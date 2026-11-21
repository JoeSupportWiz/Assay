"""End-to-end receipt tests with local synthetic tool processes only."""
from contextlib import ExitStack, redirect_stderr, redirect_stdout
import io
import json
import os
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch

import assay_handoff as h

FIX = Path(__file__).with_name('fixtures')
DEVICE = 'a' * 40
# These are the only executables the mocked tool lookup can return.
LIST = "import sys\nassert sys.argv[1:] == ['-l']\nprint('a' * 40)\n"
TOOL = '''import os, plistlib, sys
from pathlib import Path
assert sys.argv[1:4] == ['-u', 'a' * 40, 'backup'] and len(sys.argv) == 5
p = Path(sys.argv[4]) / ('a' * 40)
p.mkdir(exist_ok=True)
Path(os.environ['ASSAY_TEST_LOG']).touch()
mode = os.environ['ASSAY_TEST_MODE']
if mode != 'nochange':
    (p/'Status.plist').write_bytes(plistlib.dumps({'SnapshotState': 'finished'}))
if mode in ('good', 'badexit'):
    (p/'Manifest.db').write_bytes(b'synthetic manifest')
print('private raw fixture output')
sys.exit(17 if mode == 'badexit' else 0)
'''


class HandoffTests(unittest.TestCase):
    def setUp(self):
        stack = ExitStack()
        self.addCleanup(stack.close)
        self.base = Path(stack.enter_context(tempfile.TemporaryDirectory())).resolve()
        self.root = self.base / 'private'
        self.root.mkdir(mode=0o700)
        self.req = self.base / 'request.json'
        self.req.write_bytes((FIX / 'request.json').read_bytes())
        self.obj = json.loads(self.req.read_bytes())
        self.job = self.obj['job_id']
        self.out = self.base / ('assay-usb-result-' + self.job + '.json')
        self.log = self.base / 'called'
        self.dest = self.root / 'Backups' / 'My-iPhone' / DEVICE
        tools = {}
        for name, source in [('idevice_id', LIST), ('idevicebackup2', TOOL)]:
            f = self.base / name
            f.write_text('#!' + sys.executable + '\n' + source)
            f.chmod(0o700)
            tools[name] = str(f)
        stack.enter_context(patch.object(h.usb.shutil, 'which', side_effect=tools.__getitem__))
        stack.enter_context(patch.object(sys, 'platform', 'darwin'))
        self.tty = stack.enter_context(patch.object(sys, 'stdin'))
        self.tty.isatty.return_value = True
        self.confirm = stack.enter_context(patch('builtins.input', return_value='BACK UP'))
        stack.enter_context(patch.dict(os.environ, ASSAY_TEST_LOG=str(self.log), ASSAY_TEST_MODE='good'))
        self.console = io.StringIO()
        stack.enter_context(redirect_stdout(self.console))
        stack.enter_context(redirect_stderr(self.console))
        stack.callback(os.umask, os.umask(0o077))

    def check(self, expected, name='My-iPhone'):
        self.assertEqual(h.handoff(self.req, self.base, self.root, name), expected)
        r = json.loads(self.out.read_bytes())
        fixture = json.loads((FIX / 'completed.json').read_bytes())
        self.assertEqual(set(r), set(fixture))
        self.assertEqual((r['schema'], r['job_id'], r['state']), (fixture['schema'], self.job, expected))
        self.assertIs(r['backup_tool_succeeded'], expected in ('completed', 'unverified'))
        self.assertIs(r['fresh_manifest_verified'], expected == 'completed')
        for k in ('started_at', 'finished_at'):
            self.assertRegex(r[k], r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')
        self.assertLessEqual(r['started_at'], r['finished_at'])
        self.assertNotIn('private raw fixture output', self.console.getvalue())
        self.assertEqual(self.out.read_bytes(), (self.root / 'Jobs' / self.job.lower() / self.out.name).read_bytes())

    def test_success_and_replay_under_new_path(self):
        self.check('completed')
        self.assertTrue(self.log.is_file())
        other = self.base / 'other'
        other.mkdir()
        copy = other / 'different.json'
        copy.write_bytes(self.req.read_bytes())
        self.log.unlink()
        with self.assertRaises(h.usb.Stop):
            h.handoff(copy, other, self.root)
        self.assertFalse(self.log.exists())
        self.assertFalse((other / self.out.name).exists())

    def test_nonzero_with_fresh_evidence(self):
        os.environ['ASSAY_TEST_MODE'] = 'badexit'
        self.check('failed')
        self.assertTrue((self.dest / 'Manifest.db').is_file())

    def test_zero_without_manifest(self):
        os.environ['ASSAY_TEST_MODE'] = 'statusonly'
        self.check('unverified')

    def seed(self):
        self.dest.mkdir(mode=0o700, parents=True)
        (self.dest / 'Status.plist').write_bytes(plistlib.dumps({'SnapshotState': 'finished'}))
        (self.dest / 'Manifest.db').write_bytes(b'existing')

    def test_zero_with_recent_but_unchanged_evidence(self):
        self.seed()
        os.environ['ASSAY_TEST_MODE'] = 'nochange'
        self.check('unverified')

    def test_only_status_changed(self):
        self.seed()
        os.environ['ASSAY_TEST_MODE'] = 'statusonly'
        self.check('unverified')

    def test_socket_override_fails_before_confirmation(self):
        os.environ['USBMUXD_SOCKET_ADDRESS'] = 'fixture:1234'
        self.check('failed')
        self.confirm.assert_not_called()
        self.assertFalse(self.log.exists())

    def test_cancel_before_transfer(self):
        self.confirm.return_value = 'no'
        self.check('cancelled')
        self.assertFalse(self.log.exists())

    def test_noninteractive_cannot_approve(self):
        self.tty.isatty.return_value = False
        self.check('cancelled')
        self.confirm.assert_not_called()
        self.assertFalse(self.log.exists())

    def test_host_rejects_linked_destination(self):
        backups = self.root / 'Backups'
        backups.mkdir(mode=0o700)
        (backups / 'My-iPhone').symlink_to(self.base)
        self.check('failed')
        self.assertFalse(self.log.exists())

    def test_no_overwrite_including_dangling_link(self):
        self.out.symlink_to(self.base / 'absent')
        with self.assertRaises(h.usb.Stop):
            h.handoff(self.req, self.base, self.root)
        self.assertTrue(self.out.is_symlink())
        self.assertFalse((self.root / 'Jobs').exists())

    def test_collision_after_claim_preserves_receipt(self):
        def late_collision(_):
            self.out.write_bytes(b'preexisting')
            return 'no'
        self.confirm.side_effect = late_collision
        with self.assertRaises(h.usb.Stop):
            h.handoff(self.req, self.base, self.root, 'My-iPhone')
        self.assertEqual(self.out.read_bytes(), b'preexisting')
        saved = self.root / 'Jobs' / self.job / self.out.name
        self.assertEqual(json.loads(saved.read_bytes())['state'], 'cancelled')

    def test_strict_rejection_before_claim_or_tool(self):
        bad = [dict(self.obj, **{k: v}) for k, v in [
            ('destination', '../elsewhere'), ('command', 'fixture'), ('extra', None),
            ('job_id', '../../other'), ('job_id', 1), ('schema', 'v2'), ('operation', 'restore')]]
        blobs = [json.dumps(x).encode() for x in bad + [[], {'schema': 'assay.usb.request.v1'}]]
        blobs += [self.req.read_bytes().replace(b'{', b'{"job_id":"unused",'), b'\xff', b' ' * 4097, b'{']
        for body in blobs:
            with self.subTest(body=body[:60]):
                self.req.write_bytes(body)
                with self.assertRaises(h.usb.Stop):
                    h.handoff(self.req, self.base, self.root)
        self.assertFalse((self.root / 'Jobs').exists())
        self.assertFalse(self.out.exists())
        self.assertFalse(self.log.exists())
