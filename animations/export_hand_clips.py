"""Hand-keyed clips: Blender -> src/shared/Config/AnimClipsHand.luau.

  blender.exe -b --factory-startup --python-exit-code 1 --python animations/export_hand_clips.py

Opens every .blend in animations/hand/ (except the bare rig) and exports every action that carries
`ht_start` / `ht_end`. Each frame the rig is EVALUATED (curves, constraints, anything) and every
keyed joint's Motor6D Transform is read back from the bone matrices, so what is exported is what
Blender shows. Same clip data and the same thinning as animations/build_clips.py, in its own module:
build_clips.py never touches this file, and this never touches AnimClips.luau.

Action properties: ht_start, ht_end (frames), ht_loop, ht_priority, ht_strike_frame (optional).
Also writes animations/hand/out/<Clip>.dense.json (every frame, before thinning) for the checks.
"""
import glob
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
HAND = os.path.join(HERE, "hand")
sys.path.insert(0, HAND)
import r6_rig  # noqa: E402
from hand_actions import channelbag_of, keyed_bones  # noqa: E402

bc = r6_rig.build_clips
TARGET = os.path.join(os.path.dirname(HERE), "src", "shared", "Config", "AnimClipsHand.luau")


def export_action(scene, rig, action):
    data = rig.animation_data
    data.action = action
    data.action_slot = action.slots[0]
    bag = channelbag_of(rig)
    bones = [name for name in r6_rig.BONES if name in keyed_bones(bag)]
    first, last = int(action["ht_start"]), int(action["ht_end"])
    strike = action.get("ht_strike_frame")
    frames, previous = [], {}
    for number in range(first, last + 1):
        scene.frame_set(number)
        pose = {}
        for name in bones:
            values = r6_rig.read_values(r6_rig.local_transform(rig, name), previous.get(name))
            previous[name] = values[:3]
            pose[name] = tuple(round(v, 6) for v in values)
        frames.append({"t": (number - first) / r6_rig.FPS, "pose": pose})
    clip = {
        "loop": bool(action.get("ht_loop", False)),
        "priority": str(action.get("ht_priority", "Action2")),
        "seconds": (last - first) / r6_rig.FPS,
        "frames": frames,
    }
    if strike is not None:
        clip["strike"] = (float(strike) - first) / r6_rig.FPS
    return clip


clips = {}
for path in sorted(glob.glob(os.path.join(HAND, "*.blend"))):
    if os.path.basename(path) == "r6_rig.blend":
        continue
    bpy.ops.wm.open_mainfile(filepath=path)
    scene = bpy.context.scene
    rig = bpy.data.objects[r6_rig.RIG_NAME]
    for action in bpy.data.actions:
        if "ht_start" not in action or not action.slots:
            continue
        assert action.name not in clips, f"two actions are called {action.name}"
        clip = export_action(scene, rig, action)
        os.makedirs(os.path.join(HAND, "out"), exist_ok=True)
        with open(os.path.join(HAND, "out", action.name + ".dense.json"), "w", encoding="utf-8") as out:
            json.dump(clip, out)
        dense = len(clip["frames"])
        # Short clips keep every frame: thinning makes the keys uneven, and the Animator then blends
        # rotations differently (vault: Blender Mastery 1, section 6). Only long clips are thinned.
        clips[action.name] = bc.simplify(clip) if clip["seconds"] >= 1.0 else clip
        print(f"CLIP {action.name}: {dense} frames sampled, {len(clip['frames'])} kept, "
              f"{clip['seconds']:.3f} s, strike {clip.get('strike')}, joints {sorted(clip['frames'][0]['pose'])}")

assert clips, "no hand-keyed clips found"
source = bc.to_luau(clips).replace(
    "-- GENERATED FILE - DO NOT EDIT BY HAND. Source: animations/build_clips.py",
    "-- GENERATED FILE - DO NOT EDIT BY HAND. Source: the .blend files in animations/hand/, written by\n"
    "-- animations/export_hand_clips.py (hand-keyed in Blender, sampled from the R6 rig at 60 fps).\n"
    "-- Same format as Config/AnimClips; AnimController merges it in.",
)
assert len(source) < bc.MAX_SCRIPT_CHARS, f"AnimClipsHand is {len(source)} characters"
with open(TARGET, "w", encoding="utf-8", newline="\n") as out:
    out.write(source)
print("WROTE", TARGET, len(source), "characters")
