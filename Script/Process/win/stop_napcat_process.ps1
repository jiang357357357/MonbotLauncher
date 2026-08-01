$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "napcat_common.ps1")

Invoke-NapCatMonPm -Action stop
Write-Host "[NAPCAT_STATUS:STOPPED]"
