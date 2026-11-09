"""Poses clips on a contact sheet in Blender by frame, takes window screenshots to PNG files."""
import base64, json, os, subprocess, sys
EXE = r"C:\Users\dumpl\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\Claude Extensions\ant.dir.gh.blender.blender-mcp\.venv\Scripts\blender-mcp.exe"
SP = os.path.dirname(os.path.abspath(__file__))
p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
def send(o): p.stdin.write(json.dumps(o) + "\n"); p.stdin.flush()
n = [1]
def rpc(m, params):
    n[0] += 1; i = n[0]
    send({"jsonrpc": "2.0", "id": i, "method": m, "params": params})
    while True:
        line = p.stdout.readline()
        if not line: sys.exit("server closed")
        o = json.loads(line)
        if o.get("id") == i: return o
rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "probe", "version": "1"}})
send({"jsonrpc": "2.0", "method": "notifications/initialized"})
def code(c):
    r = rpc("tools/call", {"name": "execute_blender_code", "arguments": {"code": c}})
    return json.dumps(r.get("result", r))[:600]
print(code(open(os.path.join(SP, "sheet.py"), encoding="utf-8").read()))
import time; time.sleep(1.5)
r = rpc("tools/call", {"name": "get_screenshot_of_area_as_image", "arguments": {"area_type": "VIEW_3D"}}) if False else rpc("tools/call", {"name": "get_screenshot_of_window_as_image", "arguments": {"size_limit_in_bytes": 900000}})
saved = False
for c in r.get("result", {}).get("content", []):
    if c.get("type") == "image":
        open(sys.argv[1], "wb").write(base64.b64decode(c["data"])); saved = True
print("saved", saved, str(r)[:200] if not saved else "")
p.terminate()
