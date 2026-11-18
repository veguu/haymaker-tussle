# Stroke widths, streak lengths and edge softness against distance from each reference's centre.
param([string]$Refs)
. "$PSScriptRoot\load.ps1"
$r1 = Join-Path $Refs 'ref1.png'; $r2 = Join-Path $Refs 'ref2.png'; $r3 = Join-Path $Refs 'ref3.png'

"=== REF1 rings round (761,594), dark < 0.5 ==="
[Lab]::Rings($r1, 761, 594, '25,50,80,120,170,230,300,400,520,700', 0.5)
"rays"
[Lab]::Rays($r1, 761, 594, 720, 20, 0.5)

"=== REF2 rings round (250,269), dark < 0.25 (true black) ==="
[Lab]::Rings($r2, 250, 269, '12,25,40,60,90,130,180,240', 0.25)
"dark < 0.5"
[Lab]::Rings($r2, 250, 269, '12,25,40,60,90,130,180,240', 0.5)
"light > 0.8 (white streaks): rings on inverted threshold via 0.8"
[Lab]::Rings($r2, 250, 269, '12,25,40,60,90,130,180', 0.8)
"rays"
[Lab]::Rays($r2, 250, 269, 720, 8, 0.25)

"=== REF3 rings round (140,183), dark < 0.3 ==="
[Lab]::Rings($r3, 140, 183, '80,140,200,260,330,420', 0.3)
"rays"
[Lab]::Rays($r3, 140, 183, 720, 30, 0.3)
