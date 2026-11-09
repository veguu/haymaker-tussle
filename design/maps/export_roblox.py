"""Bakes a built arena for Roblox and exports it. Run on a .blend made by kitestead.py, gnomon.py or
saltcrest.py:

    blender -b --factory-startup <map>.blend -P export_roblox.py -- <export folder> <map name>

For every mesh in the Export collection: a UV unwrap, its procedural colour baked to a PNG (1024 for the
big pieces, 64 for single-colour ones), the material swapped for one that uses that image, then one GLB
for the whole map (Y up, modifiers applied, images embedded) and the PNGs beside it. A manifest.json
lists every mesh with its triangle count, texture and whether it should collide in Roblox: only the
fighting surface and rim collide; everything else is scenery (CanCollide false), including Saltcrest's
eaves, which overhang the drop and must never be stood on.

Roblox limits checked (vault: "Exporting and Validating Models for Roblox"): 20,000 triangles and one
material per mesh, one UV set.
"""
import json
import os
import sys

import addon_utils
import bpy

args = sys.argv[sys.argv.index("--") + 1 :]
OUT = args[0]
NAME = args[1]
os.makedirs(OUT, exist_ok=True)

COLLIDE = ("Deck", "Rim_", "Meadow", "Plaza_Tiles")
BIG = ("Deck", "Rim_", "Meadow", "Plaza_", "Underside_Beams", "Underside_Brick", "Strata_", "Below_Land", "Below_Sea", "Islands_", "Sundial_Island", "Eaves_")

addon_utils.enable("cycles", default_set=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 1
scene.cycles.device = "CPU"
bake = scene.render.bake
bake.use_pass_direct = False
bake.use_pass_indirect = False
bake.use_pass_color = True
bake.margin = 16


def is_flat_colour(mat):
    """True if the material's base colour isn't driven by any node (a single colour)."""
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat and mat.use_nodes else None
    return bsdf is not None and not bsdf.inputs["Base Color"].is_linked


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


export_objs = [o for o in bpy.data.collections["Export"].objects if o.type == "MESH"]
manifest = {"map": NAME, "units": "1 Blender unit = 1 stud; fighting surface top at y = 0", "meshes": []}
baked_cache = {}

for obj in export_objs:
    mat = obj.data.materials[0]
    flat = is_flat_colour(mat)
    size = 64 if flat else (1024 if obj.name.startswith(BIG) else 512)
    # Single-colour materials share one tiny texture per material.
    if flat and mat.name in baked_cache:
        img = baked_cache[mat.name]
    else:
        img = bpy.data.images.new(f"{NAME}_{obj.name if not flat else mat.name}", size, size)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # UVs
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
    if obj.name.startswith(COLLIDE):
        # The fighting surface and rim: projected straight down, so the top fills the texture (about
        # 4.5 px per stud) instead of sharing it with the hidden bottom. Sides take the edge's colour,
        # which is right for the rims: their paint only changes along the edge, not with height.
        uv = obj.data.uv_layers.active.data
        half = 115.0
        for poly in obj.data.polygons:
            for li in poly.loop_indices:
                co = obj.data.vertices[obj.data.loops[li].vertex_index].co
                uv[li].uv = (co.x / (2 * half) + 0.5, co.y / (2 * half) + 0.5)
    else:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01)
        bpy.ops.object.mode_set(mode="OBJECT")
    if flat and mat.name not in baked_cache:
        # One colour: fill the whole image with it, so any unwrap that shares it is right everywhere.
        colour = list(mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value)
        img.pixels = colour * (size * size)
        img.filepath_raw = os.path.join(OUT, f"{img.name}.png")
        img.file_format = "PNG"
        img.save()
        baked_cache[mat.name] = img
    elif not flat:
        nt = mat.node_tree
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.nodes.active = tex
        bpy.ops.object.bake(type="DIFFUSE")
        nt.nodes.remove(tex)
        img.filepath_raw = os.path.join(OUT, f"{img.name}.png")
        img.file_format = "PNG"
        img.save()
    # swap in an image material, keeping roughness
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rough = bsdf.inputs["Roughness"].default_value
    new = bpy.data.materials.new(f"{obj.name}_Baked")
    new.use_nodes = True
    nb = new.node_tree.nodes["Principled BSDF"]
    nb.inputs["Roughness"].default_value = rough
    nb.inputs["Metallic"].default_value = 0.0
    tex = new.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    new.node_tree.links.new(tex.outputs["Color"], nb.inputs["Base Color"])
    obj.data.materials[0] = new
    tris = triangles(obj)
    manifest["meshes"].append(
        {
            "name": obj.name,
            "triangles": tris,
            "texture": f"{img.name}.png",
            "texture_size": size,
            "can_collide": obj.name.startswith(COLLIDE),
            "within_limits": tris <= 20000 and len(obj.data.materials) == 1 and len(obj.data.uv_layers) == 1,
        }
    )
    print(f"BAKED {obj.name}: {tris} tris, {size}px{' (shared)' if flat and mat.name in baked_cache and baked_cache[mat.name] is not img else ''}")

for o in bpy.context.view_layer.objects:
    o.select_set(o in export_objs)
glb = os.path.join(OUT, f"{NAME}.glb")
bpy.ops.export_scene.gltf(
    filepath=glb,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_texcoords=True,
    export_normals=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
)
manifest["glb"] = os.path.basename(glb)
manifest["all_within_limits"] = all(m["within_limits"] for m in manifest["meshes"])
with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=1)
print("GLB", glb, round(os.path.getsize(glb) / 1e6, 2), "MB")
print("ALL WITHIN LIMITS", manifest["all_within_limits"])
