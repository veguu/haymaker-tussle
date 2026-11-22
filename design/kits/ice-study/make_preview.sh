#!/usr/bin/env bash
# Step 5: assembles the preview from the frames render_preview.py made.
#   ice_preview_side_by_side.mp4  today's ice (left) and the new ice (right), meadow above, lobby stone below,
#                                 real speed (60 fps), three passes
#   ice_preview_slow.mp4          the same at quarter speed, one pass
#   ice_new_meadow.mp4 / ice_new_lobby.mp4   the new ice alone at game size (1920 x 1080), three passes
#   ice_preview_moments.png       eight known moments of the lobby pair as stills
# Usage: bash make_preview.sh "<ice-study folder>"
set -e
D="$1"
P="$D/out/preview"
O="$D/out"
FONT="C\:/Windows/Fonts/arialbd.ttf"
label() { echo "drawtext=fontfile='$FONT':text='$1':x=14:y=12:fontsize=26:fontcolor=white:box=1:boxcolor=black@0.65:boxborderw=8"; }
GRID="[0]$(label 'In the game today - meadow')[a];[1]scale=960:540:flags=lanczos,$(label 'New - meadow')[b];[2]$(label 'In the game today - lobby stone')[c];[3]scale=960:540:flags=lanczos,$(label 'New - lobby stone')[d];[a][b][c][d]xstack=inputs=4:layout=0_0|960_0|0_540|960_540"
IN=(-framerate 60 -i "$P/today_meadow/f_%04d.png" -framerate 60 -i "$P/new_meadow/f_%04d.png" -framerate 60 -i "$P/today_lobby/f_%04d.png" -framerate 60 -i "$P/new_lobby/f_%04d.png")
ENC=(-c:v libx264 -pix_fmt yuv420p -crf 17 -movflags +faststart)

ffmpeg -v error -y "${IN[@]}" -filter_complex "$GRID" "${ENC[@]}" -r 60 "$O/_pass.mp4"
ffmpeg -v error -y -stream_loop 2 -i "$O/_pass.mp4" -c copy "$O/ice_preview_side_by_side.mp4"
ffmpeg -v error -y -i "$O/_pass.mp4" -vf "setpts=4*PTS" -r 60 "${ENC[@]}" "$O/ice_preview_slow.mp4"
for floor in meadow lobby; do
  ffmpeg -v error -y -framerate 60 -i "$P/new_$floor/f_%04d.png" "${ENC[@]}" -r 60 "$O/_new_$floor.mp4"
  ffmpeg -v error -y -stream_loop 2 -i "$O/_new_$floor.mp4" -c copy "$O/ice_new_$floor.mp4"
  rm -f "$O/_new_$floor.mp4"
done
rm -f "$O/_pass.mp4"

# Known moments (seconds after the stomp; frame = 20 + t x 60): arrival, white-hot waves, overshoot, standing, leaving.
i=0
INPUTS=()
FILTER=""
LAYOUT=""
for frame in 21 23 25 28 32 56 87 92 97; do
  t=$(awk "BEGIN{printf \"%.3f\", ($frame-20)/60}")
  INPUTS+=(-i "$P/today_lobby/f_$(printf %04d $frame).png" -i "$P/new_lobby/f_$(printf %04d $frame).png")
  FILTER+="[$((i*2))]scale=640:360,$(label "today  t = $t s")[t$i];[$((i*2+1))]scale=640:360:flags=lanczos,$(label "new  t = $t s")[n$i];"
  i=$((i+1))
done
# three columns of (today, new) pairs, three rows
STACK=""
LAY=""
k=0
for row in 0 1 2; do for col in 0 1 2; do
  STACK+="[t$k][n$k]"
  LAY+="$((col*1280))_$((row*360))|$((col*1280+640))_$((row*360))|"
  k=$((k+1))
done; done
ffmpeg -v error -y "${INPUTS[@]}" -filter_complex "${FILTER}${STACK}xstack=inputs=18:layout=${LAY%|}" "$O/ice_preview_moments.png"
ls -la "$O" | grep -E "ice_preview|ice_new"
