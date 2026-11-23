"""A POOF for FxKit.Tex.Smoke: 16 frames of a smoke puff that bursts, rolls and breaks into clumps. Blender, EEVEE.

  blender.exe -b --factory-startup --python-exit-code 1 --python design/vfx/smoke/smoke_poof.py

The owner on the toon-lobe sheet (2026-11-21): "the problem might be with the smoke itself, rather than changing the
existing shape, it should go through frames like an animation. i want the puff to burst, like an actual puff of smoke";
then, on the look: "Soft like the reference", "Break into clumps", "Pop in 2 frames". References: the cartoon smoke
puff (YouTube ucajyMCX33o: a dense white ball with a dozen or more small bumps round its edge, going patchy and
breaking into soft clumps) and the explosion (oM4CaPonk0E: nothing, then most of its size ONE frame later, then it
keeps rolling and boiling while it thins).

HOW: the puff is about forty soft balls THROWN from the middle, each with its own path, size and life, the way a
puff of smoke is many small billows. Nothing is one shape being edited: every frame is where the balls have got to.
  - burst: every ball is near the middle on frame 1 and most of the way out on frame 2;
  - roll: after that each keeps drifting outward and turning about its clump, swelling and sinking a little;
  - break up: the balls in the middle go first, so the ball opens into seven clumps; the clumps keep moving apart
    while their balls shrink away one after another.
Lit softly (one sun, a pale sky) with plain smooth shading; then the edge is softened and the last frames thinned.
(Tried first and dropped: a volume with a noise-bumped density. It came out a flat white disc with fuzz, whatever
the settings, and its first render took 14 minutes.)
"""
import math
import os
import random

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FRAMES, CELL, RENDER = 16, 256, 512
REACH = float(os.environ.get("POOF_REACH", 0.50))  # how far the clumps' middles are thrown, in half-cells
SCALE = 0.585  # everything, so the full-grown puff spans about 70 % of the cell (measured: 95 % at 1.0)
SHADE_SOFT = 6.0  # the shading is smeared this far, so the mass reads as one, not as balls
SOFT = 2.6  # the edge's softening, in pixels of the 256 px cell (a gaussian's sigma)


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def make_balls():
    """Every ball: where it is thrown (a unit direction and a distance), its size, when it dies, how it turns."""
    rng = random.Random(11)
    balls = []
    # The owner on the 81-ball poof: "too many individual bits". So FEWER, BIGGER masses: five clumps, their balls
    # packed tight and fading TOGETHER (a clump dies as one soft patch, not ball by ball), and the shading smeared
    # so no single ball shows inside the mass; only the bumps on the outline are left of them.
    clumps = 5
    for c in range(clumps):
        angle = 2 * math.pi * (c + rng.uniform(-0.22, 0.22)) / clumps
        middle = Vector((math.cos(angle), rng.uniform(-0.25, 0.25), math.sin(angle)))
        reach = REACH * rng.uniform(0.85, 1.12)
        # The owner on the "heart lasts longest" poof: "the middle doesnt seem to fade/move parallel with the others".
        # So EVERYTHING fades over the same stretch and moves out by the same share: the middle, its bumps and the
        # clumps thin together (a clump is only a little earlier or later than the rest), and the middle's balls are
        # thrown far enough to be seen travelling with them.
        clump_dies = rng.uniform(0.97, 1.06)
        for b in range(9):
            offset = Vector((rng.uniform(-1, 1), rng.uniform(-0.6, 0.6), rng.uniform(-1, 1))) * 0.13
            balls.append(dict(
                middle=middle, reach=reach, offset=offset,
                size=rng.uniform(0.16, 0.25) * (1.35 if b == 0 else 1.0),
                dies=clump_dies + rng.uniform(-0.03, 0.03),
                spin=rng.uniform(-2.4, 2.4), phase=rng.uniform(0, 6.28),
            ))
    # The owner on the five-clump poof: "i dont like how theres nothing in the middle". So the middle is NOT the first
    # to go any more: it is the puff's heart, the last thing left; the clumps peel away from it and fade first.
    for _ in range(9):  # the middle: bigger, thrown a short way, the last to fade
        direction = Vector((rng.uniform(-1, 1), rng.uniform(-0.3, 0.3), rng.uniform(-1, 1)))
        balls.append(dict(
            middle=direction.normalized(), reach=REACH * rng.uniform(0.08, 0.30), offset=Vector((0, 0, 0)),
            # the owner: 0.80 was "too big"; then "should be bigger but not huge enough to overshadow the others": the middle
            # swells a little more than the clumps (0.45 against 0.30) from a smaller start, so the lobes stay in view
            # then: "it should swell only big enough to where there is still a gap between it and the smoke around
            # it": the middle is a small tight knot, the clumps travel well clear of it, and nothing sits between.
            # and then, clearer: "near the end of the flipbook, it should be big during the largest point of the smoke
            # ... it should cover the gap at the start and reveal it slowly as the others move away". So the middle is
            # BIG while the puff is whole (it fills the space between the clumps), barely swells after that, and the
            # gap round it opens late and slowly, because the clumps start slow and speed up.
            size=rng.uniform(0.28, 0.35), dies=rng.uniform(0.98, 1.06), grow=0.12,
            spin=0.0, phase=rng.uniform(0, 6.28),
        ))
    for _ in range(0):  # (no bumps round the heart any more: they filled the gap the owner asked for), so what is left at the end is still a bumpy puff, not an oval
        direction = Vector((rng.uniform(-1, 1), rng.uniform(-0.3, 0.3), rng.uniform(-1, 1))).normalized()
        balls.append(dict(
            middle=direction, reach=REACH * rng.uniform(0.50, 0.72), offset=Vector((0, 0, 0)),
            size=rng.uniform(0.14, 0.21), dies=rng.uniform(0.97, 1.06), grow=0.35,
            spin=0.0, phase=rng.uniform(0, 6.28),
        ))
    return balls


def ball_state(ball, frame):
    """(location, radius, how solid 0-1) on a frame. A ball never shrinks to a dot (that read as bubbles). The owner:
    "maybe you can have the middle enlarge, and fade out": as a ball goes see-through it SWELLS, the middle most of
    all, the way smoke spreads thin; everything fades over the same stretch."""
    u = frame / (FRAMES - 1)
    thrown = (0.26, 0.80, 0.93)[frame] if frame < 3 else 0.96 + 0.20 * u + 1.00 * u * u  # the pop, then the clumps keep moving apart
    if "grow" in ball:
        thrown = min(thrown, 1.08)  # the middle stays where the pop put it; only the clumps keep travelling
    swollen = (0.55, 0.95, 1.0)[frame] if frame < 3 else 1.0 + 0.17 * math.sin(ball["phase"] + 7.0 * u)  # boiling
    turn = ball["spin"] * u  # the ball turns about its clump's middle as the clump rolls
    offset = ball["offset"]
    rolled = Vector((offset.x * math.cos(turn) - offset.z * math.sin(turn), offset.y,
                     offset.x * math.sin(turn) + offset.z * math.cos(turn)))
    place = ball["middle"] * ball["reach"] * thrown + rolled * (0.55 + 0.75 * min(thrown, 1.2))
    life = smooth(ball["dies"] - 0.78, ball["dies"], u)  # thins from a quarter of the way in: a long, even fade
    place = place + Vector((0, 0, 0.05 * u))  # the thinning smoke lifts a touch; it must never sink
    return place * SCALE, ball["size"] * swollen * (1 + ball.get("grow", 0.3) * life) * SCALE, 1 - life


def build(balls):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x = scene.render.resolution_y = RENDER
    scene.render.resolution_percentage = 100
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.85  # a bright sky: one soft white mass, faint shading
    scene.world = world
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0  # the picture is the cell: -1 to 1
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 1.5
    sun_data.angle = math.radians(25)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = Vector((-0.5, -0.65, 0.7)).to_track_quat("Z", "Y").to_euler()  # from the upper left front
    scene.collection.objects.link(sun)
    mat = bpy.data.materials.new("Smoke")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.9, 0.9, 0.9, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    solid = mat.node_tree.nodes.new("ShaderNodeAttribute")  # each ball's own "solid" property: it fades by itself
    solid.attribute_type = "OBJECT"
    solid.attribute_name = "solid"
    mat.node_tree.links.new(solid.outputs["Fac"], bsdf.inputs["Alpha"])
    mat.surface_render_method = "DITHERED"
    scene.eevee.taa_render_samples = 64
    objects = []
    for index in range(len(balls)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0)
        ob = bpy.context.active_object
        ob.name = f"Ball{index:02d}"
        for poly in ob.data.polygons:
            poly.use_smooth = True
        ob.data.materials.append(mat)
        ob["solid"] = 1.0
        objects.append(ob)
    return scene, objects


def load(path):
    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)


def blur(field, sigma):
    """A separable gaussian (numpy only)."""
    reach = max(int(sigma * 3), 1)
    kernel = np.exp(-0.5 * (np.arange(-reach, reach + 1) / sigma) ** 2)
    kernel /= kernel.sum()
    padded = np.pad(field, ((reach, reach), (0, 0)), mode="edge")
    field = sum(padded[i:i + field.shape[0]] * kernel[i] for i in range(len(kernel)))
    padded = np.pad(field, ((0, 0), (reach, reach)), mode="edge")
    return sum(padded[:, i:i + field.shape[1]] * kernel[i] for i in range(len(kernel)))


def finish(render, frame):
    """The render -> the texture's cell: half size, a softened edge, greyscale between light grey and white whatever
    the alpha (no dark fringe on a pale floor; the emitters tint it), and thinner on the last frames."""
    u = frame / (FRAMES - 1)
    lum, alpha = render[..., :3].mean(axis=2), render[..., 3]
    weight = alpha.reshape(CELL, 2, CELL, 2)
    alpha = weight.mean(axis=(1, 3))
    lum = (lum.reshape(CELL, 2, CELL, 2) * weight).sum(axis=(1, 3)) / np.maximum(weight.sum(axis=(1, 3)), 1e-6)
    solid = alpha > 0.5
    top = np.percentile(lum[solid], 98) if solid.any() else 1.0
    low = np.percentile(lum[solid], 2) if solid.any() else 0.0
    shade = np.clip((lum - low) / max(top - low, 1e-6), 0, 1)
    # the shading is spread out under the soft edge, so the edge takes the smoke's own tone
    shade = blur(np.where(solid, shade, 0.0), SHADE_SOFT) / np.maximum(blur(solid.astype(np.float32), SHADE_SOFT), 1e-4)
    soft = np.clip(blur(alpha, SOFT) * 1.08, 0, 1) * (1 - 0.45 * smooth(0.40, 1.0, u))
    grey = 0.66 + 0.34 * np.clip(shade, 0, 1)
    soft = np.where(soft > 0.02, soft, 0.0)
    grey = np.where(soft > 0, grey, 1.0)
    return np.stack([grey, grey, grey, soft], axis=2).astype(np.float32)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    balls = make_balls()
    scene, objects = build(balls)
    sheet = np.zeros((CELL * 4, CELL * 4, 4), dtype=np.float32)
    sheet[..., :3] = 1.0
    for frame in range(FRAMES):
        for ball, ob in zip(balls, objects):
            place, radius, solid = ball_state(ball, frame)
            ob.hide_render = solid < 0.02
            ob["solid"] = solid
            ob.update_tag()
            ob.location = place
            ob.scale = (max(radius, 0.001),) * 3
        scene.render.filepath = os.path.join(OUT, f"_poof_{frame:02d}.png")
        bpy.ops.render.render(write_still=True)
        cell = finish(load(scene.render.filepath), frame)
        os.remove(scene.render.filepath)
        row, column = frame // 4, frame % 4  # play order: left to right, then top to bottom
        y0 = (3 - row) * CELL  # pixel rows run bottom-up
        sheet[y0:y0 + CELL, column * CELL:(column + 1) * CELL] = cell
    border = 6  # a clear border in every cell, whatever the softening left there
    for row in range(4):
        for column in range(4):
            cell = sheet[row * CELL:(row + 1) * CELL, column * CELL:(column + 1) * CELL]
            for edge in (cell[:border], cell[-border:], cell[:, :border], cell[:, -border:]):
                edge[..., 3] = 0.0
    image = bpy.data.images.new("sheet", CELL * 4, CELL * 4, alpha=True)
    image.alpha_mode = "STRAIGHT"
    image.pixels.foreach_set(sheet.ravel())
    image.filepath_raw = os.path.join(OUT, "smoke_poof.png")
    image.file_format = "PNG"
    image.save()
    print("SHEET", image.filepath_raw)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "smoke_poof.blend"))
