# Roadmap

Built in order, one shippable slice at a time. Each slice ends with simulator screenshots in `docs/app-screens/` for review. An IPA is built only after you approve.

**Legend:** ✅ done · 🔨 in progress · ⏳ next · ○ planned · 🔒 needs entitlement / account / hardware

## Phase 0 — Foundation
| # | Slice | Status | Test it |
|---|---|---|---|
| 0.1 | Repo: proprietary licence, README, gallery, docs, manual-only CI | ✅ | Browse the repo |
| 0.2 | Design system: tokens, 5 themes, type, components, motion, haptics | ✅ | Appearance screen |
| 0.3 | App shell: floating tab bar, Home, search launcher, toasts, sheets | ✅ | Launch the app |
| 0.4 | Onboarding: welcome, engine choice (Mac vs iPhone), permissions primer | ✅ | Fresh install |
| 0.5 | CI: simulator screenshot mode + unsigned IPA mode | ✅ | Actions › Run workflow |

## Phase 1 — The safety core ✅

> Runs on the **Demo engine** (a simulated device that has your real symptoms). On iPhone-only and Mac engines the same screens work but writes are refused until the tunnel and companion land (3.2–3.5), and the app says so.
| # | Slice | Status |
|---|---|---|
| 1.1 | Operation pipeline: re-read → diff → confirm → write → read back → receipt → rollback | ✅ |
| 1.2 | Receipts store + Undo history, per-change undo, Restore to before Assay | ✅ |
| 1.3 | Device check: real iOS facts + findings from known-culprit preference reads, tagged Observed / Inferred / Unknown | ✅ |
| 1.4 | Diagnose: describe or pick a problem → cause, confidence, current value, fix (9:41 clock, green line, touch dots…) | ✅ keyword match · AI reasoning arrives with 5.x |
| 1.5 | Fix sheet: review diff → dry run → applying → result → "is it fixed?" check | ✅ |

## Phase 2 — Gild (tweaks)
| # | Slice | Status |
|---|---|---|
| 2.1 | Catalogue model: tier, domain/key, versions, verification, conflicts, recovery | implemented · demo catalogue |
| 2.2 | Catalogue UI + review bar + tweak detail + Experimental confirm | implemented · staged review |
| 2.3 | Presets, compare/diff, import/export | built-in presets only; import/export pending |
| 2.4 | Custom tweak builder | ○ |
| 2.5 | Signed catalogue updates (x16) | ○ |

## Phase 3 — Engines
| # | Slice | Status |
|---|---|---|
| 3.1 | Engine protocol + Demo engine (lets every screen run with no device) | ○ |
| 3.2 | iPhone engine: pairing import, Keychain storage, connection health | ○ 🔒 |
| 3.3 | Loopback Network Extension (LocalDevVPN alternative) | ○ 🔒 paid team |
| 3.4 | Backup/restore transport with checkpoints, baseline reuse, honest progress | ○ 🔒 |
| 3.5 | Mac companion app + local pairing to the iPhone app | ○ 🔒 Mac |

## Phase 4 — Scenes & Studio
| # | Slice | Status |
|---|---|---|
| 4.1 | Scenes: recipes, composer, preview, consistency check, guided apply, snapshots (x10) | ○ |
| 4.2 | Palette Lab (x06) + Wallpaper-match theme | ○ |
| 4.3 | Canvas / Poster Studio: `.tendies` import, inspect, layers, timeline, validate, export (x11) | ○ |
| 4.4 | Cards: Wallet visual editor | ○ |
| 4.5 | Icon packs (x05) | ○ |
| 4.6 | Scene sharing `.assayscene` (x09) + automations via Shortcuts (x08) | ○ |

## Phase 5 — Alchemy (AI)
| # | Slice | Status |
|---|---|---|
| 5.1 | Providers: Minis, OpenAI, Anthropic, Google, OpenRouter, Ollama; Keychain keys; connection test | wired · simulator review; live providers not tested |
| 5.2 | Explain-before-execute plans | optional chat & symptom suggestions; advice only |
| 5.3 | Asset pipeline: prompt → draft → editor → before/after → apply | ○ |
| 5.4 | MCP bridge (read-only first, on-device approval for changes) | ○ |

## Phase 6 — Signet (signing)
| # | Slice | Status |
|---|---|---|
| 6.1 | IPA inspector: targets, entitlements, Info.plist, privacy manifests (x04) | local inspector · sample included |
| 6.2 | Signing matrix + entitlement diff | profile matrix · binary entitlements not read |
| 6.3 | App Store Connect API key: certificates, profiles, devices, expiry | ○ 🔒 |
| 6.4 | Per-target sign & verify, build receipts | ○ 🔒 |
| 6.5 | Expiry calendar (x12) + renewal assistant | expiry export only; renewal pending |
| 6.6 | **In-app installer/signer** — pulls the build, reads every target's entitlements, creates bundle IDs, capabilities and per-target profiles, signs each part, verifies, installs | ○ 🔒 |
| 6.7 | Sign-in: App Store Connect API key (default, official) · Apple ID login (opt-in, labelled risky, free accounts) · or import your own .p12 + profiles and Assay checks their entitlements against each target | ○ |

## Phase 7 — Lab & Tools
| # | Slice | Status |
|---|---|---|
| 7.1 | BLE scanner + notebook: RSSI, GATT, reads, authorised writes, history, export (x14) | simulator demo; accessory verification pending |
| 7.2 | LAN: Bonjour inventory, latency, TLS certificate check (x15) | simulator demo; real LAN verification pending |
| 7.3 | Passport & snapshot compare, post-update re-check (x02) | ○ |
| 7.4 | Crash/log explainer + sysdiagnose guide (x13) | ○ |
| 7.5 | Test bench, recovery coach, multi-device (x18) | ○ |
| 7.6 | Compatibility radar + opt-in community reports (x03) | ○ |

## Phase 8 — System surfaces
| # | Slice | Status |
|---|---|---|
| 8.1 | Widgets (Home + Lock Screen), Live Activity, Dynamic Island | ○ |
| 8.2 | Control Centre controls + App Intents / Shortcuts | ○ |
| 8.3 | App lock (Assay only, Face ID) (x07) | ○ |
| 8.4 | "Still good?" follow-ups (x17) | ○ |

## Phase 9 — Assay Pro
| # | Slice | Status |
|---|---|---|
| 9.1 | StoreKit 2 supporter purchase: Yearly £9.99 · Lifetime £29.99 — every feature stays free; Pro adds a badge and alternate icons | ○ |
| 9.2 | App Store Connect products `assay.pro.yearly`, `assay.pro.lifetime` | ○ 🔒 |

> **StoreKit note:** real purchases only work for App Store / TestFlight builds. A sideloaded build can test with the included StoreKit configuration file in the simulator only.
