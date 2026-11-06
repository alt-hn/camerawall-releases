import array
import io
import os
from pathlib import Path
import socket
import tempfile
import unittest
from unittest.mock import patch
import mac_access


class AuthorizationTests(unittest.TestCase):
    def test_authorized_descriptor_does_not_write_and_closes(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / 'usb.raw'
            p.write_bytes(b'preserve existing content')
            original = os.open(p, os.O_RDWR)
            def spawn(command, stdout, **kwargs):
                self.assertEqual(command, ['/usr/libexec/authopen', '-stdoutpipe', '-o', str(os.O_RDWR), '/dev/rdisk5'])
                stdout.sendmsg([b'\0'], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array('i', [original]))])
                class Process:
                    returncode = 0
                    def communicate(self): return None, b''
                    def poll(self): return 0
                return Process()
            try:
                with patch('mac_access.revalidate'), patch('mac_access.subprocess.run'), patch('mac_access.subprocess.Popen', side_effect=spawn), patch('mac_access.os.stat', return_value=os.fstat(original)):
                    with mac_access.authorized_usb({'id': 'disk5'}, 1) as target:
                        fd = target.fileno()
                        self.assertEqual(target.read(), b'preserve existing content')
                    with self.assertRaises(OSError): os.fstat(fd)
                self.assertEqual(p.read_bytes(), b'preserve existing content')
            finally:
                os.close(original)

    def test_cancelled_authorization_fails_before_yield(self):
        def spawn(command, stdout, **kwargs):
            class Process:
                returncode = 1
                def communicate(self): return None, b'Authorization cancelled'
                def poll(self): return 1
            return Process()
        with patch('mac_access.revalidate'), patch('mac_access.subprocess.run'), patch('mac_access.subprocess.Popen', side_effect=spawn):
            with self.assertRaisesRegex(PermissionError, 'Authorization cancelled'):
                with mac_access.authorized_usb({'id': 'disk5'}, 1):
                    self.fail('Must not prepare or write after cancellation')


if __name__ == '__main__': unittest.main()
