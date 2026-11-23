"""Builds animations/camera/dash_scene.blend from the game's own maths and PROVES it.

  lune run lune/camera_scene
  blender.exe -b --factory-startup --python-exit-code 1 --python animations/camera/build_scene.py

The scene is Haymaker Rush from 4.20 to 5.00 s in ANCHOR space, moved to Blender by the rig's axis map
(Roblox (x, y, z) -> Blender (-x, z, y)). TIME: the scene runs at 100 frames a second and FRAME = cutscene
seconds x 100, so every beat is a whole frame (the cut 432, load 440, take-off 470, FACE 482, release 486,
contact 493). The exporter and the videos sample it at 60 fps.

Proofs (exit 1, nothing saved, if one fails):
  a. the fist: on every frame the rig's fist is where the game's maths puts it, and on the contact frame it is
     inside the target's torso box.
  b. today's camera: both roots land on the same screen spots as the game's maths (the controller's camera:
     CFrame.lookAt * CFrame.Angles(0, 0, roll)), within 0.5 % of the frame, on every frame, and the OTHER roll
     direction does not.
"""
import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "hand"))
sys.path.insert(0, HERE)
import r6_rig  # noqa: E402
import camera_kit  # noqa: E402

M = r6_rig.M
with open(os.path.join(HERE, "out", "scene.json"), encoding="utf-8") as source:
    DATA = json.load(source)
FRAMES = DATA["frames"]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
camera_kit.setup_scene(scene)


def make_fighter(name, tint):
    rig, body = r6_rig.build_rig()
    rig.name, body.name = name, name + "_Body"
    rig.data.name, body.data.name = name, name + "_Body"
    rig.location = (0, 0, 0)
    rig.rotation_mode = "QUATERNION"
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for slot in body.material_slots:
        mat = slot.material.copy()
        mat.name = name + slot.material.name[2:]
        if tint:
            colour = [c * (1 - tint[3]) + t * tint[3] for c, t in zip(mat.diffuse_color[:3], tint[:3])] + [1]
            mat.diffuse_color = colour
            bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
            if bsdf:
                bsdf.inputs["Base Color"].default_value = colour
        slot.material = mat
    return rig, body


attacker, attacker_body = make_fighter("Attacker", None)
target, target_body = make_fighter("Target", (0.75, 0.12, 0.12, 0.6))  # the target reads red

previous = {}


def key_matrix(owner, matrix, frame, tag):
    """Location + quaternion keys (linear), the quaternion kept in one hemisphere from frame to frame."""
    loc, quat, _ = matrix.decompose()
    last = previous.get(tag)
    if last is not None and last.dot(quat) < 0:
        quat.negate()
    previous[tag] = quat.copy()
    owner.location, owner.rotation_quaternion = loc, quat
    owner.keyframe_insert("location", frame=frame)
    owner.keyframe_insert("rotation_quaternion", frame=frame)


today = camera_kit.new_camera(scene, "Cam_today")
for sample in FRAMES:
    frame = camera_kit.frame_of(sample["t"])
    for rig, root_key, joints_key in ((attacker, "attackerRoot", "attacker"), (target, "targetRoot", "target")):
        key_matrix(rig, M @ camera_kit.cframe(sample[root_key]) @ M.inverted(), frame, rig.name)
        for bone, numbers in sample[joints_key].items():
            key_matrix(rig.pose.bones[bone], camera_kit.cframe(numbers), frame, rig.name + bone)
    camera_kit.key_camera(today, frame, sample["cam"], sample["look"], sample["fov"], sample["roll"], hold=True)

for ob in (attacker, target):
    for fc in camera_kit.fcurves_of(ob):
        for point in fc.keyframe_points:
            point.interpolation = "LINEAR"
        fc.update()

# The attacker's body is hidden but for the striking arm from RELEASE (line.soloArm): remembered on the scene.
solo = [camera_kit.frame_of(s["t"]) for s in FRAMES if s["soloArm"]]
scene["ht_solo_from"] = min(solo) if solo else -1
scene["ht_from"], scene["ht_to"] = camera_kit.frame_of(DATA["from"]), camera_kit.frame_of(DATA["to"])
scene.frame_start, scene.frame_end = scene["ht_from"], scene["ht_to"]
scene.camera = today

failures = []

# ---- Proof a: the fist.
worst_fist = 0.0
contact = None
for sample in FRAMES:
    frame = camera_kit.frame_of(sample["t"])
    scene.frame_set(frame)
    tip = camera_kit.to_roblox(r6_rig.fist_world(attacker))
    worst_fist = max(worst_fist, (tip - Vector(sample["fist"])).length)
    if abs(sample["t"] - 4.93) < 1e-6:
        local = camera_kit.part_point(target, "Torso", r6_rig.fist_world(attacker))
        gap = math.sqrt(sum(max(abs(v) - half, 0) ** 2 for v, half in zip(local, (1, 1, 0.5))))
        contact = (frame, local, gap, sample["fistInTorso"], sample["fistGap"])
print(f"PROOF a: fist vs the game's maths, worst over {len(FRAMES)} frames: {worst_fist:.6f} studs")
frame, local, gap, game_local, game_gap = contact
print(f"PROOF a: contact frame {frame}: fist in the target's torso box at ({local[0]:.3f}, {local[1]:.3f}, {local[2]:.3f}), "
      f"gap {gap:.4f}; the game: ({game_local[0]:.3f}, {game_local[1]:.3f}, {game_local[2]:.3f}), gap {game_gap:.4f}")
if worst_fist > 0.001 or gap > 0.001:
    failures.append("proof a")

# ---- Proof b: today's camera, and which way roll turns.
def screen_error(flip_roll):
    worst, worst_at, count = 0.0, None, 0
    if flip_roll:
        for sample in FRAMES:
            camera_kit.key_camera(today, camera_kit.frame_of(sample["t"]), sample["cam"], sample["look"],
                                  sample["fov"], -sample["roll"], hold=True)
    for sample in FRAMES:
        frame = camera_kit.frame_of(sample["t"])
        scene.frame_set(frame)
        for rig, key in ((attacker, "attackerOnScreen"), (target, "targetOnScreen")):
            x, y, depth = sample[key]
            if depth <= 0.1:
                continue
            view = world_to_camera_view(scene, today, rig.matrix_world.translation)
            error = max(abs((view.x * 2 - 1) - x), abs((view.y * 2 - 1) - y)) / 2 * 100  # % of the frame
            count += 1
            if error > worst:
                worst, worst_at = error, (sample["t"], rig.name)
    if flip_roll:
        for sample in FRAMES:
            camera_kit.key_camera(today, camera_kit.frame_of(sample["t"]), sample["cam"], sample["look"],
                                  sample["fov"], sample["roll"], hold=True)
    return worst, worst_at, count


worst, at, count = screen_error(False)
print(f"PROOF b: both roots on screen vs the game's maths, {count} points on {len(FRAMES)} frames "
      f"(the cuts at 4.32 and 4.82 and the rolled whip included): worst {worst:.4f} % of the frame at {at}")
flipped, flipped_at, _ = screen_error(True)
print(f"PROOF b: with roll turned the OTHER way: worst {flipped:.4f} % at {flipped_at}  (so +roll = Blender camera "
      f"turned +roll about its own +Z, the way CFrame.Angles(0, 0, roll) turns it: the picture tips clockwise)")
if worst > 0.5 or flipped < worst * 5:
    failures.append("proof b")

if failures:
    print("FAILED:", failures)
    sys.exit(1)
scene.frame_set(scene["ht_from"])
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "dash_scene.blend"))
print("SAVED dash_scene.blend")
