#!/bin/sh
# Maintainer-only, inside a disposable Debian 12 amd64 VM with validated apt lists.
# Prints a dependency plan; never installs/removes packages or touches a disk.
set -eu
archives=$(mktemp -d)
trap 'rm -rf "$archives"' EXIT
mkdir -p "$archives/partial"
apt-get -o Dir::State::status=/dev/null -o Debug::NoLocking=true \
 -o Dir::Cache::archives="$archives" \
 -o Acquire::ForceHash=SHA256 --print-uris --yes --download-only --reinstall \
 --no-install-recommends install curl ca-certificates ffmpeg python3 sudo \
 python3-venv libglib2.0-0 libgomp1 linux-image-amd64 grub-efi-amd64-signed \
 shim-signed systemd-sysv initramfs-tools network-manager netbase iproute2 qemu-guest-agent \
 libqt6gui6 libqt6opengl6 libqt6network6 qt6-qpa-plugins qt6-wayland gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav weston libgl1-mesa-dri fonts-dejavu-core
