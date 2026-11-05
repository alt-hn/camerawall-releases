# CameraWall unattended USB installer 0.2.0

Build with Python 3.9+, curl, GnuPG and xorriso: `python3 usb/build.py`.
Inspect the actual ISO with `python3 usb/verify.py`. Publish with
`python3 usb/publish.py` only from clean, committed, pushed main. The script
refuses to overwrite a public tag and keeps the application latest feed intact.

The USB automatically boots the installer after 3 seconds. No input is required
on a working x86-64 UEFI machine with Ethernet/DHCP/Internet. It automatically
ERASES the smallest eligible non-boot disk (at least 24 GiB); equal sizes use
Linux device-name order. HDD, SSD, eMMC and separate USB disks are supported
candidates. All unselected disks are protected read-only. An unresolvable boot
medium, no eligible destination or a disk-protection failure stops installation.
Active RAID/LVM, mounted disks, optical media and read-only devices are not targets.

The mounted `/cdrom` block device is resolved to its whole parent disk. Never
replace this with a transport heuristic that excludes all USB devices or with
a guess such as `/dev/sda`. Destructive partman confirmations are supplied only
after this guard succeeds. The mounted installer USB is always excluded.

A unique Linux password is created on the target; initial Linux/web credentials
are shown only on the attached local display. No shared password is embedded.
The installed root marker lets USB GRUB load the installed OS on later boots,
so leaving USB inserted does not reformat the system. A marker is written only
once GRUB and firstboot services exist. A power cut before that point may lead
to another install attempt on the next boot; it is not a transactional rollback.

Pinned CameraWall alpha.29 and AI components are downloaded during firstboot,
with checksums, retries and resumable cache. They run locally after completion.
Application source remains private and is not rebuilt or republished by this USB.

See `../docs/USB-INSTALL-VI.md`, `USB-VALIDATION.md` and `USB-RELEASE-NOTES.md`.
No build/publish script writes a physical drive. VM disks are disposable files.
