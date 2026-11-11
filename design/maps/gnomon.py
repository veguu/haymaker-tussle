"""Gnomon Isle: a meadow of real grass on a floating island of chunky stone ledges, among floating
islets, rocks and cartoon clouds, one islet a giant sundial whose blade rises over the skyline.

Run: blender -b --factory-startup -P gnomon.py -- <out folder> [--no-render] [--fast] [--cams=A,B]

Rework 2026-11-10 (user brief: floating world, 3D grass, physical detail, thin outlines, new clouds),
on top of pass 4's palette (style.py) and detail.py's builders:
- Sky all round: the valley island and its village are gone; clouds and rock fragments hang under and
  round the island.
- Grass: modelled tufts (detail.grass), short in the centre and dense round the perimeter, over a
  ground of broad green patches with a dab under each tuft. Modelled flowers in the four accent beds.
- The edge: a thick rounded turf lip hanging over the stone in lobes; the walkable edge is unchanged.
- The cliff: layers with thin blue-grey shelves stepping out, boulders and chips on the shelves, beams,
  a plank deck with seams, cut ends and a trim at five places, and roots under the lip.
- No outlines (dropped 2026-11-10): form reads from modelled depth, colour steps, lighting and contact
  shadow. detail.outline_all is kept but unused.
- The lobby side (Blender -Y) is kept open: detail.LOBBY_VIEW, checked at build ("CORRIDOR" lines).
Accents: coral and gold only.

Readability rules kept here: the stone and timber never reach outside the oval (the lip's rounded roll
reaches under a stud past it and never collides), the rim is a flush lighter band with no grass on it,
nothing rises above the rim within 100 studs of it, and the garden islets leave open sky between them.
"""
import math
import os
import random
import sys
import types

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import common as C  # noqa: E402
import paint as P  # noqa: E402
import surfaces as S  # noqa: E402
import style as ST  # noqa: E402
import gnomon_sights as GS  # noqa: E402
import detail as D  # noqa: E402
import sights as K  # noqa: E402

CAP = 4.0  # the grass cap's thickness: the rim's outer face and the surface tiles' depth
TEX = os.path.join(HERE, "out", "gnomon", "textures")
T = ST.PAL


# --- the meadow ----------------------------------------------------------------------------------
def _cells(X, Y, size, seed):
    """The four jittered cells nearest each point: yields (cx, cy, hashes) per neighbour."""
    gx, gy = X / size - 0.5, Y / size - 0.5
    i0, j0 = np.floor(gx), np.floor(gy)
    for di in (0, 1):
        for dj in (0, 1):
            ci, cj = i0 + di, j0 + dj
            h = [P.hash01(seed + k, ci, cj) for k in range(8)]
            cx = (ci + 0.5 + (h[0] - 0.5) * 0.8) * size
            cy = (cj + 0.5 + (h[1] - 0.5) * 0.8) * size
            yield cx, cy, h


CLEAR_CENTRE = 0.3  # share of the oval's radius with almost no accents, so feet and landings read
# accent flower beds: (centre, radius, flowers, seed). The east one lies under the sundial.
BEDS = [((98.0, 9.0), 8.0, 11, 5), ((-97.0, -10.0), 6.5, 7, 6), ((6.0, 80.0), 5.5, 5, 7), ((-12.0, -80.0), 5.5, 5, 8)]


def _radius(x, y):
    return np.sqrt((x / (C.A - C.RIM)) ** 2 + (y / (C.B - C.RIM)) ** 2)


def meadow_painter(X, Y):
    """The ground under the 3D grass (rework 2026-11-10: the painted blades, daisies and flowers are
    gone; real tufts and flowers stand on it). Broad warmer and cooler patches of fresh green, a darker
    dab under every tuft so the tufts sit in the turf, and a deeper patch under each flower bed. Flat
    and matte, so a falling player reads the whole oval as one clean landing shape."""
    col = ST.turf_field(X, Y)
    col = D.tuft_dabs(X, Y, col, T["blade_dark"])
    for (px, py), rad, n, seed in BEDS:
        if px < X.min() - rad - 3 or px > X.max() + rad + 3 or py < Y.min() - rad - 3 or py > Y.max() + rad + 3:
            continue
        d = np.hypot(X - px, (Y - py) * 1.2) + 1.6 * (P.fbm2(X * 0.3, Y * 0.3, 60 + seed, 2) - 0.5)
        col = P.mix(col, T["drape"], 0.6 * (1 - P.smoothstep(rad * 0.86, rad * 0.94, d)))
    return col, np.zeros(X.shape), np.full(X.shape, 0.95)


def build_meadow_flowers(rng):
    """Small modelled flowers: the four accent beds of coral and gold, and a few loose clusters in the
    outer grass. Non-colliding, knee-high at most."""
    G = types.SimpleNamespace(kit=K.Kit("Flowers_Meadow", ST.FLAT))
    for (px, py), rad, n, seed in BEDS:
        ST.flowers(G, (px, py, -0.2), n + 4, rad * 0.8, random.Random(seed), size=0.85)
    placed = 0
    while placed < 22:
        t = rng.uniform(0, math.tau)
        s = rng.uniform(0.8, 0.95)
        x, y = (C.A - C.RIM) * s * math.cos(t), (C.B - C.RIM) * s * math.sin(t)
        if any(math.hypot(x - bx, y - by) < r + 6 for (bx, by), r, _, _ in BEDS):
            continue
        keys = ("cream", "gold", "cream") if placed % 3 else ("coral", "gold", "coral")
        ST.flowers(G, (x, y, -0.2), 3, 1.4, rng, keys=keys, size=0.6)
        placed += 1
    G.kit.finish()


# --- the rim: the grass cap's lip and skirt --------------------------------------------------------
def rim_painter(S_, Pp, FACE, X, Y, Z, info):
    """Top: the same turf as the meadow, then a lighter lip with a scalloped inner edge and a bright
    line on the very edge. Outer face: a deep green skirt hanging in rounded lobes, pale stone showing
    under it. Matte."""
    zero = S_ * 0
    col = ST.turf_field(X, Y)
    top = FACE <= 1
    scallop = np.abs(np.sin(S_ * 0.42 + 1.7 * P.fbm2(S_ * 0.06, zero, 211, 2)))
    col = np.where((top & (Pp > 0.6 + 0.9 * scallop))[..., None], T["lip"], col)
    col = np.where(((FACE == 1) | (top & (Pp > info["p1"] - 0.45)))[..., None], T["lip_hi"], col)
    depth = -Z
    wander = 2.0 * P.fbm2(S_ * 0.05, zero + 3, 212, 2)
    hang = 2.75 + 0.75 * np.sin(S_ * 0.34 + wander) + 0.35 * np.sin(S_ * 0.93 + 1.3 * wander)
    skirt = P.mix(P.fill(S_.shape, T["drape"]), T["drape_dark"], P.smoothstep(0.3, 1.0, depth / hang))
    side = np.where((depth < hang)[..., None], skirt, T["cream"] * 0.86)
    col = np.where((FACE == 2)[..., None], side, col)
    col = np.where((FACE == 3)[..., None], T["cream"] * 0.55 * ST.UNDER, col)
    return col, np.zeros(S_.shape), np.full(S_.shape, 0.95)


# --- the cliff -----------------------------------------------------------------------------------
# kind, thickness, blocks round the oval, the layer's size, how far its blocks may sit in
BANDS = [  # rework: thin blue-grey shelves step OUT under thicker layers, so the cliff reads as ledges
    ("cream", 12.0, 17, 0.985, (0.93, 0.975)),
    ("bluegrey", 3.5, 23, 1.0, (0.975, 0.995)),
    ("sand", 11.0, 13, 0.92, (0.92, 0.98)),
    ("bluegrey", 3.5, 17, 0.95, (0.955, 0.99)),
    ("cream", 11.0, 11, 0.82, (0.92, 1.0)),
    ("sand", 4.0, 13, 0.85, (0.95, 1.0)),
    ("bluegrey", 9.0, 9, 0.66, (0.9, 1.0)),
    ("cream", 8.0, 7, 0.48, (0.88, 1.0)),
]
SHELVES = (1, 3, 5)  # the layers that step out: boulders and chips sit on them
TIMBER_AT = [math.radians(a) for a in (352, 62, 130, 200, 268)]


def build_strata(rng):
    bands = {"cream": bmesh.new(), "sand": bmesh.new(), "bluegrey": bmesh.new()}
    z = -CAP
    for k, (kind, thick, blocks, scale, inset) in enumerate(BANDS):
        ST.chunk_band(
            bands[kind], (0, 0), C.A * scale, C.B * scale, z, thick, blocks, rng, inset=inset, lean=0.05,
            smax=0.992, recess_at=TIMBER_AT if k == 0 else (), recess=0.93 if k == 0 else None,
        )
        if k in SHELVES:  # loose boulders and fallen chips on the shelf's top
            for _ in range(12):
                t = rng.uniform(0, math.tau)
                r = rng.uniform(0.7, 2.2)
                sc = scale * rng.uniform(0.95, 0.975)
                C.blob(bands[kind], (C.A * sc * math.cos(t), C.B * sc * math.sin(t), z + r * 0.25), r, subdiv=1, squash=0.6)
        z -= thick * 0.97
    for fx, fy, r, h in ((-18, 6, 24, 55), (20, -10, 18, 42), (2, 22, 13, 30)):
        C.cone(bands["bluegrey"], (fx, fy, z + 2), r, -h, sides=5, rng=rng, jitter=0.15, tip_offset=(rng.uniform(-6, 6), rng.uniform(-6, 6)))
    holder = C.flat_material("Gnomon_StoneHolder", (0.9, 0.85, 0.7))
    return {kind: C.mesh_object(f"Strata_{kind.capitalize()}", bm, holder) for kind, bm in bands.items()}


def build_cliff_timber(rng, tex):
    """Shoring set into the cliff at five places, under the cap and inside the oval's outline: two beam
    ends, a ledger laid across them, and a brace down to the next shelf."""
    bm, reg = bmesh.new(), []
    for th in TIMBER_AT:
        ct, st = math.cos(th), math.sin(th)
        tx, ty = -C.A * st, C.B * ct
        ln = math.hypot(tx, ty)
        tx, ty = tx / ln, ty / ln

        def at(scale, z, along=0.0):
            return Vector((C.A * scale * ct + tx * along, C.B * scale * st + ty * along, z))

        for along in (-4.5, 4.5):
            ST.tube(bm, reg, [at(0.84, -8.8, along), at(0.975, -8.3, along)], [1.5, 1.5], 8, rng)
        ST.tube(bm, reg, [at(0.962, -6.2, -8.5), at(0.962, -6.0, 8.5)], [1.35, 1.35], 8, rng)
        ST.tube(bm, reg, [at(0.90, -19.5, 0.0), at(0.968, -9.4, 0.0)], [1.25, 1.25], 8, rng)
        # rework: a small plank deck on the first shelf's exposed top (the top layer is recessed here),
        # on two bearers, with seams, cut ends and a raised trim board
        out = Vector((ct / C.A, st / C.B, 0)).normalized()
        along = Vector((tx, ty, 0))
        shelf_top = -CAP - BANDS[0][1] * 0.97
        for r_ in (0.945, 0.966):
            ST.tube(bm, reg, [at(r_, shelf_top + 0.35, -4.6), at(r_, shelf_top + 0.35, 4.6)], [0.4, 0.4], 6, rng)
        D.plank_shelf(bm, reg, at(0.955, 0.0), out, along, rng, n=5, length=4.6, width=1.4, z=shelf_top + 1.0)
    D.roots(bm, reg, rng, count=16, tube=ST.tube)
    obj = C.mesh_object("Cliff_Timber", bm, C.flat_material("Gnomon_TimberHolder", (0.7, 0.45, 0.2)))
    S.paint_scenery([obj], ST.wood_painter(reg), tex, px=ST._px(1024), roughness=0.9, **ST.AO)
    return obj


# --- backdrop ------------------------------------------------------------------------------------
def build_garden(rng, tex):
    """Four islets close enough to read from the fight, each with its own small cast: the grove
    (north-east), the hollow log (south-west), the tall pair (west), the pennant frame (north). They
    start 100 studs or more beyond the rim and float level with it or a little higher, so from the
    fight each reads as its own island with rock under it, never as part of the landable edge."""
    G = ST.Group("Garden", tex, haze=0.03)
    # north-east: the grove beside the sundial's bearing
    z = 8.0
    ST.islet(G, (232, 108, z), 34, 27, 46, rng)
    ST.tiered(G, (240, 114, z), 46, rng, "deep", 4)
    ST.twin(G, (220, 100, z), 30, rng, "leaf")
    ST.umbrella(G, (246, 94, z), 19, rng, "bloom")
    ST.bush(G, (212, 116, z), 5.5, rng, "lime")
    ST.flowers(G, (228, 90, z), 7, 5, rng)
    # west-south-west: the hollow log (rework: moved out of the lobby's view of the arena)
    ox, oy = -170.0, 46.0
    z = 0.0
    ST.islet(G, (-130 + ox, -196 + oy, z), 48, 31, 52, rng, segs=18)
    a, b = Vector((-160 + ox, -212 + oy, z + 9.2)), Vector((-102 + ox, -180 + oy, z + 9.6))
    centres = ST.hollow_log(G.bm["Wood"], G.woods, a, b, 7.6, rng)
    side = Vector((-(b - a).y, (b - a).x, 0)).normalized()
    for c, s in ((centres[0].lerp(centres[1], 0.5), 1), (centres[1].lerp(centres[2], 0.3), -1), (centres[2].lerp(centres[3], 0.2), 1), (centres[2].lerp(centres[3], 0.8), -1)):
        ST.tube(G.bm["Wood"], G.woods, [c + side * (s * 3.5) - Vector((0, 0, 5.5)), c + side * (s * 8.5) - Vector((0, 0, 10.5))], [1.3, 1.0], 6, rng)
    for t, hgt in ((0.18, 9.0), (0.46, 6.5), (0.8, 8.0)):
        ST.sprout(G, a.lerp(b, t) + Vector((0, 0, 7.2)), hgt, rng)
    ST.twin(G, (-118 + ox, -206 + oy, z), 33, rng, "leaf", "lime")
    ST.bush(G, (-150 + ox, -190 + oy, z), 5.0, rng, "deep")
    ST.flowers(G, (-134 + ox, -180 + oy, z), 6, 4.5, rng)
    # west: the tall pair and a small coral tree
    z = 11.0
    ST.islet(G, (-250, 46, z), 30, 26, 44, rng)
    ST.tiered(G, (-256, 52, z), 48, rng, "leaf", 4)
    ST.tiered(G, (-244, 34, z), 33, rng, "deep", 3)
    ST.twin(G, (-240, 58, z), 21, rng, "bloom")
    ST.bush(G, (-262, 36, z), 4.5, rng, "lime")
    # north: the pennant frame
    z = 6.0
    ST.islet(G, (-20, 222, z), 38, 26, 48, rng)
    ST.umbrella(G, (-34, 226, z), 30, rng, "lime")
    ST.twin(G, (-4, 230, z), 34, rng, "deep", "leaf")
    tops = []
    for px in (-30, 2):
        foot = Vector((px, 208, z))
        ST.tube(G.bm["Wood"], G.woods, [foot - Vector((0, 0, 1)), foot + Vector((0.6, 0, 19))], [1.0, 0.7], 6, rng)
        tops.append(foot + Vector((0.6, 0, 18.5)))
    ST.K.pennants(G.kit, tops[0], tops[1], ["coral", "gold", "cream"], n=9, sag=3.0, size=3.6)
    ST.flowers(G, (-14, 206, z), 6, 5, rng)
    G.finish()


def build_islands(rng, tex):
    """Two far islands, hazed, in the same build: a small one to the south-west and a grove island on
    the northern horizon."""
    G = ST.Group("Islands", tex, haze=0.3, px=512)
    ST.islet(G, (-280, -430, 0), 40, 34, 60, rng)
    ST.twin(G, (-274, -424, 0), 30, rng, "leaf")
    ST.tiered(G, (-290, -438, 0), 38, rng, "deep", 3)
    ST.islet(G, (-40, 480, 24), 62, 50, 96, rng, segs=18)
    ST.tiered(G, (-52, 486, 24), 50, rng, "deep", 4)
    ST.tiered(G, (-30, 470, 24), 36, rng, "leaf", 3)
    ST.twin(G, (-14, 492, 24), 34, rng, "leaf", "lime")
    ST.umbrella(G, (-70, 468, 24), 24, rng, "bloom")
    G.finish()


def build_sundial(rng, tex):
    """The landmark: a big island on the long axis carrying a sundial, its blade rising far above the
    skyline. Out at 380 studs so it marks one end of the arena from anywhere on it. Its trim carries
    the arena's accents: a coral band round the dial and on the blade, coral hour marks, a gold edge,
    and beds of the same flowers at its foot (echoed by the bed on the meadow below it)."""
    cx, cy, cz = 380.0, 30.0, -25.0
    G = ST.Group("Sundial", tex, haze=0.1)
    ST.islet(G, (cx, cy, cz), 70, 62, 120, rng, segs=20, cap=4.5)
    stone = G.bm["Stone"]
    n0 = len(stone.verts)
    C.oval_prism(stone, 50, 50, cz + 2.6, cz + 1.2, segments=28)
    for v in list(stone.verts)[n0:]:
        v.co.x += cx
        v.co.y += cy
    band = G.kit.bm("coral")
    n0 = len(band.verts)
    C.oval_prism(band, 51.5, 51.5, cz + 1.2, cz - 0.4, segments=28)
    for v in list(band.verts)[n0:]:
        v.co.x += cx
        v.co.y += cy
    for hr in range(12):
        t = hr / 12 * math.tau
        G.kit.box("coral", (cx + 42 * math.cos(t), cy + 42 * math.sin(t), cz + 2.8), (9 if hr % 3 == 0 else 5.5, 2.0, 0.7), rot_z=t)
    half = 3.5
    pts = [(-half, -36, 0), (-half, 34, 0), (-half, -36, 170), (half, -36, 0), (half, 34, 0), (half, -36, 170)]
    v = [stone.verts.new((cx + p[0], cy + p[1], cz + 2.6 + p[2])) for p in pts]
    blade = [stone.faces.new([v[i] for i in face]) for face in ((0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0))]
    # rework: these were wound inward (Roblox showed the far face from inside); a closed prism, so
    # recalculating makes them face out, which the outline behind it needs
    bmesh.ops.recalc_face_normals(stone, faces=blade)
    G.kit.cyl("gold", (cx - half - 0.6, cy + 34, cz + 2.9), (cx - half - 0.6, cy - 36, cz + 2.6 + 170), 2.2, 6)
    # painted bands on the blade: each a box wrapping it between the upright edge and the slope
    for zb, thick, key in ((30.0, 9.0, "coral"), (42.0, 3.0, "gold"), (112.0, 5.0, "coral")):
        y1 = -36 + 70 * (1 - zb / 170.0)
        G.kit.box(key, (cx, cy + (-36 + y1) / 2, cz + 2.6 + zb), (2 * half + 1.0, y1 + 36 + 0.5, thick))
    ST.umbrella(G, (cx - 30, cy + 44, cz), 26, rng, "bloom")
    ST.twin(G, (cx + 24, cy + 50, cz), 30, rng, "leaf")
    ST.tiered(G, (cx + 40, cy - 40, cz), 40, rng, "deep", 4)
    ST.bush(G, (cx - 44, cy - 34, cz), 7, rng, "lime")
    for ang in (2.6, 3.4, 4.1):
        ST.flowers(G, (cx + 58 * math.cos(ang), cy + 55 * math.sin(ang), cz), 7, 6, rng, size=2.6)
    G.finish()


# rework 2026-11-10: rounded cartoon clouds (the user's image 3) at three depths: under the island (so
# it hangs in open sky), round the sides and behind, and far out. (x, y, z, length, kind, heading).
# Nothing rises into the lobby's view of the arena; one long cloud passes well under it.
CLOUDS = [
    (-40, 60, -175, 280, "stretched", 15), (170, -40, -215, 150, "compact", -20),
    (-230, -150, -250, 300, "stretched", 30), (230, 220, -140, 160, "compact", 10),
    (40, 330, -230, 300, "stretched", -10), (-20, -250, -205, 220, "stretched", 5),
    (-340, 160, -30, 120, "compact", 0), (320, 280, 40, 230, "stretched", 160),
    (-140, 430, 70, 140, "compact", 0), (540, -140, -10, 260, "stretched", 190),
    (-480, -60, 20, 200, "stretched", -15), (120, 950, 140, 520, "stretched", 175),
    (-760, 520, 90, 460, "stretched", 20), (860, 380, 170, 320, "compact", 0),
    (-620, -420, 50, 280, "compact", 0), (650, -500, 110, 380, "stretched", 200),
]
# floating rock fragments (x, y, z, radius): a few just under the island, the rest round the sides
# and behind at mixed heights
FRAGMENTS = [
    (60, 30, -118, 7), (-50, -20, -132, 5), (20, -45, -152, 4), (170, 120, -20, 9), (-185, -40, -35, 6),
    (150, 175, 25, 5), (-170, 170, -5, 8), (300, 120, -60, 10), (-330, -20, 30, 7), (90, 330, -40, 11),
    (-90, 330, 40, 6), (260, -60, 15, 5), (-260, -260, -20, 9), (460, 160, 60, 12), (-420, 260, -30, 10),
    (200, -130, -60, 6),
]


def build_clouds(rng):
    D.cartoon_clouds(CLOUDS, rng)


def build_fragments(rng, tex):
    G = ST.Group("Fragments", tex, haze=0.04, px=512)
    D.fragments(G, FRAGMENTS, rng, ST.islet)
    G.finish()


SUN = (200, 40)  # heading (0 = east), elevation, in degrees
BACKDROP_SEED = 111


def build_backdrop(rng, tex=TEX):
    """Everything beyond the cliff: the garden islets, far islands, the sundial, the balloon fair's
    sights. (Clouds come from the runtime environment, not the map.)"""
    build_garden(rng, tex)
    build_islands(rng, tex)
    build_sundial(rng, tex)
    GS.build(rng, tex)
    build_fragments(rng, tex)
    # clouds are no longer baked into the map: the game's environment system (src/shared/EnvironmentKit) builds
    # and drifts them from the map's preset in Config/MapEnvironments. build_clouds is kept for reference.


MEET = math.radians(200)  # the sunlit timber spot, for the close-up where grass, stone and wood meet


def cameras():
    cams = C.standard_cameras(gameplay_target=(60, 10, -4), edge_target=(380, 30, 20))
    for name, (loc, target, lens) in GS.CAMS.items():
        cams[name] = C.camera(name, loc, target, lens)
    ct, st = math.cos(MEET), math.sin(MEET)
    nx, ny = ct / C.A, st / C.B
    ln = math.hypot(nx, ny)
    nx, ny = nx / ln, ny / ln
    px, py = C.A * ct, C.B * st
    cams["Meet"] = C.camera("Meet", (px + nx * 17 + ny * 10, py + ny * 17 - nx * 10, 4.5), (px * 0.972, py * 0.972, -6.5), 30)
    # rework: the lobby's view (spawn and both ends of its viewing edge, avatar camera height; the lobby
    # floor is a stud above the arena's) and a wide view of the underside and the sky below
    cams["LobbySpawn"] = C.camera("LobbySpawn", (0, -300, 12), (0, 0, -2), 18)
    cams["LobbyEdgeW"] = C.camera("LobbyEdgeW", (-86, -176, 9), (10, 0, -2), 18)
    cams["LobbyEdgeE"] = C.camera("LobbyEdgeE", (86, -176, 9), (-10, 0, -2), 18)
    cams["Underside"] = C.camera("Underside", (300, -170, -150), (0, 10, -60), 20)
    return cams


def build(out):
    rng = random.Random(11)
    C.reset()
    C.sky_and_sun(*SUN)
    tex = os.path.join(out, "textures")
    S.surface_tiles("Meadow", -CAP, meadow_painter, tex)
    S.rim_strip("Rim_Turf", C.RIM, CAP, 0.3, rim_painter, tex, px=ST._px(1024))
    strata = build_strata(rng)
    for kind, obj in strata.items():
        walls, soffits = S.split_caps(obj)
        S.paint_scenery(S.split_sectors(walls, 4), ST.stone_painter(kind), tex, px=ST._px(1024), roughness=0.95, **ST.AO)
        S.paint_scenery(S.split_sectors(soffits, 2), ST.stone_painter(kind), tex, px=ST._px(512), roughness=0.95, **ST.AO)
    build_cliff_timber(rng, tex)
    D.turf_lip(tex, rng=rng)
    D.grass(tex)
    build_meadow_flowers(random.Random(23))
    build_backdrop(random.Random(BACKDROP_SEED), tex)
    # no outlines (user decision 2026-11-10): shapes read from geometry, colour, lighting and contact shadow
    for name, n in D.corridor_report():
        print("CORRIDOR", name, n)
    return cameras()


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    ST.FAST = "--fast" in args
    if ST.FAST:
        S.TILE_PX = 256
    out = args[0] if args and not args[0].startswith("--") else os.path.join(HERE, "out", "gnomon")
    out = os.path.abspath(out)
    cams = build(out)
    report, bad = C.check_export()
    for name, tris, mats in report:
        print(f"MESH {name}: {tris} tris, {mats} material(s)")
    print("OVER LIMIT:", bad)
    print("FLAT:", S.top_is_flat(("Meadow_", "Rim_")))
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "gnomon.blend"))
    if "--no-render" not in args:
        only = [a[7:] for a in args if a.startswith("--cams=")]
        if only:
            cams = {k: v for k, v in cams.items() if k in only[0].split(",")}
        for p in C.render_all(out, "gnomon", cams):
            print("RENDER", p)
