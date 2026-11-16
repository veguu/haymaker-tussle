"""Solid ice for the Frost kit (2026-11-15): low-poly crystals, a freeze block and small shards.

Run inside Blender (5.x):  exec(open(r"<this file>").read())
It builds everything in its own scene ("HT_Kits") and exports design/kits/out/export/ice_kit.glb.
Nothing else in the open file is touched.

The look follows DonutLee1's "ICE ERUPTION" (YouTube nOloysSOoGY): a cluster of pointed crystals of
very different sizes leaning outward, faceted, darker at the root and near white at the tips. Each
mesh is one crystal (or a small clump), so the game lays clusters out itself and can reuse the same
pieces for the freeze block and for debris.

Conventions (as the maps' kit pieces): +Z up in Blender, root on the floor at the object's origin,
1 unit tall (the game sets the size), flat shading, NO texture: the tones are vertex colours, which
Roblox multiplies by the part's Color.
"""

import math
import os
import random

import bmesh
import bpy

SCENE = "HT_Kits"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\spicy\OneDrive\Documents\Haymaker Tussle\design\kits", "out", "export")


def crystal_rings(sides, radius, shoulder, lean, seed, tip_cut=0.0):
    """Rings of one crystal, root to tip: [(height, [(x, y), ...]), ...] and the tip point."""
    rng = random.Random(seed)
    twist = rng.uniform(0, math.tau)
    # An uneven cross-section: each corner at its own distance.
    corner = [radius * rng.uniform(0.72, 1.18) for _ in range(sides)]
    rings = []
    for height, scale in ((0.0, 0.78), (0.16, 1.0), (shoulder, 0.92)):
        ring = []
        for index in range(sides):
            angle = twist + math.tau * index / sides
            r = corner[index] * scale
            ring.append((math.cos(angle) * r + lean[0] * height, math.sin(angle) * r + lean[1] * height))
        rings.append((height, ring))
    tip_height = 1.0 - tip_cut
    tip = (lean[0] * tip_height + rng.uniform(-0.25, 0.25) * radius, lean[1] * tip_height + rng.uniform(-0.25, 0.25) * radius, tip_height)
    return rings, tip


def add_crystal(bm, origin, height, sides, radius, shoulder, lean, seed):
    """Adds one crystal to `bm`: a faceted prism that narrows to a point."""
    rings, tip = crystal_rings(sides, radius, shoulder, lean, seed)
    layers = []
    for ring_height, ring in rings:
        layers.append([bm.verts.new((origin[0] + x * height, origin[1] + y * height, origin[2] + ring_height * height)) for x, y in ring])
    top = bm.verts.new((origin[0] + tip[0] * height, origin[1] + tip[1] * height, origin[2] + tip[2] * height))
    faces = []
    for lower, upper in zip(layers, layers[1:]):
        for index in range(sides):
            after = (index + 1) % sides
            faces.append(bm.faces.new((lower[index], lower[after], upper[after], upper[index])))
    last = layers[-1]
    for index in range(sides):
        faces.append(bm.faces.new((last[index], last[(index + 1) % sides], top)))
    faces.append(bm.faces.new(list(reversed(layers[0]))))
    return faces


def paint(bm, seed, low=0.42, high=1.0):
    """Vertex colours by height (dark root, pale tip), each facet its own shade."""
    rng = random.Random(seed)
    layer = bm.loops.layers.color.new("Col")
    top = max(v.co.z for v in bm.verts)
    bottom = min(v.co.z for v in bm.verts)
    span = max(top - bottom, 1e-6)
    for face in bm.faces:
        facet = rng.uniform(-0.12, 0.12)
        for loop in face.loops:
            share = (loop.vert.co.z - bottom) / span
            value = max(0.0, min(1.0, low + (high - low) * share ** 1.3 + facet))
            # A little bluer in the dark, so the shadows stay saturated.
            loop[layer] = (value * 0.92, value * 0.97, min(1.0, value * 1.04), 1.0)


def make(name, build, seed):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    paint(bm, seed)
    bm.to_mesh(mesh)
    bm.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    material = bpy.data.materials.get("HT_Ice") or bpy.data.materials.new("HT_Ice")
    mesh.materials.append(material)
    return obj


def spike_tall(bm):
    add_crystal(bm, (0, 0, 0), 1.0, 6, 0.15, 0.62, (0.06, 0.02), 11)


def spike_thick(bm):
    add_crystal(bm, (0, 0, 0), 1.0, 5, 0.25, 0.55, (-0.05, 0.04), 23)
    # A second, shorter point growing out of its side.
    add_crystal(bm, (0.13, -0.05, 0.0), 0.62, 5, 0.2, 0.6, (0.3, -0.12), 29)


def clump(bm):
    add_crystal(bm, (0, 0, 0), 1.0, 6, 0.2, 0.6, (0.0, 0.05), 31)
    add_crystal(bm, (0.2, 0.08, 0), 0.7, 5, 0.22, 0.58, (0.42, 0.16), 37)
    add_crystal(bm, (-0.19, 0.1, 0), 0.6, 5, 0.24, 0.6, (-0.48, 0.2), 41)
    add_crystal(bm, (0.02, -0.2, 0), 0.5, 5, 0.26, 0.6, (0.06, -0.55), 43)


def block(bm):
    """The block a frozen fighter stands in: a thick, uneven column with a broken crown."""
    add_crystal(bm, (0, 0, 0), 1.0, 7, 0.4, 0.8, (0.02, -0.02), 53)
    add_crystal(bm, (0.2, 0.14, 0), 0.82, 5, 0.3, 0.7, (0.16, 0.12), 59)
    add_crystal(bm, (-0.22, -0.1, 0), 0.74, 5, 0.3, 0.7, (-0.18, -0.1), 61)


def shard(bm):
    """A chip of ice for debris: a small crystal pointed at both ends."""
    add_crystal(bm, (0, 0, 0.35), 0.65, 4, 0.34, 0.45, (0.05, 0.0), 71)
    faces = add_crystal(bm, (0, 0, 0.35), 0.35, 4, 0.3, 0.5, (0.0, 0.05), 73)
    for face in faces:
        for vert in face.verts:
            if vert.co.z > 0.35 + 1e-6:
                vert.co.z = 0.7 - vert.co.z
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)


PIECES = (
    ("Ice_SpikeTall", spike_tall, 101),
    ("Ice_SpikeThick", spike_thick, 103),
    ("Ice_Clump", clump, 107),
    ("Ice_Block", block, 109),
    ("Ice_Shard", shard, 113),
)


def main():
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    for obj in list(scene.collection.objects):
        if obj.name.startswith("Ice_"):
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.name.startswith("Ice_") and mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    made = []
    for index, (name, build, seed) in enumerate(PIECES):
        obj = make(name, build, seed)
        obj.location = (index * 1.2, 0, 0)
        scene.collection.objects.link(obj)
        made.append(obj)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "ice_kit.glb")
    # Export this scene only (the open file's own scene and its selection are left alone).
    layer = scene.view_layers[0]
    with bpy.context.temp_override(scene=scene, view_layer=layer):
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_active_scene=True, export_apply=True, export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=True)
    return {
        "path": path,
        "bytes": os.path.getsize(path),
        "pieces": {obj.name: {"tris": sum(len(p.vertices) - 2 for p in obj.data.polygons), "size": [round(v, 3) for v in obj.dimensions]} for obj in made},
    }


result = main()
