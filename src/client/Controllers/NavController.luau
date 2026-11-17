--!strict
-- NavController - how you get around outside a fight (Ringside, 2026-11-16; drawn in the vault's UI Research/
-- ringside-prototype.html and approved there). It replaces the single MENU button and the stack of AFK and
-- Spectate buttons at the top left.
--
-- IN THE LOBBY, on the left edge:
--   four square illustrated buttons: Shop, Classes, Ranked, Moves (keys 1 to 4), and under them
--   MORE, which opens a drawer: Cosmetics, Profile, Leaderboards, Emotes, Settings, Codes, and two rows, AFK (a
--   switch) and Spectate.
-- IN A ROUND all of that folds away into one small button at the top left, which offers only what is allowed
-- mid-fight: Settings and the controls guide. The match never pauses. Q and R are HudController's and stay.
--
-- This is a LAUNCHER. It owns no feature: Shop / Classes / Cosmetics open MenuController's shared window on
-- that page, Settings its small panel, Moves the HUD's controls guide, AFK asks the server (AfkToggle, as the
-- old button did), Spectate opens SpectateController's panel. Destinations the game doesn't have yet (Ranked,
-- Profile, Leaderboards, Emotes, Codes) are shown with a SOON tag and only say so when pressed.
--
-- Every icon is a placeholder from Ui/Icons. Phones get their own arrangement (a two-by-two block, upper left,
-- clear of the thumbstick). NOT YET: gamepad focus order, and the emote wheel (there are no emotes).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Components = require(script.Parent.Parent.Ui.Components)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)
local Icons = require(script.Parent.Parent.Ui.Icons)

local SP = Tokens.space
local colour = Tokens.colour
local make, text = Components.make, Components.text

local IN_ROUND = "HT_InRound"
local AFK = "HT_AFK"
local EDGE = 22
local BIG = 92 -- a square navigation button
local GAP = 14
local MORE_H = 40
local SMALL = Vector2.new(88, 76) -- a drawer tile
local DRAWER_W = 3 * 88 + 2 * 8 + 2 * 12
local FIGHT_BUTTON = 46

type Entry = { id: string, label: string, icon: string, key: Enum.KeyCode?, soon: boolean? }

-- The four on the left. (The owner asked for Emotes to give its place to something that exists: the moves guide.)
local MAIN: { Entry } = {
	{ id = "shop", label = "Shop", icon = "shop", key = Enum.KeyCode.One },
	{ id = "classes", label = "Classes", icon = "classes", key = Enum.KeyCode.Two },
	{ id = "ranked", label = "Ranked", icon = "ranked", key = Enum.KeyCode.Three, soon = true },
	{ id = "moves", label = "Moves", icon = "training", key = Enum.KeyCode.Four },
}
-- The drawer's grid, three across.
local MORE: { Entry } = {
	{ id = "cosmetics", label = "Cosmetics", icon = "cosmetics" },
	{ id = "profile", label = "Profile", icon = "profile", soon = true },
	{ id = "leaders", label = "Leaders", icon = "leaders", soon = true },
	{ id = "emotes", label = "Emotes", icon = "emote", soon = true },
	{ id = "settings", label = "Settings", icon = "settings" },
	{ id = "codes", label = "Codes", icon = "codes", soon = true },
}
local KEY_NAMES: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.One] = "1",
	[Enum.KeyCode.Two] = "2",
	[Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.Four] = "4",
}
local SOON_NAMES = {
	ranked = "Ranked",
	profile = "Your profile",
	leaders = "Leaderboards",
	emotes = "Emotes",
	codes = "Codes",
}

local NavController = Knit.CreateController({
	Name = "NavController",
})

-- A sticker button that lifts under the pointer and drops onto its lip while held.
local function pressable(sticker: Components.Sticker, onPress: () -> ())
	local face = sticker.face :: TextButton
	local rest = UDim2.fromOffset(0, 0)
	local down = false
	local function to(y: number, duration: string)
		HudMotion.play(face, "press", { Position = UDim2.fromOffset(0, y) }, duration, "enter")
	end
	face.MouseEnter:Connect(function()
		if not down then
			to(-2, "quick")
		end
	end)
	face.MouseLeave:Connect(function()
		down = false
		to(rest.Y.Offset, "release")
	end)
	face.MouseButton1Down:Connect(function()
		down = true
		to(math.max(sticker.depth - 2, 0), "press")
	end)
	face.MouseButton1Up:Connect(function()
		down = false
		to(rest.Y.Offset, "release")
	end)
	face.Activated:Connect(onPress)
end

-- A small tag in a corner: a key cap, or SOON.
local function tag(parent: Instance, value: string, fill: string, ink: string): Frame
	local cap = make("Frame", parent, {
		Name = "Tag",
		BackgroundColor3 = colour(fill),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 5,
	})
	Components.corner(cap, "s")
	make("UIStroke", cap, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = colour("ink.950"),
		Thickness = 2,
	})
	make("UIPadding", cap, { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) })
	local label = text(cap, "label", ink, {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = value,
		ZIndex = 6,
	})
	label.TextSize = 12
	return cap
end

type Tile = { sticker: Components.Sticker, icon: ImageLabel, label: TextLabel, key: Frame? }

-- A square tile: the illustration, a short label under it, a key cap or SOON in a corner.
local function tile(
	parent: Instance,
	entry: Entry,
	size: Vector2,
	depth: number,
	onPress: () -> ()
): Tile
	local sticker = Components.sticker(parent, {
		Name = entry.id,
		Size = UDim2.fromOffset(size.X, size.Y),
	}, { button = true, depth = depth, radius = if size.X >= BIG then "l" else "m" })
	local big = size.X >= BIG
	local iconSize = math.floor(size.Y * (if big then 0.58 else 0.52))
	local icon =
		Icons.image(sticker.face, entry.icon, iconSize, UDim2.new(0.5, 0, 0, iconSize / 2 + 5))
	icon.ZIndex = 3
	local label = text(sticker.face, "label", "ivory.50", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, if big then -8 else -6),
		Size = UDim2.new(1, 0, 0, 14),
		Text = string.upper(entry.label),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})
	label.TextSize = if big then 14 else 12
	local key: Frame? = nil
	if entry.soon then
		icon.ImageTransparency = 0.45
		label.TextColor3 = colour("stone.300")
		local soon = tag(sticker.holder, "SOON", "gold.400", "ink.950")
		soon.AnchorPoint = Vector2.new(1, 0)
		soon.Position = UDim2.new(1, 6, 0, -6)
	elseif entry.key then
		local cap =
			tag(sticker.holder, KEY_NAMES[entry.key] or entry.key.Name, "ivory.50", "ink.950")
		cap.Position = UDim2.fromOffset(-6, -6)
		key = cap
	end
	pressable(sticker, onPress)
	return { sticker = sticker, icon = icon, label = label, key = key }
end

function NavController:KnitStart()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local menu = Knit.GetController("MenuController")
	local hud = Knit.GetController("HudController")
	local spectate = Knit.GetController("SpectateController")
	local ability = Knit.GetController("AbilityController")
	local afkToggle = if GameConfig.Round.Enabled and GameConfig.Round.AfkEnabled
		then Net.client("AfkToggle")
		else nil

	local gui = make("ScreenGui", nil, {
		Name = "HT_Nav",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 19, -- over the HUD and the ultimate bar, under the shared window (20)
	})

	-- The old AFK button's whole ScreenGui goes: the drawer's switch does its job now. Its controller keeps
	-- running (it owns nothing but the button), so nothing else changes.
	local function hideOld(child: Instance)
		if child.Name == "HT_Afk" and child:IsA("ScreenGui") then
			child.Enabled = false
		end
	end
	for _, child in playerGui:GetChildren() do
		hideOld(child)
	end
	playerGui.ChildAdded:Connect(hideOld)

	local open = false -- the drawer
	local fightOpen = false -- the small menu in a round
	local setDrawer: (boolean) -> ()

	local function soon(id: string)
		ability.Notice:Fire(`{SOON_NAMES[id] or "This"} isn't in the game yet.`, false)
	end
	local function go(id: string)
		if player:GetAttribute(IN_ROUND) == true and id ~= "settings" and id ~= "moves" then
			ability.Notice:Fire("Locked until the round ends.", false)
			return
		end
		setDrawer(false)
		if id == "shop" then
			menu:Open("Shop")
		elseif id == "classes" then
			menu:Open("Abilities")
		elseif id == "cosmetics" then
			menu:Open("Cosmetics")
		elseif id == "settings" then
			menu:OpenSettings()
		elseif id == "moves" then
			hud:ToggleGuide()
		else
			soon(id)
		end
	end

	-- THE LOBBY COLUMN ---------------------------------------------------------------------------------
	local column = make("Frame", gui, {
		Name = "Column",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, EDGE, 0.5, 0),
		Size = UDim2.fromOffset(BIG, #MAIN * BIG + (#MAIN - 1) * GAP + GAP + MORE_H + 6),
	})
	local columnScale = make("UIScale", column, {})
	local tiles: { Tile } = {}
	for index, entry in MAIN do
		local made = tile(column, entry, Vector2.new(BIG, BIG), 6, function()
			go(entry.id)
		end)
		made.sticker.holder.Position = UDim2.fromOffset(0, (index - 1) * (BIG + GAP))
		tiles[index] = made
	end
	local moreSticker = Components.sticker(column, {
		Name = "More",
		Position = UDim2.fromOffset(0, #MAIN * (BIG + GAP)),
		Size = UDim2.fromOffset(BIG, MORE_H),
	}, { button = true, depth = 4, radius = "m" })
	local moreIcon = Icons.image(moreSticker.face, "more", 22, UDim2.new(0, 22, 0.5, 0))
	moreIcon.ZIndex = 3
	local moreLabel = text(moreSticker.face, "label", "ivory.50", {
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -44, 1, 0),
		Text = "MORE",
		ZIndex = 3,
	})
	moreLabel.TextSize = 14

	-- THE DRAWER -----------------------------------------------------------------------------------------
	local drawer = Components.sticker(gui, {
		Name = "Drawer",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(DRAWER_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, { depth = 0, radius = "l" })
	drawer.face.AutomaticSize = Enum.AutomaticSize.Y
	drawer.face.Size = UDim2.fromScale(1, 0)
	local drawerScale = make("UIScale", drawer.holder, {})
	local body = make("Frame", drawer.face, {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 3,
	})
	make("UIPadding", body, {
		PaddingTop = UDim.new(0, SP[3]),
		PaddingBottom = UDim.new(0, SP[3]),
		PaddingLeft = UDim.new(0, SP[3]),
		PaddingRight = UDim.new(0, SP[3]),
	})
	make(
		"UIListLayout",
		body,
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, SP[2]) }
	)
	local heading = text(body, "label", "stone.300", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Text = "MORE",
		ZIndex = 3,
	})
	heading.TextSize = 13
	local rows = math.ceil(#MORE / 3)
	local grid = make("Frame", body, {
		Name = "Grid",
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, rows * (SMALL.Y + 4) + (rows - 1) * 8 + 2),
		ZIndex = 3,
	})
	for index, entry in MORE do
		local made = tile(grid, entry, SMALL, 4, function()
			go(entry.id)
		end)
		local col, row = (index - 1) % 3, math.floor((index - 1) / 3)
		made.sticker.holder.Position =
			UDim2.fromOffset(col * (SMALL.X + 8), row * (SMALL.Y + 4 + 8))
	end

	-- A drawer row: icon, a name and a line under it, and (AFK) a switch on the right.
	type Row = { button: TextButton, sub: TextLabel, knob: Frame?, track: Frame? }
	local function row(
		order: number,
		icon: string,
		name: string,
		switch: boolean,
		onPress: () -> ()
	): Row
		local button = make("TextButton", body, {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = colour("ink.700"),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 3,
		})
		Components.corner(button, "m")
		make("UIStroke", button, {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = colour("ink.950"),
			Thickness = 2,
		})
		Icons.image(button, icon, 28, UDim2.new(0, 24, 0.5, 0)).ZIndex = 4
		local title = text(button, "label", "ivory.50", {
			Position = UDim2.fromOffset(46, 6),
			Size = UDim2.new(1, -110, 0, 16),
			Text = name,
			ZIndex = 4,
		})
		title.TextSize = 15
		local sub = text(button, "caption", "stone.300", {
			Position = UDim2.fromOffset(46, 23),
			Size = UDim2.new(1, -110, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
		})
		sub.TextSize = 13
		local track: Frame? = nil
		local knob: Frame? = nil
		if switch then
			local t = make("Frame", button, {
				Name = "Switch",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(44, 24),
				BackgroundColor3 = colour("ink.600"),
				BorderSizePixel = 0,
				ZIndex = 4,
			})
			Components.corner(t, "full")
			make("UIStroke", t, { Color = colour("ink.950"), Thickness = 2 })
			local k = make("Frame", t, {
				Name = "Knob",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 4, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = colour("stone.300"),
				BorderSizePixel = 0,
				ZIndex = 5,
			})
			Components.corner(k, "full")
			track, knob = t, k
		end
		button.Activated:Connect(onPress)
		return { button = button, sub = sub, knob = knob, track = track }
	end

	local afkRow: Row? = nil
	if afkToggle then
		afkRow = row(3, "afk", "AFK", true, function()
			if player:GetAttribute(IN_ROUND) ~= true then
				afkToggle:FireServer()
			end
		end)
	end
	local spectateRow = row(4, "spectate", "Spectate", false, function()
		setDrawer(false)
		spectate:Toggle()
	end)
	spectateRow.sub.Text = "Watch the round that is on"

	-- The AFK row says in words what the switch means, as the old button did; the server owns the state.
	local function showAfk()
		local made = afkRow
		if not made then
			return
		end
		local on = player:GetAttribute(AFK) == true
		made.sub.Text = if on then "Sitting out the next rounds" else "Playing the next round"
		local track, knob = made.track :: Frame, made.knob :: Frame
		track.BackgroundColor3 = colour(if on then "teal.400" else "ink.600")
		knob.BackgroundColor3 = colour(if on then "ink.950" else "stone.300")
		HudMotion.play(knob, "switch", {
			Position = UDim2.new(0, if on then 24 else 4, 0.5, 0),
		}, "quick", "enter")
	end
	player:GetAttributeChangedSignal(AFK):Connect(showAfk)
	showAfk()

	-- THE FIGHT BUTTON AND ITS SMALL MENU ------------------------------------------------------------------
	local fightButton = Components.sticker(gui, {
		Name = "FightMenuButton",
		Position = UDim2.fromOffset(EDGE, 12),
		Size = UDim2.fromOffset(FIGHT_BUTTON, FIGHT_BUTTON),
		Visible = false,
	}, { button = true, depth = 4, radius = "m" })
	local fightScale = make("UIScale", fightButton.holder, {})
	Icons.image(fightButton.face, "settings", 28).ZIndex = 3
	local fightMenu = Components.sticker(gui, {
		Name = "FightMenu",
		Position = UDim2.fromOffset(EDGE, 12 + FIGHT_BUTTON + 12),
		Size = UDim2.fromOffset(236, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, { depth = 0, radius = "l" })
	fightMenu.face.AutomaticSize = Enum.AutomaticSize.Y
	fightMenu.face.Size = UDim2.fromScale(1, 0)
	local fightMenuScale = make("UIScale", fightMenu.holder, {})
	local fightBody = make("Frame", fightMenu.face, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 3,
	})
	make("UIPadding", fightBody, {
		PaddingTop = UDim.new(0, SP[2]),
		PaddingBottom = UDim.new(0, SP[3]),
		PaddingLeft = UDim.new(0, SP[2]),
		PaddingRight = UDim.new(0, SP[2]),
	})
	make(
		"UIListLayout",
		fightBody,
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, SP[2]) }
	)
	local function fightRow(order: number, icon: string, name: string, onPress: () -> ())
		local button = make("TextButton", fightBody, {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = colour("ink.700"),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 3,
		})
		Components.corner(button, "m")
		make("UIStroke", button, {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = colour("ink.950"),
			Thickness = 2,
		})
		Icons.image(button, icon, 26, UDim2.new(0, 22, 0.5, 0)).ZIndex = 4
		local label = text(button, "label", "ivory.50", {
			Position = UDim2.fromOffset(44, 0),
			Size = UDim2.new(1, -48, 1, 0),
			Text = name,
			ZIndex = 4,
		})
		label.TextSize = 15
		button.Activated:Connect(onPress)
	end
	local function setFightMenu(want: boolean)
		fightOpen = want
		fightMenu.holder.Visible = want
		Components.paintSticker(
			fightButton,
			if want then "ink.500" else "ink.900",
			if want then "coral.500" else "ink.950"
		)
	end
	fightRow(1, "settings", "Settings", function()
		setFightMenu(false)
		menu:OpenSettings()
	end)
	fightRow(2, "training", "Controls guide", function()
		setFightMenu(false)
		hud:ToggleGuide()
	end)
	local note = text(fightBody, "caption", "stone.300", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 52),
		Text = "The match keeps running. Shop and classes unlock when the round ends.",
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
	})
	note.TextSize = 13
	pressable(fightButton, function()
		setFightMenu(not fightOpen)
	end)

	-- OPEN, CLOSE, LOBBY AND FIGHT ---------------------------------------------------------------------------
	local phone = false
	local function placeDrawer()
		local scale = columnScale.Scale
		local columnSize = column.AbsoluteSize
		local columnPos = column.AbsolutePosition - gui.AbsolutePosition
		if phone then
			drawer.holder.AnchorPoint = Vector2.new(0, 0)
			drawer.holder.Position =
				UDim2.fromOffset(columnPos.X + columnSize.X + 10 * scale, columnPos.Y)
		else
			-- beside the column, its foot level with the MORE button's
			drawer.holder.AnchorPoint = Vector2.new(0, 1)
			drawer.holder.Position = UDim2.fromOffset(
				columnPos.X + columnSize.X + 12 * scale,
				columnPos.Y + columnSize.Y
			)
		end
	end
	setDrawer = function(want: boolean)
		if want == open then
			return
		end
		open = want
		Components.paintSticker(
			moreSticker,
			if want then "ink.500" else "ink.900",
			if want then "coral.500" else "ink.950"
		)
		if want then
			placeDrawer()
			drawer.holder.Visible = true
			-- a short slide out from the column; under reduced motion it simply appears
			if not HudMotion.reduced() then
				local rest = drawer.holder.Position
				drawer.holder.Position = rest - UDim2.fromOffset(18, 0)
				HudMotion.play(drawer.holder, "slide", { Position = rest }, "release", "enter")
			end
		else
			drawer.holder.Visible = false
		end
	end
	pressable(moreSticker, function()
		setDrawer(not open)
	end)

	local function layout()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else HudTheme.Scale.Reference
		local ref = HudTheme.Scale.Reference
		phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		-- sized by the screen's height (the column is tall), never under 0.85 so the labels stay readable
		local scale = math.clamp(view.Y / ref.Y, 0.85, HudTheme.Scale.Max)
		if phone then
			-- a two-by-two block in the upper left, MORE under it: the lower left is the thumbstick's
			scale = math.clamp(view.Y / 390 * 0.64, 0.5, 1)
			column.AnchorPoint = Vector2.new(0, 0)
			column.Position = UDim2.fromOffset(EDGE, 56)
			column.Size = UDim2.fromOffset(BIG * 2 + GAP, BIG * 2 + GAP * 2 + MORE_H + 6)
			for index, made in tiles do
				local col, line = (index - 1) % 2, math.floor((index - 1) / 2)
				made.sticker.holder.Position =
					UDim2.fromOffset(col * (BIG + GAP), line * (BIG + GAP))
				if made.key then
					made.key.Visible = false
				end
			end
			moreSticker.holder.Position = UDim2.fromOffset(0, 2 * (BIG + GAP))
			moreSticker.holder.Size = UDim2.fromOffset(BIG * 2 + GAP, MORE_H)
		else
			-- hard against the left edge for everyone (the owner's Bots and perf tools moved to the right edge)
			column.AnchorPoint = Vector2.new(0, 0.5)
			column.Position = UDim2.new(0, EDGE, 0.5, 0)
			column.Size = UDim2.fromOffset(BIG, #MAIN * BIG + (#MAIN - 1) * GAP + GAP + MORE_H + 6)
			for index, made in tiles do
				made.sticker.holder.Position = UDim2.fromOffset(0, (index - 1) * (BIG + GAP))
				if made.key then
					made.key.Visible = true
				end
			end
			moreSticker.holder.Position = UDim2.fromOffset(0, #MAIN * (BIG + GAP))
			moreSticker.holder.Size = UDim2.fromOffset(BIG, MORE_H)
		end
		columnScale.Scale = scale
		drawerScale.Scale = scale
		fightScale.Scale = math.max(scale, 0.8)
		fightMenuScale.Scale = math.max(scale, 0.8)
		if open then
			placeDrawer()
		end
	end

	local function refresh()
		local inRound = player:GetAttribute(IN_ROUND) == true
		column.Visible = not inRound
		fightButton.holder.Visible = inRound
		if inRound then
			setDrawer(false)
		else
			setFightMenu(false)
		end
		if afkRow then
			afkRow.button.Active = not inRound
		end
	end
	player:GetAttributeChangedSignal(IN_ROUND):Connect(refresh)

	-- 1 to 4 open the four lobby buttons. They pass the key on, so nothing else loses it.
	local keys: { Enum.KeyCode } = {}
	for _, entry in MAIN do
		if entry.key then
			table.insert(keys, entry.key)
		end
	end
	ContextActionService:BindAction(
		"HaymakerNav",
		function(_, state: Enum.UserInputState, input: InputObject)
			if state == Enum.UserInputState.Begin and player:GetAttribute(IN_ROUND) ~= true then
				for _, entry in MAIN do
					if entry.key == input.KeyCode then
						go(entry.id)
					end
				end
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		table.unpack(keys)
	)

	local function watchCamera()
		layout()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	UserInputService.LastInputTypeChanged:Connect(layout)
	watchCamera()
	refresh()
	gui.Parent = playerGui
end

return NavController
