# Feature-expansion bundle review

This folder contains owner-supplied visual concepts, not implemented functionality. The screenshots contain illustrative data. A screen should not be treated as evidence that the feature exists, is technically validated, or is approved for release.

## Concepts added

1. Full change history with per-operation Undo and a whole-session dry-run rollback plan.
2. Post-iOS-update compatibility re-check and a guided “what changed?” summary.
3. Compatibility reports, scoped to device/OS/build; proposed anonymous community reports.
4. IPA/package inspector for signatures, Info.plist, privacy manifests, frameworks, entitlements and per-target app/appex mismatches.
5. Icon packs and per-app icon customization.
6. Palette Lab to derive coordinated wallpaper/widget/icon/theme palettes with contrast checks.
7. Assay app lock/keypad theme. This can secure Assay’s own UI only; it does not lock other apps or replace iOS authentication.
8. Scene automation recipes through Shortcuts; be explicit that iOS controls what can run automatically and Home Screen layout steps may need manual confirmation.
9. Scene sharing/import with signature, provenance, licence and privacy review before adding assets or Shortcuts.
10. Home Screen layout snapshots and visual diff/restore.
11. Poster Studio for `.tendies` layer/timeline editing and validation.
12. Certificate/profile expiry calendar reminders.
13. Guided sysdiagnose capture and local parsing with redacted export.
14. BLE GATT detail, pinned peripherals, RSSI and timestamped value history.
15. Local-network TLS endpoint/certificate inventory for authorized networks.
16. Signed compatibility/tweak catalogue updates with pinned-key and downgrade checks.
17. Post-change “still good?” follow-up with easy rollback.
18. Multi-device dashboard for devices explicitly paired by their owners.
19. Proposed “Assay Pro” plan/pricing screen.
20. Optional Mac companion concept for USB workflows, long-running jobs, device dashboard and local receipts.

## Decisions that need explicit product review

- **Mac companion:** promising as a way to move heavy USB backup work off the phone and may address the user's slow-backup pain. It is a separate macOS product target and needs its own pairing, transport, update and local-sync design. The mockup’s “keeps going while iPhone is locked”, throughput, remaining-time and cache numbers are mock data—not verified behavior. Design it as a capability to investigate, not a performance claim.
- **Assay Pro:** not approved. Pricing, subscriptions, free-tier boundaries and whether any core feature is paid are open decisions. The source/AGPL language in the expansion mockup is not authoritative; this project is independently implemented and its licence is still undecided.
- **Community reports:** requires consent, abuse/privacy design, report provenance, moderation, signing-key lifecycle and a safe way to avoid false compatibility claims. Display sample counts and confidence; never treat reports as proof.
- **App lock:** scope is Assay itself only. Use supported LocalAuthentication/Keychain patterns and never imply iOS app-lock privileges over other apps.
- **Icons/layouts:** distinguish alternate-icon or Shortcuts approaches from actual SpringBoard layout APIs. Explain banners, automation permissions and version limitations.
- **TLS scan:** restrict to user-authorized local networks; inspect what endpoints present, with rate limits and no exploit or credential probing.
- **Catalogue signing:** signed data needs a documented pinned-key rotation, revocation and recovery process before release.

## Review gallery

Open `review.html` (download the repo and open it locally; GitHub does not render HTML) for a tap-to-enlarge gallery of the original core screens and the expansion screenshots. The HTML fragments in this folder are source concepts; some require the original prototype shell and are not standalone screens.
