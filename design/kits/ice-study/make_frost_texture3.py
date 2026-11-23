"""Frost texture, third version (512 x 512, tileable): CRYSTALLINE frost.
The second version's patches had soft round edges and read as camouflage; the flower reference's frost has
sharp, flaky, angular edges. So the surface is built from angular cells (a Voronoi pattern, stretched along
the blade): each cell is either white frost or clear pale-blue ice, in big groups; small flakes break up the
group edges; the seams between cells are thin bright lines, like facets catching light. Paler overall than
version 2, so the ice stays as pale as the owner's pick (solid, paler).
It multiplies the part's Color (white = unchanged). V runs along the blade (the meshes' box UVs).
  python.exe make_frost_texture3.py <out.png>
"""
import subprocess
import sys

import numpy as np

SIZE = 512
rng = np.random.default_rng(20261124)
ys, xs = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE


def cells(count, stretch):
    """Tileable Voronoi: per pixel, the nearest point's index and the gap to the second nearest (0 at a seam).
    `stretch` > 1 makes the cells that many times longer along V than across U."""
    pts = rng.random((count, 2)).astype(np.float32)
    f1 = np.full((SIZE, SIZE), 9.0, np.float32)
    f2 = np.full((SIZE, SIZE), 9.0, np.float32)
    owner = np.zeros((SIZE, SIZE), np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xs - px)
        dx = np.minimum(dx, 1 - dx)
        dy = np.abs(ys - py)
        dy = np.minimum(dy, 1 - dy) / stretch
        d = np.hypot(dx, dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        owner = np.where(closer, i, owner)
        f1 = np.where(closer, d, f1)
    return owner, f2 - f1, pts


def smooth_noise(px, py):
    grid = rng.random((py, px))
    gx = xs * px
    gy = ys * py
    x0 = np.floor(gx).astype(int) % px
    y0 = np.floor(gy).astype(int) % py
    fx = gx - np.floor(gx)
    fy = gy - np.floor(gy)
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x1, y1 = (x0 + 1) % px, (y0 + 1) % py
    return (grid[y0, x0] * (1 - fx) + grid[y0, x1] * fx) * (1 - fy) + (grid[y1, x0] * (1 - fx) + grid[y1, x1] * fx) * fy


# Big angular plates, three times as long as wide; grouped into frost and clear by a slow noise.
owner, seam, pts = cells(70, 3.0)
group = smooth_noise(3, 2)
value = group[(pts[:, 1] * SIZE).astype(int) % SIZE, (pts[:, 0] * SIZE).astype(int) % SIZE]
is_frost = value > np.quantile(value, 0.45)
frost = is_frost[owner].astype(np.float32)
# Small flakes: one in six small cells flips, so the group edges are broken and flaky.
small_owner, small_seam, small_pts = cells(520, 2.0)
flip = rng.random(len(small_pts)) < 0.16
frost = np.where(flip[small_owner], 1 - frost, frost)
# Tone inside each plate: every plate its own slight shade (facets), frost sparkles.
shade = (rng.random(len(pts)) * 0.10)[owner]
sparkle = np.clip((smooth_noise(160, 160) - 0.82) / 0.18, 0, 1)
clear = np.array([0.72, 0.87, 0.97], np.float32)[None, None, :] * (1 - shade[..., None])
white = np.array([0.95, 0.985, 1.0], np.float32)[None, None, :] * (0.96 + 0.04 * sparkle[..., None])
rgb = clear * (1 - frost[..., None]) + white * frost[..., None]
# Bright seams between the big plates (thin), fainter ones between flakes.
line = np.clip(1 - seam / 0.004, 0, 1)
fine = np.clip(1 - small_seam / 0.003, 0, 1) * 0.45
edge = np.maximum(line, fine)[..., None]
rgb = rgb + (1.0 - rgb) * edge
rgb = np.clip(rgb, 0, 1)
raw = (rgb * 255 + 0.5).astype(np.uint8).tobytes()
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{SIZE}x{SIZE}", "-i", "-", sys.argv[1]],
               input=raw, check=True)
print("frost share", round(float(frost.mean()), 2), "mean", [round(float(v), 2) for v in rgb.reshape(-1, 3).mean(0)])
