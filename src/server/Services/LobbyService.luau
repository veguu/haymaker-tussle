--!strict
-- LobbyService - the open-air lobby beside the arena: its floor, its invisible walls, who's on it, its
-- two practice dummies, and the rule that nobody on it can be hit. Everything is placed from
-- GameConfig.Lobby through Core/Lobby.
--
-- WHO'S IN THE LOBBY: anyone standing inside its edges who isn't a fighter in the current round (player
-- attribute HT_InLobby). New, waiting and eliminated players are sent here by RoundService.
--
-- THE WALLS can't be seen and never show, even when touched: anchored, fully transparent parts with
-- their inner faces on the floor's edge, frictionless so you slide along them. They're past the round's
-- out line, so a fighter knocked this far is already out before reaching one.
--
-- WHAT YOU SEE is the Blender model (design/lobby/cliffside.py), kept at ServerStorage.HT_Lobby.<Lobby.Model>
-- with its pivot on the middle of the viewing edge at floor level, and cloned into place here. It collides
-- with nothing. WHAT YOU STAND ON is built here, invisible: one flat floor for the whole platform, then each
-- terrace's slab and the ramp under its steps, and the solid props (planters, the stall's counter, posts),
-- all from Config/LobbyLayout, which the same Blender script generates (never edit it by hand).
-- If the model isn't in the place, the old plain stand-in floor shows instead (Lobby.ShowFloor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lobby = require(ReplicatedStorage.Shared.Core.Lobby)
local LobbyLayout = require(ReplicatedStorage.Shared.Config.LobbyLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg: any = GameConfig.Lobby
local IN_LOBBY = "HT_InLobby"
-- FREE PRACTICE (owner, 2026-11-18): past the training wall the fight's limits are off. The server marks a
-- player standing in the training zone HT_TrainingFree; every cooldown check and the ultimate meter read it.
local FREE = "HT_TrainingFree"
local FLOOR_THICKNESS = 8
local STAND_HEIGHT = 3 -- a standing body's root is this far above the floor
local CHECK_SECONDS = 0.1
local INLAY = 0.05 -- how thick a floor marking is; it sits this far proud, and nothing collides with it

local STONE = Color3.fromRGB(226, 214, 190)
local MAT = Color3.fromRGB(96, 158, 146)
local TIMBER = Color3.fromRGB(178, 132, 84)
local EDGE = Color3.fromRGB(255, 196, 61)
local UNDER = Color3.fromRGB(150, 140, 124)

local LobbyService = Knit.CreateService({
	Name = "LobbyService",
})

local dummies: { [Model]: boolean } = {}
local folder: Folder
local shown = false -- is the plain stand-in floor visible (no Blender model in the place)?

local function slab(
	name: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	top: number,
	thick: number
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(x1 - x0, thick, z1 - z0)
	part.CFrame = CFrame.new((x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

-- A flat marking on the floor: seen, never felt.
local function inlay(
	name: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	colour: Color3,
	material: Enum.Material
)
	local part = slab(name, x0, x1, z0, z1, cfg.FloorY + INLAY, INLAY)
	part.Color = colour
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = if shown then 0 else 1
end

-- An invisible solid piece of the layout: `u` across from the centre, `d` back from the viewing edge, `h`
-- above the floor (the Blender script's axes).
local function collider(index: number, c: any)
	local back = if cfg.ViewEdgeZ >= 0 then 1 else -1
	local part: BasePart
	if c.kind == "cyl" then
		local post = Instance.new("Part")
		post.Shape = Enum.PartType.Cylinder
		post.Size = Vector3.new(c.h1 - c.h0, c.r * 2, c.r * 2)
		post.CFrame = CFrame.new(
			cfg.CenterX + c.u,
			cfg.FloorY + (c.h0 + c.h1) / 2,
			cfg.ViewEdgeZ + back * c.d
		) * CFrame.Angles(0, 0, math.pi / 2)
		part = post
	else
		local size = Vector3.new(c.u1 - c.u0, c.h1 - c.h0, c.d1 - c.d0)
		local at = CFrame.new(
			cfg.CenterX + (c.u0 + c.u1) / 2,
			cfg.FloorY + (c.h0 + c.h1) / 2,
			cfg.ViewEdgeZ + back * (c.d0 + c.d1) / 2
		)
		if c.kind == "wedge" then
			-- a WedgePart is low at its front (-Z) and high at its back: turned so it climbs away from the arena
			part = Instance.new("WedgePart")
			part.CFrame = if back > 0 then at else at * CFrame.Angles(0, math.pi, 0)
		else
			part = Instance.new("Part")
			part.CFrame = at
		end
		part.Size = size
	end
	part.Name = `Solid{index}_{c.kind}`
	part.Anchored = true
	-- seen only with the plain stand-in floor (no Blender model in the place), so the terraces can be walked
	part.Transparency = if shown then 0 else 1
	part.Color = STONE
	part.Material = Enum.Material.Limestone
	part.CanCollide = true
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
end

-- The Blender model, cloned into place. Returns whether it was there.
local function placeModel(): boolean
	local store = ServerStorage:FindFirstChild("HT_Lobby")
	local source = store and store:FindFirstChild(cfg.Model or "")
	if not (source and source:IsA("Model")) then
		return false
	end
	local model = source:Clone()
	model.Name = "Model"
	local facing = if cfg.ViewEdgeZ >= 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
	model:PivotTo(CFrame.new(cfg.CenterX, cfg.FloorY, cfg.ViewEdgeZ) * facing)
	-- always loaded for everyone, whole (streaming would deliver it piece by piece)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = folder
	return true
end

local function build()
	folder = Instance.new("Folder")
	folder.Name = "HT_Lobby"
	local x0, x1, z0, z1 = Lobby.bounds(cfg)
	local line = Lobby.trainingLine(cfg)
	local modelled = placeModel()
	local hidden = if cfg.ShowFloor and not modelled then 0 else 1
	shown = hidden == 0

	-- One floor for the whole platform, so there's no seam to trip on between lobby and training.
	local floor = slab("Floor", x0, x1, z0, z1, cfg.FloorY, FLOOR_THICKNESS)
	floor.Color = STONE
	floor.Material = Enum.Material.Limestone
	floor.Transparency = hidden
	local under =
		slab("Underside", x0 + 6, x1 - 6, z0 + 6, z1 - 6, cfg.FloorY - FLOOR_THICKNESS, 10)
	under.Color = UNDER
	under.Material = Enum.Material.Slate
	under.CanCollide = false
	under.Transparency = hidden

	-- The training mat, flush with the floor; the strip kept for gamepass displays; a line on the
	-- viewing edge, because nothing else marks where the floor stops.
	inlay("TrainingMat", x0 + 3, x1 - 3, line, z1 - 3, MAT, Enum.Material.Fabric)
	local sx0, sx1, sz0, sz1 = Lobby.strip(cfg)
	inlay("GamepassStrip", sx0 + 1, sx1 - 3, sz0 + 6, sz1 - 4, TIMBER, Enum.Material.WoodPlanks)
	inlay("ViewingEdge", x0, x1, z0, z0 + 1.5, EDGE, Enum.Material.SmoothPlastic)

	for index, solid in LobbyLayout.colliders do
		collider(index, solid)
	end

	for index, wall in Lobby.walls(cfg) do
		local part = Instance.new("Part")
		part.Name = `Barrier{index}`
		part.Size = Vector3.new(wall.sx, wall.sy, wall.sz)
		part.CFrame = CFrame.new(wall.x, wall.y, wall.z)
		part.Anchored = true
		part.Transparency = 1
		part.CanCollide = true
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		-- No friction and no bounce: you stop against it and can still slide along it.
		part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
		part.Parent = folder
	end
	folder.Parent = workspace
end

--- Is this player in the lobby?
function LobbyService:IsIn(player: Player): boolean
	return player:GetAttribute(IN_LOBBY) == true
end

--- Counts someone as out of the lobby at once, without moving them. For the round, which moves them.
function LobbyService:Release(player: Player)
	player:SetAttribute(IN_LOBBY, nil)
end

--- Puts someone on the lobby's spawn, facing the arena, with nothing left over from what they were doing.
function LobbyService:Enter(player: Player)
	local character = player.Character
	local root = character and Combatants.rootOf(character)
	if not character or not root then
		return
	end
	Knit.GetService("KickService"):Release(character)
	Knit.GetService("ClashService"):EndFor(character, "fell")
	local spot = Lobby.spawn(cfg, math.random(), math.random())
	local at = Vector3.new(spot.x, cfg.FloorY + Lobby.heightAt(cfg, spot.z) + STAND_HEIGHT, spot.z)
	local face = Vector3.new(spot.faceX, 0, spot.faceZ)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(
		CFrame.lookAt(at, at + face) * root.CFrame:ToObjectSpace(character:GetPivot())
	)
	Knit.GetService("StaggerService"):Reset(character)
	player:SetAttribute(IN_LOBBY, true)
	self._bodyReset:FireClient(player, face, "moved")
end

--- The lobby's say on whether these two may hit each other, or nil to leave it to the usual rules.
--- A practice dummy can be hit by a player in the lobby and by nothing else; anyone in the lobby is
--- out of every other fight, so practice never touches people watching or browsing.
function LobbyService:AllowsFight(a: Model, b: Model): boolean?
	if not cfg.Enabled then
		return nil
	end
	local playerA, playerB = Combatants.playerOf(a), Combatants.playerOf(b)
	if dummies[a] or dummies[b] then
		local player = playerA or playerB
		return player ~= nil and not (dummies[a] and dummies[b]) and self:IsIn(player)
	end
	if (playerA and self:IsIn(playerA)) or (playerB and self:IsIn(playerB)) then
		return false
	end
	return nil
end

local function spawnDummies()
	local service = Knit.GetService("DummyService")
	service.DummyReplaced.Event:Connect(function(old: Model, new: Model)
		if dummies[old] then
			dummies[old] = nil
			dummies[new] = true
		end
	end)
	for _, spot in Lobby.dummies(cfg) do
		task.spawn(function()
			local at =
				Vector3.new(spot.x, cfg.FloorY + Lobby.heightAt(cfg, spot.z) + STAND_HEIGHT, spot.z)
			local model = service:Spawn({
				name = spot.name,
				home = CFrame.lookAt(at, at + Vector3.new(spot.faceX, 0, spot.faceZ)),
				startStagger = 0,
				resetSeconds = cfg.DummyResetSeconds,
				fallY = cfg.FloorY - cfg.FallDepth,
			})
			dummies[model] = true
		end)
	end
end

-- THE STATION KEEPERS (owner, 2026-11-18: every stall has a use). One blocky figure behind each stall's counter
-- and at each signpost, from Lobby.Npcs (written by design/lobby/village.py: where the stations are). Each carries a ProximityPrompt
-- with the attribute HT_Page; the client's NpcController opens that page of the menu. They are scenery: seven
-- anchored parts, no Humanoid, nothing collides, nothing to hit.
local NPC_SKIN = Color3.fromRGB(240, 206, 170)
local NPC_CLOTH = {
	moves = Color3.fromRGB(236, 112, 86),
	more = Color3.fromRGB(64, 150, 146),
	classes = Color3.fromRGB(236, 112, 86),
	shop = Color3.fromRGB(238, 180, 62),
	ranked = Color3.fromRGB(64, 150, 146),
}

local function spawnNpcs()
	local keepers = Instance.new("Folder")
	keepers.Name = "Keepers"
	for _, npc in cfg.Npcs or {} do
		local z = cfg.ViewEdgeZ + npc.Back
		local feet = Vector3.new(cfg.CenterX + npc.X, cfg.FloorY + Lobby.heightAt(cfg, z), z)
		local frame = CFrame.lookAt(feet, feet + Vector3.new(npc.FaceX, 0, npc.FaceZ))
		local model = Instance.new("Model")
		model.Name = npc.Name
		local cloth = NPC_CLOTH[npc.Page] or TIMBER
		local function piece(
			name: string,
			size: Vector3,
			offset: Vector3,
			colour: Color3,
			shape: Enum.PartType?
		): Part
			local part = Instance.new("Part")
			part.Name = name
			part.Size = size * 1.2
			part.CFrame = frame * CFrame.new(offset * 1.2)
			part.Color = colour
			part.Material = Enum.Material.SmoothPlastic
			part.Shape = shape or Enum.PartType.Block
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = name == "Torso"
			part.Parent = model
			return part
		end
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(1, 2, 1), Vector3.new(side * 0.5, 1, 0), TIMBER)
			piece("Arm", Vector3.new(1, 2, 1), Vector3.new(side * 1.5, 3, 0), cloth)
		end
		local torso = piece("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), cloth)
		local head = piece(
			"Head",
			Vector3.new(1.3, 1.3, 1.3),
			Vector3.new(0, 4.65, 0),
			NPC_SKIN,
			Enum.PartType.Ball
		)
		local hat = piece(
			"Hat",
			Vector3.new(0.35, 2.3, 2.3),
			Vector3.new(0, 5.25, 0),
			EDGE,
			Enum.PartType.Cylinder
		)
		hat.CFrame = hat.CFrame * CFrame.Angles(0, 0, math.rad(90))
		model.PrimaryPart = torso

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Talk"
		prompt.ObjectText = npc.Name
		prompt.ActionText = npc.Action
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = cfg.NpcReach or 13
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("HT_Page", npc.Page)
		prompt.Parent = torso

		local tag = Instance.new("BillboardGui")
		tag.Name = "NameTag"
		tag.Size = UDim2.fromOffset(180, 26)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
		tag.MaxDistance = 70
		tag.AlwaysOnTop = false
		tag.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = npc.Name
		label.TextColor3 = Color3.fromRGB(255, 244, 222)
		label.TextStrokeColor3 = Color3.fromRGB(40, 28, 24)
		label.TextStrokeTransparency = 0.2
		label.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
		label.TextSize = 18
		label.Parent = tag
		tag.Parent = head
		model.Parent = keepers
	end
	keepers.Parent = folder
end

-- THE LEADERBOARDS: three timber boards on the training wall (the Blender model), and on each a face from
-- Lobby.Boards: a dark, slightly see-through panel with a title and ten rows. `LobbyService:SetBoard` fills one.
-- Nothing fills them yet: kills, wins and playtime are not saved anywhere, so they read "No scores yet".
local boardRows: { [string]: { TextLabel } } = {}

local function spawnBoards()
	local holder = Instance.new("Folder")
	holder.Name = "Boards"
	for _, board in cfg.Boards or {} do
		local z = cfg.ViewEdgeZ + board.Back
		local at = Vector3.new(cfg.CenterX + board.X, cfg.FloorY + board.Up, z)
		local part = Instance.new("Part")
		part.Name = board.Stat
		part.Size = Vector3.new(12.2, 9, 0.2)
		part.CFrame = CFrame.lookAt(at, at + Vector3.new(board.FaceX, 0, board.FaceZ))
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = part
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.new(0, 0, 0)
		back.BackgroundTransparency = 0.35
		back.BorderSizePixel = 0
		back.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = back
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 56)
		title.BackgroundTransparency = 1
		title.Text = board.Title
		title.TextColor3 = EDGE
		title.FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
		title.TextSize = 40
		title.Parent = back
		local rows = {}
		for index = 1, 10 do
			local row = Instance.new("TextLabel")
			row.Position = UDim2.new(0, 22, 0, 56 + (index - 1) * 29)
			row.Size = UDim2.new(1, -44, 0, 28)
			row.BackgroundTransparency = 1
			row.Text = if index == 1 then "No scores yet" else ""
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextColor3 = Color3.fromRGB(255, 244, 222)
			row.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
			row.TextSize = 24
			row.Parent = back
			rows[index] = row
		end
		boardRows[board.Stat] = rows
		part.Parent = holder
	end
	holder.Parent = folder
end

--- Writes a leaderboard: `rows` is up to ten { name, value } pairs, best first. For "Kills", "Wins", "Playtime".
function LobbyService:SetBoard(stat: string, rows: { { name: string, value: string } })
	local labels = boardRows[stat]
	if not labels then
		return
	end
	for index, label in labels do
		local row = rows[index]
		label.Text = if row
			then `{index}.  {row.name}   {row.value}`
			elseif index == 1 then "No scores yet"
			else ""
	end
end

function LobbyService:KnitInit()
	self._bodyReset = Net.server("BodyReset")
end

function LobbyService:KnitStart()
	if not cfg.Enabled then
		return
	end
	build()
	spawnDummies()
	spawnNpcs()
	spawnBoards()

	-- Who's on it. Standing inside the edges is what counts, however they arrived; a fighter in the
	-- round never is.
	local round = Knit.GetService("RoundService")
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_SECONDS then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and Combatants.rootOf(character)
			if character and root then
				local position = root.Position
				local inside = Lobby.contains(cfg, position.X, position.Z)
					and position.Y > cfg.FloorY - cfg.FallDepth
					and not round:IsStanding(character)
				if inside ~= self:IsIn(player) then
					player:SetAttribute(IN_LOBBY, if inside then true else nil)
				end
				-- The zone starts behind the training wall (Inset past the line) and is ENTERED ON FOOT: you
				-- become part of it only when you're in its footprint near the floor. So someone running the
				-- obby's decks overhead is never in it, and someone launched high inside it stays in it until
				-- they leave its footprint.
				local zone: any = cfg.TrainingFree
				local floor = cfg.FloorY + cfg.Terraces[#cfg.Terraces].Rise
				local inFootprint = inside
					and zone ~= nil
					and zone.Enabled == true
					and Lobby.inTraining(cfg, position.X, position.Z - (zone.Inset or 0))
				local free = inFootprint
					and (
						player:GetAttribute(FREE) == true
						or position.Y - floor < (zone.EnterHeight or 8) + STAND_HEIGHT
					)
				if free ~= (player:GetAttribute(FREE) == true) then
					player:SetAttribute(FREE, if free then true else nil)
				end
			end
		end
	end)
end

return LobbyService
