<# Offline quota and economics contracts. Live accounts are deliberately not a CI dependency. #>
$ErrorActionPreference='Stop'
& (Join-Path (Split-Path -Parent $PSScriptRoot) 'tests\selector-contract.ps1')
