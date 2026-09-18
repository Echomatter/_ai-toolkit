<# Smoke-test the deterministic project content index on a tiny mixed corpus. #>
$ErrorActionPreference='Stop'
$ToolkitRoot=Split-Path -Parent $PSScriptRoot
$script=Join-Path $ToolkitRoot 'tools\Project_Content_Indexer.py'
$python=Get-Command python -ErrorAction SilentlyContinue
if(-not $python){throw 'python not found'}

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
  $build=@(& $python.Source $script --db $db rebuild --root $root --facts general 2>$null)
  if($LASTEXITCODE -ne 0){throw 'index rebuild failed'}
  $bj=($build -join "`n") | ConvertFrom-Json
  if($bj.schema_version -ne '3.0'){throw "unexpected schema version: $($bj.schema_version)"}
  if($bj.validation.integrity -ne 'ok'){throw 'index integrity validation failed'}

  $search=@(& $python.Source $script --db $db search 'Quantum Ogre' --phrase --limit 20 2>$null)
  if($LASTEXITCODE -ne 0){throw 'index search failed'}
  $sj=($search -join "`n") | ConvertFrom-Json
  if(@($sj).Count -lt 2){throw "expected cross-source search hits, got $(@($sj).Count)"}

  $facts=@(& $python.Source $script --db $db facts --family identity --limit 20 2>$null)
  if($LASTEXITCODE -ne 0){throw 'index fact query failed'}
  if(-not (($facts -join "`n") -match 'Quantum Ogre')){throw 'structured fact layer did not retain expected identity value'}

  $status=@(& $python.Source $script --db $db status --root $root 2>$null)
  if($LASTEXITCODE -ne 0){throw 'index status failed'}
  $st=($status -join "`n") | ConvertFrom-Json
  if($st.stale){throw 'freshly rebuilt index reports stale'}

  Write-Output 'Content index smoke test: PASS'
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
