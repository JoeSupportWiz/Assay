#!/usr/bin/env python3
"""Create/check the small source-only Mac helper that ships inside the app. No secrets or hardware data."""
import argparse,io,stat,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
base=ROOT/'Mac/usb-backup'; dest=ROOT/'App/ArtResources/Assay-USB-Backup-Mac.zip'
names=['Assay USB Backup.command','assay_handoff.py','assay_usb_backup.py','README.md']
def build():
 data=io.BytesIO()
 with zipfile.ZipFile(data,'w',compression=zipfile.ZIP_STORED) as z:
  for name in names:
   member=zipfile.ZipInfo('Assay USB Backup/'+name,(2026,1,1,0,0,0));member.create_system=3;member.external_attr=(stat.S_IFREG|(0o755 if name.endswith('.command') else 0o644))<<16; z.writestr(member,(base/name).read_bytes())
 return data.getvalue()
if __name__=='__main__':
 args=argparse.ArgumentParser();args.add_argument('--check',action='store_true');ns=args.parse_args();result=build()
 if ns.check:
  if not dest.is_file() or dest.read_bytes()!=result:raise SystemExit('Mac helper is stale: run python3 scripts/package-mac-helper.py')
  print('Shipped helper matches its four reviewed source files')
 else:dest.write_bytes(result);print(dest.name,len(result))
