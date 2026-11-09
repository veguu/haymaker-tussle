-- Measures running speed at three stagger values, using the runner's held W. Then reads what happens
-- to the rest. Client-side read only, except that the server sets the stagger attribute beforehand.
local me = game.Players.LocalPlayer
local ch = me.Character
local root = ch.HumanoidRootPart
local stagger = ch:GetAttribute("HT_Stagger")
local top = 0
local start = os.clock()
while os.clock() - start < 3.1 do
	local v = root.AssemblyLinearVelocity
	top = math.max(top, Vector3.new(v.X, 0, v.Z).Magnitude)
	task.wait()
end
return string.format("stagger %s: top speed %.1f", tostring(stagger), top)
