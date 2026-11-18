# Reference 3's content at 2x (1280x712, y = 0 at the top of the picture, letterbox removed) with a
# measuring grid: thin lines every 40 px, labelled lines every 80 px. Writes the full view and four
# zoomed quarters (each 640x356 shown at 2x) for reading line paths as coordinates.
param([string]$Refs)
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'
$ref = [Img]::Load((Join-Path $Refs 'ref3.png')).Crop(0, 62, 640, 356).Resize(1280, 712)
$bmp = $ref.ToBitmap()
$g = [System.Drawing.Graphics]::FromImage($bmp)
$thin = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(110, 255, 0, 80)), 1
$bold = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 255, 0, 80)), 1
$font = New-Object System.Drawing.Font 'Consolas', 9, ([System.Drawing.FontStyle]::Bold)
$br = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 220, 0, 60))
for ($x = 0; $x -le 1280; $x += 40) { $g.DrawLine($(if ($x % 80 -eq 0) { $bold } else { $thin }), $x, 0, $x, 712) }
for ($y = 0; $y -le 712; $y += 40) { $g.DrawLine($(if ($y % 80 -eq 0) { $bold } else { $thin }), 0, $y, 1280, $y) }
for ($x = 0; $x -lt 1280; $x += 80) { for ($y = 0; $y -lt 712; $y += 80) { $g.DrawString("$x,$y", $font, $br, $x + 2, $y + 1) } }
$bmp.Save((Join-Path $out 'ref3_grid.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$full = [Img]::FromBitmap($bmp)
$i = 0
foreach ($q in @(@(0, 0), @(640, 0), @(0, 356), @(640, 356))) {
    $full.Crop($q[0], $q[1], 640, 356).Resize(1280, 712).Save((Join-Path $out "ref3_grid_q$i.png")); $i++
}
