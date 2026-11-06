# CameraWall USB Creator — offline first

Native macOS ARM64/Intel and Windows x64 tool. It downloads official Debian media,
SHA-256-pinned Debian packages, the existing CameraWall release and AI files, then
assembles and flashes the bootable USB **locally**. No CameraWall ISO is published
or downloaded by this tool. Legacy `usb-v*` Internet installer assets remain separate.

`core.py`: resumable verified HTTPS downloads, source verification and raw copy/readback.
`prepare.py`: local FAT payload, newc initramfs overlay, fixed-size ISO menu patches,
hybrid GPT/MBR extension and backup GPT relocation. Official Debian EFI/kernel/initrd
remain in their original extents. FAT label is deliberately <=8 characters to avoid
8.3 volume-label truncation. Existing FAT work files are recreated before formatting.
`devices.py`: physical writable USB discovery, boot/system exclusions, revalidation.
`worker.py`: fixed-purpose elevated writing; accepts only the selected/revalidated
USB and a verified locally prepared image, never generic commands or device paths.

The runtime payload mounts the data partition only on the actual installer disk,
verifies all payload hashes before partitioning, excludes that boot disk, chooses the
smallest eligible non-boot disk >=24 GiB, and protects all other disks read-only.
Debian dependencies come from the USB's local APT repository. Firstboot refuses a
missing/corrupt AI asset and never silently switches to online download.

`offline/debian-packages.json` is the dependency closure resolved by Debian 12 APT
from signature-verified official indices, with an empty dpkg status and empty archive cache, no recommends,
`Acquire::ForceHash=SHA256` and `--print-uris --download-only`. The requested roots
are documented in the maintainer script. Package controls are read from verified
.debs to generate the local Packages/Release metadata. The local repository uses
trusted=yes only after every file passes its pinned SHA-256; external unsigned
repositories are not enabled.

Build on each native OS with Python 3.13+ and Tk:

```
python -m pip install -r creator/requirements-build.txt
python -m unittest discover -s creator -p 'test_*.py' -v
python creator/build.py
```

The workflow builds and smoke-tests native packages independently, and exercises
the native writers against newly created Windows VHD/macOS disk-image devices.
Each test rechecks the exact temporary image-to-device association before writing;
this fixture override is never bundled in the app. No physical disk is touched in CI. The GUI remains unprivileged; macOS/Windows authenticate the writer.
Apps initially have no Developer ID/notarization or Authenticode publisher signature.

References: [Linux initramfs](https://www.kernel.org/doc/html/latest/driver-api/early-userspace/buffer-format.html),
[Windows volume locks](https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_lock_volume),
[Python Tk](https://docs.python.org/3/library/tkinter.html),
[PyInstaller](https://pyinstaller.org/en/stable/usage.html).
