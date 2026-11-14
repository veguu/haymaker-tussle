--!strict
-- StepBurstFx - the burst on the floor under a hard step, a dash off the ground or a landing, as a
-- replica of the one in Venomec's "Mumen Rider Combo" (YouTube 3R5WsLDp2f4, 3.27 s to 3.75 s, read
-- frame by frame at 60 fps). All particles. Decoration on this client only: nothing here can collide,
-- block a ray or affect gameplay.
--
-- THE BURST, frame by frame (1 f = 1/60 s):
--   0 f   a small white flash at the feet
--   0 f   a white crown on the floor (thin rings, dust tufts pointing outward), 2.5 studs wide, out to
--         7 studs by 4 f, gone by 13 f
--   2 f   thin white arcs lying on the floor, spinning fast, widening as they fade (to 30 f)
--   3 f   a ring of smoke puffs round it, fraying into wisps (to 45 f)
--
-- HOW IT'S BUILT. A few rigs made once and used in turn (one flat invisible anchored part each, with
-- its emitters). Nothing is created per burst. Textures: design/vfx/draw_hit_replica.ps1.

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local StepBurstFx = {}

local CROWN = "rbxassetid://73916576983471" -- hit_crown.png: thin rings and tufts pointing outward
local ARC = "rbxassetid://92074328735455" -- hit_arc.png: one thin arc
local GLOW = "rbxassetid://119052464621710" -- glow_soft.png: a soft round glow
local SMOKE = "rbxassetid://97818702295807" -- hit_smoke.png: flipbook, 4 x 4, a puff fraying into wisps

local WHITE = Color3.new(1, 1, 1)
local SMOKE_GREY = Color3.fromRGB(236, 239, 243)
local PARK = CFrame.new(0, -1000, 0)
local FRAME = 1 / 60
local RIGS = 6
local WIDTH = 6.5 -- of the part the smoke rises from, at scale 1
local LIFT = 0.6 -- the part sits this far above the floor, so the smoke isn't half buried
local FLOOR_REACH = 7 -- how far under the point a floor is looked for
local QUALITY = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then 0.6
	else 1

type Layer = {
	emitter: ParticleEmitter,
	amount: number,
	delay: number,
	size: { NumberSequenceKeypoint }, -- at scale 1
}

type Rig = {
	floor: Part,
	layers: { Layer },
	used: number, -- counts up each time the rig is used, so a late layer of an old burst is dropped
}

local rigs: { Rig } = {}
local nextRig = 1
local holder: Folder? = nil

local function fade(...: number): NumberSequence
	local points = { ... }
	local keys = {}
	for index = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[index], points[index + 1]))
	end
	return NumberSequence.new(keys)
end

local function buildRig(parent: Instance): Rig
	local floor = Instance.new("Part")
	floor.Name = "HT_StepBurst"
	floor.Anchored = true
	floor.CanCollide = false
	floor.CanQuery = false
	floor.CanTouch = false
	floor.CastShadow = false
	floor.Transparency = 1
	floor.Size = Vector3.new(WIDTH, 0.2, WIDTH)
	floor.CFrame = PARK
	floor.Parent = parent
	local ground = Instance.new("Attachment")
	ground.Position = Vector3.new(0, 0.15 - LIFT, 0)
	ground.Parent = floor

	local layers: { Layer } = {}
	local function layer(
		host: Instance,
		name: string,
		texture: string,
		amount: number,
		delayFrames: number,
		...: number
	): ParticleEmitter
		local made = Instance.new("ParticleEmitter")
		made.Name = name
		made.Texture = texture
		made.Rate = 0
		made.Enabled = false
		made.LightEmission = 0.7
		made.LightInfluence = 0
		made.Color = ColorSequence.new(WHITE)
		made.Speed = NumberRange.new(0.01)
		made.EmissionDirection = Enum.NormalId.Top
		made.Parent = host
		table.insert(layers, {
			emitter = made,
			amount = amount,
			delay = delayFrames * FRAME,
			size = fade(...).Keypoints,
		})
		return made
	end
	-- Lying flat on the floor: a particle turned square to its own velocity, sent straight up.
	local function flat(emitter: ParticleEmitter)
		emitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		emitter.Rotation = NumberRange.new(0, 360)
	end

	-- 0 f. The flash at the feet.
	local flash = layer(ground, "Flash", GLOW, 1, 0, 0, 3.2, 1, 1.2)
	flash.Lifetime = NumberRange.new(0.07)
	flash.Brightness = 2
	flash.ZOffset = 1
	flash.Transparency = fade(0, 0.1, 0.6, 0.3, 1, 1)

	-- 0 f. The crown racing out along the floor.
	local crown = layer(ground, "Crown", CROWN, 1, 0, 0, 2.5, 0.25, 7, 1, 9)
	flat(crown)
	crown.Lifetime = NumberRange.new(0.22)
	crown.Brightness = 1.2
	crown.Transparency = fade(0, 0.05, 0.5, 0.4, 1, 1)

	-- 2 f. Thin arcs lying on the floor, spinning.
	local arcs = layer(ground, "Arcs", ARC, 2, 2, 0, 4, 1, 7.5)
	flat(arcs)
	arcs.Lifetime = NumberRange.new(0.35, 0.5)
	arcs.RotSpeed = NumberRange.new(300, 520)
	arcs.Brightness = 2
	arcs.Transparency = fade(0, 0.1, 0.6, 0.35, 1, 1)

	-- 3 f. Smoke round it: each puff plays the flipbook once, swelling and fraying into wisps.
	local smoke = layer(floor, "Smoke", SMOKE, 12, 3, 0, 2.6, 1, 5)
	smoke.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	smoke.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	smoke.Shape = Enum.ParticleEmitterShape.Disc
	smoke.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	smoke.Speed = NumberRange.new(0.5, 2)
	smoke.SpreadAngle = Vector2.new(80, 80)
	smoke.Color = ColorSequence.new(SMOKE_GREY)
	smoke.LightEmission = 0.3
	smoke.Lifetime = NumberRange.new(0.5, 0.75)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Drag = 2
	smoke.Transparency = fade(0, 0.2, 0.6, 0.4, 1, 1)

	return { floor = floor, layers = layers, used = 0 }
end

local function takeRig(): Rig
	local parent = holder
	if not parent or parent.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "HT_StepBurstFx"
		made.Parent = workspace
		holder = made
		parent = made
		rigs = {}
		nextRig = 1
	end
	local rig = rigs[nextRig]
	if not rig then
		rig = buildRig(parent :: Folder)
		rigs[nextRig] = rig
	end
	nextRig = nextRig % RIGS + 1
	return rig
end

--- A burst on the floor under `position` (nothing if there's no floor within reach). `scale` is its
--- size against the reference's (1).
function StepBurstFx.play(position: Vector3, scale: number)
	local ignore: { Instance } = CollectionService:GetTagged("HT_Combatant")
	if holder then
		table.insert(ignore, holder)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = workspace:Raycast(position, Vector3.new(0, -FLOOR_REACH, 0), params)
	if not hit then
		return
	end

	local rig = takeRig()
	rig.used += 1
	local use = rig.used
	rig.floor.CFrame = CFrame.new(hit.Position + Vector3.new(0, LIFT, 0))
	rig.floor.Size = Vector3.new(WIDTH * scale, 0.2, WIDTH * scale)
	for _, layer in rig.layers do
		local emitter = layer.emitter
		local points = table.create(#layer.size)
		for index, point in layer.size do
			points[index] = NumberSequenceKeypoint.new(point.Time, point.Value * scale)
		end
		emitter.Size = NumberSequence.new(points)
		local amount = if layer.amount <= 3
			then layer.amount
			else math.max(1, math.floor(layer.amount * QUALITY + 0.5))
		if layer.delay <= 0 then
			emitter:Emit(amount)
		else
			task.delay(layer.delay, function()
				-- Dropped if the rig has been moved to a newer burst meanwhile.
				if rig.used == use and emitter.Parent then
					emitter:Emit(amount)
				end
			end)
		end
	end
end

--- Builds every rig ahead of the first burst, so the textures are loaded by then.
function StepBurstFx.preload()
	for _ = 1, RIGS do
		takeRig()
	end
end

return StepBurstFx
