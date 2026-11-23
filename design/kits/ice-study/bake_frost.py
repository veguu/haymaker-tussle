"""The ice's frost texture, MADE IN BLENDER (2026-11-22; three script-computed images before it were not):
a procedural Cycles material on the five pieces, baked to one 1024 x 1024 atlas, then previewed on the flower.
  blender -b --factory-startup --python-exit-code 1 --python bake_frost.py -- <out dir>
The material (per piece, in the piece's own space so frost follows the crystal, not a tiling image):
  * frost mask: a Noise texture stretched along the crystal, pushed through a hard ColorRamp (ragged, flaky
    edges from a second, finer noise added to the coordinate);
  * edges: Cycles' Bevel node against the true normal marks every sharp edge; edges are frost-white;
  * tips: the upper part of each crystal is whiter;
  * clear ice: pale blue with a slow Voronoi variation (large soft facets inside the ice).
Writes frost_atlas.png, tex_bake_close.png and tex_bake_game.png.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import FLOWER, FLOWER_CENTRE  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1]
ATLAS = os.path.join(OUT, "frost_atlas.png")
PALER = [(182, 224, 244), (205, 236, 250), (225, 244, 253), (245, 252, 255)]
NAMES = ["Ice_SpikeTall", "Ice_SpikeThick", "Ice_Clump", "Ice_Block", "Ice_Shard"]
CELLS = {"Ice_SpikeTall": (0, 0), "Ice_SpikeThick": (1, 0), "Ice_Clump": (2, 0), "Ice_Block": (0, 1), "Ice_Shard": (1, 1)}   # 3 x 2 grid


def frost_material(image):
    mat = bpy.data.materials.new("FrostBake")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    for node in list(N):
        N.remove(node)
    out = N.new("ShaderNodeOutputMaterial")
    emit = N.new("ShaderNodeEmission")
    L.new(emit.outputs[0], out.inputs["Surface"])
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Position"], sep.inputs[0])
    # coordinates stretched along the crystal (z counts a quarter): long patches and streaks
    stretch = N.new("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (1.0, 1.0, 0.25)
    L.new(geo.outputs["Position"], stretch.inputs["Vector"])
    # flaky edges: a fine noise pushes the coordinate about
    fine = N.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 38.0
    fine.inputs["Detail"].default_value = 6.0
    L.new(stretch.outputs[0], fine.inputs["Vector"])
    push = N.new("ShaderNodeVectorMath")
    push.operation = "SCALE"
    push.inputs["Scale"].default_value = 0.10
    L.new(fine.outputs["Color"], push.inputs[0])
    warped = N.new("ShaderNodeVectorMath")
    warped.operation = "ADD"
    L.new(stretch.outputs[0], warped.inputs[0])
    L.new(push.outputs[0], warped.inputs[1])
    patches = N.new("ShaderNodeTexNoise")
    patches.inputs["Scale"].default_value = 7.0
    patches.inputs["Detail"].default_value = 3.0
    patches.inputs["Roughness"].default_value = 0.6
    L.new(warped.outputs[0], patches.inputs["Vector"])
    mask = N.new("ShaderNodeValToRGB")
    mask.color_ramp.interpolation = "LINEAR"
    mask.color_ramp.elements[0].position = 0.47
    mask.color_ramp.elements[1].position = 0.53
    L.new(patches.outputs["Fac"], mask.inputs["Fac"])
    # tips whiter: z from 0.55 up
    tip = N.new("ShaderNodeMapRange")
    tip.inputs["From Min"].default_value = 0.55
    tip.inputs["From Max"].default_value = 1.0
    L.new(sep.outputs["Z"], tip.inputs["Value"])
    # sharp edges: where the bevelled normal leaves the true normal
    bevel = N.new("ShaderNodeBevel")
    bevel.samples = 8
    bevel.inputs["Radius"].default_value = 0.022
    dot = N.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    L.new(bevel.outputs["Normal"], dot.inputs[0])
    L.new(geo.outputs["True Normal"], dot.inputs[1])
    edge = N.new("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.995
    edge.inputs["From Max"].default_value = 0.90
    L.new(dot.outputs["Value"], edge.inputs["Value"])
    # frost = patches, or an edge, or (partly) the tip
    half_tip = N.new("ShaderNodeMath")
    half_tip.operation = "MULTIPLY"
    half_tip.inputs[1].default_value = 0.7
    L.new(tip.outputs[0], half_tip.inputs[0])
    a = N.new("ShaderNodeMath")
    a.operation = "MAXIMUM"
    L.new(mask.outputs["Color"], a.inputs[0])
    L.new(edge.outputs[0], a.inputs[1])
    frost = N.new("ShaderNodeMath")
    frost.operation = "MAXIMUM"
    L.new(a.outputs[0], frost.inputs[0])
    L.new(half_tip.outputs[0], frost.inputs[1])
    # clear ice: pale blue, large soft facets
    facets = N.new("ShaderNodeTexVoronoi")
    facets.inputs["Scale"].default_value = 4.0
    L.new(stretch.outputs[0], facets.inputs["Vector"])
    clear = N.new("ShaderNodeMixRGB")
    clear.inputs["Color1"].default_value = (*S.lin((150, 205, 240)), 1)
    clear.inputs["Color2"].default_value = (*S.lin((196, 230, 250)), 1)
    L.new(facets.outputs["Color"], clear.inputs["Fac"])
    colour = N.new("ShaderNodeMixRGB")
    colour.inputs["Color2"].default_value = (1, 1, 1, 1)
    L.new(frost.outputs[0], colour.inputs["Fac"])
    L.new(clear.outputs[0], colour.inputs["Color1"])
    L.new(colour.outputs[0], emit.inputs["Color"])
    target = N.new("ShaderNodeTexImage")
    target.image = image
    N.active = target
    return mat


S.new_scene()
scene = bpy.context.scene
kit = P.build_kit()
image = bpy.data.images.new("FrostAtlas", 1024, 1024, alpha=False)
image.generated_color = (*S.lin((196, 230, 250)), 1)     # the clear tone everywhere, so no dark fringe at island edges
bake_mat = frost_material(image)
scene.render.engine = "CYCLES"
scene.cycles.samples = 8
scene.cycles.device = "CPU"
scene.render.bake.use_clear = False
scene.render.bake.margin = 6
objects = {}
for name in NAMES:
    mesh = kit[name]
    obj = bpy.data.objects.new("Bake_" + name, mesh)
    scene.collection.objects.link(obj)
    objects[name] = obj
    for o in scene.objects:
        o.select_set(o is obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    cx, cy = CELLS[name]
    for loop in mesh.uv_layers.active.data:      # into its cell of the 3 x 2 atlas
        loop.uv = ((loop.uv[0] * 0.96 + 0.02 + cx) / 3.0, (loop.uv[1] * 0.96 + 0.02 + cy) / 2.0)
    mesh.materials.clear()
    mesh.materials.append(bake_mat)
    bpy.ops.object.bake(type="EMIT")
image.filepath_raw = ATLAS
image.file_format = "PNG"
image.save()
for obj in objects.values():
    bpy.data.objects.remove(obj)

# Preview: the flower with the baked atlas, as the game would show it (solid, paler part colours).
scene.render.engine = "BLENDER_EEVEE"
S.ICE = PALER
S.TEXTURE = ATLAS
S.floor("lobby")
S.fighter()
S.glacier(kit, 0.6, table=FLOWER, centre=FLOWER_CENTRE, transparency=0.0)
S.game_camera()
S.render(os.path.join(OUT, "tex_bake_game.png"))
S.camera((11.0, 5.0, 5.5), (0.5, -8.5, 6.0), 34.0, "Close")
S.render(os.path.join(OUT, "tex_bake_close.png"))
print("RESULT_JSON={}")
