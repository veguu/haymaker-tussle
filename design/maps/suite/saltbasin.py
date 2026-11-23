"""Map 4 of the suite, "The Salt Basin" (Tide Terrace, from Saltcrest). DESIGN BLOCKOUT 2026-11-21: NOT APPROVED.

    blender -b --factory-startup -P saltbasin.py -- <out folder> --dry --no-render

IDEA (five words): a dried sea in the sky. A shallow sea once lay in the sky and drained away, leaving a basin of
salt that still weeps water from its sides. The owner's rules beat the brief's "ocean": no sea below, ever; the
water is IN the sky, in lagoons on islands and in waterfalls falling off every edge into the open sky below.
  - Floor: a dried salt pan of LILAC salt in mid tones (the grey-white first try read as snow and was brighter than
    the fighters) with soft ripple marks, sandy tide stains, paler salt bloom; the last 55 studs turn sand, then pale
    aqua, then turquoise at the lip, so the floor's colour tells you how near the edge you are. No lines, no cells
    (real salt-flat polygons would read as cobbles).
  - Edge: the crust rolls over as a turquoise-stained lip, then thick lilac-white salt with stubby salt stalactites,
    then a salt body tapering to a point, studded with big turquoise crystal clusters pointing down and out (inside
    the footprint), and four terracotta spouts whose waterfalls curve out and pour off into the sky below.
  - Background (its own layout: shell north-east, pans north-west, lagoons east and west too): the salt pans island (a grid of evaporation pools in aqua, pink, cream and turquoise between low
    terracotta walls, white salt heaps, salt-rakers living in upturned driftwood boats), lagoon islands spilling
    waterfalls, a driftwood island (bleached arches, a beached boat, net posts), two low salt spits off the
    arena's sides, three far salt islands with waterfalls.
  - LANDMARK: the Great Shell, a spiral seashell tower about 425 studs tall and 330 across, cream with a coral
    stripe up its spiral and knobs on its shoulders, a fat pink lip round its mouth, which faces the arena; water
    runs from the mouth across the island and falls off its front edge.
  - Feel: the wet edge. The turquoise lip glints and shimmers as you near it (one texture scrolled on the rim:
    almost no per-frame cost), and waterfalls pour off the arena's spouts and every island (Beams scrolling their
    texture: no script cost), seen when you look out over the edge or get knocked off. No spray over the lip: it
    would blur the ring-out edge.
"""
import os

_d = os.path.dirname(os.path.abspath(__file__))
for _f in ("base.py", "sketch_kit.py"):
    _p = os.path.join(_d, _f)
    exec(compile(open(_p, encoding="utf-8").read(), _p, "exec"))

NAME = "Salt"
PAL.update(
    {
        "stone_salt": (srgb(214, 202, 212), srgb(236, 226, 234), srgb(160, 150, 162)),  # lilac salt, not white ice
        "stone_saltgrey": (srgb(186, 176, 188), srgb(212, 202, 214), srgb(132, 124, 138)),
        "stone_aqua": (srgb(150, 214, 206), srgb(190, 236, 228), srgb(92, 150, 150)),
        "stone_crystal": (srgb(84, 192, 190), srgb(140, 226, 220), srgb(44, 128, 136)),
        "stone_terra": (srgb(206, 112, 82), srgb(232, 152, 116), srgb(136, 70, 60)),
        "stone_pinkpan": (srgb(238, 192, 184), srgb(250, 220, 212), srgb(170, 132, 132)),
        "stone_creampan": (srgb(242, 228, 200), srgb(254, 244, 224), srgb(176, 164, 150)),
        "water_lagoon": (srgb(70, 182, 196), srgb(124, 214, 222), srgb(40, 120, 144)),
        "water_fall": (srgb(196, 236, 236), srgb(230, 250, 250), srgb(140, 186, 196)),
        "cloth_mist": (srgb(236, 244, 246), srgb(250, 252, 252), srgb(190, 200, 210)),
        "bark_drift": (srgb(200, 188, 168), srgb(228, 218, 200), srgb(138, 128, 118)),
        "bark_driftdk": (srgb(150, 138, 124), srgb(186, 176, 160), srgb(100, 92, 86)),
        "shell_cream": (srgb(246, 232, 210), srgb(255, 246, 230), srgb(182, 166, 154)),
        "shell_coral": (srgb(230, 134, 106), srgb(246, 172, 144), srgb(156, 84, 74)),
        "shell_pink": (srgb(244, 184, 172), srgb(252, 214, 204), srgb(176, 120, 116)),
        "cloth_rope": (srgb(214, 186, 132), srgb(236, 214, 170), srgb(150, 124, 90)),
    }
)

# --- the fighting surface: a dried salt pan that turns turquoise at its edge -------------------------------------------
# mid tones: the fighters must stay the brightest thing on screen
# lilac salt in mid tones (review 2026-11-21: the grey-white first floor measured 189 of 255 and read as snow)
SALT = {"salt": (142, 131, 146), "sand": (146, 133, 122), "bloom": (162, 155, 167), "grey": (131, 128, 137), "aqua": (140, 194, 186), "turq": (78, 174, 174), "deep": (52, 140, 152)}


def salt(X, Z):
    c = {k: P.rgb(*v) for k, v in SALT.items()}
    col = P.fill(X.shape, c["salt"])
    st = P.fbm2(X / 110.0 + 1.0, Z / 110.0 - 2.0, 41, 3)
    col = P.mix(col, c["sand"], 0.55 * P.smoothstep(0.5, 0.75, st))
    gr = P.fbm2(X / 80.0 - 3.0, Z / 80.0 + 1.0, 43, 3)
    col = P.mix(col, c["grey"], 0.35 * P.smoothstep(0.55, 0.8, gr))
    # ripple marks: wavy crests about 7 studs apart, a gentle slope up and a steep one down (shading only)
    warp = (P.fbm2(X / 30.0, Z / 30.0, 45, 2) - 0.5) * 14.0
    ph = (X * 0.55 + Z * 0.83 + warp) / 7.0
    fr = ph - np.floor(ph)
    rip = np.where(fr < 0.75, fr / 0.75, (1.0 - fr) / 0.25)
    col = col * (0.94 + 0.08 * rip)[..., None]
    bl = P.fbm2(X / 26.0 + 7.0, Z / 26.0, 47, 3)
    col = P.mix(col, c["bloom"], 0.45 * P.smoothstep(0.6, 0.78, bl))
    col = col * (1.0 + 0.05 * (P.fbm2(X / 9.0, Z / 9.0, 51, 2) - 0.5))[..., None]
    # the tide bands at the edge: sand, pale aqua, turquoise at the lip, each boundary wobbling
    d = edge_dist(X, Z) + (P.fbm2(X / 35.0, Z / 35.0, 49, 2) - 0.5) * 10.0
    col = P.mix(col, c["sand"], P.smoothstep(56.0, 46.0, d) * 0.6)
    col = P.mix(col, c["aqua"], P.smoothstep(40.0, 32.0, d))
    col = P.mix(col, c["turq"], P.smoothstep(20.0, 13.0, d))
    col = P.mix(col, c["deep"], P.smoothstep(3.5, 0.5, d) * 0.55)
    col = col * (0.95 + 0.06 * rip)[..., None]
    return np.clip(col, 0.0, 1.0)


def surface():
    floor_tiles(NAME, "Floor", "Salt", "stone_salt", 0.0, salt, nx=3, nz=2)


# --- the edge: a crust lip, salt icicles, crystals, waterfalls from terracotta spouts ---------------------------------
def crystal_cluster(element, m, rng, size, region="", n=None):
    """Hexagonal crystal prisms with pointed tips fanning out from one root (local +z is 'out')."""
    for k in range(n or rng.randint(4, 6)):
        r = size * rng.uniform(0.16, 0.26)
        L = size * rng.uniform(0.6, 1.0)
        b = ring_prism([(r, -r), (r, L), (r * 0.1, L + r * 1.6)], 6)
        tilt = Rx(rng.uniform(-0.55, 0.55)) @ Ry(rng.uniform(-0.55, 0.55))
        place(element, "stone_crystal", b, m @ tilt @ Rz(rng.uniform(0, 1.0)), region=region)


def waterfall(p0, out_dir, drop, width, region, element="Falls", segs=8, arc=7):
    """A short falling CURTAIN of water from Blender point p0: curved in section (so it never shows edge-on as a
    thin line), curving out along `out_dir` as it falls `drop` studs, widening fast, ending in a mist puff. (Long
    flat sheets read as poles and stilts; in the game these are camera-facing Beams that fade out.)"""
    out_dir = Vector(out_dir).normalized()
    side = Vector((-out_dir.y, out_dir.x, 0.0))
    bm = bmesh.new()
    rows = []
    for k in range(segs + 1):
        t = k / segs
        c = Vector(p0) + out_dir * (40.0 * math.sqrt(t) + 2.0) + Vector((0, 0, -drop * t))
        w = width * (1.0 + 2.6 * t)
        row = []
        for q in range(arc + 1):
            a = math.pi * (q / arc - 0.5) * 0.8
            row.append(bm.verts.new(c + side * math.sin(a) * w / 2 + out_dir * math.cos(a) * w * 0.25))
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        for q in range(arc):
            bm.faces.new((r0[q], r0[q + 1], r1[q + 1], r1[q]))
    place(element, "water_fall", bm, region=region)
    end = Vector(p0) + out_dir * 42.0 + Vector((0, 0, -drop))
    mist = lump(width * 1.6, random.Random(int(abs(p0.x) + abs(p0.y))), squash=0.6, jitter=0.2, subdiv=1, flat_bottom=0.6)
    place(element, "cloth_mist", mist, Matrix.Translation(end), region=region)


def edge():
    rng = random.Random(41)
    course("Lip", "Aqua", "stone_aqua", -0.5, 3.0, -3.5, -0.04, rng, 4.0, 7.0, gap=0.0, outer_chamfer=1.4, inner_chamfer=0.1)
    course("Crust", "Salt", "stone_salt", 0.4, 10.0, -14.0, -3.5, rng, 6.0, 11.0, gap=0.0, top_chamfer=0.5, bottom_jitter=3.0)
    course("Crust", "Saltgrey", "stone_saltgrey", 7.0, 20.0, -32.0, -14.0, rng, 8.0, 14.0, gap=0.0, top_chamfer=0.5, bottom_jitter=5.0)
    place("Core", "stone_saltgrey", oval_slab(10.0, 70.0, -14.0, -96.0, n=96))
    place("Core", "stone_salt", oval_slab(70.0, 168.0, -96.0, -210.0, n=10))  # few sides: a faceted crystal, not a smooth cone
    for k in range(36):  # stubby salt stalactites under the crust
        x, z, nx, nz = oval(t_at((k + rng.uniform(-0.3, 0.3)) / 64 * PERIM), rng.uniform(3.0, 9.0))
        L = rng.uniform(5.0, 10.0)
        r = L * rng.uniform(0.3, 0.4)
        place("Icicles", "stone_salt", ring_prism([(r, 0.0), (r * 0.6, -L * 0.5), (0.05, -L)], 5), at(x, z, -14.0 + rng.uniform(-1, 2)))
    for k in range(18):  # crystal clusters on the underside, pointing down and out, inside the footprint
        t = (k + rng.uniform(-0.25, 0.25)) / 18 * math.tau
        inset = rng.uniform(34.0, 70.0)
        x, z, nx, nz = oval(t, inset)
        h = -34.0 - (inset - 30.0) * 1.1 + rng.uniform(-6, 6)
        yaw = facing(x, z, x + nx, z + nz)
        m = at(x, z, h, yaw) @ Rx(2.3)  # local +z now points out (-y) and down
        crystal_cluster("Crystals", m, rng, rng.uniform(26.0, 40.0))
    for k in range(5):
        x, z, h, s = rng.uniform(-60, 60), rng.uniform(-50, 50), rng.uniform(-200, -150), rng.uniform(30, 44)
        crystal_cluster("Crystals", at(x, z, h) @ Rx(math.pi), rng, s)
    for k, t in enumerate((0.9, 2.45, 3.95, 5.5)):  # four terracotta spouts and their waterfalls
        x, z, nx, nz = oval(t, 1.2)
        yaw = facing(x, z, x + nx, z + nz)
        m = at(x, z, -9.0, yaw)
        place("Spouts", "stone_terra", bbox((9.0, 5.0, 6.0), 0.6), m @ T(0, 1.4, 0.0))
        place("Spouts", "water_lagoon", bbox((6.0, 3.0, 2.0), 0.3), m @ T(0, 1.0, 3.6))
        waterfall(m @ Vector((0, -1.4, 4.4)), Vector((nx, -nz, 0.0)), rng.uniform(140, 170), 12.0, f"Fall{k}")


# --- islands: salt crust tops, crystal undersides ---------------------------------------------------------------------
def salt_isle(name, cx, cz, rx, rz, top, hill=0.0, flat=None, depth=None, rng=None, falls=0):
    i = isle(name, cx, cz, rx, rz, top, hill=hill, flat=flat)
    isle_top(i, "stone_salt", "stone_aqua", side=4.0)
    rng = rng or random.Random(i["s"])
    depth = depth or min(rx, rz) * 1.2
    place("Island", "stone_salt", ellipse_slab(rx * 0.98, rz * 0.98, top - 4.0, top - 16.0, n=28, k_bot=0.92, wob=lambda a: outline(i, a)), at(cx, cz, 0.0), region=name)
    place("Island", "stone_saltgrey", ellipse_slab(rx * 0.9, rz * 0.9, top - 16.0, top - 16.0 - depth * 0.5, n=9, k_bot=0.55), at(cx, cz, 0.0), region=name)
    place("Island", "stone_salt", ellipse_slab(rx * 0.5, rz * 0.5, top - 16.0 - depth * 0.5, top - 16.0 - depth, n=7, k_bot=0.08, shift=(depth * 0.1, 0.0)), at(cx, cz, 0.0), region=name)
    for k in range(max(4, int((rx + rz) / 40))):
        a = (k + rng.uniform(-0.3, 0.3)) / max(4, int((rx + rz) / 40)) * math.tau
        x, z = cx + math.cos(a) * rx * 0.7, cz + math.sin(a) * rz * 0.7
        m = at(x, z, top - 16.0 - depth * 0.3, facing(x, z, cx + (x - cx) * 2, cz + (z - cz) * 2)) @ Rx(2.3)
        crystal_cluster("Island", m, rng, min(rx, rz) * 0.2, region=name, n=3)
    for k in range(int((rx + rz) / 30)):
        a = rng.uniform(0, math.tau)
        x, z = cx + math.cos(a) * rx * 0.97, cz + math.sin(a) * rz * 0.97
        L = rng.uniform(4.0, 8.0)
        place("Island", "stone_salt", ring_prism([(L * 0.25, 0.0), (0.05, -L)], 5), at(x, z, top - 15.0), region=name)
    for k in range(falls):
        a = -math.pi / 2 + (k - (falls - 1) / 2) * 0.5 + 0.4  # off the far (north) side, a little east
        x, z = cx + math.cos(a) * rx * 0.98, cz + math.sin(a) * rz * 0.98
        waterfall(W(x, z, top - 1.0), W(math.cos(a), math.sin(a), 0.0), rng.uniform(110, 150), 14.0, name + f"F{k}")
    return i


def lagoon(i, f=0.55):
    """A turquoise lagoon pool set into an island's top, with a terracotta rim."""
    cx, cz = i["cx"], i["cz"]
    place("Lagoon", "water_lagoon", ellipse_slab(i["rx"] * f, i["rz"] * f, i["top"] + 1.4, i["top"] - 2.0, n=28), at(cx, cz, 0.0), region=i["name"])
    place("Lagoon", "stone_terra", annulus(1.0, 1.0 + 4.0 / (i["rx"] * f), 0.0, 1.0, 28), at(cx, cz, i["top"] + 0.9) @ Matrix.Diagonal((i["rx"] * f, i["rz"] * f, 2.2, 1.0)), region=i["name"])


def boat_house(x, z, L, rng, region, yaw=None):
    """A salt-raker's house: an upturned driftwood boat, keel up, a terracotta door and stovepipe, round windows."""
    y = H(x, z)
    yaw = facing(x, z, 0.0, 0.0) + math.pi / 2 if yaw is None else yaw
    m = at(x, z, y - 0.5, yaw)
    Wd, Hh = L * 0.34, L * 0.36
    n, segs = 12, 8
    bm = bmesh.new()
    rings = []
    for k in range(n + 1):
        s = -L / 2 + L * k / n
        f = max(0.06, (1.0 - (2.0 * s / L) ** 2)) ** 0.55
        ring = [bm.verts.new((s, math.cos(a) * Wd * f, math.sin(a) * Hh * (0.55 + 0.45 * f))) for a in [math.pi * q / segs for q in range(segs + 1)]]
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for q in range(segs):
            bm.faces.new((r0[q], r1[q], r1[q + 1], r0[q + 1]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    place("Boats", "bark_drift", bm, m, region)
    place("Boats", "bark_driftdk", rod(m @ Vector((-L / 2 - 1.0, 0, Hh * 0.62)), m @ Vector((L / 2 + 1.0, 0, Hh * 0.62)), 1.0, 5), region=region)
    place("Boats", "stone_terra", bbox((1.2, Wd * 0.5, Hh * 0.55), 0.3), m @ T(-L / 2 + L * 0.06, 0, 0.0), region)
    place("Boats", "stone_terra", ring_prism([(1.3, 0.0), (1.3, 7.0), (2.0, 8.5)], 6), m @ T(L * 0.15, Wd * 0.3, Hh * 0.75), region)
    for s in (-0.2, 0.15):
        place("Boats", "water_lagoon", ring_prism([(1.6, -0.4), (1.6, 0.4)], 8), m @ T(L * s, -Wd * 0.62, Hh * 0.45) @ Rx(math.pi / 2), region)


def salt_heap(x, z, r, region):
    y = H(x, z)
    place("Pans", "stone_salt", ring_prism([(r, -0.5), (r * 0.82, r * 0.35), (r * 0.08, r * 1.05)], 9), at(x, z, y), region)


def drift_arch(x, z, span, rng, region, yaw=0.0):
    y = H(x, z)
    pts = []
    for k in range(9):
        a = math.pi * k / 8
        pts.append((math.cos(a) * span / 2 + rng.uniform(-1, 1), rng.uniform(-1, 1), math.sin(a) * span * 0.55 + rng.uniform(-1, 1)))
    b = bmesh.new()
    tube(b, pts, [span * 0.06 * (1.2 - 0.4 * math.sin(math.pi * k / 8)) for k in range(9)], sides=6, rng=rng)
    place("Drift", "bark_drift", b, at(x, z, y - 2.0, yaw), region)


def conch(x, z, face_x, face_z):
    """THE landmark: a spiral seashell standing on its base whorl like a tower, about 425 studs tall and 330 wide,
    cream with a coral stripe riding its spiral, knobs on its shoulders, a pink flared lip; its mouth faces the
    arena and a waterfall pours out of it over the island's front edge. (Lying on its side, the first try read as
    a row of beads and was too low for a landmark.)"""
    y = H(x, z)
    yaw = facing(x, z, face_x, face_z)
    m = at(x, z, y - 6.0, yaw)
    # whorls that overlap (the tube is as fat as its spiral is wide), so the spire is one solid cone; one continuous
    # tube, so no seams; starting at local +x heading +y, so the mouth opens toward -y, the arena
    turns, N = 6.0, 240
    pts, radii = [], []
    for k in range(N + 1):
        t = k / N * turns
        g = 0.72 ** t
        a = t * math.tau
        pts.append(Vector((90.0 * g * math.cos(a), 90.0 * g * math.sin(a), 66.0 + 380.0 * (1.0 - g))))
        radii.append(75.0 * g + 1.0)
    b = bmesh.new()
    tube(b, pts, radii, sides=16)
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    place("Shell", "shell_cream", b, m, "Shell")
    up = Vector((0, 0, 1))
    stripe = [p + Vector((p.x, p.y, 0.0)).normalized() * r * 0.8 + up * r * 0.5 for p, r in zip(pts, radii)]
    b = bmesh.new()
    tube(b, stripe, [r * 0.24 + 0.3 for r in radii], sides=8)
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    place("Shell", "shell_coral", b, m, "Shell")
    for k in range(10, int(N / turns * 3.0), 9):  # knobs on the shoulders of the first three whorls
        radial = Vector((pts[k].x, pts[k].y, 0.0)).normalized()
        p = pts[k] + radial * radii[k] * 0.75 + up * radii[k] * 0.62
        knob = ring_prism([(radii[k] * 0.2, 0.0), (0.5, radii[k] * 0.42)], 6)
        rot_k = up.rotation_difference((radial + up * 1.2).normalized()).to_matrix().to_4x4()
        place("Shell", "shell_cream", knob, m @ Matrix.Translation(p) @ rot_k, "Shell")
    d = (pts[1] - pts[0]).normalized()
    rot = up.rotation_difference(d).to_matrix().to_4x4()
    radial0 = Vector((pts[0].x, pts[0].y, 0.0)).normalized()
    to_d = Vector((0, 1, 0)).rotation_difference(d).to_matrix().to_4x4()
    lip = hoop(radii[0] * 1.02, 11.0, sides=8, n=28)  # a fat pink lip round the mouth (a flat disc read as a ball)
    place("Shell", "shell_pink", lip, m @ Matrix.Translation(pts[0] - d * 2.0) @ to_d, "Shell")
    flare = hoop(radii[0] * 0.75, 9.0, sides=6, n=16, arc=math.pi, start=-math.pi / 2)
    place("Shell", "shell_pink", flare, m @ Matrix.Translation(pts[0] - d * 2.0 + radial0 * radii[0] * 0.55) @ to_d, "Shell")
    inner = ring_prism([(radii[0] * 0.9, -1.0), (radii[0] * 0.9, 1.0)], 16)
    place("Shell", "shell_coral", inner, m @ Matrix.Translation(pts[0] - d * 3.4) @ rot, "Shell")
    # the water runs from the mouth across the island to its front edge as a stream, then falls
    mouth = m @ (pts[0] - d * 8.0)
    mx, mz = mouth.x, -mouth.y
    i = ISLES["Shell"]
    ux, uz = -mx / math.hypot(mx, mz), -mz / math.hypot(mx, mz)
    ex, ez = mx, mz
    while ((ex - i["cx"]) / i["rx"]) ** 2 + ((ez - i["cz"]) / i["rz"]) ** 2 < 1.0:
        ex, ez = ex + ux * 4.0, ez + uz * 4.0
    sx, sz = -uz * 12.0, ux * 12.0
    bm = bmesh.new()
    vs = [bm.verts.new(W(px, pz, H(px, pz) + 0.8)) for px, pz in ((mx + sx, mz + sz), (ex + sx, ez + sz), (ex - sx, ez - sz), (mx - sx, mz - sz))]
    bm.faces.new(vs)
    place("Falls", "water_lagoon", bm, region="ShellFall")
    waterfall(W(ex, ez, H(ex, ez)), W(ux, uz, 0.0), 200.0, 26.0, "ShellFall")
    DATA["shell"] = {"base": [round(x, 1), round(y, 1), round(z, 1)]}


PANS = (-260.0, -1150.0)
SHELL = (480.0, -1080.0)


def islands():
    """The salt basin's own layout (review 2026-11-21): the shell north-east, the pans north-west, lagoons and
    driftwood east and west too, not only north."""
    salt_isle("Pans", PANS[0], PANS[1], 250.0, 170.0, 20.0, flat=(PANS[0], PANS[1], 260.0, 20.0), depth=170.0, falls=2)
    salt_isle("Shell", SHELL[0], SHELL[1], 230.0, 190.0, 8.0, hill=6.0, depth=170.0)
    salt_isle("LagoonE", 950.0, -620.0, 130.0, 95.0, -10.0, depth=110.0, falls=1)
    salt_isle("LagoonN", -40.0, -1700.0, 180.0, 120.0, 46.0, depth=140.0, falls=2)
    salt_isle("Drift", -820.0, -1250.0, 150.0, 104.0, 22.0, hill=6.0, depth=120.0, falls=1)
    salt_isle("SpitE", 420.0, -580.0, 52.0, 40.0, -100.0, hill=3.0, depth=56.0)
    salt_isle("SpitW", -920.0, -420.0, 56.0, 42.0, -110.0, hill=3.0, depth=56.0)
    salt_isle("DriftW", -1250.0, -600.0, 160.0, 110.0, 0.0, depth=120.0, falls=1)
    salt_isle("LagoonFarE", 1400.0, -1100.0, 180.0, 120.0, 20.0, depth=130.0, falls=2)
    salt_isle("FarNE", 1600.0, -2100.0, 240.0, 150.0, 8.0, depth=150.0, falls=2)
    salt_isle("FarNW", -1700.0, -1900.0, 260.0, 160.0, 16.0, depth=150.0, falls=2)
    salt_isle("FarN", 200.0, -2900.0, 300.0, 180.0, 40.0, depth=160.0, falls=3)
    lagoon(ISLES["LagoonE"])
    lagoon(ISLES["LagoonN"], 0.5)
    lagoon(ISLES["DriftW"], 0.45)
    lagoon(ISLES["LagoonFarE"], 0.5)
    lagoon(ISLES["FarN"], 0.45)


def dressing():
    rng = random.Random(97)
    cx, cz = PANS
    colours = ("water_lagoon", "stone_pinkpan", "stone_creampan", "stone_aqua", "stone_pinkpan", "water_lagoon", "stone_aqua", "stone_creampan", "stone_pinkpan", "stone_aqua", "water_lagoon", "stone_creampan")
    pw, pd = 66.0, 46.0
    for i in range(4):
        for j in range(3):
            x, z = cx + (i - 1.5) * (pw + 4.0), cz + (j - 1.0) * (pd + 4.0) - 10.0
            place("Pans", colours[(i * 3 + j) % len(colours)], bbox((pw, pd, 1.0), 0.2), at(x, z, 20.2), "Pans")
            place("Pans", "stone_terra", bbox((pw + 4.0, 4.0, 2.6), 0.5), at(x, z - pd / 2 - 2.0, 19.6), "Pans")
            place("Pans", "stone_terra", bbox((4.0, pd + 4.0, 2.6), 0.5), at(x - pw / 2 - 2.0, z, 19.6), "Pans")
        place("Pans", "stone_terra", bbox((pw + 4.0, 4.0, 2.6), 0.5), at(cx + (i - 1.5) * (pw + 4.0), cz + 1.5 * (pd + 4.0) - 10.0 - 2.0 + 0.0, 19.6), "Pans")
    place("Pans", "stone_terra", bbox((4.0, 3 * (pd + 4.0), 2.6), 0.5), at(cx + 2 * (pw + 4.0) - 2.0, cz - 10.0, 19.6), "Pans")
    for k in range(12):
        a = rng.uniform(0, math.tau)
        salt_heap(cx + math.cos(a) * rng.uniform(170, 215), cz + math.sin(a) * rng.uniform(115, 145), rng.uniform(6, 10), "Pans")
    for k, (dx, dz) in enumerate(((-190, 90), (-140, 125), (150, 120), (205, 60), (-215, -30))):
        boat_house(cx + dx, cz + dz, rng.uniform(48, 60), rng, "Pans")
    i = ISLES["Shell"]
    conch(i["cx"] - 30.0, i["cz"] - 20.0, 0.0, 0.0)
    for dx, dz in ((-170, 60), (150, 90), (-120, -110)):
        boat_house(i["cx"] + dx, i["cz"] + dz, rng.uniform(46, 56), rng, "Shell")
    for name in ("LagoonE", "LagoonN", "DriftW", "LagoonFarE"):
        i = ISLES[name]
        drift_arch(i["cx"], i["cz"], i["rx"] * 0.9, rng, name, yaw=0.3)
        boat_house(i["cx"] + i["rx"] * 0.75, i["cz"] + i["rz"] * 0.2, 32, rng, name)
        for k in range(5):
            salt_heap(i["cx"] - i["rx"] * 0.7 + k * 9, i["cz"] + i["rz"] * 0.65, 5.0, name)
    i = ISLES["Drift"]
    for k, (dx, dz, sp, yw) in enumerate(((-60, 10, 60, 0.4), (30, -30, 80, -0.3), (70, 40, 48, 1.2))):
        drift_arch(i["cx"] + dx, i["cz"] + dz, sp, rng, "Drift", yaw=yw)
    boat_house(i["cx"] - 10, i["cz"] + 55, 46, rng, "Drift")
    for k in range(6):  # net posts with nets
        x0, z0 = i["cx"] + 40 + k * 12, i["cz"] - 60 + k * 4
        place("Drift", "bark_driftdk", bbox((2.0, 2.0, 18.0), 0.3), at(x0, z0, H(x0, z0) - 1.0), "Drift")
        if k:
            place("Drift", "cloth_rope", bbox((12.0, 0.3, 10.0), 0.1), at(x0 - 6, z0 - 2, H(x0, z0) + 5.0, -0.32), "Drift")
    for name in ("SpitE", "SpitW", "FarNE", "FarNW"):
        i = ISLES[name]
        crystal_cluster("Island", at(i["cx"], i["cz"], H(i["cx"], i["cz"]) - 2.0), rng, min(i["rx"], i["rz"]) * 0.5, region=name)
        place("Drift", "bark_driftdk", bbox((2.4, 2.4, 22.0), 0.3), at(i["cx"] + i["rx"] * 0.4, i["cz"], H(i["cx"], i["cz"]) - 1.0), name)
    for name in ("FarNE", "FarNW", "FarN"):
        i = ISLES[name]
        for k in range(3):
            boat_house(i["cx"] + rng.uniform(-100, 100), i["cz"] + rng.uniform(-50, 50), 40, rng, name)


sketch_run(NAME, [surface, edge, islands, dressing], salt, landmark=("Shell",))
