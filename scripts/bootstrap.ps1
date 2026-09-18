<#
.SYNOPSIS
  Bootstraps the OpenCode routed toolkit on Windows without adding metered API gateways.

.DESCRIPTION
  Cleans recognized artifacts from earlier toolkit editions, installs portable skills,
  OpenCode integration files, stable OpenCode, and GitHub CLI if missing.
  Provider OAuth remains interactive. No local model engine is installed or managed.
#>
param(
    [switch]$SkipSoftwareInstall,
    [switch]$PreserveLegacyToolkitArtifacts
)
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $ToolkitRoot '.state\install-manifest.json'

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path','Machine')
    $user = [Environment]::GetEnvironmentVariable('Path','User')
    $env:Path = "$machine;$user;$env:APPDATA\npm"
}
function Resolve-Exe([string]$Name,[string[]]$Fallbacks) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in $Fallbacks) { if ($p -and (Test-Path -LiteralPath $p)) { return $p } }
    return $null
}
function Get-ManifestTargets {
    $targets = @()
    if (-not (Test-Path -LiteralPath $ManifestPath)) { return $targets }
    try {
        $raw = Get-Content -LiteralPath $ManifestPath -Raw
        if ($raw -and $raw.Trim()) {
            foreach ($entry in @($raw | ConvertFrom-Json)) {
                if ($entry.target) { $targets += [string]$entry.target }
            }
        }
    } catch {
        Write-Warning "Could not read existing install manifest during legacy cleanup: $($_.Exception.Message)"
    }
    return $targets
}
function Test-AgentSkillName([string]$Path,[string]$Name) {
    $skill = Join-Path $Path 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skill)) { return $false }
    try {
        $text = Get-Content -LiteralPath $skill -Raw
        return ($text -match "(?m)^name:\s*$([regex]::Escape($Name))\s*$")
    } catch { return $false }
}
function Remove-PathItem([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $isReparse = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
    if ($isReparse -and $item.PSIsContainer) {
        # Windows PowerShell 5.1 can prompt when Remove-Item targets a directory
        # symlink/junction. rmdir removes the link itself without traversing the target.
        & cmd.exe /d /c rmdir "$Path" | Out-Null
        if ($LASTEXITCODE -ne 0 -and (Test-Path -LiteralPath $Path)) {
            throw "Could not remove directory link: $Path"
        }
    } elseif ($isReparse) {
        Remove-Item -LiteralPath $Path -Force -Confirm:$false
    } elseif ($item.PSIsContainer) {
        Remove-Item -LiteralPath $Path -Recurse -Force -Confirm:$false
    } else {
        Remove-Item -LiteralPath $Path -Force -Confirm:$false
    }
}
function Remove-LegacyToolkitArtifacts {
    if ($PreserveLegacyToolkitArtifacts) {
        Write-Output 'Legacy toolkit cleanup skipped by -PreserveLegacyToolkitArtifacts.'
        return
    }

    Write-Output '== Clean recognized legacy toolkit artifacts =='
    $manifestTargets = Get-ManifestTargets
    $skillsRoot = Join-Path $env:USERPROFILE '.agents\skills'

    # Exact skill names used by earlier toolkit editions. Current skill names are included
    # so a deleted/lost manifest does not leave an old copy blocking the new managed link.
    # Existing manifest-owned targets are left for install.ps1 to refresh normally.
    $knownToolkitSkills = @(
        'bounded-experiment','change-audit','cost-aware-routing','evidence-ledger',
        'external-research','github-ops','handoff-brief','local-first-escalation',
        'local-repo-research','model-advisor','model-escalation','model-routing',
        'public-repo-research','repo-reorient','content-index-research','task-contract','workspace-map'
    )

    foreach ($name in $knownToolkitSkills) {
        $target = Join-Path $skillsRoot $name
        if (-not (Test-Path -LiteralPath $target)) { continue }
        if ($manifestTargets -contains $target) { continue }
        if (-not (Test-AgentSkillName $target $name)) { continue }

        try {
            Remove-PathItem $target
            Write-Output "removed legacy toolkit skill: $target"
        } catch {
            Write-Warning "could not remove legacy toolkit skill ${target}: $($_.Exception.Message)"
        }
    }

    # These exact custom-agent profile names were emitted by the retired Copilot/Codex
    # editions. They are no longer used anywhere in the OpenCode architecture.
    $legacyAgentFiles = @(
        (Join-Path $env:USERPROFILE '.copilot\agents\github-operator.agent.md'),
        (Join-Path $env:USERPROFILE '.copilot\agents\public-repo-scout.agent.md'),
        (Join-Path $env:USERPROFILE '.copilot\agents\local-repo-researcher.agent.md'),
        (Join-Path $env:USERPROFILE '.copilot\agents\independent-verifier.agent.md'),
        (Join-Path $env:USERPROFILE '.copilot\agents\task-switchboard.agent.md'),
        (Join-Path $env:USERPROFILE '.codex\agents\github-operator.toml'),
        (Join-Path $env:USERPROFILE '.codex\agents\public-repo-scout.toml'),
        (Join-Path $env:USERPROFILE '.codex\agents\local-repo-researcher.toml'),
        (Join-Path $env:USERPROFILE '.codex\agents\independent-verifier.toml'),
        (Join-Path $env:USERPROFILE '.codex\agents\task-switchboard.toml'),
        (Join-Path $env:USERPROFILE '.config\opencode\agents\auto.md')
    )
    foreach ($path in $legacyAgentFiles) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            Remove-PathItem $path
            Write-Output "removed retired toolkit agent profile: $path"
        } catch {
            Write-Warning "could not remove retired toolkit agent profile ${path}: $($_.Exception.Message)"
        }
    }
}

Write-Output '== Preflight toolkit scripts =='
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Toolkit preflight validation failed.' }

Remove-LegacyToolkitArtifacts

Write-Output '== Install portable Agent Skills =='
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Skill installation failed.' }

Refresh-Path
$opencode = Resolve-Exe 'opencode' @((Join-Path $env:APPDATA 'npm\opencode.cmd'))
if (-not $opencode -and -not $SkipSoftwareInstall) {
    $npm = Resolve-Exe 'npm' @((Join-Path $env:ProgramFiles 'nodejs\npm.cmd'))
    if (-not $npm) {
        $winget = Resolve-Exe 'winget' @()
        if (-not $winget) { throw 'OpenCode is missing, npm is unavailable, and winget cannot install Node.js.' }
        Write-Output '== Install Node.js LTS =='
        & $winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
        Refresh-Path
        $npm = Resolve-Exe 'npm' @((Join-Path $env:ProgramFiles 'nodejs\npm.cmd'))
    }
    if (-not $npm) { throw 'npm is still unavailable after Node.js install.' }
    Write-Output '== Install stable OpenCode =='
    & $npm install -g opencode-ai
    if ($LASTEXITCODE -ne 0) { throw 'OpenCode npm install failed.' }
    Refresh-Path
    $opencode = Resolve-Exe 'opencode' @((Join-Path $env:APPDATA 'npm\opencode.cmd'))
}
if (-not $opencode) { throw 'OpenCode not found. Install it or rerun without -SkipSoftwareInstall.' }

$gh = Resolve-Exe 'gh' @((Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'))
if (-not $gh -and -not $SkipSoftwareInstall) {
    $winget = Resolve-Exe 'winget' @()
    if ($winget) {
        Write-Output '== Install GitHub CLI =='
        & $winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
        Refresh-Path
        $gh = Resolve-Exe 'gh' @((Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'))
    }
}
if ($gh) { Write-Output "GitHub CLI: $gh" } else { Write-Warning 'GitHub CLI is missing. Remote GitHub work will require gh or another explicit integration.' }

Write-Output '== Validate toolkit structure =='
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Toolkit validation failed.' }

# If the user already has providers connected, generate the best current routes now.
$env:OPENCODE_CONFIG = Join-Path $ToolkitRoot 'opencode\opencode.jsonc'
$env:OPENCODE_CONFIG_DIR = Join-Path $ToolkitRoot 'opencode'
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'refresh-routing.ps1') -NoRefresh
    if ($LASTEXITCODE -eq 0) {
        Write-Output '== Refresh Desktop agent/command links after routing =='
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'Desktop integration refresh failed.' }
    }
} catch {
    Write-Warning "Routing could not be refreshed yet: $($_.Exception.Message)"
}

Write-Output ''
Write-Output 'Bootstrap complete.'
Write-Output ''
Write-Output 'Next:'
Write-Output '  1. In OpenCode, /connect -> OpenAI -> ChatGPT Plus/Pro (OAuth), if desired.'
Write-Output '  2. /connect -> GitHub Copilot (device OAuth), if desired.'
Write-Output '  3. Keep using the current OpenCode free models if desired; do not add API-key gateways.'
Write-Output '  4. Run: gh auth login'
Write-Output '  5. Fully quit and reopen OpenCode Desktop; use native Build for normal work and Plan only when you explicitly select it.'
Write-Output '  6. Run scripts\refresh-routing.cmd whenever your connected model inventory changes.'
