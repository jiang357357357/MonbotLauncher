$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "napcat_common.ps1")

$LaunchEntry = Get-NapCatLaunchEntry
if (-not $LaunchEntry) {
    Write-Host "[NAPCAT_STATUS:NOT_INSTALLED]"
    throw "No installed NapCat Windows shell was found under $NapCatHome"
}
$ShellRoot = Split-Path -Parent $LaunchEntry
$QqExecutable = Get-NapCatQqExecutable
$HookLibrary = Join-Path $ShellRoot "NapCatWinBootHook.dll"
$MainEntry = Join-Path $ShellRoot "napcat.mjs"
$QuickLoginAccount = Get-NapCatQuickLoginAccount

if (-not $QqExecutable) {
    Write-Host "[NAPCAT_STATUS:QQ_NOT_FOUND]"
    throw "Tencent QQ was not found. Install QQ or set MON_NAPCAT_QQ_EXECUTABLE."
}
if (-not (Test-Path -LiteralPath $HookLibrary -PathType Leaf)) {
    Write-Host "[NAPCAT_STATUS:RUNTIME_INVALID]"
    throw "NapCat injection library is missing: $HookLibrary"
}
if (-not (Test-Path -LiteralPath $MainEntry -PathType Leaf)) {
    Write-Host "[NAPCAT_STATUS:RUNTIME_INVALID]"
    throw "NapCat main entry is missing: $MainEntry"
}

Write-Host "================================================"
Write-Host "NapCat MonPM foreground runner (Windows)"
Write-Host "================================================"
Write-Host "Runtime directory: $ShellRoot"
Write-Host "Launch entry: $LaunchEntry"
Write-Host "QQ executable: $QqExecutable"
if ($QuickLoginAccount) { Write-Host "Quick login account: $QuickLoginAccount" }
Write-Host "[NAPCAT_STATUS:STARTING]"

Push-Location $ShellRoot
try {
    $NormalizedMainEntry = $MainEntry.Replace('\', '/')
    $LoadScript = Join-Path $ShellRoot "loadNapCat.js"
    $env:NAPCAT_PATCH_PACKAGE = Join-Path $ShellRoot "qqnt.json"
    $env:NAPCAT_LOAD_PATH = $LoadScript
    $env:NAPCAT_INJECT_PATH = $HookLibrary
    $env:NAPCAT_LAUNCHER_PATH = $LaunchEntry
    $env:NAPCAT_MAIN_PATH = $MainEntry
    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($LoadScript, "(async () => {await import(`"file:///$NormalizedMainEntry`")})()", $Utf8WithoutBom)
    if ($QuickLoginAccount) {
        & $LaunchEntry $QqExecutable $HookLibrary "-q" $QuickLoginAccount
    }
    else {
        & $LaunchEntry $QqExecutable $HookLibrary
    }
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
