--!strict
-- MapService - which arena map is active. The single authority: it swaps the map's geometry and publishes
-- the change, and every client applies that map's environment (EnvironmentController) from what's published.
--
-- WHAT IT PUBLISHES: a Folder ReplicatedStorage.HT_MapState with attributes
--   Map      the active map id (Config/MapEnvironments.Maps key)
--   Seq      bumped on every swap, including a reload of the same map
--   Pending  the incoming map id while a change is under way, "" otherwise
--   SwapAt   server time the geometry will be swapped (clients are covered by then)
-- and the active geometry as workspace.HT_Map (a Model with attributes MapId and Seq), pivoted on the
-- arena's centre.
--
-- A CHANGE: Pending and SwapAt go out at once; clients fade to cover over Maps.FadeOutSeconds; after that
-- plus Maps.SwapBufferSeconds the new geometry is put in place before the old one goes (so there's always a
-- floor), then Map and Seq are published. A newer change made before the swap replaces the older one (only
-- the latest token swaps). Rounds don't start while a change is under way (RoundService asks IsChanging).
--
-- WHEN (Maps.LobbyBetweenRounds, 2026-11-13): the server starts with NO arena, on the lobby's own state
-- (Maps.LobbyMap, a MapEnvironments entry marked `lobby = true`: an environment and no geometry). A finished
-- map stays through RoundOver; when the round ends RoundService sends everyone to the lobby and calls
-- RoundEnded, which changes to the lobby state: the arena's model (floor, rim, obstacles' colliders, dressing)
-- is destroyed behind the fade and every client applies the lobby's environment. The templates in
-- ServerStorage.HT_Maps are never touched. The next arena is loaded only when the next round is actually
-- starting (ChangeForNextRound, as the intermission countdown runs out, before any fighter is placed); the
-- rotation moves on every Maps.ChangeEveryRounds rounds. Too few players -> no round -> the lobby state stays.
-- One change at a time: a change in flight makes RoundEnded and ChangeForNextRound do nothing, and only the
-- latest token ever swaps, so nothing is cleaned up or loaded twice.
-- With LobbyBetweenRounds off, the finished map stays up through the intermission as it used to.
--
-- GEOMETRY: the imported model ServerStorage.HT_Maps.<entry.model> when present; otherwise a stand-in floor
-- in the map's own colours (the old test floor), so the rotation and environments work before the import.
--
-- STUDIO: setting the workspace attribute named Maps.StudioSwitchAttribute (default HT_MapRequest) to a map
-- id - or to "next" - changes the map at once. Studio only, for testing transitions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Envs = require(ReplicatedStorage.Shared.Config.MapEnvironments)
local Environment = require(ReplicatedStorage.Shared.Core.Environment)
local MapObstacles = require(ReplicatedStorage.Shared.Config.MapObstacles)

local cfg: any = GameConfig.Maps
local arena: any = GameConfig.Arena
local CENTER = Vector3.new(arena.CenterX, arena.CenterY, arena.CenterZ)
local FOLDER = "HT_MapState"
local MODEL = "HT_Map"
local FLOOR_THICKNESS = 4

local MapService = Knit.CreateService({
	Name = "MapService",
})

local state: Folder
local active: string? = nil
local seq = 0
local token = 0
local pending: string? = nil
local roundsSinceChange = 0
local lastArena: string? = nil -- the last real arena that was up: the rotation carries on from it

-- Is `id` the lobby's state: an environment with no arena?
local function isLobby(id: string?): boolean
	local entry = id and Envs.Maps[id]
	return entry ~= nil and entry.lobby == true
end

-- The state to sit in between rounds, or nil when the finished map should stay up.
local function lobbyState(): string?
	local id = cfg.LobbyMap
	return if cfg.LobbyBetweenRounds and type(id) == "string" and isLobby(id) then id else nil
end

local function trace(message: string)
	if
		workspace:GetAttribute("HaymakerRoundDebug") or workspace:GetAttribute("HaymakerMapDebug")
	then
		print(`[Map] {message}`)
	end
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- A flat disc whose top sits `lift` above the arena's surface (the stand-in's floor and ring markings).
local function disc(
	parent: Instance,
	name: string,
	radius: number,
	lift: number,
	colour: Color3,
	solid: boolean
)
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
end

-- The old test floor, in the map's colours: a solid disc with a ring every 15 studs. (No test wall: a real
-- arena has nothing standing on it, and fighters got pinned against it.)
local function standIn(model: Model, p: any)
	local floor = rgb(p.standIn.floor)
	local ring = rgb(p.standIn.ring)
	disc(model, "Floor", arena.StartRadius, 0, floor, true)
	local radius = arena.StartRadius - 3
	local index = 0
	while radius > 3 do
		disc(model, `RingOuter{index}`, radius, 0.02 + index * 0.02, ring, false)
		disc(model, `RingInner{index}`, radius - 1, 0.03 + index * 0.02, floor, false)
		radius -= 15
		index += 1
	end
end

-- The map's colliding obstacles (Config/MapObstacles, from design/maps/obstacles.py): one invisible upright
-- Cylinder per rock or stump, matching its round footprint and height. Frictionless, so a body running or
-- dashing into one slides round it instead of sticking; flat-topped and unqueryable, so nothing launches off it and runners bump instead of stepping up. The
-- visible meshes (Obstacles_*) never collide.
local function addObstacles(model: Model, id: string)
	local entry = Envs.Maps[id]
	local list = if entry and entry.codeObstacles == false then nil else MapObstacles[id]
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") and inst.Name:match("^Obstacles_") then
			inst.CanCollide = false
			inst.CanQuery = false
			inst.CanTouch = false
		end
	end
	if not list then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "HT_Obstacles"
	for index, o in list do
		local part = Instance.new("Part")
		part.Name = `Obstacle{index}_{o.kind}`
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(o.h, o.r * 2, o.r * 2)
		part.CFrame = CFrame.new(CENTER + Vector3.new(o.x, o.h / 2, o.z))
			* CFrame.Angles(0, 0, math.pi / 2)
		part.Anchored = true
		part.CanCollide = true
		-- NOT queryable (measured 2026-11-10 in Play): a Humanoid steps up onto anything below its root
		-- (about 3 studs) that its floor check can see, so runners climbed the knee-to-waist rocks and stumps
		-- instead of bumping into them. Unqueryable, the body collides with the side and slides round it
		-- (rise 0 at run speed, a 2-stud hop at most at dash speed); the low slabs are still stepped over.
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.CustomPhysicalProperties = PhysicalProperties.new(2.7, 0, 0, 100, 1)
		part:SetAttribute("HT_Obstacle", true)
		part.Parent = folder
	end
	folder.Parent = model
end

local function buildModel(id: string): Model
	local entry = Envs.Maps[id]
	local maps = ServerStorage:FindFirstChild("HT_Maps")
	local source = entry and entry.model and maps and maps:FindFirstChild(entry.model)
	local model: Model
	if isLobby(id) then
		model = Instance.new("Model") -- no arena: nothing to stand on, nothing to see, nothing to clean up
	elseif source and source:IsA("Model") then
		model = source:Clone()
		model:PivotTo(CFrame.new(CENTER))
		addObstacles(model, id)
	else
		model = Instance.new("Model")
		standIn(model, Environment.resolve(Envs, id))
	end
	model.Name = MODEL
	-- the arena is always loaded for everyone, whole (streaming would deliver it piece by piece)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	return model
end

-- Put `id`'s geometry in place (new before old, so there's always a floor), then publish it.
local function swap(id: string)
	seq += 1
	local model = buildModel(id)
	model:SetAttribute("MapId", id)
	model:SetAttribute("Seq", seq)
	local old = workspace:FindFirstChild(MODEL)
	model.Parent = workspace
	if old then
		old:Destroy()
	end
	active = id
	if not isLobby(id) then
		lastArena = id
	end
	pending = nil
	state:SetAttribute("Pending", "")
	state:SetAttribute("SwapAt", nil)
	state:SetAttribute("Map", id)
	state:SetAttribute("Seq", seq)
	trace(`active {id} (seq {seq})`)
end

local function known(id: string): boolean
	return Envs.Maps[id] ~= nil
end

--- Change to `id` (a reload if it's already active), behind the clients' screen fade.
function MapService:ChangeTo(id: string)
	if not cfg.Enabled then
		return
	end
	if not known(id) then
		warn(`[Map] unknown map "{id}"; using the default stand-in`)
	end
	token += 1
	local mine = token
	pending = id
	local wait = cfg.FadeOutSeconds + cfg.SwapBufferSeconds
	state:SetAttribute("Pending", id)
	state:SetAttribute("SwapAt", workspace:GetServerTimeNow() + wait)
	trace(`changing to {id} in {wait} s (token {mine})`)
	task.delay(wait, function()
		if mine == token then
			swap(id)
		end
	end)
end

--- A round has ended and everyone is back in the lobby. Counts it, then takes the arena away: a change to the
--- lobby's state (its environment, no geometry), behind the fade. Does nothing if that's already where we are
--- or a change is already under way, so a second call can't clean up twice.
function MapService:RoundEnded()
	if not cfg.Enabled then
		return
	end
	roundsSinceChange += 1
	local lobby = lobbyState()
	if lobby and pending == nil and active ~= lobby then
		self:ChangeTo(lobby)
	end
end

--- The next round is about to place its fighters. If the rotation is due (every Maps.ChangeEveryRounds rounds)
--- this starts the change - map and environment together, behind the fade - and returns true; RoundService
--- then waits for IsChanging() to clear before placing anyone on the new map's spawns. Returns false when
--- the current map carries on (so a second call after the swap lets the round start).
function MapService:ChangeForNextRound(): boolean
	if not cfg.Enabled or pending ~= nil then
		return false
	end
	local onLobby = isLobby(active)
	local due = roundsSinceChange >= math.max(cfg.ChangeEveryRounds, 1)
	if not onLobby and not due then
		return false
	end
	local nextId: string
	if lastArena == nil then
		nextId = if known(cfg.StartMap) and not isLobby(cfg.StartMap)
			then cfg.StartMap
			else cfg.Rotation[1]
		roundsSinceChange = 0
	elseif due then
		nextId = Environment.nextMap(cfg.Rotation, lastArena)
		roundsSinceChange = 0
	else
		nextId = lastArena -- the same arena again, loaded fresh
	end
	self:ChangeTo(nextId)
	return true
end

function MapService:IsChanging(): boolean
	return pending ~= nil
end

function MapService:GetActive(): string?
	return active
end

--- Is there an arena up right now (false between rounds, on the lobby's state)?
function MapService:HasArena(): boolean
	return active ~= nil and not isLobby(active)
end

function MapService:KnitInit()
	state = Instance.new("Folder")
	state.Name = FOLDER
	state:SetAttribute("Pending", "")
	state.Parent = ReplicatedStorage
end

function MapService:KnitStart()
	if not cfg.Enabled then
		return
	end
	swap(lobbyState() or (if known(cfg.StartMap) then cfg.StartMap else cfg.Rotation[1]))

	if RunService:IsStudio() then
		local attr = cfg.StudioSwitchAttribute
		workspace:GetAttributeChangedSignal(attr):Connect(function()
			local want = workspace:GetAttribute(attr)
			if type(want) ~= "string" or want == "" then
				return
			end
			workspace:SetAttribute(attr, nil)
			if want == "next" then
				want = Environment.nextMap(cfg.Rotation, pending or active)
			end
			self:ChangeTo(want)
		end)
	end
end

return MapService
