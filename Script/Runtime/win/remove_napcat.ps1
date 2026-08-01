$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../../..")
$MonRoot = Resolve-Path (Join-Path $ProjectRoot "..")
$MonPmLauncher = Join-Path $MonRoot "Script/launch/win/monpm.ps1"
$StopScript = Join-Path $ProjectRoot "Script/Process/win/stop_napcat_process.ps1"
$NapCatHome = if ($env:MON_NAPCAT_HOME) { $env:MON_NAPCAT_HOME } else { Join-Path $ProjectRoot "napcat" }
$MonPmName = "napcat"

Write-Host "================================================"
Write-Host "NapCat external runtime uninstaller (Windows)"
Write-Host "================================================"
Write-Host "Project directory: $ProjectRoot"
Write-Host "Deployment directory: $NapCatHome"
Write-Host "MonPM application: $MonPmName"
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
    Write-Host "[*] Stopping MonPM application: $MonPmName"
    if (Test-Path -LiteralPath $StopScript -PathType Leaf) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StopScript | Out-Host
    }
    else {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MonPmLauncher -Action stop -Name $MonPmName | Out-Host
    }
}
catch {
    Write-Host "[!] MonPM cleanup failed: $($_.Exception.Message)"
}

if (Test-Path -Path $NapCatHome) {
    if (-not (Test-SafeRemovePath -Path $NapCatHome)) {
        Write-Host "[x] Refusing to delete an unsafe path: $NapCatHome"
        Write-Host "[NAPCAT_STATUS:REMOVE_REFUSED]"
        exit 2
    }
    Write-Host "[*] Removing runtime directory: $NapCatHome"
    Remove-Item -Path $NapCatHome -Recurse -Force
    Write-Host "[OK] Removed: $NapCatHome"
}
else {
    Write-Host "[i] Skipping missing path: $NapCatHome"
}

Write-Host ""
Write-Host "[NAPCAT_STATUS:REMOVED]"
Write-Host "NapCat external runtime uninstalled."
