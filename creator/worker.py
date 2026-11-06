"""Elevated fixed-purpose writer. Never accepts arbitrary image hashes/URLs."""
import base64
import ctypes
import json
import os
import platform
import re
import subprocess
import sys
from contextlib import ExitStack
from core import copy_and_verify
from devices import powershell, revalidate


def write_mac(image, selected, manifest):
    if os.geteuid() != 0:
        raise PermissionError('Cần quyền quản trị để ghi USB.')
    revalidate(selected, manifest['size'])
    name = selected['id']
    if not re.fullmatch(r'disk[0-9]+', name):
        raise ValueError('Thiết bị không hợp lệ.')
    subprocess.run(['/usr/sbin/diskutil', 'unmountDisk', '/dev/' + name], check=True, capture_output=True)
    revalidate(selected, manifest['size'])
    with open(image, 'rb') as source, open('/dev/r' + name, 'r+b', buffering=0) as target:
        revalidate(selected, manifest['size'])
        copy_and_verify(source, target, manifest, sync=lambda: os.fsync(target.fileno()))
    subprocess.run(['/usr/sbin/diskutil', 'eject', '/dev/' + name], check=True, capture_output=True)


def write_windows(image, selected, manifest):
    from ctypes import wintypes as w
    import msvcrt
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateFileW.argtypes = [w.LPCWSTR, w.DWORD, w.DWORD, ctypes.c_void_p, w.DWORD, w.DWORD, w.HANDLE]
    kernel.CreateFileW.restype = w.HANDLE
    kernel.CloseHandle.argtypes = [w.HANDLE]
    kernel.DeviceIoControl.argtypes = [w.HANDLE, w.DWORD, ctypes.c_void_p, w.DWORD, ctypes.c_void_p, w.DWORD, ctypes.POINTER(w.DWORD), ctypes.c_void_p]
    if not ctypes.windll.shell32.IsUserAnAdmin():
        raise PermissionError('Cần quyền Administrator để ghi USB.')
    revalidate(selected, manifest['size'])
    number = selected['id']
    if not re.fullmatch(r'[0-9]+', number):
        raise ValueError('Thiết bị không hợp lệ.')
    invalid = ctypes.c_void_p(-1).value

    def handle(path):
        h = kernel.CreateFileW(path, 0xC0000000, 3, None, 3, 0, None)
        if h == invalid:
            raise ctypes.WinError(ctypes.get_last_error())
        return h

    def control(h, code):
        returned = w.DWORD()
        if not kernel.DeviceIoControl(h, code, None, 0, None, 0, ctypes.byref(returned), None):
            raise ctypes.WinError(ctypes.get_last_error())

    with ExitStack() as stack:
        # Lock every volume, including volumes without drive letters, before any
        # write. Keep handles open until verification finishes. Never force unlock.
        paths = json.loads(powershell(f"@(Get-Partition -ErrorAction Stop | Where-Object {{ $_.DiskNumber -eq {number} }} | ForEach-Object {{ $_.AccessPaths }} | Where-Object {{ $_ -like '\\\\?\\Volume*' }}) | ConvertTo-Json -Compress") or '[]')
        if isinstance(paths, str):
            paths = [paths]
        for path in sorted(set(paths)):
            if not re.fullmatch(r'\\\\\?\\Volume\{[0-9A-Fa-f-]+\}\\', path):
                raise ValueError('Không nhận diện được volume USB.')
            h = handle(path.rstrip('\\'))
            stack.callback(kernel.CloseHandle, h)
            control(h, 0x00090018)  # FSCTL_LOCK_VOLUME
            control(h, 0x00090020)  # FSCTL_DISMOUNT_VOLUME, only after lock succeeds
        revalidate(selected, manifest['size'])
        h = handle('\\\\.\\PhysicalDrive' + number)
        try:
            fd = msvcrt.open_osfhandle(h, os.O_RDWR | os.O_BINARY)
        except Exception:
            kernel.CloseHandle(h)
            raise
        target = stack.enter_context(os.fdopen(fd, 'r+b', buffering=0))
        source = stack.enter_context(open(image, 'rb'))
        revalidate(selected, manifest['size'])
        copy_and_verify(source, target, manifest, sync=lambda: os.fsync(target.fileno()))
        control(h, 0x00070140)  # IOCTL_DISK_UPDATE_PROPERTIES


def execute(encoded, manifest):
    if len(encoded) > 16384:
        raise ValueError('Yêu cầu không hợp lệ.')
    job = json.loads(base64.urlsafe_b64decode(encoded))
    image = job['image']
    selected = job['device']
    if platform.system() == 'Darwin':
        write_mac(image, selected, manifest)
    elif platform.system() == 'Windows':
        write_windows(image, selected, manifest)
    else:
        raise RuntimeError('Chỉ hỗ trợ macOS và Windows.')


def elevated(image, selected):
    job = base64.urlsafe_b64encode(json.dumps({'image': str(image), 'device': selected}).encode()).decode()
    if getattr(sys, 'frozen', False):
        command = [sys.executable, '--write', job]
    else:
        command = [sys.executable, os.path.join(os.path.dirname(__file__), 'app.py'), '--write', job]
    if platform.system() == 'Darwin':
        import shlex
        shell = shlex.join(command)
        # Pass the command as argv: never interpolate paths into AppleScript source.
        code = 'on run argv\n do shell script (item 1 of argv) with administrator privileges\nend run'
        result = subprocess.run(['/usr/bin/osascript', '-e', code, shell], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or 'Không được cấp quyền ghi USB.')
    elif platform.system() == 'Windows':
        from ctypes import wintypes as w
        class ExecuteInfo(ctypes.Structure):
            _fields_ = [('cbSize', w.DWORD), ('fMask', w.ULONG), ('hwnd', w.HWND), ('lpVerb', w.LPCWSTR), ('lpFile', w.LPCWSTR), ('lpParameters', w.LPCWSTR), ('lpDirectory', w.LPCWSTR), ('nShow', ctypes.c_int), ('hInstApp', w.HINSTANCE), ('lpIDList', ctypes.c_void_p), ('lpClass', w.LPCWSTR), ('hkeyClass', w.HKEY), ('dwHotKey', w.DWORD), ('hIcon', w.HANDLE), ('hProcess', w.HANDLE)]
        shell = ctypes.WinDLL('shell32', use_last_error=True)
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        shell.ShellExecuteExW.argtypes = [ctypes.POINTER(ExecuteInfo)]
        kernel.WaitForSingleObject.argtypes = [w.HANDLE, w.DWORD]
        kernel.GetExitCodeProcess.argtypes = [w.HANDLE, ctypes.POINTER(w.DWORD)]
        kernel.CloseHandle.argtypes = [w.HANDLE]
        info = ExecuteInfo()
        info.cbSize = ctypes.sizeof(info)
        info.fMask = 0x40  # SEE_MASK_NOCLOSEPROCESS
        info.lpVerb = 'runas'
        info.lpFile = command[0]
        info.lpParameters = subprocess.list2cmdline(command[1:])
        info.nShow = 0
        if not shell.ShellExecuteExW(ctypes.byref(info)):
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            kernel.WaitForSingleObject(info.hProcess, 0xFFFFFFFF)
            code = w.DWORD()
            if not kernel.GetExitCodeProcess(info.hProcess, ctypes.byref(code)) or code.value:
                raise RuntimeError('Ghi/kiểm tra USB không thành công. Xem thông báo của bộ ghi và thử lại.')
        finally:
            kernel.CloseHandle(info.hProcess)
    else:
        raise RuntimeError('Chỉ hỗ trợ macOS và Windows.')
