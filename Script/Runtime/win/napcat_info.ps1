param(
    [switch]$NoImage,
    [switch]$NoLogin,
    [switch]$Pretty
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "../../..")).Path
$MonRoot = (Resolve-Path (Join-Path $ProjectRoot "..")).Path
$MonPmLauncher = Join-Path $MonRoot "Script\launch\win\monpm.ps1"
$NapCatHome = if ($env:MON_NAPCAT_HOME) { $env:MON_NAPCAT_HOME } else { Join-Path $ProjectRoot "napcat" }
$DefaultInstallBaseDir = if ($env:MON_NAPCAT_INSTALL_BASE_DIR) { $env:MON_NAPCAT_INSTALL_BASE_DIR } else { Join-Path $NapCatHome "Napcat" }
$MonPmName = "napcat"

function Get-ModifiedAt {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return (Get-Item -LiteralPath $Path).LastWriteTime.ToString("s")
}

function Get-QrcodeDataUrl {
    param([string]$Path)
    if ($NoImage -or [string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $Bytes = [System.IO.File]::ReadAllBytes($Path)
    return "data:image/png;base64,$([Convert]::ToBase64String($Bytes))"
}

function Get-MonPmStatus {
    try {
        if (-not (Test-Path -LiteralPath $MonPmLauncher -PathType Leaf)) {
            return "unknown"
        }
        $Json = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MonPmLauncher -Action list -Json 2>$null
        $Apps = $Json | ConvertFrom-Json
        $App = $Apps | Where-Object { $_.name -eq $MonPmName } | Select-Object -First 1
        if (-not $App) {
            return "missing"
        }
        return [string]$App.state
    }
    catch {
        return "unknown"
    }
}

function Find-NapCatPluginEntry {
    $FixedEntry = Join-Path $DefaultInstallBaseDir "opt\QQ\resources\app\app_launcher\napcat\napcat.mjs"
    if (Test-Path -LiteralPath $FixedEntry -PathType Leaf) {
        return (Get-Item -LiteralPath $FixedEntry).FullName
    }
    if (-not (Test-Path -LiteralPath $NapCatHome -PathType Container)) {
        return $null
    }
    $Entry = Get-ChildItem -LiteralPath $NapCatHome -Recurse -File -Filter "napcat.mjs" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[\\/]resources[\\/]app[\\/](app_launcher[\\/])?napcat[\\/]napcat\.mjs$' } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($Entry) { return $Entry.FullName }
    return $null
}

function Find-ShellRoot {
    param([string]$PluginDirectory)
    if ([string]::IsNullOrWhiteSpace($PluginDirectory) -or -not (Test-Path -LiteralPath $PluginDirectory -PathType Container)) { return $null }
    $Current = Get-Item -LiteralPath $PluginDirectory
    $HomeFull = [System.IO.Path]::GetFullPath($NapCatHome).TrimEnd('\')
    while ($Current -and $Current.FullName.StartsWith($HomeFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path -LiteralPath (Join-Path $Current.FullName "NapCatWinBootMain.exe") -PathType Leaf) {
            return $Current.FullName
        }
        $Current = $Current.Parent
    }
    return $null
}

function Find-QqExecutable {
    param([string]$ShellRoot, [string]$PluginDirectory)
    if (-not [string]::IsNullOrWhiteSpace($PluginDirectory)) {
        $AppDir = Split-Path -Parent $PluginDirectory
        $ResourcesDir = Split-Path -Parent $AppDir
        $VersionDir = Split-Path -Parent $ResourcesDir
        $VersionQq = Join-Path $VersionDir "QQ.exe"
        if (Test-Path -LiteralPath $VersionQq -PathType Leaf) {
            return (Get-Item -LiteralPath $VersionQq).FullName
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($ShellRoot)) {
        $Qq = Get-ChildItem -LiteralPath $ShellRoot -Recurse -File -Filter "QQ.exe" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        if ($Qq) { return $Qq.FullName }
    }
    return ""
}

function New-EmptyLoginInfo {
    return [ordered]@{
        apiAvailable = $false
        isLogin = $false
        isOffline = $false
        uid = ""
        uin = ""
        nick = ""
        online = $null
        avatarUrl = $null
        loginError = $null
        qrcodeUrl = $null
        error = $null
    }
}

function Get-Sha256Text {
    param([string]$Text)
    $Sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return -join ($Sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") })
    }
    finally {
        $Sha.Dispose()
    }
}

function Invoke-WebuiPost {
    param(
        [string]$BaseUrl,
        [string]$Path,
        [object]$Payload,
        [string]$Credential = ""
    )
    $Headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($Credential)) {
        $Headers["Authorization"] = "Bearer $Credential"
    }
    $Body = $Payload | ConvertTo-Json -Depth 8 -Compress
    return Invoke-RestMethod -Uri "$BaseUrl$Path" -Method Post -Headers $Headers -ContentType "application/json" -Body $Body -TimeoutSec 3
}

function Get-LoginInfo {
    param([string]$WebuiUrl, [string]$Token)
    $Login = New-EmptyLoginInfo
    if ($NoLogin) { return $Login }
    if ([string]::IsNullOrWhiteSpace($WebuiUrl)) {
        $Login.error = "WebUI URL is not available"
        return $Login
    }
    if ([string]::IsNullOrWhiteSpace($Token)) {
        $Login.error = "WebUI token is not available"
        return $Login
    }
    try {
        $BaseUrl = $WebuiUrl.Split("/webui", 2)[0]
        $Digest = Get-Sha256Text -Text "$Token.napcat"
        $Auth = Invoke-WebuiPost -BaseUrl $BaseUrl -Path "/api/auth/login" -Payload @{ hash = $Digest }
        if ($Auth.code -ne 0) {
            throw ($Auth.message | Out-String)
        }
        $Credential = [string]$Auth.data.Credential
        if ([string]::IsNullOrWhiteSpace($Credential)) {
            throw "WebUI did not return a Credential"
        }
        $StatusResult = Invoke-WebuiPost -BaseUrl $BaseUrl -Path "/api/QQLogin/CheckLoginStatus" -Payload @{} -Credential $Credential
        $InfoResult = Invoke-WebuiPost -BaseUrl $BaseUrl -Path "/api/QQLogin/GetQQLoginInfo" -Payload @{} -Credential $Credential
        $StatusData = $StatusResult.data
        $InfoData = $InfoResult.data
        $Login.apiAvailable = $true
        $Login.isLogin = [bool]$StatusData.isLogin
        $Login.isOffline = [bool]$StatusData.isOffline
        $Login.uid = [string]$InfoData.uid
        $Login.uin = [string]$InfoData.uin
        $Login.nick = [string]$InfoData.nick
        $Login.online = if ($null -ne $InfoData.online) { [bool]$InfoData.online } else { $null }
        $Login.avatarUrl = if ($InfoData.avatarUrl) { [string]$InfoData.avatarUrl } else { $null }
        $Login.loginError = if ($StatusData.loginError) { [string]$StatusData.loginError } else { $null }
        $Login.qrcodeUrl = if ($StatusData.qrcodeurl) { [string]$StatusData.qrcodeurl } else { $null }
    }
    catch {
        $Login.error = $_.Exception.Message
    }
    return $Login
}

$PluginEntry = Find-NapCatPluginEntry
$PluginDir = if ($PluginEntry) { Split-Path -Parent $PluginEntry } else { Join-Path $DefaultInstallBaseDir "opt\QQ\resources\app\app_launcher\napcat" }
$ShellRoot = Find-ShellRoot -PluginDirectory $PluginDir
$InstallBaseDir = if ($ShellRoot) { $ShellRoot } else { $DefaultInstallBaseDir }
$QqExecutable = Find-QqExecutable -ShellRoot $ShellRoot -PluginDirectory $PluginDir
$WebuiConfig = Join-Path $PluginDir "config\webui.json"
$QrcodePath = Join-Path $PluginDir "cache\qrcode.png"
$LaunchKind = if ($PluginEntry -and $ShellRoot) { "windowsShell" } elseif ($PluginEntry) { "windowsPlugin" } else { "missing" }

$Webui = $null
$WebuiError = $null
if (Test-Path -LiteralPath $WebuiConfig -PathType Leaf) {
    try {
        $Webui = Get-Content -LiteralPath $WebuiConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        $WebuiError = "Failed to read webui.json: $($_.Exception.Message)"
    }
}
else {
    $WebuiError = "webui.json does not exist"
}

$HostValue = if ($Webui -and $Webui.host) { [string]$Webui.host } else { "" }
$PortValue = if ($Webui -and $Webui.port) { [int]$Webui.port } else { $null }
$TokenValue = if ($Webui -and $Webui.token) { [string]$Webui.token } else { "" }
$BrowserHost = if ($HostValue -eq "" -or $HostValue -eq "::" -or $HostValue -eq "0.0.0.0" -or $HostValue -eq "[::]") { "127.0.0.1" } else { $HostValue.Trim("[", "]") }
$WebuiUrl = ""
if ($PortValue) {
    $WebuiUrl = "http://$BrowserHost`:$PortValue/webui"
    if ($TokenValue) { $WebuiUrl = "$WebuiUrl`?token=$TokenValue" }
}

$MonPmStatus = Get-MonPmStatus
if ($LaunchKind -eq "missing") {
    $Status = "notInstalled"
}
elseif ($WebuiError) {
    $Status = "missingConfig"
}
elseif ($MonPmStatus -eq "running") {
    $Status = "running"
}
elseif ($MonPmStatus -eq "missing" -or $MonPmStatus -eq "stopped") {
    $Status = "notRunning"
}
else {
    $Status = "unknown"
}

$Payload = [ordered]@{
    status = $Status
    monpmName = $MonPmName
    monpmStatus = $MonPmStatus
    launchKind = $LaunchKind
    runtimeRoot = [string]$NapCatHome
    installBaseDir = [string]$InstallBaseDir
    pluginDir = [string]$PluginDir
    qqExecutable = [string]$QqExecutable
    webui = [ordered]@{
        configPath = [string]$WebuiConfig
        configExists = (Test-Path -LiteralPath $WebuiConfig -PathType Leaf)
        host = $HostValue
        port = $PortValue
        token = $TokenValue
        url = $WebuiUrl
        modifiedAt = Get-ModifiedAt -Path $WebuiConfig
        error = $WebuiError
    }
    qrcode = [ordered]@{
        path = [string]$QrcodePath
        exists = (Test-Path -LiteralPath $QrcodePath -PathType Leaf)
        modifiedAt = Get-ModifiedAt -Path $QrcodePath
        dataUrl = Get-QrcodeDataUrl -Path $QrcodePath
    }
    login = Get-LoginInfo -WebuiUrl $WebuiUrl -Token $TokenValue
}

if ($Pretty) {
    $Payload | ConvertTo-Json -Depth 8
}
else {
    $Payload | ConvertTo-Json -Depth 8 -Compress
}
