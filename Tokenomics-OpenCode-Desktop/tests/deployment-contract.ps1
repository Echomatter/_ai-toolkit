<# Deploy only into temporary fixtures, never the user's OpenCode installation. #>
$ErrorActionPreference='Stop'
$RepoRoot=Split-Path -Parent $PSScriptRoot
$Fixture=Join-Path $env:TEMP ('toolkit-deploy-' + [guid]::NewGuid().ToString('N'))
$Source=Join-Path $Fixture 'source';$HomeRoot=Join-Path $Fixture 'home'
function Check($b,[string]$s) { if(-not $b){throw $s};Write-Output "PASS: $s" }
try {
    New-Item -ItemType Directory -Path $Source,$HomeRoot -Force | Out-Null
    foreach($dir in @('skills','opencode','scripts')) { Copy-Item -LiteralPath (Join-Path $RepoRoot $dir) -Destination (Join-Path $Source $dir) -Recurse }
    $instructions=Join-Path $HomeRoot '.config\opencode\AGENTS.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $instructions) -Force|Out-Null
    $userInstructions="  User-authored instruction with spaces.  `r`n"
    [IO.File]::WriteAllText($instructions,$userInstructions)
    $stale=Join-Path $Source 'skills\model-advisor'
    New-Item -ItemType Directory -Path $stale -Force | Out-Null
    Set-Content (Join-Path $stale 'SKILL.md') 'retired overlay'
    try { & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot -InterruptAfter 2 | Out-Null; throw 'Injection did not interrupt' }
    catch { if ($_.Exception.Message -notmatch 'Deliberate isolated') { throw } }
    Check (Test-Path (Join-Path $Source '.state\install-manifest.json')) 'interrupted install journals ownership before publication'
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check (-not (Test-Path (Join-Path $HomeRoot '.agents\skills\model-advisor'))) 'retired source overlay never enters discovery'
    Check (@(Get-ChildItem (Join-Path $HomeRoot '.agents\skills') -Directory).Count -eq 5) 'recovered installation has exactly five skills'
    $manifest=Join-Path $Source '.state\install-manifest.json'
    $before=Get-Content -LiteralPath $manifest -Raw
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    $after=Get-Content -LiteralPath $manifest -Raw
    Check ($before -eq $after) 'deployment twice is idempotent'
    # Upgrade the owned pre-V1 locator and managed block without touching user text.
    $legacyRoot=Join-Path $HomeRoot '.config\opencode\ai-toolkit-root.txt'
    $newRoot=Join-Path $HomeRoot '.config\opencode\tokenomics-root.txt'
    Move-Item -LiteralPath $newRoot -Destination $legacyRoot
    $owned=Get-Content $manifest -Raw|ConvertFrom-Json
    foreach($item in $owned){if($item.target-eq$newRoot){$item.target=$legacyRoot}}
    ConvertTo-Json -InputObject @($owned) -Depth 8|Set-Content $manifest
    $oldBlock=(Get-Content $instructions -Raw).Replace('TOKENOMICS MANAGED BLOCK','AI-TOOLKIT MANAGED BLOCK')
    [IO.File]::WriteAllText($instructions,$oldBlock)
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check ((Test-Path $newRoot)-and-not(Test-Path $legacyRoot)) 'owned legacy root locator migrates'
    $newBlock=Get-Content $instructions -Raw
    Check ($newBlock.Contains($userInstructions)-and-not$newBlock.Contains('AI-TOOLKIT MANAGED BLOCK')-and$newBlock.Contains('TOKENOMICS MANAGED BLOCK')) 'legacy instruction block upgrades and preserves user text'

    Check ((Get-Content $instructions -Raw).StartsWith($userInstructions)) 'user global instructions preserved verbatim outside managed block'
    Check (Test-Path -LiteralPath (Join-Path $HomeRoot '.config\opencode\plugins\delegation.ts')) 'SDK plugin deployed'
    Check (-not (Test-Path -LiteralPath (Join-Path $HomeRoot '.config\opencode\tools\delegate.ts'))) 'no duplicate advisory delegate tool'
    Check (-not (Test-Path -LiteralPath (Join-Path $HomeRoot '.config\opencode\commands'))) 'removed command directory not required or recreated'
    $dest=Join-Path $HomeRoot '.config\opencode\agents\worker.md'
    Add-Content -LiteralPath $dest -Value 'deployment-only-edit'
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check ((Get-FileHash $dest).Hash -eq (Get-FileHash (Join-Path $Source 'opencode\agents\worker.md')).Hash) 'stale copied profile repaired'
    $backupFiles=@(Get-ChildItem -LiteralPath (Join-Path $HomeRoot '.local\share\tokenomics\backups') -File -Recurse)
    Check (@($backupFiles|Where-Object{(Get-Content -LiteralPath $_.FullName -Raw) -match 'deployment-only-edit'}).Count -ge 1) 'deployment-only edit recoverably backed up'
    $unrelated=Join-Path $HomeRoot '.agents\skills\user-owned';New-Item -ItemType Directory -Path $unrelated | Out-Null
    Set-Content -LiteralPath (Join-Path $unrelated 'SKILL.md') -Value 'user data'
    & (Join-Path $Source 'scripts\uninstall.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check (Test-Path -LiteralPath (Join-Path $unrelated 'SKILL.md')) 'uninstall preserves unrelated skills'
    Check (Test-Path -LiteralPath (Join-Path $Source 'skills\reorient\SKILL.md')) 'junction removal never traverses source'
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check (Test-Path -LiteralPath $dest) 'clean reinstall works'
    $legacy=Join-Path $HomeRoot '.config\opencode\agents\deep.md'
    Set-Content $legacy 'old toolkit with user edits'
    $owned=Get-Content $manifest -Raw|ConvertFrom-Json
    $owned=@($owned)+@([pscustomobject]@{target=$legacy;source=(Join-Path $Source 'opencode\agents\deep.md');kind='file';method='copy'})
    ConvertTo-Json -InputObject $owned -Depth 8|Set-Content $manifest
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check (-not(Test-Path $legacy)) 'old manifest-owned helper retired with backup'
    Set-Content $legacy 'unrelated user agent'
    $ambiguous=Join-Path $HomeRoot '.agents\skills\model-advisor'
    New-Item -ItemType Directory $ambiguous | Out-Null
    Set-Content (Join-Path $ambiguous 'SKILL.md') 'name: model-advisor'
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check ((Get-Content $legacy -Raw).Trim() -eq 'unrelated user agent') 'unrelated same-named old agent preserved'
    Check (Test-Path (Join-Path $ambiguous 'SKILL.md')) 'unrelated same-named retired skill preserved'
    # Simulate a partial manifest that lost only the skill links. Copies remain
    # owned; verified link destinations recover the missing entries.
    $owned=Get-Content $manifest -Raw|ConvertFrom-Json
    ConvertTo-Json -InputObject @($owned|Where-Object{$_.kind -ne 'dir'}) -Depth 8|Set-Content $manifest
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    $owned=Get-Content $manifest -Raw|ConvertFrom-Json
    Check (@($owned|Where-Object{$_.kind -eq 'dir'}).Count -eq 5) 'partial manifest recovers verified managed links'
    Remove-Item -LiteralPath $manifest
    & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    Check (Test-Path $manifest) 'lost manifest recovers copies from independent ownership journal'
    & (Join-Path $Source 'scripts\uninstall.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    $conflict=Join-Path $HomeRoot '.agents\skills\reorient'
    New-Item -ItemType Directory $conflict | Out-Null
    Set-Content (Join-Path $conflict 'SKILL.md') 'user reorient'
    try { & (Join-Path $Source 'scripts\install.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null; throw 'Conflict accepted' }
    catch { if ($_.Exception.Message -notmatch 'Unmanaged resource conflict') { throw } }
    Check ((Get-Content (Join-Path $conflict 'SKILL.md') -Raw).Trim() -eq 'user reorient') 'canonical same-name user skill survives conflict'
} finally {
    if(Test-Path -LiteralPath (Join-Path $Source '.state\install-manifest.json')) {
        & (Join-Path $Source 'scripts\uninstall.ps1') -ToolkitRoot $Source -HomeRoot $HomeRoot | Out-Null
    }
    Remove-Item -LiteralPath $Fixture -Recurse -Force
}
Write-Output 'Deployment contracts passed (isolated home).'
