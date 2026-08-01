# MonBot environment removal script (PowerShell)

param(
    [switch]$NoWait
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = $PSScriptRoot
$ProjectRoot = (Get-Item "$ScriptRoot\..\..\..").FullName

Push-Location $ProjectRoot

$PathsToRemove = @(".venv", ".python-version", "uv.lock")
$Removed = 0

foreach ($Path in $PathsToRemove) {
    if (Test-Path $Path) {
        Remove-Item -Recurse -Force $Path
        Write-Host "[OK] Removed: $Path" -ForegroundColor Green
        $Removed++
    }
}

Get-ChildItem -Recurse -Force -Filter "__pycache__" -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Recurse -Force -Include "*.pyc","*.pyo" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

if ($Removed -gt 0) {
    Write-Host "[REMOVE_STATUS:SUCCESS]" -ForegroundColor Green
} else {
    Write-Host "[REMOVE_STATUS:NOTHING]" -ForegroundColor Yellow
}

Pop-Location
