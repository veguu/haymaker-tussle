"""Renders Map 1's four floor options (meadow_floor_options.py) the way Roblox layers them: the calm colour map with the
repeating detail laid over it by its alpha (a Roblox Texture), plus the restyled static blades where the option has
them, R15-sized fighters for scale. EEVEE (a rasterizer, close to Roblox; Cycles mis-lights up-normal blades).

    blender -b --factory-startup -P meadow_floor_render.py -- <meadow_floor folder>

Writes render_<x>_{game,feet,wide}.png and meadow_floor_sheet.png (PIL).
"""
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
if "PIL" not in sys.modules:  # Blender's Python has no PIL; floor_options imports it only to save files
    import types

    _pil = types.ModuleType("PIL")
    _pil.Image = None
    sys.modules["PIL"] = _pil
import meadow_floor_options as MO  # noqa: E402

A, B = 213.0, 176.0
TILES = {"mossy": 40.0, "turf": 24.0}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
eng = bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys()
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("Sky")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.62, 0.92, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 2.6
sun_data.color = (1.0, 0.92, 0.82)
sun_data.angle = math.radians(3)
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(52), 0, math.radians(-135))

n = 256
me = bpy.data.meshes.new("Floor")
me.from_pydata([(A * math.cos(2 * math.pi * i / n), B * math.sin(2 * math.pi * i / n), 0.0) for i in range(n)], [], [list(range(n))])
me.update()
uv = me.uv_layers.new(name="UVMap")
for loop in me.loops:
    x, y, _ = me.vertices[loop.vertex_index].co
    uv.data[loop.index].uv = (x / (2 * A) + 0.5, y / (2 * B) + 0.5)
floor = bpy.data.objects.new("Floor", me)
scene.collection.objects.link(floor)


def floor_material(key):
    tile = TILES[key]
    mat = bpy.data.materials.new(f"Floor_{key}")
    mat.use_nodes = True
    nt = mat.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    outp = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.95
    base = nt.nodes.new("ShaderNodeTexImage")
    base.image = bpy.data.images.load(os.path.join(out, "base_green.png"))
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1 / tile, 1 / tile, 1 / tile)
    detail = nt.nodes.new("ShaderNodeTexImage")
    detail.image = bpy.data.images.load(os.path.join(out, f"detail_{key}.png"))
    detail.extension = "REPEAT"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], detail.inputs["Vector"])
    nt.links.new(detail.outputs["Alpha"], mix.inputs["Factor"])
    nt.links.new(base.outputs["Color"], mix.inputs["A"])
    nt.links.new(detail.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], outp.inputs["Surface"])
    return mat


def solid(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[(c / 255) ** 2.2 for c in rgb], 1.0)
    return m


def fighter(x, y, shirt, pants, skin):
    for name, size, z, m in (("legL", (0.9, 0.9, 2.0), 1.0, pants), ("legR", (0.9, 0.9, 2.0), 1.0, pants),
                             ("torso", (2.0, 1.0, 2.0), 3.0, shirt), ("head", (1.2, 1.2, 1.2), 4.65, skin),
                             ("armL", (0.9, 0.9, 2.0), 3.0, shirt), ("armR", (0.9, 0.9, 2.0), 3.0, shirt)):
        dx = {"legL": -0.5, "legR": 0.5, "armL": -1.45, "armR": 1.45}.get(name, 0.0)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x + dx, y, z))
        o = bpy.context.active_object
        o.scale = size
        o.data.materials.append(solid(name, m))


for (x, y, shirt) in ((-30, 40, (196, 52, 52)), (-10, 10, (52, 92, 210)), (30, 0, (232, 150, 40)), (-60, -20, (60, 170, 80)), (60, -50, (232, 214, 60))):
    fighter(x, y, shirt, (34, 40, 80), (210, 170, 140))

# --- the restyled blades: wider, greener (the islands' leaf_land), a narrow range; normals up, no shadow ----------
ROOT, TIP = (78, 128, 66), (146, 198, 104)


def blades(mode, seed=907):
    if mode == "none":
        return None
    rng = random.Random(seed)
    sp = 2.6 if mode == "drifts" else 3.0
    noise = MO.fbm(6, 95, 3, 512)  # drifts, about 70 studs across
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    normals = []
    wx, wz = 0.82, -0.57
    nx_, ny_ = int(2 * A / sp), int(2 * B / sp)
    for i in range(nx_):
        for j in range(ny_):
            x = -A + (i + 0.5 + rng.uniform(-0.45, 0.45)) * sp
            y = -B + (j + 0.5 + rng.uniform(-0.45, 0.45)) * sp
            rho = math.hypot(x / A, y / B)
            if rho > 0.99:
                continue
            if mode == "drifts":
                # the drift field shifted (-190, -150) so the views near the fighters show both drift and open ground
                d = noise[int(((y - 150) / (2 * B) + 0.5) * 511) % 512, int(((x - 190) / (2 * A) + 0.5) * 511) % 512]
                keep = MO.smooth(0.5, 0.6, d) + MO.smooth(0.86, 0.97, rho) * 0.8  # about 37% of the floor, more at the rim
                if rng.random() > keep:
                    continue
            shade = rng.uniform(0.92, 1.06)
            for _b in range(rng.randint(2, 3)):
                a, r = rng.uniform(0, math.tau), rng.uniform(0, 0.6)
                rx, ry = x + math.cos(a) * r, y + math.sin(a) * r
                lx, ly = math.cos(a) * 0.5 + wx, math.sin(a) * 0.5 - wz
                ln = math.hypot(lx, ly) or 1
                lx, ly = lx / ln, ly / ln
                lean, h, w = rng.uniform(0.2, 0.5), rng.uniform(1.1, 2.0), rng.uniform(0.55, 0.85)
                psi = math.atan2(ly, lx) + math.pi / 2 + rng.uniform(-0.5, 0.5)
                ex, ey = math.cos(psi) * w / 2, math.sin(psi) * w / 2
                tip = Vector((rx + lx * h * math.sin(lean), ry + ly * h * math.sin(lean), h * math.cos(lean)))
                pts = (Vector((rx - ex, ry - ey, -0.1)), Vector((rx + ex, ry + ey, -0.1)), tip)
                fn = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
                for side, order in ((1.0, (0, 1, 2)), (-1.0, (1, 0, 2))):
                    f = bm.faces.new([bm.verts.new(pts[q] + fn * side * 0.0015) for q in order])
                    for lp, q in zip(f.loops, order):
                        c = TIP if q == 2 else ROOT
                        lp[col] = (*[min(1.0, (v / 255) ** 2.2 * shade) for v in c], 1.0)
                    normals.append((Vector((0, 0, 1)) + fn * side * 0.15).normalized())
    me = bpy.data.meshes.new(f"Blades_{mode}")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.normals_split_custom_set([tuple(normals[p.index]) for p in me.polygons for _ in p.loop_indices])
    o = bpy.data.objects.new(f"Blades_{mode}", me)
    o.visible_shadow = False
    m = bpy.data.materials.new("Blade")
    m.use_nodes = True
    nt = m.node_tree
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    p = nt.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.95
    nt.links.new(attr.outputs["Color"], p.inputs["Base Color"])
    me.materials.append(m)
    print("BLADES", mode, len(me.polygons), "triangles", flush=True)
    return o


def cam(name, loc, tgt, lens):
    d = bpy.data.cameras.new(name)
    d.lens = lens
    d.clip_start = 0.1
    o = bpy.data.objects.new(name, d)
    scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return o


cams = {"game": cam("game", (-30, 62, 13), (10, -20, 0), 26), "feet": cam("feet", (-24, 34, 4.5), (-12, 22, 0.5), 30),
        "wide": cam("wide", (0, 320, 70), (0, -40, -10), 28)}
made = {}
for key, (title, pattern, mode) in MO.OPTIONS.items():
    floor.data.materials.clear()
    floor.data.materials.append(floor_material(pattern))
    if mode not in made:
        made[mode] = blades(mode)
    for m, o in made.items():
        if o is not None:
            if o.name not in scene.collection.objects:
                scene.collection.objects.link(o)
            o.hide_render = m != mode
    for view, c in cams.items():
        scene.camera = c
        scene.render.filepath = os.path.join(out, f"render_{key}_{view}.png")
        bpy.ops.render.render(write_still=True)

print("RENDERS DONE; the sheet: python meadow_floor_render.py --sheet <folder>", flush=True)
