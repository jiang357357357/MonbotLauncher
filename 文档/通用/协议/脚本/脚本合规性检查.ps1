# Mon 项目脚本合规性检查工具
# 检查所有脚本是否符合规范协议

param(
    [switch]$Verbose,
    [switch]$FixIssues
)

# 设置UTF-8编码
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 项目根目录
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          Mon 项目脚本合规性检查工具                    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "项目根目录: $ProjectRoot" -ForegroundColor Cyan
Write-Host ""

# 定义要检查的脚本列表
$ScriptsToCheck = @(
    # MonCore 脚本
    @{Path = "Backend\Server\Script\EnvTools\win\check_env.ps1"; Type = "ENV_CHECK"; Module = "MonCore"},
    @{Path = "Backend\Server\Script\EnvTools\win\install_env.ps1"; Type = "ENV_INSTALL"; Module = "MonCore"},
    @{Path = "Backend\Server\Script\EnvTools\win\remove_env.ps1"; Type = "ENV_REMOVE"; Module = "MonCore"},
    @{Path = "Backend\Server\scripts\Start\start_moncore.ps1"; Type = "SERVER_START"; Module = "MonCore"},
    @{Path = "Backend\Server\scripts\DB\migrate_db.py"; Type = "DB_MIGRATE"; Module = "MonCore"},
    @{Path = "Backend\Server\scripts\DB\init_admin.py"; Type = "DB_INIT"; Module = "MonCore"},
    
    # MonHub 脚本
    @{Path = "Backend\Hub\Script\EnvTools\win\check_env.ps1"; Type = "ENV_CHECK"; Module = "MonHub"},
    @{Path = "Backend\Hub\Script\EnvTools\win\install_env.ps1"; Type = "ENV_INSTALL"; Module = "MonHub"},
    @{Path = "Backend\Hub\Script\EnvTools\win\remove_env.ps1"; Type = "ENV_REMOVE"; Module = "MonHub"},
    @{Path = "Backend\Hub\Script\main\start_monhub.ps1"; Type = "SERVER_START"; Module = "MonHub"},
    
    # MonOs 脚本
    @{Path = "Backend\BaseOs\Script\EnvTools\win\check_env.ps1"; Type = "ENV_CHECK"; Module = "MonOs"},
    @{Path = "Backend\BaseOs\Script\EnvTools\win\install_env.ps1"; Type = "ENV_INSTALL"; Module = "MonOs"},
    @{Path = "Backend\BaseOs\Script\EnvTools\win\remove_env.ps1"; Type = "ENV_REMOVE"; Module = "MonOs"},
    @{Path = "Backend\BaseOs\Script\main\start_monos.ps1"; Type = "SERVER_START"; Module = "MonOs"},
    
    # 通用脚本
    @{Path = "scripts\7zip\pack.ps1"; Type = "PACK"; Module = "Common"}
)

# 定义期望的状态标识符
$ExpectedStatusIdentifiers = @{
    "ENV_CHECK" = @("ENV_STATUS:INSTALLED", "ENV_STATUS:PARTIAL", "ENV_STATUS:NOT_INSTALLED")
    "ENV_INSTALL" = @("INSTALL_STATUS:SUCCESS", "INSTALL_STATUS:FAILED")
    "ENV_REMOVE" = @("REMOVE_STATUS:SUCCESS", "REMOVE_STATUS:PARTIAL", "REMOVE_STATUS:FAILED", "REMOVE_STATUS:NOTHING")
    "SERVER_START" = @("SERVER_STATUS:STOPPED", "SERVER_STATUS:FAILED")
    "DB_MIGRATE" = @("DB_STATUS:MIGRATED", "DB_STATUS:FAILED")
    "DB_INIT" = @("ADMIN_STATUS:CREATED", "ADMIN_STATUS:EXISTS", "ADMIN_STATUS:FAILED")
    "PACK" = @("PACK_STATUS:SUCCESS", "PACK_STATUS:FAILED", "PACK_STATUS:NO_FILES")
}

# 检查结果统计
$TotalScripts = 0
$PassedScripts = 0
$FailedScripts = 0
$Issues = @()

Write-Host "[1/3] 检查脚本文件存在性..." -ForegroundColor Magenta
Write-Host ""

foreach ($script in $ScriptsToCheck) {
    $TotalScripts++
    $fullPath = Join-Path $ProjectRoot $script.Path
    $scriptName = "$($script.Module)/$($script.Type)"
    
    if (-not (Test-Path $fullPath)) {
        Write-Host "  ✗ $scriptName - 文件不存在" -ForegroundColor Red
        $Issues += "文件不存在: $($script.Path)"
        $FailedScripts++
        continue
    }
    
    Write-Host "  ✓ $scriptName - 文件存在" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/3] 检查状态标识符合规性..." -ForegroundColor Magenta
Write-Host ""

foreach ($script in $ScriptsToCheck) {
    $fullPath = Join-Path $ProjectRoot $script.Path
    $scriptName = "$($script.Module)/$($script.Type)"
    
    if (-not (Test-Path $fullPath)) { continue }
    
    $content = Get-Content $fullPath -Raw -Encoding UTF8
    $expectedIdentifiers = $ExpectedStatusIdentifiers[$script.Type]
    
    if (-not $expectedIdentifiers) {
        Write-Host "  ⚠ $scriptName - 未定义期望的状态标识符" -ForegroundColor Yellow
        continue
    }
    
    $foundIdentifiers = @()
    foreach ($identifier in $expectedIdentifiers) {
        if ($content -match "\[$identifier\]") {
            $foundIdentifiers += $identifier
        }
    }
    
    if ($foundIdentifiers.Count -eq 0) {
        Write-Host "  ✗ $scriptName - 未找到任何状态标识符" -ForegroundColor Red
        $Issues += "缺少状态标识符: $($script.Path)"
        $FailedScripts++
    } elseif ($foundIdentifiers.Count -eq $expectedIdentifiers.Count) {
        Write-Host "  ✓ $scriptName - 所有状态标识符完整" -ForegroundColor Green
        $PassedScripts++
    } else {
        Write-Host "  ⚠ $scriptName - 部分状态标识符缺失" -ForegroundColor Yellow
        $missing = $expectedIdentifiers | Where-Object { $_ -notin $foundIdentifiers }
        Write-Host "    缺失: $($missing -join ', ')" -ForegroundColor Yellow
        $Issues += "部分状态标识符缺失: $($script.Path) - $($missing -join ', ')"
        $PassedScripts++  # 部分通过也算通过
    }
    
    if ($Verbose -and $foundIdentifiers.Count -gt 0) {
        Write-Host "    找到: $($foundIdentifiers -join ', ')" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "[3/3] 检查标准参数支持..." -ForegroundColor Magenta
Write-Host ""

$StandardParams = @("NoWait", "param.*NoWait")

foreach ($script in $ScriptsToCheck) {
    $fullPath = Join-Path $ProjectRoot $script.Path
    $scriptName = "$($script.Module)/$($script.Type)"
    
    if (-not (Test-Path $fullPath)) { continue }
    if (-not $script.Path.EndsWith(".ps1")) { continue }  # 只检查 PowerShell 脚本
    
    $content = Get-Content $fullPath -Raw -Encoding UTF8
    
    $hasStandardParams = $false
    foreach ($param in $StandardParams) {
        if ($content -match $param) {
            $hasStandardParams = $true
            break
        }
    }
    
    if ($hasStandardParams) {
        Write-Host "  ✓ $scriptName - 支持标准参数" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ $scriptName - 缺少标准参数支持" -ForegroundColor Yellow
        $Issues += "缺少标准参数: $($script.Path)"
    }
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          检查结果汇总                                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "总脚本数: $TotalScripts" -ForegroundColor Cyan
Write-Host "通过检查: $PassedScripts" -ForegroundColor Green
Write-Host "检查失败: $FailedScripts" -ForegroundColor Red
Write-Host "发现问题: $($Issues.Count)" -ForegroundColor Yellow

if ($Issues.Count -gt 0) {
    Write-Host ""
    Write-Host "问题详情:" -ForegroundColor Yellow
    foreach ($issue in $Issues) {
        Write-Host "  • $issue" -ForegroundColor Yellow
    }
}

Write-Host ""

if ($Issues.Count -eq 0) {
    Write-Host "[COMPLIANCE_STATUS:PASSED]" -ForegroundColor Green
    Write-Host "✓ 所有脚本都符合规范协议！" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[COMPLIANCE_STATUS:ISSUES_FOUND]" -ForegroundColor Yellow
    Write-Host "⚠ 发现 $($Issues.Count) 个合规性问题" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "建议操作:" -ForegroundColor Cyan
    Write-Host "  1. 查看问题详情并手动修复" -ForegroundColor Cyan
    Write-Host "  2. 参考规范文档: 文档/协议/脚本/Mon脚本规范协议.md" -ForegroundColor Cyan
    Write-Host "  3. 修复后重新运行此检查工具" -ForegroundColor Cyan
    exit 1
}
