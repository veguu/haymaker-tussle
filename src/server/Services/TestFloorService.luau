--!strict
-- TestFloorService - TEMPORARY. A plain floor to feel movement on, until the real
-- arena exists. Turned off by Debug.TestFloor. Only touches what it builds itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)

local arena = GameConfig.Arena
local CENTER = Vector3.new(arena.CenterX, arena.CenterY, arena.CenterZ)
local FLOOR_THICKNESS = 4
local RING_COLOURS = { Color3.fromRGB(235, 235, 235), Color3.fromRGB(255, 200, 80) }
local WALL_SIZE = Vector3.new(3, 10, 30)
local WALL_DISTANCE = 40
local CHECK_SECONDS = 0.25
local SPAWN_SPREAD = 14

local TestFloorService = Knit.CreateService({
	Name = "TestFloorService",
})

-- A flat disc whose top surface sits `lift` above the floor.
local function disc(
	parent: Instance,
	name: string,
	radius: number,
	lift: number,
	colour: Color3,
	solid: boolean
): Part
	local thickness = if solid then FLOOR_THICKNESS else 0.02
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, radius * 2, radius * 2)
	part.CFrame = CFrame.new(CENTER + Vector3.new(0, lift - thickness / 2, 0))
		* CFrame.Angles(0, 0, math.pi / 2)
	part.Anchored = true
	part.CanCollide = solid
	part.CanQuery = solid
	part.CanTouch = false
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "HT_TestFloor"

	disc(folder, "Floor", arena.StartRadius, 0, Color3.fromRGB(95, 110, 130), true)

	-- Rings every 15 studs, so speed and arc width can be judged by eye.
	local radius = arena.StartRadius - 3
	local index = 0
	while radius > 3 do
		local colour = RING_COLOURS[index % 2 + 1]
		disc(folder, `RingOuter{index}`, radius, 0.02 + index * 0.02, colour, false)
		disc(
			folder,
			`RingInner{index}`,
			radius - 1,
			0.03 + index * 0.02,
			Color3.fromRGB(95, 110, 130),
			false
		)
		radius -= 15
		index += 1
	end

	-- One wall, to check characters really stop against things.
	local wall = Instance.new("Part")
	wall.Name = "TestWall"
	wall.Size = WALL_SIZE
	wall.CFrame = CFrame.new(CENTER + Vector3.new(WALL_DISTANCE, WALL_SIZE.Y / 2, 0))
	wall.Anchored = true
	wall.Color = Color3.fromRGB(200, 70, 70)
	wall.Material = Enum.Material.SmoothPlastic
	wall.Parent = folder

	folder.Parent = workspace
end

-- Alone, the middle of the floor. With others, a random spot around the middle facing inward, so players
-- don't all start inside each other. Someone in training stays there.
local function placeOnFloor(character: Model)
	local player = Players:GetPlayerFromCharacter(character)
	local training = Knit.GetService("TrainingService")
	if player and training:IsIn(player) then
		training:ReturnToStation(player)
		return
	end
	if #Players:GetPlayers() <= 1 then
		character:PivotTo(CFrame.new(CENTER + Vector3.new(0, 5, 0)))
		return
	end
	local angle = math.random() * 2 * math.pi
	local spot = CENTER
		+ Vector3.new(math.cos(angle) * SPAWN_SPREAD, 5, math.sin(angle) * SPAWN_SPREAD)
	character:PivotTo(CFrame.lookAt(spot, Vector3.new(CENTER.X, spot.Y, CENTER.Z)))
end

function TestFloorService:KnitInit()
	self._bodyReset = Net.server("BodyReset")
end

function TestFloorService:KnitStart()
	if not GameConfig.Debug.TestFloor then
		return
	end
	build()

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			task.defer(placeOnFloor, character)
		end)
		if player.Character then
			task.defer(placeOnFloor, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	-- Anyone who falls comes straight back.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_SECONDS then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- Training looks after its own falls.
			if
				character
				and root
				and root.Position.Y < CENTER.Y - arena.EliminationDepth
				and not Knit.GetService("TrainingService"):IsIn(player)
			then
				root.AssemblyLinearVelocity = Vector3.zero
				placeOnFloor(character)
				Knit.GetService("StaggerService"):Reset(character)
				self._bodyReset:FireClient(player, root.CFrame.LookVector, "fell")
			end
		end
	end)
end

return TestFloorService