<#
.SYNOPSIS
    Standalone QQBot launcher.
    Runs QQBot in the current terminal when NapCat is already running separately.
#>

param(
    [switch]$Force = $false,
    [switch]$NoClean = $false
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = $PSScriptRoot
$ProjectRoot = (Get-Item "$ScriptRoot\..\..\..").FullName
$VenvPython = "$ProjectRoot\.venv\Scripts\python.exe"
$PythonExe = if (Test-Path $VenvPython) { $VenvPython } else { "python" }
$BotEntry = "$ProjectRoot\BotCore\bot.py"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "QQBot startup (current terminal)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Project directory: $ProjectRoot" -ForegroundColor Gray
Write-Host "Python:   $PythonExe" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $PythonExe)) {
    Write-Host "[x] Virtual environment not found; run uv sync first" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
if (-not (Test-Path $BotEntry)) {
    Write-Host "[x] QQBot entry point not found: $BotEntry" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Starting QQBot... Press Ctrl+C to stop" -ForegroundColor Magenta
Write-Host ""
& $PythonExe $BotEntry
exit $LASTEXITCODE
