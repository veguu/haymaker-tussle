import bpy
s = bpy.data.scenes.get("HT_Sheet")
if s:
    for o in list(s.objects): bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(s)
path = r"C:\Users\dumpl\Documents\LihFolk\LihFolk Vault V2\LihFolk Vault V2\Haymaker Tussle\Project\animations\preview_in_blender.py"
g = {"__name__": "__main__", "__file__": path}
exec(compile(open(path, encoding="utf-8").read(), path, "exec"), g)
print(bpy.context.window_manager.windows[0].scene.name, len(bpy.data.scenes), repr(bpy.data.filepath))
