# Mon project script compliance checker
# Checks whether project scripts follow the script protocol.

param(
    [switch]$Verbose,
    [switch]$FixIssues
)

# Configure UTF-8 console output.
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Project root.
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "          Mon project script compliance checker" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project root: $ProjectRoot" -ForegroundColor Cyan
Write-Host ""

# Scripts to check.
$ScriptsToCheck = @(
    # MonCore scripts.
    @{Path = "Core\Script\EnvTools\win\check_env.ps1"; Type = "ENV_CHECK"; Module = "MonCore"},
    @{Path = "Core\Script\EnvTools\win\install_env.ps1"; Type = "ENV_INSTALL"; Module = "MonCore"},
    @{Path = "Core\Script\EnvTools\win\remove_env.ps1"; Type = "ENV_REMOVE"; Module = "MonCore"},
    @{Path = "Core\scripts\Start\start_moncore.ps1"; Type = "SERVER_START"; Module = "MonCore"},
    @{Path = "Core\scripts\DB\migrate_db.py"; Type = "DB_MIGRATE"; Module = "MonCore"},
    @{Path = "Core\scripts\DB\init_admin.py"; Type = "DB_INIT"; Module = "MonCore"},
    
    # MonOs scripts.
    @{Path = "BaseOs\Script\EnvTools\win\check_env.ps1"; Type = "ENV_CHECK"; Module = "MonOs"},
    @{Path = "BaseOs\Script\EnvTools\win\install_env.ps1"; Type = "ENV_INSTALL"; Module = "MonOs"},
    @{Path = "BaseOs\Script\EnvTools\win\remove_env.ps1"; Type = "ENV_REMOVE"; Module = "MonOs"},
    @{Path = "BaseOs\Script\main\start_monos.ps1"; Type = "SERVER_START"; Module = "MonOs"},
    
    # Shared scripts.
    @{Path = "scripts\7zip\pack.ps1"; Type = "PACK"; Module = "Common"}
)

# Expected status identifiers.
$ExpectedStatusIdentifiers = @{
    "ENV_CHECK" = @("ENV_STATUS:INSTALLED", "ENV_STATUS:PARTIAL", "ENV_STATUS:NOT_INSTALLED")
    "ENV_INSTALL" = @("INSTALL_STATUS:SUCCESS", "INSTALL_STATUS:FAILED")
    "ENV_REMOVE" = @("REMOVE_STATUS:SUCCESS", "REMOVE_STATUS:PARTIAL", "REMOVE_STATUS:FAILED", "REMOVE_STATUS:NOTHING")
    "SERVER_START" = @("SERVER_STATUS:STOPPED", "SERVER_STATUS:FAILED")
    "DB_MIGRATE" = @("DB_STATUS:MIGRATED", "DB_STATUS:FAILED")
    "DB_INIT" = @("ADMIN_STATUS:CREATED", "ADMIN_STATUS:EXISTS", "ADMIN_STATUS:FAILED")
    "PACK" = @("PACK_STATUS:SUCCESS", "PACK_STATUS:FAILED", "PACK_STATUS:NO_FILES")
}

# Check result counters.
$TotalScripts = 0
$PassedScripts = 0
$FailedScripts = 0
$Issues = @()

Write-Host "[1/3] Checking script file existence..." -ForegroundColor Magenta
Write-Host ""

foreach ($script in $ScriptsToCheck) {
    $TotalScripts++
    $fullPath = Join-Path $ProjectRoot $script.Path
    $scriptName = "$($script.Module)/$($script.Type)"
    
    if (-not (Test-Path $fullPath)) {
        Write-Host "  [x] $scriptName - file does not exist" -ForegroundColor Red
        $Issues += "File does not exist: $($script.Path)"
        $FailedScripts++
        continue
    }
    
    Write-Host "  [OK] $scriptName - file exists" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/3] Checking status identifier compliance..." -ForegroundColor Magenta
Write-Host ""

foreach ($script in $ScriptsToCheck) {
    $fullPath = Join-Path $ProjectRoot $script.Path
    $scriptName = "$($script.Module)/$($script.Type)"
    
    if (-not (Test-Path $fullPath)) { continue }
    
    $content = Get-Content $fullPath -Raw -Encoding UTF8
    $expectedIdentifiers = $ExpectedStatusIdentifiers[$script.Type]
    
    if (-not $expectedIdentifiers) {
        Write-Host "  [!] $scriptName - no expected status identifiers are defined" -ForegroundColor Yellow
        continue
    }
    
    $foundIdentifiers = @()
    foreach ($identifier in $expectedIdentifiers) {
        if ($content -match "\[$identifier\]") {
            $foundIdentifiers += $identifier
        }
    }
    
    if ($foundIdentifiers.Count -eq 0) {
        Write-Host "  [x] $scriptName - no status identifiers found" -ForegroundColor Red
        $Issues += "Missing status identifiers: $($script.Path)"
        $FailedScripts++
    } elseif ($foundIdentifiers.Count -eq $expectedIdentifiers.Count) {
        Write-Host "  [OK] $scriptName - all status identifiers are present" -ForegroundColor Green
        $PassedScripts++
    } else {
        Write-Host "  [!] $scriptName - some status identifiers are missing" -ForegroundColor Yellow
        $missing = $expectedIdentifiers | Where-Object { $_ -notin $foundIdentifiers }
        Write-Host "    Missing: $($missing -join ', ')" -ForegroundColor Yellow
        $Issues += "Some status identifiers are missing: $($script.Path) - $($missing -join ', ')"
        $PassedScripts++  # A partial match still counts as passed.
    }
    
    if ($Verbose -and $foundIdentifiers.Count -gt 0) {
        Write-Host "    Found: $($foundIdentifiers -join ', ')" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "[3/3] Checking standard parameter support..." -ForegroundColor Magenta
Write-Host ""

$StandardParams = @("NoWait", "param.*NoWait")

foreach ($script in $ScriptsToCheck) {
    $fullPath = Join-Path $ProjectRoot $script.Path
    $scriptName = "$($script.Module)/$($script.Type)"
    
    if (-not (Test-Path $fullPath)) { continue }
    if (-not $script.Path.EndsWith(".ps1")) { continue }  # Check PowerShell scripts only.
    
    $content = Get-Content $fullPath -Raw -Encoding UTF8
    
    $hasStandardParams = $false
    foreach ($param in $StandardParams) {
        if ($content -match $param) {
            $hasStandardParams = $true
            break
        }
    }
    
    if ($hasStandardParams) {
        Write-Host "  [OK] $scriptName - standard parameters supported" -ForegroundColor Green
    } else {
        Write-Host "  [!] $scriptName - standard parameter support is missing" -ForegroundColor Yellow
        $Issues += "Missing standard parameters: $($script.Path)"
    }
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "          Check result summary" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Total scripts: $TotalScripts" -ForegroundColor Cyan
Write-Host "Passed checks: $PassedScripts" -ForegroundColor Green
Write-Host "Failed checks: $FailedScripts" -ForegroundColor Red
Write-Host "Issues found: $($Issues.Count)" -ForegroundColor Yellow

if ($Issues.Count -gt 0) {
    Write-Host ""
    Write-Host "Issue details:" -ForegroundColor Yellow
    foreach ($issue in $Issues) {
        Write-Host "  - $issue" -ForegroundColor Yellow
    }
}

Write-Host ""

if ($Issues.Count -eq 0) {
    Write-Host "[COMPLIANCE_STATUS:PASSED]" -ForegroundColor Green
    Write-Host "[OK] All scripts comply with the protocol." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[COMPLIANCE_STATUS:ISSUES_FOUND]" -ForegroundColor Yellow
    Write-Host "[!] Found $($Issues.Count) compliance issues" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Recommended actions:" -ForegroundColor Cyan
    Write-Host "  1. Review the issue details and fix them manually" -ForegroundColor Cyan
    Write-Host "  2. Refer to the Mon script protocol documentation" -ForegroundColor Cyan
    Write-Host "  3. Run this checker again after applying fixes" -ForegroundColor Cyan
    exit 1
}
