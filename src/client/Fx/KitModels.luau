--!strict
-- KitModels - the solid pieces the ability kits' effects are built with (the user, 2026-11-15: "mix
-- vfx with models ... the ice should be made out of a solid model"), and the one loop that moves them.
-- Decoration on this client only: every piece is anchored and can't collide, be touched or block a ray.
--
-- THE PIECES are meshes made in Blender (design/kits/*.py), uploaded as group-owned models and kept in
-- the place under ReplicatedStorage.HT_KitModels (like HT_GrassKit). Each is one unit tall with its
-- root at the bottom, so the game sets the height it wants. Until a piece is in the place, a plain
-- block stands in for it, so an effect still shows where its solid part will be.
--
-- TWO KINDS OF MOTION, both run from one Heartbeat connection:
--   ERUPT   a piece bursts out of the floor: white-hot for its first frames, past its full size and
--           back, stands for a while, then flashes white again and sinks (DonutLee1 "ICE ERUPTION",
--           YouTube nOloysSOoGY: the cluster is a white silhouette first and last).
--   THROW   a piece is thrown as debris: it flies on an arc, turning, and shrinks away.
--   BREAK   (ice-2) an erupted piece can leave by breaking instead of sinking: it stands white-hot
--           for a moment, swelling a little, then is gone and its chunks fly up and out and fall
--           (the owner's reference, "Niagara-Ice", YouTube dIWMbXMnwqc: one white flash about
--           0.17 s long while the ice breaks, chunks in the air for about 0.7 s). Nothing in it is
--           random. Since ice-12 the break copies the reference frame by frame (the owner picked all
--           four differences from a sheet): MANY SMALL pieces (2 to 8 a crystal, about 140 for the
--           Glacier), which BURST outward and up from the cluster's middle, slow down and HANG in the
--           air, white-hot for only 0.2 s and then glowing ice. ice-13: they do not shrink; each
--           one BREAKS INTO SMALLER PIECES where it hangs, twice, and the smallest go (the owner,
--           from the reference).
--           (ice-9 to ice-11 had them as real physics parts that dropped and lay on the floor.)
--   GLOW    (ice-3) a piece can glow from inside: two particle emitters in it, a very faint soft
--           glow and a few glints (the owner's idea, and their pick of two strengths in Studio; a
--           Neon core inside each piece was tried first and turned down). Kept very faint on
--           purpose: a cluster stacks about 25 of them, and at ten times this it is a white blob.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FxKit = require(script.Parent.FxKit)

local KitModels = {}

local FOLDER_NAME = "HT_KitModels"
local WHITE = Color3.new(1, 1, 1)
local FLASH_SECONDS = 0.06 -- how long a piece is white-hot as it arrives, and again as it leaves
local RISE_SECONDS = 0.08 -- from nothing to past full size
local SETTLE_SECONDS = 0.07 -- and back to full size
local SINK_SECONDS = 0.26
local LAY_SECONDS = 0.08 -- a laid tile pops in over this long
local BREAK_SECONDS = 0.10 -- a breaking piece stands white-hot this long, then its chunks fly
local CHUNK_HOT_SECONDS = 0.2 -- a chunk is white-hot this long, then glowing ice (the reference: 0.2 s)
-- ice-17: chunks FOLLOW PHYSICS (the owner: "they should go wherever they are launched at, of course but in
-- a curve since theyre effected by gravity", and "the initial launch shouldnt be powerful enough for them to
-- scatter a lot"). A chunk has a launch velocity and gravity, nothing else: no drag, no hang, no fall speed.
-- The numbers are the reference's, read frame by frame on a grid (sheets/C_track_a.jpg, C_track_b.jpg): the
-- top pieces climb about 11 studs over the flower, and late in the break a piece keeps a steady outward
-- speed while its fall grows slowly (a weak gravity, far under Roblox's 196).
local CHUNK_GRAVITY = 30 -- studs a second, each second
local CHUNK_UP = NumberRange.new(16, 30) -- launch speed upward: it climbs 4 to 15 studs
local CHUNK_OUT = NumberRange.new(2, 7) -- launch speed away from the cluster's middle, kept all the way
local CHUNK_SPIN_SECONDS = 0.3 -- how quickly a chunk stops turning: it turns rate x this, in all
-- ice-16: FEWER, LATER, QUIETER breaks (the owner: "the pieces should break less, theres too much now. in
-- the reference, the pieces break very slowly and dont move too much, making it somewhat hard to notice").
-- Every other chunk breaks, once, late in its fall, into two pieces that barely part; the rest stay whole.
local CHUNK_SPLITS = 1 -- how many times a breaking chunk breaks into smaller ones
local CHUNK_SPLIT_SIZE = 0.7 -- a smaller piece's size against the one it came from
local CHUNK_END_SECONDS = 0.25 -- a piece shrinks only as it goes, for this long

export type Erupt = {
	part: BasePart,
	base: CFrame, -- where its root sits, +Y along the way it points
	size: Vector3, -- at full size
	startAt: number,
	hold: number, -- seconds it stands at full size
	colour: Color3,
	material: Enum.Material,
	transparency: number,
	phase: number, -- 0 waiting, 1 white-hot, 2 standing, 3 leaving
	breaks: Break?, -- set: it leaves by breaking into chunks instead of sinking
	glow: boolean?, -- it glows from inside, and so do its chunks
	vanish: boolean?, -- at the end of its hold it is simply gone (what it turns into is the caller's: melt-1)
}

export type Break = {
	index: number, -- which piece of its cluster this is (fixes how its chunks fly)
	middle: Vector3, -- the cluster's middle: chunks fly away from it
	chunk: string, -- the piece its chunks are made of
}

type Chunk = {
	part: BasePart,
	from: Vector3,
	velocity: Vector3,
	turn: CFrame,
	axis: Vector3,
	rate: number,
	size: Vector3,
	startAt: number,
	life: number,
	colour: Color3,
	hot: boolean,
	glow: boolean?,
	name: string, -- which kit piece it is, for the smaller ones it breaks into
	splits: number, -- how many more times it breaks into smaller pieces
	seed: number, -- sets its pieces' directions and lives: nothing is random
	floor: number, -- the height of the ground under the cluster: a chunk is gone by the time it gets there
}

-- A flat piece laid on the floor (melt-1: the Frost trail's tiles). It pops in, lies there, then shrinks
-- toward its own middle where it lies; `onMelt` is called once, as the shrinking starts.
type Laid = {
	part: BasePart,
	cframe: CFrame,
	size: Vector3,
	startAt: number,
	hold: number,
	shrink: number,
	melting: boolean,
	onMelt: ((BasePart) -> ())?,
	share: number, -- the size it was last given (0 to 1), so a tile that is lying still is not touched
}

type Throw = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	gravity: number,
	axis: Vector3, -- what it turns about
	rate: number, -- radians a second
	turn: CFrame,
	size: Vector3,
	startAt: number,
	life: number,
	whole: boolean, -- keeps its size to the end (a thing that lands, not debris that shrinks away)
}

type Sweep = {
	part: BasePart,
	from: CFrame,
	to: CFrame,
	size: Vector3,
	startAt: number,
	seconds: number,
	colour: Color3,
	material: Enum.Material,
	hot: boolean, -- still white-hot
}

local holder: Folder? = nil
local erupting: { Erupt } = {}
local thrown: { Throw } = {}
local swept: { Sweep } = {}
local chunks: { Chunk } = {}
local laid: { Laid } = {}
local connection: RBXScriptConnection? = nil

local function folder(): Folder
	local current = holder
	if not current or current.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "HT_KitModelsFx"
		made.Parent = workspace
		holder = made
		current = made
	end
	return current :: Folder
end

-- A piece's own look (ice-10): the kit's meshes now carry a SurfaceAppearance (colour, gloss and a
-- glowing frost mask, all baked in Blender), which hides the part's Material and Color. So a piece
-- that must be plain white-hot has it taken off for that time, and put back after.
local skins: { [BasePart]: SurfaceAppearance } = setmetatable({}, { __mode = "k" }) :: any

local function textured(part: BasePart, on: boolean)
	local skin = skins[part]
	if skin then
		skin.Parent = if on then part else nil
	end
end

local function template(name: string): BasePart?
	local kit = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	local found = kit and kit:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

--- Loads the kits' meshes and textures ahead of time. Without it the first piece of a session shows
--- untextured (plain, no glow) until its images arrive (seen 2026-11-22: the first Glacier was flat).
function KitModels.preload()
	local kit = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if kit then
		pcall(function()
			ContentProvider:PreloadAsync({ kit })
		end)
	end
end

--- Is the real mesh for `name` in the place? (False: `piece` gives a plain block instead.)
function KitModels.has(name: string): boolean
	return template(name) ~= nil
end

--- A fresh copy of the piece `name`, `height` studs tall and in proportion, hidden until it is moved.
--- Returns the part and its full size.
function KitModels.piece(name: string, height: number): (BasePart, Vector3)
	local source = template(name)
	local part: BasePart
	local size: Vector3
	if source then
		part = source:Clone()
		local scale = height / math.max(source.Size.Y, 0.001)
		size = source.Size * scale
	else
		local block = Instance.new("Part")
		block.Shape = Enum.PartType.Block
		part = block
		size = Vector3.new(height * 0.32, height, height * 0.32)
	end
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Reflectance = 0.15
	local skin = part:FindFirstChildOfClass("SurfaceAppearance")
	if skin then
		skins[part] = skin
	end
	part.Size = size
	part.CFrame = CFrame.new(0, -1000, 0)
	part.Parent = folder()
	return part, size
end

local AURA_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0.82),
	NumberSequenceKeypoint.new(0.7, 0.82),
	NumberSequenceKeypoint.new(1, 1),
})
local GLINT_SIZE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.4, 0.4),
	NumberSequenceKeypoint.new(1, 0),
})
local AURA_POINTS = { -0.34, -0.12, 0.1, 0.32 } -- where along a crystal its aura is born (shares of its length)

-- Gives `part` (`size` at full size) its own aura (ice-6). The owner, with sword-aura pictures: "not
-- just one big glow ... an aura on the individual crystals", then of the first try (flame wisps born
-- anywhere in the piece's box): "too big, i want the aura to emit around each crystal ... not flame
-- wisps but a glow aura". So: soft glows no wider than the crystal, born at four points on its own
-- axis and drifting up along it, and a few small glints. The points ride with the part and go when it
-- does. NOT YET SEEN by its author: Studio's screenshots failed that day.
local function addGlow(part: BasePart, size: Vector3)
	local wide = math.min(size.X, size.Z)
	for index, share in AURA_POINTS do
		local at = Instance.new("Attachment")
		at.Name = "Aura" .. index
		at.Position = Vector3.new(0, share * size.Y, 0)
		at.Parent = part
		local glow = Instance.new("ParticleEmitter")
		glow.Name = "Glow"
		glow.Texture = FxKit.Tex.Glow
		glow.LightEmission = 1
		glow.LightInfluence = 0
		glow.Color = ColorSequence.new(Color3.fromRGB(120, 200, 255), Color3.fromRGB(225, 245, 255))
		glow.Size = NumberSequence.new(wide * 1.1, wide * 0.6)
		glow.Transparency = AURA_FADE
		glow.Lifetime = NumberRange.new(0.5, 0.8)
		glow.EmissionDirection = Enum.NormalId.Top
		glow.Speed = NumberRange.new(size.Y * 0.12, size.Y * 0.22)
		glow.SpreadAngle = Vector2.new(3, 3)
		glow.Rate = 7
		glow.Parent = at
		if index % 2 == 0 then
			local glint = Instance.new("ParticleEmitter")
			glint.Name = "Glint"
			glint.Texture = FxKit.Tex.Star
			glint.LightEmission = 1
			glint.LightInfluence = 0
			glint.Brightness = 3
			glint.Size = GLINT_SIZE
			glint.Lifetime = NumberRange.new(0.4, 0.7)
			glint.EmissionDirection = Enum.NormalId.Top
			glint.Speed = NumberRange.new(size.Y * 0.15, size.Y * 0.3)
			glint.SpreadAngle = Vector2.new(10, 10)
			glint.Rate = 2
			glint.ZOffset = 1
			glint.Parent = at
		end
	end
end

local function fraction(value: number): number
	return value - math.floor(value)
end

-- How long a thing launched upward at `up` from `height` over the floor takes to come down to it.
local function secondsToFloor(height: number, up: number): number
	if height <= 0 then
		return 0
	end
	return (up + math.sqrt(up * up + 2 * CHUNK_GRAVITY * height)) / CHUNK_GRAVITY
end

-- The chunks a broken piece bursts into: one for about every 2 studs of its length, each from its
-- own place along the piece, thrown away from the cluster's middle and upward.
local function breakApart(item: Erupt, now: number)
	local breaks = item.breaks :: Break
	local height = item.size.Y
	local count = math.clamp(math.floor(height / 2.2 + 0.5), 2, 8)
	-- What they fly away from: the cluster's middle, a quarter of this piece's height up.
	local heart = breaks.middle + Vector3.new(0, height * 0.25, 0)
	for k = 1, count do
		local u1 = fraction(math.sin(breaks.index * 12.9898 + k * 78.233) * 43758.5453)
		local u2 = fraction(math.sin(breaks.index * 39.346 + k * 11.135) * 24634.6345)
		local along = (k - 0.4) / count
		local from = (item.base * CFrame.new(0, along * height, 0)).Position
		local out = from - heart
		if out.Magnitude < 0.05 then
			out = Vector3.new(math.cos(u1 * math.pi * 2), 0.5, math.sin(u1 * math.pi * 2))
		end
		local side = Vector3.new(out.X, 0, out.Z)
		side = if side.Magnitude < 0.05
			then Vector3.new(math.cos(u1 * math.pi * 2), 0, math.sin(u1 * math.pi * 2))
			else side.Unit
		-- Mostly small; every fifth one a medium piece.
		local big = (0.45 + 1.0 * u1) * math.clamp(height / 14, 0.6, 1.2)
		if k % 5 == 0 then
			big *= 2.2
		end
		local part, size = KitModels.piece(breaks.chunk, big)
		part.Material = Enum.Material.Neon
		part.Color = WHITE
		part.Transparency = 0
		textured(part, false)
		local up = CHUNK_UP.Min + (CHUNK_UP.Max - CHUNK_UP.Min) * u2
		local away = CHUNK_OUT.Min + (CHUNK_OUT.Max - CHUNK_OUT.Min) * fraction(u1 * 5.3 + u2 * 3.7)
		-- Every other chunk breaks once, 0.7 to 1.1 s in; the others last 1.2 to 1.8 s whole. One that
		-- would reach the floor first is gone as it gets there, and does not break.
		local wanted = if k % 2 == 0 then 0.7 + 0.4 * u1 else 1.2 + 0.6 * u1
		local landing = secondsToFloor(from.Y - breaks.middle.Y, up)
		table.insert(chunks, {
			part = part,
			from = from,
			velocity = side * away + Vector3.yAxis * up,
			turn = CFrame.Angles(0, u1 * math.pi * 2, 0) * CFrame.Angles(0, 0, u2 * math.pi * 2),
			axis = Vector3.new(u1 - 0.5, u2 - 0.5, 0.31).Unit,
			rate = math.rad(200 + 300 * u2),
			size = size,
			startAt = now,
			life = math.max(math.min(wanted, landing), 0.1),
			colour = item.colour,
			hot = true,
			glow = item.glow,
			name = breaks.chunk,
			splits = if k % 2 == 0 and landing > wanted then CHUNK_SPLITS else 0,
			seed = breaks.index * 10 + k,
			floor = breaks.middle.Y,
		})
	end
end

-- Where a chunk is `t` seconds after it set off: where its launch and gravity put it. It turns as it
-- sets off and then keeps the way it faces.
local function chunkAt(item: Chunk, t: number): CFrame
	local turned = CHUNK_SPIN_SECONDS * (1 - math.exp(-t / CHUNK_SPIN_SECONDS))
	return CFrame.new(
		item.from + item.velocity * t - Vector3.new(0, 0.5 * CHUNK_GRAVITY * t * t, 0)
	) * item.turn * CFrame.fromAxisAngle(item.axis, item.rate * turned)
end

-- ice-13: a chunk that has hung for its time breaks into smaller pieces where it is (the owner, from
-- the reference: "the ice pieces dont shrink, they gradually break into smaller pieces"). Two pieces
-- ice-14: the pieces are
-- NOT pushed apart sideways (the owner: "they just cut in half and go opposite directions sideways"):
-- each carries on with the parent's own speed at that moment (ice-17) and what is left of its turning. ice-15: they start in
-- the SAME place and facing as the piece they came from and slide apart slowly, about their own size
-- in a second (the owner: "instead of teleporting apart, the pieces should slowly drift apart").
local function splitChunk(item: Chunk, now: number, at: CFrame)
	local u1 = fraction(math.sin(item.seed * 12.9898 + item.splits * 78.233) * 43758.5453)
	local u2 = fraction(math.sin(item.seed * 39.346 + item.splits * 11.135) * 24634.6345)
	local angle = u1 * math.pi * 2
	local apart = Vector3.new(math.cos(angle), (u2 - 0.5) * 0.8, math.sin(angle)).Unit
	for j = 1, 2 do
		local sign = if j == 1 then 1 else -1
		local uj = fraction(u1 * 7.31 + j * 0.37)
		local part, size = KitModels.piece(item.name, item.size.Y * CHUNK_SPLIT_SIZE)
		part.Material = Enum.Material.SmoothPlastic
		part.Color = item.colour
		part.Transparency = 0
		part.CFrame = at -- in place this very frame: the chunk loop below does not reach a new piece until the next
		-- The parent's speed as it broke, and a small push that parts the two slowly.
		local velocity = item.velocity
			- Vector3.new(0, CHUNK_GRAVITY * item.life, 0)
			+ apart * sign * item.size.Y * (0.25 + 0.2 * uj)
		local landing = secondsToFloor(at.Position.Y - item.floor, velocity.Y)
		table.insert(chunks, {
			part = part,
			from = at.Position,
			velocity = velocity,
			turn = at.Rotation,
			axis = item.axis,
			rate = item.rate * math.exp(-item.life / CHUNK_SPIN_SECONDS),
			size = size,
			startAt = now,
			life = math.max(math.min(0.5 + 0.4 * uj, landing), 0.1),
			colour = item.colour,
			hot = false,
			glow = item.glow,
			name = item.name,
			splits = item.splits - 1,
			seed = item.seed * 2 + j,
			floor = item.floor,
		})
	end
end

local function step()
	local now = os.clock()
	local slow = FxKit.slowness()
	for index = #erupting, 1, -1 do
		local item = erupting[index]
		local part = item.part
		local t = (now - item.startAt) / slow
		if part.Parent == nil then
			table.remove(erupting, index)
		elseif t >= 0 then
			local leaveAt = RISE_SECONDS + SETTLE_SECONDS + item.hold
			if item.vanish and t >= leaveAt then
				part:Destroy()
				table.remove(erupting, index)
				continue
			end
			local grown: number
			if t < RISE_SECONDS then
				local u = t / RISE_SECONDS
				grown = 1.16 * (1 - (1 - u) ^ 3)
			elseif t < RISE_SECONDS + SETTLE_SECONDS then
				grown = 1.16 - 0.16 * ((t - RISE_SECONDS) / SETTLE_SECONDS)
			elseif t < leaveAt then
				grown = 1
			else
				local u = math.clamp((t - leaveAt) / SINK_SECONDS, 0, 1)
				grown = 1 - u * u
			end
			-- White-hot on arriving and on leaving; its own colour in between.
			local phase = if t < FLASH_SECONDS then 1 elseif t < leaveAt then 2 else 3
			if phase ~= item.phase then
				item.phase = phase
				if phase == 2 then
					part.Material = item.material
					part.Color = item.colour
					part.Transparency = item.transparency
					textured(part, true)
				else
					part.Material = Enum.Material.Neon
					part.Color = WHITE
					part.Transparency = 0
					textured(part, false)
				end
			end
			if item.breaks and t >= leaveAt + BREAK_SECONDS then
				breakApart(item, now)
				part:Destroy()
				table.remove(erupting, index)
			elseif item.breaks and t >= leaveAt then
				-- Standing white-hot, swelling a little, about to break.
				local tall = item.size.Y * (1 + 0.05 * (t - leaveAt) / BREAK_SECONDS)
				part.Size = Vector3.new(item.size.X, tall, item.size.Z)
				part.CFrame = item.base * CFrame.new(0, tall / 2, 0)
			elseif t >= leaveAt + SINK_SECONDS then
				part:Destroy()
				table.remove(erupting, index)
			else
				local wide = 0.55 + 0.45 * math.min(grown, 1)
				local size = Vector3.new(
					item.size.X * wide,
					math.max(item.size.Y * grown, 0.05),
					item.size.Z * wide
				)
				part.Size = size
				part.CFrame = item.base * CFrame.new(0, size.Y / 2, 0)
			end
		end
	end
	for index = #thrown, 1, -1 do
		local item = thrown[index]
		local part = item.part
		local t = (now - item.startAt) / slow
		if part.Parent == nil or t >= item.life then
			part:Destroy()
			table.remove(thrown, index)
		elseif t >= 0 then
			local position = item.position
				+ item.velocity * t
				+ Vector3.new(0, -0.5 * item.gravity * t * t, 0)
			local share = t / item.life
			local shrink = if item.whole or share <= 0.6 then 1 else 1 - (share - 0.6) / 0.4
			part.Size = item.size * math.max(shrink, 0.05)
			part.CFrame = CFrame.new(position)
				* item.turn
				* CFrame.fromAxisAngle(item.axis, item.rate * t)
		end
	end
	for index = #swept, 1, -1 do
		local item = swept[index]
		local part = item.part
		local t = (now - item.startAt) / slow
		if part.Parent == nil or t >= item.seconds then
			part:Destroy()
			table.remove(swept, index)
		elseif t >= 0 then
			local share = t / item.seconds
			-- Fast at first, slowing: a swipe that has landed.
			local eased = 1 - (1 - share) ^ 2.2
			if item.hot and t >= FLASH_SECONDS then
				item.hot = false
				part.Material = item.material
				part.Color = item.colour
			end
			-- Thins away over its last third instead of fading.
			local thin = if share > 0.66 then 1 - (share - 0.66) / 0.34 else 1
			part.Size = Vector3.new(
				item.size.X * math.max(thin, 0.05),
				item.size.Y,
				item.size.Z * math.max(thin, 0.05)
			)
			part.CFrame = item.from:Lerp(item.to, eased)
		end
	end
	for index = #chunks, 1, -1 do
		local item = chunks[index]
		local part = item.part
		local t = (now - item.startAt) / slow
		if part.Parent == nil or t >= item.life then
			table.remove(chunks, index)
			if part.Parent ~= nil and item.splits > 0 then
				splitChunk(item, now, chunkAt(item, item.life))
			end
			part:Destroy()
		else
			if item.hot and t >= CHUNK_HOT_SECONDS then
				item.hot = false
				part.Material = Enum.Material.SmoothPlastic
				part.Color = item.colour
				part.Transparency = 0
				textured(part, true)
			end
			-- Keeps its size; only the last, smallest pieces shrink, in their final moment.
			local left = item.life - t
			if item.splits == 0 and left < CHUNK_END_SECONDS then
				part.Size = item.size * math.max(left / CHUNK_END_SECONDS, 0.05)
			end
			part.CFrame = chunkAt(item, t)
		end
	end
	for index = #laid, 1, -1 do
		local item = laid[index]
		local part = item.part
		local t = (now - item.startAt) / slow
		if part.Parent == nil or t >= LAY_SECONDS + item.hold + item.shrink then
			part:Destroy()
			table.remove(laid, index)
		elseif t >= 0 then
			local share: number
			if t < LAY_SECONDS then
				share = 0.35 + 0.65 * (1 - (1 - t / LAY_SECONDS) ^ 3)
			elseif t < LAY_SECONDS + item.hold then
				share = 1
			else
				if not item.melting then
					item.melting = true
					if item.onMelt then
						task.spawn(item.onMelt, part) -- its own thread: an error in it must not stop every piece
					end
				end
				share = math.max(1 - (t - LAY_SECONDS - item.hold) / item.shrink, 0.02)
			end
			-- Flat all the way: only its width and depth change, about its own middle.
			if share ~= item.share then
				item.share = share
				part.Size = Vector3.new(item.size.X * share, item.size.Y, item.size.Z * share)
				part.CFrame = item.cframe
			end
		end
	end
	if
		#erupting == 0
		and #thrown == 0
		and #swept == 0
		and #chunks == 0
		and #laid == 0
		and connection
	then
		connection:Disconnect()
		connection = nil
	end
end

local function run()
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

--- Bursts the piece `name` out of the floor. `base` is where its root sits, with +Y the way it
--- points. It arrives `delay` seconds from now, stands `hold` seconds, then sinks. Between its two
--- white flashes it has `colour`, `material` and `transparency`. With `breaks` it leaves by breaking
--- into flying chunks instead of sinking. With `glow` it glows from inside.
function KitModels.erupt(
	name: string,
	height: number,
	base: CFrame,
	delay: number,
	hold: number,
	colour: Color3,
	material: Enum.Material?,
	transparency: number?,
	breaks: Break?,
	glow: boolean?,
	vanish: boolean?
)
	local part, size = KitModels.piece(name, height)
	if glow then
		addGlow(part, size)
	end
	table.insert(erupting, {
		part = part,
		base = base,
		size = size,
		startAt = os.clock() + delay * FxKit.slowness(),
		hold = hold,
		colour = colour,
		material = material or Enum.Material.SmoothPlastic,
		transparency = transparency or 0.1,
		phase = 0,
		breaks = breaks,
		glow = glow,
		vanish = vanish,
	})
	run()
end

--- Throws the piece `name` as debris from `position` at `velocity`, falling under `gravity`,
--- turning as it goes, for `life` seconds.
function KitModels.throw(
	name: string,
	height: number,
	position: Vector3,
	velocity: Vector3,
	gravity: number,
	life: number,
	colour: Color3,
	material: Enum.Material?,
	whole: boolean?
): BasePart
	local part, size = KitModels.piece(name, height)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = colour
	part.Transparency = 0.05
	table.insert(thrown, {
		part = part,
		position = position,
		velocity = velocity,
		gravity = gravity,
		axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5 + 0.01).Unit,
		rate = math.rad(math.random(240, 620)),
		turn = CFrame.Angles(0, math.rad(math.random(0, 359)), math.rad(math.random(0, 359))),
		size = size,
		startAt = os.clock(),
		life = life,
		whole = whole == true,
	})
	run()
	return part
end

--- Sweeps the piece `name` from `from` to `to` (each the piece's own frame: its middle, +Y along its
--- length) in `seconds`: white-hot at first, then `colour`, thinning away at the end. For a claw
--- swiping across, or anything else that moves as one stroke.
function KitModels.sweep(
	name: string,
	length: number,
	from: CFrame,
	to: CFrame,
	seconds: number,
	colour: Color3,
	material: Enum.Material?
)
	local part, size = KitModels.piece(name, length)
	part.Material = Enum.Material.Neon
	part.Color = WHITE
	part.Transparency = 0
	part.CFrame = from
	table.insert(swept, {
		part = part,
		from = from,
		to = to,
		size = size,
		startAt = os.clock(),
		seconds = seconds,
		colour = colour,
		material = material or Enum.Material.Neon,
		hot = true,
	})
	run()
end

--- Where a piece's root goes for a spot on the floor: at `position`, pointing up but leaning `lean`
--- degrees toward `toward` (flat), and turned `yaw` degrees about its own axis.
function KitModels.rooted(position: Vector3, toward: Vector3, lean: number, yaw: number): CFrame
	local flat = Vector3.new(toward.X, 0, toward.Z)
	local frame = CFrame.new(position)
	if flat.Magnitude > 0.01 and lean ~= 0 then
		local axis = Vector3.new(0, 1, 0):Cross(flat.Unit)
		frame *= CFrame.fromAxisAngle(axis, math.rad(lean))
	end
	return frame * CFrame.Angles(0, math.rad(yaw), 0)
end

--- A copy of the flat kit piece `name`, `width` studs across at its widest and `thick` studs thick (a kit
--- tile is 1 across and paper-thin, so it is sized by its width, not its height).
function KitModels.tile(name: string, width: number, thick: number): (BasePart, Vector3)
	local source = template(name)
	local part: BasePart
	local size: Vector3
	if source then
		local across = math.max(source.Size.X, source.Size.Z, 0.001)
		part, size = KitModels.piece(name, source.Size.Y * width / across)
		size = Vector3.new(size.X, thick, size.Z)
	else
		part, size = KitModels.piece(name, thick)
		size = Vector3.new(width, thick, width)
	end
	part.Size = size
	return part, size
end

--- Lays the tile `name` flat with its middle at `cframe`: after `delay` it pops in, lies for `hold`
--- seconds, then shrinks toward its own middle over `shrink` seconds and is gone. `onMelt` is called
--- with the part as the shrinking starts (for what the melting gives off).
function KitModels.lay(
	name: string,
	width: number,
	thick: number,
	cframe: CFrame,
	delay: number,
	hold: number,
	shrink: number,
	onMelt: ((BasePart) -> ())?
)
	local part, size = KitModels.tile(name, width, thick)
	table.insert(laid, {
		part = part,
		cframe = cframe,
		size = size,
		startAt = os.clock() + delay * FxKit.slowness(),
		hold = hold,
		shrink = shrink,
		melting = false,
		onMelt = onMelt,
		share = -1,
	})
	run()
end

return KitModels
