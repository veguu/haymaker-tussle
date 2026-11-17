--!strict
-- HudController - the combat HUD in the Voltline look (2026-11-16; drawn in the vault's UI Research/
-- voltline-preview.html, "Electric blue"). Blue cut-corner panels on the screen's edges; the centre is the fight's:
--   Y  bottom-left (top-left on phones): YOUR stagger. A big slanted figure that climbs toward danger (not a
--      health bar), STAGGER, the knockback it means ("2.1x knockback"), RISING / CRITICAL / RECOVERING in words,
--      the speed bar, and the stagger bar with marks at 40 and 70. White, then yellow, then red-orange.
--   K  bottom-right: the class skills, ALWAYS shown in a fight: Q (mobility) and R (attack) as the two big
--      tiles, each with its icon, name, key cap, a shade that drains off the icon as the cooldown runs and the
--      seconds left on top. Jump and Punch are the two small tiles beside them. Four states, each a different
--      shape: ready (cyan border, corner flag, filled key), cooling down (shade and seconds), held (white
--      border, pressed fill) and can't use (dim, a slash through it).
--   A  top centre: one status strip (next round in N, get ready, 18 / 25 standing, final two, round over).
--   F  top right: the ring-out feed, newest on top, four rows; yours marked with a pink edge.
--   the target: a pink chevron and the name over your lock-on target (an open white one over the nearest
--      opponent ahead when nothing is locked), with a thin bar shaded by THEIR stagger.
--
-- It only draws. Every number comes from where the game keeps it: MovementController.Hud (speed, propel and kick
-- timing), CombatController (punch timing and results), AbilityController (kit skills), EndlagController, the
-- character's HT_Stagger, and the round's HT_RoundState folder. Rules in Core/HudLogic; colours, radii, type and
-- motion from Shared/Tokens through Ui/Components, Shared/Typography and Ui/HudMotion. No combat input is bound
-- here; on touch the real ContextActionService buttons stay the only buttons, with the cooldown drawn on them.
--
-- ROUND CONTRACT (filled by the round service; HudPreviewService is a Studio stand-in): a Folder
-- ReplicatedStorage.HT_RoundState with attributes Phase ("Intermission" | "Starting" | "Fighting" | "RoundOver"),
-- Round, Alive, Total, CountdownEnd (workspace:GetServerTimeNow() seconds), ShrinkActive (bool), ShrinkSeq (int,
-- +1 each time a shrink begins); a RemoteEvent in it named RingOut, fired to all with (victimName,
-- attackerName?, cause "knocked" | "fell" | "left"); and the player attribute HT_Eliminated.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local HudLogic = require(ReplicatedStorage.Shared.Core.HudLogic)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Typography = require(ReplicatedStorage.Shared.Typography)
local Components = require(script.Parent.Parent.Ui.Components)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)

local S, T = HudTheme.Size, HudTheme.Time
local make, text, panel, colour = Components.make, Components.text, Components.panel, Tokens.colour
local moveCfg = GameConfig.Movement
local kickCfg = GameConfig.Kick
local staggerCfg = GameConfig.Stagger
local STAGGER_MAX = staggerCfg.Max
local COMBATANT_TAG = "HT_Combatant"
local ROUND_FOLDER = "HT_RoundState"
local HELP_ACTION = "HaymakerHelp"
local GUIDE_ROWS = 7
local SP = Tokens.space -- 4, 8, 12, 16, 24, 32, 48, 64

-- Layout in design units at 1280 x 720, before the HUD scale (spec Combat HUD 5.2-5.4, Round Presentation 5.1-5.2).
local L = {
	Edge = SP[5], -- 24 from the safe edges
	Y = Vector2.new(324, 88),
	YPhone = Vector2.new(200, 88),
	FigureWidth = 96, -- three digits reserved, so the label column never jumps between 9 and 100
	Bar = Vector2.new(300, 10),
	BarPhone = 176,
	SpeedWidth = 64,
	SpeedOver = 24,
	SpeedHeight = 6,
	TileBig = 76, -- Q and R: the class skills
	TileSmall = 56, -- Jump and Punch
	TileGap = SP[2], -- 8
	TileTop = 22, -- room above the tiles for a result word (HIT / MISS / NOW)
	Cap = 20,
	K = Vector2.new(56 + 8 + 56 + 12 + 76 + 8 + 76, 22 + 76),
	Strip = Vector2.new(360, 44),
	StripTop = SP[2], -- 8
	Chip = 28,
	FeedWidth = 300,
	FeedRow = 28,
	FeedGap = SP[1], -- 4
	FeedRows = 4,
	ClosingFor = 2.5, -- seconds the ARENA CLOSING chip shows each time a shrink begins
	ReadyPop = 0.18, -- the one pop a tile gives when its skill comes back
}

local HudController = Knit.CreateController({
	Name = "HudController",
})

type Device = "mouse" | "gamepad" | "touch"

local function deviceOf(kind: Enum.UserInputType): Device?
	if kind == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(kind.Name, "Gamepad") then
		return "gamepad"
	elseif kind == Enum.UserInputType.Keyboard or string.find(kind.Name, "Mouse") then
		return "mouse"
	end
	return nil
end

-- The gamepad glyph for a binding name in HudTheme.Actions.
local PAD_KEYS = {
	R2 = Enum.KeyCode.ButtonR2,
	L2 = Enum.KeyCode.ButtonL2,
	B = Enum.KeyCode.ButtonB,
	Y = Enum.KeyCode.ButtonY,
}

-- BUILDING ------------------------------------------------------------------------------------------

-- A group: a holder sized and placed by layout, with a CanvasGroup inside that fades and rises.
type Group = { holder: Frame, fade: CanvasGroup, scale: UIScale, wanted: boolean }

local function group(parent: Instance, name: string, size: Vector2): Group
	local holder = make("Frame", parent, {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
	})
	local scale = make("UIScale", holder, {})
	local fade = make("CanvasGroup", holder, {
		Name = "Fade",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
		Visible = false,
	})
	return { holder = holder, fade = fade, scale = scale, wanted = false }
end

-- One action tile: a cut-corner box holding the icon, the skill's name (big tiles), the key cap, a cooldown
-- shade with the seconds left, the ready flag and a slash for unavailable. A result word shows above it.
type Tile = {
	id: string,
	big: boolean,
	column: Frame,
	scale: UIScale,
	box: Components.Cut,
	icon: ImageLabel,
	shadeClip: Frame,
	seconds: TextLabel,
	flag: ImageLabel,
	slash: Frame,
	cap: Frame,
	capStroke: UIStroke,
	capText: TextLabel,
	capGlyph: ImageLabel,
	capTone: string,
	name: TextLabel,
	word: TextLabel,
	state: string,
	wordUntil: number,
	secondsText: string,
}

local function makeTile(parent: Instance, id: string, x: number, big: boolean): Tile
	local size = if big then L.TileBig else L.TileSmall
	local cutSize = if big then 1 else 0.75
	local column = make("Frame", parent, {
		Name = id,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(size, L.K.Y),
	})
	local scale = make("UIScale", column, {})
	-- a short result word (HIT / MISS / NOW) above the tile, briefly
	local word = text(column, "label", "ivory.50", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(size + 2)),
		Size = UDim2.fromOffset(size + 16, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	make("UIStroke", word, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = colour("ink.950"),
		Thickness = 1.5,
		Transparency = 0.3,
	})
	local box = Components.cut(column, 2, "line.500", {
		Name = "Box",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(size, size),
	}, cutSize)
	Components.paintCut(box, "ink.700", nil)
	local icon = make("ImageLabel", box.frame, {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if big then 0.54 else 0.46),
		Size = if big then UDim2.fromOffset(36, 36) else UDim2.fromOffset(26, 26),
		Image = HudTheme.Icons[id] or "",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
	})
	-- the skill's name, inside the top of a big tile, always there
	local name = text(box.frame, "caption", "ivory.200", {
		Name = "SkillName",
		Position = UDim2.fromOffset(7, 6),
		Size = UDim2.new(1, -9, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = big,
		ZIndex = 5,
	})
	name.TextSize = 12 -- nine capitals ("FROSTBITE") have to fit beside the cut corner
	-- the cooldown shade: the tile's own shape in dark ink, shown from the top down by a clip whose height is
	-- the share of the cooldown still to run, with a white line on its lower edge. The icon stays visible under it.
	local shadeClip = make("Frame", box.frame, {
		Name = "ShadeClip",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		ClipsDescendants = true,
		ZIndex = 3,
	})
	local shade = Components.cutImage("fill", "ink.950", cutSize)
	shade.Name = "Shade"
	shade.Size = UDim2.fromOffset(size, size)
	shade.ImageTransparency = 0.45
	shade.Parent = shadeClip
	make("Frame", shadeClip, {
		Name = "Edge",
		BackgroundColor3 = colour("ivory.50"),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, 0),
		Size = UDim2.new(1, -4, 0, 2),
	})
	local seconds = text(box.frame, "numeral.m", "ivory.50", {
		Name = "Seconds",
		Position = UDim2.fromOffset(0, if big then 6 else -2),
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5,
	})
	if not big then
		seconds.TextSize = 20
	end
	make("UIStroke", seconds, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = colour("ink.950"),
		Thickness = 2,
		Transparency = 0.1,
	})
	local flag = make("ImageLabel", box.frame, {
		Name = "Ready",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(24 * cutSize, 24 * cutSize),
		Image = Tokens.cut.flag,
		ImageColor3 = colour("teal.400"),
		Visible = false,
		ZIndex = 4,
	})
	local slash = make("Frame", box.frame, {
		Name = "Slash",
		BackgroundColor3 = colour("stone.300"),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.95, 3),
		Rotation = -45,
		Visible = false,
		ZIndex = 6,
	})
	local cap, capText, capGlyph = Components.keyCap(box.frame, L.Cap)
	cap.AnchorPoint = Vector2.new(0, 1)
	cap.Position = UDim2.new(0, 5, 1, -5)
	cap.ZIndex = 6
	if not big then
		-- a small tile's cap has to hold "SPACE": tighter padding and smaller letters
		local pad = cap:FindFirstChildOfClass("UIPadding") :: UIPadding
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 3), UDim.new(0, 3)
		cap.Position = UDim2.new(0, 4, 1, -4)
		capText.TextSize = 12
	end
	return {
		id = id,
		big = big,
		column = column,
		scale = scale,
		box = box,
		icon = icon,
		shadeClip = shadeClip,
		seconds = seconds,
		flag = flag,
		slash = slash,
		cap = cap,
		capStroke = cap:FindFirstChildOfClass("UIStroke") :: UIStroke,
		capText = capText,
		capGlyph = capGlyph,
		capTone = "ink.600",
		name = name,
		word = word,
		state = "",
		wordUntil = 0,
		secondsText = "",
	}
end

-- A tile's look for a state, told apart by shape as well as colour:
--   ready: cyan border, the corner flag, the key cap filled; coming back from a cooldown the tile pops once;
--   recovering: plain border, icon dimmed under the draining shade, the seconds left on top;
--   held (the attack skill while its key is down): white border, lighter fill, the key cap white;
--   unavailable: dim, with a slash through it.
local function paintTile(tile: Tile, state: string, held: boolean)
	local key = if held then "held" else state
	if tile.state == key then
		return
	end
	local was = tile.state
	tile.state = key
	local ready = state == "ready" and not held
	local dim = state == "unavailable" and not held
	Components.paintCut(
		tile.box,
		if dim then "ink.900" elseif held then "ink.500" else "ink.700",
		if held
			then "ivory.50"
			elseif ready then "teal.400"
			elseif dim then "stone.500"
			else "line.500"
	)
	tile.icon.ImageTransparency = if dim then 0.7 elseif ready or held then 0 else 0.3
	tile.flag.Visible = ready
	tile.slash.Visible = dim
	local capTone = if held then "ivory.50" elseif ready then "teal.400" else "ink.600"
	tile.capTone = capTone
	tile.cap.BackgroundColor3 = colour(capTone)
	tile.capStroke.Color = if held or ready
		then colour(capTone)
		elseif dim then colour("stone.500")
		else colour("line.300")
	tile.capText.TextColor3 = if held or ready
		then colour("ink.950")
		elseif dim then colour("stone.500")
		else colour("ivory.50")
	tile.capGlyph.ImageTransparency = if dim then 0.6 else 0
	tile.name.TextColor3 = if dim then colour("stone.500") else colour("ivory.200")
	if key ~= "recovering" then
		tile.shadeClip.Size = UDim2.fromScale(1, 0)
	end
	if ready and was == "recovering" and not HudMotion.reduced() then
		HudMotion.pop(tile.scale, 1.08, L.ReadyPop)
	end
end

-- The target chevron: a downward V drawn with two rotated 2-unit strokes.
local function chevron(parent: Instance, width: number, tone: string): { Frame }
	local arms = {}
	for side = -1, 1, 2 do
		local arm = make("Frame", parent, {
			BackgroundColor3 = colour(tone),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * width * 0.24, 1, -7),
			Size = UDim2.fromOffset(width * 0.58, 3),
			Rotation = side * -32,
		})
		Components.corner(arm, "full")
		make("UIStroke", arm, {
			Color = colour("ink.950"),
			Thickness = 1,
			Transparency = 0.4,
		})
		table.insert(arms, arm)
	end
	return arms
end

-- THE CONTROLLER -----------------------------------------------------------------------------------

function HudController:KnitStart()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local movement = Knit.GetController("MovementController")
	local combat = Knit.GetController("CombatController")
	local ability = Knit.GetController("AbilityController")
	local endlag = Knit.GetController("EndlagController")
	local lockOn = Knit.GetController("LockOnController")
	local kickPrompt = Knit.GetController("KickPromptController")
	local hud = movement.Hud

	-- Every game-owned label on screen uses the type family, including any made later.
	Typography.adopt(playerGui)

	local gui = make("ScreenGui", nil, {
		Name = "HT_Hud",
		ResetOnSpawn = false,
		DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	gui.Parent = playerGui

	-- A: the status strip, top centre ------------------------------------------------------------------
	local strip = group(gui, "Strip", Vector2.new(L.Strip.X, L.Strip.Y + SP[2] + L.Chip))
	strip.holder.AnchorPoint = Vector2.new(0.5, 0)
	-- its border turns yellow for the final two and the last one; the contents are a row inside it
	local stripCut = Components.cut(strip.fade, 1, "line.500", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, L.Strip.Y),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	local stripPanel = stripCut.frame
	local stripRow = make("Frame", stripPanel, {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, L.Strip.Y),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	make("UIPadding", stripRow, {
		PaddingLeft = UDim.new(0, SP[5]),
		PaddingRight = UDim.new(0, SP[5]),
	})
	make("UIListLayout", stripRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, SP[3]),
	})
	local function stripText(order: number, role: string, tone: string): TextLabel
		return text(stripRow, role, tone, {
			LayoutOrder = order,
			Size = UDim2.fromOffset(0, L.Strip.Y),
			AutomaticSize = Enum.AutomaticSize.X,
		})
	end
	local stripCount = stripText(1, "numeral.m", "ivory.50") -- survivors, or seconds before a round
	local countScale = make("UIScale", stripCount, {})
	local stripTotal = stripText(2, "caption", "stone.300") -- "/ 25"
	local stripTitle = stripText(3, "label", "stone.300") -- STANDING / FINAL TWO / NEXT ROUND ...
	local titleScale = make("UIScale", stripTitle, {})
	local stripRound = stripText(4, "label", "stone.300") -- ROUND 4
	-- the warning chip: red-orange with dark lettering, and the "!" so it isn't colour alone
	local closing = panel(strip.fade, 1, "s", {
		Name = "Closing",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, L.Strip.Y + SP[2]),
		Size = UDim2.fromOffset(0, L.Chip),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = colour("danger.600"),
		BackgroundTransparency = 0,
		Visible = false,
	})
	make("UIPadding", closing, {
		PaddingLeft = UDim.new(0, SP[3]),
		PaddingRight = UDim.new(0, SP[3]),
	})
	local closingScale = make("UIScale", closing, {})
	text(closing, "label", "ink.950", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "!  ARENA CLOSING",
	})

	-- Y: you --------------------------------------------------------------------------------------------
	local you = group(gui, "You", L.Y)
	local youPanel = Components.cut(you.fade, 1, "line.500", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
	}).frame
	local youPulse = make("UIScale", you.fade, {})
	local figure = text(youPanel, "numeral.l", "ivory.50", {
		Name = "Figure",
		Position = UDim2.fromOffset(SP[3], 8),
		Size = UDim2.fromOffset(L.FigureWidth, 48),
		Text = "<unbound>", -- the sentinel: setStagger writes it at once, so seeing it means a broken wire
	})
	local figureMove = make("UIPadding", figure, {})
	local labelX = SP[3] + L.FigureWidth + SP[2]
	text(youPanel, "label", "stone.300", {
		Position = UDim2.fromOffset(labelX, 12),
		Size = UDim2.fromOffset(110, 16),
		Text = "STAGGER",
	})
	local knock = text(youPanel, "caption", "ivory.200", {
		Name = "Knockback",
		Position = UDim2.fromOffset(labelX, 30),
		Size = UDim2.fromOffset(120, 18),
		RichText = true,
	})
	local status = text(youPanel, "label", "teal.400", {
		Name = "Status",
		Position = UDim2.fromOffset(L.Y.X - SP[3] - 110, 44),
		Size = UDim2.fromOffset(110, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local speedLabel = text(youPanel, "label", "stone.300", {
		Name = "SpeedLabel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -SP[3], 0, 9),
		Size = UDim2.fromOffset(L.SpeedWidth + 2 + L.SpeedOver, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "SPEED",
	})
	local speedBase = Components.meter(youPanel, L.SpeedWidth, L.SpeedHeight, true)
	speedBase.track.AnchorPoint = Vector2.new(1, 0)
	speedBase.track.Position = UDim2.new(1, -(SP[3] + L.SpeedOver + 2), 0, 30)
	local speedOver = Components.meter(youPanel, L.SpeedOver, L.SpeedHeight, true)
	speedOver.track.AnchorPoint = Vector2.new(1, 0)
	speedOver.track.Position = UDim2.new(1, -SP[3], 0, 30)
	speedOver.track.BackgroundTransparency = 0.92
	-- your top speed under stagger: a 2-unit notch on the speed bar
	local speedNotch = make("Frame", speedBase.track, {
		Name = "Cap",
		BackgroundColor3 = colour("stone.500"),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, 2, 1, 4),
		ZIndex = 4,
	})
	local bar = Components.meter(youPanel, L.Bar.X, L.Bar.Y, true, true, { 0.4, 0.7 })
	bar.track.Position = UDim2.fromOffset(SP[3], L.Y.Y - SP[3] - L.Bar.Y)
	local barGradient = make("UIGradient", bar.fill, {
		Color = ColorSequence.new(colour("gold.400"), colour("danger.600")),
		Enabled = false,
	})
	local drainTick = make("Frame", bar.track, {
		Name = "Drain",
		BackgroundColor3 = colour("teal.400"),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 2, 1, 4),
		Visible = false,
		ZIndex = 5,
	})
	local speedParts = { speedLabel, speedBase.track, speedOver.track }

	-- K: the kit tiles ------------------------------------------------------------------------------------
	local kit = group(gui, "Kit", L.K)
	kit.holder.AnchorPoint = Vector2.new(1, 1)
	local actionById: { [string]: any } = {}
	for _, action in HudTheme.Actions do
		actionById[action.id] = action
	end
	-- Jump and Punch small on the left, then the class skills big: Q, and R outermost.
	local ORDER = { "kick", "punch", "propel", "uppercut" }
	local BIG = { propel = true, uppercut = true }
	local tiles: { [string]: Tile } = {}
	do
		local x = 0
		for index, id in ORDER do
			local big = BIG[id] == true
			tiles[id] = makeTile(kit.fade, id, x, big)
			x += (if big then L.TileBig else L.TileSmall) + (if index == 2 then SP[3] else L.TileGap)
		end
	end
	-- The class skills' names sit in their tiles for good; they change only with the class.
	local function refreshNames()
		tiles.propel.name.Text = string.upper(ability:GetSkill("mobility").name)
		tiles.uppercut.name.Text = string.upper(ability:GetSkill("attack").name)
	end
	refreshNames()
	ability.KitChanged:Connect(refreshNames)

	-- the controls guide: a ghost chip ("Controls" + key cap) and the sheet it opens -------------------------
	local help = make("Frame", gui, {
		Name = "Help",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(S.HelpWidth, S.HelpHeight),
	})
	local helpScale = make("UIScale", help, {})
	local helpChip = make("TextButton", help, {
		Name = "Chip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	})
	make("UIListLayout", helpChip, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, SP[2]),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local helpWord = text(helpChip, "label", "stone.300", {
		LayoutOrder = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "CONTROLS",
	})
	make("UIStroke", helpWord, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = colour("ink.950"),
		Thickness = 1.5,
		Transparency = 0.4,
	})
	local helpCap, helpCapText, helpCapGlyph = Components.keyCap(helpChip, L.Cap)
	helpCap.LayoutOrder = 2
	local guide = Components.cut(help, 2, "line.300", {
		Name = "Guide",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -SP[2]),
		Size = UDim2.fromOffset(S.GuideWidth + 40, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}).frame
	-- the rows live in a body of their own, so the list layout never touches the panel's two images
	local guideBody = make("Frame", guide, {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
	})
	make("UIPadding", guideBody, {
		PaddingTop = UDim.new(0, SP[4]),
		PaddingBottom = UDim.new(0, SP[4]),
		PaddingLeft = UDim.new(0, SP[4]),
		PaddingRight = UDim.new(0, SP[4]),
	})
	make("UIListLayout", guideBody, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, SP[3]),
	})
	text(guideBody, "title", "ivory.50", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 24),
		Text = "CONTROLS",
	})
	local GUIDE_INFO = S.GuideWidth + 40 - 2 * SP[4] - (64 + SP[3])
	local guideRows: { { frame: Frame, key: TextLabel, info: TextLabel } } = {}
	for order = 1, GUIDE_ROWS do
		local row = make("Frame", guideBody, {
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, S.GuideRow),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		local cap, key = Components.keyCap(row, L.Cap + 4)
		cap.Size = UDim2.fromOffset(64, L.Cap + 4)
		cap.AutomaticSize = Enum.AutomaticSize.None
		key.Size = UDim2.fromScale(1, 1)
		key.AutomaticSize = Enum.AutomaticSize.None
		local info = text(row, "body", "ivory.200", {
			Position = UDim2.fromOffset(64 + SP[3], 0),
			-- its height is measured when the text is set (refreshDevice): left to AutomaticSize, a wrapped label
			-- built while the guide is hidden stays one line tall and cuts its text off (seen 2026-11-16)
			Size = UDim2.fromOffset(GUIDE_INFO, 20),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		guideRows[order] = { frame = row, key = key, info = info }
	end

	-- F: the ring-out feed --------------------------------------------------------------------------------
	local feed = group(gui, "Feed", Vector2.new(L.FeedWidth, L.FeedRows * (L.FeedRow + L.FeedGap)))
	feed.holder.AnchorPoint = Vector2.new(1, 0)
	type FeedRow = { frame: Frame, label: TextLabel, ledge: Frame, born: number }
	local feedRows: { FeedRow } = {}

	-- Spectating: a small strip at the bottom centre while you are out ---------------------------------------
	local spectate = group(gui, "Spectate", Vector2.new(200, 40))
	spectate.holder.AnchorPoint = Vector2.new(0.5, 1)
	local spectatePanel =
		Components.cut(spectate.fade, 1, "line.500", { Size = UDim2.fromScale(1, 1) }, 0.75).frame
	text(spectatePanel, "label", "ivory.50", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "SPECTATING",
	})

	-- the target marker: chevron + name, and a thin bar in the other-fighter ramp ----------------------------
	local marker = make("BillboardGui", nil, {
		Name = "HT_TargetMarker",
		Size = UDim2.fromOffset(160, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 3.9, 0),
		AlwaysOnTop = true,
		MaxDistance = S.ChipMaxDistance,
		ResetOnSpawn = false,
		Enabled = false,
	})
	marker.Parent = playerGui
	local markerName = text(marker, "caption", "ivory.50", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	make("UIStroke", markerName, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = colour("ink.950"),
		Thickness = 1.5,
		Transparency = 0.4,
	})
	local markerBar = Components.meter(marker, 56, 4, true)
	markerBar.track.AnchorPoint = Vector2.new(0.5, 0)
	markerBar.track.Position = UDim2.new(0.5, 0, 0, 24)
	local markerArrow = make("Frame", marker, {
		Name = "Chevron",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(26, 20),
	})
	local markerScale = make("UIScale", markerArrow, {})
	local arms = chevron(markerArrow, 26, "coral.500")

	-- LAYOUT -----------------------------------------------------------------------------------------
	local device: Device = deviceOf(UserInputService:GetLastInputType()) or "mouse"

	local function layout()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else HudTheme.Scale.Reference
		local ref = HudTheme.Scale.Reference
		local scale = math.clamp(
			math.min(view.X / ref.X, view.Y / ref.Y),
			HudTheme.Scale.Min,
			HudTheme.Scale.Max
		)
		for _, g in { strip, feed, spectate, you, kit } do
			g.scale.Scale = scale
		end
		helpScale.Scale = scale
		local edge = L.Edge
		strip.holder.Position = UDim2.new(0.5, 0, 0, L.StripTop)
		feed.holder.Position = UDim2.new(1, -edge, 0, L.StripTop)
		spectate.holder.Position = UDim2.new(0.5, 0, 1, -edge)
		kit.holder.Position = UDim2.new(1, -edge, 1, -edge)
		local phone = device == "touch"
		-- Phones: your panel goes top-left (the bottom corners belong to the thumbs), narrower, no speed bar.
		local size = if phone then L.YPhone else L.Y
		you.holder.Size = UDim2.fromOffset(size.X, size.Y)
		bar.track.Size = UDim2.fromOffset(if phone then L.BarPhone else L.Bar.X, L.Bar.Y)
		for _, part in speedParts do
			(part :: GuiObject).Visible = not phone
		end
		status.Position = if phone
			then UDim2.fromOffset(labelX, 48)
			else UDim2.fromOffset(L.Y.X - SP[3] - 110, 44)
		status.TextXAlignment = if phone
			then Enum.TextXAlignment.Left
			else Enum.TextXAlignment.Right
		if phone then
			you.holder.AnchorPoint = Vector2.new(0, 0)
			you.holder.Position = UDim2.new(0, edge, 0, L.StripTop)
			help.AnchorPoint = Vector2.new(1, 0)
			help.Position =
				UDim2.new(1, -edge, 0, L.StripTop + feed.holder.Size.Y.Offset * scale + SP[2])
			guide.AnchorPoint = Vector2.new(1, 0)
			guide.Position = UDim2.new(1, 0, 1, SP[2])
		else
			you.holder.AnchorPoint = Vector2.new(0, 1)
			you.holder.Position = UDim2.new(0, edge, 1, -edge)
			help.AnchorPoint = Vector2.new(1, 1)
			help.Position = UDim2.new(1, -edge, 1, -(edge + (L.K.Y + SP[2]) * scale))
			guide.AnchorPoint = Vector2.new(1, 1)
			guide.Position = UDim2.new(1, 0, 0, -SP[2])
		end
	end

	-- STATE ------------------------------------------------------------------------------------------
	local roundFolder: Instance? = nil
	local promptActive = false
	local lastStrip: HudLogic.Strip? = nil
	local lastPhase: string? = nil
	local lastShrinkSeq = 0
	local closingToken = 0
	local character: Model? = nil
	local charConns: { RBXScriptConnection } = {}
	local stagger = 0
	local band: HudLogic.StaggerBand = "calm"
	local lastRise = -math.huge
	local recovering = false
	local recoverFrom = 0
	local barFrom, barTo, barSince = 0, 0, -math.huge
	local gaugeShown, overShown = 0, 0
	local target: Model? = nil
	local targetLocked = false
	local nextTargetPick = 0

	-- Training hides round info, except with rounds running: then training is the lobby, where people
	-- wait for the next round and watch the one on, so the countdown, survivors and feed all show there.
	local function inTraining(): boolean
		return player:GetAttribute("HT_InTraining") == true and not GameConfig.Round.Enabled
	end

	local function readRound(): HudLogic.RoundState
		local folder = roundFolder
		if not folder or inTraining() then
			return {}
		end
		return {
			phase = folder:GetAttribute("Phase"),
			alive = folder:GetAttribute("Alive"),
			total = folder:GetAttribute("Total"),
			countdownEnd = folder:GetAttribute("CountdownEnd"),
			round = folder:GetAttribute("Round"),
		}
	end

	local function setGroup(g: Group, want: boolean)
		local stepped = promptActive and (g == you or g == kit)
		local goal = if stepped then 0.4 else 0 -- a timed cue or a clash dims you and your kit to 60 %
		if want and not g.wanted then
			g.wanted = true
			HudMotion.enter(g.fade, UDim2.new(), SP[2], Tokens.motion.duration.base)
			if goal > 0 then
				HudMotion.to(
					g.fade,
					"fade",
					{ GroupTransparency = goal },
					Tokens.motion.duration.quick
				)
			end
		elseif not want and g.wanted then
			g.wanted = false
			HudMotion.leave(g.fade, Tokens.motion.duration.quick, function()
				return g.wanted
			end)
		elseif want then
			HudMotion.to(g.fade, "fade", { GroupTransparency = goal }, Tokens.motion.duration.quick)
		end
	end

	-- Which groups show: you and your kit while you're alive and in it; nothing of yours once you're out or
	-- the round is over. Touch has its own buttons, so no tiles there.
	local wasFighting = false
	local function refreshGroups()
		local alive = character ~= nil and character.Parent ~= nil
		local round = readRound()
		local out = player:GetAttribute("HT_Eliminated") == true
		local over = round.phase == "RoundOver"
		local fighting = alive and not out and not over
		setGroup(you, fighting)
		setGroup(kit, fighting and device ~= "touch")
		setGroup(spectate, out and not over)
		-- The chip is for fighters. The guide itself can also be opened from the lobby's Moves button while
		-- you're out, so it closes once, at the moment you stop fighting, not on every refresh after that.
		helpChip.Visible = fighting
		if wasFighting and not fighting then
			guide.Visible = false
		end
		wasFighting = fighting
	end

	local function refreshStrip(fromEvent: boolean)
		local round = readRound()
		local now = workspace:GetServerTimeNow()
		local info = HudLogic.strip(round, now)
		setGroup(strip, info.visible)
		if not info.visible then
			lastStrip, lastPhase = info, round.phase
			return
		end
		local roundText = if round.round then `ROUND {round.round}` else ""
		local fightingNow = round.phase == "Fighting"
		local counting = round.phase == "Intermission"
		-- Fighting: [ 18  / 25  STANDING ]; intermission: [ NEXT ROUND  12  ROUND 4 ]; starting: [ GET READY  ROUND 4 ]
		stripCount.Visible = info.count ~= nil and (fightingNow or counting)
		stripCount.Text = info.count or ""
		Typography.apply(stripCount, if counting then "mono.timer" else "numeral.m")
		stripCount.LayoutOrder = if counting then 2 else 1
		stripTotal.Visible = info.total ~= nil
		stripTotal.Text = if info.total then `/ {info.total}` else ""
		stripTitle.Text = info.title
		stripTitle.LayoutOrder = if counting then 1 else 3
		stripTitle.TextColor3 = if fightingNow and not info.finalTwo
			then colour("stone.300")
			else colour("ivory.50")
		stripRound.Visible = roundText ~= "" and not fightingNow
		stripRound.Text = roundText
		local last = info.finalTwo or (fightingNow and (round.alive or 0) <= 1)
		Components.paintCut(stripCut, nil, if last then "gold.400" else "line.500")
		local emphasis = fromEvent and HudLogic.emphasize(promptActive, HudMotion.reduced())
		local before = lastStrip
		-- Final two: one short emphasis when three became two in a fight, never when it started at two.
		if
			info.finalTwo
			and before
			and before.visible
			and not before.finalTwo
			and lastPhase == "Fighting"
			and fightingNow
			and emphasis
		then
			HudMotion.pop(titleScale, T.EmphasisScale, T.Emphasis)
		end
		if
			before
			and before.visible
			and before.count ~= info.count
			and fightingNow
			and emphasis
		then
			HudMotion.pop(countScale, 1.12, Tokens.motion.duration.base)
		end
		lastStrip, lastPhase = info, round.phase
	end

	local function refreshShrink(fromEvent: boolean)
		local folder = roundFolder
		local active = folder ~= nil
			and folder:GetAttribute("ShrinkActive") == true
			and readRound().phase == "Fighting"
		local seq = if folder then (folder:GetAttribute("ShrinkSeq") or 0) :: number else 0
		if not active then
			closing.Visible = false
		elseif seq ~= lastShrinkSeq then
			-- each time a shrink begins: the chip, for a moment
			closingToken += 1
			local mine = closingToken
			closing.Visible = true
			if fromEvent and HudLogic.emphasize(promptActive, HudMotion.reduced()) then
				HudMotion.pop(closingScale, T.EmphasisScale, T.Emphasis)
			end
			task.delay(L.ClosingFor, function()
				if closingToken == mine then
					closing.Visible = false
				end
			end)
		end
		lastShrinkSeq = seq
	end

	-- the feed: newest on top, four rows, each fading after T.Feed seconds
	local function isMe(name: string?): boolean
		return name ~= nil and (name == player.Name or name == player.DisplayName)
	end
	local function relayoutFeed()
		for index, row in feedRows do
			HudMotion.play(
				row.frame,
				"move",
				{ Position = UDim2.new(1, 0, 0, (index - 1) * (L.FeedRow + L.FeedGap)) },
				"base",
				"enter"
			)
		end
	end
	local function pushFeed(victim: string, attacker: string?, cause: string)
		local mine = isMe(victim) or isMe(attacker)
		local function name(n: string): string
			local tone = if isMe(n) then Tokens.hex["coral.300"] else Tokens.hex["ivory.50"]
			local short = if utf8.len(n) and (utf8.len(n) :: number) > 16
				then string.sub(n, 1, 15) .. "…"
				else n
			return `<font color="{tone}">{short}</font>`
		end
		local verb = `<font color="{Tokens.hex["stone.300"]}">`
		local line = if cause == "left"
			then `{name(victim)}  {verb}left</font>`
			elseif
				attacker
				and attacker ~= ""
				and cause == "knocked"
			then `{name(attacker)}  {verb}knocked out</font>  {name(victim)}`
			else `{name(victim)}  {verb}fell</font>`
		local frame = panel(feed.fade, 1, "s", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, SP[3], 0, 0),
			Size = UDim2.fromOffset(0, L.FeedRow),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0.1,
		})
		local label = text(frame, "body.strong", "ivory.50", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			RichText = true,
			Text = line,
		})
		make("UIPadding", label, {
			PaddingLeft = UDim.new(0, SP[3]),
			PaddingRight = UDim.new(0, SP[3] + 3),
		})
		-- the edge on the right: pink when the line is about you
		local ledge = make("Frame", frame, {
			Name = "Edge",
			BackgroundColor3 = colour(if mine then "coral.500" else "line.500"),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 3, 1, 0),
		})
		local row: FeedRow = { frame = frame, label = label, ledge = ledge, born = os.clock() }
		table.insert(feedRows, 1, row)
		while #feedRows > L.FeedRows do
			local old = table.remove(feedRows) :: FeedRow
			old.frame:Destroy()
		end
		relayoutFeed()
		if not feed.wanted then
			setGroup(feed, true)
		end
		task.delay(T.Feed, function()
			local at = table.find(feedRows, row)
			if at then
				table.remove(feedRows, at)
				HudMotion.play(frame, "fade", { BackgroundTransparency = 1 }, "quick", "exit")
				HudMotion.play(label, "fade", { TextTransparency = 1 }, "quick", "exit")
				task.delay(Tokens.motion.duration.quick, function()
					frame:Destroy()
				end)
				relayoutFeed()
				if #feedRows == 0 then
					setGroup(feed, false)
				end
			end
		end)
	end

	local bindRound: (Instance) -> ()
	bindRound = function(folder: Instance)
		roundFolder = folder
		-- The round service going away (or a Studio preview cleared) leaves no round, not its last one.
		folder.AncestryChanged:Connect(function(_, parent)
			if parent == nil and roundFolder == folder then
				roundFolder = nil
				lastStrip, lastPhase = nil, nil
				refreshStrip(false)
				refreshShrink(false)
				refreshGroups()
				local again = ReplicatedStorage:FindFirstChild(ROUND_FOLDER)
				if again and again ~= folder then
					bindRound(again)
				end
			end
		end)
		folder.AttributeChanged:Connect(function(name: string)
			if name == "ShrinkActive" or name == "ShrinkSeq" then
				refreshShrink(true)
			else
				refreshStrip(true)
				refreshShrink(false)
				refreshGroups()
			end
		end)
		local function hookRingOut(child: Instance)
			if child.Name == "RingOut" and child:IsA("RemoteEvent") then
				child.OnClientEvent:Connect(
					function(victim: string, attacker: string?, cause: string)
						if not inTraining() then
							pushFeed(victim, attacker, cause or "fell")
						end
					end
				)
			end
		end
		folder.ChildAdded:Connect(hookRingOut)
		for _, child in folder:GetChildren() do
			hookRingOut(child)
		end
		refreshStrip(false)
		refreshShrink(false)
		refreshGroups()
	end

	local found = ReplicatedStorage:FindFirstChild(ROUND_FOLDER)
	if found then
		bindRound(found)
	end
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == ROUND_FOLDER and roundFolder == nil then
			bindRound(child)
		end
	end)

	-- Devices: key caps and the guide follow the last input used ------------------------------------------
	local function setCap(label: TextLabel, glyph: ImageLabel, key: string)
		local image = ""
		if device == "gamepad" and PAD_KEYS[key] then
			image = UserInputService:GetImageForKeyCode(PAD_KEYS[key])
		elseif key == "M1" then
			image = HudTheme.Icons.mouse
		end
		glyph.Image = image
		glyph.Visible = image ~= ""
		label.Text = if image ~= "" then "" else key
		label.Visible = image == ""
	end
	local function refreshDevice()
		for _, id in ORDER do
			local tile = tiles[id]
			local key = (actionById[id].keys :: any)[device] or ""
			setCap(tile.capText, tile.capGlyph, key)
			tile.cap.Visible = device ~= "touch"
		end
		if device == "gamepad" then
			setCap(helpCapText, helpCapGlyph, "SELECT")
			helpCapText.Text = "SELECT"
		else
			setCap(helpCapText, helpCapGlyph, "H")
		end
		helpCap.Visible = device ~= "touch"
		local list = (HudTheme.Guide :: any)[device] or {}
		for order, row in guideRows do
			local item = list[order]
			row.frame.Visible = item ~= nil
			if item then
				row.key.Text = item.key
				row.info.Text = item.action
				task.spawn(function()
					local params = Instance.new("GetTextBoundsParams")
					params.Text = item.action
					params.Font = row.info.FontFace
					params.Size = row.info.TextSize
					params.Width = GUIDE_INFO
					local ok, bounds = pcall(function()
						return TextService:GetTextBoundsAsync(params)
					end)
					if row.info.Text == item.action then
						-- the measure knows nothing of the role's line height, so it is added here
						local height = if ok
							then math.ceil(bounds.Y * row.info.LineHeight) + 2
							else row.info.TextSize * 4
						row.info.Size = UDim2.fromOffset(GUIDE_INFO, height)
					end
				end)
			end
		end
		layout()
		refreshGroups()
	end
	UserInputService.LastInputTypeChanged:Connect(function(kind)
		local next = deviceOf(kind)
		if next and next ~= device then
			device = next
			refreshDevice()
		end
	end)

	local function toggleGuide()
		guide.Visible = not guide.Visible
	end
	helpChip.Activated:Connect(toggleGuide)
	self._toggleGuide = toggleGuide
	ContextActionService:BindActionAtPriority(HELP_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggleGuide()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.Low.Value, Enum.KeyCode.H, Enum.KeyCode.ButtonSelect)

	-- Your character ---------------------------------------------------------------------------------
	local function setStagger(value: number, animate: boolean)
		local before = stagger
		stagger = value
		local now = os.clock()
		local shown = math.floor(value + 0.5)
		if figure.Text ~= tostring(shown) then
			figure.Text = tostring(shown)
			-- the new figure rises 6 units into place (numbers move on events only)
			if animate and not HudMotion.reduced() then
				figureMove.PaddingTop = UDim.new(0, 12)
				figure.TextTransparency = 0.6
				HudMotion.play(
					figureMove,
					"swap",
					{ PaddingTop = UDim.new(0, 0) },
					"micro",
					"enter"
				)
				HudMotion.play(figure, "swap", { TextTransparency = 0 }, "micro", "enter")
			end
		end
		-- the band: white, then yellow from 40, then yellow -> red-orange from 70; the figure takes the same colour
		local newBand = HudLogic.staggerBand(value, STAGGER_MAX)
		bar.fill.BackgroundColor3 = if newBand == "critical"
			then Color3.new(1, 1, 1)
			elseif newBand == "rising" then colour("gold.400")
			else colour("ivory.50")
		barGradient.Enabled = newBand == "critical"
		figure.TextColor3 = if newBand == "critical"
			then colour("danger.600")
			elseif newBand == "rising" then colour("gold.400")
			else colour("ivory.50")
		if newBand == "critical" and band ~= "critical" and animate then
			if HudLogic.emphasize(promptActive, HudMotion.reduced()) then
				HudMotion.pop(youPulse, 1.04, Tokens.motion.duration.base)
			end
		end
		band = newBand
		-- recovering (a drop after 3 s without a hit) shows the ghost of where it was; hit relief does not
		if value > before then
			lastRise = now
			recovering = false
		elseif value < before then
			if HudLogic.recovering(value, before, now, lastRise, staggerCfg.RecoveryDelay) then
				if not recovering then
					recovering = true
					recoverFrom = before
				end
			end
		end
		if value <= 0 then
			recovering = false
		end
		local ghost = bar.ghost :: Frame
		ghost.Visible = recovering
		ghost.BackgroundColor3 = bar.fill.BackgroundColor3
		ghost.Size = UDim2.fromScale(math.clamp(recoverFrom / STAGGER_MAX, 0, 1), 1)
		drainTick.Visible = recovering
		-- the status word, so the band is never colour alone: CRITICAL wins over RECOVERING, that over RISING
		if newBand == "critical" then
			status.Text = "CRITICAL"
			status.TextColor3 = colour("danger.600")
		elseif recovering then
			status.Text = "RECOVERING"
			status.TextColor3 = colour("teal.400")
		elseif newBand == "rising" then
			status.Text = "RISING"
			status.TextColor3 = colour("gold.400")
		else
			status.Text = ""
		end
		-- what this stagger does to you: the knockback the next hit will use
		local mult = HudLogic.multiplierText(Combat.staggerMultiplier(staggerCfg :: any, value))
		knock.Text = `{mult}<font color="{Tokens.hex["stone.300"]}">x</font> knockback`
		speedNotch.Position =
			UDim2.fromScale(Combat.staggerSpeedShare(staggerCfg :: any, value), 0.5)
		speedNotch.Visible = value > 0
		-- the bar catches up from wherever it is now, so quick hits move toward the newest value
		barFrom = HudLogic.catchUp(barFrom, barTo, now - barSince, Tokens.motion.duration.quick)
		barTo = value / STAGGER_MAX
		barSince = if animate and not HudMotion.reduced() then now else -math.huge
	end

	local function onCharacter(model: Model)
		for _, conn in charConns do
			conn:Disconnect()
		end
		table.clear(charConns)
		character = model
		-- Nothing from a previous life carries over.
		stagger, barFrom, barTo, barSince = 0, 0, 0, -math.huge
		gaugeShown, overShown = 0, 0
		band, recovering, lastRise = "calm", false, -math.huge
		figure.Text = ""
		setStagger((model:GetAttribute("HT_Stagger") or 0) :: number, false)
		table.insert(
			charConns,
			model:GetAttributeChangedSignal("HT_Stagger"):Connect(function()
				setStagger((model:GetAttribute("HT_Stagger") or 0) :: number, true)
			end)
		)
		-- The groups enter again for the new life, once.
		you.wanted, kit.wanted = false, false
		refreshGroups()
	end
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function(model)
		if character == model then
			character = nil
			refreshGroups()
		end
	end)
	for _, name in { "HT_Eliminated", "HT_InTraining" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			refreshStrip(false)
			refreshShrink(false)
			refreshGroups()
		end)
	end

	-- Press and result feedback ----------------------------------------------------------------------
	local function press(tile: Tile)
		HudMotion.pressDown(tile.scale, 0.94)
		task.delay(Tokens.motion.duration.press, function()
			HudMotion.pressUp(tile.scale)
		end)
	end
	local function refuse(tile: Tile)
		tile.cap.BackgroundColor3 = colour("danger.600")
		HudMotion.play(
			tile.cap,
			"blocked",
			{ BackgroundColor3 = colour(tile.capTone) },
			"release",
			"enter"
		)
	end
	local function word(tile: Tile, say: string, tone: string)
		tile.word.Text = say
		tile.word.TextColor3 = colour(tone)
		tile.word.Visible = true
		tile.wordUntil = os.clock() + T.ResultWord
	end
	combat.PunchEvent:Connect(function(kind: string)
		local tile = tiles.punch
		if kind == "thrown" then
			press(tile)
		elseif kind == "blocked" then
			refuse(tile)
		elseif kind == "hit" then
			word(tile, "HIT", "coral.300")
		elseif kind == "miss" or kind == "cancelled" then
			word(tile, "MISS", "stone.300")
		end
	end)
	movement.Propelled:Connect(function()
		press(tiles.propel)
	end)
	movement.PropelBlocked:Connect(function()
		refuse(tiles.propel)
	end)
	-- Other kits' skills (Blink, Cyclone): the same press and refusal on the Q and R tiles.
	local slotTiles = { mobility = tiles.propel, attack = tiles.uppercut }
	ability.SkillUsed:Connect(function(slot: string)
		local tile = slotTiles[slot]
		if tile then
			press(tile)
		end
	end)
	ability.SkillBlocked:Connect(function(slot: string)
		local tile = slotTiles[slot]
		if tile then
			refuse(tile)
		end
	end)

	-- Touch: the cooldown drawn on the real buttons --------------------------------------------------
	local function touchOverlay(actionName: string): (Frame?, TextLabel?)
		local button = ContextActionService:GetButton(actionName)
		if not button then
			return nil, nil
		end
		local cover = button:FindFirstChild("HT_Cool") :: Frame?
		if not cover then
			cover = make("Frame", button, {
				Name = "HT_Cool",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 0),
				BackgroundColor3 = colour("ink.950"),
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				Active = false,
				ZIndex = 5,
			})
			Components.corner(cover :: Frame, "full")
			text(cover :: Frame, "mono.small", "ivory.50", {
				Name = "Seconds",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -2),
				Size = UDim2.fromOffset(40, 16),
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 6,
			})
		end
		return cover, (cover :: Frame):FindFirstChild("Seconds") :: TextLabel?
	end

	-- THE LOOP: one connection, no tweens started here except on state changes ---------------------------
	local lastCountdown = ""
	RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		local model = character
		-- Priority: a timed kick cue or a clash steps you and your kit back. Checked every frame, because the
		-- cue can start and end within one.
		local cueUp = kickPrompt:IsActive()
		local prompt = cueUp or (model ~= nil and model:GetAttribute("HT_Clash") ~= nil)
		if prompt ~= promptActive then
			promptActive = prompt
			refreshGroups()
		end

		if model then
			-- Stagger bar catch-up, and the teal tick at the fill's edge while recovering.
			local share =
				HudLogic.catchUp(barFrom, barTo, now - barSince, Tokens.motion.duration.quick)
			share = math.clamp(share, 0, 1)
			bar.fill.Size = UDim2.fromScale(share, 1)
			bar.fill.Visible = share > 0.002
			if recovering then
				drainTick.Position = UDim2.fromScale(share, 0.5)
			end

			-- Speed: the bar follows smoothly; past normal running, the short segment fills.
			local base, over = HudLogic.speedGauge(hud.speed, moveCfg.MaxSpeed, S.GaugeOverSpeed)
			local follow = math.min(T.GaugeRate * dt, 1)
			gaugeShown += (base - gaugeShown) * follow
			overShown += (over - overShown) * follow
			speedBase.fill.Size = UDim2.fromScale(gaugeShown, 1)
			speedBase.fill.Visible = gaugeShown > 0.01
			speedOver.fill.Size = UDim2.fromScale(overShown, 1)
			speedOver.fill.Visible = overShown > 0.01

			-- Each action from its own real timing.
			local blocked = model:GetAttribute("HT_Stunned") ~= nil
				or model:GetAttribute("HT_Air") == "hold"
				or model:GetAttribute("HT_Clash") ~= nil
				or model:GetAttribute("HT_RoundHold") ~= nil
			local punchReady, punchTotal, canPunch = combat:GetPunchTiming()
			local upperReady, upperTotal, canUpper = combat:GetUppercutTiming()
			-- Another kit's skill brings its own timing (AbilityController); one that isn't built has
			-- none, and is shown as unavailable.
			local hasDash = ability:GetSkill("mobility").id == "Dash"
			local hasUpper = ability:GetSkill("attack").id == "Uppercut"
			local moveReady, moveTotal, moveUsable = ability:GetTiming("mobility")
			local hitReady, hitTotal, hitUsable = ability:GetTiming("attack")
			-- Endlag holds back the mobility skill and the jump too (the swings already count it).
			local lagUntil = endlag:BusyUntil()
			if moveReady then
				moveReady = math.max(moveReady, lagUntil)
			end
			local kicking = hud.kickTarget ~= nil or hud.kicking == true
			local timings = {
				punch = {
					readyAt = punchReady,
					total = punchTotal,
					usable = canPunch and not blocked,
				},
				propel = if moveReady and moveTotal
					then { readyAt = moveReady, total = moveTotal, usable = moveUsable == true }
					else {
						readyAt = if hasDash then math.max(now + hud.propelLeft, lagUntil) else 0,
						total = moveCfg.PropelCooldown,
						usable = hasDash and not blocked,
					},
				-- Space: the air kick while there's someone to follow up (or one is under way), else the jump.
				kick = if kicking
					then { readyAt = hud.kickReadyAt, total = kickCfg.Cooldown, usable = true }
					else {
						readyAt = math.max(hud.jumpReadyAt, lagUntil),
						total = GameConfig.Jump.Cooldown,
						usable = not blocked,
					},
				uppercut = if hitReady and hitTotal
					then { readyAt = hitReady, total = hitTotal, usable = hitUsable == true }
					else {
						readyAt = if hasUpper then upperReady else 0,
						total = upperTotal,
						usable = hasUpper and canUpper and not blocked,
					},
			}
			local holding = model:GetAttribute("HT_Charging") ~= nil -- R is down (CombatController)
			for _, id in ORDER do
				local timing = (timings :: any)[id]
				local state = HudLogic.actionState(now, timing.readyAt, timing.usable)
				local tile = tiles[id]
				paintTile(tile, state, id == "uppercut" and holding)
				local left = HudLogic.cooldownLeft(now, timing.readyAt, timing.total)
				if state == "recovering" then
					tile.shadeClip.Size = UDim2.fromScale(1, left)
				end
				-- the seconds left: tenths under ten seconds, whole seconds above
				local wait = timing.readyAt - now
				local secs = if state ~= "recovering" or wait <= 0
					then ""
					elseif wait < 10 then string.format("%.1f", wait)
					else string.format("%d", math.ceil(wait))
				if secs ~= tile.secondsText then
					tile.secondsText = secs
					tile.seconds.Text = secs
				end
				-- above the tile: a result word for a moment, else the skill's name when names show
				if id == "kick" and cueUp then
					word(tile, "NOW", "gold.400")
				end
				tile.word.Visible = now < tile.wordUntil
				if device == "touch" then
					local cover, seconds = touchOverlay(actionById[id].touchAction)
					if cover then
						cover.Size = UDim2.fromScale(1, if state == "recovering" then left else 0)
						if seconds then
							seconds.Text = secs
						end
					end
				end
			end

			-- The target: your lock-on target (coral chevron + name), else the nearest opponent ahead (an open
			-- ivory chevron, no name).
			if now >= nextTargetPick then
				nextTargetPick = now + 0.1
				local locked: Model? = lockOn:GetTarget()
				local pick: Model? = locked
				local myRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				local camera = workspace.CurrentCamera
				if
					not pick
					and myRoot
					and camera
					and player:GetAttribute("HT_InTraining") ~= true
				then
					local best = S.TargetRange
					local look = camera.CFrame.LookVector
					for _, other in CollectionService:GetTagged(COMBATANT_TAG) do
						if
							other ~= model
							and other:IsA("Model")
							and not (
								other:GetAttribute("HT_Dummy") == true
								and other:GetAttribute("HT_Bot") ~= true
							)
						then
							local root = other:FindFirstChild("HumanoidRootPart") :: BasePart?
							if root then
								local offset = root.Position - myRoot.Position
								local distance = offset.Magnitude
								if distance < best and offset.Unit:Dot(look) > 0.3 then
									best, pick = distance, other
								end
							end
						end
					end
				end
				local isLocked = locked ~= nil
				if pick ~= target or isLocked ~= targetLocked then
					local fresh = pick ~= target
					target, targetLocked = pick, isLocked
					local root = pick and pick:FindFirstChild("HumanoidRootPart")
					marker.Adornee = root
					marker.Enabled = root ~= nil
					for _, arm in arms do
						arm.BackgroundColor3 = if isLocked
							then colour("coral.500")
							else colour("ivory.50")
						arm.BackgroundTransparency = if isLocked then 0 else 0.4
					end
					markerName.Visible = isLocked
					markerBar.track.Visible = isLocked
					if pick then
						local owner = Players:GetPlayerFromCharacter(pick)
						markerName.Text = if owner then owner.DisplayName else pick.Name
						if fresh and isLocked and not HudMotion.reduced() then
							markerScale.Scale = 1.06
							HudMotion.play(markerScale, "pop", { Scale = 1 }, "base", "enter")
						end
					end
				end
			end
			if target and targetLocked then
				-- the other-fighter ramp: faint ivory under 40, solid ivory 40-69, danger 70+ (thicker)
				local value = (target:GetAttribute("HT_Stagger") or 0) :: number
				local theirBand = HudLogic.staggerBand(value, STAGGER_MAX)
				markerBar.fill.Size = UDim2.fromScale(math.clamp(value / STAGGER_MAX, 0, 1), 1)
				markerBar.fill.Visible = value > 0
				markerBar.fill.BackgroundColor3 = if theirBand == "critical"
					then colour("danger.600")
					else colour("ivory.50")
				markerBar.fill.BackgroundTransparency = if theirBand == "calm" then 0.5 else 0
				markerBar.track.Size =
					UDim2.fromOffset(56, if theirBand == "critical" then 6 else 4)
			end
		end

		-- Countdowns tick once a second.
		if lastStrip and lastStrip.visible and lastStrip.count and lastPhase ~= "Fighting" then
			local info = HudLogic.strip(readRound(), workspace:GetServerTimeNow())
			if info.count and info.count ~= lastCountdown then
				lastCountdown = info.count
				stripCount.Text = info.count
			end
		end
	end)

	local function watchViewport()
		layout()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
	end
	watchViewport()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)

	refreshDevice()
	if player.Character then
		onCharacter(player.Character)
	end
	refreshStrip(false)
end

--- Shows or hides the controls guide (the navigation's Moves button and the fight menu call this).
function HudController:ToggleGuide()
	if self._toggleGuide then
		self._toggleGuide()
	end
end

return HudController
