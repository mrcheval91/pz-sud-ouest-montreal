# PZ Sud-Ouest Montreal

A fictional Project Zomboid map mod inspired by the southwest boroughs of Montreal.

---

## Current status

| Milestone | State |
|---|---|
| Public repo scaffold | Done |
| Canal Garage Cell JSON source (`source/cellforge/canal-garage-cell.json`) | Done |
| CellForge renderer — PNG blockout + report | Done |
| CellForge renderer — TileZed-openable TMX | Done |
| TMX opened visibly in TileZed | Verified |
| Project Zomboid load test (lotpack/lotheader/bin) | Not started |
| WorldEd map export | Not started |
| Steam Workshop release | Not planned yet |
| Build 42 compatibility | Unverified |

**Claim boundary:** TileZed-openable planning TMX generated from JSON, visually
verified in TileZed. Not a Project Zomboid load-tested map export. No playable
content yet.

---

## What this is

A custom map cell for Project Zomboid set in a fictionalized southwest Montreal.
The area draws on the character of Ville-Emard, Cote-Saint-Paul, the Lachine Canal
edge, small industrial corridors, residential streets, alleys, corner garages, and
depanneur-style streetscapes.

This is not a 1:1 replica of Montreal. Layout is adapted for gameplay. Real geography
is used for inspiration only.

---

## Canal Garage Cell

Working name for the first 300x300 prototype cell. Contents:

- Rue Principale (main road, east-west)
- Ruelle des Garages (side street, north)
- Service alley
- 4 row houses
- Depanneur Principale (corner store)
- Garage Bellemare (auto shop, fictional name)
- Fenced industrial yard
- One spawn point (depanneur sidewalk)
- One landmark (garage sign facing Rue Principale)

See [docs/MVP_CELL_PLAN.md](docs/MVP_CELL_PLAN.md) for the full plan.

---

## CellForge quickstart

CellForge reads `source/cellforge/canal-garage-cell.json` and generates local-only
planning artifacts. No TileZed installation required to run it.

```powershell
powershell -ExecutionPolicy Bypass -File "source\cellforge\render-cell.ps1"
```

Outputs appear under `.local\cellforge\` (created on first run, gitignored):

| File | Purpose |
|---|---|
| `canal-garage-cell-blockout.png` | Visual planning PNG (900x900, 3px/tile) |
| `canal-garage-cell-report.md` | Inventory report (roads, buildings, markers) |
| `blockout-tiles.png` | 9-tile colour strip used as TileZed tileset image |
| `canal-garage-cell-basic.tmx` | TileZed-openable cell file (planning only) |

To open the TMX in TileZed: File > Open > `.local\cellforge\canal-garage-cell-basic.tmx`.

See [docs/CELLFORGE_BLOCKOUT.md](docs/CELLFORGE_BLOCKOUT.md) for the GID table and
full documentation.

---

## Next steps

WorldEd GUI export was attempted and did not produce lotpack output. The project
is moving to a deterministic mapmaker layer built on top of CellForge instead.

See [docs/MAPMAKER_DIRECTION.md](docs/MAPMAKER_DIRECTION.md) for the full decision
record, license boundaries, and next technical steps.

---

## Neighborhoods in scope

- Ville-Emard
- Cote-Saint-Paul
- Canal / industrial edge

## What this is not

- A complete city of Montreal
- A 1:1 road-accurate reproduction
- A Steam Workshop release (not yet)
- Build 42 compatible (unverified — see [docs/BUILD42_TOOLING_NOTES.md](docs/BUILD42_TOOLING_NOTES.md))

## Project scope

See [docs/MAP_SCOPE.md](docs/MAP_SCOPE.md) for the phased roadmap.

## References and licenses

See [docs/REFERENCES_AND_LICENSES.md](docs/REFERENCES_AND_LICENSES.md).

## Contributing

Solo project in early development. No contributions accepted yet.
