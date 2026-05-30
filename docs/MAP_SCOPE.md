# Map Scope

This document defines the phased roadmap for PZ Sud-Ouest Montreal.

---

## Phase 0 — Repository scaffold (current)

- Set up repo structure, docs, and placeholder files.
- No playable content yet.
- Verify tooling requirements (TileZed, WorldEd, BuildingEd).

## Phase 1 — One-cell playable prototype

- Build the Canal Garage Cell (300x300 cells).
- Single spawn point.
- Basic road layout: main road, side street, alley.
- Core buildings: row houses, garage/auto shop, corner store, industrial yard.
- Load-test locally before committing any generated files.
- No Workshop release at this stage.

## Phase 2 — Residential and industrial contrast

- Expand to adjacent cells.
- Develop distinct residential texture (Ville-Emard row houses, back alleys, yards).
- Develop industrial texture (Canal-edge warehouses, loading docks, chain-link).
- Loot tables tuned for neighborhood context.

## Phase 3 — In-game map, spawn, loot, and zones

- Full in-game map integration with minimap tiles.
- Multiple spawn points with narrative framing.
- Zone definitions: safe house candidates, loot zones, hazard zones.
- NPC/zombie density tuned to neighborhood type.

---

## Non-goals (explicitly out of scope)

- Full Montreal city reproduction.
- Exact road or block accuracy.
- A giant multi-sector map.
- Custom tile sets (stock tiles only until Phase 2 is stable).
- Steam Workshop release before Phase 1 is load-tested.
- Any Build 42 compatibility claim before local verification.
