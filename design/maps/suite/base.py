"""The arena suite's shared base (owner brief 2026-11-20): six maps built in the LIVE lobby's language
(ServerStorage.HT_Lobby.Village, design/lobby/village.py): its modelling tools, baked paint and colour family, so
the world reads as one. NEVER its set pieces (owner, 2026-11-20): the lobby and the arenas are completely separate,
and every map is unique to itself, so no medallion, stalls, bunting or other lobby element goes on an arena.
Each map is a script beside this one (meadow.py, ...) that execs this file, adds its own pieces and calls run().

    blender -b --factory-startup -P <map>.py -- <out folder> [--dry] [--fast] [--no-render]

THE FIGHTING SURFACE, the same on every map (owner, 2026-11-20: "the same as Gnomon oval, for the MAIN part of the
arena, everything else can be different"): a flat oval of semi-axes A x B = 213 x 176 studs (426 x 352), rim
included, top at 0, the long axis on X (MapEnvironments `arena`). Nothing stands on it; a drop on every side.

AXES: arena-local Roblox studs. x across (+X), z toward the lobby (+Z), y up from the surface. The arena's centre on
its surface is (Arena.CenterX, CenterY, CenterZ) = (3000, 100, 0). In Blender x = x, y = -z, z = y, so Blender +Y
points NORTH, away from the lobby, where the backdrops go. glTF export (Y-up) brings that back to Roblox axes.

COLLISION: no visual mesh collides. collision.json holds the floor as a polygon of the oval (and anything else a map
declares); the Studio builder (studio_map.py) turns it into invisible anchored parts inside the map model.
NAMES: Map_<Name>_<Element>_<Material>[_n]. Meshes stay under 20,000 triangles and 2,048 studs on every axis.
"""
import json
import math
import os
import random  # noqa: F401  (the map scripts use it through this namespace)
import sys  # noqa: F401

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.abspath(os.path.join(HERE, ".."))
LOBBY = os.path.abspath(os.path.join(MAPS, "..", "lobby"))
PROJECT = os.path.abspath(os.path.join(MAPS, "..", ".."))

# The lobby's helpers, kit builders and painter (cliffside.py without its main(); village.py does the same).
_path = os.path.join(LOBBY, "cliffside.py")
_src = open(_path, encoding="utf-8").read()
_src = _src[: _src.rindex("\nmain()")]
L = {"__name__": "cliffside_kit", "__file__": _path}
exec(compile(_src, _path, "exec"), L)
K = L["K"]
chunk, block, lump, canopy_mass, tube, append, make, srgb = (K[n] for n in ("chunk", "block", "lump", "canopy_mass", "tube", "append", "make", "srgb"))
C, P, S = K["C"], K["P"], K["S"]
PAL, REGISTRY = K["PAL"], K["REGISTRY"]
brick, plain_box, flat_top = L["brick"], L["plain_box"], L["flat_top"]

ARGS = L["ARGS"]
OUT = L["OUT"]
DRY = L["DRY"]
NO_RENDER = L["NO_RENDER"]
FAST = K["FAST"]
TEX = os.path.join(OUT, "textures")
FAR_TEX = 600.0  # studs from the arena's centre: backdrop past this bakes at most 512 px (see run; was 1100 until the
# Quarry review 2026-11-21: at 800+ studs a stud is about one screen pixel at 1080p)

# THE LIVE LOBBY'S PALETTE (village.py, ui-20f, the UI's paints), so every map flows from the lobby. Each is
# (base, lit, shade), sRGB in, linear out. Maps add their own keys; feel_of() picks the treatment from the prefix
# (stone*, bark*, leaf*, anything else is "flat").
PAL.update(
    {
        "stone_pave": (srgb(238, 230, 214), srgb(252, 246, 234), srgb(160, 156, 172)),
        "stone_trim": (srgb(244, 238, 226), srgb(255, 250, 240), srgb(170, 166, 180)),
        "stone_cream": (srgb(234, 224, 206), srgb(250, 242, 226), srgb(158, 150, 160)),
        "stone_sand": (srgb(228, 206, 172), srgb(246, 228, 198), srgb(156, 136, 128)),
        "stone_blue": (srgb(174, 184, 214), srgb(206, 214, 236), srgb(104, 112, 148)),
        "stone_clay": (srgb(226, 116, 88), srgb(246, 160, 130), srgb(150, 72, 66)),
        "stone_teal": (srgb(92, 198, 219), srgb(160, 226, 238), srgb(50, 124, 150)),
        "stone_roof": (srgb(212, 104, 78), srgb(238, 146, 114), srgb(130, 62, 60)),
        "bark_timber": (srgb(196, 150, 104), srgb(226, 186, 140), srgb(122, 86, 70)),
        "bark": (srgb(112, 82, 64), srgb(152, 114, 88), srgb(64, 46, 44)),
        "cloth_coral": (srgb(238, 122, 94), srgb(248, 166, 138), srgb(160, 76, 70)),
        "cloth_gold": (srgb(242, 199, 68), srgb(252, 226, 140), srgb(172, 132, 44)),
        "cloth_cream": (srgb(255, 248, 234), srgb(255, 252, 244), srgb(186, 180, 186)),
        "cloth_teal": (srgb(92, 198, 219), srgb(160, 226, 238), srgb(50, 124, 150)),
        "soil": (srgb(126, 96, 76), srgb(162, 128, 100), srgb(80, 58, 50)),
    }
)

# --- the shared oval ------------------------------------------------------------------------------------------
A, B = 213.0, 176.0  # semi-axes, rim included (MapEnvironments gnomon.arena; every suite map's arena)
SPAWN_SHARE = 0.65  # spawns stand on the oval at this share of it (MapEnvironments arena.spawnShare)
LOBBY_EDGE_Z, LOBBY_FLOOR_Y = 250.0, 20.0  # the lobby's viewing edge, arena-local (Lobby.ViewEdgeZ, FloorY - CenterY)


def W(x, z, y=0.0):
    """Arena-local Roblox (x, z, height y) -> a Blender vector."""
    return Vector((x, -z, y))


def oval(t, inset=0.0):
    """The point at parameter t on the oval moved `inset` studs inward along its normal: (x, z, nx, nz)."""
    nx, nz = math.cos(t) / A, math.sin(t) / B
    n = math.hypot(nx, nz)
    nx, nz = nx / n, nz / n
    return A * math.cos(t) - nx * inset, B * math.sin(t) - nz * inset, nx, nz


_N = 8192
_T = np.linspace(0.0, math.tau, _N + 1)
_P = np.stack([A * np.cos(_T), B * np.sin(_T)], axis=1)
_S = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(_P, axis=0), axis=1))])
PERIM = float(_S[-1])  # about 1,229 studs


def t_at(s):
    """The oval's parameter at arc length s (any s; it wraps)."""
    return float(np.interp(s % PERIM, _S, _T))


def inside(x, z, inset=0.0):
    """True when (x, z) is inside the oval shrunk by `inset` (near enough: semi-axes minus inset)."""
    return (x / (A - inset)) ** 2 + (z / (B - inset)) ** 2 < 1.0


# --- bags: geometry gathered per (element, material, key), split so no mesh passes the triangle budget -----------
BAGS = {}
SPLIT = 16000


def tris_of(bm):
    return sum(len(f.verts) - 2 for f in bm.faces)


def add(element, material, key, src, matrix=Matrix(), family="Map", region=""):
    """Adds bmesh `src` (freed) to the bag; `region` keeps far-apart pieces in separate meshes (the 2,048 limit)."""
    k = (element, material, key, family, region)
    bags = BAGS.setdefault(k, [[bmesh.new(), 0]])
    n = tris_of(src)
    if bags[-1][1] + n > SPLIT and bags[-1][1] > 0:
        bags.append([bmesh.new(), 0])
    append(bags[-1][0], src, matrix)
    bags[-1][1] += n


PX = {}  # element -> texture size override for its meshes


def flush(map_name):
    """Every bag becomes Map_<map>_<element>_<material>[_<region>][_n], painted later by the lobby's baker."""
    for (element, material, key, family, region), bags in BAGS.items():
        for i, (bm, _n) in enumerate(bags):
            part = material + (f"_{region}" if region else "") + (f"_{i + 1}" if len(bags) > 1 else "")
            bmesh.ops.triangulate(bm, faces=bm.faces[:])
            obj = make(f"Map_{map_name}_{element}", part, key, bm, family)
            if obj is not None and element in PX:
                obj["px"] = PX[element]
    BAGS.clear()


# --- blocks laid round the oval -------------------------------------------------------------------------------
def prism_on_oval(bm, t0, t1, profile, edge=None, profile_b=None):
    """A block between edge parameters t0 and t1 whose cross-section is `profile`, a closed list of (inset, height)
    going round the section (`profile_b`, the same length, at the t1 end if given). `edge(t, inset) -> (x, z)` is
    the outline (default: the arena's oval). Straight between its ends (the oval's tightest curve, radius
    B*B/A = 145, sags 0.03 over a 6-stud block)."""
    edge = edge or (lambda t, w: oval(t, w)[:2])
    a, b = [], []
    for (w, h), (w2, h2) in zip(profile, profile_b or profile):
        x, z = edge(t0, w)
        a.append(bm.verts.new(W(x, z, h)))
        x, z = edge(t1, w2)
        b.append(bm.verts.new(W(x, z, h2)))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)


def course(element, material, key, inset0, inset1, h0, h1, rng, lmin, lmax, gap=0.15, top_chamfer=0.25,
           outer_chamfer=None, inner_chamfer=None, top_jitter=0.0, phase=0.0, family="Map", bottom_jitter=0.0,
           bottom_fn=None):
    """One course of blocks round the oval: from inset0 (outer face) to inset1 (inner face), from h0 up to h1,
    block lengths in [lmin, lmax] along the edge, a joint of `gap` between blocks, chamfered top edges;
    `bottom_jitter` lowers each block's bottom by its own amount (a ragged, stepped edge); `bottom_fn(s)` instead
    lowers it smoothly by arc length, each block sloping between its two ends (a continuous wavy edge)."""
    oc = top_chamfer if outer_chamfer is None else outer_chamfer
    ic = top_chamfer if inner_chamfer is None else inner_chamfer
    s = phase
    end = phase + PERIM
    bm = bmesh.new()
    count = 0
    while s < end - 0.01:
        ln = rng.uniform(lmin, lmax)
        if end - (s + ln) < lmin * 0.6:
            ln = end - s
        top = h1 - rng.uniform(0.0, top_jitter)
        bot = h0 - rng.uniform(0.0, bottom_jitter)
        s0, s1 = s + gap / 2, s + ln - gap / 2
        b0 = h0 - bottom_fn(s0) if bottom_fn else bot
        b1 = h0 - bottom_fn(s1) if bottom_fn else bot
        prof = [(inset0, b0), (inset0, top - oc), (inset0 + oc, top), (inset1 - ic, top), (inset1, top - ic), (inset1, b0)]
        prof_b = [(inset0, b1), (inset0, top - oc), (inset0 + oc, top), (inset1 - ic, top), (inset1, top - ic), (inset1, b1)]
        prism_on_oval(bm, t_at(s0), t_at(s1), prof, profile_b=prof_b)
        s += ln
        count += 1
        if count % 60 == 0:  # keep bags splittable
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            add(element, material, key, bm, family=family)
            bm = bmesh.new()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    add(element, material, key, bm, family=family)


def oval_ring_inlay(element, material, key, inset0, inset1, share, rng, pieces, h=0.04, depth=0.3, chamfer=0.12, family="Map"):
    """A flush stone band on a smaller copy of the oval (`share` of it), cut into `pieces` slabs."""
    bm = bmesh.new()
    a, b = A * share, B * share
    for i in range(pieces):
        g = 0.12 / (a + b) * 2
        t0, t1 = i / pieces * math.tau + g, (i + 1) / pieces * math.tau - g
        ring = []
        for t in (t0, t1):
            nx, nz = math.cos(t) / a, math.sin(t) / b
            n = math.hypot(nx, nz)
            nx, nz = nx / n, nz / n
            x, z = a * math.cos(t), b * math.sin(t)
            ring.append([(x - nx * w, z - nz * w) for w in (inset0, inset1)])
        (o0, i0), (o1, i1) = ring
        lo = [bm.verts.new(W(px, pz, h - depth)) for px, pz in (o0, o1, i1, i0)]
        mid = [bm.verts.new(W(px, pz, h - chamfer)) for px, pz in (o0, o1, i1, i0)]
        cx, cz = sum(p[0] for p in (o0, o1, i1, i0)) / 4, sum(p[1] for p in (o0, o1, i1, i0)) / 4
        up = [bm.verts.new(W(px + (cx - px) * 0.04, pz + (cz - pz) * 0.04, h)) for px, pz in (o0, o1, i1, i0)]
        for k in range(4):
            j = (k + 1) % 4
            bm.faces.new((lo[k], lo[j], mid[j], mid[k]))
            bm.faces.new((mid[k], mid[j], up[j], up[k]))
        bm.faces.new(up)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    add(element, material, key, bm, family=family)


def strip_inlay(element, material, key, x0, z0, x1, z1, width, rng, seg=7.0, h=0.04, depth=0.3, chamfer=0.12, family="Map"):
    """A flush straight band of slabs from (x0, z0) to (x1, z1)."""
    bm = bmesh.new()
    dx, dz = x1 - x0, z1 - z0
    ln = math.hypot(dx, dz)
    ux, uz = dx / ln, dz / ln
    px, pz = -uz * width / 2, ux * width / 2
    n = max(1, round(ln / seg))
    for i in range(n):
        a, b = i / n * ln + 0.08, (i + 1) / n * ln - 0.08
        quad = [(x0 + ux * a + px, z0 + uz * a + pz), (x0 + ux * b + px, z0 + uz * b + pz), (x0 + ux * b - px, z0 + uz * b - pz), (x0 + ux * a - px, z0 + uz * a - pz)]
        cx, cz = sum(q[0] for q in quad) / 4, sum(q[1] for q in quad) / 4
        lo = [bm.verts.new(W(qx, qz, h - depth)) for qx, qz in quad]
        mid = [bm.verts.new(W(qx, qz, h - chamfer)) for qx, qz in quad]
        up = [bm.verts.new(W(qx + (cx - qx) * 0.03, qz + (cz - qz) * 0.03, h)) for qx, qz in quad]
        for k in range(4):
            j = (k + 1) % 4
            bm.faces.new((lo[k], lo[j], mid[j], mid[k]))
            bm.faces.new((mid[k], mid[j], up[j], up[k]))
        bm.faces.new(up)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    add(element, material, key, bm, family=family)


# --- the painted floor: flat tiles inside the rim, UVs projected from above, colour painted in numpy -------------
PAINTED = []  # objects with their own painted image (the lobby's baker skips them)


def floor_tiles(map_name, element, material, key, inset, painter, nx=3, nz=2, px=1024, seed=0, pad=16):
    """The fighting surface inside the rim as nx x nz flat tiles at height 0, each with its own px-square colour map
    from painter(X, Z) -> linear (h, w, 3) (arena-local x and z at each pixel's centre).
    Each map is painted `pad` texels PAST its tile's edges (the painter carries on into the next tile) and the UVs sit
    inside that margin. Roblox (and Cycles) wrap textures, so a map painted edge to edge blends each edge with the
    opposite one and every tile edge shows as a thin line (Quarry 2026-11-21, its strata; Map 1's even green hid it).
    16 texels keeps the first 4 mip levels clean."""
    n = 256
    bm = bmesh.new()
    vs = []
    for i in range(n):
        x, z, _, _ = oval(i / n * math.tau, inset)
        vs.append(bm.verts.new(W(x, z, 0.0)))
    # round the oval by rising t runs clockwise seen from above in Blender (y = -z), which points the face DOWN:
    # Blender draws both sides, Roblox only the front, so Map 1's floor showed the stone under it (2026-11-22)
    bm.faces.new(list(reversed(vs)))
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    xs = [-A + i * 2 * A / nx for i in range(1, nx)]
    ys = [-B + j * 2 * B / nz for j in range(1, nz)]
    for x in xs:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(x, 0, 0), plane_no=(1, 0, 0))
    for y in ys:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, y, 0), plane_no=(0, 1, 0))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me_all = bpy.data.meshes.new("floor_tmp")
    bm.to_mesh(me_all)
    bm.free()
    os.makedirs(TEX, exist_ok=True)
    for i in range(nx):
        for j in range(nz):
            x0, x1 = -A + i * 2 * A / nx, -A + (i + 1) * 2 * A / nx
            y0, y1 = -B + j * 2 * B / nz, -B + (j + 1) * 2 * B / nz  # Blender y
            t = bmesh.new()
            t.from_mesh(me_all)
            gone = [f for f in t.faces if not (x0 - 1e-4 <= f.calc_center_median().x <= x1 + 1e-4 and y0 - 1e-4 <= f.calc_center_median().y <= y1 + 1e-4)]
            bmesh.ops.delete(t, geom=gone, context="FACES")
            if not t.faces:
                t.free()
                continue
            # the painted area: the tile plus `pad` texels each side (ex, ey studs), so the tile's edge is a texel edge
            res = 128 if FAST else px
            margin = max(2.0, pad * res / px)  # texels at this resolution (FAST previews are 128 px)
            ex = (x1 - x0) * margin / (res - 2 * margin)
            ey = (y1 - y0) * margin / (res - 2 * margin)
            uv = t.loops.layers.uv.new("UVMap")
            for f in t.faces:
                for lp in f.loops:
                    co = lp.vert.co
                    lp[uv].uv = ((co.x - x0 + ex) / (x1 - x0 + 2 * ex), (co.y - y0 + ey) / (y1 - y0 + 2 * ey))
            obj = make(f"Map_{map_name}_{element}", f"{material}_{i + 1}{j + 1}", key, t, "Map")
            if DRY:
                continue
            u = (np.arange(res) + 0.5) / res
            X = np.broadcast_to(x0 - ex + u[None, :] * (x1 - x0 + 2 * ex), (res, res))
            Yb = np.broadcast_to((y0 - ey + u * (y1 - y0 + 2 * ey))[:, None], (res, res))
            col = painter(X, -Yb)  # rows run up the image = Blender +y; arena-local z = -y
            path = P.save_png(os.path.join(TEX, f"{obj.name}_Color.png"), np.clip(col, 0, 1))
            obj.data.materials.append(S.image_material(f"{obj.name}_Painted", {"colour": path}, roughness=0.95))
            PAINTED.append(obj)
            print("PAINTED", obj.name, res, "px", flush=True)
    bpy.data.meshes.remove(me_all)


def voronoi(X, Z, cell, seed, jitter=0.85):
    """Cell id, distance to the nearest seed, and distance to the cell's border (approximate: second nearest minus
    nearest) for a jittered grid of seeds `cell` studs apart. Pure numpy: each pixel looks at its 3 x 3 grid cells."""
    gx, gz = np.floor(X / cell).astype(np.int64), np.floor(Z / cell).astype(np.int64)
    best = np.full(X.shape, 1e9)
    second = np.full(X.shape, 1e9)
    bid = np.zeros(X.shape, dtype=np.int64)
    sx = np.zeros(X.shape)
    sz = np.zeros(X.shape)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            ci, cj = gx + di, gz + dj
            px = (ci + P.hash01(seed, ci, cj) * jitter + (1 - jitter) / 2) * cell
            pz = (cj + P.hash01(seed + 7, ci, cj) * jitter + (1 - jitter) / 2) * cell
            d = np.hypot(X - px, Z - pz)
            closer = d < best
            second = np.where(closer, best, np.minimum(second, d))
            bid = np.where(closer, ci * 100003 + cj, bid)
            sx = np.where(closer, px, sx)
            sz = np.where(closer, pz, sz)
            best = np.where(closer, d, best)
    return bid, best, second - best, sx, sz


# --- kit placements (cloned in Studio from ServerStorage.HT_PropKit) ----------------------------------------------
PLACE = []  # {"asset", "x", "y", "z", "yaw", "scale"[, "tint"]}: arena-local Roblox
COLLISION = {"floor": None, "boxes": []}
DATA = {}  # anything the game needs to know about a map's pieces (a windmill's hub, ...): landmarks.json


def put(asset, x, z, y, yaw=0.0, scale=1.0, tint=None):
    p = {"asset": asset, "x": round(x, 2), "y": round(y, 2), "z": round(z, 2), "yaw": round(yaw, 3), "scale": round(scale, 3)}
    if tint:
        p["tint"] = list(tint)
    PLACE.append(p)


GROUND = ("_Island_Grass", "_Floor_", "_Path_", "_Land_")  # meshes a kit piece may stand on
BUILDINGS = ("_Village_", "_Farm_", "_FarHouse_", "_Windmill_")


def seat_placements():
    """Puts every kit piece on the real ground under it, by raycasting the built meshes (Map 1's pieces were placed
    from a height function and 33 of 85 floated or sank by up to 3.4 studs, 2026-11-22). A piece under a building's
    roof is dropped; one under a hedge or a crop strip stands on the ground beneath it."""
    bpy.context.view_layer.update()
    ground = [o for _, _, o in REGISTRY if any(g in o.name for g in GROUND)]
    dg = bpy.context.evaluated_depsgraph_get()
    kept, dropped = [], 0
    for p in PLACE:
        top = Vector((p["x"], -p["z"], p["y"] + 80.0))
        hit, _loc, _n, _i, obj, _m = bpy.context.scene.ray_cast(dg, top, Vector((0, 0, -1)), distance=600)
        if hit and any(b in obj.name for b in BUILDINGS):
            dropped += 1
            continue
        best = None
        for o in ground:
            inv = o.matrix_world.inverted()
            ok, loc, _nrm, _idx = o.ray_cast(inv @ top, (inv.to_3x3() @ Vector((0, 0, -1))).normalized(), distance=600)
            if ok:
                z = (o.matrix_world @ loc).z
                best = z if best is None else max(best, z)
        if best is None:
            dropped += 1
            continue
        p["y"] = round(best, 2)
        kept.append(p)
    PLACE[:] = kept
    print("SEATED", len(kept), "DROPPED", dropped, flush=True)


def floor_collision(top=0.0, thick=4.0, n=128):
    """The fighting surface's collider: the oval as an n-gon (0.11 studs off the true oval at most), a slab `thick`
    deep. The Studio builder fills it with wedges."""
    COLLISION["floor"] = {
        "top": top,
        "thick": thick,
        "poly": [[round(A * math.cos(i / n * math.tau), 3), round(B * math.sin(i / n * math.tau), 3)] for i in range(n)],
    }


# --- export ---------------------------------------------------------------------------------------------------
def export(map_name):
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
        tex = os.path.join(TEX, f"{o.name}_Color.png")
        size = (os.path.getsize(tex) if os.path.exists(tex) else 0) + len(o.data.polygons) * 110
        if current and budget + size > 13e6:
            groups.append(current)
            current, budget = [], 0
        current.append(o)
        budget += size
    groups.append(current)
    manifest = {"map": map_name, "oval": {"semiX": A, "semiZ": B}, "meshes": {}, "files": []}
    for index, group in enumerate(groups, 1):
        for o in bpy.context.view_layer.objects:
            o.select_set(o in group)
        path = os.path.join(up, f"{map_name.lower()}_{index}.glb")
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
            manifest["meshes"][o.name] = {  # arena-local Roblox axes: x, y = Blender z, z = -Blender y
                "file": index, "key": o["kit_key"], "x": round(mid[0], 3), "y": round(mid[2], 3), "z": round(-mid[1], 3),
                "sx": round(hi[0] - lo[0], 3), "sy": round(hi[2] - lo[2], 3), "sz": round(hi[1] - lo[1], 3), "tris": tris,
            }
        print("GLB", os.path.basename(path), manifest["files"][-1]["mb"], "MB", len(group), "meshes", flush=True)
    manifest["triangles"] = sum(m["tris"] for m in manifest["meshes"].values())
    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8"), indent=1)
    write_data()
    print("TRIANGLES", manifest["triangles"], "MESHES", len(manifest["meshes"]), "KIT PIECES", len(PLACE), flush=True)


def write_data():
    json.dump(COLLISION, open(os.path.join(OUT, "collision.json"), "w", encoding="utf-8"), indent=1)
    json.dump(PLACE, open(os.path.join(OUT, "placements.json"), "w", encoding="utf-8"), indent=1)
    json.dump(DATA, open(os.path.join(OUT, "landmarks.json"), "w", encoding="utf-8"), indent=1)


def check():
    """Hard limits: under 20,000 triangles and under 2,048 studs on every axis, per mesh."""
    bad = []
    for _, _, o in REGISTRY:
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        dims = o.dimensions
        if tris > 20000 or max(dims) > 2040:
            bad.append((o.name, tris, tuple(round(d) for d in dims)))
    return bad


# --- the review scene: the live lobby and the kit's pieces beside the map (never exported) ------------------------
def preview_collection():
    col = bpy.data.collections.get("Preview")
    if col is None:
        col = bpy.data.collections.new("Preview")
        bpy.context.scene.collection.children.link(col)
    return col


def _import_glb(path, col):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)
    return new


def add_lobby():
    """The live lobby (design/lobby/out/village/export) where it stands: lobby-local origin at (0, LOBBY_FLOOR_Y,
    LOBBY_EDGE_Z) arena-local."""
    col = preview_collection()
    exp = os.path.join(LOBBY, "out", "village", "export")
    if not os.path.isdir(exp):
        print("NO LOBBY EXPORT", exp, flush=True)
        return
    for f in sorted(os.listdir(exp)):
        if f.endswith(".glb"):
            for o in _import_glb(os.path.join(exp, f), col):
                if o.parent is None:
                    o.location += W(0.0, LOBBY_EDGE_Z, LOBBY_FLOOR_Y)


def add_kit():
    """Clones of the scenery kit's pieces at PLACE, for the renders only (Studio clones them from HT_PropKit)."""
    if not PLACE:
        return
    up = os.path.join(MAPS, "out", "gnomon", "upload")
    man = json.load(open(os.path.join(up, "kit_manifest.json"), encoding="utf-8"))["assets"]
    src_col = bpy.data.collections.new("KitSource")
    bpy.context.scene.collection.children.link(src_col)
    parts = {}
    for f in ("kit_trees.glb", "kit_plants.glb", "kit_flowers.glb", "kit_rocks.glb", "kit_ruins.glb"):
        for o in _import_glb(os.path.join(up, f), src_col):
            parts[o.name] = o
    src_col.hide_render = True
    src_col.hide_viewport = True
    col = preview_collection()
    for p in PLACE:
        info = man.get(p["asset"])
        if not info:
            continue
        sx, sy, sz = info["spot"]
        spot = Vector((sx, -sz, sy))
        m = Matrix.Translation(W(p["x"], p["z"], p["y"])) @ Matrix.Rotation(p["yaw"], 4, "Z") @ Matrix.Scale(p["scale"], 4) @ Matrix.Translation(-spot)
        for name in info["parts"]:
            o = parts.get(name)
            if o is None or o.type != "MESH":
                continue
            d = o.copy()
            col.objects.link(d)
            d.matrix_world = m @ o.matrix_world


# --- the run --------------------------------------------------------------------------------------------------
def standard_cameras():
    eye = 5.5
    sx, sz = A * SPAWN_SHARE, B * SPAWN_SHARE
    return {
        # behind a fighter on the spawn ring at the lobby side, looking north across the floor
        "Gameplay": C.camera("Gameplay", W(-30, sz + 18, eye + 9), W(20, -60, 0), lens=24),
        # a fighter's eye at the east end, looking along the long axis
        "Fighter": C.camera("Fighter", W(sx + 10, 10, eye), W(-80, -20, 2), lens=24),
        # standing near the north rim, looking out and down
        "Edge": C.camera("Edge", W(-30, -(B - 22), eye + 2), W(-140, -(B + 700), -200), lens=24),
        # launched off the west end, below the rim, looking back up at the lip
        "Recovery": C.camera("Recovery", W(-(A + 34), -16, -16), W(-(A - 8), 0, 1), lens=22),
        # from the live lobby's viewing balcony, looking at the arena
        "Lobby": C.camera("Lobby", W(-20, LOBBY_EDGE_Z + 8, LOBBY_FLOOR_Y + 6), W(0, -60, -14), lens=22),
        "Over": C.camera("Over", W(420, 520, 300), W(0, -80, -60), lens=24),
    }


def run(map_name, builders, sun=(225, 38), cameras=None):
    C.reset()
    C.sky_and_sun(*sun)
    os.makedirs(TEX, exist_ok=True)
    for fn in builders:
        fn()
        print("BUILT", fn.__name__, flush=True)
    flush(map_name)
    seat_placements()
    floor_collision()
    bad = check()
    for b in bad:
        print("OVER LIMIT", b, flush=True)
    cams = (cameras or standard_cameras)()
    scene = bpy.context.scene
    total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for _, _, o in REGISTRY)
    if DRY:
        for asset, key, obj in REGISTRY:
            base = PAL[key][0]
            obj.color = (float(base[0]) ** (1 / 2.2), float(base[1]) ** (1 / 2.2), float(base[2]) ** (1 / 2.2), 1.0)
            print(f"MESH {obj.name}: {sum(len(p.vertices) - 2 for p in obj.data.polygons)} tris", flush=True)
        print("TRIANGLES", total, "MESHES", len(REGISTRY), "KIT PIECES", len(PLACE), flush=True)
        write_data()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{map_name.lower()}_dry.blend"))
        if not NO_RENDER:
            add_lobby()
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
        if obj in PAINTED:
            continue
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        big = max(obj.dimensions)
        px = 128 if FAST else (256 if tris < 600 and big < 60 else (512 if tris < 4000 and big < 200 else 1024))
        # far backdrop (centre past FAR_TEX studs): at most 512 px. A 300-stud island 1,300 studs out covers a few
        # hundred pixels of a screen, so 1024 only costs phones memory (Quarry 2026-11-21: 44 of 78 were far;
        # retex.py shrank them after its build)
        co = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        if math.hypot(sum(c.x for c in co) / 8, sum(c.y for c in co) / 8) > FAR_TEX:
            px = min(px, 512)
        if "px" in obj.keys() and not FAST:  # a map can set its own size (far land: big flat facets need few pixels)
            px = int(obj["px"])
        K["bake_paint"](obj, px)
        print(f"PAINTED {obj.name}: {tris} tris, {px}px", flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{map_name.lower()}.blend"))
    export(map_name)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{map_name.lower()}.blend"))
    if not NO_RENDER:
        add_lobby()
        add_kit()
        scene.cycles.samples = 32
        try:
            scene.cycles.use_denoising = True
        except AttributeError:
            pass
        C.render_all(OUT, map_name.lower(), cams, resolution=(1280, 720))
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{map_name.lower()}_review.blend"))
    print("DONE", map_name, "TRIANGLES", total, flush=True)
