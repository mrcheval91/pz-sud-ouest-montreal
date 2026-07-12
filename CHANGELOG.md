# Changelog

All notable changes to PZ Sud-Ouest Montreal will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

### Added
- Initial repository scaffold
- docs/MAP_SCOPE.md: phased roadmap
- docs/MVP_CELL_PLAN.md: Canal Garage Cell plan
- docs/REFERENCES_AND_LICENSES.md: attribution and license notices
- docs/BUILD42_TOOLING_NOTES.md: tooling verification notes
- media/maps/pz-sud-ouest-montreal/: placeholder map files
- source/: WorldEd, buildings, reference stubs
- source/buildings/: 35 hand-authored BuildingEd .tbx files organized into
  17 category subfolders (apartment, church, police, station_gaz, etc.).
  Not yet compiled or load-tested — raw authoring-format TBX with implicit
  wall/room geometry, requires WorldEd/BuildingEd compilation (or a future
  PZMapForge writer, currently blocked per PZMapForge MAP-38ZH). Provenance
  and license not yet confirmed against docs/REFERENCES_AND_LICENSES.md.
