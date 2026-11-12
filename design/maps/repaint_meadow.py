"""Repaint only Gnomon's 12 floor tiles' colour maps (Meadow_jk_Color.png) from gnomon_ground.meadow, without Blender
and without the 25-minute full build. Same grid, same pixel centres and the same pond paint as gnomon.py's
surface_tiles + meadow_painter, so the tiles drop onto the existing meshes and UVs unchanged.

    python repaint_meadow.py [--check] [--px 1024] [--jobs 6]

--check repaints one tile and compares it with the file on disk (it should match unless the painter changed).
The .blend reads these PNGs from out/gnomon/textures, so it shows the new paint when next opened.
"""
import math
import os
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gnomon_ground as GG  # noqa: E402
import paint as P  # noqa: E402

TEX = os.path.join(HERE, "out", "gnomon", "textures")
A, B, RIM, TILE = 213.0, 176.0, 3.0, 128.0  # common.OVALS["gnomon"], common.RIM, surfaces.TILE (gnomon build)
POND = dict(x=0.0, y=0.0, semiX=24.0, semiY=18.0, wobble=[(3, 0.08, 0.6), (5, 0.05, 2.1)], depth=1.6, inner=0.68, water=0.55)


def pond_rho(x, y):
    u = (np.asarray(x, float) - POND["x"]) / POND["semiX"]
    v = (np.asarray(y, float) - POND["y"]) / POND["semiY"]
    th = np.arctan2(v, u)
    wob = 1.0 + sum(a * np.sin(k * th + ph) for k, a, ph in POND["wobble"])
    return np.hypot(u, v) / wob


def pond_paint(X, Y, col):
    """gnomon_dress.pond_paint (copied: that module needs Blender)."""
    d = POND["depth"] * P.smoothstep(1.0, POND["inner"], pond_rho(X, Y))
    bank = P.smoothstep(0.02, 0.35, d)
    col = P.mix(col, P.rgb(58, 92, 56), 0.55 * bank)
    bed = P.smoothstep(POND["water"] * 0.8, POND["water"] * 1.3, d)
    return P.mix(col, P.rgb(118, 120, 86), 0.8 * bed)


def tiles():
    a, b = A - RIM, B - RIM
    nx, ny = math.ceil(2 * a / TILE), math.ceil(2 * b / TILE)
    ox, oy = -nx * TILE / 2, -ny * TILE / 2
    out = []
    for j in range(ny):
        for i in range(nx):
            name = f"Meadow_{j}{i}"
            if os.path.exists(os.path.join(TEX, f"{name}_Color.png")):
                out.append((name, ox + i * TILE, oy + j * TILE))
    return out


def paint(job):
    name, x0, y0, px, dest = job
    step = TILE / px
    xs = x0 + (np.arange(px) + 0.5) * step
    ys = y0 + (np.arange(px) + 0.5) * step
    X, Y = np.meshgrid(xs, ys)
    col, _, _ = GG.meadow(X, Y)
    col = pond_paint(X, Y, col)
    srgb = np.clip(P.linear_to_srgb(col), 0, 1)
    from PIL import Image

    # rows run with Y; Blender's images store the bottom row first, so the PNG's top row is the largest Y
    Image.fromarray((srgb[::-1] * 255 + 0.5).astype(np.uint8)).save(dest)
    return dest


if __name__ == "__main__":
    args = sys.argv[1:]
    px = int(args[args.index("--px") + 1]) if "--px" in args else 1024
    jobs = int(args[args.index("--jobs") + 1]) if "--jobs" in args else 6
    todo = tiles()
    if "--check" in args:
        from PIL import Image

        name, x0, y0 = [t for t in todo if t[0] == "Meadow_11"][0]
        dest = os.path.join(HERE, "out", "gnomon", "repaint_check.png")
        paint((name, x0, y0, 256, dest))
        new = np.asarray(Image.open(dest).convert("RGB"), float)
        old = np.asarray(Image.open(os.path.join(TEX, f"{name}_Color.png")).convert("RGB").resize((256, 256)), float)
        flip = np.asarray(Image.open(os.path.join(TEX, f"{name}_Color.png")).convert("RGB").resize((256, 256)).transpose(Image.FLIP_TOP_BOTTOM), float)
        print("mean abs diff as-is %.2f, flipped %.2f" % (np.abs(new - old).mean(), np.abs(new - flip).mean()))
        sys.exit(0)
    work = [(n, x0, y0, px, os.path.join(TEX, f"{n}_Color.png")) for n, x0, y0 in todo]
    with ProcessPoolExecutor(max_workers=jobs) as ex:
        for d in ex.map(paint, work):
            print("PAINTED", d, flush=True)
