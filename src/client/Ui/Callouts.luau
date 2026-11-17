--!strict
-- Callouts - the fight-poster look's two big announcements, built to the mockup's pixels and timings
-- (UI Research/fight-poster-prototype.html: `.ucall` / gotUlt and `.lcall` / lastCall):
--
--   ultimate   "ULTIMATE" in cut-out letters dropping in one by one over a slanted streak, a READY stamp with the
--              key, confetti, and the thin edge bars pulsing once. It holds until its voice line would end, then
--              flies down toward the skills, where UltimateNotice's badge takes over.
--   last       at 5, 4, 3 and 2 standing: a big slanted number slams in over a coloured bar with FIGHTERS LEFT
--              (FINAL TWO, a shake and confetti at 2), holds for its line, then flies up into the strip.
--
-- Neither covers the screen, nothing flashes, and nothing here runs unless one is on screen: each is built when
-- it starts and destroyed when it ends. Under Reduced Motion they appear and leave without the motion.
-- The owner's five voice lines play from Config/VoiceLines once their ids are filled in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")

local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local VoiceLines = require(ReplicatedStorage.Shared.Config.VoiceLines)
local HudMotion = require(script.Parent.HudMotion)
local HudTheme = require(script.Parent.HudTheme)
local Poster = require(script.Parent.Poster)
local Shapes = require(script.Parent.Shapes)

local Callouts = {}

local colour = Tokens.colour
local TAN22 = math.tan(math.rad(22))
local spring, ease, keyframes = PosterEase.spring, PosterEase.ease, PosterEase.keyframes
local streakCurve = PosterEase.bezier(0.2, 0.8, 0.2, 1)

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
	return math.clamp(
		math.min(view.X / ref.X, view.Y / ref.Y),
		HudTheme.Scale.Min,
		HudTheme.Scale.Max
	)
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

-- A slanted band with a border along its top and bottom: `outer` shows as the border, `inner` lies over it.
-- It is `width` x `height` at (x, y) in `parent`, leaning 22 degrees, and returns its holder (anchored on the
-- side it grows from) and a function that sets how much of its width shows.
local function band(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	border: number,
	outer: Color3,
	inner: Color3,
	fromRight: boolean
): (number) -> ()
	local holder = make("Frame", parent, {
		Name = "Band",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(if fromRight then 1 else 0, 0),
		Position = UDim2.fromOffset(if fromRight then x + width else x, y),
		Size = UDim2.fromOffset(width, height),
		ClipsDescendants = false,
	})
	local lean = height * TAN22
	local slip = border * TAN22
	local back = Shapes.slant(holder, "ink.900", lean, { Name = "Outer" })
	Shapes.paint(back, outer)
	local front = Shapes.slant(holder, "ink.900", lean - 2 * slip, {
		Name = "Inner",
		Position = UDim2.fromOffset(slip, border),
		Size = UDim2.new(1, -2 * slip, 1, -2 * border),
		ZIndex = 1,
	})
	Shapes.paint(front, inner)
	return function(share: number)
		local shown = width * share
		holder.Visible = shown > 2 * lean + 2
		holder.Size = UDim2.fromOffset(shown, height)
	end
end

-- Confetti: `count` squares and rounds thrown out from (x, y) and falling away (the mockup's `cf`, 1.2 s after a
-- 0.3 s wait). `reach` is the least and most distance.
local CF_SHARE = { { 0, 0 }, { 0.15, 0.3 }, { 0.65, 1 }, { 1, 1 } }
local CF_FALL = { { 0, 0 }, { 0.65, 0 }, { 1, 140 } }
local CF_TURN = { { 0, 0 }, { 0.15, 0 }, { 0.65, 380 }, { 1, 600 } }
local CF_SIZE = { { 0, 0 }, { 0.15, 1.3 }, { 0.65, 1 }, { 1, 0.4 } }
local CF_SEEN = { { 0, 1 }, { 0.65, 1 }, { 1, 0 } }
local function confetti(
	parent: Instance,
	key: any,
	x: number,
	y: number,
	count: number,
	reachMin: number,
	reachMax: number,
	tones: { Color3 }
)
	if HudMotion.reduced() then
		return
	end
	local ink = colour("ink.900")
	local pieces = {}
	for index = 1, count do
		local angle = (index - 1) / count * 6.283 + math.random() * 0.3
		local reach = reachMin + math.random() * (reachMax - reachMin)
		local piece = make("Frame", parent, {
			Name = "Confetti",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(0, 0),
			Visible = false,
			ZIndex = 8,
		})
		local face = make("Frame", piece, {
			BackgroundColor3 = tones[(index - 1) % #tones + 1],
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -6, 1, -6),
		})
		if index % 2 == 1 then
			make("UICorner", piece, { CornerRadius = UDim.new(0.5, 0) })
			make("UICorner", face, { CornerRadius = UDim.new(0.5, 0) })
		end
		pieces[index] = {
			piece = piece,
			face = face,
			dx = math.cos(angle) * reach,
			dy = math.sin(angle) * reach * 0.6,
		}
	end
	Poster.run(key, 1.2, function(t: number)
		local share = keyframes(CF_SHARE, t, PosterEase.easeOut)
		local fall = keyframes(CF_FALL, t, PosterEase.easeOut)
		local turn = keyframes(CF_TURN, t, PosterEase.easeOut)
		local size = 26 * keyframes(CF_SIZE, t, PosterEase.easeOut)
		local clear = 1 - keyframes(CF_SEEN, t, PosterEase.easeOut)
		for _, p in pieces do
			p.piece.Visible = true
			p.piece.Position = UDim2.fromOffset(x + p.dx * share, y + p.dy * share + fall)
			p.piece.Size = UDim2.fromOffset(size, size)
			p.piece.Rotation = turn
			p.piece.BackgroundTransparency = clear
			p.face.BackgroundTransparency = clear
		end
	end, function()
		for _, p in pieces do
			p.piece:Destroy()
		end
	end, 0.3)
end

-- A stamp: an ink plate with words that lands turned and three times its size and settles on the spring (the
-- mockup's `stamp`, 0.55 s), fading in as it lands. `fades` lists what to fade, as { instance, property }.
-- It is hidden until its moment.
local function stamp(
	key: any,
	plate: Frame,
	scale: UIScale,
	restTurn: number,
	wait: number,
	fades: { { any } }
)
	plate.Visible = false
	local solid = false
	Poster.run(key, 0.55, function(t: number)
		local s = spring(t)
		plate.Visible = true
		if not solid then
			local clear = 1 - math.clamp(s, 0, 1)
			for _, fade in fades do
				fade[1][fade[2]] = clear
			end
			solid = clear <= 0
		end
		scale.Scale = 3.2 + (1 - 3.2) * s
		plate.Rotation = -34 + (restTurn + 34) * s
	end, nil, wait)
end

-- The stage every announcement stands on: a holder at the top centre scaled with the HUD, and inside it a
-- plain group that turns and scales about the announcement's centre. `box` is the announcement's own box; its
-- top-left is at `origin` inside the group.
local function stage(
	name: string,
	top: number,
	box: Vector2,
	extra: number
): (Frame, Frame, UIScale, Vector2)
	Callouts.start()
	local scale = hudScale() * extra
	local holder = make("Frame", gui, {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, (top + box.Y / 2) * scale),
		Size = UDim2.fromOffset(box.X, box.Y),
	})
	make("UIScale", holder, { Scale = scale })
	local room = Vector2.new(box.X + 1000, box.Y + 440)
	local group = make("Frame", holder, {
		Name = "Group",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(room.X, room.Y),
	})
	local groupScale = make("UIScale", group, {})
	return holder, group, groupScale, (room - box) / 2
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

-- THE ULTIMATE ---------------------------------------------------------------------------------------

-- How wide Roblox sets one of the big 74 px letters. Asked once per letter; it can wait a moment the first time.
local letterWidths: { [string]: number } = {}
local function letterWidth(letter: string): number
	local known = letterWidths[letter]
	if known then
		return known
	end
	local params = Instance.new("GetTextBoundsParams")
	params.Text = letter
	params.Font = Font.new(Tokens.family.poster, Enum.FontWeight.Bold)
	params.Size = Poster.px(74, "display")
	params.Width = 1000
	local ok, bounds = pcall(function()
		return TextService:GetTextBoundsAsync(params)
	end)
	local width = if ok then bounds.X else 74 * 0.5
	letterWidths[letter] = width
	return width
end

local WORD = "ULTIMATE"
local UC_TURN =
	{ { 0, 0 }, { 0.4, 0 }, { 0.46, -4 }, { 0.53, 3 }, { 0.6, 0 }, { 0.8, 0 }, { 1, 20 } }
local UC_SIZE =
	{ { 0, 1 }, { 0.4, 1 }, { 0.46, 1.1 }, { 0.53, 0.97 }, { 0.6, 1 }, { 0.8, 1 }, { 1, 0.15 } }
local UC_AWAY = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } }

--- "ULTIMATE ... READY": the notice for earning your ultimate, in `tone` (your class colour). `key` is the key
--- cap to show beside READY ("G"), or nil on touch. `done` runs as it leaves, when the badge should take over.
function Callouts.ultimate(tone: Color3, key: string?, done: (() -> ())?)
	local line = VoiceLines.Lines["ultimate-ready"]
	local seconds = math.max(1.7, (0.12 + line.seconds) / 0.8)
	-- every letter's width is known before anything is on screen, so nothing waits half-built
	for index = 1, #WORD do
		letterWidth(string.sub(WORD, index, index))
	end
	serial += 1
	local id = `ultimate{serial}`
	local box = Vector2.new(540, 82)
	local holder, group, groupScale, origin = stage("Ultimate", 112, box, 1)
	local ink, paper, coin = colour("ink.900"), colour("ivory.50"), colour("gold.400")

	-- the streak behind the letters: 330 past them each side, growing from the right in 0.22 s
	local setStreak =
		band(group, origin.X - 330, origin.Y + 20, box.X + 660, 68, 6, tone, ink, true)
	setStreak(0)
	Poster.run(`{id}streak`, 0.22, function(t: number)
		setStreak(streakCurve(t))
	end)

	-- the letters: a row turned 4 degrees, each a cut-out card that drops in on the spring, one after another
	local row = make("Frame", group, {
		Name = "Letters",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(origin.X, origin.Y),
		Size = UDim2.fromOffset(box.X, box.Y),
		Rotation = -4,
		ZIndex = 2,
	})
	make("UIListLayout", row, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})
	for index = 1, #WORD do
		local letter = string.sub(WORD, index, index)
		local even = index % 2 == 0
		-- the card is as wide as its letter plus the mockup's 9 of padding and 4 of border each side
		local slot = make("Frame", row, {
			Name = letter,
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.fromOffset(letterWidth(letter) + 26, box.Y),
		})
		local restTurn = if even then 5 else 0
		local restY = if even then 4 else 0
		local card = make("Frame", slot, {
			Name = "Card",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, restY),
			Size = UDim2.fromScale(1, 1),
			Rotation = restTurn,
			Visible = false,
		})
		local cardScale = make("UIScale", card, {})
		local face = make("Frame", card, {
			BackgroundColor3 = if index % 3 == 0 then coin elseif even then tone else paper,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 1, -8),
		})
		local glyph = Poster.text(card, "display", 74, "ink.900", {
			Size = UDim2.fromScale(1, 1),
			Text = letter,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 2,
		})
		local solid = false
		Poster.run(`{id}letter{index}`, 0.6, function(t: number)
			local s = spring(t)
			card.Visible = true
			if not solid then
				local clear = 1 - math.clamp(s, 0, 1)
				card.BackgroundTransparency = clear
				face.BackgroundTransparency = clear
				glyph.TextTransparency = clear
				solid = clear <= 0
			end
			card.Position = UDim2.new(0.5, 0, 0.5, -170 + (restY + 170) * s)
			card.Rotation = -28 + (restTurn + 28) * s
			cardScale.Scale = 1.7 + (1 - 1.7) * s
		end, nil, 0.18 + (index - 1) * 0.045)
	end

	-- READY and the key: an ink stamp 40 past the row's bottom-right corner
	local ready = make("Frame", group, {
		Name = "Ready",
		BackgroundColor3 = ink,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 53),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 4,
	})
	local readyScale = make("UIScale", ready, {})
	make("UIPadding", ready, { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) })
	make("UIListLayout", ready, {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	})
	local readyWord = Poster.text(ready, "display", 30, "ivory.50", {
		LayoutOrder = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "READY",
	})
	local readyFades: { { any } } =
		{ { ready, "BackgroundTransparency" }, { readyWord, "TextTransparency" } }
	local readyWidth = 160
	if key then
		local cap = make("Frame", ready, {
			Name = "Cap",
			BackgroundColor3 = paper,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Size = UDim2.fromOffset(42, 30),
		})
		local capWord = Poster.text(cap, "display", 18, "ink.900", {
			Size = UDim2.fromScale(1, 1),
			Text = key,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		table.insert(readyFades, { cap, "BackgroundTransparency" })
		table.insert(readyFades, { capWord, "TextTransparency" })
	else
		readyWidth = 108
	end
	-- its right edge is 40 past the row's, its bottom 40 below
	ready.Position =
		UDim2.fromOffset(origin.X + box.X + 40 - readyWidth / 2, origin.Y + box.Y + 40 - 53 / 2)
	stamp(`{id}ready`, ready, readyScale, -8, 0.62, readyFades)

	confetti(holder, `{id}confetti`, box.X / 2 + 13, 44 + 13, 18, 170, 360, { coin, tone, paper })
	Callouts.edges(tone)
	task.delay(0.12, Callouts.speak, "ultimate-ready")

	-- the whole notice: holds, gives one kick, holds, then flies down and right toward the skills and is gone
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
		-- no motion: everything above is already at rest; it stays for its line and goes
		task.delay(seconds * 0.8, leave)
		return
	end
	local canvas: CanvasGroup? = nil
	Poster.run(id, seconds, function(t: number)
		local away = keyframes(UC_AWAY, t, ease)
		if away > 0 and not canvas then
			canvas = toCanvas(group)
		end
		local moving: GuiObject = canvas or group
		moving.Rotation = keyframes(UC_TURN, t, ease)
		groupScale.Scale = keyframes(UC_SIZE, t, ease)
		moving.Position = UDim2.new(0.5, box.X * 0.55 * away, 0.5, 300 * away)
		if canvas then
			canvas.GroupTransparency = away
		end
	end, leave)
end

-- THE LAST PLAYERS -----------------------------------------------------------------------------------

-- each count: its number's box in the mockup, its cell in the sheet, the bar's colour, the words
local LAST = {
	[5] = {
		box = Vector2.new(117, 219),
		cell = 0,
		tone = "gold.400",
		words = "FIGHTERS LEFT",
		width = 306,
	},
	[4] = {
		box = Vector2.new(121, 219),
		cell = 1,
		tone = "gold.400",
		words = "FIGHTERS LEFT",
		width = 306,
	},
	[3] = {
		box = Vector2.new(131, 242),
		cell = 2,
		tone = "danger.600",
		words = "FIGHTERS LEFT",
		width = 306,
	},
	[2] = {
		box = Vector2.new(149, 276),
		cell = 3,
		tone = "danger.600",
		words = "FINAL TWO",
		width = 231,
	},
}
local LC_AWAY = { { 0, 0 }, { 0.74, 0 }, { 1, 1 } }
local SHAKE = { { 0, 0 }, { 0.2, -14 }, { 0.4, 12 }, { 0.6, -8 }, { 0.8, 5 }, { 1, 0 } }

--- Whether a count gets a popup (5, 4, 3 and 2).
function Callouts.hasLast(count: number): boolean
	return LAST[count] ~= nil
end

--- The last-players popup for `count` standing. `small` is the phone size. `done` runs as it leaves, when the
--- strip's count should bump.
function Callouts.last(count: number, small: boolean, done: (() -> ())?)
	local spec = LAST[count]
	if not spec then
		if done then
			done()
		end
		return
	end
	local key = VoiceLines.Last[count]
	local line = VoiceLines.Lines[key]
	local seconds = math.max(1.7, (0.1 + line.seconds) / 0.74)
	serial += 1
	local id = `last{serial}`
	local box = Vector2.new(spec.width, spec.box.Y - 34 + 77)
	local holder, group, groupScale, origin =
		stage("LastPlayers", 84, box, if small then 170 / 230 else 1)
	local ink = colour("ink.900")
	local tone = colour(spec.tone)

	-- the bar behind the number: 460 past the box each side, a third of the way down, growing from the left
	local setBar =
		band(group, origin.X - 460, origin.Y + box.Y * 0.34, box.X + 920, 98, 7, ink, tone, false)
	setBar(0)
	Poster.run(`{id}bar`, 0.22, function(t: number)
		setBar(streakCurve(t))
	end)

	-- the number: slams in 4.5 times its size, turned, and settles on the spring
	local sheet = Shapes.last
	local number = make("ImageLabel", group, {
		Name = "Number",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(origin.X + box.X / 2, origin.Y + spec.box.Y / 2),
		Size = UDim2.fromOffset(sheet.cell.X, sheet.cell.Y),
		Image = Shapes.ids.last,
		ImageRectOffset = Vector2.new(spec.cell * sheet.cell.X, 0),
		ImageRectSize = sheet.cell,
		Visible = false,
		ZIndex = 2,
	})
	local numberScale = make("UIScale", number, {})
	Poster.run(`{id}number`, 0.7, function(t: number)
		local s = spring(t)
		number.Visible = true
		number.ImageTransparency = 1 - math.clamp(s, 0, 1)
		numberScale.Scale = 4.5 + (1 - 4.5) * s
		number.Rotation = -22 * (1 - s)
	end)

	-- the words: an ink plate with the bar's colour under it, stamped on 34 units up into the number
	local words = make("Frame", group, {
		Name = "Words",
		BackgroundColor3 = tone,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(origin.X + box.X / 2, origin.Y + spec.box.Y - 34 + 77 / 2),
		Size = UDim2.fromOffset(spec.width, 77),
		ZIndex = 3,
	})
	local wordsScale = make("UIScale", words, {})
	local plate = make("Frame", words, {
		BackgroundColor3 = ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -7),
	})
	local wordsText = Poster.text(plate, "display", 42, "ivory.50", {
		Size = UDim2.fromScale(1, 1),
		Text = spec.words,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	stamp(`{id}words`, words, wordsScale, -4, 0.28, {
		{ words, "BackgroundTransparency" },
		{ plate, "BackgroundTransparency" },
		{ wordsText, "TextTransparency" },
	})

	if count == 2 then
		confetti(
			holder,
			`{id}confetti`,
			box.X / 2 + 13,
			110 + 13,
			20,
			200,
			420,
			{ colour("gold.400"), tone, colour("ivory.50") }
		)
	end
	Callouts.edges(tone)
	task.delay(0.1, Callouts.speak, key)

	-- the whole popup: holds for its line, then flies up into the strip and is gone; at 2 it shakes first
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
		task.delay(seconds * 0.74, leave)
		return
	end
	local canvas: CanvasGroup? = nil
	Poster.run(id, seconds, function(t: number)
		local away = keyframes(LC_AWAY, t, ease)
		local shake = 0
		if count == 2 then
			local into = (t * seconds - 0.1) / 0.4
			if into > 0 and into < 1 then
				shake = keyframes(SHAKE, into, ease)
			end
		end
		if away > 0 and not canvas then
			canvas = toCanvas(group)
		end
		local moving: GuiObject = canvas or group
		moving.Position = UDim2.new(0.5, shake, 0.5, -170 * away)
		groupScale.Scale = 1 + (0.15 - 1) * away
		if canvas then
			canvas.GroupTransparency = away
		end
	end, leave)
end

return Callouts
