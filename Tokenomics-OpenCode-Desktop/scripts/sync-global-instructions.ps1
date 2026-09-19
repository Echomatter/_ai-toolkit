<#
.SYNOPSIS
  Merges or removes this toolkit's managed block in OpenCode's global AGENTS.md.
.DESCRIPTION
  Preserves user-authored global instructions outside toolkit markers.
  Windows PowerShell 5.1 compatible.
#>
param([switch]$Remove, [string]$ToolkitRoot = '', [string]$HomeRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $ToolkitRoot) { $ToolkitRoot = Split-Path -Parent $PSScriptRoot }
if (-not $HomeRoot) { $HomeRoot = $env:USERPROFILE }
$Source = Join-Path $ToolkitRoot 'opencode\global-instructions.md'
$configBase = if ($env:XDG_CONFIG_HOME -and $HomeRoot -eq $env:USERPROFILE) { $env:XDG_CONFIG_HOME } else { Join-Path $HomeRoot '.config' }
$TargetDir = Join-Path $configBase 'opencode'
$Target = Join-Path $TargetDir 'AGENTS.md'
$Begin = '<!-- BEGIN TOKENOMICS MANAGED BLOCK -->'
$End = '<!-- END TOKENOMICS MANAGED BLOCK -->'
function Write-Utf8NoBom([string]$Path,[string]$Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    $tmp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    [System.IO.File]::WriteAllText($tmp,$Text,$enc)
    if(Test-Path -LiteralPath $Path){
        $backupDir=Join-Path $HomeRoot '.local\share\tokenomics\backups\instructions'
        New-Item -ItemType Directory -Path $backupDir -Force|Out-Null
        $backup=Join-Path $backupDir ([guid]::NewGuid().ToString('N')+'.md')
        [System.IO.File]::Replace($tmp,$Path,$backup)
    }else{[System.IO.File]::Move($tmp,$Path)}
}
if (-not (Test-Path -LiteralPath $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
$existing = ''
if (Test-Path -LiteralPath $Target) { $existing = Get-Content -LiteralPath $Target -Raw -Encoding UTF8 }
$pattern = '(?s)<!-- BEGIN (?:TOKENOMICS|AI-TOOLKIT) MANAGED BLOCK -->.*?<!-- END (?:TOKENOMICS|AI-TOOLKIT) MANAGED BLOCK -->'
$base = [regex]::Replace($existing,$pattern,'')
if ($Remove) {
    if (-not $base.Trim()) {
        if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Force -Confirm:$false }
    } elseif($base-ne$existing) { Write-Utf8NoBom $Target $base }
    Write-Output 'OpenCode global toolkit instructions removed.'
    return
}
if (-not (Test-Path -LiteralPath $Source)) { throw "Generated global instructions missing: $Source" }
$managed = (Get-Content -LiteralPath $Source -Raw -Encoding UTF8).Trim()
$block = $Begin + "`r`n" + $managed + "`r`n" + $End
if([regex]::IsMatch($existing,$pattern)) { $out=[regex]::Replace($existing,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $block}) }
elseif ($existing) { $out = $existing + "`r`n`r`n" + $block + "`r`n" }
else { $out = $block + "`r`n" }
if($out-ne$existing){Write-Utf8NoBom $Target $out}
Write-Output "OpenCode global toolkit instructions synchronized: $Target"
