# Deterministic Windows PowerShell 5.1 suite. No OAuth or paid calls required.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
foreach ($suite in @('scripts\validate.ps1','scripts\test-advisor.ps1','scripts\test-delegate.ps1','scripts\test-quota-routing.ps1','scripts\test-content-index.ps1','tests\deployment-contract.ps1','tests\outcome-contract.ps1','tests\refresh-contract.ps1')) {
    Write-Output "Running $suite"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root $suite)
    if ($LASTEXITCODE -ne 0) { throw "Suite failed: $suite (exit $LASTEXITCODE)" }
}
Write-Output 'All offline suites passed.'
