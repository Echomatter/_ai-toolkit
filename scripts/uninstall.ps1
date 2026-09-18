<# Removes only toolkit-managed links/copies plus the toolkit block in OpenCode global AGENTS.md. #>
$ErrorActionPreference = 'Stop'
$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $ToolkitRoot '.state\install-manifest.json'
$syncGlobal = Join-Path $PSScriptRoot 'sync-global-instructions.ps1'

function Remove-GlobalToolkitBlock {
    if (Test-Path -LiteralPath $syncGlobal) {
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syncGlobal -Remove
        } catch {
            Write-Warning "Could not remove toolkit block from OpenCode global AGENTS.md: $($_.Exception.Message)"
        }
    }
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Remove-GlobalToolkitBlock
    Write-Output 'No toolkit install manifest was found; global toolkit guidance cleanup was still attempted.'
    exit 0
}

$raw = Get-Content -LiteralPath $ManifestPath -Raw
if (-not $raw.Trim()) {
    Remove-GlobalToolkitBlock
    Write-Output 'No managed links/copies remain.'
    exit 0
}
$entries = @($raw | ConvertFrom-Json)
$failed = New-Object System.Collections.ArrayList

foreach ($entry in $entries) {
    if (-not $entry.target -or -not (Test-Path -LiteralPath $entry.target)) { continue }
    try {
        if ($entry.method -eq 'copy') { Remove-Item -LiteralPath $entry.target -Recurse -Force -Confirm:$false }
        else { Remove-Item -LiteralPath $entry.target -Force -Confirm:$false }
        Write-Output "removed: $($entry.target)"
    } catch {
        [void]$failed.Add($entry)
        Write-Warning "failed to remove $($entry.target): $($_.Exception.Message)"
    }
}

Remove-GlobalToolkitBlock
@($failed) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
Write-Output 'Uninstall complete. OpenCode/provider credentials were not touched.'
