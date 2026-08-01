$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfoScript = Join-Path $ScriptDir "napcat_info.ps1"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "NapCat external runtime check (Windows)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$Json = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InfoScript -NoImage -NoLogin
if ($LASTEXITCODE -ne 0) {
    throw "NapCat information check failed with exit code $LASTEXITCODE."
}
$Info = $Json | ConvertFrom-Json

if ($Info.launchKind -eq "missing" -or $Info.status -eq "notInstalled") {
    Write-Host "[!] NapCat runtime is not installed" -ForegroundColor Yellow
    Write-Host "    Deployment directory: $($Info.runtimeRoot)"
    Write-Host ""
    Write-Host "[NAPCAT_STATUS:NOT_INSTALLED]"
    Write-Host "[NAPCAT_HOME:$($Info.runtimeRoot)]"
    exit 0
}

Write-Host "[OK] NapCat runtime: $($Info.installBaseDir)" -ForegroundColor Green
Write-Host "[OK] Launch kind: $($Info.launchKind)" -ForegroundColor Green
Write-Host "[OK] WebUI config: $($Info.webui.configPath)" -ForegroundColor Green
Write-Host ""
Write-Host "[NAPCAT_STATUS:INSTALLED]"
Write-Host "[NAPCAT_HOME:$($Info.runtimeRoot)]"
