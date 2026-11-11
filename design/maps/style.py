"""The painted low-poly style (pass 4, user brief 2026-11-09): a grass cap over chunky stone, trees
with a silhouette each, honey timber, and one or two accent colours. No outlines anywhere: every edge
is a change of colour or of light.

Three references, used together: stacked blue stone under a bright grass cap (terrain), a family of
stylised trees (plants), and a hollow log (wood). The rules taken from them:
- Stone: few, broad, flat faces, each leaning its own way so it catches the light differently; blocks
  set in or out of each other; colour in two or three painted tones, no grain, no pits.
- Grass: one fresh green, a lighter lip at the edge, a darker skirt hanging over the stone.
- Trees: a small family (twin puff, tiered taper, umbrella, bush). A crown is shaded as ONE volume:
  light top to deep underside, nothing smaller than the crown itself.
- Wood: honey on top, darker underneath, a few long strokes along the grain, a pale cut end with a
  darker uneven rim.
- Accents: coral and gold, on a few plants, flowers and painted trim only.

A `Group` is one cluster of scenery (an islet with its plants). Its cap, stone, wood and crowns are
four meshes, each painted from world position (surfaces.paint_scenery), so one texture each.
"""
import math

import bmesh
import numpy as np
from mathutils import Vector

import common as C
import paint as P
import sights as K
import surfaces as S

SKY = np.array([0.62, 0.74, 0.92])
PAL = {
    # turf (softened 2026-11-10, user: "too vibrant": less saturated, the warm and cool closer to the leaf)
    "leaf": P.rgb(106, 170, 82),
    "warm": P.rgb(140, 180, 90),
    "cool": P.rgb(88, 160, 102),
    "lip": P.rgb(170, 204, 112),
    "lip_hi": P.rgb(204, 222, 150),
    "drape": P.rgb(64, 138, 88),
    "drape_dark": P.rgb(44, 104, 86),
    "blade": P.rgb(196, 218, 136),
    "blade_dark": P.rgb(56, 124, 84),
    # stone
    "cream": P.rgb(240, 222, 180),
    "sand": P.rgb(220, 186, 136),
    "bluegrey": P.rgb(160, 172, 190),
    # wood
    "wood": P.rgb(222, 150, 62),
    "wood_hi": P.rgb(244, 190, 96),
    "wood_dark": P.rgb(134, 78, 62),
    "wood_cut": P.rgb(246, 216, 150),
    "wood_in": P.rgb(92, 58, 104),
    "trunk": P.rgb(156, 100, 76),
    "trunk_hi": P.rgb(186, 128, 88),
    "trunk_dark": P.rgb(96, 62, 76),
    # accents
    "coral": P.rgb(238, 86, 62),
    "gold": P.rgb(252, 198, 50),
    "petal": P.rgb(252, 246, 230),
}
# crowns: (top, underside)
CROWN = {
    "leaf": (P.rgb(156, 218, 84), P.rgb(40, 138, 86)),
    "deep": (P.rgb(92, 188, 100), P.rgb(26, 108, 98)),
    "lime": (P.rgb(204, 232, 94), P.rgb(92, 166, 66)),
    "bloom": (P.rgb(252, 204, 70), P.rgb(232, 84, 62)),
}
FLAT = {
    "coral": (238, 86, 62),
    "gold": (252, 198, 50),
    "cream": (246, 236, 208),
    "stem": (70, 156, 84),
    "rope": (120, 84, 58),
}
UNDER = np.array([0.60, 0.64, 0.86])  # what a face pointing straight down is multiplied by
AO = dict(ao_tint=(0.50, 0.50, 0.70), ao_strength=0.55, ao_distance=10.0)
STONE_SPLIT = (0.40, 0.54)  # share of an islet's depth: cream above, a blue-grey shelf, sand below
FAST = False  # previews: quarter-size textures


def hz(col, k):
    return col + (SKY - col) * k if k else col


def lit(col, N, top=0.08, under=1.0):
    """Painted light: faces that look up lift a little, faces that look down fall to a cool shadow."""
    nz = N[..., 2]
    col = col * (1 + top * np.clip(nz, 0, 1))[..., None]
    dn = (under * np.clip(-nz, 0, 1))[..., None]
    return col * (1 - dn * (1 - UNDER))


def _px(px):
    return max(128, px // 4) if FAST else px


# --- stone ---------------------------------------------------------------------------------------
def chunk_band(bm, centre, a, b, z_top, thick, blocks, rng, inset=(0.93, 1.0), lean=0.06, smax=1.0, recess_at=(), recess=None):
    """One layer of chunky stone round an oval: `blocks` broad blocks, each a chord of the oval set in
    by its own amount, with a crease part-way down and a foot that leans in, so every face is flat,
    a little uneven and catches the light at its own angle. Nothing ever reaches outside the oval."""
    cx, cy = centre
    phase = rng.uniform(0, math.tau)
    cuts = [phase + (i + rng.uniform(-0.28, 0.28)) / blocks * math.tau for i in range(blocks)]
    top, mid, bot = [], [], []
    for k in range(blocks):
        t0 = cuts[k]
        t1 = cuts[k + 1] if k + 1 < blocks else cuts[0] + math.tau
        s = rng.uniform(*inset)
        if recess is not None and any(((ang - t0) % math.tau) < (t1 - t0) for ang in recess_at):
            s = recess
        zm = z_top - thick * rng.uniform(0.3, 0.7)
        for t in (t0, t1):
            x, y = a * math.cos(t), b * math.sin(t)
            sm = min(s * rng.uniform(1 - lean * 0.6, 1 + lean * 0.4), smax)
            sb = sm * rng.uniform(1 - lean, 1.0)
            top.append(bm.verts.new((cx + x * s, cy + y * s, z_top)))
            mid.append(bm.verts.new((cx + x * sm, cy + y * sm, zm + rng.uniform(-0.08, 0.08) * thick)))
            bot.append(bm.verts.new((cx + x * sb, cy + y * sb, z_top - thick)))
    n = len(top)
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for ra, rb in ((top, mid), (mid, bot)):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((ra[i], rb[i], rb[j], ra[j]))


def stone_colour(kind, Pw, N, haze=0.0):
    """Pale stone in two or three painted tones. `kind` is a key of PAL, or an integer array
    (0 cream, 1 blue-grey, 2 sand)."""
    x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
    if isinstance(kind, str):
        base = P.fill(x.shape, PAL[kind])
    else:
        base = np.where((kind == 0)[..., None], PAL["cream"], np.where((kind == 1)[..., None], PAL["bluegrey"], PAL["sand"]))
    # broad soft drift, then a few crisp painted patches a touch lighter or darker
    col = base * (0.95 + 0.10 * P.fbm3(x * 0.03, y * 0.03, z * 0.045, 301, 2))[..., None]
    c = P.vnoise3(x * 0.06, y * 0.06, z * 0.09, 305)
    col = col * (1 + 0.035 * P.smoothstep(0.66, 0.69, c) - 0.055 * P.smoothstep(0.34, 0.31, c))[..., None]
    return hz(lit(col, N, top=0.07), haze)


def stone_painter(kind, haze=0.0):
    return lambda Pw, N, obj: stone_colour(kind, Pw, N, haze)


# --- wood ----------------------------------------------------------------------------------------
def _frame(d):
    h = Vector((1, 0, 0)) if abs(d.z) > 0.7 else Vector((0, 0, 1))
    u = d.cross(h).normalized()
    return u, d.cross(u).normalized()


def tube(bm, reg, pts, radii, sides=6, rng=None, tone=0.0, caps=(True, True), jitter=0.05):
    """A timber or trunk along a path: slightly uneven rings, flat ends. Every stretch is registered
    as (start, end, radius, tone) so the wood painter knows which way the grain runs."""
    pts = [Vector(p) for p in pts]
    rings = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u, v = _frame(d)
        ring = []
        for k in range(sides):
            t = k / sides * math.tau
            rr = r * (1 + (rng.uniform(-jitter, jitter) if rng else 0))
            ring.append(bm.verts.new(p + (u * math.cos(t) + v * math.sin(t)) * rr))
        rings.append(ring)
    for ra, rb in zip(rings, rings[1:]):
        for k in range(sides):
            n = (k + 1) % sides
            bm.faces.new((ra[k], ra[n], rb[n], rb[k]))
    if caps[0]:
        bm.faces.new(list(reversed(rings[0])))
    if caps[1]:
        bm.faces.new(rings[-1])
    for (p0, r0), (p1, r1) in zip(zip(pts, radii), zip(pts[1:], radii[1:])):
        reg.append((tuple(p0), tuple(p1), max(r0, r1), tone))
    return rings


def hollow_log(bm, reg, a, b, r, rng, wall=0.13, sides=10, bend=0.05):
    """A big hollow log on its side: an uneven cut rim at each end, a thick wall, a dark inside."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    length = (b - a).length
    u, v = _frame(d)
    outer, inner, centres = [], [], []
    for i, t in enumerate((0.0, 0.3, 0.68, 1.0)):
        c = a.lerp(b, t) + u * (bend * length * math.sin(t * math.pi)) + v * (0.3 * r * (rng.uniform(-1, 1) if 0 < i < 3 else 0))
        rr = r * rng.uniform(0.95, 1.06)
        ro, ri = [], []
        for k in range(sides):
            ang = k / sides * math.tau
            e = u * math.cos(ang) + v * math.sin(ang)
            cut = d * (rng.uniform(-0.035, 0.035) * length if i in (0, 3) else 0.0)
            j = rng.uniform(0.95, 1.05)
            ro.append(bm.verts.new(c + e * rr * j + cut))
            ri.append(bm.verts.new(c + e * rr * j * (1 - wall) + cut))
        outer.append(ro)
        inner.append(ri)
        centres.append(c)
    for i in range(3):
        for k in range(sides):
            n = (k + 1) % sides
            bm.faces.new((outer[i][k], outer[i][n], outer[i + 1][n], outer[i + 1][k]))
            bm.faces.new((inner[i][n], inner[i][k], inner[i + 1][k], inner[i + 1][n]))
        reg.append((tuple(centres[i]), tuple(centres[i + 1]), r, 0.0))
    for k in range(sides):
        n = (k + 1) % sides
        bm.faces.new((outer[0][n], outer[0][k], inner[0][k], inner[0][n]))
        bm.faces.new((outer[3][k], outer[3][n], inner[3][n], inner[3][k]))
    return centres


def wood_painter(reg, haze=0.0):
    """Honey on top, darker underneath, a few long strokes along the grain, a pale cut end inside a
    darker rim, a deep violet-brown inside a hollow. Trunks (tone 1) are the same wood, browner."""
    A = np.array([s[0] for s in reg], dtype=np.float64)
    B = np.array([s[1] for s in reg], dtype=np.float64)
    R = np.array([s[2] for s in reg], dtype=np.float64)
    TONE = np.array([s[3] for s in reg], dtype=np.float64)
    D = B - A
    L = np.maximum(np.linalg.norm(D, axis=1), 1e-6)
    D = D / L[:, None]
    HX = np.abs(D[:, 2]) > 0.7
    H = np.where(HX[:, None], np.array([1.0, 0, 0]), np.array([0, 0, 1.0]))
    W1 = np.cross(D, H)
    W1 = W1 / np.linalg.norm(W1, axis=1)[:, None]
    W2 = np.cross(D, W1)

    def painter(Pw, N, obj):
        best = np.full(Pw.shape[:2], 1e18)
        idx = np.zeros(Pw.shape[:2], dtype=np.int64)
        for i in range(len(A)):
            rel = Pw - A[i]
            u = rel @ D[i]
            uc = np.clip(u, 0, L[i])
            rad = rel - uc[..., None] * D[i]
            score = np.maximum(np.sqrt((rad * rad).sum(-1)) - R[i], 0) + np.abs(u - uc)
            near = score < best
            best = np.where(near, score, best)
            idx = np.where(near, i, idx)
        d = D[idx]
        rel = Pw - A[idx]
        u = (rel * d).sum(-1)
        rad = rel - u[..., None] * d
        dist = np.maximum(np.sqrt((rad * rad).sum(-1)), 1e-6)
        e = rad / dist[..., None]
        phi = np.arctan2((e * W2[idx]).sum(-1), (e * W1[idx]).sum(-1))
        end = np.abs((N * d).sum(-1)) > 0.75
        inside = ((N * e).sum(-1) < -0.35) & ~end
        tone = TONE[idx][..., None]
        base = PAL["wood"] * (1 - tone) + PAL["trunk"] * tone
        high = PAL["wood_hi"] * (1 - tone) + PAL["trunk_hi"] * tone
        dark = PAL["wood_dark"] * (1 - tone) + PAL["trunk_dark"] * tone
        nz = N[..., 2]
        col = P.mix(base, high, 0.9 * np.clip(nz, 0, 1) ** 0.8)
        col = P.mix(col, dark, 0.8 * np.clip(-nz, 0, 1) ** 0.8)
        # a few long sweeping strokes: noise stretched hard along the grain
        k = idx * 7.31
        strokes = P.ridge(P.fbm2(u * 0.07 + k, phi * 1.7 + k, 77, 2), 0.03)
        col = P.mix(col, dark, 0.55 * strokes)
        lights = P.ridge(P.fbm2(u * 0.05 - k, phi * 1.2 + 40 + k, 78, 2), 0.02)
        col = P.mix(col, high, 0.4 * lights * (1 - strokes))
        # cut ends: pale heartwood, one growth ring, a darker uneven rim of bark
        f = dist / R[idx] + 0.07 * (P.fbm2(phi * 2.0 + k, u * 0 + 3, 79, 2) - 0.5)
        cut = P.fill(nz.shape, PAL["wood_cut"]) * (1 - 0.12 * P.ridge(f + 0.02, 0.05))[..., None]
        cut = P.mix(cut, base * 0.82, P.smoothstep(0.76, 0.8, f))
        col = np.where(end[..., None], cut, col)
        hollow = P.mix(P.fill(nz.shape, PAL["wood_in"]), dark, 0.25 + 0.3 * np.clip(nz, 0, 1))
        col = np.where(inside[..., None], hollow, col)
        return hz(col, haze)

    return painter


# --- grass caps and crowns -----------------------------------------------------------------------
def turf_field(X, Y, seed=0):
    """The turf everywhere: fresh leaf-green with broad patches of a warmer and a cooler green, their
    edges soft but definite, like areas of paint. Nothing fine."""
    wob = 0.07 * (P.fbm2(X * 0.11, Y * 0.11, 54 + seed, 3) - 0.5)
    fw = P.fbm2(X * 0.021, Y * 0.021, 51 + seed, 3) + wob
    fc = P.fbm2(X * 0.019 + 40, Y * 0.019 - 15, 52 + seed, 3) - wob
    warm = P.smoothstep(0.535, 0.56, fw)
    cool = P.smoothstep(0.575, 0.6, fc) * (1 - warm)
    col = P.fill(X.shape, PAL["leaf"])
    # softened 2026-11-10: the patches are gentle shifts now, not bold areas of paint
    col = P.mix(col, PAL["warm"], 0.5 * warm)
    col = P.mix(col, PAL["cool"], 0.5 * cool)
    dab = P.fbm2(X * 0.07 + 9, Y * 0.07, 55 + seed, 2)
    col = P.mix(col, PAL["warm"], 0.14 * P.smoothstep(0.60, 0.63, dab))
    col = P.mix(col, PAL["cool"], 0.11 * P.smoothstep(0.40, 0.37, dab))
    return col


def cap_painter(reg, haze=0.0):
    """An islet's grass cap: turf on top with a lighter lip near the edge, a deeper green skirt."""
    def painter(Pw, N, obj):
        x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
        re = np.full(x.shape, 1e9)
        zc = np.zeros(x.shape)
        for cx, cy, cz, rx, ry in reg:
            r = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
            near = r < re
            re = np.where(near, r, re)
            zc = np.where(near, cz, zc)
        top = turf_field(x, y, 3)
        top = P.mix(top, PAL["lip"], P.smoothstep(0.86, 0.9, re + 0.05 * (P.fbm2(x * 0.2, y * 0.2, 61, 2) - 0.5)))
        down = np.clip((zc - z) / 3.6, 0, 1)
        skirt = P.mix(P.fill(x.shape, PAL["drape"]), PAL["drape_dark"], P.smoothstep(0.25, 0.9, down))
        col = np.where((N[..., 2] > 0.6)[..., None], top, skirt)
        return hz(lit(col, N, top=0.0, under=0.8), haze)

    return painter


def crown_painter(reg, haze=0.0):
    """Each crown as one broad volume: its light colour on top and toward the sun, sliding to its deep
    colour underneath. No leaves, no speckle."""
    sun = np.array([-0.3, -0.12, 1.0])
    sun = sun / np.linalg.norm(sun)

    def painter(Pw, N, obj):
        x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
        best = np.full(x.shape, 1e9)
        t = np.zeros(x.shape)
        topc = P.fill(x.shape, CROWN["leaf"][0])
        botc = P.fill(x.shape, CROWN["leaf"][1])
        for cx, cy, cz, rxy, rz, key in reg:
            dn = ((x - cx) / rxy) ** 2 + ((y - cy) / rxy) ** 2 + ((z - cz) / rz) ** 2
            near = dn < best
            best = np.where(near, dn, best)
            t = np.where(near, (z - (cz - rz)) / (2 * rz), t)
            topc = np.where(near[..., None], CROWN[key][0], topc)
            botc = np.where(near[..., None], CROWN[key][1], botc)
        facing = (N * sun).sum(-1) * 0.5 + 0.5
        k = P.smoothstep(0.12, 0.92, 0.6 * np.clip(t, 0, 1) + 0.4 * facing)
        return hz(P.mix(botc, topc, k), haze)

    return painter


# --- a cluster of scenery ------------------------------------------------------------------------
class Group:
    """One cluster: an islet (or several) with its plants and timber. `flat` skips the painting and
    gives single colours, for things far away."""

    def __init__(self, name, tex_dir, haze=0.0, px=1024, flat=False):
        self.name, self.tex, self.haze, self.px, self.flat = name, tex_dir, haze, px, flat
        self.bm = {k: bmesh.new() for k in ("Cap", "Stone", "Wood", "Crown")}
        self.caps, self.stones, self.woods, self.crowns = [], [], [], []
        self.kit = K.Kit(name, FLAT, haze=haze)

    def _stone_kind(self, Pw):
        x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
        best = np.full(x.shape, 1e18)
        rel = np.zeros(x.shape)
        for cx, cy, ztop, depth, r in self.stones:
            d = np.hypot(x - cx, y - cy) / r
            near = d < best
            best = np.where(near, d, best)
            rel = np.where(near, (ztop - z) / depth, rel)
        return np.where(rel < STONE_SPLIT[0], 0, np.where(rel < STONE_SPLIT[1], 1, 2))

    def finish(self):
        flat_cols = {"Cap": PAL["leaf"], "Stone": PAL["cream"] * 0.95, "Wood": PAL["trunk"], "Crown": P.rgb(84, 172, 92)}
        painters = {
            "Cap": lambda: cap_painter(self.caps, self.haze),
            "Stone": lambda: (lambda Pw, N, obj: stone_colour(self._stone_kind(Pw), Pw, N, self.haze)),
            "Wood": lambda: wood_painter(self.woods, self.haze),
            "Crown": lambda: crown_painter(self.crowns, self.haze),
        }
        objs = {}
        for key, bm in self.bm.items():
            if not bm.verts:
                bm.free()
                continue
            name = f"{self.name}_{key}"
            mat = C.flat_material(name, tuple(float(c) for c in hz(flat_cols[key], self.haze)), 0.95)
            obj = C.mesh_object(name, bm, mat, smooth=(key == "Crown"))
            if not self.flat:
                S.paint_scenery([obj], painters[key](), self.tex, px=_px(self.px), roughness=0.95, **AO)
            objs[key] = obj
        self.bm = {}
        self.kit.finish()
        return objs


def islet(G, centre, rx, ry, depth, rng, segs=16, cap=3.6):
    """A floating islet in the arena's own build: a grass cap with a soft lip and a wavy skirt, over
    three layers of chunky stone drawn in to a hanging point."""
    cx, cy, cz = centre
    bm = G.bm["Cap"]
    rings = [[], [], []]
    for i in range(segs):
        t = i / segs * math.tau
        j = 1 + rng.uniform(-0.07, 0.07)
        x, y = rx * math.cos(t) * j, ry * math.sin(t) * j
        wave = (0.9 if i % 2 else -0.5) * rng.uniform(0.6, 1.2) * cap / 3.6
        rings[0].append(bm.verts.new((cx + x, cy + y, cz)))
        rings[1].append(bm.verts.new((cx + x * 1.025, cy + y * 1.025, cz - cap * 0.35)))
        rings[2].append(bm.verts.new((cx + x * 0.965, cy + y * 0.965, cz - cap + wave)))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[2])))
    for ra, rb in zip(rings, rings[1:]):
        for i in range(segs):
            n = (i + 1) % segs
            bm.faces.new((ra[i], rb[i], rb[n], ra[n]))
    G.caps.append((cx, cy, cz, rx, ry))
    z = cz - cap * 0.6
    sb = G.bm["Stone"]
    blocks = max(6, segs * 2 // 3)
    for share, scale, n in ((STONE_SPLIT[0], 0.93, blocks), (STONE_SPLIT[1] - STONE_SPLIT[0], 0.86, blocks + 3), (0.26, 0.72, max(5, blocks - 3))):
        chunk_band(sb, (cx, cy), rx * scale, ry * scale, z, depth * share, n, rng, inset=(0.86, 1.0), lean=0.1)
        z -= depth * share
    C.cone(sb, (cx, cy, z + 1), min(rx, ry) * 0.6, -depth * 0.2, sides=5, rng=rng, jitter=0.15, tip_offset=(rng.uniform(-0.15, 0.15) * rx, rng.uniform(-0.15, 0.15) * ry))
    G.stones.append((cx, cy, cz - cap * 0.6, depth, max(rx, ry)))


# --- plants --------------------------------------------------------------------------------------
def puff(G, centre, r, key="leaf", squash=0.82, rng=None, lumps=0.16, register=True):
    """A rounded crown: a low-poly ball with three or four broad lobes and a flatter underside."""
    bm = G.bm["Crown"]
    res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    dirs = []
    for _ in range(4):
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 1))) if rng else Vector((0, 0, 1))
        dirs.append(d.normalized())
    c = Vector(centre)
    for v in res["verts"]:
        n = v.co.normalized()
        k = 1 - lumps * 0.6 + lumps * sum(max(0.0, n.dot(d)) ** 2 for d in dirs)
        p = n * k
        if p.z < 0:
            p.z *= 0.62
        v.co = c + Vector((p.x * r, p.y * r, p.z * r * squash))
    if register:
        G.crowns.append((c.x, c.y, c.z + 0.12 * r * squash, r * 1.12, r * squash * 1.0, key))


def trunk(G, base, top, r, rng, bend=0.1):
    """A trunk with a flared foot and one soft bend."""
    base, top = Vector(base), Vector(top)
    d = top - base
    side = Vector((-d.y, d.x, 0))
    side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
    if rng and rng.random() < 0.5:
        side = -side
    mid = base.lerp(top, 0.55) + side * (bend * d.length)
    pts = [base - Vector((0, 0, 1.2)), base.lerp(top, 0.1), mid, top]
    tube(G.bm["Wood"], G.woods, pts, [r * 1.75, r * 1.1, r * 0.95, r * 0.7], 6, rng, tone=1.0)
    return mid


def twin(G, at, h, rng, key="leaf", key2=None):
    """A leaning trunk carrying two rounded crowns: a big one at the top, a smaller one on a side
    branch lower down."""
    at = Vector(at)
    a = rng.uniform(0, math.tau)
    lean = Vector((math.cos(a), math.sin(a), 0))
    top = at + lean * (0.3 * h) + Vector((0, 0, 0.66 * h))
    mid = trunk(G, at, top, 0.045 * h + 0.3, rng, bend=0.12)
    r1 = 0.36 * h
    puff(G, top + Vector((0, 0, r1 * 0.45)), r1, key, 0.8, rng)
    end = mid - lean * (0.34 * h) + Vector((0, 0, 0.13 * h))
    tube(G.bm["Wood"], G.woods, [mid - Vector((0, 0, 0.04 * h)), end], [0.03 * h + 0.2, 0.022 * h + 0.15], 5, rng, tone=1.0)
    r2 = 0.23 * h
    puff(G, end + Vector((0, 0, r2 * 0.4)), r2, key2 or key, 0.8, rng)


def tiered(G, at, h, rng, key="deep", n=4):
    """A tall tapered canopy of stacked tiers, each a soft bell, the tip curling a little off-centre."""
    at = Vector(at)
    a = rng.uniform(0, math.tau)
    curl = Vector((math.cos(a), math.sin(a), 0)) * (0.1 * h)
    z0 = 0.16 * h
    span = h - z0
    radius = 0.25 * h
    trunk(G, at, at + curl * 0.15 + Vector((0, 0, 0.3 * h)), 0.035 * h + 0.3, rng, bend=0.03)
    bm = G.bm["Crown"]
    sides = 8
    for k in range(n):
        f = k / n
        r = radius * (1 - 0.74 * f)
        zb = at.z + z0 + span * f * 0.9
        th = span / n * 1.5
        c = at + curl * (f * f)
        turn = rng.uniform(0, math.tau)
        jit = [rng.uniform(0.92, 1.08) for _ in range(sides)]
        tilt = Vector((rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06)))

        def ring(fr, fz, dup=False):
            out = []
            for i in range(sides):
                t = turn + i / sides * math.tau
                x, y = math.cos(t) * r * fr * jit[i], math.sin(t) * r * fr * jit[i]
                out.append(bm.verts.new((c.x + x, c.y + y, zb + th * fz + (x * tilt.x + y * tilt.y))))
            return out

        skirt, belly, neck = ring(1.0, 0.1), ring(0.72, 0.48), ring(0.22, 0.88)
        tip = bm.verts.new((c.x + curl.x * 0.12, c.y + curl.y * 0.12, zb + th * 1.02))
        for ra, rb in ((skirt, belly), (belly, neck)):
            for i in range(sides):
                j = (i + 1) % sides
                bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
        for i in range(sides):
            bm.faces.new((neck[i], neck[(i + 1) % sides], tip))
        # the underside is its own set of points, so the skirt keeps a crisp edge under smooth shading
        under, inner = ring(1.0, 0.1), ring(0.5, 0.26)
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((under[j], under[i], inner[i], inner[j]))
        bm.faces.new(list(reversed(inner)))
    G.crowns.append((at.x + curl.x * 0.3, at.y + curl.y * 0.3, at.z + z0 + span * 0.5, radius * 1.1, span * 0.52, key))


def umbrella(G, at, h, rng, key="lime"):
    """A wide, flat crown on a curved trunk, with two smaller puffs tucked under its edge."""
    at = Vector(at)
    a = rng.uniform(0, math.tau)
    lean = Vector((math.cos(a), math.sin(a), 0))
    top = at + lean * (0.22 * h) + Vector((0, 0, 0.72 * h))
    trunk(G, at, top, 0.05 * h + 0.3, rng, bend=0.2)
    r = 0.5 * h
    puff(G, top + Vector((0, 0, r * 0.12)), r, key, 0.46, rng, lumps=0.12, register=False)
    for s in (-1, 1):
        off = Vector((-lean.y, lean.x, 0)) * (s * r * 0.62) + lean * (rng.uniform(-0.2, 0.3) * r)
        puff(G, top + off - Vector((0, 0, r * 0.1)), r * 0.5, key, 0.6, rng, register=False)
    G.crowns.append((top.x, top.y, top.z + r * 0.05, r * 1.25, r * 0.5, key))


def bush(G, at, r, rng, key="leaf"):
    at = Vector(at)
    puff(G, at + Vector((0, 0, r * 0.3)), r, key, 0.66, rng)


def flowers(G, at, n, spread, rng, keys=("coral", "gold", "coral"), size=1.5):
    """A patch of simple flowers: a flat five-sided head on a short stem."""
    x0, y0, z0 = at
    for i in range(n):
        a = rng.uniform(0, math.tau)
        d = spread * math.sqrt(rng.random())
        x, y = x0 + d * math.cos(a), y0 + d * math.sin(a)
        s = size * rng.uniform(0.8, 1.25)
        hgt = s * rng.uniform(0.9, 1.6)
        G.kit.cyl("stem", (x, y, z0 - 0.3), (x, y, z0 + hgt), s * 0.12, 4)
        key = keys[i % len(keys)]
        G.kit.cone(key, (x, y, z0 + hgt), s, s * 0.35, 5)
        G.kit.cone("gold" if key != "gold" else "cream", (x, y, z0 + hgt + s * 0.2), s * 0.34, s * 0.3, 5)


def sprout(G, at, h, rng, key="gold"):
    """A young shoot with two pointed leaves (the hollow log's new growth)."""
    at = Vector(at)
    a = rng.uniform(0, math.tau)
    side = Vector((math.cos(a), math.sin(a), 0))
    top = at + side * (0.25 * h) + Vector((0, 0, h * 0.6))
    tube(G.bm["Wood"], G.woods, [at - Vector((0, 0, 0.6)), at.lerp(top, 0.5) - side * (0.1 * h), top], [0.07 * h, 0.055 * h, 0.04 * h], 4, rng, tone=1.0)
    for s in (-1, 1):
        d = (side * (s * 0.55) + Vector((0, 0, 1))).normalized()
        w = Vector((-side.y, side.x, 0)) * (0.2 * h)
        tipp = top + d * (0.62 * h)
        belly = top + d * (0.26 * h)
        K.quad2(G.kit.bm(key), top, belly + w, tipp, belly - w)
