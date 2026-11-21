#!/usr/bin/env python3
"""USB-only backup to a dedicated directory. No restore, permission changes, pairing or forced full backups."""
import argparse, fcntl, os, plistlib, re, shutil, stat, subprocess, sys, time
from pathlib import Path

ID=re.compile(r'(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{8}-[0-9a-fA-F]{16})\Z')
class Stop(Exception): pass

def select(lines, suffix=None):
    ids=sorted(set(x.strip() for x in lines.splitlines() if ID.fullmatch(x.strip())))
    if suffix is not None:
        if not re.fullmatch(r'[0-9a-fA-F]{6}',suffix): raise Stop('Use exactly the last six hexadecimal characters for --device.')
        ids=[x for x in ids if x.lower().endswith(suffix.lower())]
    if not ids:raise Stop('No matching USB device. Unlock the iPhone, connect it by cable and approve Trust, then retry.')
    if len(ids)>1:raise Stop('Multiple USB devices: '+', '.join('…'+i[-6:] for i in ids)+'. Specify one with --device LAST6, or unplug the others.')
    return ids[0]

def dest_check(path,device):
    p=Path(path).expanduser();
    if p.is_symlink():raise Stop('Choose a dedicated local directory, not a symlink.')
    p=p.resolve();
    if p==Path.home() or p==Path('/'):raise Stop('Choose a dedicated subdirectory.')
    if p.exists():
        if not p.is_dir():raise Stop('Destination must be a directory.')
        for child in p.iterdir():
            if child.name=='.DS_Store' and child.is_file() and not child.is_symlink():continue
            if child.name!=device or child.is_symlink() or not child.is_dir():raise Stop('Use a new folder or the existing backup folder for just this device.')
    return p

MARKERS = ('Status.plist', 'Manifest.db', 'Manifest.mbdb')


def snapshot(path):
    result = {}
    if path.is_symlink():
        raise Stop('Refusing a linked device folder.')
    for name in MARKERS:
        try:
            s = (path / name).lstat()
        except FileNotFoundError:
            continue
        if not stat.S_ISREG(s.st_mode):
            raise Stop('Refusing a non-regular backup marker.')
        result[name] = (s.st_ino, s.st_size, s.st_mtime_ns)
    return result


def summary(path, started_ns, before=None):
    # Require changes as well as timestamps: two runs can share the same second.
    try:
        after = snapshot(path)
        limit = time.time_ns() + 2_000_000_000
        fresh = {n for n, sig in after.items() if sig != (before or {}).get(n)
                 and sig[1] > 0 and started_ns - 2_000_000_000 <= sig[2] <= limit}
        if 'Status.plist' not in fresh or not fresh.intersection(MARKERS[1:]):
            return False
        if after['Status.plist'][1] > 1024 * 1024:
            return False
        fd = os.open(path / 'Status.plist', os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, 'rb') as f:
            status = plistlib.loads(f.read(1024 * 1024 + 1))
        return isinstance(status, dict) and status.get('SnapshotState') == 'finished' and after == snapshot(path)
    except Exception:
        # Unreadable, malformed or changing evidence is never verification.
        return False

def args_for(tool,device,dir_):return [tool,'-u',device,'backup',str(dir_)]

class Cancelled(Stop): pass


def backup(destination, suffix=None, start=True):
    """The standalone CLI and file handoff share this one confirmed transfer."""
    if sys.platform!='darwin': raise Stop('Run this utility on the Mac where the iPhone is connected.')
    listtool,tool=map(shutil.which,('idevice_id','idevicebackup2'))
    if not (listtool and tool):raise Stop('Requires libimobiledevice on your Mac. Finder → iPhone → General → Back Up Now also works without it.')
    if os.environ.get('USBMUXD_SOCKET_ADDRESS') or os.environ.get('USBMUXD_SOCKET_TYPE'):
        raise Stop('Use the default local USB transport, not a socket override.')
    res=subprocess.run([listtool,'-l'],stdin=subprocess.DEVNULL,capture_output=True,
                       encoding='ascii',errors='replace',timeout=10,check=False)
    if res.returncode:raise Stop('The USB device list was unavailable.')
    device=select(res.stdout,suffix);p=dest_check(destination,device)
    print(f'Device: …{device[-6:]}  •  Destination: {p}\nMode: standard USB backup, not forced full. Reuse depends on the device and existing backup.\nYour existing backup encryption setting is unchanged. A backup may contain unencrypted personal data; choose private local storage.')
    if not start:
        print('Preview only. No backup started. Use --start when ready.')
        return 'preview'
    if not sys.stdin.isatty() or input('Type BACK UP to write this backup: ').strip() != 'BACK UP':
        raise Cancelled('Cancelled before writing.')
    os.umask(0o077)
    p.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(p, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Stop('Another transfer is using this destination.')
        dest_check(p, device)
        before = snapshot(p / device)
        started = time.time_ns()
        print('Backup started. Keep the cable connected; watch the iPhone for approval.', flush=True)
        child = subprocess.Popen(args_for(tool,device,p), stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            rc = child.wait()
        except KeyboardInterrupt:
            child.terminate()
            try: child.wait(timeout=5)
            except subprocess.TimeoutExpired: child.kill(); child.wait()
            raise Cancelled('Interrupted. A partial backup may remain.')
        if rc:
            raise Stop('Backup tool failed. Check cable, trust and storage. No backup files were removed.')
        if not summary(p / device, started, before):
            print('Tool exited successfully, but fresh backup evidence was not verified.')
            return 'unverified'
        print('Transfer and fresh markers verified. Not restore-tested.')
        return 'completed'
    finally:
        os.close(fd)


def main():
    a = argparse.ArgumentParser(description=__doc__)
    a.add_argument('destination', help='Dedicated local backup folder')
    a.add_argument('--device', metavar='LAST6')
    a.add_argument('--start', action='store_true', help='Ask for confirmation, then run')
    o = a.parse_args()
    return int(backup(o.destination, o.device, o.start) == 'unverified')

if __name__=='__main__':
    try:sys.exit(main())
    except (Stop,EOFError,TimeoutError,subprocess.TimeoutExpired,OSError,KeyboardInterrupt) as e:
        print(str(e) if isinstance(e,Stop) else 'Interrupted or unavailable. No verified completion.',file=sys.stderr);sys.exit(1)
