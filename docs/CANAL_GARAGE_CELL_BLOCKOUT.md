# Canal Garage Cell Blockout

Issue: #1
Branch: phase-1-canal-garage-cell
Cell size: 300x300 tiles

## Purpose

This file defines the first playable cell before any WorldEd export is committed.

The goal is not exact Montreal accuracy. The goal is a fictionalized Sud-Ouest Montreal feeling:
residential streets, alley/service access, garage/auto shop, depanneur, fenced industrial edge,
and one recognizable local-flavored landmark.

## Coordinate convention

For this first plan:

- x = west to east, 0 to 299
- y = north to south, 0 to 299
- z = floor level, starting at 0

## Rough layout

| Zone | Approx area | Content |
|---|---:|---|
| Main road | y 130-150 | Main east-west road |
| Side street | x 120-140 | North-south street crossing the main road |
| Alley/service lane | y 185-195 | Narrow rear access behind row houses |
| Row houses | x 30-115, y 155-215 | Small residential strip |
| Depanneur/corner store | x 145-175, y 105-130 | Corner store near intersection |
| Garage/auto shop | x 180-235, y 150-210 | Main gameplay building |
| Industrial yard | x 210-285, y 35-115 | Fenced yard, storage, vehicle interest |
| Landmark | x 20-55, y 95-125 | Small mural wall or canal-side sign-inspired object |
| Spawn | x 150, y 135, z 0 | Sidewalk near depanneur |

## First playable proof

Done when all of these are true:

- the cell has walkable ground;
- the main road and side street are visible;
- at least one building placeholder exists;
- the player can spawn near the depanneur area;
- generated map files are committed only after local load test;
- README or docs state the exact playable status.

## Non-goals for this branch

- full Sud-Ouest map;
- exact real-world streets;
- custom tiles;
- Steam Workshop upload;
- final loot balance;
- final zombie zones;
- Build 42 compatibility claim before local verification.

## Next implementation step

Open TileZed/WorldEd tooling and create a 1x1 world project for this cell.
Do not commit generated lotpack, lotheader, or bin files until the cell has loaded locally.
