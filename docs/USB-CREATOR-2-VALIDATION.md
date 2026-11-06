# USB Creator 2.0 validation — 2026-11-07

Go + Wails rewrite requested after the Python version's physical macOS raw-device
EPERM error. The old AppleScript/root open is replaced with authopen for the chosen
USB, requested before download. Owner-triggered physical testing authorized the
DataTraveler 3.0 USB and reached 100% write, then exposed an ENOTTY flush failure.
The corrected build uses Apple DKIOCSYNCHRONIZECACHE for raw devices instead of
F_FULLFSYNC; failures still stop the operation before any success report.

Completed locally:
- Compiled macOS ARM64 executable (~11 MiB), embedded UI rendered in a native window.
- Windows x64 cross-compilation succeeds; native platform builds run separately.
- All 365 Debian packages and pinned Debian/app/AI sources were verified from cache.
- Go composition produced a 1,231,028,224-byte boot image. FAT payload readback tests
  check pinned SHA-256 for application, AI files and Debian packages.
- Focused tests cover short writes/truncation/cancellation, primary/backup GPT CRCs,
  preserving EFI bytes, rejecting an occupied extra GPT partition, required Python
  dependency closure, HTTP resume range matching and USB replacement rejection.
- Native UI detected the owner's DataTraveler 3.0, 28.8 GiB USB.
- Compact UI and new USB/camera icon rendered in the native macOS app.
- EN/VI presentation covers controls, warnings, progress, logs and application errors;
  system language selects the initial locale, with a persistent manual override.
  Native macOS launch selected EN, switching to VI updated the interface and
  reopening retained VI. Focused tests cover locale fallback and dynamic messages.
- Owner-triggered retry on DataTraveler 3.0 (28.8 GiB) completed all seven stages
  in 2 min 12 sec. Raw-device cache flush succeeded and the full written image
  passed SHA-256 readback. The app displayed safe-to-remove completion.

Native CI checks compiled artifacts and performs a Windows write/readback test only
on a newly created VHD, revalidating its exact backing image association on every
check. No physical USB is flashed by the agent. No new long VM installation suite
is run, following the owner's request to test the physical target themselves.

Remaining: complete unattended offline installation/firstboot, retained-USB reboot, final
non-target disk preservation, camera/HDMI/hardware compatibility. The prior Python
installer VM reached base/kernel installation; do not claim completed offline
installation. Apps lack trusted Apple/Windows publisher signing.
