"""Shared pieces for the cutscene camera scenes (animations/camera). Run inside Blender.

Conventions (proved by build_scene.py):
  - Space: the cutscene's ANCHOR space, moved to Blender by M: Roblox (x, y, z) -> Blender (-x, z, y).
  - Time: 100 frames a second, FRAME = cutscene seconds x 100.
  - A Roblox camera and a Blender camera share their own axes (right +X, up +Y, looking down -Z), so a camera's
    world matrix is M x (the Roblox camera CFrame), nothing else.
  - FieldOfView is VERTICAL: sensor_fit 'VERTICAL', lens = (sensor_height / 2) / tan(fov / 2).
  - Roll: +roll is CFrame.Angles(0, 0, roll) after the look-at: the camera turns about its own +Z (which points back
    at the viewer), right toward up, so the PICTURE tips clockwise.
"""
import math
import os
import sys

import bpy
from bpy_extras import anim_utils
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hand"))
import r6_rig  # noqa: E402

M = r6_rig.M
FPS = 100
SENSOR = 24.0
FLOOR_Z = -3.0  # roots stand 3 studs over the floor; the anchor is at a standing root's height
RES = (1280, 720)


def frame_of(seconds):
    return int(round(seconds * FPS))


def cframe(numbers):
    """A Roblox CFrame's 12 components (x, y, z, then the rotation's rows) as a 4x4, in Roblox axes."""
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = numbers
    return Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))


def to_blender(point):
    return (M @ Vector(point).to_4d()).to_3d()


def to_roblox(point):
    return (M.inverted() @ Vector(point).to_4d()).to_3d()


def lens_of(fov):
    return (SENSOR / 2) / math.tan(math.radians(fov) / 2)


def fov_of(lens):
    return math.degrees(2 * math.atan((SENSOR / 2) / lens))


def camera_matrix(cam, look, roll):
    """The Blender world matrix of a camera at `cam` looking at `look` (anchor space, Roblox axes), rolled `roll`
    degrees the way the game rolls it."""
    cam, look = Vector(cam), Vector(look)
    forward = (look - cam).normalized()
    right = forward.cross(Vector((0, 1, 0))).normalized()
    up = right.cross(forward)
    r = math.radians(roll)
    right_r = right * math.cos(r) + up * math.sin(r)
    up_r = up * math.cos(r) - right * math.sin(r)
    back = -forward
    roblox = Matrix((
        (right_r.x, up_r.x, back.x, cam.x),
        (right_r.y, up_r.y, back.y, cam.y),
        (right_r.z, up_r.z, back.z, cam.z),
        (0, 0, 0, 1),
    ))
    return M @ roblox


def read_camera(cam_object):
    """A Blender camera right now -> (cam, look direction, fov, roll) in anchor space, Roblox axes, the game's terms.
    Roll is measured against the level camera with the same aim."""
    world = M.inverted() @ cam_object.matrix_world
    position = world.translation.copy()
    right_r = Vector((world[0][0], world[1][0], world[2][0]))
    up_r = Vector((world[0][1], world[1][1], world[2][1]))
    forward = -Vector((world[0][2], world[1][2], world[2][2]))
    right = forward.cross(Vector((0, 1, 0))).normalized()
    up = right.cross(forward)
    roll = math.degrees(math.atan2(right_r.dot(up), right_r.dot(right)))
    return position, forward.normalized(), fov_of(cam_object.data.lens), roll


def fcurves_of(owner):
    data = owner.animation_data
    if not data or not data.action or not data.action_slot:
        return []
    bag = anim_utils.action_get_channelbag_for_slot(data.action, data.action_slot)
    return list(bag.fcurves) if bag else []


def new_camera(scene, name):
    data = bpy.data.cameras.new(name)
    data.sensor_fit = "VERTICAL"
    data.sensor_height = SENSOR
    data.clip_start, data.clip_end = 0.1, 2000
    cam = bpy.data.objects.new(name, data)
    cam.rotation_mode = "QUATERNION"
    scene.collection.objects.link(cam)
    return cam


_last_quat = {}


def key_camera(cam_object, frame, cam, look, fov, roll, hold=False):
    """Keys a camera from the game's terms. hold=True: constant keys (a sampled track, cuts kept sharp)."""
    loc, quat, _ = camera_matrix(cam, look, roll).decompose()
    last = _last_quat.get(cam_object.name)
    if last is not None and last.dot(quat) < 0:
        quat.negate()
    _last_quat[cam_object.name] = quat.copy()
    cam_object.location, cam_object.rotation_quaternion = loc, quat
    cam_object.data.lens = lens_of(fov)
    cam_object.keyframe_insert("location", frame=frame)
    cam_object.keyframe_insert("rotation_quaternion", frame=frame)
    cam_object.data.keyframe_insert("lens", frame=frame)
    if hold:
        for owner in (cam_object, cam_object.data):
            for fc in fcurves_of(owner):
                for point in fc.keyframe_points:
                    if abs(point.co.x - frame) < 0.5:
                        point.interpolation = "CONSTANT"


def part_point(rig, part, world_point):
    """A world point in a rig part's own space (Roblox part axes)."""
    frames = r6_rig.joint_frames()
    part_matrix = rig.matrix_world @ rig.pose.bones[part].matrix @ frames[part][1].inverted()
    return (part_matrix.inverted() @ Vector(world_point).to_4d()).to_3d()


def setup_scene(scene):
    """Workbench, 16:9, a floor with stud lines at the anchor's floor height, a plain sky."""
    scene.render.fps = FPS
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = True
    scene.display.shading.show_shadows = False
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = RES
    scene.render.resolution_percentage = 100
    world = bpy.data.worlds.new("CameraWorld")
    world.color = (0.62, 0.72, 0.86)
    scene.world = world
    # The floor: a checker of 4-stud squares, so the ground's speed and the horizon read in every frame.
    verts, faces, mats = [], [], []
    size, half = 4, 26
    for i in range(-half, half):
        for j in range(-half, half):
            x0, y0 = i * size, j * size
            start = len(verts)
            verts += [(x0, y0, FLOOR_Z), (x0 + size, y0, FLOOR_Z), (x0 + size, y0 + size, FLOOR_Z), (x0, y0 + size, FLOOR_Z)]
            faces.append((start, start + 1, start + 2, start + 3))
            mats.append((i + j) % 2)
    mesh = bpy.data.meshes.new("Floor")
    mesh.from_pydata(verts, [], faces)
    for index, colour in enumerate(((0.47, 0.50, 0.46, 1), (0.40, 0.43, 0.40, 1))):
        mat = bpy.data.materials.new(f"Floor{index}")
        mat.diffuse_color = colour
        mesh.materials.append(mat)
    for poly, index in zip(mesh.polygons, mats):
        poly.material_index = index
    floor = bpy.data.objects.new("Floor", mesh)
    scene.collection.objects.link(floor)
    return floor
