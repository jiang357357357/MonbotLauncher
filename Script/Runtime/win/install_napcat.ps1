param(
    [switch]$DownloadOnly,
    [switch]$RunInstaller,
    [switch]$AcceptNapCatLicense,
    [string]$Version = "latest",
    [string]$CacheRoot = "",
    [string]$ArchivePath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "../../..")).Path
$NapCatHome = if ($env:MON_NAPCAT_HOME) { $env:MON_NAPCAT_HOME } else { Join-Path $ProjectRoot "napcat" }
$InstallRoot = if ($env:MON_NAPCAT_INSTALL_BASE_DIR) { $env:MON_NAPCAT_INSTALL_BASE_DIR } else { Join-Path $NapCatHome "Napcat" }
if ([string]::IsNullOrWhiteSpace($CacheRoot)) {
    $CacheRoot = if ($env:MON_NAPCAT_RUNTIME_CACHE_ROOT) {
        $env:MON_NAPCAT_RUNTIME_CACHE_ROOT
    }
    else {
        Join-Path $ProjectRoot ".runtime\napcat-github"
    }
}
if ($env:MON_NAPCAT_RUNTIME_VERSION) { $Version = $env:MON_NAPCAT_RUNTIME_VERSION }
if ($env:MON_NAPCAT_SHELL_ARCHIVE) { $ArchivePath = $env:MON_NAPCAT_SHELL_ARCHIVE }

$LicenseAccepted = $AcceptNapCatLicense -or $env:MON_NAPCAT_LICENSE_ACCEPTED -eq "1"
$ShouldInstall = -not $DownloadOnly -and ($RunInstaller -or $LicenseAccepted)
$ReleaseApiRoot = "https://api.github.com/repos/NapNeko/NapCatQQ/releases"
$AssetName = "NapCat.Shell.zip"

function Get-SystemQqExecutable {
    $RegistryKeys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\QQ",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QQ",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QQ"
    )
    foreach ($Key in $RegistryKeys) {
        try {
            $UninstallString = [string](Get-ItemProperty -LiteralPath $Key -ErrorAction Stop).UninstallString
            if (-not [string]::IsNullOrWhiteSpace($UninstallString)) {
                $UninstallExecutable = $UninstallString.Trim().Trim('"')
                $Candidate = Join-Path (Split-Path -Parent $UninstallExecutable) "QQ.exe"
                if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
                    return (Get-Item -LiteralPath $Candidate).FullName
                }
            }
        }
        catch {
            continue
        }
    }
    $Fallbacks = @(
        (Join-Path $env:ProgramFiles "Tencent\QQNT\QQ.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Tencent\QQNT\QQ.exe")
    )
    foreach ($Candidate in $Fallbacks) {
        if (-not [string]::IsNullOrWhiteSpace($Candidate) -and (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
            return (Get-Item -LiteralPath $Candidate).FullName
        }
    }
    return $null
}

function Get-OfficialRelease {
    param([string]$RequestedVersion)
    $Headers = @{ "User-Agent" = "Mon-NapCat-Installer"; "Accept" = "application/vnd.github+json" }
    $Url = if ([string]::IsNullOrWhiteSpace($RequestedVersion) -or $RequestedVersion -eq "latest") {
        "$ReleaseApiRoot/latest"
    }
    else {
        $Tag = if ($RequestedVersion.StartsWith("v")) { $RequestedVersion } else { "v$RequestedVersion" }
        "$ReleaseApiRoot/tags/$Tag"
    }
    Write-Host "[*] Resolving the official NapCat release: $Url" -ForegroundColor Cyan
    return Invoke-RestMethod -Uri $Url -Headers $Headers -TimeoutSec 30
}

function Get-ExpectedSha256 {
    param([object]$Asset)
    $Digest = [string]$Asset.digest
    if ($Digest -match '^sha256:([0-9a-fA-F]{64})$') {
        return $Matches[1].ToLowerInvariant()
    }
    return ""
}

function Test-ArchiveHash {
    param([string]$Path, [string]$ExpectedSha256)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ([string]::IsNullOrWhiteSpace($ExpectedSha256)) { return $true }
    $Actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    return $Actual -eq $ExpectedSha256
}

function Install-ShellArchive {
    param([string]$SourceArchive, [string]$Destination, [string]$ResolvedVersion, [string]$Sha256)

    $StagingRoot = Join-Path $NapCatHome ".install-$PID"
    $BackupRoot = Join-Path $NapCatHome ".backup-$PID"
    if (Test-Path -LiteralPath $StagingRoot) { Remove-Item -LiteralPath $StagingRoot -Recurse -Force }
    if (Test-Path -LiteralPath $BackupRoot) { Remove-Item -LiteralPath $BackupRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $StagingRoot -Force | Out-Null

    try {
        Write-Host "[*] Extracting the official NapCat Shell..." -ForegroundColor Cyan
        Expand-Archive -LiteralPath $SourceArchive -DestinationPath $StagingRoot -Force

        $RequiredFiles = @("napcat.mjs", "NapCatWinBootMain.exe", "NapCatWinBootHook.dll", "qqnt.json")
        foreach ($RelativePath in $RequiredFiles) {
            $RequiredPath = Join-Path $StagingRoot $RelativePath
            if (-not (Test-Path -LiteralPath $RequiredPath -PathType Leaf)) {
                throw "The official NapCat Shell archive is incomplete: $RelativePath is missing."
            }
        }

        if (Test-Path -LiteralPath $InstallRoot -PathType Container) {
            foreach ($PersistentDirectory in @("config", "cache")) {
                $Existing = Join-Path $InstallRoot $PersistentDirectory
                if (Test-Path -LiteralPath $Existing -PathType Container) {
                    Copy-Item -LiteralPath $Existing -Destination $StagingRoot -Recurse -Force
                }
            }
            Move-Item -LiteralPath $InstallRoot -Destination $BackupRoot
        }

        try {
            Move-Item -LiteralPath $StagingRoot -Destination $InstallRoot
        }
        catch {
            if (Test-Path -LiteralPath $BackupRoot -PathType Container) {
                Move-Item -LiteralPath $BackupRoot -Destination $InstallRoot
            }
            throw
        }

        if (Test-Path -LiteralPath $BackupRoot -PathType Container) {
            Remove-Item -LiteralPath $BackupRoot -Recurse -Force
        }

        $Metadata = [ordered]@{
            source = "https://github.com/NapNeko/NapCatQQ"
            asset = $AssetName
            version = $ResolvedVersion
            sha256 = $Sha256
            installedAt = (Get-Date).ToUniversalTime().ToString("o")
        }
        $Metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $InstallRoot ".mon-runtime.json") -Encoding UTF8
    }
    finally {
        if (Test-Path -LiteralPath $StagingRoot -PathType Container) {
            Remove-Item -LiteralPath $StagingRoot -Recurse -Force
        }
    }
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "NapCat external runtime installer (Windows)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Project directory: $ProjectRoot"
Write-Host "Deployment directory: $InstallRoot"
Write-Host "Package source: official NapNeko/NapCatQQ GitHub release"
Write-Host "Requested version: $Version"
Write-Host ""
Write-Host "[!] NapCat is restricted to non-commercial use." -ForegroundColor Yellow
Write-Host ""

$QqExecutable = Get-SystemQqExecutable
if (-not $QqExecutable) {
    Write-Host "[NAPCAT_STATUS:QQ_NOT_FOUND]"
    throw "Tencent QQ was not found. Install the official Windows QQ client before installing NapCat Shell."
}
Write-Host "[OK] System QQ: $QqExecutable" -ForegroundColor Green

New-Item -ItemType Directory -Path $NapCatHome -Force | Out-Null
New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $ProjectRoot "logs") -Force | Out-Null

$ResolvedVersion = $Version
$ExpectedSha256 = ""
$DownloadUrl = ""

if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
    $Release = Get-OfficialRelease -RequestedVersion $Version
    $ResolvedVersion = [string]$Release.tag_name
    $Asset = $Release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1
    if (-not $Asset) {
        throw "The official release $ResolvedVersion does not contain $AssetName."
    }
    $ExpectedSha256 = Get-ExpectedSha256 -Asset $Asset
    $DownloadUrl = [string]$Asset.browser_download_url
    $ArchivePath = Join-Path (Join-Path $CacheRoot $ResolvedVersion) $AssetName
    New-Item -ItemType Directory -Path (Split-Path -Parent $ArchivePath) -Force | Out-Null

    if ($Force -or -not (Test-ArchiveHash -Path $ArchivePath -ExpectedSha256 $ExpectedSha256)) {
        Write-Host "[*] Downloading $DownloadUrl" -ForegroundColor Cyan
        $TemporaryArchive = "$ArchivePath.download"
        if (Test-Path -LiteralPath $TemporaryArchive) { Remove-Item -LiteralPath $TemporaryArchive -Force }
        try {
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $TemporaryArchive -Headers @{ "User-Agent" = "Mon-NapCat-Installer" } -TimeoutSec 600 -UseBasicParsing
            if (-not (Test-ArchiveHash -Path $TemporaryArchive -ExpectedSha256 $ExpectedSha256)) {
                throw "SHA256 verification failed for the downloaded NapCat Shell archive."
            }
            Move-Item -LiteralPath $TemporaryArchive -Destination $ArchivePath -Force
        }
        finally {
            if (Test-Path -LiteralPath $TemporaryArchive) { Remove-Item -LiteralPath $TemporaryArchive -Force }
        }
    }
    else {
        Write-Host "[i] Using verified cached archive: $ArchivePath" -ForegroundColor DarkGray
    }
}
else {
    $ArchivePath = [System.IO.Path]::GetFullPath($ArchivePath)
    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        throw "NapCat Shell archive does not exist: $ArchivePath"
    }
    $ExpectedSha256 = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
}

Write-Host "[OK] NapCat Shell archive: $ArchivePath" -ForegroundColor Green
Write-Host "[OK] SHA256: $ExpectedSha256" -ForegroundColor Green

if (-not $ShouldInstall) {
    Write-Host ""
    Write-Host "[NAPCAT_STATUS:PACKAGE_READY]"
    Write-Host "Run again with -RunInstaller -AcceptNapCatLicense to install the verified package."
    exit 0
}
if (-not $LicenseAccepted) {
    Write-Host "[NAPCAT_STATUS:LICENSE_NOT_ACCEPTED]"
    throw "Installing NapCat requires -AcceptNapCatLicense."
}

Install-ShellArchive -SourceArchive $ArchivePath -Destination $InstallRoot -ResolvedVersion $ResolvedVersion -Sha256 $ExpectedSha256

$PluginEntry = Join-Path $InstallRoot "napcat.mjs"
if (-not (Test-Path -LiteralPath $PluginEntry -PathType Leaf)) {
    Write-Host "[NAPCAT_STATUS:RUNTIME_INVALID]"
    throw "NapCat installation completed without a usable napcat.mjs entry."
}

Write-Host ""
Write-Host "[NAPCAT_STATUS:INSTALLED]"
Write-Host "NapCat Shell $ResolvedVersion installed successfully."
Write-Host "Plugin entry: $PluginEntry"
