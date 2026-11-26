"""MOCK scenes for the new style (owner 2026-11-22: the whole game restyled after Racket Strikeout; study in
../../../Style Study - Racket Strikeout.md). Not game assets: quick blocky builds rendered in EEVEE, for the mock
sheets only (mock_ui.py draws the HUD over them).

    blender -b --factory-startup -P mock_scenes.py -- <out folder>

Writes arena.png, lobby.png (1920 x 1080) and points.json (screen positions of heads and stalls, for the HUD).
His rulings kept: arenas float in OPEN SKY (no ocean), the arena is a CIRCLE, the same themes (Grassy Plains with its
village and windmill; the village lobby with its stalls), nothing from the lobby on the arena.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(OUT, exist_ok=True)
R = 194.0  # the circle: the same area as the 213 x 176 oval (to be agreed with the owner)

PAL = {
    "grass": (112, 204, 98), "grass_lit": (150, 222, 116), "grass_deep": (84, 178, 92), "rim": (255, 214, 74),
    "white": (255, 255, 255), "soil": (166, 110, 78), "soil_deep": (132, 84, 66), "stone": (136, 146, 176),
    "stone_deep": (108, 118, 152), "coral": (242, 110, 104), "lilac": (190, 152, 236), "teal": (64, 200, 204),
    "yellow": (250, 214, 84), "blue": (48, 92, 206), "navy": (30, 40, 110), "cream": (250, 240, 220),
    "wood": (186, 132, 88), "leaf": (72, 176, 96), "leaf_lit": (108, 204, 110), "pave": (246, 236, 214),
    "pave_b": (232, 218, 192), "skin": (240, 200, 160), "ink": (28, 30, 44), "orange": (246, 146, 70),
}
MATS = {}


def lin(c):
    return tuple((v / 255.0) ** 2.2 for v in c) + (1.0,)


def mat(key, studs=False, emit=0.0):
    name = key + ("_studs" if studs else "") + (f"_e{emit}" if emit else "")
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = lin(PAL[key])
    p.inputs["Roughness"].default_value = 0.9
    if "Specular IOR Level" in p.inputs:
        p.inputs["Specular IOR Level"].default_value = 0.1
    if emit:
        p.inputs["Emission Color"].default_value = lin(PAL[key])
        p.inputs["Emission Strength"].default_value = emit
    if studs:  # the faint embossed squares of the reference's floor: 4-stud tiles, a groove between them
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (0.5, 0.5, 0.5)
        br = nt.nodes.new("ShaderNodeTexBrick")
        br.offset = 0.0
        br.inputs["Scale"].default_value = 1.0
        br.inputs["Mortar Size"].default_value = 0.045
        br.inputs["Brick Width"].default_value = 1.0
        br.inputs["Row Height"].default_value = 1.0
        br.inputs["Color1"].default_value = lin(PAL[key])
        br.inputs["Color2"].default_value = lin(PAL[key])
        br.inputs["Mortar"].default_value = lin(tuple(int(v * 0.93) for v in PAL[key]))
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], br.inputs["Vector"])
        nt.links.new(br.outputs["Color"], p.inputs["Base Color"])
    MATS[name] = m
    return m


BAGS = {}  # material name -> bmesh: everything static is merged per material


def bag(m):
    return BAGS.setdefault(m.name, (bmesh.new(), m))[0]


def box(m, size, loc, rot_z=0.0, taper=1.0):
    """A box centred in x, y at loc, standing on loc.z; `taper` scales its top."""
    b = bag(m)
    sx, sy, sz = size
    mtx = Matrix.Translation(loc) @ Matrix.Rotation(rot_z, 4, "Z")
    vs = []
    for z, k in ((0.0, 1.0), (sz, taper)):
        for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(b.verts.new(mtx @ Vector((x * sx / 2 * k, y * sy / 2 * k, z))))
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        b.faces.new([vs[i] for i in f])


def roof(m, size, loc, rot_z=0.0):
    """A gable roof (a triangular prism), its ridge along local x."""
    b = bag(m)
    sx, sy, sz = size
    mtx = Matrix.Translation(loc) @ Matrix.Rotation(rot_z, 4, "Z")
    pts = [(-sx / 2, -sy / 2, 0), (sx / 2, -sy / 2, 0), (sx / 2, sy / 2, 0), (-sx / 2, sy / 2, 0), (-sx / 2, 0, sz), (sx / 2, 0, sz)]
    vs = [b.verts.new(mtx @ Vector(p)) for p in pts]
    for f in ((0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)):
        b.faces.new([vs[i] for i in f])


def disc(m, r, z0, z1, n=96, centre=(0.0, 0.0), r_in=0.0):
    b = bag(m)
    cx, cy = centre
    ang = [i / n * math.tau for i in range(n)]
    o0 = [b.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, z0)) for a in ang]
    o1 = [b.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, z1)) for a in ang]
    if r_in > 0:
        i1 = [b.verts.new((cx + math.cos(a) * r_in, cy + math.sin(a) * r_in, z1)) for a in ang]
        for i in range(n):
            j = (i + 1) % n
            b.faces.new((o1[i], o1[j], i1[j], i1[i]))
            b.faces.new((o0[i], o0[j], o1[j], o1[i]))
    else:
        b.faces.new(o1)
        b.faces.new(list(reversed(o0)))
        for i in range(n):
            j = (i + 1) % n
            b.faces.new((o0[i], o0[j], o1[j], o1[i]))


def tree(x, y, z, s, rng):
    box(mat("wood"), (2.4 * s, 2.4 * s, 9 * s), (x, y, z))
    box(mat("leaf"), (11 * s, 11 * s, 7 * s), (x, y, z + 8 * s), rng.uniform(0, 1.5))
    box(mat("leaf_lit"), (7.5 * s, 7.5 * s, 5.5 * s), (x + rng.uniform(-1, 1) * s, y + rng.uniform(-1, 1) * s, z + 14 * s), rng.uniform(0, 1.5))


def house(x, y, z, w, d, h, rot, roof_key, wall="cream"):
    box(mat(wall), (w, d, h), (x, y, z), rot)
    roof(mat(roof_key), (w + 4, d + 5, d * 0.55), (x, y, z + h), rot)
    fwd = Matrix.Rotation(rot, 4, "Z") @ Vector((0, -d / 2 - 0.3, 0))
    box(mat("navy"), (w * 0.2, 0.8, h * 0.55), (x + fwd.x, y + fwd.y, z), rot)
    for k in (-0.3, 0.3):
        side = Matrix.Rotation(rot, 4, "Z") @ Vector((w * k, -d / 2 - 0.3, 0))
        box(mat("teal"), (w * 0.14, 0.8, h * 0.22), (x + side.x, y + side.y, z + h * 0.5), rot)


def island(cx, cy, top, r, depth, rng, cell=None, grass="grass"):
    """A stepped, blocky floating island: a grid of square columns inside a wobbly circle; grass caps, soil under
    them to uneven depths, stone hanging deeper toward the middle (the reference's overhead island, upside up)."""
    cell = cell or r / 4.5
    n = int(r / cell) + 1
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            x, y = cx + i * cell, cy + j * cell
            q = math.hypot(i, j) * cell / r
            if q > 1.0 + 0.12 * math.sin(i * 1.7 + j * 2.3):
                continue
            step = round(rng.uniform(-0.5, 0.5)) * cell * 0.12 if q > 0.55 else 0.0
            box(mat(grass), (cell, cell, cell * 0.3), (x, y, top - cell * 0.3 + step))
            d1 = depth * (0.25 + 0.3 * (1 - q)) * rng.uniform(0.7, 1.3)
            box(mat("soil" if rng.random() < 0.7 else "soil_deep"), (cell * 0.96, cell * 0.96, d1), (x, y, top - cell * 0.3 + step - d1))
            if q < 0.72:
                d2 = depth * (0.25 + 0.5 * (1 - q)) * rng.uniform(0.6, 1.3)
                box(mat("stone" if rng.random() < 0.6 else "stone_deep"), (cell * 0.9, cell * 0.9, d2), (x, y, top - cell * 0.3 + step - d1 - d2))


def cloud(x, y, z, s, rng):
    """A fat cumulus: overlapping flattened balls, a flat base (lit white, a pale blue underside from the light)."""
    for _ in range(rng.randint(6, 9)):
        rr = s * rng.uniform(0.45, 1.0)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=rr, location=(x + rng.uniform(-1.6, 1.6) * s, y + rng.uniform(-0.3, 0.3) * s, z + rr * 0.55 + rng.uniform(0, 0.5) * s))
        o = bpy.context.active_object
        o.scale = (1.25, 1.0, 0.72)
        bpy.ops.object.shade_smooth()
        o.data.materials.append(mat("white", emit=0.55))
        o.visible_shadow = False


def fighter(x, y, z, shirt, facing=0.0, pose=0.0):
    """A blocky 5-stud fighter, its own object (never merged), returns its head's position."""
    parts = []
    for name, size, off, key in (("legL", (0.95, 0.95, 2.0), (-0.5, 0, 0), "ink"), ("legR", (0.95, 0.95, 2.0), (0.5, 0, 0), "ink"),
                                 ("torso", (2.0, 1.0, 2.0), (0, 0, 2.0), shirt), ("armL", (0.95, 0.95, 2.0), (-1.5, 0, 2.0), shirt),
                                 ("armR", (0.95, 0.95, 2.0), (1.5, 0, 2.0), shirt), ("head", (1.25, 1.25, 1.25), (0, 0, 4.0), "skin")):
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.active_object
        o.scale = size
        v = Matrix.Rotation(facing, 4, "Z") @ Vector((off[0], off[1], off[2] + size[2] / 2))
        o.location = (x + v.x, y + v.y, z + v.z)
        o.rotation_euler = (pose if name == "armR" else 0.0, 0, facing)
        o.data.materials.append(mat(shirt if key == shirt else key))
        parts.append(o)
    return Vector((x, y, z + 5.6))


def flush():
    for name, (b, m) in BAGS.items():
        bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
        me = bpy.data.meshes.new(name)
        b.to_mesh(me)
        b.free()
        me.materials.append(m)
        bpy.context.scene.collection.objects.link(bpy.data.objects.new(name, me))
    BAGS.clear()


def scene_setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()
    sc = bpy.context.scene
    keys = bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys()
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in keys else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("Sky")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    mp = nt.nodes.new("ShaderNodeMapRange")
    mp.inputs["From Min"].default_value = -1.0
    mp.inputs["From Max"].default_value = 1.0
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], mp.inputs["Value"])
    nt.links.new(mp.outputs["Result"], ramp.inputs["Fac"])
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, lin((120, 190, 250))  # straight down: open sky, never a sea
    el[1].position, el[1].color = 1.0, lin((22, 96, 232))  # zenith
    for pos, c in ((0.42, (150, 208, 252)), (0.5, (176, 222, 254)), (0.62, (72, 150, 244))):
        e = ramp.color_ramp.elements.new(pos)
        e.color = lin(c)
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.15
    sd = bpy.data.lights.new("Sun", "SUN")
    sd.energy = 3.4
    sd.color = (1.0, 0.97, 0.9)
    sd.angle = math.radians(4)
    sun = bpy.data.objects.new("Sun", sd)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(46), 0, math.radians(-38))
    return sc


def camera(sc, loc, target, vfov=70.0):
    cd = bpy.data.cameras.new("Cam")
    cd.sensor_fit = "VERTICAL"
    cd.sensor_height = 24.0
    cd.lens = 12.0 / math.tan(math.radians(vfov / 2))
    cd.clip_start, cd.clip_end = 0.5, 30000
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    return cam


def screen(sc, cam, p):
    bpy.context.view_layer.update()
    v = world_to_camera_view(sc, cam, Vector(p))
    return [round(v.x * 1920, 1), round((1 - v.y) * 1080, 1), round(v.z, 1)]


def backdrop(rng, village_at=(-120, 1020), far_scale=1.0):
    """Grassy Plains' own islands, north (+y here): the village, THE windmill (the one big landmark), the farm, groves
    east and west, far islets. Blocky, flat colour, packed."""
    vx, vy = village_at
    island(vx, vy, 96, 270, 150, rng)
    roofs = ["coral", "teal", "yellow", "lilac", "blue"]
    for k in range(14):
        a = k / 14 * math.tau
        rr = rng.uniform(90, 200)
        x, y = vx + math.cos(a) * rr, vy + math.sin(a) * rr * 0.8
        house(x, y, 96, rng.uniform(48, 62), rng.uniform(36, 44), rng.uniform(32, 46), math.atan2(vy - y, vx - x) + math.pi / 2, roofs[k % 5])
    box(mat("cream"), (30, 30, 96), (vx + 20, vy + 60, 96))  # the chapel's tower
    roof(mat("blue"), (34, 34, 40), (vx + 20, vy + 60, 192))
    for _ in range(30):
        a, rr = rng.uniform(0, math.tau), rng.uniform(40, 245)
        tree(vx + math.cos(a) * rr, vy + math.sin(a) * rr * 0.85, 96, rng.uniform(2.4, 3.6), rng)
    # the windmill's island
    mx, my = -470, 800
    island(mx, my, 70, 130, 120, rng)
    z = 70
    for w, h, key in ((64, 70, "cream"), (54, 70, "white"), (44, 70, "cream")):
        box(mat(key), (w, w, h), (mx, my, z), 0.3, taper=0.86)
        z += h
    box(mat("coral"), (52, 52, 30), (mx, my, z), 0.3, taper=0.5)
    hub = Vector((mx + 8, my - 34, z - 6))
    box(mat("navy"), (12, 16, 12), (hub.x, hub.y, hub.z - 6), 0.3)
    for k in range(4):  # blades: a navy spar and a white sail, facing the arena
        a = math.radians(24 + 90 * k)
        d = Vector((math.cos(a), 0, math.sin(a)))
        rot = Matrix.Rotation(0.3, 4, "Z")
        for dist, key, size in ((70, "navy", (132, 5, 7)), (84, "white", (96, 3, 30))):
            bm = bag(mat(key))
            c = hub + rot @ (d * dist) + rot @ Vector((0, -6 if key == "white" else -3, 0))
            ax = rot @ d
            up = rot @ Vector((-d.z, 0, d.x))
            nrm = rot @ Vector((0, 1, 0))
            off = up * (12 if key == "white" else 0)
            vs = [bm.verts.new(c + off + ax * sx * size[0] / 2 + up * sz * size[2] / 2 + nrm * sy * size[1] / 2) for sy in (-1, 1) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
                bm.faces.new([vs[i] for i in f])
    for _ in range(8):
        a, rr = rng.uniform(0, math.tau), rng.uniform(50, 110)
        tree(mx + math.cos(a) * rr, my + math.sin(a) * rr, 70, rng.uniform(2.2, 3.0), rng)
    # the farm
    fx, fy = 520, 900
    island(fx, fy, 60, 230, 130, rng)
    for k in range(9):
        box(mat("yellow" if k % 2 == 0 else "grass_lit"), (150, 13, 2.5), (fx - 50, fy - 70 + k * 16, 60))
    house(fx + 110, fy + 40, 60, 60, 38, 30, 0.2, "coral", "wood")
    house(fx + 60, fy - 110, 60, 40, 28, 24, -0.3, "teal")
    for _ in range(10):
        a, rr = rng.uniform(0, math.tau), rng.uniform(120, 200)
        x, y = fx + math.cos(a) * rr, fy + math.sin(a) * rr
        if rng.random() < 0.5:
            box(mat("yellow"), (16, 16, 14), (x, y, 60), rng.uniform(0, 1), taper=0.6)
        else:
            tree(x, y, 60, rng.uniform(2.4, 3.2), rng)
    # groves east and west, far islets
    for (gx, gy, top, r) in ((760, 300, 20, 110), (-820, 260, 60, 120), (1500, 1500, 170, 170), (-1500, 1700, 200, 190), (300, 2300, 230, 220), (1250, 520, 120, 130), (-1300, 700, 150, 140)):
        island(gx, gy, top, r, r * 0.8, rng)
        for _ in range(9):
            a, rr = rng.uniform(0, math.tau), rng.uniform(0, r * 0.75)
            tree(gx + math.cos(a) * rr, gy + math.sin(a) * rr, top, rng.uniform(2.6, 3.6), rng)
        house(gx, gy, top, 40, 28, 26, rng.uniform(0, 3), rng.choice(roofs))


def clouds(rng):
    for (x, y, z, s) in ((-1900, 3600, 40, 420), (-600, 4200, 120, 520), (900, 3900, 60, 480), (2300, 3300, 160, 400),
                         (-3000, 2600, 260, 380), (3200, 2200, 300, 360), (300, 4600, 700, 300), (-1400, 4400, 900, 260),
                         (1900, 4300, 1000, 240), (-2600, 900, 500, 300), (2800, 700, 620, 300)):
        cloud(x, y, z, s, rng)


def arena():
    sc = scene_setup()
    rng = random.Random(7)
    # the fighting circle: flat greens, a lighter middle, white lines, a yellow rim (how close the edge is, at a glance)
    disc(mat("grass", studs=True), R, -6.0, 0.0, 128)
    disc(mat("grass_deep", studs=True), R - 12, 0.0, 0.04, 128, r_in=118)
    disc(mat("grass_lit", studs=True), 62, 0.0, 0.05, 96)
    disc(mat("white"), 62.8, 0.0, 0.06, 96, r_in=62)
    disc(mat("white"), 119.2, 0.0, 0.06, 128, r_in=118)
    disc(mat("rim"), R, 0.0, 0.07, 128, r_in=R - 11)
    disc(mat("white"), R - 11, 0.0, 0.08, 128, r_in=R - 12.2)
    # under it: a stepped, blocky island
    cell = 30.0
    for i in range(-7, 8):
        for j in range(-7, 8):
            x, y = i * cell, j * cell
            q = math.hypot(x, y) / R
            if q > 0.97:
                continue
            d1 = rng.uniform(18, 46) * (1.3 - q)
            box(mat("soil" if rng.random() < 0.7 else "soil_deep"), (cell * 0.98, cell * 0.98, d1), (x, y, -6 - d1))
            if q < 0.75:
                d2 = rng.uniform(30, 90) * (1.2 - q)
                box(mat("stone" if rng.random() < 0.6 else "stone_deep"), (cell * 0.92, cell * 0.92, d2), (x, y, -6 - d1 - d2))
    backdrop(rng)
    clouds(rng)
    heads = {}
    heads["you"] = fighter(0, -52, 0, "blue", 0.0, pose=-0.9)
    for name, (x, y, shirt, face) in {"Bot 7": (-26, -8, "coral", 2.6), "Kairo": (30, 6, "yellow", -2.2), "Nova": (-70, 60, "teal", 1.0),
                                      "Zed": (86, 44, "lilac", 3.6), "Rally": (10, 96, "orange", 0.3)}.items():
        heads[name] = fighter(x, y, 0, shirt, face, pose=-1.2)
    flush()
    cam = camera(sc, (3, -70, 12.5), (0, 60, 8.5))
    pts = {k: screen(sc, cam, v) for k, v in heads.items()}
    sc.render.filepath = os.path.join(OUT, "arena.png")
    bpy.ops.render.render(write_still=True)
    return pts


def lobby():
    sc = scene_setup()
    rng = random.Random(21)
    # the village lobby's plaza: a floating platform, cream paving in two tones, colour zones, white lines
    box(mat("pave", studs=True), (300, 240, 8), (0, 0, -8))
    for i in range(-3, 4):
        box(mat("pave_b", studs=True), (30, 232, 0.05), (i * 80, 0, 0))
    disc(mat("coral", studs=True), 46, 0, 0.08, 64)
    disc(mat("white"), 47.4, 0, 0.09, 64, r_in=46)
    box(mat("teal", studs=True), (300, 26, 0.07), (0, 104, 0))
    box(mat("white"), (300, 1.4, 0.1), (0, 90.6, 0))
    box(mat("rim"), (300, 6, 0.12), (0, 117, 0))
    for x in range(-140, 141, 35):  # the viewing rail
        box(mat("navy"), (2.4, 2.4, 9), (x, 119, 0))
    box(mat("navy"), (300, 1.6, 1.6), (0, 119, 8.4))
    cell = 40.0
    for i in range(-4, 5):
        for j in range(-3, 4):
            d1 = rng.uniform(16, 44)
            box(mat("soil" if rng.random() < 0.7 else "soil_deep"), (cell * 0.98, cell * 0.98, d1), (i * cell * 0.92, j * cell * 0.9, -8 - d1))
            if abs(i) < 3 and abs(j) < 2:
                d2 = rng.uniform(30, 80)
                box(mat("stone"), (cell * 0.9, cell * 0.9, d2), (i * cell * 0.92, j * cell * 0.9, -8 - d1 - d2))
    # the keepers' stalls: a counter, posts, a striped awning, a keeper
    stalls = {}
    for name, (x, y, rot, key) in {"SHOP": (-56, 30, -1.15, "yellow"), "CLASSES": (-64, -8, -1.4, "blue"), "RANKED": (56, 30, 1.15, "coral"),
                                   "MOVES": (64, -8, 1.4, "teal"), "QUESTS": (-36, 72, -0.45, "lilac"), "TRAINING": (36, 72, 0.45, "orange")}.items():
        m = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rot, 4, "Z") @ Matrix.Scale(1.25, 4)
        def at(v, m=m):
            p = m @ Vector(v)
            return (p.x, p.y, p.z)
        box(mat("wood"), (26, 7, 6.5), at((0, 0, 0)), rot)
        box(mat("white"), (27, 8, 0.8), at((0, 0, 6.5)), rot)
        for sx in (-12, 12):
            for sy in (-3, 9):
                box(mat("navy"), (1.2, 1.2, 17), at((sx, sy, 0)), rot)
        for s in range(8):
            box(mat(key if s % 2 == 0 else "white"), (3.4, 15, 1.2), at((-11.9 + s * 3.4, 3, 17)), rot)
        fighter(*at((0, 6, 0))[:2], 0, key, rot)
        stalls[name] = m @ Vector((0, 3, 25))
    for (x, y, w, d, h, rot, key) in ((-150, -60, 50, 36, 30, 0.2, "coral"), (150, -64, 54, 36, 34, -0.2, "teal"), (-60, -116, 46, 32, 28, 0.0, "lilac"),
                                      (64, -118, 48, 32, 30, 0.1, "yellow")):
        house(x, y, 0, w, d, h, rot, key)
    for (x, y, s) in ((-128, 84, 2.6), (128, 86, 2.8), (-30, -70, 2.2), (34, -74, 2.4), (-140, 10, 2.4), (140, 12, 2.2), (-118, 60, 1.6), (118, 62, 1.6)):
        tree(x, y, 0, s, rng)
    for x in (-112, 112, -8, 8):  # lamp posts
        box(mat("navy"), (1.6, 1.6, 22), (x * (1 if abs(x) > 30 else 9), 112, 0))
        box(mat("yellow", emit=1.5), (4.5, 4.5, 4.5), (x * (1 if abs(x) > 30 else 9), 112, 22))
    # the arena out past the rail, small, with its own backdrop
    off = Vector((0, 640, -40))
    disc(mat("grass"), R, off.z - 6, off.z, 96, centre=(off.x, off.y))
    disc(mat("grass_lit"), 62, off.z, off.z + 0.3, 64, centre=(off.x, off.y))
    disc(mat("rim"), R, off.z, off.z + 0.4, 96, centre=(off.x, off.y), r_in=R - 11)
    for i in range(-5, 6):
        for j in range(-5, 6):
            x, y = i * 38.0, j * 38.0
            q = math.hypot(x, y) / R
            if q < 0.95:
                d1 = rng.uniform(30, 110) * (1.3 - q)
                box(mat("soil" if q > 0.6 else "stone"), (36, 36, d1), (off.x + x, off.y + y, off.z - 6 - d1))
    island(-560, 1500, 60, 220, 130, rng)
    for k in range(8):
        a = k / 8 * math.tau
        house(-560 + math.cos(a) * 120, 1500 + math.sin(a) * 100, 60, 40, 28, 28, a, ["coral", "teal", "yellow", "lilac"][k % 4])
    island(620, 1400, 40, 200, 120, rng)
    for _ in range(14):
        a, rr = rng.uniform(0, math.tau), rng.uniform(0, 150)
        tree(620 + math.cos(a) * rr, 1400 + math.sin(a) * rr, 40, rng.uniform(2.6, 3.6), rng)
    clouds(rng)
    you = fighter(0, -28, 0, "blue", 0.0)
    flush()
    cam = camera(sc, (0, -46, 13.0), (0, 80, 9.5))
    pts = {k: screen(sc, cam, v) for k, v in stalls.items()}
    pts["you"] = screen(sc, cam, you)
    sc.render.filepath = os.path.join(OUT, "lobby.png")
    bpy.ops.render.render(write_still=True)
    return pts


points = {"arena": arena(), "lobby": lobby()}
json.dump(points, open(os.path.join(OUT, "points.json"), "w", encoding="utf-8"), indent=1)
print("SCENES DONE", flush=True)
