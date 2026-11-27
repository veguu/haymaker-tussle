"""MAP 1 FULL OF LIFE, the GAME build (owner 2026-11-26: "built it in roblox studios so i can see it"). Reads the
APPROVED preview (meadow_life.py's meadow_life_preview.blend, never saved here) and writes what the game needs:

    blender -b out/suite/meadow_life/meadow_life_preview.blend -P meadow_life_game.py -- out/suite/meadow_life_game
        -> meadow_life.glb   the upload: one TEMPLATE mesh per kind (cloned in Studio, so each kind is one instanced
                             draw) on a shelf off the arena, and the STATIC pieces in place; one palette image
           life.json         the templates (centre, pivot), the statics (centre) and every instance (pivot, yaw, kind,
                             params), the chimneys, the waterfall's line, the mist; studio_life.py turns it into Luau
           life_palette.png  the flat colours, 16 px cells (exact down to the 8 x 8 mip)

The geometry IS the preview's (the same blocks he checked), recoloured from material slots to palette cells. What
the game moves (wings, heads, bodies) comes out as separate templates with their pivot recorded; the motion itself
is Core/MapLife + Shared/MapLife (one client loop), not keyframes. Positions are arena-local, Roblox axes
(x, y = Blender z, z = -Blender y).
"""
import json
import math
import os
import sys

import bmesh
import bpy
from bpy_extras import anim_utils
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(OUT, exist_ok=True)
scene = bpy.context.scene
CELL, GRID = 16, 8  # 8 x 8 cells of 16 px: a 128 px palette
SHELF = Vector((-120.0, -262.0, 0.0))  # templates sit in a row here (Blender), off the arena, for the import's fit


def rb(v):
    """Blender (x, y, z) -> Roblox arena-local [x, y, z], rounded."""
    return [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]


def rbs(v):
    """A size: Blender (x, y, z) -> Roblox [x, y, z], no sign change."""
    return [round(v.x, 3), round(v.z, 3), round(v.y, 3)]


# --- the palette: every flat colour the exported pieces use ------------------------------------------------------
COLOURS = []


def colour_of(mat):
    p = mat.node_tree.nodes.get("Principled BSDF") if mat and mat.use_nodes else None
    lin = p.inputs["Base Color"].default_value if p else (0.8, 0.8, 0.8, 1)
    return tuple(int(round(255 * max(0.0, min(1.0, c)) ** (1 / 2.2))) for c in lin[:3])


def cell(rgb):
    if rgb not in COLOURS:
        COLOURS.append(rgb)
        if len(COLOURS) > GRID * GRID:
            raise SystemExit("palette full")
    i = COLOURS.index(rgb)
    return ((i % GRID) + 0.5) / GRID, 1 - ((i // GRID) + 0.5) / GRID


PALETTE_MAT = bpy.data.materials.new("Life_Palette")
EXPORT = []  # objects for the GLB
TRIS = {}


def bake(name, sources, keep_bottom=True):
    """One export mesh from [(object, matrix)]: each source's own vertices through `matrix` (Blender axes), every face
    UV'd to its material's palette cell. keep_bottom=False drops faces pointing straight down (never seen: the
    ground pieces)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for o, m in sources:
        me = o.data
        for poly in me.polygons:
            n = (m.to_3x3() @ poly.normal).normalized()
            if not keep_bottom and n.z < -0.95:
                continue
            mat = o.material_slots[poly.material_index].material if o.material_slots else None
            u, v = cell(colour_of(mat))
            verts = [bm.verts.new(m @ me.vertices[i].co) for i in poly.vertices]
            f = bm.faces.new(verts)
            for lp in f.loops:
                lp[uv].uv = (u, v)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(PALETTE_MAT)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    EXPORT.append(ob)
    TRIS[name] = len(me.polygons)
    co = [v.co for v in me.vertices]
    lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    return (lo + hi) / 2, hi - lo


TEMPLATES, STATICS = {}, {}
_shelf = [0]


def template(name, sources, pivot_local=Vector()):
    """A kind's template: its sources in their OWN frame (pivot at the origin), set on the shelf. Records where the
    import's part centre sits from the pivot (Roblox axes), which is what the game uses to place and turn it."""
    at = SHELF + Vector((_shelf[0] * 10.0, 0, 0))
    _shelf[0] += 1
    centre, size = bake(name, [(o, Matrix.Translation(at - pivot_local) @ m) for o, m in sources])
    TEMPLATES[name] = {"centre": rb(centre), "pivot": rb(at), "offset": rb(centre - at), "size": rbs(size)}


def static(name, sources, keep_bottom=True):
    centre, size = bake(name, sources, keep_bottom)
    STATICS[name] = {"centre": rb(centre), "size": rbs(size)}


O = bpy.data.objects
I4 = Matrix.Identity(4)


def local(o):
    return (o, I4)


def first_key(o):
    """An animated object's location at its FIRST key (a smoke puff at its chimney, a mist puff at its start)."""
    ad = o.animation_data
    bag = anim_utils.action_get_channelbag_for_slot(ad.action, ad.action_slot)
    return Vector([bag.fcurves.find("location", index=i).keyframe_points[0].co[1] for i in range(3)])


# --- the moving creatures' rest poses and homes (sampled over the loop) ------------------------------------------
SAMPLES = list(range(1, 601, 15))
names = [o.name for o in O if o.name.startswith(("Butterfly_", "Bee_")) and "_Wing" not in o.name]
sums = {n: Vector() for n in names}
for f in SAMPLES:
    scene.frame_set(f)
    for n in names:
        sums[n] += O[n].matrix_world.translation
scene.frame_set(1)
mean = {n: sums[n] / len(SAMPLES) for n in names}

# butterflies: one body, a wing per colour (the right wing; the left is the same blocks turned half a turn about the
# body's length, which the game does)
template("Life_ButterflyBody", [local(O["Butterfly_00"])])
for c in range(5):
    w = O[f"Butterfly_{c:02d}_WingR"]
    template(f"Life_ButterflyWing_{c}", [local(w)])
butterflies = [{"home": rb(mean[f"Butterfly_{k:02d}"]), "colour": k % 5} for k in range(14)]
# bees: the body, both wings as one piece (they flicker together in the game)
bee_wings = [o for o in O if o.name.startswith("Bee_0_Wing")]
template("Life_BeeBody", [local(O["Bee_0"])])
template("Life_BeeWings", [local(w) for w in bee_wings])
bees = [{"home": rb(mean[f"Bee_{k}"])} for k in range(8)]

# animals: body (pivot at the feet), head (pivot at the neck)
animals = []
for kind, first in (("Sheep", "Sheep_0"), ("Cow", "Cow_0")):
    template(f"Life_{kind}Body", [local(O[first])])
    head = O[f"{first}_Head"]
    template(f"Life_{kind}Head", [local(head)])
    TEMPLATES[f"Life_{kind}Head"]["neck"] = rb(head.location)  # the neck in the body's own frame
for o in O:
    if o.name.startswith(("Sheep_", "Cow_")) and not o.name.endswith("_Head"):
        animals.append({"name": o.name, "kind": "Sheep" if o.name.startswith("Sheep") else "Cow", "at": rb(o.location), "yaw": round(o.rotation_euler.z, 4)})
animals.sort(key=lambda a: a["name"])

# birds: a gull and a swallow (body + the right wing, hinge recorded)
for kind, first in (("Gull", "Bird_0_0"), ("Swallow", "Bird_2_0")):
    template(f"Life_{kind}Body", [local(O[first])])
    wings = [o for o in O if o.parent == O[first] and o.type == "MESH"]
    right = max(wings, key=lambda o: o.location.x)
    template(f"Life_{kind}Wing", [local(right)])
    TEMPLATES[f"Life_{kind}Wing"]["hinge"] = rb(right.location)
# balloons: each its own template, one instance at its start
balloons = []
for b in range(2):
    template(f"Life_Balloon_{b}", [local(O[f"Balloon_{b}"])])
    balloons.append({"template": f"Life_Balloon_{b}", "at": rb(O[f"Balloon_{b}"].location)})

# dandelions: the puffs move (they burst and regrow); the stems are one static piece
template("Life_DandelionPuff", [local(O["Dandelion_00_Puff"])])
puffs = [rb(o.matrix_world.translation) for o in sorted((o for o in O if o.name.endswith("_Puff") and o.name.startswith("Dandelion_")), key=lambda o: o.name)]
static("Life_DandelionStems", [(o, o.matrix_world) for o in O if o.name.startswith("Dandelion_") and o.name.endswith("_Stem")], keep_bottom=False)

# vines and roots under the rim: four vine and two root templates (by length), each hang a turned clone of the nearest
hangs = []
for o in O:
    if o.name.startswith(("Vine_", "Root_")) and o.type == "MESH":
        zs = [v.co.z for v in o.data.vertices]
        hangs.append({"name": o.name, "root": o.name.startswith("Root"), "len": max(zs) - min(zs), "top": o.location.copy(),
                      "angle": math.atan2(o.location.y, o.location.x)})
VINE_T, ROOT_T = [], []
for is_root, picks, out in ((False, 4, VINE_T), (True, 2, ROOT_T)):
    group = sorted((h for h in hangs if h["root"] == is_root), key=lambda h: h["len"])
    for i in range(picks):
        h = group[min(len(group) - 1, round((i + 0.5) / picks * len(group) - 0.5))]
        name = f"Life_{'Root' if is_root else 'Vine'}_{i}"
        template(name, [local(O[h["name"]])])
        out.append((name, h))
rim = []
for h in hangs:
    tname, th = min(ROOT_T if h["root"] else VINE_T, key=lambda p: abs(p[1]["len"] - h["len"]))
    rim.append({"template": tname, "top": rb(h["top"]), "yaw": round(h["angle"] - th["angle"], 4), "root": h["root"]})

# the floor's and the lip's still pieces, in place (the clover and mushrooms never show their undersides)
static("Life_Mushrooms", [(O["Mushrooms"], O["Mushrooms"].matrix_world)], keep_bottom=False)
static("Life_Clover", [(O["Clover"], O["Clover"].matrix_world)], keep_bottom=False)
static("Life_LipFlowers", [(O["LipFlowers"], O["LipFlowers"].matrix_world)])
static("Life_Stream", [(O["Waterfall_Stream"], O["Waterfall_Stream"].matrix_world)] + [(o, o.matrix_world) for o in O if o.name.startswith("Waterfall_Foam")])

# chimneys (each smoke puff's first key is the cap + 0.8 up) and the waterfall's line (the sheet's middle column)
scene.frame_set(1)
chimneys = []
for o in O:
    if o.name.startswith("Smoke_") and o.name.endswith("_0"):
        chimneys.append(rb(first_key(o) - Vector((0, 0, 0.8))))
fall = O["Waterfall"]
vs = [fall.matrix_world @ v.co for v in fall.data.vertices]
line = []
for r in range(len(vs) // 5):
    row = vs[r * 5:(r + 1) * 5]
    line.append({"at": rb(row[2]), "width": round((row[4] - row[0]).length, 3)})
mist = [rb(first_key(O[f"Mist_{k}"])) for k in range(8)]

# --- the palette image, the GLB, the data ---------------------------------------------------------------------------
size = CELL * GRID
img = bpy.data.images.new("life_palette", size, size, alpha=False)
px = [0.0] * (size * size * 4)
for i, rgb in enumerate(COLOURS):
    cx, cy = i % GRID, GRID - 1 - i // GRID  # row 0 at the image's top (Blender's pixel rows run up)
    for y in range(cy * CELL, (cy + 1) * CELL):
        for x in range(cx * CELL, (cx + 1) * CELL):
            k = (y * size + x) * 4
            px[k:k + 4] = [rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0]
img.pixels = px
img.filepath_raw = os.path.join(OUT, "life_palette.png")
img.file_format = "PNG"
img.save()
PALETTE_MAT.use_nodes = True
nt = PALETTE_MAT.node_tree
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = img
tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9

for o in bpy.context.view_layer.objects:
    o.select_set(o in EXPORT)
glb = os.path.join(OUT, "meadow_life.glb")
bpy.ops.export_scene.gltf(
    filepath=glb, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
    export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
    export_image_format="AUTO", export_skins=False, export_animations=False,
)
data = {
    "templates": TEMPLATES, "statics": STATICS, "triangles": TRIS, "palette": COLOURS,
    "butterflies": butterflies, "bees": bees, "animals": animals, "balloons": balloons, "puffs": puffs, "rim": rim,
    "chimneys": chimneys, "waterfall": line, "mist": mist,
}
json.dump(data, open(os.path.join(OUT, "life.json"), "w", encoding="utf-8", newline="\n"), indent=1)
print("LIFE GAME", glb, round(os.path.getsize(glb) / 1e6, 3), "MB", len(EXPORT), "meshes", sum(TRIS.values()), "triangles",
      len(COLOURS), "colours", flush=True)
for n in sorted(TRIS):
    print("  ", n, TRIS[n], flush=True)
print("  counts: butterflies", len(butterflies), "bees", len(bees), "animals", len(animals), "puffs", len(puffs), "rim", len(rim),
      "chimneys", len(chimneys), "fall rows", len(line), flush=True)
