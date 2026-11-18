# Practice copy of reference 3: black ink on white (a spun shockwave web of arcs and spokes, bold
# swoosh crescents, the fist mass combed into needles streaking away from the point behind it),
# softened per layer, then the measured black -> teal -> white ramp, letterboxed 4:3.
param([string]$Refs, [float]$Tear = 0.45, [float]$Spin = 5, [int]$WebSoft = 6, [float]$Depth = 380,
      [float]$DentW = 420, [float]$Tilt = 58, [float]$Turn = -25, [float]$RimR = 300, [int]$CrackBins = 260, [float]$NeedleLen = 0.7, [float]$Smear = 0, [float]$Gaps = 0.2, [int]$Creases = 18, [string]$Tag = 'v7')
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'; New-Item -ItemType Directory -Force $out | Out-Null
$W = 1280; $H = 720                      # content at 2x of the reference's 640x360
$vx = 520; $vy = 280                     # the point the tears streak away from (measured)
$wx = 720; $wy = 380                     # the dent's bottom: the fist (far end of the arm mass)

function New-Canvas {
    $b = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::White)
    return @($b, $g)
}
function Pen([float]$w) {
    $p = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), $w
    $p.StartCap = 'Round'; $p.EndCap = 'Round'; return $p
}
function Stroke($g, [float[]]$c, [float]$wMax) {
    $n = 70; $prev = $null
    for ($i = 0; $i -le $n; $i++) {
        $t = $i / $n; $u = 1 - $t
        $x = $u*$u*$u*$c[0] + 3*$u*$u*$t*$c[2] + 3*$u*$t*$t*$c[4] + $t*$t*$t*$c[6]
        $y = $u*$u*$u*$c[1] + 3*$u*$u*$t*$c[3] + 3*$u*$t*$t*$c[5] + $t*$t*$t*$c[7]
        if ($prev) { $g.DrawLine((Pen ([Math]::Max(0.6, $wMax * [Math]::Pow([Math]::Sin([Math]::PI * $t), 0.6)))), $prev[0], $prev[1], [float]$x, [float]$y) }
        $prev = @([float]$x, [float]$y)
    }
}
function Poly($g, $xy) {
    $pts = for ($i = 0; $i -lt $xy.Length; $i += 2) { New-Object System.Drawing.PointF $xy[$i], $xy[$i + 1] }
    $g.FillPolygon([System.Drawing.Brushes]::Black, [System.Drawing.PointF[]]$pts)
}
$rnd = New-Object System.Random 3

# 1. The web: arcs (with gaps) and spokes, then SPUN round its centre (arcs stay, spokes fan out
#    into soft panels) and softened.
$web = New-Canvas; $g = $web[1]
# The target's body taking the hit: a dented surface (z = -depth * exp(-(r/width)^2)) whose bottom
# is the fist, seen at an angle. Rings = the shock spreading out; creases run into the fist.
$ax = $Tilt * [Math]::PI / 180; $az = $Turn * [Math]::PI / 180
function Proj([double]$r, [double]$th) {
    $x = $r * [Math]::Cos($th); $y = $r * [Math]::Sin($th); $z = -$Depth * [Math]::Exp(-[Math]::Pow($r / $DentW, 2))
    $y2 = $y * [Math]::Cos($ax) - $z * [Math]::Sin($ax)                              # tip the surface away
    $x3 = $x * [Math]::Cos($az) - $y2 * [Math]::Sin($az); $y3 = $x * [Math]::Sin($az) + $y2 * [Math]::Cos($az)
    return @(($wx + $x3), ($wy + $y3))
}
# put the dent's projected bottom (r = 0) exactly on the fist
$fx = $wx; $fy = $wy; $b0 = Proj 0 0; $wx = $fx - ($b0[0] - $fx); $wy = $fy - ($b0[1] - $fy)
function Wire([scriptblock]$at, [int]$n, [float]$w) {
    $prev = $null; $skip = $false
    for ($i = 0; $i -le $n; $i++) {
        $p = & $at ($i / $n)
        if ($i % 14 -eq 0) { $skip = $rnd.NextDouble() -lt $Gaps }                      # random gaps
        if ($prev -and -not $skip) { $g.DrawLine((Pen $w), [float]$prev[0], [float]$prev[1], [float]$p[0], [float]$p[1]) }
        $prev = $p
    }
}
foreach ($r in 200, 380, 620, 950) { Wire { param($t) Proj $r (2 * [Math]::PI * $t) } 180 (11 + $rnd.NextDouble() * 9) }
for ($m = 0; $m -lt $Creases; $m++) {
    $th = $m * 2 * [Math]::PI / $Creases + $rnd.NextDouble() * 0.3; $r0 = 140 + $rnd.Next(0, 120)
    Wire { param($t) Proj ($r0 + (1100 - $r0) * $t) $th } 90 (7 + $rnd.NextDouble() * 8)
}
$webImg = [Img]::FromBitmap($web[0])
if ($Spin -gt 0) { $webImg = [Lab]::Spin($webImg, $wx, $wy, $Spin, 28) }
if ($Smear -gt 0) { $webImg = [Lab]::Directional($webImg, 20, $Smear, 32) }   # along the punch
$webImg = [Lab]::Soften($webImg, $WebSoft)
$webImg = [Lab]::Levels($webImg, 0.3, 1.0, 1.15)

# 2. Bold swoosh crescents: groups of parallel strokes sweeping in from the left to the fist.
$sw = New-Canvas; $g = $sw[1]
foreach ($o in 0, 26) { Stroke $g @(-60, (20 + $o), 280, (70 + $o), 480, (190 + $o), 660, (320 + $o * 0.4)) (28 - $o * 0.3) }
foreach ($o in 0, 24) { Stroke $g @(-60, (510 + $o), 240, (500 + $o), 430, (500 + $o), 600, (480 + $o * 0.4)) (26 - $o * 0.3) }
$swImg = [Lab]::Soften([Img]::FromBitmap($sw[0]), 3)

# 3. The fist mass and the lower-right mass, cracked inside, smeared AWAY from the point behind the
#    fist (averaging zoom toward that point), then cut hard: combed needles with white slivers.
$fm = New-Canvas; $g = $fm[1]
Poly $g @(440,200, 600,230, 740,300, 780,380, 720,470, 600,520, 480,470, 420,330)   # arm from behind -> fist
Poly $g @(860,640, 1280,600, 1280,720, 840,720)
$massImg = [Img]::FromBitmap($fm[0])
$cracks = [Lab]::PolarNoise($W, $H, $vx, $vy, $CrackBins, 0.3, 0.74, 0.26, 13)
# cracks only on the far rim (more than RimR from the point): the arm itself stays solid
$rim = [Lab]::RadialShape([Img]::Solid($W, $H, 1, 1, 1), $vx, $vy, $RimR, 5000, 1, -1, 0, 0)
$cracks = [Lab]::MaskMix([Img]::Solid($W, $H, 0, 0, 0), $cracks, $rim)
$massImg = [Lab]::MaskMix([Img]::Solid($W, $H, 1, 1, 1), $cracks, [Lab]::Levels($massImg, 0.5, 0.49, 1))
$body = [Lab]::Levels([Lab]::Zoom($massImg, $vx, $vy, $Tear, 48, $null), 0.44, 0.56, 1)

# Needles: specks along the far rims (darker specks -> longer needles) dragged away from the point.
$nd = New-Canvas; $g = $nd[1]
$rims = @(@(600,230, 740,300), @(740,300, 780,380), @(780,380, 720,470), @(720,470, 600,520), @(860,640, 1280,600))
foreach ($e in $rims) {
    for ($i = 0; $i -lt 55; $i++) {
        $t = $rnd.NextDouble(); $x = $e[0] + ($e[2] - $e[0]) * $t; $y = $e[1] + ($e[3] - $e[1]) * $t
        $v = [int](140 * $rnd.NextDouble()); $z = 2 + $rnd.NextDouble() * 6
        $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($v, $v, $v))), [float]($x - $z / 2), [float]($y - $z / 2), [float]$z, [float]$z)
    }
}
$needles = [Lab]::Trail([Img]::FromBitmap($nd[0]), $vx, $vy, -$NeedleLen, 72, 0.9)
$needles = [Lab]::Levels($needles, 0.44, 0.56, 1)
$tears = [Lab]::Soften([Lab]::Min($body, $needles), 2)

# 4. Ink together, then the measured ramp, then the letterbox.
$ink = [Lab]::Min([Lab]::Min($webImg, $swImg), $tears)
$col = [Lab]::GradientMap($ink, '0:1,3,2;0.08:13,29,24;0.5:100,153,136;0.75:159,219,209;0.85:180,231,227;0.92:208,241,240;1:255,255,255')
$bmp = New-Object System.Drawing.Bitmap $W, 960
$gg = [System.Drawing.Graphics]::FromImage($bmp); $gg.Clear([System.Drawing.Color]::Black)
$cb = $col.ToBitmap(); $gg.DrawImage($cb, 0, 120, $W, $H)
$bmp.Save((Join-Path $out "ref3_copy_$Tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)

[Lab]::Side((Join-Path $Refs 'ref3.png'), (Join-Path $out "ref3_copy_$Tag.png"), (Join-Path $out "ref3_side_$Tag.png"), 420, 'reference 3', "copy $Tag")
"--- copy stats (content)"
[Lab]::Stats((Join-Path $out "ref3_copy_$Tag.png"), 0, 120, 1280, 840)
