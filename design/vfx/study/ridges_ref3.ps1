# Finds the centreline of every dark stroke in reference 3 (soft or black) by curvature, splits them
# into numbered curves and measures each stroke's width and darkness along it.
# Writes out/ref3_ridges_<tag>.png (numbered over the faded reference) and ..._points.txt.
param([string]$Refs, [int]$Blur = 3, [float]$Thr = 0.004, [int]$MinLen = 30, [string]$Tag = 'r1')
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'
$ref = [Img]::Load((Join-Path $Refs 'ref3.png')).Crop(0, 62, 640, 356).Resize(1280, 712)
$report = [Lab]::TraceRidges($ref, $Blur, $Thr, $MinLen, (Join-Path $out "ref3_ridges_$Tag.png"), (Join-Path $out "ref3_ridges_${Tag}_points.txt"))
($report -split "`n")[0]
