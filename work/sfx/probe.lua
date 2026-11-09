-- roblox-sfx: create every candidate Sound. Generated, do not hand-edit.
local SoundService = game:GetService("SoundService")

local root = SoundService:FindFirstChild("SFXProbe")
if not root then
	root = Instance.new("Folder")
	root.Name = "SFXProbe"
	root.Parent = SoundService
end
root:ClearAllChildren()

local SPEC = {
	{ role = "punch_swing", ids = { 132239386768492, 116994835209534, 133771349457972, 113846547547387, 137543397910261, 89276754970467 } },
	{ role = "punch_hit", ids = { 82235785832022, 123732376743848, 98168954865521, 72849255100295, 88580842034482, 126511693211043 } },
	{ role = "bump", ids = { 9120395943, 9119323910, 9120395234, 9120394873, 9120395560, 9120395276 } },
	{ role = "launch", ids = { 80454497832356, 139384716554132, 117058770323453, 87045152842770, 124047596872022, 74429963364192 } },
	{ role = "dash", ids = { 98988586485880, 9113069670, 99681416045662, 2741718865, 130945366711915, 105585374282271 } },
}

local made = 0
for _, role in ipairs(SPEC) do
	local folder = Instance.new("Folder")
	folder.Name = role.role
	folder.Parent = root
	for _, id in ipairs(role.ids) do
		local s = Instance.new("Sound")
		s.Name = tostring(id)
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.Volume = 0
		s.Parent = folder
		made += 1
	end
end

return string.format("created %d sounds across %d roles", made, #SPEC)
