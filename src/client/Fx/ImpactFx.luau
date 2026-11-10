--!strict
-- ImpactFx - the spark of a punch: a white star flash, thin spikes shooting out of it and a scatter of
-- small shards, all particles. A small one marks where a swing cuts the air, a big one where a punch
-- lands. Decoration on this client only: nothing here can collide, block a ray or affect gameplay.
--
-- HOW IT'S BUILT. A few invisible anchored parts, each with its own set of emitters, made once and
-- used in turn: a burst moves the next one to the spot and tells its emitters to throw a fixed number
-- of particles. Nothing is created per punch. The textures are Roblox's own built-in ones, so there is
-- nothing to upload.

local UserInputService = game:GetService("UserInputService")

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

	-- The star in the middle: there for a blink, swelling as it goes.
	local flash = emitter(at, "Flash")
	flash.Lifetime = NumberRange.new(0.1, 0.14)
	flash.Speed = NumberRange.new(0)
	flash.Rotation = NumberRange.new(0, 360)
	flash.Brightness = 6
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

	-- The shards: small bits thrown wider and slower, that hang a moment and fall.
	local shards = emitter(at, "Shards")
	shards.Orientation = Enum.ParticleOrientation.VelocityParallel
	shards.Lifetime = NumberRange.new(0.25, 0.45)
	shards.Drag = 4
	shards.Acceleration = Vector3.new(0, -30, 0)
	shards.Squash = NumberSequence.new(-0.8)
	shards.Brightness = 3
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
--- spikes and shards are thrown mostly that way, a spray off the hit; without one they go all round.
function ImpactFx.burst(position: Vector3, direction: Vector3?, scale: number)
	local kit = takeKit()
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
		NumberSequenceKeypoint.new(0, 0.75 * scale),
		NumberSequenceKeypoint.new(1, 0.15 * scale),
	})
	kit.shards:Emit(count(10))
end

return ImpactFx
