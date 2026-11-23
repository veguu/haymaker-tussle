#!/usr/bin/env bash
# Sinking (in the game now) against shattering, both floors, one clip at a time; then the comparison video.
D="C:/Users/spicy/OneDrive/Documents/Haymaker Tussle/design/kits/ice-study"
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
run() { "$B" -b --factory-startup --python-exit-code 1 --python "$D/render_preview.py" -- "$1" "$2" "$D/out/preview" 1920 1080 2>&1 | grep -E "RESULT_JSON|Error|Traceback|rror:" | cut -c1-200; }
for clip in shatter_meadow shatter_lobby; do rm -rf "$D/out/preview/$clip"; done
run shatter meadow; run shatter lobby
P="$D/out/preview"; O="$D/out"; FONT="C\:/Windows/Fonts/arialbd.ttf"
label() { echo "drawtext=fontfile='$FONT':text='$1':x=14:y=12:fontsize=26:fontcolor=white:box=1:boxcolor=black@0.65:boxborderw=8"; }
ffmpeg -v error -y -framerate 60 -i "$P/new_meadow/f_%04d.png" -framerate 60 -i "$P/shatter_meadow/f_%04d.png" -framerate 60 -i "$P/new_lobby/f_%04d.png" -framerate 60 -i "$P/shatter_lobby/f_%04d.png" \
  -filter_complex "[0]scale=960:540,$(label 'In the game now (sinks) - meadow')[a];[1]scale=960:540,$(label 'Shatter - meadow')[b];[2]scale=960:540,$(label 'In the game now (sinks) - lobby stone')[c];[3]scale=960:540,$(label 'Shatter - lobby stone')[d];[a][b][c][d]xstack=inputs=4:layout=0_0|960_0|0_540|960_540" \
  -c:v libx264 -pix_fmt yuv420p -crf 17 -r 60 "$O/_pass.mp4"
ffmpeg -v error -y -stream_loop 2 -i "$O/_pass.mp4" -c copy "$O/shatter_side_by_side.mp4"
ffmpeg -v error -y -i "$O/_pass.mp4" -vf "setpts=4*PTS" -r 60 -c:v libx264 -pix_fmt yuv420p -crf 17 "$O/shatter_slow.mp4"
rm -f "$O/_pass.mp4"
# the leaving, every 2nd frame from 1.03 s: the reference's row is added by hand beside it
ffmpeg -v error -y -start_number 82 -i "$P/shatter_lobby/f_%04d.png" -vf "select='not(mod(n,3))',scale=480:270,tile=6x3" -frames:v 1 "$O/shatter_moments.jpg"
echo ALL_DONE
