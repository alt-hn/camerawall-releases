#!/usr/bin/env python3
"""Inspect the actual ISO's boot files, runtime payload and SHA-256 manifest."""
import hashlib, json, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT/'dist'
info = json.loads((OUT/'BUILD-INFO.json').read_text())
iso = OUT/'camerawall-usb-v0.2.0-amd64.iso'
h = hashlib.sha256()
with iso.open('rb') as f:
    for block in iter(lambda:f.read(1024*1024), b''):
        h.update(block)
assert h.hexdigest() == info['iso_sha256']
with tempfile.TemporaryDirectory(prefix='cw-verify-') as directory:
    directory = pathlib.Path(directory)
    def extract(image, remote, local):
        subprocess.run(['xorriso','-osirrox','on','-indev',str(image),'-extract',remote,str(local)],check=True,capture_output=True)
    payload = directory/'payload'
    extract(iso,'/camerawall',payload)
    for name in ('preseed.cfg','select-disk.sh','late-install.sh','bootstrap.sh', 'console-ready.sh', 'camerawall-console.service','provision-analytics.py','analytics-downloads.json','release.env','camerawall-firstboot.service','LICENSE'):
        assert (payload/name).read_bytes() == (ROOT/'usb'/name).read_bytes(), name
    assert (payload/'USB-INSTALL-VI.md').read_bytes() == (ROOT/'docs/USB-INSTALL-VI.md').read_bytes()
    assert 'commit='+info['installer_source_commit'] in (payload/'INSTALLER-SOURCE.txt').read_text()
    for name in ('/boot/grub/efi.img','/install.amd/vmlinuz','/install.amd/initrd.gz'):
        a,b = directory/'original',directory/'custom'
        extract(ROOT/'.cache/debian-12.15.0-amd64-netinst.iso',name,a)
        extract(iso,name,b)
        assert a.read_bytes() == b.read_bytes(), name
        a.unlink(); b.unlink()
    for name,source in (('/boot/grub/grub.cfg','grub.cfg'),('/isolinux/isolinux.cfg','isolinux.cfg')):
        local = directory/source
        extract(iso,name,local)
        assert local.read_bytes() == (ROOT/'usb'/source).read_bytes()
print('PASS ISO SHA-256, exact runtime payload/source, unchanged Debian EFI/kernel/initrd and guarded menus')
