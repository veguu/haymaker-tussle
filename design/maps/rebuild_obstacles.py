"""Rebuilds only Gnomon's obstacle meshes in the saved scene (after obstacles.py changes heights or kinds,
not positions) and exports them on their own, for a small upload instead of a whole half.

    blender -b out/gnomon/gnomon.blend -P rebuild_obstacles.py

Writes out/gnomon/upload/gnomon_obstacles.glb and gnomon_obstacles_centres.json, and saves the .blend.
Run export_roblox.py afterwards to bring gnomon.glb and the two halves up to date.
"""
import json
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ["HT_MAP"] = "gnomon"
import gnomon as G  # noqa: E402

for name in ("Obstacles_Stone", "Obstacles_Wood"):
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)
G.build_obstacles(os.path.join(HERE, "out", "gnomon", "textures"))
objs = [bpy.data.objects[n] for n in ("Obstacles_Stone", "Obstacles_Wood")]
for o in bpy.context.view_layer.objects:
    o.select_set(o in objs)
up = os.path.join(HERE, "out", "gnomon", "upload")
path = os.path.join(up, "gnomon_obstacles.glb")
bpy.ops.export_scene.gltf(
    filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
    export_texcoords=True, export_normals=True, export_tangents=True, export_materials="EXPORT",
    export_image_format="AUTO",
)
centres = {}
for o in objs:
    co = [o.matrix_world @ Vector(c) for c in o.bound_box]
    mid = [(min(c[k] for c in co) + max(c[k] for c in co)) / 2 for k in range(3)]
    centres[o.name] = {"x": round(mid[0], 3), "y": round(mid[2], 3), "z": round(-mid[1], 3)}
with open(os.path.join(up, "gnomon_obstacles_centres.json"), "w", encoding="utf-8") as f:
    json.dump(centres, f, indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "out", "gnomon", "gnomon.blend"))
print("OBSTACLES", path, round(os.path.getsize(path) / 1e6, 2), "MB", centres)
