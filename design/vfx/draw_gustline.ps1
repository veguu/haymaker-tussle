# Draws the Gustline VFX textures (design/VFX Style.md) into design/vfx/out/ as transparent PNGs.
# Run:  powershell -ExecutionPolicy Bypass -File design\vfx\draw_gustline.ps1
# Then upload the PNGs through Studio and put the ids in src/shared/Config/GustImages.luau.
#
# Each hard shape is two images: a BASE with the style's fixed colours baked in (navy ink, pale wind
# body, white edge) and an ACCENT that is white, to be tinted with the kit's colour in the game and
# laid over the base. Glint and mote are white with an ink outline (a tint leaves the outline dark).
# The scuff is a white mask, tinted ink in the game.

Add-Type -AssemblyName System.Drawing

$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $out | Out-Null

$INK = [Drawing.Color]::FromArgb(240, 20, 30, 66)
$BODY = [Drawing.Color]::FromArgb(255, 176, 205, 236)
$LIGHT = [Drawing.Color]::FromArgb(255, 226, 238, 252)
$WHITE = [Drawing.Color]::FromArgb(255, 255, 255, 255)

function New-Canvas([int]$size) {
    $bmp = New-Object Drawing.Bitmap $size, $size, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([Drawing.Color]::Transparent)
    return @{ bmp = $bmp; g = $g }
}

function Save-Canvas($canvas, [string]$name) {
    $path = Join-Path $out $name
    $canvas.g.Dispose()
    $canvas.bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $canvas.bmp.Dispose()
    "wrote $name"
}

# A band that follows a circle of radius $r about ($cx,$cy) from angle $a0 to $a1 (degrees), whose
# inner and outer edges are $r + inner(t) and $r + outer(t), t from 0 at $a0 to 1 at $a1.
function Fill-Band($g, [Drawing.Color]$colour, [double]$cx, [double]$cy, [double]$r, [double]$a0, [double]$a1, [scriptblock]$inner, [scriptblock]$outer, [int]$steps = 160) {
    $pts = New-Object 'System.Collections.Generic.List[Drawing.PointF]'
    for ($i = 0; $i -le $steps; $i++) {
        $t = $i / $steps
        $a = ($a0 + ($a1 - $a0) * $t) * [Math]::PI / 180
        $rr = $r + (& $outer $t)
        $pts.Add((New-Object Drawing.PointF ([single]($cx + [Math]::Cos($a) * $rr)), ([single]($cy + [Math]::Sin($a) * $rr))))
    }
    for ($i = $steps; $i -ge 0; $i--) {
        $t = $i / $steps
        $a = ($a0 + ($a1 - $a0) * $t) * [Math]::PI / 180
        $rr = $r + (& $inner $t)
        $pts.Add((New-Object Drawing.PointF ([single]($cx + [Math]::Cos($a) * $rr)), ([single]($cy + [Math]::Sin($a) * $rr))))
    }
    $brush = New-Object Drawing.SolidBrush $colour
    $g.FillPolygon($brush, $pts.ToArray())
    $brush.Dispose()
}

# NOTE: [Math]::Max(0, x) and Min(1, x) with whole-number literals pick the integer overload and round x,
# so every literal here is written 0.0 / 1.0.

# THE CRESCENT. Half-width along it: nothing at the tail (t = 0), swelling to the head, rounded off
# at the very end. The head is at the image's right, the tail curls round to the lower left.
$crescentHalf = {
    param($t)
    $h = 46 * [Math]::Pow($t, 1.35)
    if ($t -gt 0.9) { $u = ($t - 0.9) / 0.1; $h = $h * [Math]::Sqrt([Math]::Max(0.0, 1 - $u * $u)) }
    return $h
}
# (PowerShell names ignore case: the centre can't be $C, because the canvas is $c.)
$MID = 256; $R = 186; $A0 = 200; $A1 = 20   # sweeps clockwise on screen from lower-left, over the top, to the right

$c = New-Canvas 512
Fill-Band $c.g $INK $MID $MID $R $A0 $A1 { param($t) -1.3 * (& $crescentHalf $t) - 3 * [Math]::Min(1.0, $t * 6) } { param($t) (& $crescentHalf $t) + 1 }
Fill-Band $c.g $BODY $MID $MID $R $A0 $A1 { param($t) -0.85 * (& $crescentHalf $t) } { param($t) (& $crescentHalf $t) }
Fill-Band $c.g $LIGHT $MID $MID $R $A0 $A1 { param($t) -0.15 * (& $crescentHalf $t) } { param($t) (& $crescentHalf $t) }
Fill-Band $c.g $WHITE $MID $MID $R $A0 $A1 { param($t) 0.5 * (& $crescentHalf $t) } { param($t) (& $crescentHalf $t) }
Save-Canvas $c 'crescent_base.png'

$c = New-Canvas 512
Fill-Band $c.g $WHITE $MID $MID $R $A0 $A1 { param($t) -0.8 * (& $crescentHalf $t) } { param($t) -0.1 * (& $crescentHalf $t) }
Save-Canvas $c 'crescent_accent.png'

# THE RING. A hard line that is thick on one side (the right) and thins to a break on the other, a
# soft pale band outside it, ink outside and under the line.
$ringHalf = {
    param($t)
    $a = $t * 2 * [Math]::PI
    $w = 3 + 9 * [Math]::Pow(0.5 + 0.5 * [Math]::Cos($a), 2)
    $gap = [Math]::Min(1.0, [Math]::Abs([Math]::Sin(($a - [Math]::PI) / 2)) * 5)   # closes to nothing at the left
    return $w * $gap
}
$RR = 168

$c = New-Canvas 512
for ($k = 0; $k -le 16; $k++) {
    $alpha = [int](120 * [Math]::Pow(1 - $k / 16, 1.6))
    $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb($alpha, 226, 238, 252)), 4.5
    $rad = $RR + 14 + $k * 3.4
    $c.g.DrawEllipse($pen, [single]($MID - $rad), [single]($MID - $rad), [single]($rad * 2), [single]($rad * 2))
    $pen.Dispose()
}
Fill-Band $c.g $INK $MID $MID $RR 0 360 { param($t) -0.7 * (& $ringHalf $t) - 2 * [Math]::Min(1.0, (& $ringHalf $t)) } { param($t) 1.5 * (& $ringHalf $t) + 4 * [Math]::Min(1.0, (& $ringHalf $t)) } 240
Fill-Band $c.g $WHITE $MID $MID $RR 0 360 { param($t) -0.6 * (& $ringHalf $t) } { param($t) 0.6 * (& $ringHalf $t) } 240
Save-Canvas $c 'ring_base.png'

$c = New-Canvas 512
Fill-Band $c.g $WHITE $MID $MID $RR 0 360 { param($t) -1.7 * (& $ringHalf $t) - 2 * [Math]::Min(1.0, (& $ringHalf $t)) } { param($t) -0.7 * (& $ringHalf $t) - 2 * [Math]::Min(1.0, (& $ringHalf $t)) } 240
Save-Canvas $c 'ring_accent.png'

# THE GLINT: a thin four-point star.
function Star-Points([double]$cx, [double]$cy, [double]$long, [double]$waist) {
    $pts = @()
    for ($i = 0; $i -lt 8; $i++) {
        $a = $i * [Math]::PI / 4 - [Math]::PI / 2
        $rad = if ($i % 2 -eq 0) { $long } else { $waist }
        $pts += New-Object Drawing.PointF ([single]($cx + [Math]::Cos($a) * $rad)), ([single]($cy + [Math]::Sin($a) * $rad))
    }
    return $pts
}
$c = New-Canvas 256
$inkBrush = New-Object Drawing.SolidBrush $INK
$whiteBrush = New-Object Drawing.SolidBrush $WHITE
$c.g.FillPolygon($inkBrush, [Drawing.PointF[]](Star-Points 128 128 124 19))
$c.g.FillPolygon($whiteBrush, [Drawing.PointF[]](Star-Points 128 128 114 13))
Save-Canvas $c 'glint.png'

# THE MOTE: a small diamond.
$c = New-Canvas 128
$c.g.FillPolygon($inkBrush, [Drawing.PointF[]]@(
    (New-Object Drawing.PointF 64, 4), (New-Object Drawing.PointF 106, 64), (New-Object Drawing.PointF 64, 124), (New-Object Drawing.PointF 22, 64)))
$c.g.FillPolygon($whiteBrush, [Drawing.PointF[]]@(
    (New-Object Drawing.PointF 64, 18), (New-Object Drawing.PointF 94, 64), (New-Object Drawing.PointF 64, 110), (New-Object Drawing.PointF 34, 64)))
Save-Canvas $c 'mote.png'

# THE SCUFF: a white mask of broken arcs and a few short cracks, as left on the floor. Fixed numbers,
# so it is the same every time it is drawn.
$c = New-Canvas 512
$arcs = @(
    @(150, 10, 70, 9), @(162, 110, 55, 6), @(155, 200, 80, 11), @(170, 300, 40, 5),
    @(196, 40, 95, 7), @(205, 170, 60, 10), @(190, 255, 75, 6), @(214, 345, 50, 8),
    @(232, 95, 45, 5), @(228, 215, 35, 4)
)
foreach ($arc in $arcs) {
    $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(215, 255, 255, 255)), ([single]$arc[3])
    $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
    $rad = $arc[0]
    $c.g.DrawArc($pen, [single]($MID - $rad), [single]($MID - $rad), [single]($rad * 2), [single]($rad * 2), [single]$arc[1], [single]$arc[2])
    $pen.Dispose()
}
$cracks = @(@(25, 120, 205), @(80, 135, 240), @(150, 110, 190), @(205, 140, 236), @(262, 125, 215), @(318, 130, 244))
foreach ($crack in $cracks) {
    $a = $crack[0] * [Math]::PI / 180
    $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(200, 255, 255, 255)), 4
    $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [Drawing.Drawing2D.LineCap]::Triangle
    $c.g.DrawLine($pen, [single]($MID + [Math]::Cos($a) * $crack[1]), [single]($MID + [Math]::Sin($a) * $crack[1]), [single]($MID + [Math]::Cos($a + 0.06) * $crack[2]), [single]($MID + [Math]::Sin($a + 0.06) * $crack[2]))
    $pen.Dispose()
}
Save-Canvas $c 'scuff.png'

$inkBrush.Dispose(); $whiteBrush.Dispose()

# ---------------------------------------------------------------------------------------------------
# THE GLOW SET (2026-11-13, second pass). White on transparent, soft-edged, for ADDITIVE particles:
# the game tints them and stacks many, see-through, so they glow. A soft edge is drawn as the same
# shape several times, wide and faint first, narrow and solid last.

function White([int]$alpha) { return [Drawing.Color]::FromArgb($alpha, 255, 255, 255) }

# A soft round glow: many faint discs, each smaller, so it is brightest in the middle.
function Fill-Glow($g, [double]$cx, [double]$cy, [double]$radius, [int]$layers, [int]$alpha) {
    $brush = New-Object Drawing.SolidBrush (White $alpha)
    for ($i = 0; $i -lt $layers; $i++) {
        $rad = $radius * (1 - $i / $layers)
        $g.FillEllipse($brush, [single]($cx - $rad), [single]($cy - $rad), [single]($rad * 2), [single]($rad * 2))
    }
    $brush.Dispose()
}

$c = New-Canvas 256
Fill-Glow $c.g 128 128 126 42 9
Fill-Glow $c.g 128 128 30 10 22
Save-Canvas $c 'glow_soft.png'

# The crescent again, as light: a hot thin core with a wide soft falloff either side.
$c = New-Canvas 512
foreach ($layer in @(@(2.7, 22), @(2.1, 34), @(1.6, 58), @(1.1, 110), @(0.5, 255))) {
    $m = $layer[0]
    Fill-Band $c.g (White $layer[1]) $MID $MID $R $A0 $A1 { param($t) -$m * (& $crescentHalf $t) }.GetNewClosure() { param($t) $m * 0.8 * (& $crescentHalf $t) }.GetNewClosure()
}
Save-Canvas $c 'crescent_glow.png'

# The ring as light: a thin bright line, uneven and broken at one side, in a soft halo.
$c = New-Canvas 512
foreach ($layer in @(@(5.5, 16), @(3.8, 30), @(2.4, 64), @(1.0, 255))) {
    $m = $layer[0]
    Fill-Band $c.g (White $layer[1]) $MID $MID 196 0 360 { param($t) -$m * 0.55 * (& $ringHalf $t) }.GetNewClosure() { param($t) $m * 0.55 * (& $ringHalf $t) }.GetNewClosure() 240
}
Save-Canvas $c 'ring_glow.png'

# The burst ring: a ring made of short strokes pointing outward, uneven, like a splash seen from above.
$c = New-Canvas 512
$seed = 7
for ($i = 0; $i -lt 64; $i++) {
    $seed = ($seed * 73 + 41) % 1009
    $jitter = $seed / 1009.0
    $a = ($i + $jitter * 0.7) * 2 * [Math]::PI / 64
    $inner = 150 + 22 * $jitter
    $len = 26 + 62 * [Math]::Pow($jitter, 2)
    foreach ($pass in @(@(9, 40), @(3.5, 235))) {
        $pen = New-Object Drawing.Pen (White $pass[1]), ([single]$pass[0])
        $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [Drawing.Drawing2D.LineCap]::Triangle
        $c.g.DrawLine($pen, [single]($MID + [Math]::Cos($a) * $inner), [single]($MID + [Math]::Sin($a) * $inner), [single]($MID + [Math]::Cos($a) * ($inner + $len)), [single]($MID + [Math]::Sin($a) * ($inner + $len)))
        $pen.Dispose()
    }
}
Save-Canvas $c 'ring_burst.png'

# The flare: a hot middle with four long thin rays and four short ones between them.
$c = New-Canvas 512
Fill-Glow $c.g 256 256 150 40 7
Fill-Glow $c.g 256 256 46 12 26
$soft = New-Object Drawing.SolidBrush (White 70)
$hard = New-Object Drawing.SolidBrush (White 255)
$c.g.FillPolygon($soft, [Drawing.PointF[]](Star-Points 256 256 250 20))
$c.g.FillPolygon($hard, [Drawing.PointF[]](Star-Points 256 256 246 8))
$c.g.TranslateTransform(256, 256); $c.g.RotateTransform(45); $c.g.TranslateTransform(-256, -256)
$c.g.FillPolygon($soft, [Drawing.PointF[]](Star-Points 256 256 140 16))
$c.g.FillPolygon($hard, [Drawing.PointF[]](Star-Points 256 256 132 6))
$c.g.ResetTransform()
$soft.Dispose(); $hard.Dispose()
Save-Canvas $c 'flare.png'

# The mote as light: the diamond, in a small halo.
$c = New-Canvas 128
Fill-Glow $c.g 64 64 62 22 8
$hard = New-Object Drawing.SolidBrush (White 255)
$c.g.FillPolygon($hard, [Drawing.PointF[]]@(
    (New-Object Drawing.PointF 64, 14), (New-Object Drawing.PointF 90, 64), (New-Object Drawing.PointF 64, 114), (New-Object Drawing.PointF 38, 64)))
$hard.Dispose()
Save-Canvas $c 'mote_glow.png'
