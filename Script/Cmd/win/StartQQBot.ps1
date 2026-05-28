<#
.SYNOPSIS
    QQBot 独立启动器
    在当前终端运行 QQBot，适用于 NapCat 已单独运行的情况。
#>

param(
    [switch]$Force = $false,
    [switch]$NoClean = $false
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 清理代理环境变量，避免 httpx/requests 等库因不兼容的代理格式崩溃
$env:HTTP_PROXY = ""
$env:HTTPS_PROXY = ""
$env:ALL_PROXY = ""

$ScriptRoot = $PSScriptRoot
$ProjectRoot = (Get-Item "$ScriptRoot\..\..\..").FullName
$VenvPython = "$ProjectRoot\.venv\Scripts\python.exe"
$PythonExe = if (Test-Path $VenvPython) { $VenvPython } else { "python" }
$BotEntry = "$ProjectRoot\BotCore\bot.py"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "QQBot 启动 (当前终端)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "项目目录: $ProjectRoot" -ForegroundColor Gray
Write-Host "Python:   $PythonExe" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $PythonExe)) {
    Write-Host "[✗] 虚拟环境不存在，请先运行 uv sync" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}
if (-not (Test-Path $BotEntry)) {
    Write-Host "[✗] QQBot 入口不存在: $BotEntry" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

Write-Host "🚀 启动 QQBot... 按 Ctrl+C 停止" -ForegroundColor Magenta
Write-Host ""
& $PythonExe $BotEntry
exit $LASTEXITCODE
