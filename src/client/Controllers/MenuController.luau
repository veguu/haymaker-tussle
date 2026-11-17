--!strict
-- MenuController - the SHARED WINDOW for Shop, Classes and Cosmetics, and the small Settings panel (Ringside,
-- 2026-11-16; drawn in the vault's UI Research/ringside-prototype.html and approved there). There is no MENU
-- button any more: NavController's shortcuts open this window DIRECTLY on the page they name.
--
-- ONE window, three pages side by side (a UIPageLayout, so it snaps to whole pages):
--   Shop       where you GET things. Today: the classes, for Coins. The button is red-orange, carries a coin and
--              the price, and asks you to press it twice (Buy, then Confirm). Passes and Robux items will be more
--              shelves on this page when they exist; nothing is sold for Robux today.
--   Classes    where you CHOOSE what you fight with: every class as a card, the picked one large with its Q and
--              R skills. The button is green and says Equip. It never costs anything. (Tab id "Abilities".)
--   Cosmetics  nothing yet: the game has no cosmetics or emotes. An honest empty page, kept so the three stay
--              together when they exist.
-- Move between pages with the tabs, the two arrows, a sideways swipe on touch, or L1 / R1 on a gamepad. A
-- shortcut lands on its page with no slide. Changing page never buys or equips anything. Only the page you are
-- on is redrawn when your coins or classes change.
--
-- Everything shown comes from AbilityController (the server's attributes); this only asks it to buy or equip.
-- Its notices show as a toast above the bottom of the screen, window open or not. M still opens and closes the
-- window (on the page you last used); so do the X, a click outside, and gamepad B while it is open.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AbilityKit = require(ReplicatedStorage.Shared.Core.AbilityKit)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Typography = require(ReplicatedStorage.Shared.Typography)
local Components = require(script.Parent.Parent.Ui.Components)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)
local Icons = require(script.Parent.Parent.Ui.Icons)

local book: any = Abilities
local M = HudTheme.Menu
local SP = Tokens.space
local colour = Tokens.colour
local make, text = Components.make, Components.text

local TOGGLE_ACTION = "HaymakerMenu"
local CLOSE_ACTION = "HaymakerMenuClose"
local PAGE_ACTION = "HaymakerMenuPage"

type Tab = "Shop" | "Abilities" | "Cosmetics"
local TABS: { Tab } = { "Shop", "Abilities", "Cosmetics" }
local TAB_NAMES: { [Tab]: string } =
	{ Shop = "Shop", Abilities = "Classes", Cosmetics = "Cosmetics" }
local TAB_ICONS: { [Tab]: string } =
	{ Shop = "shop", Abilities = "classes", Cosmetics = "cosmetics" }

local SETTINGS = {
	{ id = "shake", name = "Camera shake" },
	{ id = "flash", name = "Hit flash" },
	{ id = "music", name = "Music" },
}

local HEADER = 68
local DETAIL = Vector2.new(250, 330) -- the picked class's panel: least and most width
local CELL = Vector2.new(150, 170) -- a class card: least width, height
local LIP = 5

local MenuController = Knit.CreateController({
	Name = "MenuController",
})

local function classTone(kitId: string): string
	local name = `class.{kitId}`
	return if Tokens.hex[name] then name else "line.300"
end

-- A skill's cooldown in seconds, from where the game keeps it, or nil when it has none listed.
local function cooldownOf(skillId: string): number?
	if skillId == "Dash" then
		return GameConfig.Movement.PropelCooldown
	elseif skillId == "Uppercut" then
		return GameConfig.Uppercut.Cooldown
	end
	local own = book[skillId] or book.KitMoves[skillId] or book.KitSwings[skillId]
	return if typeof(own) == "table" and typeof(own.Cooldown) == "number" then own.Cooldown else nil
end

local function seconds(value: number): string
	return if value % 1 == 0 then `{value} s` else string.format("%.1f s", value)
end

local function small(label: TextLabel, size: number): TextLabel
	label.TextSize = size
	return label
end

local function para(
	parent: Instance,
	role: string,
	tone: string,
	value: string,
	order: number?
): TextLabel
	return text(parent, role, tone, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = value,
		LayoutOrder = order or 0,
	})
end

local function pad(parent: Instance, amount: number)
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

local function outline(parent: Instance, tone: string, thickness: number): UIStroke
	return make("UIStroke", parent, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = colour(tone),
		Thickness = thickness,
	})
end

-- A small tag: EQUIPPED (green), OWNED (quiet), a price (yellow).
local function chip(
	parent: Instance,
	value: string,
	fill: string,
	ink: string,
	coin: boolean?
): Frame
	local frame = make("Frame", parent, {
		Name = "Chip",
		BackgroundColor3 = colour(fill),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	Components.corner(frame, "s")
	outline(frame, "ink.950", 2)
	make("UIPadding", frame, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 7) })
	list(frame, 4, true)
	if coin then
		local image = Icons.image(frame, "coin", 13)
		image.AnchorPoint = Vector2.zero
		image.LayoutOrder = 1
	end
	small(
		text(frame, "label", ink, {
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = value,
			LayoutOrder = 2,
		}),
		12
	)
	return frame
end

-- The button looks: a fill, its lettering, and the lip it sits on (nil: flat, can't be pressed).
local BUTTON = {
	buy = { fill = "coral.500", ink = "ink.950", lip = "coral.700" }, -- spend: red-orange, with a coin
	equip = { fill = "teal.400", ink = "ink.950", lip = "teal.700" }, -- choose: green, free
	plain = { fill = "ink.500", ink = "ivory.50", lip = "ink.950" },
	off = { fill = "ink.600", ink = "stone.500", lip = nil },
}

-- A button on a lip; it drops onto the lip while held. "off" is flat and can't be pressed.
local function button(
	parent: Instance,
	label: string,
	style: string,
	onPress: (() -> ())?,
	coin: boolean?
): TextButton
	local look = (BUTTON :: any)[style]
	local off = look.lip == nil
	local b = make("TextButton", parent, {
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = colour(look.fill),
		Text = if coin then "     " .. label else label,
		TextColor3 = colour(look.ink),
		Active = not off,
		Selectable = not off,
		ZIndex = 2,
	})
	Typography.apply(b, "button")
	Components.corner(b, "m")
	outline(b, if off then "ink.700" else "ink.950", 3)
	if coin then
		-- the coin sits just left of the centred words
		local image = Icons.image(b, "coin", 18, UDim2.new(0.5, -(#label * 4.6 + 12), 0.5, 0))
		image.ZIndex = 3
	end
	if not off then
		local lip = make("Frame", b, {
			Name = "Lip",
			BackgroundColor3 = colour(look.lip),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -6),
			Size = UDim2.new(1, 0, 0, LIP + 6),
			ZIndex = 1,
		})
		Components.corner(lip, "m")
		outline(lip, "ink.950", 3)
		local isDown = false
		local function set(down: boolean)
			if isDown == down then
				return
			end
			isDown = down
			if HudMotion.reduced() then
				return
			end
			b.Position = b.Position + UDim2.fromOffset(0, if down then 3 else -3)
			lip.Size = UDim2.new(1, 0, 0, if down then LIP + 3 else LIP + 6)
		end
		b.MouseButton1Down:Connect(function()
			set(true)
		end)
		b.MouseButton1Up:Connect(function()
			set(false)
		end)
		b.MouseLeave:Connect(function()
			set(false)
		end)
		if onPress then
			b.Activated:Connect(onPress)
		end
	end
	return b
end

-- One skill in the detail panel: its icon with the key on it, the name, the cooldown, what it does.
local function skillRow(
	parent: Instance,
	key: string,
	icon: string,
	skill: AbilityKit.Skill,
	order: number
)
	local row = make("Frame", parent, {
		Name = key,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = colour("ink.700"),
		BorderSizePixel = 0,
		LayoutOrder = order,
	})
	Components.corner(row, "m")
	outline(row, "ink.950", 2)
	pad(row, SP[2])
	local art = make("Frame", row, {
		Name = "Art",
		BackgroundColor3 = colour("ink.900"),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(42, 42),
	})
	Components.corner(art, "s")
	outline(art, "ink.950", 2)
	Icons.image(art, icon, 30)
	local cap = make("Frame", art, {
		BackgroundColor3 = colour("ivory.50"),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-6, -6),
		Size = UDim2.fromOffset(18, 17),
		ZIndex = 2,
	})
	Components.corner(cap, "s")
	outline(cap, "ink.950", 2)
	small(
		text(cap, "label", "ink.950", {
			Size = UDim2.fromScale(1, 1),
			Text = key,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		}),
		12
	)
	local wait = cooldownOf(skill.id)
	small(
		text(row, "label", "ivory.50", {
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -108, 0, 18),
			Text = string.upper(skill.name),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		15
	)
	small(
		text(row, "label", "ivory.50", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(56, 18),
			Text = if not skill.built then "SOON" elseif wait then seconds(wait) else "",
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		14
	)
	local blurb = para(row, "caption", "stone.300", skill.blurb)
	blurb.Position = UDim2.fromOffset(52, 20)
	blurb.Size = UDim2.new(1, -52, 0, 0)
	blurb.TextSize = 13
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

	-- THE TOAST ----------------------------------------------------------------------------------------
	local toast = make("Frame", gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(0, 42),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = colour("ink.900"),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
	})
	Components.corner(toast, "m")
	make(
		"UIPadding",
		toast,
		{ PaddingLeft = UDim.new(0, SP[4]), PaddingRight = UDim.new(0, SP[4]) }
	)
	local toastStroke = outline(toast, "teal.400", 3)
	local toastText = text(toast, "body.strong", "ivory.50", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 51,
	})
	local toastToken = 0
	ability.Notice:Connect(function(message: string, good: boolean)
		toastToken += 1
		local mine = toastToken
		-- a refusal carries a "!" as well as the red border
		toastText.Text = if good then message else `!  {message}`
		toastStroke.Color = colour(if good then "teal.400" else "danger.600")
		toast.Visible = true
		task.delay(M.Toast, function()
			if toastToken == mine then
				toast.Visible = false
			end
		end)
	end)

	-- THE WINDOW ---------------------------------------------------------------------------------------
	local backdrop = make("TextButton", gui, {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colour("ink.950"),
		BackgroundTransparency = M.Backdrop,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
		Modal = true, -- frees the mouse from shift lock while the window is open
		Visible = false,
		ZIndex = 10,
	})
	local window = Components.sticker(gui, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -4),
		Size = UDim2.fromScale(M.ScreenShare.X, M.ScreenShare.Y),
		Visible = false,
		ZIndex = 11,
	}, { depth = 10, radius = "l" })
	local panel = window.face :: Frame
	panel.Active = true
	local panelScale = make("UIScale", window.holder, {})

	-- Header: arrows, the three page tabs, Coins, close.
	local header = make("Frame", panel, {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundColor3 = colour("ink.600"),
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	Components.corner(header, "l")
	make("Frame", header, { -- squares off the header's lower corners and draws the rule under it
		Name = "Foot",
		BackgroundColor3 = colour("ink.600"),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -12),
		Size = UDim2.new(1, 0, 0, 12),
	})
	make("Frame", header, {
		Name = "Rule",
		BackgroundColor3 = colour("ink.950"),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 4,
	})
	local rail = make("Frame", header, {
		Name = "Tabs",
		Position = UDim2.fromOffset(SP[3], 0),
		Size = UDim2.new(0, 0, 1, -LIP),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 4,
	})
	list(rail, SP[2], true)

	local function headerButton(
		parent: Instance,
		name: string,
		width: number,
		order: number
	): TextButton
		local b = make("TextButton", parent, {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(width, 46),
			BackgroundColor3 = colour("ink.700"),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Selectable = true,
			ZIndex = 4,
		})
		Components.corner(b, "m")
		outline(b, "ink.950", 3)
		return b
	end
	local prevButton = headerButton(rail, "Previous", 34, 0)
	small(
		text(prevButton, "title", "ivory.50", {
			Size = UDim2.fromScale(1, 1),
			Text = "<",
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 5,
		}),
		20
	)
	local nextButton = headerButton(rail, "Next", 34, 9)
	small(
		text(nextButton, "title", "ivory.50", {
			Size = UDim2.fromScale(1, 1),
			Text = ">",
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 5,
		}),
		20
	)

	local closeSize = 44
	local close = make("TextButton", header, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -SP[3], 0.5, -2),
		Size = UDim2.fromOffset(closeSize, closeSize),
		BackgroundColor3 = colour("danger.600"),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 4,
	})
	Components.corner(close, "m")
	outline(close, "ink.950", 3)
	for _, angle in { 45, -45 } do
		make("Frame", close, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.55, 0, 0, 4),
			Rotation = angle,
			BackgroundColor3 = colour("ivory.50"),
			BorderSizePixel = 0,
			ZIndex = 5,
		})
	end
	local wallet = make("Frame", header, {
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(SP[3] + closeSize + SP[3]), 0.5, -2),
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = colour("ink.900"),
		BorderSizePixel = 0,
		ZIndex = 4,
	})
	Components.corner(wallet, "m")
	outline(wallet, "ink.950", 3)
	make(
		"UIPadding",
		wallet,
		{ PaddingLeft = UDim.new(0, SP[3]), PaddingRight = UDim.new(0, SP[3]) }
	)
	list(wallet, SP[2], true)
	local walletCoin = Icons.image(wallet, "coin", 20)
	walletCoin.AnchorPoint = Vector2.zero
	walletCoin.LayoutOrder = 1
	walletCoin.ZIndex = 5
	local coinsText = text(wallet, "StatSmall", "ivory.50", {
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "0",
		LayoutOrder = 2,
		ZIndex = 5,
	})

	-- The pages: a clipping view and three frames laid side by side by a UIPageLayout.
	local view = make("Frame", panel, {
		Name = "View",
		Position = UDim2.fromOffset(3, HEADER + 3),
		Size = UDim2.new(1, -6, 1, -(HEADER + 6)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
	})
	local pager = make("UIPageLayout", view, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		EasingStyle = Enum.EasingStyle.Quart,
		EasingDirection = Enum.EasingDirection.Out,
		TweenTime = 0.23,
		Circular = false,
		TouchInputEnabled = true, -- a sideways swipe changes page
		ScrollWheelInputEnabled = false, -- the wheel belongs to the lists
		GamepadInputEnabled = false, -- L1 / R1 are bound below, so the stick stays free to move focus
	})
	local pages: { [Tab]: Frame } = {}
	for index, tab in TABS do
		local page = make("Frame", view, {
			Name = tab,
			LayoutOrder = index,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true, -- a page never shows through into its neighbour
		})
		pad(page, SP[4])
		pages[tab] = page
	end
	local dots = make("Frame", panel, {
		Name = "Dots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.fromOffset(#TABS * 28, 5),
		BackgroundTransparency = 1,
		ZIndex = 6,
	})
	local dotFrames: { Frame } = {}
	for index in TABS do
		local dot = make("Frame", dots, {
			Position = UDim2.fromOffset((index - 1) * 28, 0),
			Size = UDim2.fromOffset(22, 5),
			BackgroundColor3 = colour("line.300"),
			BorderSizePixel = 0,
			ZIndex = 6,
		})
		Components.corner(dot, "full")
		dotFrames[index] = dot
	end

	-- A class page (Shop and Classes share it): cards in a grid that scrolls, the picked one large beside it.
	type ClassPage = {
		grid: ScrollingFrame,
		gridContent: Frame,
		gridLayout: UIGridLayout,
		detail: Frame,
		detailContent: Frame,
		detailFoot: Frame,
		title: TextLabel,
	}
	local function classPage(page: Frame): ClassPage
		local title = small(
			text(page, "label", "stone.300", {
				Name = "Title",
				Size = UDim2.new(1, 0, 0, 16),
			}),
			13
		)
		local grid = make("ScrollingFrame", page, {
			Name = "Grid",
			Position = UDim2.fromOffset(0, 24),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = colour("line.300"),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Selectable = false,
		})
		local gridContent = make("Frame", grid, {
			Name = "Content",
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -14, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		local gridLayout = make("UIGridLayout", gridContent, {
			CellPadding = UDim2.fromOffset(SP[3], SP[3]),
			CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local detail = make("Frame", page, {
			Name = "Detail",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, DETAIL.Y, 1, -6),
			BackgroundColor3 = colour("ink.600"),
			BorderSizePixel = 0,
		})
		Components.corner(detail, "l")
		outline(detail, "ink.950", 3)
		local scroll = make("ScrollingFrame", detail, {
			Name = "Scroll",
			Position = UDim2.fromOffset(SP[3], SP[3]),
			Size = UDim2.new(1, -SP[3] * 2, 1, -(SP[3] * 3 + M.Tab + LIP)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = colour("line.300"),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Selectable = false,
		})
		local detailContent = make("Frame", scroll, {
			Name = "Content",
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -18, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		list(detailContent, SP[2])
		local detailFoot = make("Frame", detail, {
			Name = "Side",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, SP[3], 1, -(SP[3] + LIP)),
			Size = UDim2.new(1, -SP[3] * 2, 0, M.Tab),
			BackgroundTransparency = 1,
		})
		return {
			grid = grid,
			gridContent = gridContent,
			gridLayout = gridLayout,
			detail = detail,
			detailContent = detailContent,
			detailFoot = detailFoot,
			title = title,
		}
	end
	local shopPage = classPage(pages.Shop)
	local classesPage = classPage(pages.Abilities)

	-- Cosmetics: nothing to show yet, said plainly.
	do
		local empty = make("Frame", pages.Cosmetics, {
			Name = "Empty",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(420, 220),
			BackgroundTransparency = 1,
		})
		local icon = Icons.image(empty, "cosmetics", 96, UDim2.new(0.5, 0, 0, 56))
		icon.ImageTransparency = 0.25
		text(empty, "headline", "ivory.50", {
			Position = UDim2.fromOffset(0, 116),
			Size = UDim2.new(1, 0, 0, 32),
			Text = "NOTHING HERE YET",
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local line = para(
			empty,
			"body",
			"stone.300",
			"Cosmetics and emotes aren't in the game yet. When they are, what you own will live here."
		)
		line.Position = UDim2.fromOffset(0, 152)
		line.TextXAlignment = Enum.TextXAlignment.Center
	end

	-- The detail panel takes about a third of the page; the cards share the rest in two to four columns.
	local function fit(made: ClassPage, page: Frame)
		local width = page.AbsoluteSize.X / math.max(panelScale.Scale, 0.01) - SP[4] * 2
		if width <= 0 then
			return
		end
		local detailWidth = math.clamp(math.floor(width * 0.34), DETAIL.X, DETAIL.Y)
		made.detail.Size = UDim2.new(0, detailWidth, 1, -6)
		made.grid.Size = UDim2.new(1, -(detailWidth + SP[4]), 1, -30)
		local room = width - detailWidth - SP[4] - 14
		local columns = math.clamp(math.floor((room + SP[3]) / (CELL.X + SP[3])), 2, 4)
		local cell = math.floor((room - (columns - 1) * SP[3]) / columns)
		made.gridLayout.CellSize = UDim2.fromOffset(cell, CELL.Y)
	end

	local current: Tab = "Abilities"
	local isOpen = false
	local settingsOpen = false
	local settingsState: { [string]: boolean } = { shake = true, flash = true, music = true }
	local tabButtons: { [Tab]: TextButton } = {}
	local tabLabels: { [Tab]: TextLabel } = {}
	local picked: { [Tab]: string? } = {}
	local confirming: string? = nil -- the class whose Buy was pressed once

	local function clear(holder: Instance)
		for _, child in holder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function standing(kitId: string, wearing: string, owned: { [string]: boolean }): string
		return if kitId == wearing then "EQUIPPED" elseif owned[kitId] then "OWNED" else "NOT OWNED"
	end
	local function stateChip(parent: Instance, kit: AbilityKit.Kit, state: string): Frame
		if state == "EQUIPPED" then
			return chip(parent, "EQUIPPED", "teal.400", "ink.950")
		elseif state == "OWNED" then
			return chip(parent, "OWNED", "ink.500", "ivory.50")
		end
		return chip(parent, tostring(kit.price), "gold.400", "ink.950", true)
	end

	-- A class card: its colour and emblem, its name, its two skills, and where you stand with it.
	local function classCard(
		made: ClassPage,
		kit: AbilityKit.Kit,
		order: number,
		isPicked: boolean,
		state: string,
		dim: boolean,
		onPick: () -> ()
	)
		local tone = classTone(kit.id)
		local card = make("TextButton", made.gridContent, {
			Name = kit.id,
			BackgroundColor3 = colour(if isPicked then "ink.500" else "ink.700"),
			BackgroundTransparency = if dim then 0.35 else 0,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = order,
			Selectable = true,
		})
		Components.corner(card, "l")
		outline(card, if isPicked then "ivory.50" else "ink.950", 3)
		local art = make("Frame", card, {
			Name = "Art",
			Position = UDim2.fromOffset(9, 9),
			Size = UDim2.new(1, -18, 1, -92),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		})
		Components.corner(art, "m")
		outline(art, "ink.950", 2)
		make("UIGradient", art, {
			Color = ColorSequence.new(colour(tone), colour("ink.900")),
			Rotation = 55,
		})
		local emblem = Icons.image(art, `class_{kit.id}`, 56)
		emblem.ImageTransparency = if dim then 0.4 else 0
		text(card, "title", if dim then "stone.300" else "ivory.50", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -54),
			Size = UDim2.new(1, -20, 0, 22),
			Text = string.upper(kit.name),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		small(
			text(card, "caption", "stone.300", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 10, 1, -36),
				Size = UDim2.new(1, -20, 0, 16),
				Text = `{kit.mobility.name} · {kit.attack.name}`,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			13
		)
		local tag = stateChip(card, kit, state)
		tag.AnchorPoint = Vector2.new(0, 1)
		tag.Position = UDim2.new(0, 10, 1, -10)
		card.Activated:Connect(onPick)
	end

	-- The picked class, large: emblem, standing, name, what it is, Q and R, and one button.
	local function drawDetail(
		made: ClassPage,
		kit: AbilityKit.Kit,
		state: string,
		label: string,
		style: string,
		onPress: (() -> ())?
	)
		clear(made.detailContent)
		clear(made.detailFoot)
		local tone = classTone(kit.id)
		local hero = make("Frame", made.detailContent, {
			Name = "Hero",
			Size = UDim2.new(1, 0, 0, 104),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			LayoutOrder = 1,
		})
		Components.corner(hero, "m")
		outline(hero, "ink.950", 2)
		make("UIGradient", hero, {
			Color = ColorSequence.new(colour(tone), colour("ink.900")),
			Rotation = 40,
		})
		Icons.image(hero, `class_{kit.id}`, 80)
		stateChip(hero, kit, state).Position = UDim2.fromOffset(8, 8)
		text(made.detailContent, "headline", "ivory.50", {
			Size = UDim2.new(1, 0, 0, 30),
			Text = string.upper(kit.name),
			LayoutOrder = 2,
		})
		para(made.detailContent, "caption", "stone.300", kit.blurb, 3)
		skillRow(made.detailContent, "Q", "dash", kit.mobility, 4)
		skillRow(made.detailContent, "R", "punch", kit.attack, 5)
		local b = button(made.detailFoot, label, style, onPress, style == "buy")
		b.Name = "Action"
	end

	local redraw: () -> ()

	local function drawClasses(made: ClassPage, shop: boolean)
		local wearing = ability:GetKitId()
		local owned = ability:GetOwned()
		local coins = ability:GetCoins()
		local inRound = player:GetAttribute("HT_InRound") == true
		local key: Tab = if shop then "Shop" else "Abilities"
		made.title.Text = if shop
			then "CLASSES  ·  PAY WITH COINS"
			else "YOUR CLASSES  ·  PICK ONE TO FIGHT WITH"
		local shown: { string } = {}
		for _, kitId in book.Order do
			if not shop or book.Kits[kitId].price > 0 then
				table.insert(shown, kitId)
			end
		end
		local pick = picked[key]
		if not pick or not table.find(shown, pick) then
			-- Classes opens on the one you wear; the Shop on the first you don't own
			pick = if shop then shown[1] else wearing
			if shop then
				for _, kitId in shown do
					if not owned[kitId] then
						pick = kitId
						break
					end
				end
			end
			picked[key] = pick
		end
		clear(made.gridContent)
		for order, kitId in shown do
			classCard(
				made,
				book.Kits[kitId],
				order,
				kitId == pick,
				standing(kitId, wearing, owned),
				not shop and not owned[kitId],
				function()
					if picked[key] ~= kitId then
						picked[key] = kitId
						confirming = nil
						redraw()
					end
				end
			)
		end
		local kit = book.Kits[pick :: string]
		if not kit then
			clear(made.detailContent)
			clear(made.detailFoot)
			return
		end
		local state = standing(kit.id, wearing, owned)
		if shop then
			if state ~= "NOT OWNED" then
				drawDetail(made, kit, state, "Owned", "off", nil)
			elseif inRound then
				drawDetail(made, kit, state, "Locked in a round", "off", nil)
			elseif coins < kit.price then
				drawDetail(made, kit, state, `Need {kit.price - coins} more`, "off", nil)
			elseif confirming == kit.id then
				-- the second press spends the Coins
				drawDetail(made, kit, state, `Confirm · {kit.price}`, "buy", function()
					confirming = nil
					ability:Buy(kit.id)
				end)
			else
				drawDetail(made, kit, state, `Buy · {kit.price}`, "buy", function()
					confirming = kit.id
					redraw()
				end)
			end
		elseif state == "EQUIPPED" then
			drawDetail(made, kit, state, "Equipped", "off", nil)
		elseif state == "NOT OWNED" then
			drawDetail(made, kit, state, "See it in the Shop", "plain", function()
				picked.Shop = kit.id
				MenuController._goTo("Shop", true)
			end)
		elseif inRound then
			drawDetail(made, kit, state, "Locked in a round", "off", nil)
		else
			drawDetail(made, kit, state, "Equip", "equip", function()
				ability:Equip(kit.id)
			end)
		end
	end

	-- The tab you're on is light with dark lettering and sits pressed in; the others are dark.
	local function paintTabs()
		for index, tab in TABS do
			local on = tab == current
			tabButtons[tab].BackgroundColor3 = colour(if on then "ivory.50" else "ink.700")
			tabLabels[tab].TextColor3 = colour(if on then "ink.950" else "stone.300")
			dotFrames[index].BackgroundColor3 = colour(if on then "coral.500" else "line.300")
		end
		local at = table.find(TABS, current) or 1
		prevButton.BackgroundTransparency = if at == 1 then 0.6 else 0
		nextButton.BackgroundTransparency = if at == #TABS then 0.6 else 0
	end

	redraw = function()
		coinsText.Text = tostring(ability:GetCoins())
		if not isOpen then
			return
		end
		-- only the page you are on is drawn
		if current == "Shop" then
			fit(shopPage, pages.Shop)
			local keep = shopPage.grid.CanvasPosition
			drawClasses(shopPage, true)
			shopPage.grid.CanvasPosition = keep
		elseif current == "Abilities" then
			fit(classesPage, pages.Abilities)
			local keep = classesPage.grid.CanvasPosition
			drawClasses(classesPage, false)
			classesPage.grid.CanvasPosition = keep
		end
		paintTabs()
	end
	MenuController._redraw = redraw

	-- Goes to a page: sliding when you browse there, at once when a shortcut asked for it.
	local function goTo(tab: Tab, slide: boolean)
		confirming = nil
		current = tab
		pager.Animated = slide and not HudMotion.reduced()
		pager:JumpTo(pages[tab])
		pager.Animated = true
		redraw()
		if
			UserInputService.GamepadEnabled
			and UserInputService:GetLastInputType().Name:match("Gamepad")
		then
			GuiService.SelectedObject = tabButtons[tab]
		end
	end
	MenuController._goTo = goTo
	-- a swipe changes the page without asking us: follow it
	pager:GetPropertyChangedSignal("CurrentPage"):Connect(function()
		local page = pager.CurrentPage
		if page and isOpen and pages[current] ~= page then
			for _, tab in TABS do
				if pages[tab] == page then
					confirming = nil
					current = tab
					redraw()
				end
			end
		end
	end)
	local function step(by: number)
		local at = table.find(TABS, current) or 1
		local to = math.clamp(at + by, 1, #TABS)
		if to ~= at then
			goTo(TABS[to], true)
		end
	end
	prevButton.Activated:Connect(function()
		step(-1)
	end)
	nextButton.Activated:Connect(function()
		step(1)
	end)

	for index, tab in TABS do
		local b = headerButton(rail, tab, 0, index)
		b.AutomaticSize = Enum.AutomaticSize.X
		make("UIPadding", b, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 14) })
		list(b, 8, true)
		local icon = Icons.image(b, TAB_ICONS[tab], 32)
		icon.AnchorPoint = Vector2.zero
		icon.LayoutOrder = 1
		icon.ZIndex = 5
		tabLabels[tab] = small(
			text(b, "label", "stone.300", {
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = string.upper(TAB_NAMES[tab]),
				LayoutOrder = 2,
				ZIndex = 5,
			}),
			16
		)
		b.Activated:Connect(function()
			if current ~= tab then
				goTo(tab, true)
			end
		end)
		tabButtons[tab] = b
	end

	-- THE SETTINGS PANEL: small, on its own, the same backdrop ---------------------------------------------
	local settings = Components.sticker(gui, {
		Name = "Settings",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 11,
	}, { depth = 8, radius = "l" })
	settings.face.AutomaticSize = Enum.AutomaticSize.Y
	settings.face.Size = UDim2.fromScale(1, 0)
	local settingsScale = make("UIScale", settings.holder, {})
	local settingsBody = make("Frame", settings.face, {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 3,
	})
	pad(settingsBody, SP[4])
	list(settingsBody, SP[2])
	local function drawSettings()
		clear(settingsBody)
		local head = make("Frame", settingsBody, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
		})
		Icons.image(head, "settings", 40, UDim2.new(0, 20, 0.5, 0))
		text(head, "headline", "ivory.50", {
			Position = UDim2.fromOffset(50, 0),
			Size = UDim2.new(1, -100, 1, 0),
			Text = "SETTINGS",
		})
		local x = make("TextButton", head, {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = colour("danger.600"),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "X",
			TextColor3 = colour("ivory.50"),
		})
		Typography.apply(x, "button")
		Components.corner(x, "m")
		outline(x, "ink.950", 3)
		x.Activated:Connect(function()
			MenuController._setSettings(false)
		end)
		for index, setting in SETTINGS do
			local on = settingsState[setting.id]
			local row = make("TextButton", settingsBody, {
				Name = setting.id,
				LayoutOrder = 1 + index,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = colour("ink.700"),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
			})
			Components.corner(row, "m")
			outline(row, "ink.950", 2)
			small(
				text(row, "label", "ivory.50", {
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -90, 1, 0),
					Text = setting.name,
				}),
				15
			)
			local track = make("Frame", row, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(44, 24),
				BackgroundColor3 = colour(if on then "teal.400" else "ink.600"),
				BorderSizePixel = 0,
			})
			Components.corner(track, "full")
			outline(track, "ink.950", 2)
			local knob = make("Frame", track, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, if on then 24 else 4, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = colour(if on then "ink.950" else "stone.300"),
				BorderSizePixel = 0,
			})
			Components.corner(knob, "full")
			small(
				text(row, "caption", "stone.300", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -62, 0, 0),
					Size = UDim2.new(0, 30, 1, 0),
					Text = if on then "ON" else "OFF",
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				12
			)
			row.Activated:Connect(function()
				settingsState[setting.id] = not settingsState[setting.id]
				drawSettings()
			end)
		end
		small(
			para(
				settingsBody,
				"caption",
				"gold.400",
				"These three switches don't change anything yet.",
				8
			),
			13
		)
		local saving = ability:IsReady() and not ability:IsTemporary()
		small(
			para(
				settingsBody,
				"caption",
				if saving then "teal.400" else "gold.400",
				if not ability:IsReady()
					then "Loading your data..."
					elseif saving then "Your Coins and classes are saved."
					else "!  Not saving this session. Changes are lost when you leave.",
				9
			),
			13
		)
	end

	-- OPEN AND CLOSE -----------------------------------------------------------------------------------
	local function onCloseKey(
		_name: string,
		inputState: Enum.UserInputState
	): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			MenuController._setOpen(false)
			MenuController._setSettings(false)
		end
		return Enum.ContextActionResult.Sink -- every state, so the release never reaches the dash
	end
	local function bindKeys(on: boolean)
		if on then
			ContextActionService:BindActionAtPriority(
				CLOSE_ACTION,
				onCloseKey,
				false,
				Enum.ContextActionPriority.High.Value + 1,
				Enum.KeyCode.ButtonB
			)
		else
			ContextActionService:UnbindAction(CLOSE_ACTION)
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
		end
	end
	-- The window keeps its real sizes down to a 700 x 400 screen (a small phone); under that the whole thing
	-- shrinks together instead of crushing its contents.
	local base = 1
	local function sizeWindow()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else HudTheme.Scale.Reference
		base = math.min(1, size.X / 700, size.Y / 400)
		window.holder.Size = UDim2.fromOffset(
			math.min(size.X * M.ScreenShare.X / base, M.MaxWidth),
			math.min(size.Y * M.ScreenShare.Y / base, M.MaxHeight)
		)
		panelScale.Scale = base
		settingsScale.Scale = base
	end
	local function opening(scale: UIScale)
		-- in: a short rise and scale on the motion tokens; nothing scales under reduced motion
		sizeWindow()
		if not HudMotion.reduced() then
			scale.Scale = base * 0.95
		end
		HudMotion.play(scale, "open", { Scale = base }, "release", "enter")
	end

	local function setSettings(open: boolean)
		if open == settingsOpen then
			return
		end
		if open and isOpen then
			MenuController._setOpen(false)
		end
		settingsOpen = open
		backdrop.Visible = open
		settings.holder.Visible = open
		bindKeys(open)
		if open then
			drawSettings()
			opening(settingsScale)
		end
	end
	MenuController._setSettings = setSettings

	local function setOpen(open: boolean, tab: Tab?)
		if open and settingsOpen then
			setSettings(false)
		end
		if open == isOpen then
			if open and tab then
				goTo(tab, false) -- a shortcut pressed while the window is up: straight to its page
			end
			return
		end
		isOpen = open
		confirming = nil
		backdrop.Visible = open
		window.holder.Visible = open
		bindKeys(open)
		if open then
			ContextActionService:BindActionAtPriority(
				PAGE_ACTION,
				function(_, inputState: Enum.UserInputState, input: InputObject)
					if inputState == Enum.UserInputState.Begin then
						step(if input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1)
					end
					return Enum.ContextActionResult.Sink
				end,
				false,
				Enum.ContextActionPriority.High.Value + 1,
				Enum.KeyCode.ButtonL1,
				Enum.KeyCode.ButtonR1
			)
			goTo(tab or current, false)
			opening(panelScale)
		else
			ContextActionService:UnbindAction(PAGE_ACTION)
		end
	end
	MenuController._setOpen = setOpen

	close.Activated:Connect(function()
		setOpen(false)
	end)
	-- A press outside closes whichever is up. Checked by position: an Active frame doesn't stop the backdrop
	-- button under it from getting Activated (measured in Play, 2026-11-12).
	backdrop.Activated:Connect(function(input: InputObject)
		local at = Vector2.new(input.Position.X, input.Position.Y)
		local target = if settingsOpen then settings.holder else window.holder
		local low, size = target.AbsolutePosition, target.AbsoluteSize
		local inside = at.X >= low.X
			and at.Y >= low.Y
			and at.X <= low.X + size.X
			and at.Y <= low.Y + size.Y
		if not inside then
			setOpen(false)
			setSettings(false)
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

	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if isOpen then
			redraw()
		end
	end)
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(sizeWindow)
		end
		sizeWindow()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
	ability.InventoryChanged:Connect(redraw)
	ability.KitChanged:Connect(redraw)
	player:GetAttributeChangedSignal("HT_InRound"):Connect(redraw)
	redraw()
	gui.Parent = player:WaitForChild("PlayerGui")
end

--- Opens or closes the window (for tests and other controllers).
function MenuController:SetOpen(open: boolean)
	if self._setOpen then
		self._setOpen(open)
	end
end

--- Opens the window directly on a page: "Shop", "Abilities" (Classes) or "Cosmetics".
function MenuController:Open(tab: string)
	if self._setOpen and table.find(TABS, tab :: any) then
		self._setOpen(true, tab)
	end
end

--- Opens the small Settings panel.
function MenuController:OpenSettings()
	if self._setSettings then
		self._setSettings(true)
	end
end

return MenuController
