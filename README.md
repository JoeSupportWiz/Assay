# Assay

**Working name — not yet cleared for trademark or App Store use.**

Assay is an independent iPhone customization and developer studio: Scenes, supported tweaks, wallpaper and `.tendies` projects, app signing, diagnostics, BLE/LAN tools and AI-assisted creation. Its promise is *Shows its work*: explain changes, surface compatibility and risk, verify where iOS permits, and make recovery understandable.

## Independence and credit

Assay is a new project, **not a direct fork** of GoldenNugget Mobile. It is independently structured and implemented. We credit GoldensHQ and the GoldenNugget contributors as members of the iOS customization ecosystem whose work informed the product direction; no GoldenNugget source code or branding is included in this initial project scaffold. If licensed upstream code is incorporated later, review and comply with its license before doing so. Assay is unofficial and is not affiliated with or endorsed by Apple.

## Design foundation

The included Fold identity and UI references are supplied by the project owner in the Assay Design Bundle. The visual direction is light/dark, pastel, premium, playful-but-precise; five floating destinations (Home, Scenes, Studio, Lab, More); high-contrast black/white pill controls; spring motion with Reduce Motion fallbacks. Theme previews include Millennium, Pinstripe and Wallpaper Match. The name and identity remain subject to clearance.

## Current status

**Foundation prototype only.** The native app currently contains the home/navigation design shell and sample UI states explicitly labelled as previews. It does not yet connect to a device, run tweaks, create backups, sign apps, scan BLE/LAN, or call an AI provider. Those capabilities require separate implementation, capability audits and real-device validation. No simulated device state should be presented as live data.

The full product vision and platform constraints are documented in `Docs/PRODUCT_BRIEF.md`; design sources and screen references are in `design/`, `prototype/`, `docs/` and `brand/`.

## Build

The initial project is an XcodeGen project. With Xcode and XcodeGen available:

```sh
xcodegen generate --spec project.yml
xcodebuild -project Assay.xcodeproj -scheme Assay -sdk iphoneos \
  -destination 'generic/platform=iOS' -configuration Release \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

A macOS GitHub Actions workflow builds an unsigned archive/IPA for owner-managed signing. Signing credentials and API keys do not belong in this repository.

## Product boundaries

- No jailbreak-level access claims; each feature is version/entitlement gated.
- Live Activities show progress but do not keep the app executing.
- AI proposes; the user approves consequential changes.
- Wallet module is visual artwork only; it never touches payment credentials.
- BLE/LAN tools are visible, bounded and for authorized devices/networks.
- Secrets belong in Keychain; logs and export bundles redact identifiers by default.

## Credits

Thanks to GoldensHQ and contributors to GoldenNugget Mobile for valuable work in the iOS customization ecosystem. Other inspirations and third-party dependencies will be credited as implementation decisions are made. See `CREDITS.md`.

## Licence

The project licence is **not selected yet**. Do not redistribute this scaffold as a release until the owner chooses a licence and any bundled assets/dependencies have been reviewed.
