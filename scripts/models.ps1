<# Prints only model surfaces relevant to this no-metered-API toolkit. #>
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$env:OPENCODE_CONFIG = Join-Path $ToolkitRoot 'opencode\opencode.jsonc'
$env:OPENCODE_CONFIG_DIR = Join-Path $ToolkitRoot 'opencode'
$env:OPENCODE_ENABLE_EXA = '1'
$oc = Get-Command opencode -ErrorAction Stop
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
Write-Output '== Connected providers =='
$authCall = Invoke-OpenCodeCaptured @('auth','list')
if ($authCall.ExitCode -ne 0) { throw "opencode auth list failed: $($authCall.Output -join ' ')" }
$authCall.Output
Write-Output ''
Write-Output '== Eligible routing models =='
$modelCall = Invoke-OpenCodeCaptured @('models','--refresh')
if ($modelCall.ExitCode -ne 0) { throw "opencode models --refresh failed: $($modelCall.Output -join ' ')" }
$all = @($modelCall.Output | Where-Object { $_.ToString().Trim() -match '^[A-Za-z0-9_.-]+/.+$' })
$all | Where-Object {
    $_ -match '^openai/' -or
    $_ -match '^github-copilot/' -or
    $_ -match '^ollama/' -or
    $_ -eq 'opencode/big-pickle' -or
    $_ -match '^opencode/.+(-free|contributor-free)$'
}
Write-Output ''
Write-Output '== Current routing state =='
Get-Content -LiteralPath (Join-Path $ToolkitRoot 'routing\state.json') -Raw
Write-Output ''
Write-Output '== Current model roster =='
Get-Content -LiteralPath (Join-Path $ToolkitRoot 'routing\model-roster.json') -Raw
