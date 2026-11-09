"""Haymaker Tussle's character clips, written as maths and baked to data.

Run from the project folder:  python animations/build_clips.py

Writes animations/clips.json (read by the Blender preview) and
src/shared/Config/AnimClips.luau (read by the game), so the two can't disagree.

Everything is in Roblox R6 joint terms: a pose is a Motor6D Transform for each joint, written
as (rx, ry, rz in degrees, px, py, pz in studs). The constants below are R6's real C0 and C1.

What the signs do, from those constants:
  Torso, Head : +rx leans forward, +rz turns so the right shoulder comes forward, pz is up
  Right limb  : +rz swings forward, -rx swings out, px is forward
  Left limb   : -rz swings forward, -rx swings out, -px is forward
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)

# Rows of a rotation, then a position. Part1 = Part0 * C0 * Transform * inverse(C1).
RIGHT = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))
LEFT = ((0, 0, -1), (0, 1, 0), (1, 0, 0))
UP = ((-1, 0, 0), (0, 0, 1), (0, 1, 0))
JOINTS = {
    "Torso": (UP, (0, 0, 0), UP, (0, 0, 0)),
    "Head": (UP, (0, 1, 0), UP, (0, -0.5, 0)),
    "Right Arm": (RIGHT, (1, 0.5, 0), RIGHT, (-0.5, 0.5, 0)),
    "Left Arm": (LEFT, (-1, 0.5, 0), LEFT, (0.5, 0.5, 0)),
    "Right Leg": (RIGHT, (1, -1, 0), RIGHT, (0.5, 1, 0)),
    "Left Leg": (LEFT, (-1, -1, 0), LEFT, (-0.5, 1, 0)),
}
SIZES = {
    "Torso": (2, 2, 1),
    "Head": (2, 1, 1),
    "Right Arm": (1, 2, 1),
    "Left Arm": (1, 2, 1),
    "Right Leg": (1, 2, 1),
    "Left Leg": (1, 2, 1),
}
LIMBS = ("Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg")
GROUND = -3.0  # where the feet rest, relative to the root


# ---- Small matrix helpers: a transform is (rotation rows, position).
def mat_mul(a, b):
    return tuple(tuple(sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3)) for r in range(3))


def mat_vec(a, v):
    return tuple(sum(a[r][k] * v[k] for k in range(3)) for r in range(3))


def transpose(a):
    return tuple(tuple(a[c][r] for c in range(3)) for r in range(3))


def combine(a, b):
    rot_a, pos_a = a
    rot_b, pos_b = b
    moved = mat_vec(rot_a, pos_b)
    return mat_mul(rot_a, rot_b), tuple(pos_a[i] + moved[i] for i in range(3))


def inverse(a):
    rot, pos = a
    back = transpose(rot)
    moved = mat_vec(back, pos)
    return back, tuple(-m for m in moved)


def angles(rx, ry, rz):
    """Same order as CFrame.Angles: X, then Y, then Z, in degrees."""
    x, y, z = math.radians(rx), math.radians(ry), math.radians(rz)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    mx = ((1, 0, 0), (0, cx, -sx), (0, sx, cx))
    my = ((cy, 0, sy), (0, 1, 0), (-sy, 0, cy))
    mz = ((cz, -sz, 0), (sz, cz, 0), (0, 0, 1))
    return mat_mul(mat_mul(mx, my), mz)


def part_transforms(pose):
    """Each part's transform relative to the root, for {joint: (rx, ry, rz, px, py, pz)}."""

    def joint(name, parent):
        c0r, c0p, c1r, c1p = JOINTS[name]
        values = pose.get(name, (0, 0, 0, 0, 0, 0))
        transform = (angles(*values[:3]), tuple(values[3:]))
        return combine(combine(combine(parent, (c0r, c0p)), transform), inverse((c1r, c1p)))

    root = (((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0, 0, 0))
    torso = joint("Torso", root)
    parts = {"Torso": torso}
    for name in LIMBS:
        parts[name] = joint(name, torso)
    return parts


def lowest_foot(pose):
    """How far down the lowest corner of either foot reaches."""
    parts = part_transforms(pose)
    lowest = 99.0
    for name in ("Right Leg", "Left Leg"):
        rot, pos = parts[name]
        for dx in (-0.5, 0.5):
            for dz in (-0.5, 0.5):
                corner = mat_vec(rot, (dx, -1, dz))
                lowest = min(lowest, pos[1] + corner[1])
    return lowest


# ---- Vectors, and placing a rigid R6 arm.
def norm(v):
    size = math.sqrt(sum(c * c for c in v))
    return tuple(c / size for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def add(a, b, scale=1.0):
    return tuple(a[i] + b[i] * scale for i in range(3))


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def to_euler(rot):
    """Back to the X, Y, Z degrees that `angles` takes."""
    ry = math.asin(max(-1, min(1, rot[0][2])))
    rx = math.atan2(-rot[1][2], rot[2][2])
    rz = math.atan2(-rot[0][1], rot[0][0])
    return math.degrees(rx), math.degrees(ry), math.degrees(rz)


class ArmPlacer:
    """Turns "arm centre here, fist that way", in torso space, into a joint Transform.

    R6 arms are one rigid block, so an upright arm in front of the chest stands in for a
    forearm. Roll is carried over from the previous frame, so the block never flips over.
    """

    def __init__(self, joint):
        self.joint = joint
        self.side = (1, 0, 0)

    def pose(self, centre, fist_dir):
        c0r, c0p, c1r, c1p = JOINTS[self.joint]
        down = norm(fist_dir)
        up = tuple(-c for c in down)  # the part's +Y points away from the fist
        side = norm(add(self.side, up, -dot(self.side, up)))
        self.side = side
        back = cross(side, up)
        # Part rotation in torso space, as rows; its columns are side, up and back.
        part = tuple((side[r], up[r], back[r]) for r in range(3))
        transform = mat_mul(mat_mul(transpose(c0r), part), c1r)
        # centre = c0p + c0r * (p + transform * inverse(c1).position)
        _, c1_inv_pos = inverse((c1r, c1p))
        wanted = mat_vec(transpose(c0r), tuple(centre[i] - c0p[i] for i in range(3)))
        moved = mat_vec(transform, c1_inv_pos)
        position = tuple(wanted[i] - moved[i] for i in range(3))
        return to_euler(transform) + position


# Torso space: +X right, +Y up, -Z forward. Shoulders sit at x +-1, y 0.5.
SHOULDER = {"Right Arm": (1, 0.5, 0), "Left Arm": (-1, 0.5, 0)}

# ---- Timing helpers. The rule, from the research note: snap on the way to the strike, hold where
# a pose should be seen, and only ease on the way home.
FPS = 60
JUMP_SQUAT = 0.067  # Kick.JumpSquatSeconds: when the jump's clip and physics leave the floor


def ease_in(t):
    return t * t


def ease_in_hard(t):
    return t * t * t


def ease_out(t):
    return 1 - (1 - t) * (1 - t)


def ease_out_hard(t):
    left = 1 - t
    return 1 - left * left * left


def smooth(t):
    return t * t * (3 - 2 * t)


def wave_at(phase, offset=0.0):
    return math.sin(2 * math.pi * (phase + offset))


def part_foot(pose, name):
    """Where the bottom centre of a leg is, relative to the root."""
    rot, pos = part_transforms(pose)[name]
    return add(pos, mat_vec(rot, (0, -1, 0)))


HIP = {"Right Leg": (0.5, -1, 0), "Left Leg": (-0.5, -1, 0)}
LEG_LENGTH = 2


def lock_feet(pose, feet, placers):
    """Solves rigid legs so the feet stay where they are as the body moves, then stands the body on
    them. The legs hang off the torso, so without this any twist drags the feet around."""
    torso = list(pose["Torso"])
    for _ in range(3):
        pose["Torso"] = tuple(torso)
        rot, pos = part_transforms({"Torso": pose["Torso"]})["Torso"]
        back = transpose(rot)
        for name, foot in feet.items():
            local = mat_vec(back, tuple(foot[i] - pos[i] for i in range(3)))
            direction = norm(tuple(local[i] - HIP[name][i] for i in range(3)))
            centre = add(HIP[name], direction, LEG_LENGTH / 2)
            pose[name] = placers[name].pose(centre, direction)
        drop = GROUND - lowest_foot(pose)
        torso[5] += drop
    pose["Torso"] = tuple(torso)
    return pose


def lean_torso(lean, turn=0.0, roll=0.0, side=0.0, height=0.0):
    return (lean, roll, turn, side, 0, height)


# ---- The guard, from the user's boxing stance picture: fists at the chin, forearms upright
# in front of the chest, elbows in, the left hand leading a little.
GUARD = {
    "Right Arm": ((0.8, 0.28, -0.8), (-0.14, 0.93, -0.34)),
    "Left Arm": ((-0.72, 0.42, -1.12), (0.14, 0.93, -0.34)),
}
STANCE_TURN = -12  # the left shoulder leads
STANCE_DIP = 7

# ---- The idle: three motions at related speeds. A bounce every 1.2 s, slow breathing and a weight
# shift once per loop. Everything further from the body arrives a moment later than the body does.
IDLE_SECONDS = 2.4
IDLE_FRAMES = 48
BOUNCE = 0.07
SWAY = 0.075


def idle_arms(phase):
    """The fists stay up and ready. They ride the bounce late, and rock gently with the weight."""
    bounce = wave_at(phase * 2, -0.06)
    breath = wave_at(phase, -0.05)
    sway = wave_at(phase, -0.08)
    right = add(GUARD["Right Arm"][0], (0.02 * sway, 0.045 * bounce + 0.025 * breath, 0.05 * sway))
    left = add(GUARD["Left Arm"][0], (0.02 * sway, 0.045 * bounce + 0.025 * breath, -0.05 * sway))
    return {
        "Right Arm": (right, GUARD["Right Arm"][1]),
        "Left Arm": (left, GUARD["Left Arm"][1]),
    }


def base_stance():
    """The still fighting stance, with the feet where every standing move keeps them."""
    pose = {
        "Torso": lean_torso(STANCE_DIP, STANCE_TURN),
        "Right Leg": (2, 0, -10 + STANCE_DIP, 0, 0, 0),
        "Left Leg": (2, 0, -(16 + STANCE_DIP), 0, 0, 0),
    }
    torso = list(pose["Torso"])
    torso[5] = GROUND - lowest_foot(pose)
    pose["Torso"] = tuple(torso)
    return pose


STANCE_BASE = base_stance()
STANCE_FEET = {name: part_foot(STANCE_BASE, name) for name in ("Right Leg", "Left Leg")}
STANCE_HEIGHT = STANCE_BASE["Torso"][5]


def guard_clip():
    """Fists up, arms only, so it sits on top of any legs."""
    right, left = ArmPlacer("Right Arm"), ArmPlacer("Left Arm")
    frames = []
    for index in range(IDLE_FRAMES):
        arms = idle_arms(index / IDLE_FRAMES)
        pose = {"Right Arm": right.pose(*arms["Right Arm"]), "Left Arm": left.pose(*arms["Left Arm"])}
        frames.append({"t": index * IDLE_SECONDS / IDLE_FRAMES, "pose": pose})
    frames.append({"t": IDLE_SECONDS, "pose": dict(frames[0]["pose"])})
    return {"loop": True, "priority": "Idle", "seconds": IDLE_SECONDS, "frames": frames}


def stance_clip():
    """Standing still: the whole boxer, breathing, shifting weight and bouncing on planted feet."""
    arms_r, arms_l = ArmPlacer("Right Arm"), ArmPlacer("Left Arm")
    legs = {"Right Leg": ArmPlacer("Right Leg"), "Left Leg": ArmPlacer("Left Leg")}
    frames = []
    for index in range(IDLE_FRAMES):
        phase = index / IDLE_FRAMES
        bounce = wave_at(phase * 2)
        breath = wave_at(phase)
        sway = wave_at(phase, 0.02)
        arms = idle_arms(phase)
        pose = {
            # Breathing in lifts the chest, the bounce dips it, the weight shift carries it across.
            "Torso": lean_torso(
                STANCE_DIP + 0.8 * bounce - 1.0 * breath,
                STANCE_TURN + 1.8 * sway,
                1.1 * sway,
                SWAY * sway,
                STANCE_HEIGHT,
            ),
            "Head": (
                -STANCE_DIP * 0.5 + 1.0 * wave_at(phase * 2, -0.1),
                -0.8 * wave_at(phase, -0.1),
                -STANCE_TURN * 0.7 - 1.2 * sway,
                0,
                0,
                0,
            ),
            "Right Arm": arms_r.pose(*arms["Right Arm"]),
            "Left Arm": arms_l.pose(*arms["Left Arm"]),
        }
        lock_feet(pose, STANCE_FEET, legs)
        # The bounce itself: a little give, on top of standing on the feet.
        torso = list(pose["Torso"])
        torso[5] += BOUNCE * (bounce - 1) * 0.5
        pose["Torso"] = tuple(torso)
        frames.append({"t": index * IDLE_SECONDS / IDLE_FRAMES, "pose": pose})
    frames.append({"t": IDLE_SECONDS, "pose": dict(frames[0]["pose"])})
    return {"loop": True, "priority": "Idle", "seconds": IDLE_SECONDS, "frames": frames}


# ---- Sprint: the lean, stride and kicked-up back leg start from the user's reference video.
# A sprint isn't a sine wave. A foot sweeps back fast and straight while it's on the floor, at the
# speed the ground goes past, then comes through slower. Each stride has a moment with both feet
# off the floor, so the body rises and falls. The fists stay up, driving short and hard with the
# stride like a fighter charging in, a moment behind the shoulders.
SPRINT_SECONDS = 0.533
SPRINT_FRAMES = 32
SPRINT_LEAN = 38
LEG_AHEAD, LEG_BEHIND = 34, -64  # world angle of a leg landing, and leaving the floor
LEG_LIFT = 84  # how far behind the foot kicks up as it comes through
CONTACT_SHARE = 0.24  # share of the stride a foot spends on the floor
FIST_DRIVE = 0.42
SPRINT_FLOAT = 0.16  # how much higher the body rides with both feet off the floor


def leg_angle(phase):
    """A leg's world angle. On the floor it sweeps evenly; off it, it kicks up and swings through."""
    phase %= 1
    if phase < CONTACT_SHARE:
        return LEG_AHEAD + (LEG_BEHIND - LEG_AHEAD) * (phase / CONTACT_SHARE)
    t = (phase - CONTACT_SHARE) / (1 - CONTACT_SHARE)
    if t < 0.28:
        return LEG_BEHIND + (-LEG_LIFT - LEG_BEHIND) * ease_out(t / 0.28)
    return -LEG_LIFT + (LEG_AHEAD + LEG_LIFT) * smooth((t - 0.28) / 0.72)


def sprint_pose(phase, right, left):
    wave = wave_at(phase, -0.12)
    twist = -14 * wave_at(phase, -0.08)
    bank = 3.5 * math.sin(4 * math.pi * phase)
    right_leg = leg_angle(phase) + SPRINT_LEAN
    left_leg = leg_angle(phase + 0.5) + SPRINT_LEAN
    # A fist drives forward as the opposite leg does, and each dips into its foot's landing.
    lag = wave_at(phase, -0.18)
    fall = math.cos(4 * math.pi * phase - 0.8)
    right_centre = add(GUARD["Right Arm"][0], (0, 0.09 * lag - 0.05 * fall, FIST_DRIVE * lag))
    left_centre = add(GUARD["Left Arm"][0], (0, -0.09 * lag - 0.05 * fall, -FIST_DRIVE * lag))
    return {
        "Torso": (SPRINT_LEAN + 2.0 * math.cos(4 * math.pi * phase), bank, twist, 0, 0, 0),
        # The head holds level and steady while everything under it works.
        "Head": (-SPRINT_LEAN * 0.74, -bank * 0.5, -twist * 0.75, 0, 0, 0),
        "Right Arm": right.pose(right_centre, GUARD["Right Arm"][1]),
        "Left Arm": left.pose(left_centre, GUARD["Left Arm"][1]),
        "Right Leg": (2, 0, right_leg, 0, 0, 0),
        "Left Leg": (2, 0, -left_leg, 0, 0, 0),
    }


def bake_sprint():
    right, left = ArmPlacer("Right Arm"), ArmPlacer("Left Arm")
    poses = [sprint_pose(i / SPRINT_FRAMES, right, left) for i in range(SPRINT_FRAMES)]
    # While a foot is down the body stands on it. Between, it floats up and over.
    planted = [GROUND - lowest_foot(pose) for pose in poses]
    frames = []
    for index, pose in enumerate(poses):
        phase = index / SPRINT_FRAMES
        share = (phase % 0.5) / 0.5
        off_floor = share > CONTACT_SHARE * 2
        # Height through the stride: planted while down, an arc up over the top once off the floor.
        lift = math.sin(math.pi * (share - CONTACT_SHARE * 2) / (1 - CONTACT_SHARE * 2)) if off_floor else 0
        before = planted[index - 1]
        after = planted[(index + 1) % SPRINT_FRAMES]
        height = (before + 2 * planted[index] + after) / 4 + SPRINT_FLOAT * lift
        torso = list(pose["Torso"])
        torso[5] = height
        pose["Torso"] = tuple(torso)
        frames.append({"t": index * SPRINT_SECONDS / SPRINT_FRAMES, "pose": pose})
    frames.append({"t": SPRINT_SECONDS, "pose": dict(frames[0]["pose"])})
    return {"loop": True, "priority": "Movement", "seconds": SPRINT_SECONDS, "frames": frames}


SPRINT_HEIGHT = -0.24


# ---- Brake: hands thrown up open and wide, body thrown back, front foot dug in, skid tremble.
# It holds as long as the skid lasts, and how strongly it shows follows how fast you were going.
# When the skid ends, BrakeSettle rocks forward past upright and comes back to the stance.
BRAKE_SECONDS = 0.4
BRAKE_FRAMES = 12
BRAKE_LEAN = -24


def brake_pose(phase, right, left):
    shake = wave_at(phase)
    fast = wave_at(phase * 2)
    front = 46 + BRAKE_LEAN + 2 * shake
    back = -16 + BRAKE_LEAN - 2 * shake
    shudder = (0, 0.05 * fast, 0)
    return {
        "Torso": (BRAKE_LEAN + 1.5 * fast, 2 * shake, 10 + 2 * shake, 0, 0, 0),
        "Head": (12, 0, -6, 0, 0, 0),
        "Right Arm": right.pose(add((1.35, 1.25, -0.85), shudder), (0.35, 0.8, -0.5)),
        "Left Arm": left.pose(add((-1.2, 1.35, -0.95), shudder, -1), (-0.3, 0.85, -0.4)),
        "Right Leg": (0, 0, front, 0, 0, 0),
        "Left Leg": (0, 0, -back, 0, 0, 0),
    }


def bake_brake():
    right, left = ArmPlacer("Right Arm"), ArmPlacer("Left Arm")
    frames = []
    for index in range(BRAKE_FRAMES):
        pose = brake_pose(index / BRAKE_FRAMES, right, left)
        torso = list(pose["Torso"])
        torso[5] = GROUND - lowest_foot(pose)
        pose["Torso"] = tuple(torso)
        frames.append({"t": index * BRAKE_SECONDS / BRAKE_FRAMES, "pose": pose})
    frames.append({"t": BRAKE_SECONDS, "pose": dict(frames[0]["pose"])})
    return {"loop": True, "priority": "Action", "seconds": BRAKE_SECONDS, "frames": frames}


def bake_brake_settle():
    """Momentum carries on after the feet stop: over the front foot, then back into the stance."""
    seconds = 0.4
    arms_r, arms_l = ArmPlacer("Right Arm"), ArmPlacer("Left Arm")
    legs = {"Right Leg": ArmPlacer("Right Leg"), "Left Leg": ArmPlacer("Left Leg")}
    frames = []
    arm_up = {"Right Arm": ((1.25, 1.05, -0.9), (0.3, 0.85, -0.45)), "Left Arm": ((-1.15, 1.15, -1.0), (-0.28, 0.85, -0.4))}
    total = round(seconds * FPS)
    for index in range(total + 1):
        t = index / FPS
        # Lean: from thrown back, quickly over past upright, then a slow settle.
        if t < 0.13:
            lean = BRAKE_LEAN + (STANCE_DIP + 15 - BRAKE_LEAN) * ease_out(t / 0.13)
        else:
            lean = STANCE_DIP + 15 * (1 - smooth((t - 0.13) / (seconds - 0.13)))
        # The arms come down a beat behind the body.
        arm_share = smooth(min(max(t - 0.03, 0) / 0.24, 1))
        pose = {
            "Torso": lean_torso(lean, STANCE_TURN + 10 * (1 - smooth(t / seconds))),
            "Head": (-lean * 0.55 + 6 * (1 - arm_share), 0, -STANCE_TURN * 0.7, 0, 0, 0),
        }
        for name, placer in (("Right Arm", arms_r), ("Left Arm", arms_l)):
            centre = lerp(arm_up[name][0], GUARD[name][0], arm_share)
            direction = norm(lerp(arm_up[name][1], GUARD[name][1], arm_share))
            pose[name] = placer.pose(centre, direction)
        lock_feet(pose, STANCE_FEET, legs)
        frames.append({"t": t, "pose": pose})
    return {"loop": False, "priority": "Action", "seconds": seconds, "frames": frames}


# ---- The swings. Each lands at Punch.Windup, when the server decides the hit. Frame 1 is already
# the big pose, thrown back; it creeps further back for two frames, and then snaps to contact in
# three. After that, a fast decelerating whip to the far end of the follow-through, a brief hold
# there, and a return along a different path. The hips lead, then the chest and the arm, and the
# head and the other hand follow. A hook's far end is the next hook's wind-up, so they chain.
STRIKE = 0.08
HOLD_UNTIL = 0.033
THROUGH_AT = 0.19
HANG_FOR = 0.07
SWING_SECONDS = 0.55
BODY_LEADS = 1 / FPS
HEAD_LAGS = 2 / FPS
OFF_HAND_LAGS = 1 / FPS
RUN_TURN_SHARE = 0.42  # how much of a swing's turn a running body can show
RUN_TURN_MAX = 24
RETURN_DROP = 0.3  # the fist comes home on a low arc, not back along its path


def aim(side_sign, sweep, lift):
    """A fist direction. Sweep is degrees from straight ahead toward that arm's own side, so a
    negative sweep has crossed the body. Lift is degrees above level."""
    s, l = math.radians(sweep), math.radians(lift)
    return (side_sign * math.sin(s) * math.cos(l), math.sin(l), -math.cos(s) * math.cos(l))


def swing_beats(shape):
    """The swing's segments as (start, end, from, to, easing). `to` of None means home."""
    cocked = shape["cocked"]
    pulled = dict(cocked)
    for key, share in (("sweep", 1.08), ("turn", 1.1), ("dip", 1.08), ("lift", 1.05)):
        if key in pulled:
            pulled[key] = cocked[key] * share
    through_at = shape.get("through_at", THROUGH_AT)
    settle_at = shape.get("settle_at")
    seconds = shape.get("seconds", SWING_SECONDS)
    through = shape["through"]
    hang_to = through_at + shape.get("hang", HANG_FOR)
    drifted = {key: value + (shape.get("settle", through).get(key, value) - value) * 0.14 for key, value in through.items()}
    beats = [
        (0, HOLD_UNTIL, cocked, pulled, lambda t: t),
        (HOLD_UNTIL, STRIKE, pulled, shape["contact"], ease_in_hard),
        (STRIKE, through_at, shape["contact"], through, ease_out_hard),
        (through_at, hang_to, through, drifted, lambda t: t),
    ]
    if settle_at:
        beats.append((hang_to, settle_at, drifted, shape["settle"], smooth))
        beats.append((settle_at, seconds, shape["settle"], None, smooth))
    else:
        beats.append((hang_to, seconds, drifted, None, smooth))
    return beats


def swing_values(beats, t):
    """Every value the swing has at time t, plus how far home it has come."""
    t = max(t, 0)
    for start, end, first, second, easing in beats:
        if t <= end or end == beats[-1][1]:
            amount = easing(min((t - start) / (end - start), 1))
            keys = set(first) | set(second or {})
            values = {}
            for key in keys:
                default = 0.0
                a = first.get(key, default)
                b = second.get(key, default) if second else default
                values[key] = a + (b - a) * amount
            return values, first, second, amount
    raise ValueError("no beat")


def bake_swing(arm, shape, running):
    """A swing, thrown standing or over a run. Standing, it moves the whole body and the feet stay
    down. Over a run it poses only the arms and head: legs and torso are the sprint's, and never
    stop. The body's turn comes from `turn`, which AnimController applies to the whole body."""
    other = "Left Arm" if arm == "Right Arm" else "Right Arm"
    side_sign = 1 if arm == "Right Arm" else -1
    placer, off = ArmPlacer(arm), ArmPlacer(other)
    legs = {"Right Leg": ArmPlacer("Right Leg"), "Left Leg": ArmPlacer("Left Leg")}
    guard_centre, guard_dir = GUARD[arm]
    off_centre, off_dir = GUARD[other]
    seconds = shape.get("seconds", SWING_SECONDS)
    beats = swing_beats(shape)
    hops = "hop" in shape["contact"]
    frames = []
    turns = []
    total = round(seconds * FPS)
    # Every 60th of a second, plus the exact strike time, where the Hit event sits.
    times = sorted({index / FPS for index in range(total + 1)} | {STRIKE})
    for t in times:
        values, first, second, amount = swing_values(beats, t)
        if second:
            direction = aim(side_sign, values["sweep"], values["lift"])
            centre = add(SHOULDER[arm], direction, values["reach"])
        else:
            start_dir = aim(side_sign, first["sweep"], first["lift"])
            start_centre = add(SHOULDER[arm], start_dir, first["reach"])
            centre = lerp(start_centre, guard_centre, amount)
            centre = add(centre, (0, -RETURN_DROP * math.sin(math.pi * amount), 0))
            direction = norm(lerp(start_dir, guard_dir, amount))
        body, _, _, _ = swing_values(beats, min(t + BODY_LEADS, seconds))
        late, _, _, _ = swing_values(beats, max(t - HEAD_LAGS, 0))
        hand, _, _, _ = swing_values(beats, max(t - OFF_HAND_LAGS, 0))
        # Turn is written as "toward the punch": positive brings this arm's shoulder forward.
        twist = body.get("turn", 0) * side_sign + STANCE_TURN * (1 - min(abs(body.get("turn", 0)) / 20, 1))
        pull = hand.get("pull", 0)  # the other hand snaps back and down as the punch goes out
        pose = {
            arm: placer.pose(centre, direction),
            other: off.pose(add(off_centre, (0, -0.4 * pull, 0.55 * pull)), off_dir),
        }
        if running:
            late_turn = late.get("turn", 0) * side_sign
            pose["Head"] = (-SPRINT_LEAN * 0.74 - late.get("look", 0), 0, -late_turn * RUN_TURN_SHARE * 0.6, 0, 0, 0)
            turn = values.get("turn", 0) * side_sign * RUN_TURN_SHARE
            turns.append((t, max(-RUN_TURN_MAX, min(RUN_TURN_MAX, turn))))
        else:
            lean = STANCE_DIP + body.get("dip", 0)
            late_lean = STANCE_DIP + late.get("dip", 0)
            late_twist = late.get("turn", 0) * side_sign + STANCE_TURN * (1 - min(abs(late.get("turn", 0)) / 20, 1))
            pose["Torso"] = (lean, -body.get("bank", 0) * side_sign, twist, 0, 0, STANCE_HEIGHT)
            pose["Head"] = (-late_lean * 0.6 - late.get("look", 0), 0, -late_twist * 0.6, 0, 0, 0)
            if hops:
                # Into the air: the legs are posed, and the body rises off them.
                right_world = values.get("right_leg", -10.0)
                left_world = values.get("left_leg", 16.0)
                pose["Right Leg"] = (2, 0, right_world + lean, 0, 0, 0)
                pose["Left Leg"] = (2, 0, -(left_world + lean), 0, 0, 0)
                torso = list(pose["Torso"])
                torso[5] = 0
                pose["Torso"] = tuple(torso)
                torso[5] = GROUND - lowest_foot(pose) + values.get("hop", 0)
                pose["Torso"] = tuple(torso)
            else:
                lock_feet(pose, STANCE_FEET, legs)
                torso = list(pose["Torso"])
                torso[5] += values.get("rise", 0)
                pose["Torso"] = tuple(torso)
        frames.append({"t": t, "pose": pose})
    clip = {"loop": False, "priority": "Action2", "seconds": seconds, "strike": STRIKE, "frames": frames}
    if running:
        clip["turn"] = turns
    return clip


# Reach is how far the arm's centre sits from the shoulder: 1 is natural, more drives it out.
HOOK = {
    "cocked": {"sweep": 125, "lift": 8, "reach": 1.0, "turn": -46, "dip": 6, "rise": -0.1, "bank": 6, "look": -4},
    "contact": {"sweep": 12, "lift": 14, "reach": 1.4, "turn": 22, "dip": 9, "rise": -0.03, "pull": 0.6, "look": 2},
    "through": {"sweep": -72, "lift": 10, "reach": 1.15, "turn": 58, "dip": 13, "rise": -0.12, "bank": -8, "pull": 1, "look": 6},
    "hang": 0.06,
}
# Everything goes into it, and nothing moves in a straight line. The shoulder drops into a deep
# coil with the fist low behind the knee, the whole body whips through and over to the far side
# as it leaves the floor, the fist overshoots past straight up, and it all settles back a little
# before dropping home, so the body reads as carrying real weight.
UPPERCUT = {
    "seconds": 0.76,
    "through_at": 0.19,
    "settle_at": 0.36,
    "hang": 0.05,
    "cocked": {
        "sweep": 62, "lift": -80, "reach": 1.1, "turn": -60, "dip": 44, "rise": -0.5, "bank": 22,
        "pull": 0, "look": -12, "right_leg": -44, "left_leg": 42, "hop": 0,
    },
    "contact": {
        "sweep": 14, "lift": 40, "reach": 1.6, "turn": 20, "dip": -4, "rise": 0.1, "bank": 4,
        "pull": 0.6, "look": 8, "right_leg": -26, "left_leg": 26, "hop": 0.25,
    },
    "through": {
        "sweep": -14, "lift": 104, "reach": 1.75, "turn": 62, "dip": -36, "rise": 0.6, "bank": -18,
        "pull": 1, "look": 30, "right_leg": -18, "left_leg": 6, "hop": 0.9,
    },
    "settle": {
        "sweep": -6, "lift": 82, "reach": 1.4, "turn": 44, "dip": -20, "rise": 0.42, "bank": -8,
        "pull": 0.9, "look": 18, "right_leg": -14, "left_leg": 12, "hop": 0.5,
    },
}


# ---- The air kick and the reactions: poses, then beats between them.
def right_limb(forward, out=0.0):
    return (-out, 0, forward, 0, 0, 0)


def left_limb(forward, out=0.0):
    return (-out, 0, -forward, 0, 0, 0)


def blend_pose(a, b, t):
    return {joint: tuple(a[joint][i] + (b[joint][i] - a[joint][i]) * t for i in range(6)) for joint in a}


def beats_clip(beats, loop, seconds, priority="Action3"):
    """A clip from (time, pose) beats. A beat can carry its own easing as a third item, for how it
    arrives at that pose; the default is a soft curve. Sampled every 60th of a second."""
    frames = []
    total = round(seconds * FPS)
    for index in range(total + 1):
        t = index / FPS
        for start_beat, end_beat in zip(beats, beats[1:]):
            start, first = start_beat[0], start_beat[1]
            end, second = end_beat[0], end_beat[1]
            easing = end_beat[2] if len(end_beat) > 2 else smooth
            if t <= end:
                frames.append({"t": t, "pose": blend_pose(first, second, easing((t - start) / (end - start)))})
                break
    return {"loop": loop, "priority": priority, "seconds": seconds, "frames": frames}


def snap(t):
    """Nearly all the way there at once."""
    return 1 - (1 - t) ** 4


def body_pose(torso, head, right_arm, left_arm, right_leg, left_leg):
    return {
        "Torso": torso,
        "Head": head,
        "Right Arm": right_arm,
        "Left Arm": left_arm,
        "Right Leg": right_leg,
        "Left Leg": left_leg,
    }


def bake_leap():
    """The jump. Arms stay down beside the body, a little out, the whole way. Down into a quick
    squat, and at JUMP_SQUAT, when physics leaves the floor, it springs: legs straight, body long,
    rising off its joints past where it settles, which is as close as rigid parts get to a stretch.
    Knee-bends here are legs splayed out and forward with the hips dropped, since R6 has no knees."""

    def arms(out, forward=0.0):
        return right_limb(forward, out), left_limb(forward, out)

    def planted(pose):
        torso = list(pose["Torso"])
        torso[5] = 0
        pose["Torso"] = tuple(torso)
        torso[5] = GROUND - lowest_foot(pose)
        pose["Torso"] = tuple(torso)
        return pose

    right_arm, left_arm = arms(14, 6)
    half = planted(body_pose(
        (16, 0, -6, 0, 0, 0), (-8, 0, 3, 0, 0, 0), right_arm, left_arm, right_limb(26, 16), left_limb(26, 16),
    ))
    right_arm, left_arm = arms(20, 12)
    squat = planted(body_pose(
        (30, 0, -4, 0, 0, 0), (-20, 0, 2, 0, 0, 0), right_arm, left_arm, right_limb(50, 27), left_limb(50, 27),
    ))
    right_arm, left_arm = arms(24, -8)
    stretch = body_pose(
        (-9, 0, 2, 0, 0, 0.8), (10, 0, 0, 0, 0, 0), right_arm, left_arm, right_limb(-12, 4), left_limb(-8, 4),
    )
    right_arm, left_arm = arms(26, -2)
    settle = body_pose(
        (2, 0, 0, 0, 0, 0.1), (2, 0, 0, 0, 0, 0), right_arm, left_arm, right_limb(16, 7), left_limb(30, 7),
    )

    def air(wave):
        right_arm, left_arm = arms(26 + 4 * wave, 4 + 5 * wave)
        return body_pose(
            (6 + 2 * wave, 1.5 * wave, 3 * wave, 0, 0, 0), (-2, 0, -2 * wave, 0, 0, 0),
            right_arm, left_arm, right_limb(26 - 12 * wave, 8), left_limb(44 + 12 * wave, 8),
        )

    beats = [
        (0, half),
        (0.05, squat, ease_out),
        (JUMP_SQUAT, squat),
        (JUMP_SQUAT + 0.05, stretch, ease_out_hard),
        (JUMP_SQUAT + 0.2, settle),
        (JUMP_SQUAT + 0.42, air(1)),
    ]
    t = JUMP_SQUAT + 0.42
    wave = 1
    while t < 2.3:
        t += 0.4
        wave = -wave
        beats.append((t, air(wave)))
    clip = beats_clip(beats, False, round(t, 3))
    clip["spring"] = JUMP_SQUAT
    return clip


# The tight ball: knees to the chest, arms tucked in, head down. Every spin starts from here.
CURL = body_pose(
    (58, 0, 0, 0, 0, 0), (18, 0, 0, 0, 0, 0),
    right_limb(108, -8), left_limb(108, -8), right_limb(130, -4), left_limb(124, -4),
)
STRIKE_LEAN = -10  # the body at the moment of the kick, past a whole turn
KICK_LEG = 8  # the leg, nearly in line with the body: reaching straight past the hip
KICK_FLIP_START = CURL["Torso"][0]
KICK_FLIP_END = 360 + STRIKE_LEAN
KICK_OTHER_LEG = 80


def bake_aim():
    """Close enough: curl into the ball and hold it tight, quivering, for the timing."""

    def curled(wave):
        pose = dict(CURL)
        torso = list(CURL["Torso"])
        torso[0] += 2 * wave
        pose["Torso"] = tuple(torso)
        pose["Right Leg"] = right_limb(130 + 3 * wave, -4)
        pose["Left Leg"] = left_limb(124 - 3 * wave, -4)
        return pose

    return beats_clip(
        [(0, curled(0)), (0.1, curled(1)), (0.2, curled(-1)), (0.3, curled(1)), (0.4, curled(0))],
        True,
        0.4,
    )


def bake_spin():
    """One movement from ball to heel. Rotating forward, head over heels, gathering speed. Partway
    round the kicking leg uncurls, so it's reaching overhead when the body is upside down, and the
    rotation itself then whips the heel over and down. It ends just short of the strike, and
    KickDown's first frame is the strike, so spin and kick are one motion."""
    frames = []
    seconds = 0.28
    total = round(seconds * FPS)
    for index in range(total + 1):
        t = index / total
        angle = KICK_FLIP_START + (KICK_FLIP_END - 4 - KICK_FLIP_START) * (t ** 1.35)
        # Tight until nearly upside down, then the leg shoots out.
        open_leg = ease_out(min(max(t - 0.38, 0) / 0.42, 1))
        open_rest = smooth(min(max(t - 0.45, 0) / 0.55, 1))
        pose = body_pose(
            (angle, 0, 0, 0, 0, 0),
            (18 + (20 - 18) * open_rest, 0, 0, 0, 0, 0),
            right_limb(108 + (-58 - 108) * open_rest, -8 + 48 * open_rest),
            left_limb(108 + (-46 - 108) * open_rest, -8 + 40 * open_rest),
            right_limb(130 + (KICK_LEG + 4 - 130) * open_leg, -4 + 4 * open_leg),
            left_limb(124 + (KICK_OTHER_LEG - 124) * open_rest, -4 + 4 * open_rest),
        )
        frames.append({"t": index / FPS, "pose": pose})
    return {"loop": False, "priority": "Action3", "seconds": seconds, "frames": frames}


def bake_kick():
    """Frame 1 is the heel on them, with the leg long: the hit stop freezes here, so this is the pose
    that gets seen, and the server's stop lasts exactly as long. After it comes the push-off: the
    kicking leg snaps back up to the body as if rebounding off them, the torso arches backward as
    the body goes up, and the arms open late. Then it opens up to fall."""

    def pose(lean, head, kick, other, right_arm, left_arm, rise=0.0):
        return body_pose(
            (lean, 0, 0, 0, 0, rise), (head, 0, 0, 0, 0, 0),
            right_arm, left_arm, right_limb(kick), left_limb(other),
        )

    strike = pose(STRIKE_LEAN, 20, KICK_LEG, KICK_OTHER_LEG, right_limb(-58, 40), left_limb(-46, 32))
    past = pose(STRIKE_LEAN + 6, 24, KICK_LEG - 8, KICK_OTHER_LEG + 6, right_limb(-70, 44), left_limb(-56, 36))
    retract = pose(-30, -10, 92, 44, right_limb(-20, 60), left_limb(16, 52), 0.5)
    recoil = pose(-18, -6, 62, 26, right_limb(34, 56), left_limb(50, 48), 0.25)
    fall = pose(4, -2, 26, 12, right_limb(24, 30), left_limb(38, 26))
    return beats_clip(
        [(0, strike), (0.033, past, ease_out), (0.13, retract, ease_out_hard), (0.28, recoil), (0.5, fall)],
        False,
        0.5,
    )


def flinch_clip(pain, past, seconds):
    """Frame 1 is the pained pose, and the hit stop freezes on it. Then it's thrown further by what
    hit it, and recovers late, with the fists coming up last. Legs are left to whatever they're doing."""
    back = {
        "Torso": (STANCE_DIP, 0, STANCE_TURN, 0, 0, 0),
        "Head": (-STANCE_DIP * 0.5, 0, 8, 0, 0, 0),
        "Right Arm": right_limb(40, 14),
        "Left Arm": left_limb(55, 14),
    }
    return beats_clip([(0, pain), (0.07, past, ease_out), (seconds, back)], False, seconds, "Action4")


def bake_flinch():
    """A light hit from the front: the head snaps back and one shoulder is knocked open."""
    pain = {
        "Torso": (-16, 6, -22, 0, 0, 0),
        "Head": (-26, 0, 14, 0, 0, 0),
        "Right Arm": right_limb(-22, 48),
        "Left Arm": left_limb(44, 22),
    }
    past = {
        "Torso": (-20, 8, -28, 0, 0, 0),
        "Head": (-32, 0, 18, 0, 0, 0),
        "Right Arm": right_limb(-36, 56),
        "Left Arm": left_limb(58, 28),
    }
    return flinch_clip(pain, past, 0.28)


def bake_flinch_heavy():
    """A big hit from the front: bent right back, off balance, arms thrown out and uneven, and head
    whipped round. It takes longer to come back from."""
    pain = {
        "Torso": (-34, 13, -30, 0, 0, 0),
        "Head": (-40, 0, 22, 0, 0, 0),
        "Right Arm": right_limb(-66, 78),
        "Left Arm": left_limb(26, 64),
    }
    past = {
        "Torso": (-44, 16, -36, 0, 0, 0),
        "Head": (-48, 0, 26, 0, 0, 0),
        "Right Arm": right_limb(-84, 88),
        "Left Arm": left_limb(8, 74),
    }
    return flinch_clip(pain, past, 0.46)


def bake_flinch_back():
    """Hit from behind: thrown forward, spine arched the other way, head and arms left behind."""
    pain = {
        "Torso": (30, -7, 18, 0, 0, 0),
        "Head": (-34, 0, -10, 0, 0, 0),
        "Right Arm": right_limb(-48, 42),
        "Left Arm": left_limb(-30, 50),
    }
    past = {
        "Torso": (40, -9, 22, 0, 0, 0),
        "Head": (-42, 0, -14, 0, 0, 0),
        "Right Arm": right_limb(-66, 48),
        "Left Arm": left_limb(-44, 58),
    }
    return flinch_clip(pain, past, 0.34)


def bake_skid():
    """Knocked backward along the floor: heels dug in, front leg braced, body fighting to stay up,
    with the arms still being dragged along behind the hit."""

    def skid(wave):
        pose = body_pose(
            (-16 + 2 * wave, 3 * wave, -14, 0, 0, 0),
            (10, 0, 8, 0, 0, 0),
            right_limb(62 + 6 * wave, 34),
            left_limb(46 - 6 * wave, 30),
            right_limb(30 + 2 * wave, 6),
            left_limb(-18 - 2 * wave, 8),
        )
        torso = list(pose["Torso"])
        torso[5] = GROUND - lowest_foot(pose)
        pose["Torso"] = tuple(torso)
        return pose

    return beats_clip([(0, skid(-1)), (0.1, skid(1)), (0.2, skid(-1))], True, 0.2, "Action3")


def bake_tumble():
    """Launched: stretched, twisted and uneven, limbs clear of the body and drifting."""
    def spread(wave):
        return body_pose(
            (-26 + 7 * wave, 12 * wave, -28 + 10 * wave, 0, 0, 0),
            (-24 + 4 * wave, 0, 12, 0, 0, 0),
            right_limb(142 + 18 * wave, 34),
            left_limb(-38 + 14 * wave, 54),
            right_limb(-34 + 14 * wave, 10),
            left_limb(38 - 14 * wave, 16),
        )

    return beats_clip([(0, spread(-1)), (0.45, spread(1)), (0.9, spread(-1))], True, 0.9, "Action4")


def bake_slammed():
    """Driven down: folded around the hit, with everything trailing upward behind the body."""
    def trailing(wave):
        return body_pose(
            (34 + 2 * wave, 5, -10, 0, 0, 0),
            (-14, 0, 6, 0, 0, 0),
            right_limb(158 + 7 * wave, 26),
            left_limb(136 - 7 * wave, 38),
            right_limb(-52 + 6 * wave, 8),
            left_limb(-22 - 6 * wave, 14),
        )

    return beats_clip([(0, trailing(-1)), (0.1, trailing(1)), (0.2, trailing(-1))], True, 0.2, "Action4")


def bake_floor_hit():
    """The frame the floor arrives: flattened and spread, then limp as the body comes up off it.
    The body is low on its joints, so it reads as squashed into the floor."""
    flat = body_pose(
        (78, 6, -8, 0, 0, -2.0),
        (-40, 0, 10, 0, 0, 0),
        right_limb(112, 62),
        left_limb(96, 70),
        right_limb(-12, 26),
        left_limb(-30, 32),
    )
    limp = body_pose(
        (24, 10, -18, 0, 0, -0.5),
        (-18, 0, 12, 0, 0, 0),
        right_limb(150, 40),
        left_limb(-30, 48),
        right_limb(-40, 14),
        left_limb(30, 18),
    )
    return beats_clip([(0, flat), (0.05, flat), (0.26, limp, ease_out)], False, 0.26, "Action4")


def bake_land():
    """Landing from a height: weight goes straight down into a wide stance, then comes up out of it,
    a little past level. The fists come up last."""
    squat = body_pose(
        (24, 2, STANCE_TURN, 0, 0, 0),
        (-14, 0, 8, 0, 0, 0),
        right_limb(-22, 30),
        left_limb(-14, 34),
        right_limb(-22, 8),
        left_limb(42, 10),
    )
    torso = list(squat["Torso"])
    torso[5] = GROUND - lowest_foot(squat)
    squat["Torso"] = tuple(torso)
    up = base_stance()
    up["Head"] = (-STANCE_DIP * 0.5, 0, -STANCE_TURN * 0.7, 0, 0, 0)
    up["Right Arm"] = right_limb(95, 12)
    up["Left Arm"] = left_limb(112, 12)
    return beats_clip([(0, squat), (0.05, squat), (0.3, up)], False, 0.3, "Action")


def simplify(clip):
    """Drops frames a straight line between their neighbours would reproduce, so the clip costs
    less without its timing changing. Keeps the Hit frame, and any jump too big to blend safely."""
    frames = clip["frames"]
    if len(frames) < 3:
        return clip
    strike = clip.get("strike")
    kept = [frames[0]]
    index = 1
    while index < len(frames) - 1:
        # How far ahead can the straight line from the last kept frame reach?
        reach = index
        while reach < len(frames) - 1:
            candidate = frames[reach + 1]
            start = kept[-1]
            fine = True
            for middle in frames[frames.index(start) + 1 : reach + 1]:
                share = (middle["t"] - start["t"]) / (candidate["t"] - start["t"])
                if strike is not None and abs(middle["t"] - strike) < 0.0001:
                    fine = False
                    break
                for joint, values in middle["pose"].items():
                    for i in range(6):
                        a, b = start["pose"][joint][i], candidate["pose"][joint][i]
                        allowed = SIMPLIFY_DEGREES if i < 3 else SIMPLIFY_STUDS
                        if abs(a + (b - a) * share - values[i]) > allowed or (i < 3 and abs(b - a) > 70):
                            fine = False
                            break
                    if not fine:
                        break
                if not fine:
                    break
            if not fine:
                break
            reach += 1
        kept.append(frames[reach] if reach > index - 1 else frames[index])
        index = frames.index(kept[-1]) + 1
    if kept[-1] is not frames[-1]:
        kept.append(frames[-1])
    clip["frames"] = kept
    return clip


SIMPLIFY_DEGREES = 0.5
SIMPLIFY_STUDS = 0.012
MAX_SCRIPT_CHARS = 185000  # Studio's limit is about 200,000, and a push that fails loses the code


CLASH_SECONDS = 0.28  # a left and a right: seven punches a second


def bake_clash_barrage():
    """A fast, looping exchange of straight punches, one arm then the other, with the shoulders driving
    each one and the feet planted. Each fist snaps out and comes back slower. Purely for show."""
    arms = {"Right Arm": ArmPlacer("Right Arm"), "Left Arm": ArmPlacer("Left Arm")}
    legs = {"Right Leg": ArmPlacer("Right Leg"), "Left Leg": ArmPlacer("Left Leg")}
    out = {
        "Right Arm": ((0.72, 0.42, -1.3), norm((-0.16, 0.06, -1))),
        "Left Arm": ((-0.72, 0.5, -1.3), norm((0.16, 0.02, -1))),
    }

    def reach(phase):
        """How far out a fist is, 0 to 1, over a whole loop that it spends half of at home."""
        phase %= 1
        if phase < 0.14:
            return snap(phase / 0.14)
        if phase < 0.5:
            return 1 - smooth((phase - 0.14) / 0.36)
        return 0.0

    def placed(name, share):
        home, way = GUARD[name]
        target, aim_at = out[name]
        centre = tuple(home[i] + (target[i] - home[i]) * share for i in range(3))
        direction = norm(tuple(way[i] + (aim_at[i] - way[i]) * share for i in range(3)))
        return arms[name].pose(centre, direction)

    total = round(CLASH_SECONDS * FPS)
    frames = []
    for index in range(total):
        phase = index / total
        right = reach(phase)
        left = reach(phase + 0.5)
        drive = right - left
        pose = {
            "Torso": lean_torso(STANCE_DIP + 5 + 2 * max(right, left), 20 * drive, -2 * drive, 0.06 * drive, STANCE_HEIGHT),
            "Head": (-(STANCE_DIP + 5) * 0.5, 0, -12 * drive, 0, 0, 0),
            "Right Arm": placed("Right Arm", right),
            "Left Arm": placed("Left Arm", left),
        }
        lock_feet(pose, STANCE_FEET, legs)
        frames.append({"t": index * CLASH_SECONDS / total, "pose": pose})
    frames.append({"t": CLASH_SECONDS, "pose": dict(frames[0]["pose"])})
    return {"loop": True, "priority": "Action3", "seconds": CLASH_SECONDS, "frames": frames}


def bake_all():
    clips = {
        "Guard": guard_clip(),
        "Stance": stance_clip(),
        "Sprint": bake_sprint(),
        "Brake": bake_brake(),
        "BrakeSettle": bake_brake_settle(),
    }
    for suffix, running in (("", False), ("Run", True)):
        clips[f"HookLeft{suffix}"] = bake_swing("Left Arm", HOOK, running)
        clips[f"HookRight{suffix}"] = bake_swing("Right Arm", HOOK, running)
        clips[f"Uppercut{suffix}"] = bake_swing("Right Arm", UPPERCUT, running)
    clips["KickLeap"] = bake_leap()
    clips["KickAim"] = bake_aim()
    clips["KickSpin"] = bake_spin()
    clips["KickDown"] = bake_kick()
    clips["HitFlinch"] = bake_flinch()
    clips["HitFlinchHeavy"] = bake_flinch_heavy()
    clips["HitFlinchBack"] = bake_flinch_back()
    clips["HitSkid"] = bake_skid()
    clips["AirTumble"] = bake_tumble()
    clips["Slammed"] = bake_slammed()
    clips["FloorHit"] = bake_floor_hit()
    clips["Land"] = bake_land()
    clips["ClashBarrage"] = bake_clash_barrage()
    return {name: simplify(clip) for name, clip in clips.items()}


def to_luau(clips):
    lines = [
        "--!strict",
        "-- GENERATED FILE - DO NOT EDIT BY HAND. Source: animations/build_clips.py",
        "-- Each frame gives a joint's Transform as { rx, ry, rz, px, py, pz }, degrees and studs.",
        "return {",
    ]
    for name, clip in clips.items():
        lines.append(f"\t{name} = {{")
        lines.append(f"\t\tloop = {'true' if clip['loop'] else 'false'},")
        lines.append(f'\t\tpriority = "{clip["priority"]}",')
        lines.append(f"\t\tseconds = {clip['seconds']},")
        if "strike" in clip:
            lines.append(f"\t\tstrike = {clip['strike']},")
        if "spring" in clip:
            lines.append(f"\t\tspring = {clip['spring']},")
        if "turn" in clip:
            turns = ", ".join(f"{{ {t:.3f}, {value:.1f} }}" for t, value in clip["turn"])
            lines.append(f"\t\tturn = {{ {turns} }},")
        lines.append("\t\tframes = {")
        for frame in clip["frames"]:
            parts = []
            for joint, values in frame["pose"].items():
                numbers = ", ".join(f"{v:.3f}" for v in values)
                parts.append(f'["{joint}"] = {{ {numbers} }}')
            lines.append(f"\t\t\t{{ t = {frame['t']:.4f}, pose = {{ {', '.join(parts)} }} }},")
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    clips = bake_all()
    with open(os.path.join(HERE, "clips.json"), "w", encoding="utf-8", newline="\n") as out:
        json.dump(clips, out)
    source = to_luau(clips)
    # A script too big for Studio fails halfway through a push, after the old code has gone.
    assert len(source) < MAX_SCRIPT_CHARS, f"AnimClips is {len(source)} characters, over {MAX_SCRIPT_CHARS}"
    with open(
        os.path.join(PROJECT, "src", "shared", "Config", "AnimClips.luau"), "w", encoding="utf-8", newline="\n"
    ) as out:
        out.write(source)
    print("AnimClips characters", len(source))
    for name, clip in clips.items():
        print(name, "frames", len(clip["frames"]), "seconds", clip["seconds"])
    # How well a planted foot keeps pace with the ground, at the playback the game reaches at top
    # speed. Under 1 the foot skates forward a little; 1 is no skating at all.
    ground = 36
    playback = 1.5
    contact = CONTACT_SHARE * SPRINT_SECONDS / playback
    sweep = LEG_LENGTH * (math.sin(math.radians(LEG_AHEAD)) + math.sin(math.radians(-LEG_BEHIND)))
    print("sprint planted foot speed", round(sweep / contact, 1), "against ground speed", ground)
