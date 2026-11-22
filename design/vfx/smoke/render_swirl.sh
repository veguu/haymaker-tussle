#!/usr/bin/env bash
# Renders the swirl puff sheet in Blender and puts it on a dark background to look at.
#   bash design/vfx/smoke/render_swirl.sh
set -e
cd "$(dirname "$0")/../../.."
FFMPEG=$(find "$LOCALAPPDATA/Microsoft/WinGet/Packages" -name ffmpeg.exe | head -1)
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python-exit-code 1 \
  --python design/vfx/smoke/smoke_swirl.py 2>&1 | grep -E "Error|Traceback|File |GROUND|SHEET" || true
"$FFMPEG" -hide_banner -loglevel error -y -f lavfi -i color=c=0x262a33:s=1024x1024 -i design/vfx/smoke/out/smoke_swirl.png \
  -filter_complex "[0][1]overlay,drawgrid=w=256:h=256:t=1:c=white@0.15" -frames:v 1 design/vfx/smoke/out/smoke_swirl_on_dark.png
echo DONE
