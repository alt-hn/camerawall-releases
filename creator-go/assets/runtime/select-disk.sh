#!/bin/sh
# Unattended Debian Installer guard. Never run on the build host.
set -eu
fail() {
 trap - EXIT
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
trap 'fail "Unexpected disk preparation error. See /var/log/syslog (Ctrl+Alt+F4)."' EXIT
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
. /camerawall/mount-media.sh
mount_and_verify_media
logger -t camerawall "Installer media: /cdrom=$media, protected disk=$boot, verified payload=$payload"
disk_unused() {
 local sys node name holders id mountpoint
 sys=$1
 disk_use_reason=
 for node in "$sys" "$sys"/"${sys##*/}"*; do
  [ "$node" = "$sys" ] || [ -f "$node/partition" ] || continue
  name=${node##*/}
  disk_use_reason="cannot inspect /dev/$name"
  holders=$(ls "$node/holders") || return 1
  if [ -n "$holders" ]; then
   disk_use_reason="/dev/$name is used by $(printf '%s' "$holders" | tr '\n' ' ')"
   return 1
  fi
  id=$(cat "$node/dev") || return 1
  # Match the device number even if the filesystem was mounted through an alias.
  mountpoint=$(awk -v id="$id" '$3 == id && !found {print $5; found=1}' /proc/self/mountinfo) || return 1
  if [ -n "$mountpoint" ]; then
   disk_use_reason="/dev/$name is mounted at $mountpoint"
   return 1
  fi
 done
 disk_use_reason=
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
boot_sequence=$(cat "/sys/block/${boot##*/}/diskseq") || fail 'Cannot track the installer disk.'
scan_disks() {
 local sys name dev sectors reason
 [ "$(cat "/sys/block/${boot##*/}/diskseq")" = "$boot_sequence" ] || fail 'The installer disk changed.'
 inventory=$(disk_inventory) || fail 'Cannot track disk identities.'
 excluded=
 : > /tmp/camerawall-disks
 : > /tmp/camerawall-candidates
 : > /tmp/camerawall-manual
 for sys in /sys/block/*; do
  name=${sys##*/}
  case "$name" in sd[a-z]*|nvme[0-9]*n[0-9]*|mmcblk[0-9]*|vd[a-z]*|xvd[a-z]*) ;; *) continue;; esac
  case "$name" in *boot*|*rpmb*) continue;; esac
  dev=/dev/$name
  [ -b "$dev" ] || continue
  echo "$dev" >> /tmp/camerawall-disks
  sectors=$(cat "$sys/size")
  if [ "$dev" = "$boot" ]; then
   reason='protected installer disk'
  else
   printf '%s %s\n' "$sectors" "$dev" >> /tmp/camerawall-manual
   if [ "$(blockdev --getro "$dev")" != 0 ]; then
    reason='read-only or cannot query read-only state'
   elif ! disk_unused "$sys"; then
    reason=$disk_use_reason
   elif [ "$sectors" -lt 50331648 ]; then
    reason='smaller than 24 GiB'
   else
    printf '%s %s\n' "$sectors" "$dev" >> /tmp/camerawall-candidates
    continue
   fi
  fi
  logger -t camerawall "Auto skipped $dev ($((sectors / 2097152)) GiB): $reason"
  if [ "$dev" != "$boot" ]; then
   excluded="${excluded:+$excluded; }$dev: $reason"
  fi
 done
}
mode=automatic
case " $(cat /proc/cmdline) " in
 *' camerawall.disk=manual '*) mode=manual ;;
esac
scan_disks
if [ "$mode" = automatic ] && [ -s /tmp/camerawall-candidates ]; then
 # Equal-sized disks use lexicographic Linux device name as the documented tie-break.
 selected=$(LC_ALL=C sort -k1,1n -k2,2 /tmp/camerawall-candidates | head -n 1)
else
 mode=manual
 cat > /tmp/camerawall-target.templates <<'TEMPLATES'
Template: camerawall/target
Type: select
Choices: ${disks}
Description: Choose installation disk manually
 ${status}
 .
 ${excluded}
 .
 Installer disk: ${boot}. See Ctrl+Alt+F4 for disk detection details.

Template: camerawall/confirm-target
Type: select
Choices: Cancel, Confirm
Description: Erase ${disk} and install CameraWall?
 Confirm erases all data and partitions on this disk.
TEMPLATES
 debconf-loadtemplate camerawall /tmp/camerawall-target.templates || fail 'Cannot load the target disk menu.'
 db_subst camerawall/target boot "$boot" || fail 'Cannot show the protected installer disk.'
 while :; do
  choices='Cancel, Rescan disks'
  status='No destination disk found. Select Rescan disks to check again.'
  if [ -s /tmp/camerawall-manual ]; then
   status='Choose a disk, then confirm to erase it and install CameraWall. Disks smaller than 24 GiB may run out of space.'
   while read -r size disk; do
    choices="$choices, $disk ($((size / 2097152)) GiB)"
   done < /tmp/camerawall-manual
  fi
  db_subst camerawall/target disks "$choices" || fail 'Cannot show available disks.'
  db_subst camerawall/target excluded "${excluded:-No other disks were skipped by automatic selection.}" || fail 'Cannot show excluded disks.'
  db_subst camerawall/target status "$status" || fail 'Cannot show disk scan status.'
  db_set camerawall/target Cancel && db_fset camerawall/target seen false || fail 'Cannot set the safe default.'
  db_input critical camerawall/target && db_go && db_get camerawall/target || fail 'Cannot read target disk selection.'
  case "$RET" in
   Cancel) fail 'Installation canceled before formatting.' ;;
   'Rescan disks') scan_disks ;;
   *)
    selected=$(awk -v disk="${RET%% *}" '$2 == disk {print; exit}' /tmp/camerawall-manual)
    [ -n "$selected" ] || fail 'The selected disk is not eligible.'
    break
    ;;
  esac
 done
fi
sectors=${selected%% *}
target=${selected#* }
[ "$target" != "$boot" ] || fail 'Boot disk exclusion failed.'
[ "$(disk_inventory)" = "$inventory" ] || fail 'A disk changed during target selection.'
if [ "$mode" = manual ]; then
 db_subst camerawall/confirm-target disk "$target ($((sectors / 2097152)) GiB)" || fail 'Cannot show the erase target.'
 db_set camerawall/confirm-target Cancel && db_fset camerawall/confirm-target seen false || fail 'Cannot reset erase confirmation.'
 db_input critical camerawall/confirm-target && db_go && db_get camerawall/confirm-target || fail 'Cannot read erase confirmation.'
 [ "$RET" = Confirm ] || fail 'Installation canceled before formatting.'
 [ "$(disk_inventory)" = "$inventory" ] || fail 'A disk changed during erase confirmation.'
fi
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

if [ "$mode" = automatic ]; then
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
fi
current_inventory=$(disk_inventory) || fail 'Cannot recheck disk identities.'
[ "$current_inventory" = "$inventory" ] || fail 'A disk changed before partitioning.'
if [ "$mode" = automatic ]; then
 disk_unused "/sys/block/${target##*/}" || fail "$disk_use_reason."
elif [ "$(blockdev --getro "$target")" != 0 ]; then
 blockdev --setrw "$target" || fail "Cannot enable writes on $target."
fi
[ "$(blockdev --getro "$target")" = 0 ] || fail "The kernel still reports $target as read-only."
for dev in $(cat /tmp/camerawall-disks) "$boot"; do
 [ "$dev" != "$target" ] || continue
 [ "$(blockdev --getro "$dev")" = 1 ] || fail "Protection was lost for $dev"
done
# Remove the old partition map and filesystem headers before Partman probes the
# confirmed target. Leave creation of the new GPT and EFI filesystem to Debian.
reset_target_layout() {
 local sys sector_size scale blocks edge part start length
 sys="/sys/block/${target##*/}"
 sector_size=$(blockdev --getss "$target") || fail "Cannot read sector size on $target."
 case "$sector_size" in 512|1024|2048|4096) ;; *) fail "Unsupported sector size on $target." ;; esac
 scale=$((sector_size / 512))
 blocks=$((sectors / scale))
 edge=$((1048576 / sector_size))
 [ "$((sectors % scale))" = 0 ] && [ "$blocks" -ge "$((2 * edge))" ] || fail "Invalid disk geometry on $target."
 # Test that the kernel can replace the partition table before erasing anything.
 blockdev --rereadpt "$target" || fail "Cannot reset the partition table on $target. The kernel may still be using it."
 for part in "$sys"/"${target##*/}"*; do
  [ -f "$part/partition" ] || continue
  start=$(cat "$part/start") || fail "Cannot read partition start on $target."
  length=$(cat "$part/size") || fail "Cannot read partition size on $target."
  [ "$start" -gt 0 ] && [ "$length" -gt 0 ] && [ "$length" -le "$((sectors - start))" ] &&
   [ "$((start % scale))" = 0 ] && [ "$((length % scale))" = 0 ] || fail "Invalid partition geometry on $target."
  length=$((length / scale))
  if [ "$length" -gt "$edge" ]; then length=$edge; fi
  dd if=/dev/zero of="$target" bs="$sector_size" seek="$((start / scale))" count="$length" conv=notrunc 2>/dev/null ||
   fail "Cannot clear the old filesystem header on $target."
 done
 dd if=/dev/zero of="$target" bs="$sector_size" count="$edge" conv=notrunc 2>/dev/null &&
  dd if=/dev/zero of="$target" bs="$sector_size" seek="$((blocks - edge))" count="$edge" conv=notrunc 2>/dev/null ||
  fail "Cannot clear the old partition table on $target."
 blockdev --flushbufs "$target" && blockdev --rereadpt "$target" || fail "Cannot reload the cleared partition table on $target."
 for part in "$sys"/"${target##*/}"*; do
  [ ! -f "$part/partition" ] || fail "Old partitions are still visible on $target."
 done
 logger -t camerawall "Cleared old partition table and filesystem headers on $target"
}
reset_target_layout
logger -t camerawall "INSTALL: mode=$mode boot=$boot target=$target sectors=$sectors; all other disks protected"
echo "CameraWall: installing to $target; boot disk $boot is protected." > /dev/console
# Set destructive answers only after resolving boot media and locking other disks.
set_answer() {
 db_set "$1" "$2" && db_fset "$1" seen true || fail "Cannot configure installer question $1."
}
set_answer partman-auto/disk "$target"
set_answer grub-installer/bootdev "$target"
set_answer partman-partitioning/confirm_write_new_label true
set_answer partman/choose_partition finish
set_answer partman/confirm true
set_answer partman/confirm_nooverwrite true
printf '%s\n' "$target" > /tmp/camerawall-system-disk
printf '%s\n' "$boot" > /tmp/camerawall-boot-disk
trap - EXIT
