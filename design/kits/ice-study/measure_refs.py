"""Reference measurements for the Frost ice remake (2026-11-22).

Run with Blender's bundled python (numpy, no PIL); frames are read through ffmpeg rawvideo:
  python.exe measure_refs.py "<ice-study folder>"
Prints: tones along blades of reference C (Niagara-Ice), tones of reference D's chunks (ARC),
and a per-frame brightness / height timeline of C's arrival and leaving.
"""
import json
import subprocess
import sys

import numpy as np

ROOT = sys.argv[1]
C = ROOT + "/ref/hd/dIWMbXMnwqc.mp4"   # 2560x1440, 30 fps
D = ROOT + "/ref/hd/hAUY_cFofLw.mp4"   # 2560x1440, 59.94 fps
W, H = 2560, 1440


def frames(path, start, count, fps=None):
    vf = ["-vf", f"fps={fps}"] if fps else []
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start), "-i", path, *vf, "-frames:v", str(count),
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3)


def patch(img, x, y, r=4):
    return [int(v) for v in img[y - r:y + r + 1, x - r:x + r + 1].reshape(-1, 3).mean(0).round()]


def hsv(rgb):
    r, g, b = [v / 255 for v in rgb]
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d == 0:
        h = 0
    elif mx == r:
        h = (60 * ((g - b) / d) + 360) % 360
    elif mx == g:
        h = 60 * ((b - r) / d) + 120
    else:
        h = 60 * ((r - g) / d) + 240
    return [round(h), round(0 if mx == 0 else d / mx, 2), round(mx, 2)]


out = {}

# --- C: the standing cluster at 3.6 s. Points are in the 1440x810 crop at (600, 380). ---
still = frames(C, 3.6, 1)[0]
OX, OY = 600, 380
blades = {
    "big_upper_left": ((560, 500), (265, 140)),
    "second_left": ((600, 470), (460, 180)),
    "centre": ((690, 540), (668, 160)),
    "upper_right": ((790, 480), (1018, 195)),
    "needle_right": ((900, 530), (1300, 447)),
    "needle_far_left": ((520, 500), (145, 298)),
}
tones = {}
for name, ((x0, y0), (x1, y1)) in blades.items():
    row = []
    for share in (0.05, 0.25, 0.5, 0.75, 0.93):
        x = round(x0 + (x1 - x0) * share) + OX
        y = round(y0 + (y1 - y0) * share) + OY
        rgb = patch(still, x, y)
        row.append({"share": share, "rgb": rgb, "hsv": hsv(rgb)})
    tones[name] = row
tones["background"] = patch(still, 100 + OX, 60 + OY, 8)
tones["mist"] = patch(still, 1250 + OX, 250 + OY, 8)
tones["floor_frost"] = patch(still, 700 + OX, 690 + OY, 8)
out["C_tones"] = tones

# The ice's own pixels: brighter than the mist, inside the cluster's box. Percentiles of its colour.
box = still[OY + 130:OY + 640, OX + 130:OX + 1320].reshape(-1, 3).astype(float)
luma = box @ np.array([0.2126, 0.7152, 0.0722])
ice = box[luma > 150]
order = np.argsort(ice @ np.array([0.2126, 0.7152, 0.0722]))
pct = {}
for p in (5, 25, 50, 75, 95):
    rgb = [int(v) for v in ice[order[int(len(order) * p / 100)]].round()]
    pct[p] = {"rgb": rgb, "hsv": hsv(rgb)}
out["C_ice_percentiles"] = pct

# --- C timeline: every frame from 2.0 s to 5.7 s. ---
seq = frames(C, 2.0, 111)
line = []
for index, img in enumerate(seq):
    region = img[300:1100, 500:2100].astype(float)
    lum = region @ np.array([0.2126, 0.7152, 0.0722])
    bright = lum > 150
    rows = np.where(bright.sum(1) > 12)[0]
    cols = np.where(bright.sum(0) > 12)[0]
    line.append({
        "t": round(2.0 + index / 30, 3),
        "white_share": round(float((lum > 235).mean()), 4),
        "bright_share": round(float(bright.mean()), 4),
        "top": int(rows.min()) + 300 if len(rows) else None,
        "bottom": int(rows.max()) + 300 if len(rows) else None,
        "left": int(cols.min()) + 500 if len(cols) else None,
        "right": int(cols.max()) + 500 if len(cols) else None,
    })
out["C_timeline"] = line

# --- D: the chunks at 9.3 s (crop 1440x810 at (1100, 60)) and on the floor at 12.5 s (crop at (1120, 520)). ---
fly = frames(D, 9.3, 1)[0]
floor = frames(D, 12.5, 1)[0]
points_fly = {"chunk_top_right": (1000, 250), "chunk_right": (1100, 460), "chunk_far_right": (1260, 445),
              "chunk_mid_left": (440, 395), "chunk_big_low": (480, 600), "chunk_left": (150, 580), "background": (200, 150)}
out["D_fly"] = {k: {"rgb": patch(fly, x + 1100, y + 60), "hsv": hsv(patch(fly, x + 1100, y + 60))} for k, (x, y) in points_fly.items()}
points_floor = {"big_lit": (440, 280), "big_shade": (470, 320), "right_a_lit": (1000, 470), "right_a_shade": (1040, 510),
                "right_b": (1250, 480), "left_low": (200, 410), "ground": (700, 600)}
out["D_floor"] = {k: {"rgb": patch(floor, x + 1120, y + 520), "hsv": hsv(patch(floor, x + 1120, y + 520))} for k, (x, y) in points_floor.items()}
for name, img, ox, oy in (("D_fly_percentiles", fly, 1100, 60), ("D_floor_percentiles", floor, 1120, 520)):
    reg = img[oy:oy + 810, ox:ox + 1440].reshape(-1, 3).astype(float)
    lum = reg @ np.array([0.2126, 0.7152, 0.0722])
    icepx = reg[lum > 110]
    order = np.argsort(icepx @ np.array([0.2126, 0.7152, 0.0722]))
    res = {}
    for p in (5, 25, 50, 75, 95):
        rgb = [int(v) for v in icepx[order[int(len(order) * p / 100)]].round()]
        res[p] = {"rgb": rgb, "hsv": hsv(rgb)}
    out[name] = res

with open(ROOT + "/ref_measurements.json", "w") as handle:
    json.dump(out, handle, indent=1)
print(json.dumps({k: v for k, v in out.items() if k != "C_timeline"}))
for row in line:
    print(row)
