# Reference 3 as a side-view gut punch: the target's body is a big ball (globe lines) seen nearly from
# the side. The fist (an R6 arm block) drives in from the right and the body GOES INWARDS: its outline
# gets a notch pushed in round the fist, the surface lines dive into the notch, the rings near it
# squeeze, the hollow is shaded. Then the arm is smeared away from the fist and the measured
# black -> teal -> white ramp goes on, letterboxed.
param([string]$Refs,
      [float]$Cx = 100, [float]$Cy = 305, [float]$R = 700,
      [float]$Tilt = 12, [float]$Aim = 9,
      [float]$Dent = 0.3, [float]$DentW = 0.3, [float]$Twist = 0.2,
      [string]$Azis = '200,165,135,105,-60,-90', [string]$Lats = '30,50,75', [int]$SqueezeRings = 3,
      [float]$MerW = 18, [float]$LatW = 14, [float]$PairGap = 0.06, [float]$EdgeW = 7, [int]$GridSoft = 9, [float]$GridZoom = 0,
      [float]$Shade = 0.75, [int]$ShadeSoft = 16,
      [float]$ArmHalf = 115, [float]$Smear = 0.45, [float]$CrackDark = 0.78, [float]$RimR = 300,
      [float]$NeedleLen = 1.2, [int]$Specks = 70, [string]$Shoulder = '900,640,1280,600,1280,720,880,720',
      [string]$Tag = 'c1')
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'
$W = 1280; $H = 720
$cb = [Math]::Cos($Tilt * [Math]::PI / 180); $sb = [Math]::Sin($Tilt * [Math]::PI / 180)
$cg = [Math]::Cos($Aim * [Math]::PI / 180); $sg = [Math]::Sin($Aim * [Math]::PI / 180)
function ToScreen([double]$x, [double]$y, [double]$z) {
    $x1 = $x * $cb - $z * $sb; $z1 = $x * $sb + $z * $cb
    $x2 = $x1 * $cg - $y * $sg; $y2 = $x1 * $sg + $y * $cg
    return @(($Cx + $x2), ($Cy + $y2), $z1)
}
# The body FOLDS round the fist: a crease across its whole depth (not a dimple, which its own near
# rim would hide from the side). Points on the fist's side are pushed back along the punch, most at
# the fist's height, fading with height (y) and toward the back of the ball.
function FoldK([double]$x, [double]$y) {
    if ($x -le 0) { return 0 }
    return [Math]::Exp(-[Math]::Pow($y / ($DentW * $R), 2)) * [Math]::Pow($x / $R, 2)
}
function DentK([double]$a) { FoldK ($R * [Math]::Cos($a)) 0 }
function Ball([double]$a, [double]$p) {
    $x = $R * [Math]::Cos($a); $y = $R * [Math]::Sin($a) * [Math]::Cos($p); $z = $R * [Math]::Sin($a) * [Math]::Sin($p)
    $k = FoldK $x $y
    return ToScreen ($x - $Dent * $R * $k) $y $z
}
function New-Canvas {
    $b = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::White)
    return @($b, $g)
}
function Pen([float]$w) { $p = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), $w; $p.StartCap = 'Round'; $p.EndCap = 'Round'; $p }
function Pt($p) { New-Object System.Drawing.PointF ([float]$p[0]), ([float]$p[1]) }
function Curve($g, [scriptblock]$at, [int]$n, [float]$w) {
    $prev = $null
    for ($i = 0; $i -le $n; $i++) {
        $p = & $at ($i / $n)
        if ($prev -and $p[2] -gt 0 -and $prev[2] -gt 0) { $g.DrawLine((Pen $w), [float]$prev[0], [float]$prev[1], [float]$p[0], [float]$p[1]) }
        $prev = $p
    }
}

# 1. The body as a filled shape (every surface cell, front and back) -> its outline, notch included.
#    Front cells inside the dent are also painted into a shadow layer, darker the deeper they are.
$bm = New-Canvas; $gb = $bm[1]; $gb.SmoothingMode = 'None'
$sh = New-Canvas; $gs = $sh[1]
$na = 70; $np = 110
for ($i = 0; $i -lt $na; $i++) {
    $a0 = [Math]::PI * $i / $na; $a1 = [Math]::PI * ($i + 1) / $na
    for ($j = 0; $j -lt $np; $j++) {
        $p0 = 2 * [Math]::PI * $j / $np; $p1 = 2 * [Math]::PI * ($j + 1) / $np
        $am = ($a0 + $a1) / 2; $pm = ($p0 + $p1) / 2
        $k = FoldK ($R * [Math]::Cos($am)) ($R * [Math]::Sin($am) * [Math]::Cos($pm))
        $c = @((Ball $a0 $p0), (Ball $a1 $p0), (Ball $a1 $p1), (Ball $a0 $p1))
        $poly = [System.Drawing.PointF[]]($c | ForEach-Object { Pt $_ })
        $gb.FillPolygon([System.Drawing.Brushes]::Black, $poly)
        if ($k -gt 0.12 -and $c[0][2] -gt 0) {
            $v = [int](255 * (1 - $k)); $gs.FillPolygon((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($v, $v, $v))), $poly)
        }
    }
}
$bodyMask = [Img]::FromBitmap($bm[0])
$outline = [Lab]::OutlineBand($bodyMask, [int]$EdgeW, 0.2, 0.8)
$bodyMask.Save((Join-Path $out "ref3c_body_$Tag.png"))
$shadow = [Lab]::Mix([Img]::Solid($W, $H, 1, 1, 1), [Lab]::Soften([Img]::FromBitmap($sh[0]), $ShadeSoft), $Shade)

# 2. Globe lines on the near face: meridian pairs diving into the notch, latitude rings, and extra
#    rings close to the fist that squeeze together as the surface caves in.
$grid = New-Canvas; $g = $grid[1]
foreach ($deg in $Azis.Split(',')) {
    $p0 = [double]$deg * [Math]::PI / 180
    foreach ($d in 0, $PairGap) { $pp = $p0 + $d; Curve $g { param($t) Ball (0.02 + 3.1 * $t) $pp } 240 $MerW }
}
foreach ($lat in $Lats.Split(',')) { $a = [double]$lat * [Math]::PI / 180; Curve $g { param($t) Ball $a (2 * [Math]::PI * $t) } 300 $LatW }
for ($i = 1; $i -le $SqueezeRings; $i++) { $a = $DentW * 1.4 * $i / ($SqueezeRings + 1); Curve $g { param($t) Ball $a (2 * [Math]::PI * $t) } 220 ($LatW * 0.8) }
$gridRaw = [Lab]::Min([Img]::FromBitmap($grid[0]), $outline)
if ($GridZoom -gt 0) {                                        # the body's lines stretched out from the fist
    $fp = ToScreen ($R * (1 - $Dent) - 20) 0 0
    $gridRaw = [Lab]::Levels([Lab]::Zoom($gridRaw, [float]$fp[0], [float]$fp[1], $GridZoom, 40, $null), 0.2, 0.85, 1)
}
$gridImg = [Lab]::Levels([Lab]::Soften($gridRaw, $GridSoft), 0.3, 1.0, 1.15)

# 3. The arm: an R6 block along the pole axis, fist at the bottom of the dent, out past the right edge.
$arm = New-Canvas; $g = $arm[1]
$x0 = $R * (1 - $Dent) - 20; $x1 = $R * 4
$pts = foreach ($x in $x0, $x1) { foreach ($y in -$ArmHalf, $ArmHalf) { foreach ($z in -$ArmHalf, $ArmHalf) { ,(ToScreen $x $y $z) } } }
function Cross($o, $a, $b) { ($a[0] - $o[0]) * ($b[1] - $o[1]) - ($a[1] - $o[1]) * ($b[0] - $o[0]) }
$sorted = $pts | Sort-Object { $_[0] }, { $_[1] }
$lower = New-Object System.Collections.ArrayList; foreach ($p in $sorted) { while ($lower.Count -ge 2 -and (Cross $lower[$lower.Count - 2] $lower[$lower.Count - 1] $p) -le 0) { $lower.RemoveAt($lower.Count - 1) }; [void]$lower.Add($p) }
$upper = New-Object System.Collections.ArrayList; foreach ($p in ($sorted[($sorted.Count - 1)..0])) { while ($upper.Count -ge 2 -and (Cross $upper[$upper.Count - 2] $upper[$upper.Count - 1] $p) -le 0) { $upper.RemoveAt($upper.Count - 1) }; [void]$upper.Add($p) }
$hull = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
foreach ($p in ($lower[0..($lower.Count - 2)] + $upper[0..($upper.Count - 2)])) { $hull.Add((Pt $p)) }
$g.FillPolygon([System.Drawing.Brushes]::Black, $hull.ToArray())
if ($Shoulder) {
    $v = [float[]]($Shoulder.Split(','))
    $sp = for ($i = 0; $i -lt $v.Length; $i += 2) { New-Object System.Drawing.PointF $v[$i], $v[$i + 1] }
    $g.FillPolygon([System.Drawing.Brushes]::Black, [System.Drawing.PointF[]]$sp)
    foreach ($q in $sp) { $hull.Add($q) }
}
$armImg = [Img]::FromBitmap($arm[0])
$fist = ToScreen $x0 0 0
$top = $null; foreach ($y in -$ArmHalf, $ArmHalf) { foreach ($z in -$ArmHalf, $ArmHalf) { $c = ToScreen $x0 $y $z; if (-not $top -or $c[1] -lt $top[1]) { $top = $c } } }
$sx = [float]$top[0]; $sy = [float]$top[1]

# 4. The arm smeared away from the fist: cracks only well away from the fist, averaging zoom toward
#    the fist's top corner, a hard cut, needles from the edges right of the fist.
$cracks = [Lab]::PolarNoise($W, $H, $sx, $sy, 300, 0.3, $CrackDark, 0.15, 13)
$rim = [Lab]::Levels([Lab]::RadialShape([Img]::Solid($W, $H, 1, 1, 1), $sx, $sy, $RimR, 5000, 1, -1, 0, 0), 0.9, 1.0, 1)
$cracks = [Lab]::MaskMix([Img]::Solid($W, $H, 0, 0, 0), $cracks, $rim)
$armSrc = [Lab]::MaskMix([Img]::Solid($W, $H, 1, 1, 1), $cracks, [Lab]::Levels($armImg, 0.5, 0.49, 1))
$armBody = [Lab]::Levels([Lab]::Zoom($armSrc, $sx, $sy, $Smear, 48, $null), 0.44, 0.56, 1)
$rnd = New-Object System.Random 5
$nd = New-Canvas; $g = $nd[1]
for ($i = 0; $i -lt $hull.Count; $i++) {
    $a = $hull[$i]; $b = $hull[($i + 1) % $hull.Count]
    if ($a.X -lt $fist[0] + 60 -and $b.X -lt $fist[0] + 60) { continue }
    for ($k = 0; $k -lt $Specks; $k++) {
        $t = $rnd.NextDouble(); $x = $a.X + ($b.X - $a.X) * $t; $y = $a.Y + ($b.Y - $a.Y) * $t
        $v = [int](140 * $rnd.NextDouble()); $z = 2 + $rnd.NextDouble() * 6
        $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($v, $v, $v))), [float]($x - $z / 2), [float]($y - $z / 2), [float]$z, [float]$z)
    }
}
$needles = [Lab]::Levels([Lab]::Trail([Img]::FromBitmap($nd[0]), $sx, $sy, -$NeedleLen, 150, 0.9), 0.44, 0.56, 1)
$armOut = [Lab]::Soften([Lab]::Min($armBody, $needles), 2)

# 5. Together, the measured ramp, the letterbox.
$ink = [Lab]::Min([Lab]::Min($gridImg, $shadow), $armOut)
$ink.Save((Join-Path $out "ref3c_ink_$Tag.png"))
$col = [Lab]::GradientMap($ink, '0:1,3,2;0.08:13,29,24;0.5:100,153,136;0.75:159,219,209;0.85:180,231,227;0.92:208,241,240;1:255,255,255')
$bmp = New-Object System.Drawing.Bitmap $W, 960
$gg = [System.Drawing.Graphics]::FromImage($bmp); $gg.Clear([System.Drawing.Color]::Black)
$gg.DrawImage($col.ToBitmap(), 0, 120, $W, $H)
$bmp.Save((Join-Path $out "ref3c_copy_$Tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
[Lab]::Side((Join-Path $Refs 'ref3.png'), (Join-Path $out "ref3c_copy_$Tag.png"), (Join-Path $out "ref3c_side_$Tag.png"), 420, 'reference 3', "gut punch $Tag")
"fist at $([int]$fist[0]), $([int]$fist[1])"
