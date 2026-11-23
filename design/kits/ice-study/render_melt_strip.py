"""Melt step 1, second pass (2026-11-23): the Frostbite trail's melt as one picture sheet for the owner.
  blender -b --factory-startup --python-exit-code 1 --python render_melt_strip.py -- <out dir>

The owner so far: ONE STRIP of floor tiles along the whole dash path; the tiles "should be more random instead
of all being hexagons"; "the trail should also have some dissolving spikes on the sides" (reference A, the
spikes that turn into glowing triangles); the colour must "match the glacier so its consistent".

Reference: YouTube mOqFQpsmBeQ. A (1.8-2.8 s, sheets/melt_close_A.jpg): bright flat triangles appear on a
spike over about 0.25 s, the spike is gone, the cloud of triangles stays inside the spike's own shape and
thins out over about 0.65 s. B (5.5-7.4 s, sheets/melt_close_B.jpg): flat many-sided tiles lying over each
other, whole for 0.4 s, then each shrinks toward its own middle where it lies, over about 1.5 s.

Scene: the fighter stands at the origin at the END of the dash, facing -Y; the path lies behind them along
+Y. Frostbite covers 112 studs/s x 0.42 s = 47 studs. Nothing here is random: every shape, size and turn comes
from the piece's own number.
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_scene as S  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])   # Blender reads a bare relative path from the drive's root
os.makedirs(OUT, exist_ok=True)
KIT = os.path.join(HERE, "..", "out", "export", "ice_kit_v4.glb")   # the Glacier's own pieces and textures

# The Glacier's colours (bake_frost2.py): mostly light blue, white frost on about a fifth, glowing frost.
CLEAR_A, CLEAR_B, FROST = (150, 204, 240), (188, 227, 247), (246, 252, 255)
GLOW_TINT = (200, 235, 255)

PATH = 47.0            # studs the dash covers
DASH = 0.42            # seconds the dash takes
ACROSS = 2.2           # studs between tile columns
STEP = ACROSS * 0.866  # studs between tile rows along the path
THICK = 0.1            # studs a tile stands over the floor. FLAT: "by thicker i dont mean vertically thick" (the owner)
COLUMNS = (-2, -1, 0, 1, 2)   # five columns, about 11 studs. Seven was tried and was NOT wanted: "you didnt need to make
                       # the trail wider horizontally ... my talk about the fullness was just about the apparent gaps"
LANE = 2.4             # studs to each side of the path's middle that stay clear of crystals: where the body went
TILE_WAIT = 0.1        # seconds between a spot's crystals being gone and its tiles starting to shrink: the owner,
                       # "the crystals should dissolve before the ice melts"
TILE_SHRINK = 1.5      # seconds a tile takes to shrink away (the reference)
SPIKE_HOLD = 0.5       # seconds a spike stands before it dissolves (today's trail crystals)
SPIKE_TURN = 0.25      # seconds the triangles take to cover a spike (the reference)
SPIKE_THIN = 0.65      # seconds the cloud of triangles takes to thin out (the reference)
SIDES = (4, 5, 5, 6, 6, 7)   # the six tile shapes: how many sides each has


def frac(v):
    return v - math.floor(v)


def rnd(a, b):
    """A fixed number 0-1 for the pair (a, b): the same every run."""
    return frac(math.sin(a * 12.9898 + b * 78.233) * 43758.5453)


# ---------------------------------------------------------------------------------------------- materials
def ice_material():
    """The Glacier's look on a flat tile: two light blues, soft white frost patches that glow."""
    mat = bpy.data.materials.new("TileIce")
    mat.use_nodes = True
    N, L = mat.node_tree.nodes, mat.node_tree.links
    bsdf = N.get("Principled BSDF")
    geo = N.new("ShaderNodeNewGeometry")
    tone = N.new("ShaderNodeTexNoise")
    tone.inputs["Scale"].default_value = 0.6
    patches = N.new("ShaderNodeTexNoise")
    patches.inputs["Scale"].default_value = 1.1
    patches.inputs["Detail"].default_value = 4.0
    patches.inputs["Roughness"].default_value = 0.65
    L.new(geo.outputs["Position"], tone.inputs["Vector"])
    L.new(geo.outputs["Position"], patches.inputs["Vector"])
    mask = N.new("ShaderNodeValToRGB")
    mask.color_ramp.elements[0].position = 0.56
    mask.color_ramp.elements[1].position = 0.68
    L.new(patches.outputs["Fac"], mask.inputs["Fac"])
    blue = N.new("ShaderNodeMix")
    blue.data_type = "RGBA"
    blue.inputs["A"].default_value = (*S.lin(CLEAR_A), 1)
    blue.inputs["B"].default_value = (*S.lin(CLEAR_B), 1)
    L.new(tone.outputs["Fac"], blue.inputs["Factor"])
    colour = N.new("ShaderNodeMix")
    colour.data_type = "RGBA"
    colour.inputs["B"].default_value = (*S.lin(FROST), 1)
    L.new(mask.outputs["Color"], colour.inputs["Factor"])
    L.new(blue.outputs["Result"], colour.inputs["A"])
    L.new(colour.outputs["Result"], bsdf.inputs["Base Color"])
    glow = N.new("ShaderNodeMath")              # the frost glows strongly, the clear ice a little
    glow.operation = "MULTIPLY_ADD"
    glow.inputs[1].default_value = 1.0
    glow.inputs[2].default_value = 0.25
    L.new(mask.outputs["Color"], glow.inputs[0])
    bsdf.inputs["Emission Color"].default_value = (*S.lin(GLOW_TINT), 1)
    L.new(glow.outputs[0], bsdf.inputs["Emission Strength"])
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Specular IOR Level"].default_value = 0.6
    return mat


def rim_material():
    """A tile's edge: frost-white, like every sharp edge of the Glacier's crystals."""
    return S.flat_material("TileRim", FROST, rough=0.3, emit=0.9)


def aura_material():
    """A soft glow with no edge: brightest against the piece, fading to nothing away from it."""
    mat = bpy.data.materials.new("Aura")
    mat.use_nodes = True
    mat.surface_render_method = "BLENDED"
    N, L = mat.node_tree.nodes, mat.node_tree.links
    for node in list(N):
        N.remove(node)
    out = N.new("ShaderNodeOutputMaterial")
    emit = N.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*S.lin(FROST), 1)
    emit.inputs["Strength"].default_value = 1.5
    clear = N.new("ShaderNodeBsdfTransparent")
    weight = N.new("ShaderNodeAttribute")          # 1 at the piece's own edge, 0 at the glow's far side
    weight.attribute_name = "glow"
    soft = N.new("ShaderNodeMath")                 # squared: it falls away fast and has no outline
    soft.operation = "POWER"
    soft.inputs[1].default_value = 2.0
    L.new(weight.outputs["Fac"], soft.inputs[0])
    dim = N.new("ShaderNodeMath")
    dim.operation = "MULTIPLY"
    L.new(soft.outputs[0], dim.inputs[0])
    info = N.new("ShaderNodeObjectInfo")           # each glow's own strength: the object's colour alpha
    L.new(info.outputs["Alpha"], dim.inputs[1])
    mix = N.new("ShaderNodeMixShader")
    L.new(dim.outputs[0], mix.inputs[0])
    L.new(clear.outputs[0], mix.inputs[1])
    L.new(emit.outputs[0], mix.inputs[2])
    L.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def spark_material():
    mat = bpy.data.materials.new("Triangle")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*S.lin(FROST), 1)
    bsdf.inputs["Emission Color"].default_value = (*S.lin(GLOW_TINT), 1)
    bsdf.inputs["Emission Strength"].default_value = 3.5
    return mat


# -------------------------------------------------------------------------------------------------- tiles
def tile_mesh(shape, ice, rim):
    """One of the six flat tiles, about 1 across: uneven sides, a low rim and a slightly smaller raised top."""
    sides = SIDES[shape]
    ring = []
    for k in range(sides):
        angle = (k + (rnd(shape, k) - 0.5) * 0.56) * 2 * math.pi / sides
        radius = 0.5 * (0.78 + 0.3 * rnd(shape + 11, k))
        ring.append((radius * math.cos(angle), radius * math.sin(angle)))
    verts = [(x, y, 0.0) for x, y in ring] + [(x, y, 0.45) for x, y in ring] + [(x * 0.86, y * 0.86, 1.0) for x, y in ring]
    faces = []
    for layer in range(2):
        for k in range(sides):
            a, b = layer * sides + k, layer * sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(range(2 * sides, 3 * sides)))
    mesh = bpy.data.meshes.new(f"IceTile{shape}")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(rim)
    mesh.materials.append(ice)
    mesh.polygons[-1].material_index = 1
    return mesh


def aura_mesh(shape, mat):
    """The glow round one tile shape: it has the TILE'S OWN OUTLINE (the first try was a round ball, which the owner
    read as \"a circle around the piece instead of an aura\"). A skirt spreading over the floor from the tile's
    edge, and a shorter one rising from it; both are full at the tile and nothing at their far side."""
    sides = SIDES[shape]
    ring = []
    for k in range(sides):
        angle = (k + (rnd(shape, k) - 0.5) * 0.56) * 2 * math.pi / sides
        radius = 0.5 * (0.78 + 0.3 * rnd(shape + 11, k))
        ring.append((radius * math.cos(angle), radius * math.sin(angle)))
    verts = ([(x, y, 0.03) for x, y in ring]                       # the tile's edge
             + [(x * 1.2, y * 1.2, 0.015) for x, y in ring]        # half way out over the floor
             + [(x * 1.5, y * 1.5, 0.0) for x, y in ring]          # the far side, on the floor
             + [(x * 1.12, y * 1.12, 0.16) for x, y in ring])      # the far side of the rising part
    faces = []
    for k in range(sides):
        n = (k + 1) % sides
        faces.append((k, n, sides + n, sides + k))
        faces.append((sides + k, sides + n, 2 * sides + n, 2 * sides + k))
        faces.append((k, n, 3 * sides + n, 3 * sides + k))
    amounts = [1.0] * sides + [0.35] * sides + [0.0] * (2 * sides)
    # WISPS (the owner's second reference, velcrawl's "Aura VFX", YouTube HihKVj8Tbwg: a bright line hugging the
    # piece's outline with thin tongues licking out of it; "dont copy the reference but use the style of
    # surrounding the piece"). Two thin tongues on every side of the tile, rooted on its edge, leaning out and up,
    # each a different length; bright at the root, nothing at the tip.
    for k in range(sides):
        (ax, ay), (bx, by) = ring[k], ring[(k + 1) % sides]
        for j in range(2):
            u, v = rnd(shape * 31 + k, j + 50), rnd(shape * 17 + k, j + 60)
            along = 0.2 + 0.6 * (j + u) / 2
            mx, my = ax + (bx - ax) * along, ay + (by - ay) * along
            length = math.hypot(mx, my) or 1.0
            ox, oy = mx / length, my / length                       # straight out from the tile's middle
            tx, ty = (bx - ax), (by - ay)
            side = math.hypot(tx, ty) or 1.0
            tx, ty = tx / side * 0.035, ty / side * 0.035           # half the tongue's width at its root
            reach = 0.1 + 0.2 * v
            start = len(verts)
            verts += [(mx - tx, my - ty, 0.04), (mx + tx, my + ty, 0.04),
                      (mx + ox * reach + tx * (u - 0.5) * 6, my + oy * reach + ty * (u - 0.5) * 6, 0.05 + reach * 0.9)]
            faces.append((start, start + 1, start + 2))
            amounts += [1.0, 1.0, 0.0]
    mesh = bpy.data.meshes.new(f"Halo{shape}")
    mesh.from_pydata(verts, [], faces)
    glow = mesh.attributes.new("glow", "FLOAT", "POINT")
    for index in range(len(verts)):
        glow.data[index].value = amounts[index]
    mesh.materials.append(mat)
    return mesh


def tiles():
    """(x, y, z, width, turn, shape, share of the path 0 at its start to 1 beside the fighter). Two layers: a
    full bed of big tiles lying over each other, and smaller ones piled on top of it."""
    out = []
    rows = int(PATH / STEP)
    for row in range(rows):
        y = 2.0 + row * STEP
        shift = 0.5 if row % 2 else 0.0
        share = 1 - row / max(rows - 1, 1)
        for column in COLUMNS:
            x = (column + shift) * ACROSS
            edge = abs(x) > ACROSS * 1.4
            u, v, w = rnd(row, column), rnd(row + 31, column + 7), rnd(row + 5, column + 19)
            if True:                                       # FULL: no tile is left out, and every tile overlaps its neighbours
                width = ACROSS * ((1.25 + 0.5 * u) if edge else (1.55 + 0.45 * u))
                out.append((x + (v - 0.5) * 0.9, y + (w - 0.5) * 0.9, 0.02 + ((row * 5 + column + 2) % 6) * 0.015,
                            width, v * 2 * math.pi, int(w * 6) % 6, share))
            if not edge and rnd(row + 53, column + 3) > 0.4:
                p, q = rnd(row + 71, column + 11), rnd(row + 13, column + 41)
                out.append((x + (p - 0.5) * 1.6, y + (q - 0.5) * 1.4, THICK * 0.8, ACROSS * (0.7 + 0.5 * p),
                            q * 2 * math.pi, int(p * 6) % 6, share))
    return out


def tile_size(t, share):
    """A tile's size 0-1, `t` seconds after the dash ended. It waits until the crystals at its own spot have
    dissolved; the path's start goes first."""
    start = (SPIKE_HOLD - DASH * (1 - share)) + SPIKE_TURN + SPIKE_THIN + TILE_WAIT
    return 1.0 if t <= start else max(1.0 - (t - start) / TILE_SHRINK, 0.0)


# ------------------------------------------------------------------------------------------------- spikes
def spikes():
    """(x, y, height, lean in degrees, which way it leans, turn, piece, share of the path). Twenty-six short
    crystals standing ON the trail along its two EDGES, never in the lane the body went down (the owner: "at
    the edges of the trail (but still ON the trail) and not inside of it"), unevenly spaced, on whichever side
    their number gives, leaning every which way. Each number is fixed by the crystal's own index."""
    out = []
    count = 26
    for index in range(count):
        u, v, w, a = rnd(index, 3), rnd(index, 17), rnd(index, 29), rnd(index, 43)
        y = 3.0 + index * (PATH - 6.0) / (count - 1) + (w - 0.5) * 2.6
        side = 1 if rnd(index, 61) > 0.5 else -1
        out.append((side * (LANE + 1.0 + 1.6 * u), y, 1.4 + 2.2 * v * v, 6 + 22 * a, w * 2 * math.pi, u * 2 * math.pi,
                    "Ice_SpikeThick" if index % 3 == 0 else "Ice_SpikeTall", 1 - (y - 2.0) / PATH))
    return out


def spike_state(t, share):
    """(is the solid spike there, share of its triangles showing 0-1), `t` seconds after the dash ended.
    A spike rose as the body passed it and stands SPIKE_HOLD: the path's start dissolves first."""
    s = t - (SPIKE_HOLD - DASH * (1 - share))
    if s < 0:
        return True, 0.0
    if s < SPIKE_TURN:
        return True, s / SPIKE_TURN
    if s < SPIKE_TURN + SPIKE_THIN:
        return False, 1.0 - (s - SPIKE_TURN) / SPIKE_THIN
    return False, 0.0


def triangle_mesh(mat):
    mesh = bpy.data.meshes.new("Triangle")
    mesh.from_pydata([(0, 0.58, 0), (-0.5, -0.29, 0), (0.5, -0.29, 0)], [], [(0, 1, 2)])
    mesh.materials.append(mat)
    return mesh


def build(kit, t, ice, rim, spark):
    scene = bpy.context.scene
    meshes = [tile_mesh(shape, ice, rim) for shape in range(6)]
    glow_mat = aura_material()
    mote = bpy.data.meshes.new("Spark")
    mote.from_pydata([(0, 0, 1), (0, 0, -1), (1, 0, 0), (0, 1, 0), (-1, 0, 0), (0, -1, 0)], [],
                     [(0, 2, 3), (0, 3, 4), (0, 4, 5), (0, 5, 2), (1, 3, 2), (1, 4, 3), (1, 5, 4), (1, 2, 5)])
    mote.materials.append(spark)
    halos = [aura_mesh(shape, glow_mat) for shape in range(6)]
    for number, (x, y, z, width, turn, shape, share) in enumerate(tiles()):
        size = tile_size(t, share)
        if size <= 0.02:
            continue
        if size < 1.0:
            # EVAPORATION, second try. The owner: "not like a rising particle but rather a glowing white aura around
            # each melting piece ... but not fiery", "it shouldnt be that big, just enough to wrap arround the
            # pieces". One soft white glow per shrinking tile, a little wider than the tile and low, which shrinks
            # with it. It comes in over the first tenth of the melt so it does not pop.
            come = min((1.0 - size) / 0.1, 1.0)
            glow = bpy.data.objects.new("Halo", halos[shape])
            glow.location = (x, y, z)
            glow.rotation_euler = (0, 0, turn)
            reach = width * size * (0.7 + 0.3 * come)
            glow.scale = (reach, reach, reach)
            # Faint while the tiles still lie over each other (many glows in one place add up to a white band),
            # full once the tile is half its size and stands alone.
            glow.color = (1, 1, 1, 0.25 + 0.75 * min((1.0 - size) / 0.5, 1.0))
            # A FEW SPARKS flying out (the owner: "having a few sparks flying out"): one for every other tile at
            # a time, leaving the tile's edge outward and a little up, shrinking as it goes.
            if number % 2 == 0:
                u, v = rnd(number, 91), rnd(number, 92)
                flown = frac(u + t * 1.6)                  # a spark lasts 0.6 s, then the next leaves
                way = v * 2 * math.pi
                out = width * size * (0.5 + 0.9 * flown)
                dot = bpy.data.objects.new("Spark", mote)
                dot.location = (x + math.cos(way) * out, y + math.sin(way) * out, z + 0.15 + flown * (0.5 + 0.8 * u))
                radius = 0.13 * (1 - 0.6 * flown)
                dot.scale = (radius, radius, radius)
                scene.collection.objects.link(dot)
            scene.collection.objects.link(glow)
        obj = bpy.data.objects.new("Tile", meshes[shape])
        obj.location = (x, y, z)                           # tiles lie over one another, as in the reference
        obj.rotation_euler = (0, 0, turn)
        obj.scale = (width * size, width * size, THICK * (0.4 + 0.6 * size))
        scene.collection.objects.link(obj)
    triangle = triangle_mesh(spark)
    for index, (x, y, height, lean, way, turn, piece, share) in enumerate(spikes()):
        solid, showing = spike_state(t, share)
        tilt = Euler((math.radians(lean) * math.sin(way), math.radians(lean) * math.cos(way), 0))
        foot = THICK * 0.9                                  # it stands on the trail, not on the floor
        if solid:
            obj = bpy.data.objects.new("Spike", kit[piece].data)
            obj.location = (x, y, foot)
            obj.rotation_euler = tilt.copy()
            obj.rotation_euler.rotate_axis("Z", turn)
            obj.scale = (height, height, height)
            scene.collection.objects.link(obj)
        if showing <= 0:
            continue
        # The triangles sit inside the spike's own shape: a cone, widest at the floor.
        wide = height * (0.38 if piece == "Ice_SpikeThick" else 0.2)
        total = int(70 + height * 14)                      # dense, as the reference's cloud is
        for k in range(total):
            if rnd(index * 100 + k, 5) > showing:
                continue                                   # each triangle has its own moment to come and go
            up = rnd(index * 100 + k, 1) ** 1.4
            angle = rnd(index * 100 + k, 2) * 2 * math.pi
            out = wide * (1 - up) * math.sqrt(rnd(index * 100 + k, 3))
            local = Vector((out * math.cos(angle), out * math.sin(angle), up * height))
            local.rotate(tilt)
            tri = bpy.data.objects.new("Tri", triangle)
            tri.location = (x + local.x, y + local.y, local.z + foot + 0.1)
            tri.rotation_euler = (rnd(index * 100 + k, 6) * 6.28, rnd(index * 100 + k, 7) * 6.28, rnd(index * 100 + k, 8) * 6.28)
            size = 0.3 + 0.45 * rnd(index * 100 + k, 4)
            tri.scale = (size, size, size)
            scene.collection.objects.link(tri)


def bloom():
    """The game has Bloom (1 / 40 / 1.6): bright things glow past their edges. The same here, in the compositor."""
    scene = bpy.context.scene
    group = bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
    layers = group.nodes.new("CompositorNodeRLayers")
    glare = group.nodes.new("CompositorNodeGlare")
    glare.inputs["Type"].default_value = "Bloom"
    glare.inputs["Threshold"].default_value = 1.6
    glare.inputs["Strength"].default_value = 0.3
    glare.inputs["Size"].default_value = 0.35
    out = group.nodes.new("NodeGroupOutput")
    group.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    group.links.new(layers.outputs["Image"], glare.inputs["Image"])
    group.links.new(glare.outputs[0], out.inputs["Image"])
    scene.compositing_node_group = group
    scene.render.use_compositing = True


def load_kit():
    bpy.ops.import_scene.gltf(filepath=KIT)
    kit = {}
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.name.startswith("Ice_"):
            kit[obj.name] = obj
            # As the place shows it: the frost glows (SurfaceAppearance emissive, tint 200,235,255).
            for mat in obj.data.materials:
                bsdf = mat.node_tree.nodes.get("Principled BSDF")
                if bsdf:
                    bsdf.inputs["Emission Color"].default_value = (*S.lin(GLOW_TINT), 1)
                    bsdf.inputs["Emission Strength"].default_value = 0.45
            obj.hide_render = True
            obj.location = (0, 0, -500)
    return kit


SHOTS = [
    ("a_after_dash", 0.0, "lobby", (20, 2, 11), (0, 20, 0), 60.0),
    ("b_spikes_dissolving", 0.5, "lobby", (20, 2, 11), (0, 20, 0), 60.0),
    ("c_spikes_gone", 1.05, "lobby", (20, 2, 11), (0, 20, 0), 60.0),
    ("d_after_dash_grass", 0.0, "meadow", (20, 2, 11), (0, 20, 0), 60.0),
    ("e_close", 2.15, "meadow", (13, 5, 6), (0, 15, 1), 55.0),
    ("f_tiles_melting", 2.15, "lobby", (20, 2, 11), (0, 20, 0), 60.0),
]
for label, t, ground, position, look, fov in SHOTS:
    S.new_scene(960, 540, 32)
    bloom()
    S.floor(ground)
    S.fighter((0, 0, 0))
    build(load_kit(), t, ice_material(), rim_material(), spark_material())
    S.camera(position, look, fov, "Cam")
    S.render(os.path.join(OUT, f"melt_{label}.png"))
print("done")
