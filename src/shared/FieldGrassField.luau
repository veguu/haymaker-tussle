--!strict
--!native
-- FieldGrassField - the field grass a fighter runs through (owner, 2026-11-20), for a map whose MapEnvironments entry
-- has `fieldGrass`. Knee-to-thigh clumps (never taller than a fighter) over the whole fighting surface, swaying in
-- the map's wind with gust bands rolling across the field, parting round every character and closing slowly
-- behind them, so a runner leaves a wake.
--
-- HOW, AND WHY IT'S CHEAP
-- * Clumps are only drawn in a ring round the camera (`radius`, smaller on phones). The surface is a grid; each cell's
--   clump comes from Core/FieldGrass.clumpAt (the same every time), so the ring can drop and re-take cells freely.
--   Clumps over the ring's last studs sink into the floor, so its edge never pops. The painted floor carries the
--   look past the ring.
-- * One template MeshPart per shape (ReplicatedStorage.HT_FieldGrass), cloned into a pool and reused: identical
--   meshes draw as GPU instances; no texture (vertex shade x the part's Color). Built on this client only (Archivable
--   false), no shadows, no physics, no queries.
-- * Each clump is modelled round its ROOT: wind and parting are one rotation about it. One BulkMoveTo per frame.
--   Moving a part is the cost (MEASURED 2026-11-22: about 3 microseconds a clump; the maths is a tenth of that), so
--   few move each frame: clumps near the camera every frame, mid-range ones every few, far ones about 5 times a
--   second (config tiers), and any clump being parted every frame.
-- * Parting: each frame only the grid cells under each character are looked up, so the cost grows with the number of
--   characters near the camera, not with the grass.
-- If the templates are missing, nothing is built and nothing errors.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Environment = require(script.Parent.Core.Environment)
local FieldGrass = require(script.Parent.Core.FieldGrass)

local FieldGrassField = {}

local REFRESH = 0.2 -- seconds between re-finding the ring's cells and the characters
local BEND_IN = 14 -- 1/s: parted quickly
local BEND_OUT = 2.0 -- and closing slowly (the wake)
local BEND_HEIGHT = 6 -- a root more than this above the floor (in the air) doesn't part the grass
local HIDE = CFrame.new(0, -50000, 0)
local LETTERS = { "A", "B", "C", "D", "E", "F" }

export type Field = {
	step: (self: Field, t: number, camera: Vector3?) -> (),
	destroy: (self: Field) -> (),
	count: (self: Field) -> (number, number),
}

type Entry = {
	key: number,
	part: MeshPart,
	variant: number,
	root: Vector3,
	turn: CFrame, -- its yaw, then from its root to the part's centre (a MeshPart's CFrame is its middle)
	scale: number,
	phase: number,
	along: number, -- its place downwind, in gust lengths (worked out once)
	tier: number, -- 0 near, 1 mid, 2 far: how often it moves (set at each refresh)
	bx: number,
	bz: number,
	last: number,
	fresh: boolean, -- placed this refresh: moved on its first step whatever its tier
}

local function keyOf(ix: number, iz: number): number
	return (ix + 4096) * 8192 + (iz + 4096)
end

--- A field for `model` (the live map, pivoted on the surface's centre) or nil. `cfg` is the entry's fieldGrass,
--- `wind` the map's wind, (semiX, semiZ) its oval.
function FieldGrassField.new(
	model: Instance?,
	cfg: any,
	wind: any,
	semiX: number,
	semiZ: number
): Field?
	if not (model and model:IsA("Model") and cfg and wind) then
		return nil
	end
	local kit = ReplicatedStorage:FindFirstChild("HT_FieldGrass")
	if not kit then
		return nil
	end
	local templates: { MeshPart } = {}
	-- each template's PivotOffset is set (studio_map.py) to its ROOT, the point the clump bends about
	local pivots: { Vector3 } = {}
	for i = 1, cfg.variants do
		local t = kit:FindFirstChild("FieldGrass_" .. LETTERS[i])
		if not (t and t:IsA("MeshPart")) then
			return nil
		end
		templates[i] = t
		pivots[i] = t.PivotOffset.Position
	end
	local colours: { Color3 } = {}
	for i, c in cfg.colours do
		colours[i] = Color3.fromRGB(c[1], c[2], c[3])
	end
	local centre = (model :: Model):GetPivot().Position
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local radius: number = if touch then cfg.radiusTouch else cfg.radius
	-- the ring's sinking edge, with the phone's own fade (its ring is smaller)
	local ring = table.clone(cfg)
	ring.fade = if touch then cfg.fadeTouch or cfg.fade else cfg.fade
	local near2 = (if touch then cfg.tierNearTouch else cfg.tierNear) ^ 2
	local mid2 = (if touch then cfg.tierMidTouch else cfg.tierMid) ^ 2
	local midEvery: number, farEvery: number = cfg.midEvery, cfg.farEvery
	local cell: number = cfg.cell
	local wx, wz = Environment.wind(wind.direction)
	local bendR: number = cfg.bendRadius
	local bendMax = math.rad(cfg.bendMax)

	local folder = Instance.new("Folder")
	folder.Name = "HT_FieldGrass"
	folder.Archivable = false
	folder.Parent = workspace

	local free: { { MeshPart } } = {}
	for i = 1, #templates do
		free[i] = {}
	end
	local made = 0
	local function take(variant: number): MeshPart
		local list = free[variant]
		local part = table.remove(list)
		if part then
			return part
		end
		local p = templates[variant]:Clone()
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Archivable = false
		p.CFrame = HIDE
		p.Parent = folder
		made += 1
		return p
	end

	local entries: { Entry } = {}
	local byKey: { [number]: Entry } = {}
	local hidden: { MeshPart } = {} -- released this refresh: moved out of sight with the next BulkMoveTo
	local roots: { BasePart } = {} -- characters near the ring; their positions are read every frame
	local nextRefresh = 0
	local frame = 0
	local alive = true

	local function gatherRoots(at: Vector3)
		table.clear(roots)
		local reach2 = (radius + 10) ^ 2
		local function consider(root: Instance?)
			if root and root:IsA("BasePart") then
				local p = root.Position
				local dx, dz = p.X - at.X, p.Z - at.Z
				if dx * dx + dz * dz < reach2 then
					table.insert(roots, root)
				end
			end
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			consider(character and character:FindFirstChild("HumanoidRootPart"))
		end
		for _, child in workspace:GetChildren() do
			if
				child:IsA("Model")
				and child:FindFirstChildOfClass("Humanoid")
				and not Players:GetPlayerFromCharacter(child)
			then
				consider(child:FindFirstChild("HumanoidRootPart"))
			end
		end
	end

	local function refresh(at: Vector3, t: number)
		local fx, fz = at.X - centre.X, at.Z - centre.Z
		local r2 = radius * radius
		-- drop cells that left the ring (with a cell of slack, so a camera on a cell edge doesn't churn)
		local keep2 = (radius + cell) ^ 2
		local i = 1
		while i <= #entries do
			local e = entries[i]
			local dx, dz = e.root.X - at.X, e.root.Z - at.Z
			local d2 = dx * dx + dz * dz
			e.tier = if d2 < near2 then 0 elseif d2 < mid2 then 1 else 2
			if d2 > keep2 then
				byKey[e.key] = nil
				table.insert(free[e.variant], e.part)
				table.insert(hidden, e.part)
				entries[i] = entries[#entries]
				entries[#entries] = nil
			else
				i += 1
			end
		end
		-- take the cells that came in
		local x0, x1 = math.floor((fx - radius) / cell), math.floor((fx + radius) / cell)
		local z0, z1 = math.floor((fz - radius) / cell), math.floor((fz + radius) / cell)
		for ix = x0, x1 do
			for iz = z0, z1 do
				local key = keyOf(ix, iz)
				if not byKey[key] then
					local cx, cz = (ix + 0.5) * cell - fx, (iz + 0.5) * cell - fz
					if cx * cx + cz * cz <= r2 then
						local c = FieldGrass.clumpAt(cfg, ix, iz, semiX, semiZ)
						if c then
							local part = take(c.variant)
							part.Size = templates[c.variant].Size * c.scale
							part.Color = colours[c.tint]
							local e: Entry = {
								key = key,
								part = part,
								variant = c.variant,
								root = centre + Vector3.new(c.x, -cfg.sink, c.z),
								turn = CFrame.Angles(0, c.yaw, 0)
									* CFrame.new(-pivots[c.variant] * c.scale),
								scale = c.scale,
								phase = c.phase,
								along = (c.x * wx + c.z * wz) / wind.gustLength,
								tier = 0,
								bx = 0,
								bz = 0,
								last = t,
								fresh = true,
							}
							byKey[key] = e
							table.insert(entries, e)
						end
					end
				end
			end
		end
		gatherRoots(at)
	end

	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	local targets: { [Entry]: Vector3 } = {}

	-- The ring is centred on whoever the camera follows (the local fighter, or the one being spectated), not on the
	-- camera: at full speed the game's camera pulls back 30-40 studs, which left the fighter at the ring's thinning
	-- edge (seen in a recording, 2026-11-22). With no subject near, the camera itself.
	local function ringCentre(cameraAt: Vector3): Vector3
		local cam = workspace.CurrentCamera
		local subject = cam and cam.CameraSubject
		local part: BasePart? = nil
		if subject and subject:IsA("Humanoid") then
			part = subject.RootPart
		elseif subject and subject:IsA("BasePart") then
			part = subject
		end
		if part and (part.Position - cameraAt).Magnitude < 150 then
			return part.Position
		end
		return cameraAt
	end

	local self = {} :: any

	function self.step(_self: Field, t: number, cameraAt: Vector3?)
		if not alive or not cameraAt then
			return
		end
		local camera = ringCentre(cameraAt)
		if t >= nextRefresh then
			nextRefresh = t + REFRESH
			refresh(camera, t)
		end
		frame += 1
		local calm = GuiService.ReducedMotionEnabled
		-- parting targets: only the cells under each character
		table.clear(targets)
		-- one cell more than the bend radius: the staggered grid puts a root up to about 1.45 cells from its cell's corner
		local reach = math.ceil(bendR / cell) + 1
		for _, rootPart in roots do
			local r = rootPart.Position
			if r.Y - centre.Y >= BEND_HEIGHT then
				continue -- in the air: it doesn't touch the grass
			end
			local ix0, iz0 =
				math.floor((r.X - centre.X) / cell), math.floor((r.Z - centre.Z) / cell)
			for ix = ix0 - reach, ix0 + reach do
				for iz = iz0 - reach, iz0 + reach do
					local e = byKey[keyOf(ix, iz)]
					if e then
						local dx, dz = e.root.X - r.X, e.root.Z - r.Z
						local d = math.sqrt(dx * dx + dz * dz)
						if d < bendR then
							local s = (1 - d / bendR) / math.max(d, 0.3)
							local prev = targets[e] or Vector3.zero
							targets[e] = prev + Vector3.new(dx * s, 0, dz * s)
						end
					end
				end
			end
		end
		table.clear(parts)
		table.clear(frames)
		for _, p in hidden do
			table.insert(parts, p)
			table.insert(frames, HIDE)
		end
		table.clear(hidden)
		local cx, cz = camera.X, camera.Z
		for n, e in entries do
			local target = targets[e]
			local bent = target ~= nil or math.abs(e.bx) + math.abs(e.bz) > 0.01
			local due = e.tier == 0
				or (n + frame) % (if e.tier == 1 then midEvery else farEvery) == 0
			if e.fresh or bent or due then
				e.fresh = false
				local dt = math.min(t - e.last, 0.25)
				e.last = t
				local tx, tz = 0, 0
				if target then
					local m = target.Magnitude
					local k = bendMax * math.min(1, m) / math.max(m, 1e-6)
					tx, tz = target.X * k, target.Z * k
				end
				e.bx = FieldGrass.ease(e.bx, tx, dt, BEND_IN, BEND_OUT)
				e.bz = FieldGrass.ease(e.bz, tz, dt, BEND_IN, BEND_OUT)
				-- Reduced Motion: a steady lean, no gusts or shiver (the parting stays: it answers the player)
				local lean = if calm
					then wind.lean
					else FieldGrass.leanAngle(
						FieldGrass.gustLean(wind, cfg.gustBoost, e.along, t, e.phase)
					)
				local ax, az = wx * lean + e.bx, wz * lean + e.bz
				local angle = math.sqrt(ax * ax + az * az)
				local root = e.root
				local dx, dz = root.X - cx, root.Z - cz
				local sink = FieldGrass.sinkAt(ring, math.sqrt(dx * dx + dz * dz), radius, e.scale)
				local pos = Vector3.new(root.X, root.Y - sink, root.Z)
				-- leaning toward (ax, az) is a turn about (az, 0, -ax); then the clump's own turn, then its place
				local frameCf = if angle > 1e-4
					then CFrame.fromAxisAngle(Vector3.new(az / angle, 0, -ax / angle), angle)
							* e.turn
						+ pos
					else e.turn + pos
				table.insert(parts, e.part)
				table.insert(frames, frameCf)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	function self.destroy(_self: Field)
		alive = false
		table.clear(entries)
		table.clear(byKey)
		folder:Destroy()
	end

	function self.count(_self: Field): (number, number)
		return #entries, made -- clumps in the ring, parts ever made (the pool's size)
	end

	return self :: Field
end

return FieldGrassField
