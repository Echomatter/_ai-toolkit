<# Deterministic evidence-aware model selector (no web calls, no new architecture).
Reads routing/policy.json, routing/model-roster.json, routing/model-evidence.json,
routing/task-history.json and scores every eligible model for the given task.
Lane membership is used only as a deterministic tie-breaker, never as evidence.
Windows PowerShell 5.1 compatible. All file reads use UTF8 to preserve encoding.
#>
param(
    [string[]]$TaskType = @('bounded_feature'),
    $NeedsWrites = $false,
    $NeedsTerminal = $false,
    $NeedsWeb = $false,
    [int]$NeedsLargeContextTokens = 0,
    $NeedsDeepReasoning = $false,
    $NeedsModelDiversity = $false,
    $HighConsequence = $false,
    [string]$CurrentModel = '',
    [string]$ExcludeModel = '',
    [string]$LaneHint = '',
    [string]$Role = '',
    [string]$PreferredCostClass = '',
    [int]$ExpectedInputTokens = 0,
    [int]$ExpectedOutputTokens = 0,
    [int]$ExpectedCacheReadTokens = 0,
    [string]$QuotaStatePath = '',
    [double]$QuotaStalenessMinutes = 30
)
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot

function To-Bool($v) {
    if ($v -is [bool]) { return $v }
    if ($null -eq $v) { return $false }
    $s = "$v".Trim().ToLower()
    if ($s -in @('1','true','yes','$true','-true')) { return $true }
    return $false
}
$bNeedsWrites = To-Bool $NeedsWrites
$bNeedsTerminal = To-Bool $NeedsTerminal
$bNeedsWeb = To-Bool $NeedsWeb
$bNeedsDeep = To-Bool $NeedsDeepReasoning
$bNeedsDiversity = To-Bool $NeedsModelDiversity
$bHighConseq = To-Bool $HighConsequence
$roleNorm = ("$Role").Trim().ToLower()
$prefCost = ("$PreferredCostClass").Trim().ToLower()

# Normalize task types: accept comma-separated single string as well.
$tasks = @()
foreach ($t in @($TaskType)) {
    if ($null -eq $t) { continue }
    foreach ($part in ("$t".Split(','))) {
        $p = $part.Trim().ToLower()
        if ($p -ne '') { $tasks += $p }
    }
}
if ($tasks.Count -eq 0) { $tasks = @('bounded_feature') }
$tasks = @($tasks | Sort-Object -Unique)

function Rating-Score([string]$r) {
    switch ($r) {
        'strong' { return 4.0 }
        'good' { return 3.0 }
        'adequate' { return 2.0 }
        'weak' { return 0.0 }
        default { return 1.0 }
    }
}
function Confidence-Mult($c) {
    if ($c -eq 'high') { return 1.0 }
    if ($c -eq 'medium') { return 0.8 }
    return 0.6
}
function Surface-Access([string]$surface) {
    switch ($surface) {
        'opencode-free' { return 'free' }
        'opencode-go' { return 'OpenCode Go subscription' }
        'openai-oauth' { return 'ChatGPT OAuth' }
        'github-copilot-oauth' { return 'Copilot OAuth' }
        default { return $surface }
    }
}

$policyPath = Join-Path $ToolkitRoot 'routing\policy.json'
$rosterPath = Join-Path $ToolkitRoot 'routing\model-roster.json'
$evidencePath = Join-Path $ToolkitRoot 'routing\model-evidence.json'
$historyPath = Join-Path $ToolkitRoot 'routing\task-history.json'
$statePath = Join-Path $ToolkitRoot 'routing\state.json'

$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$roster = Get-Content -LiteralPath $rosterPath -Raw -Encoding UTF8 | ConvertFrom-Json
$ev = Get-Content -LiteralPath $evidencePath -Raw -Encoding UTF8 | ConvertFrom-Json
$state = $null
try {
    if (Test-Path -LiteralPath $statePath) {
        $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
} catch { $state = $null }
$historyEntries = @()
try {
    $h = Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($h.entries) { $historyEntries = @($h.entries) }
} catch { $historyEntries = @() }

# Quota state (optional, runtime, never committed): .state/quota-state.json written
# by refresh-quota.ps1. The selector never performs network calls; it reads the
# cache only. Missing or stale telemetry means UNKNOWN, which is preference-neutral
# and never a lockout. Telemetry health is separate from execution availability.
# Freshness requires both a recent file AND at least one surface reporting
# telemetry status 'ok': an all-failed cache (auth-failed/unreachable/...) is
# reported as stale so failed telemetry stays neutral and never gates blocks.
if ($QuotaStatePath -eq '') { $QuotaStatePath = Join-Path $ToolkitRoot '.state\quota-state.json' }
$quotaState = $null
$quotaFresh = $false
try {
    if (Test-Path -LiteralPath $QuotaStatePath) {
        $quotaState = Get-Content -LiteralPath $QuotaStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($quotaState -and $quotaState.generated_at) {
            # generated_at carries a Z suffix; normalize to UTC before diffing
            # (a raw [DateTime] cast would land in local time and false-age).
            $genUtc = ([DateTime]"$($quotaState.generated_at)").ToUniversalTime()
            $qAge = ((Get-Date).ToUniversalTime() - $genUtc).TotalMinutes
            if ($qAge -ge 0 -and $qAge -le $QuotaStalenessMinutes) { $quotaFresh = $true }
        }
        if ($quotaFresh) {
            # File age alone is not freshness: with zero 'ok' surfaces the cache
            # carries no usable signal, so report stale (neutral, blocks nothing).
            $anyOk = $false
            if ($quotaState -and $quotaState.surfaces) {
                foreach ($sp in @($quotaState.surfaces.PSObject.Properties)) {
                    if ($sp.Value -and $sp.Value.telemetry -and ([string]$sp.Value.telemetry.status).ToLower() -eq 'ok') { $anyOk = $true; break }
                }
            }
            if (-not $anyOk) { $quotaFresh = $false }
        }
    }
} catch { $quotaState = $null; $quotaFresh = $false }

# Static public Go pricing reference (committed; NOT account data).
$goPricing = $null
try {
    $pricingPath = Join-Path $ToolkitRoot 'routing\go-pricing.json'
    if (Test-Path -LiteralPath $pricingPath) {
        $goPricing = Get-Content -LiteralPath $pricingPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
} catch { $goPricing = $null }
function Get-GoPrice([string]$ModelId) {
    if (-not $goPricing -or -not $goPricing.models) { return $null }
    foreach ($p in @($goPricing.models.PSObject.Properties)) {
        if ($p.Name -eq $ModelId) { return $p.Value }
    }
    return $null
}
# Static public Copilot rate reference (committed; NOT account data).
$copilotPricing = $null
try {
    $cpPricingPath = Join-Path $ToolkitRoot 'routing\copilot-pricing.json'
    if (Test-Path -LiteralPath $cpPricingPath) {
        $copilotPricing = Get-Content -LiteralPath $cpPricingPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
} catch { $copilotPricing = $null }
function Get-CopilotPrice([string]$ModelId) {
    if (-not $copilotPricing -or -not $copilotPricing.models) { return $null }
    foreach ($p in @($copilotPricing.models.PSObject.Properties)) {
        if ($p.Name -eq $ModelId) { return $p.Value }
    }
    return $null
}
function Get-QuotaSurface([string]$SurfaceName) {
    if (-not $quotaState -or -not $quotaState.surfaces) { return $null }
    foreach ($p in @($quotaState.surfaces.PSObject.Properties)) {
        if ($p.Name -eq $SurfaceName) { return $p.Value }
    }
    return $null
}
function Get-GoWindow([string]$WindowName) {
    $s = Get-QuotaSurface 'opencode-go'
    if (-not $s -or -not $s.windows) { return $null }
    foreach ($p in @($s.windows.PSObject.Properties)) {
        if ($p.Name -eq $WindowName) { return $p.Value }
    }
    return $null
}
# Window capacity shares of the monthly limit (Go docs: 5h=20%, weekly=50%).
function Get-WindowShare([string]$WindowName) {
    if (-not $goPricing) { return $null }
    if ($WindowName -eq 'rolling') { return [double]$goPricing.window_shares.rolling }
    if ($WindowName -eq 'weekly') { return [double]$goPricing.window_shares.weekly }
    if ($WindowName -eq 'monthly') { return [double]$goPricing.window_shares.monthly }
    return $null
}

# Combined policy order for deterministic tie-breaking (deep + review + routine, unique).
$combinedPriority = @()
foreach ($listName in @('deep_priority','review_priority','routine_priority')) {
    $lst = @($policy.$listName)
    foreach ($id in $lst) {
        if ($id -and ($combinedPriority -notcontains $id)) { $combinedPriority += $id }
    }
}
function Priority-Index([string]$id) {
    $i = [Array]::IndexOf($combinedPriority, $id)
    if ($i -lt 0) { return 10000 }
    return $i
}

# Freshness from evidence_as_of (date string) vs UTC today. Never use roster.generated_at.
$freshness = 'UNPOPULATED'
$evidenceAgeDays = $null
$readiness = 'UNPOPULATED'
if ($ev.advisor_readiness) { $readiness = [string]$ev.advisor_readiness }
try {
    if ($ev.evidence_as_of -and ("$($ev.evidence_as_of)".Trim() -ne '')) {
        $asOf = [DateTime]"$($ev.evidence_as_of)"
        $today = (Get-Date).ToUniversalTime().Date
        $evidenceAgeDays = ($today - $asOf.Date).Days
        if ($evidenceAgeDays -le 1) { $freshness = 'current' }
        elseif ($evidenceAgeDays -le 3) { $freshness = 'partially stale' }
        elseif ($evidenceAgeDays -le 7) { $freshness = 'stale' }
        else { $freshness = 'very stale' }
    }
} catch { $freshness = 'UNPOPULATED' }

# Build capability weights for this task. long_context is a filter + small bonus,
# not a dominant averaged capability, so large-context models do not auto-win reviews.
# code_review weight dominates review tasks so review specialists beat long-context generalists.
$weights = @{}
function Add-W([string]$k, [double]$w) {
    if (-not $weights.ContainsKey($k)) { $weights[$k] = 0.0 }
    $weights[$k] = [double]$weights[$k] + $w
}
foreach ($t in $tasks) {
    switch ($t) {
        'code_review' { Add-W 'code_review' 5.0; Add-W 'coding' 1.0; Add-W 'repo_understanding' 0.5 }
        'independent_verification' { Add-W 'code_review' 3.0; Add-W 'architecture' 0.5; Add-W 'coding' 0.5 }
        'debugging' { Add-W 'debugging' 3.0; Add-W 'terminal_agent_work' 1.0; Add-W 'tool_use' 1.0 }
        'terminal_heavy' { Add-W 'terminal_agent_work' 3.0; Add-W 'tool_use' 1.0 }
        'architecture' { Add-W 'architecture' 3.0; Add-W 'long_horizon_engineering' 2.0; Add-W 'repo_understanding' 1.0; Add-W 'agentic_work' 1.0 }
        'large_refactor' { Add-W 'long_horizon_engineering' 2.0; Add-W 'architecture' 2.0; Add-W 'repo_understanding' 1.0; Add-W 'agentic_work' 1.0 }
        'repo_navigation' { Add-W 'repo_understanding' 2.0; Add-W 'repo_navigation' 2.0 }
        'long_context_reading' { Add-W 'long_context' 0.5; Add-W 'repo_understanding' 0.5 }
        'bounded_feature' { Add-W 'routine_coding' 2.0; Add-W 'coding' 2.0; Add-W 'tool_use' 1.0 }
        'simple_edit' { Add-W 'routine_coding' 2.0; Add-W 'coding' 2.0; Add-W 'tool_use' 1.0; Add-W 'speed' 1.0 }
        'test_generation' { Add-W 'coding' 2.0; Add-W 'routine_coding' 1.0; Add-W 'repo_understanding' 1.0 }
        'documentation' { Add-W 'coding' 1.0; Add-W 'routine_coding' 1.0; Add-W 'research' 1.0 }
        'research' { Add-W 'research' 3.0; Add-W 'tool_use' 1.0 }
        'ml' { Add-W 'deep_reasoning' 2.0; Add-W 'debugging' 1.0; Add-W 'long_horizon_engineering' 1.0 }
        'dsp' { Add-W 'deep_reasoning' 2.0; Add-W 'debugging' 1.0; Add-W 'long_horizon_engineering' 1.0 }
        'firmware' { Add-W 'deep_reasoning' 2.0; Add-W 'debugging' 1.0; Add-W 'long_horizon_engineering' 1.0 }
        'reverse_engineering' { Add-W 'deep_reasoning' 2.0; Add-W 'repo_understanding' 1.0; Add-W 'debugging' 1.0 }
        default { Add-W 'coding' 1.0; Add-W 'tool_use' 1.0 }
    }
}
if ($bNeedsTerminal) { Add-W 'terminal_agent_work' 2.0; Add-W 'tool_use' 1.0 }
if ($bNeedsDeep) { Add-W 'long_horizon_engineering' 2.0; Add-W 'deep_reasoning' 2.0; Add-W 'debugging' 1.0; Add-W 'architecture' 1.0; Add-W 'agentic_work' 1.0 }
if ($bNeedsWeb) { Add-W 'research' 1.0; Add-W 'tool_use' 1.0 }
if ($bHighConseq) { Add-W 'debugging' 1.0; Add-W 'architecture' 1.0 }
if ($NeedsLargeContextTokens -gt 0) { Add-W 'long_context' 0.5 }
# Role hint: stable role names influence weights without replacing task types.
# worker = default implementation weights (no change). review adds verification
# weights when the caller did not already specify a review task type.
# index adds light retrieval weights; its strong free bias is applied in economics.
if ($roleNorm -eq 'review') {
    if (($tasks -notcontains 'code_review') -and ($tasks -notcontains 'independent_verification')) {
        Add-W 'code_review' 3.0; Add-W 'coding' 0.5
    }
} elseif ($roleNorm -eq 'index') {
    Add-W 'research' 1.0; Add-W 'repo_understanding' 1.0
}

# Trivial-task detection: inexpensive default must win without research.
$nonTrivialTypes = @('architecture','large_refactor','debugging','terminal_heavy','ml','dsp','firmware','reverse_engineering','code_review','independent_verification','long_context_reading')
$isTrivial = $true
foreach ($t in $tasks) { if ($nonTrivialTypes -contains $t) { $isTrivial = $false; break } }
if ($bNeedsDeep -or $bNeedsTerminal -or ($NeedsLargeContextTokens -gt 0) -or $bHighConseq -or $bNeedsWrites) {
    # needs_writes alone does not make a simple edit non-trivial, but combined with
    # review/debugging/terminal/deep reasoning it does. Keep simple writes trivial.
    $hardTasks = @('architecture','large_refactor','debugging','terminal_heavy','code_review','independent_verification','ml','dsp','firmware','reverse_engineering','long_context_reading')
    $hasHard = $false
    foreach ($t in $tasks) { if ($hardTasks -contains $t) { $hasHard = $true; break } }
    if ($hasHard -or $bNeedsDeep -or $bNeedsTerminal -or ($NeedsLargeContextTokens -gt 0) -or $bHighConseq) { $isTrivial = $false }
}
$isConsequential = ($bNeedsDeep -or $bHighConseq -or ($NeedsLargeContextTokens -ge 200000) -or ($tasks -contains 'architecture') -or ($tasks -contains 'large_refactor') -or (($tasks -contains 'debugging') -and ($tasks -contains 'terminal_heavy')))

function Get-Canonical-Key($Evidence, [string]$RosterId) {
    if (-not $Evidence.alias_index) { return $null }
    foreach ($p in @($Evidence.alias_index.PSObject.Properties)) {
        if ($p.Name -eq $RosterId) { return [string]$p.Value }
    }
    return $null
}
function Get-Canonical-Entry($Evidence, [string]$CanonKey) {
    if (-not $CanonKey) { return $null }
    foreach ($p in @($Evidence.models.PSObject.Properties)) {
        if ($p.Name -eq $CanonKey) { return $p.Value }
    }
    return $null
}
function Get-Capability($entry, [string]$key) {
    if (-not $entry -or -not $entry.capabilities) { return $null }
    foreach ($p in @($entry.capabilities.PSObject.Properties)) {
        if ($p.Name -eq $key) { return $p.Value }
    }
    $fallback = @{
        routine_coding = 'coding'
        agentic_work = 'long_horizon_engineering'
        repo_navigation = 'repo_understanding'
        deep_reasoning = 'long_horizon_engineering'
    }
    if ($fallback.ContainsKey($key)) {
        $alt = [string]$fallback[$key]
        foreach ($p in @($entry.capabilities.PSObject.Properties)) {
            if ($p.Name -eq $alt) { return $p.Value }
        }
    }
    return $null
}
function Get-ModelProvider($entry, [string]$id) {
    if ($entry -and $entry.provider) { return ([string]$entry.provider).Trim().ToLower() }
    if ($id -match '^([^/]+)/') { return $Matches[1].ToLower() }
    return ''
}
function Get-ExecutionSurface([string]$ModelId, [string]$Purpose) {
    if ($CurrentModel -and $ModelId -eq $CurrentModel) { return 'build' }
    if ($state) {
        if ($Purpose -eq 'review' -and $state.review -and $ModelId -eq [string]$state.review) { return '@review' }
        if ($Purpose -eq 'implementation' -and $state.deep -and $ModelId -eq [string]$state.deep) { return '@deep chunk' }
        if ($state.routine -and $ModelId -eq [string]$state.routine) { return 'build' }
    }
    return '/models switch'
}

$excludeCanonical = $null
$excludeProvider = ''
$diversityReferenceModel = $ExcludeModel
if ($bNeedsDiversity -and -not $diversityReferenceModel -and $CurrentModel) {
    $diversityReferenceModel = $CurrentModel
}
if ($diversityReferenceModel -ne '') {
    $excludeCanonical = Get-Canonical-Key $ev $diversityReferenceModel
    $excludeEntry = Get-Canonical-Entry $ev $excludeCanonical
    $excludeProvider = Get-ModelProvider $excludeEntry $diversityReferenceModel
}

$scored = @()
$filtered = @()
$appliedBlocks = @()
$quotaNotes = @()

# ---- Execution availability (separate from telemetry health) ----
# A block applies when: reset is known and in the future; or reset is unknown
# and the bounded recheck time is still in the future. Unknown-reset blocks carry
# a bounded recheck budget (recorded by refresh-quota.ps1); when the budget is
# spent, the route is treated as unknown rather than blocked.
function Test-ExecutionBlock($exec) {
    if (-not $exec -or -not $exec.blocked) { return $null }
    $now = (Get-Date).ToUniversalTime()
    if ($exec.reset_at -and ("$($exec.reset_at)".Trim() -ne '')) {
        try {
            # Normalize to UTC: a raw [DateTime] cast lands in local time, so a
            # future reset within the UTC offset would false-compare as past.
            $reset = ([DateTime]"$($exec.reset_at)").ToUniversalTime()
            if ($reset -gt $now) {
                return [ordered]@{ active = $true; reason = [string]$exec.reason; reset_at = [string]$exec.reset_at; recheck_at = ''; kind = 'execution-block' }
            }
            return $null
        } catch {}
    }
    if ($exec.recheck_at -and ("$($exec.recheck_at)".Trim() -ne '')) {
        try {
            # Same UTC normalization: without it a future recheck inside the
            # local UTC offset compares as past and the block wrongly lapses.
            $recheck = ([DateTime]"$($exec.recheck_at)").ToUniversalTime()
            $count = 0
            try { $count = [int]$exec.recheck_count } catch {}
            if ($recheck -gt $now -and $count -lt 4) {
                return [ordered]@{ active = $true; reason = [string]$exec.reason; reset_at = ''; recheck_at = [string]$exec.recheck_at; kind = 'execution-block-recheck' }
            }
            return [ordered]@{ active = $false; reason = 'recheck budget spent; treating route as unknown'; reset_at = ''; recheck_at = ''; kind = 'recheck-spent' }
        } catch {}
    }
    return [ordered]@{ active = $true; reason = [string]$exec.reason; reset_at = ''; recheck_at = ''; kind = 'execution-block-unknown-reset' }
}
$execBlockBySurface = @{}
foreach ($sn in @('opencode-go', 'openai-oauth', 'github-copilot-oauth', 'opencode-free')) {
    $qs = Get-QuotaSurface $sn
    if ($qs -and $qs.execution) {
        $b = Test-ExecutionBlock $qs.execution
        if ($b -and $b.active) {
            $execBlockBySurface[$sn] = $b
            $appliedBlocks += [ordered]@{ surface = $sn; reason = $b.reason; reset_at = $b.reset_at; recheck_at = $b.recheck_at; kind = $b.kind }
        } elseif ($b -and -not $b.active) {
            $quotaNotes += ("surface ${sn}: " + $b.reason)
        }
    }
}

# ---- Telemetry-confirmed shared-pool exhaustion (fresh telemetry only) ----
# Go: a window whose status is not ok means the pool refused work in that window.
$goBlockedWindow = $null
if ($quotaFresh) {
    foreach ($w in @('rolling', 'weekly', 'monthly')) {
        $wu = Get-GoWindow $w
        if ($wu -and $wu.status -and ([string]$wu.status).ToLower() -ne 'ok') {
            $goBlockedWindow = [ordered]@{ window = $w; status = [string]$wu.status; resets_at = [string]$wu.resets_at }
            break
        }
    }
    if ($goBlockedWindow) {
        $appliedBlocks += [ordered]@{ surface = 'opencode-go'; reason = ("go window " + $goBlockedWindow.window + " status=" + $goBlockedWindow.status); reset_at = $goBlockedWindow.resets_at; recheck_at = ''; kind = 'pool-exhausted' }
    }
}
# Copilot: delegated execution (worker/review/deep/index via a third-party coding
# agent) consumes AI credits, which the API reports as the premium_interactions
# bucket. chat/completions unlimited does NOT cover agentic delegation, so only
# the premium bucket is evaluated here. Depletion without permitted overage blocks
# the pool until the known reset; permitted overage allows with an explicit flag
# (never silent paid fallthrough).
$copilotPremium = $null
$copilotOverage = $false
if ($quotaFresh) {
    $cs = Get-QuotaSurface 'github-copilot-oauth'
    if ($cs -and $cs.buckets -and $cs.buckets.premium_interactions) {
        $pb = $cs.buckets.premium_interactions
        $premRem = 100.0
        try { $premRem = [double]$pb.percent_remaining } catch {}
        $overPerm = $false
        try { $overPerm = [bool]$pb.overage_permitted } catch {}
        $entVal = 0.0
        try { if ($null -ne $pb.entitlement) { $entVal = [double]$pb.entitlement } } catch {}
        $copilotPremium = [ordered]@{ percent_remaining = $premRem; overage_permitted = $overPerm; reset_at = [string]$cs.reset_at; entitlement = $entVal }
        if ($premRem -le 0 -and -not $overPerm) {
            $appliedBlocks += [ordered]@{ surface = 'github-copilot-oauth'; reason = 'copilot AI-credit pool depleted (premium_interactions) with no permitted overage'; reset_at = [string]$cs.reset_at; recheck_at = ''; kind = 'pool-exhausted' }
        } elseif ($premRem -le 0 -and $overPerm) {
            $copilotOverage = $true
            $quotaNotes += 'copilot premium pool depleted but overage is permitted; allowed with overage flag'
        }
    }
}
foreach ($rm in @($roster.eligible_models)) {
    $rid = [string]$rm.id
    $surface = [string]$rm.surface
    if ($ExcludeModel -ne '' -and $rid -eq $ExcludeModel) {
        $filtered += [pscustomobject]@{ id=$rid; reason='excluded (diversity)' }
        continue
    }
    # Availability first: a blocked surface or an exhausted shared pool never
    # scores. Missing or stale telemetry is unknown, never a block.
    if ($execBlockBySurface.ContainsKey($surface)) {
        $br = $execBlockBySurface[$surface]
        $filtered += [pscustomobject]@{ id=$rid; reason=("execution blocked (" + $br.kind + "): " + $br.reason) }
        continue
    }
    if ($surface -eq 'opencode-go' -and $goBlockedWindow) {
        $filtered += [pscustomobject]@{ id=$rid; reason=("go pool exhausted: window " + $goBlockedWindow.window + " status=" + $goBlockedWindow.status) }
        continue
    }
    if ($surface -eq 'github-copilot-oauth' -and $copilotPremium -and ($copilotPremium.percent_remaining -le 0) -and (-not $copilotPremium.overage_permitted)) {
        $filtered += [pscustomobject]@{ id=$rid; reason='copilot credit pool depleted (premium_interactions), no overage permitted' }
        continue
    }
    $canon = Get-Canonical-Key $ev $rid
    $entry = Get-Canonical-Entry $ev $canon
    if (-not $entry) {
        $filtered += [pscustomobject]@{ id=$rid; reason='no canonical evidence entry' }
        continue
    }
    if ($bNeedsDiversity -and $excludeCanonical -and $canon -eq $excludeCanonical) {
        $filtered += [pscustomobject]@{ id=$rid; reason='excluded: same canonical model as diversity reference' }
        continue
    }
    $provider = Get-ModelProvider $entry $rid
    $diversityAdj = 0.0
    if ($bNeedsDiversity -and $excludeProvider -ne '' -and $provider -eq $excludeProvider) {
        $diversityAdj = -0.5
    }
    # Hard context filter: known insufficient context eliminates.
    if ($NeedsLargeContextTokens -gt 0 -and $entry.context -and $entry.context.input_tokens) {
        try {
            $ctxTokens = [int]$entry.context.input_tokens
            if ($ctxTokens -gt 0 -and $ctxTokens -lt $NeedsLargeContextTokens) {
                $filtered += [pscustomobject]@{ id=$rid; reason=("context $ctxTokens < required $NeedsLargeContextTokens") }
                continue
            }
        } catch {}
    }
    # Weighted capability average.
    $sum = 0.0
    $wsum = 0.0
    $whyParts = @()
    foreach ($k in $weights.Keys) {
        $w = [double]$weights[$k]
        $cap = Get-Capability $entry $k
        $rating = 'unknown'
        $conf = 'low'
        $srcs = @()
        if ($cap -and $cap.rating) { $rating = [string]$cap.rating }
        if ($cap -and $cap.confidence) { $conf = [string]$cap.confidence }
        if ($cap -and $cap.evidence) { $srcs = @($cap.evidence) }
        $contrib = (Rating-Score $rating) * (Confidence-Mult $conf)
        $sum += $contrib * $w
        $wsum += $w
        if ($w -ge 2.0 -and $rating -ne 'unknown') {
            $whyParts += ("$k=$rating/$conf")
        }
    }
    $capAvg = 0.0
    if ($wsum -gt 0) { $capAvg = $sum / $wsum }
    # Capability qualification first: economics may decide among qualified
    # candidates but never promote an unqualified one. Harder tasks require
    # stronger evidence before a cheap candidate qualifies.
    $capFloor = 0.5
    if ($isTrivial) { $capFloor = 0.3 }
    if ($isConsequential) { $capFloor = 2.0 }
    if ($capAvg -lt $capFloor) {
        $filtered += [pscustomobject]@{ id=$rid; reason=("capability floor: cap_avg " + ([Math]::Round($capAvg,2)) + " < required " + $capFloor) }
        continue
    }
    # Conservative synonym fallback is implemented in Get-Capability. Explicit
    # evidence always wins; absent schema keys may borrow only the nearest
    # documented capability and never invent a stronger rating.

    # Benchmark bonus: only same-version Coding Agent Index v1.5 family.
    # Terminal-Bench 2.1 and other legacy versions are excluded from ranking.
    $benchBonus = 0.0
    $benchNotes = @()
    foreach ($b in @($entry.benchmarks)) {
        if (-not $b -or -not $b.benchmark) { continue }
        $bn = [string]$b.benchmark
        if ($bn -match '2\.1') { continue }
        try { $val = [double]$b.value } catch { continue }
        if ($bn -eq 'Coding Agent Index v1.5') { $benchBonus += ($val / 100.0) * 0.4; $benchNotes += ("index $val") }
        elseif ($bn -eq 'DeepSWE v1.1') {
            if ($tasks -contains 'debugging' -or $bNeedsDeep -or ($tasks -contains 'architecture')) { $benchBonus += ($val / 100.0) * 0.3; $benchNotes += ("deepswe $val") }
        }
        elseif ($bn -eq 'Terminal-Bench 4.0') {
            if ($tasks -contains 'terminal_heavy' -or ($tasks -contains 'debugging') -or $bNeedsTerminal) { $benchBonus += ($val / 100.0) * 0.4; $benchNotes += ("tb4 $val") }
        }
        elseif ($bn -eq 'SWE-Atlas-QnA') {
            if ($tasks -contains 'repo_navigation' -or ($tasks -contains 'long_context_reading')) { $benchBonus += ($val / 100.0) * 0.2; $benchNotes += ("atlas $val") }
        }
    }
    if ($benchBonus -gt 0.8) { $benchBonus = 0.8 }

    # Local history: n<3 anecdotal only; n>=3 may influence; n>=10 substantial.
    # Reward validated first-pass success and penalize repeated attempts,
    # escalation, and defects later found by independent review.
    $histN = 0
    $histRate = $null
    $histAdj = 0.0
    $histTestsRate = $null
    $histEscRate = $null
    $histReviewDefectRate = $null
    $histAvgAttempts = $null
    if ($historyEntries.Count -gt 0) {
        $rel = @($historyEntries | Where-Object { $_.model -eq $rid })
        # Prefer task-overlapping history when enough samples exist.
        $overlap = @($rel | Where-Object {
            $hit = $false
            foreach ($tt in @($_.task_type)) { if ($tasks -contains ([string]$tt).ToLower()) { $hit = $true; break } }
            $hit
        })
        $useSet = $rel
        if ($overlap.Count -ge 3) { $useSet = $overlap }
        $histN = $useSet.Count
        if ($histN -gt 0) {
            $succ = @($useSet | Where-Object { $_.success -eq $true }).Count
            $histRate = [double]$succ / [double]$histN
            $testsPass = @($useSet | Where-Object { $_.tests_passed -eq $true }).Count
            $escCount = @($useSet | Where-Object { $_.escalated -eq $true }).Count
            $reviewDefects = @($useSet | Where-Object { $_.review_found_defects -eq $true }).Count
            $attemptTotal = 0.0
            foreach ($he in $useSet) {
                try { $attemptTotal += [double]$he.attempts } catch { $attemptTotal += 1.0 }
            }
            $histTestsRate = [double]$testsPass / [double]$histN
            $histEscRate = [double]$escCount / [double]$histN
            $histReviewDefectRate = [double]$reviewDefects / [double]$histN
            $histAvgAttempts = $attemptTotal / [double]$histN
            if ($histN -ge 3) {
                if ($histRate -ge 0.75) { $histAdj += 0.4 }
                elseif ($histRate -ge 0.6) { $histAdj += 0.2 }
                elseif ($histRate -lt 0.4) { $histAdj -= 1.0 }
                elseif ($histRate -lt 0.6) { $histAdj -= 0.35 }

                if ($histTestsRate -ge 0.8 -and $histRate -ge 0.6) { $histAdj += 0.15 }
                elseif ($histTestsRate -lt 0.5) { $histAdj -= 0.2 }

                if ($histAvgAttempts -gt 2.0) { $histAdj -= 0.3 }
                elseif ($histAvgAttempts -le 1.25 -and $histRate -ge 0.75) { $histAdj += 0.1 }

                if ($histEscRate -ge 0.5) { $histAdj -= 0.3 }
                elseif ($histEscRate -eq 0 -and $histRate -ge 0.75) { $histAdj += 0.05 }
                if ($histReviewDefectRate -ge 0.5) { $histAdj -= 0.4 }
                elseif ($histReviewDefectRate -gt 0) { $histAdj -= 0.2 }
                if ($histN -ge 10) { $histAdj = $histAdj * 1.5 }
                if ($histAdj -gt 1.0) { $histAdj = 1.0 }
                if ($histAdj -lt -1.5) { $histAdj = -1.5 }
            }
        }
    }

    # Economics, two parts. Base preserves the existing triviality/role policy
    # exactly (backward compatible when quota data is absent). The quota term
    # below is window-consistent normalized expense: monthly estimates against
    # monthly capacity, short-window pressure against the matching short-window
    # capacity. Windows are never summed as separate charges; pressure takes
    # the maximum across windows. All dollar figures are allocation estimates,
    # not charges or cash savings.
    $econBase = 0.0
    if ($isTrivial) {
        if ($surface -eq 'opencode-free') { $econBase = 1.0 }
        else { $econBase = -0.25 }
    } elseif ($isConsequential) {
        if ($surface -ne 'opencode-free') { $econBase = -0.15 }
    }
    if ($roleNorm -eq 'index') {
        if ($surface -eq 'opencode-free') { $econBase = $econBase + 2.0 }
        else { $econBase = $econBase - 1.0 }
    } elseif ($prefCost -eq 'free') {
        if ($surface -eq 'opencode-free') { $econBase = $econBase + 1.5 }
        else { $econBase = $econBase - 1.0 }
    }

    $quotaEcon = 0.0
    $quotaDetail = 'no quota signal (unknown telemetry is neutral)'
    $estCost = 0.0
    $monthlyFrac = $null
    $winPressure = $null
    $hasEst = (($ExpectedInputTokens -gt 0) -or ($ExpectedOutputTokens -gt 0) -or ($ExpectedCacheReadTokens -gt 0))
    if ($surface -eq 'opencode-go' -and $quotaFresh) {
        $maxUsed = 0.0
        foreach ($w in @('rolling', 'weekly', 'monthly')) {
            $wu = Get-GoWindow $w
            if ($wu -and $wu.used_percent) {
                try { $u = [double]$wu.used_percent; if ($u -gt $maxUsed) { $maxUsed = $u } } catch {}
            }
        }
        # Shared pool scarcity: identical for every Go model, moves Go as a
        # whole against other surfaces without differentiating inside the pool.
        $quotaEcon = $quotaEcon - (($maxUsed / 100.0) * 0.5)
        $quotaDetail = ("go pool max-window used " + ([Math]::Round($maxUsed, 1)) + "%")
        if ($hasEst) {
            $gp = Get-GoPrice $rid
            if ($gp -and $gp.monthly_limit) {
                try {
                    $ml = [double]$gp.monthly_limit
                    $estCost = ([double]$ExpectedInputTokens / 1000000.0) * [double]$gp.input + ([double]$ExpectedOutputTokens / 1000000.0) * [double]$gp.output + ([double]$ExpectedCacheReadTokens / 1000000.0) * [double]$gp.cache_read
                    if ($estCost -gt 0 -and $ml -gt 0) {
                        $monthlyFrac = $estCost / $ml
                        $quotaEcon = $quotaEcon - (($monthlyFrac * 100.0) * 0.3)
                        $maxP = 0.0
                        foreach ($w in @('rolling', 'weekly', 'monthly')) {
                            $wu = Get-GoWindow $w
                            $share = Get-WindowShare $w
                            if ($wu -and $share -and ([double]$share -gt 0)) {
                                $capw = $ml * [double]$share
                                if ($capw -gt 0) {
                                    $pts = $estCost / $capw * 100.0
                                    $rem = 100.0 - [double]$wu.used_percent
                                    if ($rem -lt 5.0) { $rem = 5.0 }
                                    $p = $pts / $rem
                                    if ($p -gt $maxP) { $maxP = $p }
                                }
                            }
                        }
                        $winPressure = $maxP
                        $quotaEcon = $quotaEcon - [Math]::Min($maxP, 1.0) * 1.0
                        $quotaDetail = ("go est $" + ([Math]::Round($estCost, 4)) + " = " + ([Math]::Round(($monthlyFrac * 100.0), 2)) + "% of monthly limit $" + $ml + "; window pressure " + ([Math]::Round($maxP, 3)))
                    }
                } catch {}
            } elseif ($gp) {
                $quotaDetail = 'go pricing has no verified monthly limit for this model; pool scarcity only'
            }
        }
    } elseif ($surface -eq 'github-copilot-oauth' -and $copilotPremium) {
        # Delegated agentic work runs as a third-party coding agent, which
        # consumes AI credits from the premium_interactions bucket. Per-model
        # rates are public; the monthly credit entitlement comes from live
        # telemetry because it is plan-dependent (1500 credits on Pro).
        $premRem = [double]$copilotPremium.percent_remaining
        $quotaEcon = $quotaEcon - ((1.0 - ($premRem / 100.0)) * 0.5)
        $quotaDetail = ("copilot premium pool " + ([Math]::Round($premRem, 1)) + "% remaining")
        if ($hasEst) {
            $cp = Get-CopilotPrice $rid
            $ent = 0.0
            try { $ent = [double]$copilotPremium.entitlement } catch {}
            if ($cp -and ($ent -gt 0)) {
                try {
                    $estD = ([double]$ExpectedInputTokens / 1000000.0) * [double]$cp.input + ([double]$ExpectedOutputTokens / 1000000.0) * [double]$cp.output + ([double]$ExpectedCacheReadTokens / 1000000.0) * [double]$cp.cache_read
                    if ($estD -gt 0) {
                        $estCredits = $estD / 0.01
                        $estCost = $estD
                        $monthlyFrac = $estCredits / $ent
                        $quotaEcon = $quotaEcon - (($monthlyFrac * 100.0) * 0.3)
                        $rem = $premRem
                        if ($rem -lt 5.0) { $rem = 5.0 }
                        $winPressure = (($monthlyFrac * 100.0) / $rem)
                        $quotaEcon = $quotaEcon - [Math]::Min($winPressure, 1.0) * 1.0
                        $quotaDetail = ("copilot est " + ([Math]::Round($estCredits, 1)) + " credits = " + ([Math]::Round(($monthlyFrac * 100.0), 2)) + "% of " + $ent + " entitlement; pressure " + ([Math]::Round($winPressure, 3)))
                    }
                } catch {}
            }
        }
        if ($copilotOverage) {
            $quotaEcon = $quotaEcon - 0.5
            $quotaDetail = $quotaDetail + '; depleted with permitted overage (explicit, never silent)'
        }
    } elseif ($surface -eq 'openai-oauth' -and $quotaFresh) {
        $os = Get-QuotaSurface 'openai-oauth'
        $maxUsed = $null
        if ($os -and $os.windows) {
            foreach ($wp in @($os.windows.PSObject.Properties)) {
                if ($wp.Name -eq 'plan_type') { continue }
                try { $u = [double]$wp.Value.used_percent; if (($null -eq $maxUsed) -or ($u -gt $maxUsed)) { $maxUsed = $u } } catch {}
            }
        }
        if ($null -ne $maxUsed) {
            $quotaEcon = $quotaEcon - (($maxUsed / 100.0) * 0.5)
            $quotaDetail = ("chatgpt window used " + ([Math]::Round($maxUsed, 1)) + "%")
        }
    }
    # Learned consumption: measured-only observations (quality=measured) may
    # nudge when this task class is historically far costlier on this model.
    # Estimated or unmeasurable observations never train.
    if (($histN -ge 3) -and ($estCost -gt 0) -and $useSet) {
        $measured = @($useSet | Where-Object { $_ -and $_.consumption -and ([string]$_.consumption.quality) -eq 'measured' -and $_.consumption.cost_dollars })
        if ($measured.Count -ge 3) {
            $avgC = 0.0
            foreach ($me in $measured) { try { $avgC += [double]$me.consumption.cost_dollars } catch {} }
            $avgC = $avgC / [double]$measured.Count
            if ($avgC -gt 0 -and (($estCost / $avgC) -gt 2.0)) {
                $quotaEcon = $quotaEcon - 0.2
                $quotaDetail = $quotaDetail + ("; historically >2x measured avg ($" + ([Math]::Round($avgC, 4)) + ", n=" + $measured.Count + ")")
            }
        }
    }
    if ($quotaEcon -lt -2.5) { $quotaEcon = -2.5 }
    if ($quotaEcon -gt 0) { $quotaEcon = 0 }
    $econAdj = $econBase + $quotaEcon

    $total = $capAvg + $benchBonus + $histAdj + $econAdj + $diversityAdj
    $scored += [pscustomobject]@{
        id = $rid
        canonical = $canon
        surface = $surface
        access = (Surface-Access $surface)
        cap_avg = [Math]::Round($capAvg, 3)
        bench_bonus = [Math]::Round($benchBonus, 3)
        hist_n = $histN
        hist_rate = $histRate
        hist_adj = [Math]::Round($histAdj, 3)
        hist_tests_rate = $histTestsRate
        hist_escalation_rate = $histEscRate
        hist_review_defect_rate = $histReviewDefectRate
        hist_avg_attempts = $histAvgAttempts
        econ_adj = $econAdj
        econ_base = $econBase
        quota_econ = [Math]::Round($quotaEcon, 3)
        quota_detail = $quotaDetail
        est_cost_dollars = $estCost
        monthly_fraction = $monthlyFrac
        window_pressure = $winPressure
        diversity_adj = $diversityAdj
        total = [Math]::Round($total, 3)
        priority = (Priority-Index $rid)
        why_caps = ($whyParts -join '; ')
        bench_notes = ($benchNotes -join '; ')
    }
}

if ($scored.Count -eq 0) { throw 'No eligible models survived hard filters.' }
$ranked = @($scored | Sort-Object -Property @{Expression='total';Descending=$true}, @{Expression='priority';Descending=$false}, @{Expression='id';Descending=$false})

$top = $ranked[0]
# Fallback: prefer a materially close alternative. When the winner is paid,
# always retain the best hosted-free candidate as a graceful quota/service fallback.
$fallback = $null
if ($ranked.Count -gt 1) {
    $cands = @($ranked | Where-Object { ($_.id -ne $top.id) -and ($_.canonical -ne $top.canonical) })
    if ($cands.Count -eq 0) { $cands = @($ranked | Where-Object { $_.id -ne $top.id }) }
    if ($cands.Count -gt 0 -and (($top.total - $cands[0].total) -le 1.5)) { $fallback = $cands[0] }

    if ($top.surface -ne 'opencode-free') {
        $freeFallback = @($ranked | Where-Object { $_.surface -eq 'opencode-free' } | Select-Object -First 1)
        if ($freeFallback.Count -gt 0) { $fallback = $freeFallback[0] }
    }
}

# Execution surface + compound phases. needs_writes=true can never be sole @review.
$isReviewTask = ($tasks -contains 'code_review') -or ($tasks -contains 'independent_verification')
$execSurface = 'build'
$phases = @()
$diagnosisModel = $null
if ($isReviewTask -and (-not $bNeedsWrites)) {
    $execSurface = Get-ExecutionSurface $top.id 'review'
    $phases = @(
        [ordered]@{ phase=1; name='diagnosis/review'; surface=$execSurface; model=$top.id }
    )
} elseif ($isReviewTask -and $bNeedsWrites) {
    $execSurface = 'combination'
    # Repair model is the ranked winner; diagnosis is the best review-capable model != repair.
    $repairModel = $top
    $diag = $null
    foreach ($c in $ranked) {
        if ($c.id -eq $repairModel.id) { continue }
        $ce = Get-Canonical-Entry $ev (Get-Canonical-Key $ev $c.id)
        $cr = Get-Capability $ce 'code_review'
        $r = 'unknown'
        if ($cr -and $cr.rating) { $r = [string]$cr.rating }
        if ($r -eq 'strong' -or $r -eq 'good') { $diag = $c; break }
    }
    if (-not $diag) {
        if ($fallback) { $diag = $fallback }
        else { $diag = $ranked[1] }
    }
    $diagnosisModel = $diag
    # Primary recommendation stays the repair model so the two requirement sets differ.
    $diagSurface = Get-ExecutionSurface $diag.id 'review'
    $repairSurface = Get-ExecutionSurface $repairModel.id 'implementation'
    $phases = @(
        [ordered]@{ phase=1; name='diagnosis/review'; surface=$diagSurface; model=$diag.id },
        [ordered]@{ phase=2; name='implementation/repair'; surface=$repairSurface; model=$repairModel.id }
    )
    # Fallback for compound is the diagnosis model (already distinct).
    $fallback = $diag
} else {
    $execSurface = Get-ExecutionSurface $top.id 'implementation'
    $phases = @(
        [ordered]@{ phase=1; name='implementation'; surface=$execSurface; model=$top.id }
    )
}

# Preserve a hosted-free fallback for any paid recommendation, even when
# compound task handling selected a separate diagnosis model.
if ($top.surface -ne 'opencode-free') {
    $freeFallback = @($ranked | Where-Object { $_.surface -eq 'opencode-free' } | Select-Object -First 1)
    if ($freeFallback.Count -gt 0) { $fallback = $freeFallback[0] }
}

# Marginal-difference stay-put: if current model is eligible and within 0.5, stay.
$stayPut = $false
$currentScore = $null
if ($CurrentModel -ne '' -and -not $bNeedsDiversity -and -not $isReviewTask) {
    foreach ($s in $ranked) { if ($s.id -eq $CurrentModel) { $currentScore = $s; break } }
    if ($currentScore -and ($top.id -ne $CurrentModel) -and (($top.total - $currentScore.total) -lt 0.5)) {
        $stayPut = $true
    }
}

# Research gating.
function Test-CandidateEvidenceGap($candidate) {
    if (-not $candidate) { return $false }
    $ce = Get-Canonical-Entry $ev (Get-Canonical-Key $ev $candidate.id)
    if (-not $ce) { return $true }
    $status = ''
    if ($ce.research_status) { $status = ([string]$ce.research_status).ToLower() }
    if ($status -in @('identity_only','partially_researched','stale_variant','unresearched')) { return $true }
    foreach ($k in $weights.Keys) {
        if ([double]$weights[$k] -lt 2.0) { continue }
        $cap = Get-Capability $ce $k
        if (-not $cap -or -not $cap.rating -or ([string]$cap.rating).ToLower() -eq 'unknown') { return $true }
    }
    return $false
}
$needsResearch = $false
$researchReason = 'cache sufficient'
if ($readiness -eq 'UNPOPULATED' -and $isConsequential) { $needsResearch = $true; $researchReason = 'UNPOPULATED evidence + consequential task' }
elseif ($readiness -eq 'UNPOPULATED' -and $isTrivial) { $needsResearch = $false; $researchReason = 'UNPOPULATED but trivial: inexpensive default' }
elseif ($isConsequential -and (Test-CandidateEvidenceGap $ranked[0])) {
    $needsResearch = $true; $researchReason = 'top candidate lacks current task-relevant evidence'
}
elseif ($isConsequential -and $ranked.Count -gt 1 -and (Test-CandidateEvidenceGap $ranked[1]) -and (($ranked[0].total - $ranked[1].total) -lt 0.75)) {
    $needsResearch = $true; $researchReason = 'close runner-up lacks current task-relevant evidence'
}
elseif (($freshness -eq 'stale' -or $freshness -eq 'very stale' -or $freshness -eq 'partially stale') -and ($ranked.Count -gt 1) -and (($ranked[0].total - $ranked[1].total) -lt 0.5) -and $isConsequential) {
    $needsResearch = $true; $researchReason = 'stale evidence + close candidates + consequential task'
}

$finalRecommended = $top.id
$finalAction = $execSurface
if ($stayPut) {
    $finalRecommended = $CurrentModel
    $finalAction = 'stay'
    $execSurface = 'build'
    $phases = @([ordered]@{ phase=1; name='implementation'; surface='build'; model=$CurrentModel })
}

# Build why lines (task-specific, evidence-tied, no lane identity as evidence).
$why = @()
$why += ("task: " + ($tasks -join ' + ') + " | writes=$bNeedsWrites terminal=$bNeedsTerminal large_ctx=$NeedsLargeContextTokens deep=$bNeedsDeep diversity=$bNeedsDiversity consequence=$bHighConseq")
if ($top.why_caps -ne '') { $why += ("capabilities: " + $top.why_caps) }
if ($top.bench_notes -ne '') { $why += ("benchmarks (same-version only, harness-noted): " + $top.bench_notes) }
else { $why += ("benchmarks: no same-version benchmark bonus applied") }
if ($top.hist_n -ge 3) {
    $why += ("local history: n=$($top.hist_n) success=$([Math]::Round([double]$top.hist_rate,2)) tests=$([Math]::Round([double]$top.hist_tests_rate,2)) escalation=$([Math]::Round([double]$top.hist_escalation_rate,2)) review_defects=$([Math]::Round([double]$top.hist_review_defect_rate,2)) avg_attempts=$([Math]::Round([double]$top.hist_avg_attempts,2)) adj=$($top.hist_adj)")
}
else { $why += ("local history: n=$($top.hist_n) anecdotal only (needs n>=3)") }
if ($isTrivial) { $why += ("economics: trivial task prefers inexpensive free/local default") }
else { $why += ("economics: evidence-led; subscription OAuth is quota-limited, and paid failures fall back to the best hosted-free candidate") }
if ($top.quota_detail -and ([string]$top.quota_detail).Trim() -ne '') { $why += ("quota: " + [string]$top.quota_detail) }
if ($appliedBlocks.Count -gt 0) {
    $why += ("availability: " + (($appliedBlocks | ForEach-Object { ($_.surface + " " + $_.kind + " (" + $_.reason + ")") }) -join '; '))
} elseif (-not $quotaFresh) {
    $why += "availability: quota telemetry unknown or stale; no route blocked on telemetry"
}
if ($bNeedsWrites -and $isReviewTask) { $why += ("compatibility: needs_writes=true rejects read-only @review as sole surface; split Phase1 diagnosis + Phase2 repair") }

# Adequacy band for delegation consumers: derived from the winner's capability
# average, not from price. strong>=3.0, adequate>=2.0, weak<2.0, unknown when 0.
$adequacy = 'unknown'
try {
    $topCap = [double]$top.cap_avg
    if ($topCap -le 0) { $adequacy = 'unknown' }
    elseif ($topCap -ge 3.0) { $adequacy = 'strong' }
    elseif ($topCap -ge 2.0) { $adequacy = 'adequate' }
    else { $adequacy = 'weak' }
} catch { $adequacy = 'unknown' }

$quotaTelemetryOut = [ordered]@{}
foreach ($sn in @('opencode-go', 'openai-oauth', 'github-copilot-oauth', 'opencode-free')) {
    $qs = Get-QuotaSurface $sn
    if ($qs -and $qs.telemetry) {
        $quotaTelemetryOut[$sn] = [ordered]@{ status = [string]$qs.telemetry.status; source = [string]$qs.telemetry.source; as_of = [string]$qs.telemetry.as_of }
    } else {
        $quotaTelemetryOut[$sn] = [ordered]@{ status = 'unknown'; source = 'none'; as_of = '' }
    }
}

$result = [ordered]@{
    recommended = $finalRecommended
    top_scored = $top.id
    access = (Surface-Access $top.surface)
    why = $why
    execution_surface = $execSurface
    action = $finalAction
    phases = $phases
    fallback = $null
    current_lane = $LaneHint
    evidence_freshness = $freshness
    evidence_age_days = $evidenceAgeDays
    evidence_readiness = $readiness
    needs_research = $needsResearch
    research_reason = $researchReason
    is_trivial = $isTrivial
    is_consequential = $isConsequential
    stay_put = $stayPut
    filtered_out = @($filtered | ForEach-Object { [ordered]@{ id=$_.id; reason=$_.reason } })
    top_scores = @($ranked | Select-Object -First 5 | ForEach-Object {
        [ordered]@{ id=$_.id; total=$_.total; cap_avg=$_.cap_avg; bench=$_.bench_bonus; hist_n=$_.hist_n; hist_adj=$_.hist_adj; econ=$_.econ_adj; quota=$_.quota_econ; diversity=$_.diversity_adj }
    })
    ranking = @($ranked | ForEach-Object {
        [ordered]@{ id=$_.id; total=$_.total; cap_avg=$_.cap_avg; econ=$_.econ_adj; quota=$_.quota_econ }
    })
    quota_state = [ordered]@{
        fresh = $quotaFresh
        telemetry = $quotaTelemetryOut
        blocks = @($appliedBlocks)
        notes = @($quotaNotes)
        overage = $copilotOverage
    }
    consumption_estimate = [ordered]@{
        allocation_estimate_dollars = $top.est_cost_dollars
        monthly_fraction = $top.monthly_fraction
        window_pressure = $top.window_pressure
        quota_detail = $top.quota_detail
        note = 'allocation estimate against subscription capacity, not a charge or cash saving'
    }
    selected_model = $finalRecommended
    surface = $top.surface
    role = $roleNorm
    adequacy = $adequacy
    reason_codes = $why
}
if ($fallback) {
    $result.fallback = [ordered]@{ id=$fallback.id; access=$fallback.access; total=$fallback.total }
    $result['fallback_model'] = [string]$fallback.id
} else {
    $result['fallback_model'] = $null
}
if ($diagnosisModel) { $result['diagnosis_model'] = [ordered]@{ id=$diagnosisModel.id; access=$diagnosisModel.access; total=$diagnosisModel.total } }

$result | ConvertTo-Json -Depth 6
