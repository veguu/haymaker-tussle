# Practice copy of reference 1: a scene -> outward zoom blur on the hit -> hard black/white threshold.
param([string]$Refs, [float]$Amount = 0.35, [float]$SolidAmount = 0.12, [float]$NeedleAmount = 0.6, [int]$Bins = 360, [float]$Density = 0.45, [float]$Spread = 0.45, [string]$Tag = 'v1')
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'; New-Item -ItemType Directory -Force $out | Out-Null
$W = 1521; $H = 861; $cx = 761; $cy = 594

function New-Canvas([System.Drawing.Color]$bg) {
    $b = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = 'AntiAlias'; $g.Clear($bg)
    return @($b, $g)
}
function Poly($g, $brush, [float[]]$xy) {
    $pts = for ($i = 0; $i -lt $xy.Length; $i += 2) { New-Object System.Drawing.PointF $xy[$i], $xy[$i + 1] }
    $g.FillPolygon($brush, [System.Drawing.PointF[]]$pts)
}
$white = [System.Drawing.Brushes]::White; $black = [System.Drawing.Brushes]::Black

# 1. Where the busy detail is (white = detail): everything except a clear band and a clear core.
$m = New-Canvas ([System.Drawing.Color]::White); $mg = $m[1]
Poly $mg $black @(0,120, 400,135, 640,185, 712,250, 745,470, 758,590, 820,650, 990,700, 1186,756, 1192,622, 1345,458, 1521,430, 1521,770, 1360,790, 1260,861, 600,861, 450,815, 0,765)
$mg.FillEllipse($black, $cx - 70, $cy - 70, 140, 140)
$detailMask = [Img]::FromBitmap($m[0])

# 2. The solid things in the scene: slabs, a figure, debris (black on white).
$s = New-Canvas ([System.Drawing.Color]::White); $sg = $s[1]
Poly $sg $black @(205,513, 300,522, 470,600, 562,682, 545,700, 430,692, 330,662, 245,565)          # left slab
Poly $sg $black @(880,560, 1010,492, 1345,458, 1192,622, 1186,756, 1156,760, 985,702, 990,668, 905,640) # right mass
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 9
$pen.LineJoin = 'Round'
function Outline($g, [float[]]$xy) {
    $pts = for ($i = 0; $i -lt $xy.Length; $i += 2) { New-Object System.Drawing.PointF $xy[$i], $xy[$i + 1] }
    $g.DrawPolygon($pen, [System.Drawing.PointF[]]$pts)
}
$pen.Width = 22
$sg.DrawArc($pen, 520, 262, 80, 90, 150, 200)                                                       # figure: head, a thick hook
$pen.Width = 9
Poly $sg $black @(612,300, 650,292, 700,420, 668,428)                                               # figure: torso, dark side
Outline $sg @(600,300, 690,282, 735,410, 655,430)                                                   # figure: torso outline
Poly $sg $black @(640,430, 700,425, 690,520, 655,515)                                               # figure: leg
Poly $sg $black @(470,350, 520,345, 525,375, 475,382)                                               # figure: arm
$solids = [Img]::FromBitmap($s[0])

# Fragments: small dark bits round the figure and the hit. They drag needles to the centre.
$f = New-Canvas ([System.Drawing.Color]::White); $fg = $f[1]
$rnd = New-Object System.Random 7
for ($i = 0; $i -lt 90; $i++) {
    $x = 420 + $rnd.NextDouble() * 360; $y = 220 + $rnd.NextDouble() * 360; $z = 2 + $rnd.NextDouble() * 7
    $fg.FillRectangle($black, [float]$x, [float]$y, [float]$z, [float]($z * (0.5 + $rnd.NextDouble())))
}
$frags = [Img]::FromBitmap($f[0])

# 3. Bright cracks inside the solids: fine radial noise, mostly dark, only where the solids are.
$cracks = [Lab]::PolarNoise($W, $H, $cx, $cy, 520, 0.35, 0.86, 0.14, 11)
$solidMask = [Lab]::Levels($solids, 0.5, 0.49, 1)        # inverted: white where solid
$solidScene = [Lab]::MaskMix([Img]::Solid($W, $H, 1, 1, 1), $cracks, $solidMask)

# 4. Busy detail (the speed-line source) where the mask allows; finer at the bottom strip.
$detail = [Lab]::PolarNoise($W, $H, $cx, $cy, $Bins, 0.22, $Density, $Spread, 3)
$fine = [Lab]::PolarNoise($W, $H, $cx, $cy, 2400, 0.22, $Density, $Spread, 5)
$lowMask = New-Canvas ([System.Drawing.Color]::Black); Poly $lowMask[1] $white @(0,700, 1521,700, 1521,861, 0,861)
$detail = [Lab]::MaskMix($detail, $fine, [Img]::FromBitmap($lowMask[0]))
$lineScene = [Lab]::MaskMix([Img]::Solid($W, $H, 1, 1, 1), $detail, $detailMask)
[Lab]::Min($solidScene, $lineScene).Save((Join-Path $out "ref1_source_$Tag.png"))

# 5. The process: zoom blur outward from the hit (long for the busy detail, short for the solid
#    objects), then a hard threshold (2 px edge) on each, and the two layers darkened together.
$lines = [Lab]::Levels([Lab]::ZoomOut($lineScene, $cx, $cy, $Amount, 48), 0.44, 0.56, 1)
$solidsOut = [Lab]::Levels([Lab]::ZoomOut($solidScene, $cx, $cy, $SolidAmount, 32), 0.44, 0.56, 1)
$needles = [Lab]::Levels([Lab]::Trail($frags, $cx, $cy, $NeedleAmount, 64, 0.9), 0.44, 0.56, 1)
$final = [Lab]::Min([Lab]::Min($lines, $solidsOut), $needles)
$final.Save((Join-Path $out "ref1_copy_$Tag.png"))

[Lab]::Side((Join-Path $Refs 'ref1.png'), (Join-Path $out "ref1_copy_$Tag.png"), (Join-Path $out "ref1_side_$Tag.png"), 430, 'reference 1', "copy $Tag")
"--- copy stats"
[Lab]::Stats((Join-Path $out "ref1_copy_$Tag.png"), 0, 0, 0, 0)
[Lab]::Rings((Join-Path $out "ref1_copy_$Tag.png"), $cx, $cy, '25,80,170,300,400,520', 0.5)
[Lab]::Rays((Join-Path $out "ref1_copy_$Tag.png"), $cx, $cy, 720, 20, 0.5)
