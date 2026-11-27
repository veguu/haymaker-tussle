"""Map 1's POND, four looks to choose from (owner 2026-11-26: "u could actually add the pond in the new map 1"). A MOCK:
nothing here is exported. It opens Map 1's own review scene (meadow_r5/meadow_review.blend: the studded floor, the
flowers, the islands, the light) and carves the old Gnomon pond into the middle of the circle.

    blender -b <out/suite/meadow_r5/meadow_review.blend> -P pond_options.py -- <out folder> [--fast] [--only=A,C]
    python pond_options_sheet.py <out folder>

THE SHAPE is the old Gnomon pond's exactly (tests/Pond.spec.luau, Core/Pond: 24 x 18 semi-axes with a gentle wobble,
1.6 deep, the water 0.55 under the floor), in the middle of the arena where the floor is worn to dirt. What the four
looks share: the hole in the floor is cut on the 2-stud grid like the dirt (a cell is basin if its centre is inside
the bank's rim), a sand shore, the stud print on the floor round it, the slowdown area unchanged (Core/Pond's
formula). What differs is the basin and the water:

  A  Stud terraces: the basin steps down in blocky ledges on the stud grid; the water is a studded turquoise plate,
     a little see-through, so the ledges show under it.
  B  Clear shallows: the old smooth bowl; the water is clear turquoise with a smooth shoreline, the studded sand bed
     under it.
  C  Lily pond: B's bowl and a deeper, less clear water, with block lily pads (some in bloom), reeds at three spots
     and block pebbles along the shore. Decoration only: nothing in it collides.
  D  Poster bands: flat colour like the Racket Strikeout seas: a pale shallow band round a deep blue middle, a white
     foam line at the edge, the shoreline cut on the stud grid; no studs on the water.
"""
import math
import os
import random
import sys
from collections import deque

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ARGV = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(ARGV[0])
FAST = "--fast" in ARGV
VIEWS = next((a.split("=", 1)[1].split(",") for a in ARGV if a.startswith("--views=")), ["fight", "wade", "over"])
ONLY = next((a.split("=", 1)[1].split(",") for a in ARGV if a.startswith("--only=")), ["A", "B", "C", "D"])
os.makedirs(OUT, exist_ok=True)

# --- the shape: Core/Pond's formula and the old Gnomon pond's numbers (Blender x, y; Roblox z = -y) ------------------
POND = dict(x=0.0, y=0.0, semiX=24.0, semiY=18.0, wobble=[(3, 0.08, 0.6), (5, 0.05, 2.1)], depth=1.6, inner=0.68, water=0.55)
RADIUS = 180.0
CELL = 2.0
W = POND["water"]


def smoothstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def rho(x, y):
    u, v = (x - POND["x"]) / POND["semiX"], (y - POND["y"]) / POND["semiY"]
    th = math.atan2(v, u)
    wob = 1.0 + sum(a * math.sin(k * th + ph) for k, a, ph in POND["wobble"])
    return math.hypot(u, v) / wob


def bed(x, y):
    return POND["depth"] * smoothstep(1.0, POND["inner"], rho(x, y))


def water_rho():
    lo, hi = POND["inner"], 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if POND["depth"] * smoothstep(1.0, POND["inner"], mid) > W:
            lo = mid
        else:
            hi = mid
    return lo


RHO_W = water_rho()


def outline_at(r, n=160):
    pts = []
    for k in range(n):
        th = k / n * math.tau
        wob = 1.0 + sum(a * math.sin(kk * th + ph) for kk, a, ph in POND["wobble"])
        pts.append((POND["x"] + math.cos(th) * POND["semiX"] * r * wob, POND["y"] + math.sin(th) * POND["semiY"] * r * wob))
    return pts


def centre(c):
    return (c[0] * CELL + CELL / 2, c[1] * CELL + CELL / 2)


BASIN = {(i, j) for i in range(-24, 24) for j in range(-24, 24) if rho(*centre((i, j))) < 1.0}
WATER = {c for c in BASIN if bed(*centre(c)) > W}
SHORE = BASIN - WATER
NB4 = ((1, 0), (-1, 0), (0, 1), (0, -1))

# --- the scene ----------------------------------------------------------------------------------------------------
scene = bpy.context.scene
grass_obj, dirt_obj = bpy.data.objects["Map_Meadow_Floor_Grass"], bpy.data.objects["Map_Meadow_Floor_Dirt"]
assert grass_obj.location.length < 1e-6 and dirt_obj.location.length < 1e-6
GRASS_MAT, DIRT_MAT = grass_obj.data.materials[0], dirt_obj.data.materials[0]

# the dirt cells as they are, read off the dirt mesh
dm = bmesh.new()
dm.from_mesh(dirt_obj.data)
bvh = BVHTree.FromBMesh(dm)
dm.free()
NN = int(RADIUS // CELL) + 1
DIRT = set()
for i in range(-NN, NN):
    for j in range(-NN, NN):
        cx, cy = centre((i, j))
        if math.hypot(cx, cy) < RADIUS - 8 and bvh.ray_cast(Vector((cx, cy, 1.0)), Vector((0, 0, -1)), 3.0)[0] is not None:
            DIRT.add((i, j))
n_dirt_before = len(DIRT)
DIRT -= BASIN
# no two cells of the floor's holes meeting only at a corner (the grass's fill needs one clean outline per hole)
for _ in range(64):
    hole = DIRT | BASIN
    pinch = set()
    for i, j in hole:
        for di, dj in ((1, 1), (1, -1)):
            if (i + di, j + dj) in hole and (i + di, j) not in hole and (i, j + dj) not in hole:
                pinch |= {(i + di, j), (i, j + dj)}
    if not pinch:
        break
    DIRT |= pinch
else:
    raise SystemExit("pinched corners left after 64 passes")


def lin(rgb):
    return tuple((c / 255.0) ** 2.2 for c in rgb)


def stud_mat(name, rgb, per=1.0, alpha=1.0, rough=0.9):
    """The floor's own stud material (one printed square per stud), recoloured; `per` = studs per printed square."""
    m = GRASS_MAT.copy()
    m.name = name
    nt = m.node_tree
    nt.nodes["Vector Math"].inputs[0].default_value = lin(rgb)
    k = 0.125 / per
    nt.nodes["Mapping"].inputs["Scale"].default_value = (k, k, k)
    p = nt.nodes["Principled BSDF"]
    p.inputs["Alpha"].default_value = alpha
    p.inputs["Roughness"].default_value = rough
    return m


def flat_mat(name, rgb, alpha=1.0, rough=0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = lin(rgb) + (1.0,)
    p.inputs["Alpha"].default_value = alpha
    p.inputs["Roughness"].default_value = rough
    return m


def put(name, bm, mat, coll, recalc=False):
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    return o


def new_coll(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c


def cell_edges(cells):
    """The outline of a set of cells as directed edges, counter-clockwise round each cell (its inside on the left)."""
    out = []
    for i, j in cells:
        x0, y0 = i * CELL, j * CELL
        for (di, dj), a, b in (((0, -1), (x0, y0), (x0 + CELL, y0)), ((1, 0), (x0 + CELL, y0), (x0 + CELL, y0 + CELL)),
                               ((0, 1), (x0 + CELL, y0 + CELL), (x0, y0 + CELL)), ((-1, 0), (x0, y0 + CELL), (x0, y0))):
            if (i + di, j + dj) not in cells:
                out.append((a, b))
    return out


def sheet(cells, z, bm=None, sub=1):
    """The cells as one flat sheet at height z (or z(x, y) if callable), each cell split sub x sub, shared corners."""
    bm = bm or bmesh.new()
    vs = {}
    h = CELL / sub

    def v(x, y):
        k = (round(x, 3), round(y, 3))
        if k not in vs:
            vs[k] = bm.verts.new((x, y, z(x, y) if callable(z) else z))
        return vs[k]

    for i, j in cells:
        for a in range(sub):
            for b in range(sub):
                x0, y0 = i * CELL + a * h, j * CELL + b * h
                bm.faces.new([v(x0, y0), v(x0 + h, y0), v(x0 + h, y0 + h), v(x0, y0 + h)])
    return bm


def skirt(bm, edges, z0, z1):
    """Walls down the outline (for water: never paper-thin from the side), facing out."""
    for a, b in edges:
        bm.faces.new([bm.verts.new((b[0], b[1], z0)), bm.verts.new((a[0], a[1], z0)), bm.verts.new((a[0], a[1], z1)), bm.verts.new((b[0], b[1], z1))])


# --- the floor round it: the circle with the dirt and the basin cut out, the dirt without the basin ----------------
gm = bmesh.new()
ring = [gm.verts.new((math.cos(k / 256 * math.tau) * (RADIUS + 0.1), math.sin(k / 256 * math.tau) * (RADIUS + 0.1), 0.0)) for k in range(256)]
for k in range(256):
    gm.edges.new((ring[k], ring[(k + 1) % 256]))
at = {}


def gv(p):
    k = (round(p[0], 3), round(p[1], 3))
    if k not in at:
        at[k] = gm.verts.new((p[0], p[1], 0.0))
    return at[k]


for a, b in cell_edges(DIRT | BASIN):
    gm.edges.new((gv(a), gv(b)))
bmesh.ops.triangle_fill(gm, use_beauty=True, use_dissolve=False, edges=gm.edges[:], normal=(0.0, 0.0, 1.0))
for f in gm.faces:
    if f.normal.z < 0:
        f.normal_flip()
area = sum(f.calc_area() for f in gm.faces)
disc = 0.5 * 256 * (RADIUS + 0.1) ** 2 * math.sin(math.tau / 256)
assert abs(area + len(DIRT | BASIN) * CELL * CELL - disc) < 1.0, ("the floor does not add up", area, disc)
gm.to_mesh(grass_obj.data)
gm.free()
dm = sheet(DIRT, 0.0)
bmesh.ops.triangulate(dm, faces=dm.faces[:])
dm.to_mesh(dirt_obj.data)
dm.free()
# the island's stone core has its top 0.3 under the floor (it fills the view under the floor's edge): under a basin
# it would fill the hole, so its top goes below the pond's bed (the real build needs the same)
core = bpy.data.objects["Map_Meadow_Core_Stone"]
cb = bmesh.new()
cb.from_mesh(core.data)
dropped = 0
for v in cb.verts:
    if v.co.z > -0.5:
        v.co.z = -POND["depth"] - 0.3
        dropped += 1
cb.to_mesh(core.data)
cb.free()
print("CORE top dropped", dropped, "verts", flush=True)
# no flower in or at the pond
for o in bpy.data.objects:
    if o.name.startswith("Map_Meadow_FloorFlowers_"):
        fb = bmesh.new()
        fb.from_mesh(o.data)
        gone = [v for v in fb.verts if rho(*(o.matrix_world @ v.co).xy) < 1.08]
        bmesh.ops.delete(fb, geom=gone, context="VERTS")
        fb.to_mesh(o.data)
        fb.free()
print(f"POND basin {len(BASIN)} cells ({len(WATER)} water, {len(SHORE)} shore), dirt {n_dirt_before} -> {len(DIRT)}, "
      f"water rho {RHO_W:.3f}", flush=True)

# --- colours (sRGB; the game's light lifts them, so they are retuned in a play test as the floor was) ---------------
SAND = (226, 200, 146)
WET = (178, 154, 110)
rng = random.Random(1126)


def on_outline(x, y):
    """Is this point on the basin's rim (it touches a cell that is not basin)?"""
    xs = [math.floor(x / CELL)] + ([x / CELL - 1] if abs(x / CELL - round(x / CELL)) < 1e-6 else [])
    ys = [math.floor(y / CELL)] + ([y / CELL - 1] if abs(y / CELL - round(y / CELL)) < 1e-6 else [])
    return any((int(round(i)), int(round(j))) not in BASIN for i in xs for j in ys)


def in_water_cell(x, y):
    xs = [math.floor(x / CELL)] + ([x / CELL - 1] if abs(x / CELL - round(x / CELL)) < 1e-6 else [])
    ys = [math.floor(y / CELL)] + ([y / CELL - 1] if abs(y / CELL - round(y / CELL)) < 1e-6 else [])
    return any((int(round(i)), int(round(j))) in WATER for i in xs for j in ys)


def bowl(lower=None):
    """The smooth bed (Core/Pond's formula) on a 1-stud grid, meeting the floor exactly at the rim; `lower` sinks
    every point of a water cell to at least that depth (for water cut on the grid: no bed poking through)."""
    def z(x, y):
        if on_outline(x, y):
            return 0.0
        d = bed(x, y)
        if lower is not None and in_water_cell(x, y):
            d = max(d, lower)
        return -d
    return z


def basin_smooth(coll, tag, lower=None, wet=WET):
    z = bowl(lower)
    put(f"Pond_{tag}_Shore", sheet(SHORE, z, sub=2), stud_mat(f"Pond_{tag}_Sand", SAND), coll)
    put(f"Pond_{tag}_Bed", sheet(WATER, z, sub=2), stud_mat(f"Pond_{tag}_Wet", wet), coll)
    return lambda x, y: z(x, y)


def water_smooth(coll, tag, rgb, alpha):
    pts = outline_at(RHO_W * 1.01)
    bm = bmesh.new()
    top = [bm.verts.new((x, y, -W)) for x, y in pts]
    bot = [bm.verts.new((x, y, -POND["depth"] - 0.1)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for k in range(len(pts)):
        m = (k + 1) % len(pts)
        bm.faces.new((top[k], bot[k], bot[m], top[m]))
    return put(f"Pond_{tag}_Water", bm, flat_mat(f"Pond_{tag}_Water", rgb, alpha, 0.35), coll, recalc=True)


# --- fighters for scale (floor_mock.py's block fighter, 5 studs tall) ------------------------------------------------
def fighter(coll, x, y, z, shirt, face):
    mats = flat_mat("ink", (30, 32, 46)), flat_mat("shirt", shirt), flat_mat("skin", (240, 200, 160))
    for size, off, m in (((0.95, 0.95, 2.0), (-0.5, 0, 1.0), 0), ((0.95, 0.95, 2.0), (0.5, 0, 1.0), 0), ((2.0, 1.0, 2.0), (0, 0, 3.0), 1),
                         ((0.95, 0.95, 2.0), (-1.5, 0, 3.0), 1), ((0.95, 0.95, 2.0), (1.5, 0, 3.0), 1), ((1.25, 1.25, 1.25), (0, 0, 4.65), 2)):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        r = Matrix.Rotation(face, 4, "Z")
        v = r @ Vector(off)
        bmesh.ops.transform(bm, matrix=Matrix.Translation((x + v.x, y + v.y, z + v.z)) @ r @ Matrix.Diagonal(Vector(size + (1.0,))), verts=bm.verts)
        put("Fighter", bm, mats[m], coll)


WADE = (5.0, 3.0)  # the wading fighter, near the deepest point


def fighters(coll, floor_z):
    fighter(coll, WADE[0], WADE[1], floor_z(*WADE), (52, 96, 214), 2.4)
    fighter(coll, -16.0, -22.0, 0.0, (238, 96, 92), -0.6)
    fighter(coll, 28.0, -7.0, 0.0, (250, 206, 70), 1.9)
    fighter(coll, -34.0, 12.0, 0.0, (60, 196, 200), -2.2)


# --- the four looks ----------------------------------------------------------------------------------------------
def look_a():
    """Stud terraces: every cell flat at a step of the bowl, risers between; a studded, slightly see-through plate."""
    coll = new_coll("Pond_A")
    step = 0.4
    lvl = {}
    for c in BASIN:
        d = round(bed(*centre(c)) / step) * step
        lvl[c] = max(d, W + 0.25) if c in WATER else min(d, step)
    for tag, cells, rgb in (("Shore", SHORE, SAND), ("Bed", WATER, WET)):
        bm = bmesh.new()
        for c in cells:
            x0, y0, z = c[0] * CELL, c[1] * CELL, -lvl[c]
            bm.faces.new([bm.verts.new(p) for p in ((x0, y0, z), (x0 + CELL, y0, z), (x0 + CELL, y0 + CELL, z), (x0, y0 + CELL, z))])
            for (di, dj), a, b in (((0, -1), (x0, y0), (x0 + CELL, y0)), ((1, 0), (x0 + CELL, y0), (x0 + CELL, y0 + CELL)),
                                   ((0, 1), (x0 + CELL, y0 + CELL), (x0, y0 + CELL)), ((-1, 0), (x0, y0 + CELL), (x0, y0))):
                up = -lvl.get((c[0] + di, c[1] + dj), 0.0)
                if up > z + 1e-6:  # a riser up to the shallower neighbour, facing into this cell
                    bm.faces.new([bm.verts.new(p) for p in ((a[0], a[1], up), (b[0], b[1], up), (b[0], b[1], z), (a[0], a[1], z))])
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
        put(f"Pond_A_{tag}", bm, stud_mat(f"Pond_A_{tag}", rgb), coll)
    bm = sheet(WATER, -W)
    skirt(bm, cell_edges(WATER), -W, -W - 0.3)
    put("Pond_A_Water", bm, stud_mat("Pond_A_Water", (70, 182, 218), alpha=0.82, rough=0.4), coll)
    fighters(coll, lambda x, y: -lvl.get((math.floor(x / CELL), math.floor(y / CELL)), 0.0))
    return coll


def look_b():
    """Clear shallows: the old smooth bowl, clear water with a smooth shoreline over the studded sand."""
    coll = new_coll("Pond_B")
    z = basin_smooth(coll, "B")
    water_smooth(coll, "B", (96, 200, 226), 0.55)
    fighters(coll, z)
    return coll


def blocks(bm_by_rgb, rgb, x, y, z, sx, sy, sz):
    b = bm_by_rgb.setdefault(rgb, bmesh.new())
    vs = [b.verts.new((x + dx * sx, y + dy * sy, z + dz * sz)) for dz in (0, 1) for dx, dy in ((0, 0), (1, 0), (1, 1), (0, 1))]
    for f in ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        b.faces.new([vs[q] for q in f])


def look_c():
    """Lily pond: B's bowl, deeper-looking water, block lily pads, reeds and pebbles (decoration, no collision)."""
    coll = new_coll("Pond_C")
    z = basin_smooth(coll, "C", wet=(150, 132, 96))
    water_smooth(coll, "C", (64, 166, 186), 0.8)
    bags = {}
    u = 0.3
    pads = []
    while len(pads) < 11:
        x, y = rng.uniform(-22, 22), rng.uniform(-16, 16)
        if rho(x, y) < RHO_W * 0.86 and math.dist((x, y), WADE) > 4.5 and all(math.dist((x, y), p) > 3.2 for p in pads):
            pads.append((x, y))
    for k, (x, y) in enumerate(pads):
        leaf = (86, 172, 80) if k % 3 else (124, 198, 98)
        notch = rng.randrange(4)
        for a in range(-2, 3):
            for b in range(-2, 3):
                if abs(a) + abs(b) > 3 or (notch == 0 and a == 0 and b > 0) or (notch == 1 and a == 0 and b < 0) or \
                        (notch == 2 and b == 0 and a > 0) or (notch == 3 and b == 0 and a < 0):
                    continue
                blocks(bags, leaf, x + a * u - u / 2, y + b * u - u / 2, -W - 0.04, u, u, 0.1)
        if k % 3 == 0:
            blocks(bags, (255, 150, 190), x - u / 2 + 0.3, y - u / 2 + 0.3, -W + 0.06, u, u, u)
            blocks(bags, (255, 206, 60), x + 0.38, y + 0.38, -W + 0.36, 0.14, 0.14, 0.14)
    # TALL reeds in clumps at the waterline (owner 2026-11-26: "make the plants next to the pond look tall"): chest
    # height to a little over a fighter's head (3 to 6 studs), stalks of stacked blocks that step a little sideways
    # as they rise (a bend, on the grid), cattail heads, and long flat leaves
    for ang in (3.6, 5.5, 1.1, 2.45):
        for _ in range(14):
            r = RHO_W * rng.uniform(0.93, 1.07)
            th = ang + rng.uniform(-0.16, 0.16)
            wob = 1.0 + sum(a * math.sin(kk * th + ph) for kk, a, ph in POND["wobble"])
            x, y = math.cos(th) * POND["semiX"] * r * wob, math.sin(th) * POND["semiY"] * r * wob
            x, y = round(x / 0.14) * 0.14, round(y / 0.14) * 0.14
            h = rng.uniform(3.0, 6.0)
            base = z(x, y) - 0.1
            green = rng.choice(((70, 150, 74), (96, 172, 84), (58, 128, 66)))
            if rng.random() < 0.35:  # a long flat leaf, leaning out in two steps
                lx, ly = rng.choice(((0.14, 0), (-0.14, 0), (0, 0.14), (0, -0.14)))
                blocks(bags, green, x, y, base, 0.42 if lx == 0 else 0.1, 0.1 if lx == 0 else 0.42, (h * 0.55) - base)
                blocks(bags, green, x + lx, y + ly, h * 0.55, 0.42 if lx == 0 else 0.1, 0.1 if lx == 0 else 0.42, h * 0.3)
                continue
            dx, dy = rng.choice(((0.07, 0), (-0.07, 0), (0, 0.07), (0, -0.07)))
            seg = (h - base) / 3
            for s in range(3):  # the stalk in three blocks, each a little further over: a gentle bend
                blocks(bags, green, x + dx * s, y + dy * s, base + seg * s, 0.2, 0.2, seg)
            if rng.random() < 0.6:  # a cattail head under a thin tip
                blocks(bags, (122, 84, 60), x + dx * 2 - 0.06, y + dy * 2 - 0.06, h - 0.9, 0.32, 0.32, 0.75)
                blocks(bags, green, x + dx * 2 + 0.03, y + dy * 2 + 0.03, h - 0.15, 0.14, 0.14, 0.45)
    for ang0, ang1 in ((0.2, 0.9), (2.2, 2.9), (4.2, 4.8)):  # block pebbles in three arcs on the shore, wide gaps
        for _ in range(7):
            th = rng.uniform(ang0, ang1)
            r = rng.uniform(0.92, 1.02)
            wob = 1.0 + sum(a * math.sin(kk * th + ph) for kk, a, ph in POND["wobble"])
            x, y = math.cos(th) * POND["semiX"] * r * wob, math.sin(th) * POND["semiY"] * r * wob
            s = rng.choice((0.42, 0.56, 0.7))
            blocks(bags, rng.choice(((150, 156, 176), (184, 188, 200), (128, 134, 156))), x, y, z(x, y) - s * 0.4, s, s * rng.choice((1, 1.4)), s * 0.8)
    for rgb, b in bags.items():
        put("Pond_C_Deco", b, stud_mat("Pond_C_Deco_%d_%d_%d" % rgb, rgb, per=0.14), coll)
    fighters(coll, z)
    return coll


def look_d():
    """Poster bands: water cut on the stud grid in two flat tones, a white foam line, no studs on the water."""
    coll = new_coll("Pond_D")
    z = basin_smooth(coll, "D", lower=W + 0.15)
    dist = {c: 0 for c in WATER if any((c[0] + di, c[1] + dj) not in WATER for di, dj in NB4)}
    q = deque(dist)
    while q:
        c = q.popleft()
        for di, dj in NB4:
            n = (c[0] + di, c[1] + dj)
            if n in WATER and n not in dist:
                dist[n] = dist[c] + 1
                q.append(n)
    shallow = {c for c in WATER if dist[c] <= 1}
    bm = sheet(shallow, -W)
    skirt(bm, cell_edges(WATER), -W, -W - 0.3)
    put("Pond_D_Shallow", bm, flat_mat("Pond_D_Shallow", (128, 220, 224), 1.0, 0.5), coll)
    put("Pond_D_Deep", sheet(WATER - shallow, -W), flat_mat("Pond_D_Deep", (44, 146, 212), 1.0, 0.5), coll)
    foam = bmesh.new()
    for a, b in cell_edges(WATER):
        dx, dy = (b[0] - a[0]) / CELL, (b[1] - a[1]) / CELL
        nx, ny = -dy * 0.45, dx * 0.45  # inward: the inside is on the left
        foam.faces.new([foam.verts.new(p) for p in ((a[0], a[1], -W + 0.012), (b[0], b[1], -W + 0.012),
                                                     (b[0] + nx, b[1] + ny, -W + 0.012), (a[0] + nx, a[1] + ny, -W + 0.012))])
    put("Pond_D_Foam", foam, flat_mat("Pond_D_Foam", (246, 252, 252), 1.0, 0.6), coll)
    fighters(coll, z)
    return coll


LOOKS = {"A": look_a, "B": look_b, "C": look_c, "D": look_d}

# --- cameras, render ----------------------------------------------------------------------------------------------
def camera(name, loc, target, lens):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    cam.clip_start = 0.1
    cam.clip_end = 20000
    o = bpy.data.objects.new(name, cam)
    scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return o


CAMS = {
    "fight": camera("PondFight", (6.0, -46.0, 9.5), (0.0, 4.0, -0.5), 24),
    "wade": camera("PondWade", (-6.0, -21.0, 4.8), (4.0, 3.0, -0.4), 26),
    "over": camera("PondOver", (62.0, -88.0, 70.0), (0.0, 0.0, -1.0), 30),
}
scene.render.engine = "CYCLES"
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "OPTIX"
    prefs.get_devices()
    for d in prefs.devices:
        d.use = d.type == "OPTIX"
    scene.cycles.device = "GPU"
except Exception as e:  # noqa: BLE001
    print("GPU unavailable, CPU:", e, flush=True)
scene.cycles.samples = 16 if FAST else 64
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = (640, 360) if FAST else (1280, 720)
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"

colls = {k: LOOKS[k]() for k in ONLY}
for k, coll in colls.items():
    for other in colls.values():
        other.hide_render = other is not coll
    for view, cam in CAMS.items():
        if view not in VIEWS:
            continue
        scene.camera = cam
        scene.render.filepath = os.path.join(OUT, f"pond_{k.lower()}_{view}.png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", scene.render.filepath, flush=True)
tris = {o.name: len(o.data.polygons) for o in bpy.data.objects if o.name.startswith("Pond_") and o.type == "MESH"}
print("TRIANGLES", tris, flush=True)
print("POND OPTIONS DONE", flush=True)
