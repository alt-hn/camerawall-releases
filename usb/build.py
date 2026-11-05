#!/usr/bin/env python3
"""Build an ISO-hybrid USB image, retaining official Debian EFI boot binaries."""
import hashlib, json, os, pathlib, shutil, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
os.chdir(ROOT)
CACHE = ROOT / '.cache'
OUT = ROOT / 'dist'
VERSION = 'usb-v0.2.0'
DEBIAN = '12.15.0'
FINGERPRINT = 'DF9B9C49EAA9298432589D76DA87E80D6294BE9B'
ISO = f'debian-{DEBIAN}-amd64-netinst.iso'
BASE = f'https://cdimage.debian.org/cdimage/archive/{DEBIAN}/amd64/iso-cd'

def run(*args, **kw):
    return subprocess.run(args, check=True, **kw)

def sha(path):
    with open(path, 'rb') as f:
        h = hashlib.sha256()
        for chunk in iter(lambda: f.read(1024*1024), b''):
            h.update(chunk)
        return h.hexdigest()

def download(name, local):
    path = CACHE / local
    if not path.exists():
        run('curl', '--proto', '=https', '--proto-redir', '=https', '-fL', '--retry', '5', '-C', '-', '-o', str(path)+'.part', BASE+'/'+name)
        pathlib.Path(str(path)+'.part').rename(path)
    return path

for command in ('curl', 'gpg', 'xorriso'):
    if not shutil.which(command):
        raise SystemExit(f'Missing build tool: {command}')
CACHE.mkdir(exist_ok=True)
OUT.mkdir(exist_ok=True)
original = download(ISO, ISO)
sums = download('SHA256SUMS', 'debian-SHA256SUMS')
sig = download('SHA256SUMS.sign', 'debian-SHA256SUMS.sign')
with tempfile.TemporaryDirectory(prefix='cw-gpg-') as home:
    run('gpg', '--homedir', home, '--batch', '--import', str(ROOT/'usb/debian-cd-key.asc'), capture_output=True)
    result = run('gpg', '--homedir', home, '--batch', '--status-fd', '1', '--verify', str(sig), str(sums), capture_output=True, text=True)
    if '[GNUPG:] VALIDSIG '+FINGERPRINT+' ' not in result.stdout:
        raise SystemExit('Unexpected Debian CD signer')
    (OUT/'DEBIAN-SIGNATURE.txt').write_text(result.stdout + result.stderr)
expected = [line.split()[0] for line in sums.read_text().splitlines() if line.split()[-1] == ISO]
assert len(expected) == 1 and sha(original) == expected[0], 'Debian ISO checksum mismatch'
output = OUT / f'camerawall-{VERSION}-amd64.iso'
if output.exists():
    raise SystemExit(f'Refusing to replace {output}; preserve/remove intentionally before rebuilding')
# Stage only runtime files; never put build caches or local files in the ISO.
with tempfile.TemporaryDirectory(prefix='cw-iso-') as stage:
    stage = pathlib.Path(stage)
    payload = stage / 'camerawall'
    payload.mkdir()
    names = ('preseed.cfg', 'select-disk.sh', 'late-install.sh', 'bootstrap.sh', 'console-ready.sh', 'camerawall-console.service',
             'provision-analytics.py', 'analytics-downloads.json', 'release.env', 'camerawall-firstboot.service', 'LICENSE')
    for name in names:
        shutil.copy2(ROOT/'usb'/name, payload/name)
    shutil.copy2(ROOT/'docs/USB-INSTALL-VI.md', payload/'USB-INSTALL-VI.md')
    commit = run('git','rev-parse','HEAD',capture_output=True,text=True).stdout.strip()
    (payload/'INSTALLER-SOURCE.txt').write_text('https://github.com/alt-hn/camerawall-releases\ncommit='+commit+'\n')
    original_md5 = stage/'original-md5sum.txt'
    run('xorriso', '-osirrox', 'on', '-indev', str(original), '-extract', '/md5sum.txt', str(original_md5), capture_output=True)
    mappings = { './boot/grub/grub.cfg': ROOT/'usb/grub.cfg',
                 './isolinux/isolinux.cfg': ROOT/'usb/isolinux.cfg' }
    mappings.update({'./camerawall/'+p.name:p for p in payload.iterdir()})
    md5lines = [line for line in original_md5.read_text().splitlines()
                if line.split()[-1] not in mappings]
    md5lines += [hashlib.md5(p.read_bytes()).hexdigest()+'  '+name for name,p in mappings.items()]
    md5 = stage/'md5sum.txt'
    md5.write_text('\n'.join(md5lines)+'\n')
    # Replay keeps the official signed kernel, shim, GRUB and hybrid USB/EFI layout.
    run('xorriso', '-indev', str(original), '-outdev', str(output),
        '-boot_image', 'any', 'replay', '-volid', 'CAMERAWALL_USB_020',
        '-map', str(payload), '/camerawall',
        '-map', str(ROOT/'usb/grub.cfg'), '/boot/grub/grub.cfg',
        '-map', str(ROOT/'usb/isolinux.cfg'), '/isolinux/isolinux.cfg',
        '-map', str(md5), '/md5sum.txt', '-commit', '-end')
report = run('xorriso', '-indev', str(output), '-report_el_torito', 'plain', '-report_system_area', 'plain', capture_output=True, text=True)
(OUT/'BOOT-LAYOUT.txt').write_text(report.stdout + report.stderr)
assert 'UEFI' in report.stdout+report.stderr and 'GPT' in report.stdout+report.stderr
metadata = dict(installer_version=VERSION, installer_source_commit=run('git','rev-parse','HEAD',capture_output=True,text=True).stdout.strip(),
                source_tree_clean=not run('git','status','--porcelain',capture_output=True,text=True).stdout,
                debian_version=DEBIAN, debian_url=BASE+'/'+ISO, debian_sha256=expected[0],
                debian_signer=FINGERPRINT, iso_sha256=sha(output),
                analytics_downloads=json.loads((ROOT/'usb/analytics-downloads.json').read_text()),
                camerawall=dict(line.split('=',1) for line in (ROOT/'usb/release.env').read_text().splitlines()))
(OUT/'BUILD-INFO.json').write_text(json.dumps(metadata, indent=2)+'\n')
(OUT/'SHA256SUMS').write_text(f'{sha(output)}  {output.name}\n')
print(json.dumps(metadata,indent=2))
