# Drawing-technique practice plates (study 15), all 2D pencil drawing, no 3D:
#   A tunnel in one-point perspective (rings closing up toward the VP, seams, contour hatching)
#   B circles in perspective: the square first (VP, diagonals, midlines), the ellipse through the midpoints
#   C five-point curvilinear grid: arcs through vanishing-point pairs, straight radials
#   D cross-contour lines on a plane, flat and bent into a VP (the dent)
#   E two forms kept distinct: value, line weight, overlap, a paper gap
param([string]$Only = '')
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'
$W = 1280; $H = 720
function P([double]$x, [double]$y) { New-Object System.Drawing.PointF ([float]$x), ([float]$y) }
function Canvas { $b = New-Object System.Drawing.Bitmap $W, $H; $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::White); return @($b, $g) }
function Finish($cv, [string]$name, [int]$seed) { $cv[1].Dispose(); [Pn]::Paper([Img]::FromBitmap($cv[0]), $seed, 0.6).Save((Join-Path $out "plate_$name.png")); "plate $name" }
function Note($g, [string]$s, [double]$x, [double]$y) { $g.DrawString($s, (New-Object System.Drawing.Font 'Segoe Print', 13), (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 60, 60, 70))), [float]$x, [float]$y) }
$paperWhite = [System.Drawing.Color]::White

# ---------------- A: tunnel ----------------
if (-not $Only -or $Only -eq 'tunnel') {
    $cv = Canvas; $g = $cv[1]; $rnd = New-Object System.Random 1
    $vx = 640; $vy = 330; $a = 760; $b = 470
    function Ring([double]$s, [double]$t0, [double]$t1, [int]$n) {
        return [System.Drawing.PointF[]]@(for ($i = 0; $i -le $n; $i++) {
            $t = $t0 + ($t1 - $t0) * $i / $n; $c = [Math]::Cos($t); $sn = [Math]::Sin($t)
            P ($vx + $s * $a * [Math]::Sign($c) * [Math]::Sqrt([Math]::Abs($c))) ($vy + $s * $b * [Math]::Sign($sn) * [Math]::Sqrt([Math]::Abs($sn)))
        })
    }
    function RingScale([int]$k) { return 1.0 / (1 + 0.32 * $k) }
    # construction: from the VP to the corners and beyond
    foreach ($c in @(@(0, 0), @(1280, 0), @(1280, 720), @(0, 720), @(640, 0), @(640, 720), @(0, 330), @(1280, 330))) { [Pn]::Ghost($g, (P $vx $vy), (P $c[0] $c[1]), 0.18, $rnd) }
    # contour hatching between the rings: strokes along the rings, more of them deeper in and on the left
    $seams = 20
    for ($k = 0; $k -lt 16; $k++) {
        for ($j = 0; $j -lt $seams; $j++) {
            $t0 = 2 * [Math]::PI * $j / $seams; $t1 = 2 * [Math]::PI * ($j + 1) / $seams
            $shade = 0.4 + 0.6 * [Math]::Max(0, -[Math]::Cos(($t0 + $t1) / 2))       # the left wall is in shade
            $m = [int](1 + $k * 0.45 * $shade + 2 * $shade)
            for ($q = 0; $q -lt $m; $q++) {
                $f = $rnd.NextDouble(); $s = (RingScale $k) * (1 - $f) + (RingScale ($k + 1)) * $f
                $u0 = $t0 + 0.04 + $rnd.NextDouble() * 0.06; $u1 = $t1 - 0.04 - $rnd.NextDouble() * 0.06
                [Pn]::Mark($g, (Ring $s $u0 $u1 8), [float](0.22 + 0.4 * $shade), 1.3, $rnd)
            }
        }
    }
    # seams to the VP, then the rings: the nearest heaviest
    for ($j = 0; $j -lt $seams; $j++) {
        $t = 2 * [Math]::PI * $j / $seams; $n0 = (Ring 1 $t $t 1)[0]; $n1 = (Ring (RingScale 16) $t $t 1)[0]
        [Pn]::Line($g, $n0, $n1, 0.42, 1.6, $rnd, 2, 1.5, 12)
    }
    for ($k = 0; $k -le 16; $k++) {
        $w = [float](0.95 - 0.04 * $k); $wd = [float](3.4 - 0.12 * $k); $st = if ($k -lt 2) { 3 } else { 2 }
        [Pn]::Path($g, (Ring (RingScale $k) 0 (2 * [Math]::PI) 140), $w, $wd, $rnd, $st, 1.8)
    }
    # the far opening: dark, cross-hatched
    $hole = Ring ((RingScale 16) * 0.98) 0 (2 * [Math]::PI) 24
    foreach ($ang in 30, 120, 75) { [Pn]::Hatch($g, $hole, $ang, 3.2, 0.85, 1.4, $rnd, 2, 6) }
    Note $g 'A  one-point tunnel: rings at r0 * d / (d + k*s), seams to the VP, contour hatching' 20 680
    Finish $cv 'tunnel' 11
}

# ---------------- B: circles in perspective ----------------
if (-not $Only -or $Only -eq 'ellipse') {
    $cv = Canvas; $g = $cv[1]; $rnd = New-Object System.Random 2
    $vp = P 300 300
    [Pn]::Line($g, (P 0 300), (P 1280 300), 0.3, 1.2, $rnd, 1, 0, 0)
    Note $g 'horizon' 20 270; Note $g 'VP' 285 305
    $walls = @(
        @{ q = @((P 700 180), (P 900 120), (P 900 520), (P 700 446.7)); lbl = 'a wall square: minor axis toward the VP' },
        @{ q = @((P 570.6 500), (P 805.9 500), (P 1160 640), (P 760 640)); lbl = 'a floor square' }
    )
    foreach ($sq in $walls) {
        $q = [System.Drawing.PointF[]]$sq.q
        foreach ($c in $q) { [Pn]::Ghost($g, $vp, $c, 0.2, $rnd) }                        # lines to the VP
        [Pn]::Ghost($g, $q[0], $q[2], 0.3, $rnd); [Pn]::Ghost($g, $q[1], $q[3], 0.3, $rnd)    # diagonals -> centre
        $Hm = [Pn]::Homography($q)
        [Pn]::Path($g, ([Pn]::MapLine($Hm, 0.5, -0.05, 0.5, 1.05, 4)), 0.3, 1.1, $rnd, 1, 0)   # midlines
        [Pn]::Path($g, ([Pn]::MapLine($Hm, -0.05, 0.5, 1.05, 0.5, 4)), 0.3, 1.1, $rnd, 1, 0)
        for ($i = 0; $i -lt 4; $i++) { [Pn]::Line($g, $q[$i], $q[($i + 1) % 4], 0.6, 2, $rnd, 2, 1.2, 10) }
        [Pn]::Path($g, ([Pn]::MapEllipse($Hm, 0.5, 0.5, 0.5, 0.5, 0, 2 * [Math]::PI, 120)), 0.95, 2.6, $rnd, 3, 1.3)
        $mid = [Pn]::Map($Hm, 0.5, 0.5); $g.FillEllipse([System.Drawing.Brushes]::Black, $mid.X - 3, $mid.Y - 3, 6, 6)
    }
    Note $g 'B  the square first; its diagonals give the centre; the ellipse touches the 4 midpoints' 20 680
    Note $g '(the circle''s centre is not the ellipse''s centre: the near half is bigger)' 20 650
    Finish $cv 'ellipse' 12
}

# ---------------- C: five-point curvilinear grid ----------------
if (-not $Only -or $Only -eq 'fisheye') {
    $cv = Canvas; $g = $cv[1]; $rnd = New-Object System.Random 3
    $cx = 640; $cy = 350; $R = 320
    $N = P $cx ($cy - $R); $S = P $cx ($cy + $R); $E = P ($cx + $R) $cy; $Wp = P ($cx - $R) $cy
    for ($i = 0; $i -lt 24; $i++) { $t = 2 * [Math]::PI * $i / 24; [Pn]::Ghost($g, (P $cx $cy), (P ($cx + $R * [Math]::Cos($t)) ($cy + $R * [Math]::Sin($t))), 0.28, $rnd) }  # depth lines: straight
    foreach ($deg in -75, -60, -45, -30, -15, 0, 15, 30, 45, 60, 75) {
        $x0 = $R * [Math]::Tan($deg * [Math]::PI / 360)                                    # equal angles -> stereographic spacing
        $wgt = [float](0.45 + 0.4 * (1 - [Math]::Abs($deg) / 90))
        [Pn]::Path($g, ([Pn]::Arc($N, $S, [float](-$x0), 60)), $wgt, 1.8, $rnd, 2, 1.2)     # verticals: arcs through N and S
        [Pn]::Path($g, ([Pn]::Arc($E, $Wp, [float](-$x0), 60)), $wgt, 1.8, $rnd, 2, 1.2)    # horizontals: arcs through E and W
    }
    [Pn]::Path($g, ([Pn]::Arc($N, $S, [float]$R, 80)), 0.9, 3, $rnd, 3, 1.5); [Pn]::Path($g, ([Pn]::Arc($S, $N, [float]$R, 80)), 0.9, 3, $rnd, 3, 1.5)
    foreach ($v in @($N, $S, $E, $Wp, (P $cx $cy))) { $g.FillEllipse([System.Drawing.Brushes]::Black, $v.X - 4, $v.Y - 4, 8, 8) }
    Note $g 'C  five-point fisheye: every straight line becomes an arc through its two VPs; lines through the centre stay straight' 20 680
    Finish $cv 'fisheye' 13
}

# ---------------- D: cross-contours, flat and bent into a VP ----------------
if (-not $Only -or $Only -eq 'dent') {
    $cv = Canvas; $g = $cv[1]; $rnd = New-Object System.Random 4
    foreach ($panel in 0, 1) {
        $ox = 640 * $panel
        $q = [System.Drawing.PointF[]]@((P ($ox + 90) 120), (P ($ox + 560) 80), (P ($ox + 575) 620), (P ($ox + 75) 600))
        $Hm = [Pn]::Homography($q); $c = [Pn]::Map($Hm, 0.5, 0.48)
        $k = if ($panel -eq 0) { 0 } else { 0.72 }; $Rp = 165
        function Draw($pts, [float]$wt, [float]$wd, [int]$st) { [Pn]::Path($g, ([Pn]::PullPath($pts, $c.X, $c.Y, [float]$k, [float]$Rp)), $wt, $wd, $rnd, $st, 1.3) }
        for ($i = 1; $i -lt 10; $i++) { $t = $i / 10; Draw ([Pn]::MapLine($Hm, $t, 0, $t, 1, 40)) 0.42 1.5 2; Draw ([Pn]::MapLine($Hm, 0, $t, 1, $t, 40)) 0.42 1.5 2 }
        if ($panel -eq 1) {
            foreach ($rr in 0.04, 0.08, 0.13, 0.19, 0.26, 0.34) { Draw ([Pn]::MapEllipse($Hm, 0.5, 0.48, $rr, $rr, 0, 2 * [Math]::PI, 90)) ([float](0.75 - $rr)) 1.8 2 }
            for ($j = 0; $j -lt 16; $j++) { $t = 2 * [Math]::PI * $j / 16; Draw ([Pn]::MapLine($Hm, 0.5, 0.48, (0.5 + 0.4 * [Math]::Cos($t)), (0.48 + 0.4 * [Math]::Sin($t)), 30)) 0.35 1.2 1 }
            for ($m = 0; $m -lt 260; $m++) {                                                  # shade in the hollow, along the rings
                $rr = 0.3 * [Math]::Sqrt($rnd.NextDouble()); $t0 = $rnd.NextDouble() * 6.283; $len = 0.3 + 0.5 * $rnd.NextDouble()
                $pts = [Pn]::PullPath(([Pn]::MapEllipse($Hm, 0.5, 0.48, $rr, $rr, $t0, ($t0 + $len), 8)), $c.X, $c.Y, [float]$k, [float]$Rp)
                [Pn]::Mark($g, $pts, [float](0.65 - 1.6 * $rr), 1.2, $rnd)
            }
        }
        for ($i = 0; $i -lt 4; $i++) { [Pn]::Path($g, ([Pn]::PullPath(@($q[$i], $q[($i + 1) % 4]), $c.X, $c.Y, [float]$k, [float]$Rp)), 0.9, 2.8, $rnd, 3, 1.5) }
        Note $g $(if ($panel -eq 0) { 'flat: cross-contours straight and even' } else { 'bent into the VP: lines bow in, rings close up, seams run in' }) ($ox + 40) 650
    }
    Finish $cv 'dent' 14
}

# ---------------- E: two forms kept distinct ----------------
if (-not $Only -or $Only -eq 'overlap') {
    $cv = Canvas; $g = $cv[1]; $rnd = New-Object System.Random 5
    $front = [System.Drawing.PointF[]]@((P 330 110), (P 900 90), (P 890 650), (P 345 640)); $side = [System.Drawing.PointF[]]@((P 900 90), (P 1060 140), (P 1050 600), (P 890 650))
    $Hm = [Pn]::Homography($front)
    for ($i = 1; $i -lt 8; $i++) { $t = $i / 8; [Pn]::Path($g, ([Pn]::MapLine($Hm, 0, $t, 1, $t, 20)), 0.3, 1.3, $rnd, 1, 1) }   # light form: thin cross-contours
    [Pn]::Hatch($g, $side, 75, 9, 0.35, 1.4, $rnd, 4, 5)
    foreach ($f in @($front, $side)) { for ($i = 0; $i -lt 4; $i++) { [Pn]::Line($g, $f[$i], $f[($i + 1) % 4], 0.7, 2.2, $rnd, 2, 1.3, 12) } }
    $ft = [System.Drawing.PointF[]]@((P -20 250), (P 470 300), (P 520 285), (P -20 215)); $fs = [System.Drawing.PointF[]]@((P -20 250), (P 470 300), (P 470 520), (P -20 560))
    foreach ($f in @($ft, $fs)) { $g.FillPolygon([System.Drawing.Brushes]::White, $f) }                                       # the dark form covers what is behind it
    foreach ($f in @($ft, $fs)) { for ($i = 0; $i -lt 4; $i++) { [Pn]::Line($g, $f[$i], $f[($i + 1) % 4], 1, 14, $paperWhite, $rnd, 1, 0, 0) } }   # paper gap round it
    [Pn]::Hatch($g, $fs, 4, 5, 0.75, 1.6, $rnd, 4, 3); [Pn]::Hatch($g, $fs, 62, 7, 0.6, 1.4, $rnd, 4, 4); [Pn]::Hatch($g, $ft, -8, 9, 0.4, 1.3, $rnd, 3, 4)
    foreach ($f in @($ft, $fs)) { for ($i = 0; $i -lt 4; $i++) { [Pn]::Line($g, $f[$i], $f[($i + 1) % 4], 1, 3.6, $rnd, 3, 1.6, 14) } }
    Note $g 'E  distinct forms: opposite values, the heaviest line on the front form, a paper gap, lines behind stop at it' 20 680
    Finish $cv 'overlap' 15
}
