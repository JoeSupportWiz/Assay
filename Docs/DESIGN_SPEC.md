# Assay: Brand, UI & Motion Specification

*v1.1 · 19 November 2026 · working name "Assay" (availability not yet cleared) · identity: **Fold***

![Hero](docs/showcase/hero.png)

## 0. How to read this
This is the complete visual and interaction spec for the approved direction. Values are in **points (pt)** at 1×. The mockups render at 393×852 pt (iPhone 16 Pro) at @3x. "Spring" means a physical spring unless a curve is given. Every animation has a **Reduce Motion** fallback (§9.9). Colour and contrast values were measured (§3.5).

---

## 1. Brand foundations

**Promise:** *Shows its work.* Assay never hides what it's doing, what it knows, or what it can't do.

**Personality:** calm, exact, playful and premium. The structure is serious and the surface is joyful.

| We are | We are not |
|---|---|
| Confident, honest, specific | Hype, "magic", vague |
| Playful in colour and motion | Childish in copy |
| Native and Apple-quality | A hacker console, cyberpunk or neon |
| Respectful of risk | Alarmist red-everything |

**Voice rules**
1. Say what will happen *before* it happens: "This removes one key. You can undo it."
2. Name the limit plainly: "iOS doesn't tell apps this, so we're asking you."
3. Never claim success without proof. Use "Value removed · read back OK", not "Fixed!"
4. Keep sentences short: verbs first, no exclamation marks except in celebration toasts (max one).
5. Use British English in UK builds (customise, colour) and localise elsewhere.
6. Numbers beat adjectives: "4 days left", not "Expiring soon".

**Naming system:** metalwork-flavoured module names with a plain-English subtitle **always shown** beside them. Gild · Customise, Canvas · Wallpapers, Cards · Wallet visuals, Signet · Signing, Vault · Backups, Alchemy · AI, Device check, Tools.

## 1A. Identity: Fold

![Mark](docs/brand/lockup-sheet.png)

**Concept.** Three offset planes fold into one layered mark. It stands for composition (Scenes, Studio) seated on evidence (Lab): layers that line up exactly once they're verified.

**Parts**
- **Symbol:** three planes with 2 pt seams. The source is `brand/svg/symbol.svg` (viewBox 0 0 100 100; tight bounds x 17–67, y 5.5–77).
- **Wordmark:** "Assay" in Inter Display 750, tracking −4.5% to −6%. For production, replace it with a licensed, custom-tuned geometric grotesk and convert to outlines.
- **Lockups:** horizontal (symbol height = cap height × 1.45, gap = 0.35 × symbol width) and stacked (symbol above, gap 0.2 × symbol height).
- **Colour:** solid `#111113` on pastel or paper; `#F5F4F0` on dark; white on XP blue and on Pinstripe gloss; white at 95% on wallpaper glass. The planes are **never** split into different colours.
- **Clear space:** at least the height of the upper plane on every side.
- **Minimum size:** 24 pt for the symbol, 16 pt only in simplified use; 80 pt for the horizontal lockup.
- **Don't:** skew, rotate, outline, bevel the core mark, add drop-shadows in UI (icons only), or put it on busy imagery without a glass plate.

**App icons** (rebuilt from the source SVG). The mark is optically centred at 55% of the canvas height, with no seam bands.

![Icons](docs/brand/icon-preview.png)

| Variant | Background | Mark |
|---|---|---|
| Light (primary) | Lilac → sky → mint 135° gradient, plus a soft white radial at the top-left | `#111113` with shadow `0 22 26 rgba(58,42,128,.28)` |
| Dark | `#26232F → #121214 → #1B1730`, plus a 35% lilac glow at the top-right | `#F5F4F0` |
| Tinted | Transparent (iOS applies the tint) | White → `#BDBDBD` vertical |
| Pinstripe (alternate) | Pinstripes, plus a dark glossy inset (radius 190) with a hard-stop gloss cap | `#EEF3FA` |
| Millennium (alternate) | `#3A8CFF → #0844C7` with a 38% top gloss | White with a blue drop shadow |
| Wallpaper (alternate) | Dusk gradient | White at 95% |

`AppIcon.appiconset` uses the iOS 18 single-size format with light, dark and tinted appearances. The alternate icons are registered under `CFBundleAlternateIcons` and switch with the theme once the user confirms.

**Launch animation (≈1.6 s total)**

| Time (ms) | What happens |
|---|---|
| 250 | The upper plane drops 8 pt into place (`spring`, overshoot). |
| 430 | The centre plane rises 10 pt and seats; the seam settles at 2 pt. |
| 670 | The lower plane folds up from scaleY 0.6, overshoots to 1.04 and settles. |
| 1050 | A single soft highlight sweeps across the seams (700 ms, 55% white, skewed −20°). |
| 1150 | The wordmark rises 10 pt and fades in. |
| 1400 | The tagline fades in. |
| 2450 | Handoff to Home: the splash scales to 1.08 and fades over 500 ms while the Home stagger begins underneath. |

Reduce Motion shows the static lockup and cross-fades to Home after 300 ms. See `docs/motion/logo-launch.mp4`.

![Launch](docs/screens/00-launch-light.png)

**Glyphs.** The pack's 24 pt outline glyphs (1.9 stroke, round caps and joins) are used for Home, Studio, Lab, More, Gild, Canvas, Cards, Alchemy, Device check, BLE, Network and Vault. Two are replaced:
- **Scenes** gets two offset planes taken from the Fold geometry. The delivered glyph was the same as Canvas, and Scenes is the hero feature.
- **Signing** keeps the rosette (signet), because a pencil reads as "edit".

---

## 2. Layout & structure

### 2.1 Grid
- **Screen margins:** 20 pt left/right (22 pt for text-only headings, an optical inset).
- **Gutters:** 12 pt between cards; 10 pt between buttons in a row; 6–8 pt between chips.
- **Vertical rhythm:** 24 pt above a section header, 12 pt below it. 14–16 pt between stacked cards. The first content block starts 10–18 pt below the status bar.
- **Safe area:** content scrolls under the floating tab bar. Reserve 128 pt of bottom inset (tab bar 68 + gap 30 + breathing room 30) so the last row can scroll fully clear.

### 2.2 Navigation
- **Floating tab bar** (5 tabs: Home, Scenes, Studio, Lab, More). It's a pill 68 pt tall, inset 20 pt from the sides and 30 pt from the bottom, with radius 34. Background is `tabBar`, with shadow `0 18 40 rgba(17,17,19,.25)`.
  - Inactive tab: a 48×50 circle with a 23 pt icon in `tabInk`.
  - Active tab: expands to a 100×50 pill filled `tabActive`, with icon + label (14/600) in `tabActiveInk`.
  - On tab change the pill **slides and morphs** between positions (matchedGeometryEffect, spring default). The label fades in 80 ms after the pill lands. Haptic: `.selection`.
- **Top bar:** no system nav bar. A 46 pt circular back button (card fill) sits on the left. Contextual chips (status or provider) sit on the right, 34–46 pt tall.
- **Large titles:** 30–32 pt Inter Display 700, −3% tracking. On scroll past 40 pt the title shrinks into a centred 17 pt inline title, with the background blurring in (`.ultraThinMaterial`) over 200 ms.
- **Universal search / launcher:** a 52 pt pill on Home, and pull-down anywhere. It searches tweaks, findings, targets, assets and actions. Results group under coloured module headers. Pressing return on an action runs it **through the normal review sheet**, never directly.
- **Expert mode:** a toggle in Settings. It shows raw plist keys, bundle IDs, GATT UUIDs and transport stats inline in mono. It's off by default.

### 2.3 Information architecture
```
Home ── readiness, active operation, Needs-you queue, recent Scene, quick checks
Scenes ─ recipes (Work · Sleep · Travel · Research · Minimal · One-page · Colour-flow)
         → compose (wallpaper · layout · widgets · Shortcuts · Focus) → consistency check
         → preview → apply sheet (Automatic vs Guided steps) → verify → receipt → restore
Studio ─ Gild (tweak catalogue, custom builder, presets) · Canvas (.tendies / Camlo)
         · Cards (Wallet visuals) · Alchemy (AI Workshop & asset pipeline)
Lab ──── Device check & passport · Compatibility radar · Change timeline · Crash/log explainer
         · Signing desk (matrix · entitlement diff · build receipts · renewal)
         · Vault (backup health · dry-run restore · transport diagnostics · recovery coach)
         · BLE notebook · Network inventory · Pairing/connection health · Test bench
More ─── Appearance · AI providers · MCP bridge · Permissions & privacy · Updates · Audit history
```

---

## 3. Colour

### 3.1 Core tokens
| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#F3F2EE` warm paper | `#0B0B0D` | Screen background |
| `card` | `#FFFFFF` | `#17171A` + 1 pt `#202024` border | Cards, rows, sheets |
| `ink` | `#111113` | `#F5F4F0` | Primary text and icons |
| `ink-2` | `#6B6B72` | `#9A9AA2` | Secondary text |
| `ink-3` | `#A3A3AA` | `#5E5E66` | **Decorative only**: dividers, inactive dots (fails text contrast) |
| `soft` | `#F3F2EE` | `#222226` | Inset fills, secondary chips |
| `primary` | `#111113` | `#F5F4F0` | Primary buttons, active chip |
| `onPrimary` | `#FFFFFF` | `#111113` | Text on primary |
| `hero` | `#111113` | `#1D1D21` | The one dark "feature" card per screen |
| `accent` | `#FFE58A` butter | `#FFE58A` | Live / attention cards |

### 3.2 Pastel module palette (tile background / glyph gradient)
| Name | Tile | Gradient (top-left → bottom-right, 150°) | Dark tile |
|---|---|---|---|
| Lilac (Gild, AI) | `#DCD1FF` | `#A893FF → #6A47F5` | `#241D45` |
| Sky (Canvas) | `#C4E6FF` | `#7CC4FF → #1F84F0` | `#10283D` |
| Mint (Cards) | `#BDF3D7` | `#6EE7B0 → #1FAE6E` | `#0F3123` |
| Butter (Live) | `#FFE58A` | `#FFE58A → #E9A93A` | (unchanged) |
| Peach (Attention) | `#FFD6BF` | `#FFB07A → #FF7A3D` | `#3A2216` |

**Glyph tile recipe:** a 58 pt squircle, radius 20, filled with the gradient. Inner highlight `inset 0 2 0 rgba(255,255,255,.4)`, plus a coloured shadow `0 10 20 <gradient-end @35%>`. White 28 pt glyph, stroke 2.1.

### 3.3 Semantic colour (never decorative)
| Meaning | Background | Ink | Shape |
|---|---|---|---|
| **Reversible / Low risk** | `#BDF3D7` | `#0D5C37` | Filled pill |
| **Caution** | `#FFE58A` | `#5A4300` | Filled pill |
| **Experimental** | `#FFD6BF` | `#8A3300` | Filled pill |
| Unavailable on this iOS | `soft` | `ink-2` | Filled pill + lock icon, row at 55% opacity |
| **Observed** (fact) | `#C4E6FF` | `#0A4A85` | Filled pill |
| **Inferred** (our reasoning) | `#DCD1FF` | `#3A1FA8` | Filled pill + confidence % |
| **Unknown** (iOS doesn't say) | transparent | `ink-2` | **1.5 pt dashed** outline, so it reads differently in mono too |
| Success | `#38C98A` | white | Check disc |
| Live / in progress | `#FFE58A` | `#111113` | Disc with 5 pt halo `rgba(255,229,138,.35)` |
| Diff removed / added | on `#111113`: `#FF9A8A` / `#8CF0B8` | comments `#8E8E96` | Mono 12 pt |

Every semantic state carries **text and shape**, not only colour (dashed vs filled; icon). Red is never used for "warning". Peach is the strongest attention colour, and true red `#FF453A` is reserved for *destructive confirm* buttons only.

### 3.4 Themes
![Themes](docs/showcase/themes.png)

| Theme | Character | Key moves |
|---|---|---|
| **Assay Light** | Default in Light mode | Paper background, white cards, black pills, pastel tiles |
| **Assay Dark** | Default in Dark mode | Near-black, raised `#17171A` cards with hairline borders, inverted pills, deep-tinted tiles keeping vivid glyph gradients |
| **Millennium** (XP homage) | Nostalgic, friendly | `#ECE9D8` window beige, Tahoma, 8 pt radii, `#7F9DB9` 1 pt borders. Hero card is a blue title-bar gradient (`#0A5BE8 → #3A8CFF 12% → #0B55DB 55% → #0844C7`). Primary is a green glossy pill. The tab bar is a full-width taskbar: blue gradient, green "Home" pill with italic bold label and a right rounded edge, and a light-blue clock tray on the right. Progress bars are segmented green blocks (8 pt segments, 2 pt gaps). |
| **Pinstripe** (iOS 4 homage) | Skeuomorphic gloss | Vertical pinstripes (5 pt `#C5CCD4` + 2 pt `#CBD2D8`), Helvetica Neue, 11 pt radii, `#A7ABB2` borders, header text with a white 1 pt emboss. Hero, accent and buttons use **hard-stop gloss** (two gradients meeting at 50%). Glyph tiles get a curved gloss highlight. The tab bar is a black glossy strip with labels, and the active tab gets a 14% white plate plus a blue `#6FB8FF` glow. |
| **Wallpaper match** | Personal, glassy | Background is the chosen wallpaper. Cards are frosted glass (`rgba(255,255,255,.13)`, blur 22, saturate 1.4, 1 pt white-20% border). Primary uses the lightest warm swatch, with text in the darkest swatch. |

**Wallpaper palette extraction**
1. The user picks a source: a wallpaper made in Canvas, a photo (PHPicker; no library permission needed), or a single colour from the eyedropper.
2. Downscale to 64×64 and run k-means (k=5) in OKLab.
3. Sort the swatches by lightness. The lightest becomes `primary` and the darkest `onPrimary`; the most chromatic mid swatches become tiles at 30% alpha.
4. **Contrast guard:** iteratively darken or lighten text tokens in OKLab until body text is ≥4.5:1 against the *blurred* card composite (sampled at 9 points). If it can't pass, fall back to a 45% dark scrim behind the content.
5. Recompute whenever the source changes. Results are cached by image hash.
6. Copy: "iOS doesn't share your wallpaper with apps, so colours come from Canvas or a photo you pick."

**Alternate app icons** follow the theme, but only after the user agrees to iOS's "You have changed the icon" alert.

### 3.5 Measured contrast (WCAG 2.x)
| Pair | Ratio | Verdict |
|---|---|---|
| Ink on light bg | 16.8 | AAA |
| Ink-2 on white card | 5.3 | AA |
| Ink-2 on light bg | 4.7 | AA |
| Ink-3 on white | **2.5** | Decorative only. **Search placeholders must use ink-2** in production. |
| Dark ink on dark bg | 17.9 | AAA |
| Dark ink-2 on dark card | 6.4 | AA |
| Ink on butter | 15.1 | AAA |
| Tier/evidence tags | 6.1–7.5 | AA |
| White on XP blue `#0B55DB` | 6.3 | AA |
| White on XP green `#36A02C` | **3.4** | Large/bold text only. Darken buttons to `#2A8422` (≥4.5) for 16 pt labels. |
| Black on pinstripe | 13.0 | AAA |
| White on iOS 4 blue | 5.3 | AA |
| Wallpaper onPrimary on primary | 11.8 | AAA |
| Diff red / green on `#111113` | 9.2 / 13.7 | AAA |

---

## 4. Typography
| Role | Family | Size / line | Weight | Tracking |
|---|---|---|---|---|
| Greeting / large title | Inter Display | 32 / 34 | 700 | −3% |
| Screen title | Inter Display | 30 / 32 | 700 | −3% |
| Section header | Inter Display | 21 / 26 | 700 | −2.5% |
| Hero metric | Inter Display | 44 / 44 (unit at 24) | 700 | −3% |
| Lock Screen clock (wallpaper preview) | Inter Display | 88–96 | 600 | −4.5% |
| Card title | Inter Display | 19 / 22 | 650 | −2% |
| Sheet title | Inter Display | 22 / 26 | 700 | −2% |
| Row title / body strong | Inter | 15 / 20 | 600 | −1.5% |
| Body | Inter | 14–15 / 21 | 400–500 | −1% |
| Caption | Inter | 12.5–13 / 17 | 500 | 0 |
| Tag | Inter | 11.5 / 24 (pill) | 700 | +1% |
| Code, keys, IDs | JetBrains Mono (SF Mono on device) | 12 / 20 | 500 | 0 |
| Millennium | Tahoma → Verdana | headings 27 pt | 700 | 0 |
| Pinstripe | Helvetica Neue | headings 27 pt | 700 | 0 |

- **Greeting pattern:** two lines. Line 1 is in `ink` ("Hey Joe,") and line 2 in `ink-3` ("what are we making?"). This two-tone headline is a signature move; reuse it for empty states.
- **Dynamic Type:** every style maps to a text style (`.largeTitle` → `.caption2`) and scales up to AX5. At ≥ XXXL the two-up card grids collapse to one column and carousels become vertical lists.
- Use tabular numbers (`.monospacedDigit()`) for every changing number: percentages, bytes, RSSI and timers.

---

## 5. Shape, depth & iconography

### 5.1 Radii
| Element | Radius |
|---|---|
| Big feature card | 28 (continuous squircle) |
| Wallpaper preview | 34 |
| Module tile inside card | 18–20 |
| Icon disc in rows | 14 |
| Buttons, chips, search, tab bar | fully round (height ÷ 2) |
| Bottom sheet | 40 (inset 8 pt from the screen edges, matching device corners) |
| Toast | 24 |
| Code / diff block | 16 |
| Millennium | 8 / 4 / 4 |
| Pinstripe | 11 / 13 / 9 |

### 5.2 Elevation
| Level | Shadow | Use |
|---|---|---|
| 0 | none | Cards on paper (contrast comes from fill, not shadow) |
| 1 | `0 6 16 rgba(40,35,25,.08)` | Floating chips |
| 2 | `0 14 30 rgba(0,0,0,.20)` | Review bar, cart pill |
| 3 | `0 18 40 rgba(17,17,19,.25)` | Tab bar |
| 4 | `0 30 60 rgba(40,35,25,.16)` + level 1 | Popovers, floating cards |
| 5 | `0 −10 50 rgba(0,0,0,.25)` + 40% dim | Sheets |
| Coloured | `0 24 50 <hue @28%>` | Wallpaper previews, gradient tiles |

### 5.3 Icons
- 24 pt grid, 1.9 pt stroke (2.1–2.4 on small discs), round caps and joins, 2 pt corner radius on rectangles. Filled only for the *active* tab icon.
- In-app glyphs are custom and drawn to match SF Symbols' optical weight. SF Symbols can be used for system-standard actions (share, trash, chevrons).
- Glyph set: home, studio (sparkline square), signet (rosette), device (phone), sliders (Gild), photo (Canvas), card (Cards), sparkle (Alchemy), download tray (Vault), bluetooth, radar, bell, search, sparkle-burst (AI search), lock, check, arrow-up-right (open), chevrons.

---

## 6. Components (every state)

### 6.1 Buttons
| Variant | Size | Fill / text | Use |
|---|---|---|---|
| **Primary pill** | h 54 (52–58), radius full, min-w 120, label 16/600, optional trailing 14 pt arrow | `primary` / `onPrimary` | One per view: Apply fix, Review & apply |
| **Secondary pill** | h 54 | `card` (+border in dark) / `ink` | Dry run, Refine, Roll back |
| **Compact pill** | h 36–44, padding 16–18 | primary | Inline actions: Renew, Review, Resume |
| **Icon circle** | 46 (36 in cards) | primary or card | Bell, back, add, open ↗ |
| **On-accent button** | h 42 | `#111113` / white, always | Buttons on butter cards keep contrast in every theme |
| **Destructive** | h 54 | `#FF453A` / white | Only on the final confirm of irreversible actions |
| **Text link** | 14/500 + 7 pt chevron | `ink-2` | "See all ›" |

**States**
- **Rest:** as specified.
- **Pressed:** scale 0.96 and brightness −4% over 120 ms ease-out. It springs back with `snappy` on release. Haptic `.light` on touch-down for primary only.
- **Disabled:** 40% opacity with no shadow. A long-press shows a tooltip with the reason ("Connect your iPhone first").
- **Loading:** the label cross-fades (150 ms) to a 16 pt spinner plus a verb ("Applying…"). Width is locked so it doesn't jump, and repeat taps are blocked.
- **Success:** the fill morphs to mint `#38C98A`, a check draws (stroke-dashoffset, 300 ms), and haptic `.success` fires. It reverts after 1.4 s or the screen moves on.
- **Failure:** a horizontal shake (3 cycles, 6 pt amplitude, 360 ms), haptic `.error`, and an inline reason under the button. The button never turns red.
- **Focus (keyboard / Switch Control):** a 3 pt `ink` ring with a 2 pt offset.
- **Hit area** ≥ 44×44 always. Icon circles under 44 get invisible padding.

### 6.2 Chips & filters
- **Filter chip:** h 36, padding 15, 14/600. Off: `card` with border. On: `primary` fill.
  - When the selection changes, the fill **slides** to the new chip (matched geometry, snappy), and the content list cross-fades and re-staggers (60 ms per row).
  - Chips scroll horizontally with a 20 pt leading inset and the last chip partly cut off, as an affordance that there's more.
- **Status chip:** h 30–34 with a 7 pt dot.
  - A dot with a 4 pt halo means live (mint for connected, sky for scanning, with a pulse at 1.6 s period and opacity 1 → .45).
- **Tag (tier/evidence):** h 24 (20 inside rows), 11.5/700, radius full. It is never interactive. Tapping the row opens the explanation instead.

### 6.3 Cards
- **Hero card** (one per screen max): `hero` fill, `heroInk` text. Optional soft radial glow (140 pt, top-right, 28% of a pastel). Contains a title (19/650, two lines), a metric (44/700) and a ring or illustration.
- **Accent card:** `accent` fill. Shows live work and has a **shimmer** (a 100° white 55% band sweeping every 2.6 s, starting 1.2 s after appear). Its "Live" tag sits top-right.
- **Module tile card:** 156×178. Pastel fill, a 58 pt glossy glyph tile that **floats** (±6 pt over 6 s ease-in-out, with phases offset by −2 s per card), title 18/700, subtitle 13 in `tileSub`, and a 36 pt ↗ circle bottom-right.
- **List card:** rows separated by 1 pt hairlines inset 66 pt (aligned to text, past the icon).
- **Finding card:** tags row → title (18/700) → reason (13.5, 2 lines) → evidence lines (tag + mono value) → two buttons (Evidence / Preview fix). The **selected** finding gets a 2 pt `ink` outline ring.
- **Floating info card** (marketing and contextual popovers): white, radius 26, elevation 4, padding 16, width 250–340.

### 6.4 Rows
- Min height 60 with padding 12/14. A 42 pt icon disc (radius 14), then title 15/600 over subtitle 12.5/`ink-2`, then a trailing element: toggle, tag, value or chevron.
- Swipe actions: leading = favourite (butter), trailing = details (soft) and roll back (peach). The full swipe performs the first action **only if it's reversible**.
- Unavailable rows show at 55% opacity with a lock disc and the subtitle "Not available on iOS 26.1 · why?". Tapping opens the compatibility popover.

### 6.5 Toggles
- 50×30 track and a 26 pt white knob with shadow `0 2 6 rgba(0,0,0,.25)`. The track is mint `#38C98A` when on.
- On flip:
  - the knob slides with `snappy`;
  - the knob squashes to 30×26 mid-travel;
  - the track colour cross-fades over 200 ms;
  - haptic `.selection` fires.
- **Toggling a tweak never applies it.** It adds the tweak to the **review bar**, which pops up at the bottom (§7.4).
- Millennium uses square corners (radius 3/2). Pinstripe uses a blue gloss track.

### 6.6 Search field
- h 48–52, radius full, `search` fill, 19 pt magnifier, placeholder in `ink-2`.
- A trailing 38 pt "AI search" sparkle-burst button opens natural-language mode: the field grows to two lines and the placeholder becomes "Describe what's wrong…".
- On focus the field lifts (scale 1.02 + elevation 1), and the content below dims to 92%.

### 6.7 Segmented control (Auto / Light / Dark)
- h 46 in a `card` capsule with 4 pt padding. The knob is filled `ink` and the active label is in `bg`.
- The knob slides with `spring default` (0.5 s) and slightly overshoots. Labels cross-fade colour over 300 ms.

### 6.8 Progress
- **Ring:** stroke 5–10 with round caps, track `ringTrack`. It fills from 12 o'clock with `ease.out` over 1.4 s on appear, and live updates animate with `snappy`. The value sits in the centre with tabular numbers.
- **Bar:** h 8, radius 4. It grows from the left with `scaleX` over 1.4 s. Millennium uses a segmented bar.
- **Step list:** each step has a 26 pt disc.
  - Done: mint with ✓ (the check draws in 250 ms).
  - Active: butter with a halo and a spinner turning at 1 rev/s.
  - Waiting: `soft` with the step number.

  When a step completes, its disc pops (scale 1.15 → 1 bouncy), the next one gains its halo, and the row text weight steps from 500 to 600.
- **Stall state:** if progress hasn't moved for 10 s, the bar gets a diagonal 45° stripe pattern moving at 1 s per cycle, and the caption reads "Waiting on the device…". After 60 s it offers Retry / Details.

### 6.9 Diff block
- `#111113` with radius 16, padding 12/14, mono 12/1.7. A comment line names the file or domain. `-` lines are in `#FF9A8A` and `+` lines in `#8CF0B8`.
- Long values truncate in the middle. Tap to expand to full width with horizontal scroll. Long-press copies the value (in Expert mode only).

---

## 7. Popups, sheets & overlays

### 7.1 Bottom sheet (Review fix, Review changes, Renew, Write characteristic)
- Inset 8 pt left, right and bottom, radius 40, `card` fill, 38×5 grabber. The content behind dims with a 40% black scrim.
- **Enter:** the sheet travels from `translateY(110%)` to 0 with `spring(response .55, damping .78)` and the scrim fades in over 400 ms. Haptic `.medium` when it settles.
- **Detents:** medium (~55%) and large. Dragging follows the finger 1:1, with rubber-banding past the top. Release with velocity > 600 pt/s to dismiss.
- **Stages inside one sheet:** Review → Applying → Result. Content swaps with a pop (scale .96 → 1, opacity 0 → 1, bouncy spring) while the sheet height animates to fit (spring default). The sheet never closes and reopens between stages.
- **Dismiss guard:** while *Applying*, swipe-to-dismiss is disabled, and the grabber is replaced by a lock glyph and the caption "Finishing safely…".

### 7.2 Toast / banner (top drop-in)
- Positioned 58 pt from the top, inset 16, radius 24, `card` fill, elevation 4. Layout: 42 pt icon disc, title 15/600, subtitle 12.5, and an optional trailing action chip ("Undo").
- **Enter:** from `translateY(−220%)` to 0 with bouncy spring. Haptic `.success` or `.warning`.
- It auto-dismisses after 4 s (6 s if it has an action). Swipe up to dismiss, tap to open.
- Toasts queue at most one deep. A newer toast replaces the older one with a vertical cross-slide.

### 7.3 Floating popovers (compatibility, "why?", provider)
- Anchored to the tapped element with a 10 pt arrow, max width 300, radius 22.
- **Enter:** scales from 0.85 at the anchor point plus a fade (bouncy, 450 ms). Tapping outside dismisses with a fast 150 ms fade.
- Example content: "Lock Screen clock · Supported · iOS 26.1", "Last verified on 26.1 (build 23B85) · 2 sources".

### 7.4 Review bar ("3 changes ready")
- A 60 pt pill, accent fill, 20 pt above the tab bar, elevation 2.
- It appears when the first change is staged: it rises from 30 pt below with scale .9 → 1 (bouncy). The count flips like an odometer, with each digit rolling vertically over 250 ms.
- Tapping Review opens the bottom sheet containing the combined diff.

### 7.5 Confirmation dialogs
These are only for **irreversible or Experimental** actions. They are a centred card (radius 28) with the title, a plain-English consequence, a checklist the user must tick ("I have a backup from today"), and the destructive button, which stays disabled until every box is ticked.

### 7.6 Dynamic Island & Live Activity
- **Compact:** a leading 22 pt gradient disc with the module glyph, and a trailing 22 pt mini progress ring.
- **Expanded** (when the island is long-pressed, or briefly when an operation starts):
  - 361×84, radius 32;
  - 48 pt glyph tile;
  - title, plus a subtitle with bytes and a truthful phase;
  - a 42 pt ring.
- **Morph timeline on start:**

  | Time (s) | What happens |
  |---|---|
  | 0 → 0.9 | Island grows to expanded (bouncy) |
  | 0.35 | Content fades in |
  | 3.0 | Content fades out |
  | 3.0 → 3.8 | Island shrinks to compact (206×37) |
  | 3.8 | Compact glyph and ring fade in |

- **Lock Screen Live Activity:** frosted dark glass (`rgba(20,12,40,.55)` + blur), radius 28, a 44 pt glyph, title 16/700, phase subtitle, 26 pt percentage, an 8 pt bar, and a footer "Started 02:12 · Resumes if paused".
- **Honesty rule:** if the app gets suspended, the activity switches to "Paused by iOS · open to resume", with the bar striped and frozen. It never keeps counting.

### 7.7 Theme switch overlay
- Picking a theme captures the current screen, then reveals the new theme through a **circle that grows from the tapped point** (from 0 to the screen diagonal, 900 ms, `cubic-bezier(.65,0,.35,1)`).
- The selected theme card scales to 1.03, gains a 2.5 pt `ink` ring, and its check disc pops in (bouncy). Haptic `.soft`.
- Reduce Motion: a 250 ms cross-fade instead.

### 7.8 Empty, loading, error & limit states
| State | Pattern |
|---|---|
| **Loading** | Skeleton cards in `soft` with a shimmer (1.4 s period), kept to the real layout's shapes. A skeleton is never shown for under 300 ms (avoids a flash). |
| **Empty** | Two-tone headline ("Nothing here yet," / "start with a preset?"), a 120 pt floating glyph tile, and one primary pill. |
| **Error** | Peach icon disc, what happened, what was *not* changed, then Retry, Details and Copy diagnostic. |
| **Offline / device disconnected** | The device chip turns grey with a "Not connected" label. Cards needing the device dim and show "Connect to continue". Nothing is hidden. |
| **Permission denied** | An inline card explaining why, with an "Open Settings" pill. No repeated system prompts. |
| **Unsupported iOS** | The row is locked at 55% opacity. A popover lists supported builds and a "Notify me" toggle. |
| **Partial success** | Butter "Partial" tag. The receipt lists each item ✓ or ✗, with "1 key not undone" and a "Fix remaining" action. |
| **Unknown** | Dashed tag: "iOS doesn't expose this. Run a live test?" |

---

## 8. Screens

### 8.0 Scenes: the core experience
![Scenes](docs/screens/02-scenes-light.png) ![Apply](docs/screens/03-scene-apply-dark.png)

- **Recipe chips** across the top: Work, Minimal, One-page, Colour-flow, Sleep, Travel, Research.
- **Scene card** in two columns:
  - **Left:** a live 168×300 Home Screen preview showing the wallpaper, a widget in glass, the app grid tinted from the wallpaper palette, and the dock. The wallpaper's focal point appears as a dashed ring that pops in at 1.6 s.
  - **Right:** an Active tag, the name ("Work · Dusk"), a list of what the scene holds (wallpaper, layout, widgets, Shortcuts, Focus), and Edit layout.
- **Consistency card:** shows an Inferred finding such as "Widget covers the wallpaper's focal point". It offers the fix and makes clear that keeping things as they are is fine ("Your call").
- **Apply sheet** (the staged sheet pattern). Two tags summarise the split: **Automatic** (mint) and **Guided · you do it** (dashed). The steps are:
  1. Current layout recorded ✓ (done before asking).
  2. Set wallpaper (Auto).
  3. Install Shortcuts (Auto).
  4. Move apps (Guided).
  5. Place widgets (Guided).
  6. Link Focus (In Settings).

  The footnote reads "iOS doesn't let apps rearrange your Home Screen…". The primary button is **Start guided apply**.
- **Guided mode (next pass):** a translucent overlay card stays pinned while the user is on the Home Screen, showing a numbered target ghost for each app or widget. When the user returns, Assay asks them to confirm each step. Assay never claims a guided step is done unless the user confirms it or iOS exposes the fact.
- **Wallpaper changed inside Assay** → a toast: "Apply its paired layout?" It never rearranges anything silently.
- **Motion:** changing recipes cross-fades the preview with a 400 ms palette morph (the tile colours interpolate in OKLab). The focal ring pulses once. Apply-sheet steps tick in order with the step-list motion (§6.8).

### 8.1 Home
![Home](docs/screens/01-home-light.png)

- A brand row at the top (Fold symbol 24 pt and the wordmark at 19/750) with the bell on the right. Below it the two-tone greeting, which rises with the first stagger step.

- Two-tone greeting, then a device chip with a live mint dot, then a bell with a peach unread dot.
- Search pill, then a two-up row: the **Device health** hero card (score plus ring) beside the **Full backup** accent card (percentage, bar and shimmer).
- **Studio** carousel of floating tiles, then the **Needs you** queue with inline actions, then the floating tab bar.
- **Launch choreography:**

  | Time (ms) | What appears |
  |---|---|
  | 150 | Greeting |
  | 240 | Search |
  | 330 | Health card |
  | 420 | Backup card |
  | 510 | Studio header |
  | 600–780 | Tiles |
  | 870 | Needs-you |
  | 690 | Tab bar (rises with the content) |

  Each element rises 26 pt and scales from 0.98. The rings fill at 600 ms, and the island morph starts at 1.6 s if an operation is live.

### 8.2 Device check → Fix flow
![Device check](docs/screens/04-device-check-light.png)

- Three summary cards: Passed (mint bar), Need a look (accent), Unknown (grey).
- Evidence filter chips, then the finding cards. Tapping a finding **expands it in place** (height spring, with other cards sliding down) to show its evidence.
- **Preview fix** pushes to the finding detail, and the **Review fix** sheet springs up:
  - the Reversible tag;
  - the diff;
  - a 3-step plan, with the first two steps already ticked (preflight and snapshot happen *before* the user is asked);
  - Dry run and Apply fix buttons.
- **Apply** → the sheet stage changes to *Applying*:
  - snapshot receipt ✓;
  - "Writing preference" with a spinner;
  - "Reading back value";
  - "You confirm the clock".
- **Result:** a mint check disc, "Value removed · read back OK · receipt #213", then the question "Is your clock showing the right time now?" with *Roll back* and *Yes, it's fixed*. At the same time a toast drops in: "Fix applied · Undo any time from History".
- **Dry run** runs the same stages with a "Simulated" tag and a dashed-outline progress bar, and writes nothing.

![Review](docs/screens/05-fix-review-dark.png)

### 8.3 Gild: tweak catalogue
![Gild](docs/screens/08-gild-wall.png)

- Title plus "142 tweaks · checked for iOS 26.1", then search, then category chips.
- A **Preset** hero card (Quiet Home) with an "All reversible" tag and Preview, then the tweak list with tier tags and toggles. Unavailable tweaks show locked.
- The review bar appears once anything is staged.
- **Tweak detail (push):** a large live preview (a mock of the Home or Lock Screen with the change applied, plus a before/after scrubber) and a tier explanation. The data card lists the plist domain and key (Expert mode only), versions verified, the verification method, conflicts and recovery notes. Then "Add to changes".
- **Safety sheet for Experimental:** the confirmation dialog pattern (§7.5).

### 8.4 Signet: signing
![Signet](docs/screens/09-signing-light.png)

- Masked team chip, then an accent card with "4 days left" plus a ring and the buttons Renew with Apple / What changes?
- **Targets tree:** the app at the root, with indented appex rows showing bundle ID (mono) and a status tag (Valid 312 d / Expires 4 d / Missing entitlement).
- Footnote: "Assay can't grant entitlements. It shows what Apple needs and prepares the request."
- The **Sign & verify** flow uses the same staged sheet: map → sign each component → verify the signature, profile and entitlements → receipt.

### 8.5 Tools: BLE & LAN
![Tools](docs/screens/10-lab-ble-dark.png)

- A "Scanning · 0:42" chip with a pulsing sky dot. Mode chips: Bluetooth, Local network, Shortcuts.
- **Radar card:** dashed range rings, and three expanding pulse rings (3 s period, staggered 1 s). Each discovered device pops in as a coloured blip (bouncy) at a position derived from RSSI.
- **List:** name, battery/services, a 4-bar RSSI meter and the mono dBm value (updates animate at a 1 Hz cadence).
- Footnote: "Reads only. Writes always ask first. Scans stop when you leave."
- **LAN** mode swaps the radar for a Bonjour service list grouped by type, with latency sparkline chips.

### 8.6 Vault & Live Activity
![Vault](docs/screens/11-vault-dark.png) ![Lock](docs/screens/12-lockscreen-light.png)

- Hero ring (62%) with bytes, the amount reused from the baseline, and the retry count. Then the step list with live throughput (mono).
- Honest footnote about iOS suspension and checkpoints.
- **History** of receipts with Roll back / Partial tags.

### 8.7 Alchemy: AI asset editing
![Alchemy](docs/screens/13-alchemy-ai-light.png)

- Provider chip (Minis / Hosted / Ollama, with a privacy dot), then the wallpaper preview with the Lock Screen clock overlaid.
- **Before/after scrubber:** on first load the handle sweeps in from the right to 48% (1.6 s ease-out, starting at 1 s). It is draggable, with a haptic tick at 0, 50 and 100%.
- Prompt bubble, then "What I changed" chips popping in one by one (150 ms apart), then Refine / Review & apply.
- The generated background slowly drifts its light (7 s, alternating) so the preview feels alive.

### 8.8 Appearance
![Appearance](docs/screens/14-appearance-dark.png)

- Auto/Light/Dark segmented control, then a 2×2 grid of theme cards (with live mini-previews), then the Match my wallpaper card. On that card the swatches pop in one after another (90 ms stagger, overlapping by −8 pt). Then Choose photo / Pick colour, then the honesty footnote.

### 8.9 Still to design (next pass)
Scene guided-apply overlay · Device passport & snapshot compare · Change timeline · Crash/log explainer · Signing matrix & entitlement diff (full) · Build receipts · Backup health score & dry-run restore · Transport diagnostics timeline · Recovery coach · BLE notebook detail · Network inventory · Test bench · MCP bridge settings · Canvas `.tendies` layer/timeline editor · Cards editor · AI provider settings · Recovery centre · Widgets gallery and Control Centre controls · Onboarding/pairing · Settings & audit log · iPad layout.

---

## 9. Motion system

### 9.1 Curves
| Name | SwiftUI | CSS (prototype) | Use |
|---|---|---|---|
| `spring` (default) | `.spring(response: 0.5, dampingFraction: 0.72)` | `cubic-bezier(.2,1.35,.35,1)` 700–900 ms | Entrances, layout changes, knobs |
| `snappy` | `.spring(response: 0.32, dampingFraction: 0.78)` | — | Toggles, chips, press release, checks |
| `bouncy` | `.spring(response: 0.55, dampingFraction: 0.62)` | — | Toasts, popovers, island, badges, blips |
| `ease.out` | `.timingCurve(0.22, 1, 0.36, 1, duration: 1.4)` | `cubic-bezier(.22,1,.36,1)` | Rings, bars, reveals |
| `sweep` | `.timingCurve(0.65, 0, 0.35, 1, duration: 0.9)` | `cubic-bezier(.65,0,.35,1)` | Theme circle reveal, page wipes |

### 9.2 Durations
- Micro (press, toggle): 120–250 ms.
- Small (chip, check): 250–350 ms.
- Medium (sheet, toast, popover): 450–700 ms.
- Large (theme reveal, island morph): 800–1000 ms.
- Ambient (float, shimmer, radar, drift): 1.6–7 s loops.

### 9.3 Choreography rules
1. **Stagger** lists and grids at 90 ms (60 ms for re-filters), starting at 150 ms. Cap the stagger at 10 items; the rest appear together.
2. **Lead with the subject.** Animate what changed first, and let its surroundings follow 50–100 ms later.
3. **One hero motion per moment.** Don't fire a toast while a sheet is mid-flight; queue it until the sheet settles.
4. **Physical continuity.** Sheets come from where the button is; popovers grow from their anchor; the theme reveal starts at the tap point.
5. **Progress never lies.** Rings and bars only animate to values the system has confirmed. Use indeterminate shimmer or stripes when the value is unknown.
6. **Ambient motion is subtle and optional:** float ±6 pt, shimmer at 55% white, radar pulses. All of it pauses when the view is off-screen, in Low Power Mode, or in Reduce Motion.

### 9.4 Signature animations
| Name | Spec |
|---|---|
| **Rise** | opacity 0 → 1, y +26 → 0, scale .98 → 1, `spring`, staggered |
| **Pop** | opacity 0 → 1, scale .6 → 1, `bouncy` |
| **Float** | y 0 → −6 → 0 over 6 s ease-in-out, infinite, phase offsets −2 s |
| **Shimmer** | white band at 100°, 30–70% stops, translateX −100% → 100% over 2.6 s, 1.2 s delay, infinite |
| **Ring fill** | stroke-dashoffset from full length to target, `ease.out` 1.4 s, 600 ms delay |
| **Bar grow** | scaleX 0 → 1 from leading, 1.4 s, 800 ms delay |
| **Island morph** | see §7.6 |
| **Circle reveal** | clip circle(0) → circle(150%) at the tap point, `sweep` |
| **Scrubber sweep** | the clip inset and handle move from 100% to 48% together, `ease.out` 1.6 s |
| **Radar pulse** | ring scale .15 → 1 and opacity .7 → 0 over 3 s ease-out, 3 rings staggered 1 s |
| **Odometer** | each digit rolls vertically 100% over 250 ms `snappy`, rightmost first |
| **Check draw** | stroke from 0 to full over 250–300 ms ease-out, plus a disc pop |
| **Shake** | translateX 0, −6, 6, −4, 4, 0 over 360 ms |

### 9.5 Haptics
- `.selection`: tabs, chips, toggles, segmented control, scrubber detents.
- `.light`: press on primary buttons.
- `.medium`: sheet settle.
- `.soft`: theme change.
- `.success`: verified result.
- `.warning`: partial result or Caution add.
- `.error`: failure.
- Never fire a haptic on ambient motion.

### 9.6 Sound
Off by default. Optional theme-matched sounds: soft UI ticks for Assay, a short chime for Millennium, a "lock click" for Pinstripe. All are original recordings, with no OS sounds reused.

### 9.7 Performance
Keep 120 Hz on ProMotion. Animate only transform, opacity and clip. Blur only on static layers. Ambient loops stay at ≤ 2 per screen. Measure with Instruments (Core Animation hitches < 5 ms/s).

### 9.8 Motion clips (in bundle)
`docs/motion/logo-launch.mp4` (Fold mark → Home, light and dark) · `docs/motion/home-alchemy.mp4` · `themes.mp4` (picker + circle reveal) · `fix-flow.mp4` (review → apply → verify → toast).

### 9.9 Reduce Motion & accessibility
- Reduce Motion turns every rise, pop, morph and reveal into a 200 ms opacity cross-fade, and switches off float, shimmer, radar and drift.
- Progress still updates, but without the spring.
- VoiceOver:
  - every tag is read inline ("Caution, version-sensitive");
  - the ring reads "Device health 94 percent";
  - the sheet stages are announced;
  - the toast is posted as an announcement.
- Hit targets are ≥ 44 pt. Content is fully navigable by Switch Control and keyboard.
- Increase Contrast: borders go to 1.5 pt `ink-2`, pastel tiles darken 8%, and `ink-3` is never used for text.

---

## 10. System surfaces
- **Widgets:**
  - Small: health ring + score.
  - Medium: health + backup + next expiry.
  - Large: "Needs you" list.
  - Lock Screen: circular score, circular cert days, rectangular "2 tweaks need review".

  All follow the theme (glass in Wallpaper match) and use App Intents for refresh/open only.
- **Control Centre:** "Run device check" (opens the app), "Backup status" (shows the state), and a "Scan nearby" toggle (opens Tools). There is no background-capable destructive control.
- **Shortcuts:** Run diagnostics · Get device health · Export report · Start approved backup · Open project. Anything consequential still stops at the in-app review sheet.

---

## 11. Repository copy
- **Repo name:** `assay` (working name; owner confirmation and availability check pending).
- **Description:** “Customise, sign and inspect your iPhone, in one workbench that shows its work.”
- **Independence:** this is a clean, independently implemented project, not a direct fork. Credit GoldenNugget Mobile and GoldensHQ as inspiration/ecosystem contributors. Do not use upstream code or branding without separate licence review.
- **Topics:** `ios` `iphone` `customization` `tendies` `wallpaper` `code-signing` `provisioning-profiles` `diagnostics` `bluetooth-le` `swiftui` `live-activities` `ollama`
- **Social preview:** `docs/brand/social-preview.png` (1280×640).
- **Release notes voice:** “**New** Fix flow with receipts. **Better** backups resume from checkpoints. **Honest** Live Activity now shows *Paused by iOS*.”

---

## 12. Platform truths the UI must respect
- Live Activities display status; they don't keep the app running. Design for resumable work.
- No location or audio keep-alive tricks.
- The app can't grant itself entitlements or silently renew identities. Renewal is guided and user-authorised.
- iOS doesn't expose the current wallpaper to apps.
- Network Extension needs an entitlement and an eligible paid account, plus user approval of the VPN configuration.
- BLE and LAN scanning are limited by CoreBluetooth and local-network permission, and are not equivalent to desktop tools.
- Wallet: visuals only, never credentials.
- Never imply Apple endorsement. Retro themes are original homages with no third-party logos.
