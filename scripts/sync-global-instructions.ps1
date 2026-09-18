<#
.SYNOPSIS
  Merges or removes this toolkit's managed block in OpenCode's global AGENTS.md.

.DESCRIPTION
  Preserves any user-authored global instructions outside the toolkit markers.
  Windows PowerShell 5.1 compatible.
#>
param([switch]$Remove)
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $ToolkitRoot 'opencode\global-instructions.md'
$TargetDir = Join-Path $env:USERPROFILE '.config\opencode'
$Target = Join-Path $TargetDir 'AGENTS.md'
$Begin = '<!-- BEGIN AI-TOOLKIT MANAGED BLOCK -->'
$End = '<!-- END AI-TOOLKIT MANAGED BLOCK -->'

function Write-Utf8NoBom([string]$Path,[string]$Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path,$Text,$enc)
}

if (-not (Test-Path -LiteralPath $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
$existing = ''
if (Test-Path -LiteralPath $Target) { $existing = Get-Content -LiteralPath $Target -Raw -Encoding UTF8 }

# Escape the marker strings explicitly for Windows PowerShell/.NET regex compatibility.
$pattern = '(?s)\r?\n?' + [regex]::Escape($Begin) + '.*?' + [regex]::Escape($End) + '\r?\n?'
$base = [regex]::Replace($existing,$pattern,"`r`n").Trim()

if ($Remove) {
    if (-not $base) {
        if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Force -Confirm:$false }
    } else {
        Write-Utf8NoBom $Target ($base + "`r`n")
    }
    Write-Output 'OpenCode global toolkit instructions removed.'
    exit 0
}

if (-not (Test-Path -LiteralPath $Source)) { throw "Generated global instructions missing: $Source" }
$managed = (Get-Content -LiteralPath $Source -Raw -Encoding UTF8).Trim()
$block = $Begin + "`r`n" + $managed + "`r`n" + $End
if ($base) { $out = $base + "`r`n`r`n" + $block + "`r`n" }
else { $out = $block + "`r`n" }
Write-Utf8NoBom $Target $out
Write-Output "OpenCode global toolkit instructions synchronized: $Target"
