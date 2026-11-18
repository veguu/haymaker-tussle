# Contact impact frame (the haymaker's first connection): quick and flashy, in reference 2's ink-burst
# style (practice copy v12, study/recreate_ref2b.ps1), drawn as pencil. No fighters, no 3D.
# Animated as an explosion, 10 frames at 24 fps (0.42 s):
#   0     the hit: a tight burst, inverted (light graphite on dark paper)
#   1-9   it blows outward: the ink masses fly out (faster the further they go), the paper rays shoot to
#         the edges, the streaks stretch, the clear centre opens up, and the ink thins out at the end
# Every frame is re-drawn as graphite strokes (the pencil boils).
param([string]$OutDir = "$PSScriptRoot\out", [int]$Frames = 10, [double]$HX = 615, [double]$HY = 400, [int]$Seed = 4,
      [int]$Strokes = 9000, [int]$Only = -1)
. "$PSScriptRoot\..\study\recreate_ref2b.ps1"          # loads Lab, Sk and InkBurst (no -Refs: no copy is made)
New-Item -ItemType Directory -Force $OutDir | Out-Null
if ($Only -lt 0) { Remove-Item (Join-Path $OutDir 'contact_*.png') -ErrorAction SilentlyContinue }
# canvas for InkBurst (it reads these from here)
$IW = 1280; $IH = 720; $P = 300; $WP = $IW + 2 * $P; $HP = $IH + 2 * $P; $cx = $HX + $P; $cy = $HY + $P
# v12 settings
$Twist = 0.04; $InkCut = 0.36; $KOut = 0.7; $KPeak = 2.6; $MidTex = 0.4; $Rays = 7; $RayMin = 1.5; $RayMax = 3.5
$RayBreak = 0.45; $Hot = 0.9; $AngCells = 34; $RadCell = 0.3; $Lobes = 0; $InkIn = 30; $Ring0 = 40; $Ring1 = 260; $Sharp = 1.2
for ($i = 0; $i -lt $Frames; $i++) {
    if ($Only -ge 0 -and $i -ne $Only) { continue }
    $t = $i / ($Frames - 1); $e = 1 - [Math]::Pow(1 - $t, 2.2)
    $Boil = 37 * $i
    $InkIn = 10 + 300 * [Math]::Pow($t, 1.4)                  # the centre opens up
    $inkOut = 70 + 800 * $e                                   # the ink reaches further out
    $Ring1 = 0.7 * $inkOut + 40
    $BlobShift = 1.7 * $e / $RadCell                          # ink masses fly outward (x5.5 in distance)
    $RayReach = 160 + 1400 * $e                               # rays shoot to the edges
    $InkCut = 0.37 - 0.12 * [Math]::Pow($t, 2)                # the ink thins out at the end
    $amount = 0.12 + 0.7 * $e                                 # streaks stretch
    $hotR = 80 + 170 * $e
    $tone = InkBurst $Seed ([float]$amount) ([float]$inkOut) ([float]$hotR)
    $reachR = 160 + 900 * $e                                  # the burst grows from the hit; beyond it, paper
    $reach = [Lab]::Levels([Lab]::RadialShape([Img]::Solid($IW, $IH, 1, 1, 1), [float]$HX, [float]$HY, 1, [float]$reachR, 1, -1, 0, 0), 0, 1, 1)
    $tone = [Lab]::MaskMix([Img]::Solid($IW, $IH, 0.96, 0.96, 0.96), $tone, $reach)
    $pencil = [Img]::FromBitmap([Sk]::Pencil($tone, [float]$HX, [float]$HY, $Strokes, 700 + $i, 28, 170, 3))
    $wash = [Lab]::Levels([Lab]::Levels($tone, 0.04, 0.3, 1), -0.55, 1, 1)
    $final = [Lab]::Multiply($pencil, $wash)
    [Lab]::Grain($final, 0.03, 1.4, 90 + $i)
    if ($i -eq 0) {                                            # the hit: inverted
        $inv = [Lab]::Levels($final, 1, 0, 1)
        $final = [Lab]::GradientMap($inv, '0:14,12,12;0.6:120,114,112;1:244,239,231')
    }
    $final.Save((Join-Path $OutDir ('contact_{0:00}.png' -f $i)))
    "frame $i done"
}
