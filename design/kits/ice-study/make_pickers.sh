#!/usr/bin/env bash
# Picker sheets: one per ice effect found in the owner's three references (2026-11-22).
# Each sheet: two big stills on top (960x540 each), six motion frames below (320x180 each).
# Usage: bash make_pickers.sh "<ice-study folder>"
set -e
R="$1"
S="$R/sheets"
T="$S/tmp"
mkdir -p "$T"
FONT="C\:/Windows/Fonts/arialbd.ttf"

big() { # id time crop(w:h:x:y or none) out
  local vf="scale=960:540"
  if [ "$3" != "none" ]; then vf="crop=$3,scale=960:540:flags=lanczos"; fi
  ffmpeg -v error -y -ss "$2" -i "$R/ref/$1.mp4" -frames:v 1 -vf "$vf" "$T/$4.png"
}
small() { # id time out
  ffmpeg -v error -y -ss "$2" -i "$R/ref/$1.mp4" -frames:v 1 -vf "scale=320:180,drawtext=fontfile='$FONT':text='$2 s':x=4:y=4:fontsize=16:fontcolor=yellow:box=1:boxcolor=black@0.6" "$T/$3.png"
}
sheet() { # letter title
  ffmpeg -v error -y -i "$T/$1_b1.png" -i "$T/$1_b2.png" -i "$T/$1_s1.png" -i "$T/$1_s2.png" -i "$T/$1_s3.png" -i "$T/$1_s4.png" -i "$T/$1_s5.png" -i "$T/$1_s6.png" \
    -filter_complex "xstack=inputs=8:layout=0_0|960_0|0_540|320_540|640_540|960_540|1280_540|1600_540,drawtext=fontfile='$FONT':text='$1':x=16:y=12:fontsize=72:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=10" \
    "$S/pick_$1.png"
}

PEW=HOeAQEvFDNA; NIA=dIWMbXMnwqc; ARC=hAUY_cFofLw

# A: Pew, one glowing cone spike (0:29.5 - 0:31.6)
big $PEW 30.6 "480:270:260:135" A_b1; big $PEW 30.95 "480:270:330:160" A_b2
i=1; for t in 29.5 29.583 29.667 30.25 30.75 31.5; do small $PEW $t A_s$i; i=$((i+1)); done
sheet A

# B: Pew, the jagged crystal mass (1:15.4 - 1:33)
big $PEW 91.75 "560:315:335:45" B_b1; big $PEW 85.6 none B_b2
i=1; for t in 75.417 75.5 75.75 78.5 92.25 92.667; do small $PEW $t B_s$i; i=$((i+1)); done
sheet B

# C: Niagara, the flower of long blades (2.2 - 5.2)
big $NIA 2.45 none C_b1; big $NIA 3.6 none C_b2
i=1; for t in 2.2 2.333 2.533 4.933 5.0 5.2; do small $NIA $t C_s$i; i=$((i+1)); done
sheet C

# D: ARC, clear rough chunks: a frozen figure that breaks (8.0 - 12)
big $ARC 8.55 "480:270:640:110" D_b1; big $ARC 9.3 "640:360:580:50" D_b2
i=1; for t in 8.0 8.25 8.75 9.0 9.5 12.0; do small $ARC $t D_s$i; i=$((i+1)); done
sheet D
ls -la "$S" | grep pick_
