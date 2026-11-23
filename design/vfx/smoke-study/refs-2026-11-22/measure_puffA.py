"""Measures the green-screen reference puff the owner prefers ("puff A": a wisp that curls up into a swirl, splits
into beans and shrinks to dots). Frames cut by ffmpeg into puffA_frames (608 x 560, 30 fps, from 5.7 s).

  python design/vfx/smoke-study/refs-2026-11-22/measure_puffA.py [blobs]

Per frame: white area, bounding box, how much changed against the frame before, and the separate blobs. With
"blobs": every blob's middle and size on the frames where it has split.
"""
import glob
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FFMPEG = glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Microsoft", "WinGet", "Packages", "*FFmpeg*", "*", "bin", "ffmpeg.exe"))[0]
W, H = 608, 560


def load(frame):
    path = os.path.join(HERE, "puffA_frames", f"f_{frame + 1:02d}.png")
    raw = subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True).stdout
    image = np.frombuffer(raw, dtype=np.uint8).reshape(H, W, 3).astype(int)
    return (image[..., 0] > 150) & (image[..., 2] > 150)


def blobs(mask):
    """[(area, x, y, width, height)] of the connected white shapes, biggest first."""
    seen = np.zeros_like(mask)
    out = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        stack, xs, ys = [(y0, x0)], [], []
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            xs.append(x)
            ys.append(y)
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if len(xs) >= 6:
            out.append((len(xs), sum(xs) / len(xs), sum(ys) / len(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1))
    return sorted(out, reverse=True)


if __name__ == "__main__":
    detail = "blobs" in sys.argv
    last = None
    print("frame   area  left right  top bottom  width height  changed%  blobs")
    for frame in range(3, 34):
        mask = load(frame)
        mask[:, :] &= True
        ys, xs = np.nonzero(mask)
        if not len(xs):
            print(f"{frame:5d}  empty")
            last = mask
            continue
        found = blobs(mask)
        changed = 100 * (mask ^ last).sum() / mask.sum() if last is not None else 0
        print(f"{frame:5d} {mask.sum():6d} {xs.min():5d} {xs.max():5d} {ys.min():4d} {ys.max():6d} {xs.max() - xs.min() + 1:6d} "
              f"{ys.max() - ys.min() + 1:6d} {changed:9.0f}  {len(found)}")
        if detail and len(found) > 1:
            for area, x, y, w, h in found:
                print(f"         blob area {area:5d} at ({x:5.0f}, {y:5.0f}) size {w:3d} x {h:3d}")
        last = mask
