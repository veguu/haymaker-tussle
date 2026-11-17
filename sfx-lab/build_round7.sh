#!/usr/bin/env bash
# Round 7 (2026-11-16): HEAVY hits built on the measured anime big-hit anatomy (vault: "Anime Impact Sound
# Anatomy" + "Punch Sound Design - References vs Synthesized Attempts"): dry contact (snap + thud), a wide
# broadband BLAST/ROAR whose top sweeps down (the muffle), a late mono SUB held ~1 s, and a SINKING boom
# (bass downer 175 -> 50 Hz). Dry recordings only. Run from the project folder.
set -e
L="C:/Users/spicy/SFX Library/Sonniss GDC 2026"
SW="$L/David Dumais Audio - Melee Weapons Sound Effects Pack 2/SWSH_SWING IMPACTS Quick Heavy Weapon Swing To Thud Impact Var 01_DDUMAIS_MWP2.wav"
CRACKER="$L/InMotionAudio - Christmas Cracker/OBJMisc_CrackerPull_WithBang_Effected_03_InMotionAudio_ChristmasCracker.wav"
FW="$L/Ivo Vicic - Fireworks FX/13 Fireworks_powerful explosions_multiples in a row_near.wav"
AX="$L/Epic Stock Media - Anime Game/EXPLDsgn_Explosion Small Blast Enemy Death Crunchy Boom Cartoon Noisy Crash Impact Delay 03_ESM_AG.wav"
B011="$L/Federico Soler - Effective Trailer Booms Vol. 2/EffectiveTrailer_Booms_Vol2_011.wav"
B075="$L/Federico Soler - Effective Trailer Booms Vol. 2/EffectiveTrailer_Booms_Vol2_075.wav"
B214="$L/Federico Soler - Effective Trailer Booms Vol. 2/EffectiveTrailer_Booms_Vol2_214.wav"
DOWN="$L/344 Audio - Bass Drops & Downers Vol. 1/DSGNBass_Bass Drop & Downer Fast 16_344 Audio_Bass Drops & Downers.wav"
ICE="$L/Alexander Kopeikin - 100 kHz Designed Ice/ice, surface cracking, fissure, fast, hard-003.wav"   # debris: sparse cracks, highs only
O=sfx-lab/round7
mkdir -p "$O"

# layer = "src|start|pitch|hp|lp|gain dB|delay ms|fade-out start|mono(L or -)|sweep(f0:f1:seconds or -)"
mix() {
	local name=$1 len=$2
	shift 2
	local ins=() f="" lab="" i=0
	for spec in "$@"; do
		IFS='|' read -r src st pitch hp lp g dl fo mono sweep <<<"$spec"
		ins+=(-ss "$st" -i "$src")
		local m="" sw=""
		if [ "$mono" = "L" ]; then m="pan=stereo|c0=c0|c1=c0,"; fi
		if [ -n "$sweep" ] && [ "$sweep" != "-" ]; then
			IFS=':' read -r f0 f1 t1 <<<"$sweep"
			local cmds
			cmds=$(awk -v a=$f0 -v b=$f1 -v T=$t1 -v n="m$i" 'BEGIN{s=""; for(t=0.04;t<=T+1e-9;t+=0.04){f=a*exp(log(b/a)*t/T); s=s sprintf("%.2f lowpass@%s f %.0f;",t,n,f)} print s}')
			sw="asendcmd=c='${cmds}',lowpass@m$i=f=$f0,"
		fi
		f+="[$i]atrim=0:$len,asetpts=N/SR/TB,aresample=48000,asetrate=48000*$pitch,aresample=48000,aformat=channel_layouts=stereo,${m}${sw}highpass=f=$hp,lowpass=f=$lp,volume=${g}dB,afade=t=in:d=0.002,afade=t=out:st=$fo:d=0.25,adelay=$dl:all=1[l$i];"
		lab+="[l$i]"
		i=$((i + 1))
	done
	ffmpeg -hide_banner -loglevel error -y "${ins[@]}" -filter_complex \
		"${f}${lab}amix=inputs=$i:normalize=0,asoftclip=type=tanh:param=1.2,alimiter=limit=0.89:attack=1:release=120,atrim=0:$len,afade=t=out:st=$(awk -v l=$len 'BEGIN{print l-0.3}'):d=0.3" \
		-ar 48000 "$O/$name.wav"
	echo "$name.wav"
}

SNAP="$CRACKER|0.078|1.0|700|16000|-5|0|0.2|-|-"
THUD="$SW|48.195|0.9|25|16000|0|0|0.5|-|-"

# K1 "blast": fireworks explosion as the roar (wide, real), boom 214 sub, sinking downer
mix heavy_K1_blast 2.6 "$SNAP" "$THUD" \
	"$FW|6.605|0.95|100|16000|5|4|1.0|-|9000:700:1.0" \
	"$B214|0.262|1.0|25|220|-2|25|1.6|L|-" \
	"$DOWN|0.170|1.0|25|350|-9|60|1.9|L|-" "$ICE|0.330|1.0|1800|12000|-13|90|0.9|-|-"
# K2 "crunchy": the anime-game designed explosion as the roar, boom 075 sub, downer
mix heavy_K2_crunch 2.6 "$SNAP" "$THUD" \
	"$AX|0.000|0.95|100|16000|3|4|1.0|-|9000:700:1.0" \
	"$B075|0.258|1.0|25|220|-2|25|1.6|L|-" \
	"$DOWN|0.170|1.0|25|350|-9|60|1.9|L|-" "$ICE|0.330|1.0|1800|12000|-13|90|0.9|-|-"
# K3 "colossal": both roars, the deepest boom (011 pitched down), downer
mix heavy_K3_colossal 2.6 "$SNAP" "$THUD" \
	"$FW|6.605|0.92|100|16000|2|4|1.1|-|9000:600:1.2" \
	"$AX|0.000|0.92|100|16000|0|8|1.1|-|9000:600:1.2" \
	"$B011|0.268|0.94|25|220|-2|25|1.7|L|-" \
	"$DOWN|0.170|0.95|25|350|-9|60|2.0|L|-" "$ICE|0.330|1.0|1800|12000|-13|90|0.9|-|-"
