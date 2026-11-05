#!/bin/sh
# Unattended Debian Installer guard. Never run on the build host.
set -eu
fail() {
 logger -t camerawall "INSTALL STOPPED: $*"
 echo "CameraWall INSTALL STOPPED: $*" > /dev/console
 # Replace the progress box with a visible terminal error; no answer can
 # resume disk selection or formatting after this guard has rejected the machine.
 cat > /tmp/camerawall-error.templates <<'TEMPLATES'
Template: camerawall/automatic-error
Type: error
Description: CameraWall automatic installation stopped
 ${reason}
 .
 No fallback disk will be erased. Power off and correct the disk/boot setup.
TEMPLATES
 debconf-loadtemplate camerawall /tmp/camerawall-error.templates || true
 db_subst camerawall/automatic-error reason "$*" || true
 db_input critical camerawall/automatic-error || true
 db_go || true
 # An early_command failure must never fall through to partman's default disk.
 while :; do sleep 3600; done
}
. /usr/share/debconf/confmodule
[ -d /sys/firmware/efi ] || fail 'UEFI boot is required.'
command -v blockdev >/dev/null || fail 'Cannot enforce disk protection.'
# Resolve the actual mounted installer device to its whole physical disk. Do not
# guess by USB transport: a different USB drive is a legitimate installation target.
media=$(awk '$2 == "/cdrom" {print $1}' /proc/mounts)
[ -n "$media" ] || fail 'Cannot identify the mounted installer medium.'
media=$(readlink -f "$media")
name=${media##*/}
[ -e "/sys/class/block/$name" ] || fail 'Installer medium is not a block device.'
node=$(readlink -f "/sys/class/block/$name")
if [ -f "/sys/class/block/$name/partition" ]; then name=$(basename "$(dirname "$node")"); fi
case "$name" in sd*|nvme*|mmcblk*|vd*|xvd*|sr*) ;; *) fail 'Loop/mapper/network boot is unsupported; flash the ISO directly.';; esac
boot=/dev/$name
[ -b "$boot" ] || fail 'Cannot resolve the installer parent disk.'
: > /tmp/camerawall-disks
: > /tmp/camerawall-candidates
for sys in /sys/block/*; do
 name=${sys##*/}
 case "$name" in sd[a-z]*|nvme[0-9]*n[0-9]*|mmcblk[0-9]*|vd[a-z]*|xvd[a-z]*) ;; *) continue;; esac
 case "$name" in *boot*|*rpmb*) continue;; esac
 dev=/dev/$name
 [ -b "$dev" ] || continue
 echo "$dev" >> /tmp/camerawall-disks
 [ "$dev" != "$boot" ] || continue
 [ "$(blockdev --getro "$dev")" = 0 ] || continue
 sectors=$(cat "$sys/size")
 [ "$sectors" -ge 50331648 ] || continue # 24 GiB, regardless of SSD/HDD/USB transport
 holders=$(ls "$sys/holders")
 for part in "$sys"/"$name"*; do
  [ -f "$part/partition" ] || continue
  holders="$holders$(ls "$part/holders")"
 done
 [ -z "$holders" ] || continue
 # Never overwrite a mounted disk, including a manually attached data filesystem.
 mounted=no
 for device in "$dev" "$dev"[0-9]* "$dev"p[0-9]*; do
  if awk -v d="$device" '$1 == d {found=1} END {exit !found}' /proc/mounts; then mounted=yes; fi
 done
 [ "$mounted" = no ] || continue
 printf '%s %s\n' "$sectors" "$dev" >> /tmp/camerawall-candidates
done
[ -s /tmp/camerawall-candidates ] || fail 'No writable, unused destination of at least 24 GiB outside the boot disk.'
# Equal-sized disks use lexicographic Linux device name as the documented tie-break.
selected=$(LC_ALL=C sort -k1,1n -k2,2 /tmp/camerawall-candidates | head -n 1)
sectors=${selected%% *}
target=${selected#* }
[ "$target" != "$boot" ] || fail 'Boot disk exclusion failed.'
# Protect the boot device and all unselected whole disks AND their partitions.
for dev in $(cat /tmp/camerawall-disks) "$boot"; do
 [ "$dev" != "$target" ] || continue
 name=${dev##*/}
 for p in /sys/block/"$name"/"$name"*; do
  [ -f "$p/partition" ] || continue
  blockdev --setro "/dev/${p##*/}" || fail "Cannot protect $p"
 done
 blockdev --setro "$dev" || fail "Cannot protect $dev"
 [ "$(blockdev --getro "$dev")" = 1 ] || fail "Cannot verify protection for $dev"
done
[ "$(blockdev --getro "$target")" = 0 ] || fail 'Destination became read-only.'
logger -t camerawall "UNATTENDED: boot=$boot target=$target sectors=$sectors; erasing smallest eligible disk; all others protected"
echo "CameraWall: automatically installing to $target; boot disk $boot is protected." > /dev/console
db_set partman-auto/disk "$target"
db_set grub-installer/bootdev "$target"
# Set destructive answers only after resolving boot media and locking other disks.
db_set partman-partitioning/confirm_write_new_label true
db_set partman/choose_partition finish
db_set partman/confirm true
db_set partman/confirm_nooverwrite true
for question in partman-auto/disk grub-installer/bootdev partman-partitioning/confirm_write_new_label partman/choose_partition partman/confirm partman/confirm_nooverwrite; do
 db_fset "$question" seen true
done
printf '%s\n' "$target" > /tmp/camerawall-system-disk
printf '%s\n' "$boot" > /tmp/camerawall-boot-disk
