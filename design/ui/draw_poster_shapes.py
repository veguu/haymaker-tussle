"""Draws the white shapes the fight-poster HUD tints (Roblox cannot skew or clip a frame to a polygon).

    python design/ui/draw_poster_shapes.py

Writes to assets/ui/:
  poster_wedge.png    128 x 256. A right triangle (the lower-right half of its box): the slanted end of a plate
                      leaning like "/". A slanted plate is this wedge, a plain body, and the wedge turned round
                      (Ui/Shapes.slant; poster_wedge_end.png is that turned copy). NOT a 9-slice: Roblox mis-slices an image it draws small, and the
                      lean goes (seen 2026-11-16).
  poster_seg_on.png   249 x 160. A lit stagger segment: 20 units tall, leaning 20 degrees.
  poster_seg_off.png  231 x 112. An unlit one: 14 units tall, leaning 20 degrees.
  poster_tile.png     256 x 256. The skill tile's rough-cut quad, polygon(6% 0, 100% 5%, 94% 100%, 0 94%).
                      Stretched to the tile; the same image inset by the outline width is the tile's fill.
  poster_stripes.png  256 x 256. Diagonal stripes inside the same quad: the "can't use" pattern.
  poster_badge.png    384 x 104. The ULT READY badge's quad, polygon(3% 0, 100% 8%, 97% 100%, 0 90%). Stretched.

All white on transparent, with white under the transparent pixels so tinted edges do not go dark.
After changing a shape: upload it and put the new id in src/client/Ui/Shapes.luau (the only place ids live).
"""

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "assets" / "ui"
SS = 4  # supersampling


def save(mask: Image.Image, name: str) -> None:
    w, h = mask.size[0] // SS, mask.size[1] // SS
    alpha = mask.resize((w, h), Image.LANCZOS)
    image = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    image.putalpha(alpha)
    image.save(OUT / name)
    print(name, image.size)


def quad(w: int, h: int) -> list[tuple[float, float]]:
    return [(0.06 * w, 0), (w, 0.05 * h), (0.94 * w, h), (0, 0.94 * h)]


def wedge() -> None:
    w, h = 128 * SS, 256 * SS
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon([(w, 0), (w, h), (0, h)], fill=255)
    save(mask, "poster_wedge.png")
    # the same wedge turned half round, for a plate's right end (turning it in Roblox leaves a hairline seam)
    save(mask.rotate(180), "poster_wedge_end.png")


def segment(name: str, height: float) -> None:
    """A stagger segment as the mockup draws it: 23.83 wide, `height` tall, skewed 20 degrees."""
    import math

    unit = 8 * SS
    lean = height * math.tan(math.radians(20))
    w, h = round((23.83 + lean) * unit), round(height * unit)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon([(lean * unit, 0), (w, 0), (w - lean * unit, h), (0, h)], fill=255)
    save(mask, name)


def tile() -> None:
    s = 256 * SS
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).polygon(quad(s, s), fill=255)
    save(mask, "poster_tile.png")


def badge() -> None:
    w, h = 384 * SS, 104 * SS
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon([(0.03 * w, 0), (w, 0.08 * h), (0.97 * w, h), (0, 0.9 * h)], fill=255)
    save(mask, "poster_badge.png")


def stripes() -> None:
    s = 256 * SS
    period, band = 40 * SS, 15 * SS
    lines = Image.new("L", (s, s), 0)
    draw = ImageDraw.Draw(lines)
    for k in range(-s, 2 * s, period):
        # a band running from bottom-left to top-right
        draw.polygon([(k, s), (k + band, s), (k + band + s, 0), (k + s, 0)], fill=255)
    shape = Image.new("L", (s, s), 0)
    ImageDraw.Draw(shape).polygon(quad(s, s), fill=255)
    mask = Image.composite(lines, Image.new("L", (s, s), 0), shape)
    save(mask, "poster_stripes.png")


# The lobby's rough-cut shapes: each is the mockup's own clip-path polygon (in per cent of the box), drawn at four
# times the size the mockup uses it. Stretched in Roblox; the same image inset by 4 units is the fill.
MENU_SHAPES = {
    # the left menu's buttons: 250 x 74 (Classes, Ranked and More share the first; Shop and Moves have their own)
    "poster_nav_a.png": (250, 74, [(2, 10), (97, 0), (100, 86), (4, 100), (0, 55)]),
    "poster_nav_b.png": (250, 74, [(0, 4), (98, 8), (96, 100), (3, 92)]),
    "poster_nav_d.png": (250, 74, [(3, 0), (100, 6), (97, 96), (0, 100)]),
    # the fight's MENU button and the window's close button
    "poster_gear.png": (58, 58, [(8, 0), (100, 6), (92, 100), (0, 92)]),
    "poster_close.png": (54, 54, [(6, 0), (100, 8), (94, 100), (0, 90)]),
    # a class tile, an action button, a shop slab
    "poster_class.png": (132, 112, [(5, 0), (100, 5), (95, 100), (0, 95)]),
    "poster_act.png": (250, 66, [(0, 8), (100, 0), (96, 100), (3, 92)]),
    "poster_slab.png": (250, 150, [(3, 0), (100, 4), (97, 100), (0, 96)]),
}


def menu_shapes() -> None:
    for name, (width, height, points) in MENU_SHAPES.items():
        w, h = width * 4 * SS, height * 4 * SS
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).polygon([(x / 100 * w, y / 100 * h) for x, y in points], fill=255)
        save(mask, name)


def class_stripes() -> None:
    """A class you don't own: the mockup's 135-degree stripes (12 units clear, 6 dark) inside the class tile."""
    width, height, points = MENU_SHAPES["poster_class.png"]
    w, h = width * 4 * SS, height * 4 * SS
    unit = 4 * SS
    lines = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(lines)
    period, band = 18 * unit * 1.4142, 6 * unit * 1.4142  # measured along x for a 45-degree stripe
    k = -h
    while k < w + h:
        draw.polygon([(k, h), (k + band, h), (k + band + h, 0), (k + h, 0)], fill=255)
        k += period
    shape = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shape).polygon([(x / 100 * w, y / 100 * h) for x, y in points], fill=255)
    save(Image.composite(lines, Image.new("L", (w, h), 0), shape), "poster_class_stripes.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    wedge()
    segment("poster_seg_on.png", 20)
    segment("poster_seg_off.png", 14)
    tile()
    stripes()
    badge()
    menu_shapes()
    class_stripes()
