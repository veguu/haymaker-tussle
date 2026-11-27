"""MAP 1 FULL OF LIFE, the PREVIEW (owner 2026-11-26: "make all models in blender, show it on the blender preview so i
can check myself whether its good to use or not, include all animations aswell"). His picks from my list A to L:
B splashes when you wade; E butterflies and bees over the flowers, petals blown in gusts; F cloud shadows over the
floor; G birds; H hot-air balloons; I island life (chimney smoke, sheep and cows, a waterfall); J vines and roots under
the rim, flowers in the lip; K a fairy ring, clover, dandelion puffs that burst when run through ("don't overdo it").
Sound (L: ambience AND fight music) is a later piece: nothing here.

    blender -b <out/suite/meadow_r6/meadow_review.blend> -P meadow_life.py -- <out folder>
        -> <out folder>/meadow_life_preview.blend (Map 1 with its pond + every piece, animated, 20 s at 30 fps, looping)

Every piece is in its own collection under "Life" (switch one off to judge the map without it), and each has a
"Look_*" camera. Three block fighters act the moments the game would cause: one DASHES at a butterfly (it darts away,
its wings beating faster: "you'll NEVER be able to hit the butterfly"), one WADES into the pond (rings and droplets),
one RUNS through a row of dandelions (they burst into seeds).

STYLE: what lives on the floor (butterflies, bees, petals, mushrooms, clover, dandelions, lip flowers, splashes) is the
floor's BLOCK style ("a bland model like everything else": 0.14-stud blocks like the stud flowers, flat colours); what
lives on the islands and in the sky (sheep, cows, birds, balloons, smoke, vines, roots) is the islands' chunky low-poly.
A preview only: the game build (meshes in Blender, motion as one shared client loop, a phone path, frame cost
measured) comes after his yes, piece by piece.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGV = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(ARGV[0])
os.makedirs(OUT, exist_ok=True)
HERE = os.path.dirname(os.path.abspath(__file__))
FPS, FRAMES = 30, 600
GAP = 0.06  # frames between a cycle's end and the next start: Blender merges keys 0.01 apart (found 2026-11-26)
SEC = FRAMES / FPS
scene = bpy.context.scene

# --- the map's own data: meadow.py read as a module (islands, heights, the pond, the floor's dirt), nothing built ---
_src = open(os.path.join(HERE, "meadow.py"), encoding="utf-8").read().replace("\r\n", "\n")
_src = _src[: _src.rindex("\nrun(NAME")]
G = {"__name__": "meadow_life", "__file__": os.path.join(HERE, "meadow.py")}
exec(compile(_src, os.path.join(HERE, "meadow.py"), "exec"), G)
ISLE, island_h, outline, pond_rho, pond_bed, on_floor_dirt = G["ISLE"], G["island_h"], G["outline"], G["pond_rho"], G["pond_bed"], G["on_floor_dirt"]
POND, RADIUS = G["POND"], G["RADIUS"]
WIND = Vector((1.0, -0.3, 0.0)).normalized()  # MapEnvironments wind.direction {1, 0.3} (x, z) in Blender's x, y

# every piece of island geometry the village builders lay down (to keep animals clear of it) and every chimney's cap
OCC, CHIMNEYS = [], []


def _spy(b, matrix):
    if b.verts:
        lo = Vector((min(v.co.x for v in b.verts), min(v.co.y for v in b.verts), min(v.co.z for v in b.verts)))
        hi = Vector((max(v.co.x for v in b.verts), max(v.co.y for v in b.verts), max(v.co.z for v in b.verts)))
        size = hi - lo
        c = matrix @ ((lo + hi) / 2)
        OCC.append((c.x, c.y, max(size.x, size.y) / 2))
        if abs(size.x - 4.4) < 0.05 and abs(size.y - 4.4) < 0.05 and abs(size.z - 1.0) < 0.05:
            CHIMNEYS.append(matrix @ Vector((0.0, 0.0, 1.0)))  # house(): the chimney's cap, a 4.4 x 4.4 x 1 block
    b.free()


G["vput"] = lambda element, key, b, matrix, region="": _spy(b, matrix)
G["make"] = lambda asset, part, key, bm, family="Map", smooth=False: _spy(bm, Matrix())
_n_objects = len(bpy.data.objects)
G["add"] = lambda element, material, key, src, matrix=Matrix(), family="Map", region="": _spy(src, matrix)
G["village"]()
G["pack"]()
print("LIFE chimneys", len(CHIMNEYS), "occupied", len(OCC), "objects made by the replay", len(bpy.data.objects) - _n_objects, flush=True)

# --- helpers -------------------------------------------------------------------------------------------------------
for _o in bpy.data.objects:
    if _o.name.startswith("PreviewFighter"):
        _o.hide_viewport = _o.hide_render = True
LIFE = bpy.data.collections.new("Life")
scene.collection.children.link(LIFE)
_MATS = {}


def coll(name):
    c = bpy.data.collections.new(f"Life_{name}")
    LIFE.children.link(c)
    return c


def lin(c):
    return tuple((v / 255.0) ** 2.2 for v in c)


def mat(rgb, alpha=1.0, fade=False, rough=0.8, emit=0.0):
    """A flat colour. fade: the object's own colour alpha (obj.color[3]) multiplies the alpha, so one material serves
    many objects that fade on their own clocks."""
    key = (tuple(rgb), alpha, fade, rough, emit)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new("Life_%d_%d_%d" % tuple(rgb) + ("_fade" if fade else ""))
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = lin(rgb) + (1.0,)
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = lin(rgb) + (1.0,)
        p.inputs["Emission Strength"].default_value = emit
    if fade or alpha < 1.0:
        if fade:
            oi = nt.nodes.new("ShaderNodeObjectInfo")
            mul = nt.nodes.new("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            mul.inputs[1].default_value = alpha
            nt.links.new(oi.outputs["Alpha"], mul.inputs[0])
            nt.links.new(mul.outputs[0], p.inputs["Alpha"])
        else:
            p.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except (AttributeError, TypeError):
            pass
    _MATS[key] = m
    return m


class Mesh:
    """Boxes (and other faces) in several colours, one object with a material slot per colour."""

    def __init__(self):
        self.bm = bmesh.new()
        self.slots = []
        self.face_slot = []

    def slot(self, m):
        if m not in self.slots:
            self.slots.append(m)
        return self.slots.index(m)

    def box(self, m, c, s, rot=None, taper=1.0, bottom=True):
        """A box centred on c (x, y, z), size s; `taper` scales its top; `rot` a 3x3/4x4 matrix about its centre."""
        k = self.slot(m)
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        pts = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
               (-hx * taper, -hy * taper, hz), (hx * taper, -hy * taper, hz), (hx * taper, hy * taper, hz), (-hx * taper, hy * taper, hz)]
        r = rot.to_3x3() if rot is not None else None
        vs = [self.bm.verts.new(Vector(c) + (r @ Vector(p) if r else Vector(p))) for p in pts]
        faces = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)] + ([(3, 2, 1, 0)] if bottom else [])
        for f in faces:
            self.bm.faces.new([vs[q] for q in f])
            self.face_slot.append(k)

    def poly(self, m, pts):
        k = self.slot(m)
        self.bm.faces.new([self.bm.verts.new(Vector(p)) for p in pts])
        self.face_slot.append(k)

    def make(self, name, collection, loc=(0, 0, 0), parent=None):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.slots:
            me.materials.append(m)
        for poly, k in zip(me.polygons, self.face_slot):
            poly.material_index = k
        o = bpy.data.objects.new(name, me)
        collection.objects.link(o)
        o.location = loc
        if parent is not None:
            o.parent = parent
        return o


def anim(idb, path, index, pairs, interp=1):
    """Keyframes on any datablock: pairs of (frame, value); interp 0 constant, 1 linear, 2 bezier."""
    if idb.animation_data is None:
        idb.animation_data_create()
    if idb.animation_data.action is None:
        idb.animation_data.action = bpy.data.actions.new(f"{idb.name}_Life")
    fc = idb.animation_data.action.fcurve_ensure_for_datablock(idb, path, index=index)
    fc.keyframe_points.add(len(pairs))
    fc.keyframe_points.foreach_set("co", [v for p in pairs for v in (float(p[0]), float(p[1]))])
    fc.keyframe_points.foreach_set("interpolation", [interp] * len(pairs))
    fc.update()


def sample(idb, path, n, fn, step=1, interp=1):
    """Keys every `step` frames over the loop from fn(t seconds) -> sequence of n values (or one value if n == 1)."""
    frames = list(range(1, FRAMES + 1, step)) + ([FRAMES] if (FRAMES - 1) % step else [])
    vals = [fn((f - 1) / FPS) for f in frames]
    for i in range(n):
        anim(idb, path, i, [(f, v if n == 1 else v[i]) for f, v in zip(frames, vals)], interp)


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def on_grass(x, y):
    """On the green (not dirt, not at the pond, inside the circle with room to spare)."""
    return math.hypot(x, y) < RADIUS - 8 and not on_floor_dirt(x, y) and float(pond_rho(x, y)) > 1.15


def grass_spot(rng, rmin, rmax, near=None, spread=None):
    for _ in range(4000):
        if near is not None:
            x, y = near[0] + rng.uniform(-spread, spread), near[1] + rng.uniform(-spread, spread)
        else:
            a, r = rng.uniform(0, math.tau), rng.uniform(rmin, rmax)
            x, y = math.cos(a) * r, math.sin(a) * r
        if on_grass(x, y):
            return x, y
    raise SystemExit("no grass spot found")


def pond_floor(x, y):
    """The ground's height (Blender z) on the arena: the pond's bed where it is, the floor elsewhere."""
    return -float(pond_bed(x, y)) if float(pond_rho(x, y)) < 1.0 else 0.0


# ======== THE DEMO FIGHTERS: the moments the game causes (a dash, wading, running through dandelions) ===============
DEMO = coll("DemoFighters")


def fighter(name, shirt):
    """floor_mock.py's block fighter, legs and arms separate so they can swing."""
    root = bpy.data.objects.new(name, None)
    DEMO.objects.link(root)
    ink, top, skin = mat((30, 32, 46)), mat(shirt), mat((240, 200, 160))
    parts = {}
    for pname, size, off, m, pivot in (("LegL", (0.95, 0.95, 2.0), (-0.5, 0, 1.0), ink, 2.0), ("LegR", (0.95, 0.95, 2.0), (0.5, 0, 1.0), ink, 2.0),
                                       ("Torso", (2.0, 1.0, 2.0), (0, 0, 3.0), top, None), ("ArmL", (0.95, 0.95, 2.0), (-1.5, 0, 3.0), top, 4.0),
                                       ("ArmR", (0.95, 0.95, 2.0), (1.5, 0, 3.0), top, 4.0), ("Head", (1.25, 1.25, 1.25), (0, 0, 4.65), skin, None)):
        mb = Mesh()
        if pivot is None:
            mb.box(m, off, size)
            o = mb.make(f"{name}_{pname}", DEMO, parent=root)
        else:  # swings about its top (hip or shoulder)
            mb.box(m, (0, 0, off[2] - pivot), size)
            o = mb.make(f"{name}_{pname}", DEMO, loc=(off[0], 0, pivot), parent=root)
        parts[pname] = o
    return root, parts


def drive_fighter(root, parts, path_fn, swing_fn):
    """path_fn(t) -> (x, y, z, heading); swing_fn(t) -> leg swing radians (0 = standing)."""
    sample(root, "location", 3, lambda t: path_fn(t)[:3], step=1)
    sample(root, "rotation_euler", 3, lambda t: (0.0, 0.0, path_fn(t)[3]), step=1)
    for pname, sign in (("LegL", 1), ("LegR", -1), ("ArmL", -0.8), ("ArmR", 0.8)):
        sample(parts[pname], "rotation_euler", 1, lambda t, s=sign: s * swing_fn(t), step=1)


def lerp_path(points, t):
    """points: [(time, x, y)], piecewise linear, held at the ends."""
    if t <= points[0][0]:
        return points[0][1], points[0][2]
    for (t0, x0, y0), (t1, x1, y1) in zip(points, points[1:]):
        if t <= t1:
            k = (t - t0) / max(t1 - t0, 1e-6)
            return x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
    return points[-1][1], points[-1][2]


def heading_of(points, t):
    a, b = lerp_path(points, t - 0.05), lerp_path(points, t + 0.05)
    if math.hypot(b[0] - a[0], b[1] - a[1]) < 1e-4:
        for (t0, x0, y0), (t1, x1, y1) in zip(points, points[1:]):
            if t <= t1 and (x1 != x0 or y1 != y0):
                return math.atan2(y1 - y0, x1 - x0) - math.pi / 2
        return 0.0
    return math.atan2(b[1] - a[1], b[0] - a[0]) - math.pi / 2


def moving(points, t):
    a, b = lerp_path(points, t - 0.05), lerp_path(points, t + 0.05)
    return math.hypot(b[0] - a[0], b[1] - a[1]) / 0.1


# ======== E: BUTTERFLIES (block style, small, never hit: a dash makes one dart away, wings beating faster) ==========
BUT = coll("Butterflies")
rng = random.Random(2611)
U = 0.14
BLOOMS = [(255, 255, 255), (255, 150, 190), (255, 220, 92), (190, 150, 250), (255, 170, 90)]
BODY = (52, 44, 60)
DASH_AT = 5.0  # seconds: the dash demo
DASHER_FROM, BUT0_HOME = (24.0, -62.0), None
butterflies = []
homes = []
# butterfly 0 waits beside the dash demo; the rest over the green where the flowers are
BUT0_HOME = grass_spot(rng, 0, 0, near=(30.0, -52.0), spread=3.0)
homes.append(BUT0_HOME)
while len(homes) < 14:
    h = grass_spot(rng, 40, 165)
    if all(math.dist(h, o) > 18 for o in homes):
        homes.append(h)
dash_dir = Vector((BUT0_HOME[0] - DASHER_FROM[0], BUT0_HOME[1] - DASHER_FROM[1], 0)).normalized()
DASH_PATH = [(0.0, *DASHER_FROM), (DASH_AT - 0.01, *DASHER_FROM),
             (DASH_AT + 0.33, DASHER_FROM[0] + dash_dir.x * 14, DASHER_FROM[1] + dash_dir.y * 14),
             (DASH_AT + 2.5, DASHER_FROM[0] + dash_dir.x * 14, DASHER_FROM[1] + dash_dir.y * 14),
             (DASH_AT + 6.5, DASHER_FROM[0] + dash_dir.x * 4, DASHER_FROM[1] + dash_dir.y * 4),
             (SEC, *DASHER_FROM)]

for k, home in enumerate(homes):
    colour = BLOOMS[k % len(BLOOMS)]
    tip = (max(colour[0] - 70, 30), max(colour[1] - 70, 30), max(colour[2] - 70, 30)) if colour != (255, 255, 255) else (120, 150, 210)
    mb = Mesh()  # the body: 3 blocks long
    mb.box(mat(BODY), (0, 0, 0), (U * 0.8, U * 3, U * 0.8))
    body = mb.make(f"Butterfly_{k:02d}", BUT)
    wings = []
    for side in (-1, 1):  # a wing: 3 x 3 blocks (about a 1-stud span), the outer corner block in the darker tip colour
        mb = Mesh()
        for i in range(3):
            for j in range(3):
                if i == 2 and j == 0:
                    continue  # a notched back edge: reads as a wing, not a card
                m = mat(tip) if (i >= 1 and j == 2 and i + j >= 3) else mat(colour)
                mb.box(m, (side * (U * 0.5 + i * U + U / 2), (j - 1) * U, 0), (U, U, U * 0.3))
        w = mb.make(f"Butterfly_{k:02d}_Wing{'L' if side < 0 else 'R'}", BUT, parent=body)
        wings.append((w, side))
    ph = rng.uniform(0, math.tau)
    rx, ry, hgt, sp = rng.uniform(1.5, 3.5), rng.uniform(1.5, 3.5), rng.uniform(0.9, 2.0), rng.uniform(0.25, 0.45)

    def base(t, home=home, ph=ph, rx=rx, ry=ry, hgt=hgt, sp=sp):
        a = t * sp * math.tau / 2 + ph
        return (home[0] + rx * math.sin(a) + 0.4 * math.sin(a * 3.1),
                home[1] + ry * math.sin(a * 0.7 + 1.3),
                hgt + 0.35 * math.sin(a * 2.3) + 0.15 * math.sin(a * 5.7))

    dodge = None
    if k == 0:  # the dash: it darts sideways and up as the fighter comes within reach, then drifts back
        side = Vector((-dash_dir.y, dash_dir.x, 0))
        dodge = (DASH_AT + 0.03, side * 4.2 + Vector((0, 0, 2.0)))

    def pos(t, base=base, dodge=dodge):
        p = Vector(base(t))
        if dodge:
            t0, off = dodge
            if t >= t0:
                k_in = ease((t - t0) / 0.22)
                k_out = 1 - ease((t - t0 - 1.4) / 2.5)
                p += off * (k_in * k_out)
        return p

    def rate(t, dodge=dodge):  # wing beats a second: 4 calm, 12 while it flees
        if dodge and dodge[0] - 0.05 <= t <= dodge[0] + 2.2:
            x = (t - dodge[0] + 0.05)
            return 4 + 8 * ease(x / 0.15) * (1 - ease((x - 1.4) / 0.8))
        return 4.0

    # the flap phase is the running sum of the rate, so the wings never jump when it speeds up
    phase, acc, last = {}, 0.0, 0.0
    for f in range(1, FRAMES + 1):
        t = (f - 1) / FPS
        acc += rate(t) * math.tau * (t - last)
        last = t
        phase[f] = acc
    sample(body, "location", 3, lambda t, pos=pos: tuple(pos(t)), step=2)

    def yaw(t, pos=pos):
        a, b = pos(t - 0.1), pos(t + 0.1)
        return math.atan2(b.y - a.y, b.x - a.x) - math.pi / 2

    sample(body, "rotation_euler", 3, lambda t, yaw=yaw: (0.0, 0.0, yaw(t)), step=2)
    for w, side in wings:
        anim(w, "rotation_euler", 1, [(f, -side * (0.55 + 0.75 * math.sin(phase[f]))) for f in range(1, FRAMES + 1)])
    butterflies.append(body)

# ======== E: BEES (block style, smaller: yellow, black, yellow, two clear wings that flicker) ===================
BEE = coll("Bees")
for k in range(8):
    home = grass_spot(rng, 30, 160) if k else grass_spot(rng, 0, 0, near=(34.0, -48.0), spread=4.0)
    mb = Mesh()
    for j, c in enumerate(((255, 206, 40), (40, 34, 30), (255, 206, 40))):
        mb.box(mat(c), (0, (j - 1) * 0.1, 0), (0.1, 0.1, 0.1))
    body = mb.make(f"Bee_{k}", BEE)
    for side in (-1, 1):
        mb = Mesh()
        mb.box(mat((235, 245, 255), alpha=0.55), (side * 0.09, 0.02, 0.06), (0.12, 0.1, 0.02))
        w = mb.make(f"Bee_{k}_Wing", BEE, parent=body)
        anim(w, "rotation_euler", 1, [(f, side * (0.5 if f % 2 else -0.3)) for f in range(1, FRAMES + 1)], interp=0)
    ph = rng.uniform(0, 10)

    def bee(t, home=home, ph=ph):
        a = t + ph
        return (home[0] + 2.2 * math.sin(a * 0.9) + 0.5 * math.sin(a * 7.3),
                home[1] + 1.8 * math.sin(a * 0.6 + 1) + 0.4 * math.sin(a * 6.1),
                0.6 + 0.3 * math.sin(a * 1.7) + 0.1 * math.sin(a * 9.0))

    sample(body, "location", 3, bee, step=1)
    sample(body, "rotation_euler", 3, lambda t, bee=bee: (0, 0, math.atan2(bee(t + 0.05)[1] - bee(t)[1], bee(t + 0.05)[0] - bee(t)[0]) - math.pi / 2), step=2)

# ======== E: PETALS blown off the flowers in each gust (every 4 s: MapEnvironments wind.gustSeconds) ============
PET = coll("Petals")
GUSTS = [0.5 + 4.0 * i for i in range(5)]
pet_spots = [grass_spot(rng, 0, 0, near=(26.0, -50.0), spread=9.0) for _ in range(14)] + [grass_spot(rng, 30, 160) for _ in range(26)]
for k, (sx, sy) in enumerate(pet_spots):
    colour = rng.choice(BLOOMS[:4])
    mb = Mesh()
    mb.box(mat(colour), (0, 0, 0), (0.12, 0.12, 0.025))
    p = mb.make(f"Petal_{k:02d}", PET)
    flights = []
    for g0 in GUSTS:
        if rng.random() < 0.7:
            flights.append((g0 + rng.uniform(0, 0.6), rng.uniform(1.6, 2.6), rng.uniform(4.0, 8.0), rng.uniform(0.5, 1.4)))

    def petal(t, sx=sx, sy=sy, flights=flights):
        for t0, dur, dist, up in flights:
            if t0 <= t <= t0 + dur:
                k_ = (t - t0) / dur
                d = WIND * (dist * ease(k_)) + Vector((-WIND.y, WIND.x, 0)) * 0.6 * math.sin(k_ * 5)
                return (sx + d.x, sy + d.y, 0.3 + up * math.sin(math.pi * k_)), 1.0, k_
        return (sx, sy, 0.3), 0.0, 0.0

    sample(p, "location", 3, lambda t, petal=petal: petal(t)[0], step=1)
    sample(p, "scale", 3, lambda t, petal=petal: (petal(t)[1],) * 3, step=1, interp=0)
    sample(p, "rotation_euler", 3, lambda t, petal=petal, s=rng.uniform(5, 9): (petal(t)[2] * s, petal(t)[2] * s * 0.7, petal(t)[2] * 3), step=1)

# ======== F: CLOUD SHADOWS sliding over the floor with the wind (in the game: one soft image as a Texture on the floor
# meshes, its offset moved each frame) ==========================================================================
SHA = coll("CloudShadows")
bm = bmesh.new()
bm.faces.new([bm.verts.new((math.cos(i / 128 * math.tau) * (RADIUS + 0.1), math.sin(i / 128 * math.tau) * (RADIUS + 0.1), 0.04)) for i in range(128)])
me = bpy.data.meshes.new("CloudShadows")
bm.to_mesh(me)
bm.free()
m = bpy.data.materials.new("Life_CloudShadow")
m.use_nodes = True
nt = m.node_tree
p = nt.nodes["Principled BSDF"]
p.inputs["Base Color"].default_value = lin((60, 78, 120)) + (1.0,)  # a light blue-grey shade, never dark
p.inputs["Roughness"].default_value = 1.0
tc, mp, nz, cr = (nt.nodes.new(t) for t in ("ShaderNodeTexCoord", "ShaderNodeMapping", "ShaderNodeTexNoise", "ShaderNodeValToRGB"))
mp.name = "ShadowMapping"
SHADOW_TILE = 80.0  # studs per unit of the noise
mp.inputs["Scale"].default_value = (1 / SHADOW_TILE,) * 3
nz.inputs["Scale"].default_value = 1.0
nz.inputs["Detail"].default_value = 2.0
# FEW AND LIGHT (owner 2026-11-26: "dont overcrowd the arena with shadows, it shouldnt be dark"): MEASURED from straight
# above, renders with and without this layer: 11 to 14% of the floor shaded over the loop, the darkest spot 12 to 13%
# darker (the first values shaded 78% of it, up to 21% darker)
cr.color_ramp.elements[0].position, cr.color_ramp.elements[1].position = 0.55, 0.67
cr.color_ramp.elements[0].color, cr.color_ramp.elements[1].color = (0, 0, 0, 1), (0.32, 0.32, 0.32, 1)
nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
nt.links.new(mp.outputs["Vector"], nz.inputs["Vector"])
nt.links.new(nz.outputs["Fac"], cr.inputs["Fac"])
nt.links.new(cr.outputs["Color"], p.inputs["Alpha"])
try:
    m.surface_render_method = "BLENDED"
except (AttributeError, TypeError):
    pass
me.materials.append(m)
shadow = bpy.data.objects.new("CloudShadows", me)
SHA.objects.link(shadow)
shadow.visible_shadow = False
# the clouds' own drift speed (MapEnvironments clouds.drift.speed 5.5 studs a second), down the wind. The Mapping
# node adds its Location AFTER its Scale, so the offset is in noise units (SHADOW_TILE studs each), not studs: the first
# preview moved them in studs-as-units and the shadows raced 80 times too fast (owner: "why are the clouds shadows
# moving so fast", 2026-11-26)
anim(nt, 'nodes["ShadowMapping"].inputs[1].default_value', 0, [(1, 0.0), (FRAMES, -WIND.x * 5.5 * SEC / SHADOW_TILE)])
anim(nt, 'nodes["ShadowMapping"].inputs[1].default_value', 1, [(1, 0.0), (FRAMES, -WIND.y * 5.5 * SEC / SHADOW_TILE)])

# ======== B: SPLASHES while wading (rings and droplets at the feet, from the HT_Wading moment) ===============
SPL = coll("Splashes")
WADE_PATH = [(0.0, -30.0, -16.0), (2.0, -30.0, -16.0), (8.0, -7.0, -3.0), (11.0, -7.0, -3.0), (16.0, 6.0, -8.0), (18.5, 6.0, -8.0), (SEC, -30.0, -16.0)]


def in_water(x, y):
    return float(pond_bed(x, y)) > POND["water"]


ring_mat = mat((235, 250, 255), alpha=0.85, fade=True, rough=0.3)
drop_mat = mat((200, 238, 250), alpha=0.9, fade=True, rough=0.3)
events = []  # (time, x, y): a ring every 0.4 s while the wader is in the water (0.9 s apart standing still)
t, nxt = 0.0, 0.0
while t < SEC:
    x, y = lerp_path(WADE_PATH, t)
    if in_water(x, y) and t >= nxt:
        events.append((t, x, y))
        nxt = t + (0.4 if moving(WADE_PATH, t) > 0.3 else 0.9)
    t += 1 / FPS
RINGS, DROPS = 4, 4
for r_i in range(RINGS):
    bm = bmesh.new()
    n = 28
    outer = [bm.verts.new((math.cos(a / n * math.tau), math.sin(a / n * math.tau), 0)) for a in range(n)]
    inner = [bm.verts.new((math.cos(a / n * math.tau) * 0.86, math.sin(a / n * math.tau) * 0.86, 0)) for a in range(n)]
    for a in range(n):
        b_ = (a + 1) % n
        bm.faces.new((outer[a], outer[b_], inner[b_], inner[a]))
    me = bpy.data.meshes.new(f"Ripple_{r_i}")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(ring_mat)
    ring = bpy.data.objects.new(f"Ripple_{r_i}", me)
    SPL.objects.link(ring)
    mine = events[r_i::RINGS]
    loc, sc, al = [], [], []
    for t0, x, y in mine:
        f0 = 1 + t0 * FPS
        f1 = f0 + 0.9 * FPS
        loc += [(f0, (x, y)), (f1, (x, y))]
        sc += [(f0 - GAP, 0.0), (f0, 0.35), (f1, 2.3), (f1 + GAP, 0.0)]
        al += [(f0, 0.9), (f1, 0.0)]
    for i in range(2):
        anim(ring, "location", i, [(f, v[i]) for f, v in loc], interp=0)
    anim(ring, "location", 2, [(1, -POND["water"] + 0.02)])
    for i in range(3):
        anim(ring, "scale", i, [(1, 0.0)] + sc if i < 2 else [(1, 1.0)])
    anim(ring, "color", 3, [(1, 0.0)] + al)
    for d_i in range(DROPS):
        mb = Mesh()
        mb.box(drop_mat, (0, 0, 0), (0.12, 0.12, 0.12))
        drop = mb.make(f"Droplet_{r_i}_{d_i}", SPL)
        keys_x, keys_y, keys_z, keys_s = [(1, 0.0)], [(1, 0.0)], [(1, -2.0)], [(1, 0.0)]
        for t0, x, y in mine:
            a = rng.uniform(0, math.tau)
            vx, vy, vz = math.cos(a) * rng.uniform(0.8, 1.6), math.sin(a) * rng.uniform(0.8, 1.6), rng.uniform(2.8, 4.0)
            dur = 2 * vz / 18.0
            for s in range(0, 9):
                tt = dur * s / 8
                f = 1 + (t0 + tt) * FPS
                keys_x.append((f, x + vx * tt))
                keys_y.append((f, y + vy * tt))
                keys_z.append((f, -POND["water"] + 0.4 + vz * tt - 9.0 * tt * tt))
            keys_s += [(1 + t0 * FPS - GAP, 0.0), (1 + t0 * FPS, 1.0), (1 + (t0 + dur) * FPS, 0.6), (1 + (t0 + dur) * FPS + GAP, 0.0)]
        for i, ks in enumerate((keys_x, keys_y, keys_z)):
            anim(drop, "location", i, sorted(ks))
        for i in range(3):
            anim(drop, "scale", i, sorted(keys_s))
        anim(drop, "color", 3, [(1, 1.0)])
print("LIFE splashes", len(events), flush=True)

# ======== K: FAIRY RING, CLOVER, DANDELIONS (block style, ankle height: nothing over 0.42 studs, kept few) =======
FLO = coll("FloorDetails")
RING_AT = grass_spot(rng, 0, 0, near=(-40.0, -70.0), spread=10.0)
mb = Mesh()
cap_red, cap_brown, stem_white, dot_white = mat((214, 64, 58)), mat((168, 110, 70)), mat((240, 234, 220)), mat((255, 255, 255))


def mushroom(mb, x, y, cap, s=1.0):
    mb.box(stem_white, (x, y, 0.1 * s), (0.14 * s, 0.14 * s, 0.2 * s))
    mb.box(cap, (x, y, 0.27 * s), (0.42 * s, 0.42 * s, 0.14 * s), taper=0.7)
    if cap is cap_red:
        for dx, dy in ((0.09, 0.05), (-0.08, -0.07), (-0.05, 0.1)):
            mb.box(dot_white, (x + dx * s, y + dy * s, 0.345 * s), (0.07 * s, 0.07 * s, 0.03 * s))


n_mush = 0
for i in range(14):
    a = i / 14 * math.tau + rng.uniform(-0.08, 0.08)
    r = 2.6 + rng.uniform(-0.15, 0.15)
    x, y = RING_AT[0] + math.cos(a) * r, RING_AT[1] + math.sin(a) * r
    if on_grass(x, y):
        mushroom(mb, x, y, cap_red, rng.uniform(0.8, 1.05))
        n_mush += 1
for _ in range(2):  # two small lone clusters
    cx, cy = grass_spot(rng, 50, 150)
    for _j in range(3):
        mushroom(mb, cx + rng.uniform(-0.6, 0.6), cy + rng.uniform(-0.6, 0.6), cap_brown, rng.uniform(0.7, 1.0))
        n_mush += 1
mb.make("Mushrooms", FLO)
mb = Mesh()
leaf, leaf_lit, clover_flower = mat((64, 140, 72)), mat((96, 170, 86)), mat((250, 246, 255))
n_clover = 0
CLOVER_AT = [grass_spot(rng, 0, 0, near=(10.0, -58.0), spread=6.0)] + [grass_spot(rng, 40, 160) for _ in range(4)]
for cx, cy in CLOVER_AT:
    for _j in range(26):
        x, y = cx + rng.gauss(0, 1.3), cy + rng.gauss(0, 1.3)
        if not on_grass(x, y):
            continue
        h = rng.uniform(0.08, 0.16)
        mb.box(leaf, (x, y, h / 2), (0.04, 0.04, h), bottom=False)
        for a in (0.0, 2.1, 4.2):
            a2 = a + rng.uniform(0, 0.5)
            mb.box(rng.choice((leaf, leaf_lit)), (x + math.cos(a2) * 0.06, y + math.sin(a2) * 0.06, h + 0.01), (0.09, 0.09, 0.025))
        if rng.random() < 0.12:
            mb.box(clover_flower, (x, y, h + 0.06), (0.08, 0.08, 0.08))
        n_clover += 1
mb.make("Clover", FLO)
# dandelions: a stem and a ball of tiny white blocks; the runner bursts a row of them into seeds that ride the wind
RUN_PATH = [(0.0, -2.0, -72.0), (12.5, -2.0, -72.0), (13.6, 18.0, -62.0), (15.0, 30.0, -56.0), (SEC, 30.0, -56.0)]
DAND_ROW = []
for i in range(6):  # along the runner's line
    k_ = 0.15 + i * 0.14
    x = -2.0 + (18.0 - -2.0) * k_ * 1.3
    y = -72.0 + (-62.0 - -72.0) * k_ * 1.3
    x, y = x + rng.uniform(-0.4, 0.4), y + rng.uniform(-0.4, 0.4)
    if on_grass(x, y):
        DAND_ROW.append((x, y))
DAND = DAND_ROW + [grass_spot(rng, 40, 165) for _ in range(12)]
stem, fluff, seed_m = mat((96, 160, 80)), mat((252, 252, 248)), mat((246, 246, 240), fade=True)
n_seed = 0
for k, (x, y) in enumerate(DAND):
    mb = Mesh()
    mb.box(stem, (0, 0, 0.13), (0.05, 0.05, 0.26))
    pt = mb.make(f"Dandelion_{k:02d}_Stem", FLO, loc=(x, y, 0))
    mb = Mesh()
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                if abs(dx) + abs(dy) + abs(dz) <= 2:
                    mb.box(fluff, (dx * 0.055, dy * 0.055, dz * 0.055), (0.05, 0.05, 0.05))
    puff = mb.make(f"Dandelion_{k:02d}_Puff", FLO, loc=(x, y, 0.33))
    # when the runner passes within 1.2 studs, the puff goes and 8 seeds ride the wind away, rising, and fade
    burst = None
    t = 0.0
    while t < SEC:
        rx, ry = lerp_path(RUN_PATH, t)
        if math.hypot(rx - x, ry - y) < 1.2 and moving(RUN_PATH, t) > 2:
            burst = t
            break
        t += 1 / FPS
    if burst is None:
        continue
    fb = 1 + burst * FPS
    for i in range(3):
        anim(puff, "scale", i, [(1, 1.0), (fb, 1.0), (fb + 2, 0.0), (FRAMES - 30, 0.0), (FRAMES, 1.0)])
    for s_i in range(8):
        mb = Mesh()
        mb.box(seed_m, (0, 0, 0), (0.035, 0.035, 0.05))
        mb.box(seed_m, (0, 0, 0.045), (0.11, 0.11, 0.02))  # the seed's little parachute
        sd = mb.make(f"Dandelion_{k:02d}_Seed{s_i}", FLO)
        a = rng.uniform(0, math.tau)
        out = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.4, 1.2)
        travel = WIND * rng.uniform(4.0, 8.0) + out
        rise = rng.uniform(1.0, 2.4)
        dur = rng.uniform(2.2, 3.4)
        ks = [(fb + dur * FPS * j / 6, (x + travel.x * ease(j / 6) * (j / 6) ** 0.3, y + travel.y * ease(j / 6) * (j / 6) ** 0.3,
                                          0.33 + rise * math.sin(j / 6 * math.pi * 0.6) + 0.15 * math.sin(j * 2.1))) for j in range(7)]
        for i in range(3):
            anim(sd, "location", i, [(1, (x, y, 0.33)[i]), (fb - GAP, (x, y, 0.33)[i])] + [(f, v[i]) for f, v in ks])
            anim(sd, "scale", i, [(1, 0.0), (fb - GAP, 0.0), (fb, 1.0), (fb + dur * FPS, 1.0), (fb + dur * FPS + GAP, 0.0)])
        anim(sd, "color", 3, [(fb, 1.0), (fb + dur * FPS * 0.6, 1.0), (fb + dur * FPS, 0.0)])
        n_seed += 1
print("LIFE floor: mushrooms", n_mush, "clover", n_clover, "dandelions", len(DAND), "row", len(DAND_ROW), "seeds", n_seed, flush=True)

# ======== J: FLOWERS IN THE LIP, VINES AND ROOTS UNDER THE RIM ====================================================
RIM = coll("RimLife")
mb = Mesh()
for i in range(30):
    a = i / 30 * math.tau + rng.uniform(-0.08, 0.08)
    r = RADIUS + 0.28
    z = rng.uniform(-0.9, -0.35)
    c, s_ = math.cos(a), math.sin(a)
    tilt = Matrix.Rotation(-0.7, 4, Vector((-s_, c, 0)))  # leaning out over the edge
    stem_c = Vector((c * r, s_ * r, z))
    mb.box(mat((86, 160, 80)), stem_c, (0.08, 0.08, 0.3), rot=tilt)
    tipv = stem_c + (tilt.to_3x3() @ Vector((0, 0, 0.2)))
    mb.box(mat(rng.choice(BLOOMS[:4])), tipv, (0.2, 0.2, 0.12), rot=tilt)
    if rng.random() < 0.5:
        mb.box(mat((255, 206, 60)), tipv + tilt.to_3x3() @ Vector((0, 0, 0.07)), (0.08, 0.08, 0.05), rot=tilt)
mb.make("LipFlowers", RIM)
vine_leaf, vine_leaf2, vine_stem = mat((70, 150, 74)), mat((104, 176, 88)), mat((60, 112, 58))
root_m, root_m2 = mat((112, 82, 62)), mat((86, 62, 50))
n_vine = n_root = 0
HANGS = []  # clusters round the rim: 2 to 4 vines a few studs apart, a root now and then between them
for cl in range(24):
    a0 = cl / 24 * math.tau + rng.uniform(-0.05, 0.05)
    for v in range(rng.randint(2, 4)):
        HANGS.append((a0 + v * rng.uniform(0.005, 0.009), False))
    if cl % 2 == 0:
        HANGS.append((a0 + rng.uniform(0.04, 0.06), True))
for i, (a, is_root) in enumerate(HANGS):
    c, s_ = math.cos(a), math.sin(a)
    mb = Mesh()
    if is_root:  # a root from the soil's foot: thick tapering blocks, a little crooked
        length, seg = rng.uniform(4.0, 10.0), 0.9
        x = y = 0.0
        for j in range(int(length / seg)):
            w = 0.8 * (1 - j / (length / seg)) + 0.25
            x += rng.uniform(-0.12, 0.12)
            y += rng.uniform(-0.12, 0.12)
            mb.box(rng.choice((root_m, root_m2)), (x, y, -seg * (j + 0.5)), (w, w, seg + 0.05))
        top = (c * (RADIUS + 0.2), s_ * (RADIUS + 0.2), -6.2)
        sway = 0.025
        n_root += 1
    else:  # a vine from under the lip: a stem with leaf blocks on alternate sides
        length = rng.uniform(6.0, 18.0)
        mb.box(vine_stem, (0, 0, -length / 2), (0.16, 0.16, length))
        for j in range(int(length / 0.6)):
            side = 1 if j % 2 else -1
            lz = -0.35 - j * 0.6
            ls = 0.62 * (1 - 0.35 * j / (length / 0.6))
            mb.box(rng.choice((vine_leaf, vine_leaf2)), (side * 0.3 * -s_, side * 0.3 * c, lz), (ls, ls * 0.8, ls * 0.75), rot=Matrix.Rotation(a, 4, "Z"))
        top = (c * (RADIUS + 0.55), s_ * (RADIUS + 0.55), -2.4)
        sway = 0.07
        n_vine += 1
    o = mb.make(f"{'Root' if is_root else 'Vine'}_{i:02d}", RIM, loc=top)
    ph = rng.uniform(0, math.tau)
    per = rng.uniform(4.0, 6.0)
    # swings about its top, out and back across the rim (the axis along the rim), slowly, its own phase
    axis = Vector((-s_, c, 0))
    sample(o, "rotation_euler", 3, lambda t, ph=ph, per=per, axis=axis, sway=sway: tuple(
        (Matrix.Rotation(sway * math.sin(t / per * math.tau + ph), 4, axis) @ Matrix.Rotation(0.3 * sway * math.sin(t / per * 2.7 + ph), 4, "Z")).to_euler()), step=3, interp=2)
print("LIFE rim: vines", n_vine, "roots", n_root, flush=True)

# ======== I: SHEEP AND COWS on the Pasture island (chunky low-poly, grazing: heads down and up, a few steps) =======
ANI = coll("Animals")
wool, face_dark, leg_dark = mat((246, 242, 232)), mat((58, 52, 56)), mat((70, 62, 64))
cow_white, cow_black, cow_pink, horn = mat((244, 242, 236)), mat((44, 40, 46)), mat((236, 170, 170)), mat((236, 222, 190))


def free_spot(isl, rng, taken, gap=9.0, inner=0.55, near=None, radius=0.0):
    """A clear spot on the island (Roblox x, z inside `inner` of its size, or within `radius` of `near`), returned
    in Blender's x, y and the ground's height."""
    name, cx, cz, rx, rz = isl[:5]
    for _ in range(3000):
        if near is not None:
            x, z = near[0] + rng.uniform(-radius, radius), near[1] + rng.uniform(-radius, radius)
            if ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2 > 0.6 ** 2:
                continue
        else:
            a, r = rng.uniform(0, math.tau), math.sqrt(rng.uniform(0, 1)) * inner
            x, z = cx + math.cos(a) * rx * r, cz + math.sin(a) * rz * r
        bx, by = x, -z
        if all(math.hypot(bx - ox, by - oy) > orad + 3.0 for ox, oy, orad in OCC if abs(bx - ox) < 80 and abs(by - oy) < 80) and \
                all(math.hypot(bx - tx, by - ty) > gap for tx, ty in taken):
            return bx, by, island_h(isl, x, z)
    raise SystemExit(f"no free spot on {name}")


def animal(name, kind, at, yaw, rng):
    x, y, z = at
    mb = Mesh()
    if kind == "sheep":  # a woolly block body on dark legs: about 3.6 studs long
        mb.box(wool, (0, 0, 1.75), (2.0, 3.0, 1.6), taper=0.92)
        mb.box(wool, (0, 0.1, 2.55), (1.6, 2.4, 0.5), taper=0.8)
        for lx, ly in ((-0.6, -1.0), (0.6, -1.0), (-0.6, 1.0), (0.6, 1.0)):
            mb.box(leg_dark, (lx, ly, 0.5), (0.4, 0.4, 1.0))
        head_m, head_c, head_s = face_dark, (0, 1.25, 0.25), (0.85, 1.1, 0.85)
    else:  # a cow: white with black patches, pink snout, small horns: about 5.6 studs long
        mb.box(cow_white, (0, 0, 2.7), (2.4, 4.6, 2.0), taper=0.95)
        for px, py, pz, s in ((1.21, -0.6, 2.9, (0.05, 1.6, 1.1)), (-1.21, 0.9, 2.5, (0.05, 1.4, 1.2)), (0.4, 0.3, 3.71, (1.2, 1.3, 0.05))):
            mb.box(cow_black, (px, py, pz), s)
        for lx, ly in ((-0.75, -1.6), (0.75, -1.6), (-0.75, 1.6), (0.75, 1.6)):
            mb.box(cow_white, (lx, ly, 0.85), (0.6, 0.6, 1.7))
            mb.box(cow_black, (lx, ly, 0.15), (0.64, 0.64, 0.3))
        head_m, head_c, head_s = cow_white, (0, 1.9, 0.2), (1.2, 1.5, 1.2)
    body = mb.make(f"{name}", ANI, loc=(x, y, z))
    body.rotation_euler = (0, 0, yaw)
    mb = Mesh()  # the head, hinged at the neck so it can drop to graze
    mb.box(head_m, head_c, head_s)
    if kind == "sheep":
        for ex in (-0.55, 0.55):
            mb.box(face_dark, (ex, head_c[1] - 0.2, head_c[2] + 0.25), (0.35, 0.2, 0.15))
    else:
        mb.box(cow_pink, (0, head_c[1] + 0.8, head_c[2] - 0.3), (1.0, 0.25, 0.6))
        for ex in (-0.5, 0.5):
            mb.box(horn, (ex, head_c[1] - 0.35, head_c[2] + 0.75), (0.2, 0.2, 0.4))
    neck = (0, 1.3, 1.95) if kind == "sheep" else (0, 2.1, 2.9)
    head = mb.make(f"{name}_Head", ANI, loc=neck, parent=body)
    # grazing: head down for a few seconds, up for a few, its own rhythm; a short shuffle now and then
    period, ph = rng.uniform(5.0, 8.0), rng.uniform(0, 1)

    def graze(t, period=period, ph=ph):
        k_ = ((t / period) + ph) % 1.0
        down = ease(k_ / 0.12) * (1 - ease((k_ - 0.55) / 0.12))
        return (-1.3 * down - 0.05 * math.sin(t * 6) * down, 0.0, 0.0)

    sample(head, "rotation_euler", 3, graze, step=2, interp=2)
    step_t = rng.uniform(3, 15)
    fwd = Vector((-math.sin(yaw), math.cos(yaw), 0)) * rng.uniform(1.0, 2.0)
    for i in range(3):
        anim(body, "location", i, [(1, (x, y, z)[i]), (1 + step_t * FPS, (x, y, z)[i]), (1 + (step_t + 1.5) * FPS, (x + fwd.x, y + fwd.y, z)[i]),
                                   (FRAMES, (x + fwd.x, y + fwd.y, z)[i])], interp=2)
    return body


taken = []
herd = []
past = ISLE["Pasture"]
hx, hy, _hz = free_spot(past, rng, [], inner=0.3)  # one herd, grazing together
for i in range(7):
    at = free_spot(past, rng, taken, gap=6.0, near=(hx, -hy), radius=20.0)
    taken.append(at[:2])
    herd.append(animal(f"Sheep_{i}", "sheep", at, rng.uniform(0, math.tau), rng))
for i in range(4):
    at = free_spot(past, rng, taken, gap=9.0, near=(hx, -hy), radius=26.0)
    taken.append(at[:2])
    herd.append(animal(f"Cow_{i}", "cow", at, rng.uniform(0, math.tau), rng))
ham = ISLE["Hamlet"]
cx_, cy_, _cz = free_spot(ham, rng, [], inner=0.35)
for i in range(3):
    at = free_spot(ham, rng, taken, gap=9.0, near=(cx_, -cy_), radius=18.0)
    taken.append(at[:2])
    herd.append(animal(f"Cow_Hamlet_{i}", "cow", at, rng.uniform(0, math.tau), rng))
PASTURE_LOOK = Vector((sum(h.location.x for h in herd[:11]) / 11, sum(h.location.y for h in herd[:11]) / 11, herd[0].location.z))

# ======== I: CHIMNEY SMOKE (the near chimneys; in the game a ParticleEmitter each) ===================================
SMO = coll("ChimneySmoke")
puff_m = mat((236, 236, 240), alpha=0.75, fade=True, rough=1.0)
near = sorted(CHIMNEYS, key=lambda v: v.length)
for c_i, top in enumerate(near):
    for k in range(7):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        me = bpy.data.meshes.new(f"Smoke_{c_i}_{k}")
        bm.to_mesh(me)
        bm.free()
        me.materials.append(puff_m)
        o = bpy.data.objects.new(f"Smoke_{c_i}_{k}", me)
        SMO.objects.link(o)
        o.visible_shadow = False
        period, life = 3.5, 3.5
        start = k * period / 7 + c_i * 0.37
        locs, scs, als = [], [], []
        t0 = start % period - period
        while t0 < SEC + period:
            f0, f1 = 1 + t0 * FPS, 1 + (t0 + life) * FPS
            drift = WIND * 12.0 + Vector((0, 0, 17.0))
            locs += [(f0, tuple(top + Vector((0, 0, 0.8))))]
            locs += [(f1 - GAP, tuple(top + Vector((0, 0, 0.8)) + drift))]
            scs += [(f0, 1.6), (f1 - GAP, 5.5)]
            als += [(f0, 0.0), (f0 + 0.15 * life * FPS, 1.0), (f1 - GAP, 0.0)]
            t0 += period
        for i in range(3):
            anim(o, "location", i, [(f, v[i]) for f, v in locs])
            anim(o, "scale", i, scs)
        anim(o, "color", 3, als)
print("LIFE smoke from", len(near), "chimneys", flush=True)

# ======== I: THE WATERFALL off the windmill's island, toward the arena (in the game: Beam chains, the Ribbon texture
# scrolling, studio_map.py "beams"; it falls into the sky and thins to mist: nothing lands) ============================
WAT = coll("Waterfall")
mill = ISLE["Mill"]
a = math.atan2(0 - mill[2], 0 - mill[1])  # toward the arena, in the island's own x, z
f_ = outline(mill, a)
ex, ez = mill[1] + math.cos(a) * mill[3] * f_ * 0.97, mill[2] + math.sin(a) * mill[4] * f_ * 0.97
ey = island_h(mill, ex, ez)
lip = Vector((ex, -ez, ey))
out_dir = Vector((0 - lip.x, 0 - lip.y, 0)).normalized()
side = Vector((-out_dir.y, out_dir.x, 0))
bm = bmesh.new()
uvl = bm.loops.layers.uv.new("UVMap")
rows = 24
width = 12.0
prev = None
for j in range(rows + 1):
    s = j / rows
    drop = 150.0 * s
    fwd = 9.0 * math.sqrt(s) + 2.0
    w = width * (1 + 0.6 * s)
    c = lip + out_dir * fwd + Vector((0, 0, -drop))
    row = [bm.verts.new(c + side * (w / 2) * k_) for k_ in (-1, -0.5, 0, 0.5, 1)]
    if prev:
        for i in range(4):
            f = bm.faces.new((prev[i], prev[i + 1], row[i + 1], row[i]))
            for lp, (u, v) in zip(f.loops, ((i / 4, (j - 1) / rows), ((i + 1) / 4, (j - 1) / rows), ((i + 1) / 4, j / rows), (i / 4, j / rows))):
                lp[uvl].uv = (u, v * 6)
    prev = row
me = bpy.data.meshes.new("Waterfall")
bm.to_mesh(me)
bm.free()
m = bpy.data.materials.new("Life_Waterfall")
m.use_nodes = True
nt = m.node_tree
p = nt.nodes["Principled BSDF"]
p.inputs["Base Color"].default_value = lin((200, 236, 250)) + (1.0,)
p.inputs["Emission Color"].default_value = lin((200, 236, 250)) + (1.0,)
p.inputs["Emission Strength"].default_value = 0.25
tc, mp, wave, mix, grad = (nt.nodes.new(t) for t in ("ShaderNodeTexCoord", "ShaderNodeMapping", "ShaderNodeTexWave", "ShaderNodeMath", "ShaderNodeSeparateXYZ"))
mp.name = "FallMapping"
wave.wave_type = "BANDS"
wave.bands_direction = "Y"
wave.inputs["Scale"].default_value = 3.0
wave.inputs["Distortion"].default_value = 6.0
nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
nt.links.new(tc.outputs["UV"], grad.inputs["Vector"])
fade = nt.nodes.new("ShaderNodeMapRange")  # thinning to mist at the bottom: alpha from 0.85 at the lip to 0 at 6 (UV v)
fade.inputs["From Min"].default_value, fade.inputs["From Max"].default_value = 3.5, 6.0
fade.inputs["To Min"].default_value, fade.inputs["To Max"].default_value = 0.85, 0.0
nt.links.new(grad.outputs["Y"], fade.inputs["Value"])
mix.operation = "MULTIPLY"
streak = nt.nodes.new("ShaderNodeMapRange")
streak.inputs["To Min"].default_value, streak.inputs["To Max"].default_value = 0.55, 1.0
nt.links.new(wave.outputs["Fac"], streak.inputs["Value"])
nt.links.new(streak.outputs[0], mix.inputs[0])
nt.links.new(fade.outputs[0], mix.inputs[1])
nt.links.new(mix.outputs[0], p.inputs["Alpha"])
try:
    m.surface_render_method = "BLENDED"
except (AttributeError, TypeError):
    pass
me.materials.append(m)
fall = bpy.data.objects.new("Waterfall", me)
WAT.objects.link(fall)
fall.visible_shadow = False
anim(nt, 'nodes["FallMapping"].inputs[1].default_value', 1, [(1, 0.0), (FRAMES, -2.4 * SEC)])  # the water runs down
for k in range(8):  # mist puffs where it thins out
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
    me = bpy.data.meshes.new(f"Mist_{k}")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(puff_m)
    o = bpy.data.objects.new(f"Mist_{k}", me)
    WAT.objects.link(o)
    o.visible_shadow = False
    base_c = lip + out_dir * 14 + Vector((0, 0, -110)) + side * rng.uniform(-8, 8)
    period = 4.0
    t0 = k * period / 8 - period
    locs, scs, als = [], [], []
    while t0 < SEC + period:
        f0, f1 = 1 + t0 * FPS, 1 + (t0 + period) * FPS
        locs += [(f0, tuple(base_c)), (f1 - GAP, tuple(base_c + Vector((0, 0, -25)) + out_dir * 6))]
        scs += [(f0, 4.0), (f1 - GAP, 9.0)]
        als += [(f0, 0.0), (f0 + 0.3 * period * FPS, 0.7), (f1 - GAP, 0.0)]
        t0 += period
    for i in range(3):
        anim(o, "location", i, [(f, v[i]) for f, v in locs])
        anim(o, "scale", i, scs)
    anim(o, "color", 3, als)
# the stream that feeds it: a strip of water over the island's top to the edge, white foam where it tips over
mb = Mesh()
stream_m, foam_m = mat((120, 200, 230), rough=0.3), mat((246, 252, 255))
back = -out_dir
bank = []
for j in range(13):
    p0 = lip + back * (j * 3.0)
    bank.append(Vector((p0.x, p0.y, island_h(mill, p0.x, -p0.y) + 0.3)))
for j in range(12):
    w0, w1 = 5.0 + 2.0 * j / 12, 5.0 + 2.0 * (j + 1) / 12
    a_, b_ = bank[j], bank[j + 1]
    mb.poly(stream_m, [a_ - side * w0 / 2, a_ + side * w0 / 2, b_ + side * w1 / 2, b_ - side * w1 / 2])
mb.make("Waterfall_Stream", WAT)
for k in range(7):  # foam blocks along the drop, each bobbing on its own beat
    mb = Mesh()
    s = rng.uniform(0.9, 1.6)
    mb.box(foam_m, (0, 0, 0), (s, s, s * 0.6))
    fo = mb.make(f"Waterfall_Foam{k}", WAT, loc=tuple(lip + side * (k - 3) * 1.6 + out_dir * 1.2 + Vector((0, 0, 0.3))))
    z0, ph = fo.location.z, rng.uniform(0, math.tau)
    anim(fo, "location", 2, [(f, z0 + 0.25 * math.sin((f - 1) / FPS * 5 + ph)) for f in range(1, FRAMES + 1, 2)])
WATERFALL_LOOK = lip + Vector((0, 0, -50))

# ======== G: BIRDS (chunky low-poly: three flocks; one sweeps round under the arena's rim) ==========================
BRD = coll("Birds")
gull_w, gull_g, beak = mat((244, 244, 240)), mat((150, 158, 176)), mat((246, 168, 60))
swal_b, swal_w = mat((52, 66, 120)), mat((240, 236, 228))
FLOCKS = [  # centre (Blender x, y, z), radii, loop direction, kind, count
    ((-150.0, 420.0, 70.0), (170.0, 110.0), 1, "gull", 6),
    ((420.0, 120.0, 55.0), (150.0, 120.0), -1, "gull", 5),
    ((0.0, 0.0, -24.0), (198.0, 198.0), 1, "swallow", 6),
]
for f_i, (cen, (rx, ry), dirn, kind, count) in enumerate(FLOCKS):
    for b_i in range(count):
        s = 1.3 if kind == "gull" else 0.6
        mb = Mesh()
        body_m, wing_m = (gull_w, gull_g) if kind == "gull" else (swal_b, swal_b)
        mb.box(body_m, (0, 0, 0), (0.9 * s, 2.6 * s, 0.8 * s), taper=0.8)
        mb.box(body_m if kind == "gull" else swal_w, (0, 1.4 * s, 0.25 * s), (0.75 * s, 0.8 * s, 0.7 * s))
        mb.box(beak, (0, 1.95 * s, 0.2 * s), (0.25 * s, 0.4 * s, 0.2 * s))
        mb.box(wing_m, (0, -1.6 * s, 0.05 * s), (0.9 * s if kind == "gull" else 1.4 * s, 0.9 * s, 0.15 * s), taper=1.0)  # tail
        bird = mb.make(f"Bird_{f_i}_{b_i}", BRD)
        for side_ in (-1, 1):
            mb = Mesh()
            span = (2.4 if kind == "gull" else 2.0) * s
            mb.box(wing_m, (side_ * span / 2, 0.1 * s, 0), (span, 1.1 * s, 0.14 * s))
            mb.box(cow_black if kind == "gull" else swal_b, (side_ * (span - 0.3 * s), -0.05 * s, 0), (0.6 * s, 0.9 * s, 0.15 * s))
            w = mb.make(f"Bird_{f_i}_{b_i}_Wing", BRD, loc=(side_ * 0.4 * s, 0, 0.15 * s), parent=bird)
            ph = rng.uniform(0, 1)
            sample(w, "rotation_euler", 3, lambda t, side_=side_, ph=ph, kind=kind: (
                0.0, -side_ * (0.15 + (0.55 if kind == "gull" else 0.7) * math.sin(t * (3.0 if kind == "gull" else 5.0) * math.tau)
                             * (0.5 + 0.5 * math.cos(t * 0.9 + ph * 6))), 0.0), step=1)
        lag = b_i * 0.035 * dirn
        offs = Vector((rng.uniform(-14, 14), rng.uniform(-14, 14), rng.uniform(-8, 8))) * (0.4 if kind == "swallow" else 1.0)

        def fly(t, cen=cen, rx=rx, ry=ry, dirn=dirn, lag=lag, offs=offs):
            a = dirn * (t / SEC) * math.tau - lag * math.tau
            return Vector((cen[0] + rx * math.cos(a), cen[1] + ry * math.sin(a), cen[2] + 6 * math.sin(a * 3))) + offs

        sample(bird, "location", 3, lambda t, fly=fly: tuple(fly(t)), step=3)

        def turn(t, fly=fly):
            p0, p1 = fly(t), fly(t + 0.2)
            yaw = math.atan2(p1.y - p0.y, p1.x - p0.x) - math.pi / 2
            return (0.0, dirn * 0.25, yaw)  # banked into the turn

        sample(bird, "rotation_euler", 3, turn, step=3)

# ======== H: HOT-AIR BALLOONS (chunky low-poly: a striped envelope, basket, ropes), drifting slowly, bobbing ========
BAL = coll("Balloons")
BALLOONS = [((-330.0, 640.0, 120.0), ((214, 64, 58), (246, 232, 200)), Vector((1.0, 0.4, 0))),
            ((260.0, 760.0, 170.0), ((32, 168, 170), (255, 214, 72)), Vector((-0.6, 1.0, 0)))]
for b_i, (at, (c1, c2), drift) in enumerate(BALLOONS):
    mb = Mesh()
    prof = [(0.0, 0.0), (3.0, 0.6), (7.0, 3.5), (10.0, 8.0), (11.0, 13.0), (10.0, 18.0), (7.0, 22.0), (3.5, 24.0), (0.0, 24.6)]
    n = 12
    rings_ = [[Vector((math.cos(i / n * math.tau) * r, math.sin(i / n * math.tau) * r, 8 + z)) for i in range(n)] for r, z in prof]
    for j in range(len(rings_) - 1):
        for i in range(n):
            q = [rings_[j][i], rings_[j][(i + 1) % n], rings_[j + 1][(i + 1) % n], rings_[j + 1][i]]
            m_ = mat(c1) if i % 2 == 0 else mat(c2)
            if q[0] == q[1]:
                mb.poly(m_, [q[0], q[2], q[3]])
            elif q[2] == q[3]:
                mb.poly(m_, [q[0], q[1], q[2]])
            else:
                mb.poly(m_, q)
    mb.box(mat((150, 104, 66)), (0, 0, 1.5), (4.6, 4.6, 3.0), taper=1.08)
    mb.box(mat((104, 72, 50)), (0, 0, 3.1), (5.0, 5.0, 0.4))
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        bot = Vector((sx * 2.1, sy * 2.1, 3.2))
        topv = Vector((sx * 2.8, sy * 2.8, 8.6))
        mid = (bot + topv) / 2
        d = topv - bot
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        mb.box(mat((86, 66, 52)), mid, (0.35, 0.35, d.length), rot=rot)
    bal = mb.make(f"Balloon_{b_i}", BAL)
    ph = rng.uniform(0, math.tau)
    sample(bal, "location", 3, lambda t, at=at, drift=drift, ph=ph: tuple(Vector(at) + drift.normalized() * 2.5 * t + Vector((0, 0, 2.0 * math.sin(t / 7 * math.tau + ph)))), step=5, interp=2)
    sample(bal, "rotation_euler", 3, lambda t, ph=ph: (0.02 * math.sin(t / 6 * math.tau + ph), 0.02 * math.cos(t / 5 * math.tau + ph), 0.08 * math.sin(t / 20 * math.tau)), step=5, interp=2)

# ======== THE DEMO FIGHTERS' MOTION ==================================================================================
dasher, dparts = fighter("Demo_Dasher", (238, 96, 92))
drive_fighter(dasher, dparts, lambda t: (*lerp_path(DASH_PATH, t), 0.0, heading_of(DASH_PATH, t)),
              lambda t: 0.6 * math.sin(t * 9) if moving(DASH_PATH, t) > 0.5 else 0.0)
wader, wparts = fighter("Demo_Wader", (52, 96, 214))
drive_fighter(wader, wparts, lambda t: (*lerp_path(WADE_PATH, t), pond_floor(*lerp_path(WADE_PATH, t)), heading_of(WADE_PATH, t)),
              lambda t: 0.45 * math.sin(t * 7) if moving(WADE_PATH, t) > 0.3 else 0.0)
runner, rparts = fighter("Demo_Runner", (250, 206, 70))
drive_fighter(runner, rparts, lambda t: (*lerp_path(RUN_PATH, t), 0.0, heading_of(RUN_PATH, t)),
              lambda t: 0.7 * math.sin(t * 11) if moving(RUN_PATH, t) > 0.5 else 0.0)

# ======== THE WINDMILL'S SAILS TURN (owner 2026-11-26: "can we make the win dmill move in the background", then "it should
# be notiacble that its moving tho, dont make it slow"): MapEnvironments.Maps.meadow.spinners, as the game turns them
# (Shared/MapExtras): about the hub {-375.39, 292.69, -797.7} on the axis {0.4258, 0, 0.9048} (Roblox, arena-local), at
# 9 turns a minute: three turns in the 20 s loop, so it loops without a jump ====================================
hubo = bpy.data.objects.new("Windmill_Hub", None)
LIFE.objects.link(hubo)
hubo.location = (-375.39, 797.7, 292.69)
hubo.rotation_mode = "AXIS_ANGLE"
_ax = Vector((0.4258, -0.9048, 0.0)).normalized()
hubo.rotation_axis_angle = (0.0, _ax.x, _ax.y, _ax.z)
bpy.context.view_layer.update()
for _o in [o for o in bpy.data.objects if "WindmillSails" in o.name]:
    _mw = _o.matrix_world.copy()
    _o.parent = hubo
    _o.matrix_parent_inverse = hubo.matrix_world.inverted()
    _o.matrix_world = _mw
anim(hubo, "rotation_axis_angle", 0, [(1, 0.0), (FRAMES + 1, 9 / 60 * SEC * math.tau)])

# ======== CAMERAS to check each piece, the timeline, the light ======================================================
def camera(name, loc, target, lens):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    cam.clip_start = 0.05
    cam.clip_end = 20000
    o = bpy.data.objects.new(name, cam)
    LIFE.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return o


b0 = Vector((BUT0_HOME[0], BUT0_HOME[1], 0.0))
side_v = Vector((-dash_dir.y, dash_dir.x, 0.0))
mid = DAND_ROW[len(DAND_ROW) // 2]
run_dir = Vector((20.0, 10.0, 0.0)).normalized()
perp = Vector((-run_dir.y, run_dir.x, 0.0))
to_arena = Vector((-PASTURE_LOOK.x, -PASTURE_LOOK.y, 0.0)).normalized()
LOOKS = {
    # the player's own view of the dash: behind the fighter, the butterfly darting aside as it comes
    "Look_1_Butterflies": camera("Look_1_Butterflies", tuple(Vector((*DASHER_FROM, 0.0)) - dash_dir * 7.0 + Vector((0, 0, 4.5))),
                                 tuple(b0 + dash_dir * 2.0 + Vector((0, 0, 1.8))), 30),
    "Look_1b_ButterflyClose": camera("Look_1b_ButterflyClose", (homes[1][0] + 4.5, homes[1][1] - 4.5, 2.4), (homes[1][0], homes[1][1], 1.4), 40),
    "Look_1c_BeeClose": camera("Look_1c_BeeClose", (34.0, -54.0, 1.6), (34.0, -48.0, 0.6), 40),
    "Look_2_Pond": camera("Look_2_Pond", (-22.0, -30.0, 6.5), (-6.0, -4.0, -0.4), 28),
    "Look_3_Dandelions": camera("Look_3_Dandelions", tuple(Vector((mid[0], mid[1], 0.0)) - perp * 9.0 + Vector((0, 0, 2.4))), (mid[0], mid[1], 0.6), 32),
    "Look_3b_FairyRing": camera("Look_3b_FairyRing", (RING_AT[0], RING_AT[1] - 5.5, 2.4), (RING_AT[0], RING_AT[1], 0.1), 28),
    "Look_4_Arena": camera("Look_4_Arena", (3.0, -66.0, 12.5), (0.0, 60.0, 8.0), 20),
    "Look_5_SkyNorth": camera("Look_5_SkyNorth", (0.0, 40.0, 14.0), (-150.0, 900.0, 120.0), 24),
    "Look_6_Pasture": camera("Look_6_Pasture", tuple(PASTURE_LOOK + to_arena * 48 + Vector((0, 0, 18))), tuple(PASTURE_LOOK + Vector((0, 0, 2))), 30),
    "Look_7_Waterfall": camera("Look_7_Waterfall", tuple(lip + out_dir * 220 + Vector((40, 0, -10))), tuple(WATERFALL_LOOK), 30),
    "Look_8_Rim": camera("Look_8_Rim", (-30.0, -236.0, 4.0), (8.0, -178.0, -7.0), 24),
    "Look_9_Village": camera("Look_9_Village", (-60.0, 520.0, 110.0), (-120.0, 1150.0, 110.0), 30),
}
chase = camera("Look_10_GullChase", (0, 0, 0), (0, 1, 0), 30)
chase.parent = bpy.data.objects["Bird_0_0"]
chase.location = (0.0, -11.0, 3.5)
chase.rotation_euler = Vector((0.0, 11.0, -3.5)).to_track_quat("-Z", "Y").to_euler()
LOOKS["Look_10_GullChase"] = chase
for cam_name, target in (("Look_1b_ButterflyClose", "Butterfly_01"), ("Look_1c_BeeClose", "Bee_0")):  # these follow their subject
    con = LOOKS[cam_name].constraints.new("TRACK_TO")
    con.target = bpy.data.objects[target]
    con.track_axis, con.up_axis = "TRACK_NEGATIVE_Z", "UP_Y"
scene.camera = LOOKS["Look_4_Arena"]
scene.render.fps = FPS
scene.frame_start, scene.frame_end = 1, FRAMES
scene.frame_current = 1
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        continue
print("LIFE engine", scene.render.engine, flush=True)
tris = {}
for c in LIFE.children:
    tris[c.name] = sum(len(o.data.polygons) for o in c.objects if o.type == "MESH")
print("LIFE triangles by piece (quads count once)", tris, flush=True)
path = os.path.join(OUT, "meadow_life_preview.blend")
bpy.ops.wm.save_as_mainfile(filepath=path)
print("LIFE PREVIEW", path, flush=True)
