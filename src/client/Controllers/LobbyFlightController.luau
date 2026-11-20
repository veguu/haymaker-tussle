--!strict
-- LobbyFlightController - Bell Rock's two set pieces, on this client (2026-11-20; the owner: the obby leads to an
-- island behind the lobby, "make it creative").
--
-- THE HAYMAKER'S FLIGHT (LobbyFlight, to this player only): the glove threw you home. Your own client owns your
-- body, so it flies you: every frame, after the movement code has run, the body is set on the arc
-- (Core/Lobby.flightPoint: a straight line from the glove to the Champion's Perch, lifted by `apex` at its middle)
-- with the matching velocity, so nothing between the two (walls, roofs, the tree) can catch you. At the end you
-- stand on the Perch; the server then resets your momentum (BodyReset) and checks you arrived.
--
-- THE SET PIECES MOVING (LobbyFx, to everyone): "glove" throws the glove's punch (the Lobby_Glove_* meshes shoot
-- out 5 studs and spring back), "bell" swings the bell (Lobby_Bell_*) on its hanger. Each plays its sound if one
-- is set (Lobby.Sky.Bell.Sound, Lobby.Sky.Glove.Sound). Reduced Motion: the sound only.
--
-- COST: nothing runs until an event arrives; a flight binds one render step for its few seconds, a swing tweens
-- at most four parts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lobby = require(ReplicatedStorage.Shared.Core.Lobby)
local Net = require(ReplicatedStorage.Shared.Net)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)

local LobbyFlightController = Knit.CreateController({ Name = "LobbyFlightController" })

local cfg: any = GameConfig.Lobby
local STEP_NAME = "HT_LobbyFlight"
local PUNCH_OUT = 5 -- studs the glove shoots out
local rest: { [BasePart]: CFrame } = {} -- each moving mesh's place in the model, so repeated swings never drift

-- The lobby model's meshes whose names start with `prefix` (and are not the frame or the rock of the same name).
local function meshes(prefix: string): { BasePart }
	local list: { BasePart } = {}
	local lobby = workspace:FindFirstChild("HT_Lobby")
	local model = lobby and lobby:FindFirstChild("Model")
	if not model then
		return list
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and string.sub(item.Name, 1, #prefix) == prefix then
			table.insert(list, item)
			rest[item] = rest[item] or item.CFrame
		end
	end
	return list
end

local function playAt(id: string?, at: Vector3, volume: number?)
	if not id or id == "" then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "HT_LobbySound"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(at)
	holder.Parent = workspace
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 1
	sound.RollOffMaxDistance = 600
	sound.Parent = holder
	sound:Play()
	task.delay(6, function()
		holder:Destroy()
	end)
end

local function world(x: number, back: number, up: number): Vector3
	return Vector3.new(cfg.CenterX + x, cfg.FloorY + up, cfg.ViewEdgeZ + back)
end

local function punchGlove()
	local glove = cfg.Sky.Glove
	playAt(glove.Sound, world(glove.X, glove.Back, glove.Up + 4), 1)
	if HudMotion.reduced() then
		return
	end
	local toward = Vector3.new(0, 0, if cfg.ViewEdgeZ >= 0 then -1 else 1) -- at the village
	for _, part in meshes("Lobby_Glove_") do
		local home = rest[part]
		local out = TweenService:Create(
			part,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = home + toward * PUNCH_OUT }
		)
		out.Completed:Once(function()
			TweenService:Create(
				part,
				TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ CFrame = home }
			):Play()
		end)
		out:Play()
	end
end

local function ringBell()
	local bell = cfg.Sky.Bell
	playAt(bell.Sound, world(bell.X, bell.Back, bell.Up + 6), bell.Volume)
	if HudMotion.reduced() then
		return
	end
	local parts = meshes("Lobby_Bell_")
	if #parts == 0 then
		return
	end
	-- it swings about its hanger, under the frame's beam
	local pivot = CFrame.new(world(bell.X, bell.Back, bell.Up + 8.6))
	local offsets: { [BasePart]: CFrame } = {}
	for _, part in parts do
		offsets[part] = pivot:ToObjectSpace(rest[part])
	end
	local angle = Instance.new("NumberValue")
	angle.Changed:Connect(function(value: number)
		local turn = pivot * CFrame.Angles(value, 0, 0)
		for part, offset in offsets do
			part.CFrame = turn * offset
		end
	end)
	local swings = { 0.42, -0.3, 0.18, -0.08, 0 }
	local index = 0
	local function nextSwing()
		index += 1
		if index > #swings then
			angle:Destroy()
			return
		end
		local tween = TweenService:Create(
			angle,
			TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Value = swings[index] }
		)
		tween.Completed:Once(nextSwing)
		tween:Play()
	end
	nextSwing()
end

local function fly(from: Vector3, to: Vector3, apex: number, seconds: number)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local started = os.clock()
	local arena = Vector3.new(0, 0, if cfg.ViewEdgeZ >= 0 then -1 else 1)
	pcall(function()
		RunService:UnbindFromRenderStep(STEP_NAME)
	end)
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Last.Value, function()
		if not root.Parent then
			RunService:UnbindFromRenderStep(STEP_NAME)
			return
		end
		local t = (os.clock() - started) / seconds
		local x, y, z, vx, vy, vz =
			Lobby.flightPoint(from.X, from.Y, from.Z, to.X, to.Y, to.Z, apex, seconds, t)
		local at = Vector3.new(x, y, z)
		if t >= 1 then
			RunService:UnbindFromRenderStep(STEP_NAME)
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.lookAt(at, at + arena)
			return
		end
		local flat = Vector3.new(vx, 0, vz)
		root.CFrame = CFrame.lookAt(at, at + (if flat.Magnitude > 0.01 then flat.Unit else arena))
		root.AssemblyLinearVelocity = Vector3.new(vx, vy, vz)
	end)
end

function LobbyFlightController:KnitStart()
	if not cfg.Enabled or not cfg.Sky or not cfg.Sky.Enabled then
		return
	end
	task.spawn(function()
		local flight = Net.client("LobbyFlight")
		if flight then
			flight.OnClientEvent:Connect(
				function(from: Vector3, to: Vector3, apex: number, seconds: number)
					fly(from, to, apex, seconds)
				end
			)
		end
	end)
	task.spawn(function()
		local fx = Net.client("LobbyFx")
		if fx then
			fx.OnClientEvent:Connect(function(kind: string)
				if kind == "glove" then
					punchGlove()
				elseif kind == "bell" then
					ringBell()
				end
			end)
		end
	end)
end

return LobbyFlightController
