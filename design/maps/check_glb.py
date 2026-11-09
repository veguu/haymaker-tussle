"""Re-imports an exported arena GLB into an empty scene and renders it, to prove the file itself (baked
textures, UVs, scale, orientation) is right, not just the source scene.

    blender -b --factory-startup -P check_glb.py -- <map.glb> <out folder> <prefix>
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

glb, out, prefix = sys.argv[sys.argv.index("--") + 1 :][:3]
C.reset()
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
xs = [v[0] for o in meshes if o.name.startswith(("Deck", "Meadow", "Plaza_Tiles")) for v in o.bound_box]
ys = [v[1] for o in meshes if o.name.startswith(("Deck", "Meadow", "Plaza_Tiles")) for v in o.bound_box]
zs = [v[2] for o in meshes if o.name.startswith(("Deck", "Meadow", "Plaza_Tiles")) for v in o.bound_box]
print("MESHES", len(meshes))
print("SURFACE SPAN", round(max(xs) - min(xs), 1), "x", round(max(ys) - min(ys), 1), "top", round(max(zs), 2))
C.sky_and_sun()
cams = C.standard_cameras()
for name in ("Edge", "Overview"):
    bpy.data.objects.remove(cams.pop(name))
for p in C.render_all(out, prefix, cams, (960, 540)):
    print("RENDER", p)
