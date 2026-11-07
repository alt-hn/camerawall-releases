#!/usr/bin/env python3
"""Resolve matching CameraWall Linux packages from the public release feed."""
import json
import re
import urllib.request

REPO = 'alt-hn/camerawall-releases'


def latest_release():
    request = urllib.request.Request(
        f'https://api.github.com/repos/{REPO}/releases/latest',
        headers={'Accept': 'application/vnd.github+json', 'Cache-Control': 'no-cache'})
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.loads(response.read(2 << 20))
    tag = release['tag_name']
    if release['draft'] or release['prerelease'] or not re.fullmatch(
            r'v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?', tag):
        raise ValueError(f'Invalid public CameraWall release: {tag!r}')

    def asset(name):
        for item in release['assets']:
            if (item['name'] == name and item['size'] > 0
                    and re.fullmatch(r'sha256:[0-9a-f]{64}', item['digest'] or '')):
                return dict(name=name, size=item['size'], sha256=item['digest'][7:],
                            url=f'https://github.com/{REPO}/releases/download/{tag}/{name}')
        raise ValueError(f'Missing verified release asset: {name}')

    return tag, asset(f'camerawall_{tag}_linux_amd64.tar.gz'), asset(
        f'camerawall-display_{tag}_linux_amd64_debian12.tar.gz')


if __name__ == '__main__':
    version, app, display = latest_release()
    print(version, app['sha256'], display['sha256'])
