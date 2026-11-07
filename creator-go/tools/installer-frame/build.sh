#!/bin/sh
# Pass the usr/lib/x86_64-linux-gnu directory from the Debian GTK initrd.
set -eu
libs=$(cd "$1" && pwd)
cd "$(dirname "$0")"
if [ -n "${INSTALLER_CC:-}" ]; then
  set -- "$INSTALLER_CC"
else
  set -- zig cc -target x86_64-linux-gnu
fi
"$@" -nostdlib -shared -fPIC -Os -s \
  -Wl,--no-undefined -Wl,--as-needed frame.c \
  "$libs/libgtk-x11-2.0.so.0" "$libs/libgdk-x11-2.0.so.0" \
  "$libs/libgobject-2.0.so.0" \
  -o ../../assets/installer/viewport-frame.so
chmod 644 ../../assets/installer/viewport-frame.so
