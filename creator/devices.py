"""Conservative physical USB discovery. No generic user-entered device paths."""
import hashlib
import json
import platform
import plistlib
import re
import subprocess


def run(args):
    try:
        return subprocess.check_output(args, stderr=subprocess.PIPE, timeout=30)
    except subprocess.TimeoutExpired:
        raise RuntimeError('Thiết bị không phản hồi trong 30 giây. Kiểm tra cổng/cáp USB rồi quét lại. Chưa ghi dữ liệu vào ổ nào.') from None
    except subprocess.CalledProcessError:
        raise RuntimeError('Không đọc được thông tin ổ từ hệ điều hành. Kiểm tra kết nối USB và quyền truy cập rồi quét lại.') from None


def powershell(script):
    import base64
    encoded = base64.b64encode(script.encode('utf-16le')).decode()
    return run(['powershell.exe', '-NoProfile', '-NonInteractive', '-EncodedCommand', encoded]).decode('utf-8-sig').strip()


def identity(device):
    # Capacity/model/serial plus physical identifier: changing a selection is rejected.
    return hashlib.sha256(json.dumps(device, sort_keys=True).encode()).hexdigest()


def mac_devices():
    listing = plistlib.loads(run(['/usr/sbin/diskutil', 'list', '-plist', 'external', 'physical']))
    found = []
    media = plistlib.loads(run(['/usr/sbin/ioreg', '-r', '-c', 'IOMedia', '-a']))
    registry = {}
    def visit(items):
        for item in items:
            if item.get('Whole') and item.get('BSD Name'):
                registry[item['BSD Name']] = item.get('IORegistryEntryID')
            visit(item.get('IORegistryEntryChildren', []))
    visit(media)
    for name in listing.get('WholeDisks', []):
        if not re.fullmatch(r'disk[0-9]+', name):
            continue
        info = plistlib.loads(run(['/usr/sbin/diskutil', 'info', '-plist', name]))
        # diskutil uses WholeDisk (IORegistry uses Whole). Membership in the
        # external/physical listing is authoritative; modern macOS may report
        # VirtualOrPhysical=Unknown even for physical disks.
        if not info.get('WholeDisk') or info.get('Internal', True) or info.get('VirtualOrPhysical') == 'Virtual':
            continue
        if info.get('BusProtocol') != 'USB' or not info.get('Writable', False):
            continue
        # An external USB may itself host macOS. Refuse any disk participating in
        # the current root/APFS container, not just a disk labelled Internal.
        root = plistlib.loads(run(['/usr/sbin/diskutil', 'info', '-plist', '/']))
        protected = {root.get('ParentWholeDisk'), root.get('DeviceIdentifier')}
        for item in root.get('APFSPhysicalStores', []):
            store = item.get('DeviceIdentifier') or item.get('APFSPhysicalStore', '')
            protected.add(re.sub(r's[0-9]+$', '', store))
        apfs = plistlib.loads(run(['/usr/sbin/diskutil', 'apfs', 'list', '-plist']))
        for container in apfs.get('Containers', []):
            if any(v.get('MountPoint') == '/' or 'System' in v.get('Roles', []) for v in container.get('Volumes', [])):
                protected.update(re.sub(r's[0-9]+$', '', p.get('DeviceIdentifier', '')) for p in container.get('PhysicalStores', []))
        if name in protected:
            continue
        found.append({'id': name, 'size': int(info['TotalSize']), 'model': info.get('MediaName', name),
                      'serial': str(registry.get(name) or ''), 'sector': int(info.get('DeviceBlockSize', 512))})
    return found


def windows_devices():
    text = powershell("[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); @(Get-Disk -ErrorAction Stop | Where-Object { $_.BusType -eq 'USB' -and -not $_.IsBoot -and -not $_.IsSystem -and -not $_.IsReadOnly -and -not $_.IsOffline } | ForEach-Object { @{id=[string]$_.Number; size=[long]$_.Size; model=$_.FriendlyName; serial=[string]$_.UniqueId; sector=[int]$_.LogicalSectorSize} }) | ConvertTo-Json -Compress")
    result = json.loads(text or '[]')
    if isinstance(result, dict):
        result = [result]
    return [d for d in result if re.fullmatch(r'[0-9]+', d['id'])]


def discover(minimum):
    system = platform.system()
    devices = mac_devices() if system == 'Darwin' else windows_devices() if system == 'Windows' else []
    return [d for d in devices if d.get('serial', '').strip() and d['size'] >= max(minimum, 2 * 1024**3) and d['sector'] == 512]


def revalidate(selected, minimum):
    for current in discover(minimum):
        if current['id'] == selected['id'] and identity(current) == identity(selected):
            return current
    raise ValueError('USB đã đổi, bị rút hoặc không còn an toàn để ghi. Hãy chọn lại thiết bị.')
