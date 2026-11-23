"""Four WALKABLE floor options for the arena suite (owner 2026-11-21: "i want all the MAPS FLOOR texture feel like a
texture that you can walk on ... the floor textures is just NOT it"), painted as seamless tiles in numpy:

    python floor_options.py <out folder>

Why tiles: a whole-tile painted map is about 6-7 px a stud, a smooth airbrushed picture at a fighter's feet. Walkable
ground needs foot-scale detail (stones, joints, cracks, grain), which only a REPEATING layer can give cheaply. In Roblox
each option is one seamless detail image laid over the floor tiles as a `Texture` (StudsPerTile = its tile size,
offsets aligned across tiles), over a low-chroma large-scale colour map (base_<x>.png). Tested 2026-11-21: a Texture
renders across a floor MeshPart's top face. Built-in Roblox materials looked like realistic beach sand.

Writes, per option x in a..d: detail_<x>.png (RGBA, 1024 px, tiles seamlessly), base_<x>.png (2048 px across the oval)
and options.json (tile sizes in studs, notes). Colours: calmer than the first floor (owner's rule: fighters must be the
most saturated thing on screen; the fresh review measured the first floor at the fighters' own hue).
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

N = 1024  # detail tile, px
A_SEMI, B_SEMI = 213.0, 176.0  # the oval


def srgb(*c):
    return np.array(c, dtype=np.float64) / 255.0


def periodic_noise(g, seed, n=N):
    """Value noise on an n x n image, lattice g x g, tiling seamlessly."""
    r = np.random.default_rng(seed).random((g, g))
    x = np.arange(n) * g / n
    i0 = np.floor(x).astype(int)
    f = x - i0
    i1 = (i0 + 1) % g
    f = f * f * (3 - 2 * f)
    fx, fy = f[None, :], f[:, None]
    a, b = r[np.ix_(i0, i0)], r[np.ix_(i0, i1)]
    c, d = r[np.ix_(i1, i0)], r[np.ix_(i1, i1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(g, seed, octaves=4, n=N):
    tot, amp, s = np.zeros((n, n)), 1.0, 0.0
    for k in range(octaves):
        tot += amp * periodic_noise(g * 2 ** k, seed + 17 * k, n)
        s += amp
        amp *= 0.5
    return tot / s


def hash01(*ks):
    """A stable 0..1 per integer key (arrays allowed)."""
    h = np.zeros(np.broadcast(*ks).shape, dtype=np.uint64) + np.uint64(1469598103934665603)
    for k in ks:
        h ^= np.asarray(k, dtype=np.int64).astype(np.uint64) + np.uint64(0x9E3779B97F4A7C15)
        h *= np.uint64(1099511628211)
        h ^= h >> np.uint64(29)
    return (h % np.uint64(1 << 24)).astype(np.float64) / float(1 << 24)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def grid():
    """Pixel centres in tile units 0..1 (x across, y down the image)."""
    u = (np.arange(N) + 0.5) / N
    return np.broadcast_to(u[None, :], (N, N)), np.broadcast_to(u[:, None], (N, N))


def lit_bevel(edge, width, light=0.22, dark=0.28, side=None):
    """Painted bevel: lighter just inside an edge on the lit side, darker on the shade side (side in -1..1)."""
    t = 1.0 - smooth(0.0, width, edge)
    if side is None:
        return 1.0 - dark * t
    return 1.0 + t * (light * np.clip(side, 0, 1) - dark * np.clip(-side, 0, 1))


# --- A: fan-laid setts (reference 20's square) ------------------------------------------------------------------
def option_a(tile=16.0):
    X, Y = grid()
    xs, ys = X * tile, Y * tile  # studs
    R = tile / 2.0  # fan radius: rows R/2 apart, fans R apart, staggered
    h, w, joint = 1.15, 1.35, 0.16  # a sett's depth along the radius, its width along the arc, the joint
    best_cy = np.full(xs.shape, -1e9)
    fx_, fy_ = np.zeros(xs.shape), np.zeros(xs.shape)
    fid = np.zeros(xs.shape, dtype=np.int64)
    rows = int(round(tile / (R / 2)))
    cols = int(round(tile / R))
    for j in range(-3, rows + 4):
        cy = j * R / 2
        off = (j % 2) * R / 2
        for i in range(-3, cols + 3):
            cx = i * R + off
            dx, dy = xs - cx, cy - ys  # fans open UP the image (dy > 0)
            inside = (dx * dx + dy * dy <= R * R) & (dy >= 0) & (cy > best_cy)
            best_cy = np.where(inside, cy, best_cy)
            fx_ = np.where(inside, dx, fx_)
            fy_ = np.where(inside, dy, fy_)
            fid = np.where(inside, (j % rows) * 1000 + (i % cols), fid)
    # where a later (lower) fan covers this one, the boundary is a joint too: distance to every later fan's half-disc
    over = np.full(xs.shape, 1e9)
    for j in range(-3, rows + 4):
        cy = j * R / 2
        off = (j % 2) * R / 2
        for i in range(-3, cols + 3):
            cx = i * R + off
            dx, dy = xs - cx, cy - ys
            ro = np.hypot(dx, dy)
            d = np.where(dy >= 0, ro - R, np.where(np.abs(dx) <= R, -dy, np.hypot(np.abs(dx) - R, -dy)))
            over = np.where(cy > best_cy, np.minimum(over, d), over)
    r = np.hypot(fx_, fy_)
    th = np.arctan2(fy_, fx_)  # 0..pi
    ring = np.floor(r / h)
    rr = r - ring * h
    rmid = (ring + 0.5) * h
    n_in_ring = np.maximum(1, np.round(math.pi * rmid / w))
    seg = th / math.pi * n_in_ring + hash01(fid, ring) * 0.6
    idx = np.floor(seg)
    along = (seg - idx) * (math.pi * rmid / n_in_ring)
    width_here = math.pi * rmid / n_in_ring
    edge = np.minimum.reduce([rr, h - rr, along, width_here - along, R - r, np.maximum(over, 0.0)])
    key = hash01(fid, ring, idx)
    tone = 0.82 + 0.3 * key
    pal = [srgb(196, 184, 164), srgb(176, 160, 142), srgb(186, 164, 140), srgb(160, 148, 134), srgb(204, 190, 160)]
    pick = np.floor(hash01(fid, ring, idx, 7) * len(pal)).astype(int) % len(pal)
    col = np.stack(pal)[pick] * tone[..., None]
    # rounded tops: lit toward the sun (up-left of the image), shade the other way
    lx = -(along - width_here / 2) / (width_here / 2)
    ly = (rr - h / 2) / (h / 2)
    shade = 1.0 + 0.16 * (0.6 * ly + 0.4 * lx) * smooth(0.0, 0.5, edge)
    col *= shade[..., None]
    col *= lit_bevel(edge, 0.22, dark=0.3)[..., None]
    col *= (0.93 + 0.14 * fbm(32, 11))[..., None]  # grain
    groutc = srgb(118, 104, 90) * (0.85 + 0.3 * fbm(16, 12))[..., None]
    g = 1.0 - smooth(joint * 0.5, joint, edge)
    col = col * (1 - g[..., None]) + groutc * g[..., None]
    dust = smooth(0.55, 0.8, fbm(4, 13))
    col = col * (1 - 0.25 * dust[..., None]) + srgb(214, 200, 176) * 0.25 * dust[..., None]
    alpha = np.full(xs.shape, 0.92)
    return col, alpha, tile, "Fan-laid setts: small sandstone setts in arcs, painted shading, dusty patches (like reference 20's square)."


# --- B: sawn quarry slabs ---------------------------------------------------------------------------------------
def option_b(tile=48.0):
    X, Y = grid()
    xs, ys = X * tile, Y * tile
    rows_h = [11.0, 13.0, 12.0, 12.0]
    tops = np.cumsum([0.0] + rows_h)
    row = np.searchsorted(tops, ys, side="right") - 1
    row = np.clip(row, 0, len(rows_h) - 1)
    y0 = tops[row]
    hrow = np.array(rows_h)[row]
    vy = ys - y0
    rng = np.random.default_rng(21)
    edge_x = np.zeros(xs.shape)
    local_x = np.zeros(xs.shape)  # studs past the slab's own left cut (carries across the tile's wrap)
    slab = np.zeros(xs.shape, dtype=np.int64)
    for k in range(len(rows_h)):
        cuts = [0.0]
        while True:
            nxt = cuts[-1] + rng.uniform(11.0, 21.0)
            if tile - nxt < 9.0:
                break
            cuts.append(nxt)
        cuts = np.array(cuts) + rng.uniform(0, tile)
        cuts = np.sort(np.mod(cuts, tile))
        m = row == k
        xv = xs[m]
        d = np.mod(xv[:, None] - cuts[None, :], tile)  # distance past each cut
        i = np.argmin(d, axis=1)
        past = d[np.arange(len(xv)), i]
        nxt_cut = cuts[(i + 1) % len(cuts)]
        before = np.mod(nxt_cut - xv, tile)
        edge_x[m] = np.minimum(past, before)
        local_x[m] = past
        slab[m] = k * 100 + i
    edge = np.minimum.reduce([edge_x, vy, hrow - vy])
    key = hash01(slab)
    pal = [srgb(188, 176, 158), srgb(174, 156, 140), srgb(196, 182, 156), srgb(164, 150, 136), srgb(182, 160, 132)]
    pick = np.floor(hash01(slab, 3) * len(pal)).astype(int) % len(pal)
    col = np.stack(pal)[pick] * (0.9 + 0.16 * key)[..., None]
    # tooling: fine parallel strokes at each slab's own angle (the saw and the claw chisel), soft
    ang = hash01(slab, 5) * math.pi
    s = (local_x * np.cos(ang) + vy * np.sin(ang)) / 0.55
    tool = 0.5 + 0.5 * np.sin(s * 2 * math.pi + 3.0 * fbm(8, 22))
    col *= (1.0 - 0.07 * tool * smooth(0.3, 0.9, fbm(6, 23)))[..., None]
    col *= (0.94 + 0.12 * fbm(24, 24))[..., None]
    # bevel: the joint's lit and shaded lips
    lit = np.where(vy < hrow / 2, 1.0, -1.0)
    col *= lit_bevel(edge, 0.45, light=0.12, dark=0.22, side=lit * 0.7)[..., None]
    # chipped corners and a few scuffs
    chip = smooth(0.62, 0.7, fbm(12, 25)) * (1 - smooth(0.0, 1.2, edge))
    col *= (1 - 0.25 * chip)[..., None]
    joint = 0.35
    g = 1.0 - smooth(joint * 0.45, joint, edge)
    groutc = srgb(120, 108, 94) * (0.85 + 0.3 * fbm(16, 26))[..., None]
    col = col * (1 - g[..., None]) + groutc * g[..., None]
    dust = smooth(0.58, 0.82, fbm(3, 27))
    col = col * (1 - 0.3 * dust[..., None]) + srgb(220, 210, 190) * 0.3 * dust[..., None]
    alpha = np.full(xs.shape, 0.9)
    return col, alpha, tile, "Sawn quarry bed: big staggered sandstone slabs with tool marks, chipped corners and chalk dust; dark worn joints, no thin lines."


# --- C: weathered bedrock strata ----------------------------------------------------------------------------------
def draw_cracks(tile, seed, count, px_per_stud):
    """Distance (studs) to the nearest crack: random-walk polylines with a branch or two, wrapped round the tile."""
    rng = np.random.default_rng(seed)
    dist = np.full((N, N), 1e9)
    X, Y = grid()
    xs, ys = X * tile, Y * tile
    segs = []
    for _ in range(count):
        p = rng.uniform(0, tile, 2)
        a = rng.uniform(0, 2 * math.pi)
        for _step in range(rng.integers(5, 11)):
            a += rng.normal(0, 0.55)
            q = p + rng.uniform(0.8, 2.2) * np.array([math.cos(a), math.sin(a)])
            segs.append((p.copy(), q.copy()))
            if rng.random() < 0.18:
                b = a + rng.choice([-1, 1]) * rng.uniform(0.6, 1.2)
                br = q + rng.uniform(0.6, 1.4) * np.array([math.cos(b), math.sin(b)])
                segs.append((q.copy(), br))
            p = q
    for p, q in segs:
        for ox in (-tile, 0, tile):
            for oy in (-tile, 0, tile):
                a_, b_ = p + (ox, oy), q + (ox, oy)
                lo = np.minimum(a_, b_) - 0.6
                hi = np.maximum(a_, b_) + 0.6
                if hi[0] < 0 or hi[1] < 0 or lo[0] > tile or lo[1] > tile:
                    continue
                c0, c1 = int(max(0, lo[0] * px_per_stud)), int(min(N, hi[0] * px_per_stud + 1))
                r0, r1 = int(max(0, lo[1] * px_per_stud)), int(min(N, hi[1] * px_per_stud + 1))
                sx, sy = xs[r0:r1, c0:c1], ys[r0:r1, c0:c1]
                d = b_ - a_
                L2 = max(1e-9, float(d @ d))
                t = np.clip(((sx - a_[0]) * d[0] + (sy - a_[1]) * d[1]) / L2, 0, 1)
                dd = np.hypot(sx - (a_[0] + t * d[0]), sy - (a_[1] + t * d[1]))
                dist[r0:r1, c0:c1] = np.minimum(dist[r0:r1, c0:c1], dd)
    return dist


def option_c(tile=32.0):
    """Natural bedrock: the strata (base map) show through; this layer adds what feet meet: a coarse rock grain with
    lit and shaded flecks, shallow scoops, thin brown cracks, rubble in clusters and chalk dust."""
    X, Y = grid()
    xs, ys = X * tile, Y * tile
    pps = N / tile
    col = np.zeros((N, N, 3))
    alpha = np.zeros((N, N))
    # coarse grain: lit flecks and shaded flecks at a few px each, so the rock reads as rough stone up close
    g1, g2 = fbm(96, 71, 2), fbm(48, 72, 3)
    light = smooth(0.6, 0.78, g1)
    dark = smooth(0.6, 0.8, 1 - g2)
    col = col + srgb(224, 214, 196) * light[..., None]
    alpha = np.maximum(alpha, 0.35 * light)
    col = np.where((dark > light)[..., None], srgb(120, 106, 94), col)
    alpha = np.maximum(alpha, 0.3 * dark)
    # shallow scoops: soft darker hollows a few studs across, each lit on its far rim
    scoop = smooth(0.62, 0.8, fbm(6, 73))
    col = np.where((0.25 * scoop > alpha)[..., None], srgb(132, 118, 104), col)
    alpha = np.maximum(alpha, 0.25 * scoop)
    # thin brown cracks, few
    crack = draw_cracks(tile, 32, 4, pps)
    wide = 0.05 + 0.05 * fbm(8, 34)
    core = 1.0 - smooth(wide * 0.6, wide, crack)
    col = col * (1 - core[..., None]) + srgb(104, 86, 72) * core[..., None]
    alpha = np.maximum(alpha, 0.85 * core)
    # rubble in clusters: chips only where a cluster noise is high
    rng = np.random.default_rng(74)
    clus = fbm(4, 75)
    for _ in range(260):
        cx, cy = rng.uniform(0, tile), rng.uniform(0, tile)
        if clus[int(cy * pps) % N, int(cx * pps) % N] < 0.58:
            continue
        r = rng.uniform(0.08, 0.3)
        dx = np.mod(xs - cx + tile / 2, tile) - tile / 2
        dy = np.mod(ys - cy + tile / 2, tile) - tile / 2
        d = np.hypot(dx, dy * 1.3)
        inside = 1.0 - smooth(r * 0.75, r, d)
        if not inside.any():
            continue
        lit = np.clip(-(dx + dy) / (r * 1.4), -1, 1)
        c = srgb(196, 184, 166) * (1 + 0.16 * lit)[..., None]
        sh = (1.0 - smooth(r, r * 1.5, np.hypot(dx - r * 0.3, dy * 1.3 - r * 0.3))) * (1 - inside)
        col = col * (1 - inside[..., None]) + c * inside[..., None]
        col = col * (1 - sh[..., None]) + srgb(112, 98, 86) * sh[..., None]
        alpha = np.maximum(alpha, np.maximum(inside, 0.5 * sh))
    dust = smooth(0.6, 0.85, fbm(3, 76))
    col = col * (1 - dust[..., None]) + srgb(226, 216, 198) * dust[..., None] * 1.0
    alpha = np.maximum(alpha, 0.3 * dust)
    return col, alpha, tile, "Weathered bedrock: the strata kept, calmer, with rough grain, scoops, thin cracks, rubble clusters and chalk dust at foot scale."


# --- D: big irregular flagstones (crazy paving) --------------------------------------------------------------------
def option_d(tile=40.0):
    """Polygonal flags about 8 studs across (Voronoi on a jittered 3 x 3 grid, so straight edges), each its own
    shade with a painted bevel, joints filled with packed sand a little darker than the stone (a soft band, never a
    light line). 5 x 5 seeds a 40-stud tile, jittered wide, so the repeat is hard to see."""
    X, Y = grid()
    xs, ys = X * tile, Y * tile
    G = 5
    cell = tile / G
    gx, gy = np.floor(xs / cell).astype(int), np.floor(ys / cell).astype(int)
    f1, f2 = np.full(xs.shape, 1e9), np.full(xs.shape, 1e9)
    sid = np.zeros(xs.shape, dtype=np.int64)
    vx, vy = np.zeros(xs.shape), np.zeros(xs.shape)
    for di in (-2, -1, 0, 1, 2):
        for dj in (-2, -1, 0, 1, 2):
            ci, cj = (gx + di) % G, (gy + dj) % G
            px_ = (gx + di + 0.04 + 0.92 * hash01(ci, cj, 2)) * cell
            py_ = (gy + dj + 0.04 + 0.92 * hash01(ci, cj, 3)) * cell
            dx, dy = xs - px_, ys - py_
            d = np.hypot(dx, dy)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            sid = np.where(closer, ci * 100 + cj, sid)
            vx, vy = np.where(closer, dx, vx), np.where(closer, dy, vy)
            f1 = np.where(closer, d, f1)
    edge = (f2 - f1) * 0.5  # about the distance to the flag's border
    pal = [srgb(188, 176, 158), srgb(172, 158, 144), srgb(194, 180, 152), srgb(164, 150, 138), srgb(180, 162, 140)]
    pick = np.floor(hash01(sid, 1) * len(pal)).astype(int) % len(pal)
    col = np.stack(pal)[pick] * (0.9 + 0.16 * hash01(sid, 9))[..., None]
    col *= (0.94 + 0.12 * fbm(32, 61))[..., None]
    col *= (1.0 - 0.06 * smooth(0.55, 0.75, fbm(10, 62)))[..., None]  # worn patches
    lit = np.clip(-(vx + vy) / (cell * 0.6), -1, 1)
    col *= lit_bevel(edge, 0.5, light=0.14, dark=0.2, side=lit)[..., None]
    joint = 0.42 * (0.8 + 0.4 * fbm(16, 63))
    g = 1.0 - smooth(joint * 0.5, joint, edge)
    sand = srgb(156, 142, 124) * (0.9 + 0.2 * fbm(48, 64))[..., None]
    col = col * (1 - g[..., None]) + sand * g[..., None]
    dust = smooth(0.58, 0.85, fbm(3, 65))
    col = col * (1 - 0.25 * dust[..., None]) + srgb(214, 202, 182) * 0.25 * dust[..., None]
    alpha = np.full(xs.shape, 0.92)
    return col, alpha, tile, "Big flagstones: irregular cut stone flags about 8 studs across, painted bevels, joints filled with packed sand (no dark lines)."


# --- the large-scale colour under each option (the floor tiles' own map) -----------------------------------------
def base_map(kind, n=2048):
    u = (np.arange(n) + 0.5) / n
    X = (u[None, :] * 2 - 1) * A_SEMI
    Z = (u[:, None] * 2 - 1) * B_SEMI
    X, Z = np.broadcast_to(X, (n, n)), np.broadcast_to(Z, (n, n))
    big = fbm(4, 51, 3, n)
    if kind == "c":
        pal = np.stack([srgb(190, 168, 144), srgb(166, 142, 128), srgb(200, 186, 160), srgb(150, 130, 116), srgb(194, 162, 120), srgb(176, 158, 140)])
        fold = np.abs(np.mod(X / 140.0 + big, 2.0) - 1.0) * 70.0
        s = Z * 0.9 + X * 0.3 + fold + (fbm(6, 52, 3, n) - 0.5) * 50.0
        k = np.floor(s / 18.0)
        f = s / 18.0 - k
        i0 = (hash01(k.astype(np.int64)) * len(pal)).astype(int) % len(pal)
        i1 = (hash01(k.astype(np.int64) + 1) * len(pal)).astype(int) % len(pal)
        t = smooth(0.9, 1.0, f)[..., None]
        col = pal[i0] * (1 - t) + pal[i1] * t
        col *= (0.95 + 0.1 * hash01(k.astype(np.int64), 3))[..., None]
    else:
        tint = {"a": srgb(186, 172, 152), "b": srgb(182, 168, 150), "d": srgb(184, 170, 150)}[kind]
        col = tint * (0.9 + 0.2 * big)[..., None]
    rho = np.sqrt((X / A_SEMI) ** 2 + (Z / B_SEMI) ** 2)
    col *= (1 - 0.25 * smooth(0.96, 1.0, rho))[..., None]
    return col


def save(path, rgb, alpha=None):
    a = np.clip(rgb, 0, 1)
    img = (a * 255 + 0.5).astype(np.uint8)
    if alpha is not None:
        img = np.dstack([img, (np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8)])
    Image.fromarray(img).save(path)


def seam_error(rgb):
    """How different the tile's opposite edges are, as a mean 0..255 step (0 = seamless)."""
    return float(np.abs(rgb[:, 0] - rgb[:, -1]).mean() * 255), float(np.abs(rgb[0] - rgb[-1]).mean() * 255)


def main(out):
    os.makedirs(out, exist_ok=True)
    meta = {}
    for name, fn in (("a", option_a), ("b", option_b), ("c", option_c), ("d", option_d)):
        col, alpha, tile, note = fn()
        save(os.path.join(out, f"detail_{name}.png"), col, alpha)
        save(os.path.join(out, f"base_{name}.png"), base_map(name))
        # a 3 x 3 preview, to see the repeat
        prev = np.tile(np.clip(col, 0, 1), (3, 3, 1))[::3, ::3]
        save(os.path.join(out, f"repeat_{name}.png"), prev)
        meta[name] = {"tile_studs": tile, "px_per_stud": round(N / tile, 1), "note": note, "edge_step": seam_error(col)}
        print(name, meta[name], flush=True)
    json.dump(meta, open(os.path.join(out, "options.json"), "w", encoding="utf-8", newline="\n"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "suite", "floor_options"))
