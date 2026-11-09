import bpy, importlib.util, math, os
from mathutils import Matrix, Quaternion
PROJECT_ANIMS = r"C:\Users\dumpl\Documents\LihFolk\LihFolk Vault V2\LihFolk Vault V2\Haymaker Tussle\Project\animations"
spec = importlib.util.spec_from_file_location("ht_build_clips", os.path.join(PROJECT_ANIMS, "build_clips.py"))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
CLIPS = m.bake_all()
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
def sample(clip, time):
    frames = clip["frames"]
    time = min(time, clip["seconds"])
    for a, b in zip(frames, frames[1:]):
        if time <= b["t"]:
            s = b["t"] - a["t"]; k = (time - a["t"]) / s if s > 0 else 0
            return {j: tuple(v[i] + (b["pose"][j][i] - v[i]) * k for i in range(6)) for j, v in a["pose"].items()}
    return dict(frames[-1]["pose"])
SHEET = [
 ("KickLeap", 0.0), ("KickLeap", 0.05), ("KickLeap", 0.117), ("KickLeap", 0.27), ("KickLeap", 0.6), ("KickAim", 0.1), ("KickSpin", 0.0),
 ("KickSpin", 0.1), ("KickSpin", 0.17), ("KickSpin", 0.22), ("KickSpin", 0.28), ("KickDown", 0.0), ("KickDown", 0.13), ("KickDown", 0.3),
 ("HitFlinch", 0.0), ("HitFlinch", 0.07), ("HitFlinchHeavy", 0.0), ("HitFlinchHeavy", 0.07), ("HitFlinchBack", 0.0), ("HitSkid", 0.05), ("AirTumble", 0.2),
]
NAME = "HT_Sheet"
old = bpy.data.scenes.get(NAME)
if old:
    for o in list(old.objects): bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(old)
scene = bpy.data.scenes.new(NAME)
COL = {"Torso": (0.13,0.15,0.2,1),"Head": (0.95,0.8,0.55,1),"Right Arm": (0.85,0.25,0.2,1),"Left Arm": (0.2,0.45,0.85,1),"Right Leg": (0.55,0.57,0.62,1),"Left Leg": (0.38,0.4,0.45,1)}
def box(name,size):
    x,y,z=size[0]/2,size[2]/2,size[1]/2
    v=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    f=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(name); me.from_pydata(v,[],f); me.update(); return me
def mat(n,c):
    x=bpy.data.materials.get("HTS_"+n) or bpy.data.materials.new("HTS_"+n); x.diffuse_color=c; return x
COLS=7; SX=7.2; SZ=10.5
for i,(clip,t) in enumerate(SHEET):
    cx=(i%COLS-(COLS-1)/2)*SX; cz=-(i//COLS)*SZ
    pose=sample(CLIPS[clip],t)
    full={k:pose.get(k) for k in m.SIZES}
    # fill legs/torso from stance for partial clips
    stance=sample(CLIPS["Sprint"],0.0) if clip.endswith("Run") else sample(CLIPS["Stance"],0.0)
    for k in full:
        if full[k] is None: full[k]=stance[k]
    tr=m.part_transforms(full)
    for name,(rot,pos) in tr.items():
        o=bpy.data.objects.new(f"{i} {name}",box("HTS_"+name,m.SIZES[name]))
        o.data.materials.append(mat(name,COL[name])); o.rotation_mode="QUATERNION"; scene.collection.objects.link(o)
        o.location=(cx+pos[0],-pos[2],cz+3+pos[1]); o.rotation_quaternion=(P@Matrix(rot)@P.transposed()).to_quaternion()
    w=bpy.data.curves.new(f"{i} l","FONT"); w.body=f"{clip} {t}"; w.size=0.55; w.align_x="CENTER"
    tx=bpy.data.objects.new(f"{i} l",w); tx.location=(cx,0,cz+7.3); tx.rotation_euler=(math.pi/2,0,math.pi); scene.collection.objects.link(tx)
    g=bpy.data.objects.new(f"{i} g",box("HTS_g",(6,0.02,4))); g.location=(cx,0,cz); scene.collection.objects.link(g)
win=bpy.context.window_manager.windows[0]; win.scene=scene
for a in win.screen.areas:
    if a.type=="VIEW_3D":
        r=a.spaces.active.region_3d; r.view_perspective="ORTHO"; r.view_location=(0,0,-5.5); r.view_distance=30
        tilt=Matrix.Rotation(math.radians(82),4,"X").to_quaternion()
        r.view_rotation=Quaternion((0,0,1),math.radians(180-28))@tilt
        s=a.spaces.active; s.shading.type="SOLID"; s.shading.color_type="MATERIAL"; s.overlay.show_overlays=False
print("ok")
