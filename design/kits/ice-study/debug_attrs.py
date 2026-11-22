import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_scene as S  # noqa: E402

GLB = sys.argv[sys.argv.index("--") + 1]
S.new_scene()
kit = S.load_kit(GLB)
out = {}
for name, mesh in kit.items():
    row = {"attributes": [(a.name, a.domain, a.data_type) for a in mesh.attributes],
           "color_attributes": [(a.name, a.domain, a.data_type) for a in mesh.color_attributes],
           "active_color": mesh.color_attributes.active_color_name, "render_color": mesh.color_attributes.render_color_index}
    if mesh.color_attributes:
        attr = mesh.color_attributes[0]
        values = [tuple(round(c, 3) for c in d.color) for d in attr.data]
        row["first"] = values[:3]
        row["min_r"] = min(v[0] for v in values)
        row["max_r"] = max(v[0] for v in values)
    out[name] = row
print("RESULT_JSON=" + json.dumps(out))
