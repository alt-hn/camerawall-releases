"""Build on each native OS/architecture; never runs the privileged writer."""
import json
from pathlib import Path
import platform
import plistlib
import re
import subprocess
import sys

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'image.json').read_text())
assert manifest['mode'] == 'offline'
sources = json.loads((root / 'offline/sources.json').read_text())
assert all(re.fullmatch('[a-f0-9]{64}', item['sha256']) for item in [sources['debian'], sources['application'], *sources['analytics']])
args = [sys.executable, '-m', 'PyInstaller', '--noconfirm', '--clean', '--windowed', '--name', 'CameraWall USB Creator', '--distpath', str(root.parent / 'dist' / 'creator'), '--workpath', str(root.parent / '.cache' / 'creator-build'), '--specpath', str(root.parent / '.cache'), '--add-data', f'{root / "image.json"}:.', '--add-data', f'{root / "offline"}:offline', '--osx-bundle-identifier', 'com.alitasoft.camerawall.usbcreator']
for package in ('pyfatfs', 'pycdlib', 'fs', 'certifi', 'six', 'appdirs'):
    args += ['--copy-metadata', package]
args += ['--add-data', f'{root / "THIRD-PARTY-NOTICES.txt"}:.', '--add-data', f'{root / "LICENSE"}:.']
for name in ('select-disk.sh', 'root-service.conf', 'release.env', 'provision-analytics.py', 'analytics-downloads.json', 'camerawall-console.service', 'console-ready.sh', 'camerawall-firstboot.service'):
    args += ['--add-data', f'{root.parent / "usb" / name}:usb-runtime']
if platform.system() == 'Windows':
    args += ['--onefile']
else:
    args += ['--onedir']
subprocess.run(args + [str(root / 'app.py')], check=True)

if platform.system() == 'Darwin':
    app = root.parent / 'dist/creator/CameraWall USB Creator.app'
    info = app / 'Contents/Info.plist'
    settings = plistlib.loads(info.read_bytes())
    settings['NSRemovableVolumesUsageDescription'] = 'CameraWall cần truy cập USB bạn chọn để tạo bộ cài bootable và kiểm tra dữ liệu sau khi ghi.'
    info.write_bytes(plistlib.dumps(settings))
    # Updating Info.plist invalidates PyInstaller's local ad-hoc signature.
    subprocess.run(['/usr/bin/codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
