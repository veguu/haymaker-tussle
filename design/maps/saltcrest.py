"""Saltcrest: a glazed tile plaza with terracotta eaves, high above a winding coastline and harbour.

Run: blender -b --factory-startup -P saltcrest.py -- <out folder> [--no-render]
Backdrop: a low-contrast landscape far below (700 studs): sea, hills, a road, a harbour village and a
lighthouse. Signature material: glazed ceramic tile (sea-green, white, sun-baked orange) laid round a
compass rose, and matte terracotta in coping, roof tile and brick.

The plaza is painted (paint.py) as 5-stud handmade tiles: each its own hue and glaze finish, slightly
pillowed, glaze pooling darker at the edges, a few chipped corners showing the biscuit, a few repaired
tiles in a newer shade with fresher grout. The compass rose is crisp vector shapes cut through the
tiles with their own grout lines, wide enough to read from the oblique fighting camera; each point is
split light and dark. The whites are kept well below full white so grout and glaze still read in sun.
At the edge the glaze stops at a mortar line and matte terracotta coping takes over; under it two
overlapping courses of roof tile show their thickness and cut ends, and a warm shadow falls beneath.

The eaves overhang the drop below the surface. They're visual only: in Roblox they must be
CanCollide = false, so nobody can stand on them (see EXPORT notes).
"""
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
import paint as P  # noqa: E402
import surfaces as S  # noqa: E402
import saltcrest_sights as SS  # noqa: E402

TILE = 5.0
PLAZA_DEPTH = 3.0
SEA_GREEN = (0.16, 0.58, 0.52)
ORANGE = (0.90, 0.48, 0.18)
TERRACOTTA = (0.78, 0.36, 0.17)
GROUND = -700.0
HAZE = (0.62, 0.74, 0.92)
PA, PB = C.A - C.RIM, C.B - C.RIM

TC = {
    "white": P.rgb(214, 210, 196),
    "white_cool": P.rgb(202, 208, 208),
    "white_warm": P.rgb(220, 206, 182),
    "repair": P.rgb(196, 210, 214),
    "green_d": P.rgb(24, 110, 102),
    "green_l": P.rgb(76, 170, 152),
    "orange_d": P.rgb(186, 82, 30),
    "orange_l": P.rgb(236, 142, 62),
    "grout": P.rgb(148, 138, 122),
    "grout_new": P.rgb(186, 178, 162),
    "biscuit": P.rgb(206, 164, 122),
    "terracotta": P.rgb(190, 96, 52),
    "mortar": P.rgb(210, 198, 174),
    "salt": P.rgb(236, 232, 222),
}
# region codes -> colour
REGIONS = ["white", "green_d", "orange_l", "green_d", "green_l", "orange_d", "orange_l", "orange_l", "green_d", "green_d"]
FIELD, BAND, LINE, MAIN_D, MAIN_L, DIAG_D, DIAG_L, HEART, DOT, RING = range(10)


# --- the compass rose ----------------------------------------------------------------------------
def _point_sd(X, Y, ang, length, width):
    """Signed distance (studs) to one kite-shaped point of the star, and which half it is on."""
    dx, dy = math.cos(ang), math.sin(ang)
    a = X * dx + Y * dy
    b = -X * dy + Y * dx
    norm = math.sqrt(1 + (width / length) ** 2)
    sd = (np.abs(b) - width * (1 - a / length)) / norm
    sd = np.maximum(sd, a - length)
    sd = np.maximum(sd, -a - 4.0)
    return sd, b


def _ellipse_sd(X, Y, k):
    """Signed distance to the ellipse at fraction k of the plaza's semi-axes (negative inside)."""
    re = np.sqrt((X / PA) ** 2 + (Y / PB) ** 2)
    th = np.arctan2(Y / PB, X / PA)
    local = np.hypot(PA * np.cos(th), PB * np.sin(th))
    return (re - k) * local


def compass(X, Y):
    """Region code per point, plus the distance to the nearest visible pattern edge (for grout)."""
    region = np.full(X.shape, FIELD, dtype=np.int64)
    edge = np.full(X.shape, 99.0)
    covered = np.full(X.shape, 99.0)  # how far inside a higher shape we are (negative = inside)

    def lay(sd, code):
        nonlocal covered
        free = covered > 0
        here = (sd < 0) & free
        region[here] = code[here] if isinstance(code, np.ndarray) else code
        vis = covered > -0.15
        edge[:] = np.where(vis, np.minimum(edge, np.abs(sd)), edge)
        covered = np.minimum(covered, sd)

    r = np.hypot(X, Y)
    lay(r - 3.5, DOT)
    lay(r - 8.5, HEART)
    lay(r - 10.0, RING)
    mains = []
    for k in range(4):
        ang = k * math.pi / 2
        length = 0.86 * (PA if k % 2 == 0 else PB)
        sd, b = _point_sd(X, Y, ang, length, 14.0)
        mains.append((sd, b))
    sd_main = np.minimum.reduce([m[0] for m in mains])
    code = np.full(X.shape, MAIN_L)
    for sd, b in mains:
        code = np.where((sd <= sd_main + 1e-9) & (b < 0), MAIN_D, np.where(sd <= sd_main + 1e-9, MAIN_L, code))
    split = np.full(X.shape, 99.0)
    for sd, b in mains:
        split = np.where(sd < 0, np.minimum(split, np.abs(b)), split)
    free = covered > 0
    lay(sd_main, code)
    edge[:] = np.where(free & (sd_main < 0), np.minimum(edge, split), edge)
    diags = []
    for k in range(4):
        dx, dy = (1 if k in (0, 3) else -1), (1 if k < 2 else -1)
        ang = math.atan2(dy * PB, dx * PA)
        length = 0.6 * math.hypot(PA * math.cos(math.pi / 4), PB * math.sin(math.pi / 4))
        diags.append(_point_sd(X, Y, ang, length, 10.0))
    sd_diag = np.minimum.reduce([d[0] for d in diags])
    dcode = np.full(X.shape, DIAG_L)
    dsplit = np.full(X.shape, 99.0)
    for sd, b in diags:
        dcode = np.where(sd <= sd_diag + 1e-9, np.where(b < 0, DIAG_D, DIAG_L), dcode)
        dsplit = np.where(sd < 0, np.minimum(dsplit, np.abs(b)), dsplit)
    free = covered > 0
    lay(sd_diag, dcode)
    edge[:] = np.where(free & (sd_diag < 0), np.minimum(edge, dsplit), edge)
    lay(np.abs(r - 29.25) - 1.25, RING)
    lay(np.maximum(_ellipse_sd(X, Y, 0.888), -_ellipse_sd(X, Y, 0.875)), LINE)
    lay(np.maximum(_ellipse_sd(X, Y, 0.95), -_ellipse_sd(X, Y, 0.90)), BAND)
    return region, edge


def plaza_painter(X, Y):
    region, pat_edge = compass(X, Y)
    ix, iy = np.floor(X / TILE), np.floor(Y / TILE)
    lx, ly = X - (ix + 0.5) * TILE, Y - (iy + 0.5) * TILE
    # a handmade tile: rounded corners, edges that wander a little
    rr = 0.32
    half = TILE / 2 - 0.12
    wob = 0.05 * (P.vnoise2(X * 1.7, Y * 1.7, 401) - 0.5) * 2
    qx, qy = np.abs(lx) - (half - rr), np.abs(ly) - (half - rr)
    sd_tile = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rr + wob
    inside = np.minimum(-sd_tile, pat_edge - 0.1)
    grout = inside < 0

    h = [P.hash01(410 + k, ix, iy, region) for k in range(8)]
    names = np.array(REGIONS)
    base = np.stack([TC[n] for n in REGIONS])[region]
    whites = np.where((h[0] < 0.33)[..., None], TC["white_cool"], np.where((h[0] < 0.6)[..., None], TC["white_warm"], TC["white"]))
    base = np.where((region == FIELD)[..., None], whites, base)
    tint = 1 + 0.05 * (np.stack([h[1], h[2], h[3]], axis=-1) - 0.5)
    col = base * tint * (0.93 + 0.1 * h[4])[..., None]
    repaired = (region == FIELD) & (P.hash01(430, ix, iy) < 0.022)
    col = np.where(repaired[..., None], TC["repair"] * (0.97 + 0.04 * h[4])[..., None], col)
    # glaze pools darker toward the edge; the tile face is slightly pillowed
    pool = 1 - P.smoothstep(0.0, 0.5, inside)
    col = col * (1 - 0.12 * pool)[..., None]
    glaze_mottle = P.fbm2(X * 1.3, Y * 1.3, 402, 2)
    col = col * (0.97 + 0.06 * glaze_mottle)[..., None]
    height = 0.05 * P.smoothstep(0.0, 0.55, inside)
    rough = 0.2 + 0.16 * h[5]
    rough = np.where(h[6] < 0.08, 0.42, rough)
    # a chipped corner here and there shows the biscuit
    chipped = P.hash01(431, ix, iy) < 0.05
    cxs = np.where(P.hash01(432, ix, iy) < 0.5, -1.0, 1.0) * (TILE / 2)
    cys = np.where(P.hash01(433, ix, iy) < 0.5, -1.0, 1.0) * (TILE / 2)
    rc = 0.35 + 0.4 * P.hash01(434, ix, iy)
    chip = chipped & (np.hypot(lx - cxs, ly - cys) < rc * (0.8 + 0.5 * P.vnoise2(X * 6, Y * 6, 403))) & ~grout
    col = np.where(chip[..., None], TC["biscuit"] * (0.9 + 0.15 * P.vnoise2(X * 8, Y * 8, 404))[..., None], col)
    height = np.where(chip, -0.03, height)
    rough = np.where(chip, 0.95, rough)
    # a hairline crack, filled, across a few tiles
    cracked = (P.hash01(435, ix, iy) < 0.03) & ~grout
    ca = P.hash01(436, ix, iy) * math.pi
    cl = np.abs(lx * np.cos(ca) + ly * np.sin(ca) - (P.hash01(437, ix, iy) - 0.5) * 2 + 0.08 * np.sin(lx * 3))
    hair = cracked & (cl < 0.035)
    col = np.where(hair[..., None], col * 0.55, col)
    # grout
    gcol = np.where(repaired[..., None], TC["grout_new"], TC["grout"] * (0.9 + 0.2 * P.fbm2(X * 0.6, Y * 0.6, 405, 2))[..., None])
    col = np.where(grout[..., None], gcol, col)
    height = np.where(grout, -0.06, height)
    rough = np.where(grout, 0.95, rough)
    # broad, soft variation: sun fade and old water marks
    col = col * (0.97 + 0.06 * P.fbm2(X * 0.03, Y * 0.03, 406, 3))[..., None]
    return col, height, rough


def rim_painter(S_, Pp, FACE, X, Y, Z, info):
    """Matte terracotta coping: handmade pavers with cream mortar; on the outer face, the paver's
    edge, a mortar bed and a brick course, with a little salt bloom low down."""
    perim = info["perimeter"]
    n = round(perim / 3.2)
    ls = perim / n
    jitter = 0.25 * (P.hash01(501, np.floor(S_ / ls)) - 0.5)
    s = S_ + jitter
    seg = np.floor(s / ls)
    a = s - seg * ls
    dj = np.minimum(a, ls - a)
    h = [P.hash01(510 + k, seg) for k in range(4)]
    col = TC["terracotta"] * (0.84 + 0.26 * h[0])[..., None]
    col = np.where((h[1] < 0.15)[..., None], col * np.array([0.78, 0.7, 0.66]), col)
    col = col * (0.92 + 0.14 * P.vnoise2(S_ * 4, Pp * 4, 511))[..., None]
    burnt = P.smoothstep(0.66, 0.74, P.fbm2(S_ * 0.8, Pp * 0.8, 512, 3))
    col = col * (1 - 0.22 * burnt)[..., None]
    joint = dj < 0.1
    # outer face below the paver: mortar bed, then a course of brick headers
    side = FACE == 2
    bed = side & (Z < -1.2) & (Z > -1.38)
    brick_s = (S_ + 0.8) / 1.6
    bdj = np.minimum(brick_s % 1.0, 1 - brick_s % 1.0) * 1.6
    brick = side & (Z <= -1.38)
    bcol = P.rgb(176, 86, 50) * (0.85 + 0.25 * P.hash01(520, np.floor(brick_s)))[..., None]
    col = np.where(brick[..., None], bcol, col)
    joint = joint & ~brick | (brick & (bdj < 0.09)) | bed
    salt = side * P.smoothstep(-1.6, -2.8, Z) * P.smoothstep(0.5, 0.7, P.fbm2(S_ * 1.2, Z * 1.2, 521, 3))
    col = P.mix(col, TC["salt"], 0.35 * salt)
    inner = Pp < 0.12  # the mortar line where the glaze stops
    col = np.where((joint | inner)[..., None], TC["mortar"] * (0.9 + 0.1 * P.vnoise2(S_ * 3, Pp * 3, 522))[..., None], col)
    height = 0.05 * P.smoothstep(0.05, 0.3, dj)
    height = np.where(joint | inner, -0.05, height)
    rough = np.where(joint | inner, 1.0, 0.95)
    return col, height, rough


# --- eaves and brickwork -------------------------------------------------------------------------
def barrel_tile(bm, origin, outward, along, length, radius, droop_deg=15, sides=8, thickness=0.42, radius_end=None):
    """One curved roof tile: a half-tube lying outward from the rim, tipped down like eaves, with its
    thickness closed off at both cut ends and along both long edges. It widens from `radius` at its
    upper end to `radius_end` at its lower end, like a real tapered tile, so courses nest."""
    radius_end = radius if radius_end is None else radius_end
    o = Vector(origin)
    out = Vector((outward[0], outward[1], 0)).normalized()
    side = Vector((along[0], along[1], 0)).normalized()
    droop = math.radians(droop_deg)
    axis = (out * math.cos(droop) - Vector((0, 0, 1)) * math.sin(droop)).normalized()
    up = axis.cross(side).normalized()
    if up.z < 0:
        up = -up
    rings = []
    for end, rad in ((0.0, radius), (length, radius_end)):
        outer, inner = [], []
        for i in range(sides + 1):
            t = math.pi * i / sides
            dirv = side * math.cos(t) + up * math.sin(t)
            outer.append(bm.verts.new(o + axis * end + dirv * rad))
            inner.append(bm.verts.new(o + axis * end + dirv * (rad - thickness)))
        rings.append((outer, inner))
    (o0, i0), (o1, i1) = rings
    for i in range(sides):
        bm.faces.new((o0[i], o0[i + 1], o1[i + 1], o1[i]))
        bm.faces.new((i0[i + 1], i0[i], i1[i], i1[i + 1]))
        bm.faces.new((i0[i], o0[i], o0[i + 1], i0[i + 1]))
        bm.faces.new((o1[i], i1[i], i1[i + 1], o1[i + 1]))
    bm.faces.new((o0[0], i0[0], i1[0], o1[0]))
    bm.faces.new((i0[sides], o0[sides], o1[sides], i1[sides]))


def _rim_points(step=3.4):
    steps = 1600
    pts = [C.oval_xy(i / steps * math.tau) for i in range(steps)]
    acc, last = 0.0, pts[0]
    placed = [pts[0]]
    for p in pts[1:]:
        acc += math.dist(p, last)
        last = p
        if acc >= step:
            placed.append(p)
            acc = 0.0
    return placed


def build_eaves():
    """Two courses of barrel tiles in columns down the slope: the upper course starts at the rim, the
    lower one tucks under its ends, so every column shows the overlap and both cut ends. All of it stays
    below the surface (top at -0.1 or lower)."""
    upper, lower = bmesh.new(), bmesh.new()
    for (x, y) in _rim_points():
        t = math.atan2(y / C.B, x / C.A)
        nx, ny = math.cos(t) / C.A, math.sin(t) / C.B
        n = math.hypot(nx, ny)
        nx, ny = nx / n, ny / n
        droop = math.radians(16)
        o = Vector((x - nx * 0.6, y - ny * 0.6, -1.95))
        barrel_tile(upper, o, (nx, ny), (-ny, nx), 4.4, 1.4, 16, radius_end=1.75)
        # the lower course on the same line, its narrow end tucked 0.8 up inside the upper one's mouth
        axis = Vector((nx * math.cos(droop), ny * math.cos(droop), -math.sin(droop)))
        barrel_tile(lower, o + axis * 3.6, (nx, ny), (-ny, nx), 4.2, 1.2, 16, radius_end=1.72)
    mat = C.flat_material("Saltcrest_RoofTileHolder", TERRACOTTA)
    return [C.mesh_object("Eaves_RoofTiles_Upper", upper, mat), C.mesh_object("Eaves_RoofTiles_Lower", lower, mat)]


STEPS = [0.985, 0.9, 0.79, 0.66, 0.52, 0.37, 0.22]


def build_underside(rng):
    """Brick courses stepping in like stacked plates, each with a sea-green glazed lip; copper pipes down
    the sides; a few hanging planters."""
    bricks, lips = bmesh.new(), bmesh.new()
    z = -PLAZA_DEPTH
    for k, s in enumerate(STEPS):
        h = 9.0 if k < 3 else 8.0
        C.oval_prism(bricks, C.A * s, C.B * s, z, z - h, segments=64)
        if 0 < k:
            C.ring(lips, C.A * s + 0.9, C.B * s + 0.9, C.A * s - 0.5, C.B * s - 0.5, z + 0.01, z - 1.2, segments=64)
        z -= h
    C.cone(bricks, (0, 0, z), C.B * 0.14, -26, sides=10)
    brick_obj = C.mesh_object("Underside_Brick", bricks, C.flat_material("Saltcrest_BrickHolder", TERRACOTTA))
    C.mesh_object("Underside_TileLips", lips, C.flat_material("Saltcrest_GlazeLip", SEA_GREEN, 0.4))

    pipes = bmesh.new()
    for i in range(7):
        t = i / 7 * math.tau + 0.3
        x0, y0 = C.oval_xy(t, C.A * 0.975, C.B * 0.975)
        x1, y1 = C.oval_xy(t, C.A * 0.6, C.B * 0.6)
        C.cylinder(pipes, (x0, y0, -3.5), (x0 * 0.99, y0 * 0.99, -20), 0.9, 8)
        C.cylinder(pipes, (x0 * 0.99, y0 * 0.99, -20), (x1, y1, -32), 0.9, 8)
        C.cylinder(pipes, (x1, y1, -32), (x1, y1, -44), 0.9, 8)
    C.mesh_object("Underside_CopperPipes", pipes, C.flat_material("Saltcrest_Copper", (0.33, 0.62, 0.52), 0.6))

    planters, bushes = bmesh.new(), bmesh.new()
    for i in range(6):
        t = i / 6 * math.tau + 0.8
        x, y = C.oval_xy(t, C.A * 0.9, C.B * 0.9)
        C.box(planters, (x, y, -16), (6, 4, 3.5), rot_z=t)
        C.blob(bushes, (x, y, -13.5), 3.4, subdiv=1, squash=0.8)
    C.mesh_object("Underside_Planters", planters, terracotta_material("Saltcrest_Planter"))
    C.mesh_object("Underside_PlanterBushes", bushes, C.flat_material("Saltcrest_Bush", (0.26, 0.56, 0.22)))
    return brick_obj


def brick_painter(Pw, N, obj):
    """Running-bond brick, cream mortar, each brick its own fired colour, a few dark headers; salt
    bloom gathering low on each stepped course and under the glazed lips."""
    x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
    course = z / 1.6
    row = np.floor(course)
    rowf = course - row
    around = np.arctan2(y, x) * np.hypot(x, y)
    along = around / 3.4 + 0.5 * row
    bi = np.floor(along)
    bf = along - bi
    mortar = (np.minimum(bf, 1 - bf) * 3.4 < 0.13) | (np.minimum(rowf, 1 - rowf) * 1.6 < 0.13)
    h = P.hash01(601, bi, row)
    col = P.mix(P.rgb(150, 66, 38), P.rgb(198, 108, 64), h)
    col = np.where((P.hash01(602, bi, row) < 0.08)[..., None], P.rgb(108, 52, 34), col)
    col = col * (0.9 + 0.16 * P.vnoise3(x * 3, y * 3, z * 3, 603))[..., None]
    mcol = TC["mortar"] * (0.85 + 0.2 * P.fbm3(x * 0.8, y * 0.8, z * 0.8, 604, 2))[..., None]
    col = np.where(mortar[..., None], mcol, col)
    # how far above the bottom of its stepped course this point is
    tops = [-PLAZA_DEPTH]
    for k in range(len(STEPS)):
        tops.append(tops[-1] - (9.0 if k < 3 else 8.0))
    above = np.full(z.shape, 99.0)
    for zt, zb in zip(tops, tops[1:]):
        m = (z <= zt + 0.01) & (z >= zb - 0.01)
        above = np.where(m, z - zb, above)
    below_lip = np.full(z.shape, 99.0)
    for zt in tops[1:-1]:
        below_lip = np.minimum(below_lip, np.where(z <= zt, zt - z, 99.0))
    mott = P.fbm3(x * 0.6, y * 0.6, z * 0.6, 605, 3)
    bloom = (1 - P.smoothstep(0.0, 3.5, above)) * P.smoothstep(0.45, 0.65, mott)
    bloom = np.maximum(bloom, (1 - P.smoothstep(0.0, 1.5, below_lip)) * P.smoothstep(0.55, 0.7, mott) * 0.6)
    streak = P.smoothstep(0.62, 0.72, P.fbm3(x * 0.8, y * 0.8, z * 0.08, 606, 3)) * 0.5
    col = P.mix(col, TC["salt"], np.clip(0.42 * bloom + 0.2 * streak, 0, 0.5))
    return col


_PERIM_T, _PERIM_CUM, _PERIM = None, None, None


def roof_painter(Pw, N, obj):
    """Terracotta tiles, each its own firing; the cut ends and the edges show paler unglazed clay and
    the thickness; the insides are darker."""
    global _PERIM_T, _PERIM_CUM, _PERIM
    if _PERIM_T is None:
        _PERIM_T, _PERIM_CUM, _PERIM = S.oval_arclength(C.A, C.B)
    x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
    t = np.arctan2(y / C.B, x / C.A) % math.tau
    s = np.interp(t, _PERIM_T, _PERIM_CUM)
    col_id = np.round(s / 3.4)
    course = (np.hypot(x / C.A, y / C.B) > 1.03).astype(float)
    h = P.hash01(701, col_id, course)
    col = P.mix(P.rgb(178, 82, 44), P.rgb(214, 122, 70), h)
    col = np.where((P.hash01(702, col_id, course) < 0.12)[..., None], col * np.array([0.8, 0.72, 0.68]), col)
    col = col * (0.9 + 0.16 * P.fbm3(x * 1.5, y * 1.5, z * 1.5, 703, 2))[..., None]
    # cut ends: faces whose normal runs along the tile's axis (outward and down)
    rx, ry = x / C.A ** 2, y / C.B ** 2
    rn = np.hypot(rx, ry)
    rx, ry = rx / rn, ry / rn
    d = math.radians(17)
    along = np.abs(N[..., 0] * rx * math.cos(d) + N[..., 1] * ry * math.cos(d) - N[..., 2] * math.sin(d))
    cut = along > 0.8
    col = np.where(cut[..., None], P.rgb(222, 156, 106) * (0.9 + 0.15 * P.vnoise3(x * 6, y * 6, z * 6, 704))[..., None], col)
    inside = (N[..., 2] < -0.3) & ~cut
    col = np.where(inside[..., None], col * 0.72, col)
    return col


def terracotta_material(name, base=TERRACOTTA, haze=0.0):
    base = tuple(b + (hz - b) * haze for b, hz in zip(base, HAZE))
    mat, nt, bsdf = C.new_material(name)
    tc = C.coords(nt)
    blot = C.node(nt, "ShaderNodeTexNoise", Scale=0.25, Detail=3.0)
    nt.links.new(tc.outputs["Object"], blot.inputs["Vector"])
    r = C.ramp(nt, [(0.3, tuple(c * 0.85 for c in base)), (0.5, base), (0.7, tuple(min(c * 1.08, 1) for c in base))])
    nt.links.new(blot.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


# --- backdrop (the coast, Net Rock and the open sea are in saltcrest_sights.py) -----------------------
def build_clouds(rng):
    clear = (C.A + 60, C.B + 60)
    # sparse and well out, so the view down to the coast stays open
    C.cloud_layer("Clouds_Low", -360, 300, 1600, 8, (50, 90), rng, keep_clear=(1100, 900))
    C.cloud_layer("Clouds_Near", -120, 220, 700, 5, (28, 44), rng, keep_clear=clear, avoid=[(SS.NET_ROCK[0], SS.NET_ROCK[1], 190)])
    C.cloud_layer("Clouds_Horizon", 40, 1300, 1900, 8, (110, 190), rng)


SUN = (30, 42)  # heading (0 = east), elevation, in degrees
BACKDROP_SEED = 123


def build_backdrop(rng):
    SS.build(rng)
    # clouds are no longer baked into the map: the game's environment system (src/shared/EnvironmentKit) builds
    # and drifts them from the map's preset in Config/MapEnvironments. build_clouds is kept for reference.


def cameras():
    cams = C.standard_cameras(gameplay_target=(-60, 8, -4), edge_target=(-380, 120, -800))
    # The gameplay view faces the coast side here, so the hills show past the rim.
    for name, loc, target in (
        ("Gameplay", (70, 18, 16), (-60, 8, -4)),
        ("Edge", (-C.A + 14, 10, 16), (-900, 150, -620)),
        ("Recovery", (-C.A - 38, 24, -14), (-C.A + 8, 0, 1)),
        ("Overview", (420, -380, 140), (-420, 80, -330)),
    ):
        cams[name].location = loc
        d = Vector(target) - Vector(loc)
        cams[name].rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    for name, (loc, target, lens) in SS.CAMS.items():
        cams[name] = C.camera(name, loc, target, lens)
    return cams


def build(out):
    C.reset()
    C.sky_and_sun(*SUN)
    tex = os.path.join(out, "textures")
    S.surface_tiles("Plaza_Tiles", -PLAZA_DEPTH, plaza_painter, tex)
    S.rim_strip("Rim_Terracotta", C.RIM, PLAZA_DEPTH, 0.3, rim_painter, tex)
    eaves = build_eaves()
    brick = build_underside(random.Random(23))
    warm = (0.52, 0.30, 0.20)
    for obj in eaves:
        S.paint_scenery(S.split_sectors(obj, 4), roof_painter, tex, roughness=0.95, ao_strength=0.9, ao_tint=warm, ao_distance=3.0)
    walls, soffits = S.split_caps(brick)
    S.paint_scenery(S.split_sectors(walls, 4), brick_painter, tex, roughness=0.95, ao_strength=0.85, ao_tint=warm, ao_distance=8.0)
    S.paint_scenery(S.split_sectors(soffits, 4), brick_painter, tex, px=512, roughness=0.95, ao_strength=0.85, ao_tint=warm, ao_distance=8.0)
    build_backdrop(random.Random(BACKDROP_SEED))
    return cameras()

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = args[0] if args and not args[0].startswith("--") else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "saltcrest")
    out = os.path.abspath(out)
    cams = build(out)
    report, bad = C.check_export()
    for name, tris, mats in report:
        print(f"MESH {name}: {tris} tris, {mats} material(s)")
    print("OVER LIMIT:", bad)
    print("FLAT:", S.top_is_flat(("Plaza_Tiles_", "Rim_")))
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "saltcrest.blend"))
    if "--no-render" not in args:
        for p in C.render_all(out, "saltcrest", cams):
            print("RENDER", p)
