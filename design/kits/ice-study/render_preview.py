"""Step 5: the Glacier erupting, frame by frame, with KitModels' ERUPT timings, from the game camera.
  blender -b --factory-startup --python-exit-code 1 --python render_preview.py -- <side> <floor> <out dir> <width> <height> [first] [last]
side: "today" (the kit and layout in the game now) or "new" (the new kit, the flower layout, the pale tones).
Writes <out dir>/<side>_<floor>/f_0000.png ...: 20 empty frames, the eruption at 60 fps, 20 empty frames.
"""
import os
import sys
import time

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import FLOWER, FLOWER_CENTRE, GAME_BLUES, PALE_GLASS  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
SIDE, FLOOR, OUT, WIDTH, HEIGHT = args[0], args[1], args[2], int(args[3]), int(args[4])
FPS, LEAD = 60, 20
LAST_T = 2 * 2 / 60 + S.RISE + S.SETTLE + S.GLACIER_HOLD + max(S.SINK, S.BREAK + 0.85)   # the last wave has sunk, or its chunks have gone
FRAMES = LEAD + int(LAST_T * FPS) + 2 + LEAD
FIRST = int(args[5]) if len(args) > 5 else 0
LAST = int(args[6]) if len(args) > 6 else FRAMES - 1
OLD_GLB = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "out", "export", "ice_kit.glb")

S.new_scene(width=WIDTH, height=HEIGHT, samples=16)
if SIDE == "today":
    S.ICE = GAME_BLUES
    kit = S.load_kit(OLD_GLB)
    setup = {"table": None, "centre": S.GLACIER_CENTRE, "transparency": 0.1}
else:
    S.ICE = PALE_GLASS
    kit = P.build_kit()
    setup = {"table": FLOWER, "centre": FLOWER_CENTRE, "transparency": 0.25}
    if SIDE == "shatter":      # the new ice, leaving by breaking instead of sinking
        setup["leave"] = "shatter"
S.floor(FLOOR)
S.fighter()
S.game_camera()
folder = os.path.join(OUT, f"{SIDE}_{FLOOR}")
os.makedirs(folder, exist_ok=True)
import shutil  # noqa: E402

table = setup["table"] or S.GLACIER


def moment(t):
    """What the cluster looks like at `t`, as a key: frames with the same key are the same picture (before the
    stomp, while every crystal stands, after the last has sunk), so they are rendered once and copied."""
    if t < 0:
        return "empty"
    states = []
    for spec in table:
        state = S.erupt_state(t - spec[4] * 2 / 60)
        states.append(None if state is None else (round(state[0], 4), round(state[1], 4), state[2]))
    if SIDE == "shatter" and t >= S.RISE + S.SETTLE + S.GLACIER_HOLD:
        return ("leaving", round(t, 4)) if t < LAST_T else "empty"     # chunks in flight: every frame differs
    return "empty" if all(s is None for s in states) else tuple(states)


started = time.time()
seen, rendered, copied = {}, 0, 0
for frame in range(FIRST, LAST + 1):
    path = os.path.join(folder, f"f_{frame:04d}.png")
    key = moment((frame - LEAD) / FPS)
    if os.path.exists(path) and os.environ.get("ICE_KEEP") == "1":
        seen.setdefault(key, path)     # resuming a stopped run: keep what is already rendered
        continue
    if key in seen:
        shutil.copyfile(seen[key], path)
        copied += 1
        continue
    t = (frame - LEAD) / FPS
    made = S.glacier(kit, t, **setup) if t >= 0 else []
    S.render(path)
    S.remove(made)
    seen[key] = path
    rendered += 1
print(f"RESULT_JSON={{\"frames\": {FRAMES}, \"rendered\": {rendered}, \"copied\": {copied}, \"seconds\": {time.time() - started:.1f}}}")
