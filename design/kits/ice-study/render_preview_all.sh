#!/usr/bin/env bash
# Renders the eruption clips' frames, ONE CLIP AT A TIME (three at once ran 12 times slower on this PC:
# about 25 s a frame instead of 2).
# Usage: bash render_preview_all.sh [new|all|resume]
#   new    = the new ice only, from scratch (after a change to the pieces or the layout)
#   all    = today's ice as well, from scratch
#   resume = keep the frames that exist and render the missing ones
D="C:/Users/spicy/OneDrive/Documents/Haymaker Tussle/design/kits/ice-study"
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
run() { "$B" -b --factory-startup --python-exit-code 1 --python "$D/render_preview.py" -- "$1" "$2" "$D/out/preview" "$3" "$4" 2>&1 | grep -E "RESULT_JSON|Error|Traceback|rror:" | cut -c1-300; echo "$1 $2 exit=${PIPESTATUS[0]}"; }
if [ "$1" = "resume" ]; then
  export ICE_KEEP=1
  # the newest two frames of each clip may be half written: render them again
  for clip in today_meadow today_lobby new_meadow new_lobby; do
    ls "$D/out/preview/$clip"/f_*.png 2>/dev/null | tail -2 | while read -r f; do rm -f "$f"; done
  done
else
  rm -rf "$D/out/preview/new_meadow" "$D/out/preview/new_lobby"
  if [ "$1" = "all" ]; then rm -rf "$D/out/preview/today_meadow" "$D/out/preview/today_lobby"; fi
fi
run today meadow 960 540
run today lobby 960 540
run new meadow 1920 1080
run new lobby 1920 1080
for clip in today_meadow today_lobby new_meadow new_lobby; do echo "$clip $(ls "$D/out/preview/$clip" | wc -l) frames"; done
echo ALL_DONE
