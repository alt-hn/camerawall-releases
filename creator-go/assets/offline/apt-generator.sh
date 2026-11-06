#!/bin/sh
# apt-setup calls generators only after the base system is installed in /target.
set -eu
[ -f /cw-media/repo/Packages ] || exit 1
mkdir -p /target/cw-media
if ! awk '$2 == "/target/cw-media" {found=1} END {exit !found}' /proc/mounts; then
 mount --bind /cw-media /target/cw-media
fi
printf 'deb [trusted=yes] file:/cw-media/repo ./\n' > "$1"
