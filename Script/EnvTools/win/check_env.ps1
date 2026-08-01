# MonBot environment check script (PowerShell)

param(
    [switch]$NoWait
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = $PSScriptRoot
$ProjectRoot = (Get-Item "$ScriptRoot\..\..\..").FullName
$VenvPython = "$ProjectRoot\.venv\Scripts\python.exe"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "          MonBot environment checker" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project directory: $ProjectRoot" -ForegroundColor Cyan
Write-Host ""

$CheckPassed = $true
$Warnings = 0

Write-Host "[1/4] Checking project configuration..." -ForegroundColor Magenta
if (Test-Path "$ProjectRoot\pyproject.toml") {
    Write-Host "  [OK] pyproject.toml exists" -ForegroundColor Green
} else {
    Write-Host "  [x] pyproject.toml not found" -ForegroundColor Red
    $CheckPassed = $false
}
Write-Host ""

Write-Host "[2/4] Checking the virtual environment..." -ForegroundColor Magenta
if (-not (Test-Path "$ProjectRoot\.venv")) {
    Write-Host "  [x] Virtual environment does not exist (.venv)" -ForegroundColor Red
    $CheckPassed = $false
} else {
    Write-Host "  [OK] Virtual environment exists" -ForegroundColor Green
    if (Test-Path $VenvPython) {
        Write-Host "  [OK] Python: $(& $VenvPython --version)" -ForegroundColor Green
    } else {
        Write-Host "  [x] Virtual environment is invalid (python.exe not found)" -ForegroundColor Red
        $CheckPassed = $false
    }
}
Write-Host ""

Write-Host "[3/4] Checking critical dependencies..." -ForegroundColor Magenta
if (Test-Path $VenvPython) {
    $packages = @(
        @{ Name = "nonebot2"; Code = "from importlib.metadata import version; print(version('nonebot2'))" },
        @{ Name = "websockets"; Code = "import websockets; print(websockets.__version__)" },
        @{ Name = "aiohttp"; Code = "import aiohttp; print(aiohttp.__version__)" },
        @{ Name = "psutil"; Code = "import psutil; print(psutil.__version__)" }
    )
    foreach ($package in $packages) {
        $result = & $VenvPython -c $package.Code 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-Host "  [OK] $($package.Name): $result" -ForegroundColor Green
        } else {
            Write-Host "  [x] $($package.Name) is not installed" -ForegroundColor Red
            $CheckPassed = $false
        }
    }
} else {
    Write-Host "  [x] Cannot check dependencies (virtual environment missing)" -ForegroundColor Red
    $CheckPassed = $false
}
Write-Host ""

Write-Host "[4/4] Checking the log directory..." -ForegroundColor Magenta
if (Test-Path "$ProjectRoot\logs") {
    Write-Host "  [OK] logs directory exists" -ForegroundColor Green
} else {
    Write-Host "  [!] logs directory does not exist" -ForegroundColor Yellow
    $Warnings++
}
Write-Host ""

if ($CheckPassed) {
    if ($Warnings -gt 0) {
        Write-Host "[ENV_STATUS:PARTIAL]" -ForegroundColor Yellow
    } else {
        Write-Host "[ENV_STATUS:INSTALLED]" -ForegroundColor Green
    }
} else {
    Write-Host "[ENV_STATUS:NOT_INSTALLED]" -ForegroundColor Red
    exit 1
}
