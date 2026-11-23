"""The ice's COLOUR texture, made in Blender, second pass (2026-11-22). The owner: stronger; models stay
default grey with no vertex colours, "all the color and texture should come from textures"; the first bake
was "too small ... way too stretched on the actual model. please make sure the texture wraps around the model".
So: one 1024 x 1024 image PER PIECE (five times the pixels of the shared sheet), the full colour baked in
(pale blue ice and white frost), the pattern made in 3D on the piece itself, so it runs unbroken round every
blade and across every UV seam, and only slightly longer along the crystal than across (1.6 : 1, was 4 : 1).
  blender -b --factory-startup --python-exit-code 1 --python bake_frost2.py -- <out dir>
Writes ice_tex_<piece>.png, tex_bake2_close.png, tex_bake2_game.png.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import FLOWER, FLOWER_CENTRE  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1]
NAMES = ["Ice_SpikeTall", "Ice_SpikeThick", "Ice_Clump", "Ice_Block", "Ice_Shard"]
CLEAR_A, CLEAR_B, FROST = (150, 204, 240), (188, 227, 247), (246, 252, 255)   # mostly light blue (reference median 182,224,244)


def frost_material(image, gloss=False):
    mat = bpy.data.materials.new("FrostBake")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    N, L = mat.node_tree.nodes, mat.node_tree.links
    for node in list(N):
        N.remove(node)
    out = N.new("ShaderNodeOutputMaterial")
    emit = N.new("ShaderNodeEmission")
    L.new(emit.outputs[0], out.inputs["Surface"])
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Position"], sep.inputs[0])
    stretch = N.new("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (1.0, 1.0, 0.62)
    L.new(geo.outputs["Position"], stretch.inputs["Vector"])
    fine = N.new("ShaderNodeTexNoise")          # flaky, broken edges
    fine.inputs["Scale"].default_value = 30.0
    fine.inputs["Detail"].default_value = 8.0
    fine.inputs["Roughness"].default_value = 0.7
    L.new(stretch.outputs[0], fine.inputs["Vector"])
    push = N.new("ShaderNodeVectorMath")
    push.operation = "SCALE"
    push.inputs["Scale"].default_value = 0.16
    L.new(fine.outputs["Color"], push.inputs[0])
    warped = N.new("ShaderNodeVectorMath")
    warped.operation = "ADD"
    L.new(stretch.outputs[0], warped.inputs[0])
    L.new(push.outputs[0], warped.inputs[1])
    patches = N.new("ShaderNodeTexNoise")       # the big frost patches: a third to a half of a blade wide
    patches.inputs["Scale"].default_value = 5.5
    patches.inputs["Detail"].default_value = 2.0
    L.new(warped.outputs[0], patches.inputs["Vector"])
    mask = N.new("ShaderNodeValToRGB")
    mask.color_ramp.elements[0].position = 0.56
    mask.color_ramp.elements[1].position = 0.68      # soft-edged highlights on about a fifth of the surface (the owner: "too much white ... mostly light blue with white glowy highlights")
    L.new(patches.outputs["Fac"], mask.inputs["Fac"])
    tip = N.new("ShaderNodeMapRange")
    tip.inputs["From Min"].default_value = 0.8
    tip.inputs["From Max"].default_value = 1.6
    L.new(sep.outputs["Z"], tip.inputs["Value"])
    bevel = N.new("ShaderNodeBevel")            # every sharp edge is frost-white
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
    a = N.new("ShaderNodeMath")
    a.operation = "MAXIMUM"
    L.new(mask.outputs["Color"], a.inputs[0])
    wear = N.new("ShaderNodeTexNoise")          # the edge line breaks up and varies in strength
    wear.inputs["Scale"].default_value = 9.0
    wear.inputs["Detail"].default_value = 4.0
    L.new(geo.outputs["Position"], wear.inputs["Vector"])
    worn = N.new("ShaderNodeMapRange")
    worn.inputs["From Min"].default_value = 0.38
    worn.inputs["From Max"].default_value = 0.62
    worn.inputs["To Min"].default_value = 0.15
    L.new(wear.outputs["Fac"], worn.inputs["Value"])
    broken = N.new("ShaderNodeMath")
    broken.operation = "MULTIPLY"
    L.new(edge.outputs[0], broken.inputs[0])
    L.new(worn.outputs[0], broken.inputs[1])
    L.new(broken.outputs[0], a.inputs[1])
    frost = N.new("ShaderNodeMath")
    frost.operation = "MAXIMUM"
    L.new(a.outputs[0], frost.inputs[0])
    L.new(tip.outputs[0], frost.inputs[1])
    depth = N.new("ShaderNodeTexNoise")         # the clear ice: two blues, slowly varying
    depth.inputs["Scale"].default_value = 3.0
    L.new(geo.outputs["Position"], depth.inputs["Vector"])
    clear = N.new("ShaderNodeMixRGB")
    clear.inputs["Color1"].default_value = (*S.lin(CLEAR_A), 1)
    clear.inputs["Color2"].default_value = (*S.lin(CLEAR_B), 1)
    L.new(depth.outputs["Fac"], clear.inputs["Fac"])
    colour = N.new("ShaderNodeMixRGB")
    colour.inputs["Color2"].default_value = (*S.lin(FROST), 1)
    # Inside the blue (the owner agreed the faces were too plain): long bright streaks running up the blade,
    # and a finer mottling, both only part-way to white.
    long = N.new("ShaderNodeMapping")
    long.inputs["Scale"].default_value = (1.0, 1.0, 0.07)
    L.new(geo.outputs["Position"], long.inputs["Vector"])
    streak = N.new("ShaderNodeTexNoise")
    streak.inputs["Scale"].default_value = 26.0
    streak.inputs["Detail"].default_value = 3.0
    L.new(long.outputs[0], streak.inputs["Vector"])
    streaks = N.new("ShaderNodeMapRange")
    streaks.inputs["From Min"].default_value = 0.56
    streaks.inputs["From Max"].default_value = 0.66
    streaks.inputs["To Max"].default_value = 0.7
    L.new(streak.outputs["Fac"], streaks.inputs["Value"])
    mott = N.new("ShaderNodeTexNoise")
    mott.inputs["Scale"].default_value = 15.0
    mott.inputs["Detail"].default_value = 6.0
    mott.inputs["Roughness"].default_value = 0.65
    L.new(warped.outputs[0], mott.inputs["Vector"])
    mottle = N.new("ShaderNodeMapRange")
    mottle.inputs["From Min"].default_value = 0.5
    mottle.inputs["From Max"].default_value = 0.7
    mottle.inputs["To Max"].default_value = 0.45
    L.new(mott.outputs["Fac"], mottle.inputs["Value"])
    inner = N.new("ShaderNodeMath")
    inner.operation = "MAXIMUM"
    L.new(streaks.outputs[0], inner.inputs[0])
    L.new(mottle.outputs[0], inner.inputs[1])
    total = N.new("ShaderNodeMath")
    total.operation = "MAXIMUM"
    L.new(frost.outputs[0], total.inputs[0])
    L.new(inner.outputs[0], total.inputs[1])
    L.new(total.outputs[0], colour.inputs["Fac"])
    L.new(clear.outputs[0], colour.inputs["Color1"])
    L.new(colour.outputs[0], emit.inputs["Color"])
    if gloss:
        # The GLOSS map (ice-10, for Roblox's SurfaceAppearance): glTF's packing, green = roughness, blue =
        # metalness. Clear ice is mirror-smooth (0.06), frost is matte (0.7); nothing is metal.
        rough = N.new("ShaderNodeMapRange")
        rough.inputs["To Min"].default_value = 0.06
        rough.inputs["To Max"].default_value = 0.7
        L.new(total.outputs[0], rough.inputs["Value"])
        pack = N.new("ShaderNodeCombineColor")
        pack.inputs[0].default_value = 1.0
        pack.inputs[2].default_value = 0.0
        L.new(rough.outputs[0], pack.inputs[1])
        L.new(pack.outputs[0], emit.inputs["Color"])
    target = N.new("ShaderNodeTexImage")
    target.image = image
    N.active = target
    return mat


def shown_material(path, gloss_path=None):
    """As Roblox shows a textured MeshPart: the image is the colour; no vertex colours, no tint."""
    mat = bpy.data.materials.new("Shown")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    N, L = mat.node_tree.nodes, mat.node_tree.links
    bsdf = N.get("Principled BSDF")
    tex = N.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=True)
    L.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.3
    bsdf.inputs["Specular IOR Level"].default_value = 0.6
    if gloss_path:
        orm = N.new("ShaderNodeTexImage")
        orm.image = bpy.data.images.load(gloss_path, check_existing=True)
        orm.image.colorspace_settings.name = "Non-Color"
        split = N.new("ShaderNodeSeparateColor")
        L.new(orm.outputs["Color"], split.inputs[0])
        L.new(split.outputs[1], bsdf.inputs["Roughness"])
        L.new(split.outputs[2], bsdf.inputs["Metallic"])
    return mat


S.new_scene()
scene = bpy.context.scene
kit = P.build_kit()
scene.render.engine = "CYCLES"
scene.cycles.samples = 8
scene.cycles.device = "CPU"
scene.render.bake.use_clear = False
scene.render.bake.margin = 8
paths = {}
gloss_paths = {}
for name in NAMES:
    mesh = kit[name]
    image = bpy.data.images.new("Tex_" + name, 1024, 1024, alpha=False)
    image.generated_color = (*S.lin(CLEAR_B), 1)
    obj = bpy.data.objects.new("Bake_" + name, mesh)
    scene.collection.objects.link(obj)
    for o in scene.objects:
        o.select_set(o is obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.015)
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh.materials.clear()
    mesh.materials.append(frost_material(image))
    bpy.ops.object.bake(type="EMIT")
    paths[name] = os.path.join(OUT, f"ice_tex_{name}.png")
    image.filepath_raw = paths[name]
    image.file_format = "PNG"
    image.save()
    gloss = bpy.data.images.new("Gloss_" + name, 512, 512, alpha=False)
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

scene.render.engine = "BLENDER_EEVEE"
S.floor("lobby")
S.fighter()
shown = {name: shown_material(paths[name], gloss_paths[name]) for name in NAMES}
for obj in S.glacier(kit, 0.6, table=FLOWER, centre=FLOWER_CENTRE, transparency=0.0):
    name = obj.name.split("_", 1)[1]
    obj.data.materials.clear()
    obj.data.materials.append(shown[name])
S.game_camera()
S.render(os.path.join(OUT, "tex_bake2_game.png"))
S.camera((11.0, 5.0, 5.5), (0.5, -8.5, 6.0), 34.0, "Close")
S.render(os.path.join(OUT, "tex_bake2_close.png"))
# Export for Roblox: the five pieces with their baked UVs and textures, NO vertex colours (the owner: models
# stay default grey; all colour comes from the texture).
import json  # noqa: E402
GLB = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "out", "export", "ice_kit_v4.glb")
exported, report = [], {}
for name in NAMES:
    mesh = kit[name].copy()
    mesh.name = name
    while mesh.color_attributes:
        mesh.color_attributes.remove(mesh.color_attributes[0])
    mesh.materials.clear()
    mat = shown_material(paths[name], gloss_paths[name])
    mat.name = name + "_Mat"
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    exported.append(obj)
    rep = P.mesh_report(mesh)
    rep["uv_layers"] = len(mesh.uv_layers)
    report[obj.name] = rep
for o in scene.objects:
    o.select_set(o in exported)
bpy.context.view_layer.objects.active = exported[0]
bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                          export_texcoords=True, export_normals=True, export_materials="EXPORT", export_vertex_color="NONE",
                          export_image_format="AUTO")
print("RESULT_JSON=" + json.dumps({"glb": GLB, "bytes": os.path.getsize(GLB), "pieces": report}))
