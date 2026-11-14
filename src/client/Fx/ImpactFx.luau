--!strict
-- ImpactFx - the spark of a punch: a white star flash, thin spikes shooting out of it and a scatter of
-- small shards, all particles, where a punch lands. A swing that hits nothing shows only a thin streak
-- behind the fist (fistTrail). Decoration on this client only: nothing here can collide, block a ray or affect gameplay.
--
-- HOW IT'S BUILT. A few invisible anchored parts, each with its own set of emitters, made once and
-- used in turn: a burst moves the next one to the spot and tells its emitters to throw a fixed number
-- of particles. Nothing is created per punch. The textures are Roblox's own built-in ones, so there is
-- nothing to upload.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GustStyle = require(ReplicatedStorage.Shared.Config.GustStyle)

local ImpactFx = {}

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local WHITE = Color3.new(1, 1, 1)
local EDGE = Color3.fromRGB(120, 170, 255)
local PARK = CFrame.new(0, -1000, 0)
local KITS = 6
local QUALITY = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then 0.6
	else 1

type Kit = {
	part: Part,
	flash: ParticleEmitter,
	spikes: ParticleEmitter,
	shards: ParticleEmitter,
}

local kits: { Kit } = {}
local nextKit = 1
local holder: Folder? = nil

local function emitter(parent: Instance, name: string): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Name = name
	made.Texture = SPARK_TEXTURE
	made.Rate = 0
	made.Enabled = false
	made.LightEmission = 1
	made.LightInfluence = 0
	made.Color = ColorSequence.new(WHITE, EDGE)
	made.Parent = parent
	return made
end

local function buildKit(parent: Instance): Kit
	local part = Instance.new("Part")
	part.Name = "HT_Impact"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = PARK
	local at = Instance.new("Attachment")
	at.Parent = part

	-- The glint in the middle (the style's four-point star, ink-edged): there for a blink, swelling as
	-- it goes. Drawn as it is, not as a glow, so its ink edge shows against a bright sky.
	local flash = emitter(at, "Flash")
	flash.Texture = GustStyle.Images.Flare
	flash.Color = ColorSequence.new(WHITE, GustStyle.Wind)
	flash.Lifetime = NumberRange.new(0.1, 0.14)
	flash.Speed = NumberRange.new(0)
	flash.Rotation = NumberRange.new(-12, 12)
	flash.Brightness = 3
	flash.ZOffset = 1
	flash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- The spikes: sprites stretched thin along the way they fly, fast and gone almost at once.
	local spikes = emitter(at, "Spikes")
	spikes.Orientation = Enum.ParticleOrientation.VelocityParallel
	spikes.Lifetime = NumberRange.new(0.1, 0.2)
	spikes.Drag = 7
	spikes.Squash = NumberSequence.new(-3.2)
	spikes.Brightness = 4
	spikes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- The motes (the style's diamonds, ink-edged): small bits thrown wider and slower, long axis along
	-- the way they fly, that hang a moment and fall. White, or the kit's accent on a heavy hit.
	local shards = emitter(at, "Shards")
	shards.Texture = GustStyle.Images.MoteGlow
	shards.Color = ColorSequence.new(WHITE)
	shards.Orientation = Enum.ParticleOrientation.VelocityParallel
	shards.Lifetime = NumberRange.new(0.25, 0.45)
	shards.Drag = 4
	shards.Acceleration = Vector3.new(0, -30, 0)
	shards.Brightness = 1.6
	shards.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})

	part.Parent = parent
	return { part = part, flash = flash, spikes = spikes, shards = shards }
end

local function takeKit(): Kit
	local parent = holder
	if not parent or parent.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "HT_ImpactFx"
		made.Parent = workspace
		holder = made
		parent = made
		kits = {}
		nextKit = 1
	end
	local kit = kits[nextKit]
	if not kit then
		kit = buildKit(parent :: Folder)
		kits[nextKit] = kit
	end
	nextKit = nextKit % KITS + 1
	return kit
end

local function count(amount: number): number
	return math.max(1, math.floor(amount * QUALITY + 0.5))
end

--- A burst at `position`, `scale` times the size of an ordinary landed punch. With a `direction` the
--- spikes and motes are thrown mostly that way, a spray off the hit; without one they go all round.
--- `accent` (a kit's colour, for heavy hits) colours the motes; without it they're white.
function ImpactFx.burst(position: Vector3, direction: Vector3?, scale: number, accent: Color3?)
	local kit = takeKit()
	kit.shards.Color = ColorSequence.new(accent or WHITE)
	local aim = if direction and direction.Magnitude > 0.01 then direction.Unit else nil
	kit.part.CFrame = if aim then CFrame.lookAt(position, position + aim) else CFrame.new(position)
	local spread = if aim then Vector2.new(70, 70) else Vector2.new(180, 180)

	kit.flash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2 * scale),
		NumberSequenceKeypoint.new(0.35, 5.5 * scale),
		NumberSequenceKeypoint.new(1, 3.4 * scale),
	})
	kit.flash:Emit(2)

	kit.spikes.SpreadAngle = spread
	kit.spikes.Speed = NumberRange.new(55 * scale, 115 * scale)
	kit.spikes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.6 * scale),
		NumberSequenceKeypoint.new(1, 0.7 * scale),
	})
	kit.spikes:Emit(count(14))

	kit.shards.SpreadAngle = spread
	kit.shards.Speed = NumberRange.new(18 * scale, 46 * scale)
	kit.shards.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6 * scale),
		NumberSequenceKeypoint.new(1, 0.14 * scale),
	})
	kit.shards:Emit(count(if accent then 12 else 7))
end

local fistTrails: { [BasePart]: Trail } = setmetatable({}, { __mode = "k" }) :: any
local fistTokens: { [Trail]: number } = setmetatable({}, { __mode = "k" }) :: any

--- A thin streak behind the fist of `arm` for `seconds`: the after-image of a swing. `width` is how
--- thick it is in studs and `life` how long each bit of it lasts, so it stays short and close to the
--- hand. One Trail per arm, made the first time that arm swings and reused.
function ImpactFx.fistTrail(arm: BasePart, seconds: number, width: number, life: number)
	local trail = fistTrails[arm]
	if not trail or trail.Parent ~= arm then
		local drop = arm.Size.Y / 2 - 0.15
		local top = Instance.new("Attachment")
		top.Name = "HT_FistTrailA"
		top.Position = Vector3.new(0, -drop, width / 2)
		top.Parent = arm
		local bottom = Instance.new("Attachment")
		bottom.Name = "HT_FistTrailB"
		bottom.Position = Vector3.new(0, -drop, -width / 2)
		bottom.Parent = arm
		local made = Instance.new("Trail")
		made.Name = "HT_FistTrail"
		made.Attachment0 = top
		made.Attachment1 = bottom
		made.FaceCamera = true
		made.MinLength = 0.05
		made.Color = ColorSequence.new(WHITE, EDGE)
		made.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		made.WidthScale = NumberSequence.new(1, 0.2)
		made.LightEmission = 1
		made.LightInfluence = 0
		made.Enabled = false
		made.Parent = arm
		fistTrails[arm] = made
		trail = made
	end
	local shown = trail :: Trail
	-- Its width can change from swing to swing (a charged one is wider).
	local drop = arm.Size.Y / 2 - 0.15
	if shown.Attachment0 and shown.Attachment1 then
		shown.Attachment0.Position = Vector3.new(0, -drop, width / 2)
		shown.Attachment1.Position = Vector3.new(0, -drop, -width / 2)
	end
	shown.Lifetime = life
	shown:Clear()
	shown.Enabled = true
	local token = (fistTokens[shown] or 0) + 1
	fistTokens[shown] = token
	task.delay(seconds, function()
		if fistTokens[shown] == token then
			shown.Enabled = false
		end
	end)
end

-- THE GROUND BLAST: what a body slamming into the floor throws up. A flash and spikes going up and out,
-- a ring of light racing outward along the floor, a short pillar of light, embers drifting up and a
-- skirt of dust. Its parts are made once and reused, like the bursts.
local GOLD = Color3.fromRGB(255, 214, 120)
local EMBER = Color3.fromRGB(255, 150, 50)
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local BLASTS = 3

local FIRE = Color3.fromRGB(255, 120, 30)
local SOOT = Color3.fromRGB(60, 48, 42)

type Blast = {
	part: Part,
	flash: ParticleEmitter,
	spikes: ParticleEmitter,
	embers: ParticleEmitter,
	dust: ParticleEmitter,
	fireball: ParticleEmitter,
	smoke: ParticleEmitter,
	ring: Part,
	pillar: Part,
}

local blasts: { Blast } = {}
local nextBlast = 1
local blastHolder: Folder? = nil

local function glowPart(parent: Instance, name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 1, 1)
	part.CFrame = PARK
	part.Parent = parent
	return part
end

local function buildBlast(parent: Instance): Blast
	local part = Instance.new("Part")
	part.Name = "HT_GroundBlast"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = PARK
	local at = Instance.new("Attachment")
	-- Emitters throw along the attachment's front, which here points straight up.
	at.CFrame = CFrame.lookAt(Vector3.zero, Vector3.yAxis, Vector3.zAxis)
	at.Parent = part

	local flash = emitter(at, "Flash")
	flash.Lifetime = NumberRange.new(0.12, 0.18)
	flash.Speed = NumberRange.new(0)
	flash.Rotation = NumberRange.new(0, 360)
	flash.Brightness = 7
	flash.ZOffset = 2
	flash.Color = ColorSequence.new(WHITE, GOLD)
	flash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})

	local spikes = emitter(at, "Spikes")
	spikes.Orientation = Enum.ParticleOrientation.VelocityParallel
	spikes.Lifetime = NumberRange.new(0.14, 0.28)
	spikes.SpreadAngle = Vector2.new(80, 80)
	spikes.Drag = 6
	spikes.Squash = NumberSequence.new(-3.4)
	spikes.Brightness = 5
	spikes.Color = ColorSequence.new(WHITE, GOLD)
	spikes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- Embers: small sparks thrown up that slow, hang and drift higher as they go out.
	local embers = emitter(at, "Embers")
	embers.Lifetime = NumberRange.new(0.7, 1.4)
	embers.SpreadAngle = Vector2.new(55, 55)
	embers.Drag = 3
	embers.Acceleration = Vector3.new(0, 9, 0)
	embers.Rotation = NumberRange.new(0, 360)
	embers.Brightness = 4
	embers.Color = ColorSequence.new(GOLD, EMBER)
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- Dust: thrown out low all round, swelling as it fades. Lit by the scene, so it reads as dirt.
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = DUST_TEXTURE
	dust.Rate = 0
	dust.Enabled = false
	dust.Lifetime = NumberRange.new(0.6, 1.1)
	dust.SpreadAngle = Vector2.new(88, 88)
	dust.Drag = 4
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-50, 50)
	dust.Color = ColorSequence.new(Color3.fromRGB(214, 200, 180))
	dust.LightEmission = 0.15
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Parent = at

	-- The fireball: big glowing puffs that burst up and out, white-hot to orange, and go dark as they cool.
	local fireball = Instance.new("ParticleEmitter")
	fireball.Name = "Fireball"
	fireball.Texture = DUST_TEXTURE
	fireball.Rate = 0
	fireball.Enabled = false
	fireball.Lifetime = NumberRange.new(0.35, 0.6)
	fireball.SpreadAngle = Vector2.new(70, 70)
	fireball.Drag = 7
	fireball.Acceleration = Vector3.new(0, 14, 0)
	fireball.Rotation = NumberRange.new(0, 360)
	fireball.RotSpeed = NumberRange.new(-90, 90)
	fireball.LightEmission = 1
	fireball.LightInfluence = 0
	fireball.Brightness = 3
	fireball.ZOffset = 1
	fireball.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.2, GOLD),
		ColorSequenceKeypoint.new(0.55, FIRE),
		ColorSequenceKeypoint.new(1, SOOT),
	})
	fireball.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fireball.Parent = at

	-- The smoke: a dark cloud left behind, rising slowly and spreading as it thins.
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = DUST_TEXTURE
	smoke.Rate = 0
	smoke.Enabled = false
	smoke.Lifetime = NumberRange.new(1.2, 2)
	smoke.SpreadAngle = Vector2.new(60, 60)
	smoke.Drag = 3
	smoke.Acceleration = Vector3.new(0, 6, 0)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 80, 74), Color3.fromRGB(150, 140, 132))
	smoke.LightEmission = 0
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Parent = at

	part.Parent = parent
	return {
		part = part,
		flash = flash,
		spikes = spikes,
		embers = embers,
		dust = dust,
		fireball = fireball,
		smoke = smoke,
		ring = glowPart(parent, "HT_GroundRing"),
		pillar = glowPart(parent, "HT_GroundPillar"),
	}
end

local function takeBlast(): Blast
	local parent = blastHolder
	if not parent or parent.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "HT_GroundBlastFx"
		made.Parent = workspace
		blastHolder = made
		parent = made
		blasts = {}
		nextBlast = 1
	end
	local blast = blasts[nextBlast]
	if not blast then
		blast = buildBlast(parent :: Folder)
		blasts[nextBlast] = blast
	end
	nextBlast = nextBlast % BLASTS + 1
	return blast
end

-- A flat glowing disc or an upright column: a cylinder grown and faded out. A cylinder's length runs
-- along its X axis, so it is turned to point that up. `upright` keeps its foot on the floor as it grows.
local function glow(
	part: Part,
	at: Vector3,
	upright: boolean,
	from: Vector3,
	to: Vector3,
	colour: Color3,
	startTransparency: number,
	seconds: number
)
	local stand = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	part.Color = colour
	part.Size = from
	part.Transparency = startTransparency
	part.CFrame = if upright then stand * CFrame.new(from.X / 2, 0, 0) else stand
	local goal: { [string]: any } = { Size = to, Transparency = 1 }
	if upright then
		goal.CFrame = stand * CFrame.new(to.X / 2, 0, 0)
	end
	local tween = TweenService:Create(
		part,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween.Completed:Connect(function()
		if part.Transparency >= 1 then
			part.CFrame = PARK
		end
	end)
	tween:Play()
end

--- An explosion on the floor at `position` (a point on the floor's surface), `scale` times the size of
--- an ordinary slam landing.
function ImpactFx.groundBlast(position: Vector3, scale: number)
	local blast = takeBlast()
	local at = position + Vector3.yAxis * 0.25
	blast.part.CFrame = CFrame.new(at)

	blast.flash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 4 * scale),
		NumberSequenceKeypoint.new(0.35, 11 * scale),
		NumberSequenceKeypoint.new(1, 7 * scale),
	})
	blast.flash:Emit(2)

	blast.spikes.Speed = NumberRange.new(70 * scale, 150 * scale)
	blast.spikes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3.4 * scale),
		NumberSequenceKeypoint.new(1, 0.9 * scale),
	})
	blast.spikes:Emit(count(22))

	blast.embers.Speed = NumberRange.new(18 * scale, 52 * scale)
	blast.embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55 * scale),
		NumberSequenceKeypoint.new(1, 0.1 * scale),
	})
	blast.embers:Emit(count(34))

	blast.dust.Speed = NumberRange.new(16 * scale, 34 * scale)
	blast.dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.5 * scale),
		NumberSequenceKeypoint.new(1, 8 * scale),
	})
	blast.dust:Emit(count(16))

	blast.fireball.Speed = NumberRange.new(14 * scale, 34 * scale)
	blast.fireball.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3 * scale),
		NumberSequenceKeypoint.new(0.4, 7 * scale),
		NumberSequenceKeypoint.new(1, 9 * scale),
	})
	blast.fireball:Emit(count(14))

	blast.smoke.Speed = NumberRange.new(6 * scale, 16 * scale)
	blast.smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5 * scale),
		NumberSequenceKeypoint.new(1, 13 * scale),
	})
	blast.smoke:Emit(count(10))

	glow(
		blast.ring,
		at,
		false,
		Vector3.new(0.15, 3 * scale, 3 * scale),
		Vector3.new(0.15, 34 * scale, 34 * scale),
		GOLD,
		0.35,
		0.4
	)
	glow(
		blast.pillar,
		at,
		true,
		Vector3.new(14 * scale, 2.4 * scale, 2.4 * scale),
		Vector3.new(26 * scale, 0.3 * scale, 0.3 * scale),
		WHITE,
		0.3,
		0.3
	)
end

return ImpactFx
