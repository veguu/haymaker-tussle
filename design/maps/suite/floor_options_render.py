"""Renders the four floor options (floor_options.py) on the arena's oval the way Roblox would layer them, from the
game's camera, at the feet and wide, with R15-sized fighters for scale:

    blender -b --factory-startup -P floor_options_render.py -- <floor_options folder>

Each floor = its large-scale colour map (base_<x>.png across the oval) with the repeating detail (detail_<x>.png, RGBA,
tiled every tile_studs) laid OVER it by its alpha: the same sum as a Roblox `Texture` on the floor tiles. EEVEE, a
warm sun like Quarry's, a plain sky. Writes render_<x>_<view>.png.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
meta = json.load(open(os.path.join(out, "options.json"), encoding="utf-8"))
A, B = 213.0, 176.0

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys() else "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"

world = bpy.data.worlds.new("Sky")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.42, 0.62, 0.92, 1.0)
bg.inputs["Strength"].default_value = 0.55

sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 2.4
sun_data.color = (1.0, 0.89, 0.75)
sun_data.angle = math.radians(3)
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(-55))

# the oval floor
n = 256
verts = [(A * math.cos(2 * math.pi * i / n), B * math.sin(2 * math.pi * i / n), 0.0) for i in range(n)]
me = bpy.data.meshes.new("Floor")
me.from_pydata(verts, [], [list(range(n))])
me.update()
uv = me.uv_layers.new(name="UVMap")
for loop in me.loops:
    x, y, _ = me.vertices[loop.vertex_index].co
    uv.data[loop.index].uv = (x / (2 * A) + 0.5, y / (2 * B) + 0.5)
floor = bpy.data.objects.new("Floor", me)
scene.collection.objects.link(floor)


def floor_material(key, tile):
    mat = bpy.data.materials.new(f"Floor_{key}")
    mat.use_nodes = True
    nt = mat.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    outp = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.95
    base = nt.nodes.new("ShaderNodeTexImage")
    base.image = bpy.data.images.load(os.path.join(out, f"base_{key}.png"))
    base.interpolation = "Linear"
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1 / tile, 1 / tile, 1 / tile)
    detail = nt.nodes.new("ShaderNodeTexImage")
    detail.image = bpy.data.images.load(os.path.join(out, f"detail_{key}.png"))
    detail.interpolation = "Linear"
    detail.extension = "REPEAT"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], detail.inputs["Vector"])
    nt.links.new(detail.outputs["Alpha"], mix.inputs["Factor"])
    nt.links.new(base.outputs["Color"], mix.inputs["A"])
    nt.links.new(detail.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], outp.inputs["Surface"])
    return mat


def solid(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[(c / 255) ** 2.2 for c in rgb], 1.0)
    p.inputs["Roughness"].default_value = 0.8
    return m


def box(name, size, at, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.data.materials.append(mat)
    return o


def fighter(x, y, shirt, pants, skin, face=0.0):
    """A blocky R15-sized figure (5 studs): legs 2, torso 2, head 1.2, arms."""
    ms, mp, mk = solid("shirt", shirt), solid("pants", pants), solid("skin", skin)
    parts = [
        box("legL", (0.9, 0.9, 2.0), (x - 0.5, y, 1.0), mp), box("legR", (0.9, 0.9, 2.0), (x + 0.5, y, 1.0), mp),
        box("torso", (2.0, 1.0, 2.0), (x, y, 3.0), ms), box("head", (1.2, 1.2, 1.2), (x, y, 4.65), mk),
        box("armL", (0.9, 0.9, 2.0), (x - 1.45, y, 3.0), ms), box("armR", (0.9, 0.9, 2.0), (x + 1.45, y, 3.0), ms),
    ]
    for p in parts:
        p.rotation_euler = (0, 0, face)
        p.location = Vector((x, y, p.location.z)) + (p.location - Vector((x, y, p.location.z))).copy()
    return parts


fighter(0, 0, (220, 60, 50), (40, 50, 90), (238, 196, 160))
fighter(-8, 22, (60, 110, 220), (60, 60, 70), (198, 140, 100))
fighter(10, 40, (240, 140, 40), (90, 60, 40), (150, 100, 70))
fighter(-22, 70, (90, 190, 90), (50, 50, 60), (232, 184, 150))
fighter(30, 95, (230, 200, 60), (70, 70, 120), (120, 80, 60))

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
VIEWS = {
    "game": ((0.0, -15.0, 9.0), (0.0, 12.0, 2.0), 70),  # the game's camera behind a fighter
    "feet": ((7.0, -9.0, 7.5), (1.0, 1.0, 0.5), 55),  # looking down at the fighter's feet
    "wide": ((0.0, -150.0, 6.0), (0.0, 200.0, 0.0), 70),  # eye height, across the arena
}


def aim(loc, target, fov):
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam_data.angle = math.radians(fov)


for key, m in meta.items():
    floor.data.materials.clear()
    floor.data.materials.append(floor_material(key, m["tile_studs"]))
    for view, (loc, target, fov) in VIEWS.items():
        aim(loc, target, fov)
        scene.render.filepath = os.path.join(out, f"render_{key}_{view}.png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", key, view, flush=True)
