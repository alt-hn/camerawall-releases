# CameraWall USB installer 0.1.0 — evaluation prerelease

Bootable USB image for **x86-64 UEFI thin clients with Ethernet and an internal SSD/eMMC**. It installs Debian 12 from official Debian media/mirrors, then downloads the existing CameraWall **v0.1.0-alpha.29** release from GitHub. No custom cloud service or preinstalled OS disk image is required.

- Explicit system-disk choice, model/serial/capacity readback, typed ERASE phrase and Debian's final partition confirmation. USB/removable/rotating disks cannot be selected; unselected disks are set read-only during installation. Disconnect recording/backup disks before installing.
- Creates a user-chosen Linux administrator password; installs and starts headless CameraWall. Native HDMI/desktop is not installed.
- Provisions pinned CPU OpenCV/NumPy and YuNet/SFace/YOLOX models, with checksum validation, for local operation after installation. No inference-time model downloads.
- Cached downloads support retries/resume. Failure remains visible in systemd logs; restarting the firstboot service does not repartition disks. Successful setup requires HTTP readiness.
- Verifies official Debian CD signing key/checksum, signed Debian packages, and pinned SHA-256/source provenance for CameraWall. All dependency/model URLs and hashes are in BUILD-INFO.json and the source.
- No recording HDD format/mount, no unreleased admin HDD/network features, no real-device flashing or deployment is performed by publishing this release.

**Start here:** [Hướng dẫn flash USB, cài đặt và phục hồi (Windows/macOS/Linux)](https://github.com/alt-hn/camerawall-releases/blob/usb-v0.1.0/docs/USB-INSTALL-VI.md). Download the ISO and SHA256SUMS; verify the checksum before flashing. Both flashing USB and installing onto the chosen system disk erase that respective disk.

Read attached **USB-VALIDATION.md** for exact VM checks and unverified physical-device limits. Secure Boot, ARM, Wi-Fi, real thin-client storage/NIC compatibility, camera capacity and physical HDMI are not certified. This USB release is separate from application updates and does not replace the application's latest-release feed.

Application source commit: `a1d21d088334a76bf986afd2c271a07a9c9a9381` (existing alpha.29 binary; application source remains private).
Installer source: this release's `usb-v0.1.0` tag, built from clean pushed `main`; exact commit and image SHA-256 in **BUILD-INFO.json**.
