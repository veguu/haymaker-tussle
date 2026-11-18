# Reference 3 in perspective, from a 3/4 angle: the target's body (a ball drawn with globe lines) WRAPS
# ROUND THE FIST and sinks into a deep funnel along the punch, so all its lines run toward one
# vanishing point. The arm is an R6 block coming from near the camera into the funnel, its edges
# converging on the same point. Surface patches are painted far to near (near ones hide far ones), the
# funnel darkens with depth, the arm is smeared away from the vanishing point, then the measured
# black -> teal -> white ramp and the letterbox.
param([string]$Refs,
      [double]$CamX = -4, [double]$CamY = 2, [double]$CamZ = -7, [double]$LookZ = 3, [double]$Focal = 900, [double]$Roll = 0,
      [double]$VPX = 520, [double]$VPY = 280, [double]$FistSX = 0, [double]$FistSY = 0,   # vanishing point (measured) or fist anchor
      [double]$Rb = 6, [double]$Depth = 30, [double]$FunnelW = 1.1, [double]$BodyTurn = 45, [double]$MaxAngle = 100, [double]$Twist = 0, [string]$MerAz = '', [string]$RingDeg = '', [double]$PairDeg = 1.5, [double]$ArmVPX = 0, [double]$ArmVPY = 0, [double]$ArmLen = 2, [string]$ArmPoly = '', [double]$SmearX = 0, [double]$SmearY = 0, [double]$NeedleMinX = 0, [double]$SinkVPX = 0, [double]$SinkVPY = 0, [int]$RingGrey = 0, [double]$RingFade = 0, [double]$RingW = 1, [double]$TwinW = 1,
      [double]$FistZ = 2.2, [double]$ArmHalf = 0.55, [double]$ArmBack = -5,
      [int]$Meridians = 16, [int]$NRho = 70, [int]$NPhi = 96, [string]$RingAt = '6,12,18,26,36,46,56,66',
      [double]$LineW = 9, [double]$Shade = 0.8, [double]$ShadeDepth = 4, [double]$ShadeStart = 0.6, [int]$GridSoft = 4,
      [float]$Smear = 0.4, [float]$CrackDark = 0.8, [float]$RimR = 260, [float]$NeedleLen = 1.0, [int]$Specks = 50,
      [string]$Tag = 'd1')
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'
$W = 1280; $H = 720

# Camera basis (world: y up, punch along +z into the body).
function Norm($v) { $l = [Math]::Sqrt($v[0] * $v[0] + $v[1] * $v[1] + $v[2] * $v[2]); @(($v[0] / $l), ($v[1] / $l), ($v[2] / $l)) }
function CrossV($a, $b) { @(($a[1] * $b[2] - $a[2] * $b[1]), ($a[2] * $b[0] - $a[0] * $b[2]), ($a[0] * $b[1] - $a[1] * $b[0])) }
$f = Norm @((0 - $CamX), (0 - $CamY), ($LookZ - $CamZ))
$r = Norm (CrossV @(0, 1, 0) $f)
$u = CrossV $f $r
if ($Roll -ne 0) {                                           # roll the camera round its view direction
    $ra = $Roll * [Math]::PI / 180; $c0 = [Math]::Cos($ra); $s0 = [Math]::Sin($ra)
    $r2 = @(($r[0] * $c0 + $u[0] * $s0), ($r[1] * $c0 + $u[1] * $s0), ($r[2] * $c0 + $u[2] * $s0))
    $u = @((-$r[0] * $s0 + $u[0] * $c0), (-$r[1] * $s0 + $u[1] * $c0), (-$r[2] * $s0 + $u[2] * $c0)); $r = $r2
}
# Put the vanishing point of the punch direction (0,0,1) where the reference has it, or (FistSX set)
# put the fist there instead and let the vanishing point fall where the geometry puts it.
$ox = $VPX - $Focal * $r[2] / $f[2]; $oy = $VPY + $Focal * $u[2] / $f[2]
if ($FistSX -gt 0) {
    $vx = -$CamX; $vy = -$CamY; $vz = $FistZ - $CamZ
    $xc = $vx * $r[0] + $vy * $r[1] + $vz * $r[2]; $yc = $vx * $u[0] + $vy * $u[1] + $vz * $u[2]; $zc = $vx * $f[0] + $vy * $f[1] + $vz * $f[2]
    $ox = $FistSX - $Focal * $xc / $zc; $oy = $FistSY + $Focal * $yc / $zc
    $VPX = $ox + $Focal * $r[2] / $f[2]; $VPY = $oy - $Focal * $u[2] / $f[2]
}
function Proj([double]$x, [double]$y, [double]$z) {
    $vx = $x - $CamX; $vy = $y - $CamY; $vz = $z - $CamZ
    $xc = $vx * $r[0] + $vy * $r[1] + $vz * $r[2]; $yc = $vx * $u[0] + $vy * $u[1] + $vz * $u[2]; $zc = $vx * $f[0] + $vy * $f[1] + $vz * $f[2]
    if ($zc -lt 0.05) { $zc = 0.05 }
    return @(($ox + $Focal * $xc / $zc), ($oy - $Focal * $yc / $zc), $zc)
}
# The body: a ball of radius Rb whose surface touches the fist's start at the origin, TURNED by
# BodyTurn about the vertical so it faces the camera at 3/4. Parametrised round the impact point:
# polar angle a from it, azimuth phi. Then the part near the punch line is pulled deep along the
# punch (+z): the body wraps round the fist and sinks toward the punch's vanishing point.
$bt = $BodyTurn * [Math]::PI / 180
$nx = [Math]::Sin($bt); $nz = [Math]::Cos($bt)            # ball centre direction from the impact
function Surf([double]$a, [double]$phi) {
    $ca = [Math]::Cos($a); $sa = [Math]::Sin($a)
    $e1 = $sa * [Math]::Cos($phi); $e2 = $sa * [Math]::Sin($phi)
    $x = $Rb * ($nx - $nx * $ca + $nz * $e1); $y = $Rb * $e2; $z = $Rb * ($nz - $nz * $ca - $nx * $e1)
    $dz = $Depth * [Math]::Exp(-([Math]::Pow($x, 2) + [Math]::Pow($y, 2)) / ($FunnelW * $FunnelW))
    $tw = $Twist * [Math]::Min(1, $dz / 3)                      # a swirl as the surface sinks
    $x2 = $x * [Math]::Cos($tw) - $y * [Math]::Sin($tw); $y2 = $x * [Math]::Sin($tw) + $y * [Math]::Cos($tw)
    if ($script:sinkDir) {                                      # sink along a chosen direction (toward its vanishing point)
        return @(($x2 + $dz * $script:sinkDir[0]), ($y2 + $dz * $script:sinkDir[1]), ($z + $dz * $script:sinkDir[2]), $dz)
    }
    return @($x2, $y2, ($z + $dz), $dz)
}
function New-Canvas {
    $b = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::White)
    return @($b, $g)
}
function Pen([float]$w) { $p = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), $w; $p.StartCap = 'Round'; $p.EndCap = 'Round'; $p }
function Pt($p) { New-Object System.Drawing.PointF ([float]$p[0]), ([float]$p[1]) }

# The body sinks toward a vanishing point on screen (SinkVPX, SinkVPY): the world direction of the ray
# through that point, so the deep part of the hole recedes exactly there.
$script:sinkDir = $null
if ($SinkVPX -gt 0) {
    $sdx = ($SinkVPX - $ox) / $Focal; $sdy = -($SinkVPY - $oy) / $Focal
    $script:sinkDir = Norm @(($sdx * $r[0] + $sdy * $u[0] + $f[0]), ($sdx * $r[1] + $sdy * $u[1] + $f[1]), ($sdx * $r[2] + $sdy * $u[2] + $f[2]))
}
# 1. Surface patches, far to near. Each is filled by depth in the funnel (deeper = darker) and draws
#    its own globe-line edges, so nearer patches hide farther lines.
$aMax = $MaxAngle * [Math]::PI / 180
$rhos = for ($i = 0; $i -le $NRho; $i++) { $aMax * [Math]::Pow($i / $NRho, 1.7) }    # polar angles
$rings = @{}; foreach ($k in $RingAt.Split(',')) { $rings[[int]$k] = $true }
$mStep = [int]($NPhi / $Meridians)
$cells = New-Object System.Collections.Generic.List[object]
$P = @{}
for ($i = 0; $i -le $NRho; $i++) { for ($j = 0; $j -le $NPhi; $j++) {
    $s = Surf $rhos[$i] (2 * [Math]::PI * $j / $NPhi); $q = Proj $s[0] $s[1] $s[2]
    $P["$i,$j"] = @($q[0], $q[1], $q[2], $s[3])
} }
for ($i = 0; $i -lt $NRho; $i++) { for ($j = 0; $j -lt $NPhi; $j++) {
    $c = @($P["$i,$j"], $P["$($i+1),$j"], $P["$($i+1),$($j+1)"], $P["$i,$($j+1)"])
    $zc = ($c[0][2] + $c[1][2] + $c[2][2] + $c[3][2]) / 4
    $cells.Add(@($zc, $i, $j, $c))
} }
$sorted = $cells | Sort-Object { $_[0] } -Descending
$cv = New-Canvas; $g = $cv[1]
foreach ($cell in $sorted) {
    $i = $cell[1]; $j = $cell[2]; $c = $cell[3]
    $dz = ($c[0][3] + $c[2][3]) / 2
    # shade only inside the hollow (from ShadeStart deep), darkening toward the vanishing point
    $sd = [Math]::Max(0, [Math]::Min(1, ($dz - $ShadeStart) / $ShadeDepth))
    $v = [int](255 * (1 - $Shade * [Math]::Pow($sd, 0.7)))
    $poly = [System.Drawing.PointF[]]@((Pt $c[0]), (Pt $c[1]), (Pt $c[2]), (Pt $c[3]))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($v, $v, $v))), $poly)
    $wpx = [float][Math]::Min(26, [Math]::Max(1.2, $LineW * 7 / $cell[0]))
    # Lines on BOTH cells that share them, so a later (nearer) neighbour's fill can't notch them.
    # Meridians come in pairs (j and j+1 of each step): the doubled "swooshes".
    if ($MerAz) { continue }                                  # explicit lines are drawn below instead
    $mw = [float]($wpx * 0.7)
    if ($j % $mStep -le 1) { $g.DrawLine((Pen $mw), $poly[0], $poly[1]) }                    # meridian
    if (($j + 1) % $mStep -le 1) { $g.DrawLine((Pen $mw), $poly[3], $poly[2]) }
    if ($rings.ContainsKey($i)) { $g.DrawLine((Pen $wpx), $poly[0], $poly[3]) }              # ring
    if ($rings.ContainsKey($i + 1)) { $g.DrawLine((Pen $wpx), $poly[1], $poly[2]) }
    if ($i + 1 -eq $NRho) { $g.DrawLine((Pen ($wpx * 1.6)), $poly[1], $poly[2]) }            # the body's edge
}
# Explicit globe lines where the fit placed the reference's lines: meridians (in close pairs) at the
# given azimuths, rings at the given angles from the impact. Width shrinks with distance.
if ($MerAz) {
    function Seg($a1, $p1, $a2, $p2, [double]$w, [int]$grey) {
        $s1 = Surf $a1 $p1; $s2 = Surf $a2 $p2; $q1 = Proj $s1[0] $s1[1] $s1[2]; $q2 = Proj $s2[0] $s2[1] $s2[2]
        if ($q1[2] -lt 0.1 -or $q2[2] -lt 0.1) { return }
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($grey, $grey, $grey)), ([float][Math]::Min(40, [Math]::Max(1.5, $w / $q1[2])))
        $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
        $g.DrawLine($pen, [float]$q1[0], [float]$q1[1], [float]$q2[0], [float]$q2[1])
    }
    $aTop = $MaxAngle * [Math]::PI / 180
    # rings first (softer, grey cores), outer rings fainter; then the meridians on top
    $ri = 0; $rl = @($RingDeg.Split(','))
    foreach ($deg in $rl) {
        $a = [double]$deg * [Math]::PI / 180
        $grey = [int]($RingGrey + (200 - $RingGrey) * $ri / [Math]::Max(1, $rl.Count - 1) * $RingFade); $ri++
        for ($k = 0; $k -lt 240; $k++) { Seg $a (2 * [Math]::PI * $k / 240) $a (2 * [Math]::PI * ($k + 1) / 240) ($LineW * $RingW) $grey }
    }
    foreach ($deg in $MerAz.Split(',')) {
        foreach ($d in 0, $PairDeg) {
            $ph = ([double]$deg + $d) * [Math]::PI / 180; $lineWidth = if ($d -eq 0) { $LineW * 0.8 } else { $LineW * 0.8 * $TwinW }
            for ($k = 0; $k -lt 160; $k++) { $a1 = $aTop * [Math]::Pow($k / 160, 1.5); $a2 = $aTop * [Math]::Pow(($k + 1) / 160, 1.5); Seg $a1 $ph $a2 $ph $lineWidth 0 }
        }
    }
}
$surfImg = [Lab]::Soften([Img]::FromBitmap($cv[0]), $GridSoft)
$surfImg.Save((Join-Path $out "ref3d_surf_$Tag.png"))

# 2. The arm: an R6 block along the punch, fist end at FistZ inside the funnel, the other end near the
#    camera (off the right edge). Its edges converge on the vanishing point.
$a = $ArmHalf
$corners = foreach ($z in $FistZ, $ArmBack) { foreach ($x in -$a, $a) { foreach ($y in -$a, $a) { ,(Proj $x $y $z) } } }
if ($ArmVPX -gt 0) {
    # The arm points at its own vanishing point (ArmVPX, ArmVPY) on screen: its far direction is the ray
    # through that point. It runs from the fist (at FistZ on the punch line) back toward the camera.
    $dx = ($ArmVPX - $ox) / $Focal; $dy = -($ArmVPY - $oy) / $Focal
    $d = Norm @(($dx * $r[0] + $dy * $u[0] + $f[0]), ($dx * $r[1] + $dy * $u[1] + $f[1]), ($dx * $r[2] + $dy * $u[2] + $f[2]))
    $e1 = Norm (CrossV $d @(0, 1, 0)); $e2 = CrossV $d $e1
    $corners = foreach ($t in 0, -$ArmLen) { foreach ($i in -1, 1) { foreach ($j in -1, 1) {
        ,(Proj ($d[0] * $t + $a * ($i * $e1[0] + $j * $e2[0])) ($d[1] * $t + $a * ($i * $e1[1] + $j * $e2[1])) ($FistZ + $d[2] * $t + $a * ($i * $e1[2] + $j * $e2[2])))
    } } }
}
function Cross2($o, $p, $q) { ($p[0] - $o[0]) * ($q[1] - $o[1]) - ($p[1] - $o[1]) * ($q[0] - $o[0]) }
$sc = $corners | Sort-Object { $_[0] }, { $_[1] }
$lower = New-Object System.Collections.ArrayList; foreach ($p in $sc) { while ($lower.Count -ge 2 -and (Cross2 $lower[$lower.Count - 2] $lower[$lower.Count - 1] $p) -le 0) { $lower.RemoveAt($lower.Count - 1) }; [void]$lower.Add($p) }
$upper = New-Object System.Collections.ArrayList; foreach ($p in ($sc[($sc.Count - 1)..0])) { while ($upper.Count -ge 2 -and (Cross2 $upper[$upper.Count - 2] $upper[$upper.Count - 1] $p) -le 0) { $upper.RemoveAt($upper.Count - 1) }; [void]$upper.Add($p) }
$hull = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
foreach ($p in ($lower[0..($lower.Count - 2)] + $upper[0..($upper.Count - 2)])) { $hull.Add((Pt $p)) }
if ($ArmPoly) {                                            # the arm's outline given directly (screen px)
    $v = [float[]]($ArmPoly.Split(','))
    $hull = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
    for ($i = 0; $i -lt $v.Length; $i += 2) { $hull.Add((New-Object System.Drawing.PointF $v[$i], $v[$i + 1])) }
}
if ($SmearX -gt 0) { $VPX = $SmearX; $VPY = $SmearY }       # the arm's own vanishing point drives its smear
$am = New-Canvas; $am[1].FillPolygon([System.Drawing.Brushes]::Black, $hull.ToArray())
$armImg = [Img]::FromBitmap($am[0])
$fist = Proj 0 0 $FistZ

# 3. The arm smeared away from the vanishing point (cracks only well out from it), cut hard, needles.
$cracks = [Lab]::PolarNoise($W, $H, [float]$VPX, [float]$VPY, 300, 0.3, $CrackDark, 0.15, 13)
$fistS = Proj 0 0 $FistZ
$rim = [Lab]::Levels([Lab]::RadialShape([Img]::Solid($W, $H, 1, 1, 1), [float]$fistS[0], [float]$fistS[1], $RimR, 5000, 1, -1, 0, 0), 0.9, 1.0, 1)
$cracks = [Lab]::MaskMix([Img]::Solid($W, $H, 0, 0, 0), $cracks, $rim)
$armSrc = [Lab]::MaskMix([Img]::Solid($W, $H, 1, 1, 1), $cracks, [Lab]::Levels($armImg, 0.5, 0.49, 1))
$armBody = [Lab]::Levels([Lab]::Zoom($armSrc, [float]$VPX, [float]$VPY, $Smear, 48, $null), 0.44, 0.56, 1)
$rnd = New-Object System.Random 5
$nd = New-Canvas; $g = $nd[1]
for ($i = 0; $i -lt $hull.Count; $i++) {
    $p = $hull[$i]; $q = $hull[($i + 1) % $hull.Count]
    $mx = ($p.X + $q.X) / 2 - $fistS[0]; $my = ($p.Y + $q.Y) / 2 - $fistS[1]
    if ([Math]::Sqrt($mx * $mx + $my * $my) -lt $RimR * 0.6) { continue }       # the fist end stays clean
    if ((($p.X + $q.X) / 2) -lt $NeedleMinX) { continue }                         # needles only off the far edges
    for ($k = 0; $k -lt $Specks; $k++) {
        $t = $rnd.NextDouble(); $x = $p.X + ($q.X - $p.X) * $t; $y = $p.Y + ($q.Y - $p.Y) * $t
        $v = [int](140 * $rnd.NextDouble()); $z = 2 + $rnd.NextDouble() * 6
        $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($v, $v, $v))), [float]($x - $z / 2), [float]($y - $z / 2), [float]$z, [float]$z)
    }
}
$needles = [Lab]::Levels([Lab]::Trail([Img]::FromBitmap($nd[0]), [float]$VPX, [float]$VPY, -$NeedleLen, 150, 0.9), 0.44, 0.56, 1)
$armOut = [Lab]::Soften([Lab]::Min($armBody, $needles), 2)

# 4. Together, the ramp, the letterbox.
$ink = [Lab]::Min($surfImg, $armOut)
$ink.Save((Join-Path $out "ref3d_ink_$Tag.png"))

# Check against the reference: its traced target lines (rings blue, spokes orange) over our surface.
# Reference coords are 1280x712 picture coords; ours are 1280x720, so scale y by 720/712.
. "$PSScriptRoot\ref3_lines.ps1"
$ov = $surfImg.ToBitmap(); $go = [System.Drawing.Graphics]::FromImage($ov); $go.SmoothingMode = 'AntiAlias'
foreach ($k in $RefLines.Keys) {
    $col = if ($RefLines[$k].fam -eq 'spoke') { [System.Drawing.Color]::FromArgb(230, 240, 120, 0) } else { [System.Drawing.Color]::FromArgb(230, 30, 90, 230) }
    $p = $RefLines[$k].pts
    $pf = [System.Drawing.PointF[]]@(for ($i = 0; $i -lt $p.Length; $i += 2) { New-Object System.Drawing.PointF ([float]$p[$i]), ([float]($p[$i + 1] * 720 / 712)) })
    $go.DrawCurve((New-Object System.Drawing.Pen $col, 4), $pf)
}
$go.FillEllipse([System.Drawing.Brushes]::Red, 592, 387, 18, 18)
$ov.Save((Join-Path $out "ref3d_overlay_$Tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$col = [Lab]::GradientMap($ink, '0:1,3,2;0.08:13,29,24;0.5:100,153,136;0.75:159,219,209;0.85:180,231,227;0.92:208,241,240;1:255,255,255')
$bmp = New-Object System.Drawing.Bitmap $W, 960
$gg = [System.Drawing.Graphics]::FromImage($bmp); $gg.Clear([System.Drawing.Color]::Black)
$gg.DrawImage($col.ToBitmap(), 0, 120, $W, $H)
$bmp.Save((Join-Path $out "ref3d_copy_$Tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
[Lab]::Side((Join-Path $Refs 'ref3.png'), (Join-Path $out "ref3d_copy_$Tag.png"), (Join-Path $out "ref3d_side_$Tag.png"), 420, 'reference 3', "3/4 funnel $Tag")
"fist at $([int]$fist[0]), $([int]$fist[1]); vanishing point $VPX, $VPY"
