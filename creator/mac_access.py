"""Ask macOS for a descriptor to the selected USB using Apple's authopen.

Opening never truncates or writes. The caller retains the descriptor throughout
preparation, then revalidates device identity before the first write.
"""
import array
from contextlib import contextmanager
import os
import re
import socket
import subprocess
from devices import revalidate
from core import copy_and_verify


@contextmanager
def authorized_usb(selected, minimum):
    revalidate(selected, minimum)
    name = selected['id']
    if not re.fullmatch(r'disk[0-9]+', name):
        raise ValueError('Thiết bị không hợp lệ.')
    subprocess.run(['/usr/sbin/diskutil', 'unmountDisk', '/dev/' + name], check=True, capture_output=True)
    revalidate(selected, minimum)
    parent, child = socket.socketpair()
    descriptors = []
    process = None
    try:
        process = subprocess.Popen(['/usr/libexec/authopen', '-stdoutpipe', '-o', str(os.O_RDWR), '/dev/r' + name], stdout=child, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
        child.close()
        _, ancillary, flags, _ = parent.recvmsg(1, socket.CMSG_SPACE(array.array('i').itemsize * 4))
        for level, kind, payload in ancillary:
            if level == socket.SOL_SOCKET and kind == socket.SCM_RIGHTS:
                received = array.array('i')
                received.frombytes(payload[:len(payload) - len(payload) % received.itemsize])
                descriptors.extend(received)
        _, error = process.communicate()
        if process.returncode or len(descriptors) != 1 or flags & socket.MSG_CTRUNC:
            raise PermissionError('macOS chưa cho phép truy cập USB. Hãy cho phép Removable Volumes khi được hỏi; nếu đã từ chối, kiểm tra System Settings → Privacy & Security → Files and Folders → CameraWall USB Creator. Chi tiết: ' + error.decode(errors='replace').strip())
        fd = descriptors.pop()
        with os.fdopen(fd, 'r+b', buffering=0) as target:
            revalidate(selected, minimum)
            if os.fstat(target.fileno()).st_rdev != os.stat('/dev/r' + name).st_rdev:
                raise ValueError('USB đã thay đổi trong lúc xin quyền. Hãy chọn lại.')
            yield target
    finally:
        parent.close()
        child.close()
        for fd in descriptors:
            os.close(fd)
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait()


def write_authorized(image, selected, manifest, target):
    revalidate(selected, manifest['size'])
    with open(image, 'rb') as source:
        copy_and_verify(source, target, manifest, sync=lambda: os.fsync(target.fileno()))


def eject(selected):
    subprocess.run(['/usr/sbin/diskutil', 'eject', '/dev/' + selected['id']], check=True, capture_output=True)
