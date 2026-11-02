#!/usr/bin/env python3
"""Provision the alpha.29 offline CPU analytics runtime from hash-pinned upstream files."""
import hashlib, json, pathlib, shutil, subprocess
BASE = pathlib.Path('/usr/local/lib/camerawall-usb')
CACHE = pathlib.Path('/var/lib/camerawall-usb/analytics-downloads')
TARGET = pathlib.Path('/opt/camerawall/analytics')
CACHE.mkdir(parents=True,exist_ok=True)
(TARGET/'models').mkdir(parents=True,exist_ok=True)
(TARGET/'licenses').mkdir(exist_ok=True)
# bootstrap's umask is private for credentials; model/venv directories must be
# traversable by the unprivileged camerawall worker.
TARGET.chmod(0o755)
(TARGET/'models').chmod(0o755)
(TARGET/'licenses').chmod(0o755)

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):
            h.update(chunk)
    return h.hexdigest()

items=json.loads((BASE/'analytics-downloads.json').read_text())
wheels=[]
for item in items:
    path=CACHE/item['name']
    if not path.exists() or sha(path)!=item['sha256']:
        partial=path.with_name(path.name+'.part')
        command=['curl','--proto','=https','--proto-redir','=https','--tlsv1.2','-fL','--connect-timeout','30','--max-time','1200','--retry','5','--retry-all-errors','--retry-delay','5','-o',str(partial)]
        if subprocess.run(command+['-C','-',item['url']]).returncode:
            subprocess.run(command+[item['url']],check=True)
        if sha(partial)!=item['sha256']:
            partial.unlink()
            raise SystemExit('Checksum mismatch; file not installed: '+item['name'])
        partial.replace(path)
    print('Verified '+item['name'],flush=True)
    if item['kind']=='wheel':
        wheels.append(str(path))
    else:
        destination=TARGET/('models' if item['kind']=='model' else 'licenses')/item['name']
        shutil.copyfile(path,destination)
        destination.chmod(0o644)
# Use only downloaded and verified wheels, with no dependency resolver/network.
import os
os.umask(0o022)
subprocess.run(['python3','-m','venv',str(TARGET/'.venv')],check=True)
python=str(TARGET/'.venv/bin/python')
subprocess.run([python,'-m','pip','--isolated','--disable-pip-version-check','install','--no-index','--no-deps',*wheels],check=True)
subprocess.run([python,'-m','pip','--isolated','--disable-pip-version-check','check'],check=True)
subprocess.run([python,'-c', '''import cv2,numpy
assert cv2.__version__=='4.12.0' and numpy.__version__=='2.0.2'
base='/opt/camerawall/analytics/models/'
cv2.FaceDetectorYN.create(base+'yunet.onnx','',(640,360))
cv2.FaceRecognizerSF.create(base+'sface.onnx','')
cv2.dnn.readNetFromONNX(base+'object_detection_yolox_2022nov.onnx')
print('PASS offline OpenCV, NumPy, YuNet, SFace and YOLOX model load')
'''],check=True)
shutil.copyfile(BASE/'analytics-downloads.json',TARGET/'DOWNLOAD-PROVENANCE.json')
(TARGET/'DOWNLOAD-PROVENANCE.json').chmod(0o644)
