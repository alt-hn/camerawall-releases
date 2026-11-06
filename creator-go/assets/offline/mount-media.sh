#!/bin/sh
set -eu
media=$(awk '$2 == "/cdrom" {print $1}' /proc/mounts)
media=$(readlink -f "$media")
name=${media##*/}
node=$(readlink -f "/sys/class/block/$name")
if [ -f "/sys/class/block/$name/partition" ]; then name=$(basename "$(dirname "$node")"); fi
[ -b "/dev/$name" ] || exit 1
mkdir -p /cw-media
for part in /sys/class/block/"$name"/"$name"*; do
 [ -f "$part/partition" ] || continue
 dev=/dev/${part##*/}
 label=$(blkid -s LABEL -o value "$dev" || true)
 if [ "$label" = CWOFFLIN ]; then
  mount -t vfat -o ro "$dev" /cw-media
  [ -f /cw-media/SHA256SUMS ] || exit 1
  cd /cw-media
  sha256sum -c SHA256SUMS > /tmp/cw-media-verify.log || exit 1
  exit 0
 fi
done
exit 1
