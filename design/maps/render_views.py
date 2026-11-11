"""Renders chosen cameras of a built arena .blend (EEVEE, the scene's own lighting).

    blender -b out/<map>/<map>.blend -P render_views.py -- <out folder> <prefix> [Camera ...] [--size 1280x720]

With no camera names it renders all five (Gameplay, Floor, Edge, Recovery, Overview).
"""
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1 :]
out, prefix = os.path.abspath(args[0]), args[1]
size = (1280, 720)
names = []
rest = args[2:]
i = 0
while i < len(rest):
    if rest[i] == "--size":
        w, h = rest[i + 1].split("x")
        size = (int(w), int(h))
        i += 2
    else:
        names.append(rest[i])
        i += 1
names = names or ["Gameplay", "Floor", "Edge", "Recovery", "Overview"]
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = size
scene.render.image_settings.file_format = "PNG"
os.makedirs(out, exist_ok=True)
for name in names:
    cam = bpy.data.objects.get(name)
    if cam is None:
        print("NO CAMERA", name)
        continue
    scene.camera = cam
    scene.render.filepath = os.path.join(out, f"{prefix}_{name.lower()}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER", scene.render.filepath)
