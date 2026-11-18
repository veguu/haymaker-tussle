# Traces reference 3's dark strokes: thins them to centrelines, splits them into curves, fits each.
# Writes out/ref3_trace_<t>.png (numbered curves over the faded reference), a points file and a report.
param([string]$Refs, [float]$Thr = 0.3, [int]$MinLen = 40)
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'
$ref = [Img]::Load((Join-Path $Refs 'ref3.png')).Crop(0, 62, 640, 356).Resize(1280, 712)
$tag = [int]($Thr * 100)
$report = [Lab]::TraceCurves($ref, $Thr, $MinLen, (Join-Path $out "ref3_trace_$tag.png"), (Join-Path $out "ref3_trace_${tag}_points.txt"))
$report | Out-File -Encoding utf8 (Join-Path $out "ref3_trace_${tag}_report.txt")
$report
