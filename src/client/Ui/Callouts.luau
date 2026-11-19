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
-- sharp ink-edged impact lines, the big moments throw shards. No bars, streaks, stamps or confetti.
--
-- Neither covers the screen, nothing flashes, and nothing here runs unless one is on screen: each is built when
-- it starts and destroyed when it ends. Under Reduced Motion they appear and leave without the motion.
-- The owner's five voice lines play from Config/VoiceLines once their ids are filled in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

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

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
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
-- an impact line's length over its life: out at once, then drawn away to nothing
local SLASH_LONG = { { 0, 0.2 }, { 0.25, 1 }, { 1, 0 } }
local shardCurve = PosterEase.bezier(0.1, 0.7, 0.2, 1)

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
		tone = "ivory.50",
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
		tone = "gold.400",
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
		tone = "danger.600",
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

-- Impact lines: straight ink-edged bars that shoot out from behind a hit along `angles` (degrees; 0 is right,
-- 90 is down) and are drawn away to nothing as they go. They start `near` from (x, y) and run out to `far`;
-- `flat` squashes the ring they stand on (a wide word's is an oval). Every other one is `tones[2]`.
local function slashes(
	parent: Instance,
	key: any,
	x: number,
	y: number,
	angles: { number },
	tones: { Color3 },
	near: number,
	far: number,
	long: number,
	thick: number,
	flat: number,
	seconds: number,
	wait: number
)
	if HudMotion.reduced() then
		return
	end
	local ink = colour("ink.900")
	local lines = {}
	for index, angle in angles do
		local line = make("Frame", parent, {
			Name = "Slash",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(0, 0),
			Rotation = angle,
			Visible = false,
			ZIndex = 1,
		})
		local face = make("Frame", line, {
			BackgroundColor3 = tones[(index - 1) % #tones + 1],
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
		})
		local turn = math.rad(angle)
		local cos, sin = math.cos(turn), math.sin(turn) * flat
		-- on a squashed ring a line still points straight away from the middle
		line.Rotation = math.deg(math.atan2(sin, cos))
		lines[index] = { line = line, face = face, cos = cos, sin = sin }
	end
	Poster.run(key, seconds, function(t: number)
		local out = near + (far - near) * PosterEase.easeOut(t)
		local length = long * keyframes(SLASH_LONG, t, PosterEase.linear)
		local wide = thick * (1 - 0.35 * t)
		local reach = out + length / 2
		for _, l in lines do
			l.line.Visible = true
			l.line.Position = UDim2.fromOffset(x + l.cos * reach, y + l.sin * reach)
			l.line.Size = UDim2.fromOffset(length, wide)
			l.face.Visible = length > 8
		end
	end, function()
		for _, l in lines do
			l.line:Destroy()
		end
	end, wait)
end

-- Shards: thin ink-edged slivers thrown out fast from (x, y), tumbling, gone in about half a second. The word's
-- answer to confetti: nothing round, nothing that drifts.
local function shards(
	parent: Instance,
	key: any,
	x: number,
	y: number,
	count: number,
	reachMin: number,
	reachMax: number,
	tones: { Color3 },
	first: number, -- the fan they are thrown into: from this angle (0 is right, 90 is down)...
	sweep: number, -- ...round by this many degrees
	seconds: number,
	wait: number
)
	if HudMotion.reduced() then
		return
	end
	local ink = colour("ink.900")
	local pieces = {}
	for index = 1, count do
		local angle = first
			+ (index - 1) / math.max(count - 1, 1) * sweep
			+ (math.random() - 0.5) * 10
		local reach = reachMin + math.random() * (reachMax - reachMin)
		local piece = make("Frame", parent, {
			Name = "Shard",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(0, 0),
			Visible = false,
			ZIndex = 1,
		})
		local face = make("Frame", piece, {
			BackgroundColor3 = tones[(index - 1) % #tones + 1],
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
		})
		local turn = math.rad(angle)
		pieces[index] = {
			piece = piece,
			face = face,
			angle = angle,
			spin = (math.random() * 2 - 1) * 220,
			dx = math.cos(turn) * reach,
			dy = math.sin(turn) * reach * 0.7,
		}
	end
	Poster.run(key, seconds, function(t: number)
		local e = shardCurve(t)
		local size = 0.6 + 0.4 * math.min(1, t * 4)
		local clear = if t > 0.7 then (t - 0.7) / 0.3 else 0
		for _, p in pieces do
			p.piece.Visible = true
			p.piece.Position = UDim2.fromOffset(x + p.dx * e, y + p.dy * e + 40 * t * t)
			p.piece.Size = UDim2.fromOffset(34 * size, 10 * size)
			p.piece.Rotation = p.angle + p.spin * t
			p.piece.BackgroundTransparency = clear
			p.face.BackgroundTransparency = clear
		end
	end, function()
		for _, p in pieces do
			p.piece:Destroy()
		end
	end, wait)
end

--- One number of the countdown (3, 2 or 1): it comes fast in its own way (COUNT_MOVE), hits hard, shakes and
--- throws its impact lines, and is knocked away just before the next one is due. `small` is the phone size.
function Callouts.count(beat: number, small: boolean)
	local sheet = Shapes.count
	local cell = sheet.numbers[beat]
	local move = COUNT_MOVE[beat]
	if not cell or not move then
		return
	end
	UiSound.play(`cd_{beat}`)
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
	slashes(
		group,
		`{id}lines`,
		0,
		move.lineY,
		move.lines,
		{ colour(move.tone), colour("ink.900") },
		move.near,
		move.far,
		move.long,
		14,
		1,
		0.3,
		HIT
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

--- "TUSSLE!": the fight is on. Seven cut-out letters in boxes (cream, your class colour `tone`, yellow, the "!"
--- pink and tipped) BURST OUT of the word's middle together and spring back to their size; as they hit, the word
--- shakes, impact lines and shards fly out ALL ROUND it and the screen's edge bars pulse once; then the word swells and is gone:
--- GO_LIFE in all.
function Callouts.go(tone: Color3, small: boolean)
	UiSound.play("round_go")
	serial += 1
	local id = `go{serial}`
	local _holder, group, away = countStage("Tussle", small)
	local sheet = Shapes.count
	local ink, paper = colour("ink.900"), colour("ivory.50")
	local coin, danger = colour("gold.400"), colour("danger.600")
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
			BackgroundColor3 = if last
				then danger
				elseif index % 3 == 0 then coin
				elseif even then tone
				else paper,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.new(1, -10, 1, -10),
			ZIndex = 3,
		})
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
			ImageColor3 = if last then paper else ink,
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
	local lineTones = { tone, ink }
	-- the sides and below (0 is right, 90 is down)
	slashes(
		group,
		`{id}lines`,
		0,
		0,
		fan(16, -8, 188),
		lineTones,
		300,
		480,
		190,
		16,
		0.5,
		0.32,
		WORD_HIT
	)
	-- above
	slashes(
		group,
		`{id}linesUp`,
		0,
		0,
		fan(11, 202, 338),
		lineTones,
		300,
		400,
		120,
		16,
		0.4,
		0.32,
		WORD_HIT
	)
	shards(group, `{id}shards`, 0, 0, 20, 300, 560, { coin, tone, paper }, 0, 180, 0.55, WORD_HIT)
	shards(
		group,
		`{id}shardsUp`,
		0,
		0,
		12,
		110,
		170,
		{ coin, tone, paper },
		195,
		150,
		0.5,
		WORD_HIT
	)
	Callouts.edges(tone)
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
	alt: Color3,
	wait: number,
	gap: number
): (Frame, Vector2, number)
	local sheet = Shapes.cards
	local ink, paper, coin = colour("ink.900"), colour("ivory.50"), colour("gold.400")
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
			BackgroundColor3 = if index % 3 == 0 then coin elseif even then alt else paper,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(border, border),
			Size = UDim2.new(1, -2 * border, 1, -2 * border),
			ZIndex = 3,
		})
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
			ImageColor3 = ink,
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
	local row, box, hit = cardRow(id, "ULTIMATE", 74, tone, 0.25, CARD_GAP)
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

	-- the last card lands: lines on a flat oval (the word is wide) and shards, to the sides and down only
	slashes(
		group,
		`{id}lines`,
		centre.X,
		centre.Y,
		fan(14, -8, 188),
		{ tone, colour("ink.900") },
		300,
		470,
		170,
		14,
		0.45,
		0.32,
		hit
	)
	shards(
		group,
		`{id}shards`,
		centre.X,
		centre.Y,
		16,
		260,
		470,
		{ colour("gold.400"), tone, colour("ivory.50") },
		0,
		180,
		0.55,
		hit
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
		tone = "gold.400",
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
		tone = "gold.400",
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
		tone = "danger.600",
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
		tone = "danger.600",
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
	local tone = colour(spec.tone)

	-- the sizes first: the tile is its number plus the mockup's padding; beside it the tag over the cards
	local shown = spec.font / spec.drawn
	local tileSize = Vector2.new(math.round(spec.wide * shown) + 62, spec.font + 10)
	local row, rowSize =
		cardRow(id, spec.words, if two then 104 else 92, tone, TILE_AT + 0.2, CARD_GAP)
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
	quad(tile, "tile", spec.tone, 7, 9, 10)
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

	-- the tile lands: lines from behind it, to the sides and down only; at two, shards as well
	slashes(
		group,
		`{id}lines`,
		tileX,
		middle + tileSize.Y * 0.06,
		fan(spec.lines, -8, 188),
		{ tone, ink },
		if two then 150 else 130,
		if two then 330 else 250,
		if two then 150 else 120,
		if two then 16 else 14,
		0.8,
		0.3,
		hit
	)
	if two then
		shards(
			group,
			`{id}shards`,
			tileX,
			middle,
			16,
			200,
			420,
			{ colour("gold.400"), tone, colour("ivory.50") },
			0,
			180,
			0.55,
			hit
		)
	end
	Callouts.edges(tone)
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
	local row, box, hit = cardRow(id, word, 112, tone, 0.3, 0.04)
	local holder, group, _groupScale, origin, span =
		stage("ClassName", box, if small then 0.4 else 0.5)
	local centre = origin + box / 2
	row.Rotation = -5
	row.Position = UDim2.fromOffset(centre.X, centre.Y)
	row.Parent = group
	slashes(
		group,
		`{id}lines`,
		centre.X,
		centre.Y,
		fan(18, -8, 188),
		{ tone, colour("ink.900") },
		340,
		600,
		220,
		16,
		0.5,
		0.32,
		hit
	)
	shards(
		group,
		`{id}shards`,
		centre.X,
		centre.Y,
		24,
		300,
		620,
		{ colour("gold.400"), tone, colour("ivory.50") },
		0,
		180,
		0.55,
		hit
	)
	Callouts.edges(tone)
	live(id, holder, group, span, 1.7, CN_AWAY, hit, 0.4, 30, 16, nil)
end

return Callouts
