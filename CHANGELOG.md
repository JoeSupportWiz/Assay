# Changelog

## 0.3.0 (3) — Device utilities
- Compare a reported status clock to actual system time, and check a local preset log for the two exact display settings; this does not reset SpringBoard.
- Create and undo Assay scenes; export new palette artwork at the display’s native resolution.
- File Vault checkpoints selected documents and verifies restored copies without overwriting originals.
- Signet matches a public signing certificate to profiles for specified bundle IDs without requesting a private key.
- Failed receipt items no longer count as verified changes. Old engine readings are cleared when you switch engines.

## Unreleased · Build 6 review
- Signet reads bounded per-target entitlement evidence from executables, with explicit Unknown states for unsupported or malformed binaries.
- Added a verified Assay build library, preset import/export review, optional Assay-only privacy lock and supporter purchase client. No App Store, TestFlight or signed-device verification yet.
- Repeat File Vault checkpoints reuse verified blobs without writing duplicate payloads.

## Unreleased · Studio and Lab integration
- **Analyse with Minis**: review an allowlisted snapshot, optionally add receipt summaries or counts from an imported backup log, then share or export. A local read-only MCP server compares user-approved exports. No pairing file or model key required.
- **Engine status** now distinguishes public iPhone checks from unimplemented system writes. The review sheet allows previews, not live writes, on real-device engines.
- Added [four feature test cards](docs/features/README.md): Bluetooth notebook, local network inventory, Signet IPA inspection and Alchemy chat. Simulator coverage is not live hardware or provider verification.
- Added an explicit, advice-only AI second opinion in Diagnose; keyword matching still works offline.
- Scoped custom AI credentials and hosted consent to their configured endpoints; credentials are never sent over HTTP.

## 0.2.0 — Phase 1 · Safety core
- **New** Every change goes through one pipeline: current value re-read, exact diff shown, written, read back, receipt kept.
- **New** Undo history: per-change undo, and Restore to before Assay. Changes that couldn't be read first are listed as not undoable.
- **New** Device check produces findings with evidence; Diagnose matches a described or picked problem to a cause with confidence.
- **New** Fix sheet with dry run, risk tier, "I understand" gate for Caution, and a "Is it fixed?" check only you can answer.
- **Changed** UI rebuilt on native iOS components: system tab bar, grouped lists, vector mark. Removed gradients, glows, shimmer, floating tiles, blend modes and springs.
- **Fixed** iPhone-only target (was also advertising iPad).

## 0.1.0 — Phase 0 · Foundation (in progress)
- **New** Fold design system: five themes (Light, Dark, Millennium, Pinstripe, Wallpaper match), springs, haptics, tags, pills, rings.
- **New** App shell with a morphing floating tab bar, search launcher and toasts.
- **New** Onboarding with your engine choice: Mac companion (fastest) or iPhone only (most private), plus a Demo engine.
- **New** Home: greeting, device chip, health and backup cards, Studio carousel, Needs-you queue.
- **New** Lab device passport from real iOS APIs, every value tagged Observed or Unknown.
- **New** Appearance with live theme previews; Engine settings.
- **Honest** Modules not built yet say so, with their roadmap phase.
- **CI** Manual-only workflow: simulator screenshots or unsigned IPA.
