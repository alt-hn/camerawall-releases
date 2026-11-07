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
disk_unused() {
 local sys dev holders part mounted device
 sys=$1
 dev=$2
 holders=$(ls "$sys/holders") || return 1
 for part in "$sys"/"${dev##*/}"*; do
  [ -f "$part/partition" ] || continue
  [ -z "$holders" ] || return 1
  holders=$(ls "$part/holders") || return 1
 done
 [ -z "$holders" ] || return 1
 # Never overwrite a mounted disk, including a manually attached data filesystem.
 mounted=no
 for device in "$dev" "$dev"[0-9]* "$dev"p[0-9]*; do
  if awk -v d="$device" '$1 == d {found=1} END {exit !found}' /proc/mounts; then mounted=yes; fi
 done
 [ "$mounted" = no ]
}
disk_inventory() {
 local disk sequence
 for disk in /sys/block/*; do
  case "${disk##*/}" in sd[a-z]*|nvme[0-9]*n[0-9]*|mmcblk[0-9]*|vd[a-z]*|xvd[a-z]*|sr*) ;; *) continue;; esac
  [ -b "/dev/${disk##*/}" ] || continue
  sequence=$(cat "$disk/diskseq") || return 1
  printf '%s %s\n' "${disk##*/}" "$sequence"
 done
}
inventory=$(disk_inventory) || fail 'Cannot track disk identities.'
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
 disk_unused "$sys" "$dev" || continue
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
# Show the exact target before providing any destructive answers to partman.
cat > /tmp/camerawall-countdown.templates <<'TEMPLATES'
Template: camerawall/erase-title
Type: text
Description: Erase ${disk} and install CameraWall?

Template: camerawall/erase-countdown
Type: text
Description: All data on ${disk} will be erased in ${seconds} s. Select Cancel to stop.
TEMPLATES
debconf-loadtemplate camerawall /tmp/camerawall-countdown.templates || fail 'Cannot load the erase warning.'
db_subst camerawall/erase-title disk "$target ($((sectors / 2097152)) GiB)" || fail 'Cannot display the selected disk.'
db_subst camerawall/erase-countdown disk "$target" || fail 'Cannot display the selected disk.'
db_capb backup progresscancel || fail 'Cannot enable installer cancellation.'
db_progress START 0 10 camerawall/erase-title || fail 'Cannot start the erase countdown.'
for seconds in 10 9 8 7 6 5 4 3 2 1; do
 db_subst camerawall/erase-countdown seconds "$seconds" || fail 'Cannot update the erase warning.'
 if ! db_progress INFO camerawall/erase-countdown; then
  db_progress STOP || true
  fail 'Installation canceled before formatting.'
 fi
 sleep 1
 if ! db_progress STEP 1; then
  db_progress STOP || true
  fail 'Installation canceled before formatting.'
 fi
done
db_progress STOP || fail 'Cannot close the erase countdown.'
db_capb backup || fail 'Cannot restore installer controls.'
current_inventory=$(disk_inventory) || fail 'Cannot recheck disk identities.'
[ "$current_inventory" = "$inventory" ] || fail 'A disk changed during the countdown.'
disk_unused "/sys/block/${target##*/}" "$target" || fail 'Destination is now in use.'
[ -b "$target" ] && [ "$(blockdev --getro "$target")" = 0 ] || fail 'Target disk changed during the countdown.'
for dev in $(cat /tmp/camerawall-disks) "$boot"; do
 [ "$dev" != "$target" ] || continue
 [ "$(blockdev --getro "$dev")" = 1 ] || fail "Protection was lost for $dev"
done
logger -t camerawall "UNATTENDED: boot=$boot target=$target sectors=$sectors; erasing smallest eligible disk; all others protected"
echo "CameraWall: automatically installing to $target; boot disk $boot is protected." > /dev/console
db_set partman-auto/disk "$target"
db_set grub-installer/bootdev "$target"
# Set destructive answers only after resolving boot media and locking other disks.
db_set partman-partitioning/confirm_write_new_label true
db_set partman/confirm_write_new_label true
db_set partman/choose_partition finish
db_set partman/confirm true
db_set partman/confirm_nooverwrite true
for question in partman-auto/disk grub-installer/bootdev partman-partitioning/confirm_write_new_label partman/confirm_write_new_label partman/choose_partition partman/confirm partman/confirm_nooverwrite; do
 db_fset "$question" seen true
done
printf '%s\n' "$target" > /tmp/camerawall-system-disk
printf '%s\n' "$boot" > /tmp/camerawall-boot-disk
