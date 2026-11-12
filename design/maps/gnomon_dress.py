"""Gnomon's dressing (user brief 2026-11-11, four references): grass over the whole battlefield, a few flowers, small
boulders, ONE shallow pond in the middle, and the decorative islands planted from the scenery kit
(props_kit.py: trees, bushes, plants, flowers, rocks, ruins). Called from gnomon.py's build.

WHAT IS MAP GEOMETRY (exported with the map): the pond's basin (the two middle floor tiles rebuilt on a 2-stud grid
and carved), its water, and the grass (low-poly versions of the six kit plants, merged into chunks named Grass_*,
one shared palette texture, so GrassWind sways their tips in game).

WHAT IS PLACED (placements.json, cloned in Studio from the kit's uploaded models, one shared mesh per asset):
every tree, bush, plant, flower cluster, rock, ruin and lily. They are also instanced into the Blender scene
(collection "Dressing", never exported) so the assembly can be reviewed here.

PERFORMANCE: the grass is about 5,500 tufts of about 70 triangles in ~30 chunks (each under Roblox's 20,000), one
texture for all of it; everything else repeats a few dozen kit meshes, which Roblox draws as instances.
"""
import json
import math
import os
import random

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import common as C
import paint as P
import surfaces as S
import style as ST

HERE = os.path.dirname(os.path.abspath(__file__))
KIT_BLEND = os.path.join(HERE, "out", "gnomon", "props", "gnomon_props.blend")
CAP = 4.0

# --- THE POND: the same numbers as MapEnvironments.gnomon.pond (Roblox z = -Blender y); Core/Pond is this formula
POND = dict(x=0.0, y=0.0, semiX=24.0, semiY=18.0, wobble=[(3, 0.08, 0.6), (5, 0.05, 2.1)], depth=1.6, inner=0.68, water=0.55)


def pond_rho(x, y):
    u = (np.asarray(x, float) - POND["x"]) / POND["semiX"]
    v = (np.asarray(y, float) - POND["y"]) / POND["semiY"]
    th = np.arctan2(v, u)
    wob = 1.0 + sum(a * np.sin(k * th + ph) for k, a, ph in POND["wobble"])
    return np.hypot(u, v) / wob


def bed_depth(x, y):
    return POND["depth"] * P.smoothstep(1.0, POND["inner"], pond_rho(x, y))


def water_rho():
    """Where the bed is exactly the water's depth below the floor: the water's edge, as a share of rho."""
    lo, hi = POND["inner"], 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if POND["depth"] * float(P.smoothstep(1.0, POND["inner"], mid)) > POND["water"]:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def pond_outline(rho, n=72):
    pts = []
    for i in range(n):
        th = i / n * math.tau
        wob = 1.0 + sum(a * math.sin(k * th + ph) for k, a, ph in POND["wobble"])
        pts.append((POND["x"] + math.cos(th) * POND["semiX"] * rho * wob, POND["y"] + math.sin(th) * POND["semiY"] * rho * wob))
    return pts


def ground_z(x, y):
    return -float(bed_depth(x, y))


# --- the basin -------------------------------------------------------------------------------------
def carve_basin():
    """Rebuilds every floor tile the pond touches as a prism whose top is a 2-stud grid sunk by the bed's depth
    (same UVs as the painted tile, so its texture still fits). Those tiles get precise collision on import, so
    the bed is a real walkable floor."""
    ext = max(POND["semiX"], POND["semiY"]) * 1.25
    carved = []
    for obj in list(C.collection("Export").objects):
        if not obj.name.startswith("Meadow_"):
            continue
        co = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        x0, x1 = min(c.x for c in co), max(c.x for c in co)
        y0, y1 = min(c.y for c in co), max(c.y for c in co)
        if x1 < POND["x"] - ext or x0 > POND["x"] + ext or y1 < POND["y"] - ext or y0 > POND["y"] + ext:
            continue
        assert abs((x1 - x0) - S.TILE) < 0.01 and abs((y1 - y0) - S.TILE) < 0.01, f"{obj.name} isn't a whole tile"
        n = int(S.TILE / 2)
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        grid = [[bm.verts.new((x0 + i * 2.0, y0 + j * 2.0, ground_z(x0 + i * 2.0, y0 + j * 2.0))) for i in range(n + 1)] for j in range(n + 1)]
        for j in range(n):
            for i in range(n):
                bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
        border = [grid[0][i] for i in range(n + 1)] + [grid[j][n] for j in range(1, n + 1)] + [grid[n][i] for i in range(n - 1, -1, -1)] + [grid[j][0] for j in range(n - 1, 0, -1)]
        bottom = [bm.verts.new((v.co.x, v.co.y, -CAP)) for v in border]
        for k in range(len(border)):
            m = (k + 1) % len(border)
            bm.faces.new((border[m], border[k], bottom[k], bottom[m]))
        bm.faces.new(list(reversed(bottom)))
        for f in bm.faces:
            for loop in f.loops:
                loop[uv].uv = ((loop.vert.co.x - x0) / S.TILE, (loop.vert.co.y - y0) / S.TILE)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        obj["precise_collision"] = True
        carved.append(obj.name)
    print("BASIN", carved, flush=True)
    return carved


def pond_paint(X, Y, col):
    """The bed and the shore, painted into the floor tiles: wet darker earth down the bank, a muted sandy-olive
    bed under the water."""
    d = bed_depth(X, Y)
    bank = P.smoothstep(0.02, 0.35, d)
    col = P.mix(col, P.rgb(58, 92, 56), 0.55 * bank)
    bed = P.smoothstep(POND["water"] * 0.8, POND["water"] * 1.3, d)
    col = P.mix(col, P.rgb(118, 120, 86), 0.8 * bed)
    return col


def build_water():
    """The water: a flat surface at the waterline, following the shore, a little thick so it's never paper-thin
    from the side. Non-colliding; slightly see-through on import."""
    pts = pond_outline(water_rho() * 1.01)
    bm = bmesh.new()
    top = [bm.verts.new((x, y, -POND["water"])) for x, y in pts]
    bot = [bm.verts.new((x, y, -POND["depth"] - 0.1)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for k in range(len(pts)):
        m = (k + 1) % len(pts)
        bm.faces.new((top[k], bot[k], bot[m], top[m]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    C.mesh_object("Pond_Water", bm, C.flat_material("Gnomon_PondWater", tuple(float(c) for c in P.rgb(84, 168, 198)), 0.4))


# --- grass ------------------------------------------------------------------------------------------
# image 4's palette: four tone columns, each a gradient from the shaded base to the lit tip, with a lighter rib
GRASS_TONES = [(-0.06, 0.0), (0.0, 0.0), (0.05, 0.02), (0.02, 0.06)]  # (value shift, warm shift)
VARIANTS = {
    # kit plant -> lite version: (leaves, length, width, tilt, droop, layers, weight, height cap, blade rows, scale)
    # The low wide ones carry the coverage (cheap: one row of 4 triangles a leaf, drawn large); the taller ones
    # stand through it everywhere, centre included, at their own heights.
    "Plant_Groundcover": (9, (1.0, 1.5), (0.7, 1.0), (0.05, 0.3), 0.3, 2, 0.30, 1.0, 1, (1.2, 1.7)),
    "Plant_Broadleaf_Small": (7, (1.3, 1.7), (0.6, 0.8), (0.3, 0.7), 0.3, 2, 0.22, 1.5, 1, (1.1, 1.5)),
    "Plant_Roundleaf": (7, (1.2, 1.6), (1.0, 1.3), (0.15, 0.45), 0.35, 1, 0.18, 1.1, 1, (1.1, 1.6)),
    "Plant_Spiky": (8, (2.4, 3.4), (0.3, 0.45), (0.9, 1.35), 0.15, 1, 0.12, 3.0, 2, (0.8, 1.15)),
    "Plant_Broadleaf": (7, (2.2, 2.8), (0.9, 1.2), (0.35, 0.7), 0.3, 2, 0.10, 2.2, 2, (0.9, 1.2)),
    "Plant_Tall_Blade": (6, (3.0, 3.8), (0.45, 0.6), (1.0, 1.35), 0.2, 1, 0.08, 3.2, 2, (0.85, 1.1)),
}


def grass_atlas(tex_dir):
    n_u, n_v = 4 * 16, 128
    base, light, dark = P.rgb(66, 124, 74), P.rgb(112, 170, 110), P.rgb(42, 88, 52)
    img = np.zeros((n_v, n_u, 3))
    v = np.linspace(0, 1, n_v)[:, None]
    for c, (val, warm) in enumerate(GRASS_TONES):
        u = np.linspace(0, 1, 16)[None, :]
        grad = P.mix(P.fill((n_v, 16), dark), base, P.smoothstep(0.0, 0.45, v))
        grad = P.mix(grad, light, 0.85 * P.smoothstep(0.45, 1.0, v))
        rib = np.exp(-((u - 0.5) / 0.12) ** 2)  # the midrib catches the light
        grad = grad + (0.35 * rib * P.smoothstep(0.1, 0.6, v))[..., None] * (light - grad)
        grad = grad * (1 + val) + np.array([warm, warm * 0.6, -warm * 0.4]) * 0.15
        img[:, c * 16 : (c + 1) * 16] = np.clip(grad, 0, 1)
    os.makedirs(tex_dir, exist_ok=True)
    path = P.save_png(os.path.join(tex_dir, "Grass_Atlas_Color.png"), img[::-1])
    return S.image_material("Grass_Atlas", {"colour": path}, roughness=0.95)


def _leaf_arrays(base, d, length, width, droop, fold, tone, rng, samples=2):
    """A single-sided folded blade (8 triangles): vertices, faces, and per-corner UVs into the atlas column."""
    base = Vector(base)
    d = Vector(d).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    if up.z < 0:
        up = -up
    verts, uvs = [], []
    col = tone / 4.0
    for i in range(samples + 1):
        t = i / samples
        w = width * (0.35 if i == 0 else (1.0 if i < samples else 0.05))
        c = base + d * length * t + up * (length * 0.22 * math.sin(math.pi * t * 0.8)) - Vector((0, 0, droop * length * t * t))
        for k, (off, ru) in enumerate(((-0.5, 0.15), (0.0, 0.5), (0.5, 0.85))):
            p = c + side * w * off + (up * 0.18 * w if k == 1 else Vector())
            verts.append((p.x, p.y, p.z))
            uvs.append((col + ru / 4.0, t))
    faces = []
    for i in range(samples):
        a, b = i * 3, (i + 1) * 3
        faces.append((a, a + 1, b + 1, b))
        faces.append((a + 1, a + 2, b + 2, b + 1))
    return verts, faces, uvs


def grass_template(name, rng):
    leaves, length, width, tilt, droop, layers, weight, cap, rows, _ = VARIANTS[name]
    V, F, U = [], [], []
    for layer in range(layers):
        n = leaves - layer * 3
        for i in range(n):
            a = i / n * math.tau + rng.uniform(-0.3, 0.3) + layer * 0.4
            t = rng.uniform(*tilt) * (1 - layer * 0.25)
            d = (math.cos(a) * math.cos(t), math.sin(a) * math.cos(t), math.sin(t))
            v, f, u = _leaf_arrays((0, 0, 0.05 + layer * 0.12), d, rng.uniform(*length) * (1 - layer * 0.25), rng.uniform(*width), droop, 0.2, rng.randrange(4), rng, samples=rows)
            o = len(V)
            V += v
            U += [u[k] for face in f for k in face]
            F += [tuple(o + k for k in face) for face in f]
    V = np.array(V)
    top = V[:, 2].max()
    if top > cap:  # keep the tallest grass readable: never above about waist height
        V *= cap / top
    return V, F, U


def scatter_grass(tex_dir, avoid):
    """Grass over the whole floor: a jittered grid kept or dropped by a low-frequency density field (so it
    gathers in natural overlapping groups with no bare patches), the variant picked by a second field (patches of
    one kind) mixed with chance, random turn and size, seated on the ground (down the pond's bank too), kept off
    the water, the rocks and the flowers, denser along the shore. Merged into chunks of at most 19,000 triangles."""
    rng = random.Random(909)
    mat = grass_atlas(tex_dir)
    names = list(VARIANTS)
    templates = {n: [grass_template(n, random.Random(1000 + 37 * k + j)) for j in range(3)] for k, n in enumerate(names)}
    weights = np.array([VARIANTS[n][6] for n in names])
    a, b = C.A - C.RIM - 2.0, C.B - C.RIM - 2.0
    rw = water_rho()
    step = 2.9
    cells = {}
    count = 0
    for gx in np.arange(-a, a, step):
        for gy in np.arange(-b, b, step):
            x, y = gx + rng.uniform(-0.45, 0.45) * step, gy + rng.uniform(-0.45, 0.45) * step
            if (x / a) ** 2 + (y / b) ** 2 > 1:
                continue
            rho = float(pond_rho(x, y))
            if rho < rw * 1.02:
                continue
            if any((x - ax) ** 2 + (y - ay) ** 2 < ar * ar for ax, ay, ar in avoid):
                continue
            dens = 0.55 + 0.45 * float(P.fbm2(np.array(x * 0.045), np.array(y * 0.045), 77, 3))
            if rho < 1.35:
                dens += 0.25
            if rng.random() > dens:
                continue
            patch = float(P.fbm2(np.array(x * 0.03 + 50), np.array(y * 0.03), 78, 2))
            if rng.random() < 0.6:
                k = min(int(patch * len(names) * 1.4) % len(names), len(names) - 1)
            else:
                k = int(np.searchsorted(np.cumsum(weights / weights.sum()), rng.random()))
            V, F, U = rng.choice(templates[names[k]])
            s = rng.uniform(*VARIANTS[names[k]][9])
            th = rng.uniform(0, math.tau)
            ct, st = math.cos(th), math.sin(th)
            Vw = V * s
            Vw = np.stack([Vw[:, 0] * ct - Vw[:, 1] * st + x, Vw[:, 0] * st + Vw[:, 1] * ct + y, Vw[:, 2] + ground_z(x, y) - 0.05], axis=1)
            key = (int((x + a) // 72), int((y + b) // 72))
            chunk = cells.setdefault(key, [[[], [], [], 0]])
            if chunk[-1][3] + len(F) * 2 > 19000:
                chunk.append([[], [], [], 0])
            cur = chunk[-1]
            o = sum(len(v) for v in cur[0])
            cur[0].append(Vw)
            cur[1] += [tuple(o + i for i in f) for f in F]
            cur[2] += U
            cur[3] += len(F) * 2
            count += 1
    total = 0
    idx = 0
    for key in sorted(cells):
        for verts, faces, uvs, tris in cells[key]:
            if not faces:
                continue
            V = np.concatenate(verts)
            me = bpy.data.meshes.new(f"Grass_Scatter_{idx:02d}")
            me.from_pydata(V.tolist(), [], faces)
            uvl = me.uv_layers.new(name="UVMap")
            uvl.data.foreach_set("uv", np.array(uvs, dtype=np.float32).ravel())
            for poly in me.polygons:
                poly.use_smooth = False
            me.materials.append(mat)
            obj = bpy.data.objects.new(f"Grass_Scatter_{idx:02d}", me)
            C.collection("Export").objects.link(obj)
            obj["double_sided"] = True
            total += tris
            idx += 1
    print(f"GRASS {count} tufts, {idx} chunks, {total} triangles", flush=True)
    return count, total


# --- placements -------------------------------------------------------------------------------------
PLACEMENTS = []  # dicts: asset, x, y, z (Blender), rot (about up), scale, collide, zone


def place(asset, x, y, z, rot, scale=1.0, collide=False, zone="island"):
    PLACEMENTS.append(dict(asset=asset, x=float(x), y=float(y), z=float(z), rot=float(rot), scale=float(scale), collide=collide, zone=zone))


def battlefield(rng):
    """The pond's shore (rocks in four arcs with wide gaps, lilies, flowers at two openings), a few small
    boulders well apart, and sparse flowers. Returns spots the grass keeps off: (x, y, radius)."""
    avoid = []
    rw = water_rho()
    # shoreline rocks: four arcs, leaving four openings of 25-35 degrees (several ways in, across and out)
    arcs = [(20, 75), (115, 160), (200, 245), (290, 335)]
    shore = ["Rock_Round", "Rock_Medium", "Rock_Small_A", "Rock_Twin", "Rock_Small_B", "Rock_Wedge", "Rock_Pebbles", "Rock_Flat_Slab"]
    for a0, a1 in arcs:
        deg = a0 + rng.uniform(0, 6)
        while deg < a1:
            th = math.radians(deg)
            wob = 1.0 + sum(a * math.sin(k * th + ph) for k, a, ph in POND["wobble"])
            r = rng.uniform(1.0, 1.12)
            x, y = math.cos(th) * POND["semiX"] * r * wob, math.sin(th) * POND["semiY"] * r * wob
            asset = rng.choice(shore)
            s = rng.uniform(0.75, 1.25)
            place(asset, x, y, ground_z(x, y) - 0.25, rng.uniform(0, math.tau), s, collide=asset not in ("Rock_Pebbles",), zone="shore")
            avoid.append((x, y, 3.2 * s))
            deg += rng.uniform(14, 24)
    # lilies on the water, sparse: the water stays easy to read
    for k, asset in enumerate(["Lily_Pad_Big", "Lily_Pad", "Lily_Pad_Small", "Lily_Lotus", "Lily_Pad", "Lily_Lotus", "Lily_Pad_Small", "Lily_Pad_Big"]):
        for _ in range(50):
            th = rng.uniform(0, math.tau)
            rr = rng.uniform(0.25, 0.8) * rw
            wob = 1.0 + sum(a * math.sin(kk * th + ph) for kk, a, ph in POND["wobble"])
            x, y = math.cos(th) * POND["semiX"] * rr * wob, math.sin(th) * POND["semiY"] * rr * wob
            if all((x - p["x"]) ** 2 + (y - p["y"]) ** 2 > 36 for p in PLACEMENTS if p["zone"] == "water"):
                place(asset, x, y, -POND["water"] + 0.02, rng.uniform(0, math.tau), rng.uniform(1.5, 1.9), zone="water")
                break
    # flowers at two shore openings
    for deg, asset in ((95, "Flowers_Daisy_Big"), (270, "Flowers_Bell"), (180, "Flowers_Daisy_Small")):
        th = math.radians(deg)
        x, y = math.cos(th) * POND["semiX"] * 1.3, math.sin(th) * POND["semiY"] * 1.3
        place(asset, x, y, ground_z(x, y), rng.uniform(0, math.tau), rng.uniform(0.9, 1.1), zone="shore")
        avoid.append((x, y, 1.6))
    # small boulders, well apart, off the spawn oval and the recovery edge and the pond
    a, b = C.A - C.RIM, C.B - C.RIM
    small = ["Rock_Small_A", "Rock_Small_B", "Rock_Medium", "Rock_Pebbles", "Rock_Wedge", "Rock_Round"]
    spots = []
    tries = 0
    while len(spots) < 11 and tries < 4000:
        tries += 1
        x, y = rng.uniform(-a, a), rng.uniform(-b, b)
        f = math.hypot(x / a, y / b)
        if f > 0.84 or abs(f - 0.65) < 0.08 or pond_rho(x, y) < 1.6:
            continue
        if any((x - sx) ** 2 + (y - sy) ** 2 < 42 ** 2 for sx, sy in spots):
            continue
        spots.append((x, y))
        asset = small[len(spots) % len(small)]
        s = rng.uniform(0.8, 1.15)
        place(asset, x, y, -0.2, rng.uniform(0, math.tau), s, collide=asset != "Rock_Pebbles", zone="field")
        avoid.append((x, y, 3.0 * s))
    # sparse flowers: singles and a few small clusters, far apart
    fl = ["Flowers_Daisy_Small", "Flowers_Tulip", "Flowers_Lily", "Flowers_Bell", "Flowers_Coral", "Flowers_Daisy_Big"]
    fspots = []
    tries = 0
    while len(fspots) < 22 and tries < 6000:
        tries += 1
        x, y = rng.uniform(-a, a), rng.uniform(-b, b)
        if math.hypot(x / a, y / b) > 0.93 or pond_rho(x, y) < 1.4:
            continue
        if any((x - sx) ** 2 + (y - sy) ** 2 < 30 ** 2 for sx, sy in fspots):
            continue
        if any((x - ax) ** 2 + (y - ay) ** 2 < (ar + 4) ** 2 for ax, ay, ar in avoid):
            continue
        fspots.append((x, y))
        n = 1 if rng.random() < 0.7 else rng.randint(2, 3)
        for k in range(n):
            ox, oy = (rng.uniform(-2.5, 2.5), rng.uniform(-2.5, 2.5)) if k else (0, 0)
            place(rng.choice(fl), x + ox, y + oy, 0.0, rng.uniform(0, math.tau), rng.uniform(0.8, 1.1), zone="field")
            avoid.append((x + ox, y + oy, 1.4))
    print(f"BATTLEFIELD {sum(1 for p in PLACEMENTS if p['zone'] == 'shore')} shore, {sum(1 for p in PLACEMENTS if p['zone'] == 'water')} lilies, {len(spots)} boulders, {len(fspots)} flower spots", flush=True)
    return avoid


# --- the islands: the old procedural plants become kit placements ----------------------------------
SLOTS = []  # (kind, x, y, z, size, cap) recorded while the backdrop builds
TREE_H = {"Tree_A": 30, "Tree_B": 42, "Tree_C": 24, "Tree_D": 52, "Tree_E": 34}


def _cap_of(G):
    return G.caps[-1] if getattr(G, "caps", None) else None


def begin_islands():
    """Swaps style's plant builders for recorders, so each islet keeps its composition but is planted from the kit."""
    def rec(kind):
        def f(G, at, size, rng, *args, **kw):
            SLOTS.append((kind, at[0], at[1], at[2], float(size), _cap_of(G)))
        return f

    def rec_flowers(G, at, n, spread, rng, *args, **kw):
        SLOTS.append(("flowers", at[0], at[1], at[2], float(spread), _cap_of(G)))

    ST.twin = rec("twin")
    ST.tiered = rec("tiered")
    ST.umbrella = rec("umbrella")
    ST.bush = rec("bush")
    ST.sprout = rec("sprout")
    ST.flowers = rec_flowers


# extra scenery per islet in its ORIGINAL layout coordinates (pushed out with it): ruins, large rocks, lush clusters
EXTRAS = [
    # west, the tall pair: an overgrown arch and a column among the trees
    ("Ruin_Arch", -244, 32, 11, 0.6, 1.0), ("Ruin_Column_Broken", -262, 62, 11, 2.0, 1.0), ("Rock_Split_Big", -238, 60, 11, 0.4, 1.0),
    # north, the pennant islet: a broken wall behind the pennants
    ("Ruin_Wall", -10, 236, 6, 0.2, 0.9), ("Rock_Wide_Cluster", -42, 214, 6, 1.1, 1.0), ("Bush_Big", 12, 214, 6, 0.0, 1.0),
    # north-east, the grove: a tall column and rocks
    ("Ruin_Column_Tall", 224, 122, 8, 0.3, 1.0), ("Rock_Pillar", 252, 100, 8, 0.0, 1.2), ("Bush_Wide", 214, 96, 8, 1.4, 1.0),
    # south-west, the hollow log islet: rocks and a flat slab by the log
    ("Rock_Flat_Slab", -318, -138, 0, 0.8, 1.2), ("Rock_Twin", -276, -166, 0, 2.2, 1.1), ("Bush_Round", -290, -132, 0, 0.0, 1.0),
    # the sundial island: a broken column and rocks under the blade
    ("Ruin_Column_Broken", 352, 66, -25, 1.0, 1.1), ("Rock_Pillar", 412, 2, -25, 0.5, 1.4), ("Rock_Wide_Cluster", 346, -12, -25, 2.0, 1.2),
]


def finish_islands(push, rng):
    """Turns the recorded slots into kit placements (trees sized to the slot, bushes, plants, flowers), adds one or
    two supporting plants round each tree inside its cap, adds the extras, and moves everything out with its islet."""
    trees_round = ["Tree_A", "Tree_C", "Tree_E"]
    trees_tall = ["Tree_B", "Tree_D"]
    bushes = ["Bush_Round", "Bush_Wide", "Bush_Tall", "Bush_Double", "Bush_Low", "Bush_Big"]
    plants = ["Plant_Broadleaf", "Plant_Spiky", "Plant_Tall_Blade", "Plant_Roundleaf", "Plant_Broadleaf_Small", "Plant_Groundcover"]
    flowers = ["Flowers_Daisy_Big", "Flowers_Daisy_Small", "Flowers_Lily", "Flowers_Tulip", "Flowers_Bell", "Flowers_Coral"]
    raw = []

    def on_cap(cap, x, y, margin=0.8):
        if not cap:
            return True
        cx, cy, cz, rx, ry = cap
        return ((x - cx) / (rx * margin)) ** 2 + ((y - cy) / (ry * margin)) ** 2 <= 1

    for kind, x, y, z, size, cap in SLOTS:
        if kind in ("twin", "umbrella", "tiered"):
            asset = rng.choice(trees_tall if kind == "tiered" else trees_round)
            raw.append((asset, x, y, z, rng.uniform(0, math.tau), max(0.55, min(1.7, size / TREE_H[asset]))))
            for _ in range(rng.randint(3, 5)):
                for _ in range(20):
                    a, d = rng.uniform(0, math.tau), rng.uniform(4, 9)
                    px, py = x + math.cos(a) * d, y + math.sin(a) * d
                    if on_cap(cap, px, py):
                        pick = rng.random()
                        asset2 = rng.choice(bushes if pick < 0.4 else plants if pick < 0.75 else flowers)
                        raw.append((asset2, px, py, z, rng.uniform(0, math.tau), rng.uniform(0.8, 1.2)))
                        break
        elif kind == "bush":
            raw.append((rng.choice(bushes), x, y, z, rng.uniform(0, math.tau), max(0.6, min(1.6, size / 2.6))))
        elif kind == "sprout":
            raw.append((rng.choice(["Plant_Tall_Blade", "Plant_Spiky", "Plant_Broadleaf"]), x, y, z, rng.uniform(0, math.tau), 1.0))
        elif kind == "flowers":
            raw.append((rng.choice(flowers), x, y, z, rng.uniform(0, math.tau), 1.0))
    for asset, x, y, z, rot, s in EXTRAS:
        raw.append((asset, x, y, z, rot, s))
    for asset, x, y, z, rot, s in raw:
        dx, dy, dz = push(x, y, z)
        place(asset, x + dx, y + dy, z + dz - 0.15, rot, s, zone="island")
    print(f"ISLANDS {len(SLOTS)} slots -> {len(raw)} placements", flush=True)


# --- the kit in the Blender scene, the manifest for Studio ------------------------------------------
def load_kit():
    """Appends the kit's meshes from the kit .blend; returns {asset: [(part name, mesh)]}. Every kit mesh is modelled
    round its asset's base at the origin, so a placement's matrix is all an instance needs."""
    with bpy.data.libraries.load(KIT_BLEND, link=False) as (src, dst):
        dst.objects = [n for n in src.objects]
    kit = {}
    for o in dst.objects:
        if o is not None and o.type == "MESH" and "kit_asset" in o:
            kit.setdefault(o["kit_asset"], []).append((o.name, o.data))
    for o in dst.objects:
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)
    return kit


def instance_dressing(kit):
    """Puts every placement into the Blender scene (collection Dressing, never exported): each asset's parts share
    the kit's meshes, so the assembly can be inspected here exactly as it will stand in Studio."""
    col = bpy.data.collections.get("Dressing") or bpy.data.collections.new("Dressing")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    missing = set()
    for i, p in enumerate(PLACEMENTS):
        parts = kit.get(p["asset"])
        if not parts:
            missing.add(p["asset"])
            continue
        m = Matrix.Translation((p["x"], p["y"], p["z"])) @ Matrix.Rotation(p["rot"], 4, "Z") @ Matrix.Scale(p["scale"], 4)
        for name, me in parts:
            o = bpy.data.objects.new(f"D{i:03d}_{name}", me)
            o.matrix_world = m
            col.objects.link(o)
    if missing:
        print("MISSING KIT ASSETS", sorted(missing), flush=True)


def write_placements(out_dir, lobby_view):
    """placements.json in Roblox axes from the arena's centre on the floor's top: x, y up, z = -Blender y, the turn
    about up (Roblox's own sign), the scale; and a check that nothing tall stands in the lobby's view."""
    rows = []
    for p in PLACEMENTS:
        rows.append(dict(asset=p["asset"], x=round(p["x"], 3), y=round(p["z"], 3), z=round(-p["y"], 3), rot=round(p["rot"], 4), scale=round(p["scale"], 3), collide=p["collide"], zone=p["zone"]))
    with open(os.path.join(out_dir, "placements.json"), "w", encoding="utf-8") as f:
        json.dump(rows, f, indent=1)
    v = lobby_view
    hits = [p["asset"] for p in PLACEMENTS if p["zone"] == "island" and v["x"][0] < p["x"] < v["x"][1] and v["y"][0] < p["y"] < v["y"][1] and p["z"] > v["floor"]]
    used = sorted({p["asset"] for p in PLACEMENTS})
    print(f"PLACEMENTS {len(rows)} ({len(used)} distinct assets); in the lobby's view: {hits}", flush=True)
    return used
