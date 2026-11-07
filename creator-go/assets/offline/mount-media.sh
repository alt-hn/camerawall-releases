#!/bin/sh
# Called by the disk guard before it supplies any partitioning answers.
mount_and_verify_media() {
 mkdir -p /cw-media || fail 'Cannot create the offline USB mount point.'
 payload=
 for part in /sys/class/block/"${boot##*/}"/"${boot##*/}"*; do
  [ -f "$part/partition" ] || continue
  dev=/dev/${part##*/}
  label=$(blkid -s LABEL -o value "$dev" || true)
  [ "$label" = CWOFFLIN ] || continue
  [ -z "$payload" ] || fail 'More than one CWOFFLIN partition was found on the installer USB.'
  payload=$dev
 done
 [ -n "$payload" ] || fail "Cannot find the CWOFFLIN partition on $boot."
 mount -t vfat -o ro "$payload" /cw-media || fail "Cannot mount the offline USB partition $payload."
 manifest=/cw-media/SHA256SUMS
 [ -s "$manifest" ] || fail "Checksum list is missing or empty on $payload."
 total=$(wc -l < "$manifest") || fail 'Cannot read the offline USB checksum list.'
 [ "$total" -gt 0 ] || fail 'The offline USB checksum list is incomplete.'
 cat > /tmp/camerawall-media.templates <<'TEMPLATES'
Template: camerawall/verify-media
Type: text
Description: Verifying CameraWall USB files
TEMPLATES
 debconf-loadtemplate camerawall /tmp/camerawall-media.templates || fail 'Cannot load the USB verification screen.'
 db_progress START 0 "$total" camerawall/verify-media || fail 'Cannot show USB verification progress.'
 logger -t camerawall "Verifying $total files on $payload"
 if ! (
  cd /cw-media || exit 1
  checked=0
  # Keep stdin available for replies from debconf.
  while IFS= read -r checksum <&7 || [ -n "$checksum" ]; do
   printf '%s\n' "$checksum" | sha256sum -c - || exit 1
   checked=$((checked + 1))
   db_progress SET "$checked" >/dev/null || exit 1
  done 7< "$manifest"
  [ "$checked" -eq "$total" ]
 ) > /tmp/cw-media-verify.log 2>&1; then
  db_progress STOP || true
  logger -t camerawall "$(tail -n 3 /tmp/cw-media-verify.log)"
  fail "Offline USB verification failed on $payload. See /tmp/cw-media-verify.log."
 fi
 db_progress STOP || fail 'Cannot close the USB verification screen.'
 logger -t camerawall "Verified $total files on $payload"
}
