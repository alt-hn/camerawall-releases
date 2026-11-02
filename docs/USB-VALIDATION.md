# USB installer validation — usb-v0.1.0

Status: validation in progress; not yet published.

Target: Debian 12.15 amd64 netinst, x86-64 UEFI, Ethernet, internal SSD/eMMC;
headless CameraWall v0.1.0-alpha.29, source a1d21d088334a76bf986afd2c271a07a9c9a9381.
The existing application source `main` was clean and equal to fetched `origin/main`
at pinning time. No application source was changed or rebuilt for this installer.
Debian 12 is grounded in the application's prior Debian 12 installation lifecycle
evidence and Debian 12 native binary target, not an assumption about Debian 13.

Recorded pre-release checks:

- Official Debian ISO SHA-256: cd4462c06aa8892e692c0c4b9c17802f38c8ab8690e85cbfb5ccaa5956e9af17.
- Debian SHA256SUMS detached signature verified with CD signing key
  DF9B9C49EAA9298432589D76DA87E80D6294BE9B. See DEBIAN-SIGNATURE.txt.
- Pinned CameraWall AMD64 archive hash, ELF machine type 62, and BUILD-INFO version/source verified.
- Shell syntax and Python compilation passed.
- Development ISO booted in QEMU 11.1.3 TCG x86-64 on Apple Silicon with EDK II UEFI,
  presented the CameraWall GRUB menu, booted Debian Installer from emulated USB,
  configured DHCP and prompted for a Linux account password.
- Disk guard offered only the 32 GiB emulated SSD; 8 GiB rotating recording disk
  and USB installer were marked PROTECTED. Deliberately incorrect erase phrase
  displayed "CameraWall installation stopped safely" / "Erase phrase did not match".
- After stopping that VM, qemu-img compared both guest disks against zero and
  reported identical content (size mismatch expected against /dev/zero): no writes
  before confirmation.

Full install/reboot/HTTP validation will be recorded here before publication.

Not established: physical thin-client boot, real SATA/NVMe/eMMC controller/firmware
compatibility, Secure Boot, Wi-Fi, USB Ethernet, real camera/ONVIF/AI capacity,
physical HDMI, power-loss recovery at every write boundary, prolonged soak or
production deployment. A VM test is not a physical-device qualification.
