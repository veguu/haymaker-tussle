--!strict
-- LobbyService - the open-air lobby beside the arena: its floor, its invisible walls, who's on it, its
-- training sections' dummies, bots, signs and launch pad, and the rule that nobody on it can be hit. Everything is placed from
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
--
-- THE FOUR TRAINING ZONES (owner, 2026-11-20, a 2 x 2 sketch; Core/TrainingGrounds): the dummy row, the clash
-- dummy (DummyService gives it its beat and flash), the 1v1 bot arena (ring-outs score: `watchRing`) and the
-- recovery cliff, whose side of the lobby is left open: its launch pads throw you off and a body that falls out
-- there is caught and put back on the cliff.
-- THE SKY LEG (Lobby.Sky): the obby jumps out through a gap in the back wall onto floating isles and Bell Rock. A
-- fall out there puts you back on the last checkpoint you stood on; Bell Rock's bell rings when punched (from
-- CombatService.PunchThrown); its glove (the Haymaker) throws whoever stands on its X home onto the Champion's
-- Perch along a fixed arc that their own client flies (LobbyFlight), with the punch shown to everyone (LobbyFx).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lobby = require(ReplicatedStorage.Shared.Core.Lobby)
local LobbyLayout = require(ReplicatedStorage.Shared.Config.LobbyLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local TrainingGrounds = require(ReplicatedStorage.Shared.Core.TrainingGrounds)
local Typography = require(ReplicatedStorage.Shared.Typography)
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

-- THE SOFT PALETTE (owner, 2026-11-19: the lobby in the UI's light colours; design/lobby/village.py has the model's)
local STONE = Color3.fromRGB(246, 238, 224)
local MAT = Color3.fromRGB(165, 223, 236)
local TIMBER = Color3.fromRGB(218, 184, 150)
local EDGE = Color3.fromRGB(250, 223, 127)
local UNDER = Color3.fromRGB(190, 178, 196)
local INK = Color3.fromRGB(67, 54, 90)
local CREAM = Color3.fromRGB(255, 249, 236)

local LobbyService = Knit.CreateService({
	Name = "LobbyService",
})

local dummies: { [Model]: boolean } = {}
-- THE TRAINING SECTIONS (owner, 2026-11-19): every dummy belongs to a section of the training grounds
-- (Lobby.Training, Core/TrainingGrounds). They sleep while nobody is in free practice (`asleep`).
local asleep = false
local emptySince: number? = nil
local SLEEP_AFTER_SECONDS = 4
local onPad: { [Player]: boolean } = {}
-- the zones' colours (the UI's retro comic paints): the arena's bot blue, the clash dummy yellow
local SPAR_COLOUR = Color3.fromRGB(100, 163, 255)
local ATTACKER_COLOUR = Color3.fromRGB(240, 82, 90)
local CLASH_COLOUR = Color3.fromRGB(255, 210, 63)
-- THE SKY LEG: the last checkpoint each player stood on (an index into Lobby.checkpoints), who is on the glove's X,
-- who is flying home, and when each last rang the bell.
local reached: { [Player]: number } = {}
local onGlove: { [Player]: boolean } = {}
local flying: { [Player]: boolean } = {}
local rang: { [Player]: number } = {}
local FLIGHT = "HT_Flight" -- character attribute while the Haymaker's flight carries you
-- THE 1V1 ARENA: its bot, the bot's home, and the bout (the challenger is whoever last stood on the ring).
local ringBot: Model? = nil
local ringBotHome: CFrame? = nil
local ringScore: TextLabel? = nil
local bout = { challenger = nil :: Player?, you = 0, bot = 0, youOn = false, botOut = false }
-- worked out once (the settings never change while the server runs), so the 10-a-second check allocates nothing
local CHECKPOINTS = Lobby.checkpoints(cfg)
local EDGES: { TrainingGrounds.Edge } = {}
for _, section in (cfg.Training and cfg.Training.Sections) or {} do
	local edge = TrainingGrounds.edge(cfg, section)
	if edge then
		table.insert(EDGES, edge)
	end
end
local RING: TrainingGrounds.Ring? = nil
for _, section in (cfg.Training and cfg.Training.Sections) or {} do
	RING = RING or TrainingGrounds.ring(cfg, section)
end

-- Which open edge's air this spot is in, or nil (TrainingGrounds.edgeAt on the cached edges).
local function edgeAt(x: number, z: number): TrainingGrounds.Edge?
	for _, edge in EDGES do
		if x >= edge.x0 and x <= edge.x1 and z >= edge.z0 and z <= edge.z1 then
			return edge
		end
	end
	return nil
end
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
			if ringBot == old then
				ringBot = new
			end
			if asleep then
				service:SetDormant(new, true)
			end
		end
	end)
	local training: any = cfg.Training
	local floor = TrainingGrounds.floorY(cfg)
	local staggerMax = GameConfig.Stagger.Max
	for _, spot in TrainingGrounds.dummies(cfg) do
		task.spawn(function()
			local at = Vector3.new(spot.x, floor + spot.up + STAND_HEIGHT, spot.z)
			local facing = Vector3.new(spot.faceX, 0, spot.faceZ)
			local spec: any = {
				name = spot.name,
				home = CFrame.lookAt(at, at + facing),
				startStagger = math.floor(spot.staggerShare * staggerMax + 0.5),
				resetSeconds = training.ResetSeconds,
				fallY = cfg.FloorY - cfg.FallDepth,
			}
			if spot.kind == "Still" then
				spec.stationary = true
			elseif spot.kind == "Patrol" and spot.toX and spot.toZ then
				spec.patrol =
					{ ax = spot.x, az = spot.z, bx = spot.toX, bz = spot.toZ, speed = spot.speed }
			elseif spot.kind == "Spar" or spot.kind == "Attacker" or spot.kind == "Clash" then
				spec.trainer =
					{ bot = training.Bots[spot.kind], x = spot.x, z = spot.z, radius = spot.radius }
				spec.colour = if spot.kind == "Spar"
					then SPAR_COLOUR
					elseif spot.kind == "Clash" then CLASH_COLOUR
					else ATTACKER_COLOUR
			end
			local model = service:Spawn(spec)
			dummies[model] = true
			local section = TrainingGrounds.byKey(cfg, spot.section)
			if spot.kind == "Spar" and section and section.Ring then
				ringBot, ringBotHome = model, spec.home
			end
			if asleep then
				service:SetDormant(model, true)
			end
		end)
	end
end

-- Wakes or sleeps every section dummy. Asleep, a dummy is anchored at home and DummyService skips it.
local function setAsleep(on: boolean)
	if asleep == on then
		return
	end
	asleep = on
	local service = Knit.GetService("DummyService")
	for model in dummies do
		service:SetDormant(model, on)
	end
end

-- THE SECTION SIGNS: a soft card on each section's timber board (the Blender model): cream, rounded, a border in
-- the section's pastel, plum lettering. Static text, drawn only from near (Sign.Distance).
local function spawnSigns()
	local training: any = cfg.Training
	local sign = training.Sign
	local holder = Instance.new("Folder")
	holder.Name = "SectionSigns"
	local floor = TrainingGrounds.floorY(cfg)
	local toArena = Vector3.new(0, 0, if cfg.ViewEdgeZ >= 0 then -1 else 1)
	local ink = Color3.fromHex(sign.Ink)
	-- OFF (owner, 2026-11-19: "remove the signs"): Sign.Enabled false means no boards in the model and no cards here
	for _, spot in if sign.Enabled then TrainingGrounds.signs(cfg) else {} do
		local at = Vector3.new(spot.x, floor + sign.Up, spot.z) + toArena * 0.02
		local part = Instance.new("Part")
		part.Name = spot.key
		part.Size = Vector3.new(sign.Width, sign.Height, 0.1)
		part.CFrame = CFrame.lookAt(at, at + toArena)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.MaxDistance = sign.Distance
		gui.Parent = part
		local card = Instance.new("Frame")
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.Size = UDim2.new(1, -12, 1, -12)
		card.BackgroundColor3 = Color3.fromHex(sign.Card)
		card.BorderSizePixel = 0
		card.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 6
		stroke.Color = Color3.fromHex(spot.colour):Lerp(ink, 0.12)
		stroke.Parent = card
		local title = Instance.new("TextLabel")
		title.Position = UDim2.new(0, 12, 0, 12)
		title.Size = UDim2.new(1, -24, 0.5, -10)
		title.BackgroundTransparency = 1
		title.Text = spot.title
		title.TextColor3 = ink
		title.FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
		title.TextScaled = true
		title.Parent = card
		local hint = Instance.new("TextLabel")
		hint.Position = UDim2.new(0, 14, 0.5, 4)
		hint.Size = UDim2.new(1, -28, 0.5, -16)
		hint.BackgroundTransparency = 1
		hint.Text = spot.hint
		hint.TextColor3 = ink
		hint.TextTransparency = 0.15
		hint.FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium)
		hint.TextScaled = true
		hint.TextWrapped = true
		hint.Parent = card
		part.Parent = holder
	end

	-- flat lettering on the floor: the knockback lane's distances and the launch pad's name
	local function floorText(
		text: string,
		x: number,
		y: number,
		z: number,
		wide: number,
		tall: number
	): TextLabel
		local part = Instance.new("Part")
		part.Name = "FloorText"
		-- a part's top face draws its text along the part's length with the top of the letters toward -X, so
		-- the length runs across the reader's view (they face away from the arena) and -X points away from them
		part.Size = Vector3.new(tall, 0.05, wide)
		local spotAt = Vector3.new(x, y + 0.2, z)
		part.CFrame = CFrame.lookAt(spotAt, spotAt + Vector3.new(toArena.Z, 0, 0))
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0
		gui.MaxDistance = sign.Distance
		gui.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		Typography.apply(label, "World")
		label.Text = text
		label.TextColor3 = ink
		label.TextScaled = true
		label.Parent = gui
		part.Parent = holder
		return label
	end
	for _, section in training.Sections do
		for _, mark in TrainingGrounds.marks(cfg, section) do
			floorText(`{mark.studs}`, mark.x, floor, mark.z, 5, 2.2)
		end
		for _, pad in TrainingGrounds.pads(cfg, section) do
			-- the name just behind the pad, toward the arena side, read by someone walking up to it
			floorText(pad.title, pad.x, pad.y, pad.z + toArena.Z * (pad.radius + 1.6), 7, 2.4)
		end
		local ring = TrainingGrounds.ring(cfg, section)
		if ring then
			ringScore = floorText("1V1: STEP UP", ring.scoreX, ring.y, ring.scoreZ, 13, 2.6)
		end
	end
	holder.Parent = folder
end

-- FALLING PETALS (owner, 2026-11-19: sakura, "flower petals vfx falling"): one ParticleEmitter under each blossom
-- canopy the Blender script marked (Lobby.Petals.Spots). A soft round dot squashed into a petal, tumbling down
-- and drifting with the lobby's wind. Few particles (Rate x Lifetime at most ~70 for the great tree), no light, no
-- collision, and Roblox thins particles by itself on low graphics settings, which is the phone path.
local function spawnPetals()
	local petals: any = cfg.Petals
	if not petals or not petals.Enabled then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "Petals"
	for index, spot in petals.Spots do
		local part = Instance.new("Part")
		part.Name = `Canopy{index}`
		part.Size = Vector3.new(spot.Radius * 2, 0.2, spot.Radius * 2)
		part.CFrame =
			CFrame.new(cfg.CenterX + spot.X, cfg.FloorY + spot.Up, cfg.ViewEdgeZ + spot.Back)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Petals"
		emitter.Texture = petals.Texture
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Rate = petals.RatePerStud * spot.Radius
		emitter.Lifetime = NumberRange.new(petals.Lifetime * 0.8, petals.Lifetime)
		emitter.Speed = NumberRange.new(1.5, 3.5)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Acceleration = Vector3.new(petals.Drift, -petals.Fall, petals.Drift * 0.3)
		emitter.Drag = 0.6
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-140, 140)
		emitter.Size = NumberSequence.new(petals.Size)
		emitter.Squash = NumberSequence.new(-0.45)
		emitter.Color =
			ColorSequence.new(Color3.fromHex(petals.Colour), Color3.fromHex(petals.ColourEnd))
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.08, 0.1),
			NumberSequenceKeypoint.new(0.85, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.LightEmission = 0
		emitter.LightInfluence = 0.5
		emitter.Parent = part
		part.Parent = holder
	end
	holder.Parent = folder
end

-- THE LAUNCH PAD on the ring-out deck: step onto it and you're thrown off the deck, the way a hit would throw
-- you, to practise getting back. Once per step-on, only on foot on the deck, only in free practice.
local function checkPads(player: Player, character: Model, position: Vector3, free: boolean)
	local training: any = cfg.Training
	local on = false
	for _, section in training.Sections do
		for _, pad in TrainingGrounds.pads(cfg, section) do
			if
				free
				and math.abs(position.Y - (pad.y + STAND_HEIGHT)) <= 2.5
				and (position.X - pad.x) ^ 2 + (position.Z - pad.z) ^ 2 <= pad.radius * pad.radius
			then
				on = true
				if not onPad[player] then
					Knit.GetService("KnockbackService")
						:Launch(character, pad.dirX * pad.out, pad.dirZ * pad.out, pad.up, pad.up)
				end
			end
		end
	end
	onPad[player] = if on then true else nil
end

-- Puts a body somewhere, facing that way, standing, with its momentum and stagger gone: a catch after a fall.
local function putBack(player: Player, character: Model, at: Vector3, face: Vector3)
	local root = Combatants.rootOf(character)
	if not root then
		return
	end
	Knit.GetService("KickService"):Release(character)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(
		CFrame.lookAt(at, at + face) * root.CFrame:ToObjectSpace(character:GetPivot())
	)
	Knit.GetService("StaggerService"):Reset(character)
	LobbyService._bodyReset:FireClient(player, face, "moved")
end

-- THE SKY LEG, every check for one player: the catch under the isles, the checkpoints, the glove's X. Returns
-- true when it moved them (nothing else should look at them this check).
local function checkSky(player: Player, character: Model, position: Vector3): boolean
	local sky: any = cfg.Sky
	if not sky or not sky.Enabled or flying[player] then
		return false
	end
	local marks = CHECKPOINTS
	if Lobby.inSky(cfg, position.X, position.Z) and position.Y < cfg.FloorY - sky.CatchBelow then
		local mark = marks[reached[player] or 1]
		if mark then
			local back = Vector3.new(0, 0, if cfg.ViewEdgeZ >= 0 then 1 else -1)
			putBack(player, character, Vector3.new(mark.x, mark.y + STAND_HEIGHT, mark.z), back)
		end
		return true
	end
	for index, mark in marks do
		if Lobby.standingOn(mark, position.X, position.Y - STAND_HEIGHT, position.Z, 2.5) then
			reached[player] = index
		end
	end
	local glove = sky.Glove
	local padX, padZ = cfg.CenterX + glove.Pad.X, cfg.ViewEdgeZ + glove.Pad.Back
	local padY = cfg.FloorY + glove.Up
	local on = math.abs(position.Y - STAND_HEIGHT - padY) <= 2.5
		and (position.X - padX) ^ 2 + (position.Z - padZ) ^ 2 <= glove.Pad.Radius ^ 2
	if on and not onGlove[player] then
		onGlove[player] = true
		LobbyService:FlyHome(player)
		return true
	end
	onGlove[player] = if on then true else nil
	return false
end

-- THE RECOVERY CLIFF's catch: a body that falls out past the open edge is put back on the cliff, facing the edge.
local function checkEdge(player: Player, character: Model, position: Vector3): boolean
	local edge = edgeAt(position.X, position.Z)
	if edge and position.Y < edge.catchY and not flying[player] then
		putBack(
			player,
			character,
			Vector3.new(edge.returnX, edge.returnY + STAND_HEIGHT, edge.returnZ),
			Vector3.new(edge.faceX, 0, 0)
		)
		return true
	end
	return false
end

-- THE 1V1 ARENA's bout, every check: the challenger is the player who last stood on the ring (in free practice).
-- Knocking the bot off scores for them, and the bot is put back after ReturnSeconds; going off yourself scores for
-- the bot. Leaving training ends the bout. The score is written on the ring's floor, by its steps.
local function watchRing()
	local ring = RING
	if not ring then
		return
	end
	local function show()
		if ringScore then
			ringScore.Text = if bout.challenger
				then `YOU {bout.you}  -  {bout.bot} BOT`
				else "1V1: STEP UP"
		end
	end
	-- who is on the ring now
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and Combatants.rootOf(character)
		if
			root
			and player:GetAttribute(FREE) == true
			and TrainingGrounds.onRing(
				ring,
				root.Position.X,
				root.Position.Y - STAND_HEIGHT,
				root.Position.Z
			)
		then
			if bout.challenger ~= player then
				bout.challenger, bout.you, bout.bot, bout.botOut = player, 0, 0, false
			end
			bout.youOn = true
			show()
		end
	end
	local challenger = bout.challenger
	if challenger and (challenger.Parent == nil or challenger:GetAttribute(FREE) ~= true) then
		bout.challenger, bout.you, bout.bot, bout.youOn = nil, 0, 0, false
		show()
		return
	end
	-- the challenger went off
	if challenger and bout.youOn then
		local root = challenger.Character and Combatants.rootOf(challenger.Character)
		if root and TrainingGrounds.offRing(ring, root.Position.Y - STAND_HEIGHT) then
			bout.youOn = false
			bout.bot += 1
			show()
		end
	end
	-- the bot went off
	local bot = ringBot
	local botRoot = bot and bot.Parent and Combatants.rootOf(bot)
	if bot and botRoot and not bout.botOut and not botRoot.Anchored then
		if TrainingGrounds.offRing(ring, botRoot.Position.Y - STAND_HEIGHT) then
			bout.botOut = true
			if challenger then
				bout.you += 1
				show()
			end
			task.delay(ring.returnSeconds, function()
				if ringBot and ringBot.Parent and ringBotHome then
					Knit.GetService("DummyService"):PlaceAt(ringBot, ringBotHome)
				end
				bout.botOut = false
			end)
		end
	end
end

-- THE STATION KEEPERS (owner, 2026-11-18: every stall has a use). One blocky figure behind each stall's counter
-- and at each signpost, from Lobby.Npcs (written by design/lobby/village.py: where the stations are). Each carries a ProximityPrompt
-- with the attribute HT_Page; the client's NpcController opens that page of the menu. They are scenery: seven
-- anchored parts, no Humanoid, nothing collides, nothing to hit.
local NPC_SKIN = Color3.fromRGB(240, 206, 170)
local NPC_CLOTH = {
	moves = Color3.fromRGB(245, 166, 192),
	more = Color3.fromRGB(165, 223, 236),
	classes = Color3.fromRGB(218, 211, 247),
	shop = Color3.fromRGB(250, 223, 127),
	ranked = Color3.fromRGB(163, 226, 187),
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
		label.TextColor3 = CREAM
		label.TextStrokeColor3 = INK
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
		back.BackgroundColor3 = INK
		back.BackgroundTransparency = 0.2
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
			row.TextColor3 = CREAM
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
	self._flight = Net.server("LobbyFlight")
	self._fx = Net.server("LobbyFx")
end

--- THE HAYMAKER: the glove on Bell Rock punches this player home. Their own client flies them along the arc
--- (Lobby.flightPoint, so every client draws the same path); when it ends the server puts them on its last point,
--- the Champion's Perch, facing the arena, with nothing left over from the flight.
function LobbyService:FlyHome(player: Player)
	local sky: any = cfg.Sky
	local character = player.Character
	local root = character and Combatants.rootOf(character)
	if not sky or not character or not root or flying[player] then
		return
	end
	local glove = sky.Glove
	local from = Vector3.new(
		cfg.CenterX + glove.Pad.X,
		cfg.FloorY + glove.Up + STAND_HEIGHT,
		cfg.ViewEdgeZ + glove.Pad.Back
	)
	local to = Vector3.new(
		cfg.CenterX + glove.To.X,
		cfg.FloorY + glove.To.Up + STAND_HEIGHT,
		cfg.ViewEdgeZ + glove.To.Back
	)
	flying[player] = true
	character:SetAttribute(FLIGHT, true)
	Knit.GetService("KickService"):Release(character)
	Knit.GetService("StaggerService"):Reset(character)
	self._fx:FireAllClients("glove", player)
	self._flight:FireClient(player, from, to, glove.Apex, glove.Seconds)
	task.delay(glove.Seconds + 0.2, function()
		flying[player] = nil
		if character.Parent then
			character:SetAttribute(FLIGHT, nil)
			local body = Combatants.rootOf(character)
			if body and (body.Position - to).Magnitude > 6 then
				-- their client never flew them (or lagged far behind): put them where the flight ends
				local face = Vector3.new(0, 0, if cfg.ViewEdgeZ >= 0 then -1 else 1)
				putBack(player, character, to, face)
			else
				self._bodyReset:FireClient(
					player,
					Vector3.new(0, 0, if cfg.ViewEdgeZ >= 0 then -1 else 1),
					"moved"
				)
			end
		end
	end)
end

function LobbyService:KnitStart()
	if not cfg.Enabled then
		return
	end
	build()
	asleep = cfg.Training.SleepWhenEmpty == true
	spawnDummies()
	spawnNpcs()
	spawnBoards()
	spawnSigns()
	spawnPetals()
	Players.PlayerRemoving:Connect(function(player)
		onPad[player] = nil
		reached[player] = nil
		onGlove[player] = nil
		flying[player] = nil
		rang[player] = nil
	end)
	-- THE BELL on Bell Rock rings when someone punches within reach of it, facing it, at most once per Cooldown
	local sky: any = cfg.Sky
	if sky and sky.Enabled then
		local bell = sky.Bell
		local bellAt =
			Vector3.new(cfg.CenterX + bell.X, cfg.FloorY + bell.Up + 4, cfg.ViewEdgeZ + bell.Back)
		Knit.GetService("CombatService").PunchThrown.Event
			:Connect(function(attacker: Model, player: Player)
				local root = Combatants.rootOf(attacker)
				if not root or not self:IsIn(player) then
					return
				end
				local to = bellAt - root.Position
				local flat = Vector3.new(to.X, 0, to.Z)
				local look = root.CFrame.LookVector
				if
					flat.Magnitude <= bell.Reach
					and math.abs(to.Y) <= 6
					and flat.Magnitude > 0.1
					and flat.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) > 0.3
					and os.clock() - (rang[player] or -math.huge) >= bell.Cooldown
				then
					rang[player] = os.clock()
					self._fx:FireAllClients("bell", player)
				end
			end)
	end

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
		local training = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and Combatants.rootOf(character)
			if
				character
				and root
				and not round:IsStanding(character)
				and (
					checkSky(player, character, root.Position)
					or checkEdge(player, character, root.Position)
				)
			then
				root = nil -- moved this check: looked at again next time
			end
			if character and root then
				local position = root.Position
				local edgeAir = edgeAt(position.X, position.Z)
				local inside = (
					Lobby.contains(cfg, position.X, position.Z)
					or Lobby.inSky(cfg, position.X, position.Z)
					or edgeAir ~= nil
				)
					and (position.Y > cfg.FloorY - cfg.FallDepth or flying[player] == true)
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
					and (
						Lobby.inTraining(cfg, position.X, position.Z - (zone.Inset or 0))
						-- launched off the recovery cliff you are still training, out in its air
						or edgeAir ~= nil
					)
				local free = inFootprint
					and (
						player:GetAttribute(FREE) == true
						or position.Y - floor < (zone.EnterHeight or 8) + STAND_HEIGHT
					)
				if free ~= (player:GetAttribute(FREE) == true) then
					player:SetAttribute(FREE, if free then true else nil)
					if not free then
						-- what the bots did to you in training stays in training
						Knit.GetService("StaggerService"):Reset(character)
					end
				end
				if free then
					training += 1
				end
				checkPads(player, character, position, free)
			end
		end
		watchRing()
		-- The section dummies wake the moment someone walks in, and sleep a few seconds after the last one leaves.
		if cfg.Training.SleepWhenEmpty then
			if training > 0 then
				emptySince = nil
				setAsleep(false)
			else
				local now = os.clock()
				emptySince = emptySince or now
				if now - emptySince >= SLEEP_AFTER_SECONDS then
					setAsleep(true)
				end
			end
		end
	end)
end

return LobbyService
