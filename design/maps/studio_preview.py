"""Packs an exported arena GLB so Roblox Studio can rebuild it in place with NO upload, for a look
under the game's own lighting before the real Import 3D step (roblox-3d-model skill, "Into Studio,
with no upload": AssetService EditableMesh + EditableImage, session-local, Edit mode only).

    blender -b --factory-startup -P studio_preview.py -- <map.glb> <out folder> [--scenery-px 512]

Writes <out>/index.json and one <name>.mesh.bin per mesh, plus <name>.tex.bin for textured ones
(single-colour meshes carry their colour in the index instead). Serve the folder with the skill's
serve_assets.py, then run studio_preview.lua through the Studio MCP.

Each mesh is centred on its own bounding box (the index holds the centre, Roblox axes, studs), since a
MeshPart sits on its mesh's centre. Blender Z-up -> Roblox Y-up is (x, y, z) -> (x, z, -y): a rotation,
so the winding is kept. Texture rows are written as Blender has them (see the skill for why).
The preview carries colour only: no normal or roughness maps.
"""
import json
import os
import struct
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1 :]
glb, out = os.path.abspath(args[0]), os.path.abspath(args[1])
scenery_px = int(args[args.index("--scenery-px") + 1]) if "--scenery-px" in args else 512
os.makedirs(out, exist_ok=True)
SURFACE = ("Meadow_", "Rim_", "Deck_", "Plaza_Tiles_", "Lobby_Floor")


def linear_to_srgb(c):
    c = np.clip(np.asarray(c, np.float64), 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
index = []
for obj in sorted((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: o.name):
    me = obj.data
    me.calc_loop_triangles()
    nv = len(me.vertices)
    co = np.empty((nv, 3), np.float64)
    me.vertices.foreach_get("co", co.ravel())
    mw = np.array(obj.matrix_world.to_4x4())
    co = co @ mw[:3, :3].T + mw[:3, 3]
    pos = np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)
    centre = (pos.min(axis=0) + pos.max(axis=0)) / 2.0
    pos = pos - centre
    uv = np.zeros((len(me.loops), 2), np.float64)
    if me.uv_layers.active:
        me.uv_layers.active.data.foreach_get("uv", uv.ravel())
    nt = len(me.loop_triangles)
    tv = np.empty((nt, 3), np.int32)
    tl = np.empty((nt, 3), np.int32)
    me.loop_triangles.foreach_get("vertices", tv.ravel())
    me.loop_triangles.foreach_get("loops", tl.ravel())
    quant = np.round(uv * 65535).astype(np.int64)
    _, first, inverse = np.unique(quant, axis=0, return_index=True, return_inverse=True)
    uniq_uv = uv[first]
    tri_uv = inverse.reshape(-1)[tl]
    blob = bytearray(struct.pack("<4sIIII", b"RMSH", 1, nv, len(uniq_uv), nt))
    blob += pos.astype("<f4").tobytes() + uniq_uv.astype("<f4").tobytes() + tv.astype("<u4").tobytes() + tri_uv.astype("<u4").tobytes()
    name = obj.name.replace(".", "_")
    with open(os.path.join(out, name + ".mesh.bin"), "wb") as f:
        f.write(blob)
    entry = {"name": name, "centre": [round(float(v), 4) for v in centre], "tris": nt, "collide": name.startswith(SURFACE)}
    img = None
    mat = me.materials[0] if me.materials else None
    if mat and mat.use_nodes:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf and bsdf.inputs["Base Color"].is_linked:
            src = bsdf.inputs["Base Color"].links[0].from_node
            img = src.image if src.type == "TEX_IMAGE" else None
        elif bsdf:
            entry["colour"] = [int(round(float(v) * 255)) for v in linear_to_srgb(list(bsdf.inputs["Base Color"].default_value)[:3])]
    if img is not None:
        w = img.size[0]
        px = np.array(img.pixels[:], np.float32).reshape(img.size[1], w, 4)
        if w <= 64:
            entry["colour"] = [int(round(float(v) * 255)) for v in np.clip(px[img.size[1] // 2, w // 2, :3], 0, 1)]
        else:
            n = w if name.startswith(SURFACE) else min(w, scenery_px)
            if n != w:
                img = img.copy()
                img.scale(n, n)
                px = np.array(img.pixels[:], np.float32).reshape(n, n, 4)
            # an 8-bit image's pixels are already sRGB-encoded: written as they are
            rgba = np.concatenate([(np.clip(px[:, :, :3], 0, 1) * 255.0).round().astype(np.uint8), np.full((n, n, 1), 255, np.uint8)], axis=2)
            with open(os.path.join(out, name + ".tex.bin"), "wb") as f:
                f.write(struct.pack("<4sI", b"RTEX", n) + rgba.tobytes())
            entry["tex"] = n
    index.append(entry)
    print("PACKED", name, nt, "tris", entry.get("tex", entry.get("colour")))
with open(os.path.join(out, "index.json"), "w", encoding="utf-8") as f:
    json.dump(index, f)
print("MESHES", len(index), "TRIS", sum(e["tris"] for e in index))
