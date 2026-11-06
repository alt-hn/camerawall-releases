# USB Creator 1.0.0 validation

2026-11-07 Asia/Ho_Chi_Minh. Published for the owner's physical-machine testing.
The owner explicitly requested stopping further testing and publishing. Full
unattended offline installation is **not yet validated end to end**.

## Completed evidence

- Build source: `b7fb1d1` on clean, pushed main. Native CI run
  [42265138604](https://github.com/alt-hn/camerawall-releases/actions/runs/42265138604)
  passed Windows x64, macOS Intel and macOS ARM64 builds and packaged GUI startup.
- 20 focused tests passed: copy/readback, corrupt/short sources, partial writes,
  download cache/range/HTTPS handling, device identity/system-disk exclusions,
  GPT CRCs/bounds, initramfs encoding and required offline package presence.
- Native Windows writer passed volume lock/dismount, raw write, flush and SHA-256
  readback on a newly created disposable VHD. Native macOS writers passed unmount,
  raw write, flush, readback and eject on disposable disk-image devices. These
  tests revalidate the exact temporary image-to-device association. No physical
  disk was flashed, erased or reformatted.
- Live Mac discovery and GUI identified the attached RTL9210 NVME USB device,
  256,060,514,304 bytes (238.5 GiB), disk18, writable, external and 512-byte sectors.
  Device numbers are session-specific; select by model and capacity, not this ID.
- All 365 Debian packages downloaded and SHA-256 verified against APT-resolved
  manifests. Official Debian ISO, CameraWall alpha.40 and AI assets also verified.
- Local composition produced a 1,231,028,224-byte boot image. The same copy/readback
  routine used by the app wrote and verified a simulated USB; it was then expanded
  to an 8 GiB simulated device to exercise realistic media geometry.
- QEMU EDK II booted the image with no NIC (`-nic none`) and no keypresses. It
  selected the separate 32 GiB destination and protected the 48 GiB sentinel disk.
  At the last observation, the sentinel disk had zero writes.
- Integration testing found and fixed an unavailable target repository mount,
  then six dependencies omitted because they were already cached in the resolver
  VM. The final resolver uses both empty dpkg status and empty archive cache.
  The third run reached kernel/base-system installation before being stopped at
  the owner's request. This is **not** proof of completed offline installation.
- Prior Internet-installer tests demonstrated alpha.40 backend UID 0, web login,
  update API enabled and root persistence through install.sh --upgrade. They do
  not substitute for offline firstboot verification of this Creator version.

## Remaining physical/integration checks

Complete offline firstboot; authenticated UI/root/model readiness on that install;
retained-USB reboot; final sentinel comparison; actual USB controller compatibility;
physical UAC/admin prompts; thin-client firmware, Secure Boot, HDMI and cameras.
Apps have no Apple Developer ID/notarization or Windows Authenticode publisher
signature. macOS ad-hoc build signing is not a trusted publisher signature.

The media is intended for Intel/AMD x86-64 UEFI systems, with Secure Boot disabled.
It automatically erases the smallest eligible non-boot disk >=24 GiB. The Creator
runs on Mac Apple Silicon but does not install this OS onto Apple Silicon Macs.
