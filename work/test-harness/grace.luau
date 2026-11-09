-- Timed in one script, since separate tool calls take longer than the grace period itself.
local Run = game:GetService("RunService")
local g = game.Players.LocalPlayer.PlayerGui.HT_LockOnMarker
local cam = workspace.CurrentCamera
local d = workspace.HT_D.HumanoidRootPart
local out = {}
local function isLocked() return g.Adornee ~= nil and g.Layer2.ImageColor3.B < 0.5 end
local function note(label, t0)
	table.insert(out, string.format("%-44s %.2f s: shown=%s locked=%s", label, os.clock() - t0, tostring(g.Enabled), tostring(isLocked())))
end
local function wall()
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = Vector3.new(40, 40, 1)
	p.Position = d.Position + Vector3.new(0, 0, 5)
	p.Parent = workspace
	return p
end
local function yaw() local _, y = cam.CFrame:ToOrientation() return math.deg(y) end
if not isLocked() then return "not locked at the start" end
local t0 = os.clock()
local p = wall()
Run.Heartbeat:Wait() Run.Heartbeat:Wait()
note("wall up, 2 frames later", t0)
local y0 = yaw()
d.CFrame += Vector3.new(14, 0, 0)
task.wait(0.4)
table.insert(out, string.format("they moved 14 studs while hidden: camera yaw %.2f then %.2f", y0, yaw()))
note("still hidden", t0)
d.CFrame -= Vector3.new(14, 0, 0)
p:Destroy()
task.wait(0.15)
note("wall gone, back in sight", t0)
task.wait(0.8)
note("still held, past when the grace would end", t0)
t0 = os.clock()
p = wall()
while g.Adornee ~= nil and os.clock() - t0 < 3 do task.wait() end
table.insert(out, string.format("hidden for good: let go after %.2f s", os.clock() - t0))
p:Destroy()
return table.concat(out, "\n")
