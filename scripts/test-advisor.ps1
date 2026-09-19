<# Executable regression tests for deterministic evidence-aware selection (no web calls).
Invokes scripts/select-model.ps1 with fixed task specs and asserts outputs differ
by requirements - not by prompt text. Also proves history wiring, freshness source,
encoding, and structural invariants. Windows PowerShell 5.1 compatible. #>
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$fail = 0
function Pass([string]$m) { Write-Output "PASS: $m" }
function Fail([string]$m) { $script:fail++; Write-Output "FAIL: $m" }

$rosterPath = Join-Path $ToolkitRoot 'routing\model-roster.json'
$statePath = Join-Path $ToolkitRoot 'routing\state.json'
$evidencePath = Join-Path $ToolkitRoot 'routing\model-evidence.json'
$historyPath = Join-Path $ToolkitRoot 'routing\task-history.json'
$policyPath = Join-Path $ToolkitRoot 'routing\policy.json'
$selectorPath = Join-Path $ToolkitRoot 'scripts\select-model.ps1'
$recordPath = Join-Path $ToolkitRoot 'scripts\record-task-outcome.ps1'

try { $roster = Get-Content -LiteralPath $rosterPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail 'roster is malformed JSON'; $roster = $null }
try { $st = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail 'state is malformed JSON'; $st = $null }
try { $ev = Get-Content -LiteralPath $evidencePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail 'evidence is malformed JSON'; $ev = $null }
try { $policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail 'policy is malformed JSON'; $policy = $null }
if ($roster -and $st -and $ev -and $policy) { Pass 'roster/state/evidence/policy are well-formed JSON' }
if (-not (Test-Path -LiteralPath $selectorPath)) { Fail 'scripts/select-model.ps1 missing' } else { Pass 'deterministic selector present' }

function Invoke-Selection([string[]]$TaskTypes, $Writes, $Terminal, [int]$Ctx, $Deep, $Diversity, $Conseq) {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $selectorPath -TaskType $TaskTypes -NeedsWrites:$Writes -NeedsTerminal:$Terminal -NeedsLargeContextTokens $Ctx -NeedsDeepReasoning:$Deep -NeedsModelDiversity:$Diversity -HighConsequence:$Conseq 2>$null
    if ($LASTEXITCODE -ne 0) { throw "select-model failed for $($TaskTypes -join ',')" }
    return (($out -join "`n") | ConvertFrom-Json)
}

function Get-CanonicalKey($Evidence, [string]$RosterId) {
    foreach ($p in @($Evidence.alias_index.PSObject.Properties)) { if ($p.Name -eq $RosterId) { return [string]$p.Value } }
    return $null
}

# E1: trivial simple edit stays inexpensive and in Build without research.
try {
    $e1 = Invoke-Selection @('simple_edit') $false $false 0 $false $false $false
    if ($e1.recommended -match '^opencode/') { Pass 'E1 trivial edit recommends hosted free model' }
    else { Fail ("E1 trivial edit not on hosted free model: " + $e1.recommended) }
    if ($e1.execution_surface -eq 'build') { Pass 'E1 trivial edit stays in build' }
    else { Fail ("E1 wrong surface: " + $e1.execution_surface) }
    if (-not $e1.needs_research) { Pass 'E1 trivial task uses cache, no research' }
    else { Fail 'E1 trivial task incorrectly demands research' }
} catch { Fail ("E1 selector error: " + $_.Exception.Message) }

# E2: hard architecture refactor goes subscription via promotion/delegation, unlike E1.
try {
    $e2 = Invoke-Selection @('architecture','large_refactor') $true $false 500000 $true $false $true
    if ($e2.recommended -match '^(openai|github-copilot)/') { Pass 'E2 hard refactor recommends frontier subscription model' }
    else { Fail ("E2 hard refactor not subscription: " + $e2.recommended) }
    if ($e2.execution_surface -eq '@deep chunk' -or $e2.execution_surface -eq '/models switch') { Pass ("E2 hard refactor promotes/delegates (" + $e2.execution_surface + ")") }
    else { Fail ("E2 wrong surface: " + $e2.execution_surface) }
    if ($e1 -and ($e2.recommended -ne $e1.recommended)) { Pass 'E2 differs from trivial E1 by requirements' }
    elseif ($e1) { Fail 'E2 same model as trivial E1 despite different requirements' }
} catch { Fail ("E2 selector error: " + $_.Exception.Message) }

# E3/E4: DexFraggler review-only vs review+repair must produce different recommendations.
$dexReviewOnly = $null
$dexRepair = $null
try {
    $dexReviewOnly = Invoke-Selection @('code_review','independent_verification','long_context_reading') $false $false 500000 $false $true $false
    if ($dexReviewOnly.execution_surface -eq '@review') {
        if ($dexReviewOnly.recommended -eq $st.review) { Pass 'E3 @review surface matches the configured Review role' }
        else { Fail 'E3 @review would execute a different model than the recommendation' }
    } elseif ($dexReviewOnly.execution_surface -eq '/models switch' -or $dexReviewOnly.execution_surface -eq 'build') {
        Pass ("E3 review-only uses honest surface for selected model (" + $dexReviewOnly.execution_surface + ")")
    } else { Fail ("E3 wrong surface: " + $dexReviewOnly.execution_surface) }
    if (@($dexReviewOnly.phases).Count -eq 1) { Pass 'E3 single diagnosis phase' }
    else { Fail 'E3 should have exactly one phase' }
} catch { Fail ("E3 selector error: " + $_.Exception.Message) }
try {
    $dexRepair = Invoke-Selection @('code_review','debugging','terminal_heavy') $true $true 500000 $true $true $true
    if ($dexRepair.execution_surface -eq 'combination') { Pass 'E4 DexFraggler review+repair uses combination surface' }
    else { Fail ("E4 wrong surface: " + $dexRepair.execution_surface) }
    if (@($dexRepair.phases).Count -eq 2) { Pass 'E4 splits Phase1 diagnosis + Phase2 repair' }
    else { Fail 'E4 should have exactly two phases' }
    $p1 = @($dexRepair.phases | Where-Object { $_.phase -eq 1 })[0]
    $p2 = @($dexRepair.phases | Where-Object { $_.phase -eq 2 })[0]
    if ($p1 -and $p2 -and $p1.model -ne $p2.model) {
        $p1Ok = (($p1.surface -eq '@review' -and $p1.model -eq $st.review) -or ($p1.surface -eq '/models switch') -or ($p1.surface -eq 'build'))
        $p2Ok = (($p2.surface -eq '@deep chunk' -and $p2.model -eq $st.deep) -or ($p2.surface -eq '/models switch') -or ($p2.surface -eq 'build'))
        if ($p1Ok -and $p2Ok) { Pass 'E4 phase models and execution surfaces are internally consistent' }
        else { Fail 'E4 phase surface names do not match the models they would actually execute' }
    } else { Fail 'E4 phase separation invalid (needs_writes must reject sole @review)' }
    if ($p1 -and $dexRepair.execution_surface -eq '@review') { Fail 'E4 must not collapse to sole @review when needs_writes=true' }
} catch { Fail ("E4 selector error: " + $_.Exception.Message) }
if ($dexReviewOnly -and $dexRepair) {
    if (($dexReviewOnly.recommended -ne $dexRepair.recommended) -or ($dexReviewOnly.execution_surface -ne $dexRepair.execution_surface)) {
        Pass ("E3/E4 DexFraggler requirements change recommendation (" + $dexReviewOnly.recommended + " " + $dexReviewOnly.execution_surface + " -> " + $dexRepair.recommended + " " + $dexRepair.execution_surface + ")")
    } else { Fail 'E3/E4 identical despite changed requirements (needs_writes/terminal/deep)' }
    Write-Output ("INFO: DexFraggler review-only  = " + $dexReviewOnly.recommended + " via " + $dexReviewOnly.execution_surface)
    Write-Output ("INFO: DexFraggler review+repair = " + $dexRepair.recommended + " via " + $dexRepair.execution_surface + " (Phase1 " + $dexRepair.diagnosis_model.id + ")")
}

# E5: history wiring - 3 failures for the trivial winner must move the ranking.
try {
    $before = Invoke-Selection @('simple_edit') $false $false 0 $false $false $false
    $topId = [string]$before.top_scored
    $secondId = $null
    if ($before.fallback -and $before.fallback.id) { $secondId = [string]$before.fallback.id }
    if (-not $secondId) { Fail 'E5 cannot determine fallback for history test'; throw 'no fallback' }
    $histBak = $null; $rosterBak = $null
    if (Test-Path -LiteralPath $historyPath) { $histBak = Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 }
    if (Test-Path -LiteralPath $rosterPath) { $rosterBak = Get-Content -LiteralPath $rosterPath -Raw -Encoding UTF8 }
    try {
        for ($i = 1; $i -le 3; $i++) {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recordPath -Repo 'advisor-test' -TaskType @('simple_edit') -Model $topId -Access 'test' -Success:$false -TestsPassed:$false -Attempts 1 -Escalated:$false -ElapsedBand 'minutes' | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'record-task-outcome failed' }
        }
        $after = Invoke-Selection @('simple_edit') $false $false 0 $false $false $false
        $hit = @($after.top_scores | Where-Object { $_.id -eq $topId })[0]
        if ($hit -and $hit.hist_n -ge 3) { Pass ("E5 history wired into selection (n=" + $hit.hist_n + " for $topId)") }
        else { Fail 'E5 selector did not see recorded history (n<3)' }
        if ([string]$after.top_scored -ne $topId) { Pass ("E5 3 failures move trivial ranking ($topId -> " + $after.top_scored + ")") }
        else { Fail ("E5 ranking unchanged despite 3 failures for $topId") }
        $rosterCheck = Get-Content -LiteralPath $rosterPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $obs = $null
        foreach ($rm in @($rosterCheck.eligible_models)) { if ($rm.id -eq $topId) { $obs = $rm.observed; break } }
        if ($obs -and $obs.total -ge 3) { Pass 'E5 roster observed synced from history' }
        else { Fail 'E5 roster observed not synced' }
    } finally {
        if ($null -ne $histBak) {
            $enc = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($historyPath, $histBak, $enc)
        }
        if ($null -ne $rosterBak) {
            $enc2 = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($rosterPath, $rosterBak, $enc2)
        }
    }
} catch { Fail ("E5 history test error: " + $_.Exception.Message) }

# E6: freshness comes from evidence_as_of (UTC date), never roster.generated_at.
try {
    $probe = Invoke-Selection @('simple_edit') $false $false 0 $false $false $false
    $expected = 'UNPOPULATED'
    $age = $null
    if ($ev.evidence_as_of -and ("$($ev.evidence_as_of)".Trim() -ne '')) {
        $asOf = [DateTime]"$($ev.evidence_as_of)"
        $age = (((Get-Date).ToUniversalTime().Date) - $asOf.Date).Days
        if ($age -le 1) { $expected = 'current' } elseif ($age -le 3) { $expected = 'partially stale' } elseif ($age -le 7) { $expected = 'stale' } else { $expected = 'very stale' }
    }
    if ([string]$probe.evidence_freshness -eq $expected) { Pass ("E6 freshness from evidence_as_of ($expected)") }
    else { Fail ("E6 freshness mismatch: selector=" + $probe.evidence_freshness + " expected=" + $expected) }
    $utcOk = $true
    foreach ($p in @($rosterPath, $statePath)) {
        try { $j = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json; [DateTime]$j.generated_at | Out-Null } catch { $utcOk = $false }
    }
    if ($utcOk) { Pass 'E6 roster/state timestamps are parseable ISO-8601' } else { Fail 'E6 bad generated_at format' }
} catch { Fail ("E6 freshness error: " + $_.Exception.Message) }

# E7: encoding - generated markdown must not contain mojibake.
# Bad patterns built from char codes so this script stays ASCII-only (PS 5.1 safe).
try {
    $emDashMojibake = [string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201D)
    $enDashMojibake = [string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x201C)
    $eAcuteMojibake = [string]([char]0x00C3) + [string]([char]0x00A9)
    $nbspMojibake = [string]([char]0x00C2) + [string]([char]0x00A0)
    $bad = @($emDashMojibake, $enDashMojibake, $eAcuteMojibake, $nbspMojibake)
    $foundBad = @()
    foreach ($f in @((Join-Path $ToolkitRoot 'opencode\global-instructions.md'), (Join-Path $ToolkitRoot 'opencode\agents\build.md'), (Join-Path $ToolkitRoot 'opencode\agents\deep.md'), (Join-Path $ToolkitRoot 'opencode\agents\review.md'))) {
        if (Test-Path -LiteralPath $f) {
            $t = Get-Content -LiteralPath $f -Raw -Encoding UTF8
            foreach ($b in $bad) { if ($t.Contains($b)) { $foundBad += ([IO.Path]::GetFileName($f) + ":" + $b) } }
        }
    }
    if ($foundBad.Count -eq 0) { Pass 'E7 no mojibake in generated instructions/agents (UTF8 clean)' }
    else { Fail ("E7 mojibake found: " + ($foundBad -join ', ')) }
} catch { Fail ("E7 encoding error: " + $_.Exception.Message) }

# E8: legacy benchmark versions never decide ranking (grok TB2.1 must not top terminal work).
try {
    $term = Invoke-Selection @('debugging','terminal_heavy') $true $true 0 $true $false $false
    if ($term.top_scored -notmatch 'grok') { Pass 'E8 legacy TB2.1 evidence does not top terminal ranking' }
    else { Fail ("E8 legacy benchmark topped ranking: " + $term.top_scored) }
    $notes = ($term.why -join "`n")
    if ($notes -notmatch '2\.1') { Pass 'E8 selector reasoning excludes legacy version from bonus' }
    else { Fail 'E8 legacy version leaked into ranking bonus' }
} catch { Fail ("E8 benchmark error: " + $_.Exception.Message) }

# E9: an explicit diversity request should not reuse the excluded canonical model,
# and should prefer a different model vendor when evidence is otherwise competitive.
try {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $selectorPath -TaskType @('code_review','independent_verification') -NeedsWrites:$false -NeedsModelDiversity:$true -ExcludeModel $st.deep 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'select-model diversity probe failed' }
    $div = (($out -join "`n") | ConvertFrom-Json)
    $deepCanon = Get-CanonicalKey $ev $st.deep
    $recCanon = Get-CanonicalKey $ev $div.recommended
    if ($deepCanon -and $recCanon -and $deepCanon -ne $recCanon) { Pass 'E9 diversity excludes the Deep canonical model from Review selection' }
    else { Fail 'E9 diversity reused the Deep canonical model' }

    function ProviderFor([string]$rid) {
        $ck = Get-CanonicalKey $ev $rid
        foreach ($p in @($ev.models.PSObject.Properties)) {
            if ($p.Name -eq $ck -and $p.Value.provider) { return ([string]$p.Value.provider).ToLower() }
        }
        return ''
    }
    $deepProvider = ProviderFor $st.deep
    $recProvider = ProviderFor $div.recommended
    if ($deepProvider -and $recProvider -and $deepProvider -ne $recProvider) { Pass 'E9 diversity selected a different model vendor from Deep' }
    else { Write-Output ("INFO: E9 selected same vendor despite diversity preference: " + $div.recommended) }
} catch { Fail ("E9 diversity error: " + $_.Exception.Message) }

# E10: a later Review can update the original task observation by TaskId
# without appending a disconnected second record.
try {
    $histBak2 = $null; $rosterBak2 = $null
    if (Test-Path -LiteralPath $historyPath) { $histBak2 = Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 }
    if (Test-Path -LiteralPath $rosterPath) { $rosterBak2 = Get-Content -LiteralPath $rosterPath -Raw -Encoding UTF8 }
    try {
        $tid = 'advisor-review-link-test'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recordPath -Repo 'advisor-test' -TaskType @('bounded_feature') -Model $st.routine -Access 'test' -Success:$true -TestsPassed:$true -Attempts 1 -Escalated:$false -ElapsedBand 'short' -TaskId $tid | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'initial task history record failed' }
        $beforeMark = Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $countBeforeMark = @($beforeMark.entries).Count
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recordPath -TaskId $tid -MarkReviewDefect | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'review-defect update failed' }
        $afterMark = Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $linked = @($afterMark.entries | Where-Object { $_.task_id -eq $tid })[0]
        if ($linked -and $linked.review_found_defects -eq $true -and @($afterMark.entries).Count -eq $countBeforeMark) {
            Pass 'E10 review defect updates the original task observation'
        } else { Fail 'E10 review defect was not linked to the original task' }
    } finally {
        if ($null -ne $histBak2) {
            $enc3 = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($historyPath, $histBak2, $enc3)
        }
        if ($null -ne $rosterBak2) {
            $enc4 = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($rosterPath, $rosterBak2, $enc4)
        }
    }
} catch { Fail ("E10 task linkage error: " + $_.Exception.Message) }

# E11: index/free-fallback lane stays on the routine hosted-free model.
try {
    if($st.index -eq $st.routine -and $st.free_fallback -eq $st.routine -and $st.routine -match '^opencode/'){
        Pass 'E11 Index and free fallback remain hosted-free routing preferences'
    } else {
        Fail ("E11 index/free fallback mismatch: routine=" + $st.routine + " index=" + $st.index + " fallback=" + $st.free_fallback)
    }
    $indexAgent=Get-Content -LiteralPath (Join-Path $ToolkitRoot 'opencode\agents\index.md') -Raw -Encoding UTF8
    if($indexAgent.Contains("model: $($st.routine)")){Pass 'E11 generated Index agent uses Routine model'}else{Fail 'E11 generated Index agent model does not match Routine'}
} catch { Fail ("E11 index lane error: " + $_.Exception.Message) }

# E12: local model engines are outside the eligible/routing surface.
try {
    $localEligible=@($roster.eligible_models | Where-Object { $_.surface -eq 'ollama-local' -or $_.id -match '^ollama/' })
    if($localEligible.Count -eq 0){Pass 'E12 no local-model entries in eligible roster'}else{Fail 'E12 local-model entry remains eligible'}
    if(@($policy.allowed_surfaces) -notcontains 'ollama-local'){Pass 'E12 local-model surface removed from policy'}else{Fail 'E12 policy still allows local-model surface'}
} catch { Fail ("E12 local-engine exclusion error: " + $_.Exception.Message) }

# E13: paid recommendations always expose a hosted-free fallback.
try {
    $paidProbe = Invoke-Selection @('architecture','debugging','terminal_heavy') $true $true 128000 $true $false $true
    if ($paidProbe.recommended -match '^(openai|github-copilot)/') {
        if ($paidProbe.fallback -and $paidProbe.fallback.id -match '^opencode/') {
            Pass ("E13 paid recommendation has hosted-free fallback (" + $paidProbe.fallback.id + ")")
        } else { Fail 'E13 paid recommendation lacks hosted-free fallback' }
    } else {
        Pass 'E13 probe selected hosted-free model; paid fallback requirement not applicable'
    }
} catch { Fail ("E13 free fallback error: " + $_.Exception.Message) }

function Invoke-SelectionWithRole([string[]]$TaskTypes, $Writes, $Terminal, [int]$Ctx, $Deep, $Diversity, $Conseq, [string]$Role, [string]$PrefCost, [string]$Exclude) {
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$selectorPath,'-TaskType',$TaskTypes)
    if ($Writes) { $argList += @('-NeedsWrites:$true') } else { $argList += @('-NeedsWrites:$false') }
    if ($Terminal) { $argList += @('-NeedsTerminal:$true') } else { $argList += @('-NeedsTerminal:$false') }
    $argList += @('-NeedsLargeContextTokens',$Ctx)
    if ($Deep) { $argList += @('-NeedsDeepReasoning:$true') } else { $argList += @('-NeedsDeepReasoning:$false') }
    if ($Diversity) { $argList += @('-NeedsModelDiversity:$true') } else { $argList += @('-NeedsModelDiversity:$false') }
    if ($Conseq) { $argList += @('-HighConsequence:$true') } else { $argList += @('-HighConsequence:$false') }
    if ($Role -ne '') { $argList += @('-Role',$Role) }
    if ($PrefCost -ne '') { $argList += @('-PreferredCostClass',$PrefCost) }
    if ($Exclude -ne '') { $argList += @('-ExcludeModel',$Exclude) }
    $out = & powershell.exe @argList 2>$null
    if ($LASTEXITCODE -ne 0) { throw "select-model failed for $($TaskTypes -join ',') role=$Role" }
    return (($out -join "`n") | ConvertFrom-Json)
}

# E14: worker-role bounded work selects an adequately qualified free model.
try {
    $e14 = Invoke-SelectionWithRole @('bounded_feature') $true $false 0 $false $false $false 'worker' '' ''
    if ($e14.selected_model -match '^opencode/') { Pass 'E14 worker role selects hosted free model for bounded work' }
    else { Fail ("E14 worker role not on hosted free model: " + $e14.selected_model) }
    if ($e14.adequacy -eq 'strong' -or $e14.adequacy -eq 'adequate') { Pass ("E14 worker selection adequacy: " + $e14.adequacy) }
    else { Fail ("E14 worker adequacy too weak: " + $e14.adequacy) }
    if (-not $e14.needs_research) { Pass 'E14 worker delegation uses cache, no research' }
    else { Fail 'E14 worker delegation incorrectly demands research' }
} catch { Fail ("E14 worker role error: " + $_.Exception.Message) }

# E15: delegation contract fields are present and consistent.
try {
    $e15 = Invoke-SelectionWithRole @('bounded_feature') $true $false 0 $false $false $false 'worker' '' ''
    $contractOk = $true
    if (-not $e15.selected_model -or $e15.selected_model -ne $e15.recommended) { $contractOk = $false }
    if (-not $e15.surface) { $contractOk = $false }
    if ($e15.role -ne 'worker') { $contractOk = $false }
    if (-not $e15.adequacy) { $contractOk = $false }
    if ($null -eq $e15.reason_codes -or @($e15.reason_codes).Count -eq 0) { $contractOk = $false }
    if (-not $e15.fallback_model) { $contractOk = $false }
    if (-not $e15.evidence_readiness) { $contractOk = $false }
    if ($contractOk) { Pass 'E15 delegation contract fields present and consistent' }
    else { Fail 'E15 delegation contract fields missing or inconsistent' }
} catch { Fail ("E15 contract error: " + $_.Exception.Message) }

# E16: an explicitly excluded model never wins.
try {
    $base = Invoke-SelectionWithRole @('bounded_feature') $true $false 0 $false $false $false 'worker' '' ''
    $excluded = [string]$base.selected_model
    $e16 = Invoke-SelectionWithRole @('bounded_feature') $true $false 0 $false $false $false 'worker' '' $excluded
    if ([string]$e16.selected_model -ne $excluded) { Pass ("E16 excluded model does not win ($excluded -> " + $e16.selected_model + ")") }
    else { Fail ("E16 excluded model still selected: " + $excluded) }
} catch { Fail ("E16 exclusion error: " + $_.Exception.Message) }

# E17: a model lacking required context is filtered with a context reason.
try {
    $e17 = Invoke-SelectionWithRole @('long_context_reading') $false $false 900000 $false $false $false '' '' ''
    $ctxFiltered = @($e17.filtered_out | Where-Object { $_.reason -match 'context' })
    if ($ctxFiltered.Count -gt 0) { Pass ("E17 insufficient-context models filtered (" + $ctxFiltered.Count + " with context reason)") }
    else { Fail 'E17 no context-based filtering observed for 900K requirement' }
} catch { Fail ("E17 context filter error: " + $_.Exception.Message) }

# E18: review role with diversity excludes the implementation (Deep) model.
try {
    $e18 = Invoke-SelectionWithRole @('code_review','independent_verification') $false $false 0 $false $true $false 'review' '' $st.deep
    $deepCanon = Get-CanonicalKey $ev $st.deep
    $recCanon = Get-CanonicalKey $ev $e18.selected_model
    if ($deepCanon -and $recCanon -and $deepCanon -ne $recCanon) { Pass 'E18 review role excludes the Deep canonical model' }
    else { Fail 'E18 review role reused the Deep canonical model' }
} catch { Fail ("E18 review diversity error: " + $_.Exception.Message) }

# E19: index role with free preference stays on a free candidate.
try {
    $e19 = Invoke-SelectionWithRole @('research') $false $false 0 $false $false $false 'index' 'free' ''
    if ($e19.selected_model -match '^opencode/') { Pass 'E19 index role stays free-biased' }
    else { Fail ("E19 index role not on free model: " + $e19.selected_model) }
} catch { Fail ("E19 index bias error: " + $_.Exception.Message) }

# E20: identical inputs/evidence produce deterministic output.
try {
    $e20a = Invoke-SelectionWithRole @('debugging') $true $false 0 $false $false $false 'worker' '' ''
    $e20b = Invoke-SelectionWithRole @('debugging') $true $false 0 $false $false $false 'worker' '' ''
    $ta = @($e20a.top_scores | Where-Object { $_.id -eq $e20a.selected_model })[0]
    $tb = @($e20b.top_scores | Where-Object { $_.id -eq $e20b.selected_model })[0]
    if ($e20a.selected_model -eq $e20b.selected_model -and $ta -and $tb -and $ta.total -eq $tb.total) {
        Pass 'E20 deterministic output for identical inputs/evidence'
    } else { Fail 'E20 nondeterministic selection output' }
} catch { Fail ("E20 determinism error: " + $_.Exception.Message) }

# E21: ordinary selection has no side effects on routing files (parent state untouched).
try {
    function File-Hash([string]$p) {
        if (-not (Test-Path -LiteralPath $p)) { return '' }
        return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
    }
    $h1 = @($rosterPath, $statePath, $evidencePath, $historyPath) | ForEach-Object { File-Hash $_ }
    [void](Invoke-SelectionWithRole @('bounded_feature') $true $false 0 $false $false $false 'worker' '' '')
    $h2 = @($rosterPath, $statePath, $evidencePath, $historyPath) | ForEach-Object { File-Hash $_ }
    $same = $true
    for ($i = 0; $i -lt $h1.Count; $i++) { if ($h1[$i] -ne $h2[$i]) { $same = $false; break } }
    if ($same) { Pass 'E21 selection is read-only over roster/state/evidence/history' }
    else { Fail 'E21 selection modified routing files' }
} catch { Fail ("E21 side-effect error: " + $_.Exception.Message) }

# E22: no live web research occurs during ordinary selection (static check).
try {
    $selText = Get-Content -LiteralPath $selectorPath -Raw -Encoding UTF8
    $webCalls = @('Invoke-WebRequest','Invoke-RestMethod','System.Net.WebClient','System.Net.Http.HttpClient','Start-BitsTransfer')
    $foundWeb = @()
    foreach ($w in $webCalls) { if ($selText.Contains($w)) { $foundWeb += $w } }
    if ($foundWeb.Count -eq 0) { Pass 'E22 selector performs no live web calls' }
    else { Fail ("E22 selector contains web calls: " + ($foundWeb -join ', ')) }
} catch { Fail ("E22 web-check error: " + $_.Exception.Message) }

# Structural: alias coverage, lanes eligible, OAuth gating, no metered, no Plan, provenance.
$unmapped = @()
foreach ($rid in @($roster.eligible_models | ForEach-Object { $_.id })) {
    if (-not (Get-CanonicalKey $ev $rid)) { $unmapped += $rid }
}
if ($unmapped.Count -eq 0) { Pass 'S1 all eligible roster IDs map to canonical evidence entries' }
else { Fail ("S1 unmapped roster IDs: " + ($unmapped -join ', ')) }
$allIds = @($roster.eligible_models | ForEach-Object { $_.id })
if ($allIds -contains $st.deep -and $allIds -contains $st.review -and $allIds -contains $st.routine -and $allIds -contains $st.worker) { Pass 'S2 lanes (incl. worker) reference eligible roster models' }
else { Fail 'S2 lane references model outside eligible roster' }
if (($st.deep -match '^openai/' -and -not $st.oauth.openai) -or ($st.review -match '^github-copilot/' -and -not $st.oauth.github_copilot)) { Fail 'S3 subscription lane without matching OAuth' }
else { Pass 'S3 OAuth gating holds for subscription lanes' }
$forbidden = @('openrouter', 'vercel', 'anthropic', 'google', 'xai', 'groq', 'together', 'fireworks')
$badLane = $false
foreach ($f in $forbidden) { if ($st.deep -match "^$f" -or $st.review -match "^$f" -or $st.routine -match "^$f") { $badLane = $true } }
if (-not $badLane) { Pass 'S4 no metered/excluded provider in automatic lanes' } else { Fail 'S4 metered provider in automatic lane' }
$planForced = $false
foreach ($cmdFile in Get-ChildItem -LiteralPath (Join-Path $ToolkitRoot 'opencode\commands') -File -Filter '*.md') {
    $t = Get-Content -LiteralPath $cmdFile.FullName -Raw -Encoding UTF8
    if ($t -match '(?m)^agent:\s*plan\s*$') { $planForced = $true; Fail ("command forces Plan: " + $cmdFile.Name) }
}
if (-not $planForced) { Pass 'S5 no command silently enters Plan' }
$compatLedger = $false
foreach ($mprop in @($ev.models.PSObject.Properties)) {
    foreach ($b in @($mprop.Value.benchmarks)) { if ($b.comparability -or $b.harness) { $compatLedger = $true; break } }
    if ($compatLedger) { break }
}
if ($compatLedger) { Pass 'S6 benchmark harness/comparability recorded in ledger' } else { Fail 'S6 benchmark comparability guard missing' }
$indepSources = @($ev.sources.PSObject.Properties | Where-Object { $_.Value.source_type -eq 'INDEPENDENT' }).Count
if ($indepSources -ge 1) { Pass 'S7 independent provenance present' } else { Fail 'S7 no independent sources' }
try {
    $h = Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $h.entries) { Pass 'S8 task-history.json valid with entries array' } else { Fail 'S8 history lacks entries array' }
} catch { Fail 'S8 history malformed' }

Write-Output ''
if ($fail -gt 0) { Write-Output "Advisor regression: $fail failure(s)."; exit 1 } else { Write-Output 'Advisor regression: all checks passed.'; exit 0 }
