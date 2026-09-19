<# Quota-aware routing regression tests.
Live tests use the installed Go subscription telemetry; fixture tests use
synthetic quota-state files in TEMP via -QuotaStatePath and never touch live
state or commit runtime data. Windows PowerShell 5.1 compatible. #>
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$fail = 0
function Pass([string]$m) { Write-Output "PASS: $m" }
function Fail([string]$m) { $script:fail++; Write-Output "FAIL: $m" }

$selector = Join-Path $ToolkitRoot 'scripts\select-model.ps1'
$quotaScript = Join-Path $ToolkitRoot 'scripts\refresh-quota.ps1'
$recordScript = Join-Path $ToolkitRoot 'scripts\record-task-outcome.ps1'
$liveQuota = Join-Path $ToolkitRoot '.state\quota-state.json'
$delegateTool = Join-Path $ToolkitRoot 'opencode\tools\delegate.ts'

function Invoke-Selection([hashtable]$Extra) {
    $a = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$selector,'-TaskType','bounded_feature','-Role','worker')
    foreach ($k in $Extra.Keys) { $a += @($k, $Extra[$k]) }
    $out = & powershell.exe @a 2>$null
    if ($LASTEXITCODE -ne 0) { throw ("select-model failed: " + ($out -join ' ')) }
    return (($out -join "`n") | ConvertFrom-Json)
}
function Rank-Pos($ranking, [string]$id) {
    for ($i = 0; $i -lt $ranking.Count; $i++) { if ([string]$ranking[$i].id -eq $id) { return $i } }
    return -1
}
function Write-FixtureState([string]$Path, $surfaces) {
    $st = [ordered]@{ generated = $true; generated_at = (Get-Date).ToUniversalTime().ToString('o'); surfaces = $surfaces }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, ($st | ConvertTo-Json -Depth 8), $enc)
}
function New-Surface($telemetryStatus, $extra) {
    $s = [ordered]@{
        quota_type = 'subscription'
        telemetry = [ordered]@{ status = $telemetryStatus; source = 'fixture'; as_of = (Get-Date).ToUniversalTime().ToString('o'); note = '' }
        execution = $null
    }
    foreach ($k in $extra.Keys) { $s[$k] = $extra[$k] }
    return $s
}

# Q1: live refresh writes state with all surfaces, no credential material.
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $quotaScript -ToolkitRoot $ToolkitRoot 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'refresh-quota exit code nonzero' }
    $qs = Get-Content -LiteralPath $liveQuota -Raw -Encoding UTF8 | ConvertFrom-Json
    $ok = $true
    foreach ($sn in @('opencode-go','openai-oauth','github-copilot-oauth','opencode-free')) {
        $found = $false
        foreach ($p in @($qs.surfaces.PSObject.Properties)) { if ($p.Name -eq $sn) { $found = $true } }
        if (-not $found) { $ok = $false }
    }
    $raw = Get-Content -LiteralPath $liveQuota -Raw -Encoding UTF8
    if ($raw -match 'sk-|gho_|eyJ[A-Za-z0-9]') { Fail 'Q1 quota-state.json contains credential-like material' }
    elseif (-not $ok) { Fail 'Q1 quota-state.json missing surfaces' }
    else {
        $go = $null
        foreach ($p in @($qs.surfaces.PSObject.Properties)) { if ($p.Name -eq 'opencode-go') { $go = $p.Value } }
        if ($go.telemetry.status -eq 'ok' -and $go.windows.rolling -and $go.windows.weekly -and $go.windows.monthly) {
            Pass ("Q1 live refresh ok (go rolling=" + $go.windows.rolling.used_percent + "% weekly=" + $go.windows.weekly.used_percent + "% monthly=" + $go.windows.monthly.used_percent + "%)")
        } else { Fail ("Q1 go telemetry not ok: " + $go.telemetry.status) }
    }
} catch { Fail ("Q1 live refresh error: " + $_.Exception.Message) }

# Q2: economics decide among qualified same-pool Go models (live).
try {
    $sel = Invoke-Selection @{ '-ExpectedInputTokens' = '500000'; '-ExpectedOutputTokens' = '50000'; '-ExpectedCacheReadTokens' = '2000000' }
    $lp = Rank-Pos $sel.ranking 'opencode-go/longcat-2.0'
    $qp = Rank-Pos $sel.ranking 'opencode-go/qwen3.7-max'
    if ($lp -lt 0 -or $qp -lt 0) { Fail 'Q2 go pair missing from ranking (unexpected filter)' }
    else {
        $le = $sel.ranking[$lp]; $qe = $sel.ranking[$qp]
        if ([double]$le.cap_avg -ne [double]$qe.cap_avg) { Fail 'Q2 pair capability not tied; demo premise changed' }
        # Hand-verified window-consistent math from live windows + static pricing.
        $qs = Get-Content -LiteralPath $liveQuota -Raw -Encoding UTF8 | ConvertFrom-Json
        $go = $null
        foreach ($p in @($qs.surfaces.PSObject.Properties)) { if ($p.Name -eq 'opencode-go') { $go = $p.Value } }
        $ru = [double]$go.windows.rolling.used_percent; $wu = [double]$go.windows.weekly.used_percent; $mu = [double]$go.windows.monthly.used_percent
        $maxUsed = [Math]::Max($ru, [Math]::Max($wu, $mu))
        $expL = 0.5*0.30 + 0.05*1.20 + 2.0*0.006
        $expQ = 0.5*2.50 + 0.05*7.50 + 2.0*0.50
        $qL = -(($maxUsed/100.0)*0.5) - ((($expL/60.0)*100.0)*0.3)
        $pL = [Math]::Max(($expL/(60.0*0.2)*100.0)/[Math]::Max(100.0-$ru,5.0), [Math]::Max(($expL/(60.0*0.5)*100.0)/[Math]::Max(100.0-$wu,5.0), ($expL/60.0*100.0)/[Math]::Max(100.0-$mu,5.0)))
        $qL = $qL - [Math]::Min($pL,1.0)
        if ([Math]::Abs([double]$le.quota - $qL) -gt 0.02) { Fail ("Q2 longcat quota mismatch: got " + $le.quota + " expected ~" + ([Math]::Round($qL,3))) }
        elseif ([double]$qe.quota -ne -2.5) { Fail ("Q2 qwen quota expected clamped -2.5, got " + $qe.quota) }
        elseif ($lp -ge $qp) { Fail ("Q2 economics did not order pair: longcat@$lp qwenmax@$qp") }
        else { Pass ("Q2 longcat above qwen3.7-max among qualified (quota " + $le.quota + " vs " + $qe.quota + ")") }
    }
    # Counterfactual: without token estimates only shared scarcity applies.
    $sel2 = Invoke-Selection @{}
    $lp2 = Rank-Pos $sel2.ranking 'opencode-go/longcat-2.0'
    $qp2 = Rank-Pos $sel2.ranking 'opencode-go/qwen3.7-max'
    if ([Math]::Abs([double]$sel2.ranking[$lp2].quota - [double]$sel2.ranking[$qp2].quota) -gt 0.001) {
        Fail 'Q2 counterfactual: quota differs without token estimates'
    } else { Pass 'Q2 counterfactual: no-estimate quota collapses to shared scarcity' }
} catch { Fail ("Q2 go-pair error: " + $_.Exception.Message) }

# Q3: live Copilot premium bucket governs agentic delegation (state-aware).
try {
    $sel = Invoke-Selection @{}
    $qs = Get-Content -LiteralPath $liveQuota -Raw -Encoding UTF8 | ConvertFrom-Json
    $cs = $null
    foreach ($p in @($qs.surfaces.PSObject.Properties)) { if ($p.Name -eq 'github-copilot-oauth') { $cs = $p.Value } }
    $premRem = [double]$cs.buckets.premium_interactions.percent_remaining
    $overPerm = [bool]$cs.buckets.premium_interactions.overage_permitted
    $cpRanked = @($sel.ranking | Where-Object { ([string]$_.id) -match '^github-copilot/' })
    if (($premRem -le 0) -and (-not $overPerm)) {
        if ($cpRanked.Count -eq 0) {
            $reasons = @($sel.filtered_out | Where-Object { ([string]$_.id) -match '^github-copilot/' -and ([string]$_.reason) -match 'premium_interactions' })
            if ($reasons.Count -ge 15) { Pass 'Q3 depleted premium pool blocks all 15 Copilot routes (chat-unlimited ignored)' }
            else { Fail ("Q3 only " + $reasons.Count + " copilot routes carry the premium reason") }
        } else { Fail ("Q3 depleted pool but " + $cpRanked.Count + " copilot models still rank") }
    } else {
        if ($cpRanked.Count -gt 0) { Pass ("Q3 premium pool has headroom (" + $premRem + "%); copilot routes score") }
        else { Fail 'Q3 pool has headroom but no copilot model ranks' }
    }
} catch { Fail ("Q3 copilot error: " + $_.Exception.Message) }

# Q4: OpenAI window pressure penalizes without blocking (telemetry != execution).
try {
    $sel = Invoke-Selection @{}
    $oai = @($sel.ranking | Where-Object { ([string]$_.id) -match '^openai/' } | Select-Object -First 1)
    if ($oai.Count -eq 0) { Fail 'Q4 no openai model ranks at all' }
    elseif ([double]$oai[0].quota -ge 0) { Fail 'Q4 expected negative scarcity term on 100%-used wham window' }
    else { Pass ("Q4 openai pressured but selectable (quota=" + $oai[0].quota + ")") }
} catch { Fail ("Q4 openai error: " + $_.Exception.Message) }

# Q5: fixture telemetry auth-failure blocks nothing.
try {
    $fx = Join-Path $env:TEMP 'quota_fx5.json'
    $surfaces = [ordered]@{
        'opencode-go' = (New-Surface 'auth-failed' @{})
        'openai-oauth' = (New-Surface 'unreachable' @{})
        'github-copilot-oauth' = (New-Surface 'auth-failed' @{})
        'opencode-free' = (New-Surface 'not-applicable' @{})
    }
    Write-FixtureState $fx $surfaces
    $sel = Invoke-Selection @{ '-QuotaStatePath' = $fx }
    $blocked = @($sel.filtered_out | Where-Object { ([string]$_.reason) -match 'execution blocked|pool exhausted|credit pool depleted' })
    if ($blocked.Count -gt 0) { Fail ("Q5 telemetry failure blocked routes: " + $blocked[0].id) }
    elseif (-not $sel.quota_state.fresh) { Pass 'Q5 telemetry failure is neutral; staleness reported, nothing blocked' }
    else { Fail 'Q5 fixture unexpectedly fresh' }
    Remove-Item -LiteralPath $fx -Force -ErrorAction SilentlyContinue
} catch { Fail ("Q5 fixture error: " + $_.Exception.Message) }

# Q6/Q7: unknown-reset execution blocks: future recheck blocks, spent budget allows.
try {
    $fx = Join-Path $env:TEMP 'quota_fx67.json'
    $future = (Get-Date).ToUniversalTime().AddMinutes(10).ToString('o')
    $past = (Get-Date).ToUniversalTime().AddMinutes(-10).ToString('o')
    $surfaces = [ordered]@{
        'opencode-go' = (New-Surface 'ok' @{ execution = [ordered]@{ blocked = $true; reason = 'quota_exhaustion'; reset_at = ''; recheck_at = $future; recheck_count = 1; recorded_at = (Get-Date).ToUniversalTime().ToString('o') } })
        'openai-oauth' = (New-Surface 'ok' @{})
        'github-copilot-oauth' = (New-Surface 'ok' @{ buckets = [ordered]@{ premium_interactions = [ordered]@{ unlimited = $false; percent_remaining = 80; quota_remaining = 1200; credits_used = 300; entitlement = 1500; overage_permitted = $false } }; reset_at = '2026-10-01T00:00:00.000Z' })
        'opencode-free' = (New-Surface 'not-applicable' @{})
    }
    Write-FixtureState $fx $surfaces
    $sel = Invoke-Selection @{ '-QuotaStatePath' = $fx }
    $goRanked = @($sel.ranking | Where-Object { ([string]$_.id) -match '^opencode-go/' })
    $goReasons = @($sel.filtered_out | Where-Object { ([string]$_.id) -match '^opencode-go/longcat' })
    if ($goRanked.Count -gt 0) { Fail 'Q6 blocked go surface still ranks' }
    elseif ($goReasons.Count -eq 0 -or ([string]$goReasons[0].reason) -notmatch 'recheck') { Fail 'Q6 block reason missing recheck info' }
    else { Pass 'Q6 unknown-reset block filters with bounded recheck (no immediate reselection of that pool)' }
    # Spent budget: past recheck + count 4 -> allowed with note.
    $surfaces['opencode-go'].execution.recheck_at = $past
    $surfaces['opencode-go'].execution.recheck_count = 4
    Write-FixtureState $fx $surfaces
    $sel = Invoke-Selection @{ '-QuotaStatePath' = $fx }
    $goRanked = @($sel.ranking | Where-Object { ([string]$_.id) -match '^opencode-go/' })
    if ($goRanked.Count -eq 0) { Fail 'Q7 spent recheck budget still blocks' }
    else { Pass 'Q7 spent recheck budget degrades to unknown; routes allowed' }
    Remove-Item -LiteralPath $fx -Force -ErrorAction SilentlyContinue
} catch { Fail ("Q6/Q7 fixture error: " + $_.Exception.Message) }

# Q8: fixture healthy Copilot pool differentiates per-model estimates.
try {
    $fx = Join-Path $env:TEMP 'quota_fx8.json'
    $surfaces = [ordered]@{
        'opencode-go' = (New-Surface 'ok' @{})
        'openai-oauth' = (New-Surface 'ok' @{})
        'github-copilot-oauth' = (New-Surface 'ok' @{ buckets = [ordered]@{ premium_interactions = [ordered]@{ unlimited = $false; percent_remaining = 80; quota_remaining = 1200; credits_used = 300; entitlement = 1500; overage_permitted = $false } }; reset_at = '2026-10-01T00:00:00.000Z' })
        'opencode-free' = (New-Surface 'not-applicable' @{})
    }
    Write-FixtureState $fx $surfaces
    $a = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$selector,'-TaskType','bounded_feature','-Role','worker','-QuotaStatePath',$fx,'-ExpectedInputTokens','500000','-ExpectedOutputTokens','50000','-ExpectedCacheReadTokens','2000000')
    $sel = ((& powershell.exe @a 2>$null | Out-String) | ConvertFrom-Json)
    $kp = Rank-Pos $sel.ranking 'github-copilot/kimi-k3'
    $mp = Rank-Pos $sel.ranking 'github-copilot/mai-code-1.1-flash'
    if ($kp -lt 0 -or $mp -lt 0) { Fail 'Q8 copilot pair missing from ranking' }
    elseif ([double]$sel.ranking[$mp].quota -le [double]$sel.ranking[$kp].quota) { Fail 'Q8 cheap copilot model not favored over kimi-k3' }
    else { Pass ("Q8 copilot per-model estimates differentiate (mai " + $sel.ranking[$mp].quota + " vs kimi-k3 " + $sel.ranking[$kp].quota + ")") }
    Remove-Item -LiteralPath $fx -Force -ErrorAction SilentlyContinue
} catch { Fail ("Q8 fixture error: " + $_.Exception.Message) }

# Q9: reset guard marks unmeasurable via crafted baseline.
try {
    $tid = 'quota-test-reset-guard'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recordScript -Repo '_ai-toolkit' -TaskType 'bounded_feature' -Model 'opencode-go/longcat-2.0' -Access 'opencode-go' -Success $true -TestsPassed $true -Attempts 1 -Escalated $false -ElapsedBand 'short' -TaskId $tid -MeasureStart 2>$null | Out-Null
    $mp = Join-Path $ToolkitRoot ('.state\measurements\' + $tid + '.json')
    if (-not (Test-Path -LiteralPath $mp)) { throw 'baseline not written' }
    # Inflate the baseline above any plausible live counters to force the reset guard.
    # Ensure the target entry exists first: a live snapshot shape that omits it
    # would otherwise leave nothing to inflate and the diff would read 0/measured.
    $b = Get-Content -LiteralPath $mp -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $b.parse_ok) { throw 'baseline stats unparsable (live shape changed?)' }
    $mid9 = 'opencode-go/longcat-2.0'
    $hasTarget = $false
    foreach ($p in @($b.models.PSObject.Properties)) { if ($p.Name -eq $mid9) { $hasTarget = $true } }
    if (-not $hasTarget) {
        $b.models | Add-Member -NotePropertyName $mid9 -NotePropertyValue ([ordered]@{ messages = 0; input = 0; output = 0; cache_read = 0; cost = 0 }) -Force
    }
    foreach ($p in @($b.models.PSObject.Properties)) {
        $p.Value.input = 999999999999.0; $p.Value.output = 999999999999.0; $p.Value.cost = 999999.0
    }
    $b | Add-Member -NotePropertyName parse_ok -NotePropertyValue $true -Force
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($mp, ($b | ConvertTo-Json -Depth 6), $enc)
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recordScript -Repo '_ai-toolkit' -TaskType 'bounded_feature' -Model 'opencode-go/longcat-2.0' -Access 'opencode-go' -Success $true -TestsPassed $true -Attempts 1 -Escalated $false -ElapsedBand 'short' -TaskId $tid -MeasureFinalize 2>&1
    if ($LASTEXITCODE -ne 0) { throw ("finalize failed: " + ($out -join ' ')) }
    $h = Get-Content -LiteralPath (Join-Path $ToolkitRoot 'routing\task-history.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $e = @($h.entries | Where-Object { [string]$_.task_id -eq $tid } | Select-Object -Last 1)
    if ($e.Count -eq 0 -or -not $e[0].consumption) { Fail 'Q9 consumption missing on finalized entry' }
    elseif ([string]$e[0].consumption.quality -ne 'unmeasurable') { Fail ("Q9 reset guard quality=" + $e[0].consumption.quality) }
    elseif ([double]$e[0].consumption.cost_dollars -ne 0) { Fail 'Q9 unmeasurable cost not clamped to zero' }
    else { Pass 'Q9 reset guard marks unmeasurable with zeroed display values' }
    # Clean up the synthetic history entry so fixtures never pollute learning.
    $kept = @($h.entries | Where-Object { [string]$_.task_id -ne $tid })
    $h.entries = $kept
    $h.generated_at = (Get-Date).ToUniversalTime().ToString('o')
    [System.IO.File]::WriteAllText((Join-Path $ToolkitRoot 'routing\task-history.json'), ($h | ConvertTo-Json -Depth 4), $enc)
} catch { Fail ("Q9 measurement error: " + $_.Exception.Message) }

# Q10: concurrency guard marks estimated via crafted baseline.
try {
    $tid = 'quota-test-concurrency-guard'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recordScript -Repo '_ai-toolkit' -TaskType 'bounded_feature' -Model 'opencode-go/longcat-2.0' -Access 'opencode-go' -Success $true -TestsPassed $true -Attempts 1 -Escalated $false -ElapsedBand 'short' -TaskId $tid -MeasureStart 2>$null | Out-Null
    $mp = Join-Path $ToolkitRoot ('.state\measurements\' + $tid + '.json')
    $b = Get-Content -LiteralPath $mp -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $b.parse_ok) { throw 'baseline stats unparsable (live shape changed?)' }
    # Simulate concurrent activity by depressing another REAL model's baseline
    # counters, so the live after-snapshot shows a large positive other-model
    # delta. (A synthetic baseline-only entry can never appear in the live
    # after-snapshot, which makes the other-delta negative and never trips the
    # guard.)
    $mid10 = 'opencode-go/longcat-2.0'
    $donor = $null
    foreach ($p in @($b.models.PSObject.Properties)) {
        if ($p.Name -ne $mid10 -and (([double]$p.Value.input + [double]$p.Value.output) -gt 60000)) { $donor = $p.Value; break }
    }
    if (-not $donor) { throw 'no donor model with enough volume for concurrency simulation' }
    $donor.messages = 0; $donor.input = 0; $donor.output = 0; $donor.cache_read = 0; $donor.cost = 0
    $b | Add-Member -NotePropertyName parse_ok -NotePropertyValue $true -Force
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($mp, ($b | ConvertTo-Json -Depth 6), $enc)
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recordScript -Repo '_ai-toolkit' -TaskType 'bounded_feature' -Model 'opencode-go/longcat-2.0' -Access 'opencode-go' -Success $true -TestsPassed $true -Attempts 1 -Escalated $false -ElapsedBand 'short' -TaskId $tid -MeasureFinalize 2>&1
    if ($LASTEXITCODE -ne 0) { throw ("finalize failed: " + ($out -join ' ')) }
    $h = Get-Content -LiteralPath (Join-Path $ToolkitRoot 'routing\task-history.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $e = @($h.entries | Where-Object { [string]$_.task_id -eq $tid } | Select-Object -Last 1)
    if ($e.Count -eq 0 -or -not $e[0].consumption) { Fail 'Q10 consumption missing on finalized entry' }
    elseif ([string]$e[0].consumption.quality -ne 'estimated') { Fail ("Q10 concurrency quality=" + $e[0].consumption.quality) }
    else { Pass 'Q10 concurrent activity marks consumption estimated' }
    $kept = @($h.entries | Where-Object { [string]$_.task_id -ne $tid })
    $h.entries = $kept
    $h.generated_at = (Get-Date).ToUniversalTime().ToString('o')
    [System.IO.File]::WriteAllText((Join-Path $ToolkitRoot 'routing\task-history.json'), ($h | ConvertTo-Json -Depth 4), $enc)
} catch { Fail ("Q10 measurement error: " + $_.Exception.Message) }

# Q11: delegate tool contract (expected tokens, quota, abort fields, research-free).
try {
    $dt = Get-Content -LiteralPath $delegateTool -Raw -Encoding UTF8
    $need = @('expectedInputTokens','expectedOutputTokens','ExpectedInputTokens','quota:','consumption_estimate','abort_verified','fallback_policy')
    $missing = @()
    foreach ($n in $need) { if (-not $dt.Contains($n)) { $missing += $n } }
    $webMarks = @('webfetch','websearch','fetch(','Invoke-WebRequest','HttpClient')
    $foundWeb = @()
    foreach ($w in $webMarks) { if ($dt.Contains($w)) { $foundWeb += $w } }
    if ($missing.Count -gt 0) { Fail ("Q11 delegate missing: " + ($missing -join ', ')) }
    elseif ($foundWeb.Count -gt 0) { Fail ("Q11 delegate references web: " + ($foundWeb -join ', ')) }
    else { Pass 'Q11 delegate carries quota/overage/abort contract, stays research-free' }
} catch { Fail ("Q11 delegate error: " + $_.Exception.Message) }

# Q12: worker guidance states the abort limitation and no-competing-writer rule.
try {
    $ok = $true
    foreach ($f in @('opencode\agents\worker.template.md','opencode\agents\worker.md')) {
        $t = Get-Content -LiteralPath (Join-Path $ToolkitRoot $f) -Raw -Encoding UTF8
        if (($t -notmatch 'competing writer') -or ($t -notmatch 'cannot be remotely stopped') -or ($t -notmatch 'BlockSurface')) { $ok = $false }
    }
    if ($ok) { Pass 'Q12 worker template+generated state abort limitation, no competing writer' }
    else { Fail 'Q12 worker guidance incomplete' }
} catch { Fail ("Q12 worker error: " + $_.Exception.Message) }

# Q13: determinism + backward compatibility without quota state.
try {
    $a = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$selector,'-TaskType','bounded_feature','-Role','worker')
    $r1 = ((& powershell.exe @a 2>$null | Out-String) | ConvertFrom-Json).selected_model
    $r2 = ((& powershell.exe @a 2>$null | Out-String) | ConvertFrom-Json).selected_model
    $missing = Join-Path $env:TEMP 'quota_missing.json'
    if (Test-Path -LiteralPath $missing) { Remove-Item -LiteralPath $missing -Force }
    $b = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$selector,'-TaskType','bounded_feature','-Role','worker','-QuotaStatePath',$missing)
    $r3 = ((& powershell.exe @b 2>$null | Out-String) | ConvertFrom-Json)
    if ($r1 -ne $r2) { Fail 'Q13 nondeterministic selection' }
    elseif (-not $r3.selected_model -or -not $r3.adequacy -or -not $r3.role) { Fail 'Q13 contract incomplete without quota file' }
    else { Pass ("Q13 deterministic (" + $r1 + "); contract holds without quota state") }
} catch { Fail ("Q13 determinism error: " + $_.Exception.Message) }

Write-Output ''
if ($fail -gt 0) { Write-Output "Quota regression: $fail failure(s)."; exit 1 } else { Write-Output 'Quota regression: all checks passed.'; exit 0 }
