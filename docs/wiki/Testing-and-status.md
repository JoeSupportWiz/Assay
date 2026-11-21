# Testing and status

**Review baseline:** `integration/studio-lab-review` at `eab9ea7` · Assay 0.3.0 (7). Check **More → Version** before comparing results. This is a developer preview, not a signed-device acceptance report.

| Evidence | What it establishes | What it does not establish |
| --- | --- | --- |
| Simulator capture | The app rendered the pictured screen with review inputs. | Hardware behaviour, a live permission grant or an installation. |
| Offline fixture | The specific production logic handled its test inputs, such as refusing a restore collision. | Access to a particular Files provider, Apple team or phone. |
| Demo receipt | A simulated change was previewed or read back in Demo. | A physical repair or even a change to a real iPhone setting. |
| Unsigned IPA | The manual CI `ipa` mode packages unsigned code. | A trusted signature, successful installation, launch or distribution. |

## Repeat a check

- **Without a phone:** from the repository root on a Mac with Xcode command-line tools, run `sh tests/scenes/smoke.sh`, `sh tests/scene-transfer/smoke.sh` or `sh tests/file-vault/run.sh`. Scenes should restore the prior appearance; transfer should preserve existing scenes; Vault should refuse to overwrite a destination.
- **In the app:** open **Lab → Test bench**, choose a setup card and tap **Run saved checklist** twice. Compare the two runs from the same engine. An unselected check did not pass; it did not run.
- **On an approved device, later:** test Files picker cancellation and restore, Bluetooth and Local Network denial, and widget registration. Record build, OS version, engine, expected result and what actually happened. Use redacted observations, not raw logs or profiles.

No claim of a signed artifact, device installation, live Apple team transaction or working system-write engine follows from these checks.

[Field guide](Home.md) · [Signing and permissions](Signing-and-permissions.md)
