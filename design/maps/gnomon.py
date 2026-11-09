"""Gnomon Isle: a clover meadow on fractured pale-stone strata, among distant floating islands, one of
them a giant sundial whose blade rises over the skyline.

Run: blender -b --factory-startup -P gnomon.py -- <out folder> [--no-render]
Backdrop: distant floating islands with a recognisable landmark. Signature material: layered pale stone,
cream / sand / blue-grey bands with sharp cracks, broken into broad facets.

Readability rules kept here: the strata never reach outside the oval (no ledges to land on), the rim is
a flush cream band against the green, and no island within 200 studs rises more than 20 above the deck.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

CREAM = (0.93, 0.85, 0.66)
SAND = (0.84, 0.66, 0.42)
BLUEGREY = (0.58, 0.66, 0.77)
GRASS = (0.30, 0.60, 0.20)


def stone_material(name, base, crack=0.55):
    """Pale stone: a soft painted variation, broad darker patches, and thin sharp crack lines."""
    mat, nt, bsdf = C.new_material(name)
    tc = C.coords(nt)
    patches = C.node(nt, "ShaderNodeTexNoise", Scale=0.05, Detail=3.0)
    nt.links.new(tc.outputs["Object"], patches.inputs["Vector"])
    shade = C.ramp(
        nt,
        [(0.3, tuple(c * 0.88 for c in base)), (0.55, base), (0.75, tuple(min(c * 1.05, 1) for c in base))],
    )
    nt.links.new(patches.outputs["Fac"], shade.inputs["Fac"])
    # Cracks: Voronoi cell edges, pushed around by noise so they wander like real fractures.
    warp = C.node(nt, "ShaderNodeTexNoise", Scale=0.05, Detail=2.0)
    nt.links.new(tc.outputs["Object"], warp.inputs["Vector"])
    push = nt.nodes.new("ShaderNodeVectorMath")
    push.operation = "MULTIPLY_ADD"
    nt.links.new(warp.outputs["Color"], push.inputs[0])
    push.inputs[1].default_value = (18.0, 18.0, 18.0)
    nt.links.new(tc.outputs["Object"], push.inputs[2])
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 0.035
    nt.links.new(push.outputs["Vector"], vor.inputs["Vector"])
    soft = min(crack + 0.18, 0.9)
    cracks = C.ramp(nt, [(0.0, (soft, soft, soft)), (0.012, (1, 1, 1))])
    nt.links.new(vor.outputs["Distance"], cracks.inputs["Fac"])
    out = C.multiply_colours(nt, shade.outputs["Color"], cracks.outputs["Color"])
    nt.links.new(out.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


def grass_material():
    """A meadow: two painted greens in broad soft patches, and a light sprinkle of clover and flowers.
    Kept low in contrast so the surface stays calm to fight on."""
    mat, nt, bsdf = C.new_material("Gnomon_Grass")
    tc = C.coords(nt)
    patches = C.node(nt, "ShaderNodeTexNoise", Scale=0.035, Detail=2.0)
    nt.links.new(tc.outputs["Object"], patches.inputs["Vector"])
    greens = C.ramp(nt, [(0.35, (0.24, 0.52, 0.17)), (0.6, GRASS), (0.8, (0.40, 0.68, 0.24))])
    nt.links.new(patches.outputs["Fac"], greens.inputs["Fac"])
    dots = nt.nodes.new("ShaderNodeTexVoronoi")
    dots.inputs["Scale"].default_value = 0.6
    nt.links.new(tc.outputs["Object"], dots.inputs["Vector"])
    speck = C.ramp(nt, [(0.0, (1, 1, 1)), (0.06, (1, 1, 1)), (0.07, (0, 0, 0))])
    nt.links.new(dots.outputs["Distance"], speck.inputs["Fac"])
    flower = C.ramp(nt, [(0.0, (0.97, 0.95, 0.88)), (0.85, (0.97, 0.95, 0.88)), (0.86, (0.95, 0.62, 0.70))])
    flower.color_ramp.interpolation = "CONSTANT"
    sep = C.separate(nt, dots.outputs["Color"])
    nt.links.new(sep.outputs["X"], flower.inputs["Fac"])
    keep = C.math_node(nt, "MULTIPLY", speck.outputs["Color"], value_b=0.65)
    out = C.mix_colour(nt, keep.outputs[0], greens.outputs["Color"], flower.outputs["Color"])
    nt.links.new(out.outputs[2], bsdf.inputs["Base Color"])
    return mat


def rotate_bm(bm, angle, about=(0, 0)):
    rot = Matrix.Rotation(angle, 4, "Z")
    for v in bm.verts:
        v.co = rot @ (v.co - Vector((about[0], about[1], 0))) + Vector((about[0], about[1], 0))


def facet_slab(bm_target, a, b, z_top, thickness, taper, rng, turn, segments=20, exact_top=False):
    """One stratum: an oval slab with a few broad facets, its outline only ever pulled inward, so it
    never sticks out past the rim above it. `exact_top` keeps the top ring on the oval itself, for the
    slab right under the meadow, so no underside shows between them."""
    bm = bmesh.new()
    top, bottom = [], []
    if exact_top:
        segments = C.SEGMENTS
        turn = 0.0
    for i in range(segments):
        t = i / segments * math.tau
        x, y = C.oval_xy(t, a, b)
        j = 1.0 if exact_top else rng.uniform(0.9, 1.0)
        top.append(bm.verts.new((x * j, y * j, z_top)))
        jb = rng.uniform(0.88, 1.0) * taper
        bottom.append(bm.verts.new((x * jb, y * jb, z_top - thickness * rng.uniform(0.85, 1.15))))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bottom)))
    for i in range(segments):
        n = (i + 1) % segments
        bm.faces.new((top[i], bottom[i], bottom[n], top[n]))
    rotate_bm(bm, turn)
    me = bpy.data.meshes.new("tmp")
    bm.to_mesh(me)
    bm.free()
    bm_target.from_mesh(me)
    bpy.data.meshes.remove(me)


def build_main(rng):
    bm = bmesh.new()
    C.oval_prism(bm, C.A - C.RIM, C.B - C.RIM, 0.0, -2.0)
    C.mesh_object("Meadow", bm, grass_material())
    bm = bmesh.new()
    C.ring(bm, C.A, C.B, C.A - C.RIM, C.B - C.RIM, 0.0, -2.0)
    C.mesh_object("Rim_Stone", bm, stone_material("Gnomon_RimStone", (0.96, 0.90, 0.74), 0.7))

    bands = {"Cream": bmesh.new(), "Sand": bmesh.new(), "BlueGrey": bmesh.new()}
    order = ["Cream", "Sand", "BlueGrey", "Cream", "Sand", "BlueGrey"]
    z = -2.0
    scale = 0.995
    for k, band in enumerate(order):
        thick = rng.uniform(11, 16)
        taper = 0.9
        if k == 0:
            facet_slab(bands[band], C.A, C.B, z, thick, taper, rng, 0.0, exact_top=True)
        else:
            facet_slab(bands[band], C.A * scale, C.B * scale, z, thick, taper, rng, rng.uniform(-0.05, 0.05))
        z -= thick * 0.95
        scale *= rng.uniform(0.84, 0.9)
    # Rock fingers hanging below, pointed and faceted.
    fingers = bands["BlueGrey"]
    for fx, fy, r, h in ((-18, 6, 22, 55), (20, -10, 17, 42), (2, 22, 12, 30)):
        C.cone(fingers, (fx, fy, z + 2), r, -h, sides=6, rng=rng, jitter=0.15, tip_offset=(rng.uniform(-6, 6), rng.uniform(-6, 6)))
    colours = {"Cream": CREAM, "Sand": SAND, "BlueGrey": BLUEGREY}
    for name, bm in bands.items():
        C.mesh_object(f"Strata_{name}", bm, stone_material(f"Gnomon_{name}", colours[name]))



def tree(trunks, canopies, at, height, radius, rng):
    x, y, z = at
    C.cylinder(trunks, (x, y, z), (x + rng.uniform(-2, 2), y + rng.uniform(-2, 2), z + height), radius * 0.12, 6)
    C.canopy(canopies, (x, y, z + height * 0.85), radius, layers=3, rng=rng)


def floating_island(bms, centre, radius, rng, trees=3):
    """A small island: a grass cap on a faceted stone cone, with a few layered trees."""
    cx, cy, cz = centre
    grass, stone, trunks, canopies = bms
    C.oval_prism(grass, radius, radius * rng.uniform(0.75, 0.95), cz, cz - 2.5, segments=14, jitter=0.08, rng=rng)
    depth = radius * rng.uniform(1.3, 1.9)
    slab = bmesh.new()
    C.oval_prism(slab, radius * 0.98, radius * 0.8, cz - 2.5, cz - depth, segments=10, jitter=0.12, rng=rng, taper=0.18)
    for v in slab.verts:
        v.co.x += cx
        v.co.y += cy
    me = bpy.data.meshes.new("tmp")
    slab.to_mesh(me)
    slab.free()
    stone.from_mesh(me)
    bpy.data.meshes.remove(me)
    # move the grass cap we just made into place (its last 28 verts)
    for v in list(grass.verts)[-28:]:
        v.co.x += cx
        v.co.y += cy
    for _ in range(trees):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0, radius * 0.55)
        tree(trunks, canopies, (cx + d * math.cos(a), cy + d * math.sin(a), cz - 1), rng.uniform(16, 28), rng.uniform(9, 14), rng)


def build_islands(rng):
    bms = (bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new())
    spots = [
        (205, 150, -38, 30),
        (-230, 120, -22, 38),
        (-260, -150, 6, 44),
        (60, -300, -12, 34),
        (-90, 330, 14, 40),
        (330, -190, -30, 28),
        (-420, 40, 20, 52),
    ]
    for x, y, z, r in spots:
        dist = math.hypot(x, y)
        if dist < 200:
            z = min(z, -10)  # trees here stay under 20 studs above the deck
        floating_island(bms, (x, y, z), r, rng, trees=2 + int(r > 35))
    grass, stone, trunks, canopies = bms
    C.mesh_object("Islands_Grass", grass, grass_material())
    C.mesh_object("Islands_Stone", stone, stone_material("Gnomon_IslandStone", (0.80, 0.74, 0.62)))
    C.mesh_object("Trees_Trunks", trunks, C.flat_material("Gnomon_Trunk", (0.42, 0.27, 0.16)))
    canopy_mat = C.flat_material("Gnomon_Canopy", (0.26, 0.58, 0.24))
    C.mesh_object("Trees_Canopies", canopies, canopy_mat)


def build_sundial(rng):
    """The landmark: a big island on the long axis carrying a sundial, its blade rising far above the
    skyline. Out at 380 studs so it marks one end of the arena from anywhere on it."""
    cx, cy, cz = 380.0, 30.0, -25.0
    grass, stone = bmesh.new(), bmesh.new()
    C.oval_prism(grass, 70, 62, cz, cz - 3, segments=20, jitter=0.04, rng=rng)
    for v in grass.verts:
        v.co.x += cx
        v.co.y += cy
    body = bmesh.new()
    C.oval_prism(body, 69, 60, cz - 3, cz - 120, segments=12, jitter=0.1, rng=rng, taper=0.15)
    for v in body.verts:
        v.co.x += cx
        v.co.y += cy
    me = bpy.data.meshes.new("tmp")
    body.to_mesh(me)
    body.free()
    stone.from_mesh(me)
    bpy.data.meshes.remove(me)
    C.mesh_object("Sundial_Island_Grass", grass, grass_material())
    C.mesh_object("Sundial_Island_Stone", stone, stone_material("Gnomon_SundialRock", SAND))

    dial = bmesh.new()
    C.oval_prism(dial, 50, 50, cz + 2.5, cz - 0.5, segments=40)
    for v in dial.verts:
        v.co.x += cx
        v.co.y += cy
    C.mesh_object("Sundial_Dial", dial, stone_material("Gnomon_DialStone", (0.97, 0.93, 0.82), 0.75))
    marks = bmesh.new()
    for h in range(12):
        t = h / 12 * math.tau
        long = h % 3 == 0
        r = 42
        C.box(marks, (cx + r * math.cos(t), cy + r * math.sin(t), cz + 2.7), (8 if long else 5, 1.6, 0.6), rot_z=t)
    C.mesh_object("Sundial_Marks", marks, C.flat_material("Gnomon_DialMarks", (0.30, 0.22, 0.16)))

    # The gnomon: a tall right-angled blade standing across the dial, its broad face turned toward the
    # arena so it reads as a great triangle on the skyline, its slanted edge gilded.
    blade = bmesh.new()
    half = 3.5
    pts = [(-half, -36, 0), (-half, 34, 0), (-half, -36, 170), (half, -36, 0), (half, 34, 0), (half, -36, 170)]
    v = [blade.verts.new((cx + p[0], cy + p[1], cz + 2.5 + p[2])) for p in pts]
    for face in ((0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)):
        blade.faces.new([v[i] for i in face])
    C.mesh_object("Sundial_Gnomon", blade, stone_material("Gnomon_Blade", (0.95, 0.88, 0.70), 0.7))
    edge = bmesh.new()
    C.cylinder(edge, (cx - half - 0.6, cy + 34, cz + 2.8), (cx - half - 0.6, cy - 36, cz + 2.5 + 170), 2.2, 6)
    C.mesh_object("Sundial_GildedEdge", edge, C.flat_material("Gnomon_Gilt", (0.98, 0.76, 0.28), 0.6))


def build_clouds(rng):
    clear = (C.A + 50, C.B + 50)
    C.cloud_layer("Clouds_Low", -150, 160, 900, 30, (40, 70), rng, keep_clear=clear)
    C.cloud_layer("Clouds_Sea", -260, 0, 1500, 56, (70, 120), rng)
    C.cloud_layer("Clouds_Horizon", 20, 1200, 1800, 12, (110, 190), rng)


def build():
    rng = random.Random(11)
    C.reset()
    C.sky_and_sun(sun_heading_deg=200, sun_elevation_deg=40)
    build_main(rng)
    build_islands(rng)
    build_sundial(rng)
    build_clouds(rng)
    return C.standard_cameras(gameplay_target=(60, 10, -4), edge_target=(380, 30, 20))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "gnomon")
    cams = build()
    report, bad = C.check_export()
    for name, tris, mats in report:
        print(f"MESH {name}: {tris} tris, {mats} material(s)")
    print("OVER LIMIT:", bad)
    print("FLAT:", C.surface_is_flat(bpy.data.objects["Meadow"]), C.surface_is_flat(bpy.data.objects["Rim_Stone"]))
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "gnomon.blend"))
    if "--no-render" not in args:
        for p in C.render_all(out, "gnomon", cams):
            print("RENDER", p)
