#!/usr/bin/env bash
# Frame sheets and preview videos for the two impact frames.
#   contact: 10 pencil frames at 24 fps (0.42 s); fist impact: 8 pencil frames at 24 fps (0.33 s)
#   impact_preview.mp4      real speed: contact, 0.4 s pause, fist impact
#   impact_preview_slow.mp4 the same at quarter speed
set -e
cd "$(dirname "$0")/out"
ffmpeg -v error -y $(for i in 00 01 02 03 04 05 06 07 08 09; do echo -n "-i contact_$i.png "; done) -filter_complex \
  "$(for i in $(seq 0 9); do echo -n "[$i]scale=512:288[c$i];"; done)[c0][c1][c2][c3][c4]hstack=5[r0];[c5][c6][c7][c8][c9]hstack=5[r1];[r0][r1]vstack" contact_sheet.png
ffmpeg -v error -y $(for i in 00 01 02 03 04 05 06 07; do echo -n "-i plunge_$i.png "; done) -filter_complex \
  "$(for i in $(seq 0 7); do echo -n "[$i]scale=640:360[p$i];"; done)[p0][p1][p2][p3]hstack=4[r0];[p4][p5][p6][p7]hstack=4[r1];[r0][r1]vstack" plunge_sheet.png
GRAPH="[0]fps=60,format=yuv420p[a];[1]fps=60,tpad=stop_mode=clone:stop_duration=0.2,format=yuv420p[b];[2]format=yuv420p[g];[a][g][b]concat=n=3:v=1"
ffmpeg -v error -y -framerate 24 -i contact_%02d.png -framerate 24 -i plunge_%02d.png -f lavfi -i color=c=black:s=1280x720:d=0.4:r=60 \
  -filter_complex "${GRAPH}[v]" -map "[v]" -c:v libx264 -crf 18 -pix_fmt yuv420p impact_preview.mp4
ffmpeg -v error -y -framerate 24 -i contact_%02d.png -framerate 24 -i plunge_%02d.png -f lavfi -i color=c=black:s=1280x720:d=0.4:r=60 \
  -filter_complex "${GRAPH},setpts=4*PTS[v]" -map "[v]" -r 60 -c:v libx264 -crf 18 -pix_fmt yuv420p impact_preview_slow.mp4
echo "previews written"
