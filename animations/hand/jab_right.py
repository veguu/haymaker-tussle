"""JabRight v2: a rear-hand (right) straight, anime exaggerated, from Guard, standing, whole body.

  blender.exe -b --factory-startup --python-exit-code 1 --python animations/hand/jab_right.py -- block
  blender.exe -b --factory-startup --python-exit-code 1 --python animations/hand/jab_right.py -- spline
  blender.exe -b --factory-startup --python-exit-code 1 --python animations/hand/jab_right.py -- video

Built to the vault's Blender Mastery 1 (the owner's rules, 2026-11-21): snap in over 2 frames with the
peak speed ON the contact frame, HOLD the extended pose 7 frames, recover with no dead tail, feet planted,
the fist driving straight and staying in view of the game camera, first and last frame exactly on Guard.

Key poses are written the way an animator thinks, turned into joint values by build_clips' ArmPlacer and
this file's Feet, and KEYED on the rig. Torso space: +X is the character's right, +Y up, -Z forward.
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import motion_checks  # noqa: E402
import r6_rig  # noqa: E402
import shots  # noqa: E402
from hand_actions import curve, key_values, new_clip  # noqa: E402

bc = r6_rig.build_clips
STAGE = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "block"
OUT = os.path.join(r6_rig.HERE, "out")
CLIP = "JabRight"

# frame, name, then the pose in an animator's terms:
#   lean (+ forward), bank (+ tips the head toward the character's left), turn (+ right shoulder
#   forward), fwd (studs forward), side (studs to the right)
#   fist: (sweep, lift, reach) = the punching fist's aim IN THE WORLD: degrees from straight ahead toward
#         the right, degrees above level, and how far the arm's centre is from the shoulder (at most 1.45);
#         or "guard" with an offset (right, up, back) from its guard place by the chin
#   left: the left fist's offset from its guard place (right, up, back)
#   head: (nod, + down; turn, + to its left) relative to the torso
GUARD = dict(lean=7, bank=0, turn=-12, fwd=0, side=0, fist=("guard", (0, 0, 0)), left=(0, 0, 0), head=(-4.1, 8.25))
CONTACT = dict(lean=15, bank=7, turn=46, fwd=0.30, side=-0.12,
               fist=(10, 3, 1.38), left=(0.05, -0.40, 0.55), head=(-4, -30))  # lift 3: forward, not up (the owner, v2)
PRESS = dict(CONTACT)
if os.environ.get("JAB_FIST"):  # tuning only: "sweep,lift,reach" and "lean,bank,turn,fwd,side"
    CONTACT["fist"] = tuple(float(v) for v in os.environ["JAB_FIST"].split(","))
if os.environ.get("JAB_BODY"):
    CONTACT.update(zip(("lean", "bank", "turn", "fwd", "side"), (float(v) for v in os.environ["JAB_BODY"].split(","))))
if os.environ.get("JAB_HEAD"):
    CONTACT["head"] = tuple(float(v) for v in os.environ["JAB_HEAD"].split(","))
PRESS = dict(CONTACT, lean=CONTACT["lean"] + 2.5, turn=CONTACT["turn"] + 5, fwd=CONTACT["fwd"] + 0.06,
             fist=(CONTACT["fist"][0], CONTACT["fist"][1], CONTACT["fist"][2] + 0.07),
             left=(0.05, -0.44, 0.60), head=(CONTACT["head"][0] - 1.5, CONTACT["head"][1] - 3))
PULLED = dict(lean=3.5, bank=5.5, turn=-48, fwd=-0.25, side=0.09,
              fist=(10.5, 2, 0.06), left=(0.11, -0.05, -0.48), head=(-2, 36))
POSES = [
    (1, "GUARD", GUARD),
    (7, "ANTICIPATION", dict(lean=4, bank=5, turn=-44, fwd=-0.22, side=0.08,
                             fist=(10, 2, 0.10), left=(0.10, -0.05, -0.45), head=(-2, 33))),
    # The wind-up creeps a little deeper for a frame, so the whole punch is thrown in two frames (8 -> 10).
    (8, "PULLED", PULLED),
    # 9 is made in solve_all: 30% of the way, the fist ON the straight line from 8 to 10.
    (10, "CONTACT", CONTACT),
    # The hold is ALIVE (the owner, v2: "too stiff, too short"): the fist presses a little further through,
    # then settles back, over 8 frames; the body never freezes.
    (14, "PRESS", PRESS),
    (19, "HOLD END", CONTACT),
    # Home on the same straight path, slower and heavier (the owner, v2): 14 frames, not 8.
    (33, "GUARD", GUARD),
]
WINDUP_END, STRIKE_FRAME, HOLD_END = 8, 10, 19
DRIVE_FRAME, DRIVE_SHARE = 9, 0.30
HIP = bc.HIP
# The Guard clip's first frame, not the bare GUARD constant: the idle rides a bounce, so they differ by 0.04 studs.
GUARD_ARMS = bc.idle_arms(0)


def torso_values(spec):
    return (spec["lean"], -spec["bank"], spec["turn"], -spec["side"], -spec["fwd"], 0)


def corners_low(pose, leg):
    """The lowest point of a leg part, relative to the root."""
    rot, pos = bc.part_transforms(pose)[leg]
    return min(bc.add(pos, bc.mat_vec(rot, (x, -1, z)))[1] for x in (-0.5, 0.5) for z in (-0.5, 0.5))


class Feet:
    """Plants the rigid legs. Where lock_feet aims a leg at its foot and lets the sole swing and turn
    with the body, this keeps each sole's CENTRE over one spot on the floor and keeps the foot pointing
    the same way in the world; the sole only rocks. The body is then set down so the lower foot touches."""

    def __init__(self, guard_torso):
        pose = {"Torso": guard_torso}
        self.placers = {leg: bc.ArmPlacer(leg) for leg in ("Right Leg", "Left Leg")}
        bc.lock_feet(pose, bc.STANCE_FEET, self.placers)
        parts = bc.part_transforms(pose)
        self.spot, self.side = {}, {}
        for leg in self.placers:
            rot, pos = parts[leg]
            sole = bc.add(pos, bc.mat_vec(rot, (0, -1, 0)))
            self.spot[leg] = (sole[0], sole[2])
            self.side[leg] = bc.mat_vec(rot, (1, 0, 0))  # the foot's own sideways axis, in the world
        # Stance itself stands with one sole 0.05 higher than the other: keep that, level the rest to it.
        self.guard_gap = self.plant(guard_torso)[1]

    def plant(self, torso):
        """torso: (rx, ry, rz, px, py, anything). Returns the pose (Torso with its height, and the legs)
        and how far the higher foot is left above the floor."""
        pose = {"Torso": tuple(torso[:5]) + (0,)}
        rot, pos = bc.part_transforms(pose)["Torso"]
        back = bc.transpose(rot)
        for leg, placer in self.placers.items():
            top = bc.add(pos, bc.mat_vec(rot, HIP[leg]))
            dx, dz = self.spot[leg][0] - top[0], self.spot[leg][1] - top[2]
            down = math.sqrt(max(bc.LEG_LENGTH ** 2 - dx * dx - dz * dz, 1e-9))
            direction = bc.mat_vec(back, bc.norm((dx, -down, dz)))
            placer.side = bc.mat_vec(back, self.side[leg])
            pose[leg] = placer.pose(bc.add(HIP[leg], direction, bc.LEG_LENGTH / 2), direction)
        lows = {leg: corners_low(pose, leg) for leg in self.placers}
        pose["Torso"] = tuple(torso[:5]) + (bc.GROUND - min(lows.values()),)
        return pose, lows["Right Leg"] - lows["Left Leg"]

    def plant_level(self, torso, reach=30.0):
        """plant(), with the hips TILTED (the torso's bank, at most `reach` degrees either way) until both
        feet touch the floor the way they do in Stance. Two rigid legs of one length only both reach the
        floor when the hips tilt to suit; without this the far foot hangs up to 0.29 studs in the air.
        Returns the pose and how far the higher foot is still off."""
        def gap(tilt):
            return self.plant((torso[0], torso[1] + tilt, torso[2], torso[3], torso[4], 0))

        base = getattr(self, "guard_gap", 0.0)
        pose, g0 = gap(0.0)
        if abs(g0 - base) < 1e-5:
            return pose, 0.0
        lo, hi = -reach, reach
        g_lo, g_hi = gap(lo)[1] - base, gap(hi)[1] - base
        if g_lo * g_hi > 0:
            best = min((abs(gap(t)[1] - base), t) for t in [i / 30 * reach for i in range(-30, 31)])
            pose, g = gap(best[1])
            return pose, abs(g - base)
        for _ in range(48):
            mid = (lo + hi) / 2
            g_mid = gap(mid)[1] - base
            if g_lo * g_mid <= 0:
                hi, g_hi = mid, g_mid
            else:
                lo, g_lo = mid, g_mid
        pose, g = gap((lo + hi) / 2)
        return pose, abs(g - base)


def arms_and_head(pose, spec, placers, tip=None):
    """Adds the arms and head to a pose that already has its torso. `tip` = (point, direction) in root
    space puts the punching fist's end exactly there (the frame-9 breakdown)."""
    rot, pos = bc.part_transforms({"Torso": pose["Torso"]})["Torso"]
    back = bc.transpose(rot)
    fist = spec["fist"]
    if tip:
        point, way = tip
        way = bc.norm(way)
        centre_world = bc.add(point, way, -1)
        centre = bc.mat_vec(back, tuple(centre_world[i] - pos[i] for i in range(3)))
        direction = bc.mat_vec(back, way)
    elif fist[0] == "guard":
        placers["Right Arm"].side = (1, 0, 0)  # the placer carries roll between poses: start clean on Guard
        centre, direction = GUARD_ARMS["Right Arm"]
        centre = bc.add(centre, fist[1])
    else:
        sweep, lift, reach = fist
        direction = bc.mat_vec(back, bc.aim(1, sweep, lift))  # aimed in the world, seen from the turned torso
        centre = bc.add(bc.SHOULDER["Right Arm"], direction, reach)
    pose["Right Arm"] = placers["Right Arm"].pose(centre, direction)
    placers["Left Arm"].side = (1, 0, 0)
    left_centre, left_direction = GUARD_ARMS["Left Arm"]
    pose["Left Arm"] = placers["Left Arm"].pose(bc.add(left_centre, spec["left"]), left_direction)
    pose["Head"] = (spec["head"][0], 0, spec["head"][1], 0, 0, 0)
    return pose


def fist_tip(pose):
    rot, pos = bc.part_transforms(pose)["Right Arm"]
    return bc.add(pos, bc.mat_vec(rot, (0, -1, 0))), bc.mat_vec(rot, (0, -1, 0))


def solve_all():
    feet = Feet(torso_values(GUARD))
    placers = {name: bc.ArmPlacer(name) for name in ("Right Arm", "Left Arm")}
    solved, hovers = {}, {}
    for frame, _name, spec in POSES:
        pose, hovers[frame] = feet.plant_level(torso_values(spec))
        solved[frame] = arms_and_head(pose, spec, placers)
    # The breakdown: body 30% of the way from the wind-up to contact, the fist's end on the straight line.
    a, b = PULLED, CONTACT
    mixed = {key: a[key] + (b[key] - a[key]) * DRIVE_SHARE for key in ("lean", "bank", "turn", "fwd", "side")}
    mixed["left"] = bc.lerp(a["left"], b["left"], DRIVE_SHARE)
    mixed["head"] = tuple(a["head"][i] + (b["head"][i] - a["head"][i]) * DRIVE_SHARE for i in range(2))
    mixed["fist"] = (None,)
    pose, hovers[DRIVE_FRAME] = feet.plant_level(torso_values(mixed))
    (p0, d0), (p1, d1) = fist_tip(solved[WINDUP_END]), fist_tip(solved[STRIKE_FRAME])
    drive = {"Right Arm": bc.ArmPlacer("Right Arm"), "Left Arm": placers["Left Arm"]}
    solved[DRIVE_FRAME] = arms_and_head(pose, mixed, drive,
                                        tip=(bc.lerp(p0, p1, DRIVE_SHARE), bc.lerp(d0, d1, DRIVE_SHARE)))
    return solved, hovers, feet


def open_rig():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(r6_rig.HERE, "r6_rig.blend"))
    scene = bpy.context.scene
    scene.render.fps = r6_rig.FPS
    rig = bpy.data.objects[r6_rig.RIG_NAME]
    for name in ("Right Arm", "Left Arm"):
        rig.pose.bones[name].rotation_mode = "QUATERNION"  # big swings: the short way round, no Euler wobble
    return scene, rig


def block(scene, rig):
    solved, hovers, feet = solve_all()
    action, bag = new_clip(rig, CLIP)
    memory = {}
    for frame in sorted(solved):
        for bone in r6_rig.BONES:
            key_values(rig, bag, frame, bone, solved[frame][bone], "CONSTANT", memory)
    first, last = POSES[0][0], POSES[-1][0]
    action["ht_loop"] = False
    action["ht_priority"] = "Action2"
    action["ht_strike_frame"] = STRIKE_FRAME
    action["ht_windup_end"] = WINDUP_END
    action["ht_hold_end"] = HOLD_END
    action["ht_start"] = first
    action["ht_end"] = last
    scene.frame_start, scene.frame_end = first, last
    print("HOVER of the higher foot at the keys:", {f: round(h, 3) for f, h in sorted(hovers.items())})
    for frame in sorted(solved):
        parts = bc.part_transforms(solved[frame])
        rot, pos = parts["Torso"]
        shoulder = bc.add(pos, bc.mat_vec(rot, bc.SHOULDER["Right Arm"]))
        tip, _ = fist_tip(solved[frame])
        print(f"KEY f{frame:<3} fist right {tip[0]:5.2f} up {tip[1] + 3:5.2f} forward {-tip[2]:5.2f}   "
              f"arm centre {math.dist(parts['Right Arm'][1], shoulder):.2f} from the shoulder")
    return action, bag, feet


def spline(scene, rig, bag, feet):
    """Blocking -> motion. Bezier between the keys (auto-clamped handles), except the HOLD, which is held
    exactly (constant from the contact key to the hold's last key). Then the foot pass: on EVERY frame the
    legs are planted again under the curve's torso and keyed linear, with the body's height."""
    for fc in bag.fcurves:
        for point in fc.keyframe_points:
            point.interpolation = "BEZIER"
            point.handle_left_type = point.handle_right_type = "AUTO_CLAMPED"
        fc.update()
    first, last = POSES[0][0], POSES[-1][0]
    baked, worst = [], 0.0
    for frame in range(first, last + 1):
        scene.frame_set(frame)
        torso = r6_rig.read_values(r6_rig.local_transform(rig, "Torso"))
        pose, hover = feet.plant_level(torso)
        worst = max(worst, hover)
        baked.append((frame, pose))
    for fc in list(bag.fcurves):
        if '"Right Leg"' in fc.data_path or '"Left Leg"' in fc.data_path:
            bag.fcurves.remove(fc)
    height = curve(bag, "Torso", "location", 2)
    height.keyframe_points.clear()
    shift = curve(bag, "Torso", "rotation_euler", 1)  # the bank the foot pass tilts the hips by
    shift.keyframe_points.clear()
    memory = {}
    for frame, pose in baked:
        height.keyframe_points.insert(frame, pose["Torso"][5]).interpolation = "LINEAR"
        shift.keyframe_points.insert(frame, math.radians(pose["Torso"][1])).interpolation = "LINEAR"
        for leg in ("Right Leg", "Left Leg"):
            key_values(rig, bag, frame, leg, pose[leg], "LINEAR", memory)
    height.update()
    shift.update()
    print(f"HOVER worst over every frame: {worst:.3f} studs (the higher foot above the floor)")


scene, rig = open_rig()
cameras = shots.setup(scene)
action, bag, feet = block(scene, rig)
keys = sorted([frame for frame, _, _ in POSES] + [DRIVE_FRAME])
names = {frame: name for frame, name, _ in POSES}
names[DRIVE_FRAME] = "DRIVE"
first, last = POSES[0][0], POSES[-1][0]

if STAGE == "block":
    labels = [f"f{frame} {names[frame]}" for frame in keys]
    print("SHEET", shots.contact_sheet(scene, cameras, keys, labels, OUT, "jab2_block", views=("game", "side", "front")))
else:
    spline(scene, rig, bag, feet)
    result, verdict = motion_checks.run()
    if STAGE == "spline" and not os.environ.get("JAB_FIST"):
        near = list(range(STRIKE_FRAME - 4, STRIKE_FRAME + 4))
        rest = [f for f in range(2, last + 1, 2) if f not in near]
        if last not in rest:
            rest.append(last)
        for name, part in (("jab2_contact", near), ("jab2_rest", rest)):
            labels = [f"f{frame}" + (" HIT" if frame == STRIKE_FRAME else "") for frame in part]
            print("SHEET", shots.contact_sheet(scene, cameras, part, labels, OUT, name, views=("game", "side", "front")))
    if STAGE == "video":
        print("VIDEO", shots.render_mp4(cameras["game"], os.path.join(OUT, "JabRight_game_realspeed.mp4"),
                                         first - 30, last + 30, fps=60))
        print("VIDEO", shots.render_mp4(cameras["side"], os.path.join(OUT, "JabRight_side_quarterspeed.mp4"),
                                         first - 8, last + 8, fps=15))

scene.frame_set(first)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(r6_rig.HERE, "jab_right.blend"))
print("SAVED jab_right.blend stage", STAGE)
