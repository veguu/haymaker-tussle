"""Melt step 2 (2026-11-23): the Frostbite trail's six floor tiles and the dissolve's triangle, made in Blender.
  blender -b --factory-startup --python-exit-code 1 --python bake_tiles.py -- <out dir>

Writes, into <out dir>: ice_tex_Ice_Tile<n>.png (512, colour), ice_gloss_Ice_Tile<n>.png (256, glTF packing:
green roughness, blue metalness), tile_bake_strip.png (the baked tiles laid as the trail, to check the bake),
ice_triangle.png (256, white on clear: the particle the trail's crystals dissolve into);
and ../out/export/ice_tiles_v1.glb (the six tiles with UVs and textures, no vertex colours).

The owner's rules this keeps: all art incl. textures is made in Blender; models stay grey, colour comes from
the texture; the texture wraps the model without stretching (the pattern is made in 3D on the tile itself);
the trail matches the Glacier (its blues, its white frost on about a fifth, white edges); tiles are flat and
"more random instead of all being hexagons".

A tile is 1 across at its widest and 0.035 thick, lying flat with its underside on z = 0 and its bounding box
centred on the origin in X and Y (Roblox places a MeshPart by the middle of its bounding box).
"""
import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_scene as S  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(OUT, exist_ok=True)
GLB = os.path.join(os.path.dirname(HERE), "out", "export", "ice_tiles_v1.glb")

CLEAR_A, CLEAR_B, FROST = (150, 204, 240), (188, 227, 247), (246, 252, 255)   # the Glacier's (bake_frost2.py)
SIDES = (4, 5, 5, 6, 6, 7)
THICK = 0.035
NAMES = [f"Ice_Tile{n}" for n in range(1, 7)]


def frac(v):
    return v - math.floor(v)


def rnd(a, b):
    return frac(math.sin(a * 12.9898 + b * 78.233) * 43758.5453)


def tile_mesh(shape):
    """The same six outlines as the picture sheet (render_melt_strip.py), now closed, centred and 1 across."""
    sides = SIDES[shape]
    ring = []
    for k in range(sides):
        angle = (k + (rnd(shape, k) - 0.5) * 0.56) * 2 * math.pi / sides
        radius = 0.5 * (0.78 + 0.3 * rnd(shape + 11, k))
        ring.append((radius * math.cos(angle), radius * math.sin(angle)))
    xs, ys = [p[0] for p in ring], [p[1] for p in ring]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    scale = 1.0 / max(max(xs) - min(xs), max(ys) - min(ys))
    ring = [((x - cx) * scale, (y - cy) * scale) for x, y in ring]
    verts = ([(x, y, 0.0) for x, y in ring] + [(x, y, THICK * 0.45) for x, y in ring]
             + [(x * 0.9, y * 0.9, THICK) for x, y in ring])
    faces = [tuple(reversed(range(sides)))]                               # the underside
    for layer in range(2):
        for k in range(sides):
            a, b = layer * sides + k, layer * sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(range(2 * sides, 3 * sides)))                      # the top
    mesh = bpy.data.meshes.new(NAMES[shape])
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    return mesh


def frost_material(image, gloss=False):
    """The Glacier's frost on a flat tile, as an emission to bake: two light blues, soft white patches on about
    a fifth, a finer mottling, and frost-white on every edge and side."""
    mat = bpy.data.materials.new("TileBake")
    mat.use_nodes = True
    N, L = mat.node_tree.nodes, mat.node_tree.links
    for node in list(N):
        N.remove(node)
    out = N.new("ShaderNodeOutputMaterial")
    emit = N.new("ShaderNodeEmission")
    L.new(emit.outputs[0], out.inputs["Surface"])
    geo = N.new("ShaderNodeNewGeometry")
    patches = N.new("ShaderNodeTexNoise")
    patches.inputs["Scale"].default_value = 4.5
    patches.inputs["Detail"].default_value = 3.0
    patches.inputs["Roughness"].default_value = 0.6
    L.new(geo.outputs["Position"], patches.inputs["Vector"])
    mask = N.new("ShaderNodeValToRGB")
    mask.color_ramp.elements[0].position = 0.56
    mask.color_ramp.elements[1].position = 0.68
    L.new(patches.outputs["Fac"], mask.inputs["Fac"])
    bevel = N.new("ShaderNodeBevel")                # every sharp edge is frost-white
    bevel.samples = 8
    bevel.inputs["Radius"].default_value = 0.03
    dot = N.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    L.new(bevel.outputs["Normal"], dot.inputs[0])
    L.new(geo.outputs["True Normal"], dot.inputs[1])
    edge = N.new("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.998
    edge.inputs["From Max"].default_value = 0.90
    L.new(dot.outputs["Value"], edge.inputs["Value"])
    up = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["True Normal"], up.inputs[0])
    side = N.new("ShaderNodeMapRange")              # the tile's thin sides are frost too
    side.inputs["From Min"].default_value = 0.7
    side.inputs["From Max"].default_value = 0.3
    L.new(up.outputs["Z"], side.inputs["Value"])
    mott = N.new("ShaderNodeTexNoise")
    mott.inputs["Scale"].default_value = 14.0
    mott.inputs["Detail"].default_value = 6.0
    mott.inputs["Roughness"].default_value = 0.65
    L.new(geo.outputs["Position"], mott.inputs["Vector"])
    mottle = N.new("ShaderNodeMapRange")
    mottle.inputs["From Min"].default_value = 0.5
    mottle.inputs["From Max"].default_value = 0.7
    mottle.inputs["To Max"].default_value = 0.45
    L.new(mott.outputs["Fac"], mottle.inputs["Value"])
    total = None
    for socket in (mask.outputs["Color"], edge.outputs[0], side.outputs[0], mottle.outputs[0]):
        if total is None:
            total = socket
            continue
        most = N.new("ShaderNodeMath")
        most.operation = "MAXIMUM"
        L.new(total, most.inputs[0])
        L.new(socket, most.inputs[1])
        total = most.outputs[0]
    depth = N.new("ShaderNodeTexNoise")
    depth.inputs["Scale"].default_value = 2.5
    L.new(geo.outputs["Position"], depth.inputs["Vector"])
    clear = N.new("ShaderNodeMix")
    clear.data_type = "RGBA"
    clear.inputs["A"].default_value = (*S.lin(CLEAR_A), 1)
    clear.inputs["B"].default_value = (*S.lin(CLEAR_B), 1)
    L.new(depth.outputs["Fac"], clear.inputs["Factor"])
    colour = N.new("ShaderNodeMix")
    colour.data_type = "RGBA"
    colour.inputs["B"].default_value = (*S.lin(FROST), 1)
    L.new(total, colour.inputs["Factor"])
    L.new(clear.outputs["Result"], colour.inputs["A"])
    L.new(colour.outputs["Result"], emit.inputs["Color"])
    if gloss:
        rough = N.new("ShaderNodeMapRange")         # clear ice mirror-smooth (0.06), frost matte (0.7), no metal
        rough.inputs["To Min"].default_value = 0.06
        rough.inputs["To Max"].default_value = 0.7
        L.new(total, rough.inputs["Value"])
        pack = N.new("ShaderNodeCombineColor")
        pack.inputs[0].default_value = 1.0
        pack.inputs[2].default_value = 0.0
        L.new(rough.outputs[0], pack.inputs[1])
        L.new(pack.outputs[0], emit.inputs["Color"])
    target = N.new("ShaderNodeTexImage")
    target.image = image
    N.active = target
    return mat


def shown_material(path, gloss_path, name):
    """As Roblox shows a textured MeshPart: the image is the colour, the gloss image its roughness."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    N, L = mat.node_tree.nodes, mat.node_tree.links
    bsdf = N.get("Principled BSDF")
    tex = N.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=True)
    L.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    orm = N.new("ShaderNodeTexImage")
    orm.image = bpy.data.images.load(gloss_path, check_existing=True)
    orm.image.colorspace_settings.name = "Non-Color"
    split = N.new("ShaderNodeSeparateColor")
    L.new(orm.outputs["Color"], split.inputs[0])
    L.new(split.outputs[1], bsdf.inputs["Roughness"])
    L.new(split.outputs[2], bsdf.inputs["Metallic"])
    return mat


# ----------------------------------------------------------------------------------------------- the bake
S.new_scene(960, 540, 32)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 8
scene.cycles.device = "CPU"
scene.render.bake.use_clear = False
scene.render.bake.margin = 8
meshes, paths, gloss_paths, report = [], {}, {}, {}
for shape, name in enumerate(NAMES):
    mesh = tile_mesh(shape)
    meshes.append(mesh)
    obj = bpy.data.objects.new("Bake_" + name, mesh)
    scene.collection.objects.link(obj)
    for o in scene.objects:
        o.select_set(o is obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    image = bpy.data.images.new("Tex_" + name, 512, 512, alpha=False)
    image.generated_color = (*S.lin(CLEAR_B), 1)
    mesh.materials.clear()
    mesh.materials.append(frost_material(image))
    bpy.ops.object.bake(type="EMIT")
    paths[name] = os.path.join(OUT, f"ice_tex_{name}.png")
    image.filepath_raw = paths[name]
    image.file_format = "PNG"
    image.save()
    gloss = bpy.data.images.new("Gloss_" + name, 256, 256, alpha=False)
    gloss.colorspace_settings.name = "Non-Color"
    gloss.generated_color = (1.0, 0.3, 0.0, 1.0)
    mesh.materials.clear()
    mesh.materials.append(frost_material(gloss, gloss=True))
    bpy.ops.object.bake(type="EMIT")
    gloss_paths[name] = os.path.join(OUT, f"ice_gloss_{name}.png")
    gloss.filepath_raw = gloss_paths[name]
    gloss.file_format = "PNG"
    gloss.save()
    bpy.data.objects.remove(obj)
    mesh.materials.clear()
    mesh.materials.append(shown_material(paths[name], gloss_paths[name], name + "_Mat"))
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    mesh.calc_loop_triangles()
    report[name] = {
        "sides": SIDES[shape], "triangles": len(mesh.loop_triangles),
        "size": [round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3), round(max(zs) - min(zs), 4)],
        "bbox_centre_xy": [round((max(xs) + min(xs)) / 2, 4), round((max(ys) + min(ys)) / 2, 4)],
        "z_min": round(min(zs), 4), "uv_layers": len(mesh.uv_layers),
    }

# ------------------------------------------------------------- check: the baked tiles laid as the trail
scene.render.engine = "BLENDER_EEVEE"
S.floor("meadow")
S.fighter((0, 0, 0))
ACROSS, PATH = 2.2, 47.0
STEP = ACROSS * 0.866
for row in range(int(PATH / STEP)):
    for column in (-2, -1, 0, 1, 2):
        x = (column + (0.5 if row % 2 else 0.0)) * ACROSS
        u, v, w = rnd(row, column), rnd(row + 31, column + 7), rnd(row + 5, column + 19)
        width = ACROSS * ((1.25 + 0.5 * u) if abs(x) > ACROSS * 1.4 else (1.55 + 0.45 * u))
        obj = bpy.data.objects.new("Tile", meshes[int(w * 6) % 6])
        obj.location = (x + (v - 0.5) * 0.9, 2.0 + row * STEP + (w - 0.5) * 0.9, 0.02 + ((row * 5 + column + 2) % 6) * 0.015)
        obj.rotation_euler = (0, 0, v * 2 * math.pi)
        obj.scale = (width, width, width * 0.1 / (width * THICK))          # 0.1 studs thick whatever its width
        scene.collection.objects.link(obj)
S.camera((9, -3, 6), (0, 9, 0), 55.0, "Close")
S.render(os.path.join(OUT, "tile_bake_strip.png"))

# ----------------------------------------------------------------------------------------- the export
exported = []
for mesh in meshes:
    obj = bpy.data.objects.new(mesh.name, mesh)
    scene.collection.objects.link(obj)
    exported.append(obj)
for o in scene.objects:
    o.select_set(o in exported)
bpy.context.view_layer.objects.active = exported[0]
bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                          export_texcoords=True, export_normals=True, export_materials="EXPORT", export_vertex_color="NONE",
                          export_image_format="AUTO")
result = {"glb": GLB, "bytes": os.path.getsize(GLB), "pieces": report}

# --------------------------------------------------------------------------- the dissolve's triangle
S.new_scene(256, 256, 64)
scene = bpy.context.scene
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"
white = bpy.data.materials.new("White")
white.use_nodes = True
N, L = white.node_tree.nodes, white.node_tree.links
for node in list(N):
    N.remove(node)
out = N.new("ShaderNodeOutputMaterial")
glow = N.new("ShaderNodeEmission")
glow.inputs["Color"].default_value = (1, 1, 1, 1)
L.new(glow.outputs[0], out.inputs["Surface"])
shard = bpy.data.meshes.new("Shard")
# A sharp uneven triangle (a broken sliver of ice, not a road sign): true points, no rounding.
shard.from_pydata([(-0.02, 0.46, 0), (-0.40, -0.36, 0), (0.42, -0.24, 0)], [], [(0, 1, 2)])
shard.materials.append(white)
scene.collection.objects.link(bpy.data.objects.new("Shard", shard))
data = bpy.data.cameras.new("Top")
data.type = "ORTHO"
data.ortho_scale = 1.0
top = bpy.data.objects.new("Top", data)
top.location = (0, 0.03, 5)
scene.collection.objects.link(top)
scene.camera = top
S.render(os.path.join(OUT, "ice_triangle.png"))

print("RESULT_JSON=" + json.dumps(result))
