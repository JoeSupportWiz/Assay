# Signing and permissions

**Studio → Signet** can inspect a build without an Apple login. A profile match, a code signature, permission to install, and the user’s consent to use Bluetooth are four different things.

## Inspect before signing

1. Choose **Demo** in Signet for a sample, or turn it off and tap **Choose .ipa file** for a local IPA or zipped `.app`. Open the app target, then each embedded extension. A match for the app does not cover its widget.
2. In **Requested vs allowed**, compare each target’s declarations with what its profile allows. Read the source label: supported executable declarations can be observed; expected capabilities can be inferred. A matching key does not prove the values match. **Unknown** is not a pass.
3. For a separate offline check, open **Check certificate & profiles**. Choose one **public** `.cer` or certificate-only PEM and 1–6 `.mobileprovision` files. Enter one concrete target bundle ID and tap **Check target**. Read certificate inclusion, expiry and target match separately; repeat for the extension. **Clear selected data** clears the view, not your files.

## Who grants what?

| Decision | Authority and limit |
| --- | --- |
| May this target be signed for development? | Apple provisioning and a matching signing identity, per target. Signet preflight does not check Apple’s profile signature, private-key possession or device eligibility. It does not sign or install. |
| Does Assay change the developer team? | Not during inspection. In **Apple developer team**, loading inventory is a read; confirming **Create development profile** is a real Apple account write for one target. Skip this route for review. A team API key is not a code-signing identity. |
| May the installed app use a private resource? | The user decides at the iOS prompt for the feature, such as Bluetooth or Local Network. If denied, leave access off or revisit Assay’s permissions in Settings. Re-signing does not grant consent or unlock system preference writes. |

**For a later device build:** the owner handles signing in Apple’s toolchain (for example, Xcode’s **Signing & Capabilities** for both app and widget). Signet’s inspection receipt is not a signing or installation receipt.

Use Demo or synthetic fixtures for a shared walkthrough. Never attach private keys, profiles, pairing records, device identifiers or account details to a report.

[Field guide](Home.md) · [Testing and status](Testing-and-status.md)
