--!strict
-- QuestClipboard - the daily quests as a CLIPBOARD (the owner, 2026-11-20: "make it so it reflects like a
-- clipboard", after the website preview). Opened at the lobby's notice board; QuestController owns it.
--
-- A board with a metal clip holding one sheet of paper; on the paper DAILY QUESTS, a ruled line, and today's three
-- quests as a checklist: a tick box (green with a tick when done), what to do, a bar and the count, and on the right
-- the Coins, a green CLAIM button once it is done, or CLAIMED with the line crossed off. Built only from shapes the
-- UI already has (rounded rectangles, ink edges, a hard ink shadow, flat fills) and its two faces (Oswald for words
-- and numbers, the coach's Kalam for the small notes). Nothing turns at rest; it pops in fast. Sizes are in the
-- mockup's units (1280 x 720) and the whole board scales as one, like the menu window.
--
-- It stands clear of the lobby's menu strips on the left and its tool tiles on the right, so nothing overlaps.
-- The world behind it goes soft (a BlurEffect, skipped at the two lowest graphics levels, as the window does).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Callouts = require(script.Parent.Callouts)
local HudMotion = require(script.Parent.HudMotion)
local HudTheme = require(script.Parent.HudTheme)
local Poster = require(script.Parent.Poster)
local PosterKit = require(script.Parent.PosterKit)
local UiSound = require(script.Parent.UiSound)

local colour = Tokens.colour
local make = PosterKit.make

export type QuestView = {
	id: string,
	goal: number,
	progress: number,
	reward: number,
	claimed: boolean,
	text: string,
	progressText: string,
}

export type Handle = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	draw: () -> (),
}

local BOARD = Vector2.new(780, 650)
local SHADOW = 12
local CLIP_UP = 28 -- how far the clip stands above the board
local PAPER = { X = 28, Y = 66, Inset = 34, Top = 40 }
local ROW = { Top = 96, Pitch = 124, Height = 118, Bar = Vector2.new(270, 16), Count = 344 }
local INNER = BOARD.X - 2 * PAPER.X - 2 * PAPER.Inset -- the paper's writing width
-- room kept for the lobby's menu strips (left) and tool tiles (right), in their own units (NavController)
local NAV_RIGHT = 26 + 44 + 18 + 250 * 1.02 + 12
local TOOLS_LEFT = 22 + 94 + 8 + 16
local BLUR = { Size = 10, In = 0.25, Out = 0.18 }
-- room kept under the top strip or the fighters' row for the toast (MenuController.showToast: 44 tall at 1.3 x
-- the strips' scale, 10 below what is up there), so a toast never lies on the clipboard (seen 2026-11-20)
local TOAST_ROOM = 10 + 44 * 1.3 + 8

local function lowGraphics(): boolean
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and level >= 1 and level <= 2
end

-- a rounded box with an ink edge
local function box(
	parent: Instance,
	name: string,
	at: Vector2,
	size: Vector2,
	fill: Color3,
	corner: number,
	edge: number?
): Frame
	local frame = make("Frame", parent, {
		Name = name,
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
	})
	make("UICorner", frame, { CornerRadius = UDim.new(0, corner) })
	if edge then
		make("UIStroke", frame, { Color = colour("ink.900"), Thickness = edge })
	end
	return frame
end

-- a straight ink stroke from a to b (the tick's two legs), round-ended
local function stroke(parent: Instance, a: Vector2, b: Vector2, thick: number)
	local d = b - a
	local line = make("Frame", parent, {
		Name = "Stroke",
		BackgroundColor3 = colour("ink.900"),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(d.Magnitude + thick, thick),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
	})
	make("UICorner", line, { CornerRadius = UDim.new(1, 0) })
end

--- Builds the clipboard (hidden) under `playerGui`. `get` returns today's quests or nil, `secondsLeft` the time to
--- the next board, `claim(id)` asks the server, `onClosed` is told when it closes by itself or by the X.
local function new(
	playerGui: Instance,
	get: () -> { QuestView }?,
	secondsLeft: () -> number,
	claim: (string) -> (),
	onClosed: () -> ()
): Handle
	local gui = make("ScreenGui", playerGui, {
		Name = "HT_Quests",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 21, -- over the lobby strips (the menu window is 20; the two are never open together)
		Enabled = false,
	})
	local holder = make("Frame", gui, {
		Name = "Clipboard",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(BOARD.X, BOARD.Y),
	})
	local scaler = make("UIScale", holder, {})

	-- THE BOARD
	box(holder, "Shadow", Vector2.new(SHADOW, SHADOW), BOARD, colour("ink.900"), 20)
	box(holder, "Board", Vector2.zero, BOARD, colour("gold.600"), 20, 6)
	local paper = box(
		holder,
		"Paper",
		Vector2.new(PAPER.X, PAPER.Y),
		Vector2.new(BOARD.X - 2 * PAPER.X, BOARD.Y - PAPER.Y - PAPER.X),
		colour("ivory.50"),
		8,
		4
	)
	paper.ZIndex = 2

	-- THE CLIP: a ring with its hole, and the plate over the paper's top edge, with a highlight along it
	local metal = colour("violet.400")
	local ring = box(
		holder,
		"ClipRing",
		Vector2.new(BOARD.X / 2 - 52, -CLIP_UP),
		Vector2.new(104, 40),
		metal,
		14,
		5
	)
	ring.ZIndex = 4
	local hole =
		box(ring, "Hole", Vector2.new(20, 9), Vector2.new(64, 12), colour("gold.600"), 6, 4)
	hole.ZIndex = 5
	local plate = box(
		holder,
		"ClipPlate",
		Vector2.new(BOARD.X / 2 - 125, -CLIP_UP + 18),
		Vector2.new(250, 64),
		metal,
		16,
		5
	)
	plate.ZIndex = 6
	local shine = box(
		plate,
		"Shine",
		Vector2.new(14, 8),
		Vector2.new(222, 8),
		metal:Lerp(Color3.new(1, 1, 1), 0.55),
		4
	)
	shine.ZIndex = 7

	-- THE X
	local closeButton = make("TextButton", holder, {
		Name = "Close",
		BackgroundColor3 = colour("danger.600"),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(BOARD.X - 14 - 46, 10),
		Size = UDim2.fromOffset(46, 46),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 8,
	})
	make("UICorner", closeButton, { CornerRadius = UDim.new(0, 9) })
	make("UIStroke", closeButton, {
		Color = colour("ink.900"),
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	Poster.text(closeButton, "display", 26, "ink.900", {
		Size = UDim2.fromScale(1, 1),
		Text = "X",
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9,
	})

	-- THE SHEET: what is written on the paper
	local sheet = make("Frame", paper, {
		Name = "Sheet",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAPER.Inset - 4, PAPER.Top - 4), -- (the paper's 4 edge is inside its box)
		Size = UDim2.new(1, -2 * PAPER.Inset, 1, -PAPER.Top),
		ZIndex = 3,
	})
	Poster.text(sheet, "display", 56, "ink.900", {
		Name = "Title",
		Size = UDim2.fromOffset(INNER, 64),
		Text = "DAILY QUESTS",
		ZIndex = 3,
	})
	local sub = Poster.note(sheet, 19, {
		Name = "Sub",
		Position = UDim2.fromOffset(INNER - 300, 24),
		Size = UDim2.fromOffset(300, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	})
	box(sheet, "Rule", Vector2.new(0, 72), Vector2.new(INNER, 4), colour("ink.900"), 2).ZIndex = 3
	Poster.note(sheet, 16, {
		Name = "Rules",
		Position = UDim2.fromOffset(0, 476),
		Size = UDim2.fromOffset(INNER, 26),
		Text = "A round counts when you land a hit in it. Training counts behind the training wall.",
		ZIndex = 3,
	})
	local rows = make("Frame", sheet, {
		Name = "Rows",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})

	local function drawRow(index: number, quest: QuestView)
		local done = quest.progress >= quest.goal
		local row = make("Frame", rows, {
			Name = "Quest_" .. quest.id,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, ROW.Top + (index - 1) * ROW.Pitch),
			Size = UDim2.fromOffset(INNER, ROW.Height),
			ZIndex = 3,
		})
		if index > 1 then
			local line =
				box(row, "Line", Vector2.new(0, -4), Vector2.new(INNER, 2), colour("ink.900"), 1)
			line.BackgroundTransparency = 0.84
		end
		-- the tick box
		local check = box(
			row,
			"Check",
			Vector2.new(2, 22),
			Vector2.new(36, 36),
			colour(if done then "go.400" else "ivory.50"),
			8,
			4
		)
		if done then
			stroke(check, Vector2.new(9, 19), Vector2.new(15, 25), 4.5)
			stroke(check, Vector2.new(15, 25), Vector2.new(27, 11), 4.5)
		end
		-- what to do; crossed off once claimed
		local what =
			Poster.text(row, "display", 30, if quest.claimed then "ink.500" else "ink.900", {
				Name = "What",
				Position = UDim2.fromOffset(60, 16),
				Size = UDim2.fromOffset(0, 42),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = string.upper(quest.text),
			})
		if quest.claimed then
			make("Frame", what, {
				Name = "CrossedOff",
				BackgroundColor3 = colour("ink.900"),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, -4, 0.5, 2),
				Size = UDim2.new(1, 8, 0, 4),
			})
		end
		-- the bar and the count
		local track = box(row, "Bar", Vector2.new(60, 70), ROW.Bar, colour("ivory.200"), 8, 3)
		local share = math.clamp(quest.progress / math.max(quest.goal, 1), 0, 1)
		if share > 0 then
			local fill = make("Frame", track, {
				Name = "Fill",
				BackgroundColor3 = colour(if done then "go.400" else "teal.400"),
				BorderSizePixel = 0,
				Size = UDim2.new(math.max(share, 0.06), 0, 1, 0),
			})
			make("UICorner", fill, { CornerRadius = UDim.new(0, 8) })
		end
		Poster.text(row, "label", 20, "ink.900", {
			Name = "Count",
			Position = UDim2.fromOffset(ROW.Count, 61),
			Size = UDim2.fromOffset(120, 34),
			Text = quest.progressText,
		})
		-- the right side: Coins, CLAIM, or CLAIMED
		if quest.claimed then
			Poster.text(row, "label", 22, "ink.500", {
				Name = "Claimed",
				Position = UDim2.fromOffset(INNER - 260, 30),
				Size = UDim2.fromOffset(260, 34),
				Text = `CLAIMED · {quest.reward}`,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		elseif done then
			local button = make("TextButton", row, {
				Name = "Claim",
				BackgroundColor3 = colour("go.400"),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(INNER - 180, 18),
				Size = UDim2.fromOffset(180, 58),
				Text = "",
				AutoButtonColor = false,
			})
			make("UICorner", button, { CornerRadius = UDim.new(0, 9) })
			make("UIStroke", button, {
				Color = colour("ink.900"),
				Thickness = 4,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})
			Poster.text(button, "display", 24, "ink.900", {
				Size = UDim2.fromScale(1, 1),
				Text = `CLAIM · {quest.reward}`,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local home = button.Position
			button.MouseEnter:Connect(function()
				UiSound.hover()
				button.Position = home - UDim2.fromOffset(0, 2)
			end)
			button.MouseLeave:Connect(function()
				button.Position = home
			end)
			button.Activated:Connect(function()
				UiSound.play("ui_press")
				claim(quest.id)
			end)
		else
			local reward = make("Frame", row, {
				Name = "Reward",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(INNER - 260, 26),
				Size = UDim2.fromOffset(260, 40),
			})
			make("UIListLayout", reward, {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			})
			local coin = make("Frame", reward, {
				Name = "Coin",
				BackgroundColor3 = colour("gold.400"),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(22, 22),
				LayoutOrder = 1,
			})
			make("UICorner", coin, { CornerRadius = UDim.new(1, 0) })
			make("UIStroke", coin, { Color = colour("ink.900"), Thickness = 3 })
			Poster.text(reward, "display", 26, "ink.900", {
				Name = "Coins",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 40),
				Text = `{quest.reward} COINS`,
				LayoutOrder = 2,
			})
		end
	end

	local function draw()
		rows:ClearAllChildren()
		local left = secondsLeft()
		local hours, minutes = math.floor(left / 3600), math.floor(left % 3600 / 60)
		sub.Text = if hours > 0
			then `new ones in {hours}h {minutes}m`
			else `new ones in {math.max(minutes, 1)}m`
		local list = get()
		if not list then
			Poster.note(rows, 19, {
				Name = "Loading",
				Position = UDim2.fromOffset(0, ROW.Top + 20),
				Size = UDim2.fromOffset(INNER, 30),
				Text = "Your quests are on their way.",
			})
			return
		end
		for index, quest in list do
			drawRow(index, quest)
		end
	end

	-- WHERE IT STANDS: the middle of the screen, clear of the strips and tiles, as big as the window would be
	local scale = 1
	local function layout()
		local stage = PosterKit.stage()
		local fit = PosterKit.Fit
		local strip = HudTheme.Strip
		-- under the top strip, or the fighters' row when it is up (the clip touched the row, seen 2026-11-20),
		-- and under where the toast pops
		local top = math.max(
			stage.top + strip.Top + strip.Tall * strip.Shrink * stage.hud,
			Callouts.taken() or 0
		) + TOAST_ROOM * stage.nav
		local below = 16 + 40 * stage.hud + 16
		local leftRoom = NAV_RIGHT * stage.nav
		local rightRoom = TOOLS_LEFT * stage.nav
		local roomX = stage.view.X - leftRoom - rightRoom
		local roomY = stage.view.Y - top - below
		local want = math.clamp(stage.scale * fit.Window, fit.WindowMin, fit.WindowMax)
		scale = math.max(
			math.min(want, roomX / (BOARD.X + SHADOW), roomY / (BOARD.Y + SHADOW + CLIP_UP)),
			0.3
		)
		local wide = BOARD.X * scale
		local x = math.clamp(
			(stage.view.X - wide) / 2,
			leftRoom,
			math.max(leftRoom, stage.view.X - rightRoom - wide)
		)
		local y = top
			+ CLIP_UP * scale
			+ math.max(0, roomY - (BOARD.Y + SHADOW + CLIP_UP) * scale) * 0.4
		holder.Position = UDim2.fromOffset(x, y)
		scaler.Scale = scale
	end

	-- THE BLUR
	local blur: BlurEffect? = nil
	local function setBlur(on: boolean)
		local want = on and not lowGraphics()
		if want and not blur then
			blur =
				make("BlurEffect", Lighting, { Name = "HT_QuestBlur", Size = 0, Enabled = false })
		end
		local effect = blur
		if not effect then
			return
		end
		if HudMotion.reduced() then
			effect.Size = if want then BLUR.Size else 0
			effect.Enabled = want
			return
		end
		effect.Enabled = true
		local tween = TweenService:Create(
			effect,
			TweenInfo.new(if want then BLUR.In else BLUR.Out, Enum.EasingStyle.Quad),
			{ Size = if want then BLUR.Size else 0 }
		)
		tween.Completed:Connect(function()
			if not want and effect.Size == 0 then
				effect.Enabled = false
			end
		end)
		tween:Play()
	end

	local isOpen = false
	local function open()
		layout()
		draw()
		if isOpen then
			return
		end
		isOpen = true
		gui.Enabled = true
		UiSound.play("ui_open")
		setBlur(true)
		-- it pops in fast, toward you (owner: pop-ups must POP)
		if HudMotion.reduced() then
			scaler.Scale = scale
		else
			Poster.run(holder, 0.32, function(t: number)
				scaler.Scale = scale * (0.82 + 0.18 * PosterEase.spring(t))
			end)
		end
	end
	local function close()
		if not isOpen then
			return
		end
		isOpen = false
		Poster.stop(holder)
		gui.Enabled = false
		UiSound.play("ui_close")
		setBlur(false)
	end
	closeButton.Activated:Connect(function()
		close()
		onClosed()
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if isOpen then
				layout()
			end
		end)
	end

	return {
		open = open,
		close = close,
		isOpen = function()
			return isOpen
		end,
		draw = draw,
	}
end

return { new = new }
