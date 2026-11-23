"""Frost texture, second version (512 x 512, tileable), after a study of all four ice references
(sheets/texture_study.jpg, 2026-11-22). What they share, and the first texture lacked:
  * BIG patches, not fine lines: ragged white frost against clear mid-blue ice, each patch a fifth to a
    half of a blade wide (flower reference; Pew's ice has the same in cream and navy);
  * the patches are stretched along the blade, with long bright streaks running its length;
  * strong contrast: white (236,251,255) against (130,180,215), about half and half;
  * fine sparkle only inside the white; a few thin dark fracture lines; crack lines are rare.
It multiplies the part's Color (white = unchanged). V runs along the blade (the meshes' box UVs).
  python.exe make_frost_texture2.py <out.png>
"""
import subprocess
import sys

import numpy as np

SIZE = 512
rng = np.random.default_rng(20261123)


def noise(px, py):
    """Tileable value noise with `px` cells across and `py` cells up."""
    grid = rng.random((py, px))

    def axis(period):
        c = np.arange(SIZE) * period / SIZE
        i0 = np.floor(c).astype(int)
        f = c - i0
        f = f * f * (3 - 2 * f)
        return i0, (i0 + 1) % period, f
    x0, x1, fx = axis(px)
    y0, y1, fy = axis(py)
    top = grid[y0][:, x0] * (1 - fx) + grid[y0][:, x1] * fx
    bottom = grid[y1][:, x0] * (1 - fx) + grid[y1][:, x1] * fx
    return top * (1 - fy)[:, None] + bottom * fy[:, None]


def norm(a):
    return (a - a.min()) / (a.max() - a.min())


# Patches: wide cells across (few across U), long along V; ragged edges from finer layers.
patch = norm(0.55 * noise(5, 2) + 0.25 * noise(10, 4) + 0.13 * noise(24, 10) + 0.07 * noise(64, 40))
cut = np.quantile(patch, 0.42)                               # 58 % of the surface is frost, as in the flower reference
frost = np.clip((patch - cut) / 0.05, 0, 1)                  # hard, ragged boundary
# Streaks along the blade: very thin across U, long along V.
streak = norm(0.6 * noise(48, 2) + 0.4 * noise(96, 3))
streaks = np.clip((streak - 0.8) / 0.15, 0, 1)
frost = np.maximum(frost, streaks * 0.6)
# Inside the clear ice: soft depth; inside the frost: sparkle.
depth = norm(noise(6, 5))
sparkle = np.clip((noise(128, 128) - 0.8) / 0.2, 0, 1)
clear = np.array([0.62, 0.80, 0.93])[None, None, :] * (0.86 + 0.2 * depth[..., None])
white = np.array([0.93, 0.98, 1.0])[None, None, :] * (0.95 + 0.05 * sparkle[..., None])
rgb = clear * (1 - frost[..., None]) + white * frost[..., None]
# A few thin dark fractures across the blade, in the clear ice only.
fracture = norm(noise(3, 14))
line = np.clip(1 - np.abs(fracture - 0.5) / 0.012, 0, 1) * (1 - frost)
rgb = rgb * (1 - 0.0 * line[..., None])   # fracture lines dropped: they drew loops, which no reference has
rgb = np.clip(rgb, 0, 1)
raw = (rgb * 255 + 0.5).astype(np.uint8).tobytes()
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{SIZE}x{SIZE}", "-i", "-", sys.argv[1]],
               input=raw, check=True)
print("white share", round(float((frost > 0.5).mean()), 2), "mean", [round(float(v), 2) for v in rgb.reshape(-1, 3).mean(0)])
