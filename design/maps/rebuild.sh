#!/usr/bin/env bash
# Rebuild one arena end to end: build + paint + renders, export GLB, re-import check renders.
#   bash rebuild.sh <map>            (kitestead | gnomon | saltcrest)
#   REUSE=1 bash rebuild.sh <map>    keep the painted surface and rim maps (only scenery changed)
set -e
cd "$(dirname "$0")"
B="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
m="$1"
"$B" -b --factory-startup -P "$m.py" -- "out/$m" ${REUSE:+--reuse-textures} > "out/${m}_build.log" 2>&1
"$B" -b --factory-startup "out/$m/$m.blend" -P export_roblox.py -- "out/$m/export" "$m" > "out/${m}_export.log" 2>&1
"$B" -b --factory-startup -P check_glb.py -- "out/$m/export/$m.glb" "out/$m" "glb_$m" > "out/${m}_check.log" 2>&1
grep -E "OVER LIMIT|FLAT" "out/${m}_build.log"
grep -E "^GLB|ALL WITHIN" "out/${m}_export.log"
grep -E "SPAN|NORMAL MAPS|MESHES" "out/${m}_check.log"
