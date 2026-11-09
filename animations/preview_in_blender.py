"""Shows the baked clips on exact R6 dummies in their own Blender scene. Run inside Blender.

Eight dummies side by side, looping: Sprint, Brake, punches standing, punches while sprinting,
the idle, and the air kick's clips in order, held up off the floor as they would be in the game.
Nothing here saves a file, and no other scene is changed. Re-running replaces the scene.
"""
import importlib.util
import math
import os

import bpy
from mathutils import Matrix

PROJECT_ANIMS = r"C:\Users\dumpl\Documents\LihFolk\LihFolk Vault V2\LihFolk Vault V2\Haymaker Tussle\Project\animations"
SCENE_NAME = "HT_Anims"
SPACING = 9
FPS = 60
SECONDS = 5.1
FEET_UP = 3

spec = importlib.util.spec_from_file_location("ht_build_clips", os.path.join(PROJECT_ANIMS, "build_clips.py"))
clips_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clips_module)
CLIPS = clips_module.bake_all()

# Roblox (x, y up, -z forward) to Blender (x, z up, +y forward).
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def sample(clip, time):
    """A clip's pose at a time, between its baked frames."""
    frames = clip["frames"]
    if clip["loop"]:
        time = time % clip["seconds"]
    time = min(time, clip["seconds"])
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


SWING_EVERY = 0.85
SWINGS = ("HookLeft", "HookRight", "Uppercut")


def swing_pose(time, suffix):
    """The three swings in turn, each thrown at the start of its slot."""
    slot = int(time / SWING_EVERY)
    clip = CLIPS[SWINGS[slot % len(SWINGS)] + suffix]
    return sample(clip, min(time - slot * SWING_EVERY, clip["seconds"]))


def pose_stance(time):
    return sample(CLIPS["Stance"], time)


def pose_sprint(time):
    return sample(CLIPS["Sprint"], time)


def pose_brake(time):
    return sample(CLIPS["Brake"], time)


def pose_swings(time):
    pose = dict(pose_stance(time))
    pose.update(swing_pose(time, ""))
    return pose


def pose_both(time):
    pose = dict(pose_sprint(time))
    pose.update(swing_pose(time, "Run"))
    return pose


AIR_KICK = (("KickLeap", 0.6), ("KickAim", 0.3), ("KickSpin", 0.28), ("KickDown", 0.5))
REACTIONS = (("HitFlinch", 0.28), ("Stance", 0.3), ("HitFlinchHeavy", 0.46), ("HitSkid", 0.4), ("Stance", 0.3), ("HitFlinchBack", 0.34), ("AirTumble", 0.6), ("Slammed", 0.3), ("FloorHit", 0.26), ("AirTumble", 0.4), ("Land", 0.3))
STOPPING = (("Sprint", 1.066), ("Brake", 0.6), ("BrakeSettle", 0.4), ("Stance", 0.6))
AIR_KICK_SECONDS = sum(seconds for _, seconds in AIR_KICK)
AIR_LIFT = {"Air kick": 5}


def pose_air_kick(time):
    """The jump, hanging on while the ring closes, the front flip, the kick, then a short rest."""
    left = time % (AIR_KICK_SECONDS + 0.4)
    for name, seconds in AIR_KICK:
        if left < seconds:
            return sample(CLIPS[name], left)
        left -= seconds
    return sample(CLIPS["KickDown"], CLIPS["KickDown"]["seconds"])


def in_order(sequence, time, rest=0.0):
    """Clips one after another, looping."""
    total = sum(seconds for _, seconds in sequence) + rest
    left = time % total
    for name, seconds in sequence:
        if left < seconds:
            return sample(CLIPS[name], left)
        left -= seconds
    return sample(CLIPS[sequence[-1][0]], sequence[-1][1])


def pose_reactions(time):
    return in_order(REACTIONS, time, 0.3)


def pose_stopping(time):
    return in_order(STOPPING, time)


DUMMIES = [
    ("Air kick", pose_air_kick),
    ("Hit reactions", pose_reactions),
    ("Run, brake, settle", pose_stopping),
    ("Sprint + swings", pose_both),
    ("Sprint", pose_sprint),
    ("Brake", pose_brake),
    ("Swings", pose_swings),
    ("Idle", pose_stance),
]

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

ground = bpy.data.objects.new("HT_ground", box_mesh("HT_ground", (84, 0.02, 14)))
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
        region.view_distance = 66
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
