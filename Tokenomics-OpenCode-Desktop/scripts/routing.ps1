$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$state = Join-Path $ToolkitRoot 'routing\state.json'
if (-not (Test-Path -LiteralPath $state)) { throw 'Routing state not found; run refresh-routing.cmd.' }
Get-Content -LiteralPath $state -Raw
