--!strict
-- SwingTrailFx - the ribbon a swing leaves in the air, as a replica of the slashes in Scrippage's
-- "Weapon Switcher" (YouTube UOoYfyJhQN8, 9.55 s to 10.2 s, read frame by frame at 60 fps). Trails and
-- particles only. Decoration on this client only: nothing here can collide, block a ray or affect
-- gameplay.
--
-- WHAT THE REFERENCE SHOWS. The blade drags a pale see-through ribbon behind it, as wide as the blade
-- is long: brightest along the tip's path, streaked along the swing, narrowing to a point where it
-- fades. The tip itself draws a thin bright line. A few four-point glints hang in the air after it.
-- Here the "blade" runs from the forearm (or shin) to a little past the fist (or foot).
--
-- Its direction is never chosen: the ribbon is drawn by the limb's own movement, so it always follows
-- the swing. The glints are upright four-point stars, not turned at random.
--
-- HOW IT'S BUILT. One set per limb (four attachments, two Trails, one emitter), made the first time
-- that limb swings and reused. Textures: design/vfx/draw_hit_replica.ps1.

local SwingTrailFx = {}

local RIBBON = "rbxassetid://136226108329170" -- hit_ribbon.png: a bright tip edge, thinning streaks
local STAR = "rbxassetid://124927142938107" -- hit_star.png: a four-point glint

local WHITE = Color3.new(1, 1, 1)
local PALE_BLUE = Color3.fromRGB(110, 190, 255) -- the reference's blue, deepened to show on bright ground
local REACH = 1.1 -- how far past the fist or foot the ribbon's bright edge runs
local INSIDE = 1 -- how far up the limb from the fist or foot its inner edge sits
local EDGE = 0.09 -- half the thickness of the tip's bright line
local GLINTS = 4

type Rig = {
	ribbon: Trail,
	edge: Trail,
	glints: ParticleEmitter,
	token: number, -- counts up each swing, so an old swing's timers do nothing
}

local rigs: { [BasePart]: Rig } = setmetatable({}, { __mode = "k" }) :: any

local function fade(...: number): NumberSequence
	local points = { ... }
	local keys = {}
	for index = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[index], points[index + 1]))
	end
	return NumberSequence.new(keys)
end

local function attachment(limb: BasePart, name: string, height: number): Attachment
	local made = Instance.new("Attachment")
	made.Name = name
	made.Position = Vector3.new(0, height, 0)
	made.Parent = limb
	return made
end

local function build(limb: BasePart): Rig
	-- A limb's fist or foot is its lower end.
	local fist = -limb.Size.Y / 2
	local tip = attachment(limb, "HT_SwingTip", fist - REACH)
	local inner = attachment(limb, "HT_SwingInner", fist + INSIDE)
	local edgeA = attachment(limb, "HT_SwingEdgeA", fist - REACH - EDGE)
	local edgeB = attachment(limb, "HT_SwingEdgeB", fist - REACH + EDGE)

	-- The ribbon: flat in the plane of the swing, its bright edge along the tip's path.
	local ribbon = Instance.new("Trail")
	ribbon.Name = "HT_SwingRibbon"
	ribbon.Attachment0 = tip
	ribbon.Attachment1 = inner
	ribbon.Texture = RIBBON
	ribbon.TextureMode = Enum.TextureMode.Stretch
	ribbon.TextureLength = 1
	ribbon.FaceCamera = false
	ribbon.MinLength = 0.05
	ribbon.LightEmission = 0.35
	ribbon.LightInfluence = 0
	ribbon.Brightness = 1.3
	ribbon.Transparency = fade(0, 0.05, 0.5, 0.35, 1, 1)
	ribbon.WidthScale = NumberSequence.new(1, 0.15)
	ribbon.Enabled = false
	ribbon.Parent = limb

	-- The thin bright line the tip draws.
	local edge = Instance.new("Trail")
	edge.Name = "HT_SwingEdge"
	edge.Attachment0 = edgeA
	edge.Attachment1 = edgeB
	edge.FaceCamera = true
	edge.MinLength = 0.05
	edge.LightEmission = 1
	edge.LightInfluence = 0
	edge.Brightness = 3
	edge.Transparency = fade(0, 0, 0.7, 0.2, 1, 1)
	edge.WidthScale = NumberSequence.new(1, 0.1)
	edge.Enabled = false
	edge.Parent = limb

	-- The glints: upright four-point stars that swell, shrink and drift a little.
	local glints = Instance.new("ParticleEmitter")
	glints.Name = "HT_SwingGlints"
	glints.Texture = STAR
	glints.Rate = 0
	glints.Enabled = false
	glints.LightEmission = 0.9
	glints.LightInfluence = 0
	glints.Brightness = 2.5
	glints.Size = fade(0, 0.2, 0.3, 1.1, 1, 0)
	glints.Lifetime = NumberRange.new(0.25, 0.4)
	glints.Speed = NumberRange.new(3, 9)
	glints.SpreadAngle = Vector2.new(180, 180)
	glints.Drag = 3
	glints.Rotation = NumberRange.new(0)
	glints.RotSpeed = NumberRange.new(0)
	glints.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)
	glints.Parent = tip

	return { ribbon = ribbon, edge = edge, glints = glints, token = 0 }
end

--- A swing of `limb` (an arm or a leg): its ribbon and tip line for `seconds`, each bit of them
--- lasting `life` seconds, and a few glints when it strikes, `strike` seconds in. `colour` tints it;
--- without one it's the reference's pale blue.
function SwingTrailFx.play(
	limb: BasePart,
	seconds: number,
	life: number,
	strike: number,
	colour: Color3?
)
	local rig = rigs[limb]
	if not rig or rig.ribbon.Parent ~= limb then
		rig = build(limb)
		rigs[limb] = rig
	end
	local tint = colour or PALE_BLUE
	rig.ribbon.Color = ColorSequence.new(WHITE, tint)
	rig.edge.Color = ColorSequence.new(tint:Lerp(WHITE, 0.4), tint)
	rig.glints.Color = ColorSequence.new(WHITE, tint)
	rig.ribbon.Lifetime = life
	rig.edge.Lifetime = life * 0.8
	rig.ribbon:Clear()
	rig.edge:Clear()
	rig.ribbon.Enabled = true
	rig.edge.Enabled = true
	rig.token += 1
	local token = rig.token
	local shown = rig
	task.delay(strike, function()
		if shown.token == token and shown.glints.Parent then
			shown.glints:Emit(GLINTS)
		end
	end)
	task.delay(seconds, function()
		if shown.token == token then
			shown.ribbon.Enabled = false
			shown.edge.Enabled = false
		end
	end)
end

return SwingTrailFx
