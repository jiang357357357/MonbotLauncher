$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../../..")
$MonRoot = Resolve-Path (Join-Path $ProjectRoot "..")
$MonPmLauncher = Join-Path $MonRoot "Script/launch/win/monpm.ps1"
$NapCatHome = if ($env:MON_NAPCAT_HOME) { $env:MON_NAPCAT_HOME } else { Join-Path $ProjectRoot "napcat" }
$MonPmName = "napcat"

Write-Host "================================================"
Write-Host "NapCat 外置运行时卸载工具 (Windows)"
Write-Host "================================================"
Write-Host "项目目录: $ProjectRoot"
Write-Host "部署目录: $NapCatHome"
Write-Host "MonPM 应用: $MonPmName"
Write-Host ""

function Test-SafeRemovePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $ProjectFull = [System.IO.Path]::GetFullPath([string]$ProjectRoot)
    if ($FullPath -eq [System.IO.Path]::GetPathRoot($FullPath)) { return $false }
    if ($FullPath -eq $ProjectFull) { return $false }
    return $FullPath.StartsWith($ProjectFull, [System.StringComparison]::OrdinalIgnoreCase)
}

try {
    Write-Host "[*] 停止 MonPM 应用: $MonPmName"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MonPmLauncher -Action stop -Name $MonPmName | Out-Host
}
catch {
    Write-Host "[!] MonPM 清理失败: $($_.Exception.Message)"
}

if (Test-Path -Path $NapCatHome) {
    if (-not (Test-SafeRemovePath -Path $NapCatHome)) {
        Write-Host "[x] 拒绝删除不安全路径: $NapCatHome"
        Write-Host "[NAPCAT_STATUS:REMOVE_REFUSED]"
        exit 2
    }
    Write-Host "[*] 删除运行时目录: $NapCatHome"
    Remove-Item -Path $NapCatHome -Recurse -Force
    Write-Host "[OK] 已删除: $NapCatHome"
}
else {
    Write-Host "[i] 跳过不存在的路径: $NapCatHome"
}

Write-Host ""
Write-Host "[NAPCAT_STATUS:REMOVED]"
Write-Host "NapCat 外置运行时已卸载。"
