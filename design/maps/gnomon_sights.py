"""Gnomon Isle's sights: the balloon fair.

Round the compass (east is +X, the sundial's end):
- East, horizon: the sundial island (built in gnomon.py), the one tall landmark.
- East-south-east, rim overlook: the launch field. A floating island below the rim where a balloon is being
  inflated on its side, basket tipped over, fan running, pennant lines in the wind, a striped tent.
- North-west, middle distance and far: two balloons already away, one near and low, one far and high.
- (Removed in the 2026-11-10 rework: the valley island and its village, so nothing but sky lies
  under the arena.)
- North, horizon: a grove island. South-south-west, far horizon: a hazy mesa.

The launch field and the valley sit under the rim line, so from mid-arena the edge reads against sky;
they open up as a fighter nears that side.
"""
import math

import bmesh
from mathutils import Matrix

import common as C
import sights as K
import style as ST

BALLOON = {
    "coral": (214, 84, 58),
    "cream": (240, 226, 190),
    "teal": (44, 138, 132),
    "mustard": (226, 172, 60),
    "basket": (206, 150, 80),
    "trim": (96, 62, 38),
    "rope": (90, 70, 52),
    "burner": (70, 70, 76),
}
PROPS = {
    **BALLOON,
    "canvas": (232, 214, 170),
    "pole": (214, 150, 72),
    "crate": (232, 178, 96),
    "trunk": (110, 78, 60),
    "canopy": (74, 150, 84),
    "wall": (232, 220, 190),
    "water": (120, 190, 214),
    "field1": (196, 188, 96),
    "field2": (128, 170, 84),
    "road": (214, 196, 150),
}
LAUNCH = (300.0, -230.0, -48.0)  # rework: moved east, out of the lobby's view of the arena
VALLEY = (-470.0, 20.0)
CAMS = {
    "Sight_Launch": ((95, -60, 10), (300, -225, -44), 24),
    "Sight_Balloons": ((60, -40, 7), (-300, 280, 95), 32),
}


def stream_y(x):
    return VALLEY[1] + 70 * math.sin((x + 470) / 150.0)


def valley_height(x, y):
    u, v = (x - VALLEY[0]) / 300.0, (y - VALLEY[1]) / 360.0
    d = abs(y - stream_y(x))
    ridge = 150 * K.smooth(50, 260, d)
    bumps = (14 * math.sin(x / 47 + y / 61) + 10 * math.sin(x / 29 - y / 37)) * K.smooth(40, 160, d)
    return -335 + ridge + bumps - 60 * K.smooth(0.75, 1.0, u * u + v * v)


def build_drifting():
    k = K.Kit("Sight_BalloonNear", BALLOON, haze=0.05)
    K.balloon(k, (-250, 235, 78), 26, ["coral", "cream"], 0.4)
    k.finish()
    k = K.Kit("Sight_BalloonFar", BALLOON, haze=0.3)
    K.balloon(k, (-540, 560, 200), 26, ["mustard", "cream"], 1.0)
    k.finish()


def build_launch(rng, tex):
    lx, ly, lz = LAUNCH
    G = ST.Group("Sight_LaunchIsle", tex, haze=0.03, px=512)
    ST.islet(G, LAUNCH, 86, 62, 95, rng, segs=20)
    ST.twin(G, (lx + 62, ly - 26, lz), 20, rng, "leaf")
    ST.tiered(G, (lx + 72, ly - 6, lz), 24, rng, "deep", 3)
    ST.twin(G, (lx - 68, ly + 10, lz), 18, rng, "bloom")
    G.finish()
    k = K.Kit("Sight_Launch", PROPS)
    radius = 24.0
    lift = radius * 0.62 + 1
    place = Matrix.Translation((lx + 10, ly + 4, lz + lift)) @ Matrix.Rotation(0.5, 4, "Z")
    # the envelope on its side, half full: crown lifting off the grass, squashed under its own weight
    m = k.mark()
    K.envelope(k, ["mustard", "cream", "coral"], radius)
    k.move(m, place @ Matrix.Diagonal((1, 1, 0.62, 1)) @ Matrix.Rotation(math.radians(72), 4, "Y"))
    # the basket tipped over toward the mouth, its ropes, and the inflator fan
    basket = (-44.0, 0.0, -lift + 4.6)
    m = k.mark()
    k.box("basket", (0, 0, 0), (8, 8, 6.5))
    k.box("trim", (0, 0, 3.5), (8.8, 8.8, 0.9))
    k.move(m, place @ Matrix.Translation(basket) @ Matrix.Rotation(math.radians(65), 4, "Y"))
    m = k.mark()
    for sy in (-1, 1):
        for sz in (-1, 1):
            k.cyl("rope", (basket[0] + 3.5, sy * 3.6, basket[2] + sz * 2.6 + 1), (-29.7, sy * 4.4, -6.0 + sz * 2.8), 0.16, 4)
    k.box("burner", (-37, -13, -lift + 3), (5, 5, 6))
    k.cyl("burner", (-34.5, -13, -lift + 3.5), (-33.5, -13, -lift + 3.5), 3.2, 10)
    k.move(m, place)
    # pennant lines on poles round the field
    poles = [(-70, -20), (-40, 40), (30, 48), (72, 10)]
    tops = []
    for px, py in poles:
        k.cyl("pole", (lx + px, ly + py, lz), (lx + px, ly + py, lz + 18), 0.6, 6)
        tops.append((lx + px, ly + py, lz + 17.5))
    for a, b in zip(tops, tops[1:]):
        K.pennants(k, a, b, ["coral", "mustard", "cream"], n=12, sag=3.5, size=3.4)
    # the crew's tent, crates, two folded envelopes waiting their turn, a windsock, three trees
    tx, ty = lx - 52, ly - 18
    k.cyl("canvas", (tx, ty, lz), (tx, ty, lz + 7), 9, 10)
    k.cone("coral", (tx, ty, lz + 7), 11, 8, 10)
    for i, (cx, cy, s) in enumerate([(-22, -30, 5), (-15, -33, 4), (-19, -25, 3.4), (-30, -36, 4.4), (-8, -28, 3)]):
        k.box("crate", (lx + cx, ly + cy, lz + s / 2), (s, s, s), rot_z=i * 0.4)
    C.blob(k.bm("mustard"), (lx + 40, ly - 32, lz + 1.6), 6.5, subdiv=1, squash=0.35)
    C.blob(k.bm("coral"), (lx + 52, ly - 24, lz + 1.4), 5.5, subdiv=1, squash=0.35)
    sx, sy = lx + 50, ly + 30
    k.cyl("pole", (sx, sy, lz), (sx, sy, lz + 20), 0.5, 6)
    m = k.mark()
    k.cone("coral", (0, 0, 0), 2.4, 10, 8)
    k.move(m, Matrix.Translation((sx, sy, lz + 19.5)) @ Matrix.Rotation(0.5, 4, "Z") @ Matrix.Rotation(math.radians(80), 4, "Y"))
    k.finish()


def build_valley(rng, tex):
    vx, vy = VALLEY
    stops = [(0.0, (156, 194, 100)), (0.25, (108, 162, 82)), (0.6, (88, 138, 86)), (0.85, (178, 172, 152)), (1.0, (216, 206, 180))]
    mat = K.height_material("Gnomon_Valley", stops, -345, -175, haze=0.12)
    K.terrain(
        "Sight_Land_Valley",
        valley_height,
        K.linspace(vx - 300, vx + 300, 61),
        K.linspace(vy - 360, vy + 360, 73),
        mat,
        keep=lambda x, y: ((x - vx) / 300) ** 2 + ((y - vy) / 360) ** 2 < 1,
    )
    skirt = bmesh.new()
    C.oval_prism(skirt, 296, 356, -398, -660, segments=20, jitter=0.06, rng=rng, taper=0.3)
    for v in skirt.verts:
        v.co.x += vx
        v.co.y += vy
    C.mesh_object("Sight_Land_ValleyRock", skirt, C.flat_material("Gnomon_ValleyRock", K.hazed((0.72, 0.68, 0.60), 0.15), 0.95))

    k = K.Kit("Sight_Village", PROPS, haze=0.12)
    # the stream, a bridge, and the chapel green with the village's own small balloon
    K.strip(k.bm("water"), [(x, stream_y(x)) for x in range(-755, -180, 25)], 10, valley_height, lift=0.8, step=30)
    gx = -470.0
    gy = stream_y(gx) + 42
    gz = valley_height(gx, gy)
    k.box("wall", (gx, gy, gz + 20), (15, 15, 46))
    k.cone("coral", (gx, gy, gz + 43), 12, 16, 4)
    k.box("road", (gx + 30, stream_y(gx + 30), valley_height(gx + 30, stream_y(gx + 30)) + 2), (9, 26, 1.4))
    bx, by = gx - 34, gy + 6
    K.balloon(k, (bx, by, gz + 66), 13, ["coral", "cream"], 0.3)
    k.cyl("rope", (bx, by, gz), (bx, by, gz + 38), 0.25, 4)
    # houses along both banks, roofs in the balloons' colours
    roofs = ["coral", "mustard", "coral"]
    placed, tries = [], 0
    while len(placed) < 15 and tries < 500:
        tries += 1
        x = rng.uniform(-640, -330)
        y = stream_y(x) + rng.choice((-1, 1)) * rng.uniform(26, 72)
        if any(math.hypot(x - a, y - b) < 40 for a, b in placed) or math.hypot(x - gx, y - gy) < 36 or math.hypot(x - bx, y - by) < 24:
            continue
        placed.append((x, y))
        K.house(k, (x, y, valley_height(x, y) - 3), rng.uniform(26, 34), rng.uniform(20, 26), rng.uniform(15, 20) + 3, rng.uniform(-0.4, 0.4), "wall", roofs[len(placed) % 3])
    # a few fields downstream and trees up the slopes
    for i, (fx, side) in enumerate([(-300, 1), (-262, 1), (-300, -1), (-258, -1)]):
        fy = stream_y(fx) + side * 30
        k.box("field1" if i % 2 else "field2", (fx, fy, valley_height(fx, fy) + 0.5), (34, 30, 1.0), rot_z=0.1 * side)
    k.finish()
    G = ST.Group("Sight_ValleyTrees", tex, haze=0.12, flat=True)
    for i in range(14):
        x = rng.uniform(-680, -280)
        y = stream_y(x) + rng.choice((-1, 1)) * rng.uniform(95, 170)
        (ST.tiered if i % 2 else ST.twin)(G, (x, y, valley_height(x, y) - 1), rng.uniform(30, 44), rng)
    G.finish()


def build_horizon(rng, tex):
    centre = (-520.0, -1050.0, 60.0)
    G = ST.Group("Sight_FarMesa", tex, haze=0.5, flat=True)
    ST.islet(G, centre, 190, 150, 300, rng, segs=14, cap=8.0)
    for i, (ox, oy) in enumerate(((-60, 20), (10, -30), (70, 30), (30, 50))):
        (ST.tiered if i % 2 else ST.twin)(G, (centre[0] + ox, centre[1] + oy, centre[2]), rng.uniform(70, 90), rng)
    G.finish()


def build(rng, tex):
    build_drifting()
    build_launch(rng, tex)
    # rework 2026-11-10: the valley island and its village are gone (the user: every map floats in the
    # sky, no ground under the arena). build_valley is kept only for reference.
    build_horizon(rng, tex)
