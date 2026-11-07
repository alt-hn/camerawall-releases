"""Compose an offline bootable USB locally from verified upstream components.

No custom ISO is downloaded/published. The official Debian hybrid boot layout is
retained, its menu patched in place, and a FAT payload partition appended.
"""
import concurrent.futures
import gzip
import hashlib
import io
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import struct
import tarfile
import uuid
import zlib
import pycdlib
from pyfatfs.PyFat import PyFat
from pyfatfs.PyFatFS import PyFatFS
from core import download, sha256

SECTOR = 512
MIB = 1024 * 1024
RUNTIME = ('select-disk.sh', 'root-service.conf', 'install-display-runtime.sh', 'install-host-runtime.sh', 'provision-analytics.py', 'analytics-downloads.json', 'camerawall-console.service', 'console-ready.sh', 'camerawall-firstboot.service')


def runtime_files(root):
    # In a frozen app only these runtime files are bundled, never build caches.
    runtime = root / 'usb-runtime'
    if not runtime.exists():
        runtime = root.parent / 'usb'
    files = {'camerawall/' + name: (runtime / name).read_bytes() for name in RUNTIME}
    for name in ('mount-media.sh', 'late-install.sh', 'offline-bootstrap.sh'):
        files['camerawall/' + name] = (root / 'offline' / name).read_bytes()
    files['usr/lib/apt-setup/generators/02camerawall'] = (root / 'offline/apt-generator.sh').read_bytes()
    files['preseed.cfg'] = (root / 'offline/preseed.cfg').read_bytes()
    files['camerawall/camerawall-firstboot.service'] = files['camerawall/camerawall-firstboot.service'].replace(b'Download and install latest CameraWall release (Internet needed once)', b'Install cached CameraWall offline').replace(b'Wants=network-online.target\nAfter=network-online.target', b'After=network.target')
    files['camerawall/console-ready.sh'] = files['camerawall/console-ready.sh'].replace(b'CameraWall READY: http://%s', b'CameraWall READY (connect Ethernet for LAN access): http://%s')
    return files


def initramfs(files):
    out = bytearray()
    def add(name, data, mode, inode):
        encoded = name.encode() + b'\0'
        values = [inode, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(encoded), 0]
        out.extend(b'070701' + ''.join(f'{v:08x}' for v in values).encode())
        out.extend(encoded)
        out.extend(b'\0' * (-len(out) % 4))
        out.extend(data)
        out.extend(b'\0' * (-len(out) % 4))
    directories = {str(parent) for name in files for parent in Path(name).parents if str(parent) != '.'}
    for index, name in enumerate(sorted(directories, key=lambda p: (p.count('/'), p)), 1):
        add(name, b'', 0o40755, index)
    for index, (name, data) in enumerate(sorted(files.items()), len(directories) + 1):
        add(name, data, 0o100755 if name.endswith('.sh') or '/generators/' in name else 0o100644, index)
    add('TRAILER!!!', b'', 0, len(files) + len(directories) + 1)
    return gzip.compress(bytes(out), mtime=0)


def control_from_deb(path):
    with open(path, 'rb') as f:
        if f.read(8) != b'!<arch>\n':
            raise ValueError('Invalid Debian package')
        while header := f.read(60):
            if len(header) != 60 or header[-2:] != b'`\n':
                raise ValueError('Invalid ar header')
            name = header[:16].decode().strip().rstrip('/')
            size = int(header[48:58])
            data = f.read(size)
            if len(data) != size:
                raise ValueError('Truncated Debian package')
            if size % 2:
                f.read(1)
            if name.startswith('control.tar'):
                with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as t:
                    for member in t.getmembers():
                        if member.name in ('control', './control'):
                            return t.extractfile(member).read().decode().strip()
    raise ValueError('Missing Debian package control')


def package_index(packages, paths):
    entries = []
    for item in packages:
        control = control_from_deb(paths[item['sha256']])
        entries.append(control + f"\nFilename: pool/{item['name']}\nSize: {item['size']}\nSHA256: {item['sha256']}\n")
    return ('\n'.join(entries) + '\n').encode()


def patch_file(image, relative, payload):
    iso = pycdlib.PyCdlib()
    iso.open(str(image))
    try:
        record = iso.get_record(rr_path=relative)
        extent, length = record.extent_location() * 2048, record.data_length
        if len(payload) > length:
            raise ValueError('Boot menu exceeds original ISO allocation')
    finally:
        iso.close()
    with open(image, 'r+b') as f:
        f.seek(extent)
        f.write(payload + b' ' * (length - len(payload)))


def gpt_append(image, start, length, total):
    """Extend the original signed-off hybrid layout; keep EFI/APM sectors intact."""
    with open(image, 'r+b') as f:
        f.seek(512)
        header = bytearray(f.read(512))
        if header[:8] != b'EFI PART':
            raise ValueError('Expected official Debian GPT hybrid image')
        header_size = struct.unpack_from('<I', header, 12)[0]
        entries_lba, count, entry_size = struct.unpack_from('<QII', header, 72)
        if not (92 <= header_size <= 512 and entry_size == 128 and count >= 3):
            raise ValueError('Unsupported Debian GPT layout')
        f.seek(entries_lba * SECTOR)
        entries = bytearray(f.read(count * entry_size))
        # Original image has precisely two occupied GPT entries. Refuse layout drift.
        if any(entries[2 * entry_size:]):
            raise ValueError('Unexpected occupied partition entry')
        entry = bytearray(entry_size)
        entry[:16] = uuid.UUID('EBD0A0A2-B9E5-4433-87C0-68B6B72699C7').bytes_le
        entry[16:32] = uuid.uuid4().bytes_le
        struct.pack_into('<QQQ', entry, 32, start, start + length - 1, 0)
        label = 'CWOFFLIN'.encode('utf-16le')
        entry[56:56+len(label)] = label
        entries[2*entry_size:3*entry_size] = entry
        sectors = math.ceil(len(entries) / SECTOR)
        last = total // SECTOR - 1
        if start + length - 1 >= last - sectors:
            raise ValueError('Payload overlaps backup GPT')
        struct.pack_into('<Q', header, 32, last)
        struct.pack_into('<Q', header, 48, last - sectors - 1)
        struct.pack_into('<I', header, 88, zlib.crc32(entries))
        def checksum(h):
            struct.pack_into('<I', h, 16, 0)
            struct.pack_into('<I', h, 16, zlib.crc32(h[:header_size]))
        checksum(header)
        f.seek(entries_lba * SECTOR)
        f.write(entries)
        f.seek(SECTOR)
        f.write(header)
        backup = bytearray(header)
        struct.pack_into('<QQ', backup, 24, last, 1)
        struct.pack_into('<Q', backup, 72, last - sectors)
        checksum(backup)
        f.seek((last - sectors) * SECTOR)
        f.write(entries)
        f.seek(last * SECTOR)
        f.write(backup)
        # Retain the Debian hybrid MBR boot code/EFI entry; add the data partition.
        f.seek(446 + 2*16)
        f.write(struct.pack('<B3sB3sII', 0, b'\xfe\xff\xff', 0x0c, b'\xfe\xff\xff', start, length))
        f.flush()
        os.fsync(f.fileno())


MENU = b'''insmod part_gpt
insmod fat
insmod ext2
set default=install
set timeout=3
set timeout_style=menu
if search --no-floppy --file --set=cwroot /camerawall-installed.marker; then
 set default=installed
 set timeout=10
 menuentry 'Boot installed CameraWall' --id installed {
  set root=$cwroot
  set prefix=($cwroot)/boot/grub
  set cw_installer_boot_arg=camerawall.installer_boot=1
  export cw_installer_boot_arg
  configfile ($cwroot)/boot/grub/grub.cfg
  halt
 }
fi
if search --no-floppy --label --set=cwdata CWOFFLIN; then
 menuentry 'CameraWall OFFLINE INSTALL - ERASE smallest non-boot disk' --id install {
  linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/preseed.cfg --- quiet
  initrd /install.amd/initrd.gz ($cwdata)/cw-initrd.gz
 }
else
 echo 'CameraWall payload missing. Installation is unavailable.'
 if [ "$default" = install ]; then
  halt
 fi
fi
menuentry 'Power off' { halt }
'''


def prepare(root, cache, progress=lambda *_: None):
    root, cache = Path(root), Path(cache)
    spec = json.loads((root / 'offline/sources.json').read_text())
    packages = json.loads((root / 'offline/debian-packages.json').read_text())
    runtime = root / 'usb-runtime'
    if not runtime.exists():
        runtime = root.parent / 'usb'
    resolver = importlib.util.spec_from_file_location('latest_release', runtime / 'latest-release.py')
    module = importlib.util.module_from_spec(resolver)
    resolver.loader.exec_module(module)
    version, app, display = module.latest_release()
    assets = list({item['sha256']: item for item in [spec['debian'], app, display, *spec['analytics'], *packages]}.values())
    cache.mkdir(parents=True, exist_ok=True)
    paths = {}
    total = sum(item['size'] for item in assets)
    complete = 0
    def fetch(item):
        return item, download(item, cache / 'downloads')
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for item, path in pool.map(fetch, assets):
            paths[item['sha256']] = path
            complete += item['size']
            progress('download', complete, total)
    progress('prepare', 0, 1)
    files = runtime_files(root)
    files['camerawall/release.env'] = (f"CAMERAWALL_VERSION={version}\n"
        f"CAMERAWALL_SHA256={app['sha256']}\nCAMERAWALL_DISPLAY_SHA256={display['sha256']}\n").encode()
    data_files = {'cw-initrd.gz': initramfs(files), 'repo/Packages': package_index(packages, paths)}
    data_files['repo/Packages.gz'] = gzip.compress(data_files['repo/Packages'], mtime=0)
    release = 'Origin: CameraWall offline cache\nLabel: Verified Debian packages\nSuite: offline\nDate: Fri, 06 Nov 2026 00:00:00 UTC\nArchitectures: amd64 all\nSHA256:\n'
    for name in ('Packages', 'Packages.gz'):
        payload = data_files['repo/' + name]
        release += f' {hashlib.sha256(payload).hexdigest()} {len(payload)} {name}\n'
    data_files['repo/Release'] = release.encode()
    source_files = {'app.tar.gz': paths[app['sha256']], 'display.tar.gz': paths[display['sha256']]}
    source_files.update({'analytics/' + i['name']: paths[i['sha256']] for i in spec['analytics']})
    source_files.update({'repo/pool/' + i['name']: paths[i['sha256']] for i in packages})
    sums = []
    for name, payload in data_files.items():
        sums.append(hashlib.sha256(payload).hexdigest() + '  ' + name)
    for name, path in source_files.items():
        with path.open('rb') as f:
            sums.append(sha256(f) + '  ' + name)
    data_files['SHA256SUMS'] = ('\n'.join(sums) + '\n').encode()
    payload_size = sum(len(v) for v in data_files.values()) + sum(p.stat().st_size for p in source_files.values())
    fat_size = math.ceil((payload_size * 1.08 + 32*MIB) / (16*MIB)) * 16*MIB
    fat = cache / 'payload.fat'
    fat.unlink(missing_ok=True)
    fat.touch()
    formatter = PyFat()
    formatter.mkfs(str(fat), fat_type=PyFat.FAT_TYPE_FAT32, size=fat_size, label='CWOFFLIN')
    formatter.close()
    with PyFatFS(str(fat)) as fs:
        for directory in ['repo', 'repo/pool', 'analytics']:
            fs.makedirs(directory, recreate=True)
        for name, payload in data_files.items():
            fs.writebytes(name, payload)
        for name, path in source_files.items():
            with fs.openbin(name, 'w') as out, path.open('rb') as source:
                shutil.copyfileobj(source, out, MIB)
    original = paths[spec['debian']['sha256']]
    image = cache / 'camerawall-offline.img'
    shutil.copyfile(original, image)
    patch_file(image, '/boot/grub/grub.cfg', MENU)
    patch_file(image, '/isolinux/isolinux.cfg', b'DEFAULT vesamenu.c32\nPROMPT 0\nTIMEOUT 0\nMENU TITLE CameraWall: UEFI required\nLABEL stop\n MENU LABEL Reboot in UEFI mode\n LOCALBOOT -1\n')
    # The original media-check manifest has a fixed-width digest: patch that line
    # too, without moving any official EFI/kernel/initrd extent.
    iso = pycdlib.PyCdlib(); iso.open(str(image))
    changed = {}
    for name in ('/boot/grub/grub.cfg', '/isolinux/isolinux.cfg'):
        data = io.BytesIO(); iso.get_file_from_iso_fp(data, rr_path=name)
        changed['.' + name] = hashlib.md5(data.getvalue()).hexdigest()
    sums_file = io.BytesIO()
    iso.get_file_from_iso_fp(sums_file, rr_path='/md5sum.txt'); iso.close()
    lines = sums_file.getvalue().decode().splitlines(keepends=True)
    lines = [changed[line.split()[-1]] + line[32:] if line.split()[-1] in changed else line for line in lines]
    patch_file(image, '/md5sum.txt', ''.join(lines).encode())
    start_bytes = math.ceil(image.stat().st_size / MIB) * MIB
    total_bytes = math.ceil((start_bytes + fat_size + 64*SECTOR) / MIB) * MIB
    with image.open('r+b') as out, fat.open('rb') as source:
        out.truncate(total_bytes)
        out.seek(start_bytes)
        shutil.copyfileobj(source, out, MIB)
    gpt_append(image, start_bytes // SECTOR, fat_size // SECTOR, total_bytes)
    with image.open('rb') as f:
        result = {'size': total_bytes, 'sha256': sha256(f)}
    (cache / 'prepared-image.json').write_text(json.dumps(result, indent=2) + '\n')
    progress('prepare', 1, 1)
    return image, result
