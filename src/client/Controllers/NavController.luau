--!strict
-- NavController - how you get around outside a fight, built to the approved fight-poster mockup (the vault's
-- UI Research/fight-poster-prototype.html: `.nav`, `.coins`, `.gear`). It replaces the Ringside column of square
-- buttons and its drawer.
--
-- IN THE LOBBY, down the left: five rough-cut strips, each a step further right than the one above.
--   SHOP (1)  CLASSES (2)  RANKED (3)  MOVES (4)  MORE
-- Each opens MenuController's poster window on its page; pressing the one that is open closes it. The open one
-- sits out to the right, a little larger, its word rocking. Your Coins are on a slanted plate at the top right.
-- IN A ROUND all of that folds away into one small MENU button at the top left, which opens the window's More
-- page: Settings and the controls. The match never pauses. Q and R are HudController's and stay.
--
-- DOWN THE RIGHT EDGE in the lobby: three small tiles, SETTINGS, SPECTATE and AFK (2026-11-18; they were rows
-- of the More page).
-- This is a LAUNCHER and owns no feature. Sizes are the mockup's
-- pixels at 1280 x 720; the lobby scales as a whole (Ui/PosterKit.lobbyScale).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Drift = require(script.Parent.Parent.Ui.Drift)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)
local Icons = require(script.Parent.Parent.Ui.Icons)
local Poster = require(script.Parent.Parent.Ui.Poster)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)
local PosterKit = require(script.Parent.Parent.Ui.PosterKit)
local UiSound = require(script.Parent.Parent.Ui.UiSound)

local colour = Tokens.colour
local make = PosterKit.make

local IN_ROUND = "HT_InRound"
local GEAR = 68 -- the fight's MENU button
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

-- the mockup's five, top to bottom: 250 x 74 and 14 apart; MORE is the small cream one. SHOP stands above
-- CLASSES (the owner, 2026-11-18; the mockup had them the other way), and the keys follow the order.
local ENTRIES: { Entry } = {
	{
		id = "shop",
		label = "Shop",
		key = Enum.KeyCode.One,
		keyName = "1",
		tone = "gold.400",
		shape = "navA",
		x = 0,
		y = 0,
		size = Vector2.new(250, 74),
		font = 34,
	},
	{
		id = "classes",
		label = "Classes",
		key = Enum.KeyCode.Two,
		keyName = "2",
		tone = "teal.400",
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

-- the right-edge tools, top to bottom: a tile 94 x 78 (wide enough for SPECTATE with air round it), 12 apart
local TOOLS = {
	{ id = "settings", label = "SETTINGS", icon = "toolSettings" },
	{ id = "spectate", label = "SPECTATE", icon = "toolSpectate" },
	{ id = "afk", label = "AFK", icon = "toolAfk" },
}
local TOOL = Vector2.new(94, 78)
local TOOL_GAP = 12

-- whether the menu strips print their hotkey number (1-4) at their right end
local SHOW_KEYS = false

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
		-- (no number on the strips since 2026-11-20, the owner had them removed; the 1-4 keys still open the pages)
		if entry.keyName and SHOW_KEYS then
			-- the key, printed on the strip at its right end (ui-23a, 2026-11-20: no square label pasted on top; the owner, "I want it to be IN THE UI")
			local made = Poster.text(cut.face, "display", 20, "ink.900", {
				Name = "Key",
				BackgroundTransparency = 1,
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
		-- up and down only (ui-24a): the strips used to sway a degree as well, but Roblox stops clipping under
		-- anything turned, so the sparkles spilled past the strip at every sway (and "nothing tilted", 2026-11-19)
		Drift.add("nav", cut.body, entry.size.Y, 4)
		table.insert(strips, {
			entry = entry,
			cut = cut,
			word = word,
			wordScale = wordScale,
			cap = cap,
			home = Vector2.new(entry.x + entry.size.X / 2, entry.y + entry.size.Y / 2),
		})
	end

	-- THE TOOLS: SETTINGS, SPECTATE, AFK ----------------------------------------------------------------------
	-- Down the right edge in the lobby (the owner, 2026-11-18: they were rows of the More page, too important to
	-- sit that deep). Three cream tiles, each its icon over its word. AFK turns yellow and says AFK ON while you
	-- are sitting out. They stand under the Coins and the feed, and give way to the open window.
	local tools = make("Frame", gui, {
		Name = "Tools",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(TOOL.X + 8, #TOOLS * TOOL.Y + (#TOOLS - 1) * TOOL_GAP + 8),
	})
	local toolsScale = make("UIScale", tools, {})
	type Tool = { id: string, cut: PosterKit.Cut, word: TextLabel, home: Vector2 }
	local toolList: { Tool } = {}
	local afkRemote = if GameConfig.Round.Enabled and GameConfig.Round.AfkEnabled
		then Net.client("AfkToggle")
		else nil
	local spectate = Knit.GetController("SpectateController")
	-- when the AFK tile was last pressed: the toast answers your own press, not the attribute arriving on join
	local askedAfk = -math.huge
	local function useTool(id: string)
		if id == "settings" then
			toggle("settings")
		elseif id == "spectate" then
			spectate:Toggle()
		elseif id == "afk" and afkRemote then
			askedAfk = os.clock()
			afkRemote:FireServer()
		end
	end
	for index, spec in TOOLS do
		if spec.id ~= "afk" or afkRemote then
			local cut = PosterKit.cut(tools, "tile", TOOL, colour("ivory.50"), Vector2.new(5, 6))
			cut.fill:SetAttribute("HT_Finish", "plain") -- (utility tiles: no sparkles, the owner, 2026-11-20)
			cut.root.Name = spec.id
			local home = Vector2.new(TOOL.X / 2, (index - 1) * (TOOL.Y + TOOL_GAP) + TOOL.Y / 2)
			cut.root.Position = UDim2.fromOffset(home.X, home.Y)
			-- the mockup's line drawing, in ink
			local icon = Icons.image(cut.face, spec.icon, 36, UDim2.new(0.5, 0, 0, 30))
			icon.ImageColor3 = colour("ink.900")
			local word = Poster.text(cut.face, "label", 15, "ink.900", {
				Name = "Word",
				Position = UDim2.new(0, 0, 1, -30),
				Size = UDim2.new(1, 0, 0, 20),
				Text = spec.label,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			PosterKit.pressable(cut, function()
				useTool(spec.id)
			end)
			Drift.add("tools", cut.body, TOOL.Y, 3) -- up and down only: they carry words
			table.insert(toolList, { id = spec.id, cut = cut, word = word, home = home })
		end
	end
	local function paintAfk()
		local on = player:GetAttribute("HT_AFK") == true
		for _, tool in toolList do
			if tool.id == "afk" then
				tool.cut.fill.ImageColor3 = colour(if on then "gold.400" else "ivory.50")
				tool.word.Text = if on then "AFK ON" else "AFK"
			end
		end
	end
	player:GetAttributeChangedSignal("HT_AFK"):Connect(function()
		paintAfk()
		if os.clock() - askedAfk < 5 then
			askedAfk = -math.huge
			menu:Toast(
				if player:GetAttribute("HT_AFK") == true
					then "AFK on. You'll sit out the next round."
					else "AFK off. You're in for the next round."
			)
		end
	end)
	paintAfk()

	-- The open page's strip sits 18 to the right and a little larger, and its word rocks (the mockup's `wig`:
	-- 2 degrees each way, half a second a swing) for as long as it is open.
	local current: string? = nil
	-- strips and tools on their way in: they answer no pointer until they have landed (see `enter`)
	local entering: { [any]: boolean } = {}
	local function rock(strip: Strip, out: boolean)
		if current ~= strip.entry.id or HudMotion.reduced() then
			strip.word.Rotation = 0
			strip.wordScale.Scale = 1
			return
		end
		Poster.run(strip.word, 0.5, function(t: number)
			local e = PosterEase.easeInOut(t)
			local share = if out then e else 1 - e
			-- (it rocked 2 degrees each way until 2026-11-19; now it only swells: less angular)
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
			-- it SLIDES to its place over a quarter second (it used to jump the 18 units in one frame). One
			-- still on its way in is left alone: `enter` reads `current` and lands it in the right place.
			if not entering[strip.cut] then
				local root = strip.cut.root
				local from = root.Position.X.Offset
				local to = strip.home.X + (if on then 18 else 0)
				Poster.run(strip, 0.25, function(t: number)
					local e = PosterEase.easeOut(t)
					root.Position = UDim2.fromOffset(from + (to - from) * e, strip.home.Y)
				end)
			end
			strip.cut.scale.Scale = strip.cut.restScale
			-- the open strip holds still: its word rocks instead
			Drift.hold(strip.cut.body, on)
			Poster.stop(strip.word)
			rock(strip, true)
		end
	end
	menu.Changed:Connect(setCurrent)
	-- the tools give way to the open window (nothing lies over anything)
	menu.Changed:Connect(function(entry: string?)
		local showTools = entry == nil and player:GetAttribute(IN_ROUND) ~= true
		tools.Visible = showTools
		Drift.show("tools", showTools)
	end)

	-- The strips arriving (`nin`): each from off the left, tipped 10 degrees, on the spring, one after another.
	local function enter()
		for index, strip in strips do
			local cut = strip.cut
			cut.root.Visible = false
			-- The entrance and the answer to the pointer (PosterKit.pressable) run under the SAME key, so a
			-- pointer crossing a strip in flight replaced its entrance and left it standing where it was,
			-- short of its place and tipped (found reading the code, 2026-11-18). Its button is put away
			-- until it has landed.
			entering[cut] = true
			Poster.stop(strip)
			if cut.button then
				cut.button.Visible = false
			end
			Poster.run(cut, 0.7, function(t: number)
				local s = PosterEase.spring(t)
				local shift = (current == strip.entry.id) and 18 or 0
				cut.root.Visible = true
				cut.root.Position = UDim2.fromOffset(
					strip.home.X + shift - strip.entry.size.X * 1.3 * (1 - s),
					strip.home.Y
				)
				cut.root.Rotation = -10 * (1 - s)
			end, function()
				entering[cut] = nil
				if cut.button then
					cut.button.Visible = true
				end
			end, (index - 1) * 0.07)
		end
		-- the tools the same way, from off the right
		for index, tool in toolList do
			local cut = tool.cut
			cut.root.Visible = false
			entering[cut] = true
			if cut.button then
				cut.button.Visible = false
			end
			Poster.run(cut, 0.7, function(t: number)
				local s = PosterEase.spring(t)
				cut.root.Visible = true
				cut.root.Position =
					UDim2.fromOffset(tool.home.X + TOOL.X * 1.6 * (1 - s), tool.home.Y)
				cut.root.Rotation = 10 * (1 - s)
			end, function()
				entering[cut] = nil
				if cut.button then
					cut.button.Visible = true
				end
			end, 0.2 + (index - 1) * 0.07)
		end
	end

	-- THE COINS ------------------------------------------------------------------------------------------
	-- NO PLATE (the owner, 2026-11-18: "i HATE this style ... for EVERYTHING"; a slanted ink plate until then): a
	-- coin and the number as poster lettering, standing straight on the world, 22 from the right and 18 from the
	-- top. The row is laid out from the right, so nothing has to be measured.
	local coins = make("Frame", topGui, {
		Name = "Coins",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(240, 48),
	})
	local coinsScale = make("UIScale", coins, {})
	make("UIListLayout", coins, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	})
	local coin = make("Frame", coins, {
		Name = "Coin",
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(28, 28),
	})
	-- a yellow disc with an ink edge, and the same disc in ink a little right and down: its hard shadow
	for _, part in { { "Shadow", "ink.900", 5, 6, 1 }, { "Face", "gold.400", 3, 3, 2 } } do
		local disc = make("Frame", coin, {
			Name = part[1],
			BackgroundColor3 = colour(part[2] :: string),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(part[3] :: number, part[4] :: number),
			Size = UDim2.fromOffset(20, 20),
			ZIndex = part[5] :: number,
		})
		make("UICorner", disc, { CornerRadius = UDim.new(0.5, 0) })
		make("UIStroke", disc, { Color = colour("ink.900"), Thickness = 3 })
	end
	local coinsAmount =
		PosterKit.lettering(coins, 26, "gold.400", "0", { Name = "Amount", LayoutOrder = 2 }) -- coin yellow: louder than cream
	local function refreshCoins()
		PosterKit.setLettering(coinsAmount, tostring(ability:GetCoins()))
	end
	ability.InventoryChanged:Connect(refreshCoins)
	refreshCoins()

	-- THE FIGHT'S MENU BUTTON -----------------------------------------------------------------------------
	-- 68 x 68 (58 until 2026-11-18: the owner wanted it a little bigger), cream, 22 from the left and 18 from the
	-- top; in a round it opens the window straight on its Settings, which is all the round's menu is
	local gear = PosterKit.cut(topGui, "gear", Vector2.new(GEAR, GEAR), colour("ivory.50"))
	gear.fill:SetAttribute("HT_Finish", "plain")
	gear.root.Name = "Menu"
	-- a cog, not the word MENU (the owner, 2026-11-18: it is only the settings button now): the same line
	-- drawing as the lobby's SETTINGS tile, in ink
	local gearIcon = Icons.image(gear.face, "toolSettings", 44)
	gearIcon.ImageColor3 = colour("ink.900")
	PosterKit.pressable(gear, function()
		toggle(if player:GetAttribute(IN_ROUND) == true then "settings" else "more")
	end)
	Drift.add("fight", gear.body, GEAR, 5) -- up and down only: MENU is small text

	-- THE FIGHT'S CONTROLS ---------------------------------------------------------------------------------
	-- A small cream chip over Jump and Punch, "H . CONTROLS", and a small see-through panel that opens above it
	-- with every control, scrolling (the owner, 2026-11-18: not the big window, the same style but simpler). H
	-- opens and closes it in a round; in the lobby H still opens the window's Moves page.
	local CHIP = Vector2.new(176, 30)
	local PANEL = Vector2.new(320, 240)
	local chipHolder = make("Frame", gui, {
		Name = "ControlsChip",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(CHIP.X, CHIP.Y),
		Visible = false,
	})
	local chipScale = make("UIScale", chipHolder, {})
	local chip = PosterKit.cut(chipHolder, "act", CHIP, colour("ivory.50"), Vector2.new(3, 4))
	chip.fill:SetAttribute("HT_Finish", "plain")
	chip.root.Position = UDim2.fromOffset(CHIP.X / 2, CHIP.Y / 2)
	local chipWord = Poster.text(chip.face, "label", 15, "ink.900", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local panel = make("Frame", gui, {
		Name = "ControlsPanel",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = colour("ink.900"),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(PANEL.X, PANEL.Y),
		Visible = false,
	})
	local panelScale = make("UIScale", panel, {})
	make("UIStroke", panel, { Color = colour("ink.900"), Thickness = 3 })
	Poster.text(panel, "label", 15, "gold.400", {
		Name = "Title",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "CONTROLS",
	})
	local list = make("ScrollingFrame", panel, {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -16, 1, -42),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = colour("ivory.50"),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	make("UIListLayout", list, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local function deviceNow(): string
		local kind = UserInputService:GetLastInputType()
		if kind == Enum.UserInputType.Touch then
			return "touch"
		elseif string.find(kind.Name, "Gamepad") then
			return "gamepad"
		end
		return "mouse"
	end
	-- the rows: a key in a cream cap, then what it does (the same list as the window's Moves page)
	local listedFor = ""
	local function fillControls()
		local device = deviceNow()
		if device == listedFor then
			return
		end
		listedFor = device
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local moves: { { key: string, action: string } } =
			table.clone((HudTheme.Guide :: any)[device] or {})
		table.insert(moves, math.min(5, #moves + 1), {
			key = if device == "gamepad" then "Up" elseif device == "touch" then "Ult" else "G",
			action = "Ultimate: when ULT READY shows, land a hit, then press it.",
		})
		for index, move in moves do
			local name, rest = string.match(move.action, "^([^:%.]+)[:%.]%s*(.*)$")
			local row = make("Frame", list, {
				Name = "Row",
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, 24),
			})
			-- (the key as yellow lettering on the panel, no cream box (ui-23a, 2026-11-20: no square label pasted on top; the owner, "I want it to be IN THE UI"))
			local cap = Poster.text(row, "label", 14, "gold.400", {
				Name = "Key",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(64, 24),
				Text = move.key,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			cap.TextTruncate = Enum.TextTruncate.AtEnd
			Poster.text(row, "label", 14, "ivory.50", {
				Name = "What",
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromOffset(74, 0),
				Size = UDim2.new(1, -74, 0, 24),
				RichText = true,
				Text = if name
					then `<b>{string.upper(name)}</b>  <font color="{Tokens.hex["stone.300"]}">{rest}</font>`
					else move.action,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
		end
	end
	local controlsOpen = false
	-- how far the panel's foot stands above the screen's bottom margin, in HUD units, and its slide between the
	-- two places when the ultimate arrives or goes
	local panelHud = 1
	local function panelLift(): number
		return if player:GetAttribute("HT_UltReady") == true then 200 else 77 + CHIP.Y + 8
	end
	player:GetAttributeChangedSignal("HT_UltReady"):Connect(function()
		local from = panel.Position.Y.Offset
		local to = -(24 + panelLift() * panelHud)
		Poster.run(panel, 0.25, function(t: number)
			panel.Position = UDim2.new(1, -26, 1, from + (to - from) * PosterEase.easeOut(t))
		end)
	end)
	local function setControls(on: boolean)
		if on == controlsOpen then
			return
		end
		controlsOpen = on
		if on then
			fillControls()
		end
		panel.Visible = on
		UiSound.play(if on then "ui_open" else "ui_close")
	end
	PosterKit.pressable(chip, function()
		setControls(not controlsOpen)
	end)
	Drift.add("fight", chip.body, CHIP.Y, 3)
	-- it gives way to the open window
	menu.Changed:Connect(function(entry: string?)
		if entry then
			setControls(false)
		end
	end)

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
		gear.root.Position = UDim2.fromOffset(22 + GEAR / 2 * press, 18 + GEAR / 2 * press)
		local lobby = player:GetAttribute(IN_ROUND) ~= true
		nav.Visible = lobby
		coins.Visible = lobby
		gear.root.Visible = not lobby
		-- the tools: under the Coins and the feed's four rows, about the middle of the screen's right edge
		toolsScale.Scale = scale
		local under = stage.top + 18 + 58 * scale + 4 * 32 * stage.hud + 8
		local middle = stage.top + room * 0.52 - tools.Size.Y.Offset * scale / 2
		tools.Position = UDim2.new(1, -22 * scale, 0, math.max(under, middle))
		local showTools = lobby and menu:GetEntry() == nil
		tools.Visible = showTools
		Drift.show("tools", showTools)
		Drift.show("nav", lobby)
		Drift.show("fight", not lobby)
		-- the CONTROLS chip stands over the small Jump and Punch tiles (69 units at the HUD's scale, 24 from the
		-- bottom, 26 from the right) and its panel over the ULT READY badge's place; a phone has neither
		local device = deviceNow()
		local showChip = not lobby and device ~= "touch"
		chipScale.Scale = stage.hud
		panelScale.Scale = stage.hud
		chipHolder.Position = UDim2.new(1, -26, 1, -(24 + 77 * stage.hud))
		-- The panel stands right on top of the chip (8 units of air). Only while you HOLD your ultimate does
		-- it stand higher, clear of the ULT READY badge's place, and it comes back down when the ultimate is
		-- used (the owner, 2026-11-18: it always stood high, with an empty gap under it).
		panelHud = stage.hud
		Poster.stop(panel)
		panel.Position = UDim2.new(1, -26, 1, -(24 + panelLift() * panelHud))
		chipHolder.Visible = showChip
		chipWord.Text = if device == "gamepad" then "SELECT  ·  CONTROLS" else "H  ·  CONTROLS"
		if not showChip then
			setControls(false)
		end
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
				if player:GetAttribute(IN_ROUND) == true then
					setControls(not controlsOpen)
				else
					toggle("moves")
				end
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
