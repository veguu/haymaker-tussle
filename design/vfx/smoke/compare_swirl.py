"""The swirl puff against its reference, drawing by drawing, by numbers. Plain Python + numpy (Blender's
interpreter), ffmpeg to read PNGs.

  python design/vfx/smoke/compare_swirl.py

Reference: design/vfx/smoke-study/refs-2026-11-22/puffA_frames (608 x 560 cuts at 30 fps; 1 px = 0.01 unit).
Mine: out/swirl_cells/c_NN.png (256 px cells, 6.8 units wide: 1 px = 0.0266 unit).
For each drawing: width, height and white area in units, and how many separate shapes there are.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(HERE)), "vfx", "smoke-study", "refs-2026-11-22"))
from compare_puff2d import load  # noqa: E402
from measure_puffA import blobs  # noqa: E402
import measure_puffA  # noqa: E402

REF = os.path.join(os.path.dirname(os.path.dirname(HERE)), "vfx", "smoke-study", "refs-2026-11-22", "puffA_frames")
REF_DRAWINGS = [4, 7, 8, 10, 12, 15, 17, 19, 20, 22, 23, 24, 25, 27, 28, 30]


def row(mask, unit, least):
    ys, xs = np.nonzero(mask)
    if not len(xs):
        return 0.0, 0.0, 0.0, 0
    shapes = [b for b in blobs(mask) if b[0] >= least]
    return (xs.max() - xs.min() + 1) * unit, (ys.max() - ys.min() + 1) * unit, mask.sum() * unit * unit, len(shapes)


def table(label, rows):
    print(f"\n{label}")
    print("  width   :", " ".join(f"{r[0]:5.2f}" for r in rows))
    print("  height  :", " ".join(f"{r[1]:5.2f}" for r in rows))
    print("  area    :", " ".join(f"{r[2]:5.2f}" for r in rows))
    print("  shapes  :", " ".join(f"{r[3]:5d}" for r in rows))


if __name__ == "__main__":
    reference = []
    for frame in REF_DRAWINGS:
        image = load(os.path.join(REF, f"f_{frame + 1:02d}.png"), 608, 560)
        reference.append(row((image[..., 0] > 150) & (image[..., 2] > 150), 0.01, 40))
    measure_puffA.W = measure_puffA.H = 256
    mine = [row(load(os.path.join(HERE, "out", "swirl_cells", f"c_{frame:02d}.png"), 256, 256)[..., 3] > 127, 6.8 / 256, 3)
            for frame in range(16)]
    print("drawing   :", " ".join(f"{k:5d}" for k in range(16)))
    table("REFERENCE (units: 1 = 100 px of the reference)", reference)
    table("MINE", mine)
