-- roblox-sfx: build the verified sounds straight into this place.
-- Generated. Creates SoundService/SFX/<role>, ready to hear immediately.
local SoundService = game:GetService("SoundService")

local root = SoundService:FindFirstChild("SFX")
if not root then
	root = Instance.new("Folder")
	root.Name = "SFX"
	root.Parent = SoundService
end
root:ClearAllChildren()

local BANK = {
	{ role = "bump", id = 9119323910, volume = 0.4, looped = false },
	{ role = "dash", id = 120777847710409, volume = 0.8, looped = false },
	{ role = "launch", id = 80454497832356, volume = 0.6, looped = false },
	{ role = "punch_hit", id = 82235785832022, volume = 0.7, looped = false },
	{ role = "punch_swing", id = 132239386768492, volume = 0.5, looped = false },
}

for _, e in ipairs(BANK) do
	local s = Instance.new("Sound")
	s.Name = e.role
	s.SoundId = "rbxassetid://" .. tostring(e.id)
	s.Volume = e.volume
	s.Looped = e.looped
	s.Parent = root
end

return string.format("installed %d sounds under SoundService.SFX", #BANK)
