--!nocheck
-- Pull scripts out of a LOCAL copy of the place (File > Save to File As... in Studio) into a folder, without
-- going through Studio: for saving a teammate's place-only work into Git (memory "haymaker-place-ahead-of-git").
--   lune run lune/extract_scripts <place.rbxl> <out folder> <FullName> [FullName ...]
-- Writes <out>/<FullName>.luau for each script named (exact GetFullName()), and lists any it could not find.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath, outDir = process.args[1], process.args[2]
local game = roblox.deserializePlace(fs.readFile(placePath))
if not fs.isDir(outDir) then
	fs.writeDir(outDir)
end
local byName = {}
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		byName[d:GetFullName()] = d
	end
end
for i = 3, #process.args do
	local name = process.args[i]
	local s = byName[name]
	if s then
		local src = s.Source
		fs.writeFile(outDir .. "/" .. name .. ".luau", src)
		print(string.format("ok   %s (%d chars)", name, #src))
	else
		print("MISSING " .. name)
	end
end
