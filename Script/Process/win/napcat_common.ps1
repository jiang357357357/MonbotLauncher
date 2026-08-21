$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$NapCatProcessScriptDir = $PSScriptRoot
$NapCatProjectRoot = (Resolve-Path (Join-Path $NapCatProcessScriptDir "../../..")).Path
$NapCatMonRoot = (Resolve-Path (Join-Path $NapCatProjectRoot "..")).Path
$NapCatHome = if ($env:MON_NAPCAT_HOME) { $env:MON_NAPCAT_HOME } else { Join-Path $NapCatProjectRoot "napcat" }
$NapCatMonPmLauncher = Join-Path $NapCatMonRoot "Script\launch\win\monpm.ps1"
$NapCatMonPmConfig = Join-Path $NapCatMonRoot ".run\monpm\monpm.json"
$NapCatMonPmName = "napcat"

function Get-NapCatPluginEntry {
    if (-not (Test-Path -LiteralPath $NapCatHome -PathType Container)) { return $null }
    $StandaloneEntry = Join-Path $NapCatHome "Napcat\napcat.mjs"
    if (Test-Path -LiteralPath $StandaloneEntry -PathType Leaf) {
        return (Get-Item -LiteralPath $StandaloneEntry).FullName
    }
    $Entry = Get-ChildItem -LiteralPath $NapCatHome -Recurse -File -Filter "napcat.mjs" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -match '[\\/]resources[\\/]app[\\/](app_launcher[\\/])?napcat[\\/]napcat\.mjs$' -or
            (Test-Path -LiteralPath (Join-Path $_.DirectoryName "NapCatWinBootMain.exe") -PathType Leaf)
        } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($Entry) { return $Entry.FullName }
    return $null
}

function Get-NapCatQqExecutable {
    if ($env:MON_NAPCAT_QQ_EXECUTABLE -and (Test-Path -LiteralPath $env:MON_NAPCAT_QQ_EXECUTABLE -PathType Leaf)) {
        return (Get-Item -LiteralPath $env:MON_NAPCAT_QQ_EXECUTABLE).FullName
    }
    $RegistryKeys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\QQ",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QQ",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QQ"
    )
    foreach ($Key in $RegistryKeys) {
        try {
            $UninstallString = [string](Get-ItemProperty -LiteralPath $Key -ErrorAction Stop).UninstallString
            if (-not [string]::IsNullOrWhiteSpace($UninstallString)) {
                $Candidate = Join-Path (Split-Path -Parent $UninstallString.Trim().Trim('"')) "QQ.exe"
                if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
                    return (Get-Item -LiteralPath $Candidate).FullName
                }
            }
        }
        catch {
            continue
        }
    }
    return $null
}

function Get-NapCatShellRoot {
    $PluginEntry = Get-NapCatPluginEntry
    if (-not $PluginEntry) { return $null }
    $Current = Get-Item -LiteralPath (Split-Path -Parent $PluginEntry)
    $HomeFull = [System.IO.Path]::GetFullPath($NapCatHome).TrimEnd('\')
    while ($Current -and $Current.FullName.StartsWith($HomeFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path -LiteralPath (Join-Path $Current.FullName "NapCatWinBootMain.exe") -PathType Leaf) {
            return $Current.FullName
        }
        $Current = $Current.Parent
    }
    return $null
}

function Get-NapCatLaunchEntry {
    if ($env:MON_NAPCAT_EXECUTABLE -and (Test-Path -LiteralPath $env:MON_NAPCAT_EXECUTABLE -PathType Leaf)) {
        return (Get-Item -LiteralPath $env:MON_NAPCAT_EXECUTABLE).FullName
    }
    $ShellRoot = Get-NapCatShellRoot
    if (-not $ShellRoot) { return $null }
    $Entry = Join-Path $ShellRoot "NapCatWinBootMain.exe"
    if (Test-Path -LiteralPath $Entry -PathType Leaf) { return $Entry }
    return $null
}

function Get-NapCatQuickLoginAccount {
    if ($env:MON_NAPCAT_QQ_ACCOUNT) { return $env:MON_NAPCAT_QQ_ACCOUNT }
    $ConfigPath = Join-Path $NapCatProjectRoot ".monconfig"
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return "" }
    $InSection = $false
    foreach ($RawLine in Get-Content -LiteralPath $ConfigPath -Encoding UTF8) {
        $Line = $RawLine.Trim()
        if ($Line -match '^\[(.+)\]$') {
            $InSection = $Matches[1] -eq "napcat_process"
            continue
        }
        if ($InSection -and $Line -match '^QQ_ACCOUNT\s*=\s*([^#\s]+)') {
            return $Matches[1]
        }
    }
    return ""
}

function Test-NapCatMonPmConfig {
    if (-not (Test-Path -LiteralPath $NapCatMonPmConfig -PathType Leaf)) { return $false }
    try {
        $Config = Get-Content -LiteralPath $NapCatMonPmConfig -Raw -Encoding UTF8 | ConvertFrom-Json
        $App = $Config.apps | Where-Object { $_.name -eq $NapCatMonPmName } | Select-Object -First 1
        return $null -ne $App -and ($App.platforms -contains "windows" -or $null -eq $App.platforms)
    }
    catch {
        return $false
    }
}

function Initialize-NapCatMonPmConfig {
    if (-not (Test-Path -LiteralPath $NapCatMonPmLauncher -PathType Leaf)) {
        throw "MonPM launcher not found: $NapCatMonPmLauncher"
    }
    if (-not (Test-NapCatMonPmConfig)) {
        Write-Host "[*] Refreshing MonPM configuration for Windows NapCat..." -ForegroundColor Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NapCatMonPmLauncher -Action refresh-config
        if ($LASTEXITCODE -ne 0) { throw "Failed to refresh MonPM configuration: $LASTEXITCODE" }
    }
}

function Invoke-NapCatMonPm {
    param([ValidateSet("start", "stop", "restart")][string]$Action)
    Initialize-NapCatMonPmConfig
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NapCatMonPmLauncher -Action $Action -Name $NapCatMonPmName
    if ($LASTEXITCODE -ne 0) { throw "MonPM $Action $NapCatMonPmName failed: $LASTEXITCODE" }
}

function Get-NapCatMonPmStatus {
    Initialize-NapCatMonPmConfig
    $RawOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NapCatMonPmLauncher -Action list -Json
    if ($LASTEXITCODE -ne 0) { throw "Failed to read MonPM status: $LASTEXITCODE" }
    $JsonText = $RawOutput -join "`n"
    $JsonStart = $JsonText.IndexOf("[")
    if ($JsonStart -lt 0) {
        throw "MonPM list did not return a JSON array."
    }
    $Apps = $JsonText.Substring($JsonStart) | ConvertFrom-Json
    $App = $Apps | Where-Object { $_.name -eq $NapCatMonPmName } | Select-Object -First 1
    if (-not $App) { return "missing" }
    if ($App.lifecycle_state) { return [string]$App.lifecycle_state }
    return [string]$App.state
}
