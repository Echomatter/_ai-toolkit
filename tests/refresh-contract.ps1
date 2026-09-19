$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $env:TEMP ('toolkit-refresh-'+[guid]::NewGuid().ToString('N'))
$oldPath=$env:Path
try {
 New-Item -ItemType Directory -Path $fixture,(Join-Path $fixture 'scripts'),(Join-Path $fixture 'bin') -Force|Out-Null
 foreach($folder in @('opencode','routing')){Copy-Item (Join-Path $repo $folder) (Join-Path $fixture $folder) -Recurse}
 foreach($file in @('refresh-routing.ps1','select-model.ps1')){Copy-Item (Join-Path $repo "scripts\$file") (Join-Path $fixture "scripts\$file")}
 Set-Content (Join-Path $fixture 'bin\opencode.cmd') "@echo off`r`nif `"%~1`"==`"models`" echo opencode/big-pickle`r`nexit /b 0"
 $env:Path=(Join-Path $fixture 'bin')+';'+$oldPath
 $history=Join-Path $fixture 'routing\task-history.json'
 $nested=@{entries=@(@{task_id='one';execution_attempts=@(@{usage=@{cache=@{read=123}}})});generated_at='old'}
 ConvertTo-Json -InputObject $nested -Depth 12|Set-Content $history
 $before=(Get-FileHash $history).Hash
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture 'scripts\refresh-routing.ps1') -NoRefresh -Quiet
 if($LASTEXITCODE-ne 0){throw 'Isolated inventory refresh failed'}
 if((Get-FileHash $history).Hash-ne$before){throw 'Inventory refresh altered outcome history'}
 Write-Output 'PASS: inventory refresh preserves nested outcome history and observation timestamps byte-for-byte'
 $evidence=Join-Path $fixture 'routing\model-evidence.json'
 Set-Content $evidence '{broken'
 $before=(Get-FileHash $evidence).Hash
 $errorLog=Join-Path $fixture 'expected-error.log'
 $ErrorActionPreference='Continue'
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture 'scripts\refresh-routing.ps1') -NoRefresh -Quiet *> $errorLog
 $ErrorActionPreference='Stop'
 if($LASTEXITCODE-eq 0-or(Get-FileHash $evidence).Hash-ne$before){throw 'Corrupt evidence was accepted or overwritten'}
 Write-Output 'PASS: malformed evidence remains intact instead of being replaced by an empty cache'
} finally {
 $env:Path=$oldPath
 if(-not[IO.Path]::GetFullPath($fixture).StartsWith([IO.Path]::GetFullPath($env:TEMP),[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected fixture path'}
 Remove-Item -LiteralPath $fixture -Recurse -Force
}
