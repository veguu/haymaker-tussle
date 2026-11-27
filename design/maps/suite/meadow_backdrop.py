"""MAP 1's ISLAND BACKDROP for the lowest graphics quality (owner 2026-11-26: "remember to take into account with people
on low end devices, people with the lowest graphics quality ... i still want it to look good"; he picked A, the
backdrop). Below quality 4 Roblox stops drawing any mesh whose bounding box's nearest point is past roughly 300 to 500
studs (measured in Studio, life-3): every floating island, tree and the mill vanish there, and house scraps float in
the sky. This builds a cheap copy of all of it as FEW meshes whose bounds reach the arena (an anchor triangle far below
it), so Roblox always draws them, set just INSIDE the real pieces so they stay hidden wherever the real islands draw:

  * each island: its own grass top and soil band (meadow.py islands(), the same rings) pulled 3% in toward the island's
    middle and dropped 2 studs, its rock core 5% in, the keel pieces 10% in toward their own middles (the boulders are
    left out: the core shows in their place);
  * houses, the mill's tower, farm sheds, crops and hedges: each piece's outer shape (a convex hull: boxes and prisms
    stay boxes and prisms) shrunk 10% toward its own middle; pieces under 2.5 studs (windows, beams) left out;
  * tree crowns: a 12-face gem inside each crown (the crown's box, 85%); trunks and the windmill's sails left out (the
    sails turn).

    blender -b --factory-startup -P meadow_backdrop.py -- <out folder>
        -> backdrop.glb (Map_Meadow_Backdrop_<n>, under 20,000 triangles each), backdrop.json (centres, triangles),
           backdrop_palette.png
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(OUT, exist_ok=True)
HERE = os.path.dirname(os.path.abspath(__file__))
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
scene = bpy.context.scene

# --- meadow.py read as a module (its builders and data), nothing built by it ---------------------------------------
_src = open(os.path.join(HERE, "meadow.py"), encoding="utf-8").read().replace("\r\n", "\n")
_src = _src[: _src.rindex("\nrun(NAME")]
G = {"__name__": "meadow_backdrop", "__file__": os.path.join(HERE, "meadow.py")}
exec(compile(_src, os.path.join(HERE, "meadow.py"), "exec"), G)
ISLANDS, PAL, W = G["ISLANDS"], G["PAL"], G["W"]

PIECES = []  # (element, part, key, [world verts], region)
HOUSES = []  # (walls key, roof key, [pieces made inside that house() call])
_IN_HOUSE = []


def _take(element, part, key, b, matrix, region):
    if b.verts:
        piece = (element, part, key, [matrix @ v.co for v in b.verts], region)
        (_IN_HOUSE[-1][2] if _IN_HOUSE else PIECES).append(piece)
    b.free()


_house = G["house"]


def _house_spy(x, z, yaw, w, d, wall_h, rng, roof="bark_thatch", walls="plaster", *a, **k):
    _IN_HOUSE.append((walls, roof, []))
    try:
        return _house(x, z, yaw, w, d, wall_h, rng, roof, walls, *a, **k)
    finally:
        HOUSES.append(_IN_HOUSE.pop())


G["house"] = _house_spy


G["vput"] = lambda element, key, b, matrix, region="": _take(element, "", key, b, matrix, region)
G["make"] = lambda asset, part, key, bm, family="Map", smooth=False: _take(asset, part, key, bm, Matrix(), "")
G["add"] = lambda element, material, key, src, matrix=Matrix(), family="Map", region="": _take(element, material, key, src, matrix, region)
G["islands"]()
G["village"]()
G["pack"]()
kinds = {}
for e, p, k, vs, r in PIECES:
    kinds[(e, p)] = kinds.get((e, p), 0) + 1
print("BACKDROP pieces by element/part", sorted(kinds.items()), flush=True)


# --- the palette ----------------------------------------------------------------------------------------------------
def colour(key):
    c = PAL.get(key, PAL.get("soil"))[0]
    if max(c[:3]) <= 1.0:
        c = tuple(int(round(255 * max(0.0, min(1.0, x)) ** (1 / 2.2))) for x in c[:3])
    return tuple(int(x) for x in c[:3])


COLOURS = []


def cell(rgb):
    if rgb not in COLOURS:
        COLOURS.append(rgb)
    i = COLOURS.index(rgb)
    return ((i % 8) + 0.5) / 8, 1 - ((i // 8) + 0.5) / 8


# --- the shapes -----------------------------------------------------------------------------------------------------
OUTS = []  # (region, bmesh)
_BMS = {}


def bm_for(points):
    """The quarter round the arena a piece goes to (by its middle): each quarter's mesh then spans under 2048 studs
    (Roblox's largest part) while its bounds still reach the arena (the anchor triangle), so it is always drawn."""
    m = sum(points, Vector()) / len(points)
    key = ("N" if m.y > 0 else "S") + ("E" if m.x > 0 else "W")  # Blender +y = Roblox -z = north
    if key not in _BMS:
        b = bmesh.new()
        b.loops.layers.uv.new("UVMap")
        _BMS[key] = b
    return _BMS[key]


def put_faces(dst, verts, faces, rgb):
    """faces: lists of indices into verts"""
    uv = dst.loops.layers.uv["UVMap"]
    u, v = cell(rgb)
    vv = [dst.verts.new(p) for p in verts]
    for f in faces:
        try:
            face = dst.faces.new([vv[i] for i in f])
        except ValueError:
            continue
        for lp in face.loops:
            lp[uv].uv = (u, v)


def hull(points):
    b = bmesh.new()
    for p in points:
        b.verts.new(p)
    res = bmesh.ops.convex_hull(b, input=b.verts[:])
    for g in res.get("geom_interior", []) + res.get("geom_unused", []):
        if isinstance(g, bmesh.types.BMVert) and g.is_valid:
            bmesh.ops.delete(b, geom=[g], context="VERTS")
    b.verts.index_update()
    verts = [v.co.copy() for v in b.verts]
    faces = [[v.index for v in f.verts] for f in b.faces]
    b.free()
    return verts, faces


def shrink(points, f, centre=None, horizontal=False):
    c = centre if centre is not None else sum(points, Vector()) / len(points)
    out = []
    for p in points:
        d = p - c
        out.append(Vector((c.x + d.x * f, c.y + d.y * f, p.z if horizontal else c.z + d.z * f)))
    return out


def gem(points, f=0.85):
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    c, h = (lo + hi) / 2, (hi - lo) / 2 * f
    ring = [Vector((c.x + h.x * math.cos(a / 6 * math.tau), c.y + h.y * math.sin(a / 6 * math.tau), c.z)) for a in range(6)]
    verts = ring + [Vector((c.x, c.y, c.z + h.z)), Vector((c.x, c.y, c.z - h.z))]
    faces = [[i, (i + 1) % 6, 6] for i in range(6)] + [[(i + 1) % 6, i, 7] for i in range(6)]
    return verts, faces


def obox(points, f, axis=None):
    """A box inside a box-like piece: its footprint's smallest rectangle (or along `axis`), shrunk to f."""
    if axis is None:
        best = None
        pts2 = [(p.x, p.y) for p in points]
        for i in range(len(pts2)):
            for j in range(i + 1, min(len(pts2), i + 40)):
                dx, dy = pts2[j][0] - pts2[i][0], pts2[j][1] - pts2[i][1]
                ln = math.hypot(dx, dy)
                if ln < 1e-3:
                    continue
                ux, uy = dx / ln, dy / ln
                us = [x * ux + y * uy for x, y in pts2]
                vs_ = [-x * uy + y * ux for x, y in pts2]
                area = (max(us) - min(us)) * (max(vs_) - min(vs_))
                if best is None or area < best[0]:
                    best = (area, ux, uy)
        ux, uy = (best[1], best[2]) if best else (1.0, 0.0)
    else:
        ux, uy = axis
    us = [p.x * ux + p.y * uy for p in points]
    vs_ = [-p.x * uy + p.y * ux for p in points]
    zs = [p.z for p in points]
    cu, cv, cz = (max(us) + min(us)) / 2, (max(vs_) + min(vs_)) / 2, (max(zs) + min(zs)) / 2
    hu, hv, hz = (max(us) - min(us)) / 2 * f, (max(vs_) - min(vs_)) / 2 * f, (max(zs) - min(zs)) / 2 * f
    verts = []
    for sz in (-1, 1):
        for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            u, v = cu + su * hu, cv + sv * hv
            verts.append(Vector((u * ux - v * uy, u * uy + v * ux, cz + sz * hz)))
    faces = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return verts, faces


ISLE_C = {i[0]: Vector(W(i[1], i[2], i[5])) for i in ISLANDS}


def island_of(region_points):
    """The island a piece of island geometry belongs to (the nearest centre): its centre and its data."""
    p = sum(region_points, Vector()) / len(region_points)
    name = min(ISLE_C, key=lambda n: (ISLE_C[n].x - p.x) ** 2 + (ISLE_C[n].y - p.y) ** 2)
    return ISLE_C[name], G["ISLE"][name]


def island_centre(region_points):
    return island_of(region_points)[0]


skipped = {"small": 0, "bark": 0, "sails": 0, "boulders": 0}
FAR = ("FarN", "FarNE", "FarNW", "FarNEN")  # 2000+ studs out: no mesh reaching the arena can span them; phones drop them
skipped["far"] = 0
for element, part, key, vs, region in PIECES:
    if region in FAR or (element == "Island" and island_of(vs)[1][0] in FAR):
        skipped["far"] += 1
        continue
    lo = Vector((min(p.x for p in vs), min(p.y for p in vs), min(p.z for p in vs)))
    hi = Vector((max(p.x for p in vs), max(p.y for p in vs), max(p.z for p in vs)))
    size = hi - lo
    dst = bm_for(vs)
    rgb = colour(key)
    if element == "Island":
        c = island_centre(vs)
        if part in ("Grass", "Soil"):
            pts = [Vector((p.x, p.y, p.z - 2.0)) for p in shrink(vs, 0.97, Vector((c.x, c.y, 0)), horizontal=True)]
            v2, f2 = hull(pts) if part == "Soil" else (None, None)
            if part == "Grass":  # the top keeps its rings: a fan following the ground, not a hull
                b = bmesh.new()
                # rebuild the same faces: the builder's bmesh faces are gone, so re-fan the points by angle and ring
                b.free()
                put_top = pts
                # sort into the builder's order: centre first, then rings of n; meadow.py islands() appends exactly so
                n = 40  # the builder's: 5 rings of 40; every other point kept (the rings stay, so it follows the hill)
                pts2 = [put_top[0]] + [put_top[1 + r * n + i] for r in range(5) for i in range(0, n, 2)]
                m = n // 2
                faces = [[0, 1 + (i + 1) % m, 1 + i] for i in range(m)]
                for r in range(4):
                    for i in range(m):
                        j = (i + 1) % m
                        faces.append([1 + r * m + i, 1 + r * m + j, 1 + (r + 1) * m + j, 1 + (r + 1) * m + i])
                put_faces(dst, pts2, faces, rgb)
                continue
            put_faces(dst, v2, f2, rgb)
            continue
        if part == "Rock" and len(vs) == 72:  # the core (3 rings of 24), 10% in, and a point inside the lower keel lobe
            isl = island_of(vs)[1]
            top, depth = isl[5], isl[8]
            pts = shrink(vs, 0.9, Vector((c.x, c.y, 0)), horizontal=True) + [Vector((c.x, c.y, top - depth * 1.05))]
            v2, f2 = hull(pts)
            cut = top - depth * 0.5  # cream rock above, the islands' blue "deep" stone below
            hi_f = [f for f in f2 if sum(v2[i].z for i in f) / len(f) >= cut]
            lo_f = [f for f in f2 if sum(v2[i].z for i in f) / len(f) < cut]
            put_faces(dst, v2, hi_f, rgb)
            put_faces(dst, v2, lo_f, colour("stone_deep"))
            continue
        skipped["boulders"] += 1
        continue
    if element == "WindmillSails" or "Sails" in element:
        skipped["sails"] += 1
        continue
    if part == "Bark" or key.startswith("bark_trunk"):
        skipped["bark"] += 1
        continue
    if max(size.x, size.y, size.z) < 6.0 or min(size.x, size.y, size.z) < 1.0:  # windows, doors, beams, posts
        skipped["small"] += 1
        continue
    if element == "Trees":
        v2, f2 = gem(vs, 0.85)
    elif element == "Windmill":  # turned shapes: their own hull, shrunk
        v2, f2 = hull(shrink(vs, 0.9))
    else:
        v2, f2 = obox(vs, 0.85)
    put_faces(dst, v2, f2, rgb)
# each house: its walls as a plain box along its ridge, and its gable volume (under the roof slabs) in the ROOF colour
n_house = 0
for walls, roof, pieces in HOUSES:
    gable = [p for p in pieces if p[2] == walls and len(p[3]) == 6]
    boxes = [p for p in pieces if p[2] == walls and len(p[3]) != 6]
    if not gable or any(p[4] in FAR for p in pieces):
        continue
    g = gable[0][3]
    top2 = sorted(g, key=lambda v: -v.z)[:2]
    ax = top2[1] - top2[0]
    ln = math.hypot(ax.x, ax.y) or 1.0
    axis = (ax.x / ln, ax.y / ln)
    dst = bm_for(g)
    for b_ in boxes:
        v2, f2 = obox(b_[3], 0.9, axis)
        put_faces(dst, v2, f2, colour(walls))
    v2, f2 = hull(shrink(g, 0.92))
    put_faces(dst, v2, f2, colour(roof))
    n_house += 1
print("BACKDROP skipped", skipped, "houses", n_house, "of", len(HOUSES), flush=True)

# --- objects: split any over 19,000 triangles; each gets an anchor triangle far under the arena ----------------------
ANCHOR = [Vector((0.0, 0.0, -300.0)), Vector((0.1, 0.0, -300.0)), Vector((0.0, 0.1, -300.0))]
objs = []
for region, b in sorted(_BMS.items()):
    bmesh.ops.triangulate(b, faces=b.faces[:])
    tris = len(b.faces)
    parts = max(1, math.ceil(tris / 19000))
    faces = list(b.faces)
    faces.sort(key=lambda f: math.atan2(f.calc_center_median().y, f.calc_center_median().x))
    for k in range(parts):
        sub = faces[k * len(faces) // parts:(k + 1) * len(faces) // parts]
        nb = bmesh.new()
        uv_src = b.loops.layers.uv["UVMap"]
        uv = nb.loops.layers.uv.new("UVMap")
        vmap = {}
        for f in sub:
            for v in f.verts:
                if v not in vmap:
                    vmap[v] = nb.verts.new(v.co)
            try:
                nf = nb.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            for lp, sp in zip(nf.loops, f.loops):
                lp[uv].uv = sp[uv_src].uv
        af = nb.faces.new([nb.verts.new(p) for p in ANCHOR])
        for lp in af.loops:
            lp[uv].uv = cell(colour("soil"))
        name = f"Map_Meadow_Backdrop_{len(objs) + 1}"
        me = bpy.data.meshes.new(name)
        nb.to_mesh(me)
        nb.free()
        ob = bpy.data.objects.new(name, me)
        scene.collection.objects.link(ob)
        objs.append(ob)
    b.free()

size = 64
img = bpy.data.images.new("backdrop_palette", size, size, alpha=False)
px = [0.0] * (size * size * 4)
for i, rgb in enumerate(COLOURS):
    cx, cy = i % 8, 7 - i // 8
    for y in range(cy * 8, (cy + 1) * 8):
        for x in range(cx * 8, (cx + 1) * 8):
            k = (y * size + x) * 4
            px[k:k + 4] = [rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0]
img.pixels = px
img.filepath_raw = os.path.join(OUT, "backdrop_palette.png")
img.file_format = "PNG"
img.save()
mat = bpy.data.materials.new("Backdrop_Palette")
mat.use_nodes = True
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
tex.interpolation = "Closest"
mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
data = {"meshes": {}, "colours": COLOURS}
for ob in objs:
    ob.data.materials.append(mat)
    co = [v.co for v in ob.data.vertices]
    lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    mid = (lo + hi) / 2
    span = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
    assert span < 2040, f"{ob.name} spans {span:.0f} studs: over Roblox's 2048"
    data["meshes"][ob.name] = {"x": round(mid.x, 3), "y": round(mid.z, 3), "z": round(-mid.y, 3), "tris": len(ob.data.polygons),
                               "sx": round(hi.x - lo.x, 1), "sy": round(hi.z - lo.z, 1), "sz": round(hi.y - lo.y, 1)}
for o in scene.objects:
    if o is not None:
        o.select_set(o in objs)
glb = os.path.join(OUT, "backdrop.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                          export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
                          export_image_format="AUTO", export_skins=False, export_animations=False)
json.dump(data, open(os.path.join(OUT, "backdrop.json"), "w", encoding="utf-8", newline="\n"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "backdrop.blend"))
print("BACKDROP", glb, round(os.path.getsize(glb) / 1e6, 2), "MB", {k: v["tris"] for k, v in data["meshes"].items()},
      "colours", len(COLOURS), flush=True)
