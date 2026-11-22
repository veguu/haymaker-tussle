"""The R6 rig for hand-keyed clips, and the maths that ties it to the game's Motor6Ds.

Imported by build_rig.py, export_hand_clips.py and the check scripts (all run inside Blender).

THE CONVENTION (proved by build_rig.py's round trip):
  Roblox:  Part1 = Part0 * C0 * Transform * C1^-1
  Every bone's REST frame is its joint frame at rest (Part0 * C0), moved into Blender's axes by M
  (Roblox (x, y, z) -> Blender (-x, z, y): the character faces -Y, Z is up). A child's rest frame
  relative to its parent's is then C1_parent^-1 * C0_child, a constant, so the bone's local pose
  (matrix_basis) IS the Motor6D Transform, with no axis conversion at all.
  Channels: location = (px, py, pz) studs; rotation_euler in mode 'ZYX' = (rx, ry, rz), because
  Blender's 'ZYX' builds Rx * Ry * Rz, the same product as CFrame.Angles(rx, ry, rz).
"""
import importlib.util
import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ANIMS = os.path.dirname(HERE)

_spec = importlib.util.spec_from_file_location("ht_build_clips", os.path.join(ANIMS, "build_clips.py"))
build_clips = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(build_clips)

JOINTS = build_clips.JOINTS
SIZES = build_clips.SIZES
LIMBS = build_clips.LIMBS
BONES = ("Torso",) + tuple(LIMBS)
FPS = 60
RIG_NAME = "R6"
BODY_NAME = "R6_Body"
ROOT_HEIGHT = 3.0  # the root is 3 studs above the floor the feet rest on

# Roblox axes to Blender axes: (x, y, z) -> (-x, z, y). A proper rotation (determinant +1).
M = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

COLOURS = {
    "Torso": (0.30, 0.32, 0.36, 1),
    "Head": (0.85, 0.72, 0.55, 1),
    "Right Arm": (0.95, 0.45, 0.10, 1),  # orange: the right side
    "Left Arm": (0.15, 0.45, 0.95, 1),  # blue: the left side
    "Right Leg": (0.60, 0.30, 0.10, 1),
    "Left Leg": (0.10, 0.28, 0.60, 1),
    "Face": (0.05, 0.05, 0.05, 1),
}


def frame4(rows, position):
    """A build_clips transform (rotation rows, position) as a 4x4, still in Roblox axes."""
    m = Matrix(rows).to_4x4()
    m.translation = Vector(position)
    return m


def joint_frames():
    """Each joint's C0 and C1 as 4x4 matrices in Roblox axes."""
    return {name: (frame4(c0r, c0p), frame4(c1r, c1p)) for name, (c0r, c0p, c1r, c1p) in JOINTS.items()}


def rest_frames():
    """Each bone's rest frame in ARMATURE space (Blender axes): M * Part0_rest * C0."""
    frames = joint_frames()
    c0, c1 = frames["Torso"]
    rest = {"Torso": M @ c0}
    torso_part = c0 @ c1.inverted()  # the torso part at rest, relative to the root
    for name in LIMBS:
        rest[name] = M @ torso_part @ frames[name][0]
    return rest


def build_rig(collection=None):
    """Makes the armature and one rigidly weighted body mesh. Returns (rig, body)."""
    collection = collection or bpy.context.scene.collection
    arm = bpy.data.armatures.new(RIG_NAME)
    rig = bpy.data.objects.new(RIG_NAME, arm)
    collection.objects.link(rig)
    rig.location = (0, 0, ROOT_HEIGHT)
    rig.show_in_front = True
    arm.display_type = "STICK"

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    rest = rest_frames()
    for name in BONES:
        eb = arm.edit_bones.new(name)
        eb.head = (0, 0, 0)
        eb.tail = (0, 0.4, 0)
        eb.matrix = rest[name]
        if name != "Torso":
            eb.parent = arm.edit_bones["Torso"]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "ZYX"

    # The body: one box per part, in armature space at rest (Part_rest = joint frame * C1^-1).
    frames = joint_frames()
    verts, faces, groups, face_material = [], [], {}, []
    materials = []

    def material(key):
        mat = bpy.data.materials.get("R6_" + key) or bpy.data.materials.new("R6_" + key)
        mat.diffuse_color = COLOURS[key]
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = COLOURS[key]
            bsdf.inputs["Roughness"].default_value = 0.8
        if mat not in materials:
            materials.append(mat)
        return materials.index(mat)

    def box(part_frame, size, centre, bone, key):
        start = len(verts)
        sx, sy, sz = (s / 2 for s in size)
        for dx in (-1, 1):
            for dy in (-1, 1):
                for dz in (-1, 1):
                    local = Vector((centre[0] + dx * sx, centre[1] + dy * sy, centre[2] + dz * sz))
                    verts.append(part_frame @ local)
        quads = ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3))
        index = material(key)
        for quad in quads:
            faces.append(tuple(start + i for i in quad))
            face_material.append(index)
        groups.setdefault(bone, []).extend(range(start, start + 8))

    for name in BONES:
        part = rest[name] @ frames[name][1].inverted()  # armature space, Blender axes, Roblox-local part axes
        box(part, SIZES[name], (0, 0, 0), name, name)
        if name == "Head":
            # A dark visor on the face (Roblox front is -Z of the part), so stills show which way it looks.
            box(part, (1.2, 0.3, 0.1), (0, 0.1, -0.52), name, "Face")
        if name == "Torso":
            box(part, (0.6, 0.6, 0.1), (0, 0.4, -0.52), name, "Face")

    mesh = bpy.data.meshes.new(BODY_NAME)
    mesh.from_pydata(verts, [], faces)
    for mat in materials:
        mesh.materials.append(mat)
    for poly, index in zip(mesh.polygons, face_material):
        poly.material_index = index
    mesh.update()
    body = bpy.data.objects.new(BODY_NAME, mesh)
    collection.objects.link(body)
    body.parent = rig
    for bone, indices in groups.items():
        body.vertex_groups.new(name=bone).add(indices, 1.0, "REPLACE")
    modifier = body.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig
    # Outward normals whatever the winding came out as.
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.objects.active = rig
    return rig, body


def set_pose(rig, pose):
    """Puts clip values {joint: (rx, ry, rz, px, py, pz)} on the bones' channels (no keys)."""
    for name in BONES:
        pb = rig.pose.bones[name]
        values = pose.get(name, (0, 0, 0, 0, 0, 0))
        pb.rotation_euler = Euler([math.radians(v) for v in values[:3]], "ZYX")
        pb.location = Vector(values[3:6])


def local_transform(rig, name):
    """The EVALUATED Motor6D Transform of a joint right now (constraints and drivers included)."""
    pb = rig.pose.bones[name]
    bone = pb.bone
    if pb.parent is None:
        return bone.matrix_local.inverted() @ pb.matrix
    rel = pb.parent.bone.matrix_local.inverted() @ bone.matrix_local
    return (pb.parent.matrix @ rel).inverted() @ pb.matrix


def read_values(matrix, previous=None):
    """A Transform as clip values (rx, ry, rz degrees in CFrame.Angles order, px, py, pz studs).
    `previous` (rx, ry, rz in degrees) picks the Euler solution closest to the frame before."""
    rot = matrix.to_3x3().normalized()
    if previous is not None:
        euler = rot.to_euler("ZYX", Euler([math.radians(v) for v in previous], "ZYX"))
    else:
        euler = rot.to_euler("ZYX")
    position = matrix.translation
    return tuple(math.degrees(a) for a in euler) + (position.x, position.y, position.z)


def part_matrices(rig):
    """Each part's evaluated transform relative to the root, in ROBLOX axes (to compare with
    build_clips.part_transforms)."""
    frames = joint_frames()
    out = {}
    for name in BONES:
        joint = M.inverted() @ rig.pose.bones[name].matrix
        out[name] = joint @ frames[name][1].inverted()
    return out


def fist_world(rig, arm="Right Arm"):
    """The fist: the bottom-centre of the arm part (0, -1, 0 in the part), in Blender world space."""
    frames = joint_frames()
    part = rig.pose.bones[arm].matrix @ frames[arm][1].inverted()
    return rig.matrix_world @ (part @ Vector((0, -1, 0)))
