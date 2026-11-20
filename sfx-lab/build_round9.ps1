# Round 9 (kits-8t, 2026-11-20): the release bass, aimed at the owner's FAVOURITE reference, Benimaru's "Crimson Moon"
# (tTUEM9KdxfQ), after round 8's three ("none really sound like the references"). Measured from 3.85 s: a 1.66 s SWELL
# (very low start, noisy rise) into a BOOM (sub, low and lmid peaking together, -10 to -15 dB), then a full DRONE held
# above -20 dB for 2.3 s+ in every band, the sub sitting near 50 Hz. Each candidate is cut so its boom lands at 1.6 s:
# the game starts it on the haymaker's contact, it swells through the 1.62 s slow sink, and booms on the release.
# Sources: Sonniss GDC 2016/2019/2020 bundles (royalty-free in games), in "C:\Users\spicy\SFX Library\Sonniss GDC
# 2015-2020 picks". Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File sfx-lab\build_round9.ps1
$lib = "C:\Users\spicy\SFX Library\Sonniss GDC 2015-2020 picks"
$out = Join-Path $PSScriptRoot "round9"
$hit096 = "$lib\SoundBits -  Cinematic Hits & Transitions 2\CHT2_Cinematic_Hit_096.wav"
$risers = "$lib\SoundMorph - Sinematic\Sinematic - Risers_02.wav"
$planet = "$lib\MatiasMacSD - Eradication - Small Pack\Planet_Explosion_Low-04.wav"
$braam = "$lib\Federico Soler Fernandez - Effective Trailer Braams\Braam 004 (D).wav"
$boom091 = "$lib\Federico Soler Fern_ndez - Effective Trailer Booms\Boom 091.wav"
$tail = "afade=t=in:d=0.15,afade=t=out:st=3.2:d=0.8,atrim=0:4.0"
$finish = "alimiter=limit=0.89:attack=1:release=80,aresample=48000"

# D "cinematic hit": SoundBits Cinematic Hit 096 alone (its own rise; its sub peaks at 2.78 s, so cut 1.18 s in)
ffmpeg -v error -y -ss 1.18 -i $hit096 -filter_complex "[0:a]atrim=0:4.2,$tail,$finish" -ac 2 -c:a pcm_s16le "$out\bass_D_cinematic_hit.wav"

# E "riser into planet": the Sinematic riser (sub peak 2.63 s, cut 1.03 s in) with the low planet explosion under it
# for the drone (its peak 1.0 s, delayed so it lands on the boom at 1.6 s)
ffmpeg -v error -y -ss 1.03 -i $risers -i $planet -filter_complex `
	"[0:a]atrim=0:4.2,volume=0.9[a];[1:a]atrim=0:3.6,adelay=600|600,volume=0.7[b];[a][b]amix=inputs=2:normalize=0,$tail,$finish" `
	-ac 2 -c:a pcm_s16le "$out\bass_E_riser_planet.wav"

# F "braam swell": the trailer braam's swell (loudest 2.68 s, cut 1.08 s in) with Trailer Boom 091 struck on the 1.6 s
ffmpeg -v error -y -ss 1.08 -i $braam -i $boom091 -filter_complex `
	"[0:a]atrim=0:4.2,volume=0.8[a];[1:a]atrim=0:3.5,adelay=1485|1485,volume=1.0[b];[a][b]amix=inputs=2:normalize=0,$tail,$finish" `
	-ac 2 -c:a pcm_s16le "$out\bass_F_braam_swell.wav"
