#!/bin/bash
set -eu
state=/var/lib/camerawall-usb
[[ -c /dev/tty1 ]] || exit 0
if [[ ! -f $state/complete ]]; then
 echo 'CameraWall setup is incomplete. Restore Ethernet/Internet and reboot to retry. No disk will be erased again.' > /dev/tty1
 exit 0
fi
# Only the attached local display receives credentials; never journal/network.
{
 printf '\nCameraWall READY: http://%s\n' "$(hostname -I | awk '{print $1}')"
 if [[ -f $state/linux-password ]]; then
  printf 'Linux user: cwadmin | Initial password: '; cat "$state/linux-password"
 fi
 if [[ -f /etc/camerawall/initial-admin-password ]]; then
  printf 'CameraWall initial web password: '; cat /etc/camerawall/initial-admin-password
 fi
 printf 'Keep these credentials private. Change passwords after login.\n'
} > /dev/tty1
