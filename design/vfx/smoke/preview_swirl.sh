#!/usr/bin/env bash
# The swirl puff beside its reference: a looping video and a sheet of stills.
#   bash design/vfx/smoke/preview_swirl.sh
# Left: the reference (28 video frames at 30 fps = 0.93 s). Right: out/swirl_cells played as the GAME plays a
# flipbook: the 16 drawings evenly over the same 0.93 s. Same scale (my 256 px cell is 6.8 units = 680 reference px)
# and the same ground line and burst point.
set -e
cd "$(dirname "$0")"
FFMPEG=$(find "$LOCALAPPDATA/Microsoft/WinGet/Packages" -name ffmpeg.exe | head -1)
REF=../smoke-study/refs-2026-11-22/puffA_frames
WORK=out/_swirl_preview
rm -rf "$WORK" && mkdir -p "$WORK"
BG=0x262a33
pair() {  # reference frame file number, my drawing, output name
  "$FFMPEG" -hide_banner -loglevel error -y -i "$REF/f_$1.png" -i "out/swirl_cells/c_$2.png" -filter_complex \
    "color=c=$BG:s=608x560[bg1];color=c=$BG:s=608x560[bg2];[0]format=rgba,colorkey=0x1fe01f:0.35:0.05[ref];[bg1][ref]overlay=shortest=1[left];[1]scale=680:680:flags=lanczos,crop=608:560:36:57[me];[bg2][me]overlay=shortest=1[right];[left][right]hstack,drawbox=x=607:y=0:w=2:h=560:c=white@0.25:t=fill" \
    -frames:v 1 "$3"
}
# 56 frames at 60 fps: the reference changes every 2 frames, mine every 3.5
for n in $(seq 0 55); do
  r=$(printf "%02d" $((n / 2 + 5)))        # video frames 4-31 are files f_05-f_32
  m=$(printf "%02d" $((n * 16 / 56)))
  pair "$r" "$m" "$WORK/p_$(printf "%03d" "$n").png"
done
for n in $(seq 56 85); do  # an empty beat, then again
  "$FFMPEG" -hide_banner -loglevel error -y -f lavfi -i "color=c=$BG:s=1216x560" -vf "drawbox=x=607:y=0:w=2:h=560:c=white@0.25:t=fill" -frames:v 1 "$WORK/p_$(printf "%03d" "$n").png"
done
"$FFMPEG" -hide_banner -loglevel error -y -stream_loop 5 -framerate 60 -i "$WORK/p_%03d.png" -pix_fmt yuv420p -crf 14 out/swirl_vs_reference.mp4
"$FFMPEG" -hide_banner -loglevel error -y -stream_loop 2 -framerate 12 -i "$WORK/p_%03d.png" -pix_fmt yuv420p -crf 14 out/swirl_vs_reference_slow.mp4
# stills: my 16 drawings under the reference drawings they stand for
k=0
for f in 4 7 8 10 12 15 17 19 20 22 23 24 25 27 28 30; do
  pair "$(printf "%02d" $((f + 1)))" "$(printf "%02d" "$k")" "$WORK/s_$(printf "%02d" "$k").png"
  k=$((k + 1))
done
"$FFMPEG" -hide_banner -loglevel error -y -framerate 1 -i "$WORK/s_%02d.png" -vf "crop=608:560:0:0,scale=240:-2,tile=8x2" -frames:v 1 "$WORK/ref_stills.png"
"$FFMPEG" -hide_banner -loglevel error -y -framerate 1 -i "$WORK/s_%02d.png" -vf "crop=608:560:608:0,scale=240:-2,tile=8x2" -frames:v 1 "$WORK/my_stills.png"
"$FFMPEG" -hide_banner -loglevel error -y -i "$WORK/ref_stills.png" -i "$WORK/my_stills.png" -filter_complex "[0]pad=iw:ih+6:0:0:white[a];[a][1]vstack" out/swirl_vs_reference_stills.png
rm -rf "$WORK"
echo "PREVIEW out/swirl_vs_reference.mp4 out/swirl_vs_reference_slow.mp4 out/swirl_vs_reference_stills.png"
