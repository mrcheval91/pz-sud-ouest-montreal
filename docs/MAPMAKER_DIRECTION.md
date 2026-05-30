# Mapmaker Direction

Date: 2026-05-30
Branch: phase-1-canal-garage-cell

This document records the decision to build a deterministic mapmaker layer
instead of continuing WorldEd GUI trial-and-error.

---

## Problem encountered

### TileZed palette workflow

The TileZed tile palette did not present usable tiles for block-level layout
painting at the planning stage. Manual tile painting was impractical.

### WorldEd Generate Lots

WorldEd's Generate Lots function was triggered but produced no lotpack output.
No export files were written to the expected output directory.

### TMX-to-cell assignment

Assigning the generated planning TMX to a WorldEd cell caused a crash.
No cell was produced. The GUI workflow was abandoned at this point.

---

## Current verified assets

The following have been built and verified independent of WorldEd/TileZed GUI:

| Asset | Location | Verified |
|---|---|---|
| Canal Garage Cell JSON source | `source/cellforge/canal-garage-cell.json` | Yes |
| PNG blockout (900x900) | `.local/cellforge/canal-garage-cell-blockout.png` | Yes |
| Markdown inventory report | `.local/cellforge/canal-garage-cell-report.md` | Yes |
| 9-tile colour strip (TileZed tileset) | `.local/cellforge/blockout-tiles.png` | Yes |
| TileZed-openable planning TMX | `.local/cellforge/canal-garage-cell-basic.tmx` | Yes — opens visibly in TileZed |
| Real-PZ-tile TMX (scratch experiment) | Outside repo, not committed | Yes — opened visibly in TileZed |

All outputs above are generated deterministically from the JSON source by
`source/cellforge/render-cell.ps1`. No WorldEd or TileZed installation is required
to generate them.

---

## New direction

Build a deterministic mapmaker layer (working name: CellForge / PZMapForge) that
owns the full pipeline from JSON cell definition to PZ-loadable output, without
depending on the WorldEd GUI export path.

### Target pipeline

```
canal-garage-cell.json
  -> render-cell.ps1
       -> PNG blockout         (planning reference)
       -> markdown report      (inventory)
       -> blockout TMX         (TileZed preview, colour tiles)
       -> real-tile TMX        (TileZed preview, PZ tile IDs)  <-- next step
       -> lotpack/lotheader    (PZ load target)                <-- future step
```

### What this is not

- Not an official Project Zomboid tool.
- Not a replacement for WorldEd in all workflows.
- Not a fork of WorldEd or TileZed.
- The generated TMX files open in TileZed for visual review only. They have not
  been load-tested in Project Zomboid.

---

## License and claim boundaries

These boundaries are non-negotiable and must be maintained throughout this project:

| Boundary | Status |
|---|---|
| Project Zomboid game source | Not used. Not copied. |
| PZ assets (tilesets, sprites, sounds) | Not redistributed. May be referenced locally for local generation only. |
| WorldEd / TileZed source | Not forked. Not incorporated. May be studied separately under GPL/license review before any reuse decision. |
| Playable PZ map claim | Not made. Requires local load test. |
| Steam Workshop claim | Not made. |
| Build 42 compatibility | Not claimed. Unverified. |
| Official tool claim | Not made. This is an independent mod project. |

Any future use of WorldEd/TileZed source code requires a separate documented
license review before that code enters this repository.

---

## Next technical steps

In priority order:

1. **Add real-tile TMX generator to CellForge.**
   Extend `render-cell.ps1` (or a new script) to produce a TMX using actual
   PZ tile IDs (e.g. `newtiledroad`, `grass`) rather than colour-block GIDs.
   Reference local installed PZ tile data only; do not commit PZ assets.

2. **Add local asset path config.**
   Add a `.local/cellforge/config.json` (gitignored) for the local PZ install
   path and tileset path. Do not hardcode. Do not commit paths.

3. **Add TMX validation.**
   Validate generated TMX structure before opening in TileZed: check GID count,
   layer dimensions, tileset reference, and base64/gzip integrity.

4. **Investigate WorldEd/TileZed source separately.**
   If the lotpack compilation step requires understanding WorldEd's export format,
   study the WorldEd source under its GPL license. Document any findings in a
   separate decision record before incorporating anything.

5. **Load test.**
   Only after steps 1-3 are stable: generate lotpack/lotheader/bin from a real-tile
   TMX and load-test in a local Project Zomboid install. Commit generated exports
   only after a passing load test.
