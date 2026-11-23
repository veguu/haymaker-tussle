"""Chooses each crystal's turn about its own axis (yaw) on purpose, instead of the game's math.random(0, 359):
the yaw that shows the most ice to the game camera (flat blades face-on, not edge-on), among the yaws that keep
the piece inside today's limits (no further ahead than 18.3 studs, no wider than 16.4 to a side, no nearer the
camera than 13.2, nothing behind the thrower).
  blender -b --factory-startup --python-exit-code 1 --python fit_yaws.py
Prints the table with its yaws, to paste into ice_layout.py (and later FrostFx.GLACIER).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ice_pieces as P  # noqa: E402
import ice_scene as S  # noqa: E402
from ice_layout import FLOWER, FLOWER_CENTRE  # noqa: E402

AHEAD_MAX, SIDE_MAX, CAMERA_MIN, BEHIND_MAX = 18.3, 16.4, 13.2, 0.0
FLAT_MAX = 70.0   # no side blade may lie flatter than this (or than its piece's own lean, if that is more):
#                   the owner spotted one lying on the floor as a thin sliver, most of it under the ground
CAM = Vector((0, 12.07, 7.74))

S.new_scene()
kit = P.build_kit()
blades = P.blade_list(kit)
feet_r = S.M4 @ Vector((0, 0, 0))
way, right = Vector((0, 0, -1)), Vector((1, 0, 0))
middle = feet_r + way * FLOWER_CENTRE
table, notes = [], []
for index, spec in enumerate(FLOWER, start=1):
    r, a, height, lean, wave, name, tone = spec[:7]
    mesh = kit[name]
    spot = feet_r + right * r + way * a
    best = None
    for yaw in range(0, 360, 15):
        obj = S.place(mesh, S.rooted(spot, spot - middle, lean, yaw), height, name="_fit")
        world = [obj.matrix_world @ v.co for v in mesh.vertices]
        ahead = max(-w.y for w in world)
        behind = max(w.y for w in world)
        side = max(abs(w.x) for w in world)
        near = min((w - CAM).length for w in world)
        view = (CAM - (obj.matrix_world @ Vector((0, 0, 0.5)))).normalized()
        turn = obj.matrix_world.to_3x3()
        shown = 0.0
        for polygon in mesh.polygons:
            normal = (turn @ polygon.normal)
            shown += 0.5 * abs(normal.normalized().dot(view)) * polygon.area * (height ** 2)
        upright = turn.normalized()
        flattest = max(math.degrees(math.acos(max(-1, min(1, (upright @ axis).normalized().z)))) for axis, *_rest in blades.get(name, [(Vector((0, 0, 1)),)]))
        flat_limit = max(FLAT_MAX, lean + 2)
        poking = S.slivers(mesh, obj.matrix_world) + S.detached(mesh, obj.matrix_world)
        ok = ahead <= AHEAD_MAX and side <= SIDE_MAX and near >= CAMERA_MIN and behind <= BEHIND_MAX and flattest <= flat_limit and poking == 0
        over = (max(0, ahead - AHEAD_MAX) + max(0, side - SIDE_MAX) + max(0, CAMERA_MIN - near) + max(0, behind - BEHIND_MAX)
                + max(0, flattest - flat_limit) / 5 + poking * 3)
        key = (ok, -over if not ok else shown)
        if best is None or key > best[0]:
            best = (key, yaw, round(ahead, 1), round(side, 1), round(near, 1), round(shown, 1), ok, round(flattest, 1), poking)
        bpy.data.objects.remove(obj)
    _key, yaw, ahead, side, near, shown, ok, flattest, poking = best
    table.append((r, a, height, lean, wave, name, tone, yaw))
    notes.append({"row": index, "piece": name, "yaw": yaw, "ahead": ahead, "side": side, "to_camera": near, "shown": shown, "flattest_blade": flattest, "slivers": poking, "inside_limits": ok})
print("RESULT_JSON=" + json.dumps({"table": table, "notes": notes}))
