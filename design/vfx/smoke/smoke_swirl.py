"""Flat 2D swirl puff (a new texture for ground dust), built and rendered in Blender with METABALLS.

  blender.exe -b --factory-startup --python-exit-code 1 --python design/vfx/smoke/smoke_swirl.py

The owner's pick (2026-11-22, "i think i prefer this animation"): the green-screen puff that rises off the ground as
a curling wisp, swells into a swirl, splits into nine beans and shrinks to dots that drift outward. Nothing fades.
Measured in design/vfx/smoke-study/refs-2026-11-22 (measure_puffA.py): 23 drawings over 0.93 s; the 16 used here
are video frames 4 7 8 10 12 15 17 19 (growing) and 20 22 23 24 25 27 28 30 (breaking up).

How it is made: nine beans, each three metaballs in a short bent row. Metaballs melt into each other when close and
pinch apart when they separate, which is this puff's whole look. Growing: the beans sit on a spiral from the foot,
up the right side, over the top and down the left to a curl in the middle; the spiral is squashed small at first
and more of it appears as it grows (the tip grows out of the bean before it). Breaking up: every bean follows the
path and the shrinking measured from the reference. The shapes themselves are generated, not traced.

1 unit = 100 px of the reference; the origin is the burst point on the ground.
Writes out/smoke_swirl.png (1024 x 1024, 4 x 4, white with the shape in the alpha), out/swirl_cells/c_NN.png and
smoke_swirl.blend (16 frames, one metaball object per frame).
"""
import math
import os
import random

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
CELLS_DIR = os.path.join(OUT, "swirl_cells")
CELL, FRAMES = 256, 16
ORTHO = 6.8                  # the cell's side in units: the biggest drawing spans about 73 % of it
CAMERA = (0.34, 2.57)        # the cell's middle (x, height above the ground)
MIDDLE = (0.30, 2.45)        # the beans ring round this point
SEEN = 0.575                 # a lone metaball's surface sits at this share of its radius (stiffness 2, threshold 0.6)


def unit(x, y):
    return ((x - 270) / 100, (540 - y) / 100)


# The nine beans while breaking up, drawings 8-15: where each is (reference px) and its size (px of area).
TRACKS = {
    "left":        [(126, 299), (111, 274), (104, 227), (87, 208), (79, 188), (74, 178), (72, 166), (62, 157)],
    "upper_right": [(406, 187), (421, 175), (439, 156), (456, 143), (467, 132), (475, 124), (481, 120), (490, 114)],
    "right":       [(482, 312), (501, 294), (519, 275), (527, 263), (535, 260), (544, 254), (549, 250), (557, 247)],
    "top":         [(215, 98), (211, 77), (199, 63), (188, 53), (183, 42), (176, 34), (173, 27), (163, 18)],
    "lower_right": [(446, 455), (456, 473), (477, 474), (489, 477), (501, 481), (510, 483), (515, 485), (524, 489)],
    "lower_left":  [(111, 469), (100, 453), (90, 438), (82, 428), (78, 415), (71, 408), (70, 402), (64, 394)],
    "inner":       [(240, 221), (255, 202), (258, 187), (261, 178), (264, 170), (268, 165), (271, 162), (276, 156)],
    "bottom":      [(279, 471), (286, 465), (279, 453), (275, 446), (277, 437), (276, 430), (273, 423), (272, 416)],
    "centre":      [(301, 352), (314, 345), (319, 335), (321, 327), (323, 319), (325, 312), (326, 305), (326, 297)],
}
AREAS = {
    "left":        [19001, 17985, 8861, 4699, 2039, 1089, 365, 54],
    "upper_right": [11475, 8008, 5870, 3089, 1471, 595, 306, 51],
    "right":       [11139, 8598, 3888, 2024, 1112, 349, 170, 10],
    "top":         [10817, 9452, 4545, 3793, 1725, 752, 345, 44],
    "lower_right": [7460, 5950, 3591, 2821, 1143, 417, 254, 22],
    "lower_left":  [7394, 6375, 3273, 2291, 846, 340, 139, 8],
    "inner":       [3289, 2504, 1404, 851, 408, 181, 109, 12],
    "bottom":      [2649, 2064, 1149, 856, 509, 288, 129, 16],
    "centre":      [2108, 1846, 1217, 765, 464, 263, 122, 19],
}
# The spiral the puff grows along: the foot, up the right side, over the top, down the left, the curl in the middle.
SPINE = ["lower_left", "bottom", "lower_right", "right", "upper_right", "top", "left", "centre", "inner"]
# The last two beans close the middle of the swirl (one solid mass at its biggest): bigger than at the split.
GROW_SIZE = {"centre": 1.9, "inner": 2.0}
# Growing, drawings 0-7 (the reference's outline as shares of its biggest): width, height, how much of the spiral
# there is yet, and how fat the beans are against their size at the split (fat = melted into one mass).
GROW_X = [0.17, 0.32, 0.39, 0.55, 0.62, 0.74, 0.80, 1.00]
GROW_Z = [0.24, 0.42, 0.44, 0.48, 0.52, 0.81, 0.94, 1.00]
REVEAL = [0.34, 0.50, 0.67, 0.72, 0.78, 0.90, 0.97, 1.00]
FAT = [1.30, 1.14, 1.12, 1.14, 1.12, 1.04, 1.00, 0.92]
# While it grows the puff is ONE band along the spiral: these pairs of beans are bridged by extra balls. At its
# biggest (drawing 7) two bridges have already let go, so it is three masses about to split (as the reference).
LINKS = [("lower_left", "bottom"), ("bottom", "lower_right"), ("lower_right", "right"), ("right", "upper_right"),
         ("upper_right", "top"), ("top", "left"), ("left", "centre"), ("centre", "inner")]
# ... and once the middle closes (drawings 6 and 7) the curl's bean is joined to everything round it
LATE_LINKS = [("top", "inner"), ("left", "inner"), ("upper_right", "inner"), ("centre", "upper_right")]
LET_GO = {7: {("bottom", "lower_right"), ("right", "upper_right")}}
BRIDGE = 0.80    # a bridge ball's size against the smaller of the two beans it joins
PULL_IN = 0.07   # at its biggest the puff is the split layout drawn in a little, the beans fat enough to touch
STRETCH = [0.60] * 8 + [0.80, 0.68, 0.48, 0.34, 0.22, 0.12, 0.06, 0.0]  # how long a bean is; dots are round
BEND = 0.30      # the middle ball sits this far out (share of the seen radius): a kidney, not a sausage
SIZE = 1.00      # every bean's size while breaking up, against the measured area (tuned by compare_swirl.py)


def bean(name, x, z, radius, stretch, rng):
    """Three balls in a bent row across the line to the middle: [(x, z, seen radius)]."""
    ox, oz = x - MIDDLE[0], z - MIDDLE[1]
    away = math.hypot(ox, oz) or 1.0
    ox, oz = ox / away, oz / away
    ax, az = -oz, ox  # along the ring
    seen = radius * math.sqrt(math.pi / (math.pi + 4 * stretch))  # the same area whatever the stretch
    reach = stretch * seen
    balls = []
    for step, out in ((-1, 0.0), (0, BEND * stretch / 0.6), (1, 0.0)):
        wobble = rng.uniform(0.94, 1.06)  # the boil
        balls.append((x + ax * reach * step + ox * out * seen, z + az * reach * step + oz * out * seen,
                      seen * wobble * (0.92 if step else 1.0)))
    return balls


def drawing(frame):
    """Every ball of one drawing: [(x, z, seen radius)]."""
    rng = random.Random(500 + frame)
    balls = []
    if frame >= 8:
        step = frame - 8
        for name in SPINE:
            x, z = unit(*TRACKS[name][step])
            radius = math.sqrt(AREAS[name][step] / math.pi) / 100 * SIZE
            balls.extend(bean(name, x, z, radius, STRETCH[frame], rng))
        return balls
    shown = REVEAL[frame] * len(SPINE)
    last = None
    placed = {}
    for order, name in enumerate(SPINE):
        whole = min(max(shown - order, 0.0), 1.0)
        x, z = unit(*TRACKS[name][0])
        x, z = x + (MIDDLE[0] - x) * PULL_IN, z + (MIDDLE[1] - z) * PULL_IN
        peak = (x, z)
        if whole <= 0:
            break
        if whole < 1 and last:  # the tip grows out of the bean before it
            x, z = last[0] + (x - last[0]) * (0.45 + 0.55 * whole), last[1] + (z - last[1]) * (0.45 + 0.55 * whole)
        radius = math.sqrt(AREAS[name][0] / math.pi) / 100 * FAT[frame] * (0.40 + 0.60 * whole) * GROW_SIZE.get(name, 1.0)
        scale = math.sqrt(GROW_X[frame] * GROW_Z[frame])
        balls.extend(bean(name, x * GROW_X[frame], z * GROW_Z[frame], radius * scale, STRETCH[frame], rng))
        placed[name] = (x * GROW_X[frame], z * GROW_Z[frame], radius * scale)
        last = peak
    for a, b in LINKS + (LATE_LINKS if frame >= 6 else []):
        if a in placed and b in placed and (a, b) not in LET_GO.get(frame, ()):
            (ax, az, ar), (bx, bz, br) = placed[a], placed[b]
            for share in (0.25, 0.5, 0.75):
                balls.append((ax + (bx - ax) * share, az + (bz - az) * share, BRIDGE * min(ar, br) * rng.uniform(0.94, 1.06)))
    return balls


# The drawn gaps in the growing mass (holdout shapes in front of it), in the coordinates of the biggest drawing:
# name -> (points along the gap, its width at each point). They are squashed with the puff as it grows.
STROKES = {
    # the notch that comes in from the left between the head and the foot: wide open early (the wisp is a "Z")
    "notch": ([(-2.9, 1.25), (-1.7, 1.42), (-0.7, 1.34), (0.15, 1.14), (0.80, 1.22)], [0.36, 0.26, 0.20, 0.14, 0.0]),
    # at its biggest the right lobe has let go: one gap from the ground up and out to the right
    "split": ([(0.98, -0.3), (0.97, 0.55), (0.86, 1.25), (1.12, 2.05), (1.45, 2.72), (2.2, 2.98), (3.1, 2.9)],
              [0.14, 0.13, 0.12, 0.12, 0.13, 0.15, 0.20]),
    # the curl: a spiral gap that winds in round the inner bean and ends in an eye
    "curl": ([(0.80, 3.00), (0.62, 3.70), (-0.15, 3.98), (-0.85, 3.66), (-0.98, 3.05), (-0.50, 2.68), (0.05, 2.82),
              (0.12, 3.18), (-0.18, 3.28)], [0.0, 0.13, 0.16, 0.16, 0.15, 0.14, 0.13, 0.12, 0.12]),
}
# drawing -> {name: (how wide against the table, how much of its length is there yet)}
STROKE_ON = {
    1: {"notch": (2.2, 1.0)}, 2: {"notch": (2.0, 1.0)}, 3: {"notch": (1.8, 1.0)}, 4: {"notch": (1.6, 1.0)},
    5: {"notch": (1.7, 1.0)}, 6: {"notch": (1.6, 1.0), "curl": (0.8, 0.6)},
    7: {"notch": (1.5, 1.0), "curl": (1.0, 1.0), "split": (1.0, 1.0)},
}
EYE = 0.14  # the round end of the curl


def stroke(points, widths, reach, wide, frame):
    """A smooth tapered band along the points (a Catmull-Rom curve), as one polygon [(x, z)]."""
    line = []
    count = len(points)
    for k in range(count - 1):
        p0, p1, p2, p3 = points[max(k - 1, 0)], points[k], points[k + 1], points[min(k + 2, count - 1)]
        for step in range(8):
            t = step / 8
            if (k + t) / (count - 1) > reach:
                break
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t * t
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t ** 3)
            z = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t * t
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t ** 3)
            line.append((x, z, (widths[k] + (widths[k + 1] - widths[k]) * t) * wide))
    if reach >= 1:
        line.append((points[-1][0], points[-1][1], widths[-1] * wide))
    gx, gz = GROW_X[frame], GROW_Z[frame]
    thin = math.sqrt(gx * gz)
    line = [(x * gx, z * gz, w * thin) for x, z, w in line]
    left, right = [], []
    for k, (x, z, w) in enumerate(line):
        x0, z0, _ = line[max(k - 1, 0)]
        x1, z1, _ = line[min(k + 1, len(line) - 1)]
        length = math.hypot(x1 - x0, z1 - z0) or 1e-9
        nx, nz = -(z1 - z0) / length, (x1 - x0) / length
        left.append((x + nx * w / 2, z + nz * w / 2))
        right.append((x - nx * w / 2, z - nz * w / 2))
    return left + right[::-1], line[-1]


def gaps(frame):
    """The holdout polygons of one drawing."""
    out = []
    for name, (wide, reach) in STROKE_ON.get(frame, {}).items():
        points, widths = STROKES[name]
        polygon, (x, z, w) = stroke(points, widths, reach, wide, frame)
        out.append(polygon)
        if name == "curl" and reach >= 1:
            eye = EYE * wide * math.sqrt(GROW_X[frame] * GROW_Z[frame])
            out.append([(x + eye * math.cos(a * math.tau / 16), z + eye * math.sin(a * math.tau / 16)) for a in range(16)])
    return out


# ------------------------------------------------------------------------------------------------- Blender
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"  # flat white must come out as written
    scene.view_settings.look = "None"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x = scene.render.resolution_y = CELL
    scene.render.resolution_percentage = 100
    scene.render.filter_size = 1.0  # a crisp drawn edge
    scene.eevee.taa_render_samples = 64
    scene.frame_start, scene.frame_end = 0, FRAMES - 1
    scene.render.fps = 24
    camera_data = bpy.data.cameras.new("Cam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = ORTHO
    camera = bpy.data.objects.new("Cam", camera_data)
    camera.location = (CAMERA[0], -20, CAMERA[1])
    camera.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return scene


def material(name, holdout):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    if holdout:
        shader = nodes.new("ShaderNodeHoldout")
    else:
        shader = nodes.new("ShaderNodeEmission")
        shader.inputs[0].default_value = (1, 1, 1, 1)
    mat.node_tree.links.new(shader.outputs[0], out.inputs[0])
    return mat


def show_on(ob, frame):
    """Seen on its own frame only, so the .blend scrubs as the 16 drawings."""
    for at, hidden in ((frame - 1, True), (frame, False), (frame + 1, True)):
        ob.hide_render = ob.hide_viewport = hidden
        ob.keyframe_insert("hide_render", frame=at)
        ob.keyframe_insert("hide_viewport", frame=at)


def puff_object(scene, frame, balls, mat):
    # every drawing is its own metaball family (the name before any ".001"): families never melt into each other
    meta = bpy.data.metaballs.new(f"Draw{frame:02d}Puff")
    meta.resolution = 0.03
    meta.render_resolution = 0.012
    meta.threshold = 0.6
    for x, z, seen in balls:
        if seen < 0.012:
            continue
        element = meta.elements.new(type="BALL")
        element.co = (x, 0.0, z)
        element.radius = seen / SEEN
    meta.materials.append(mat)
    ob = bpy.data.objects.new(f"Draw{frame:02d}Puff", meta)
    scene.collection.objects.link(ob)
    show_on(ob, frame)
    return ob


def gaps_object(scene, frame, polygons, mat):
    if not polygons:
        return
    verts, faces = [], []
    for polygon in polygons:
        start = len(verts)
        verts.extend((x, -5.0, z) for x, z in polygon)  # in front of the puff
        faces.append(list(range(start, start + len(polygon))))
    mesh = bpy.data.meshes.new(f"Draw{frame:02d}Gaps")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(f"Draw{frame:02d}Gaps", mesh)
    scene.collection.objects.link(ob)
    show_on(ob, frame)


def ground(scene, mat):
    """Nothing shows below the ground line: the foot is cut flat."""
    mesh = bpy.data.meshes.new("Ground")
    mesh.from_pydata([(-20, -5, -10), (20, -5, -10), (20, -5, 0), (-20, -5, 0)], [], [[0, 1, 2, 3]])
    mesh.materials.append(mat)
    ob = bpy.data.objects.new("Ground", mesh)
    scene.collection.objects.link(ob)


def load_pixels(path):
    import numpy as np

    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)


if __name__ == "__main__":
    import numpy as np

    os.makedirs(CELLS_DIR, exist_ok=True)
    scene = reset()
    white, hole = material("White", False), material("Hole", True)
    ground(scene, hole)
    for frame in range(FRAMES):
        puff_object(scene, frame, drawing(frame), white)
        gaps_object(scene, frame, gaps(frame), hole)
    sheet = np.zeros((CELL * 4, CELL * 4, 4), dtype=np.float32)
    sheet[..., :3] = 1.0  # white everywhere, also where it is clear: no dark fringe when the texture is filtered
    for frame in range(FRAMES):
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(CELLS_DIR, f"c_{frame:02d}.png")
        bpy.ops.render.render(write_still=True)
        alpha = load_pixels(scene.render.filepath)[..., 3]
        row, column = frame // 4, frame % 4  # play order: left to right, then top to bottom
        y0 = (3 - row) * CELL  # pixel rows run bottom-up
        sheet[y0:y0 + CELL, column * CELL:(column + 1) * CELL, 3] = alpha
    image = bpy.data.images.new("sheet", CELL * 4, CELL * 4, alpha=True)
    image.alpha_mode = "STRAIGHT"
    image.pixels.foreach_set(sheet.ravel())
    image.filepath_raw = os.path.join(OUT, "smoke_swirl.png")
    image.file_format = "PNG"
    image.save()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "smoke_swirl.blend"))
    print(f"GROUND {CAMERA[1] / ORTHO * 100:.1f} % of the cell below its middle")
    print("SHEET", image.filepath_raw)
