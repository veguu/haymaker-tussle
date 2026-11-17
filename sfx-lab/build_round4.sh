#!/usr/bin/env bash
# Round 4: punches built from RECORDED layers (Sonniss GDC 2026, royalty-free), mixed into one file each.
# Crack/crunch layer (bright, stereo, held highs) + body/sub layer (late sub), aligned so the crack's high peak
# lands ~15 ms in and the sub blooms 25-110 ms in (the reference order). Run from the project folder.
set -e
L="C:/Users/spicy/SFX Library/Sonniss GDC 2026"
GORE="$L/Epic Stock Media - Halloween Game - Haunted House and Horror Audio Scare Kit/GORESplt_Gore Designed Transient Heavy Impact Smash 01_ESM_HALG.wav"
SMACK="$L/Epic Stock Media - Anime Game/FGHTImpt_Combat Punch Impact Light Hit Delay Crunchy Vintage Quick Smack 05_ESM_AG.wav"
CF="$L/344 Audio - Cinematic Fight Vol. 1/FGHTImpt_4 x Punch, Body 02_344 Audio_Cinematic Fight Vol 1.wav"
SW="$L/David Dumais Audio - Melee Weapons Sound Effects Pack 2/SWSH_SWING IMPACTS Quick Heavy Weapon Swing To Thud Impact Var 01_DDUMAIS_MWP2.wav"
O=sfx-lab/round4
mkdir -p "$O"

# layer chain: trim -> 48 kHz stereo -> optional pitch (rate factor) -> band split -> gain -> 2 ms fade-in
layer() { # src start dur pitch hp lp gainDb label
	echo "[${8}]atrim=0:$3,asetpts=N/SR/TB,aresample=48000,asetrate=48000*$4,aresample=48000,aformat=channel_layouts=stereo,highpass=f=$5,lowpass=f=$6,volume=${7}dB,afade=t=in:d=0.002[${8}o]"
}
build() { # name ... : crack src/start, body src/start, pitch, crack gain, body gain, body delay ms
	local name=$1 cs=$2 cst=$3 bs=$4 bst=$5 pitch=$6 cg=$7 bg=$8 bd=$9
	ffmpeg -hide_banner -loglevel error -y -ss "$cst" -i "$cs" -ss "$bst" -i "$bs" -filter_complex \
"[0]anull[c];[1]anull[b];$(layer x x 0.45 $pitch 250 16000 $cg c);$(layer x x 0.45 $pitch 25 2500 $bg b);[co]afade=t=out:st=0.14:d=0.12[cf];[bo]adelay=$bd:all=1[bd];[cf][bd]amix=inputs=2:normalize=0,asoftclip=type=tanh:param=1.2,alimiter=limit=0.89:attack=1:release=60,afade=t=out:st=0.33:d=0.12" \
		-ar 48000 "$O/$name.wav"
	echo "$name.wav"
}
# The body starts 8-10 ms after the crack so the crack leads (first-15 ms brightness); the crack fades from 140 ms
# (highs held ~150-250 ms like the references).
# A: gore crack (cut 25 ms into its rise) + Cinematic Fight body (punch 4)
build punch_A_gore_cf "$GORE" 0.100 "$CF" 3.275 1.0 -2 0 9
# B: gore crack + Cinematic Fight body (punch 2, the late-sub one), pitched down 6 % for weight
build punch_B_gore_cf2 "$GORE" 0.100 "$CF" 1.230 0.94 -2 0 9
# C: gore crack + weapon swing-to-thud body (take at 36.2 s), pitched down 8 %
build punch_C_gore_thud "$GORE" 0.100 "$SW" 36.190 0.92 -3 1 8
