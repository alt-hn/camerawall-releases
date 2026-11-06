# USB 0.3.0 Internet installer validation

For the new offline Creator, see [USB-CREATOR-VALIDATION.md](USB-CREATOR-VALIDATION.md).
The Creator references below describe the earlier online prototype, not the final offline tool.

Date: 2026-11-06 (Asia/Ho_Chi_Minh). No physical USB/disk was flashed.

## Image provenance

Debian 12.15.0 amd64 netinst retains the official EFI image, kernel and initrd.
Builder verifies Debian CD key DF9B9C49EAA9298432589D76DA87E80D6294BE9B and
ISO SHA-256 cd4462c06aa8892e692c0c4b9c17802f38c8ab8690e85cbfb5ccaa5956e9af17.
The final ISO is rebuilt from clean pushed main; its payload/menu files are
extracted and compared with source. BUILD-INFO.json identifies that exact build.

Pinned application: v0.1.0-alpha.40 (public latest at selection), SHA-256
bec332ff9313035ced4a5a0883bd410ba17321a85cd6824b85acc99854ad1753,
source 32b0714d9f96db7492c43b077f43bd88bf287358. Archive digest and embedded source
were read back. No private application source is modified or published.

## VM evidence

- The unchanged disk selection/preseed/USB marker path was fully installed and
  rebooted without input under usb-v0.2.0. Its evidence is retained at that tag.
  This release does not claim a second complete Debian installation.
- The new bootstrap, pinned application and root service profile were installed
  into that disposable Debian 12 QEMU guest. Pinned AI files loaded, firstboot
  reached READY, CameraWall and media services were active, and HTTP login worked.
- /proc/PID/status showed all backend UIDs = 0. Running the packaged
  install.sh --upgrade preserved the root drop-in and the backend restarted as
  UID 0. Application/media accounts and existing credentials/data were preserved.
- Authenticated GET /api/updates returned current=alpha.40 and enabled=true.
  The automatic update timer remains enabled, with fresh-appliance mode Off, so
  later UI mode changes can take effect. No newer release was fabricated to
  claim a complete web-triggered upgrade to a nonexistent version.
- Creator's actual copy-and-verify routine wrote the full development ISO into
  a disposable raw USB image, flushed it and verified the SHA-256 by reading it
  back. QEMU EDK II booted that output through USB storage into the unattended
  Debian installer. This verifies boot-image copying, not physical controller I/O.

## Creator tests and packaging

15 focused fixture tests cover correct raw copying/readback, partial/failed writes,
corrupt/short sources rejected before writes, corrupt readback, cached-image
revalidation, interrupted download/range behavior, HTTPS downgrade rejection,
USB replacement, absent identities/4K sectors and external macOS system exclusion.

The native app was visually inspected on macOS for layout/contrast and the empty
USB state. Final packages are built natively per architecture via the public
workflow; per-package metadata records source, OS, architecture, image pin and
SHA-256. Build success is separate from physical flash/OS privilege prompt tests.

The root configuration intentionally increases backend privilege at the owner's
request. It survives replacement of the base systemd unit. Future changes to
installer/update semantics may require integration review; persistence is not
promised against an updater explicitly removing custom drop-ins.

## Limits

Unverified: physical USB writing, Windows UAC/macOS administrator dialogs end to end,
real thin-client boot/NIC/storage/HDMI, Secure Boot, ARM target installation, camera
throughput, long recordings and every power-loss boundary. The Creator apps are
initially unsigned (no Apple notarization/Developer ID or Windows Authenticode).
No claim is made that OS download/security warnings are absent.

The system boot disk and other unselected USB devices are not written by fixture
or CI tests. No host networking was modified. Installer disk protection/zero-input
behavior remains subject to the firmware USB-first and working Ethernet prerequisites.
