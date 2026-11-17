"""The Classes page's idles: one looping R6 pose for each class, written as maths and baked to data.

Run from the project folder:  python animations/build_class_idles.py

Writes animations/class_idles.json (read by the Blender preview, preview_class_idles.py) and
src/shared/Config/ClassIdleClips.luau (read by Ui/ClassPreview), so the two can't disagree.

Same terms as build_clips.py, whose helpers this uses: a pose is a Motor6D Transform for each R6 joint,
(rx, ry, rz in degrees, px, py, pz in studs). R6 limbs are single rigid blocks, so a pose is told by the
whole body's line: where the arms point, how the torso leans and turns, how wide the feet stand.

Below, an arm or a leg is given as (forward, out): `forward` degrees swung forward from hanging straight down
(90 = level in front, 180 = straight up, negative = behind), `out` degrees lifted away from the body
(negative = across it). Legs are given against the WORLD, so a leaning torso does not carry them off the
floor; the feet are planted where the first frame puts them and the body stands on them (lock_feet).
"""
import importlib.util
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)

spec = importlib.util.spec_from_file_location("ht_build_clips", os.path.join(HERE, "build_clips.py"))
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)

FRAMES = 24


def limb(side, forward, out=0.0):
    return B.right_limb(forward, out) if side == "R" else B.left_limb(forward, out)


def head(nod=0.0, turn=0.0, tilt=0.0):
    """+nod looks down, +turn brings the right ear forward (the face turns left)."""
    return (nod, tilt, turn, 0, 0, 0)


def idle(seconds, legs, pose_at, bob=0.04, bob_speed=1):
    """A loop. `legs` is {"R": (forward, out), "L": (forward, out)} against the world; `pose_at(phase)` gives
    the torso (lean, turn, roll, side), the head and the two arms for a phase from 0 to 1."""
    first = pose_at(0.0)
    lean = first["torso"][0]
    stand = {
        "Torso": B.lean_torso(*first["torso"]),
        "Right Leg": limb("R", legs["R"][0] + lean, legs["R"][1]),
        "Left Leg": limb("L", legs["L"][0] + lean, legs["L"][1]),
    }
    torso = list(stand["Torso"])
    torso[5] = B.GROUND - B.lowest_foot(stand)
    stand["Torso"] = tuple(torso)
    feet = {name: B.part_foot(stand, name) for name in ("Right Leg", "Left Leg")}
    placers = {"Right Leg": B.ArmPlacer("Right Leg"), "Left Leg": B.ArmPlacer("Left Leg")}
    frames = []
    for index in range(FRAMES):
        phase = index / FRAMES
        want = pose_at(phase)
        pose = {
            "Torso": B.lean_torso(*want["torso"], torso[5]),
            "Head": head(*want.get("head", (0, 0, 0))),
            "Right Arm": limb("R", *want["right"]),
            "Left Arm": limb("L", *want["left"]),
        }
        B.lock_feet(pose, feet, placers)
        body = list(pose["Torso"])
        body[5] += bob * (B.wave_at(phase * bob_speed) - 1) * 0.5
        pose["Torso"] = tuple(body)
        frames.append({"t": index * seconds / FRAMES, "pose": pose})
    frames.append({"t": seconds, "pose": dict(frames[0]["pose"])})
    return {"loop": True, "priority": "Idle", "seconds": seconds, "frames": frames}


def bruiser():
    """Heavy and square: feet wide, arms held off the body, a slow chest heave."""

    def at(phase):
        breath = B.wave_at(phase)
        return {
            "torso": (8 - 1.6 * breath, 8, 0, 0),
            "head": (-4 + 1.0 * breath, -6, 0),
            "right": (16 + 2 * breath, 30 + 3.5 * breath),
            "left": (16 + 2 * breath, 30 + 3.5 * breath),
        }

    return idle(3.0, {"R": (-4, 16), "L": (6, 16)}, at, bob=0.05)


def inferno():
    """One fist thrown up high and pumping, the other arm back, bouncing on the spot."""

    def at(phase):
        pump = B.wave_at(phase * 2)
        sway = B.wave_at(phase)
        return {
            "torso": (-6 + 1.2 * pump, -14 + 2 * sway, 1.5 * sway, 0.04 * sway),
            "head": (-10, 10, 0),
            "right": (166 + 7 * pump, 8),
            "left": (-18 - 4 * pump, 14),
        }

    return idle(1.6, {"R": (-10, 8), "L": (14, 8)}, at, bob=0.12, bob_speed=2)


def beast():
    """Low and wide, leaning in, both arms out in front and clawing in turn."""

    def at(phase):
        claw = B.wave_at(phase * 2)
        breath = B.wave_at(phase)
        return {
            "torso": (30 + 2 * breath, 6 + 3 * claw, 0, 0.05 * claw),
            "head": (-24, -4, 0),
            "right": (60 + 12 * claw, 22),
            "left": (60 - 12 * claw, 22),
        }

    return idle(1.8, {"R": (22, 20), "L": (-18, 20)}, at, bob=0.08, bob_speed=2)


def trickster():
    """Loose and showy: one arm up and waving, a hand out at the hip, the weight rocking side to side."""

    def at(phase):
        sway = B.wave_at(phase)
        wave = B.wave_at(phase * 2)
        return {
            "torso": (-3, 16 + 3 * sway, 5 * sway, 0.12 * sway),
            "head": (-4, -10, -6 * sway),
            "right": (-10, 26 + 3 * sway),
            "left": (154, 14 + 12 * wave),
        }

    return idle(2.0, {"R": (0, 6), "L": (18, 12)}, at, bob=0.06, bob_speed=2)


def dragon():
    """Arms lifted out like half-open wings and beating slowly, chest up, as if held on the air. (Not level:
    level arms are six studs across, wider than the space the Classes page gives the figure.)"""

    def at(phase):
        beat = B.wave_at(phase)
        late = B.wave_at(phase, -0.12)
        return {
            "torso": (-8 - 2 * beat, 0, 0, 0),
            "head": (-10 + 2 * late, 0, 0),
            "right": (6, 46 + 7 * late),
            "left": (6, 46 + 7 * late),
        }

    return idle(3.2, {"R": (-2, 10), "L": (4, 10)}, at, bob=0.16)


def frost():
    """Still and cold: arms crossed low in front, turned half away, barely breathing."""

    def at(phase):
        breath = B.wave_at(phase)
        return {
            "torso": (0.6 * breath, -18, 0, 0),
            "head": (2, 16 + 1.5 * breath, 0),
            "right": (30 + 1.0 * breath, -22),
            "left": (30 + 1.0 * breath, -22),
        }

    return idle(4.0, {"R": (0, 3), "L": (4, 4)}, at, bob=0.02)


def tempest():
    """Leaning into a run that never starts: one arm reaching ahead, one back, quick on the toes."""

    def at(phase):
        pump = B.wave_at(phase * 2)
        sway = B.wave_at(phase)
        return {
            "torso": (22 + 1.5 * pump, 22 + 3 * sway, 0, 0.03 * sway),
            "head": (-16, -12, 0),
            "right": (78 + 8 * pump, 4),
            "left": (-58 - 8 * pump, 6),
        }

    return idle(1.2, {"R": (-26, 4), "L": (30, 4)}, at, bob=0.1, bob_speed=2)


def bake_all():
    # Base is the game's own fighting stance: the boxer's guard every fighter idles in.
    return {
        "Base": B.stance_clip(),
        "Bruiser": bruiser(),
        "Inferno": inferno(),
        "Beast": beast(),
        "Trickster": trickster(),
        "Dragon": dragon(),
        "Frost": frost(),
        "Tempest": tempest(),
    }


if __name__ == "__main__":
    clips = bake_all()
    with open(os.path.join(HERE, "class_idles.json"), "w", encoding="utf-8", newline="\n") as out:
        json.dump(clips, out)
    source = B.to_luau(clips).replace(
        "-- GENERATED FILE - DO NOT EDIT BY HAND. Source: animations/build_clips.py",
        "-- GENERATED FILE - DO NOT EDIT BY HAND. Source: animations/build_class_idles.py\n"
        "-- The Classes page's idles, by kit id (Ui/ClassPreview). A kit with none stands as Base does.",
    )
    assert len(source) < B.MAX_SCRIPT_CHARS, f"ClassIdleClips is {len(source)} characters"
    with open(
        os.path.join(PROJECT, "src", "shared", "Config", "ClassIdleClips.luau"), "w", encoding="utf-8", newline="\n"
    ) as out:
        out.write(source)
    print("ClassIdleClips characters", len(source))
    for name, clip in clips.items():
        print(name, "frames", len(clip["frames"]), "seconds", clip["seconds"])
