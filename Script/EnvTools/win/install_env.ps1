# MonBot environment installation script (PowerShell)
# Use uv to install Python 3.12.x and all dependencies.

param(
    [switch]$NoWait
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = $PSScriptRoot
$ProjectRoot = (Get-Item "$ScriptRoot\..\..\..").FullName

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "          MonBot environment installer" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project root: $ProjectRoot" -ForegroundColor Cyan
Write-Host "Virtual environment: $ProjectRoot\.venv" -ForegroundColor Cyan
Write-Host ""

Push-Location $ProjectRoot

Write-Host "[0/5] Checking project configuration..." -ForegroundColor Magenta
if (-not (Test-Path "pyproject.toml")) {
    Write-Host "[x] pyproject.toml not found in the current directory" -ForegroundColor Red
    Write-Host "[INSTALL_STATUS:FAILED]" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "[OK] pyproject.toml found" -ForegroundColor Green
Write-Host ""

Write-Host "[1/5] Checking the uv package manager..." -ForegroundColor Magenta
$uvCmd = Get-Command "uv" -ErrorAction SilentlyContinue
if (-not $uvCmd) {
    Write-Host "[x] uv is not installed; installing it automatically..." -ForegroundColor Yellow
    pip install uv
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[x] uv installation failed" -ForegroundColor Red
        Write-Host "[INSTALL_STATUS:FAILED]" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "[OK] uv installed successfully" -ForegroundColor Green
} else {
    Write-Host "[OK] uv is installed: $(& uv --version)" -ForegroundColor Green
}
Write-Host ""

Write-Host "[2/5] Installing Python 3.12.x..." -ForegroundColor Magenta
& uv python install 3.12.6
if ($LASTEXITCODE -ne 0) {
    Write-Host "[x] Python installation failed" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "[OK] Python 3.12.6 installed successfully" -ForegroundColor Green

& uv python pin 3.12.6
if ($LASTEXITCODE -ne 0) {
    Write-Host "[x] Failed to pin the Python version" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "[OK] Python version pinned to 3.12.6" -ForegroundColor Green
Write-Host ""

Write-Host "[3/5] Creating the virtual environment and installing dependencies..." -ForegroundColor Magenta
if (Test-Path ".venv") {
    Remove-Item -Recurse -Force ".venv"
    Write-Host "[OK] Previous virtual environment removed" -ForegroundColor Green
}

& uv sync
if ($LASTEXITCODE -ne 0) {
    Write-Host "[x] Dependency synchronization failed" -ForegroundColor Red
    Write-Host "[INSTALL_STATUS:FAILED]" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "[OK] Virtual environment created successfully" -ForegroundColor Green
Write-Host "[OK] All dependencies installed" -ForegroundColor Green
Write-Host ""

$VenvPython = ".venv\Scripts\python.exe"
Write-Host "[4/5] Verifying the installation..." -ForegroundColor Magenta
if (-not (Test-Path $VenvPython)) {
    Write-Host "[x] Virtual environment Python not found: $VenvPython" -ForegroundColor Red
    Write-Host "[INSTALL_STATUS:FAILED]" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "[OK] Python version: $(& $VenvPython --version)" -ForegroundColor Green

$packages = @(
    @{ Name = "nonebot2"; Code = "from importlib.metadata import version; print(version('nonebot2'))" },
    @{ Name = "websockets"; Code = "import websockets; print(websockets.__version__)" },
    @{ Name = "aiohttp"; Code = "import aiohttp; print(aiohttp.__version__)" }
)
foreach ($package in $packages) {
    $result = & $VenvPython -c $package.Code 2>$null
    if ($LASTEXITCODE -eq 0 -and $result) {
        Write-Host "  [OK] $($package.Name): $result" -ForegroundColor Green
    } else {
        Write-Host "  [x] $($package.Name)" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "[5/5] Creating required directories..." -ForegroundColor Magenta
New-Item -ItemType Directory -Path "logs" -Force | Out-Null
Write-Host "[OK] Log directory ready: logs" -ForegroundColor Green
Write-Host ""

Write-Host "[INSTALL_STATUS:SUCCESS]" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  Start service: .\Script\Cmd\win\Start.ps1" -ForegroundColor Yellow
Write-Host "  Check environment: .\Script\EnvTools\win\check_env.ps1" -ForegroundColor Yellow

Pop-Location
