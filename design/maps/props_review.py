"""Review renders of the scenery kit, one per family row (EEVEE, the kit's sun and sky, a neutral ground).

    blender -b <out>/gnomon_props.blend -P props_review.py -- <out folder> [Family ...]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1 :]
out = os.path.abspath(args[0])
only = args[1:]
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.view_settings.view_transform = "Standard"
ground = bpy.data.objects.get("ReviewGround")
if not ground:
    me = bpy.data.meshes.new("ReviewGround")
    s = 2000
    me.from_pydata([(-s, -s, -0.02), (s, -s, -0.02), (s, s, -0.02), (-s, s, -0.02)], [], [(0, 1, 2, 3)])
    ground = bpy.data.objects.new("ReviewGround", me)
    scene.collection.objects.link(ground)
    mat = bpy.data.materials.new("ReviewGround")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.30, 0.28, 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
    me.materials.append(mat)
fams = {}
for col in bpy.data.collections["PropKit"].children:
    fams[col.name[4:]] = [o for o in col.objects]
cam_data = bpy.data.cameras.new("ReviewCam")
cam = bpy.data.objects.new("ReviewCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
for fam, objs in fams.items():
    if only and fam not in only:
        continue
    for f2, o2 in fams.items():  # only this family in the shot
        for o in o2:
            o.hide_render = f2 != fam
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    mid = (lo + hi) / 2
    span = max(hi.x - lo.x, (hi.z - lo.z) * 1.8)
    cam_data.lens = 40
    dist = span * 1.05
    cam.location = mid + Vector((0, -dist, dist * 0.45))
    cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(out, f"review_{fam.lower()}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER", scene.render.filepath)
