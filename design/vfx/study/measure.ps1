# Measures the three impact-frame references: tones, convergence point, stroke widths, edge softness.
param([string]$Refs)
. "$PSScriptRoot\load.ps1"
$r1 = Join-Path $Refs 'ref1.png'; $r2 = Join-Path $Refs 'ref2.png'; $r3 = Join-Path $Refs 'ref3.png'

"=== REF1 (base impact, Roblox scene) ==="
[Lab]::Stats($r1, 0, 0, 0, 0)
[Lab]::Extremes($r1)
[Lab]::Vanish($r1, 0, 0, 0, 0)

"=== REF2 (ink zoom burst) ==="
[Lab]::Stats($r2, 0, 0, 0, 0)
[Lab]::Extremes($r2)
[Lab]::Vanish($r2, 0, 0, 0, 0)

"=== REF3 (fist impact, letterboxed 640x480; content rows 60-420) ==="
[Lab]::Stats($r3, 0, 0, 640, 60)
[Lab]::Stats($r3, 0, 60, 640, 420)
[Lab]::Extremes($r3)
[Lab]::Vanish($r3, 0, 60, 640, 420)
"left half"
[Lab]::Vanish($r3, 0, 60, 320, 420)
"right half"
[Lab]::Vanish($r3, 320, 60, 640, 420)
