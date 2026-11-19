# Signer preflight

Open **Signer preflight**, choose a public certificate, then select one to six provisioning profiles together. Enter a concrete bundle ID and tap **Check target**. Each profile has separate observations: certificate inclusion, expiry against the displayed comparison time, and target-pattern match. Editing the target or replacing files invalidates the target result. Picking profiles replaces the batch; a bad profile does not hide the others. Profile numbers follow picker return order. Use **Clear selected data** to reset the session.

- **Certificate:** a single DER X.509 `.cer` or a single `CERTIFICATE` PEM in `.pem`/`.cer` (64 KiB). Security creates a `SecCertificate` and CryptoKit hashes its complete DER, not a key, subject name, or PEM text. The X.509 validity start and expiry are displayed independently. No `.p12`, passwords, chains, private keys, Keychain access or trust evaluation.
- **Profiles:** `.mobileprovision` only (2 MiB each). The reader walks the CMS SignedData envelope to the encapsulated plist, including primitive and one-level chunked BER octet strings. It does **not** verify the CMS signature. A matching digest among the declared `DeveloperCertificates` is an observed inclusion; a non-match is conclusive only for a completely readable list. Missing, malformed or oversized (>32 entries) lists give Unknown rather than a guessed negative. A present empty list contains no certificate.
- **App ID:** `Entitlements.application-identifier` must begin with one of the profile’s `ApplicationIdentifierPrefix` values; the team ID is not substituted. Only literal, `*`, and final whole-component `.*` patterns are supported. `com.example.*` matches `com.example.app`, not `com.example` or `com.examplex.app`. Comparison preserves case. Missing or unsupported patterns give Unknown. The target must be concrete ASCII letters/digits/hyphens in nonempty dot-separated components, at most 255 bytes.
- **Time:** comparisons use the local clock at import or explicit check. A date at or before that instant is reported expired. A missing or unreadable date is Unknown.
- **Privacy:** the importer reads security-scoped local files in bounded chunks on a background actor. There is no upload, copy to app storage, telemetry, persistent bookmark or raw profile display. Only derived observations are kept while the view is open. Clearing or leaving cancels pending work and drops those observations; it does not erase source files. Choose already-local files for fully offline use; Files providers control their own downloads.

These observations do not establish authenticity, revocation status, device eligibility, entitlement compatibility or possession of a private key. There is no signing or install operation here.

## Integration and offline test

The parent adds `NavigationLink("Signer preflight") { SignerPreflightView() }` in its existing navigation. XcodeGen already includes `App/`; there are no build-setting or CI changes. The existing IPA inspector’s profile summary counts certificates and flattens entitlements; preflight instead needs individual DER fingerprints and does not keep those entitlements.

From the repository root with a Foundation-capable Swift compiler:

```sh
(
  set -eu
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  src=App/Features/Signet
  swiftc "$src/SignerPreflightRules.swift" "$src/SignerPreflightEnvelope.swift" \
    tests/signer-preflight/main.swift -o "$tmp/check"
  "$tmp/check"
  swiftc -frontend -parse "$src"/SignerPreflight*.swift
)
```

The suite uses deterministic date boundaries, synthetic digest lists and in-memory ASN.1 structures. It does not authenticate a profile or exercise the Apple file picker. The parent’s iOS build should type-check the full view and reader against the Apple SDK. On a future UI run, check replacement/cancellation, malformed and oversized selections, wildcard boundaries, edited targets and clearing during an import. No key, signing account or device registration is required.
