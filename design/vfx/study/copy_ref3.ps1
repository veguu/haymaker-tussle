# Reference 3 redrawn from measurements only: the target's strokes from ref3_strokes.ps1 (paths, widths,
# darkness) and the black mass from its measured outline, then softened, the measured teal ramp, and the
# letterbox. Also writes an overlay of the traced lines on the copy, to check they match.
param([string]$Refs, [float]$MassThr = 0.12, [int]$MassMin = 1500, [int]$MassStep = 3, [float]$MassMinX = 450, [int]$Soft = 4, [int]$HaloSoft = 12, [float]$HaloLift = 0.5, [string]$RidgeFiles = 'ref3_ridges_r1_points.txt,ref3_ridges_r2_points.txt', [float]$RidgeW = 6, [float]$RidgeLift = 0.05,
      [float]$WidthK = 1.0, [string]$Tag = 'm1')
. "$PSScriptRoot\load.ps1"
. "$PSScriptRoot\ref3_strokes.ps1"
. "$PSScriptRoot\ref3_lines.ps1"
$out = Join-Path $PSScriptRoot 'out'
$W = 1280; $H = 712
$ref = [Img]::Load((Join-Path $Refs 'ref3.png')).Crop(0, 62, 640, 356).Resize($W, $H)

$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::White)

# 1. The target's strokes, lightest first, as smooth curves: segments of a Catmull-Rom spline through the
#    points, each with the width and darkness interpolated along the stroke.
function Spline($p, [int]$per) {
    $n = $p.Count; $res = New-Object System.Collections.Generic.List[double[]]
    for ($i = 0; $i -lt $n - 1; $i++) {
        $p0 = $p[[Math]::Max(0, $i - 1)]; $p1 = $p[$i]; $p2 = $p[$i + 1]; $p3 = $p[[Math]::Min($n - 1, $i + 2)]
        for ($k = 0; $k -lt $per; $k++) {
            $t = $k / $per; $t2 = $t * $t; $t3 = $t2 * $t
            $x = 0.5 * ((2 * $p1[0]) + (-$p0[0] + $p2[0]) * $t + (2 * $p0[0] - 5 * $p1[0] + 4 * $p2[0] - $p3[0]) * $t2 + (-$p0[0] + 3 * $p1[0] - 3 * $p2[0] + $p3[0]) * $t3)
            $y = 0.5 * ((2 * $p1[1]) + (-$p0[1] + $p2[1]) * $t + (2 * $p0[1] - 5 * $p1[1] + 4 * $p2[1] - $p3[1]) * $t2 + (-$p0[1] + 3 * $p1[1] - 3 * $p2[1] + $p3[1]) * $t3)
            $wv = $p1[2] + ($p2[2] - $p1[2]) * $t
            $res.Add([double[]]@($x, $y, $wv))
        }
    }
    $last = $p[$n - 1]; $res.Add([double[]]@($last[0], $last[1], $last[2]))
    return $res
}
$order = $Strokes.Keys | Sort-Object { - $Strokes[$_].dark }
foreach ($k in $order) {
    $s = $Strokes[$k]; $v = [int](255 * $s.dark)
    $pts = for ($i = 0; $i -lt $s.pts.Length; $i += 2) { ,[double[]]@($s.pts[$i], $s.pts[$i + 1], $s.w[$i / 2]) }
    $sp = Spline $pts 12
    for ($i = 0; $i -lt $sp.Count - 1; $i++) {
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($v, $v, $v)), ([float]([Math]::Max(1, $sp[$i][2] * $WidthK)))
        $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
        $g.DrawLine($pen, [float]$sp[$i][0], [float]$sp[$i][1], [float]$sp[$i + 1][0], [float]$sp[$i + 1][1])
    }
}

# 1b. Every other measured centreline (ridge passes r1, r2), each sample drawn at the reference's own
#     darkness there; samples in the black mass are skipped (the mass is drawn from its outline).
foreach ($pf in $RidgeFiles.Split(',')) {
    $path = Join-Path $out $pf
    if (-not (Test-Path $path)) { continue }
    foreach ($line in Get-Content $path) {
        if (-not $line.Contains(':')) { continue }
        $smp = @($line.Split(':')[1].Trim().Split(' ') | Where-Object { $_ } | ForEach-Object { $c = $_.Split(','); ,[double[]]@($c[0], $c[1], $c[2], $c[3]) })
        for ($i = 0; $i -lt $smp.Count - 1; $i++) {
            $a = $smp[$i]; $b = $smp[$i + 1]
            if ([Math]::Abs($a[0] - $b[0]) + [Math]::Abs($a[1] - $b[1]) -gt 30) { continue }
            $dk = ($a[3] + $b[3]) / 2; if ($dk -lt 0.04 -and $a[0] -gt 450) { continue }
            $v = [int](255 * [Math]::Min(0.85, $dk + $RidgeLift))
            $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($v, $v, $v)), ([float]$RidgeW)
            $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
            $g.DrawLine($pen, [float]$a[0], [float]$a[1], [float]$b[0], [float]$b[1])
        }
    }
}

# 2. The black mass (fist, arm, spikes, the lower-right mass): measured outlines of the darkest regions.
$outl = [Lab]::DarkOutlines($ref, $MassThr, $MassMin, $MassStep)
$nMass = 0
foreach ($line in ($outl -split "`n")) {
    if (-not $line.Contains(':')) { continue }
    $xy = $line.Split(':')[1].Trim().Split(' ')
    if ($xy.Count -lt 3) { continue }
    if ([float]($xy[0].Split(",")[0]) -lt $MassMinX) { continue }               # the swooshes' own black cores are strokes
    $poly = [System.Drawing.PointF[]]@($xy | ForEach-Object { $c = $_.Split(','); New-Object System.Drawing.PointF ([float]$c[0]), ([float]$c[1]) })
    $g.FillPolygon([System.Drawing.Brushes]::Black, $poly, [System.Drawing.Drawing2D.FillMode]::Winding); $nMass++
}
"mass regions: $nMass"

# 3. Soften, ramp, letterbox; compare.
# Each stroke: a lightly softened core, and a wide soft halo (the same ink blurred hard, lifted to a
# light grey): the reference's dark cores with broad teal edges.
$raw = [Img]::FromBitmap($bmp)
$core = [Lab]::Soften($raw, $Soft)
$halo = [Lab]::Levels([Lab]::Soften($raw, $HaloSoft), -$HaloLift, 1, 1)
$ink = [Lab]::Min($core, $halo)
$ink.Save((Join-Path $out "ref3m_ink_$Tag.png"))
$col = [Lab]::GradientMap($ink, '0:1,3,2;0.08:13,29,24;0.5:100,153,136;0.75:159,219,209;0.85:180,231,227;0.92:208,241,240;1:255,255,255')
$full = New-Object System.Drawing.Bitmap $W, 952
$gg = [System.Drawing.Graphics]::FromImage($full); $gg.Clear([System.Drawing.Color]::Black)
$gg.DrawImage($col.ToBitmap(), 0, 120, $W, $H)
$full.Save((Join-Path $out "ref3m_copy_$Tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
[Lab]::Side((Join-Path $Refs 'ref3.png'), (Join-Path $out "ref3m_copy_$Tag.png"), (Join-Path $out "ref3m_side_$Tag.png"), 420, 'reference 3', "measured copy $Tag")

# Overlay: the traced target lines over the copy (they should sit on its strokes).
$ov = $col.ToBitmap(); $go = [System.Drawing.Graphics]::FromImage($ov); $go.SmoothingMode = 'AntiAlias'
foreach ($k in $RefLines.Keys) {
    $c = if ($RefLines[$k].fam -eq 'spoke') { [System.Drawing.Color]::FromArgb(220, 240, 120, 0) } else { [System.Drawing.Color]::FromArgb(220, 30, 90, 230) }
    $p = $RefLines[$k].pts
    $pf = [System.Drawing.PointF[]]@(for ($i = 0; $i -lt $p.Length; $i += 2) { New-Object System.Drawing.PointF ([float]$p[$i]), ([float]$p[$i + 1]) })
    $go.DrawCurve((New-Object System.Drawing.Pen $c, 3), $pf)
}
$ov.Save((Join-Path $out "ref3m_overlay_$Tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
