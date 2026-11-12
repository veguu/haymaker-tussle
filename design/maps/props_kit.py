"""Gnomon Isle's scenery kit (user brief 2026-11-11 with nine references): rocks, trees, bushes, leafy plants,
flowers, a lily pond and overgrown ruins, all in the boulder reference's treatment (image 1): chunky forms with
broad planes, softened bevelled edges, gentle edge highlights, shaded recesses, subtle painted colour
variation, matte. Each object keeps its own colours (green foliage, brown trunks, natural flowers, stone ruins).

    blender -b --factory-startup -P props_kit.py -- [out folder] [--fast] [--only=rocks,trees,...]

Builds every asset in collection "PropKit" (one sub-collection per family), laid out on a review grid, and
saves <out>/gnomon_props.blend. One MESH PER MATERIAL per asset (Roblox: one material a mesh), named
<Asset>_<Part> (Rock_Pillar_Stone, Tree_A_Bark, Tree_A_Leaf, ...). Every asset's pivot is its base centre on
the ground (z = 0), so it sits flush wherever it's placed. Sizes are studs.

PAINT: every mesh is smart-UV'd and baked (Cycles): world position, normal, ambient occlusion and POINTINESS
(convexity). The colour is the palette's base with broad low-frequency variation, lit from above, lighter
on convex edges (the boulder reference's edge highlights), darker in recesses and occlusion (tinted, not
black). No outlines, no fine noise, no gloss.
"""
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ.setdefault("HT_MAP", "gnomon")
import common as C  # noqa: E402
import paint as P  # noqa: E402
import surfaces as S  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
FAST = "--fast" in ARGS
ONLY = next((a[7:].split(",") for a in ARGS if a.startswith("--only=")), None)
OUT = os.path.abspath(next((a for a in ARGS if not a.startswith("--")), os.path.join(HERE, "out", "gnomon", "props")))
TEX = os.path.join(OUT, "textures")


def srgb(r, g, b):
    return P.rgb(r, g, b)


# (base, light, dark) per material, sRGB in, linear out
PAL = {
    "stone_grey": (srgb(194, 190, 180), srgb(240, 236, 224), srgb(122, 118, 120)),
    "stone_cream": (srgb(214, 202, 178), srgb(244, 236, 214), srgb(140, 128, 120)),
    "stone_sand": (srgb(204, 180, 146), srgb(236, 214, 178), srgb(132, 110, 96)),
    "stone_blue": (srgb(174, 178, 184), srgb(222, 226, 230), srgb(108, 110, 122)),
    "ruin": (srgb(184, 176, 160), srgb(228, 222, 204), srgb(112, 104, 104)),
    "bark": (srgb(124, 84, 58), srgb(176, 126, 86), srgb(70, 44, 40)),
    "bark_warm": (srgb(146, 96, 60), srgb(196, 140, 92), srgb(84, 52, 40)),
    # image 4 (2026-11-11): sampled from the user's green, about (64, 120, 74) overall, (102, 160, 106) lit,
    # (48, 93, 52) shaded. Every foliage key stays inside that family; the variants only shift it a little.
    "leaf": (srgb(66, 124, 74), srgb(112, 170, 110), srgb(42, 88, 52)),
    "leaf_deep": (srgb(58, 114, 68), srgb(100, 160, 100), srgb(36, 80, 48)),
    "leaf_lime": (srgb(76, 134, 76), srgb(124, 180, 112), srgb(48, 96, 54)),
    "leaf_olive": (srgb(70, 126, 70), srgb(116, 172, 104), srgb(44, 90, 50)),
    "stem": (srgb(70, 128, 70), srgb(112, 170, 104), srgb(42, 88, 50)),
    "petal_white": (srgb(240, 238, 230), srgb(255, 255, 250), srgb(196, 190, 182)),
    "petal_cream": (srgb(244, 234, 206), srgb(255, 250, 232), srgb(186, 170, 150)),
    "centre": (srgb(244, 184, 36), srgb(255, 222, 96), srgb(196, 118, 20)),
    "lotus": (srgb(222, 124, 188), srgb(250, 196, 232), srgb(150, 70, 140)),
    "lilac": (srgb(176, 136, 222), srgb(214, 186, 246), srgb(110, 80, 160)),
    "coral": (srgb(238, 112, 86), srgb(252, 168, 132), srgb(170, 64, 60)),
    "water": (srgb(88, 170, 200), srgb(150, 214, 232), srgb(48, 116, 160)),
    "pad": (srgb(70, 132, 74), srgb(118, 178, 110), srgb(42, 90, 54)),
}
# how strongly each kind shows the treatment: (broad variation, top light, bevel-edge highlight, per-facet tone,
# occlusion)
FEEL = {
    "stone": (0.08, 0.26, 0.75, 0.14, 0.75),
    "bark": (0.10, 0.20, 0.45, 0.12, 0.70),
    "leaf": (0.08, 0.32, 0.30, 0.16, 0.70),
    "flat": (0.04, 0.22, 0.25, 0.06, 0.45),
    "water": (0.05, 0.25, 0.10, 0.03, 0.20),
}


def feel_of(key):
    if key.startswith(("stone", "ruin")):
        return FEEL["stone"]
    if key.startswith("bark"):
        return FEEL["bark"]
    if key.startswith(("leaf", "pad", "stem")):
        return FEEL["leaf"]
    if key == "water":
        return FEEL["water"]
    return FEEL["flat"]


# --- bmesh helpers --------------------------------------------------------------------------------
def append(dst, src, matrix=Matrix()):
    me = bpy.data.meshes.new("tmp")
    src.to_mesh(me)
    me.transform(matrix)
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)
    src.free()


def unit(rng, up_bias=0.0):
    while True:
        v = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1) + up_bias))
        if 0.2 < v.length <= 1.4:
            return v.normalized()


def chunk(size, rng, cuts=10, bevel=0.13, keep=(0.55, 0.84), base_cut=0.12, subdiv=1):
    """A chunky stone: an ellipsoid sliced by `cuts` random planes into broad flat faces, near-flat faces merged,
    edges softened by a two-step bevel, a flat foot cut `base_cut` up from its bottom. Returns a bmesh centred in
    x, y with its foot at z = 0."""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx / 2, v.co.y * sy / 2, v.co.z * sz / 2)) * rng.uniform(0.97, 1.03)
    for _ in range(cuts):
        d = unit(rng, 0.25)
        # the ellipsoid's true extent along d (its support), so every cut really bites
        reach = math.sqrt((d.x * sx / 2) ** 2 + (d.y * sy / 2) ** 2 + (d.z * sz / 2) ** 2)
        co = d * reach * rng.uniform(*keep)
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=d, clear_outer=True)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    zmin = min(v.co.z for v in bm.verts)
    zcut = zmin + sz * base_cut
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), plane_co=(0, 0, zcut), plane_no=(0, 0, -1), clear_outer=True)
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(7), verts=bm.verts[:], edges=bm.edges[:])
    sharp = [e for e in bm.edges if e.calc_face_angle(0) > math.radians(22)]
    if sharp and bevel > 0:
        bmesh.ops.bevel(bm, geom=sharp, offset=bevel * min(sx, sy, sz), segments=3, profile=0.55, affect="EDGES", clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for v in bm.verts:
        v.co.z -= zcut
    return bm


def block(size, rng, chip=0.18, bevel=0.06):
    """A cut stone block (ruins): a box with one or two chipped corners and softened edges."""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz + sz / 2))
    for _ in range(rng.choice((0, 1, 1, 2))):
        corner = Vector((rng.choice((-1, 1)) * sx / 2, rng.choice((-1, 1)) * sy / 2, rng.choice((0, 1)) * sz))
        d = (corner - Vector((0, 0, sz / 2))).normalized()
        co = corner - d * min(sx, sy, sz) * rng.uniform(0.6, 1.0) * chip * 2
        bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), plane_co=co, plane_no=d, clear_outer=True)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    for v in bm.verts:  # a little irregularity, so no block is a perfect box
        v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.03 * min(sx, sy, sz)
    sharp = [e for e in bm.edges if e.calc_face_angle(0) > math.radians(20)]
    bmesh.ops.bevel(bm, geom=sharp, offset=bevel * min(sx, sy, sz), segments=2, profile=0.6, affect="EDGES", clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def lump(r, rng, squash=0.8, jitter=0.1, subdiv=2, flat_bottom=0.35):
    """A faceted foliage lump (canopy or bush mass): a jittered icosphere, a little squashed, its underside
    flattened so clusters read as layered masses."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    for v in bm.verts:
        v.co *= 1 + rng.uniform(-jitter, jitter)
        v.co.z *= squash
        if v.co.z < -r * squash * flat_bottom:
            v.co.z = -r * squash * flat_bottom + (v.co.z + r * squash * flat_bottom) * 0.3
    return bm


def canopy_mass(r, rng, squash=0.72, cuts=4):
    """A canopy mass in the tree reference's manner: a squashed, jittered ball sliced by a few planes into
    broad faceted faces (near-flat ones merged), its underside flattened."""
    bm = lump(r, rng, squash=squash, jitter=0.1, subdiv=2, flat_bottom=0.45)
    for _ in range(cuts):
        d = unit(rng, 0.6)
        reach = math.sqrt((d.x * r) ** 2 + (d.y * r) ** 2 + (d.z * r * squash) ** 2)
        bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), plane_co=d * reach * rng.uniform(0.62, 0.8), plane_no=d, clear_outer=True)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(9), verts=bm.verts[:], edges=bm.edges[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def tube(bm, pts, radii, sides=7, rng=None, caps=(True, True), jitter=0.06):
    """A trunk, branch, root or stem along a path: slightly uneven rings."""
    pts = [Vector(p) for p in pts]
    rings = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = d.orthogonal().normalized()
        w = d.cross(u).normalized()
        ring = []
        for k in range(sides):
            t = k / sides * math.tau
            rr = r * (1 + (rng.uniform(-jitter, jitter) if rng else 0))
            ring.append(bm.verts.new(p + (u * math.cos(t) + w * math.sin(t)) * rr))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            n = (k + 1) % sides
            bm.faces.new((a[k], a[n], b[n], b[k]))
    if caps[0]:
        bm.faces.new(list(reversed(rings[0])))
    if caps[1]:
        bm.faces.new(rings[-1])


def leaf(bm, base, direction, length, width, rng, droop=0.25, fold=0.18, curl=0.0, samples=6, tip=0.85, thick=0.05):
    """A leaf or petal blade: a lance or oval outline along an arching centreline, folded along its midrib (a
    shallow V, so the rib catches the light), given a little thickness so it shows from both sides."""
    base = Vector(base)
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    if up.z < 0:
        up = -up
    rows = []
    for i in range(samples + 1):
        t = i / samples
        # widest about 40% along; `tip` < 1 rounds the end (petals), 1 keeps it pointed (blades)
        w = width * (0.25 + 0.75 * (t / 0.4) ** 0.6) if t < 0.4 else width * ((1 - t) / 0.6) ** tip
        w = max(w, width * 0.04)
        c = base + d * length * t + up * (length * 0.25 * math.sin(math.pi * t * 0.8)) - Vector((0, 0, droop * length * t * t))
        c += side * curl * length * t * t
        rows.append((bm.verts.new(c - side * w / 2), bm.verts.new(c + up * fold * w), bm.verts.new(c + side * w / 2)))
    top = []
    for a, b in zip(rows, rows[1:]):
        top.append(bm.faces.new((a[0], a[1], b[1], b[0])))
        top.append(bm.faces.new((a[1], a[2], b[2], b[1])))
    if thick > 0:
        res = bmesh.ops.solidify(bm, geom=top, thickness=thick)
        del res


# --- objects and paint ----------------------------------------------------------------------------
REGISTRY = []  # (asset, part key, object)
RIGS = {}  # asset -> [(bone, head, tail, parent, kind)]: the wind rig, recorded while each asset is built


def bone(asset, name, head, tail, parent=None, kind="branch"):
    RIGS.setdefault(asset, []).append((name, Vector(head), Vector(tail), parent, kind))


def make(asset, part, key, bm, family, smooth=False):
    if not bm.verts:
        bm.free()
        return None
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0005)
    me = bpy.data.meshes.new(f"{asset}_{part}")
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(f"{asset}_{part}", me)
    kit = bpy.data.collections.get("PropKit")
    if kit is None:
        kit = bpy.data.collections.new("PropKit")
        bpy.context.scene.collection.children.link(kit)
    col = bpy.data.collections.get(f"Kit_{family}")
    if col is None:
        col = bpy.data.collections.new(f"Kit_{family}")
        kit.children.link(col)
    col.objects.link(obj)
    obj["kit_asset"] = asset
    obj["kit_key"] = key
    obj["kit_family"] = family
    REGISTRY.append((asset, key, obj))
    return obj


def facet_mask(obj):
    """A colour attribute "kitmask" per face corner: R = 1 on narrow bevel strips (the softened edges, which take
    the highlight), G = one random tone per broad facet (coplanar triangles grouped), so each plane reads as its
    own painted shape."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    group = [-1] * len(bm.faces)
    areas = []
    for f in bm.faces:
        if group[f.index] >= 0:
            continue
        gid = len(areas)
        group[f.index] = gid
        stack, area = [f], 0.0
        while stack:
            g = stack.pop()
            area += g.calc_area()
            for e in g.edges:
                for h in e.link_faces:
                    if group[h.index] < 0 and h.normal.dot(f.normal) > 0.995:
                        group[h.index] = gid
                        stack.append(h)
        areas.append(area)
    big = sorted(areas)[-max(1, len(areas) // 8)]
    attr = me.color_attributes.new("kitmask", "FLOAT_COLOR", "CORNER")
    for poly, f in zip(me.polygons, bm.faces):
        gid = group[f.index]
        edge = 1.0 - min(1.0, areas[gid] / (0.06 * big))
        rnd = float(P.hash01(17, gid, len(areas)))
        for li in poly.loop_indices:
            attr.data[li].color = (max(edge, 0.0), rnd, 0.0, 1.0)
    bm.free()


def _bake_mask(obj, img):
    mat = bpy.data.materials.new("MaskTmp")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "kitmask"
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(at.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    old = obj.data.materials[0]
    obj.data.materials[0] = mat
    S._select_only(obj)
    bpy.context.scene.cycles.samples = 1
    bpy.ops.object.bake(type="EMIT", margin=8, margin_type="EXTEND")
    obj.data.materials[0] = old
    bpy.data.materials.remove(mat)


def bake_paint(obj, px):
    key = obj["kit_key"]
    base, light, dark = PAL[key]
    var, top, edge, facet, ao_k = feel_of(key)
    S._select_only(obj)
    if not obj.data.materials:
        obj.data.materials.append(C.flat_material(f"{obj.name}_Flat", tuple(float(c) for c in base), 0.95))
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    facet_mask(obj)
    imgs = {k: bpy.data.images.new(f"bake_{k}", px, px, float_buffer=True) for k in ("Position", "Normal", "AO", "Pointiness", "Mask")}
    _bake_mask(obj, imgs["Mask"])
    S._bake_into(obj, imgs["Position"], "EMIT", "Position")
    S._bake_into(obj, imgs["Normal"], "EMIT", "Normal")
    S._bake_into(obj, imgs["Pointiness"], "EMIT", "Pointiness")
    S._bake_into(obj, imgs["AO"], "AO")
    Pw = (S._pixels(imgs["Position"])[..., :3].astype(np.float64) - 0.5) * 4000.0
    Nw = S._pixels(imgs["Normal"])[..., :3].astype(np.float64) * 2.0 - 1.0
    # _bake_into maps every emitted vector v -> v * 0.5 + 0.5, pointiness included (0.5 is flat -> 0.75)
    pt = (S._pixels(imgs["Pointiness"])[..., 0].astype(np.float64) - 0.5) * 2.0
    ao = np.clip(S._pixels(imgs["AO"])[..., 0].astype(np.float64), 0, 1)
    mask = S._pixels(imgs["Mask"])[..., :2].astype(np.float64)
    for img in imgs.values():
        bpy.data.images.remove(img)
    x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
    seed = sum(map(ord, obj["kit_asset"])) % 997
    n = P.fbm3(x * 0.09, y * 0.09, z * 0.09, seed, 2) - 0.5
    col = P.fill(x.shape, base) * (1 + 2 * var * n)[..., None]
    up = np.clip(Nw[..., 2], -1, 1)
    col = P.mix(col, light, top * np.clip(up, 0, 1))
    col = P.mix(col, dark, 0.35 * np.clip(-up, 0, 1))
    col = col * (1 + 2 * facet * (mask[..., 1] - 0.5))[..., None]  # each broad facet its own tone
    col = P.mix(col, light, edge * np.clip(mask[..., 0], 0, 1))  # the bevelled edges catch the light
    concave = P.smoothstep(0.495, 0.42, pt)
    col = P.mix(col, dark, 0.35 * concave)  # creases and inside corners
    occl = (1.0 - ao)[..., None]
    tint = np.array([0.55, 0.52, 0.75])
    col = col * (1.0 - ao_k * occl * (1.0 - tint))
    col = np.clip(col, 0, 1)
    maps = {"colour": S.PT.save_png(os.path.join(TEX, f"{obj.name}_Color.png"), col)}
    old = obj.data.materials[0]
    obj.data.materials[0] = S.image_material(f"{obj.name}_Painted", maps, roughness=0.95)
    if old and old.users == 0:
        bpy.data.materials.remove(old)


# --- ROCKS (image 1) ------------------------------------------------------------------------------
def rocks():
    rng = random.Random(101)
    specs = [
        # name, [(size, offset, lean)], palette
        ("Rock_Pillar", [((2.6, 2.2, 6.2), (0, 0, 0), 0.04)], "stone_grey"),
        ("Rock_Split_Big", [((6.0, 4.4, 9.5), (-0.6, 0, 0), -0.10), ((4.4, 3.6, 6.4), (2.2, 0.5, 0), 0.16), ((3.2, 3.0, 4.0), (3.4, -0.6, 0), 0.25)], "stone_cream"),
        ("Rock_Wide_Cluster", [((7.0, 5.0, 3.4), (0, 0, 0), 0.0), ((4.2, 3.8, 3.0), (3.0, -1.2, 0), 0.05), ((3.4, 3.2, 2.2), (-3.4, 0.6, 0), -0.05)], "stone_grey"),
        ("Rock_Round", [((4.6, 4.2, 4.4), (0, 0, 0), 0.0)], "stone_sand"),
        ("Rock_Wedge", [((2.4, 1.8, 3.8), (0, 0, 0), 0.12)], "stone_blue"),
        ("Rock_Medium", [((3.4, 2.8, 2.4), (0, 0, 0), 0.0)], "stone_cream"),
        ("Rock_Twin", [((3.0, 2.6, 3.4), (-1.2, 0, 0), -0.06), ((2.4, 2.2, 2.6), (1.3, 0.4, 0), 0.08)], "stone_blue"),
        ("Rock_Small_A", [((1.6, 1.3, 1.4), (0, 0, 0), 0.0)], "stone_grey"),
        ("Rock_Small_B", [((1.2, 1.1, 1.6), (0, 0, 0), 0.1)], "stone_sand"),
        ("Rock_Pebbles", [((0.9, 0.8, 0.6), (0, 0, 0), 0.0), ((0.7, 0.6, 0.5), (1.1, 0.4, 0), 0.0), ((0.6, 0.6, 0.45), (0.3, 1.0, 0), 0.0), ((0.5, 0.4, 0.4), (-0.8, 0.6, 0), 0.0)], "stone_cream"),
        ("Rock_Flat_Slab", [((5.4, 4.0, 1.3), (0, 0, 0), 0.0)], "stone_grey"),
    ]
    for name, parts, key in specs:
        bm = bmesh.new()
        for size, off, lean in parts:
            c = chunk(size, rng, cuts=rng.randint(12, 17))
            append(bm, c, Matrix.Translation(off) @ Matrix.Rotation(lean, 4, "Y") @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z"))
        make(name, "Stone", key, bm, "Rocks")


# --- RUINS (image 9) --------------------------------------------------------------------------------
def ivy(bm_leaf, bm_flower, path, rng, density=4.0, size=1.1, flowers=0.12):
    """Ivy along a path (a list of points draped over stone): small leaves in pairs, a few lilac flowers."""
    path = [Vector(p) for p in path]
    for a, b in zip(path, path[1:]):
        seg = b - a
        n = max(2, int(seg.length * density))
        for i in range(n):
            p = a + seg * (i / n) + Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0))
            d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 0.4)))
            leaf(bm_leaf, p, d, size * rng.uniform(0.7, 1.2), size * rng.uniform(0.6, 0.85), rng, droop=0.2, fold=0.12, samples=3, tip=0.6, thick=0.04)
            if i % 3 == 0:  # a leafy clump hugging the stone every so often
                append(bm_leaf, canopy_mass(size * rng.uniform(0.7, 1.2), rng, squash=0.7, cuts=2), Matrix.Translation(p))
            if rng.random() < flowers:
                f = lump(size * 0.22, rng, squash=0.8, jitter=0.05, subdiv=1)
                append(bm_flower, f, Matrix.Translation(p + Vector((0, 0, 0.15))))


def ruins():
    rng = random.Random(202)

    def stack(bm, x, y, h, w, d, z0=0.0, rot=0.0, levels=None):
        z = z0
        tops = []
        heights = levels or []
        while z < h - 0.3:
            bh = heights.pop(0) if heights else rng.uniform(1.2, 1.8)
            bh = min(bh, h - z)
            b = block((w * rng.uniform(0.92, 1.05), d * rng.uniform(0.92, 1.05), bh), rng)
            append(bm, b, Matrix.Translation((x + rng.uniform(-0.15, 0.15), y + rng.uniform(-0.15, 0.15), z)) @ Matrix.Rotation(rot + rng.uniform(-0.04, 0.04), 4, "Z"))
            z += bh
            tops.append(z)
        return z

    # an arch: two piers of blocks and a ring of wedge blocks, one missing near the top
    stone, lv, fl = bmesh.new(), bmesh.new(), bmesh.new()
    span, pier_h, R = 7.0, 7.5, 3.5 + 1.0
    for sx in (-1, 1):
        stack(stone, sx * (span / 2 + 0.9), 0, pier_h, 1.8, 1.6)
    n = 9
    for i in range(n):
        if i == 6:
            continue  # a fallen voussoir
        t0, t1 = i / n * math.pi, (i + 1) / n * math.pi
        tm = (t0 + t1) / 2
        b = block((1.6, 1.6, R * (t1 - t0) * 0.96), rng, chip=0.1)
        m = Matrix.Translation((math.cos(tm) * (span / 2 + 0.9) * 1.0, 0, pier_h + math.sin(tm) * (span / 2 + 0.9))) @ Matrix.Rotation(-tm, 4, "Y") @ Matrix.Translation((0, 0, -R * (t1 - t0) * 0.48))
        append(stone, b, m)
    fallen = block((1.6, 1.6, 1.5), rng)
    append(stone, fallen, Matrix.Translation((2.4, 2.0, 0)) @ Matrix.Rotation(0.6, 4, "Z") @ Matrix.Rotation(0.5, 4, "X"))
    for sx in (-1, 1):  # a few paving slabs round the foot
        for k in range(3):
            b = block((rng.uniform(1.6, 2.4), rng.uniform(1.4, 2.0), 0.35), rng, chip=0.1)
            append(stone, b, Matrix.Translation((sx * rng.uniform(0.5, 4.5), rng.uniform(-2.5, 2.5), -0.15)) @ Matrix.Rotation(rng.uniform(-0.3, 0.3), 4, "Z"))
    ivy(lv, fl, [(-5.6, 0.9, 1.0), (-5.0, 0.9, 5.0), (-4.2, 0.6, 8.6), (-2.6, 0.6, 11.4), (-0.4, 0.6, 12.6)], rng)
    ivy(lv, fl, [(5.3, -0.9, 7.6), (5.4, -0.9, 4.0)], rng, density=1.2)
    make("Ruin_Arch", "Stone", "ruin", stone, "Ruins")
    make("Ruin_Arch", "Ivy", "leaf_deep", lv, "Ruins")
    make("Ruin_Arch", "Flower", "lilac", fl, "Ruins")

    # a partial wall: courses of blocks, broken down toward one end
    stone, lv, fl = bmesh.new(), bmesh.new(), bmesh.new()
    x = -6.0
    for col in range(7):
        w = rng.uniform(1.8, 2.4)
        h = max(0.9, 6.5 - col * rng.uniform(0.6, 1.0) + rng.uniform(-0.6, 0.6))
        stack(stone, x + w / 2, 0, h, w, 1.6)
        x += w * 1.02
    for k in range(4):
        b = block((rng.uniform(1.2, 1.8), rng.uniform(1.0, 1.4), rng.uniform(0.9, 1.3)), rng)
        append(stone, b, Matrix.Translation((rng.uniform(3, 9), rng.uniform(1.5, 3.5), 0)) @ Matrix.Rotation(rng.uniform(0, 3), 4, "Z") @ Matrix.Rotation(rng.uniform(-0.3, 0.3), 4, "X"))
    ivy(lv, fl, [(-5.5, 0.9, 6.4), (-3.0, 0.9, 6.2), (-1.0, 0.9, 5.0), (0.2, 1.0, 2.0), (0.8, 1.2, 0.3)], rng)
    ivy(lv, fl, [(-4.5, -0.9, 6.4), (-4.4, -0.9, 3.5)], rng, density=1.2)
    make("Ruin_Wall", "Stone", "ruin", stone, "Ruins")
    make("Ruin_Wall", "Ivy", "leaf", lv, "Ruins")
    make("Ruin_Wall", "Flower", "lilac", fl, "Ruins")

    # columns: drums, one tall with a capital, one broken short with its fallen drums
    for name, h, broken in (("Ruin_Column_Tall", 9.5, False), ("Ruin_Column_Broken", 4.2, True)):
        stone, lv, fl = bmesh.new(), bmesh.new(), bmesh.new()
        base = block((2.6, 2.6, 0.8), rng, chip=0.08)
        append(stone, base, Matrix())
        z = 0.8
        while z < h - 0.2:
            dh = min(rng.uniform(1.4, 2.0), h - z)
            dr = bmesh.new()
            tube(dr, [(0, 0, 0), (0, 0, dh)], [0.95, 0.92], sides=10, rng=rng, jitter=0.02)
            sharp = [e for e in dr.edges if e.calc_face_angle(0) > math.radians(35)]
            bmesh.ops.bevel(dr, geom=sharp, offset=0.08, segments=2, profile=0.6, affect="EDGES", clamp_overlap=True)
            append(stone, dr, Matrix.Translation((rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), z)) @ Matrix.Rotation(rng.uniform(0, 1), 4, "Z"))
            z += dh
        if not broken:
            cap = block((2.4, 2.4, 0.7), rng, chip=0.08)
            append(stone, cap, Matrix.Translation((0, 0, z)))
            ivy(lv, fl, [(0.9, 0.9, 1.0), (0.9, -0.5, 4.0), (-0.6, -0.9, 7.0), (-1.0, 0.4, z + 0.6)], rng, density=1.4)
        else:
            for k in range(2):
                dr = bmesh.new()
                tube(dr, [(0, 0, 0), (0, 0, 1.6)], [0.95, 0.92], sides=10, rng=rng, jitter=0.02)
                append(stone, dr, Matrix.Translation((2.0 + k * 1.9, 0.6 * k, 0.95)) @ Matrix.Rotation(math.pi / 2 + rng.uniform(-0.2, 0.2), 4, "Y") @ Matrix.Rotation(rng.uniform(0, 1), 4, "Z"))
            ivy(lv, fl, [(0.9, 0.5, 0.6), (0.7, -0.6, 2.4), (-0.4, -0.8, h)], rng, density=1.4)
        make(name, "Stone", "ruin", stone, "Ruins")
        make(name, "Ivy", "leaf_deep", lv, "Ruins")
        make(name, "Flower", "lilac", fl, "Ruins")


# --- TREES (image 8) --------------------------------------------------------------------------------
def tree(name, height, rng, branches=3, spread=0.5, canopy=1.0, lean=(0.0, 0.0), bark="bark", leafkey="leaf", tufts=1):
    """A branching tree: a substantial trunk flaring into grounded roots, forking into `branches` limbs, each
    ending in a layered canopy of faceted lumps; a small tuft on the trunk. Canopy masses overlap so the crown
    reads as one irregular, layered shape."""
    wood, crown = bmesh.new(), bmesh.new()
    r0 = height * 0.055
    fork = height * rng.uniform(0.42, 0.52)
    lx, ly = lean
    trunk = [(0, 0, -0.6), (lx * 0.2, ly * 0.2, fork * 0.35), (lx * 0.6, ly * 0.6, fork * 0.75), (lx, ly, fork)]
    tube(wood, trunk, [r0 * 1.25, r0, r0 * 0.88, r0 * 0.8], sides=8, rng=rng)
    bone(name, "Root", (0, 0, -0.6), (0, 0, r0 * 1.5), None, "root")
    bone(name, "Trunk", (0, 0, r0 * 1.5), (lx, ly, fork), "Root", "trunk")
    # roots: flaring out and down into the ground (their ends sit below z = 0, so nothing floats)
    for k in range(rng.randint(4, 6)):
        a = k / 5 * math.tau + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(a), math.sin(a), 0))
        reach = r0 * rng.uniform(2.4, 3.6)
        pts = [Vector((0, 0, r0 * 1.6)) + out * r0 * 0.5, out * (r0 + reach * 0.45) + Vector((0, 0, r0 * 0.55)), out * (r0 + reach) + Vector((0, 0, -0.35))]
        tube(wood, pts, [r0 * 0.55, r0 * 0.32, r0 * 0.12], sides=6, rng=rng)
    top = Vector((lx, ly, fork))
    ends = []
    for b in range(branches):
        a = b / branches * math.tau + rng.uniform(-0.5, 0.5)
        out = Vector((math.cos(a), math.sin(a), 0))
        reach = height * spread * rng.uniform(0.35, 0.55)
        rise = height * rng.uniform(0.25, 0.42)
        mid = top + out * reach * 0.45 + Vector((0, 0, rise * 0.55))
        end = top + out * reach + Vector((0, 0, rise))
        tube(wood, [top - Vector((0, 0, r0)), mid, end], [r0 * 0.7, r0 * 0.45, r0 * 0.25], sides=7, rng=rng)
        ends.append(end)
        bone(name, f"Branch{b}", top, end, "Trunk", "branch")
        if rng.random() < 0.6:  # a side twig with its own small mass
            tw = mid + (out.cross(Vector((0, 0, 1))) * rng.choice((-1, 1)) * reach * 0.35) + Vector((0, 0, rise * 0.25))
            tube(wood, [mid, tw], [r0 * 0.25, r0 * 0.12], sides=5, rng=rng)
            ends.append(tw)
            bone(name, f"Twig{b}", mid, tw, f"Branch{b}", "twig")
    # the crown: lumps round each branch end and a few bridging the middle
    cr = height * 0.16 * canopy
    centre = sum(ends, Vector()) / len(ends) + Vector((0, 0, cr * 0.4))
    for e in ends:
        for k in range(rng.randint(2, 4)):
            off = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 0.6))) * cr * 0.7
            r = cr * rng.uniform(0.75, 1.1)
            append(crown, canopy_mass(r, rng, squash=rng.uniform(0.58, 0.78)), Matrix.Translation(e + off) @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z"))
    for k in range(3):
        off = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0, 0.5))) * cr * 0.6
        append(crown, canopy_mass(cr * rng.uniform(0.9, 1.25), rng, squash=0.62), Matrix.Translation(centre + off))
    for k in range(tufts):  # the small tuft on the trunk (as in the reference), overlapping the bark
        a = rng.uniform(0, math.tau)
        h = fork * rng.uniform(0.5, 0.75)
        axis = Vector((lx * h / fork * 0.9, ly * h / fork * 0.9, h))
        tr = cr * 0.38
        append(crown, canopy_mass(tr, rng, squash=0.75, cuts=2), Matrix.Translation(axis + Vector((math.cos(a), math.sin(a), 0)) * (r0 * 0.8 + tr * 0.55)))
    make(name, "Bark", bark, wood, "Trees")
    make(name, "Leaf", leafkey, crown, "Trees")


def trees():
    rng = random.Random(303)
    tree("Tree_A", 30, rng, branches=3, spread=0.5, canopy=1.0, lean=(1.2, 0.4))
    tree("Tree_B", 42, rng, branches=4, spread=0.42, canopy=1.05, lean=(-1.0, 0.8), leafkey="leaf_deep")
    tree("Tree_C", 24, rng, branches=2, spread=0.65, canopy=1.15, lean=(0.6, -1.4), bark="bark_warm", leafkey="leaf_lime")
    tree("Tree_D", 52, rng, branches=4, spread=0.36, canopy=0.95, lean=(0.4, 0.2), leafkey="leaf_olive")
    tree("Tree_E", 34, rng, branches=3, spread=0.62, canopy=0.85, lean=(-1.8, -0.4), bark="bark_warm", tufts=2)


# --- BUSHES (images 2, 7) and LEAFY PLANTS (images 2, 6) ---------------------------------------------
def bush(name, layout, rng, key):
    bm = bmesh.new()
    bone(name, "Root", (0, 0, -0.3), (0, 0, 0.3), None, "root")
    for i, (x, y, z, r, sq) in enumerate(layout):
        bone(name, f"Mass{i}", (x * 0.3, y * 0.3, 0.3), (x, y, z + r * sq * 0.6), "Root", "bush")
        append(bm, lump(r, rng, squash=sq, jitter=0.12), Matrix.Translation((x, y, z)))
        for k in range(rng.randint(7, 11)):  # small leafy lumps over the upper surface: the bumpy outline of image 7
            a = rng.uniform(0, math.tau)
            el = rng.uniform(-0.15, 1.1)
            p = Vector((x + math.cos(a) * math.cos(el) * r * 0.82, y + math.sin(a) * math.cos(el) * r * 0.82, z + math.sin(el) * r * sq * 0.82))
            append(bm, lump(r * rng.uniform(0.26, 0.42), rng, squash=0.85, jitter=0.15, subdiv=1), Matrix.Translation(p))
    make(name, "Leaf", key, bm, "Bushes")


def plant(name, rng, key, leaves=9, length=(2.0, 3.2), width=(0.5, 0.8), tilt=(0.5, 1.1), droop=0.25, layers=1, flowers=0):
    bm, fl = bmesh.new(), bmesh.new()
    for layer in range(layers):
        n = leaves - layer * 2
        for i in range(n):
            a = i / n * math.tau + rng.uniform(-0.25, 0.25) + layer * 0.4
            t = rng.uniform(*tilt) * (1 - layer * 0.25)
            d = Vector((math.cos(a) * math.cos(t), math.sin(a) * math.cos(t), math.sin(t)))
            ln = rng.uniform(*length) * (1 - layer * 0.25)
            base = Vector((0, 0, 0.05 + layer * 0.15))
            leaf(bm, base, d, ln, rng.uniform(*width), rng, droop=droop, fold=0.2)
            if layer == 0 and i == 0:
                bone(name, "Root", (0, 0, -0.3), (0, 0, 0.2), None, "root")
            bone(name, f"Leaf{layer}_{i}", base, base + d * ln * 0.8, "Root", "leaf")
    for k in range(flowers):
        p = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), length[1] * 0.45))
        append(fl, lump(0.18, rng, subdiv=1, squash=0.9), Matrix.Translation(p))
    make(name, "Leaf", key, bm, "Plants")
    make(name, "Flower", "petal_white", fl, "Plants")


def bushes_and_plants():
    rng = random.Random(404)
    bush("Bush_Round", [(0, 0, 2.4, 2.6, 0.85), (0.8, 0.6, 3.6, 1.6, 0.8)], rng, "leaf")
    bush("Bush_Wide", [(-2.8, 0, 1.7, 2.0, 0.75), (0, 0.3, 2.0, 2.3, 0.75), (2.9, -0.2, 1.6, 1.9, 0.75), (1.0, -0.8, 2.6, 1.4, 0.8)], rng, "leaf_deep")
    bush("Bush_Tall", [(0, 0, 1.8, 2.0, 0.9), (0.1, 0.1, 3.8, 1.7, 0.9), (0, -0.1, 5.4, 1.2, 0.95)], rng, "leaf_olive")
    bush("Bush_Double", [(0, 0, 1.4, 1.8, 0.8), (0.3, 0.2, 3.3, 1.5, 0.8)], rng, "leaf_lime")
    bush("Bush_Low", [(-0.9, 0, 0.9, 1.3, 0.7), (0.9, 0.4, 0.8, 1.1, 0.7), (0.2, -0.7, 0.8, 1.0, 0.7)], rng, "leaf")
    bush("Bush_Big", [(0, 0, 3.0, 3.4, 0.8), (-2.6, 0.8, 2.4, 2.4, 0.8), (2.4, -0.6, 2.6, 2.6, 0.8), (0.4, 0.6, 5.0, 2.2, 0.85)], rng, "leaf_deep")
    plant("Plant_Spiky", rng, "leaf", leaves=11, length=(2.4, 3.6), width=(0.3, 0.45), tilt=(0.9, 1.35), droop=0.15)
    plant("Plant_Broadleaf", rng, "leaf_lime", leaves=8, length=(2.4, 3.0), width=(0.9, 1.2), tilt=(0.35, 0.7), droop=0.3, layers=2, flowers=3)
    plant("Plant_Broadleaf_Small", rng, "leaf", leaves=7, length=(1.3, 1.7), width=(0.6, 0.8), tilt=(0.4, 0.8), droop=0.3, layers=2)
    plant("Plant_Roundleaf", rng, "leaf_deep", leaves=7, length=(1.2, 1.6), width=(1.0, 1.3), tilt=(0.15, 0.5), droop=0.35)
    plant("Plant_Tall_Blade", rng, "leaf_olive", leaves=7, length=(3.4, 4.6), width=(0.45, 0.6), tilt=(1.0, 1.35), droop=0.2)
    plant("Plant_Groundcover", rng, "leaf", leaves=12, length=(0.9, 1.4), width=(0.6, 0.9), tilt=(0.05, 0.3), droop=0.3, layers=2)


# --- FLOWERS (images 4, 5) --------------------------------------------------------------------------
def blossom(bm_petal, bm_centre, at, face, rng, kind="daisy", size=1.0):
    at = Vector(at)
    face = Vector(face).normalized()
    side = face.orthogonal().normalized()
    other = face.cross(side)
    if kind == "daisy":
        n = rng.randint(12, 15)
        for i in range(n):
            a = i / n * math.tau
            d = (side * math.cos(a) + other * math.sin(a)) * 0.9 + face * 0.12
            leaf(bm_petal, at, d, 0.85 * size, 0.42 * size, rng, droop=0.05, fold=0.05, samples=3, tip=0.45, thick=0.03)
        c = lump(0.32 * size, rng, squash=0.6, jitter=0.03, subdiv=1)
        rot = face.to_track_quat("Z", "Y").to_matrix().to_4x4()
        append(bm_centre, c, Matrix.Translation(at + face * 0.08 * size) @ rot)
    elif kind in ("lily", "tulip", "bell"):
        n = 6
        cup = {"lily": 0.55, "tulip": 1.25, "bell": 1.45}[kind]
        for i in range(n):
            a = i / n * math.tau + (0.5 if i % 2 else 0)
            d = (side * math.cos(a) + other * math.sin(a)) * (1.0 / cup) + face * 1.0
            w = {"lily": 0.36, "tulip": 0.62, "bell": 0.5}[kind] * size
            leaf(bm_petal, at, d, 1.1 * size, w, rng, droop=-0.1 if kind != "lily" else 0.25, fold=0.25, samples=3, tip=0.7, thick=0.03)
        append(bm_centre, lump(0.14 * size, rng, subdiv=1), Matrix.Translation(at + face * 0.35 * size))
    elif kind == "lotus":
        for layer, (n, length, lift) in enumerate(((9, 1.5, 0.45), (8, 1.3, 1.1), (6, 1.05, 2.2))):
            for i in range(n):
                a = i / n * math.tau + layer * 0.35
                d = (side * math.cos(a) + other * math.sin(a)) + face * lift
                leaf(bm_petal, at + face * 0.12 * layer, d, length * size, 0.78 * size, rng, droop=-0.15, fold=0.35, samples=4, tip=0.55, thick=0.05)
        c = bmesh.new()
        tube(c, [(0, 0, 0), (0, 0, 0.45 * size)], [0.38 * size, 0.3 * size], sides=8, rng=rng)
        append(bm_centre, c, Matrix.Translation(at + face * 0.2 * size))


def flower_cluster(name, rng, kind, heads, height=(1.6, 3.0), size=(0.8, 1.1), petal="petal_white", leaves=4):
    pet, cen, stem = bmesh.new(), bmesh.new(), bmesh.new()
    bone(name, "Root", (0, 0, -0.3), (0, 0, 0.15), None, "root")
    for h in range(heads):
        base = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))
        ht = rng.uniform(*height)
        bend = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))
        top = base + bend + Vector((0, 0, ht))
        tube(stem, [base - Vector((0, 0, 0.2)), base + bend * 0.4 + Vector((0, 0, ht * 0.55)), top], [0.09, 0.08, 0.07], sides=5, rng=rng, jitter=0.02)
        bone(name, f"Stem{h}", base + Vector((0, 0, 0.15)), top, "Root", "stem")
        face = (Vector((0, 0, 1)) + bend * 0.6).normalized() if kind != "bell" else (Vector((0, 0, -1)) + bend).normalized()
        blossom(pet, cen, top, face, rng, kind, rng.uniform(*size))
    for k in range(leaves + 2):  # broad leaves at the foot, as in image 4
        a = k / (leaves + 2) * math.tau + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), rng.uniform(0.25, 0.7))).normalized()
        ln = rng.uniform(1.3, 2.1)
        leaf(stem, (0, 0, 0.1), d, ln, rng.uniform(0.6, 0.85), rng, droop=0.35, fold=0.22, samples=4, tip=0.7)
        bone(name, f"Foliage{k}", (0, 0, 0.1), Vector((0, 0, 0.1)) + d * ln * 0.8, "Root", "leaf")
    make(name, "Petal", petal, pet, "Flowers")
    make(name, "Centre", "centre", cen, "Flowers")
    make(name, "Stem", "stem", stem, "Flowers")


def flowers():
    rng = random.Random(505)
    flower_cluster("Flowers_Daisy_Big", rng, "daisy", 7, height=(1.2, 2.4))
    flower_cluster("Flowers_Daisy_Small", rng, "daisy", 3, height=(0.9, 1.8), size=(0.6, 0.85))
    flower_cluster("Flowers_Lily", rng, "lily", 3, height=(2.0, 3.2), petal="petal_cream")
    flower_cluster("Flowers_Tulip", rng, "tulip", 4, height=(1.5, 2.4), size=(0.7, 0.9))
    flower_cluster("Flowers_Bell", rng, "bell", 5, height=(1.8, 2.8), size=(0.5, 0.7), leaves=3)
    flower_cluster("Flowers_Coral", rng, "daisy", 4, height=(1.0, 2.0), size=(0.6, 0.8), petal="coral")


# --- LILY POND (image 3) -----------------------------------------------------------------------------
def lily_pad(pads, cx, cy, r, rng, z=0.0):
    """A thick lily pad with its notch, its underside at z (on the water)."""
    notch = rng.uniform(0, math.tau)
    seg = 14
    ring_t, ring_b = [], []
    cpt = pads.verts.new((cx, cy, z + 0.22))
    cpb = pads.verts.new((cx, cy, z))
    for i in range(seg + 1):
        t = notch + 0.35 + i / seg * (math.tau - 0.7)
        ring_t.append(pads.verts.new((cx + math.cos(t) * r, cy + math.sin(t) * r, z + 0.18 - 0.04 * math.sin(i))))
        ring_b.append(pads.verts.new((cx + math.cos(t) * r, cy + math.sin(t) * r, z)))
    for i in range(seg):
        pads.faces.new((cpt, ring_t[i], ring_t[i + 1]))
        pads.faces.new((cpb, ring_b[i + 1], ring_b[i]))
        pads.faces.new((ring_t[i], ring_b[i], ring_b[i + 1], ring_t[i + 1]))
    pads.faces.new((cpt, cpb, ring_b[0], ring_t[0]))
    pads.faces.new((cpt, ring_t[-1], ring_b[-1], cpb))


def lilies():
    """Single pond pieces to place on any water: three pad sizes and a water lily on its pad. Their base is
    the water's surface (z = 0)."""
    rng = random.Random(707)
    for name, r in (("Lily_Pad_Small", 1.0), ("Lily_Pad", 1.4), ("Lily_Pad_Big", 1.9)):
        pads = bmesh.new()
        lily_pad(pads, 0, 0, r, rng)
        bone(name, "Root", (0, 0, -0.4), (0, 0, -0.1), None, "root")
        bone(name, "Pad", (0, 0, 0), (0, 0, 0.6), "Root", "pad")
        make(name, "Pad", "pad", pads, "Pond")
    pads, pet, cen = bmesh.new(), bmesh.new(), bmesh.new()
    lily_pad(pads, 0.3, -0.2, 1.6, rng)
    blossom(pet, cen, (0, 0, 0.22), (0, 0, 1), rng, "lotus", 0.9)
    bone("Lily_Lotus", "Root", (0, 0, -0.4), (0, 0, -0.1), None, "root")
    bone("Lily_Lotus", "Pad", (0.3, -0.2, 0), (0.3, -0.2, 0.6), "Root", "pad")
    bone("Lily_Lotus", "Flower", (0, 0, 0.2), (0, 0, 1.4), "Root", "lotus")
    make("Lily_Lotus", "Pad", "pad", pads, "Pond")
    make("Lily_Lotus", "Petal", "lotus", pet, "Pond")
    make("Lily_Lotus", "Centre", "centre", cen, "Pond")


def pond():
    rng = random.Random(606)
    water, rim, pads, pet, cen = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    # the water: an irregular shoreline, its surface a little below the island's top
    n = 28
    pts = []
    for i in range(n):
        a = i / n * math.tau
        r = 9.0 * (1 + 0.12 * math.sin(a * 3 + 0.7) + 0.06 * math.sin(a * 7)) * (1.25 if math.cos(a) > 0 else 1.0)
        pts.append((math.cos(a) * r, math.sin(a) * r * 0.8))
    # a shallow pool sitting ON the island's top (its surface 0.15 up), held by a ring of stones, so it needs
    # no hole in the island and can be placed anywhere flat
    top = [water.verts.new((x, y, 0.15)) for x, y in pts]
    bot = [water.verts.new((x * 0.92, y * 0.92, -0.6)) for x, y in pts]
    water.faces.new(top)
    water.faces.new(list(reversed(bot)))
    for k in range(n):
        m = (k + 1) % n
        water.faces.new((top[k], bot[k], bot[m], top[m]))
    # shoreline rocks round about two thirds of the edge, flowers on the rest come from the kit when placed
    for i in range(n):  # a closed ring of low stones, bigger here and there
        x, y = pts[i]
        s = rng.uniform(1.1, 1.8) * (1.5 if rng.random() < 0.2 else 1.0)
        c = chunk((s * 1.4, s, s * 0.7), rng, cuts=10)
        append(rim, c, Matrix.Translation((x * 1.06, y * 1.06, -0.3)) @ Matrix.Rotation(math.atan2(y, x) + rng.uniform(-0.4, 0.4), 4, "Z"))
    # thick lily pads with their notch, and two water lilies; each pad and lily sways on its own bone
    bone("Pond_Lily", "Root", (0, 0, -0.6), (0, 0, -0.2), None, "root")
    for k in range(7):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0, 6.0)
        cx, cy = math.cos(a) * rr, math.sin(a) * rr * 0.75
        r = rng.uniform(0.9, 1.6)
        lily_pad(pads, cx, cy, r, rng, z=0.12)
        bone("Pond_Lily", f"Pad{k}", (cx, cy, 0.12), (cx, cy, 0.7), "Root", "pad")
        if k < 2:
            blossom(pet, cen, (cx, cy, 0.34), (0, 0, 1), rng, "lotus", rng.uniform(0.75, 0.95))
            bone("Pond_Lily", f"Lotus{k}", (cx, cy, 0.3), (cx, cy, 1.5), "Root", "lotus")
    make("Pond_Lily", "Water", "water", water, "Pond")
    make("Pond_Lily", "Stone", "stone_grey", rim, "Pond")
    make("Pond_Lily", "Pad", "pad", pads, "Pond")
    make("Pond_Lily", "Petal", "lotus", pet, "Pond")
    make("Pond_Lily", "Centre", "centre", cen, "Pond")


# --- layout and run ------------------------------------------------------------------------------------
ORDER = [("rocks", rocks), ("ruins", ruins), ("trees", trees), ("plants", bushes_and_plants), ("flowers", flowers), ("pond", pond), ("pond", lilies)]
ROWS = {"Rocks": 0, "Ruins": 1, "Trees": 2, "Bushes": 3, "Plants": 4, "Flowers": 5, "Pond": 6}
ROW_GAP = {"Rocks": 16, "Ruins": 22, "Trees": 56, "Bushes": 16, "Plants": 10, "Flowers": 8, "Pond": 26}


# --- WIND RIG (user, 2026-11-11: bones and a wind sway on everything that would move; never rocks or stone) ---
WIND = Vector((1.0, 0.35, 0.0)).normalized()  # the way the wind blows (the lean), in the asset's own axes
LOOP = 120  # frames at 30 fps: a 4-second loop; every motion runs a whole number of cycles in it, so it's seamless
# per bone kind: (lean + sway amplitude in degrees, cycles per loop, flutter share)
SWAY = {"pad": (2.0, 1, 0.6), "lotus": (3.5, 1, 0.5), "trunk": (1.2, 1, 0.3), "branch": (2.6, 1, 0.4), "twig": (4.0, 2, 0.5), "bush": (3.2, 1, 0.4), "leaf": (9.0, 2, 0.6), "stem": (7.0, 1, 0.5)}
RIGID = ("Leaf", "Petal", "Centre", "Flower", "Pad")
STATIC = ("Water", "Stone")  # never move: the whole part stays on the root  # these parts move whole with one bone (a lump, a leaf, a petal)


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def _parts(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    seen, parts = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, part = [v], []
        seen.add(v.index)
        while stack:
            u = stack.pop()
            part.append(u.index)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        parts.append(part)
    bm.free()
    return parts


def rig(asset, objs):
    bones = RIGS[asset]
    data = bpy.data.armatures.new(f"{asset}_Rig")
    arm = bpy.data.objects.new(f"{asset}_Rig", data)
    objs[0].users_collection[0].objects.link(arm)
    arm["kit_asset"] = asset
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.view_layer.objects:
        o.select_set(o is arm)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent, kind in bones:
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = head, tail if (tail - head).length > 0.05 else head + Vector((0, 0, 0.3))
    for name, head, tail, parent, kind in bones:
        if parent:
            data.edit_bones[name].parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    segs = [(name, head, tail, kind) for name, head, tail, parent, kind in bones]
    movers = [sg for sg in segs if sg[3] != "root"]
    for obj in objs:
        me = obj.data
        groups = {name: obj.vertex_groups.new(name=name) for name, *_ in segs}
        part_name = obj.name[len(asset) + 1 :]
        if part_name in STATIC:
            groups[segs[0][0]].add(list(range(len(me.vertices))), 1.0, "REPLACE")
        elif part_name in RIGID:
            for part in _parts(me):
                c = sum((me.vertices[i].co for i in part), Vector()) / len(part)
                # the part follows the bone whose far end it sits nearest (a lump at a branch tip, a petal at a stem top)
                best = min(movers, key=lambda sg: min(_seg_dist(c, sg[1], sg[2]), (c - sg[2]).length * 0.8))
                groups[best[0]].add(part, 1.0, "REPLACE")
        else:
            # bark and stems: each connected piece belongs to its nearest bone and may bend only against that
            # bone's parent (a stem from its base, a branch from the trunk), so no piece is split between
            # unrelated bones and stretched
            parent_of = {name: parent for name, head, tail, parent, kind in bones}
            by_name = {sg[0]: sg for sg in segs}
            for part in _parts(me):
                c = sum((me.vertices[i].co for i in part), Vector()) / len(part)
                best = min(segs, key=lambda sg: _seg_dist(c, sg[1], sg[2]))
                cands = [best] + ([by_name[parent_of[best[0]]]] if parent_of[best[0]] else [])
                for i in part:
                    pick = min(cands, key=lambda sg: _seg_dist(me.vertices[i].co, sg[1], sg[2]))
                    groups[pick[0]].add([i], 1.0, "REPLACE")
        mod = obj.modifiers.new("Wind", "ARMATURE")
        mod.object = arm
        obj.parent = arm
    # the sway: a steady lean downwind with gusts, and a smaller flutter across it, per bone, keyed over one loop
    bpy.context.scene.render.fps = 30
    seed = sum(map(ord, asset))
    for i, (name, head, tail, kind) in enumerate(movers):
        amp, cycles, flutter = SWAY[kind]
        b = data.bones[name]
        d = (tail - head).normalized()
        lean = d.cross(WIND)
        if lean.length < 0.2:
            lean = d.cross(Vector((0, 0, 1)))
        lean.normalize()
        across = d.cross(lean).normalized()
        to_local = b.matrix_local.to_3x3().inverted()
        ax1, ax2 = (to_local @ lean).normalized(), (to_local @ across).normalized()
        ph1 = P.hash01(seed, i, 1) * math.tau
        ph2 = P.hash01(seed, i, 2) * math.tau
        pb = arm.pose.bones[name]
        pb.rotation_mode = "QUATERNION"
        for f in range(0, LOOP + 1, 4):
            t = f / LOOP * math.tau
            a = math.radians(amp) * (0.45 + 0.55 * math.sin(cycles * t + ph1)) * (0.85 + 0.15 * math.sin(t + ph2))
            c = math.radians(amp) * flutter * math.sin(2 * cycles * t + ph2)
            pb.rotation_quaternion = Quaternion(ax1, a) @ Quaternion(ax2, c)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    for fc in arm.animation_data.action.fcurves if arm.animation_data and arm.animation_data.action and hasattr(arm.animation_data.action, "fcurves") else []:
        fc.modifiers.new("CYCLES")
    if arm.animation_data and arm.animation_data.action:
        arm.animation_data.action.name = f"{asset}_Wind"
    return arm


def rig_all():
    by_asset = {}
    for asset, key, obj in REGISTRY:
        by_asset.setdefault(asset, []).append(obj)
    made = 0
    for asset in RIGS:
        if asset in by_asset:
            rig(asset, by_asset[asset])
            made += 1
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 0, LOOP - 1
    print("RIGGED", made, "assets", flush=True)


WRAP = {"Rocks": 34, "Ruins": 60, "Trees": 400, "Bushes": 36, "Plants": 24, "Flowers": 16, "Pond": 40}


def layout():
    """Puts every asset on a review grid: one block per family, assets left to right, wrapping onto a new
    line past the family's width. An asset's parts move together (its pivot is its base centre)."""
    by_asset = {}
    for asset, key, obj in REGISTRY:
        by_asset.setdefault(asset, []).append(obj)
    rows = {}
    for asset, objs in by_asset.items():
        rows.setdefault(objs[0]["kit_family"], []).append((asset, objs))
    y = 0.0
    for fam in sorted(rows, key=lambda f: ROWS[f]):
        x, line_depth = 0.0, 0.0
        for asset, objs in rows[fam]:
            pts = [Vector(c) for o in objs for c in o.bound_box]  # local: every part's pivot is the asset's base
            w = max(p.x for p in pts) - min(p.x for p in pts)
            d = max(p.y for p in pts) - min(p.y for p in pts)
            if x > 0 and x + w > WRAP[fam]:
                x, y = 0.0, y - line_depth - 6
                line_depth = 0.0
            x += w / 2
            arm = bpy.data.objects.get(f"{asset}_Rig")
            if arm:  # a rigged asset moves by its armature; its meshes are parented to it
                arm.location = (x, y, 0)
            else:
                for o in objs:
                    o.location = (x, y, 0)
            x += w / 2 + 4
            line_depth = max(line_depth, d)
        y -= line_depth + 30


def main():
    C.reset()
    C.sky_and_sun(200, 40)
    os.makedirs(TEX, exist_ok=True)
    for key, fn in ORDER:
        if ONLY is None or key in ONLY:
            fn()
            print("BUILT", key, flush=True)
    import addon_utils

    addon_utils.enable("cycles", default_set=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.bake.target = "IMAGE_TEXTURES"
    if scene.world:
        scene.world.light_settings.distance = 3.0
    for asset, key, obj in REGISTRY:
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        px = 128 if FAST else (256 if tris < 600 else (512 if tris < 4000 else 1024))
        bake_paint(obj, px)
        print(f"PAINTED {obj.name}: {tris} tris, {px}px", flush=True)
    rig_all()
    layout()
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "gnomon_props.blend"))
    print("SAVED", os.path.join(OUT, "gnomon_props.blend"))


main()
