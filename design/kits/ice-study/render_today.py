"""Today's five ice pieces as the game shows them, rendered headless (2026-11-22):
  blender -b --factory-startup --python-exit-code 1 --python render_today.py -- <kit.glb> <out dir> <prefix>
Makes <prefix>_lobby_t005/t012/t060/t118.png and <prefix>_meadow_t060.png from the game camera (to set beside
the Studio captures of the same moments), and <prefix>_pieces.png: each piece from four sides, white Color.
"""
import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_scene as S  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
GLB, OUT, PREFIX = args[0], args[1], args[2]
QUICK = len(args) > 3 and args[3] == "quick"
os.makedirs(OUT, exist_ok=True)

result = {"renders": []}
for kind, moments in ((("lobby", (0.05, 0.6)),) if QUICK else (("lobby", (0.05, 0.12, 0.6, 1.18)), ("meadow", (0.05, 0.6)))):
    S._materials.clear()
    S.new_scene()
    kit = S.load_kit(GLB)
    S.floor(kind)
    S.fighter()
    S.game_camera()
    for t in moments:
        made = S.glacier(kit, t)
        path = os.path.join(OUT, f"{PREFIX}_{kind}_t{int(round(t * 100)):03d}.png")
        S.render(path)
        result["renders"].append(path)
        S.remove(made)

if QUICK:
    print("RESULT_JSON=" + json.dumps(result))
    sys.exit(0)

# The pieces alone: four sides each, 8 studs tall, white part Color, on the lobby floor.
S._materials.clear()
S.new_scene(width=2000, height=1000)
kit = S.load_kit(GLB)
S.floor("lobby")
names = ["Ice_SpikeTall", "Ice_SpikeThick", "Ice_Clump", "Ice_Block", "Ice_Shard"]
info = {}
for column, name in enumerate(names):
    mesh = kit[name]
    low, high = S.bounds(mesh)
    info[name] = {"tris": sum(len(p.vertices) - 2 for p in mesh.polygons),
                  "size": [round(v, 3) for v in (high - low)],
                  "root_offset_xy": [round(v, 3) for v in ((low + high) / 2)[:2]], "z_min": round(low.z, 4)}
    attr = mesh["paint"]
    for row, yaw in enumerate((0, 90, 180, 270)):
        base = S.rooted(S.M4 @ S.Vector(((column - 2) * 11.0, row * 14.0 - 21.0, 0)), S.Vector((0, 0, 0)), 0, yaw)
        obj = S.place(mesh, base, 8.0, name=f"{name}_{yaw}")
        obj.data = mesh.copy()
        obj.data.materials.clear()
        obj.data.materials.append(S.ice_material(f"White_{name}_{yaw}", (255, 255, 255), attr, transparency=0))
cam = S.camera((0, 60, 34), (0, 0, 3), 38.0, "Sheet")
path = os.path.join(OUT, f"{PREFIX}_pieces.png")
S.render(path)
result["renders"].append(path)
result["pieces"] = info
print("RESULT_JSON=" + json.dumps(result))
