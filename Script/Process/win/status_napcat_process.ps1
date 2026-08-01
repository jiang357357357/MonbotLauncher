$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "napcat_common.ps1")

if (-not (Get-NapCatLaunchEntry)) {
    Write-Host "[NAPCAT_STATUS:NOT_INSTALLED]"
    exit 0
}
$Status = Get-NapCatMonPmStatus
Write-Host "MonPM state: $Status"
if ($Status -eq "running") {
    Write-Host "[NAPCAT_STATUS:RUNNING]"
}
else {
    Write-Host "[NAPCAT_STATUS:NOT_RUNNING]"
}
