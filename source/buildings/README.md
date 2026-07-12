# BuildingEd Source

Place BuildingEd .tbx building files here once buildings are authored.

One file per building type. Name files descriptively:
  row_house_narrow.tbx
  garage_bellemare.tbx
  depanneur_corner.tbx
  industrial_yard_fenced.tbx

Do not commit generated outputs until load-tested locally.

---

## Status (2026-07-11)

35 hand-authored BuildingEd `.tbx` files organized into 17 category
subfolders (`apartment/`, `church/`, `police/`, `station_gaz/`, etc.),
sourced from a working set of Montreal-referenced buildings (Lasalle,
Verdun, Angrignon, canal St-Patrick, Honore-Mercier). Original filenames
preserved in spirit (normalized to lowercase/underscore) since several
still carry authoring notes (e.g. "v1 needs work") — check a file's content
before assuming it is finished.

**Not yet compiled or load-tested.** These are raw authoring-format TBX:
walls, doors, and room geometry are implicit (resolved by WorldEd/BuildingEd
at compile time from room-boundary + tileset choices), not explicit grids —
see PZMapForge's `docs/MAP_38ZG_BUILDING_LAYER_STRUCTURE_DISCOVERED.md` and
`docs/MAP_38ZH_FIELD1_ARRAY_BOUND_CONFIRMED.md` for why PZMapForge's own
writer cannot place these directly yet (the compiled binary record type it
knows how to write has no confirmed slot for wall/room data). Getting these
into a real cell currently means opening them in WorldEd/BuildingEd, the
official compiler for this format.

**Provenance:** working files, not a third-party asset pack (filenames
contain personal authoring notes in French, e.g. "Travail a faire un peu" —
"still needs work"). Confirm authorship/license before any public release
or Steam Workshop upload — not yet checked against
`docs/REFERENCES_AND_LICENSES.md`.
