"""The cliffside courtyard lobby (user brief 2026-11-13), built by script in Blender 5.2 with Gnomon's scenery
kit: the same chunk / block / canopy builders and the same baked paint (props_kit.py), so every new piece
belongs to the collection the first map's rocks, ruins and trees come from. New palette: warm limestone,
honey timber, terracotta, teal, coral and gold, under golden-hour light.

    blender -b --factory-startup -P cliffside.py -- <out folder> [--fast] [--no-render]

CONCEPT "Stepped Overlook": three terraces stepping DOWN toward the arena, so every level sees over the one in
front. From the arena backward: the viewing balcony, three steps up to the court (spawn, shop stall, great
tree), three more to the training terrace under a timber gate. The crag under it tapers like Gnomon's island.

AXES: lobby-local. u across (Roblox +X), d back from the viewing edge (Roblox +Z), h above the lobby floor
(GameConfig.Lobby.FloorY). In Blender x = u, y = -d (so +Y points at the arena), z = h; the origin is the
middle of the viewing edge at floor level. 1 unit = 1 stud. Sizes come from design/game.json -> config.Lobby.

WRITES into <out>: cliffside.blend, textures/, export/cliffside_<n>.glb (each under 20 MB), manifest.json
(every mesh's expected centre in lobby-local Roblox axes, to align the import), collision.json (boxes,
wedges and cylinders; also generated into src/shared/Config/LobbyLayout.luau), placements.json (pieces of the
existing kit, ServerStorage.HT_PropKit, cloned by the Studio script), and review renders.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.join(HERE, "..", "maps")
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, MAPS)
os.environ.setdefault("HT_MAP", "gnomon")

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = os.path.abspath(next((a for a in ARGS if not a.startswith("--")), os.path.join(HERE, "out", "cliffside")))
NO_RENDER = "--no-render" in ARGS
DRY = "--dry" in ARGS  # geometry and numbers only: no paint, no export, a quick solid-colour look

# The kit's builders and painter, without running its own build (its last line is main()).
_src = open(os.path.join(MAPS, "props_kit.py"), encoding="utf-8").read()
_src = _src[: _src.rindex("\nmain()")]
K = {"__name__": "props_kit", "__file__": os.path.join(MAPS, "props_kit.py")}
exec(compile(_src, os.path.join(MAPS, "props_kit.py"), "exec"), K)
chunk, block, tube, canopy_mass, lump, append, make, srgb = (K[n] for n in ("chunk", "block", "tube", "canopy_mass", "lump", "append", "make", "srgb"))
C, PAL, REGISTRY = K["C"], K["PAL"], K["REGISTRY"]

# feel_of() picks the treatment from the key's prefix: stone*, bark*, leaf*, anything else is "flat".
PAL.update(
    {
        "stone_pave": (srgb(222, 204, 172), srgb(248, 236, 208), srgb(146, 126, 110)),
        "stone_trim": (srgb(232, 220, 196), srgb(252, 244, 222), srgb(150, 136, 124)),
        "stone_clay": (srgb(198, 112, 78), srgb(232, 156, 112), srgb(128, 66, 58)),
        "stone_teal": (srgb(70, 150, 146), srgb(128, 198, 188), srgb(40, 94, 104)),
        "bark_timber": (srgb(176, 124, 72), srgb(222, 172, 108), srgb(104, 66, 48)),
        "bark_gate": (srgb(204, 86, 62), srgb(240, 138, 100), srgb(132, 48, 50)),
        "leaf_gold": (srgb(232, 158, 56), srgb(252, 210, 112), srgb(178, 94, 46)),
        "cloth_coral": (srgb(236, 112, 86), srgb(252, 164, 130), srgb(172, 66, 64)),
        "cloth_gold": (srgb(238, 180, 62), srgb(255, 220, 120), srgb(184, 118, 40)),
        "cloth_cream": (srgb(244, 232, 204), srgb(255, 248, 228), srgb(186, 168, 150)),
        "cloth_teal": (srgb(64, 150, 146), srgb(120, 196, 186), srgb(38, 96, 104)),
        "soil": (srgb(108, 80, 58), srgb(150, 116, 84), srgb(66, 46, 40)),
        "paper": (srgb(255, 226, 156), srgb(255, 244, 204), srgb(226, 170, 96)),
    }
)

cfg = json.load(open(os.path.join(PROJECT, "design", "game.json"), encoding="utf-8"))["config"]["Lobby"]
W, D = float(cfg["Width"]), float(cfg["Depth"])
HX = W / 2
TERRACES = [(float(t["Start"]), float(t["Rise"])) for t in cfg["Terraces"]]
RUN, LEAD = float(cfg["StairRun"]), float(cfg["StairLead"])
TRAIN = D - float(cfg["TrainingDepth"])
(COURT_D, COURT_H), (TRAIN_D, TRAIN_H) = TERRACES
assert abs(TRAIN_D - TRAIN) < 1e-6, "the training terrace must start on the training line"
SPAWN_D = float(cfg["SpawnZ"]) - float(cfg["ViewEdgeZ"])

COLLISION = []  # {"kind": "box"|"wedge"|"cyl", ...} in u, d, h
PLACE = []  # {"asset", "u", "d", "h", "yaw", "scale"}: the existing kit's pieces


def height_at(d):
    """The walking height at depth d: the same rule as Core/Lobby.heightAt."""
    h, prev = 0.0, 0.0
    for start, rise in TERRACES:
        a, b = start - LEAD - RUN, start - LEAD
        if d >= b:
            h = rise
        elif d > a:
            h = prev + (rise - prev) * (d - a) / (b - a)
        prev = rise
    return h


def at(u, d, h=0.0):
    return Vector((u, -d, h))


def T(u, d, h=0.0, yaw=0.0):
    return Matrix.Translation(at(u, d, h)) @ Matrix.Rotation(yaw, 4, "Z")


def box_c(u0, u1, d0, d1, h0, h1):
    COLLISION.append({"kind": "box", "u0": u0, "u1": u1, "d0": d0, "d1": d1, "h0": h0, "h1": h1})


def cyl_c(u, d, r, h0, h1):
    COLLISION.append({"kind": "cyl", "u": u, "d": d, "r": r, "h0": h0, "h1": h1})


def put(asset, u, d, h, yaw=0.0, scale=1.0):
    PLACE.append({"asset": asset, "u": round(u, 2), "d": round(d, 2), "h": round(h, 2), "yaw": round(yaw, 3), "scale": scale})


def plain_box(bm, u0, u1, d0, d1, h0, h1):
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1.0)
    for v in b.verts:
        v.co = Vector(((u0 + u1) / 2 + v.co.x * (u1 - u0), -((d0 + d1) / 2) + v.co.y * (d1 - d0), (h0 + h1) / 2 + v.co.z * (h1 - h0)))
    bmesh.ops.triangulate(b, faces=b.faces[:])
    append(bm, b)


def brick(size, rng):
    """A plain cut block for walls seen from a distance: a slightly uneven box with one chamfer (44 triangles;
    the kit's block() is about 250)."""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz + sz / 2))
        v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.035 * min(sx, sy, sz)
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.09 * min(sx, sy, sz), segments=1, affect="EDGES", clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


# --- paving: flagstones in running bond, each its own facet so the painter gives each its own tone ----------
def flags(bm, u0, u1, d0, d1, h, rng, row=5.5, wmin=5.0, wmax=9.0, gap=0.14, bev=0.16, thick=0.5):
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
            low = [bm.verts.new((px, py, top - thick)) for px, py in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
            mid = [bm.verts.new((px, py, top - bev)) for px, py in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
            up = [bm.verts.new((px, py, top)) for px, py in ((x0 + bev, y0 + bev), (x1 - bev, y0 + bev), (x1 - bev, y1 - bev), (x0 + bev, y1 - bev))]
            for i in range(4):
                j = (i + 1) % 4
                bm.faces.new((low[i], low[j], mid[j], mid[i]))
                bm.faces.new((mid[i], mid[j], up[j], up[i]))
            bm.faces.new(up)
            x += w


def paving():
    rng = random.Random(11)
    # up to each flight's first step, and on from just behind its last
    for name, d0, d1, h in (("Balcony", 0.0, COURT_D - RUN, 0.0), ("Court", COURT_D + 0.45, TRAIN_D - RUN, COURT_H), ("Training", TRAIN_D + 0.45, D, TRAIN_H)):
        bm = bmesh.new()
        flags(bm, -HX, HX, d0, d1, h, rng)
        make(f"Lobby_Paving_{name}", "Stone", "stone_pave", bm, "Lobby")
    # the spawn medallion: two rings of wedge tiles and a hub, laid a hair proud of the flagstones
    clay, teal, trim = bmesh.new(), bmesh.new(), bmesh.new()

    def ring(bm_of, r0, r1, n, phase=0.0, h=COURT_H + 0.05):
        for i in range(n):
            t0, t1 = phase + i / n * math.tau, phase + (i + 1) / n * math.tau
            g = 0.012
            pts = [(r0, t0 + g), (r1, t0 + g * r0 / r1), (r1, t1 - g * r0 / r1), (r0, t1 - g)]
            target = bm_of(i)
            lo = [target.verts.new(at(math.cos(t) * r, SPAWN_D + math.sin(t) * r, h - 0.3)) for r, t in pts]
            hi = [target.verts.new(at(math.cos(t) * r, SPAWN_D + math.sin(t) * r, h)) for r, t in pts]
            for k in range(4):
                j = (k + 1) % 4
                target.faces.new((lo[k], lo[j], hi[j], hi[k]))
            target.faces.new(hi)

    ring(lambda i: trim, 0.5, 3.2, 8)
    ring(lambda i: teal if i % 2 == 0 else trim, 3.4, 7.6, 12, 0.13)
    ring(lambda i: clay if i % 2 == 0 else teal, 7.8, 11.2, 20)
    ring(lambda i: trim, 11.4, 12.6, 28, 0.05)
    for bm in (clay, teal, trim):  # the wedge tiles were wound either way round the ring
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    make("Lobby_Medallion", "Clay", "stone_clay", clay, "Lobby")
    make("Lobby_Medallion", "Teal", "stone_teal", teal, "Lobby")
    make("Lobby_Medallion", "Trim", "stone_trim", trim, "Lobby")
    # the training mat: the old lobby's sea-green canvas with a cream border
    mat, border = bmesh.new(), bmesh.new()
    plain_box(border, -50, 50, TRAIN_D + 4, D - 5, TRAIN_H - 0.2, TRAIN_H + 0.06)
    plain_box(mat, -48.4, 48.4, TRAIN_D + 5.6, D - 6.6, TRAIN_H - 0.2, TRAIN_H + 0.1)
    make("Lobby_Mat", "Border", "cloth_cream", border, "Lobby")
    make("Lobby_Mat", "Canvas", "cloth_teal", mat, "Lobby")


# --- steps: three courses of long blocks a flight, between planters at both ends --------------------------------
STEP_HALF = 46.0  # the flights run between u = -46 and 46; planters fill the rest of the width


def stairs_and_planters():
    rng = random.Random(23)
    steps, planter, soil = bmesh.new(), bmesh.new(), bmesh.new()
    prev = 0.0
    for start, rise in TERRACES:
        a = start - RUN  # visual steps end flush on the terrace at `start`
        n = 3
        run, lift = RUN / n, (rise - prev) / n
        for k in range(n):
            x = -STEP_HALF
            while x < STEP_HALF - 0.01:
                w = min(rng.uniform(7.0, 11.0), STEP_HALF - x)
                if STEP_HALF - (x + w) < 4:
                    w = STEP_HALF - x
                b = block((w - 0.1, run + 0.5, lift * (k + 1) + 0.7), rng, chip=0.08, bevel=0.07)
                append(steps, b, T(x + w / 2, a + (k + 0.5) * run + 0.25, prev - 0.7))
                x += w
        # the walking ramp under the steps, and the terrace's own floor from there back
        COLLISION.append({"kind": "wedge", "u0": -HX, "u1": HX, "d0": start - LEAD - RUN, "d1": start - LEAD, "h0": prev, "h1": rise})
        box_c(-HX, HX, start - LEAD, D, prev - 1.0, rise)
        # a planter at each end of the flight: a low wall of blocks round a bed
        for s in (-1, 1):
            u0, u1 = (STEP_HALF, HX) if s > 0 else (-HX, -STEP_HALF)
            d0, d1 = start - RUN - 3, start + 3
            top = rise + 1.7
            for (ua, ub, da, db) in ((u0, u1, d0, d0 + 1.6), (u0, u1, d1 - 1.6, d1), (u0, u0 + 1.6, d0, d1), (u1 - 1.6, u1, d0, d1)):
                long_u = (ub - ua) > (db - da)
                length = (ub - ua) if long_u else (db - da)
                count = max(1, round(length / 4.2))
                for i in range(count):
                    seg = length / count
                    size = (seg - 0.08, 1.6, top - prev + 0.8) if long_u else (1.6, seg - 0.08, top - prev + 0.8)
                    cu = ua + (i + 0.5) * seg if long_u else (ua + ub) / 2
                    cd = (da + db) / 2 if long_u else da + (i + 0.5) * seg
                    append(planter, block(size, rng, chip=0.1, bevel=0.06), T(cu, cd, prev - 0.8))
            plain_box(soil, u0 + 1.2, u1 - 1.2, d0 + 1.2, d1 - 1.2, prev, top - 0.35)
            box_c(u0, u1, d0, d1, prev - 1.0, top)
            mid_u, mid_d = (u0 + u1) / 2, (d0 + d1) / 2
            put("Bush_Wide" if s > 0 else "Bush_Big", mid_u - 3 * s, mid_d, top - 0.35, rng.uniform(0, 6.28), 1.25)
            put("Bush_Round", mid_u + 5 * s, mid_d + 1.5, top - 0.35, rng.uniform(0, 6.28), 1.2)
            put("Flowers_Coral", mid_u + 1.5 * s, mid_d - 3.2, top - 0.35, rng.uniform(0, 6.28), 1.3)
            put("Plant_Broadleaf", mid_u - 7 * s, mid_d + 2.6, top - 0.35, rng.uniform(0, 6.28), 1.3)
            put("Flowers_Tulip", mid_u + 7.5 * s, mid_d - 2.4, top - 0.35, rng.uniform(0, 6.28), 1.2)
        prev = rise
    make("Lobby_Steps", "Stone", "stone_trim", steps, "Lobby")
    make("Lobby_Planters", "Stone", "stone_trim", planter, "Lobby")
    make("Lobby_Planters", "Soil", "soil", soil, "Lobby")


# --- the edge: a retaining wall of block courses under the floor, a low parapet with posts on three sides ------------
def edges():
    rng = random.Random(37)
    wall, parapet = bmesh.new(), bmesh.new()

    def course(p0, p1, h_top, rows, size_h, along_u, thick=1.8, target=wall, length=6.0, out=1.0):
        # p0, p1: the run's ends along its axis; the other coordinate is fixed by `out`
        n = max(1, round(abs(p1 - p0) / length))
        seg = (p1 - p0) / n
        for r in range(rows):
            for i in range(n):
                c = p0 + (i + 0.5) * seg + (seg / 2 if r % 2 else 0.0)
                size = (abs(seg) - 0.1, thick, size_h) if along_u else (thick, abs(seg) - 0.1, size_h)
                b = brick(size, rng)
                ht = h_top(min(max(c, 0.0), D)) if callable(h_top) else h_top
                pos = T(c, out, ht - (r + 1) * size_h) if along_u else T(out, c, ht - (r + 1) * size_h)
                append(target, b, pos)

    # retaining wall: three courses under the floor all the way round, a stud outside the edge
    course(-HX - 1, HX + 1, -0.3, 2, 4.5, True, out=-1.0, length=8.0)
    course(-HX - 1, HX + 1, TRAIN_H - 0.3, 3, 4.5, True, out=D + 1.0, length=8.0)
    for s in (-1, 1):
        course(0, D, lambda d: height_at(d) - 0.3, 3, 4.5, False, out=s * (HX + 1.0), length=8.0)
    # parapet: knee-high on the sides and back; only a kerb along the view, so nothing stands in it
    course(-HX - 1, HX + 1, 0.55, 1, 0.85, True, thick=1.5, target=parapet, length=4.4, out=-0.95)
    course(-HX - 1, HX + 1, TRAIN_H + 1.5, 1, 1.8, True, thick=1.5, target=parapet, length=4.4, out=D + 0.95)
    for s in (-1, 1):
        course(4, D, lambda d: height_at(d) + 1.5, 1, 1.8, False, thick=1.5, target=parapet, length=4.4, out=s * (HX + 0.95))
    # posts with caps: the corners, then every 24 studs down the sides and across the back
    posts = [(s * (HX + 0.95), d) for s in (-1, 1) for d in (0.0, 24, 48, 72, 96 + 3, 126, D + 0.95)] + [(u, D + 0.95) for u in (-33, 0, 33)]
    for u, d in posts:
        h = height_at(min(max(d, 0), D))
        front = d < 1
        tall = 2.2 if front else 3.4
        append(parapet, block((2.2, 2.2, tall + 0.4), rng, chip=0.08), T(u, d if not front else -0.95, h - 0.4))
        append(parapet, block((2.8, 2.8, 0.5), rng, chip=0.06), T(u, d if not front else -0.95, h + tall))
        LANTERNS.append((u, d if not front else -0.95, h + tall + 0.5))
    make("Lobby_Retaining", "Stone", "stone_cream", wall, "Lobby")
    make("Lobby_Parapet", "Stone", "stone_trim", parapet, "Lobby")


# --- lanterns: a timber post and arm on every parapet post, a paper lantern hanging from it ----------------------------
LANTERNS = []


def lanterns():
    rng = random.Random(41)
    timber, paper = bmesh.new(), bmesh.new()
    for u, d, h in LANTERNS:
        # which way the arm reaches, in Blender axes: into the courtyard
        if d >= D:
            inward = Vector((0.0, 1.0, 0.0))
        elif d < 1:
            inward = Vector((0.0, -1.0, 0.0))
        else:
            inward = Vector((-math.copysign(1.0, u), 0.0, 0.0))
        post_top = h + 5.2
        tube(timber, [at(u, d, h - 0.1), at(u, d, post_top)], [0.3, 0.26], sides=6, rng=rng)
        tip = at(u, d, post_top - 0.3) + inward * 1.9
        tube(timber, [at(u, d, post_top - 0.5), tip], [0.18, 0.16], sides=5, rng=rng)
        tube(timber, [tip, tip - Vector((0, 0, 0.8))], [0.05, 0.05], sides=4, caps=(False, False))
        body = tip - Vector((0, 0, 1.6))
        b = bmesh.new()
        bmesh.ops.create_cube(b, size=1.0)
        for v in b.verts:
            wide = 1.0 if v.co.z < 0 else 0.86
            v.co = Vector((v.co.x * 1.05 * wide, v.co.y * 1.05 * wide, v.co.z * 1.4))
        bmesh.ops.triangulate(b, faces=b.faces[:])
        append(paper, b, Matrix.Translation(body))
        for z, size in ((0.78, 1.25), (-0.76, 1.0)):
            cap = bmesh.new()
            bmesh.ops.create_cube(cap, size=1.0)
            for v in cap.verts:
                v.co = Vector((v.co.x * size, v.co.y * size, v.co.z * 0.16))
            bmesh.ops.triangulate(cap, faces=cap.faces[:])
            append(timber, cap, Matrix.Translation(body + Vector((0, 0, z))))
    make("Lobby_Lanterns", "Timber", "bark_timber", timber, "Lobby")
    make("Lobby_Lanterns", "Paper", "paper", paper, "Lobby")


# --- the crag: big chunks under the edge, tapering down like Gnomon's island; spires behind and beside ----------------
SHELVES = []  # (u, d, h): flat rock tops outside the walls, for the kit's trees


def flat_top(bm, cut):
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, cut), plane_no=(0, 0, 1), clear_outer=True)
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])


def crag():
    rng = random.Random(53)
    bands = {"stone_cream": bmesh.new(), "stone_sand": bmesh.new(), "stone_blue": bmesh.new()}

    def rock(key, u, d, h_foot, size, lean=0.0, cuts=None, top=None, soft=True):
        c = chunk(size, rng, cuts=cuts or rng.randint(11, 16), bevel=0.06 if soft else 0.0)
        if top is not None:
            flat_top(c, top - h_foot)
        append(bands[key], c, T(u, d, h_foot, rng.uniform(0, math.tau)) @ Matrix.Rotation(lean, 4, "Y"))

    # under the floor: a ring of big blocks hugging the edge, then two smaller rings, then a keel
    for (inset, h_top, sz, key, n_u, n_d) in (
        (2.0, -1.0, (34, 30, 30), "stone_cream", 5, 6),
        (-3.0, -22.0, (42, 38, 36), "stone_sand", 4, 5),
        (-14.0, -48.0, (46, 42, 42), "stone_blue", 3, 4),
    ):
        ux, dx = HX + inset, D / 2 + inset
        pts = []
        for i in range(n_u):
            t = (i + 0.5) / n_u * 2 - 1
            pts += [(t * ux, D / 2 - dx), (t * ux, D / 2 + dx)]
        for i in range(n_d):
            t = (i + 0.5) / n_d * 2 - 1
            pts += [(-ux, D / 2 + t * dx), (ux, D / 2 + t * dx)]
        for u, d in pts:
            size = tuple(s * rng.uniform(0.85, 1.15) for s in sz)
            # pulled in under the edge, so the wall and parapet sit on rock rather than hang past it
            pull = 0.42
            cu, cd = u * (1 - pull * 0.18), D / 2 + (d - D / 2) * (1 - pull * 0.18)
            rock(key, cu, cd, h_top - size[2] * 0.7, size, top=h_top if inset > 0 else None, soft=False)
    core = bmesh.new()  # nothing shows between the ring's blocks
    plain_box(core, -HX + 14, HX - 14, 14, D - 14, -60, -1.2)
    append(bands["stone_sand"], core)
    for (u, d, h, sz) in ((0, D / 2, -128, (70, 62, 64)), (-20, D / 2 + 22, -98, (58, 54, 50)), (24, D / 2 - 18, -94, (56, 52, 48)), (0, D / 2, -168, (38, 34, 52))):
        rock("stone_blue" if h < -120 else "stone_sand", u, d, h, sz, cuts=14, soft=False)

    # spires: tall rocks behind the training terrace and down both sides of the back half. None by the view.
    spires = [
        (-52, D + 16, -18, (22, 20, 74), 0.05, "stone_cream"),
        (-24, D + 24, -22, (26, 22, 96), -0.04, "stone_sand"),
        (10, D + 20, -20, (20, 18, 66), 0.06, "stone_cream"),
        (40, D + 26, -24, (28, 24, 104), 0.03, "stone_sand"),
        (64, D + 12, -16, (18, 16, 58), -0.07, "stone_blue"),
        (-HX - 15, D - 12, -20, (20, 22, 82), 0.05, "stone_sand"),
        (-HX - 13, D - 44, -16, (16, 18, 52), -0.05, "stone_cream"),
        (HX + 16, D - 20, -20, (22, 20, 88), -0.04, "stone_cream"),
        (HX + 12, D - 52, -14, (16, 16, 46), 0.06, "stone_blue"),
        (-HX - 10, 74, -12, (13, 14, 30), 0.04, "stone_blue"),
        (HX + 11, 66, -12, (14, 13, 26), -0.05, "stone_sand"),
    ]
    for u, d, h, sz, lean, key in spires:
        rock(key, u, d, h, sz, lean)
        for _ in range(2):  # a couple of smaller rocks at each one's foot, never inside the walls
            for _try in range(12):
                a = rng.uniform(0, math.tau)
                r = max(sz[0], sz[1]) * 0.55
                s = rng.uniform(0.28, 0.45)
                fu, fd = u + math.cos(a) * r, d + math.sin(a) * r
                reach = max(sz[0], sz[1]) * s * 0.85
                if abs(fu) - reach > HX + 3 or fd - reach > D + 3:
                    rock(rng.choice(list(bands)), fu, fd, h + 4, (sz[0] * s * 1.6, sz[1] * s * 1.6, sz[2] * s), soft=False)
                    break
    # shelves: flat-topped ledges just outside the walls, each with a tree from the kit
    for u, d, top, sz, tree in (
        (-HX - 15, 104, 4.0, (22, 26, 30), "Tree_D"),
        (HX + 16, 112, 5.0, (24, 26, 32), "Tree_B"),
        (-HX - 13, 38, -2.0, (18, 22, 24), "Tree_E"),
        (HX + 14, 30, -3.0, (20, 20, 24), "Tree_C"),
        (-30, D + 17, 8.0, (26, 18, 30), "Tree_A"),
        (28, D + 16, 9.0, (24, 18, 30), "Tree_D"),
    ):
        rock("stone_cream", u, d, top - sz[2] * 0.5, sz, top=top)
        put(tree, u, d, top, rng.uniform(0, 6.28), 1.0)
        put("Bush_Low", u + rng.uniform(-5, 5), d + rng.uniform(-5, 5), top, rng.uniform(0, 6.28), 1.2)
        put("Plant_Tall_Blade", u + rng.uniform(-6, 6), d + rng.uniform(-6, 6), top, rng.uniform(0, 6.28), 1.4)
        put("Rock_Small_A", u + rng.uniform(-6, 6), d + rng.uniform(-6, 6), top, rng.uniform(0, 6.28), 1.3)
    for key, bm in bands.items():
        make("Lobby_Crag", key.split("_")[1].capitalize(), key, bm, "Lobby")


# --- the great tree: the court's landmark, on a raised bed on the side away from the shop ------------------------------
TREE_BED = (-HX, -HX + 18.0, 44.0, 80.0)


def great_tree():
    rng = random.Random(67)
    u0, u1, d0, d1 = TREE_BED
    top = COURT_H + 1.9
    stone, soil, bark, leaf = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for (ua, ub, da, db) in ((u0, u1, d0, d0 + 1.8), (u0, u1, d1 - 1.8, d1), (u1 - 1.8, u1, d0, d1)):
        long_u = (ub - ua) > (db - da)
        length = (ub - ua) if long_u else (db - da)
        count = max(1, round(length / 4.4))
        for i in range(count):
            seg = length / count
            size = (seg - 0.08, 1.8, top - COURT_H + 0.8) if long_u else (1.8, seg - 0.08, top - COURT_H + 0.8)
            cu = ua + (i + 0.5) * seg if long_u else (ua + ub) / 2
            cd = (da + db) / 2 if long_u else da + (i + 0.5) * seg
            append(stone, block(size, rng, chip=0.1, bevel=0.06), T(cu, cd, COURT_H - 0.8))
    plain_box(soil, u0, u1 - 1.4, d0 + 1.4, d1 - 1.4, COURT_H, top - 0.35)
    box_c(u0, u1, d0, d1, COURT_H - 1.0, top)
    cu, cd = u0 + 8.5, (d0 + d1) / 2
    base = at(cu, cd, top - 0.4)
    trunk = [base, base + Vector((0.5, 0.4, 5)), base + Vector((1.6, -0.3, 10)), base + Vector((1.2, 0.6, 15))]
    tube(bark, trunk, [2.1, 1.7, 1.35, 1.1], sides=9, rng=rng)
    for k in range(5):  # buttress roots
        a = k / 5 * math.tau + 0.4
        tube(bark, [base + Vector((0, 0, 1.4)), base + Vector((math.cos(a) * 2.6, math.sin(a) * 2.6, 0.3)), base + Vector((math.cos(a) * 4.2, math.sin(a) * 4.2, -0.2))], [1.0, 0.7, 0.3], sides=6, rng=rng)
    limbs = [((7.5, -4.5, 7.0), 8.6), ((-5.5, 5.0, 7.5), 8.0), ((2.5, 8.5, 9.0), 7.4), ((-3.0, -7.5, 8.0), 7.2), ((0.6, 0.4, 12.5), 9.6)]
    for off, r in limbs:
        tip = trunk[-1] + Vector(off)
        mid = trunk[-2] + (tip - trunk[-2]) * 0.55 + Vector((0, 0, 1.2))
        tube(bark, [trunk[-2], mid, tip], [0.95, 0.6, 0.35], sides=6, rng=rng)
        append(leaf, canopy_mass(r, rng, squash=0.7, cuts=5), Matrix.Translation(tip + Vector((0, 0, r * 0.25))))
        for _ in range(2):
            o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 0.5))) * r * 0.8
            append(leaf, canopy_mass(r * rng.uniform(0.5, 0.68), rng, squash=0.72, cuts=4), Matrix.Translation(tip + o))
    cyl_c(cu, cd, 2.4, top - 1, top + 14)
    make("Lobby_GreatTree", "Stone", "stone_trim", stone, "Lobby")
    make("Lobby_GreatTree", "Soil", "soil", soil, "Lobby")
    make("Lobby_GreatTree", "Bark", "bark", bark, "Lobby")
    make("Lobby_GreatTree", "Leaf", "leaf_gold", leaf, "Lobby")
    for (du, dd, asset, sc) in ((-3.0, -12, "Bush_Round", 1.3), (3.5, 12, "Bush_Double", 1.3), (6.5, -6, "Flowers_Daisy_Big", 1.2), (5.5, 7, "Flowers_Coral", 1.3), (-2, 14.5, "Plant_Broadleaf", 1.4), (7, -14, "Plant_Spiky", 1.4), (2, -15.5, "Flowers_Bell", 1.3)):
        put(asset, cu + du, cd + dd, top - 0.35, rng.uniform(0, 6.28), sc)
    # two benches facing the court, in the tree's shade
    bstone, btimber = bmesh.new(), bmesh.new()
    for bd in (52.0, 72.0):
        bu = u1 + 3.2
        for leg in (-2.6, 2.6):
            append(bstone, block((1.5, 0.9, 1.3), rng, chip=0.08), T(bu, bd + leg, COURT_H))
        append(btimber, block((1.9, 7.2, 0.45), rng, chip=0.04, bevel=0.05), T(bu, bd, COURT_H + 1.3))
        box_c(bu - 1.0, bu + 1.0, bd - 3.6, bd + 3.6, COURT_H, COURT_H + 1.75)
    make("Lobby_Benches", "Stone", "stone_trim", bstone, "Lobby")
    make("Lobby_Benches", "Timber", "bark_timber", btimber, "Lobby")


# --- the shop stall: on the strip kept for gamepass displays, opposite the tree ---------------------------------------
def stall():
    rng = random.Random(71)
    timber, coral, cream, clay = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    u0, u1, d0, d1 = HX - 11.0, HX - 1.0, 40.0, 84.0
    h = COURT_H
    # counter: a run of timber blocks with a plank top
    n = 6
    for i in range(n):
        seg = (d1 - d0) / n
        append(timber, block((3.0, seg - 0.1, 2.9), rng, chip=0.05, bevel=0.05), T(u0 + 1.5, d0 + (i + 0.5) * seg, h))
    append(timber, block((4.2, d1 - d0 + 1.2, 0.4), rng, chip=0.03, bevel=0.05), T(u0 + 1.7, (d0 + d1) / 2, h + 2.9))
    box_c(u0 - 0.4, u0 + 3.8, d0 - 0.6, d1 + 0.6, h, h + 3.3)
    # posts and the awning's frame
    for d in (d0, (d0 + d1) / 2, d1):
        tube(timber, [at(u0 - 0.2, d, h), at(u0 - 0.2, d, h + 9.4)], [0.5, 0.42], sides=6, rng=rng)
        tube(timber, [at(u1, d, h), at(u1, d, h + 12.2)], [0.5, 0.42], sides=6, rng=rng)
        tube(timber, [at(u0 - 3.4, d, h + 8.4), at(u1 + 0.4, d, h + 12.3)], [0.26, 0.26], sides=5, rng=rng)
        cyl_c(u0 - 0.2, d, 0.6, h, h + 9)
    tube(timber, [at(u0 - 0.2, d0 - 1, h + 9.3), at(u0 - 0.2, d1 + 1, h + 9.3)], [0.3, 0.3], sides=5, rng=rng)
    tube(timber, [at(u1, d0 - 1, h + 12.1), at(u1, d1 + 1, h + 12.1)], [0.3, 0.3], sides=5, rng=rng)
    # awning: coral and cream stripes sloping down toward the court, a scalloped hem
    stripes = 8
    for i in range(stripes):
        a, b = d0 - 1.2 + i * (d1 - d0 + 2.4) / stripes, d0 - 1.2 + (i + 1) * (d1 - d0 + 2.4) / stripes
        target = coral if i % 2 == 0 else cream
        p = [at(u0 - 3.6, a, h + 8.55), at(u0 - 3.6, b, h + 8.55), at(u1 + 0.5, b, h + 12.65), at(u1 + 0.5, a, h + 12.65)]
        hem = [p[0] + Vector((-0.15, 0, -1.3)), p[1] + Vector((-0.15, 0, -1.3))]
        mid = (hem[0] + hem[1]) / 2 + Vector((0, 0, -0.55))
        up = Vector((0.06, 0, 0.16))
        vs = [target.verts.new(q) for q in p] + [target.verts.new(q + up) for q in p]
        target.faces.new(vs[:4])
        target.faces.new(list(reversed(vs[4:])))
        for k in range(4):
            j = (k + 1) % 4
            target.faces.new((vs[k], vs[k + 4], vs[j + 4], vs[j]))
        hv = [target.verts.new(q) for q in (p[0], p[1], hem[1], mid, hem[0])]
        target.faces.new(hv)
        hv2 = [target.verts.new(q + Vector((-0.08, 0, 0))) for q in (p[0], p[1], hem[1], mid, hem[0])]
        target.faces.new(list(reversed(hv2)))
    # stock: crates by the counter, clay pots at its ends
    for (cu, cd, s, yaw) in ((u0 - 2.6, d0 - 4.2, 2.6, 0.3), (u0 - 0.2, d0 - 4.6, 2.2, -0.2), (u0 - 1.5, d0 - 4.4, 1.8, 0.6), (u0 - 2.2, d1 + 4.4, 2.4, -0.4), (u0 + 0.6, d1 + 4.0, 2.0, 0.2)):
        lift = 2.6 if (cu, cd) == (u0 - 1.5, d0 - 4.4) else 0.0
        append(timber, block((s, s, s), rng, chip=0.05, bevel=0.05), T(cu, cd, h + lift, yaw))
    box_c(u0 - 4.2, u0 + 1.4, d0 - 6.2, d0 - 2.9, h, h + 2.6)
    box_c(u0 - 3.8, u0 + 1.9, d1 + 2.6, d1 + 5.8, h, h + 2.4)
    profile = [(0.0, 0.55), (0.5, 0.95), (1.4, 1.15), (2.2, 0.85), (2.6, 0.5), (2.85, 0.62)]
    for (pu, pd, s) in ((u0 + 1.6, d0 + 3, 0.7), (u0 + 1.4, d0 + 9.5, 0.55), (u0 + 1.7, d1 - 4, 0.75), (u0 - 5.6, d1 + 3.6, 1.25), (u0 - 5.2, d0 - 3.4, 1.1)):
        base_h = h + 3.3 if s < 1 else h
        tube(clay, [at(pu, pd, base_h + z * s) for z, _ in profile], [r * s for _, r in profile], sides=8, rng=rng, jitter=0.03)
        if s >= 1:
            cyl_c(pu, pd, 1.2 * s, h, h + 2.9 * s)
    for bm in (coral, cream):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    make("Lobby_Stall", "Timber", "bark_timber", timber, "Lobby")
    make("Lobby_Stall", "Coral", "cloth_coral", coral, "Lobby")
    make("Lobby_Stall", "Cream", "cloth_cream", cream, "Lobby")
    make("Lobby_Stall", "Clay", "stone_clay", clay, "Lobby")


# --- the training gate, banner poles, striking posts ------------------------------------------------------------------
def gate_and_banners():
    rng = random.Random(83)
    gate, timber, coral, gold, rope = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    gd = TRAIN_D - 3.0
    h = COURT_H
    for s in (-1, 1):
        u = s * 19.0
        tube(gate, [at(u, gd, h - 0.5), at(u * 0.985, gd, h + 17.5)], [1.15, 0.95], sides=8, rng=rng, jitter=0.03)
        append(gate, block((3.2, 3.2, 1.4), rng, chip=0.06), T(u, gd, h + 2.0))
        cyl_c(u, gd, 1.6, h, h + 17)
    append(gate, block((50.0, 2.4, 1.7), rng, chip=0.04, bevel=0.05), T(0, gd, h + 17.4))
    append(gate, block((54.0, 3.0, 0.8), rng, chip=0.04, bevel=0.05), T(0, gd, h + 19.1))
    append(gate, block((42.0, 1.6, 1.3), rng, chip=0.04, bevel=0.05), T(0, gd, h + 13.4))
    append(gate, block((1.6, 1.4, 2.7), rng, chip=0.04), T(0, gd, h + 14.7))
    make("Lobby_Gate", "Timber", "bark_gate", gate, "Lobby")

    def banner(u, d, h0, cloth, tall=15.0, face=0.0):
        tube(timber, [at(u, d, h0 - 0.3), at(u, d, h0 + tall)], [0.36, 0.28], sides=6, rng=rng)
        cyl_c(u, d, 0.6, h0, h0 + tall)
        arm = Vector((math.cos(face), math.sin(face), 0))
        a, b = at(u, d, h0 + tall - 0.9), at(u, d, h0 + tall - 0.9) + arm * 3.4
        tube(timber, [a - arm * 0.4, b], [0.15, 0.15], sides=5, rng=rng)
        rows = 6
        length, width = 8.5, 2.7
        front, back = [], []
        normal = Vector((-arm.y, arm.x, 0))
        for r in range(rows + 1):
            t = r / rows
            sway = math.sin(t * 2.6) * 0.35 * t
            for k in (0, 1):
                p = a + arm * (0.45 + k * width) + Vector((0, 0, -0.1 - t * length + (0.6 if (r == rows and k == 1) else 0))) + normal * sway
                front.append(cloth.verts.new(p + normal * 0.04))
                back.append(cloth.verts.new(p - normal * 0.04))
        for r in range(rows):
            i = r * 2
            cloth.faces.new((front[i], front[i + 1], front[i + 3], front[i + 2]))
            cloth.faces.new((back[i + 2], back[i + 3], back[i + 1], back[i]))

    a = COURT_D - RUN / 2
    banner(-STEP_HALF + 1.2, a, 0.0, coral, face=math.pi)
    banner(STEP_HALF - 1.2, a, 0.0, gold, face=0.0)
    for i, u in enumerate((-58, -30, 30, 58)):
        banner(u, D - 2.2, TRAIN_H, coral if i % 2 == 0 else gold, tall=13.0, face=0.0 if u < 0 else math.pi)
    # striking posts along the back of the mat, rope-bound
    for u in (-40, -20, 0, 20, 40):
        d = D - 9.5
        tube(timber, [at(u, d, TRAIN_H - 0.2), at(u, d, TRAIN_H + 6.2)], [0.75, 0.7], sides=8, rng=rng, jitter=0.03)
        for z in (2.6, 3.9, 5.2):
            tube(rope, [at(u, d, TRAIN_H + z - 0.42), at(u, d, TRAIN_H + z + 0.42)], [0.86, 0.86], sides=8, rng=rng, jitter=0.02)
        cyl_c(u, d, 0.95, TRAIN_H, TRAIN_H + 6.2)
    make("Lobby_Banners", "Timber", "bark_timber", timber, "Lobby")
    make("Lobby_Banners", "Coral", "cloth_coral", coral, "Lobby")
    make("Lobby_Banners", "Gold", "cloth_gold", gold, "Lobby")
    make("Lobby_Banners", "Rope", "cloth_cream", rope, "Lobby")
    # the old kit's ruins and rocks, as dressing at the landmarks and the edges
    cyl_c(-HX + 6, 8, 1.6, 0.0, 4.4)
    cyl_c(HX - 5, D - 6, 1.6, TRAIN_H, TRAIN_H + 10.5)
    cyl_c(-HX + 5, D - 7, 1.6, TRAIN_H, TRAIN_H + 4.4)
    cyl_c(HX - 6, 9, 2.6, 0.0, 3.6)
    cyl_c(-HX + 7, D - 13, 2.0, TRAIN_H, TRAIN_H + 2.4)
    put("Ruin_Column_Broken", -HX + 6, 8, 0.0, 0.4, 1.0)
    put("Ruin_Column_Tall", HX - 5, D - 6, TRAIN_H, 1.1, 1.0)
    put("Ruin_Column_Broken", -HX + 5, D - 7, TRAIN_H, 2.0, 1.0)
    put("Rock_Twin", HX - 6, 9, 0.0, 2.2, 1.2)
    put("Rock_Small_B", HX - 10, 5, 0.0, 0.7, 1.3)
    put("Plant_Groundcover", -HX + 9, 12, 0.0, 0.2, 1.3)
    put("Flowers_Daisy_Small", HX - 9, 12.5, 0.0, 1.4, 1.3)
    put("Rock_Medium", -HX + 7, D - 13, TRAIN_H, 0.5, 1.1)
    put("Plant_Roundleaf", HX - 9, D - 11, TRAIN_H, 0.9, 1.4)


# --- build, paint, save, export --------------------------------------------------------------------------------------
def export():
    up = os.path.join(OUT, "export")
    os.makedirs(up, exist_ok=True)
    for o in bpy.data.objects:  # the bake's facet mask is a colour attribute: Roblox would multiply it in
        if o.type == "MESH":
            for attr in list(o.data.color_attributes):
                o.data.color_attributes.remove(attr)
    bpy.context.view_layer.update()
    objs = sorted((o for _, _, o in REGISTRY), key=lambda o: o.name)
    groups, current, budget = [], [], 0
    for o in objs:
        tex = os.path.join(OUT, "textures", f"{o.name}_Color.png")
        size = (os.path.getsize(tex) if os.path.exists(tex) else 0) + len(o.data.polygons) * 110
        if current and budget + size > 13e6:
            groups.append(current)
            current, budget = [], 0
        current.append(o)
        budget += size
    groups.append(current)
    manifest = {"meshes": {}, "files": []}
    for index, group in enumerate(groups, 1):
        for o in bpy.context.view_layer.objects:
            o.select_set(o in group)
        path = os.path.join(up, f"cliffside_{index}.glb")
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
            export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
            export_image_format="AUTO", export_skins=False, export_animations=False,
        )
        manifest["files"].append({"file": os.path.basename(path), "mb": round(os.path.getsize(path) / 1e6, 2), "meshes": [o.name for o in group]})
        for o in group:
            co = [o.matrix_world @ Vector(c) for c in o.bound_box]
            lo = [min(c[k] for c in co) for k in range(3)]
            hi = [max(c[k] for c in co) for k in range(3)]
            mid = [(lo[k] + hi[k]) / 2 for k in range(3)]
            tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
            # lobby-local Roblox axes: x = u, y = h, z = d (= -Blender y)
            manifest["meshes"][o.name] = {
                "file": index, "key": o["kit_key"], "x": round(mid[0], 3), "y": round(mid[2], 3), "z": round(-mid[1], 3),
                "sx": round(hi[0] - lo[0], 3), "sy": round(hi[2] - lo[2], 3), "sz": round(hi[1] - lo[1], 3), "tris": tris,
            }
        print("GLB", os.path.basename(path), manifest["files"][-1]["mb"], "MB", len(group), "meshes", flush=True)
    manifest["triangles"] = sum(m["tris"] for m in manifest["meshes"].values())
    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8"), indent=1)
    json.dump(COLLISION, open(os.path.join(OUT, "collision.json"), "w", encoding="utf-8"), indent=1)
    json.dump(PLACE, open(os.path.join(OUT, "placements.json"), "w", encoding="utf-8"), indent=1)
    print("TRIANGLES", manifest["triangles"], "MESHES", len(manifest["meshes"]), "COLLIDERS", len(COLLISION), "KIT PIECES", len(PLACE), flush=True)


def main():
    C.reset()
    C.sky_and_sun(250, 16)  # golden hour: a low sun from the lobby's left
    os.makedirs(os.path.join(OUT, "textures"), exist_ok=True)
    for fn in (paving, stairs_and_planters, edges, lanterns, crag, great_tree, stall, gate_and_banners):
        fn()
        print("BUILT", fn.__name__, flush=True)
    scene = bpy.context.scene
    cams = {
        "Spawn": C.camera("Spawn", at(0, SPAWN_D + 14, COURT_H + 7), at(0, -60, -8), lens=22),
        "Court": C.camera("Court", at(-30, 20, 16), at(30, 96, 6), lens=22),
        "Training": C.camera("Training", at(36, 84, 14), at(-20, 140, 8), lens=22),
        "Arena": C.camera("Arena", at(-150, -230, -10), at(0, 60, 0), lens=35),
        "Over": C.camera("Over", at(150, -110, 150), at(0, 75, 0), lens=30),
    }
    if DRY:
        total = 0
        for asset, key, obj in REGISTRY:
            tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
            total += tris
            base = PAL[key][0]
            obj.color = (float(base[0]) ** (1 / 2.2), float(base[1]) ** (1 / 2.2), float(base[2]) ** (1 / 2.2), 1.0)
            print(f"MESH {obj.name}: {tris} tris{'  OVER 20000' if tris > 20000 else ''}", flush=True)
        print("TRIANGLES", total, "MESHES", len(REGISTRY), "COLLIDERS", len(COLLISION), "KIT PIECES", len(PLACE), flush=True)
        json.dump(COLLISION, open(os.path.join(OUT, "collision.json"), "w", encoding="utf-8"), indent=1)
        json.dump(PLACE, open(os.path.join(OUT, "placements.json"), "w", encoding="utf-8"), indent=1)
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "OBJECT"
        scene.display.shading.show_cavity = True
        scene.display.shading.show_shadows = True
        C.render_all(OUT, "dry", cams, resolution=(960, 540))
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "cliffside.blend"))
    if not NO_RENDER:
        scene.cycles.samples = 24
        C.render_all(OUT, "cliffside", cams, resolution=(960, 540))
    export()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "cliffside.blend"))
    print("SAVED", os.path.join(OUT, "cliffside.blend"), flush=True)


main()
