# USB Creator 2.0 validation — 2026-11-07

Go + Wails rewrite requested after the Python version's physical macOS raw-device
EPERM error. The old AppleScript/root open is replaced with authopen for the chosen
USB, requested before download. This mechanism still needs the owner's physical
USB permission/flash confirmation; changing language alone is not proof of a fix.

Completed locally:
- Compiled macOS ARM64 executable (~11 MiB), embedded UI rendered in a native window.
- Windows x64 cross-compilation succeeds; native platform builds run separately.
- All 365 Debian packages and pinned Debian/app/AI sources were verified from cache.
- Go composition produced a 1,231,028,224-byte boot image. FAT payload readback tests
  check pinned SHA-256 for application, AI files and Debian packages.
- Focused tests cover short writes/truncation/cancellation, primary/backup GPT CRCs,
  preserving EFI bytes, rejecting an occupied extra GPT partition, required Python
  dependency closure, HTTP resume range matching and USB replacement rejection.
- Read-only local discovery agrees with diskutil: no external physical USB currently
  present. Previous 1.0 detection of RTL9210 NVME is not substituted for a 2.0 probe.

Native CI checks compiled artifacts and performs a Windows write/readback test only
on a newly created VHD, revalidating its exact backing image association on every
check. No physical USB is flashed by the agent. No new long VM installation suite
is run, following the owner's request to test the physical target themselves.

Remaining: physical removable-volume permission, actual USB flash/readback,
complete unattended offline installation/firstboot, retained-USB reboot, final
non-target disk preservation, camera/HDMI/hardware compatibility. The prior Python
installer VM reached base/kernel installation; do not claim completed offline
installation. Apps lack trusted Apple/Windows publisher signing.
