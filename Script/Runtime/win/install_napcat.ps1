param(
    [switch]$DownloadOnly,
    [switch]$RunInstaller,
    [switch]$AcceptNapCatLicense,
    [string[]]$InstallerArgs = @()
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../../..")
$NapCatHome = if ($env:MON_NAPCAT_HOME) { $env:MON_NAPCAT_HOME } else { Join-Path $ProjectRoot "napcat" }
$InstallerRoot = if ($env:MON_NAPCAT_INSTALLER_ROOT) { $env:MON_NAPCAT_INSTALLER_ROOT } else { Join-Path $NapCatHome ".installer" }
$InstallerUrl = if ($env:MON_NAPCAT_INSTALLER_URL) { $env:MON_NAPCAT_INSTALLER_URL } else { "https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.ps1" }
$InstallerFile = Join-Path $InstallerRoot "install.ps1"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "NapCat 外置运行时安装器 (Windows)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "项目目录: $ProjectRoot"
Write-Host "部署目录: $NapCatHome"
Write-Host "安装器目录: $InstallerRoot"
Write-Host "官方安装器: $InstallerUrl"
Write-Host ""
Write-Host "[!] NapCatQQ 本体不应进入 Mon 的 GitCode 源码或客户端分发仓库。" -ForegroundColor Yellow
Write-Host "[!] 如需商业或客户分发，请先取得 NapCatQQ 主作者明确授权。" -ForegroundColor Yellow
Write-Host ""

New-Item -ItemType Directory -Force -Path $NapCatHome | Out-Null
New-Item -ItemType Directory -Force -Path $InstallerRoot | Out-Null
Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerFile -UseBasicParsing

Write-Host ""
Write-Host "[OK] 官方安装器已下载: $InstallerFile" -ForegroundColor Green

if (-not $RunInstaller -or $DownloadOnly) {
    Write-Host ""
    Write-Host "[NAPCAT_STATUS:INSTALLER_DOWNLOADED]"
    Write-Host "执行安装:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File Script/Runtime/win/install_napcat.ps1 -RunInstaller -AcceptNapCatLicense"
    exit 0
}

if (-not $AcceptNapCatLicense) {
    Write-Host ""
    Write-Host "[x] 执行安装器前需要显式确认 NapCatQQ 许可证" -ForegroundColor Red
    Write-Host "    参数: -AcceptNapCatLicense"
    Write-Host ""
    Write-Host "[NAPCAT_STATUS:LICENSE_NOT_ACCEPTED]"
    exit 2
}

Write-Host ""
Write-Host "[*] 开始执行官方 NapCat 安装器..." -ForegroundColor Cyan
Push-Location $NapCatHome
try {
    & powershell -ExecutionPolicy Bypass -File $InstallerFile @InstallerArgs
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "[NAPCAT_STATUS:INSTALLER_FINISHED]"
