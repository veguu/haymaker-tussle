"""The flat puff against its reference, drawing by drawing, by numbers. Plain Python + numpy (Blender's
interpreter), ffmpeg to read PNGs.

  python design/vfx/smoke/compare_puff2d.py

Reference: design/vfx/smoke-study/refs-2026-11-22/puffB_frames (580 x 400 cuts of the green-screen puff at 30 fps;
its 16 drawings are video frames 16-34 less the held ones). Mine: out/puff2d_cells/c_NN.png.
For each drawing: width and height as a share of the widest drawing, white area as a share of the biggest, and the
holes' share of the filled outline.
"""
import glob
import os
import subprocess

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(os.path.dirname(os.path.dirname(HERE)), "vfx", "smoke-study", "refs-2026-11-22", "puffB_frames")
REF_DRAWINGS = [16, 17, 18, 19, 21, 22, 23, 24, 26, 27, 28, 29, 31, 32, 33, 34]
FFMPEG = glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Microsoft", "WinGet", "Packages", "*FFmpeg*", "*", "bin", "ffmpeg.exe"))[0]


def load(path, width, height):
    raw = subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.uint8).reshape(height, width, 4).astype(int)


def numbers(mask):
    ys, xs = np.nonzero(mask)
    if not len(xs):
        return 0, 0, 0, 0.0
    hull = np.zeros_like(mask)
    for x in np.unique(xs):
        column = np.nonzero(mask[:, x])[0]
        hull[column.min():column.max() + 1, x] = True
    rows = np.zeros_like(mask)
    for y in np.unique(ys):
        row = np.nonzero(mask[y])[0]
        rows[y, row.min():row.max() + 1] = True
    hull &= rows
    return xs.max() - xs.min() + 1, ys.max() - ys.min() + 1, int(mask.sum()), 100 * (1 - mask.sum() / hull.sum())


def table(label, masks):
    rows = [numbers(mask) for mask in masks]
    widest = max(r[0] for r in rows[:12])  # of the whole drawings, not the last strokes
    biggest = max(r[2] for r in rows)
    print(f"\n{label}")
    print("  width %  :", " ".join(f"{100 * r[0] / widest:5.0f}" for r in rows))
    print("  height % :", " ".join(f"{100 * r[1] / widest:5.0f}" for r in rows))
    print("  area %   :", " ".join(f"{100 * r[2] / biggest:5.0f}" for r in rows))
    print("  holes %  :", " ".join(f"{r[3]:5.0f}" for r in rows))
    return rows


if __name__ == "__main__":
    reference = []
    for frame in REF_DRAWINGS:
        image = load(os.path.join(REF, f"f_{frame + 1:02d}.png"), 580, 400)
        reference.append((image[..., 0] > 150) & (image[..., 2] > 150))
    mine = [load(os.path.join(HERE, "out", "puff2d_cells", f"c_{frame:02d}.png"), 256, 256)[..., 3] > 127 for frame in range(16)]
    print("drawing    :", " ".join(f"{k:5d}" for k in range(16)))
    table("REFERENCE", reference)
    table("MINE", mine)
