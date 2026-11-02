#!/bin/sh
# Runs inside Debian Installer, never on the build host.
set -eu
. /usr/share/debconf/confmodule
cat > /tmp/camerawall.templates <<'TEMPLATES'
Template: camerawall/disk
Type: select
Choices: ${choices}
Description: Choose the SYSTEM SSD/eMMC to ERASE
 ${inventory}
 .
 ALL partitions and ALL data on the chosen disk will be lost. Disconnect recording disks and backups before proceeding. USB, removable media and rotating HDDs cannot be selected. Other disks will be made read-only for this installer session.

Template: camerawall/erase
Type: string
Description: Permanent data loss: confirm the exact system disk
 ${identity}
 .
 To erase this entire disk, type exactly: ${phrase}
 .
 An empty or incorrect answer aborts installation. Debian will also ask you to confirm writing the partition table.

Template: camerawall/error
Type: error
Description: CameraWall installation stopped safely
 ${reason}
 .
 No automatic fallback disk will be used. Power off, remove recording drives and check the hardware, then start again. Do not continue with manual partitioning.
TEMPLATES
debconf-loadtemplate camerawall /tmp/camerawall.templates
fail() {
 db_subst camerawall/error reason "$*"
 db_input critical camerawall/error || true
 db_go || true
 # Fail closed: keep partman from continuing after an early_command error.
 while :; do sleep 3600; done
}
[ -d /sys/firmware/efi ] || fail 'UEFI boot is required. Legacy BIOS is unsupported.'
command -v blockdev >/dev/null || fail 'blockdev is unavailable; disk protection cannot be applied.'
: > /tmp/camerawall-candidates
: > /tmp/camerawall-disks
inventory=''
choices=''
for sys in /sys/block/*; do
 name=${sys##*/}
 case "$name" in sd[a-z]*|nvme[0-9]*n[0-9]*|mmcblk[0-9]) ;; *) continue;; esac
 [ -f "$sys/partition" ] && continue
 dev=/dev/$name
 [ -b "$dev" ] || continue
 echo "$dev" >> /tmp/camerawall-disks
 path=$(readlink -f "$sys")
 removable=$(cat "$sys/removable")
 rotational=$(cat "$sys/queue/rotational")
 sectors=$(cat "$sys/size")
 model=$(cat "$sys/device/model" 2>/dev/null || echo eMMC)
 serial=$(cat "$sys/device/serial" 2>/dev/null || true)
 if [ -z "$serial" ] && command -v udevadm >/dev/null; then
  serial=$(udevadm info --query=property --name="$dev" 2>/dev/null | sed -n 's/^ID_SERIAL_SHORT=//p')
 fi
 serial=${serial:-unavailable}
 gib=$((sectors / 2097152))
 status=PROTECTED
 case "$path" in */usb[0-9]*/*) usb=yes;; *) usb=no;; esac
 if [ "$usb" = no ] && [ "$removable" = 0 ] && [ "$rotational" = 0 ] && [ "$gib" -ge 24 ]; then
  # Reject disks involved in active MD/DM stacks. Never remove existing RAID/LVM automatically.
  holders=$(ls "$sys/holders")
  for part in "$sys"/"$name"*; do
   [ -f "$part/partition" ] || continue
   holders="$holders$(ls "$part/holders")"
  done
  if [ -z "$holders" ]; then
   status=ELIGIBLE
   echo "$dev" >> /tmp/camerawall-candidates
   choices="${choices:+$choices, }$dev"
  fi
 fi
 inventory="$inventory [$dev: ${gib}GiB model=$model serial=$serial $status]"
done
[ -s /tmp/camerawall-candidates ] || fail "No eligible internal SSD/eMMC (minimum 24 GiB). $inventory"
db_subst camerawall/disk choices "$choices"
db_subst camerawall/disk inventory "$inventory"
db_fset camerawall/disk seen false
db_input critical camerawall/disk || true
db_go || fail 'Disk selection cancelled.'
db_get camerawall/disk
target=$RET
grep -Fxq "$target" /tmp/camerawall-candidates || fail 'No valid system disk selected.'
name=${target##*/}
sectors=$(cat /sys/block/"$name"/size)
phrase="ERASE $target $sectors"
db_subst camerawall/erase identity "$inventory Selected: $target. Existing operating systems, recordings and files on this disk will be destroyed."
db_subst camerawall/erase phrase "$phrase"
db_set camerawall/erase ''
db_fset camerawall/erase seen false
db_input critical camerawall/erase || true
db_go || fail 'Erase confirmation cancelled.'
db_get camerawall/erase
[ "$RET" = "$phrase" ] || fail 'Erase phrase did not match.'
# Lock every unselected disk and its partitions, including the installer USB.
while read -r dev; do
 [ "$dev" = "$target" ] && continue
 name=${dev##*/}
 for p in /sys/block/"$name"/"$name"*; do
  [ -f "$p/partition" ] || continue
  blockdev --setro "/dev/${p##*/}" || fail "Cannot protect partition $p"
 done
 blockdev --setro "$dev" || fail "Cannot protect $dev"
 [ "$(blockdev --getro "$dev")" = 1 ] || fail "Read-only verification failed for $dev"
done < /tmp/camerawall-disks
[ "$(blockdev --getro "$target")" = 0 ] || fail 'Selected system disk is read-only.'
db_set partman-auto/disk "$target"
db_set grub-installer/bootdev "$target"
printf '%s\n' "$target" > /tmp/camerawall-system-disk
logger -t camerawall "User explicitly confirmed erasure of $target ($sectors sectors); other disks protected"
