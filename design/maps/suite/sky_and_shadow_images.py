"""Map 1's SKY and CLOUD SHADOWS as images (owner 2026-11-26, after seeing Map 1 in Studio):
  "i dont like how the sky is splitn betwee two colors" -> the place's photo skybox has an ocean under the horizon; a
     plain gradient skybox instead: deep blue overhead, pale at the horizon, the SAME pale haze below it, so the
     horizon never splits (the Atmosphere's haze colour matches the lower half);
  "the cloud shadows don't look like shadows at all ... make it look better, make it subtle too" -> big soft cloud
     shapes (no ragged scraps), a neutral dark shade (not the blue-grey of the first try), the Texture's Transparency
     keeping it subtle.

    python sky_and_shadow_images.py <out folder> [--test]
        -> sky_side.png (256 x 512: top edge = the up face's blue, the middle = the horizon, the lower half = haze),
           sky_up.png, sky_down.png (16 px, flat), cloud_shadow_soft.png (256 px, tileable)
        --test also writes cloud_shadow_soft_64.hex (64 px RGBA as hex) to try it in Studio with no upload
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ZENITH = (58, 138, 232)  # overhead
HORIZON = (190, 222, 250)  # at the horizon line
HAZE = (196, 225, 251)  # below it: the Atmosphere's colour, so the horizon never splits
SHADE = (34, 44, 58)  # a neutral dark: darkens the floor without tinting it blue


def gradient_side(w=256, h=512):
    rows = np.zeros((h, 3))
    for y in range(h):
        v = y / (h - 1)  # 0 = the top edge (45 degrees up at the face's middle), 0.5 = the horizon
        if v < 0.5:
            k = (v / 0.5) ** 1.6  # stays blue high up, brightens toward the horizon
            rows[y] = np.array(ZENITH) * (1 - k) + np.array(HORIZON) * k
        else:
            k = min(1.0, (v - 0.5) / 0.06)  # a soft few rows from the horizon colour into the haze
            rows[y] = np.array(HORIZON) * (1 - k) + np.array(HAZE) * k
    img = np.repeat(rows[:, None, :], w, axis=1)
    return Image.fromarray(np.round(img).astype(np.uint8), "RGB")


def soft_shadow(n, tile=600.0, seed=2613):
    """Three puffy clouds per tile, each a cluster of soft round lobes (a cumulus seen from below), wrapping at the
    tile's edges; a wide soft edge, so the shade fades in and out like a real cloud's."""
    rng = np.random.default_rng(seed)
    s = tile / n
    y, x = np.mgrid[0:n, 0:n].astype(np.float64) * s
    field = np.zeros((n, n))
    for cx, cy, lobes, size in ((120.0, 140.0, 8, 1.0), (420.0, 330.0, 7, 0.9), (230.0, 500.0, 5, 0.7)):
        for _ in range(lobes):
            bx, by = cx + rng.uniform(-95, 95) * size, cy + rng.uniform(-45, 45) * size
            sig = rng.uniform(24.0, 40.0) * size
            dx = np.abs(x - bx)
            dy = np.abs(y - by)
            dx = np.minimum(dx, tile - dx)
            dy = np.minimum(dy, tile - dy)
            field += np.exp(-(dx * dx + dy * dy) / (2 * sig * sig))
    field /= field.max()
    k = np.clip((field - 0.1) / 0.55, 0, 1)  # a WIDE soft edge: the shade fades in over most of the cloud
    alpha = k * k * (3 - 2 * k)
    rgba = np.zeros((n, n, 4), np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = SHADE
    rgba[..., 3] = np.round(alpha * 255).astype(np.uint8)
    return rgba, float((alpha > 0.15).mean())


def main(out, test):
    os.makedirs(out, exist_ok=True)
    gradient_side().save(os.path.join(out, "sky_side.png"), optimize=True)
    Image.new("RGB", (16, 16), ZENITH).save(os.path.join(out, "sky_up.png"))
    Image.new("RGB", (16, 16), HAZE).save(os.path.join(out, "sky_down.png"))
    rgba, shaded = soft_shadow(256)
    Image.fromarray(rgba, "RGBA").save(os.path.join(out, "cloud_shadow_soft.png"), optimize=True)
    print("SKY + SHADOW", out, "; shaded", round(shaded * 100, 1), "% of a tile;",
          {f: os.path.getsize(os.path.join(out, f)) for f in ("sky_side.png", "sky_up.png", "sky_down.png", "cloud_shadow_soft.png")})
    if test:
        small, _ = soft_shadow(64)
        open(os.path.join(out, "cloud_shadow_soft_64.hex"), "w").write(small.tobytes().hex())


if __name__ == "__main__":
    main(os.path.abspath(sys.argv[1]), "--test" in sys.argv)
