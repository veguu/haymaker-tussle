"""Draws the hexagon barrier's three images (white on clear; the game tints them).

  hex_tile.png  one seamless period of a pointy-top hexagon grid: crisp edges with a faint halo.
                A period is sqrt(3) x 3 hexagon radii, so the image is 296 x 512 and the game
                stretches it to the exact tile size (Barrier.HexSize).
  hex_cell.png  one hexagon, sqrt(3) x 2 radii: bright rim, soft fill. The proximity glow is made
                of these, one per hexagon near a player.
  halo.png      a soft round blob, for the glow behind them.

Run: python design/barrier/draw_barrier.py   (writes into design/barrier/out)
"""

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
SS = 4  # supersampling
LINE = 0.07  # edge thickness, in hexagon radii
ROOT3 = math.sqrt(3)


def hexagon(cx, cy, r):
    return [
        (cx + r * math.cos(math.radians(60 * k - 90)), cy + r * math.sin(math.radians(60 * k - 90)))
        for k in range(6)
    ]


def outline(draw, points, width):
    closed = points + [points[0], points[1]]
    draw.line(closed, fill=255, width=width, joint="curve")


def tile():
    w, h = 296, 512
    unit = h * SS / 3  # pixels per hexagon radius
    big = Image.new("L", (w * SS, h * SS), 0)
    draw = ImageDraw.Draw(big)
    for j in range(-2, 5):
        for i in range(-2, 4):
            cx = ROOT3 * unit * (i + 0.5 * (j % 2))
            cy = 1.5 * unit * j
            outline(draw, hexagon(cx, cy, unit), max(1, round(LINE * unit)))
    crisp = big.resize((w, h), Image.LANCZOS)
    # The halo must wrap too, so blur a 3 x 3 tiling and keep the middle.
    wide = Image.new("L", (w * 3, h * 3))
    for a in range(3):
        for b in range(3):
            wide.paste(crisp, (a * w, b * h))
    halo = wide.filter(ImageFilter.GaussianBlur(4)).crop((w, h, 2 * w, 2 * h))
    alpha = ImageChops.lighter(crisp, halo.point(lambda v: int(v * 0.4)))
    image = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    image.putalpha(alpha)
    image.save(os.path.join(OUT, "hex_tile.png"))


def cell():
    # One lit hexagon, as in the reference GIF: a bright rim with a soft glow either side of it, and a
    # faint fill. Dim, it reads as lines only; at full brightness the fill shows too.
    w, h = 222, 256
    unit = h * SS / 2
    cx, cy = w * SS / 2, h * SS / 2
    big = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(big).polygon(hexagon(cx, cy, unit), fill=255)
    solid = big.resize((w, h), Image.LANCZOS)
    rim_big = Image.new("L", (w * SS, h * SS), 0)
    outline(ImageDraw.Draw(rim_big), hexagon(cx, cy, unit), max(1, round(LINE * 1.5 * unit)))
    rim = rim_big.resize((w, h), Image.LANCZOS)
    glow = rim.filter(ImageFilter.GaussianBlur(9)).point(lambda v: min(255, int(v * 1.5)))
    fill = solid.point(lambda v: int(v * 0.2))
    alpha = ImageChops.lighter(ImageChops.lighter(fill, glow), rim)
    alpha = ImageChops.multiply(alpha, solid)
    image = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    image.putalpha(alpha)
    image.save(os.path.join(OUT, "hex_cell.png"))


def halo():
    size = 128
    image = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    alpha = Image.new("L", (size, size), 0)
    px = alpha.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - (size - 1) / 2, y - (size - 1) / 2) / (size / 2)
            t = max(0.0, 1 - d)
            px[x, y] = int(255 * t * t * (3 - 2 * t))
    image.putalpha(alpha)
    image.save(os.path.join(OUT, "halo.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    tile()
    cell()
    halo()
    print("wrote", OUT)
