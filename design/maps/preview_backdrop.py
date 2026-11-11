"""Quick look at one arena's backdrop without painting its surfaces: a plain oval stands in for the
arena, the map's own `build_backdrop` builds the scenery, and the look-around and sight cameras are
rendered small. Takes about a minute, against 10-20 for a full build.

    blender -b --factory-startup -P preview_backdrop.py -- <map> [Camera ...]

Writes out/<map>/preview/<camera>.png and saves out/<map>/preview/backdrop.blend.
"""
import importlib
import os
import random
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import common as C  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1 :]
name, wanted = args[0], args[1:]
mod = importlib.import_module(name)
C.reset()
C.sky_and_sun(*mod.SUN)
bm = bmesh.new()
C.oval_prism(bm, C.A - C.RIM, C.B - C.RIM, 0.0, -6.0)
C.mesh_object("Stand_In_Surface", bm, C.flat_material("StandIn", (0.55, 0.55, 0.5)), col="Setup")
bm = bmesh.new()
C.ring(bm, C.A, C.B, C.A - C.RIM, C.B - C.RIM, 0.0, -6.0)
C.mesh_object("Stand_In_Rim", bm, C.flat_material("StandInRim", (0.9, 0.5, 0.2)), col="Setup")
mod.build_backdrop(random.Random(mod.BACKDROP_SEED))
cams = mod.cameras()
report, bad = C.check_export()
print("MESHES", len(report), "TRIS", sum(t for _, t, _ in report), "OVER LIMIT:", bad)
out = os.path.join(HERE, "out", name, "preview")
os.makedirs(out, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "backdrop.blend"))
keep = {k: v for k, v in cams.items() if (k in wanted if wanted else k.startswith(("Look", "Sight_")))}
scene = bpy.context.scene
scene.eevee.taa_render_samples = 16
for p in C.render_all(out, "pv", keep, (960, 540)):
    print("RENDER", p)
