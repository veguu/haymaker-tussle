"""Map 1 of the suite, "Grassy Plains" (Gnomon's revamp; owner brief 2026-11-20). The BENCHMARK the other five follow.

    blender -b --factory-startup -P meadow.py -- <out folder> [--dry] [--fast] [--no-render]

Owner, 2026-11-20: "it should look like grass plains", "props in the background, like houses, so it looks like a
small village". My reading: grass everywhere, not a stone stadium.
  - Fighting surface: the shared oval (base.py: 426 x 352, top at 0), plain natural grass to the very edge, painted in
    numpy (warm and cool swaths, grass masses lit toward the sun, a fine mottle). Clean: no lines, nothing standing.
    NOTHING from the lobby goes on an arena (owner, 2026-11-20: every map is its own).
  - Edge: the turf rolls over the edge as a ragged grass lip, then a band of soil, then a jumble of warm rock tapering
    to a keel (the island floats, like the lobby; nothing sticks out past the edge to look like a ledge).
  - Around it: OPEN SKY (owner, 2026-11-20: "it should feel like we're fighting in the sky"; no land below, ever).
    The background is a few floating islands in the NORTH (away from the lobby), each with a rocky underside like
    the arena's: the village island, the windmill's island, a farm island with striped fields in hedgerows, two tree
    islets off the arena's sides, and three fainter islands far out.
  - The village: a hamlet on its island 1,150 studs out, high enough to show over the far rim from the middle of
    the arena and from the lobby: thatched cottages round a green, a slate-roofed barn, a windmill on a
    knoll (its sails a separate mesh, so the game can turn them). Built here, not taken from the lobby.
  - The POND (owner 2026-11-26): the old Gnomon pond in the middle of the circle, lily pond look with tall reeds
    (POND below); `--no-pond` builds without it.
"""
import os
import sys

# THE NEW FLOOR STYLE (owner 2026-11-22, approved from design/style/out/floor/floor_sheet.png; trail in
# `Style Study - Racket Strikeout.md`): the FLOOR ONLY changes; the lip, soil, rock and every island stay as they are.
#   - the arena is a CIRCLE, not the suite's oval ("more circle than oval so fix that"). RADIUS 180 is HIS size
#     (2026-11-22): the mock's 194 (the old oval's area) put the ring-out line, radius + 60, past the lobby's front.
#     It must equal MapEnvironments.Maps.meadow.arena (semiX = semiZ). `--radius=<studs>` builds another size.
#   - ONE flat green, studded at Raise a Fairy's scale (one raised square per stud; the studs are a Texture laid in
#     Studio, never geometry), DIRT where fighters wear the ground, cut on the stud grid, and small STUD FLOWERS at
#     real proportions ("slightly below the roblox character's ankle": nothing over 0.42 studs).
#   - gone with the old style: the flagstone Texture, the grass blades, the floor's painted colour map.
#   --near builds and exports ONLY the arena's own pieces (floor, dirt, flowers, lip, soil, rock) and renders them
#   among the islands of an earlier full build (`--islands=<folder name under out/suite>`, default meadow_r3), which
#   are already uploaded and unchanged; near_merge.py then writes the data studio_map.py assembles from.
RADIUS = float(next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--radius=")), 180.0))
NEAR_ONLY = "--near" in sys.argv
ISLANDS_FROM = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--islands=")), "meadow_r3")

# base.py's shared oval (A, B) is the other suite maps' (their session owns that file): Map 1 swaps in its circle as
# the file is read, so everything built from the oval (the lip, the soil, the rock, the collider, the cameras) follows.
_p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "base.py")
_src = open(_p, encoding="utf-8").read().replace("\r\n", "\n")
_oval = "A, B = 213.0, 176.0"
assert _src.count(_oval) == 1, "base.py's oval line changed: update meadow.py's circle patch"
exec(compile(_src.replace(_oval, "A, B = %r, %r" % (RADIUS, RADIUS)), _p, "exec"))
assert A == RADIUS and B == RADIUS, "the circle did not take"

NAME = "Meadow"

PAL.update(
    {
        "turf": (srgb(92, 154, 76), srgb(128, 182, 92), srgb(62, 122, 66)),
        "leaf_lip": (srgb(78, 136, 66), srgb(116, 170, 86), srgb(48, 94, 56)),
        "soil": (srgb(132, 100, 74), srgb(168, 134, 100), srgb(86, 62, 52)),
        # the arena's own soil band: the stone treatment (bevel light, a tone per block) and a hue shift, warm
        # orange-tan where lit, plum in the shade (suite-1c review: the soil read as one flat brown strip)
        "stone_soil": (srgb(138, 102, 74), srgb(196, 150, 100), srgb(92, 62, 74)),
        "soil_path": (srgb(182, 152, 108), srgb(210, 182, 136), srgb(124, 100, 78)),
        # hue shift (suite-1c review): lit faces warmer (toward gold), shade cooler (toward lavender), so the rock
        # is painted, not just darkened
        "stone_rock": (srgb(196, 176, 146), srgb(242, 216, 168), srgb(118, 108, 140)),
        "stone_deep": (srgb(150, 152, 168), srgb(204, 198, 196), srgb(84, 86, 130)),
        "stone_wall": (srgb(212, 192, 158), srgb(234, 218, 188), srgb(146, 128, 120)),
        "stone_slate": (srgb(116, 132, 156), srgb(160, 176, 198), srgb(76, 86, 108)),
        "leaf_land": (srgb(104, 164, 82), srgb(146, 198, 104), srgb(64, 118, 70)),
        "plaster": (srgb(242, 230, 204), srgb(255, 248, 228), srgb(178, 166, 162)),
        "bark_thatch": (srgb(214, 172, 92), srgb(240, 206, 130), srgb(150, 108, 64)),
        "bark_door": (srgb(104, 76, 60), srgb(140, 106, 82), srgb(64, 46, 42)),
    }
)
PX.update({"Land": 256, "FieldWall": 512, "Path": 256, "Flowers": 256})

FLOOR_OUT = 0.1  # the floor reaches this far past the circle, onto the lip (edge())
SUN_X, SUN_Z = -0.707, 0.707  # toward the sun on the ground (heading 225: the lobby's left shoulder)
GRASS = (100, 180, 86)  # sRGB: the ONE flat green (owner 2026-11-22: "obviously just one flat")
DIRT = (172, 130, 92)  # "maybe add some dirt tho where it makes sense"
CELL = 2.0  # dirt is cut on a 2-stud grid, so its edges run between the raised squares
STUD_SOURCE = os.path.abspath(os.path.join(PROJECT, "..", "..", "Raise a Fairy", "Attachments", "Style", "stud-texture.png"))
# the stud layer: studio_map.py lays this overlay (stud_overlay.py makes it from the owner's own stud texture) as a
# Texture on every floor mesh, 4 squares an image, ONE SQUARE PER STUD; its asset id goes in the build's
# upload_ids.json "floor_studs"
FLOOR_STUDS = {"image": "design/maps/suite/patterns/stud_overlay.png", "tile": 4, "transparency": 0.2}
# the colours the floor meshes get IN THE GAME: tuned in a play test (2026-11-22) from the mock's own camera until the
# screen read as the approved picture (measured on screenshots: grass 98,177,100 against the mock's 99,176,102; dirt
# 167,129,106 against 164,130,108). The game's light and grade push colours up: with the mock's own numbers (GRASS,
# DIRT) the floor came out lime (105,211,93) and the studs' lit bevels too strong (so the Texture is 20% clear).
# Retune in Studio (part Color, Texture.Transparency): no upload needed.
GRASS_GAME = (96, 148, 89)
DIRT_GAME = (141, 114, 92)

# --- THE POND (owner 2026-11-26: "u could actually add the pond in the new map 1"; he picked C "Lily pond" from
# out/suite/pond_options/pond_sheet.png, then "make the plants next to the pond look tall"). The old Gnomon pond's shape
# EXACTLY, in the middle of the circle where the floor is worn: Core/Pond's formula, and MapEnvironments
# Maps.meadow.pond holds the same numbers in Roblox axes (z = -Blender y; tests/Pond.spec.luau checks them). An
# irregular oval 24 x 18, a smooth bowl 1.6 deep, the water 0.55 under the floor: at most about a stud of water. The
# hole in the floor is cut on the dirt's 2-stud grid (a cell is basin when its centre is inside the rim); a sand shore
# and the bed are floor meshes (flat colours, studded in Studio), then the water, block lily pads and pebbles, and TALL
# reeds (3 to 6 studs) at the water's edge. Only the bowl's own collider collides (collision.json floor "tris").
# `--no-pond` builds Map 1 as it was.
POND_ON = "--no-pond" not in sys.argv
POND = dict(x=0.0, y=0.0, semiX=24.0, semiY=18.0, wobble=[(3, 0.08, 0.6), (5, 0.05, 2.1)], depth=1.6, inner=0.68, water=0.55)
POND_SAND = (226, 200, 146)  # the shore, as on the approved sheet
POND_WET = (150, 132, 96)  # the bed under the water
POND_WATER = (64, 166, 186)
POND_WATER_CLEAR = 0.2  # the water's Transparency in the game (0.8 opaque on the sheet)
# the game's colours: first guesses from the floor's own retune (the game's light lifts colours), measured and
# retuned in a play test like the floor (part Color and Transparency: no upload)
POND_SAND_GAME = (190, 170, 128)
POND_WET_GAME = (126, 112, 88)
POND_WATER_GAME = (56, 140, 160)


def _pond_ss(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def pond_rho(x, y):
    """Core/Pond.rho in Blender's x, y (floats or numpy arrays): 1 on the bank's rim."""
    u = (np.asarray(x, float) - POND["x"]) / POND["semiX"]
    v = (np.asarray(y, float) - POND["y"]) / POND["semiY"]
    th = np.arctan2(v, u)
    wob = 1.0 + sum(a * np.sin(k * th + ph) for k, a, ph in POND["wobble"])
    return np.hypot(u, v) / wob


def pond_bed(x, y):
    """How far under the floor the pond's bed is here (Core/Pond.bedDepth)."""
    return POND["depth"] * _pond_ss(1.0, POND["inner"], pond_rho(x, y))


def pond_outline(r, n):
    """n points round the pond at oval radius r (1 = the rim), Blender x, y."""
    pts = []
    for k in range(n):
        th = k / n * math.tau
        wob = 1.0 + sum(a * math.sin(kk * th + ph) for kk, a, ph in POND["wobble"])
        pts.append((POND["x"] + math.cos(th) * POND["semiX"] * r * wob, POND["y"] + math.sin(th) * POND["semiY"] * r * wob))
    return pts


def pond_water_rho():
    """The oval radius where the bed meets the water's surface."""
    lo, hi = POND["inner"], 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if float(POND["depth"] * _pond_ss(1.0, POND["inner"], mid)) > POND["water"]:
            lo = mid
        else:
            hi = mid
    return lo


# --- the fighting surface ----------------------------------------------------------------------------------------
def _dirt_mask():
    """Where the ground is worn to dirt, one cell per CELL studs (Blender x, y): the middle (the brawl) and the
    spawn ring (where every round starts), in soft patches. The approved mock's own field (floor_mock.py)."""
    n = int(RADIUS // CELL) + 1
    ii, jj = np.meshgrid(np.arange(-n, n), np.arange(-n, n), indexing="ij")
    X, Y = ii * CELL + CELL / 2, jj * CELL + CELL / 2
    rad = np.hypot(X, Y)
    v = P.fbm2(X / 34.0 + 7.3, Y / 34.0 - 2.1, 5, 3) + 0.12 * (P.fbm2(X / 9.0 + 1.3, Y / 9.0 + 4.2, 9, 2) - 0.5)
    mid = 52.0 * RADIUS / 194.0
    thr = np.full(X.shape, 0.69)
    thr = np.where(rad < mid, 0.50 + 0.10 * (rad / mid), thr)  # the middle is worn most
    ring = np.abs(rad - RADIUS * SPAWN_SHARE)
    thr = np.where(ring < 14.0, np.minimum(thr, 0.585 + 0.03 * ring / 14.0), thr)  # where rounds start
    dirt = (v > thr) & (rad < RADIUS - 12.0)
    # no two patches meeting only at a corner (one clean outline round every patch): fill such corners in
    for _ in range(64):
        a, b, c, d = dirt[:-1, :-1], dirt[1:, :-1], dirt[:-1, 1:], dirt[1:, 1:]
        pinch = (a & d & ~b & ~c) | (b & c & ~a & ~d)
        if not pinch.any():
            break
        for sl in ((slice(None, -1), slice(None, -1)), (slice(1, None), slice(None, -1)), (slice(None, -1), slice(1, None)), (slice(1, None), slice(1, None))):
            dirt[sl] |= pinch
    else:
        raise SystemExit("the dirt mask still has patches meeting at a corner after 64 passes")
    return n, dirt, X, Y, rad


DIRT_N, DIRT_MASK, DIRT_X, DIRT_Y, DIRT_RAD = _dirt_mask()
# the pond's cells, and the dirt the floor shows round it. DIRT_MASK itself stays as it was: the flowers' draws read it,
# so the approved layout is the same everywhere but at the pond
POND_MASK = (pond_rho(DIRT_X, DIRT_Y) < 1.0) if POND_ON else np.zeros_like(DIRT_MASK)
FLOOR_DIRT = DIRT_MASK & ~POND_MASK
for _ in range(64):  # no two holes in the green meeting only at a corner: a pinched corner's empty cells become dirt
    _hole = FLOOR_DIRT | POND_MASK
    _a, _b, _c, _d = _hole[:-1, :-1], _hole[1:, :-1], _hole[:-1, 1:], _hole[1:, 1:]
    _pinch = (_a & _d & ~_b & ~_c) | (_b & _c & ~_a & ~_d)
    if not _pinch.any():
        break
    for _sl in ((slice(None, -1), slice(None, -1)), (slice(1, None), slice(None, -1)), (slice(None, -1), slice(1, None)), (slice(1, None), slice(1, None))):
        FLOOR_DIRT[_sl] |= _pinch
    FLOOR_DIRT &= ~POND_MASK
else:
    raise SystemExit("the floor round the pond still has holes meeting at a corner after 64 passes")


def on_floor_dirt(x, y):
    """Is this point (Blender x, y) on a dirt cell of the floor as built (with the pond)?"""
    i, j = int(math.floor(x / CELL)) + DIRT_N, int(math.floor(y / CELL)) + DIRT_N
    return 0 <= i < 2 * DIRT_N and 0 <= j < 2 * DIRT_N and bool(FLOOR_DIRT[i, j])


def on_dirt(x, y):
    """Is this point (Blender x, y) on a dirt cell?"""
    i, j = int(math.floor(x / CELL)) + DIRT_N, int(math.floor(y / CELL)) + DIRT_N
    return 0 <= i < 2 * DIRT_N and 0 <= j < 2 * DIRT_N and bool(DIRT_MASK[i, j])


def flat_material(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = tuple((c / 255.0) ** 2.2 for c in rgb) + (1.0,)
    p.inputs["Roughness"].default_value = 0.9
    return m


def _area_up(bm):
    return sum(f.calc_area() for f in bm.faces if f.normal.z > 0.5), sum(f.calc_area() for f in bm.faces if f.normal.z <= 0.5)


def surface():
    """The floor as TWO flat meshes that share one plane and never overlap (so nothing can flicker): the dirt patches,
    and the green everywhere else out to the lip. No texture and no UVs: each is one flat colour set in Studio (so the
    owner can retune a colour without an upload), with the stud Texture over it."""
    # the dirt: its cells merged into as few flat faces as its outline allows
    def cells_mesh(mask):
        bm = bmesh.new()
        for i, j in zip(*np.nonzero(mask)):
            x0, y0 = float((i - DIRT_N) * CELL), float((j - DIRT_N) * CELL)
            bm.faces.new([bm.verts.new((x0 + dx, y0 + dy, 0.0)) for dx, dy in ((0, 0), (CELL, 0), (CELL, CELL), (0, CELL))])
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.001)
        bmesh.ops.dissolve_limit(bm, angle_limit=0.01, verts=bm.verts[:], edges=bm.edges[:])
        bm.normal_update()
        return bm

    dm = cells_mesh(FLOOR_DIRT)
    # the green's holes: the dirt and the pond's basin together (the pond's own meshes fill its cells: pond())
    hm = cells_mesh(FLOOR_DIRT | POND_MASK)
    outline = [(e.verts[0].co.copy(), e.verts[1].co.copy()) for e in hm.edges if len(e.link_faces) == 1]
    hm.free()
    bmesh.ops.triangulate(dm, faces=dm.faces[:])
    dm.normal_update()
    dirt_area, dirt_down = _area_up(dm)
    cells = int(FLOOR_DIRT.sum())
    pond_area = float(POND_MASK.sum()) * CELL * CELL
    assert dirt_down < 1e-6 and abs(dirt_area - cells * CELL * CELL) < 0.5, ("dirt mesh", dirt_area, dirt_down, cells)
    # the green: the whole circle, FLOOR_OUT past the edge (out to the lip's roll), with the dirt's outline cut out
    # of it: the very same corner points, so the two meshes meet without a crack
    gm = bmesh.new()
    n = 256
    r = RADIUS + FLOOR_OUT
    ring = [gm.verts.new((math.cos(i / n * math.tau) * r, math.sin(i / n * math.tau) * r, 0.0)) for i in range(n)]
    for i in range(n):
        gm.edges.new((ring[i], ring[(i + 1) % n]))
    at = {}

    def vert(co):
        k = (round(co.x, 3), round(co.y, 3))
        if k not in at:
            at[k] = gm.verts.new((co.x, co.y, 0.0))
        return at[k]

    for a, b in outline:
        gm.edges.new((vert(a), vert(b)))
    bmesh.ops.triangle_fill(gm, use_beauty=True, use_dissolve=False, edges=gm.edges[:], normal=(0.0, 0.0, 1.0))
    gm.normal_update()
    for f in gm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    gm.normal_update()
    grass_area, grass_down = _area_up(gm)
    disc = 0.5 * n * r * r * math.sin(math.tau / n)
    assert grass_down < 1e-6 and abs(grass_area + dirt_area + pond_area - disc) < 1.0, ("floor does not add up", grass_area, dirt_area, pond_area, disc)
    for part, bm, rgb in (("Grass", gm, GRASS), ("Dirt", dm, DIRT)):
        obj = make(f"Map_{NAME}_Floor", part, "turf", bm, "Map")
        obj.data.materials.append(flat_material(f"Map_{NAME}_Floor_{part}_Flat", rgb))
        PAINTED.append(obj)  # no baked paint: a flat colour
        print(f"FLOOR {obj.name}: {len(obj.data.polygons)} triangles", flush=True)
    print(f"FLOOR radius {RADIUS}: dirt {cells} cells, {dirt_area / disc:.1%} of the floor; pond {int(POND_MASK.sum())} cells "
          f"(dirt as drawn {int(DIRT_MASK.sum())})", flush=True)
    DATA["floor"] = {"colour": list(GRASS_GAME), "material": "Grass"}  # the collider's (what footsteps and dust read)
    DATA["floor_studs"] = dict(FLOOR_STUDS, colours={f"Map_{NAME}_Floor_Grass": list(GRASS_GAME), f"Map_{NAME}_Floor_Dirt": list(DIRT_GAME)})


# --- the edge and the island under it -----------------------------------------------------------------------------
def edge():
    rng = random.Random(19)
    # the turf rolls over: a grass lip just under the floor's edge, its outer top rounded, its hanging edge a soft wave
    # (the first pass's stepped, per-block bottoms read as game blocks)
    def wave(amp, k1, k2, ph):
        return lambda s: amp * (0.5 + 0.3 * math.sin(s / k1 + ph) + 0.2 * math.sin(s / k2 + ph * 2.3))

    # THE DARK LINE (suite-1c review): the lip's rounded corner began 0.15 inside the floor's edge, so the floor's
    # zero-thick edge hung over a gap with a shadow under it, and the lip's top ran 2.2 studs on under the floor,
    # where the bake painted it black (occluded) and that bled out along the visible edge. Now the floor reaches
    # FLOOR_OUT past the oval and the lip's roll starts exactly at the floor's edge, 0.02 under it (no flat strip,
    # no groove); its top runs on only 0.3 under the floor (covering the two outlines' chord mismatch), and
    # bake_paint_lit_edges repaints that hidden strip light so nothing dark can bleed out. 0.45 past the collider's
    # edge at most, so a fighter never seems to stand on grass and fall.
    course("Lip", "Grass", "leaf_lip", -0.45, 0.2, -2.6, -0.02, rng, 3.0, 5.0, gap=0.0, outer_chamfer=0.45 - FLOOR_OUT,
           inner_chamfer=0.01, bottom_fn=wave(2.4, 9.0, 3.7, 0.4))
    # soil under it, flush with the lip's inner face (so no slot opens up under the floor's rim), its own slower
    # wave; painted as stone (a tone per block, painted edge light, hue shift)
    course("Soil", "Earth", "stone_soil", -FLOOR_OUT, 6.0, -6.6, -2.6, rng, 4.0, 7.0, gap=0.0, top_chamfer=0.6,
           bottom_fn=wave(3.0, 14.0, 5.1, 1.7))
    # hidden fill so no joint shows sky
    core = bmesh.new()
    n = 96
    top = [core.verts.new(W(*oval(i / n * math.tau, 2.0)[:2], -0.3)) for i in range(n)]
    bot = [core.verts.new(W(*oval(i / n * math.tau, 26.0)[:2], -36.0)) for i in range(n)]
    if POND_ON:
        # the core's top is 0.3 under the floor: under the pond it would fill the basin (found on the pond sheet,
        # 2026-11-26), so it has a pit there, rim at the pond's bank, floor below the bed; it stays a closed mesh
        ring = pond_outline(1.0, 48)
        hi = [core.verts.new((x, y, -0.3)) for x, y in ring]
        lo = [core.verts.new((x, y, -POND["depth"] - 0.4)) for x, y in ring]
        rim = [core.edges.new((top[i], top[(i + 1) % n])) for i in range(n)]
        rim += [core.edges.new((hi[k], hi[(k + 1) % len(hi)])) for k in range(len(hi))]
        bmesh.ops.triangle_fill(core, use_beauty=True, use_dissolve=False, edges=rim, normal=(0.0, 0.0, 1.0))
        for k in range(len(hi)):
            m = (k + 1) % len(hi)
            core.faces.new((hi[k], hi[m], lo[m], lo[k]))
        core.faces.new(lo)
    else:
        core.faces.new(top)
    core.faces.new(list(reversed(bot)))
    for i in range(n):
        j = (i + 1) % n
        core.faces.new((top[i], bot[i], bot[j], top[j]))
    bmesh.ops.recalc_face_normals(core, faces=core.faces[:])
    add("Core", "Stone", "stone_rock", core)


# --- painted edge light (suite-1c review: the arena's rock and soil edges had none). Real bevels tripled the crag's
# triangles (21k -> 62k) and the shared baker barely lit them, so the light is PAINTED instead: after the shared
# bake, every pixel within EDGE_W studs of a convex crease is mixed toward the key's lit colour. No triangles added.
# Meadow only: this wraps the baker in this Blender process, never the shared file.
EDGE_LIT = ("_Crag_", "Map_Meadow_Soil_", "_Lip_")  # the arena's own edge, seen up close; the far islands keep the plain bake
EDGE_W = 1.2  # studs over which the light fades from a crease
EDGE_K = 0.5  # how far toward the lit colour a crease goes
_shared_bake = K["bake_paint"]


def bake_paint_lit_edges(obj, px):
    from mathutils.kdtree import KDTree

    _shared_bake(obj, px)
    if not any(s in obj.name for s in EDGE_LIT):
        return
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    pts = []
    for e in bm.edges:
        if len(e.link_faces) != 2 or e.calc_face_angle_signed(0.0) < math.radians(25):  # convex creases only
            continue
        a, b = e.verts[0].co, e.verts[1].co
        n = max(1, int((b - a).length / 0.3))
        pts.extend(a.lerp(b, i / n) for i in range(n + 1))
    bm.free()
    if not pts:
        return
    kd = KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    img = bpy.data.images.new("bake_edge_position", px, px, float_buffer=True)
    S._bake_into(obj, img, "EMIT", "Position")
    pos = ((S._pixels(img)[..., :3].astype(np.float64) - 0.5) * 4000.0).reshape(-1, 3)
    bpy.data.images.remove(img)
    d = np.full(len(pos), 1e9)
    for i in np.nonzero(np.abs(pos).max(axis=1) < 1900.0)[0]:  # empty pixels decode to -2000
        d[i] = kd.find(pos[i])[2]
    lit = np.clip(1.0 - d / EDGE_W, 0.0, 1.0) ** 1.5 * EDGE_K
    if "_Lip_" in obj.name:  # the lip's top hidden under the floor: lit colour, so no occlusion bleeds out
        rho = np.sqrt((pos[:, 0] / (A + FLOOR_OUT)) ** 2 + (pos[:, 1] / (B + FLOOR_OUT)) ** 2)
        lit = np.where((rho < 1.0) & (pos[:, 2] > -0.1), 1.0, lit)
    tex = next(nd.image for nd in obj.data.materials[0].node_tree.nodes if nd.type == "TEX_IMAGE" and nd.image)
    buf = np.empty(px * px * 4, dtype=np.float32)
    tex.pixels.foreach_get(buf)
    buf = buf.reshape(-1, 4)
    light = P.linear_to_srgb(np.asarray(PAL[obj["kit_key"]][1], dtype=np.float64))  # the PNG holds sRGB
    buf[:, :3] = buf[:, :3] * (1.0 - lit[:, None]) + light[None, :] * lit[:, None]
    tex.pixels.foreach_set(buf.ravel())
    tex.save()
    print(f"EDGE LIGHT {obj.name}: {len(pts)} crease points, {int((lit > 0.05).sum())} px lit", flush=True)


K["bake_paint"] = bake_paint_lit_edges

LIP_REACH = FLOOR_OUT  # how far past the oval a rock may reach: no further out than the soil's face


def crag():
    rng = random.Random(53)

    def rock(key, x, z, foot, size, top=None, lean=0.0, cuts=None, clamp_t=None):
        c = chunk(size, rng, cuts=cuts or rng.randint(11, 16), bevel=0.0)
        if top is not None:
            flat_top(c, top - foot)
        m = Matrix.Translation(W(x, z, foot)) @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z") @ Matrix.Rotation(lean, 4, "Y")
        if clamp_t is not None:
            # never past the lip (suite-1c review: first-ring rocks bulged out on the west): pull the rock in
            # along the oval's normal until its outermost point is at most LIP_REACH past the edge
            ox, oz, nx, nz = oval(clamp_t, 0.0)
            reach = max(((m @ v.co).x - ox) * nx + (-(m @ v.co).y - oz) * nz for v in c.verts)
            if reach > LIP_REACH:
                m = Matrix.Translation(W(-nx * (reach - LIP_REACH), -nz * (reach - LIP_REACH), 0.0)) @ m
        add("Crag", key.split("_")[1].capitalize(), key, c, m)

    # jumbled, overlapping bands: sizes from half to one and a half, spacing under a rock's width, each rock's height
    # and lean its own, some tall slabs among them
    for inset, top, size, key, spacing, flat in (
        (6.0, -6.5, (26, 22, 26), "stone_rock", 13.0, True),
        (22.0, -30.0, (36, 32, 40), "stone_rock", 17.0, False),
        (42.0, -60.0, (44, 40, 48), "stone_rock", 21.0, False),
        (66.0, -94.0, (50, 46, 56), "stone_deep", 26.0, False),
    ):
        n = int(PERIM * (1 - inset / 200.0) / spacing)
        for k in range(n):
            t = t_at((k + rng.uniform(-0.4, 0.4)) / n * PERIM)
            x, z, _, _ = oval(t, inset + rng.uniform(-3, 7))
            big = rng.uniform(0.5, 1.5) if rng.random() < 0.8 else rng.uniform(0.35, 0.5)
            sz = [s * big * rng.uniform(0.8, 1.2) for s in size]
            if not flat and rng.random() < 0.18:  # a tall slab
                sz = [sz[0] * 0.6, sz[1] * 0.75, sz[2] * 1.7]
            drop = rng.uniform(-0.25, 0.25) * size[2]
            rock(key, x, z, top - sz[2] * (0.75 if flat else 0.55) + (0 if flat else drop), tuple(sz),
                 top=top if flat else None, lean=0.0 if flat else rng.uniform(-0.22, 0.22),
                 clamp_t=t)  # every ring: nothing past the lip, so no rock reads as a ledge
    for x, z, foot, size, key in (
        (0, 0, -160, (96, 84, 84), "stone_rock"),
        (-48, 22, -140, (72, 66, 62), "stone_rock"),
        (52, -20, -136, (70, 62, 60), "stone_deep"),
        (0, 0, -214, (54, 48, 74), "stone_deep"),
        (-20, -10, -186, (60, 56, 50), "stone_deep"),
    ):
        rock(key, x, z, foot, size, cuts=14)
    core = bmesh.new()
    n = 64
    rings = [(24.0, -34.0), (60.0, -70.0), (110.0, -120.0), (150.0, -150.0)]
    loops = [[core.verts.new(W(*oval(i / n * math.tau, inset)[:2], h)) for i in range(n)] for inset, h in rings]
    core.faces.new(loops[0])
    core.faces.new(list(reversed(loops[-1])))
    for a, b in zip(loops, loops[1:]):
        for i in range(n):
            j = (i + 1) % n
            core.faces.new((a[i], b[i], b[j], a[j]))
    bmesh.ops.recalc_face_normals(core, faces=core.faces[:])
    add("Core", "Stone", "stone_rock", core)


# --- THE POND's pieces (POND at the top; the look is pond_options.py's C, the same draws, so the same layout) ---------
# the lily pads', pebbles' and reeds' palette: one image (one draw a mesh), a 64 px cell per colour; the first two rows
# print one stud in the cell's middle (on a squarish block face, as the flowers do), the last two are plain (long faces:
# a stud stretched up a 5-stud stalk would read as a smear)
POND_DECO = [(86, 172, 80), (124, 198, 98), (255, 150, 190), (255, 206, 60),  # pad, pad lit, bloom, yolk
             (70, 150, 74), (96, 172, 84), (58, 128, 66), (122, 84, 60),  # reeds (three greens), cattail
             (150, 156, 176), (184, 188, 200), (128, 134, 156)]  # pebbles
POND_WADE = (5.0, 3.0)  # the review's wading fighter (the pads keep clear of it, as on the sheet)
POND_RIM = []  # the bank's rim for the collider, arena-local Roblox (x, height, z)
POND_TRIS = []  # the bowl's collider triangles, the same axes


def _pond_palette(path):
    f = _stud_factor(32)
    img = np.zeros((256, 512, 3))
    for k, rgb in enumerate(POND_DECO):
        for cell, studded in ((k, True), (16 + k, False)):
            cx, cy = cell % 8, cell // 8
            c = np.broadcast_to(P.rgb(*rgb), (64, 64, 3)).copy()
            if studded:
                c[16:48, 16:48] = c[16:48, 16:48] * f[..., None]
            img[cy * 64 : cy * 64 + 64, cx * 64 : cx * 64 + 64] = c
    P.save_png(path, np.clip(img, 0, 1))


def pond():
    if not POND_ON:
        return
    basin = {(int(i) - DIRT_N, int(j) - DIRT_N) for i, j in zip(*np.nonzero(POND_MASK))}
    wet = {c for c in basin if float(pond_bed(c[0] * CELL + CELL / 2, c[1] * CELL + CELL / 2)) > POND["water"]}
    shore = basin - wet
    rho_w = pond_water_rho()

    def cells_at(x, y):
        """The cells whose closed square holds the point."""
        xs = {math.floor(x / CELL)} | ({round(x / CELL) - 1} if abs(x / CELL - round(x / CELL)) < 1e-6 else set())
        ys = {math.floor(y / CELL)} | ({round(y / CELL) - 1} if abs(y / CELL - round(y / CELL)) < 1e-6 else set())
        return [(int(i), int(j)) for i in xs for j in ys]

    def z(x, y):
        """The bed's height (Core/Pond's bowl), exactly 0 on the basin's outline so it meets the floor."""
        if any(c not in basin for c in cells_at(x, y)):
            return 0.0
        return -float(pond_bed(x, y))

    def sheet(cells):
        """The cells as one surface on a 1-stud grid, the bowl's height at each corner."""
        bm = bmesh.new()
        vs = {}

        def v(x, y):
            k = (round(x, 3), round(y, 3))
            if k not in vs:
                vs[k] = bm.verts.new((x, y, z(x, y)))
            return vs[k]

        for i, j in cells:
            for a in range(2):
                for b in range(2):
                    x0, y0 = i * CELL + a, j * CELL + b
                    bm.faces.new([v(x0, y0), v(x0 + 1, y0), v(x0 + 1, y0 + 1), v(x0, y0 + 1)])
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        return bm

    made = {}
    for part, cells, rgb in (("PondShore", shore, POND_SAND), ("PondBed", wet, POND_WET)):
        obj = make(f"Map_{NAME}_Floor", part, "turf", sheet(cells), "Map")
        obj.data.materials.append(flat_material(f"Map_{NAME}_Floor_{part}_Flat", rgb))
        PAINTED.append(obj)
        made[part] = len(obj.data.polygons)
    # the water: a flat surface at the waterline along a smooth shore, thick to below the bed (never paper-thin)
    pts = pond_outline(rho_w * 1.01, 160)
    bm = bmesh.new()
    top = [bm.verts.new((x, y, -POND["water"])) for x, y in pts]
    bot = [bm.verts.new((x, y, -POND["depth"] - 0.1)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for k in range(len(pts)):
        m = (k + 1) % len(pts)
        bm.faces.new((top[k], bot[k], bot[m], top[m]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    obj = make(f"Map_{NAME}_Pond", "Water", "stone_slate", bm, "Map")
    obj.data.materials.append(flat_material(f"Map_{NAME}_Pond_Water_Flat", POND_WATER))
    PAINTED.append(obj)
    made["Water"] = len(obj.data.polygons)
    # the lily pads, blooms and pebbles (no shadows), the tall reeds (shadows): pond_options.py look C, the same draws
    bags = {}
    for name in ("Deco", "Reeds"):
        b = bmesh.new()
        bags[name] = (b, b.loops.layers.uv.new("UVMap"))

    def block(name, rgb, x, y, z0, sx, sy, sz):
        b, uvl = bags[name]
        k = POND_DECO.index(rgb)
        vs = [b.verts.new((x + dx * sx, y + dy * sy, z0 + dz * sz)) for dz in (0, 1) for dx, dy in ((0, 0), (1, 0), (1, 1), (0, 1))]
        for f, w, h in (((0, 1, 5, 4), sx, sz), ((1, 2, 6, 5), sy, sz), ((2, 3, 7, 6), sx, sz), ((3, 0, 4, 7), sy, sz), ((4, 5, 6, 7), sx, sy)):
            cell = k if max(w, h) <= 2.0 * min(w, h) else 16 + k
            u0, v0 = (cell % 8 * 64 + 16) / 512.0, (cell // 8 * 64 + 16) / 256.0
            face = b.faces.new([vs[q] for q in f])
            for lp, uv in zip(face.loops, ((u0, v0), (u0 + 0.0625, v0), (u0 + 0.0625, v0 + 0.125), (u0, v0 + 0.125))):
                lp[uvl].uv = uv

    rng = random.Random(1126)  # the sheet's seed
    w = POND["water"]
    u = 0.3
    pads = []
    while len(pads) < 11:
        x, y = rng.uniform(-22, 22), rng.uniform(-16, 16)
        if float(pond_rho(x, y)) < rho_w * 0.86 and math.dist((x, y), POND_WADE) > 4.5 and all(math.dist((x, y), p) > 3.2 for p in pads):
            pads.append((x, y))
    for k, (x, y) in enumerate(pads):
        leaf = POND_DECO[0] if k % 3 else POND_DECO[1]
        notch = rng.randrange(4)
        for a in range(-2, 3):
            for b in range(-2, 3):
                if abs(a) + abs(b) > 3 or (notch == 0 and a == 0 and b > 0) or (notch == 1 and a == 0 and b < 0) or \
                        (notch == 2 and b == 0 and a > 0) or (notch == 3 and b == 0 and a < 0):
                    continue
                block("Deco", leaf, x + a * u - u / 2, y + b * u - u / 2, -w - 0.04, u, u, 0.1)
        if k % 3 == 0:
            block("Deco", POND_DECO[2], x - u / 2 + 0.3, y - u / 2 + 0.3, -w + 0.06, u, u, u)
            block("Deco", POND_DECO[3], x + 0.38, y + 0.38, -w + 0.36, 0.14, 0.14, 0.14)
    # TALL reeds in clumps at the waterline (owner: "make the plants next to the pond look tall"): chest height to a
    # little over a fighter's head, stalks of three blocks stepping a little sideways (a bend on the grid), cattail
    # heads, long flat leaves
    reeds = 0
    for ang in (3.6, 5.5, 1.1, 2.45):
        for _ in range(14):
            r = rho_w * rng.uniform(0.93, 1.07)
            th = ang + rng.uniform(-0.16, 0.16)
            wob = 1.0 + sum(a * math.sin(kk * th + ph) for kk, a, ph in POND["wobble"])
            x, y = math.cos(th) * POND["semiX"] * r * wob, math.sin(th) * POND["semiY"] * r * wob
            x, y = round(x / 0.14) * 0.14, round(y / 0.14) * 0.14
            h = rng.uniform(3.0, 6.0)
            base = z(x, y) - 0.1
            green = rng.choice((POND_DECO[4], POND_DECO[5], POND_DECO[6]))
            reeds += 1
            if rng.random() < 0.35:  # a long flat leaf, leaning out in two steps
                lx, ly = rng.choice(((0.14, 0), (-0.14, 0), (0, 0.14), (0, -0.14)))
                block("Reeds", green, x, y, base, 0.42 if lx == 0 else 0.1, 0.1 if lx == 0 else 0.42, (h * 0.55) - base)
                block("Reeds", green, x + lx, y + ly, h * 0.55, 0.42 if lx == 0 else 0.1, 0.1 if lx == 0 else 0.42, h * 0.3)
                continue
            dx, dy = rng.choice(((0.07, 0), (-0.07, 0), (0, 0.07), (0, -0.07)))
            seg = (h - base) / 3
            for s in range(3):
                block("Reeds", green, x + dx * s, y + dy * s, base + seg * s, 0.2, 0.2, seg)
            if rng.random() < 0.6:
                block("Reeds", POND_DECO[7], x + dx * 2 - 0.06, y + dy * 2 - 0.06, h - 0.9, 0.32, 0.32, 0.75)
                block("Reeds", green, x + dx * 2 + 0.03, y + dy * 2 + 0.03, h - 0.15, 0.14, 0.14, 0.45)
    for ang0, ang1 in ((0.2, 0.9), (2.2, 2.9), (4.2, 4.8)):  # block pebbles in three arcs on the shore, wide gaps
        for _ in range(7):
            th = rng.uniform(ang0, ang1)
            r = rng.uniform(0.92, 1.02)
            wob = 1.0 + sum(a * math.sin(kk * th + ph) for kk, a, ph in POND["wobble"])
            x, y = math.cos(th) * POND["semiX"] * r * wob, math.sin(th) * POND["semiY"] * r * wob
            s = rng.choice((0.42, 0.56, 0.7))
            grey = rng.choice((POND_DECO[8], POND_DECO[9], POND_DECO[10]))
            z0 = z(x, y) - s * 0.4
            block("Deco", grey, x, y, z0, s, s * rng.choice((1, 1.4)), s * 0.8)
    mat = None
    if not DRY:
        path = os.path.join(TEX, f"Map_{NAME}_Pond_Color.png")
        _pond_palette(path)
        mat = S.image_material(f"Map_{NAME}_Pond_Painted", {"colour": path}, roughness=0.9)
    for name, (b, _uvl) in bags.items():
        bmesh.ops.triangulate(b, faces=b.faces[:])
        tallest = max(v.co.z for v in b.verts)
        obj = make(f"Map_{NAME}_Pond", name, "leaf_lip", b, "Map")
        if mat is not None:
            obj.data.materials.append(mat)
        PAINTED.append(obj)
        made[name] = len(obj.data.polygons)
        print(f"POND {obj.name}: tallest {tallest:.2f}", flush=True)
    # the collider: the bowl as rings of the formula's level lines (each ring is level: the bed's depth depends only
    # on rho), 24 points round, and a flat middle; the floor round it is built in floor_collision (below)
    rob = lambda x, y, hgt: (round(x, 3), round(hgt, 3), round(-y, 3))  # noqa: E731
    levels = [1.0, 0.92, 0.84, 0.76, POND["inner"]]
    rings = [[rob(x, y, -float(pond_bed(x, y)) if lv < 1.0 else 0.0) for x, y in pond_outline(lv, 24)] for lv in levels]
    POND_RIM[:] = rings[0]
    POND_TRIS.clear()
    for k in range(len(rings) - 1):
        a_, b_ = rings[k], rings[k + 1]
        for i in range(24):
            j = (i + 1) % 24
            POND_TRIS.append((a_[i], a_[j], b_[j]))
            POND_TRIS.append((a_[i], b_[j], b_[i]))
    mid = rob(POND["x"], POND["y"], -POND["depth"])
    for i in range(24):
        POND_TRIS.append((mid, rings[-1][i], rings[-1][(i + 1) % 24]))
    DATA["floor_studs"]["colours"][f"Map_{NAME}_Floor_PondShore"] = list(POND_SAND_GAME)
    DATA["floor_studs"]["colours"][f"Map_{NAME}_Floor_PondBed"] = list(POND_WET_GAME)
    DATA["pond"] = {
        "shape": {"x": POND["x"], "z": 0.0 - POND["y"], "semiX": POND["semiX"], "semiZ": POND["semiY"], "wobble": POND["wobble"],
                  "depth": POND["depth"], "inner": POND["inner"], "water": POND["water"]},
        "water": {"mesh": f"Map_{NAME}_Pond_Water", "colour": list(POND_WATER_GAME), "transparency": POND_WATER_CLEAR},
        "decor": {f"Map_{NAME}_Pond_Deco": {"shadow": False}, f"Map_{NAME}_Pond_Reeds": {"shadow": True}},
        "cells": len(basin), "water_cells": len(wet), "pads": len(pads), "reeds": reeds,
    }
    print(f"POND {len(basin)} cells ({len(wet)} wet, {len(shore)} shore), water rho {rho_w:.3f}, triangles {made}, "
          f"collider {len(POND_TRIS)} bowl triangles", flush=True)


def _ring_tris(outer, inner):
    """Triangles filling the ring between two closed outlines round the same middle (both star-shaped about it),
    walked together by angle. Points are (x, height, z)."""
    def ang(p):
        return math.atan2(p[2], p[0]) % math.tau

    o, i = sorted(outer, key=ang), sorted(inner, key=ang)
    no, ni = len(o), len(i)
    out, a, b = [], 0, 0
    while a < no or b < ni:
        na = ang(o[(a + 1) % no]) + (math.tau if a + 1 >= no else 0.0)
        nb = ang(i[(b + 1) % ni]) + (math.tau if b + 1 >= ni else 0.0)
        if b >= ni or (a < no and na <= nb):
            out.append((o[a % no], o[(a + 1) % no], i[b % ni]))
            a += 1
        else:
            out.append((o[a % no], i[(b + 1) % ni], i[b % ni]))
            b += 1
    return out


_base_floor_collision = floor_collision


def floor_collision(top=0.0, thick=4.0, n=128):
    """base.floor_collision (the circle's polygon, kept), plus with the pond the floor as TRIANGLES: the ring of floor
    round the pond and the pond's bowl (arena-local Roblox x, height, z). studio_map.py builds "tris" when present."""
    _base_floor_collision(top, thick, n)
    if POND_TRIS:
        outer = [(p[0], top, p[1]) for p in COLLISION["floor"]["poly"]]
        tris = _ring_tris(outer, POND_RIM) + POND_TRIS
        COLLISION["floor"]["tris"] = [[list(v) for v in t] for t in tris]
        print("COLLIDER", len(tris), "triangles (floor ring", len(tris) - len(POND_TRIS), "+ bowl", len(POND_TRIS), ")", flush=True)


# --- the backdrop: floating islands in open sky (owner, 2026-11-20: "it should feel like we're fighting in the sky";
# NOTHING under or round the arena, only background details), each with a rocky underside like the arena's -------
# name, centre x, z, semi-axes rx, rz, top (edge height), hill (rise in the middle), key, crag depth
# FIX ROUND 2026-11-22 (owner: "islands kinda packed with stuff"; fresh review: tops bare, islands on the horizon line,
# E/S/W empty): every island LIFTED into the sky (tops 40-210 studs over the floor line, so their rocky undersides
# show from a fighter's eye; GroveE stays low for depth), four NEW islands fill the empty bearings (Orchard east,
# Hamlet west, Pasture and Dovecote on the lobby's flanks, clear of its view of the arena), and every top is packed
# (pack()). Names starting "Far" are dropped on phones (MapEnvironments phoneHide "_FarN"...).
ISLANDS = [
    ("Village", -120.0, -1150.0, 300.0, 230.0, 92.0, 26.0, "leaf_land", 190.0),
    ("Mill", -400.0, -850.0, 120.0, 105.0, 70.0, 30.0, "leaf_land", 130.0),
    ("Farm", 560.0, -1020.0, 250.0, 175.0, 60.0, 12.0, "leaf_land", 150.0),
    ("GroveE", 660.0, -300.0, 95.0, 75.0, -40.0, 10.0, "leaf_land", 85.0),
    ("GroveW", -690.0, -360.0, 105.0, 85.0, 20.0, 10.0, "leaf_land", 90.0),
    ("Orchard", 1000.0, 20.0, 210.0, 150.0, 70.0, 14.0, "leaf_land", 140.0),
    ("Hamlet", -1050.0, -40.0, 230.0, 160.0, 110.0, 18.0, "leaf_land", 150.0),
    ("Pasture", 830.0, 520.0, 170.0, 130.0, 40.0, 10.0, "leaf_land", 110.0),
    ("Dovecote", -860.0, 560.0, 160.0, 130.0, 150.0, 16.0, "leaf_land", 120.0),
    ("FarNE", 1350.0, -1950.0, 170.0, 120.0, 150.0, 22.0, "leaf_far", 120.0),
    ("FarNW", -1450.0, -2050.0, 190.0, 130.0, 180.0, 26.0, "leaf_far", 130.0),
    ("FarN", 260.0, -2500.0, 230.0, 150.0, 210.0, 30.0, "leaf_far", 150.0),
]
ISLE = {i[0]: i for i in ISLANDS}
VC = (-120.0, -1150.0)  # the village green: the middle of the village island
# MESH GROUPS: neighbouring islands share their meshes (the fix round's packing took Map 1 from 120 to 272 meshes, each
# a draw call). Every group spans under 2,048 studs (the mesh limit); the far islands keep their own names (phones
# drop "_FarN..."). Used by islands(), vput(), far_tree(), haystack() and hedge().
GROUP = {"Village": "N", "Mill": "N", "Farm": "N", "GroveE": "E", "Orchard": "E", "Pasture": "E", "GroveW": "W",
         "Hamlet": "W", "Dovecote": "W", "": "N",  # "": the village's first ring and the windmill (sails: *_N)
         "FarNE": "FarNEN", "FarN": "FarNEN"}  # still "_FarN...", so phones drop them


def grp(region):
    return GROUP.get(region, region)


V_Y = 110.0  # its flat shelf, 18 over the island's edge (as before the lift), so the island's rock shows under it
MILL = (ISLE["Mill"][1], ISLE["Mill"][2])
WINDMILL_SCALE = 1.7  # the mill as designed (about 240 studs to the sail tips) times this
PX.update({"Island": 512, "Crops": 256, "Hedges": 512, "Trees": 512, "Path": 256})
PAL.update(
    {
        "leaf_far": (srgb(122, 170, 142), srgb(162, 200, 172), srgb(86, 126, 114)),
        "leaf_hedge": (srgb(66, 122, 68), srgb(100, 158, 88), srgb(40, 84, 54)),
        "leaf_tree": (srgb(84, 150, 82), srgb(126, 188, 106), srgb(50, 104, 64)),
        "leaf_treedeep": (srgb(64, 124, 76), srgb(102, 164, 98), srgb(38, 86, 58)),
        "leaf_treegold": (srgb(222, 178, 72), srgb(246, 212, 122), srgb(162, 120, 52)),
        "crop_wheat": (srgb(228, 192, 100), srgb(246, 216, 136), srgb(172, 132, 74)),
        "crop_green": (srgb(150, 192, 92), srgb(186, 216, 122), srgb(100, 142, 72)),
        "crop_furrow": (srgb(152, 114, 82), srgb(186, 148, 110), srgb(102, 74, 60)),
        "crop_sage": (srgb(176, 196, 134), srgb(206, 220, 164), srgb(122, 142, 98)),
        "crop_hay": (srgb(222, 186, 104), srgb(244, 212, 140), srgb(160, 124, 72)),
        "plaster_sand": (srgb(236, 214, 178), srgb(252, 234, 204), srgb(172, 152, 138)),
        "plaster_sage": (srgb(214, 226, 200), srgb(236, 244, 224), srgb(150, 162, 148)),
        "bark_moss": (srgb(152, 162, 84), srgb(186, 196, 116), srgb(102, 112, 60)),
        "paint_sage": (srgb(110, 156, 128), srgb(146, 190, 160), srgb(72, 108, 92)),
    }
)


def sstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def outline(isl, a):
    """The island's edge radius factor at angle a (a gentle wobble, its own per island)."""
    s = sum(map(ord, isl[0]))
    return 1.0 + 0.07 * math.sin(3 * a + s) + 0.04 * math.sin(5 * a + s * 0.7)


def island_h(isl, x, z):
    name, cx, cz, rx, rz, top, hill, _key, _depth = isl
    u, v = (x - cx) / rx, (z - cz) / rz
    h = top + hill * math.exp(-((u / 0.6) ** 2 + (v / 0.6) ** 2)) + 1.5 * math.sin(x / 23.0 + z / 31.0)
    if name == "Village":  # the green and the houses stand on a flat shelf
        d = math.hypot(x - VC[0], (z - VC[1]) * 1.2)
        h += (V_Y - h) * sstep(220.0, 150.0, d)
    return h


def H(x, z):
    """The ground's height at (x, z) on whichever island holds that point (the nearest, measured in its own size)."""
    best = min(ISLANDS, key=lambda i: ((x - i[1]) / i[3]) ** 2 + ((z - i[2]) / i[4]) ** 2)
    return island_h(best, x, z)


def region_of(x, z):
    return f"{int((x + 3000) // 1000)}{int((z + 4000) // 1000)}"


def islands():
    for isl in ISLANDS:
        name, cx, cz, rx, rz, top, hill, key, depth = isl
        rng = random.Random(sum(map(ord, name)))
        reg = grp(name)
        # the top: a fan of rings out to the wobbly edge, following the island's ground
        bm = bmesh.new()
        n = 40
        fr = (0.0, 0.22, 0.45, 0.66, 0.84, 1.0)
        centre = bm.verts.new(W(cx, cz, island_h(isl, cx, cz)))
        rings = []
        for f in fr[1:]:
            ring = []
            for i in range(n):
                a = i / n * math.tau
                k = f * outline(isl, a)
                x, z = cx + math.cos(a) * rx * k, cz + math.sin(a) * rz * k
                ring.append(bm.verts.new(W(x, z, island_h(isl, x, z))))
            rings.append(ring)
        for i in range(n):
            bm.faces.new((centre, rings[0][i], rings[0][(i + 1) % n]))
        for r0, r1 in zip(rings, rings[1:]):
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((r0[i], r1[i], r1[j]))
                bm.faces.new((r0[i], r1[j], r0[j]))
        # its rim: the turf rolls over (a lip), then soil, set back under it
        lip = [bm.verts.new(W(cx + math.cos(i / n * math.tau) * rx * outline(isl, i / n * math.tau) * 1.005, cz + math.sin(i / n * math.tau) * rz * outline(isl, i / n * math.tau) * 1.005, island_h(isl, cx + math.cos(i / n * math.tau) * rx, cz + math.sin(i / n * math.tau) * rz) - 3.0 - 1.5 * math.sin(i * 1.7))) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((rings[-1][i], lip[i], lip[j], rings[-1][j]))
        lip_co = [v.co.copy() for v in lip]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        add("Island", "Grass", key, bm, region=reg)
        soil = bmesh.new()
        lo = [soil.verts.new(W(cx + math.cos(i / n * math.tau) * rx * outline(isl, i / n * math.tau) * 0.985, cz + math.sin(i / n * math.tau) * rz * outline(isl, i / n * math.tau) * 0.985, top - 9.0 - 2.0 * math.sin(i * 2.3))) for i in range(n)]
        up = [soil.verts.new(c) for c in lip_co]
        for i in range(n):
            j = (i + 1) % n
            soil.faces.new((up[i], lo[i], lo[j], up[j]))
        bmesh.ops.recalc_face_normals(soil, faces=soil.faces[:])
        add("Island", "Soil", "soil", soil, region=reg)
        # the underside: jumbled bands of rock tapering to a keel, sized to the island
        size = min(rx, rz)
        for frac, drop, sz, rkey in ((0.93, 6.0, 0.16, "stone_rock"), (0.72, 0.3, 0.22, "stone_rock"), (0.46, 0.6, 0.28, "stone_deep")):
            per = math.pi * (rx + rz) * frac
            cnt = max(6, int(per / (size * sz * 0.85)))
            for k in range(cnt):
                a = (k + rng.uniform(-0.3, 0.3)) / cnt * math.tau
                ok = outline(isl, a) * frac
                x, z = cx + math.cos(a) * rx * ok, cz + math.sin(a) * rz * ok
                big = rng.uniform(0.6, 1.4)
                s3 = (size * sz * big * 1.3, size * sz * big * 1.15, size * sz * big * 1.4)
                c = chunk(s3, rng, cuts=rng.randint(11, 15), bevel=0.0)
                if drop > 1:  # the top band sits flat under the soil
                    foot = top - drop - s3[2] * 0.8
                    flat_top(c, s3[2] * 0.8)
                else:
                    foot = top - depth * drop - s3[2] * 0.5 + rng.uniform(-0.1, 0.1) * depth
                add("Island", rkey.split("_")[1].capitalize(), rkey, c, Matrix.Translation(W(x, z, foot)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z") @ Matrix.Rotation(rng.uniform(-0.2, 0.2), 4, "Y"), region=reg)
        for f, d2 in ((0.55, 0.62), (0.3, 0.9)):  # the keel
            s3 = (rx * f, rz * f, depth * 0.55)
            c = chunk(s3, rng, cuts=13, bevel=0.0)
            add("Island", "Deep", "stone_deep", c, Matrix.Translation(W(cx, cz, top - depth * d2)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z"), region=reg)
        core = bmesh.new()  # hidden fill, so no gap between the rocks shows sky through the island
        loops = []
        for f, h in ((0.9, top - 4.0), (0.62, top - depth * 0.45), (0.3, top - depth * 0.8)):
            loops.append([core.verts.new(W(cx + math.cos(i / 24 * math.tau) * rx * f, cz + math.sin(i / 24 * math.tau) * rz * f, h)) for i in range(24)])
        core.faces.new(loops[0])
        core.faces.new(list(reversed(loops[-1])))
        for l0, l1 in zip(loops, loops[1:]):
            for i in range(24):
                j = (i + 1) % 24
                core.faces.new((l0[i], l1[i], l1[j], l0[j]))
        bmesh.ops.recalc_face_normals(core, faces=core.faces[:])
        add("Island", "Rock", "stone_rock", core, region=reg)


# --- building blocks (the reference study: chunky, exaggerated, edges caught by the light, bands at the joins) -----
def bbox(size, bevel=0.35, taper=(1.0, 1.0)):
    """A box from z = 0 up, sized (sx, sy, sz), its top scaled by `taper`, every edge bevelled (the baker lights
    bevels, so each block shows a painted edge light)."""
    sx, sy, sz = size
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1.0)
    for v in b.verts:
        top = v.co.z > 0
        fx, fy = taper if top else (1.0, 1.0)
        v.co = Vector((v.co.x * sx * fx, v.co.y * sy * fy, (v.co.z + 0.5) * sz))
    if bevel > 0:
        bmesh.ops.bevel(b, geom=b.edges[:], offset=min(bevel, 0.3 * min(sx, sy, sz)), segments=1, affect="EDGES", clamp_overlap=True)
    bmesh.ops.triangulate(b, faces=b.faces[:])
    return b


def ring_prism(bm, rings, n, close_bottom=True, close_top=True):
    """A turned shape: rings = [(radius, height)] bottom to top, n sides."""
    # vertices half a step round, so a face (not a corner) points along -y, the front
    loops = [[bm.verts.new((math.cos((i + 0.5) / n * math.tau) * r, math.sin((i + 0.5) / n * math.tau) * r, h)) for i in range(n)] for r, h in rings]
    if close_bottom:
        bm.faces.new(list(reversed(loops[0])))
    if close_top:
        bm.faces.new(loops[-1])
    for lo, hi in zip(loops, loops[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def annulus(bm, r0, r1, h0, h1, n):
    """A flat ring (a deck or a band round a turned shape)."""
    ang = [(i + 0.5) / n * math.tau for i in range(n)]
    lo0 = [bm.verts.new((math.cos(a) * r0, math.sin(a) * r0, h0)) for a in ang]
    lo1 = [bm.verts.new((math.cos(a) * r1, math.sin(a) * r1, h0)) for a in ang]
    hi0 = [bm.verts.new((math.cos(a) * r0, math.sin(a) * r0, h1)) for a in ang]
    hi1 = [bm.verts.new((math.cos(a) * r1, math.sin(a) * r1, h1)) for a in ang]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((hi0[i], hi1[i], hi1[j], hi0[j]))
        bm.faces.new((lo0[j], lo1[j], lo1[i], lo0[i]))
        bm.faces.new((lo1[i], lo1[j], hi1[j], hi1[i]))
        bm.faces.new((lo0[j], lo0[i], hi0[i], hi0[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


VILLAGE = {}  # (element, key) -> bmesh: the whole village is a handful of meshes


def vput(element, key, b, matrix, region=""):
    append(VILLAGE.setdefault((element, key, grp(region)), bmesh.new()), b, matrix)


VREGION = [""]  # the region the next house's pieces go to (farmsteads are far apart)


def facing(x, z, tx, tz):
    """The yaw that turns local -y (a building's front) toward (tx, tz), arena-local."""
    return math.atan2(tx - x, tz - z)


def T(*co):
    return Matrix.Translation(co)


def house(x, z, yaw, w, d, wall_h, rng, roof="bark_thatch", walls="plaster", accent="cloth_teal", storeys=1,
          chimney=True, element="Village", door_side=0.0):
    """A storybook house facing local -y. Squat tapered walls on a deep stone plinth, timber corner posts and bands
    at every join, a heavy overhanging roof (thatch thick and rounded, slate thinner) set a little crooked, a
    leaning chimney with a cap, a door and shuttered windows in the accent colour."""
    y = H(x, z)
    m = Matrix.Translation(W(x, z, y)) @ Matrix.Rotation(yaw, 4, "Z")
    vput(element, "stone_wall", bbox((w + 1.8, d + 1.8, 9.5), 0.5), m @ T(0, 0, -8.0), region=VREGION[0])
    top = 1.5 + wall_h
    vput(element, walls, bbox((w, d, wall_h), 0.5, (0.97, 0.97)), m @ T(0, 0, 1.5), region=VREGION[0])
    if storeys == 2:  # a jettied upper floor, overhanging on every side
        up = wall_h * 0.8
        vput(element, "bark_timber", bbox((w + 2.2, d + 2.2, 1.2), 0.3), m @ T(0, 0, top - 0.4), region=VREGION[0])
        vput(element, walls, bbox((w + 1.8, d + 1.8, up), 0.5, (0.98, 0.98)), m @ T(0, 0, top + 0.8), region=VREGION[0])
        top = top + 0.8 + up
    for sx in (-1, 1):
        for sy in (-1, 1):
            vput(element, "bark_timber", bbox((1.7, 1.7, top - 1.6), 0.3), m @ T(sx * (w / 2 - 0.1), sy * (d / 2 - 0.1), 1.5), region=VREGION[0])
    vput(element, "bark_timber", bbox((w + 0.9, d + 0.9, 1.3), 0.3), m @ T(0, 0, top - 1.0), region=VREGION[0])
    # roof: a gable volume under two heavy slabs and a ridge roll, the whole roof turned a touch off square
    thatch = roof.startswith("bark")
    th = 3.0 if thatch else 1.8
    over_d, over_l = (3.2, 2.4) if thatch else (2.4, 1.8)
    rise = d * (0.78 if thatch else 0.62)
    skew = Matrix.Rotation(rng.uniform(-0.03, 0.03), 4, "Z")
    g = bmesh.new()
    L, D = w / 2 - 0.2, d / 2 - 0.2
    a = [g.verts.new((-L, -D, top)), g.verts.new((-L, D, top)), g.verts.new((-L, 0, top + rise))]
    c = [g.verts.new((L, -D, top)), g.verts.new((L, D, top)), g.verts.new((L, 0, top + rise))]
    g.faces.new((a[0], a[1], a[2]))
    g.faces.new((c[2], c[1], c[0]))
    g.faces.new((a[0], c[0], c[1], a[1]))
    bmesh.ops.recalc_face_normals(g, faces=g.faces[:])
    vput(element, walls, g, m, region=VREGION[0])
    run_ = math.hypot(d / 2 + over_d, rise + over_d * rise / (d / 2))
    pitch = math.atan2(rise, d / 2)
    for side in (-1, 1):
        slab = bbox((w + 2 * over_l, run_, th), 0.9 if thatch else 0.4)
        # the slab's inner edge on the ridge, sloping down to the eave
        r = Matrix.Translation((0, side * (run_ / 2) * math.cos(pitch), top + rise - (run_ / 2) * math.sin(pitch) + 0.2)) @ Matrix.Rotation(-side * pitch, 4, "X") @ Matrix.Translation((0, 0, -th / 2))
        vput(element, roof, slab, m @ skew @ r, region=VREGION[0])
    ridge = bmesh.new()
    tube(ridge, [(-(w / 2 + over_l), 0, top + rise + th * 0.55), ((w / 2 + over_l), 0, top + rise + th * 0.55)], [th * 0.75, th * 0.75], sides=6)
    vput(element, roof, ridge, m @ skew, region=VREGION[0])
    if chimney:
        cx = w / 2 - 4.0
        lean = Matrix.Rotation(rng.uniform(-0.07, 0.07), 4, "Y")
        ch_h = rise + 6.0
        vput(element, "stone_wall", bbox((3.8, 3.8, ch_h), 0.4, (0.82, 0.82)), m @ T(cx, d * 0.18, top - 1.0) @ lean, region=VREGION[0])
        vput(element, "stone_wall", bbox((4.4, 4.4, 1.0), 0.3), m @ T(cx, d * 0.18, top - 1.0) @ lean @ T(0, 0, ch_h), region=VREGION[0])
    # door, windows, shutters
    vput(element, accent, bbox((4.4, 1.0, 7.4), 0.3), m @ T(door_side * w * 0.25, -d / 2 - 0.25, 1.5), region=VREGION[0])
    vput(element, "stone_wall", bbox((6.0, 1.3, 1.2), 0.3), m @ T(door_side * w * 0.25, -d / 2 - 0.3, 9.0), region=VREGION[0])
    rows = [(5.0, -d / 2 - 0.2, [fx for fx in (-0.3, 0.0, 0.3) if abs(fx - door_side * 0.25) > 0.18])]
    if storeys == 2:
        rows.append((top - wall_h * 0.8 + 2.0, -d / 2 - 1.1, [-0.32, 0.0, 0.32]))
    for z0, front, xs in rows:
        for fx in xs:
            wx = fx * w
            vput(element, "bark_door", bbox((3.4, 0.8, 3.6), 0.25), m @ T(wx, front, z0), region=VREGION[0])
            vput(element, "stone_wall", bbox((4.2, 1.2, 0.7), 0.2), m @ T(wx, front - 0.2, z0 - 0.6), region=VREGION[0])
            for s in (-1, 1):
                vput(element, accent, bbox((1.5, 0.7, 3.8), 0.2), m @ T(wx + s * 2.6, front - 0.1, z0 - 0.1), region=VREGION[0])
    for fx in (-0.25, 0.25):
        vput(element, "bark_door", bbox((3.4, 0.8, 3.6), 0.25), m @ T(fx * w, d / 2 + 0.2, 5.0), region=VREGION[0])


def chapel(x, z, yaw, rng):
    """The village's second landmark: a long slate-roofed nave and a square tower with a slate spire and a gold
    finial, at the green's far side, so its spire stands over the roofs."""
    house(x, z, yaw, 52, 26, 18, rng, roof="stone_slate", walls="plaster_sand", accent="paint_sage", chimney=False)
    y = H(x, z)
    m = Matrix.Translation(W(x, z, y)) @ Matrix.Rotation(yaw, 4, "Z") @ T(-26 - 9, 0, 0)
    vput("Village", "stone_wall", bbox((20, 20, 66), 0.6, (0.88, 0.88)), m @ T(0, 0, -6))
    vput("Village", "bark_timber", bbox((19.5, 19.5, 1.6), 0.3), m @ T(0, 0, 44))
    for s in range(4):  # belfry openings
        a = s * math.pi / 2
        vput("Village", "bark_door", bbox((5.0, 1.2, 8.0), 0.3), m @ Matrix.Rotation(a, 4, "Z") @ T(0, -8.9, 48))
    spire = bmesh.new()
    base = [spire.verts.new((sx * 10.0, sy * 10.0, 60.0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    apex = spire.verts.new((0, 0, 98.0))
    spire.faces.new(list(reversed(base)))
    for i in range(4):
        spire.faces.new((base[i], base[(i + 1) % 4], apex))
    bmesh.ops.recalc_face_normals(spire, faces=spire.faces[:])
    vput("Village", "stone_slate", spire, m)
    vput("Village", "cloth_gold", bbox((1.6, 1.6, 7.0), 0.3), m @ T(0, 0, 97))


def well(x, z):
    y = H(x, z)
    m = Matrix.Translation(W(x, z, y))
    b = bmesh.new()
    annulus(b, 3.2, 5.2, -1.0, 4.0, 10)
    vput("Village", "stone_wall", b, m)
    for s in (-1, 1):
        vput("Village", "bark_timber", bbox((1.2, 1.2, 10.0), 0.25), m @ T(s * 4.2, 0, 3.0))
    r = bmesh.new()
    ring_prism(r, [(6.5, 12.5), (0.6, 17.0)], 4)
    vput("Village", "bark_thatch", r, m @ Matrix.Rotation(math.pi / 4, 4, "Z"))


def windmill(x, z, face_x, face_z):
    """THE landmark (owner, 2026-11-20: "a lot bigger"): about 200 studs to the top of the sails. A stone foot, a
    tapered plaster tower with a slight belly, timber bands at the joins, a gallery with a railing, a thatched
    dome with a gold finial, and four lattice sails, two of them half reefed. The sails are their own meshes
    (WindmillSails) round the hub, so the game can turn them; the hub is recorded in landmarks.json."""
    y = H(x, z)
    yaw = facing(x, z, face_x, face_z)
    # suite-1c review: still "tree-high" from the lobby, so the whole mill is built at WINDMILL_SCALE (about 400
    # studs to the sail tips); the hub in landmarks.json is scaled with it
    m = Matrix.Translation(W(x, z, y)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(WINDMILL_SCALE, 4)
    n = 12
    HT = 108.0

    def r_at(h):
        return 22.0 - 9.0 * (h / HT) + 1.6 * math.sin(math.pi * h / HT)

    b = bmesh.new()
    ring_prism(b, [(25.0, -10.0), (25.0, 12.0), (23.8, 14.0)], n)
    vput("Windmill", "stone_wall", b, m)
    t = bmesh.new()
    ring_prism(t, [(r_at(h), h) for h in (14.0, 30.0, 46.0, 62.0, 78.0, 94.0, HT)], n)
    vput("Windmill", "plaster", t, m)
    for hb in (14.0, 70.0, HT - 2.0):
        bb = bmesh.new()
        annulus(bb, r_at(hb) - 0.5, r_at(hb) + 1.2, hb, hb + 2.4, n)
        vput("Windmill", "bark_timber", bb, m)
    # the gallery: a deck on brackets and a railing
    gh = 40.0
    deck = bmesh.new()
    annulus(deck, r_at(gh) - 0.5, r_at(gh) + 7.5, gh - 1.4, gh + 0.8, n)
    vput("Windmill", "bark_timber", deck, m)
    rail = bmesh.new()
    annulus(rail, r_at(gh) + 6.6, r_at(gh) + 7.6, gh + 4.6, gh + 5.6, n)
    vput("Windmill", "bark_timber", rail, m)
    for k in range(n):
        a = (k + 0.5) / n * math.tau
        rr = r_at(gh) + 7.0
        vput("Windmill", "bark_timber", bbox((0.9, 0.9, 5.0), 0.2), m @ T(math.cos(a) * rr, math.sin(a) * rr, gh + 0.6))
    # door, windows (front and sides), the gallery door
    vput("Windmill", "bark_door", bbox((7.0, 2.0, 12.0), 0.4), m @ T(0, -24.6, 0))
    vput("Windmill", "cloth_teal", bbox((5.6, 1.4, 10.0), 0.3), m @ T(0, -25.0, 1.0))
    for h in (24.0, 56.0, 84.0):
        for a in (0.0, -0.9, 0.9):
            rr = r_at(h) - 0.2
            vput("Windmill", "bark_door", bbox((4.2, 1.6, 6.0), 0.3), m @ Matrix.Rotation(a, 4, "Z") @ T(0, -rr, h))
    # the cap: a thatched dome, a gold finial
    cap = bmesh.new()
    rt = r_at(HT)
    ring_prism(cap, [(rt + 3.0, HT - 1.0), (rt + 4.6, HT + 5.0), (rt + 3.2, HT + 14.0), (rt * 0.55, HT + 23.0), (1.2, HT + 28.0)], n)
    vput("Windmill", "bark_thatch", cap, m)
    vput("Windmill", "cloth_gold", bbox((2.0, 2.0, 8.0), 0.3), m @ T(0, 0, HT + 27.0))
    # sails, round the hub on the arena side
    # the hub stands well out from the tower on a windshaft, so the sails clear the gallery
    hub = (0.0, -34.0, HT + 6.0)
    vput("Windmill", "bark_timber", bbox((6.0, 26.0, 6.0), 0.5), m @ T(0, -21.0, HT + 3.0))
    vput("WindmillSails", "bark_timber", bbox((7.0, 8.0, 7.0), 0.5), m @ T(hub[0], hub[1], hub[2] - 3.5))
    reef = (1.0, 0.6, 1.0, 0.5)
    # thicker stocks, rails and bars, fewer bars (suite-1c review: the thin lattice would shimmer at 1,000 studs)
    for k in range(4):
        a = math.radians(30 + 90 * k)
        r = Matrix.Translation((hub[0], hub[1] - 2.0, hub[2])) @ Matrix.Rotation(-a, 4, "Y")
        vput("WindmillSails", "bark_timber", bbox((90.0, 4.4, 4.4), 0.6), m @ r @ T(45.0 + 2.0, 0, -2.2))
        for off in (4.5, 18.0):
            vput("WindmillSails", "bark_timber", bbox((70.0, 2.4, 2.4), 0.4), m @ r @ T(55.0, 0, off - 1.2))
        for q in range(7):
            vput("WindmillSails", "bark_timber", bbox((2.2, 2.2, 17.0), 0.35), m @ r @ T(21.0 + q * 10.6, 0, 1.0))
        span = 66.0 * reef[k]
        vput("WindmillSails", "cloth_cream", bbox((span, 0.6, 13.0), 0.2), m @ r @ T(21.0 + span / 2, 0.8, 4.6))
    hub_world = m @ Vector(hub)
    DATA["windmill"] = {
        "hub": [round(hub_world.x, 2), round(hub_world.z, 2), round(-hub_world.y, 2)],  # arena-local x, y, z
        "axis": [round(math.sin(yaw), 4), 0.0, round(math.cos(yaw), 4)],  # toward the arena, arena-local
        "meshes": "Map_Meadow_WindmillSails_*",
    }


# --- island details: lines laid on the ground, hedgerows, cheap far trees -----------------------------------
def resample(points, step):
    out = []
    for (ax, az), (bx, bz) in zip(points, points[1:]):
        n = max(1, int(math.hypot(bx - ax, bz - az) / step))
        for i in range(n):
            t = i / n
            out.append((ax + (bx - ax) * t, az + (bz - az) * t))
    out.append(points[-1])
    return out


def ribbon(element, material, key, points, width, lift, region="", step=10.0, piece=0):
    """A strip of the given width laid on the land along a polyline, `lift` above it; with `piece`, cut into
    meshes of that many points (a long stream must stay under 2,048 studs a mesh)."""
    pts = resample(points, step)
    if piece and len(pts) > piece:
        for k in range(0, len(pts) - 1, piece):
            ribbon(element, material, key, pts[k : k + piece + 1], width, lift, region=f"{region}{k // piece}", step=step * 100)
        return
    bm = bmesh.new()
    left, right = [], []
    for i, (x, z) in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
        dx, dz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dz) or 1.0
        px, pz = -dz / ln * width / 2, dx / ln * width / 2
        left.append(bm.verts.new(W(x + px, z + pz, H(x + px, z + pz) + lift)))
        right.append(bm.verts.new(W(x - px, z - pz, H(x - px, z - pz) + lift)))
    for i in range(len(pts) - 1):
        bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
    for f in bm.faces:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    add(element, material, key, bm, region=region)


def hedge(points, rng, closed=False, region=None):
    """A hedgerow: a rounded green bank following the land, its height wandering."""
    pts = resample(points + ([points[0]] if closed else []), 9.0)
    hs = [rng.uniform(3.8, 5.6) for _ in pts]
    for i in range(len(pts) - 1):
        (ax, az), (bx, bz) = pts[i], pts[i + 1]
        dx, dz = bx - ax, bz - az
        ln = math.hypot(dx, dz) or 1.0
        px, pz = -dz / ln, dx / ln
        bm = bmesh.new()
        ends = []
        for (x, z), h in (((ax, az), hs[i]), ((bx, bz), hs[i + 1])):
            y = H(x, z)
            ends.append([bm.verts.new(W(x + px * o, z + pz * o, y + v)) for o, v in ((-2.4, -0.8), (-2.4, h * 0.6), (-1.2, h), (1.2, h), (2.4, h * 0.6), (2.4, -0.8))])
        a, b = ends
        for k in range(5):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        for f in bm.faces:
            f.normal_update()
        add("Hedges", "Leaf", "leaf_hedge", bm, region=grp(region or region_of(ax, az)))


def far_tree(x, z, s, rng, key=None, region=None):
    """A cheap faceted tree for the far land (about 120 triangles), merged into region meshes."""
    y = H(x, z)
    reg = grp(region or region_of(x, z))
    b = bmesh.new()
    tube(b, [(0, 0, -1.0), (0.4 * s, 0, 5.0 * s), (0.6 * s, 0.3 * s, 9.0 * s)], [1.0 * s, 0.8 * s, 0.6 * s], sides=5, rng=rng)
    add("Trees", "Bark", "bark", b, Matrix.Translation(W(x, z, y)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z"), region=reg)
    key = key or rng.choice(["leaf_tree", "leaf_tree", "leaf_treedeep", "leaf_treedeep", "leaf_treegold"] if rng.random() < 0.12 else ["leaf_tree", "leaf_treedeep"])
    c = lump(5.5 * s, rng, squash=0.78, jitter=0.14, subdiv=1, flat_bottom=0.4)
    bmesh.ops.triangulate(c, faces=c.faces[:])
    add("Trees", key.split("_")[1].capitalize(), key, c, Matrix.Translation(W(x, z, y + 11.0 * s)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z"), region=reg)



def village():
    rng = random.Random(131)
    cx, cz = VC
    well(cx + 6, cz + 10)
    chapel(cx + 10, cz - 165, facing(cx + 10, cz - 165, cx, cz), rng)
    spots = []
    kinds = [
        ("bark_thatch", "plaster", "cloth_teal", 1),
        ("stone_slate", "plaster_sand", "cloth_coral", 2),
        ("bark_moss", "plaster_sage", "cloth_gold", 1),
        ("bark_thatch", "plaster_sand", "paint_sage", 1),
        ("stone_slate", "plaster", "cloth_gold", 2),
        ("bark_thatch", "plaster_sage", "cloth_coral", 1),
    ]
    for k in range(12):
        a = k / 12 * math.tau + rng.uniform(-0.12, 0.12)
        if abs(math.sin(a) + 1) < 0.25:  # leave the chapel's side open
            continue
        r = rng.uniform(115, 165)
        x, z = cx + math.cos(a) * r, cz + math.sin(a) * r * 0.8
        spots.append((x, z))
        roof, walls, accent, storeys = kinds[k % len(kinds)]
        w = rng.uniform(34, 44) if storeys == 1 else rng.uniform(28, 34)
        house(x, z, facing(x, z, cx, cz), w, rng.uniform(22, 27), rng.uniform(13, 15), rng, roof=roof, walls=walls,
              accent=accent, storeys=storeys, chimney=rng.random() < 0.85, door_side=rng.choice((-1.0, 0.0, 1.0)))
    bx, bz = cx + 225, cz - 60  # the barn: big, timber walls, a slate roof, a wide door
    house(bx, bz, facing(bx, bz, cx, cz), 64, 36, 21, rng, roof="stone_slate", walls="bark_timber", accent="bark_door", chimney=False)
    # a path from the green to the island's front edge, toward the arena
    ribbon("Path", "Soil", "soil_path", [(cx + 30, cz + 40), (cx + 45, cz + 120), (cx + 20, cz + 190), (cx + 30, cz + 222)], 8.0, 0.5)
    for _k in range(18):  # trees and flowers round the green (kit)
        a = rng.uniform(0, math.tau)
        r = rng.uniform(50, 250)
        x, z = cx + math.cos(a) * r, cz + math.sin(a) * r * 0.78
        if ((x - cx) / 285) ** 2 + ((z - cz) / 215) ** 2 > 1:
            continue
        if any(math.hypot(x - sx, z - sz) < 40 for sx, sz in spots + [(bx, bz), (cx + 10, cz - 165), (cx, cz)]):
            continue
        put(rng.choice(["Tree_A", "Tree_C", "Tree_D", "Tree_E"]), x, z, H(x, z), rng.uniform(0, 6.28), rng.uniform(2.6, 3.2))
    for _k in range(16):
        a, r = rng.uniform(0, math.tau), rng.uniform(30, 240)
        x, z = cx + math.cos(a) * r, cz + math.sin(a) * r * 0.78
        if ((x - cx) / 285) ** 2 + ((z - cz) / 215) ** 2 > 1 or any(math.hypot(x - sx, z - sz) < 26 for sx, sz in spots):
            continue
        asset = rng.choice(["Flowers_Tulip", "Flowers_Daisy_Big", "Flowers_Coral", "Flowers_Bell", "Flowers_Daisy_Small"])
        for _q in range(rng.randint(2, 4)):
            fx, fz = x + rng.uniform(-6, 6), z + rng.uniform(-6, 6)
            put(asset, fx, fz, H(fx, fz), rng.uniform(0, 6.28), rng.uniform(3.0, 4.0))
    # the windmill on its own island
    windmill(MILL[0], MILL[1], 0.0, 0.0)
    for (element, key, region), bm in VILLAGE.items():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        add(element, key.split("_")[-1].capitalize(), key, bm, region=region)
    VILLAGE.clear()


def farm():
    """The farm island: two fields of striped crops in hedgerows, bales in the wheat, a farmhouse and a barn."""
    rng = random.Random(211)
    _n, cx, cz, rx, rz = ISLE["Farm"][:5]
    for (fx, fz, fw, fd, yaw, ka, kb) in (
        (cx - 85, cz + 15, 150, 100, 0.12, "crop_wheat", "crop_furrow"),
        (cx + 95, cz - 45, 140, 90, -0.2, "crop_green", "crop_sage"),
    ):
        ux, uz = math.cos(yaw), math.sin(yaw)
        vx, vz = -uz, ux
        sw = 10.0
        for k in range(int(fd / sw)):
            v0, v1 = -fd / 2 + k * sw, -fd / 2 + (k + 1) * sw - 0.8
            key = ka if k % 2 == 0 else kb
            bm = bmesh.new()
            segs = max(2, int(fw / 15))
            row0, row1 = [], []
            for q in range(segs + 1):
                u = -fw / 2 + q * fw / segs
                for row, v in ((row0, v0), (row1, v1)):
                    px, pz = fx + u * ux + v * vx, fz + u * uz + v * vz
                    row.append(bm.verts.new(W(px, pz, H(px, pz) + 0.6)))
            for q in range(segs):
                bm.faces.new((row0[q], row0[q + 1], row1[q + 1], row1[q]))
            for f in bm.faces:
                f.normal_update()
                if f.normal.z < 0:
                    f.normal_flip()
            add("Crops", key.split("_")[1].capitalize(), key, bm, region=grp("Farm"))
        corners = [(fx + su * (fw / 2 + 4) * ux + sv * (fd / 2 + 4) * vx, fz + su * (fw / 2 + 4) * uz + sv * (fd / 2 + 4) * vz) for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        hedge(corners, rng, closed=True, region=grp("Farm"))
        for x, z in corners:
            if rng.random() < 0.75:
                put(rng.choice(["Tree_A", "Tree_C", "Tree_E"]), x, z, H(x, z), rng.uniform(0, 6.28), rng.uniform(2.4, 3.0))
        if "crop_wheat" in (ka, kb):
            for _b in range(6):
                u, v = rng.uniform(-fw * 0.4, fw * 0.4), rng.uniform(-fd * 0.4, fd * 0.4)
                px, pz = fx + u * ux + v * vx, fz + u * uz + v * vz
                b = bmesh.new()
                bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=8, radius1=3.4, radius2=3.4, depth=5.0)
                add("Crops", "Bales", "crop_hay", b, Matrix.Translation(W(px, pz, H(px, pz) + 3.0)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X"), region=grp("Farm"))
    hx, hz = cx + 20, cz + 110
    VREGION[0] = "Farm"
    house(hx, hz, facing(hx, hz, 0.0, 0.0), 36, 24, 14, rng, roof="bark_thatch", walls="plaster", accent="cloth_teal", element="Farm")
    house(hx + 85, hz - 25, facing(hx + 85, hz - 25, 0.0, 0.0) + 0.4, 54, 32, 19, rng, roof="stone_slate", walls="bark_timber", accent="bark_door", chimney=False, element="Farm")
    VREGION[0] = ""
    for (element, key, region), bm in VILLAGE.items():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        add(element, key.split("_")[-1].capitalize(), key, bm, region=region)
    VILLAGE.clear()


def groves():
    """The tree islets near the arena's sides (the kit's trees, so they sway) and the far islands' cheap trees."""
    rng = random.Random(241)
    for name in ("GroveE", "GroveW"):
        _n, cx, cz, rx, rz = ISLE[name][:5]
        for k in range(5):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(0.0, 0.55)
            x, z = cx + math.cos(a) * rx * r, cz + math.sin(a) * rz * r
            put(rng.choice(["Tree_A", "Tree_B", "Tree_C", "Tree_D", "Tree_E"]), x, z, H(x, z), rng.uniform(0, 6.28), rng.uniform(2.4, 3.0))
        for k in range(7):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(0.3, 0.8)
            x, z = cx + math.cos(a) * rx * r, cz + math.sin(a) * rz * r
            put(rng.choice(["Bush_Round", "Bush_Wide", "Bush_Low", "Flowers_Tulip", "Flowers_Daisy_Big", "Flowers_Coral"]), x, z, H(x, z), rng.uniform(0, 6.28), rng.uniform(2.0, 2.6))
    for name in ("FarNE", "FarNW", "FarN"):
        _n, cx, cz, rx, rz = ISLE[name][:5]
        for k in range(rng.randint(7, 11)):
            a = rng.uniform(0, math.tau)
            r = math.sqrt(rng.uniform(0.0, 0.6))
            far_tree(cx + math.cos(a) * rx * r, cz + math.sin(a) * rz * r, rng.uniform(2.8, 3.8), rng, region=name)
    VREGION[0] = "FarN"
    _n, cx, cz = ISLE["FarN"][:3]
    house(cx + 40, cz + 50, facing(cx + 40, cz + 50, 0.0, 0.0), 34, 22, 13, rng, roof="bark_moss", walls="plaster", accent="cloth_gold", element="FarHouse")
    VREGION[0] = ""
    for (element, key, region), bm in VILLAGE.items():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        add(element, key.split("_")[-1].capitalize(), key, bm, region=region)
    VILLAGE.clear()


# --- STUD FLOWERS on the floor (owner 2026-11-22: "maybe add like studlike flowers"; "make proportions of the flowers
# SMALL, like ... an actual flower compared to a human in real life ... slightly below the roblox character's ankle").
# A fighter is 5 studs tall, its ankle about 0.45 up: nothing here is taller than 0.42. Little builds of 0.14-stud
# blocks on a 0.14 grid (Raise a Fairy's Map Style: blocks stick out only where they add shape), sown in drifts of one
# colour so they read from the camera, never on the dirt. The approved mock's own layout (floor_mock.py, seed 404).
# They replace the old style's grass blades (38.6k triangles); the same budget, cheaper to draw:
#   - ONE small palette image for every flower (8 colours, a stud printed on each block face), so a mesh is one draw;
#   - two layers, each in 2 x 2 tiles so the camera culls what is behind it: A (phones keep it) holds FLOWER_SHARE_A of
#     the flowers, B the rest (MapEnvironments phoneHide "_FloorFlowers_B_"); no shadows (studio_map.py);
#   - faces nobody can see are left out (a block's underside, a stem's top under its bloom).
FLOWER_U = 0.14  # one flower block, studs
FLOWER_SHARE_A = 0.4
LEAF, LEAF_LIT, LEAF_DEEP = (70, 160, 74), (132, 206, 96), (52, 128, 66)
BLOOMS = [(255, 255, 255), (255, 150, 190), (255, 220, 92), (190, 150, 250)]
YOLK = (255, 206, 60)
FLOWER_PALETTE = [LEAF, LEAF_LIT, LEAF_DEEP, YOLK] + BLOOMS  # 4 x 2 cells of 64 px
FLOWER_SPOTS = 150  # drifts


def _stud_factor(px):
    """The owner's stud texture as the mock used it: one square, px x px, the factor on a colour
    (0.45 + 0.55 x texture / 128), rows bottom-up."""
    img = bpy.data.images.load(STUD_SOURCE, check_existing=True)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    g = buf.reshape(h, w, 4)[..., 0].astype(np.float64) * 255.0
    one = g.reshape(8, h // 8, 8, w // 8).transpose(0, 2, 1, 3).reshape(64, h // 8, w // 8).mean(axis=0)
    k = one.shape[0] // px
    return 0.45 + 0.55 * one.reshape(px, k, px, k).mean(axis=(1, 3)) / 128.0


def _flower_palette(path):
    """256 x 128: a 64 px cell per colour, the colour everywhere and one stud printed in the cell's middle 32 px,
    which is all a block face shows (the 16 px of plain colour round it keep the next cell out of the small mips)."""
    f = _stud_factor(32)
    img = np.zeros((128, 256, 3))
    for k, rgb in enumerate(FLOWER_PALETTE):
        cx, cy = k % 4, k // 4
        cell = np.broadcast_to(P.rgb(*rgb), (64, 64, 3)).copy()
        cell[16:48, 16:48] = cell[16:48, 16:48] * f[..., None]
        img[cy * 64 : cy * 64 + 64, cx * 64 : cx * 64 + 64] = cell
    P.save_png(path, np.clip(img, 0, 1))


def floor_flowers():
    rng = random.Random(404)  # the mock's seed and order of draws: the layout the owner approved
    lay = random.Random(77)  # which layer a flower goes to (its own stream, so the layout above never changes)
    U = FLOWER_U
    mat = None
    if not DRY:
        path = os.path.join(TEX, f"Map_{NAME}_FloorFlowers_Color.png")
        _flower_palette(path)
        mat = S.image_material(f"Map_{NAME}_FloorFlowers_Painted", {"colour": path}, roughness=0.9)
    bags = {}  # (layer, tile) -> (bmesh, uv layer)
    here = [None]  # the bag the flower being built goes into

    def cube(rgb, x, y, z, s=U, h=None, top=True):
        """A block whose corner is at (x, y, z); no underside (it sits on the floor or on a block)."""
        bm, uvl = here[0]
        h = s if h is None else h
        k = FLOWER_PALETTE.index(rgb)
        u0, v0 = (k % 4 * 64 + 16) / 256.0, (k // 4 * 64 + 16) / 128.0
        uvs = ((u0, v0), (u0 + 0.125, v0), (u0 + 0.125, v0 + 0.25), (u0, v0 + 0.25))
        vs = [bm.verts.new((x + dx * s, y + dy * s, z + dz * h)) for dz in (0, 1) for dx, dy in ((0, 0), (1, 0), (1, 1), (0, 1))]
        for f in ((0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)) + (((4, 5, 6, 7),) if top else ()):  # wound to face out
            face = bm.faces.new([vs[q] for q in f])
            for lp, uv in zip(face.loops, uvs):
                lp[uvl].uv = uv

    def tulip(x, y, bloom):  # a stem of one or two blocks, a bloom block: 0.28 to 0.42 tall
        hgt = rng.choice((1, 1, 2))
        cube(LEAF, x, y, 0.0, h=U * hgt, top=False)
        cube(bloom, x, y, U * hgt)

    def daisy(x, y, bloom):  # a flat 2 x 2 of petals, a yolk block in the middle: 0.2 tall
        cube(bloom, x - U / 2, y - U / 2, 0.0, s=U * 2, h=U * 0.5)
        cube(YOLK, x, y, U * 0.5)

    def tuft(x, y, _bloom):  # two or three blades of grass
        for dx, dy in rng.sample([(0, 0), (1, 0), (0, 1), (-1, 0)], rng.randint(2, 3)):
            cube(rng.choice((LEAF, LEAF_LIT, LEAF_DEEP)), x + dx * U, y + dy * U, 0.0, h=U * rng.choice((1, 2, 2.6)))

    def snap(v):
        return round(v / U) * U

    # the mock's first drift stood at its close-up fighter's feet (the nearest clear ground to (34, -58)): kept, so
    # the draws and so the whole layout match the picture he approved
    show = min(((float(DIRT_X[i, j]), float(DIRT_Y[i, j])) for i in range(DIRT_X.shape[0]) for j in range(DIRT_X.shape[1])
                if DIRT_RAD[i, j] < 120 and not DIRT_MASK[max(0, i - 4):i + 5, max(0, j - 4):j + 5].any()),
               key=lambda q: math.hypot(q[0] - 34.0, q[1] + 58.0))
    DATA["flower_show"] = [round(show[0], 2), round(show[1], 2)]  # Blender x, y: the review's close-up stands here
    spots = [(show[0] + 1.2, show[1] + 1.0)] * 3 + [(22.0, 12.0), (-26.0, -2.0)]
    for _c in range(FLOWER_SPOTS):
        a, r = rng.uniform(0, math.tau), RADIUS * math.sqrt(rng.uniform(0.01, 0.92))
        spots.append((math.cos(a) * r, math.sin(a) * r))
    count = {"A": 0, "B": 0}
    for cx, cy in spots:
        bloom = rng.choice(BLOOMS)
        spread = 1.6 if (cx, cy) == spots[0] else rng.uniform(2.0, 5.0)
        for _f in range(rng.randint(9, 20)):
            x, y = snap(cx + rng.gauss(0, spread)), snap(cy + rng.gauss(0, spread))
            if math.hypot(x, y) > RADIUS - 4 or on_dirt(x, y):
                continue
            layer = "A" if lay.random() < FLOWER_SHARE_A else "B"
            key = (layer, f"{1 if x < 0 else 2}{1 if -y < 0 else 2}")  # tiles by arena-local x and z (z = -y)
            # in or at the pond (or on a cell the pond turned to dirt): drawn all the same, so every other flower keeps
            # its place in the approved layout, then thrown away
            gone = POND_ON and (float(pond_rho(x, y)) < 1.08 or on_floor_dirt(x, y))
            if gone:
                key = ("gone", "")
            if key not in bags:
                bm = bmesh.new()
                bags[key] = (bm, bm.loops.layers.uv.new("UVMap"))
            here[0] = bags[key]
            rng.choices((tulip, daisy, tuft), weights=(4, 4, 3))[0](x, y, bloom if rng.random() < 0.85 else rng.choice(BLOOMS))
            if gone:
                count["gone"] = count.get("gone", 0) + 1
                continue
            count[layer] += 1
    made = {"A": 0, "B": 0}
    tallest = 0.0
    for (layer, tile), (bm, _uvl) in sorted(bags.items()):
        if layer == "gone":
            bm.free()
            continue
        tallest = max(tallest, max(v.co.z for v in bm.verts))
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        obj = make(f"Map_{NAME}_FloorFlowers", f"{layer}_{tile}", "leaf_lip", bm, "Map")
        if obj is None:
            continue
        if mat is not None:
            obj.data.materials.append(mat)
            PAINTED.append(obj)
        made[layer] += len(obj.data.polygons)
    assert tallest <= 0.42 + 1e-6, f"a flower is {tallest} studs tall: over the ankle"
    print("FLOOR FLOWERS", count, "flowers;", made, "triangles;", len(bags), "meshes; tallest", round(tallest, 3), flush=True)


# --- packing the islands (fix round 2026-11-22, owner: "make sure the islands are kinda packed with stuff so it adds
# detail, and makes it so players fighting can catch a glimpse of the amount of detail") -----------------------------
# Everything here is big enough to read at 700-1,300 studs (houses 25-45 studs, trees about 35, haystacks 12): the
# kit's 1-10 stud pieces are specks at that range. Cheap merged meshes (far_tree, haystacks, hedges), houses through
# house() so each island's houses are a handful of meshes (region = the island).
def haystack(x, z, s, rng, region):
    y = H(x, z)
    b = bmesh.new()
    ring_prism(b, [(5.5 * s, -1.0), (6.0 * s, 5.0 * s), (4.6 * s, 8.5 * s), (0.8 * s, 12.0 * s)], 9)
    add("Crops", "Hay", "crop_hay", b, Matrix.Translation(W(x, z, y)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z"), region=grp(region))


def dovecote(x, z, rng, region):
    """A tall round dovecote: a stone drum, a plaster upper with rows of holes (dark bands), a conical slate cap."""
    y = H(x, z)
    m = Matrix.Translation(W(x, z, y))
    vput("Village", "stone_wall", (lambda b: (ring_prism(b, [(13.0, -6.0), (12.5, 18.0)], 12), b)[1])(bmesh.new()), m, region=region)
    vput("Village", "plaster_sand", (lambda b: (ring_prism(b, [(11.5, 18.0), (10.5, 52.0)], 12), b)[1])(bmesh.new()), m, region=region)
    for hb in (26.0, 34.0, 42.0):
        bb = bmesh.new()
        annulus(bb, 10.6, 11.6, hb, hb + 2.2, 12)
        vput("Village", "bark_door", bb, m, region=region)
    cap = bmesh.new()
    ring_prism(cap, [(14.0, 51.0), (13.0, 54.0), (1.0, 80.0)], 12)
    vput("Village", "stone_slate", cap, m, region=region)
    vput("Village", "cloth_gold", bbox((1.6, 1.6, 6.0), 0.3), m @ T(0, 0, 79.0), region=region)


def spots_on(isl, count, rng, inner=0.0, outer=0.78, gap=30.0, taken=None):
    """Up to `count` points on an island's top between `inner` and `outer` of its size, `gap` studs apart."""
    _n, cx, cz, rx, rz = isl[:5]
    taken = taken if taken is not None else []
    out = []
    for _try in range(count * 30):
        if len(out) >= count:
            break
        a, r = rng.uniform(0, math.tau), math.sqrt(rng.uniform(inner * inner, outer * outer))
        x, z = cx + math.cos(a) * rx * r, cz + math.sin(a) * rz * r
        if any(math.hypot(x - tx, z - tz) < gap for tx, tz in taken + out):
            continue
        out.append((x, z))
    taken.extend(out)
    return out


HOUSE_KINDS = [
    ("bark_thatch", "plaster", "cloth_teal", 1),
    ("stone_slate", "plaster_sand", "cloth_coral", 2),
    ("bark_moss", "plaster_sage", "cloth_gold", 1),
    ("bark_thatch", "plaster_sand", "paint_sage", 1),
    ("stone_slate", "plaster", "cloth_gold", 2),
    ("bark_thatch", "plaster_sage", "cloth_coral", 1),
]


def hamlet(isl, houses, trees, rng, taken, inner=0.0, outer=0.7, small=False, element="Village"):
    """Houses facing the island's middle, gardens of trees between them."""
    _n, cx, cz = isl[:3]
    VREGION[0] = isl[0]
    for k, (x, z) in enumerate(spots_on(isl, houses, rng, inner, outer, 46.0 if not small else 38.0, taken)):
        roof, walls, accent, storeys = HOUSE_KINDS[(k + len(taken)) % len(HOUSE_KINDS)]
        w = rng.uniform(26, 34) if small else (rng.uniform(32, 40) if storeys == 1 else rng.uniform(26, 32))
        house(x, z, facing(x, z, cx, cz) + rng.uniform(-0.3, 0.3), w, rng.uniform(20, 25), rng.uniform(12, 14), rng,
              roof=roof, walls=walls, accent=accent, storeys=storeys, chimney=rng.random() < 0.8,
              door_side=rng.choice((-1.0, 0.0, 1.0)), element=element)
    VREGION[0] = ""
    for x, z in spots_on(isl, trees, rng, 0.0, 0.88, 16.0, taken):
        far_tree(x, z, rng.uniform(2.6, 3.6), rng, region=isl[0])


def pack():
    rng = random.Random(331)
    taken = {name: [] for name in ISLE}
    # the village: a second, looser ring of cottages out to the island's edge, trees in every garden
    v = ISLE["Village"]
    taken["Village"] += [(VC[0], VC[1]), (VC[0] + 10, VC[1] - 165), (VC[0] + 225, VC[1] - 60)]
    for a in range(12):  # keep the first ring's houses and the green clear
        taken["Village"].append((VC[0] + math.cos(a / 12 * math.tau) * 140, VC[1] + math.sin(a / 12 * math.tau) * 112))
    hamlet(v, 9, 26, rng, taken["Village"], inner=0.72, outer=0.9, small=True)
    # the mill's island: the miller's house, a barn, haystacks, trees
    m = ISLE["Mill"]
    taken["Mill"].append(MILL)
    taken["Mill"].append((MILL[0], MILL[1]))
    hamlet(m, 2, 9, rng, taken["Mill"], inner=0.45, outer=0.75)
    for x, z in spots_on(m, 4, rng, 0.4, 0.8, 18.0, taken["Mill"]):
        haystack(x, z, rng.uniform(0.9, 1.2), rng, "Mill")
    # the farm: cottages, haystacks across the fields' edges, an orchard row
    f = ISLE["Farm"]
    taken["Farm"] += [(f[1] - 85, f[2] + 15), (f[1] + 95, f[2] - 45), (f[1] + 20, f[2] + 110), (f[1] + 105, f[2] + 85)]
    hamlet(f, 3, 14, rng, taken["Farm"], inner=0.55, outer=0.85, small=True)
    for x, z in spots_on(f, 7, rng, 0.5, 0.88, 16.0, taken["Farm"]):
        haystack(x, z, rng.uniform(0.9, 1.3), rng, "Farm")
    # the groves: a woodcutter's hut each and denser woods
    for name in ("GroveE", "GroveW"):
        hamlet(ISLE[name], 1, 10, rng, taken[name], inner=0.2, outer=0.6, small=True)
    # NEW: the orchard (east): rows of fruit trees, a cider barn, beehive stacks (haystacks' shape, gold)
    o = ISLE["Orchard"]
    _n, cx, cz, rx, rz = o[:5]
    for i in range(-6, 7):
        for j in range(-4, 5):
            x, z = cx + i * 26 + (13 if j % 2 else 0), cz + j * 24
            if ((x - cx) / (rx * 0.82)) ** 2 + ((z - cz) / (rz * 0.82)) ** 2 > 1 or math.hypot(x - (cx + 40), z - (cz - 20)) < 45:
                continue
            far_tree(x, z, rng.uniform(2.2, 2.8), rng, key=rng.choice(["leaf_tree", "leaf_treegold", "leaf_tree"]), region="Orchard")
    VREGION[0] = "Orchard"
    house(cx + 40, cz - 20, facing(cx + 40, cz - 20, 0.0, 0.0), 50, 30, 18, rng, roof="stone_slate", walls="bark_timber",
          accent="bark_door", chimney=False, element="Village")
    VREGION[0] = ""
    # NEW: the hamlet (west): a small village round a well
    hm = ISLE["Hamlet"]
    well(hm[1], hm[2])
    taken["Hamlet"].append((hm[1], hm[2]))
    hamlet(hm, 8, 22, rng, taken["Hamlet"], inner=0.3, outer=0.8)
    # NEW: the pasture (the lobby's east flank): hedged paddocks, a hay barn, haystacks
    p = ISLE["Pasture"]
    _n, cx, cz, rx, rz = p[:5]
    for (ox, oz, w, d) in ((-50, -20, 90, 70), (55, 25, 80, 60)):
        hedge([(cx + ox - w / 2, cz + oz - d / 2), (cx + ox + w / 2, cz + oz - d / 2), (cx + ox + w / 2, cz + oz + d / 2), (cx + ox - w / 2, cz + oz + d / 2)], rng, closed=True, region="Pasture")
    VREGION[0] = "Pasture"
    house(cx + 70, cz - 55, facing(cx + 70, cz - 55, 0.0, 0.0), 44, 28, 16, rng, roof="bark_thatch", walls="bark_timber",
          accent="bark_door", chimney=False, element="Village")
    VREGION[0] = ""
    taken["Pasture"] += [(cx + 70, cz - 55)]
    for x, z in spots_on(p, 6, rng, 0.0, 0.8, 18.0, taken["Pasture"]):
        haystack(x, z, rng.uniform(0.9, 1.3), rng, "Pasture")
    for x, z in spots_on(p, 10, rng, 0.6, 0.9, 16.0, taken["Pasture"]):
        far_tree(x, z, rng.uniform(2.6, 3.4), rng, region="Pasture")
    # NEW: the dovecote (the lobby's west flank): a tall dovecote, a cottage, a walled garden of trees
    dc = ISLE["Dovecote"]
    dovecote(dc[1], dc[2], rng, "Dovecote")
    taken["Dovecote"].append((dc[1], dc[2]))
    hamlet(dc, 2, 14, rng, taken["Dovecote"], inner=0.35, outer=0.75)
    # the far islands: a cluster of houses each among their trees
    for name in ("FarNE", "FarNW", "FarN"):
        hamlet(ISLE[name], 4, 0, rng, taken[name], inner=0.0, outer=0.6, small=True, element="FarHouse")
    for (element, key, region), bm in VILLAGE.items():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        add(element, key.split("_")[-1].capitalize(), key, bm, region=region)
    VILLAGE.clear()


def meadow_cameras():
    """The standard views, a fighter's eye in all four directions (the owner's rule: no empty arc of sky), and the new
    floor up close: behind a fighter, at the ankle beside a flower drift, and straight down."""
    cams = standard_cameras()
    for name, (tx, tz) in (("LookN", (0, -900)), ("LookE", (900, 0)), ("LookS", (0, 900)), ("LookW", (-900, 0))):
        cams[name] = C.camera(name, W(0, 0, 14.0), W(tx, tz, 40.0), lens=22)
    sx, sy = DATA.get("flower_show", (34.0, -58.0))
    cams["Play"] = C.camera("Play", (3, -66, 12.5), (0, 60, 8.0), lens=20)
    cams["Ankle"] = C.camera("Ankle", (sx + 5.5, sy - 6.0, 1.5), (sx + 0.6, sy + 0.6, 0.75), lens=30)
    cams["Feet"] = C.camera("Feet", (16, -64, 6.0), (-4, -40, 1.0), lens=28)
    cams["Top"] = C.camera("Top", (0, -1, 2.9 * RADIUS), (0, 0, 0), lens=28)
    if POND_ON:  # the pond sheet's three views
        cams["PondFight"] = C.camera("PondFight", (6.0, -46.0, 9.5), (0.0, 4.0, -0.5), lens=24)
        cams["PondWade"] = C.camera("PondWade", (-6.0, -21.0, 4.8), (4.0, 3.0, -0.4), lens=26)
        cams["PondOver"] = C.camera("PondOver", (62.0, -88.0, 70.0), (0.0, 0.0, -1.0), lens=30)
    return cams


# --- the review scene: the game's stud look on the floor (in the game a Texture; here the owner's texture printed by
# the material), a few fighters for scale, and in a --near build the islands of the earlier full build -------------
def _stud_material(name, rgb, studs_per_square=1.0):
    """The approved mock's floor material: the flat colour x (0.45 + 0.55 x the stud texture / mid grey)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.9
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    k = 1.0 / (8.0 * studs_per_square)  # the image holds 8 x 8 squares
    mp.inputs["Scale"].default_value = (k, k, k)
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(STUD_SOURCE, check_existing=True)
    img.image.colorspace_settings.name = "Non-Color"
    img.extension = "REPEAT"
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY_ADD"
    mul.inputs[1].default_value = 0.55 / (128.0 / 255.0)
    mul.inputs[2].default_value = 0.45
    sc = nt.nodes.new("ShaderNodeVectorMath")
    sc.operation = "SCALE"
    sc.inputs[0].default_value = tuple((c / 255.0) ** 2.2 for c in rgb)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], img.inputs["Vector"])
    nt.links.new(img.outputs["Color"], mul.inputs[0])
    nt.links.new(mul.outputs[0], sc.inputs["Scale"])
    nt.links.new(sc.outputs["Vector"], p.inputs["Base Color"])
    return m


def _fighter(x, y, shirt, face, z=0.0):
    ink, skin, top = flat_material("fighter", (30, 32, 46)), flat_material("fighter", (240, 200, 160)), flat_material("fighter", shirt)
    col = preview_collection()
    for size, off, m in (((0.95, 0.95, 2.0), (-0.5, 0, 1.0), ink), ((0.95, 0.95, 2.0), (0.5, 0, 1.0), ink), ((2.0, 1.0, 2.0), (0, 0, 3.0), top),
                         ((0.95, 0.95, 2.0), (-1.5, 0, 3.0), top), ((0.95, 0.95, 2.0), (1.5, 0, 3.0), top), ((1.25, 1.25, 1.25), (0, 0, 4.65), skin)):
        b = bmesh.new()
        bmesh.ops.create_cube(b, size=1.0)
        me = bpy.data.meshes.new("fighter")
        b.to_mesh(me)
        b.free()
        me.materials.append(m)
        o = bpy.data.objects.new("PreviewFighter", me)
        col.objects.link(o)
        v = Matrix.Rotation(face, 4, "Z") @ Vector(off)
        o.matrix_world = Matrix.Translation((x + v.x, y + v.y, z + v.z)) @ Matrix.Rotation(face, 4, "Z") @ Matrix.Diagonal((*size, 1.0))


_base_add_lobby = add_lobby


def add_lobby():
    """base.run calls this once the export is written, just before the review renders."""
    if not DRY:
        for obj, rgb in ((bpy.data.objects.get(f"Map_{NAME}_Floor_Grass"), GRASS), (bpy.data.objects.get(f"Map_{NAME}_Floor_Dirt"), DIRT)):
            if obj is not None:
                obj.data.materials.clear()
                obj.data.materials.append(_stud_material(obj.name + "_Studs", rgb))
        for (x, y, shirt, face) in ((0, -46, (52, 96, 214), 0.0), (-22, -6, (238, 96, 92), 2.6), (26, 8, (250, 206, 70), -2.2), (-66, 52, (60, 196, 200), 1.0),
                                    (80, 40, (190, 150, 240), 3.6), (8, 92, (246, 146, 70), 0.3)):
            _fighter(x, y, shirt, face)
        sx, sy = DATA.get("flower_show", (34.0, -58.0))
        _fighter(sx, sy, (60, 170, 90), 0.5)
        if POND_ON:  # the pond's studded shore and bed, the water as on the sheet (80% opaque), someone wading
            for part, rgb in (("PondShore", POND_SAND), ("PondBed", POND_WET)):
                obj = bpy.data.objects.get(f"Map_{NAME}_Floor_{part}")
                if obj is not None:
                    obj.data.materials.clear()
                    obj.data.materials.append(_stud_material(obj.name + "_Studs", rgb))
            water = bpy.data.objects.get(f"Map_{NAME}_Pond_Water")
            if water is not None:
                bsdf = water.data.materials[0].node_tree.nodes["Principled BSDF"]
                bsdf.inputs["Alpha"].default_value = 1.0 - POND_WATER_CLEAR
                bsdf.inputs["Roughness"].default_value = 0.35
            _fighter(*POND_WADE, (52, 96, 214), 2.4, z=-float(pond_bed(*POND_WADE)))
    if NEAR_ONLY:
        build = os.path.join(MAPS, "out", "suite", ISLANDS_FROM)
        col = preview_collection()
        skip = ("_Floor_", "_Lip_", f"Map_{NAME}_Soil_", "_Crag_", "_Core_", "_FieldGrass_", "_FloorFlowers_")
        for f in sorted(os.listdir(os.path.join(build, "export"))):
            if f.endswith(".glb"):
                for o in _import_glb(os.path.join(build, "export", f), col):
                    if any(k in o.name for k in skip):
                        bpy.data.objects.remove(o, do_unlink=True)
        PLACE.extend(json.load(open(os.path.join(build, "placements.json"), encoding="utf-8")))  # for the renders only
    _base_add_lobby()


BUILDERS = [surface, edge, crag, pond, floor_flowers] if NEAR_ONLY else [surface, edge, crag, pond, islands, village, farm, groves, pack, floor_flowers]
run(NAME, BUILDERS, cameras=meadow_cameras)
