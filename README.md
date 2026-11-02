# CameraWall binary releases

Self-hosted Linux NVR for RTSP cameras. This repository distributes evaluation binaries, installation resources, checksums, release notes and third-party license notices. CameraWall application source is maintained separately in a private repository.

**Application release pinned by the USB installer: [v0.1.0-alpha.29](https://github.com/alt-hn/camerawall-releases/releases/tag/v0.1.0-alpha.29) — public application release.** Read the attached `VALIDATION.md` for actual test coverage and limitations. Short synthetic tests do not establish sustained full-resolution camera capacity. Proxmox LXC and OS versions beyond the tested Debian environment remain unverified.

## USB Internet installer (x86-64 UEFI)

Download the [USB installer 0.1.0 evaluation prerelease](https://github.com/alt-hn/camerawall-releases/releases/tag/usb-v0.1.0). Read [Vietnamese flash/install/recovery instructions](docs/USB-INSTALL-VI.md) and [validation scope](docs/USB-VALIDATION.md). It installs Debian 12 and pins CameraWall alpha.29; existing recording disks are not provisioned.

## Install

On Linux AMD64 or ARM64 with systemd:

```sh
sudo apt-get update
sudo apt-get install -y ffmpeg python3 curl ca-certificates
version=v0.1.0-alpha.29
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

Open `http://SERVER` on a trusted LAN. Use **Cameras → Scan and add now** to discover and add ONVIF cameras, or enable **Auto mode** to check every minute and at startup. Supply the camera ONVIF account; choose whether new cameras record. Manual RTSP main/substream entry remains available. Choose **English / Tiếng Việt** on login or the sidebar. Enable continuous recording, and set a quota, retention and minimum-free-space reserve in Storage. The default recording directory is `/var/lib/camerawall/recordings`. Recording continues when browsers close.

For an external recording disk, prepare its mount and service-user permissions first, then install with `sudo ./install.sh --storage /mnt/camerawall-recordings`. The archive's `docs/PROXMOX-LXC.md` explains unprivileged LXC bind mounts and UID/GID mapping. The archive also includes security, storage migration, upgrade and recovery guides.

Use HTTPS through a trusted reverse proxy or a VPN for remote access. Do not expose the plain HTTP port to the Internet. H.265 and audio browser playback depend on the camera codec/browser; originals can be downloaded for external players. Browser playback remuxes video without transcoding and has limited seeking.

## Upgrade and uninstall

Verify/extract the next archive and run `sudo ./upgrade.sh`. Existing configuration, database, encryption key and recordings are preserved. Back up state and required video before upgrading.

`sudo /opt/camerawall/uninstall.sh` retains state and recordings for reinstall. `--purge` explicitly removes configuration, credentials and index, while still retaining video files. Keep a state backup if those old recordings must remain recoverable.

FFmpeg is a distribution-package dependency. Go2rtc is bundled. The archives include the distribution license and third-party notices.

## Optional native HDMI display

The backend package remains headless with no graphics dependencies. Separate `camerawall-display_v0.1.0-alpha.29_linux_{amd64,arm64}_debian12.tar.gz` packages use Qt 6/GStreamer directly, without a browser or desktop. Install the matching backend first; read `docs/NATIVE-DISPLAY.md` and install the distribution runtime packages before installing the renderer. Run `sudo ./install-display.sh --enable` from the native archive only on the actual Linux display host. Hardware/seat preflight must pass before the service is enabled at boot. Recording runs independently of display failures. Native package upgrades require running the installer with `--enable` again to verify hardware and re-enable output.

Choose Headless, Display or Hybrid under **Local display**. Native output prefers EGLFS/DRM and can fall back to a lightweight Wayland kiosk. Set the HDMI language independently to English or Vietnamese. The native archives target Debian 12 Qt 6.4/GStreamer 1.22. A software-rendered Wayland test painted sixteen low-resolution substreams, handled fullscreen/reconnect and preserved recording through display crashes. Physical HDMI/EGLFS, GPU decoding and physical input remain unverified; read the attached `NATIVE-VALIDATION.md`. Direct display is unsupported in ordinary LXC deployments.

## Tiếng Việt

Chọn **Ngôn ngữ → Tiếng Việt**. Trong trang **Camera**, nhập tài khoản ONVIF rồi nhấn **Quét và thêm ngay**, hoặc bật **Chế độ tự động** để quét mỗi phút và sau khi khởi động. Chọn ghi hình cho camera mới nếu cần. Camera cũ được bỏ qua; mật khẩu được mã hóa khi lưu. Nếu không tìm thấy camera, bật ONVIF, kiểm tra mạng multicast hoặc nhập địa chỉ ONVIF nội bộ. Camera không tương thích vẫn có thể thêm thủ công bằng RTSP. Gói cài đặt có hướng dẫn `docs/AUTO-SETUP-VI.md`.
