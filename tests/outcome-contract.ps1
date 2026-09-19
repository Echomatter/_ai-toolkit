$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$root=Join-Path $env:TEMP ('toolkit-outcome-' + [guid]::NewGuid().ToString('N'))
function Check($c,[string]$s){if(-not $c){throw $s};Write-Output "PASS: $s"}
function Save([string]$p,$o){[IO.File]::WriteAllText($p,($o|ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))}
try {
 New-Item -ItemType Directory -Path (Join-Path $root 'routing'),(Join-Path $root '.state\delegation') -Force|Out-Null
 $history=Join-Path $root 'routing\task-history.json'
 Save $history @{generated=$true;entries=@()}
 $roster=Join-Path $root 'routing\model-roster.json';Save $roster @{generated_at='2020-01-01T00:00:00Z';eligible_models=@()}
 $before=(Get-FileHash $roster).Hash
 $id='a'*64
 Save (Join-Path $root ('.state\delegation\'+$id+'.json')) @{
   task_id=$id;parent_model='opencode/free-parent';role='worker';status='completed';attempts=@(@{
     status='completed';selected_model='opencode-go/b';observed_model='opencode-go/b';surface='opencode-go';elapsed_ms=1000;
     usage=@{input=30;output=20;cache_read=10;cache_write=0;provider_dollars=.01}
   })
 }
 $script=Join-Path $repo 'scripts\record-task-outcome.ps1'
 $params=@{ToolkitRoot=$root;Repo='fixture';TaskType='bounded_feature';Model='opencode-go/b';Access='opencode-go';Success=$true;TestsPassed=$true;Attempts=1;Escalated=$false;ElapsedBand='short';TaskId=$id}
 & $script @params|Out-Null
 & $script @params|Out-Null
 $h=Get-Content $history -Raw|ConvertFrom-Json
 Check (@($h.entries).Count -eq 1) 'duplicate outcome is an upsert'
 Check ($h.entries[0].consumption.source -eq 'session_messages' -and $h.entries[0].consumption.input_tokens -eq 30) 'receipt provides structured per-child consumption'
 Check ((Get-FileHash $roster).Hash -eq $before) 'recording never advances availability discovery'
 & $script -ToolkitRoot $root -TaskId $id -MarkReviewDefect|Out-Null
 $h=Get-Content $history -Raw|ConvertFrom-Json
 Check ($h.entries[0].review_found_defects -eq $true) 'review finding attaches to original attempt'
 & $script @params|Out-Null
 $h=Get-Content $history -Raw|ConvertFrom-Json
 Check ($h.entries[0].review_found_defects -eq $true) 'later recording cannot erase the review defect'
 $params.Model='opencode-go/wrong';$rejected=$false
 try { & $script @params|Out-Null } catch { $rejected=$true }
 Check $rejected 'wrong-model outcome rejected'
 Set-Content -LiteralPath $history -Value '{broken';$corrupt=(Get-FileHash $history).Hash;$rejected=$false
 try { & $script @params|Out-Null } catch { $rejected=$true }
 Check ($rejected -and (Get-FileHash $history).Hash -eq $corrupt) 'malformed history preserved unchanged'
} finally {Remove-Item -LiteralPath $root -Recurse -Force}
