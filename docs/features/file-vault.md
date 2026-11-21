# Files Vault

**Entry point:** push `FileVaultView()` inside the existing navigation stack. The feature needs no pairing, entitlements beyond the system Files picker, or third-party packages.

Choose **Choose files for checkpoint** and select 1–32 regular files. The checkpoint captures only that selection, not a folder tree, other Assay state, or the device. Each selection is limited to 16 MiB per file and 64 MiB total before deduplication. There is no automatic monitoring. Selecting changed files later creates another checkpoint; all older versions remain available.

Expand a dated checkpoint, tap a file, and choose a writable folder. The restored bytes use the original file name. A collision is an error, not a replace dialog. Use another folder to keep both versions. A provider that does not allow exclusive publication cannot be used as a restore destination. Verification covers local bytes, not a remote provider’s eventual sync.

## Storage and integrity

- `Application Support/FilesVault` is private to Assay and excluded from system backups. Uninstalling Assay removes it. Export important copies elsewhere. The vault is not a separate encrypted archive or a repair tool.
- `blobs/<sha256>` contains file contents; `snapshots/<uuid>.json` contains an ordered list of local names, lengths, entry IDs and hashes. No source paths, persistent bookmarks, diagnostics, telemetry, password files or pairing records are created. Names appear only in the local UI/manifest and selected restore destination. Do not add vault records to diagnostic exports.
- A serial actor performs scoped, coordinated Files access and 64 KiB streaming SHA-256 off the main actor. Scopes are released on success and failure. Each source is re-read and compared; each stored blob is independently read back, even on reuse. All entries must verify before the manifest is atomically published. Failure rolls back blobs added by that attempt. Abrupt process termination can leave an unreferenced blob or stage file, but not a partially published checkpoint.
- Restore validates the manifest and blob, streams to a fresh temporary file in the chosen folder, verifies that file, then publishes with a same-directory exclusive rename. It never modifies a picked original. This preserves contents, not timestamps, extended attributes, or permissions. Normal failures clean up temporary files; a process kill can interrupt cleanup.

## Verification

On macOS with current Xcode command-line tools, run `sh tests/file-vault/run.sh`. The disposable fixture exercises the production store: two matching sources, reuse across checkpoints, reopening history, previous-version restore, collision with a changed original, missing and corrupt blobs, and rollback on a failed multi-file checkpoint. It needs no signing or device. On iOS, additionally check picker cancellation, denied/read-only providers, a source unavailable offline, size limits, and destination collisions.
