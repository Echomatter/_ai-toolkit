<# Deterministic offline selector contracts; never uses live credentials/history. #>
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Root = Join-Path $env:TEMP ('toolkit-selector-' + [guid]::NewGuid().ToString('N'))
$failed = 0
function Check($condition,[string]$name) { if ($condition) { Write-Output "PASS: $name" } else { $script:failed++; Write-Output "FAIL: $name" } }
function Json([string]$rel,$obj) {
    $p = Join-Path $Root $rel; New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
    [IO.File]::WriteAllText($p,(ConvertTo-Json -InputObject $obj -Depth 15),(New-Object Text.UTF8Encoding($false)))
}
function Run-Selection($extra=@{}) {
    $args2=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $RepoRoot 'scripts\select-model.ps1'),'-ToolkitRoot',$Root,'-Role','worker')
    foreach ($k in $extra.Keys) { $args2 += @('-' + $k,[string]$extra[$k]) }
    $raw = & powershell.exe @args2
    if ($LASTEXITCODE -ne 0) { throw 'Selector failed' }
    return (($raw -join "`n") | ConvertFrom-Json)
}
function State($used=20,$status='ok',$age=0) {
    $windows=[ordered]@{}
    foreach ($w in @('rolling','weekly','monthly')) { $windows[$w]=@{ used_percent=$used; status=$status; resets_at=(Get-Date).ToUniversalTime().AddHours(2).ToString('o') } }
    return @{ generated_at=(Get-Date).ToUniversalTime().ToString('o'); surfaces=@{
        'opencode-go'=@{ telemetry=@{status='ok';as_of=(Get-Date).ToUniversalTime().AddMinutes(-$age).ToString('o');source='fixture'};windows=$windows }
    }}
}
try {
    New-Item -ItemType Directory -Path (Join-Path $Root 'routing') -Force | Out-Null
    $caps=@{}
    foreach($c in @('coding','routine_coding','tool_use','speed','research','repo_understanding','architecture','debugging','long_horizon_engineering','deep_reasoning','agentic_work','terminal_agent_work','code_review')) { $caps[$c]=@{rating='strong';confidence='high';evidence=@('fixture')} }
    $models=@{}; $aliases=@{}
    foreach($id in @('opencode-go/cheap','opencode-go/expensive','openai/other','opencode/free')) {
        $models[$id]=@{ provider=$id; capabilities=$caps; context=@{input_tokens=128000}; research_status='researched_current'; benchmarks=@() }
        $aliases[$id]=$id
    }
    $models['opencode-go/unknown']=@{provider='unknown';capabilities=@{};research_status='identity_only';benchmarks=@()}
    $aliases['opencode-go/unknown']='opencode-go/unknown'
    $roster=@{eligible_models=@(@{id='opencode-go/cheap';surface='opencode-go'},@{id='opencode-go/expensive';surface='opencode-go'},@{id='opencode-go/unknown';surface='opencode-go'})}
    Json 'routing\policy.json' @{allowed_surfaces=@('opencode-go','opencode-free','openai-oauth','github-copilot-oauth');allow_overage=$false}
    Json 'routing\model-roster.json' $roster
    Json 'routing\model-evidence.json' @{schema_version=2;advisor_readiness='READY';evidence_as_of=(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd');models=$models;alias_index=$aliases;sources=@{fixture=@{}}}
    Json 'routing\task-history.json' @{entries=@()}
    Json 'routing\state.json' @{}
    Json 'routing\go-pricing.json' @{window_shares=@{rolling=.2;weekly=.5;monthly=1};models=@{
        'opencode-go/cheap'=@{input=.1;output=.2;cache_read=.002;monthly_limit=60}
        'opencode-go/expensive'=@{input=2;output=6;cache_read=.4;monthly_limit=15}
    }}
    $a=Run-Selection
    Check ($a.selected_model -eq 'opencode-go/cheap') 'omitted estimates use a workload prior and distinguish same-pool models'
    Check ($a.adequacy -in @('adequate','strong')) 'selected candidate clears real quality floor'
    Check (@($a.filtered_out | Where-Object {$_.id -eq 'opencode-go/unknown'}).Count -eq 1) 'unknown capability does not qualify'
    Check ($a.consumption_estimate.monthly_fraction -gt 0) 'static economics remains useful without telemetry'
    Check ($a.execution_surface -eq 'delegate') 'explicit role selects child execution, not a parent model switch'
    Json '.state\quota-state.json' (State 90)
    $b=Run-Selection
    Check ($b.consumption_estimate.window_pressure -gt 0) 'scarcity changes predicted task pressure'
    Check ($b.selected_model) '90 percent use is not an exhausted pool'
    Json '.state\quota-state.json' (State 102 'rate-limited')
    $c=Run-Selection
    Check ($null -eq $c.selected_model) 'exhausted shared Go pool excludes every affected model'
    Json '.state\quota-state.json' (State 20)
    $d=Run-Selection @{ExcludedModels='opencode-go/cheap'}
    Check ($d.selected_model -eq 'opencode-go/expensive') 'failed model can be excluded without excluding a healthy same-pool model'
    $e=Run-Selection @{NeedsLargeContextTokens='200000'}
    Check ($null -eq $e.selected_model) 'known insufficient context filters candidates'
    $f=Run-Selection @{NeedsModelDiversity='true';ExcludeModel='opencode-go/cheap'}
    Check ($f.selected_model -eq 'opencode-go/expensive') 'explicit model independence honored'
    $g=Run-Selection @{CurrentModel='opencode-go/expensive'}
    Check ($g.selected_model -eq 'opencode-go/cheap' -and $g.surface -eq 'opencode-go') 'child selection not overridden by stale stay-put metadata'
    $roster.eligible_models=@(@{id='opencode-go/cheap';surface='opencode-go'})
    Json 'routing\model-roster.json' $roster
    $h=Run-Selection
    Check ($h.selected_model -and $null -eq $h.fallback_model -and @($h.phases).Count -eq 1) 'one candidate has no fabricated fallback/reviewer'
    $q=State 20
    $q.surfaces['opencode-go'].execution=@{blocked=$true;reason='quota_exhaustion';reset_at='';recheck_at=(Get-Date).AddMinutes(-2).ToString('o');recheck_count=99}
    Json '.state\quota-state.json' $q
    $i=Run-Selection
    Check ($null -eq $i.selected_model) 'unknown-reset failure count never restores normal eligibility'
    Json '.state\quota-state.json' (State 20)
    Json '.state\delegation\blocks\example.json' @{scope='model';key='opencode-go/cheap';reason='auth';recorded_at=(Get-Date).ToString('o')}
    $j=Run-Selection
    Check ($null -eq $j.selected_model) 'durable execution-side health excludes a failed route'
    Remove-Item -LiteralPath (Join-Path $Root '.state\delegation\blocks\example.json')
    $roster.eligible_models += @{id='openai/other';surface='openai-oauth'}
    Json 'routing\model-roster.json' $roster
    $q=State 20
    $q.surfaces['openai-oauth']=@{telemetry=@{status='ok';as_of=(Get-Date).ToUniversalTime().ToString('o')};allowed=$false;limit_reached=$true;windows=@{primary=@{used_percent=100}}}
    Json '.state\quota-state.json' $q
    $k=Run-Selection
    Check (@($k.filtered_out | Where-Object {$_.id -eq 'openai/other' -and $_.reason -match 'exhausted'}).Count -eq 1) 'confirmed relevant ChatGPT exhaustion is a hard exclusion'
    $q.surfaces['openai-oauth'].telemetry.as_of=(Get-Date).ToUniversalTime().AddDays(-1).ToString('o')
    Json '.state\quota-state.json' $q
    $l=Run-Selection
    Check (@($l.ranking | Where-Object {$_.id -eq 'openai/other'}).Count -eq 1) 'one successful provider does not make unrelated stale data fresh'
    $roster.eligible_models=@()
    Json 'routing\model-roster.json' $roster
    $m=Run-Selection
    Check ($null -eq $m.selected_model -and @($m.phases).Count -eq 0) 'empty inventory returns a valid no-route result'
} finally { Remove-Item -LiteralPath $Root -Recurse -Force }
if ($failed) { throw "$failed selector contracts failed" }
Write-Output 'Selector contracts passed (isolated fixtures; no live model calls).'
