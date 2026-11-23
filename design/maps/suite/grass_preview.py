"""A look at the field grass in Blender, before anything is uploaded: the built map's review scene with the clumps
planted in a ring round the camera by the SAME rules as the game (Core/FieldGrass: one clump per 4-stud cell,
jittered, its shape, turn, size and tint from the cell), leaning in the map's wind at one moment (a gust band
crossing), parted round an R6-sized fighter and still bent in the wake behind them.

    blender -b --factory-startup <out>/meadow_review.blend -P grass_preview.py -- <out>

Renders grass_run.png (third person behind the fighter), grass_fight.png (the map's Gameplay camera) and
grass_low.png (a low view beside the fighter: grass height against a fighter's 5 studs). Saves grass_preview.blend.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0])

# MapEnvironments.Maps.meadow.fieldGrass and Gnomon's wind (the meadow shares Gnomon's environment)
CELL, RADIUS, FADE, MARGIN, VARIANTS = 4.0, 80.0, 28.0, 2.5, 4
SCALE = (0.85, 1.15)
COLOURS = [(112, 172, 84), (98, 160, 80), (128, 178, 88), (104, 164, 96)]
GUST_BOOST, BEND_R, BEND_MAX, SINK, HEIGHT = 2.2, 4.2, math.radians(55), 0.15, 2.6
WIND = dict(lean=0.09, strength=0.3, gustLength=42.0, gustSeconds=4.0, flutter=0.05, flutterSeconds=1.2)
A, B = 213.0, 176.0
d = math.hypot(1.0, 0.3)
WX, WZ = 1.0 / d, 0.3 / d
T = 1.1  # the moment shown: a gust band is crossing the view

FIGHTER = (-12.0, 104.0)  # arena-local x, z: on the spawn ring's lobby side, running north (toward -z)
RUN_SPEED = 22.0  # studs/s, for the wake


def W(x, z, y=0.0):
    return Vector((x, -z, y))


def hsh(ix, iz, ch):
    v = math.sin(ix * 127.1 + iz * 311.7 + ch * 74.7) * 43758.5453
    return v - math.floor(v)


def clump_at(ix, iz):
    x = (ix + 0.1 + 0.8 * hsh(ix, iz, 1)) * CELL
    z = (iz + 0.1 + 0.8 * hsh(ix, iz, 2)) * CELL
    a, b = A - MARGIN, B - MARGIN
    if (x / a) ** 2 + (z / b) ** 2 >= 1:
        return None
    return dict(x=x, z=z, yaw=hsh(ix, iz, 3) * math.tau, scale=SCALE[0] + (SCALE[1] - SCALE[0]) * hsh(ix, iz, 4),
                variant=int(hsh(ix, iz, 5) * VARIANTS), tint=int(hsh(ix, iz, 6) * len(COLOURS)), phase=hsh(ix, iz, 7))


def wind_lean(x, z, t, phase):
    along = x * WX + z * WZ
    g = math.sin((along / WIND["gustLength"] - t / WIND["gustSeconds"]) * math.tau)
    band = g * g if g > 0 else 0.0
    flutter = WIND["flutter"] * math.sin((t / WIND["flutterSeconds"] + phase) * math.tau)
    return WIND["lean"] + WIND["strength"] * GUST_BOOST * band + flutter


def srgb_lin(c):
    return tuple(((v / 255.0) ** 2.2) for v in c) + (1.0,)


def main():
    scene = bpy.context.scene
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, "grass", "field_grass.glb"))
    templates = sorted((o for o in bpy.data.objects if o not in before and o.type == "MESH"), key=lambda o: o.name)
    col = bpy.data.collections.new("FieldGrass")
    scene.collection.children.link(col)
    # the game's look: the mesh's greyscale shade (its colour attribute) times the part's Color
    mat = bpy.data.materials.new("FieldGrassTint")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.9
    vc = nt.nodes.new("ShaderNodeVertexColor")
    oi = nt.nodes.new("ShaderNodeObjectInfo")
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(vc.outputs["Color"], mul.inputs["A"])
    nt.links.new(oi.outputs["Color"], mul.inputs["B"])
    nt.links.new(mul.outputs["Result"], bsdf.inputs["Base Color"])
    for t in templates:
        vc.layer_name = t.data.color_attributes[0].name if t.data.color_attributes else ""
        t.data.materials.clear()
        t.data.materials.append(mat)
        t.hide_render = True
        t.hide_set(True)
    cams = {}
    fx, fz = FIGHTER
    cams["grass_run"] = (W(fx + 3, fz + 13, 7.5), W(fx, fz - 30, 1.5), 30)
    cams["grass_low"] = (W(fx + 9, fz + 7, 2.6), W(fx - 2, fz - 4, 2.2), 32)
    focus = (fx + 2, fz + 6)  # the ring follows the camera: centred near both views
    wake = [(fx, fz + k * 3.0, math.exp(-BEND_IN_OUT * (k * 3.0 / RUN_SPEED))) for k in range(1, 7)]
    planted = 0
    for ix in range(int((focus[0] - RADIUS) // CELL) - 1, int((focus[0] + RADIUS) // CELL) + 2):
        for iz in range(int((focus[1] - RADIUS) // CELL) - 1, int((focus[1] + RADIUS) // CELL) + 2):
            c = clump_at(ix, iz)
            if not c:
                continue
            dist = math.hypot(c["x"] - focus[0], c["z"] - focus[1])
            if dist > RADIUS:
                continue
            lean = math.atan(wind_lean(c["x"], c["z"], T, c["phase"]))
            ax, az = WX * lean, WZ * lean
            # parted round the fighter, and still bent along the wake behind them
            for px, pz, keep in [(fx, fz, 1.0)] + wake:
                dx, dz = c["x"] - px, c["z"] - pz
                dd = math.hypot(dx, dz)
                if dd < BEND_R:
                    s = BEND_MAX * (1 - dd / BEND_R) * keep / max(dd, 0.3)
                    ax, az = ax + dx * s, az + dz * s
            ang = math.hypot(ax, az)
            start = RADIUS - FADE
            sink = SINK + ((min(1, (dist - start) / FADE)) ** 2 * HEIGHT * c["scale"] if dist > start else 0)
            m = Matrix.Translation(W(c["x"], c["z"], -sink))
            if ang > 1e-4:
                bx, by = ax / ang, -az / ang  # toward (ax, az) arena-local = (ax, -az) in Blender
                m = m @ Matrix.Rotation(ang, 4, Vector((-by, bx, 0)))
            m = m @ Matrix.Rotation(-c["yaw"], 4, "Z") @ Matrix.Scale(c["scale"], 4)
            o = bpy.data.objects.new(f"G{planted}", templates[c["variant"]].data)
            o.matrix_world = m
            o.color = srgb_lin(COLOURS[c["tint"]])
            col.objects.link(o)
            planted += 1
    print("PLANTED", planted, flush=True)
    # an R6-sized fighter for scale (5 studs), mid-run
    fig = bpy.data.collections.new("Fighter")
    scene.collection.children.link(fig)

    def part(name, size, at, rgb, rot=0.0):
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        o = bpy.context.active_object
        o.name = name
        o.scale = size
        o.location = at
        o.rotation_euler = (rot, 0, 0)
        m = bpy.data.materials.new(name)
        m.diffuse_color = srgb_lin(rgb)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = srgb_lin(rgb)
        o.data.materials.append(m)
        for c in list(o.users_collection):
            c.objects.unlink(o)
        fig.objects.link(o)

    base = W(fx, fz, 0)
    part("LegL", (1, 1, 2), base + Vector((-0.5, 0, 1)), (60, 70, 110), 0.35)
    part("LegR", (1, 1, 2), base + Vector((0.5, 0, 1)), (60, 70, 110), -0.35)
    part("Torso", (2, 1, 2), base + Vector((0, 0, 3)), (236, 112, 86))
    part("ArmL", (1, 1, 2), base + Vector((-1.5, 0, 3)), (236, 200, 160), -0.5)
    part("ArmR", (1, 1, 2), base + Vector((1.5, 0, 3)), (236, 200, 160), 0.5)
    part("Head", (1.2, 1.2, 1.2), base + Vector((0, 0, 4.6)), (236, 200, 160))
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    for name, (loc, target, lens) in cams.items():
        cd = bpy.data.cameras.new(name)
        cd.lens = lens
        cd.clip_start = 0.3
        cd.clip_end = 20000
        cam = bpy.data.objects.new(name, cd)
        cam.location = loc
        cam.rotation_euler = (target - loc).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(cam)
        scene.camera = cam
        scene.render.filepath = os.path.join(OUT, f"{name}.png")
        bpy.ops.render.render(write_still=True)
    gp = bpy.data.objects.get("Gameplay")
    if gp:
        scene.camera = gp
        scene.render.filepath = os.path.join(OUT, "grass_fight.png")
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "grass_preview.blend"))


BEND_IN_OUT = 2.0  # the game's closing rate (1/s)
main()
