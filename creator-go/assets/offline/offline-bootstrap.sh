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
trap 'echo "CameraWall offline setup failed. Inspect journalctl -u camerawall-firstboot. No disk will be repartitioned."' ERR
[[ $(uname -m) == x86_64 && $(id -u) == 0 ]]
cd "$state"
printf '%s  app.tar.gz\n' "$CAMERAWALL_SHA256" | sha256sum -c -
python3 - "$CAMERAWALL_VERSION" "$CAMERAWALL_SOURCE_COMMIT" <<'PY'
import pathlib,sys,tarfile
root='camerawall_'+sys.argv[1]+'_linux_amd64'
with tarfile.open('app.tar.gz') as t:
 for m in t.getmembers():
  p=pathlib.PurePosixPath(m.name)
  assert not p.is_absolute() and '..' not in p.parts and p.parts[0]==root
  assert m.isfile() or m.isdir()
 info=t.extractfile(root+'/BUILD-INFO.txt').read().decode()
 assert 'source_commit='+sys.argv[2]+'\n' in info
 t.extractall('unpacked')
PY
# The Creator copied every pinned AI asset to this cache; do not download a missing
# item silently. A damaged USB is a failure, not an unexpected online fallback.
python3 - <<'PY'
import hashlib,json,pathlib
base=pathlib.Path('/usr/local/lib/camerawall-usb')
cache=pathlib.Path('/var/lib/camerawall-usb/analytics-downloads')
for item in json.loads((base/'analytics-downloads.json').read_text()):
 p=cache/item['name']
 assert p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],item['name']
PY
python3 "$base/provision-analytics.py"
install -d -m 0755 /etc/systemd/system/camerawall.service.d /var/lib/camerawall
install -m 0644 "$base/root-service.conf" /etc/systemd/system/camerawall.service.d/90-appliance-root.conf
if [[ ! -e /var/lib/camerawall/update-settings.json ]]; then printf '{"mode":"off","auto_download":false}\n' > /var/lib/camerawall/update-settings.json; fi
bash "unpacked/camerawall_${CAMERAWALL_VERSION}_linux_amd64/install.sh"
systemctl enable --now camerawall-auto-download.timer
[[ $(systemctl show camerawall.service -p User --value) == root ]]
for attempt in $(seq 1 120); do
 if curl --noproxy '*' -fsS --max-time 5 http://127.0.0.1/ >/dev/null && systemctl is-active --quiet camerawall.service camerawall-media.service; then
  printf 'version=%s\nmode=offline\ncompleted=%s\n' "$CAMERAWALL_VERSION" "$(date -u +%FT%TZ)" > "$state/complete"
  echo 'READY: CameraWall offline installation complete.'
  exit 0
 fi
 sleep 5
done
exit 1
