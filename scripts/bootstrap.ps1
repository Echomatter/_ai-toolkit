<# Bootstrap existing OpenCode integration. Cleanup is ownership-aware in install.ps1;
never delete unowned legacy resources by name. PowerShell 5.1. #>
param([switch]$SkipSoftwareInstall,[switch]$PreserveLegacyToolkitArtifacts)
$ErrorActionPreference='Stop'
$ToolkitRoot=Split-Path -Parent $PSScriptRoot
function Refresh-Path {
    $machine=[Environment]::GetEnvironmentVariable('Path','Machine')
    $user=[Environment]::GetEnvironmentVariable('Path','User')
    $env:Path="$machine;$user;$env:APPDATA\npm"
}
function Resolve-Exe([string]$Name,[string[]]$Fallbacks) {
    $cmd=Get-Command $Name -ErrorAction SilentlyContinue
    if($cmd){return $cmd.Source}
    foreach($p in $Fallbacks){if($p-and(Test-Path -LiteralPath $p)){return $p}}
    return $null
}
Write-Output '== Preflight toolkit scripts =='
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate.ps1')
if($LASTEXITCODE-ne 0){throw 'Toolkit preflight validation failed.'}
Write-Output '== Install owned toolkit resources =='
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install.ps1')
if($LASTEXITCODE-ne 0){throw 'Toolkit installation failed.'}
Refresh-Path
$opencode=Resolve-Exe 'opencode' @((Join-Path $env:APPDATA 'npm\opencode.cmd'))
if(-not$opencode-and-not$SkipSoftwareInstall){
    $npm=Resolve-Exe 'npm' @((Join-Path $env:ProgramFiles 'nodejs\npm.cmd'))
    if(-not$npm){
        $winget=Resolve-Exe 'winget' @()
        if(-not$winget){throw 'OpenCode and npm are missing; install Node.js first.'}
        & $winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
        Refresh-Path
        $npm=Resolve-Exe 'npm' @((Join-Path $env:ProgramFiles 'nodejs\npm.cmd'))
    }
    if(-not$npm){throw 'npm is unavailable.'}
    & $npm install -g opencode-ai
    if($LASTEXITCODE-ne 0){throw 'OpenCode installation failed.'}
    Refresh-Path
    $opencode=Resolve-Exe 'opencode' @((Join-Path $env:APPDATA 'npm\opencode.cmd'))
}
if(-not$opencode){throw 'OpenCode not found. Install it or rerun without SkipSoftwareInstall.'}
$gh=Resolve-Exe 'gh' @((Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'))
if(-not$gh-and-not$SkipSoftwareInstall){
    $winget=Resolve-Exe 'winget' @()
    if($winget){
        & $winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
        Refresh-Path
        $gh=Resolve-Exe 'gh' @((Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'))
    }
}
if(-not$gh){Write-Warning 'GitHub CLI is unavailable; Sync remote operations require an authenticated GitHub interface.'}
$env:OPENCODE_CONFIG=Join-Path $ToolkitRoot 'opencode\opencode.jsonc'
$env:OPENCODE_CONFIG_DIR=Join-Path $ToolkitRoot 'opencode'
try{
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'refresh-routing.ps1') -NoRefresh
    if($LASTEXITCODE-eq 0){
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install.ps1')
        if($LASTEXITCODE-ne 0){throw 'Updated integration deployment failed.'}
    }
}catch{Write-Warning "Inventory refresh unavailable: $($_.Exception.Message)"}
Write-Output 'Bootstrap complete. Fully quit and restart OpenCode to load the plugin.'
Write-Output 'Keep your selected parent model. Use native /connect for providers and gh auth login for GitHub.'
Write-Output 'Unowned legacy resources are never deleted by name; resolve reported conflicts explicitly.'
