#Requires -Version 5.1
<#
.SYNOPSIS
    Reads canal-garage-cell.json and renders a 300x300 PNG blockout to .local/cellforge/.
    No TileZed, WorldEd, or network access required.
    Does not write into media/maps. Does not produce lotpack/lotheader/bin files.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Paths
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot   = Split-Path -Parent (Split-Path -Parent $scriptDir)
$jsonPath   = Join-Path $scriptDir 'canal-garage-cell.json'
$outputDir  = Join-Path $repoRoot '.local\cellforge'
$pngPath    = Join-Path $outputDir 'canal-garage-cell-blockout.png'
$reportPath = Join-Path $outputDir 'canal-garage-cell-report.md'

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force $outputDir | Out-Null
}

# Load cell definition
$cell  = Get-Content $jsonPath -Raw | ConvertFrom-Json
$W     = [int]$cell.meta.cell_width
$H     = [int]$cell.meta.cell_height
$SCALE = 3   # pixels per tile — PNG becomes 900x900
$PW    = $W * $SCALE
$PH    = $H * $SCALE

Add-Type -AssemblyName System.Drawing

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

$bmp = [System.Drawing.Bitmap]::new($PW, $PH)
$g   = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$g.Clear($colors['grass'])

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

# Roads
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
        $rH     = [int]$road.y_end - $yStart
        if ($sw -gt 0) { Fill-Rect ([int]$road.x - $sw) $yStart $sw $rH 'sidewalk' }
        Fill-Rect ([int]$road.x) $yStart ([int]$road.width) $rH $surface
        if ($sw -gt 0) { Fill-Rect ([int]$road.x + [int]$road.width) $yStart $sw $rH 'sidewalk' }
    }
}

# Buildings
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

# Spawn marker (5x5 dot)
$sx = [int]$cell.spawn.x; $sy = [int]$cell.spawn.y
Fill-Rect ($sx - 2) ($sy - 2) 5 5 'spawn'

# Landmark marker (3x3 dot)
$lx = [int]$cell.landmark.x; $ly = [int]$cell.landmark.y
Fill-Rect ($lx - 1) ($ly - 1) 3 3 'landmark'

# Labels — cast lookup indices explicitly to avoid PS5.1 type ambiguity
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

# Report
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
PNG: .local/cellforge/canal-garage-cell-blockout.png

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

## Notes

- This blockout is a planning artifact only. It does not produce PZ map files.
- No lotpack/lotheader/bin files were generated.
- media/maps was not modified.
- Output written to .local/ which is gitignored.
"@

Set-Content -Path $reportPath -Value $report -Encoding UTF8
Write-Output "Report written: $reportPath"
Write-Output "Done."
