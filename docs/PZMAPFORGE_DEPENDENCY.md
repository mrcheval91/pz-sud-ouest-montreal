# PZMapForge Dependency

This map mod repo does not contain PZMapForge tool source.
PZMapForge is maintained as a separate canonical tool repository.

---

## Where to find PZMapForge

- GitHub: https://github.com/mrcheval91/PZMapForge
- Local clone: E:\Omni\Zomboid\PZMapForge

---

## Why they are separated

PZMapForge is an independent deterministic map-planning layer. Keeping it in
the map mod repo mixed tool source with map content and made both harder to
maintain. The canonical tool lives in its own repo; this repo consumes the
planning artifacts it generates.

See docs/MAPMAKER_DIRECTION.md for the full decision record.

---

## What this repo uses from PZMapForge

This repo does not import PZMapForge as a submodule or package dependency.
It consumes PZMapForge outputs locally:

- Outputs land under `.local/mapforge/` (gitignored in both repos)
- No generated artifacts are committed here
- No PZ game assets are copied into either repo

---

## How to run PZMapForge against this repo

From this repo's root:

```powershell
powershell -ExecutionPolicy Bypass `
    -File "E:\Omni\Zomboid\PZMapForge\source\image-mapforge.ps1" `
    -ImagePath ".local\cellforge\canal-garage-cell-blockout.png" `
    -Resize `
    -OutputDir ".local\mapforge" `
    -AllowExternalOutput
```

The `-Resize` flag is needed because the CellForge blockout PNG is 900x900
(3px per tile). PZMapForge expects a 300x300 image matching the palette's
`cell_width` and `cell_height`.

The `-AllowExternalOutput` flag is needed because the output directory
`.local\mapforge` in this repo is outside PZMapForge's own `.local\mapforge`.
Outputs remain gitignored here via `.local/` in `.gitignore`.

---

## How to run the PZMapForge test harness

```powershell
powershell -ExecutionPolicy Bypass `
    -File "E:\Omni\Zomboid\PZMapForge\scripts\test-image-mapforge.ps1"
```

Expected result: 28 assertions pass, exit 0.

---

## Claim boundary

PZMapForge outputs are planning artifacts only.
No lotpack, lotheader, or bin files are generated.
No playable Project Zomboid map status is claimed.
media/maps in this repo is not touched by PZMapForge.
