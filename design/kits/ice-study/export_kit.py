"""Builds the five ice pieces, checks every one, saves a .blend and exports the GLB for Roblox.
  blender -b --factory-startup --python-exit-code 1 --python export_kit.py -- <out.glb> <out.blend>
Fails (exit 1) if any piece breaks a rule the game relies on. Run glb_report.py on the GLB afterwards: the
file, not the .blend, is what Roblox gets.
"""
import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
GLB, BLEND = args[0], args[1]
BUDGET = {"Ice_SpikeTall": 200, "Ice_SpikeThick": 300, "Ice_Clump": 650, "Ice_Block": 250, "Ice_Shard": 40}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
collection = bpy.data.collections.new("AI_IceKit_v2")
scene.collection.children.link(collection)
material = bpy.data.materials.new("HT_Ice")
kit = P.build_kit()
reports, failures, objects = {}, [], []
for column, name in enumerate(["Ice_SpikeTall", "Ice_SpikeThick", "Ice_Clump", "Ice_Block", "Ice_Shard"]):
    mesh = kit[name]
    mesh.name = name
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = (column * 2.5, 0, 0)     # apart in the .blend; a GLB node's translation does not move the mesh
    collection.objects.link(obj)
    objects.append(obj)
    rep = P.mesh_report(mesh)
    reports[name] = rep
    rules = {
        "closed (no non-manifold edges)": rep["non_manifold_edges"] == 0,
        "no loose geometry": rep["loose_verts"] == 0 and rep["loose_edges"] == 0,
        "no zero-area faces": rep["zero_area_faces"] == 0,
        "normals outward": rep["flipped_faces"] == 0,
        "triangles only": rep["ngons"] == 0,
        "stands on z = 0": abs(rep["z_min"]) < 1e-6,
        "exactly 1 unit tall": abs(rep["height"] - 1.0) < 1e-5,
        "bounding box centred on the origin": all(abs(v) < 1e-5 for v in rep["bbox_centre_xy"]),
        "one colour set, Col": rep["colour_sets"] == ["Col"],
        "colours between 0.64 and 1": rep["colour_min"] >= 0.639 and rep["colour_max"] <= 1.0,
        f"within {BUDGET[name]} triangles": rep["tris"] <= BUDGET[name],
        "has UVs": len(mesh.uv_layers) == 1,
        "flat shaded": not any(p.use_smooth for p in mesh.polygons),
    }
    for rule, ok in rules.items():
        if not ok:
            failures.append(f"{name}: {rule}")

os.makedirs(os.path.dirname(GLB), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
for obj in bpy.data.objects:
    obj.select_set(obj in objects)
bpy.context.view_layer.objects.active = objects[0]
bpy.ops.export_scene.gltf(
    filepath=GLB, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
    export_texcoords=True, export_normals=True, export_materials="EXPORT",
    export_vertex_color="NAME", export_vertex_color_name="Col", export_all_vertex_colors=False,
    export_active_vertex_color_when_no_material=True,
)
print("RESULT_JSON=" + json.dumps({"glb": GLB, "bytes": os.path.getsize(GLB), "blend": BLEND, "pieces": reports, "failures": failures}))
if failures:
    raise SystemExit("FAILED: " + "; ".join(failures))
