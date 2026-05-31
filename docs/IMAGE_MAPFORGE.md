# ImageMapForge MVP

Date: 2026-05-30
Branch: phase-1-canal-garage-cell
Working name: PZMapForge ImageMapForge MVP

ImageMapForge is a local deterministic map-planning layer built on top of the
current CellForge direction. It reads a simple PNG or BMP blockout image and
converts each pixel into a semantic cell kind.

It exists because manual WorldEd/TileZed GUI work consumed too much time and the
current verified milestone is only a TileZed-openable planning TMX generated
from JSON.

---

## What the tool does

`source/cellforge/image-mapforge.ps1` reads an input image and the palette file
at `source/cellforge/image-palette.json`, then writes local-only planning
artifacts under `.local/mapforge/`:

| File | Purpose |
|---|---|
| `parsed-cell.json` | Compact semantic grid artifact with legend, rows, counts, and hashes |
| `parsed-cell-report.md` | Human-readable inventory and claim-boundary report |
| `parsed-cell-preview.png` | Visual preview generated from the semantic grid |
| `parsed-cell-tiles.png` | Generated colour-strip tileset used by the TMX |
| `parsed-cell-basic.tmx` | TileZed-openable planning TMX |

The preferred input size is 300x300 pixels, matching one Project Zomboid cell
planning grid in this repository. If the input is not 300x300, the tool exits
nonzero unless `-Resize` is passed.

---

## Exact claim boundary

This tool produces planning artifacts only.

It does not:

- produce `lotpack`, `lotheader`, or `bin` files;
- write into `media/maps`;
- copy Project Zomboid tilesheets into this repository;
- redistribute Project Zomboid assets;
- make a playable map claim;
- make an official Project Zomboid tool claim.

The TMX is intended for TileZed visual review only. A real playable-export claim
requires a separate local Project Zomboid load test.

---

## Image palette format

The palette file is JSON:

```json
{
  "schema": "pzmapforge.image-palette.v0.1",
  "cell_width": 300,
  "cell_height": 300,
  "preview_scale": 3,
  "tile_size": 32,
  "kinds": [
    {
      "kind": "grass",
      "code": "g",
      "gid": 1,
      "rgb": [100, 140, 70],
      "description": "Grass or open ground"
    }
  ]
}
```

Each kind has:

| Field | Meaning |
|---|---|
| `kind` | Semantic planning kind |
| `code` | One-character code used in `parsed-cell.json` rows |
| `gid` | Tile GID used in the generated TMX |
| `rgb` | Source image colour used for exact matching |
| `description` | Human-readable meaning |

Required semantic kinds:

- `grass`
- `road`
- `sidewalk`
- `row_house`
- `depanneur`
- `garage`
- `industrial_yard`
- `landmark`
- `spawn`

Palette mode performs exact colour matching first. If a source pixel colour is
not present in the palette, it is mapped to the nearest palette colour by RGB
squared distance. Debug mode prints colour frequencies and exact-unmapped
colours without writing artifacts.

---

## How to run

First, keep the existing CellForge proof working:

```powershell
powershell -ExecutionPolicy Bypass -File "source\cellforge\render-cell.ps1"
```

Then run ImageMapForge against a 300x300 PNG or BMP:

```powershell
powershell -ExecutionPolicy Bypass -File "source\cellforge\image-mapforge.ps1" -ImagePath ".local\mapforge\test-input.png"
```

To inspect colours before generating artifacts:

```powershell
powershell -ExecutionPolicy Bypass -File "source\cellforge\image-mapforge.ps1" -ImagePath ".local\mapforge\test-input.png" -Mode Debug
```

To resize a non-300x300 image deterministically to 300x300:

```powershell
powershell -ExecutionPolicy Bypass -File "source\cellforge\image-mapforge.ps1" -ImagePath ".local\cellforge\canal-garage-cell-blockout.png" -Resize
```

---

## Output location and safety

By default, outputs go to:

```text
.local/mapforge/
```

The tool refuses to write outside `.local/mapforge` unless
`-AllowExternalOutput` is explicitly passed. It also refuses to write into or
over `media/maps`.

`.local/` is intentionally gitignored. Generated test images, previews, TMX
files, and parsed artifacts should remain local until a later load-tested export
process exists.

---

## Difference from WorldEd and TileZed

WorldEd and TileZed are external GUI tools in the Project Zomboid mapping
workflow. ImageMapForge is not a replacement for them and does not use their
source code.

ImageMapForge is a local deterministic planning step:

```text
image blockout
  -> palette match
  -> semantic grid
  -> preview PNG
  -> TileZed-openable planning TMX
```

It is useful because the source of truth is a small image plus a palette file,
not a fragile manual GUI session.

---

## Next steps toward a real PZ-compatible export

1. Add a TMX integrity validator for dimensions, GID count, base64, gzip, and
   tileset references.
2. Add a local-only semantic-kind-to-PZ-tile mapping that references installed
   Project Zomboid assets without copying them into the repo.
3. Investigate the WorldEd/TileZed lot export path separately and document any
   blocker honestly.
4. Generate `lotpack`, `lotheader`, and `bin` files only after the format is
   understood well enough to run a real local load test.
5. Claim playable status only after Project Zomboid loads the map locally.
