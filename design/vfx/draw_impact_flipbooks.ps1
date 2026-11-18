# Draws the haymaker's impact-frame FLIPBOOKS (kits-8e, 2026-11-18). The owner: the impact frames "should look more
# like a sketch", "shouldnt be still images and should be highly animated using flipbooks, just like they are in the
# references", with three reference stills: manga speed lines drawn as rough tapered ink strokes round a clear centre;
# a grainy, tonal radial burst with dark ink blots; and sweeping curved strokes with a soft cyan edge.
#
# Each sheet is 1024 x 1024: four frames of 512 x 512 in a 2 x 2 grid, read left to right, top to bottom
# (ImpactFrame steps ImageRectOffset through them). White on transparent, so a card tints them black, white or red.
# Every stroke comes from a seeded generator, the seed fixed per frame: the drawing is the same each time it is made.
#   impact_lines_a.png, impact_lines_b.png  8 frames of speed lines closing in, a new set of strokes every frame
#   impact_burst.png                         4 frames of a tonal burst opening out from the hit, with grain and blots
# Also writes impact_flipbooks_preview.png: every frame on black and on white, to look at before uploading.
param([string]$Out = (Join-Path $PSScriptRoot 'out'))

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null
$frame = 512
$sheet = 1024

function New-Sheet {
	$bmp = New-Object System.Drawing.Bitmap($sheet, $sheet, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$gfx = [System.Drawing.Graphics]::FromImage($bmp)
	$gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$gfx.Clear([System.Drawing.Color]::Transparent)
	return @{ Bmp = $bmp; Gfx = $gfx }
}

function Save-Sheet($canvas, [string]$name) {
	$canvas.Gfx.Dispose()
	$path = Join-Path $Out $name
	$canvas.Bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
	return $path
}

function White([int]$alpha) {
	return [System.Drawing.Color]::FromArgb([Math]::Max(0, [Math]::Min(255, $alpha)), 255, 255, 255)
}

# one rough ink stroke along a ray: from radius r0 to r1 at angle a, width w at its thick end, tapering to a point
# inward, its edges jittered (a hand-drawn, slightly broken line)
function Draw-Stroke($gfx, [double]$cx, [double]$cy, [double]$a, [double]$r0, [double]$r1, [double]$w, [int]$alpha, $rng) {
	$steps = 7
	$left = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	$right = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	$nx, $ny = -[Math]::Sin($a), [Math]::Cos($a)
	for ($i = 0; $i -le $steps; $i++) {
		$u = $i / [double]$steps
		$r = $r0 + ($r1 - $r0) * $u
		$half = $w * 0.5 * [Math]::Pow($u, 0.8) * (0.75 + 0.5 * $rng.NextDouble())
		$wobble = ($rng.NextDouble() - 0.5) * $w * 0.35
		$px = $cx + [Math]::Cos($a) * $r + $nx * $wobble
		$py = $cy + [Math]::Sin($a) * $r + $ny * $wobble
		$left.Add((New-Object System.Drawing.PointF([float]($px + $nx * $half), [float]($py + $ny * $half))))
		$right.Insert(0, (New-Object System.Drawing.PointF([float]($px - $nx * $half), [float]($py - $ny * $half))))
	}
	$points = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	$points.AddRange($left)
	$points.AddRange($right)
	$brush = New-Object System.Drawing.SolidBrush((White $alpha))
	$gfx.FillPolygon($brush, $points.ToArray())
	$brush.Dispose()
}

# SPEED LINES: dense rough strokes from past the frame's edge in toward the hit, leaving a clear centre that closes in
# over the 8 frames; thick wedges mixed with hairlines; some strokes broken in two (the sketch look).
function Draw-Lines($gfx, [int]$ox, [int]$oy, [int]$index) {
	$rng = New-Object System.Random(1000 + $index)
	$cx = $ox + $frame / 2.0
	$cy = $oy + $frame / 2.0
	$hole = $frame * (0.3 - 0.022 * $index) # the clear centre, closing in
	$outer = $frame * 0.75
	$count = 170
	$gfx.Clip = New-Object System.Drawing.Region((New-Object System.Drawing.RectangleF($ox, $oy, $frame, $frame)))
	for ($i = 0; $i -lt $count; $i++) {
		$a = ($i / [double]$count) * 2 * [Math]::PI + ($rng.NextDouble() - 0.5) * 0.05
		$inner = $hole * (0.85 + 0.6 * $rng.NextDouble())
		$kind = $rng.NextDouble()
		$w = if ($kind -lt 0.18) { 9 + 10 * $rng.NextDouble() } elseif ($kind -lt 0.55) { 3.5 + 3 * $rng.NextDouble() } else { 1.2 + 1.6 * $rng.NextDouble() }
		if ($rng.NextDouble() -lt 0.25) {
			$split = $inner + ($outer - $inner) * (0.35 + 0.3 * $rng.NextDouble())
			Draw-Stroke $gfx $cx $cy $a $inner ($split - 6) ($w * 0.8) 255 $rng
			Draw-Stroke $gfx $cx $cy $a ($split + 4) $outer $w 255 $rng
		} else {
			Draw-Stroke $gfx $cx $cy $a $inner $outer $w 255 $rng
		}
	}
	$gfx.ResetClip()
}

# THE BURST: a tonal radial explosion opening out from the hit: many soft streaks in greys, dark blots round the core
# (left transparent: the card's background shows through as ink), and a sprinkle of grain.
function Draw-Burst($gfx, [int]$ox, [int]$oy, [int]$index) {
	$rng = New-Object System.Random(2000 + $index)
	$cx = $ox + $frame / 2.0
	$cy = $oy + $frame / 2.0
	$open = 0.55 + 0.15 * $index
	$region = New-Object System.Drawing.Region((New-Object System.Drawing.RectangleF($ox, $oy, $frame, $frame)))
	$gfx.Clip = $region
	for ($i = 0; $i -lt 260; $i++) {
		$a = $rng.NextDouble() * 2 * [Math]::PI
		$r0 = $frame * 0.03 * $rng.NextDouble()
		$r1 = $frame * $open * (0.35 + 0.7 * $rng.NextDouble())
		$w = 3 + 22 * [Math]::Pow($rng.NextDouble(), 2)
		$alpha = 60 + [int](170 * $rng.NextDouble())
		Draw-Stroke $gfx $cx $cy $a $r1 $r0 $w $alpha $rng
	}
	# the white-hot core
	$core = $frame * (0.06 + 0.015 * $index)
	$brush = New-Object System.Drawing.SolidBrush((White 255))
	$gfx.FillEllipse($brush, [float]($cx - $core), [float]($cy - $core), [float]($core * 2), [float]($core * 2))
	$brush.Dispose()
	# grain: tiny specks, denser toward the middle
	for ($i = 0; $i -lt 2600; $i++) {
		$a = $rng.NextDouble() * 2 * [Math]::PI
		$r = $frame * 0.5 * [Math]::Sqrt($rng.NextDouble())
		$x = $cx + [Math]::Cos($a) * $r
		$y = $cy + [Math]::Sin($a) * $r
		$speck = New-Object System.Drawing.SolidBrush((White (40 + [int](120 * $rng.NextDouble()))))
		$gfx.FillRectangle($speck, [float]$x, [float]$y, 1.6, 1.6)
		$speck.Dispose()
	}
	$gfx.ResetClip()
}

# THE ARCS: long curved strokes sweeping round the hit, thick in the middle and pointed at both ends, each drawn
# three times wider and fainter under itself (the soft edge, tinted cyan by the card)
function Draw-Arc($gfx, [double]$cx, [double]$cy, [double]$radius, [double]$fromDeg, [double]$sweepDeg, [double]$w, [int]$alpha) {
	$steps = 24
	$outer = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	$inner = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	for ($i = 0; $i -le $steps; $i++) {
		$u = $i / [double]$steps
		$a = ($fromDeg + $sweepDeg * $u) * [Math]::PI / 180.0
		$r = $radius * (1 - 0.18 * $u) # spiralling in
		$half = $w * 0.5 * [Math]::Sin($u * [Math]::PI)
		$outer.Add((New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($a) * ($r + $half)), [float]($cy + [Math]::Sin($a) * ($r + $half)))))
		$inner.Insert(0, (New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($a) * ($r - $half)), [float]($cy + [Math]::Sin($a) * ($r - $half)))))
	}
	$points = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	$points.AddRange($outer)
	$points.AddRange($inner)
	$brush = New-Object System.Drawing.SolidBrush((White $alpha))
	$gfx.FillPolygon($brush, $points.ToArray())
	$brush.Dispose()
}

function Draw-Arcs($gfx, [int]$ox, [int]$oy, [int]$index) {
	# a few BIG strokes sweeping across the frame (reference 3), never rings round the middle: each lies on a large
	# circle whose centre is off to one side, so it crosses the frame as one swipe; the set turns frame to frame
	$rng = New-Object System.Random(3000 + $index)
	$cx = $ox + $frame / 2.0
	$cy = $oy + $frame / 2.0
	$gfx.Clip = New-Object System.Drawing.Region((New-Object System.Drawing.RectangleF($ox, $oy, $frame, $frame)))
	$turn = 28 * $index
	for ($i = 0; $i -lt 6; $i++) {
		$side = ($turn + $i * 61 + 25 * $rng.NextDouble()) * [Math]::PI / 180.0
		$radius = $frame * (0.55 + 0.6 * $rng.NextDouble())
		$px = $cx + [Math]::Cos($side) * $radius * 0.9
		$py = $cy + [Math]::Sin($side) * $radius * 0.9
		$from = ($side * 180.0 / [Math]::PI) + 180 - 35 - 20 * $rng.NextDouble()
		$sweep = 60 + 30 * $rng.NextDouble()
		$w = 18 + 26 * $rng.NextDouble()
		Draw-Arc $gfx $px $py $radius $from $sweep ($w * 2.6) 45
		Draw-Arc $gfx $px $py $radius $from $sweep ($w * 1.6) 100
		Draw-Arc $gfx $px $py $radius $from $sweep $w 255
	}
	$gfx.ResetClip()
}

$made = @()
foreach ($name in @('a', 'b')) {
	$canvas = New-Sheet
	for ($k = 0; $k -lt 4; $k++) {
		$index = if ($name -eq 'a') { $k } else { 4 + $k }
		Draw-Lines $canvas.Gfx (($k % 2) * $frame) ([Math]::Floor($k / 2) * $frame) $index
	}
	$made += Save-Sheet $canvas "impact_lines_$name.png"
}
$canvas = New-Sheet
for ($k = 0; $k -lt 4; $k++) { Draw-Burst $canvas.Gfx (($k % 2) * $frame) ([Math]::Floor($k / 2) * $frame) $k }
$made += Save-Sheet $canvas 'impact_burst.png'
# (impact_arcs: drawn but not used: as concentric rings it read as a target, as crossing sweeps as a star; the owner
# bans both "sun" shapes, so the figures' line boil carries the sketch look instead)

# the preview: each sheet on black (as drawn) and on white (tinted black), side by side
$preview = New-Object System.Drawing.Bitmap(2048, ($made.Count * 512), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pg = [System.Drawing.Graphics]::FromImage($preview)
$pg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
for ($i = 0; $i -lt $made.Count; $i++) {
	$img = [System.Drawing.Image]::FromFile($made[$i])
	$pg.FillRectangle([System.Drawing.Brushes]::Black, 0, $i * 512, 1024, 512)
	$pg.FillRectangle([System.Drawing.Brushes]::White, 1024, $i * 512, 1024, 512)
	# four frames across, 256 px each, on black
	for ($k = 0; $k -lt 4; $k++) {
		$src = New-Object System.Drawing.Rectangle((($k % 2) * $frame), ([Math]::Floor($k / 2) * $frame), $frame, $frame)
		$pg.DrawImage($img, (New-Object System.Drawing.Rectangle(($k * 256), ($i * 512 + 128), 256, 256)), $src, [System.Drawing.GraphicsUnit]::Pixel)
	}
	# the same four, inverted to black ink on white
	$matrix = New-Object System.Drawing.Imaging.ColorMatrix
	$matrix.Matrix00 = -1; $matrix.Matrix11 = -1; $matrix.Matrix22 = -1; $matrix.Matrix40 = 1; $matrix.Matrix41 = 1; $matrix.Matrix42 = 1
	$attributes = New-Object System.Drawing.Imaging.ImageAttributes
	$attributes.SetColorMatrix($matrix)
	for ($k = 0; $k -lt 4; $k++) {
		$dest = New-Object System.Drawing.Rectangle((1024 + $k * 256), ($i * 512 + 128), 256, 256)
		$pg.DrawImage($img, $dest, (($k % 2) * $frame), ([Math]::Floor($k / 2) * $frame), $frame, $frame, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
	}
	$img.Dispose()
}
$pg.Dispose()
$preview.Save((Join-Path $Out 'impact_flipbooks_preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$preview.Dispose()
$made
