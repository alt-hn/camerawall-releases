"""Explicit CI-only raw writer check on a newly created macOS disk image."""
import hashlib
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile


def plist(command):
    return plistlib.loads(subprocess.check_output(command))


def write_fixture(image_path, source_path, device):
    import worker
    image_path = Path(image_path).resolve()
    def validate(selected, minimum):
        images = plist(['/usr/bin/hdiutil', 'info', '-plist'])['images']
        matches = [i for i in images if Path(i['image-path']).resolve() == image_path]
        assert len(matches) == 1
        entries = {e.get('dev-entry') for e in matches[0]['system-entities']}
        assert '/dev/' + selected['id'] in entries
        info = plist(['/usr/sbin/diskutil', 'info', '-plist', '/dev/' + selected['id']])
        assert info['Whole'] and info['VirtualOrPhysical'] == 'Virtual'
        assert info['TotalSize'] >= minimum
    worker.revalidate = validate
    source = Path(source_path)
    worker.write_mac(source, {'id': device}, {'size': source.stat().st_size, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest()})
    print('PASS: macOS unmount, raw write, flush, SHA256 readback and eject on disposable disk image')


def main():
    with tempfile.TemporaryDirectory(prefix='cw-writer-fixture-') as directory:
        root = Path(directory)
        image = root / 'fixture.dmg'
        subprocess.run(['/usr/bin/hdiutil', 'create', '-size', '128m', '-layout', 'MBRSPUD', '-fs', 'MS-DOS', str(image)], check=True)
        attached = plist(['/usr/bin/hdiutil', 'attach', '-nobrowse', '-plist', str(image)])
        devices = [e['dev-entry'] for e in attached['system-entities'] if e.get('dev-entry') and e.get('content-hint') == 'FDisk_partition_scheme']
        assert len(devices) == 1, attached
        device = devices[0]
        try:
            source = root / 'image.raw'
            source.write_bytes(os.urandom(1024**2))
            subprocess.run(['sudo', '-n', sys.executable, __file__, '--fixture', str(image), str(source), device.removeprefix('/dev/')], check=True)
        finally:
            subprocess.run(['/usr/bin/hdiutil', 'detach', device], capture_output=True)


if __name__ == '__main__':
    if len(sys.argv) == 5 and sys.argv[1] == '--fixture':
        write_fixture(*sys.argv[2:])
    else:
        main()
