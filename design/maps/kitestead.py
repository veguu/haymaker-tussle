"""Kitestead: a raft of oversized painted timber hung in open sky, held up by kites.

Run: blender -b --factory-startup -P kitestead.py -- <out folder> [--no-render]
Backdrop: open sky and three tiers of cloud far below (sense of height). Signature material: timber with
visible grain, every plank end painted red, mustard or leaf green, so the rim is a striped band.
"""
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

PLANK = 6.0  # board width, studs
DECK_DEPTH = 4.0
PAINT = [(0.84, 0.22, 0.17), (0.96, 0.72, 0.20), (0.33, 0.66, 0.28)]  # red, mustard, leaf green
HONEY = (0.84, 0.55, 0.27)


def plank_index(nt):
    """Nodes giving the board index (floor of (y + B) / PLANK) and the position across the board."""
    tc = C.coords(nt)
    sep = C.separate(nt, tc.outputs["Object"])
    shifted = C.math_node(nt, "ADD", sep.outputs["Y"], value_b=C.B)
    across = C.math_node(nt, "DIVIDE", shifted.outputs[0], value_b=PLANK)
    idx = C.math_node(nt, "FLOOR", across.outputs[0])
    frac = C.math_node(nt, "FRACT", across.outputs[0])
    return tc, sep, idx, frac


def seam_factor(nt, frac_socket, width=0.05):
    """1 on the board, 0 on the dark joint between boards."""
    r = C.ramp(nt, [(0.0, (0, 0, 0)), (width, (1, 1, 1)), (1 - width, (1, 1, 1)), (1.0, (0, 0, 0))])
    nt.links.new(frac_socket, r.inputs["Fac"])
    return r


def deck_material():
    mat, nt, bsdf = C.new_material("Kitestead_Deck")
    tc, sep, idx, frac = plank_index(nt)
    # Each board its own shade of honey.
    noise = nt.nodes.new("ShaderNodeTexWhiteNoise")
    noise.noise_dimensions = "1D"
    nt.links.new(idx.outputs[0], noise.inputs["W"])
    shade = C.ramp(nt, [(0.0, (0.74, 0.46, 0.22)), (0.5, HONEY), (1.0, (0.90, 0.64, 0.34))])
    nt.links.new(noise.outputs["Value"], shade.inputs["Fac"])
    # Long grain along each board (along X).
    grain = C.grain(nt, tc.outputs["Object"], "X", 2.4, dark=(0.78, 0.74, 0.70))
    grained = C.multiply_colours(nt, shade.outputs["Color"], grain.outputs["Color"])
    # Butt joints: each board is several lengths, joined at staggered places.
    off = C.math_node(nt, "MULTIPLY", idx.outputs[0], value_b=17.3)
    along = C.math_node(nt, "ADD", sep.outputs["X"], off.outputs[0])
    along_s = C.math_node(nt, "DIVIDE", along.outputs[0], value_b=41.0)
    along_f = C.math_node(nt, "FRACT", along_s.outputs[0])
    butt = C.ramp(nt, [(0.0, (0, 0, 0)), (0.008, (1, 1, 1)), (0.992, (1, 1, 1)), (1.0, (0, 0, 0))])
    nt.links.new(along_f.outputs[0], butt.inputs["Fac"])
    seam = seam_factor(nt, frac.outputs[0])
    both = C.math_node(nt, "MULTIPLY", seam.outputs["Color"], butt.outputs["Color"])
    final = C.mix_colour(nt, both.outputs[0], (0.36, 0.22, 0.12), grained.outputs[2])
    nt.links.new(final.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


def painted_ends_material():
    """The rim: every board's end painted, cycling red, mustard, green, with a dark joint between."""
    mat, nt, bsdf = C.new_material("Kitestead_PaintedEnds")
    tc, sep, idx, frac = plank_index(nt)
    mod = C.math_node(nt, "FLOORED_MODULO", idx.outputs[0], value_b=3.0)
    third = C.math_node(nt, "DIVIDE", mod.outputs[0], value_b=3.0)
    paint = C.ramp(nt, [(0.0, PAINT[0]), (0.32, PAINT[1]), (0.65, PAINT[2])])
    paint.color_ramp.interpolation = "CONSTANT"
    nt.links.new(third.outputs[0], paint.inputs["Fac"])
    # A brushed, slightly uneven coat.
    brush = C.node(nt, "ShaderNodeTexNoise", Scale=0.6, Detail=4.0)
    nt.links.new(tc.outputs["Object"], brush.inputs["Vector"])
    coat = C.ramp(nt, [(0.3, (0.86, 0.86, 0.86)), (0.7, (1, 1, 1))])
    nt.links.new(brush.outputs["Fac"], coat.inputs["Fac"])
    coated = C.multiply_colours(nt, paint.outputs["Color"], coat.outputs["Color"])
    seam = seam_factor(nt, frac.outputs[0], 0.04)
    final = C.mix_colour(nt, seam.outputs["Color"], (0.30, 0.18, 0.10), coated.outputs[2])
    nt.links.new(final.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    return mat


def beam_material():
    mat, nt, bsdf = C.new_material("Kitestead_Beams")
    tc = C.coords(nt)
    g = C.grain(nt, tc.outputs["Object"], "X", 3.0, light=(0.60, 0.39, 0.21), dark=(0.45, 0.28, 0.15))
    g2 = C.grain(nt, tc.outputs["Object"], "Y", 3.0, light=(1, 1, 1), dark=(0.86, 0.86, 0.86))
    both = C.multiply_colours(nt, g.outputs["Color"], g2.outputs["Color"])
    nt.links.new(both.outputs[2], bsdf.inputs["Base Color"])
    return mat


def cell_paint_material(name, scale=0.12):
    """Paint picked per small piece: a Voronoi cell's random colour chooses red, mustard or green."""
    mat, nt, bsdf = C.new_material(name)
    tc = C.coords(nt)
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    sep = C.separate(nt, vor.outputs["Color"])
    paint = C.ramp(nt, [(0.0, PAINT[0]), (0.33, PAINT[1]), (0.66, PAINT[2])])
    paint.color_ramp.interpolation = "CONSTANT"
    nt.links.new(sep.outputs["X"], paint.inputs["Fac"])
    nt.links.new(paint.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def build_deck():
    bm = bmesh.new()
    C.oval_prism(bm, C.A - C.RIM, C.B - C.RIM, 0.0, -DECK_DEPTH)
    deck = C.mesh_object("Deck", bm, deck_material())
    bm = bmesh.new()
    C.ring(bm, C.A, C.B, C.A - C.RIM, C.B - C.RIM, 0.0, -DECK_DEPTH)
    rim = C.mesh_object("Rim_PaintedEnds", bm, painted_ends_material())
    return deck, rim


def build_underside(rng):
    """Four layers of crossbeams, each smaller and turned 90 degrees, so the raft tapers below like an
    upside-down stepped pyramid; then a keel block. Painted caps on the beam ends, rope wraps where
    layers cross."""
    beams = bmesh.new()
    caps = [bmesh.new(), bmesh.new(), bmesh.new()]
    cap_count = [0]
    wraps = bmesh.new()

    def cap(centre, size):
        C.box(caps[cap_count[0] % 3], centre, size)
        cap_count[0] += 1
    layers = [(0.92, "Y", -4.0, 5.5), (0.74, "X", -9.5, 6.0), (0.54, "Y", -15.5, 6.5), (0.34, "X", -22.0, 7.0)]
    spacing = 13.0
    for scale, axis, top, height in layers:
        a, b = C.A * scale, C.B * scale
        z = top - height / 2
        if axis == "Y":
            x = -a + spacing / 2
            while x < a:
                half = b * math.sqrt(max(1 - (x / a) ** 2, 0))
                if half > 4:
                    w = 5.0 + rng.uniform(-0.5, 0.5)
                    C.box(beams, (x, 0, z), (w, half * 2, height))
                    for sgn in (-1, 1):
                        cap((x, sgn * (half + 0.3), z), (w + 0.2, 0.6, height + 0.2))
                x += spacing
        else:
            y = -b + spacing / 2
            while y < b:
                half = a * math.sqrt(max(1 - (y / b) ** 2, 0))
                if half > 4:
                    w = 5.0 + rng.uniform(-0.5, 0.5)
                    C.box(beams, (0, y, z), (half * 2, w, height))
                    for sgn in (-1, 1):
                        cap((sgn * (half + 0.3), y, z), (0.6, w + 0.2, height + 0.2))
                    # rope wraps a third of the way in
                    for sgn in (-1, 1):
                        cx = sgn * half * 0.55
                        C.cylinder(wraps, (cx - 0.7, y, z), (cx + 0.7, y, z), 4.1, 8)
                y += spacing
    # keel
    C.box(beams, (0, 0, -33.0), (C.A * 0.22, C.B * 0.16, 8.0))
    C.box(beams, (0, 0, -40.0), (C.A * 0.10, C.B * 0.08, 6.0))
    objs = [
        C.mesh_object("Underside_Beams", beams, beam_material()),
        C.mesh_object("Underside_EndsRed", caps[0], C.flat_material("Kitestead_PaintRed", PAINT[0], 0.8)),
        C.mesh_object("Underside_EndsMustard", caps[1], C.flat_material("Kitestead_PaintMustard", PAINT[1], 0.8)),
        C.mesh_object("Underside_EndsGreen", caps[2], C.flat_material("Kitestead_PaintGreen", PAINT[2], 0.8)),
        C.mesh_object("Underside_RopeWraps", wraps, C.flat_material("Kitestead_Rope", (0.62, 0.48, 0.30))),
    ]
    return objs


def diamond(bm, centre, facing, height, width, depth, part):
    """One quarter (part 0..3) of a kite's diamond, as a thin prism, in the plane facing `facing`."""
    cx, cy, cz = centre
    fx, fy = facing
    # in-plane axes: right (horizontal) and up (tilted back 25 degrees)
    rx, ry = -fy, fx
    tilt = math.radians(25)
    up = (fx * -math.sin(tilt), fy * -math.sin(tilt), math.cos(tilt))
    top = (up[0] * height * 0.62, up[1] * height * 0.62, up[2] * height * 0.62)
    bottom = (-up[0] * height * 0.38, -up[1] * height * 0.38, -up[2] * height * 0.38)
    left = (-rx * width / 2, -ry * width / 2, 0)
    right = (rx * width / 2, ry * width / 2, 0)
    corners = [(top, right), (right, bottom), (bottom, left), (left, top)][part]
    pts = [(0, 0, 0), corners[0], corners[1]]
    n = (fx * math.cos(tilt) * depth / 2, fy * math.cos(tilt) * depth / 2, math.sin(tilt) * depth / 2)
    front = [bm.verts.new((cx + p[0] + n[0], cy + p[1] + n[1], cz + p[2] + n[2])) for p in pts]
    back = [bm.verts.new((cx + p[0] - n[0], cy + p[1] - n[1], cz + p[2] - n[2])) for p in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new((front[i], back[i], back[j], front[j]))
    return top, bottom


def build_kites(rng):
    fabric_colours = {
        "Red": (0.86, 0.24, 0.18),
        "Mustard": (0.97, 0.76, 0.26),
        "Green": (0.36, 0.68, 0.30),
        "Cream": (0.98, 0.93, 0.80),
    }
    fabric = {k: bmesh.new() for k in fabric_colours}
    rigging = bmesh.new()
    pairs = [("Red", "Cream"), ("Mustard", "Green"), ("Green", "Cream"), ("Cream", "Red"), ("Mustard", "Red")]
    count = 11
    for i in range(count):
        t = i / count * math.tau + rng.uniform(-0.18, 0.18)
        dist = rng.uniform(165, 260)
        x, y = dist * math.cos(t) * 1.05, dist * math.sin(t) * 0.95
        size = rng.uniform(34, 50)
        # Well below the deck, so they never break the rim line from anywhere on the arena (the rim is
        # about 8 degrees below eye level from the middle): a kite's top is 0.62 of its size above its
        # centre, and stays at least 50 studs under the deck.
        z = rng.uniform(-110, -50) - size * 0.62
        facing = (-math.cos(t), -math.sin(t))
        c1, c2 = pairs[i % len(pairs)]
        top = bottom = None
        for part in range(4):
            top, bottom = diamond(fabric[c1 if part % 2 == 0 else c2], (x, y, z), facing, size, size * 0.72, 0.5, part)
        # spars
        C.cylinder(rigging, (x + top[0], y + top[1], z + top[2]), (x + bottom[0], y + bottom[1], z + bottom[2]), 0.35, 6)
        # tether to the underside
        anchor_t = t + rng.uniform(-0.1, 0.1)
        ax, ay = C.A * 0.7 * math.cos(anchor_t), C.B * 0.7 * math.sin(anchor_t)
        C.cylinder(rigging, (x + bottom[0], y + bottom[1], z + bottom[2]), (ax, ay, -12.0), 0.25, 5)
        # tail of bows, sagging down and away
        bx, by, bz = x + bottom[0], y + bottom[1], z + bottom[2]
        for k in range(1, 7):
            px = bx - facing[0] * k * 3.0
            py = by - facing[1] * k * 3.0
            pz = bz - k * 3.2 - 0.25 * k * k
            colour = c2 if k % 2 else c1
            C.box(fabric[colour], (px, py, pz), (2.4, 2.4, 1.2), rot_z=t + k)
    objs = []
    for name, bm in fabric.items():
        objs.append(C.mesh_object(f"Kites_{name}", bm, C.flat_material(f"Kite_{name}", fabric_colours[name], 0.95)))
    objs.append(C.mesh_object("Kites_Rigging", rigging, C.flat_material("Kitestead_Rigging", (0.40, 0.29, 0.19))))
    return objs


def build_clouds(rng):
    clear = (C.A + 45, C.B + 45)
    C.cloud_layer("Clouds_Near", -95, 190, 650, 22, (26, 44), rng, keep_clear=clear)
    C.cloud_layer("Clouds_Mid", -190, 140, 1000, 32, (40, 70), rng, keep_clear=clear)
    C.cloud_layer("Clouds_Sea", -330, 0, 1500, 64, (70, 120), rng)
    # Distant towering cumulus on the horizon, for the sense of open sky.
    C.cloud_layer("Clouds_Horizon", 30, 1300, 1900, 14, (120, 200), rng)


def build():
    rng = random.Random(7)
    C.reset()
    C.sky_and_sun(sun_heading_deg=215, sun_elevation_deg=40)
    build_deck()
    build_underside(rng)
    build_kites(rng)
    build_clouds(rng)
    cams = C.standard_cameras(gameplay_target=(60, 12, 3), edge_target=(C.A + 220, 60, -45))
    return cams


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "kitestead")
    cams = build()
    report, bad = C.check_export()
    for name, tris, mats in report:
        print(f"MESH {name}: {tris} tris, {mats} material(s)")
    print("OVER LIMIT:", bad)
    print("FLAT:", C.surface_is_flat(bpy.data.objects["Deck"]), C.surface_is_flat(bpy.data.objects["Rim_PaintedEnds"]))
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "kitestead.blend"))
    if "--no-render" not in args:
        for p in C.render_all(out, "kitestead", cams):
            print("RENDER", p)
