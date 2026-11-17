--!strict
-- NavController - how you get around outside a fight, built to the approved fight-poster mockup (the vault's
-- UI Research/fight-poster-prototype.html: `.nav`, `.coins`, `.gear`). It replaces the Ringside column of square
-- buttons and its drawer.
--
-- IN THE LOBBY, down the left: five rough-cut strips, each a step further right than the one above.
--   CLASSES (1)  SHOP (2)  RANKED (3)  MOVES (4)  MORE
-- Each opens MenuController's poster window on its page; pressing the one that is open closes it. The open one
-- sits out to the right, a little larger, its word rocking. Your Coins are on a slanted plate at the top right.
-- IN A ROUND all of that folds away into one small MENU button at the top left, which opens the window's More
-- page: Settings and the controls. The match never pauses. Q and R are HudController's and stay.
--
-- This is a LAUNCHER and owns no feature. AFK and Spectate are rows of the More page now. Sizes are the mockup's
-- pixels at 1280 x 720; the lobby scales as a whole (Ui/PosterKit.lobbyScale).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Drift = require(script.Parent.Parent.Ui.Drift)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)
local Poster = require(script.Parent.Parent.Ui.Poster)
local PosterKit = require(script.Parent.Parent.Ui.PosterKit)
local Shapes = require(script.Parent.Parent.Ui.Shapes)

local colour = Tokens.colour
local make = PosterKit.make

local IN_ROUND = "HT_InRound"
local KEYS_ACTION = "HaymakerNavKeys"
local MOVES_ACTION = "HaymakerHelp"

type Entry = {
	id: string,
	label: string,
	key: Enum.KeyCode?,
	keyName: string?,
	tone: string,
	shape: string,
	x: number, -- each strip starts a step right of the one above
	y: number,
	size: Vector2,
	font: number,
}

-- the mockup's five, top to bottom: 250 x 74 and 14 apart; MORE is the small cream one
local ENTRIES: { Entry } = {
	{
		id = "classes",
		label = "Classes",
		key = Enum.KeyCode.One,
		keyName = "1",
		tone = "teal.400",
		shape = "navA",
		x = 0,
		y = 0,
		size = Vector2.new(250, 74),
		font = 34,
	},
	{
		id = "shop",
		label = "Shop",
		key = Enum.KeyCode.Two,
		keyName = "2",
		tone = "gold.400",
		shape = "navB",
		x = 16,
		y = 88,
		size = Vector2.new(250, 74),
		font = 34,
	},
	{
		id = "ranked",
		label = "Ranked",
		key = Enum.KeyCode.Three,
		keyName = "3",
		tone = "danger.600",
		shape = "navA",
		x = 30,
		y = 176,
		size = Vector2.new(250, 74),
		font = 34,
	},
	{
		id = "moves",
		label = "Moves",
		key = Enum.KeyCode.Four,
		keyName = "4",
		tone = "violet.400",
		shape = "navD",
		x = 44,
		y = 264,
		size = Vector2.new(250, 74),
		font = 34,
	},
	{
		id = "more",
		label = "More",
		tone = "ivory.50",
		shape = "navA",
		x = 58,
		y = 352,
		size = Vector2.new(170, 54),
		font = 22,
	},
}

local NavController = Knit.CreateController({
	Name = "NavController",
})

function NavController:KnitStart()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local menu = Knit.GetController("MenuController")
	local ability = Knit.GetController("AbilityController")

	-- the strips: on the whole screen, as the mockup places them
	local gui = make("ScreenGui", nil, {
		Name = "HT_Nav",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 19, -- over the HUD, under the poster window (20)
	})
	-- the coins and the fight's MENU button: under Roblox's own top bar, like the HUD's strip
	local topGui = make("ScreenGui", nil, {
		Name = "HT_NavTop",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 19,
	})

	local function toggle(id: string)
		if menu:GetEntry() == id then
			menu:Close()
		else
			menu:Open(id)
		end
	end

	-- THE STRIPS -----------------------------------------------------------------------------------------
	local nav = make("Frame", gui, {
		Name = "Nav",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(320, 410),
	})
	local navScale = make("UIScale", nav, {})
	type Strip = {
		entry: Entry,
		cut: PosterKit.Cut,
		word: Frame,
		wordScale: UIScale,
		cap: TextLabel?,
		home: Vector2,
	}
	local strips: { Strip } = {}
	for _, entry in ENTRIES do
		local cut =
			PosterKit.cut(nav, entry.shape, entry.size, colour(entry.tone), Vector2.new(6, 7))
		cut.root.Name = entry.id
		PosterKit.place(cut, entry.x, entry.y)
		-- the label is an image of the word in the mockup's own font (Ui/Shapes.letters)
		local word = Poster.word(
			cut.face,
			"words",
			"nav:" .. string.upper(entry.label),
			entry.font,
			"ink.900",
			{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 22, 0.5, 0) }
		).frame
		local wordScale = make("UIScale", word, {})
		local cap: TextLabel? = nil
		if entry.keyName then
			-- the key: cream on ink, at the strip's right end
			local made = Poster.text(cut.face, "label", 15, "ivory.50", {
				Name = "Key",
				BackgroundColor3 = colour("ink.900"),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -22, 0.5, 0),
				Size = UDim2.fromOffset(0, 25),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = entry.keyName,
			})
			make("UIPadding", made, { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) })
			cap = made
		end
		PosterKit.pressable(cut, function()
			toggle(entry.id)
		end)
		-- Idle drift (Ui/Drift): 4 units, and the shape and the word (an image) swing half a degree each way. The
		-- key cap is small text, so it only rides up and down. 4 and half a degree, not the mockup's 5 and 0.8:
		-- two neighbours at their far ends must still not touch (14 apart, less a 7-unit shadow).
		Drift.add("nav", cut.body, entry.size.Y, 4, nil, 1, { cut.shape, word })
		table.insert(strips, {
			entry = entry,
			cut = cut,
			word = word,
			wordScale = wordScale,
			cap = cap,
			home = Vector2.new(entry.x + entry.size.X / 2, entry.y + entry.size.Y / 2),
		})
	end

	-- The open page's strip sits 18 to the right and a little larger, and its word rocks (the mockup's `wig`:
	-- 2 degrees each way, half a second a swing) for as long as it is open.
	local current: string? = nil
	local function rock(strip: Strip, out: boolean)
		if current ~= strip.entry.id or HudMotion.reduced() then
			strip.word.Rotation = 0
			strip.wordScale.Scale = 1
			return
		end
		Poster.run(strip.word, 0.5, function(t: number)
			local e = PosterEase.easeInOut(t)
			local share = if out then e else 1 - e
			strip.word.Rotation = -2 + 4 * share
			strip.wordScale.Scale = 1 + 0.05 * share
		end, function()
			rock(strip, not out)
		end)
	end
	local function setCurrent(id: string?)
		current = id
		for _, strip in strips do
			local on = strip.entry.id == id
			strip.cut.restScale = if on then 1.04 else 1
			strip.cut.root.Position =
				UDim2.fromOffset(strip.home.X + (if on then 18 else 0), strip.home.Y)
			strip.cut.scale.Scale = strip.cut.restScale
			-- the open strip holds still: its word rocks instead
			Drift.hold(strip.cut.body, on)
			Poster.stop(strip.word)
			rock(strip, true)
		end
	end
	menu.Changed:Connect(setCurrent)

	-- The strips arriving (`nin`): each from off the left, tipped 10 degrees, on the spring, one after another.
	local function enter()
		for index, strip in strips do
			local cut = strip.cut
			cut.root.Visible = false
			Poster.run(cut, 0.7, function(t: number)
				local s = PosterEase.spring(t)
				local shift = (current == strip.entry.id) and 18 or 0
				cut.root.Visible = true
				cut.root.Position = UDim2.fromOffset(
					strip.home.X + shift - strip.entry.size.X * 1.3 * (1 - s),
					strip.home.Y
				)
				cut.root.Rotation = -10 * (1 - s)
			end, nil, (index - 1) * 0.07)
		end
	end

	-- THE COINS ------------------------------------------------------------------------------------------
	-- a slanted ink plate, 22 from the right and 18 from the top: a coin and the number in 22 px Oswald
	-- (its width is set from the number's measured width: left to AutomaticSize, the plate, which is wider than
	-- its box, made the box grow without end; first run, 2026-11-17)
	local coins = make("Frame", topGui, {
		Name = "Coins",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(120, 48),
	})
	local coinsScale = make("UIScale", coins, {})
	local coinsLean = 48 * math.tan(math.rad(10))
	Shapes.slant(coins, "ink.900", coinsLean, {
		Name = "Plate",
		Position = UDim2.fromOffset(-coinsLean / 2, 0),
		Size = UDim2.new(1, coinsLean, 1, 0),
	})
	local coinsRow = make("Frame", coins, {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	})
	make("UIPadding", coinsRow, { PaddingLeft = UDim.new(0, 15), PaddingRight = UDim.new(0, 16) })
	make("UIListLayout", coinsRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 11),
	})
	local coin = make("Frame", coinsRow, {
		Name = "Coin",
		BackgroundColor3 = colour("gold.400"),
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(20, 20),
	})
	make("UICorner", coin, { CornerRadius = UDim.new(0.5, 0) })
	make("UIStroke", coin, { Color = colour("ivory.50"), Thickness = 3 })
	-- the amount: figures from the lettering sheet (Ui/Shapes.letters), so its width is known at once
	local coinsFigures =
		Poster.figures(coinsRow, 12, 22, "ivory.50", { Name = "Amount", LayoutOrder = 2 })
	local function refreshCoins()
		local width = Poster.setFigures(coinsFigures, tostring(ability:GetCoins()))
		coins.Size = UDim2.fromOffset(15 + 20 + 11 + math.ceil(width) + 16, 48)
	end
	ability.InventoryChanged:Connect(refreshCoins)
	refreshCoins()

	-- THE FIGHT'S MENU BUTTON -----------------------------------------------------------------------------
	-- 58 x 58, cream, 22 from the left and 18 from the top; it opens the window's More page
	local gear = PosterKit.cut(topGui, "gear", Vector2.new(58, 58), colour("ivory.50"))
	gear.root.Name = "Menu"
	local gearWord = Poster.text(gear.face, "label", 15, "ink.900", {
		Size = UDim2.fromScale(1, 1),
		Text = "MENU",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	gearWord.FontFace = Font.new(Tokens.family.text, Enum.FontWeight.Bold)
	PosterKit.pressable(gear, function()
		toggle("more")
	end)
	Drift.add("fight", gear.body, 58, 5) -- up and down only: MENU is small text

	-- LAYOUT AND WHAT SHOWS --------------------------------------------------------------------------------
	local wasLobby: boolean? = nil
	local function refresh()
		local stage = PosterKit.stage()
		local scale = stage.nav
		navScale.Scale = scale
		-- the column stands where the mockup has it down the stage (its middle just above the stage's), under
		-- Roblox's top bar
		local room = stage.view.Y - stage.top
		nav.Position =
			UDim2.fromOffset(26 * scale, stage.top + math.max(8, room * 0.493 - 205 * scale))
		coinsScale.Scale = scale
		coins.Position = UDim2.new(1, -22 * scale, 0, 18)
		local press = math.max(scale, PosterKit.Fit.Button)
		gear.restScale = press
		gear.scale.Scale = press
		gear.root.Position = UDim2.fromOffset(22 + 29 * press, 18 + 29 * press)
		local lobby = player:GetAttribute(IN_ROUND) ~= true
		nav.Visible = lobby
		coins.Visible = lobby
		gear.root.Visible = not lobby
		Drift.show("nav", lobby)
		Drift.show("fight", not lobby)
		-- the keys only mean anything with a keyboard in hand
		local keyboard = UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch
			and not string.find(UserInputService:GetLastInputType().Name, "Gamepad")
		for _, strip in strips do
			if strip.cap then
				strip.cap.Visible = keyboard
			end
		end
		if lobby and wasLobby ~= true then
			enter()
		end
		wasLobby = lobby
	end
	player:GetAttributeChangedSignal(IN_ROUND):Connect(refresh)
	UserInputService.LastInputTypeChanged:Connect(refresh)
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
		end
		refresh()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

	-- KEYS -------------------------------------------------------------------------------------------------
	-- 1 to 4 open the four pages in the lobby; H (Select on a gamepad) opens the controls anywhere.
	local byKey: { [Enum.KeyCode]: string } = {}
	local keys: { Enum.KeyCode } = {}
	for _, entry in ENTRIES do
		if entry.key then
			byKey[entry.key] = entry.id
			table.insert(keys, entry.key)
		end
	end
	ContextActionService:BindAction(
		KEYS_ACTION,
		function(_: string, state: Enum.UserInputState, input: InputObject)
			if state == Enum.UserInputState.Begin and player:GetAttribute(IN_ROUND) ~= true then
				local id = byKey[input.KeyCode]
				if id then
					toggle(id)
				end
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		table.unpack(keys)
	)
	ContextActionService:BindActionAtPriority(
		MOVES_ACTION,
		function(_: string, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				toggle("moves")
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.Low.Value,
		Enum.KeyCode.H,
		Enum.KeyCode.ButtonSelect
	)

	gui.Parent = playerGui
	topGui.Parent = playerGui
	watchCamera()
end

return NavController
