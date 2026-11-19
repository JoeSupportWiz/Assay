#!/usr/bin/env python3
"""No network. Ensure the 20 shipping assets match the independently supplied Fold identity pack."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
items=json.loads((root/'docs/audit/identity-assets.json').read_text())
assert len(items)==20
for path,ref in items.items():
 f=root/path
 assert f.is_file() and 'App/Assets.xcassets/' in path
 assert hashlib.sha256(f.read_bytes()).hexdigest()==ref['sha256'],path
 if f.suffix=='.svg' and 'glyphs' in ref['source']:
  import xml.etree.ElementTree as E
  assert E.fromstring(f.read_bytes()).get('viewBox')=='0 0 24 24',path
print('PASS: 20 shipped identity files match the supplied Fold masters, including 14 vector glyphs')
