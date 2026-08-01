<#
.SYNOPSIS
    Full MonBot launcher.
    Starts NapCat in a new window and runs QQBot in the current terminal.
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

$NapcatInfoScript = "$ProjectRoot\Script\Runtime\win\napcat_info.ps1"
$NapcatStartScript = "$ProjectRoot\Script\Process\win\start_napcat_process.ps1"
$BotEntry = "$ProjectRoot\BotCore\bot.py"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Full MonBot startup (NapCat + QQBot)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Project directory: $ProjectRoot" -ForegroundColor Gray
Write-Host "Python:   $PythonExe" -ForegroundColor Gray
Write-Host ""

$ok = $true
if (-not (Test-Path $PythonExe)) {
    Write-Host "[x] Virtual environment not found; run uv sync first" -ForegroundColor Red
    $ok = $false
}
if (-not (Test-Path $BotEntry)) {
    Write-Host "[x] QQBot entry point not found: $BotEntry" -ForegroundColor Red
    $ok = $false
}
if (-not $ok) {
    Read-Host "Press Enter to exit"
    exit 1
}

$hasNapcat = $false
if ((Test-Path $NapcatInfoScript) -and (Test-Path $NapcatStartScript)) {
    try {
        $NapcatJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NapcatInfoScript -NoImage -NoLogin 2>$null
        $NapcatInfo = $NapcatJson | ConvertFrom-Json
        $hasNapcat = $NapcatInfo.launchKind -ne "missing"
    }
    catch {
        Write-Host "[1/2] [!] Failed to inspect NapCat; skipping: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($hasNapcat) {
    Write-Host "[1/2] Starting NapCat through MonPM..." -ForegroundColor Magenta
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NapcatStartScript
    if ($LASTEXITCODE -ne 0) {
        throw "NapCat startup failed with exit code $LASTEXITCODE"
    }
    Write-Host "  [OK] NapCat start command completed" -ForegroundColor Green
    Write-Host "  Waiting 5 seconds for initialization..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
} else {
    Write-Host "[1/2] [!] NapCat is not deployed; skipping" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[2/2] Starting QQBot in the current terminal... Press Ctrl+C to stop" -ForegroundColor Magenta
Write-Host ""
Set-Location $ProjectRoot
& $PythonExe $BotEntry
exit $LASTEXITCODE
