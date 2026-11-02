# USB installer validation — usb-v0.1.0

Validation date: **2026-11-03, Asia/Ho_Chi_Minh**. Evaluation prerelease;
physical thin-client qualification and deployment are not claimed.

## Artifact and provenance

- Debian **12.15.0 amd64 netinst**, official ISO SHA-256
  `cd4462c06aa8892e692c0c4b9c17802f38c8ab8690e85cbfb5ccaa5956e9af17`.
- Detached Debian SHA256SUMS signature verified using CD signing key
  `DF9B9C49EAA9298432589D76DA87E80D6294BE9B`; see DEBIAN-SIGNATURE.txt.
- CameraWall **v0.1.0-alpha.29**, archive SHA-256
  `2cb8bee4fb154af3aa753c345c9f9165b903c2de5576a134167423690904fefd`,
  source `a1d21d088334a76bf986afd2c271a07a9c9a9381`.
  Archive BUILD-INFO and AMD64 ELF machine type 62 were verified.
- Application `main` was clean and equal to fetched `origin/main` when this release
  was pinned. No application source was changed or rebuilt. Debian 12 selection
  is grounded in the application's Debian 12 installation lifecycle evidence and
  Debian 12 native binary target; no Debian 13 compatibility is assumed.
- OpenCV 4.12.0.88 / NumPy 2.0.2 Linux x86-64 wheels, YuNet/SFace/YOLOX models and
  upstream model license files were downloaded and checked against pinned SHA-256.
  URLs/hashes are in BUILD-INFO.json and `usb/analytics-downloads.json`.
- xorriso reports UEFI El Torito plus hybrid MBR/GPT USB layout. EFI boot image,
  kernel and initrd are byte-identical to Debian's originals. Runtime payload,
  boot menus and installer source marker are inspected from the built ISO.
- Complete remastered media manifest verified: **979 files**. SHA-256 is the
  external integrity check; Debian's internal MD5 manifest is retained/updated
  only for its media consistency checker.
- Shell syntax, Python compilation and git diff whitespace checks passed.

## VM installation and disk protection

QEMU **11.1.3**, TCG x86-64 software emulation on Apple Silicon, EDK II UEFI,
2 GiB RAM, 4 virtual CPUs for the completed run; emulated USB image,
32 GiB non-rotating SCSI system disk and separate 8 GiB rotating recording disk.
No physical disk was attached, flashed or partitioned.

- Booted the ISO as USB storage into the CameraWall GRUB menu and Debian Installer.
- DHCP worked; Linux administrator password was requested interactively.
- Disk selector displayed model/serial/capacity and offered only the system SSD.
  USB and rotating recording disk were protected.
- A deliberately wrong erase phrase in an earlier development-image run stopped
  installation with "Erase phrase did not match" and no fallback disk. Both guest
  disks remained all-zero according to qemu-img comparison after stopping that VM.
- In the completed run, kernel readback after explicit confirmation was:
  `/dev/sda` selected, `sda ro=0`, `sdb ro=1`, `sdc ro=1`.
- Debian's separate final write confirmation listed only sda partitions:
  EFI System Partition, ext4 root and swap. No automatic confirmation was supplied.
- Completed Debian installation, official mirror security updates, FFmpeg and
  required packages, GRUB and firstboot-service installation.
- Shut down/remounted the VM configuration without USB and booted the installed
  SSD through `EFI/debian/shimx64.efi`. Installed kernel was **6.1.0-54-amd64**,
  Debian **6.1.190-1**. Future installs receive Debian 12 packages current at that time.
- After the full installation and recovery tests, the entire recording guest disk
  still compared identical to zero. The size-mismatch note is expected when
  comparing a fixed-size guest image with `/dev/zero`; no disk-content difference.
  This uses a synthetic empty recording disk, not a real recording library.

## Firstboot, usable service and recovery

- On the newly installed Debian OS, firstboot fetched the existing CameraWall
  release and all pinned AI files, verified them, installed the local environment,
  loaded all three models and installed/started CameraWall. It reached `READY`.
- Host-forwarded HTTP returned **200**, and bundled JavaScript/CSS assets were
  retrieved successfully. Administrator API login returned **200** and a session
  cookie; password and cookie values were not logged.
- `camerawall` and `camerawall-media` were active. The auto-download timer was disabled.
- Under the unprivileged `camerawall` user, OpenCV/NumPy imported, all models loaded,
  and YuNet processed a blank synthetic frame. This is runtime/permissions evidence,
  not recognition accuracy or real-camera throughput evidence.
- Controlled download interruption on the build host stopped a real GitHub release
  transfer after **2,191,969 bytes**; HTTP Range resume completed and SHA-256 matched.
- In the disposable guest, a deliberately incorrect expected CameraWall hash caused
  firstboot to fail, with explicit checksum-mismatch output. Installed binary mtime
  was unchanged and no success marker was written. The wrong hash was then removed.
- Restarting firstboot with the correct manifest reused verified cache, preserved
  existing application state/credentials and returned to `READY` without partitioning.

The full OS install used the ISO from installer commit `5baa367`. The final
bootstrap only changes expected cache-miss logging; that exact final bootstrap
was installed into the disposable guest and exercised by the checksum-failure and
recovery tests. Its SHA-256 was read back as
`a2673e21375e91a8d21fcf20016e76582b36cfec2192636c8639a59f8baa9780`, matching source.
Final ISO runtime files are re-extracted and compared to the final committed source;
BOOT-LAYOUT.txt / BUILD-INFO.json describe the final artifact, not a development ISO.

## Offline reboot

Rebooted the installed SSD with **no USB** and QEMU user networking
`restrict=on` (only the explicit host HTTP forward retained). An outbound HTTPS
request to deb.debian.org failed within the configured timeout, confirming the
restricted connection. Host-forwarded HTTP returned 200 and administrator API
login succeeded using the preserved password. Both application/media services
were active; firstboot reported `ConditionResult=no`, `ActiveState=inactive`
because the persisted completion marker existed. The update-download timer
remained disabled. The disposable VM was then powered off.

## Limits

Not established: physical thin-client boot, real SATA/NVMe/eMMC controller or NIC
firmware compatibility, Secure Boot, Wi-Fi, USB Ethernet, real RTSP/ONVIF camera
operation in this VM, sustained recording/AI capacity, physical HDMI, power-loss
recovery at every write boundary, prolonged soak or production deployment.

No blanket rollback is promised. Loss of power after disk-write confirmation can
leave a partially installed OS. Download errors after OS installation can be
retried through the service; application state created only partially by an
interruption may require individual diagnosis. See USB-INSTALL-VI.md.

Publication verification checks the clean pushed-main tag, GitHub asset SHA-256
and sizes, anonymous public links, and that the application latest-release feed
is unchanged. The large published ISO is not downloaded again just for readback.
