<#
.SYNOPSIS
  Regenerates OpenCode Build/Index/Deep/Review model assignments from models the user can actually access.

.DESCRIPTION
  Uses only current OpenCode free SKUs, ChatGPT OAuth, and GitHub Copilot OAuth.
  Separately metered API-key/gateway providers are ignored.
  Also regenerates the model roster and the toolkit-managed global OpenCode instructions
  used for conditional next-phase model recommendations.
#>
param(
    [switch]$NoRefresh,
    [switch]$Quiet
)
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $ToolkitRoot 'opencode'
$AgentsDir = Join-Path $ConfigDir 'agents'
$Template = Join-Path $ConfigDir 'opencode.template.jsonc'
$Config = Join-Path $ConfigDir 'opencode.jsonc'
$GlobalInstructionsTemplate = Join-Path $ConfigDir 'global-instructions.template.md'
$GlobalInstructions = Join-Path $ConfigDir 'global-instructions.md'
$PolicyPath = Join-Path $ToolkitRoot 'routing\policy.json'
$StatePath = Join-Path $ToolkitRoot 'routing\state.json'
$RosterPath = Join-Path $ToolkitRoot 'routing\model-roster.json'

function Say([string]$m) { if (-not $Quiet) { Write-Output $m } }
function Write-Utf8NoBom([string]$Path,[string]$Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path,$Text,$enc)
}
function Pick-Exact($available, $priority, [string]$exclude='') {
    foreach ($candidate in @($priority)) {
        if ($candidate -ne $exclude -and $available -contains $candidate) { return $candidate }
    }
    return $null
}
function Pick-First($items, [string]$exclude='') {
    foreach ($x in @($items)) { if ($x -and $x -ne $exclude) { return $x } }
    return $null
}
function Pick-Pattern($items, $patterns, [string]$exclude='') {
    foreach ($pattern in @($patterns)) {
        foreach ($x in @($items)) {
            if ($x -ne $exclude -and $x -match $pattern) { return $x }
        }
    }
    return $null
}
function Is-FreeOpenCode([string]$m) {
    if ($m -eq 'opencode/big-pickle') { return $true }
    return ($m -match '^opencode/.+(-free|contributor-free)$')
}
function Invoke-OpenCodeCaptured([string[]]$Arguments) {
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $oc.Source @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    return [pscustomobject]@{ Output = $output; ExitCode = $exitCode }
}
function Render-Agent([string]$Name, [string]$OwnModel, [string]$RoutineModel, [string]$DeepModel, [string]$ReviewModel, [string]$WorkerModel) {
    $templatePath = Join-Path $AgentsDir "$Name.template.md"
    $outputPath = Join-Path $AgentsDir "$Name.md"
    if (-not (Test-Path -LiteralPath $templatePath)) { throw "Missing agent template: $templatePath" }
    $text = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    $text = $text.Replace('__ROUTINE_MODEL__',$RoutineModel).Replace('__DEEP_MODEL__',$DeepModel).Replace('__REVIEW_MODEL__',$ReviewModel).Replace('__WORKER_MODEL__',$WorkerModel)
    if ($Name -eq 'build') { $text = $text.Replace('__MODEL__',$RoutineModel) }
    elseif ($Name -eq 'deep') { $text = $text.Replace('__MODEL__',$DeepModel) }
    elseif ($Name -eq 'review') { $text = $text.Replace('__MODEL__',$ReviewModel) }
    elseif ($Name -eq 'index') { $text = $text.Replace('__MODEL__',$RoutineModel) }
    elseif ($Name -eq 'worker') { $text = $text.Replace('__MODEL__',$WorkerModel) }
    # Backward-compatible templates use their lane-specific placeholder as the model field.
    $text = $text.Replace("model: __ROUTINE_MODEL__","model: $RoutineModel").Replace("model: __DEEP_MODEL__","model: $DeepModel").Replace("model: __REVIEW_MODEL__","model: $ReviewModel").Replace("model: __WORKER_MODEL__","model: $WorkerModel")
    Write-Utf8NoBom $outputPath $text
}
function Surface-For([string]$Model) {
    if ($Model -match '^opencode/') { return 'opencode-free' }
    if ($Model -match '^openai/') { return 'openai-oauth' }
    if ($Model -match '^github-copilot/') { return 'github-copilot-oauth' }
    return 'unknown'
}

$oc = Get-Command opencode -ErrorAction SilentlyContinue
if (-not $oc) { throw 'OpenCode not found. Run bootstrap.cmd first.' }
$policy = Get-Content -LiteralPath $PolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json

$ocArgs = @('models')
if (-not $NoRefresh) { $ocArgs += '--refresh' }
$modelCall = Invoke-OpenCodeCaptured $ocArgs
if ($modelCall.ExitCode -ne 0) { throw "opencode models failed: $($modelCall.Output -join ' ')" }
$available = @($modelCall.Output | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -match '^[A-Za-z0-9_.-]+/.+$' } | Sort-Object -Unique)
if ($available.Count -eq 0) { throw 'OpenCode reported no available models. Connect a provider first.' }

$free = @($available | Where-Object { Is-FreeOpenCode $_ })

$authText = ''
try {
    $authCall = Invoke-OpenCodeCaptured @('auth','list')
    if ($authCall.ExitCode -eq 0) {
        $authText = ($authCall.Output | ForEach-Object { $_.ToString() }) -join "`n"
        $authText = [regex]::Replace($authText, "$([char]27)\[[0-?]*[ -/]*[@-~]", '')
    }
} catch {}
$hasOpenAIOAuth = ($authText -match '(?im)^.*OpenAI.*oauth.*$')
$hasCopilotOAuth = ($authText -match '(?im)^.*GitHub\s+Copilot.*oauth.*$')

$openai = @()
if ($hasOpenAIOAuth) { $openai = @($available | Where-Object { $_ -match '^openai/' }) }
$copilot = @()
if ($hasCopilotOAuth) {
    $copilot = @($available | Where-Object { $_ -match '^github-copilot/' -and $_ -notmatch '^github-copilot/gpt-5\.6-' })
}

# Static picks are fallback defaults only. Evidence-aware selection below overrides
# them whenever model-evidence.json + task-history.json yield a better candidate.
$routineStatic = Pick-Exact $available $policy.routine_priority
if (-not $routineStatic) { $routineStatic = Pick-First $free }
$subscriptionModels = @($openai + $copilot)
if (-not $routineStatic) { $routineStatic = Pick-First $subscriptionModels }
if (-not $routineStatic) { throw 'No eligible non-metered routine model was found.' }

$deepStatic = Pick-Exact $subscriptionModels $policy.deep_priority
if (-not $deepStatic) { $deepStatic = Pick-Pattern $subscriptionModels @('^openai/gpt-5\.6-sol','^openai/gpt-5\.6-terra','^openai/gpt-5\.5','^github-copilot/claude-opus','^github-copilot/claude-sonnet','^github-copilot/gpt-5\.5','^github-copilot/gemini.*pro') }
if (-not $deepStatic) { $deepStatic = Pick-First $subscriptionModels }
if (-not $deepStatic) { $deepStatic = Pick-Exact $available $policy.routine_priority }
if (-not $deepStatic) { $deepStatic = $routineStatic }

$reviewEligible = @(@($subscriptionModels + $free) | Sort-Object -Unique)
$reviewStatic = Pick-Exact $reviewEligible $policy.review_priority $deepStatic
if (-not $reviewStatic) {
    if ($deepStatic -match '^openai/') {
        $reviewStatic = Pick-Pattern $copilot @('^github-copilot/claude-sonnet','^github-copilot/claude-opus','^github-copilot/gpt-5\.5','^github-copilot/gemini.*pro') $deepStatic
        if (-not $reviewStatic) { $reviewStatic = Pick-First $copilot $deepStatic }
    } elseif ($deepStatic -match '^github-copilot/') {
        $reviewStatic = Pick-Pattern $openai @('^openai/gpt-5\.6-terra','^openai/gpt-5\.6-luna','^openai/gpt-5\.6-sol','^openai/gpt-5\.5') $deepStatic
        if (-not $reviewStatic) { $reviewStatic = Pick-First $openai $deepStatic }
    }
}
if (-not $reviewStatic) { $reviewStatic = Pick-First $free $deepStatic }
if (-not $reviewStatic) { $reviewStatic = $deepStatic }

$routine = $routineStatic
$deep = $deepStatic
$review = $reviewStatic
# Worker is the generic dynamic delegated execution role. Its default pins to
# the routine model; evidence-aware selection below may promote it when the
# selector finds a materially better implementation model. Per-task selection
# still happens at delegation time via the delegate tool + select-model.ps1.
$worker = $routineStatic

# ---- Deterministic evidence-aware lane selection ---------------------------
# Score the current eligible inventory with routing evidence + local history via
# scripts/select-model.ps1. Policy order remains only as a deterministic tie-breaker
# inside the selector. Static picks above survive only when the selector cannot run
# or returns a model that is no longer eligible.
function Invoke-Selector([string[]]$TaskTypes, $NeedsWrites, $NeedsTerminal, [int]$CtxTokens, $NeedsDeep, $NeedsDiversity, $HighConseq, [string]$Exclude) {
    try {
        $selScript = Join-Path $PSScriptRoot 'select-model.ps1'
        if (-not (Test-Path -LiteralPath $selScript)) { return $null }
        $excludeArgs = if ($Exclude) { @('-ExcludeModel', $Exclude) } else { @() }
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $selScript -TaskType $TaskTypes -NeedsWrites:$NeedsWrites -NeedsTerminal:$NeedsTerminal -NeedsLargeContextTokens $CtxTokens -NeedsDeepReasoning:$NeedsDeep -NeedsModelDiversity:$NeedsDiversity -HighConsequence:$HighConseq @excludeArgs 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $out) { return $null }
        $json = ($out -join "`n") | ConvertFrom-Json
        if (-not $json.recommended) { return $null }
        return $json
    } catch { return $null }
}
$evidenceFileForLanes = Join-Path $ToolkitRoot 'routing\model-evidence.json'
$selectorUsable = (Test-Path -LiteralPath $evidenceFileForLanes) -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'select-model.ps1'))
if ($selectorUsable) {
    try { Get-Content -LiteralPath $evidenceFileForLanes -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null }
    catch { $selectorUsable = $false }
}
if ($selectorUsable) {
    # Routine: ordinary implementation on an inexpensive model (writes, no deep/terminal/large-ctx).
    $r = Invoke-Selector @('simple_edit','bounded_feature') $true $false 0 $false $false $false
    if ($r -and $r.recommended -and ($available -contains $r.recommended)) {
        # Routine stays on a hosted free model whenever one is available.
        if (($r.recommended -match '^opencode/') -or $free.Count -eq 0) {
            $routine = $r.recommended
        } elseif ($free.Count -gt 0) {
            $routine = $routineStatic
        } else {
            $routine = $r.recommended
        }
    }
    # Deep: hard reasoning/terminal/large-context implementation.
    $d = Invoke-Selector @('architecture','debugging','terminal_heavy') $true $true 128000 $true $false $true
    if ($d -and $d.recommended -and ($available -contains $d.recommended)) { $deep = $d.recommended }
    # Worker: generic bounded implementation (feature work, debugging, tests).
    # Evidence-led; falls back to the routine model when the selector cannot
    # run or returns an ineligible model.
    $w = Invoke-Selector @('bounded_feature','debugging','test_generation') $true $false 0 $false $false $false
    if ($w -and $w.recommended -and ($available -contains $w.recommended)) { $worker = $w.recommended }
    else { $worker = $routine }
    # Review: independent verification, different model from Deep when possible.
    $v = Invoke-Selector @('code_review','independent_verification') $false $false 128000 $false $true $false $deep
    if ($v -and $v.recommended -and ($available -contains $v.recommended) -and ($v.recommended -ne $deep)) {
        $review = $v.recommended
    } elseif ($review -eq $deep) {
        # Preserve independence: fall back to static review when selector agrees with Deep.
        if ($reviewStatic -ne $deep -and ($available -contains $reviewStatic)) { $review = $reviewStatic }
    }
    if ($review -eq $deep) {
        # Last resort: first eligible different model so review stays independent when possible.
        $alt = @($reviewEligible | Where-Object { $_ -ne $deep } | Select-Object -First 1)
        if ($alt.Count -gt 0) { $review = $alt[0] }
    }
}

if (-not (Test-Path -LiteralPath $AgentsDir)) { New-Item -ItemType Directory -Path $AgentsDir -Force | Out-Null }
Render-Agent 'build' $routine $routine $deep $review $worker
Render-Agent 'index' $routine $routine $deep $review $worker
Render-Agent 'deep' $deep $routine $deep $review $worker
Render-Agent 'review' $review $routine $deep $review $worker
Render-Agent 'worker' $worker $routine $deep $review $worker

$templateText = Get-Content -LiteralPath $Template -Raw -Encoding UTF8
$configText = $templateText.Replace('__ROUTINE_MODEL__',$routine)
Write-Utf8NoBom $Config $configText

if (-not (Test-Path -LiteralPath $GlobalInstructionsTemplate)) { throw "Missing global instruction template: $GlobalInstructionsTemplate" }
$globalText = Get-Content -LiteralPath $GlobalInstructionsTemplate -Raw -Encoding UTF8
$globalText = $globalText.Replace('__ROUTINE_MODEL__',$routine).Replace('__DEEP_MODEL__',$deep).Replace('__REVIEW_MODEL__',$review).Replace('__WORKER_MODEL__',$worker)
Write-Utf8NoBom $GlobalInstructions $globalText

# ---- Build per-model roster objects ---------------------------------------
# Availability lives here; capability evidence lives in model-evidence.json.
# observed[] is wired from routing/task-history.json (real outcomes, not scaffolding).

function New-ModelObject([string]$Id, [string]$Surface, [string]$Economics) {
    return [ordered]@{
        id = $Id
        surface = $Surface
        economics = $Economics
        # Availability belongs in the roster. Capability claims and research
        # freshness live only in routing/model-evidence.json.
        observed = @{}
    }
}

function Get-HistoryObserved([string]$ModelId, $Entries) {
    $rel = @($Entries | Where-Object { $_.model -eq $ModelId })
    if ($rel.Count -eq 0) { return @{} }
    $succ = @($rel | Where-Object { $_.success -eq $true }).Count
    $tests = @($rel | Where-Object { $_.tests_passed -eq $true }).Count
    $esc = @($rel | Where-Object { $_.escalated -eq $true }).Count
    $last = ($rel | Sort-Object -Property timestamp | Select-Object -Last 1).timestamp
    $rate = 0.0
    if ($rel.Count -gt 0) { $rate = [Math]::Round([double]$succ / [double]$rel.Count, 3) }
    return [ordered]@{
        total = $rel.Count
        successes = $succ
        failures = ($rel.Count - $succ)
        success_rate = $rate
        tests_passed = $tests
        escalated = $esc
        last_seen = $last
    }
}

$historyPathEarly = Join-Path $ToolkitRoot 'routing\task-history.json'
$historyEntriesEarly = @()
if (Test-Path -LiteralPath $historyPathEarly) {
    try {
        $hd = Get-Content -LiteralPath $historyPathEarly -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($hd.entries) { $historyEntriesEarly = @($hd.entries) }
    } catch { $historyEntriesEarly = @() }
}

$eligibleModels = New-Object System.Collections.ArrayList
foreach ($m in @($free | Sort-Object -Unique)) {
    $o = New-ModelObject $m 'opencode-free' 'currently-free'
    $o.observed = Get-HistoryObserved $m $historyEntriesEarly
    [void]$eligibleModels.Add($o)
}
foreach ($m in @($openai | Sort-Object -Unique)) {
    $o = New-ModelObject $m 'openai-oauth' 'subscription-quota'
    $o.observed = Get-HistoryObserved $m $historyEntriesEarly
    [void]$eligibleModels.Add($o)
}
foreach ($m in @($copilot | Sort-Object -Unique)) {
    $o = New-ModelObject $m 'github-copilot-oauth' 'subscription-quota'
    $o.observed = Get-HistoryObserved $m $historyEntriesEarly
    [void]$eligibleModels.Add($o)
}

$now = (Get-Date).ToUniversalTime().ToString('o')
$state = [ordered]@{
    generated = $true
    generated_at = $now
    available_count = $available.Count
    oauth = [ordered]@{
        openai = [bool]$hasOpenAIOAuth
        github_copilot = [bool]$hasCopilotOAuth
    }
    eligible = [ordered]@{
        opencode_free = $free.Count
        openai_oauth = $openai.Count
        github_copilot_oauth = $copilot.Count
    }
    routine = $routine
    deep = $deep
    index = $routine
    worker = $worker
    review = $review
    free_fallback = $routine
    review_is_distinct_model = ($review -ne $deep)
    review_is_independent = ($review -ne $deep) # legacy field: distinct ID, not necessarily different vendor
    desktop_agents = @('build','index','worker','deep','review')
    policy = 'free OpenCode first -> bounded OAuth subscription escalation; no local engine and no metered API gateways'
    promotion = 'search/narrow with free tools first; delegate bounded hard chunks to Deep; if paid escalation is unavailable, continue on free Build/index/Explore; full-session switching remains explicit'
}
Write-Utf8NoBom $StatePath ($state | ConvertTo-Json -Depth 7)

# ---- Build full roster with capability schema ---------------------------
$roster = [ordered]@{
    generated = $true
    generated_at = $now
    assignments = [ordered]@{
        routine = [ordered]@{ id=$routine; surface=(Surface-For $routine) }
        index = [ordered]@{ id=$routine; surface=(Surface-For $routine) }
        worker = [ordered]@{ id=$worker; surface=(Surface-For $worker) }
        deep = [ordered]@{ id=$deep; surface=(Surface-For $deep) }
        review = [ordered]@{ id=$review; surface=(Surface-For $review) }
    }
    economics = [ordered]@{
        opencode_free = 'currently free hosted model; availability may change'
        openai_oauth = 'ChatGPT subscription/quota access; not API token billing'
        github_copilot_oauth = 'GitHub Copilot subscription/quota access; not API token billing'
    }
    eligible_models = @($eligibleModels)
    recommendation = [ordered]@{
        automatic_session_switch = $false
        automatic_chunk_delegation = 'Use free index/Explore/web retrieval first; Deep only when model-routing escalation criteria are met'
        end_of_task = 'recommend only when the next phase is clear and another lane has a material advantage'
        explicit_command = '/recommend-model'
    }
}
Write-Utf8NoBom $RosterPath ($roster | ConvertTo-Json -Depth 8)

# ---- Lightweight local task-history mechanism -------------------------
# Structured observation, not ML. refresh-routing never fabricates outcomes;
# it only preserves the file and refreshes its timestamp. Real writes happen
# in scripts/record-task-outcome.ps1, which also syncs roster observed stats.
$historyPath = Join-Path $ToolkitRoot 'routing\task-history.json'
if (-not (Test-Path -LiteralPath $historyPath)) {
    $init = [ordered]@{generated=$true; generated_at=(Get-Date).ToUniversalTime().ToString('o'); entries=@()}
    Write-Utf8NoBom $historyPath ($init | ConvertTo-Json -Depth 3)
}
$historyData = $null
if (Test-Path -LiteralPath $historyPath) {
    try { $historyData = Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $historyData = $null }
}
if (-not $historyData) { $historyData = [ordered]@{generated=$true; generated_at=(Get-Date).ToUniversalTime().ToString('o'); entries=@()} }
# Ensure generated_at is always current UTC; never rewrite entries here.
$historyData.generated_at = (Get-Date).ToUniversalTime().ToString('o')
if (-not $historyData.generated) { $historyData | Add-Member -NotePropertyName generated -NotePropertyValue $true -Force }
if ($null -eq $historyData.entries) { $historyData | Add-Member -NotePropertyName entries -NotePropertyValue @() -Force }
Write-Utf8NoBom $historyPath ($historyData | ConvertTo-Json -Depth 4)

# Keep the OpenCode Desktop global managed instruction block current without replacing
# any user-authored content outside the toolkit markers.
$syncScript = Join-Path $PSScriptRoot 'sync-global-instructions.ps1'
if (Test-Path -LiteralPath $syncScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syncScript | ForEach-Object { if (-not $Quiet) { Write-Output $_ } }
    if ($LASTEXITCODE -ne 0) { throw 'Could not synchronize OpenCode global instructions.' }
}

Say 'Routing refreshed:'
Say "  Build/Routine: $routine"
Say "  Index        : $routine (free retrieval helper)"
Say "  Worker       : $worker (dynamic delegated execution)"
Say "  Deep         : $deep (explicit escalation)"
Say "  Review       : $review"
if ($hasOpenAIOAuth) { Say '  OpenAI OAuth  : detected' } else { Say '  OpenAI OAuth  : not detected' }
if ($hasCopilotOAuth) { Say '  Copilot OAuth : detected' } else { Say '  Copilot OAuth : not detected' }
if ($review -eq $deep) { Say '  WARN: no distinct review model was available.' }
Say '  Promotion     : free retrieval first; bounded Deep escalation; paid failure returns to free Build/index/Explore'
Say '  Advice        : /recommend-model; conditional one-line next-phase advice enabled'

# ---- model-evidence.json (capability evidence, separate from availability) ---
# Capability evidence lives in routing/model-evidence.json and is populated by
# real web research (see the model-advisor skill and the /refresh-model-evidence
# workflow). refresh-routing never overwrites researched models/sources; it only
# guarantees the file exists and refreshes current_assignments_snapshot so the
# snapshot cannot go stale after lane changes. Timestamps are UTC ISO-8601.
$evidencePath = Join-Path $ToolkitRoot 'routing\model-evidence.json'
$evidenceNow = (Get-Date).ToUniversalTime().ToString('o')
$evidenceExists = $false
$evidenceObj = $null
if (Test-Path -LiteralPath $evidencePath) {
    try { $evidenceObj = Get-Content -LiteralPath $evidencePath -Raw -Encoding UTF8 | ConvertFrom-Json; $evidenceExists = $true } catch { $evidenceExists = $false; $evidenceObj = $null }
}
if (-not $evidenceExists) {
    $stub = [ordered]@{
        schema_version = 2
        generated_at = $evidenceNow
        evidence_as_of = $null
        advisor_readiness = 'UNPOPULATED'
        readiness_reason = 'No capability evidence yet. Run the /refresh-model-evidence workflow (web research) to populate.'
        policy = [ordered]@{
            selection_mode = 'library_first'
            lane_assignment_is_capability_evidence = $false
            needs_writes_cannot_use_read_only_review_as_sole_execution_surface = $true
            automatic_session_model_switching = $false
            api_key_metered_surfaces_eligible = $false
            benchmark_cost_is_efficiency_signal_not_user_marginal_cost = $true
            benchmark_versions_must_not_be_compared_as_same_scale = $true
            local_empirical_history_minimum_n_for_material_weight = 3
        }
        current_assignments_snapshot = [ordered]@{
            routine = [ordered]@{ id=$routine; surface=(Surface-For $routine) }
            index = [ordered]@{ id=$routine; surface=(Surface-For $routine) }
            worker = [ordered]@{ id=$worker; surface=(Surface-For $worker) }
            deep = [ordered]@{ id=$deep; surface=(Surface-For $deep) }
            review = [ordered]@{ id=$review; surface=(Surface-For $review) }
        }
        serious_candidate_set = @()
        evidence_classes = [ordered]@{
            VERIFIED_LOCAL = 'Observed in this installation or task history.'
            VERIFIED_CATALOG = 'Current provider/catalog identity or availability fact.'
            PROVIDER_REPORTED = 'Official provider documentation or release claims.'
            INDEPENDENT = 'Third-party benchmark/evaluation evidence.'
            INFERRED = 'Advisor conclusion derived from evidence; never stored as source fact.'
        }
        sources = [ordered]@{}
        alias_index = [ordered]@{}
        models = [ordered]@{}
        research_queue = [ordered]@{
            high_priority = @()
            medium_priority = @()
            deprioritized = @()
        }
    }
    Write-Utf8NoBom $evidencePath ($stub | ConvertTo-Json -Depth 4)
    Say '  Evidence      : stub created (UNPOPULATED - run /refresh-model-evidence)'
} else {
    # Preserve researched evidence; sync lane snapshot and register newly available
    # model IDs as identity-only research targets without inventing capabilities.
    try {
        if (-not $evidenceObj.alias_index) { $evidenceObj | Add-Member -NotePropertyName alias_index -NotePropertyValue ([pscustomobject]@{}) -Force }
        if (-not $evidenceObj.models) { $evidenceObj | Add-Member -NotePropertyName models -NotePropertyValue ([pscustomobject]@{}) -Force }
        if (-not $evidenceObj.research_queue) {
            $evidenceObj | Add-Member -NotePropertyName research_queue -NotePropertyValue ([pscustomobject]@{ high_priority=@(); medium_priority=@(); deprioritized=@() }) -Force
        }
        $evidenceDirty = $false
        foreach ($rm in @($eligibleModels)) {
            $rid = [string]$rm.id
            $mapped = $false
            foreach ($p in @($evidenceObj.alias_index.PSObject.Properties)) {
                if ($p.Name -eq $rid) { $mapped = $true; break }
            }
            if ($mapped) { continue }

            $safeKey = 'unresearched:' + $rid
            $providerName = ''
            if ($rid -match '^([^/]+)/') { $providerName = $Matches[1] }
            $evidenceObj.alias_index | Add-Member -NotePropertyName $rid -NotePropertyValue $safeKey -Force
            $identityEntry = [pscustomobject]@{
                provider = $providerName
                aliases = @($rid)
                research_status = 'identity_only'
                positioning = 'Newly discovered eligible model; capability evidence not yet researched.'
                context = [pscustomobject]@{ input_tokens=$null; output_tokens=$null; confidence='low' }
                capabilities = [pscustomobject]@{}
                benchmarks = @()
                efficiency = [pscustomobject]@{ interpretation='unresearched' }
                research_gaps = @('Official model documentation','Independent coding-agent evidence')
                cautions = @('Do not recommend for consequential work until current evidence is collected.')
                source_keys = @()
                last_researched_at = $null
            }
            $evidenceObj.models | Add-Member -NotePropertyName $safeKey -NotePropertyValue $identityEntry -Force
            $mq = @($evidenceObj.research_queue.medium_priority)
            if ($mq -notcontains $rid) {
                $evidenceObj.research_queue.medium_priority = @($mq + $rid)
            }
            $evidenceDirty = $true
        }

        $newSnapshot = [ordered]@{
            routine = [ordered]@{ id=$routine; surface=(Surface-For $routine) }
            index = [ordered]@{ id=$routine; surface=(Surface-For $routine) }
            worker = [ordered]@{ id=$worker; surface=(Surface-For $worker) }
            deep = [ordered]@{ id=$deep; surface=(Surface-For $deep) }
            review = [ordered]@{ id=$review; surface=(Surface-For $review) }
        }
        $storedSnapshot = $evidenceObj.current_assignments_snapshot
        if ((-not $storedSnapshot) -or ($storedSnapshot.routine.id -ne $routine) -or ($storedSnapshot.index.id -ne $routine) -or ($storedSnapshot.deep.id -ne $deep) -or ($storedSnapshot.review.id -ne $review) -or ((-not $storedSnapshot.worker) -or ($storedSnapshot.worker.id -ne $worker))) {
            $evidenceObj.current_assignments_snapshot = $newSnapshot
            $evidenceDirty = $true
        }
        if ($evidenceDirty) {
            Write-Utf8NoBom $evidencePath ($evidenceObj | ConvertTo-Json -Depth 12)
            Say '  Evidence      : preserved researched evidence; synced lane snapshot'
        } else {
            Say '  Evidence      : unchanged; left untouched'
        }
    } catch {
        Say '  Evidence      : preserved existing model-evidence.json'
    }
}
