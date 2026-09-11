from pathlib import Path
from PyInstaller.utils.hooks import collect_all, collect_submodules

root = Path(SPECPATH).resolve().parents[2]
core = root / 'BotCore'
datas, binaries, hiddenimports = [], [], []
for package in ('nonebot', 'nonebot.adapters.onebot', 'aiohttp', 'websockets', 'rich'):
    data, binary, hidden = collect_all(package)
    datas += data
    binaries += binary
    hiddenimports += hidden
# NoneBot drivers and local plugins are imported dynamically.
hiddenimports += collect_submodules('nonebot.drivers')
# Plugin imports require nonebot.init(), so hook-time import discovery cannot
# enumerate these modules reliably. Derive names from source without executing.
for source in (core / 'src').rglob('*.py'):
    if '__pycache__' in source.parts:
        continue
    module = source.relative_to(core).with_suffix('')
    if module.name == '__init__':
        module = module.parent
    hiddenimports.append('.'.join(module.parts))
a = Analysis([str(core / 'bot.py')], pathex=[str(core)], datas=datas,
             binaries=binaries, hiddenimports=sorted(set(hiddenimports)),
             module_collection_mode={'src': 'pyz+py'},
             excludes=['pytest', 'watchfiles', 'IPython', 'numpy', 'matplotlib', 'pandas', 'tkinter'], noarchive=False)
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name='eden-bot',
          console=True, strip=False, upx=False)
coll = COLLECT(exe, a.binaries, a.datas, name='eden-bot', strip=False, upx=False)
