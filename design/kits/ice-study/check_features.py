"""Step 4, by numbers: the new Glacier against reference C's measurements and against today's ice.
  blender -b --factory-startup --python-exit-code 1 --python check_features.py -- <old kit.glb>
Prints: blade count, leans and widths of the new flower; the cluster's width, height and depth; how close each
cluster comes to the game camera and to the thrower (today's numbers are the pass mark).
"""
import json
import math
import os
import statistics
import sys

import bpy
from mathutils import Vector
from mathutils.geometry import intersect_point_line

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import FLOWER, FLOWER_CENTRE  # noqa: E402

OLD = sys.argv[sys.argv.index("--") + 1]
# Reference C, measured on design/kits/ice-study/sheets/C_still_3600_grid.png (blade root at 700, 600):
REF = {"blades": 15, "leans": [4, 30, 38, 44, 55, 62, 74, 76, 79, 95], "width_over_height": 2.5,
       "broad_width": (0.16, 0.24), "needle_width": (0.05, 0.07)}


def extents(objects):
    cam, chest = Vector((0, 12.07, 7.74)), Vector((0, 0, 3))
    low, high = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    near_cam, near_line = 1e9, 1e9
    for obj in objects:
        for v in obj.data.vertices:
            w = obj.matrix_world @ v.co
            low = Vector((min(low[i], w[i]) for i in range(3)))
            high = Vector((max(high[i], w[i]) for i in range(3)))
            near_cam = min(near_cam, (w - cam).length)
            _point, share = intersect_point_line(w, cam, chest)
            share = min(max(share, 0.0), 1.0)
            near_line = min(near_line, (w - (cam + (chest - cam) * share)).length)
    return {"width": round(high.x - low.x, 1), "height": round(high.z, 1), "ahead_from": round(-high.y, 1), "ahead_to": round(-low.y, 1),
            "width_over_height": round((high.x - low.x) / high.z, 2), "to_camera": round(near_cam, 1),
            "to_sight_line": round(near_line, 2), "tris": sum(len(o.data.polygons) for o in objects), "pieces": len(objects),
            "blades_barely_poking_out_of_the_floor": sum(S.slivers(o.data, o.matrix_world) for o in objects),
            "blades_coming_out_of_the_floor_away_from_their_root": sum(S.detached(o.data, o.matrix_world) for o in objects)}


out = {"reference": REF}
S.new_scene()
old = S.load_kit(OLD)
out["today"] = extents(S.glacier(old, 0.6))

S._materials.clear()
S.new_scene()
kit = P.build_kit()
made = S.glacier(kit, 0.6, table=FLOWER, centre=FLOWER_CENTRE)
out["new"] = extents(made)

# Every blade of the flower, in the world: its lean from straight up and its length in studs.
blades = P.blade_list(kit)
rows = []
for obj, spec in zip(made, FLOWER):
    height, name = spec[2], spec[5]
    turn = obj.matrix_world.to_3x3().normalized()
    for axis, length, width, kind in blades[name]:
        world = (turn @ axis).normalized()
        rows.append({"piece": name, "kind": kind, "length": round(length * height, 1), "width": width,
                     "lean": round(math.degrees(math.acos(max(-1, min(1, world.z)))), 1)})
major = [r for r in rows if r["kind"] != "stub" and r["length"] >= 8.0]
leans = sorted(r["lean"] for r in major)
out["new_blades"] = {
    "all_shells": len(rows), "major (8 studs or longer, not stubs)": len(major),
    "lean_min": leans[0], "lean_median": statistics.median(leans), "lean_max": leans[-1],
    "leans_over_90 (point into the floor)": sum(1 for v in leans if v > 90),
    "broad_width_range": [min(r["width"] for r in rows if r["kind"] == "broad"), max(r["width"] for r in rows if r["kind"] == "broad")],
    "needle_width_range": [min(r["width"] for r in rows if r["kind"] == "needle"), max(r["width"] for r in rows if r["kind"] == "needle")],
    "longest": max(r["length"] for r in rows),
}
ref = sorted(REF["leans"])
out["reference_leans"] = {"min": ref[0], "median": statistics.median(ref), "max": ref[-1]}
print("RESULT_JSON=" + json.dumps(out))
