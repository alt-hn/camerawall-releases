"""Maintainer integration test: native writer against a newly created VHD only.

Run explicitly on a disposable, elevated Windows CI runner. Never discovers or
selects physical disks, and never adds a device-validation bypass to the app.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile


def main():
    assert platform.system() == 'Windows'
    import worker
    from devices import powershell
    with tempfile.TemporaryDirectory(prefix='cw-writer-fixture-') as directory:
        root = Path(directory)
        vhd = root / 'fixture.vhd'
        script = root / 'diskpart.txt'
        script.write_text(f'create vdisk file="{vhd}" maximum=128 type=expandable\nselect vdisk file="{vhd}"\nattach vdisk\ncreate partition primary\nformat fs=ntfs quick\n', encoding='ascii')
        subprocess.run(['diskpart', '/s', str(script)], check=True, capture_output=True)
        # A path from TemporaryDirectory has no quotes, but escape defensively.
        literal = str(vhd).replace("'", "''")
        query = f"Get-DiskImage -ImagePath '{literal}' -ErrorAction Stop | Get-Disk -ErrorAction Stop | Select-Object Number,Size,IsBoot,IsSystem,FriendlyName | ConvertTo-Json -Compress"

        def inspect():
            disk = json.loads(powershell(query))
            assert not disk['IsBoot'] and not disk['IsSystem'], disk
            assert 'virtual' in disk['FriendlyName'].lower(), disk
            assert disk['Size'] == 128 * 1024**2, disk
            return disk

        try:
            disk = inspect()
            selected = {'id': str(disk['Number']), 'size': disk['Size']}
            def validate(device, minimum):
                current = inspect()
                assert str(current['Number']) == device['id']
                assert current['Size'] >= minimum
            worker.revalidate = validate
            image = root / 'image.raw'
            payload = os.urandom(1024**2)
            image.write_bytes(payload)
            worker.write_windows(image, selected, {'size': len(payload), 'sha256': hashlib.sha256(payload).hexdigest()})
            print('PASS: Windows volume lock, dismount, raw write, flush and SHA256 readback on disposable VHD')
        finally:
            script.write_text(f'select vdisk file="{vhd}"\ndetach vdisk\n', encoding='ascii')
            subprocess.run(['diskpart', '/s', str(script)], check=True, capture_output=True)


if __name__ == '__main__':
    main()
