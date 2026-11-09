-- Read-only: real flat speed every 0.25 s for 9 s, to read a coast or a stop against the key timing.
local root = game.Players.LocalPlayer.Character.HumanoidRootPart
local out = {}
for _ = 1, 36 do
	local v = root.AssemblyLinearVelocity
	table.insert(out, string.format("%.0f", Vector3.new(v.X, 0, v.Z).Magnitude))
	task.wait(0.25)
end
return table.concat(out, " ")
