# Assay feature agent brief (read fully before writing code)

You are building ONE feature of Assay, a native SwiftUI iPhone app (iOS 17+), in a private repo at /var/minis/workspace/assay.
You work in a sandbox shell on a phone. There is NO Xcode and NO full type-checker here. You can only syntax-check.

## Hard boundaries
- Create files ONLY inside your own folder: App/Features/<YourFeature>/ and, if you need models, App/Core/<YourFeature>*.swift (prefix every type with your feature name to avoid collisions).
- DO NOT edit any existing file. Do not touch AppModel.swift, AppShell.swift, StudioView.swift, LabView.swift, MoreView.swift, Components.swift, Theme.swift, Catalog.swift, project.yml, scripts or docs outside docs/features/<yourfeature>.md.
- DO NOT run git. The lead merges your files.
- Never print or store secrets. Never claim a capability that iOS doesn't allow. No fake data presented as real: anything simulated must carry a visible "Demo" tag.

## How to check your work (fast, ~1s)
    /usr/local/swift/bin/swift-frontend -frontend -parse -swift-version 5 <files...>
This only parses. Be extra careful with types, optionals, and API names you can't compile. Prefer simple, well-known SwiftUI APIs (List, Section, LabeledContent, Toggle, Button, NavigationLink(value:), TextField, Picker, Stepper, ProgressView). Avoid anything iOS 18+ only. Avoid macros/@Previewable.

## Design rules (this is a "quiet native" UI; the user disliked decoration)
- Native grouped lists. Use `.themedList()` on the List and `.rowCard()` on every Section. No gradients, glows, shadows, blur, blend modes, springs, repeatForever animations, floating tiles, shimmer.
- Pinned primary action: `.safeAreaInset(edge: .bottom) { Button { } label: { Text("…") }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20).padding(.vertical, 10).background(.bar) }`.
- Plain labels. No cute greetings. UK English.
- Always pair colour with text. Evidence tags: `Tag(style: .observed | .inferred(Int?) | .unknown)`. Risk tags: `Tag(style: tier.tag)`.
- Text colours: `@Environment(\.theme) private var t` then t.ink, t.ink2, t.ink3, t.card, t.accentColor. Never hardcode black/white for text.
- Anything the real device or network might not provide must say so ("Not available", "Needs …"), never invent values.

## Existing APIs you may CALL (read the files for exact signatures)
- App/DesignSystem/Components.swift: Tag, TagStyle, IconTile(symbol:hue:size:), PrimaryButtonStyle, SecondaryButtonStyle, FactRow, FindingRow, ThemedBackground, .themedList(), .rowCard(), Haptics, Motion, Wordmark, FoldMark.
- App/DesignSystem/Theme.swift: Theme, ModuleHue (.lilac .sky .mint .butter .peach), Palette.
- App/Core/Models.swift: Fact, Evidence (.observed/.inferred(Int)/.unknown), DeviceSnapshot.
- App/Core/Operations.swift: PlistValue, PrefKey, Tier, Change, OperationPlan, Receipt, ReceiptStore.
- App/Core/AppModel.swift: `@Environment(AppModel.self) private var model` gives model.engine, model.snapshot, model.receipts, model.activePlan (set it to an OperationPlan to open the standard review/apply/undo sheet — USE THIS for anything that changes the device), model.show(Toast(...)), model.userName, model.expertMode.
- App/Engine/DeviceEngine.swift: DeviceEngine protocol, OperationRunner.
Any change to the device MUST go through `model.activePlan = OperationPlan(...)` so it gets preview, dry run, read-back, receipt and undo. Never write to the device directly.

## What to deliver
1. Swift files, each starting with `import SwiftUI` (and others you need). Top-level entry: ONE public root view named `<Feature>RootView` (no init params; reads `@Environment(AppModel.self)`), plus any models/services it needs.
2. Keep file count small (2–6 files). Prefer correctness over breadth. Every screen must have loading, empty, error and "not available on this engine" states where relevant.
3. docs/features/<yourfeature>.md: what it does, what is real vs demo vs not-yet-possible, how to test it, known limits.
4. A final message listing: files created, the root view name, any new `AppModel` properties/routes you NEED the lead to add (exact code), and anything you were unsure compiles.

Run the parse check on every file you create and fix every error before finishing.
