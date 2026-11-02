# Building the CameraWall USB installer

Prerequisites: Python 3.9+, curl, GnuPG, xorriso; Linux or macOS. On macOS:
`brew install xorriso gnupg` (QEMU is optional for validation).

Read `../docs/USB-INSTALL-VI.md`. Build on clean, committed, pushed `main` before
publishing. `python3 usb/build.py` downloads/caches Debian's official netinst,
verifies the Debian CD signature against the pinned fingerprint and checks SHA-256,
then remasters a bootable hybrid ISO under `dist/`. The script refuses to overwrite
an existing ISO. Local development builds are identified as dirty in BUILD-INFO;
never publish those builds. No host disk, partition, mount or service is modified.

The pinned application version/hash/source is in `release.env`. To change it,
verify the release's checksum, archive BUILD-INFO and source provenance; do not
substitute a moving `latest` URL. The application archive is downloaded on the
target after Debian boots. Firmware and installer packages remain Debian's;
this project does not host a cloud service or a preinstalled OS disk image.

`select-disk.sh` executes in Debian Installer. Its early-command wrapper must
remain fail-closed, including unexpected failures before a disk is selected.
Do not pre-answer partman's final write confirmations. Existing LVM/RAID is not
automatically removed. `bootstrap.sh` executes on the target OS as root; its
checksum is pinned, tar entries are validated, and success requires HTTP readiness.

Publication uses a separate `usb-v...` prerelease, with `--latest=false` so the
CameraWall updater continues to see application releases. Attach ISO, SHA256SUMS,
BUILD-INFO.json, BOOT-LAYOUT.txt, DEBIAN-SIGNATURE.txt, USB-INSTALL-VI.md and
USB-VALIDATION.md. Compare GitHub's asset digest/size with local SHA-256 and verify
anonymous public release/download links. Do not re-download the ISO solely for
publication verification. No application source or credentials belong in this repo.
