#!/bin/sh
# Build against the glibc ABI used by the pinned Debian 12 amd64 installer.
set -eu
cd "$(dirname "$0")"
"${ZIG:-zig}" cc -target x86_64-linux-gnu.2.36 -shared -fPIC -Os -s error-log.c \
 -o ../../assets/installer/error-log.so
chmod 644 ../../assets/installer/error-log.so
