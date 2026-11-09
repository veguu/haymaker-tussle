"""Saltcrest: a glazed tile plaza with terracotta eaves, high above a winding coastline and harbour.

Run: blender -b --factory-startup -P saltcrest.py -- <out folder> [--no-render]
Backdrop: a landscape far below (800 studs): sea, hills, a road, a harbour village and a lighthouse.
Signature material: glazed ceramic tile (sea-green, white, sun-baked orange) laid in a compass rose that
follows whole tiles, and matte terracotta, in tile and brick.

The eaves overhang the drop below the surface. They're visual only: in Roblox they must be
CanCollide = false, so nobody can stand on them (see EXPORT notes).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

TILE = 5.0
SEA_GREEN = (0.16, 0.58, 0.52)
GLAZE_WHITE = (0.86, 0.85, 0.79)
ORANGE = (0.90, 0.48, 0.18)
TERRACOTTA = (0.78, 0.36, 0.17)
GROUND = -700.0


def tile_material():
    """The plaza: whole tiles, each one colour, laid as a compass rose. The pattern is worked out at each
    tile's centre so it follows the tiles like a real mosaic; grout lines between; a little variation
    tile to tile; a soft glaze."""
    mat, nt, bsdf = C.new_material("Saltcrest_Tiles")
    tc = C.coords(nt)
    sep = C.separate(nt, tc.outputs["Object"])
    # tile centre
    def snap(axis):
        d = C.math_node(nt, "DIVIDE", sep.outputs[axis], value_b=TILE)
        f = C.math_node(nt, "FLOOR", d.outputs[0])
        c = C.math_node(nt, "ADD", f.outputs[0], value_b=0.5)
        return C.math_node(nt, "MULTIPLY", c.outputs[0], value_b=TILE), d
    sx, dx = snap("X")
    sy, dy = snap("Y")
    # elliptical radius 0..1 at the tile centre
    nx = C.math_node(nt, "DIVIDE", sx.outputs[0], value_b=C.A)
    ny = C.math_node(nt, "DIVIDE", sy.outputs[0], value_b=C.B)
    nx2 = C.math_node(nt, "MULTIPLY", nx.outputs[0], nx.outputs[0])
    ny2 = C.math_node(nt, "MULTIPLY", ny.outputs[0], ny.outputs[0])
    rr = C.math_node(nt, "SQRT", C.math_node(nt, "ADD", nx2.outputs[0], ny2.outputs[0]).outputs[0])
    # angle
    ang = C.math_node(nt, "ARCTAN2", ny.outputs[0], nx.outputs[0])
    # Compass rose: four long rays on the axes, four shorter diagonals, an orange heart, and a
    # sea-green band near the rim. Rays are narrow because |cos|^14 falls away fast off each axis.
    two = C.math_node(nt, "MULTIPLY", ang.outputs[0], value_b=2.0)
    c2 = C.math_node(nt, "ABSOLUTE", C.math_node(nt, "COSINE", two.outputs[0]).outputs[0])
    s2 = C.math_node(nt, "ABSOLUTE", C.math_node(nt, "SINE", two.outputs[0]).outputs[0])
    main_reach = C.math_node(nt, "MULTIPLY_ADD", C.math_node(nt, "POWER", c2.outputs[0], value_b=14.0).outputs[0])
    main_reach.inputs[1].default_value = 0.72
    main_reach.inputs[2].default_value = 0.1
    diag_reach = C.math_node(nt, "MULTIPLY_ADD", C.math_node(nt, "POWER", s2.outputs[0], value_b=14.0).outputs[0])
    diag_reach.inputs[1].default_value = 0.42
    diag_reach.inputs[2].default_value = 0.1
    in_main = C.math_node(nt, "LESS_THAN", rr.outputs[0], main_reach.outputs[0])
    in_diag = C.math_node(nt, "LESS_THAN", rr.outputs[0], diag_reach.outputs[0])
    field = C.ramp(nt, [(0.0, ORANGE), (0.1, GLAZE_WHITE), (0.86, SEA_GREEN), (0.9, GLAZE_WHITE)])
    field.color_ramp.interpolation = "CONSTANT"
    nt.links.new(rr.outputs[0], field.inputs["Fac"])
    centre = C.math_node(nt, "LESS_THAN", rr.outputs[0], value_b=0.1)
    not_centre = C.math_node(nt, "SUBTRACT", None, centre.outputs[0], value_a=1.0)
    diag_here = C.math_node(nt, "MULTIPLY", in_diag.outputs[0], not_centre.outputs[0])
    main_here = C.math_node(nt, "MULTIPLY", in_main.outputs[0], not_centre.outputs[0])
    with_diag = C.mix_colour(nt, diag_here.outputs[0], field.outputs["Color"], ORANGE)
    base = C.mix_colour(nt, main_here.outputs[0], with_diag.outputs[2], SEA_GREEN)
    # per-tile variation
    tid = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sx.outputs[0], tid.inputs[0])
    nt.links.new(sy.outputs[0], tid.inputs[1])
    wn = nt.nodes.new("ShaderNodeTexWhiteNoise")
    wn.noise_dimensions = "3D"
    nt.links.new(tid.outputs[0], wn.inputs["Vector"])
    vary = C.ramp(nt, [(0.0, (0.9, 0.9, 0.9)), (1.0, (1.03, 1.03, 1.03))])
    nt.links.new(wn.outputs["Value"], vary.inputs["Fac"])
    varied = C.multiply_colours(nt, base.outputs[2], vary.outputs["Color"])
    # grout
    fx = C.math_node(nt, "FRACT", dx.outputs[0])
    fy = C.math_node(nt, "FRACT", dy.outputs[0])
    gx = C.ramp(nt, [(0.0, (0, 0, 0)), (0.035, (1, 1, 1)), (0.965, (1, 1, 1)), (1.0, (0, 0, 0))])
    gy = C.ramp(nt, [(0.0, (0, 0, 0)), (0.035, (1, 1, 1)), (0.965, (1, 1, 1)), (1.0, (0, 0, 0))])
    nt.links.new(fx.outputs[0], gx.inputs["Fac"])
    nt.links.new(fy.outputs[0], gy.inputs["Fac"])
    gm = C.math_node(nt, "MULTIPLY", gx.outputs["Color"], gy.outputs["Color"])
    final = C.mix_colour(nt, gm.outputs[0], (0.72, 0.68, 0.60), varied.outputs[2])
    nt.links.new(final.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Specular IOR Level"].default_value = 0.3
    return mat


def terracotta_material(name, base=TERRACOTTA):
    mat, nt, bsdf = C.new_material(name)
    tc = C.coords(nt)
    blot = C.node(nt, "ShaderNodeTexNoise", Scale=0.25, Detail=3.0)
    nt.links.new(tc.outputs["Object"], blot.inputs["Vector"])
    r = C.ramp(nt, [(0.3, tuple(c * 0.85 for c in base)), (0.5, base), (0.7, tuple(min(c * 1.08, 1) for c in base))])
    nt.links.new(blot.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


def brick_material():
    """Running-bond brick round the sides: courses by height, bricks by distance round the oval."""
    mat, nt, bsdf = C.new_material("Saltcrest_Brick")
    tc = C.coords(nt)
    sep = C.separate(nt, tc.outputs["Object"])
    course = C.math_node(nt, "DIVIDE", sep.outputs["Z"], value_b=1.6)
    row = C.math_node(nt, "FLOOR", course.outputs[0])
    rowf = C.math_node(nt, "FRACT", course.outputs[0])
    ang = C.math_node(nt, "ARCTAN2", sep.outputs["Y"], sep.outputs["X"])
    around = C.math_node(nt, "MULTIPLY", ang.outputs[0], value_b=95.0 / 3.6)
    shift = C.math_node(nt, "MULTIPLY", row.outputs[0], value_b=0.5)
    along = C.math_node(nt, "ADD", around.outputs[0], shift.outputs[0])
    brick = C.math_node(nt, "FLOOR", along.outputs[0])
    alongf = C.math_node(nt, "FRACT", along.outputs[0])
    mx = C.ramp(nt, [(0.0, (0, 0, 0)), (0.04, (1, 1, 1)), (0.96, (1, 1, 1)), (1.0, (0, 0, 0))])
    my = C.ramp(nt, [(0.0, (0, 0, 0)), (0.08, (1, 1, 1)), (0.92, (1, 1, 1)), (1.0, (0, 0, 0))])
    nt.links.new(alongf.outputs[0], mx.inputs["Fac"])
    nt.links.new(rowf.outputs[0], my.inputs["Fac"])
    mortar = C.math_node(nt, "MULTIPLY", mx.outputs["Color"], my.outputs["Color"])
    idv = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(brick.outputs[0], idv.inputs[0])
    nt.links.new(row.outputs[0], idv.inputs[1])
    wn = nt.nodes.new("ShaderNodeTexWhiteNoise")
    wn.noise_dimensions = "3D"
    nt.links.new(idv.outputs[0], wn.inputs["Vector"])
    shade = C.ramp(nt, [(0.0, (0.62, 0.27, 0.14)), (0.5, (0.76, 0.36, 0.18)), (1.0, (0.84, 0.48, 0.26))])
    nt.links.new(wn.outputs["Value"], shade.inputs["Fac"])
    final = C.mix_colour(nt, mortar.outputs[0], (0.86, 0.80, 0.68), shade.outputs["Color"])
    nt.links.new(final.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


def build_plaza():
    bm = bmesh.new()
    C.oval_prism(bm, C.A - C.RIM, C.B - C.RIM, 0.0, -3.0)
    C.mesh_object("Plaza_Tiles", bm, tile_material())
    bm = bmesh.new()
    C.ring(bm, C.A, C.B, C.A - C.RIM, C.B - C.RIM, 0.0, -3.0)
    C.mesh_object("Rim_Terracotta", bm, terracotta_material("Saltcrest_RimTerracotta", ORANGE))


def barrel_tile(bm, origin, outward, along, length, radius, droop_deg=15, sides=6):
    """One curved roof tile: a half-tube lying outward from the rim, tipped down like eaves."""
    o = Vector(origin)
    out = Vector((outward[0], outward[1], 0)).normalized()
    side = Vector((along[0], along[1], 0)).normalized()
    droop = math.radians(droop_deg)
    axis = (out * math.cos(droop) - Vector((0, 0, 1)) * math.sin(droop)).normalized()
    up = axis.cross(side).normalized()
    if up.z < 0:
        up = -up
    thickness = 0.35
    rings = []
    for end in (0.0, length):
        outer, inner = [], []
        for i in range(sides + 1):
            t = math.pi * i / sides
            dirv = side * math.cos(t) + up * math.sin(t)
            outer.append(bm.verts.new(o + axis * end + dirv * radius))
            inner.append(bm.verts.new(o + axis * end + dirv * (radius - thickness)))
        rings.append((outer, inner))
    (o0, i0), (o1, i1) = rings
    for i in range(sides):
        bm.faces.new((o0[i], o0[i + 1], o1[i + 1], o1[i]))
        bm.faces.new((i0[i + 1], i0[i], i1[i], i1[i + 1]))
    for (outer, inner) in rings:
        pass
    for i in range(sides):
        bm.faces.new((i0[i], o0[i], o0[i + 1], i0[i + 1]))
        bm.faces.new((o1[i], i1[i], i1[i + 1], o1[i + 1]))
    bm.faces.new((o0[0], i0[0], i1[0], o1[0]))
    bm.faces.new((i0[sides], o0[sides], o1[sides], i1[sides]))


def build_eaves():
    bm = bmesh.new()
    # walk round the oval in equal steps of about 3.4 studs
    steps = 1600
    pts = [C.oval_xy(i / steps * math.tau) for i in range(steps)]
    acc, last = 0.0, pts[0]
    placed = [pts[0]]
    for p in pts[1:]:
        acc += math.dist(p, last)
        last = p
        if acc >= 3.4:
            placed.append(p)
            acc = 0.0
    for (x, y) in placed:
        t = math.atan2(y / C.B, x / C.A)
        nx, ny = math.cos(t) / C.A, math.sin(t) / C.B  # outward normal of the ellipse
        n = math.hypot(nx, ny)
        nx, ny = nx / n, ny / n
        barrel_tile(bm, (x - nx * 0.6, y - ny * 0.6, -2.1), (nx, ny), (-ny, nx), 5.5, 1.8)
    return C.mesh_object("Eaves_RoofTiles", bm, terracotta_material("Saltcrest_RoofTile"))


def build_underside(rng):
    """Brick courses stepping in like stacked plates, each with a sea-green glazed lip; copper pipes down
    the sides; a few hanging planters."""
    bricks, lips = bmesh.new(), bmesh.new()
    scales = [0.985, 0.9, 0.79, 0.66, 0.52, 0.37, 0.22]
    z = -3.0
    for k, s in enumerate(scales):
        h = 9.0 if k < 3 else 8.0
        C.oval_prism(bricks, C.A * s, C.B * s, z, z - h, segments=64)
        if 0 < k:
            C.ring(lips, C.A * s + 0.9, C.B * s + 0.9, C.A * s - 0.5, C.B * s - 0.5, z + 0.01, z - 1.2, segments=64)
        z -= h
    C.cone(bricks, (0, 0, z), C.B * 0.14, -26, sides=10)
    C.mesh_object("Underside_Brick", bricks, brick_material())
    C.mesh_object("Underside_TileLips", lips, C.flat_material("Saltcrest_GlazeLip", SEA_GREEN, 0.4))

    pipes = bmesh.new()
    for i in range(7):
        t = i / 7 * math.tau + 0.3
        x0, y0 = C.oval_xy(t, C.A * 0.975, C.B * 0.975)
        x1, y1 = C.oval_xy(t, C.A * 0.6, C.B * 0.6)
        C.cylinder(pipes, (x0, y0, -3.5), (x0 * 0.99, y0 * 0.99, -20), 0.9, 8)
        C.cylinder(pipes, (x0 * 0.99, y0 * 0.99, -20), (x1, y1, -32), 0.9, 8)
        C.cylinder(pipes, (x1, y1, -32), (x1, y1, -44), 0.9, 8)
    C.mesh_object("Underside_CopperPipes", pipes, C.flat_material("Saltcrest_Copper", (0.33, 0.62, 0.52), 0.6))

    planters, bushes = bmesh.new(), bmesh.new()
    for i in range(6):
        t = i / 6 * math.tau + 0.8
        x, y = C.oval_xy(t, C.A * 0.9, C.B * 0.9)
        C.box(planters, (x, y, -16), (6, 4, 3.5), rot_z=t)
        C.blob(bushes, (x, y, -13.5), 3.4, subdiv=1, squash=0.8)
    C.mesh_object("Underside_Planters", planters, terracotta_material("Saltcrest_Planter"))
    C.mesh_object("Underside_PlanterBushes", bushes, C.flat_material("Saltcrest_Bush", (0.26, 0.56, 0.22)))


def coast_x(y):
    """The coastline: x of the shore for a given y, a winding curve with a harbour bay."""
    return (
        -760
        + 90 * math.sin(y / 260.0)
        + 45 * math.sin(y / 95.0 + 1.3)
        + (-130 * math.exp(-((y - 140) / 120.0) ** 2))  # the harbour bay
    )


def land_height(x, y, rng_noise):
    shore = coast_x(y)
    inland = shore - x  # positive on land (land is toward -X)
    if inland < 0:
        return GROUND - 6 + max(inland, -40) * 0.05
    rise = min(inland / 6.0, 4) + max(inland - 80, 0) * 0.07
    hills = 30 * (math.sin(x / 150.0) * math.cos(y / 170.0) + 1) + 20 * math.sin(x / 61.0 + y / 83.0)
    # far inland the hills build into a range of soft mountains along the horizon
    mountains = max(inland - 900, 0) / 1600.0
    peaks = 260 * mountains * (1.2 + math.sin(y / 230.0) * math.cos(x / 310.0))
    return GROUND + rise + max(hills, 0) * min(max(inland - 40, 0) / 150.0, 1.0) + max(peaks, 0)


def land_material():
    mat, nt, bsdf = C.new_material("Saltcrest_Land")
    tc = C.coords(nt)
    sep = C.separate(nt, tc.outputs["Object"])
    h = C.math_node(nt, "SUBTRACT", sep.outputs["Z"], value_b=GROUND)
    r = C.ramp(
        nt,
        [(0.0, (0.93, 0.85, 0.62)), (0.012, (0.93, 0.85, 0.62)), (0.02, (0.48, 0.72, 0.30)), (0.15, (0.34, 0.60, 0.24)), (0.45, (0.26, 0.50, 0.24)), (0.75, (0.40, 0.52, 0.36)), (0.95, (0.62, 0.66, 0.58))],
    )
    norm = C.math_node(nt, "DIVIDE", h.outputs[0], value_b=500.0)
    nt.links.new(norm.outputs[0], r.inputs["Fac"])
    fields = C.node(nt, "ShaderNodeTexVoronoi", Scale=0.012)
    nt.links.new(tc.outputs["Object"], fields.inputs["Vector"])
    fs = C.separate(nt, fields.outputs["Color"])
    patch = C.ramp(nt, [(0.0, (0.92, 0.92, 0.92)), (0.5, (1, 1, 1)), (1.0, (1.06, 1.04, 0.92))])
    nt.links.new(fs.outputs["X"], patch.inputs["Fac"])
    out = C.multiply_colours(nt, r.outputs["Color"], patch.outputs["Color"])
    nt.links.new(out.outputs[2], bsdf.inputs["Base Color"])
    return mat


def build_landscape(rng):
    # sea: a big flat disc, lighter in the shallows near the shore
    sea = bmesh.new()
    C.oval_prism(sea, 3200, 3200, GROUND - 4, GROUND - 6, segments=64)
    sea_mat = C.new_material("Saltcrest_Sea")
    mat, nt, bsdf = sea_mat
    tc = C.coords(nt)
    sep = C.separate(nt, tc.outputs["Object"])
    shallow = C.ramp(nt, [(0.0, (0.18, 0.62, 0.66)), (0.4, (0.10, 0.45, 0.62)), (1.0, (0.06, 0.32, 0.56))])
    xs = C.math_node(nt, "ADD", sep.outputs["X"], value_b=760.0)
    xn = C.math_node(nt, "DIVIDE", xs.outputs[0], value_b=900.0)
    nt.links.new(xn.outputs[0], shallow.inputs["Fac"])
    nt.links.new(shallow.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.4
    C.mesh_object("Below_Sea", sea, mat)

    # land: a grid shaped by the coastline and hills, only on the shore side
    land = bmesh.new()
    n = 80
    x0, x1, y0, y1 = -3400.0, -500.0, -2200.0, 2200.0
    grid = []
    for j in range(n + 1):
        row = []
        y = y0 + (y1 - y0) * j / n
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            row.append(land.verts.new((x, y, land_height(x, y, rng))))
        grid.append(row)
    for j in range(n):
        for i in range(n):
            land.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    C.mesh_object("Below_Land", land, land_material(), smooth=True)

    # harbour village on the bay, white walls and orange roofs, plus a road winding inland
    walls, roofs, road = bmesh.new(), bmesh.new(), bmesh.new()
    houses = 0
    while houses < 46:
        y = rng.uniform(10, 290)
        x = coast_x(y) - rng.uniform(25, 210)
        z = land_height(x, y, rng)
        if z < GROUND + 2:
            continue
        w, d, h = rng.uniform(24, 36), rng.uniform(18, 28), rng.uniform(14, 24)
        rot = rng.uniform(-0.3, 0.3)
        C.box(walls, (x, y, z + h / 2), (w, d, h), rot_z=rot)
        # a pitched roof: a stretched cone with 4 sides reads as a hip roof from above
        C.cone(roofs, (x, y, z + h), max(w, d) * 0.72, h * 0.6, sides=4, tip_offset=(0, 0))
        houses += 1
    px, py = coast_x(150) - 30, 150.0
    for k in range(60):
        nx = px - 22
        ny = py + 40 * math.sin(k / 6.0)
        z = land_height(nx, ny, rng)
        C.box(road, ((px + nx) / 2, (py + ny) / 2, z + 0.8), (math.hypot(nx - px, ny - py) + 4, 9, 1.2), rot_z=math.atan2(ny - py, nx - px))
        px, py = nx, ny
    C.mesh_object("Below_Village_Walls", walls, C.flat_material("Saltcrest_Whitewash", (0.96, 0.95, 0.90)))
    C.mesh_object("Below_Village_Roofs", roofs, terracotta_material("Saltcrest_VillageRoofs", ORANGE))
    C.mesh_object("Below_Road", road, C.flat_material("Saltcrest_Road", (0.88, 0.80, 0.62)))

    # the lighthouse on its headland, banded red and white
    hx, hy = coast_x(-260) - 18, -260.0
    hz = land_height(hx, hy, rng)
    red, white = bmesh.new(), bmesh.new()
    for k in range(6):
        z0 = hz + k * 16
        C.cylinder(red if k % 2 == 0 else white, (hx, hy, z0), (hx, hy, z0 + 16), 11 - k * 0.8, 12)
    C.cylinder(white, (hx, hy, hz + 96), (hx, hy, hz + 106), 7, 12)
    C.cone(red, (hx, hy, hz + 106), 8.5, 10, sides=12)
    C.mesh_object("Below_Lighthouse_Red", red, C.flat_material("Saltcrest_LighthouseRed", (0.84, 0.20, 0.16)))
    C.mesh_object("Below_Lighthouse_White", white, C.flat_material("Saltcrest_LighthouseWhite", (0.97, 0.96, 0.92)))

    # sailboats in and around the bay
    hulls, sails = bmesh.new(), bmesh.new()
    for k in range(9):
        y = rng.uniform(-200, 420)
        x = coast_x(y) + rng.uniform(60, 420)
        rot = rng.uniform(0, math.tau)
        C.box(hulls, (x, y, GROUND - 2), (22, 8, 4), rot_z=rot)
        C.cone(sails, (x, y, GROUND), 7, 26, sides=3, tip_offset=(0, 0))
    C.mesh_object("Below_Boat_Hulls", hulls, C.flat_material("Saltcrest_Hull", (0.55, 0.32, 0.18)))
    C.mesh_object("Below_Boat_Sails", sails, C.flat_material("Saltcrest_Sail", (0.98, 0.97, 0.93)))


def build_clouds(rng):
    clear = (C.A + 60, C.B + 60)
    # sparse and well out, so the view down to the coast stays open
    C.cloud_layer("Clouds_Low", -360, 300, 1600, 14, (50, 90), rng, keep_clear=(1100, 900))
    C.cloud_layer("Clouds_Near", -120, 220, 700, 10, (28, 44), rng, keep_clear=clear)
    C.cloud_layer("Clouds_Horizon", 40, 1300, 1900, 14, (110, 190), rng)


def build():
    rng = random.Random(23)
    C.reset()
    C.sky_and_sun(sun_heading_deg=205, sun_elevation_deg=42)
    build_plaza()
    build_eaves()
    build_underside(rng)
    build_landscape(rng)
    build_clouds(rng)
    cams = C.standard_cameras(gameplay_target=(-60, 8, -4), edge_target=(-380, 120, -800))
    # The gameplay view faces the coast side here, so the village shows past the rim.
    cams["Gameplay"].location = (70, 18, 16)
    d = Vector((-60, 8, -4)) - cams["Gameplay"].location
    cams["Gameplay"].rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    edge = cams["Edge"]
    edge.location = (-C.A + 14, 10, 16)
    d = Vector((-900, 150, -620)) - edge.location
    edge.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    rec = cams["Recovery"]
    rec.location = (-C.A - 38, 24, -14)
    d = Vector((-C.A + 8, 0, 1)) - rec.location
    rec.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    ov = cams["Overview"]
    ov.location = (420, -380, 140)
    d = Vector((-420, 80, -330)) - ov.location
    ov.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return cams


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "saltcrest")
    cams = build()
    report, bad = C.check_export()
    for name, tris, mats in report:
        print(f"MESH {name}: {tris} tris, {mats} material(s)")
    print("OVER LIMIT:", bad)
    print("FLAT:", C.surface_is_flat(bpy.data.objects["Plaza_Tiles"]), C.surface_is_flat(bpy.data.objects["Rim_Terracotta"]))
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "saltcrest.blend"))
    if "--no-render" not in args:
        for p in C.render_all(out, "saltcrest", cams):
            print("RENDER", p)
