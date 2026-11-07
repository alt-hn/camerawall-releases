#!/bin/bash
set -eu
state=/var/lib/camerawall-usb
[[ -c /dev/tty1 ]] || exit 0
# Only the attached local display receives credentials; never journal/network.
{
 read -r cmdline < /proc/cmdline
 if [[ ! -d /sys/firmware/efi || " $cmdline " != *" camerawall.bootcheck=1 "* ]]; then
  printf '\nBoot check: unavailable. Check the installed UEFI/GRUB configuration.\n'
 elif [[ " $cmdline " == *" camerawall.installer_boot=1 "* ]]; then
  printf '\nBoot check: pending. Shut down, remove installer USB, then power on.\n'
  printf 'If the firmware reports no OS, reconnect USB to recover this installation.\n'
 elif ! labels=$(lsblk -nr -o LABEL); then
  printf '\nBoot check: unavailable. Could not inspect attached disks.\n'
 elif grep -qxE 'CWOFFLIN|CAMERAWALL_USB_[0-9]+' <<< "$labels"; then
  printf '\nBoot check: pending. Shut down, remove installer USB, then power on.\n'
 else
  root=$(findmnt -nro SOURCE --mountpoint /)
  esp=$(findmnt -nro SOURCE --mountpoint /boot/efi || true)
  if [[ -b $root && -b $esp ]] &&
     root_disk=$(lsblk -ndo PKNAME "$root") &&
     esp_disk=$(lsblk -ndo PKNAME "$esp") &&
     [[ -n $root_disk && $root_disk == "$esp_disk" ]]; then
   printf '\nBoot check: PASS. Debian started from the installed disk without installer USB.\n'
  else
   printf '\nBoot check: unavailable. Root and EFI are not verified on the same disk.\n'
  fi
 fi
 if [[ ! -f $state/complete ]]; then
  printf 'CameraWall setup is incomplete. Check camerawall-firstboot before retrying.\n'
  exit 0
 fi
 printf '\nCameraWall READY: http://%s\n' "$(hostname -I | awk '{print $1}')"
 if [[ -f $state/linux-password ]]; then
  printf 'Linux user: cwadmin | Initial password: '; cat "$state/linux-password"
 fi
 if web_password=$(/opt/camerawall/bin/camerawall --show-initial-password 2>/dev/null) && [[ -n $web_password ]]; then
  printf 'CameraWall initial web password: %s\n' "$web_password"
 fi
 printf 'Keep these credentials private. To change the Linux password, log in and run passwd.\n'
} > /dev/tty1
