# Slices reference 3 by brightness to see its shapes at each depth of the soft edges:
# the black cores (< 0.12), the inner halo (< 0.45), the outer halo (< 0.8) and the faintest tint (< 0.95).
param([string]$Refs)
. "$PSScriptRoot\load.ps1"
$out = Join-Path $PSScriptRoot 'out'
$ref = [Img]::Load((Join-Path $Refs 'ref3.png')).Crop(0, 60, 640, 360).Resize(1280, 720)
$i = 0
foreach ($t in 0.12, 0.45, 0.8, 0.95) {
    $s = [Lab]::Levels($ref, $t, $t + 0.01, 1)
    $s.Save((Join-Path $out "ref3_slice_$i.png")); $i++
}
$ref.Save((Join-Path $out 'ref3_content_2x.png'))
