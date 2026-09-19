<# Native-SDK execution controller tests with independent fixture responses. #>
$ErrorActionPreference='Stop'
& node --test (Join-Path (Split-Path -Parent $PSScriptRoot) 'tests\delegate-runtime.test.mjs') (Join-Path (Split-Path -Parent $PSScriptRoot) 'tests\presentation.test.mjs') (Join-Path (Split-Path -Parent $PSScriptRoot) 'tests\usage.test.mjs')
if($LASTEXITCODE-ne 0){throw 'Delegate runtime contracts failed.'}
