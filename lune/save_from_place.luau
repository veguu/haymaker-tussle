--!nocheck
-- Write scripts dumped from the place (execute_luau results saved under tool-results, blocks
-- "@@@BEGIN <FullName>\n<source>\n@@@END") into src, at their Rojo paths. For saving a teammate's place-only
-- work into Git (memory "haymaker-place-ahead-of-git").
--   lune run lune/save_from_place <dump1> [dump2 ...]
local fs = require("@lune/fs")
local process = require("@lune/process")

local function pathOf(full: string): string?
	if full == "ServerScriptService.Server" then
		return "src/server/init.server.luau"
	elseif full == "StarterPlayer.StarterPlayerScripts.Client" then
		return "src/client/init.client.luau"
	end
	local rest = full:match("^ReplicatedStorage%.Shared%.(.+)$")
	if rest then
		return "src/shared/" .. rest:gsub("%.", "/") .. ".luau"
	end
	rest = full:match("^StarterPlayer%.StarterPlayerScripts%.Client%.(.+)$")
	if rest then
		return "src/client/" .. rest:gsub("%.", "/") .. ".luau"
	end
	rest = full:match("^ServerScriptService%.Server%.(.+)$")
	if rest then
		return "src/server/" .. rest:gsub("%.", "/") .. ".luau"
	end
	return nil
end

for _, dump in process.args do
	local text = fs.readFile(dump):gsub("\r", "")
	for full, src in text:gmatch("@@@BEGIN ([^\n]+)\n(.-)\n@@@END\n") do
		local path = pathOf(full)
		if not path then
			print("SKIP (no path rule) " .. full)
		else
			local existed = fs.isFile(path)
			fs.writeFile(path, src:gsub("\n+$", "") .. "\n")
			print(string.format("%s %s (%d chars)", if existed then "updated" else "NEW    ", path, #src))
		end
	end
end
