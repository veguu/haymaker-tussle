"""Kitestead: a raft of oversized painted timber hung in open sky, held up by kites.

Run: blender -b --factory-startup -P kitestead.py -- <out folder> [--no-render]
Backdrop: open sky, a few soft clouds far below, restrained glimpses of kites. Signature material:
hand-built timber deck, every plank end round the rim painted red, mustard or leaf green.

The deck is painted board by board (paint.py): 6-stud boards running along X, each its own length
(two to four beam gaps), its joints staggered and always landing on a beam of the frame below, so the
sparse nail heads sit where a board really meets a beam. Each board has its own tone and grain; a few
have a knot, a shallow split at a cut end, or are a lighter, newer replacement plank (the short ones).
The rim is a band of plank ends painted over wood: chipped back to timber on the exposed corner and the
joints, strongest colour in the sheltered places, end grain showing through on the outer face.
"""
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
import paint as P  # noqa: E402
import surfaces as S  # noqa: E402
import kitestead_sights as KS  # noqa: E402

DECK_DEPTH = 4.0
BOARD = 6.0  # board width, studs
ROW_Y0 = -96.0
NROWS = 32
# The frame's top layer: beams along Y every 13 studs (build_underside uses the same numbers).
L1_SCALE = 0.92
BEAM_SPACING = 13.0
BEAM_X0 = -C.A * L1_SCALE + BEAM_SPACING / 2
NBEAMS = int((2 * C.A * L1_SCALE - BEAM_SPACING / 2) // BEAM_SPACING) + 1
LAYERS = [(0.92, "Y", -4.0, 5.5), (0.74, "X", -9.5, 6.0), (0.54, "Y", -15.5, 6.5), (0.34, "X", -22.0, 7.0)]

PAINT = [P.rgb(178, 52, 36), P.rgb(214, 160, 44), P.rgb(76, 140, 58)]  # red, mustard, leaf green
WOOD = {
    "honey": P.rgb(184, 128, 74),
    "amber": P.rgb(170, 106, 60),
    "straw": P.rgb(196, 150, 92),
    "grey": P.rgb(156, 136, 108),
    "raw": P.rgb(206, 166, 112),
    "fresh": P.rgb(214, 172, 112),
}


def beam_x(k):
    return BEAM_X0 + k * BEAM_SPACING


def _layout():
    """For every row of boards: the x of each butt joint (always on a beam) and which beams carry one."""
    bounds, joint = [], np.zeros((NROWS, NBEAMS), dtype=bool)
    width = 0
    for r in range(NROWS):
        rng = random.Random(4000 + r * 7)
        ks = []
        k = rng.randint(0, 3)
        while k < NBEAMS:
            ks.append(k)
            step = 1 if rng.random() < 0.07 else rng.choice([2, 3, 3, 4, 4])
            k += step
        for k in ks:
            joint[r, k] = True
        b = [-1000.0] + [beam_x(k) for k in ks] + [1000.0]
        bounds.append(b)
        width = max(width, len(b))
    table = np.full((NROWS, width), 1e4)
    for r, b in enumerate(bounds):
        table[r, : len(b)] = b
    return table, joint


BOUNDS, JOINT = _layout()


# --- the deck ------------------------------------------------------------------------------------
def deck_painter(X, Y):
    shape = X.shape
    r = np.clip(np.floor((Y - ROW_Y0) / BOARD), 0, NROWS - 1).astype(np.int64)
    across = Y - ROW_Y0 - r * BOARD
    start, end = np.empty(shape), np.empty(shape)
    bidx = np.zeros(shape, dtype=np.int64)
    for rr in np.unique(r):
        m = r == rr
        bnd = BOUNDS[rr]
        i = np.clip(np.searchsorted(bnd, X[m], side="right") - 1, 0, len(bnd) - 2)
        bidx[m] = i
        start[m] = bnd[i]
        end[m] = bnd[i + 1]
    length = end - start
    to_end = np.minimum(X - start, end - X)
    h = [P.hash01(100 + s, r, bidx) for s in range(20)]

    # each board: a tone, a brightness, a little greying; the short ones are newer replacements
    repl = (np.abs(length - BEAM_SPACING) < 0.5) | (h[0] < 0.025)
    tone = np.where((h[1] < 0.45)[..., None], WOOD["honey"], np.where((h[1] < 0.75)[..., None], WOOD["amber"], WOOD["straw"]))
    tone = tone * (0.88 + 0.2 * h[2])[..., None]
    broad = P.fbm2(X * 0.012, Y * 0.012, 3, 3)
    weather = np.clip((h[3] - 0.55) * 1.4, 0, 0.42) + 0.3 * P.smoothstep(0.55, 0.75, P.fbm2(X * 0.02 + 40, Y * 0.02, 4, 3))
    tone = P.mix(tone, WOOD["grey"], np.clip(weather, 0, 0.6))
    tone = np.where(repl[..., None], WOOD["fresh"] * (0.95 + 0.1 * h[2])[..., None], tone)
    tone = tone * (0.9 + 0.2 * broad)[..., None]

    # grain along the board, bent round knots
    vs, ve = np.maximum(start, -C.A), np.minimum(end, C.A)
    knot_x = vs + 2.5 + h[4] * np.maximum(ve - vs - 5.0, 0.5)
    knot_y = 1.1 + h[5] * (BOARD - 2.2)
    has_knot = (h[6] < 0.2) & ~repl
    dk = np.hypot((X - knot_x) / 1.8, across - knot_y)
    rk = 0.26 + 0.24 * h[7]
    swirl = has_knot * 1.9 * np.exp(-((dk / (rk * 3.2)) ** 2))
    warp = P.fbm2(X * 0.03 + h[8] * 50, across * 0.25 + h[9] * 50, 11, 3)
    g = across * (1.0 + 0.9 * h[10]) + (warp - 0.5) * 2.6 + h[11] * 7 + swirl
    ring = g - np.floor(g)
    late = P.smoothstep(0.55, 0.8, ring) * (1 - P.smoothstep(0.86, 0.98, ring))
    fibre = P.fbm2(X * 0.9, across * 7.0 + h[12] * 30, 13, 2)
    col = tone * ((1 - 0.24 * late) * (0.92 + 0.14 * fibre))[..., None]
    col = np.where(repl[..., None], tone * ((1 - 0.14 * late) * (0.95 + 0.08 * fibre))[..., None], col)
    # knots: a dark core, a darker ring
    knot_core = has_knot * P.smoothstep(rk, rk * 0.65, dk)
    knot_ring = has_knot * np.exp(-(((dk - rk) / 0.1) ** 2))
    col = P.mix(col, P.rgb(70, 38, 18), knot_core * 0.9)
    col = col * (1 - 0.35 * knot_ring)[..., None]
    # end grain: a darker band at every cut end
    eg = 1 - P.smoothstep(0.0, 0.5, to_end)
    col = col * (1 - 0.24 * eg)[..., None]
    # a shallow split running in from a cut end
    use_start = h[13] < 0.5
    from_end = np.where(use_start, X - start, end - X)
    sl = 1.5 + 3.5 * h[14]
    sy = 1.2 + h[15] * (BOARD - 2.4)
    width = 0.1 * (1 - from_end / sl)
    split = (h[16] < 0.15) & ~repl & (from_end < sl) & (np.abs(across - sy - 0.08 * np.sin(from_end * 2.3 + h[17] * 6)) < width)
    col = np.where(split[..., None], P.rgb(52, 30, 16), col)
    # seams and rounded edges, a little grime along them
    de = np.minimum(across, BOARD - across)
    gap = (de < 0.12) | (to_end < 0.06)
    bevel = 0.07 * np.minimum(P.smoothstep(0.1, 0.45, de), P.smoothstep(0.05, 0.35, to_end))
    col = col * (0.78 + 0.22 * P.smoothstep(0.1, 0.6, np.minimum(de, to_end * 1.5)))[..., None]

    # nail heads, only where a board crosses a beam: both ends at a joint, now and then mid-board
    kb = np.clip(np.round((X - BEAM_X0) / BEAM_SPACING), 0, NBEAMS - 1).astype(np.int64)
    xb = beam_x(kb)
    at_joint = JOINT[r, kb]
    side = np.where(X >= xb, 1.0, -1.0)
    nx = xb + np.where(at_joint, side * 1.0, 0.0) + (P.hash01(71, r, kb, side) - 0.5) * 0.3
    ny = np.where(across < BOARD / 2, 1.3, BOARD - 1.3) + (P.hash01(72, r, kb, across < BOARD / 2) - 0.5) * 0.3
    half = C.B * L1_SCALE * np.sqrt(np.clip(1 - (xb / (C.A * L1_SCALE)) ** 2, 0, 1))
    present = (at_joint | (P.hash01(73, r, kb) < 0.3)) & (np.abs(Y) < half - 1.5)
    dn = np.where(present, np.hypot(X - nx, across - ny), 99.0)
    rn = 0.17
    col = P.mix(col, P.rgb(120, 72, 44), 0.35 * (1 - P.smoothstep(0.15, 0.55, dn)))
    col = P.mix(col, P.rgb(62, 58, 54), P.smoothstep(rn, rn * 0.7, dn))

    col = np.where(gap[..., None], P.rgb(34, 22, 14), col)
    height = bevel - 0.006 * late - 0.05 * split
    height = height + 0.035 * np.sqrt(np.clip(1 - (dn / rn) ** 2, 0, 1)) - 0.015 * np.exp(-(((dn - rn - 0.05) / 0.06) ** 2))
    height = np.where(gap, -0.1, height)
    rough = 0.82 - 0.08 * late
    rough = np.where(repl, 0.72, rough)
    rough = np.where(dn < rn, 0.45, rough)
    rough = np.where(gap, 1.0, rough)
    return col, height, rough


def rim_painter(S_, Pp, FACE, X, Y, Z, info):
    """Plank ends round the rim, about 6 studs each, painted red, mustard, green in turn."""
    perim = info["perimeter"]
    n = round(perim / BOARD)
    ls = perim / n
    seg = np.floor(S_ / ls)
    a = S_ - seg * ls
    dj = np.minimum(a, ls - a)
    hs = [P.hash01(300 + k, seg) for k in range(4)]
    paint = np.stack(PAINT)[(seg % 3).astype(np.int64)] * (0.9 + 0.16 * hs[0])[..., None]
    # brush strokes along the board's end, and the wood showing faintly through the coat
    streak = P.fbm2(S_ * 4.0, Pp * 0.35, 43, 3)
    ac = ls / 2 + (hs[1] - 0.5) * 2.5
    zc = -info["depth"] - 1.5 - 3 * hs[2]
    rd = np.hypot(a - ac, Z - zc)
    rings = rd * 1.5 + 0.5 * P.fbm2(S_ * 0.8, Z * 0.8, 44, 2)
    ringline = 1 - P.smoothstep(0.0, 0.18, np.abs(rings - np.round(rings)))
    grainline = 1 - P.smoothstep(0.0, 0.2, np.abs((S_ * 1.3 + P.fbm2(S_ * 0.2, Pp * 0.5, 45, 2) * 2) % 1 - 0.5))
    woodline = np.where(FACE == 2, ringline, grainline)
    paint = paint * ((0.9 + 0.16 * streak) * (1 - 0.07 * woodline))[..., None]
    # sun-bleached on the open top, strongest colour in the shelter by the deck and under the lip
    bleach = np.where(FACE <= 1, 0.24 * P.smoothstep(0.3, 1.9, Pp), 0.0)
    pale = paint * 0.72 + paint.mean(axis=-1, keepdims=True) * 0.28 + 0.035
    paint = P.mix(paint, pale, bleach)
    # chips: mostly on the exposed outer corner and at the joints, a few anywhere
    dc = np.abs(Pp - (info["p1"] + info["p2"]) / 2)
    exposure = np.maximum.reduce(
        [1 - P.smoothstep(0.1, 1.1, dc), 0.8 * (1 - P.smoothstep(0.1, 0.7, dj)), 0.55 * (1 - P.smoothstep(0.05, 0.5, np.abs(Pp - info["p3"])))]
    )
    cn = 0.65 * P.fbm2(S_ * 1.8, Pp * 1.8, 41, 3) + 0.35 * P.fbm2(S_ * 0.6, Pp * 0.6, 42, 2)
    thr = 0.79 - 0.36 * exposure
    chip = P.smoothstep(thr - 0.012, thr + 0.012, cn)
    wood = WOOD["raw"] * (0.88 + 0.16 * hs[3])[..., None] * (1 - 0.22 * woodline)[..., None]
    col = P.mix(paint, wood, chip)
    col = col * (1 - 0.3 * (chip * (1 - chip) * 4))[..., None]
    gap = dj < 0.1
    col = np.where(gap[..., None], P.rgb(40, 26, 16), col)
    height = 0.03 * (1 - chip) - 0.08 * (1 - P.smoothstep(0.02, 0.3, dj)) - 0.01 * woodline * chip
    rough = np.where(FACE <= 1, 0.62, 0.55)
    rough = P.mix(rough, 0.9, chip)
    rough = np.where(gap, 1.0, rough)
    return col, height, rough


# --- underside -----------------------------------------------------------------------------------
def _layer_beams(scale, axis):
    """(position across, half length) of each beam in a layer."""
    a, b = C.A * scale, C.B * scale
    out = []
    if axis == "Y":
        x = -a + BEAM_SPACING / 2
        while x < a:
            half = b * math.sqrt(max(1 - (x / a) ** 2, 0))
            if half > 4:
                out.append((x, half))
            x += BEAM_SPACING
    else:
        y = -b + BEAM_SPACING / 2
        while y < b:
            half = a * math.sqrt(max(1 - (y / b) ** 2, 0))
            if half > 4:
                out.append((y, half))
            y += BEAM_SPACING
    return out


def rope_loop(bm, centre, axis, width, z0, z1, t=0.45):
    """A loop of rope round a beam's cross-section (a square frame of four rope bars). `axis` is the
    beam's direction; the loop lies across it."""
    cx, cy = centre
    span = width + 2 * t
    tall = z1 - z0 + 2 * t
    if axis == "X":
        C.box(bm, (cx, cy, z1 + t / 2), (t, span, t))
        C.box(bm, (cx, cy, z0 - t / 2), (t, span, t))
        for s in (-1, 1):
            C.box(bm, (cx, cy + s * (width / 2 + t / 2), (z0 + z1) / 2), (t, t, tall))
    else:
        C.box(bm, (cx, cy, z1 + t / 2), (span, t, t))
        C.box(bm, (cx, cy, z0 - t / 2), (span, t, t))
        for s in (-1, 1):
            C.box(bm, (cx + s * (width / 2 + t / 2), cy, (z0 + z1) / 2), (t, t, tall))


def build_underside(rng):
    """Four layers of crossbeams, each smaller and turned 90 degrees, so the raft tapers below like an
    upside-down stepped pyramid; then a keel. Painted caps on the beam ends. Where two layers cross at
    the outside of the frame, a square lashing: three turns round the lower beam each side of the upper
    one and two round both, so the joints read from the recovery camera."""
    beams = {"X": bmesh.new(), "Y": bmesh.new()}
    caps = [bmesh.new(), bmesh.new(), bmesh.new()]
    lash = bmesh.new()
    count = 0
    widths = {}
    for li, (scale, axis, top, height) in enumerate(LAYERS):
        z = top - height / 2
        for pos, half in _layer_beams(scale, axis):
            w = 5.0 + rng.uniform(-0.5, 0.5)
            widths[(li, round(pos, 2))] = w
            if axis == "Y":
                C.box(beams["Y"], (pos, 0, z), (w, half * 2, height))
                ends = [((pos, s * (half + 0.3), z), (w + 0.2, 0.6, height + 0.2)) for s in (-1, 1)]
            else:
                C.box(beams["X"], (0, pos, z), (half * 2, w, height))
                ends = [((s * (half + 0.3), pos, z), (0.6, w + 0.2, height + 0.2)) for s in (-1, 1)]
            for centre, size in ends:
                C.box(caps[count % 3], centre, size)
                count += 1
    # lashings at the outermost crossings of each lower beam
    for li in range(len(LAYERS) - 1):
        up_scale, up_axis, up_top, up_h = LAYERS[li]
        lo_scale, lo_axis, lo_top, lo_h = LAYERS[li + 1]
        upper = _layer_beams(up_scale, up_axis)
        for lpos, lhalf in _layer_beams(lo_scale, lo_axis):
            lw = widths[(li + 1, round(lpos, 2))]
            hits = [(upos, widths[(li, round(upos, 2))]) for upos, uhalf in upper if abs(upos) < lhalf - 3 and abs(lpos) < uhalf - 1]
            if not hits:
                continue
            for upos, uw in (min(hits), max(hits)) if len(hits) > 1 else hits:
                cx, cy = (upos, lpos) if lo_axis == "X" else (lpos, upos)
                lz0, lz1 = lo_top - lo_h, lo_top
                for s in (-1, 1):
                    for j in range(3):  # turns round the lower beam
                        off = s * (uw / 2 + 0.4 + 0.55 * j)
                        c = (cx + off, cy) if lo_axis == "X" else (cx, cy + off)
                        rope_loop(lash, c, lo_axis, lw, lz0, lz1)
                    for j in range(2):  # turns round the upper beam, each side of the lower one
                        off = s * (lw / 2 + 0.4 + 0.55 * j)
                        c = (cx, cy + off) if lo_axis == "X" else (cx + off, cy)
                        rope_loop(lash, c, up_axis, uw, lz1, up_top)
    C.box(beams["X"], (0, 0, -33.0), (C.A * 0.22, C.B * 0.16, 8.0))
    C.box(beams["X"], (0, 0, -40.0), (C.A * 0.10, C.B * 0.08, 6.0))
    holder = C.flat_material("Kitestead_Timber", WOOD["honey"])
    objs = {
        "beamsX": C.mesh_object("Underside_BeamsX", beams["X"], holder),
        "beamsY": C.mesh_object("Underside_BeamsY", beams["Y"], holder),
        "caps": [
            C.mesh_object("Underside_EndsRed", caps[0], C.flat_material("Kitestead_PaintRed", tuple(PAINT[0]))),
            C.mesh_object("Underside_EndsMustard", caps[1], C.flat_material("Kitestead_PaintMustard", tuple(PAINT[1]))),
            C.mesh_object("Underside_EndsGreen", caps[2], C.flat_material("Kitestead_PaintGreen", tuple(PAINT[2]))),
        ],
        "lash": C.mesh_object("Underside_Lashings", lash, C.flat_material("Kitestead_Rope", (0.42, 0.29, 0.14))),
    }
    return objs


def _layer_at(z):
    best = None
    for scale, axis, top, height in LAYERS:
        if top - height - 0.5 <= z <= top + 0.5:
            best = (scale, axis, top, height)
    return best


def beam_painter(axis):
    """Timber beams: grain along each beam, end grain rings on the cut ends, greyer on top, darker and
    damp-looking underneath."""

    def painter(Pw, N, obj):
        x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
        along = x if axis == "X" else y
        cross = y if axis == "X" else x
        warp = P.fbm3(along * 0.03, cross * 0.25, z * 0.25, 5, 3)
        g = (cross * 0.9 + z * 0.6) * 1.1 + (warp - 0.5) * 3.0
        ring = g - np.floor(g)
        late = P.smoothstep(0.55, 0.8, ring) * (1 - P.smoothstep(0.86, 0.98, ring))
        fibre = P.fbm3(along * 0.8, cross * 5, z * 5, 6, 2)
        tone = P.rgb(150, 102, 62) * (0.88 + 0.22 * P.fbm3(x * 0.05, y * 0.05, z * 0.05, 7, 2))[..., None]
        col = tone * ((1 - 0.25 * late) * (0.9 + 0.16 * fibre))[..., None]
        # end grain on the cut ends
        nax = np.abs(N[..., 0] if axis == "X" else N[..., 1])
        end = nax > 0.7
        # ring centre: the nearest beam of the layer at this height
        cc = np.zeros_like(cross)
        zc = np.zeros_like(z)
        for scale, ax, top, height in LAYERS:
            if ax != axis:
                continue
            m = (z <= top + 0.5) & (z >= top - height - 0.5)
            span = (C.B if axis == "X" else C.A) * scale
            o = -span + BEAM_SPACING / 2
            cc = np.where(m, o + np.round((cross - o) / BEAM_SPACING) * BEAM_SPACING, cc)
            zc = np.where(m, top - height / 2 - 1.5, zc)
        rd = np.hypot(cross - cc, z - zc) * 1.6 + 0.4 * P.fbm3(x * 0.5, y * 0.5, z * 0.5, 8, 2)
        rline = 1 - P.smoothstep(0.0, 0.2, np.abs(rd - np.round(rd)))
        check = P.ridge(P.fbm3(x * 0.4, y * 0.4, z * 0.4, 9, 2), 0.012)
        end_col = P.rgb(128, 86, 52) * (1 - 0.3 * rline - 0.5 * check)[..., None]
        col = np.where(end[..., None], end_col, col)
        up, down = N[..., 2] > 0.6, N[..., 2] < -0.6
        col = np.where(up[..., None], P.mix(col, P.rgb(150, 138, 122), 0.3), col)
        col = np.where(down[..., None], col * np.array([0.8, 0.82, 0.8]), col)
        return col

    return painter


def caps_painter(Pw, N, obj):
    key = 0 if "Red" in obj.name else 1 if "Mustard" in obj.name else 2
    x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
    streak = P.fbm3(x * 2, y * 2, z * 0.3, 21, 3)
    paint = PAINT[key] * (0.9 + 0.16 * streak)[..., None]
    cn = P.fbm3(x * 1.4, y * 1.4, z * 1.4, 22, 3)
    chip = P.smoothstep(0.62, 0.64, cn)
    col = P.mix(paint, WOOD["raw"] * 0.9, chip)
    return col * (1 - 0.4 * chip * (1 - chip) * 4)[..., None]


def rope_painter(Pw, N, obj):
    x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
    twist = (x + y + z) * 2.2 + 0.3 * P.fbm3(x, y, z, 31, 2)
    groove = 1 - P.smoothstep(0.0, 0.22, np.abs(twist - np.round(twist)))
    fibre = P.fbm3(x * 6, y * 6, z * 6, 32, 2)
    col = P.rgb(176, 136, 84) * (0.88 + 0.2 * fibre)[..., None]
    return col * (1 - 0.45 * groove)[..., None]


# --- backdrop ------------------------------------------------------------------------------------
def diamond(bm, centre, facing, height, width, depth, part):
    """One quarter (part 0..3) of a kite's diamond, as a thin prism, in the plane facing `facing`."""
    cx, cy, cz = centre
    fx, fy = facing
    rx, ry = -fy, fx
    tilt = math.radians(25)
    up = (fx * -math.sin(tilt), fy * -math.sin(tilt), math.cos(tilt))
    top = (up[0] * height * 0.62, up[1] * height * 0.62, up[2] * height * 0.62)
    bottom = (-up[0] * height * 0.38, -up[1] * height * 0.38, -up[2] * height * 0.38)
    left = (-rx * width / 2, -ry * width / 2, 0)
    right = (rx * width / 2, ry * width / 2, 0)
    corners = [(top, right), (right, bottom), (bottom, left), (left, top)][part]
    pts = [(0, 0, 0), corners[0], corners[1]]
    n = (fx * math.cos(tilt) * depth / 2, fy * math.cos(tilt) * depth / 2, math.sin(tilt) * depth / 2)
    front = [bm.verts.new((cx + p[0] + n[0], cy + p[1] + n[1], cz + p[2] + n[2])) for p in pts]
    back = [bm.verts.new((cx + p[0] - n[0], cy + p[1] - n[1], cz + p[2] - n[2])) for p in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new((front[i], back[i], back[j], front[j]))
    return top, bottom


def build_kites(rng, angles=(160, 205, 250, 292, 335)):
    fabric_colours = {
        "Red": (0.86, 0.24, 0.18),
        "Mustard": (0.97, 0.76, 0.26),
        "Green": (0.36, 0.68, 0.30),
        "Cream": (0.98, 0.93, 0.80),
    }
    fabric = {k: bmesh.new() for k in fabric_colours}
    rigging = bmesh.new()
    pairs = [("Red", "Cream"), ("Mustard", "Green"), ("Green", "Cream"), ("Cream", "Red"), ("Mustard", "Red")]
    # Compass bearings (0 = east): west round to south-east. North is the village's, east the kite train's.
    for i, deg in enumerate(angles):
        t = math.radians(deg) + rng.uniform(-0.08, 0.08)
        dist = rng.uniform(175, 260)
        x, y = dist * math.cos(t) * 1.05, dist * math.sin(t) * 0.95
        size = rng.uniform(34, 50)
        # Well below the deck, so they never break the rim line from anywhere on the arena: a kite's top
        # is 0.62 of its size above its centre and stays at least 50 studs under the deck.
        z = rng.uniform(-110, -55) - size * 0.62
        facing = (-math.cos(t), -math.sin(t))
        c1, c2 = pairs[i % len(pairs)]
        top = bottom = None
        for part in range(4):
            top, bottom = diamond(fabric[c1 if part % 2 == 0 else c2], (x, y, z), facing, size, size * 0.72, 0.5, part)
        C.cylinder(rigging, (x + top[0], y + top[1], z + top[2]), (x + bottom[0], y + bottom[1], z + bottom[2]), 0.35, 6)
        anchor_t = t + rng.uniform(-0.1, 0.1)
        ax, ay = C.A * 0.7 * math.cos(anchor_t), C.B * 0.7 * math.sin(anchor_t)
        C.cylinder(rigging, (x + bottom[0], y + bottom[1], z + bottom[2]), (ax, ay, -12.0), 0.25, 5)
        bx, by, bz = x + bottom[0], y + bottom[1], z + bottom[2]
        for k in range(1, 7):
            px = bx - facing[0] * k * 3.0
            py = by - facing[1] * k * 3.0
            pz = bz - k * 3.2 - 0.25 * k * k
            C.box(fabric[c2 if k % 2 else c1], (px, py, pz), (2.4, 2.4, 1.2), rot_z=t + k)
    objs = []
    for name, bm in fabric.items():
        objs.append(C.mesh_object(f"Kites_{name}", bm, C.flat_material(f"Kite_{name}", fabric_colours[name], 0.95)))
    objs.append(C.mesh_object("Kites_Rigging", rigging, C.flat_material("Kitestead_Rigging", (0.40, 0.29, 0.19))))
    return objs


def build_clouds(rng):
    """A few soft clouds: a sparse near tier, a sea of cloud far below for the height, some on the
    horizon. The village's hillside and the kite train are kept open."""
    clear = (C.A + 45, C.B + 45)
    north = [(0, 600, 380)]
    C.cloud_layer("Clouds_Near", -95, 200, 650, 6, (26, 44), rng, keep_clear=clear, avoid=north)
    C.cloud_layer("Clouds_Mid", -190, 160, 1000, 10, (40, 70), rng, keep_clear=clear, avoid=north)
    C.cloud_layer("Clouds_Sea", -330, 0, 1500, 40, (70, 120), rng)
    C.cloud_layer("Clouds_Horizon", 30, 1300, 1900, 6, (120, 200), rng, avoid=[(0, 1000, 500), (800, -100, 320)])


SUN = (215, 40)  # heading (0 = east), elevation, in degrees
BACKDROP_SEED = 107


def build_backdrop(rng):
    """Everything beyond the raft: its kites, the timber village's mountain, the kite train, clouds."""
    build_kites(rng)
    KS.build(rng, diamond)
    # clouds are no longer baked into the map: the game's environment system (src/shared/EnvironmentKit) builds
    # and drifts them from the map's preset in Config/MapEnvironments. build_clouds is kept for reference.


def cameras():
    cams = C.standard_cameras(gameplay_target=(60, 12, 3), edge_target=(C.A + 220, 60, -45))
    for name, (loc, target, lens) in KS.CAMS.items():
        cams[name] = C.camera(name, loc, target, lens)
    return cams


def build(out):
    rng = random.Random(7)
    C.reset()
    C.sky_and_sun(*SUN)
    tex = os.path.join(out, "textures")
    S.surface_tiles("Deck", -DECK_DEPTH, deck_painter, tex)
    S.rim_strip("Rim_PaintedEnds", C.RIM, DECK_DEPTH, 0.35, rim_painter, tex)
    under = build_underside(rng)
    S.paint_scenery(S.split_sectors(under["beamsX"], 4), beam_painter("X"), tex, ao_tint=(0.42, 0.34, 0.30))
    S.paint_scenery(S.split_sectors(under["beamsY"], 4), beam_painter("Y"), tex, ao_tint=(0.42, 0.34, 0.30))
    S.paint_scenery(under["caps"], caps_painter, tex, px=512, roughness=0.6)
    S.paint_scenery(S.split_sectors(under["lash"], 4), rope_painter, tex, px=512, ao_strength=0.6)
    build_backdrop(random.Random(BACKDROP_SEED))
    return cameras()

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = args[0] if args and not args[0].startswith("--") else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "kitestead")
    out = os.path.abspath(out)
    cams = build(out)
    report, bad = C.check_export()
    for name, tris, mats in report:
        print(f"MESH {name}: {tris} tris, {mats} material(s)")
    print("OVER LIMIT:", bad)
    print("FLAT:", S.top_is_flat(("Deck_", "Rim_")))
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "kitestead.blend"))
    if "--no-render" not in args:
        for p in C.render_all(out, "kitestead", cams):
            print("RENDER", p)
