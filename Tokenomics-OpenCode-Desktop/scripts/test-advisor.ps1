<# Isolated selector regression entry point. No live model calls or real history mutation. #>
$ErrorActionPreference='Stop'
& (Join-Path (Split-Path -Parent $PSScriptRoot) 'tests\selector-contract.ps1')
