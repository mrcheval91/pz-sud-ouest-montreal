# CellForge Blockout

CellForge is a small deterministic cell layout generator for PZ Sud-Ouest Montreal.
It replaces manual TileZed tile-painting during early planning phases.

---

## Why it exists

TileZed manual painting was paused due to an unusable tile palette workflow
(see docs/LOCAL_TOOLING_PROOF.md). CellForge lets layout planning continue
without requiring TileZed to be functional.

---

## What it does

1. Reads `source/cellforge/canal-garage-cell.json` — the canonical cell definition.
2. Renders a PNG blockout to `.local/cellforge/canal-garage-cell-blockout.png`.
3. Writes a markdown inventory report to `.local/cellforge/canal-garage-cell-report.md`.
4. Generates a 9-tile colour strip to `.local/cellforge/blockout-tiles.png` (TileZed tileset image).
5. Generates a TileZed-openable TMX to `.local/cellforge/canal-garage-cell-basic.tmx`.

All output goes to `.local/` which is gitignored. Nothing is written into `media/maps`.
No lotpack/lotheader/bin files are produced.

**The TMX is a planning artifact, not a Project Zomboid load-tested map export.**

---

## How to run

```powershell
cd E:\Omni\Zomboid\pz-sud-ouest-montreal
pwsh source\cellforge\render-cell.ps1
```

Or with Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File source\cellforge\render-cell.ps1
```

Output appears under `.local\cellforge\` (created on first run).

---

## What the JSON defines

`source/cellforge/canal-garage-cell.json` contains:

| Section | Contents |
|---|---|
| `meta` | Cell name, dimensions (300x300), status |
| `layers` | Named colour keys for each surface type |
| `roads` | Rue Principale, Ruelle des Garages, Service Alley |
| `buildings` | 4 row houses, depanneur, garage, industrial yard |
| `landmark` | Garage Bellemare sign position |
| `spawn` | Depanneur sidewalk spawn point |

Edit the JSON to adjust layout. Re-run the script to regenerate all outputs.

---

## Colour key (PNG blockout and TMX tiles)

| GID | Colour | Meaning |
|---|---|---|
| 1 | Dark green | Grass / open ground |
| 2 | Dark grey | Road / asphalt |
| 3 | Light tan | Sidewalk |
| 4 | Brown | Row house |
| 5 | Orange-brown | Depanneur / corner store |
| 6 | Blue-grey | Garage / auto shop |
| 7 | Tan/dirt | Industrial yard |
| 8 | Yellow | Landmark marker |
| 9 | Bright green | Spawn marker |

The PNG blockout additionally renders roof overlays, fence borders, and text labels
on top of the base colours. These are visual-only and do not correspond to GIDs.

---

## TMX output

`canal-garage-cell-basic.tmx` uses the same format as the scratch TMX that opened
visibly in TileZed (see docs/LOCAL_TOOLING_PROOF.md). It references
`blockout-tiles.png` as its tileset — both files must be in the same directory.

To open in TileZed: File → Open → `.local\cellforge\canal-garage-cell-basic.tmx`.

**This is not a Project Zomboid map export.** It contains no lotpack, lotheader,
or bin files and has not been load-tested in-game.

---

## Limitations

- Planning artifact only — not a Project Zomboid map.
- No zone data, loot definitions, or PZ-specific metadata are generated.
- The TMX opens in TileZed for visual layout review only.
- When TileZed manual painting resumes, this JSON is the ground truth for layout.

---

## Next step

Use the TMX as a visual reference when translating the layout into a WorldEd cell.
Verify B42-compatible TileZed/WorldEd before making any PZ compatibility claims.
