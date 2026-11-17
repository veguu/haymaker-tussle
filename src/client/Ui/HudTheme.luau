--!strict
-- HudTheme - every colour, size and timing the combat HUD uses, in one place to tune. Fonts are not
-- here: the family and the text roles (weight and size per kind of text) are in Shared/Typography,
-- for the whole game. Sizes are pixels at a 1280 x 720 window; HudController scales the HUD by
-- `Scale`. Times are seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
-- With a mouse or a gamepad the HUD may shrink to `MinDesktop` in a small window, so it keeps the share of the
-- screen it has at 1280 x 720 (owner, 2026-11-17: everything took too much of a small window). On touch it
-- never goes under `Min`: a phone's screen is small in pixels but is held close.
HudTheme.Scale =
	{ Reference = Vector2.new(1280, 720), Min = 1, MinDesktop = 0.6, Max = 1.35, Bottom = 0.82 }

--- The HUD's scale in a viewport of this size, for the device in hand.
function HudTheme.scaleFor(view: Vector2): number
	local rule = HudTheme.Scale
	local touch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
	return math.clamp(
		math.min(view.X / rule.Reference.X, view.Y / rule.Reference.Y),
		if touch then rule.Min else rule.MinDesktop,
		rule.Max
	)
end

HudTheme.Size = {
	Edge = 16, -- inset from the screen's edges (inside the safe area); the corner buttons use it
	-- The target marker, above their head.
	ChipMaxDistance = 70,
	TargetRange = 22, -- with no lock-on: nearest opponent ahead within this many studs
}

HudTheme.Time = {
	ResultWord = 0.4, -- HIT / MISS above Punch
	Emphasis = 0.3, -- final two, arena closing
	EmphasisScale = 1.12,
	Feed = 2, -- how long a ring-out line stays
	FeedIn = 0.45, -- a line coming in from the right, on the spring
	FeedOut = 0.2, -- and leaving to the right
}

-- THE FIGHT-POSTER HUD (2026-11-16; the approved mockup is the vault's UI Research/fight-poster-prototype.html).
-- The owner: "I want it to look EXACTLY like it". Places and sizes are in HudController's `L`, in the mockup's own
-- pixels; the colours (token names), steps and timings are here, copied from the mockup's CSS. Motion runs on the
-- mockup's own curves (Core/PosterEase), not on TweenService's.

-- Your stagger: a slanted ink plate with your class colour on its left edge, a big slanted number, the
-- knockback it means, one word, and a 12-segment bar. It is NOT health: no health or damage wording.
-- The number and the bar go white, then yellow, then pink at the same shares of the maximum. The mockup's
-- meter ran 0 to 150 with steps at 50 and 100; those are the same thirds of this game's maximum.
HudTheme.Stagger = {
	Plate = "ink.900",
	Segments = 12,
	YellowShare = 1 / 3,
	PinkShare = 2 / 3,
	Tone = { white = "ivory.50", yellow = "gold.400", pink = "danger.600" },
	SegmentOff = "poster.unlit",
	Label = "ivory.50",
	Text = "ivory.50",
	RisingFor = 0.8, -- seconds the word says RISING after a gain
	-- a gain (the mockup's `bump` and `shk`): the number comes in at BumpScale, turned BumpTurn degrees, and
	-- settles on the spring; the plate shakes. Neither plays under Reduced Motion.
	BumpScale = 1.8,
	BumpTurn = -10,
	BumpSeconds = 0.6,
	ShakeSeconds = 0.32,
	SegmentSeconds = 0.3, -- a segment growing or shrinking, on the pop curve
}

-- The speed dial (HudController, group Y): a half dial of ticks. Its top speed and where "above a run" starts
-- come from GameConfig.Movement (PropelChargedSpeed, MaxSpeed); the colours are Stagger.Tone's.
HudTheme.Speed = {
	Ticks = 30,
	From = 197, -- degrees: where the first tick stands, counted anticlockwise from the right
	Sweep = 214, -- degrees the ticks cover, over the top
	Redline = 100, -- studs a second: pink from here
	Every = 0.05, -- seconds between readings of your speed
	EveryLite = 0.1, -- the same on phones
	Smooth = 0.5, -- how far the shown speed moves toward the real one at each reading
	PeakFall = 28, -- studs a second, each second: how fast the top-speed mark falls back
	StripBump = 1.6, -- a hit: the stagger strip comes in this much bigger and settles on the spring
}

-- The skill tiles: a rough-cut tile with an ink outline and a hard shadow. Three states, each a different
-- SHAPE and WORD as well as a colour:
--   ready     the tile in your class colour (Jump and Punch in light violet), a READY flag with a tick;
--   cooling   dark, a fill rising from the bottom, the seconds left;
--   can't use dark with stripes, a slash across it and a flag that says why.
HudTheme.Tile = {
	Line = "ink.900",
	LineHeld = "ivory.50", -- the attack skill while its key is held (not in the mockup)
	Dark = "poster.dark",
	Stripe = "poster.stripe",
	Quiet = "violet.400", -- Jump and Punch when ready
	OnBright = "ink.900", -- lettering on a class colour or light violet
	OnDark = "ivory.50",
	OnBlocked = "ivory.50", -- the can't-use flag's lettering, as the mockup has it
	Ready = "teal.400",
	Blocked = "danger.600",
	FillShade = 0.45, -- the rising fill is the class colour mixed this far to black
	Shadow = { tone = "ink.900", transparency = 0.15, x = 5, y = 6 },
	-- coming off cooldown (`spop`): in at PopScale, turned PopTurn degrees, settling on the spring
	PopScale = 1.6,
	PopTurn = 10,
	PopSeconds = 0.7,
	-- used (`sq`): the mockup squashes to 1.25 x 0.6; an even shrink of the same area stands in for it
	UsedScale = 0.87,
	UsedSeconds = 0.5,
	-- refused (`nope`)
	Nudge = 6,
	NudgeSeconds = 0.18,
	WordReady = "READY",
	WordStunned = "STUNNED",
	WordBlocked = "CAN'T USE",
}

-- The strip at the top centre: a slanted ink plate with your class colour under it, the count in yellow.
HudTheme.Strip = {
	Plate = "ink.900",
	Count = "gold.400",
	Word = "ivory.50",
	Last = "gold.400", -- the edge, for the final two and the last one
	Warning = "danger.600", -- the ARENA CLOSING chip
	OnWarning = "ink.950",
	-- the count changing in a fight (`sb`)
	BumpScale = 2.4,
	BumpTurn = -10,
	BumpSeconds = 0.55,
}

-- The HUD's four action icons, by action id, from the one icon list (Ui/Icons; all placeholders there).
HudTheme.Icons = {
	punch = Icons.id("classes"), -- the glove
	propel = Icons.id("dash"), -- Q, the class's move
	kick = Icons.id("jump"),
	uppercut = Icons.id("punch"), -- R, the class's attack
}

-- The combat actions, with their bindings per device and the touch button each mirrors.
HudTheme.Actions = {
	{
		id = "punch",
		name = "Punch",
		keys = { mouse = "Click", gamepad = "R2" },
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
		keys = { mouse = "Space", gamepad = "Y" },
		touchAction = "HaymakerKick",
	},
}

-- The controls the window's Moves page lists. Lock-on is E in Studio, because Alt there opens Studio's
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
		{ key = lockKey, action = "Lock on: the nearest opponent." },
		{ key = "H", action = "This guide." },
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
		{ key = "L1", action = "Lock on: the nearest opponent." },
		{ key = "Select", action = "This guide." },
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
		{ key = "Lock", action = "Lock on: the nearest opponent." },
	},
}

-- The spectate panel (bottom centre; opened from the window's More page). The old button beside it is hidden.
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
	-- the fight-poster panel (2026-11-18): its buttons' height, the who-plate's lean, and the HUD's SPECTATING chip
	Tab = 40,
	Lean = 6,
	Chip = Vector2.new(170, 32),
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
