"""The chunk pieces (reference D) as the game uses them: a fighter frozen in Ice_Block (8 studs, see-through
0.4) and Ice_Shard debris (1 to 2.2 studs) thrown round them, from the game camera and close up.
  blender -b --factory-startup --python-exit-code 1 --python render_chunks.py -- <out dir>
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
from ice_layout import PALE_GLASS  # noqa: E402
TARGET = Vector((0, -7, 0))   # the frozen fighter, 7 studs ahead of the thrower

# Debris: (right, ahead of the target, height above the floor, size, tone, turn x, y, z in degrees)
SHARDS = [
    (-3.6, -1.0, 4.6, 2.0, 3, 40, 20, 10), (-2.0, -2.6, 6.6, 1.4, 4, 80, 130, 40), (1.0, -3.0, 7.4, 1.7, 2, 150, 60, 200),
    (3.2, -1.6, 5.4, 2.2, 3, 20, 200, 80), (4.6, 0.6, 3.4, 1.5, 4, 100, 30, 300), (-5.0, 0.4, 2.4, 1.6, 2, 60, 250, 120),
    (3.6, -3.4, 0.5, 2.0, 3, 90, 10, 60), (-2.8, -3.8, 0.45, 1.7, 4, 95, 80, 200), (1.0, -4.6, 0.4, 1.3, 2, 85, 160, 20),
    (-5.6, -2.2, 0.4, 1.4, 3, 100, 40, 310), (5.8, -1.8, 0.5, 1.8, 4, 80, 300, 150),
]

for kind in ("lobby", "meadow"):
    S._materials.clear()
    S.new_scene()
    S.ICE = PALE_GLASS
    kit = P.build_kit()
    S.floor(kind)
    S.fighter()
    S.fighter(tuple(TARGET))
    # The freeze block: KitModels.piece("Ice_Block", 8), ICE[3], Transparency 0.4, standing on the target's floor.
    base = S.rooted(S.M4 @ TARGET, Vector((0, 0, 0)), 0, 35)
    block = S.place(kit["Ice_Block"], base, 8.0, name="Block")
    block.data = kit["Ice_Block"].copy()
    block.data.materials.clear()
    block.data.materials.append(S.material_for("Col", 3, "own", 0.4))
    block.visible_shadow = False
    for index, (r, a, up, size, tone, rx, ry, rz) in enumerate(SHARDS):
        mesh = kit["Ice_Shard"].copy()
        mesh.materials.clear()
        mesh.materials.append(S.material_for("Col", tone, "own", 0.05))
        obj = bpy.data.objects.new(f"Shard{index}", mesh)
        turn = Euler((math.radians(rx), math.radians(ry), math.radians(rz))).to_matrix().to_4x4()
        middle = Matrix.Translation((0, 0, -0.5))
        obj.matrix_world = Matrix.Translation(TARGET + Vector((-r, -a, up))) @ turn @ Matrix.Scale(size, 4) @ middle
        obj.visible_shadow = False
        bpy.context.scene.collection.objects.link(obj)
    S.game_camera()
    S.render(os.path.join(OUT, f"chunks_{kind}_game.png"))
    S.camera((9.0, 3.5, 5.0), (0.0, -6.6, 3.4), 42.0, "Close")
    S.render(os.path.join(OUT, f"chunks_{kind}_close.png"))
print("RESULT_JSON={}")
