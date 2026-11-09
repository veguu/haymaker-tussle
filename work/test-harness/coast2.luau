-- Moves you to open floor, then reads speed, keys down, position and the movement readout during a W release.
local UIS = game:GetService("UserInputService")
local root = game.Players.LocalPlayer.Character.HumanoidRootPart
root.AssemblyLinearVelocity = Vector3.zero
root.CFrame = CFrame.lookAt(Vector3.new(0, 103, 60), Vector3.new(0, 103, 0))
local out = {}
for _ = 1, 26 do
	local v = root.AssemblyLinearVelocity
	local keys = {}
	for _, k in UIS:GetKeysPressed() do
		table.insert(keys, k.KeyCode.Name)
	end
	table.insert(out, string.format("%.0f[%s]z%.0f", Vector3.new(v.X, 0, v.Z).Magnitude, table.concat(keys, "+"), root.Position.Z))
	task.wait(0.25)
end
return table.concat(out, " ")
