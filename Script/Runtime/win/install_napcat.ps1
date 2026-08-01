param(
    [switch]$DownloadOnly,
    [switch]$RunInstaller,
    [switch]$AcceptNapCatLicense,
    [string]$Version = "latest",
    [string]$RuntimePlatform = "win-x64",
    [string]$RuntimeRepoUrl = "https://gitcode.com/zz357357357/MonNapCatRuntime.git",
    [string]$RuntimeBranch = "master",
    [string]$CacheRoot = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "../../..")).Path
$NapCatHome = if ($env:MON_NAPCAT_HOME) { $env:MON_NAPCAT_HOME } else { Join-Path $ProjectRoot "napcat" }
if ([string]::IsNullOrWhiteSpace($CacheRoot)) {
    $CacheRoot = if ($env:MON_NAPCAT_RUNTIME_CACHE_ROOT) {
        $env:MON_NAPCAT_RUNTIME_CACHE_ROOT
    }
    else {
        Join-Path $ProjectRoot ".runtime\napcat-gitcode"
    }
}
if ($env:MON_NAPCAT_RUNTIME_REPO_URL) { $RuntimeRepoUrl = $env:MON_NAPCAT_RUNTIME_REPO_URL }
if ($env:MON_NAPCAT_RUNTIME_REPO_BRANCH) { $RuntimeBranch = $env:MON_NAPCAT_RUNTIME_REPO_BRANCH }
if ($env:MON_NAPCAT_RUNTIME_VERSION) { $Version = $env:MON_NAPCAT_RUNTIME_VERSION }
if ($env:MON_NAPCAT_RUNTIME_PLATFORM) { $RuntimePlatform = $env:MON_NAPCAT_RUNTIME_PLATFORM }

$RuntimeRepoDir = Join-Path $CacheRoot "MonNapCatRuntime"
$LicenseAccepted = $AcceptNapCatLicense -or $env:MON_NAPCAT_LICENSE_ACCEPTED -eq "1"
$ShouldRunInstaller = -not $DownloadOnly -and ($RunInstaller -or $LicenseAccepted)

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git command failed with exit code ${LASTEXITCODE}: git $($Arguments -join ' ')"
    }
}

function Test-SafeCachePath {
    param([string]$Path)
    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $CacheFullPath = [System.IO.Path]::GetFullPath($CacheRoot).TrimEnd('\') + '\'
    return $FullPath.StartsWith($CacheFullPath, [System.StringComparison]::OrdinalIgnoreCase)
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "NapCat external runtime installer (Windows)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Project directory: $ProjectRoot"
Write-Host "Deployment directory: $NapCatHome"
Write-Host "Runtime repository: $RuntimeRepoUrl ($RuntimeBranch)"
Write-Host "Runtime package: $RuntimePlatform / $Version"
Write-Host ""
Write-Host "[!] The Windows package is an online bootstrap and still downloads QQ/NapCat components." -ForegroundColor Yellow
Write-Host "[!] NapCat is restricted to non-commercial use; the mirrored package includes its upstream license." -ForegroundColor Yellow
Write-Host ""

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required to download the private GitCode runtime repository."
}

New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
if ((Test-Path -LiteralPath $RuntimeRepoDir) -and -not (Test-Path -LiteralPath (Join-Path $RuntimeRepoDir ".git"))) {
    if (-not (Test-SafeCachePath -Path $RuntimeRepoDir)) {
        throw "Refusing to replace an unsafe cache path: $RuntimeRepoDir"
    }
    Remove-Item -LiteralPath $RuntimeRepoDir -Recurse -Force
}

if (Test-Path -LiteralPath (Join-Path $RuntimeRepoDir ".git")) {
    Write-Host "[*] Updating the GitCode NapCat runtime repository..." -ForegroundColor Cyan
    Invoke-Git -Arguments @("-C", $RuntimeRepoDir, "remote", "set-url", "origin", $RuntimeRepoUrl)
    Invoke-Git -Arguments @("-C", $RuntimeRepoDir, "fetch", "--quiet", "--depth", "1", "origin", $RuntimeBranch)
    Invoke-Git -Arguments @("-C", $RuntimeRepoDir, "checkout", "--quiet", "--force", "--detach", "FETCH_HEAD")
    Invoke-Git -Arguments @("-C", $RuntimeRepoDir, "sparse-checkout", "init", "--no-cone")
    Invoke-Git -Arguments @("-C", $RuntimeRepoDir, "sparse-checkout", "set", "--no-cone", "/manifest.json", "/napcat/$RuntimePlatform/")
    Invoke-Git -Arguments @("-C", $RuntimeRepoDir, "clean", "-fdq")
}
else {
    Write-Host "[*] Cloning the GitCode NapCat runtime repository..." -ForegroundColor Cyan
    Invoke-Git -Arguments @("clone", "--depth", "1", "--filter=blob:none", "--sparse", "--branch", $RuntimeBranch, $RuntimeRepoUrl, $RuntimeRepoDir)
    Invoke-Git -Arguments @("-C", $RuntimeRepoDir, "sparse-checkout", "set", "--no-cone", "/manifest.json", "/napcat/$RuntimePlatform/")
}

if ($Force) {
    Write-Host "[i] Runtime cache was refreshed from the remote branch." -ForegroundColor DarkGray
}

$RootManifestPath = Join-Path $RuntimeRepoDir "manifest.json"
if (-not (Test-Path -LiteralPath $RootManifestPath -PathType Leaf)) {
    throw "Runtime repository manifest is missing: $RootManifestPath"
}
$RootManifest = Get-Content -LiteralPath $RootManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$ResolvedVersion = $Version
if ($Version -eq "latest") {
    $PlatformProperty = $RootManifest.platforms.PSObject.Properties[$RuntimePlatform]
    if (-not $PlatformProperty -or -not $PlatformProperty.Value.version) {
        throw "The runtime manifest does not define platform $RuntimePlatform."
    }
    $ResolvedVersion = [string]$PlatformProperty.Value.version
}
if ($ResolvedVersion -notmatch '^v[0-9A-Za-z._-]+$') {
    throw "Invalid runtime version: $ResolvedVersion"
}

$PackageRoot = Join-Path $RuntimeRepoDir "napcat\$RuntimePlatform\$ResolvedVersion"
$PackageManifestPath = Join-Path $PackageRoot "manifest.json"
$PackageInstaller = Join-Path $PackageRoot "install-windows-bootstrap.ps1"
if (-not (Test-Path -LiteralPath $PackageManifestPath -PathType Leaf)) {
    throw "Windows runtime package manifest is missing: $PackageManifestPath"
}
if (-not (Test-Path -LiteralPath $PackageInstaller -PathType Leaf)) {
    throw "Windows runtime package installer is missing: $PackageInstaller"
}

$PackageManifest = Get-Content -LiteralPath $PackageManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($PackageManifest.platform -ne $RuntimePlatform -or $PackageManifest.version -ne $ResolvedVersion) {
    throw "Runtime package metadata does not match $RuntimePlatform / $ResolvedVersion."
}

Write-Host "[*] Verifying and extracting the GitCode Windows bootstrap..." -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PackageInstaller -BotLauncherRoot $ProjectRoot
if ($LASTEXITCODE -ne 0) {
    throw "Windows bootstrap extraction failed with exit code $LASTEXITCODE."
}

$BootstrapRoot = Join-Path $NapCatHome ".bootstrap\$ResolvedVersion"
$Installer = Join-Path $BootstrapRoot "NapCatInstaller.exe"
if (-not $ShouldRunInstaller) {
    Write-Host ""
    Write-Host "[NAPCAT_STATUS:BOOTSTRAP_READY]"
    Write-Host "Run the upstream installer after accepting the NapCat license:"
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File Script/Runtime/win/install_napcat.ps1 -RunInstaller -AcceptNapCatLicense"
    exit 0
}
if (-not $LicenseAccepted) {
    Write-Host "[NAPCAT_STATUS:LICENSE_NOT_ACCEPTED]"
    throw "Running the upstream installer requires -AcceptNapCatLicense."
}
if (-not (Test-Path -LiteralPath $Installer -PathType Leaf)) {
    throw "NapCatInstaller.exe is missing after extraction: $Installer"
}

Write-Host ""
Write-Host "[*] Starting the official NapCat Windows installer..." -ForegroundColor Cyan
Write-Warning "NapCatInstaller.exe is supplied by the upstream release and is not Authenticode signed."
Push-Location $BootstrapRoot
try {
    & $Installer
    $InstallerExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}
if ($null -ne $InstallerExitCode -and $InstallerExitCode -ne 0) {
    throw "NapCatInstaller.exe exited with code $InstallerExitCode."
}

Write-Host ""
Write-Host "[NAPCAT_STATUS:INSTALLER_FINISHED]"
Write-Host "NapCat Windows installer finished for $ResolvedVersion."
