# Reference 3 as a scene: the target's body is a big ball drawn with globe lines, seen from the side.
# The fist (an R6 arm block) drives in from the right and hits it at the pole. Near the pole the
# surface caves in (dent) and twists, so the meridians curve hard into the impact. Then each layer
# is softened or smeared away from the fist, and the measured black -> teal -> white ramp goes on.
param([string]$Refs,
      [float]$Cx = 40, [float]$Cy = 300, [float]$R = 540,       # ball centre and radius on screen (2x px)
      [float]$Tilt = 25, [float]$Aim = 10,                      # pole tipped toward the camera; its screen angle
      [float]$Dent = 0.25, [float]$DentW = 0.45, [float]$Twist = 0.6,
      [int]$Meridians = 12, [string]$Lats = '28,50,75,95,120', [float]$MerW = 16, [float]$LatW = 20,
      [float]$PairGap = 0.05, [float]$MerPhase = 0, [string]$Azis = '', [float]$RimR = 220, [float]$RimK = 1.3, [int]$CraterRings = 3, [float]$Shade = 0.6, [int]$ShadeSoft = 22,
      [float]$ArmHalf = 85, [float]$Smear = 0.35, [float]$SmX = 0, [float]$SmY = 0, [string]$Shoulder = "", [float]$CrackDark = 0.85, [int]$Specks = 40, [float]$NeedleLen = 0.8, [int]$GridSoft = 6,
      [string]$Tag = 'b1')
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'
$W = 1280; $H = 720
$cb = [Math]::Cos($Tilt * [Math]::PI / 180); $sb = [Math]::Sin($Tilt * [Math]::PI / 180)
$cg = [Math]::Cos($Aim * [Math]::PI / 180); $sg = [Math]::Sin($Aim * [Math]::PI / 180)

# Local frame: pole along +x. Tip the pole toward the camera (+z = toward the viewer), then turn it
# in the screen plane by Aim (y down). Returns screen x, y and depth z.
function ToScreen([double]$x, [double]$y, [double]$z) {
    $x1 = $x * $cb - $z * $sb; $z1 = $x * $sb + $z * $cb
    $x2 = $x1 * $cg - $y * $sg; $y2 = $x1 * $sg + $y * $cg
    return @(($Cx + $x2), ($Cy + $y2), $z1)
}
# A point on the dented, twisted ball: polar angle a from the pole, azimuth p round it.
function Ball([double]$a, [double]$p) {
    $k = [Math]::Exp(-[Math]::Pow($a / $DentW, 2))
    $r = $R * (1 - $Dent * $k); $p2 = $p + $Twist * $k
    return ToScreen ($r * [Math]::Cos($a)) ($r * [Math]::Sin($a) * [Math]::Cos($p2)) ($r * [Math]::Sin($a) * [Math]::Sin($p2))
}
function New-Canvas {
    $b = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::White)
    return @($b, $g)
}
function Pen([float]$w) { $p = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), $w; $p.StartCap = 'Round'; $p.EndCap = 'Round'; $p }
# Draw a curve on the ball's front: width grows with nearness to the viewer.
function Curve($g, [scriptblock]$at, [int]$n, [float]$w) {
    $prev = $null
    for ($i = 0; $i -le $n; $i++) {
        $p = & $at ($i / $n)
        if ($prev -and $p[2] -gt 0 -and $prev[2] -gt 0) {
            $g.DrawLine((Pen ($w * (0.55 + 0.45 * $p[2] / $R))), [float]$prev[0], [float]$prev[1], [float]$p[0], [float]$p[1])
        }
        $prev = $p
    }
}

# 1. The body: globe lines. Meridians come in pairs (the doubled "swooshes"); latitude rings single.
$grid = New-Canvas; $g = $grid[1]
$aziList = if ($Azis) { $Azis.Split(',') | ForEach-Object { [double]$_ * [Math]::PI / 180 } } else { 0..($Meridians - 1) | ForEach-Object { $_ * 2 * [Math]::PI / $Meridians } }
foreach ($p0 in $aziList) {
    foreach ($d in 0, $PairGap) { $pp = $p0 + $MerPhase + $d; Curve $g { param($t) Ball (0.03 + 3.1 * $t) $pp } 220 $MerW }
}
foreach ($lat in $Lats.Split(',')) {
    $a = [double]$lat * [Math]::PI / 180
    Curve $g { param($t) Ball $a (2 * [Math]::PI * $t) } 300 $LatW
}
# The body going INWARDS: rings inside the crater shrinking into the hole (a funnel), and a bold
# rim ring where the surface turns from bulging out to caving in.
$rimA = $DentW * $RimK
for ($i = 1; $i -le $CraterRings; $i++) {
    $a = $rimA * $i / ($CraterRings + 1)
    Curve $g { param($t) Ball $a (2 * [Math]::PI * $t) } 200 ($LatW * (0.5 + 0.4 * $i / $CraterRings))
}
Curve $g { param($t) Ball $rimA (2 * [Math]::PI * $t) } 300 ($LatW * 1.5)
$gridImg = [Lab]::Levels([Lab]::Soften([Img]::FromBitmap($grid[0]), $GridSoft), 0.3, 1.0, 1.15)

# The crater's shadow: its rim filled, softened hard, so it is darkest at the fist.
$cr = New-Canvas
$rimPts = for ($i = 0; $i -lt 160; $i++) { $p = Ball $rimA (2 * [Math]::PI * $i / 160); New-Object System.Drawing.PointF ([float]$p[0]), ([float]$p[1]) }
$cr[1].FillPolygon([System.Drawing.Brushes]::Black, [System.Drawing.PointF[]]$rimPts)
$shadow = [Lab]::Mix([Img]::Solid($W, $H, 1, 1, 1), [Lab]::Soften([Img]::FromBitmap($cr[0]), $ShadeSoft), $Shade)

# 2. The arm: an R6 block along the pole axis, its fist end at the bottom of the dent, running out
#    past the right edge. All black (it is a silhouette); drawn as the hull of its 8 corners.
$arm = New-Canvas; $g = $arm[1]
$x0 = $R * (1 - $Dent) - 20; $x1 = $R * 3.2
$pts = foreach ($x in $x0, $x1) { foreach ($y in -$ArmHalf, $ArmHalf) { foreach ($z in -$ArmHalf, $ArmHalf) { ,(ToScreen $x $y $z) } } }
$hull = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
$sorted = $pts | Sort-Object { $_[0] }, { $_[1] }
function Cross($o, $a, $b) { ($a[0] - $o[0]) * ($b[1] - $o[1]) - ($a[1] - $o[1]) * ($b[0] - $o[0]) }
$lower = New-Object System.Collections.ArrayList; foreach ($p in $sorted) { while ($lower.Count -ge 2 -and (Cross $lower[$lower.Count - 2] $lower[$lower.Count - 1] $p) -le 0) { $lower.RemoveAt($lower.Count - 1) }; [void]$lower.Add($p) }
$upper = New-Object System.Collections.ArrayList; foreach ($p in ($sorted[($sorted.Count - 1)..0])) { while ($upper.Count -ge 2 -and (Cross $upper[$upper.Count - 2] $upper[$upper.Count - 1] $p) -le 0) { $upper.RemoveAt($upper.Count - 1) }; [void]$upper.Add($p) }
foreach ($p in ($lower[0..($lower.Count - 2)] + $upper[0..($upper.Count - 2)])) { $hull.Add((New-Object System.Drawing.PointF ([float]$p[0]), ([float]$p[1]))) }
$g.FillPolygon([System.Drawing.Brushes]::Black, $hull.ToArray())
if ($Shoulder) {                                                  # the attacker's body, low right
    $v = [float[]]($Shoulder.Split(','))
    $sp = for ($i = 0; $i -lt $v.Length; $i += 2) { New-Object System.Drawing.PointF $v[$i], $v[$i + 1] }
    $g.FillPolygon([System.Drawing.Brushes]::Black, [System.Drawing.PointF[]]$sp)
    for ($i = 0; $i -lt $sp.Count; $i++) { $hull.Add($sp[$i]) }      # its edges get needles too
}
$fist = ToScreen $x0 0 0
$top = ToScreen $x0 (-$ArmHalf) (-$ArmHalf); foreach ($y in -$ArmHalf, $ArmHalf) { foreach ($z in -$ArmHalf, $ArmHalf) { $c = ToScreen $x0 $y $z; if ($c[1] -lt $top[1]) { $top = $c } } }
$sx = [float]($top[0] + $SmX); $sy = [float]($top[1] + $SmY)     # smear centre: the fist's top corner (measured)
$armImg = [Img]::FromBitmap($arm[0]); $armImg.Save((Join-Path $out "ref3b_arm_$Tag.png")); "smear centre $([int]$sx), $([int]$sy)"

# 3. The arm smeared away from the fist (it is the thing moving): averaging zoom toward the fist,
#    a hard cut, then needles trailed from specks along its edges.
$rnd = New-Object System.Random 5
$cracks = [Lab]::PolarNoise($W, $H, $sx, $sy, 300, 0.3, $CrackDark, 0.15, 13)
$rim = [Lab]::RadialShape([Img]::Solid($W, $H, 1, 1, 1), $sx, $sy, $RimR, 5000, 1, -1, 0, 0)   # no cracks near the fist
$rim = [Lab]::Levels($rim, 0.9, 1.0, 1)                                   # a sharp start, not a fade
$cracks = [Lab]::MaskMix([Img]::Solid($W, $H, 0, 0, 0), $cracks, $rim)
$armSrc = [Lab]::MaskMix([Img]::Solid($W, $H, 1, 1, 1), $cracks, [Lab]::Levels($armImg, 0.5, 0.49, 1))
$body = [Lab]::Levels([Lab]::Zoom($armSrc, $sx, $sy, $Smear, 48, $null), 0.44, 0.56, 1)
$nd = New-Canvas; $g = $nd[1]
for ($i = 0; $i -lt $hull.Count; $i++) {
    $a = $hull[$i]; $b = $hull[($i + 1) % $hull.Count]
    if ($a.X -lt $fist[0] + 60 -and $b.X -lt $fist[0] + 60) { continue }      # the fist's own face stays clean
    for ($k = 0; $k -lt $Specks; $k++) {
        $t = $rnd.NextDouble(); $x = $a.X + ($b.X - $a.X) * $t; $y = $a.Y + ($b.Y - $a.Y) * $t
        $v = [int](140 * $rnd.NextDouble()); $z = 2 + $rnd.NextDouble() * 6
        $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($v, $v, $v))), [float]($x - $z / 2), [float]($y - $z / 2), [float]$z, [float]$z)
    }
}
$needles = [Lab]::Levels([Lab]::Trail([Img]::FromBitmap($nd[0]), $sx, $sy, -$NeedleLen, 150, 0.9), 0.44, 0.56, 1)
$armOut = [Lab]::Soften([Lab]::Min($body, $needles), 2)

# 4. Together, the measured ramp, the letterbox.
$ink = [Lab]::Min([Lab]::Min($gridImg, $shadow), $armOut)
$ink.Save((Join-Path $out "ref3b_ink_$Tag.png"))
$col = [Lab]::GradientMap($ink, '0:1,3,2;0.08:13,29,24;0.5:100,153,136;0.75:159,219,209;0.85:180,231,227;0.92:208,241,240;1:255,255,255')
$bmp = New-Object System.Drawing.Bitmap $W, 960
$gg = [System.Drawing.Graphics]::FromImage($bmp); $gg.Clear([System.Drawing.Color]::Black)
$gg.DrawImage($col.ToBitmap(), 0, 120, $W, $H)
$bmp.Save((Join-Path $out "ref3b_copy_$Tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
[Lab]::Side((Join-Path $Refs 'ref3.png'), (Join-Path $out "ref3b_copy_$Tag.png"), (Join-Path $out "ref3b_side_$Tag.png"), 420, 'reference 3', "scene copy $Tag")
"fist at $([int]$fist[0]), $([int]$fist[1])"
