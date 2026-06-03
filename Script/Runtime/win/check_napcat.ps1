$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../../..")

$CandidatePaths = @()
if ($env:MON_NAPCAT_HOME) {
    $CandidatePaths += $env:MON_NAPCAT_HOME
}
$CandidatePaths += @(
    (Join-Path $ProjectRoot "napcat"),
    (Join-Path $HOME "Napcat"),
    (Join-Path $HOME "NapCat"),
    (Join-Path $ProjectRoot ".runtime/napcat")
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "NapCat 外置运行时检查 (Windows)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$FoundPath = $null
foreach ($Path in $CandidatePaths) {
    if (Test-Path -Path $Path -PathType Container) {
        $Children = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne ".installer" }
        if ($Children) {
            $FoundPath = $Path
            break
        }
    }
}

if (-not $FoundPath) {
    $DefaultPath = Join-Path $ProjectRoot "napcat"
    if (Test-Path -Path $DefaultPath -PathType Container) {
        Write-Host "[!] NapCat 部署目录已创建，但尚未发现运行时文件" -ForegroundColor Yellow
        Write-Host "    部署目录: $DefaultPath"
    }
    else {
        Write-Host "[!] 未发现 NapCat 运行时目录" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "[NAPCAT_STATUS:NOT_INSTALLED]"
    Write-Host "[NAPCAT_HOME:$DefaultPath]"
    exit 0
}

Write-Host "[OK] NapCat 运行时目录: $FoundPath" -ForegroundColor Green
Write-Host ""
Write-Host "[NAPCAT_STATUS:INSTALLED]"
Write-Host "[NAPCAT_HOME:$FoundPath]"
