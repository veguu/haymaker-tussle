--!strict
-- HudTheme - every colour, size and timing the combat HUD uses, in one place to tune. Fonts are not
-- here: the family and the text roles (weight and size per kind of text) are in Shared/Typography,
-- for the whole game. Sizes are pixels at a 1280 x 720 window; HudController scales the HUD by
-- `Scale`. Times are seconds.

local RunService = game:GetService("RunService")

local HudTheme = {}

HudTheme.Colour = {
	Panel = Color3.fromRGB(16, 23, 33),
	PanelRaised = Color3.fromRGB(34, 45, 60),
	Track = Color3.fromRGB(44, 56, 72),
	Accent = Color3.fromRGB(255, 196, 61), -- the arena ring yellow
	AccentHot = Color3.fromRGB(255, 132, 64), -- stagger high: you'll fly
	Text = Color3.fromRGB(242, 239, 230),
	Muted = Color3.fromRGB(150, 162, 178),
	Dim = Color3.fromRGB(96, 108, 124),
	Over = Color3.fromRGB(130, 210, 255), -- speed past normal running
	Miss = Color3.fromRGB(160, 170, 185),
	Blocked = Color3.fromRGB(255, 96, 84),
	OnAccent = Color3.fromRGB(16, 23, 33), -- dark lettering on the yellow
}

HudTheme.Transparency = {
	Panel = 0.15, -- the compact dark backing behind light HUD text
	Stepped = 0.55, -- groups that step back while a timed prompt or clash has priority
	-- The controls list has no panel (user, 2026-11-09): light text with a thin dark outline, and key
	-- caps as faint see-through tags.
	CapTag = 0.45,
	Outline = 0.3,
}

-- Whole-HUD scale: window size against 1280 x 720, kept within these so text stays readable.
-- `Bottom` shrinks the two bottom groups (your stagger and speed, and the controls) against the rest
-- (user, 2026-11-09: smaller). At the 1280 x 720 reference that takes 15-unit text to about 12 px.
HudTheme.Scale = { Reference = Vector2.new(1280, 720), Min = 1, Max = 1.35, Bottom = 0.82 }

HudTheme.Size = {
	Edge = 16, -- inset from the screen's edges (inside the safe area)
	Notch = 10, -- the angled corner cut
	AccentBar = 3,
	-- Top strip: round state and survivors.
	StripWidth = 260,
	StripHeight = 52,
	StripTop = 6,
	ShrinkWidth = 160,
	ShrinkHeight = 24,
	-- Bottom centre: your stagger (the big one) and speed under it.
	VitalsWidth = 360,
	VitalsHeight = 72,
	StaggerBarWidth = 246,
	StaggerBar = 10,
	GaugeBase = 62, -- width of the gauge up to normal running speed
	GaugeOver = 30, -- width of the part past it (up to GaugeOverSpeed)
	GaugeOverSpeed = 120, -- studs/s at the end of the gauge: past a propel, most launches
	GaugeHeight = 4,
	-- Bottom right: the three combat actions, one row each, in fixed columns with 8 px or more between
	-- them. Mirrored in design/ui/hud_layout.json for the roblox-ui checker (verify_ui.py).
	ActionsWidth = 268,
	ActionRow = 34,
	ActionPad = 8,
	ActionIconX = 12, -- icon column
	ActionNameX = 46, -- name column
	ActionNameWidth = 78,
	ActionKeyX = 132, -- key cap column
	ActionKeyWidth = 58,
	ActionStatusWidth = 58, -- reserved for "15.0s", so nothing moves as the digits change
	ActionLine = 2, -- the cooldown progress line under a row
	-- The help chip above the actions, and the full guide it opens.
	HelpHeight = 26,
	HelpWidth = 150,
	GuideWidth = 320,
	GuideRow = 28,
	-- Ring-out feed.
	FeedWidth = 250,
	FeedHeight = 34,
	-- Target chip, above their head.
	ChipWidth = 120,
	ChipHeight = 32,
	ChipMaxDistance = 70,
	TargetRange = 22, -- with no lock-on: nearest opponent ahead within this many studs
}

HudTheme.Time = {
	Enter = 0.18, -- groups fading in
	EnterTravel = 8, -- pixels they rise while they do
	Exit = 0.12,
	PressDown = 0.04,
	PressUp = 0.06,
	PressScale = 0.96,
	StaggerCatchUp = 0.15,
	StaggerAccent = 0.22,
	StaggerAccentGain = 8, -- a gain this big gets the one short accent
	ReadyFlash = 0.18,
	ResultWord = 0.4, -- HIT / MISS beside Punch
	Emphasis = 0.3, -- final two, arena closing
	EmphasisScale = 1.12,
	Feed = 2, -- how long a ring-out line stays
	GaugeRate = 14, -- how quickly the momentum gauge follows, per second
	DigitHysteresis = 0.8,
	DigitHz = 10, -- most redraws per second of the speed digits
	Steps = 0.15, -- stepping back for a prompt
}

-- The icons: drawn by Project/design/ui/draw_icons.py (PNGs in Project/assets/icons) and uploaded
-- through Studio as Images on 2026-11-08 (punch and propel redrawn for hud-9). Redraw and re-upload to change them.
HudTheme.Icons = {
	punch = "rbxassetid://93989680466321",
	propel = "rbxassetid://108732937698089",
	kick = "rbxassetid://113416372768113",
	uppercut = "rbxassetid://93989680466321", -- the punch's fist, until it has its own drawing
	mouse = "rbxassetid://118394725313773",
}

-- The combat actions, in the order they're listed, with their bindings per device and the
-- touch button each mirrors. "M1" draws a mouse.
HudTheme.Actions = {
	{
		id = "punch",
		name = "Punch",
		keys = { mouse = "M1", gamepad = "R2" },
		touchAction = "HaymakerPunch",
	},
	{
		id = "uppercut",
		name = "Uppercut",
		keys = { mouse = "R", gamepad = "L2" },
		touchAction = "HaymakerUppercut",
	},
	{
		id = "propel",
		name = "Dash",
		keys = { mouse = "Q", gamepad = "B" },
		touchAction = "HaymakerPropel",
	},
	{
		id = "kick",
		name = "Jump",
		keys = { mouse = "SPACE", gamepad = "Y" },
		touchAction = "HaymakerKick",
	},
}

-- The full guide behind the help chip. Lock-on is E in Studio, because Alt there opens Studio's
-- menu bar.
local lockKey = if RunService:IsStudio() then "E" else "Alt"
HudTheme.Guide = {
	mouse = {
		{
			key = "Click",
			action = "Punch: left and right hooks. Hold to draw it back, let go to throw it fast.",
		},
		{
			key = "R",
			action = "Uppercut: roots you, then throws them up and away. Further the faster you ran in.",
		},
		{
			key = "Q",
			action = "Dash: a short burst the way you're going. Hard to steer. 3 s to recharge.",
		},
		{
			key = "Space",
			action = "Jump: further and higher the faster you run. Click in the air to dive kick where you point.",
		},
		{
			key = "Click + Space",
			action = "Holding punch, Space kicks them up. Space again to jump at them, then click on the ring.",
		},
		{ key = "Ctrl", action = "Shift lock. The camera aims your kick." },
		{ key = lockKey, action = "Lock on to the nearest opponent." },
		{ key = "H", action = "Show or hide this guide." },
	},
	gamepad = {
		{
			key = "R2",
			action = "Punch: left and right hooks. Hold to draw it back, let go to throw.",
		},
		{
			key = "L2",
			action = "Uppercut: roots you, then throws them up and away. Further the faster you ran in.",
		},
		{ key = "B", action = "Dash: a short burst the way you're going. Hard to steer." },
		{
			key = "Y",
			action = "Jump: further and higher the faster you run. R2 in the air to dive kick.",
		},
		{
			key = "R2 + Y",
			action = "Holding punch, Y kicks them up. Y again to jump at them, then R2 on the ring.",
		},
		{ key = "L1", action = "Lock on to the nearest opponent." },
		{ key = "Select", action = "Show or hide this guide." },
	},
	touch = {
		{
			key = "Punch",
			action = "Punch: left and right hooks. Hold to draw it back, let go to throw it fast.",
		},
		{ key = "Propel", action = "Dash: a short burst the way you're going. 3 s to recharge." },
		{ key = "Upper", action = "Uppercut: roots you, then throws them up and away." },
		{
			key = "Kick",
			action = "Jump. Tap again in the air to dive kick. Holding Punch, it kicks them up.",
		},
		{ key = "Lock", action = "Lock on to the nearest opponent." },
	},
}

-- The AFK button, top left: sit out the next rounds. 52 tall, the touch-target minimum.
HudTheme.Afk = {
	Width = 132,
	Height = 52,
	Top = 8, -- below the safe area's top edge
	Corner = 6,
	PressScale = 0.96,
	PressSeconds = 0.05,
	ReleaseSeconds = 0.16,
}

-- The Spectate button sits under the AFK button and opens a small panel beside it.
HudTheme.Spectate = {
	Width = 132,
	Height = 52,
	Gap = 8, -- between tap targets
	PanelWidth = 280,
	Row = 52,
	Pad = 8,
	Corner = 6,
	Arrow = 52,
	PressScale = 0.96,
	PressSeconds = 0.05,
	ReleaseSeconds = 0.16,
}

return HudTheme
