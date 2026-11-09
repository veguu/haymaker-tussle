"""Exports every clip in Config/AnimClips to animations/export/<name>.rbxm, made by Studio itself.

Roblox warns that .rbxm files made outside Studio might not upload, so Studio builds and serialises each one. Studio
must be in Edit, with the current code pushed. Then animations/upload_clips.py uploads them.

    python animations/export_clips.py [clip names, or nothing for all]
"""

import base64
import os
import re
import subprocess
import sys

MCP = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "export")

ENCODE = r"""
local RS = game:GetService("ReplicatedStorage")
local clips = require(RS.Shared.Config.AnimClips)
local AnimSequence = require(RS.Shared.AnimSequence)
local NAME = "%s"
if NAME == "" then
	local names = {}
	for name in clips do table.insert(names, name) end
	table.sort(names)
	return "NAMES:" .. table.concat(names, ",")
end
local data = game:GetService("SerializationService"):SerializeInstancesAsync({ AnimSequence.build(NAME, clips[NAME]) })
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local parts = {}
local size = buffer.len(data)
for i = 0, size - 1, 3 do
	local a = buffer.readu8(data, i)
	local b = if i + 1 < size then buffer.readu8(data, i + 1) else 0
	local c = if i + 2 < size then buffer.readu8(data, i + 2) else 0
	local n = a * 65536 + b * 256 + c
	local one = bit32.extract(n, 18, 6) + 1
	local two = bit32.extract(n, 12, 6) + 1
	local three = bit32.extract(n, 6, 6) + 1
	local four = bit32.extract(n, 0, 6) + 1
	parts[#parts + 1] = alphabet:sub(one, one) .. alphabet:sub(two, two)
		.. (if i + 1 < size then alphabet:sub(three, three) else "=")
		.. (if i + 2 < size then alphabet:sub(four, four) else "=")
end
return "DATA:" .. table.concat(parts)
"""


def luau(code):
    done = subprocess.run([sys.executable, MCP, "luau", "--dm", "Edit", "--code", code], capture_output=True, text=True)
    return done.stdout + done.stderr


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:]
    if not names:
        found = re.search(r"NAMES:([\w,]+)", luau(ENCODE % ""))
        if not found:
            sys.exit("Couldn't list the clips. Is Studio in Edit, with the code pushed?")
        names = found.group(1).split(",")
    for name in names:
        result = luau(ENCODE % name)
        found = re.search(r"DATA:([A-Za-z0-9+/=]+)", result)
        if not found:
            sys.exit(f"{name} failed: {result[:300]}")
        data = base64.b64decode(found.group(1))
        if not data.startswith(b"<roblox!"):
            sys.exit(f"{name} isn't a binary Roblox file")
        with open(os.path.join(OUT, name + ".rbxm"), "wb") as file:
            file.write(data)
        print(f"{name}.rbxm {len(data) // 1024} KB")
    print(f"{len(names)} clips exported to {OUT}")


if __name__ == "__main__":
    main()
