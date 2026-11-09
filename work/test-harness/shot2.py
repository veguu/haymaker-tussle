import base64, json, os, subprocess, sys, time
EXE = r"C:\Users\dumpl\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\Claude Extensions\ant.dir.gh.blender.blender-mcp\.venv\Scripts\blender-mcp.exe"
SP = os.path.dirname(os.path.abspath(__file__))
p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
def send(o): p.stdin.write(json.dumps(o) + "\n"); p.stdin.flush()
n=[1]
def rpc(m, params):
    n[0]+=1; i=n[0]; send({"jsonrpc":"2.0","id":i,"method":m,"params":params})
    while True:
        o=json.loads(p.stdout.readline())
        if o.get("id")==i: return o
rpc("initialize",{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1"}})
send({"jsonrpc":"2.0","method":"notifications/initialized"})
views=[("a",-1.0,36),("b",-22.0,36)]
for name,z,d in views:
    code=f'''
import bpy, math
from mathutils import Matrix, Quaternion
win=bpy.context.window_manager.windows[0]
areas=[a for a in win.screen.areas if a.type=="VIEW_3D"]
a=max(areas,key=lambda x:x.width)
r=a.spaces.active.region_3d; r.view_perspective="ORTHO"; r.view_location=(0,0,{z}); r.view_distance={d}
tilt=Matrix.Rotation(math.radians(84),4,"X").to_quaternion()
r.view_rotation=Quaternion((0,0,1),math.radians(180-30))@tilt
a.tag_redraw()
'''
    rpc("tools/call",{"name":"execute_blender_code","arguments":{"code":code}})
    time.sleep(1.2)
    r=rpc("tools/call",{"name":"get_screenshot_of_window_as_image","arguments":{"size_limit_in_bytes":1200000}})
    for c in r.get("result",{}).get("content",[]):
        if c.get("type")=="image":
            open(os.path.join(SP,f"sheet_{name}.png"),"wb").write(base64.b64decode(c["data"]))
p.terminate()
print("done")
