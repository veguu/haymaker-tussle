"""Solid pieces for the Inferno and Beast kits (2026-11-15): a meteor, rock chunks and curved claws.

Run inside Blender (5.x):  exec(open(r"<this file>").read())
It builds everything in the scene "HT_Kits" (beside the ice kit, which it leaves alone) and exports
design/kits/out/export/rock_claw_kit.glb.

Same conventions as ice_kit.py: +Z up, one unit tall, flat shading, no texture; the tones are
vertex colours, which Roblox multiplies by the part's Color. A claw's root is at the origin and it
curves toward +X as it rises, so the game points it by turning it about its own axis. The meteor
and the chunks are centred on the origin.
"""

import math
import os
import random

import bmesh
import bpy

SCENE = "HT_Kits_RockClaw"  # a scene of its own, so the export holds only these pieces
OUT =os.path.join(os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\spicy\OneDrive\Documents\Haymaker Tussle\design\kits", "out", "export")
PREFIXES = ("Rock_", "Claw_")


def paint(bm, seed, low, high, by_height):
    """Vertex colours: each facet its own shade; with `by_height`, darker at the root."""
    rng = random.Random(seed)
    layer = bm.loops.layers.color.new("Col")
    top = max(v.co.z for v in bm.verts)
    bottom = min(v.co.z for v in bm.verts)
    span = max(top - bottom, 1e-6)
    for face in bm.faces:
        facet = rng.uniform(0.0, 1.0)
        for loop in face.loops:
            share = (loop.vert.co.z - bottom) / span if by_height else facet
            value = low + (high - low) * (share * 0.7 + facet * 0.3 if by_height else share)
            value = max(0.0, min(1.0, value))
            loop[layer] = (value, value, value, 1.0)


def rock(bm, seed, subdivisions, rough, squash):
    """A lumpy rock: an icosphere with every corner pushed in or out, one unit across."""
    rng = random.Random(seed)
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=0.5)
    for vert in bm.verts:
        scale = 1.0 + rng.uniform(-rough, rough)
        vert.co.x *= scale
        vert.co.y *= scale
        vert.co.z *= scale * squash
    # Back to exactly one unit tall, centred.
    top = max(v.co.z for v in bm.verts)
    bottom = min(v.co.z for v in bm.verts)
    middle = (top + bottom) / 2
    height = max(top - bottom, 1e-6)
    for vert in bm.verts:
        vert.co.z = (vert.co.z - middle) / height
        vert.co.x /= height
        vert.co.y /= height


def claw(bm, width, depth, curve, sides=4, rings=9):
    """A curved claw: a blade that narrows to a point and bends toward +X as it rises."""
    layers = []
    for ring in range(rings):
        u = ring / rings
        # Thickest a fifth of the way up, then a long taper.
        thick = (math.sin(math.pi * min(u / 0.4, 1.0) * 0.5) if u < 0.2 else 1.0) * (1.0 - u) ** 0.8
        bend = curve * u * u
        layer = []
        for index in range(sides):
            angle = math.tau * index / sides + math.pi / 4
            layer.append(bm.verts.new((bend + math.cos(angle) * width * thick, math.sin(angle) * depth * thick, u)))
        layers.append(layer)
    tip = bm.verts.new((curve, 0.0, 1.0))
    for lower, upper in zip(layers, layers[1:]):
        for index in range(sides):
            after = (index + 1) % sides
            bm.faces.new((lower[index], lower[after], upper[after], upper[index]))
    last = layers[-1]
    for index in range(sides):
        bm.faces.new((last[index], last[(index + 1) % sides], tip))
    bm.faces.new(list(reversed(layers[0])))


def make(name, build, seed, low, high, by_height):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    paint(bm, seed, low, high, by_height)
    bm.to_mesh(mesh)
    bm.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    material = bpy.data.materials.get("HT_Kit") or bpy.data.materials.new("HT_Kit")
    mesh.materials.append(material)
    return obj


PIECES = (
    # name, builder, seed, darkest, palest, shaded by height
    ("Rock_Meteor", lambda bm: rock(bm, 5, 2, 0.16, 0.92), 201, 0.5, 1.0, False),
    ("Rock_ChunkA", lambda bm: rock(bm, 9, 1, 0.3, 0.7), 203, 0.55, 1.0, False),
    ("Rock_ChunkB", lambda bm: rock(bm, 14, 1, 0.34, 1.0), 207, 0.55, 1.0, False),
    ("Claw_Blade", lambda bm: claw(bm, 0.07, 0.035, 0.34), 211, 0.55, 1.0, True),
    ("Claw_Fang", lambda bm: claw(bm, 0.15, 0.1, 0.22, sides=5, rings=7), 213, 0.5, 1.0, True),
)


def main():
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    for obj in list(scene.collection.objects):
        if obj.name.startswith(PREFIXES):
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.name.startswith(PREFIXES) and mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    made = []
    for index, (name, build, seed, low, high, by_height) in enumerate(PIECES):
        obj = make(name, build, seed, low, high, by_height)
        obj.location = (index * 1.4, 3.0, 0)
        scene.collection.objects.link(obj)
        made.append(obj)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "rock_claw_kit.glb")
    # Export this scene only: it holds nothing but these pieces. (Selecting objects in a scene that
    # is not the window's, under temp_override, took Blender 5.2 down; exporting the active scene
    # of the override does not.)
    layer = scene.view_layers[0]
    with bpy.context.temp_override(scene=scene, view_layer=layer):
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_active_scene=True, export_apply=True, export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=True)
    return {
        "path": path,
        "bytes": os.path.getsize(path),
        "pieces": {obj.name: {"tris": sum(len(p.vertices) - 2 for p in obj.data.polygons), "size": [round(v, 3) for v in obj.dimensions]} for obj in made},
    }


result = main()
