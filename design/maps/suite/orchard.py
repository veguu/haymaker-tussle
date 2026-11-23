"""Map 6 of the suite, "The Blossom Shelf" (Orchard Terraces). DESIGN BLOCKOUT 2026-11-21: NOT APPROVED, NOT BUILT.

    blender -b --factory-startup -P orchard.py -- <out folder> --dry --no-render

IDEA (five words): an orchard terrace in bloom. The arena is the top terrace of a sky orchard: a brick floor
strewn with fallen blossom, its walls trained with flowering fruit trees, the bees' great hive beyond.
  - Floor: terracotta brick laid in a 45-degree herringbone (no long straight joints; a chevron's columns read as lines), joints a darker clay (never white), drifts of fallen coral, pink and
    white petals swept by the wind into soft piles, tiny and close in tone to the brick (a drift, not dots). No medallion: the brief's
    "petal mosaics" are the fallen petals (my reading).
  - Edge: a fat rolled terracotta rim over a cream band, then a tall terracotta wall with a timber trellis and
    ESPALIER trees on it (fruit trees trained flat against the wall, blossom along every branch), then the island's
    root ball, roots dangling into the sky. Nothing stands out past the edge.
  - Background (its own layout: the skep north-west, the main orchard north-east, terraces east and west too):
    terraced orchard islands with tilled soil tops, not grass (two or three walled terraces stepping up, rows of round blossom trees in
    coral, pink and white on each), a glasshouse, trellis tunnels of blossom, small bee skeps on stands, two low
    terraces off the arena's sides, three far orchards. Islands hang on root balls like the arena.
  - LANDMARK: the Great Skep, a coiled-straw beehive about 320 studs tall (a dome of fat straw rings) with a round
    coral door, round windows, honey dripping from the top, and three giant chunky bees flying round it (three
    moved parts). No giant tree: the lobby has the great tree.
  - Feel: blossom on the wind. A light fall of petals over the whole arena from one wide, fixed emitter above it
    (low rate, short lifetimes, halved on phones; nothing follows the camera; the cost is NOT measured yet), and the
    three bees circle the skep (3 moved parts, about 15 us a frame).
"""
import os

_d = os.path.dirname(os.path.abspath(__file__))
for _f in ("base.py", "sketch_kit.py"):
    _p = os.path.join(_d, _f)
    exec(compile(open(_p, encoding="utf-8").read(), _p, "exec"))

NAME = "Orchard"
PAL.update(
    {
        "stone_terra": (srgb(204, 112, 82), srgb(230, 150, 116), srgb(134, 70, 60)),
        "stone_terradk": (srgb(180, 96, 72), srgb(210, 132, 104), srgb(116, 60, 54)),
        "stone_cream": (srgb(236, 224, 200), srgb(250, 242, 224), srgb(170, 160, 152)),
        "leaf_orchard": (srgb(112, 158, 86), srgb(150, 190, 108), srgb(70, 112, 64)),
        "leaf_grassor": (srgb(140, 176, 96), srgb(176, 204, 124), srgb(94, 126, 72)),
        "soil_tilled": (srgb(150, 110, 84), srgb(184, 142, 110), srgb(100, 72, 58)),
        "leaf_blossom": (srgb(240, 146, 136), srgb(250, 184, 172), srgb(170, 92, 92)),
        "leaf_blossompale": (srgb(248, 196, 190), srgb(255, 222, 216), srgb(180, 132, 134)),
        "leaf_blossomwhite": (srgb(250, 238, 232), srgb(255, 250, 246), srgb(184, 172, 172)),
        "bark_orchard": (srgb(120, 86, 66), srgb(160, 120, 92), srgb(74, 52, 44)),
        "bark_trellis": (srgb(214, 190, 150), srgb(236, 216, 182), srgb(148, 128, 104)),
        "bark_straw": (srgb(228, 184, 96), srgb(246, 214, 140), srgb(164, 124, 64)),
        "bark_strawdk": (srgb(204, 158, 80), srgb(232, 192, 120), srgb(140, 104, 56)),
        "cloth_honey": (srgb(236, 172, 56), srgb(252, 206, 110), srgb(170, 112, 36)),
        "cloth_bee": (srgb(82, 60, 50), srgb(116, 90, 76), srgb(50, 36, 32)),
        "glass_pale": (srgb(196, 228, 222), srgb(226, 244, 240), srgb(136, 170, 170)),
        "soil": (srgb(128, 96, 74), srgb(164, 130, 100), srgb(82, 60, 50)),
    }
)
BLOSSOMS = ("leaf_blossom", "leaf_blossompale", "leaf_blossomwhite", "leaf_blossom")

# --- the fighting surface: chevron brick with drifts of fallen blossom -------------------------------------------------
ORCH = {"terra": (196, 120, 94), "terralt": (212, 144, 114), "terradk": (174, 104, 82), "petal": (228, 150, 140), "petalpale": (236, 176, 166), "petalwhite": (240, 196, 186)}  # petals low contrast: a drift, not dots


def orchard(X, Z):
    c = {k: P.rgb(*v) for k, v in ORCH.items()}
    # HERRINGBONE at 45 degrees, bricks 4 x 2 studs: it has no long straight joints (the chevron's columns read as
    # lines running north, re-check 2026-11-21). Cells of 2 studs; residue (i - j) mod 4 says which brick a cell is in:
    # 0, 1 = a brick lying along i; 3, 2 = a brick standing along j.
    u = 2.0
    a = (X + Z) * 0.7071 / u
    b = (X - Z) * 0.7071 / u
    i, j = np.floor(a), np.floor(b)
    fa, fb2 = a - i, b - j
    r = np.mod(i - j, 4)
    lying = r < 2
    bi = np.where(lying, np.where(r == 0, i, i - 1), i)
    bj = np.where(lying, j, np.where(r == 3, j, j - 1))
    la = np.where(lying, np.where(r == 0, fa, fa + 1.0) / 2.0, fa)  # 0..1 along each brick's own axes
    lb = np.where(lying, fb2, np.where(r == 3, fb2, fb2 + 1.0) / 2.0)
    h = P.hash01(81, bi, bj + 7 * lying)
    col = P.mix(P.mix(c["terra"], c["terralt"], P.smoothstep(0.5, 1.0, h)), c["terradk"], P.smoothstep(0.35, 0.0, h))
    sa = np.where(lying, 2.0 * u, u)
    sb = np.where(lying, u, 2.0 * u)
    bev = np.minimum(np.minimum(la, 1.0 - la) * sa, np.minimum(lb, 1.0 - lb) * sb)  # studs to the brick's edge
    col = col * (0.80 + 0.2 * P.smoothstep(0.0, 0.35, bev))[..., None]
    col = col * (1.0 + 0.08 * (P.fbm2(X / 45.0, Z / 45.0, 83, 3) - 0.5))[..., None]
    # fallen blossom: drifts swept toward the south-west, piled thicker in the north-east
    wx, wz = (X + Z) * 0.707, (X - Z) * 0.707
    D = P.fbm2(wx / 70.0, wz / 26.0, 85, 3)
    D = P.smoothstep(0.46, 0.72, D) * (0.55 + 0.45 * P.smoothstep(-150.0, 150.0, X - Z))
    col = P.mix(col, c["petalpale"], 0.32 * D)
    pc = 1.1
    gi, gj = np.floor(X / pc), np.floor(Z / pc)
    ox = (P.hash01(87, gi, gj) - 0.5) * 0.5
    oz = (P.hash01(88, gi, gj) - 0.5) * 0.5
    ang = P.hash01(89, gi, gj) * math.pi
    lx, lz = X - (gi + 0.5) * pc - ox, Z - (gj + 0.5) * pc - oz
    ux = lx * np.cos(ang) + lz * np.sin(ang)
    uz = -lx * np.sin(ang) + lz * np.cos(ang)
    petal = (ux / 0.48) ** 2 + (uz / 0.28) ** 2 < 1.0
    on = petal & (P.hash01(90, gi, gj) < D * 0.6 + 0.01)
    pick = P.hash01(91, gi, gj)
    pcol = np.where((pick < 0.45)[..., None], c["petal"], np.where((pick < 0.8)[..., None], c["petalpale"], c["petalwhite"]))
    col = np.where(on[..., None], P.mix(col, pcol, 0.6), col)
    col = col * (1.0 - 0.18 * P.smoothstep(5.0, 0.0, edge_dist(X, Z)))[..., None]
    return np.clip(col, 0.0, 1.0)


def surface():
    floor_tiles(NAME, "Floor", "Brick", "stone_terra", 0.0, orchard, nx=3, nz=2)


# --- the edge: rolled rim, cream band, a trellised wall with espalier trees, a root ball --------------------------------
def blossom_lump(element, p, s, rng, region="", flat=None, key=None):
    c = lump(s, rng, squash=0.8, jitter=0.16, subdiv=1, flat_bottom=0.3)
    bmesh.ops.triangulate(c, faces=c.faces[:])
    m = Matrix.Translation(Vector(p)) @ Rz(rng.uniform(0, 6.28))
    if flat is not None:  # squash against a wall: flat is the wall's outward normal (Blender vector)
        n = Vector(flat).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(n).to_matrix().to_4x4()
        m = Matrix.Translation(Vector(p)) @ rot @ Matrix.Diagonal((1.0, 1.0, 0.45, 1.0))
    place(element, key or rng.choice(BLOSSOMS), c, m, region=region)


def espalier(t, rng, h0=-44.0, h1=-12.0, inset=1.0):
    """A fan-trained fruit tree flat against the wall at oval parameter t: a short trunk, six branches fanning up
    across the wall face, blossom masses along them."""
    x, z, nx, nz = oval(t, inset)
    m = at(x, z, 0.0, facing(x, z, x + nx, z + nz))  # local -y is out of the wall, x along it
    normal = (m @ Vector((0, -1, 0, 0))).to_3d()
    base = Vector((0, -0.6, h0))
    fork = Vector((0, -0.6, h0 + 8.0))
    place("Espalier", "bark_orchard", rod(m @ base, m @ fork, 1.3, 5))
    for k in range(6):
        a = math.radians(-70 + k * 28)
        L = rng.uniform(16.0, 22.0)
        tip = fork + Vector((math.sin(a) * L * 1.3, 0.0, math.cos(a) * L * 0.85))
        tip.z = min(tip.z, h1)
        place("Espalier", "bark_orchard", rod(m @ fork, m @ tip, 0.7, 4))
        for q in range(3):
            p = fork + (tip - fork) * (0.45 + q * 0.27) + Vector((0, -1.2, 0))
            blossom_lump("Espalier", m @ p, rng.uniform(2.6, 3.6), rng, flat=normal)


def edge():
    rng = random.Random(101)
    course("Rim", "Terra", "stone_terra", -0.8, 4.0, -6.0, -0.04, rng, 6.0, 10.0, gap=0.0, outer_chamfer=2.2, inner_chamfer=0.1)
    course("Band", "Cream", "stone_cream", 0.4, 8.0, -10.0, -6.0, rng, 8.0, 14.0, gap=0.2, top_chamfer=0.4)
    course("Wall", "Terradk", "stone_terradk", 1.0, 12.0, -46.0, -10.0, rng, 7.0, 11.0, gap=0.25, top_chamfer=0.3)
    place("Core", "soil", oval_slab(8.0, 16.0, -10.0, -46.0, n=96))
    # the trellis on the wall: a diamond lattice of timber laths, just proud of the wall face
    n = int(PERIM / 6.0)
    for k in range(n):
        ta, tb = t_at(k * PERIM / n), t_at((k + 1) * PERIM / n)
        xa, za, _, _ = oval(ta, 0.6)
        xb, zb, _, _ = oval(tb, 0.6)
        for r in range(5):
            h0, h1 = -44.0 + r * 6.4, -44.0 + (r + 1) * 6.4
            place("Trellis", "bark_trellis", rod(W(xa, za, h0), W(xb, zb, h1), 0.3, 4))
            place("Trellis", "bark_trellis", rod(W(xa, za, h1), W(xb, zb, h0), 0.3, 4))
    for k in range(18):
        espalier((k + 0.5) / 18 * math.tau + rng.uniform(-0.05, 0.05), rng)
    # the root ball: soil bulging out a little under the wall, then rounding to a bottom, roots dangling
    place("Roots", "soil", oval_slab(12.0, 8.0, -46.0, -70.0, n=64))
    place("Roots", "soil", oval_slab(8.0, 60.0, -70.0, -110.0, n=48))
    place("Roots", "soil", oval_slab(60.0, 150.0, -110.0, -150.0, n=32))
    for k in range(46):  # roots leave the ball's own surface (re-check: some floated loose under it)
        a = rng.uniform(0, math.tau)
        inset = rng.uniform(20.0, 140.0)
        x, z, _, _ = oval(a, inset)
        y0 = (-70.0 - (inset - 8.0) / 52.0 * 40.0 if inset < 60.0 else -110.0 - (inset - 60.0) / 90.0 * 40.0) + 3.0
        pts = [W(x, z, y0)]
        for q in range(4):
            x += rng.uniform(-6, 6)
            z += rng.uniform(-6, 6)
            pts.append(W(x, z, y0 - (q + 1) * rng.uniform(10, 18)))
        b = bmesh.new()
        tube(b, pts, [2.4, 1.8, 1.2, 0.7, 0.3], sides=5, rng=rng)
        place("Roots", "bark_orchard", b)


# --- islands: walled terraces on root balls -----------------------------------------------------------------------
def blossom_tree(x, z, s, rng, region, y=None, key=None):
    """A round storybook blossom tree: a short kinked trunk and three blossom masses, one colour per tree."""
    y = H(x, z) if y is None else y
    b = bmesh.new()
    tube(b, [(0, 0, -1.0), (0.5 * s, 0, 4.0 * s), (0.2 * s, 0.4 * s, 7.5 * s)], [1.2 * s, 0.9 * s, 0.6 * s], sides=6, rng=rng)
    place("Trees", "bark_orchard", b, at(x, z, y, rng.uniform(0, 6.28)), region=region)
    key = key or rng.choice(BLOSSOMS)
    for k in range(3):
        c = lump(4.6 * s * rng.uniform(0.85, 1.1), rng, squash=0.8, jitter=0.15, subdiv=1, flat_bottom=0.4)
        bmesh.ops.triangulate(c, faces=c.faces[:])
        off = (rng.uniform(-2.5, 2.5) * s, rng.uniform(-2.5, 2.5) * s, (8.5 + k * 2.2) * s)
        place("Trees", key if k else rng.choice((key, "leaf_orchard")), c, at(x, z, y, rng.uniform(0, 6.28)) @ T(*off), region=region)


def terrace_isle(name, cx, cz, rx, rz, top, levels=2, rise=12.0, depth=None, rng=None, trees=True):
    """A terraced orchard island: `levels` walled terraces stepping up, rows of blossom trees round each, on a root
    ball with roots dangling."""
    rng = rng or random.Random(sum(map(ord, name)))
    fracs = [1.0, 0.62, 0.32][:levels]
    hs = [top + k * rise for k in range(levels)]

    def shape(u, v):
        rr = math.hypot(u, v)
        for k in range(levels - 1, -1, -1):
            if rr < fracs[k] - 0.02:
                return hs[k] - top
        return 0.0

    i = isle(name, cx, cz, rx, rz, top, shape=shape)
    for k, (f, h) in enumerate(zip(fracs, hs)):
        place("Island", "soil_tilled", ellipse_slab(rx * f, rz * f, h, h - 2.0, n=32, wob=lambda a: outline(i, a)), at(cx, cz, 0.0), region=name)
        place("Island", "stone_terra", ellipse_slab(rx * f * 1.005, rz * f * 1.005, h - 0.5, h - rise - 2.0 if k else h - 10.0, n=32, wob=lambda a: outline(i, a)), at(cx, cz, 0.0), region=name)
        if trees:
            ring_f = f * 0.86 if k == levels - 1 else (f + fracs[k + 1]) / 2
            n = max(5, int(math.tau * rx * ring_f / 34))
            key = rng.choice(BLOSSOMS)
            for q in range(n):
                a = q / n * math.tau + rng.uniform(-0.08, 0.08)
                blossom_tree(cx + math.cos(a) * rx * ring_f, cz + math.sin(a) * rz * ring_f, rng.uniform(2.2, 2.8), rng, name, y=h, key=key)
    depth = depth or min(rx, rz) * 1.0
    place("Island", "soil", ellipse_slab(rx * 0.97, rz * 0.97, top - 10.0, top - 10.0 - depth * 0.45, n=24, k_bot=0.78), at(cx, cz, 0.0), region=name)
    place("Island", "soil", ellipse_slab(rx * 0.76, rz * 0.76, top - 10.0 - depth * 0.45, top - 10.0 - depth, n=20, k_bot=0.2), at(cx, cz, 0.0), region=name)
    for k in range(int((rx + rz) / 14)):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.2, 0.75)
        x, z = cx + math.cos(a) * rx * r, cz + math.sin(a) * rz * r
        y0 = top - 10.0 - depth * (0.5 + 0.4 * (1 - r))
        b = bmesh.new()
        tube(b, [W(x, z, y0), W(x + rng.uniform(-5, 5), z + rng.uniform(-5, 5), y0 - 14), W(x + rng.uniform(-8, 8), z + rng.uniform(-8, 8), y0 - 30)], [1.8, 1.0, 0.3], sides=5, rng=rng)
        place("Island", "bark_orchard", b, region=name)
    return i


def glasshouse(x, z, w, d, h, rng, region):
    y = H(x, z)
    m = at(x, z, y, facing(x, z, 0.0, 0.0))
    place("Houses", "stone_terra", bbox((w + 2.0, d + 2.0, 3.0), 0.5), m @ T(0, 0, -1.0), region)
    place("Houses", "glass_pale", bbox((w, d, h), 0.3), m @ T(0, 0, 2.0), region)
    for k in range(5):
        px = -w / 2 + k * w / 4
        for sy in (-1, 1):
            place("Houses", "stone_cream", bbox((1.2, 1.2, h), 0.2), m @ T(px, sy * d / 2, 2.0), region)
    g = bmesh.new()
    L, D = w / 2, d / 2
    a = [g.verts.new((-L, -D, 0)), g.verts.new((-L, D, 0)), g.verts.new((-L, 0, d * 0.45))]
    b2 = [g.verts.new((L, -D, 0)), g.verts.new((L, D, 0)), g.verts.new((L, 0, d * 0.45))]
    g.faces.new((a[2], a[1], a[0]))
    g.faces.new((b2[0], b2[1], b2[2]))
    g.faces.new((a[0], b2[0], b2[2], a[2]))
    g.faces.new((a[2], b2[2], b2[1], a[1]))
    bmesh.ops.recalc_face_normals(g, faces=g.faces[:])
    place("Houses", "glass_pale", g, m @ T(0, 0, h + 2.0), region)
    place("Houses", "stone_cream", rod(m @ Vector((-L, 0, h + 2.0 + d * 0.45)), m @ Vector((L, 0, h + 2.0 + d * 0.45)), 0.8, 4), region=region)
    place("Houses", "stone_terra", bbox((6.0, 1.0, 9.0), 0.3), m @ T(0, -d / 2 - 0.4, 2.0), region)


def trellis_tunnel(x0, z0, x1, z1, rng, region, w=14.0, h=14.0):
    L = math.hypot(x1 - x0, z1 - z0)
    n = int(L / 8)
    yaw = math.atan2(-(z1 - z0), x1 - x0)
    for k in range(n + 1):
        t = k / n
        px, pz = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
        y = H(px, pz)
        m = Matrix.Translation(W(px, pz, y)) @ Rz(yaw + math.pi / 2)
        place("Trellis", "bark_trellis", hoop(w / 2, 0.6, sides=4, n=10, arc=math.pi), m @ T(0, 0, h - w / 2) @ Matrix.Diagonal((1, 1, 1.4, 1)), region)
        for s in (-1, 1):
            place("Trellis", "bark_trellis", bbox((1.0, 1.0, h - w / 2), 0.2), m @ T(s * w / 2, 0, 0), region)
        if k % 2 == 0:
            blossom_lump("Trellis", m @ Vector((rng.uniform(-4, 4), 0, h + 3.0)), rng.uniform(3.0, 4.2), rng, region=region)


def small_skep(x, z, rng, region):
    y = H(x, z)
    m = at(x, z, y, rng.uniform(0, 6.28))
    place("Skeps", "bark_trellis", bbox((5.0, 5.0, 4.0), 0.4), m, region)
    place("Skeps", "bark_straw", ring_prism([(3.6, 4.0), (3.8, 6.0), (3.0, 8.4), (1.6, 10.0), (0.3, 10.6)], 10), m, region)


def great_skep(x, z, rng):
    """THE landmark: a coiled-straw skep about 320 studs tall: fat straw rings stacked into a bell dome round a solid
    core, a round coral door with a timber hood, round windows, a gold knob, honey dripping from the crown."""
    y = H(x, z)
    yaw = facing(x, z, 0.0, 0.0)
    m = at(x, z, y, yaw) @ Matrix.Scale(1.6, 4)
    Hd, R = 200.0, 92.0  # local sizes; the whole skep is scaled 1.6 x (about 320 tall)

    def r_at(h):
        return max(6.0, R * (1.0 - (h / Hd) ** 2.4) ** 0.5)

    prof = [(r_at(h) - 3.0, h) for h in (0, 20, 40, 60, 80, 100, 120, 140, 160, 175, 188, 196)] + [(1.0, 199.0)]
    place("Skep", "bark_strawdk", ring_prism(prof, 24), m, "Skep")
    k, h = 0, 5.0
    while h < Hd - 6.0:
        rr = r_at(h)
        ring = hoop(rr, 6.2, sides=6, n=36)
        place("Skep", "bark_straw" if k % 2 == 0 else "bark_strawdk", ring, m @ T(0, 0, h) @ Rx(math.pi / 2), "Skep")
        h += 11.5
        k += 1
    place("Skep", "cloth_honey", ring_prism([(8.0, 0.0), (5.0, 8.0), (0.5, 12.0)], 10), m @ T(0, 0, Hd - 4.0), "Skep")
    # the door: a round-topped coral door with a timber hood, facing the arena
    place("Skep", "leaf_blossom", bbox((26.0, 8.0, 22.0), 0.8), m @ T(0, -r_at(10.0) + 2.0, 0.0), "Skep")
    place("Skep", "leaf_blossom", ring_prism([(13.0, -4.0), (13.0, 4.0)], 14), m @ T(0, -r_at(22.0) + 2.0, 22.0) @ Rx(math.pi / 2), "Skep")
    place("Skep", "bark_trellis", hoop(16.0, 2.4, sides=5, n=12, arc=math.pi), m @ T(0, -r_at(22.0) - 3.0, 22.0), "Skep")
    for a, hw in ((-0.5, 70.0), (0.45, 100.0), (0.0, 130.0), (-0.9, 140.0), (0.95, 60.0)):
        rr = r_at(hw)
        p = m @ Rz(a) @ T(0, -rr - 1.0, hw)
        place("Skep", "stone_cream", hoop(7.0, 1.8, sides=5, n=14), p, "Skep")
        place("Skep", "cloth_bee", ring_prism([(6.0, -1.0), (6.0, 0.5)], 12), p @ T(0, 0.8, 0) @ Rx(math.pi / 2), "Skep")
    for k in range(9):  # honey dripping from under the crown
        a = k / 9 * math.tau + rng.uniform(-0.2, 0.2)
        hh = rng.uniform(150.0, 180.0)
        rr = r_at(hh)
        L = rng.uniform(10.0, 28.0)
        place("Skep", "cloth_honey", ring_prism([(3.2, 0.0), (2.4, -L * 0.7), (0.4, -L)], 6), m @ Rz(a) @ T(0, -rr - 2.0, hh), "Skep")
    for k, (a, rr, hh, s) in enumerate(((-0.9, 150.0, 150.0, 1.0), (0.7, 130.0, 210.0, 0.85), (2.6, 140.0, 120.0, 0.9))):
        bee(m @ Vector((math.sin(a) * rr, -math.cos(a) * rr, hh)), s * 21.0, yaw + a + 1.4, rng)
    DATA["skep"] = {"bees": "Map_Orchard_Bees_*"}


def bee(p, s, yaw, rng):
    """A giant chunky bee: a fat gold body with dark bands, a dark head, two cream wings."""
    m = Matrix.Translation(Vector(p)) @ Rz(yaw)
    body = lump(s, rng, squash=0.9, jitter=0.05, subdiv=2, flat_bottom=0.9)
    place("Bees", "cloth_honey", body, m @ Matrix.Diagonal((1.45, 1.0, 1.0, 1.0)), "Bees")
    for q in (-0.35, 0.25):
        place("Bees", "cloth_bee", hoop(s * 0.98, s * 0.16, sides=6, n=20), m @ T(q * s * 1.4, 0, 0) @ Rz(math.pi / 2) @ Matrix.Diagonal((1.0, 1.0, 0.98, 1.0)), "Bees")
    head = lump(s * 0.6, rng, squash=1.0, jitter=0.05, subdiv=1, flat_bottom=1.0)
    place("Bees", "cloth_bee", head, m @ T(s * 1.6, 0, s * 0.1), "Bees")
    for sy in (-1, 1):
        w = ring_prism([(s * 0.9, -0.3), (s * 0.9, 0.3)], 10, sx=0.55, sy=1.0)
        place("Bees", "stone_cream", w, m @ T(-s * 0.2, sy * s * 1.1, s * 0.9) @ Rx(sy * 0.5), "Bees")


MAIN = (300.0, -1250.0)
SKEP = (-180.0, -1080.0)  # whole in a fighter's view


def islands():
    """The orchard's own layout (review 2026-11-21): the skep north-west, the main orchard north-east, terraces east
    and west too, not only north."""
    rng = random.Random(113)
    terrace_isle("Main", MAIN[0], MAIN[1], 250.0, 175.0, 20.0, levels=3, rise=14.0, depth=160.0, rng=rng)
    terrace_isle("Skep", SKEP[0], SKEP[1], 220.0, 200.0, 10.0, levels=1, depth=150.0, rng=rng, trees=False)
    terrace_isle("Tunnel", -860.0, -700.0, 150.0, 90.0, 0.0, levels=2, rise=10.0, depth=90.0, rng=rng)
    terrace_isle("Glass", 640.0, -700.0, 130.0, 96.0, -6.0, levels=2, rise=10.0, depth=90.0, rng=rng)
    terrace_isle("North", -100.0, -1750.0, 210.0, 130.0, 50.0, levels=3, rise=14.0, depth=130.0, rng=rng)
    terrace_isle("TerraceE", 880.0, -220.0, 56.0, 42.0, -120.0, levels=1, depth=56.0, rng=rng)
    terrace_isle("TerraceW", -560.0, -560.0, 60.0, 44.0, -100.0, levels=1, depth=56.0, rng=rng)
    terrace_isle("OrchardE", 1200.0, -1100.0, 200.0, 140.0, 10.0, levels=2, rise=14.0, depth=120.0, rng=rng)
    terrace_isle("OrchardW", -1300.0, -1250.0, 200.0, 140.0, 20.0, levels=2, rise=14.0, depth=120.0, rng=rng)
    terrace_isle("FarNE", 1600.0, -2300.0, 240.0, 150.0, 8.0, levels=2, rise=16.0, depth=140.0, rng=rng)
    terrace_isle("FarNW", -1500.0, -2200.0, 260.0, 160.0, 16.0, levels=2, rise=16.0, depth=140.0, rng=rng)
    terrace_isle("FarN", 400.0, -3000.0, 300.0, 180.0, 40.0, levels=3, rise=18.0, depth=150.0, rng=rng)


def dressing():
    rng = random.Random(127)
    great_skep(SKEP[0], SKEP[1] - 10.0, rng)
    i = ISLES["Skep"]
    for k in range(8):
        a = k / 8 * math.tau + 0.2
        x, z = i["cx"] + math.cos(a) * i["rx"] * 0.82, i["cz"] + math.sin(a) * i["rz"] * 0.82
        blossom_tree(x, z, rng.uniform(2.2, 2.7), rng, "Skep")
    for k in range(5):
        a = rng.uniform(0, math.tau)
        small_skep(i["cx"] + math.cos(a) * i["rx"] * 0.68, i["cz"] + math.sin(a) * i["rz"] * 0.68, rng, "Skep")
    cx, cz = MAIN
    glasshouse(cx + 20.0, cz + 20.0, 44.0, 26.0, 14.0, rng, "Main")
    for k in range(6):
        a = rng.uniform(0, math.tau)
        small_skep(cx + math.cos(a) * 110, cz + math.sin(a) * 78, rng, "Main")
    i = ISLES["Tunnel"]
    trellis_tunnel(i["cx"] - 110, i["cz"] + 10, i["cx"] + 100, i["cz"] - 20, rng, "Tunnel")
    i = ISLES["Glass"]
    glasshouse(i["cx"], i["cz"], 40.0, 24.0, 13.0, rng, "Glass")
    i = ISLES["North"]
    trellis_tunnel(i["cx"] - 60, i["cz"] + 60, i["cx"] + 90, i["cz"] + 40, rng, "North")
    for name in ("FarNE", "FarNW", "OrchardE"):
        i = ISLES[name]
        glasshouse(i["cx"] + 20, i["cz"] + 10, 40.0, 24.0, 13.0, rng, name)


sketch_run(NAME, [surface, edge, islands, dressing], orchard, landmark=("Skep", "Bees"))
