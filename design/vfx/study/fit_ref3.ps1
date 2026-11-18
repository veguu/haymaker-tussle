# Fits reference 3's traced target lines: a circle per line, a general conic (ellipse) per ring, the
# least-squares point the spokes' end tangents converge on, and draws the families over the reference.
param([string]$Refs)
. "$PSScriptRoot\load.ps1"
. "$PSScriptRoot\ref3_lines.ps1"
$out = Join-Path $PSScriptRoot 'out'

function Solve($A, $b) {      # Gaussian elimination; $A is n x n as nested arrays, $b length n
    $n = $b.Count
    $M = @(for ($i = 0; $i -lt $n; $i++) { ,([double[]](@($A[$i]) + @($b[$i]))) })
    for ($c = 0; $c -lt $n; $c++) {
        $p = $c
        for ($r = $c + 1; $r -lt $n; $r++) { $vr = $M[$r][$c]; $vp0 = $M[$p][$c]; if ([Math]::Abs($vr) -gt [Math]::Abs($vp0)) { $p = $r } }
        $t = $M[$c]; $M[$c] = $M[$p]; $M[$p] = $t
        for ($r = 0; $r -lt $n; $r++) {
            if ($r -eq $c) { continue }
            $f = $M[$r][$c] / $M[$c][$c]
            for ($k = $c; $k -le $n; $k++) { $M[$r][$k] -= $f * $M[$c][$k] }
        }
    }
    return @(for ($i = 0; $i -lt $n; $i++) { $M[$i][$n] / $M[$i][$i] })
}
function Zeros($n) { @(for ($i = 0; $i -lt $n; $i++) { ,([double[]](New-Object 'double[]' $n)) }) }
function Pts($l) { $p = $l.pts; for ($i = 0; $i -lt $p.Length; $i += 2) { ,@([double]$p[$i], [double]$p[$i + 1]) } }

"=== circle fit per line (centre, radius, rms) ==="
foreach ($k in $RefLines.Keys) {
    $P = @(Pts $RefLines[$k]); $n = $P.Count
    $A = Zeros 3; $b = [double[]](New-Object 'double[]' 3)
    foreach ($q in $P) { $row = @($q[0], $q[1], 1.0); $rhs = -($q[0] * $q[0] + $q[1] * $q[1])
        for ($i = 0; $i -lt 3; $i++) { for ($j = 0; $j -lt 3; $j++) { $A[$i][$j] += $row[$i] * $row[$j] }; $b[$i] += $row[$i] * $rhs } }
    $s = Solve $A $b; $cx = -$s[0] / 2; $cy = -$s[1] / 2; $r = [Math]::Sqrt($cx * $cx + $cy * $cy - $s[2])
    $rms = 0; foreach ($q in $P) { $d = [Math]::Sqrt(($q[0] - $cx) * ($q[0] - $cx) + ($q[1] - $cy) * ($q[1] - $cy)) - $r; $rms += $d * $d }
    "{0,-5} {1,-5} centre ({2,6:0},{3,6:0})  r {4,6:0}  rms {5:0.0}" -f $k, $RefLines[$k].fam, $cx, $cy, $r, [Math]::Sqrt($rms / $n)
}

"`n=== where the spokes sink: least-squares meeting point of their end tangents ==="
$A = Zeros 2; $b = [double[]](New-Object 'double[]' 2)
foreach ($k in $RefLines.Keys) {
    if ($RefLines[$k].fam -ne 'spoke') { continue }
    $P = @(Pts $RefLines[$k]); $e = $P[$P.Count - 1]; $f = $P[$P.Count - 2]
    $dx = $e[0] - $f[0]; $dy = $e[1] - $f[1]; $l = [Math]::Sqrt($dx * $dx + $dy * $dy); $nx = -$dy / $l; $ny = $dx / $l
    $A[0][0] += $nx * $nx; $A[0][1] += $nx * $ny; $A[1][0] += $nx * $ny; $A[1][1] += $ny * $ny
    $c = $nx * $e[0] + $ny * $e[1]; $b[0] += $nx * $c; $b[1] += $ny * $c
    "{0,-4} ends ({1:0},{2:0}) heading {3:0} deg" -f $k, $e[0], $e[1], ([Math]::Atan2($dy, $dx) * 180 / [Math]::PI)
}
$vp = Solve $A $b
$global:vp = $vp
"meeting point ({0:0}, {1:0})" -f $vp[0], $vp[1]
foreach ($k in $RefLines.Keys) {
    if ($RefLines[$k].fam -ne 'spoke') { continue }
    $P = @(Pts $RefLines[$k]); $e = $P[$P.Count - 1]; $f = $P[$P.Count - 2]
    $dx = $e[0] - $f[0]; $dy = $e[1] - $f[1]; $l = [Math]::Sqrt($dx * $dx + $dy * $dy)
    $miss = [Math]::Abs((-$dy * ($vp[0] - $e[0]) + $dx * ($vp[1] - $e[1])) / $l)
    "  {0,-4} misses it by {1:0} px" -f $k, $miss
}

"`n=== ring distances from the meeting point (near side large, far side small?) ==="
foreach ($k in $RefLines.Keys) {
    if ($RefLines[$k].fam -ne 'ring') { continue }
    $ds = foreach ($q in (Pts $RefLines[$k])) { [Math]::Sqrt(($q[0] - $vp[0]) * ($q[0] - $vp[0]) + ($q[1] - $vp[1]) * ($q[1] - $vp[1])) }
    $angs = foreach ($q in (Pts $RefLines[$k])) { [Math]::Atan2($q[1] - $vp[1], $q[0] - $vp[0]) * 180 / [Math]::PI }
    "{0,-5} distance {1:0}..{2:0}  angle {3:0}..{4:0} deg" -f $k, ($ds | Measure-Object -Minimum).Minimum, ($ds | Measure-Object -Maximum).Maximum, ($angs | Measure-Object -Minimum).Minimum, ($angs | Measure-Object -Maximum).Maximum
}

# Overlay: reference faded, spokes orange, rings blue, meeting point marked.
$ref = [Img]::Load((Join-Path $Refs 'ref3.png')).Crop(0, 62, 640, 356).Resize(1280, 712)
$bmp = $ref.ToBitmap(); $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 255, 255, 255))), 0, 0, 1280, 712)
$font = New-Object System.Drawing.Font 'Segoe UI', 12, ([System.Drawing.FontStyle]::Bold)
foreach ($k in $RefLines.Keys) {
    $col = if ($RefLines[$k].fam -eq 'spoke') { [System.Drawing.Color]::FromArgb(255, 240, 120, 0) } else { [System.Drawing.Color]::FromArgb(255, 30, 90, 230) }
    $pen = New-Object System.Drawing.Pen $col, 5
    $P = @(Pts $RefLines[$k]); $pf = [System.Drawing.PointF[]]($P | ForEach-Object { New-Object System.Drawing.PointF ([float]$_[0]), ([float]$_[1]) })
    $g.DrawCurve($pen, $pf)
    $m = $P[[int]($P.Count / 2)]; $g.DrawString($k, $font, (New-Object System.Drawing.SolidBrush $col), [float]$m[0] + 6, [float]$m[1] - 22)
    if ($RefLines[$k].fam -eq 'spoke') {
        $e = $P[$P.Count - 1]; $dash = New-Object System.Drawing.Pen $col, 2; $dash.DashStyle = 'Dash'
        $g.DrawLine($dash, [float]$e[0], [float]$e[1], [float]$vp[0], [float]$vp[1])
    }
}
$g.FillEllipse([System.Drawing.Brushes]::Red, [float]$vp[0] - 9, [float]$vp[1] - 9, 18, 18)
$g.DrawString('sinks to', $font, [System.Drawing.Brushes]::Red, [float]$vp[0] + 12, [float]$vp[1] - 10)
$bmp.Save((Join-Path $out 'ref3_lines_map.png'), [System.Drawing.Imaging.ImageFormat]::Png)
