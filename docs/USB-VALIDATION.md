# USB installer validation — usb-v0.2.0

Validation date: **2026-11-06, Asia/Ho_Chi_Minh**. Evaluation installer;
physical thin-client qualification and deployment are not claimed.

## Artifact and provenance

- Debian **12.15.0 amd64 netinst**, official ISO SHA-256
  `cd4462c06aa8892e692c0c4b9c17802f38c8ab8690e85cbfb5ccaa5956e9af17`.
- Detached checksum signature verified with Debian CD signing key
  `DF9B9C49EAA9298432589D76DA87E80D6294BE9B`.
- Existing CameraWall **v0.1.0-alpha.29**, archive SHA-256
  `2cb8bee4fb154af3aa753c345c9f9165b903c2de5576a134167423690904fefd`,
  application source `a1d21d088334a76bf986afd2c271a07a9c9a9381`.
  No application source is changed or rebuilt for this installer.
- Pinned OpenCV 4.12.0.88, NumPy 2.0.2, YuNet/SFace/YOLOX models and licenses
  are verified by SHA-256 during provisioning.
- Final ISO verification extracts and compares all runtime payloads and menus
  with committed source. Debian EFI image, kernel and initrd remain byte-identical.
  BUILD-INFO.json records source commit, source cleanliness and ISO digest;
  BOOT-LAYOUT.txt records UEFI El Torito and hybrid MBR/GPT layout.

## Zero-input installation

QEMU 11.1.3, EDK II UEFI, x86-64 TCG on Apple Silicon, 4 CPUs and 2 GiB RAM.
Only disposable disk images were attached; no physical disk was flashed.

Three writable guest disks were present:

| Device during installation | Size | Role |
| --- | --- | --- |
| sda | 48 GiB | Rotating SCSI HDD with an existing sentinel |
| sdb | 24 GiB | Boot USB, intentionally large enough to qualify by size |
| sdc | 32 GiB | Separate USB installation destination |

The default menu timed out and completed Debian installation, partitioning,
Linux account creation, reboot, application download, AI provisioning and READY
without a keypress or mouse click. Installer log selected **sdc**, excluded **sdb**,
and protected all other disks. Root and EFI partitions were read back on sdc.
The 48 GiB HDD compared identical to its pre-install image after shutdown.

The boot USB was never selected or repartitioned. During operation, its EFI FAT
image had one byte changed (sector 2496, offset 37, 0 to 1); after clean shutdown,
all original ISO bytes compared identical again. This is not a claim of zero
firmware writes. The kernel disk guard protects it before partitioning.

A separate VM with only the 24 GiB boot USB stopped at the explicit error:
"No writable, unused destination of at least 24 GiB outside the boot disk."
No fallback destination was selected. No input was supplied to dismiss the error.

## Ready state and subsequent USB boot

- CameraWall and its media service started; firstboot reached READY after pinned
  dependencies and all three models loaded successfully.
- HTTP administrator login returned 200 and a session cookie using the generated
  password. Secret values and cookies are excluded from published evidence.
- Generated Linux password matched the cwadmin shadow hash; its file mode was 0600.
- Local console displayed READY, LAN URL and both initial passwords. Journal
  content was checked for both passwords and did not contain them.
- Reboot retained completion state and credentials. A separate cold boot reset
  UEFI NVRAM to ensure the **installer USB** was first. Firmware readback showed
  BootCurrent pointing to CW-BOOT-24GB; the USB loaded the installed OS through
  its marker. No second installation or selection of the spare HDD occurred.

The full install used a development image of the final successful installation
path. Two subsequent changes were separately exercised: the no-destination error
dialog in the boot-only VM, and the getty Type=exec override in the installed VM
(to prevent Debian's delayed getty startup from clearing credentials on reboot).
The final ISO is rebuilt from clean pushed main and its exact files are verified;
a second complete Debian installation of that final remaster is not claimed.

## Scope and limits

The unchanged bootstrap's download-resume, checksum-rejection, recovery and
restricted-network reboot tests belong to **usb-v0.1.0**, whose validation remains
available under that tag. They are not presented as newly repeated 0.2.0 tests.

Not established: physical thin-client boot, real SATA/NVMe/eMMC controllers or NIC
firmware, Secure Boot, Wi-Fi, USB Ethernet, real camera throughput, recording soak,
physical HDMI or power failure at every write boundary. VM evidence establishes
selection/exclusion and unattended setup, not compatibility with every machine.
Firmware must already prefer USB; Ethernet/DHCP/Internet must work for installation.
A power failure before the installed marker exists may restart installation and
erase the selected disk again. There is no transactional partition rollback.

Publication checks the clean pushed-main tag, all asset SHA-256 digests/sizes,
anonymous public links and unchanged application latest-release feed. The large
published ISO is not downloaded again solely for readback.
