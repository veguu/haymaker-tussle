--!strict
-- TrainingService - the training arena beside the 1v1 arena: its floors and markings, its stations and
-- controls, and who counts as being in it. Everything is placed from GameConfig.Training through
-- Core/TrainingLayout. Nothing here decides a hit: dummies are real combatants, and launch pads send the
-- same knockback message a real punch does.
--
-- Controls are flat pads on the floor: walk onto one and it happens, once, until you step off. Nothing
-- can bump into them or be hidden behind them.
--
-- FOR THE ROUND STEP: a player with the HT_InTraining attribute isn't in the round, dummies have
-- Combatants.DUMMY_ATTRIBUTE and must never count for anything, and `LeaveTraining` takes someone out.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local TrainingLayout = require(ReplicatedStorage.Shared.Core.TrainingLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg: any = GameConfig.Training
local arena = GameConfig.Arena
local staggerMax = GameConfig.Stagger.Max
local IN_TRAINING = "HT_InTraining"
local FLOOR_THICKNESS = 4
local STAND_HEIGHT = 3 -- a standing body's root is this far above the floor
local CHECK_SECONDS = 0.1
local LAUNCH_SETTLE_SECONDS = 0.05 -- the move arrives first, then the launch

local FLOOR = Color3.fromRGB(62, 72, 92)
local FLOOR_HUB = Color3.fromRGB(48, 56, 74)
local BRIDGE = Color3.fromRGB(78, 88, 108)
local RIM = Color3.fromRGB(255, 200, 80)
local RING = Color3.fromRGB(120, 134, 160)
local WHITE = Color3.fromRGB(240, 244, 250)
local CONTROL = Color3.fromRGB(90, 220, 255)
local EXIT = Color3.fromRGB(120, 255, 150)
local PAD = Color3.fromRGB(255, 120, 90)
local REACH = Color3.fromRGB(255, 120, 200)

local TrainingService = Knit.CreateService({
	Name = "TrainingService",
})

type Pad = {
	x: number,
	z: number,
	radius: number,
	run: (player: Player) -> (),
	inside: { [Player]: boolean },
}

local byStation: { [string]: { Model } } = {}
local pads: { Pad } = {}
local currentStation: { [Player]: string } = {}
local folder: Folder

-- A flat disc. A solid one's top is the floor; a thin one is only a marking and nothing can touch it.
local function disc(
	name: string,
	x: number,
	z: number,
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
	part.CFrame = CFrame.new(x, cfg.CenterY + lift - thickness / 2, z)
		* CFrame.Angles(0, 0, math.pi / 2)
	part.Anchored = true
	part.CanCollide = solid
	part.CanQuery = solid
	part.CanTouch = false
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

-- A ring painted on the floor: a coloured disc, with the floor's colour on top of it.
local function ring(
	name: string,
	x: number,
	z: number,
	radius: number,
	width: number,
	lift: number,
	colour: Color3,
	inside: Color3
)
	disc(name, x, z, radius, lift, colour, false)
	disc(`{name}Inner`, x, z, math.max(radius - width, 0.05), lift + 0.01, inside, false)
end

-- Flat text on the floor. `lookX`, `lookZ` is the way someone reading it faces.
local function floorText(
	text: string,
	x: number,
	z: number,
	width: number,
	height: number,
	lookX: number,
	lookZ: number,
	colour: Color3,
	lift: number?
): Part
	local part = Instance.new("Part")
	part.Name = "Text"
	-- A part's top face draws its text along the part's length, with the top of the letters toward -X. So
	-- the length runs across the reader's view, and -X points away from them.
	part.Size = Vector3.new(height, 0.02, width)
	local at = Vector3.new(x, cfg.CenterY + (lift or 0.2), z)
	part.CFrame = CFrame.lookAt(at, at + Vector3.new(-lookZ, 0, lookX))
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.MaxDistance = cfg.SignDistance
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = colour
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	part.Parent = folder
	return part
end

-- A pad on the floor. With `run`, the server acts when someone walks onto it. With a client action, the
-- player's own client does: only things only they can see. Returns its label, for pads that change.
local function padControl(
	x: number,
	z: number,
	title: string,
	colour: Color3,
	lookX: number,
	lookZ: number,
	run: ((player: Player) -> ())?,
	clientAction: string?
): TextLabel
	local radius = cfg.PadRadius
	local mark = disc(`Pad {title}`, x, z, radius, 0.3, colour, false)
	disc(`Pad {title} Inner`, x, z, radius - 0.5, 0.31, FLOOR_HUB, false)
	local text = floorText(title, x, z, radius * 1.7, radius * 1.1, lookX, lookZ, colour, 0.33)
	if clientAction then
		mark:SetAttribute("HT_ClientAction", clientAction)
		mark:SetAttribute("HT_PadRadius", radius)
		CollectionService:AddTag(mark, "HT_ClientPad")
	end
	if run then
		table.insert(pads, { x = x, z = z, radius = radius, run = run, inside = {} })
	end
	return (text:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui):FindFirstChildOfClass(
		"TextLabel"
	) :: TextLabel
end

-- Who has just walked onto a pad. It only works from the floor, and only once until they've stepped off.
local function checkPads()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and Combatants.rootOf(character)
		if root and character and Combatants.isAlive(character) then
			local position = root.Position
			local onFloor = math.abs(position.Y - (cfg.CenterY + STAND_HEIGHT)) <= 2.5
			for _, pad in pads do
				local dx, dz = position.X - pad.x, position.Z - pad.z
				local isOn = onFloor and dx * dx + dz * dz <= pad.radius * pad.radius
				if isOn and not pad.inside[player] then
					pad.inside[player] = true
					pad.run(player)
				elseif not isOn then
					pad.inside[player] = nil
				end
			end
		end
	end
end

-- Puts a player somewhere with nothing left over from what they were doing.
local function movePlayer(
	player: Player,
	x: number,
	height: number,
	z: number,
	faceX: number,
	faceZ: number,
	reason: string,
	detail: string?
)
	local character = player.Character
	local root = character and Combatants.rootOf(character)
	if not character or not root then
		return
	end
	Knit.GetService("KickService"):Release(character)
	Knit.GetService("ClashService"):EndFor(character, "fell")
	local at = Vector3.new(x, cfg.CenterY + STAND_HEIGHT + height, z)
	local spot = CFrame.lookAt(at, at + Vector3.new(faceX, 0, faceZ))
	character:PivotTo(spot * root.CFrame:ToObjectSpace(character:GetPivot()))
	TrainingService._bodyReset:FireClient(player, Vector3.new(faceX, 0, faceZ), reason, detail)
end

--- Is this player in the training arena?
function TrainingService:IsIn(player: Player): boolean
	return player:GetAttribute(IN_TRAINING) == true
end

--- May these two hit each other? Nobody reaches across the boundary, dummies don't fight each other, and
--- two players in training only spar if that's turned on.
function TrainingService:AllowsFight(a: Model, b: Model): boolean
	local playerA, playerB = Combatants.playerOf(a), Combatants.playerOf(b)
	if not playerA and not playerB then
		return false
	end
	if not playerA or not playerB then
		return self:IsIn((playerA or playerB) :: Player) and cfg.DummiesEnabled
	end
	local inA, inB = self:IsIn(playerA), self:IsIn(playerB)
	if inA ~= inB then
		return false
	end
	return if inA then cfg.SparringEnabled else GameConfig.Debug.TestFloor
end

--- Puts someone back in the training arena, at the station they were last on. For respawning there.
function TrainingService:ReturnToStation(player: Player)
	local key = currentStation[player]
	local station = key and TrainingLayout.stationByKey(cfg, key)
	local x, z, faceX, faceZ
	if station then
		x, z, faceX, faceZ = TrainingLayout.entry(cfg, station)
	else
		x, z, faceX, faceZ = TrainingLayout.hubEntry(cfg)
	end
	movePlayer(player, x, 0, z, faceX, faceZ, "fell")
	local character = player.Character
	if character then
		Knit.GetService("StaggerService"):Reset(character)
	end
end

--- Takes someone out of training, back to the gate on the other arena.
function TrainingService:LeaveTraining(player: Player)
	player:SetAttribute(IN_TRAINING, nil)
	currentStation[player] = nil
	local x, z, faceX, faceZ = TrainingLayout.arenaArrival(cfg, arena)
	movePlayer(player, x, 0, z, faceX, faceZ, "moved")
	local character = player.Character
	if character then
		Knit.GetService("StaggerService"):Reset(character)
	end
end

local function enterTraining(player: Player)
	player:SetAttribute(IN_TRAINING, true)
	currentStation[player] = "Hub"
	local x, z, faceX, faceZ = TrainingLayout.hubEntry(cfg)
	movePlayer(player, x, 0, z, faceX, faceZ, "moved")
	local character = player.Character
	if character then
		Knit.GetService("StaggerService"):Reset(character)
	end
end

local function resetStation(player: Player, key: string)
	for _, model in byStation[key] or {} do
		Knit.GetService("DummyService"):RequestReset(model)
	end
	local character = player.Character
	if character then
		Knit.GetService("StaggerService"):Reset(character)
	end
end

-- A launch pad: to the same spot, with the same stagger, then the same message a punch sends.
local function launchFrom(player: Player, station: any, pad: any)
	local character = player.Character
	local root = character and Combatants.rootOf(character)
	if not character or not root then
		return
	end
	local spot = TrainingLayout.pad(cfg, station, pad)
	movePlayer(
		player,
		spot.startX,
		pad.HeightStuds,
		spot.startZ,
		-spot.dirX,
		-spot.dirZ,
		"launch",
		pad.Name
	)
	Knit.GetService("StaggerService")
		:Set(character, math.floor(pad.StaggerShare * staggerMax + 0.5), false)
	if pad.Launched then
		Knit.GetService("KickService"):MarkLaunched(character, character)
	end
	task.delay(LAUNCH_SETTLE_SECONDS, function()
		if character.Parent then
			Knit.GetService("KnockbackService"):Launch(
				character,
				spot.dirX * pad.OutwardSpeed,
				spot.dirZ * pad.OutwardSpeed,
				pad.UpSpeed,
				pad.UpSpeed
			)
		end
	end)
end

-- Numbered rings out from a station's centre, so a launch can be read at a glance.
local function distanceMarks(station: any)
	local x, z, outX, outZ = TrainingLayout.stationCenter(cfg, station)
	local radius = cfg.MarkerStep
	local index = 0
	while radius < station.Radius - 1 do
		ring(`Ring{radius}`, x, z, radius, 0.3, 0.02 + index * 0.02, RING, FLOOR)
		local labelX, labelZ = TrainingLayout.place(cfg, station, radius - 1.2, -2)
		floorText(tostring(radius), labelX, labelZ, 4, 2, outX, outZ, RING, 0.15)
		radius += cfg.MarkerStep
		index += 1
	end
end

local function buildStation(station: any)
	local x, z, outX, outZ = TrainingLayout.stationCenter(cfg, station)
	-- The rim is the floor itself, so the edge you can see is the edge you can stand on.
	disc(`Station {station.Key}`, x, z, station.Radius, 0, RIM, true)
	disc(`Station {station.Key} Top`, x, z, station.Radius - cfg.RimWidth, 0.01, FLOOR, false)
	distanceMarks(station)

	-- The bridge overlaps both floors, so there's no gap to catch on.
	local length = cfg.RingDistance
	local middle = Vector3.new(
		cfg.CenterX + outX * length / 2,
		cfg.CenterY - FLOOR_THICKNESS / 2,
		cfg.CenterZ + outZ * length / 2
	)
	local bridge = Instance.new("Part")
	bridge.Name = `Bridge {station.Key}`
	bridge.Size =
		Vector3.new(cfg.BridgeWidth, FLOOR_THICKNESS, length - station.Radius - cfg.HubRadius + 4)
	local hubGap = (length - station.Radius - cfg.HubRadius) / 2 + cfg.HubRadius
	local span = Vector3.new(cfg.CenterX + outX * hubGap, middle.Y, cfg.CenterZ + outZ * hubGap)
	bridge.CFrame = CFrame.lookAt(span, span + Vector3.new(outX, 0, outZ))
	bridge.Anchored = true
	bridge.CanTouch = false
	bridge.Color = BRIDGE
	bridge.Material = Enum.Material.SmoothPlastic
	bridge.Parent = folder

	local hubLabelAt = cfg.HubRadius - 7
	floorText(
		`{station.Key}  {station.Title}`,
		cfg.CenterX + outX * hubLabelAt,
		cfg.CenterZ + outZ * hubLabelAt,
		24,
		3.6,
		outX,
		outZ,
		WHITE
	)
	local titleX, titleZ = TrainingLayout.place(cfg, station, -(station.Radius - 7), 0)
	floorText(`{station.Key}  {station.Title}`, titleX, titleZ, 30, 4, outX, outZ, WHITE)
	local purposeX, purposeZ = TrainingLayout.place(cfg, station, -(station.Radius - 11.5), 0)
	floorText(station.Purpose, purposeX, purposeZ, 44, 2.6, outX, outZ, RING)

	local resetX, resetZ = TrainingLayout.stationPad(cfg, station, cfg.PadRadius * 3)
	if station.Key == cfg.Recovery.StationKey then
		padControl(
			resetX,
			resetZ,
			"Back to the ledge",
			CONTROL,
			outX,
			outZ,
			function(player: Player)
				local entryX, entryZ, faceX, faceZ = TrainingLayout.entry(cfg, station)
				movePlayer(player, entryX, 0, entryZ, faceX, faceZ, "moved")
				local character = player.Character
				if character then
					Knit.GetService("StaggerService"):Reset(character)
				end
			end
		)
	else
		padControl(
			resetX,
			resetZ,
			`Reset {station.Key}`,
			CONTROL,
			outX,
			outZ,
			function(player: Player)
				resetStation(player, station.Key)
			end
		)
	end

	for _, dummy in station.Dummies do
		local dummyX, dummyZ = TrainingLayout.place(cfg, station, dummy.Forward, dummy.Right)
		if station.Key == cfg.HitboxStationKey then
			-- The real reach, drawn from the real settings.
			for index, reach in TrainingLayout.reachRings(GameConfig.Punch) do
				ring(
					`Reach{reach.name}`,
					dummyX,
					dummyZ,
					reach.radius,
					0.2,
					0.2 + index * 0.02,
					REACH,
					FLOOR
				)
				local labelX, labelZ = TrainingLayout.place(
					cfg,
					station,
					dummy.Forward + reach.radius - 0.6,
					-reach.radius - 2.6
				)
				floorText(
					`{reach.name} {reach.radius}`,
					labelX,
					labelZ,
					7,
					1.1,
					outX,
					outZ,
					REACH,
					0.3
				)
			end
			for _, spot in TrainingLayout.standSpots(GameConfig.Punch) do
				local spotX, spotZ = TrainingLayout.place(
					cfg,
					station,
					dummy.Forward - spot.forward,
					dummy.Right + spot.right
				)
				disc(`Stand {spot.name}`, spotX, spotZ, 0.7, 0.35, EXIT, false)
				floorText(spot.name, spotX, spotZ - 0.0, 5, 0.9, outX, outZ, WHITE, 0.37)
			end
		elseif dummy.StartStaggerShare then
			local labelX, labelZ =
				TrainingLayout.place(cfg, station, dummy.Forward - 6, dummy.Right)
			floorText(
				`{dummy.Name}: {TrainingLayout.startStagger(dummy, staggerMax)}`,
				labelX,
				labelZ,
				12,
				1.8,
				outX,
				outZ,
				WHITE
			)
		else
			ring(`Mark {dummy.Name}`, dummyX, dummyZ, 2.2, 0.2, 0.25, REACH, FLOOR)
		end
	end
end

local function buildHub()
	disc("Hub", cfg.CenterX, cfg.CenterZ, cfg.HubRadius, 0, RIM, true)
	disc("Hub Top", cfg.CenterX, cfg.CenterZ, cfg.HubRadius - cfg.RimWidth, 0.01, FLOOR_HUB, false)
	floorText("TRAINING", cfg.CenterX, cfg.CenterZ, 26, 6, 1, 0, WHITE)
	floorText(
		"Follow a bridge to a station. Nothing here counts for a round.",
		cfg.CenterX - 5,
		cfg.CenterZ,
		40,
		2.2,
		1,
		0,
		RING
	)
	local hub = TrainingLayout.hubPads(cfg)
	padControl(hub.exit.x, hub.exit.z, "To 1v1 arena", EXIT, -1, 0, function(player: Player)
		TrainingService:LeaveTraining(player)
	end)
	padControl(hub.panel.x, hub.panel.z, "Testing display", CONTROL, 1, 0, nil, "TogglePanel")
	padControl(hub.hitbox.x, hub.hitbox.z, "Hitboxes", CONTROL, 1, 0, nil, "ToggleHitbox")
end

local function buildGate()
	local gateX, gateZ = TrainingLayout.arenaGate(cfg, arena)
	padControl(gateX, gateZ, "TRAINING", EXIT, 1, 0, function(player: Player)
		enterTraining(player)
	end)
end

local function buildMoving(station: any)
	local patrol = cfg.Patrol
	local half = patrol.Length / 2
	local forward = station.Dummies[1].Forward
	local ax, az = TrainingLayout.place(cfg, station, forward, -half)
	local bx, bz = TrainingLayout.place(cfg, station, forward, half)
	local middle = Vector3.new((ax + bx) / 2, cfg.CenterY + 0.2, (az + bz) / 2)
	local strip = Instance.new("Part")
	strip.Name = "Path"
	strip.Size = Vector3.new(1, 0.02, patrol.Length)
	strip.CFrame = CFrame.lookAt(middle, Vector3.new(bx, middle.Y, bz))
	strip.Anchored = true
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CanTouch = false
	strip.Color = REACH
	strip.Material = Enum.Material.SmoothPlastic
	strip.Parent = folder
	disc("Path End A", ax, az, 2, 0.21, REACH, false)
	disc("Path End B", bx, bz, 2, 0.21, REACH, false)
end

local function makeDummies(station: any)
	local dummyService = Knit.GetService("DummyService")
	local _, _, outX, outZ = TrainingLayout.stationCenter(cfg, station)
	byStation[station.Key] = {}
	for _, dummy in station.Dummies do
		local x, z = TrainingLayout.place(cfg, station, dummy.Forward, dummy.Right)
		local patrol = nil
		if dummy.Patrols then
			local half = cfg.Patrol.Length / 2
			local ax, az = TrainingLayout.place(cfg, station, dummy.Forward, -half)
			local bx, bz = TrainingLayout.place(cfg, station, dummy.Forward, half)
			patrol = {
				ax = ax,
				az = az,
				bx = bx,
				bz = bz,
				speed = cfg.Patrol.Speeds[cfg.Patrol.StartIndex].Speed,
			}
			x, z = ax, az
		end
		local position = Vector3.new(x, cfg.CenterY + STAND_HEIGHT, z)
		-- Facing the hub, so it's looking at whoever walks up to it.
		local model = dummyService:Spawn({
			name = dummy.Name,
			home = CFrame.lookAt(position, position - Vector3.new(outX, 0, outZ)),
			startStagger = TrainingLayout.startStagger(dummy, staggerMax),
			resetSeconds = station.ResetSeconds,
			stationary = dummy.Stationary == true,
			patrol = patrol,
		})
		table.insert(byStation[station.Key], model)
	end
end

local function buildControls(station: any)
	local _, _, outX, outZ = TrainingLayout.stationCenter(cfg, station)
	local beside = -cfg.PadRadius * 3
	if station.Key == cfg.HitboxStationKey then
		local x, z = TrainingLayout.stationPad(cfg, station, beside)
		padControl(x, z, "Hitboxes", CONTROL, outX, outZ, nil, "ToggleHitbox")
		local targetX, targetZ = TrainingLayout.stationPad(cfg, station, beside * 2)
		local label: TextLabel
		label = padControl(targetX, targetZ, "Target: stationary", CONTROL, outX, outZ, function()
			local model = byStation[station.Key][1]
			local dummyService = Knit.GetService("DummyService")
			local turnOn = not dummyService:IsStationary(model)
			dummyService:SetStationary(model, turnOn)
			label.Text = if turnOn then "Target: stationary" else "Target: physics"
		end)
	elseif station.Key == cfg.Patrol.StationKey then
		local speeds = cfg.Patrol.Speeds
		local index = cfg.Patrol.StartIndex
		local x, z = TrainingLayout.stationPad(cfg, station, beside)
		local label: TextLabel
		label = padControl(x, z, `Speed: {speeds[index].Name}`, CONTROL, outX, outZ, function()
			index = index % #speeds + 1
			local model = byStation[station.Key][1]
			Knit.GetService("DummyService"):SetPatrolSpeed(model, speeds[index].Speed)
			label.Text = `Speed: {speeds[index].Name}`
		end)
	elseif station.Key == cfg.Recovery.StationKey then
		for _, launch in cfg.Recovery.Pads do
			local spot = TrainingLayout.pad(cfg, station, launch)
			padControl(
				spot.markX,
				spot.markZ,
				launch.Name,
				PAD,
				outX,
				outZ,
				function(player: Player)
					launchFrom(player, station, launch)
				end
			)
			floorText(
				TrainingLayout.padConditions(launch, staggerMax),
				spot.markX - spot.dirX * (cfg.PadRadius + 2),
				spot.markZ - spot.dirZ * (cfg.PadRadius + 2),
				11,
				2.4,
				outX,
				outZ,
				RING
			)
		end
	end
end

function TrainingService:KnitInit()
	self._bodyReset = Net.server("BodyReset")
end

function TrainingService:KnitStart()
	if not cfg.Enabled then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "HT_Training"
	buildGate()
	buildHub()
	for _, station in cfg.Stations do
		buildStation(station)
		if station.Key == cfg.Patrol.StationKey then
			buildMoving(station)
		end
	end
	folder.Parent = workspace

	if cfg.DummiesEnabled then
		Knit.GetService("DummyService").DummyReplaced.Event:Connect(function(old: Model, new: Model)
			for _, models in byStation do
				local index = table.find(models, old)
				if index then
					models[index] = new
				end
			end
		end)
		for _, station in cfg.Stations do
			makeDummies(station)
			buildControls(station)
		end
	end

	-- Who's where. Standing on the training floors is what counts, so anyone who ends up here
	-- is in training however they arrived, and the same for the other arena.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		checkPads()
		elapsed += dt
		if elapsed < CHECK_SECONDS then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and Combatants.rootOf(character)
			if root then
				local position = root.Position
				local onFloor = math.abs(position.Y - (cfg.CenterY + STAND_HEIGHT)) <= 2
				if onFloor then
					local key = TrainingLayout.standingOn(cfg, position.X, position.Z)
					if key then
						currentStation[player] = key
						if not self:IsIn(player) then
							player:SetAttribute(IN_TRAINING, true)
						end
					elseif self:IsIn(player) then
						local fromArena =
							Vector3.new(position.X - arena.CenterX, 0, position.Z - arena.CenterZ)
						if fromArena.Magnitude <= arena.StartRadius then
							player:SetAttribute(IN_TRAINING, nil)
							currentStation[player] = nil
						end
					end
				end
				if self:IsIn(player) and position.Y < cfg.CenterY - cfg.FallDepth then
					self:ReturnToStation(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		currentStation[player] = nil
	end)
end

return TrainingService