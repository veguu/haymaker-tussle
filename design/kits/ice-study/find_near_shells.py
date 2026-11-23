"""Which blades have visible parts near the thrower's feet (the stray piece at the fighter's lower right).
  blender -b --factory-startup --python-exit-code 1 --python find_near_shells.py
Lists every blade (shell) with vertices above the floor inside the box: 0.5 to 5 studs to the right, 3 behind to
4 ahead of the thrower, under 3 studs up.
"""
import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import FLOWER, FLOWER_CENTRE  # noqa: E402

S.new_scene()
kit = P.build_kit()
made = S.glacier(kit, 0.6, table=FLOWER, centre=FLOWER_CENTRE)
out = []
for number, (obj, spec) in enumerate(zip(made, FLOWER), start=1):
    mesh = kit[spec[5]]
    world = [obj.matrix_world @ v.co for v in mesh.vertices]
    for index, shell in enumerate(S.shells(mesh)):
        pts = [world[i] for i in shell]
        inside = [p for p in pts if p.z > 0 and 0.5 < -p.x < 5 and -3 < -p.y < 4 and p.z < 3]
        if inside:
            above = [p for p in pts if p.z > 0]
            out.append({"row": number, "piece": spec[5], "shell": index, "verts_in_box": len(inside),
                        "verts_above_floor": len(above), "verts": len(pts), "top": round(max(p.z for p in pts), 2),
                        "right": [round(min(-p.x for p in above), 1), round(max(-p.x for p in above), 1)],
                        "ahead": [round(min(-p.y for p in above), 1), round(max(-p.y for p in above), 1)]})
print("RESULT_JSON=" + json.dumps(out))
