$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../../..")
$NapCatHome = if ($env:MON_NAPCAT_HOME) { $env:MON_NAPCAT_HOME } else { Join-Path $ProjectRoot "napcat" }
$Pm2Name = if ($env:MON_NAPCAT_PM2_NAME) { $env:MON_NAPCAT_PM2_NAME } else { "NapCat-Service" }

Write-Host "================================================"
Write-Host "NapCat 外置运行时卸载工具 (Windows)"
Write-Host "================================================"
Write-Host "项目目录: $ProjectRoot"
Write-Host "部署目录: $NapCatHome"
Write-Host "PM2 应用: $Pm2Name"
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
    $Pm2 = Get-Command pm2 -ErrorAction SilentlyContinue
    if ($Pm2) {
        $Json = & pm2 jlist
        $Apps = $Json | ConvertFrom-Json
        $App = $Apps | Where-Object { $_.name -eq $Pm2Name } | Select-Object -First 1
        if ($App) {
            Write-Host "[*] 停止并移除 PM2 应用: $Pm2Name"
            & pm2 delete $Pm2Name | Out-Host
            & pm2 save --force | Out-Null
        }
        else {
            Write-Host "[i] PM2 中未找到 NapCat 应用"
        }
    }
    else {
        Write-Host "[i] 未找到 pm2，跳过 PM2 清理"
    }
}
catch {
    Write-Host "[!] PM2 清理失败: $($_.Exception.Message)"
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
