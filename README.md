# CameraWall binary releases

Self-hosted Linux NVR for RTSP cameras. This repository distributes evaluation binaries, installation resources, checksums, release notes and third-party license notices. CameraWall application source is maintained separately in a private repository.

**Current release: [v0.1.0-alpha.2](https://github.com/alt-hn/camerawall-releases/releases/tag/v0.1.0-alpha.2) — prerelease.** Read the attached `VALIDATION.md` for actual test coverage and limitations. Short synthetic tests do not establish sustained full-resolution camera capacity. Proxmox LXC and OS versions beyond the tested Debian environment remain unverified.

## Install

On Linux AMD64 or ARM64 with systemd:

```sh
sudo apt-get update
sudo apt-get install -y ffmpeg python3 curl ca-certificates
version=v0.1.0-alpha.2
arch=amd64 # choose arm64 for ARM64 Linux
base=https://github.com/alt-hn/camerawall-releases/releases/download/$version
curl -fLO "$base/camerawall_${version}_linux_${arch}.tar.gz"
curl -fLO "$base/SHA256SUMS"
sha256sum --ignore-missing -c SHA256SUMS
tar xzf "camerawall_${version}_linux_${arch}.tar.gz"
cd "camerawall_${version}_linux_${arch}"
sudo ./install.sh
sudo cat /etc/camerawall/initial-admin-password
```

Open `http://SERVER:8080` on a trusted LAN. Add RTSP main/substream URLs in Cameras, enable continuous recording, and set a quota, retention and minimum-free-space reserve in Storage. The default recording directory is `/var/lib/camerawall/recordings`. Recording continues when browsers close.

For an external recording disk, prepare its mount and service-user permissions first, then install with `sudo ./install.sh --storage /mnt/camerawall-recordings`. The archive's `docs/PROXMOX-LXC.md` explains unprivileged LXC bind mounts and UID/GID mapping. The archive also includes security, storage migration, upgrade and recovery guides.

Use HTTPS through a trusted reverse proxy or a VPN for remote access. Do not expose the plain HTTP port to the Internet. H.265 and audio browser playback depend on the camera codec/browser; originals can be downloaded for external players. Browser playback remuxes video without transcoding and has limited seeking.

## Upgrade and uninstall

Verify/extract the next archive and run `sudo ./upgrade.sh`. Existing configuration, database, encryption key and recordings are preserved. Back up state and required video before upgrading.

`sudo /opt/camerawall/uninstall.sh` retains state and recordings for reinstall. `--purge` explicitly removes configuration, credentials and index, while still retaining video files. Keep a state backup if those old recordings must remain recoverable.

FFmpeg is a distribution-package dependency. Go2rtc is bundled. The archives include the distribution license and third-party notices.
