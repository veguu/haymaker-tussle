"""Keys on the R6 rig, the Blender 5.2 way (actions hold slots; F-curves live in a slot's channelbag).

A clip's settings ride on its action as custom properties:
  ht_loop (bool), ht_priority (str), ht_strike_frame (float, optional), ht_start, ht_end (frames).
"""
import math

import bpy
from bpy_extras import anim_utils

CHANNELS = (("rotation_euler", 3), ("location", 3))


def new_clip(rig, name):
    """A fresh action with one slot for the rig, assigned. Returns (action, channelbag)."""
    action = bpy.data.actions.new(name)
    slot = action.slots.new(id_type="OBJECT", name=rig.name)
    rig.animation_data_create()
    rig.animation_data.action = action
    rig.animation_data.action_slot = slot
    return action, anim_utils.action_ensure_channelbag_for_slot(action, slot)


def channelbag_of(rig):
    data = rig.animation_data
    if not data or not data.action or not data.action_slot:
        return None
    return anim_utils.action_get_channelbag_for_slot(data.action, data.action_slot)


def curve(bag, bone, prop, index):
    path = f'pose.bones["{bone}"].{prop}'
    found = bag.fcurves.find(path, index=index)
    return found or bag.fcurves.new(path, index=index, group_name=bone)


def key_pose(bag, frame, pose, interpolation="BEZIER"):
    """Keys every joint in `pose` ({joint: (rx, ry, rz, px, py, pz)}, degrees and studs) at `frame`."""
    for bone, values in pose.items():
        for i in range(3):
            point = curve(bag, bone, "rotation_euler", i).keyframe_points.insert(frame, math.radians(values[i]))
            point.interpolation = interpolation
        for i in range(3):
            point = curve(bag, bone, "location", i).keyframe_points.insert(frame, values[3 + i])
            point.interpolation = interpolation


def key_values(rig, bag, frame, bone, values, interpolation="BEZIER", memory=None):
    """Keys one joint from clip values (rx, ry, rz, px, py, pz), in whichever rotation mode the bone
    uses. `memory` (a dict kept by the caller) carries the last rotation keyed per bone, so the new
    key is written as the nearest equivalent: Euler numbers never jump a whole turn, and quaternions
    stay in one hemisphere. Without that, the curve between two keys takes the long way round."""
    from mathutils import Euler

    memory = memory if memory is not None else {}
    pb = rig.pose.bones[bone]
    rotation = Euler([math.radians(v) for v in values[:3]], "ZYX").to_matrix()
    last = memory.get(bone)
    if pb.rotation_mode == "QUATERNION":
        quat = rotation.to_quaternion()
        if last is not None and last.dot(quat) < 0:
            quat.negate()
        memory[bone] = quat.copy()
        channel, numbers = "rotation_quaternion", list(quat)
    else:
        if last is not None:
            euler = rotation.to_euler(pb.rotation_mode, last)
        else:
            euler = rotation.to_euler(pb.rotation_mode)
        memory[bone] = euler.copy()
        channel, numbers = "rotation_euler", list(euler)
    for i, number in enumerate(numbers):
        curve(bag, bone, channel, i).keyframe_points.insert(frame, number).interpolation = interpolation
    for i in range(3):
        curve(bag, bone, "location", i).keyframe_points.insert(frame, values[3 + i]).interpolation = interpolation
    return memory


def set_interpolation(bag, interpolation, handles=None):
    for fc in bag.fcurves:
        for point in fc.keyframe_points:
            point.interpolation = interpolation
            if handles:
                point.handle_left_type = handles
                point.handle_right_type = handles
        fc.update()


def keyed_bones(bag):
    """Bones that have any F-curve, in rig order: only these are exported (the rest stay free for
    whatever plays underneath, the way Guard holds only the arms)."""
    names = []
    for fc in bag.fcurves:
        if fc.data_path.startswith('pose.bones["'):
            name = fc.data_path.split('"')[1]
            if name not in names:
                names.append(name)
    return names
