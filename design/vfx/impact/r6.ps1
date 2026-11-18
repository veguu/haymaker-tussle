# R6 fighters as boxes, a perspective camera, and painter's-order rendering with GDI+.
# World: y up. A figure is built facing +x with its right side at +z, then rotated and moved.

function V3([double]$x, [double]$y, [double]$z) { return ,([double[]]@($x, $y, $z)) }
function VAdd($a, $b) { return ,([double[]]@(($a[0] + $b[0]), ($a[1] + $b[1]), ($a[2] + $b[2]))) }
function VSub($a, $b) { return ,([double[]]@(($a[0] - $b[0]), ($a[1] - $b[1]), ($a[2] - $b[2]))) }
function VMul($a, [double]$s) { return ,([double[]]@(($a[0] * $s), ($a[1] * $s), ($a[2] * $s))) }
function VDot($a, $b) { return $a[0] * $b[0] + $a[1] * $b[1] + $a[2] * $b[2] }
function VCross($a, $b) { return ,([double[]]@(($a[1] * $b[2] - $a[2] * $b[1]), ($a[2] * $b[0] - $a[0] * $b[2]), ($a[0] * $b[1] - $a[1] * $b[0]))) }
function VNorm($a) { $l = [Math]::Sqrt((VDot $a $a)); return ,([double[]]@(($a[0] / $l), ($a[1] / $l), ($a[2] / $l))) }
function RotY($v, [double]$deg) { $t = $deg * [Math]::PI / 180; $c = [Math]::Cos($t); $s = [Math]::Sin($t); return ,([double[]]@(($v[0] * $c + $v[2] * $s), $v[1], (-$v[0] * $s + $v[2] * $c))) }
function RotX($v, [double]$deg) { $t = $deg * [Math]::PI / 180; $c = [Math]::Cos($t); $s = [Math]::Sin($t); return ,([double[]]@($v[0], ($v[1] * $c - $v[2] * $s), ($v[1] * $s + $v[2] * $c))) }
function RotZ($v, [double]$deg) { $t = $deg * [Math]::PI / 180; $c = [Math]::Cos($t); $s = [Math]::Sin($t); return ,([double[]]@(($v[0] * $c - $v[1] * $s), ($v[0] * $s + $v[1] * $c), $v[2])) }

function Ident { return ,@((V3 1 0 0), (V3 0 1 0), (V3 0 0 1)) }
# An orthonormal basis whose y axis runs along $dir (for a limb pointing somewhere).
function AlongY($dir) {
    $y = VNorm $dir
    $hint = if ([Math]::Abs($y[2]) -lt 0.9) { V3 0 0 1 } else { V3 1 0 0 }
    $x = VNorm (VCross $y $hint); $z = VCross $x $y
    return ,@($x, $y, $z)
}
function NewBox($c, $size, $axes, [string]$part) {
    return @{ c = $c; ax = $axes; hs = [double[]]@(($size[0] / 2), ($size[1] / 2), ($size[2] / 2)); part = $part }
}

# R6 figure: torso 2x2x1, head 1.2 cube, arms and legs 1x2x1. Limb directions point from the joint
# toward the hand or foot. Arms hang from a joint 0.5 below the arm's top, legs from the hip.
function R6Figure($rArm, $lArm, $rLeg, $lLeg) {
    $boxes = @()
    $boxes += NewBox (V3 0 3 0) (V3 1 2 2) (Ident) 'torso'
    $boxes += NewBox (V3 0 4.6 0) (V3 1.2 1.2 1.2) (Ident) 'head'
    $boxes += NewBox (VAdd (V3 0 3.5 1.5) (VMul (VNorm $rArm) 0.5)) (V3 1 2 1) (AlongY $rArm) 'rarm'
    $boxes += NewBox (VAdd (V3 0 3.5 -1.5) (VMul (VNorm $lArm) 0.5)) (V3 1 2 1) (AlongY $lArm) 'larm'
    $boxes += NewBox (VAdd (V3 0 2 0.5) (VMul (VNorm $rLeg) 1)) (V3 1 2 1) (AlongY $rLeg) 'rleg'
    $boxes += NewBox (VAdd (V3 0 2 -0.5) (VMul (VNorm $lLeg) 1)) (V3 1 2 1) (AlongY $lLeg) 'lleg'
    return ,$boxes
}
# Rotate boxes about a pivot with a rotation scriptblock (vector -> vector), then move by $move.
function Xform($boxes, $pivot, [scriptblock]$rot, $move) {
    $out = @()
    foreach ($b in $boxes) {
        $c = VAdd (VAdd $pivot (& $rot (VSub $b.c $pivot))) $move
        $ax = @((& $rot $b.ax[0]), (& $rot $b.ax[1]), (& $rot $b.ax[2]))
        $out += @{ c = $c; ax = $ax; hs = $b.hs; part = $b.part }
    }
    return ,$out
}

# Camera looking from $pos at $look, rolled by $roll degrees; the world point $anchorW lands on screen
# at ($ax, $ay).
function NewCam($pos, $look, [double]$focal, [double]$roll, $anchorW, [double]$ax, [double]$ay) {
    $f = VNorm (VSub $look $pos); $r = VNorm (VCross (V3 0 1 0) $f); $u = VCross $f $r
    if ($roll -ne 0) {
        $t = $roll * [Math]::PI / 180; $c = [Math]::Cos($t); $s = [Math]::Sin($t)
        $r2 = VAdd (VMul $r $c) (VMul $u $s); $u = VAdd (VMul $r (-$s)) (VMul $u $c); $r = $r2
    }
    $cam = @{ pos = $pos; f = $f; r = $r; u = $u; focal = $focal; ox = 0.0; oy = 0.0 }
    $v = VSub $anchorW $pos
    $cam.ox = $ax - $focal * (VDot $v $r) / (VDot $v $f); $cam.oy = $ay + $focal * (VDot $v $u) / (VDot $v $f)
    return $cam
}
function Project($cam, $p) {
    $v = VSub $p $cam.pos; $zc = VDot $v $cam.f; if ($zc -lt 0.05) { $zc = 0.05 }
    return ,([double[]]@(($cam.ox + $cam.focal * (VDot $v $cam.r) / $zc), ($cam.oy - $cam.focal * (VDot $v $cam.u) / $zc), $zc))
}

# Render: visible faces far to near. Faces turned to the light are paper with a black outline,
# faces turned away are solid black: blocky R6 read in pure ink.
function RenderBoxes($boxes, $cam, [int]$imgW, [int]$imgH, $light, [float]$edge, [double]$litCut) {
    $faces = New-Object System.Collections.Generic.List[object]
    $L = VNorm $light
    foreach ($b in $boxes) {
        for ($i = 0; $i -lt 3; $i++) {
            foreach ($sg in 1, -1) {
                $n = VMul $b.ax[$i] $sg
                $fc = VAdd $b.c (VMul $n $b.hs[$i])
                if ((VDot $n (VSub $cam.pos $fc)) -le 0) { continue }
                $j = ($i + 1) % 3; $k = ($i + 2) % 3
                $ej = VMul $b.ax[$j] $b.hs[$j]; $ek = VMul $b.ax[$k] $b.hs[$k]
                $cs = @((VAdd (VAdd $fc $ej) $ek), (VAdd (VSub $fc $ej) $ek), (VSub (VSub $fc $ej) $ek), (VSub (VAdd $fc $ej) $ek))
                $pts = [System.Drawing.PointF[]]@($cs | ForEach-Object { $q = Project $cam $_; New-Object System.Drawing.PointF ([float]$q[0]), ([float]$q[1]) })
                $faces.Add(@((Project $cam $fc)[2], $pts, (VDot $n $L)))
            }
        }
    }
    $bmp = New-Object System.Drawing.Bitmap $imgW, $imgH
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::White)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), $edge; $pen.LineJoin = 'Round'
    foreach ($fa in ($faces | Sort-Object { $_[0] } -Descending)) {
        if ($fa[2] -gt $litCut) { $g.FillPolygon([System.Drawing.Brushes]::White, $fa[1]) } else { $g.FillPolygon([System.Drawing.Brushes]::Black, $fa[1]) }
        $g.DrawPolygon($pen, $fa[1])
    }
    $g.Dispose()
    return $bmp
}
