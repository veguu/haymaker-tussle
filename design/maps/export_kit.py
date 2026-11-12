"""Exports the scenery kit for Roblox: one GLB per family in out/gnomon/upload (under the 20 MB Open Cloud limit),
in REST pose (the wind rigs stay in the .blend), plus kit_manifest.json: every mesh's expected centre (Roblox axes,
x, y up, z = -Blender y) to align an import, each asset's base spot to set its pivot, and triangle counts.

    blender -b out/gnomon/props/gnomon_props.blend -P export_kit.py
"""
import json
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.join(HERE, "out", "gnomon", "upload")
os.makedirs(UP, exist_ok=True)
GROUPS = {"rocks": ("Kit_Rocks",), "ruins": ("Kit_Ruins",), "trees": ("Kit_Trees",), "plants": ("Kit_Bushes", "Kit_Plants"), "flowers": ("Kit_Flowers", "Kit_Pond")}

for arm in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
    arm.data.pose_position = "REST"
# the bake's facet mask ("kitmask") is a colour attribute: exported, it becomes vertex colour, which Roblox
# multiplies into the texture (rocks came out bright green, canopies near black). Never ship it.
for o in bpy.data.objects:
    if o.type == "MESH":
        for attr in list(o.data.color_attributes):
            o.data.color_attributes.remove(attr)
bpy.context.view_layer.update()

manifest = {"meshes": {}, "assets": {}}
for fam, cols in GROUPS.items():
    objs = [o for c in cols for o in bpy.data.collections[c].all_objects if o.type == "MESH" and o.get("kit_asset") != "Pond_Lily"]  # its stone ring is over 20k triangles; the map has its own pond
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs)
    path = os.path.join(UP, f"kit_{fam}.glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
        export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
        export_image_format="AUTO", export_skins=False, export_animations=False,
    )
    for o in objs:
        dg = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
        co = [o.matrix_world @ Vector(c) for c in o.bound_box]
        mid = [(min(c[k] for c in co) + max(c[k] for c in co)) / 2 for k in range(3)]
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        asset = o.get("kit_asset", o.name)
        spot = (o.parent.matrix_world.translation if o.parent else o.matrix_world.translation)
        manifest["meshes"][o.name] = {"family": fam, "asset": asset, "x": round(mid[0], 3), "y": round(mid[2], 3), "z": round(-mid[1], 3), "tris": tris}
        a = manifest["assets"].setdefault(asset, {"family": fam, "spot": [round(spot.x, 3), round(spot.z, 3), round(-spot.y, 3)], "tris": 0, "parts": []})
        a["tris"] += tris
        a["parts"].append(o.name)
    print("KIT", fam, round(os.path.getsize(path) / 1e6, 2), "MB", len(objs), "meshes", flush=True)
with open(os.path.join(UP, "kit_manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=1)
for name, a in sorted(manifest["assets"].items(), key=lambda kv: -kv[1]["tris"]):
    print(f"TRIS {name}: {a['tris']}")
