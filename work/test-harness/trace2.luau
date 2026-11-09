-- Moves you to open floor facing away from the test wall, then reads speed, position and camera angle.
local me = game.Players.LocalPlayer
local root = me.Character.HumanoidRootPart
local cam = workspace.CurrentCamera
root.AssemblyLinearVelocity = Vector3.zero
root.CFrame = CFrame.lookAt(Vector3.new(0, 103, 45), Vector3.new(0, 103, 0))
task.wait(0.3)
cam.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 6, 14), root.Position)
_G.HT_trace_ready = true
local out = {}
for _ = 1, 24 do
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
	local off = if flat.Magnitude > 1 then math.deg(math.acos(math.clamp(flat.Unit:Dot(look), -1, 1))) else 0
	table.insert(out, string.format("%.0f@z%.0f/x%.0f/off%.0f", flat.Magnitude, root.Position.Z, root.Position.X, off))
	task.wait(0.2)
end
_G.HT_trace_ready = nil
return table.concat(out, " ")
