"""Quick look at gnomon_ground's meadow without Blender (system Python with numpy + Pillow):

    python ground_preview.py [out folder]

Writes ground_close.png (a 36 x 20 stud patch at 24 px a stud, with the Studio overlay laid on top, the way the
gameplay camera sees it up close), ground_tile.png (one 128-stud floor tile at the shipped 8 px a stud) and
ground_detail.png (the seamless overlay itself, tiled 2 x 2 to show it meets)."""
import os
import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gnomon_ground as GG  # noqa: E402
import paint as P  # noqa: E402

out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out", "gnomon", "ground_preview"))
os.makedirs(out, exist_ok=True)


def save(path, lin):
    Image.fromarray((np.clip(P.linear_to_srgb(np.clip(lin, 0, 1)), 0, 1) * 255).astype(np.uint8)).save(path)


t0 = time.time()
det = GG.detail_tile(512)
Image.fromarray((np.tile(det, (2, 2, 1)) * 255).astype(np.uint8), "RGBA").save(os.path.join(out, "ground_detail.png"))

# close patch, with the overlay composited in sRGB as Studio does
ppx = 24
xs = 60 + (np.arange(36 * ppx) + 0.5) / ppx
ys = 30 + (np.arange(20 * ppx) + 0.5) / ppx
X, Y = np.meshgrid(xs, ys)
col, _, _ = GG.meadow(X, Y)
srgb = P.linear_to_srgb(col)
k = det.shape[0] / GG.DETAIL_STUDS
iu = (np.floor(X * k).astype(int)) % det.shape[0]
iv = (np.floor(Y * k).astype(int)) % det.shape[0]
o = det[iv, iu]
srgb = srgb * (1 - o[..., 3:4]) + o[..., :3] * o[..., 3:4]
Image.fromarray((np.clip(srgb, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out, "ground_close.png"))

# one full tile at the shipped density
TPX = int(os.environ.get("TILE_PX", 512))
xs = -64 + (np.arange(TPX) + 0.5) / (TPX / 128)
X, Y = np.meshgrid(xs, xs)
col, _, _ = GG.meadow(X, Y)
save(os.path.join(out, "ground_tile.png"), col)
print(f"done in {time.time() - t0:.1f}s ->", out)
