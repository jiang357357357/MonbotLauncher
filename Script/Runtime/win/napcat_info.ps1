param(
    [switch]$NoImage,
    [switch]$Pretty
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../../..")
$NapCatHome = if ($env:MON_NAPCAT_HOME) { $env:MON_NAPCAT_HOME } else { Join-Path $ProjectRoot "napcat" }
$InstallBaseDir = if ($env:MON_NAPCAT_INSTALL_BASE_DIR) { $env:MON_NAPCAT_INSTALL_BASE_DIR } else { Join-Path $NapCatHome "Napcat" }
$PluginDir = Join-Path $InstallBaseDir "opt/QQ/resources/app/app_launcher/napcat"
$WebuiConfig = Join-Path $PluginDir "config/webui.json"
$QrcodePath = Join-Path $PluginDir "cache/qrcode.png"
$Pm2Name = if ($env:MON_NAPCAT_PM2_NAME) { $env:MON_NAPCAT_PM2_NAME } else { "napcat" }

function Get-ModifiedAt {
    param([string]$Path)
    if (-not (Test-Path -Path $Path)) {
        return $null
    }
    return (Get-Item -Path $Path).LastWriteTime.ToString("s")
}

function Get-QrcodeDataUrl {
    param([string]$Path)
    if ($NoImage -or -not (Test-Path -Path $Path)) {
        return $null
    }
    $Bytes = [System.IO.File]::ReadAllBytes($Path)
    return "data:image/png;base64,$([Convert]::ToBase64String($Bytes))"
}

function Get-Pm2Status {
    try {
        $Pm2 = Get-Command pm2 -ErrorAction SilentlyContinue
        if (-not $Pm2) {
            return "unknown"
        }
        $Json = & pm2 jlist
        $Apps = $Json | ConvertFrom-Json
        $App = $Apps | Where-Object { $_.name -eq $Pm2Name } | Select-Object -First 1
        if (-not $App) {
            return "missing"
        }
        return $App.pm2_env.status
    }
    catch {
        return "unknown"
    }
}

$Webui = @{}
$WebuiError = $null
if (Test-Path -Path $WebuiConfig) {
    try {
        $Webui = Get-Content -Path $WebuiConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        $WebuiError = "读取 webui.json 失败: $($_.Exception.Message)"
    }
}
else {
    $WebuiError = "webui.json 不存在"
}

$HostValue = if ($Webui.host) { [string]$Webui.host } else { "" }
$PortValue = $Webui.port
$TokenValue = if ($Webui.token) { [string]$Webui.token } else { "" }
$BrowserHost = if ($HostValue -eq "" -or $HostValue -eq "::" -or $HostValue -eq "0.0.0.0" -or $HostValue -eq "[::]") { "127.0.0.1" } else { $HostValue.Trim("[", "]") }
$WebuiUrl = ""
if ($PortValue) {
    $WebuiUrl = "http://$BrowserHost`:$PortValue/webui"
    if ($TokenValue) {
        $WebuiUrl = "$WebuiUrl`?token=$TokenValue"
    }
}

$Pm2Status = Get-Pm2Status
$LaunchKind = if (Test-Path -Path (Join-Path $PluginDir "napcat.mjs")) { "shell" } else { "missing" }
if ($LaunchKind -eq "missing") {
    $Status = "notInstalled"
}
elseif ($WebuiError) {
    $Status = "missingConfig"
}
elseif ($Pm2Status -eq "online") {
    $Status = "running"
}
elseif ($Pm2Status -eq "missing") {
    $Status = "notRunning"
}
else {
    $Status = "unknown"
}

$Payload = [ordered]@{
    status = $Status
    pm2Name = $Pm2Name
    pm2Status = $Pm2Status
    launchKind = $LaunchKind
    runtimeRoot = [string]$NapCatHome
    installBaseDir = [string]$InstallBaseDir
    pluginDir = [string]$PluginDir
    qqExecutable = [string](Join-Path $InstallBaseDir "opt/QQ/qq")
    webui = [ordered]@{
        configPath = [string]$WebuiConfig
        configExists = (Test-Path -Path $WebuiConfig)
        host = $HostValue
        port = $PortValue
        token = $TokenValue
        url = $WebuiUrl
        modifiedAt = Get-ModifiedAt -Path $WebuiConfig
        error = $WebuiError
    }
    qrcode = [ordered]@{
        path = [string]$QrcodePath
        exists = (Test-Path -Path $QrcodePath)
        modifiedAt = Get-ModifiedAt -Path $QrcodePath
        dataUrl = Get-QrcodeDataUrl -Path $QrcodePath
    }
}

$Depth = 8
if ($Pretty) {
    $Payload | ConvertTo-Json -Depth $Depth
}
else {
    $Payload | ConvertTo-Json -Depth $Depth -Compress
}
