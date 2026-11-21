# Palette Lab

Choose a JPEG, PNG or HEIC from Files to make a five-colour scene palette. The picker and image analysis run locally; Palette Lab stores neither the image nor its URL. `StudioArtwork.readImage` limits imports to regular, non-symlink files up to 20 MiB, 20,000 pixels per side and 80 megapixels before downsampling.

The analyser draws an oriented thumbnail (long edge ≤128 pixels) into an sRGB bitmap of the same aspect ratio, so no letterbox padding is sampled. It ignores transparent pixels, unpremultiplies other pixels and counts them by alpha coverage. It ranks 4-bit-per-channel bins by frequency and keeps representative colours separated in RGB space. When there are too few colours, it labels added tints or shades **Derived tone**, not **Extracted**. Opaque borders already in the source are part of the image.

Select a swatch to compare black and white text. The higher WCAG luminance ratio is suggested; either option below 4.5:1 is flagged for normal text. This is a check on two solid colours, not a whole-photo readability, subject-overlap or system appearance check. Suggestions do not change text in the scene. Adjusting a colour locks that slot on reimport. Unlock it to let a later import replace it. Failed or cancelled imports leave the last palette intact.

## Scene editor integration

Present inside a `NavigationStack`. Only the explicit **Use palette in draft** action returns five distinct sRGB values, sorted by decreasing relative luminance for `WallpaperPalette`. Cancel does not invoke the callback. The editor remains responsible for saving or discarding its draft.

```swift
.sheet(isPresented: $showPaletteLab) {
    NavigationStack {
        ScenePaletteLabView { palette in draft.appearance.palette = palette }
    }
}
```

Include `draft.appearance.palette` among the palette picker’s options so the new custom value has a matching tag. Palette Lab does not activate or write a saved scene, modify the device wallpaper, or request Photos access.

## Verification

Run `sh tests/palette-lab/smoke.sh` from the repository root. No SDK, image files, packages or network connection are needed beyond a Swift toolchain with Foundation. On iOS, try a narrow transparent PNG, a HEIC photo, and a second import with one edited slot locked. Check both contrast ratios at an accessibility text size, then cancel; the editor draft should be unchanged. Repeat and use the palette; dismiss the editor without saving to discard it.
