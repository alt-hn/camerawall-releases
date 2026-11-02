#!/bin/sh
set -eu
[ -s /tmp/camerawall-system-disk ] || exit 1
mkdir -p /target/usr/local/lib/camerawall-usb /target/var/lib/camerawall-usb
cp /cdrom/camerawall/bootstrap.sh /cdrom/camerawall/release.env /target/usr/local/lib/camerawall-usb/
cp /cdrom/camerawall/camerawall-firstboot.service /target/etc/systemd/system/
cp /tmp/camerawall-system-disk /target/var/lib/camerawall-usb/system-disk
chmod 755 /target/usr/local/lib/camerawall-usb/bootstrap.sh
printf 'Acquire::Retries "5";\n' > /target/etc/apt/apt.conf.d/80camerawall-retry
in-target systemctl enable camerawall-firstboot.service
cat > /target/etc/motd <<'MOTD'
CameraWall Internet installer
Check installation: sudo systemctl status camerawall-firstboot
Progress/errors: sudo journalctl -u camerawall-firstboot -b
Retry after restoring Internet: sudo systemctl restart camerawall-firstboot
Ready only when /var/lib/camerawall-usb/complete exists.
LAN address: hostname -I  (open http://IP in your browser)
Admin password: sudo cat /etc/camerawall/initial-admin-password
MOTD
