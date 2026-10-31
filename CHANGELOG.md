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
