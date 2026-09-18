<#
.SYNOPSIS
  Installs or refreshes this toolkit's portable Agent Skills.

.DESCRIPTION
  Manages individual directories under %USERPROFILE%\.agents\skills.
  Prefers symbolic links, then directory junctions, then managed copies.
  Preserves unrelated user skills and prunes only toolkit-owned/recognized legacy items.

  Windows PowerShell 5.1 compatible.
#>

$ErrorActionPreference = 'Stop'

$ToolkitRoot  = Split-Path -Parent $PSScriptRoot
$StateDir     = Join-Path $ToolkitRoot '.state'
$ManifestPath = Join-Path $StateDir 'install-manifest.json'
$SkillsSrc    = Join-Path $ToolkitRoot '.agents\skills'
$SkillsDst    = Join-Path $env:USERPROFILE '.agents\skills'
$OpenCodeRoot = Join-Path $env:USERPROFILE '.config\opencode'
$AgentSrc     = Join-Path $ToolkitRoot 'opencode\agents'
$AgentDst     = Join-Path $OpenCodeRoot 'agents'
$CommandSrc   = Join-Path $ToolkitRoot 'opencode\commands'
$CommandDst   = Join-Path $OpenCodeRoot 'commands'

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}


function Remove-PathItem([string]$Path, [switch]$RecurseRegular) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $isReparse = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
    if ($isReparse -and $item.PSIsContainer) {
        & cmd.exe /d /c rmdir "$Path" | Out-Null
        if ($LASTEXITCODE -ne 0 -and (Test-Path -LiteralPath $Path)) { throw "Could not remove directory link: $Path" }
    } elseif ($isReparse) {
        Remove-Item -LiteralPath $Path -Force -Confirm:$false
    } elseif ($item.PSIsContainer) {
        if (-not $RecurseRegular) { throw "Refusing to remove regular directory without -RecurseRegular: $Path" }
        Remove-Item -LiteralPath $Path -Recurse -Force -Confirm:$false
    } else {
        Remove-Item -LiteralPath $Path -Force -Confirm:$false
    }
}

function Load-Manifest {
    $list = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $ManifestPath) {
        try {
            $raw = Get-Content -LiteralPath $ManifestPath -Raw
            if ($raw -and $raw.Trim()) {
                foreach ($e in @($raw | ConvertFrom-Json)) { [void]$list.Add($e) }
            }
        } catch {
            Write-Warning "Could not read old install manifest; recognized legacy items will still be handled safely."
        }
    }
    return $list
}

function Save-Manifest($List) {
    Ensure-Dir $StateDir
    @($List) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

function Find-Entry([string]$Target, $Manifest) {
    foreach ($e in @($Manifest)) { if ($e.target -eq $Target) { return $e } }
    return $null
}

function Remove-Managed($Entry) {
    if (-not $Entry -or -not $Entry.target -or -not (Test-Path -LiteralPath $Entry.target)) { return }
    if ($Entry.method -eq 'copy') {
        Remove-PathItem -Path $Entry.target -RecurseRegular
    } else {
        Remove-PathItem -Path $Entry.target
    }
}

function Recognized-Skill([string]$Path, [string]$Name) {
    $skill = Join-Path $Path 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skill)) { return $false }
    try {
        $text = Get-Content -LiteralPath $skill -Raw
        return $text.Contains("name: $Name")
    } catch { return $false }
}

$manifest = Load-Manifest
$nextManifest = New-Object System.Collections.ArrayList
$currentTargets = @()
$currentTargets += @(Get-ChildItem -LiteralPath $SkillsSrc -Directory | ForEach-Object { Join-Path $SkillsDst $_.Name })
if (Test-Path -LiteralPath $AgentSrc) {
    $currentTargets += @(Get-ChildItem -LiteralPath $AgentSrc -File -Filter '*.md' | Where-Object { $_.Name -notlike '*.template.md' } | ForEach-Object { Join-Path $AgentDst $_.Name })
}
if (Test-Path -LiteralPath $CommandSrc) {
    $currentTargets += @(Get-ChildItem -LiteralPath $CommandSrc -File -Filter '*.md' | ForEach-Object { Join-Path $CommandDst $_.Name })
}

# Prune anything previously installed by this toolkit that is not part of the current
# skill set, even if an old source folder still exists after an overlay.
# Also prune managed entries whose canonical source disappeared.
foreach ($entry in @($manifest)) {
    $isCurrent = $entry.target -and ($currentTargets -contains $entry.target)
    $sourceMissing = $entry.source -and -not (Test-Path -LiteralPath $entry.source)
    if (-not $isCurrent -or $sourceMissing) {
        try {
            Remove-Managed $entry
            Write-Output "pruned retired managed item: $($entry.target)"
        } catch {
            Write-Warning "could not prune $($entry.target): $($_.Exception.Message)"
            [void]$nextManifest.Add($entry)
        }
    } else {
        [void]$nextManifest.Add($entry)
    }
}
$manifest = $nextManifest

# Earlier toolkit items that are no longer canonical are removed automatically only when
# the install manifest proves this toolkit owns them. If the manifest was lost, leave
# same-named user files alone and report them for manual cleanup.
$retiredSkills = @(
    'cost-aware-routing','task-contract','workspace-map','public-repo-research',
    'local-first-escalation','external-research','model-escalation'
)
foreach ($name in $retiredSkills) {
    $target = Join-Path $SkillsDst $name
    if (-not (Test-Path -LiteralPath $target)) { continue }
    $owned = Find-Entry $target $manifest
    if ($owned) {
        try {
            Remove-Managed $owned
            [void]$manifest.Remove($owned)
            Write-Output "removed retired toolkit skill: $target"
        } catch { Write-Warning "could not remove retired skill ${target}: $($_.Exception.Message)" }
    } elseif (Recognized-Skill $target $name) {
        Write-Warning "retired skill exists but is not in this toolkit's manifest; left untouched: $target"
    }
}

# Legacy custom-agent profiles are no longer needed. The earlier manifest pruning above
# removes toolkit-owned copies/links whose canonical sources disappeared. Unmanaged
# same-named agent files are deliberately left untouched.
$legacyFiles = @(
    (Join-Path $env:USERPROFILE '.copilot\agents\github-operator.agent.md'),
    (Join-Path $env:USERPROFILE '.copilot\agents\public-repo-scout.agent.md'),
    (Join-Path $env:USERPROFILE '.copilot\agents\local-repo-researcher.agent.md'),
    (Join-Path $env:USERPROFILE '.copilot\agents\independent-verifier.agent.md'),
    (Join-Path $env:USERPROFILE '.copilot\agents\task-switchboard.agent.md'),
    (Join-Path $env:USERPROFILE '.codex\agents\github-operator.toml'),
    (Join-Path $env:USERPROFILE '.codex\agents\public-repo-scout.toml'),
    (Join-Path $env:USERPROFILE '.codex\agents\local-repo-researcher.toml'),
    (Join-Path $env:USERPROFILE '.codex\agents\independent-verifier.toml'),
    (Join-Path $env:USERPROFILE '.codex\agents\task-switchboard.toml')
)
foreach ($path in $legacyFiles) {
    if (Test-Path -LiteralPath $path) {
        Write-Warning "legacy agent profile is not manifest-owned and was left untouched: $path"
    }
}

Ensure-Dir $SkillsDst
$created = 0
$refreshed = 0
$conflicts = 0

foreach ($src in Get-ChildItem -LiteralPath $SkillsSrc -Directory) {
    $target = Join-Path $SkillsDst $src.Name
    $owned = Find-Entry $target $manifest

    if (Test-Path -LiteralPath $target) {
        if (-not $owned) {
            Write-Warning "conflict: $target exists and is not toolkit-managed; left untouched"
            $conflicts++
            continue
        }
        if ($owned.method -eq 'copy') {
            Remove-Item -LiteralPath $target -Recurse -Force
            Copy-Item -LiteralPath $src.FullName -Destination $target -Recurse -Force
            $owned.source = $src.FullName
            $refreshed++
            Write-Output "refreshed copy: $target"
            continue
        }
        # Existing managed link/junction remains correct if it points at the live toolkit tree.
        $owned.source = $src.FullName
        Write-Output "already managed: $target"
        continue
    }

    $method = $null
    try {
        New-Item -ItemType SymbolicLink -Path $target -Target $src.FullName -ErrorAction Stop | Out-Null
        $method = 'symlink'
    } catch {
        try {
            New-Item -ItemType Junction -Path $target -Target $src.FullName -ErrorAction Stop | Out-Null
            $method = 'junction'
        } catch {
            Copy-Item -LiteralPath $src.FullName -Destination $target -Recurse -Force
            $method = 'copy'
        }
    }

    $entry = [PSCustomObject]@{ target=$target; source=$src.FullName; kind='dir'; method=$method }
    [void]$manifest.Add($entry)
    $created++
    Write-Output "$method -> $target"
}

# Install OpenCode Desktop-visible global agents and commands without replacing the user's
# global opencode.json. OpenCode Desktop loads these directories natively.
function Install-ManagedFile([string]$Source, [string]$Target) {
    $parent = Split-Path -Parent $Target
    Ensure-Dir $parent
    $owned = Find-Entry $Target $manifest

    if (Test-Path -LiteralPath $Target) {
        if (-not $owned) {
            Write-Warning "conflict: $Target exists and is not toolkit-managed; left untouched"
            $script:conflicts++
            return
        }
        if ($owned.method -eq 'copy') {
            Copy-Item -LiteralPath $Source -Destination $Target -Force
            $owned.source = $Source
            $script:refreshed++
            Write-Output "refreshed copy: $Target"
            return
        }
        $owned.source = $Source
        Write-Output "already managed: $Target"
        return
    }

    $method = $null
    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
        $method = 'symlink'
    } catch {
        Copy-Item -LiteralPath $Source -Destination $Target -Force
        $method = 'copy'
    }
    $entry = [PSCustomObject]@{ target=$Target; source=$Source; kind='file'; method=$method }
    [void]$manifest.Add($entry)
    $script:created++
    Write-Output "$method -> $Target"
}

Ensure-Dir $AgentDst
Ensure-Dir $CommandDst
foreach ($src in Get-ChildItem -LiteralPath $AgentSrc -File -Filter '*.md' | Where-Object { $_.Name -notlike '*.template.md' }) {
    Install-ManagedFile $src.FullName (Join-Path $AgentDst $src.Name)
}
foreach ($src in Get-ChildItem -LiteralPath $CommandSrc -File -Filter '*.md' | Where-Object { $_.Name -notlike '*.template.md' }) {
    Install-ManagedFile $src.FullName (Join-Path $CommandDst $src.Name)
}

# Merge the toolkit's generated global guidance into OpenCode's global AGENTS.md
# without replacing user-authored instructions outside the managed markers.
$syncGlobal = Join-Path $PSScriptRoot 'sync-global-instructions.ps1'
if (Test-Path -LiteralPath $syncGlobal) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syncGlobal
    if ($LASTEXITCODE -ne 0) { throw 'Could not synchronize OpenCode global instructions.' }
}

Save-Manifest $manifest
Write-Output ""
Write-Output "Toolkit install summary: $created created, $refreshed refreshed, $conflicts conflicts."
Write-Output "OpenCode Desktop agents: native build override, deep, review; global toolkit guidance synchronized"
