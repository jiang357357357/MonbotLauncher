$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "napcat_common.ps1")

if (-not (Get-NapCatLaunchEntry)) {
    Write-Host "[NAPCAT_STATUS:NOT_INSTALLED]"
    throw "No installed NapCat Windows shell was found under $NapCatHome"
}
Invoke-NapCatMonPm -Action restart
Write-Host "[NAPCAT_STATUS:RESTARTED]"
