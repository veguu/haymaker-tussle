# Renders test punches from scratch with ffmpeg. Each sound is designed as one whole file (the layers here are
# the parts of ONE hit, mixed and rendered together, never stacked in the game).
# Run: powershell -ExecutionPolicy Bypass -File sfx-lab\make_punch_tests.ps1
$ErrorActionPreference = 'Stop'
$out = $PSScriptRoot

function Render([string]$name, [object[]]$layers, [string]$master, [double]$dur = 0.6) {
	$chains = @()
	$labels = ''
	for ($i = 0; $i -lt $layers.Count; $i++) {
		$l = $layers[$i]
		$c = "aevalsrc='$($l.e)':s=48000:d=$dur"
		if ($l.f) { $c += ",$($l.f)" }
		if ($l.d) { $c += ",adelay=$($l.d):all=1" }
		$c += ",atrim=0:$dur[l$i]"
		$chains += $c
		$labels += "[l$i]"
	}
	$graph = ($chains -join ';') + ";$labels" + "amix=inputs=$($layers.Count):normalize=0,$master[o]"
	ffmpeg -hide_banner -loglevel error -y -filter_complex $graph -map '[o]' -ar 48000 -ac 1 "$out\$name.wav"
	Write-Output "$name.wav"
}

# The shared master: tame the lows under 40 Hz, round off the top, a little tape-like drive, glue, limit.
$master = 'highpass=f=40,lowpass=f=6000,asoftclip=type=tanh:param=1.4,acompressor=threshold=-16dB:ratio=4:attack=0.5:release=80,alimiter=limit=0.95,afade=t=out:st=0.45:d=0.15'

# Body: a sine dropping 130 -> 52 Hz in ~0.1 s. Knock: dull noise in 180-1400 Hz, gone in ~40 ms.
$body = @{ e = '0.9*sin(2*PI*(52*t+2.34*(1-exp(-t/0.03))))*exp(-t/0.11)*min(1,t/0.003)' }
$knock = @{ e = '1.1*(2*random(0)-1)*exp(-t/0.016)*min(1,t/0.001)'; f = 'highpass=f=180,highpass=f=180,lowpass=f=1400,lowpass=f=1400' }
$knockTone = @{ e = '0.35*sin(2*PI*(210*t+1.3*(1-exp(-t/0.012))))*exp(-t/0.03)' }

# A: plain, dull, heavy body punch.
Render 'punch_A_dull' @($body, $knock, $knockTone) $master

# B: heavier: A plus a very short crunch (3-4 kHz, ~6 ms, not a slap's 30 ms) and a low tail that sinks.
$crunch = @{ e = '0.5*(2*random(1)-1)*exp(-t/0.006)'; f = 'highpass=f=1500,lowpass=f=4000' }
$subTail = @{ e = '0.55*sin(2*PI*(42*t+1.3*(1-exp(-t/0.1))))*exp(-t/0.26)*min(1,t/0.01)' }
Render 'punch_B_heavy' @($body, $knock, $knockTone, $crunch, $subTail) ($master -replace 'param=1.4', 'param=2')

# C: B with the swing in it: a short cloth whoosh rising into the hit 90 ms later (the file's hit is at 0.09 s).
$whoosh = @{ e = '0.45*(2*random(2)-1)*pow(t/0.09,3)*lt(t,0.09)'; f = 'highpass=f=500,lowpass=f=2500' }
$hit = foreach ($l in @($body, $knock, $knockTone, $crunch, $subTail)) { $x = $l.Clone(); $x.d = 90; $x }
Render 'punch_C_whoosh' (@($whoosh) + $hit) ($master -replace 'param=1.4', 'param=2') 0.7
