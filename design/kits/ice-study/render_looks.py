"""Step 2: three looks of the new ice, as stills from the game camera on the lobby stone and the meadow.
  blender -b --factory-startup --python-exit-code 1 --python render_looks.py -- <out dir> [look numbers]
Look 1: the new blades in today's Glacier layout, in the game's four blues.
Look 2: the same, in the reference's pale glass tones, a little more see-through.
Look 3: the reference's flower: one centre, long blades leaning far out (a new layout table).
"""
import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
WANT = [int(v) for v in args[1:]] or [1, 2, 3]
os.makedirs(OUT, exist_ok=True)

from ice_layout import FLOWER, FLOWER_CENTRE, GAME_BLUES, PALE_GLASS  # noqa: E402

LOOKS = {
    1: {"palette": GAME_BLUES, "table": None, "centre": S.GLACIER_CENTRE, "transparency": 0.1},
    2: {"palette": PALE_GLASS, "table": None, "centre": S.GLACIER_CENTRE, "transparency": 0.25},
    3: {"palette": PALE_GLASS, "table": FLOWER, "centre": FLOWER_CENTRE, "transparency": 0.25},
}

def clearance(objects):
    """How close the ice comes to the game camera, and to the line from the camera to the fighter's chest
    (kits-2: two crystals behind the thrower once put the camera inside the ice)."""
    from mathutils import Vector
    from mathutils.geometry import intersect_point_line
    cam, chest = Vector((0, 12.07, 7.74)), Vector((0, 0, 3))
    near_cam, near_line, back = 1e9, 1e9, -1e9
    for obj in objects:
        for v in obj.data.vertices:
            w = obj.matrix_world @ v.co
            near_cam = min(near_cam, (w - cam).length)
            point, share = intersect_point_line(w, cam, chest)
            share = min(max(share, 0.0), 1.0)
            near_line = min(near_line, (w - (cam + (chest - cam) * share)).length)
            back = max(back, w.y)
    return {"to_camera": round(near_cam, 2), "to_sight_line": round(near_line, 2), "furthest_behind_thrower": round(back, 2)}


result = {"renders": [], "pieces": {}}
for number in WANT:
    look = LOOKS[number]
    for kind in ("lobby", "meadow"):
        S._materials.clear()
        S.new_scene()
        S.ICE = look["palette"]
        kit = P.build_kit()
        if not result["pieces"]:
            result["pieces"] = {name: P.mesh_report(mesh) for name, mesh in kit.items()}
        S.floor(kind)
        S.fighter()
        S.game_camera()
        for t in (0.6,):
            made = S.glacier(kit, t, table=look["table"], centre=look["centre"], transparency=look["transparency"])
            if kind == "lobby":
                result.setdefault("clearance", {})[number] = clearance(made)
            path = os.path.join(OUT, f"look{number}_{kind}_t{int(round(t * 100)):03d}.png")
            S.render(path)
            result["renders"].append(path)
print("RESULT_JSON=" + json.dumps(result))
