"""Physical detail for the floating-island maps (rework brief 2026-11-10), shared by all three arenas.

The brief asked for depth from geometry instead of flat paint:
- `grass`: real modelled tufts, a few chunky tapered blades each, short in the centre and dense round
  the perimeter. Built from tuft sites that the meadow painter also reads (`tuft_sites` / `tuft_dabs`),
  so every tuft has a darker dab of ground under it. The tufts are merged into a dozen sector meshes
  (one draw call each, about 8,000 triangles) coloured from one small gradient texture: base dark,
  tip light, cool to warm across. Non-colliding, no shadows, for a 30-player server.
- `turf_lip`: a thick rounded grass lip round the oval, hanging over the stone in lobes. Its top sits
  just under the fighting surface, so the walkable edge is unchanged.
- `plank_shelf`, `roots`: modelled timber (planks with seams, pale cut ends, a raised trim) and roots.
- `fragments`: small floating rocks with a grass cap, at varied heights and distances.
- `cartoon_clouds`: rounded clouds of a few joined masses, a broad flattened underside, white tops and
  pale-blue undersides in two flat tones (the user's image 3).
- `outlines`: thin cartoon outlines as inverted hulls (a copy of the mesh pushed out along its normals,
  faces flipped, dark single colour). Roblox draws only front faces, so only the rim of the hull shows
  round the silhouette. Vault: "Voxel Art - Studs Outlines and Style Kits" (inverted hull works at any
  count; Highlight is capped per client). Line width grows with distance from the arena so the line
  reads about the same weight from the fighting camera.

`LOBBY_VIEW` is the corridor between the lobby and the arena that must stay open (brief: lobby
placement and arena view). Every placement here is checked against it, and `corridor_report` lists
anything in the Export collection that rises into it.
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import common as C
import paint as P
import surfaces as S

# --- the lobby's view corridor ---------------------------------------------------------------------
# Blender coordinates (Roblox +Z is Blender -Y). The lobby platform is X -90..90, Roblox Z 170..410,
# so Blender Y -170..-410; its viewing edge faces the arena. Scenery may pass under the corridor
# (below FLOOR) but never rise into it.
LOBBY_VIEW = dict(x=(-160.0, 160.0), y=(-460.0, -90.0), floor=-45.0)
if C.MAP == "gnomon":
    # 2026-11-10: the doubled Gnomon oval (half-depth 176) and the lobby moved out to Roblox Z 250..490 and
    # raised 11 studs (GameConfig.Lobby): the corridor runs from the lobby back to the arena's near edge and
    # spans the oval's width, so the near ring-out edge and floor stay in view from the spawn and both ends.
    LOBBY_VIEW = dict(x=(-240.0, 240.0), y=(-520.0, -150.0), floor=-45.0)


def in_lobby_view(x, y, z_top):
    v = LOBBY_VIEW
    return v["x"][0] < x < v["x"][1] and v["y"][0] < y < v["y"][1] and z_top > v["floor"]


def corridor_report():
    """Export meshes whose bounds rise into the lobby's view corridor (the arena itself excluded)."""
    v = LOBBY_VIEW
    hits = []
    for obj in C.collection("Export").objects:
        if obj.type != "MESH" or obj.name.startswith(("Meadow_", "Rim_", "Lip_", "Grass_", "Strata_", "Cliff_")):
            continue
        co = np.array([obj.matrix_world @ Vector(c) for c in obj.bound_box])
        lo, hi = co.min(axis=0), co.max(axis=0)
        if hi[0] > v["x"][0] and lo[0] < v["x"][1] and hi[1] > v["y"][0] and lo[1] < v["y"][1] and hi[2] > v["floor"]:
            # bounds overlap; check the vertices themselves
            me = obj.data
            pts = np.empty((len(me.vertices), 3))
            me.vertices.foreach_get("co", pts.ravel())
            inside = (pts[:, 0] > v["x"][0]) & (pts[:, 0] < v["x"][1]) & (pts[:, 1] > v["y"][0]) & (pts[:, 1] < v["y"][1]) & (pts[:, 2] > v["floor"])
            if inside.any():
                hits.append((obj.name, int(inside.sum())))
    return hits


# --- grass -----------------------------------------------------------------------------------------
INNER_A, INNER_B = C.A - C.RIM, C.B - C.RIM
CLEAR = 0.45  # share of the radius where tufts stay short (feet and landings read)


def _rc(x, y):
    return math.sqrt((x / INNER_A) ** 2 + (y / INNER_B) ** 2)


def _h(seed, i, j):
    return float(P.hash01(seed, np.float64(i), np.float64(j)))


def tuft_sites(seed=401):
    """Every tuft: (x, y, size, blades, turn, tone). Two jittered grids: an even one over the whole
    meadow and a finer one in the outer band, so the perimeter is dense and the centre sparse."""
    sites = []
    for cell, sd, band in ((3.3, seed, False), (2.2, seed + 50, True)):
        ni, nj = int(INNER_A / cell) + 2, int(INNER_B / cell) + 2
        for i in range(-ni, ni):
            for j in range(-nj, nj):
                x = (i + 0.5 + (_h(sd, i, j) - 0.5) * 0.85) * cell
                y = (j + 0.5 + (_h(sd + 1, i, j) - 0.5) * 0.85) * cell
                rc = _rc(x, y)
                if rc > 0.985:
                    continue
                edge = float(P.smoothstep(0.55, 0.93, rc))
                chance = (0.62 * float(P.smoothstep(0.78, 0.9, rc))) if band else (0.5 + 0.38 * edge)
                if _h(sd + 2, i, j) > chance:
                    continue
                short = 0.55 + 0.35 * _h(sd + 3, i, j)
                tall = 1.5 + 1.1 * _h(sd + 3, i, j)
                size = short + (tall - short) * float(P.smoothstep(CLEAR, 0.88, rc))
                blades = 3 + int(_h(sd + 4, i, j) * 2.99) if size > 1.2 else 3 + int(_h(sd + 4, i, j) * 1.99)
                sites.append((x, y, size, blades, _h(sd + 5, i, j) * math.tau, _h(sd + 6, i, j)))
    return sites


_SITES = None


def sites():
    global _SITES
    if _SITES is None:
        _SITES = tuft_sites()
    return _SITES


def tuft_dabs(X, Y, col, dark, strength=0.38):
    """Darkens a soft dab of ground under every tuft (painter side). X, Y are a tile's stud grids."""
    s = np.array(sites())
    x0, x1, y0, y1 = X.min() - 3, X.max() + 3, Y.min() - 3, Y.max() + 3
    s = s[(s[:, 0] > x0) & (s[:, 0] < x1) & (s[:, 1] > y0) & (s[:, 1] < y1)]
    shade = np.zeros(X.shape)
    for x, y, size, _, turn, _ in s:
        r = 0.55 + 0.45 * size
        ix = slice(*np.searchsorted(X[0], (x - r - 0.5, x + r + 0.5)))
        iy = slice(*np.searchsorted(Y[:, 0], (y - r - 0.5, y + r + 0.5)))
        if ix.start == ix.stop or iy.start == iy.stop:
            continue
        dx, dy = X[iy, ix] - x, Y[iy, ix] - y
        d = np.sqrt((dx / r) ** 2 + (dy / (r * 0.8)) ** 2)
        shade[iy, ix] = np.maximum(shade[iy, ix], 1 - P.smoothstep(0.55, 1.0, d))
    return P.mix(col, dark, strength * shade)


# Grass colours, sRGB: (cool, warm) per height
GRASS_ROWS = [  # softened 2026-11-10: tips no longer near-white lime; the base stays dark for depth
    ((34, 96, 74), (66, 110, 56)),  # base, in the ground
    ((60, 136, 88), (102, 152, 70)),
    ((100, 172, 100), (144, 184, 88)),
    ((154, 204, 128), (194, 212, 124)),  # tip
]


def grass_texture(tex_dir, name="Grass_Palette", n=128):
    """One small gradient: v = height up the blade, u = cool to warm. Saved as a painted map."""
    os.makedirs(tex_dir, exist_ok=True)
    v = np.linspace(0, 1, n)[:, None]
    u = np.linspace(0, 1, n)[None, :]
    rows = len(GRASS_ROWS) - 1
    k = np.clip((v * rows).astype(int), 0, rows - 1)
    f = v * rows - k
    out = np.zeros((n, n, 3))
    for c in range(3):
        cool = np.array([r[0][c] for r in GRASS_ROWS], float) / 255.0
        warm = np.array([r[1][c] for r in GRASS_ROWS], float) / 255.0
        lo = cool[k] + (warm[k] - cool[k]) * u
        hi = cool[k + 1] + (warm[k + 1] - cool[k + 1]) * u
        out[..., c] = lo + (hi - lo) * f
    lin = P.srgb_to_linear(out)
    path = P.save_png(os.path.join(tex_dir, f"{name}_Color.png"), lin)
    return S.image_material(name, {"colour": path}, roughness=0.95)


def _blade(bm, uv, base, tip_dir, length, width, bend_dir, bend, tone):
    """A chunky tapered blade: a three-sided stalk from a triangle at the base to a smaller one at the
    middle, then to a point. 9 triangles."""
    up = Vector(tip_dir).normalized()
    side = Vector(bend_dir)
    mid = base + up * (length * 0.5) + side * (bend * 0.35)
    tip = base + up * length + side * bend
    u0 = up.cross(Vector((0, 0, 1)) if abs(up.z) < 0.99 else Vector((1, 0, 0)))
    if u0.length < 1e-6:
        u0 = Vector((1, 0, 0))
    u0.normalize()
    u1 = up.cross(u0).normalized()
    rings = []
    for c, w in ((base, width), (mid, width * 0.62)):
        ring = []
        for k in range(3):
            a = k / 3 * math.tau
            ring.append(bm.verts.new(c + (u0 * math.cos(a) + u1 * math.sin(a)) * w))
        rings.append(ring)
    t = bm.verts.new(tip)
    faces = []
    for k in range(3):
        n = (k + 1) % 3
        faces.append(((rings[0][k], rings[0][n], rings[1][n], rings[1][k]), (0.0, 0.0, 0.5, 0.5)))
        faces.append(((rings[1][k], rings[1][n], t), (0.5, 0.5, 1.0)))
    for vs, vv in faces:
        f = bm.faces.new(vs)
        for loop, v in zip(f.loops, vv):
            loop[uv].uv = (tone, max(0.02, min(0.98, v)))


def grass(tex_dir, sectors=12, z=-0.15):
    """The tufts, merged by sector. Returns the objects."""
    mat = grass_texture(tex_dir)
    bms = [bmesh.new() for _ in range(sectors)]
    uvs = [b.loops.layers.uv.new("UVMap") for b in bms]
    wind = Vector((0.45, 0.2, 0))
    for x, y, size, blades, turn, tone in sites():
        k = int(((math.atan2(y / INNER_B, x / INNER_A) + math.pi) / math.tau) * sectors) % sectors
        bm, uv = bms[k], uvs[k]
        for b in range(blades):
            a = turn + b / blades * math.tau + (_h(611 + b, x * 7, y * 7) - 0.5) * 0.9
            out = Vector((math.cos(a), math.sin(a), 0))
            spread = 0.18 * size
            base = Vector((x, y, z)) + out * spread
            lean = 0.18 + 0.32 * _h(613 + b, x * 5, y * 5)
            length = size * (0.75 + 0.5 * _h(617 + b, x * 3, y * 3)) * (1.25 if b == 0 else 1.0)
            tip_dir = Vector((0, 0, 1)) + out * lean + wind * 0.25
            t = min(0.97, max(0.03, tone + (_h(619 + b, x, y) - 0.5) * 0.3))
            _blade(bm, uv, base, tip_dir, length, 0.14 + 0.07 * size, out + wind, 0.18 * length, t)
    objs = []
    for k, bm in enumerate(bms):
        if not bm.verts:
            bm.free()
            continue
        obj = C.mesh_object(f"Grass_Tufts_{k + 1:02d}", bm, mat, smooth=True)
        obj["no_shadow"] = True
        objs.append(obj)
    return objs


# --- the thick turf lip ----------------------------------------------------------------------------
LIP_ROWS = [  # v down the profile: lip highlight, leaf, drape, deep drape (sRGB)
    # 2026-11-10 (user: shade 9 of the matcha reference, a very deep forest green): the lip keeps a lighter
    # mossy line on top so the ring-out edge reads against the dark ground
    (78, 104, 50),
    (36, 58, 20),
    (20, 38, 13),
    (14, 30, 11),
    (10, 22, 10),
]


def lip_texture(tex_dir, name="Lip_Palette", n=128):
    os.makedirs(tex_dir, exist_ok=True)
    # image row 0 is the bottom (uv y = 0); the lip's uv y is 1 at the top of the profile
    v = 1.0 - np.linspace(0, 1, n)  # v down the profile for each image row
    rows = len(LIP_ROWS) - 1
    k = np.clip((v * rows).astype(int), 0, rows - 1)
    f = v * rows - k
    cols = np.array(LIP_ROWS, float) / 255.0
    line = cols[k] + (cols[k + 1] - cols[k]) * f[:, None]
    img = np.repeat(line[:, None, :], n, axis=1)
    path = P.save_png(os.path.join(tex_dir, f"{name}_Color.png"), P.srgb_to_linear(img))
    return S.image_material(name, {"colour": path}, roughness=0.95)


def turf_lip(tex_dir, a=C.A, b=C.B, segs=int(360 * C.SCALE), rng=None, top=-0.12):
    """A rounded roll of turf round the oval, outside the rim's outer face by under a stud, and a skirt
    hanging over the stone in lobes. Profile (scale of the oval, depth): rounded over the edge, then
    drawn in under. v of the texture runs down the profile."""
    mat = lip_texture(tex_dir)
    prof = [(0.990, top, 0.0), (1.0035, top - 0.55, 0.12), (1.0075, top - 1.6, 0.3), (1.0065, top - 2.7, 0.48), (1.0015, top - 3.6, 0.64)]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rows = []
    for i in range(segs):
        t = i / segs * math.tau
        x, y = math.cos(t), math.sin(t)
        lobe = 1.2 + 1.3 * abs(math.sin(t * 23 + 1.3 * math.sin(t * 5))) + (rng.uniform(-0.3, 0.3) if rng else 0)
        pts = [(s, z, v) for s, z, v in prof] + [(0.994, top - 3.6 - lobe, 0.82), (0.984, top - 3.9 - lobe * 1.25, 1.0)]
        # the profile's offsets are studs from the original oval (a bigger oval keeps the same roll, not a
        # wider one): s - 1 is a share of ORIGINAL_OVAL, added to this oval's own semi-axes
        a0, b0 = C.ORIGINAL_OVAL
        rows.append([(bm.verts.new(((a + (s - 1) * a0) * x, (b + (s - 1) * b0) * y, z)), v) for s, z, v in pts])
    for i in range(segs):
        n = (i + 1) % segs
        for k in range(len(rows[i]) - 1):
            # outward-facing: going round anticlockwise and down the profile
            quad = (rows[i][k], rows[i][k + 1], rows[n][k + 1], rows[n][k])
            f = bm.faces.new([q[0] for q in quad])
            for loop, (vert, v), u in zip(f.loops, quad, (i / segs, i / segs, (i + 1) / segs, (i + 1) / segs)):
                loop[uv].uv = (u, 1.0 - v)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # recalc can't know inside from outside on an open band: make sure the faces look outward
    for f in bm.faces:
        c = f.calc_center_median()
        if f.normal.x * c.x / a ** 2 + f.normal.y * c.y / b ** 2 < 0:
            f.normal_flip()
    return C.mesh_object("Lip_Turf", bm, mat, smooth=True)


# --- timber and roots ------------------------------------------------------------------------------
def plank_box(bm, reg, p0, p1, width, thick, up=(0, 0, 1), tone=0.0):
    """A plank from p0 to p1 (centre line), registered for the wood painter so its grain runs along it
    and its ends paint as pale cut ends."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    upv = Vector(up)
    w = d.cross(upv).normalized() * (width / 2)
    h = w.cross(d).normalized() * (thick / 2)
    corners = []
    for p in (p0, p1):
        corners.append([bm.verts.new(p + sw * w + sh * h) for sw, sh in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    a, b = corners
    faces = [bm.faces.new(list(reversed(a))), bm.faces.new(b)]
    for k in range(4):
        n = (k + 1) % 4
        faces.append(bm.faces.new((a[k], a[n], b[n], b[k])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)  # a closed box: outward for sure (Roblox culls the rest)
    reg.append((tuple(p0), tuple(p1), max(width, thick) / 2, tone))


def plank_shelf(bm, reg, centre, out, along, rng, n=5, length=8.0, width=1.5, gap=0.22, z=-6.4):
    """A small deck of planks laid across beam ends: seams between planks, cut ends, and a raised
    trim board along the outer end. `out` and `along` are unit vectors (outward, tangent)."""
    c = Vector(centre)
    total = n * width + (n - 1) * gap
    for i in range(n):
        off = -total / 2 + width / 2 + i * (width + gap)
        jag = rng.uniform(-0.35, 0.35)
        p0 = c + along * off - out * (length * 0.5) + Vector((0, 0, z + rng.uniform(-0.05, 0.05)))
        p1 = c + along * off + out * (length * 0.5 + jag) + Vector((0, 0, z))
        plank_box(bm, reg, p0, p1, width, 0.5)
    # the trim: a board on edge across the outer ends, a little proud
    tz = z + 0.45
    tc = c + out * (length * 0.5 - 0.4) + Vector((0, 0, tz))
    plank_box(bm, reg, tc - along * (total / 2 + 0.3), tc + along * (total / 2 + 0.3), 0.45, 1.0, up=(0, 0, 1))


def roots(bm, reg, rng, count=14, a=C.A, b=C.B, tube=None):
    """Roots hanging from under the turf lip down the top of the cliff, hugging it."""
    for i in range(count):
        t = (i + rng.uniform(-0.3, 0.3)) / count * math.tau
        ct, st = math.cos(t), math.sin(t)
        pts, radii = [], []
        z = -3.0
        s = 0.986
        drift = rng.uniform(-0.03, 0.03)
        for k in range(4):
            pts.append((a * s * math.cos(t + drift * k), b * s * math.sin(t + drift * k), z))
            radii.append(0.75 * (1 - k * 0.22))
            z -= rng.uniform(3.5, 5.5)
            s -= rng.uniform(0.006, 0.014)
        tube(bm, reg, pts, radii, 5, rng, tone=1.0, caps=(False, True))


# --- floating rock fragments -----------------------------------------------------------------------
def fragments(G, spots, rng, islet, cap_frac=0.35):
    """Small floating rocks. Each spot is (x, y, z, r); the larger ones carry a grass cap."""
    for x, y, z, r in spots:
        if in_lobby_view(x, y, z + r * 0.3):
            raise ValueError(f"fragment at {(x, y, z)} rises into the lobby's view")
        islet(G, (x, y, z), r, r * rng.uniform(0.75, 0.95), r * rng.uniform(1.3, 1.9), rng, segs=9, cap=max(1.2, r * cap_frac * 0.4))


# --- cartoon clouds --------------------------------------------------------------------------------
CLOUD_TOP = (255, 255, 255)
CLOUD_UNDER = (204, 224, 246)


def cloud_material():
    """Two flat tones split by the surface's facing: white where it looks up or out, pale blue where it
    turns under. Baked to the texture on export."""
    mat, nt, bsdf = C.new_material("CartoonCloud")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = C.separate(nt, geo.outputs["Normal"])
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.interpolation = "CONSTANT"
    r.color_ramp.elements[0].position = 0.0
    r.color_ramp.elements[0].color = tuple(P.srgb_to_linear(np.array(CLOUD_UNDER) / 255.0)) + (1,)
    r.color_ramp.elements[1].position = 0.47  # normal z of about -0.06 maps to 0.47
    r.color_ramp.elements[1].color = tuple(P.srgb_to_linear(np.array(CLOUD_TOP) / 255.0)) + (1,)
    mapr = nt.nodes.new("ShaderNodeMapRange")
    mapr.inputs["From Min"].default_value = -1.0
    mapr.inputs["From Max"].default_value = 1.0
    nt.links.new(sep.outputs["Z"], mapr.inputs["Value"])
    nt.links.new(mapr.outputs["Result"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def _mass(bm, centre, r, flat_z, squash=0.9, subdiv=2):
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    for v in res["verts"]:
        p = v.co
        z = p.z * squash
        q = Vector((centre[0] + p.x, centre[1] + p.y, centre[2] + z))
        if q.z < flat_z:  # a broad, slightly rounded underside
            q.z = flat_z - (flat_z - q.z) * 0.18
        v.co = q


def cartoon_cloud(name, centre, length, rng, kind="compact", heading=0.0, mat=None):
    """One cloud: a row of joined masses. 'compact': a big middle and two or three smaller sides.
    'stretched': a big head, a run of smaller masses and a thin tail of flat wisps."""
    if in_lobby_view(centre[0], centre[1], centre[2] + length * 0.2):
        raise ValueError(f"cloud {name} sits in the lobby's view")
    bm = bmesh.new()
    cx, cy, cz = centre
    ch, sh = math.cos(heading), math.sin(heading)
    flat = cz - length * 0.07
    if kind == "compact":
        masses = [(0.0, 0.0, 0.22), (-0.28, 0.03, 0.15), (0.3, -0.02, 0.16), (-0.12, 0.08, 0.17), (0.14, 0.1, 0.14)]
        if rng.random() < 0.5:
            masses.append((-0.45, -0.02, 0.09))
    else:
        masses = [(0.18, 0.0, 0.16), (0.32, 0.04, 0.12), (0.02, 0.06, 0.13), (-0.12, 0.0, 0.1), (0.42, -0.02, 0.08)]
        masses += [(-0.22 - 0.07 * k, -0.01 * k, 0.07 * (1 - k * 0.12)) for k in range(4)]
    for ox, oz, rr in masses:
        side = rng.uniform(-0.05, 0.05) * length
        x = ox * length * (1 + rng.uniform(-0.05, 0.05))
        r = rr * length * rng.uniform(0.92, 1.08)
        px, py = cx + x * ch - side * sh, cy + x * sh + side * ch
        _mass(bm, (px, py, flat + r * 0.55 + oz * length), r, flat, subdiv=4 if rr >= 0.12 else 3)
    if kind == "stretched":  # the thin wisp at the end of the tail
        for k in range(3):
            x = (-0.5 - 0.06 * k) * length
            r = length * (0.045 - 0.008 * k)
            px, py = cx + x * ch, cy + x * sh
            _mass(bm, (px, py, flat + r * 0.2), r, flat + r * 0.05, squash=0.45)
    return C.mesh_object(name, bm, mat, smooth=True)


def cartoon_clouds(spots, rng):
    mat = cloud_material()
    objs = []
    for i, (x, y, z, length, kind, heading) in enumerate(spots):
        objs.append(cartoon_cloud(f"Cloud_{i + 1:02d}", (x, y, z), length, rng, kind, math.radians(heading), mat))
    return objs


# --- outlines --------------------------------------------------------------------------------------
LINE = (38, 32, 52)  # deep violet-brown, not black: reads as ink against both sky and grass
_LINE_MAT = None


def line_width(obj, base=0.28, per_stud=0.0032, cap=2.0):
    co = np.array([obj.matrix_world @ Vector(c) for c in obj.bound_box])
    centre = (co.min(axis=0) + co.max(axis=0)) / 2
    d = math.hypot(centre[0], centre[1])
    return min(cap, base + per_stud * max(0.0, d - 60))


def outline(obj, width=None, merge=0.02):
    """An inverted hull for `obj` in the Export collection, named <obj>_Line."""
    global _LINE_MAT
    if _LINE_MAT is None or _LINE_MAT.name not in bpy.data.materials:
        _LINE_MAT = C.flat_material("Outline", tuple(float(c) for c in P.rgb(*LINE)), 1.0)
        # Roblox draws front faces only; Blender must do the same or the hull hides the object
        _LINE_MAT.use_backface_culling = True
    w = width if width is not None else line_width(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=merge)
    bm.normal_update()  # keeps the mesh's own winding: it already renders right in Roblox
    for v in bm.verts:
        n = v.normal
        if n.length > 1e-6:
            v.co += n * w
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    for layer in list(bm.loops.layers.uv):
        bm.loops.layers.uv.remove(layer)
    line = C.mesh_object(f"{obj.name}_Line", bm, _LINE_MAT)
    line["no_shadow"] = True
    return line


def outline_all(prefixes, skip=(), widths=None):
    """Outlines every Export mesh whose name starts with one of `prefixes`."""
    out = []
    for obj in list(C.collection("Export").objects):
        if obj.type != "MESH" or not obj.name.startswith(prefixes) or obj.name.endswith("_Line"):
            continue
        if any(s in obj.name for s in skip):
            continue
        w = None
        for pre, val in (widths or {}).items():
            if obj.name.startswith(pre):
                w = val
        out.append(outline(obj, w))
    return out
