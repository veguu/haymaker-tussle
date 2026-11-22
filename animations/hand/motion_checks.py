"""The self-check standard for hand-keyed clips (vault: Blender Mastery 1, sections 4 and 5), run on the
real rig inside Blender. check_clip.py calls this; it can also be run directly:

  blender.exe -b <clip>.blend --python-exit-code 1 --python animations/hand/motion_checks.py -- [contact] [hold_end] [windup_end]

The frames come from the action's properties (ht_strike_frame, ht_hold_end, ht_windup_end) unless given.
The functions marked NOTE are the tutorial's code; the ones marked OURS were added or changed after the
tutorial's version was run on the first jab (see run()'s comments for why).
"""
import math
import os
import sys

import bpy
from mathutils import Vector
from mathutils.geometry import intersect_point_line

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r6_rig  # noqa: E402
import shots  # noqa: E402

HOLD_RADIUS, HOLD_SPEED = 0.4, 0.2
PARTS = ("Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg")
LEGS = ("Right Leg", "Left Leg")


# ---- NOTE: the tutorial's functions, unchanged.
def group_vertices(body, group):
    gi = body.vertex_groups[group].index
    return [v.index for v in body.data.vertices if any(e.group == gi and e.weight > 0.5 for e in v.groups)]


def end_vertices(body, group, joint_world, count=4):
    mw = body.matrix_world
    idx = group_vertices(body, group)
    idx.sort(key=lambda i: (mw @ body.data.vertices[i].co - joint_world).length, reverse=True)
    return idx[:count]


def points_per_frame(body, indices, frames):
    sc, out = bpy.context.scene, []
    for f in frames:
        sc.frame_set(f)
        ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        me = ev.to_mesh()
        out.append([body.matrix_world @ me.vertices[i].co for i in indices])
        ev.to_mesh_clear()
    return out


def centroid(points):
    return sum(points, Vector()) / len(points)


def still_stretches(tracks, frames, eps=0.01, min_len=6, allowed=()):
    moves = [max((p - q).length for pts in tracks.values() for p, q in zip(pts[k], pts[k + 1]))
             for k in range(len(frames) - 1)]
    runs, start = [], None
    for i, m in enumerate(moves + [float("inf")]):
        if m < eps and start is None:
            start = i
        elif m >= eps and start is not None:
            f0, f1 = frames[start], frames[i]
            if f1 - f0 + 1 >= min_len and not any(a <= f0 and f1 <= b for a, b in allowed):
                runs.append((f0, f1))
            start = None
    return runs


def sideways_drift(path, line_from, line_to):
    a = Vector((line_from.x, line_from.y, 0))
    b = Vector((line_to.x, line_to.y, 0))
    worst = 0.0
    for p in path:
        q = Vector((p.x, p.y, 0))
        closest, _ = intersect_point_line(q, a, b)
        worst = max(worst, (q - closest).length)
    return worst


def foot_slide(foot_points, floor_z=0.0, planted_tol=0.03):
    planted = []
    for pts in foot_points:
        low = min(pts, key=lambda v: v.z)
        if low.z - floor_z <= planted_tol:
            planted.append(Vector((low.x, low.y)))
    return max(((p - planted[0]).length for p in planted), default=0.0)


def visible_fraction(cam, body, part_group, points):
    dg = bpy.context.evaluated_depsgraph_get()
    in_group = set(group_vertices(body, part_group))
    origin = cam.matrix_world.translation
    seen = 0
    for p in points:
        d = p - origin
        hit, loc, nor, face, ob, mat = bpy.context.scene.ray_cast(dg, origin, d.normalized(), distance=d.length + 0.05)
        if hit and ob.name == body.name and all(v in in_group for v in body.data.polygons[face].vertices):
            seen += 1
    return seen / max(1, len(points))


# ---- OURS.
def visible_share(cam, body, part_group, points):
    """visible_fraction, fixed. The tutorial's version aims at the part's exact corner vertices: a ray at
    a corner can slip past every face, hit nothing, and be counted as hidden (the old jab's fist read
    0.0-0.4 while in plain view). Here each point is pulled 15% toward the points' centre, so the ray
    lands ON the part, and a ray that reaches the point without hitting anything counts as seen."""
    dg = bpy.context.evaluated_depsgraph_get()
    in_group = set(group_vertices(body, part_group))
    origin = cam.matrix_world.translation
    middle = centroid(points)
    seen = 0
    for p in points:
        q = p + (middle - p) * 0.15
        d = q - origin
        hit, loc, nor, face, ob, mat = bpy.context.scene.ray_cast(dg, origin, d.normalized(), distance=d.length - 0.02)
        if not hit or (ob.name == body.name and all(v in in_group for v in body.data.polygons[face].vertices)):
            seen += 1
    return seen / max(1, len(points))


def sole_slide(sole_points, foot_points, floor_z=0.0, planted_tol=0.03):
    """Horizontal drift of the SOLE'S CENTRE (the four bottom corners' centroid) over the frames the foot
    is planted. The tutorial's foot_slide follows whichever corner is lowest, and that corner changes as
    a rigid foot rocks: it then reports a jump between corners (up to a stud) that is not a slide."""
    planted = []
    for sole, pts in zip(sole_points, foot_points):
        if min(v.z for v in pts) - floor_z <= planted_tol:
            c = centroid(sole)
            planted.append(Vector((c.x, c.y)))
    return max(((p - planted[0]).length for p in planted), default=0.0)


def sole_twist(sole_points):
    """How far the sole turns on the spot (degrees of yaw from the first frame)."""
    def heading(sole):
        d = sole[1] - sole[0]
        return math.atan2(d.y, d.x)
    first = heading(sole_points[0])
    return max(abs(math.degrees((heading(s) - first + math.pi) % (2 * math.pi) - math.pi)) for s in sole_points)


def slow_stretches(tracks, frames, slow=0.12, min_len=6, allowed=()):
    """Dead tails as the first jab had one: the body still creeping (0.04-0.10 studs a frame), which the
    tutorial's 0.01 never catches. Same search with a looser "nearly still"."""
    return still_stretches(tracks, frames, eps=slow, min_len=min_len, allowed=allowed)


def joint_difference(a, b):
    """(degrees, studs) between two joint transforms."""
    rot = a.to_3x3().normalized().inverted() @ b.to_3x3().normalized()
    angle = math.degrees(rot.to_quaternion().angle)
    return min(angle, 360 - angle), (a.translation - b.translation).length


def run(contact=None, hold_end=None, windup_end=None, quiet=False):
    scene = bpy.context.scene
    rig = bpy.data.objects[r6_rig.RIG_NAME]
    body = bpy.data.objects[r6_rig.BODY_NAME]
    action = rig.animation_data.action
    start, end = int(action["ht_start"]), int(action["ht_end"])
    contact = int(contact if contact is not None else action["ht_strike_frame"])
    windup_end = int(windup_end if windup_end is not None else action.get("ht_windup_end", contact - 2))
    frames = list(range(start, end + 1))

    # The game camera, always the current one from shots.py (an older .blend may hold an older camera).
    cam = bpy.data.objects.get("Cam_game")
    if cam is None:
        cam = bpy.data.objects.new("Cam_game", bpy.data.cameras.new("Cam_game"))
        scene.collection.objects.link(cam)
    location, target, _ = shots.VIEWS["game"]
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(70)
    bpy.context.view_layer.update()

    mw = rig.matrix_world
    joint = {name: mw @ rig.data.bones[name].head_local for name in PARTS}  # at REST: the mesh data is the rest mesh
    fist_idx = end_vertices(body, "Right Arm", joint["Right Arm"])
    sole_idx = {leg: end_vertices(body, leg, joint[leg]) for leg in LEGS}
    tracks = {g: points_per_frame(body, group_vertices(body, g), frames) for g in PARTS}
    fist_points = points_per_frame(body, fist_idx, frames)
    fist_path = [centroid(p) for p in fist_points]
    soles = {leg: points_per_frame(body, sole_idx[leg], frames) for leg in LEGS}
    at = lambda f: f - start  # noqa: E731

    speeds = [0.0] + [(fist_path[k + 1] - fist_path[k]).length for k in range(len(frames) - 1)]
    peak = max(speeds)
    peak_frame = frames[speeds.index(peak)]
    after = [speeds[at(contact) + k] for k in (1, 2) if at(contact) + k < len(speeds)]

    # The hold: how long the WHOLE body stays put from the contact frame on.
    moves = [max((p - q).length for pts in tracks.values() for p, q in zip(pts[k], pts[k + 1]))
             for k in range(len(frames) - 1)]
    # (v3: the owner wants the hold alive, not frozen, so "held" = the fist stays within HOLD_RADIUS of where
    # it landed (the press-through moves the body up to 0.3 studs in the first frame, so no body-speed limit);
    # the tutorial's 0.01 studs a frame means frozen.)
    still_to = contact
    while (at(still_to) < len(moves)
           and (fist_path[at(still_to) + 1] - fist_path[at(contact)]).length <= HOLD_RADIUS):
        still_to += 1
    hold_frames = still_to - contact + 1 if still_to > contact else 0
    frozen = contact
    while at(frozen) < len(moves) and moves[at(frozen)] < 0.01:
        frozen += 1
    hold_end = int(hold_end if hold_end is not None else action.get("ht_hold_end", still_to))
    allowed = [(contact, hold_end)]

    floor = min(v.z for leg in LEGS for pts in tracks[leg] for v in pts)
    visible, visible_note = {}, {}
    for label, frame in (("windup", windup_end), ("contact", contact), ("hold_end", hold_end)):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        points = fist_points[at(frame)]
        visible[label] = visible_share(cam, body, "Right Arm", points + [centroid(points)])
        visible_note[label] = visible_fraction(cam, body, "Right Arm", points + [centroid(points)])

    scene.frame_set(start)
    first = {name: r6_rig.local_transform(rig, name).copy() for name in PARTS}
    scene.frame_set(end)
    last = {name: r6_rig.local_transform(rig, name).copy() for name in PARTS}
    loop_deg = max(joint_difference(first[n], last[n])[0] for n in PARTS)
    loop_studs = max(joint_difference(first[n], last[n])[1] for n in PARTS)
    guard = r6_rig.build_clips.guard_clip()["frames"][0]["pose"]
    guard_deg = guard_studs = 0.0
    for name, values in guard.items():
        want = r6_rig.frame4(r6_rig.build_clips.angles(*values[:3]), values[3:6])
        for have in (first[name], last[name]):
            degrees, studs = joint_difference(want, have)
            guard_deg, guard_studs = max(guard_deg, degrees), max(guard_studs, studs)

    drift = sideways_drift(fist_path[at(windup_end): at(contact) + 1], fist_path[at(windup_end)], fist_path[at(contact)])
    result = {
        "frames": (start, end, windup_end, contact, hold_end),
        "peak_speed": round(peak, 3), "peak_frame": peak_frame, "after_contact": [round(v, 3) for v in after],
        "hold_frames": hold_frames, "frozen_frames": frozen - contact + 1 if frozen > contact else 0,
        "dead_tails_note": still_stretches(tracks, frames, allowed=allowed),
        "dead_tails_slow": slow_stretches(tracks, frames, allowed=allowed),
        "drift": round(drift, 3),
        "foot_slide_note": {leg: round(foot_slide(tracks[leg]), 3) for leg in LEGS},
        "sole_slide": {leg: round(sole_slide(soles[leg], tracks[leg]), 3) for leg in LEGS},
        "sole_twist": {leg: round(sole_twist(soles[leg]), 1) for leg in LEGS},
        "floor": round(floor, 3),
        "visible": {k: round(v, 2) for k, v in visible.items()},
        "visible_note": {k: round(v, 2) for k, v in visible_note.items()},
        "first_vs_last": (round(loop_deg, 3), round(loop_studs, 4)),
        "arms_vs_guard": (round(guard_deg, 3), round(guard_studs, 4)),
        "speeds": [round(v, 2) for v in speeds],
    }
    verdict = {
        "peak on the contact frame": peak_frame == contact,
        # 5 to 8 was the first rule; the owner then called a 7-frame hold "too short", so the band is 8 to 12.
        "hold 8 to 12 frames": 8 <= hold_frames <= 12,
        "no dead tail (tutorial: 6+ frames under 0.01)": not result["dead_tails_note"],
        "no dead tail (ours: 6+ frames under 0.12)": not result["dead_tails_slow"],
        "fist drift at most 0.1": drift <= 0.1,
        "foot slide at most 0.03 (tutorial: lowest corner)": max(result["foot_slide_note"].values()) <= 0.03,
        "foot slide at most 0.03 (ours: sole centre)": max(result["sole_slide"].values()) <= 0.03,
        "feet not under the floor": floor >= -0.01,
        "fist at least half visible (windup, contact, hold)": min(visible.values()) >= 0.5,
        "first and last frame the same pose": loop_deg <= 0.5 and loop_studs <= 0.01,
        "arms on Guard at both ends": guard_deg <= 0.5 and guard_studs <= 0.01,
    }
    if not quiet:
        print(f"CHECKS {action.name}: frames {start}-{end}, wind-up ends {windup_end}, contact {contact}, hold to {hold_end}")
        print("  fist speed per frame:", " ".join(f"{v:.2f}" for v in speeds))
        for key in ("peak_speed", "peak_frame", "after_contact", "hold_frames", "frozen_frames", "dead_tails_note", "dead_tails_slow",
                    "drift", "foot_slide_note", "sole_slide", "sole_twist", "floor", "visible", "visible_note", "first_vs_last",
                    "arms_vs_guard"):
            print(f"  {key:<16} {result[key]}")
        for name, ok in verdict.items():
            print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    return result, verdict


if __name__ == "__main__":
    extra = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    numbers = [int(v) for v in extra[:3]] + [None] * 3
    run(*numbers[:3])
