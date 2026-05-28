<#
.SYNOPSIS
    MonBot 完全启动器
    NapCat 在新窗口启动，QQBot 在当前终端运行。
#>

param(
    [switch]$Force = $false,
    [switch]$NoClean = $false
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 移除代理环境变量，避免 httpx/requests 等库因不兼容的代理格式崩溃
Remove-Item Env:HTTP_PROXY, Env:HTTPS_PROXY, Env:ALL_PROXY -ErrorAction SilentlyContinue

$ScriptRoot = $PSScriptRoot
$ProjectRoot = (Get-Item "$ScriptRoot\..\..\..").FullName
$VenvPython = "$ProjectRoot\.venv\Scripts\python.exe"
$PythonExe = if (Test-Path $VenvPython) { $VenvPython } else { "python" }

$NapcatScript = "$ProjectRoot\napcat\launcher.bat"
$BotEntry = "$ProjectRoot\BotCore\bot.py"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "MonBot 完全启动 (NapCat + QQBot)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "项目目录: $ProjectRoot" -ForegroundColor Gray
Write-Host "Python:   $PythonExe" -ForegroundColor Gray
Write-Host ""

$ok = $true
if (-not (Test-Path $PythonExe)) {
    Write-Host "[✗] 虚拟环境不存在，请先运行 uv sync" -ForegroundColor Red
    $ok = $false
}
if (-not (Test-Path $BotEntry)) {
    Write-Host "[✗] QQBot 入口不存在: $BotEntry" -ForegroundColor Red
    $ok = $false
}
if (-not $ok) {
    Read-Host "按 Enter 退出"
    exit 1
}

$hasNapcat = Test-Path $NapcatScript

if ($hasNapcat) {
    Write-Host "[1/2] 🚀 启动 NapCat（新窗口）..." -ForegroundColor Magenta
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle = 'NapCat'; & '$NapcatScript'" -WorkingDirectory "$ProjectRoot\napcat"
    Write-Host "  ✓ NapCat 已在新窗口启动" -ForegroundColor Green
    Write-Host "  等待 5 秒初始化..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
} else {
    Write-Host "[1/2] ⚠ NapCat 未部署，跳过" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[2/2] 🚀 启动 QQBot（当前终端）... 按 Ctrl+C 停止" -ForegroundColor Magenta
Write-Host ""
Set-Location $ProjectRoot
& $PythonExe $BotEntry
exit $LASTEXITCODE
