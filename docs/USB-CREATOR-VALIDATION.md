# USB Creator offline validation

Validation in progress, 2026-11-07 Asia/Ho_Chi_Minh. No Creator release has been
published yet. This document will be finalized after the offline install completes.

Completed:
- 20 focused tests: raw copy/readback, corrupt/short sources, partial writes,
  download cache/range/HTTPS handling, device identity/system-disk exclusions,
  GPT primary/backup CRCs and partition bounds, initramfs encoding, invalid .deb.
- All 365 Debian dependency packages downloaded and SHA-256 verified against the
  APT-resolved manifest. Official Debian ISO, CameraWall alpha.40 and AI files
  independently verified against pinned digests.
- Local composition produced a bootable hybrid image around 1.15 GiB. The actual
  writer routine copied it to a simulated USB and verified full image readback.
- QEMU EDK II booted the appended FAT/initramfs image. VM has no NIC (`-nic none`).
  No keys or clicks were supplied to the installer. Boot disk is protected and
  a separate 32 GiB disk selected; a 48 GiB sentinel disk remains unselected.
- First integration run exposed a missing local-repository mount at package
  installation. Fixed using an executable apt-setup generator after base install;
  a second run starts from a new blank target disk.
- Native macOS app opened with bundled Python/Tk; layout and empty/error states
  observed. An unresponsive external disk caused a read-only probe timeout;
  the app did not write a disk.
- Earlier online-image testing demonstrated alpha.40 backend UID 0, web login and
  update API enabled, plus persistence of root after install.sh --upgrade. This
  is not substituted for completing the new offline end-to-end test.

Pending: complete offline firstboot, root/API/model/credential checks, retained-USB
reboot, sentinel comparison, final native CI packages and public artifact readback.
Physical flashing/UAC/admin prompts, thin-client controllers, Secure Boot, real
camera throughput and physical HDMI remain unverified. App packages have no
Developer ID/notarization or Authenticode publisher signature.
