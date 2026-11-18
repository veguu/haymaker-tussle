# Reference 2, second approach: a few big ink masses close to the hot centre, broad paper rays cut
# through them, a lighter brushed field outside; the streaks bend slightly (twisted zoom blur).
param([string]$Refs, [int]$Seed = 4, [float]$Amount = 1.2, [float]$Twist = 0.22, [int]$BlobCell = 90,
      [float]$InkCut = 0.36, [float]$InkIn = 30, [float]$InkOut = 230, [float]$KPeak = 2.8, [float]$KOut = 0.55,
      [float]$Ring0 = 40, [float]$Ring1 = 210, [float]$HotR = 95, [float]$Hot = 0.85, [int]$Rays = 7,
      [float]$RayMin = 1.2, [float]$RayMax = 3.5, [float]$Sharp = 1.2, [float]$MidTex = 0.26, [float]$RayBreak = 0.35, [float]$Lobes = 0.35, [int]$AngCells = 40, [int]$Boil = 0, [float]$RadCell = 0.32, [float]$BlobShift = 0, [float]$RayReach = 1400, [string]$Tag = 'v8')
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'
$IW = 1032; $IH = 774; $P = 300
$WP = $IW + 2 * $P; $HP = $IH + 2 * $P; $cx = 500 + $P; $cy = 538 + $P

function InkBurst([int]$sd, [float]$amount, [float]$inkOut, [float]$hotR) {
    $src = [Img]::Solid($WP, $HP, 0.5, 0.5, 0.5)
    [Lab]::Grain($src, 0.22, 64, $sd); [Lab]::Grain($src, $MidTex * 0.5, 9, $sd + 2 + $Boil)
    [Lab]::PolarGrainShift($src, $cx, $cy, $MidTex, 220, 0.12, $sd + 1, ($BlobShift * $RadCell / 0.12)); [Lab]::PolarGrain($src, $cx, $cy, $MidTex * 0.6, 600, 0.05, $sd + 3 + $Boil)
    $lt = New-Object System.Drawing.Bitmap $WP, $HP; $lg = [System.Drawing.Graphics]::FromImage($lt)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $WP, $HP
    $lgb = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(105, 105, 105)), ([System.Drawing.Color]::FromArgb(200, 200, 200)), 330
    $lg.FillRectangle($lgb, $rect); $lg.Dispose()
    $src = [Lab]::Mix($src, [Img]::FromBitmap($lt), 0.45)
    # big ink masses: low-frequency blobs, only in a ring close to the centre
    $blobs = [Img]::Solid($WP, $HP, 0.5, 0.5, 0.5)
    [Lab]::PolarGrainShift($blobs, $cx, $cy, 0.5, $AngCells, $RadCell, $sd + 10, $BlobShift); [Lab]::PolarGrainShift($blobs, $cx, $cy, 0.25, ($AngCells * 3), ($RadCell * 0.5), $sd + 11, ($BlobShift * 2))
    [Lab]::Grain($blobs, 0.15, 7, $sd + 12)
    [Lab]::PolarGrain($blobs, $cx, $cy, $Lobes, 7, 3.0, $sd + 13)          # a few lobes reaching out, gaps between
    $ring = [Lab]::RadialShape([Img]::Solid($WP, $HP, 1, 1, 1), $cx, $cy, $InkIn, $inkOut, 1, -1, 0, 0)
    $ink = [Lab]::Multiply([Lab]::Levels($blobs, $InkCut + 0.02, $InkCut, 1), [Lab]::Levels($ring, 0.3, 0.6, 1))
    $src = [Lab]::MaskMix($src, [Img]::Solid($WP, $HP, 0.02, 0.02, 0.02), $ink)
    # broad paper rays from the centre, cut through everything
    $rb = New-Object System.Drawing.Bitmap $WP, $HP; $rg = [System.Drawing.Graphics]::FromImage($rb); $rg.SmoothingMode = 'AntiAlias'; $rg.Clear([System.Drawing.Color]::Black)
    $rnd = New-Object System.Random $sd
    $a0 = $rnd.NextDouble() * 360
    for ($k = 0; $k -lt $Rays; $k++) {
        $ang = ($a0 + $k * 360 / $Rays + ($rnd.NextDouble() - 0.5) * 30) * [Math]::PI / 180
        $hw = ($RayMin + $rnd.NextDouble() * ($RayMax - $RayMin)) * [Math]::PI / 180
        # a log-spiral wedge (angle grows with ln r at the blur's twist rate) so the twisted blur keeps it
        $side1 = @(); $side2 = @()
        foreach ($rr in (@(12, 20, 35, 60, 100, 170, 280, 450, 700, 1000, 1400) | Where-Object { $_ -le [Math]::Max(60, $RayReach) })) {
            $th = $ang + $Twist * [Math]::Log($rr / 12.0); $hww = $hw * [Math]::Min(1, $rr / 60.0)
            $side1 += New-Object System.Drawing.PointF ([float]($cx + $rr * [Math]::Cos($th - $hww))), ([float]($cy + $rr * [Math]::Sin($th - $hww)))
            $side2 = @(New-Object System.Drawing.PointF ([float]($cx + $rr * [Math]::Cos($th + $hww))), ([float]($cy + $rr * [Math]::Sin($th + $hww)))) + $side2
        }
        $pts = $side1 + $side2
        $v = 170 + $rnd.Next(0, 86)
        $rg.FillPolygon((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($v, $v, $v))), [System.Drawing.PointF[]]$pts)
    }
    $rg.Dispose()
    # ragged rays: the wedge mask broken up by blotchy noise (dry brush)
    $rag = [Img]::Solid($WP, $HP, 0.5, 0.5, 0.5); [Lab]::Grain($rag, 0.5, 30, $sd + 30 + $Boil); [Lab]::Grain($rag, 0.3, 8, $sd + 31 + $Boil)
    $rayMask = [Lab]::Multiply([Img]::FromBitmap($rb), [Lab]::Levels($rag, $RayBreak - 0.08, $RayBreak + 0.08, 1))
    $src = [Lab]::MaskMix($src, [Img]::Solid($WP, $HP, 0.97, 0.97, 0.97), $rayMask)
    [Lab]::Grain($src, 0.3, 2.2, $sd + 20 + $Boil)
    $b = [Lab]::ZoomOutTwist($src, $cx, $cy, $amount, $Twist, 64)
    $b = [Lab]::RadialShape($b, $cx, $cy, $Ring0, $Ring1, $KPeak, $KOut, $hotR, $Hot)
    $b = $b.Crop($P, $P, $IW, $IH)
    $b = [Lab]::Mix($b, [Lab]::Soften($b, 2), -$Sharp)
    return [Lab]::Levels($b, 0.1, 0.9, 1.0)
}

if ($Refs) {
    $tone = InkBurst $Seed $Amount $InkOut $HotR
    $final = [Lab]::GradientMap($tone, '0:2,1,1;0.5:142,133,134;1:241,231,232')
    [Lab]::Grain($final, 0.035, 1.6, 21)
    $final.Save((Join-Path $out "ref2_copy_$Tag.png"))
    [Lab]::Side((Join-Path $Refs 'ref2.png'), (Join-Path $out "ref2_copy_$Tag.png"), (Join-Path $out "ref2_side_$Tag.png"), 400, 'reference 2', "copy $Tag")
    [Lab]::Stats((Join-Path $out "ref2_copy_$Tag.png"), 0, 0, 0, 0)
}
