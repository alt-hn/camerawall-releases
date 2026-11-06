import hashlib
import io
import json
import plistlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import core
import devices


def manifest(data):
    return {'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data), 'url': 'https://github.com/alt-hn/camerawall-releases/releases/download/test/image.iso'}


class Response(io.BytesIO):
    url = 'https://release-assets.githubusercontent.com/image'
    status = 200
    headers = {}


class TransferTests(unittest.TestCase):
    def test_writes_boot_sectors_and_verifies(self):
        data = b'BOOT' + bytes(range(256)) * 8192
        target = io.BytesIO(b'Z' * (len(data) + 512))
        progress = []
        core.copy_and_verify(io.BytesIO(data), target, manifest(data), lambda *e: progress.append(e))
        self.assertEqual(target.getvalue()[:len(data)], data)
        self.assertEqual(target.getvalue()[len(data):], b'Z' * 512)
        self.assertEqual(progress[-1], ('verify', len(data), len(data)))

    def test_bad_source_never_writes(self):
        target = io.BytesIO(b'keep me')
        with self.assertRaises(ValueError):
            core.copy_and_verify(io.BytesIO(b'wrong'), target, manifest(b'right'))
        self.assertEqual(target.getvalue(), b'keep me')

    def test_short_source_never_writes(self):
        target = io.BytesIO(b'keep me')
        with self.assertRaises(ValueError):
            core.copy_and_verify(io.BytesIO(b'x'), target, manifest(b'longer'))
        self.assertEqual(target.getvalue(), b'keep me')

    def test_readback_corruption_is_failure(self):
        class Corrupt(io.BytesIO):
            def read(self, size=-1):
                return b'X' * len(super().read(size))
        with self.assertRaises(ValueError):
            core.copy_and_verify(io.BytesIO(b'boot'), Corrupt(), manifest(b'boot'))

    def test_partial_writes_are_completed(self):
        class Partial(io.BytesIO):
            def write(self, data):
                return super().write(data[:2])
        target = Partial()
        core.copy_and_verify(io.BytesIO(b'bootsector'), target, manifest(b'bootsector'))
        self.assertEqual(target.getvalue(), b'bootsector')

    def test_zero_write_fails(self):
        class Full(io.BytesIO):
            def write(self, data):
                return 0
        with self.assertRaises(OSError):
            core.copy_and_verify(io.BytesIO(b'boot'), Full(), manifest(b'boot'))

    def test_bad_hash_deletes_download(self):
        with tempfile.TemporaryDirectory() as directory, patch('core.urllib.request.urlopen', return_value=Response(b'evil')):
            with self.assertRaises(ValueError):
                core.download(manifest(b'boot'), directory)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_cache_verified_before_reuse(self):
        with tempfile.TemporaryDirectory() as directory:
            m = manifest(b'boot')
            Path(directory, m['sha256'] + '.iso').write_bytes(b'evil')
            with patch('core.urllib.request.urlopen', return_value=Response(b'boot')) as fetch:
                self.assertEqual(core.download(m, directory).read_bytes(), b'boot')
                fetch.assert_called_once()

    def test_resume_requires_matching_range(self):
        m = manifest(b'boot')
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, m['sha256'] + '.part').write_bytes(b'bo')
            response = Response(b'ot')
            response.status = 206
            response.headers = {'Content-Range': 'bytes 2-3/4'}
            with patch('core.urllib.request.urlopen', return_value=response):
                self.assertEqual(core.download(m, directory).read_bytes(), b'boot')

    def test_ignored_range_restarts(self):
        m = manifest(b'boot')
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, m['sha256'] + '.part').write_bytes(b'bo')
            with patch('core.urllib.request.urlopen', return_value=Response(b'boot')):
                self.assertEqual(core.download(m, directory).read_bytes(), b'boot')

    def test_wrong_range_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            response = Response(b'boot')
            response.status = 206
            response.headers = {'Content-Range': 'bytes 1-4/5'}
            with patch('core.urllib.request.urlopen', return_value=response), self.assertRaises(ValueError):
                core.download(manifest(b'boot'), directory)

    def test_downgraded_https_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            response = Response(b'boot')
            response.url = 'http://example.com/image'
            with patch('core.urllib.request.urlopen', return_value=response), self.assertRaises(ValueError):
                core.download(manifest(b'boot'), directory)


class DeviceTests(unittest.TestCase):
    def test_device_replacement_rejected(self):
        old = {'id': 'disk5', 'size': 32 * 1024**3, 'model': 'USB', 'serial': 'attach-1', 'sector': 512}
        new = dict(old, serial='attach-2')
        with patch('devices.discover', return_value=[new]), self.assertRaises(ValueError):
            devices.revalidate(old, 100)

    def test_no_serial_or_4k_sector_rejected(self):
        base = {'id': '1', 'size': 32 * 1024**3, 'model': 'USB', 'serial': 'abc', 'sector': 512}
        with patch('devices.platform.system', return_value='Windows'), patch('devices.windows_devices', return_value=[dict(base, serial=''), dict(base, sector=4096), base]):
            self.assertEqual(devices.discover(100), [base])

    def test_mac_system_usb_excluded(self):
        def run(args):
            if 'ioreg' in args[0]:
                return plistlib.dumps([{'BSD Name': 'disk5', 'Whole': True, 'IORegistryEntryID': 10}])
            if args[1:3] == ['list', '-plist']:
                return plistlib.dumps({'WholeDisks': ['disk5']})
            if args[-1] == '/':
                return plistlib.dumps({'DeviceIdentifier': 'disk6s1s1'})
            if args[1] == 'apfs':
                return plistlib.dumps({'Containers': [{'PhysicalStores': [{'DeviceIdentifier': 'disk5s2'}], 'Volumes': [{'Roles': ['System']}]}]})
            return plistlib.dumps({'Whole': True, 'Internal': False, 'VirtualOrPhysical': 'Physical', 'BusProtocol': 'USB', 'Writable': True, 'TotalSize': 32 * 1024**3})
        with patch('devices.run', side_effect=run):
            self.assertEqual(devices.mac_devices(), [])


if __name__ == '__main__':
    unittest.main()
