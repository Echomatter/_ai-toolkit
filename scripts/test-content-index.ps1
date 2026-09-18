<# Smoke-test the deterministic project content index on a tiny mixed corpus. #>
$ErrorActionPreference='Stop'
$ToolkitRoot=Split-Path -Parent $PSScriptRoot
$script=Join-Path $ToolkitRoot 'tools\Project_Content_Indexer.py'
$python=Get-Command python -ErrorAction SilentlyContinue
if(-not $python){throw 'python not found'}

function Invoke-IndexJson([string[]]$Arguments) {
  $previous=$ErrorActionPreference
  try {
    $ErrorActionPreference='Continue'
    $out=@(& $python.Source $script @Arguments 2>$null)
    $code=$LASTEXITCODE
  } finally {
    $ErrorActionPreference=$previous
  }
  if($code -ne 0){ throw "index command failed ($code): $($Arguments -join ' ')" }
  return (($out -join "`n") | ConvertFrom-Json)
}

$root=Join-Path $env:TEMP ("ai-toolkit-index-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
try{
  Set-Content -LiteralPath (Join-Path $root 'notes.md') -Encoding UTF8 -Value @'
# Encounter notes

The Quantum Ogre appears only after the keyed gate is opened.
Its encounter token is QO-64.
'@
  Set-Content -LiteralPath (Join-Path $root 'records.json') -Encoding UTF8 -Value @'
{
  "encounters": [
    {"name": "Quantum Ogre", "token": "QO-64", "status": "current"},
    {"name": "Drone Hound", "token": "DH-07", "status": "current"}
  ]
}
'@

  $db=Join-Path $root '.content-index\Project_Content_Index.sqlite'
  $bj=Invoke-IndexJson @('--db',$db,'rebuild','--root',$root,'--facts','general')
  if($bj.schema_version -ne '3.0'){throw "unexpected schema version: $($bj.schema_version)"}
  if($bj.validation.integrity -ne 'ok'){throw 'index integrity validation failed'}

  $sj=Invoke-IndexJson @('--db',$db,'search','Quantum Ogre','--phrase','--limit','20')
  if(@($sj).Count -lt 2){throw "expected cross-source search hits, got $(@($sj).Count)"}

  $facts=Invoke-IndexJson @('--db',$db,'facts','--family','identity','--limit','20')
  if(-not (($facts | ConvertTo-Json -Depth 6) -match 'Quantum Ogre')){throw 'structured fact layer did not retain expected identity value'}

  $st=Invoke-IndexJson @('--db',$db,'status','--root',$root)
  if($st.stale){throw 'freshly rebuilt index reports stale'}

  Write-Output 'Content index smoke test: PASS'
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
