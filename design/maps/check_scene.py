"""Structural check of a built arena (user brief 2026-11-10: objects phasing through each other, loose and
floating pieces, balloon parts that don't connect). Run on the saved .blend:

    blender -b out/gnomon/gnomon.blend -P check_scene.py -- [bob studs]

Splits every exported mesh into its loose parts and joins parts whose boxes touch (0.15 studs of slack)
into ASSEMBLIES: an islet with its trees and props is one, a balloon is one, the arena is one. Reports:
- LOOSE: a small assembly (under 12 studs across) that touches nothing: a floating flower, a pennant
  off its line, a rope end in the air. Floating rock fragments and clouds are allowed (FREE_OK).
- CLASH: two big assemblies whose boxes overlap (an islet's trees in another islet, a fragment inside an
  island). Not proof of an intersection, so each is listed for a look.
- BOB: a bobbing assembly (balloons) whose box, grown by its full bob travel, reaches another assembly.
- BURIED: an obstacle rock or stump sunk more than 0.7 studs into the floor, or floating above it.
"""
import os
import sys

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
BOB = float(args[0]) if args else 8.0  # rise + sway at most (MapEnvironments bob rules), studs
SLACK = 0.15
FREE_OK = ("Fragments_", "Cloud")
BOBBING = ("Sight_BalloonNear", "Sight_BalloonFar")


def parts():
    out = []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or not any(c.name == "Export" for c in obj.users_collection):
            continue
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.transform(obj.matrix_world)
        seen = set()
        for f in bm.faces:
            if f.index in seen:
                continue
            stack, verts = [f], []
            seen.add(f.index)
            while stack:
                g = stack.pop()
                verts.extend(v.co[:] for v in g.verts)
                for e in g.edges:
                    for h in e.link_faces:
                        if h.index not in seen:
                            seen.add(h.index)
                            stack.append(h)
            v = np.array(verts)
            out.append((obj.name, v.min(0), v.max(0)))
        bm.free()
    return out


def assemblies(ps):
    n = len(ps)
    lo = np.array([p[1] for p in ps]) - SLACK
    hi = np.array([p[2] for p in ps]) + SLACK
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for i in range(n):
        touch = np.all((lo[i] <= hi) & (hi[i] >= lo), axis=1)
        for j in np.nonzero(touch)[0]:
            if j > i:
                parent[find(i)] = find(j)
    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    out = []
    for idx in groups.values():
        names = sorted({ps[i][0] for i in idx})
        out.append((names, lo[idx].min(0) + SLACK, hi[idx].max(0) - SLACK, len(idx)))
    return out


def label(names):
    return ",".join(names[:4]) + ("..." if len(names) > 4 else "")


def main():
    ps = parts()
    asm = assemblies(ps)
    print(f"SCENE {len(ps)} loose parts in {len(asm)} assemblies")
    big = []
    for names, lo, hi, count in asm:
        size = float(np.max(hi - lo))
        if size < 12 and not all(n.startswith(FREE_OK) for n in names):
            print(f"LOOSE {label(names)} size {size:.1f} at {np.round((lo + hi) / 2, 1).tolist()}")
        if size >= 12:
            big.append((names, lo, hi))
    for i, (na, la, ha) in enumerate(big):
        grow = BOB if any(n.startswith(BOBBING) for n in na) else 0.0
        for nb, lb, hb in big[i + 1 :]:
            g = grow or (BOB if any(n.startswith(BOBBING) for n in nb) else 0.0)
            if np.all(la - g <= hb) and np.all(ha + g >= lb):
                kind = "BOB" if g else "CLASH"
                print(f"{kind} {label(na)} <-> {label(nb)}")
    # obstacles against the floor (its top is z = 0)
    for name, lo, hi in ps:
        if name.startswith("Obstacles_"):
            if lo[2] < -0.75 or lo[2] > 0.05:
                print(f"BURIED {name} part bottom {lo[2]:.2f} at {np.round((lo + hi) / 2, 1).tolist()}")
    print("CHECK DONE")


main()
