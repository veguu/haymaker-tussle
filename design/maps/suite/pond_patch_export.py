"""Exports ONLY the meshes studio_pond.py listed (pond_patch.json) from a Map 1 build, with base.export's glTF
settings, into <build>/export_pond/meadow_pond.glb: the pond's upload.

    blender -b out/suite/meadow_r6/meadow.blend -P pond_patch_export.py -- out/suite/meadow_r6
"""
import json
import os
import sys

import bpy

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
patch = json.load(open(os.path.join(out, "pond_patch.json"), encoding="utf-8"))["patch"]
missing = [n for n in patch if n not in bpy.data.objects]
if missing:
    raise SystemExit(f"not in the build's blend: {missing}")
for o in bpy.data.objects:  # base.export strips these too: Roblox would multiply a colour attribute in
    if o.type == "MESH":
        for attr in list(o.data.color_attributes):
            o.data.color_attributes.remove(attr)
bpy.context.view_layer.update()
for o in bpy.context.view_layer.objects:
    o.select_set(o.name in patch)
up = os.path.join(out, "export_pond")
os.makedirs(up, exist_ok=True)
path = os.path.join(up, "meadow_pond.glb")
bpy.ops.export_scene.gltf(
    filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
    export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
    export_image_format="AUTO", export_skins=False, export_animations=False,
)
tris = {n: len(bpy.data.objects[n].data.polygons) for n in patch}
print("PATCH GLB", path, round(os.path.getsize(path) / 1e6, 2), "MB", len(patch), "meshes", sum(tris.values()), "triangles", flush=True)
for n, t in tris.items():
    print("  ", n, t, flush=True)
