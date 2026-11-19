# Changelog

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
