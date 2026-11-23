"""Map 1's floor options (owner 2026-11-22: "Yes, start the fix round"; the suite's floor is option D, big flagstones,
2026-11-21, "every map ... its own pattern"). A grass map needs D's method in its own pattern, so four options:

    python meadow_floor_options.py <out folder>          (the patterns, numpy only)
    blender -b --factory-startup -P meadow_floor_options.py -- <out folder> --render   (renders + the sheet)

  A  Mossy flagstones: D's flags in a grey-green stone, wide grass joints; no blades.
  B  Mossy flagstones with blade drifts: as A, chunky blades in soft drifts (about a third of the floor), thicker
     toward the rim.
  C  Turf: a sod pattern at foot scale (tufts, clover, small worn earth), chunky blades everywhere but sparser.
  D  Turf with blade drifts: C's pattern, the blades only in drifts.

Blades here are the RESTYLED ones (fresh review 2026-11-22: too yellow, too fine for the storybook islands): wider,
greener (the islands' leaf_land), a narrow colour range. The method is the suite's: a seamless 1024 px detail image as
a Roblox Texture over a calm colour map (floor_options.py), so the patterns use its tiling helpers.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import floor_options as FO  # noqa: E402

srgb, fbm, hash01, smooth, grid, lit_bevel, N = FO.srgb, FO.fbm, FO.hash01, FO.smooth, FO.grid, FO.lit_bevel, FO.N
A_SEMI, B_SEMI = FO.A_SEMI, FO.B_SEMI

GRASS_JOINT = srgb(98, 150, 80)  # the joints' grass, a calm mid green (fighters stay the most saturated)
LEAF_LAND = (srgb(104, 164, 82), srgb(146, 198, 104))  # the islands' grass, base and lit (meadow.py PAL leaf_land)


def mossy_flags(tile=40.0):
    """D's flags (the same Voronoi on a jittered 5 x 5 grid, so they line up with the suite's pattern) in a pale
    grey-green stone, each flag its own shade, a painted bevel; WIDE joints filled with grass, moss creeping in."""
    X, Y = grid()
    xs, ys = X * tile, Y * tile
    G = 5
    cell = tile / G
    gx, gy = np.floor(xs / cell).astype(int), np.floor(ys / cell).astype(int)
    f1, f2 = np.full(xs.shape, 1e9), np.full(xs.shape, 1e9)
    sid = np.zeros(xs.shape, dtype=np.int64)
    vx, vy = np.zeros(xs.shape), np.zeros(xs.shape)
    for di in (-2, -1, 0, 1, 2):
        for dj in (-2, -1, 0, 1, 2):
            ci, cj = (gx + di) % G, (gy + dj) % G
            px_ = (gx + di + 0.04 + 0.92 * hash01(ci, cj, 2)) * cell
            py_ = (gy + dj + 0.04 + 0.92 * hash01(ci, cj, 3)) * cell
            dx, dy = xs - px_, ys - py_
            d = np.hypot(dx, dy)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            sid = np.where(closer, ci * 100 + cj, sid)
            vx, vy = np.where(closer, dx, vx), np.where(closer, dy, vy)
            f1 = np.where(closer, d, f1)
    edge = (f2 - f1) * 0.5
    pal = [srgb(176, 180, 160), srgb(162, 168, 150), srgb(184, 184, 162), srgb(156, 162, 146), srgb(170, 176, 154)]
    pick = np.floor(hash01(sid, 1) * len(pal)).astype(int) % len(pal)
    col = np.stack(pal)[pick] * (0.92 + 0.12 * hash01(sid, 9))[..., None]
    col *= (0.94 + 0.12 * fbm(32, 71))[..., None]
    lit = np.clip(-(vx + vy) / (cell * 0.6), -1, 1)
    col *= lit_bevel(edge, 0.5, light=0.14, dark=0.2, side=lit)[..., None]
    moss = smooth(0.55, 0.8, fbm(12, 72)) * (1.0 - smooth(0.6, 1.6, edge))  # moss creeping in from the joints
    col = col * (1 - 0.5 * moss[..., None]) + GRASS_JOINT * 0.5 * moss[..., None]
    joint = 0.8 * (0.55 + 0.9 * fbm(8, 73))  # wide and uneven: grass, not sand
    g = 1.0 - smooth(joint * 0.5, joint, edge)
    grass = GRASS_JOINT * (0.8 + 0.3 * fbm(64, 74))[..., None]
    col = col * (1 - g[..., None]) + grass * g[..., None]
    return col, np.full(xs.shape, 0.92), tile


def turf(tile=24.0):
    """Sod at foot scale: tufts (small lit/shaded lumps), a little clover, small worn earth patches; calm greens."""
    X, Y = grid()
    base = srgb(96, 148, 78)
    tuft = fbm(96, 81, 3)  # about 4 px tufts at 1024 / 24 studs
    col = base * (0.86 + 0.3 * tuft)[..., None]
    lit = fbm(48, 82, 2)
    col *= (0.92 + 0.14 * smooth(0.45, 0.7, lit))[..., None]
    clover = smooth(0.66, 0.74, fbm(40, 83, 2)) * smooth(0.5, 0.7, fbm(6, 84))
    col = col * (1 - clover[..., None] * 0.6) + srgb(118, 168, 92) * clover[..., None] * 0.6
    # no worn earth: at a 24-stud repeat its patches lined up in rows (first try, 2026-11-22)
    return col, np.full(X.shape, 0.9), tile


def base_green(n=2048):
    """The calm large-scale colour under the detail: one green, large soft variation only, a little lighter at the rim
    (the lip's roll)."""
    u = (np.arange(n) + 0.5) / n
    X = (u[None, :] * 2 - 1) * A_SEMI
    Z = (u[:, None] * 2 - 1) * B_SEMI
    big = fbm(4, 91, 3, n)
    col = srgb(100, 150, 82) * (0.93 + 0.14 * big)[..., None]
    rho = np.sqrt((X / A_SEMI) ** 2 + (Z / B_SEMI) ** 2)
    return col * (1 + 0.08 * smooth(0.97, 1.0, rho))[..., None]


OPTIONS = {
    "a": ("Mossy flagstones", "mossy", "none"),
    "b": ("Mossy flagstones + grass drifts", "mossy", "drifts"),
    "c": ("Turf + grass everywhere", "turf", "all"),
    "d": ("Turf + grass drifts", "turf", "drifts"),
}


def write_patterns(out):
    os.makedirs(out, exist_ok=True)
    for key, fn in (("mossy", mossy_flags), ("turf", turf)):
        col, alpha, tile = fn()
        FO.save(os.path.join(out, f"detail_{key}.png"), col, alpha)
        print(key, "tile", tile, "seam", FO.seam_error(col), flush=True)
    FO.save(os.path.join(out, "base_green.png"), base_green())


if __name__ == "__main__" and "--render" not in sys.argv:
    write_patterns(os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "out", "suite", "meadow_floor")))
