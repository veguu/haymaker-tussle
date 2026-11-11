--!strict
-- EnvironmentController - applies the active map's environment (lighting, sky, clouds, leaves, bobbing
-- scenery) on this client, and covers every map change with a short screen fade. The lobby shares it:
-- Lighting is one per client.
--
-- READS (MapService's contract): ReplicatedStorage.HT_MapState attributes Map, Seq, Pending, SwapAt, and
-- workspace.HT_Map (attributes MapId, Seq).
--
-- A CHANGE, as this client sees it:
--   Pending set  -> fade to cover, timed to be covered by SwapAt; build the incoming map's clouds and leaves
--                   now, unparented, so nothing pops in later.
--   Map/Seq set  -> covered at once if the fade hadn't finished (the new arena is never shown under the old
--                   lighting); the old scene is destroyed whole; the new lighting is applied and the
--                   prepared scene shown; once the new geometry is here and loaded (and at least
--                   Maps.HoldSeconds have passed) the fade clears.
-- JOINING: the screen starts covered and clears once the active map's environment is in, so a late joiner
-- never sees a default sky. A newer change at any point replaces the one in progress (a generation
-- counter). If the cover lasts longer than Maps.MaxBlackSeconds for any reason, it clears anyway.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Environment = require(ReplicatedStorage.Shared.Core.Environment)
local EnvironmentKit = require(ReplicatedStorage.Shared.EnvironmentKit)

local cfg: any = GameConfig.Maps
local arena: any = GameConfig.Arena
local ANCHOR = Vector3.new(arena.CenterX, arena.CenterY, arena.CenterZ)
local FADE_COLOUR = Color3.fromRGB(22, 30, 46)
local MAP_WAIT_SECONDS = 5
local PRELOAD_SECONDS = 3

local EnvironmentController = Knit.CreateController({
	Name = "EnvironmentController",
})

local alpha = 1
local target = 1
local fadeSeconds = 0.6
local coveredSince: number? = os.clock()
local generation = 0
local scene: EnvironmentKit.Scene? = nil
local prepared: { id: string, scene: EnvironmentKit.Scene }? = nil
local overlay: Frame

local function trace(message: string)
	if workspace:GetAttribute("HaymakerMapDebug") then
		print(`[Env] {message}`)
	end
end

local function cover(seconds: number)
	target = 1
	fadeSeconds = seconds
end

local function reveal(seconds: number)
	target = 0
	fadeSeconds = seconds
end

local function makeOverlay()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_MapFade"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local frame = Instance.new("Frame")
	frame.Name = "Cover"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = FADE_COLOUR
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.BackgroundTransparency = 0
	frame.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	overlay = frame
end

-- Build (unparented) the scene for `id`, ahead of the swap.
local function prepare(id: string)
	if prepared and prepared.id == id then
		return
	end
	if prepared then
		prepared.scene:destroy()
	end
	prepared = { id = id, scene = EnvironmentKit.newScene(EnvironmentKit.preset(id), ANCHOR, id) }
	trace(`prepared {id}`)
end

-- The active map's geometry, once it's the one for `seq` (nil if it doesn't arrive in time).
local function waitForMap(seq: number, mine: number): Instance?
	local deadline = os.clock() + MAP_WAIT_SECONDS
	while os.clock() < deadline and mine == generation do
		local model = workspace:FindFirstChild("HT_Map")
		if model and model:GetAttribute("Seq") == seq then
			return model
		end
		task.wait(0.05)
	end
	return nil
end

-- Put `id`'s environment in place (the screen is covered for all of it), then clear the cover.
local function enter(id: string, seq: number, revealSeconds: number)
	generation += 1
	local mine = generation
	alpha, target = 1, 1 -- covered now, even if the fade out hadn't finished
	coveredSince = coveredSince or os.clock()
	local startedAt = os.clock()

	if scene then
		scene:destroy()
		scene = nil
	end
	local p = EnvironmentKit.preset(id)
	EnvironmentKit.applyLighting(p)
	if not (prepared and prepared.id == id) then
		prepare(id)
	end
	local incoming = (prepared :: any).scene :: EnvironmentKit.Scene
	prepared = nil
	scene = incoming

	task.spawn(function()
		local model = waitForMap(seq, mine)
		if mine ~= generation then
			return
		end
		incoming:bind(model)
		incoming:show(workspace)
		if model then
			local done = false
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync({ model, incoming.folder })
				end)
				done = true
			end)
			local until_ = os.clock() + PRELOAD_SECONDS
			while not done and os.clock() < until_ and mine == generation do
				task.wait(0.05)
			end
		end
		local hold = cfg.HoldSeconds - (os.clock() - startedAt)
		if hold > 0 then
			task.wait(hold)
		end
		if
			mine == generation
			and (ReplicatedStorage :: any).HT_MapState:GetAttribute("Pending") == ""
		then
			local clouds, motes = incoming:counts()
			trace(`entered {id} seq {seq}: {clouds} clouds, {motes} leaves`)
			reveal(revealSeconds)
		end
	end)
end

function EnvironmentController:KnitStart()
	makeOverlay()

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		alpha = Environment.fadeStep(alpha, target, dt, fadeSeconds)
		overlay.BackgroundTransparency = 1 - alpha
		overlay.Visible = alpha > 0
		if alpha >= 1 then
			coveredSince = coveredSince or now
			if now - (coveredSince :: number) > cfg.MaxBlackSeconds and target == 1 then
				trace("cover held too long: clearing")
				reveal(cfg.FadeInSeconds)
			end
		else
			coveredSince = nil
		end
		if scene then
			scene:step(workspace:GetServerTimeNow())
		end
	end)

	if not cfg.Enabled then
		-- no map system: the shared sunny default, no fades
		EnvironmentKit.applyLighting(EnvironmentKit.preset(nil))
		alpha, target = 0, 0
		return
	end

	local state = ReplicatedStorage:WaitForChild("HT_MapState") :: Folder

	local function onPending()
		local id = state:GetAttribute("Pending")
		if type(id) ~= "string" or id == "" then
			return
		end
		local swapAt = state:GetAttribute("SwapAt")
		local left = if type(swapAt) == "number"
			then swapAt - workspace:GetServerTimeNow()
			else cfg.FadeOutSeconds
		-- covered by the swap: what's left of the fade takes the time that's left (fadeStep's seconds are
		-- for a whole fade, so scale up by the share still to go)
		local share = 1 - alpha
		local seconds = math.clamp(left - 0.05, 0.05, cfg.FadeOutSeconds)
		cover(if share > 0.01 then seconds / share else 0.05)
		prepare(id)
	end

	local lastSeq = -1
	local function onMap(revealSeconds: number)
		local id = state:GetAttribute("Map")
		local seq = state:GetAttribute("Seq")
		if type(id) ~= "string" or type(seq) ~= "number" or seq == lastSeq then
			return
		end
		lastSeq = seq
		enter(id, seq, revealSeconds)
	end

	state:GetAttributeChangedSignal("Pending"):Connect(onPending)
	state:GetAttributeChangedSignal("Seq"):Connect(function()
		onMap(cfg.FadeInSeconds)
	end)
	-- joining: whatever is active now, revealed more gently
	onPending()
	onMap(cfg.JoinFadeInSeconds)
end

return EnvironmentController
