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
Description: CameraWall setup stopped
 ${reason}
 .
 Setup has stopped. Correct the problem and restart from the installer USB.
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
target_swap_devices() {
 local sys source type path node rest
 sys=$1
 while read -r source type rest; do
  [ "$type" = partition ] || continue
  path=$(readlink -f "$source") || continue
  node=${path##*/}
  if [ "$node" = "${sys##*/}" ] || [ -f "$sys/$node/partition" ]; then
   printf '%s\n' "$path"
  fi
 done < /proc/swaps
}
disk_unused() {
 local sys node name holders id mountpoint swaps
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
 swaps=$(target_swap_devices "$sys") || { disk_use_reason="cannot inspect active swap on ${sys##*/}"; return 1; }
 if [ -n "$swaps" ]; then
  disk_use_reason="active swap: $(printf '%s' "$swaps" | tr '\n' ' ')"
  return 1
 fi
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
 local sys name dev sectors reason kind model transport priority
 [ "$(cat "/sys/block/${boot##*/}/diskseq")" = "$boot_sequence" ] || fail 'The installer disk changed.'
 inventory=$(disk_inventory) || fail 'Cannot track disk identities.'
 : > /tmp/camerawall-disks
 : > /tmp/camerawall-targets
 : > /tmp/camerawall-auto-targets
 choices='Cancel, Rescan disks'
 status=
 for sys in /sys/block/*; do
  name=${sys##*/}
  case "$name" in sd[a-z]*|nvme[0-9]*n[0-9]*|mmcblk[0-9]*|vd[a-z]*|xvd[a-z]*) ;; *) continue;; esac
  case "$name" in *boot*|*rpmb*) continue;; esac
  dev=/dev/$name
  [ -b "$dev" ] || continue
  echo "$dev" >> /tmp/camerawall-disks
  [ "$dev" != "$boot" ] || continue
  sectors=$(cat "$sys/size")
  [ "$sectors" -gt 0 ] || continue
  case "$(cat "$sys/queue/rotational")" in
   0) kind='SSD/flash' ;;
   1) kind='HDD' ;;
   *) kind='Disk' ;;
  esac
  model=$(cat "$sys/device/model" 2>/dev/null | LC_ALL=C tr -cd 'A-Za-z0-9 ._-' | cut -c1-24)
  reason=Ready
  if [ "$(blockdev --getro "$dev")" != 0 ]; then
   reason='read-only'
  elif ! disk_unused "$sys"; then
   reason='busy'
   logger -t camerawall "$dev: $disk_use_reason"
  elif [ "$sectors" -lt 50331648 ]; then
   reason='under 24 GiB'
  fi
  printf '%s %s\n' "$sectors" "$dev" >> /tmp/camerawall-targets
  # Prefer internal solid-state storage, then internal HDD, then external disks.
  # Busy/read-only status never changes this ranking.
  priority=2
  [ "$kind" != 'SSD/flash' ] || priority=0
  transport=$(readlink -f "$sys") || fail "Cannot identify the connection for $dev."
  case "$transport" in */usb*) priority=$((priority + 10)) ;; esac
  if [ "$(cat "$sys/removable")" = 1 ]; then priority=$((priority + 20)); fi
  if [ "$sectors" -ge 50331648 ]; then
   printf '%s %s %s\n' "$priority" "$sectors" "$dev" >> /tmp/camerawall-auto-targets
  fi
  choices="$choices, $dev | $kind ${model:+$model }| $((sectors / 2097152)) GiB | $reason"
 done
 [ -s /tmp/camerawall-targets ] || status='No destination disk found. Check the connection or firmware, then rescan.'
}
check_inventory() {
 local current
 current=$(disk_inventory) || fail 'Cannot recheck disk identities.'
 [ "$current" = "$inventory" ] || fail 'A disk changed. Restart setup and select the disk again.'
}
protect_other_disks() {
 local dev name p
 check_inventory
 while read -r dev; do
  [ "$dev" != "$target" ] || continue
  name=${dev##*/}
  for p in /sys/block/"$name"/"$name"*; do
   [ -f "$p/partition" ] || continue
   blockdev --setro "/dev/${p##*/}" &&
    [ "$(blockdev --getro "/dev/${p##*/}")" = 1 ] || fail "Cannot protect /dev/${p##*/}."
  done
  blockdev --setro "$dev" &&
   [ "$(blockdev --getro "$dev")" = 1 ] || fail "Cannot protect $dev."
 done <<DISKS
$(cat /tmp/camerawall-disks)
$boot
DISKS
 check_inventory
}
# Release only mounts backed directly by the confirmed disk or its partitions.
release_target_mounts() {
 local sys node id mounts mountpoint
 sys=$1
 mounts=
 for node in "$sys" "$sys"/"${sys##*/}"*; do
  [ "$node" = "$sys" ] || [ -f "$node/partition" ] || continue
  id=$(cat "$node/dev") || fail "Cannot identify /dev/${node##*/}."
  mounts="$mounts
$(awk -v id="$id" '$3 == id {print $5}' /proc/self/mountinfo)"
 done
 # Descendants must be unmounted first. Refuse stacked mounts on other disks.
 printf '%s\n' "$mounts" | LC_ALL=C sort -r -u > /tmp/camerawall-target-mounts
 while IFS= read -r mountpoint; do
  [ -n "$mountpoint" ] || continue
  case "$mountpoint" in /|/cdrom|/cdrom/*|/cw-media|/cw-media/*|/target|/target/*|/dev|/dev/*|/proc|/proc/*|/sys|/sys/*)
   fail "Cannot release protected mount $mountpoint." ;;
  esac
  [ "$(CW_MOUNT_POINT="$mountpoint" awk '$5 == ENVIRON["CW_MOUNT_POINT"] {n++} END {print n+0}' /proc/self/mountinfo)" = 1 ] ||
   fail "Cannot release stacked mount $mountpoint."
  check_inventory
  # mountinfo escapes whitespace; printf decodes it without shell evaluation.
  mountpoint=$(printf '%b' "$mountpoint")
  umount "$mountpoint" || fail "Cannot unmount $mountpoint on $target."
 done < /tmp/camerawall-target-mounts
}
prepare_target() {
 local sys swaps swap partition
 check_inventory
 sys="/sys/block/${target##*/}"
 if [ "$(blockdev --getro "$target")" = 1 ]; then
  blockdev --setrw "$target" || fail "Cannot enable writes on $target."
 fi
 [ "$(blockdev --getro "$target")" = 0 ] || fail "$target is still read-only."
 for partition in "$sys"/"${target##*/}"*; do
  [ -f "$partition/partition" ] || continue
  blockdev --setrw "/dev/${partition##*/}" || fail "Cannot enable writes on /dev/${partition##*/}."
 done
 release_target_mounts "$sys"
 swaps=$(target_swap_devices "$sys") || fail "Cannot inspect active swap on $target."
 for swap in $swaps; do
  check_inventory
  swapoff "$swap" || fail "Cannot disable active swap on $swap."
 done
 disk_unused "$sys" || fail "Cannot use $target: $disk_use_reason."
 check_inventory
 blockdev --rereadpt "$target" || fail "Kernel refused to reload the partition table on $target. Check the disk lock and see Ctrl+Alt+F4 for details."
}
# Remove the old partition map and filesystem headers before Partman probes the
# confirmed target. Leave creation of the new GPT and EFI filesystem to Debian.
reset_target_layout() {
 local sys sector_size scale blocks edge part start length tail_start
 sys="/sys/block/${target##*/}"
 sector_size=$(blockdev --getss "$target") || fail "Cannot read sector size on $target."
 case "$sector_size" in 512|1024|2048|4096) ;; *) fail "Unsupported sector size on $target." ;; esac
 scale=$((sector_size / 512))
 blocks=$((sectors / scale))
 edge=$((1048576 / sector_size))
 [ "$((sectors % scale))" = 0 ] && [ "$blocks" -ge "$((2 * edge))" ] || fail "Invalid disk geometry on $target."
 check_inventory
 for part in "$sys"/"${target##*/}"*; do
  [ -f "$part/partition" ] || continue
  start=$(cat "$part/start") || fail "Cannot read partition start on $target."
  length=$(cat "$part/size") || fail "Cannot read partition size on $target."
  [ "$start" -gt 0 ] && [ "$length" -gt 0 ] && [ "$length" -le "$((sectors - start))" ] &&
   [ "$((start % scale))" = 0 ] && [ "$((length % scale))" = 0 ] || fail "Invalid partition geometry on $target."
  length=$((length / scale))
  tail_start=$((start / scale + length))
  if [ "$length" -gt "$edge" ]; then length=$edge; fi
  tail_start=$((tail_start - length))
  check_inventory
  dd if=/dev/zero of="$target" bs="$sector_size" seek="$tail_start" count="$length" conv=notrunc 2>/dev/null ||
   fail "Cannot clear the old filesystem backup on $target."
  check_inventory
  dd if=/dev/zero of="$target" bs="$sector_size" seek="$((start / scale))" count="$length" conv=notrunc 2>/dev/null ||
   fail "Cannot clear the old filesystem header on $target."
 done
 check_inventory
 dd if=/dev/zero of="$target" bs="$sector_size" count="$edge" conv=notrunc 2>/dev/null ||
  fail "Cannot clear the old partition table on $target."
 check_inventory
 dd if=/dev/zero of="$target" bs="$sector_size" seek="$((blocks - edge))" count="$edge" conv=notrunc 2>/dev/null ||
  fail "Cannot clear the old partition table on $target."
 blockdev --flushbufs "$target" && blockdev --rereadpt "$target" || fail "Cannot reload the cleared partition table on $target."
 for part in "$sys"/"${target##*/}"*; do
  [ ! -f "$part/partition" ] || fail "Old partitions are still visible on $target."
 done
 logger -t camerawall "Cleared old partition table and filesystem headers on $target"
}
select_automatic_target() {
 scan_disks
 # Rank before checking write access or usage so a locked target never triggers fallback.
 selected=$(LC_ALL=C sort -k1,1n -k2,2n -k3,3 /tmp/camerawall-auto-targets | awk 'NR == 1 {print $2, $3}')
 [ -n "$selected" ] || fail 'Auto found no destination disk of at least 24 GiB. Choose Manual to inspect the disks.'
 sectors=${selected%% *}
 target=${selected#* }
 check_inventory
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
}
retry_target_operation() {
 local operation reason attempts
 operation=$1
 attempts=0
 while :; do
  check_inventory
  if (
   trap - EXIT
   fail() { printf '%s\n' "$*" > /tmp/camerawall-target-error; exit 1; }
   : > /tmp/camerawall-target-error
   "$operation"
  ); then
   return 0
  fi
  check_inventory
  attempts=$((attempts + 1))
  if [ "$attempts" -lt 2 ]; then
   sleep 1
   continue
  fi
  reason=$(cat /tmp/camerawall-target-error)
  if [ "$mode" = auto ]; then
   logger -t camerawall "Retrying fixed Auto target $target: ${reason:-Disk operation failed}"
   echo "CameraWall: retrying $target in 10 seconds: ${reason:-disk operation failed}" > /dev/console
   sleep 10
   continue
  fi
  logger -t camerawall "Target $target retained: ${reason:-Disk operation failed}"
  cat > /tmp/camerawall-retry.templates <<'TEMPLATES'
Template: camerawall/retry-target
Type: select
Choices: Retry this disk, Stop
Description: Continue on ${disk}
 ${reason}
 .
 Setup keeps this disk selected. Check its connection or hardware lock, then retry.
TEMPLATES
  debconf-loadtemplate camerawall /tmp/camerawall-retry.templates || fail 'Cannot display disk recovery.'
  db_subst camerawall/retry-target disk "$target"
  db_subst camerawall/retry-target reason "${reason:-Disk operation failed. See Ctrl+Alt+F4.}"
  db_set camerawall/retry-target 'Retry this disk'
  db_fset camerawall/retry-target seen false
  db_input critical camerawall/retry-target && db_go && db_get camerawall/retry-target ||
   fail 'Cannot read retry selection.'
  [ "$RET" = 'Retry this disk' ] || fail "Stopped with $target selected."
  attempts=0
 done
}
clean_target() {
 prepare_target
 reset_target_layout
}
format_target_partition() {
 prepare_target
 [ -f "$part/partition" ] && [ "$(cat "$part/start")" = "$start" ] &&
  [ "$(cat "$part/size")" = "$size" ] && [ "$(blockdev --getro "$partdev")" = 0 ] ||
  fail "Partition changed or is read-only: $partdev."
 check_inventory
 mkfs.ext4 -F "$partdev" || fail "Cannot format $partdev."
 blockdev --flushbufs "$partdev" || fail "Cannot flush $partdev."
}
select_manual_target() {
 cat > /tmp/camerawall-target.templates <<'TEMPLATES'
Template: camerawall/target
Type: select
Choices: ${disks}
Description: Where do you want to install CameraWall?
 ${status}
 .
 Installer USB: ${boot} (protected). Select a disk for installation or disk options.

Template: camerawall/action
Type: select
Choices: Back, Install CameraWall, Clean disk - delete ALL partitions, Format a partition (ext4)
Description: ${disk}
 ${result}
 .
 Clean disk deletes ALL partitions and old boot data, leaving the disk unallocated. Install creates fresh system and EFI partitions.

Template: camerawall/partition
Type: select
Choices: ${partitions}
Description: Choose a partition to format on ${disk}

Template: camerawall/confirm-target
Type: select
Choices: Back, Confirm
Description: ${action}
 This permanently removes access to the existing data on ${disk}.
TEMPLATES
 debconf-loadtemplate camerawall /tmp/camerawall-target.templates || fail 'Cannot load the disk menu.'
 db_subst camerawall/target boot "$boot" || fail 'Cannot show the protected installer disk.'
 ask() {
  db_set "$1" "$2" && db_fset "$1" seen false &&
   db_input critical "$1" && db_go && db_get "$1" || fail 'Cannot read the disk menu.'
 }
 confirm() {
  db_subst camerawall/confirm-target action "$1" &&
   db_subst camerawall/confirm-target disk "$2" || fail 'Cannot show the confirmation.'
  ask camerawall/confirm-target Back
  [ "$RET" = Confirm ]
 }
 selected_disk=
 while :; do
  if [ -z "$selected_disk" ]; then
   scan_disks
   db_subst camerawall/target disks "$choices" &&
    db_subst camerawall/target status "${result:-${status:-Choose the exact destination. Setup never switches to another disk.}}" ||
    fail 'Cannot display disk inventory.'
   ask camerawall/target Cancel
   result=
   case "$RET" in
    Cancel) fail 'Setup canceled.' ;;
    'Rescan disks') continue ;;
   esac
   target=${RET%% *}
   sectors=$(awk -v disk="$target" '$2 == disk {print $1; exit}' /tmp/camerawall-targets)
   [ -n "$sectors" ] && [ "$target" != "$boot" ] || fail 'Invalid destination disk.'
   check_inventory
   label=$RET
   selected_disk=$target
  fi
  check_inventory
  db_subst camerawall/action result "${result:-Choose an operation for this disk.}"
  db_subst camerawall/action disk "$label" || fail 'Cannot display selected disk.'
  ask camerawall/action Back
  case "$RET" in
   Back) selected_disk=; result=; continue ;;
   'Install CameraWall')
    confirm 'Erase this disk and install CameraWall?' "$label" || continue
    return 0
    ;;
   'Clean disk - delete ALL partitions')
    confirm 'Delete all partitions and old boot data?' "$label" || continue
    retry_target_operation clean_target
    result="Deleted all partitions on $target. This disk remains selected."
    ;;
   'Format a partition (ext4)')
    sys="/sys/block/${target##*/}"
    partitions=Back
    for part in "$sys"/"${target##*/}"*; do
     [ -f "$part/partition" ] || continue
     size=$(cat "$part/size")
     partitions="$partitions, /dev/${part##*/} ($((size / 2048)) MiB)"
    done
    if [ "$partitions" = Back ]; then
     result="No partitions to format on $target."
     continue
    fi
    db_subst camerawall/partition disk "$label" &&
     db_subst camerawall/partition partitions "$partitions" || fail 'Cannot display partitions.'
    ask camerawall/partition Back
    [ "$RET" != Back ] || continue
    partdev=${RET%% *}
    part="$sys/${partdev##*/}"
    [ -f "$part/partition" ] && [ "$partdev" = "/dev/${part##*/}" ] && [ -b "$partdev" ] ||
     fail 'Invalid partition selection.'
    start=$(cat "$part/start")
    size=$(cat "$part/size")
    confirm 'Format this partition as ext4?' "$RET on $label" || continue
    command -v mkfs.ext4 >/dev/null || anna-install e2fsprogs-udeb || fail 'Cannot load the ext4 formatter.'
    command -v mkfs.ext4 >/dev/null || fail 'The ext4 formatter is unavailable.'
    retry_target_operation format_target_partition
    result="Formatted $partdev as ext4. This disk remains selected."
    ;;
   *) fail 'Invalid disk option.' ;;
  esac
 done
}
mode=auto
case " $(cat /proc/cmdline) " in
 *' camerawall.disk=manual '*) mode=manual; select_manual_target ;;
 *) select_automatic_target ;;
esac
[ "$target" != "$boot" ] || fail 'The installer USB cannot be selected.'
protect_other_disks
retry_target_operation clean_target
check_inventory
target_sequence=$(printf '%s\n' "$inventory" | awk -v name="${target##*/}" '$1 == name {print $2}')
[ -n "$target_sequence" ] || fail 'Cannot record the selected disk identity.'
logger -t camerawall "INSTALL: boot=$boot target=$target sectors=$sectors; all other disks protected"
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
printf '%s\n' "$target_sequence" > /tmp/camerawall-system-diskseq
trap - EXIT
