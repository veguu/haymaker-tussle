"""The fighting village lobby (owner's brief 2026-11-18): the cliffside lobby rebuilt 2.5x wider and deeper as a
bustling village, in the same kit, palette and baked paint as cliffside.py, whose helpers this file reuses by
exec-ing it without its main().

    blender -b --factory-startup -P village.py -- <out folder> [--dry] [--fast] [--no-render]

LAYOUT (u across, d back from the viewing edge, h above Lobby.FloorY; sizes from village_config.json). COMPACT
(owner, 2026-11-18: the 330 x 375 first build was "wayyy too big"; the lobby is back near its first size, a
little bigger for detail):
  d   0..21   h 0  the front row: a clear viewing balcony, benches at its back, the obby's ramp in the left
                   corner and the Champion's Perch in the right
  d  30..111  h 4  the village square, 150 wide: spawn medallion, three shop HOUSES down each side 44 studs from
                   spawn (walls, tile roof, open shopfront, a keeper inside each), the great tree before the
                   training steps
  d 120..330  h 8  the training grounds behind a clay wall with three gates: its own private, free-practice
                   zone. FOUR ZONES in a 2 x 2 grid (owner, 2026-11-20, from his sketch; training_sections.json)
                   round a walkway cross (spine u -9..9, bar d 222..240): front left the DUMMY ROW, front right
                   the CLASH DUMMY (and the leaderboards on its wall), back left the 1V1 BOT ARENA (a raised
                   round arena), back right the RECOVERY CLIFF (the lobby's right edge open to the sky)
  d 330..600       the SKY LEG behind the lobby (village_config.json Sky): the Launch Rock, four floating isles,
                   Bell Rock with its bell, the Haymaker glove, a tree, a bench and a summit flag
THE OBBY has its own platforms (the shops are not part of it), spaced for a full-speed run: the ramp, four
decks up the left side and over the wall, then along the walkway cross (turn deck, the Crossroads, two decks down
the spine), out through the gap in the back wall and over the isles to Bell Rock: 14 running jumps. The Haymaker
glove punches you home onto the Champion's Perch. Every hop is in obby.json and checked by
design/lobby/prove/check_obby.py.

WRITES into <out>: village.blend, textures/, export/village_<n>.glb, manifest.json, collision.json,
placements.json, obby.json and review renders. NOTHING under src/ is touched: the layout goes live only through
gen_layout.py and game.json, when the owner says so.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
_path = os.path.join(HERE, "cliffside.py")
_src = open(_path, encoding="utf-8").read()
_src = _src[: _src.rindex("\nmain()")].replace('f"cliffside_{index}.glb"', 'f"village_{index}.glb"')
exec(compile(_src, _path, "exec"), globals())  # helpers, palette, kit builders, export()

# RETRO COMIC (ui-22a, owner 2026-11-20: picked palette 2, then "change the entire vibe of the game ... to the same
# vibe"). The UI's paints (shared/Tokens.luau): navy ink 1E2233, newsprint cream FFF4D6, primary yellow FFD23F,
# comic blue 64A3FF, red F0525A, grey-blue A9B4C9, green 2EC27E. Here: newsprint stone whose shade is a cool navy,
# RED tile roofs, warm timber, yellow / red / blue / green cloth, green trees with yellow clumps, blue accents. The
# ui-20f version is in work/before-retro-lobby/village.py. Each is (base, lit, shade).
PAL.update(
    {
        "stone_pave": (srgb(240, 232, 210), srgb(255, 248, 228), srgb(150, 156, 178)),
        "stone_trim": (srgb(246, 240, 222), srgb(255, 252, 238), srgb(160, 166, 186)),
        "stone_cream": (srgb(236, 226, 202), srgb(252, 244, 222), srgb(148, 150, 170)),
        "stone_sand": (srgb(232, 206, 160), srgb(248, 226, 186), srgb(150, 138, 140)),
        "stone_blue": (srgb(120, 160, 220), srgb(170, 200, 245), srgb(60, 90, 160)),
        "stone_clay": (srgb(220, 84, 80), srgb(240, 130, 120), srgb(140, 48, 62)),
        "stone_teal": (srgb(80, 150, 240), srgb(140, 190, 255), srgb(40, 90, 180)),
        "stone_roof": (srgb(214, 64, 68), srgb(238, 110, 104), srgb(120, 36, 52)),
        "bark_timber": (srgb(200, 146, 88), srgb(230, 182, 122), srgb(120, 80, 60)),
        "bark_gate": (srgb(80, 150, 240), srgb(140, 190, 255), srgb(40, 90, 180)),
        "bark": (srgb(98, 70, 56), srgb(140, 104, 80), srgb(52, 38, 40)),
        "leaf_pink": (srgb(60, 170, 90), srgb(110, 210, 120), srgb(30, 100, 70)),
        "leaf_blush": (srgb(255, 210, 63), srgb(255, 232, 140), srgb(190, 140, 30)),
        "cloth_coral": (srgb(240, 82, 90), srgb(250, 130, 130), srgb(150, 44, 60)),
        "cloth_gold": (srgb(255, 210, 63), srgb(255, 232, 140), srgb(190, 140, 30)),
        "cloth_cream": (srgb(255, 244, 214), srgb(255, 250, 236), srgb(176, 176, 190)),
        "cloth_teal": (srgb(100, 163, 255), srgb(160, 200, 255), srgb(50, 96, 190)),
        "cloth_lav": (srgb(169, 180, 201), srgb(205, 214, 228), srgb(100, 110, 140)),
        "cloth_mint": (srgb(46, 194, 126), srgb(120, 226, 170), srgb(24, 120, 80)),
        "soil": (srgb(120, 90, 70), srgb(160, 124, 96), srgb(70, 52, 46)),
        "paper": (srgb(255, 240, 190), srgb(255, 250, 220), srgb(236, 196, 150)),
    }
)

cfg = json.load(open(os.path.join(HERE, "village_config.json"), encoding="utf-8"))
W, D = float(cfg["Width"]), float(cfg["Depth"])
HX = W / 2
TERRACES = [(float(t["Start"]), float(t["Rise"])) for t in cfg["Terraces"]]
RUN, LEAD = float(cfg["StairRun"]), float(cfg["StairLead"])
(SQ_D, SQ_H), (TR_D, TR_H) = TERRACES
assert abs(TR_D - (D - float(cfg["TrainingDepth"]))) < 1e-6, "the training terrace must start on the training line"
SPAWN_D = float(cfg["SpawnZ"]) - float(cfg["ViewEdgeZ"])
STEP_HALF = 56.0
NOPERCH = 60.0  # free-standing poles are solid up to here: above the highest deck (30) plus the best jump (16.3)
TREE = (0.0, 95.0)  # the great tree, on the way from spawn to the training gate
SCALE = 216.0 / 375.0  # the crag was sized for the first, larger build; held at the compact lobby's scale so deepening training (2026-11-19) leaves the rocks as they were
SECTIONS = json.load(open(os.path.join(HERE, "training_sections.json"), encoding="utf-8"))
SIGN = SECTIONS["Sign"]



def box_c(u0, u1, d0, d1, h0, h1):  # to 0.1 stud, so every generated LobbyLayout line stays inside StyLua's width
    COLLISION.append({"kind": "box", "u0": round(u0, 1), "u1": round(u1, 1), "d0": round(d0, 1), "d1": round(d1, 1), "h0": round(h0, 1), "h1": round(h1, 1)})


def cyl_c(u, d, r, h0, h1):
    COLLISION.append({"kind": "cyl", "u": round(u, 1), "d": round(d, 1), "r": round(r, 1), "h0": round(h0, 1), "h1": round(h1, 1)})


BAGS = {}  # (element, part, key) -> bmesh; every bag becomes Lobby_<element>_<part>
OBBY = []  # the course's standable tops, in order
STATIONS = []  # {"name", "role", "page", "action", "u", "d", "h", "face"}: where LobbyService stands each NPC
LAMPS = []  # (u, d, h, toward (x, y), tall)
PLANTS_LOW = ["Flowers_Coral", "Plant_Broadleaf", "Flowers_Tulip", "Bush_Low", "Flowers_Daisy_Big", "Plant_Spiky", "Flowers_Bell", "Plant_Roundleaf", "Flowers_Daisy_Small", "Plant_Groundcover"]
BUSHES = ["Bush_Big", "Bush_Round", "Bush_Wide", "Bush_Double", "Bush_Low"]
FLAGS = ["cloth_coral", "cloth_gold", "cloth_teal", "cloth_lav", "cloth_mint", "cloth_cream"]


def bag(element, part, key):
    k = (element, part, key)
    if k not in BAGS:
        BAGS[k] = bmesh.new()
    return BAGS[k]


def cloth(element, key):
    return bag(element, key.split("_")[1].capitalize(), key)


def tris_of(bm):
    return sum(len(f.verts) - 2 for f in bm.faces)


def emit(element, part, key, bm, limit=17000):
    """One mesh, or several split by loose island along the longer side, so none passes Roblox's 20,000."""
    if tris_of(bm) <= limit:
        make(f"Lobby_{element}", part, key, bm, "Lobby")
        return
    bm.faces.index_update()
    seen, islands = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        seen.add(f.index)
        stack, isl = [f], []
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for o in e.link_faces:
                    if o.index not in seen:
                        seen.add(o.index)
                        stack.append(o)
        islands.append(isl)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    axis = 0 if max(xs) - min(xs) >= max(ys) - min(ys) else 1
    islands.sort(key=lambda isl: sum(f.calc_center_median()[axis] for f in isl) / len(isl))
    groups, current, count = [], [], 0
    for isl in islands:
        n = sum(len(f.verts) - 2 for f in isl)
        if current and count + n > limit:
            groups.append(current)
            current, count = [], 0
        current.append(isl)
        count += n
    groups.append(current)
    for i, group in enumerate(groups):
        new, vmap = bmesh.new(), {}
        for isl in group:
            for f in isl:
                vs = []
                for v in f.verts:
                    if v.index not in vmap:
                        vmap[v.index] = new.verts.new(v.co)
                    vs.append(vmap[v.index])
                new.faces.new(vs)
        make(f"Lobby_{element}{'ABCDEFGHJK'[i]}", part, key, new, "Lobby")
    bm.free()


def post_c(u, d, r, h0, h1):
    """A post under a deck: solid only up to the deck (in pieces under 8 tall, so gen_layout's no-perch rule
    never carries it up through the deck it holds)."""
    n = max(1, math.ceil((h1 - h0) / 7.5))
    for i in range(n):
        cyl_c(u, d, r, h0 + (h1 - h0) * i / n, h0 + (h1 - h0) * (i + 1) / n)


def pole_c(u, d, r, h0):
    cyl_c(u, d, r, h0, NOPERCH)


def obby(name, top, u0=None, u1=None, d0=None, d1=None, u=None, d=None, r=None, how=""):
    OBBY.append({"n": len(OBBY) + 1, "name": name, "top": top, "u0": u0, "u1": u1, "d0": d0, "d1": d1, "u": u, "d": d, "r": r, "how": how})


def crate(bm, u, d, h, size, rng, yaw=0.0):
    append(bm, brick(size, rng), T(u, d, h, yaw))


def deck(bm, u0, u1, d0, d1, top, rng, thick=0.7, plank=2.5):
    along_u = (u1 - u0) >= (d1 - d0)
    span = (d1 - d0) if along_u else (u1 - u0)
    n = max(1, round(span / plank))
    w = span / n
    for i in range(n):
        j, e0, e1 = rng.uniform(-0.04, 0.04), rng.uniform(0, 0.3), rng.uniform(0, 0.3)
        if along_u:
            plain_box(bm, u0 - e0, u1 + e1, d0 + i * w + 0.07, d0 + (i + 1) * w - 0.07, top - thick + j, top)
        else:
            plain_box(bm, u0 + i * w + 0.07, u0 + (i + 1) * w - 0.07, d0 - e0, d1 + e1, top - thick + j, top)


def valance(c1, c2, uf, face, d0, d1, top, out=5.0, drop=2.6):
    """A striped awning skirt reaching out from a roof's front edge, with a scalloped hem."""
    n = max(4, round((d1 - d0) / 4.5))
    for i in range(n):
        a, b = d0 + i * (d1 - d0) / n, d0 + (i + 1) * (d1 - d0) / n
        t = c1 if i % 2 == 0 else c2
        p = [at(uf, a, top - 0.1), at(uf, b, top - 0.1), at(uf + face * out, b, top - drop), at(uf + face * out, a, top - drop)]
        t.faces.new([t.verts.new(q) for q in p])
        low = Vector((0, 0, -0.9))
        t.faces.new([t.verts.new(q) for q in (p[3], p[2], p[2] + low, (p[2] + p[3]) / 2 + Vector((0, 0, -1.5)), p[3] + low)])


def lantern_body(pos, s=1.0):
    timber, paper = bag("Lanterns", "Timber", "bark_timber"), bag("Lanterns", "Paper", "paper")
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1.0)
    for v in b.verts:
        wide = 1.0 if v.co.z < 0 else 0.86
        v.co = Vector((v.co.x * 1.05 * wide, v.co.y * 1.05 * wide, v.co.z * 1.4)) * s
    bmesh.ops.triangulate(b, faces=b.faces[:])
    append(paper, b, Matrix.Translation(pos))
    for z, size in ((0.78, 1.25), (-0.76, 1.0)):
        cap = bmesh.new()
        bmesh.ops.create_cube(cap, size=1.0)
        for v in cap.verts:
            v.co = Vector((v.co.x * size, v.co.y * size, v.co.z * 0.16)) * s
        bmesh.ops.triangulate(cap, faces=cap.faces[:])
        append(timber, cap, Matrix.Translation(pos + Vector((0, 0, z * s))))


def hang(pos, drop=0.8, s=1.0):
    """A paper lantern hanging on a short cord under `pos` (a Blender-space point)."""
    tube(bag("Lanterns", "Timber", "bark_timber"), [pos, pos - Vector((0, 0, drop))], [0.05, 0.05], sides=4, caps=(False, False))
    lantern_body(pos - Vector((0, 0, drop + 0.8 * s)), s)


def lamps():
    rng = random.Random(41)
    timber = bag("Lanterns", "Timber", "bark_timber")
    for u, d, h, (ix, iy), tall in LAMPS:
        inward = Vector((ix, iy, 0.0))
        top = h + tall
        tube(timber, [at(u, d, h - 0.1), at(u, d, top)], [0.3, 0.26], sides=6, rng=rng)
        tip = at(u, d, top - 0.3) + inward * 1.9
        tube(timber, [at(u, d, top - 0.5), tip], [0.18, 0.16], sides=5, rng=rng)
        hang(tip)


def bunting(a, b, start=0, sag=None):
    a, b = Vector(a), Vector(b)
    length = (b - a).length
    n = max(3, round(length / 3.4))
    sag = length * 0.07 if sag is None else sag
    pts = [a + (b - a) * (i / n) + Vector((0, 0, -sag * 4 * (i / n) * (1 - i / n))) for i in range(n + 1)]
    tube(bag("Bunting", "Rope", "cloth_cream"), pts, [0.07] * (n + 1), sides=4, caps=(False, False), jitter=0.0)
    for i in range(n):
        bm = cloth("Bunting", FLAGS[(i + start) % len(FLAGS)])
        p, q = pts[i], pts[i + 1]
        g = (q - p) * 0.12
        bm.faces.new([bm.verts.new(v) for v in (p + g, q - g, (p + q) / 2 + Vector((0, 0, -2.3)))])


def banner(u, d, h0, key, rng, tall=15.0, face=0.0, solid=True):
    timber, cl = bag("Banners", "Timber", "bark_timber"), cloth("Banners", key)
    tube(timber, [at(u, d, h0 - 0.3), at(u, d, h0 + tall)], [0.36, 0.28], sides=6, rng=rng)
    if solid:
        pole_c(u, d, 0.6, h0)
    arm = Vector((math.cos(face), math.sin(face), 0))
    a = at(u, d, h0 + tall - 0.9)
    tube(timber, [a - arm * 0.4, a + arm * 3.4], [0.15, 0.15], sides=5, rng=rng)
    rows, length, width = 6, 8.5, 2.7
    normal = Vector((-arm.y, arm.x, 0))
    pts = []
    for r in range(rows + 1):
        t = r / rows
        sway = math.sin(t * 2.6) * 0.35 * t
        for k in (0, 1):
            pts.append(cl.verts.new(a + arm * (0.45 + k * width) + Vector((0, 0, -0.1 - t * length + (0.6 if (r == rows and k == 1) else 0))) + normal * sway))
    for r in range(rows):
        i = r * 2
        cl.faces.new((pts[i], pts[i + 1], pts[i + 3], pts[i + 2]))


def arch(a, b, h0, key, rng, tall=13.0):
    """A station's frame: two posts at lobby points a and b (u, d), a double beam, and the station's colour hung
    between them."""
    timber, cl = bag("Arches", "Timber", "bark_timber"), cloth("Arches", key)
    pa, pb = at(a[0], a[1], h0), at(b[0], b[1], h0)
    up = Vector((0, 0, tall))
    along = (pb - pa).normalized()
    for p, (u, d) in ((pa, a), (pb, b)):
        tube(timber, [p - Vector((0, 0, 0.2)), p + up], [0.75, 0.6], sides=6, rng=rng)
        pole_c(u, d, 0.9, h0)
    tube(timber, [pa + up - along * 1.6 + Vector((0, 0, -0.4)), pb + up + along * 1.6 + Vector((0, 0, -0.4))], [0.5, 0.5], sides=6, rng=rng)
    tube(timber, [pa + up + Vector((0, 0, -2.4)), pb + up + Vector((0, 0, -2.4))], [0.32, 0.32], sides=5, rng=rng)
    span = (pb - pa).length
    for t0, t1, drop in ((0.14, 0.4, 5.0), (0.4, 0.6, 6.4), (0.6, 0.86, 5.0)):
        p0, p1 = pa + along * span * t0 + up + Vector((0, 0, -2.6)), pa + along * span * t1 + up + Vector((0, 0, -2.6))
        mid = (p0 + p1) / 2 + Vector((0, 0, -drop - 1.2))
        cl.faces.new([cl.verts.new(v) for v in (p0, p1, p1 + Vector((0, 0, -drop)), mid, p0 + Vector((0, 0, -drop)))])
    hang(pa + along * 2.2 + up + Vector((0, 0, -2.6)))
    hang(pb - along * 2.2 + up + Vector((0, 0, -2.6)))


def bench(u, d, h, rng, along_d=True):
    stone, timber = bag("Benches", "Stone", "stone_trim"), bag("Benches", "Timber", "bark_timber")
    for leg in (-2.6, 2.6):
        crate(stone, u + (0 if along_d else leg), d + (leg if along_d else 0), h, (1.5, 0.9, 1.3) if along_d else (0.9, 1.5, 1.3), rng)
    crate(timber, u, d, h + 1.3, (1.9, 7.2, 0.45) if along_d else (7.2, 1.9, 0.45), rng)
    if along_d:
        box_c(u - 1.0, u + 1.0, d - 3.6, d + 3.6, h, h + 1.75)
    else:
        box_c(u - 3.6, u + 3.6, d - 1.0, d + 1.0, h, h + 1.75)


def bed(u0, u1, d0, d1, h, rng, plants, wall=1.6, element="Planters"):
    """A walled planting bed: a low wall of cut blocks round soil, dressed from the kit."""
    stone, soil = bag(element, "Stone", "stone_trim"), bag(element, "Soil", "soil")
    top = h + wall
    for ua, ub, da, db in ((u0, u1, d0, d0 + 1.5), (u0, u1, d1 - 1.5, d1), (u0, u0 + 1.5, d0 + 1.5, d1 - 1.5), (u1 - 1.5, u1, d0 + 1.5, d1 - 1.5)):
        long_u = (ub - ua) > (db - da)
        length = (ub - ua) if long_u else (db - da)
        count = max(1, round(length / 5.0))
        seg = length / count
        for i in range(count):
            size = (seg - 0.08, 1.5, wall + 0.6) if long_u else (1.5, seg - 0.08, wall + 0.6)
            crate(stone, ua + (i + 0.5) * seg if long_u else (ua + ub) / 2, (da + db) / 2 if long_u else da + (i + 0.5) * seg, h - 0.6, size, rng)
    plain_box(soil, u0 + 1.0, u1 - 1.0, d0 + 1.0, d1 - 1.0, h, top - 0.35)
    box_c(u0, u1, d0, d1, h - 1.0, top)
    long_u = (u1 - u0) >= (d1 - d0)
    for i, asset in enumerate(plants):
        t = (i + 0.5) / len(plants)
        side = 0.5 + rng.uniform(-0.28, 0.28)
        pu = u0 + 2 + (u1 - u0 - 4) * (t if long_u else side)
        pd = d0 + 2 + (d1 - d0 - 4) * (side if long_u else t)
        put(asset, pu, pd, top - 0.35, rng.uniform(0, 6.28), rng.uniform(1.15, 1.4))


# --- ground: flagstones by zone (each zone its own mesh, so its texture stays sharp), a slab under them ----------
def flags2(bm, u0, u1, d0, d1, h, rng, row=9.0, wmin=8.0, wmax=14.0, gap=0.16, bev=0.2):
    rows = max(1, round((d1 - d0) / row))
    step = (d1 - d0) / rows
    for r in range(rows):
        a, b = d0 + r * step, d0 + (r + 1) * step
        x = u0
        while x < u1 - 0.01:
            w = rng.uniform(wmin, wmax)
            if u1 - (x + w) < wmin * 0.6:
                w = u1 - x
            top = h - rng.uniform(0.0, 0.05)
            x0, x1, y0, y1 = x + gap / 2, x + w - gap / 2, -b + gap / 2, -a - gap / 2
            mid = [bm.verts.new((px, py, top - bev)) for px, py in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
            up = [bm.verts.new((px, py, top)) for px, py in ((x0 + bev, y0 + bev), (x1 - bev, y0 + bev), (x1 - bev, y1 - bev), (x0 + bev, y1 - bev))]
            for i in range(4):
                j = (i + 1) % 4
                bm.faces.new((mid[i], mid[j], up[j], up[i]))
            bm.faces.new(up)
            x += w


def ring_tiles(pick, cu, cd, r0, r1, n, h, phase=0.0):
    for i in range(n):
        t0, t1 = phase + i / n * math.tau, phase + (i + 1) / n * math.tau
        g = 0.012
        pts = [(r0, t0 + g), (r1, t0 + g * r0 / r1), (r1, t1 - g * r0 / r1), (r0, t1 - g)]
        target = pick(i)
        lo = [target.verts.new(at(cu + math.cos(t) * r, cd + math.sin(t) * r, h - 0.3)) for r, t in pts]
        hi = [target.verts.new(at(cu + math.cos(t) * r, cd + math.sin(t) * r, h)) for r, t in pts]
        for k in range(4):
            j = (k + 1) % 4
            target.faces.new((lo[k], lo[j], hi[j], hi[k]))
        target.faces.new(hi)


def ground():
    rng = random.Random(11)
    under = bag("Ground", "Stone", "stone_sand")
    index = 0
    for d0, d1, h, rows in ((0.0, SQ_D - RUN, 0.0, 1), (SQ_D + 0.45, TR_D - RUN, SQ_H, 1), (TR_D + 0.45, D, TR_H, 1)):
        plain_box(under, -HX, HX, d0, d1, h - 1.6, h - 0.24)
        for r in range(rows):
            for c in range(3):
                index += 1
                flags2(bag(f"Paving{index}", "Stone", "stone_sand" if h == TR_H else "stone_pave"), -HX + c * W / 3, -HX + (c + 1) * W / 3, d0 + r * (d1 - d0) / rows, d0 + (r + 1) * (d1 - d0) / rows, h, rng)
    # the spawn medallion, larger than the old court's
    clay, teal, trim = bag("Medallion", "Clay", "stone_clay"), bag("Medallion", "Teal", "stone_teal"), bag("Medallion", "Trim", "stone_trim")
    h = SQ_H + 0.05
    ring_tiles(lambda i: trim, 0, SPAWN_D, 0.5, 3.0, 8, h)
    ring_tiles(lambda i: teal if i % 2 == 0 else trim, 0, SPAWN_D, 3.2, 7.2, 12, h, 0.13)
    ring_tiles(lambda i: clay if i % 2 == 0 else teal, 0, SPAWN_D, 7.4, 10.6, 20, h)
    ring_tiles(lambda i: trim, 0, SPAWN_D, 10.8, 11.8, 28, h, 0.05)


# --- steps and the planters at their ends --------------------------------------------------------------------------
def stairs():
    rng = random.Random(23)
    steps = bag("Steps", "Stone", "stone_trim")
    prev = 0.0
    for index, (start, rise) in enumerate(TERRACES):
        a = start - RUN
        run, lift = RUN / 3, (rise - prev) / 3
        for k in range(3):
            x = -STEP_HALF
            while x < STEP_HALF - 0.01:
                w = min(rng.uniform(9.0, 14.0), STEP_HALF - x)
                if STEP_HALF - (x + w) < 5:
                    w = STEP_HALF - x
                crate(steps, x + w / 2, a + (k + 0.5) * run + 0.25, prev - 0.7, (w - 0.1, run + 0.5, lift * (k + 1) + 0.7), rng)
                x += w
        COLLISION.append({"kind": "wedge", "u0": -HX, "u1": HX, "d0": start - LEAD - RUN, "d1": start - LEAD, "h0": prev, "h1": rise})
        box_c(-HX, HX, start - LEAD, D, prev - 1.0, rise)
        for s in (-1, 1):
            u0, u1 = (STEP_HALF, HX) if s > 0 else (-HX, -STEP_HALF)
            if index == 0 and s < 0:
                continue  # the obby's ramp climbs here instead of a planter
            plants = [BUSHES[(index + i) % 5] if i % 3 == 0 else PLANTS_LOW[(index * 3 + i + (0 if s > 0 else 4)) % 10] for i in range(5)]
            bed(u0, u1, start - RUN - 3, start + 3, prev, rng, plants, wall=rise - prev + 1.7)
        prev = rise


# --- the edge: retaining wall, parapet, posts with lanterns ---------------------------------------------------------
def edges():
    rng = random.Random(37)
    wall, parapet = bag("Retaining", "Stone", "stone_cream"), bag("Parapet", "Stone", "stone_trim")

    def course(p0, p1, h_top, rows, size_h, along_u, out, thick=1.8, target=wall, length=12.0):
        n = max(1, round(abs(p1 - p0) / length))
        seg = (p1 - p0) / n
        for r in range(rows):
            for i in range(n):
                c = p0 + (i + 0.5) * seg + (seg / 2 if r % 2 else 0.0)
                size = (abs(seg) - 0.1, thick, size_h) if along_u else (thick, abs(seg) - 0.1, size_h)
                ht = h_top(min(max(c, 0.0), D)) if callable(h_top) else h_top
                crate(target, c if along_u else out, out if along_u else c, ht - (r + 1) * size_h, size, rng)

    course(-HX - 1, HX + 1, -0.3, 2, 4.5, True, -1.0)
    course(-HX - 1, HX + 1, TR_H - 0.3, 3, 4.5, True, D + 1.0)
    for s in (-1, 1):
        course(0, D, lambda d: height_at(d) - 0.3, 3, 4.5, False, s * (HX + 1.0))
    course(-HX - 1, HX + 1, 0.55, 1, 0.85, True, -0.95, thick=1.5, target=parapet, length=6.0)
    course(-HX - 1, HX + 1, TR_H + 1.5, 1, 1.8, True, D + 0.95, thick=1.5, target=parapet, length=6.0)
    # the recovery cliff (2026-11-20): the right side is left open from Edge.Back0 to Edge.Back1, no parapet, no posts
    edge = next(z["Edge"] for z in SECTIONS["Sections"] if z.get("Edge"))
    course(4, D, lambda d: height_at(d) + 1.5, 1, 1.8, False, -(HX + 0.95), thick=1.5, target=parapet, length=6.0)
    course(4, edge["Back0"], lambda d: height_at(d) + 1.5, 1, 1.8, False, HX + 0.95, thick=1.5, target=parapet, length=6.0)
    course(edge["Back1"], D, lambda d: height_at(d) + 1.5, 1, 1.8, False, HX + 0.95, thick=1.5, target=parapet, length=6.0)
    posts = [(s * (HX + 0.95), d) for s in (-1, 1) for d in [0.0] + list(range(27, int(D) - 10, 27)) + [D + 0.95]
             if not (s > 0 and edge["Back0"] - 3 <= d <= edge["Back1"] + 3)]
    posts += [(HX + 0.95, edge["Back0"] - 1.0), (HX + 0.95, edge["Back1"] + 1.0)]  # one post each end of the opening
    posts += [(u, D + 0.95) for u in range(-50, 51, 25) if u != 0]  # none in the middle: the obby jumps out over it
    for u, d in posts:
        h = height_at(min(max(d, 0), D))
        front = d < 1
        tall = 2.2 if front else 3.4
        dd = -0.95 if front else d
        crate(parapet, u, dd, h - 0.4, (2.2, 2.2, tall + 0.4), rng)
        crate(parapet, u, dd, h + tall, (2.8, 2.8, 0.5), rng)
        inward = (0.0, 1.0) if d >= D else ((0.0, -1.0) if front else (-math.copysign(1.0, u), 0.0))
        LAMPS.append((u, dd, h + tall + 0.5, inward, 5.2))


# --- the crag under and round the village --------------------------------------------------------------------------
def crag():
    rng = random.Random(53)
    k = SCALE
    bands = {key: bag("Crag", key.split("_")[1].capitalize(), key) for key in ("stone_cream", "stone_sand", "stone_blue")}

    def rock(key, u, d, h_foot, size, lean=0.0, cuts=None, top=None, soft=False):
        c = chunk(size, rng, cuts=cuts or rng.randint(11, 15), bevel=0.06 if soft else 0.0)
        if top is not None:
            flat_top(c, top - h_foot)
        append(bands[key], c, T(u, d, h_foot, rng.uniform(0, math.tau)) @ Matrix.Rotation(lean, 4, "Y"))

    for inset, h_top, sz, key, n_u, n_d in ((3.0, -1.0, (68, 62, 48), "stone_cream", 5, 6), (-4.0, -34.0 * k, (86, 78, 60), "stone_sand", 4, 5), (-22.0 * k, -76.0 * k, (96, 88, 72), "stone_blue", 3, 4)):
        ux, dx = HX + inset, D / 2 + inset
        pts = [(((i + 0.5) / n_u * 2 - 1) * ux, D / 2 + sd * dx) for i in range(n_u) for sd in (-1, 1)]
        n_d = round(n_d * D / 216.0)  # as many rocks down each side, per stud, as the 216-deep lobby had
        pts += [(sd * ux, D / 2 + ((i + 0.5) / n_d * 2 - 1) * dx) for i in range(n_d) for sd in (-1, 1)]
        for u, d in pts:
            size = tuple(v * k * rng.uniform(0.85, 1.15) for v in sz)
            rock(key, u * 0.93, D / 2 + (d - D / 2) * 0.93, h_top - size[2] * 0.7, size, top=h_top if inset > 0 else None)
    plain_box(bands["stone_sand"], -HX + 14, HX - 14, 14, D - 14, -100 * k, -1.7)
    for u, d, h, sz in ((0, D / 2, -250, (190, 170, 150)), (-50, D / 2 + 50, -190, (150, 140, 120)), (60, D / 2 - 40, -184, (146, 136, 116)), (0, D / 2, -330, (100, 90, 130))):
        rock("stone_blue" if h < -230 else "stone_sand", u * k, D / 2 + (d - D / 2) * k, h * k, tuple(v * k for v in sz), cuts=14)
    spires = [
        # 2026-11-20: none in the sky leg's corridor behind the middle, none off the recovery cliff's open edge
        (-58, D + 16, -18, (24, 22, 78), 0.05, "stone_cream"), (-40, D + 30, -26, (26, 22, 96), -0.04, "stone_sand"),
        (40, D + 30, -26, (22, 20, 80), 0.06, "stone_cream"), (58, D + 26, -24, (30, 26, 112), 0.03, "stone_sand"),
        (-HX - 16, D - 20, -20, (22, 24, 90), 0.05, "stone_sand"), (-HX - 14, D - 70, -16, (18, 20, 56), -0.05, "stone_cream"),
        (HX + 14, D + 6, -22, (20, 20, 70), -0.04, "stone_cream"), (HX + 13, 196, -14, (18, 18, 50), 0.06, "stone_blue"),
        (-HX - 11, 100, -12, (14, 16, 32), 0.04, "stone_blue"), (HX + 12, 88, -12, (16, 14, 28), -0.05, "stone_sand"),
    ]
    for u, d, h, sz, lean, key in spires:
        rock(key, u, d, h, sz, lean, soft=True)
    # shelves just outside the walls, each with a kit tree on a soil mound at its middle
    for u, d, top, sz, big in ((HX + 16, 150, 9.0, (24, 26, 32), 1.5), (-HX - 15, 160, 8.0, (24, 28, 32), 1.7), (-HX - 14, 52, 1.0, (20, 24, 26), 1.4),
                               (HX + 15, 66, 0.0, (22, 22, 26), 1.6), (-38, D + 17, 11.0, (28, 20, 32), 1.6), (38, D + 16, 12.0, (26, 20, 32), 1.8),
                               (HX + 16, 205, 9.0, (24, 26, 32), 1.7), (-HX - 15, 268, 8.5, (24, 28, 32), 1.5)):
        rock("stone_cream", u, d, top - sz[2] * 0.5, sz, top=top, soft=True)
        yaw = rng.uniform(0, 6.28)
        put("Rock_Flat_Slab", u, d, top - 2.5, yaw, 3.0, skin="soil")
        sakura(u, d, top, rng, s=big, solid=False, petals=abs(u) > HX and 100 < d < 200)
        fallen_petals(u, d, top + 0.02, 1.0, 5.5, 26, rng)
        for asset, scale, ang in (("Bush_Low", 1.2, 0.6), ("Plant_Tall_Blade", 1.4, 2.6), ("Rock_Small_A", 1.3, 4.6)):
            put(asset, u + math.cos(ang) * 3.0, d + math.sin(ang) * 3.0, top, rng.uniform(0, 6.28), scale)


# --- sakura: the village's trees are all in blossom ---------------------------------------------------------------
PETALS = []  # {"u", "d", "h", "r"}: canopies petals fall from (LobbyService hangs a ParticleEmitter under each)


def sakura(u, d, h, rng, s=1.0, solid=True, petals=False):
    """A small blossom tree: a leaning plum-brown trunk, three boughs, pink masses with paler ones among them."""
    bark, pink, blush = bag("Sakura", "Bark", "bark"), bag("Sakura", "Leaf", "leaf_pink"), bag("Sakura", "Blush", "leaf_blush")
    base = at(u, d, h - 0.4)
    lean = Vector((rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), 0))
    trunk = [base, base + (lean * 0.4 + Vector((0, 0, 3.4))) * s, base + (lean + Vector((0, 0, 6.6))) * s]
    tube(bark, trunk, [0.85 * s, 0.62 * s, 0.45 * s], sides=6, rng=rng)
    turn = rng.uniform(0, math.tau)
    for k in range(3):
        a = turn + k * math.tau / 3
        tip = trunk[-1] + Vector((math.cos(a) * 3.4, math.sin(a) * 3.4, 2.2 + k * 0.7)) * s
        tube(bark, [trunk[-2], trunk[-1] + (tip - trunk[-1]) * 0.5 + Vector((0, 0, 0.5 * s)), tip], [0.4 * s, 0.3 * s, 0.18 * s], sides=5, rng=rng)
        append(pink, canopy_mass(3.6 * s, rng, squash=0.66, cuts=4), Matrix.Translation(tip + Vector((0, 0, 0.8 * s))))
        o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.1, 0.6))) * 2.6 * s
        append(blush, canopy_mass(2.3 * s, rng, squash=0.7, cuts=3), Matrix.Translation(tip + o))
    append(blush, canopy_mass(3.2 * s, rng, squash=0.6, cuts=4), Matrix.Translation(trunk[-1] + Vector((0, 0, 3.4 * s))))
    if solid:
        pole_c(u, d, 0.9 * s, h)
    if petals:
        PETALS.append({"u": round(u, 1), "d": round(d, 1), "h": round(h + 8.0 * s, 1), "r": round(5.0 * s, 1)})


def fallen_petals(cu, cd, h, r0, r1, n, rng):
    """Petals on the ground: tiny flat pink and pale diamonds scattered in a ring. Two triangles each."""
    for i in range(n):
        a, r = rng.uniform(0, math.tau), math.sqrt(rng.uniform(r0 * r0, r1 * r1))
        target = cloth("Petals", "cloth_coral") if i % 3 else bag("Petals", "Blush", "leaf_blush")
        c = at(cu + math.cos(a) * r, cd + math.sin(a) * r, h + 0.07 + (i % 5) * 0.004)
        t, w, l = rng.uniform(0, math.tau), rng.uniform(0.22, 0.4), rng.uniform(0.4, 0.7)
        ax, ay = Vector((math.cos(t), math.sin(t), 0)), Vector((-math.sin(t), math.cos(t), 0))
        target.faces.new([target.verts.new(c + v) for v in (ax * l, ay * w, -ax * l, -ay * w)])


# --- the great tree: the square's landmark, on a round bed, with the obby's deck round its trunk -------------------
def great_tree():
    rng = random.Random(67)
    cu, cd = TREE
    s = 1.35
    top = SQ_H + 1.9
    stone, soil, bark, leaf = bag("GreatTree", "Stone", "stone_trim"), bag("GreatTree", "Soil", "soil"), bag("GreatTree", "Bark", "bark"), bag("GreatTree", "Leaf", "leaf_pink")
    n = 12
    for i in range(n):
        a = i / n * math.tau
        append(stone, block((5.9, 1.8, 2.7), rng, chip=0.1, bevel=0.06), T(cu + math.cos(a) * 11, cd + math.sin(a) * 11, SQ_H - 0.8, math.atan2(-math.cos(a), -math.sin(a))))
    tube(soil, [at(cu, cd, SQ_H), at(cu, cd, top - 0.35)], [10.6, 10.6], sides=12)
    cyl_c(cu, cd, 11.8, SQ_H - 1.0, top)
    base = at(cu, cd, top - 0.4)
    trunk = [base, base + Vector((0.5, 0.4, 5)) * s, base + Vector((1.6, -0.3, 10)) * s, base + Vector((1.2, 0.6, 15)) * s]
    tube(bark, trunk, [r * s for r in (2.1, 1.7, 1.35, 1.1)], sides=9, rng=rng)
    for k in range(6):
        a = k / 6 * math.tau + 0.4
        tube(bark, [base + Vector((0, 0, 1.4 * s)), base + Vector((math.cos(a) * 2.6, math.sin(a) * 2.6, 0.3)) * s + Vector((0, 0, 0)), base + Vector((math.cos(a) * 4.4 * s, math.sin(a) * 4.4 * s, -0.2))], [1.0 * s, 0.7 * s, 0.3 * s], sides=6, rng=rng)
    for off, r in (((7.5, -4.5, 7.0), 8.6), ((-5.5, 5.0, 7.5), 8.0), ((2.5, 8.5, 9.0), 7.4), ((-3.0, -7.5, 8.0), 7.2), ((0.6, 0.4, 12.5), 9.6), ((-8.0, -2.0, 10.0), 7.0)):
        tip = trunk[-1] + Vector(off) * s
        mid = trunk[-2] + (tip - trunk[-2]) * 0.55 + Vector((0, 0, 1.2 * s))
        tube(bark, [trunk[-2], mid, tip], [0.95 * s, 0.6 * s, 0.35 * s], sides=6, rng=rng)
        append(leaf, canopy_mass(r * s, rng, squash=0.7, cuts=5), Matrix.Translation(tip + Vector((0, 0, r * s * 0.25))))
        for _ in range(2):
            o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 0.5))) * r * s * 0.8
            append(bag("GreatTree", "Blush", "leaf_blush"), canopy_mass(r * s * rng.uniform(0.5, 0.68), rng, squash=0.72, cuts=4), Matrix.Translation(tip + o))
    cyl_c(cu, cd, 3.0, top - 1, NOPERCH)
    PETALS.append({"u": cu, "d": cd, "h": round(top + 19.0 * s, 1), "r": round(15.0 * s, 1)})
    fallen_petals(cu, cd, SQ_H, 12.4, 27.0, 230, rng)
    fallen_petals(cu, cd, top - 0.3, 3.5, 10.0, 60, rng)
    for i, asset in enumerate(("Bush_Round", "Flowers_Coral", "Plant_Broadleaf", "Bush_Double", "Flowers_Daisy_Big", "Plant_Spiky", "Flowers_Bell", "Bush_Low", "Flowers_Tulip", "Plant_Roundleaf")):
        a = i / 10 * math.tau
        put(asset, cu + math.cos(a) * 7.4, cd + math.sin(a) * 7.4, top - 0.35, rng.uniform(0, 6.28), 1.3)
    for a in (0.0, math.pi):  # benches in the shade, either side
        bench(cu + math.cos(a) * 15.5, cd + math.sin(a) * 15.5, SQ_H, rng, along_d=abs(math.cos(a)) > 0.7)


# --- shops: real little buildings. Walls, a pitched tile roof, an open shopfront with the keeper in plain sight -----
def shop(u0, u1, d0, d1, base, face, rng, key, station):
    """A shop house (owner, 2026-11-18: "the stand should be actual buildings", nothing in front of the keeper, a
    roof worth looking at). The front is open from the counter up to the lintel; the awning sits ABOVE head height;
    the sign hangs off the corner, not across the front. Nothing here is part of the obby."""
    wall, tim, roof = bag("Shops", "Plaster", "stone_trim"), bag("Shops", "Timber", "bark_timber"), bag("Shops", "Roof", "stone_roof")
    c1, c2 = cloth("Shops", key), cloth("Shops", "cloth_cream")
    uf, ub = (u1, u0) if face > 0 else (u0, u1)
    eave, ridge, dm, um = base + 9.2, base + 14.6, (d0 + d1) / 2, (u0 + u1) / 2
    lo, hi = min(ub, ub + face * 0.8), max(ub, ub + face * 0.8)
    plain_box(wall, lo, hi, d0, d1, base, eave)  # back wall
    box_c(lo, hi, d0, d1, base, eave)
    for da, db in ((d0, d0 + 0.8), (d1 - 0.8, d1)):  # side walls
        plain_box(wall, u0, u1, da, db, base, eave)
        box_c(u0, u1, da, db, base, eave)
        gable = [at(u0, (da + db) / 2, eave), at(u1, (da + db) / 2, eave), at(um, (da + db) / 2, ridge - 0.3)]
        wall.faces.new([wall.verts.new(v) for v in gable])
    cu = uf - face * 0.8  # the counter: a low front wall with a plank top
    plain_box(wall, min(cu - 0.8, cu + 0.8), max(cu - 0.8, cu + 0.8), d0 + 0.8, d1 - 0.8, base, base + 2.8)
    crate(tim, cu, dm, base + 2.8, (2.6, d1 - d0 - 1.2, 0.4), rng)
    box_c(cu - 1.3, cu + 1.3, d0, d1, base, base + 3.2)
    for d in (d0 + 0.4, d1 - 0.4):  # corner posts and the lintel over the opening
        tube(tim, [at(uf, d, base - 0.2), at(uf, d, eave)], [0.55, 0.48], sides=6, rng=rng)
        tube(tim, [at(ub, d, base - 0.2), at(ub, d, eave)], [0.5, 0.45], sides=6, rng=rng)
    tube(tim, [at(uf, d0 - 0.6, eave - 0.3), at(uf, d1 + 0.6, eave - 0.3)], [0.45, 0.45], sides=6, rng=rng)
    # the roof: two slopes of overlapping tile courses, a timber ridge
    over = 1.8
    for side in (-1, 1):
        e_u = um + side * ((u1 - u0) / 2 + over)
        courses = 5
        for k in range(courses):
            t0, t1 = k / courses, (k + 1) / courses + 0.06
            ua, ub2 = e_u + (um - e_u) * t0, e_u + (um - e_u) * min(t1, 1.0)
            ha, hb = eave - 0.5 + (ridge - eave + 0.5) * t0 + 0.28, eave - 0.5 + (ridge - eave + 0.5) * min(t1, 1.0)
            vs = [roof.verts.new(at(x, d, h + dz)) for dz in (0.0, 0.45) for (x, h) in ((ua, ha), (ub2, hb)) for d in (d0 - 1.4, d1 + 1.4)]
            for quad in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
                roof.faces.new([vs[i] for i in quad])
    tube(tim, [at(um, d0 - 1.7, ridge + 0.1), at(um, d1 + 1.7, ridge + 0.1)], [0.4, 0.4], sides=6, rng=rng)
    # the awning: striped canvas reaching out over the customer, its edge above head height
    n = 6
    for i in range(n):
        a, b = d0 - 0.4 + i * (d1 - d0 + 0.8) / n, d0 - 0.4 + (i + 1) * (d1 - d0 + 0.8) / n
        t = c1 if i % 2 == 0 else c2
        p = [at(uf, a, eave - 0.1), at(uf, b, eave - 0.1), at(uf + face * 4.6, b, eave - 1.5), at(uf + face * 4.6, a, eave - 1.5)]
        t.faces.new([t.verts.new(q) for q in p])
        low = Vector((0, 0, -0.5))
        t.faces.new([t.verts.new(q) for q in (p[3], p[2], p[2] + low, (p[2] + p[3]) / 2 + Vector((0, 0, -0.9)), p[3] + low)])
    for d in (d0 + 0.4, d1 - 0.4):
        tube(tim, [at(uf, d, eave - 3.4), at(uf + face * 4.5, d, eave - 1.6)], [0.2, 0.18], sides=5, rng=rng)
        hang(at(uf + face * 4.2, d, eave - 1.7), drop=0.4, s=0.75)
    # the sign: a board in the shop's colour on a bracket at the corner, side-on to the street
    tube(tim, [at(uf, d0 - 0.2, eave - 1.0), at(uf + face * 0.2, d0 - 4.0, eave - 1.0)], [0.2, 0.2], sides=5, rng=rng)
    crate(tim, uf + face * 0.1, d0 - 2.4, eave - 4.2, (0.5, 3.4, 2.8), rng)
    for off in (-0.3, 0.3):
        q = [at(uf + face * 0.1 + off, d0 - 3.9, eave - 3.9), at(uf + face * 0.1 + off, d0 - 0.9, eave - 3.9), at(uf + face * 0.1 + off, d0 - 0.9, eave - 1.7), at(uf + face * 0.1 + off, d0 - 3.9, eave - 1.7)]
        c1.faces.new([c1.verts.new(v) for v in q])
    # inside: shelves on the back wall with jars, the stock behind the keeper
    clay = bag("Shops", "Clay", "stone_clay")
    profile = [(0.0, 0.5), (0.4, 0.8), (1.1, 0.95), (1.7, 0.7), (2.0, 0.45)]
    for z in (4.2, 6.6):
        crate(tim, ub + face * 1.6, dm, base + z, (1.6, d1 - d0 - 3.0, 0.3), rng)
        for k, t in enumerate((0.22, 0.5, 0.78)):
            s = (0.62, 0.5, 0.7)[(k + int(z)) % 3]
            tube(clay, [at(ub + face * 1.6, d0 + (d1 - d0) * t, base + z + 0.3 + pz * s) for pz, _ in profile], [r * s for _, r in profile], sides=7, rng=rng, jitter=0.03)
    crate(tim, ub + face * 2.2, d1 - 2.6, base, (2.2, 2.2, 2.2), rng, 0.3)
    name, role, page, action = station
    STATIONS.append({"name": name, "role": role, "page": page, "action": action, "u": round(cu - face * 2.6, 1), "d": round(dm, 1), "h": base, "fx": face, "fz": 0})
    clay_t, teal_t, trim_t = bag("Medallion", "Clay", "stone_clay"), bag("Medallion", "Teal", "stone_teal"), bag("Medallion", "Trim", "stone_trim")
    ru = uf + face * 4.6
    ring_tiles(lambda i: trim_t, ru, dm, 0.4, 1.8, 6, base + 0.05)
    ring_tiles(lambda i: clay_t if key in ("cloth_coral", "cloth_gold") else teal_t, ru, dm, 2.0, 3.8, 10, base + 0.05, 0.2)


def shops():
    """Three shops down each side of the square, 44 studs from spawn, facing it. Training's two keepers have the
    shops nearest the training steps; the shop page's two have the middle of the right-hand row."""
    rng = random.Random(71)
    h = SQ_H
    rows = ((40, 58), (64, 82), (88, 106))
    left = (("Outfitter", "more", "more", "Browse", "cloth_teal"), ("Ranked Herald", "ranked", "ranked", "Ranked", "cloth_coral"), ("Moves Master", "moves", "moves", "Learn moves", "cloth_gold"))
    right = (("Coin Exchange", "coins", "shop", "Get coins", "cloth_gold"), ("Gamepass Merchant", "gamepasses", "shop", "Open the shop", "cloth_coral"), ("Class Master", "classes", "classes", "Choose a class", "cloth_teal"))
    for (d0, d1), l, r in zip(rows, left, right):
        shop(-56, -44, d0, d1, h, 1, rng, l[4], l[:4])
        shop(44, 56, d0, d1, h, -1, rng, r[4], r[:4])


def hop_deck(u, d, top, rng, half_u=8.0, half_d=8.0, posts="centre"):
    """One timber deck of the course on its posts. posts: "centre" (one post, two along a long deck), "sides"
    (two at the deck's sides, so a walkway under it stays clear), "hub" (one thick post at the middle)."""
    tim = bag("Obby", "Timber", "bark_timber")
    deck(tim, u - half_u, u + half_u, d - half_d, d + half_d, top, rng)
    if posts == "sides":
        spots, radius = [(u - half_u + 0.9, d), (u + half_u - 0.9, d)], 0.8
    elif posts == "hub":
        spots, radius = [(u, d)], 1.6
    else:
        spots, radius = ([(u, d)] if half_d <= 10 else [(u, d - half_d * 0.55), (u, d + half_d * 0.55)]), 0.95
    for pu, pd in spots:
        base = height_at(pd)
        tube(tim, [at(pu, pd, base - 0.2), at(pu, pd, top - 0.6)], [radius, radius * 0.84], sides=6 if radius < 1.2 else 8, rng=rng)
        reach = min(half_u, half_d) - 0.8
        for k in range(4):
            v = Vector((math.cos(k * math.pi / 2 + 0.8), math.sin(k * math.pi / 2 + 0.8), 0))
            if posts == "sides":  # struts lean in under the deck, never out over the walk
                v = Vector(((u - pu) / max(abs(u - pu), 0.01) * 0.7, (1 if k % 2 else -1) * 0.7, 0))
            tube(tim, [at(pu, pd, top - 5.2), at(pu, pd, top - 0.7) + v * reach], [0.28, 0.26], sides=5, rng=rng)
        post_c(pu, pd, radius + 0.05, base, top - 1.1)
    box_c(u - half_u, u + half_u, d - half_d, d + half_d, top - 1.1, top)


# --- the obby: its own platforms, up the left side, over the training cross and out to the floating isles -------
def obby_course():
    """Spaced for a full-speed run (owner): gaps of 22 to 28, landings of 14 or more, each a little higher than the
    last. THE ROUTE (owner, 2026-11-20: the obby should use the training area's space and lead to another island
    behind it over floating island platforms): up the left side and over the training wall as before, then along
    the walkway cross between the four training zones (a turn deck, the Crossroads in the middle, two decks down
    the spine), out through the gap in the back wall onto the Launch Rock, over four floating isles to Bell Rock.
    From there the Haymaker glove punches you home onto the Champion's Perch. The shops are not part of it."""
    rng = random.Random(97)
    tim = bag("Obby", "Timber", "bark_timber")
    u0, u1, d0, d1, top = -72.0, -60.0, 12.0, 37.2, 12.0
    n = 12
    for i in range(n):
        a, b = d0 + i * (d1 - d0) / n, d0 + (i + 1) * (d1 - d0) / n
        z = top * (i + 1) / n
        plain_box(tim, u0, u1, a + 0.06, b - 0.06, z - 0.7, z)
    for u in (u0 + 1.0, u1 - 1.0):
        tube(tim, [at(u, d0, 0.1), at(u, d1, top - 0.9)], [0.42, 0.42], sides=5, rng=rng)
        for t in (0.34, 0.62, 0.9):
            dd = d0 + (d1 - d0) * t
            tube(tim, [at(u, dd, height_at(dd) - 0.2), at(u, dd, top * t - 0.8)], [0.5, 0.42], sides=6, rng=rng)
    COLLISION.append({"kind": "wedge", "u0": u0, "u1": u1, "d0": d0, "d1": d1, "h0": 0.0, "h1": top})
    banner(u1 + 1.6, d0 + 1.0, 0.0, "cloth_teal", rng, tall=11.0, face=0.0, solid=False)
    obby("Ramp", top, u0, u1, d0, d1, how="run up it, from the balcony's left corner")
    # (name, u, d, top, half_u, half_d, posts, how). posts: "centre" one post, "sides" two at the walkway's edges
    # so the walk under the deck stays clear, "hub" one thick post at the middle of the cross.
    route = (
        ("Deck 1", -66, 71, 13.0, 8, 8, "centre", "straight on off the ramp, 1 up"),
        ("Deck 2", -66, 113, 17.0, 8, 8, "centre", "running jump, 4 up"),
        ("Deck 3", -66, 153, 18.0, 8, 8, "centre", "over the training wall, 1 up"),
        ("Deck 4", -66, 194, 19.0, 8, 8, "centre", "running jump, 1 up, above the dummy row's far edge"),
        ("Turn deck", -42, 234, 20.0, 8, 8, "centre", "running jump onto the walkway cross, 1 up; turn right"),
        ("Crossroads", 0, 234, 21.0, 12, 12, "hub", "running jump, 1 up: the middle of the cross; turn left"),
        ("Spine 1", 0, 278, 22.0, 8, 8, "sides", "running jump down the spine, 1 up"),
        ("Spine 2", 0, 318, 23.0, 8, 8, "sides", "running jump, 1 up; next, out through the gap in the back wall"),
    )
    prev = None
    for name, u, d, top_h, hu, hd, posts, how in route:
        hop_deck(u, d, top_h, rng, hu, hd, posts=posts)
        obby(name, top_h, u - hu, u + hu, d - hd, d + hd, how=how)
        if prev is not None:  # a garland slung under the way across, below the line you jump
            pu, pd, ph, phu, phd = prev
            du, dd = u - pu, d - pd
            if abs(du) > abs(dd):
                a, b = at(pu + math.copysign(phu, du), pd, ph - 1.3), at(u - math.copysign(hu, du), d, top_h - 1.3)
            else:
                a, b = at(pu, pd + math.copysign(phd, dd), ph - 1.3), at(u, d - math.copysign(hd, dd), top_h - 1.3)
            bunting(a, b, start=len(OBBY))
        prev = (u, d, top_h, hu, hd)
    sky_leg(rng)
    # the Champion's Perch: a stone tower on the balcony's right corner, the best view in the village. Since
    # 2026-11-20 the course no longer climbs to it: the Haymaker glove on Bell Rock punches you onto it.
    tower, gold = bag("Perch", "Stone", "stone_cream"), cloth("Perch", "cloth_gold")
    for k in range(5):
        for iu in (0, 1):
            for idd in (0, 1):
                append(tower, block((9.2 - k * 0.12, 9.2 - k * 0.12, 6.0), rng, chip=0.12, bevel=0.05), T(61.5 + iu * 9, 5.5 + idd * 9, k * 5.7 - 0.3, rng.uniform(-0.03, 0.03)))
    box_c(57, 75, 1, 19, 0.0, 28.0)
    deck(tim, 55, 75, 0.5, 19.5, 29.0, rng, thick=1.0)
    box_c(55, 75, 0.5, 19.5, 28.0, 29.0)
    for u, key in ((56, "cloth_gold"), (74, "cloth_coral")):
        banner(u, 1.5, 29.0, key, rng, tall=11.0, face=math.pi / 2)
    crate(tower, 65, 4.5, 29.0, (4.6, 4.6, 2.0), rng)
    cup = [(0.0, 1.0), (0.4, 1.2), (0.8, 0.45), (1.8, 0.4), (2.2, 1.1), (3.3, 1.7), (4.0, 1.9), (4.1, 1.6)]
    tube(gold, [at(65, 4.5, 31.0 + z) for z, _ in cup], [r for _, r in cup], sides=10, rng=rng, jitter=0.0)
    box_c(62.7, 67.3, 2.2, 6.8, 29.0, 31.0)
    for i, o in enumerate(OBBY):
        o["n"] = i + 1


# --- the sky leg: floating isles behind the lobby, and Bell Rock ----------------------------------------------------
SKY = cfg["Sky"]
ISLES = ((-14.0, 402.0, 27.0, 7.0), (12.0, 436.0, 29.0, 7.0), (-10.0, 472.0, 31.0, 7.0), (10.0, 506.0, 33.0, 7.0))


def float_isle(u, d, top, r, rng, element="Isles", depth=None):
    """A floating island: a broad faceted rock cut flat at its widest and tapered to a point underneath, a second
    smaller rock hung below it, and a grass top that follows the rock's own faceted outline with a stone rim
    showing. Scaled so the top is at least r + 0.8 from the middle in every direction (the obby's landing is a
    circle of radius r, proven by check_obby.py). Solid only at the top."""
    stone, under, grass = bag(element, "Stone", "stone_cream"), bag(element, "Under", "stone_blue"), bag(element, "Grass", "leaf_pink")
    depth = depth or r * 2.2
    c = chunk((r * 2.5, r * 2.4, depth * 2.0), rng, cuts=rng.randint(9, 12), bevel=0.0)
    flat_top(c, depth)
    on_top = lambda v: abs(v.co.z - depth) < 1e-3
    rim = [e for e in c.edges if on_top(e.verts[0]) and on_top(e.verts[1]) and any(not all(on_top(x) for x in f.verts) for f in e.link_faces)]

    def edge_distance(e):  # from the middle to the rim edge, flat
        p, q = Vector((e.verts[0].co.x, e.verts[0].co.y)), Vector((e.verts[1].co.x, e.verts[1].co.y))
        t = max(0.0, min(1.0, (-p).dot(q - p) / max((q - p).length_squared, 1e-9)))
        return (p + (q - p) * t).length

    inner = min(edge_distance(e) for e in rim)
    grow = (r + 0.8) / inner
    for v in c.verts:
        t = max(0.0, min(1.0, v.co.z / depth))  # the lower it is, the narrower
        k = grow * (0.3 + 0.7 * t ** 0.6)
        v.co.x *= k
        v.co.y *= k
    yaw = rng.uniform(0, math.tau)
    place = T(u, d, top - 0.35 - depth, yaw)
    outline = sorted({(v.co.x, v.co.y) for v in c.verts if on_top(v)}, key=lambda p: math.atan2(p[1], p[0]))
    append(stone, c, place)
    low = chunk((r * 1.0, r * 0.95, depth * 0.55), rng, cuts=11, bevel=0.0)
    append(under, low, T(u + rng.uniform(-r * 0.15, r * 0.15), d + rng.uniform(-r * 0.15, r * 0.15), top - depth * 0.8, rng.uniform(0, math.tau)) @ Matrix.Rotation(math.pi, 4, "X"))
    # the grass: the top outline pulled in by 0.7 (a stone rim shows), 0.4 thick
    g = bmesh.new()
    lo, hi = [], []
    for x, y in outline:
        k = max(0.0, 1.0 - 0.7 / max(math.hypot(x, y), 0.01))
        lo.append(g.verts.new((x * k, y * k, depth - 0.05)))
        hi.append(g.verts.new((x * k, y * k, depth + 0.35)))
    for i in range(len(lo)):
        j = (i + 1) % len(lo)
        g.faces.new((lo[i], lo[j], hi[j], hi[i]))
    g.faces.new(hi)
    bmesh.ops.recalc_face_normals(g, faces=g.faces[:])
    bmesh.ops.triangulate(g, faces=g.faces[:])
    append(grass, g, place)
    cyl_c(u, d, r, top - 1.2, top)


def summit_flag(u, d, h, rng, tall=30.0):
    """A tall pole with a big gold pennant: the obby's goal, seen over the training wall from the square."""
    tim, gold = bag("BellRock", "Timber", "bark_timber"), cloth("BellRock", "cloth_gold")
    tube(tim, [at(u, d, h - 0.3), at(u, d, h + tall)], [0.7, 0.45], sides=7, rng=rng)
    tube(tim, [at(u, d, h + tall), at(u, d, h + tall + 0.8)], [0.8, 0.2], sides=7, rng=rng)
    pole_c(u, d, 0.8, h)
    rows = 5
    pts = []
    for k in range(rows + 1):
        t = k / rows
        wave = math.sin(t * 3.0) * 0.8 * t
        top_z, bot_z = h + tall - 0.6 - t * 1.6, h + tall - 8.6 + t * 5.4
        pts.append((gold.verts.new(at(u + 0.5 + t * 13.0, d + wave, top_z)), gold.verts.new(at(u + 0.5 + t * 13.0, d + wave, bot_z))))
    for k in range(rows):
        gold.faces.new((pts[k][0], pts[k + 1][0], pts[k + 1][1], pts[k][1]))


def bell_post(u, d, h, rng):
    """THE BELL: a gold boxing-ring bell on a timber frame (two posts, a beam), its striker hanging beside it.
    The bell itself is its own element (Lobby_Bell_*), so the client can swing it when it rings."""
    frame, gold, dark = bag("BellFrame", "Timber", "bark_timber"), bag("Bell", "Gold", "cloth_gold"), bag("Bell", "Iron", "bark")
    for s in (-1, 1):
        tube(frame, [at(u + s * 3.2, d, h - 0.3), at(u + s * 3.2, d, h + 9.2)], [0.55, 0.45], sides=6, rng=rng)
        cyl_c(u + s * 3.2, d, 0.7, h, h + 9.2)
    tube(frame, [at(u - 4.2, d, h + 8.9), at(u + 4.2, d, h + 8.9)], [0.5, 0.5], sides=6, rng=rng)
    crate(frame, u, d, h - 0.2, (8.6, 2.0, 0.6), rng)
    # the bell: a domed cup, mouth down, on a short iron hanger
    tube(dark, [at(u, d, h + 8.6), at(u, d, h + 7.6)], [0.18, 0.18], sides=5, caps=(False, False), jitter=0.0)
    prof = [(7.7, 0.35), (7.5, 1.05), (7.0, 1.45), (6.2, 1.7), (5.4, 1.95), (5.0, 2.25), (4.85, 2.1)]
    tube(gold, [at(u, d, h + z) for z, _ in prof], [r for _, r in prof], sides=14, rng=rng, jitter=0.0)
    tube(dark, [at(u, d, h + 5.9), at(u, d, h + 4.6)], [0.16, 0.16], sides=5, jitter=0.0)
    lump_bm = lump(0.42, rng, squash=1.0, jitter=0.0, subdiv=1, flat_bottom=0.0)
    append(dark, lump_bm, Matrix.Translation(at(u, d, h + 4.4)))


def glove_machine(u, d, h, rng):
    """THE HAYMAKER: a giant red boxing glove on a timber arm, sprung from a timber frame, pointing at the village.
    Stand on the X in front of it and it punches you home. The glove and its arm are their own element
    (Lobby_Glove_*) so the client can throw the punch; the frame (Lobby_GloveFrame_*) stays put."""
    frame, red, cuff = bag("GloveFrame", "Timber", "bark_timber"), bag("Glove", "Red", "cloth_coral"), bag("Glove", "Cuff", "cloth_cream")
    arm, spring = bag("Glove", "Arm", "bark_timber"), bag("Glove", "Spring", "cloth_gold")
    hz = h + 3.6  # the fist's middle, about chest height
    # the frame: a squat box on four legs behind the glove, open toward it
    for su in (-1, 1):
        for sd in (0, 1):
            tube(frame, [at(u + su * 2.6, d + 3.0 + sd * 4.0, h - 0.3), at(u + su * 2.6, d + 3.0 + sd * 4.0, hz + 2.4)], [0.5, 0.42], sides=6, rng=rng)
    crate(frame, u, d + 5.0, hz + 2.2, (6.2, 5.2, 0.7), rng)
    crate(frame, u, d + 7.0, h - 0.2, (6.2, 1.4, hz - h + 2.2), rng)
    box_c(u - 3.2, u + 3.2, d + 2.4, d + 7.8, h, hz + 3.0)
    # the spring: a gold coil from the frame's back to the arm
    coil = [at(u + math.cos(t) * 0.9, d + 6.4 - t * 0.16, hz + math.sin(t) * 0.9) for t in [i * 0.55 for i in range(26)]]
    tube(spring, coil, [0.2] * len(coil), sides=5, caps=(False, False), jitter=0.0)
    tube(arm, [at(u, d + 2.6, hz), at(u, d - 0.3, hz)], [0.75, 0.75], sides=8, rng=rng)
    # the glove: cuff, a big padded fist, a thumb across its front
    tube(cuff, [at(u, d - 0.2, hz), at(u, d - 1.7, hz)], [2.2, 2.35], sides=12, rng=rng, jitter=0.0)
    fist = lump(3.4, rng, squash=0.82, jitter=0.04, subdiv=2, flat_bottom=0.0)
    for v in fist.verts:
        v.co.y *= 1.12
    append(red, fist, Matrix.Translation(at(u, d - 4.4, hz + 0.3)))
    thumb = lump(1.3, rng, squash=0.8, jitter=0.03, subdiv=1, flat_bottom=0.0)
    for v in thumb.verts:
        v.co.x *= 1.6
    append(red, thumb, Matrix.Translation(at(u + 0.8, d - 6.2, hz - 1.3)))
    # the X it throws you from: two crossed clay strips on the cap
    pad = SKY["Glove"]["Pad"]
    clay = bag("BellRock", "Clay", "stone_clay")
    for ang in (math.pi / 4, -math.pi / 4):
        strip = bmesh.new()
        bmesh.ops.create_cube(strip, size=1.0)
        for v in strip.verts:
            v.co = Vector((v.co.x * 5.6, v.co.y * 0.9, v.co.z * 0.16))
        bmesh.ops.triangulate(strip, faces=strip.faces[:])
        append(clay, strip, T(pad["X"], pad["Back"], h + 0.03, ang))


def sky_leg(rng):
    """The Launch Rock just past the back wall (the sky leg's checkpoint), four floating isles that climb 2 studs
    a hop, and Bell Rock: a big island with the bell, the Haymaker glove, a tree, a bench looking back at the
    village, and lanterns. Every top is round and in obby.json; check_obby.py proves every hop."""
    marks = {c["Name"]: c for c in SKY["Checkpoints"]}
    lr = marks["Launch Rock"]
    float_isle(lr["X"], lr["Back"], lr["Up"], lr["Radius"], rng, depth=24.0)
    obby("Launch Rock", lr["Up"], u=lr["X"], d=lr["Back"], r=lr["Radius"], how="through the gap in the back wall, 2 up: the checkpoint")
    put("Bush_Low", lr["X"] - lr["Radius"] + 2.0, lr["Back"] + 2.0, lr["Up"], 0.4, 1.3)
    put("Flowers_Daisy_Big", lr["X"] + lr["Radius"] - 2.2, lr["Back"] - 1.5, lr["Up"], 1.2, 1.2)
    props = (("Bush_Round", 1.2), ("Flowers_Coral", 1.25), ("Plant_Broadleaf", 1.3), ("Flowers_Tulip", 1.2))
    for i, (u, d, top, r) in enumerate(ISLES):
        float_isle(u, d, top, r, rng)
        obby(f"Isle {i + 1}", top, u=u, d=d, r=r, how="running jump, 2 up")
        side = -1 if u > 0 else 1  # a plant on the side away from the next hop's line
        put(props[i][0], u - side * (r - 1.6), d + 1.0, top, rng.uniform(0, 6.28), props[i][1])
    br = marks["Bell Rock"]
    bu, bd, bh, brr = br["X"], br["Back"], br["Up"], br["Radius"]
    float_isle(bu, bd, bh, brr, rng, element="BellRock", depth=52.0)
    obby("Bell Rock", bh, u=bu, d=bd, r=brr, how="running jump, 3 up: THE END. Ring the bell; the glove punches you home")
    summit_flag(bu - 9.0, bd + 25.0, bh, rng)
    bell = SKY["Bell"]
    bell_post(bell["X"], bell["Back"], bh, rng)
    glove = SKY["Glove"]
    glove_machine(glove["X"], glove["Back"], bh, rng)
    sakura(bu + 6.0, bd + 20.0, bh, rng, s=1.7, petals=True)
    bench(bu - 12.0, bd + 19.0, bh, rng, along_d=False)
    for u, d, way in ((bu - 26.0, bd + 8.0, (1, 0)), (bu + 26.0, bd + 6.0, (-1, 0)), (bu - 4.0, bd + 28.0, (0, 1))):
        LAMPS.append((u, d, bh, way, 7.5))
    ring = ("Bush_Big", "Flowers_Coral", "Plant_Spiky", "Bush_Round", "Flowers_Bell", "Plant_Roundleaf", "Bush_Double", "Flowers_Daisy_Small", "Plant_Tall_Blade", "Bush_Wide")
    for i, asset in enumerate(ring):
        a = math.pi * (0.2 + 0.6 * i / (len(ring) - 1))  # round the back half only; the front is the landing
        put(asset, bu + math.cos(a) * (brr - 3.0), bd + math.sin(a) * (brr - 3.0), bh, rng.uniform(0, 6.28), rng.uniform(1.2, 1.5))


# --- the square's furniture: everything here is a seat, shade, light or a notice ----------------------------------
def square():
    rng = random.Random(83)
    h = SQ_H
    tim, paper = bag("Props", "Timber", "bark_timber"), cloth("Props", "cloth_cream")
    for u in (-30, 0, 30):  # the front row's benches, at the back of the balcony
        bench(u, 17.0, 0.0, rng, along_d=False)
    for u, d, along in ((-24, 62, True), (24, 62, True), (-16, 40, False), (16, 40, False)):
        bench(u, d, h, rng, along_d=along)
    # the notice board, at the top of the balcony's steps
    for u in (-4, 4):
        tube(tim, [at(u, 33.5, h - 0.2), at(u, 33.5, h + 7.6)], [0.4, 0.34], sides=6, rng=rng)
    crate(tim, 0, 33.5, h + 3.0, (9.4, 0.5, 4.2), rng)
    crate(tim, 0, 33.5, h + 7.4, (10.6, 1.6, 0.4), rng)
    for du, dz, w, t in ((-2.6, 5.5, 2.2, 1.6), (0.2, 4.9, 1.8, 2.2), (2.8, 5.6, 2.0, 1.7), (-1.0, 3.8, 1.6, 1.2)):
        q = at(du, 33.9, h + dz)
        paper.faces.new([paper.verts.new(q + Vector(o)) for o in ((-w / 2, 0, -t / 2), (w / 2, 0, -t / 2), (w / 2, 0, t / 2), (-w / 2, 0, t / 2))])
    box_c(-4.6, 4.6, 32.9, 34.1, h, h + 7.8)
    for i, (u0, u1, d0, d1) in enumerate(((-38, -22, 104, 110), (22, 38, 104, 110), (-74, -60, 84, 100), (60, 74, 84, 100), (-74, -60, 44, 58))):
        bed(u0, u1, d0, d1, h, rng, [PLANTS_LOW[(i * 3 + k) % 10] if k % 3 else BUSHES[(i + k) % 5] for k in range(5)], wall=1.5, element="Beds")
    for u in (-30, 30):  # a small sakura in each bed at the foot of the training steps
        sakura(u, 107, h + 1.2, rng, s=1.05)
        fallen_petals(u, 107, h, 4.0, 11.0, 40, rng)
    for u, d, way in ((-36, 70, (1, 0)), (36, 52, (-1, 0)), (-12, 110, (0, -1)), (12, 110, (0, -1)), (36, 100, (-1, 0)), (-36, 46, (1, 0))):
        LAMPS.append((u, d, h, way, 8.5))
    for u, key in ((-14, "cloth_coral"), (14, "cloth_gold")):
        banner(u, 47, h, key, rng, tall=13.0, face=math.pi if u < 0 else 0.0)
    for u in (-STEP_HALF + 1.5, STEP_HALF - 1.5):
        banner(u, TR_D - RUN / 2, SQ_H, "cloth_teal" if u < 0 else "cloth_coral", rng, face=math.pi if u < 0 else 0.0)
    # bunting: every end is tied to something (a banner pole's top, a shop's ridge, the tree, the main gate)
    lines = [((-14, 47, 16.6), (14, 47, 16.6)), ((-14, 47, 16.6), (-50, 49, 18.6)), ((14, 47, 16.6), (50, 49, 18.6)), ((-50, 73, 18.6), (-1.5, 95, 21)), ((1.5, 95, 21), (50, 73, 18.6)),
             ((-50, 97, 18.6), (-13.4, WALL_D, 24.5)), ((50, 97, 18.6), (13.4, WALL_D, 24.5))]
    for i, (a, b) in enumerate(lines):
        bunting(at(*a), at(*b), start=i)


# --- the training grounds: its own zone behind a wall --------------------------------------------------------------
WALL_D = TR_D + 5.6  # the wall's middle line, just behind the stair-end planters
GATES = ((-54.0, -38.0), (-12.0, 12.0), (38.0, 54.0))  # the punching gate, the main gate, the kicking gate
BOARDS = []  # {"title", "stat", "u", "d", "h", "fx", "fz"}: where LobbyService hangs each leaderboard's face


def training_wall():
    """The zone's edge: a clay wall across the whole width at the top of the steps, with three gates. Past it the
    zone is yours alone and the fight's limits are off, so it has to be seen from anywhere on the square."""
    rng = random.Random(113)
    wall, cap, tim = bag("TrainWall", "Clay", "stone_clay"), bag("TrainWall", "Stone", "stone_trim"), bag("TrainWall", "Timber", "bark_timber")
    h = TR_H
    edges_u = [-HX] + [x for g in GATES for x in g] + [HX]
    for a, b in zip(edges_u[0::2], edges_u[1::2]):
        n = max(1, round((b - a) / 8.0))
        seg = (b - a) / n
        for r in range(2):
            for i in range(n):
                crate(wall, a + (i + 0.5) * seg, WALL_D, h - 0.3 + r * 4.0, (seg - 0.1, 2.4, 4.2), rng)
        for i in range(n):
            crate(cap, a + (i + 0.5) * seg, WALL_D, h + 7.9, (seg - 0.06, 3.2, 0.9), rng)
        box_c(a, b, WALL_D - 1.2, WALL_D + 1.2, h, h + 8.8)
        for end in (a, b):  # a pier at each gate jamb
            if abs(end) < HX - 0.1:
                pu = end + (1.4 if end == a else -1.4)
                crate(cap, pu, WALL_D, h - 0.3, (2.8, 3.4, 10.6), rng)
                hang(at(pu, WALL_D - 2.0, h + 9.4), drop=0.6, s=0.9)
        if abs((a + b) / 2) < 40:  # banners only on the two inner stretches: the outer ones are under the obby's line
            banner((a + b) / 2, WALL_D, h + 8.6, FLAGS[int(abs(a)) % 3], rng, tall=8.0, face=math.pi / 2, solid=False)
    arch((GATES[0][0], WALL_D), (GATES[0][1], WALL_D), h, "cloth_coral", rng)
    arch((GATES[2][0], WALL_D), (GATES[2][1], WALL_D), h, "cloth_gold", rng)
    g0, g1 = GATES[1]
    for u in (g0 - 1.4, g1 + 1.4):
        tube(tim, [at(u, WALL_D, h - 0.2), at(u, WALL_D, h + 17.0)], [0.9, 0.75], sides=6, rng=rng)
    tube(tim, [at(g0 - 4.4, WALL_D, h + 16.2), at(g1 + 4.4, WALL_D, h + 16.2)], [0.6, 0.6], sides=6, rng=rng)
    tube(tim, [at(g0 - 2.6, WALL_D, h + 13.4), at(g1 + 2.6, WALL_D, h + 13.4)], [0.4, 0.4], sides=5, rng=rng)
    for t0, t1, drop, key in ((g0, g0 + 7, 4.2, "cloth_coral"), (g0 + 7, g1 - 7, 5.4, "cloth_teal"), (g1 - 7, g1, 4.2, "cloth_coral")):
        cl = cloth("TrainWall", key)
        p0, p1 = at(t0 + 0.3, WALL_D, h + 13.2), at(t1 - 0.3, WALL_D, h + 13.2)
        cl.faces.new([cl.verts.new(v) for v in (p0, p1, p1 + Vector((0, 0, -drop)), (p0 + p1) / 2 + Vector((0, 0, -drop - 1.2)), p0 + Vector((0, 0, -drop)))])
    for u in (g0 + 3, 0, g1 - 3):
        hang(at(u, WALL_D + 0.8, h + 13.0))


def mat(u0, u1, d0, d1, key_border, key_canvas, name):
    plain_box(cloth("Mats", key_border), u0, u1, d0, d1, TR_H - 0.2, TR_H + 0.06)
    plain_box(bag("Mats", name + "Canvas", key_canvas), u0 + 1.6, u1 - 1.6, d0 + 1.6, d1 - 1.6, TR_H - 0.2, TR_H + 0.1)


def strike_post(u, d, rng, tall=6.2):
    tube(bag("Training", "Timber", "bark_timber"), [at(u, d, TR_H - 0.2), at(u, d, TR_H + tall)], [0.75, 0.7], sides=8, rng=rng, jitter=0.03)
    for z in (2.6, 3.9, 5.2):
        tube(bag("Training", "Rope", "cloth_cream"), [at(u, d, TR_H + z - 0.42), at(u, d, TR_H + z + 0.42)], [0.86, 0.86], sides=8, rng=rng, jitter=0.02)
    cyl_c(u, d, 0.95, TR_H, TR_H + tall)


def sign_board(u, d, rng):
    """A section's sign: two timber posts and a plank facing the arena side (the way you walk in). LobbyService
    puts the soft card with the section's name on its face (Lobby.Training.Sign)."""
    tim = bag("Training", "Timber", "bark_timber")
    half, up, tall = SIGN["Width"] / 2, SIGN["Up"], SIGN["Height"]
    for s in (-1, 1):
        tube(tim, [at(u + s * (half + 0.2), d, TR_H - 0.2), at(u + s * (half + 0.2), d, TR_H + up + tall / 2 + 0.9)], [0.42, 0.34], sides=6, rng=rng)
    crate(tim, u, d + 0.35, TR_H + up - tall / 2 - 0.3, (SIGN["Width"] + 0.6, 0.5, tall + 0.6), rng)
    box_c(u - half - 0.6, u + half + 0.6, d - 0.3, d + 0.7, TR_H, TR_H + up + tall / 2 + 0.9)


def pillar(u, d, top, rng, half=4.5):
    """A stone pillar a dummy stands on: stacked blocks, a trim cap, solid."""
    stone, cap = bag("Training", "Stone", "stone_cream"), bag("Training", "Trim", "stone_trim")
    n = max(1, round(top / 2.6))
    for k in range(n):
        crate(stone, u, d, TR_H - 0.3 + k * (top - 0.5) / n, (half * 2 - 0.5, half * 2 - 0.5, (top - 0.5) / n + 0.3), rng, yaw=rng.uniform(-0.04, 0.04))
    crate(cap, u, d, TR_H + top - 0.6, (half * 2, half * 2, 0.6), rng)
    box_c(u - half, u + half, d - half, d + half, TR_H, TR_H + top)


def zone_border(u0, u1, d0, d1, key, w=1.4):
    """A zone's edge: a flush strip of its colour all round, so the four zones read from the obby above."""
    bm = cloth("Zones", key) if key.startswith("cloth") else bag("Zones", key.split("_")[1].capitalize(), key)
    for a0, a1, b0, b1 in ((u0, u1, d0, d0 + w), (u0, u1, d1 - w, d1), (u0, u0 + w, d0 + w, d1 - w), (u1 - w, u1, d0 + w, d1 - w)):
        plain_box(bm, a0, a1, b0, b1, TR_H - 0.2, TR_H + 0.08)


def x_mark(u, d, h, key="stone_clay", size=4.6):
    clay = bag("Mats", key.split("_")[1].capitalize(), key)
    for ang in (math.pi / 4, -math.pi / 4):
        strip = bmesh.new()
        bmesh.ops.create_cube(strip, size=1.0)
        for v in strip.verts:
            v.co = Vector((v.co.x * size, v.co.y * 0.8, v.co.z * 0.3))
        bmesh.ops.triangulate(strip, faces=strip.faces[:])
        append(clay, strip, T(u, d, h - 0.06, ang))


def training():
    """The training grounds (owner, 2026-11-20, with a sketch: FOUR distinct areas in a 2 x 2 grid). The zones sit
    in the corners of a walkway cross (the spine X -9..9, the bar Back 222..240), from training_sections.json:
    front left the DUMMY ROW (five dummies, hit toward the outer wall over lines every 10 studs), front right the
    CLASH DUMMY (it swings on a beat at whoever stands on the X), back left the 1V1 BOT ARENA (a raised round
    arena, ring-outs count), back right the RECOVERY CLIFF (the lobby's right edge is open sky; three pads throw
    you off). The obby runs over the cross. The leaderboards stay on the right-hand wall of the clash zone."""
    rng = random.Random(89)
    h = TR_H
    tim = bag("Training", "Timber", "bark_timber")
    sec = {s["Key"]: s for s in SECTIONS["Sections"]}
    for s in SECTIONS["Sections"]:
        if SIGN.get("Enabled"):  # owner, 2026-11-19: "remove the signs"
            sign_board(s["Sign"]["X"], s["Sign"]["Back"], rng)
        key = {"Row": "cloth_coral", "Clash": "cloth_gold", "Arena": "cloth_teal", "Cliff": "cloth_mint"}[s["Key"]]
        zone_border(s["X0"], s["X1"], s["Back0"], s["Back1"], key)

    # the walkway cross: pale paving strips along the spine and the bar, edged in timber
    walk = bag("Walk", "Stone", "stone_pave")
    flags2(walk, -8.6, 8.6, WALL_D + 1.4, D - 0.4, h + 0.08, rng, row=8.0, wmin=5.0, wmax=8.6)
    flags2(walk, -HX + 0.5, -8.6, 222.4, 239.6, h + 0.08, rng, row=8.6, wmin=8.0, wmax=13.0)
    flags2(walk, 8.6, HX - 0.5, 222.4, 239.6, h + 0.08, rng, row=8.6, wmin=8.0, wmax=13.0)

    # DUMMY ROW: a round clay mark under each dummy, a cream line where you stand, and a line every 10 studs
    # toward the outer wall (LobbyService writes the numbers)
    s = sec["Row"]
    for dm in s["Dummies"]:
        ring_tiles(lambda i: bag("Mats", "Clay", "stone_clay"), dm["X"], dm["Back"], 2.6, 3.5, 10, h + 0.14)
    stand = s["Dummies"][0]["X"] + 7.0
    plain_box(cloth("Mats", "cloth_cream"), stand - 0.5, stand + 0.5, s["Back0"] + 8, s["Back1"] - 8, h - 0.1, h + 0.14)
    m = s["Marks"]
    for k in range(1, m["Count"] + 1):
        x = m["FromX"] + m["Dir"] * m["Step"] * k
        key = "stone_clay" if k % 2 else "stone_teal"
        plain_box(bag("Mats", key.split("_")[1].capitalize(), key), x - 0.4, x + 0.4, s["Back0"] + 4, s["Back1"] - 4, h - 0.1, h + 0.13)

    # CLASH DUMMY: a gold-and-cream round mat under it, a clay ring at its reach, the X you stand on
    s = sec["Clash"]
    dm = s["Dummies"][0]
    ring_tiles(lambda i: cloth("Mats", "cloth_gold") if i % 2 == 0 else bag("Mats", "Canvas", "cloth_cream"), dm["X"], dm["Back"], 1.2, dm["Radius"] - 1.2, 16, h + 0.1)
    ring_tiles(lambda i: bag("Mats", "Clay", "stone_clay"), dm["X"], dm["Back"], dm["Radius"] - 1.0, dm["Radius"], 28, h + 0.14)
    x_mark(s["Mark"]["X"], s["Mark"]["Back"], h + 0.2)
    for a in range(4):  # four gold banners round the circle: the zone's landmark from the walkway
        ang = a * math.pi / 2 + math.pi / 4
        banner(dm["X"] + math.cos(ang) * (dm["Radius"] + 4), dm["Back"] + math.sin(ang) * (dm["Radius"] + 4), h, "cloth_gold", rng, tall=11.0, face=math.pi / 2, solid=True)

    # 1V1 BOT ARENA: a raised round stone arena, blue-and-cream rings on top, a clay edge line, steps at the front
    s = sec["Arena"]
    ring = s["Ring"]
    cu, cd, r, top = ring["X"], ring["Back"], ring["Radius"], h + ring["Raise"]
    stone, trim = bag("Arena", "Stone", "stone_cream"), bag("Arena", "Trim", "stone_trim")
    n = 22
    for i in range(n):  # the wall: two courses of cut blocks round the rim
        a = (i + 0.5) / n * math.tau
        for row in range(2):
            append(stone, brick((r * math.tau / n + 0.3, 2.4, ring["Raise"] / 2 + 0.25), rng),
                   T(cu + math.cos(a + row * 0.07) * (r - 1.1), cd + math.sin(a + row * 0.07) * (r - 1.1), h - 0.3 + row * ring["Raise"] / 2, math.atan2(-math.cos(a), -math.sin(a))))
    tube(stone, [at(cu, cd, h - 0.3), at(cu, cd, top - 0.2)], [r - 1.6, r - 1.6], sides=22, jitter=0.0)
    ring_tiles(lambda i: trim, cu, cd, 0.4, 4.0, 8, top)
    ring_tiles(lambda i: cloth("Arena", "cloth_teal") if i % 2 == 0 else bag("Arena", "Canvas", "cloth_cream"), cu, cd, 4.2, r - 3.2, 18, top, 0.17)
    ring_tiles(lambda i: bag("Arena", "Clay", "stone_clay"), cu, cd, r - 3.0, r - 0.2, 32, top + 0.04)
    cyl_c(cu, cd, r, h, top)
    st = ring["Steps"]
    for k in range(4):  # four steps up the front, from the bar walkway
        crate(trim, (st["X0"] + st["X1"]) / 2, st["Back0"] + (k + 0.5) * (st["Back1"] - st["Back0"]) / 4, h - 0.3, (st["X1"] - st["X0"], (st["Back1"] - st["Back0"]) / 4 + 0.1, (k + 1) * ring["Raise"] / 4 + 0.3), rng)
    COLLISION.append({"kind": "wedge", "u0": st["X0"], "u1": st["X1"], "d0": st["Back0"], "d1": st["Back1"], "h0": h, "h1": top})
    for a in (0.6, 2.55, 3.7, 5.65):  # four blue banners round it on the sand
        banner(cu + math.cos(a) * (r + 4.5), cd + math.sin(a) * (r + 4.5), h, "cloth_teal", rng, tall=12.0, face=a + math.pi / 2, solid=True)

    # RECOVERY CLIFF: the lobby's right edge is left open (edges() leaves out the parapet there); a clay lip on the
    # edge, a green-and-cream ring at each pad (LobbyService writes LIGHT, MEDIUM, HEAVY), a mark where you land
    # when you miss
    s = sec["Cliff"]
    e = s["Edge"]
    plain_box(bag("Mats", "Clay", "stone_clay"), HX - 1.2, HX + 0.1, e["Back0"], e["Back1"], h - 0.1, h + 0.14)
    for pad in s["Pads"]:
        ring_tiles(lambda i: cloth("Mats", "cloth_mint") if i % 2 == 0 else bag("Mats", "Canvas", "cloth_cream"), pad["X"], pad["Back"], 0.4, pad["Radius"], 10, h + 0.12)
        plain_box(cloth("Mats", "cloth_mint"), pad["X"] + pad["Radius"] + 0.6, HX - 1.6, pad["Back"] - 0.35, pad["Back"] + 0.35, h - 0.1, h + 0.12)
    ret = e["Return"]
    ring_tiles(lambda i: bag("Mats", "Clay", "stone_clay"), ret["X"], ret["Back"], 1.8, 2.6, 12, h + 0.14)
    for d in (250, 318):  # two green banners at the cliff's ends, set back from the edge
        banner(HX - 6.0, d, h, "cloth_mint", rng, tall=13.0, face=math.pi, solid=True)

    # the leaderboards: three timber boards on the right-hand wall, each under its own little roof. LobbyService
    # puts the lists on their faces (GameConfig.Lobby.Boards).
    for d, title, stat in ((150, "MOST KILLS", "Kills"), (171, "MOST WINS", "Wins"), (192, "MOST PLAYTIME", "Playtime")):
        for sd in (-1, 1):
            tube(tim, [at(72.2, d + sd * 6.6, h - 0.2), at(72.2, d + sd * 6.6, h + 12.2)], [0.6, 0.5], sides=6, rng=rng)
        crate(tim, 72.3, d, h + 1.6, (0.9, 12.6, 9.4), rng)
        for sd in (-1, 1):  # a two-plank roof over the board
            b = bmesh.new()
            bmesh.ops.create_cube(b, size=1.0)
            for v in b.verts:
                v.co = Vector((v.co.x * 3.4, v.co.y * 7.6, v.co.z * 0.35))
            bmesh.ops.triangulate(b, faces=b.faces[:])
            append(tim, b, Matrix.Translation(at(71.6, d + sd * 3.5, h + 12.6)) @ Matrix.Rotation(sd * 0.2, 4, "X"))
        box_c(71.4, 73.2, d - 7.2, d + 7.2, h, h + 12.4)
        BOARDS.append({"title": title, "stat": stat, "u": 71.8, "d": d, "h": h + 6.3, "fx": -1, "fz": 0})
        hang(at(71.0, d, h + 12.2), drop=0.5, s=0.8)

    # lamps down the walkway cross
    for u, d, way in ((-11.5, 150, (1, 0)), (11.5, 196, (-1, 0)), (-11.5, 262, (1, 0)), (11.5, 300, (-1, 0)), (-30, 220.5, (0, -1)), (30, 241.5, (0, 1))):
        LAMPS.append((u, d, h, way, 8.5))


# --- build -----------------------------------------------------------------------------------------------------------
def main():
    C.reset()
    C.sky_and_sun(250, 16)
    os.makedirs(os.path.join(OUT, "textures"), exist_ok=True)
    for fn in (ground, stairs, edges, crag, great_tree, shops, obby_course, square, training_wall, training, lamps):
        fn()
        print("BUILT", fn.__name__, flush=True)
    for (element, part, key), bm in BAGS.items():
        if key.startswith("cloth") or key == "paper":
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        emit(element, part, key, bm)
    json.dump(OBBY, open(os.path.join(OUT, "obby.json"), "w", encoding="utf-8"), indent=1)
    json.dump(STATIONS, open(os.path.join(OUT, "stations.json"), "w", encoding="utf-8"), indent=1)
    json.dump(BOARDS, open(os.path.join(OUT, "boards.json"), "w", encoding="utf-8"), indent=1)
    json.dump(PETALS, open(os.path.join(OUT, "petals.json"), "w", encoding="utf-8"), indent=1)
    scene = bpy.context.scene
    cams = {
        "Over": C.camera("Over", at(190, -150, 190), at(0, 110, 0), lens=30),
        "Top": C.camera("Top", at(0, 300, 640), at(0, 299.99, 0), lens=36),
        "Spawn": C.camera("Spawn", at(0, SPAWN_D + 14, SQ_H + 7), at(0, -80, -6), lens=20),
        "Square": C.camera("Square", at(26, 34, 16), at(-30, 100, 10), lens=18),
        "Market": C.camera("Market", at(4, 62, 9), at(60, 74, 9), lens=18),
        "Obby": C.camera("Obby", at(0, 40, 26), at(0, 110, 12), lens=16),
        "Training": C.camera("Training", at(0, 114, 30), at(0, 190, 6), lens=16),
        "BackYard": C.camera("BackYard", at(0, 196, 46), at(0, 270, 6), lens=16),
        "TrainTop": C.camera("TrainTop", at(0, 229, 300), at(0, 228.99, 0), lens=30),
        "Sky": C.camera("Sky", at(-30, 296, 52), at(0, 450, 24), lens=18),
        "BellRock": C.camera("BellRock", at(-58, 512, 62), at(0, 562, 38), lens=22),
        "FromSquare": C.camera("FromSquare", at(0, SPAWN_D - 6, SQ_H + 6), at(0, 560, 40), lens=26),
        "Cliff": C.camera("Cliff", at(24, 232, 34), at(110, 300, -12), lens=18),
        "Arena1v1": C.camera("Arena1v1", at(-8, 236, 30), at(-41, 284, 8), lens=20),
        "Arena": C.camera("Arena", at(-200, -260, 10), at(0, 90, 0), lens=30),
    }
    cams["Top"].data.type = "ORTHO"
    cams["Top"].data.ortho_scale = 660
    if DRY:
        total = 0
        for asset, key, obj in REGISTRY:
            tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
            total += tris
            base = PAL[key][0]
            obj.color = (float(base[0]) ** (1 / 2.2), float(base[1]) ** (1 / 2.2), float(base[2]) ** (1 / 2.2), 1.0)
            print(f"MESH {obj.name}: {tris} tris{'  OVER 20000' if tris > 20000 else ''}", flush=True)
        print("TRIANGLES", total, "MESHES", len(REGISTRY), "COLLIDERS", len(COLLISION), "KIT PIECES", len(PLACE), "OBBY", len(OBBY), flush=True)
        json.dump(COLLISION, open(os.path.join(OUT, "collision.json"), "w", encoding="utf-8"), indent=1)
        json.dump(PLACE, open(os.path.join(OUT, "placements.json"), "w", encoding="utf-8"), indent=1)
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "OBJECT"
        scene.display.shading.show_cavity = True
        scene.display.shading.show_shadows = True
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "village_dry.blend"))
        C.render_all(OUT, "dry", cams, resolution=(1280, 720))
        return
    import addon_utils

    addon_utils.enable("cycles", default_set=True)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.bake.target = "IMAGE_TEXTURES"
    if scene.world:
        scene.world.light_settings.distance = 3.0
    for asset, key, obj in REGISTRY:
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        assert tris <= 20000, f"{obj.name} has {tris} triangles (Roblox takes 20,000 a mesh)"
        px = 128 if K["FAST"] else (256 if tris < 600 else (512 if tris < 4000 else 1024))
        K["bake_paint"](obj, px)
        print(f"PAINTED {obj.name}: {tris} tris, {px}px", flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "village.blend"))
    if not NO_RENDER:
        scene.cycles.samples = 24
        C.render_all(OUT, "village", cams, resolution=(1280, 720))
    export()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "village.blend"))
    print("SAVED", os.path.join(OUT, "village.blend"), flush=True)


main()
