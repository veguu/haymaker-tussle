"""Numbers for a cutscene camera, measured in Blender on the proven scene (animations/camera).

  blender.exe -b animations/camera/dash_camera.blend --python-exit-code 1 --python animations/camera/camera_checks.py

Sampled at the game's 60 frames a second from the cut (4.32 s) to the contact (4.93 s), plus the contact itself.
Per frame: where each fighter's body falls on a 16:9 screen (every vertex projected), the attacker's height on
screen, whether both are whole in frame and inside the 4:3 centre, whether the attacker is left of the target,
the pan speed (% of the frame's width per frame), the camera's speed, and how close the lens is to a body.
"""
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import camera_kit  # noqa: E402

CUT, CONTACT = 4.32, 4.93
EYE = dict(cam=(1.61, 0.32, 2.55), look=(-0.49, -1.01, -0.59), fov=30.8, roll=6.2)  # rel "target", the drawn plunge
NEAR = 0.6  # the lens must stay this far from any body part (studs)


def times():
    out, k = [], 0
    while CUT + k / 60 < CONTACT - 1e-6:
        out.append(CUT + k / 60)
        k += 1
    return out + [CONTACT]


def set_time(scene, seconds):
    frame = seconds * camera_kit.FPS
    whole = math.floor(frame + 1e-6)
    scene.frame_set(whole, subframe=max(frame - whole, 0.0))


def body_box(scene, cam, body):
    """A body's box on screen (x0, x1, y0, y1 as shares of the frame, y from the TOP), its nearest depth, and how
    close the lens is to any of its vertices."""
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = ev.to_mesh()
    xs, ys, depth, near = [], [], 1e9, 1e9
    eye = cam.matrix_world.translation
    for v in mesh.vertices:
        world = body.matrix_world @ v.co
        view = world_to_camera_view(scene, cam, world)
        near = min(near, (world - eye).length)
        if view.z > 0.05:
            xs.append(view.x)
            ys.append(1 - view.y)
            depth = min(depth, view.z)
    ev.to_mesh_clear()
    if not xs:
        return None, near
    return (min(xs), max(xs), min(ys), max(ys), depth), near


def measure(cam_name, solo_from=None):
    scene = bpy.context.scene
    cam = bpy.data.objects[cam_name]
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = camera_kit.RES
    attacker, target = bpy.data.objects["Attacker"], bpy.data.objects["Target"]
    bodies = {"attacker": bpy.data.objects["Attacker_Body"], "target": bpy.data.objects["Target_Body"]}
    rows, last = [], None
    for t in times():
        set_time(scene, t)
        position, forward, fov, roll = camera_kit.read_camera(cam)
        boxes, nears = {}, {}
        for who, body in bodies.items():
            boxes[who], nears[who] = body_box(scene, cam, body)
        a_root = world_to_camera_view(scene, cam, attacker.matrix_world.translation)
        t_root = world_to_camera_view(scene, cam, target.matrix_world.translation)
        row = dict(t=t, cam=position, forward=forward, fov=fov, roll=roll, boxes=boxes, near=min(nears.values()),
                   a_x=a_root.x, t_x=t_root.x, a_y=1 - a_root.y, t_y=1 - t_root.y, pan=0.0, tilt=0.0, speed=0.0, turn=0.0)
        if last is not None:
            dt = (t - last["t"]) * 60  # in 60 fps frames
            hfov = 2 * math.atan(math.tan(math.radians(fov) / 2) * 16 / 9)
            yaw = math.atan2(forward.x, -forward.z) - math.atan2(last["forward"].x, -last["forward"].z)
            yaw = (yaw + math.pi) % (2 * math.pi) - math.pi
            pitch = math.asin(forward.y) - math.asin(last["forward"].y)
            row["pan"] = yaw / hfov * 100 / dt
            row["tilt"] = pitch / math.radians(fov) * 100 / dt
            row["speed"] = (position - last["cam"]).length / dt
            row["turn"] = math.degrees(forward.angle(last["forward"])) / dt
        rows.append(row)
        last = row
    return rows


def whole(box, x_edge=0.0):
    return box is not None and box[0] >= x_edge and box[1] <= 1 - x_edge and box[2] >= 0 and box[3] <= 1


def report(cam_name, cut_after=None, quiet=False):
    """cut_after: a time after which the shot is another one (a cut): speeds across it are not counted."""
    rows = measure(cam_name)
    moving = [r for r in rows if cut_after is None or r["t"] <= cut_after + 1e-6]
    body = moving[1:] if len(moving) > 1 else moving
    heights = [(r["boxes"]["attacker"][3] - r["boxes"]["attacker"][2]) * 100 if r["boxes"]["attacker"] else 0 for r in moving]
    pans = [r["pan"] for r in body]
    speeds = [r["speed"] for r in body]
    turns = [r["turn"] for r in body]
    accel = [abs(b - a) for a, b in zip(speeds, speeds[1:])]
    turn_accel = [abs(b - a) for a, b in zip(turns, turns[1:])]
    pan_jumps = [abs(b - a) for a, b in zip(pans, pans[1:])]
    scene = bpy.context.scene
    set_time(scene, CONTACT)
    cam = bpy.data.objects[cam_name]
    position, forward, fov, roll = camera_kit.read_camera(cam)
    target_root = camera_kit.to_roblox(bpy.data.objects["Target"].matrix_world.translation)
    want_cam = target_root + Vector(EYE["cam"])
    want_dir = (Vector(EYE["look"]) - Vector(EYE["cam"])).normalized()
    eye_error = dict(studs=(position - want_cam).length, aim=math.degrees(forward.angle(want_dir)),
                     fov=abs(fov - EYE["fov"]), roll=abs(roll - EYE["roll"]))
    result = dict(
        frames=len(rows),
        not_whole_16x9=[round(r["t"], 3) for r in moving if not (whole(r["boxes"]["attacker"]) and whole(r["boxes"]["target"]))],
        not_in_4x3=[round(r["t"], 3) for r in moving if not (whole(r["boxes"]["attacker"], 0.125) and whole(r["boxes"]["target"], 0.125))],
        attacker_not_left=[round(r["t"], 3) for r in rows if r["a_x"] >= r["t_x"]],
        height_first=heights[0], height_last=heights[-1], heights=heights,
        pan_mean=sum(pans) / max(len(pans), 1), pan_min=min(pans, default=0), pan_max=max(pans, default=0),
        pan_first=pans[0] if pans else 0, pans=pans, pan_jump=max(pan_jumps, default=0),
        speed_max=max(speeds, default=0), accel_max=max(accel, default=0),
        turn_max=max(turns, default=0), turn_accel_max=max(turn_accel, default=0),
        settled_frames=sum(1 for r in reversed(body) if True) and next((i for i, r in enumerate(reversed(body)) if r["turn"] > 0.05 or r["speed"] > 0.01), len(body)),
        near=min(r["near"] for r in rows), eye=eye_error,
        rolls=[r["roll"] for r in rows], fovs=[r["fov"] for r in rows],
        attacker_x=[r["a_x"] * 100 for r in rows], attacker_y=[r["a_y"] * 100 for r in rows],
        target_x=[r["t_x"] * 100 for r in rows], target_y=[r["t_y"] * 100 for r in rows],
    )
    if not quiet:
        fmt = lambda values, spec="{:.1f}": " ".join(spec.format(v) for v in values)  # noqa: E731
        print(f"CAMERA {cam_name}: {len(rows)} frames at 60 fps, 4.32 -> 4.93 s" + (f" (a cut after {cut_after})" if cut_after else ""))
        print("  attacker height %H :", fmt(result["heights"], "{:.0f}"))
        print("  attacker root x %W :", fmt(result["attacker_x"], "{:.0f}"))
        print("  attacker root y %H :", fmt(result["attacker_y"], "{:.0f}"))
        print("  target root x %W   :", fmt(result["target_x"], "{:.0f}"))
        print("  target root y %H   :", fmt(result["target_y"], "{:.0f}"))
        print("  pan %W/frame       :", fmt(result["pans"]))
        print("  roll               :", fmt(result["rolls"]))
        print("  fov                :", fmt(result["fovs"], "{:.0f}"))
        for key in ("not_whole_16x9", "not_in_4x3", "attacker_not_left"):
            print(f"  {key:<18} : {result[key]}")
        print(f"  pan mean {result['pan_mean']:.2f}, min {result['pan_min']:.2f}, max {result['pan_max']:.2f}, first frame {result['pan_first']:.2f}, "
              f"biggest change between frames {result['pan_jump']:.2f}")
        print(f"  camera speed max {result['speed_max']:.3f} studs/frame, accel max {result['accel_max']:.3f}; "
              f"aim max {result['turn_max']:.2f} deg/frame, change max {result['turn_accel_max']:.2f}")
        print(f"  settled for the last {result['settled_frames']} frame(s) before the end of the move; nearest body {result['near']:.2f} studs")
        print(f"  final frame vs the drawn eye: {eye_error['studs']:.4f} studs, aim {eye_error['aim']:.3f} deg, "
              f"fov {eye_error['fov']:.3f}, roll {eye_error['roll']:.3f}")
    return result


if __name__ == "__main__":
    for name, cut in (("Cam_today", 4.82 - 1e-3), ("Cam_new", None)):
        if bpy.data.objects.get(name):
            report(name, cut_after=cut if name == "Cam_today" else bpy.context.scene.get("ht_new_cut"))
