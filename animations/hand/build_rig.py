"""Builds animations/hand/r6_rig.blend and PROVES the rig is the game's Motor6D maths.

  blender.exe -b --factory-startup --python-exit-code 1 --python animations/hand/build_rig.py

Three checks, all must pass or the script exits 1 and writes no file:
  1. Rest: every bone's rest matrix is the joint frame it was given (bone roll survived).
  2. Forward: with a clip pose on the channels, every part sits where build_clips.part_transforms
     (the game's maths, written independently) says it should.
  3. Round trip: Guard (every frame) and HookRight (every frame) are keyed onto the rig, read back
     through the exporter's sampler, and must match within 0.01 degrees and 0.001 studs.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r6_rig  # noqa: E402
from hand_actions import new_clip, key_pose  # noqa: E402

MAX_DEGREES = 0.01
MAX_STUDS = 0.001

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = r6_rig.FPS
rig, body = r6_rig.build_rig()
bpy.context.view_layer.update()

failures = []

# 1. Rest frames.
rest = r6_rig.rest_frames()
worst = 0.0
for name in r6_rig.BONES:
    got = rig.data.bones[name].matrix_local
    worst = max(worst, max(abs(got[r][c] - rest[name][r][c]) for r in range(4) for c in range(4)))
print(f"REST worst matrix difference {worst:.2e}")
if worst > 1e-5:
    failures.append(f"rest frames differ by {worst}")

clips = r6_rig.build_clips.bake_all()


def matrix_of(transform):
    return r6_rig.frame4(*transform)


# 2. Forward kinematics against the game's own maths.
worst_rot = worst_pos = 0.0
tested = 0
for clip_name in ("Guard", "HookRight", "Sprint", "KickSpin", "Slammed"):
    for frame in clips[clip_name]["frames"]:
        r6_rig.set_pose(rig, frame["pose"])
        bpy.context.view_layer.update()
        expected = r6_rig.build_clips.part_transforms(frame["pose"])
        got = r6_rig.part_matrices(rig)
        for name in r6_rig.BONES:
            want = matrix_of(expected[name])
            have = got[name]
            worst_pos = max(worst_pos, (want.translation - have.translation).length)
            worst_rot = max(worst_rot, max(abs(want[r][c] - have[r][c]) for r in range(3) for c in range(3)))
        tested += 1
print(f"FORWARD {tested} poses: worst position {worst_pos:.2e} studs, worst rotation-matrix entry {worst_rot:.2e}")
if worst_pos > 1e-4 or worst_rot > 1e-5:
    failures.append(f"forward kinematics differ: {worst_pos} studs, {worst_rot}")

# 3. Round trip through keys and the exporter's sampler.
report = []
for clip_name in ("Guard", "HookRight"):
    clip = clips[clip_name]
    r6_rig.set_pose(rig, {})
    action, bag = new_clip(rig, "RT_" + clip_name)
    numbers = []
    for frame in clip["frames"]:
        number = 1 + frame["t"] * r6_rig.FPS
        numbers.append(number)
        key_pose(bag, number, frame["pose"], interpolation="LINEAR")
    worst_deg = worst_studs = worst_matrix = 0.0
    previous = {}
    for number, frame in zip(numbers, clip["frames"]):
        scene.frame_set(int(math.floor(number)), subframe=number - math.floor(number))
        for name, values in frame["pose"].items():
            matrix = r6_rig.local_transform(rig, name)
            got = r6_rig.read_values(matrix, previous.get(name, values[:3]))
            previous[name] = got[:3]
            for i in range(3):
                # The same rotation can be written a whole turn apart (the baked clip itself wraps): compare mod 360.
                worst_deg = max(worst_deg, abs((got[i] - values[i] + 180) % 360 - 180))
            for i in range(3, 6):
                worst_studs = max(worst_studs, abs(got[i] - values[i]))
            want = r6_rig.frame4(r6_rig.build_clips.angles(*values[:3]), values[3:6])
            worst_matrix = max(worst_matrix, max(abs(want[r][c] - matrix[r][c]) for r in range(3) for c in range(4)))
    line = (
        f"ROUNDTRIP {clip_name}: {len(numbers)} frames, joints {sorted(clip['frames'][0]['pose'])}, "
        f"worst {worst_deg:.5f} degrees, {worst_studs:.6f} studs, matrix entry {worst_matrix:.2e}"
    )
    print(line)
    report.append(line)
    if worst_deg > MAX_DEGREES or worst_studs > MAX_STUDS:
        failures.append(line)
    bpy.data.actions.remove(action)

if failures:
    print("FAILED:")
    for failure in failures:
        print("  ", failure)
    sys.exit(1)

r6_rig.set_pose(rig, {})
scene.frame_set(1)
target = os.path.join(r6_rig.HERE, "r6_rig.blend")
bpy.ops.wm.save_as_mainfile(filepath=target)
print("SAVED", target)
