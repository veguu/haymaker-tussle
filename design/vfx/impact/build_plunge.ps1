# Fist impact frame (right before the knockback). The drawing itself is design/vfx/impact/Plunge.cs:
# one perspective (three vanishing points) for the torso, head, arms and fist; the target in its Fold pose at
# the final punch; the chest caving in toward the depth vanishing point; every mark a scratch.
# This script renders the frames: frame 0 (the hit) inverted, the rest graphite on paper.
param([string]$OutDir = "$PSScriptRoot\out", [int]$Frames = 8, [int]$Only = -1, [int]$Seed = 300, [switch]$Info)
. "$PSScriptRoot\..\study\load.ps1"
New-Item -ItemType Directory -Force $OutDir | Out-Null
if ($Info) { [Plunge]::Info(); return }
if ($Only -lt 0) { Remove-Item (Join-Path $OutDir 'plunge_*.png') -ErrorAction SilentlyContinue }
for ($i = 0; $i -lt $Frames; $i++) {
    if ($Only -ge 0 -and $i -ne $Only) { continue }
    $img = [Plunge]::Render($i, $Frames, $Seed)
    if ($i -eq 0) { $img = [Lab]::GradientMap([Lab]::Levels($img, 1, 0, 1), '0:22,20,22;0.55:120,116,112;1:238,233,224') }
    $img.Save((Join-Path $OutDir ('plunge_{0:00}.png' -f $i)))
    "frame $i done"
}
