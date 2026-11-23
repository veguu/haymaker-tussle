"""A turntable sheet of the five new pieces: each one turned six ways (60 degrees apart) and from above, 8 studs
tall, in the game's ice colour (tone 3 of the pale palette) on the lobby stone.
  blender -b --factory-startup --python-exit-code 1 --python render_turntable.py -- <out dir>
Writes turn_<piece>.png (one row each); make_preview.sh stacks them.
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import PALE_GLASS  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1]
for name in ("Ice_SpikeTall", "Ice_SpikeThick", "Ice_Clump", "Ice_Block", "Ice_Shard"):
    S._materials.clear()
    S.new_scene(width=2400, height=560)
    S.ICE = PALE_GLASS
    kit = P.build_kit()
    S.floor("lobby")
    mesh = kit[name]
    low, high = S.bounds(mesh)
    step = max(high.x - low.x, high.y - low.y) * 8 + 2.5
    for index in range(7):
        x = (index - 3) * step
        top_view = index == 6
        base = S.rooted(S.M4 @ Vector((x, 0, 0)), Vector((0, 0, 0)), 0, index * 60 if not top_view else 0)
        obj = S.place(mesh, base, 8.0, name=f"{name}_{index}")
        obj.data = mesh.copy()
        obj.data.materials.clear()
        obj.data.materials.append(S.material_for("Col", 3, "own", 0.0))
        obj.visible_shadow = False
        if top_view:      # the last one lies tipped toward the camera, to show it from above
            from mathutils import Matrix
            obj.matrix_world = Matrix.Translation((x, 0, 4.2)) @ Matrix.Rotation(-1.2, 4, "X") @ Matrix.Translation((-x, 0, -4)) @ obj.matrix_world
    distance = step * 7 / (2 * 0.2126) / (2400 / 560) * 1.05 + 4
    S.camera((0, distance, 6.5), (0, 0, 4.0), 24.0, "Turn")
    S.render(os.path.join(OUT, f"turn_{name}.png"))
print("RESULT_JSON={}")
