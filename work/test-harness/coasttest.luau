-- Moves you to open floor, then reads speed, the camera's angle off travel, and how many smoke puffs are
-- showing. run_coasttest.py sends W, then a turn with D and A, then a turn during a propel.
local root = game.Players.LocalPlayer.Character.HumanoidRootPart
root.AssemblyLinearVelocity = Vector3.zero
root.CFrame = CFrame.lookAt(Vector3.new(0, 103, 50), Vector3.new(0, 103, 0))
local out = {}
local function puffs()
	local n = 0
	for _, part in workspace.HT_Fx:GetChildren() do
		if part:IsA("BasePart") and part:FindFirstChildOfClass("SpecialMesh") and part.Position.Y > -500 and part.Transparency < 1 then
			n += 1
		end
	end
	return n
end
for _ = 1, 44 do
	local v = root.AssemblyLinearVelocity
	table.insert(out, string.format("%.0f/%d", Vector3.new(v.X, 0, v.Z).Magnitude, puffs()))
	task.wait(0.25)
end
return table.concat(out, " ")
