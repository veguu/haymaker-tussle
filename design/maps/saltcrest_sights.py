"""Saltcrest's sights: a working coast, 700 studs below.

Round the compass (the coast is the -X side, open sea the +X side):
- West, far below: the bay. A smaller harbour village, a dock on piles with two moored boats, fishing
  nets drying on racks along the beach.
- West-south-west: the near headland, with a striped sailboat rounding its tip (wake behind it).
- South-west: the salt pans that give the place its name: a grid of brine ponds in three stages,
  white cones of raked salt, a windpump.
- Farther along the shore: the lighthouse on the far headland, banded red and white.
- North, middle distance: Net Rock, a sea stack that climbs most of the way up to the plaza, with a
  fisher's deck lashed to its top, nets on racks, a hut and a hoist with a boat hanging from it.
- East: open sea, three small sails far out, one low island with a beacon, and on the horizon a
  squall: a tall cloud trailing rain.

Everything on the ground is hazed toward the sky so the coast stays low in contrast; Net Rock is near
and keeps its colour.
"""
import math

import bmesh
from mathutils import Matrix

import common as C
import sights as K

GROUND = -700.0
PANS = (-1060.0, -905.0, -365.0, -165.0)  # x0, x1, y0, y1: flattened for the salt pans
COL = {
    "wall": (246, 243, 232),
    "roof": (214, 122, 64),
    "roof2": (190, 98, 52),
    "accent": (44, 138, 128),
    "road": (226, 208, 168),
    "timber": (140, 100, 64),
    "dark": (78, 64, 56),
    "net": (188, 214, 196),
    "float": (232, 120, 50),
    "hull": (150, 96, 60),
    "hull2": (52, 110, 128),
    "sail": (250, 247, 238),
    "stripe": (232, 120, 50),
    "foam": (240, 246, 248),
    "salt": (248, 246, 240),
    "saltwall": (224, 216, 196),
    "brine1": (150, 206, 200),
    "brine2": (190, 222, 208),
    "brine3": (226, 232, 222),
    "lh_red": (206, 58, 44),
    "lh_white": (246, 244, 236),
    "lamp": (252, 236, 160),
    "grass": (120, 160, 84),
    "rock": (170, 150, 124),
}
NET_ROCK = (30.0, 380.0, -112.0)


def coast_x(y):
    """The coastline: x of the shore for a given y. A harbour bay, a near headland, a far headland."""
    return (
        -760
        + 90 * math.sin(y / 260.0)
        + 45 * math.sin(y / 95.0 + 1.3)
        - 130 * math.exp(-((y - 140) / 120.0) ** 2)
        + 130 * math.exp(-((y + 70) / 60.0) ** 2)
        + 170 * math.exp(-((y + 640) / 80.0) ** 2)
    )


def land_height(x, y):
    inland = coast_x(y) - x  # positive on land (land is toward -X)
    if inland < 0:
        return GROUND - 6 + max(inland, -40) * 0.05
    rise = min(inland / 6.0, 4) + max(inland - 80, 0) * 0.07
    hills = 30 * (math.sin(x / 150.0) * math.cos(y / 170.0) + 1) + 20 * math.sin(x / 61.0 + y / 83.0)
    mountains = max(inland - 900, 0) / 1600.0
    peaks = 260 * mountains * (1.2 + math.sin(y / 230.0) * math.cos(x / 310.0))
    h = GROUND + rise + max(hills, 0) * min(max(inland - 40, 0) / 150.0, 1.0) + max(peaks, 0)
    # the headlands are rocky and stand up from the water
    for yc, wide in ((-70, 55), (-640, 70)):
        h += 40 * math.exp(-((y - yc) / wide) ** 2) * K.smooth(0, 60, inland) * K.smooth(420, 180, inland)
    x0, x1, y0, y1 = PANS
    m = K.smooth(x0 - 120, x0, x) * K.smooth(x1 + 30, x1, x) * K.smooth(y0 - 120, y0, y) * K.smooth(y1 + 60, y1, y)
    return h + (GROUND + 3.5 - h) * m


CAMS = {
    # From the rim at the height of a player's camera (16), which is what clears the eaves. Anything
    # steeper than about 58 degrees down is hidden behind them, so nothing is placed that close in.
    "Sight_Bay": ((-113.5, 20, 16), (-640, 170, -700), 35),
    "Sight_Headland": ((-113.5, -30, 16), (coast_x(-70) + 30, -150, -700), 60),
    "Sight_SaltPans": ((-112, -24, 16), (-980, -265, -700), 70),
    "Sight_Lighthouse": ((-108, -34, 16), (coast_x(-640) - 20, -640, -640), 85),
    "Sight_NetRock": ((24, 93.5, 16), (30, 335, -128), 35),
    "Sight_OpenSea": ((113.5, 0, 16), (1300, -120, -700), 35),
}


def hull(bm, length=64.0, beam=16.0, depth=7.0):
    outline = [(-0.47, -0.5), (0.19, -0.5), (0.53, 0.0), (0.19, 0.5), (-0.47, 0.5)]
    top = [bm.verts.new((x * length, y * beam, depth)) for x, y in outline]
    bot = [bm.verts.new((x * length * 0.9, y * beam * 0.55, 0)) for x, y in outline]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(5):
        n = (i + 1) % 5
        bm.faces.new((top[i], bot[i], bot[n], top[n]))


def boat(k, pos, scale, heading, sail=True, key="hull", wake=False):
    """A sailboat built heading +X at the origin, then placed. The sail is banded cream and orange."""
    m = k.mark()
    hull(k.bm(key))
    k.box("wall", (-10, 0, 8.5), (16, 8, 3))
    if sail:
        k.cyl("dark", (0, 0, 7), (0, 0, 86), 0.9, 6)
        k.cyl("dark", (0, 0, 14), (-29, 0, 14), 0.6, 5)

        def edge(z):
            return -28 * (84 - z) / 70.0

        for b in range(4):
            z0, z1 = 14 + b * 17.5, 14 + (b + 1) * 17.5
            K.quad2(k.bm("sail" if b % 2 == 0 else "stripe"), (-0.9, 0, z0), (edge(z0), 0, z0), (edge(z1), 0, z1), (-0.9, 0, z1))
        K.tri2(k.bm("sail"), (1.2, 0, 78), (33, 0, 8.5), (3, 0, 13))
        K.tri2(k.bm("stripe"), (0, 0, 87), (0, 0, 82), (-9, 0, 84.5))
    if wake:
        f = k.bm("foam")
        for s in (-1, 1):
            f.faces.new([f.verts.new(p) for p in ((-26, s * 4, 2.4), (-104, s * 21, 2.4), (-110, s * 29, 2.4))][:: -s])
            f.faces.new([f.verts.new(p) for p in ((30, s * 2, 2.4), (-6, s * 9, 2.4), (-6, s * 13, 2.4))][:: -s])
    k.move(m, Matrix.Translation(pos) @ Matrix.Rotation(heading, 4, "Z") @ Matrix.Scale(scale, 4))


def build_sea_and_land():
    sea = bmesh.new()
    C.oval_prism(sea, 3200, 3200, GROUND - 4, GROUND - 6, segments=64)
    mat, nt, bsdf = C.new_material("Saltcrest_Sea")
    tc = C.coords(nt)
    sep = C.separate(nt, tc.outputs["Object"])
    stops = [(0.0, (0.18, 0.62, 0.66)), (0.4, (0.10, 0.45, 0.62)), (1.0, (0.06, 0.32, 0.56))]
    shallow = C.ramp(nt, [(p, K.hazed(c, 0.22)) for p, c in stops])
    xs = C.math_node(nt, "ADD", sep.outputs["X"], value_b=760.0)
    xn = C.math_node(nt, "DIVIDE", xs.outputs[0], value_b=900.0)
    nt.links.new(xn.outputs[0], shallow.inputs["Fac"])
    nt.links.new(shallow.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.4
    C.mesh_object("Below_Sea", sea, mat)

    stops = [(0.0, (0.93, 0.85, 0.62)), (0.012, (0.93, 0.85, 0.62)), (0.02, (0.48, 0.72, 0.30)), (0.15, (0.34, 0.60, 0.24)), (0.45, (0.26, 0.50, 0.24)), (0.75, (0.40, 0.52, 0.36)), (0.95, (0.62, 0.66, 0.58))]
    mat = K.height_material("Saltcrest_Land", stops, GROUND, GROUND + 500, haze=0.22, linear=True)
    # fine near the shore so the bay, headlands and pans keep their shape; coarse inland and far away
    xs = K.linspace(-3400, -1150, 26) + K.linspace(-1100, -420, 41)
    ys = K.linspace(-2200, -950, 14) + K.linspace(-900, 520, 72) + K.linspace(580, 2200, 14)
    K.terrain("Below_Land", land_height, xs, ys, mat, smooth_shade=True)


def build_bay(k, rng):
    """The harbour village (half the old size), its road, the dock and the net racks."""
    placed, tries = [], 0
    while len(placed) < 22 and tries < 600:
        tries += 1
        y = rng.uniform(40, 270)
        x = coast_x(y) - rng.uniform(34, 180)
        z = land_height(x, y)
        if z < GROUND + 2 or any(math.hypot(x - a, y - b) < 38 for a, b in placed):
            continue
        placed.append((x, y))
        i = len(placed)
        K.house(k, (x, y, z - 3), rng.uniform(24, 34), rng.uniform(18, 26), rng.uniform(13, 21) + 3, rng.uniform(-0.3, 0.3), "wall", "accent" if i % 7 == 0 else ("roof" if i % 2 else "roof2"))
    tx, ty = coast_x(150) - 70, 150.0
    tz = land_height(tx, ty)
    k.box("wall", (tx, ty, tz + 28), (15, 15, 60))
    k.cone("roof2", (tx, ty, tz + 58), 12, 16, 4)
    pts = [(coast_x(150) - 30, 150.0)]
    for i in range(60):
        px, py = pts[-1]
        pts.append((px - 22, py + 40 * math.sin(i / 6.0)))
    K.strip(k.bm("road"), pts, 9, land_height, lift=0.8, step=30)
    # the dock: a deck on piles with a T-head, two boats alongside
    x0 = coast_x(150) - 8
    k.box("timber", (x0 + 75, 150, GROUND + 2.6), (150, 14, 1.6))
    k.box("timber", (x0 + 152, 150, GROUND + 2.6), (18, 44, 1.6))
    for i in range(7):
        for s in (-1, 1):
            k.cyl("dark", (x0 + 6 + i * 24, 150 + s * 6, GROUND - 7), (x0 + 6 + i * 24, 150 + s * 6, GROUND + 2), 1.6, 6)
    boat(k, (x0 + 96, 172, GROUND - 5.5), 0.45, 0.1, key="hull2")
    boat(k, (x0 + 138, 190, GROUND - 5.5), 0.4, 2.7, sail=False)
    # nets drying along the beach beside it, floats still on, and three rowboats pulled up
    for i in range(5):
        y = 200 + i * 27
        x = coast_x(y) - 16
        K.net_rack(k, (x, y, land_height(x, y)), 22 + 4 * (i % 2), 15 + 2 * (i % 3), rng.uniform(-0.2, 0.2))
    for i, y in enumerate((106, 120, 96)):
        x = coast_x(y) - 9
        m = k.mark()
        hull(k.bm("hull2" if i == 1 else "hull"), 22, 7, 3)
        k.move(m, Matrix.Translation((x, y, land_height(x, y) + 0.3)) @ Matrix.Rotation(0.3 * i - 0.2, 4, "Z"))


def build_salt_pans(k, rng):
    x0, x1, y0, y1 = PANS
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    k.box("saltwall", (cx, cy, GROUND + 3.7), (x1 - x0 - 8, y1 - y0 - 8, 1.2))
    for c in range(3):
        for r in range(4):
            key = ("brine1", "brine2", "brine3")[(c + (r % 2)) % 3 if c < 2 else 2]
            k.box(key, (x1 - 30 - c * 47, y0 + 29 + r * 47.5, GROUND + 4.5), (42, 42.5, 0.5))
    for i in range(6):
        y = y0 + 22 + i * 32
        k.cone("salt", (x0 - 18, y, land_height(x0 - 18, y) - 0.5), 10 + (i % 2) * 2, 12 + (i % 3), 8)
    # a windpump at the seaward corner, and the salters' shed
    px, py = x1 + 18, y1 + 6
    pz = land_height(px, py)
    k.cyl("timber", (px, py, pz), (px, py, pz + 36), 1.4, 6)
    for i in range(4):
        a = i * math.pi / 2 + 0.4
        u = (0.0, math.cos(a), math.sin(a))
        v = (0.0, -math.sin(a), math.cos(a))
        hub = (px + 1.6, py, pz + 36)

        def at(r, w):
            return (hub[0], hub[1] + u[1] * r + v[1] * w, hub[2] + u[2] * r + v[2] * w)

        K.quad2(k.bm("sail"), at(3, -0.8), at(17, -3), at(17, 3), at(3, 0.8))
    sx, sy = x0 + 10, y0 - 34
    K.house(k, (sx, sy, land_height(sx, sy) - 2), 30, 20, 14, 0.2, "wall", "roof")


def build_headland_and_light(k, rng):
    # the sailboat rounding the near headland, heeling on to its new course
    tip = coast_x(-70)
    boat(k, (tip + 60, -168, GROUND - 5.5), 1.15, math.radians(78), wake=True)
    # the lighthouse on the far headland
    lx, ly = coast_x(-640) - 30, -640.0
    lz = land_height(lx, ly)
    for i in range(6):
        k.cyl("lh_red" if i % 2 == 0 else "lh_white", (lx, ly, lz + i * 26), (lx, ly, lz + (i + 1) * 26), 18 - i * 1.3, 12)
    k.cyl("dark", (lx, ly, lz + 156), (lx, ly, lz + 159), 15, 12)
    k.cyl("lamp", (lx, ly, lz + 159), (lx, ly, lz + 171), 8, 10)
    k.cone("lh_red", (lx, ly, lz + 171), 10.5, 12, 12)
    K.house(k, (lx - 34, ly + 10, land_height(lx - 34, ly + 10) - 2), 28, 20, 14, 0.4, "wall", "roof")


def build_open_sea(rng):
    k = K.Kit("Below_FarBoats", COL, haze=0.4)
    for x, y, h in ((1000, -420, 0.5), (1250, 60, 2.2), (1480, -180, 4.0)):
        boat(k, (x, y, GROUND - 5), 0.65, h)
    k.finish()
    k = K.Kit("Below_FarIsle", COL, haze=0.5)
    m = k.mark()
    C.oval_prism(k.bm("rock"), 300, 190, GROUND + 36, GROUND - 6, segments=12, jitter=0.1, rng=rng, taper=1.3)
    k.cone("grass", (-40, 0, GROUND + 36), 150, 70, 8)
    k.cyl("lh_white", (110, 20, GROUND + 36), (110, 20, GROUND + 106), 12, 8)
    k.cone("lh_red", (110, 20, GROUND + 106), 14, 14, 8)
    k.move(m, Matrix.Translation((2400, -500, 0)))
    k.finish()


def build_net_rock(rng):
    rx, ry, top = NET_ROCK
    rock = bmesh.new()
    K.ring_stack(rock, (rx, ry), [(96, GROUND - 6), (74, -430), (46, -215), (55, top - 16), (50, top - 2)], sides=10, rng=rng, jitter=0.1)
    C.mesh_object("Sight_Land_NetRock", rock, K.rock_material("Saltcrest_NetRock", (204, 160, 112), haze=0.05))
    k = K.Kit("Sight_NetRock", COL, haze=0.03)
    m = k.mark()
    C.oval_prism(k.bm("grass"), 49, 49, top + 1, top - 2.5, segments=10)
    k.move(m, Matrix.Translation((rx, ry, 0)))
    K.house(k, (rx + 10, ry + 16, top + 1), 22, 16, 11, 0.3, "wall", "roof", gable_key="accent")
    # the fisher's deck, cantilevered toward the plaza and braced back to the rock
    k.box("timber", (rx, ry - 58, top + 0.4), (58, 34, 1.6))
    for sx in (-25, 0, 25):
        k.cyl("dark", (rx + sx, ry - 73, top - 0.4), (rx + sx * 0.6, ry - 44, top - 34), 1.0, 5)
    for sx in (-28, 28):
        for sy in (-74, -58, -44):
            k.cyl("dark", (rx + sx, ry + sy, top + 1), (rx + sx, ry + sy, top + 5), 0.4, 4)
    south = -math.pi / 2
    K.net_rack(k, (rx - 15, ry - 54, top + 1.2), 22, 14, south)
    K.net_rack(k, (rx + 12, ry - 56, top + 1.2), 20, 13, south)
    K.net_rack(k, (rx - 22, ry + 2, top + 1), 22, 14, south - 0.5)
    for i, (ox, oy) in enumerate(((22, -44), (25, -47.5), (-4, -68))):
        k.cyl("float" if i != 1 else "accent", (rx + ox, ry + oy, top + 1.2), (rx + ox, ry + oy, top + 4.6), 1.6, 8)
    # the hoist, with the boat hanging clear of the rock
    hx, hy = rx + 27, ry - 72
    k.cyl("dark", (hx, hy, top + 1), (hx, hy, top + 26), 0.9, 6)
    k.cyl("dark", (hx, hy, top + 26), (hx + 14, hy - 12, top + 24), 0.7, 5)
    k.cyl("dark", (hx, hy, top + 12), (hx + 9, hy - 8, top + 24.5), 0.4, 4)
    k.cyl("dark", (hx + 14, hy - 12, top + 24), (hx + 14, hy - 12, top - 12), 0.22, 4)
    boat(k, (hx + 14, hy - 12, top - 16), 0.3, 0.5, sail=False, key="hull2")
    K.pennants(k, (rx + 10, ry + 16, top + 19), (rx - 30, ry - 26, top + 15), ["accent", "float", "sail"], n=9, sag=2.5, size=3.0, string="dark")
    k.cyl("dark", (rx - 30, ry - 26, top + 1), (rx - 30, ry - 26, top + 15.5), 0.5, 5)
    k.finish()


def build_squall(rng):
    """East, on the horizon: a squall far out to sea, a tall cloud with a flat grey base and slanting
    rain under it. The one tall thing on the sea side; it frames that end of the plaza."""
    k = K.Kit("Sight_Squall", {"white": (250, 250, 250), "grey": (188, 200, 216), "rain": (206, 220, 236)}, haze=0.2, rough=1.0, glow=0.5)
    cx, cy = 1750.0, -260.0
    for i in range(7):
        a = i / 7 * math.tau
        C.blob(k.bm("grey"), (cx + 150 * math.cos(a), cy + 190 * math.sin(a), 70), rng.uniform(110, 150), subdiv=2, squash=0.45)
    for ox, oy, oz, r in ((0, 0, 190, 190), (-60, 110, 150, 150), (50, -120, 160, 150), (20, 30, 330, 150), (-30, -20, 450, 110), (60, 60, 250, 120)):
        C.blob(k.bm("white"), (cx + ox, cy + oy, oz), r, subdiv=2, squash=0.8)
    # the rain: thin veils that lean with the wind and thin out toward the sea
    for i in range(11):
        y = cy - 190 + i * 38 + rng.uniform(-12, 12)
        w = rng.uniform(5, 12)
        fall = rng.uniform(0.55, 1.0)
        z1 = 40 + (GROUND - 20) * fall
        lean = -330 * fall
        K.quad2(k.bm("rain"), (cx, y - w, 40), (cx, y + w, 40), (cx - 40, y + w * 0.4 + lean, z1), (cx - 40, y - w * 0.4 + lean, z1))
    for obj in k.finish():
        obj.visible_shadow = False


def build(rng):
    build_sea_and_land()
    build_squall(rng)
    k = K.Kit("Below_Coast", COL, haze=0.18)
    build_bay(k, rng)
    build_salt_pans(k, rng)
    build_headland_and_light(k, rng)
    k.finish()
    build_open_sea(rng)
    build_net_rock(rng)
