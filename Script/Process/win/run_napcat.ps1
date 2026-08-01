$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "napcat_common.ps1")

$LaunchEntry = Get-NapCatLaunchEntry
if (-not $LaunchEntry) {
    Write-Host "[NAPCAT_STATUS:NOT_INSTALLED]"
    throw "No installed NapCat Windows shell was found under $NapCatHome"
}
$ShellRoot = Split-Path -Parent $LaunchEntry
$QuickLoginAccount = Get-NapCatQuickLoginAccount

Write-Host "================================================"
Write-Host "NapCat MonPM foreground runner (Windows)"
Write-Host "================================================"
Write-Host "Runtime directory: $ShellRoot"
Write-Host "Launch entry: $LaunchEntry"
if ($QuickLoginAccount) { Write-Host "Quick login account: $QuickLoginAccount" }
Write-Host "[NAPCAT_STATUS:STARTING]"

Push-Location $ShellRoot
try {
    if ($QuickLoginAccount) {
        & $LaunchEntry $QuickLoginAccount
    }
    else {
        & $LaunchEntry
    }
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
