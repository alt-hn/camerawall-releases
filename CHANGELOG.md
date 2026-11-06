## USB Creator 2.0.0 — 2026-11-07

- Replace Python/Tk desktop runtime with compiled Go + Wails for macOS/Windows.
- Per-stage and per-file byte progress, cache/checksum state, transfer speed,
  elapsed time, retry details and action log. Cancel/resume preparation from cache.
- Port verified offline composition and guarded raw write/readback to Go.
- macOS requests device authorization through authopen before downloading.
- Flush macOS raw USB devices with DKIOCSYNCHRONIZECACHE, fixing the error at
  100% write before checksum readback. Explain the separate macOS unreadable-media notice.
- Compact 880×650 interface and new USB/camera app icon with editable SVG source.
- The Python 1.0.1 fix was superseded before publication. Full physical offline
  installation remains for the owner's testing; no custom ISO is published.

## USB Creator 1.0.1 — 2026-11-07

- macOS: replace the AppleScript/root raw-device open with Apple's authopen
  descriptor authorization, requested for the selected USB before downloading.
- Declare the removable-volume usage description; preserve device revalidation,
  checksum verification and unprivileged GUI. Cancelling permission writes nothing.
- Fix based on a physical Mac EPERM report; full offline installation remains
  unverified. No cache deletion or physical USB flashing during this fix.

## USB Creator 1.0.0 offline — 2026-11-07

- Download official Debian media, dependency packages, CameraWall and AI assets directly; compose bootable media locally instead of downloading a custom CameraWall ISO.
- Bundle a verified local APT repository and firstboot cache for installation without any network.
- Preserve zero-input target installation, boot-disk exclusion and root appliance behavior.

## USB installer 0.3.0 / USB Creator 1.0.0 — 2026-11-06

- Native macOS/Windows USB Creator downloads a pinned ISO, writes the boot image and verifies readback.
- Pin current application alpha.40 and run the appliance backend as root through a persistent service drop-in.
- Keep the existing zero-input, smallest eligible non-boot disk installation policy.

## USB installer 0.2.0 — 2026-11-06

- Boot and install automatically without keyboard/mouse input; choose the smallest eligible non-boot disk.
- Allow HDD/SSD/eMMC and separate USB destinations; resolve and protect the actual boot-medium parent disk.
- Generate a unique Linux administrator password and show initial credentials only on the local display.
- Boot the installed OS when the installer USB remains inserted, preventing repeat installation after a successful OS setup.

## USB installer 0.1.0 — 2026-11-03

- Separate bootable Debian 12.15 amd64 UEFI USB installer, pinning CameraWall alpha.29.
- Guarded SSD/eMMC selection, explicit erase confirmation and read-only protection for other disks.
- Automatic firstboot installation with verified resumable downloads and offline CPU analytics dependencies/models.
- Vietnamese Windows/macOS/Linux flash guide, recovery instructions and explicit validation limits.
- USB prerelease publishing verifies GitHub asset digests and leaves application latest-release selection unchanged.

# Changelog

## v0.1.0-alpha.3

- Add ONVIF camera discovery and automatic main/substream setup, with optional persistent Auto scans every minute and at startup. Passwords are encrypted, repeat scans skip existing cameras, and new-camera recording is explicitly selected.
- Add English/Vietnamese Web UI, remembered language selection, Vietnamese setup instructions and separately configurable native display language.
- Add independent optional Qt 6/GStreamer native renderer packages, headless/display/hybrid modes, EGLFS/DRM preflight, Wayland kiosk fallback and a separate boot service.
- Verify real multicast/SOAP discovery through decoded RTSP recording, plus a sixteen-tile native software-rendered wall and recording continuity during renderer crashes. Physical HDMI/EGLFS and GPU decoding remain unverified.
- Keep alpha.1/alpha.2 artifacts unchanged.

## v0.1.0-alpha.2

- Keep the first reconnect deadline when live-view stall and socket-close notifications repeat.
- Preserve original recording file times during stream-copy repair, so delayed recovery keeps the recording on its original date.
- Add automated timer and recording-repair regressions, plus an actual near-full isolated filesystem test.
- Alpha.1 artifacts remain unchanged; its release notes document the two recovery limitations.

## v0.1.0-alpha.1

Initial evaluation prerelease:

- Authenticated RTSP live wall with 1×1, 2×2, 3×3 and 4×4 selections, substream preview and main-stream expansion.
- Encrypted camera configuration, up to 16 cameras, supervised continuous stream-copy Matroska recording and optional audio.
- Searchable SQLite recording index, authenticated playback/remux and original-segment download.
- Retention, quota and free-space rotation with playback protection, volume identity checks and interrupted-recording reconciliation.
- Embedded responsive web UI, systemd installation, upgrades that retain recordings, Linux AMD64/ARM64 packages and SHA-256 checksums.

See the release's validation attachment for measured synthetic-stream performance, exact test evidence and deployment limitations. This is an alpha, including limited browser playback seeking and unverified Proxmox/OS/full-resolution long-duration combinations.
