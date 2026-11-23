"""Which blades of the new Glacier lie nearly flat or dip under the floor (the owner asked about a thin sliver
on the ground at the flower's lower left, 2026-11-22).
  blender -b --factory-startup --python-exit-code 1 --python find_low_blades.py
For every blade: the row and piece it belongs to, its lean in the world, where its tip is (x: + = the thrower's
left on screen... printed as right/ahead/up in studs), and how much of the piece's mesh is under the floor.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import FLOWER, FLOWER_CENTRE  # noqa: E402

S.new_scene()
kit = P.build_kit()
made = S.glacier(kit, 0.6, table=FLOWER, centre=FLOWER_CENTRE)
blades = P.blade_list(kit)
rows = []
for number, (obj, spec) in enumerate(zip(made, FLOWER), start=1):
    height, name = spec[2], spec[5]
    under = sum(1 for v in obj.data.vertices if (obj.matrix_world @ v.co).z < -0.05)
    lowest = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
    turn = obj.matrix_world.to_3x3().normalized()
    root = obj.matrix_world @ Vector((0, 0, 0))
    for index, (axis, length, width, kind) in enumerate(blades[name]):
        world = (turn @ axis).normalized()
        tip = root + world * length * height
        lean = math.degrees(math.acos(max(-1, min(1, world.z))))
        rows.append({"row": number, "piece": name, "blade": index, "kind": kind, "lean": round(lean, 1),
                     "length": round(length * height, 1), "tip_right": round(-tip.x, 1), "tip_ahead": round(-tip.y, 1),
                     "tip_up": round(tip.z, 1), "piece_verts_under_floor": under, "piece_lowest": round(lowest, 2)})
rows = [r for r in rows if r["tip_ahead"] < 5.0 or r["tip_up"] < 1.6]
rows.sort(key=lambda r: r["tip_ahead"])
print("RESULT_JSON=" + json.dumps(rows[:20]))
