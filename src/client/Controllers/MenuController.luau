--!strict
-- MenuController - the game menu. M (or the Menu button at the left edge) opens and closes it; so do
-- the X, a click outside it, and gamepad B while it's open (bound only then, above the B dash, so the
-- dash keeps B the rest of the time: vault Field Note "Shift-Lock Sprint and Gamepad B for Menus").
--
-- Four tabs:
--   Abilities - the kit you wear (its Q and R skills) and every kit you own, to equip.
--   Shop      - every kit, with its price in Coins, to buy.
--   Passes    - placeholders for game passes; nothing is for sale yet.
--   Settings  - placeholder switches that don't change anything yet, and whether progress saves.
--
-- Everything shown comes from AbilityController (the server's attributes); the menu only asks it to
-- buy or equip. Its notices (a buy went through, a skill that isn't built) show as a toast above the
-- bottom of the screen, menu open or not.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityKit = require(ReplicatedStorage.Shared.Core.AbilityKit)
local Typography = require(ReplicatedStorage.Shared.Typography)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)

local book: any = Abilities
local C = HudTheme.Colour
local M = HudTheme.Menu

local TOGGLE_ACTION = "HaymakerMenu"
local CLOSE_ACTION = "HaymakerMenuClose"

type Tab = "Abilities" | "Shop" | "Passes" | "Settings"
local TABS: { Tab } = { "Abilities", "Shop", "Passes", "Settings" }

local PASSES = {
	{ name = "VIP", blurb = "A gold name tag and a VIP spot in the lobby." },
	{ name = "2x Coins", blurb = "Double the Coins from every round." },
	{ name = "Kit Collector", blurb = "Every ability kit released this season." },
}

local SETTINGS = {
	{ id = "shake", name = "Camera shake", blurb = "The camera kicks when you hit or get hit." },
	{ id = "flash", name = "Hit flash", blurb = "Bodies flash white when a hit lands." },
	{ id = "music", name = "Music", blurb = "Background music in the lobby and rounds." },
}

local MenuController = Knit.CreateController({
	Name = "MenuController",
})

local function make(className: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function text(parent: Instance, role: string, props: { [string]: any }): TextLabel
	local label = make("TextLabel", nil, {
		BackgroundTransparency = 1,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	Typography.apply(label, role)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

-- A text block that grows to fit its wrapped text.
local function para(
	parent: Instance,
	role: string,
	value: string,
	colour: Color3?,
	order: number?
): TextLabel
	return text(parent, role, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = value,
		TextColor3 = colour or C.Text,
		LayoutOrder = order or 0,
	})
end

local function corner(parent: Instance, radius: number)
	make("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function padding(parent: Instance, amount: number)
	make("UIPadding", parent, {
		PaddingTop = UDim.new(0, amount),
		PaddingBottom = UDim.new(0, amount),
		PaddingLeft = UDim.new(0, amount),
		PaddingRight = UDim.new(0, amount),
	})
end

local function list(parent: Instance, gap: number, horizontal: boolean?)
	make("UIListLayout", parent, {
		FillDirection = if horizontal
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
		VerticalAlignment = if horizontal
			then Enum.VerticalAlignment.Center
			else Enum.VerticalAlignment.Top,
	})
end

-- A small round coin, drawn (no emoji).
local function coin(parent: Instance, size: number, order: number?): Frame
	local dot = make("Frame", parent, {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = M.Coin,
		BorderSizePixel = 0,
		LayoutOrder = order or 0,
	})
	make("UICorner", dot, { CornerRadius = UDim.new(0.5, 0) })
	make("UIStroke", dot, { Color = Color3.fromRGB(176, 120, 20), Thickness = 1.5 })
	return dot
end

-- A key cap: "Q", "R".
local function keyCap(parent: Instance, key: string, order: number): Frame
	local cap = make("Frame", parent, {
		Size = UDim2.fromOffset(26, 24),
		BackgroundColor3 = C.Track,
		BorderSizePixel = 0,
		LayoutOrder = order,
	})
	corner(cap, 4)
	text(cap, "Key", {
		Size = UDim2.fromScale(1, 1),
		Text = key,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	return cap
end

-- A button: "primary" (yellow), "plain" (raised dark) or "off" (greyed, not pressable).
local function button(
	parent: Instance,
	label: string,
	style: string,
	onPress: (() -> ())?
): TextButton
	local off = style == "off"
	local b = make("TextButton", parent, {
		Size = UDim2.fromOffset(M.CardButton, M.Tab),
		AutoButtonColor = not off,
		BorderSizePixel = 0,
		BackgroundColor3 = if style == "primary"
			then C.Accent
			elseif off then C.Panel
			else C.PanelRaised,
		BackgroundTransparency = if off then 0.4 else 0,
		Text = label,
		TextColor3 = if style == "primary" then C.OnAccent elseif off then C.Dim else C.Text,
		Active = not off,
		Selectable = not off,
	})
	Typography.apply(b, "Button")
	b.TextScaled = false
	corner(b, 6)
	if onPress and not off then
		b.Activated:Connect(onPress)
	end
	return b
end

-- A card: a text column on the left and room for one button on the right. Returns the column.
local function card(parent: Instance, order: number, withButton: boolean): (Frame, Frame)
	local frame = make("Frame", parent, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.PanelRaised,
		BorderSizePixel = 0,
		LayoutOrder = order,
	})
	corner(frame, 6)
	padding(frame, 12)
	local column = make("Frame", frame, {
		Size = UDim2.new(1, if withButton then -(M.CardButton + 12) else 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	list(column, 4)
	local side = make("Frame", frame, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(M.CardButton, M.Tab),
		BackgroundTransparency = 1,
		Visible = withButton,
	})
	return column, side
end

-- One skill line inside a card: key cap, name, a "not built yet" tag on placeholders, and its blurb.
local function skillLine(parent: Instance, key: string, skill: AbilityKit.Skill, order: number)
	local row = make("Frame", parent, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	})
	local top = make("Frame", row, {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
	})
	list(top, 8, true)
	keyCap(top, key, 1)
	local name = text(top, "Action", {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = skill.name,
		LayoutOrder = 2,
	})
	name.TextColor3 = C.Text
	if not skill.built then
		local tag = make("Frame", top, {
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.Track,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		})
		corner(tag, 4)
		make("UIPadding", tag, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
		text(tag, "Label", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = "NOT BUILT YET",
			TextColor3 = C.Muted,
		})
	end
	local blurb = para(row, "Body", skill.blurb, C.Muted)
	blurb.Position = UDim2.fromOffset(34, 26)
	blurb.Size = UDim2.new(1, -34, 0, 0)
	make("UIPadding", row, { PaddingBottom = UDim.new(0, 4) })
end

function MenuController:KnitStart()
	local player = Players.LocalPlayer
	local ability = Knit.GetController("AbilityController")

	local gui = make("ScreenGui", nil, {
		Name = "HT_Menu",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 20,
		IgnoreGuiInset = false,
	})

	-- THE MENU BUTTON, left edge, middle ---------------------------------------------------------------
	local openButton = make("TextButton", gui, {
		Name = "MenuButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, HudTheme.Size.Edge, 0.5, 0),
		Size = UDim2.fromOffset(M.ButtonWidth, M.ButtonHeight),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = HudTheme.Transparency.Panel,
		Text = "",
		Selectable = true,
	})
	corner(openButton, HudTheme.Afk.Corner)
	local buttonScale = make("UIScale", openButton, {})
	text(openButton, "Button", {
		Size = UDim2.new(1, 0, 0.6, 0),
		Position = UDim2.fromScale(0, 0.05),
		Text = "MENU",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local openHint = text(openButton, "Label", {
		Size = UDim2.new(1, 0, 0.4, 0),
		Position = UDim2.fromScale(0, 0.58),
		Text = "kits and shop",
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- THE TOAST ----------------------------------------------------------------------------------------
	local toast = make("Frame", gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = HudTheme.Transparency.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
	})
	corner(toast, 6)
	make("UIPadding", toast, { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) })
	local toastStroke = make("UIStroke", toast, { Thickness = 1.5, Color = C.Accent })
	local toastText = text(toast, "Action", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 51,
	})
	local toastToken = 0
	ability.Notice:Connect(function(message: string, good: boolean)
		toastToken += 1
		local mine = toastToken
		toastText.Text = message
		toastStroke.Color = if good then M.Good else C.Blocked
		toast.Visible = true
		task.delay(M.Toast, function()
			if toastToken == mine then
				toast.Visible = false
			end
		end)
	end)

	-- THE PANEL ----------------------------------------------------------------------------------------
	local backdrop = make("TextButton", gui, {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = M.Backdrop,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
		Modal = true, -- frees the mouse from shift lock while the menu is open
		Visible = false,
		ZIndex = 10,
	})
	local panel = make("Frame", gui, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(M.ScreenShare.X, M.ScreenShare.Y),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 11,
	})
	make("UISizeConstraint", panel, { MaxSize = Vector2.new(M.MaxWidth, M.MaxHeight) })
	corner(panel, M.Corner)
	make("UIStroke", panel, { Color = C.Track, Thickness = 1.5 })
	local panelScale = make("UIScale", panel, {})

	-- Header: title, Coins, close.
	local header = make("Frame", panel, {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, M.Header),
		BackgroundTransparency = 1,
	})
	make("Frame", header, {
		Name = "AccentBar",
		Position = UDim2.new(0, M.Pad, 1, -2),
		Size = UDim2.new(1, -M.Pad * 2, 0, 2),
		BackgroundColor3 = C.Track,
		BorderSizePixel = 0,
	})
	local title = text(header, "Announce", {
		Position = UDim2.fromOffset(M.Pad, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		Text = "MENU",
	})
	title.TextColor3 = C.Accent
	local wallet = make("Frame", header, {
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(M.Header * 1.1 + M.Gap * 2), 0.5, 0),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.PanelRaised,
		BorderSizePixel = 0,
	})
	corner(wallet, 15)
	make("UIPadding", wallet, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) })
	list(wallet, 8, true)
	coin(wallet, 16, 1)
	local coinsText = text(wallet, "StatSmall", {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "0",
		LayoutOrder = 2,
	})

	-- The X: square, 1.1 x the header's height, at its bottom right (vault Field Note "Shared Close
	-- Buttons and Headers Across Many Screens"). Drawn with two bars, no glyph.
	local close = make("TextButton", header, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -M.Gap, 1, -2),
		Size = UDim2.fromScale(0.9, 0.9),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = C.PanelRaised,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
		Selectable = true,
	})
	corner(close, 6)
	for _, angle in { 45, -45 } do
		make("Frame", close, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.55, 0, 0, 3),
			Rotation = angle,
			BackgroundColor3 = C.Text,
			BorderSizePixel = 0,
		})
	end

	-- Body: the tab rail and the page.
	local rail = make("Frame", panel, {
		Name = "Tabs",
		Position = UDim2.fromOffset(M.Pad, M.Header + M.Gap + 4),
		Size = UDim2.new(0, M.Rail, 1, -(M.Header + M.Gap + 4 + M.Pad)),
		BackgroundTransparency = 1,
	})
	list(rail, 6)
	local page = make("ScrollingFrame", panel, {
		Name = "Page",
		Position = UDim2.fromOffset(M.Pad + M.Rail + M.Pad, M.Header + M.Gap + 4),
		Size = UDim2.new(1, -(M.Pad * 3 + M.Rail), 1, -(M.Header + M.Gap + 4 + M.Pad)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Muted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		Selectable = false,
	})
	local content = make("Frame", page, {
		Name = "Content",
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	list(content, 10)

	local current: Tab = "Abilities"
	local isOpen = false
	local settingsState: { [string]: boolean } = { shake = true, flash = true, music = true }
	local tabButtons: { [Tab]: TextButton } = {}

	local function clearPage()
		for _, child in content:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	local function heading(value: string, order: number)
		local label = text(content, "Button", {
			Size = UDim2.new(1, 0, 0, 24),
			Text = value,
			LayoutOrder = order,
		})
		label.TextColor3 = C.Accent
	end

	local function kitCard(
		kit: AbilityKit.Kit,
		order: number,
		buttonLabel: string?,
		style: string,
		onPress: (() -> ())?
	)
		local column, side = card(content, order, buttonLabel ~= nil)
		-- Named, so a test can find "Content.<kit id>.Side.Action".
		local cardFrame = column.Parent :: Frame
		cardFrame.Name = kit.id
		side.Name = "Side"
		text(column, "Button", {
			Size = UDim2.new(1, 0, 0, 22),
			Text = kit.name,
			LayoutOrder = 1,
		})
		para(column, "Body", kit.blurb, C.Muted, 2)
		skillLine(column, "Q", kit.mobility, 3)
		skillLine(column, "R", kit.attack, 4)
		if buttonLabel then
			local b = button(side, buttonLabel, style, onPress)
			b.Name = "Action"
			b.Size = UDim2.fromScale(1, 1)
		end
	end

	local function drawAbilities()
		local wearing = ability:GetKitId()
		local owned = ability:GetOwned()
		local inRound = player:GetAttribute("HT_InRound") == true
		heading("Equipped", 1)
		kitCard(book.Kits[wearing], 2, nil, "off", nil)
		heading("Your kits", 3)
		local order = 4
		for _, kitId in book.Order do
			if owned[kitId] and kitId ~= wearing then
				local kit = book.Kits[kitId]
				if inRound then
					kitCard(kit, order, "In a round", "off", nil)
				else
					kitCard(kit, order, "Equip", "primary", function()
						ability:Equip(kitId)
					end)
				end
				order += 1
			end
		end
		if order == 4 then
			para(
				content,
				"Body",
				"You only own the Base kit. Buy more in the Shop.",
				C.Muted,
				order
			)
		end
	end

	local function drawShop()
		local owned = ability:GetOwned()
		local coins = ability:GetCoins()
		heading("Ability kits", 1)
		para(content, "Body", "Each kit gives you a new Q (mobility) and R (attack).", C.Muted, 2)
		local order = 3
		for _, kitId in book.Order do
			local kit = book.Kits[kitId]
			if kit.price > 0 then
				if owned[kitId] then
					kitCard(kit, order, "Owned", "off", nil)
				elseif coins >= kit.price then
					kitCard(kit, order, `Buy for {kit.price}`, "primary", function()
						ability:Buy(kitId)
					end)
				else
					kitCard(kit, order, `{kit.price} Coins`, "off", nil)
				end
				order += 1
			end
		end
	end

	local function drawPasses()
		heading("Game passes", 1)
		para(content, "Body", "Placeholders: nothing here is for sale yet.", C.Muted, 2)
		for index, pass in PASSES do
			local column, side = card(content, 2 + index, true)
			text(
				column,
				"Button",
				{ Size = UDim2.new(1, 0, 0, 22), Text = pass.name, LayoutOrder = 1 }
			)
			para(column, "Body", pass.blurb, C.Muted, 2)
			button(side, "Coming soon", "off", nil).Size = UDim2.fromScale(1, 1)
		end
	end

	local function drawSettings()
		heading("Settings", 1)
		para(content, "Body", "Placeholders: these switches don't change anything yet.", C.Muted, 2)
		for index, setting in SETTINGS do
			local column, side = card(content, 2 + index, true)
			text(
				column,
				"Button",
				{ Size = UDim2.new(1, 0, 0, 22), Text = setting.name, LayoutOrder = 1 }
			)
			para(column, "Body", setting.blurb, C.Muted, 2)
			local on = settingsState[setting.id]
			local b = button(
				side,
				if on then "On" else "Off",
				if on then "primary" else "plain",
				function()
					settingsState[setting.id] = not settingsState[setting.id]
					MenuController._redraw()
				end
			)
			b.Size = UDim2.fromScale(1, 1)
		end
		heading("Progress", 10)
		local saving = ability:IsReady() and not ability:IsTemporary()
		para(
			content,
			"Body",
			if not ability:IsReady()
				then "Loading your data..."
				elseif saving then "Your Coins and kits are saved."
				else "Not saving this session (no data access here, or it failed to load). Changes are lost when you leave.",
			if saving then M.Good else C.AccentHot,
			11
		)
	end

	local function paintTabs()
		for tab, b in tabButtons do
			local on = tab == current
			b.BackgroundColor3 = if on then C.Accent else C.PanelRaised
			b.TextColor3 = if on then C.OnAccent else C.Text
		end
	end

	local function redraw()
		coinsText.Text = tostring(ability:GetCoins())
		if not isOpen then
			return
		end
		local keep = page.CanvasPosition
		clearPage()
		if current == "Abilities" then
			drawAbilities()
		elseif current == "Shop" then
			drawShop()
		elseif current == "Passes" then
			drawPasses()
		else
			drawSettings()
		end
		paintTabs()
		page.CanvasPosition = keep
	end
	MenuController._redraw = redraw

	for index, tab in TABS do
		local b = make("TextButton", rail, {
			Name = tab,
			Size = UDim2.new(1, 0, 0, M.Tab),
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Text = tab,
			LayoutOrder = index,
			Selectable = true,
		})
		Typography.apply(b, "Button")
		corner(b, 6)
		b.Activated:Connect(function()
			if current ~= tab then
				current = tab
				page.CanvasPosition = Vector2.zero
				redraw()
			end
		end)
		tabButtons[tab] = b
	end

	-- OPEN AND CLOSE -----------------------------------------------------------------------------------
	local function onCloseKey(
		_name: string,
		inputState: Enum.UserInputState
	): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			MenuController._setOpen(false)
		end
		return Enum.ContextActionResult.Sink -- every state, so the release never reaches the dash
	end

	local function setOpen(open: boolean)
		if open == isOpen then
			return
		end
		isOpen = open
		backdrop.Visible = open
		panel.Visible = open
		openButton.BackgroundColor3 = if open then C.Accent else C.Panel
		openButton.BackgroundTransparency = if open then 0 else HudTheme.Transparency.Panel
		for _, child in openButton:GetChildren() do
			if child:IsA("TextLabel") then
				child.TextColor3 = if open
					then C.OnAccent
					elseif child == openHint then C.Muted
					else C.Text
			end
		end
		if open then
			ContextActionService:BindActionAtPriority(
				CLOSE_ACTION,
				onCloseKey,
				false,
				Enum.ContextActionPriority.High.Value + 1,
				Enum.KeyCode.ButtonB
			)
			redraw()
			if not GuiService.ReducedMotionEnabled then
				panelScale.Scale = 0.94
				TweenService:Create(
					panelScale,
					TweenInfo.new(M.Open, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{
						Scale = 1,
					}
				):Play()
			end
			if
				UserInputService.GamepadEnabled
				and UserInputService:GetLastInputType().Name:match("Gamepad")
			then
				GuiService.SelectedObject = tabButtons[current]
			end
		else
			ContextActionService:UnbindAction(CLOSE_ACTION)
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
		end
	end
	MenuController._setOpen = setOpen

	openButton.Activated:Connect(function()
		setOpen(not isOpen)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	-- A press outside the panel closes it. Checked by position: the panel (an Active frame) doesn't stop
	-- the backdrop button under it from getting Activated (measured in Play, 2026-11-12).
	backdrop.Activated:Connect(function(input: InputObject)
		local at = Vector2.new(input.Position.X, input.Position.Y)
		local low, size = panel.AbsolutePosition, panel.AbsoluteSize
		local inside = at.X >= low.X
			and at.Y >= low.Y
			and at.X <= low.X + size.X
			and at.Y <= low.Y + size.Y
		if not inside then
			setOpen(false)
		end
	end)
	ContextActionService:BindAction(
		TOGGLE_ACTION,
		function(_name: string, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				setOpen(not isOpen)
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.M
	)

	-- The hint under MENU names the key on a keyboard.
	local function hint()
		local last = UserInputService:GetLastInputType()
		openHint.Text = if last == Enum.UserInputType.Touch or last.Name:match("Gamepad")
			then "kits and shop"
			else "press M"
	end
	UserInputService.LastInputTypeChanged:Connect(hint)
	hint()

	-- Same scale rule as the AFK button: the window against 1280 x 720, kept readable.
	local function layout()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else HudTheme.Scale.Reference
		local ref = HudTheme.Scale.Reference
		buttonScale.Scale = math.clamp(
			math.min(view.X / ref.X, view.Y / ref.Y),
			HudTheme.Scale.Min,
			HudTheme.Scale.Max
		)
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	layout()

	ability.InventoryChanged:Connect(redraw)
	ability.KitChanged:Connect(redraw)
	player:GetAttributeChangedSignal("HT_InRound"):Connect(redraw)
	redraw()
	gui.Parent = player:WaitForChild("PlayerGui")
end

--- Opens or closes the menu (for tests and other controllers).
function MenuController:SetOpen(open: boolean)
	if self._setOpen then
		self._setOpen(open)
	end
end

return MenuController
