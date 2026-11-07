#!/bin/bash
set -Eeuo pipefail
umask 077
base=/usr/local/lib/camerawall-usb
state=/var/lib/camerawall-usb
mkdir -p "$state"
exec 9>"$state/lock"
flock -n 9 || exit 1
[[ ! -f $state/complete ]] || exit 0
trap 'rc=$?; echo "FAILED (exit $rc). Restore Internet, inspect journalctl -u camerawall-firstboot, then sudo systemctl restart camerawall-firstboot. Cached downloads are retained. No disk will be repartitioned."; exit "$rc"' ERR
[[ $(uname -m) == x86_64 && $(id -u) == 0 ]]
source /etc/os-release
[[ $ID == debian && $VERSION_ID == 12 ]]
cd "$state"
# Resolve a fresh snapshot before even inspecting cached bytes.
release=$(python3 "$base/latest-release.py")
read -r CAMERAWALL_VERSION CAMERAWALL_SHA256 CAMERAWALL_DISPLAY_SHA256 <<< "$release"
archive="camerawall_${CAMERAWALL_VERSION}_linux_amd64.tar.gz"
display="camerawall-display_${CAMERAWALL_VERSION}_linux_amd64_debian12.tar.gz"
fetch() {
 local name=$1 digest=$2
 local url="https://github.com/alt-hn/camerawall-releases/releases/download/$CAMERAWALL_VERSION/$name"
 if printf '%s  %s\n' "$digest" "$name" | sha256sum -c --status; then
  return
 fi
 local -a curl_options=(--proto '=https' --proto-redir '=https' --tlsv1.2 -fL --connect-timeout 30 --max-time 1800 --retry 5 --retry-all-errors --retry-delay 5)
 if ! curl "${curl_options[@]}" -C - -o "$name.part" "$url"; then
  curl "${curl_options[@]}" -o "$name.part" "$url"
 fi
 printf '%s  %s\n' "$digest" "$name.part" | sha256sum -c - || { rm -f "$name.part"; return 1; }
 mv "$name.part" "$name"
}
fetch "$archive" "$CAMERAWALL_SHA256"
fetch "$display" "$CAMERAWALL_DISPLAY_SHA256"
# Validate paths/types before extraction and verify the package version.
python3 - "$archive" "$CAMERAWALL_VERSION" <<'PY'
import pathlib, sys, tarfile
archive, version = sys.argv[1:]
root = f'camerawall_{version}_linux_amd64'
with tarfile.open(archive) as t:
    for m in t.getmembers():
        p = pathlib.PurePosixPath(m.name)
        assert not p.is_absolute() and '..' not in p.parts and p.parts[0] == root, m.name
        assert m.isfile() or m.isdir(), m.name
    info = t.extractfile(root + '/BUILD-INFO.txt').read().decode()
    assert f'version={version}\n' in info
    t.extractall('unpacked')
PY
echo 'Installing signed Debian dependencies and the offline analytics runtime...'
apt-get -o Acquire::Retries=5 update
DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=5 install -y --no-install-recommends python3-venv libglib2.0-0 libgomp1 libqt6gui6 libqt6opengl6 libqt6network6 qt6-qpa-plugins qt6-wayland gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav weston libgl1-mesa-dri fonts-dejavu-core
python3 "$base/provision-analytics.py"
# A dedicated drop-in survives future install.sh --upgrade unit replacements.
install -d -m 0755 /etc/systemd/system/camerawall.service.d
install -m 0644 "$base/root-service.conf" /etc/systemd/system/camerawall.service.d/90-appliance-root.conf
# Keep the timer available for UI settings, but start fresh appliances in off mode.
if [[ ! -e /var/lib/camerawall/update-settings.json ]]; then
 install -d -m 0755 /var/lib/camerawall
 printf '{"mode":"off","auto_download":false}\n' > /var/lib/camerawall/update-settings.json
fi
bundle="unpacked/camerawall_${CAMERAWALL_VERSION}_linux_amd64"
bash "$base/install-host-runtime.sh" "$bundle"
bash "$bundle/install.sh"
[[ $(systemctl show camerawall.service -p User --value) == root ]]
# The timer honors the persisted UI mode; manual updates remain available.
systemctl enable --now camerawall-auto-download.timer
for attempt in $(seq 1 120); do
 if curl --noproxy '*' -fsS --max-time 5 http://127.0.0.1/ >/dev/null &&
    systemctl is-active --quiet camerawall.service camerawall-media.service camerawall-host.service &&
    curl --noproxy '*' -fsS --max-time 10 --unix-socket /run/camerawall-host/control.sock http://host/status >/dev/null; then
  bash "$base/install-display-runtime.sh" "$display" "$CAMERAWALL_VERSION" "$CAMERAWALL_DISPLAY_SHA256"
  printf 'version=%s\ncompleted=%s\n' "$CAMERAWALL_VERSION" "$(date -u +%FT%TZ)" > "$state/complete"
  echo "READY: CameraWall $CAMERAWALL_VERSION. LAN addresses: $(hostname -I)"
  echo 'Open http://LAN-IP ; admin password: sudo /opt/camerawall/bin/camerawall --show-initial-password'
  exit 0
 fi
 sleep 5
done
echo 'CameraWall backend, media or appliance helper did not become ready.'
exit 1
