"""Map 1's CLOUD SHADOWS as one tileable image (owner 2026-11-26: "dont overcrowd the arena with shadows, it shouldnt
be dark"): a few soft patches, about 12% of a tile under shade, the shade colour of the approved preview (60, 78, 120).
The image's alpha peaks at 1; the game's Texture.Transparency sets how dark (0.68 -> at most 32% of the shade over the
floor, the preview's 0.32, which measured 12 to 13% darker).

    python cloud_shadow_image.py <out folder>   -> cloud_shadow.png (512 px, tiled every TILE studs in the game)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

TILE = 360.0  # studs a tile: about the arena's width, so one or two patches pass at a time
N = 512
SHADE = (60, 78, 120)


def main(out):
    rng = np.random.default_rng(2612)
    s = TILE / N  # studs per pixel
    f = np.fft.fftfreq(N, d=s)  # cycles per stud
    fx, fy = np.meshgrid(f, f)
    r2 = fx * fx + fy * fy

    def smooth(sigma):
        """Tileable smooth noise (white noise low-passed in the frequency domain: periodic by construction)."""
        spec = np.fft.fft2(rng.standard_normal((N, N))) * np.exp(-2 * (math.pi * sigma) ** 2 * r2)
        out = np.real(np.fft.ifft2(spec))
        return (out - out.mean()) / out.std()

    field = smooth(30.0) + 0.35 * smooth(9.0)  # big soft shapes, a little ragged at their edges
    # soft edge: a smoothstep across the top ~12% of the field
    t = float(np.quantile(field, 0.885))
    e0, e1 = t - 0.25, t + 0.55
    k = np.clip((field - e0) / (e1 - e0), 0, 1)
    alpha = k * k * (3 - 2 * k)
    shaded = float((alpha > 0.12).mean())
    rgba = np.zeros((N, N, 4), np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = SHADE
    rgba[..., 3] = np.round(alpha * 255).astype(np.uint8)
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "cloud_shadow.png")
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)
    print("CLOUD SHADOW", path, os.path.getsize(path), "bytes; shaded", round(shaded * 100, 1), "% of a tile; mean alpha",
          round(float(alpha.mean()), 3))


if __name__ == "__main__":
    main(os.path.abspath(sys.argv[1]))
