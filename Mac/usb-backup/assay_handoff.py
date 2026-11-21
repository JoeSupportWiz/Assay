#!/usr/bin/env python3
"""Run one user-selected Assay USB request, not a watcher or server."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
from uuid import UUID

import assay_usb_backup as usb

LIMIT = 4096


def unique(pairs):
    obj = dict(pairs)
    if len(obj) != len(pairs):
        raise ValueError('duplicate key')
    return obj


def read_job(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as f:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise usb.Stop('Choose a regular request file.')
        raw = f.read(LIMIT + 1)
    try:
        if len(raw) > LIMIT:
            raise ValueError
        obj = json.loads(raw.decode('utf-8'), object_pairs_hook=unique)
        if (not isinstance(obj, dict) or set(obj) != {'schema', 'job_id', 'operation'}
                or obj['schema'] != 'assay.usb.request.v1' or obj['operation'] != 'standard_usb_backup'):
            raise ValueError
        job = obj['job_id']
        if not isinstance(job, str) or not job.isascii() or str(UUID(job)) != job.lower():
            raise ValueError
        return job
    except (ValueError, RecursionError):
        raise usb.Stop('Invalid Assay request; no backup started.') from None


def private_dir(path, volume):
    path.mkdir(mode=0o700, exist_ok=True)
    s = path.lstat()
    if (not stat.S_ISDIR(s.st_mode) or s.st_uid != os.getuid() or s.st_mode & 0o077
            or s.st_dev != volume or path.resolve() != path):
        raise usb.Stop('Backup and job folders must be private local directories, not links.')
    return path


def local_root():
    support = Path.home() / 'Library' / 'Application Support'
    data = Path('/System/Volumes/Data')
    volume = (data if data.is_dir() else Path('/')).stat().st_dev
    if support.resolve() != support or support.stat().st_dev != volume:
        raise usb.Stop('A local startup-volume home library is required.')
    return private_dir(support / 'Assay USB Handoff', volume)


def exclusive(path, payload):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as f:
        f.write(payload)
        f.flush()
        os.fsync(f.fileno())


def utc():
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def handoff(request, output, root, name=None):
    job = read_job(request)
    if not output.is_dir() or root == output.resolve() or root in output.resolve().parents:
        raise usb.Stop('Choose a receipt folder outside private backup storage.')
    filename = 'assay-usb-result-' + job.lower() + '.json'
    target = output / filename
    if os.path.lexists(target):
        raise usb.Stop('A receipt already exists. Nothing was run or overwritten.')
    volume = root.stat().st_dev
    jobs = private_dir(root / 'Jobs', volume)
    claim = jobs / job.lower()
    try:
        claim.mkdir(mode=0o700)  # Permanent exclusive claim, including crash/cancel paths.
    except FileExistsError:
        raise usb.Stop('This Mac user already claimed this job. Request a new job to retry.')
    started = utc()
    try:
        print(f'Job: {job}\nReceipt: {str(target)!r}')
        if not sys.stdin.isatty():
            raise usb.Cancelled('An interactive Mac confirmation is required.')
        if name is None:
            name = input('Private local backup folder name [My-iPhone]: ') or 'My-iPhone'
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9 _-]{0,63}', name):
            raise usb.Stop('Use a folder name, not a path (letters, numbers, spaces, - or _).')
        backups = private_dir(root / 'Backups', volume)
        dest = private_dir(backups / name, volume)
        state = usb.backup(dest)
    except (usb.Cancelled, EOFError, KeyboardInterrupt):
        state = 'cancelled'
    except (usb.Stop, OSError, subprocess.SubprocessError) as e:
        print(str(e) if isinstance(e, usb.Stop) else 'Backup unavailable.', file=sys.stderr)
        state = 'failed'
    payload = (json.dumps(dict(schema='assay.usb.result.v1', job_id=job, state=state,
                               started_at=started, finished_at=utc(),
                               backup_tool_succeeded=state in ('completed', 'unverified'),
                               fresh_manifest_verified=state == 'completed')) + '\n').encode('ascii')
    saved = claim / filename
    exclusive(saved, payload)
    try:
        exclusive(target, payload)
    except OSError:
        raise usb.Stop(f'Receipt export failed; do not rerun. Retrieve the saved receipt at {saved}.')
    print(f'{state}: {str(target)!r}')
    return state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('request', nargs='?', type=Path, help='Request file (default: Mac file picker)')
    parser.add_argument('--result-dir', type=Path, help='Existing folder (default: beside request)')
    parser.add_argument('--backup-name', help='Private local folder name (default: prompt)')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        raise usb.Stop('Run the handoff on the Mac with the USB cable.')
    request = args.request
    if request is None:
        pick = subprocess.run(['/usr/bin/osascript', '-e',
                               'POSIX path of (choose file with prompt "Select the Assay request from Files")'],
                              capture_output=True, check=False)
        if pick.returncode:
            raise usb.Stop('No request selected; nothing was run.')
        request = Path(os.fsdecode(pick.stdout[:-1]))  # osascript appends one newline.
    state = handoff(request, args.result_dir or request.parent, local_root(), args.backup_name)
    return {'completed': 0, 'unverified': 2, 'cancelled': 3, 'failed': 1}[state]


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (usb.Stop, OSError, KeyboardInterrupt) as e:
        print(str(e) if isinstance(e, usb.Stop) else 'Handoff unavailable or interrupted.', file=sys.stderr)
        sys.exit(1)
