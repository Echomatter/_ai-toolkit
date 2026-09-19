<# Updates stable OpenCode and refreshes toolkit-managed skills/routing. #>
$ErrorActionPreference='Stop'
$npm=Get-Command npm -ErrorAction SilentlyContinue
if(-not $npm){throw 'npm not found; rerun bootstrap or update OpenCode manually.'}
& $npm.Source install -g opencode-ai
if($LASTEXITCODE -ne 0){throw 'OpenCode update failed.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install.ps1')
if($LASTEXITCODE -ne 0){throw 'Skill refresh failed.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'refresh-routing.ps1')
if($LASTEXITCODE -ne 0){throw 'Routing refresh failed.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate.ps1')
if($LASTEXITCODE -ne 0){throw 'Toolkit validation failed.'}
Write-Output 'Update complete.'
