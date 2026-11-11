"""Shared building blocks for the three Haymaker Tussle arenas, run inside Blender (5.2, headless).

Units: 1 Blender unit = 1 Roblox stud. Z is up; the fighting surface's top is z = 0. Every map has the
same flat oval shape: 213 x 176 studs for 25 fighters (Gnomon: 426 x 352, see OVALS) (semi-axes A along X, B along Y; was 230 x 190 for 30), a 3-stud contrasting rim band flush
with the surface, and nothing standing on it. Personality goes into the surface paint, the island's
sides and underside, and the scenery beyond (kept at least 60 studs past the edge if it rises above the
rim).

Lighting follows the user's image 4: bright blue sky, soft white clouds, a warm sun about 40 degrees up,
gentle blue-tinted shadows that keep the local colours. Painted materials are matte (roughness near 1,
no metalness), per the vault note "Hand-Painted and Stylized Texturing".

Roblox limits (vault: "Exporting and Validating Models for Roblox"): at most 20,000 triangles and one
material per mesh, one UV set. `check_export` enforces them on the Export collection.
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

# 2026-11-10: sized for 25 fighters (was 115 x 95 for 30): same 115:95 shape, same room per fighter.
# Every map's oval before the user's enlargement brief (2026-11-10), recorded so a size is never derived by
# multiplying (a rerun can't double an arena twice): the semi-axes are ABSOLUTE numbers per map.
ORIGINAL_OVAL = (106.5, 88.0)  # semi-axes A (along X, the long one), B (along Y): 213 x 176 studs
OVALS = {
    # Gnomon Isle doubled once (user, 2026-11-10): 426 x 352 studs, from ORIGINAL_OVAL. Absolute; never scale again.
    "gnomon": (213.0, 176.0),
}
# Which map this Blender run builds: gnomon.py sets HT_MAP before importing this module; rebuild.sh exports it
# for the export and check steps. Unknown or unset -> ORIGINAL_OVAL (Kitestead, Saltcrest).
MAP = os.environ.get("HT_MAP", "")
A, B = OVALS.get(MAP, ORIGINAL_OVAL)
SCALE = A / ORIGINAL_OVAL[0]  # how much bigger than the original this map's oval is (1 or 2)
RIM = 3.0  # contrasting rim band width
SEGMENTS = 128

# Linear colours. The world's Generated Z is the view direction's height: 0 at the horizon, 1 straight up.
SKY_ZENITH = (0.05, 0.24, 0.80)
SKY_MID = (0.16, 0.44, 0.92)
SKY_HORIZON = (0.46, 0.70, 0.97)
SUN_COLOUR = (1.0, 0.93, 0.80)


# --- scene ---------------------------------------------------------------------------------------
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    for name in ("Export", "Scenery", "Setup"):
        col = bpy.data.collections.new(name)
        scene.collection.children.link(col)
    return scene


def collection(name):
    return bpy.data.collections[name]


def link(obj, col="Export"):
    collection(col).objects.link(obj)
    return obj


def mesh_object(name, bm, mat, col="Export", smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(name, me)
    if mat is not None:
        me.materials.append(mat)
    return link(obj, col)


def join(objects, name):
    """Joins objects into one mesh (one material: the first's)."""
    if not objects:
        return None
    ctx = bpy.context
    for o in ctx.view_layer.objects:
        o.select_set(False)
    for o in objects:
        o.select_set(True)
    ctx.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = ctx.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    while len(obj.data.materials) > 1:
        obj.data.materials.pop(index=len(obj.data.materials) - 1)
    for poly in obj.data.polygons:
        poly.material_index = 0
    return obj


# --- shapes ---------------------------------------------------------------------------------------
def oval_xy(t, a=A, b=B):
    return a * math.cos(t), b * math.sin(t)


def oval_prism(bm, a, b, z_top, z_bottom, segments=SEGMENTS, jitter=0.0, rng=None, taper=1.0):
    """An oval slab between two heights. `taper` scales the bottom ring; `jitter` roughens the outline
    (broad facets) for rock."""
    top, bottom = [], []
    for i in range(segments):
        t = i / segments * math.tau
        x, y = oval_xy(t, a, b)
        j = 1.0 + (rng.uniform(-jitter, jitter) if rng and jitter else 0.0)
        top.append(bm.verts.new((x * j, y * j, z_top)))
        jb = 1.0 + (rng.uniform(-jitter, jitter) if rng and jitter else 0.0)
        bottom.append(bm.verts.new((x * taper * jb, y * taper * jb, z_bottom)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bottom)))
    for i in range(segments):
        n = (i + 1) % segments
        bm.faces.new((top[i], bottom[i], bottom[n], top[n]))
    return top, bottom


def ring(bm, a_out, b_out, a_in, b_in, z_top, z_bottom, segments=SEGMENTS):
    """A flat band between two ovals, with an outer side face down to z_bottom (closed)."""
    ot, it, ob, ib = [], [], [], []
    for i in range(segments):
        t = i / segments * math.tau
        x, y = math.cos(t), math.sin(t)
        ot.append(bm.verts.new((a_out * x, b_out * y, z_top)))
        it.append(bm.verts.new((a_in * x, b_in * y, z_top)))
        ob.append(bm.verts.new((a_out * x, b_out * y, z_bottom)))
        ib.append(bm.verts.new((a_in * x, b_in * y, z_bottom)))
    for i in range(segments):
        n = (i + 1) % segments
        bm.faces.new((it[i], ot[i], ot[n], it[n]))  # top
        bm.faces.new((ot[i], ob[i], ob[n], ot[n]))  # outer side
        bm.faces.new((ib[i], it[i], it[n], ib[n]))  # inner side (hidden, keeps it watertight)
        bm.faces.new((ob[i], ib[i], ib[n], ob[n]))  # bottom


def box(bm, centre, size, rot_z=0.0):
    cx, cy, cz = centre
    sx, sy, sz = (s / 2 for s in size)
    c, s = math.cos(rot_z), math.sin(rot_z)
    pts = []
    for dz in (-sz, sz):
        for dy in (-sy, sy):
            for dx in (-sx, sx):
                pts.append(bm.verts.new((cx + dx * c - dy * s, cy + dx * s + dy * c, cz + dz)))
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    for face in f:
        bm.faces.new([pts[i] for i in face])


def cylinder(bm, start, end, radius, sides=8):
    a, b = Vector(start), Vector(end)
    axis = (b - a).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    ra, rb = [], []
    for i in range(sides):
        t = i / sides * math.tau
        off = (u * math.cos(t) + v * math.sin(t)) * radius
        ra.append(bm.verts.new(a + off))
        rb.append(bm.verts.new(b + off))
    bm.faces.new(list(reversed(ra)))
    bm.faces.new(rb)
    for i in range(sides):
        n = (i + 1) % sides
        bm.faces.new((ra[i], ra[n], rb[n], rb[i]))


def cone(bm, base_centre, radius, height, sides=6, rng=None, jitter=0.0, tip_offset=(0, 0)):
    cx, cy, cz = base_centre
    ring_v = []
    for i in range(sides):
        t = i / sides * math.tau + (rng.uniform(0, 0.4) if rng else 0)
        r = radius * (1 + (rng.uniform(-jitter, jitter) if rng else 0))
        ring_v.append(bm.verts.new((cx + r * math.cos(t), cy + r * math.sin(t), cz)))
    tip = bm.verts.new((cx + tip_offset[0], cy + tip_offset[1], cz + height))
    bm.faces.new(list(reversed(ring_v)) if height > 0 else ring_v)
    for i in range(sides):
        n = (i + 1) % sides
        if height > 0:
            bm.faces.new((ring_v[i], ring_v[n], tip))
        else:
            bm.faces.new((ring_v[n], ring_v[i], tip))


def blob(bm, centre, radius, subdiv=1, squash=0.6):
    """A low-poly cloud puff: an icosphere, flattened."""
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in res["verts"]:
        v.co.z *= squash
        v.co += Vector(centre)


def canopy(bm, centre, radius, layers=3, rng=None, height=None):
    """A layered tree canopy: stacked, slightly turned discs with ragged edges, like the references'
    trees but our own proportions."""
    cx, cy, cz = centre
    step = (height or radius * 0.55) / layers
    for k in range(layers):
        r = radius * (1.0 - 0.22 * k)
        z = cz + k * step
        sides = 9
        top, bot = [], []
        turn = (rng.uniform(0, 1) if rng else 0) + k * 0.35
        for i in range(sides):
            t = turn + i / sides * math.tau
            rr = r * (1 + (rng.uniform(-0.12, 0.12) if rng else 0))
            droop = rng.uniform(0.3, 0.9) if rng else 0.6
            top.append(bm.verts.new((cx + rr * 0.55 * math.cos(t), cy + rr * 0.55 * math.sin(t), z + step * 0.9)))
            bot.append(bm.verts.new((cx + rr * math.cos(t), cy + rr * math.sin(t), z - droop * step * 0.5)))
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for i in range(sides):
            n = (i + 1) % sides
            bm.faces.new((bot[i], bot[n], top[n], top[i]))


# --- materials ----------------------------------------------------------------------------------
def new_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat, nt, bsdf


def flat_material(name, colour, roughness=0.9, emission=0.0):
    mat, nt, bsdf = new_material(name)
    bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*colour, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for key, value in inputs.items():
        if key.startswith("_"):
            setattr(n, key[1:], value)
        else:
            n.inputs[key].default_value = value
    return n


def ramp(nt, stops):
    """A ColorRamp from [(position, (r, g, b)), ...]."""
    n = nt.nodes.new("ShaderNodeValToRGB")
    cr = n.color_ramp
    while len(cr.elements) > len(stops):
        cr.elements.remove(cr.elements[-1])
    while len(cr.elements) < len(stops):
        cr.elements.new(0.5)
    for el, (pos, col) in zip(cr.elements, stops):
        el.position = pos
        el.color = (*col, 1)
    return n


def coords(nt):
    return nt.nodes.new("ShaderNodeTexCoord")


def separate(nt, vector_socket):
    s = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(vector_socket, s.inputs[0])
    return s


def math_node(nt, op, a=None, b=None, value_a=0.0, value_b=0.0):
    m = nt.nodes.new("ShaderNodeMath")
    m.operation = op
    if a is not None:
        nt.links.new(a, m.inputs[0])
    else:
        m.inputs[0].default_value = value_a
    if b is not None:
        nt.links.new(b, m.inputs[1])
    else:
        m.inputs[1].default_value = value_b
    return m


def mix_colour(nt, factor_socket, a_socket_or_col, b_socket_or_col, blend="MIX"):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    nt.links.new(factor_socket, m.inputs["Factor"])
    for idx, val in ((6, a_socket_or_col), (7, b_socket_or_col)):
        if isinstance(val, tuple):
            m.inputs[idx].default_value = (*val, 1)
        else:
            nt.links.new(val, m.inputs[idx])
    return m


def multiply_colours(nt, a_socket, b_socket):
    """a x b, as a colour (the Mix node's Result is outputs[2])."""
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = "MULTIPLY"
    m.inputs["Factor"].default_value = 1.0
    nt.links.new(a_socket, m.inputs[6])
    nt.links.new(b_socket, m.inputs[7])
    return m


def grain(nt, vector_socket, along="X", scale=2.2, light=(1, 1, 1), dark=(0.8, 0.8, 0.8)):
    """Long wood grain: noise stretched hard along one axis, so it reads as straight streaks."""
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (0.03, 1.0, 1.0) if along == "X" else (1.0, 0.03, 1.0) if along == "Y" else (1.0, 1.0, 0.03)
    nt.links.new(vector_socket, mapping.inputs["Vector"])
    noise = node(nt, "ShaderNodeTexNoise", Scale=scale, Detail=8.0, Roughness=0.6)
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    r = ramp(nt, [(0.35, dark), (0.5, light), (0.65, light), (0.78, dark)])
    nt.links.new(noise.outputs["Fac"], r.inputs["Fac"])
    return r


def cloud_material():
    mat, nt, bsdf = new_material("Cloud")
    bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Emission Color"].default_value = (0.86, 0.92, 1.0, 1)
    bsdf.inputs["Emission Strength"].default_value = 0.35
    return mat


# --- lighting, sky, clouds ---------------------------------------------------------------------
def sky_and_sun(sun_heading_deg=210, sun_elevation_deg=40):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Sky")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = separate(nt, tc.outputs["Generated"])
    r = ramp(nt, [(0.0, SKY_HORIZON), (0.14, SKY_MID), (0.55, SKY_ZENITH)])
    nt.links.new(sep.outputs["Z"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], bg.inputs["Color"])
    # The sky lights the shadows a little, so they stay blue-tinted but keep the local colours.
    bg.inputs["Strength"].default_value = 0.7

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 5.0
    sun_data.color = SUN_COLOUR
    sun_data.angle = math.radians(6)
    sun = bpy.data.objects.new("Sun", sun_data)
    el, hd = math.radians(sun_elevation_deg), math.radians(sun_heading_deg)
    direction = Vector((math.cos(el) * math.cos(hd), math.cos(el) * math.sin(hd), math.sin(el)))
    sun.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    link(sun, "Setup")

    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = -0.25
    try:
        scene.eevee.taa_render_samples = 48
        scene.eevee.use_shadows = True
    except AttributeError:
        pass
    return sun


def cloud_cluster(bm, centre, size, rng, puffs=7, squash=0.55):
    cx, cy, cz = centre
    for _ in range(puffs):
        r = size * rng.uniform(0.35, 0.65)
        off = (rng.uniform(-1, 1) * size * 0.9, rng.uniform(-1, 1) * size * 0.5, rng.uniform(0, 0.35) * size * squash)
        blob(bm, (cx + off[0], cy + off[1], cz + off[2]), r, subdiv=2, squash=squash)


_CLOUD_MAT = None


def cloud_layer(name, z, inner, outer, count, size_range, rng, col="Export", keep_clear=None, per_mesh=8, avoid=None):
    """A ring of clouds between two distances from the centre, split into meshes of `per_mesh` clusters
    (each cluster is about 2,240 triangles, so 8 stay under Roblox's 20,000). `keep_clear` is (a, b) of an
    oval nothing may sit under, so the rim's drop stays open."""
    global _CLOUD_MAT
    if _CLOUD_MAT is None or _CLOUD_MAT.name not in bpy.data.materials:
        _CLOUD_MAT = cloud_material()
    objs = []
    bm = bmesh.new()
    in_mesh = 0
    placed = 0
    tries = 0
    while placed < count and tries < count * 20:
        tries += 1
        d = rng.uniform(inner, outer)
        t = rng.uniform(0, math.tau)
        x, y = d * math.cos(t), d * math.sin(t)
        if keep_clear:
            a, b = keep_clear
            if (x / a) ** 2 + (y / b) ** 2 < 1:
                continue
        if avoid and any(math.hypot(x - ax, y - ay) < ar for ax, ay, ar in avoid):
            continue  # circles (x, y, radius) kept open, so clouds never sit on a sight
        cloud_cluster(bm, (x, y, z + rng.uniform(-8, 8)), rng.uniform(*size_range), rng)
        placed += 1
        in_mesh += 1
        if in_mesh >= per_mesh:
            objs.append(mesh_object(f"{name}_{len(objs) + 1}", bm, _CLOUD_MAT, col, smooth=True))
            bm = bmesh.new()
            in_mesh = 0
    if in_mesh:
        objs.append(mesh_object(f"{name}_{len(objs) + 1}", bm, _CLOUD_MAT, col, smooth=True))
    else:
        bm.free()
    return objs


# --- cameras and renders -----------------------------------------------------------------------
def camera(name, location, target, lens=28):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.clip_end = 20000
    data.clip_start = 0.5
    cam = bpy.data.objects.new(name, data)
    cam.location = location
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    link(cam, "Setup")
    return cam


def standard_cameras(gameplay_target=(40, 8, -4), edge_target=None, overview_from=(300, -390, 95)):
    """Gameplay (behind a fighter on the surface), Edge (over the rim at the backdrop), Recovery (just
    below the rim, looking back up at the lip, as a launched player sees it) and Overview."""
    cams = {
        "Gameplay": camera("Gameplay", (-72, -18, 16), gameplay_target, 26),
        "Edge": camera("Edge", (A - 30, -20, 11), edge_target or (A + 200, 40, -40), 26),
        "Recovery": camera("Recovery", (A + 38, -24, -14), (A - 8, 0, 1), 24),
        "Overview": camera("Overview", overview_from, (0, 0, -28), 30),
        # Floor: a fighter's eye height, a few steps from the rim, looking at floor, rim and drop.
        "Floor": camera("Floor", (44, -36, 6), (80, -67, -2), 26),
    }
    # Look-around views from the middle of the arena at eye height, for judging the backdrop: what
    # shows above the rim in each direction, and how much clear sky an airborne fighter has behind them.
    for name, (dx, dy) in {"LookE": (1, 0), "LookN": (0, 1), "LookW": (-1, 0), "LookS": (0, -1)}.items():
        cams[name] = camera(name, (0, 0, 7), (dx * 300, dy * 300, 22), 20)
    return cams


def render_all(out_dir, prefix, cams, resolution=(1280, 720)):
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.image_settings.file_format = "PNG"
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    for name, cam in cams.items():
        scene.camera = cam
        scene.render.filepath = os.path.join(out_dir, f"{prefix}_{name.lower()}.png")
        bpy.ops.render.render(write_still=True)
        paths.append(scene.render.filepath)
    return paths


# --- checks --------------------------------------------------------------------------------------
def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def check_export():
    """Every mesh in Export: under 20,000 triangles and one material. Returns a report."""
    report = []
    bad = []
    for obj in collection("Export").objects:
        if obj.type != "MESH":
            continue
        tris = triangles(obj)
        mats = len(obj.data.materials)
        report.append((obj.name, tris, mats))
        if tris > 20000 or mats != 1:
            bad.append(obj.name)
    return report, bad


def surface_is_flat(obj, tolerance=0.06):
    """The fighting surface's top faces must all sit at z = 0 (within the rim's paint offset)."""
    zs = [v.co.z for v in obj.data.vertices if v.co.z > -0.5]
    return max(zs) - min(zs) <= tolerance if zs else False
