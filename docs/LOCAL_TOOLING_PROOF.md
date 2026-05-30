# Local Tooling Proof

Date: 2026-05-30
Branch: phase-1-canal-garage-cell
Issue: #1
PR: #2

## Goal

Verify enough local Project Zomboid mapping tooling to begin the Canal Garage Cell prototype.

## Local environment

Project Zomboid install found at:

```text
D:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid
```

Project Zomboid bundled Java was available at:

```text
D:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\jre64\bin\java.exe
```

## Tooling installed outside repo

Mapping tools were extracted outside the repository:

```text
E:\Omni\Zomboid\tools
```

Important launchers found:

```text
E:\Omni\Zomboid\tools\TileD\TileZed.exe
E:\Omni\Zomboid\tools\WorldEd\PZWorldEd.exe
```

## Result

TileZed opened successfully after running the local config tool.

A scratch test map was created and saved outside the repository:

```text
E:\Omni\Zomboid\scratch\canal-garage-cell-test\canal-garage-test.tmx
```

Observed scratch output:

```text
canal-garage-test.tmx    487 bytes
```

## Repo safety check

No `.tmx` files were committed or created inside the repository.

Generated map files remain blocked until local load testing passes.

## WorldEd launch verification

WorldEd previously showed a `Tilesets.txt` error before the config pass.

After running the local config tool, WorldEd opened cleanly without the `Tilesets.txt` popup.

This is only a launch proof. WorldEd export and Project Zomboid load testing are still pending before generated map exports are committed.
