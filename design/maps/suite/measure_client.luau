-- Client: render cost of the live map from a fixed fighter's-eye camera, and what MapExtras' swing costs a frame.
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local cam = workspace.CurrentCamera
local map = workspace:WaitForChild("HT_Map", 10)
local centre = Vector3.new(3000, 100, 0)
local eye = centre + Vector3.new(0, 6, 120)
local look = centre + Vector3.new(60, 20, -400)

local function sample(seconds)
	local cpu, gpu, frame, n = {}, {}, {}, 0
	-- after the game's own camera each frame, so the view stays fixed
	RunService:BindToRenderStep("HT_Measure", Enum.RenderPriority.Last.Value, function()
		cam.CFrame = CFrame.lookAt(eye, look)
	end)
	task.wait(1)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		RunService.Heartbeat:Wait()
		n += 1
		table.insert(cpu, Stats.RenderCPUFrameTime * 1000)
		table.insert(gpu, Stats.RenderGPUFrameTime * 1000)
		table.insert(frame, Stats.FrameTime * 1000)
	end
	RunService:UnbindFromRenderStep("HT_Measure")
	local function median(t)
		table.sort(t)
		return math.floor(t[math.max(1, math.floor(#t / 2))] * 1000 + 0.5) / 1000
	end
	return { frames = n, cpu = median(cpu), gpu = median(gpu), frame = median(frame) }
end

-- the swing's own cost: MapExtras' step for the 5 boom parts, timed over many runs (parts put back after)
local parts, homes = {}, {}
for _, d in (map and map:GetDescendants() or {}) do
	if d:IsA("BasePart") and string.find(d.Name, "_DerrickBoom_", 1, true) then
		table.insert(parts, d)
		table.insert(homes, d.CFrame)
	end
end
local MapMotion = require(game.ReplicatedStorage.Shared.Core.MapMotion)
local mover = { mode = "swing", amp = 12, period = 60 }
local hub = centre + Vector3.new(560, 31.4, -760)
local frames = table.create(#parts)
local runs = 2000
local t0 = os.clock()
for i = 1, runs do
	local angle = MapMotion.pose(mover, i / 60)
	local turn = CFrame.new(hub) * CFrame.fromAxisAngle(Vector3.yAxis, angle) * CFrame.new(-hub)
	for k, home in homes do
		frames[k] = turn * home
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end
local swingUs = (os.clock() - t0) / runs * 1e6
workspace:BulkMoveTo(parts, homes, Enum.BulkMoveMode.FireCFrameChanged)

local r = sample(6)
return {
	map = map and map:GetAttribute("MapId"),
	swingParts = #parts,
	swingMicroseconds = math.floor(swingUs * 100 + 0.5) / 100,
	render = r,
	textureMb = math.floor(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture) + 0.5),
	meshMb = math.floor(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts) + 0.5),
	totalMb = math.floor(Stats:GetTotalMemoryUsageMb() + 0.5),
}
