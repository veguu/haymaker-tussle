"""Map 2 of the suite, "The Limestone Pit" (Sunbaked Quarry). DESIGN BLOCKOUT 2026-11-21: NOT APPROVED, NOT BUILT.

    blender -b --factory-startup -P quarry.py -- <out folder> --dry --no-render

IDEA (five words): a sky quarry, still cutting. The arena is the freshly sawn top of a giant sandstone block that
quarrymen are cutting free in open sky; their works float round it.
  - Floor (OWNER 2026-11-21, picked from a 4-option sheet: "a floor I would walk on"): BIG FLAGSTONES, irregular cut
    flags about 8 studs across with painted bevels and sand joints a little darker than the stone, as a seamless detail
    image (floor_options.py option_d, patterns/flagstones_d.png) laid on the floor tiles as a Roblox Texture, over a
    CALM colour map (calm_floor: low chroma, soft large patches; fighters stay the most saturated thing on screen).
    The first floor, superseded: Folded strata (honey, tan, rose, umber; no cream) about 18 studs wide,
    crisp-edged and bent at angles (soft waves read as dunes, straight ones as pitch stripes), chalk dust drifting
    over it; the last few studs darken to the cut edge. No joints, no lines, no rim band, no fine chisel strokes
    (they shimmered and read as sand ripples).
  - Edge: the block's sides cut in eight crisp benches, each stepping IN as it goes down, to a point (an upside-down
    stepped pyramid: nothing sticks out as a ledge). Timber scaffolds and ladders cling under the benches; two cut
    blocks hang on ropes.
  - Background (open sky; its own layout: derrick east-north-east, yard north, hamlet and pit west, blocks east
    and west as well): the stone-yard island (stone workshops with canvas roofs, stacks of cut blocks under teal
    canvas, a treadwheel crane, a guild tower), the quarrymen's hamlet (flat-roofed lime-washed houses with water
    jars on the roofs, dark cypress spires), a block with an open pit cut into its top, rope bridges, cut blocks
    drifting loose, low block rafts off the sides, two blocks east and west, three far blocks.
  - LANDMARK: the Great Derrick, a timber crane about 410 studs tall braced by sheer-legs, its boom swung out
    ACROSS the view (so its arm reads from the arena) with a house-sized block hanging from it, a treadwheel at its
    foot. Boom, ropes and load are their own meshes (the game can swing them slowly: one moved part).
  - Feel: chalk dust. Landings and knockback slides kick up pale dust (particles fired on those events only, not
    every step: 25 players on phones), and the crane's boom swings slowly (1 moved part, about 5 us a frame).
"""
import os

_d = os.path.dirname(os.path.abspath(__file__))
for _f in ("base.py", "sketch_kit.py"):
    _p = os.path.join(_d, _f)
    exec(compile(open(_p, encoding="utf-8").read(), _p, "exec"))

NAME = "Quarry"
PX.update({"Scaffold": 512})  # small pieces under the benches, seen only from the rim (fresh review 2026-11-21)
PAL.update(
    {
        "stone_honey": (srgb(222, 176, 116), srgb(242, 206, 152), srgb(150, 112, 84)),
        "stone_rose": (srgb(208, 146, 116), srgb(232, 182, 152), srgb(140, 92, 84)),
        "stone_tan": (srgb(232, 200, 150), srgb(248, 224, 182), srgb(160, 130, 104)),
        "stone_chalk": (srgb(242, 230, 208), srgb(255, 248, 234), srgb(172, 162, 156)),
        "stone_umber": (srgb(178, 128, 92), srgb(210, 164, 124), srgb(114, 80, 66)),
        "plaster_lime": (srgb(240, 228, 206), srgb(255, 246, 228), srgb(176, 164, 158)),
        "bark_crane": (srgb(160, 110, 68), srgb(200, 150, 100), srgb(96, 64, 48)),
        "bark_plank": (srgb(204, 160, 106), srgb(230, 194, 140), srgb(132, 96, 70)),
        "cloth_canvas": (srgb(84, 150, 148), srgb(132, 192, 186), srgb(50, 98, 104)),
        "cloth_rope": (srgb(214, 186, 132), srgb(236, 214, 170), srgb(150, 124, 90)),
        "leaf_cypress": (srgb(62, 112, 74), srgb(96, 146, 96), srgb(38, 76, 56)),
        "glow_lantern": (srgb(255, 204, 104), srgb(255, 230, 160), srgb(214, 150, 70)),
    }
)

# --- the fighting surface: a sliced sandstone block ----------------------------------------------------------------
# mid tones (review 2026-11-21: the first floor measured 198 of 255 from a fighter's eye, Map 1's grass 132)
SAND = {"honey": (166, 125, 83), "cream": (182, 158, 121), "tan": (175, 144, 103), "rose": (164, 109, 86), "deep": (144, 103, 72), "chalk": (197, 184, 162), "umber": (129, 90, 64)}


def sandstone(X, Z):
    c = {k: P.rgb(*v) for k, v in SAND.items()}
    # no cream in the strata: thin pale bands read as lines across the floor (re-check 2026-11-21)
    pal = np.stack([c["honey"], c["tan"], c["rose"], c["honey"], c["deep"], c["tan"], c["umber"], c["honey"], c["rose"], c["deep"]])
    # strata: bands 5 to 30 studs wide, folded at angles across the block (folded rock, so neither straight pitch
    # stripes nor soft dunes), each band edge crisp
    fold = np.abs(np.mod(X / 140.0 + P.fbm2(Z / 200.0, X / 200.0, 7, 2), 2.0) - 1.0) * 70.0
    s = Z * 0.9 + X * 0.3 + fold + (P.fbm2(X / 90.0 + 2.1, Z / 90.0 - 0.6, 8, 2) - 0.5) * 40.0
    s = s + (P.fbm2(s / 40.0, X / 300.0, 9, 2) - 0.5) * 30.0
    k = np.floor(s / 18.0)  # bands about 18 studs: wide enough never to read as lines
    f = s / 18.0 - k
    i0 = (P.hash01(5, k) * len(pal)).astype(np.int64) % len(pal)
    i1 = (P.hash01(5, k + 1) * len(pal)).astype(np.int64) % len(pal)
    col = P.mix(pal[i0], pal[i1], P.smoothstep(0.93, 1.0, f))
    col = col * (0.92 + 0.12 * P.hash01(6, k))[..., None]  # each layer its own shade
    col = col * (1.0 + 0.08 * (P.fbm2(X / 30.0, Z / 30.0, 23, 3) - 0.5) + 0.04 * (P.fbm2(X / 4.0, Z / 4.0, 24, 2) - 0.5))[..., None]
    dust = P.fbm2(X / 48.0 + 4.0, Z / 48.0 - 1.0, 31, 3)
    col = P.mix(col, c["chalk"], 0.2 * P.smoothstep(0.6, 0.8, dust))
    rho = np.sqrt((X / A) ** 2 + (Z / B) ** 2)
    col = P.mix(col, c["umber"], P.smoothstep(6.0, 0.0, (1.0 - rho) * B) * 0.45)
    return np.clip(col, 0.0, 1.0)


CALM = {"stone": (184, 170, 150), "warm": (190, 170, 142), "cool": (172, 164, 152), "edge": (150, 134, 118)}


def calm_floor(X, Z):
    """The colour under the flagstones (owner's pick, 2026-11-21): calm cut-stone greys and creams with soft patches
    tens of studs across, so the 40-stud flag pattern never reads as a repeat; a little darker toward the cut edge."""
    c = {k: P.rgb(*v) for k, v in CALM.items()}
    a = P.fbm2(X / 120.0 + 1.3, Z / 120.0 - 0.7, 81, 3)
    b = P.fbm2(X / 60.0 - 2.1, Z / 60.0 + 0.4, 82, 3)
    col = P.mix(c["cool"], c["warm"], P.smoothstep(0.35, 0.7, a))
    col = P.mix(col, c["stone"], 0.5)
    col = col * (0.94 + 0.12 * b)[..., None]
    rho = np.sqrt((X / A) ** 2 + (Z / B) ** 2)
    col = P.mix(col, c["edge"], P.smoothstep(6.0, 0.0, (1.0 - rho) * B) * 0.35)
    return np.clip(col, 0.0, 1.0)


def surface():
    floor_tiles(NAME, "Floor", "Stone", "stone_honey", 0.0, calm_floor, nx=3, nz=2)
    map_data(("Floor", "Bench", "Core", "Scaffold"), CALM["stone"], "Slate",
             floor_detail={"image": "patterns/flagstones_d.png", "tile": 40.0, "transparency": 0.0})


# --- the edge: eight benches stepping in to a point, scaffolds under them -------------------------------------------
STRATA = ("stone_honey", "stone_rose", "stone_tan", "stone_chalk", "stone_honey", "stone_umber", "stone_tan", "stone_rose")


def benches():
    out, inset, h = [], 0.0, -0.04
    for k, step in enumerate((12.0, 13.0, 15.0, 17.0, 19.0, 22.0, 25.0, 0.0)):
        out.append((inset, inset + 18.0, h - 15.0, h, STRATA[k]))
        inset += step
        h -= 15.0
    return out


def edge():
    rng = random.Random(23)
    bs = benches()
    for i0, i1, h0, h1, key in bs:
        course("Bench", mat_name(key), key, i0, i1, h0, h1, rng, 16.0, 30.0, gap=0.7, top_chamfer=0.8)
    last = bs[-1]
    place("Core", "stone_umber", oval_slab(8.0, last[0] + 10.0, -0.5, last[2] + 1.0, n=96))
    place("Core", "stone_umber", oval_slab(last[0] + 2.0, last[0] + 40.0, last[2] + 1.0, last[2] - 12.0, n=48))
    for k, t in enumerate((0.3, 1.25, 2.2, 3.5, 4.7, 5.6)):
        scaffold(t, rng, hang=k in (1, 4))


def scaffold(t, rng, hang=False):
    """Timber scaffolding under the benches at oval parameter t: posts hung from the first bench, two plank decks
    reaching in to the lower benches, a ladder, cross braces, a lantern; optionally a cut block on a rope."""
    x, z, nx, nz = oval(t, 0.0)
    m = at(x, z, 0.0, facing(x, z, x + nx, z + nz))  # local -y points out of the arena, +y in
    for px in (-10.0, 0.0, 10.0):
        for py in (3.0, 10.0):
            place("Scaffold", "bark_plank", bbox((1.8, 1.8, 46.0), 0.3), m @ T(px, py, -62.0))
    for h, reach in ((-31.0, 26.0), (-46.0, 41.0)):
        place("Scaffold", "bark_plank", bbox((24.0, reach - 1.0, 1.2), 0.3), m @ T(0, 1.0 + (reach - 1.0) / 2, h - 1.2))
        place("Scaffold", "bark_crane", bbox((24.0, 1.2, 1.8), 0.3), m @ T(0, 1.2, h))
    for px in (-10.0, 10.0):
        place("Scaffold", "bark_crane", rod(m @ Vector((px, 3.0, -60.0)), m @ Vector((0.0, 3.0, -33.0)), 0.6, 5))
    for rail in (-1.6, 1.6):
        place("Scaffold", "bark_crane", rod(m @ Vector((5.0 + rail, 2.0, -46.0)), m @ Vector((5.0 + rail, 5.0, -31.0)), 0.4, 4))
    for q in range(6):
        hq = -44.0 + q * 2.4
        place("Scaffold", "bark_crane", rod(m @ Vector((3.4, 2.0 + q * 0.5, hq)), m @ Vector((6.6, 2.0 + q * 0.5, hq)), 0.3, 4))
    place("Scaffold", "glow_lantern", bbox((1.6, 1.6, 2.4), 0.3), m @ T(-6.0, 2.0, -28.0))
    if hang:
        place("Scaffold", "cloth_rope", rod(m @ Vector((-4.0, 6.0, -15.0)), m @ Vector((-4.0, 6.0, -96.0)), 0.5, 5))
        place("Scaffold", "stone_tan", bbox((14.0, 12.0, 11.0), 0.6), m @ T(-4.0, 6.0, -107.0) @ Rz(rng.uniform(-0.3, 0.3)))


# --- islands: cut blocks floating in the sky, stepped underneath like the arena -------------------------------------
def block_isle(name, cx, cz, w, d, top, yaw=0.0, benches=4, step=10.0, bench_h=12.0):
    """A floating cut block: a chalk-topped body, then benches stepping in under it to a small bottom block."""
    isle(name, cx, cz, w / 2, d / 2, top, flat=(cx, cz, max(w, d), top))
    m = at(cx, cz, 0.0, yaw)
    place("Island", "stone_tan", bbox((w, d, 2.6), 0.4), m @ T(0, 0, top - 2.6), region=name)
    place("Island", "stone_honey", bbox((w - 0.8, d - 0.8, 12.0), 0.5), m @ T(0, 0, top - 14.6), region=name)
    h = top - 14.6
    for k in range(1, benches + 1):
        bw, bd = w - 2 * step * k, d - 2 * step * k
        if bw < 16 or bd < 16:
            break
        place("Island", STRATA[k % len(STRATA)], bbox((bw, bd, bench_h), 0.6), m @ T(0, 0, h - bench_h), region=name)
        h -= bench_h
    return m


def pit_isle(name, cx, cz, w, d, top, yaw, rng):
    """A block with an open quarry pit cut into its top: frames stepping down to a pit floor, benches under it."""
    isle(name, cx, cz, w / 2, d / 2, top, flat=(cx, cz, max(w, d), top))
    m = at(cx, cz, 0.0, yaw)
    s, hs = 14.0, 10.0
    for k in range(3):
        ow, od, iw, idp = w - 2 * s * k, d - 2 * s * k, w - 2 * s * (k + 1), d - 2 * s * (k + 1)
        h0 = top - hs * k
        key = ("stone_tan", "stone_honey", "stone_rose")[k]
        for sx, sy, cxo, cyo in ((ow, (od - idp) / 2, 0, (od + idp) / 4), (ow, (od - idp) / 2, 0, -(od + idp) / 4), ((ow - iw) / 2, idp, (ow + iw) / 4, 0), ((ow - iw) / 2, idp, -(ow + iw) / 4, 0)):
            place("Island", key, bbox((sx, sy, hs + 2), 0.5), m @ T(cxo, cyo, h0 - hs - 2), region=name)
    place("Island", "stone_chalk", bbox((w - 6 * s, d - 6 * s, 4), 0.5), m @ T(0, 0, top - 3 * hs - 4), region=name)
    place("Island", "stone_honey", bbox((w, d, 22), 0.5), m @ T(0, 0, top - 3 * hs - 26), region=name)
    h = top - 3 * hs - 26
    for k in range(1, 5):
        bw, bd = w - 24 * k, d - 24 * k
        if bw < 16 or bd < 16:
            break
        place("Island", STRATA[(k + 2) % len(STRATA)], bbox((bw, bd, 12), 0.5), m @ T(0, 0, h - 12), region=name)
        h -= 12
    for px in (-w / 2 + 10, -w / 2 + 30):
        place("Island", "bark_crane", bbox((2.0, 2.0, 30.0), 0.3), m @ T(px, -d / 2 + 10, top), region=name)
    place("Island", "bark_crane", bbox((24.0, 2.4, 2.4), 0.3), m @ T(-w / 2 + 20, -d / 2 + 10, top + 30), region=name)
    place("Island", "cloth_rope", rod(m @ Vector((-w / 2 + 20, -d / 2 + 10, top + 30)), m @ Vector((-w / 2 + 26, -d / 2 + 26, top - 18)), 0.4, 4), region=name)


def shed(x, z, yaw, w, d, h, roof_key, region):
    """A mason's workshop of the quarry's own stone: thick walls in strata bands, one big square doorway with a
    timber lintel, a heavy canvas roof on a ridge beam, a block on a sledge at the door. (Not open timber posts:
    those read as the lobby's market canopies, review 2026-11-21.)"""
    m = at(x, z, H(x, z), yaw)
    place("Yard", "stone_honey", bbox((w, d, h * 0.5), 0.8), m @ T(0, 0, -1.0), region)
    place("Yard", "stone_tan", bbox((w, d, h * 0.5 + 1.0), 0.8, (0.97, 0.97)), m @ T(0, 0, h * 0.5 - 1.0), region)
    place("Yard", "stone_umber", bbox((w * 0.4, 1.4, h * 0.75), 0.3), m @ T(0, -d / 2 - 0.2, 0.0), region)
    place("Yard", "bark_crane", bbox((w * 0.4 + 5.0, 3.0, 3.0), 0.4), m @ T(0, -d / 2 - 0.6, h * 0.75), region)
    g = bmesh.new()
    L, D, rise = w / 2 + 3.0, d / 2 + 3.0, d * 0.35
    a = [g.verts.new((-L, -D, 0)), g.verts.new((L, -D, 0)), g.verts.new((L, 0, rise)), g.verts.new((-L, 0, rise))]
    b2 = [g.verts.new((-L, D, 0)), g.verts.new((L, D, 0))]
    g.faces.new((a[0], a[1], a[2], a[3]))
    g.faces.new((a[3], a[2], b2[1], b2[0]))
    g.faces.new((a[0], a[3], b2[0]))
    g.faces.new((a[1], b2[1], a[2]))
    g.faces.new((a[0], b2[0], b2[1], a[1]))
    bmesh.ops.recalc_face_normals(g, faces=g.faces[:])
    place("Yard", roof_key, g, m @ T(0, 0, h), region)
    place("Yard", "bark_plank", bbox((10.0, 8.0, 2.0), 0.3), m @ T(w * 0.3, -d / 2 - 8.0, 0.0), region)
    place("Yard", "stone_rose", bbox((8.0, 6.0, 6.0), 0.5), m @ T(w * 0.3, -d / 2 - 8.0, 2.0), region)


def house(x, z, yaw, w, d, h, rng, region, door="cloth_canvas"):
    """A quarryman's house: thick lime-washed walls a little tapered, a heavy flat roof with a parapet, a squat
    chimney and big clay water jars on the roof (no pergola: too like the lobby's canopies), a teal door and
    shutters, a stone outside stair."""
    m = at(x, z, H(x, z), yaw)
    place("Hamlet", "stone_tan", bbox((w + 2.0, d + 2.0, 4.0), 0.5), m @ T(0, 0, -3.0), region)
    place("Hamlet", "plaster_lime", bbox((w, d, h), 0.9, (0.95, 0.95)), m @ T(0, 0, 1.0), region)
    place("Hamlet", "stone_honey", bbox((w * 0.95 + 1.6, d * 0.95 + 1.6, 3.2), 0.6), m @ T(0, 0, h + 1.0), region)
    place("Hamlet", "stone_tan", bbox((4.0, 4.0, 8.0), 0.5, (0.8, 0.8)), m @ T(w * 0.28, d * 0.2, h + 3.0), region)
    for q in range(2):
        place("Hamlet", "stone_rose", ring_prism([(1.6, 0.0), (2.8, 2.4), (2.4, 4.6), (1.4, 5.4)], 8), m @ T(-w * 0.25 + q * 6.0, -d * 0.15, h + 3.6), region)
    place("Hamlet", door, bbox((5.0, 1.2, 8.0), 0.3), m @ T(rng.uniform(-w * 0.2, w * 0.2), -d / 2 - 0.4, 1.0), region)
    for fx in (-0.3, 0.3):
        place("Hamlet", "bark_crane", bbox((4.0, 1.0, 4.0), 0.3), m @ T(fx * w, -d / 2 - 0.3, h * 0.55), region)
    for q in range(5):  # an outside stair up one side
        place("Hamlet", "stone_tan", bbox((5.0, 4.0, 2.0 + q * h / 5), 0.3), m @ T(w / 2 + 3.0, -d / 2 + 4.0 + q * 4.0, 0.0), region)


def guild_tower(x, z, yaw, region):
    """The masons' guild tower: a square stone tower in strata bands, a timber lookout with a canvas roof."""
    m = at(x, z, H(x, z), yaw)
    h = 0.0
    for k, (s, hh) in enumerate(((30.0, 18.0), (27.0, 18.0), (24.0, 18.0), (21.0, 18.0))):
        place("Hamlet", STRATA[k], bbox((s, s, hh), 0.7), m @ T(0, 0, h), region)
        h += hh
    place("Hamlet", "bark_plank", bbox((28.0, 28.0, 2.0), 0.4), m @ T(0, 0, h), region)
    for sx in (-1, 1):
        for sy in (-1, 1):
            place("Hamlet", "bark_crane", bbox((2.0, 2.0, 12.0), 0.3), m @ T(sx * 12, sy * 12, h + 2.0), region)
    roof = ring_prism([(21.0, 0.0), (21.0, 2.0), (2.0, 14.0)], 4)
    place("Hamlet", "cloth_canvas", roof, m @ T(0, 0, h + 14.0) @ Rz(math.pi / 4), region)
    place("Hamlet", "glow_lantern", bbox((3.0, 3.0, 4.0), 0.3), m @ T(0, 0, h + 4.0), region)


def stack(x, z, yaw, rng, region, n=None, covered=False):
    """A stack of cut blocks, two or three high; sometimes under a teal canvas."""
    m = at(x, z, H(x, z), yaw)
    s = rng.uniform(10.0, 13.0)
    cols, rows = rng.choice(((2, 2), (3, 2), (2, 1), (3, 1)))
    layers = n or rng.randint(2, 3)
    for L in range(layers):
        for i in range(cols - (1 if L == layers - 1 and cols > 1 else 0)):
            for j in range(rows):
                key = rng.choice(("stone_honey", "stone_tan", "stone_rose", "stone_chalk"))
                place("Yard", key, bbox((s - 0.4, s - 0.4, s * 0.8), 0.5), m @ T((i - (cols - 1) / 2) * s + L * s / 2 * (cols > 1), (j - (rows - 1) / 2) * s, L * s * 0.8), region)
    if covered:
        place("Yard", "cloth_canvas", bbox((cols * s + 2.0, rows * s + 2.0, 1.2), 0.4), m @ T(0, 0, layers * s * 0.8), region)


def cypress(x, z, s, rng, region):
    """A dark cypress spire (the quarry's trees: tall and narrow, a clear silhouette against the sky)."""
    y = H(x, z)
    b = ring_prism([(0.9 * s, -1.0), (1.0 * s, 2.0), (3.0 * s, 4.0), (3.4 * s, 10.0 * s), (2.8 * s, 16.0 * s), (1.6 * s, 21.0 * s), (0.2 * s, 25.0 * s)], 7)
    place("Trees", "leaf_cypress", b, at(x, z, y, rng.uniform(0, 6.28)) @ Ry(rng.uniform(-0.05, 0.05)), region=region)


def small_crane(x, z, yaw, region):
    m = at(x, z, H(x, z), yaw)
    place("Yard", "bark_crane", bbox((5.0, 5.0, 56.0), 0.4, (0.8, 0.8)), m @ T(0, 0, 0), region)
    place("Yard", "bark_crane", rod(m @ Vector((0, 0, 52.0)), m @ Vector((0, -42.0, 40.0)), 1.6, 6), region=region)
    place("Yard", "cloth_rope", rod(m @ Vector((0, -41.0, 40.0)), m @ Vector((0, -41.0, 9.0)), 0.5, 4), region=region)
    place("Yard", "stone_tan", bbox((10.0, 10.0, 8.0), 0.4), m @ T(0, -41.0, 1.0), region)
    place("Yard", "bark_plank", hoop(12.0, 1.1, sides=5, n=20), m @ T(9.0, 0, 13.0) @ Rz(math.pi / 2), region)


def derrick(x, z, boom_x, boom_z):
    """THE landmark: a timber derrick about 410 studs tall (1.3 x the first try, sheer-legs for bulk), its boom swung out toward (boom_x, boom_z), a
    house-sized block hanging from it, a treadwheel at its foot, back-stays to stone anchors, lanterns on the boom.
    The boom, its ropes and the load are 'DerrickBoom' meshes so the game can swing them round the mast."""
    y = H(x, z)
    yaw = facing(x, z, boom_x, boom_z)
    m = at(x, z, y, yaw) @ Matrix.Scale(1.3, 4)  # review 2026-11-21: bigger and bulkier than the first try
    r = "Derrick"
    place("Derrick", "stone_chalk", bbox((60.0, 60.0, 8.0), 0.6), m @ T(0, 0, -2.0), r)
    place("Derrick", "bark_crane", bbox((28.0, 28.0, 290.0), 0.8, (0.5, 0.5)), m @ T(0, 0, 2.0), r)
    for sx in (-1, 1):  # sheer-legs bracing the mast: bulk and a wide A-frame silhouette
        place("Derrick", "bark_crane", rod(m @ Vector((sx * 62.0, 26.0, 0.0)), m @ Vector((sx * 6.0, 4.0, 210.0)), 7.0, 6), region=r)
        place("Derrick", "stone_rose", bbox((22.0, 22.0, 12.0), 0.6), m @ T(sx * 62.0, 26.0, -4.0), r)
        for hb in (60.0, 130.0):
            f = hb / 210.0
            place("Derrick", "bark_plank", rod(m @ Vector((sx * (62.0 - 56.0 * f), 26.0 - 22.0 * f, hb)), m @ Vector((0.0, 0.0, hb)), 3.0, 5), region=r)
    for hc, sc in ((60.0, 1.0), (150.0, 0.8), (240.0, 0.62)):
        place("Derrick", "bark_plank", bbox((24.0 * sc, 24.0 * sc, 5.0), 0.4), m @ T(0, 0, hc), r)
    head = Vector((0.0, 0.0, 292.0))
    place("Derrick", "bark_crane", bbox((15.0, 15.0, 9.0), 0.6), m @ T(0, 0, 288.0), r)
    place("Derrick", "cloth_canvas", bbox((3.0, 30.0, 18.0), 0.3), m @ T(0, 0, 296.0), r)  # a pennant on the mast head
    el = math.radians(34.0)
    L = 270.0
    foot = Vector((0.0, -13.0, 18.0))
    tip = foot + Vector((0.0, -L * math.cos(el), L * math.sin(el)))
    place("DerrickBoom", "bark_crane", bbox((20.0, 20.0, L), 0.6, (0.6, 0.6)), m @ T(*foot) @ Rx(math.pi / 2 - el), r)
    place("Derrick", "bark_plank", bbox((26.0, 12.0, 12.0), 0.6), m @ T(0, -13.0, 8.0), r)
    place("DerrickBoom", "cloth_rope", rod(m @ head, m @ tip, 1.4, 6), region=r)
    for sx in (-1, 1):
        anchor = Vector((sx * 70.0, 100.0, 4.0))
        place("Derrick", "cloth_rope", rod(m @ head, m @ anchor, 1.4, 6), region=r)
        place("Derrick", "stone_rose", bbox((18.0, 18.0, 14.0), 0.6), m @ T(*(anchor - Vector((0, 0, 8.0)))), r)
    hook = tip + Vector((0.0, 0.0, -70.0))
    place("DerrickBoom", "cloth_rope", rod(m @ tip, m @ hook, 1.6, 6), region=r)
    load_top = hook.z - 10.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            place("DerrickBoom", "cloth_rope", rod(m @ hook, m @ Vector((hook.x + sx * 36.0, hook.y + sy * 25.0, load_top)), 1.2, 5), region=r)
    place("DerrickBoom", "stone_honey", bbox((78.0, 56.0, 52.0), 0.8), m @ T(hook.x, hook.y, load_top - 52.0), r)
    place("DerrickBoom", "stone_rose", bbox((78.6, 56.6, 11.0), 0.5), m @ T(hook.x, hook.y, load_top - 34.0), r)
    for q in range(4):
        p = foot + (tip - foot) * (0.25 + q * 0.2)
        place("DerrickBoom", "glow_lantern", bbox((3.4, 3.4, 4.6), 0.4), m @ T(p.x, p.y, p.z - 12.0), r)
        place("DerrickBoom", "cloth_rope", rod(m @ p, m @ Vector((p.x, p.y, p.z - 7.4)), 0.3, 4), region=r)
    place("Derrick", "bark_plank", hoop(38.0, 3.6, sides=6, n=28), m @ T(48.0, -30.0, 40.0) @ Rz(math.pi / 2), r)
    for k in range(6):
        a = k / 6 * math.pi
        place("Derrick", "bark_crane", rod(m @ Vector((48.0, -30.0 + math.cos(a) * 38, 40.0 + math.sin(a) * 38)), m @ Vector((48.0, -30.0 - math.cos(a) * 38, 40.0 - math.sin(a) * 38)), 1.2, 4), region=r)
    for sy in (-1, 1):
        place("Derrick", "bark_crane", bbox((6.0, 6.0, 42.0), 0.3), m @ T(48.0, -30.0 + sy * 8.0, 0.0), r)
    place("Derrick", "bark_plank", bbox((24.0, 20.0, 16.0), 0.4), m @ T(-44.0, 34.0, 0.0), r)
    place("Derrick", "cloth_canvas", bbox((30.0, 26.0, 2.4), 0.6), m @ T(-44.0, 34.0, 16.0) @ Rx(0.15), r)
    mast = m @ Vector((0.0, 0.0, 0.0))  # the boom swings round the mast (MapEnvironments quarry spinners: its hub)
    DATA["derrick"] = {"meshes": "Map_Quarry_DerrickBoom_*", "pivot": [round((m @ foot).x, 2), round((m @ foot).z, 2), round(-(m @ foot).y, 2)],
                       "mast": [round(mast.x, 2), round(mast.z, 2), round(-mast.y, 2)]}


YARD = (-150.0, -1250.0)
HAMLET = (-760.0, -1050.0)
DERRICK = (560.0, -760.0)


def islands():
    """The quarry's own layout (review 2026-11-21: the first five maps shared one layout): the derrick east-north-
    east, the yard north, the hamlet and pit west, blocks east and west too, not only north."""
    rng = random.Random(311)
    block_isle("Yard", YARD[0], YARD[1], 460.0, 300.0, 30.0, yaw=0.05, benches=6, step=14.0, bench_h=13.0)
    block_isle("Hamlet", HAMLET[0], HAMLET[1], 300.0, 220.0, 12.0, yaw=-0.25, benches=6, step=12.0)
    block_isle("Derrick", DERRICK[0], DERRICK[1], 240.0, 210.0, 8.0, yaw=-0.12, benches=6, step=13.0)
    pit_isle("Pit", -420.0, -700.0, 210.0, 160.0, -20.0, 0.25, rng)
    block_isle("BlocksE", 780.0, -120.0, 96.0, 74.0, -130.0, yaw=0.3, benches=3)
    block_isle("BlocksW", -620.0, -500.0, 104.0, 80.0, -96.0, yaw=-0.2, benches=3)
    block_isle("Ledge", 900.0, -1400.0, 220.0, 150.0, 20.0, yaw=0.4, benches=5)
    block_isle("QuarryE", 1180.0, -560.0, 200.0, 150.0, -40.0, yaw=0.6, benches=5)
    block_isle("QuarryW", -1200.0, -560.0, 220.0, 160.0, -30.0, yaw=-0.5, benches=5)
    block_isle("FarNE", 1650.0, -1650.0, 260.0, 170.0, 8.0, yaw=0.2, benches=5, step=14.0)
    block_isle("FarNW", -1700.0, -1750.0, 280.0, 190.0, 16.0, yaw=-0.3, benches=5, step=14.0)
    block_isle("FarN", -250.0, -2650.0, 320.0, 210.0, 36.0, yaw=0.1, benches=5, step=16.0)
    for x, z, h, s in ((90, -650, 40, 30), (-60, -880, 100, 24), (330, -560, 70, 22), (-420, -1000, 80, 34), (300, -1300, 140, 26), (-1000, -880, 50, 28), (1000, -900, 40, 30), (-260, -560, 10, 20), (760, -1080, 150, 22), (-560, -1500, 120, 30)):
        isle(f"Loose{x}", x, z, s / 2, s / 2, h)
        b = bbox((s * 1.3, s, s * 0.8), 0.8)
        place("Loose", rng.choice(("stone_honey", "stone_tan", "stone_rose")), b, at(x, z, h, rng.uniform(0, 6.28)) @ Rx(rng.uniform(-0.15, 0.15)), region=f"Loose{int(x) // 700}")


def works():
    rng = random.Random(401)
    cx, cz = YARD
    for dx, dz, w, d, h in ((-160, -70, 58, 32, 22), (-80, -110, 48, 30, 20), (20, -105, 62, 34, 23), (120, -70, 50, 30, 21), (-185, 50, 46, 28, 20), (170, 60, 52, 30, 21)):
        x, z = cx + dx, cz + dz
        shed(x, z, facing(x, z, cx, cz + 200) + rng.uniform(-0.15, 0.15), w, d, h, rng.choice(("cloth_canvas", "bark_crane")), "Yard")
    for k, (dx, dz) in enumerate(((-70, 10), (0, 40), (70, 20), (140, -10), (-110, 100), (40, 110), (-20, -40), (100, 120), (-150, -10), (200, -110))):
        stack(cx + dx, cz + dz, rng.uniform(0, 6.28), rng, "Yard", covered=k % 3 == 0)
    small_crane(cx + 190, cz + 20, facing(cx + 190, cz + 20, cx + 400, cz + 100), "Yard")
    guild_tower(cx - 30, cz + 115, 0.1, "Yard")
    for k in range(10):
        a = rng.uniform(0, math.tau)
        x, z = cx + math.cos(a) * rng.uniform(170, 215), cz + math.sin(a) * rng.uniform(100, 135)
        cypress(x, z, rng.uniform(2.2, 3.2), rng, "Yard")
    hx, hz = HAMLET
    for k, (dx, dz) in enumerate(((-80, -40), (-20, -60), (50, -45), (90, 10), (-90, 30), (20, 40), (-30, -5))):
        x, z = hx + dx, hz + dz
        house(x, z, facing(x, z, 0.0, 0.0) + rng.uniform(-0.3, 0.3), rng.uniform(22, 30), rng.uniform(18, 24), rng.uniform(16, 22), rng, "Hamlet", door=rng.choice(("cloth_canvas", "stone_rose")))
    for k in range(9):
        a = rng.uniform(0, math.tau)
        x, z = hx + math.cos(a) * rng.uniform(100, 140), hz + math.sin(a) * rng.uniform(70, 100)
        cypress(x, z, rng.uniform(2.0, 3.0), rng, "Hamlet")
    for name in ("BlocksE", "BlocksW", "Ledge", "QuarryE", "QuarryW"):
        i = ISLES[name]
        stack(i["cx"] - 12, i["cz"] + 6, rng.uniform(0, 6.28), rng, name, covered=True)
        stack(i["cx"] + 18, i["cz"] - 10, rng.uniform(0, 6.28), rng, name)
        cypress(i["cx"] + 30, i["cz"] + 16, 2.0, rng, name)
    i = ISLES["Ledge"]
    shed(i["cx"] - 50, i["cz"] + 20, facing(i["cx"], i["cz"], 0.0, 0.0), 48, 28, 20, "cloth_canvas", "Ledge")
    house(i["cx"] + 40, i["cz"] + 40, facing(i["cx"], i["cz"], 0.0, 0.0), 26, 20, 18, rng, "Ledge")
    small_crane(i["cx"] + 70, i["cz"] - 20, facing(i["cx"] + 70, i["cz"] - 20, 0.0, 0.0), "Ledge")
    for name in ("FarN", "FarNE", "FarNW"):
        i = ISLES[name]
        for k in range(6):
            cypress(i["cx"] + rng.uniform(-90, 90), i["cz"] + rng.uniform(-50, 50), rng.uniform(2.4, 3.2), rng, name)
        house(i["cx"] + 20, i["cz"] + 10, facing(i["cx"], i["cz"], 0.0, 0.0), 28, 22, 18, rng, name)
    small_crane(ISLES["FarN"]["cx"] - 60, ISLES["FarN"]["cz"], 0.6, "FarN")
    # rope bridges: yard to hamlet, yard to the pit
    rope_bridge("Bridges", "bark_plank", "cloth_rope", W(cx - 230, cz + 30, 30.0), W(hx + 140, hz - 20, 12.0), 24.0, "BridgeW")
    rope_bridge("Bridges", "bark_plank", "cloth_rope", W(-380.0, -780.0, -20.0), W(cx - 160, cz + 150, 30.0), 30.0, "BridgeS")
    # the landmark, its boom swung out to the west across the view from the arena
    derrick(DERRICK[0], DERRICK[1], DERRICK[0] - 400.0, DERRICK[1] + 120.0)


sketch_run(NAME, [surface, edge, islands, works], sandstone, landmark=("Derrick", "DerrickBoom"))
