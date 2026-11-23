"""The field grass clumps (owner, 2026-11-20: "I want that feel of you running through a grass field, shouldn't be
taller than the character, wind should also blow on it"; the earlier very low tufts were not liked).

    blender -b --factory-startup -P field_grass.py -- <out folder>

Four clump meshes, each a fan of folded blades round its ROOT (the pivot the game bends it about), knee to thigh
high on an R6 fighter (5 studs): no blade passes 2.6 studs. No texture: a per-vertex greyscale (dark root, light
tip, a lighter fold) that Roblox multiplies by the part's Color (MEASURED on Gnomon, 2026-11-11), so one mesh takes
any tint. About 240 triangles a clump, so a ring of them round the camera stays cheap.

WRITES <out>/field_grass.glb (meshes FieldGrass_A..D) and field_grass.png (a look at the four).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else os.path.join(os.path.dirname(__file__), "..", "out", "suite", "meadow", "grass"))
os.makedirs(OUT, exist_ok=True)

# name: (blades, footprint radius, height range, outward lean range in degrees, seed)
# Each clump spreads its roots over a disc wider than half the 4-stud grid, so neighbours overlap into one carpet
# (the first pass's clustered roots read as separate tufts with bare ground between).
VARIANTS = {
    # 2026-11-22 (measured in Studio: moving a clump costs about 5 microseconds a frame): bigger, fuller clumps on a
    # 6-stud grid, so fewer of them cover the field; roots over a disc wide enough that neighbours still overlap
    "FieldGrass_A": (40, 3.4, (1.2, 1.9), (10, 28), 1),  # short and full
    "FieldGrass_B": (40, 3.5, (1.5, 2.3), (8, 26), 2),  # the common one
    "FieldGrass_C": (38, 3.5, (1.8, 2.6), (6, 22), 3),  # tall
    "FieldGrass_D": (42, 3.6, (1.3, 2.4), (14, 34), 4),  # wide and floppy
}


def blade(bm, col, rng, root, height, lean_deg, width):
    """A folded blade: three levels (root, 55 %, tip), each level a left edge, a raised fold and a right edge, curving
    further out the higher it goes. Six triangles."""
    out = Vector((root.x, root.y, 0.0))
    if out.length < 1e-3:
        a = rng.uniform(0, math.tau)
        out = Vector((math.cos(a), math.sin(a), 0.0))
    out.normalize()
    out = (out + Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), 0))).normalized()
    side = Vector((-out.y, out.x, 0.0))
    lean = math.radians(lean_deg)
    pts = []
    for t in (0.0, 0.55, 1.0):
        bend = lean * (0.35 + 0.9 * t)  # more lean toward the tip: a curve, not a stick
        p = root + out * (math.sin(bend) * height * t * 0.9) + Vector((0, 0, math.cos(bend) * height * t))
        pts.append(p)
    levels = []
    for t, p, w in zip((0.0, 0.55), pts[:2], (width, width * 0.62)):
        fold = Vector((0, 0, 0)) + out * (-0.06 * w) + Vector((0, 0, 0.04))
        levels.append([bm.verts.new(p - side * w / 2), bm.verts.new(p + fold), bm.verts.new(p + side * w / 2)])
    tip = bm.verts.new(pts[2])
    shade = {}
    # light enough that root x the part's Color sits just under the painted floor (2026-11-22: 0.32 at the root read
    # as black stubble in Studio)
    for (l, r_, m), g in zip(levels, (0.62, 0.86)):
        shade[l], shade[r_], shade[m] = g, g, min(1.0, g + 0.06)
    shade[tip] = 1.0
    faces = []
    a, b = levels
    faces += [bm.faces.new((a[0], a[1], b[1], b[0])), bm.faces.new((a[1], a[2], b[2], b[1]))]
    faces += [bm.faces.new((b[0], b[1], tip)), bm.faces.new((b[1], b[2], tip))]
    for f in faces:
        for lp in f.loops:
            g = shade[lp.vert]
            lp[col] = (g, g * 1.0, g * 0.96, 1.0)


def build(name, spec):
    n, rad, (h0, h1), (l0, l1), seed = spec
    rng = random.Random(seed)
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    for i in range(n):
        r = rad * math.sqrt(rng.uniform(0.0, 1.0))
        a = rng.uniform(0, math.tau)
        root = Vector((math.cos(a) * r, math.sin(a) * r, 0.0))  # roots over the whole disc, tips fanning out
        h = rng.uniform(h0, h1)
        blade(bm, col, rng, root, h, rng.uniform(l0, l1), rng.uniform(0.22, 0.32))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.get("FieldGrass") or bpy.data.materials.new("FieldGrass")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.9
    at = nt.nodes.new("ShaderNodeVertexColor")
    at.layer_name = "Col"
    nt.links.new(at.outputs["Color"], bsdf.inputs["Base Color"])
    me.materials.append(mat)
    return obj


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    objs = [build(name, spec) for name, spec in VARIANTS.items()]
    for o in objs:
        print(o.name, sum(len(p.vertices) - 2 for p in o.data.polygons), "tris", tuple(round(d, 2) for d in o.dimensions), flush=True)
    for o in bpy.data.objects:
        if o is not None:
            o.select_set(o in objs)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "field_grass.glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_normals=True, export_vertex_color="ACTIVE", export_materials="EXPORT")
    # a look: the four side by side, then a little field of them (no texture, the green comes from the material)
    for i, o in enumerate(objs):
        o.location = (i * 5.0 - 7.5, 0, 0)
    scene = bpy.context.scene
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.7, 0.9, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (0.9, 0.2, -0.8)
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.location = (0, -12, 4)
    cam.rotation_euler = (math.radians(78), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    tint = bpy.data.materials["FieldGrass"].node_tree
    mix = tint.nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    mix.inputs[2].default_value = (0.25, 0.5, 0.18, 1)
    vc = next(nd for nd in tint.nodes if nd.type == "VERTEX_COLOR")
    bsdf = next(nd for nd in tint.nodes if nd.type == "BSDF_PRINCIPLED")
    tint.links.new(vc.outputs["Color"], mix.inputs[1])
    tint.links.new(mix.outputs[0], bsdf.inputs["Base Color"])
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 960, 400
    scene.render.filepath = os.path.join(OUT, "field_grass.png")
    bpy.ops.render.render(write_still=True)


main()
