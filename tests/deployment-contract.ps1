<# Deploy only into temporary fixtures, never the user's OpenCode installation. #>
$ErrorActionPreference='Stop'
$RepoRoot=Split-Path -Parent $PSScriptRoot
$Fixture=Join-Path $env:TEMP ('toolkit-deploy-' + [guid]::NewGuid().ToString('N'))
$Source=Join-Path $Fixture 'source';$HomeRoot=Join-Path $Fixture 'home'
function Check($b,[string]$s) { if(-not $b){throw $s};Write-Output "PASS: $s" }
try {
    New-Item -ItemType Directory -Path $Source,$HomeRoot -Force | Out-Null
    foreach($dir in @('skills','opencode','scripts')) { Copy-Item -LiteralPath (Join-Path $RepoRoot $dir) -Destination (Join-Path $Source $dir) -Recurse }
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    $manifest=Join-Path $Source '.state\install-manifest.json'
    $before=Get-Content -LiteralPath $manifest -Raw
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    $after=Get-Content -LiteralPath $manifest -Raw
    Check ($before -eq $after) 'deployment twice is idempotent'
    Check (Test-Path -LiteralPath (Join-Path $HomeRoot '.config\opencode\plugins\delegation.ts')) 'SDK plugin deployed'
    Check (-not (Test-Path -LiteralPath (Join-Path $HomeRoot '.config\opencode\tools\delegate.ts'))) 'no duplicate advisory delegate tool'
    Check (-not (Test-Path -LiteralPath (Join-Path $HomeRoot '.config\opencode\commands'))) 'removed command directory not required or recreated'
    $dest=Join-Path $HomeRoot '.config\opencode\agents\worker.md'
    Add-Content -LiteralPath $dest -Value 'deployment-only-edit'
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check ((Get-FileHash $dest).Hash -eq (Get-FileHash (Join-Path $Source 'opencode\agents\worker.md')).Hash) 'stale copied profile repaired'
    $backupFiles=@(Get-ChildItem -LiteralPath (Join-Path $HomeRoot '.local\share\ai-toolkit\backups') -File -Recurse)
    Check (@($backupFiles|Where-Object{(Get-Content -LiteralPath $_.FullName -Raw) -match 'deployment-only-edit'}).Count -ge 1) 'deployment-only edit recoverably backed up'
    $unrelated=Join-Path $HomeRoot '.agents\skills\user-owned';New-Item -ItemType Directory -Path $unrelated | Out-Null
    Set-Content -LiteralPath (Join-Path $unrelated 'SKILL.md') -Value 'user data'
    & (Join-Path $Source 'scripts\uninstall.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check (Test-Path -LiteralPath (Join-Path $unrelated 'SKILL.md')) 'uninstall preserves unrelated skills'
    Check (Test-Path -LiteralPath (Join-Path $Source 'skills\reorient\SKILL.md')) 'junction removal never traverses source'
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check (Test-Path -LiteralPath $dest) 'clean reinstall works'
} finally {
    if(Test-Path -LiteralPath (Join-Path $Source '.state\install-manifest.json')) {
        & (Join-Path $Source 'scripts\uninstall.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    }
    Remove-Item -LiteralPath $Fixture -Recurse -Force
}
Write-Output 'Deployment contracts passed (isolated home).'
