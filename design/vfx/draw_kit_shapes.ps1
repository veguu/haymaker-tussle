# Draws the particle shapes the ability kits' effects add to the FxKit set (2026-11-15). White on
# transparent, hard edges, true points, 512 px (drawn at 1024 and scaled down for clean edges).
#   kit_claw.png      a thick crescent tapered to a point at both ends, thicker toward one end, with a
#                     thin second strand under it. Bulge at the top of the image.
#                     (Nyght "Light Moveset" f2830: very thick crescents with a crisp inner edge;
#                      Hazaze "Frigid Rush" f46: crescents built from strands, thick to thin.)
#   kit_shard.png     an ice crystal standing on the image's centre and pointing up, two facets.
#                     (DoubleCats "Sword Combat VFX" f287: hard-edged polygons with needle points.)
#   kit_leaf.png      a lens pointed at both ends, lying along X, fatter toward the back.
#                     (Divergent Vfx "Acheron Ultimate" f258: lens sparks; Nyght f3714: leaf shards.)
#   kit_pinwheel.png  a ring broken into five crescents, each thick at its head and running to a point.
#                     (xander22 "Projectiles VFX Pack" f474, f1706: a broken circle of crescent arcs.)
# Also writes kit_shapes_preview.png: all four on a mid-tone sheet, to look at before uploading.
param([string]$Out = (Join-Path $PSScriptRoot 'out'))

Add-Type -AssemblyName System.Drawing
$big = 1024
$small = 512
$white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)

function New-Canvas {
	$bmp = New-Object System.Drawing.Bitmap($big, $big, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$gfx = [System.Drawing.Graphics]::FromImage($bmp)
	$gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$gfx.Clear([System.Drawing.Color]::Transparent)
	return @{ Bmp = $bmp; Gfx = $gfx }
}

function Save-Canvas($canvas, [string]$name) {
	$canvas.Gfx.Dispose()
	$final = New-Object System.Drawing.Bitmap($small, $small, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$g2 = [System.Drawing.Graphics]::FromImage($final)
	$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$g2.Clear([System.Drawing.Color]::Transparent)
	$g2.DrawImage($canvas.Bmp, 0, 0, $small, $small)
	$g2.Dispose()
	$path = Join-Path $Out $name
	$final.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
	$final.Dispose()
	$canvas.Bmp.Dispose()
	return $path
}

function Fill-Points($gfx, $points, [int]$alpha) {
	$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alpha, 255, 255, 255))
	$gfx.FillPolygon($brush, [System.Drawing.PointF[]]$points)
	$brush.Dispose()
}

# A band along an arc: the outer edge walked forward, the inner edge back. `thick` is a script block
# giving the band's thickness at u (0 to 1 along it); `radiusAt` its outer radius at u.
function Get-Band([double]$cx, [double]$cy, [double]$fromDeg, [double]$toDeg, $radiusAt, $thick, [int]$steps) {
	$outer = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	$inner = New-Object System.Collections.Generic.List[System.Drawing.PointF]
	for ($i = 0; $i -le $steps; $i++) {
		$u = $i / [double]$steps
		$angle = ($fromDeg + ($toDeg - $fromDeg) * $u) * [Math]::PI / 180.0
		$radius = & $radiusAt $u
		$width = & $thick $u
		$cosA = [Math]::Cos($angle)
		$sinA = [Math]::Sin($angle)
		$outer.Add((New-Object System.Drawing.PointF([single]($cx + $radius * $cosA), [single]($cy - $radius * $sinA))))
		$inner.Add((New-Object System.Drawing.PointF([single]($cx + ($radius - $width) * $cosA), [single]($cy - ($radius - $width) * $sinA))))
	}
	$inner.Reverse()
	$outer.AddRange($inner)
	return $outer.ToArray()
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$made = @()

# --- Claw -------------------------------------------------------------------------------------------
$canvas = New-Canvas
$clawRadius = { param($u) 470.0 }
# Thickest about a third of the way along, a long thin tail after it, a true point at both ends.
$clawThick = { param($u) 150.0 * [Math]::Pow([Math]::Max(0.0, [Math]::Sin([Math]::PI * [Math]::Pow($u, 0.6))), 1.25) }
Fill-Points $canvas.Gfx (Get-Band 512.0 690.0 157.0 23.0 $clawRadius $clawThick 160) 255
# The second strand: thinner, a little shorter, tucked under the first.
$strandRadius = { param($u) 470.0 - 150.0 * [Math]::Pow([Math]::Max(0.0, [Math]::Sin([Math]::PI * [Math]::Pow($u, 0.6))), 1.25) - 26.0 }
$strandThick = { param($u) 26.0 * [Math]::Pow([Math]::Max(0.0, [Math]::Sin([Math]::PI * [Math]::Pow($u, 0.7))), 1.1) }
Fill-Points $canvas.Gfx (Get-Band 512.0 690.0 146.0 40.0 $strandRadius $strandThick 120) 190
$made += Save-Canvas $canvas 'kit_claw.png'

# --- Shard ------------------------------------------------------------------------------------------
$canvas = New-Canvas
$tip = New-Object System.Drawing.PointF(512, 30)
$foot = New-Object System.Drawing.PointF(512, 512)
$leftShoulder = New-Object System.Drawing.PointF(418, 300)
$rightShoulder = New-Object System.Drawing.PointF(592, 250)
$ridgeTop = New-Object System.Drawing.PointF(524, 250)
# Left facet: full. Right facet: dimmer, so the crystal reads as two faces.
Fill-Points $canvas.Gfx @($tip, $ridgeTop, $foot, $leftShoulder) 255
Fill-Points $canvas.Gfx @($tip, $rightShoulder, $foot, $ridgeTop) 150
# A small side crystal leaning off the foot.
Fill-Points $canvas.Gfx @((New-Object System.Drawing.PointF(660, 250)), (New-Object System.Drawing.PointF(600, 420)), $foot, (New-Object System.Drawing.PointF(560, 400))) 205
$made += Save-Canvas $canvas 'kit_shard.png'

# --- Leaf -------------------------------------------------------------------------------------------
$canvas = New-Canvas
$top = New-Object System.Collections.Generic.List[System.Drawing.PointF]
$bottom = New-Object System.Collections.Generic.List[System.Drawing.PointF]
for ($i = 0; $i -le 120; $i++) {
	$u = $i / 120.0
	$x = 40.0 + 944.0 * $u
	# Fattest about 40% of the way from the back; both ends are true points.
	$half = 118.0 * [Math]::Pow([Math]::Max(0.0, [Math]::Sin([Math]::PI * [Math]::Pow($u, 0.75))), 1.15)
	$top.Add((New-Object System.Drawing.PointF([single]$x, [single](512.0 - $half))))
	$bottom.Add((New-Object System.Drawing.PointF([single]$x, [single](512.0 + $half))))
}
$bottom.Reverse()
$top.AddRange($bottom)
Fill-Points $canvas.Gfx $top.ToArray() 255
$made += Save-Canvas $canvas 'kit_leaf.png'

# --- Pinwheel ---------------------------------------------------------------------------------------
$canvas = New-Canvas
for ($k = 0; $k -lt 5; $k++) {
	$start = 90.0 + 72.0 * $k
	# Each crescent runs 54 degrees anticlockwise from its head, drifting inward as it thins.
	$wheelRadius = { param($u) 452.0 - 34.0 * $u }
	$wheelThick = { param($u) 60.0 * [Math]::Pow([Math]::Max(0.0, [Math]::Sin([Math]::PI * [Math]::Pow($u, 0.45))), 1.1) }
	Fill-Points $canvas.Gfx (Get-Band 512.0 512.0 $start ($start + 54.0) $wheelRadius $wheelThick 90) 255
}
$made += Save-Canvas $canvas 'kit_pinwheel.png'

# --- Preview sheet ----------------------------------------------------------------------------------
$sheet = New-Object System.Drawing.Bitmap(1040, 280, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gs = [System.Drawing.Graphics]::FromImage($sheet)
$gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gs.Clear([System.Drawing.Color]::FromArgb(255, 58, 66, 84))
$slot = 0
foreach ($path in $made) {
	$img = [System.Drawing.Image]::FromFile($path)
	$gs.DrawImage($img, 10 + 258 * $slot, 12, 250, 250)
	$img.Dispose()
	$slot++
}
$gs.Dispose()
$previewPath = Join-Path $Out 'kit_shapes_preview.png'
$sheet.Save($previewPath, [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
$made + $previewPath
