"""Rebuilds ONLY a suite map's painted floor tiles and exports them as one GLB, with no full build (2026-11-21:
Quarry's tile seams, fixed by base.floor_tiles' painted margin):

    blender -b --factory-startup -P floor_only.py -- <out folder> <map>.py [builder]

Execs base.py, sketch_kit.py and the map's script without its last line (its sketch_run / run call), then calls the
map's floor builder (default `surface`, the one that calls floor_tiles), and exports every Map_<Name>_Floor_* mesh to
<out>/export/<map>_floor.glb with base.export's settings, plus <out>/floor_manifest.json (centres, arena-local, as in
manifest.json, so studio code can check each tile lands where the old one was).
"""
import json
import os
import sys

argv = sys.argv[sys.argv.index("--") + 1:]
out, script = os.path.abspath(argv[0]), argv[1]
builder = argv[2] if len(argv) > 2 else "surface"
here = os.path.dirname(os.path.abspath(__file__))
map_path = script if os.path.isabs(script) else os.path.join(here, script)

# base.py reads its out folder from the arguments after "--": give it ours (a full build, not --dry)
sys.argv = [sys.argv[0], "--", out]
src = open(map_path, encoding="utf-8").read().rstrip()
last = src.rfind("\n")
if not (src[last + 1:].startswith("sketch_run(") or src[last + 1:].startswith("run(")):
    raise SystemExit(f"{script}: expected its last line to be sketch_run(...) or run(...)")
G = {"__name__": "floor_only", "__file__": map_path}
exec(compile(src[:last], map_path, "exec"), G)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

G["C"].reset()
G[builder]()
name = G["NAME"]
floor = sorted((o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(f"Map_{name}_Floor_")), key=lambda o: o.name)
if not floor:
    raise SystemExit("no floor meshes were built")
for o in floor:
    for attr in list(o.data.color_attributes):
        o.data.color_attributes.remove(attr)
bpy.context.view_layer.update()
for o in bpy.context.view_layer.objects:
    o.select_set(o in floor)
up = os.path.join(out, "export")
os.makedirs(up, exist_ok=True)
path = os.path.join(up, f"{name.lower()}_floor.glb")
bpy.ops.export_scene.gltf(
    filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
    export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
    export_image_format="AUTO", export_skins=False, export_animations=False,
)
man = {"map": name, "file": os.path.basename(path), "mb": round(os.path.getsize(path) / 1e6, 2), "meshes": {}}
for o in floor:
    co = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = [min(c[k] for c in co) for k in range(3)]
    hi = [max(c[k] for c in co) for k in range(3)]
    mid = [(lo[k] + hi[k]) / 2 for k in range(3)]
    man["meshes"][o.name] = {"x": round(mid[0], 3), "y": round(mid[2], 3), "z": round(-mid[1], 3),
                             "tris": sum(len(p.vertices) - 2 for p in o.data.polygons)}
json.dump(man, open(os.path.join(out, "floor_manifest.json"), "w", encoding="utf-8", newline="\n"), indent=1)
print("FLOOR DONE", man["file"], man["mb"], "MB", len(floor), "meshes", flush=True)
