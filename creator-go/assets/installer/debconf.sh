#!/bin/sh
# Preload into the installer frontend only. Child programs and the installed
# Debian system use their ordinary libraries.
exec /lib64/ld-linux-x86-64.so.2 --preload /camerawall/error-log.so /usr/lib/cdebconf/debconf "$@"
