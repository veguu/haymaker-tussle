"""Check renders for hand-keyed clips: three fixed views and contact sheets. Run inside Blender.

Views (the character stands at the origin on the floor, facing -Y):
  front : orthographic, from in front of the character
  side  : orthographic, from the character's RIGHT (the orange arm is the near one)
  game  : perspective, behind and above like the game's follow camera (70 degrees)
"""
import math
import os

import bpy
import numpy as np
from mathutils import Vector

VIEWS = {
    # name: (location, look at, orthographic scale or None for perspective)
    "front": ((0, -20, 3.4), (0, 0, 3.4), 9.5),
    "side": ((-20, -0.6, 3.4), (0, -0.6, 3.4), 9.5),
    # The game's camera: straight behind (ShiftLock.CameraOffsetX is 0), Roblox's default 12.5 studs from the head,
    # looking about 15 degrees down, 70 degrees. (The first jab used a camera off to the left, which was wrong.)
    "game": ((0, 12.07, 7.74), (0, 0, 4.5), None),
}
CELL = (300, 380)


def setup(scene):
    """Workbench, flat studio light, a floor, the three cameras. Returns {view: camera}."""
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = True
    scene.display.shading.show_shadows = True
    scene.display.shading.shadow_intensity = 0.35
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = CELL
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("HandWorld")
    world.color = (0.80, 0.82, 0.86)
    scene.world = world

    floor_mesh = bpy.data.meshes.new("Floor")
    floor_mesh.from_pydata([(-9, -9, 0), (9, -9, 0), (9, 9, 0), (-9, 9, 0)], [], [(0, 1, 2, 3)])
    floor = bpy.data.objects.new("Floor", floor_mesh)
    mat = bpy.data.materials.new("Floor")
    mat.diffuse_color = (0.62, 0.64, 0.68, 1)
    floor_mesh.materials.append(mat)
    scene.collection.objects.link(floor)

    cameras = {}
    for name, (location, target, ortho) in VIEWS.items():
        data = bpy.data.cameras.new("Cam_" + name)
        if ortho:
            data.type = "ORTHO"
            data.ortho_scale = ortho
        else:
            data.sensor_fit = "VERTICAL"
            data.angle = math.radians(70)
        cam = bpy.data.objects.new("Cam_" + name, data)
        cam.location = location
        direction = Vector(target) - Vector(location)
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(cam)
        cameras[name] = cam
    stamp = scene.render
    stamp.use_stamp = True
    for flag in ("date", "time", "render_time", "frame", "frame_range", "memory", "hostname", "camera", "lens",
                 "scene", "marker", "filename", "sequencer_strip"):
        if hasattr(stamp, "use_stamp_" + flag):
            setattr(stamp, "use_stamp_" + flag, False)
    stamp.use_stamp_note = True
    stamp.use_stamp_labels = False
    stamp.stamp_font_size = 22
    stamp.stamp_foreground = (0.05, 0.05, 0.05, 1)
    stamp.stamp_background = (1, 1, 1, 0.75)
    return cameras


def render_cell(scene, camera, frame, label, path):
    scene.camera = camera
    scene.frame_set(frame)
    scene.render.stamp_note_text = label
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def _load(path):
    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)


def sheet(rows, path):
    """rows: lists of cell image paths (top row first). Writes one PNG with the cells side by side."""
    cells = [[_load(p) for p in row] for row in rows]
    height, width = cells[0][0].shape[:2]
    columns = max(len(row) for row in cells)
    out = np.ones((height * len(cells), width * columns, 4), dtype=np.float32)
    for r, row in enumerate(cells):
        for c, cell in enumerate(row):
            y0 = (len(cells) - 1 - r) * height  # pixel rows run bottom-up
            out[y0 : y0 + height, c * width : (c + 1) * width] = cell
    image = bpy.data.images.new("sheet", width * columns, height * len(cells), alpha=False)
    image.pixels.foreach_set(out.ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    return path


def contact_sheet(scene, cameras, frames, labels, folder, name, views=("front", "side", "game")):
    """One row per view, one column per frame. Returns the sheet's path."""
    os.makedirs(folder, exist_ok=True)
    rows = []
    for view in views:
        row = []
        for frame, label in zip(frames, labels):
            path = os.path.join(folder, f"_{name}_{view}_{frame:03d}.png")
            render_cell(scene, cameras[view], frame, f"{view}  {label}", path)
            row.append(path)
        rows.append(row)
    out = sheet(rows, os.path.join(folder, name + ".png"))
    for row in rows:
        for path in row:
            os.remove(path)
    return out


def render_mp4(cam, path, frame_start, frame_end, fps=60, res=(960, 540), engine="BLENDER_WORKBENCH"):
    """Render a frame range from one camera to an H.264 MP4. fps=15 on a 60 fps clip = quarter speed.
    (From the vault's Blender Mastery 1, section 5.) Every render setting is put back afterwards."""
    sc, r = bpy.context.scene, bpy.context.scene.render
    im = r.image_settings
    saved = (sc.camera, r.engine, r.resolution_x, r.resolution_y, r.resolution_percentage, r.fps, r.fps_base,
             sc.frame_start, sc.frame_end, r.filepath, im.media_type, im.file_format, r.use_stamp)
    sc.camera, r.engine = cam, engine
    r.resolution_x, r.resolution_y, r.resolution_percentage = res[0], res[1], 100
    r.fps, r.fps_base = fps, 1.0
    sc.frame_start, sc.frame_end = frame_start, frame_end
    r.use_stamp = False
    im.media_type = "VIDEO"  # 5.x: set before FFMPEG
    im.file_format = "FFMPEG"
    r.ffmpeg.format = "MPEG4"
    r.ffmpeg.codec = "H264"
    r.ffmpeg.constant_rate_factor = "HIGH"
    r.filepath = path
    bpy.ops.render.render(animation=True)
    (sc.camera, r.engine, r.resolution_x, r.resolution_y, r.resolution_percentage, r.fps, r.fps_base,
     sc.frame_start, sc.frame_end, r.filepath, im.media_type, im.file_format, r.use_stamp) = saved
    return path
