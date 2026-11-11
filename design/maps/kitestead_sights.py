"""Kitestead's sights: the timber village that built the raft.

Round the compass (east is +X):
- North, middle distance to horizon: a mountain shoulder rising out of the cloud sea. On its terrace, a
  timber village with painted gable ends; a mill with a working waterwheel on a stream that ends in a
  waterfall; a lumber yard with log stacks, plank piles and a hoist; an ox cart taking freshly painted
  beams to the ropeway that carries them up to the raft (a pallet hangs on the cable, half way).
- East, horizon: a kite train, five kites on one line climbing from a rock spire.
- West, horizon: a kite-maker's loft on a rock pinnacle, flying three test kites.
- South: open sky, the cloud sea and the raft's own kites, kept sparse.

The waterwheel is its own pair of meshes (Sight_Waterwheel_*), centred on the axle, so it can be spun
in Roblox.
"""
import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector

import common as C
import sights as K

PAINT = {"red": (178, 52, 36), "mustard": (214, 160, 44), "green": (76, 140, 58)}
COL = {
    **PAINT,
    "timber": (150, 102, 62),
    "plank": (206, 166, 112),
    "dark": (92, 64, 44),
    "roof": (118, 92, 76),
    "straw": (198, 170, 104),
    "water": (140, 196, 222),
    "foam": (238, 244, 248),
    "trunk": (104, 74, 54),
    "canopy": (70, 138, 80),
    "canopy2": (98, 158, 86),
    "road": (196, 176, 136),
    "ox": (224, 208, 184),
    "rope": (84, 64, 48),
    "cream": (250, 238, 205),
    "rock": (150, 140, 128),
}
KEYS = ["red", "mustard", "green"]
CAMS = {
    "Sight_Village": ((0, 93, 10), (0, 470, -150), 22),
    "Sight_Yard": ((70, 86, 10), (125, 500, -165), 55),
    "Sight_Mill": ((-60, 88, 10), (-150, 480, -160), 55),
    "Sight_KiteTrain": ((-40, 20, 7), (760, -90, 130), 40),
    "Sight_KiteLoft": ((40, -10, 7), (-560, 60, 60), 55),
}
YS = [300, 420, 560, 760, 900, 1150]
HS = [-400, -175, -120, 40, 120, 10]
ROPEWAY = (0.0, 430.0)
RAFT_ANCHOR = (0.0, 66.0, -12.0)


def mountain_height(x, y):
    base = float(np.interp(y, YS, HS))
    f = max(1 - (x / 560.0) ** 2, 0.0) ** 0.8
    bumps = (18 * math.sin(x / 71 + y / 53) + 12 * math.sin(x / 37 - y / 91)) * K.smooth(560, 700, y)
    return -400 + (base + 400) * f + bumps * f


G = mountain_height


def capped_beam(k, centre, length, thick, key, rot=0.0):
    """A freshly painted beam: the whole length in one of the raft's three colours, so a load of them
    reads as red, mustard and green stripes from the arena."""
    k.box(key, centre, (length, thick, thick), rot)


def build_mountain():
    stops = [(0.0, (122, 114, 106)), (0.2, (170, 152, 130)), (0.40, (150, 140, 126)), (0.44, (126, 166, 88)), (0.55, (112, 158, 84)), (0.76, (88, 134, 86)), (0.9, (170, 160, 140)), (1.0, (208, 198, 174))]
    mat = K.height_material("Kitestead_Mountain", stops, -400, 130, haze=0.1)
    K.terrain("Sight_Land_Mountain", G, K.linspace(-560, 560, 67), K.linspace(300, 1150, 51), mat)


def build_village(rng):
    k = K.Kit("Sight_Village", COL, haze=0.08)
    # the stream down the mountain, through the mill race, and over the terrace's edge
    K.strip(k.bm("water"), [(-130, 760), (-150, 640), (-140, 560), (-150, 500), (-150, 424)], 10, G, lift=0.9, step=22)
    K.strip(k.bm("foam"), [(-150, 426), (-150, 300)], 12, G, lift=1.4, step=12)
    # the mill and its axle (the wheel itself is separate, below)
    mz = G(-150, 492)
    K.house(k, (-186, 494, G(-186, 494) - 4), 34, 26, 26, 0.0, "timber", "roof", gable_key="red")
    k.cyl("dark", (-170, 492, mz + 17), (-142, 492, mz + 17), 1.3, 8)
    for sx in (-143.5,):
        k.box("dark", (sx, 492, mz + 8), (2.4, 4, 18))
    # houses on the terrace, painted gable ends
    spots = [(-90, 512), (-30, 540), (48, 522), (215, 478), (250, 530), (-250, 486), (-235, 540), (-110, 560), (10, 575)]
    for i, (x, y) in enumerate(spots):
        K.house(k, (x, y, G(x, y) - 5), rng.uniform(26, 34), rng.uniform(20, 26), rng.uniform(14, 19) + 5, math.pi / 2 + rng.uniform(-0.25, 0.25), "timber", "roof" if i % 2 else "straw", gable_key=KEYS[i % 3])
    # the lumber yard: log stacks with pale cut ends, plank piles, a saw shed, an A-frame hoist
    for sx, sy in ((120, 490), (165, 525)):
        z0 = G(sx, sy)
        for row, n in enumerate((4, 3, 2)):
            for j in range(n):
                y = sy + (j - (n - 1) / 2) * 8.6
                z = z0 + 4.2 + row * 7.4
                k.cyl("timber", (sx - 22, y, z), (sx + 22, y, z), 4.2, 8)
                for s in (-1, 1):
                    k.cyl("plank", (sx + s * 22, y, z), (sx + s * 22.4, y, z), 3.6, 8)
    for px, py, ph, rot in ((176, 478, 5, 0.1), (184, 492, 3, -0.15), (150, 462, 4, 0.5)):
        k.box("plank", (px, py, G(px, py) + ph / 2), (30, 10, ph), rot)
    shed = (95.0, 532.0)
    sz = G(*shed)
    for ox in (-12, 12):
        for oy in (-9, 9):
            k.cyl("dark", (shed[0] + ox, shed[1] + oy, sz - 3), (shed[0] + ox, shed[1] + oy, sz + 14), 1.0, 6)
    K.gable(k.bm("roof"), (shed[0], shed[1], sz + 14), 30, 24, 8)
    k.cyl("timber", (shed[0] - 10, shed[1], sz + 5), (shed[0] + 14, shed[1], sz + 5), 3.4, 8)
    hz = G(140, 470)
    k.cyl("dark", (128, 470, hz - 2), (140, 470, hz + 30), 1.0, 6)
    k.cyl("dark", (152, 470, hz - 2), (140, 470, hz + 30), 1.0, 6)
    k.cyl("rope", (140, 470, hz + 30), (140, 470, hz + 13), 0.3, 4)
    k.cyl("timber", (129, 470, hz + 10), (151, 470, hz + 10), 3.2, 8)
    # finished beams waiting, ends freshly painted
    for i in range(5):
        y = 548 + i * 3.8
        capped_beam(k, (150, y, G(150, y) + 2.4), 44, 3.6, KEYS[i % 3])
    # roads: yard -> cart -> ropeway, and across to the mill
    K.strip(k.bm("road"), [(150, 468), (90, 476), (30, 474), (2, 446)], 12, G, lift=0.5)
    K.strip(k.bm("road"), [(2, 446), (-70, 458), (-140, 474)], 9, G, lift=0.5)
    # the ox cart, loaded, heading for the ropeway
    m = k.mark()
    k.box("timber", (0, 0, 6.5), (22, 11, 1.6))
    for s in (-1, 1):
        k.cyl("dark", (-2, s * 6.5, 5), (-2, s * 7.8, 5), 5, 10)
        k.cyl("dark", (11, s * 3, 6.5), (23, s * 3, 6.2), 0.5, 5)
        k.box("timber", (0, s * 5.2, 8), (22, 0.6, 1.6))
    for i in range(4):
        capped_beam(k, (0, (i - 1.5) * 2.5, 8.6), 27, 2.3, KEYS[i % 3])
    for i in range(3):
        capped_beam(k, (0, (i - 1) * 2.5, 10.9), 27, 2.3, KEYS[(i + 1) % 3])
    k.box("ox", (28, 0, 7.2), (11, 6, 6.5))
    k.box("ox", (35, 0, 9.5), (4.4, 4.2, 4.2))
    for ox in (24, 32):
        for oy in (-2, 2):
            k.box("ox", (ox, oy, 2.2), (1.8, 1.8, 4.4))
    for s in (-1, 1):
        k.box("dark", (36.5, s * 2.6, 12.2), (0.8, 2.2, 0.8))
    k.move(m, Matrix.Translation((30, 474, G(30, 474))) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(1.5, 4))
    # the ropeway: a tower at the terrace edge, one cable up to the raft, a pallet of beams on its way
    rx, ry = ROPEWAY
    rz = G(rx, ry)
    for ox in (-7, 7):
        for oy in (-6, 6):
            k.cyl("dark", (rx + ox, ry + oy, rz - 8), (rx + ox, ry + oy, rz + 32), 1.1, 6)
    k.box("plank", (rx, ry, rz + 20), (17, 15, 1.4))
    K.gable(k.bm("roof"), (rx, ry, rz + 32), 20, 18, 7, math.pi / 2)
    K.gable(k.bm("mustard"), (rx, ry - 10.2, rz + 32), 0.6, 15, 6, 0.0)
    a, b = Vector((rx, ry - 2, rz + 30)), Vector(RAFT_ANCHOR)
    k.cyl("rope", a, b, 0.45, 5)
    p = a.lerp(b, 0.45)
    for ox in (-6, 6):
        k.cyl("rope", (p.x + ox, p.y, p.z), (p.x + ox, p.y, p.z - 9), 0.2, 4)
    k.box("timber", (p.x, p.y, p.z - 9.4), (16, 8, 0.8))
    for i in range(3):
        capped_beam(k, (p.x, p.y + (i - 1) * 2.5, p.z - 7.8), 18, 2.3, KEYS[i])
    # trees up the slope behind the village, layered canopies in two greens
    for i in range(18):
        x, y = rng.uniform(-330, 330), rng.uniform(600, 770)
        K.tree(k, (x, y, G(x, y) - 1), rng.uniform(22, 34), rng.uniform(13, 18), rng, canopy="canopy" if i % 2 else "canopy2")
    for x, y in ((-285, 452), (290, 455), (75, 590)):
        K.tree(k, (x, y, G(x, y) - 1), rng.uniform(20, 26), rng.uniform(12, 15), rng)
    k.finish()

    # the waterwheel: built flat, then stood up over the mill race
    w = K.Kit("Sight_Waterwheel", COL, haze=0.08)
    m = w.mark()
    radius = 20.0
    for zo in (-3, 3):
        for i in range(12):
            a = (i + 0.5) / 12 * math.tau
            w.box("timber", (radius * math.cos(a), radius * math.sin(a), zo), (2.2, 2 * radius * math.sin(math.pi / 12) + 0.6, 1.6), a)
    for i in range(12):
        a = i / 12 * math.tau
        w.box("plank", ((radius + 1.5) * math.cos(a), (radius + 1.5) * math.sin(a), 0), (5, 1.2, 8), a)
    for i in range(6):
        a = i / 6 * math.tau
        w.cyl("timber", (0, 0, 0), (radius * math.cos(a), radius * math.sin(a), 0), 0.9, 6)
    w.cyl("dark", (0, 0, -4.6), (0, 0, 4.6), 2.6, 10)
    w.cyl("red", (0, 0, 4.6), (0, 0, 5.2), 2.0, 10)
    w.cyl("red", (0, 0, -5.2), (0, 0, -4.6), 2.0, 10)
    w.move(m, Matrix.Translation((-150, 492, mz + 17)) @ Matrix.Rotation(math.radians(90), 4, "Y"))
    w.finish()


def build_kite_train(rng, diamond):
    k = K.Kit("Sight_KiteTrain", COL, haze=0.14)
    K.ring_stack(k.bm("rock"), (880, -140), [(84, -420), (60, -250), (34, -140), (22, -70)], sides=8, rng=rng, jitter=0.12)
    base, top = Vector((880, -140, -70)), Vector((690, -50, 240))
    prev = base
    for i in range(5):
        t = (i + 1) / 5
        pos = base.lerp(top, t)
        pos.z = base.z + (top.z - base.z) * t ** 0.8
        size = 46 + 13 * i
        ang = math.atan2(pos.y, pos.x)
        facing = (-math.cos(ang), -math.sin(ang))
        c1 = KEYS[i % 3]
        for part in range(4):
            diamond(k.bm(c1 if part % 2 == 0 else "cream"), tuple(pos), facing, size, size * 0.72, 0.6, part)
        k.cyl("rope", prev, pos, 0.5, 5)
        prev = pos
    k.finish()


def build_kite_loft(rng, diamond):
    """West, on the horizon: a kite-maker's loft on a pinnacle, three test kites up on short lines."""
    k = K.Kit("Sight_KiteLoft", {**COL, "rock": (196, 182, 156)}, haze=0.12)
    f = K.Kit("Sight_KiteLoftKites", COL, haze=0.05, glow=0.55)
    cx, cy, top = -560.0, 60.0, 18.0
    K.ring_stack(k.bm("rock"), (cx, cy), [(76, -420), (48, -230), (26, -110), (13, -30), (17, top)], sides=9, rng=rng, jitter=0.14)
    K.house(k, (cx, cy, top), 22, 16, 12, math.pi / 2 + 0.2, "timber", "straw", gable_key="mustard")
    roof = Vector((cx, cy, top + 21))
    ang = math.atan2(cy, cx)
    facing = (-math.cos(ang), -math.sin(ang))
    for i, (ox, oy, oz, size) in enumerate(((-30, -80, 70, 34), (-70, 30, 112, 42), (-20, 92, 50, 28))):
        pos = (cx + ox, cy + oy, top + oz)
        for part in range(4):
            diamond(f.bm(KEYS[i] if part % 2 == 0 else "cream"), pos, facing, size, size * 0.72, 0.5, part)
        k.cyl("rope", roof, (pos[0], pos[1], pos[2] - size * 0.38), 0.3, 4)
    k.cyl("dark", (cx + 12, cy - 12, top), (cx + 12, cy - 12, top + 20), 0.6, 5)
    K.pennants(k, roof, (cx + 12, cy - 12, top + 19.5), KEYS, n=8, sag=2.0, size=3.2)
    k.finish()
    f.finish()


def build(rng, diamond):
    build_mountain()
    build_village(rng)
    build_kite_train(rng, diamond)
    build_kite_loft(rng, diamond)
