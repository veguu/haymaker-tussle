"""Map 5 of the suite, "The Solar Disc" (Overgrown Sundial Ruins, from Gnomon's sundial). DESIGN BLOCKOUT 2026-11-21:
NOT APPROVED, NOT BUILT.

    blender -b --factory-startup -P sundial.py -- <out folder> --dry --no-render

IDEA (five words): fighting on an ancient sundial. The arena is one colossal carved stone disc, the dial of a ruined
sky observatory, overgrown and crumbling, its bronze instrument still turning above the ruins.
  - Floor: ONE monolithic disc of mid-tone grey-cream stone (no paving joints: the lobby is paved, and a ring of curved
    slabs would read as a target), weathered in broad warm and cool stains, soft lichen blooms, moss in a few broad
    hollows; near the edge a worn, broken "hour band" of darker stone carrying twelve big bronze hour glyphs about 30
    studs across, with teal patina and moss over parts of them (original symbols: sun, moon, waves, peak, comet,
    spiral, leaf, crown, eye, hourglass, bird, sprout; none like a controller button), and THE HOUR HAND: the
    gnomon's shadow painted as one broad soft wedge from the middle to the hour band (nothing stands on the floor).
    Moss only out near the rim. No cracks and no thin rings (both read as pitch lines from a fighter's eye); no clean
    ring and no centre medallion (the lobby has those).
  - Edge: the disc's side is a thick bronze band streaked with teal patina, over a stone course; under it the disc
    overhangs a ruined round arcade (piers and arches, some broken) wrapping a masonry drum, ivy curtains hanging
    from the band over the arches, a second smaller arcade tier, then a broken faceted foot with tumbled blocks set
    into it (none loose: loose blocks are the quarry's).
  - Background (its own layout: armillary north, colonnade north-west, aqueduct east, temple west, ruins far east
    and west too): ruin islands of the same masonry, their tops old mossy paving (not grass): a ring of chunky
    columns round a small domed round temple, a temple with a pediment on a stepped platform, a two-tier aqueduct of
    arches running off its island into the sky, an overgrown garden island with weeping trees and broken columns,
    two low ruins off the arena's sides, three far ruins.
  - LANDMARK: the Great Armillary, a bronze armillary sphere about 280 studs across (meridian, equator and ecliptic
    rings, a polar rod, a gold sun at its heart) on a broken round tower, about 390 studs high in all. Its rings
    are their own meshes and turn slowly (three moved parts).
  - Feel: the dial is the round's clock. The twelve glyphs light up gold one by one as the round runs (a colour
    change a few times a round; needs a small hook into the round timer), and the armillary's rings turn (3 moved
    parts, about 15 us a frame).
"""
import os

_d = os.path.dirname(os.path.abspath(__file__))
for _f in ("base.py", "sketch_kit.py"):
    _p = os.path.join(_d, _f)
    exec(compile(open(_p, encoding="utf-8").read(), _p, "exec"))

NAME = "Sundial"
PAL.update(
    {
        "stone_dial": (srgb(222, 216, 202), srgb(242, 238, 226), srgb(156, 152, 150)),
        "stone_ruin": (srgb(214, 204, 184), srgb(236, 228, 210), srgb(150, 142, 134)),
        "stone_ruindk": (srgb(150, 142, 132), srgb(184, 176, 164), srgb(98, 94, 92)),
        "paint_bronze": (srgb(186, 130, 68), srgb(222, 170, 104), srgb(120, 80, 50)),
        "paint_patina": (srgb(86, 166, 152), srgb(132, 202, 186), srgb(52, 110, 106)),
        "leaf_ivy": (srgb(76, 130, 74), srgb(110, 164, 94), srgb(46, 90, 56)),
        "leaf_ivylt": (srgb(118, 160, 86), srgb(152, 192, 110), srgb(78, 116, 64)),
        "leaf_moss": (srgb(132, 156, 92), srgb(164, 186, 116), srgb(90, 112, 66)),
        "stone_flag": (srgb(176, 168, 150), srgb(204, 196, 178), srgb(120, 114, 106)),
        "cloth_gold": (srgb(240, 196, 76), srgb(255, 226, 140), srgb(172, 132, 44)),
        "glow_sun": (srgb(255, 210, 110), srgb(255, 236, 170), srgb(214, 160, 70)),
    }
)

# --- the fighting surface: one weathered stone disc with a ring of bronze hour glyphs ----------------------------------
# mid tones (review 2026-11-21: the first disc measured 181 of 255 and read as fog)
DIAL = {"stone": (153, 142, 120), "warm": (162, 147, 121), "cool": (140, 136, 127), "lichen": (142, 147, 92), "lichen2": (166, 158, 138),
        "moss": (112, 146, 84), "mossdk": (74, 108, 66), "bronze": (190, 136, 72), "bronzedk": (140, 96, 56), "patina": (88, 168, 154),
        "hourband": (121, 110, 92)}
GLYPH_IN = 20.0  # glyph centres this far in from the edge
BAND_IN = 36.0  # the bronze band this far in


def _seg(u, v, ax, ay, bx, by):
    """Distance from (u, v) to the segment a-b (numpy)."""
    px, py = u - ax, v - ay
    dx, dy = bx - ax, by - ay
    t = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0.0, 1.0)
    return np.hypot(px - dx * t, py - dy * t)


def glyph_sdf(k, u, v):
    """Twelve original hour glyphs as distance fields (studs), u along the ring, v outward; ink where < 0."""
    r = np.hypot(u, v)
    kind = k % 12
    if kind == 0:  # sun: a disc, a ring, eight short rays
        ang = np.arctan2(v, u)
        ray = np.abs(np.mod(ang + math.pi / 8, math.pi / 4) - math.pi / 8) * r - 1.1 + 100.0 * ((r < 8.0) | (r > 11.0))
        return np.minimum(np.minimum(r - 3.0, np.abs(r - 6.0) - 1.2), ray)
    if kind == 1:  # crescent moon
        return np.maximum(r - 7.5, -(np.hypot(u - 3.2, v - 1.5) - 6.2))
    if kind == 2:  # two waves
        return np.minimum(np.abs(v - 2.6 - 2.0 * np.sin(u * 0.75)), np.abs(v + 2.6 - 2.0 * np.sin(u * 0.75))) - 1.2 + np.maximum(0.0, np.abs(u) - 8.0)
    if kind == 3:  # a peak
        return np.minimum(_seg(u, v, -8, -6, 0, 6), _seg(u, v, 0, 6, 8, -6)) - 1.6
    if kind == 4:  # a comet: a head and three tapering tails
        head = np.hypot(u - 4.5, v - 4.5) - 3.0
        tails = np.minimum(np.minimum(_seg(u, v, 4.5, 4.5, -8, -8) - 1.4, _seg(u, v, 4.5, 4.5, -3, -9) - 1.0), _seg(u, v, 4.5, 4.5, -9, -3) - 1.0)
        return np.minimum(head, tails)
    if kind == 5:  # a spiral
        ang = np.arctan2(v, u)
        a = 1.3
        d = np.abs(np.mod((r / a - ang) / math.tau + 0.5, 1.0) - 0.5) * math.tau * a
        return np.maximum(d - 1.2, r - 9.0)
    if kind == 6:  # leaf with a midrib
        return np.maximum(np.hypot(u, v / 2.0) - 4.2, 0.6 - np.abs(u))  # the midrib left as stone
    if kind == 7:  # crown
        return np.minimum(np.minimum(_seg(u, v, -7, -5, 7, -5), _seg(u, v, -7, -5, -7, 4)), np.minimum(np.minimum(_seg(u, v, 7, -5, 7, 4), _seg(u, v, -7, 4, -3.5, 0)), np.minimum(_seg(u, v, -3.5, 0, 0, 5), np.minimum(_seg(u, v, 0, 5, 3.5, 0), _seg(u, v, 3.5, 0, 7, 4))))) - 1.4
    if kind == 8:  # an eye of the sky: an almond with a heart
        return np.minimum(np.abs(np.hypot(u / 1.7, v) - 4.2) - 0.9, r - 2.0)
    if kind == 9:  # hourglass
        return np.minimum(np.minimum(_seg(u, v, -6, 7, 6, 7), _seg(u, v, -6, -7, 6, -7)), np.minimum(_seg(u, v, -6, 7, 6, -7), _seg(u, v, 6, 7, -6, -7))) - 1.4
    if kind == 10:  # a bird
        return np.minimum(np.abs(np.hypot(u + 4, v - 3) - 4.5) - 1.2 + 10 * (v < 2.5), np.abs(np.hypot(u - 4, v - 3) - 4.5) - 1.2 + 10 * (v < 2.5))
    stem = _seg(u, v, 0, -8, 0, 3) - 1.3  # a sprout: a stem and two leaves
    return np.minimum(stem, np.minimum(np.hypot((u + 3.6) / 1.9, (v - 4.0) / 1.0) - 2.0, np.hypot((u - 3.6) / 1.9, (v - 4.0) / 1.0) - 2.0))


def dial(X, Z):
    c = {k: P.rgb(*v) for k, v in DIAL.items()}
    col = P.fill(X.shape, c["stone"])
    w = P.fbm2(X / 120.0 + 2.0, Z / 120.0 + 1.0, 61, 3)
    col = P.mix(col, c["warm"], 0.6 * P.smoothstep(0.45, 0.7, w))
    col = P.mix(col, c["cool"], 0.5 * P.smoothstep(0.55, 0.3, w))
    col = col * (1.0 + 0.08 * (P.fbm2(X / 40.0, Z / 40.0, 63, 3) - 0.5) + 0.04 * (P.fbm2(X / 8.0, Z / 8.0, 65, 2) - 0.5))[..., None]
    li = P.fbm2(X / 22.0 + 5.0, Z / 22.0 - 3.0, 67, 3)
    col = P.mix(col, c["lichen"], 0.45 * P.smoothstep(0.66, 0.8, li))
    li2 = P.fbm2(X / 16.0 - 2.0, Z / 16.0 + 4.0, 69, 3)
    col = P.mix(col, c["lichen2"], 0.4 * P.smoothstep(0.68, 0.82, li2))
    e = edge_dist(X, Z)
    # moss only out near the rim (inside, blotches read as a patchy lawn: re-check 2026-11-21); no cracks
    mo = P.fbm2(X / 60.0 - 4.0, Z / 60.0 + 2.0, 71, 3)
    col = P.mix(col, c["moss"], 0.7 * P.smoothstep(0.5, 0.72, mo) * P.smoothstep(0.35, 0.65, P.fbm2(X / 10.0, Z / 10.0, 72, 2)) * P.smoothstep(70.0, 40.0, e))
    # THE HOUR HAND: the great gnomon's shadow, painted as a broad soft wedge from the middle to the hour band (nothing
    # stands on the floor; the shadow is the dial's own). It points at the eleventh glyph, north-east (z < 0 is north).
    ang = (10.5 / 12.0) * math.tau
    ux, uz = math.cos(ang) * A, math.sin(ang) * B
    L = math.hypot(ux, uz)
    ux, uz = ux / L, uz / L
    along = X * ux + Z * uz
    across = np.abs(-X * uz + Z * ux)
    reach = L - 34.0
    half = 3.0 + 22.0 * np.clip(along / reach, 0.0, 1.0)
    wedge = P.smoothstep(half + 6.0, half - 2.0, across) * P.smoothstep(-4.0, 6.0, along) * P.smoothstep(reach + 8.0, reach - 6.0, along)
    col = col * (1.0 - 0.32 * wedge)[..., None]
    col = P.mix(col, P.rgb(110, 116, 136), 0.18 * wedge)
    # the hour band: a wide zone of darker, warmer stone under the glyphs, soft-edged (a zone, not a line)
    # broken and overgrown, so it reads as old worn stone, not a clean ring (a clean ring read as the lobby's medallion)
    hb = P.smoothstep(GLYPH_IN + 16.0, GLYPH_IN + 8.0, e + (P.fbm2(X / 30.0, Z / 30.0, 74, 2) - 0.5) * 14.0)
    col = P.mix(col, c["hourband"], 0.6 * hb * (0.5 + 0.5 * P.smoothstep(0.3, 0.6, P.fbm2(X / 22.0, Z / 22.0, 76, 3))))
    # the twelve glyphs
    for k in range(12):
        t = (k + 0.5) / 12 * math.tau
        px, pz, nx, nz = oval(t, GLYPH_IN)
        u = (X - px) * (-nz) + (Z - pz) * nx
        v = (X - px) * nx + (Z - pz) * nz
        near = (np.abs(u) < 20) & (np.abs(v) < 20)
        if not near.any():
            continue
        s = glyph_sdf(k, u * 0.55, v * 0.55) / 0.55  # about 30 studs across
        ink = P.smoothstep(0.35, -0.35, s) * near
        ink = ink * (1.0 - 0.85 * P.smoothstep(0.62, 0.75, P.fbm2(X / 9.0 + k, Z / 9.0, 78, 2)))  # moss over parts of some
        g = P.mix(c["bronze"], c["patina"], 0.55 * P.smoothstep(0.5, 0.75, P.fbm2(X / 5.0 + k, Z / 5.0, 75, 2)))
        g = P.mix(g, c["bronzedk"], P.smoothstep(-0.9, -0.2, s) * 0.5)
        col = P.mix(col, g, ink)
    # moss creeping in from the north rim
    creep = P.smoothstep(26.0, 2.0, e) * P.smoothstep(0.1, -0.5, Z / B) * P.smoothstep(0.45, 0.7, P.fbm2(X / 18.0, Z / 18.0, 77, 3))
    col = P.mix(col, c["moss"], creep * 0.8)
    col = col * (1.0 - 0.18 * P.smoothstep(5.0, 0.0, e))[..., None]
    return np.clip(col, 0.0, 1.0)


def surface():
    floor_tiles(NAME, "Floor", "Dial", "stone_dial", 0.0, dial, nx=3, nz=2)


# --- the edge: bronze band, stone course, the disc overhanging a ruined arcade, ivy -------------------------------------
def column(element, x, z, h, r, rng, region, y=None, broken=False, ivy=False):
    y = H(x, z) if y is None else y
    m = at(x, z, y, rng.uniform(0, 6.28))
    place(element, "stone_ruin", bbox((r * 2.8, r * 2.8, 2.2), 0.4), m @ T(0, 0, -0.5), region)
    hh = h * (rng.uniform(0.3, 0.7) if broken else 1.0)
    place(element, "stone_ruin", ring_prism([(r, 1.5), (r * 0.86, hh)], 10), m, region)
    if not broken:
        place(element, "stone_ruin", bbox((r * 2.6, r * 2.6, 2.4), 0.4), m @ T(0, 0, hh), region)
    if ivy:
        for q in range(3):
            c = lump(r * rng.uniform(1.0, 1.5), rng, squash=0.9, jitter=0.15, subdiv=1, flat_bottom=0.1)
            bmesh.ops.triangulate(c, faces=c.faces[:])
            place(element, rng.choice(("leaf_ivy", "leaf_ivylt")), c, m @ T(r * 0.7, 0, hh * rng.uniform(0.3, 0.95)), region)
    return hh


def ivy_curtain(p, length, rng, region="", element="Ivy"):
    """Ivy hanging from Blender point p: a chain of leafy masses, smaller as they hang."""
    for q in range(int(length / 6) + 1):
        s = 4.5 * (1.0 - 0.6 * q / max(1, length / 6)) * rng.uniform(0.85, 1.15)
        c = lump(s, rng, squash=1.2, jitter=0.15, subdiv=1, flat_bottom=0.1)
        bmesh.ops.triangulate(c, faces=c.faces[:])
        place(element, rng.choice(("leaf_ivy", "leaf_ivy", "leaf_ivylt")), c, Matrix.Translation(Vector(p) + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), -q * 6.0))), region=region)


def edge():
    rng = random.Random(59)
    course("Band", "Bronze", "paint_bronze", -0.3, 3.5, -7.0, -0.04, rng, 10.0, 16.0, gap=0.3, outer_chamfer=0.8, inner_chamfer=0.1)
    course("Disc", "Dial", "stone_dial", 0.8, 14.0, -16.0, -7.0, rng, 12.0, 20.0, gap=0.5, top_chamfer=0.5)
    place("Core", "stone_ruindk", oval_slab(10.0, 40.0, -15.5, -18.0, n=96))
    for k in range(40):  # patina streaks running down the bronze
        x, z, nx, nz = oval(t_at((k + rng.uniform(-0.3, 0.3)) / 40 * PERIM), -0.35)
        place("Band", "paint_patina", bbox((rng.uniform(1.5, 3.5), 0.6, rng.uniform(3.0, 6.0)), 0.2), at(x, z, -6.6 - rng.uniform(0, 1.0), facing(x, z, x + nx, z + nz)))
    # the arcade: piers on an oval 40 studs in, arches between them, a lintel course over them
    n = 30
    tops = []
    for k in range(n):
        x, z, nx, nz = oval(t_at(k / n * PERIM), 42.0)
        broken = rng.random() < 0.22
        hh = rng.uniform(14.0, 30.0) if broken else 44.0
        place("Arcade", "stone_ruin", bbox((8.0, 8.0, hh), 0.6), at(x, z, -62.0, facing(x, z, x + nx, z + nz)))
        tops.append((x, z, nx, nz, broken))
    for k in range(n):
        x0, z0, nx, nz, b0 = tops[k]
        x1, z1, _, _, b1 = tops[(k + 1) % n]
        if b0 or b1:
            continue
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        span = math.hypot(x1 - x0, z1 - z0)
        yaw = facing(mx, mz, mx + nx, mz + nz)
        place("Arcade", "stone_ruin", hoop(span / 2 - 3.0, 2.6, sides=4, n=10, arc=math.pi), at(mx, mz, -32.0, yaw), "")
    course("Lintel", "Ruin", "stone_ruin", 36.0, 50.0, -18.0, -16.0, rng, 10.0, 16.0, gap=0.4)
    place("Core", "stone_ruindk", oval_slab(50.0, 60.0, -18.0, -64.0, n=64))
    course("Plinth", "Ruin", "stone_ruin", 40.0, 70.0, -70.0, -62.0, rng, 10.0, 16.0, gap=0.4)
    # a second, smaller arcade tier under the first
    n2 = 22
    for k in range(n2):
        x, z, nx, nz = oval(t_at(k / n2 * PERIM), 76.0)
        if rng.random() < 0.3:
            continue
        place("Arcade", "stone_ruin", bbox((7.0, 7.0, 30.0), 0.6), at(x, z, -100.0, facing(x, z, x + nx, z + nz)))
    place("Core", "stone_ruindk", oval_slab(84.0, 90.0, -70.0, -100.0, n=64))
    course("Plinth", "Ruin", "stone_ruin", 72.0, 100.0, -106.0, -100.0, rng, 10.0, 16.0, gap=0.4)
    # the broken bottom: a faceted mass with tumbled blocks set into it (none loose)
    place("Core", "stone_ruin", oval_slab(80.0, 150.0, -106.0, -160.0, n=12))
    for k in range(34):
        inset = rng.uniform(84.0, 146.0)
        x, z, _, _ = oval(t_at(rng.uniform(0, PERIM)), inset)
        h = -106.0 - (inset - 80.0) / 70.0 * 54.0
        s = rng.uniform(9, 16)
        place("Rubble", rng.choice(("stone_ruin", "stone_ruindk")), block((s * 1.4, s, s * 0.8), rng), at(x, z, h - s * 0.4, rng.uniform(0, 6.28)) @ Rx(rng.uniform(-0.4, 0.4)))
    for k in range(34):  # ivy curtains from the band, over the arches
        x, z, nx, nz = oval(t_at((k + rng.uniform(-0.3, 0.3)) / 34 * PERIM), 1.5)
        ivy_curtain(W(x, z, -8.0), rng.uniform(12, 40), rng)


# --- islands: ruined masonry over arcades, ivy hanging --------------------------------------------------------------
def ruin_isle(name, cx, cz, rx, rz, top, hill=0.0, flat=None, depth=None, rng=None):
    i = isle(name, cx, cz, rx, rz, top, hill=hill, flat=flat)
    isle_top(i, "stone_flag", "stone_ruin", side=6.0)  # old paving, not grass (grass tops are Map 1's)
    rng = rng or random.Random(i["s"])
    depth = depth or min(rx, rz) * 1.1
    place("Island", "stone_ruin", ellipse_slab(rx * 0.97, rz * 0.97, top - 6.0, top - 12.0, n=28, wob=lambda a: outline(i, a)), at(cx, cz, 0.0), region=name)
    n = max(8, int((rx + rz) / 22))
    for k in range(n):  # an arcade under the rim
        a = k / n * math.tau
        x, z = cx + math.cos(a) * rx * 0.8, cz + math.sin(a) * rz * 0.8
        if rng.random() < 0.8:
            place("Island", "stone_ruin", bbox((6.0, 6.0, depth * 0.35), 0.5), at(x, z, top - 12.0 - depth * 0.35), region=name)
    # a masonry drum (straight sides, not a cone), a plinth, a second smaller drum, a broken faceted foot
    place("Island", "stone_ruindk", ellipse_slab(rx * 0.76, rz * 0.76, top - 12.0, top - 12.0 - depth * 0.35, n=24), at(cx, cz, 0.0), region=name)
    place("Island", "stone_ruin", ellipse_slab(rx * 0.84, rz * 0.84, top - 12.0 - depth * 0.35, top - 18.0 - depth * 0.35, n=24), at(cx, cz, 0.0), region=name)
    place("Island", "stone_ruin", ellipse_slab(rx * 0.56, rz * 0.56, top - 18.0 - depth * 0.35, top - 18.0 - depth * 0.6, n=20), at(cx, cz, 0.0), region=name)
    place("Island", "stone_ruindk", ellipse_slab(rx * 0.56, rz * 0.56, top - 18.0 - depth * 0.6, top - 12.0 - depth, n=9, k_bot=0.25), at(cx, cz, 0.0), region=name)
    for k in range(int((rx + rz) / 16)):
        a = rng.uniform(0, math.tau)
        x, z = cx + math.cos(a) * rx * 0.96, cz + math.sin(a) * rz * 0.96
        ivy_curtain(W(x, z, top - 5.0), rng.uniform(10, 30), rng, region=name, element="Island")
    return i


def weeping_tree(x, z, s, rng, region):
    """A weeping willow for the ruins (not Map 1's round trees): a short leaning trunk, a broad low dome of leaves and
    thick curtains hanging nearly to the ground all round, so it reads as a willow, not a palm."""
    y = H(x, z)
    b = bmesh.new()
    tube(b, [(0, 0, -1.0), (0.6 * s, 0, 4.0 * s), (1.0 * s, 0.3 * s, 7.0 * s)], [1.5 * s, 1.1 * s, 0.8 * s], sides=6, rng=rng)
    m = at(x, z, y, rng.uniform(0, 6.28))
    place("Trees", "bark", b, m, region=region)
    c = lump(7.0 * s, rng, squash=0.5, jitter=0.1, subdiv=1, flat_bottom=0.1)
    bmesh.ops.triangulate(c, faces=c.faces[:])
    place("Trees", "leaf_ivy", c, m @ T(1.0 * s, 0.3 * s, 8.5 * s), region=region)
    for k in range(11):
        a = k / 11 * math.tau
        ivy_curtain(m @ Vector((1.0 * s + math.cos(a) * 6.0 * s, 0.3 * s + math.sin(a) * 6.0 * s, 8.0 * s)), 6.5 * s, rng, region=region, element="Trees")


def moss_mounds(i, rng, n):
    for k in range(n):
        a, r = rng.uniform(0, math.tau), math.sqrt(rng.uniform(0.05, 0.8))
        x, z = i["cx"] + math.cos(a) * i["rx"] * r, i["cz"] + math.sin(a) * i["rz"] * r
        c = lump(rng.uniform(6, 12), rng, squash=0.35, jitter=0.15, subdiv=1, flat_bottom=0.5)
        bmesh.ops.triangulate(c, faces=c.faces[:])
        place("Island", "leaf_moss", c, at(x, z, H(x, z)), region=i["name"])


def tholos(x, z, r, rng, region):
    """A small round temple: a stepped base, a ring of columns, an architrave ring, a bronze-green dome."""
    y = H(x, z)
    m = at(x, z, y, 0.0)
    for q in range(3):
        place("Temples", "stone_ruin", ring_prism([(r + 8 - q * 3, q * 2.0), (r + 8 - q * 3, q * 2.0 + 2.0)], 16), m @ T(0, 0, -1.0), region)
    for k in range(10):
        a = k / 10 * math.tau
        column("Temples", x + math.cos(a) * r, z + math.sin(a) * r, 28.0, 3.2, rng, region, y=y + 5.0)
    place("Temples", "stone_ruin", annulus(r - 3.0, r + 3.0, 33.0, 37.0, 16), m, region)
    place("Temples", "paint_patina", ring_prism([(r + 2.0, 37.0), (r * 0.8, 37.0 + r * 0.5), (r * 0.35, 37.0 + r * 0.8), (0.5, 37.0 + r * 0.9)], 16), m, region)
    place("Temples", "cloth_gold", ring_prism([(1.4, 37.0 + r * 0.88), (0.3, 37.0 + r * 0.88 + 6.0)], 6), m, region)


def temple(x, z, w, d, rng, region):
    """A temple on a stepped platform: six front columns, side columns, an entablature, a pediment roof."""
    y = H(x, z)
    yaw = facing(x, z, 0.0, 0.0)
    m = at(x, z, y, yaw)
    for q in range(3):
        place("Temples", "stone_ruin", bbox((w + 16 - q * 5, d + 16 - q * 5, 2.4), 0.4), m @ T(0, 0, -1.0 + q * 2.4), region)
    base = y + 6.2
    for k in range(6):
        for side in (-1, 1):
            px = -w / 2 + 3 + k * (w - 6) / 5
            wx = m @ Vector((px, side * (d / 2 - 3), 0))
            column("Temples", wx.x, -wx.y, 30.0, 3.4, rng, region, y=base, broken=(k == 4 and side == 1), ivy=(k == 1))
    place("Temples", "stone_ruin", bbox((w + 2, d + 2, 5.0), 0.6), m @ T(0, 0, base - y + 34.0), region)
    g = bmesh.new()
    L, D, rise = w / 2 + 2, d / 2 + 2, 11.0
    a = [g.verts.new((-L, -D, 0)), g.verts.new((L, -D, 0)), g.verts.new((0, -D, rise))]
    b2 = [g.verts.new((-L, D, 0)), g.verts.new((L, D, 0)), g.verts.new((0, D, rise))]
    g.faces.new(a)
    g.faces.new(list(reversed(b2)))
    g.faces.new((a[0], b2[0], b2[2], a[2]))
    g.faces.new((a[1], a[2], b2[2], b2[1]))
    g.faces.new((a[0], a[1], b2[1], b2[0]))
    bmesh.ops.recalc_face_normals(g, faces=g.faces[:])
    place("Temples", "paint_patina", g, m @ T(0, 0, base - y + 39.0) @ Rz(math.pi / 2), region)


def aqueduct(x0, z0, x1, z1, y, rng, region):
    """Two tiers of arches between two points, broken at one end."""
    L = math.hypot(x1 - x0, z1 - z0)
    n = int(L / 26)
    yaw = math.atan2(-(z1 - z0), x1 - x0)  # Blender yaw of the run
    for tier, (ph, span_h) in enumerate(((0.0, 34.0), (38.0, 22.0))):
        for k in range(n - (2 if tier else 0)):
            t = (k + 0.5) / n
            px, pz = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
            m = Matrix.Translation(W(px, pz, y + ph)) @ Rz(yaw)
            for s in (-1, 1):
                place("Aqueduct", "stone_ruin", bbox((8.0, 10.0, span_h), 0.5), m @ T(s * 11.0, 0, 0), region)
            place("Aqueduct", "stone_ruin", hoop(8.0, 3.6, sides=4, n=8, arc=math.pi), m @ Rz(math.pi / 2) @ Rz(-math.pi / 2) @ T(0, 0, span_h - 8.0), region)
            place("Aqueduct", "stone_ruin", bbox((26.0, 11.0, 6.0), 0.5), m @ T(0, 0, span_h), region)
            if rng.random() < 0.4:
                ivy_curtain(m @ Vector((rng.uniform(-10, 10), 4.0, span_h)), rng.uniform(8, 20), rng, region=region, element="Aqueduct")


def armillary(cx, cz, y0, R, face_x, face_z):
    """THE landmark: an armillary sphere of radius R on a cradle: a meridian ring facing the arena, an equator ring,
    an ecliptic band, a polar rod with tips, a gold sun at the heart. Rings are 'ArmillaryRings' meshes (they turn)."""
    yaw = facing(cx, cz, face_x, face_z)
    centre = at(cx, cz, y0 + R + 14.0, yaw)
    lat = math.radians(40.0)
    place("ArmillaryRings", "paint_bronze", hoop(R, 6.0, sides=8, n=56), centre, "Armillary")  # meridian
    eq = centre @ Rx(-lat) @ Rx(math.pi / 2)
    place("ArmillaryRings", "paint_bronze", hoop(R * 0.94, 5.0, sides=8, n=56), eq, "Armillary")
    ecl = centre @ Rx(-lat) @ Ry(math.radians(23.5))  # the annulus is already flat in its own XY plane
    band = annulus(R * 0.84, R * 0.9, -6.0, 6.0, 56)
    place("ArmillaryRings", "paint_patina", band, ecl, "Armillary")
    col = centre @ Rx(-lat) @ Ry(math.pi / 2) @ Rx(math.pi / 2)
    place("ArmillaryRings", "paint_bronze", hoop(R * 0.78, 3.6, sides=6, n=48), col, "Armillary")
    axis = (centre @ Rx(-lat) @ Vector((0, 0, 1, 0))).to_3d().normalized()
    c3 = centre.to_translation()
    place("ArmillaryRings", "paint_bronze", rod(c3 - axis * R * 1.25, c3 + axis * R * 1.25, 3.0, 8), region="Armillary")
    for s in (-1, 1):
        tip = c3 + axis * R * 1.25 * s
        cone = ring_prism([(6.0, 0.0), (0.3, 16.0)], 8)
        rot = Vector((0, 0, 1)).rotation_difference(axis * s).to_matrix().to_4x4()
        place("ArmillaryRings", "cloth_gold", cone, Matrix.Translation(tip) @ rot, "Armillary")
    sun = bmesh.new()
    bmesh.ops.create_icosphere(sun, subdivisions=2, radius=R * 0.16)
    place("ArmillaryRings", "glow_sun", sun, centre, "Armillary")
    # the cradle: a stone pedestal and two bronze arms up to the meridian ring
    base = at(cx, cz, y0, yaw)
    place("Armillary", "stone_ruin", ring_prism([(26.0, 0.0), (22.0, 8.0), (14.0, 12.0), (12.0, 18.0)], 12), base, "Armillary")
    for s in (-1, 1):
        a0 = base @ Vector((s * 10.0, 0.0, 18.0))
        a1 = centre @ Vector((s * R * math.sin(0.5), 0.0, -R * math.cos(0.5)))
        place("Armillary", "paint_bronze", rod(a0, a1, 3.4, 6), region="Armillary")
    DATA["armillary"] = {"meshes": "Map_Sundial_ArmillaryRings_*", "centre": [round(c3.x, 2), round(c3.z, 2), round(-c3.y, 2)]}


def broken_tower(x, z, r, h, rng, region):
    """A broken round tower: a drum of courses, two rows of dark arches, a ragged top, ivy."""
    y = H(x, z)
    m = at(x, z, y, 0.0)
    place("Tower", "stone_ruin", ring_prism([(r + 6, -2.0), (r + 4, 6.0), (r, 8.0), (r * 0.94, h)], 16), m, region)
    for q, hh in enumerate((22.0, 52.0)):
        for k in range(8):
            a = (k + 0.5 * q) / 8 * math.tau
            place("Tower", "stone_ruindk", bbox((9.0, 3.0, 16.0), 0.4), m @ Rz(a) @ T(0, -(r * 0.96), hh), region)
    for k in range(12):  # a ragged top
        a = k / 12 * math.tau
        place("Tower", "stone_ruin", bbox((10.0, 7.0, rng.uniform(2.0, 10.0)), 0.5), m @ Rz(a) @ T(0, -(r * 0.9), h), region)
    for k in range(6):
        a = rng.uniform(0, math.tau)
        ivy_curtain(m @ Vector((math.cos(a) * (r + 1), math.sin(a) * (r + 1), h - rng.uniform(0, 20))), rng.uniform(20, 50), rng, region=region, element="Tower")
    return y + h


COL = (-520.0, -1050.0)
TOWER = (0.0, -1400.0)


def islands():
    """The sundial's own layout (review 2026-11-21): the armillary dead north, the colonnade north-west, the
    aqueduct east, the temple west, ruins far east and west too, not only north."""
    ruin_isle("Colonnade", COL[0], COL[1], 240.0, 165.0, 24.0, flat=(COL[0], COL[1], 250.0, 24.0), depth=150.0)
    ruin_isle("Tower", TOWER[0], TOWER[1], 150.0, 130.0, 10.0, flat=(TOWER[0], TOWER[1], 160.0, 10.0), depth=140.0)
    ruin_isle("Aqueduct", 560.0, -760.0, 160.0, 70.0, -12.0, depth=80.0)
    ruin_isle("Temple", -860.0, -620.0, 130.0, 100.0, 0.0, flat=(-860.0, -620.0, 140.0, 0.0), depth=100.0)
    ruin_isle("Garden", 520.0, -1550.0, 210.0, 130.0, 50.0, hill=10.0, depth=130.0)
    ruin_isle("RuinE", 820.0, -260.0, 54.0, 42.0, -120.0, hill=3.0, depth=56.0)
    ruin_isle("RuinW", -560.0, -480.0, 58.0, 44.0, -96.0, hill=3.0, depth=56.0)
    ruin_isle("RuinFarE", 1250.0, -1000.0, 220.0, 140.0, 0.0, depth=120.0)
    ruin_isle("RuinFarW", -1300.0, -1350.0, 220.0, 140.0, 10.0, depth=120.0)
    ruin_isle("FarNE", 1700.0, -2200.0, 240.0, 150.0, 8.0, depth=140.0)
    ruin_isle("FarNW", -1500.0, -2100.0, 260.0, 160.0, 16.0, depth=140.0)
    ruin_isle("FarN", -200.0, -3000.0, 300.0, 180.0, 40.0, depth=150.0)


def ruins():
    rng = random.Random(71)
    cx, cz = COL
    for k in range(18):  # a ring of columns round the round temple, some broken, some joined by lintels
        a = k / 18 * math.tau
        x, z = cx + math.cos(a) * 150, cz + math.sin(a) * 100
        column("Colonnade", x, z, 36.0, 4.2, rng, "Colonnade", broken=rng.random() < 0.3, ivy=rng.random() < 0.35)
    tholos(cx, cz, 26.0, rng, "Colonnade")
    for k in range(5):  # fallen column drums
        x, z = cx + rng.uniform(-180, 180), cz + rng.uniform(-110, 110)
        if math.hypot((x - cx) / 150, (z - cz) / 100) < 0.6:
            continue
        place("Colonnade", "stone_ruin", ring_prism([(2.6, 0.0), (2.6, 12.0)], 10), at(x, z, H(x, z) + 2.4, rng.uniform(0, 6.28)) @ Ry(math.pi / 2), "Colonnade")
    for k in range(10):
        a = rng.uniform(0, math.tau)
        weeping_tree(cx + math.cos(a) * rng.uniform(170, 220), cz + math.sin(a) * rng.uniform(115, 150), rng.uniform(2.4, 3.2), rng, "Colonnade")
    tx, tz = TOWER
    top = broken_tower(tx, tz, 34.0, 92.0, rng, "Tower")
    armillary(tx, tz, top, 136.0, -300.0, 0.0)  # the meridian ring turned nearly face-on to the arena
    for k in range(6):
        a = rng.uniform(0, math.tau)
        weeping_tree(tx + math.cos(a) * rng.uniform(70, 100), tz + math.sin(a) * rng.uniform(55, 80), rng.uniform(2.2, 3.0), rng, "Tower")
    i = ISLES["Aqueduct"]
    aqueduct(i["cx"] - 210.0, i["cz"] + 20.0, i["cx"] + 140.0, i["cz"] - 30.0, i["top"] - 2.0, rng, "Aqueduct")
    i = ISLES["Temple"]
    temple(i["cx"], i["cz"], 50.0, 34.0, rng, "Temple")
    for k in range(5):
        a = rng.uniform(0, math.tau)
        weeping_tree(i["cx"] + math.cos(a) * 95, i["cz"] + math.sin(a) * 70, rng.uniform(2.2, 2.8), rng, "Temple")
    i = ISLES["Garden"]
    for k in range(16):
        a, r = rng.uniform(0, math.tau), math.sqrt(rng.uniform(0.05, 0.75))
        weeping_tree(i["cx"] + math.cos(a) * i["rx"] * r, i["cz"] + math.sin(a) * i["rz"] * r, rng.uniform(2.6, 3.6), rng, "Garden")
    for k in range(6):
        column("Garden", i["cx"] - 120 + k * 45, i["cz"] + 70, 34.0, 4.2, rng, "Garden", broken=k % 2 == 1, ivy=True)
    for name in ISLES:
        moss_mounds(ISLES[name], rng, max(3, int(ISLES[name]["rx"] / 25)))
    for name in ("RuinE", "RuinW"):
        i = ISLES[name]
        column("Ruins", i["cx"] - 14, i["cz"], 30.0, 2.4, rng, name, ivy=True)
        column("Ruins", i["cx"] + 14, i["cz"] + 6, 30.0, 2.4, rng, name, broken=True)
    for name in ("FarNE", "FarNW", "FarN", "RuinFarE", "RuinFarW"):
        i = ISLES[name]
        for k in range(7):
            column("Ruins", i["cx"] - 120 + k * 40, i["cz"] + rng.uniform(-30, 30), 40.0, 4.6, rng, name, broken=rng.random() < 0.4)
        for k in range(5):
            weeping_tree(i["cx"] + rng.uniform(-120, 120), i["cz"] + rng.uniform(-60, 60), rng.uniform(3.0, 3.8), rng, name)


sketch_run(NAME, [surface, edge, islands, ruins], dial, landmark=("Armillary", "ArmillaryRings", "Tower"))
