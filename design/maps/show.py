"""Opens a built arena in Blender's window for looking around: rendered shading, through the gameplay
camera, with the Export collection selected-free. Run with the GUI (not -b):

    blender <map>.blend -P show.py

Middle mouse to orbit (that leaves the camera view), numpad 0 to go back to the gameplay camera, and the
other cameras (Edge, Recovery, Overview) are in the Setup collection: select one and Ctrl+numpad 0.
"""
import bpy


def setup():
    scene = bpy.context.scene
    cam = bpy.data.objects.get("Gameplay")
    if cam:
        scene.camera = cam
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type != "VIEW_3D":
                continue
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    space.shading.type = "RENDERED"
                    space.clip_end = 20000
                    space.overlay.show_overlays = False
                    space.region_3d.view_perspective = "CAMERA"
    return None


bpy.app.timers.register(setup, first_interval=1.0)
