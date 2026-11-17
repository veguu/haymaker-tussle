#!/usr/bin/env bash
# Round 6 (2026-11-16): the user liked round 5's F (thud + body) and G (one heavy thud) as M1s ("soft m1s"),
# G as "a 4th m1 with knockback"; a HEAVY punch needs more. Dry recordings only (no gore/splat, memory rule).
# Builds: m1_hit takes (F style, 4 different source pairs) + m1_finish (G), and heavy punch candidates
# (thud + designed trailer boom under it). Run from the project folder.
set -e
L="C:/Users/spicy/SFX Library/Sonniss GDC 2026"
CF="$L/344 Audio - Cinematic Fight Vol. 1/FGHTImpt_4 x Punch, Body 02_344 Audio_Cinematic Fight Vol 1.wav"
SW="$L/David Dumais Audio - Melee Weapons Sound Effects Pack 2/SWSH_SWING IMPACTS Quick Heavy Weapon Swing To Thud Impact Var 01_DDUMAIS_MWP2.wav"
CRACKER="$L/InMotionAudio - Christmas Cracker/OBJMisc_CrackerPull_WithBang_Effected_03_InMotionAudio_ChristmasCracker.wav"
B011="$L/Federico Soler - Effective Trailer Booms Vol. 2/EffectiveTrailer_Booms_Vol2_011.wav"
B075="$L/Federico Soler - Effective Trailer Booms Vol. 2/EffectiveTrailer_Booms_Vol2_075.wav"
B214="$L/Federico Soler - Effective Trailer Booms Vol. 2/EffectiveTrailer_Booms_Vol2_214.wav"
O=sfx-lab/round6
mkdir -p "$O"

# mix <name> <length s> <layer>... ; layer = "src|start s|pitch|highpass Hz|lowpass Hz|gain dB|delay ms|fade-out start s"
mix() {
	local name=$1 len=$2
	shift 2
	local ins=() f="" lab="" i=0
	for spec in "$@"; do
		IFS='|' read -r src st pitch hp lp g dl fo mono <<<"$spec"
		ins+=(-ss "$st" -i "$src")
		# mono=L: use the left channel only (a boom whose lows are anti-phase between channels would cancel when
		# Roblox plays it in mono)
		local m=""
		if [ "$mono" = "L" ]; then m="pan=stereo|c0=c0|c1=c0,"; fi
		f+="[$i]atrim=0:$len,asetpts=N/SR/TB,aresample=48000,asetrate=48000*$pitch,aresample=48000,aformat=channel_layouts=stereo,${m}highpass=f=$hp,lowpass=f=$lp,volume=${g}dB,afade=t=in:d=0.002,afade=t=out:st=$fo:d=0.15,adelay=$dl:all=1[l$i];"
		lab+="[l$i]"
		i=$((i + 1))
	done
	ffmpeg -hide_banner -loglevel error -y "${ins[@]}" -filter_complex \
		"${f}${lab}amix=inputs=$i:normalize=0,asoftclip=type=tanh:param=1.2,alimiter=limit=0.89:attack=1:release=80,atrim=0:$len,afade=t=out:st=$(awk -v l=$len 'BEGIN{print l-0.12}'):d=0.12" \
		-ar 48000 "$O/$name.wav"
	echo "$name.wav"
}

# --- m1_hit takes: swing-thud on a Cinematic Fight body punch (round 5 F), four different source pairs
mix m1_hit_1 0.45 "$SW|12.205|0.95|150|16000|-2|0|0.3" "$CF|2.270|0.95|25|2500|-1|4|0.3"
mix m1_hit_2 0.45 "$SW|36.190|0.95|150|16000|-2|0|0.3" "$CF|3.275|0.95|25|2500|-1|4|0.3"
mix m1_hit_3 0.45 "$SW|60.195|0.96|150|16000|-2|0|0.3" "$CF|1.230|0.96|25|2500|-1|4|0.3"
mix m1_hit_4 0.45 "$SW|39.335|0.94|150|16000|0|0|0.3" "$CF|0.285|0.97|25|2500|-1|4|0.3"
# --- m1_finish (4th hit, knockback): round 5 G, one heavy swing-thud pitched down 8 %
mix m1_finish 0.45 "$SW|48.195|0.92|25|16000|0|0|0.3"

# --- heavy punch candidates: the m1_finish thud with a designed trailer boom under it (boom's hit at ~0.26 s)
# H1: thud + boom 214 (lows only), boom tail ~1.1 s
mix heavy_H1_thud_boom214 1.3 "$SW|48.195|0.9|25|16000|0|0|1.0" "$B214|0.262|1.0|25|400|-3|3|1.0|L"
# H2: dry snap + thud + boom 075
mix heavy_H2_snap_thud_boom075 1.3 "$CRACKER|0.078|1.0|700|16000|-6|0|1.0" "$SW|36.190|0.9|25|16000|-1|4|1.0" "$B075|0.258|1.0|25|400|-3|6|1.0|L"
# H3: body punch + thud + boom 011 (the boom pitched down 6 % for a deeper, longer fall)
mix heavy_H3_body_thud_boom011 1.3 "$CF|3.275|0.92|25|2500|-1|0|1.0" "$SW|12.205|0.9|150|16000|-2|0|1.0" "$B011|0.268|0.94|25|400|-3|5|1.0|L"
