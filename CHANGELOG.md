# Changelog

## v0.1.0-alpha.1

Initial evaluation prerelease:

- Authenticated RTSP live wall with 1×1, 2×2, 3×3 and 4×4 selections, substream preview and main-stream expansion.
- Encrypted camera configuration, up to 16 cameras, supervised continuous stream-copy Matroska recording and optional audio.
- Searchable SQLite recording index, authenticated playback/remux and original-segment download.
- Retention, quota and free-space rotation with playback protection, volume identity checks and interrupted-recording reconciliation.
- Embedded responsive web UI, systemd installation, upgrades that retain recordings, Linux AMD64/ARM64 packages and SHA-256 checksums.

See the release's validation attachment for measured synthetic-stream performance, exact test evidence and deployment limitations. This is an alpha, including limited browser playback seeking and unverified Proxmox/OS/full-resolution long-duration combinations.
