<# Read-only structural validation for the OpenCode routed edition. #>
$ErrorActionPreference='Stop'
$ToolkitRoot=Split-Path -Parent $PSScriptRoot
$fail=New-Object System.Collections.ArrayList; $warn=New-Object System.Collections.ArrayList
function OK([string]$m){Write-Output "OK:   $m"}
function F([string]$m){[void]$fail.Add($m);Write-Output "FAIL: $m"}
function W([string]$m){[void]$warn.Add($m);Write-Output "WARN: $m"}

$required=@('README.md','AGENTS.md','skills','global','opencode','routing','scripts','tools','docs')
foreach($x in $required){if(Test-Path -LiteralPath (Join-Path $ToolkitRoot $x)){OK "$x present"}else{F "$x missing"}}

# Parse scripts before running installation. Tests are parsed as well.
$psFiles=@(Get-ChildItem -LiteralPath (Join-Path $ToolkitRoot 'scripts') -Filter '*.ps1' -File)
if(Test-Path -LiteralPath (Join-Path $ToolkitRoot 'tests')){$psFiles+=@(Get-ChildItem -LiteralPath (Join-Path $ToolkitRoot 'tests') -Filter '*.ps1' -File)}
foreach($ps1 in $psFiles){
  $tokens=$null; $parseErrors=$null
  [System.Management.Automation.Language.Parser]::ParseFile($ps1.FullName,[ref]$tokens,[ref]$parseErrors) | Out-Null
  if($parseErrors -and $parseErrors.Count -gt 0){
    foreach($pe in $parseErrors){F "PowerShell parse error in $($ps1.Name):$($pe.Extent.StartLineNumber): $($pe.Message)"}
  } else { OK "PowerShell parses: $($ps1.Name)" }
}

$expected=@('reorient','search-index','sync','model-routing','record-outcome')
$catalog=Get-Content (Join-Path $ToolkitRoot 'opencode\catalog.json') -Raw|ConvertFrom-Json
if ((@($catalog.skills|Sort-Object) -join ',') -ne (@($expected|Sort-Object) -join ',')) { F 'install skill catalog differs from public contract' } else { OK 'explicit five-skill installation catalog' }
foreach($group in @('agents','tools','plugins')) {
  $names=@($catalog.$group)
  $extension=if($group-eq'agents'){'*.md'}else{'*.ts'}
  $files=@(Get-ChildItem (Join-Path $ToolkitRoot "opencode\$group") -Filter $extension -File | ForEach-Object {$_.BaseName})
  if((@($names|Sort-Object)-join',')-ne(@($files|Sort-Object)-join',')){F "catalog/source mapping mismatch: $group"}else{OK "catalog/source mapping: $group"}
}
$skillsDir=Join-Path $ToolkitRoot 'skills'
$actual=@(Get-ChildItem -LiteralPath $skillsDir -Directory | ForEach-Object{$_.Name})
foreach($s in $expected){$p=Join-Path $skillsDir "$s\SKILL.md";if(Test-Path -LiteralPath $p){OK "skill present: $s"}else{F "skill missing: $s"}}
foreach($s in $actual){if($expected -notcontains $s){F "unexpected extra toolkit skill: $s"}}
foreach($dir in Get-ChildItem -LiteralPath $skillsDir -Directory){
  $file=Join-Path $dir.FullName 'SKILL.md'; $lines=Get-Content -LiteralPath $file -Encoding UTF8
  if($lines.Count -lt 4 -or $lines[0].Trim() -ne '---'){F "invalid frontmatter: $($dir.Name)";continue}
  $end=-1;for($i=1;$i -lt $lines.Count;$i++){if($lines[$i].Trim() -eq '---'){$end=$i;break}}
  if($end -lt 2){F "unclosed frontmatter: $($dir.Name)";continue}
  $head=($lines[1..($end-1)] -join "`n")
  if($head -notmatch "(?m)^name:\s*$([regex]::Escape($dir.Name))\s*$"){F "skill name mismatch: $($dir.Name)"}
  elseif($head -notmatch '(?m)^description:\s*.+$'){F "skill description missing: $($dir.Name)"}else{OK "frontmatter valid: $($dir.Name)"}
}

$template=Join-Path $ToolkitRoot 'opencode\opencode.template.jsonc'
$config=Join-Path $ToolkitRoot 'opencode\opencode.jsonc'
foreach($p in @($template,$config)){if(Test-Path -LiteralPath $p){OK "present: $([IO.Path]::GetFileName($p))"}else{F "missing: $p"}}
if(Test-Path -LiteralPath $template){
  $t=Get-Content -LiteralPath $template -Raw
  if($t.Contains('"model"')){F 'CLI template still pins a parent model'}else{OK 'CLI template does not pin a parent model'}
  if($t.Contains('__LOCAL_PROVIDER_BLOCK__')){F 'retired local provider token remains in template'}else{OK 'no local provider token in template'}
}
if(Test-Path -LiteralPath $config){
  $c=Get-Content -LiteralPath $config -Raw
  if($c.Contains('"default_agent": "build"')){OK "config contains default Build agent"}else{F "config missing default Build agent"}
  if($c.Contains('"permission":')){F "toolkit config still defines top-level permissions"}else{OK "toolkit config leaves global permissions to user settings"}
  foreach($bad in @('openrouter/','vercel/')){if($c -match [regex]::Escape($bad)){F "metered gateway present in routing config: $bad"}else{OK "no $bad routing"}}
}
$agentTemplates=@('build','researcher','worker','architect','review')
foreach($a in $agentTemplates){
  $tp=Join-Path $ToolkitRoot "opencode\templates\$a.template.md"
  $gp=Join-Path $ToolkitRoot "opencode\agents\$a.md"
  if(Test-Path -LiteralPath $tp){OK "agent template present: $a"}else{F "agent template missing: $a"}
  if(Test-Path -LiteralPath $gp){OK "generated agent present: $a"}else{F "generated agent missing: $a"}
}
foreach($retired in @('index.md','deep.md','index.template.md','deep.template.md')){
  $rp=Join-Path $ToolkitRoot "opencode\agents\$retired"
  if(Test-Path -LiteralPath $rp){F "retired agent still discoverable: $retired"}else{OK "retired agent absent from discovery: $retired"}
}
$templateLeak=@(Get-ChildItem -LiteralPath (Join-Path $ToolkitRoot 'opencode\agents') -File -Filter '*.template.md' -ErrorAction SilentlyContinue)
if($templateLeak.Count -gt 0){F 'generation templates remain under opencode/agents'}else{OK 'generation templates kept out of agent discovery'}
foreach($agentFile in Get-ChildItem -LiteralPath (Join-Path $ToolkitRoot 'opencode\agents') -File -Filter '*.md'){
  $at=Get-Content -LiteralPath $agentFile.FullName -Raw
  if($at.Contains('"*": ask')){F "agent overrides all shell commands to ask: $($agentFile.Name)"}
  if($at.Contains('external_directory: ask')){F "agent overrides external_directory to ask: $($agentFile.Name)"}
  if($at -match '(?m)^model:\s*\S+'){F "role has a permanent model pin: $($agentFile.Name)"}
}
$globalTemplate=Join-Path $ToolkitRoot 'opencode\global-instructions.template.md'
$globalGenerated=Join-Path $ToolkitRoot 'opencode\global-instructions.md'
foreach($p in @($globalTemplate,$globalGenerated)){if(Test-Path -LiteralPath $p){OK "present: $([IO.Path]::GetFileName($p))"}else{F "missing: $p"}}
if(Test-Path -LiteralPath $globalTemplate){
  $g=Get-Content -LiteralPath $globalTemplate -Raw
  if($g.Contains('__ROUTINE_MODEL__') -or $g.Contains('__DEEP_MODEL__')){F 'global instruction template still pins lane models'}else{OK 'global instruction template is model-neutral'}
  if($g.Contains('@architect') -and $g.Contains('@researcher')){OK 'global instructions name retained helpers'}else{F 'global instructions missing architect/researcher'}
}
$roster=Join-Path $ToolkitRoot 'routing\model-roster.json'
try{Get-Content -LiteralPath $roster -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null;OK 'valid JSON: model-roster.json'}catch{F "invalid JSON: $roster"}
$policy=Join-Path $ToolkitRoot 'routing\policy.json'
$state=Join-Path $ToolkitRoot 'routing\state.json'
foreach($p in @($policy,$state)){try{Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null;OK "valid JSON: $([IO.Path]::GetFileName($p))"}catch{F "invalid JSON: $p"}}
$evidence=Join-Path $ToolkitRoot 'routing\model-evidence.json'
$ev=$null
try{$ev=Get-Content -LiteralPath $evidence -Raw -Encoding UTF8 | ConvertFrom-Json;OK 'valid JSON: model-evidence.json'}catch{F "invalid JSON: $evidence"}
if($ev){
  if($ev.schema_version -ne 2){F "model-evidence.json schema_version is $($ev.schema_version), expected 2"}
  $sources=@(); if($ev.sources){$sources=@($ev.sources.PSObject.Properties.Name)}
  $modelProps=@(); if($ev.models){$modelProps=@($ev.models.PSObject.Properties)}
  if($modelProps.Count -eq 0){F 'model-evidence.json contains no models'}else{OK "model-evidence.json has $($modelProps.Count) canonical models"}
  $missingSrc=New-Object System.Collections.ArrayList
  foreach($m in $modelProps){
    $mn=$m.Name; $md=$m.Value
    foreach($k in @($md.source_keys)){if($sources -notcontains $k){[void]$missingSrc.Add("$mn.source_keys -> $k")}}
    foreach($b in @($md.benchmarks)){if($b -and $sources -notcontains $b.source){[void]$missingSrc.Add("$mn.benchmarks -> $($b.source)")}}
    foreach($cap in @($md.capabilities.PSObject.Properties)){
      foreach($k in @($cap.Value.evidence)){if($sources -notcontains $k){[void]$missingSrc.Add("$mn.capabilities.$($cap.Name) -> $k")}}
    }
  }
  if($missingSrc.Count -gt 0){F ("model-evidence.json references unregistered sources: " + ($missingSrc -join ', '))}else{OK 'model-evidence.json source_keys/benchmarks/capability evidence all reference registered sources'}
  if($ev.alias_index){
    $aliasProps=@($ev.alias_index.PSObject.Properties)
    $modelNames=@($modelProps|ForEach-Object{$_.Name})
    $badAlias=@($aliasProps|Where-Object{$modelNames -notcontains ([string]$_.Value)}|ForEach-Object{"$($_.Name) -> $($_.Value)"})
    if($badAlias.Count -gt 0){F ("model-evidence.json alias_index targets missing models: " + ($badAlias -join ', '))}else{OK "alias_index maps $($aliasProps.Count) roster aliases to $($modelProps.Count) models"}
    $used=@($modelProps|ForEach-Object{@($_.Value.source_keys)})
    $orphan=@($sources|Where-Object{$used -notcontains $_})
    if($orphan.Count -gt 0){W "registered sources never referenced by any model source_keys: $($orphan -join ', ')"}
  }
  OK "model-evidence.json counts: $($modelProps.Count) models, $($sources.Count) sources, $((@($ev.alias_index.PSObject.Properties)).Count) aliases"
}
$history=Join-Path $ToolkitRoot 'routing\task-history.json'
try{Get-Content -LiteralPath $history -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null;OK 'valid JSON: task-history.json'}catch{F "invalid JSON: $history"}
$cmdDir=Join-Path $ToolkitRoot 'opencode\commands'
$cmdFiles=@()
if(Test-Path -LiteralPath $cmdDir){$cmdFiles=@(Get-ChildItem -LiteralPath $cmdDir -File -Filter '*.md')}
if($cmdFiles.Count -eq 0){OK 'no toolkit slash-command wrappers'}else{F ("toolkit command wrappers remain: " + (($cmdFiles|ForEach-Object{$_.Name}) -join ', '))}
foreach($s in @('refresh-routing.ps1','bootstrap.ps1','doctor.ps1','install.ps1','sync-global-instructions.ps1','record-task-outcome.ps1','test-advisor.ps1','test-delegate.ps1','test-content-index.ps1','select-model.ps1','opencode.cmd')){if(Test-Path -LiteralPath (Join-Path $ToolkitRoot "scripts\$s")){OK "script present: $s"}else{F "script missing: $s"}}
$indexer=Join-Path $ToolkitRoot 'tools\Project_Content_Indexer.py'
$indexTool=Join-Path $ToolkitRoot 'opencode\tools\content_index.ts'
$delegateTool=Join-Path $ToolkitRoot 'opencode\plugins\delegation.ts'
if(Test-Path -LiteralPath $indexer){OK 'project content indexer present'}else{F 'project content indexer missing'}
if(Test-Path -LiteralPath $indexTool){OK 'OpenCode content_index tool present'}else{F 'OpenCode content_index tool missing'}
if(Test-Path -LiteralPath $delegateTool){OK 'OpenCode delegate plugin present'}else{F 'OpenCode delegate plugin missing'}
if(Test-Path -LiteralPath (Join-Path $ToolkitRoot 'opencode\tools\delegate.ts')){F 'retired advisory delegate would duplicate the plugin tool'}
foreach($f in @('tools\runtime\delegation.mjs','tools\runtime\bridge.mjs')){if(-not(Test-Path -LiteralPath (Join-Path $ToolkitRoot $f))){F "missing runtime implementation: $f"}}
$retiredLocal=@('scripts\install-local-fallback.ps1','scripts\install-local-fallback.cmd','docs\LOCAL-FALLBACK.md','ollama\Modelfile.qwen2.5-coder-7b-16k')
foreach($rel in $retiredLocal){if(Test-Path -LiteralPath (Join-Path $ToolkitRoot $rel)){F "retired local-engine artifact remains: $rel"}else{OK "retired local-engine artifact absent: $rel"}}
foreach($p in @((Join-Path $ToolkitRoot 'routing\policy.json'),(Join-Path $ToolkitRoot 'scripts\refresh-routing.ps1'),(Join-Path $ToolkitRoot 'scripts\select-model.ps1'),(Join-Path $ToolkitRoot 'README.md'),(Join-Path $ToolkitRoot 'AGENTS.md'))){
  $lt=Get-Content -LiteralPath $p -Raw
  if($lt -match '(?i)ollama|ollama-local|local-compute|install-local-fallback|__LOCAL_PROVIDER_BLOCK__'){F "retired local-engine reference remains: $p"}
}
Write-Output ''
Write-Output "Validation summary: $($fail.Count) failures, $($warn.Count) warnings."
if($fail.Count -gt 0){exit 1}else{exit 0}
