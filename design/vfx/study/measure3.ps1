# Reference 3's colour ramp (content area only) and its streak direction per region.
param([string]$Refs)
. "$PSScriptRoot\load.ps1"
$r3 = Join-Path $Refs 'ref3.png'
"=== REF3 ramp (rows 60-420) ==="
[Lab]::Ramp($r3, 0, 60, 640, 420)
"=== streak direction by region ==="
"centre mass (250-450, 150-330)"; [Lab]::Vanish($r3, 250, 150, 450, 330)
"spikes right (380-640, 170-300)"; [Lab]::Vanish($r3, 380, 170, 640, 300)
"arcs left (0-260, 60-300)"; [Lab]::Vanish($r3, 0, 60, 260, 300)
"fan top right (330-640, 60-170)"; [Lab]::Vanish($r3, 330, 60, 640, 170)
"lower right (420-640, 320-420)"; [Lab]::Vanish($r3, 420, 320, 640, 420)
