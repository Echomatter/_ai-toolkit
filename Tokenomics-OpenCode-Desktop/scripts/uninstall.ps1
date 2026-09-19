<# Removes only manifest-owned toolkit resources using the same recovery-safe deployment path. #>
[CmdletBinding()]
param([string]$ToolkitRoot = '', [string]$HomeRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $ToolkitRoot) { $ToolkitRoot = Split-Path -Parent $PSScriptRoot }
& (Join-Path $ToolkitRoot 'scripts\install.ps1') -ToolkitRoot $ToolkitRoot -HomeRoot $HomeRoot -Uninstall
