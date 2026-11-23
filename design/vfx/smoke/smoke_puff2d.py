"""Flat 2D ground puff (a new texture for ground dust), built and rendered in Blender.

  blender.exe -b --factory-startup --python-exit-code 1 --python design/vfx/smoke/smoke_puff2d.py

The owner's reference (2026-11-22): the green-screen puff, measured in design/vfx/smoke-study/refs-2026-11-22
(measure_puffB.py): 16 drawings over 0.67 s. One flat white shape with a flat bottom on the ground: it pops to
about 3/4 of its size in three drawings, keeps swelling slowly, and dies by HOLES: gaps open inside its cells and
grow until only the cell walls are left as thin lines, which break into strokes and are gone. Nothing fades.

The layout of the cells is my own (the reference is a paid template: its style and timing are copied, its drawing
is not traced). The puff is a dome cut into cells (a weighted Voronoi split of the dome). White = every cell, its
outer edge bowed out into a lobe. Holes = every cell again, inset by the wall's half thickness, as HOLDOUT shapes
in front of the white. Shrinking the inset opens the holes; at the end whole walls go, one after another.

Writes out/smoke_puff2d.png (1024 x 1024, 4 x 4, white with the shape in the alpha), out/puff2d_cells/c_NN.png and
smoke_puff2d.blend (16 frames, one white and one holes object per frame).
"""
import math
import os
import random

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
CELLS_DIR = os.path.join(OUT, "puff2d_cells")
CELL, FRAMES = 256, 16
FILL = 0.75  # the widest frame spans this share of the cell
CAMERA_Z = 0.70  # the cell's middle sits this far above the ground line (scene units)

# The dome, counter-clockwise from the ground's left end. 2 wide, 1.25 tall, lower on the left, its top right of
# the middle and a fuller right side (as the reference). The first edge is the GROUND.
DOME = [(-1.0, 0.0), (1.0, 0.0), (1.05, 0.35), (0.98, 0.75), (0.72, 1.08), (0.36, 1.24), (-0.05, 1.22),
        (-0.45, 1.08), (-0.78, 0.82), (-0.97, 0.50), (-1.03, 0.22)]

# The cells: (x, y, weight, bump). Laid out on purpose: four big, the rest small, slivers along the ground, no two
# alike. bump = how far the cell's outer edge bows out, as a share of its length (the cauliflower lobes).
SEEDS = [
    (-0.60, 0.46, 0.085, 0.26),   # big, left
    (0.14, 0.96, 0.080, 0.12),    # big, top
    (0.62, 0.58, 0.070, 0.27),    # big, right
    (-0.02, 0.42, 0.075, 0.00),   # big, low middle
    (-0.24, 0.80, -0.030, 0.22),  # small, between left and top
    (0.62, 1.02, -0.035, 0.30),   # small, top right
    (0.30, 0.62, -0.040, 0.00),   # small, middle
    (0.46, 0.20, -0.010, 0.00),   # lower right
    (0.90, 0.18, -0.020, 0.34),   # right corner
    (-0.40, 0.07, -0.030, 0.00),  # ground sliver, left
    (0.10, 0.05, -0.040, 0.00),   # ground sliver, middle
    (-0.88, 0.12, -0.030, 0.30),  # left corner
    (-0.50, 0.90, -0.020, 0.27),  # top left
    (-0.30, 0.22, -0.045, 0.00),  # small, low left
]
# How much later (plus) or earlier (minus) each cell's hole opens, as extra inset. The big cells open first.
STAGGER = [-0.010, 0.000, -0.006, 0.006, 0.012, 0.018, 0.008, 0.006, 0.014, 0.002, 0.006, 0.018, 0.012, 0.014]

# Per drawing. The reference's numbers: width and height as shares of the final size, and the holes' share of the
# filled shape. Drawings 0-3 are the pop.
SCALE_X = [0.134, 0.20, 0.35, 0.73, 0.78, 0.82, 0.85, 0.89, 0.93, 0.97, 0.99, 0.99, 1.0, 1.0, 1.0, 1.0]
SCALE_Y = [0.065, 0.24, 0.45, 0.79, 0.83, 0.86, 0.89, 0.92, 0.94, 0.97, 1.00, 1.00, 1.0, 1.0, 1.0, 1.0]
HOLES = [0.0, 0.02, 0.05, 0.156, 0.234, 0.315, 0.42, 0.55, 0.63, 0.71, 0.80]  # drawings 0-10: solved for
# early on only the big cells have holes (the stagger counts for more), and the holes are lopsided
SPREAD = [0, 5.0, 4.0, 2.4, 1.8, 1.4, 1.1, 1.0, 1.0, 1.0, 1.0]
LEANS = [0, 0.80, 0.80, 0.80, 0.75, 0.65, 0.55, 0.42, 0.30, 0.18, 0.08]
# drawings 11-15, the lines: (the line's half width, the share of the walls already gone, wobble). A wall goes as a
# WHOLE (both its sides at once), so what is left is thin strokes with free ends, never pointed corner bits.
LINES = {11: (0.0105, 0.00, 0.003), 12: (0.0085, 0.00, 0.004), 13: (0.0065, 0.12, 0.005), 14: (0.0050, 0.40, 0.005),
         15: (0.0040, 0.75, 0.004)}
# ... and every line breaks into dashes: two gaps per line that grow. The share of each line that is gap:
GAPS = {12: 0.18, 13: 0.50, 14: 0.74, 15: 0.90}
LIFT = {11: 0.03, 12: 0.07, 13: 0.11, 14: 0.20, 15: 0.26}  # the dying lines lift off the ground (share of the height)
ROUNDS = [3, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 0, 0, 0, 0, 0]  # the holes' corners sharpen as the walls thin to lines
ANCHOR_X = -0.40  # the burst starts left of the middle and billows up and to the right
RIM_MIN = 0.011   # the outer line never thinner than this until the walls break
ARC = 10          # points along a lobe
WARP = 0.022      # how far the wave field bends the drawing (scene units)
# Bits thrown off at the left foot during the pop: drawing -> [(x, y, radius)]
BITS = {
    3: [(-0.96, 0.07, 0.040), (-1.03, 0.19, 0.028), (-0.93, 0.27, 0.020)],
    4: [(-1.03, 0.08, 0.030), (-1.10, 0.22, 0.020), (-1.00, 0.31, 0.012)],
    5: [(-1.09, 0.09, 0.018), (-1.16, 0.24, 0.011)],
}
_fixed = random.Random(77)
# every wall (a pair of cells), every cell's outer edge and ground edge: when it goes, 0 = first, 1 = last
GOES = {}
for _i in range(len(SEEDS)):
    GOES[("rim", _i)] = _fixed.random()
    GOES[("ground", _i)] = _fixed.random() * 0.6  # the foot clears early: the puff lifts off
    for _j in range(_i + 1, len(SEEDS)):
        GOES[("wall", _i, _j)] = _fixed.random()
# each side of each cell: how lopsided its early hole is (-1 to 1), so the holes are not shrunken copies of the cell
LEAN = {(_i, _k): _fixed.uniform(-1, 1) for _i in range(len(SEEDS)) for _k in range(-len(DOME), len(SEEDS))}


# ------------------------------------------------------------------------------------------------- 2D geometry
def planes_of(index):
    """Half planes (nx, ny, d, key): the cell is where n.p <= d for all of them. key = ("rim" or "ground", dome
    edge) or ("wall", the other cell)."""
    planes = []
    for k in range(len(DOME)):
        (ax, ay), (bx, by) = DOME[k], DOME[(k + 1) % len(DOME)]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy)
        nx, ny = dy / length, -dx / length  # outward, for a counter-clockwise outline
        planes.append((nx, ny, nx * ax + ny * ay, ("ground" if k == 0 else "rim", k)))
    cx, cy, cw, _ = SEEDS[index]
    for other, (ox, oy, ow, _) in enumerate(SEEDS):
        if other == index:
            continue
        nx, ny = 2 * (ox - cx), 2 * (oy - cy)
        d = ox * ox + oy * oy - cx * cx - cy * cy + cw - ow
        length = math.hypot(nx, ny)
        planes.append((nx / length, ny / length, d / length, ("wall", other)))
    return planes


def clip(points, plane):
    """Sutherland-Hodgman against one half plane. points: [(x, y, key of the edge that leaves this point)]."""
    nx, ny, d, key = plane
    out = []
    count = len(points)
    for i in range(count):
        x0, y0, t0 = points[i]
        x1, y1, _ = points[(i + 1) % count]
        s0, s1 = nx * x0 + ny * y0 - d, nx * x1 + ny * y1 - d
        if s0 <= 0:
            out.append((x0, y0, t0))
            if s1 > 0:
                u = s0 / (s0 - s1)
                out.append((x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, key))
        elif s1 <= 0:
            u = s0 / (s0 - s1)
            out.append((x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, t0))
    return out


def no_inset(key):
    return 0.0


def cell_polygon(index, inset=no_inset):
    points = [(-4, -4, ("box",)), (4, -4, ("box",)), (4, 4, ("box",)), (-4, 4, ("box",))]
    for nx, ny, d, key in PLANES[index]:
        points = clip(points, (nx, ny, d - inset(key), key))
        if len(points) < 3:
            return []
    clean = []
    for p in points:  # drop doubled corners
        q = clean[-1] if clean else points[-1]
        if math.hypot(p[0] - q[0], p[1] - q[1]) > 1e-5:
            clean.append(p)
    return clean if len(clean) >= 3 else []


def area(points):
    return 0.5 * sum(points[i][0] * points[(i + 1) % len(points)][1] - points[(i + 1) % len(points)][0] * points[i][1]
                     for i in range(len(points)))


def bumped(points, bump):
    """Swaps the cell's outer edge (its run of rim edges) for one arc bowed outward: the cauliflower lobe. The two
    ends of the run stay put, so neighbours meet in a notch. Returns [(x, y)]."""
    count = len(points)
    rim = [p[2][0] == "rim" for p in points]
    bumped.arc = False  # whether the outer edge became an arc (its points then come first in the result)
    if bump <= 0 or not any(rim) or all(rim):
        return [(x, y) for x, y, _ in points]
    start = next(i for i in range(count) if rim[i] and not rim[i - 1])
    run = [points[start]]
    i = start
    while rim[i % count]:
        i += 1
        run.append(points[i % count])
    rest = [points[k % count] for k in range(i + 1, start + count)]
    (x0, y0, _), (x1, y1, _) = run[0], run[-1]
    chord = math.hypot(x1 - x0, y1 - y0)
    if chord < 0.08:
        return [(x, y) for x, y, _ in points]
    nx, ny = (y1 - y0) / chord, -(x1 - x0) / chord  # outward (the polygon runs counter-clockwise)
    # walk the run by length, lifting each point by a sine of how far along it is
    lengths = [math.hypot(run[k + 1][0] - run[k][0], run[k + 1][1] - run[k][1]) for k in range(len(run) - 1)]
    total = sum(lengths)
    arc = []
    for step in range(ARC + 1):
        want = total * step / ARC
        k = 0
        while k < len(lengths) - 1 and want > lengths[k]:
            want -= lengths[k]
            k += 1
        u = want / lengths[k] if lengths[k] else 0.0
        x = run[k][0] + (run[k + 1][0] - run[k][0]) * u
        y = run[k][1] + (run[k + 1][1] - run[k][1]) * u
        lift = bump * chord * math.sin(math.pi * step / ARC) ** 0.75
        arc.append((x + nx * lift, y + ny * lift))
    bumped.arc = True
    return arc + [(x, y) for x, y, _ in rest]


def rounded(points, rounds=3):
    """Chaikin corner cutting. points: [(x, y)]."""
    for _ in range(rounds):
        out = []
        count = len(points)
        for i in range(count):
            x0, y0 = points[i]
            x1, y1 = points[(i + 1) % count]
            out.append((0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1))
            out.append((0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1))
        points = out
    return points


def warped(points, frame):
    """Bends everything with one slow wave field, so the walls are drawn curves, not ruled lines. Both sides of a
    wall move together (the field is far wider than a wall), so a line keeps its width. The ground stays flat, and
    the field shifts a little every drawing (the boil)."""
    out = []
    count = len(points)
    shift = 0.45 * frame
    for i in range(count):
        x0, y0 = points[i]
        x1, y1 = points[(i + 1) % count]
        steps = max(1, int(math.hypot(x1 - x0, y1 - y0) / 0.04))
        for step in range(steps):
            x, y = x0 + (x1 - x0) * step / steps, y0 + (y1 - y0) * step / steps
            hold = min(max(y / 0.18, 0.0), 1.0)  # nothing moves on the ground line
            dx = WARP * (math.sin(5.3 * x + 3.1 * y + 0.6 + shift) + 0.6 * math.sin(9.7 * y - 4.1 * x + 2.3 - shift))
            dy = WARP * (math.sin(4.7 * y - 3.7 * x + 4.0 - shift) + 0.6 * math.sin(10.3 * x + 3.3 * y + 1.1 + shift))
            out.append((x + dx * hold, y + dy * hold * hold))
    return out


def strip(line, a, b, half=0.03):
    """A band round the stretch a-b (0-1 of its length) of a line [(x, y)]: a gap, once it is a holdout."""
    lengths = [math.hypot(line[k + 1][0] - line[k][0], line[k + 1][1] - line[k][1]) for k in range(len(line) - 1)]
    total = sum(lengths) or 1e-9

    def at(u):
        want = total * u
        k = 0
        while k < len(lengths) - 1 and want > lengths[k]:
            want -= lengths[k]
            k += 1
        t = want / lengths[k] if lengths[k] else 0.0
        return (line[k][0] + (line[k + 1][0] - line[k][0]) * t, line[k][1] + (line[k + 1][1] - line[k][1]) * t)

    points = [at(a)]
    run = 0.0
    for k in range(1, len(line) - 1):
        run += lengths[k - 1]
        if a < run / total < b:
            points.append(line[k])
    points.append(at(b))
    left, right = [], []
    for k, (x, y) in enumerate(points):
        x0, y0 = points[max(k - 1, 0)]
        x1, y1 = points[min(k + 1, len(points) - 1)]
        length = math.hypot(x1 - x0, y1 - y0) or 1e-9
        nx, ny = -(y1 - y0) / length, (x1 - x0) / length
        left.append((x + nx * half, y + ny * half))
        right.append((x - nx * half, y - ny * half))
    return left + right[::-1]


def gaps(frame, bumps):
    """The gaps in every wall, outer edge and ground edge on a drawing of the line stage."""
    share = GAPS.get(frame, 0.0)
    out = []
    if share <= 0:
        return out
    for index in range(len(SEEDS)):
        points = cell_polygon(index)
        polygon = bumped(points, bumps[index])
        lines = [(("rim", index), polygon[:ARC + 1])] if bumped.arc else []
        count = len(points)
        for i in range(count):
            x0, y0, key = points[i]
            x1, y1, _ = points[(i + 1) % count]
            if key[0] == "wall" and index < key[1]:
                lines.append((("wall", index, key[1]), [(x0, y0), (x1, y1)]))
            elif key[0] == "ground" or (key[0] == "rim" and not bumped.arc):
                lines.append(((key[0], index, i), [(x0, y0), (x1, y1)]))
        for name, line in lines:
            fixed = random.Random(repr(name))  # the same gaps on every drawing: they only grow
            gap = min(0.96, share * fixed.uniform(0.7, 1.3))
            # one long gap and one short, anywhere along the line, and a line in three opens only one at first:
            # evenly cut lines read as a ruled dashed line, not as a drawing wearing away
            big = fixed.uniform(0.55, 0.85)
            centres = (fixed.uniform(0.12, 0.46), fixed.uniform(0.54, 0.88))
            late = fixed.random() < 0.34
            for centre, part in zip(centres, (big, 1 - big)):
                if late and part < 0.5 and frame == 12:
                    continue
                out.append(strip(line, max(0.0, centre - gap * part / 2), min(1.0, centre + gap * part / 2)))
    return out


def early_inset(index, base, lean):
    """The inset of each side of a cell's hole while the holes are opening (drawings 1-10)."""
    def inset(key):
        side = base * max(0.25, 1 + lean * LEAN[(index, key[1] if key[0] == "wall" else -key[1] - 1)])
        if key[0] == "ground":
            return side * 0.6  # a thin foot: the slivers along the ground open with the rest
        return max(side, RIM_MIN) if key[0] == "rim" else side
    return inset


def cell_base(index, base, spread):
    """A cell's inset: in step with the cell's size (a small cell gets a small hole early, not none until late),
    plus its own delay."""
    return base * (0.30 + 0.70 * SIZE[index]) + STAGGER[index] * spread


def white_inset(key):
    return -0.012 if key[0] == "wall" else 0.0  # neighbours overlap a little: no seams inside the white


def hole_share(inset, spread, lean):
    total = 0.0
    for i in range(len(SEEDS)):
        polygon = cell_polygon(i, early_inset(i, cell_base(i, inset, spread), lean))
        total += max(area(polygon), 0.0) if polygon else 0.0
    return total / WHOLE


def solve_inset(share, spread, lean):
    low, high = 0.0, 0.6  # a bigger inset means smaller holes
    for _ in range(40):
        middle = (low + high) / 2
        if hole_share(middle, spread, lean) > share:
            low = middle
        else:
            high = middle
    return (low + high) / 2


PLANES = [planes_of(i) for i in range(len(SEEDS))]
WHOLE = sum(area(cell_polygon(i)) for i in range(len(SEEDS)))
_areas = [area(cell_polygon(i)) for i in range(len(SEEDS))]
SIZE = [math.sqrt(a / max(_areas)) for a in _areas]
INSETS = [None] + [solve_inset(HOLES[k], SPREAD[k], LEANS[k]) for k in range(1, len(HOLES))]


def place(points, frame):
    """The pop (a squash about the burst point on the ground) and the lift at the end."""
    lift = LIFT.get(frame, 0.0) * 1.25
    return [(ANCHOR_X + (x - ANCHOR_X) * SCALE_X[frame], y * SCALE_Y[frame] + lift) for x, y in points]


def line_inset(index, half, gone):
    def inset(key):
        name = ("wall", min(index, key[1]), max(index, key[1])) if key[0] == "wall" else (key[0], index)
        return -0.014 if GOES[name] < gone else half
    return inset


def drawing(frame):
    """(white polygons, hole polygons) of one drawing, as lists of [(x, y)]."""
    rng = random.Random(1000 + frame)
    whites, holes = [], []
    bumps = [SEEDS[index][3] * rng.uniform(0.85, 1.15) for index in range(len(SEEDS))]  # the lobes breathe
    for index in range(len(SEEDS)):
        bump = bumps[index]
        whites.append(place(warped(bumped(cell_polygon(index, white_inset), bump), frame), frame))
        if frame == 0:
            continue
        if frame in LINES:
            half, gone, wobble = LINES[frame]
            inset = line_inset(index, half, gone)
        else:
            base = cell_base(index, INSETS[frame], SPREAD[frame])
            inset = early_inset(index, base, LEANS[frame])
            wobble = min(0.030, 0.30 * base + 0.003)
        polygon = cell_polygon(index, inset)
        if not polygon or area(polygon) < 0.0006:
            continue
        soft = [(x + rng.uniform(-wobble, wobble), y + rng.uniform(-wobble, wobble))
                for x, y in bumped(polygon, bump)]
        holes.append(place(warped(rounded(soft, ROUNDS[frame]), frame), frame))
    holes.extend(place(warped(gap, frame), frame) for gap in gaps(frame, bumps))
    for x, y, radius in BITS.get(frame, []):
        whites.append([(x + radius * math.cos(a * math.tau / 14), y + radius * 0.8 * math.sin(a * math.tau / 14))
                       for a in range(14)])
    return whites, holes


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
    camera_data.ortho_scale = WIDTH / FILL
    camera = bpy.data.objects.new("Cam", camera_data)
    camera.location = (CENTRE_X, -10, CAMERA_Z)
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


def flat_object(scene, name, polygons, depth, mat, frame):
    verts, faces = [], []
    for polygon in polygons:
        start = len(verts)
        verts.extend((x, depth, y) for x, y in polygon)
        faces.append(list(range(start, start + len(polygon))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    # seen on its own frame only, so the .blend scrubs as the 16 drawings
    for at, hidden in ((frame - 1, True), (frame, False), (frame + 1, True)):
        ob.hide_render = ob.hide_viewport = hidden
        ob.keyframe_insert("hide_render", frame=at)
        ob.keyframe_insert("hide_viewport", frame=at)
    return ob


def load_pixels(path):
    import numpy as np

    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)


DRAWINGS = [drawing(frame) for frame in range(FRAMES)]
_xs = [x for whites, _ in DRAWINGS[:12] for polygon in whites[:len(SEEDS)] for x, _ in polygon]  # not the thrown bits
WIDTH, CENTRE_X = max(_xs) - min(_xs), (max(_xs) + min(_xs)) / 2

if __name__ == "__main__":
    import numpy as np

    os.makedirs(CELLS_DIR, exist_ok=True)
    scene = reset()
    white, hole = material("White", False), material("Hole", True)
    for frame, (whites, holes) in enumerate(DRAWINGS):
        flat_object(scene, f"White_{frame:02d}", whites, 0.0, white, frame)
        if holes:
            flat_object(scene, f"Holes_{frame:02d}", holes, -0.1, hole, frame)  # in front of the white
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
    image.filepath_raw = os.path.join(OUT, "smoke_puff2d.png")
    image.file_format = "PNG"
    image.save()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "smoke_puff2d.blend"))
    print("INSETS", " ".join("-" if v is None else f"{v:.3f}" for v in INSETS))
    print(f"WIDTH {WIDTH:.3f} units, cell {WIDTH / FILL:.3f} units, ground {CAMERA_Z / (WIDTH / FILL) * 100:.1f} % of the cell below its middle")
    print("SHEET", image.filepath_raw)
