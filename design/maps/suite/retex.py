"""Shrinks a BUILT suite map's far colour textures and re-exports its GLBs, with no re-bake (2026-11-21, Quarry):

    python retex.py <out folder> [--far 1100] [--px 512]

1. (system Python, PIL) every mesh whose centre is more than --far studs from the arena's centre (manifest.json,
   arena-local) and whose <name>_Color.png is bigger than --px is cut to --px (Lanczos). The full-size PNG goes to
   textures_full/ first (never overwritten: a second run keeps the true originals).
2. (Blender, headless, runs this file again) opens <map>.blend (saved after its export, so its colour attributes are
   already gone), reloads every image from disk and exports the GLBs exactly as base.export does (same grouping,
   settings and names), then rewrites manifest.json's "files" and each mesh's "file". Geometry is untouched.
3. checks every PNG inside the new GLBs against the textures on disk (count and sizes).

Why: a 300-stud island 1,300+ studs away covers a few hundred pixels of a screen, so 1024 px only costs phones
memory. base.py's bake caps these at 512 for maps built after Quarry, so they need none of this.
"""
import json
import os
import shutil
import struct
import subprocess
import sys

BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"


def args(argv):
    out, far, px = None, 1100.0, 512
    i = 0
    while i < len(argv):
        if argv[i] == "--far":
            far = float(argv[i + 1])
            i += 2
        elif argv[i] == "--px":
            px = int(argv[i + 1])
            i += 2
        else:
            out = argv[i]
            i += 1
    return os.path.abspath(out), far, px


def shrink(out, far, px):
    from PIL import Image

    man = json.load(open(os.path.join(out, "manifest.json"), encoding="utf-8"))
    tex, full = os.path.join(out, "textures"), os.path.join(out, "textures_full")
    os.makedirs(full, exist_ok=True)
    cut = []
    for name, m in sorted(man["meshes"].items()):
        if (m["x"] ** 2 + m["z"] ** 2) ** 0.5 <= far:
            continue
        path = os.path.join(tex, f"{name}_Color.png")
        if not os.path.exists(path):
            continue
        img = Image.open(path)
        if img.size[0] <= px and img.size[1] <= px:
            continue
        keep = os.path.join(full, os.path.basename(path))
        if not os.path.exists(keep):
            shutil.copy2(path, keep)
        mode = img.mode
        small = img.convert("RGBA").resize((px, px), Image.LANCZOS)
        # back to RGB or RGBA as it was; a palette (P) image stays RGBA (converting to P would re-quantise it)
        (small.convert(mode) if mode in ("RGB", "RGBA", "L", "LA") else small).save(path)
        cut.append(name)
    print("SHRUNK", len(cut), "textures to", px, "px:", ", ".join(cut), flush=True)
    return cut


def blender_export(out):
    import bpy

    man_path = os.path.join(out, "manifest.json")
    man = json.load(open(man_path, encoding="utf-8"))
    name = man["map"]
    for img in bpy.data.images:
        if img.source == "FILE" and img.filepath:
            img.reload()
    up, tex = os.path.join(out, "export"), os.path.join(out, "textures")
    # the same grouping as base.export: meshes by name, a new file past about 13 MB of textures and faces
    objs = sorted((o for o in bpy.data.objects if o.type == "MESH" and o.name in man["meshes"]), key=lambda o: o.name)
    if len(objs) != len(man["meshes"]):
        raise SystemExit(f"the .blend has {len(objs)} of the manifest's {len(man['meshes'])} meshes")
    groups, current, budget = [], [], 0
    for o in objs:
        t = os.path.join(tex, f"{o.name}_Color.png")
        size = (os.path.getsize(t) if os.path.exists(t) else 0) + len(o.data.polygons) * 110
        if current and budget + size > 13e6:
            groups.append(current)
            current, budget = [], 0
        current.append(o)
        budget += size
    groups.append(current)
    # every GLB is written to export_new/ first; the old ones are replaced only once all the new ones exist
    new = os.path.join(out, "export_new")
    shutil.rmtree(new, ignore_errors=True)
    os.makedirs(new)
    files = []
    for index, group in enumerate(groups, 1):
        for o in bpy.context.view_layer.objects:
            o.select_set(o in group)
        path = os.path.join(new, f"{name.lower()}_{index}.glb")
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
            export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
            export_image_format="AUTO", export_skins=False, export_animations=False,
        )
        files.append({"file": os.path.basename(path), "mb": round(os.path.getsize(path) / 1e6, 2), "meshes": [o.name for o in group]})
        for o in group:
            man["meshes"][o.name]["file"] = index
        print("GLB", files[-1]["file"], files[-1]["mb"], "MB", len(group), "meshes", flush=True)
    for old in os.listdir(up):
        if old.lower().startswith(name.lower() + "_") and old.endswith(".glb"):
            os.remove(os.path.join(up, old))
    for f in files:
        shutil.move(os.path.join(new, f["file"]), os.path.join(up, f["file"]))
    os.rmdir(new)
    man["files"] = files
    json.dump(man, open(man_path, "w", encoding="utf-8", newline="\n"), indent=1)


def glb_pngs(path):
    """(width, height) of every PNG embedded in a GLB."""
    data = open(path, "rb").read()
    length = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + length])
    binary = 20 + length + 8
    sizes = []
    for img in gltf.get("images", []):
        view = gltf["bufferViews"][img["bufferView"]]
        start = binary + view.get("byteOffset", 0)
        if data[start:start + 8] == b"\x89PNG\r\n\x1a\n":
            sizes.append(struct.unpack(">II", data[start + 16:start + 24]))
    return sizes


def verify(out, px, cut):
    from PIL import Image

    man = json.load(open(os.path.join(out, "manifest.json"), encoding="utf-8"))
    found = {}
    for f in man["files"]:
        for s in glb_pngs(os.path.join(out, "export", f["file"])):
            found[s] = found.get(s, 0) + 1
    want = {}
    for name in man["meshes"]:
        t = os.path.join(out, "textures", f"{name}_Color.png")
        if os.path.exists(t):
            s = Image.open(t).size
            want[s] = want.get(s, 0) + 1
    print("GLB TEXTURES", sorted(found.items()), "ON DISK", sorted(want.items()), flush=True)
    if found != want:
        raise SystemExit("the GLBs' textures do not match the textures on disk")
    print("FILES", [(f["file"], f["mb"], len(f["meshes"])) for f in man["files"]], "TOTAL MB", round(sum(f["mb"] for f in man["files"]), 2), flush=True)


if __name__ == "__main__":
    if "bpy" in sys.modules or "--blender" in sys.argv:
        blender_export(os.path.abspath(sys.argv[sys.argv.index("--") + 1]))
    else:
        out, far, px = args(sys.argv[1:])
        cut = shrink(out, far, px)
        blend = os.path.join(out, json.load(open(os.path.join(out, "manifest.json"), encoding="utf-8"))["map"].lower() + ".blend")
        subprocess.run([BLENDER, "-b", "--factory-startup", blend, "-P", os.path.abspath(__file__), "--", out], check=True)
        verify(out, px, cut)
