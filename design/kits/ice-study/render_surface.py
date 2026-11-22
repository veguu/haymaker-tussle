"""Flat facets or frost: Look 3 with vertex colours only, and with the frost texture multiplied in.
  blender -b --factory-startup --python-exit-code 1 --python render_surface.py -- <out dir> <frost.png>
Renders surface_<flat|frost>_<lobby|meadow>_<game|close>.png.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import FLOWER, FLOWER_CENTRE, PALE_GLASS  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
OUT, FROST = args[0], args[1]
for surface in ("flat", "frost"):
    for kind in ("lobby", "meadow"):
        S._materials.clear()
        S.new_scene()
        S.ICE = PALE_GLASS
        S.TEXTURE = FROST if surface == "frost" else None
        kit = P.build_kit()
        S.floor(kind)
        S.fighter()
        S.glacier(kit, 0.6, table=FLOWER, centre=FLOWER_CENTRE, transparency=0.25)
        S.game_camera()
        S.render(os.path.join(OUT, f"surface_{surface}_{kind}_game.png"))
        if kind == "lobby":
            S.camera((11.0, 5.0, 5.5), (0.5, -8.5, 6.0), 34.0, "Close")
            S.render(os.path.join(OUT, f"surface_{surface}_{kind}_close.png"))
print("RESULT_JSON={}")
