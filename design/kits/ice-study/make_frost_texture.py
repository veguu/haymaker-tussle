"""A frost texture for the ice (512 x 512, tileable): pale mottling, white crack lines and a few darker veins,
after reference C's surface. It is a multiplier (white = unchanged), so it only ever darkens the part's colour.
  python.exe make_frost_texture.py <out.png>
numpy only; the PNG is written through ffmpeg.
"""
import subprocess
import sys

import numpy as np

SIZE = 512
rng = np.random.default_rng(20261122)


def periodic_noise(period):
    """Value noise that tiles: a period x period grid of random values, smoothly interpolated."""
    grid = rng.random((period, period))
    coords = np.arange(SIZE) * period / SIZE
    i0 = np.floor(coords).astype(int)
    f = coords - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % period
    rows = grid[i0][:, i0] * (1 - f)[None, :] + grid[i0][:, i1] * f[None, :]
    rows2 = grid[i1][:, i0] * (1 - f)[None, :] + grid[i1][:, i1] * f[None, :]
    return rows * (1 - f)[:, None] + rows2 * f[:, None]


def distance_to_lines(lines):
    """Distance in pixels from every pixel to the nearest of `lines` ((x0, y0, x1, y1)), wrapping at the edges."""
    ys, xs = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    best = np.full((SIZE, SIZE), 1e9, np.float32)
    for x0, y0, x1, y1 in lines:
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                ax, ay, bx, by = x0 + ox, y0 + oy, x1 + ox, y1 + oy
                if max(ax, bx) < -8 or min(ax, bx) > SIZE + 8 or max(ay, by) < -8 or min(ay, by) > SIZE + 8:
                    continue
                dx, dy = bx - ax, by - ay
                length = dx * dx + dy * dy + 1e-6
                t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / length, 0, 1)
                d = np.hypot(xs - (ax + t * dx), ys - (ay + t * dy))
                best = np.minimum(best, d)
    return best


def cracks(count, steps, step, wander):
    """Jagged lines: each starts somewhere, heads one way and kinks a little at every step."""
    lines = []
    for _ in range(count):
        x, y = rng.random(2) * SIZE
        heading = rng.random() * np.pi * 2
        for _ in range(steps):
            heading += rng.normal(0, wander)
            nx, ny = x + np.cos(heading) * step, y + np.sin(heading) * step
            lines.append((x, y, nx, ny))
            if rng.random() < 0.18:     # a short branch
                side = heading + rng.choice((-1, 1)) * rng.uniform(0.6, 1.1)
                lines.append((nx, ny, nx + np.cos(side) * step * 0.9, ny + np.sin(side) * step * 0.9))
            x, y = nx, ny
    return lines


mottle = 0.5 * periodic_noise(4) + 0.3 * periodic_noise(8) + 0.15 * periodic_noise(16) + 0.05 * periodic_noise(64)
mottle = (mottle - mottle.min()) / (mottle.max() - mottle.min())
value = 0.80 + 0.16 * mottle
speckle = periodic_noise(128)
value += 0.05 * np.clip((speckle - 0.72) / 0.28, 0, 1)

veins = distance_to_lines(cracks(5, 10, 34, 0.35))
value -= 0.14 * np.clip(1 - veins / 7.0, 0, 1) ** 1.5           # soft darker fractures inside the ice

white = distance_to_lines(cracks(9, 12, 26, 0.45))
line = np.clip(1 - (white - 0.6) / 1.4, 0, 1)                    # a crisp line about 2 px wide
halo = np.clip(1 - white / 6.0, 0, 1) ** 2 * 0.5
value = value + (1.0 - value) * np.maximum(line, halo)

value = np.clip(value, 0, 1)
shade = 1 - value
rgb = np.stack([value * (1 - 0.30 * shade), value * (1 - 0.08 * shade), np.minimum(1, value * (1 + 0.05 * shade))], -1)
raw = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8).tobytes()
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{SIZE}x{SIZE}", "-i", "-", sys.argv[1]],
               input=raw, check=True)
print("mean", [round(float(v), 3) for v in rgb.reshape(-1, 3).mean(0)], "min", round(float(value.min()), 3))
