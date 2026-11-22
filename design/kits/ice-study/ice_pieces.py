"""The Frost kit's ice, second version (2026-11-22): blades and broken chunks, for Blender 5.2.

The look is measured from the owner's two picks (design/kits/ice-study/ref_measurements.json and the sheets):
  C  "Unreal VFX | Niagara-Ice" (YouTube dIWMbXMnwqc, 2.2-5.2 s): about 15 long flat BLADES from one centre.
     Broad blades are 16-24 % as wide as they are long, needles 5-7 %; both are widest about 40 % of the way up,
     narrow again at the root, and end in a chisel point that sits over one edge. Leans 4-80 degrees.
     Pale glass: (125,162,198) to (236,251,255); the tone changes facet by facet, not from root to tip.
  D  "Unreal VFX Portfolio [ Ice Magic ]" (YouTube hAUY_cFofLw, 8-12.5 s): broken CHUNKS, lumps of 8-14 flat
     faces, 1.2 to 2.2 times as long as wide, grey-white with bright edges.

Conventions the game relies on (src/client/Fx/KitModels.luau): each piece is 1 unit tall, +Z up, standing on
z = 0; the game sizes it by its height and places it by the MIDDLE OF ITS BOUNDING BOX, so every piece is
centred on the origin in X and Y. Flat shading. One colour attribute, "Col" (FLOAT_COLOR, face corner): the
numbers in it are what Roblox multiplies the part's Color by, so they are kept between (0.64, 0.79, 0.88) and 1
(Neon shows anything much darker as navy, and the white-hot flash stops being white).

Every blade is listed by hand below: nothing here is random.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

HEX = [(0.50, 0.0), (0.16, 0.5), (-0.26, 0.5), (-0.50, 0.0), (-0.20, -0.5), (0.24, -0.5)]   # a flat six-sided blade
RHOMB = [(0.50, 0.0), (0.05, 0.5), (-0.50, 0.0), (-0.08, -0.5)]                             # a needle
# along the blade: (share of its length, width, thickness, sideways kink in widths)
BROAD = [(-0.12, 0.40, 0.60, 0.00), (0.14, 0.76, 0.90, 0.00), (0.42, 1.00, 1.00, 0.05), (0.74, 0.68, 0.74, 0.02), (0.92, 0.32, 0.42, 0.00)]
NEEDLE = [(-0.12, 0.50, 0.60, 0.00), (0.32, 1.00, 1.00, 0.04), (0.80, 0.52, 0.60, 0.00)]
STUB = [(-0.20, 0.70, 0.80, 0.00), (0.30, 1.00, 1.00, 0.04), (0.72, 0.60, 0.70, 0.00)]

KEY = Vector((0.45, -0.35, 0.82)).normalized()   # the side the paler facets face


def direction(lean, azimuth):
    """Unit vector leaning `lean` degrees from straight up, toward compass `azimuth` (0 = +X, 90 = +Y)."""
    l, a = math.radians(lean), math.radians(azimuth)
    return Vector((math.sin(l) * math.cos(a), math.sin(l) * math.sin(a), math.cos(l)))


def blade_shell(root, lean, azimuth, length, width, flat=0.5, kind="broad", roll=0.0, tip=1.0):
    """One closed blade as its own bmesh, cut off flat at z = 0.
    `width` and the blade's thickness (`flat` x width) are in units of its length; `roll` turns it about its own
    axis (degrees); `tip` (-1 to 1) puts the point over one edge or the other."""
    bm = bmesh.new()
    axis = direction(lean, azimuth)
    side = axis.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    side = (Matrix.Rotation(math.radians(roll), 3, axis) @ side).normalized()
    face = axis.cross(side).normalized()
    stations = {"broad": BROAD, "needle": NEEDLE, "stub": STUB}[kind]
    section = RHOMB if kind == "needle" else HEX
    w, t = width * length, width * length * flat
    rings = []
    for share, wide, thick, kink in stations:
        centre = Vector(root) + axis * (share * length) + side * (kink * w)
        rings.append([bm.verts.new(centre + side * (x * w * wide) + face * (y * t * thick)) for x, y in section])
    last_wide = stations[-1][1]
    point = bm.verts.new(Vector(root) + axis * length + side * (tip * 0.42 * w * last_wide))
    count = len(section)
    for lower, upper in zip(rings, rings[1:]):
        for i in range(count):
            j = (i + 1) % count
            bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
    for i in range(count):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % count], point))
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    cut_flat(bm)
    return bm


def cut_flat(bm):
    """Removes everything below z = 0 and closes the hole, so the shell stands on the floor."""
    if min(v.co.z for v in bm.verts) >= -1e-6:
        return
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    # dist=1e-4: with 0, vertices lying on the plane are cut inconsistently (Blender Mastery 0, section 2b).
    result = bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-4, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if edges:
        bmesh.ops.triangle_fill(bm, edges=edges, use_beauty=True)
    for v in bm.verts:
        if abs(v.co.z) < 1e-4:
            v.co.z = 0.0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def chunk_shell(points, squash=(1, 1, 1), at=(0, 0, 0)):
    """A broken lump: the convex hull of hand-placed points (each (x, y, z))."""
    bm = bmesh.new()
    verts = [bm.verts.new((p[0] * squash[0] + at[0], p[1] * squash[1] + at[1], p[2] * squash[2] + at[2])) for p in points]
    result = bmesh.ops.convex_hull(bm, input=verts)
    for v in [g for g in result["geom_unused"] + result["geom_interior"] if isinstance(g, bmesh.types.BMVert)]:
        if v.is_valid:
            bm.verts.remove(v)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def merge(shells):
    """Joins closed shells into one bmesh (they pass through each other; each stays closed)."""
    out = bmesh.new()
    for shell in shells:
        mesh = bpy.data.meshes.new("_tmp")
        shell.to_mesh(mesh)
        shell.free()
        out.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    return out


SHADE = (0.64, 0.79, 0.88)   # reference C: a shaded facet (132,183,220) over a lit one (206,233,250)


def paint(bm, tips=0.25):
    """One tone per flat face, by which way it faces: white toward KEY and near the points, SHADE away from it.
    Nothing goes below SHADE: on Neon (the white-hot flash) 0.64 still shows near white, 0.4 would show navy."""
    layer = bm.loops.layers.float_color.new("Col")
    top = max(v.co.z for v in bm.verts)
    for face in bm.faces:
        facing = face.normal.dot(KEY)                              # -1 to 1
        height = face.calc_center_median().z / max(top, 1e-6)     # 0 to 1
        value = max(0.0, min(1.0, 0.5 + 0.5 * facing + tips * (height - 0.5)))
        colour = tuple(SHADE[i] + (1.0 - SHADE[i]) * value for i in range(3)) + (1.0,)
        for loop in face.loops:
            loop[layer] = colour


TILE = 2.0   # the frost texture repeats twice over a piece's height


def box_uvs(bm):
    """UVs by box projection: each flat face is mapped along the axis it faces most. Every piece gets UVs even
    while it is only vertex-coloured, so a texture can be added later without remodelling (vault: Trim Sheets
    Atlases and Vertex Colors)."""
    layer = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        n = face.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        a, b = [i for i in range(3) if i != axis]
        for loop in face.loops:
            co = loop.vert.co
            loop[layer].uv = (co[a] * TILE + 0.5, co[b] * TILE)


def finish(name, bm):
    """Triangulates, stands the piece on z = 0 at 1 unit tall, centres its bounding box on the origin, paints it."""
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    low = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
    high = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
    scale = 1.0 / (high.z - low.z)
    shift = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    for v in bm.verts:
        v.co = (v.co - shift) * scale
        if abs(v.co.z) < 1e-6:
            v.co.z = 0.0
    bm.normal_update()
    paint(bm)
    box_uvs(bm)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = False
    mesh.color_attributes.active_color = mesh.color_attributes["Col"]
    mesh.color_attributes.render_color_index = 0
    mesh["paint"] = "Col"
    mesh["scale"] = scale     # table units -> the finished piece's units (its height is 1)
    return mesh


# ---- the five pieces. Blades: (root x, y, lean, azimuth, length, width, flatness, kind, roll, tip) ----

SPIKE_TALL = [
    ((0.0, 0.0), 0, 0, 1.00, 0.24, 0.55, "broad", 20, 1.0),
    ((0.05, 0.02), 16, 40, 0.62, 0.22, 0.55, "broad", 60, -1.0),
    ((-0.04, -0.03), 18, 230, 0.34, 0.30, 0.60, "stub", 0, -1.0),
]
SPIKE_THICK = [
    ((0.0, 0.0), 3, 90, 1.00, 0.30, 0.52, "broad", 10, -1.0),
    ((0.07, 0.02), 28, 20, 0.72, 0.24, 0.50, "broad", 70, 1.0),
    ((-0.06, -0.02), 34, 200, 0.55, 0.26, 0.50, "broad", 60, -1.0),
    ((-0.02, 0.06), 40, 110, 0.60, 0.10, 0.60, "needle", 30, 1.0),
    ((0.0, -0.07), 20, 280, 0.30, 0.34, 0.60, "stub", 0, 1.0),
]
# A flower round a tall middle, after the reference: broad blades high, needles low and long, stubs between.
# The middle blade is twice the skirt's height on purpose: the game sizes a piece by its HEIGHT, so a flower
# as wide as the reference's (2.5 times its height) would be 40 studs across in today's Glacier and reach the
# camera. With this middle, the widest blade reaches 0.45 of the height from the centre.
CLUMP = [
    ((0.0, 0.0), 3, 60, 1.60, 0.15, 0.55, "broad", 0, -1.0),
    ((-0.05, -0.03), 13, 200, 1.22, 0.16, 0.50, "broad", 50, 1.0),
    ((0.05, -0.02), 20, 330, 1.00, 0.17, 0.50, "broad", 70, -1.0),
    ((-0.04, 0.04), 42, 150, 0.80, 0.19, 0.50, "broad", 80, 1.0),
    ((0.06, 0.02), 36, 20, 0.78, 0.17, 0.50, "broad", 75, 1.0),
    ((-0.02, -0.06), 46, 265, 0.70, 0.18, 0.50, "broad", 70, -1.0),
    ((0.02, 0.07), 54, 95, 0.78, 0.07, 0.60, "needle", 40, 1.0),
    ((-0.07, -0.02), 55, 205, 0.80, 0.07, 0.60, "needle", 10, -1.0),
    ((0.06, -0.05), 53, 310, 0.76, 0.07, 0.60, "needle", 50, -1.0),
    ((0.06, 0.05), 52, 55, 0.66, 0.09, 0.60, "needle", 20, 1.0),
    ((0.02, 0.03), 22, 120, 0.36, 0.34, 0.60, "stub", 0, 1.0),
    ((-0.03, -0.02), 26, 250, 0.32, 0.36, 0.60, "stub", 30, -1.0),
    ((0.03, -0.03), 24, 330, 0.30, 0.36, 0.60, "stub", 60, 1.0),
]

# Chunk points are (x, y, z) on a rough lump; flat faces come from the hull.
SHARD_POINTS = [   # a wedge with few, large faces (reference D's chunks have 8-14)
    (0.00, 0.00, 0.00), (0.24, 0.12, 0.16), (-0.20, 0.16, 0.22), (0.06, -0.26, 0.20), (0.30, -0.08, 0.55),
    (-0.28, -0.04, 0.62), (0.04, 0.26, 0.60), (0.10, -0.10, 0.92), (-0.06, 0.06, 1.00),
]
BLOCK_POINTS = [   # an uneven boulder of big flat faces: a five-sided foot, a wider belt, a broken crown
    (0.44, 0.12, 0.00), (0.05, 0.47, 0.00), (-0.42, 0.22, 0.00), (-0.30, -0.38, 0.00), (0.30, -0.36, 0.00),
    (0.55, 0.05, 0.42), (0.12, 0.56, 0.50), (-0.52, 0.30, 0.36), (-0.40, -0.46, 0.55), (0.36, -0.44, 0.40),
    (0.22, 0.14, 0.92), (-0.20, 0.10, 1.00), (-0.02, -0.24, 0.86),
]
BLOCK_FOOT = [   # small lumps leaning against the block's foot: (points scale, at)
    ((0.30, 0.30, 0.34), (0.44, 0.22, 0.0)), ((0.26, 0.28, 0.26), (-0.40, -0.30, 0.0)), ((0.22, 0.22, 0.22), (-0.10, 0.48, 0.0)),
]


def blades(table):
    return [blade_shell((x, y, 0.0), lean, azimuth, length, width, flat, kind, roll, tip)
            for (x, y), lean, azimuth, length, width, flat, kind, roll, tip in table]


BLADE_TABLES = {"Ice_SpikeTall": SPIKE_TALL, "Ice_SpikeThick": SPIKE_THICK, "Ice_Clump": CLUMP}


def blade_list(kit):
    """For the checks: {piece: [(unit axis, length in piece units, width / length, kind), ...]}."""
    out = {}
    for name, table in BLADE_TABLES.items():
        scale = kit[name]["scale"]
        out[name] = [(direction(lean, azimuth), length * scale, width, kind)
                     for _root, lean, azimuth, length, width, _flat, kind, _roll, _tip in table]
    return out


def build_kit():
    """Returns {piece name: mesh}, the game's five names."""
    kit = {}
    kit["Ice_SpikeTall"] = finish("Ice_SpikeTall", merge(blades(SPIKE_TALL)))
    kit["Ice_SpikeThick"] = finish("Ice_SpikeThick", merge(blades(SPIKE_THICK)))
    kit["Ice_Clump"] = finish("Ice_Clump", merge(blades(CLUMP)))
    kit["Ice_Shard"] = finish("Ice_Shard", merge([chunk_shell(SHARD_POINTS)]))
    shells = [chunk_shell(BLOCK_POINTS)]
    for squash, at in BLOCK_FOOT:
        shells.append(chunk_shell(SHARD_POINTS, squash, at))
    kit["Ice_Block"] = finish("Ice_Block", merge(shells))
    return kit


def mesh_report(mesh):
    """Blender Mastery 0's mesh report, for a mesh datablock."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    low = [min(v.co[i] for v in bm.verts) for i in range(3)]
    high = [max(v.co[i] for v in bm.verts) for i in range(3)]
    rep = {
        "tris": sum(len(f.verts) - 2 for f in bm.faces),
        "ngons": sum(1 for f in bm.faces if len(f.verts) > 4),
        "non_manifold_edges": sum(1 for e in bm.edges if not e.is_manifold),
        "loose_verts": sum(1 for v in bm.verts if not v.link_edges),
        "loose_edges": sum(1 for e in bm.edges if not e.link_faces),
        "zero_area_faces": sum(1 for f in bm.faces if f.calc_area() < 1e-8),
        "size": [round(high[i] - low[i], 4) for i in range(3)],
        "z_min": round(low[2], 6),
        "height": round(high[2] - low[2], 6),
        "bbox_centre_xy": [round((low[i] + high[i]) / 2, 6) for i in range(2)],
        "colour_sets": [a.name for a in mesh.color_attributes],
    }
    before = [f.normal.copy() for f in bm.faces]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    rep["flipped_faces"] = sum(1 for f, n in zip(bm.faces, before) if f.normal.dot(n) < 0)
    values = [c for d in mesh.color_attributes["Col"].data for c in d.color[:3]] if "Col" in mesh.color_attributes else []
    rep["colour_min"] = round(min(values), 3) if values else None
    rep["colour_max"] = round(max(values), 3) if values else None
    bm.free()
    return rep
