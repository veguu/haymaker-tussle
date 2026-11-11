"""Bakes a built arena for Roblox and exports it. Run on a .blend made by kitestead.py, gnomon.py or
saltcrest.py:

    blender -b --factory-startup <map>.blend -P export_roblox.py -- <export folder> <map name>

Meshes the build already painted (the surface tiles, the rim, the cliff, beams, brick and roof tiles: their
material reads an image) are exported as they are, with their colour, normal and roughness maps. Every
other mesh gets a UV unwrap and its procedural colour baked to a PNG (1024 for the big pieces, 64 for
single-colour ones). Then one GLB for the whole map (Y up, tangents for the normal maps, images
embedded). A manifest.json
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
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1 :]
OUT = os.path.abspath(args[0])  # relative paths resolve against the drive root inside Blender
NAME = args[1]
os.makedirs(OUT, exist_ok=True)

COLLIDE = ("Deck_", "Rim_", "Meadow_", "Plaza_Tiles_")
BIG = ("Deck", "Rim_", "Meadow", "Plaza_", "Underside_Beams", "Underside_Brick", "Strata_", "Below_Land", "Below_Sea", "Islands_", "Sundial_Island", "Eaves_", "Sight_Land")

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


def painted_maps(mat):
    """The images a painted material uses: {"colour": ..., "normal": ..., "mr": ...}, or None."""
    if not (mat and mat.use_nodes):
        return None
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is None or not bsdf.inputs["Base Color"].is_linked:
        return None
    src = bsdf.inputs["Base Color"].links[0].from_node
    if src.type != "TEX_IMAGE":
        return None
    maps = {"colour": src.image}
    if bsdf.inputs["Normal"].is_linked:
        nm = bsdf.inputs["Normal"].links[0].from_node
        if nm.type == "NORMAL_MAP" and nm.inputs["Color"].is_linked:
            maps["normal"] = nm.inputs["Color"].links[0].from_node.image
    if bsdf.inputs["Roughness"].is_linked:
        sep = bsdf.inputs["Roughness"].links[0].from_node
        if sep.inputs[0].is_linked:
            maps["mr"] = sep.inputs[0].links[0].from_node.image
    return maps


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


export_objs = [o for o in bpy.data.collections["Export"].objects if o.type == "MESH"]
manifest = {"map": NAME, "units": "1 Blender unit = 1 stud; fighting surface top at y = 0", "meshes": []}
baked_cache = {}

for obj in export_objs:
    mat = obj.data.materials[0]
    painted = painted_maps(mat)
    if painted:
        tris = triangles(obj)
        manifest["meshes"].append(
            {
                "name": obj.name,
                "triangles": tris,
                "textures": {k: os.path.basename(img.filepath) for k, img in painted.items()},
                "texture_size": painted["colour"].size[0],
                "can_collide": obj.name.startswith(COLLIDE),
                "within_limits": tris <= 20000 and len(obj.data.materials) == 1 and len(obj.data.uv_layers) == 1,
            }
        )
        print(f"PAINTED {obj.name}: {tris} tris, maps {sorted(painted)}")
        continue
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
    elif not obj.get("keep_uv"):  # terrains come with their own top-down UVs
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01)
        bpy.ops.object.mode_set(mode="OBJECT")
    if flat and mat.name not in baked_cache:
        # One colour: fill the whole image with it, so any unwrap that shares it is right everywhere.
        # The material's colour is linear; a PNG's pixels are sRGB. Writing the linear numbers straight
        # in (as passes 1-3 did) made every single-colour prop come out darker and harsher in the GLB.
        lin = list(mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value)
        colour = [c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055 for c in lin[:3]] + [1.0]
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
    export_tangents=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
)
manifest["glb"] = os.path.basename(glb)
manifest["all_within_limits"] = all(m["within_limits"] for m in manifest["meshes"])
with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=1)
print("GLB", glb, round(os.path.getsize(glb) / 1e6, 2), "MB")
print("ALL WITHIN LIMITS", manifest["all_within_limits"])

# --- the upload halves (2026-11-10 b) -------------------------------------------------------------
# Open Cloud takes 20 MB a file, so a map over that goes up as two Model assets: the arena (floor, rim,
# lip, cliff, timber, obstacles) and the backdrop. Each half's meshes and their expected centres (Roblox
# axes: x, y up, z = -Blender y; studs from the arena's centre on the floor's top) go to upload/, so the
# halves can be put back exactly in Studio whatever offset or turn the import gives them.
ARENA_PARTS = ("Meadow_", "Rim_", "Lip_", "Strata_", "Cliff_", "Obstacles_")
up_dir = os.path.join(os.path.dirname(OUT), "upload")
os.makedirs(up_dir, exist_ok=True)
centres = {}
# the sand cliff layers ride with the backdrop: the arena half alone came to 21 MB (2026-11-10 b)
def first_half(o):
    return o.name.startswith(ARENA_PARTS) and not o.name.startswith("Strata_Sand")


for i, part in ((1, [o for o in export_objs if first_half(o)]), (2, [o for o in export_objs if not first_half(o)])):
    for o in bpy.context.view_layer.objects:
        o.select_set(o in part)
    path = os.path.join(up_dir, f"{NAME}_{i}.glb")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
    )
    for o in part:
        co = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = [min(c[k] for c in co) for k in range(3)]
        hi = [max(c[k] for c in co) for k in range(3)]
        mid = [(lo[k] + hi[k]) / 2 for k in range(3)]
        centres[o.name] = {"half": i, "x": round(mid[0], 3), "y": round(mid[2], 3), "z": round(-mid[1], 3)}
    print("UPLOAD", path, round(os.path.getsize(path) / 1e6, 2), "MB", len(part), "meshes")
with open(os.path.join(up_dir, f"{NAME}_centres.json"), "w", encoding="utf-8") as f:
    json.dump(centres, f, indent=1)
