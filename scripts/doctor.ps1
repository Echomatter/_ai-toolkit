<# Read-only diagnostics for the OpenCode routed stack. #>
param([switch]$Deep)
$ErrorActionPreference = 'Continue'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$fail=0; $warn=0
function OK([string]$m){ Write-Output "OK:   $m" }
function WARN([string]$m){ $script:warn++; Write-Output "WARN: $m" }
function FAIL([string]$m){ $script:fail++; Write-Output "FAIL: $m" }
$env:OPENCODE_CONFIG = Join-Path $ToolkitRoot 'opencode\opencode.jsonc'
$env:OPENCODE_CONFIG_DIR = Join-Path $ToolkitRoot 'opencode'
$env:OPENCODE_ENABLE_EXA = '1'

$oc=Get-Command opencode -ErrorAction SilentlyContinue
function Invoke-OpenCodeCaptured([string[]]$Arguments) {
  if(-not $oc){ return [pscustomobject]@{Output=@();ExitCode=127} }
  $previous=$ErrorActionPreference
  try {
    $ErrorActionPreference='Continue'
    $output=@(& $oc.Source @Arguments 2>&1)
    $exitCode=$LASTEXITCODE
  } finally { $ErrorActionPreference=$previous }
  return [pscustomobject]@{Output=$output;ExitCode=$exitCode}
}
if($oc){
  $ver=(& $oc.Source --version 2>&1 | Out-String).Trim(); OK "OpenCode found: $ver"
  try { $models=@(& $oc.Source models 2>&1); if($LASTEXITCODE -eq 0 -and $models.Count -gt 0){ OK "OpenCode model inventory available ($($models.Count) entries)." } else { FAIL 'OpenCode model inventory failed.' } } catch { FAIL 'OpenCode model inventory failed.' }
}else{ FAIL 'OpenCode command not found.' }

$gh=Get-Command gh -ErrorAction SilentlyContinue
if($gh){
  OK 'GitHub CLI found.'
  & $gh.Source auth status *> $null
  if($LASTEXITCODE -eq 0){ OK 'GitHub CLI authenticated.' } else { WARN 'GitHub CLI is installed but not authenticated; run gh auth login.' }
}else{ WARN 'GitHub CLI not found; remote GitHub work will be unavailable.' }

$skills=@('repo-reorient','local-repo-research','github-ops','change-audit','evidence-ledger','bounded-experiment','model-routing','model-advisor','handoff-brief')
foreach($s in $skills){ $p=Join-Path $env:USERPROFILE ".agents\skills\$s\SKILL.md"; if(Test-Path -LiteralPath $p){OK "skill installed: $s"}else{FAIL "skill missing: $s"} }


$ocGlobal=Join-Path $env:USERPROFILE '.config\opencode'
foreach($a in @('build','deep','review')){
  $p=Join-Path $ocGlobal "agents\$a.md"
  if(Test-Path -LiteralPath $p){OK "Desktop agent installed: $a"}else{FAIL "Desktop agent missing: $a"}
}
foreach($c in @('reorient','prior-art','audit','routing','github','recommend-model','refresh-model-evidence','record-outcome')){
  $p=Join-Path $ocGlobal "commands\$c.md"
  if(Test-Path -LiteralPath $p){OK "Desktop command installed: /$c"}else{FAIL "Desktop command missing: /$c"}
}

$globalAgents=Join-Path $env:USERPROFILE '.config\opencode\AGENTS.md'
if(Test-Path -LiteralPath $globalAgents){
  $ga=Get-Content -LiteralPath $globalAgents -Raw
  if($ga -match '<!-- BEGIN AI-TOOLKIT MANAGED BLOCK -->' -and $ga -match '<!-- END AI-TOOLKIT MANAGED BLOCK -->'){OK 'OpenCode global toolkit instruction block installed.'}else{WARN 'OpenCode global AGENTS.md exists but toolkit managed block was not found.'}
}else{FAIL 'OpenCode global AGENTS.md missing; routing/promotion guidance will not load in Desktop.'}

$rosterPath=Join-Path $ToolkitRoot 'routing\model-roster.json'
if(Test-Path -LiteralPath $rosterPath){
   try { $roster=Get-Content -LiteralPath $rosterPath -Raw -Encoding UTF8 | ConvertFrom-Json; OK "Model roster present ($(@($roster.eligible_models).Count) eligible entries)." } catch { FAIL 'model roster is invalid JSON.' }
} else { FAIL 'model roster missing.' }

$statePath=Join-Path $ToolkitRoot 'routing\state.json'
if(Test-Path -LiteralPath $statePath){
   try {
      $st=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
      OK "Routine: $($st.routine)"; OK "Deep: $($st.deep)"; OK "Review: $($st.review)"
      $distinct = $true
      if($null -ne $st.review_is_distinct_model){ $distinct = [bool]$st.review_is_distinct_model }
      elseif($null -ne $st.review_is_independent){ $distinct = [bool]$st.review_is_independent }
      if(-not $distinct){ WARN 'Review currently uses the same model ID as Deep.' }
    } catch { FAIL 'routing state is invalid JSON.' }
} else { FAIL 'routing state missing.' }

$evidencePath = Join-Path $ToolkitRoot 'routing\model-evidence.json'
$evidenceData = $null
$evidenceCanonicalCount = 0
$evidenceResearchedCurrent = 0
$evidenceProviderOnly = 0
$evidenceAliasCoverage = 0
$evidenceAliasMissing = @()
$evidenceSourcesTotal = 0
$evidenceIndependentSources = 0
if(Test-Path -LiteralPath $evidencePath){
    try {
        $evidenceData = Get-Content -LiteralPath $evidencePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if($evidenceData.schema_version -ne 2){ FAIL 'model-evidence.json is not schema_version 2.' }
        if($evidenceData.models){
            $evidenceCanonicalCount = @($evidenceData.models.PSObject.Properties).Count
            foreach($prop in @($evidenceData.models.PSObject.Properties)){
                if($prop.Value.research_status -eq 'researched_current'){ $evidenceResearchedCurrent++ }
                elseif($prop.Value.research_status -eq 'provider_researched'){ $evidenceProviderOnly++ }
            }
        }
        if($evidenceData.alias_index -and $roster){
            foreach($rid in @($roster.eligible_models | ForEach-Object { $_.id })){
                if($evidenceData.alias_index.PSObject.Properties.Name -contains $rid){ $evidenceAliasCoverage++ }
                else { $evidenceAliasMissing += $rid }
            }
            if($evidenceAliasMissing.Count -gt 0){ FAIL ("evidence alias_index misses roster IDs: " + ($evidenceAliasMissing -join ', ')) }
        }
        if($evidenceData.sources){
            $evidenceSourcesTotal = @($evidenceData.sources.PSObject.Properties).Count
            $evidenceIndependentSources = @($evidenceData.sources.PSObject.Properties | Where-Object { $_.Value.source_type -eq 'INDEPENDENT' }).Count
        }
        OK "Model evidence database present (schema v$($evidenceData.schema_version), $evidenceCanonicalCount canonical models, alias coverage $evidenceAliasCoverage)."
        if($evidenceData.readiness_reason){ OK "Readiness reason: $($evidenceData.readiness_reason)" }
    } catch { FAIL 'model-evidence.json is invalid JSON.' }
} else { FAIL 'model-evidence.json missing.' }

# Review independence is about the underlying model vendor, not merely a
# different provider/access prefix. Warn when Deep and Review resolve to the
# same canonical vendor so users know the second pass is less independent.
if($evidenceData -and $st -and $evidenceData.alias_index -and $evidenceData.models){
    function Get-EvidenceProvider([string]$rid){
        $ck = $null
        foreach($p in @($evidenceData.alias_index.PSObject.Properties)){ if($p.Name -eq $rid){ $ck=[string]$p.Value; break } }
        if(-not $ck){ return '' }
        foreach($p in @($evidenceData.models.PSObject.Properties)){
            if($p.Name -eq $ck -and $p.Value.provider){ return ([string]$p.Value.provider).ToLower() }
        }
        return ''
    }
    $deepVendor = Get-EvidenceProvider ([string]$st.deep)
    $reviewVendor = Get-EvidenceProvider ([string]$st.review)
    if($deepVendor -and $reviewVendor -and $deepVendor -eq $reviewVendor -and $st.deep -ne $st.review){
        WARN "Review uses a different model ID but the same model vendor as Deep ($deepVendor); cross-vendor independence is reduced."
    }
}

# ---- Enhanced reporting -------------------------------------------
Write-Output ''
Write-Output '--- Advisor diagnostics ---'
$eligibleCount = 0
$opencodeFreeCount = 0
$openaiOauthCount = 0
$copilotOauthCount = 0
$ollamaLocalCount = 0
if($roster){ $eligibleCount = @($roster.eligible_models).Count }
if($st){
    $opencodeFreeCount = $st.eligible.opencode_free
    $openaiOauthCount = $st.eligible.openai_oauth
    $copilotOauthCount = $st.eligible.github_copilot_oauth
    $ollamaLocalCount = $st.eligible.ollama_local
}
Write-Output "Eligible models: $eligibleCount"
Write-Output ""
Write-Output "Current lanes:"
Write-Output "Routine (Build): $($st.routine)"
Write-Output "Explore: native OpenCode agent (no fixed model)"
Write-Output "Deep: $($st.deep)"
Write-Output "Review: $($st.review)"
Write-Output ""
$rosterAge = 'unknown'
if($roster -and $roster.generated_at){
    try {
       $genDate = [DateTime]$roster.generated_at
       $ageDays = (New-TimeSpan -Start $genDate -End (Get-Date)).Days
       $rosterAge = "$ageDays day(s)"
    } catch { $rosterAge = 'unknown' }
}
Write-Output "Availability roster age: $rosterAge"

# Evidence age and freshness (schema v2: evidence_as_of is a date string).
$evidenceAge = 'unknown'
$evidenceFreshness = 'UNPOPULATED'
if($evidenceData -and $evidenceData.evidence_as_of){
    try {
       $genDate = [DateTime]$evidenceData.evidence_as_of
       $ageDays = (New-TimeSpan -Start $genDate -End (Get-Date)).Days
       $evidenceAge = "$ageDays day(s)"
       if($ageDays -le 1){ $evidenceFreshness = 'current' } elseif($ageDays -le 3){ $evidenceFreshness = 'partially stale' } elseif($ageDays -le 7){ $evidenceFreshness = 'stale' } else { $evidenceFreshness = 'very stale' }
    } catch { $evidenceAge = 'unknown' }
}
Write-Output ""
Write-Output "--- Evidence diagnostics ---"
Write-Output "Evidence freshness: $evidenceFreshness"
Write-Output "Evidence age: $evidenceAge"
Write-Output "Canonical models with researched_current evidence: $evidenceResearchedCurrent"
Write-Output "Canonical models with provider-only evidence: $evidenceProviderOnly"
Write-Output "Registered sources: $evidenceSourcesTotal ($evidenceIndependentSources independent)"
Write-Output "Roster IDs mapped in alias_index: $evidenceAliasCoverage"

# Advisor readiness: prefer the value stored in model-evidence.json (set by research),
# fall back to locally computed thresholds when the file predates that field.
$advisorReadiness = 'UNPOPULATED'
if($evidenceData -and $evidenceData.advisor_readiness){ $advisorReadiness = $evidenceData.advisor_readiness }
elseif($evidenceResearchedCurrent -ge 9 -and $evidenceIndependentSources -ge 3){ $advisorReadiness = 'READY' }
elseif($evidenceResearchedCurrent -ge 2){ $advisorReadiness = 'PARTIAL' }
Write-Output ""
Write-Output "Advisor readiness: $advisorReadiness"
if($advisorReadiness -ne 'READY'){ WARN "Evidence readiness is $advisorReadiness" }

Write-Output ""
Write-Output "OpenAI OAuth: $(if($st.oauth.openai){'detected'}else{'absent'})"
Write-Output "Copilot OAuth: $(if($st.oauth.github_copilot){'detected'}else{'absent'})"
Write-Output "OpenCode free models: $opencodeFreeCount"
Write-Output "Local models: $ollamaLocalCount"
Write-Output ""
# Roster age is availability age only - never evidence freshness.
$rosterFreshness = 'current'
if($roster -and $roster.generated_at){
   try {
      $genDate = [DateTime]$roster.generated_at
      $ageDays = (New-TimeSpan -Start $genDate -End (Get-Date)).Days
      if($ageDays -gt 7){ $rosterFreshness = 'stale' } elseif($ageDays -gt 3){ $rosterFreshness = 'partially stale' }
   } catch {}
}
Write-Output "Availability roster: $rosterFreshness"
if($rosterFreshness -ne 'current'){ WARN "Availability roster is $rosterFreshness (run refresh-routing.cmd)" }

# ---- Enhanced validation ------------------------------------------
# Check subscription model without corresponding OAuth
if($st){
   if($st.deep -match '^openai/' -and -not $st.oauth.openai){ FAIL 'Deep lane selected OpenAI without eligible OpenAI OAuth route.' }
   if($st.review -match '^github-copilot/' -and -not $st.oauth.github_copilot){ FAIL 'Review lane selected GitHub Copilot without eligible Copilot OAuth route.' }
   # Check Deep/Review reference available models
   $allModelIds = @($roster.eligible_models).id
   if($allModelIds -notcontains $st.deep){ FAIL 'Deep lane references model not in eligible roster.' }
   if($allModelIds -notcontains $st.review){ FAIL 'Review lane references model not in eligible roster.' }
   # Check no metered/excluded route in automatic routing
   $forbidden = @('openrouter','vercel','anthropic','google','xai','groq','together','fireworks')
   foreach($f in $forbidden){ if($st.deep -match "^$f" -or $st.review -match "^$f"){ FAIL 'Metered/excluded provider in automatic routing lane.' } }
}
# Check generated files are valid JSON
@($rosterPath,$statePath) | ForEach-Object {
   try { Get-Content -LiteralPath $_ -Raw | ConvertFrom-Json | Out-Null } catch { FAIL "Generated file is malformed JSON: $_" }
}

if($Deep -and $oc){
   Write-Output ''
   Write-Output 'Connected OpenCode providers:'
   $authCall=Invoke-OpenCodeCaptured @('auth','list')
   $authText=''
   if($authCall.ExitCode -eq 0){
      $authCall.Output | ForEach-Object { Write-Output $_.ToString() }
      $authText=($authCall.Output | ForEach-Object { $_.ToString() }) -join "`n"
      $authText=[regex]::Replace($authText, "$([char]27)\[[0-?]*[ -/]*[@-~]", '')
   } else { WARN 'OpenCode provider listing failed.' }
   Write-Output ''
   Write-Output 'Running routing refresh...'
   & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'refresh-routing.ps1')
   if($LASTEXITCODE -eq 0){
      OK 'routing refresh completed.'
      try {
         $fresh=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
         $authHasOpenAI=($authText -match '(?im)^.*OpenAI.*oauth.*$')
         $authHasCopilot=($authText -match '(?im)^.*GitHub\s+Copilot.*oauth.*$')
         if($authHasOpenAI -and -not $fresh.oauth.openai){ FAIL 'OpenAI OAuth is connected but routing did not detect it.' }
         if($authHasCopilot -and -not $fresh.oauth.github_copilot){ FAIL 'GitHub Copilot OAuth is connected but routing did not detect it.' }
         if((-not $fresh.oauth.openai) -and ($fresh.deep -match '^openai/')){ FAIL 'Deep lane selected OpenAI without an eligible OpenAI OAuth route.' }
         if((-not $fresh.oauth.github_copilot) -and ($fresh.review -match '^github-copilot/')){ FAIL 'Review lane selected GitHub Copilot without an eligible Copilot OAuth route.' }
      } catch { FAIL 'post-refresh routing state validation failed.' }
   } else { FAIL 'routing refresh failed.' }
}
Write-Output ''
Write-Output "Doctor summary: $fail failures, $warn warnings."
if($fail -gt 0){exit 1}else{exit 0}
