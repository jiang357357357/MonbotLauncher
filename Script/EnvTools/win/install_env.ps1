# MonBot 环境安装脚本 (PowerShell)
# 使用 UV 自动安装 Python 3.12.x 和所有依赖

param(
    [switch]$NoWait
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = $PSScriptRoot
$ProjectRoot = (Get-Item "$ScriptRoot\..\..\..").FullName

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          MonBot 环境安装工具                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "项目根目录: $ProjectRoot" -ForegroundColor Cyan
Write-Host "虚拟环境: $ProjectRoot\.venv" -ForegroundColor Cyan
Write-Host ""

Push-Location $ProjectRoot

Write-Host "[0/5] 检查项目配置..." -ForegroundColor Magenta
if (-not (Test-Path "pyproject.toml")) {
    Write-Host "✗ 未在当前目录找到 pyproject.toml" -ForegroundColor Red
    Write-Host "[INSTALL_STATUS:FAILED]" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✓ 找到 pyproject.toml" -ForegroundColor Green
Write-Host ""

Write-Host "[1/5] 检查 UV 包管理器..." -ForegroundColor Magenta
$uvCmd = Get-Command "uv" -ErrorAction SilentlyContinue
if (-not $uvCmd) {
    Write-Host "✗ UV 未安装，正在自动安装..." -ForegroundColor Yellow
    pip install uv
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ UV 安装失败" -ForegroundColor Red
        Write-Host "[INSTALL_STATUS:FAILED]" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "✓ UV 安装成功" -ForegroundColor Green
} else {
    Write-Host "✓ UV 已安装: $(& uv --version)" -ForegroundColor Green
}
Write-Host ""

Write-Host "[2/5] 安装 Python 3.12.x..." -ForegroundColor Magenta
& uv python install 3.12.6
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Python 安装失败" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✓ Python 3.12.6 安装成功" -ForegroundColor Green

& uv python pin 3.12.6
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Python 版本固定失败" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✓ Python 版本已固定为 3.12.6" -ForegroundColor Green
Write-Host ""

Write-Host "[3/5] 创建虚拟环境并安装依赖..." -ForegroundColor Magenta
if (Test-Path ".venv") {
    Remove-Item -Recurse -Force ".venv"
    Write-Host "✓ 旧虚拟环境已删除" -ForegroundColor Green
}

& uv sync
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ 依赖同步失败" -ForegroundColor Red
    Write-Host "[INSTALL_STATUS:FAILED]" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✓ 虚拟环境创建成功" -ForegroundColor Green
Write-Host "✓ 所有依赖已安装" -ForegroundColor Green
Write-Host ""

$VenvPython = ".venv\Scripts\python.exe"
Write-Host "[4/5] 验证安装..." -ForegroundColor Magenta
if (-not (Test-Path $VenvPython)) {
    Write-Host "✗ 虚拟环境 Python 不存在: $VenvPython" -ForegroundColor Red
    Write-Host "[INSTALL_STATUS:FAILED]" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✓ Python 版本: $(& $VenvPython --version)" -ForegroundColor Green

$packages = @(
    @{ Name = "nonebot2"; Code = "from importlib.metadata import version; print(version('nonebot2'))" },
    @{ Name = "websockets"; Code = "import websockets; print(websockets.__version__)" },
    @{ Name = "aiohttp"; Code = "import aiohttp; print(aiohttp.__version__)" }
)
foreach ($package in $packages) {
    $result = & $VenvPython -c $package.Code 2>$null
    if ($LASTEXITCODE -eq 0 -and $result) {
        Write-Host "  ✓ $($package.Name): $result" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($package.Name)" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "[5/5] 创建必要的目录..." -ForegroundColor Magenta
New-Item -ItemType Directory -Path "logs" -Force | Out-Null
Write-Host "✓ 日志目录已就绪: logs" -ForegroundColor Green
Write-Host ""

Write-Host "[INSTALL_STATUS:SUCCESS]" -ForegroundColor Green
Write-Host "下一步操作:" -ForegroundColor Cyan
Write-Host "  启动服务: .\Script\Cmd\win\Start.ps1" -ForegroundColor Yellow
Write-Host "  检查环境: .\Script\EnvTools\win\check_env.ps1" -ForegroundColor Yellow

Pop-Location
