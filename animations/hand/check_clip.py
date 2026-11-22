"""Numbers for a hand-keyed clip, next to an existing swing. Plain Python (Blender's interpreter):

  python animations/hand/check_clip.py JabRight

Reads animations/hand/out/<Clip>.dense.json (written by export_hand_clips.py). Prints, per frame:
the fist's place (right, up, forward of the root, in studs), its speed (studs per frame), how far
the feet have moved from where they started; then the same fist numbers for HookRight; then how far
the thinned clip in AnimClipsHand strays from the dense one.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import build_clips as bc  # noqa: E402

name = sys.argv[1] if len(sys.argv) > 1 else "JabRight"
ARM = "Right Arm"


def tip(pose, part):
    rot, pos = bc.part_transforms(pose)[part]
    return bc.add(pos, bc.mat_vec(rot, (0, -1, 0)))


def table(frames, strike, label):
    print(f"\n{label}: frame, t, fist right/up/forward, speed (studs/frame), bar")
    last, speeds, path = None, [], []
    for index, frame in enumerate(frames):
        p = tip(frame["pose"], ARM)
        path.append(p)
        speed = 0.0 if last is None else math.dist(p, last) / max((frame["t"] - frames[index - 1]["t"]) * 60, 1e-9)
        speeds.append(speed)
        mark = " <- HIT" if strike is not None and abs(frame["t"] - strike) < 1e-4 else ""
        print(f"  f{index + 1:<3} {frame['t']:.3f}  {p[0]:6.2f} {p[1]:6.2f} {-p[2]:6.2f}   {speed:5.2f}  {'#' * round(speed * 12)}{mark}")
        last = p
    peak = max(speeds)
    reach = max(-p[2] for p in path)
    print(f"  peak speed {peak:.2f} studs/frame ({peak * 60:.0f} studs/s) at f{speeds.index(peak) + 1}; furthest forward {reach:.2f}")
    return path, speeds


with open(os.path.join(HERE, "out", name + ".dense.json"), encoding="utf-8") as source:
    clip = json.load(source)
frames = clip["frames"]
path, speeds = table(frames, clip.get("strike"), name)

# Feet: how far each foot's bottom centre strays from where it started.
start = {leg: tip(frames[0]["pose"], leg) for leg in ("Right Leg", "Left Leg")}
worst = {leg: 0.0 for leg in start}
worst_at = {leg: 0 for leg in start}
low = 1e9
for index, frame in enumerate(frames):
    low = min(low, bc.lowest_foot(frame["pose"]))
    for leg in start:
        moved = math.dist(tip(frame["pose"], leg), start[leg])
        if moved > worst[leg]:
            worst[leg], worst_at[leg] = moved, index + 1
print("\nFEET worst slide from the start pose:", {leg: f"{worst[leg]:.3f} studs at f{worst_at[leg]}" for leg in worst},
      f"lowest point {low - bc.GROUND:+.3f} from the floor")

# Arms: does the shoulder end of each arm leave the shoulder? (a gap reads as a detached arm)
for arm in ("Right Arm", "Left Arm"):
    gap, gap_at = 0.0, 0
    for index, frame in enumerate(frames):
        parts = bc.part_transforms(frame["pose"])
        rot, pos = parts[arm]
        top = bc.add(pos, bc.mat_vec(rot, (0, 1, 0)))
        trot, tpos = parts["Torso"]
        shoulder = bc.add(tpos, bc.mat_vec(trot, bc.SHOULDER[arm]))
        distance = math.dist(top, shoulder)
        if distance > gap:
            gap, gap_at = distance, index + 1
    print(f"{arm}: top of the arm is at most {gap:.2f} studs from the shoulder point (f{gap_at})")

hook = bc.bake_swing("Right Arm", bc.HOOK, False)
table([f for f in hook["frames"] if abs(f["t"] * 60 - round(f["t"] * 60)) < 1e-6], None, "HookRight (60 fps frames; its HIT is at 0.080 s)")

# Thinned against dense: what the game plays against what Blender shows.
module = os.path.join(os.path.dirname(os.path.dirname(HERE)), "src", "shared", "Config", "AnimClipsHand.luau")
text = open(module, encoding="utf-8").read()
block = text[text.index(f"\t{name} = {{"):]
kept = []
for line in block.splitlines():
    line = line.strip()
    if line.startswith("{ t = "):
        t = float(line.split("t = ")[1].split(",")[0])
        pose = {}
        for chunk in line.split('["')[1:]:
            joint = chunk.split('"]')[0]
            pose[joint] = [float(v) for v in chunk.split("{ ")[1].split(" }")[0].split(", ")]
        kept.append((t, pose))
    elif line == "}," and kept and line == "},":
        if len(kept) > 1 and block.splitlines().index("\t},") < 10**9:
            pass
kept = kept[: next((i for i in range(1, len(kept)) if kept[i][0] < kept[i - 1][0]), len(kept))]
worst_deg = worst_studs = 0.0
for frame in frames:
    t = frame["t"]
    for index in range(len(kept) - 1):
        (t0, a), (t1, b) = kept[index], kept[index + 1]
        if t0 - 1e-6 <= t <= t1 + 1e-6:
            share = (t - t0) / (t1 - t0) if t1 > t0 else 0
            for joint, values in frame["pose"].items():
                for i in range(6):
                    error = abs(a[joint][i] + (b[joint][i] - a[joint][i]) * share - values[i])
                    if i < 3:
                        worst_deg = max(worst_deg, min(error, abs(error - 360)))
                    else:
                        worst_studs = max(worst_studs, error)
            break
print(f"\nTHINNED {len(kept)} of {len(frames)} frames kept: worst {worst_deg:.3f} degrees, {worst_studs:.4f} studs from the dense clip "
      "(straight-line blend of the numbers; the Animator's own blend is not modelled)")
