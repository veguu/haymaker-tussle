--!strict
-- SwingTrailFx - what a swing leaves in the air, after the slash ribbons in Scrippage's "Weapon
-- Switcher" (YouTube UOoYfyJhQN8; frames 919-969 and 1097-1108 in the vault's "VFX Ref V10").
-- Trails and particles only. Decoration on this client only: nothing here can collide, block a ray or
-- affect gameplay.
--
-- WHAT THE REFERENCE SHOWS (H = one character height). The ribbon is THIN, 0.06 to 0.12 H wide, and
-- long, up to 2.4 H. It is white with a narrow coloured edge. It reaches its full length as the swing
-- ends and is erased from its oldest end in 4 to 6 frames, leaving a hook at the tip for a moment. A
-- few four-point sparkles come AFTER the swing and sit where they are, only shrinking.
--
-- IN THE STYLE (Fx/FxKit): a swing is air, not a hit, so it is white. The hit colour is only a thin
-- second line inside the white one. Three tones in all: white-hot line, coloured line, and a faint
-- wide body behind them. NO BLACK LINE (the user, 2026-11-14: "i dont think black lines are good for
-- the m1 swing trails").
--
-- Its direction is never chosen: every line is drawn by the limb's own movement, so it always
-- follows the swing. The sparkles are upright four-point stars, not turned at random.
--
-- HOW IT'S BUILT. One set per limb (attachments, four Trails, one emitter), made the first time that
-- limb swings and reused.

local FxKit = require(script.Parent.FxKit)

local SwingTrailFx = {}

local fade = FxKit.fade

local REACH = 1.1 -- how far past the fist or foot the bright line runs
local BODY = 1.5 -- how wide the faint body is, from the bright line back up the limb
local LINE = 0.11 -- half the thickness of the white line (0.22 studs: about 0.05 H)
local TINT_IN = 0.34 -- how far inside the white line the coloured one runs
local SPARKLES = 2

type Rig = {
	body: Trail,
	line: Trail,
	tint: Trail,
	sparkles: ParticleEmitter,
	token: number, -- counts up each swing, so an old swing's timers do nothing
}

local rigs: { [BasePart]: Rig } = setmetatable({}, { __mode = "k" }) :: any

local function attachment(limb: BasePart, name: string, height: number): Attachment
	local made = Instance.new("Attachment")
	made.Name = name
	made.Position = Vector3.new(0, height, 0)
	made.Parent = limb
	return made
end

-- A thin line drawn by two attachments `half` either side of `height` on the limb.
local function thinLine(limb: BasePart, name: string, height: number, half: number): Trail
	local made = Instance.new("Trail")
	made.Name = name
	made.Attachment0 = attachment(limb, name .. "A", height - half)
	made.Attachment1 = attachment(limb, name .. "B", height + half)
	made.FaceCamera = true
	made.MinLength = 0.05
	made.LightInfluence = 0
	made.Enabled = false
	made.Parent = limb
	return made
end

local function build(limb: BasePart): Rig
	-- A limb's fist or foot is its lower end.
	local fist = -limb.Size.Y / 2
	local tip = fist - REACH

	-- The faint wide body: flat in the plane of the swing, brightest along the tip's path.
	local body = Instance.new("Trail")
	body.Name = "HT_SwingBody"
	body.Attachment0 = attachment(limb, "HT_SwingBodyTip", tip)
	body.Attachment1 = attachment(limb, "HT_SwingBodyIn", tip + BODY)
	body.Texture = FxKit.Tex.Ribbon
	body.TextureMode = Enum.TextureMode.Stretch
	body.TextureLength = 1
	body.FaceCamera = false
	body.MinLength = 0.05
	body.LightEmission = 0.3
	body.LightInfluence = 0
	body.Color = ColorSequence.new(FxKit.WHITE)
	body.Transparency = fade(0, 0.55, 0.5, 0.75, 1, 1)
	body.WidthScale = NumberSequence.new(1, 0.2)
	body.Enabled = false
	body.Parent = limb

	-- The white-hot line the tip draws: the ribbon itself. It narrows to nothing at its oldest end.
	local line = thinLine(limb, "HT_SwingLine", tip, LINE)
	line.LightEmission = 1
	line.Brightness = 3
	line.Color = ColorSequence.new(FxKit.WHITE)
	line.Transparency = fade(0, 0, 0.7, 0.15, 1, 1)
	line.WidthScale = NumberSequence.new(1, 0.1)

	-- The coloured line just inside it: thinner, dimmer, lasting a little longer, so the hit colour
	-- is what is left as the white goes.
	local tint = thinLine(limb, "HT_SwingTint", tip + TINT_IN, LINE * 0.7)
	tint.LightEmission = 0.6
	tint.Brightness = 1.6
	tint.Transparency = fade(0, 0.15, 0.6, 0.4, 1, 1)
	tint.WidthScale = NumberSequence.new(1, 0.1)

	-- The sparkles: upright four-point stars that appear after the swing and shrink where they are.
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "HT_SwingSparkles"
	sparkles.Texture = FxKit.Tex.Star
	sparkles.Rate = 0
	sparkles.Enabled = false
	sparkles.LightEmission = 0.9
	sparkles.LightInfluence = 0
	sparkles.Brightness = 2.5
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5, 0.15),
		NumberSequenceKeypoint.new(0.2, 0.6, 0.2),
		NumberSequenceKeypoint.new(1, 0, 0),
	})
	sparkles.Lifetime = NumberRange.new(0.2, 0.32)
	sparkles.Speed = NumberRange.new(0.5, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Drag = 6
	sparkles.Rotation = NumberRange.new(0)
	sparkles.RotSpeed = NumberRange.new(0)
	sparkles.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)
	sparkles.Parent = body.Attachment0

	return { body = body, line = line, tint = tint, sparkles = sparkles, token = 0 }
end

--- A swing of `limb` (an arm or a leg): its lines for `seconds`, each bit of them lasting `life`
--- seconds, and a couple of sparkles when it strikes, `strike` seconds in. `colour` is the hit colour
--- of the thin second line (plain white without one).
function SwingTrailFx.play(
	limb: BasePart,
	seconds: number,
	life: number,
	strike: number,
	colour: Color3?
)
	local rig = rigs[limb]
	if not rig or rig.body.Parent ~= limb then
		rig = build(limb)
		rigs[limb] = rig
	end
	local hue = colour or FxKit.PLAIN
	rig.tint.Color = ColorSequence.new(hue:Lerp(FxKit.WHITE, 0.35), hue:Lerp(FxKit.BLACK, 0.25))
	rig.sparkles.Color = ColorSequence.new(FxKit.WHITE, hue:Lerp(FxKit.WHITE, 0.5))
	rig.body.Lifetime = life
	rig.line.Lifetime = life * 0.85
	rig.tint.Lifetime = life * 1.25
	local trails = { rig.body, rig.line, rig.tint }
	for _, trail in trails do
		trail:Clear()
		trail.Enabled = true
	end
	rig.token += 1
	local token = rig.token
	local shown = rig
	task.delay(strike, function()
		if shown.token == token and shown.sparkles.Parent then
			shown.sparkles:Emit(SPARKLES)
		end
	end)
	task.delay(seconds, function()
		if shown.token == token then
			for _, trail in trails do
				trail.Enabled = false
			end
		end
	end)
end

return SwingTrailFx
