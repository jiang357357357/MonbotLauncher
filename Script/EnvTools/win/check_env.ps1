# MonBot 环境检查脚本 (PowerShell)

param(
    [switch]$NoWait
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = $PSScriptRoot
$ProjectRoot = (Get-Item "$ScriptRoot\..\..\..").FullName
$VenvPython = "$ProjectRoot\.venv\Scripts\python.exe"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          MonBot 环境检查工具                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "项目目录: $ProjectRoot" -ForegroundColor Cyan
Write-Host ""

$CheckPassed = $true
$Warnings = 0

Write-Host "[1/4] 检查项目配置..." -ForegroundColor Magenta
if (Test-Path "$ProjectRoot\pyproject.toml") {
    Write-Host "  ✓ pyproject.toml 存在" -ForegroundColor Green
} else {
    Write-Host "  ✗ 未找到 pyproject.toml" -ForegroundColor Red
    $CheckPassed = $false
}
Write-Host ""

Write-Host "[2/4] 检查虚拟环境..." -ForegroundColor Magenta
if (-not (Test-Path "$ProjectRoot\.venv")) {
    Write-Host "  ✗ 虚拟环境不存在 (.venv)" -ForegroundColor Red
    $CheckPassed = $false
} else {
    Write-Host "  ✓ 虚拟环境存在" -ForegroundColor Green
    if (Test-Path $VenvPython) {
        Write-Host "  ✓ Python: $(& $VenvPython --version)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ 虚拟环境损坏 (未找到 python.exe)" -ForegroundColor Red
        $CheckPassed = $false
    }
}
Write-Host ""

Write-Host "[3/4] 检查关键依赖..." -ForegroundColor Magenta
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
            Write-Host "  ✓ $($package.Name): $result" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($package.Name) 未安装" -ForegroundColor Red
            $CheckPassed = $false
        }
    }
} else {
    Write-Host "  ✗ 无法检查依赖 (虚拟环境不存在)" -ForegroundColor Red
    $CheckPassed = $false
}
Write-Host ""

Write-Host "[4/4] 检查日志目录..." -ForegroundColor Magenta
if (Test-Path "$ProjectRoot\logs") {
    Write-Host "  ✓ logs 目录存在" -ForegroundColor Green
} else {
    Write-Host "  ⚠ logs 目录不存在" -ForegroundColor Yellow
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
