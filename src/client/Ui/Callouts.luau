--!strict
-- Callouts - the fight-poster look's big announcements (the mockup UI Research/fight-poster-prototype.html):
--
--   count, go    the round-start countdown: 3, 2, 1, then TUSSLE! (the mockup's `.cd`)
--   ultimate     ULTIMATE in letter cards, then READY and the key on a yellow tag (`.ucall` / gotUlt)
--   last         at 5, 4, 3 and 2 standing: the number on a rough-cut tile, LEFT (or FINAL) in cards
--                (`.lcall` / lastCall)
--   className    your class's name in cards as you use your ultimate (`.cband2` / fire)
--
-- One style for all of them since ui-16a / ui-17a: things come fast and HIT, the hit shakes them and throws
-- SPEED PILLS (ui-24a: round-capped speed lines pulled away into their tips, small pops at the tips; they replaced
-- the straight bars and tumbling shards, which "look cheap"). No bars, streaks, stamps or confetti.
-- COLOURS (ui-24a): the word pop-ups are in YOUR colour's palette (`Callouts.setColour`; a tint, the colour, a
-- deep shade, cream and ink: Core/ColourMath); the countdown is ONE colour the caller picks for the round.
--
-- Neither covers the screen, nothing flashes, and nothing here runs unless one is on screen: each is built when
-- it starts and destroyed when it ends. Under Reduced Motion they appear and leave without the motion.
-- The owner's five voice lines play from Config/VoiceLines once their ids are filled in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ColourMath = require(ReplicatedStorage.Shared.Core.ColourMath)
local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local VoiceLines = require(ReplicatedStorage.Shared.Config.VoiceLines)
local HudMotion = require(script.Parent.HudMotion)
local HudTheme = require(script.Parent.HudTheme)
local Poster = require(script.Parent.Poster)
local Shapes = require(script.Parent.Shapes)
local UiSound = require(script.Parent.UiSound)

local Callouts = {}

local colour = Tokens.colour
local spring, ease, keyframes = PosterEase.spring, PosterEase.ease, PosterEase.keyframes

local gui: ScreenGui? = nil
local edgeGui: ScreenGui? = nil
local serial = 0

-- A colour's palette as Color3s (Core/ColourMath): the tint, the colour itself, the deep shade.
type Tones = { tone: Color3, light: Color3, deep: Color3 }

local function rgb(c: Color3): ColourMath.RGB
	return { r = c.R, g = c.G, b = c.B }
end

local function tonesOf(c: Color3): Tones
	local p = ColourMath.palette(rgb(c))
	return {
		tone = c,
		light = Color3.new(p.light.r, p.light.g, p.light.b),
		deep = Color3.new(p.deep.r, p.deep.g, p.deep.b),
	}
end

-- ink or cream letters, whichever reads better on `face`
local function letterOn(face: Color3): Color3
	return if ColourMath.inkReads(rgb(face)) then colour("ink.900") else colour("ivory.50")
end

local yours: Color3? = nil

--- Your colour, for the pop-ups that are about you (the last players count): your class colour, or the one you
--- picked in More > Cosmetics. The callers that already pass a colour pass this same one.
function Callouts.setColour(tone: Color3)
	yours = tone
end

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

-- A letter card's look in the current style (ui-23a, 2026-11-20): rounded corners on its shadow, edge and face,
-- and the in-game comic shading on the face (a still halftone toward its foot, as Ui/Texture.comic). Until then a
-- card was a plain square block of flat colour.
local function comicCard(shadow: Frame, edge: Frame, face: Frame, radius: number)
	for _, piece in { shadow, edge, face } do
		make("UICorner", piece, { CornerRadius = UDim.new(0, radius) })
	end
	local halftone = make("ImageLabel", face, {
		Name = "Halftone",
		BackgroundTransparency = 1,
		Image = Shapes.ids.dots,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(10, 10),
		ImageColor3 = colour("ink.900"),
		ImageTransparency = 0.78,
		Size = UDim2.fromScale(1, 1),
	})
	make("UICorner", halftone, { CornerRadius = UDim.new(0, math.max(0, radius - 3)) })
	make("UIGradient", halftone, {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})
end

-- how far down the screen (pixels) something stands that the pop-ups must start under, or nil
local clearTop: number? = nil

--- Tells the pop-ups what they must stand under: the bottom edge, in screen pixels, of the fighters' row while it
--- is on screen; nil when only the top strip is there.
function Callouts.under(pixels: number?)
	clearTop = pixels
end

-- the pop-up on screen now (a stage's holder) and how far down the screen it reaches
local liveHolder: Frame? = nil
local liveBottom = 0

--- How far down the screen (pixels) the top of the screen is taken: by the fighters' row while it is up, and by
--- a pop-up while one is on screen. nil when neither is there. (The menu's toast stands under this.)
function Callouts.taken(): number?
	local low = clearTop
	if liveHolder and liveHolder.Parent then
		low = math.max(low or 0, liveBottom)
	end
	return low
end

--- Builds the two layers the announcements draw in. Safe to call more than once.
function Callouts.start()
	if gui then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = make("ScreenGui", playerGui, {
		Name = "HT_Callouts",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	-- the countdown's sheet is fetched now: unfetched, the first number of the first round drew 0.1 s late
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({ Shapes.ids.count })
		end)
	end)
	-- (PreloadAsync alone was not enough: the first number still reported itself unloaded for 0.19 s. One dot of
	-- the sheet kept on the screen, all but clear, holds the image in memory.)
	make("ImageLabel", gui, {
		Name = "Warm",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(1, 1),
		Image = Shapes.ids.count,
		ImageRectSize = Vector2.new(1, 1),
		ImageTransparency = 0.99,
	})
	-- the edge bars lie on the screen's real top and bottom edges
	edgeGui = make("ScreenGui", playerGui, {
		Name = "HT_CalloutEdges",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
	})
end

-- The HUD's own scale rule, so the announcements grow with it on big screens.
local function hudScale(): number
	local camera = workspace.CurrentCamera
	local ref = HudTheme.Scale.Reference
	local view = if camera then camera.ViewportSize else ref
	return HudTheme.scaleFor(view)
end

--- Speaks a line, if it has been uploaded.
function Callouts.speak(key: string)
	local line = VoiceLines.Lines[key]
	if not line or line.id == "" then
		return
	end
	local sound = make("Sound", SoundService, {
		Name = "HT_Voice",
		SoundId = line.id,
		Volume = VoiceLines.Volume,
	})
	sound:Play()
	task.delay(line.seconds + 1, function()
		sound:Destroy()
	end)
end

--- The thin bars along the top and bottom edges: they sweep in and fade, once (the mockup's `ue`, 1.1 s).
function Callouts.edges(tone: Color3)
	Callouts.start()
	local layer = edgeGui :: ScreenGui
	if HudMotion.reduced() then
		return
	end
	for _, old in layer:GetChildren() do
		old:Destroy()
	end
	local top = make("Frame", layer, {
		Name = "Top",
		BackgroundColor3 = tone,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 12),
	})
	local bottom = make("Frame", layer, {
		Name = "Bottom",
		BackgroundColor3 = tone,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0, 0, 0, 12),
	})
	local WIDTH = { { 0, 0 }, { 0.3, 1 }, { 1, 1 } }
	local SEEN = { { 0, 1 }, { 0.3, 1 }, { 1, 0 } }
	Poster.run(layer, 1.1, function(t: number)
		local width = keyframes(WIDTH, t, ease)
		local clear = 1 - keyframes(SEEN, t, ease)
		top.Size = UDim2.new(width, 0, 0, 12)
		bottom.Size = UDim2.new(width, 0, 0, 12)
		top.BackgroundTransparency = clear
		bottom.BackgroundTransparency = clear
	end, function()
		top:Destroy()
		bottom:Destroy()
	end)
end

local ARRIVE = 0.45 -- seconds to come in from the left edge
-- it runs a long way, so it only just passes its place before settling (the spring overshot by 100 px)
local arriveCurve = PosterEase.bezier(0.22, 1.12, 0.36, 1)
local DRIFT = 150 -- how far it travels, slowly, while it is being read
local function glide(elapsed: number, life: number, away: number, span: number): number
	local arrived = arriveCurve(math.clamp(elapsed / ARRIVE, 0, 1))
	-- it never stands still: it rushes in, slows to a steady drift to the right through the middle of the
	-- screen, then picks up speed and is gone off to the right as it fades
	local drift = DRIFT * (life - 0.45)
	return -(span / 2 + 200) * (1 - arrived) + drift + span * 0.3 * away * away
end

-- The stage every announcement stands on: a holder at the top centre scaled with the HUD, and inside it a
-- plain group that turns and scales about the announcement's centre. `box` is the announcement's own box; its
-- top-left is at `origin` inside the group.
-- WHERE AND HOW BIG (owner, 2026-11-17): an announcement must be seen without covering the fight. The mockup
-- puts it across the middle of the screen at full size; here it is SMALL (`extra`, a share of the mockup's size)
-- and stands right under the top strip, so the middle of the screen, where people are fighting, stays clear.
-- HOW IT COMES AND GOES (owner, 2026-11-17: "appears from the left, slowly goes right, then fades right; use
-- your own ideas"): in fast from the LEFT edge, a slow steady drift to the right while it is read, then away to
-- the RIGHT, speeding up as it fades (`glide`). `span` is the screen's width in the stage's own units, so
-- it starts wholly off the screen. (A bar across the whole screen was tried the same day and taken out again.)
local function stage(
	name: string,
	box: Vector2,
	extra: number
): (Frame, Frame, UIScale, Vector2, number)
	Callouts.start()
	local hud = hudScale()
	local scale = hud * extra
	local camera = workspace.CurrentCamera
	local wide = if camera then camera.ViewportSize.X else 1280
	local span = wide / scale + 400
	local holder = make("Frame", gui, {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- the strip is 18 from the top and 72 tall at the HUD's scale; the fighters' row, when it is up, is
		-- taller than the strip (`Callouts.under`): with few left standing ULTIMATE and a class's name stood
		-- on its tiles (seen 2026-11-18)
		Position = UDim2.new(
			0.5,
			0,
			0,
			math.max((18 + 72) * hud + 20, (clearTop or 0) + 16) + box.Y / 2 * scale
		),
		Size = UDim2.fromOffset(box.X, box.Y),
	})
	make("UIScale", holder, { Scale = scale })
	liveHolder = holder
	liveBottom = holder.Position.Y.Offset + box.Y / 2 * scale + 8
	local room = Vector2.new(math.max(box.X + 1000, span), box.Y + 440)
	local group = make("Frame", holder, {
		Name = "Group",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- it starts off the left edge (see `glide`); with no motion it is simply in its place
		Position = if HudMotion.reduced()
			then UDim2.fromScale(0.5, 0.5)
			else UDim2.new(0.5, -(span / 2 + 200), 0.5, 0),
		Size = UDim2.fromOffset(room.X, room.Y),
	})
	local groupScale = make("UIScale", group, {})
	return holder, group, groupScale, (room - box) / 2, span
end

-- Moves a stage's group into a CanvasGroup, so the whole announcement can fade as one. Only done for its last
-- moments, when nothing inside is moving any more: a CanvasGroup is drawn again every frame its contents change,
-- which cost about 3 ms a frame while the letters were still landing (measured 2026-11-16).
local function toCanvas(group: Frame): CanvasGroup
	local canvas = make("CanvasGroup", group.Parent, {
		Name = "Fade",
		BackgroundTransparency = 1,
		AnchorPoint = group.AnchorPoint,
		Position = group.Position,
		Size = group.Size,
		Rotation = group.Rotation,
	})
	for _, child in group:GetChildren() do
		child.Parent = canvas
	end
	group:Destroy()
	return canvas
end

-- THE ROUND'S START: 3, 2, 1, TUSSLE! -----------------------------------------------------------------
--
-- The owner, 2026-11-18: no GET READY strip; three seconds before the fight a countdown on the screen, seen and
-- approved on the mockup page first (`.cd`, cdBeat and cdGo). His words since, in order: "remove the lines" (NO
-- slanted bar behind the number or the word); no "little confetti effects" on the numbers; "less effects compared
-- to the tussle, but make each number unique"; then "MORE aggressive ... getting ready to fight, not getting
-- ready to attend a tea party", in the game's own style.
-- So nothing here floats or bounces about. A number COMES FAST AND HITS: 0.13 s in, speeding up, to a hard stop a
-- little under its size, a short spring back, a heavy shake of the whole thing and a burst of sharp ink-edged
-- impact lines from behind it. The word's cards hit one after another, and on the last one the whole word
-- punches, shakes, throws impact lines all round and sharp shards (not confetti). No white, no flash, nothing
-- across the screen but the thin edge bars.
-- Unlike the other two announcements it does not glide: nobody is fighting yet (everyone is held on their spawn),
-- so it stands in the middle near the top, bigger than they are. One beat at a time: a new beat takes the place
-- of the one before.

-- its centre, as a share of the screen's height (0.32 at first: the "!" card then touched the fighters' row,
-- which comes up as the word lands; seen 2026-11-18)
local COUNT_TALL = 0.38
local COUNT_SIZE = 0.8 -- of the mockup's size, at the HUD's scale
local COUNT_SIZE_SMALL = 0.6 -- on a phone
local TUSSLE = { "T", "U", "S", "S", "L", "E", "!" }

local HIT = 0.13 -- a number: seconds from first sight to the hit
local HIT_SIZE = 0.84 -- how far it is driven in by the hit, before it springs back to 1
local SETTLE = 0.34
local CARD_HIT, CARD_GAP, CARD_SETTLE, CARD_SIZE = 0.1, 0.035, 0.28, 0.88
-- TUSSLE! POPS OUT (the owner, 2026-11-18: "it should have more of a POPOUT animation, cuz its like 3, 2, 1,
-- FIGHT ... the one rn doesnt feel like its popping out it feels like the anims are slow"). Until then its seven
-- cards came DOWN one after another (0.31 s before the last had landed) and the word stood 1.3 s. Now the whole
-- word bursts out of its own middle AT ONCE: every card starts small at the centre, flies to its place and past
-- its size in GO_POP, and springs back; the shake, the lines and the shards go off at that same moment. The word
-- holds, dips and swells away: GO_LIFE in all.
local GO_POP = 0.09 -- seconds from nothing to the burst's full size
local GO_OVER = 1.26 -- a card overshoots to this before it springs back to 1
local GO_SETTLE = 0.26
local GO_LIFE = 0.95
local WORD_HIT = GO_POP -- when the word hits
local GO_SIZE = { { 0, 1 }, { 0.7, 1 }, { 0.8, 0.93 }, { 1, 1.8 } }
local GO_CLEAR = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } }
local popCurve = PosterEase.bezier(0.1, 0.9, 0.2, 1) -- out fast, easing as it arrives

-- a hard shake: one big kick, then less each way
local JOLT = { { 0, 0 }, { 0.15, -1 }, { 0.35, 0.8 }, { 0.55, -0.5 }, { 0.78, 0.25 }, { 1, 0 } }

local function fan(count: number, first: number, last: number): { number }
	local angles = table.create(count)
	for index = 1, count do
		angles[index] = first + (index - 1) * (last - first) / (count - 1)
	end
	return angles
end

local function ring(count: number, first: number): { number }
	local angles = table.create(count)
	for index = 1, count do
		angles[index] = first + (index - 1) * 360 / count
	end
	return angles
end

-- EACH NUMBER HAS ITS OWN MOVE (the mockup's CDM). It comes from (fromX, fromY) at `fromSize` times its size
-- turned `turn`; the shake goes the way it came (`shakeX`, `shakeY`); `lines` are the angles of its impact lines
-- (0 is right, 90 is DOWN), which start `near` from (0, lineY) and run out to `far`; it leaves to (outX, outY)
-- at `outSize`, turned `outTurn`.
--   3  slams in from big, straight at you: lines all round, knocked down
--   2  crashes down from above: lines kicked out low along the ground, flicked off to the right
--   1  punches in from the left: lines thrown forward to the right, swells upward into the word
local COUNT_MOVE = {
	[3] = {
		fromSize = 3.6,
		turn = -18,
		fromX = 0,
		fromY = 0,
		shakeX = 1,
		shakeY = 0.45,
		lines = ring(10, 18),
		lineY = 0,
		near = 110,
		far = 215,
		long = 120,
		outX = 0,
		outY = 46,
		outSize = 0.45,
		outTurn = 11,
	},
	[2] = {
		fromSize = 1.4,
		turn = 14,
		fromX = 0,
		fromY = -300,
		shakeX = 0,
		shakeY = 1,
		lines = { 0, -16, -34, 180, 196, 214 }, -- (in this order the two sides' colours mirror each other)
		lineY = 80,
		near = 80,
		far = 250,
		long = 130,
		outX = 130,
		outY = 0,
		outSize = 0.6,
		outTurn = 28,
	},
	[1] = {
		fromSize = 1.2,
		turn = -14,
		fromX = -420,
		fromY = 0,
		shakeX = 1,
		shakeY = 0,
		lines = { -42, -21, 0, 21, 42 },
		lineY = 0,
		near = 70,
		far = 260,
		long = 140,
		outX = 0,
		outY = -60,
		outSize = 1.6,
		outTurn = 0,
	},
}

local countHolder: Frame? = nil

-- THE COUNTDOWN'S COLOURS (ui-24a; the owner, 2026-11-20: "randomized everytime ... RANDOM COLORS, not random
-- SETS of colors, so it shouldnt be all purple, all blue"): the 3, the 2, the 1 and each TUSSLE! card its own
-- colour, no two neighbours alike, new every round, and the SAME on every player's screen, because
-- Core/ColourMath.sequence draws them from the round's CountdownEnd, which every client has. No message is sent.
local ROUND_TONES = {
	"gold.400",
	"danger.600",
	"teal.400",
	"go.400",
	"class.Inferno",
	"class.Dragon",
	"class.Tempest",
	"class.Trickster",
}

--- The countdown's colours for the round whose CountdownEnd is `finish`: ten, in order the 3, the 2, the 1 and the
--- seven TUSSLE! cards.
function Callouts.roundColours(finish: number): { Color3 }
	local picks = ColourMath.sequence(finish, 3 + #TUSSLE, #ROUND_TONES)
	local list = table.create(#picks)
	for index, pick in picks do
		list[index] = colour(ROUND_TONES[pick])
	end
	return list
end

--- Takes the countdown off the screen at once (the round was called off).
function Callouts.countStop()
	if countHolder then
		countHolder:Destroy()
		countHolder = nil
	end
end

-- The countdown's own stage: a point near the top centre at the HUD's scale, and a group in it that the shake
-- moves. Returns the holder, the group and a function that takes this beat away (only if it is still the one up).
local function countStage(name: string, small: boolean): (Frame, Frame, () -> ())
	Callouts.start()
	Callouts.countStop()
	local holder = make("Frame", gui, {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, COUNT_TALL),
		Size = UDim2.fromOffset(0, 0),
	})
	make(
		"UIScale",
		holder,
		{ Scale = hudScale() * (if small then COUNT_SIZE_SMALL else COUNT_SIZE) }
	)
	local group = make("Frame", holder, {
		Name = "Group",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
	})
	countHolder = holder
	return holder,
		group,
		function()
			holder:Destroy()
			if countHolder == holder then
				countHolder = nil
			end
		end
end

-- The hard shake of a whole beat: `x` and `y` are how far the first kick goes.
local function jolt(key: any, group: Frame, x: number, y: number, seconds: number, wait: number)
	Poster.run(key, seconds, function(t: number)
		local k = keyframes(JOLT, t, ease)
		group.Position = UDim2.fromOffset(x * k, y * k)
	end, nil, wait)
end

-- SPEED PILLS (ui-24a; the owner's pick "A" of four on work/burst-options.html, 2026-11-20, in place of the straight
-- bars and tumbling shards that "look cheap"): round-capped speed lines that shoot out from BEHIND a hit and are
-- pulled away into their tips, thick and thin, a few hundredths of a second apart; each thick one leaves a small
-- pop at its tip. They start on a rounded box round the hit (`halfX`, `halfY` out from (x, y)) along `angles`
-- (degrees; 0 is right, 90 is DOWN) and run `reach` further (longer to the sides than straight down), `thick`
-- wide. Thick ones are the colour (every third cream), thin ones and the pops the tint. `small` (a phone) throws
-- every other line and no pops. One frame connection for the whole burst; nothing is left behind.
local PILL_LIFE = 0.32 -- a line's own life
local PILL_STAGGER = 0.03 -- lines set off up to this much apart
local POP_AT, POP_LIFE = 0.17, 0.22 -- a pop shows this long after its line sets off, for this long

local function backOut(t: number): number
	local c1 = 2.4
	return 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function pills(
	parent: Instance,
	key: any,
	x: number,
	y: number,
	halfX: number,
	halfY: number,
	angles: { number },
	tones: Tones,
	reach: number,
	thick: number,
	wait: number,
	small: boolean
)
	if HudMotion.reduced() then
		return
	end
	local ink, paper = colour("ink.900"), colour("ivory.50")
	local lines = {}
	for index = 1, #angles, if small then 2 else 1 do
		local angle = angles[index] + (math.random() - 0.5) * 6
		local turn = math.rad(angle)
		local cos, sin = math.cos(turn), math.sin(turn)
		local thin = index % 2 == 0
		local wide = if thin then thick * 0.6 else thick
		-- the ink edge a fifth of the line's width (a fixed 4 left a thin line nearly all ink: seen in Studio)
		local edge = math.max(2, math.round(wide * 0.2))
		local line = make("Frame", parent, {
			Name = "Pill",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = angle,
			Size = UDim2.fromOffset(0, 0),
			Visible = false,
			ZIndex = 1,
		})
		make("UICorner", line, { CornerRadius = UDim.new(1, 0) })
		local face = make("Frame", line, {
			BackgroundColor3 = if thin
				then tones.light
				elseif (index - 1) / 2 % 3 == 2 then paper
				else tones.tone,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(edge, edge),
			Size = UDim2.new(1, -2 * edge, 1, -2 * edge),
		})
		make("UICorner", face, { CornerRadius = UDim.new(1, 0) })
		local pop: Frame? = nil
		if not thin and not small then
			pop = make("Frame", parent, {
				Name = "Pop",
				BackgroundColor3 = ink,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(0, 0),
				Visible = false,
				ZIndex = 1,
			})
			make("UICorner", pop, { CornerRadius = UDim.new(1, 0) })
			local dot = make("Frame", pop, {
				BackgroundColor3 = tones.light,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -2 * edge, 1, -2 * edge),
			})
			make("UICorner", dot, { CornerRadius = UDim.new(1, 0) })
		end
		table.insert(lines, {
			line = line,
			face = face,
			pop = pop,
			-- on a rounded box round the hit (a squarish ellipse), so they come out from behind its edge
			x = x + halfX * math.sign(cos) * math.abs(cos) ^ 0.5,
			y = y + halfY * math.sign(sin) * math.abs(sin) ^ 0.5,
			cos = cos,
			sin = sin,
			wide = wide,
			far = reach * (0.55 + 0.6 * math.abs(cos)) * (0.85 + 0.3 * math.random()),
			at = math.random() * PILL_STAGGER,
		})
	end
	local life = PILL_STAGGER + (if small then PILL_LIFE else POP_AT + POP_LIFE)
	Poster.run(key, life, function(t: number)
		local elapsed = t * life
		for _, l in lines do
			local u = (elapsed - l.at) / PILL_LIFE
			if u > 0 and u < 1 then
				-- the head races out and slows; the tail follows faster at the end, so the line is pulled away
				-- into its tip instead of shrinking where it stands
				local head = l.far * (1 - (1 - u) ^ 4)
				local tail = l.far * u ^ 1.7
				local length = head - tail + l.wide
				local middle = (head + tail) / 2
				local clear = if u > 0.9 then (u - 0.9) / 0.1 else 0
				l.line.Visible = true
				l.line.Position = UDim2.fromOffset(l.x + l.cos * middle, l.y + l.sin * middle)
				l.line.Size = UDim2.fromOffset(length, l.wide * (1 - 0.25 * u))
				l.line.BackgroundTransparency = clear
				l.face.BackgroundTransparency = clear
			else
				l.line.Visible = false
			end
			local pop = l.pop
			if pop then
				local p = (elapsed - l.at - POP_AT) / POP_LIFE
				if p > 0 and p < 1 then
					local out = l.far * 0.96 + l.wide * 1.3 * (1 - (1 - p) ^ 3)
					local size = l.wide
						* (
							if p < 0.35
								then backOut(p / 0.35) * 1.1
								else 1.1 * (1 - (p - 0.35) / 0.65)
						)
					pop.Visible = true
					pop.Position = UDim2.fromOffset(l.x + l.cos * out, l.y + l.sin * out)
					pop.Size = UDim2.fromOffset(size, size)
				else
					pop.Visible = false
				end
			end
		end
	end, function()
		for _, l in lines do
			l.line:Destroy()
			if l.pop then
				l.pop:Destroy()
			end
		end
	end, wait)
end

--- One number of the countdown (3, 2 or 1): it comes fast in its own way (COUNT_MOVE), hits hard, shakes and
--- throws its impact lines, and is knocked away just before the next one is due. `small` is the phone size.
function Callouts.count(beat: number, small: boolean, tone: Color3?)
	local sheet = Shapes.count
	local cell = sheet.numbers[beat]
	local move = COUNT_MOVE[beat]
	if not cell or not move then
		return
	end
	UiSound.play(`cd_{beat}`)
	local tones = tonesOf(tone or colour("gold.400"))
	serial += 1
	local id = `count{serial}`
	local _holder, group, away = countStage("Countdown", small)
	local number = make("ImageLabel", group, {
		Name = "Number",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(sheet.cell.X, sheet.cell.Y),
		Image = Shapes.ids.count,
		ImageRectOffset = Vector2.new(cell * sheet.cell.X, 0),
		ImageRectSize = sheet.cell,
		-- the sheet's faces are WHITE (ui-24a): the round's colour tints them; the ink stays near-black
		ImageColor3 = tones.tone,
		ZIndex = 2,
	})
	if HudMotion.reduced() then
		-- no motion: the number stands for most of its second and goes
		task.delay(0.9, away)
		return
	end
	number.Visible = false
	local scale = make("UIScale", number, {})
	-- in: fast and speeding up, to a hard stop driven a little under its size
	Poster.run(`{id}in`, HIT, function(t: number)
		local e = PosterEase.easeIn(t)
		number.Visible = true
		number.ImageTransparency = 1 - math.min(1, t * 3)
		scale.Scale = move.fromSize + (HIT_SIZE - move.fromSize) * e
		number.Position = UDim2.fromOffset(move.fromX * (1 - e), move.fromY * (1 - e))
		number.Rotation = move.turn * (1 - e)
	end)
	-- the hit: it springs back to its size, everything shakes, the lines fly
	Poster.run(`{id}settle`, SETTLE, function(t: number)
		scale.Scale = HIT_SIZE + (1 - HIT_SIZE) * spring(t)
	end, nil, HIT)
	jolt(`{id}shake`, group, 22 * move.shakeX, 22 * move.shakeY, 0.34, HIT)
	pills(
		group,
		`{id}lines`,
		0,
		move.lineY,
		move.near * 0.7,
		move.near * 0.9,
		move.lines,
		tones,
		move.far - move.near + move.long * 0.4,
		18,
		HIT,
		small
	)
	-- away: 0.2 s from 0.78 s
	Poster.run(`{id}out`, 0.2, function(t: number)
		local e = PosterEase.easeIn(t)
		number.ImageTransparency = e
		number.Position = UDim2.fromOffset(move.outX * e, move.outY * e)
		scale.Scale = 1 + (move.outSize - 1) * e
		number.Rotation = move.outTurn * e
	end, away, 0.78)
end

--- "TUSSLE!": the fight is on. Seven cut-out letters in boxes, each in its own colour from `colours` (ui-24a; the
--- "!" tipped) BURST OUT of the word's middle together and spring back to their size; as they hit, the word
--- shakes, impact lines and shards fly out ALL ROUND it and the screen's edge bars pulse once; then the word swells and is gone:
--- GO_LIFE in all.
function Callouts.go(colours: { Color3 }, small: boolean)
	UiSound.play("round_go")
	serial += 1
	local id = `go{serial}`
	local _holder, group, away = countStage("Tussle", small)
	local sheet = Shapes.count
	local ink = colour("ink.900")
	local tones = tonesOf(colours[1])
	local still = HudMotion.reduced()

	-- a card is its letter plus the mockup's 12 of padding and 5 of border each side, 138 tall, 7 apart
	local TALL, GAP = 138, 7
	local widths: { number } = {}
	local total = GAP * (#TUSSLE - 1)
	for index, letter in TUSSLE do
		widths[index] = math.round(sheet.letters[letter].width) + 34
		total += widths[index]
	end
	local row = make("Frame", group, {
		Name = "Word",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(total, TALL),
		Rotation = -4,
		ZIndex = 2,
	})
	local rowScale = make("UIScale", row, {})
	local fades: { { any } } = {}
	local glyphSize = sheet.letterCell / sheet.letterScale
	local x = 0
	for index, letter in TUSSLE do
		local last = index == #TUSSLE
		local even = index % 2 == 0
		local restTurn = if last then 9 elseif even then 5 else 0
		local restY = TALL / 2 + (if last then -6 elseif even then 5 else 0)
		local width = widths[index]
		local restX = x + width / 2
		local card = make("Frame", row, {
			Name = letter,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(restX, restY),
			Size = UDim2.fromOffset(width, TALL),
			Rotation = restTurn,
			Visible = still,
		})
		x += width + GAP
		local cardScale = make("UIScale", card, {})
		local shadow = make("Frame", card, {
			Name = "Shadow",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 9),
			Size = UDim2.fromScale(1, 1),
		})
		local edge = make("Frame", card, {
			Name = "Edge",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		})
		local face = make("Frame", card, {
			Name = "Face",
			BackgroundColor3 = colours[index] or colours[1],
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.new(1, -10, 1, -10),
			ZIndex = 3,
		})
		comicCard(shadow, edge, face, 12)
		local spot = sheet.letters[letter]
		local glyph = make("ImageLabel", card, {
			Name = "Glyph",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(glyphSize.X, glyphSize.Y),
			Image = Shapes.ids.count,
			ImageRectOffset = Vector2.new(spot.cell * sheet.letterCell.X, sheet.letterTop),
			ImageRectSize = sheet.letterCell,
			ImageColor3 = letterOn(colours[index] or colours[1]),
			ZIndex = 4,
		})
		local mine: { { any } } = {
			{ shadow, "BackgroundTransparency" },
			{ edge, "BackgroundTransparency" },
			{ face, "BackgroundTransparency" },
			{ glyph, "ImageTransparency" },
		}
		table.move(mine, 1, #mine, #fades + 1, fades)
		if not still then
			-- every card bursts out of the word's middle at the same moment: small to bigger than itself, flying
			-- to its place with a twist, then springing back to its size
			local fromX, fromY = total / 2, TALL / 2
			local fromTurn = if even then 34 else -34
			Poster.run(`{id}letter{index}`, GO_POP, function(t: number)
				local e = popCurve(t)
				card.Visible = true
				local clear = 1 - math.min(1, t * 4)
				for _, fade in mine do
					fade[1][fade[2]] = clear
				end
				card.Position =
					UDim2.fromOffset(fromX + (restX - fromX) * e, fromY + (restY - fromY) * e)
				card.Rotation = fromTurn + (restTurn - fromTurn) * e
				cardScale.Scale = 0.2 + (GO_OVER - 0.2) * e
			end)
			Poster.run(`{id}set{index}`, GO_SETTLE, function(t: number)
				cardScale.Scale = GO_OVER + (1 - GO_OVER) * spring(t)
			end, nil, GO_POP)
		end
	end

	if still then
		task.delay(1, away)
		return
	end
	-- the word hits: the shake, the lines (on an oval, the word is wide) and the shards, ALL ROUND THE WORD (the
	-- owner, 2026-11-18: "have the effects SURROUNDING the word, like a popup"). Until then nothing went up: the
	-- fighters' row comes up over the word at this very moment, and lines all round crossed its tiles (no UI
	-- piece may overlap another). So the upper half is there but SHORT: its lines stand on a flatter oval and
	-- stop sooner, and its shards are thrown only a little way, so both end under the row.
	jolt(`{id}shake`, group, 30, 16, 0.34, WORD_HIT)
	-- (ui-24a) speed pills: to the sides and below, and a short fan above (the row comes up over the word now)
	pills(
		group,
		`{id}lines`,
		0,
		0,
		total / 2 + 10,
		TALL / 2 + 8,
		fan(16, -8, 188),
		tones,
		300,
		24,
		WORD_HIT,
		small
	)
	pills(
		group,
		`{id}linesUp`,
		0,
		0,
		total / 2 + 10,
		TALL / 2 + 8,
		fan(9, 206, 334),
		tones,
		130,
		18,
		WORD_HIT,
		small
	)

	Callouts.edges(colours[1])
	-- the whole word: holds, dips a little, then swells and is gone
	Poster.run(id, GO_LIFE, function(t: number)
		rowScale.Scale = keyframes(GO_SIZE, t, ease)
		local clear = keyframes(GO_CLEAR, t, ease)
		if clear > 0 then
			for _, fade in fades do
				fade[1][fade[2]] = clear
			end
		end
	end, away)
end

-- THE FIGHT'S POP-UPS, IN THE COUNTDOWN'S STYLE (ui-17a) ---------------------------------------------
--
-- The owner, 2026-11-18, after the countdown: "since you changed the style, can u change it for everything ELSE
-- ... the ones that pop up on ur screen during ur fight in the arena, like 5 4 3 2 players left ... I want it to
-- be different"; seen on the mockup page first (`.kr`, `.lnw`, lastCall, gotUlt, fire), then "Yes, build them".
-- ONE WAY OF SAYING THINGS: a word is cut-out letter cards that HIT one after another, straight at you
-- (`cardRow`); a number is a big rough-cut tile that slams in; the hit shakes the pop-up and throws impact lines
-- (`slashes`); the big moments throw shards. No slanted bar, no streak, no confetti, no stamp.
-- WHAT DID NOT CHANGE (his rules of 2026-11-17): they are small, stand right under the top strip, come in fast
-- from the left, drift right while they are read and leave to the right (`stage`, `glide`). So their lines and
-- shards fan to the sides and DOWN only: the strip and the fighters' row are just above.

local CARD_FROM = 2.5 -- a card comes at you from this many times its size

-- A word in letter cards (the mockup's `.kr`): each card is its letter in ink on cream, on `alt` (every second
-- one) or on yellow (every third), with an ink edge and a hard ink shadow; the row is turned 4 degrees, the even
-- cards 5 more, the last one 6 the other way. `size` is the letters' size in the mockup's pixels. Each card hits
-- in CARD_HIT seconds, `gap` after the one before, the first at `wait`.
-- Returns the row (NOT parented yet: its size is needed to lay the pop-up out), its size, and when the last card
-- lands.
local function cardRow(
	key: string,
	text: string,
	size: number,
	tones: Tones,
	wait: number,
	gap: number
): (Frame, Vector2, number)
	local sheet = Shapes.cards
	local ink, paper = colour("ink.900"), colour("ivory.50")
	local still = HudMotion.reduced()
	local k = size / sheet.size
	local border = math.max(3, math.round(size * 0.045))
	local pad = size * 0.1
	local tall = size + 2 * border
	local GAP = 6
	local count = #text
	local widths: { number } = {}
	local total = GAP * (count - 1)
	for index = 1, count do
		local spot = sheet.letters[string.sub(text, index, index)]
		widths[index] = math.round((if spot then spot.width else 60) * k + 2 * pad + 2 * border)
		total += widths[index]
	end
	local row = make("Frame", nil, {
		Name = "Cards",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(total, tall),
		Rotation = -4,
		ZIndex = 2,
	})
	local glyphSize = sheet.cell / sheet.scale * k
	local x = 0
	for index = 1, count do
		local letter = string.sub(text, index, index)
		local last = index == count
		local even = index % 2 == 0
		local restTurn = if last then -6 elseif even then 5 else 0
		local restY = tall / 2 + (if last then -0.04 * size elseif even then 0.04 * size else 0)
		local width = widths[index]
		-- the palette (ui-24a): the last card deep, every third the tint, every second the colour, the rest cream
		local faceTone = if last
			then tones.deep
			elseif index % 3 == 0 then tones.light
			elseif even then tones.tone
			else paper
		local card = make("Frame", row, {
			Name = letter,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x + width / 2, restY),
			Size = UDim2.fromOffset(width, tall),
			Rotation = restTurn,
			Visible = still,
		})
		x += width + GAP
		local cardScale = make("UIScale", card, {})
		local shadow = make("Frame", card, {
			Name = "Shadow",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(math.round(size * 0.065), math.round(size * 0.075)),
			Size = UDim2.fromScale(1, 1),
		})
		local edge = make("Frame", card, {
			Name = "Edge",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		})
		local face = make("Frame", card, {
			Name = "Face",
			BackgroundColor3 = faceTone,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(border, border),
			Size = UDim2.new(1, -2 * border, 1, -2 * border),
			ZIndex = 3,
		})
		comicCard(shadow, edge, face, math.max(6, math.round(size * 0.09)))
		local spot = sheet.letters[letter]
		local glyph = make("ImageLabel", card, {
			Name = "Glyph",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(glyphSize.X, glyphSize.Y),
			Image = Shapes.ids.cards,
			ImageRectOffset = if spot
				then Vector2.new(
					spot.cell % sheet.perRow * sheet.cell.X,
					math.floor(spot.cell / sheet.perRow) * sheet.cell.Y
				)
				else Vector2.zero,
			ImageRectSize = sheet.cell,
			ImageColor3 = letterOn(faceTone),
			Visible = spot ~= nil,
			ZIndex = 4,
		})
		if not still then
			local at = wait + (index - 1) * gap
			Poster.run(`{key}card{index}`, CARD_HIT, function(t: number)
				local e = PosterEase.easeIn(t)
				local clear = 1 - math.min(1, t * 3)
				card.Visible = true
				shadow.BackgroundTransparency = clear
				edge.BackgroundTransparency = clear
				face.BackgroundTransparency = clear
				glyph.ImageTransparency = clear
				cardScale.Scale = CARD_FROM + (CARD_SIZE - CARD_FROM) * e
				card.Rotation = restTurn - 20 * (1 - e)
			end, nil, at)
			Poster.run(`{key}set{index}`, CARD_SETTLE, function(t: number)
				cardScale.Scale = CARD_SIZE + (1 - CARD_SIZE) * spring(t)
			end, nil, at + CARD_HIT)
		end
	end
	return row, Vector2.new(total, tall), wait + (count - 1) * gap + CARD_HIT
end

-- A pop-up's life on its stage: it glides in from the left, drifts while it is read and leaves to the right
-- (`away` is the 0-to-1 keyframes of leaving), with one hard shake at `kickAt` seconds. `done` runs as it goes.
local function live(
	id: string,
	holder: Frame,
	group: Frame,
	span: number,
	seconds: number,
	away: { { number } },
	kickAt: number,
	kickSeconds: number,
	kickX: number,
	kickY: number,
	done: (() -> ())?
)
	local left = false
	local function leave()
		if left then
			return
		end
		left = true
		holder:Destroy()
		if done then
			done()
		end
	end
	if HudMotion.reduced() then
		-- no motion: everything is already at rest; it stays for its line and goes
		task.delay(seconds * away[2][1], leave)
		return
	end
	local canvas: CanvasGroup? = nil
	Poster.run(id, seconds, function(t: number)
		local gone = keyframes(away, t, ease)
		local elapsed = t * seconds
		local x, y = 0, 0
		local into = (elapsed - kickAt) / kickSeconds
		if into > 0 and into < 1 then
			local kick = keyframes(JOLT, into, ease)
			x, y = kickX * kick, kickY * kick
		end
		if gone > 0 and not canvas then
			canvas = toCanvas(group)
		end
		local moving: GuiObject = canvas or group
		moving.Position = UDim2.new(0.5, x + glide(elapsed, t, gone, span), 0.5, y)
		if canvas then
			canvas.GroupTransparency = gone
		end
	end, leave)
end

-- A rough-cut piece that comes at you and hits: hidden until `at`, then from `from` times its size (turned 22
-- degrees further) to HIT_SIZE in `seconds`, then the spring back to 1.
local function slam(
	key: string,
	piece: GuiObject,
	scale: UIScale,
	restTurn: number,
	from: number,
	at: number
)
	if HudMotion.reduced() then
		piece.Visible = true
		return
	end
	piece.Visible = false
	Poster.run(`{key}in`, HIT, function(t: number)
		local e = PosterEase.easeIn(t)
		piece.Visible = true
		scale.Scale = from + (HIT_SIZE - from) * e
		piece.Rotation = restTurn - 22 * (1 - e)
	end, nil, at)
	Poster.run(`{key}settle`, SETTLE, function(t: number)
		scale.Scale = HIT_SIZE + (1 - HIT_SIZE) * spring(t)
	end, nil, at + HIT)
end

-- A rough-cut quad (a name in Shapes.ids) with its ink edge, a fill `line` units in and a hard ink shadow.
local function quad(
	parent: Instance,
	shape: string,
	tone: string,
	line: number,
	shadowX: number,
	shadowY: number
)
	Shapes.image(
		parent,
		shape,
		"ink.900",
		{ Name = "Shadow", Position = UDim2.fromOffset(shadowX, shadowY) }
	)
	Shapes.image(parent, shape, "ink.900", { Name = "Line", ZIndex = 2 })
	Shapes.image(parent, shape, tone, {
		Name = "Fill",
		Position = UDim2.fromOffset(line, line),
		Size = UDim2.new(1, -2 * line, 1, -2 * line),
		ZIndex = 3,
	})
end

-- THE ULTIMATE ---------------------------------------------------------------------------------------

local UC_AWAY = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } }

--- "ULTIMATE ... READY": the notice for earning your ultimate, in `tone` (your class colour). ULTIMATE hits in
--- cards; as the last one lands the lines and shards fly; then READY and the key land as a yellow rough-cut tag.
--- `key` is the key cap to show ("G"), or nil on touch. `done` runs as it leaves, when the badge takes over.
function Callouts.ultimate(tone: Color3, key: string?, done: (() -> ())?)
	local line = VoiceLines.Lines["ultimate-ready"]
	local seconds = math.max(1.7, (0.12 + line.seconds) / 0.8)
	serial += 1
	local id = `ultimate{serial}`
	local tones = tonesOf(tone)
	local row, box, hit = cardRow(id, "ULTIMATE", 74, tones, 0.25, CARD_GAP)
	local holder, group, _groupScale, origin, span = stage("Ultimate", box, 0.6)
	local centre = origin + box / 2
	row.Position = UDim2.fromOffset(centre.X, centre.Y)
	row.Parent = group

	-- READY and the key: a yellow tag 52 past the row's right edge and 56 below it, landing after the word
	local tagSize = Vector2.new(if key then 172 else 124, 54)
	local tag = make("Frame", group, {
		Name = "Ready",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(
			origin.X + box.X + 52 - tagSize.X / 2,
			origin.Y + box.Y + 56 - tagSize.Y / 2
		),
		Size = UDim2.fromOffset(tagSize.X, tagSize.Y),
		Rotation = -8,
		ZIndex = 4,
	})
	local tagScale = make("UIScale", tag, {})
	quad(tag, "badge", "gold.400", 5, 6, 7)
	-- the tag in your tint (ui-24a: no yellow mixed in)
	local tagFill = tag:FindFirstChild("Fill") :: ImageLabel
	tagFill.ImageColor3 = tones.light
	local words = make("Frame", tag, {
		Name = "Words",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	})
	make("UIListLayout", words, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	})
	Poster.word(words, "words", "stamp:READY", 30, "ink.900", { LayoutOrder = 1 })
	if key then
		local cap = make("Frame", words, {
			Name = "Cap",
			BackgroundColor3 = colour("ink.900"),
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Size = UDim2.fromOffset(40, 32),
		})
		local capFace = make("Frame", cap, {
			BackgroundColor3 = colour("ivory.50"),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
		})
		Poster.text(capFace, "display", 18, "ink.900", {
			Size = UDim2.fromScale(1, 1),
			Text = key,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	-- (from twice its size, not three times: at three its corner swept over the fighters' row)
	slam(`{id}ready`, tag, tagScale, -8, 2, hit + 0.16)

	-- the last card lands: speed pills, to the sides and down only
	pills(
		group,
		`{id}lines`,
		centre.X,
		centre.Y,
		box.X / 2 + 8,
		box.Y / 2 + 6,
		fan(14, -8, 188),
		tones,
		210,
		16,
		hit,
		key == nil
	)
	Callouts.edges(tone)
	task.delay(0.12, Callouts.speak, "ultimate-ready")
	live(id, holder, group, span, seconds, UC_AWAY, hit, 0.36, 22, 12, done)
end

-- THE LAST PLAYERS -----------------------------------------------------------------------------------

-- each count: the tile's colour, the number's cell on Shapes.last with its box's width and the size it was
-- drawn at there, the size it is shown at, the words, the first kick of the shake, how many lines
local LAST = {
	[5] = {
		cell = 0,
		wide = 117,
		drawn = 230,
		font = 184,
		words = "LEFT",
		tag = "FIGHTERS",
		kick = Vector2.new(14, 8),
		lines = 9,
	},
	[4] = {
		cell = 1,
		wide = 121,
		drawn = 230,
		font = 184,
		words = "LEFT",
		tag = "FIGHTERS",
		kick = Vector2.new(16, 9),
		lines = 9,
	},
	[3] = {
		cell = 2,
		wide = 131,
		drawn = 255,
		font = 200,
		words = "LEFT",
		tag = "FIGHTERS",
		kick = Vector2.new(21, 11),
		lines = 9,
	},
	[2] = {
		cell = 3,
		wide = 149,
		drawn = 290,
		font = 222,
		words = "FINAL",
		tag = "TWO LEFT",
		kick = Vector2.new(28, 14),
		lines = 13,
	},
}
local LC_AWAY = { { 0, 0 }, { 0.74, 0 }, { 1, 1 } }
local TILE_AT = 0.3 -- the number tile starts in (the pop-up is still arriving); it lands HIT later
local TAG_TALL, TAG_GAP, SIDE_GAP = 36, 12, 22

--- Whether a count gets a popup (5, 4, 3 and 2).
function Callouts.hasLast(count: number): boolean
	return LAST[count] ~= nil
end

--- The last-players popup for `count` standing: the number on a rough-cut tile in the count's colour that slams
--- in, a small ink tag (FIGHTERS) over LEFT in cards; at two the order turns round, FINAL in cards and then
--- the 2, with more lines, shards and a bigger shake. `small` is the phone size. `done` runs as it leaves, when
--- the strip's count should bump.
function Callouts.last(count: number, small: boolean, done: (() -> ())?)
	local spec = LAST[count]
	if not spec then
		if done then
			done()
		end
		return
	end
	UiSound.play(`last_{count}`)
	local voice = VoiceLines.Last[count]
	local line = VoiceLines.Lines[voice]
	local seconds = math.max(1.7, (0.1 + line.seconds) / 0.74)
	serial += 1
	local id = `last{serial}`
	local two = count == 2
	local still = HudMotion.reduced()
	local ink = colour("ink.900")
	local tones = tonesOf(yours or colour("coral.500"))

	-- the sizes first: the tile is its number plus the mockup's padding; beside it the tag over the cards
	local shown = spec.font / spec.drawn
	local tileSize = Vector2.new(math.round(spec.wide * shown) + 62, spec.font + 10)
	local row, rowSize =
		cardRow(id, spec.words, if two then 104 else 92, tones, TILE_AT + 0.2, CARD_GAP)
	local sideTall = TAG_TALL + TAG_GAP + rowSize.Y
	local box = Vector2.new(tileSize.X + SIDE_GAP + rowSize.X, math.max(tileSize.Y, sideTall))
	local holder, group, _groupScale, origin, span =
		stage("LastPlayers", box, if small then 0.38 else 0.46)
	local middle = origin.Y + box.Y / 2
	-- at two the words come first and the number last
	local tileX = origin.X + (if two then rowSize.X + SIDE_GAP + tileSize.X / 2 else tileSize.X / 2)
	local sideLeft = origin.X + (if two then 0 else tileSize.X + SIDE_GAP)

	-- the number tile
	local tile = make("Frame", group, {
		Name = "Number",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(tileX, middle),
		Size = UDim2.fromOffset(tileSize.X, tileSize.Y),
		Rotation = -6,
		ZIndex = 2,
	})
	local tileScale = make("UIScale", tile, {})
	quad(tile, "tile", "ivory.50", 7, 9, 10)
	-- your colour, its deep shade at three and two (ui-24a; it was yellow, then red)
	local tileFill = tile:FindFirstChild("Fill") :: ImageLabel
	tileFill.ImageColor3 = if count <= 3 then tones.deep else tones.tone
	local sheet = Shapes.last
	make("ImageLabel", tile, {
		Name = "Figure",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- (the mockup pads the number 22 on the left and 40 on the right, and 10 under it)
		Position = UDim2.new(0.5, -9, 0.5, -5),
		Size = UDim2.fromOffset(sheet.cell.X * shown, sheet.cell.Y * shown),
		Image = Shapes.ids.last,
		ImageRectOffset = Vector2.new(spec.cell * sheet.cell.X, 0),
		ImageRectSize = sheet.cell,
		ZIndex = 4,
	})
	slam(`{id}tile`, tile, tileScale, -6, 3, TILE_AT)
	local hit = TILE_AT + HIT

	-- the words beside it: the tag, then the cards under it
	local top = middle - sideTall / 2
	row.Position =
		UDim2.fromOffset(sideLeft + rowSize.X / 2, top + TAG_TALL + TAG_GAP + rowSize.Y / 2)
	row.Parent = group
	-- (straight, not turned as in the mockup: small text that is turned is drawn soft)
	local tag = make("Frame", group, {
		Name = "Tag",
		BackgroundColor3 = ink,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(if two then 1 else 0, 0),
		Position = UDim2.fromOffset(sideLeft + (if two then rowSize.X else 0), top),
		Size = UDim2.fromOffset(0, TAG_TALL),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = still,
		ZIndex = 3,
	})
	make("UIPadding", tag, { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) })
	local tagScale = make("UIScale", tag, {})
	Poster.text(tag, "label", 25, "ivory.50", {
		Size = UDim2.fromOffset(0, TAG_TALL),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = spec.tag,
	})
	if not still then
		Poster.run(`{id}tag`, 0.1, function(t: number)
			tag.Visible = true
			tagScale.Scale = 2 + (1 - 2) * PosterEase.easeIn(t)
		end, nil, TILE_AT + 0.42)
	end

	-- the tile lands: speed pills from behind it, to the sides and down only (more and further at two)
	pills(
		group,
		`{id}lines`,
		tileX,
		middle,
		tileSize.X / 2 + 6,
		tileSize.Y / 2 + 6,
		fan(spec.lines, -8, 188),
		tones,
		if two then 240 else 180,
		if two then 18 else 15,
		hit,
		small
	)
	Callouts.edges(tones.tone)
	task.delay(0.1, Callouts.speak, voice)
	live(
		id,
		holder,
		group,
		span,
		seconds,
		LC_AWAY,
		hit,
		if two then 0.46 else 0.34,
		spec.kick.X,
		spec.kick.Y,
		done
	)
end

-- USING THE ULTIMATE ---------------------------------------------------------------------------------

local CN_AWAY = { { 0, 0 }, { 0.68, 0 }, { 1, 1 } }

--- Your class's name as you use your ultimate: big cards that hit one after another, lines and shards as the last
--- one lands, then it is gone to the right (1.7 s). `name` is the class's id ("Frost"); `tone` its colour.
function Callouts.className(name: string, tone: Color3, small: boolean)
	local word = string.upper(name)
	if #word == 0 or string.find(word, "[^A-Z]") then
		return
	end
	serial += 1
	local id = `class{serial}`
	local tones = tonesOf(tone)
	local row, box, hit = cardRow(id, word, 112, tones, 0.3, 0.04)
	local holder, group, _groupScale, origin, span =
		stage("ClassName", box, if small then 0.4 else 0.5)
	local centre = origin + box / 2
	row.Rotation = -5
	row.Position = UDim2.fromOffset(centre.X, centre.Y)
	row.Parent = group
	pills(
		group,
		`{id}lines`,
		centre.X,
		centre.Y,
		box.X / 2 + 10,
		box.Y / 2 + 8,
		fan(16, -8, 188),
		tones,
		300,
		22,
		hit,
		small
	)
	Callouts.edges(tone)
	live(id, holder, group, span, 1.7, CN_AWAY, hit, 0.4, 30, 16, nil)
end

return Callouts
