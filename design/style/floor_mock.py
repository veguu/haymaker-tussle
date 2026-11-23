"""MOCK of the new FLOOR on Map 1 (owner 2026-11-22: the Racket Strikeout / Raise a Fairy look on the FLOORS ONLY,
"everything else should still be normal"; "obviously just one flat, maybe add some dirt tho where it makes sense, and
maybe add like studlike flowers, do it in blender first"; the arena is a CIRCLE).

    blender -b --factory-startup -P floor_mock.py -- <out folder> [--fast]

What it shows: Grassy Plains' real painted islands (design/maps/out/suite/meadow_r3, imported as they are) round a
CIRCULAR arena whose floor is ONE flat green with the owner's own stud texture (Raise a Fairy's stud-texture.png, one
raised square per stud: Raise a Fairy's scale, owner 2026-11-22 "scale down the studs ... the scale in the grow a fairy
game is a better representation"), dirt patches cut on the stud grid where fighters wear the ground (the middle, the
spawn ring), and stud-like flowers at real-life proportions: 0.14-stud blocks, nothing taller than 0.42 studs (below a fighter's
ankle), a stud printed on every block face (Raise a Fairy's Map Style: blocks stick out only where they add shape). The lip, soil and rock under it are meadow.py's own, rebuilt on the circle.
A mock only: nothing here is exported.
"""
import json
import math
import os
import random
import sys

RADIUS = 194.0  # the same area as the 213 x 176 oval (to be agreed)
HERE = os.path.dirname(os.path.abspath(__file__))
SUITE = os.path.abspath(os.path.join(HERE, "..", "maps", "suite"))
BUILD = os.path.abspath(os.path.join(HERE, "..", "maps", "out", "suite", "meadow_r3"))
STUDS = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", "Raise a Fairy", "Attachments", "Style", "stud-texture.png"))
FAST = "--fast" in sys.argv

meadow_path = os.path.join(SUITE, "meadow.py")
src = open(meadow_path, encoding="utf-8").read().replace("\r\n", "\n")
src = src[: src.rindex("\nrun(NAME")]
line = 'exec(compile(open(_p, encoding="utf-8").read(), _p, "exec"))'
assert src.count(line) == 1
src = src.replace(line, 'exec(compile(open(_p, encoding="utf-8").read().replace("A, B = 213.0, 176.0", "A, B = %r, %r" % (RADIUS, RADIUS)), _p, "exec"))')
g = {"__name__": "floor_mock", "__file__": meadow_path, "RADIUS": RADIUS}
exec(compile(src, meadow_path, "exec"), g)
assert g["A"] == RADIUS and g["B"] == RADIUS, "the circle did not take"

import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

C, K, P, W, OUT, NAME = g["C"], g["K"], g["P"], g["W"], g["OUT"], g["NAME"]
GRASS = (100, 180, 86)  # ONE flat green
DIRT = (172, 130, 92)
FLOWERS = [(255, 255, 255), (255, 156, 196), (255, 222, 96), (204, 166, 255)]

C.reset()
C.sky_and_sun(225, 38)
os.makedirs(g["TEX"], exist_ok=True)
g["edge"]()
g["crag"]()
g["flush"](NAME)
import addon_utils  # noqa: E402

addon_utils.enable("cycles", default_set=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.render.bake.target = "IMAGE_TEXTURES"
for asset, key, obj in g["REGISTRY"]:
    K["bake_paint"](obj, 128 if FAST else 512)
    print("PAINTED", obj.name, flush=True)


def lin(c):
    return tuple((v / 255.0) ** 2.2 for v in c) + (1.0,)


def stud_mat(name, rgb, studs_per_square=1.0):
    """A flat colour with the stud texture laid over it: the texture is mid grey (128) with a lit and a shaded bevel,
    so colour x (0.45 + 0.55 x texture / mid) keeps the flat colour and prints the studs."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.9
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    k = 1.0 / (8.0 * studs_per_square)  # the image holds 8 x 8 squares
    mp.inputs["Scale"].default_value = (k, k, k)
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(STUDS, check_existing=True)
    img.image.colorspace_settings.name = "Non-Color"
    img.extension = "REPEAT"
    img.projection = "BOX"  # every face of a block gets its studs, not only the top
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY_ADD"
    mul.inputs[1].default_value = 0.55 / (128.0 / 255.0)
    mul.inputs[2].default_value = 0.45
    sc = nt.nodes.new("ShaderNodeVectorMath")
    sc.operation = "SCALE"
    sc.inputs[0].default_value = lin(rgb)[:3]
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], img.inputs["Vector"])
    nt.links.new(img.outputs["Color"], mul.inputs[0])
    nt.links.new(mul.outputs[0], sc.inputs["Scale"])
    nt.links.new(sc.outputs["Vector"], p.inputs["Base Color"])
    return m


def plain_mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = lin(rgb)
    p.inputs["Roughness"].default_value = 0.85
    return m


def put(name, bm, m):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    return o


# --- the floor: one flat studded green, out to the lip ---------------------------------------------------------------
bm = bmesh.new()
n = 160
bm.faces.new([bm.verts.new((math.cos(i / n * math.tau) * (RADIUS + 0.1), math.sin(i / n * math.tau) * (RADIUS + 0.1), 0.0)) for i in range(n)])
put("MockFloor", bm, stud_mat("FloorGrass", GRASS))

# --- dirt where fighters wear it: the middle (the brawl) and the spawn ring, cut on the 2-stud stud grid ----------------
N = int(RADIUS // 2) + 1
ii, jj = np.meshgrid(np.arange(-N, N), np.arange(-N, N), indexing="ij")
X, Y = ii * 2.0 + 1.0, jj * 2.0 + 1.0
rad = np.hypot(X, Y)
noise = P.fbm2(X / 34.0 + 7.3, Y / 34.0 - 2.1, 5, 3)
fine = P.fbm2(X / 9.0 + 1.3, Y / 9.0 + 4.2, 9, 2)
v = noise + 0.12 * (fine - 0.5)
thr = np.full(X.shape, 0.69)
thr = np.where(rad < 52.0, 0.50 + 0.10 * (rad / 52.0), thr)  # the middle is worn most
ring = np.abs(rad - RADIUS * 0.65)
thr = np.where(ring < 14.0, np.minimum(thr, 0.585 + 0.03 * ring / 14.0), thr)  # where rounds start
dirt = (v > thr) & (rad < RADIUS - 12.0)
bm = bmesh.new()
for i, j in zip(*np.nonzero(dirt)):
    x0, y0 = float(ii[i, j] * 2.0), float(jj[i, j] * 2.0)
    bm.faces.new([bm.verts.new((x0 + dx, y0 + dy, 0.03)) for dx, dy in ((0, 0), (2, 0), (2, 2), (0, 2))])
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.001)
put("MockDirt", bm, stud_mat("FloorDirt", DIRT))
print("DIRT CELLS", int(dirt.sum()), "of", int((rad < RADIUS).sum()), flush=True)

# --- stud-like flowers at REAL proportions (owner 2026-11-22: "make proportions of the flowers SMALL, like ... an actual
# flower compared to a human in real life ... slightly below the roblox character's ankle"): a fighter is 5 studs, its
# ankle about 0.45 up, so nothing here is taller than 0.42. Little builds of 0.14-stud blocks on a 0.14 grid, one stud
# printed per block face (Raise a Fairy's rule), sown in drifts of one colour so they read from the camera. ---------
rng = random.Random(404)
bags = {}
U = 0.14  # one flower block
LEAF, LEAF_LIT, LEAF_DEEP = (70, 160, 74), (132, 206, 96), (52, 128, 66)
BLOOMS = [(255, 255, 255), (255, 150, 190), (255, 220, 92), (190, 150, 250)]
YOLK = (255, 206, 60)


def cube(rgb, x, y, z, s=U, h=None):
    """A block whose corner is at (x, y, z); no bottom face (it sits on the floor or on a block)."""
    b = bags.setdefault(rgb, bmesh.new())
    h = s if h is None else h
    vs = [b.verts.new((x + dx * s, y + dy * s, z + dz * h)) for dz in (0, 1) for dx, dy in ((0, 0), (1, 0), (1, 1), (0, 1))]
    for f in ((4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        b.faces.new([vs[q] for q in f])


def on_dirt(x, y):
    i, j = int(math.floor(x / 2.0)) + N, int(math.floor(y / 2.0)) + N
    return 0 <= i < 2 * N and 0 <= j < 2 * N and bool(dirt[i, j])


def tulip(x, y, bloom):  # a stem of one or two blocks, a bloom block: 0.28 to 0.42 tall
    hgt = rng.choice((1, 1, 2))
    cube(LEAF, x, y, 0.0, h=U * hgt)
    cube(bloom, x, y, U * hgt)


def daisy(x, y, bloom):  # a flat 2 x 2 of petals, a yolk block in the middle: 0.2 tall
    cube(bloom, x - U / 2, y - U / 2, 0.0, s=U * 2, h=U * 0.5)
    cube(YOLK, x, y, U * 0.5)


def tuft(x, y, _bloom):  # two or three blades of grass
    for dx, dy in rng.sample([(0, 0), (1, 0), (0, 1), (-1, 0)], rng.randint(2, 3)):
        cube(rng.choice((LEAF, LEAF_LIT, LEAF_DEEP)), x + dx * U, y + dy * U, 0.0, h=U * rng.choice((1, 2, 2.6)))


def snap(v):
    return round(v / U) * U


count = 0
# the close-up's fighter stands on grass (the nearest clear spot to (34, -58)) with a drift of flowers at its feet
SHOW = min(((float(X[i, j]), float(Y[i, j])) for i in range(X.shape[0]) for j in range(X.shape[1])
            if rad[i, j] < 120 and not dirt[max(0, i - 4):i + 5, max(0, j - 4):j + 5].any()),
           key=lambda q: math.hypot(q[0] - 34.0, q[1] + 58.0))
spots = [(SHOW[0] + 1.2, SHOW[1] + 1.0)] * 3 + [(22.0, 12.0), (-26.0, -2.0)]
for _c in range(150):
    a, r = rng.uniform(0, math.tau), RADIUS * math.sqrt(rng.uniform(0.01, 0.92))
    spots.append((math.cos(a) * r, math.sin(a) * r))
for cx, cy in spots:
    bloom = rng.choice(BLOOMS)
    spread = 1.6 if (cx, cy) == spots[0] else rng.uniform(2.0, 5.0)
    for _f in range(rng.randint(9, 20)):
        x, y = snap(cx + rng.gauss(0, spread)), snap(cy + rng.gauss(0, spread))
        if math.hypot(x, y) > RADIUS - 4 or on_dirt(x, y):
            continue
        rng.choices((tulip, daisy, tuft), weights=(4, 4, 3))[0](x, y, bloom if rng.random() < 0.85 else rng.choice(BLOOMS))
        count += 1
tris = 0
for rgb, b in bags.items():
    tris += len(b.faces) * 2
    put("MockFlowers_%d_%d_%d" % rgb, b, stud_mat("Flower_%d_%d_%d" % rgb, rgb, studs_per_square=U))
print("FLOWERS", count, "triangles", tris, "tallest", round(U * 3, 2), "studs", flush=True)

# --- everything else as it is: the real painted islands, their kit trees, the live lobby ---------------------------
NEAR = ("_Floor_", "_Lip_", "Map_Meadow_Soil_", "_Crag_", "_Core_", "_FieldGrass_")
col = g["preview_collection"]()
for f in sorted(os.listdir(os.path.join(BUILD, "export"))):
    if f.endswith(".glb"):
        for o in g["_import_glb"](os.path.join(BUILD, "export", f), col):
            if any(k in o.name for k in NEAR):
                bpy.data.objects.remove(o, do_unlink=True)
g["PLACE"].extend(json.load(open(os.path.join(BUILD, "placements.json"), encoding="utf-8")))
g["add_kit"]()
g["add_lobby"]()


def fighter(x, y, shirt, face):
    m_shirt, m_ink, m_skin = plain_mat("shirt", shirt), plain_mat("ink", (30, 32, 46)), plain_mat("skin", (240, 200, 160))
    for size, off, m in (((0.95, 0.95, 2.0), (-0.5, 0, 1.0), m_ink), ((0.95, 0.95, 2.0), (0.5, 0, 1.0), m_ink), ((2.0, 1.0, 2.0), (0, 0, 3.0), m_shirt),
                         ((0.95, 0.95, 2.0), (-1.5, 0, 3.0), m_shirt), ((0.95, 0.95, 2.0), (1.5, 0, 3.0), m_shirt), ((1.25, 1.25, 1.25), (0, 0, 4.65), m_skin)):
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.active_object
        o.scale = size
        v = Matrix.Rotation(face, 4, "Z") @ Vector(off)
        o.location = (x + v.x, y + v.y, v.z)
        o.rotation_euler = (0, 0, face)
        o.data.materials.append(m)


for (x, y, shirt, face) in ((0, -46, (52, 96, 214), 0.0), (-22, -6, (238, 96, 92), 2.6), (26, 8, (250, 206, 70), -2.2), (-66, 52, (60, 196, 200), 1.0),
                            (80, 40, (190, 150, 240), 3.6), (8, 92, (246, 146, 70), 0.3)):
    fighter(x, y, shirt, face)
fighter(SHOW[0], SHOW[1], (60, 170, 90), 0.5)

cams = {
    "Play": C.camera("Play", (3, -66, 12.5), (0, 60, 8.0), lens=20),
    "Feet": C.camera("Feet", (16, -64, 6.0), (-4, -40, 1.0), lens=28),
    "Ankle": C.camera("Ankle", (SHOW[0] + 5.5, SHOW[1] - 6.0, 1.5), (SHOW[0] + 0.6, SHOW[1] + 0.6, 0.75), lens=30),
    "Over": C.camera("Over", (230, -330, 250), (0, 40, -30), lens=24),
    "Lobby": C.camera("Lobby", W(-20, g["LOBBY_EDGE_Z"] + 8, g["LOBBY_FLOOR_Y"] + 6), W(0, -60, -14), lens=22),
    "Top": C.camera("Top", (0, -1, 520), (0, 0, 0), lens=28),
}
scene.cycles.samples = 12 if FAST else 40
try:
    scene.cycles.use_denoising = True
except AttributeError:
    pass
only = [a.split("=")[1].split(",") for a in sys.argv if a.startswith("--only=")]
if only:
    cams = {k: v for k, v in cams.items() if k in only[0]}
C.render_all(OUT, "floor", cams, resolution=(960, 540) if FAST else (1600, 900))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "floor_mock.blend"))
print("FLOOR MOCK DONE", flush=True)
