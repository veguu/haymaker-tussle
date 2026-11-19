"""Checks every hop of the village obby against the game's own movement, AT FULL RUNNING SPEED.

    python design/lobby/prove/check_obby.py [out folder]

Reads <out>/obby.json (written by village.py: the course's standable tops, in order). For each hop it takes the
flat gap between the two footprints, the height change, and how deep the landing is along the way you travel.

THE RULE (owner, 2026-11-18: "the obby needs to be spaced out so it can match the speed of the running"):
a running jump taken at full speed from the very edge must come down ON the landing: at least MARGIN studs past
its near edge and at least MARGIN short of its far edge. A course that needs you to slow down fails.

THE MOVES (GameConfig.Movement / Jump, and the Play measurements in HANDOFF move-14):
  jump   a running Space jump as MEASURED from 60 studs/s: 10.7 high, 40 long, 0.68 s. Lower than the settings
         alone give (16.3 high), so it is the careful number.
  hop    a standing Space jump: 50 up (6.3 high), drifting about 20 studs/s. Only the gate's re-entry stair uses it.
A hop with gap 0 is a walk-on (the ramp, the beam) and is not judged.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "out", "village")
G_UP, G_DOWN = 196.2, 196.2 * 1.3  # AirRecovery.FallGravityScale 1.3 on the way down
MARGIN = 3.0
RUN = (64.8, 59.0)  # up speed and flat speed of the measured running jump
HOP = (50.0, 20.0)


def reach(up, flat, rise):
    """How far along the floor a jump travels before coming down onto a top `rise` studs higher (None: too high)."""
    apex = up * up / (2 * G_UP)
    if rise > apex:
        return None
    return flat * (up / G_UP + math.sqrt(2 * (apex - rise) / G_DOWN))


def rect(o):
    if o["r"]:
        return o["u"] - o["r"], o["u"] + o["r"], o["d"] - o["r"], o["d"] + o["r"]
    return o["u0"], o["u1"], o["d0"], o["d1"]


def gap_and_depth(a, b):
    """The flat gap from a to b, and how deep b is along the axis you cross the gap on."""
    if a["r"] and b["r"]:  # two round tops: straight between their rims
        return math.hypot(b["u"] - a["u"], b["d"] - a["d"]) - a["r"] - b["r"], 2 * b["r"]
    a0, a1, a2, a3 = rect(a)
    b0, b1, b2, b3 = rect(b)
    du = max(b0 - a1, a0 - b1, 0.0)
    dd = max(b2 - a3, a2 - b3, 0.0)
    if b["r"]:
        depth = 2 * b["r"]
    else:
        depth = (b1 - b0) if du >= dd else (b3 - b2)
    return math.hypot(du, dd), depth


def main():
    course = json.load(open(os.path.join(OUT, "obby.json"), encoding="utf-8"))
    stair = [o for o in course if o["name"].startswith("Gate step")]
    route = [o for o in course if not o["name"].startswith("Gate step")]
    bad = 0
    print(f"{'hop':<44} {'gap':>5} {'rise':>5} {'landing':>7}  full-speed jump")
    prev = None
    for o in route:
        if prev is not None:
            g, depth = gap_and_depth(prev, o)
            rise = o["top"] - prev["top"]
            name = f"{prev['name']} -> {o['name']}"
            if g < 0.5:
                print(f"{name:<44} {g:5.1f} {rise:+5.1f} {depth:7.1f}  walk on")
            else:
                r = reach(RUN[0], RUN[1], rise)
                if r is None:
                    verdict, ok = "FAIL: too high for a running jump", False
                elif r < g + MARGIN:
                    verdict, ok = f"FAIL: lands {r:.1f}, short of the gap", False
                elif r > g + depth - MARGIN:
                    verdict, ok = f"FAIL: lands {r:.1f}, overshoots a {depth:.0f}-stud landing", False
                else:
                    verdict, ok = f"lands {r - g:4.1f} in, {g + depth - r:4.1f} to spare", True
                bad += 0 if ok else 1
                print(f"{name:<44} {g:5.1f} {rise:+5.1f} {depth:7.1f}  {verdict}")
        prev = o
    prev = {"name": "the square", "top": 4.0}
    gate = [o for o in route if o["name"] == "Gate deck"]
    for o in (stair + gate) if stair else []:
        rise = o["top"] - prev["top"]
        r = reach(HOP[0], HOP[1], rise)
        ok = r is not None
        bad += 0 if ok else 1
        print(f"{'(re-entry stair) ' + prev['name'] + ' -> ' + o['name']:<44} {0.0:5.1f} {rise:+5.1f} {'':>7}  {'standing hop' if ok else 'FAIL: too high for a standing hop'}")
        prev = o
    print(f"{len(route) - 1 + (len(stair) + 1 if stair else 0)} hops, {bad} failing; margin {MARGIN} studs at both ends of every landing")
    sys.exit(1 if bad else 0)


main()
