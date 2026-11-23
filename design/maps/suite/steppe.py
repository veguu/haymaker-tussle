"""Map 3 of the suite, "The Kite Ridge" (Highwind Steppe, from Kitestead). DESIGN BLOCKOUT 2026-11-21: NOT APPROVED.

    blender -b --factory-startup -P steppe.py -- <out folder> --dry --no-render

IDEA (five words): a woven mat in the wind. Herders of a high, windy plateau in the sky wrestle on a giant woven
straw mat; their wind-cut ridges, tents and kites fly round it.
  - Floor: the whole oval is ONE hand-woven straw mat in mid tones: a TWILL weave (diagonal ribs; basket and plain
    weaves read as a checkerboard from a fighter's eye) of 2.4-stud strands that wander, vary in width and each have
    their own shade, broad sun-bleached and worn patches, ochre dust, and a coral binding with a frayed inner edge.
    No end bands (with the border they read as a court).
  - Edge: the binding rolls over the rim as a fat coral hem over felt, streamers tied along it blowing downwind;
    under that, ONE wind-sculpted mass of plateau rock (dune, ochre, rust from top to bottom, shallow wind grooves,
    no steps: steps are the quarry's) sweeping into a long tail to the east like a comet.
  - Background (its own layout: kite north-north-west, camp north, ridges east and west too): long rounded golden
    ridges, each with a cairn and a cluster of tall poles hung with long vertical coral, gold and indigo
    banners (clusters, not rows: rows read as the lobby's bunting); the herders' camp (round felt tents with coral
    bands and gold crowns, racks of rugs drying, the kite winch tower); a corral with woolly herd animals; small kites
    flying from the ridges; two low mesas off the sides; two ridges far east and west; three far ridges.
  - LANDMARK: the Great Kite, a chunky coral, gold and cream diamond kite about 360 studs wide and 490 tall, flying
    about 330 studs up in the north-north-west on a tether from the winch tower, a long ribbon tail streaming downwind.
    Far bigger than anything else; it bobs (one moved part).
  - Feel: the wind. Gusts you can see: a few thin translucent streaks sweep across at knee height from west to east
    (Beams scrolling their texture: no script cost; nothing stands on the floor and nothing hides a fighter), every
    streamer and banner whips the same way, and the kite bobs (1 moved part, about 5 us a frame).
"""
import os

_d = os.path.dirname(os.path.abspath(__file__))
for _f in ("base.py", "sketch_kit.py"):
    _p = os.path.join(_d, _f)
    exec(compile(open(_p, encoding="utf-8").read(), _p, "exec"))

NAME = "Steppe"
PAL.update(
    {
        "cloth_straw": (srgb(198, 160, 94), srgb(226, 194, 132), srgb(140, 108, 66)),
        "cloth_felt": (srgb(242, 232, 210), srgb(255, 248, 232), srgb(176, 166, 160)),
        "cloth_feltdk": (srgb(196, 172, 136), srgb(222, 200, 166), srgb(132, 114, 96)),
        "cloth_indigo": (srgb(70, 112, 150), srgb(112, 152, 186), srgb(44, 70, 104)),
        "cloth_rug": (srgb(196, 92, 72), srgb(226, 134, 108), srgb(128, 56, 52)),
        "stone_dune": (srgb(214, 178, 128), srgb(236, 206, 162), srgb(150, 120, 96)),
        "stone_ochre": (srgb(196, 134, 82), srgb(224, 172, 118), srgb(128, 86, 62)),
        "stone_rust": (srgb(166, 94, 66), srgb(200, 132, 100), srgb(106, 58, 50)),
        "stone_umber": (srgb(146, 90, 62), srgb(182, 126, 94), srgb(94, 56, 46)),
        "leaf_steppe": (srgb(196, 162, 92), srgb(222, 192, 124), srgb(136, 108, 64)),
        "bark_pole": (srgb(150, 104, 66), srgb(190, 140, 96), srgb(92, 62, 46)),
        "cloth_wool": (srgb(240, 232, 214), srgb(255, 250, 236), srgb(178, 170, 160)),
        "cloth_muzzle": (srgb(96, 72, 60), srgb(132, 104, 86), srgb(60, 44, 40)),
        "cloth_rope": (srgb(214, 186, 132), srgb(236, 214, 170), srgb(150, 124, 90)),
    }
)

# --- the fighting surface: one hand-woven straw mat ------------------------------------------------------------------
WEAVE = {"straw": (198, 160, 94), "strawdk": (182, 144, 84), "coral": (204, 104, 80), "ochre": (176, 122, 74)}


def weave(X, Z):
    c = {k: P.rgb(*v) for k, v in WEAVE.items()}
    # hand-woven: strands wander and vary in width, so the cells are uneven (a regular grid read as tiles)
    wz = Z + 2.2 * np.sin(X / 47.0 + 0.3) + 3.0 * (P.fbm2(X / 70.0, Z / 25.0, 11, 2) - 0.5)
    wx = X + 2.2 * np.sin(Z / 41.0 + 1.1) + 3.0 * (P.fbm2(Z / 70.0, X / 25.0, 12, 2) - 0.5)
    uz = wz / 2.4 + 0.35 * np.sin(wz / 7.0)
    ux = wx / 2.4 + 0.35 * np.sin(wx / 8.0)
    row, colm = np.floor(uz), np.floor(ux)
    fz, fx = uz - row, ux - colm
    # a TWILL (over two, under two, each row one strand on): diagonal ribs. Basket and plain weaves both read as a
    # checkerboard from a fighter's eye (first two tries).
    horiz = np.mod(colm - row, 4) < 2
    across = np.where(horiz, fz, fx)
    prof = np.sin(np.pi * across)
    # every strand its own shade, so the eye follows strands (a weave), not squares
    weft = c["straw"] * (0.86 + 0.26 * P.hash01(4, row))[..., None]
    warp = c["strawdk"] * (0.86 + 0.26 * P.hash01(3, colm))[..., None]
    col = np.where(horiz[..., None], weft, warp)
    # no end bands: a border plus two end bands read as a court with end zones (re-check 2026-11-21)
    along = np.where(horiz, X, Z)
    fib = P.fbm2(along / 3.0, np.where(horiz, Z, X) * 2.5, 13, 2) - 0.5
    col = col * (0.91 + 0.11 * prof + 0.06 * fib)[..., None]
    # broad wear, bleach and shade dominate the look from a fighter's eye
    col = col * (1.0 + 0.26 * (P.fbm2(X / 70.0, Z / 70.0, 21, 3) - 0.5) + 0.12 * (P.fbm2(X / 18.0, Z / 18.0, 22, 2) - 0.5))[..., None]
    dust = P.fbm2(X / 40.0 + 3.0, Z / 40.0 - 2.0, 33, 3)
    col = P.mix(col, c["ochre"], 0.25 * P.smoothstep(0.58, 0.8, dust))
    d = edge_dist(X, Z) + (P.hash01(10, np.floor(X / 3.0), np.floor(Z / 3.0)) - 0.5) * 2.0
    bind = P.smoothstep(8.6, 7.8, d)
    col = P.mix(col, c["coral"] * (0.82 + 0.2 * np.sin(np.pi * np.clip(d / 8.0, 0.0, 1.0)))[..., None], bind)
    return np.clip(col, 0.0, 1.0)


def surface():
    floor_tiles(NAME, "Floor", "Mat", "cloth_straw", 0.0, weave, nx=3, nz=2)


# --- the edge: hem, felt, streamers, one wind-sculpted mass sweeping into a tail ---------------------------------------
def ribbon(p0, length, drift, width, key, element, region, wiggle=2.5, phase=0.0, segs=8, along=None):
    """A streamer hanging from Blender point p0: down `length`, blown `drift` studs downwind (east), a gentle wave."""
    bm = bmesh.new()
    left, right = [], []
    for k in range(segs + 1):
        t = k / segs
        p = Vector(p0) + Vector((drift * t ** 1.4, math.sin(t * 6.0 + phase) * wiggle * t, -length * t))
        left.append(bm.verts.new(p + Vector((0, -width / 2, 0))))
        right.append(bm.verts.new(p + Vector((0, width / 2, 0))))
    for k in range(segs):
        bm.faces.new((left[k], right[k], right[k + 1], left[k + 1]))
    place(element, key, bm, region=region)


def loft(rings, key, element, region=""):
    """Quads between consecutive closed rings of Blender points (same count)."""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], b[i], b[j], a[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    place(element, key, bm, region=region)


def sculpted_mass(ring_at, levels, tip, element, region=""):
    """A wind-sculpted underside: rings from ring_at(f) (f 0 at the top to 1 at the bottom), shallow grooves on every
    other ring, coloured dune, ochre, rust from top to bottom, closed to a tip point."""
    rings = [ring_at(k / levels, k % 2 == 1) for k in range(levels + 1)]
    thirds = (levels // 3, 2 * levels // 3)
    for key, a, b in (("stone_dune", 0, thirds[0]), ("stone_ochre", thirds[0], thirds[1]), ("stone_rust", thirds[1], levels)):
        loft(rings[a : b + 1], key, element, region)
    bm = bmesh.new()
    last = [bm.verts.new(p) for p in rings[-1]]
    t = bm.verts.new(tip)
    for i in range(len(last)):
        bm.faces.new((last[i], last[(i + 1) % len(last)], t))
    bm.faces.new(list(reversed([bm.verts.new(p) for p in rings[0]])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    place(element, "stone_umber", bm, region=region)


def edge():
    rng = random.Random(31)
    course("Hem", "Coral", "cloth_coral", -0.6, 4.0, -5.0, -0.04, rng, 5.0, 8.0, gap=0.0, outer_chamfer=1.8, inner_chamfer=0.1)
    course("Felt", "Feltdk", "cloth_feltdk", 0.6, 8.0, -9.0, -5.0, rng, 8.0, 12.0, gap=0.0, top_chamfer=0.5)
    n = 96

    def ring_at(f, groove):
        inset = 3.0 + f ** 1.3 * 172.0 + (2.5 if groove else 0.0)
        shift = f ** 1.8 * 168.0  # east of x 208 at most: never out past the edge
        h = -9.0 - f * 150.0
        return [W(oval(i / n * math.tau, min(inset, 174.0))[0] + shift, oval(i / n * math.tau, min(inset, 174.0))[1], h) for i in range(n)]

    sculpted_mass(ring_at, 14, W(196.0, 0.0, -178.0), "Plateau")
    for k in range(22):
        t = (k + 0.5) / 22 * math.tau
        x, z, nx, nz = oval(t, -0.5)
        ribbon(W(x, z, -4.0), rng.uniform(22, 34), rng.uniform(10, 18), 3.0, ("cloth_coral", "cloth_gold", "cloth_felt")[k % 3], "Streamers", "", phase=k)


# --- islands: golden plateau tops, sculpted undersides trailing east ----------------------------------------------------
def strata_isle(name, cx, cz, rx, rz, top, crest=0.0, hill=0.0, flat=None, depth=None, rng=None):
    ridge = (lambda u, v: crest * math.exp(-(v / 0.38) ** 2) * (1.0 - 0.6 * u * u)) if crest else None
    i = isle(name, cx, cz, rx, rz, top, hill=hill, flat=flat, shape=ridge)
    isle_top(i, "leaf_steppe", "stone_dune", side=7.0)
    depth = depth or min(rx, rz) * 1.1
    n = 28

    def ring_at(f, groove):
        k = (1.0 - 0.85 * f ** 1.2) * (0.97 if groove else 1.0)
        out = []
        for q in range(n):
            a = q / n * math.tau
            o = outline(i, a)
            out.append(W(cx + math.cos(a) * rx * o * k + f ** 1.6 * depth * 1.2, cz + math.sin(a) * rz * o * k, top - 7.0 - f * depth))
        return out

    sculpted_mass(ring_at, 8, W(cx + depth * 1.9, cz, top - 7.0 - depth * 1.15), "Island", region=name)
    rng = rng or random.Random(i["s"])
    for k in range(max(2, int(rx * rz / 5000))):  # boulders on the dry grass
        a, r = rng.uniform(0, math.tau), math.sqrt(rng.uniform(0.05, 0.7))
        x, z = cx + math.cos(a) * rx * r, cz + math.sin(a) * rz * r
        s = rng.uniform(5, 10)
        place("Island", "stone_ochre", chunk((s * 1.3, s, s * 0.7), rng, cuts=7, bevel=0.0), at(x, z, H(x, z) - s * 0.2, rng.uniform(0, 6.28)), region=name)
    return i


def tent(x, z, r, rng, region, roof="cloth_coral"):
    """A round felt tent: cream felt walls with a coral band, a low cone roof, a gold crown, an indigo door."""
    y = H(x, z)
    m = at(x, z, y, facing(x, z, 0.0, 0.0))
    place("Camp", "cloth_felt", ring_prism([(r, -1.0), (r, r * 0.55)], 12), m, region)
    place("Camp", "cloth_coral", annulus(r - 0.3, r + 0.6, r * 0.22, r * 0.36, 12), m, region)
    place("Camp", roof, ring_prism([(r + 1.6, r * 0.5), (r * 0.5, r * 0.5 + r * 0.42), (r * 0.16, r * 0.5 + r * 0.56)], 12), m, region)
    place("Camp", "cloth_gold", ring_prism([(r * 0.2, r * 1.04), (r * 0.12, r * 1.18)], 8), m, region)
    place("Camp", "cloth_indigo", bbox((r * 0.45, 1.2, r * 0.42), 0.3), m @ T(0, -r + 0.2, 0.0), region)


def pole_cluster(x, z, rng, region, n=4, tall=(44.0, 70.0)):
    """A summit cairn with a cluster of tall poles, each hung with one long vertical banner blowing a little east
    and a short streamer at the top. Clusters, never rows (rows of flags read as bunting)."""
    y = H(x, z)
    for q in range(4):
        s = 7.0 - q * 1.4
        place("Poles", "stone_dune" if q % 2 else "stone_ochre", chunk((s * 1.4, s * 1.2, s * 0.7), rng, cuts=6, bevel=0.0), at(x, z, y - 0.5 + q * s * 0.55, rng.uniform(0, 6.28)), region)
    for k in range(n):
        a = k / n * math.tau + rng.uniform(-0.3, 0.3)
        px, pz = x + math.cos(a) * rng.uniform(8, 14), z + math.sin(a) * rng.uniform(8, 14)
        h = rng.uniform(*tall)
        base, top = W(px, pz, y - 1.0), W(px, pz, y + h)
        place("Poles", "bark_pole", rod(base, top, 1.1, 6), region=region)
        place("Poles", "cloth_gold", ring_prism([(1.7, 0.0), (0.2, 3.0)], 6), Matrix.Translation(top), region)
        key = rng.choice(("cloth_coral", "cloth_gold", "cloth_indigo", "cloth_coral", "cloth_felt"))
        ribbon(top + Vector((0.6, 0, -2.5)), h * 0.6, h * 0.12, 5.5, key, "Poles", region, wiggle=1.4, phase=k, segs=10)
        ribbon(top + Vector((0.6, 0, -0.8)), 4.0, h * 0.35, 1.4, "cloth_felt", "Poles", region, wiggle=1.2, phase=k * 2.0)


def kite(cx, cz, alt, w, h_up, h_dn, keys, region, tether_from=None, tail_len=None, element="Kites"):
    """A chunky diamond kite facing the arena, tipped back, quartered in two colours, thick cross spars, a long
    ribbon tail streaming downwind (a ribbon, not bows on a line: those read as bunting), a tether."""
    yaw = facing(cx, cz, 0.0, 0.0)
    m = at(cx, cz, alt, yaw) @ Rx(-0.32)
    th = max(0.8, w * 0.018)
    quads = [((0, 0), (-w / 2, 0), (0, h_up)), ((0, 0), (0, h_up), (w / 2, 0)), ((0, 0), (w / 2, 0), (0, -h_dn)), ((0, 0), (0, -h_dn), (-w / 2, 0))]
    for q, tri in enumerate(quads):
        bm = bmesh.new()
        front = [bm.verts.new((px, -th / 2, pz)) for px, pz in tri]
        back = [bm.verts.new((px, th / 2, pz)) for px, pz in tri]
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        for k in range(3):
            j = (k + 1) % 3
            bm.faces.new((front[k], front[j], back[j], back[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        place(element, keys[q % len(keys)], bm, m, region)
    sp = max(0.6, w * 0.014)
    place(element, "bark_pole", rod(m @ Vector((-w / 2, -th, 0)), m @ Vector((w / 2, -th, 0)), sp, 6), region=region)
    place(element, "bark_pole", rod(m @ Vector((0, -th, -h_dn)), m @ Vector((0, -th, h_up)), sp, 6), region=region)
    for s in (-1, 1):  # a frame round the edge, for a chunky outline
        place(element, "bark_pole", rod(m @ Vector((0, -th, h_up)), m @ Vector((s * w / 2, -th, 0)), sp * 0.7, 5), region=region)
        place(element, "bark_pole", rod(m @ Vector((s * w / 2, -th, 0)), m @ Vector((0, -th, -h_dn)), sp * 0.7, 5), region=region)
    bottom = m @ Vector((0, 0, -h_dn))
    tail_len = tail_len or h_dn * 1.6
    segs = 12
    pts = [bottom + Vector((tail_len * 0.5 * (k / segs) ** 1.3, math.sin(k * 0.9) * w * 0.03, -tail_len * (k / segs) + tail_len * 0.3 * (k / segs) ** 2)) for k in range(segs + 1)]
    wd = w * 0.05
    for k in range(segs):
        bm = bmesh.new()
        a, b = pts[k], pts[k + 1]
        vs = [bm.verts.new(a + Vector((0, -wd / 2, 0))), bm.verts.new(a + Vector((0, wd / 2, 0))), bm.verts.new(b + Vector((0, wd / 2 * 0.9, 0))), bm.verts.new(b + Vector((0, -wd / 2 * 0.9, 0)))]
        bm.faces.new(vs)
        place(element, keys[(k // 2) % len(keys)], bm, region=region)
    if tether_from is not None:
        bridle = m @ Vector((0, -w * 0.15, -h_dn * 0.15))
        place(element, "cloth_rope", rod(Vector(tether_from), bridle, sp * 0.5, 5), region=region + "T")


def winch_tower(x, z):
    """The kite-keepers' winch tower: a stone foot, a timber tower, a big rope drum at the top."""
    y = H(x, z)
    m = at(x, z, y, facing(x, z, KITE[0], KITE[1]))
    place("Camp", "stone_dune", bbox((32.0, 32.0, 14.0), 0.8, (0.9, 0.9)), m @ T(0, 0, -2.0), "Camp")
    for sx in (-1, 1):
        for sy in (-1, 1):
            place("Camp", "bark_pole", rod(m @ Vector((sx * 13, sy * 13, 10.0)), m @ Vector((sx * 6, sy * 6, 80.0)), 1.8, 6), region="Camp")
    for hh in (30.0, 56.0):
        place("Camp", "bark_pole", bbox((24.0 - hh * 0.12, 24.0 - hh * 0.12, 2.0), 0.3), m @ T(0, 0, hh), "Camp")
    place("Camp", "bark_pole", bbox((20.0, 20.0, 3.0), 0.4), m @ T(0, 0, 78.0), "Camp")
    place("Camp", "cloth_rope", ring_prism([(8.0, -10.0), (8.0, 10.0)], 12), m @ T(0, 0, 90.0) @ Ry(math.pi / 2), "Camp")
    for sx in (-1, 1):
        place("Camp", "bark_pole", bbox((2.0, 4.0, 15.0), 0.3), m @ T(sx * 11.0, 0, 81.0), "Camp")
    return m @ Vector((0, 0, 96.0))


def rug_rack(x, z, rng, region):
    y = H(x, z)
    m = at(x, z, y, rng.uniform(-0.4, 0.4))
    for sx in (-1, 1):
        place("Camp", "bark_pole", bbox((1.4, 1.4, 14.0), 0.2), m @ T(sx * 16.0, 0, 0), region)
    place("Camp", "bark_pole", rod(m @ Vector((-16.0, 0, 13.0)), m @ Vector((16.0, 0, 13.0)), 0.5, 4), region=region)
    for k in range(3):
        place("Camp", rng.choice(("cloth_rug", "cloth_gold", "cloth_coral", "cloth_indigo")), bbox((8.0, 0.4, 10.0), 0.1), m @ T(-10.0 + k * 10.0, 0, 3.0), region)


def beast(x, z, rng, region):
    """A woolly herd animal: a fat wool lump, a dark muzzle, short legs, curled horns."""
    y = H(x, z)
    m = at(x, z, y, rng.uniform(0, 6.28))
    body = lump(5.5, rng, squash=0.75, jitter=0.12, subdiv=1, flat_bottom=0.3)
    place("Herd", "cloth_wool", body, m @ T(0, 0, 6.5) @ Matrix.Diagonal((1.35, 1.0, 1.0, 1.0)), region)
    place("Herd", "cloth_muzzle", bbox((3.4, 4.0, 3.6), 0.8), m @ T(7.2, 0, 6.0) @ Rz(math.pi / 2), region)
    for sx in (-1, 1):
        for sy in (-1, 1):
            place("Herd", "cloth_muzzle", bbox((1.4, 1.4, 3.0), 0.3), m @ T(sx * 3.4, sy * 2.4, 0.0), region)
        place("Herd", "cloth_wool", hoop(1.4, 0.45, sides=4, n=8, arc=math.pi * 1.4), m @ T(8.0, sx * 1.8, 9.6), region)


CAMP = (-200.0, -1150.0)
KITE = (-250.0, -1500.0, 330.0)  # low and central enough to sit whole in a fighter's view


def islands():
    strata_isle("Camp", CAMP[0], CAMP[1], 280.0, 140.0, 24.0, crest=10.0, flat=(CAMP[0] - 20.0, CAMP[1] + 10.0, 180.0, 26.0), depth=150.0)
    strata_isle("RidgeE", 420.0, -760.0, 200.0, 36.0, 0.0, crest=64.0, depth=80.0)
    strata_isle("RidgeW", -700.0, -700.0, 170.0, 34.0, -10.0, crest=56.0, depth=76.0)
    strata_isle("Herd", 700.0, -1250.0, 160.0, 116.0, 16.0, hill=8.0, depth=110.0)
    strata_isle("RidgeN", 150.0, -1800.0, 280.0, 44.0, 60.0, crest=70.0, depth=110.0)
    strata_isle("RidgeNW", -950.0, -1300.0, 220.0, 40.0, 30.0, crest=60.0, depth=90.0)
    strata_isle("MesaE", 720.0, -380.0, 54.0, 42.0, -110.0, hill=4.0, depth=60.0)
    strata_isle("MesaW", -760.0, -180.0, 58.0, 44.0, -120.0, hill=4.0, depth=60.0)
    strata_isle("RidgeFarE", 1250.0, -500.0, 240.0, 46.0, -20.0, crest=70.0, depth=100.0)
    strata_isle("RidgeFarW", -1300.0, -900.0, 260.0, 46.0, 0.0, crest=70.0, depth=100.0)
    strata_isle("FarNE", 1800.0, -2000.0, 300.0, 70.0, 10.0, crest=60.0, depth=110.0)
    strata_isle("FarNW", -1300.0, -2400.0, 300.0, 74.0, 16.0, crest=60.0, depth=110.0)
    strata_isle("FarN", 500.0, -2900.0, 340.0, 80.0, 40.0, crest=60.0, depth=120.0)


def camp():
    rng = random.Random(67)
    cx, cz = CAMP
    for k, (dx, dz, r) in enumerate(((-170, -30, 17), (-120, 40, 15), (-70, -55, 19), (-20, 30, 14), (30, -40, 16), (-200, 50, 13), (60, 35, 15), (-110, -95, 13), (-150, 95, 12))):
        tent(cx + dx, cz + dz, r, rng, "Camp", roof=("cloth_coral", "cloth_gold", "cloth_felt")[k % 3])
    for dx, dz in ((-90, 0), (10, -5), (-180, 10)):
        rug_rack(cx + dx, cz + dz, rng, "Camp")
    tower_top = winch_tower(cx + 110, cz - 10)
    pole_cluster(cx + 200, cz + 10, rng, "Camp", n=5)
    for name in ("RidgeE", "RidgeW", "RidgeN", "RidgeNW", "RidgeFarE", "RidgeFarW", "FarNE", "FarNW", "FarN"):
        i = ISLES[name]
        far = name.startswith("Far") or name.endswith("FarE") or name.endswith("FarW")
        pole_cluster(i["cx"] - i["rx"] * 0.25, i["cz"], rng, name, n=rng.randint(3, 5), tall=(60.0, 90.0) if far else (44.0, 70.0))
        if i["rx"] > 190:
            pole_cluster(i["cx"] + i["rx"] * 0.45, i["cz"], rng, name, n=3, tall=(60.0, 90.0) if far else (40.0, 60.0))
    i = ISLES["Herd"]
    for hh in (4.0, 8.0):
        place("Herd", "bark_pole", hoop(56.0, 0.8, sides=4, n=28), at(i["cx"], i["cz"], H(i["cx"], i["cz"]) + hh) @ Rx(math.pi / 2), "Herd")
    for k in range(18):
        a = k / 18 * math.tau
        x, z = i["cx"] + math.cos(a) * 56, i["cz"] + math.sin(a) * 56
        place("Herd", "bark_pole", bbox((1.6, 1.6, 10.0), 0.2), at(x, z, H(x, z) - 1.0), "Herd")
    for k in range(7):
        a, r = rng.uniform(0, math.tau), rng.uniform(0, 40)
        beast(i["cx"] + math.cos(a) * r, i["cz"] + math.sin(a) * r, rng, "Herd")
    tent(i["cx"] - 90, i["cz"] + 40, 15, rng, "Herd")
    tent(i["cx"] + 95, i["cz"] - 30, 13, rng, "Herd", roof="cloth_gold")
    for name in ("MesaE", "MesaW"):
        i = ISLES[name]
        tent(i["cx"] - 10, i["cz"], 11, rng, name)
        pole_cluster(i["cx"] + 22, i["cz"] + 6, rng, name, n=2, tall=(26.0, 34.0))
    for k, (kx, kz, alt, w, src) in enumerate(((560, -900, 200, 40, "RidgeE"), (260, -640, 150, 30, "RidgeE"), (-640, -860, 180, 36, "RidgeW"), (-1000, -1150, 250, 40, "RidgeNW"), (820, -1420, 240, 40, "Herd"), (300, -1980, 320, 46, "RidgeN"), (1250, -700, 220, 40, "RidgeFarE"))):
        i = ISLES[src]
        anchor = W(i["cx"] + rng.uniform(-40, 40), i["cz"], H(i["cx"], i["cz"]) + 4.0)
        keys = (("cloth_coral", "cloth_gold"), ("cloth_felt", "cloth_coral"), ("cloth_gold", "cloth_indigo"))[k % 3]
        kite(kx, kz, alt, w, w * 0.55, w * 0.85, keys, f"Kite{k}", tether_from=anchor)
    # THE landmark: the Great Kite on its tether from the winch tower
    kite(KITE[0], KITE[1], KITE[2], 360.0, 190.0, 300.0, ("cloth_coral", "cloth_gold", "cloth_felt", "cloth_gold"), "GreatKite", tether_from=tower_top, tail_len=520.0, element="GreatKite")


sketch_run(NAME, [surface, edge, islands, camp], weave, landmark=("GreatKite",), floor_px=1024)
