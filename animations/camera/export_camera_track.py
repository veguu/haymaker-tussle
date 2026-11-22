"""Blender camera -> src/shared/Config/CameraTracks.luau (a baked camera track the game plays).

  blender.exe -b animations/camera/dash_camera.blend --python-exit-code 1 --python animations/camera/export_camera_track.py

Samples Cam_new at the game's 60 frames a second from the cut (4.32 s) to the contact (4.93 s), plus the contact
frame itself, and writes one row per frame: the cutscene time, the camera's place and look-at point in ANCHOR space
(Roblox axes), the vertical field of view, the roll (as CFrame.Angles(0, 0, roll) after the look-at), and 1 when the
frame starts on a CUT (the game then holds the frame before it instead of blending into it).
Core/Ultimates.shot plays it in that window instead of the shots; the jitter and jolts stay on top.
Never edit the module by hand: change the camera in Blender (animations/camera/dash_camera.py) and export again.
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import camera_checks  # noqa: E402
import camera_kit  # noqa: E402

NAME = "HaymakerDash"
LOOK_AHEAD = 10.0  # the look-at point is this far along the aim
TARGET = os.path.join(os.path.dirname(os.path.dirname(HERE)), "src", "shared", "Config", "CameraTracks.luau")

scene = bpy.context.scene
cam = bpy.data.objects["Cam_new"]
cut_after = scene.get("ht_new_cut")
rows, last = [], None
for t in camera_checks.times():
    camera_checks.set_time(scene, t)
    position, forward, fov, roll = camera_kit.read_camera(cam)
    look = position + forward * LOOK_AHEAD
    cut = 1 if (cut_after is not None and last is not None and last <= cut_after < t) else 0
    rows.append((t, position.x, position.y, position.z, look.x, look.y, look.z, fov, roll, cut))
    last = t

lines = [
    "--!strict",
    "-- GENERATED FILE - DO NOT EDIT BY HAND. Source: animations/camera/dash_camera.blend (designed by",
    "-- animations/camera/dash_camera.py), written by animations/camera/export_camera_track.py.",
    "-- Baked camera tracks: one row per frame at 60 frames a second of cutscene time, in the anchor's space:",
    "-- { t, camX, camY, camZ, lookX, lookY, lookZ, fov, roll, cut }. cut = 1: this frame starts on a cut (the frame",
    "-- before it is held until then). Core/Ultimates.shot plays a track from `from` up to (not including) `to`.",
    "return {",
    f"\t{NAME} = {{",
    f"\t\tfrom = {rows[0][0]:.4f},",
    f"\t\tto = {rows[-1][0]:.4f},",
    "\t\tframes = {",
]
for row in rows:
    numbers = [f"{row[0]:.4f}"] + [f"{v:.4f}" for v in row[1:7]] + [f"{row[7]:.3f}", f"{row[8]:.3f}", str(row[9])]
    lines.append("\t\t\t{ " + ", ".join(numbers) + " },")
lines += ["\t\t},", "\t},", "}"]
source = "\n".join(lines) + "\n"
with open(TARGET, "w", encoding="utf-8", newline="\n") as out:
    out.write(source)
print(f"WROTE {TARGET}: {len(rows)} frames, {len(source)} characters, cuts at {[f'{r[0]:.3f}' for r in rows if r[9]]}")
print("LAST", " ".join(f"{v:.4f}" for v in rows[-1][:9]))
