# Assay build 8 · USB backup handoff for Mac

1. On iPhone, save the Assay backup request using Files. AirDrop it to your Mac or choose a shared folder. Connect just that iPhone by USB, unlock it, and approve Trust on the phone if asked.
2. On the Mac, double-click **Assay USB Backup.command** and pick the request. You need Python 3.8+ and compatible `idevice_id` and `idevicebackup2` (libimobiledevice) on your PATH. Nothing is installed automatically. If Finder won’t run the launcher, use the Terminal command below; don’t change your security settings.
3. Choose a backup folder **name** on the Mac. Backups stay under `~/Library/Application Support/Assay USB Handoff/Backups/`, on the startup data volume. Reuse the same name for incremental backups. Check the masked device suffix and destination shown in Terminal, then type **BACK UP** to start. Any other response declines. Keep the cable connected and allow enough disk space. An existing backup can be updated: don’t use your sole good copy.
4. Wait for the final state in Terminal. Next to the request, look for **`assay-usb-result-<lowercase UUID>.json`**. Return just this receipt to Files and import it for the matching job in Assay. Never share the backup folder. The receipt excludes device identifiers, paths, tool output and credentials.

Terminal alternative (omit `--result-dir` to write beside the request):

```sh
python3 assay_handoff.py "$HOME/Downloads/request.json" --backup-name My-iPhone --result-dir "$HOME/Downloads"
```

**What the receipt means.** `completed` (exit 0) requires the ordinary USB tool to exit zero **and** a changed, fresh, finished `Status.plist` plus a changed, fresh, nonempty regular `Manifest.db` or `Manifest.mbdb` for the selected phone. This is not a restore test. `unverified` (2) means the tool exited zero but that evidence was missing, stale or inconclusive. A valid incremental backup that reused its manifest can be unverified. `failed` (1) means the tool or a prerequisite failed; `cancelled` (3) means confirmation was declined or the run interrupted. Keep any partial backup; don’t discard a known-good copy.

**One job, one attempt.** Only a regular UTF-8 JSON file of at most 4 KiB with exactly the three request fields is accepted. Bad requests have no receipt. A valid job is exclusively claimed before confirmation; replaying a copy under this Mac account won’t rerun it, even in a different export folder. An existing receipt is never overwritten. If export fails, retrieve the identical saved receipt from `~/Library/Application Support/Assay USB Handoff/Jobs/<lowercase UUID>/`; copy it to a *new* location. A crash may leave a claim with no finished receipt. Don’t clear the claim: generate a new job on the phone to retry. Job matching is not authentication; import only receipts you transferred from your own Mac.

There is no listener, restore, forced full backup or encryption change. An ordinary Apple local backup has exclusions and may contain unencrypted personal data. This is not a GoldenNugget protective baseline. For a standalone preview use `python3 assay_usb_backup.py "$HOME/AssayBackups/My-iPhone"`; or use Finder → iPhone → General → Back Up Now without the handoff.

**Synthetic tests only:** `python3 -m unittest -v test_usb test_handoff` from this directory. `fixtures/request.json` and `fixtures/completed.json` are contract examples, not a real job or proof of backup. Hardware and macOS GUI behavior have not been tested here.
