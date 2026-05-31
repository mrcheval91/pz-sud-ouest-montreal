#Requires -Version 5.1
<#
.SYNOPSIS
    Hardening test harness for image-mapforge.ps1.

    Creates synthetic test images in .local/mapforge-test/ (gitignored).
    Does not depend on pre-existing .local/ state.
    Exits 0 if all tests pass, exits 1 if any fail.
    Does not commit or touch media/maps.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent (Split-Path -Parent $scriptDir)
$imfScript = Join-Path $scriptDir 'image-mapforge.ps1'
$testDir   = Join-Path $repoRoot '.local\mapforge-test'
$outputDir = Join-Path $repoRoot '.local\mapforge'

$pass = 0
$fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { Write-Output "  PASS  $Label"; $script:pass++ }
    else            { Write-Output "  FAIL  $Label"; $script:fail++ }
}

# Invokes image-mapforge.ps1 as a child process.
# Sets local ErrorActionPreference to SilentlyContinue so that NativeCommandError
# objects produced by 2>&1 in PS5.1 do not propagate as terminating errors.
function Invoke-Imf {
    param([string[]]$ExtraArgs, [switch]$CaptureOutput)
    $ErrorActionPreference = 'SilentlyContinue'   # local to this function scope
    $allArgs = @('-ExecutionPolicy', 'Bypass', '-File', $imfScript) + $ExtraArgs
    if ($CaptureOutput) {
        $out = & powershell @allArgs 2>&1
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
    }
    else {
        & powershell @allArgs 2>&1 | Out-Null
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $null }
    }
}

# ---------------------------------------------------------------------------
# Create synthetic test images
# ---------------------------------------------------------------------------

if (-not (Test-Path $testDir)) { New-Item -ItemType Directory -Force $testDir | Out-Null }

# Exact grass colour from palette
$GRASS_R = 100; $GRASS_G = 140; $GRASS_B = 70
# Near-grass (not in palette — forces nearest-colour matching, one pixel)
$NEAR_R  = 101; $NEAR_G  = 141; $NEAR_B  = 71

$img300 = Join-Path $testDir 'test-300x300.png'
$bmp300 = [System.Drawing.Bitmap]::new(300, 300)
$g300   = [System.Drawing.Graphics]::FromImage($bmp300)
$g300.Clear([System.Drawing.Color]::FromArgb(255, $GRASS_R, $GRASS_G, $GRASS_B))
$g300.Dispose()
$bmp300.SetPixel(150, 150, [System.Drawing.Color]::FromArgb(255, $NEAR_R, $NEAR_G, $NEAR_B))
$bmp300.Save($img300, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp300.Dispose()

$img10 = Join-Path $testDir 'test-10x10.png'
$bmp10 = [System.Drawing.Bitmap]::new(10, 10)
$g10   = [System.Drawing.Graphics]::FromImage($bmp10)
$g10.Clear([System.Drawing.Color]::FromArgb(255, $GRASS_R, $GRASS_G, $GRASS_B))
$g10.Dispose()
$bmp10.Save($img10, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp10.Dispose()

# Ensure outputDir is clean so debug-mode no-write assertion is unambiguous
if (Test-Path $outputDir) { Remove-Item -Recurse -Force $outputDir }

Write-Output "Test images created. outputDir cleared."
Write-Output ""

# ---------------------------------------------------------------------------
# Test 1: Bad image path exits nonzero
# ---------------------------------------------------------------------------

Write-Output "Test 1: Bad image path"
$r = Invoke-Imf @('-ImagePath', (Join-Path $testDir 'does-not-exist.png'))
Assert-True ($r.ExitCode -ne 0) "Bad image path exits nonzero (exit $($r.ExitCode))"

# ---------------------------------------------------------------------------
# Test 2: Non-300x300 without -Resize exits nonzero
# ---------------------------------------------------------------------------

Write-Output "Test 2: Non-300x300 without -Resize"
$r = Invoke-Imf @('-ImagePath', $img10)
Assert-True ($r.ExitCode -ne 0) "10x10 image without -Resize exits nonzero (exit $($r.ExitCode))"

# ---------------------------------------------------------------------------
# Test 3: External OutputDir refused without -AllowExternalOutput
# ---------------------------------------------------------------------------

Write-Output "Test 3: External output refusal"
$r = Invoke-Imf @('-ImagePath', $img300, '-OutputDir', $env:TEMP)
Assert-True ($r.ExitCode -ne 0) "External OutputDir without -AllowExternalOutput exits nonzero (exit $($r.ExitCode))"

# ---------------------------------------------------------------------------
# Test 4: media/maps OutputDir refused; directory not touched
# ---------------------------------------------------------------------------

Write-Output "Test 4: media/maps output path refused"
$mediaPath    = Join-Path $repoRoot 'media\maps'
$mediaFiles1  = @(Get-ChildItem -Recurse $mediaPath | Select-Object -ExpandProperty FullName)

$r = Invoke-Imf @('-ImagePath', $img300, '-OutputDir', $mediaPath)
Assert-True ($r.ExitCode -ne 0) "media/maps OutputDir exits nonzero (exit $($r.ExitCode))"

$mediaFiles2  = @(Get-ChildItem -Recurse $mediaPath | Select-Object -ExpandProperty FullName)
Assert-True ($mediaFiles1.Count -eq $mediaFiles2.Count) `
    "media/maps file count unchanged after refused run ($($mediaFiles1.Count) files)"

# ---------------------------------------------------------------------------
# Test 5: Debug mode — exits 0, reports diagnostics, writes no artifact files
# ---------------------------------------------------------------------------

Write-Output "Test 5: Debug mode"
$r = Invoke-Imf @('-ImagePath', $img300, '-Mode', 'Debug') -CaptureOutput
Assert-True ($r.ExitCode -eq 0) "Debug mode exits 0 (exit $($r.ExitCode))"

$dbg = $r.Output -join "`n"
Assert-True ($dbg -match 'Unique colours')                    "Debug mode: Unique colours line present"
Assert-True ($dbg -match 'Unmapped exact colours')            "Debug mode: Unmapped exact colours line present"
Assert-True ($dbg -match "$GRASS_R,$GRASS_G,$GRASS_B")        "Debug mode: exact grass colour in frequency table"
Assert-True ($dbg -match "$NEAR_R,$NEAR_G,$NEAR_B")           "Debug mode: near-grass colour in unmapped section"
Assert-True (-not (Test-Path (Join-Path $outputDir 'parsed-cell.json'))) `
    "Debug mode writes no artifact files"

# ---------------------------------------------------------------------------
# Test 6: Normal run — exits 0, all 5 output files present
# ---------------------------------------------------------------------------

Write-Output "Test 6: Normal run"
$r = Invoke-Imf @('-ImagePath', $img300)
Assert-True ($r.ExitCode -eq 0)                                                "Normal run exits 0 (exit $($r.ExitCode))"
Assert-True (Test-Path (Join-Path $outputDir 'parsed-cell.json'))              "parsed-cell.json written"
Assert-True (Test-Path (Join-Path $outputDir 'parsed-cell-report.md'))         "parsed-cell-report.md written"
Assert-True (Test-Path (Join-Path $outputDir 'parsed-cell-preview.png'))       "parsed-cell-preview.png written"
Assert-True (Test-Path (Join-Path $outputDir 'parsed-cell-tiles.png'))         "parsed-cell-tiles.png written"
Assert-True (Test-Path (Join-Path $outputDir 'parsed-cell-basic.tmx'))         "parsed-cell-basic.tmx written"

# ---------------------------------------------------------------------------
# Test 7: Kind counts sum to width * height
# ---------------------------------------------------------------------------

Write-Output "Test 7: Kind counts completeness"
$json    = Get-Content (Join-Path $outputDir 'parsed-cell.json') -Raw | ConvertFrom-Json
$kindSum = 0
foreach ($c in $json.counts) { $kindSum += [int]$c.pixels }
$expected = [int]$json.width * [int]$json.height
Assert-True ($kindSum -eq $expected) "Kind counts sum to ${expected} (got $kindSum)"

# ---------------------------------------------------------------------------
# Test 8: Deterministic — two runs on the same image produce identical counts
# ---------------------------------------------------------------------------

Write-Output "Test 8: Deterministic kind counts"
$counts1 = $json.counts | ConvertTo-Json -Compress -Depth 3

Remove-Item -Recurse -Force $outputDir
$r = Invoke-Imf @('-ImagePath', $img300)
Assert-True ($r.ExitCode -eq 0) "Second run exits 0"
$json2   = Get-Content (Join-Path $outputDir 'parsed-cell.json') -Raw | ConvertFrom-Json
$counts2 = $json2.counts | ConvertTo-Json -Compress -Depth 3
Assert-True ($counts1 -eq $counts2) "Kind counts identical across two runs of the same image"

# ---------------------------------------------------------------------------
# Test 9: Nearest-colour drift report — presence, detail, and accuracy
# ---------------------------------------------------------------------------

Write-Output "Test 9: Nearest-colour drift report"
$drift = $json2.nearest_drift
Assert-True ($null -ne $drift -and $drift.Count -gt 0) `
    "nearest_drift field present and non-empty in JSON"

$nearKey   = "$NEAR_R,$NEAR_G,$NEAR_B"
$driftRow  = $drift | Where-Object { $_.source_rgb -eq $nearKey }
Assert-True ($null -ne $driftRow)               "Drift record for near-grass ($nearKey) present"
Assert-True ($driftRow.nearest_kind -eq 'grass') "Near-grass pixel mapped to 'grass' kind"
Assert-True ([double]$driftRow.distance -lt 5.0) "Drift distance is small (got $($driftRow.distance))"
Assert-True ([int]$driftRow.count -eq 1)          "Drift count is 1 (one near-grass pixel placed)"

$rpt = Get-Content (Join-Path $outputDir 'parsed-cell-report.md') -Raw
Assert-True ($rpt -match 'Nearest-colour drift') "Drift section present in markdown report"
Assert-True ($rpt -match $nearKey)               "Drift table contains near-grass RGB in report"

# ---------------------------------------------------------------------------
# Test 10: .local/ not visible in git status
# ---------------------------------------------------------------------------

Write-Output "Test 10: .local/ gitignore proof"
$ErrorActionPreference = 'SilentlyContinue'
$gitOut = git -C $repoRoot status --porcelain 2>&1
$ErrorActionPreference = 'Stop'
$leaked = @($gitOut | Where-Object { [string]$_ -match '\.local[\\/]' })
Assert-True ($leaked.Count -eq 0) ".local/ absent from git status (leaked: $($leaked.Count))"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Output ""
Write-Output "----------------------------------------"
Write-Output "Results: $pass passed, $fail failed"
Write-Output "----------------------------------------"

if ($fail -gt 0) { exit 1 }
exit 0
