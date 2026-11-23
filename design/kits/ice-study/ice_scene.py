"""Shared scene kit for the Frost ice remake (2026-11-22), for headless Blender 5.2.

What it gives: the game's camera, a floor in the game's colours, a stand-in fighter, materials that show
vertex colours the way Roblox does, and the Frost Glacier's own layout and ERUPT motion (copied from
src/client/Fx/FrostFx.luau and Fx/KitModels.luau), so a kit of five pieces can be seen as the game shows it.

Roblox facts this file relies on (measured in Studio, 2026-11-22):
  * A MeshPart is placed by the middle of its bounding box, not by the Blender origin.
  * Vertex colours multiply the part's Color as plain numbers (stored value x colour, both as shown on
    screen), on Neon too. Blender's glTF exporter writes byte colours converted to linear, so a colour
    painted as 0.42 arrives as 0.15.
  * Lighting: sun toward (-0.860, 0.497, 0.113), ClockTime 16; the game camera is 12.07 behind and 7.74 above
    the thrower's feet, looking at 4.5 above them, FieldOfView 70 (vertical).
Scene axes: the thrower stands at the origin facing -Y, +Z up, their right is -X (Roblox (x, y, z) -> (-x, z, y)).
"""
import math
import os

import bpy
from mathutils import Matrix, Vector

M4 = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Roblox <-> Blender (its own inverse)

ICE = [(84, 156, 255), (128, 204, 255), (184, 232, 255), (240, 251, 255)]
GLOW = (170, 236, 255)
FLOORS = {"lobby": (250, 232, 196), "meadow": (128, 170, 60)}   # as photographed in Studio (lit)
SKY = (124, 192, 223)
SUN, AMBIENT, NEON = 3.2, 0.6, 4.2
AMBIENT_COLOUR = (0.42, 0.62, 1.0)   # the sky lights the shaded sides blue
#   # tuned against the Studio captures (design/kits/ice-study/studio)

# FrostFx.GLACIER: right, ahead, height, lean, wave, piece, tone
GLACIER = [
    (0, 7, 16, 0, 0, "Ice_Clump", 2), (-1.4, 6.4, 13, 6, 0, "Ice_SpikeTall", 0), (1.6, 7.6, 12, 6, 0, "Ice_SpikeTall", 0),
    (-4, 5.5, 11.5, 20, 1, "Ice_SpikeThick", 3), (4, 5.5, 11, 20, 1, "Ice_SpikeThick", 1), (-3, 10, 12.5, 16, 1, "Ice_SpikeThick", 2),
    (3.2, 10.4, 10.5, 16, 1, "Ice_SpikeThick", 4), (0, 3.4, 8, 14, 1, "Ice_SpikeTall", 0), (-8, 3.5, 8, 26, 2, "Ice_Clump", 1),
    (8, 3.5, 7.5, 26, 2, "Ice_Clump", 3), (0, 13.5, 9, 22, 2, "Ice_Clump", 4), (-11, 7, 7.5, 30, 2, "Ice_SpikeTall", 2),
    (11, 7, 8, 30, 2, "Ice_SpikeTall", 3), (-8.5, 11.5, 8.5, 30, 2, "Ice_SpikeThick", 4), (8.5, 11.5, 9, 30, 2, "Ice_SpikeThick", 1),
    (-5, 14.5, 6.5, 34, 2, "Ice_SpikeTall", 2), (5, 14.5, 7, 34, 2, "Ice_SpikeTall", 3), (-13.5, 4, 5.5, 30, 2, "Ice_SpikeTall", 4),
    (13.5, 4, 5.5, 30, 2, "Ice_SpikeTall", 2),
]
GLACIER_HOLD, GLACIER_CENTRE = 0.9, 7
FLASH, RISE, SETTLE, SINK = 0.06, 0.08, 0.07, 0.26


def lin(c):
    """sRGB 0-255 triple -> linear floats (what a Blender colour socket wants)."""
    out = []
    for v in c:
        v /= 255
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return out


def new_scene(width=1600, height=574, samples=32):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.eevee.taa_render_samples = samples
    scene.render.fps = 60
    world = bpy.data.worlds.new("Sky")
    try:
        world.use_nodes = True
    except Exception:
        pass
    # The camera sees the sky's colour; the scene is lit by a paler, weaker ambient (Roblox Ambient 70,70,85 and
    # OutdoorAmbient 100,100,115 are far dimmer than its sky).
    nodes, links = world.node_tree.nodes, world.node_tree.links
    background = nodes.get("Background")
    background.inputs["Color"].default_value = (*lin(SKY), 1)
    background.inputs["Strength"].default_value = 1.0
    ambient = nodes.new("ShaderNodeBackground")
    ambient.inputs["Color"].default_value = (*AMBIENT_COLOUR, 1)
    ambient.inputs["Strength"].default_value = AMBIENT
    path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(path.outputs["Is Camera Ray"], mix.inputs[0])
    links.new(ambient.outputs[0], mix.inputs[1])
    links.new(background.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], nodes.get("World Output").inputs["Surface"])
    scene.world = world
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = SUN
    sun_data.color = (1.0, 0.95, 0.86)
    sun_data.angle = math.radians(3)
    sun = bpy.data.objects.new("Sun", sun_data)
    toward = Vector((0.860, 0.113, 0.497)).normalized()   # Roblox (-0.860, 0.497, 0.113)
    sun.rotation_euler = toward.to_track_quat("Z", "Y").to_euler()
    scene.collection.objects.link(sun)
    return scene


def flat_material(name, rgb, rough=0.6, emit=0.0):
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*lin(rgb), 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = 0.2
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*lin(rgb), 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def floor(kind, tiles=True):
    """A 600-stud floor in the game's colour, with faint 4-stud tiles as a ruler."""
    rgb = FLOORS[kind]
    mesh = bpy.data.meshes.new("Floor")
    mesh.from_pydata([(-300, -300, 0), (300, -300, 0), (300, 300, 0), (-300, 300, 0)], [], [(0, 1, 2, 3)])
    obj = bpy.data.objects.new("Floor_" + kind, mesh)
    mat = flat_material("Floor_" + kind, rgb, rough=0.9, emit=0.14)
    if tiles:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        coord = nodes.new("ShaderNodeTexCoord")
        checker = nodes.new("ShaderNodeTexChecker")
        checker.inputs["Scale"].default_value = 0.25    # object coordinates are studs: 4-stud squares
        dark = [v * 0.93 for v in lin(rgb)]
        checker.inputs["Color1"].default_value = (*lin(rgb), 1)
        checker.inputs["Color2"].default_value = (*dark, 1)
        links.new(coord.outputs["Object"], checker.inputs["Vector"])
        links.new(checker.outputs["Color"], bsdf.inputs["Base Color"])
    mesh.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(name, size, centre, mat):
    sx, sy, sz = (v / 2 for v in size)
    verts = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = centre
    bpy.context.scene.collection.objects.link(obj)
    return obj


def fighter(at=(0, 0, 0)):
    """A blocky stand-in the size of the game's R6 fighter (5 studs), in the owner's avatar colours."""
    shirt = flat_material("Shirt", (236, 236, 240))
    legs = flat_material("Legs", (40, 42, 50))
    skin = flat_material("Skin", (205, 190, 170))
    hair = flat_material("Hair", (120, 112, 104))
    x, y, z = at
    parts = [
        box("Torso", (2, 1, 2), (x, y, z + 3), shirt), box("ArmL", (1, 1, 2), (x + 1.5, y, z + 3), shirt),
        box("ArmR", (1, 1, 2), (x - 1.5, y, z + 3), shirt), box("LegL", (1, 1, 2), (x + 0.5, y, z + 1), legs),
        box("LegR", (1, 1, 2), (x - 0.5, y, z + 1), legs), box("Head", (1.2, 1.2, 1.2), (x, y, z + 4.6), skin),
        box("Hair", (1.3, 1.3, 0.5), (x, y + 0.05, z + 5.1), hair),
    ]
    return parts


def lens_of(fov, sensor=24.0):
    return (sensor / 2) / math.tan(math.radians(fov) / 2)


def camera(position, look, fov=70.0, name="Cam"):
    data = bpy.data.cameras.new(name)
    data.sensor_fit, data.sensor_height = "VERTICAL", 24.0
    data.lens = lens_of(fov)
    data.clip_start, data.clip_end = 0.1, 2000
    obj = bpy.data.objects.new(name, data)
    obj.location = position
    direction = Vector(look) - Vector(position)
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.scene.camera = obj
    return obj


def game_camera():
    return camera((0, 12.07, 7.74), (0, 0, 4.5), 70.0, "GameCam")


TEXTURE = None   # path of a multiplier texture (frost); None = vertex colours only


def ice_material(name, colour, attribute, neon=False, transparency=0.1):
    """Roblox look: albedo = part Color (decoded to linear) x the stored vertex colour, used as it is."""
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    vcol = nodes.new("ShaderNodeVertexColor")
    vcol.layer_name = attribute
    tint = nodes.new("ShaderNodeVectorMath")
    tint.operation = "MULTIPLY"
    tint.inputs[1].default_value = lin(colour)
    out_socket = tint.outputs["Vector"]
    if TEXTURE:
        image = nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(TEXTURE, check_existing=True)
        frost = nodes.new("ShaderNodeVectorMath")
        frost.operation = "MULTIPLY"
        links.new(tint.outputs["Vector"], frost.inputs[0])
        links.new(image.outputs["Color"], frost.inputs[1])
        out_socket = frost.outputs["Vector"]
    if neon:
        # Fitted to the Studio captures (2026-11-22): on Neon a stored vertex colour of 0.1 shows near black
        # navy, 0.3 mid blue, 0.8 white with bloom: about 4.2 x stored^3.8 / ^3.2 / ^2.4 for R / G / B.
        split = nodes.new("ShaderNodeSeparateColor")
        join = nodes.new("ShaderNodeCombineColor")
        links.new(vcol.outputs["Color"], split.inputs[0])
        for channel, power in enumerate((3.8, 3.2, 2.4)):
            node = nodes.new("ShaderNodeMath")
            node.operation = "POWER"
            node.inputs[1].default_value = power
            links.new(split.outputs[channel], node.inputs[0])
            links.new(node.outputs[0], join.inputs[channel])
        links.new(join.outputs[0], tint.inputs[0])
    else:
        links.new(vcol.outputs["Color"], tint.inputs[0])
    if neon:
        bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
        links.new(out_socket, bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = NEON
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    else:
        links.new(out_socket, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.3
        bsdf.inputs["Specular IOR Level"].default_value = 0.6
    bsdf.inputs["Alpha"].default_value = 1.0 - transparency
    return mat


_materials = {}


def material_for(attribute, tone, state, transparency=None):
    """state: 'own' (its colour and material) or 'hot' (Neon white). `transparency` replaces the game's 0.1."""
    see = 0.1 if transparency is None else transparency
    key = (attribute, tone, state, see, tuple(ICE[tone - 1]) if tone else GLOW, TEXTURE)
    if key not in _materials:
        if state == "hot":
            _materials[key] = ice_material("Hot_" + attribute, (255, 255, 255), attribute, neon=True, transparency=0)
        elif tone == 0:
            _materials[key] = ice_material("Glow_" + attribute, GLOW, attribute, neon=True, transparency=0.2)
        else:
            _materials[key] = ice_material(f"Ice{tone}_" + attribute, ICE[tone - 1], attribute, transparency=see)
    return _materials[key]


def paint_of(mesh):
    """The colour attribute that holds the painting: the one whose values vary most. (The kits-2 GLB has two
    sets: COLOR_0 all white and COLOR_1 painted; Roblox showed the painted one.)"""
    best, spread = None, -1.0
    for attr in mesh.color_attributes:
        values = [d.color[0] + d.color[1] + d.color[2] for d in attr.data]
        s = (max(values) - min(values)) if values else 0.0
        if s > spread:
            best, spread = attr.name, s
    return best


def load_kit(glb):
    """Imports a kit GLB; returns {piece name: mesh}. The objects themselves are removed."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb)
    kit = {}
    for obj in set(bpy.data.objects) - before:
        if obj.type == "MESH":
            name = obj.name.split(".")[0]
            mesh = obj.data
            # Bake any object transform the importer left (rotation or scale) into the mesh.
            mesh.transform(obj.matrix_world.to_3x3().to_4x4())
            mesh.name = name + "_kit"
            mesh["paint"] = paint_of(mesh) or ""
            kit[name] = mesh
        bpy.data.objects.remove(obj)
    return kit


def bounds(mesh):
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def rooted(position_r, toward_r, lean, yaw):
    """KitModels.rooted, in Roblox space."""
    flat = Vector((toward_r.x, 0, toward_r.z))
    frame = Matrix.Translation(position_r)
    if flat.length > 0.01 and lean != 0:
        axis = Vector((0, 1, 0)).cross(flat.normalized())
        frame = frame @ Matrix.Rotation(math.radians(lean), 4, axis)
    return frame @ Matrix.Rotation(math.radians(yaw), 4, "Y")


def erupt_state(t, hold=GLACIER_HOLD):
    """KitModels' ERUPT at `t` seconds after a piece arrives: (grown, wide, hot) or None when it is gone."""
    if t < 0:
        return None
    leave = RISE + SETTLE + hold
    if t >= leave + SINK:
        return None
    if t < RISE:
        grown = 1.16 * (1 - (1 - t / RISE) ** 3)
    elif t < RISE + SETTLE:
        grown = 1.16 - 0.16 * ((t - RISE) / SETTLE)
    elif t < leave:
        grown = 1.0
    else:
        u = min(max((t - leave) / SINK, 0), 1)
        grown = 1 - u * u
    wide = 0.55 + 0.45 * min(grown, 1)
    return grown, wide, (t < FLASH or t >= leave)


def place(mesh, base_r, height, grown=1.0, wide=1.0, name="Piece"):
    """Puts `mesh` where the game would: Roblox frame `base_r` at its root, `height` studs tall, scaled about
    the middle of its bounding box as a MeshPart is."""
    low, high = bounds(mesh)
    centre_b = (low + high) / 2
    size_b = high - low
    scale = height / size_b.z
    # In Roblox: size (X, Y, Z) = Blender (x, z, y) x scale; ERUPT widens X and Z, grows Y.
    full_y = size_b.z * scale
    shown_y = max(full_y * grown, 0.05)
    scale_r = Matrix.Diagonal((scale * wide, scale * shown_y / full_y, scale * wide, 1))
    centre_r = M4 @ centre_b
    local_r = Matrix.Translation((0, shown_y / 2, 0)) @ scale_r @ Matrix.Translation(-centre_r)
    obj = bpy.data.objects.new(name, mesh)
    obj.matrix_world = M4 @ base_r @ local_r @ M4
    bpy.context.scene.collection.objects.link(obj)
    return obj


def glacier(kit, t, feet=(0, 0, 0), table=None, attribute=None, centre=GLACIER_CENTRE, transparency=None):
    """The Frost Glacier at `t` seconds after the stomp, built from `kit` ({name: mesh}). Returns its objects."""
    made = []
    feet_r = M4 @ Vector(feet)
    way = Vector((0, 0, -1))
    right = Vector((1, 0, 0))
    middle = feet_r + way * centre
    for index, spec in enumerate(table or GLACIER, start=1):
        r, a, height, lean, wave, name, tone = spec[:7]
        yaw = spec[7] if len(spec) > 7 else (index * 137) % 360   # the game: math.random(0, 359) unless the row sets it
        state = erupt_state(t - wave * 2 / 60)
        if state is None:
            continue
        grown, wide, hot = state
        mesh = kit[name]
        spot = feet_r + right * r + way * a
        base = rooted(spot, spot - middle, lean, yaw)
        obj = place(mesh, base, height, grown, wide, f"G{index:02d}_{name}")
        attr = attribute or mesh["paint"]
        obj.data = mesh.copy()   # its own material slot
        obj.data.materials.clear()
        obj.data.materials.append(material_for(attr, tone, "hot" if hot else "own", transparency))
        obj.visible_shadow = False   # KitModels: CastShadow = false
        made.append(obj)
    return made


_shells = {}


def shells(mesh):
    """The mesh's separate closed pieces (blades, lumps) as lists of vertex indices."""
    key = mesh.name
    if key not in _shells:
        parent = list(range(len(mesh.vertices)))

        def find(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i
        for edge in mesh.edges:
            a, b = find(edge.vertices[0]), find(edge.vertices[1])
            if a != b:
                parent[a] = b
        groups = {}
        for i in range(len(mesh.vertices)):
            groups.setdefault(find(i), []).append(i)
        _shells[key] = list(groups.values())
    return _shells[key]


def slivers(mesh, matrix):
    """How many of the mesh's blades only just poke out of the floor when it is placed by `matrix`: the top
    under 1 stud up, or under 30 % of the blade above the floor. (The owner pointed at one: a blade lying
    almost flat with most of it under the ground, showing as a thin strip.) Blades wholly under the floor do
    not count: they are not seen."""
    heights = [(matrix @ v.co).z for v in mesh.vertices]
    count = 0
    for shell in shells(mesh):
        zs = [heights[i] for i in shell]
        top = max(zs)
        if top <= 0.05:
            continue
        above = sum(1 for z in zs if z > 0.0) / len(zs)
        if top < 1.0 or above < 0.3:
            count += 1
    return count


def detached(mesh, matrix):
    """How many of the mesh's blades come out of the floor away from the piece's root: the nearest part above
    the floor is more than 30 % of the blade's length from the root, so it reads as a loose piece lying on the
    ground. (Found by eye on 2026-11-22: a side blade of a leaning piece, its first third under the floor.)"""
    root = matrix @ Vector((0, 0, 0))
    world = [matrix @ v.co for v in mesh.vertices]
    count = 0
    for shell in shells(mesh):
        pts = [world[i] for i in shell]
        above = [p for p in pts if p.z > -0.02]      # on the floor counts: a piece's own cut lies at exactly 0
        if not above or len(above) == len(pts):
            continue
        length = max((p - root).length for p in pts)
        nearest = min((p - root).length for p in above)
        if nearest > 0.3 * length:
            count += 1
    return count


def render(path):
    scene = bpy.context.scene
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def remove(objects):
    for obj in objects:
        mesh = obj.data
        bpy.data.objects.remove(obj)
        if mesh and mesh.users == 0:
            bpy.data.meshes.remove(mesh)
