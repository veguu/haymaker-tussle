"""Makes the poster window's background tiles from the mockup's own fonts and layout.

    python design/ui/make_word_tiles.py

Writes assets/ui/words/<word>.png (one tile per word that can stand behind the window: the eight classes and the
four other screens) and assets/ui/poster_dots.png, and prints each tile's size. Upload them and put the ids and
widths in src/client/Ui/Shapes.luau.
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parents[1] / "assets" / "ui"
WORDS = [
    "Base", "Bruiser", "Inferno", "Beast", "Trickster", "Dragon", "Frost", "Tempest",
    "Shop", "Ranked", "Moves", "More", "Settings", "Menu",
]  # fmt: skip


def capture(*args: str) -> str:
    done = subprocess.run(
        [sys.executable, str(HERE / "mock_capture.py"), *args], capture_output=True, timeout=180
    )
    return done.stdout.decode("utf-8", "replace")


def white(path: pathlib.Path) -> None:
    """White under every pixel, alpha only, so a tinted edge never goes dark."""
    alpha = Image.open(path).convert("RGBA").split()[-1]
    image = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    image.putalpha(alpha)
    image.save(path)


def main() -> None:
    page = str(HERE / "poster_words.html")
    (OUT / "words").mkdir(parents=True, exist_ok=True)
    widths = {}
    for line in capture("--dump", page, json.dumps({"measure": WORDS})).splitlines():
        if line.startswith("RECT "):
            name, width = line[5:].split(" | ")
            widths[name] = int(width)
    for word in WORDS:
        width = widths[word]
        out = OUT / "words" / f"{word.lower()}.png"
        capture("--clear", "--size", f"{width},168", "--page", page, str(out), json.dumps({"word": word, "width": width}))
        white(out)
        print(word, Image.open(out).size)
    dots = OUT / "poster_dots.png"
    capture("--clear", "--size", "128,128", "--page", page, str(dots), json.dumps({"dots": True}))
    white(dots)
    print("dots", Image.open(dots).size)


if __name__ == "__main__":
    main()
