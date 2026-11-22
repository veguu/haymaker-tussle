"""Toon-lobe smoke for FxKit.Tex.Smoke, built and rendered in Blender (EEVEE, Shader to RGB, Standard colour).

  blender.exe -b --factory-startup --python-exit-code 1 --python design/vfx/smoke/smoke_toon.py -- looks
  blender.exe -b --factory-startup --python-exit-code 1 --python design/vfx/smoke/smoke_toon.py -- sheet

The puff is a handful of overlapping balls, lit by one sun from the upper
left, and shaded in flat steps: diffuse light -> Shader to RGB -> a CONSTANT colour ramp -> emission. Greyscale only
(the emitters tint it); the film is transparent.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
STAGE = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "looks"
CELL = 256
FILL = 0.70  # the biggest frame fills about this share of the cell

# The lobes: (x, z, y toward the camera, radius). Laid out on purpose: one big, a ring of smaller ones, no two alike.
LOBES = [
    (0.00, 0.05, 0.00, 1.00),
    (0.92, 0.38, -0.10, 0.66),
    (-0.88, 0.30, -0.05, 0.72),
    (0.28, 0.90, 0.10, 0.62),
    (-0.42, 0.86, 0.15, 0.50),
    (0.74, -0.52, 0.20, 0.58),
    (-0.60, -0.58, 0.25, 0.64),
    (0.05, -0.80, 0.30, 0.52),
]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"  # not AgX: flat tones must come out as written
    scene.view_settings.look = "None"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_percentage = 100
    scene.render.filter_size = 1.2
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0
    scene.world = world
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.0
    sun_data.angle = math.radians(1)
    sun_data.use_shadow = False  # cast shadows terrace on the remeshed surface: the steps come from the light alone
    sun = bpy.data.objects.new("Sun", sun_data)
    # the light comes from the upper left front: the sun's own +Z points back at where it shines from
    sun.rotation_euler = Vector((-0.55, -0.6, 0.65)).to_track_quat("Z", "Y").to_euler()
    scene.collection.objects.link(sun)
    return scene, cam


def puff(scene, lobes, voxel=0.022):
    """The balls, joined into one object."""
    made = []
    for x, z, y, r in lobes:
        if r <= 0.02:
            continue
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=r, location=(x, y, z))
        made.append(bpy.context.active_object)
    for ob in made:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    if len(made) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = "Puff"
    # NOT remeshed into one skin: a voxel remesh gave stair-stepped tone edges (its normals are faceted). Whole balls
    # keep true round normals, so every flat tone ends in a clean curve, and each lobe reads as its own ball.
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


def toon(name, stops, rim=None):
    """stops: [(position, grey)] of a CONSTANT ramp over the light on the surface. rim = (width 0-1, grey): a flat
    band where the surface turns away from the camera."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    elements = ramp.color_ramp.elements
    while len(elements) > 1:
        elements.remove(elements[-1])
    elements[0].position, elements[0].color = stops[0][0], (stops[0][1],) * 3 + (1,)
    for position, grey in stops[1:]:
        e = elements.new(position)
        e.color = (grey, grey, grey, 1)
    emission = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(diffuse.outputs[0], to_rgb.inputs[0])
    nt.links.new(to_rgb.outputs[0], ramp.inputs[0])
    colour = ramp.outputs[0]
    if rim:
        weight = nt.nodes.new("ShaderNodeLayerWeight")
        weight.inputs[0].default_value = 0.5
        edge = nt.nodes.new("ShaderNodeMath")
        edge.operation = "GREATER_THAN"
        edge.inputs[1].default_value = 1 - rim[0]
        nt.links.new(weight.outputs["Facing"], edge.inputs[0])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["B"].default_value = (rim[1],) * 3 + (1,)
        nt.links.new(edge.outputs[0], mix.inputs["Factor"])
        nt.links.new(colour, mix.inputs["A"])
        colour = mix.outputs["Result"]
    nt.links.new(colour, emission.inputs[0])
    nt.links.new(emission.outputs[0], out.inputs[0])
    return mat


def outline(ob, thickness=0.06, grey=0.42):
    """A darker shell behind the puff (an inverted hull): a clean drawn edge."""
    mat = bpy.data.materials.new("Line")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emission = nt.nodes.new("ShaderNodeEmission")
    emission.inputs[0].default_value = (grey, grey, grey, 1)
    nt.links.new(emission.outputs[0], out.inputs[0])
    mat.use_backface_culling = True
    ob.data.materials.append(mat)
    mod = ob.modifiers.new("Hull", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 1
    mod.use_flip_normals = True
    mod.material_offset = 1
    return mod


def frame_camera(cam, extent):
    cam.data.ortho_scale = 2 * extent / FILL


def render(scene, path, size=CELL):
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


LOOKS = {
    # 1: a solid cauliflower: three flat tones, the shadow on the underside, a clean edge, nothing else
    "1_solid": dict(stops=[(0.0, 0.58), (0.22, 0.80), (0.55, 1.0)]),
    # 2: as the reference's ring: a light rim band along the edge over a flat grey fill
    "2_rim": dict(stops=[(0.0, 0.62), (0.30, 0.78)], rim=(0.42, 1.0)),
    # 3: drawn: two flat tones inside a darker outline
    "3_outlined": dict(stops=[(0.0, 0.72), (0.30, 1.0)], line=True),
}

if STAGE == "looks":
    os.makedirs(OUT, exist_ok=True)
    for name, look in LOOKS.items():
        scene, cam = reset()
        ob = puff(scene, LOBES)
        ob.data.materials.append(toon("Toon", look["stops"], look.get("rim")))
        if look.get("line"):
            outline(ob)
        frame_camera(cam, 1.75)
        print("LOOK", render(scene, os.path.join(OUT, f"look_{name}.png"), size=512))


# ---------------------------------------------------------------------------------------------------------------
# THE FLIPBOOK (the owner's picks, 2026-11-21: look "3: Outlined"; ending "Both": the big lobes hollow out while the
# small ones drift off and shrink; "Solid in the texture").
# Each lobe is its OWN ball object (a unit sphere, scaled), so the material can cut a hole in it from its own centre:
# the picture-plane distance from the ball's middle (object coordinates) against the ball's "hole" property. The
# outline is an inverted hull on every ball, cut by the same hole, so a hollowed lobe is left as a drawn arch.
FRAMES = 16
BIG = (0, 1, 2)  # these hollow out; the rest drift off and shrink
TONE_SHADOW, TONE_LIGHT, TONE_LINE = 0.50, 1.0, 0.20  # scene-linear greys (Standard: about 188, 255 and 124 of 255)
LINE_WIDTH = 0.060  # the outline, in scene units (about 3 px of a 256 px cell)
ORTHO = 2 * 1.75 / FILL
# The hole in each big lobe: when it starts (share of the life) and which way its middle slides as it grows (in the
# ball's own units): down and toward the puff's middle, so what is left is an ARCH on the lobe's upper, outer side
# (the reference's rim at 13.20 s), not a ring. A noise bends the hole's edge so it is never a perfect circle.
HOLE_FROM = {0: 0.24, 1: 0.36, 2: 0.46}
HOLE_SLIDE = {0: (0.05, -0.46), 1: (-0.40, -0.26), 2: (0.42, -0.22)}
HOLE_NOISE = 0.22


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def lobe_state(index, frame):
    """Where a lobe is on a frame: (x, z, y, radius, hole 0-1)."""
    x, z, y, r = LOBES[index]
    u = frame / (FRAMES - 1)
    grow = (0.80, 0.94, 1.0)[frame] if frame < 3 else 1.0  # full size at once: no growing in
    if index in BIG:
        out = 1 + 0.22 * u
        # one after another, never together (three holes opening at once read as a face, then as linked rings)
        start = HOLE_FROM[index]
        hole = smooth(start, 0.93, u) * 1.30
        radius = r * grow * (1 + 0.10 * u)
        if frame == FRAMES - 1:
            radius = 0.0  # the last arches are gone on the last frame
    else:
        out = 1 + 0.62 * smooth(0.10, 1.0, u)
        hole = 0.0
        radius = r * grow * (1 - smooth(0.30, 1.0, u) * 0.94)
    # The owner on the first preview: "the smoke burst shouldnt drop". So NOTHING moves down: no sinking to re-centre the
    # dying puff (that was my fix for a check), and the lobes under the middle drift out sideways, not downward. The
    # whole puff lifts a little, as smoke does; its weight climbs on purpose as the bottoms clear into arches.
    rise = 0.12 * u
    if z < 0:
        return x * out * grow, (z + rise) * grow, y, radius, hole
    return x * out * grow, (z * out + rise) * grow, y, radius, hole


def hole_cut(nt, shader_out):
    """Mixes a shader with nothing inside the ball's hole. Returns the socket to plug into the output."""
    coords = nt.nodes.new("ShaderNodeTexCoord")
    split = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coords.outputs["Object"], split.inputs[0])
    flat = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(split.outputs["X"], flat.inputs["X"])
    nt.links.new(split.outputs["Z"], flat.inputs["Y"])
    hole = nt.nodes.new("ShaderNodeAttribute")
    hole.attribute_type = "OBJECT"
    hole.attribute_name = "hole"
    slide = nt.nodes.new("ShaderNodeAttribute")
    slide.attribute_type = "OBJECT"
    slide.attribute_name = "slide"  # (x, z, 0): where the hole's middle is, already times the hole's size
    moved = nt.nodes.new("ShaderNodeVectorMath")
    moved.operation = "SUBTRACT"
    nt.links.new(flat.outputs[0], moved.inputs[0])
    nt.links.new(slide.outputs["Vector"], moved.inputs[1])
    length = nt.nodes.new("ShaderNodeVectorMath")
    length.operation = "LENGTH"
    nt.links.new(moved.outputs[0], length.inputs[0])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.2
    noise.inputs["Detail"].default_value = 0.0
    nt.links.new(flat.outputs[0], noise.inputs["Vector"])
    bend = nt.nodes.new("ShaderNodeMath")  # (noise - 0.5) * HOLE_NOISE
    bend.operation = "MULTIPLY_ADD"
    bend.inputs[1].default_value = HOLE_NOISE
    bend.inputs[2].default_value = -0.5 * HOLE_NOISE
    nt.links.new(noise.outputs["Fac"], bend.inputs[0])
    bent = nt.nodes.new("ShaderNodeMath")
    bent.operation = "ADD"
    nt.links.new(length.outputs["Value"], bent.inputs[0])
    nt.links.new(bend.outputs[0], bent.inputs[1])
    keep = nt.nodes.new("ShaderNodeMath")
    keep.operation = "GREATER_THAN"
    nt.links.new(bent.outputs[0], keep.inputs[0])
    nt.links.new(hole.outputs["Fac"], keep.inputs[1])
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(keep.outputs[0], mix.inputs[0])
    nt.links.new(clear.outputs[0], mix.inputs[1])
    nt.links.new(shader_out, mix.inputs[2])
    return mix.outputs[0]


def flipbook_materials():
    body = toon("Body", [(0.0, TONE_SHADOW), (0.30, TONE_LIGHT)])
    nt = body.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    emission = next(n for n in nt.nodes if n.type == "EMISSION")
    nt.links.new(hole_cut(nt, emission.outputs[0]), out.inputs[0])
    body.use_backface_culling = True
    line = bpy.data.materials.new("Line")
    line.use_nodes = True
    nt = line.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emission = nt.nodes.new("ShaderNodeEmission")
    emission.inputs[0].default_value = (TONE_LINE,) * 3 + (1,)
    nt.links.new(hole_cut(nt, emission.outputs[0]), out.inputs[0])
    line.use_backface_culling = True
    for mat in (body, line):
        mat.surface_render_method = "DITHERED"
    return body, line


def build_flipbook_scene():
    scene, cam = reset()
    cam.data.ortho_scale = ORTHO
    body, line = flipbook_materials()
    balls = []
    for index in range(len(LOBES)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.0)
        ball = bpy.context.active_object
        ball.name = f"Lobe{index}"
        for poly in ball.data.polygons:
            poly.use_smooth = True
        ball.data.materials.append(body)
        ball.data.materials.append(line)
        hull = ball.modifiers.new("Hull", "SOLIDIFY")
        hull.offset = 1
        hull.use_flip_normals = True
        hull.material_offset = 1
        ball["hole"] = -1.0
        ball["slide"] = (0.0, 0.0, 0.0)
        balls.append(ball)
    return scene, cam, balls


def pose_frame(balls, frame):
    for index, ball in enumerate(balls):
        x, z, y, radius, hole = lobe_state(index, frame)
        ball.hide_render = radius < 0.03
        ball.location = (x, y, z)
        ball.scale = (max(radius, 0.001),) * 3
        ball.modifiers["Hull"].thickness = LINE_WIDTH / max(radius, 0.03)  # the same width on every lobe
        ball["hole"] = hole if hole > 0.02 else -1.0  # -1: no hole at all (the noise can't nibble a whole ball)
        sx, sz = HOLE_SLIDE.get(index, (0.0, 0.0))
        ball["slide"] = (sx * hole, sz * hole, 0.0)
        ball.update_tag()


def load_pixels(path):
    import numpy as np

    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)


if STAGE == "sheet":
    import numpy as np

    os.makedirs(OUT, exist_ok=True)
    scene, cam, balls = build_flipbook_scene()
    sheet = np.zeros((CELL * 4, CELL * 4, 4), dtype=np.float32)
    for frame in range(FRAMES):
        pose_frame(balls, frame)
        bpy.context.view_layer.update()
        path = render(scene, os.path.join(OUT, f"_cell_{frame:02d}.png"))
        cell = load_pixels(path)
        row, column = frame // 4, frame % 4  # play order: left to right, then top to bottom
        y0 = (3 - row) * CELL  # pixel rows run bottom-up
        sheet[y0:y0 + CELL, column * CELL:(column + 1) * CELL] = cell
        os.remove(path)
    image = bpy.data.images.new("sheet", CELL * 4, CELL * 4, alpha=True)
    image.alpha_mode = "STRAIGHT"
    image.pixels.foreach_set(sheet.ravel())
    image.filepath_raw = os.path.join(OUT, "smoke_toon.png")
    image.file_format = "PNG"
    image.save()
    print("SHEET", image.filepath_raw)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "smoke_toon.blend"))
