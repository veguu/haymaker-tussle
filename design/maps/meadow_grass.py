"""Widely separated meadow clumps for Gnomon. Each clump has a ground-level origin."""
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

import common as C
import detail as D

COUNT = 132
SPACING = 23.0


def placements():
    rng = random.Random(7601)
    points = []
    for attempt in range(30000):
        x = rng.uniform(-C.A + 10, C.A - 10)
        y = rng.uniform(-C.B + 10, C.B - 10)
        if (x / (C.A - 10)) ** 2 + (y / (C.B - 10)) ** 2 >= 1:
            continue
        if any((x - p['x']) ** 2 + (y - p['y']) ** 2 < SPACING ** 2 for p in points):
            continue
        points.append(dict(x=x, y=y, turn=rng.uniform(0, math.tau), scale=rng.uniform(0.82, 1.13), variant=len(points) % 3))
        if len(points) == COUNT:
            return points
    raise RuntimeError('Could not place the requested sparse clumps')


def make_template(index, material):
    rng = random.Random(220 + index)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new('UVMap')
    blades = 9 + index * 2
    for i in range(blades):
        angle = rng.uniform(0, math.tau)
        radius = rng.uniform(0.06, 0.42)
        outward = Vector((math.cos(angle), math.sin(angle), 0))
        base = outward * radius + Vector((0, 0, -0.025))
        height = rng.uniform(0.85, 1.62) * (1 + index * 0.05)
        direction = Vector((0, 0, 1)) + outward * rng.uniform(0.06, 0.22)
        D._blade(bm, uv, base, direction, height, rng.uniform(0.055, 0.09), outward,
                 rng.uniform(0.12, 0.3) * height, rng.uniform(0.12, 0.88))
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=3)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    obj = C.mesh_object(f'MeadowPrototype_{index}', bm, material, smooth=True)
    obj['no_shadow'] = True
    return obj


def build(tex_dir):
    original = D.GRASS_ROWS
    D.GRASS_ROWS = [((14, 95, 24), (31, 110, 15)), ((26, 140, 27), (65, 163, 23)),
                    ((63, 183, 34), (105, 198, 37)), ((117, 212, 53), (158, 221, 69))]
    mat = D.grass_texture(tex_dir, name='MeadowTuft_Palette')
    D.GRASS_ROWS = original
    templates = [make_template(i, mat) for i in range(3)]
    objects = []
    rows = placements()
    for i, p in enumerate(rows):
        obj = templates[p['variant']].copy()
        obj.data = obj.data.copy()
        obj.name = f'MeadowTuft_{i + 1:03d}'
        obj.data.name = obj.name
        C.collection('Export').objects.link(obj)
        obj.location = (p['x'], p['y'], 0)
        obj.rotation_euler.z = p['turn']
        obj.scale = (p['scale'],) * 3
        # Bake shape transform while retaining a bottom-centre pivot.
        from mathutils import Matrix
        matrix = Matrix.Rotation(p['turn'], 4, 'Z') @ Matrix.Scale(p['scale'], 4)
        obj.data.transform(matrix)
        obj.rotation_euler = (0, 0, 0)
        obj.scale = (1, 1, 1)
        obj['no_shadow'] = True
        objects.append(obj)
        p['name'] = obj.name
    for obj in templates:
        bpy.data.objects.remove(obj, do_unlink=True)
    with open(os.path.join(os.path.dirname(tex_dir), 'meadow_grass_layout.json'), 'w') as f:
        json.dump({'spacing': SPACING, 'count': len(rows), 'clumps': rows}, f, indent=2)
    print('SPARSE_GRASS', len(objects), 'minimum_spacing', SPACING)
    return objects
