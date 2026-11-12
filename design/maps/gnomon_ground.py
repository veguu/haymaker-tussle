"""Gnomon's ground (user brief 2026-11-11 b, two references): an illustrated meadow painted INTO the floor.

Image 2 gives the treatment (soft hand-painted meadow, fine strokes, gentle variation), image 1 the MAIN ARENA's
palette (subdued natural greens, sandy earth with pale pebbles). Sampled from image 1 (sRGB): deep 58,108,48;
shade 69,122,53; mid 84,138,57; light 97,150,61; highlight 117,155,75; earth 142,132,84 / 176,161,104 /
206,192,128.

Pure numpy (no bpy at import), so `python ground_preview.py` can look at a patch in seconds.

- meadow(X, Y): the arena's colour, height and roughness in studs (Blender x, y). Broad soft patches of lighter and
  deeper green, a painterly mid-scale mottle, painted grass clumps (dark stroke under a light stroke, radiating),
  loose single strokes, and a few worn patches of sandy earth with pebbles whose edges the strokes break up. No
  painted shadows: the scene's sun casts those.
- detail_tile(px, studs): a SEAMLESS overlay of fine strokes (white and black with alpha) laid over the floor in
  Studio as a Texture at `DETAIL_STUDS` per tile, so the ground keeps its brushwork right under the camera where the
  1024-px tile (8 px a stud) would blur. Luminance only, so it suits grass and earth alike.
- ISLE palettes: each decorative islet's ground, grass, bushes and flowers follow its own tree (style.PAL keys).
"""
import math

import numpy as np

import paint as P

# --- the main arena's palette (image 1), linear ---------------------------------------------------
G = {
    # 2026-11-12 lighting pass (user, Genshin-style daylight): under the brighter sun the old even mid-green read as
    # one flat lime field. Now a wider HUE range: warm sunlit yellow-greens against cool blue-green shade, slightly
    # less saturated, so the light carries the freshness and the ground keeps its variation and brushwork.
    "deep": P.rgb(50, 96, 60),
    "shade": P.rgb(64, 116, 70),
    "mid": P.rgb(90, 136, 62),
    "light": P.rgb(124, 158, 70),
    "high": P.rgb(148, 172, 84),
    "stroke_dark": P.rgb(52, 98, 54),
    "stroke_light": P.rgb(142, 172, 88),
    "earth_dark": P.rgb(128, 112, 74),
    "earth": P.rgb(170, 154, 100),
    "earth_light": P.rgb(204, 189, 128),
    "pebble": P.rgb(218, 206, 170),
    "pebble_dark": P.rgb(120, 104, 74),
}

# the turf_field keys style.py's rim, lip and caps read, for the arena (image 1's greens)
ARENA_PAL = {
    "leaf": P.rgb(90, 136, 62), "warm": P.rgb(118, 154, 68), "cool": P.rgb(66, 118, 70),
    "lip": P.rgb(104, 150, 66), "lip_hi": P.rgb(138, 170, 86),
    "drape": P.rgb(60, 108, 56), "drape_dark": P.rgb(44, 84, 48),
}
LIP_ROWS = [(128, 168, 82), (96, 148, 62), (80, 134, 55), (60, 108, 50), (44, 84, 42)]

# --- per-islet palettes: each islet follows its tree (kit leaf averages, sRGB) --------------------------------
# Tree_A mid green, Tree_B deep cool green, Tree_C lime, Tree_D pale olive, Tree_E bright green.
ISLES = {
    # name: (tree, ground keys, grass tint (sRGB, tuft tips), bush tint, flowers)
    "lime": dict(tree="Tree_C", leaf=(132, 160, 70), warm=(150, 168, 74), cool=(116, 150, 66), lip=(156, 176, 84),
                 drape=(98, 124, 52), drape_dark=(74, 98, 44), grass=(172, 196, 88), bush=(236, 246, 200),
                 flowers=("Flowers_Daisy_Big", "Flowers_Tulip", "Flowers_Daisy_Small")),
    "cool": dict(tree="Tree_B", leaf=(62, 118, 88), warm=(70, 128, 92), cool=(54, 106, 88), lip=(84, 138, 104),
                 drape=(46, 92, 74), drape_dark=(34, 72, 62), grass=(104, 168, 124), bush=(208, 236, 226),
                 flowers=("Flowers_Bell", "Flowers_Lily", "Flowers_Daisy_Small")),
    "olive": dict(tree="Tree_D", leaf=(124, 140, 76), warm=(140, 148, 80), cool=(108, 128, 72), lip=(150, 160, 92),
                  drape=(92, 106, 58), drape_dark=(70, 82, 48), grass=(176, 184, 108), bush=(240, 236, 206),
                  flowers=("Flowers_Coral", "Flowers_Tulip", "Flowers_Daisy_Big")),
    "bright": dict(tree="Tree_E", leaf=(86, 150, 62), warm=(100, 160, 66), cool=(72, 136, 60), lip=(112, 168, 76),
                   drape=(60, 112, 50), drape_dark=(44, 88, 42), grass=(136, 204, 98), bush=(226, 250, 214),
                   flowers=("Flowers_Daisy_Small", "Flowers_Coral", "Flowers_Lily")),
    "mid": dict(tree="Tree_A", leaf=(84, 132, 64), warm=(96, 140, 66), cool=(72, 120, 62), lip=(108, 150, 76),
                drape=(60, 104, 52), drape_dark=(44, 82, 44), grass=(134, 184, 102), bush=(230, 242, 218),
                flowers=("Flowers_Lily", "Flowers_Bell", "Flowers_Daisy_Big")),
}
# islet cap centres (the layout coordinates gnomon.py builds them at, before push_backdrop) -> palette
ISLE_AT = [
    ((232, 108), "lime"),  # north-east grove
    ((-300, -150), "cool"),  # south-west hollow log
    ((-250, 46), "olive"),  # west, the tall pair
    ((-20, 222), "bright"),  # north, the pennant frame
    ((-280, -430), "mid"),  # far south-west
    ((-40, 480), "cool"),  # far north grove island (hazed: deep cool so it recedes)
]


ISLE_REACH = 90.0  # studs: anything further from every planted islet (sundial, launch isle, fragments) keeps the arena's


def isle_of(x, y, reach=ISLE_REACH):
    """The palette name for a point in the backdrop's layout coordinates (nearest planted islet's centre), or None
    when no planted islet is within `reach`."""
    best, name = 1e18, None
    for (cx, cy), n in ISLE_AT:
        d = (x - cx) ** 2 + (y - cy) ** 2
        if d < best:
            best, name = d, n
    return name if best <= reach * reach else None


def isle_ground(name):
    """The meadow keys (as G, linear) for one islet palette, plus its lip and skirt colours."""
    s = ISLES[name]
    leaf, warm, cool, lip = (np.array(s[k], float) for k in ("leaf", "warm", "cool", "lip"))
    drape, dark = np.array(s["drape"], float), np.array(s["drape_dark"], float)
    srgb = {
        "mid": leaf, "light": warm, "shade": cool, "deep": drape * 1.08, "high": lip,
        "stroke_dark": drape, "stroke_light": np.minimum(lip * 1.06, 255),
        "lip": lip, "drape": drape, "drape_dark": dark,
    }
    return {k: P.rgb(*v) for k, v in srgb.items()}


# --- strokes ----------------------------------------------------------------------------------------
UPWARD = math.pi / 2  # painted blades lean this way in texture space (image 1: tips up), with a wide spread


def _stroke(X, Y, bx, by, ang, length, width):
    """Coverage of one tapered, slightly curled stroke from (bx, by) along `ang` (arrays broadcast), 0..1."""
    dx, dy = np.cos(ang), np.sin(ang)
    rx, ry = X - bx, Y - by
    t = (rx * dx + ry * dy) / length
    d = -rx * dy + ry * dx - 0.18 * length * np.clip(t, 0, 1) ** 2  # a gentle curl toward one side
    w = width * np.clip(1.0 - t, 0.0, 1.0) ** 0.7 + 1e-4
    body = np.clip((w - np.abs(d)) / (w * 0.6), 0.0, 1.0)
    return body * ((t > 0.0) & (t < 1.0)) * np.clip(t / 0.15, 0.0, 1.0)


def clumps(X, Y, cell, seed, length, width, keep, blades=(3, 5), spread=1.5, period=None):
    """Painted grass clumps: per jittered cell (kept with chance `keep`), a fan of 3-5 blades from one root, leaning
    UPWARD with a wide spread. Returns (dark, light) coverage: each blade's darker copy sits just under it, so the
    fan reads as a lit blade over its own shade. `period` (in cells) wraps the hashes so the result tiles."""
    dark = np.zeros(X.shape)
    light = np.zeros(X.shape)
    gi, gj = np.floor(X / cell), np.floor(Y / cell)
    nmax = blades[1]
    for di in (-1, 0, 1):
        for dj in (-1, 0):
            ci, cj = gi + di, gj + dj
            hi, hj = (np.mod(ci, period), np.mod(cj, period)) if period else (ci, cj)
            h = [P.hash01(seed + k, hi, hj) for k in range(5)]
            on = h[4] < keep
            cx = (ci + 0.15 + 0.7 * h[0]) * cell
            cy = (cj + 0.15 + 0.7 * h[1]) * cell
            n = blades[0] + np.floor(h[2] * (blades[1] - blades[0] + 1))
            lean = UPWARD + (h[3] - 0.5) * 0.9
            for b in range(nmax):
                hb = P.hash01(seed + 50 + b, hi, hj)
                use = on & (b < n)
                side = b / max(nmax - 1, 1) - 0.5
                ang = lean + side * spread + (hb - 0.5) * 0.35
                L = length * (0.6 + 0.6 * hb) * (1.0 - 0.5 * abs(side))
                lt = _stroke(X, Y, cx, cy, ang, L, width) * use
                dk = _stroke(X, Y, cx + 0.04, cy - 0.07, ang, L * 1.02, width * 1.35) * use
                light = np.maximum(light, lt)
                dark = np.maximum(dark, dk)
    return dark, light


def singles(X, Y, cell, seed, length, width, keep, period=None):
    """Loose single blades leaning UPWARD: the fine grain between clumps. Coverage (dark, light)."""
    dark = np.zeros(X.shape)
    light = np.zeros(X.shape)
    gi, gj = np.floor(X / cell), np.floor(Y / cell)
    for di in (-1, 0, 1):
        for dj in (-1, 0):
            ci, cj = gi + di, gj + dj
            hi, hj = (np.mod(ci, period), np.mod(cj, period)) if period else (ci, cj)
            h = [P.hash01(seed + k, hi, hj) for k in range(5)]
            on = h[4] < keep
            cx, cy = (ci + h[0]) * cell, (cj + h[1]) * cell
            ang = UPWARD + (h[2] - 0.5) * 1.8
            L = length * (0.6 + 0.8 * h[3])
            s = _stroke(X, Y, cx, cy, ang, L, width) * on
            dark = np.maximum(dark, s * (h[3] < 0.45))
            light = np.maximum(light, s * (h[3] >= 0.45))
    return dark, light


def mounds(X, Y, cell, seed, keep, radius):
    """Mid-scale grass masses, as image 1 paints them: soft ragged blobs, lit on their upper side and shaded on
    the lower. Returns (lit, shade) 0..1."""
    lit = np.zeros(X.shape)
    shade = np.zeros(X.shape)
    gi, gj = np.floor(X / cell), np.floor(Y / cell)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            ci, cj = gi + di, gj + dj
            h = [P.hash01(seed + k, ci, cj) for k in range(5)]
            on = h[4] < keep
            cx, cy = (ci + 0.2 + 0.6 * h[0]) * cell, (cj + 0.2 + 0.6 * h[1]) * cell
            r = radius * (0.6 + 0.7 * h[2])
            rx, ry = (X - cx) / 1.35, Y - cy
            a = np.arctan2(ry, rx)
            rag = 1.0 + 0.16 * np.sin(a * 7 + h[3] * 20) + 0.08 * np.sin(a * 13 + h[3] * 7)
            dd = np.hypot(rx, ry) / (r * rag)
            body = P.smoothstep(1.0, 0.75, dd) * on
            top = P.smoothstep(-0.2, 0.6, ry / r)
            lit = np.maximum(lit, body * top)
            under = P.smoothstep(1.05, 0.8, np.hypot(rx, ry + 0.25 * r) / (r * rag)) * on * (1 - top)
            shade = np.maximum(shade, under * (1 - body * top))
    return lit, shade


# --- the arena's meadow -----------------------------------------------------------------------------
def earth_mask(X, Y):
    """A few small worn patches of sandy earth (about 4% of the field, broken up), ragged at the edge.
    (0..1, the raw field). 2026-11-11 b review: 13% in big blotches read as camouflage; now 4%."""
    f = P.fbm2(X * 0.018 + 31, Y * 0.018 - 7, 401, 4)
    f2 = P.fbm2(X * 0.07 - 3, Y * 0.07 + 11, 402, 3)
    edge = 0.07 * (P.fbm2(X * 0.5, Y * 0.5, 403, 2) - 0.5)
    v = f + 0.6 * (f2 - 0.5) + edge
    return P.smoothstep(0.76, 0.772, v), v


def meadow(X, Y, earth=True, pal=None):
    """The arena floor: (colour linear (...,3), height studs, roughness). `pal` swaps the greens (an islet's
    isle_ground); the earth always uses the arena's sand."""
    g = pal or G
    # broad soft swaths (about a hundred studs): warm sunlit yellow-green against cool blue-green, graded softly
    # like painted areas; then medium patches of lighter and deeper green with soft but present edges; a mottle
    w0 = P.fbm2(X * 0.009 + 13, Y * 0.009 - 5, 300, 3)
    w1 = P.fbm2(X * 0.016, Y * 0.016, 301, 4)
    w2 = P.fbm2(X * 0.031 + 40, Y * 0.031 - 12, 302, 3)
    wob = 0.06 * (P.fbm2(X * 0.16, Y * 0.16, 303, 2) - 0.5)
    col = P.fill(X.shape, g["mid"])
    col = P.mix(col, g["light"], 0.8 * P.smoothstep(0.46, 0.64, w0 + wob))
    col = P.mix(col, g["shade"], 0.7 * P.smoothstep(0.54, 0.36, w0 - wob))
    col = P.mix(col, g["high"], 0.45 * P.smoothstep(0.55, 0.60, w1 + wob))
    col = P.mix(col, g["shade"], 0.55 * P.smoothstep(0.56, 0.60, w2 - wob))
    col = P.mix(col, g["deep"], 0.4 * P.smoothstep(0.65, 0.69, w2 - wob))
    col = col * (1.0 + 0.12 * (P.fbm2(X * 0.22, Y * 0.22, 304, 3) - 0.5))[..., None]
    # painted grass masses (lit tops, shaded undersides), two sizes
    for cell, keep, radius, seed, k in ((4.2, 0.55, 1.9, 320, 1.0), (2.3, 0.5, 1.05, 330, 0.8)):
        lit, shade = mounds(X, Y, cell, seed, keep, radius)
        col = P.mix(col, g["shade"], 0.62 * k * shade)
        col = P.mix(col, g["light"], 0.5 * k * lit)
    height = np.zeros(X.shape)
    E = np.zeros(X.shape)
    if earth:
        E, v = earth_mask(X, Y)
        e1 = P.fbm2(X * 0.09 + 5, Y * 0.09, 405, 3)
        ecol = P.mix(P.fill(X.shape, G["earth"]), G["earth_light"], 0.7 * P.smoothstep(0.45, 0.7, e1))
        ecol = P.mix(ecol, G["earth_dark"], 0.3 * P.smoothstep(0.62, 0.78, P.fbm2(X * 0.2, Y * 0.2, 406, 2)))
        # pebbles: pale stones with a darker lower edge, only on earth
        for cell, seed, chance in ((0.8, 410, 0.22), (1.9, 420, 0.35)):
            gi, gj = np.floor(X / cell), np.floor(Y / cell)
            h = [P.hash01(seed + k, gi, gj) for k in range(4)]
            cx, cy = (gi + 0.3 + 0.4 * h[0]) * cell, (gj + 0.3 + 0.4 * h[1]) * cell
            r = (0.05 + 0.11 * h[2]) * (cell / 0.8) ** 0.5
            on = h[3] < chance
            dd = np.hypot((X - cx) / 1.25, Y - cy)
            rim = np.hypot((X - cx - 0.03) / 1.25, Y - cy + 0.05)
            ecol = P.mix(ecol, G["pebble_dark"], 0.55 * np.clip((r * 1.18 - rim) / 0.03, 0, 1) * on)
            ecol = P.mix(ecol, G["pebble"], np.clip((r - dd) / 0.03, 0, 1) * on)
            height = height + 0.06 * np.clip((r - dd) / r, 0, 1) * on * E
        # the grass's own shade just outside the earth, so the turf reads as sitting on it
        rimband = P.smoothstep(0.72, 0.76, v) * (1 - E)
        col = P.mix(col, g["deep"], 0.35 * rimband)
        col = P.mix(col, ecol, E)
        height = height - 0.03 * E
    # painted blades: fans (two sizes) and loose single blades, thinning to strays over the earth
    grass = 1.0 - 0.8 * E
    for cell, length, width, keep, seed, strength in ((1.7, 1.05, 0.11, 0.5, 500, 0.8), (1.0, 0.7, 0.08, 0.5, 520, 0.6)):
        dk, lt = clumps(X, Y, cell, seed, length, width, keep)
        col = P.mix(col, g["stroke_dark"], 0.5 * strength * dk * grass)
        col = P.mix(col, g["stroke_light"], 0.55 * strength * lt * grass)
        height = height + 0.03 * np.maximum(dk, lt) * grass
    dk, lt = singles(X, Y, 0.55, 540, 0.5, 0.06, 0.45)
    col = P.mix(col, g["stroke_dark"], 0.3 * dk * grass)
    col = P.mix(col, g["stroke_light"], 0.3 * lt * grass)
    rough = np.full(X.shape, 0.95)
    return np.clip(col, 0, 1), height, rough


# --- the close-up overlay -----------------------------------------------------------------------------
DETAIL_STUDS = 14.0  # one overlay tile covers this many studs (seamless)


def detail_tile(px=1024, studs=DETAIL_STUDS):
    """A seamless RGBA overlay of fine painted blades (sRGB 0..1): deep-green shade strokes and pale-green lit
    strokes, alpha their strength. Cells are whole numbers per tile and hashed modulo the tile, so the edges meet."""
    xs = (np.arange(px) + 0.5) / px * studs
    X, Y = np.meshgrid(xs, xs)
    cellA, cellB, cellC = studs / 8, studs / 14, studs / 24  # 1.75, 1.0, 0.58 studs
    dkA, ltA = clumps(X, Y, cellA, 600, 1.0, 0.1, 0.45, period=8)
    dkB, ltB = clumps(X, Y, cellB, 620, 0.65, 0.075, 0.5, period=14)
    dkC, ltC = singles(X, Y, cellC, 640, 0.45, 0.05, 0.5, period=24)
    dark = np.maximum.reduce([dkA * 0.9, dkB * 0.8, dkC * 0.6])
    light = np.maximum.reduce([ltA * 0.9, ltB * 0.8, ltC * 0.6])
    a_dark, a_light = 0.34 * dark, 0.30 * light
    alpha = np.clip(a_dark + a_light, 0, 1)
    share = np.where(alpha > 1e-4, a_light / np.maximum(alpha, 1e-4), 0.0)[..., None]
    shade, lit = np.array([46, 92, 40]) / 255, np.array([150, 186, 96]) / 255
    rgba = np.zeros((px, px, 4))
    rgba[..., :3] = shade + (lit - shade) * share
    rgba[..., 3] = alpha
    return rgba


# --- the grass tufts' atlas ------------------------------------------------------------------------------
def tuft_atlas(columns=4, col_px=16, rows=128):
    """The tufts' shared texture as straight RGBA (sRGB, row 0 = the blade TIP). Roblox does not tint a MeshPart's
    texture by its Color; it shows the Color only through the texture's transparent areas. So the tip is clear
    (pure palette colour), a deep green-black fades in toward the root (the blade's own shade), the edges darken a
    little and the midrib carries a faint pale highlight. Each column has its own curve, for variety."""
    img = np.zeros((rows, columns * col_px, 4))
    v = np.linspace(1, 0, rows)[:, None]  # 1 at the tip (top row), 0 at the root
    u = np.linspace(0, 1, col_px)[None, :]
    rib = np.exp(-((u - 0.5) / 0.14) ** 2)
    edge = np.exp(-((np.minimum(u, 1 - u)) / 0.08) ** 2)
    shade = np.array([0.08, 0.14, 0.06])
    pale = np.array([0.94, 0.97, 0.82])
    for c in range(columns):
        dark = (0.52 + 0.04 * c) * (1 - P.smoothstep(0.0, 0.8 - 0.05 * c, v)) + 0.10 * edge
        light = 0.16 * rib * P.smoothstep(0.25, 0.85, v)
        dark = np.clip(dark, 0, 1)
        a = np.clip(dark + light, 0, 1)
        share = np.where(a > 1e-4, light / np.maximum(a, 1e-4), 0.0)[..., None]
        rgb = shade + (pale - shade) * share
        img[:, c * col_px : (c + 1) * col_px, :3] = rgb
        img[:, c * col_px : (c + 1) * col_px, 3] = a
    return img
