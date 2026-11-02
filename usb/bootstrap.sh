#!/bin/bash
set -Eeuo pipefail
umask 077
base=/usr/local/lib/camerawall-usb
state=/var/lib/camerawall-usb
source "$base/release.env"
mkdir -p "$state"
exec 9>"$state/lock"
flock -n 9 || exit 1
[[ ! -f $state/complete ]] || exit 0
trap 'rc=$?; echo "FAILED (exit $rc). Restore Internet, inspect journalctl -u camerawall-firstboot, then sudo systemctl restart camerawall-firstboot. Cached downloads are retained. No disk will be repartitioned."; exit "$rc"' ERR
[[ $(uname -m) == x86_64 && $(id -u) == 0 ]]
source /etc/os-release
[[ $ID == debian && $VERSION_ID == 12 ]]
cd "$state"
archive="camerawall_${CAMERAWALL_VERSION}_linux_amd64.tar.gz"
url="https://github.com/alt-hn/camerawall-releases/releases/download/$CAMERAWALL_VERSION/$archive"
check() { printf '%s  %s\n' "$CAMERAWALL_SHA256" "$archive" | sha256sum -c -; }
if ! check 2>/dev/null; then
 echo "Downloading $CAMERAWALL_VERSION from GitHub Releases..."
 # Retain partial bytes across service restarts. A server without Range support
 # gets one clean retry; a mismatched completed object is never executed.
 if ! curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fL --connect-timeout 30 --max-time 1800 --retry 5 --retry-all-errors --retry-delay 5 -C - -o "$archive.part" "$url"; then
  echo 'Resume failed; retrying a fresh transfer.'
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fL --connect-timeout 30 --max-time 1800 --retry 5 --retry-all-errors --retry-delay 5 -o "$archive.part" "$url"
 fi
 printf '%s  %s\n' "$CAMERAWALL_SHA256" "$archive.part" | sha256sum -c - || { rm -f "$archive.part"; exit 1; }
 mv "$archive.part" "$archive"
fi
check
# Validate paths/types before extraction and pin the package's source provenance.
python3 - "$archive" "$CAMERAWALL_VERSION" "$CAMERAWALL_SOURCE_COMMIT" <<'PY'
import pathlib, sys, tarfile
archive, version, commit = sys.argv[1:]
root = f'camerawall_{version}_linux_amd64'
with tarfile.open(archive) as t:
    for m in t.getmembers():
        p = pathlib.PurePosixPath(m.name)
        assert not p.is_absolute() and '..' not in p.parts and p.parts[0] == root, m.name
        assert m.isfile() or m.isdir(), m.name
    info = t.extractfile(root + '/BUILD-INFO.txt').read().decode()
    assert f'version={version}\n' in info and f'source_commit={commit}\n' in info
    t.extractall('unpacked')
PY
bash "unpacked/camerawall_${CAMERAWALL_VERSION}_linux_amd64/install.sh"
# No unattended Internet download after installation; updates remain an admin choice.
systemctl disable --now camerawall-auto-download.timer
for attempt in $(seq 1 120); do
 if curl --noproxy '*' -fsS --max-time 5 http://127.0.0.1/ >/dev/null && systemctl is-active --quiet camerawall.service camerawall-media.service; then
  printf 'version=%s\nsource_commit=%s\ncompleted=%s\n' "$CAMERAWALL_VERSION" "$CAMERAWALL_SOURCE_COMMIT" "$(date -u +%FT%TZ)" > "$state/complete"
  echo "READY: CameraWall $CAMERAWALL_VERSION. LAN addresses: $(hostname -I)"
  echo 'Open http://LAN-IP ; admin password: sudo cat /etc/camerawall/initial-admin-password'
  exit 0
 fi
 sleep 5
done
echo 'Services did not become HTTP-ready within 10 minutes.'
exit 1
