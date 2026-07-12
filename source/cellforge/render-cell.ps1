#Requires -Version 5.1
<#
.SYNOPSIS
    Reads canal-garage-cell.json and writes to .local/cellforge/:
      canal-garage-cell-blockout.png   - visual PNG blockout (planning reference)
      canal-garage-cell-report.md      - inventory report
      blockout-tiles.png               - 9-tile colour strip (TileZed tileset)
      canal-garage-cell-basic.tmx      - TileZed-openable cell file

    No TileZed, WorldEd, or network access required.
    Does not write into media/maps. Does not produce lotpack/lotheader/bin files.
    This is a planning artifact. The TMX is not a PZ load-tested map export.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName 'System.IO.Compression'

# Paths
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot   = Split-Path -Parent (Split-Path -Parent $scriptDir)
$jsonPath   = Join-Path $scriptDir 'canal-garage-cell.json'
$outputDir  = Join-Path $repoRoot '.local\cellforge'
$pngPath    = Join-Path $outputDir 'canal-garage-cell-blockout.png'
$reportPath = Join-Path $outputDir 'canal-garage-cell-report.md'
$tilesPath  = Join-Path $outputDir 'blockout-tiles.png'
$tmxPath    = Join-Path $outputDir 'canal-garage-cell-basic.tmx'

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force $outputDir | Out-Null
}

# Load cell definition
$cell  = Get-Content $jsonPath -Raw | ConvertFrom-Json
$W     = [int]$cell.meta.cell_width
$H     = [int]$cell.meta.cell_height
$SCALE = 3   # pixels per tile for blockout PNG — produces 900x900
$PW    = $W * $SCALE
$PH    = $H * $SCALE

# Shared colour palette
$colors = @{
    grass    = [System.Drawing.Color]::FromArgb(255, 100, 140,  70)
    asphalt  = [System.Drawing.Color]::FromArgb(255,  70,  70,  70)
    sidewalk = [System.Drawing.Color]::FromArgb(255, 190, 180, 160)
    building = [System.Drawing.Color]::FromArgb(255, 160, 110,  80)
    roof     = [System.Drawing.Color]::FromArgb(255, 120,  80,  60)
    dirt     = [System.Drawing.Color]::FromArgb(255, 160, 130,  90)
    fence    = [System.Drawing.Color]::FromArgb(255, 180, 180, 180)
    gravel   = [System.Drawing.Color]::FromArgb(255, 150, 145, 135)
    spawn    = [System.Drawing.Color]::FromArgb(255,   0, 220,  80)
    landmark = [System.Drawing.Color]::FromArgb(255, 255, 220,   0)
    label_bg = [System.Drawing.Color]::FromArgb(200,   0,   0,   0)
}

# --- Helper functions --------------------------------------------------------

function Fill-Rect {
    param([int]$x, [int]$y, [int]$w, [int]$h, [string]$colorKey)
    $brush = [System.Drawing.SolidBrush]::new($colors[$colorKey])
    $g.FillRectangle($brush, ($x * $SCALE), ($y * $SCALE), ($w * $SCALE), ($h * $SCALE))
    $brush.Dispose()
}

function Draw-Label {
    param([int]$x, [int]$y, [string]$text)
    $font    = [System.Drawing.Font]::new('Courier New', 7)
    $bgBrush = [System.Drawing.SolidBrush]::new($colors['label_bg'])
    $fgBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $size    = $g.MeasureString($text, $font)
    $px      = $x * $SCALE
    $py      = $y * $SCALE
    $g.FillRectangle($bgBrush, $px, $py, ([int]$size.Width + 2), ([int]$size.Height + 1))
    $g.DrawString($text, $font, $fgBrush, ($px + 1), $py)
    $font.Dispose(); $bgBrush.Dispose(); $fgBrush.Dispose()
}

# Fills a rectangle of cells in the GID grid ($script:grid).
# Clamps to grid bounds; silently ignores out-of-range regions.
function Grid-Fill {
    param([int]$x0, [int]$y0, [int]$w, [int]$h, [uint32]$gid)
    $cx0 = [Math]::Max($x0, 0)
    $cy0 = [Math]::Max($y0, 0)
    $cx1 = [Math]::Min($x0 + $w - 1, $script:W - 1)
    $cy1 = [Math]::Min($y0 + $h - 1, $script:H - 1)
    if ($cx0 -gt $cx1 -or $cy0 -gt $cy1) { return }
    for ($ty = $cy0; $ty -le $cy1; $ty++) {
        $rowBase = $ty * $script:W
        for ($tx = $cx0; $tx -le $cx1; $tx++) {
            $script:grid[$rowBase + $tx] = $gid
        }
    }
}

# --- Section 1: PNG blockout -------------------------------------------------

$bmp = [System.Drawing.Bitmap]::new($PW, $PH)
$g   = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$g.Clear($colors['grass'])

foreach ($road in $cell.roads) {
    $surface = 'asphalt'
    if ($road.PSObject.Properties['surface'] -and $road.surface -eq 'gravel') { $surface = 'gravel' }

    if ($road.orientation -eq 'horizontal') {
        $sw = [int]$road.sidewalk_width
        if ($sw -gt 0) { Fill-Rect 0 ([int]$road.y - $sw) $W $sw 'sidewalk' }
        Fill-Rect 0 ([int]$road.y) $W ([int]$road.width) $surface
        if ($sw -gt 0) { Fill-Rect 0 ([int]$road.y + [int]$road.width) $W $sw 'sidewalk' }
    } else {
        $sw     = [int]$road.sidewalk_width
        $yStart = [int]$road.y_start
        $rLen   = [int]$road.y_end - $yStart
        if ($sw -gt 0) { Fill-Rect ([int]$road.x - $sw) $yStart $sw $rLen 'sidewalk' }
        Fill-Rect ([int]$road.x) $yStart ([int]$road.width) $rLen $surface
        if ($sw -gt 0) { Fill-Rect ([int]$road.x + [int]$road.width) $yStart $sw $rLen 'sidewalk' }
    }
}

foreach ($b in $cell.buildings) {
    $fill = if ($b.type -eq 'industrial_yard') { 'dirt' } else { 'building' }
    $bx = [int]$b.x; $by = [int]$b.y; $bw = [int]$b.width; $bh = [int]$b.height
    Fill-Rect $bx $by $bw $bh $fill

    if ($b.PSObject.Properties['fenced'] -and $b.fenced) {
        $pen = [System.Drawing.Pen]::new($colors['fence'], 2)
        $g.DrawRectangle($pen, ($bx * $SCALE), ($by * $SCALE), ($bw * $SCALE), ($bh * $SCALE))
        $pen.Dispose()
    }

    if ($b.type -ne 'industrial_yard') {
        $rx = $bx + 1; $ry = $by + 1; $rw = $bw - 2; $rh = $bh - 2
        if ($rw -gt 0 -and $rh -gt 0) { Fill-Rect $rx $ry $rw $rh 'roof' }
    }
}

$sx = [int]$cell.spawn.x;    $sy = [int]$cell.spawn.y
$lx = [int]$cell.landmark.x; $ly = [int]$cell.landmark.y
Fill-Rect ($sx - 2) ($sy - 2) 5 5 'spawn'
Fill-Rect ($lx - 1) ($ly - 1) 3 3 'landmark'

$dep = $cell.buildings[4]; $gar = $cell.buildings[5]; $ind = $cell.buildings[6]
Draw-Label 2 142 'Rue Principale'
Draw-Label 92 10  'Ruelle des Garages'
Draw-Label 193 50 'Service Alley'
Draw-Label ([int]$dep.x) ([int]$dep.y - 10) 'Depanneur'
Draw-Label ([int]$gar.x) ([int]$gar.y - 10) 'Garage Bellemare'
Draw-Label ([int]$ind.x) ([int]$ind.y - 10) 'Industrial Yard'
Draw-Label ($sx - 2) ($sy - 14) 'SPAWN'
Draw-Label ($lx + 4) ($ly - 2)  'LANDMARK'

$g.Dispose()
$bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "PNG written: $pngPath"

# --- Section 2: Markdown report ----------------------------------------------

$buildingLines = foreach ($b in $cell.buildings) {
    "| $($b.label) | $($b.type) | $($b.x),$($b.y) | $($b.width)x$($b.height) |"
}
$roadLines = foreach ($r in $cell.roads) {
    $surf = if ($r.PSObject.Properties['surface']) { $r.surface } else { 'asphalt' }
    "| $($r.label) | $($r.orientation) | $($r.width) tiles | $surf |"
}

$report = @"
# Canal Garage Cell Blockout Report

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Source: source/cellforge/canal-garage-cell.json

**Status: $($cell.meta.status)**

## Cell dimensions

$($cell.meta.cell_width) x $($cell.meta.cell_height) tiles  (scale ${SCALE}px/tile -> PNG ${PW}x${PH}px)

## Roads

| Label | Orientation | Width | Surface |
|---|---|---|---|
$($roadLines -join "`n")

## Buildings

| Label | Type | Position (x,y) | Size (w x h) |
|---|---|---|---|
$($buildingLines -join "`n")

## Special markers

| Type | Label | Position |
|---|---|---|
| Spawn | $($cell.spawn.label) | $($cell.spawn.x),$($cell.spawn.y) |
| Landmark | $($cell.landmark.label) | $($cell.landmark.x),$($cell.landmark.y) |

## Outputs (all under .local/cellforge/ - gitignored)

| File | Purpose |
|---|---|
| canal-garage-cell-blockout.png | Visual planning PNG |
| canal-garage-cell-report.md | This report |
| blockout-tiles.png | 9-tile colour strip (TileZed tileset image) |
| canal-garage-cell-basic.tmx | TileZed-openable cell file (planning only, not PZ load-tested) |

## Notes

- Planning artifact only. Does not produce PZ map files.
- No lotpack/lotheader/bin files generated.
- media/maps not modified.
- TMX opens in TileZed for visual layout review. Not a Project Zomboid export.
"@

Set-Content -Path $reportPath -Value $report -Encoding UTF8
Write-Output "Report written: $reportPath"

# --- Section 3: Tile strip PNG (TileZed tileset) ----------------------------
#
# 9 solid-colour 32x32 tiles in a horizontal strip.
# GID 1-9 correspond to: grass, road, sidewalk, row_house, depanneur,
# garage, industrial_yard, landmark, spawn.

$TILE_SIZE = 32
$tileColors = @(
    [System.Drawing.Color]::FromArgb(255, 100, 140,  70)  # GID 1 grass
    [System.Drawing.Color]::FromArgb(255,  70,  70,  70)  # GID 2 road/asphalt
    [System.Drawing.Color]::FromArgb(255, 190, 180, 160)  # GID 3 sidewalk
    [System.Drawing.Color]::FromArgb(255, 160, 110,  80)  # GID 4 row house
    [System.Drawing.Color]::FromArgb(255, 200, 130,  60)  # GID 5 depanneur
    [System.Drawing.Color]::FromArgb(255,  80,  80, 100)  # GID 6 garage
    [System.Drawing.Color]::FromArgb(255, 160, 130,  90)  # GID 7 industrial yard
    [System.Drawing.Color]::FromArgb(255, 255, 220,   0)  # GID 8 landmark
    [System.Drawing.Color]::FromArgb(255,   0, 220,  80)  # GID 9 spawn
)
$TILE_COUNT  = $tileColors.Count  # 9
$stripWidth  = $TILE_COUNT * $TILE_SIZE

$stripBmp = [System.Drawing.Bitmap]::new($stripWidth, $TILE_SIZE)
$sg = [System.Drawing.Graphics]::FromImage($stripBmp)
$sg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None

for ($i = 0; $i -lt $TILE_COUNT; $i++) {
    $brush = [System.Drawing.SolidBrush]::new($tileColors[$i])
    $sg.FillRectangle($brush, ($i * $TILE_SIZE), 0, $TILE_SIZE, $TILE_SIZE)
    $brush.Dispose()
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 0, 0, 0), 1)
    $sg.DrawRectangle($pen, ($i * $TILE_SIZE), 0, ($TILE_SIZE - 1), ($TILE_SIZE - 1))
    $pen.Dispose()
}

$sg.Dispose()
$stripBmp.Save($tilesPath, [System.Drawing.Imaging.ImageFormat]::Png)
$stripBmp.Dispose()
Write-Output "Tile strip written: $tilesPath"

# --- Section 4: GID grid -----------------------------------------------------
#
# Build a flat uint32 array [row-major, y*W+x] of GID values.
# Paint order mirrors Section 1: background, sidewalks, roads, buildings, markers.
# GID 0 is used as an unset sentinel; converted to GID 1 (grass) before encoding.

$GID_GRASS    = [uint32]1
$GID_ROAD     = [uint32]2
$GID_SIDEWALK = [uint32]3
$GID_ROWHOUSE = [uint32]4
$GID_DEPA     = [uint32]5
$GID_GARAGE   = [uint32]6
$GID_INDYARD  = [uint32]7
$GID_LANDMARK = [uint32]8
$GID_SPAWN    = [uint32]9

$grid = New-Object uint32[] ($W * $H)   # initialised to 0

foreach ($road in $cell.roads) {
    if ($road.orientation -eq 'horizontal') {
        $sw = [int]$road.sidewalk_width
        if ($sw -gt 0) { Grid-Fill 0 ([int]$road.y - $sw) $W $sw $GID_SIDEWALK }
        Grid-Fill 0 ([int]$road.y) $W ([int]$road.width) $GID_ROAD
        if ($sw -gt 0) { Grid-Fill 0 ([int]$road.y + [int]$road.width) $W $sw $GID_SIDEWALK }
    } else {
        $sw     = [int]$road.sidewalk_width
        $yStart = [int]$road.y_start
        $rLen   = [int]$road.y_end - $yStart
        if ($sw -gt 0) { Grid-Fill ([int]$road.x - $sw) $yStart $sw $rLen $GID_SIDEWALK }
        Grid-Fill ([int]$road.x) $yStart ([int]$road.width) $rLen $GID_ROAD
        if ($sw -gt 0) { Grid-Fill ([int]$road.x + [int]$road.width) $yStart $sw $rLen $GID_SIDEWALK }
    }
}

$typeToGid = @{
    'row_house'       = $GID_ROWHOUSE
    'corner_store'    = $GID_DEPA
    'garage'          = $GID_GARAGE
    'industrial_yard' = $GID_INDYARD
}
foreach ($b in $cell.buildings) {
    $gidB = if ($typeToGid.ContainsKey($b.type)) { [uint32]$typeToGid[$b.type] } else { $GID_ROWHOUSE }
    Grid-Fill ([int]$b.x) ([int]$b.y) ([int]$b.width) ([int]$b.height) $gidB
}

Grid-Fill ($sx - 2) ($sy - 2) 5 5 $GID_SPAWN
Grid-Fill ($lx - 1) ($ly - 1) 3 3 $GID_LANDMARK

# Replace sentinel 0 with GID 1 (grass)
for ($i = 0; $i -lt $grid.Length; $i++) {
    if ($grid[$i] -eq 0) { $grid[$i] = $GID_GRASS }
}

# --- Section 5: Encode and write TMX ----------------------------------------

# uint32[] -> byte[] (native LE on x86/x64 Windows)
$rawBytes = New-Object byte[] ($grid.Length * 4)
[System.Buffer]::BlockCopy($grid, 0, $rawBytes, 0, $rawBytes.Length)

# gzip compress
$ms = [System.IO.MemoryStream]::new()
$gz = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Compress)
$gz.Write($rawBytes, 0, $rawBytes.Length)
$gz.Close()
$compressed = $ms.ToArray()
$ms.Dispose()

$b64 = [Convert]::ToBase64String($compressed)

$tmxContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.0" orientation="orthogonal" width="$W" height="$H" tilewidth="$TILE_SIZE" tileheight="$TILE_SIZE">
 <tileset firstgid="1" name="canal_garage_blockout" tilewidth="$TILE_SIZE" tileheight="$TILE_SIZE">
  <image source="blockout-tiles.png" width="$stripWidth" height="$TILE_SIZE"/>
 </tileset>
 <layer name="Ground" width="$W" height="$H">
  <data encoding="base64" compression="gzip">
   $b64
  </data>
 </layer>
</map>
"@

Set-Content -Path $tmxPath -Value $tmxContent -Encoding UTF8
Write-Output "TMX written: $tmxPath"
Write-Output "Done."
