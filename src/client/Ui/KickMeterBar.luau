--!strict
-- KickMeterBar - the air kick's timing meter on screen: a bold horizontal bar near the bottom centre, red at
-- both ends through orange and yellow to green in the exact middle, with a marker running along it. The rules
-- (where the marker is, what a press is worth) are Core/KickMeter; the server scores; this only draws.
--
-- THE WHOLE BAR ANIMATES, not just the marker: its body, frame, gradient, glow, scale and opacity come in
-- together (slide up, widen from the middle, a small overshoot, colours waking from faint to full, a highlight
-- running along the frame), react to the result (a pulse on body and frame, stronger the better the timing;
-- PERFECT snaps to the middle, flashes green-white and throws a shockwave), and leave together (the glow
-- softens, the colour drains in to the middle, the bar squeezes, drops and fades).
--
-- ONE state machine drives it from one frame loop that only runs while the bar is on screen, so an old exit
-- can never hide a newly opened meter: opening simply restarts it. The scoring gradient and the centre target
-- never move while timing is live. Decoration never changes the score: the label and marker show what the
-- server recorded. Settings: GameConfig.KickMeter (styles E/X/C/F/M, sizes, timings, strengths).

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Typography = require(ReplicatedStorage.Shared.Typography)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local KickMeter = require(ReplicatedStorage.Shared.Core.KickMeter)

local cfg = GameConfig.KickMeter

local RED = Color3.fromRGB(236, 62, 54)
local ORANGE = Color3.fromRGB(255, 140, 40)
local YELLOW = Color3.fromRGB(255, 222, 62)
local GREEN = Color3.fromRGB(58, 222, 104)
local INK = Color3.fromRGB(12, 14, 22) -- the frame
local FAINT = Color3.fromRGB(120, 128, 142) -- what the colours wake from
local WHITE = Color3.new(1, 1, 1)
local STOPS = { RED, ORANGE, YELLOW, GREEN, YELLOW, ORANGE, RED } -- evenly spaced: green dead centre

local RESULT: { [string]: { text: string, colour: Color3, glow: number, pulse: number, seconds: number } } =
	{
		perfect = {
			text = "PERFECT",
			colour = Color3.fromRGB(150, 255, 178),
			glow = 1,
			pulse = 0.09,
			seconds = 0.3,
		},
		good = {
			text = "GOOD",
			colour = Color3.fromRGB(96, 232, 128),
			glow = 0.7,
			pulse = 0.05,
			seconds = 0.24,
		},
		okay = {
			text = "OKAY",
			colour = Color3.fromRGB(255, 222, 62),
			glow = 0.45,
			pulse = 0.03,
			seconds = 0.2,
		},
		poor = {
			text = "POOR",
			colour = Color3.fromRGB(255, 104, 92),
			glow = 0.3,
			pulse = 0.015,
			seconds = 0.16,
		},
		late = {
			text = "TOO LATE",
			colour = Color3.fromRGB(255, 104, 92),
			glow = 0.3,
			pulse = 0.015,
			seconds = 0.16,
		},
	}

-- How much the colour style turns everything up or down (C1 as designed, C2 stronger bloom and shimmer, C3
-- restrained saturation and opacity changes only).
local COLOUR_STYLE: { [string]: { glow: number, shimmer: number, wake: number } } = {
	C1 = { glow = 1, shimmer = 1, wake = 1 },
	C2 = { glow = 1.6, shimmer = 2.2, wake = 1 },
	C3 = { glow = 0.45, shimmer = 0, wake = 0.5 },
}

local WAIT_SECONDS = 0.6 -- a press the server never answers lets the bar go after this
local SNAP_SECONDS = 0.07 -- the marker settling on the recorded spot (PERFECT: the decorative snap to the middle)
local GLOW_PAD = 9

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function easeOut(t: number): number
	t = 1 - math.clamp(t, 0, 1)
	return 1 - t * t * t
end

local function easeIn(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t
end

local function mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local KickMeterBar = {}
KickMeterBar.__index = KickMeterBar

export type Bar = typeof(setmetatable({} :: any, KickMeterBar))

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function KickMeterBar.new(gui: ScreenGui): Bar
	local W, H = cfg.Width, cfg.Height

	-- root: placed and fitted to the screen. pose: what the animation scales (from its centre).
	local root = Instance.new("Frame")
	root.Name = "KickMeter"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(cfg.ScreenX, cfg.ScreenY)
	root.Size = UDim2.fromOffset(W, H)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Parent = root

	local pose = Instance.new("Frame")
	pose.Name = "Pose"
	pose.AnchorPoint = Vector2.new(0.5, 0.5)
	pose.Position = UDim2.fromScale(0.5, 0.5)
	pose.Size = UDim2.fromScale(1, 1)
	pose.BackgroundTransparency = 1
	pose.Parent = root

	local function layer(name: string, z: number, pad: number, radius: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.new(1, pad * 2, 1, pad * 2)
		f.BorderSizePixel = 0
		f.ZIndex = z
		f.Parent = pose
		corner(f, radius)
		return f
	end

	local radius = math.floor(H * 0.3)
	local glowFar = layer("GlowFar", 1, GLOW_PAD * 2, radius + GLOW_PAD * 2)
	local glowNear = layer("GlowNear", 1, GLOW_PAD, radius + GLOW_PAD)
	local back = layer("Frame", 2, 0, radius)
	back.BackgroundColor3 = INK
	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Color = INK
	outline.Parent = back

	local body = layer("Body", 3, -3, math.max(radius - 3, 2))
	body.BackgroundColor3 = WHITE
	local paint = Instance.new("UIGradient")
	paint.Parent = body

	local gloss = Instance.new("Frame") -- the light band along the top that makes it read as a solid bar
	gloss.Name = "Gloss"
	gloss.AnchorPoint = Vector2.new(0.5, 0)
	gloss.Position = UDim2.new(0.5, 0, 0, 6)
	gloss.Size = UDim2.new(1, -18, 0.2, 0)
	gloss.BackgroundColor3 = WHITE
	gloss.BorderSizePixel = 0
	gloss.ZIndex = 4
	gloss.Parent = pose
	corner(gloss, 4)

	-- where the marker and marks sit along the body (inset 3 px each side): share f of the way across
	local function across(f: number): UDim2
		return UDim2.new(f, (1 - 2 * f) * 3, 0.5, 0)
	end

	-- thin marks where the named results change, the same distance out on both sides
	local ticks: { Frame } = {}
	for _, accuracy in { cfg.PerfectAccuracy, cfg.GoodAccuracy, cfg.OkayAccuracy } do
		for _, side in { -1, 1 } do
			local tick = Instance.new("Frame")
			tick.Name = "Tick"
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
			tick.Position = across((side * (1 - accuracy) + 1) / 2)
			tick.Size = UDim2.new(0, 2, 1, -6)
			tick.BackgroundColor3 = INK
			tick.BorderSizePixel = 0
			tick.ZIndex = 4
			tick.Parent = pose
			table.insert(ticks, tick)
		end
	end

	local flash = layer("Flash", 4, -3, math.max(radius - 3, 2))
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1

	-- the centre target: a white line through the bar with a diamond above and below it
	local target = Instance.new("Frame")
	target.Name = "Target"
	target.AnchorPoint = Vector2.new(0.5, 0.5)
	target.Position = UDim2.fromScale(0.5, 0.5)
	target.Size = UDim2.new(0, cfg.TargetWidth, 1, 8)
	target.BackgroundColor3 = WHITE
	target.BorderSizePixel = 0
	target.ZIndex = 5
	target.Parent = pose
	local targetLine = Instance.new("UIStroke")
	targetLine.Thickness = 1.5
	targetLine.Color = INK
	targetLine.Parent = target
	local caps: { Frame } = {}
	local capLines: { UIStroke } = {}
	for _, side in { -1, 1 } do
		local cap = Instance.new("Frame")
		cap.Name = "Cap"
		cap.AnchorPoint = Vector2.new(0.5, 0.5)
		cap.Position = UDim2.new(0.5, 0, 0.5, side * (H / 2 + 9))
		cap.Size = UDim2.fromOffset(9, 9)
		cap.Rotation = 45
		cap.BackgroundColor3 = WHITE
		cap.BorderSizePixel = 0
		cap.ZIndex = 5
		cap.Parent = pose
		local line = Instance.new("UIStroke")
		line.Thickness = 1.5
		line.Color = INK
		line.Parent = cap
		table.insert(caps, cap)
		table.insert(capLines, line)
	end

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Size = UDim2.new(0, cfg.MarkerWidth, 1, cfg.MarkerOverhang * 2)
	marker.BackgroundColor3 = WHITE
	marker.BorderSizePixel = 0
	marker.ZIndex = 6
	marker.Parent = pose
	corner(marker, 2)
	local markerLine = Instance.new("UIStroke")
	markerLine.Thickness = 2.5
	markerLine.Color = Color3.new(0, 0, 0)
	markerLine.Parent = marker

	-- the highlight that runs along the frame
	local shine = layer("Shine", 7, 0, radius)
	shine.BackgroundTransparency = 1
	local shineLine = Instance.new("UIStroke")
	shineLine.Thickness = 2
	shineLine.Color = WHITE
	shineLine.Transparency = 1
	shineLine.Parent = shine
	local shineBand = Instance.new("UIGradient")
	shineBand.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.38, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.62, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	shineBand.Parent = shineLine

	-- PERFECT's shockwave: a ring the bar's shape, thrown outward
	local shock = layer("Shock", 1, 0, radius)
	shock.BackgroundTransparency = 1
	local shockLine = Instance.new("UIStroke")
	shockLine.Thickness = 3
	shockLine.Transparency = 1
	shockLine.Parent = shock

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -18)
	label.Size = UDim2.new(1, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.TextColor3 = WHITE
	label.ZIndex = 8
	Typography.apply(label, "Announce")
	label.Parent = root
	local labelLine = Instance.new("UIStroke")
	labelLine.Thickness = 2.5
	labelLine.Color = INK
	labelLine.Parent = label
	local labelPop = Instance.new("UIScale")
	labelPop.Parent = label

	local self = setmetatable({
		gui = gui,
		root = root,
		fit = fit,
		pose = pose,
		glowFar = glowFar,
		glowNear = glowNear,
		back = back,
		outline = outline,
		body = body,
		paint = paint,
		gloss = gloss,
		ticks = ticks,
		flash = flash,
		target = target,
		targetLine = targetLine,
		caps = caps,
		capLines = capLines,
		marker = marker,
		markerLine = markerLine,
		shineLine = shineLine,
		shineBand = shineBand,
		shock = shock,
		shockLine = shockLine,
		label = label,
		labelLine = labelLine,
		labelPop = labelPop,
		across = across,
		state = "hidden", -- hidden, enter, live, wait, result, exit
		since = 0,
		exitSeconds = cfg.ExitSeconds,
		position = 0, -- where the marker is drawn
		from = 0, -- where it was when the result arrived
		result = nil :: any,
		hint = "",
		connection = nil :: RBXScriptConnection?,
		lastPaint = "",
	}, KickMeterBar)
	return self
end

-- The gradient at this saturation (0 faint to 1 full), tint (toward a result colour) and opacity, showing only
-- `reveal` of the way out from the middle (1 = the whole bar).
function KickMeterBar._paint(
	self: Bar,
	saturation: number,
	alpha: number,
	reveal: number,
	tint: Color3?,
	tintShare: number
)
	local key = string.format("%.2f|%.2f|%.3f|%.2f", saturation, alpha, reveal, tintShare)
	if key == self.lastPaint and not tint then
		return
	end
	self.lastPaint = key
	local points = table.create(#STOPS)
	for i, colour in STOPS do
		local c = FAINT:Lerp(colour, saturation)
		if tint and tintShare > 0 then
			c = c:Lerp(tint, tintShare)
		end
		points[i] = ColorSequenceKeypoint.new((i - 1) / (#STOPS - 1), c)
	end
	self.paint.Color = ColorSequence.new(points)
	local clear = 1 - alpha
	if reveal >= 0.999 then
		self.paint.Transparency = NumberSequence.new(clear)
	elseif reveal <= 0.001 then
		self.paint.Transparency = NumberSequence.new(1)
	else
		local w, edge = 0.5 * reveal, 0.05
		local t1 = math.max(0.5 - w - edge, 0.0005)
		local t2 = math.max(0.5 - w, t1 + 0.0005)
		local t3 = math.max(math.min(0.5 + w, 0.999), t2 + 0.0005)
		local t4 = math.max(math.min(0.5 + w + edge, 0.9995), t3 + 0.0002)
		self.paint.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(t1, 1),
			NumberSequenceKeypoint.new(t2, clear),
			NumberSequenceKeypoint.new(t3, clear),
			NumberSequenceKeypoint.new(t4, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

type Look = {
	alpha: number, -- the whole bar's opacity
	slide: number, -- pixels down from its place
	wide: number, -- width, as a share of full
	tall: number, -- height, as a share of full
	saturation: number,
	reveal: number,
	glow: number,
	glowColour: Color3,
	shine: number?, -- where the frame highlight is, 0 to 1 along the bar (nil: none)
	shineStrength: number,
	flash: number,
	shock: number?, -- 0 to 1 through the shockwave (nil: none)
	tint: Color3?,
	tintShare: number,
	frame: Color3,
	markerAlpha: number,
	markerGrow: number,
	labelAlpha: number,
	labelScale: number,
}

local function baseLook(): Look
	return {
		alpha = 1,
		slide = 0,
		wide = 1,
		tall = 1,
		saturation = 1,
		reveal = 1,
		glow = 0.25,
		glowColour = WHITE,
		shine = nil,
		shineStrength = 0,
		flash = 0,
		shock = nil,
		tint = nil,
		tintShare = 0,
		frame = INK,
		markerAlpha = 1,
		markerGrow = 1,
		labelAlpha = 1,
		labelScale = 1,
	}
end

local function entranceLook(u: number): Look
	local look = baseLook()
	local style = cfg.Entrance
	local wake = (COLOUR_STYLE[cfg.ColourStyle] or COLOUR_STYLE.C1).wake
	local faint = mix(1, cfg.FaintSaturation, wake)
	if style == "E2" then
		-- a crisp reveal from the middle out: no slide, no overshoot
		look.reveal = easeOut(u / 0.8)
		look.alpha = smooth(u / 0.3)
		look.saturation = mix(faint, 1, smooth(u / 0.8))
	elseif style == "E3" then
		-- energy lines assemble it: the frame is drawn by the highlight first, then the colour fills from the middle
		look.alpha = smooth(u / 0.35)
		look.reveal = easeOut((u - 0.35) / 0.65)
		look.saturation = mix(faint, 1, smooth((u - 0.35) / 0.65))
		look.shine = u / 0.6
		look.shineStrength = 1
		look.glow = 0.25 + 0.5 * math.sin(math.pi * math.clamp(u, 0, 1))
	else
		-- E1: slide up, widen from the middle, overshoot a little, settle; the colours wake as it lands
		local over = cfg.EntranceOvershoot
		local grown = if u < 0.6
			then mix(0.5, 1 + over, easeOut(u / 0.6))
			else mix(1 + over, 1, smooth((u - 0.6) / 0.4))
		look.wide = grown
		look.tall = if u < 0.6
			then mix(0.7, 1 + over * 1.5, easeOut(u / 0.6))
			else mix(1 + over * 1.5, 1, smooth((u - 0.6) / 0.4))
		look.slide = cfg.EntranceSlide * (1 - easeOut(u / 0.7))
		look.alpha = smooth(u / 0.45)
		look.saturation = mix(faint, 1, smooth((u - 0.15) / 0.75))
		look.shine = (u - 0.25) / 0.75
		look.shineStrength = 0.9
		look.glow = 0.25 + 0.35 * math.sin(math.pi * math.clamp(u, 0, 1))
	end
	look.markerAlpha = smooth((u - 0.45) / 0.45)
	look.labelAlpha = smooth((u - 0.3) / 0.5)
	return look
end

local function exitLook(u: number, glowColour: Color3, glowFrom: number): Look
	local look = baseLook()
	local style = cfg.Exit
	look.glowColour = glowColour
	look.markerAlpha = 1 - smooth(u / 0.4)
	look.labelAlpha = 1 - smooth(u / 0.6)
	if style == "X2" then
		-- collapse into a thin streak of light, which then closes
		look.tall = mix(1, 0.08, easeOut(u / 0.5))
		look.saturation = 1 - smooth(u / 0.4)
		look.flash = smooth(u / 0.45) * 0.9
		look.wide = mix(1, 0.02, easeIn((u - 0.4) / 0.6))
		look.alpha = 1 - smooth((u - 0.75) / 0.25)
		look.glow = glowFrom * (1 - u)
	elseif style == "X3" then
		-- a soft dissolve: almost no movement
		look.alpha = 1 - smooth(u)
		look.glow = glowFrom * (1 - smooth(u / 0.7))
		look.saturation = mix(1, 0.6, smooth(u))
	else
		-- X1: the glow softens, the colour and light draw in to the middle, then squeeze, drop and fade
		look.glow = glowFrom * (1 - smooth(u / 0.6))
		look.reveal = 1 - easeIn(u / 0.85)
		look.tall = mix(1, 0.6, easeIn(u))
		look.wide = mix(1, 0.92, easeIn(u))
		look.slide = cfg.ExitSlide * easeIn(u)
		look.alpha = 1 - smooth((u - 0.35) / 0.65)
	end
	return look
end

local function resultLook(r: number, result: any, total: number): Look
	local look = baseLook()
	local show = RESULT[result.name]
	local style = cfg.PerfectStyle
	local perfect = result.name == "perfect"
	local beat = math.clamp(r / show.seconds, 0, 1)
	local hit = math.sin(math.pi * beat) -- up and back over the feedback
	local fade = 1 - beat
	local pulse = show.pulse
	if perfect and style == "F2" then
		pulse *= 1.9 -- the arcade bounce
		hit = math.abs(math.sin(math.pi * 2 * beat)) * (1 - beat * 0.5)
	elseif perfect and style == "F3" then
		pulse *= 0.4
	end
	look.wide = 1 + pulse * hit
	look.tall = 1 + pulse * 1.6 * hit
	look.glowColour = show.colour
	-- strongest at the hit, then it softens through the hold (the exit takes it from there)
	look.glow = show.glow * mix(1.6, 0.8, smooth(r / math.max(total, 0.01)))
	look.tint = show.colour
	look.tintShare = 0.4 * show.glow * fade
	look.frame = INK:Lerp(show.colour, 0.85 * show.glow * fade)
	look.labelScale = 1 + 0.35 * show.glow * (1 - smooth(r / 0.14))
	if result.name == "good" or perfect then
		look.shine = r / (show.seconds * 0.9)
		look.shineStrength = if perfect then 1 else 0.6
	end
	if perfect and style ~= "F3" then
		look.flash = 0.85 * (1 - smooth(r / (show.seconds * 0.8)))
		look.shock = r / (show.seconds * 1.2)
		look.markerGrow = 1 + 0.6 * fade
	end
	return look
end

function KickMeterBar._apply(self: Bar, look: Look)
	local styleMix = COLOUR_STYLE[cfg.ColourStyle] or COLOUR_STYLE.C1
	local a = math.clamp(look.alpha, 0, 1)
	local clear = 1 - a
	self.root.Position = UDim2.new(cfg.ScreenX, 0, cfg.ScreenY, look.slide)
	self.pose.Size = UDim2.fromScale(look.wide, look.tall)

	-- ColourIntensity scales how far the colour transitions go (the result tint and the flash), never the
	-- scoring gradient itself
	local intensity = math.clamp(cfg.ColourIntensity, 0, 2)
	self:_paint(
		math.clamp(look.saturation, 0, 1),
		a,
		look.reveal,
		look.tint,
		math.clamp(look.tintShare * intensity, 0, 1)
	)
	self.back.BackgroundTransparency = mix(1, 0.08, a)
	self.outline.Transparency = clear
	self.outline.Color = look.frame
	-- the gloss draws in with the colour
	self.gloss.Size = UDim2.new(look.reveal, -18 * look.reveal, 0.2, 0)
	self.gloss.BackgroundTransparency = 1 - 0.28 * a * look.reveal
	for _, tick in self.ticks do
		tick.BackgroundTransparency = 1 - 0.45 * a * look.reveal
	end
	self.target.BackgroundTransparency = clear
	self.targetLine.Transparency = clear
	for i, cap in self.caps do
		cap.BackgroundTransparency = clear
		self.capLines[i].Transparency = clear
	end

	local glow = math.clamp(look.glow * cfg.GlowStrength * styleMix.glow, 0, 1.6) * a
	self.glowNear.BackgroundColor3 = look.glowColour
	self.glowFar.BackgroundColor3 = look.glowColour
	self.glowNear.BackgroundTransparency = 1 - math.clamp(0.3 * glow, 0, 0.7)
	self.glowFar.BackgroundTransparency = 1 - math.clamp(0.14 * glow, 0, 0.4)

	self.flash.BackgroundTransparency = 1 - math.clamp(look.flash * intensity, 0, 1) * a
	if look.shine and look.shine >= 0 and look.shine <= 1 and look.shineStrength > 0 then
		self.shineBand.Offset = Vector2.new(mix(-0.62, 0.62, look.shine), 0)
		self.shineLine.Transparency = 1 - math.clamp(look.shineStrength, 0, 1) * a
	else
		self.shineLine.Transparency = 1
	end
	if look.shock and look.shock >= 0 and look.shock < 1 then
		local s = easeOut(look.shock)
		self.shock.Size = UDim2.new(1 + 0.22 * s, 0, 1 + 2.4 * s, 0)
		self.shockLine.Color = look.glowColour
		self.shockLine.Transparency = 1 - (1 - look.shock) * 0.9 * a
	else
		self.shockLine.Transparency = 1
	end

	local m = math.clamp(look.markerAlpha, 0, 1) * a
	self.marker.Position = self.across((math.clamp(self.position, -1, 1) + 1) / 2)
	self.marker.Size =
		UDim2.new(0, cfg.MarkerWidth * look.markerGrow, 1, cfg.MarkerOverhang * 2 * look.markerGrow)
	self.marker.BackgroundTransparency = 1 - m
	self.markerLine.Transparency = 1 - m

	local l = math.clamp(look.labelAlpha, 0, 1) * a
	self.label.TextTransparency = 1 - l
	self.labelLine.Transparency = 1 - l
	self.labelPop.Scale = look.labelScale
end

function KickMeterBar._fit(self: Bar)
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local scale = math.clamp(math.min(view.X / 1280, view.Y / 720), cfg.ScaleMin, cfg.ScaleMax)
	-- never wider than its share of a narrow screen
	scale = math.min(scale, view.X * cfg.MaxWidthShare / cfg.Width)
	self.fit.Scale = scale
end

function KickMeterBar._stop(self: Bar)
	self.state = "hidden"
	self.root.Visible = false
	self.result = nil
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

function KickMeterBar._leave(self: Bar, seconds: number)
	self.state = "exit"
	self.since = os.clock()
	self.exitSeconds = math.max(seconds, 0.01)
end

function KickMeterBar._frame(self: Bar)
	local now = os.clock()
	local t = now - self.since
	local reduced = GuiService.ReducedMotionEnabled
	local look: Look
	if self.state == "enter" then
		local u = t / math.max(cfg.EntranceSeconds, 0.01)
		if u >= 1 then
			self.state = "live"
			self.since = now
			look = baseLook()
		else
			look = entranceLook(u)
		end
	elseif self.state == "live" or self.state == "wait" then
		look = baseLook()
		-- a quiet shimmer along the FRAME only: the scoring colours and the target never move
		local styleMix = COLOUR_STYLE[cfg.ColourStyle] or COLOUR_STYLE.C1
		local strength = cfg.ShimmerStrength * styleMix.shimmer
		if strength > 0 and not reduced then
			local cycle = (t % cfg.ShimmerSeconds) / cfg.ShimmerSeconds
			look.shine = cycle * 1.6 - 0.3
			look.shineStrength = strength
		end
		if self.state == "wait" then
			look.markerGrow = 1 + 0.35 * (1 - smooth(t / 0.1)) -- the press registering on the marker
			if t >= WAIT_SECONDS then
				self:_leave(cfg.CancelExitSeconds)
			end
		end
	elseif self.state == "result" then
		local result = self.result
		local total = cfg.FeedbackSeconds + cfg.ResultHoldSeconds
		-- the marker settles on what was RECORDED (already scored); PERFECT's snap to the middle is decoration
		local settle = smooth(t / SNAP_SECONDS)
		local goal = if result.name == "perfect" and cfg.PerfectStyle == "F1"
			then 0
			else result.position
		self.position = mix(self.from, goal, settle)
		look = resultLook(t, result, total)
		if t >= total then
			self:_leave(cfg.ExitSeconds)
		end
	else -- exit
		local u = t / self.exitSeconds
		if u >= 1 then
			self:_stop()
			return
		end
		local result = self.result
		local colour = if result then RESULT[result.name].colour else WHITE
		look = exitLook(u, colour, if result then RESULT[result.name].glow * 0.8 else 0.25)
	end
	if reduced then
		-- reduced motion: no slide, squash or flash; opacity and colour still say everything
		look.slide, look.wide, look.tall, look.flash, look.shock, look.shine = 0, 1, 1, 0, nil, nil
		look.labelScale, look.markerGrow = 1, 1
	end
	self:_apply(look)
end

function KickMeterBar._start(self: Bar)
	self.root.Visible = true
	self:_fit()
	if not self.connection then
		self.connection = RunService.RenderStepped:Connect(function()
			self:_frame()
		end)
	end
end

--- Timing is on: called every frame while the jumper is attached, with the seconds since touching and this
--- kick's marker plan. Opens the bar if it isn't open (whatever an older bar was doing).
function KickMeterBar.Update(self: Bar, since: number, plan: KickMeter.Plan, hint: string)
	if self.state ~= "enter" and self.state ~= "live" then
		self.state = "enter"
		self.since = os.clock() - math.max(since, 0)
		self.result = nil
		self.lastPaint = ""
		self.label.Text = hint
		self.label.TextColor3 = WHITE
		self:_start()
	end
	if hint ~= self.hint then
		self.hint = hint
		self.label.Text = hint
	end
	self.position = KickMeter.position(cfg, plan, since)
end

--- Whether a press counts yet (the bar has settled and the marker is running).
function KickMeterBar.IsLive(self: Bar): boolean
	return self.state == "live"
end

--- The press (or the meter running out): the marker stops where it is, at once, and the bar waits for the
--- server's score.
function KickMeterBar.Freeze(self: Bar)
	if self.state == "enter" or self.state == "live" then
		self.state = "wait"
		self.since = os.clock()
	end
end

--- The server's score: where it recorded the marker (-1 to 1), and the named result ("perfect", "good",
--- "okay", "poor", or "late" for a meter that ran out). Plays the feedback, holds, then leaves.
function KickMeterBar.Result(self: Bar, position: number, name: string)
	if self.state == "hidden" or self.state == "result" or not RESULT[name] then
		return
	end
	self.state = "result"
	self.since = os.clock()
	self.from = self.position
	self.result = { position = math.clamp(position, -1, 1), name = name }
	self.label.Text = RESULT[name].text
	self.label.TextColor3 = RESULT[name].colour
	self:_start()
end

--- The timing was called off (stunned, the target gone, the kick ended): a quick exit with no result. A bar
--- already showing its result, or waiting on the server, is left to finish.
function KickMeterBar.Cancel(self: Bar)
	if self.state == "enter" or self.state == "live" then
		self:_leave(cfg.CancelExitSeconds)
	end
end

--- Whether the timing cue is up (so the HUD steps back): from opening until the press.
function KickMeterBar.IsActive(self: Bar): boolean
	return self.state == "enter" or self.state == "live"
end

--- For tests: the state name and the drawn marker position.
function KickMeterBar.Peek(self: Bar): (string, number)
	return self.state, self.position
end

return KickMeterBar
