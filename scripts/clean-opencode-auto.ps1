$ErrorActionPreference = "Stop"

Write-Host "== OpenCode Auto cleanup =="

$removed = 0
$reported = 0

# 1. Remove the retired global Auto agent, if present.
$globalAuto = Join-Path $HOME ".config\opencode\agents\auto.md"

if (Test-Path -LiteralPath $globalAuto) {
    Remove-Item -LiteralPath $globalAuto -Force
    Write-Host "Removed: $globalAuto"
    $removed++
}

# 2. Search the current location and F:\ for project-level
#    .opencode\agents\auto.md leftovers.
$roots = New-Object System.Collections.Generic.List[string]

$currentRoot = (Get-Location).Path
if (Test-Path -LiteralPath $currentRoot) {
    [void]$roots.Add($currentRoot)
}

if (Test-Path -LiteralPath "F:\") {
    if ($currentRoot -ne "F:\") {
        [void]$roots.Add("F:\")
    }
}

foreach ($root in $roots) {
    Write-Host "Searching for project Auto agents under: $root"

    $files = Get-ChildItem `
        -LiteralPath $root `
        -Recurse `
        -Force `
        -File `
        -Filter "auto.md" `
        -ErrorAction SilentlyContinue

    foreach ($file in $files) {
        $fullName = $file.FullName.Replace("/", "\")

        if ($fullName -match "\\\.opencode\\agents\\auto\.md$") {
            Remove-Item -LiteralPath $file.FullName -Force
            Write-Host "Removed: $($file.FullName)"
            $removed++
        }
    }
}

# 3. Report any remaining OpenCode config references to Auto.
#    These are reported, not automatically rewritten.
$configRoots = New-Object System.Collections.Generic.List[string]

$globalConfigRoot = Join-Path $HOME ".config\opencode"
if (Test-Path -LiteralPath $globalConfigRoot) {
    [void]$configRoots.Add($globalConfigRoot)
}

if (Test-Path -LiteralPath "F:\") {
    [void]$configRoots.Add("F:\")
}

Write-Host ""
Write-Host "== Remaining Auto references =="

foreach ($root in $configRoots) {
    $configFiles = Get-ChildItem `
        -LiteralPath $root `
        -Recurse `
        -Force `
        -File `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match "^opencode.*\.jsonc?$" -or
            $_.Name -eq "AGENTS.md"
        }

    foreach ($configFile in $configFiles) {
        $matches = Select-String `
            -LiteralPath $configFile.FullName `
            -Pattern '"auto"|default_agent|agent:\s*auto|\bAuto\b' `
            -ErrorAction SilentlyContinue

        if ($matches) {
            Write-Host ""
            Write-Host "Review: $($configFile.FullName)"

            foreach ($match in $matches) {
                Write-Host ("  {0}: {1}" -f $match.LineNumber, $match.Line.Trim())
                $reported++
            }
        }
    }
}

Write-Host ""
Write-Host "Removed Auto agent files: $removed"
Write-Host "Remaining references reported: $reported"
Write-Host ""
Write-Host "Now fully quit OpenCode Desktop, reopen it, and start a NEW session."
