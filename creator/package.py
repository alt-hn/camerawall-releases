import hashlib
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
label = sys.argv[1]
out = root / 'dist' / 'creator-packages'
out.mkdir(parents=True, exist_ok=True)
name = 'CameraWall-USB-Creator-1.0.0-' + label
if platform.system() == 'Windows':
    source = root / 'dist/creator/CameraWall USB Creator.exe'
    target = out / (name + '.exe')
    shutil.copy2(source, target)
else:
    source = root / 'dist/creator/CameraWall USB Creator.app'
    target = out / (name + '.zip')
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(source), str(target)], check=True)
info = {'file': target.name, 'size': target.stat().st_size, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'source': subprocess.check_output(['git','rev-parse','HEAD'], cwd=root, text=True).strip(), 'os': platform.platform(), 'arch': platform.machine(), 'python': platform.python_version(), 'image': json.loads((root / 'creator/image.json').read_text()), 'signed': False}
(out / (name + '.json')).write_text(json.dumps(info, indent=2) + '\n')
print(json.dumps(info, indent=2))
