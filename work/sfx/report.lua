-- roblox-sfx: measure what actually loaded. Generated, do not hand-edit.
-- TimeLength is the ONLY trustworthy duration in this pipeline.
local root = game:GetService("SoundService"):FindFirstChild("SFXProbe")
if not root then
	return "NO PROBE - run probe.lua first"
end

local lines = {}
for _, folder in ipairs(root:GetChildren()) do
	for _, s in ipairs(folder:GetChildren()) do
		table.insert(lines, string.format(
			"%s,%s,%s,%.3f",
			folder.Name, s.Name, tostring(s.IsLoaded), s.TimeLength
		))
	end
end
table.sort(lines)
return table.concat(lines, "\n")
