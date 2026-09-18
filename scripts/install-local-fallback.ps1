<# Installs optional Ollama/Qwen fallback. It does not make local the preferred route. #>
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path','Machine')
    $user = [Environment]::GetEnvironmentVariable('Path','User')
    $env:Path = "$machine;$user;$env:LOCALAPPDATA\Programs\Ollama"
}
function Resolve-Exe([string]$Name,[string[]]$Fallbacks) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in $Fallbacks) { if ($p -and (Test-Path -LiteralPath $p)) { return $p } }
    return $null
}
Refresh-Path
$ollama = Resolve-Exe 'ollama' @((Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'))
if (-not $ollama) {
    $winget = Resolve-Exe 'winget' @()
    if (-not $winget) { throw 'winget unavailable. Install Ollama manually, then rerun.' }
    & $winget install --id Ollama.Ollama -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
    $ollama = Resolve-Exe 'ollama' @((Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'))
}
if (-not $ollama) { throw 'Ollama still not found.' }
try { & $ollama list *> $null } catch {}
if ($LASTEXITCODE -ne 0) {
    Start-Process -FilePath $ollama -ArgumentList 'serve' -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 2
}
& $ollama pull 'qwen2.5-coder:7b'
if ($LASTEXITCODE -ne 0) { throw 'ollama pull failed.' }
& $ollama create 'qwen2.5-coder:7b-16k' -f (Join-Path $ToolkitRoot 'ollama\Modelfile.qwen2.5-coder-7b-16k')
if ($LASTEXITCODE -ne 0) { throw 'ollama create failed.' }
$stateDir = Join-Path $ToolkitRoot '.state'
if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
Set-Content -LiteralPath (Join-Path $stateDir 'local-enabled') -Value 'qwen2.5-coder:7b-16k' -Encoding ASCII
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'refresh-routing.ps1')
Write-Output 'Local fallback installed. It remains lower priority than suitable free hosted models unless refresh-routing is run with -PreferLocal.'
