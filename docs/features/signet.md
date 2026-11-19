# Signet — IPA inspector and signing matrix (Phase 6.1 / 6.2)

Root view: `SignetRootView` (App/Features/Signet/). All types are prefixed `Signet`.

## What it does
Choose an `.ipa` (or a zipped `.app`) and Signet reads it locally, with no Apple account:

- **App summary**: bundle ID, name, version/build, MinimumOSVersion, device families, URL schemes, background modes, usage-description keys present, `Frameworks/` listing, file size.
- **Targets tree**: the app and every nested `.appex`. Each row shows bundle ID (monospaced), profile name, expiry in days and a tag (more than 30 days = Valid, 7–30 = Caution, under 7 = Expiring soon, past = Expired). Tapping a row lists per-target checks, each tagged Observed / Inferred / Unknown.
- **Checks**: bundle ID vs profile App ID pattern; profile not expired; profile covers expected entitlements for the extension point (e.g. packet tunnel needs `com.apple.developer.networking.networkextension`); App Groups present in app and extensions; privacy manifest present; extension has its own profile; `get-task-allow` on a distribution profile; no `_CodeSignature` shows "Unsigned — ready for signing".
- **Entitlement matrix**: rows = entitlement keys, columns = targets, cells ✓ / – / ✗ (with words as well as symbols).
- **Requested vs allowed diff**: `−` (expected, missing from profile, red-ish) and `+` (allowed but not expected, green-ish), with the signs and words so colour is never the only signal.
- **Profile expiry**: every distinct profile with days left, plus a `ShareLink` for an `.ics` file (one event per profile at expiry, alarms at 14 days, 3 days and at expiry).
- **Build receipt**: plain text with app ID, version, targets, profile names, expiry, device *count* and SHA-256 of the file (CryptoKit, streamed in 4 MB chunks). Shareable.
- **Sign** button: present, disabled, labelled "Signing arrives in a later slice (needs your developer account or certificate)."

## Real, demo, later
| | |
|---|---|
| **Real** | Everything above for a file you import. ZIP central-directory reader (stored + deflate via `compression_decode_buffer(COMPRESSION_ZLIB)`, which is raw deflate), CRC-32 verification, Info.plist and profile parsing, SHA-256, ICS and receipt export. |
| **Demo** | The Demo toggle shows an in-memory fake app "Demo Notes" with 1 app + 3 extensions (Tunnel with a missing Network Extension entitlement, Widget with 45 days, Share with 5 days left). Carries a visible Demo tag on rows, headers and exports; the receipt says "DEMO DATA"; the SHA-256 is "Not computed". |
| **Later** | Signing, certificate import, reading entitlements from the Mach-O binary's code signature, CMS signature verification, ZIP64, creating/renewing profiles via the Apple developer API. |

## Method notes and limits
- Only needed entries are extracted into memory: `Info.plist`, `embedded.mobileprovision`, `PrivacyInfo.xcprivacy` (app only is parsed; others are just detected), `_CodeSignature/CodeResources` (presence only, never extracted), nested appex equivalents, and a first-level listing of `Frameworks/`. Nothing is written to disk.
- Limits: file ≤ 2 GB, each extracted entry ≤ 8 MB, central directory ≤ 64 MB. Zip-slip paths (absolute, `..`, backslash, NUL) make the whole file refused. Encrypted entries and methods other than stored/deflate are skipped (error for the app's Info.plist, a note for extensions). ZIP64 is refused with a message.
- Provisioning profile = CMS (PKCS#7). Signet scans for `<?xml` … last `</plist>` and parses that slice. The CMS signature is **not** verified, so Signet reports what the profile claims, not proof that Apple issued it.
- Profile type (Development / Ad hoc / Enterprise / App Store) is **Inferred** from `ProvisionsAllDevices`, `ProvisionedDevices` and `get-task-allow`; Apple does not label it.
- "Requested by target" in the matrix and diff is **Inferred** from the extension point, background modes and the other targets. **Binary entitlements not read (Unknown).**
- Privacy: certificates, device UDIDs and key material are never stored or exported; only counts are kept.
- Zipped `.app` support: a top-level `X.app/` folder or `Payload/X.app/`.

## How to test
1. Open Signet, switch on Demo, and walk through Targets, Matrix, Requested vs allowed, Expiry and Receipt. Expect: Tunnel shows a "Missing" ✗ / `−` for the Network Extension entitlement; Share shows "Expiring soon".
2. Switch Demo off, choose a real `.ipa` (signed with `embedded.mobileprovision`, and an unsigned one for the "Unsigned — ready for signing" path).
3. Share the `.ics` and import it into Calendar; check three alarms per event.
4. Try a non-ZIP renamed to `.ipa` (expect "This is not a ZIP archive") and a ZIP without Payload (expect the "does not look like an .ipa" message).

## Integration
No `AppModel` changes are required. The view uses `.themedList()`, `.rowCard()`, `Tag`, `PrimaryButtonStyle` and `Haptics`, and expects to sit inside an existing `NavigationStack` (it uses `NavigationLink` with destination views and sets its own navigation title). It does not touch the device and does not use `model.activePlan`.
