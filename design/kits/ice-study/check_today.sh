#!/usr/bin/env bash
# Renders today's ice (quick: two moments) and tiles it beside the Studio captures. Usage: bash check_today.sh [quick]
D="C:/Users/spicy/OneDrive/Documents/Haymaker Tussle/design/kits"
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python-exit-code 1 --python "$D/ice-study/render_today.py" -- "$D/out/export/ice_kit.glb" "$D/ice-study/out" today $1 2>&1 | grep -E "Error|Traceback|line [0-9]+" | cut -c1-300
ffmpeg -v error -y -i "$D/ice-study/studio/today_lobby_t060.jpg" -i "$D/ice-study/out/today_lobby_t060.png" -i "$D/ice-study/studio/today_lobby_t005.jpg" -i "$D/ice-study/out/today_lobby_t005.png" -filter_complex "[0]scale=1600:574[a];[2]scale=1600:574[c];[a][1][c][3]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0,scale=2400:-1" "$D/ice-study/out/check_today_studio_vs_blender.jpg"
PY="C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe"
P1="824,96 592,272 960,240 432,304 795,240 728,144 900,480 1300,40"
echo "t060 studio | blender"; paste <("$PY" -I "$D/ice-study/px.py" "$D/ice-study/studio/today_lobby_t060.jpg" $P1) <("$PY" -I "$D/ice-study/px.py" "$D/ice-study/out/today_lobby_t060.png" $P1)
P2="715,42 704,178 688,322 1024,66 960,194 912,322 824,66 824,178"
echo "t005 studio | blender"; paste <("$PY" -I "$D/ice-study/px.py" "$D/ice-study/studio/today_lobby_t005.jpg" $P2) <("$PY" -I "$D/ice-study/px.py" "$D/ice-study/out/today_lobby_t005.png" $P2)
