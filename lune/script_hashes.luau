--!nocheck
-- Checksums of every Rojo-managed script ON DISK, keyed by its place path (from sourcemap.json), to compare
-- with the same checksums taken in Studio (the place can be ahead of Git: memory "haymaker-place-ahead-of-git").
--   rojo sourcemap default.project.json -o sourcemap.json ; lune run lune/script_hashes
-- Output: "<FullName>\t<fnv1a32 of the source, CR removed>\t<length>\t<file>" per line.
-- The SAME hash in Luau for Studio: see HASH_LUAU at the bottom of the output with --studio.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local function fnv(s: string): number
	-- Rojo drops the file's trailing newline in the place: ignore trailing newlines on both sides.
	s = s:gsub("\r", ""):gsub("\n+$", "")
	local h = 2166136261
	for i = 1, #s do
		local c = string.byte(s, i)
		if c ~= 13 then
			h = bit32.bxor(h, c)
			h = ((h % 256) * 16777216 + h * 403) % 4294967296
		end
	end
	return h
end

local map = serde.decode("json", fs.readFile("sourcemap.json"))
local out = {}
local function walk(node, path)
	local full = if path then path .. "." .. node.name else node.name
	if node.filePaths then
		for _, f in node.filePaths do
			if f:match("%.luau?$") then
				local src = fs.readFile(f)
				table.insert(out, string.format("%s\t%d\t%d\t%s", full, fnv(src), #(src:gsub("\r", "")), f))
			end
		end
	end
	for _, child in node.children or {} do
		walk(child, full)
	end
end
for _, child in map.children or {} do
	walk(child, nil)
end
table.sort(out)
print(table.concat(out, "\n"))
