<# Delegation regression tests: role permissions, topology, delegate tool/static
contract, and live selector behavior per role. No web calls.
Windows PowerShell 5.1 compatible. #>
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$fail = 0
function Pass([string]$m) { Write-Output "PASS: $m" }
function Fail([string]$m) { $script:fail++; Write-Output "FAIL: $m" }

$statePath = Join-Path $ToolkitRoot 'routing\state.json'
$selectorPath = Join-Path $ToolkitRoot 'scripts\select-model.ps1'
$workerTemplate = Join-Path $ToolkitRoot 'opencode\templates\worker.template.md'
$workerGenerated = Join-Path $ToolkitRoot 'opencode\agents\worker.md'
$buildTemplate = Join-Path $ToolkitRoot 'opencode\templates\build.template.md'
$reviewTemplate = Join-Path $ToolkitRoot 'opencode\templates\review.template.md'
$indexTemplate = Join-Path $ToolkitRoot 'opencode\templates\researcher.template.md'
$delegateTool = Join-Path $ToolkitRoot 'opencode\tools\delegate.ts'

try { $st = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail 'state is malformed JSON'; $st = $null }
if ($st) { Pass 'routing state is well-formed JSON' }

# D1: worker agent files exist and do not hard-pin a provider model.
try {
    if (-not (Test-Path -LiteralPath $workerTemplate)) { Fail 'D1 worker template missing' }
    elseif (-not (Test-Path -LiteralPath $workerGenerated)) { Fail 'D1 generated worker agent missing' }
    else {
        Pass 'D1 worker template and generated agent present'
        $wg = Get-Content -LiteralPath $workerGenerated -Raw -Encoding UTF8
        if ($wg -notmatch '(?m)^model:\s*') { Pass 'D1 generated worker inherits the invoking model' }
        else { Fail 'D1 generated worker still hard-pins a model' }
    }
} catch { Fail ("D1 worker files error: " + $_.Exception.Message) }

# D2: build can delegate to worker.
try {
    $bt = Get-Content -LiteralPath $buildTemplate -Raw -Encoding UTF8
    if ($bt -match '(?m)^\s*worker:\s*allow\s*$') { Pass 'D2 build template allows worker delegation' }
    else { Fail 'D2 build template does not allow worker' }
} catch { Fail ("D2 build topology error: " + $_.Exception.Message) }

# D3: worker is write-capable with bounded nesting (explore/index/review, no self-spawn).
try {
    $wt = Get-Content -LiteralPath $workerTemplate -Raw -Encoding UTF8
    if ($wt -match 'edit:\s*deny') { Fail 'D3 worker must be write-capable (unexpected edit deny)' }
    else { Pass 'D3 worker is write-capable' }
    $nestedOk = ($wt -match '(?m)^\s*explore:\s*allow\s*$') -and ($wt -match '(?m)^\s*researcher:\s*allow\s*$') -and ($wt -match '(?m)^\s*review:\s*allow\s*$')
    if ($nestedOk) { Pass 'D3 worker nests explore/researcher/review' }
    else { Fail 'D3 worker nesting is not explore/researcher/review' }
    if ($wt -match '(?m)^\s*worker:\s*allow\s*$') { Fail 'D3 worker must not recursively spawn another worker' }
    else { Pass 'D3 worker does not self-spawn' }
} catch { Fail ("D3 worker permissions error: " + $_.Exception.Message) }

# D4: review and index remain read-only.
try {
    $rt = Get-Content -LiteralPath $reviewTemplate -Raw -Encoding UTF8
    $it = Get-Content -LiteralPath $indexTemplate -Raw -Encoding UTF8
    if ($rt -match 'edit:\s*deny') { Pass 'D4 review remains read-only' } else { Fail 'D4 review lost read-only restriction' }
    if ($it -match 'edit:\s*deny') { Pass 'D4 researcher remains read-only' } else { Fail 'D4 researcher lost read-only restriction' }
} catch { Fail ("D4 read-only error: " + $_.Exception.Message) }

# D5: delegate tool exists, is research-free, and keeps the adapter point.
try {
    if (-not (Test-Path -LiteralPath $delegateTool)) { Fail 'D5 delegate tool missing' }
    else {
        $dt = Get-Content -LiteralPath $delegateTool -Raw -Encoding UTF8
        Pass 'D5 delegate tool present'
        $webMarks = @('webfetch','websearch','Invoke-WebRequest')
        $foundWeb = @()
        foreach ($w in $webMarks) { if ($dt.Contains($w)) { $foundWeb += $w } }
        if ($foundWeb.Count -eq 0) { Pass 'D5 delegate tool performs no live web research' }
        else { Fail ("D5 delegate tool references web: " + ($foundWeb -join ', ')) }
        if ($dt -notmatch '(?i)statically pinned|ADAPTER POINT') { Pass 'D5 delegate tool has no static model-lock contract' }
        else { Fail 'D5 delegate tool still advertises a static model lock' }
        if ($dt.Contains('select-model.ps1')) { Pass 'D5 delegate tool invokes deterministic selector' }
        else { Fail 'D5 delegate tool does not invoke select-model.ps1' }
    }
    $cmdPath = Join-Path $ToolkitRoot 'opencode\commands\delegate.md'
    if (Test-Path -LiteralPath $cmdPath) { Fail 'D5 retired /delegate command wrapper still present' }
    else { Pass 'D5 no /delegate command wrapper' }
} catch { Fail ("D5 delegate tool error: " + $_.Exception.Message) }

# D6-D8: live selector contract per role (worker/review/researcher).
function Invoke-RoleSelection([string]$Role, [string[]]$TaskTypes, [string]$Exclude) {
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$selectorPath,'-TaskType',$TaskTypes,'-Role',$Role)
    if ($Role -eq 'researcher') { $argList += @('-PreferredCostClass','free') }
    if ($Role -eq 'review') { $argList += @('-NeedsModelDiversity:$true') }
    if ($Exclude -ne '') { $argList += @('-ExcludeModel',$Exclude) }
    $out = & powershell.exe @argList 2>$null
    if ($LASTEXITCODE -ne 0) { throw "select-model failed for role=$Role" }
    return (($out -join "`n") | ConvertFrom-Json)
}

try {
    $w = Invoke-RoleSelection 'worker' @('bounded_feature') ''
    if ($w.selected_model -and $w.role -eq 'worker' -and $w.adequacy -and $w.fallback_model) {
        Pass ("D6 worker contract ok (" + $w.selected_model + "/" + $w.adequacy + ")")
    } else { Fail 'D6 worker contract incomplete' }
} catch { Fail ("D6 worker contract error: " + $_.Exception.Message) }

try {
    $implModel = ''
    if ($st -and $st.deep) { $implModel = [string]$st.deep }
    $r = Invoke-RoleSelection 'review' @('code_review','independent_verification') $implModel
    if ([string]$r.selected_model -ne $implModel) { Pass ("D7 review excludes implementation model (" + $r.selected_model + ")") }
    else { Fail 'D7 review reused the implementation model' }
} catch { Fail ("D7 review diversity error: " + $_.Exception.Message) }

try {
    $i = Invoke-RoleSelection 'researcher' @('research') ''
    if ($i.selected_model -match '^opencode/') { Pass ("D8 researcher stays free (" + $i.selected_model + ")") }
    else { Fail ("D8 researcher not on free model: " + $i.selected_model) }
} catch { Fail ("D8 researcher bias error: " + $_.Exception.Message) }

Write-Output ''
if ($fail -gt 0) { Write-Output "Delegate regression: $fail failure(s)."; exit 1 } else { Write-Output 'Delegate regression: all checks passed.'; exit 0 }
