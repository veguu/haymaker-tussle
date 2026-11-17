"""Shows the eight class idles (build_class_idles.py) on exact R6 dummies in their own Blender scene. Run inside
Blender. One dummy a class, side by side, each looping its own idle. Nothing here saves a file, and no other
scene is changed. Re-running replaces the scene.
"""
import importlib.util
import math
import os

import bpy
from mathutils import Matrix

PROJECT_ANIMS = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else PROJECT_ANIMS
SCENE_NAME = "HT_ClassIdles"
SPACING = 8
FPS = 60
SECONDS = 12
FEET_UP = 3
AIR_LIFT = {}

spec = importlib.util.spec_from_file_location("ht_class_idles", os.path.join(PROJECT_ANIMS, "build_class_idles.py"))
idles_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(idles_module)
clips_module = idles_module.B
CLIPS = idles_module.bake_all()

# Roblox (x, y up, -z forward) to Blender (x, z up, +y forward).
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def sample(clip, time):
    """A clip's pose at a time, between its baked frames."""
    frames = clip["frames"]
    time = time % clip["seconds"]
    for index in range(len(frames) - 1):
        first, second = frames[index], frames[index + 1]
        if time <= second["t"]:
            span = second["t"] - first["t"]
            amount = (time - first["t"]) / span if span > 0 else 0
            pose = {}
            for joint, values in first["pose"].items():
                other = second["pose"][joint]
                pose[joint] = tuple(values[i] + (other[i] - values[i]) * amount for i in range(6))
            return pose
    return dict(frames[-1]["pose"])


DUMMIES = [(name, (lambda time, clip=clip: sample(clip, time))) for name, clip in reversed(list(CLIPS.items()))]

COLOURS = {
    "Torso": (0.13, 0.15, 0.2, 1),
    "Head": (0.95, 0.8, 0.55, 1),
    "Right Arm": (0.85, 0.25, 0.2, 1),
    "Left Arm": (0.2, 0.45, 0.85, 1),
    "Right Leg": (0.55, 0.57, 0.62, 1),
    "Left Leg": (0.38, 0.4, 0.45, 1),
}


def box_mesh(name, size):
    x, y, z = size[0] / 2, size[2] / 2, size[1] / 2  # Roblox (w, h, d) as Blender (x, depth, height)
    verts = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return mesh


def material(name, colour):
    made = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    made.diffuse_color = colour
    return made


old = bpy.data.scenes.get(SCENE_NAME)
if old:
    for thing in list(old.objects):
        bpy.data.objects.remove(thing, do_unlink=True)
    bpy.data.scenes.remove(old)

scene = bpy.data.scenes.new(SCENE_NAME)
scene.render.fps = FPS
scene.frame_start = 1
scene.frame_end = round(FPS * SECONDS)
scene.sync_mode = "AUDIO_SYNC" if False else "FRAME_DROP"

for index, (label, pose_of) in enumerate(DUMMIES):
    offset = (index - (len(DUMMIES) - 1) / 2) * SPACING
    parts = {}
    for name, size in clips_module.SIZES.items():
        obj = bpy.data.objects.new(f"{label} {name}", box_mesh(f"HT_{name}", size))
        obj.data.materials.append(material(f"HT_{name}", COLOURS[name]))
        obj.rotation_mode = "QUATERNION"
        scene.collection.objects.link(obj)
        parts[name] = obj

    # A nose, so which way the head faces is obvious.
    nose = bpy.data.objects.new(f"{label} nose", box_mesh("HT_nose", (0.5, 0.3, 0.3)))
    nose.data.materials.append(material("HT_nose", (0.1, 0.1, 0.1, 1)))
    scene.collection.objects.link(nose)
    nose.parent = parts["Head"]
    nose.location = (0, 0.6, 0)

    words = bpy.data.curves.new(f"{label} label", "FONT")
    words.body = label
    words.size = 0.9
    words.align_x = "CENTER"
    text = bpy.data.objects.new(f"{label} label", words)
    text.location = (offset, 0, 6.2 + AIR_LIFT.get(label, 0))
    text.rotation_euler = (math.pi / 2, 0, math.radians(170))
    scene.collection.objects.link(text)

    for frame in range(scene.frame_start, scene.frame_end + 1):
        time = (frame - 1) / FPS
        transforms = clips_module.part_transforms(pose_of(time))
        for name, (rot, pos) in transforms.items():
            rotation = P @ Matrix(rot) @ P.transposed()
            obj = parts[name]
            obj.location = (offset + pos[0], -pos[2], FEET_UP + AIR_LIFT.get(label, 0) + pos[1])
            obj.rotation_quaternion = rotation.to_quaternion()
            obj.keyframe_insert("location", frame=frame)
            obj.keyframe_insert("rotation_quaternion", frame=frame)

ground = bpy.data.objects.new("HT_ground", box_mesh("HT_ground", (76, 0.02, 14)))
ground.data.materials.append(material("HT_ground", (0.5, 0.55, 0.6, 1)))
ground.location = (0, 0, -0.01)
scene.collection.objects.link(ground)

window = bpy.context.window_manager.windows[0]
window.scene = scene
scene.frame_set(1)

from mathutils import Quaternion

for area in window.screen.areas:
    if area.type == "VIEW_3D":
        region = area.spaces.active.region_3d
        region.view_perspective = "PERSP"
        region.view_location = (0, 0, 3.5)
        region.view_distance = 58
        tilt = Matrix.Rotation(math.radians(78), 4, "X").to_quaternion()
        region.view_rotation = Quaternion((0, 0, 1), math.radians(170)) @ tilt
        area.spaces.active.shading.type = "SOLID"
        area.spaces.active.shading.color_type = "MATERIAL"
        area.spaces.active.shading.light = "STUDIO"
        area.spaces.active.overlay.show_overlays = False


def start_playing():
    # Playback only runs when started from Blender's main loop, not from the MCP call.
    w = bpy.context.window_manager.windows[0]
    a = next(x for x in w.screen.areas if x.type == "VIEW_3D")
    r = next(x for x in a.regions if x.type == "WINDOW")
    with bpy.context.temp_override(window=w, screen=w.screen, area=a, region=r):
        if not w.screen.is_animation_playing:
            bpy.ops.screen.animation_play()
    return None


bpy.app.timers.register(start_playing, first_interval=0.3)
