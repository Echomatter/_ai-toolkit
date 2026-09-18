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
    [string]$ParentModel = ''
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
if ($Role) { Write-Output "  Role: $Role" }
if ($DelegatedModel) { Write-Output "  Delegated model: $DelegatedModel" }
if ($ParentModel) { Write-Output "  Parent model: $ParentModel" }
Write-Output "  Total entries: $($existing.Count)"
