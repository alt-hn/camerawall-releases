#!/bin/sh
set -eu
[ -s /tmp/camerawall-system-disk ]
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
[ -s /target/boot/grub/grub.cfg ]
printf 'CameraWall offline appliance 1.0.0\n' > /target/camerawall-installed.marker

# Preserve the USB recovery marker even if generating the boot-check entries fails.
mkdir -p /target/etc/default/grub.d
cat > /target/etc/default/grub.d/99-camerawall-bootcheck.cfg <<'GRUB'
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX camerawall.bootcheck=1 "'$cw_installer_boot_arg'
GRUB
if ! in-target update-grub; then
 logger -t camerawall 'Could not generate boot verification entries. USB recovery remains available.'
fi
