<# Ownership-aware, recoverable deployment. Windows PowerShell 5.1.
   No user credentials, conversations or unrelated resources are removed.
   HomeRoot/ToolkitRoot exist for isolated deployment tests, not model routing. #>
[CmdletBinding()]
param([string]$ToolkitRoot = '', [string]$HomeRoot = '', [switch]$Uninstall)
$ErrorActionPreference = 'Stop'
if (-not $ToolkitRoot) { $ToolkitRoot = Split-Path -Parent $PSScriptRoot }
if (-not $HomeRoot) { $HomeRoot = $env:USERPROFILE }
$ToolkitRoot = [IO.Path]::GetFullPath($ToolkitRoot)
$HomeRoot = [IO.Path]::GetFullPath($HomeRoot)
$state = Join-Path $ToolkitRoot '.state'
New-Item -ItemType Directory -Path $state -Force | Out-Null
$manifestPath = Join-Path $state 'install-manifest.json'
$backupRoot = Join-Path $HomeRoot ('.local\share\ai-toolkit\backups\' + [guid]::NewGuid().ToString('N'))
$configBase = if ($env:XDG_CONFIG_HOME -and $HomeRoot -eq $env:USERPROFILE) { $env:XDG_CONFIG_HOME } else { Join-Path $HomeRoot '.config' }
$config = Join-Path $configBase 'opencode'
$roots = @((Join-Path $HomeRoot '.agents\skills'), (Join-Path $config 'agents'), (Join-Path $config 'commands'), (Join-Path $config 'tools'), (Join-Path $config 'plugins'))
$locator = Join-Path $config 'ai-toolkit-root.txt'
$old = @()
if (Test-Path -LiteralPath $manifestPath) {
    try { $old = @(Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json) }
    catch { throw 'Install manifest is malformed. Preserved unchanged; refusing unowned cleanup.' }
}
function Full([string]$p) { return [IO.Path]::GetFullPath($p).TrimEnd('\','/') }
function Same([string]$a,[string]$b) { return (Full $a) -ieq (Full $b) }
function Allowed([string]$p) {
    if (-not $p) { return $false }
    if (Same $p $locator) { return $true }
    $parent = Split-Path -Parent (Full $p)
    foreach ($r in $roots) { if (Same $parent $r) { return $true } }
    return $false
}
function Item([string]$p) {
    $i = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    if ($i) { return $i }
    # A dangling junction may fail direct resolution but still has a directory entry.
    $parent = Split-Path -Parent $p; $leaf = Split-Path -Leaf $p
    if (Test-Path -LiteralPath $parent) { return Get-ChildItem -LiteralPath $parent -Force | Where-Object { $_.Name -eq $leaf } | Select-Object -First 1 }
}
function Fingerprint([string]$p) {
    if (Test-Path -LiteralPath $p -PathType Leaf) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash }
    $rows = @()
    foreach ($f in @(Get-ChildItem -LiteralPath $p -File -Recurse -Force | Sort-Object FullName)) {
        $rel = $f.FullName.Substring($p.Length).Replace('\','/')
        $rows += ($rel + '=' + (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash)
    }
    return ($rows -join '|')
}
function Backup([string]$p) {
    $i = Item $p
    if (-not $i) { return }
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $dest = Join-Path $backupRoot ([guid]::NewGuid().ToString('N') + '-' + $i.Name)
    if (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        @{ path=$p; target=@($i.Target); link_type=$i.LinkType } | ConvertTo-Json | Set-Content -LiteralPath ($dest + '.link.json') -Encoding UTF8
    } else { Copy-Item -LiteralPath $p -Destination $dest -Recurse -Force }
    Write-Output "Backed up: $p"
}
function Remove-Owned([string]$p) {
    if (-not (Allowed $p)) { throw "Manifest target outside managed deployment roots: $p" }
    $i = Item $p
    if (-not $i) { return }
    Backup $p
    if (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        if ($i.PSIsContainer) { [IO.Directory]::Delete($p) }
        else { [IO.File]::Delete($p) }
    } else { Remove-Item -LiteralPath $p -Recurse -Force }
}
function Write-Manifest($entries) {
    $tmp = $manifestPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        $json = ConvertTo-Json -InputObject @($entries) -Depth 8
        [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $manifestPath) { [IO.File]::Replace($tmp,$manifestPath,$null) }
        else { [IO.File]::Move($tmp,$manifestPath) }
    } finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } }
}
$lock = $null
try { $lock = New-Object System.IO.FileStream(($manifestPath + '.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None,4096,[IO.FileOptions]::DeleteOnClose) }
catch { throw 'Another deployment is active. No changes made.' }
try {
    # Read under lock as well; never operate from a manifest another installer replaced.
    if (Test-Path -LiteralPath $manifestPath) { $old = @(Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json) }
    foreach ($e in $old) { if (-not (Allowed $e.target)) { throw "Refusing out-of-scope manifest target: $($e.target)" } }
    if ($Uninstall) {
        foreach ($e in $old) { Remove-Owned $e.target }
        Write-Manifest @()
        & (Join-Path $ToolkitRoot 'scripts\sync-global-instructions.ps1') -ToolkitRoot $ToolkitRoot -HomeRoot $HomeRoot -Remove
        Write-Output 'Toolkit uninstalled. Backups retained; credentials and unrelated resources untouched.'
        return
    }
    $desired = @()
    foreach ($d in @(Get-ChildItem -LiteralPath (Join-Path $ToolkitRoot 'skills') -Directory)) {
        if (-not (Test-Path -LiteralPath (Join-Path $d.FullName 'SKILL.md'))) { throw "Invalid skill source: $($d.FullName)" }
        $desired += [pscustomobject]@{ source=$d.FullName; target=(Join-Path $roots[0] $d.Name); kind='dir' }
    }
    foreach ($pair in @(@('agents','*.md'), @('tools','*.ts'), @('plugins','*.ts'))) {
        $src = Join-Path $ToolkitRoot ('opencode\' + $pair[0])
        foreach ($f in @(Get-ChildItem -LiteralPath $src -File -Filter $pair[1] | Where-Object { $_.Name -notlike '*.template.md' })) {
            $desired += [pscustomobject]@{ source=$f.FullName; target=(Join-Path (Join-Path $config $pair[0]) $f.Name); kind='file' }
        }
    }
    $rootFile = Join-Path $state 'toolkit-root.txt'
    [IO.File]::WriteAllText($rootFile,$ToolkitRoot,(New-Object Text.UTF8Encoding($false)))
    $desired += [pscustomobject]@{ source=$rootFile; target=$locator; kind='file' }
    # Conflicts are not ownership. Stop before altering any deployment resource.
    foreach ($d in $desired) {
        $owned = @($old | Where-Object { Same $_.target $d.target })
        if ((Item $d.target) -and -not $owned.Count) { throw "Unmanaged resource conflict; left untouched: $($d.target)" }
    }
    $next = @($old)
    foreach ($e in @($old)) {
        if (-not @($desired | Where-Object { Same $_.target $e.target }).Count) {
            Remove-Owned $e.target
            $next = @($next | Where-Object { -not (Same $_.target $e.target) })
            Write-Manifest $next
        }
    }
    foreach ($d in $desired) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $d.target) -Force | Out-Null
        $existing = Item $d.target
        $method = 'copy'; $unchanged = $false
        if ($existing) {
            if (($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $targets = @($existing.Target)
                if ($targets.Count -eq 1 -and $targets[0] -and (Same $targets[0] $d.source)) {
                    $method = if ($existing.LinkType -eq 'Junction') { 'junction' } else { 'symlink' }
                    $unchanged = $true
                }
            } else { $unchanged = (Fingerprint $d.source) -eq (Fingerprint $d.target) }
            if (-not $unchanged) { Remove-Owned $d.target }
        }
        if (-not $unchanged) {
            if ($d.kind -eq 'dir') {
                try { New-Item -ItemType Junction -Path $d.target -Target $d.source -ErrorAction Stop | Out-Null; $method='junction' }
                catch { Copy-Item -LiteralPath $d.source -Destination $d.target -Recurse -Force; $method='copy' }
            } else { Copy-Item -LiteralPath $d.source -Destination $d.target -Force; $method='copy' }
        }
        if ((Fingerprint $d.source) -ne (Fingerprint $d.target)) { throw "Deployment verification failed: $($d.target)" }
        $next = @($next | Where-Object { -not (Same $_.target $d.target) })
        $next += [pscustomobject]@{ target=$d.target; source=$d.source; kind=$d.kind; method=$method; fingerprint=(Fingerprint $d.target) }
        Write-Manifest $next
        Write-Output "Verified $method`: $($d.target)"
    }
    & (Join-Path $ToolkitRoot 'scripts\sync-global-instructions.ps1') -ToolkitRoot $ToolkitRoot -HomeRoot $HomeRoot
    Write-Output 'Verified toolkit deployment complete. Fully restart OpenCode to load the new plugin and profiles.'
    if (Test-Path -LiteralPath $backupRoot) { Write-Output "Recoverable backups: $backupRoot" }
} finally { if ($lock) { $lock.Dispose() } }
