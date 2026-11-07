#!/bin/sh
set -eu
[ -s /tmp/camerawall-system-disk ] || exit 1
mkdir -p /target/usr/local/lib/camerawall-usb /target/var/lib/camerawall-usb
cp /cdrom/camerawall/bootstrap.sh /cdrom/camerawall/root-service.conf /cdrom/camerawall/latest-release.py /cdrom/camerawall/install-display-runtime.sh /cdrom/camerawall/install-host-runtime.sh /target/usr/local/lib/camerawall-usb/
cp /cdrom/camerawall/provision-analytics.py /cdrom/camerawall/analytics-downloads.json /target/usr/local/lib/camerawall-usb/
cp /cdrom/camerawall/camerawall-firstboot.service /target/etc/systemd/system/
cp /tmp/camerawall-system-disk /target/var/lib/camerawall-usb/system-disk
chmod 755 /target/usr/local/lib/camerawall-usb/bootstrap.sh
printf 'Acquire::Retries "5";\n' > /target/etc/apt/apt.conf.d/80camerawall-retry
cp /cdrom/camerawall/console-ready.sh /target/usr/local/lib/camerawall-usb/
chmod 755 /target/usr/local/lib/camerawall-usb/console-ready.sh
cp /cdrom/camerawall/camerawall-console.service /target/etc/systemd/system/
# Wait until agetty has acquired/cleared tty1 before displaying credentials.
# Debian's Type=idle can otherwise clear them after our boot job finishes.
mkdir -p /target/etc/systemd/system/getty@tty1.service.d
printf '[Service]\nType=exec\n' > /target/etc/systemd/system/getty@tty1.service.d/camerawall.conf
# Let NetworkManager manage Ethernet DHCP on this fresh appliance.
printf 'auto lo\niface lo inet loopback\n' > /target/etc/network/interfaces
in-target systemctl enable NetworkManager camerawall-firstboot.service camerawall-console.service
cat > /target/etc/motd <<'MOTD'
CameraWall Internet installer
Check installation: sudo systemctl status camerawall-firstboot
Progress/errors: sudo journalctl -u camerawall-firstboot -b
Retry after restoring Internet: sudo systemctl restart camerawall-firstboot
Ready only when /var/lib/camerawall-usb/complete exists.
LAN address: hostname -I  (open http://IP in your browser)
Admin password: sudo /opt/camerawall/bin/camerawall --show-initial-password
MOTD

# Generate a unique machine-local Linux password without a prompt or shared default.
in-target python3 -c 'import os,pathlib,secrets,subprocess; p="".join(secrets.choice("abcdefghijkmnpqrstuvwxyz") for _ in range(8)); subprocess.run(["chpasswd"],input="cwadmin:"+p+"\n",text=True,check=True); f=pathlib.Path("/var/lib/camerawall-usb/linux-password"); f.touch(mode=0o600); f.write_text(p+"\n")'
# GRUB on the USB detects this marker on subsequent boots and loads the installed
# system. Write only after the OS bootloader and firstboot service exist.
[ -s /target/boot/grub/grub.cfg ] || exit 1
printf 'CameraWall unattended installer 0.3.0\n' > /target/camerawall-installed.marker

# Preserve the USB recovery marker even if generating the boot-check entries fails.
mkdir -p /target/etc/default/grub.d
cat > /target/etc/default/grub.d/99-camerawall-bootcheck.cfg <<'GRUB'
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX camerawall.bootcheck=1 "'$cw_installer_boot_arg'
GRUB
if ! in-target update-grub; then
 logger -t camerawall 'Could not generate boot verification entries. USB recovery remains available.'
fi
