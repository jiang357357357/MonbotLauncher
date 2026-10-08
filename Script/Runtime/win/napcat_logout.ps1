$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
. (Join-Path $ProjectRoot 'Script\Process\win\napcat_common.ps1')

# Verify the managed runtime before changing its login settings.
Initialize-NapCatMonPmConfig
$Entry = Get-NapCatPluginEntry
if (-not $Entry) { throw 'NapCat runtime is not installed.' }
$ConfigPath = Join-Path (Split-Path -Parent $Entry) 'config\webui.json'
$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$HostValue = [string]$Config.host
if ($HostValue -in @('', '::', '0.0.0.0', '[::]')) { $HostValue = '127.0.0.1' }
if ($HostValue.Contains(':') -and -not $HostValue.StartsWith('[')) { $HostValue = "[$HostValue]" }
if (-not $Config.port -or -not $Config.token) { throw 'NapCat WebUI port/token is missing.' }
$BaseUrl = "http://$HostValue`:$($Config.port)"
$Sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $Digest = -join ($Sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$($Config.token).napcat")) |
        ForEach-Object { $_.ToString('x2') })
}
finally { $Sha.Dispose() }
$Auth = Invoke-RestMethod -Uri "$BaseUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{ hash = $Digest } | ConvertTo-Json -Compress) -TimeoutSec 5
if ($Auth.code -ne 0 -or -not $Auth.data.Credential) { throw 'NapCat WebUI authentication failed.' }
$Headers = @{ Authorization = "Bearer $($Auth.data.Credential)" }
$Result = Invoke-RestMethod -Uri "$BaseUrl/api/QQLogin/SetQuickLoginQQ" -Method Post -Headers $Headers -ContentType 'application/json' -Body '{"uin":""}' -TimeoutSec 5
if ($Result.code -ne 0) { throw 'Could not clear NapCat quick login.' }
Invoke-NapCatMonPm -Action restart
Write-Output '[NAPCAT_LOGOUT:RESTARTED_FOR_LOGIN]'
