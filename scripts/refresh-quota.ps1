<# Quota telemetry refresh (read-only on routing data; writes .state/quota-state.json only).
Reads live usage from provider endpoints using the user's existing OpenCode credentials.
Never logs or echoes credential material. Exit code is 0 even when telemetry is
unavailable; per-surface telemetry health is recorded instead.
Telemetry health is kept separate from execution availability: a failed telemetry
request never blocks a model route. Execution blocks are recorded only via
-BlockSurface on confirmed execution-side failure, and a telemetry refresh never
clears one merely because local statistics look inexpensive.
Windows PowerShell 5.1 compatible.
#>
param(
    [string]$ToolkitRoot = '',
    [string]$BlockSurface = '',
    [string]$BlockReason = '',
    [string]$BlockResetAt = '',
    [int]$BlockRecheckMinutes = 15
)
$ErrorActionPreference = 'Stop'
if ($ToolkitRoot -eq '') { $ToolkitRoot = Split-Path -Parent $PSScriptRoot }
$StatePath = Join-Path $ToolkitRoot '.state\quota-state.json'

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}
function Now-UtcIso() { return (Get-Date).ToUniversalTime().ToString('o') }
function Redact([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return '' }
    if ($s.Length -le 8) { return '***' }
    return $s.Substring(0, 4) + '***'
}

# Load prior state so execution blocks and cached telemetry survive refreshes.
$prior = $null
try {
    if (Test-Path -LiteralPath $StatePath) {
        $prior = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
} catch { $prior = $null }
function Get-PriorSurface([string]$name) {
    if ($prior -and $prior.surfaces) {
        foreach ($p in @($prior.surfaces.PSObject.Properties)) {
            if ($p.Name -eq $name) { return $p.Value }
        }
    }
    return $null
}
function Get-PriorExecution([string]$name) {
    $s = Get-PriorSurface $name
    if ($s -and $s.execution) { return $s.execution }
    return $null
}

$authPath = Join-Path $env:USERPROFILE '.local\share\opencode\auth.json'
$auth = $null
try {
    if (Test-Path -LiteralPath $authPath) {
        $auth = Get-Content -LiteralPath $authPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
} catch { $auth = $null }

function Invoke-QuotaGet([string]$Url, [hashtable]$Headers, [int]$TimeoutSec = 15) {
    # Returns @{ok; status; body}. Never includes credential material in outputs.
    try {
        $resp = Invoke-WebRequest -Uri $Url -Headers $Headers -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return @{ ok = $true; status = [int]$resp.StatusCode; body = [string]$resp.Content }
    } catch {
        $code = 0
        $body = ''
        try {
            if ($_.Exception.Response) {
                $code = [int]$_.Exception.Response.StatusCode.value__
                $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $body = $sr.ReadToEnd()
                $sr.Close()
            }
        } catch {}
        return @{ ok = $false; status = $code; body = $body }
    }
}

$now = Now-UtcIso
$surfaces = [ordered]@{}

# ---- OpenCode Go: live account windows ----
$goTelemetry = [ordered]@{ status = 'unavailable'; source = 'go-usage-api'; as_of = $now; note = '' }
$goWindows = $null
$goKeyPresent = ($auth -and $auth.'opencode-go' -and $auth.'opencode-go'.key)
if ($goKeyPresent) {
    $goHeaders = @{ Authorization = ("Bearer " + [string]$auth.'opencode-go'.key); 'User-Agent' = 'ai-toolkit-refresh-quota' }
    $r = Invoke-QuotaGet 'https://opencode.ai/zen/go/v1/usage' $goHeaders
    if ($r.ok) {
        try {
            $u = ($r.body | ConvertFrom-Json).usage
            $goWindows = [ordered]@{}
            foreach ($w in @('rolling', 'weekly', 'monthly')) {
                $wu = $u.$w
                if ($wu) {
                    $goWindows[$w] = [ordered]@{
                        status = [string]$wu.status
                        used_percent = [double]$wu.percent
                        resets_at = [string]$wu.resetsAt
                    }
                }
            }
            $goTelemetry.status = 'ok'
        } catch { $goTelemetry.status = 'unparseable'; $goTelemetry.note = 'response did not match expected shape' }
    } elseif ($r.status -eq 401) {
        $goTelemetry.status = 'auth-failed'
        $goTelemetry.note = 'usage endpoint rejected the stored key (telemetry only; execution availability unchanged)'
    } elseif ($r.status -eq 403) {
        $goTelemetry.status = 'no-plan'
        $goTelemetry.note = 'server reports no active Go plan for this key (authoritative for telemetry)'
    } else {
        $goTelemetry.status = 'unreachable'
        $goTelemetry.note = ("http status " + $r.status)
    }
} else {
    $goTelemetry.status = 'no-credential'
    $goTelemetry.note = 'no opencode-go key in auth.json'
}
$goExec = Get-PriorExecution 'opencode-go'
$surfaces['opencode-go'] = [ordered]@{
    quota_type = 'subscription'
    telemetry = $goTelemetry
    windows = $goWindows
    execution = $goExec
}

# ---- GitHub Copilot: live quota snapshots ----
$cpTelemetry = [ordered]@{ status = 'unavailable'; source = 'github-copilot-internal-api'; as_of = $now; note = '' }
$cpBuckets = $null
$cpReset = ''
$cpTokenPresent = ($auth -and $auth.'github-copilot' -and $auth.'github-copilot'.access)
if ($cpTokenPresent) {
    $cpHeaders = @{ Authorization = ("token " + [string]$auth.'github-copilot'.access); 'User-Agent' = 'ai-toolkit-refresh-quota' }
    $r = Invoke-QuotaGet 'https://api.github.com/copilot_internal/user' $cpHeaders
    if ($r.ok) {
        try {
            $cu = ($r.body | ConvertFrom-Json)
            $cpReset = [string]$cu.quota_reset_date_utc
            $cpBuckets = [ordered]@{}
            foreach ($b in @($cu.quota_snapshots.PSObject.Properties)) {
                $v = $b.Value
                $cpBuckets[$b.Name] = [ordered]@{
                    unlimited = [bool]$v.unlimited
                    percent_remaining = [double]$v.percent_remaining
                    quota_remaining = $v.quota_remaining
                    credits_used = $v.credits_used
                    entitlement = $v.entitlement
                    overage_permitted = [bool]$v.overage_permitted
                }
            }
            $cpTelemetry.status = 'ok'
        } catch { $cpTelemetry.status = 'unparseable'; $cpTelemetry.note = 'response did not match expected shape' }
    } elseif ($r.status -eq 401 -or $r.status -eq 403) {
        $cpTelemetry.status = 'auth-failed'
        $cpTelemetry.note = 'token rejected for quota lookup (telemetry only; execution availability unchanged)'
    } else {
        $cpTelemetry.status = 'unreachable'
        $cpTelemetry.note = ("http status " + $r.status)
    }
} else {
    $cpTelemetry.status = 'no-credential'
    $cpTelemetry.note = 'no github-copilot token in auth.json'
}
$cpExec = Get-PriorExecution 'github-copilot-oauth'
$surfaces['github-copilot-oauth'] = [ordered]@{
    quota_type = 'subscription'
    telemetry = $cpTelemetry
    buckets = $cpBuckets
    reset_at = $cpReset
    execution = $cpExec
}

# ---- ChatGPT: attempt first-party usage surface ----
$aiTelemetry = [ordered]@{ status = 'unavailable'; source = 'chatgpt-wham-usage'; as_of = $now; note = '' }
$aiWindows = $null
$aiTokenPresent = ($auth -and $auth.openai -and $auth.openai.access)
if ($aiTokenPresent) {
    $aiHeaders = @{
        Authorization = ("Bearer " + [string]$auth.openai.access)
        'ChatGPT-Account-Id' = [string]$auth.openai.accountId
        Accept = 'application/json'
        Origin = 'https://chatgpt.com'
        Referer = 'https://chatgpt.com/'
        'User-Agent' = 'Mozilla/5.0'
    }
    $r = Invoke-QuotaGet 'https://chatgpt.com/backend-api/wham/usage' $aiHeaders
    if ($r.ok) {
        try {
            $wu = ($r.body | ConvertFrom-Json)
            $aiWindows = [ordered]@{ plan_type = [string]$wu.plan_type }
            if ($wu.rate_limit -and $wu.rate_limit.primary_window) {
                $pw = $wu.rate_limit.primary_window
                $aiWindows['primary'] = [ordered]@{
                    used_percent = [double]$pw.used_percent
                    window_seconds = [int]$pw.limit_window_seconds
                    reset_at_unix = [long]$pw.reset_at
                }
            }
            if ($wu.rate_limit -and $wu.rate_limit.secondary_window) {
                $sw = $wu.rate_limit.secondary_window
                $aiWindows['secondary'] = [ordered]@{
                    used_percent = [double]$sw.used_percent
                    window_seconds = [int]$sw.limit_window_seconds
                    reset_at_unix = [long]$sw.reset_at
                }
            }
            $aiTelemetry.status = 'ok'
        } catch { $aiTelemetry.status = 'unparseable'; $aiTelemetry.note = 'response did not match expected shape' }
    } elseif ($r.status -eq 401 -or $r.status -eq 403) {
        $aiTelemetry.status = 'auth-failed'
        $aiTelemetry.note = 'stored ChatGPT token rejected by the first-party usage surface in this installation (telemetry only; execution availability unchanged)'
    } else {
        $aiTelemetry.status = 'unreachable'
        $aiTelemetry.note = ("http status " + $r.status)
    }
} else {
    $aiTelemetry.status = 'no-credential'
    $aiTelemetry.note = 'no openai token in auth.json'
}
$aiExec = Get-PriorExecution 'openai-oauth'
$surfaces['openai-oauth'] = [ordered]@{
    quota_type = 'subscription'
    telemetry = $aiTelemetry
    windows = $aiWindows
    execution = $aiExec
}

# ---- opencode-free: no quota surface; telemetry is intentionally absent ----
$freeExec = Get-PriorExecution 'opencode-free'
$surfaces['opencode-free'] = [ordered]@{
    quota_type = 'free-hosted'
    telemetry = [ordered]@{ status = 'not-applicable'; source = 'none'; as_of = $now; note = 'free tier exposes no quota surface; availability is not assumed' }
    execution = $freeExec
}

# ---- Execution block recording (confirmed execution-side failures only) ----
if ($BlockSurface -ne '') {
    $validSurfaces = @('opencode-go', 'openai-oauth', 'github-copilot-oauth', 'opencode-free')
    if ($validSurfaces -notcontains $BlockSurface) { throw "Unknown surface for execution block: $BlockSurface" }
    $priorCount = 0
    $pe = Get-PriorExecution $BlockSurface
    if ($pe -and $pe.recheck_count) { try { $priorCount = [int]$pe.recheck_count } catch { $priorCount = 0 } }
    # Bounded rechecking: cap consecutive unknown-reset blocks at 3, then back off.
    $recheckAt = ''
    try {
        $recheckAt = (Get-Date).ToUniversalTime().AddMinutes([double]$BlockRecheckMinutes).ToString('o')
    } catch {}
    $surfaces[$BlockSurface].execution = [ordered]@{
        blocked = $true
        reason = $BlockReason
        reset_at = $BlockResetAt
        recheck_at = $recheckAt
        recheck_count = ($priorCount + 1)
        recorded_at = $now
    }
    Write-Output ("Recorded execution block: $BlockSurface reason=$BlockReason recheck_at=$recheckAt")
}

# A refresh never clears an execution block merely because telemetry looks cheap.
# Blocks clear only when their reset time has passed (handled by the selector as
# unknown-reset recheck) or when a same-bucket live check shows headroom. That
# same-bucket clearing is evaluated in select-model.ps1, not here.

$state = [ordered]@{
    generated = $true
    generated_at = $now
    surfaces = $surfaces
}
Write-Utf8NoBom $StatePath ($state | ConvertTo-Json -Depth 8)
Write-Output "Wrote quota state:"
Write-Output ("  path: $StatePath")
foreach ($sn in @($surfaces.Keys)) {
    $t = $surfaces[$sn].telemetry
    Write-Output ("  surface=$sn telemetry=" + $t.status)
}
