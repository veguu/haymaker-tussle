"""The STUD LAYER for Haymaker's floors (owner 2026-11-22: a studded flat-colour floor on the arenas and the lobby, at
Raise a Fairy's scale, one raised square per stud, from his own texture).

    python stud_overlay.py            -> patterns/stud_overlay.png (256 px, 4 x 4 studs, RGBA)

His texture (`Raise a Fairy/Attachments/Style/stud-texture.png`, 512 px, 8 x 8 squares on mid grey 129) is opaque, so
it cannot lie over a coloured floor as it is. This turns it into an OVERLAY that works over any colour or pattern: clear
where the texture is flat, white where a bevel is lit, black where it is shaded, the alpha set so the floor's colour
comes out as the approved mock's (design/style/floor_mock.py stud_mat): colour x (0.45 + 0.55 x texture / 128).
In the game it is a Texture on the floor's Top face, StudsPerTileU/V = 4 (studio_map.py "floor_studs").
The 64 squares of his image differ by 0.2 grey levels (measured), so they are averaged into one and tiled 4 x 4.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", "..", "Raise a Fairy", "Attachments", "Style", "stud-texture.png"))
OUT = os.path.join(HERE, "patterns", "stud_overlay.png")
STUDS = 4  # squares across the overlay
DEAD = 0.012  # under this much change the overlay stays clear (the flat ground between the squares)
RING, RING_PX = 0.13, 3  # the contact shadow at the square's foot: its strength, and how far it fades (of 64 px a stud)


def main():
    g = np.asarray(Image.open(SRC).convert("L")).astype(np.float64)
    assert g.shape == (512, 512), g.shape
    one = g.reshape(8, 64, 8, 64).transpose(0, 2, 1, 3).reshape(64, 64, 64).mean(axis=0)  # one square, 64 px
    f = 0.45 + 0.55 * one / 128.0  # the mock's factor on the floor's colour
    d = f - 1.0
    d[np.abs(d) < DEAD] = 0.0
    # a faint contact shadow round the square's foot (RING, fading over RING_PX): on a pale floor (the lobby's cream
    # paving) white cannot get whiter, so the lit sides vanished and only the two shaded sides showed, reading as
    # tick marks, not squares (seen in Studio 2026-11-22). The texture's own shading is untouched inside the square.
    rows, cols = np.nonzero(np.abs(d) > 0.03)
    r0, r1, c0, c1 = rows.min(), rows.max(), cols.min(), cols.max()
    yy, xx = np.mgrid[0:64, 0:64]
    out = np.maximum(np.maximum(r0 - yy, yy - r1), np.maximum(c0 - xx, xx - c1))  # px outside the square (Chebyshev)
    ring = np.where((out > 0) & (out <= RING_PX), RING * (1.0 - (out - 1) / RING_PX), 0.0)
    d = np.where(ring > 0, np.minimum(d, -ring), d)
    rgba = np.zeros((64, 64, 4), dtype=np.uint8)
    rgba[..., :3] = np.where(d[..., None] > 0, 255, 0)
    rgba[..., 3] = np.clip(np.round(np.abs(d) * 255.0), 0, 255)
    Image.fromarray(np.tile(rgba, (STUDS, STUDS, 1)), "RGBA").save(OUT, optimize=True)
    print(OUT, os.path.getsize(OUT), "bytes;", "lit alpha max", int(rgba[..., 3][d > 0].max()), "shade alpha max", int(rgba[..., 3][d < 0].max()),
          "clear share", round(float((rgba[..., 3] == 0).mean()), 3))


if __name__ == "__main__":
    main()
