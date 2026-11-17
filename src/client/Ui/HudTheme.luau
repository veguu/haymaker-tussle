--!strict
-- HudTheme - every colour, size and timing the combat HUD uses, in one place to tune. Fonts are not
-- here: the family and the text roles (weight and size per kind of text) are in Shared/Typography,
-- for the whole game. Sizes are pixels at a 1280 x 720 window; HudController scales the HUD by
-- `Scale`. Times are seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Icons = require(script.Parent.Icons)

local HudTheme = {}

-- Pointed at Shared/Tokens (Voltline since 2026-11-16: the token names are jobs, see the note there). One
-- colour, one job: coral = YOU (pink), teal = ready/recovering (cyan), gold = earned (yellow), ink/ivory/
-- stone = neutral (blue surfaces, white text). The names stay so every screen picks the palette up with no code change; screens move to
-- Tokens directly as they are rebuilt (Phase 1+), then this table goes.
local T = Tokens.colour
HudTheme.Colour = {
	Panel = T("ink.900"),
	PanelRaised = T("ink.800"),
	Track = T("ink.600"),
	Accent = T("coral.500"), -- you: your stagger, your selection, on/active
	AccentHot = T("danger.600"), -- critical stagger (the palette's fill colour; the text use goes in Phase 1b)
	Text = T("ivory.50"),
	Muted = T("stone.300"),
	Dim = T("stone.500"), -- disabled, non-essential only
	Over = T("teal.400"), -- speed past normal running (no own job in the palette yet; Phase 1 decides)
	Miss = T("stone.300"),
	Blocked = T("danger.600"),
	OnAccent = T("ink.900"), -- dark lettering on coral
}

HudTheme.Transparency = {
	Panel = Tokens.surface[1].transparency, -- 0.12, the HUD maximum: more and coral loses contrast on paving
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

-- The HUD's four action icons, by action id, from the one icon list (Ui/Icons; all placeholders there).
HudTheme.Icons = {
	punch = Icons.id("classes"), -- the glove
	propel = Icons.id("dash"), -- Q, the class's move
	kick = Icons.id("jump"),
	uppercut = Icons.id("punch"), -- R, the class's attack
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
			action = "Punch: a 4-hit string. The first three stun and drag them, the fourth knocks them away.",
		},
		{
			key = "R",
			action = "Your class's attack. Hold it for up to 3 seconds, let go to throw it.",
		},
		{
			key = "Q",
			action = "Your class's move. Can't be used while stunned.",
		},
		{
			key = "Space",
			action = "Jump. Click in the air to glide a punch at where you point.",
		},
		{ key = "Ctrl", action = "Shift lock." },
		{ key = lockKey, action = "Lock on to the nearest opponent." },
		{ key = "H", action = "Show or hide this guide." },
	},
	gamepad = {
		{
			key = "R2",
			action = "Punch: a 4-hit string. The first three stun and drag them, the fourth knocks them away.",
		},
		{
			key = "L2",
			action = "Your class's attack. Hold it for up to 3 seconds, let go to throw it.",
		},
		{ key = "B", action = "Your class's move. Can't be used while stunned." },
		{
			key = "Y",
			action = "Jump. R2 in the air to glide a punch.",
		},
		{ key = "L1", action = "Lock on to the nearest opponent." },
		{ key = "Select", action = "Show or hide this guide." },
	},
	touch = {
		{
			key = "Punch",
			action = "Punch: a 4-hit string. The fourth knocks them away.",
		},
		{ key = "Propel", action = "Your class's move." },
		{ key = "Upper", action = "Your class's attack. Hold, then let go to throw it." },
		{
			key = "Kick",
			action = "Jump. Punch in the air to glide a punch at them.",
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

-- The owner's Bots button (Studio or the place's owner only) sits under the Spectate button.
HudTheme.BotsFreeze = {
	Width = 132,
	Height = 52,
	Gap = 8,
	Corner = 6,
}

-- The menu (M, or the Menu button at the left edge): ability inventory, shop, passes, settings.
-- The panel takes most of a phone screen and stops growing at MaxWidth x MaxHeight.
HudTheme.Menu = {
	ButtonWidth = 132,
	ButtonHeight = 52,
	Corner = 8,
	MaxWidth = 1040,
	MaxHeight = 600,
	ScreenShare = Vector2.new(0.92, 0.86), -- of the screen, before MaxWidth/MaxHeight
	Header = 56,
	Rail = 150, -- the tab column
	Tab = 44, -- tab and button height: the touch-target minimum
	Gap = 8,
	Pad = 14,
	CardButton = 136,
	Detail = Vector2.new(230, 320), -- the selected class's panel: least and most width (32 % of the sheet)
	Cell = Vector2.new(140, 156), -- a class card: least width, height
	Coin = T("gold.400"), -- earned
	Good = T("teal.400"), -- confirmed
	Backdrop = 0.45,
	Open = 0.16,
	Toast = 2.4, -- seconds a notice stays
}

return HudTheme
