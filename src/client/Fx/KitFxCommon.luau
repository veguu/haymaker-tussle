--!strict
-- KitFxCommon - what the four ability kits' effect modules share (InfernoFx, FrostFx, BeastFx,
-- DragonFx): each kit's colours, the layer recipes they are all built from, pieces laid out as the
-- camera sees them, and emitters that run for a while on a moving body. Built on Fx/FxKit. Decoration
-- on this client only: nothing here can collide, block a ray or affect gameplay.
--
-- THESE ARE NOT PLAIN. The game's ordinary effects are white and grey, small and short (FxKit's style,
-- the user, 2026-11-14). The kits' skills are the exception the user asked for on 2026-11-15: "very
-- detailed very flashy", in each kit's own colour, "just like the references". So an ability gets what
-- the reference study found a big hit to be (vault: 63 VFX Creation/Reference Study, the Consolidated
-- Reference Sheet), in this order:
--   a one-frame cue; the main shape at full size at once, white first and coloured after; the layer
--   that shows direction; sparks that fly briefly and stop; rings; then leftovers that last four to
--   ten times the bright part: smoke, embers, sparkles, a mark that keeps the place.
-- One hue per kit, as a ramp: white-hot, bright, body, deep. Black only as thin accents.
-- Still true from FxKit: pointed shapes are placed on purpose, and sizes are real (a particle is drawn
-- TWICE its Size across; H is one character height).

local FxKit = require(script.Parent.FxKit)

local Common = {}

local Tex = FxKit.Tex
local fade = FxKit.fade

export type Palette = {
	white: Color3, -- white-hot: cores and first frames
	bright: Color3, -- the light end of the hue
	body: Color3, -- the hue itself
	deep: Color3, -- a darker version that still glows
	smoke: Color3, -- what its smoke or mist is
}

-- Inferno: white-yellow, yellow-orange, orange-red (xander22 "Projectiles VFX Pack" f2574).
-- Frost: white core, cyan edge, saturated blue tail (Hazaze "Frigid Rush" f65, f645).
-- Beast: red with black accents (Divergent Vfx "Acheron Ultimate" f294; Venomec "Mumen Rider" f141).
-- Dragon: violet with a pink-white core (DoubleCats "Sword Combat VFX" f12-16).
Common.Palettes = {
	Inferno = {
		white = Color3.fromRGB(255, 248, 220),
		bright = Color3.fromRGB(255, 208, 84),
		body = Color3.fromRGB(255, 122, 28),
		deep = Color3.fromRGB(214, 44, 16),
		smoke = Color3.fromRGB(92, 78, 74),
	},
	Frost = {
		white = Color3.fromRGB(238, 252, 255),
		bright = Color3.fromRGB(150, 228, 255),
		body = Color3.fromRGB(70, 176, 255),
		deep = Color3.fromRGB(34, 92, 232),
		smoke = Color3.fromRGB(206, 232, 250),
	},
	Beast = {
		white = Color3.fromRGB(255, 234, 226),
		bright = Color3.fromRGB(255, 98, 70),
		body = Color3.fromRGB(238, 34, 34),
		deep = Color3.fromRGB(132, 8, 22),
		smoke = Color3.fromRGB(74, 58, 60),
	},
	Dragon = {
		white = Color3.fromRGB(252, 238, 255),
		bright = Color3.fromRGB(216, 150, 255),
		body = Color3.fromRGB(154, 82, 255),
		deep = Color3.fromRGB(76, 34, 188),
		smoke = Color3.fromRGB(150, 132, 178),
	},
	-- Bruiser: gold (Nyght "Light Moveset": white-hot core, yellow body, orange only on fading parts).
	Bruiser = {
		white = Color3.fromRGB(255, 250, 226),
		bright = Color3.fromRGB(255, 224, 112),
		body = Color3.fromRGB(255, 176, 40),
		deep = Color3.fromRGB(196, 104, 14),
		smoke = Color3.fromRGB(156, 144, 126),
	},
	-- Trickster: pink-magenta (Divergent Vfx "Acheron Ultimate": magenta held for the dash cores).
	Trickster = {
		white = Color3.fromRGB(255, 240, 250),
		bright = Color3.fromRGB(255, 150, 214),
		body = Color3.fromRGB(255, 64, 170),
		deep = Color3.fromRGB(150, 20, 110),
		smoke = Color3.fromRGB(128, 104, 138),
	},
	-- The Base and Tempest kits' skills stay in the game's plain white and grey.
	Plain = {
		white = Color3.fromRGB(255, 255, 255),
		bright = Color3.fromRGB(255, 255, 255),
		body = Color3.fromRGB(236, 239, 243),
		deep = Color3.fromRGB(190, 196, 206),
		smoke = Color3.fromRGB(236, 239, 243),
	},
} :: { [string]: Palette }

--- A ColorSequence through these colours, evenly spaced (one colour: flat).
function Common.ramp(...: Color3): ColorSequence
	local colours = { ... }
	if #colours == 1 then
		return ColorSequence.new(colours[1])
	end
	local points = {}
	for index, colour in colours do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colours - 1), colour))
	end
	return ColorSequence.new(points)
end

--- Which way `direction` points on the screen, in degrees anticlockwise from screen-right. A
--- camera-facing particle whose texture points right (Needle, Leaf) aims that way with this as its
--- Rotation; one whose texture points or bulges up (Shard, Claw, Arc, Wisp) with this minus 90.
function Common.screenAngle(direction: Vector3): number
	local camera = workspace.CurrentCamera
	local frame = if camera then camera.CFrame else CFrame.new()
	local x = direction:Dot(frame.RightVector)
	local y = direction:Dot(frame.UpVector)
	if math.abs(x) + math.abs(y) < 0.001 then
		return 90
	end
	return math.deg(math.atan2(y, x))
end

-- THE LAYER RECIPES. Each takes an emitter fresh from FxKit's `add` and sets what that kind of layer
-- always has; the effect then sets its own colour and anything particular.

--- A white-hot ball: the first frames of a hit or a release.
function Common.flash(emitter: ParticleEmitter, life: number)
	emitter.Lifetime = NumberRange.new(life)
	emitter.Brightness = 3
	emitter.ZOffset = 1
	emitter.Transparency = fade(0, 0, 0.5, 0.15, 1, 1)
end

--- A ring or other round shape that only widens and fades.
function Common.ring(emitter: ParticleEmitter, life: number)
	emitter.Lifetime = NumberRange.new(life)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Brightness = 1.8
	emitter.Transparency = fade(0, 0.1, 0.5, 0.4, 1, 1)
end

--- Flipbook smoke or mist: plays once, swelling and fading.
function Common.smoke(emitter: ParticleEmitter, colour: Color3, lifeMin: number, lifeMax: number)
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	emitter.Color = ColorSequence.new(colour)
	emitter.LightEmission = 0.25
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Drag = 3
	emitter.Lifetime = NumberRange.new(lifeMin, lifeMax)
	emitter.Transparency = fade(0, 0.35, 0.6, 0.55, 1, 1)
end

--- Flipbook flame tongues (FxKit.Tex.Wisp). The texture rises, so the effect aims it with Rotation.
function Common.flame(emitter: ParticleEmitter, lifeMin: number, lifeMax: number)
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	emitter.LightEmission = 0.75
	emitter.Brightness = 1.6
	emitter.Drag = 4
	emitter.Lifetime = NumberRange.new(lifeMin, lifeMax)
	emitter.Transparency = fade(0, 0.05, 0.55, 0.25, 1, 1)
end

--- Streaks shot from a part's front face, lying along their flight. `squash` below zero is longer
--- and thinner.
function Common.streaks(emitter: ParticleEmitter, squash: number, lifeMin: number, lifeMax: number)
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Drag = 5
	emitter.Brightness = 2
	emitter.Squash = NumberSequence.new(squash)
	emitter.Lifetime = NumberRange.new(lifeMin, lifeMax)
	emitter.Transparency = fade(0, 0.05, 0.6, 0.15, 1, 1)
end

--- Pieces thrown out that fly briefly and stop (Nyght "Light Moveset" f4789-4791: petals fly about
--- one character height in a frame and stop). `spread` 180 is every way; less is a cone.
function Common.thrown(
	emitter: ParticleEmitter,
	spread: number,
	drag: number,
	lifeMin: number,
	lifeMax: number
)
	emitter.SpreadAngle = Vector2.new(spread, spread)
	emitter.Drag = drag
	emitter.Lifetime = NumberRange.new(lifeMin, lifeMax)
	emitter.Transparency = fade(0, 0, 0.7, 0.15, 1, 1)
end

--- Four-point sparkles that stay where they appear and only grow and shrink (Hazaze "Frigid Rush"
--- f47; xander22 f2265-2284: ice sparkles stay still and twinkle).
function Common.twinkle(emitter: ParticleEmitter, lifeMin: number, lifeMax: number)
	emitter.Lifetime = NumberRange.new(lifeMin, lifeMax)
	emitter.Rotation = NumberRange.new(0)
	emitter.Brightness = 3
	emitter.ZOffset = 1.4
	emitter.Transparency = fade(0, 0, 0.8, 0, 1, 1)
end

--- Small grains that outlast everything else and drift (xander22 f2585-2590: embers for 70 frames).
function Common.embers(emitter: ParticleEmitter, lifeMin: number, lifeMax: number)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 2.5
	emitter.Brightness = 2.5
	emitter.ZOffset = 0.6
	emitter.Lifetime = NumberRange.new(lifeMin, lifeMax)
	emitter.Transparency = fade(0, 0, 0.75, 0.1, 1, 1)
end

-- PIECES LAID OUT AS THE CAMERA SEES THEM. Like FxKit.placed, for any texture: one emitter each, on
-- an attachment of a part that is turned to face the camera for each use (FxKit.screenAt).

export type Piece = {
	emitter: ParticleEmitter,
	at: Attachment,
	angle: number, -- degrees, measured from the effect's own direction
	radius: number, -- how far out its middle sits, in studs
	turn: number, -- added to its Rotation: 0 for textures that point right, -90 for ones that point up
	spin: number, -- degrees a second it turns, mirrored with the layout
}

--- Makes one piece per spec on `face`. A spec is { angle, radius, Size, spin?, turn? } (its own turn
--- replaces `turn`: minus its angle keeps a piece parallel to the effect's direction). `shape` turns a
--- piece's Size into its size over its life (time, share of Size, time, share...); `setup` gives each
--- emitter its look. `gap` is how many frames later each piece appears than the one before.
function Common.pieces(
	add: FxKit.Add,
	face: Part,
	name: string,
	texture: string,
	turn: number,
	delayFrames: number,
	specs: { { number } },
	shape: { number },
	setup: (emitter: ParticleEmitter, index: number) -> (),
	gap: number?
): { Piece }
	local list: { Piece } = {}
	for index, spec in specs do
		local seat = FxKit.attach(face)
		local size = spec[3]
		local points = {}
		for at = 1, #shape, 2 do
			table.insert(points, NumberSequenceKeypoint.new(shape[at], shape[at + 1] * size))
		end
		local made =
			add(seat, name .. index, texture, 1, delayFrames + (gap or 0) * (index - 1), points)
		setup(made, index)
		table.insert(list, {
			emitter = made,
			at = seat,
			angle = spec[1],
			radius = spec[2],
			turn = spec[5] or turn,
			spin = spec[4] or 0,
		})
	end
	return list
end

--- Puts pieces where they belong for one use. `base` is the screen angle of the effect's direction
--- (Common.screenAngle); each piece sits at base + its own angle, or base - it when `mirror` is -1.
function Common.place(list: { Piece }, base: number, mirror: number, scale: number)
	for _, piece in list do
		local angle = base + piece.angle * mirror
		local radians = math.rad(angle)
		piece.at.Position = Vector3.new(math.cos(radians), math.sin(radians), 0)
			* piece.radius
			* scale
		piece.emitter.Rotation = NumberRange.new(angle + piece.turn)
		piece.emitter.RotSpeed = NumberRange.new(piece.spin * mirror)
	end
end

--- Specs for a starburst of needles for FxKit.placed: `count` spikes round a point, no two alike
--- (Venomec "Mumen Rider" f139: straight needle spikes of uneven length and direction). Lengths are
--- in studs, most of them short and a few long. The same `seed` always gives the same star.
function Common.starSpecs(
	count: number,
	shortest: number,
	longest: number,
	squash: number,
	seed: number
): { { number } }
	local random = Random.new(seed)
	local specs = {}
	for index = 1, count do
		local angle = (index - 1) * 360 / count + random:NextNumber(-13, 13)
		local length = shortest + (longest - shortest) * random:NextNumber() ^ 1.7
		-- A needle is 2 x Size x 2^-squash long, and sits half its length out.
		table.insert(specs, { angle, length / 2, length / (2 * 2 ^ -squash) })
	end
	return specs
end

-- EMITTERS THAT RUN FOR A WHILE ON A MOVING BODY: a flame trail, frost underfoot, sparkles behind a
-- launched fighter. Made once per body part and kept; each use switches them on for its length.

type Stream = { at: Attachment, emitters: { ParticleEmitter }, rates: { number }, token: number }

local streams: { [BasePart]: { [string]: Stream } } = setmetatable({}, { __mode = "k" }) :: any

--- A fresh emitter for a stream, off, set up as FxKit's layers are.
function Common.emitter(
	host: Instance,
	name: string,
	texture: string,
	rate: number
): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Name = name
	made.Texture = texture
	made.Rate = rate
	made.Enabled = false
	made.LightEmission = 1
	made.LightInfluence = 0
	made.Color = ColorSequence.new(FxKit.WHITE)
	made.Speed = NumberRange.new(0)
	made.Parent = host
	return made
end

--- Runs the stream `key` on `part` for `seconds`. The first time, `build` makes its emitters on an
--- attachment at `offset` (in the part's own space) and returns them.
function Common.stream(
	part: BasePart,
	key: string,
	seconds: number,
	offset: Vector3,
	build: (at: Attachment) -> { ParticleEmitter }
)
	local byKey = streams[part]
	if not byKey then
		byKey = {}
		streams[part] = byKey
	end
	local stream = byKey[key]
	if not stream or stream.at.Parent ~= part then
		local at = Instance.new("Attachment")
		at.Name = "HT_Kit" .. key
		at.Position = offset
		at.Parent = part
		local emitters = build(at)
		local rates = {}
		for index, emitter in emitters do
			rates[index] = emitter.Rate
		end
		stream = { at = at, emitters = emitters, rates = rates, token = 0 }
		byKey[key] = stream
	end
	stream.token += 1
	local token = stream.token
	local slow = FxKit.slowness()
	for index, emitter in stream.emitters do
		emitter.Rate = stream.rates[index] * FxKit.QUALITY
		emitter.TimeScale = 1 / slow
		emitter.Enabled = true
	end
	task.delay(seconds * slow, function()
		if stream.token == token then
			for _, emitter in stream.emitters do
				emitter.Enabled = false
			end
		end
	end)
end

--- Switches a pooled rig's own running emitters on for `seconds`, starting `delayFrames` after the
--- rig was fired. Dropped if the rig has been given to a newer use meanwhile.
function Common.run(
	rig: FxKit.Rig,
	emitters: { ParticleEmitter },
	delayFrames: number,
	seconds: number
)
	local use = rig.used
	local slow = FxKit.slowness()
	local function stop()
		for _, emitter in emitters do
			emitter.Enabled = false
		end
	end
	stop()
	task.delay(delayFrames * FxKit.FRAME * slow, function()
		if rig.used ~= use then
			return
		end
		for _, emitter in emitters do
			emitter.TimeScale = 1 / slow
			emitter.Enabled = true
		end
		task.delay(seconds * slow, function()
			if rig.used == use then
				stop()
			end
		end)
	end)
end

--- A body's feet on the floor: the floor under `root` if there is one within `reach`, else nil.
function Common.floorAt(root: BasePart, reach: number): Vector3?
	return FxKit.floorUnder(root.Position, reach)
end

-- THE THICK LAYERS (2026-11-15, after the first kit effects were turned down as "thin" and "too
-- bright"). Every one of a kit's effects is built from these, in the kit's own tones, so each frame
-- has a dark saturated shade, the colour as a solid mass, a thin white core and one accent
-- (vault: "VFX Readability and Value - Lessons from Blind Reviews"). FrostFx has its own copy of the
-- same recipes, written first.

export type Tones = {
	ink: Color3, -- the dark shade: a deep, saturated version of the hue, never grey
	deep: Color3,
	body: Color3,
	bright: Color3,
	white: Color3,
	accent: Color3, -- one contrasting hue, for motes and a few sparks only
	smoke: Color3,
}

export type Thick = {
	darkSmoke: (
		add: FxKit.Add,
		host: Instance,
		amount: number,
		delay: number,
		big: number
	) -> ParticleEmitter,
	haze: (
		add: FxKit.Add,
		host: Instance,
		amount: number,
		delay: number,
		big: number
	) -> ParticleEmitter,
	chips: (
		add: FxKit.Add,
		host: Instance,
		amount: number,
		delay: number,
		spread: number,
		speed: NumberRange,
		big: number
	) -> ParticleEmitter,
	motes: (add: FxKit.Add, host: Instance, amount: number, delay: number) -> ParticleEmitter,
	flash: (add: FxKit.Add, at: Instance, big: number, delay: number) -> ParticleEmitter,
	floorRing: (
		add: FxKit.Add,
		at: Attachment,
		name: string,
		delay: number,
		from: number,
		to: number,
		tone: number
	) -> ParticleEmitter,
	stain: (add: FxKit.Add, at: Attachment, big: number, life: number) -> (),
	rays: (add: FxKit.Add, host: BasePart, count: number, big: number) -> (),
	star: (add: FxKit.Add, face: Part, long: number) -> { { Piece } },
	lens: (
		add: FxKit.Add,
		host: Instance,
		amount: number,
		delay: number,
		spread: number
	) -> ParticleEmitter,
}

local STAR_SHAPE = { 0, 1, 0.35, 0.85, 1, 0.15 }

--- Puts every tone of a star where it belongs (Common.place for each).
function Common.placeAll(sets: { { Piece } }, base: number)
	for _, set in sets do
		Common.place(set, base, 1, 1)
	end
end

--- The thick layers in one kit's tones.
function Common.thick(tones: Tones): Thick
	local ramp = Common.ramp
	local thick = {} :: any

	-- Dark smoke: the shade behind the bright parts.
	function thick.darkSmoke(add, host, amount, delay, big)
		local made = add(
			host,
			"DarkSmoke" .. delay,
			Tex.Smoke,
			amount,
			delay,
			FxKit.curve(0, big, big * 0.3, 1, big * 2, big * 0.5),
			{ speed = NumberRange.new(big * 1.2, big * 3) }
		)
		Common.smoke(made, tones.ink, 0.7, 1.1)
		made.Color = ramp(tones.ink, tones.deep)
		made.LightEmission = 0
		made.ZOffset = -2
		made.SpreadAngle = Vector2.new(180, 180)
		made.Transparency = fade(0, 0.15, 0.5, 0.35, 1, 1)
		return made
	end

	-- Pale smoke, mist or dust over it.
	function thick.haze(add, host, amount, delay, big)
		local made = add(
			host,
			"Haze" .. delay,
			Tex.Smoke,
			amount,
			delay,
			FxKit.curve(0, big, big * 0.3, 1, big * 2.1, big * 0.5),
			{ speed = NumberRange.new(big, big * 2.5) }
		)
		Common.smoke(made, tones.smoke, 0.6, 1)
		made.LightEmission = 0.15
		made.SpreadAngle = Vector2.new(180, 180)
		return made
	end

	-- Solid-coloured chips thrown out that fly briefly and fall.
	function thick.chips(add, host, amount, delay, spread, speed, big)
		local made = add(
			host,
			"Chips" .. delay,
			Tex.Leaf,
			amount,
			delay,
			FxKit.curve(0, big, big * 0.4, 1, big * 0.5, big * 0.2),
			{ speed = speed }
		)
		Common.thrown(made, spread, 3, 0.5, 0.9)
		made.Orientation = Enum.ParticleOrientation.VelocityParallel
		made.Squash = NumberSequence.new(-0.3)
		made.Acceleration = Vector3.new(0, -60, 0)
		made.LightEmission = 0.3
		made.Brightness = 1.6
		made.Color = ramp(tones.white, tones.bright, tones.body)
		return made
	end

	-- Motes in the accent hue that drift up and outlast the rest.
	function thick.motes(add, host, amount, delay)
		local made = add(
			host,
			"Motes" .. delay,
			Tex.Glow,
			amount,
			delay,
			FxKit.curve(0, 0.45, 0.2, 0.7, 0.35, 0.15, 1, 0, 0),
			{ speed = NumberRange.new(3, 9) }
		)
		Common.embers(made, 0.9, 1.5)
		made.Acceleration = Vector3.new(0, 5, 0)
		made.Color = ramp(tones.white, tones.accent)
		return made
	end

	-- The white flash a big shape arrives in.
	function thick.flash(add, at, big, delay)
		local made = add(
			at,
			"Flash" .. delay,
			Tex.Glow,
			1,
			delay,
			FxKit.keys(0, big * 0.7, 0.3, big, 1, big * 0.4)
		)
		Common.flash(made, 0.1)
		made.Color = ramp(tones.white, tones.bright)
		return made
	end

	-- A ring on the floor. Tone 1 is white to bright, 2 bright to body, 3 body to deep.
	function thick.floorRing(add, at, name, delay, from, to, tone)
		local made = add(
			at,
			name,
			Tex.Circle,
			1,
			delay,
			FxKit.keys(0, from, 0.3, to * 0.85, 1, to),
			{ flat = true, onFloor = true }
		)
		Common.ring(made, 0.36)
		made.Brightness = 2.4
		made.Color = if tone == 1
			then ramp(tones.white, tones.bright)
			elseif tone == 2 then ramp(tones.bright, tones.body)
			else ramp(tones.body, tones.deep)
		return made
	end

	-- The dark stain a burst leaves on the floor, with a glow of the colour over it.
	function thick.stain(add, at, big, life)
		local dark = add(
			at,
			"Stain",
			Tex.Glow,
			1,
			0,
			FxKit.keys(0, big * 0.7, 0.2, big, 1, big * 1.1),
			{ flat = true, onFloor = true }
		)
		dark.Lifetime = NumberRange.new(life)
		dark.LightEmission = 0
		dark.Color = ramp(tones.ink, tones.deep)
		dark.Transparency = fade(0, 0.2, 0.7, 0.35, 1, 1)
		local glow = add(
			at,
			"StainGlow",
			Tex.Glow,
			1,
			1,
			FxKit.keys(0, big * 0.45, 0.2, big * 0.7, 1, big * 0.8),
			{ flat = true, onFloor = true }
		)
		glow.Lifetime = NumberRange.new(life * 0.8)
		glow.LightEmission = 0.4
		glow.Color = ramp(tones.bright, tones.body)
		glow.Transparency = fade(0, 0.35, 0.6, 0.55, 1, 1)
	end

	-- Thin white rays standing up out of a burst.
	function thick.rays(add, host, count, big)
		for index = 1, count do
			local at = FxKit.attach(host, Vector3.new((index - (count + 1) / 2) * big * 0.9, 0, 0))
			local ray =
				add(at, "Ray" .. index, Tex.Leaf, 1, index - 1, FxKit.keys(0, big, 1, big * 1.25))
			Common.flash(ray, 0.2)
			ray.Rotation = NumberRange.new(84 + index * 4)
			ray.Squash = fade(0, -1.2, 1, -2.4)
			ray.Color = ramp(tones.white, tones.bright)
		end
	end

	-- A star in three tones: dark spikes, the colour over them, a few thin white ones on top.
	function thick.star(add, face, long)
		local function spikes(
			name: string,
			count: number,
			short: number,
			far: number,
			squash: number,
			seed: number,
			setup: (emitter: ParticleEmitter) -> ()
		)
			return Common.pieces(
				add,
				face,
				name,
				Tex.Needle,
				0,
				0,
				Common.starSpecs(count, short, far, squash, seed),
				STAR_SHAPE,
				function(emitter)
					emitter.Squash = NumberSequence.new(squash)
					emitter.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)
					setup(emitter)
				end
			)
		end
		return {
			spikes("DeepSpike", 9, long * 0.5, long, -0.7, 31, function(emitter)
				emitter.Lifetime = NumberRange.new(0.22, 0.3)
				emitter.LightEmission = 0
				emitter.ZOffset = 0.4
				emitter.Color = ramp(tones.deep, tones.ink)
			end),
			spikes("Spike", 13, long * 0.4, long * 1.15, -1, 7, function(emitter)
				emitter.Lifetime = NumberRange.new(0.18, 0.26)
				emitter.LightEmission = 0.3
				emitter.Brightness = 1.8
				emitter.ZOffset = 1
				emitter.Color = ramp(tones.bright, tones.body)
			end),
			spikes("HotSpike", 6, long * 0.5, long * 1.3, -1.7, 19, function(emitter)
				emitter.Lifetime = NumberRange.new(0.12, 0.18)
				emitter.Brightness = 3
				emitter.ZOffset = 1.6
				emitter.Color = ColorSequence.new(tones.white)
			end),
		}
	end

	-- Lens-shaped sparks: big, few, thrown and stopped (Ako Shiba "Megumin Explosion", YouTube
	-- NQfkrr8xEIM: ember ovals a head across; Divergent Vfx f258).
	function thick.lens(add, host, amount, delay, spread)
		local made = add(
			host,
			"Lens" .. delay,
			Tex.Leaf,
			amount,
			delay,
			FxKit.curve(0, 1.1, 0.5, 1, 0.5, 0.2),
			{ speed = NumberRange.new(40, 85) }
		)
		Common.thrown(made, spread, 7, 0.2, 0.36)
		made.Orientation = Enum.ParticleOrientation.VelocityParallel
		made.Squash = NumberSequence.new(-0.5)
		made.LightEmission = 0.4
		made.Brightness = 2.2
		made.Color = ramp(tones.white, tones.bright, tones.body)
		return made
	end

	return thick
end

Common.Tex = Tex

return Common
