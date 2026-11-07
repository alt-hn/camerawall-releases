#!/bin/bash
# Called after the matching backend has started.
set -Eeuo pipefail
archive=$1
version=$2
digest=$3
printf '%s  %s\n' "$digest" "$archive" | sha256sum -c -
root="camerawall-display_${version}_linux_amd64_debian12"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
python3 - "$archive" "$root" "$work" <<'PY'
import pathlib, sys, tarfile
archive, root, dest = sys.argv[1:]
with tarfile.open(archive) as t:
    for member in t.getmembers():
        p = pathlib.PurePosixPath(member.name)
        if p.is_absolute() or '..' in p.parts or not p.parts or p.parts[0] != root or not (member.isfile() or member.isdir()):
            sys.exit(f"Invalid display archive entry: {member.name}")
    t.extractall(dest)
PY
bash "$work/$root/install-display.sh"
# Headless remains the default. The launcher probes actual hardware only when
# Display or Hybrid is selected, and reports the result in the web UI.
systemctl enable --now camerawall-display.service
