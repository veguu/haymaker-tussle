--!strict
-- PosterKit - the fight-poster lobby's building blocks, each the mockup's own (UI Research/
-- fight-poster-prototype.html): a rough-cut shape with an ink outline and a hard shadow (`.cut`), the way it
-- answers a press (`.press`), a key cap (`.cap`, `kbd`), the slanted ink row of a skill or a control (`.sk`), the
-- small PLANNED tag (`.tag`) and the pop a tile makes when a page is drawn (`tpop`). Sizes are the mockup's pixels;
-- the screens that use these scale as a whole.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local HudTheme = require(script.Parent.HudTheme)
local Poster = require(script.Parent.Poster)
local Shapes = require(script.Parent.Shapes)
local UiSound = require(script.Parent.UiSound)

local PosterKit = {}

local colour = Tokens.colour

function PosterKit.make(class: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end
local make = PosterKit.make

-- How big the lobby's pieces are against the mockup's own sizes (owner, 2026-11-17: at the mockup's sizes
-- everything took too much of the screen). The window is the big one, so it gives the most; the strips are the
-- lobby's buttons, so they give less and never go under 46 px tall.
PosterKit.Fit = {
	Window = 1, -- (0.9 until 2026-11-18: the top strip shrank and moved up to give the window this room)
	WindowMin = 0.7,
	WindowMax = 1.2,
	Nav = 0.85,
	NavMin = 0.62,
	Button = 0.76, -- the fight's MENU button never goes under 44 px
}

export type Stage = {
	view: Vector2, -- the whole screen
	top: number, -- where the stage starts: the height of Roblox's own top bar
	scale: number, -- the screen UNDER the top bar against the mockup's 1280 x 720
	hud: number, -- the fight HUD's scale (the strip, the tiles, the plate)
	nav: number, -- the menu strips', the coins' and the MENU button's scale
}

--- The lobby's stage. The mockup is drawn for 1280 x 720 with nothing above it; in the game Roblox's top bar is
--- above it, so the stage is the screen under that bar.
function PosterKit.stage(): Stage
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local inset = GuiService:GetGuiInset()
	local scale = math.clamp(math.min(view.X / 1280, (view.Y - inset.Y) / 720), 0.5, 1.35)
	return {
		view = view,
		top = inset.Y,
		scale = scale,
		hud = HudTheme.scaleFor(view),
		nav = math.max(scale * PosterKit.Fit.Nav, PosterKit.Fit.NavMin),
	}
end

--- The stage's scale alone.
function PosterKit.lobbyScale(): number
	return PosterKit.stage().scale
end

export type Cut = {
	root: Frame, -- place and size this; it scales and turns about its centre
	body: Frame, -- everything drawn, on one layer: the idle drift moves this (Ui/Drift), never the root
	shape: Frame, -- the shadow, the outline and the fill: what may turn (no text on it)
	scale: UIScale,
	fill: ImageLabel,
	line: ImageLabel,
	face: Frame, -- put the contents here
	button: TextButton?,
	restScale: number, -- where it settles when nothing is touching it (a picked thing may sit larger, tipped)
	restTurn: number,
}

--- A rough-cut shape: `shape` (a name in Shapes.ids) with a 4-unit ink outline, filled `fill`, and when `shadow`
--- is given a hard ink shadow that far down-right.
function PosterKit.cut(
	parent: Instance?,
	shape: string,
	size: Vector2,
	fill: Color3,
	shadow: Vector2?,
	props: { [string]: any }?
): Cut
	local root = make("Frame", nil, {
		Name = "Cut",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
	})
	local scale = make("UIScale", root, {})
	local body = make("Frame", root, {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	local outline = make("Frame", body, {
		Name = "Shape",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	if shadow then
		Shapes.image(outline, shape, "ink.900", {
			Name = "Shadow",
			Position = UDim2.fromOffset(shadow.X, shadow.Y),
			ImageTransparency = 0.15,
		})
	end
	local line = Shapes.image(outline, shape, "ink.900", { Name = "Line", ZIndex = 1 })
	local inner = Shapes.image(outline, shape, "ivory.50", {
		Name = "Fill",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		ZIndex = 2,
	})
	inner.ImageColor3 = fill
	local face = make("Frame", body, {
		Name = "Face",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
	for key, value in props or {} do
		(root :: any)[key] = value
	end
	root.Parent = parent
	return {
		root = root,
		body = body,
		shape = outline,
		scale = scale,
		fill = inner,
		line = line,
		face = face,
		restScale = 1,
		restTurn = 0,
	}
end

--- Puts a cut's centre where its top-left would be at `x`, `y` (cuts are anchored at their centre, to turn there).
function PosterKit.place(cut: Cut, x: number, y: number)
	local size = cut.root.Size
	cut.root.Position = UDim2.fromOffset(x + size.X.Offset / 2, y + size.Y.Offset / 2)
end

--- Makes a cut pressable, as the mockup's `.press`: it grows and tips a little under the pointer, squashes when
--- held, and springs back. `onPress` runs when it is activated. Returns the button.
function PosterKit.pressable(cut: Cut, onPress: () -> (), still: boolean?): TextButton
	local button = make("TextButton", cut.root, {
		Name = "Press",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 9,
	})
	cut.button = button
	local size, turn = 1, 0
	local over = false -- the pointer is on it
	-- Its entrance pop (PosterKit.pop) writes the same scale and turn under another key: a pointer arriving
	-- during the pop had two runs writing them in turn, frame by frame, and the tile shivered (found reading
	-- the code, 2026-11-18). The first answer to the pointer ends the pop where it is.
	local function endPop()
		if Poster.running(cut.root) then
			Poster.stop(cut.root)
			cut.root.Visible = true
		end
	end
	local function go(toSize: number, toTurn: number, seconds: number)
		endPop()
		local fromSize, fromTurn = cut.scale.Scale, cut.root.Rotation
		size, turn = toSize, toTurn
		Poster.run(cut, seconds, function(t: number)
			local s = PosterEase.spring(t)
			cut.scale.Scale = fromSize + (size - fromSize) * s
			cut.root.Rotation = fromTurn + (turn - fromTurn) * s
		end)
	end
	-- `still`: it only answers the press (a tile that is already picked keeps its own tilt)
	if not still then
		button.MouseEnter:Connect(function()
			over = true
			UiSound.hover()
			go(cut.restScale * 1.07, cut.restTurn, 0.55)
		end)
		button.MouseLeave:Connect(function()
			over = false
			go(cut.restScale, cut.restTurn, 0.55)
		end)
		button.MouseButton1Down:Connect(function()
			UiSound.play("ui_press")
			endPop()
			Poster.stop(cut)
			cut.scale.Scale = cut.restScale * 0.94
		end)
		button.MouseButton1Up:Connect(function()
			-- back to the size it has under the pointer, not to rest: let go with the pointer still on it, it
			-- used to shrink to rest and stay there, looking un-hovered until the pointer left and came back
			go(cut.restScale * (if over then 1.07 else 1), cut.restTurn, 0.55)
		end)
	end
	button.Activated:Connect(onPress)
	return button
end

--- The pop a tile, slab or row makes when its page is drawn (`tpop`): from a fifth of its size and turned 18
--- degrees, on the spring over 0.6 s, after `wait`, settling at `restScale` and `restTurn` (1 and 0 if not given).
function PosterKit.pop(
	root: GuiObject,
	scale: UIScale,
	wait: number,
	restScale: number?,
	restTurn: number?
)
	root.Visible = false
	Poster.run(root, 0.6, function(t: number)
		local s = PosterEase.spring(t)
		root.Visible = true
		local size, turn = restScale or 1, restTurn or 0
		scale.Scale = math.max(0.2 + (size - 0.2) * s, 0.01)
		root.Rotation = -18 + (turn + 18) * s
	end, nil, wait)
end

--- A key cap: cream with ink Oswald lettering, at least 30 wide plus its padding, 30 tall.
function PosterKit.cap(parent: Instance?, key: string, props: { [string]: any }?): Frame
	local cap = make("Frame", nil, {
		Name = "Cap",
		BackgroundColor3 = colour("ivory.50"),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(42, 30),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	make("UIPadding", cap, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	make("UIListLayout", cap, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	Poster.text(cap, "display", 18, "ink.900", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = key,
	})
	for name, value in props or {} do
		(cap :: any)[name] = value
	end
	cap.Parent = parent
	return cap
end

--- The small ink tag (PLANNED): cream Titillium on ink, turned 2 degrees.
function PosterKit.tag(parent: Instance?, words: string, props: { [string]: any }?): TextLabel
	local tag = Poster.text(nil, "label", 15, "ivory.50", {
		Name = "Tag",
		BackgroundColor3 = colour("ink.900"),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 27),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = 0, -- straight: small text turned even a degree is drawn soft (measured 2026-11-17)
		Text = string.upper(words),
	})
	make("UIPadding", tag, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	for name, value in props or {} do
		(tag :: any)[name] = value
	end
	tag.Parent = parent
	return tag
end

export type Row = {
	root: Frame,
	body: Frame, -- everything drawn: the idle drift moves this (Ui/Drift)
	scale: UIScale,
	plate: Frame,
	right: TextLabel,
	button: TextButton?,
}

export type Lettering = { frame: Frame, face: TextLabel, shadow: TextLabel }

--- POSTER LETTERING with nothing behind it: Oswald in `tone` with an ink outline and a hard ink shadow (the same
--- word in ink, a little right and down), as a move's name is drawn. It is how words and numbers stand on the
--- world or on the window's field now that NO slanted ink plate is left anywhere (the owner, 2026-11-18, with
--- pictures of the round strip and the knockout feed: "i HATE this style, it doesn't even represent the rest of
--- the main ui ... for EVERYTHING"). `css` is the mockup's pixel size. The outline stays under 7 % of the letter,
--- where it starts to close a letter's counters (vault: "UIStroke on Text - Glyph Counters and the Stroke Ratio").
--- The frame is as wide as its word; change the word with PosterKit.setLettering.
function PosterKit.lettering(
	parent: Instance?,
	css: number,
	tone: string,
	text: string,
	props: { [string]: any }?
): Lettering
	local frame = make("Frame", nil, {
		Name = "Lettering",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, math.ceil(css * 1.3)),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	local drop = math.max(1, math.floor(css * 0.08 + 0.5))
	local line = if css >= 40 then 2.5 elseif css >= 28 then 2 else 1.5
	local function word(name: string, wordTone: string, x: number, y: number, z: number): TextLabel
		local label = Poster.text(frame, "display", css, wordTone, {
			Name = name,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			ZIndex = z,
		})
		make(
			"UIStroke",
			label,
			{ Color = colour("ink.900"), Thickness = line, LineJoinMode = Enum.LineJoinMode.Round }
		)
		return label
	end
	local shadow = word("Shadow", "ink.900", drop, drop + 1, 1)
	local face = word("Face", tone, 0, 0, 2)
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return { frame = frame, face = face, shadow = shadow }
end

--- Changes a lettering's word.
function PosterKit.setLettering(lettering: Lettering, text: string)
	lettering.face.Text = text
	lettering.shadow.Text = text
end

--- A SMALL ROUGH-CUT TILE WITH WORDS ON IT: the key tile's shape (ink edge, hard ink shadow) in any fill, as wide
--- as its words. What a status word stands on where a slanted ink plate used to be: NEXT ROUND, ROUND OVER,
--- KNOCKED OUT, SPECTATING. `height` 28 and under gets the thinner edge. Its width is worked out from the words
--- (left to AutomaticSize, a shape that fills its box makes the box grow without end; first seen 2026-11-17).
function PosterKit.chip(
	parent: Instance?,
	words: string,
	css: number,
	fill: string,
	tone: string,
	height: number,
	props: { [string]: any }?
): Frame
	local size = Poster.px(css, "display")
	-- (Enum.Font.Oswald is the regular face; the Bold one is about a tenth wider)
	local wide = TextService:GetTextSize(words, size, Enum.Font.Oswald, Vector2.new(4000, 400)).X
		* 1.1
	local small = height <= 28
	local edge = if small then 2 else 3
	local pad = if small then 9 else 14
	local chip = make("Frame", nil, {
		Name = "Chip",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(math.ceil(wide) + 2 * pad, height),
	})
	Shapes.image(
		chip,
		"tile",
		"ink.900",
		{ Name = "Shadow", Position = UDim2.fromOffset(edge, edge + 1) }
	)
	Shapes.image(chip, "tile", "ink.900", { Name = "Line", ZIndex = 2 })
	Shapes.image(chip, "tile", fill, {
		Name = "Fill",
		Position = UDim2.fromOffset(edge, edge),
		Size = UDim2.new(1, -2 * edge, 1, -2 * edge),
		ZIndex = 3,
	})
	-- (straight: small text turned even a degree is drawn soft)
	Poster.text(chip, "display", css, tone, {
		Name = "Words",
		Size = UDim2.fromScale(1, 1),
		Text = words,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
	})
	for key, value in props or {} do
		(chip :: any)[key] = value
	end
	chip.Parent = parent
	return chip
end

-- A row's note: the mockup's 21 px drawn at 19, as the window itself is drawn smaller than the mockup's.
local NOTE = 19
local NOTE_INDENT = 26 -- the hooked arrow and its gap

-- Where a row's words start: past its key tile (as wide as its key, about 9 units a letter, never under 46).
local function rowLeft(key: string?): number
	return if key then 4 + math.max(46, 20 + 9 * #key) + 12 else 6
end

--- How tall a row must be for its note: 46 bare, and one line's pitch more for every line the note takes at
--- that width. Callers lay their rows out with this, so no line is ever dropped.
function PosterKit.rowHeight(width: number, key: string?, detail: string?): number
	if not detail or detail == "" then
		return 46
	end
	local lines = Poster.noteLines(detail, NOTE, width - rowLeft(key) - NOTE_INDENT - 14)
	return 46 + Poster.notePitch(NOTE) * lines
end

--- A row of words with NO FRAME (the owner, 2026-11-18: "having a frame isn't high quality, especially for the
--- moves section"; seen on the mockup's Moves page first, `.mv`, then "apply that same new style to anything
--- that's applicable"). Nothing is behind the words; what keeps them readable on the window's drifting field is:
---   the KEY   on a small cream rough-cut tile with an ink edge and a hard ink shadow (when `key` is given);
---   the NAME  as poster lettering: cream Oswald with an ink outline and a hard ink shadow. The outline is 1.5
---             units on a 35-unit letter, under the 7 % at which an outline starts to close a letter's counters;
---   the NOTE  under it (`detail`): the coach's handwriting (Poster.note), ink, with a hooked marker arrow
---             leading down to it from the name (ui-19d; until then plain bold Titillium);
---   `right`   a word standing alone at the right end (PLANNED): a note with a hand-drawn ring round it;
---   `cooldown` the cooldown counter at the right end: a stopwatch, the seconds as poster lettering in coin
---             yellow, SEC small in ink. No plate behind it, and no word: the owner, in order, "hard to tell what
---             number it is" (handwritten), "i dont want it to be the same style" (a tile like the key's), "DONT
---             MAKE IT A COMPLETELY DIFFERENT STYLE ... obvious that its the cooldown counter" (a starburst),
---             "i dont like the frame" (a slanted plate).
--- `height` comes from PosterKit.rowHeight.
function PosterKit.row(
	parent: Instance?,
	width: number,
	height: number,
	key: string?,
	name: string,
	detail: string?,
	right: string?,
	cooldown: string?
): Row
	local root = make("Frame", nil, {
		Name = "Row",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
	})
	local scale = make("UIScale", root, {})
	local body = make("Frame", root, {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	-- (kept so a Row still has its `plate`: an empty box where the ink plate was)
	local plate = make("Frame", body, {
		Name = "Plate",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	local x = rowLeft(key)
	if key then
		-- a tile is as wide as its key (about 9 units a letter at this size) and never under 46; the name
		-- starts 12 past it (rowLeft)
		local tileWidth = x - 16
		local tile = make("Frame", body, {
			Name = "Key",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.fromOffset(tileWidth, 40),
			ZIndex = 2,
		})
		Shapes.image(
			tile,
			"tile",
			"ink.900",
			{ Name = "Shadow", Position = UDim2.fromOffset(3, 4) }
		)
		Shapes.image(tile, "tile", "ink.900", { Name = "Line", ZIndex = 2 })
		Shapes.image(tile, "tile", "ivory.50", {
			Name = "Fill",
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			ZIndex = 3,
		})
		-- (straight: small text turned even a degree is drawn soft)
		Poster.text(tile, "display", 18, "ink.900", {
			Name = "Letter",
			Size = UDim2.fromScale(1, 1),
			Text = key,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 4,
		})
	end
	local hasRight = (right ~= nil and right ~= "") or cooldown ~= nil
	local nameProps = {
		Position = UDim2.fromOffset(x, 3),
		Size = UDim2.new(1, -x - (if hasRight then 112 else 12), 0, 34),
		Text = string.upper(name),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	-- the hard shadow: the same word in ink, 2 right and 3 down, under the cream one
	local shadow = Poster.text(body, "display", 24, "ink.900", nameProps)
	shadow.Name = "NameShadow"
	shadow.Position = UDim2.fromOffset(x + 2, 6)
	shadow.ZIndex = 2
	make(
		"UIStroke",
		shadow,
		{ Color = colour("ink.900"), Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round }
	)
	local label = Poster.text(body, "display", 24, "ivory.50", nameProps)
	label.Name = "Name"
	label.ZIndex = 3
	make(
		"UIStroke",
		label,
		{ Color = colour("ink.900"), Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round }
	)
	if detail and detail ~= "" then
		Shapes.image(body, "noteArrow", "ink.900", {
			Name = "Arrow",
			Position = UDim2.fromOffset(x, 33),
			Size = UDim2.fromOffset(22, 20),
			ZIndex = 2,
		})
		Poster.note(body, NOTE, {
			Name = "Detail",
			Position = UDim2.fromOffset(x + NOTE_INDENT, 37),
			Size = UDim2.new(1, -x - NOTE_INDENT - 14, 0, height - 34),
			Text = detail,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,
		})
	end
	-- the word at the right end, in the coach's hand with a ring drawn round it (the caller's word, written
	-- "Planned": capitals in this hand are hard to read)
	local word = if right and right ~= ""
		then string.upper(string.sub(right, 1, 1)) .. string.lower(string.sub(right, 2))
		else ""
	local wordWide = if word ~= ""
		then math.ceil(
			TextService:GetTextSize(
				word,
				Poster.notePx(NOTE),
				Enum.Font.Kalam,
				Vector2.new(4000, 400)
			).X * 1.08
		)
		else 0
	local rightLabel = Poster.note(body, NOTE, {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 5),
		Size = UDim2.fromOffset(wordWide + 28, 32),
		Text = word,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = word ~= "",
		ZIndex = 2,
	})
	Shapes.image(rightLabel, "noteRing", "ink.900", { Name = "Ring", ZIndex = 2 })
	if cooldown then
		local counter = make("Frame", body, {
			Name = "Cooldown",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 2),
			Size = UDim2.fromOffset(110, 36),
			ZIndex = 2,
		})
		make("UIListLayout", counter, {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
		Shapes.image(counter, "stopwatch", "ivory.50", {
			Name = "Stopwatch",
			ImageColor3 = Color3.new(1, 1, 1), -- its own colours
			LayoutOrder = 1,
			Size = UDim2.fromOffset(28, 28),
		})
		PosterKit.lettering(counter, 26, "gold.400", cooldown, { LayoutOrder = 2 })
		local unit = Poster.text(counter, "display", 13, "ink.900", {
			Name = "Unit",
			LayoutOrder = 3,
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = "SEC",
		})
		make("UIPadding", unit, { PaddingTop = UDim.new(0, 8) })
	end
	root.Parent = parent
	return { root = root, body = body, scale = scale, plate = plate, right = rightLabel }
end

--- Puts a row's centre where its top-left would be at `x`, `y`.
function PosterKit.placeRow(row: Row, x: number, y: number)
	local size = row.root.Size
	row.root.Position = UDim2.fromOffset(x + size.X.Offset / 2, y + size.Y.Offset / 2)
end

--- Makes a row pressable: the same answer to a press as a cut, a little gentler.
function PosterKit.pressRow(row: Row, onPress: () -> ()): TextButton
	local button = make("TextButton", row.root, {
		Name = "Press",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 9,
	})
	row.button = button
	local over = false
	-- (as PosterKit.pressable: the pointer ends the row's entrance pop, and letting go leaves it hovered)
	local function endPop()
		if Poster.running(row.root) then
			Poster.stop(row.root)
			row.root.Visible = true
			row.root.Rotation = 0
		end
	end
	local function go(to: number)
		endPop()
		local from = row.scale.Scale
		Poster.run(row, 0.55, function(t: number)
			row.scale.Scale = from + (to - from) * PosterEase.spring(t)
		end)
	end
	button.MouseEnter:Connect(function()
		over = true
		UiSound.hover()
		go(1.03)
	end)
	button.MouseLeave:Connect(function()
		over = false
		go(1)
	end)
	button.MouseButton1Down:Connect(function()
		UiSound.play("ui_press")
		endPop()
		Poster.stop(row)
		row.scale.Scale = 0.97
	end)
	button.MouseButton1Up:Connect(function()
		go(if over then 1.03 else 1)
	end)
	button.Activated:Connect(onPress)
	return button
end

--- A big word with an ink outline and a hard ink shadow (the window's title): two labels, the shadow under.
function PosterKit.title(
	parent: Instance?,
	css: number,
	props: { [string]: any }?
): (Frame, (string) -> ())
	local holder = make("Frame", nil, { Name = "Title", BackgroundTransparency = 1 })
	-- Roblox draws no text over 100, and 84 px of the mockup's Oswald is 123. So the word is set at 100 or under
	-- in a box that much smaller, and the box is scaled back up (first run, 2026-11-17: the title came out at
	-- four fifths of its size).
	local grow = math.max(1, Poster.px(css, "display") / 100)
	local inner = make("Frame", holder, {
		Name = "Inner",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1 / grow, 1 / grow),
	})
	make("UIScale", inner, { Scale = grow })
	local labels = {}
	for index, tone in { "ink.900", "ivory.50" } do
		local label = Poster.text(inner, "display", css / grow, tone, {
			Name = if index == 1 then "Shadow" else "Word",
			Position = if index == 1 then UDim2.fromOffset(7 / grow, 7 / grow) else UDim2.new(),
			Size = UDim2.fromScale(1, 1),
			ZIndex = index,
		})
		make("UIStroke", label, {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = colour("ink.900"),
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = 2.5 / grow,
		})
		labels[index] = label
	end
	-- The word itself comes from the lettering sheets (the browser's own drawing of it, outline and shadow and
	-- all); the two labels above only stand in for a word that isn't on a sheet yet.
	local drawn = Poster.word(holder, "titles", "", css, nil, { ZIndex = 3 })
	for name, value in props or {} do
		(holder :: any)[name] = value
	end
	holder.Parent = parent
	return holder,
		function(words: string)
			local upper = string.upper(words)
			local known = Poster.hasWord("titles", "title:" .. upper)
			Poster.setWord(drawn, if known then "title:" .. upper else "")
			inner.Visible = not known
			for _, label in labels do
				label.Text = upper
			end
		end
end

return PosterKit
