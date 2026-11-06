"""Build on each native OS/architecture; never runs the privileged writer."""
import json
from pathlib import Path
import platform
import re
import subprocess
import sys

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'image.json').read_text())
assert re.fullmatch('[a-f0-9]{64}', manifest['sha256']) and manifest['size'] > 0, 'Pin a verified released ISO before packaging'
args = [sys.executable, '-m', 'PyInstaller', '--noconfirm', '--clean', '--windowed', '--name', 'CameraWall USB Creator', '--distpath', str(root.parent / 'dist' / 'creator'), '--workpath', str(root.parent / '.cache' / 'creator-build'), '--specpath', str(root.parent / '.cache'), '--add-data', f'{root / "image.json"}:.', '--osx-bundle-identifier', 'com.alitasoft.camerawall.usbcreator']
if platform.system() == 'Windows':
    args += ['--onefile']
else:
    args += ['--onedir']
subprocess.run(args + [str(root / 'app.py')], check=True)
