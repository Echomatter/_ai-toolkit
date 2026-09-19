# Opt-in live provider exercise, deliberately excluded from credential-free CI.
param([switch]$Live, [string]$ParentModel='opencode/big-pickle')
$ErrorActionPreference='Stop'
if(-not $Live){throw 'Use -Live to authorize a real model request with existing OpenCode authentication.'}
$root=Split-Path -Parent $PSScriptRoot
$log=Join-Path $root ('.state\live-'+[guid]::NewGuid().ToString('N')+'.jsonl')
$prompt='Read-only toolkit integration test. Invoke delegate exactly once with role worker, taskTypes [repo_navigation], needsWrites false, freeOnly true, preferredCostClass free, needsModelDiversity true. Task: Read opencode/catalog.json using read and return the exact five skill names. No shell, writes or nested agents. Return the delegate receipt. Do not retry or perform the task yourself.'
& opencode run --dir $root --agent build --model $ParentModel --format json --title 'Toolkit live cross-model contract' $prompt | Set-Content -LiteralPath $log -Encoding UTF8
if($LASTEXITCODE-ne 0){throw "OpenCode run failed. Local log: $log"}
$events=@(Get-Content $log|Where-Object{$_.Trim().StartsWith('{')}|ForEach-Object{$_|ConvertFrom-Json})
$calls=@($events|Where-Object{($_.part.tool-eq'delegate'-or$_.part.state.metadata.ai_toolkit_delegate_display.original_tool-eq'delegate')-and$_.part.state.status-eq'completed'}|Group-Object {$_.part.callID}|ForEach-Object{$_.Group[-1]})
if($calls.Count-ne 1){throw "Expected one completed delegate call; got $($calls.Count). Local log: $log"}
$receipt=$calls[0].part.state.output|ConvertFrom-Json
$attempt=@($receipt.attempts)[-1]
if($receipt.status-ne'completed'){throw "Child failed: $($attempt.failure). Local log: $log"}
if($attempt.selected_model-ne$attempt.dispatched_model-or$attempt.selected_model-ne$attempt.observed_model){throw 'Selected/dispatched/observed mismatch'}
if($receipt.parent_model-ne$ParentModel-or$attempt.observed_model-eq$ParentModel){throw 'Not a cross-model execution with the requested parent'}
$export=Join-Path $root ('.state\live-parent-'+$receipt.parent_session+'.json')
& opencode export $receipt.parent_session | Set-Content -LiteralPath $export -Encoding UTF8
if($LASTEXITCODE-ne 0){throw 'Could not independently export parent session'}
$parent=Get-Content $export -Raw|ConvertFrom-Json
$models=@($parent.messages|Where-Object{$_.info.role-eq'assistant'}|ForEach-Object{"$($_.info.providerID)/$($_.info.modelID)"}|Sort-Object -Unique)
if($models.Count-ne 1-or$models[0]-ne$ParentModel){throw 'Parent model changed in runtime message history'}
$catalog=Get-Content (Join-Path $root 'opencode\catalog.json') -Raw|ConvertFrom-Json
foreach($skill in $catalog.skills){if($receipt.result-notmatch[regex]::Escape($skill)){throw "Child omitted $skill"}}
Write-Output 'PASS: live selected/dispatched/observed child identity and catalog result'
Write-Output 'PASS: exported parent assistant messages retain the requested model'
$receipt|Select-Object task_id,parent_model,role,status,attempts|ConvertTo-Json -Depth 8
Write-Output "Local evidence: $log"
