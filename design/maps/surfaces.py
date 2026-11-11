"""Painted surfaces for the arenas: the tiled fighting surface, the strip-unwrapped rim, and scenery
painted from baked position maps. Runs inside Blender 5.2. See paint.py for the painting tools.

Texel density (what decides whether a detail survives into Roblox):
- surface: 64-stud tiles, 1024 px each = 16 px per stud (the old single bake was 4.5)
- rim: a strip unwrapped round the oval, split in two pieces, about 15 px per stud
- scenery: cut into wedges round the centre, each smart-projected into its own 1024 texture
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import common as C
import paint as PT

TILE = 64.0  # studs per surface tile; 4 x 3 tiles cover the oval
TILE_PX = 1024
TILE_ORIGIN = (-128.0, -96.0)
# `--reuse-textures` skips repainting a surface tile or rim piece whose three maps are already on disk
# (the painters are slow; use it when only the scenery changed).
REUSE = "--reuse-textures" in sys.argv


def _cached(tex_dir, name):
    paths = {k: os.path.join(tex_dir, f"{name}_{s}.png") for k, s in (("colour", "Color"), ("normal", "Normal"), ("mr", "MR"))}
    return paths if REUSE and all(os.path.exists(p) for p in paths.values()) else None


# --- materials -----------------------------------------------------------------------------------
def load_image(path, data=False):
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color" if data else "sRGB"
    return img


def image_material(name, maps, roughness=0.8, normal_strength=1.0):
    """A material from painted maps: colour, optional OpenGL normal map, optional glTF
    metallic-roughness image (roughness in green, metal in blue). The glTF exporter carries all three
    and Roblox's 3D importer turns them into a SurfaceAppearance."""
    mat, nt, bsdf = C.new_material(name)
    bsdf.inputs["Roughness"].default_value = roughness
    col = nt.nodes.new("ShaderNodeTexImage")
    col.image = load_image(maps["colour"])
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    if maps.get("mr"):
        mr = nt.nodes.new("ShaderNodeTexImage")
        mr.image = load_image(maps["mr"], data=True)
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(mr.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    if maps.get("normal"):
        nm = nt.nodes.new("ShaderNodeTexImage")
        nm.image = load_image(maps["normal"], data=True)
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nmap.inputs["Strength"].default_value = normal_strength
        nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# --- the fighting surface ------------------------------------------------------------------------
def _clip(pts, inside, cut):
    out = []
    for i in range(len(pts)):
        cur, prev = pts[i], pts[i - 1]
        if inside(cur):
            if not inside(prev):
                out.append(cut(prev, cur))
            out.append(cur)
        elif inside(prev):
            out.append(cut(prev, cur))
    return out


def clip_rect(poly, x0, x1, y0, y1):
    """Sutherland-Hodgman: a convex polygon cut to an axis-aligned rectangle."""

    def at_x(xc):
        return lambda p, q: (xc, p[1] + (q[1] - p[1]) * (xc - p[0]) / (q[0] - p[0]))

    def at_y(yc):
        return lambda p, q: (p[0] + (q[0] - p[0]) * (yc - p[1]) / (q[1] - p[1]), yc)

    pts = list(poly)
    for inside, cut in (
        (lambda p: p[0] >= x0, at_x(x0)),
        (lambda p: p[0] <= x1, at_x(x1)),
        (lambda p: p[1] >= y0, at_y(y0)),
        (lambda p: p[1] <= y1, at_y(y1)),
    ):
        if not pts:
            break
        pts = _clip(pts, inside, cut)
    return pts


def _area(pts):
    return 0.5 * abs(sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(pts, pts[1:] + pts[:1])))


def surface_tiles(prefix, z_bottom, painter, tex_dir, normal_strength=1.0, a=C.A - C.RIM, b=C.B - C.RIM):
    """The fighting surface as flat prism tiles (top exactly at z = 0), each with its own painted maps.
    `painter(X, Y)` gets stud coordinates (rows = y) and returns (colour, height, roughness)."""
    poly = [C.oval_xy(i / C.SEGMENTS * math.tau, a, b) for i in range(C.SEGMENTS)]
    objs = []
    step = TILE / TILE_PX
    for j in range(3):
        for i in range(4):
            x0 = TILE_ORIGIN[0] + i * TILE
            y0 = TILE_ORIGIN[1] + j * TILE
            pts = clip_rect(poly, x0, x0 + TILE, y0, y0 + TILE)
            if len(pts) < 3 or _area(pts) < 1.0:
                continue
            bm = bmesh.new()
            uv = bm.loops.layers.uv.new("UVMap")
            top = [bm.verts.new((x, y, 0.0)) for x, y in pts]
            bot = [bm.verts.new((x, y, z_bottom)) for x, y in pts]
            bm.faces.new(top)
            bm.faces.new(list(reversed(bot)))
            for k in range(len(pts)):
                n = (k + 1) % len(pts)
                bm.faces.new((top[k], bot[k], bot[n], top[n]))
            for f in bm.faces:
                for loop in f.loops:
                    co = loop.vert.co
                    loop[uv].uv = ((co.x - x0) / TILE, (co.y - y0) / TILE)
            name = f"{prefix}_{j}{i}"
            # painted with a one-pixel border so the normals are right at the tile edges
            maps = _cached(tex_dir, name)
            if maps is None:
                xs = x0 + (np.arange(-1, TILE_PX + 1) + 0.5) * step
                ys = y0 + (np.arange(-1, TILE_PX + 1) + 0.5) * step
                X, Y = np.meshgrid(xs, ys)
                colour, height, rough = painter(X, Y)
                maps = PT.save_maps(tex_dir, name, colour, height, rough, px_per_stud=TILE_PX / TILE, crop=1)
            objs.append(C.mesh_object(name, bm, image_material(name, maps, normal_strength=normal_strength)))
            print("PAINTED", name, flush=True)
    return objs


def top_is_flat(prefixes):
    """The fighting surface and the rim's top: every upward-facing face exactly at z = 0, and nothing
    of them higher. Returns (ok, number of pieces)."""
    objs = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(prefixes)]
    ok = bool(objs)
    for o in objs:
        me = o.data
        top = max(v.co.z for v in me.vertices)
        ups = [p for p in me.polygons if p.normal.z > 0.99]
        zs = [me.vertices[i].co.z for p in ups for i in p.vertices]
        ok = ok and abs(top) < 1e-4 and bool(zs) and max(abs(z) for z in zs) < 1e-4
    return ok, len(objs)


def edge_distance(X, Y, a=C.A - C.RIM, b=C.B - C.RIM):
    """Roughly how far (studs) a point is inside the surface's edge."""
    re = np.sqrt((X / a) ** 2 + (Y / b) ** 2)
    th = np.arctan2(Y / b, X / a)
    local = np.hypot(a * np.cos(th), b * np.sin(th))
    return (1.0 - re) * local


# --- the rim -------------------------------------------------------------------------------------
def oval_arclength(a, b, samples=8192):
    """Lookup tables (t, cumulative length) round an oval, and its perimeter."""
    t = np.linspace(0, math.tau, samples + 1)
    x, y = a * np.cos(t), b * np.sin(t)
    cum = np.concatenate([[0.0], np.cumsum(np.hypot(np.diff(x), np.diff(y)))])
    return t, cum, float(cum[-1])


def rim_strip(name, width, depth, chamfer, painter, tex_dir, pieces=2, segs=24, px=1024, a_out=C.A, b_out=C.B):
    """The rim: a band flush with the surface (top at z = 0) with a chamfered outer edge, unwrapped as
    a strip: u runs round the oval, v across the top, down the chamfer and side and under the bottom.
    Split into `pieces` meshes, each laid out in rows of one texture. `painter(S, Pp, FACE, X, Y, Z, info)`
    gets studs round the rim, studs across the profile, the face (0 top, 1 chamfer, 2 side, 3 bottom)
    and world position, and returns (colour, height, roughness)."""
    t_tab, cum, perim = oval_arclength(a_out, b_out)
    a_in, b_in = a_out - width, b_out - width
    p1 = width - chamfer
    p2 = p1 + chamfer * math.sqrt(2)
    p3 = p2 + (depth - chamfer)
    p4 = p3 + width
    breaks = [0.0, p1, p2, p3, p4]
    piece_len = perim / pieces
    gutter = 6
    rows = 1
    while True:
        r = rows + 1
        if r * (math.ceil(p4 * px * r / piece_len) + gutter) > px:
            break
        rows = r
    row_len = piece_len / rows
    d = px / row_len
    row_px = math.ceil(p4 * d) + gutter

    def section(s):
        t = float(np.interp(s % perim, cum, t_tab))
        ox, oy = a_out * math.cos(t), b_out * math.sin(t)
        ix, iy = a_in * math.cos(t), b_in * math.sin(t)
        ln = math.hypot(ox - ix, oy - iy)
        ux, uy = (ox - ix) / ln, (oy - iy) / ln
        return [(ix, iy, 0.0), (ox - ux * chamfer, oy - uy * chamfer, 0.0), (ox, oy, -chamfer), (ox, oy, -depth), (ix, iy, -depth)]

    objs = []
    info = dict(p1=p1, p2=p2, p3=p3, p4=p4, perimeter=perim, depth=depth, width=width)
    for pc in range(pieces):
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        for r in range(rows):
            s0 = pc * piece_len + r * row_len
            v0 = (r * row_px + gutter / 2) / px
            secs = []
            for k in range(segs + 1):
                s = s0 + row_len * k / segs
                secs.append((s, [bm.verts.new(p) for p in section(s)]))
            for k in range(segs):
                (sa, va), (sb, vb) = secs[k], secs[k + 1]
                for e in range(5):
                    f = bm.faces.new((va[e], va[(e + 1) % 5], vb[(e + 1) % 5], vb[e]))
                    pa, pb = (breaks[e], breaks[e + 1]) if e < 4 else (p4, p4)
                    for loop, (s, p) in zip(f.loops, ((sa, pa), (sa, pb), (sb, pb), (sb, pa))):
                        loop[uv].uv = ((s - s0) / row_len, v0 + p * d / px)
        # end caps so each piece is closed (never seen; their UVs sit on one texel)
        # (a section listed in order faces +tangent, so the start cap is reversed)
        for s, flip in ((pc * piece_len, True), ((pc + 1) * piece_len, False)):
            ring = [bm.verts.new(p) for p in section(s)]
            f = bm.faces.new(list(reversed(ring)) if flip else ring)
            for loop in f.loops:
                loop[uv].uv = (0.5, (gutter / 2 + 0.5) / px)
        # the strip's coordinates for every texel of the atlas
        S = np.zeros((px, px))
        Pp = np.full((px, px), p4)
        cols = np.arange(px) + 0.5
        for r in range(rows):
            y0 = r * row_px
            S[y0 : y0 + row_px, :] = pc * piece_len + r * row_len + cols[None, :] / d
            pr = (np.arange(row_px) - gutter / 2 + 0.5) / d
            Pp[y0 : y0 + row_px, :] = np.clip(pr, 0.0, p4)[:, None]
        used = rows * row_px
        S[used:, :] = S[used - 1, :]
        FACE = np.digitize(Pp, [p1, p2, p3]).astype(np.int64)
        T = np.interp(S % perim, cum, t_tab)
        OX, OY = a_out * np.cos(T), b_out * np.sin(T)
        IX, IY = a_in * np.cos(T), b_in * np.sin(T)
        ft = np.clip(Pp / width, 0, 1)
        fb = np.clip((Pp - p3) / width, 0, 1)
        X = np.where(FACE <= 1, IX + (OX - IX) * ft, np.where(FACE == 2, OX, OX + (IX - OX) * fb))
        Y = np.where(FACE <= 1, IY + (OY - IY) * ft, np.where(FACE == 2, OY, OY + (IY - OY) * fb))
        Z = np.where(FACE == 0, 0.0, np.where(FACE == 1, -(Pp - p1) / math.sqrt(2), np.where(FACE == 2, -chamfer - (Pp - p2), -depth)))
        piece = f"{name}_{pc + 1}"
        maps = _cached(tex_dir, piece)
        if maps is None:
            colour, height, rough = painter(S, Pp, FACE, X, Y, Z, info)
            maps = PT.save_maps(tex_dir, piece, colour, height, rough, px_per_stud=d)
        objs.append(C.mesh_object(piece, bm, image_material(piece, maps)))
        print("PAINTED", piece, f"{rows} rows, {d:.1f} px/stud", flush=True)
    return objs


# --- scenery: split, unwrap, bake position, paint ------------------------------------------------
def split_sectors(obj, k=4):
    """Cuts a mesh into k wedges round the vertical axis (k even), so each gets its own texture."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for j in range(k // 2):
        ang = math.pi * j / (k // 2)
        n = Vector((-math.sin(ang), math.cos(ang), 0.0))
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=n)
    mat = obj.data.materials[0] if obj.data.materials else None
    cols = list(obj.users_collection)
    base = obj.name
    out = []
    for i in range(k):
        b2 = bm.copy()
        drop = []
        for f in b2.faces:
            c = f.calc_center_median()
            if int((math.atan2(c.y, c.x) % math.tau) / (math.tau / k)) % k != i:
                drop.append(f)
        bmesh.ops.delete(b2, geom=drop, context="FACES")
        if not b2.faces:
            b2.free()
            continue
        me = bpy.data.meshes.new(f"{base}_{i + 1}")
        b2.to_mesh(me)
        b2.free()
        for poly in me.polygons:
            poly.use_smooth = False
        o = bpy.data.objects.new(f"{base}_{i + 1}", me)
        if mat:
            me.materials.append(mat)
        for c in cols:
            c.objects.link(o)
        out.append(o)
    bm.free()
    bpy.data.objects.remove(obj)
    return out


def split_caps(obj, threshold=0.7, suffix="_Soffit"):
    """Splits off the near-horizontal faces (the big tops and undersides of stepped slabs), so they
    don't take most of the texture away from the walls, which are what the recovery camera sees.
    Returns (walls, caps)."""
    mat = obj.data.materials[0] if obj.data.materials else None
    cols = list(obj.users_collection)
    out = []
    for keep_caps in (False, True):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.normal_update()
        drop = [f for f in bm.faces if (abs(f.normal.z) > threshold) != keep_caps]
        bmesh.ops.delete(bm, geom=drop, context="FACES")
        name = obj.name + (suffix if keep_caps else "")
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(name, me)
        if mat:
            me.materials.append(mat)
        for c in cols:
            c.objects.link(o)
        out.append(o)
    bpy.data.objects.remove(obj)
    return out[0], out[1]


def _select_only(obj):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _bake_into(obj, img, kind, emit_from=None):
    """Bakes into `img` with a temporary material: EMIT of position or normal, or AO."""
    old = obj.data.materials[0]
    mat = bpy.data.materials.new("BakeTmp")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    vm = nt.nodes.new("ShaderNodeVectorMath")
    vm.operation = "MULTIPLY_ADD"
    scale, offset = (1 / 4000.0, 0.5) if emit_from == "Position" else (0.5, 0.5)
    vm.inputs[1].default_value = (scale, scale, scale)
    vm.inputs[2].default_value = (offset, offset, offset)
    nt.links.new(geo.outputs[emit_from or "Normal"], vm.inputs[0])
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(vm.outputs[0], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    obj.data.materials[0] = mat
    _select_only(obj)
    bpy.context.scene.cycles.samples = 24 if kind == "AO" else 1
    bpy.ops.object.bake(type=kind, margin=8, margin_type="EXTEND")
    obj.data.materials[0] = old
    bpy.data.materials.remove(mat)


def _pixels(img):
    buf = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    return buf.reshape(img.size[1], img.size[0], 4)


def paint_scenery(objs, painter, tex_dir, px=1024, roughness=0.9, ao_strength=0.8, ao_tint=(0.36, 0.30, 0.30), ao_distance=6.0):
    """For each object: smart-project UVs, bake world position, normal and ambient occlusion with Cycles,
    paint the colour with `painter(P, N, obj)` ((h, w, 3) arrays, world space) and multiply in the
    occlusion, tinted (a warm tint gives a warm shadow). Each object gets an image material, so what
    Blender shows is what is exported."""
    import addon_utils

    addon_utils.enable("cycles", default_set=True)
    scene = bpy.context.scene
    engine = scene.render.engine
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.bake.target = "IMAGE_TEXTURES"
    if scene.world:
        scene.world.light_settings.distance = ao_distance
    tint = np.asarray(ao_tint, dtype=np.float64)
    for obj in objs:
        _select_only(obj)
        if not obj.data.uv_layers:
            obj.data.uv_layers.new(name="UVMap")
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.006)
        bpy.ops.object.mode_set(mode="OBJECT")
        imgs = {k: bpy.data.images.new(f"bake_{k}", px, px, float_buffer=True) for k in ("Position", "Normal", "AO")}
        _bake_into(obj, imgs["Position"], "EMIT", "Position")
        _bake_into(obj, imgs["Normal"], "EMIT", "Normal")
        _bake_into(obj, imgs["AO"], "AO")
        Pw = (_pixels(imgs["Position"])[..., :3].astype(np.float64) - 0.5) * 4000.0
        Nw = _pixels(imgs["Normal"])[..., :3].astype(np.float64) * 2.0 - 1.0
        ao = np.clip(_pixels(imgs["AO"])[..., 0].astype(np.float64), 0, 1)
        for img in imgs.values():
            bpy.data.images.remove(img)
        colour = painter(Pw, Nw, obj)
        occl = (1.0 - ao)[..., None]
        colour = colour * (1.0 - ao_strength * occl * (1.0 - tint))
        maps = {"colour": PT.save_png(os.path.join(tex_dir, f"{obj.name}_Color.png"), colour)}
        old = obj.data.materials[0]
        obj.data.materials[0] = image_material(f"{obj.name}_Painted", maps, roughness=roughness)
        if old and old.users == 0:
            bpy.data.materials.remove(old)
        print("PAINTED", obj.name, flush=True)
    scene.render.engine = engine
    return objs
