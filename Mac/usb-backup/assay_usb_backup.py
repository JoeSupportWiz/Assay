#!/usr/bin/env python3
"""USB-only backup to a dedicated directory. No restore, permission changes, pairing or forced full backups."""
import argparse, os, plistlib, re, shutil, stat, subprocess, sys, time
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

def summary(path,started_ns):
    # A fresh finished marker is NOT proof of a successful full restore. Read only the small status plist.
    s=path/'Status.plist'
    try:
        st=s.lstat();
        if not stat.S_ISREG(st.st_mode) or st.st_size>1024*1024 or st.st_mtime_ns < started_ns-2_000_000_000: return False
        with s.open('rb') as f: status=plistlib.load(f)
        return isinstance(status,dict) and status.get('SnapshotState')=='finished' and any((path/n).is_file() for n in ('Manifest.db','Manifest.mbdb'))
    except (ValueError,OSError,plistlib.InvalidFileException):return False

def args_for(tool,device,dir_):return [tool,'-u',device,'backup',str(dir_)]

def main():
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('destination',help='Dedicated local backup folder; reuse it for later runs');a.add_argument('--device',metavar='LAST6');a.add_argument('--start',action='store_true',help='Ask for confirmation, then run. Default is preview only.');o=a.parse_args()
    if sys.platform!='darwin': raise Stop('Run this utility on the Mac where the iPhone is connected.')
    listtool,tool=map(shutil.which,('idevice_id','idevicebackup2'))
    if not (listtool and tool):raise Stop('Requires libimobiledevice on your Mac. Finder → iPhone → General → Back Up Now also works without it.')
    res=subprocess.run([listtool,'-l'],stdin=subprocess.DEVNULL,capture_output=True,text=True,timeout=10,check=False)
    if res.returncode:raise Stop('The USB device list was unavailable.')
    device=select(res.stdout,o.device);p=dest_check(o.destination,device)
    print(f'Device: …{device[-6:]}  •  Destination: {p}\nMode: standard USB backup, not forced full. Reuse depends on the device and existing backup.\nYour existing backup encryption setting is unchanged. A backup may contain unencrypted personal data; choose private local storage.')
    if not o.start: print('Preview only. No backup started. Use --start when ready.');return 0
    if not sys.stdin.isatty() or input('Type BACK UP to write this backup: ').strip()!='BACK UP':raise Stop('Cancelled before writing.')
    os.umask(0o077);p.mkdir(mode=0o700,parents=True,exist_ok=True);started=time.time_ns()
    print('Backup started. Keep the cable connected. Watch the iPhone for iOS approval; progress and speed are not estimated.',flush=True)
    child=subprocess.Popen(args_for(tool,device,p),stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try: rc=child.wait()
    except KeyboardInterrupt:
        child.terminate()
        try:child.wait(timeout=5)
        except subprocess.TimeoutExpired:child.kill();child.wait()
        raise Stop('Interrupted. A partial backup may remain; no completed backup claimed.')
    if rc:raise Stop(f'Backup tool exited {rc}. Completion not verified. Check cable, unlock/trust and available storage. No backup files were removed.')
    if not summary(p/device,started):raise Stop('Transfer exited successfully but a new finished backup marker and manifest were not verified. Do not rely on this copy as your only backup.')
    print('The transfer finished and the destination has a fresh finished marker plus manifest. Not restore-tested.');return 0

if __name__=='__main__':
    try:sys.exit(main())
    except (Stop,EOFError,TimeoutError,subprocess.TimeoutExpired,OSError,KeyboardInterrupt) as e:
        print(str(e) if isinstance(e,Stop) else 'Interrupted or unavailable. No verified completion.',file=sys.stderr);sys.exit(1)
