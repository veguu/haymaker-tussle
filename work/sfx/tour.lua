-- roblox-sfx: play the whole bank out loud, spaced by each sound's real length.
-- Generated. Studio plays Sounds in edit mode, so this needs no playtest.
-- Returns immediately and schedules the rest with task.delay, because
-- execute_luau drops its output if the script yields.
local SoundService = game:GetService("SoundService")

local root = SoundService:FindFirstChild("SFX")
if not root then
	return "run install.lua first"
end

local TOUR = {
	{ role = "bump", length = 0.708 },
	{ role = "dash", length = 0.866 },
	{ role = "launch", length = 1.522 },
	{ role = "punch_hit", length = 1.0 },
	{ role = "punch_swing", length = 0.416 },
}

local GAP = 0.4
local at = 0
for _, e in ipairs(TOUR) do
	local offset = at
	task.delay(offset, function()
		local s = root:FindFirstChild(e.role)
		if s and s:IsA("Sound") then
			s.TimePosition = 0
			s:Play()
			print(string.format("%5.1fs  %s", offset, e.role))
		end
	end)
	at += e.length + GAP
end

return string.format("touring %d sounds over %.1f seconds - listen", #TOUR, at)
