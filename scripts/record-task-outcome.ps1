# Record task outcome for local learning
# Boolean flags accept $True/$False, 1/0, or 'true'/'false' strings so the
# script also works when invoked via powershell -File (which stringifies args).
param(
    [string]$Repo,
    [string[]]$TaskType,
    [string]$Model,
    [string]$Access,
    $Success,
    $TestsPassed,
    [int]$Attempts,
    $Escalated,
    [string]$ElapsedBand,
    [string]$TaskId = '',
    $ReviewFoundDefects = $false,
    [switch]$MarkReviewDefect,
    [string]$Role = '',
    [string]$DelegatedModel = '',
    [string]$ParentModel = '',
    [switch]$MeasureStart,
    [switch]$MeasureFinalize,
    $InputTokens = $null,
    $OutputTokens = $null,
    $CacheReadTokens = $null,
    $CostDollars = $null,
    [string]$ConsumptionQuality = '',
    [string]$ConsumptionReason = ''
)

function To-Bool($v) {
    if ($v -is [bool]) { return $v }
    $s = "$v".Trim().ToLower()
    if ($s -in @('1', 'true', 'yes', '$true')) { return $true }
    return $false
}
$Success = To-Bool $Success
$TestsPassed = To-Bool $TestsPassed
$Escalated = To-Bool $Escalated
$ReviewFoundDefects = To-Bool $ReviewFoundDefects

# Normalize task types: accept a comma-separated single string as well, since
# arrays do not survive `powershell.exe -File` CLI parsing as multiple tokens
# (extra elements spill into positional parameters). Callers should prefer the
# single-string form: -TaskType "bounded_feature,architecture".
$TaskTypeNorm = @()
foreach ($t in @($TaskType)) {
    if ($null -eq $t) { continue }
    foreach ($part in ("$t".Split(','))) {
        $p = $part.Trim().ToLower()
        if ($p -ne '') { $TaskTypeNorm += $p }
    }
}
if ($TaskTypeNorm.Count -eq 0 -and -not $MarkReviewDefect) { throw '-TaskType is required (e.g. -TaskType "bounded_feature").' }

$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$HistoryPath = Join-Path $ToolkitRoot 'routing\task-history.json'
$RosterPath = Join-Path $ToolkitRoot 'routing\model-roster.json'

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

# Consumption measurement surrounds execution: baseline at dispatch, diff at
# completion. opencode stats is local session history (not an account balance),
# so attribution carries a quality flag. Go window percents are account-level
# and too coarse for per-task attribution; they are intentionally not used here.
function Parse-TokenNumber([string]$s) {
    $t = ("$s".Trim() -replace ',', '')
    if ($t -match '^([\d\.]+)\s*([KMB])?$') {
        $v = [double]$Matches[1]
        switch ($Matches[2]) {
            'K' { return $v * 1000.0 }
            'M' { return $v * 1000000.0 }
            'B' { return $v * 1000000000.0 }
        }
        return $v
    }
    return 0.0
}
function Get-StatsSnapshot() {
    $snap = [ordered]@{ captured_at = (Get-Date).ToUniversalTime().ToString('o'); parse_ok = $false; models = [ordered]@{} }
    try {
        $oc = Get-Command opencode -ErrorAction SilentlyContinue
        if (-not $oc) { return $snap }
        # Native UTF-8 box-drawing output is misdecoded under PS 5.1 console
        # code pages, so never split on the literal box character. Strip any
        # non-alphanumeric framing instead and match the inner text.
        $prevEnc = [Console]::OutputEncoding
        try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
        try {
            $raw = & $oc.Source stats --models 2>$null | ForEach-Object { $_.ToString() }
        } finally {
            try { [Console]::OutputEncoding = $prevEnc } catch {}
        }
        $cur = ''
        foreach ($line in $raw) {
            $t = "$line".Trim()
            if ($t -eq '') { continue }
            # Encoding-agnostic row detection: the model id must be the first
            # ASCII id-like token on the line. Leading framing in ANY decoded
            # form (correct box-drawing, letter-like mojibake from a wrong
            # console code page, dashes) is non-ASCII or punctuation and is
            # skipped; real words always start with ASCII letters, so a line
            # like 'Avg Cost/Day' can never be skipped over and falsely match.
            if ($t -match '^[^A-Za-z0-9$]*([A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+)\b') {
                $cur = $Matches[1]
                if (-not $snap.models.$cur) { $snap.models[$cur] = [ordered]@{ messages = 0; input = 0; output = 0; cache_read = 0; cost = 0 } }
            } elseif ($cur -ne '' -and $t -match '^[^A-Za-z0-9$]*?(Messages|Input Tokens|Output Tokens|Cache Read|Cache Write|Cost)\s+(.+?)\s*$') {
                # Same treatment for key lines: the key word is matched as the
                # first ASCII word, and trailing framing is stripped from the
                # value by charset (box bytes are always >=0x80, so they can
                # never decode to ASCII value characters like 1.2K or $0.05).
                $k = $Matches[1]; $v = ($Matches[2] -replace '[^0-9A-Za-z$%.,]+$', '').Trim()
                if ($k -eq 'Messages') { $snap.models[$cur].messages = [int](Parse-TokenNumber $v) }
                elseif ($k -eq 'Input Tokens') { $snap.models[$cur].input = (Parse-TokenNumber $v) }
                elseif ($k -eq 'Output Tokens') { $snap.models[$cur].output = (Parse-TokenNumber $v) }
                elseif ($k -eq 'Cache Read') { $snap.models[$cur].cache_read = (Parse-TokenNumber $v) }
                elseif ($k -eq 'Cost') { $snap.models[$cur].cost = (Parse-TokenNumber ($v -replace '^\$', '')) }
            }
        }
        # Honest signal: parsed only when at least one model row was read.
        # An empty shape must degrade to unmeasurable, never to measured zeros.
        if ($snap.models.Count -gt 0) { $snap.parse_ok = $true }
    } catch {}
    return $snap
}
function Get-MeasurePath([string]$TaskId, [string]$ToolkitRoot) {
    $safe = ("$TaskId" -replace '[^A-Za-z0-9_\-]', '_')
    if ($safe -eq '') { throw '-TaskId is required for measurement.' }
    $dir = Join-Path $ToolkitRoot '.state\measurements'
    return (Join-Path $dir ($safe + '.json'))
}

# Load existing history (UTF8; UTC timestamps throughout)
$historyData = $null
if (Test-Path -LiteralPath $HistoryPath) {
    try { $historyData = Get-Content -LiteralPath $HistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $historyData = $null }
}
if (-not $historyData) { $historyData = [ordered]@{generated=$true; generated_at=(Get-Date).ToUniversalTime().ToString('o'); entries=@()} }
if (-not $historyData.generated) { $historyData | Add-Member -NotePropertyName generated -NotePropertyValue $true -Force }
if ($null -eq $historyData.entries) { $historyData | Add-Member -NotePropertyName entries -NotePropertyValue @() -Force }

$now = (Get-Date).ToUniversalTime().ToString('o')
$existing = @()
if ($historyData.entries) { $existing = @($historyData.entries) }

# Baseline capture at dispatch time. No history is written in this mode.
if ($MeasureStart) {
    if (-not $TaskId) { $TaskId = [guid]::NewGuid().ToString() }
    $mp = Get-MeasurePath $TaskId $ToolkitRoot
    $mdir = Split-Path -Parent $mp
    if (-not (Test-Path -LiteralPath $mdir)) { New-Item -ItemType Directory -Path $mdir | Out-Null }
    $snap = Get-StatsSnapshot
    Write-Utf8NoBom $mp ([ordered]@{ task_id = $TaskId; baseline_at = $snap.captured_at; parse_ok = $snap.parse_ok; models = $snap.models } | ConvertTo-Json -Depth 6)
    Write-Output "Measurement baseline:"
    Write-Output "  Task ID: $TaskId"
    Write-Output ("  Stats parsed: " + $snap.parse_ok)
    Write-Output ("  Path: $mp")
    exit 0
}

function To-DoubleOrNull($v) {
    if ($null -eq $v -or ("$v".Trim() -eq '')) { return $null }
    try { return [double]"$v" } catch { return $null }
}

# A review can update the original implementation record instead of creating
# a second unrelated observation. This is the bridge that lets review quality
# influence future routing.
if ($MarkReviewDefect) {
    if (-not $TaskId) { throw '-MarkReviewDefect requires -TaskId.' }
    $updated = $false
    foreach ($e in $existing) {
        if ([string]$e.task_id -eq $TaskId) {
            $e.review_found_defects = $true
            $e | Add-Member -NotePropertyName reviewed_at -NotePropertyValue $now -Force
            $updated = $true
            break
        }
    }
    if (-not $updated) { throw "TaskId not found in task history: $TaskId" }
} else {
    if (-not $TaskId) { $TaskId = [guid]::NewGuid().ToString() }
    # Consumption attribution: explicit caller values default to estimated
    # unless the caller asserts measured provenance. A -MeasureFinalize diff
    # overrides explicit values with the snapshot computation below.
    $cIn = To-DoubleOrNull $InputTokens
    $cOut = To-DoubleOrNull $OutputTokens
    $cCache = To-DoubleOrNull $CacheReadTokens
    $cCost = To-DoubleOrNull $CostDollars
    $cQuality = ("$ConsumptionQuality".Trim().ToLower())
    if ($cQuality -eq '' -and (($null -ne $cIn) -or ($null -ne $cOut) -or ($null -ne $cCost))) { $cQuality = 'estimated' }
    $cReason = "$ConsumptionReason"
    if ($MeasureFinalize) {
        $mp = Get-MeasurePath $TaskId $ToolkitRoot
        if (-not (Test-Path -LiteralPath $mp)) { throw "No measurement baseline for TaskId: $TaskId. Run -MeasureStart at dispatch first." }
        $base = Get-Content -LiteralPath $mp -Raw -Encoding UTF8 | ConvertFrom-Json
        $after = Get-StatsSnapshot
        # Fresh snapshots carry models as an OrderedDictionary while baselines
        # rehydrated from JSON carry a PSCustomObject. PSObject.Properties on a
        # dictionary yields its .NET members (Count/Keys/...) instead of the
        # model entries, so the target lookup below would always miss and every
        # finalize would degrade to unmeasurable. Normalize to PSCustomObject.
        if ($after.models -is [System.Collections.IDictionary]) {
            $norm = New-Object PSObject
            foreach ($ak in @($after.models.Keys)) {
                $norm | Add-Member -NotePropertyName "$ak" -NotePropertyValue $after.models[$ak]
            }
            $after.models = $norm
        }
        $cQuality = 'measured'
        $cReason = ''
        if (-not $base.parse_ok -or -not $after.parse_ok) {
            $cQuality = 'unmeasurable'; $cReason = 'stats-unavailable'
            $cIn = 0; $cOut = 0; $cCache = 0; $cCost = 0
        } else {
            $mid = "$Model"
            $b = $null; $a = $null
            foreach ($p in @($base.models.PSObject.Properties)) { if ($p.Name -eq $mid) { $b = $p.Value } }
            foreach ($p in @($after.models.PSObject.Properties)) { if ($p.Name -eq $mid) { $a = $p.Value } }
            # Missing-model is explicit, never zero-defaulted into a fake diff:
            # absent from after while present in baseline means the parser lost
            # the row (stats are cumulative), so degrade to unmeasurable.
            # Absent from baseline but present in after is first-use: baseline
            # zero is valid and stays measured. Absent from both: unmeasurable.
            if ((-not $a) -and $b) {
                $cQuality = 'unmeasurable'; $cReason = 'stats-unavailable'
                $cIn = 0; $cOut = 0; $cCache = 0; $cCost = 0
            } elseif ((-not $b) -and (-not $a)) {
                $cQuality = 'unmeasurable'; $cReason = 'stats-unavailable'
                $cIn = 0; $cOut = 0; $cCache = 0; $cCost = 0
            } else {
            if (-not $b) { $b = [ordered]@{ messages = 0; input = 0; output = 0; cache_read = 0; cost = 0 } }
            $dIn = [double]$a.input - [double]$b.input
            $dOut = [double]$a.output - [double]$b.output
            $dCache = [double]$a.cache_read - [double]$b.cache_read
            $dCost = [double]$a.cost - [double]$b.cost
            if (($dIn -lt 0) -or ($dOut -lt 0) -or ($dCost -lt 0)) {
                # A quota reset or delayed reporting moved the counters. Clamp
                # to zero for display, but mark unmeasurable so the zero never
                # trains burn-rate learning as a measured free task.
                $cQuality = 'unmeasurable'; $cReason = 'counter-reset-or-delayed-reporting'
                $cIn = 0; $cOut = 0; $cCache = 0; $cCost = 0
            } else {
                # Concurrent activity elsewhere in the account pollutes the
                # model-specific delta. Compare against the all-model totals.
                $tB = 0.0; $tA = 0.0
                foreach ($p in @($base.models.PSObject.Properties)) { $tB += [double]$p.Value.input + [double]$p.Value.output }
                foreach ($p in @($after.models.PSObject.Properties)) { $tA += [double]$p.Value.input + [double]$p.Value.output }
                $other = ($tA - $tB) - ($dIn + $dOut)
                if (($other -gt 50000) -or (($dIn + $dOut) -gt 0 -and ($other / ($dIn + $dOut)) -gt 0.1)) {
                    $cQuality = 'estimated'; $cReason = 'concurrent-activity'
                }
                $cIn = $dIn; $cOut = $dOut; $cCache = $dCache; $cCost = $dCost
            }
            }
        }
        try { Remove-Item -LiteralPath $mp -Force } catch {}
    }
    $entry = [ordered]@{
        task_id = $TaskId
        timestamp = $now
        repo = $Repo
        task_type = $TaskTypeNorm
        model = $Model
        access = $Access
        success = $Success
        tests_passed = $TestsPassed
        attempts = $Attempts
        escalated = $Escalated
        review_found_defects = $ReviewFoundDefects
        elapsed_band = $ElapsedBand
        role = $Role
        delegated_model = $DelegatedModel
        parent_model = $ParentModel
    }
    if (($null -ne $cIn) -or ($null -ne $cOut) -or ($null -ne $cCost) -or ($cQuality -eq 'unmeasurable')) {
        $entry.consumption = [ordered]@{
            input_tokens = $cIn
            output_tokens = $cOut
            cache_read_tokens = $cCache
            cost_dollars = $cCost
            quality = $cQuality
            reason = $cReason
        }
    }
    $existing += $entry
}

# Keep last 50 entries, sorted by timestamp descending
if ($existing.Count -gt 50) {
    $sorted = $existing | Sort-Object -Property timestamp -Descending
    $trimmed = @()
    for ($i = 0; $i -lt 50; $i++) { $trimmed += $sorted[$i] }
    $existing = $trimmed | Sort-Object -Property timestamp
}
$historyData.entries = $existing
$historyData.generated_at = $now

Write-Utf8NoBom $HistoryPath ($historyData | ConvertTo-Json -Depth 4)

# Wire into roster observed stats so refresh-routing and select-model see real history.
# n<3 stays anecdotal in the selector; n>=3 may influence; n>=10 substantial.
try {
    if (Test-Path -LiteralPath $RosterPath) {
        $roster = Get-Content -LiteralPath $RosterPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $byModel = @{}
        foreach ($e in @($existing)) {
            $mid = [string]$e.model
            if (-not $byModel.ContainsKey($mid)) { $byModel[$mid] = @() }
            $byModel[$mid] += $e
        }
        foreach ($rm in @($roster.eligible_models)) {
            $mid = [string]$rm.id
            if ($byModel.ContainsKey($mid)) {
                $rel = @($byModel[$mid])
                $succ = @($rel | Where-Object { $_.success -eq $true }).Count
                $tests = @($rel | Where-Object { $_.tests_passed -eq $true }).Count
                $esc = @($rel | Where-Object { $_.escalated -eq $true }).Count
                $last = ($rel | Sort-Object -Property timestamp | Select-Object -Last 1).timestamp
                $rate = [Math]::Round([double]$succ / [double]$rel.Count, 3)
                $rm.observed = [ordered]@{
                    total = $rel.Count
                    successes = $succ
                    failures = ($rel.Count - $succ)
                    success_rate = $rate
                    tests_passed = $tests
                    escalated = $esc
                    last_seen = $last
                }
            }
        }
        $roster.generated_at = (Get-Date).ToUniversalTime().ToString('o')
        Write-Utf8NoBom $RosterPath ($roster | ConvertTo-Json -Depth 8)
    }
} catch {
    Write-Warning "History recorded but roster observed sync failed: $($_.Exception.Message)"
}

if ($MarkReviewDefect) {
    Write-Output "Updated task review outcome:"
    Write-Output "  Task ID: $TaskId"
    Write-Output "  Review found defects: True"
    Write-Output "  Total entries: $($existing.Count)"
    exit 0
}

Write-Output "Recorded task outcome:"
Write-Output "  Task ID: $TaskId"
Write-Output "  Repo: $Repo"
Write-Output "  Task: $($TaskTypeNorm -join ', ')"
Write-Output "  Model: $Model"
Write-Output "  Access: $Access"
Write-Output "  Success: $Success"
Write-Output "  Tests passed: $TestsPassed"
Write-Output "  Attempts: $Attempts"
Write-Output "  Elapsed band: $ElapsedBand"
if ($entry -and $entry.consumption) {
    Write-Output ("  Consumption: in=" + $entry.consumption.input_tokens + " out=" + $entry.consumption.output_tokens + " cost=$" + $entry.consumption.cost_dollars + " quality=" + $entry.consumption.quality)
    if ($entry.consumption.reason) { Write-Output ("  Consumption reason: " + $entry.consumption.reason) }
}
if ($Role) { Write-Output "  Role: $Role" }
if ($DelegatedModel) { Write-Output "  Delegated model: $DelegatedModel" }
if ($ParentModel) { Write-Output "  Parent model: $ParentModel" }
Write-Output "  Total entries: $($existing.Count)"
