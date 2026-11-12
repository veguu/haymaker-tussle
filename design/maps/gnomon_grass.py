"""Gnomon's 3D grass (user brief 2026-11-11 b): VERY LOW compact tufts, fewer of them, over a painted ground.

Replaces gnomon_dress.scatter_grass (10,105 kit-plant tufts merged into 47 chunks, about 568k triangles, swayed per
vertex through EditableMesh copies). Now:

- TEMPLATES: five tiny tufts adapted from the kit's six plants (fine blades, a low fan, small broad leaves, round
  leaves, a sprig), 0.45-0.8 studs tall, blades leaning out at low angles. Each blade is 5 triangles with a raised
  midrib, so it keeps real thickness from any side. Modelled round their ROOT at the origin: the root is the pivot the
  game bends them about. No texture: a per-vertex greyscale shade (dark root, pale tip, lighter rib) times the part's
  Color, which is the palette, so one mesh serves every islet (see tuft_material for why).
- SCATTER: a jittered grid kept by a soft density field (no grid, no repeats), 1-3 tufts per spot, random turn and
  a narrow size range; kept off the water, rocks, flowers, the very edge, and mostly off the bare earth.
- ISLETS: the near garden islets get tufts too, tinted with their own tree's palette (gnomon_ground.ISLES).
- OUTPUT: collection Grass in the .blend (linked duplicates of the templates, coloured per tuft, never in the map
  export), `grass_templates.glb` (the five vertex-shaded meshes, for Open Cloud), and `src/shared/Config/GrassLayouts/
  Gnomon.luau` (every tuft: position from the arena centre on the floor top, turn, scale, template, colour index),
  which the client builds and animates (Shared/GrassField).
"""
import json
import math
import os
import random

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import common as C
import paint as P
import gnomon_dress as DR
import gnomon_ground as GG

HERE = os.path.dirname(os.path.abspath(__file__))
LAYOUT = os.path.join(HERE, "..", "..", "src", "shared", "Config", "GrassLayouts", "Gnomon.luau")

# name: (blades, length, width, tilt from flat (rad), layers, height cap, weight, kit source)
TUFTS = {
    "Tuft_Fine": (7, (0.5, 0.8), (0.07, 0.1), (0.55, 0.95), 1, 0.62, 0.34, "Plant_Tall_Blade / Plant_Spiky"),
    "Tuft_Fan": (6, (0.45, 0.65), (0.11, 0.15), (0.2, 0.45), 1, 0.36, 0.26, "Plant_Groundcover"),
    "Tuft_Leaf": (5, (0.4, 0.55), (0.16, 0.22), (0.3, 0.55), 1, 0.4, 0.16, "Plant_Broadleaf_Small"),
    "Tuft_Round": (4, (0.3, 0.42), (0.2, 0.26), (0.15, 0.35), 1, 0.28, 0.12, "Plant_Roundleaf"),
    "Tuft_Sprig": (5, (0.6, 0.85), (0.06, 0.08), (0.85, 1.15), 1, 0.8, 0.12, "Plant_Broadleaf (stalks)"),
}
TEMPLATE_ORDER = list(TUFTS)

# the arena's tuft colours (sRGB, the colour of a tip; the atlas darkens toward the root): three tones of image 1's
# greens, picked by the same broad field that lightens and deepens the ground, so tufts sit in their patch
ARENA_TONES = [(144, 180, 82), (128, 168, 76), (160, 190, 92)]  # light-1 (2026-11-12): lifted to sit in the sunlit swaths
ATLAS_COLUMNS = 4


def grass_atlas(tex_dir):
    """The shared RGBA atlas (gnomon_ground.tuft_atlas): clear tips show the part's Color, shade fades in to the root."""
    rgba = GG.tuft_atlas(ATLAS_COLUMNS)
    h, w = rgba.shape[:2]
    os.makedirs(tex_dir, exist_ok=True)
    path = os.path.join(tex_dir, "Grass_Tuft_Atlas.png")
    img = bpy.data.images.new("Grass_Tuft_Atlas", w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(rgba[::-1], dtype=np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def tuft_material(atlas_path=None):
    """Vertex shade x the object's colour. MEASURED in Studio 2026-11-11: a MeshPart's TextureID is NOT tinted by its
    Color (a greyscale atlas drew white), and its transparent areas don't show the Color either (grey-lavender), so
    the tufts carry no texture: their shading is a per-vertex greyscale gradient (dark root, pale tip, lighter rib)
    in COLOR_0, and the part's Color is the palette. Blender shows the same: Color Attribute x Object Info."""
    mat = bpy.data.materials.get("Grass_Tuft") or bpy.data.materials.new("Grass_Tuft")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.95
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Color"
    info = nt.nodes.new("ShaderNodeObjectInfo")
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type, mul.blend_type = "RGBA", "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(vc.outputs["Color"], mul.inputs[6])
    nt.links.new(info.outputs["Color"], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.use_backface_culling = False
    return mat


def shade_vertices(me):
    """COLOR_0 for one tuft: greyscale by height (root 0.5 -> tip 1.0, in linear), the raised rib vertices a touch
    lighter. Multiplied by the part's Color in Roblox."""
    co = np.empty((len(me.vertices), 3))
    me.vertices.foreach_get("co", co.ravel())
    z = co[:, 2] - co[:, 2].min()
    h = z / max(z.max(), 1e-4)
    g = 0.5 + 0.5 * P.smoothstep(0.0, 0.9, h)
    # rib vertices are the 4th of each blade's 6 (root L, root R, mid L, RIB, mid R, tip)
    rib = (np.arange(len(co)) % 6) == 3
    g = np.where(rib, np.minimum(g + 0.08, 1.0), g)
    attr = me.color_attributes.get("Color") or me.color_attributes.new("Color", "BYTE_COLOR", "POINT")
    rgba = np.stack([g, g, g * 0.97, np.ones_like(g)], axis=1).astype(np.float32)
    attr.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = attr


def _blade(V, F, U, base, ang, tilt, length, width, column, rng):
    """One blade, 5 triangles: root (2 verts), middle (3, the midrib raised), tip (1). Curves up then over."""
    d = Vector((math.cos(ang) * math.cos(tilt), math.sin(ang) * math.cos(tilt), math.sin(tilt)))
    side = Vector((-math.sin(ang), math.cos(ang), 0.0))
    up = side.cross(d).normalized()
    if up.z < 0:
        up = -up
    bend = rng.uniform(0.12, 0.3)
    mid_c = base + d * length * 0.5 + up * length * 0.05
    tip_c = base + d * length - Vector((0, 0, bend * length * math.cos(tilt)))
    col = column / ATLAS_COLUMNS
    du = 1 / ATLAS_COLUMNS
    o = len(V)
    V += [base - side * width * 0.35, base + side * width * 0.35]
    U += [(col + 0.2 * du, 0.0), (col + 0.8 * du, 0.0)]
    V += [mid_c - side * width * 0.5, mid_c + up * width * 0.22, mid_c + side * width * 0.5]
    U += [(col + 0.05 * du, 0.5), (col + 0.5 * du, 0.55), (col + 0.95 * du, 0.5)]
    V += [tip_c]
    U += [(col + 0.5 * du, 1.0)]
    b0, b1, mL, mR_, mR, t = o, o + 1, o + 2, o + 3, o + 4, o + 5
    F += [(b0, b1, mR_), (b0, mR_, mL), (b1, mR, mR_), (mL, mR_, t), (mR_, mR, t)]


def tuft_mesh(name, rng):
    blades, length, width, tilt, layers, cap, _, _ = TUFTS[name]
    V, F, U = [], [], []
    for i in range(blades):
        a = i / blades * math.tau + rng.uniform(-0.35, 0.35)
        r0 = rng.uniform(0.0, 0.06)
        base = Vector((math.cos(a) * r0, math.sin(a) * r0, 0.0))
        _blade(V, F, U, base, a, rng.uniform(*tilt), rng.uniform(*length), rng.uniform(*width), rng.randrange(ATLAS_COLUMNS), rng)
    arr = np.array([tuple(v) for v in V])
    top = arr[:, 2].max()
    if top > cap:
        arr[:, 2] *= cap / top
    arr[:, 2] -= 0.04  # seated a hair into the ground so no root floats over a slope
    me = bpy.data.meshes.new(name)
    me.from_pydata(arr.tolist(), [], F)
    uvl = me.uv_layers.new(name="UVMap")
    loops = [U[i] for f in F for i in f]
    uvl.data.foreach_set("uv", np.array(loops, dtype=np.float32).ravel())
    for poly in me.polygons:
        poly.use_smooth = True
    return me


def build_templates(tex_dir):
    atlas = None  # no texture (see tuft_material)
    mat = tuft_material()
    col = bpy.data.collections.get("GrassTemplates") or bpy.data.collections.new("GrassTemplates")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    meshes, info = {}, {}
    for k, name in enumerate(TEMPLATE_ORDER):
        me = tuft_mesh(name, random.Random(7100 + 31 * k))
        shade_vertices(me)
        me.materials.append(mat)
        obj = bpy.data.objects.new(name, me)
        obj.location = (k * 3.0, -900.0, 0.0)  # out of the way; the export moves them back to the origin
        col.objects.link(obj)
        obj["double_sided"] = True
        meshes[name] = me
        co = np.empty((len(me.vertices), 3))
        me.vertices.foreach_get("co", co.ravel())
        lo, hi = co.min(0), co.max(0)
        c = (lo + hi) / 2
        # Roblox axes (x, y up, z = -Blender y): the bounding-box centre from the root, and the size
        info[name] = dict(offset=[round(float(c[0]), 4), round(float(c[2]), 4), round(float(-c[1]), 4)],
                          size=[round(float(hi[0] - lo[0]), 4), round(float(hi[2] - lo[2]), 4), round(float(hi[1] - lo[1]), 4)],
                          tris=len(F_of(me)))
    col.hide_render = True
    return meshes, mat, info, atlas


def F_of(me):
    me.calc_loop_triangles()
    return me.loop_triangles


# --- scatter ----------------------------------------------------------------------------------------
def _tone(x, y):
    """The arena tone for a tuft here: follows the ground's broad light/deep patches (gnomon_ground.meadow)."""
    w1 = float(P.fbm2(np.array(x * 0.016), np.array(y * 0.016), 301, 4))
    w2 = float(P.fbm2(np.array(x * 0.031 + 40), np.array(y * 0.031 - 12), 302, 3))
    if w1 > 0.57:
        return 2
    if w2 > 0.59:
        return 1
    return 0


def scatter_arena(avoid, rng):
    """[(x, y, z, turn, scale, template index, colour index)] in Blender studs over the battlefield."""
    weights = np.array([TUFTS[n][6] for n in TEMPLATE_ORDER])
    cum = np.cumsum(weights / weights.sum())
    a, b = C.A - C.RIM - 1.5, C.B - C.RIM - 1.5
    rw = DR.water_rho()
    step = 5.6
    out = []
    for gx in np.arange(-a, a, step):
        for gy in np.arange(-b, b, step):
            x, y = gx + rng.uniform(-0.5, 0.5) * step, gy + rng.uniform(-0.5, 0.5) * step
            if (x / a) ** 2 + (y / b) ** 2 > 1:
                continue
            if float(DR.pond_rho(x, y)) < rw * 1.06:
                continue
            if any((x - ax) ** 2 + (y - ay) ** 2 < (ar + 0.6) ** 2 for ax, ay, ar in avoid):
                continue
            dens = 0.42 + 0.5 * float(P.fbm2(np.array(x * 0.05), np.array(y * 0.05), 88, 3))
            E, _ = GG.earth_mask(np.array([x]), np.array([y]))
            dens *= 1.0 - 0.8 * float(E[0])
            if rng.random() > dens:
                continue
            n = 1 if rng.random() < 0.55 else (2 if rng.random() < 0.75 else 3)
            for k in range(n):
                px, py = (x, y) if k == 0 else (x + rng.uniform(-0.9, 0.9), y + rng.uniform(-0.9, 0.9))
                t = int(np.searchsorted(cum, rng.random()))
                out.append((px, py, DR.ground_z(px, py), rng.uniform(0, math.tau), rng.uniform(0.85, 1.2), t, _tone(px, py)))
    return out


def scatter_islets(islets, placements, rng):
    """Tufts on the near garden islets' caps, coloured by each islet's palette (colour index 3 + palette slot)."""
    names = list(GG.ISLES)
    weights = np.array([TUFTS[n][6] for n in TEMPLATE_ORDER])
    cum = np.cumsum(weights / weights.sum())
    out = []
    for cx, cy, cz, rx, ry, isle in islets:
        n = int(math.pi * rx * ry * 0.7 / 9.0)
        for _ in range(n * 3):
            if n <= 0:
                break
            u, v = rng.uniform(-1, 1), rng.uniform(-1, 1)
            if u * u + v * v > 0.72:
                continue
            x, y = cx + u * rx, cy + v * ry
            if any((x - p["x"]) ** 2 + (y - p["y"]) ** 2 < (2.6 * p["scale"] if p["asset"].startswith(("Tree_", "Ruin_", "Rock_")) else 1.2) ** 2
                   for p in placements):
                continue
            t = int(np.searchsorted(cum, rng.random()))
            out.append((x, y, cz, rng.uniform(0, math.tau), rng.uniform(1.0, 1.35), t, len(ARENA_TONES) + names.index(isle)))
            n -= 1
    return out


def colours():
    """Every colour index -> sRGB tip colour: the arena tones, then one per islet palette."""
    return [list(c) for c in ARENA_TONES] + [list(GG.ISLES[n]["grass"]) for n in GG.ISLES]


def instance_scene(tufts, meshes):
    """Collection Grass: one linked duplicate per tuft, its object colour the palette tone (shown by the material)."""
    col = bpy.data.collections.get("Grass") or bpy.data.collections.new("Grass")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    cols = [tuple(float(v) for v in P.srgb_to_linear(np.array(c) / 255.0)) + (1.0,) for c in colours()]
    for i, (x, y, z, rot, s, t, ci) in enumerate(tufts):
        o = bpy.data.objects.new(f"G{i:05d}", meshes[TEMPLATE_ORDER[t]])
        o.matrix_world = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot, 4, "Z") @ Matrix.Scale(s, 4)
        o.color = cols[ci]
        col.objects.link(o)


def write_layout(tufts, info, path=LAYOUT):
    """The Luau layout: per tuft x, y, z (Roblox axes from the arena centre on the floor's top), turn (Roblox
    sign), scale, template, colour; flat arrays of numbers so the module stays small."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    def f(v, d=2):
        s = f"{v:.{d}f}".rstrip("0").rstrip(".")
        return "0" if s in ("-0", "") else s
    rows = []
    for x, y, z, rot, s, t, ci in tufts:
        rows.append(",".join([f(x), f(z), f(-y), f(rot, 3), f(s), str(t + 1), str(ci + 1)]))
    tmpl = ",\n\t\t".join(
        f'{{ name = "{n}", offset = Vector3.new({info[n]["offset"][0]}, {info[n]["offset"][1]}, {info[n]["offset"][2]}), '
        f'size = Vector3.new({info[n]["size"][0]}, {info[n]["size"][1]}, {info[n]["size"][2]}) }}'
        for n in TEMPLATE_ORDER)
    cols = ", ".join(f"Color3.fromRGB({c[0]}, {c[1]}, {c[2]})" for c in colours())
    body = ",\n".join("\t\t" + ", ".join(rows[i : i + 6]) for i in range(0, len(rows), 6))
    src = f"""--!strict
-- GENERATED by design/maps/gnomon_grass.py (Blender build of Gnomon): DO NOT EDIT BY HAND.
-- Gnomon's low grass tufts for Shared/GrassField: {len(tufts)} tufts.
-- Templates: ReplicatedStorage.HT_GrassKit.<name> (MeshParts modelled round their root; `offset` is the
-- bounding-box centre from the root and `size` the mesh size at scale 1, both in studs, Roblox axes).
-- Data: 7 numbers per tuft: x, y, z from the arena centre on the floor's top, turn about up (radians), scale,
-- template index, colour index (tip colour; each mesh's vertex shade darkens toward the root).
return {{
	templates = {{
		{tmpl},
	}},
	colours = {{ {cols} }},
	stride = 7,
	data = {{
{body},
	}},
}}
"""
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(src)
    return path, len(src)


def export_templates(meshes, out_dir):
    """grass_templates.glb: the five tufts at the origin (root on it), vertex-shaded (COLOR_0), no texture."""
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    tmp = bpy.data.collections.new("GrassTemplateExport")
    scene.collection.children.link(tmp)
    objs = []
    for k, name in enumerate(TEMPLATE_ORDER):
        o = bpy.data.objects.new(name, meshes[name])
        tmp.objects.link(o)
        objs.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = os.path.join(out_dir, "grass_templates.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True, export_tangents=False,
                              export_materials="EXPORT", export_image_format="AUTO",
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(tmp)
    return path
