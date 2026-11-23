"""MOCK of the new floor on the LOBBY (owner 2026-11-22: the stud look on "the arena floor, the lobby floor"; "the ones
with pattern should retain their pattern"). Opens floor_mock.py's saved scene (the live lobby is in it) and prints the
stud texture over the lobby's own floor paint: paving, walks, mats, zones, the medallion, Bell Rock's lawn. Nothing
else changes. One raised square per stud (Raise a Fairy's scale).

    blender -b out/floor/floor_mock.blend -P lobby_floor_mock.py
"""
import math
import os

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "floor")
STUDS = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", "Raise a Fairy", "Attachments", "Style", "stud-texture.png"))
FLOORS = ("Lobby_Paving", "Lobby_Walk_", "Lobby_Mats_", "Lobby_Zones_", "Lobby_Medallion_", "Lobby_BellRock_Grass", "Lobby_BellRock_Moss",
          "Lobby_BellRock_Path", "Lobby_Arena_Canvas", "Lobby_Arena_Clay", "Lobby_Arena_Teal")
img = bpy.data.images.load(STUDS, check_existing=True)
img.colorspace_settings.name = "Non-Color"
done = 0
for o in bpy.data.objects:
    if o.type != "MESH" or not o.name.startswith(FLOORS):
        continue
    for slot in o.material_slots:
        m = slot.material
        if m is None or not m.use_nodes or m.get("studded"):
            continue
        nt = m.node_tree
        p = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if p is None or not p.inputs["Base Color"].links:
            continue
        src = p.inputs["Base Color"].links[0].from_socket
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (0.125, 0.125, 0.125)  # 8 squares an image: one per stud
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.extension = "REPEAT"
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY_ADD"
        mul.inputs[1].default_value = 0.55 / (128.0 / 255.0)
        mul.inputs[2].default_value = 0.45
        sc = nt.nodes.new("ShaderNodeVectorMath")
        sc.operation = "SCALE"
        nt.links.new(geo.outputs["Position"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
        nt.links.new(tex.outputs["Color"], mul.inputs[0])
        nt.links.new(src, sc.inputs[0])
        nt.links.new(mul.outputs[0], sc.inputs["Scale"])
        nt.links.new(sc.outputs["Vector"], p.inputs["Base Color"])
        m["studded"] = True
        done += 1
print("STUDDED MATERIALS", done, flush=True)
scene = bpy.context.scene


def plain(rgb):
    m = bpy.data.materials.new("p")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = tuple((v / 255) ** 2.2 for v in rgb) + (1,)
    return m


def fighter(x, y, z, shirt, face):
    for size, off, rgb in (((0.95, 0.95, 2.0), (-0.5, 0, 1.0), (30, 32, 46)), ((0.95, 0.95, 2.0), (0.5, 0, 1.0), (30, 32, 46)), ((2.0, 1.0, 2.0), (0, 0, 3.0), shirt),
                           ((0.95, 0.95, 2.0), (-1.5, 0, 3.0), shirt), ((0.95, 0.95, 2.0), (1.5, 0, 3.0), shirt), ((1.25, 1.25, 1.25), (0, 0, 4.65), (240, 200, 160))):
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.active_object
        o.scale = size
        v = Matrix.Rotation(face, 4, "Z") @ Vector(off)
        o.location = (x + v.x, y + v.y, z + v.z)
        o.rotation_euler = (0, 0, face)
        o.data.materials.append(plain(rgb))


def cam(name, loc, target, lens):
    d = bpy.data.cameras.new(name)
    d.lens = lens
    d.clip_start, d.clip_end = 0.1, 20000
    o = bpy.data.objects.new(name, d)
    scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return o


# stand on the plaza's medallion (open floor): its centre and top from the mesh itself, not from whatever is above it
bpy.context.view_layer.update()
med = bpy.data.objects["Lobby_Medallion_Trim"]
pts = [med.matrix_world @ Vector(c) for c in med.bound_box]
cx, cy = sum(q.x for q in pts) / 8, sum(q.y for q in pts) / 8
z0 = max(q.z for q in pts)
print("MEDALLION", round(cx, 1), round(cy, 1), round(z0, 2), flush=True)
spots = [(cx + 4.0, cy - 6.0), (cx - 16.0, cy + 14.0)]
for (x, y), shirt, face in zip(spots, ((52, 96, 214), (238, 96, 92)), (0.3, 2.4)):
    fighter(x, y, z0, shirt, face)
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.cycles.samples = 40
for name, c in {"lobbyfloor_wide": cam("LW", (cx + 10, cy - 40, z0 + 11), (cx - 2, cy + 30, z0 + 2), 20),
                "lobbyfloor_feet": cam("LF", (cx + 11, cy - 15, z0 + 3.0), (cx + 4, cy - 6, z0 + 0.8), 30)}.items():
    scene.camera = c
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
print("LOBBY FLOOR DONE", flush=True)
