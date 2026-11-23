#!/usr/bin/env bash
# The flat puff beside its reference: a looping video at the reference's own timing and a sheet of stills.
#   bash design/vfx/smoke/preview_puff2d.sh
# Left: the reference (green-screen puff, 20 video frames at 30 fps, some drawings held for two).
# Right: out/puff2d_cells, scaled so the puff is as wide as the reference's and stands on the same ground line.
set -e
cd "$(dirname "$0")"
FFMPEG=$(find "$LOCALAPPDATA/Microsoft/WinGet/Packages" -name ffmpeg.exe | head -1)
REF=../smoke-study/refs-2026-11-22/puffB_frames
WORK=out/_puff2d_preview
rm -rf "$WORK" && mkdir -p "$WORK"
BG=0x262a33
# which of my drawings each of the 20 video frames shows (the reference holds 3, 7, 11 and 15 for two frames)
MINE=(0 1 2 3 3 4 5 6 7 7 8 9 10 11 11 12 13 14 15 15)
# my cell is 256 px with the puff 75 % wide (192 px); the reference puff is 506 px wide: scale by 2.64 -> 676 px.
# my ground line is at 128 + 58 = 186 px -> 491 px; the reference's is at 363 of 400: crop from 491 - 363 = 128.
for n in $(seq 0 19); do
  r=$(printf "%02d" $((n + 17)))
  m=$(printf "%02d" "${MINE[$n]}")
  o=$(printf "%02d" "$n")
  "$FFMPEG" -hide_banner -loglevel error -y -i "$REF/f_$r.png" -i "out/puff2d_cells/c_$m.png" -filter_complex \
    "color=c=$BG:s=580x400[bg1];color=c=$BG:s=580x400[bg2];[0]format=rgba,colorkey=0x1fe01f:0.35:0.05[ref];[bg1][ref]overlay=shortest=1[left];[1]scale=676:676:flags=lanczos,crop=580:400:48:128[me];[bg2][me]overlay=shortest=1[right];[left][right]hstack,drawbox=x=579:y=0:w=2:h=400:c=white@0.25:t=fill" \
    -frames:v 1 "$WORK/p_$o.png"
done
# a short empty beat, then again: 5 loops
for n in 20 21 22 23 24 25 26 27 28 29; do
  "$FFMPEG" -hide_banner -loglevel error -y -f lavfi -i "color=c=$BG:s=1160x400" -vf "drawbox=x=579:y=0:w=2:h=400:c=white@0.25:t=fill" -frames:v 1 "$WORK/p_$n.png"
done
"$FFMPEG" -hide_banner -loglevel error -y -stream_loop 5 -framerate 30 -i "$WORK/p_%02d.png" -pix_fmt yuv420p -crf 14 out/puff2d_vs_reference.mp4
"$FFMPEG" -hide_banner -loglevel error -y -stream_loop 2 -framerate 6 -i "$WORK/p_%02d.png" -pix_fmt yuv420p -crf 14 out/puff2d_vs_reference_slow.mp4
# stills: the 16 drawings, the reference above mine, two rows of eight
"$FFMPEG" -hide_banner -loglevel error -y -framerate 1 -i "$WORK/p_%02d.png" -vf "select='not(eq(n\,4)+eq(n\,9)+eq(n\,14)+eq(n\,19))*lt(n\,20)',crop=580:400:0:0,scale=240:-2,tile=8x2" -frames:v 1 "$WORK/ref_stills.png"
"$FFMPEG" -hide_banner -loglevel error -y -framerate 1 -i "$WORK/p_%02d.png" -vf "select='not(eq(n\,4)+eq(n\,9)+eq(n\,14)+eq(n\,19))*lt(n\,20)',crop=580:400:580:0,scale=240:-2,tile=8x2" -frames:v 1 "$WORK/my_stills.png"
"$FFMPEG" -hide_banner -loglevel error -y -i "$WORK/ref_stills.png" -i "$WORK/my_stills.png" -filter_complex "[0]pad=iw:ih+6:0:0:white[a];[a][1]vstack" out/puff2d_vs_reference_stills.png
rm -rf "$WORK"
echo "PREVIEW out/puff2d_vs_reference.mp4 out/puff2d_vs_reference_slow.mp4 out/puff2d_vs_reference_stills.png"
