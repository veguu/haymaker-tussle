"""Draws the kill leader's crown for the fighters' row (Ui/Roster) as pixel art.

The owner sent a reference (2026-11-18): a three-point pixel crown, dark outline, yellow with an orange shaded side,
a pale highlight stripe and a darker band. This is our OWN drawing in that manner, in the game's colours (the ink,
the coin yellow, Bruiser's orange); the reference picture itself is not used.

    python design/ui/make_crown.py     -> assets/icons/poster/crown_pixel.png (21 x 15 cells, 16 px a cell)

The shape is worked out, not typed in: three peaks and two valleys give the top edge, columns give the shading,
and every clear cell touching a filled one becomes outline. Nothing here uploads anything.
"""

import os

from PIL import Image

CELL = 16
WIDE, TALL = 21, 15
INK = (26, 18, 54, 255)  # ink.900
YELLOW = (255, 212, 38, 255)  # coral.500 / gold.400, the coin yellow
ORANGE = (255, 159, 46, 255)  # class.Bruiser
LIGHT = (255, 246, 176, 255)
BAND = (217, 112, 26, 255)
CLEAR = (0, 0, 0, 0)

PEAKS = [(2, 1), (10, 1), (18, 1)]  # column, row of each point's tip
VALLEYS = [(6, 7), (14, 7)]
FOOT = 13  # the last filled row
BAND_ROW = 10  # the darker band; the rows under it are the base, one cell wider each side


def top(col):
    """The first filled row in a column: straight lines from each tip down to the valley beside it."""
    marks = sorted(PEAKS + VALLEYS)
    for (c0, r0), (c1, r1) in zip(marks, marks[1:]):
        if c0 <= col <= c1:
            return round(r0 + (r1 - r0) * (col - c0) / (c1 - c0))
    return None


def shade(col):
    if col == 3 or 9 <= col <= 11 or col >= 14:
        return YELLOW
    if 12 <= col <= 13:
        return LIGHT
    return ORANGE


def main():
    cells = [[CLEAR] * WIDE for _ in range(TALL)]
    for col in range(1, WIDE - 1):
        body = PEAKS[0][0] <= col <= PEAKS[-1][0]
        first = top(col) if body else BAND_ROW + 1
        for row in range(first, FOOT + 1):
            cells[row][col] = BAND if row == BAND_ROW else shade(col)
    filled = [[cells[r][c] != CLEAR for c in range(WIDE)] for r in range(TALL)]
    for row in range(TALL):
        for col in range(WIDE):
            if filled[row][col]:
                continue
            near = [(row + dr, col + dc) for dr in (-1, 0, 1) for dc in (-1, 0, 1) if dr or dc]
            if any(0 <= r < TALL and 0 <= c < WIDE and filled[r][c] for r, c in near):
                cells[row][col] = INK
    image = Image.new("RGBA", (WIDE * CELL, TALL * CELL), CLEAR)
    for row in range(TALL):
        for col in range(WIDE):
            if cells[row][col] != CLEAR:
                image.paste(cells[row][col], (col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
    out = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "icons", "poster", "crown_pixel.png")
    image.save(out, optimize=True)
    print(os.path.normpath(out), image.size, os.path.getsize(out), "bytes")
    for row in cells:
        print("".join("." if c == CLEAR else "K" if c == INK else "L" if c == LIGHT else "B" if c == BAND else "O" if c == ORANGE else "Y" for c in row))


if __name__ == "__main__":
    main()
