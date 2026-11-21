# Assay field guide

**[Open the field guide →](Home.md)**

This directory is the readable private copy while the native Wiki is disabled. The guides describe the review branch at `eab9ea7`.

**Check against the repository:** [device engines](../../App/Engine/Engines.swift) · [clock comparison](../../App/Features/DisplayCheck/DisplayCheckView.swift) · [File Vault](../features/file-vault.md) · [scene activation](../features/scenes.md) · [scene transfer](../features/scene-transfer.md) · [signer preflight](../features/signer-preflight.md) · [build 7 audit](../audit/REQUESTS.md) · [CI definition](../../.github/workflows/ios.yml).

## Preparing a native wiki mirror

The repository copy uses ordinary relative links. Make the following changes **only in the mirror**, once the design page and its media are present:

1. Copy every page in this directory except `README.md` to the wiki root. Keep the filenames, including `Home.md`, `_Sidebar.md` and `Design-and-motion.md`.
2. For links between copied pages, drop only the destination’s `.md`: `(Scenes.md)` becomes `(Scenes)`. Keep any `#anchor`. Do this in the sidebar and on linked images too: the Home image should open `Design-and-motion`.
3. For every local media reference on every copied page, resolve the file relative to its **source page**. Copy it under `media/` at the wiki root, preserving its path from the repository root. For example, `../identity/repo/five-launches.jpg` becomes `media/docs/identity/repo/five-launches.jpg`. Rewrite both image sources and file links this way, including theme stills, film posters and all five MP4 links. Keep the films as ordinary links so playback does not depend on an inline player.
4. For repository documents or source files that were not copied, use their GitHub file permalinks at the reviewed revision instead of `../` paths. Leave external URLs and same-page anchors intact. Check Home and the sidebar, then follow the gallery’s stills and film links before treating the mirror as complete.
