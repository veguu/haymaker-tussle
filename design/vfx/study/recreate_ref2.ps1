# Practice copy of reference 2: a blotchy picture (ink blobs crowded in a ring round the hit, a
# grey field outside) -> strong outward zoom blur -> contrast pushed AFTER the blur in the ring ->
# hot white centre -> warm paper, grain. No threshold.
param([string]$Refs, [float]$Amount = 1.2, [float]$Ring0 = 50, [float]$Ring1 = 260, [float]$KPeak = 3.2,
      [float]$KOut = 0.9, [float]$Big = 0.25, [float]$HotR = 100, [float]$Hot = 0.7,
      [float]$InkCut = 0.36, [float]$OuterInk = 0.24, [float]$PaperCut = 0.26, [float]$FineGrain = 0.3,
      [float]$Sharp = 1.4, [int]$SharpR = 2, [int]$Seed = 4, [string]$Tag = 'v6')
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'; New-Item -ItemType Directory -Force $out | Out-Null
$W = 1032; $H = 774; $P = 260
$WP = $W + 2 * $P; $HP = $H + 2 * $P; $cx = 500 + $P; $cy = 538 + $P      # padded canvas

# 1. Blotchy picture: three octaves of value noise round mid grey, lighter to the top-right.
$src = [Img]::Solid($WP, $HP, 0.5, 0.5, 0.5)
[Lab]::Grain($src, $Big, 64, $Seed)
[Lab]::Grain($src, 0.3, 26, $Seed + 1)
[Lab]::Grain($src, 0.16, 9, $Seed + 2)
$light = New-Object System.Drawing.Bitmap $WP, $HP
$lg = [System.Drawing.Graphics]::FromImage($light)
$rect = New-Object System.Drawing.Rectangle 0, 0, $WP, $HP
$lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(95, 95, 95)), ([System.Drawing.Color]::FromArgb(175, 175, 175)), 330
$lg.FillRectangle($lb, $rect)
$src = [Lab]::Mix($src, [Img]::FromBitmap($light), 0.35)

# 2. Ink blobs: generous inside a ring round the hit, sparse outside; a few bare-paper patches.
$blobs = [Img]::Solid($WP, $HP, 0.5, 0.5, 0.5)
[Lab]::Grain($blobs, 0.5, 40, $Seed + 10)
[Lab]::Grain($blobs, 0.25, 15, $Seed + 11)
$ring = [Lab]::RadialShape([Img]::Solid($WP, $HP, 1, 1, 1), $cx, $cy, 90, 300, 1, -1, 0, 0)  # 1 in the ring
$inkRing = [Lab]::Multiply([Lab]::Levels($blobs, $InkCut + 0.02, $InkCut, 1), $ring)
$inkOuter = [Lab]::Levels($blobs, $OuterInk + 0.02, $OuterInk, 1)
$ink = [Lab]::Levels([Lab]::Mix($inkRing, $inkOuter, 0.5), 0, 0.5, 1)
$paperMask = [Lab]::Levels($blobs, 1 - $PaperCut - 0.02, 1 - $PaperCut, 1)
$src = [Lab]::MaskMix($src, [Img]::Solid($WP, $HP, 0.02, 0.02, 0.02), $ink)
$src = [Lab]::MaskMix($src, [Img]::Solid($WP, $HP, 0.97, 0.97, 0.97), $paperMask)
[Lab]::Grain($src, $FineGrain, 2.2, $Seed + 20)                       # before the blur: striations
$src.Crop($P, $P, $W, $H).Save((Join-Path $out "ref2_source_$Tag.png"))

# 3. Strong outward zoom blur; contrast pushed after it, strongest in the ring; hot centre.
$blur = [Lab]::ZoomOut($src, $cx, $cy, $Amount, 64)
$blur = [Lab]::RadialShape($blur, $cx, $cy, $Ring0, $Ring1, $KPeak, $KOut, $HotR, $Hot)
$blur = $blur.Crop($P, $P, $W, $H)
# Unsharp mask: the reference's streaks are crisp hairlines, not soft gradients.
$blur = [Lab]::Mix($blur, [Lab]::Soften($blur, $SharpR), -$Sharp)

# 4. Tone curve, paper colour, grain.
$tone = [Lab]::Levels($blur, 0.12, 0.88, 1.0)
$final = [Lab]::GradientMap($tone, '0:2,1,1;0.5:142,133,134;1:241,231,232')
[Lab]::Grain($final, 0.035, 1.6, 21)
$final.Save((Join-Path $out "ref2_copy_$Tag.png"))

[Lab]::Side((Join-Path $Refs 'ref2.png'), (Join-Path $out "ref2_copy_$Tag.png"), (Join-Path $out "ref2_side_$Tag.png"), 400, 'reference 2', "copy $Tag")
"--- copy stats"
[Lab]::Stats((Join-Path $out "ref2_copy_$Tag.png"), 0, 0, 0, 0)
