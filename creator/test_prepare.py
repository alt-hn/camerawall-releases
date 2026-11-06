import gzip
import hashlib
import io
import json
import struct
import tarfile
import tempfile
import unittest
import zlib
from pathlib import Path
from prepare import gpt_append, initramfs, control_from_deb


class OfflineBootTests(unittest.TestCase):
    def test_offline_manifest_includes_requested_runtime_packages(self):
        root = Path(__file__).parent
        packages = json.loads((root / 'offline/debian-packages.json').read_text())
        names = {p['name'].split('_')[0] for p in packages}
        preseed = (root / 'offline/preseed.cfg').read_text()
        requested = next(line.split(' string ', 1)[1].split() for line in preseed.splitlines() if line.startswith('d-i pkgsel/include '))
        self.assertFalse(set(requested) - names)
        self.assertTrue({'python3.11-venv', 'python3-pip-whl', 'python3-setuptools-whl'} <= names)

    def test_gpt_mirrors_crc_and_preserves_boot_payload(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'disk.img'
            header = bytearray(512)
            struct.pack_into('<8sIIIIQQQQ16sQIII', header, 0, b'EFI PART', 65536, 92, 0, 0, 1, 1023, 34, 990, b'G'*16, 2, 4, 128, 0)
            with p.open('wb') as f:
                f.truncate(4*1024**2)
                f.seek(512); f.write(header)
                f.seek(32768); f.write(b'official EFI and kernel sentinel')
            gpt_append(p, 2048, 2048, p.stat().st_size)
            with p.open('rb') as f:
                f.seek(32768); self.assertEqual(f.read(len(b'official EFI and kernel sentinel')), b'official EFI and kernel sentinel')
                f.seek(512); primary = bytearray(f.read(512))
                f.seek(-512, 2); backup = bytearray(f.read(512))
                for h in [primary, backup]:
                    expected = struct.unpack_from('<I', h, 16)[0]
                    struct.pack_into('<I', h, 16, 0)
                    self.assertEqual(expected, zlib.crc32(h[:92]))
                    lba = struct.unpack_from('<Q', h, 72)[0]
                    f.seek(lba*512); entries = f.read(512)
                    self.assertEqual(struct.unpack_from('<I',h,88)[0], zlib.crc32(entries))
                    self.assertEqual(struct.unpack_from('<QQ',entries,256+32), (2048,4095))
                self.assertEqual(struct.unpack_from('<QQ', primary, 24), (1,8191))
                self.assertEqual(struct.unpack_from('<QQ', backup, 24), (8191,1))

    def test_unexpected_extra_partition_stops(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'disk.img'
            with p.open('wb') as f:
                f.truncate(4*1024**2)
                h=bytearray(512)
                struct.pack_into('<8sIIIIQQQQ16sQIII',h,0,b'EFI PART',65536,92,0,0,1,1023,34,990,b'G'*16,2,4,128,0)
                f.seek(512);f.write(h);f.seek(1024+256);f.write(b'existing data partition')
            with self.assertRaises(ValueError):
                gpt_append(p,2048,2048,p.stat().st_size)

    def test_initramfs_contains_preseed_and_executable_guard(self):
        data = gzip.decompress(initramfs({'preseed.cfg': b'offline', 'camerawall/guard.sh': b'guard'}))
        entries = {}
        offset = 0
        while True:
            self.assertEqual(data[offset:offset+6],b'070701')
            fields=[int(data[offset+6+i*8:offset+14+i*8],16) for i in range(13)]
            offset+=110
            name=data[offset:offset+fields[11]-1].decode();offset+=fields[11];offset=(offset+3)//4*4
            payload=data[offset:offset+fields[6]];offset+=fields[6];offset=(offset+3)//4*4
            if name=='TRAILER!!!':break
            entries[name]=(fields[1],payload)
        self.assertEqual(entries['preseed.cfg'][1],b'offline')
        self.assertEqual(entries['camerawall/guard.sh'],(0o100755,b'guard'))

    def test_invalid_debian_package_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'bad.deb';p.write_bytes(b'not a package')
            with self.assertRaises(ValueError):control_from_deb(p)


if __name__ == '__main__':
    unittest.main()
