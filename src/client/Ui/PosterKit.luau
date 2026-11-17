--!strict
-- PosterKit - the fight-poster lobby's building blocks, each the mockup's own (UI Research/
-- fight-poster-prototype.html): a rough-cut shape with an ink outline and a hard shadow (`.cut`), the way it
-- answers a press (`.press`), a key cap (`.cap`, `kbd`), the slanted ink row of a skill or a control (`.sk`), the
-- small PLANNED tag (`.tag`) and the pop a tile makes when a page is drawn (`tpop`). Sizes are the mockup's pixels;
-- the screens that use these scale as a whole.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local HudTheme = require(script.Parent.HudTheme)
local Poster = require(script.Parent.Poster)
local Shapes = require(script.Parent.Shapes)
local UiSound = require(script.Parent.UiSound)

local PosterKit = {}

local colour = Tokens.colour
local TAN6 = math.tan(math.rad(6))

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
	Window = 0.9,
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
	local function go(toSize: number, toTurn: number, seconds: number)
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
			UiSound.hover()
			go(cut.restScale * 1.07, cut.restTurn, 0.55)
		end)
		button.MouseLeave:Connect(function()
			go(cut.restScale, cut.restTurn, 0.55)
		end)
		button.MouseButton1Down:Connect(function()
			UiSound.play("ui_press")
			Poster.stop(cut)
			cut.scale.Scale = cut.restScale * 0.94
		end)
		button.MouseButton1Up:Connect(function()
			go(cut.restScale, cut.restTurn, 0.55)
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

--- A slanted ink row (`.sk`): a key cap when `key` is given, a name in Oswald, a smaller line under it when
--- `detail` is given, and `right` (a cooldown, PLANNED, ON) at its right end. `height` is 46 for a bare row, 72
--- with one line of detail, 98 with two.
function PosterKit.row(
	parent: Instance?,
	width: number,
	height: number,
	key: string?,
	name: string,
	detail: string?,
	right: string?
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
	-- the plate leans 6 degrees; its box is that much wider than the row's contents
	local lean = height * TAN6
	local plate = Shapes.slant(body, "ink.900", lean, {
		Name = "Plate",
		Position = UDim2.fromOffset(-lean / 2, 0),
		Size = UDim2.new(1, lean, 1, 0),
	})
	local x = 12
	if key then
		-- a cap is as wide as its key (about 8.7 units a letter at this size) and never under 42; the name
		-- starts 10 past it
		local capWidth = math.max(42, 12 + 8.7 * #key)
		PosterKit.cap(body, key, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.fromOffset(capWidth, 30),
			AutomaticSize = Enum.AutomaticSize.None,
			ZIndex = 2,
		})
		x = 12 + capWidth + 10
	end
	Poster.text(body, "display", 20, "ivory.50", {
		Name = "Name",
		Position = UDim2.fromOffset(x, 8),
		Size = UDim2.new(1, -x - 70, 0, 30),
		Text = string.upper(name),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
	})
	if detail and detail ~= "" then
		-- 17, not the mockup's 15: the window is drawn smaller than the mockup's and this line was hard to read
		-- (owner, 2026-11-17)
		local small = Poster.text(body, "label", 17, "ivory.50", {
			Name = "Detail",
			Position = UDim2.fromOffset(x, 38),
			Size = UDim2.new(1, -x - 14, 0, height - 46),
			Text = detail,
			TextTransparency = 0.1,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,
		})
		-- the mockup's small line is Titillium Regular; SemiBold here, because the thin weight reads soft when small
		small.FontFace = Font.new(Tokens.family.text, Enum.FontWeight.SemiBold)
	end
	local rightLabel = Poster.text(body, "display", 18, "ivory.50", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(120, 26),
		Text = right or "",
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
	})
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
	local function go(to: number)
		local from = row.scale.Scale
		Poster.run(row, 0.55, function(t: number)
			row.scale.Scale = from + (to - from) * PosterEase.spring(t)
		end)
	end
	button.MouseEnter:Connect(function()
		UiSound.hover()
		go(1.03)
	end)
	button.MouseLeave:Connect(function()
		go(1)
	end)
	button.MouseButton1Down:Connect(function()
		UiSound.play("ui_press")
		Poster.stop(row)
		row.scale.Scale = 0.97
	end)
	button.MouseButton1Up:Connect(function()
		go(1)
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
