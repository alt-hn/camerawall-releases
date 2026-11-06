#!/usr/bin/env python3
"""Publish only a clean pushed-main USB build; compare GitHub asset digests."""
import hashlib, json, os, pathlib, subprocess, sys, urllib.request
ROOT = pathlib.Path(__file__).resolve().parents[1]
os.chdir(ROOT)
REPO = 'alt-hn/camerawall-releases'
TAG = 'usb-v0.3.0'
OUT = ROOT/'dist'

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()

assert run('git','branch','--show-current') == 'main'
assert not run('git','status','--porcelain'), 'Commit all changes first'
run('git','fetch','origin','main')
head = run('git','rev-parse','HEAD')
assert head == run('git','rev-parse','origin/main'), 'Push main first'
info = json.loads((OUT/'BUILD-INFO.json').read_text())
assert info['source_tree_clean'] and info['installer_source_commit'] == head
iso = OUT/f'camerawall-{TAG}-amd64.iso'
assert digest(iso) == info['iso_sha256']
run(sys.executable, str(ROOT/'usb/verify.py'))
for name in ('USB-INSTALL-VI.md','USB-VALIDATION.md','USB-RELEASE-NOTES.md'):
    assert (OUT/name).read_bytes() == (ROOT/'docs'/name).read_bytes()
names = [iso.name, 'BUILD-INFO.json', 'BOOT-LAYOUT.txt', 'DEBIAN-SIGNATURE.txt',
         'USB-INSTALL-VI.md', 'USB-VALIDATION.md', 'USB-RELEASE-NOTES.md']
assets = [OUT/name for name in names]
sums = {p.name:digest(p) for p in assets}
(OUT/'SHA256SUMS').write_text(f'{sums[iso.name]}  {iso.name}\n')
assets.append(OUT/'SHA256SUMS')
# Reuse the configured Git credential in memory; never log/store the token.
if not os.environ.get('GH_TOKEN') and not os.environ.get('GITHUB_TOKEN'):
    if subprocess.run(['gh','auth','status'],capture_output=True).returncode:
        result = subprocess.run(['git','credential','fill'],input='protocol=https\nhost=github.com\n\n',text=True,capture_output=True,check=True)
        credential = dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)
        assert credential.get('password'), 'GitHub authentication required'
        os.environ['GH_TOKEN'] = credential['password']
latest_before = json.loads(run('gh','api',f'repos/{REPO}/releases/latest'))['tag_name']
# Draft releases are not reliably returned by the tags endpoint. Resolve the
# draft's database id through gh, and permit a safe resume only while still draft.
existing = subprocess.run(['gh','release','view',TAG,'--repo',REPO,'--json','databaseId'],capture_output=True,text=True)
if existing.returncode == 0:
    release_id = json.loads(existing.stdout)['databaseId']
    prior = json.loads(run('gh','api',f'repos/{REPO}/releases/{release_id}'))
    assert prior['draft'] and prior['tag_name'] == TAG, 'Never replace a public release'
    run('gh','release','edit',TAG,'--repo',REPO,'--target',head,
        '--title','CameraWall USB installer 0.3.0 (Debian 12 / x86-64 UEFI)',
        '--notes-file',str(OUT/'USB-RELEASE-NOTES.md'),'--prerelease','--latest=false')
else:
    run('gh','release','create',TAG,'--repo',REPO,'--target',head,'--draft','--prerelease','--latest=false',
        '--title','CameraWall USB installer 0.3.0 (Debian 12 / x86-64 UEFI)',
        '--notes-file',str(OUT/'USB-RELEASE-NOTES.md'))
    release_id = json.loads(run('gh','release','view',TAG,'--repo',REPO,'--json','databaseId'))['databaseId']
run('gh','release','upload',TAG,'--repo',REPO,'--clobber',*map(str,assets))
release = json.loads(run('gh','api',f'repos/{REPO}/releases/{release_id}'))
assert release['draft'] and release['prerelease'] and release['target_commitish'] == head
remote = {a['name']:a for a in release['assets']}
assert set(remote) == {p.name for p in assets}
for p in assets:
    a = remote[p.name]
    assert a['size'] == p.stat().st_size and a['digest'] == 'sha256:'+digest(p), p.name
run('gh','release','edit',TAG,'--repo',REPO,'--draft=false','--prerelease','--latest=false')
# Anonymous API and HEAD checks establish public accessibility without re-downloading.
with urllib.request.urlopen(f'https://api.github.com/repos/{REPO}/releases/tags/{TAG}') as response:
    public = json.load(response)
assert not public['draft'] and public['prerelease'] and public['target_commitish'] == head
for a in public['assets']:
    assert a['digest'] == remote[a['name']]['digest']
    request = urllib.request.Request(a['browser_download_url'], method='HEAD')
    with urllib.request.urlopen(request) as response:
        assert response.status == 200
assert json.loads(run('gh','api',f'repos/{REPO}/releases/latest'))['tag_name'] == latest_before
run('git','fetch','origin','tag',TAG)
assert run('git','rev-parse',TAG+'^{commit}') == head
(OUT/'PUBLICATION.json').write_text(json.dumps(public,indent=2)+'\n')
print(json.dumps({'url':public['html_url'],'source':head,'asset_count':len(assets),
                  'latest_application_release':latest_before,'verified':'SHA256 digests, sizes, anonymous links and tag source'},indent=2))
