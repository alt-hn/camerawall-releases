# CameraWall USB 0.3.0 — USB Creator image and root appliance

**This USB automatically ERASES the smallest eligible disk of at least 24 GiB other than the disk it booted from. There is no password prompt, disk selection, ERASE phrase or partition confirmation. Boot it only on a machine you intend to reinstall.**

Connect Ethernet and boot the USB in x86-64 UEFI mode. After a three-second menu countdown, the installer chooses the destination, protects every other disk, installs Debian 12, generates a unique Linux administrator password, reboots and installs pinned CameraWall alpha.40 plus its local CPU AI environment/models. The CameraWall backend runs as root using a persistent service drop-in; its media service retains its separate account. The local display shows the LAN URL and initial passwords when ready.

SSD, rotating HDD, eMMC and a separate USB disk can be destinations. The actual mounted installer medium is resolved to its whole parent disk and excluded; USB transport by itself is not excluded. Equal-sized eligible disks use Linux device-name order. Read-only/mounted disks and active RAID/LVM members are excluded. If boot-media identification or disk protection fails, installation stops before formatting.

Leaving the USB inserted does not cause repeat erasure: its GRUB loader detects the installed-system marker and boots that system. The marker also preserves a completed OS while firstboot downloads are incomplete. A power failure before the marker is written can lead to a fresh installation attempt on the next boot.

[Hướng dẫn flash và sử dụng](https://github.com/alt-hn/camerawall-releases/blob/usb-v0.3.0/docs/USB-INSTALL-VI.md). Attachments include SHA256SUMS, BUILD-INFO.json, boot layout, Debian signature verification and exact validation scope. This prerelease does not change the application latest-release feed.

Application archive remains the existing alpha.40 with source commit `32b0714d9f96db7492c43b077f43bd88bf287358`; no private application source is published or rebuilt. Physical thin-client boot, Secure Boot, ARM, Wi-Fi and real camera capacity are not certified. No physical drive was flashed by this release task.
