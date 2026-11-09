"""Draws the lock-on reticle's PNG layers: the shapes of haymaker-lock-on-reference.html, thickened to read at
a distance, each with a matching dark outline layer behind it.

Every layer is white on transparent, on the same 1024 canvas, with the rotation pivot at dead centre. The game
tints the shape white or gold and the outline dark, so they have to be separate images: a tint would turn a
baked-in outline gold as well. Measurements are in the reference's pixels, for its 112 px marker. The canvas
covers CANVAS_UNITS of those pixels.

    python assets/lockon/build_lockon_art.py
"""

import math
import os

import numpy as np
from PIL import Image

CANVAS = 1024
CANVAS_UNITS = 144  # the widest thing, the pulse with its outline, is about 128 across
SUPERSAMPLE = 4
HERE = os.path.dirname(os.path.abspath(__file__))

ARC_SPAN = 90  # the reference's CSS border arcs are a quarter circle, cut radially

# Reference stroke in brackets. The positions, gaps and angles are all the reference's.
OUTER_RADIUS, OUTER_STROKE = 56.0, 7.0  # (4)
OUTER_ANGLES = (15, 135, 255)  # clockwise from straight up
TIP_CENTRE_Y, TIP_SIDE = 56.5, 9.0  # (7)
INNER_RADIUS, INNER_STROKE = 37.0, 4.0  # (2), brought in a touch so its outline clears the outer one
INNER_ANGLES = (55, 235)
DIAMOND_OUTER, DIAMOND_STROKE = 12.0, 3.0  # (10 and 2)
PULSE_RADIUS, PULSE_STROKE = 61.6, 4.0  # (2)
PULSE_ANGLES = (0, 180)
OUTLINE = 3.0  # how far the dark edge extends past the shape on every side
THIN_OUTLINE = 2.5  # for the smaller pieces, so it doesn't swallow them


def grid():
    size = CANVAS * SUPERSAMPLE
    per_unit = size / CANVAS_UNITS
    axis = (np.arange(size) + 0.5 - size / 2) / per_unit
    return np.meshgrid(axis, axis)  # y runs down the image


def arcs(x, y, radius, stroke, centres, grow=0.0):
    """Arcs, grown by `grow` on every side, including past their ends."""
    distance = np.hypot(x, y)
    bearing = np.degrees(np.arctan2(x, -y)) % 360  # clockwise degrees from straight up
    ring = (distance <= radius + grow) & (distance >= radius - stroke - grow)
    middle = radius - stroke / 2
    half_span = ARC_SPAN / 2 + math.degrees(grow / middle)
    within = np.zeros_like(ring)
    for centre in centres:
        offset = (bearing - centre + 180) % 360 - 180
        within |= np.abs(offset) <= half_span
    return ring & within


def diamond(x, y, side, centre_y=0.0, grow=0.0):
    """A square of this side turned 45 degrees, grown by `grow` on every side."""
    half_diagonal = side / math.sqrt(2) + grow * math.sqrt(2)
    return np.abs(x) + np.abs(y - centre_y) <= half_diagonal


def save(name, mask):
    alpha = Image.fromarray((mask * 255).astype(np.uint8), "L").resize((CANVAS, CANVAS), Image.LANCZOS)
    # White everywhere, even where it's see-through, so edges can't pick up a dark fringe when tinted.
    white = Image.new("L", (CANVAS, CANVAS), 255)
    image = Image.merge("RGBA", (white, white, white, alpha))
    path = os.path.join(HERE, name + ".png")
    image.save(path, optimize=True)
    print(f"{name}.png {os.path.getsize(path) // 1024} KB, drawn box {alpha.point(lambda v: 255 if v > 8 else 0).getbbox()}")


def outer(x, y, grow=0.0):
    return arcs(x, y, OUTER_RADIUS, OUTER_STROKE, OUTER_ANGLES, grow) | diamond(x, y, TIP_SIDE, -TIP_CENTRE_Y, grow)


def main():
    x, y = grid()
    save("lockon_outer", outer(x, y))
    save("lockon_outer_outline", outer(x, y, OUTLINE))
    save("lockon_inner", arcs(x, y, INNER_RADIUS, INNER_STROKE, INNER_ANGLES))
    save("lockon_inner_outline", arcs(x, y, INNER_RADIUS, INNER_STROKE, INNER_ANGLES, THIN_OUTLINE))
    hole = DIAMOND_OUTER - DIAMOND_STROKE * 2
    save("lockon_diamond", diamond(x, y, DIAMOND_OUTER) & ~diamond(x, y, hole))
    save("lockon_diamond_outline", diamond(x, y, DIAMOND_OUTER, grow=THIN_OUTLINE) & ~diamond(x, y, hole, grow=-THIN_OUTLINE))
    save("lockon_diamond_filled", diamond(x, y, DIAMOND_OUTER))
    save("lockon_diamond_filled_outline", diamond(x, y, DIAMOND_OUTER, grow=THIN_OUTLINE))
    save("lockon_pulse", arcs(x, y, PULSE_RADIUS, PULSE_STROKE, PULSE_ANGLES))
    save("lockon_pulse_outline", arcs(x, y, PULSE_RADIUS, PULSE_STROKE, PULSE_ANGLES, THIN_OUTLINE))


if __name__ == "__main__":
    main()
