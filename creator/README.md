# CameraWall USB Creator

Native Python/Tk app packaged with PyInstaller for macOS ARM64/Intel and Windows x64.
The user selects a USB and explicitly starts erasure. Fixed image metadata in
`image.json` controls the download URL, length and SHA-256; no arbitrary URL/disk input.

`core.py` handles resumable download, source verification, raw image copy and readback.
`devices.py` discovers only physical, writable USB disks and excludes host boot disks.
macOS revalidates IOMedia registry identity; Windows uses the disk UniqueId. The worker
revalidates again after opening the device. Never weaken these checks for convenience.
`worker.py` runs only the fixed flash job elevated. It locks/dismounts Windows volumes
before raw writes and unmounts the macOS disk. The UI does not run elevated.

Build on each native OS with Python 3.13+ and Tk:

```
python -m pip install -r creator/requirements-build.txt
python -m unittest discover -s creator -p 'test_*.py' -v
python creator/build.py
```

Packaging requires a valid pinned image. `.github/workflows/usb-creator.yml` builds
Windows x64, macOS Intel and ARM64 independently; no physical disks are touched in CI.
The package is initially unsigned. Do not claim physical flashing or OS privilege
prompts have been tested solely because cross-platform packages built successfully.

Primary API references:
- https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_lock_volume
- https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_dismount_volume
- https://docs.python.org/3/library/tkinter.html
- https://pyinstaller.org/en/stable/usage.html
