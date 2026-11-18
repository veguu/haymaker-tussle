# Draws the haymaker's SKETCH impact-frame pieces (kits-8e, 2026-11-18). The owner, after the abstract flipbooks: "the
# frames shoudlnt look like that, it should look like an actual impact. and for the fist, it should be a drawing thats
# very sketchy", with a reference: the two fighters as black ink silhouettes with ragged edges, cut through by white
# hairline streaks radiating from the hit, dense black speed lines streaming over the background from it, and a spiky
# black burst on the fist.
#
# Sheets are 1024 x 1024: four 512 x 512 frames in a 2 x 2 grid (the game steps ImageRectOffset through them). Seeded
# per frame, so the drawing is the same every time it is made.
#   impact_hatch.png  white hairlines radiating from the centre, dense: laid OVER black silhouettes on a white card they
#                     show only inside the bodies, so the bodies read as ink streaked by the blow (4 frames, redrawn)
#   impact_spikes.png a spiky burst: long thin spikes out from a small core (4 frames, opening out)
#   impact_fist.png   a very sketchy drawn fist, side on, knuckles to the right, ink lines and hatched shadow on a white
#                     fill (drawn in its real colours, not tinted), loose overlapping strokes that boil frame to frame
#   impact_mock.png   the fist-plunge card put together from these on a stand-in torso, to judge before uploading
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
function Argb([int]$a, [int]$r, [int]$g, [int]$b) {
	return [System.Drawing.Color]::FromArgb([Math]::Max(0, [Math]::Min(255, $a)), $r, $g, $b)
}
function Cell([int]$k) { return @((($k % 2) * $frame), ([Math]::Floor($k / 2) * $frame)) }

# a tapered spike: from radius r0 (a point) out to r1 (its base `w` wide) along angle a
function Fill-Spike($gfx, $brush, [double]$cx, [double]$cy, [double]$a, [double]$r0, [double]$r1, [double]$w) {
	$nx, $ny = -[Math]::Sin($a), [Math]::Cos($a)
	$tip = New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($a) * $r1), [float]($cy + [Math]::Sin($a) * $r1))
	$b1 = New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($a) * $r0 + $nx * $w / 2), [float]($cy + [Math]::Sin($a) * $r0 + $ny * $w / 2))
	$b2 = New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($a) * $r0 - $nx * $w / 2), [float]($cy + [Math]::Sin($a) * $r0 - $ny * $w / 2))
	$gfx.FillPolygon($brush, [System.Drawing.PointF[]]@($b1, $tip, $b2))
}

# HATCH: hundreds of white hairlines from near the centre outward, varying length and weight, a few broken
function Draw-Hatch($gfx, [int]$k) {
	$rng = New-Object System.Random(4000 + $k)
	$o = Cell $k
	$cx, $cy = ($o[0] + $frame / 2.0), ($o[1] + $frame / 2.0)
	$gfx.Clip = New-Object System.Drawing.Region((New-Object System.Drawing.RectangleF($o[0], $o[1], $frame, $frame)))
	for ($i = 0; $i -lt 420; $i++) {
		$a = $rng.NextDouble() * 2 * [Math]::PI
		$r0 = $frame * (0.02 + 0.25 * $rng.NextDouble())
		$r1 = $r0 + $frame * (0.15 + 0.6 * $rng.NextDouble())
		$w = 0.8 + 2.4 * [Math]::Pow($rng.NextDouble(), 3)
		$pen = New-Object System.Drawing.Pen((Argb (150 + [int](105 * $rng.NextDouble())) 255 255 255), [float]$w)
		$gfx.DrawLine($pen, [float]($cx + [Math]::Cos($a) * $r0), [float]($cy + [Math]::Sin($a) * $r0), [float]($cx + [Math]::Cos($a) * $r1), [float]($cy + [Math]::Sin($a) * $r1))
		$pen.Dispose()
	}
	$gfx.ResetClip()
}

# SPIKES: a ragged black-ink burst (drawn white, tinted by the card): long thin spikes of uneven length round a small
# core, the burst opening over the 4 frames
function Draw-Spikes($gfx, [int]$k) {
	$rng = New-Object System.Random(5000 + $k)
	$o = Cell $k
	$cx, $cy = ($o[0] + $frame / 2.0), ($o[1] + $frame / 2.0)
	$gfx.Clip = New-Object System.Drawing.Region((New-Object System.Drawing.RectangleF($o[0], $o[1], $frame, $frame)))
	$brush = New-Object System.Drawing.SolidBrush((Argb 255 255 255 255))
	$reach = $frame * (0.28 + 0.06 * $k)
	for ($i = 0; $i -lt 64; $i++) {
		$a = ($i / 64.0) * 2 * [Math]::PI + ($rng.NextDouble() - 0.5) * 0.08
		$long = $reach * (0.35 + 0.65 * [Math]::Pow($rng.NextDouble(), 0.7))
		Fill-Spike $gfx $brush $cx $cy $a 0 $long (6 + 10 * $rng.NextDouble())
	}
	$core = $frame * (0.06 + 0.01 * $k)
	$gfx.FillEllipse($brush, [float]($cx - $core), [float]($cy - $core), [float]($core * 2), [float]($core * 2))
	$brush.Dispose()
	$gfx.ResetClip()
}

# THE FIST, side on, knuckles to the right, the forearm off to the left. Its outline as Bezier pieces in a 0..1 box
# (x right, y down), then drawn LOOSE: each line several times with small set offsets and weights, overshooting a
# little, the way a quick ink sketch is; the shadow side hatched with diagonal hairlines; finger creases; a thumb.
function Map-Point([double]$x, [double]$y, [double]$ox, [double]$oy, [double]$s) {
	return New-Object System.Drawing.PointF([float]($ox + $x * $s), [float]($oy + $y * $s))
}
function Sketch-Bezier($gfx, $rng, $pts, [double]$ox, [double]$oy, [double]$s, [double]$weight, [int]$passes) {
	for ($p = 0; $p -lt $passes; $p++) {
		$j = 0.006 * ($p + 1)
		$q = @()
		foreach ($pt in $pts) {
			$q += Map-Point ($pt[0] + ($rng.NextDouble() - 0.5) * $j) ($pt[1] + ($rng.NextDouble() - 0.5) * $j) $ox $oy $s
		}
		$w = $weight * (0.55 + 0.7 * $rng.NextDouble())
		$pen = New-Object System.Drawing.Pen((Argb (170 + [int](85 * $rng.NextDouble())) 12 12 14), [float]$w)
		$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
		$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
		$gfx.DrawBezier($pen, $q[0], $q[1], $q[2], $q[3])
		$pen.Dispose()
	}
}
function Draw-Fist($gfx, [double]$ox, [double]$oy, [double]$s, [int]$k) {
	$rng = New-Object System.Random(6000 + $k)
	# the silhouette (one closed path) for the white fill and the hatching clip
	$outline = @(
		@(@(0.0, 0.30), @(0.15, 0.27), @(0.28, 0.24), @(0.36, 0.20)),  # forearm top to the wrist
		@(@(0.36, 0.20), @(0.50, 0.10), @(0.66, 0.06), @(0.80, 0.09)), # the back of the hand up to the knuckles
		@(@(0.80, 0.09), @(0.92, 0.10), @(0.99, 0.18), @(0.97, 0.30)), # round the knuckles
		@(@(0.97, 0.30), @(0.98, 0.40), @(0.95, 0.50), @(0.86, 0.54)), # the folded fingers' front
		@(@(0.86, 0.54), @(0.76, 0.60), @(0.62, 0.60), @(0.52, 0.56)), # under the fingers to the thumb's root
		@(@(0.52, 0.56), @(0.42, 0.62), @(0.30, 0.66), @(0.18, 0.66)), # the heel of the hand into the wrist
		@(@(0.18, 0.66), @(0.10, 0.66), @(0.04, 0.66), @(0.0, 0.66))   # the forearm's underside
	)
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath
	foreach ($b in $outline) {
		$path.AddBezier((Map-Point $b[0][0] $b[0][1] $ox $oy $s), (Map-Point $b[1][0] $b[1][1] $ox $oy $s), (Map-Point $b[2][0] $b[2][1] $ox $oy $s), (Map-Point $b[3][0] $b[3][1] $ox $oy $s))
	}
	$path.CloseFigure()
	$fill = New-Object System.Drawing.SolidBrush((Argb 255 246 246 242))
	$gfx.FillPath($fill, $path)
	$fill.Dispose()
	# hatched shadow: the lower half, diagonal hairlines clipped to the fist
	$gfx.SetClip($path)
	for ($i = 0; $i -lt 70; $i++) {
		$u = $i / 70.0
		$x0 = $ox + ($u * 1.3 - 0.2) * $s
		$pen = New-Object System.Drawing.Pen((Argb (90 + [int](90 * $rng.NextDouble())) 12 12 14), [float](1 + 1.6 * $rng.NextDouble()))
		$y0 = $oy + (0.38 + 0.06 * $rng.NextDouble()) * $s
		$gfx.DrawLine($pen, [float]$x0, [float]$y0, [float]($x0 - 0.16 * $s), [float]($y0 + 0.34 * $s))
		$pen.Dispose()
	}
	# a second, denser layer of hatching under the knuckles and along the heel (the darkest shadow)
	for ($i = 0; $i -lt 40; $i++) {
		$u = $i / 40.0
		$x0 = $ox + (0.45 + $u * 0.5) * $s
		$pen = New-Object System.Drawing.Pen((Argb 200 12 12 14), [float](1.2 + 1.2 * $rng.NextDouble()))
		$gfx.DrawLine($pen, [float]$x0, [float]($oy + 0.47 * $s), [float]($x0 + 0.05 * $s), [float]($oy + 0.62 * $s))
		$pen.Dispose()
	}
	$gfx.ResetClip()
	# the outline, loose
	foreach ($b in $outline) { Sketch-Bezier $gfx $rng $b $ox $oy $s 5.5 3 }
	# the folded fingers: four segments across the front, each a short curve
	foreach ($f in @(0.15, 0.25, 0.35, 0.45)) {
		Sketch-Bezier $gfx $rng @(@(0.80, ($f - 0.02)), @(0.88, ($f - 0.04)), @(0.95, ($f - 0.01)), @(0.98, ($f + 0.03))) $ox $oy $s 3 2
	}
	# the knuckles' tops: little humps along the back
	foreach ($n in @(0.62, 0.71, 0.80)) {
		Sketch-Bezier $gfx $rng @(@(($n - 0.05), 0.12), @(($n - 0.02), 0.06), @(($n + 0.03), 0.06), @(($n + 0.05), 0.12)) $ox $oy $s 2.5 2
	}
	# the thumb wrapped across the fingers, with its nail
	Sketch-Bezier $gfx $rng @(@(0.48, 0.50), @(0.58, 0.40), @(0.74, 0.38), @(0.86, 0.42)) $ox $oy $s 4.5 3
	Sketch-Bezier $gfx $rng @(@(0.86, 0.42), @(0.90, 0.46), @(0.86, 0.52), @(0.78, 0.52)) $ox $oy $s 4 2
	Sketch-Bezier $gfx $rng @(@(0.76, 0.42), @(0.80, 0.40), @(0.84, 0.42), @(0.84, 0.47)) $ox $oy $s 2.5 2
	# the wrist crease and a tendon on the forearm
	Sketch-Bezier $gfx $rng @(@(0.33, 0.24), @(0.31, 0.38), @(0.33, 0.52), @(0.30, 0.64)) $ox $oy $s 2.5 2
	Sketch-Bezier $gfx $rng @(@(0.05, 0.40), @(0.12, 0.38), @(0.20, 0.37), @(0.28, 0.38)) $ox $oy $s 2 1
	# motion lines off the back of the forearm
	for ($i = 0; $i -lt 7; $i++) {
		$y = $oy + (0.28 + 0.055 * $i) * $s
		$pen = New-Object System.Drawing.Pen((Argb 220 12 12 14), [float](2 + 2 * $rng.NextDouble()))
		$gfx.DrawLine($pen, [float]($ox - (0.08 + 0.25 * $rng.NextDouble()) * $s), [float]$y, [float]($ox - 0.01 * $s), [float]$y)
		$pen.Dispose()
	}
	$path.Dispose()
}


# ---- kits-8e pass 2: the owner pointed at the first three references: "the third one is pretty much what i want for the
# fist impact, and the second is good for the base impact. of course they should both be animated".

# THE BASE IMPACT (reference 2): a full-frame tonal burst, drawn in its real greys on an opaque card: a mid-grey ground,
# hundreds of dark and light streaks out from the hit, dark blots round the core, a white-hot core, grain over all.
function Draw-Base($gfx, [int]$k, [int]$seed) {
	$rng = New-Object System.Random($seed + $k)
	$o = Cell $k
	$cx = $o[0] + $frame / 2.0 + ($k % 2) * 6 - 3
	$cy = $o[1] + $frame / 2.0
	$gfx.Clip = New-Object System.Drawing.Region((New-Object System.Drawing.RectangleF($o[0], $o[1], $frame, $frame)))
	$ground = New-Object System.Drawing.SolidBrush((Argb 255 150 150 152))
	$gfx.FillRectangle($ground, [float]$o[0], [float]$o[1], [float]$frame, [float]$frame)
	$ground.Dispose()
	for ($i = 0; $i -lt 520; $i++) {
		$a = $rng.NextDouble() * 2 * [Math]::PI
		$r0 = $frame * 0.02 * $rng.NextDouble()
		$r1 = $frame * (0.25 + 0.6 * $rng.NextDouble())
		$w = 2 + 14 * [Math]::Pow($rng.NextDouble(), 2)
		if ($rng.NextDouble() -lt 0.5) { $tone = [int](10 + 60 * $rng.NextDouble()) } else { $tone = [int](200 + 55 * $rng.NextDouble()) }
		$brush = New-Object System.Drawing.SolidBrush((Argb (90 + [int](140 * $rng.NextDouble())) $tone $tone ([Math]::Min(255, $tone + 2))))
		Fill-Spike $gfx $brush $cx $cy $a $r1 $r0 $w
		$brush.Dispose()
	}
	# dark ink blots ringing the core (reference 2's black masses), set round it by turn
	for ($i = 0; $i -lt 9; $i++) {
		$a = ($i / 9.0) * 2 * [Math]::PI + $k * 0.3
		$r = $frame * (0.12 + 0.06 * $rng.NextDouble())
		$bw = $frame * (0.05 + 0.06 * $rng.NextDouble())
		$blot = New-Object System.Drawing.SolidBrush((Argb 200 8 8 10))
		$gfx.FillEllipse($blot, [float]($cx + [Math]::Cos($a) * $r - $bw), [float]($cy + [Math]::Sin($a) * $r - $bw * 0.6), [float]($bw * 2), [float]($bw * 1.2))
		$blot.Dispose()
	}
	$core = $frame * (0.07 + 0.012 * $k)
	$white = New-Object System.Drawing.SolidBrush((Argb 255 250 250 250))
	$gfx.FillEllipse($white, [float]($cx - $core), [float]($cy - $core), [float]($core * 2), [float]($core * 2))
	$white.Dispose()
	for ($i = 0; $i -lt 9000; $i++) {
		$x = $o[0] + $frame * $rng.NextDouble()
		$y = $o[1] + $frame * $rng.NextDouble()
		$v = [int](255 * $rng.NextDouble())
		$speck = New-Object System.Drawing.SolidBrush((Argb 55 $v $v $v))
		$gfx.FillRectangle($speck, [float]$x, [float]$y, 1.5, 1.5)
		$speck.Dispose()
	}
	$gfx.ResetClip()
}

# THE SWEEPS (reference 3): big curving brush strokes round the hit, thick in the middle and pointed at both ends,
# black cores with a soft CYAN edge (drawn in those colours), partial curves of different sizes, the set turning
function Draw-Sweep($gfx, [double]$cx, [double]$cy, [double]$radius, [double]$fromDeg, [double]$sweepDeg, [double]$w, $colour) {
	$steps = 30
	$outer = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	$inner = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	for ($i = 0; $i -le $steps; $i++) {
		$u = $i / [double]$steps
		$a = ($fromDeg + $sweepDeg * $u) * [Math]::PI / 180.0
		$r = $radius * (1 + 0.12 * $u)
		$half = $w * 0.5 * [Math]::Pow([Math]::Sin($u * [Math]::PI), 0.7)
		$outer.Add((New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($a) * ($r + $half)), [float]($cy + [Math]::Sin($a) * ($r + $half)))))
		$inner.Insert(0, (New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($a) * ($r - $half)), [float]($cy + [Math]::Sin($a) * ($r - $half)))))
	}
	$points = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	$points.AddRange($outer)
	$points.AddRange($inner)
	$brush = New-Object System.Drawing.SolidBrush($colour)
	$gfx.FillPolygon($brush, $points.ToArray())
	$brush.Dispose()
}
function Draw-Sweeps($gfx, [int]$k) {
	$rng = New-Object System.Random(7000 + $k)
	$o = Cell $k
	$cx = $o[0] + $frame * 0.55
	$cy = $o[1] + $frame * 0.5
	$gfx.Clip = New-Object System.Drawing.Region((New-Object System.Drawing.RectangleF($o[0], $o[1], $frame, $frame)))
	$turn = -24 * $k
	for ($i = 0; $i -lt 7; $i++) {
		$radius = $frame * (0.2 + 0.09 * $i + 0.03 * $rng.NextDouble())
		$from = $turn + 120 + $i * 33 + 30 * $rng.NextDouble()
		$sweep = 110 + 70 * $rng.NextDouble()
		$w = 14 + 22 * $rng.NextDouble()
		Draw-Sweep $gfx $cx $cy $radius $from $sweep ($w * 3.4) (Argb 40 120 230 225)
		Draw-Sweep $gfx $cx $cy $radius $from $sweep ($w * 2.2) (Argb 90 140 240 235)
		Draw-Sweep $gfx $cx $cy $radius $from $sweep $w (Argb 255 6 8 10)
	}
	$gfx.ResetClip()
}

# THE FIST (reference 3's ink mass): the fist's silhouette filled with black ink, its edge torn into spikes (short ones
# all round, long streaks thrown forward past the knuckles), streaks trailing back off the forearm, and a few white
# strokes inside so it still reads as a fist (the knuckle row, the thumb, the creases); redrawn every frame
function Draw-InkFist($gfx, [double]$ox, [double]$oy, [double]$s, [int]$k) {
	$rng = New-Object System.Random(8000 + $k)
	$outline = @(
		@(@(0.0, 0.30), @(0.15, 0.27), @(0.28, 0.24), @(0.36, 0.20)),
		@(@(0.36, 0.20), @(0.50, 0.10), @(0.66, 0.06), @(0.80, 0.09)),
		@(@(0.80, 0.09), @(0.92, 0.10), @(0.99, 0.18), @(0.97, 0.30)),
		@(@(0.97, 0.30), @(0.98, 0.40), @(0.95, 0.50), @(0.86, 0.54)),
		@(@(0.86, 0.54), @(0.76, 0.60), @(0.62, 0.60), @(0.52, 0.56)),
		@(@(0.52, 0.56), @(0.42, 0.62), @(0.30, 0.66), @(0.18, 0.66)),
		@(@(0.18, 0.66), @(0.10, 0.66), @(0.04, 0.66), @(0.0, 0.66))
	)
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath
	foreach ($b in $outline) {
		$path.AddBezier((Map-Point $b[0][0] $b[0][1] $ox $oy $s), (Map-Point $b[1][0] $b[1][1] $ox $oy $s), (Map-Point $b[2][0] $b[2][1] $ox $oy $s), (Map-Point $b[3][0] $b[3][1] $ox $oy $s))
	}
	$path.CloseFigure()
	$ink = New-Object System.Drawing.SolidBrush((Argb 255 6 6 8))
	$gfx.FillPath($ink, $path)
	$flat = $path.Clone()
	$flat.Flatten()
	$pts = $flat.PathPoints
	$mx = $ox + 0.6 * $s
	$my = $oy + 0.36 * $s
	for ($i = 0; $i -lt $pts.Length; $i += 2) {
		$p = $pts[$i]
		# the edge flows one way (reference 3): streaks trail BACK and a little up from the top and bottom edges, a few
		# sharp splinters fly forward off the knuckles, the rest of the edge only slightly ragged
		$out = [Math]::Atan2($p.Y - $my, $p.X - $mx)
		$front = [Math]::Cos($out)
		if ($front -gt 0.55) {
			if ($rng.NextDouble() -gt 0.7) { continue }
			$a = $out * 0.4 + ($rng.NextDouble() - 0.5) * 0.3
			$long = $s * (0.05 + 0.12 * $rng.NextDouble())
		} else {
			$a = [Math]::PI + ($p.Y - $my) / $s * 1.2 + ($rng.NextDouble() - 0.5) * 0.15
			$long = $s * (0.02 + 0.22 * [Math]::Pow($rng.NextDouble(), 1.5)) * (1 - [Math]::Max(0, $front))
		}
		$tip = New-Object System.Drawing.PointF([float]($p.X + [Math]::Cos($a) * $long), [float]($p.Y + [Math]::Sin($a) * $long))
		$nx = -[Math]::Sin($a)
		$ny = [Math]::Cos($a)
		$w = $s * (0.008 + 0.014 * $rng.NextDouble())
		$b1 = New-Object System.Drawing.PointF([float]($p.X + $nx * $w), [float]($p.Y + $ny * $w))
		$b2 = New-Object System.Drawing.PointF([float]($p.X - $nx * $w), [float]($p.Y - $ny * $w))
		$gfx.FillPolygon($ink, [System.Drawing.PointF[]]@($b1, $tip, $b2))
	}
	for ($i = 0; $i -lt 26; $i++) {
		$y = $oy + (0.27 + 0.4 * $rng.NextDouble()) * $s
		$x1 = $ox + 0.05 * $s
		$len = (0.15 + 0.45 * $rng.NextDouble()) * $s
		Fill-Spike $gfx $ink $x1 $y ([Math]::PI) 0 $len ($s * (0.01 + 0.025 * $rng.NextDouble()))
	}
	$strokes = @(
		@(@(0.62, 0.13), @(0.70, 0.10), @(0.80, 0.11), @(0.90, 0.15)),
		@(@(0.50, 0.50), @(0.60, 0.42), @(0.74, 0.40), @(0.86, 0.44)),
		@(@(0.86, 0.22), @(0.90, 0.21), @(0.94, 0.24), @(0.96, 0.28)),
		@(@(0.86, 0.33), @(0.90, 0.32), @(0.94, 0.35), @(0.95, 0.39))
	)
	foreach ($b in $strokes) {
		for ($p = 0; $p -lt 2; $p++) {
			$q = @()
			foreach ($pt in $b) { $q += Map-Point ($pt[0] + ($rng.NextDouble() - 0.5) * 0.01) ($pt[1] + ($rng.NextDouble() - 0.5) * 0.01) $ox $oy $s }
			$pen = New-Object System.Drawing.Pen((Argb (150 + [int](100 * $rng.NextDouble())) 245 245 245), [float]($s * (0.006 + 0.006 * $rng.NextDouble())))
			$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
			$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
			$gfx.DrawBezier($pen, $q[0], $q[1], $q[2], $q[3])
			$pen.Dispose()
		}
	}
	$ink.Dispose()
	$flat.Dispose()
	$path.Dispose()
}

$made = @()
foreach ($pair in @(@('impact_base_a.png', 9000), @('impact_base_b.png', 9100))) {
	$canvas = New-Sheet
	for ($k = 0; $k -lt 4; $k++) { Draw-Base $canvas.Gfx $k $pair[1] }
	$made += Save-Sheet $canvas $pair[0]
}
$canvas = New-Sheet
for ($k = 0; $k -lt 4; $k++) { Draw-Sweeps $canvas.Gfx $k }
$made += Save-Sheet $canvas 'impact_sweeps.png'
$canvas = New-Sheet
for ($k = 0; $k -lt 4; $k++) {
	$o = Cell $k
	$canvas.Gfx.Clip = New-Object System.Drawing.Region((New-Object System.Drawing.RectangleF($o[0], $o[1], $frame, $frame)))
	Draw-InkFist $canvas.Gfx ($o[0] + 70) ($o[1] + 110) 380 $k
	$canvas.Gfx.ResetClip()
}
$made += Save-Sheet $canvas 'impact_fist.png'
$canvas = New-Sheet
for ($k = 0; $k -lt 4; $k++) { Draw-Hatch $canvas.Gfx $k }
$made += Save-Sheet $canvas 'impact_hatch.png'

# MOCKS of the two moments, 4 frames across each (the animation), to judge before uploading
$baseA = [System.Drawing.Image]::FromFile((Join-Path $Out 'impact_base_a.png'))
$sweeps = [System.Drawing.Image]::FromFile((Join-Path $Out 'impact_sweeps.png'))
$fistImg = [System.Drawing.Image]::FromFile((Join-Path $Out 'impact_fist.png'))
foreach ($which in @('base', 'fist')) {
	$strip = New-Object System.Drawing.Bitmap(2400, 340, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$g = [System.Drawing.Graphics]::FromImage($strip)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$g.Clear([System.Drawing.Color]::Gray)
	for ($k = 0; $k -lt 4; $k++) {
		$x = $k * 600 + 4
		$y = 4
		$c = Cell $k
		$g.SetClip((New-Object System.Drawing.Rectangle($x, $y, 592, 332)))
		if ($which -eq 'base') {
			# the burst full frame, the two fighters as black blocks over it
			$g.DrawImage($baseA, (New-Object System.Drawing.Rectangle(($x - 4), ($y - 130), 600, 600)), $c[0], $c[1], 512, 512, [System.Drawing.GraphicsUnit]::Pixel)
			$ink = New-Object System.Drawing.SolidBrush((Argb 255 8 8 10))
			$g.FillRectangle($ink, ($x + 150), ($y + 120), 70, 150)
			$g.FillRectangle($ink, ($x + 210), ($y + 150), 110, 34)
			$g.FillRectangle($ink, ($x + 330), ($y + 90), 80, 170)
			$ink.Dispose()
		} else {
			# white card, the sweeps behind, the ink fist driving in
			$g.FillRectangle([System.Drawing.Brushes]::White, $x, $y, 592, 332)
			$g.DrawImage($sweeps, (New-Object System.Drawing.Rectangle(($x + 20), ($y - 170), 680, 680)), $c[0], $c[1], 512, 512, [System.Drawing.GraphicsUnit]::Pixel)
			$g.DrawImage($fistImg, (New-Object System.Drawing.Rectangle(($x - 30), ($y - 40), 480, 480)), $c[0], $c[1], 512, 512, [System.Drawing.GraphicsUnit]::Pixel)
		}
		$g.ResetClip()
	}
	$g.Dispose()
	$strip.Save((Join-Path $Out "impact_mock_$which.png"), [System.Drawing.Imaging.ImageFormat]::Png)
	$strip.Dispose()
}
$baseA.Dispose()
$sweeps.Dispose()
$fistImg.Dispose()
$made
