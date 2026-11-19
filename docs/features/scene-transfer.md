# Personal scene transfer (X09)

Present `SceneTransferView()` as a destination inside the existing navigation stack. It needs no environment model, registration, entitlement or custom document type. Files uses the standard JSON type with the suggested name `Assay-scene-v1.json`.

**Export:** choose one local scene, optionally enable **Include manual note content**, then **Review export**. The review shows the exact JSON bytes as literal text. **Export JSON to Files** writes that snapshot, not a later read of the library. Share the saved file from Files. Consent resets after preparing a review or switching scenes. The scene name is always shared: check it as well as notes for personal details.

**Import:** choose a JSON file in Files, inspect the complete validated fields, then **Save as new scene** or cancel. Nothing is saved by previewing. Each save gets a new local UUID even if the name and contents already exist. No activation, merge, URL opening, script execution, asset fetching, or selection/undo changes. The reader accesses only the selected file, coordinates with its provider and reads at most 65,537 bytes to enforce the 64 KiB limit independently of file metadata.

### Version 1

```json
{"schema":"assay.scene.v1","name":"Evening","theme":"wallpaper","palette":["#FBE5C8","#F0B49E","#B78198","#725C83","#302B45"],"widgetNote":"Place the clock by hand."}
```

One UTF-8 JSON object, not an archive or library dump. Required: `schema` exactly as above; trimmed `name` (1–80 characters, ≤320 UTF-8 bytes); `theme` (`auto`, `light`, `dark`, `millennium`, `pinstripe`, `wallpaper`); `palette` (exactly five ordered ASCII `#RRGGBB` strings, either hex case, duplicates allowed). Optional `wallpaperNote`, `iconNote`, `widgetNote` are literal strings (≤2,000 characters and ≤8,000 UTF-8 bytes each); omitted means empty. Export omits empty notes. Control characters, bidi controls, line and paragraph separators are rejected; notes may contain LF and tab. Unknown versions, duplicate/unknown fields, explicit nulls and alternate types are errors, not silently discarded. URLs in text have no action semantics. No identity, account, keychain, device, active selection or undo fields exist in this format.

**Scope:** an unsigned personal interchange format, not proof of authorship, provenance, licence or integrity. No multi-asset bundles, signatures, manifests, wallpaper pixels, icon/widget payloads or asset remapping. Portability is limited to compatible Assay v1 readers and supported themes/palettes; it does not recreate an OS Home Screen or guarantee identical rendering on another device. Existing plain-text sharing is separate.

**Check:** `sh tests/scene-transfer/smoke.sh` from the repo root. On iOS, round-trip a custom five-colour scene with notes off, then on; inspect the file in Files, cancel a preview, then import twice. Verify both new scenes coexist with the original, current theme and undo are unchanged, and choosing another scene requires opting back into note sharing. Try invalid and oversized files and cancel each picker; none should add a scene.
