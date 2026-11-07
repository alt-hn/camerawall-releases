#!/bin/bash
# Stage the helper before starting the backend, so the backend's drop-in
# picks up the mount path and starts the helper in the host namespace.
set -Eeuo pipefail
bundle=$1
for tool in lsblk mount umount mkfs.ext4 ip udevadm busctl nmcli; do
 command -v "$tool" >/dev/null || { echo "Missing appliance helper dependency: $tool" >&2; exit 1; }
done
install -d -m 0755 /opt/camerawall/bin /usr/lib/tmpfiles.d /etc/systemd/system/camerawall.service.d
install -m 0755 "$bundle/bin/camerawall-host" /opt/camerawall/bin/camerawall-host.new
mv /opt/camerawall/bin/camerawall-host.new /opt/camerawall/bin/camerawall-host
install -m 0644 "$bundle/deploy/camerawall-host.service" /etc/systemd/system/camerawall-host.service
install -m 0644 "$bundle/deploy/camerawall-host.tmpfiles" /usr/lib/tmpfiles.d/camerawall-host.conf
install -m 0644 "$bundle/deploy/camerawall-host-storage.conf" /etc/systemd/system/camerawall.service.d/host-storage.conf
systemd-tmpfiles --create /usr/lib/tmpfiles.d/camerawall-host.conf
systemctl enable camerawall-host.service
