# Test Assay 0.3 (build 3)

Use these tools without a pairing file or AI account. No device-wide reset is needed. The iOS app is independently built; no GoldenNugget data or code is included.

| Open | A useful first test | Known boundary |
|---|---|---|
| **Lab → Clock & Lock Screen** | While the status bar says 09:41, tap **My status bar shows 9:41**. Repeat once the live local clock has advanced a minute. Optionally import your GoldenNugget app log. | Device time is measured; status time is *reported by you*. Exact keys in complete preset lists show historical intent, not applied preferences. No write or backup. |
| **Lab → File Vault** | Save two small files with identical contents. Change one, take another checkpoint, then export the first version into an empty folder in Files. | Selected files only, stored locally, not a phone backup. Keep external copies before uninstalling. A name collision refuses the export instead of overwriting the destination. |
| **Scenes** | Create a named scene, choose a palette and theme, save, review and activate. Return to Scenes and undo. Export the scene's portrait wallpaper PNG to Files. | Appearance changes in Assay. Setting the PNG as your system wallpaper and placing Home Screen icons/widgets are manual. |
| **Studio → Signet → Check certificate & profiles** | Choose your **public** `.cer` and one or more `.mobileprovision` files. Enter the app/extension bundle ID and compare eligibility for each target. | Match/expiry checks do not validate Apple's CMS signature or sign/install an IPA. Do **not** import a private key or `.p12` here. |

## Backing up the iPhone itself

For a standard local device backup with no Assay tunnel, plug the iPhone into a trusted Mac and use **Finder → your iPhone → General → Back Up Now**. For a terminal workflow, see the optional [standalone USB backup utility](../../Mac/usb-backup/README.md). Reusing a dedicated backup folder allows the device to send changes where supported. A standard backup is not a drop-in replacement for a tweak app’s modified/protective backup.

## Automated evidence

The simulator workflow runs the production Vault against fixture files (content reuse, restoration, corruption, collisions and incomplete checkpoints), the Scene store with isolated defaults, seven clock cases plus log-list counting, and 46 certificate/profile parser and matching checks. The standalone USB utility has six fixture tests and has not been hardware tested. CI does not use your phone or Apple credentials.
