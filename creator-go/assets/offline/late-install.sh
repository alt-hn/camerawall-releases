#!/bin/sh
set -eu
verify_boot_target() {
 disk=$(cat /tmp/camerawall-system-disk) || return 1
 sequence=$(cat /tmp/camerawall-system-diskseq) || return 1
 [ "$(cat "/sys/block/${disk##*/}/diskseq")" = "$sequence" ] || return 1
 for mount in /target /target/boot/efi; do
  dev=$(awk -v path="$mount" '$5 == path {dev=$3; n++} END {if (n==1) print dev}' /proc/self/mountinfo)
  [ -n "$dev" ] || return 1
  node=$(readlink -f "/sys/dev/block/$dev") || return 1
  [ -f "$node/partition" ] && [ "$(basename "$(dirname "$node")")" = "${disk##*/}" ] || return 1
 done
 [ -s /target/boot/grub/grub.cfg ] || return 1
 [ -s /target/boot/efi/EFI/BOOT/BOOTX64.EFI ] ||
  [ -s /target/boot/efi/EFI/debian/shimx64.efi ] ||
  [ -s /target/boot/efi/EFI/debian/grubx64.efi ]
}
if ! verify_boot_target; then
 logger -t camerawall 'INSTALL STOPPED: system or EFI partition is not on the selected disk, or EFI boot files are missing.'
 echo 'CameraWall: could not verify boot files on the selected disk. See Ctrl+Alt+F4.' > /dev/console
 exit 1
fi
logger -t camerawall "Verified system and EFI partitions on $disk."

# GRUB registers the installed system in BootOrder. Prefer its exact ESP for
# the first reboot, even if the firmware has an older BootNext value.
target_efibootmgr() {
 # Debian Installer mounts a fresh sysfs for in-target and unmounts its
 # children afterward. Mount efivarfs within that same invocation.
 in-target --pass-stdout sh -c '
  vars=/sys/firmware/efi/efivars
  mountpoint -q "$vars" || mount -t efivarfs efivarfs "$vars" || exit 1
  exec efibootmgr "$@"
 ' sh "$@"
}
prefer_installed_efi() {
 esp_uuid=$(in-target --pass-stdout blkid -s PARTUUID -o value "/dev/${node##*/}") || return 1
 [ -n "$esp_uuid" ] || return 1
 entries=$(target_efibootmgr -v) || return 1
 entry=$(printf '%s\n' "$entries" | awk -v uuid="$esp_uuid" '
  /^Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\*/ {
   line=tolower($0)
   if (index(line, ",gpt," tolower(uuid) ",") &&
       line ~ /file\(\\efi\\debian\\(shim|grub)x64[.]efi\)/) {
    print substr($0,5,4)
    exit
   }
  }')
 [ -n "$entry" ] && target_efibootmgr --bootnext "$entry"
}
if ! prefer_installed_efi; then
 logger -t camerawall "Could not set the one-time UEFI boot target for $disk; select it in the firmware boot menu if necessary."
fi
base=/target/usr/local/lib/camerawall-usb
state=/target/var/lib/camerawall-usb
mkdir -p "$base" "$state/analytics-downloads"
cp /camerawall/release.env /camerawall/root-service.conf /camerawall/provision-analytics.py /camerawall/analytics-downloads.json "$base/"
cp /camerawall/install-display-runtime.sh /camerawall/install-host-runtime.sh "$base/"
cp /camerawall/offline-bootstrap.sh "$base/bootstrap.sh"
cp /camerawall/console-ready.sh "$base/console-ready.sh"
chmod 755 "$base/bootstrap.sh" "$base/console-ready.sh"
cp /cw-media/app.tar.gz /cw-media/display.tar.gz "$state/"
cp /cw-media/analytics/* "$state/analytics-downloads/"
cp /camerawall/camerawall-firstboot.service /target/etc/systemd/system/
cp /camerawall/camerawall-console.service /target/etc/systemd/system/
mkdir -p /target/etc/systemd/system/getty@tty1.service.d
printf '[Service]\nType=exec\n' > /target/etc/systemd/system/getty@tty1.service.d/camerawall.conf
# A fresh appliance gets DHCP when Ethernet is later connected; offline setup
# does not wait for a network. Never applied to the creator host.
printf 'camerawall\n' > /target/etc/hostname
mkdir -p /target/etc/network
printf 'auto lo\niface lo inet loopback\n' > /target/etc/network/interfaces
in-target systemctl enable NetworkManager camerawall-firstboot.service camerawall-console.service
in-target systemctl disable NetworkManager-wait-online.service
in-target python3 -c 'import pathlib,secrets,subprocess; p="".join(secrets.choice("abcdefghijkmnpqrstuvwxyz") for _ in range(8)); subprocess.run(["chpasswd"],input="cwadmin:"+p+"\n",text=True,check=True); f=pathlib.Path("/var/lib/camerawall-usb/linux-password"); f.touch(mode=0o600); f.write_text(p+"\n")'
# Package installation is complete. Replace the installer's CD-ROM and
# temporary file sources with the appliance's normal Debian repositories.
rm -f /target/etc/apt/sources.list.d/camerawall-offline.list
cat > /target/etc/apt/sources.list <<'APT'
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian bookworm main non-free-firmware
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian bookworm-updates main non-free-firmware
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian-security bookworm-security main non-free-firmware
APT
printf 'CameraWall offline appliance 1.0.0\n' > /target/camerawall-installed.marker

# Preserve the USB recovery marker even if generating the boot-check entries fails.
mkdir -p /target/etc/default/grub.d
cat > /target/etc/default/grub.d/99-camerawall-bootcheck.cfg <<'GRUB'
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX camerawall.bootcheck=1 "'$cw_installer_boot_arg'
GRUB
if ! in-target update-grub; then
 logger -t camerawall 'Could not generate boot verification entries. USB recovery remains available.'
fi
