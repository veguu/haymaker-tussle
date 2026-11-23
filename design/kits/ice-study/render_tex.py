"""The solid, paler ice (ice-8) with and without a frost texture, close up and from the game camera.
  blender -b --factory-startup --python-exit-code 1 --python render_tex.py -- <out dir> <texture.png> <tag>
Writes tex_<tag>_close.png and tex_<tag>_game.png (tag "flat" with texture "none" = no texture).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import FLOWER, FLOWER_CENTRE  # noqa: E402

OUT, TEX, TAG = sys.argv[sys.argv.index("--") + 1:][:3]
PALER = [(182, 224, 244), (205, 236, 250), (225, 244, 253), (245, 252, 255)]
S.new_scene()
S.ICE = PALER
S.TEXTURE = None if TEX == "none" else TEX
kit = P.build_kit()
S.floor("lobby")
S.fighter()
S.glacier(kit, 0.6, table=FLOWER, centre=FLOWER_CENTRE, transparency=0.0)
S.game_camera()
S.render(os.path.join(OUT, f"tex_{TAG}_game.png"))
S.camera((11.0, 5.0, 5.5), (0.5, -8.5, 6.0), 34.0, "Close")
S.render(os.path.join(OUT, f"tex_{TAG}_close.png"))
print("RESULT_JSON={}")
