"""Quick look at one arena's fighting surface alone: paints its tiles (a tile whose maps are already in
out/<map>/textures is reused with --reuse-textures) and renders the Gameplay and Floor cameras under
the map's own sun. A couple of minutes, against a full build.

    blender -b --factory-startup -P preview_surface.py -- <map> [--reuse-textures]

Writes out/<map>/preview/surface_gameplay.png and surface_floor.png.
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import common as C  # noqa: E402
import surfaces as S  # noqa: E402

SURFACES = {
    "gnomon": ("Meadow", -2.0, "meadow_painter"),
    "kitestead": ("Deck", -4.0, "deck_painter"),
    "saltcrest": ("Plaza_Tiles", -3.0, "plaza_painter"),
}
name = sys.argv[sys.argv.index("--") + 1]
mod = importlib.import_module(name)
prefix, depth, painter = SURFACES[name]
C.reset()
C.sky_and_sun(*mod.SUN)
S.surface_tiles(prefix, depth, getattr(mod, painter), os.path.join(HERE, "out", name, "textures"))
cams = {k: v for k, v in mod.cameras().items() if k in ("Gameplay", "Floor")}
for p in C.render_all(os.path.join(HERE, "out", name, "preview"), "surface", cams, (1280, 720)):
    print("RENDER", p)
