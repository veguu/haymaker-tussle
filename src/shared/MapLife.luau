--!strict
-- MapLife - a map's small life on THIS client (owner 2026-11-26, Map 1 "full of life"), moved by Core/MapLife's rules
-- from the map's `life` entry (Config/MapEnvironments). Shared/MapExtras makes one and steps it each frame, so all of
-- it is one loop and one BulkMoveTo with the map's other movers. Cosmetic only: nothing here collides, is queried or
-- touches anything, and nothing is sent anywhere; a missing piece is skipped, never an error.
--
-- What the map's model holds (built in Studio by design/maps/suite/studio_life.py from the Blender game build,
-- design/maps/suite/meadow_life_game.py), under HT_Life:
--   Butterflies/<one folder each>: Body, WingL, WingR      Bees/<one each>: Body, Wings
--   Birds/<one each, HT_Flock, HT_Bird>: Body, WingL, WingR  Animals/<one each>: Body, Head (HT_Neck)
--   Balloons/<parts>   Rim/<vines and roots, HT_Sway>   Puffs/<dandelion puffs>   Static/<still pieces>
--   Fx (an anchor part): attachments Splash (Ring, Drops), Seeds (Seeds), Smoke_<n> (Smoke), Mist_<n> (Mist)
--   Petals (a flat box part over the floor): one emitter per petal colour
-- Every moving part carries HT_PivotOffset (a CFrame: the part from its pivot); wings HT_Hinge (the right
-- wing's hinge in the body's frame); cloud shadows are Textures named HT_CloudShadow on the floor meshes (HT_BaseU/V).
--
-- PHONES (touch, no keyboard) keep fewer creatures and chimneys (the entry's `phone` numbers), and far pieces freeze:
-- the floor's creatures past `near` studs from the camera, the islands' and the sky's past `far`. The islands' and
-- sky's movers update every few frames (they move slowly, far away). Reduced Motion: the clock runs at a third
-- (Core/MapMotion.REDUCED). What it costs: HT_Life's LifeAvgMs / LifePeakMs / LifeParts on this client, each second.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")

local Core = require(script.Parent.Core.MapLife)
local MapMotion = require(script.Parent.Core.MapMotion)
local Pond = require(script.Parent.Core.Pond)

local MapLife = {}

export type Life = {
	step: (self: Life, t: number) -> (),
	destroy: (self: Life) -> (),
}

local TAU = 2 * math.pi
local FLIP = CFrame.Angles(0, 0, math.pi) -- a right wing's blocks turned half a turn about the body: the left wing

-- a part from its pivot: HT_PivotOffset, a CFrame (the centre's offset, then the import's own turn: a GLB import is
-- half a turn about y from Blender's axes); a Vector3 is taken as an offset alone
local function offsetOf(p: BasePart): CFrame
	local o = p:GetAttribute("HT_PivotOffset")
	if typeof(o) == "CFrame" then
		return o
	end
	return if typeof(o) == "Vector3" then CFrame.new(o) else CFrame.identity
end

local function vec(p: Instance?, name: string): Vector3
	local v = p and p:GetAttribute(name)
	return if typeof(v) == "Vector3" then v else Vector3.zero
end

local function children(folder: Instance?): { Instance }
	local list = if folder then folder:GetChildren() else {}
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function part(holder: Instance, name: string): BasePart?
	local p = holder:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

--- Life for `model` (the live map, pivoted on the arena's centre) from its entry, or nil when it has none.
function MapLife.new(model: Model, entry: any, touch: boolean): Life?
	local cfg = entry and entry.life
	local root = model:FindFirstChild("HT_Life")
	if not (cfg and root) or #Core.problems(cfg) > 0 then
		return nil
	end
	local pivot = model:GetPivot()
	local centre = pivot.Position
	local wd = entry.environment and entry.environment.wind and entry.environment.wind.direction
		or { 1, 0.3 }
	local wl = math.sqrt(wd[1] * wd[1] + wd[2] * wd[2])
	local wx, wz = wd[1] / wl, wd[2] / wl
	local pond = entry.pond

	-- ---- gather ---------------------------------------------------------------------------------------------------
	local moved: { BasePart } = {} -- every part this moves (to put back home on destroy)
	local homes: { CFrame } = {}
	local function track(p: BasePart)
		table.insert(moved, p)
		table.insert(homes, p.CFrame)
	end
	local function drop(holder: Instance)
		holder.Parent = nil -- this client's copy only: never replicated back
	end

	local bcfg = cfg.butterflies or {}
	local butterflies = {}
	local bFolder = root:FindFirstChild("Butterflies")
	local bList = children(bFolder)
	-- more than the model holds (`count`): copies of its own butterflies (another colour), made on this client only,
	-- beside the model's (pairs) and in the gaps (Core.extraHomes); destroyed with the life
	local made: { Instance } = {}
	local sized: { { any } } = {} -- {part, its size before `scale`}: put back on destroy, so a rebind never grows twice
	if bFolder and type(bcfg.count) == "number" and bcfg.count > #bList then
		local hs = {}
		for _, f in bList do
			local body = part(f, "Body")
			if body then
				local h = (body.CFrame * offsetOf(body):Inverse()).Position - centre
				table.insert(hs, { h.X, h.Z, f })
			end
		end
		for k, e in Core.extraHomes(hs, bcfg.count, bcfg.spread) do
			local src = hs[e.src]
			local copy = (src[3] :: Instance):Clone()
			local d = Vector3.new(e.x - src[1], e.y, e.z - src[2])
			for _, p in copy:GetChildren() do
				if p:IsA("BasePart") then
					p.CFrame += d
				end
			end
			copy.Name = string.format("ButterflyX_%02d", k) -- sorts after the model's own
			copy.Parent = bFolder
			table.insert(made, copy)
		end
		bList = children(bFolder)
	end
	for i, f in bList do
		local body, wl_, wr = part(f, "Body"), part(f, "WingL"), part(f, "WingR")
		if not (body and wl_ and wr) then
			continue
		end
		if touch and not Core.kept(i, #bList, bcfg.phone or #bList) then
			drop(f)
			continue
		end
		track(body)
		track(wl_)
		track(wr)
		-- `scale`: a bigger butterfly about its own pivot (life-5: 1.4, "at least noticeable"); sizes, offsets and the
		-- wings' hinge all grow together, once, here
		local s = if type(bcfg.scale) == "number" then bcfg.scale else 1
		local pivotCF = body.CFrame * offsetOf(body):Inverse()
		local home = pivotCF.Position
		local look = Vector3.new(pivotCF.LookVector.X, 0, pivotCF.LookVector.Z)
		local startFace = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
		local f0x, f0y, f0z = Core.butterfly(i, 0, bcfg.flutter or 0.3)
		local function grown(o: CFrame): CFrame
			return if s == 1 then o else CFrame.new(o.Position * s) * o.Rotation
		end
		if s ~= 1 then
			for _, p in { body, wl_, wr } do
				table.insert(sized, { p, p.Size })
				p.Size *= s
			end
		end
		table.insert(butterflies, {
			i = i,
			body = body,
			wingL = wl_,
			wingR = wr,
			offB = grown(offsetOf(body)),
			offW = grown(offsetOf(wr)),
			hinge = vec(wr, "HT_Hinge") * s,
			home = home,
			phase = Core.rand(i, 30) * TAU,
			dartAt = nil :: number?,
			-- the flight (life-6): where it is and how it moves, the stop it is flying to (`n`), its target, when it
			-- reached the stop, and which way it faces; it starts exactly where the model put it (its flight point minus
			-- the flutter's first offset, so the first frame it is moved does not pop: 0.6 studs, measured), partway
			-- through its stops
			px = home.X - f0x,
			py = home.Y - f0y,
			pz = home.Z - f0z,
			vx = 0,
			vy = 0,
			vz = 0,
			n = 1 + math.floor(Core.rand(i, 31) * 7),
			tx = home.X - f0x,
			ty = home.Y - f0y,
			tz = home.Z - f0z,
			arrived = nil :: number?,
			ft = 0, -- its own flutter clock
			face = startFace, -- the way the model has it facing, so the first frame does not turn it
		})
	end

	local bees = {}
	local beeList = children(root:FindFirstChild("Bees"))
	for i, f in beeList do
		local body, wings = part(f, "Body"), part(f, "Wings")
		if not (body and wings) then
			continue
		end
		if touch and not Core.kept(i, #beeList, (cfg.bees and cfg.bees.phone) or #beeList) then
			drop(f)
			continue
		end
		track(body)
		track(wings)
		table.insert(bees, {
			i = i,
			body = body,
			wings = wings,
			offB = offsetOf(body),
			offW = offsetOf(wings),
			home = (body.CFrame * offsetOf(body):Inverse()).Position,
		})
	end

	local birds = {}
	for _, f in children(root:FindFirstChild("Birds")) do
		local flock = cfg.flocks and cfg.flocks[f:GetAttribute("HT_Flock") or 0]
		local body, wl_, wr = part(f, "Body"), part(f, "WingL"), part(f, "WingR")
		if not (flock and body and wl_ and wr) then
			continue
		end
		if touch and flock.phone == false then
			drop(f)
			continue
		end
		track(body)
		track(wl_)
		track(wr)
		table.insert(birds, {
			b = f:GetAttribute("HT_Bird") or 1,
			flock = flock,
			body = body,
			wingL = wl_,
			wingR = wr,
			offB = offsetOf(body),
			offW = offsetOf(wr),
			hinge = vec(wr, "HT_Hinge"),
		})
	end

	local animals = {}
	for i, f in children(root:FindFirstChild("Animals")) do
		local body, head = part(f, "Body"), part(f, "Head")
		if not (body and head) then
			continue
		end
		track(body)
		track(head)
		table.insert(animals, {
			i = i,
			body = body,
			head = head,
			offB = offsetOf(body),
			offH = offsetOf(head),
			home = body.CFrame * offsetOf(body):Inverse(),
			neck = vec(head, "HT_Neck"),
		})
	end

	local balloons = {}
	for i, p in children(root:FindFirstChild("Balloons")) do
		if p:IsA("BasePart") then
			track(p)
			table.insert(
				balloons,
				{ i = i, part = p, off = offsetOf(p), home = p.CFrame * offsetOf(p):Inverse() }
			)
		end
	end

	local rim = {}
	for i, p in children(root:FindFirstChild("Rim")) do
		if p:IsA("BasePart") then
			if touch and cfg.rimOnPhones == false then
				drop(p)
				continue
			end
			local home = p.CFrame * offsetOf(p):Inverse()
			local flat = Vector3.new(home.Position.X - centre.X, 0, home.Position.Z - centre.Z)
			local along = if flat.Magnitude > 1e-3
				then Vector3.new(-flat.Z, 0, flat.X).Unit
				else Vector3.xAxis
			track(p)
			table.insert(rim, {
				i = i,
				part = p,
				off = offsetOf(p),
				home = home,
				along = along,
				amount = p:GetAttribute("HT_Sway") or 0.05,
			})
		end
	end

	local dcfg = cfg.dandelions or {}
	local puffs = {}
	for _, p in children(root:FindFirstChild("Puffs")) do
		if p:IsA("BasePart") then
			table.insert(puffs, {
				part = p,
				at = p.Position,
				burstAt = nil :: number?,
				shown = 1,
				base = p.Transparency,
			})
		end
	end

	local shadows = {}
	local scfg = cfg.shadows
	for _, d in model:GetDescendants() do
		if d:IsA("Texture") and d.Name == "HT_CloudShadow" then
			if not scfg or (touch and scfg.phone == false) then
				d.Transparency = 1
				continue
			end
			table.insert(shadows, {
				tex = d,
				u0 = d:GetAttribute("HT_BaseU") or 0,
				v0 = d:GetAttribute("HT_BaseV") or 0,
			})
		end
	end

	local fx = root:FindFirstChild("Fx")
	local splashAt = fx and fx:FindFirstChild("Splash")
	local ring = splashAt and splashAt:FindFirstChild("Ring") :: ParticleEmitter?
	local drops = splashAt and splashAt:FindFirstChild("Drops") :: ParticleEmitter?
	local seedAt = fx and fx:FindFirstChild("Seeds")
	local seeds = seedAt and seedAt:FindFirstChild("Seeds") :: ParticleEmitter?
	-- chimney smoke: phones keep the nearest few, at a lower rate
	local smoke = {}
	if fx then
		for _, a in fx:GetChildren() do
			local e = a:IsA("Attachment")
				and a.Name:sub(1, 6) == "Smoke_"
				and a:FindFirstChild("Smoke")
			if e and e:IsA("ParticleEmitter") then
				table.insert(smoke, { emitter = e, d = (a.WorldPosition - centre).Magnitude })
			end
		end
	end
	table.sort(smoke, function(a, b)
		return a.d < b.d
	end)
	local smcfg = cfg.smoke or {}
	for k, s in smoke do
		if touch then
			s.emitter.Enabled = k <= (smcfg.phone or #smoke)
			s.emitter.Rate = smcfg.phoneRate or s.emitter.Rate
		end
	end
	local petalBox = root:FindFirstChild("Petals")
	local petals: { ParticleEmitter } = {}
	for _, e in if petalBox then petalBox:GetChildren() else {} do
		if e:IsA("ParticleEmitter") then
			table.insert(petals, e)
		end
	end

	-- ---- the loop ---------------------------------------------------------------------------------------------------
	local near, far = cfg.near or 260, cfg.far or 1600
	local fleeCfg: Core.Flee = {
		reach = bcfg.reach or 8,
		close = bcfg.close or 2.5,
		speed = bcfg.speed or 18,
		lead = bcfg.lead,
	}
	local seeButterfly = bcfg.see or near
	local wcfg = bcfg.wander or {} -- the roaming flight (life-6)
	local fcfg = bcfg.flee or {} -- the swerve out of a fighter's way
	local edge = wcfg.edge or 165 -- studs from the arena's centre: stops stay over the floor
	local seeBee = cfg.bees and cfg.bees.see or near
	local seeRim = cfg.rimSee or near
	-- the fighters (every HT_Combatant: players and bots): the list each half second, where they are every frame,
	-- their speed from how far they moved (a dash read late is a dash missed: it is within reach ~0.13 s)
	type Fighter = {
		root: BasePart,
		x: number,
		z: number,
		vx: number,
		vz: number,
		px: number?,
		pz: number?,
		at: number?,
	}
	local fighters: { Fighter } = {}
	local fightersAt = -1
	local splashDue: { [BasePart]: number } = {}
	local clock, last = 0, nil :: number?
	local frame = 0
	local nextGust = 0
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	local spent, peak, count, reportAt = 0, 0, 0, 0
	local self = {} :: any

	local function refreshFighters(t: number)
		fightersAt = t
		local known: { [BasePart]: Fighter } = {}
		for _, f in fighters do
			known[f.root] = f
		end
		table.clear(fighters)
		for _, m in CollectionService:GetTagged("HT_Combatant") do
			local r = if m:IsA("Model")
				then (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart"))
				else nil
			if r and r:IsA("BasePart") then
				local p = r.Position
				table.insert(fighters, known[r] or { root = r, x = p.X, z = p.Z, vx = 0, vz = 0 })
			end
		end
	end

	local function trackFighters(t: number)
		for _, f in fighters do
			local p = f.root.Position
			f.x, f.z = p.X, p.Z
			local dt = if f.at then t - (f.at :: number) else 0
			if f.at == nil or dt >= 0.03 then
				if f.at and dt < 0.5 then
					f.vx, f.vz = (p.X - (f.px :: number)) / dt, (p.Z - (f.pz :: number)) / dt
				end
				f.px, f.pz, f.at = p.X, p.Z, t
			end
		end
	end

	local function wingPair(body: CFrame, b: any, lift: number)
		local h = b.hinge
		table.insert(parts, b.wingR)
		table.insert(frames, body * CFrame.new(h) * CFrame.Angles(0, 0, lift) * b.offW)
		table.insert(parts, b.wingL)
		table.insert(
			frames,
			body * CFrame.new(-h.X, h.Y, h.Z) * CFrame.Angles(0, 0, -lift) * FLIP * b.offW
		)
	end

	function self.step(_self: Life, t: number)
		local began = os.clock()
		frame += 1
		local dt = if last then math.clamp(t - (last :: number), 0, 0.25) else 0
		local reduced = GuiService.ReducedMotionEnabled
		clock = MapMotion.advance(clock, last, t, reduced)
		last = t
		local camera = workspace.CurrentCamera
		local cam = if camera then camera.CFrame.Position else centre
		-- what the camera can see: a cone a little wider than the screen's corners (nothing off-screen moves; it is
		-- placed again from the clock when it comes back, out of sight at the cone's margin)
		local look = if camera then camera.CFrame.LookVector else Vector3.zAxis
		local coneCos = -1
		if camera then
			local tv = math.tan(math.rad(camera.FieldOfView) / 2)
			local size = camera.ViewportSize
			local th = tv * size.X / math.max(size.Y, 1)
			coneCos = math.cos(math.min(math.atan(math.sqrt(tv * tv + th * th)) + 0.15, math.pi))
		end
		local function seen(p: Vector3, r: number): boolean
			local d = p - cam
			local dist = d.Magnitude
			return dist < r + 2 or d:Dot(look) >= dist * coneCos - r
		end
		table.clear(parts)
		table.clear(frames)
		if t - fightersAt >= 0.5 then
			refreshFighters(t)
		end
		trackFighters(t)

		-- butterflies (life-6): FLY from stop to stop round their homes, lingering a moment at each; a fighter coming at
		-- one (checked every other frame) sends it on a quick swerve off his line, a glide like any other, so it never
		-- jumps; wings beat faster while it flees. Past `see` or out of view one simply holds still where it is.
		local scan = frame % 2 == 0
		local fly = math.min(dt, 0.1) * (if reduced then MapMotion.REDUCED else 1)
		for _, b in butterflies do
			local here = Vector3.new(b.px, b.py, b.pz)
			if (here - cam).Magnitude > seeButterfly or not seen(here, 9) then
				continue
			end
			local since = if b.dartAt then t - b.dartAt else nil
			local fleeing = since ~= nil and since < (fcfg.time or 0.9)
			if scan and (since == nil or since > 0.6) then
				for _, f in fighters do
					local hit, sx, sz = Core.threat(fleeCfg, b.px, b.pz, f.x, f.z, f.vx, f.vz)
					if hit then
						b.dartAt, since, fleeing = t, 0, true
						b.tx = b.px + sx * (bcfg.dart or 4.2)
						b.ty = b.py + (bcfg.rise or 2)
						b.tz = b.pz + sz * (bcfg.dart or 4.2)
						b.n += 1 -- and afterwards on to a new stop, not back into the fight
						b.arrived = nil
						break
					end
				end
			end
			local quick, cap = wcfg.quick or 1.2, wcfg.speed or 5
			if fleeing then
				quick, cap = fcfg.quick or 7, fcfg.speed or 14
			else
				local sx, sy, sz = Core.stop(b.i, b.n, wcfg.range or 28, wcfg.lift or 2.5)
				local gx, gz = b.home.X + sx, b.home.Z + sz
				local fromC = Vector3.new(gx - centre.X, 0, gz - centre.Z)
				if fromC.Magnitude > edge then -- stops stay over the floor
					fromC = fromC.Unit * edge
					gx, gz = centre.X + fromC.X, centre.Z + fromC.Z
				end
				b.tx, b.ty, b.tz = gx, b.home.Y + sy, gz
				local dx, dz = b.tx - b.px, b.tz - b.pz
				if dx * dx + dz * dz < 6.25 then
					b.arrived = b.arrived or t
					local lin = wcfg.linger or { 0.6, 2.5 }
					if t - b.arrived > Core.linger(b.i, b.n, lin[1], lin[2]) then
						b.n += 1
						b.arrived = nil
					end
				end
			end
			b.px, b.py, b.pz, b.vx, b.vy, b.vz =
				Core.glide(b.px, b.py, b.pz, b.vx, b.vy, b.vz, b.tx, b.ty, b.tz, fly, quick, cap)
			-- face where it flies, turning smoothly (not snapping when it stops or swerves)
			local hv = Vector3.new(b.vx, 0, b.vz)
			if hv.Magnitude > 0.3 then
				b.face = b.face:Lerp(hv.Unit, math.min(1, dt * 6))
			end
			-- the flutter runs on the butterfly's OWN clock, which stops while it holds still out of view, so it never
			-- pops to a new spot when it comes back into view (life-6: a 0.57-stud jump, measured)
			b.ft += fly
			local ox, oy, oz = Core.butterfly(b.i, b.ft, bcfg.flutter or 0.3)
			local pos = Vector3.new(b.px + ox, b.py + oy, b.pz + oz)
			local body = if b.face.Magnitude > 1e-3
				then CFrame.lookAt(pos, pos + Vector3.new(b.face.X, 0, b.face.Z))
				else CFrame.new(pos)
			b.phase += Core.beats(since, bcfg.calm or 4, bcfg.fast or 12) * TAU * dt * (if reduced
				then MapMotion.REDUCED
				else 1)
			table.insert(parts, b.body)
			table.insert(frames, body * b.offB)
			wingPair(body, b, Core.wing(b.phase))
		end

		-- bees: buzz about their flowers, wings flickering every frame
		for _, b in bees do
			if (b.home - cam).Magnitude > seeBee or not seen(b.home, 4) then
				continue
			end
			local ox, oy, oz = Core.bee(b.i, clock)
			local px, _, pz = Core.bee(b.i, clock + 0.05)
			local pos = b.home + Vector3.new(ox, oy, oz)
			local dir = Vector3.new(px - ox, 0, pz - oz)
			local body = if dir.Magnitude > 1e-4
				then CFrame.lookAt(pos, pos + dir)
				else CFrame.new(pos)
			table.insert(parts, b.body)
			table.insert(frames, body * b.offB)
			table.insert(parts, b.wings)
			table.insert(
				frames,
				body * CFrame.Angles(if frame % 2 == 0 then 0.5 else -0.3, 0, 0) * b.offW
			)
		end

		-- birds: round their loops, banked into the turn, wings beating and gliding (every third frame: far away)
		if frame % 3 == 0 then
			for _, b in birds do
				local x, y, z, vx, vy, vz = Core.orbit(b.flock, b.b, clock)
				local pos = pivot:PointToWorldSpace(Vector3.new(x, y, z))
				if (pos - cam).Magnitude > far or not seen(pos, 10) then
					continue
				end
				local vel = pivot:VectorToWorldSpace(Vector3.new(vx, vy * 0.2, vz))
				local body = CFrame.lookAt(pos, pos + vel)
					* CFrame.Angles(0, 0, -b.flock.dir * 0.25)
				table.insert(parts, b.body)
				table.insert(frames, body * b.offB)
				wingPair(body, b, Core.birdWing(b.flock, b.b, clock))
			end
		end

		-- the slow ones (animals, vines: every sixth frame; balloons: every third)
		if frame % 6 == 0 then
			for _, a in animals do
				if (a.home.Position - cam).Magnitude > far or not seen(a.home.Position, 6) then
					continue
				end
				local body = a.home * CFrame.new(0, 0, -Core.shuffle(a.i, clock))
				table.insert(parts, a.body)
				table.insert(frames, body * a.offB)
				table.insert(parts, a.head)
				table.insert(
					frames,
					body * CFrame.new(a.neck) * CFrame.Angles(Core.graze(a.i, clock), 0, 0) * a.offH
				)
			end
			for _, v in rim do
				if (v.home.Position - cam).Magnitude > seeRim or not seen(v.home.Position, 18) then
					continue
				end
				local swing, twist = Core.sway(v.i, clock, v.amount)
				local at = v.home.Position
				local turn = CFrame.fromAxisAngle(v.along, swing) * CFrame.Angles(0, twist, 0)
				table.insert(parts, v.part)
				table.insert(frames, CFrame.new(at) * turn * v.home.Rotation * v.off)
			end
		end
		if frame % 3 == 0 then
			local bl = cfg.balloons or {}
			for _, b in balloons do
				local dx, dy, dz, rx, rz, turn =
					Core.balloon(b.i, clock, bl.loop or 120, bl.speed or 2.5)
				table.insert(parts, b.part)
				table.insert(
					frames,
					CFrame.new(pivot:VectorToWorldSpace(Vector3.new(dx, dy, dz)))
						* b.home
						* CFrame.Angles(rx, turn, rz)
						* b.off
				)
			end
		end

		-- dandelions: a fighter running through one bursts it into seeds on the wind; it grows back
		local dl = dcfg
		for _, p in puffs do
			if p.burstAt == nil then
				if (p.at - cam).Magnitude <= near then
					for _, f in fighters do
						local speed = math.sqrt(f.vx * f.vx + f.vz * f.vz)
						if
							Core.bursts(
								p.at.X,
								p.at.Z,
								f.x,
								f.z,
								speed,
								dl.reach or 1.2,
								dl.least or 2
							)
						then
							p.burstAt = t
							if seeds and seedAt and seedAt:IsA("Attachment") then
								seedAt.WorldPosition = p.at
								seeds:Emit(dl.seeds or 8)
							end
							break
						end
					end
				end
			end
			if p.burstAt then
				local k = Core.puff(t - p.burstAt, dl.regrow or 25, dl.grow or 2)
				if math.abs(k - p.shown) > 0.02 or (k >= 1 and p.shown < 1) then
					p.shown = k
					p.part.Transparency = p.base + (1 - p.base) * (1 - k)
				end
				if k >= 1 then
					p.burstAt = nil
				end
			end
		end

		-- splashes: a ring and droplets at the feet of anyone wading, often while they move
		local spcfg = cfg.splashes
		if pond and spcfg and ring and drops and splashAt and splashAt:IsA("Attachment") then
			for _, f in fighters do
				local here = pivot:PointToObjectSpace(f.root.Position)
				local wading = Pond.inWater(pond, here.X, here.Z) and here.Y < (spcfg.above or 4.5)
				if not wading then
					splashDue[f.root] = nil
					continue
				end
				local due = splashDue[f.root] or t
				if t >= due then
					local moving = f.vx * f.vx + f.vz * f.vz > 1
					splashDue[f.root] = t
						+ Core.splashGap(moving, spcfg.moving or 0.4, spcfg.standing or 0.9)
					splashAt.WorldPosition =
						pivot:PointToWorldSpace(Vector3.new(here.X, -pond.water + 0.03, here.Z))
					ring:Emit(1)
					drops:Emit(spcfg.drops or 4)
				end
			end
			for r in splashDue do
				if not r.Parent then
					splashDue[r] = nil
				end
			end
		end

		-- cloud shadows slide with the wind (every other frame)
		if scfg and frame % 2 == 0 then
			local du, dv = Core.slide(clock, scfg.speed, wx, wz, scfg.tile)
			for _, s in shadows do
				s.tex.OffsetStudsU = (s.u0 + du) % scfg.tile
				s.tex.OffsetStudsV = (s.v0 + dv) % scfg.tile
			end
		end

		-- petals blown off the flowers in each gust
		local pcfg = cfg.petals
		if pcfg and #petals > 0 and t >= nextGust then
			nextGust = t + (pcfg.every or 4)
			local n = if touch then (pcfg.phone or pcfg.count) else pcfg.count
			for k, e in petals do
				e:Emit(math.floor(n / #petals) + (if k <= n % #petals then 1 else 0))
			end
		end

		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		-- what it costs, for the owner's testing
		local took = os.clock() - began
		spent += took
		peak = math.max(peak, took)
		count += 1
		if t >= reportAt then
			reportAt = t + 1
			root:SetAttribute("LifeAvgMs", math.floor(spent / count * 1e5) / 100)
			root:SetAttribute("LifePeakMs", math.floor(peak * 1e5) / 100)
			root:SetAttribute("LifeParts", #parts)
			spent, peak, count = 0, 0, 0
		end
	end

	function self.destroy(_self: Life)
		for i, p in moved do
			if p.Parent then
				p.CFrame = homes[i]
			end
		end
		for _, p in puffs do
			p.part.Transparency = p.base
		end
		for _, ps in sized do
			(ps[1] :: BasePart).Size = ps[2]
		end
		table.clear(sized)
		for _, c in made do
			c:Destroy()
		end
		table.clear(made)
		table.clear(butterflies)
		table.clear(bees)
		table.clear(birds)
		table.clear(animals)
		table.clear(balloons)
		table.clear(rim)
		table.clear(puffs)
		table.clear(shadows)
	end

	return self :: Life
end

return MapLife
