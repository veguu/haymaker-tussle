#!/usr/bin/env bash
# One sheet per look for the owner: the reference and today's ice on top, the look on both floors below.
# Usage: bash make_look_sheets.sh "<ice-study folder>"
set -e
D="$1"
O="$D/out"
FONT="C\:/Windows/Fonts/arialbd.ttf"
label() { echo "drawtext=fontfile='$FONT':text='$1':x=14:y=12:fontsize=34:fontcolor=white:box=1:boxcolor=black@0.65:boxborderw=8"; }
for n in 1 2 3; do
  ffmpeg -v error -y -i "$D/sheets/C_still_4500.png" -i "$D/studio/today_lobby_t060.jpg" -i "$O/look${n}_lobby_t060.png" -i "$O/look${n}_meadow_t060.png" \
    -filter_complex "[0]scale=800:450,$(label 'Your reference')[a];[1]scale=1120:-1,pad=1120:450:0:(oh-ih)/2:black,$(label 'In the game today')[b];[2]scale=960:-1,$(label "Look $n - lobby stone")[c];[3]scale=960:-1,$(label "Look $n - meadow")[d];[a][b][c][d]xstack=inputs=4:layout=0_0|800_0|0_450|960_450" \
    "$O/look_sheet_$n.png"
done
ls -la "$O" | grep look_sheet
