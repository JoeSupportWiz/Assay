import os, plistlib, tempfile, time, unittest
from pathlib import Path
import assay_usb_backup as u
A='1'*40;B='2'*40
class Tests(unittest.TestCase):
 def test_select(self):self.assertEqual(A,u.select(A+'\n'+A));self.assertRaises(u.Stop,u.select,'');self.assertRaises(u.Stop,u.select,A+'\n'+B);self.assertEqual(B,u.select(A+'\n'+B,'222222'))
 def test_mask(self):
  with self.assertRaises(u.Stop) as ctx:u.select(A+'\n'+B)
  self.assertNotIn(A,str(ctx.exception))
 def test_args(self):self.assertEqual(u.args_for('tool',A,Path('/path with spaces')),['tool','-u',A,'backup','/path with spaces'])
 def test_dest(self):
  with tempfile.TemporaryDirectory() as root:
   p=Path(root);(p/'random').write_text('');self.assertRaises(u.Stop,u.dest_check,p,A);q=p/'new';self.assertEqual(u.dest_check(q,A),q.resolve());self.assertFalse(q.exists())
 def test_symlink(self):
  with tempfile.TemporaryDirectory() as root:
   p=Path(root);(p/A).symlink_to(p);self.assertRaises(u.Stop,u.dest_check,p,A)
 def test_result(self):
  with tempfile.TemporaryDirectory() as root:
   p=Path(root);now=time.time_ns();self.assertFalse(u.summary(p,now));(p/'Manifest.db').write_bytes(b'fixture');(p/'Status.plist').write_bytes(plistlib.dumps({'SnapshotState':'finished'}));self.assertTrue(u.summary(p,now));self.assertFalse(u.summary(p,now+9_000_000_000));(p/'Status.plist').write_bytes(plistlib.dumps({'SnapshotState':'pending'}));self.assertFalse(u.summary(p,now))
if __name__=='__main__':unittest.main()
