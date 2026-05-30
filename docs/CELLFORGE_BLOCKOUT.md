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

Output goes to `.local/` which is gitignored. Nothing is written into `media/maps`.
No lotpack/lotheader/bin files are produced.

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

Edit the JSON to adjust layout. Re-run the script to regenerate the PNG.

---

## Colour key

| Colour | Meaning |
|---|---|
| Dark green | Grass / open ground |
| Dark grey | Asphalt road |
| Light tan | Sidewalk |
| Brown | Building footprint |
| Dark brown | Roof overlay |
| Tan/dirt | Industrial yard |
| Grey border | Chain-link fence |
| Gravel grey | Service alley |
| Bright green | Spawn marker |
| Yellow | Landmark marker |

---

## Limitations

- This is a 2D planning blockout, not a Project Zomboid map.
- No tile data, zone data, or loot definitions are generated.
- The PNG is a layout reference only. It does not load into PZ.
- When TileZed painting resumes, this JSON serves as the ground truth for layout.

---

## Next step

Once TileZed tile palette workflow is resolved (or B42 mapping tools are verified),
translate this JSON layout into a WorldEd cell using the blockout as a reference guide.
