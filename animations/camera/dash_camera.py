"""The Haymaker Rush dash camera (4.32 -> 4.93 s), designed in Blender on the proven scene.

  blender.exe -b animations/camera/dash_scene.blend --python-exit-code 1 --python animations/camera/dash_camera.py -- board
  blender.exe -b animations/camera/dash_scene.blend --python-exit-code 1 --python animations/camera/dash_camera.py -- spline

Keys are written in the game's own terms, in ANCHOR space (Roblox axes: +X the anchor's right, +Y up, -Z the way
the target was knocked): frame (= seconds x 100), camera place, look-at point, vertical FOV, roll. "T+" means
relative to the target's root on that frame, "A+" to the attacker's.
"""
import json
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "hand"))
import camera_kit  # noqa: E402
import shots  # noqa: E402

STAGE = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "board"
DESIGN = os.environ.get("DASH_DESIGN", "B")
OUT = os.path.join(HERE, "out")
with open(os.path.join(OUT, "scene.json"), encoding="utf-8") as source:
    DATA = json.load(source)
SAMPLE = {camera_kit.frame_of(s["t"]): s for s in DATA["frames"]}
CUT, LOAD, TAKEOFF, FACE, RELEASE, CONTACT = 432, 440, 470, 482, 486, 493
# The storyboard's beats: the cut, the coil at its deepest, the take-off, mid-dash, the last frames before
# contact, contact (Azure Flames: 4.867, 5.033, 5.067, 5.167, 5.267, 5.300).
BEATS = [(CUT, "cut"), (TAKEOFF - 1, "coil deepest"), (TAKEOFF + 3, "take-off"), (FACE - 1, "mid-dash"),
         (CONTACT - 3, "before contact"), (CONTACT, "CONTACT")]


def root(who, frame):
    return Vector(SAMPLE[frame][who + "Root"][:3])


def place(spec, frame):
    """("T+", (x, y, z)) / ("A+", ...) / ("M+", share, (x, y, z)) = from the attacker toward the target / a plain point."""
    if spec[0] == "T+":
        return root("target", frame) + Vector(spec[1])
    if spec[0] == "A+":
        return root("attacker", frame) + Vector(spec[1])
    if spec[0] == "M+":
        return root("attacker", frame).lerp(root("target", frame), spec[1]) + Vector(spec[2])
    return Vector(spec)


STAND = (7.70, 0.60, 8.16)  # today's dash stand: behind the attacker's right
EYE_CAM, EYE_LOOK = ("T+", (1.61, 0.32, 2.55)), ("T+", (-0.49, -1.01, -0.59))  # the drawn plunge's eye

DESIGNS = {
    # A: ONE continuous move. Stays put and pans toward the target from the first frame through the coil (Azure);
    # at the take-off it goes after the attacker along their right side, closing and narrowing, and lands on the
    # drawn eye as the fist does. No cut at FACE.
    "A": [
        (CUT, STAND, ("M+", 0.20, (0, 0.4, 0)), 60, 0),
        (TAKEOFF, STAND, ("M+", 0.45, (0, 0.5, 0)), 57.5, 0),
        (476, (7.25, 1.9, 4.4), ("M+", 0.55, (0, 0.5, 0)), 55, 0.8),
        (482, (6.1, 3.6, -0.6), ("M+", 0.66, (0, 0.3, 0)), 50, 2.0),
        (488, (3.9, 6.2, -5.9), ("M+", 0.82, (0, -0.1, 0)), 40, 4.2),
        (491, ("T+", (1.95, 0.25, 3.25)), ("T+", (-0.49, -1.0, -0.59)), 33, 5.8),
        (CONTACT, EYE_CAM, EYE_LOOK, 30.8, 6.2),
    ],
}


# B (the owner's picks on the storyboard, 2026-11-21): "Stay put, then cut", "Low and close (Azure)", "Settle just
# before", "Dutch from the start". ONE place, low behind the attacker's right; the aim pans toward the target at an
# even speed from the first frame (no ease-in), slows over the last frames and is still SETTLE frames before the
# contact; the horizon starts tipped and comes round to the close-up's 6.2 degrees; then ONE hard cut, on the contact
# frame, onto the drawn plunge's eye.
B = dict(
    stand=("A+", (6.2, -2.0, 7.0)),  # from the attacker's root at the cut: right, down (1 stud over the floor), behind
    look_from=("M+", 0.34, (0.0, -2.8, 0.0)),
    look_to=("M+", 0.85, (0.0, -1.3, 0.0)),  # at the settle frame
    fov=(67, 58),
    # tipped COUNTER-clockwise (negative), easing toward level: it lifts the target (upper right) and drops the
    # attacker (lower left), the dash's own diagonal. The close-up's +6.2 arrives with the cut.
    roll=(-12, -4),
    settle=490,  # still from here: 3 hundredths = 2 frames at 60 fps before the contact
    slow_from=484,
)
for key, value in json.loads(os.environ.get("DASH_B", "{}")).items():  # tuning only
    B[key] = tuple(value) if isinstance(value, list) else value


def b_share(frame):
    """How far the pan has come: even speed from the cut, then slowing to a stop at the settle frame."""
    run, slow = B["slow_from"] - CUT, B["settle"] - B["slow_from"]
    speed = 1 / (run + slow / 2)
    if frame <= B["slow_from"]:
        return speed * (frame - CUT)
    u = min((frame - B["slow_from"]) / slow, 1)
    return speed * run + speed * slow * (u - u * u / 2)


def build_new(scene):
    cam = bpy.data.objects.get("Cam_new")
    if cam:
        bpy.data.objects.remove(cam)
    cam = camera_kit.new_camera(scene, "Cam_new")
    if DESIGN == "B":
        stand = place(B["stand"], CUT)
        look_from, look_to = place(B["look_from"], CUT), place(B["look_to"], B["settle"])
        for frame in range(CUT, CONTACT):
            share = b_share(frame)
            eased = share * share * (3 - 2 * share)
            # the AIM turns at an even angle per frame (a lerp of the look-at point does not: the far end crawls)
            aim = (look_from - stand).normalized().slerp((look_to - stand).normalized(), share)
            camera_kit.key_camera(cam, frame, stand, stand + aim * 10,
                                  B["fov"][0] + (B["fov"][1] - B["fov"][0]) * share,
                                  B["roll"][0] + (B["roll"][1] - B["roll"][0]) * eased)
        for owner in (cam, cam.data):
            for fc in camera_kit.fcurves_of(owner):
                for point in fc.keyframe_points:
                    point.interpolation = "CONSTANT" if round(point.co.x) == CONTACT - 1 else "LINEAR"
                fc.update()
        camera_kit.key_camera(cam, CONTACT, place(EYE_CAM, CONTACT), place(EYE_LOOK, CONTACT), 30.8, 6.2, hold=True)
        scene["ht_new_cut"] = CONTACT / 100 - 0.001
        scene["ht_solo_from"] = CONTACT  # the body stays whole until the cut (the game: soloArm.from moves to HAYMAKER)
        return cam
    for frame, at, look, fov, roll in DESIGNS[DESIGN]:
        camera_kit.key_camera(cam, frame, place(at, frame), place(look, frame), fov, roll, hold=True)
    return cam


def solo_arm(scene):
    """From RELEASE the game shows only the attacker's striking arm (line.soloArm): a Mask on the body, keyed."""
    body = bpy.data.objects["Attacker_Body"]
    mask = body.modifiers.get("SoloArm") or body.modifiers.new("SoloArm", "MASK")
    mask.vertex_group = "Right Arm"
    for frame, on in ((int(scene["ht_from"]), False), (int(scene["ht_solo_from"]) - 1, False), (int(scene["ht_solo_from"]), True)):
        mask.show_render = mask.show_viewport = on
        mask.keyframe_insert("show_render", frame=frame)
        mask.keyframe_insert("show_viewport", frame=frame)


def still(scene, cam, frame, label, path):
    scene.camera = cam
    scene.frame_set(frame)
    r = scene.render
    r.use_stamp, r.use_stamp_note, r.stamp_note_text = True, True, label
    for flag in ("date", "time", "render_time", "frame", "frame_range", "memory", "hostname", "camera", "lens",
                 "scene", "marker", "filename", "sequencer_strip"):
        if hasattr(r, "use_stamp_" + flag):
            setattr(r, "use_stamp_" + flag, False)
    r.use_stamp_labels = False
    r.stamp_font_size = 20
    r.stamp_foreground, r.stamp_background = (1, 1, 1, 1), (0, 0, 0, 0.6)
    r.image_settings.file_format = "PNG"
    r.resolution_x, r.resolution_y = 640, 360
    r.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


scene = bpy.context.scene
today = bpy.data.objects["Cam_today"]
new = build_new(scene)
solo_arm(scene)

if STAGE in ("board", "spline") and not os.environ.get("DASH_B"):
    rows = [[os.path.join(OUT, "ref", f"ref_{i + 1}.png") for i in range(len(BEATS))]]
    temp = []
    for name, cam in (("today", today), ("new " + DESIGN, new)):
        row = []
        for frame, beat in BEATS:
            path = os.path.join(OUT, f"_{name[:3]}_{frame}.png")
            row.append(still(scene, cam, frame, f"{name}  {frame / 100:.2f}s  {beat}", path))
        rows.append(row)
        temp += row
    print("SHEET", shots.sheet(rows, os.path.join(OUT, f"storyboard_{DESIGN}.png")))
    for path in temp:
        os.remove(path)
    scene.render.resolution_x, scene.render.resolution_y = camera_kit.RES



def shake_at(seconds):
    """Ultimates.shake's jolts (the take-off's shove is the only one in this window): studs along the screen's
    right and up, out at once and back through zero with a small overshoot."""
    import math
    x = y = 0.0
    for jolt in DATA["jolts"]:
        into = seconds - jolt["t"]
        if 0 <= into < jolt["seconds"]:
            share = into / jolt["seconds"]
            size = (1 - share) * (1 - share) * math.cos(share * math.pi * 1.5) * jolt["studs"]
            length = math.hypot(jolt["x"], jolt["y"])
            x += jolt["x"] / length * size
            y += jolt["y"] / length * size
    return x, y


def render_compare(scene, sides, path, first=4.32, last=5.0, loops=3, pad=18, half=(1280, 720)):
    """Today's camera beside the new one, at the game's 60 frames a second, the jolt on top as the game adds it
    (CFrame.new(sx, sy, 0) after the camera's own frame), looped. After the vault's render_side_by_side (Blender
    Mastery 1, section 5), but this scene runs at 100 frames a second, so each 60 fps frame is rendered as a still
    at its own time (frame + subframe), and each half is a 16:9 frame: a camera's frame shape matters."""
    import numpy as np
    from mathutils import Matrix

    import camera_checks

    work = os.path.splitext(path)[0] + "_frames"
    os.makedirs(work, exist_ok=True)
    r = scene.render
    body = bpy.data.objects["Attacker_Body"]
    body.animation_data_clear()
    mask = body.modifiers["SoloArm"]
    video = bpy.data.objects.get("Cam_video") or camera_kit.new_camera(scene, "Cam_video")
    r.resolution_x, r.resolution_y, r.resolution_percentage = half[0], half[1], 100
    r.image_settings.file_format = "PNG"
    for prop in r.bl_rna.properties:
        if prop.identifier.startswith("use_stamp"):
            setattr(r, prop.identifier, False)
    r.use_stamp, r.use_stamp_note, r.use_stamp_labels, r.stamp_font_size = True, True, False, 26
    r.stamp_foreground, r.stamp_background = (1, 1, 1, 1), (0, 0, 0, 0.6)
    count = int(round((last - first) * 60))
    files = []
    for index in range(count + 1):
        seconds = min(first + index / 60, last)
        row = []
        for side, (cam, label, solo_from) in enumerate(sides):
            camera_checks.set_time(scene, seconds)
            sx, sy = shake_at(seconds)
            video.matrix_world = cam.matrix_world @ Matrix.Translation((sx, sy, 0))
            video.data.lens = cam.data.lens
            mask.show_render = mask.show_viewport = seconds >= solo_from - 1e-6
            scene.camera = video
            r.stamp_note_text = f"{label}   {seconds:.3f} s"
            r.filepath = os.path.join(work, f"side{side}_{index:03d}.png")
            bpy.ops.render.render(write_still=True)
            row.append(r.filepath)
        both = np.concatenate([shots._load(f) for f in row], axis=1)
        image = bpy.data.images.new("sbs", both.shape[1], both.shape[0], alpha=False)
        image.pixels.foreach_set(both.ravel())
        image.filepath_raw = os.path.join(work, f"sbs_{index:03d}.png")
        image.file_format = "PNG"
        image.save()
        bpy.data.images.remove(image)
        files.append(f"sbs_{index:03d}.png")
    order = ([files[0]] * pad + files + [files[-1]] * pad) * loops
    enc = bpy.data.scenes.new("Encode")
    enc.view_settings.view_transform = "Standard"
    strip = enc.sequence_editor_create().strips.new_image(name="sbs", filepath=os.path.join(work, order[0]), channel=1, frame_start=1)
    for name in order[1:]:
        strip.elements.append(name)
    er = enc.render
    er.resolution_x, er.resolution_y, er.resolution_percentage = half[0] * len(sides), half[1], 100
    er.fps, er.fps_base = 60, 1.0
    enc.frame_start, enc.frame_end = 1, len(order)
    er.image_settings.media_type = "VIDEO"
    er.image_settings.file_format = "FFMPEG"
    er.ffmpeg.format, er.ffmpeg.codec, er.ffmpeg.constant_rate_factor = "MPEG4", "H264", "HIGH"
    er.filepath = path
    bpy.ops.render.render(animation=True, scene=enc.name)
    bpy.data.scenes.remove(enc)
    return path, work


if STAGE == "video":
    path, work = render_compare(scene, [(today, "TODAY", 4.86), (new, "NEW " + DESIGN, scene["ht_solo_from"] / 100)],
                                os.path.join(OUT, "dash_camera_compare.mp4"))
    print("VIDEO", path)
    # proof that a still honours the subframe: two renders a third of a frame apart must differ
    import numpy as np
    a, b = shots._load(os.path.join(work, "side1_024.png")), shots._load(os.path.join(work, "side1_025.png"))
    print("SUBFRAME frames 24 and 25 of the new side differ by", float(np.abs(a - b).mean()))
if STAGE == "spline":
    import camera_checks
    camera_checks.report("Cam_new", cut_after=scene.get("ht_new_cut"))
if STAGE != "video":
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "dash_camera.blend"))
print("SAVED dash_camera.blend stage", STAGE)
