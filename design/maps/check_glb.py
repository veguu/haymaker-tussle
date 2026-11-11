"""Re-imports an exported arena GLB into an empty scene and renders it, to prove the file itself (baked
and painted textures, normal and roughness maps, UVs, scale, orientation, every sight) is right, not
just the source scene. Each map is rendered with its own sun (its module's SUN). The cameras are the
map's own (its module is found from the GLB's file name: gnomon.glb -> gnomon.cameras()).

    blender -b --factory-startup -P check_glb.py -- <map.glb> <out folder> <prefix> [Camera ...]

With no camera names it renders them all.
"""
import importlib
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1 :]
glb, out, prefix = args[:3]
wanted = args[3:]
mod = importlib.import_module(os.path.splitext(os.path.basename(glb))[0])
C.reset()
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
surface = [o for o in meshes if o.name.startswith(("Deck", "Meadow", "Plaza_Tiles", "Rim_"))]
pts = [o.matrix_world @ Vector(v) for o in surface for v in o.bound_box]
print("MESHES", len(meshes), "SIGHT MESHES", sum(1 for o in meshes if o.name.startswith(("Sight_", "Below_"))))
print("SURFACE SPAN", round(max(p.x for p in pts) - min(p.x for p in pts), 1), "x", round(max(p.y for p in pts) - min(p.y for p in pts), 1), "top", round(max(p.z for p in pts), 3))
normals = sum(1 for o in meshes for m in o.data.materials if m and m.use_nodes and any(n.type == "NORMAL_MAP" for n in m.node_tree.nodes))
print("MATERIALS WITH NORMAL MAPS", normals)
C.sky_and_sun(*mod.SUN)
cams = mod.cameras()
if wanted:
    for name in list(cams):
        if name not in wanted:
            bpy.data.objects.remove(cams.pop(name))
for p in C.render_all(os.path.abspath(out), prefix, cams, (1280, 720)):
    print("RENDER", p)
