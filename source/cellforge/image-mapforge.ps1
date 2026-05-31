#Requires -Version 5.1
<#
.SYNOPSIS
    ImageMapForge: reads a PNG or BMP blockout image and writes local-only
    deterministic map-planning artifacts under .local/mapforge/.

.DESCRIPTION
    Converts image pixels into semantic cell kinds, writes a compact parsed-cell
    JSON artifact, a markdown report (including nearest-colour drift detail), a
    visual preview PNG, a generated colour-strip tileset, and a TileZed-openable
    planning TMX.

    Does not write into media/maps. Does not copy or redistribute Project Zomboid
    assets. Does not produce lotpack/lotheader/bin files. The TMX is a planning
    artifact only and is not a Project Zomboid load-tested export.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [ValidateSet('Palette', 'Debug')]
    [string]$Mode = 'Palette',

    [switch]$Resize,

    [string]$OutputDir,

    [switch]$AllowExternalOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName 'System.IO.Compression'

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot    = Split-Path -Parent (Split-Path -Parent $scriptDir)
$palettePath = Join-Path $scriptDir 'image-palette.json'

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot '.local\mapforge'
}

# ---------------------------------------------------------------------------
# Guards and helpers
# ---------------------------------------------------------------------------

function Fail {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

function Get-FullPathSafe {
    param([string]$PathValue)
    return [System.IO.Path]::GetFullPath($PathValue)
}

function Test-PathIsUnder {
    param([string]$ChildPath, [string]$ParentPath)
    $child  = Get-FullPathSafe $ChildPath
    $parent = Get-FullPathSafe $ParentPath
    $cmp    = [StringComparison]::OrdinalIgnoreCase
    if ($child.Equals($parent, $cmp)) { return $true }
    $sep = [System.IO.Path]::DirectorySeparatorChar
    $alt = [System.IO.Path]::AltDirectorySeparatorChar
    if (-not $parent.EndsWith([string]$sep) -and -not $parent.EndsWith([string]$alt)) {
        $parent = $parent + $sep
    }
    return $child.StartsWith($parent, $cmp)
}

function Get-FileSha256 {
    param([string]$PathValue)
    $sha    = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($PathValue)
    try {
        $hash = $sha.ComputeHash($stream)
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally { $stream.Dispose(); $sha.Dispose() }
}

function New-ColorFromRgbArray {
    param([object[]]$Rgb)
    if ($Rgb.Count -ne 3) { Fail "Palette rgb must have exactly 3 integers." }
    $r = [int]$Rgb[0]; $g = [int]$Rgb[1]; $b = [int]$Rgb[2]
    foreach ($v in @($r, $g, $b)) {
        if ($v -lt 0 -or $v -gt 255) { Fail "Palette rgb value out of range 0..255." }
    }
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

function Get-RgbKey {
    param([System.Drawing.Color]$Color)
    return "$($Color.R),$($Color.G),$($Color.B)"
}

function Get-NearestPaletteEntry {
    param([System.Drawing.Color]$Color, [object[]]$Entries)
    $best      = $null
    $bestScore = [double]::PositiveInfinity
    foreach ($entry in $Entries) {
        $dr    = [double]$Color.R - [double]$entry.r
        $dg    = [double]$Color.G - [double]$entry.g
        $db    = [double]$Color.B - [double]$entry.b
        $score = ($dr * $dr) + ($dg * $dg) + ($db * $db)
        if ($score -lt $bestScore) { $best = $entry; $bestScore = $score }
    }
    return $best
}

function Write-TileStrip {
    param([object[]]$Entries, [string]$PathValue, [int]$TileSize)
    $bmp = [System.Drawing.Bitmap]::new($Entries.Count * $TileSize, $TileSize)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    try {
        for ($i = 0; $i -lt $Entries.Count; $i++) {
            $brush = [System.Drawing.SolidBrush]::new($Entries[$i].color)
            $pen   = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 0, 0, 0), 1)
            try {
                $g.FillRectangle($brush, ($i * $TileSize), 0, $TileSize, $TileSize)
                $g.DrawRectangle($pen,   ($i * $TileSize), 0, ($TileSize - 1), ($TileSize - 1))
            }
            finally { $brush.Dispose(); $pen.Dispose() }
        }
        $bmp.Save($PathValue, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $g.Dispose(); $bmp.Dispose() }
}

function Write-PreviewPng {
    param([string[]]$Rows, [hashtable]$CodeToEntry, [string]$PathValue,
          [int]$Width, [int]$Height, [int]$Scale)
    $bmp = [System.Drawing.Bitmap]::new(($Width * $Scale), ($Height * $Scale))
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    try {
        for ($y = 0; $y -lt $Height; $y++) {
            $row = $Rows[$y]
            for ($x = 0; $x -lt $Width; $x++) {
                $entry = $CodeToEntry[[string]$row[$x]]
                $brush = [System.Drawing.SolidBrush]::new($entry.color)
                try { $g.FillRectangle($brush, ($x * $Scale), ($y * $Scale), $Scale, $Scale) }
                finally { $brush.Dispose() }
            }
        }
        $bmp.Save($PathValue, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $g.Dispose(); $bmp.Dispose() }
}

function Convert-GidGridToBase64Gzip {
    param([uint32[]]$Grid)
    $rawBytes = New-Object byte[] ($Grid.Length * 4)
    [System.Buffer]::BlockCopy($Grid, 0, $rawBytes, 0, $rawBytes.Length)
    $ms = [System.IO.MemoryStream]::new()
    $gz = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Compress)
    try { $gz.Write($rawBytes, 0, $rawBytes.Length) }
    finally { $gz.Close() }
    try { return [Convert]::ToBase64String($ms.ToArray()) }
    finally { $ms.Dispose() }
}

function Write-Tmx {
    param([string]$PathValue, [string]$TilesetImageName,
          [int]$Width, [int]$Height, [int]$TileSize, [int]$TilesetImageWidth, [uint32[]]$Grid)
    $b64 = Convert-GidGridToBase64Gzip $Grid
    $tmx = @"
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.0" orientation="orthogonal" width="$Width" height="$Height" tilewidth="$TileSize" tileheight="$TileSize">
 <tileset firstgid="1" name="imagemapforge_blockout" tilewidth="$TileSize" tileheight="$TileSize">
  <image source="$TilesetImageName" width="$TilesetImageWidth" height="$TileSize"/>
 </tileset>
 <layer name="Ground" width="$Width" height="$Height">
  <data encoding="base64" compression="gzip">
   $b64
  </data>
 </layer>
</map>
"@
    Set-Content -Path $PathValue -Value $tmx -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Output path guards
# ---------------------------------------------------------------------------

$outputFull      = Get-FullPathSafe $OutputDir
$allowedRoot     = Get-FullPathSafe (Join-Path $repoRoot '.local\mapforge')
$mediaMapsRoot   = Get-FullPathSafe (Join-Path $repoRoot 'media\maps')

if ((Test-PathIsUnder $outputFull $mediaMapsRoot) -or (Test-PathIsUnder $mediaMapsRoot $outputFull)) {
    Fail "Refusing to write into or over media/maps. Use a .local/mapforge output path."
}

if (-not $AllowExternalOutput -and -not (Test-PathIsUnder $outputFull $allowedRoot)) {
    Fail "Refusing to write outside .local/mapforge without -AllowExternalOutput. Requested: $outputFull"
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------

if (-not (Test-Path $ImagePath -PathType Leaf)) {
    Fail "ImagePath not found: $ImagePath"
}

if (-not (Test-Path $palettePath -PathType Leaf)) {
    Fail "Palette config not found: $palettePath"
}

$imageFull = (Resolve-Path $ImagePath).Path
$ext       = [System.IO.Path]::GetExtension($imageFull).ToLowerInvariant()
if ($ext -ne '.png' -and $ext -ne '.bmp') {
    Fail "Unsupported image extension '$ext'. Use PNG or BMP."
}

# ---------------------------------------------------------------------------
# Load and validate palette
# ---------------------------------------------------------------------------

$palette      = Get-Content -Path $palettePath -Raw | ConvertFrom-Json
$width        = [int]$palette.cell_width
$height       = [int]$palette.cell_height
$previewScale = [int]$palette.preview_scale
$tileSize     = [int]$palette.tile_size

if ($width -le 0 -or $height -le 0)  { Fail "Palette cell dimensions must be positive." }
if ($tileSize -le 0)                  { Fail "Palette tile_size must be positive." }
if ($previewScale -le 0)              { Fail "Palette preview_scale must be positive." }

$requiredKinds = @('grass','road','sidewalk','row_house','depanneur',
                   'garage','industrial_yard','landmark','spawn')

$entries       = @()
$kindSet       = @{}
$gidSet        = @{}
$codeSet       = @{}
$exactColorMap = @{}
$codeToEntry   = @{}

foreach ($raw in $palette.kinds) {
    $kind  = [string]$raw.kind
    $code  = [string]$raw.code
    $gid   = [int]$raw.gid
    $color = New-ColorFromRgbArray $raw.rgb

    if ([string]::IsNullOrWhiteSpace($kind))   { Fail "Palette entry has blank kind." }
    if ($code.Length -ne 1)                    { Fail "Palette code for '$kind' must be one character." }
    if ($gid -le 0)                            { Fail "Palette gid for '$kind' must be positive." }
    if ($kindSet.ContainsKey($kind))            { Fail "Duplicate palette kind: $kind" }
    if ($gidSet.ContainsKey([string]$gid))      { Fail "Duplicate palette gid: $gid" }
    if ($codeSet.ContainsKey($code))            { Fail "Duplicate palette code: $code" }

    $entry = [pscustomobject]@{
        kind        = $kind
        code        = $code
        gid         = $gid
        r           = [int]$color.R
        g           = [int]$color.G
        b           = [int]$color.B
        color       = $color
        description = [string]$raw.description
    }

    $rgbKey = Get-RgbKey $color
    if ($exactColorMap.ContainsKey($rgbKey)) { Fail "Duplicate palette rgb: $rgbKey" }

    $kindSet[$kind]      = $true
    $gidSet[[string]$gid] = $true
    $codeSet[$code]      = $true
    $exactColorMap[$rgbKey] = $entry
    $codeToEntry[$code]  = $entry
    $entries             += $entry
}

foreach ($req in $requiredKinds) {
    if (-not $kindSet.ContainsKey($req)) { Fail "Palette missing required kind: $req" }
}

$entries = @($entries | Sort-Object -Property gid)
for ($i = 0; $i -lt $entries.Count; $i++) {
    $want = $i + 1
    if ([int]$entries[$i].gid -ne $want) {
        Fail "Palette gids must be contiguous from 1. Expected $want, got $($entries[$i].gid)."
    }
}

# ---------------------------------------------------------------------------
# Load and optionally resize image
# ---------------------------------------------------------------------------

$sourceBmp = [System.Drawing.Bitmap]::new($imageFull)
$workBmp   = $null
try {
    if ($sourceBmp.Width -ne $width -or $sourceBmp.Height -ne $height) {
        if (-not $Resize) {
            Fail "Input image is $($sourceBmp.Width)x$($sourceBmp.Height). Expected ${width}x${height}. Re-run with -Resize to scale deterministically."
        }
        $workBmp       = [System.Drawing.Bitmap]::new($width, $height)
        $resizeGfx     = [System.Drawing.Graphics]::FromImage($workBmp)
        $resizeGfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $resizeGfx.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        try { $resizeGfx.DrawImage($sourceBmp, 0, 0, $width, $height) }
        finally { $resizeGfx.Dispose() }
    }
    else {
        $workBmp = [System.Drawing.Bitmap]::new($sourceBmp)
    }
}
finally { $sourceBmp.Dispose() }

# ---------------------------------------------------------------------------
# Pixel scan — colour frequencies (needed by both Debug and Palette modes)
# ---------------------------------------------------------------------------

$colorFrequencies         = @{}   # rgbKey -> count
$unmappedExactFrequencies = @{}   # rgbKey -> count (unmapped only)

try {
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $color = $workBmp.GetPixel($x, $y)
            $key   = Get-RgbKey $color
            if (-not $colorFrequencies.ContainsKey($key)) { $colorFrequencies[$key] = 0 }
            $colorFrequencies[$key]++
            if (-not $exactColorMap.ContainsKey($key)) {
                if (-not $unmappedExactFrequencies.ContainsKey($key)) {
                    $unmappedExactFrequencies[$key] = 0
                }
                $unmappedExactFrequencies[$key]++
            }
        }
    }

    # ---- Debug mode: print diagnostics and exit --------------------------

    if ($Mode -eq 'Debug') {
        Write-Output "ImageMapForge Debug"
        Write-Output "Image: $imageFull"
        Write-Output "Dimensions: $($workBmp.Width)x$($workBmp.Height)"
        Write-Output "Unique colours: $($colorFrequencies.Count)"
        Write-Output "Unmapped exact colours: $($unmappedExactFrequencies.Count)"
        Write-Output ""
        Write-Output "Top colour frequencies:"
        $colorFrequencies.GetEnumerator() |
            Sort-Object -Property @{ Expression = 'Value'; Descending = $true },
                                  @{ Expression = 'Key';   Descending = $false } |
            Select-Object -First 50 |
            ForEach-Object { Write-Output ("  {0} = {1}" -f $_.Key, $_.Value) }

        if ($unmappedExactFrequencies.Count -gt 0) {
            Write-Output ""
            Write-Output "Top unmapped exact colours (nearest-colour matching will be applied):"
            $unmappedExactFrequencies.GetEnumerator() |
                Sort-Object -Property @{ Expression = 'Value'; Descending = $true },
                                      @{ Expression = 'Key';   Descending = $false } |
                Select-Object -First 50 |
                ForEach-Object { Write-Output ("  {0} = {1}" -f $_.Key, $_.Value) }
        }
        exit 0
    }

    # ---- Palette mode: full artifact generation --------------------------

    New-Item -ItemType Directory -Force -Path $outputFull | Out-Null

    $jsonPath    = Join-Path $outputFull 'parsed-cell.json'
    $reportPath  = Join-Path $outputFull 'parsed-cell-report.md'
    $previewPath = Join-Path $outputFull 'parsed-cell-preview.png'
    $tilesPath   = Join-Path $outputFull 'parsed-cell-tiles.png'
    $tmxPath     = Join-Path $outputFull 'parsed-cell-basic.tmx'

    $rows      = New-Object System.Collections.Generic.List[string]
    $grid      = New-Object uint32[] ($width * $height)
    $kindCounts = @{}
    foreach ($entry in $entries) { $kindCounts[$entry.kind] = 0 }

    $exactMatchedPixels   = 0
    $nearestMatchedPixels = 0

    # nearestDrift: rgbKey -> {source_rgb, entry, nearest_kind, nearest_rgb, distance, count}
    # Caches nearest-colour lookups so each unique unmapped RGB is resolved only once.
    $nearestDrift = @{}

    for ($y = 0; $y -lt $height; $y++) {
        $chars = New-Object char[] $width
        for ($x = 0; $x -lt $width; $x++) {
            $color = $workBmp.GetPixel($x, $y)
            $key   = Get-RgbKey $color

            if ($exactColorMap.ContainsKey($key)) {
                $entry = $exactColorMap[$key]
                $exactMatchedPixels++
            }
            else {
                if ($nearestDrift.ContainsKey($key)) {
                    $entry = $nearestDrift[$key].entry
                    $nearestDrift[$key].count++
                }
                else {
                    $nearest = Get-NearestPaletteEntry $color $entries
                    $dr      = [double]$color.R - [double]$nearest.r
                    $dg      = [double]$color.G - [double]$nearest.g
                    $db      = [double]$color.B - [double]$nearest.b
                    $dist    = [Math]::Round([Math]::Sqrt($dr*$dr + $dg*$dg + $db*$db), 2)
                    $nearestDrift[$key] = @{
                        source_rgb   = $key
                        entry        = $nearest
                        nearest_kind = $nearest.kind
                        nearest_rgb  = "$($nearest.r),$($nearest.g),$($nearest.b)"
                        distance     = $dist
                        count        = 1
                    }
                    $entry = $nearest
                }
                $nearestMatchedPixels++
            }

            $chars[$x]                     = [char]$entry.code[0]
            $grid[($y * $width) + $x]      = [uint32]$entry.gid
            $kindCounts[$entry.kind]++
        }
        $rows.Add((-join $chars)) | Out-Null
    }

    Write-PreviewPng -Rows ($rows.ToArray()) -CodeToEntry $codeToEntry `
        -PathValue $previewPath -Width $width -Height $height -Scale $previewScale
    Write-TileStrip  -Entries $entries -PathValue $tilesPath -TileSize $tileSize
    Write-Tmx -PathValue $tmxPath -TilesetImageName 'parsed-cell-tiles.png' `
        -Width $width -Height $height -TileSize $tileSize `
        -TilesetImageWidth ($entries.Count * $tileSize) -Grid $grid

    # Build drift list sorted by count desc
    $driftList = $nearestDrift.Values |
        Sort-Object -Property @{ Expression = 'count'; Descending = $true },
                              @{ Expression = 'source_rgb'; Descending = $false }

    $driftRecords = @()
    foreach ($d in $driftList) {
        $driftRecords += [ordered]@{
            source_rgb   = $d.source_rgb
            count        = [int]$d.count
            nearest_kind = $d.nearest_kind
            nearest_rgb  = $d.nearest_rgb
            distance     = $d.distance
        }
    }

    # Build legend and counts for artifact
    $legend = @()
    foreach ($e in $entries) {
        $legend += [ordered]@{
            code        = $e.code
            kind        = $e.kind
            gid         = [int]$e.gid
            rgb         = @([int]$e.r, [int]$e.g, [int]$e.b)
            description = $e.description
        }
    }

    $counts = @()
    foreach ($e in $entries) {
        $counts += [ordered]@{
            kind   = $e.kind
            code   = $e.code
            gid    = [int]$e.gid
            pixels = [int]$kindCounts[$e.kind]
        }
    }

    $artifact = [ordered]@{
        schema         = 'pzmapforge.parsed-cell.v0.1'
        tool           = 'ImageMapForge'
        claim_boundary = 'planning_artifact_only_not_pz_load_tested'
        source_image   = $imageFull
        source_image_sha256 = Get-FileSha256 $imageFull
        palette        = $palettePath
        palette_sha256 = Get-FileSha256 $palettePath
        width          = $width
        height         = $height
        resized        = [bool]$Resize
        matching       = [ordered]@{
            exact_pixels           = [int]$exactMatchedPixels
            nearest_pixels         = [int]$nearestMatchedPixels
            unique_source_colours  = [int]$colorFrequencies.Count
            unmapped_exact_colours = [int]$unmappedExactFrequencies.Count
        }
        legend         = $legend
        counts         = $counts
        nearest_drift  = $driftRecords
        rows           = $rows.ToArray()
        outputs        = [ordered]@{
            json              = 'parsed-cell.json'
            report            = 'parsed-cell-report.md'
            preview           = 'parsed-cell-preview.png'
            generated_tileset = 'parsed-cell-tiles.png'
            tmx               = 'parsed-cell-basic.tmx'
        }
    }

    $artifact | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8

    # Build report sections
    $countLines = foreach ($e in $entries) {
        "| $($e.kind) | $($e.code) | $($e.gid) | $($kindCounts[$e.kind]) |"
    }
    $legendLines = foreach ($e in $entries) {
        "| $($e.kind) | $($e.code) | $($e.gid) | $($e.r),$($e.g),$($e.b) | $($e.description) |"
    }
    $driftTop = $driftList | Select-Object -First 20
    $driftLines = foreach ($d in $driftTop) {
        "| $($d.source_rgb) | $($d.count) | $($d.nearest_kind) | $($d.nearest_rgb) | $($d.distance) |"
    }

    $report = @"
# ImageMapForge Parsed Cell Report

Source image: ``$imageFull``
Source SHA-256: ``$((Get-FileSha256 $imageFull))``
Palette: ``$palettePath``
Palette SHA-256: ``$((Get-FileSha256 $palettePath))``
Dimensions: ${width}x${height}
Resized: $([bool]$Resize)

## Claim boundary

Planning artifact only. Not a Project Zomboid load-tested export. No lotpack, lotheader, or bin files generated. No Project Zomboid tilesheets copied. ``media/maps`` not touched.

## Matching summary

| Field | Value |
|---|---:|
| Unique source colours | $($colorFrequencies.Count) |
| Exact matched pixels | $exactMatchedPixels |
| Nearest matched pixels | $nearestMatchedPixels |
| Unmapped exact colours | $($unmappedExactFrequencies.Count) |

## Nearest-colour drift (top 20 by pixel count)

Unmapped source colours and what they were matched to. Zero rows = all pixels
matched exactly. High distance values flag potential palette mismatches.

| Source RGB | Count | Matched kind | Palette RGB | RGB distance |
|---|---:|---|---|---:|
$($driftLines -join "`n")

## Semantic kind counts

| Kind | Code | GID | Pixels |
|---|---|---:|---:|
$($countLines -join "`n")

## Palette legend

| Kind | Code | GID | RGB | Description |
|---|---|---:|---|---|
$($legendLines -join "`n")

## Outputs

All outputs are local-only. Keep under ``.local/mapforge/``.

| File | Purpose |
|---|---|
| ``parsed-cell.json`` | Compact semantic grid artifact |
| ``parsed-cell-report.md`` | This report |
| ``parsed-cell-preview.png`` | Visual preview from semantic rows |
| ``parsed-cell-tiles.png`` | Generated colour-strip tileset |
| ``parsed-cell-basic.tmx`` | TileZed-openable planning TMX |
"@

    Set-Content -Path $reportPath -Value $report -Encoding UTF8

    Write-Output "JSON written: $jsonPath"
    Write-Output "Report written: $reportPath"
    Write-Output "Preview written: $previewPath"
    Write-Output "Tile strip written: $tilesPath"
    Write-Output "TMX written: $tmxPath"
    Write-Output "Done. Planning artifacts only; no PZ export claim."
}
finally {
    if ($null -ne $workBmp) { $workBmp.Dispose() }
}
