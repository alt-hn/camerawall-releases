#!/bin/sh
set -eu
[ -s /tmp/camerawall-system-disk ]
base=/target/usr/local/lib/camerawall-usb
state=/target/var/lib/camerawall-usb
mkdir -p "$base" "$state/analytics-downloads"
cp /camerawall/release.env /camerawall/root-service.conf /camerawall/provision-analytics.py /camerawall/analytics-downloads.json "$base/"
cp /camerawall/offline-bootstrap.sh "$base/bootstrap.sh"
cp /camerawall/console-ready.sh "$base/console-ready.sh"
chmod 755 "$base/bootstrap.sh" "$base/console-ready.sh"
cp /cw-media/app.tar.gz "$state/app.tar.gz"
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
in-target python3 -c 'import pathlib,secrets,subprocess; p=secrets.token_urlsafe(18); subprocess.run(["chpasswd"],input="cwadmin:"+p+"\n",text=True,check=True); f=pathlib.Path("/var/lib/camerawall-usb/linux-password"); f.touch(mode=0o600); f.write_text(p+"\n")'
# Remove the temporary local installer repository before the first normal boot.
rm -f /target/etc/apt/sources.list.d/camerawall-offline.list
sed -i '\|file:/cw-media|d' /target/etc/apt/sources.list
[ -s /target/boot/grub/grub.cfg ]
printf 'CameraWall offline appliance 1.0.0\n' > /target/camerawall-installed.marker
