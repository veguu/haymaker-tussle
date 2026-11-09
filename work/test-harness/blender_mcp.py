"""Calls Blender's MCP tools directly over stdio. usage: blender_mcp.py list | code <file.py>"""
import json, subprocess, sys
EXE = r"C:\Users\dumpl\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\Claude Extensions\ant.dir.gh.blender.blender-mcp\.venv\Scripts\blender-mcp.exe"
p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
def send(o): p.stdin.write(json.dumps(o) + "\n"); p.stdin.flush()
def rpc(i, m, params):
    send({"jsonrpc": "2.0", "id": i, "method": m, "params": params})
    while True:
        line = p.stdout.readline()
        if not line: sys.exit("server closed")
        o = json.loads(line)
        if o.get("id") == i: return o
rpc(1, "initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "probe", "version": "1"}})
send({"jsonrpc": "2.0", "method": "notifications/initialized"})
if sys.argv[1] == "list":
    r = rpc(2, "tools/list", {})
    for t in r["result"]["tools"]:
        print(t["name"], list(t["inputSchema"].get("properties", {}).keys()))
else:
    code = open(sys.argv[2], encoding="utf-8").read()
    r = rpc(2, "tools/call", {"name": "execute_blender_code", "arguments": {"code": code}})
    print(json.dumps(r.get("result", r))[:3000])
p.terminate()
