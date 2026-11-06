"""Shared image transfer logic. This module never opens a device by name."""
import hashlib
import os
import ssl
import certifi
import urllib.request
import urllib.parse
from pathlib import Path

CHUNK = 1024 * 1024


def sha256(stream, count=None, progress=lambda *_: None):
    digest = hashlib.sha256()
    done = 0
    while count is None or done < count:
        chunk = stream.read(CHUNK if count is None else min(CHUNK, count - done))
        if not chunk:
            break
        digest.update(chunk)
        done += len(chunk)
        progress(done, count or done)
    if count is not None and done != count:
        raise ValueError('Thiết bị/file ngắn hơn dung lượng bộ cài.')
    return digest.hexdigest()


def verify(path, manifest):
    if Path(path).stat().st_size != manifest['size']:
        raise ValueError('Dung lượng bộ cài không đúng.')
    with open(path, 'rb') as stream:
        if sha256(stream) != manifest['sha256']:
            raise ValueError('Checksum bộ cài không đúng. Không ghi USB.')


def download(manifest, cache, progress=lambda *_: None):
    """Pinned HTTPS image; interrupted downloads resume only on valid Content-Range."""
    url = manifest['url']
    if urllib.parse.urlsplit(url).scheme != 'https' or urllib.parse.urlsplit(url).hostname not in {'github.com', 'cdimage.debian.org', 'deb.debian.org', 'security.debian.org', 'files.pythonhosted.org', 'media.githubusercontent.com', 'raw.githubusercontent.com'}:
        raise ValueError('Nguồn bộ cài không được hỗ trợ.')
    cache = Path(cache)
    cache.mkdir(parents=True, exist_ok=True)
    final = cache / (manifest['sha256'] + '.iso')
    if final.exists():
        try:
            verify(final, manifest)
            progress(manifest['size'], manifest['size'])
            return final
        except ValueError:
            final.unlink()
    partial = final.with_suffix('.part')
    offset = partial.stat().st_size if partial.exists() else 0
    if offset > manifest['size']:
        partial.unlink()
        offset = 0
    if offset < manifest['size']:
        request = urllib.request.Request(url, headers={'User-Agent': 'CameraWall-USB-Creator/1.0', 'Range': f'bytes={offset}-'})
        with urllib.request.urlopen(request, timeout=60, context=ssl.create_default_context(cafile=certifi.where())) as response:
            if not response.url.startswith('https://'):
                raise ValueError('Tải bộ cài yêu cầu HTTPS.')
            append = offset > 0 and response.status == 206
            if response.status == 206 and response.headers.get('Content-Range') != f"bytes {offset}-{manifest['size']-1}/{manifest['size']}":
                raise ValueError('Máy chủ trả về đoạn tải không hợp lệ.')
            if not append:
                offset = 0
            with partial.open('ab' if append else 'wb') as stream:
                while chunk := response.read(CHUNK):
                    if offset + len(chunk) > manifest['size']:
                        raise ValueError('Bộ cài tải về lớn hơn dung lượng đã ghim.')
                    stream.write(chunk)
                    offset += len(chunk)
                    progress(offset, manifest['size'])
                stream.flush()
                os.fsync(stream.fileno())
    try:
        verify(partial, manifest)
    except ValueError:
        partial.unlink(missing_ok=True)
        raise
    partial.replace(final)
    return final


def copy_and_verify(source, target, manifest, progress=lambda *_: None, sync=lambda: None):
    """Caller owns validated handles. Verify source before the first target write."""
    if sha256(source, manifest['size']) != manifest['sha256']:
        raise ValueError('Checksum nguồn thay đổi. Không ghi USB.')
    source.seek(0)
    done = 0
    while done < manifest['size']:
        chunk = source.read(min(CHUNK, manifest['size'] - done))
        if not chunk:
            raise ValueError('Bộ cài bị cắt ngắn trong lúc ghi.')
        view = memoryview(chunk)
        while view:
            written = target.write(view)
            if not written or written < 0:
                raise OSError('Không thể ghi đầy đủ vào USB.')
            view = view[written:]
        done += len(chunk)
        progress('write', done, manifest['size'])
    target.flush()
    sync()
    target.seek(0)
    actual = sha256(target, manifest['size'], lambda d, n: progress('verify', d, n))
    if actual != manifest['sha256']:
        raise ValueError('USB đọc lại không khớp. Chưa thể dùng để cài đặt.')
