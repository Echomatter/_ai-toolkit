<# Smoke-test the deterministic project content indexer on a tiny mixed corpus. #>
$ErrorActionPreference='Stop'
$ToolkitRoot=Split-Path -Parent $PSScriptRoot
$Indexer=Join-Path $ToolkitRoot 'tools\Project_Content_Indexer.py'
if(-not (Test-Path -LiteralPath $Indexer)){throw "Indexer missing: $Indexer"}

$python=Get-Command python -ErrorAction SilentlyContinue
$prefix=@()
if(-not $python){
  $python=Get-Command py -ErrorAction SilentlyContinue
  if($python){$prefix=@('-3')}
}
if(-not $python){$python=Get-Command python3 -ErrorAction SilentlyContinue}
if(-not $python){throw 'Python is required for the content index smoke test.'}

function Invoke-Indexer([string[]]$Args){
  $all=@($prefix + @($Indexer) + $Args)
  $out=@(& $python.Source @all 2>&1)
  if($LASTEXITCODE -ne 0){throw "Indexer failed: $($out -join ' ')"}
  return ($out -join [Environment]::NewLine)
}

$root=Join-Path ([IO.Path]::GetTempPath()) ("ai-toolkit-index-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
try {
  @'
# Project Notes

Alpha Reactor is the canonical power source.
Status: active
'@ | Set-Content -LiteralPath (Join-Path $root 'notes.md') -Encoding UTF8

  @'
{
  "module": {
    "name": "Beta Module",
    "status": "ready",
    "latency_ms": 12
  }
}
'@ | Set-Content -LiteralPath (Join-Path $root 'data.json') -Encoding UTF8

  $build=Invoke-Indexer @('rebuild','--root',$root,'--facts','general') | ConvertFrom-Json
  if($build.indexed_sources -lt 2){throw "Expected >=2 indexed sources, got $($build.indexed_sources)"}
  if($build.validation.integrity -ne 'ok'){throw 'SQLite integrity validation did not pass.'}
  if(-not $build.validation.units_equal_fts_rows){throw 'FTS/unit parity validation did not pass.'}

  $search=Invoke-Indexer @('search','Alpha Reactor','--phrase','--limit','10') | ConvertFrom-Json
  if(@($search).Count -lt 1){throw 'Phrase search returned no results.'}
  if(-not (@($search.virtual_path) -contains 'notes.md')){throw 'Phrase search did not locate notes.md.'}

  $structured=Invoke-Indexer @('search','Beta Module','--phrase','--limit','10') | ConvertFrom-Json
  if(@($structured).Count -lt 1){throw 'Structured JSON content was not searchable.'}

  Add-Content -LiteralPath (Join-Path $root 'notes.md') -Value ([Environment]::NewLine + 'Changed after build.')
  $status=Invoke-Indexer @('status','--root',$root) | ConvertFrom-Json
  if(-not $status.stale){throw 'Status did not detect changed source content.'}

  Write-Output 'PASS: content index rebuild/search/structured retrieval/staleness smoke test'
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
