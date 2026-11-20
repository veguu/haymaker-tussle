# Round 8 (kits-8r, 2026-11-19): the release's BASS (the owner: "having the punch sound twice isnt good, instead i want
# something bassy"; references: Kakyoin's death 2.515 s, Benimaru Crimson Moon). Target, measured on the Kakyoin hit
# (design/cutscene-study/18-barrage-release-bass.md): sub peak about -6 dB at +40 ms held above -20 dB for ~1.5 s,
# loudest at +100 ms, down 20 dB by ~370 ms then a rumble, sub wandering 50-100 Hz, highs low and short, lows mono.
# Sources: Sonniss GDC 2026 (commercial use in games, no attribution). Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File sfx-lab\build_round8.ps1
$lib = "C:\Users\spicy\SFX Library\Sonniss GDC 2026"
$out = Join-Path $PSScriptRoot "round8"
$boom075 = "$lib\Federico Soler - Effective Trailer Booms Vol. 2\EffectiveTrailer_Booms_Vol2_075.wav"
$boom011 = "$lib\Federico Soler - Effective Trailer Booms Vol. 2\EffectiveTrailer_Booms_Vol2_011.wav"
$med04 = "$lib\344 Audio - Bass Drops & Downers Vol. 1\DSGNBass_Bass Drop & Downer Medium 04_344 Audio_Bass Drops & Downers.wav"
$fast12 = "$lib\344 Audio - Bass Drops & Downers Vol. 2\DSGNBass_Bass Drop & Downer Fast 12_344 Audio_Bass Drops & Downers Vol 2.wav"

# every source cut at its own onset (measured with sfx-lab/tools/onsets.luau), so each candidate starts at sample 0
$tail = "afade=t=out:st=1.5:d=0.5,atrim=0:2.0"
$finish = "alimiter=limit=0.89:attack=1:release=60,aresample=48000"

# A "thump + roar": Trailer Boom 075's punchy sub (the hit) under the Downer Medium 04's low roar and downer
ffmpeg -v error -y -ss 0.26 -i $boom075 -ss 0.11 -i $med04 -filter_complex `
	"[0:a]atrim=0:2.2,volume=1.0[a];[1:a]atrim=0:2.2,volume=0.7[b];[a][b]amix=inputs=2:normalize=0,$tail,$finish" `
	-ac 2 -c:a pcm_s16le "$out\bass_A_thump_roar.wav"

# B "deep body": Trailer Boom 011's long dark boom with Boom 075's first 0.3 s for the hit's front
ffmpeg -v error -y -ss 0.27 -i $boom011 -ss 0.26 -i $boom075 -filter_complex `
	"[0:a]atrim=0:2.2,volume=1.0[a];[1:a]atrim=0:0.35,afade=t=out:st=0.15:d=0.2,volume=0.8[b];[a][b]amix=inputs=2:normalize=0,asplit[m][n];[m]lowpass=f=150,pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1[lo];[n]highpass=f=150[hi];[lo][hi]amix=inputs=2:normalize=0,$tail,$finish" `
	-ac 2 -c:a pcm_s16le "$out\bass_B_deep_body.wav"

# C "sinking": A pitched 8 % lower (deeper, a touch slower) with Fast 12's pure sub bed under it, lows to mono
ffmpeg -v error -y -ss 0.26 -i $boom075 -ss 0.11 -i $med04 -ss 0.185 -i $fast12 -filter_complex `
	"[0:a]atrim=0:2.4,volume=1.0[a];[1:a]atrim=0:2.4,volume=0.6[b];[2:a]atrim=0:2.4,lowpass=f=120,volume=0.8[c];[a][b][c]amix=inputs=3:normalize=0,asetrate=48000*0.92,aresample=48000,$tail,$finish" `
	-ac 2 -c:a pcm_s16le "$out\bass_C_sinking.wav"
