--!strict
--!native
-- PlantField - the map's flowers, leafy plants, bushes, tree crowns and lilies moving in the wind, on THIS client
-- (Core/Foliage holds the rules). Runs beside GrassField from the same wind, so they move in the same gusts.
--
-- HOW, AND WHY IT'S CHEAP
-- * Nothing is built or cloned: the map's own placements (HT_Dressing) are moved locally (the server never sees
--   it). Each placement is one rigid set of parts turned about one pivot (a clump's base, a crown's low point).
-- * Only placements within their kind's range of the camera move, fading to rest at the edge so leaving the
--   range is invisible. The near set is re-found 4 times a second, not every frame. Past 40% of the range a
--   placement moves every 3rd frame (slow motion, so it can't be seen). One BulkMoveTo per frame for all of it.
-- * Phones (touch, no keyboard) and low graphics (quality 1-3) get shorter ranges.
-- * Characters (players and bots) push flowers, plants and bushes over a little as they walk through.
-- If the map has no HT_Dressing folder, nothing happens and nothing errors.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Environment = require(script.Parent.Core.Environment)
local Foliage = require(script.Parent.Core.Foliage)

local PlantField = {}

local REFRESH = 0.25 -- seconds between re-finding the near set and the characters
local TIER_SHARE = 0.4 -- past this share of its range, a placement moves every TIER_EVERY frames
local TIER_EVERY = 3
local BEND_PAD = 1.5 -- studs added to a clump's own radius for a character to push it
local BEND_HEIGHT = 6 -- a root more than this above the clump's base doesn't push it
local BEND_IN = 12 -- easing rates (1/s): pushed over quickly
local BEND_OUT = 3 -- and back up slowly
local TAU = 2 * math.pi

export type Field = {
	step: (self: Field, t: number, camera: Vector3?) -> (),
	destroy: (self: Field) -> (),
	count: (self: Field) -> (number, number),
}

type Entry = {
	tune: Foliage.Tuning,
	kind: Foliage.Kind,
	pivot: Vector3,
	parts: { BasePart },
	rel: { CFrame }, -- each part's rest CFrame, measured from the pivot (world axes)
	phase: number,
	radius: number,
	range: number,
	bx: number, -- current push from characters (radians, horizontal vector)
	bz: number,
	moved: boolean, -- off its rest pose right now
}

local function lowGraphics(): boolean
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return true
	end
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if ok and level ~= Enum.SavedQualitySetting.Automatic then
		return level.Value <= 3
	end
	return false
end

--- The moving plants of `model` (the live map) in `wind` (a resolved preset's wind table), or nil.
function PlantField.new(model: Instance?, wind: any): Field?
	if not model then
		return nil
	end
	local dressing = model:FindFirstChild("HT_Dressing", true)
	if not dressing then
		return nil
	end

	local low = lowGraphics()
	local wx, wz = Environment.wind(wind.direction)
	local gustLength = math.max(wind.gustLength or 40, 1)
	local gustSeconds = math.max(wind.gustSeconds or 4.5, 0.1)
	local flutterSeconds = math.max(wind.flutterSeconds or 1.2, 0.1)

	local entries: { Entry } = {}
	local maxRange = 0
	for _, placement in dressing:GetChildren() do
		local kind = Foliage.kindOf(placement.Name)
		if not kind or not placement:IsA("Model") then
			continue
		end
		local tune = Foliage.Tuning[kind]
		local parts: { BasePart } = {}
		for _, p in placement:GetDescendants() do
			if p:IsA("BasePart") and p.Anchored and Foliage.partMoves(kind, p.Name) then
				table.insert(parts, p)
			end
		end
		if #parts == 0 then
			continue
		end
		-- the pivot: a clump's base (bottom of its bounds); a tree crown's low point (a third up the crown)
		local pivot: Vector3
		local radius: number
		if kind == "tree" then
			local leaf = parts[1]
			pivot = leaf.Position - Vector3.new(0, leaf.Size.Y * 0.2, 0)
			radius = 0
		else
			local box, size = (placement :: Model):GetBoundingBox()
			pivot = box.Position - Vector3.new(0, size.Y * 0.5, 0)
			radius = math.max(size.X, size.Z) * 0.5
		end
		local rel = table.create(#parts)
		for i, p in parts do
			rel[i] = CFrame.new(-pivot) * p.CFrame
		end
		local range = if low then tune.rangeLow else tune.range
		maxRange = math.max(maxRange, range)
		table.insert(entries, {
			tune = tune,
			kind = kind,
			pivot = pivot,
			parts = parts,
			rel = rel,
			phase = Environment.hash(math.floor(pivot.X), math.floor(pivot.Z), 11) * TAU,
			radius = radius,
			range = range,
			bx = 0,
			bz = 0,
			moved = false,
		})
	end
	if #entries == 0 then
		return nil
	end

	local alive = true
	local near: { Entry } = {}
	local roots: { Vector3 } = {}
	local nextRefresh = -math.huge
	local lastT: number? = nil
	local frameNo = 0
	local moveParts: { BasePart } = {}
	local moveFrames: { CFrame } = {}

	local function pushRest(e: Entry)
		local base = CFrame.new(e.pivot)
		for i, p in e.parts do
			table.insert(moveParts, p)
			table.insert(moveFrames, base * e.rel[i])
		end
		e.moved = false
	end

	local function refresh(cam: Vector3)
		local old = near
		near = {}
		for _, e in entries do
			local dx, dz = e.pivot.X - cam.X, e.pivot.Z - cam.Z
			if dx * dx + dz * dz < e.range * e.range then
				table.insert(near, e)
			end
		end
		for _, e in old do
			local dx, dz = e.pivot.X - cam.X, e.pivot.Z - cam.Z
			if e.moved and dx * dx + dz * dz >= e.range * e.range then
				e.bx, e.bz = 0, 0
				pushRest(e)
			end
		end
		table.clear(roots)
		local reach2 = (maxRange + 20) ^ 2
		local function consider(root: Instance?)
			if root and root:IsA("BasePart") then
				local p = root.Position
				local dx, dz = p.X - cam.X, p.Z - cam.Z
				if dx * dx + dz * dz < reach2 then
					table.insert(roots, p)
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
				and not Players:GetPlayerFromCharacter(child)
				and child:FindFirstChildOfClass("Humanoid")
			then
				consider(child:FindFirstChild("HumanoidRootPart"))
			end
		end
	end

	local self = {} :: any

	function self.step(_self: Field, t: number, camera: Vector3?)
		if not alive then
			return
		end
		local dt = if lastT then math.clamp(t - lastT, 0, 0.1) else 0
		lastT = t
		local cam = camera
			or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
			or Vector3.zero
		if t >= nextRefresh or t < nextRefresh - REFRESH * 2 then
			nextRefresh = t + REFRESH
			refresh(cam)
		end
		frameNo += 1
		for idx, e in near do
			local tune = e.tune
			local px, pz = e.pivot.X, e.pivot.Z
			local dx, dz = px - cam.X, pz - cam.Z
			local dist = math.sqrt(dx * dx + dz * dz)

			-- characters pushing it over (eased: quickly over, slowly back)
			local tx, tz = 0, 0
			if tune.bend > 0 then
				local reach = e.radius + BEND_PAD
				for _, r in roots do
					local rx, rz = px - r.X, pz - r.Z
					local d = math.sqrt(rx * rx + rz * rz)
					if d < reach and r.Y - e.pivot.Y < BEND_HEIGHT and r.Y > e.pivot.Y - 2 then
						local k = tune.bend * (1 - d / reach) / math.max(d, 0.3)
						tx += rx * k
						tz += rz * k
					end
				end
				tx, tz = Foliage.cap(tx, tz, tune.bend)
			end
			local pushing = tx ~= 0 or tz ~= 0 or e.bx ~= 0 or e.bz ~= 0
			if pushing then
				local into = (tx * tx + tz * tz) > (e.bx * e.bx + e.bz * e.bz)
				local a = 1 - math.exp(-(if into then BEND_IN else BEND_OUT) * dt)
				e.bx += (tx - e.bx) * a
				e.bz += (tz - e.bz) * a
				if math.abs(e.bx) < 1e-3 and math.abs(e.bz) < 1e-3 and tx == 0 and tz == 0 then
					e.bx, e.bz = 0, 0
				end
			end

			-- far ones take turns (unless they're being pushed)
			if
				not pushing
				and dist > e.range * TIER_SHARE
				and (frameNo + idx) % TIER_EVERY ~= 0
			then
				continue
			end

			local amp = Foliage.fade(dist, e.range)
			local frame: CFrame
			if e.kind == "lily" then
				local w = TAU * t / (gustSeconds * 0.8) + e.phase
				local rise = (tune.bob or 0) * amp * math.sin(w)
				local turn = (tune.turn or 0) * amp * math.sin(w * 0.5 + 1.3)
				frame = CFrame.new(e.pivot + Vector3.new(0, rise, 0)) * CFrame.Angles(0, turn, 0)
			else
				local g = Foliage.gust(px, pz, t, wx, wz, gustLength, gustSeconds)
				local lx, lz = Foliage.lean(tune, g, t, e.phase, flutterSeconds, wx, wz)
				lx, lz = lx * amp + e.bx, lz * amp + e.bz
				local ang = math.sqrt(lx * lx + lz * lz)
				if ang < 1e-4 then
					frame = CFrame.new(e.pivot)
				else
					-- leaning toward (lx, lz): a turn about the horizontal axis at right angles to it
					frame = CFrame.new(e.pivot)
						* CFrame.fromAxisAngle(Vector3.new(lz, 0, -lx) / ang, ang)
				end
			end
			for i, p in e.parts do
				table.insert(moveParts, p)
				table.insert(moveFrames, frame * e.rel[i])
			end
			e.moved = true
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
			table.clear(moveParts)
			table.clear(moveFrames)
		end
	end

	function self.destroy(_self: Field)
		alive = false
		for _, e in entries do
			if e.moved then
				pushRest(e)
			end
		end
		local keep: { BasePart } = {}
		local frames: { CFrame } = {}
		for i, p in moveParts do
			if p.Parent then
				table.insert(keep, p)
				table.insert(frames, moveFrames[i])
			end
		end
		if #keep > 0 then
			workspace:BulkMoveTo(keep, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		table.clear(moveParts)
		table.clear(moveFrames)
		table.clear(entries)
		table.clear(near)
	end

	function self.count(_self: Field): (number, number)
		return #entries, #near
	end

	return self :: Field
end

return PlantField
