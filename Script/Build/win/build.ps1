param([string]$Python = 'python', [string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..\..\..").Path
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'dist' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$buildVenv = Join-Path $root 'build\bot-venv'
& $Python -m venv $buildVenv
if ($LASTEXITCODE -ne 0) { throw 'Build venv creation failed' }
$py = Join-Path $buildVenv 'Scripts\python.exe'
# Install declared dependencies without the legacy pyproject wheel package path.
& $py -m pip install 'pyinstaller>=6,<7' 'nonebot2[fastapi,aiohttp]>=2.0.0' 'nonebot-adapter-onebot>=2.0.0' 'websockets>=11.0.0' 'aiohttp>=3.8.0' 'aiofiles>=23.0.0' 'rich>=13.0.0' 'psutil>=5.9.0'
if ($LASTEXITCODE -ne 0) { throw 'Build dependency installation failed' }
$env:PYTHONPATH = Join-Path $root 'BotCore'
$env:PYTHONUTF8 = '1'
& $py -m PyInstaller --noconfirm --distpath $OutputDirectory --workpath (Join-Path $root 'build\pyinstaller') "$PSScriptRoot\eden-bot.spec"
if ($LASTEXITCODE -ne 0) { throw 'PyInstaller failed' }
$bundle = Join-Path $OutputDirectory 'eden-bot'
Copy-Item "$PSScriptRoot\bot.monconfig" "$bundle\.monconfig" -Force
New-Item -ItemType Directory -Force "$bundle\Config" | Out-Null
& "$bundle\eden-bot.exe" --self-test
if ($LASTEXITCODE -ne 0) { throw 'Frozen application self-test failed' }
& $py -m pip freeze | Out-File "$bundle\build-requirements.txt" -Encoding utf8
Write-Host "Windows QQBot bundle: $bundle"
