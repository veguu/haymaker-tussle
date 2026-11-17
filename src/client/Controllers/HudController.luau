--!strict
-- HudController - the combat HUD in the fight-poster look (2026-11-16; the approved mockup is the vault's UI
-- Research/fight-poster-prototype.html). Slanted ink plates on the screen's edges; the centre is the fight's:
--   Y  bottom-left (top-left on phones): YOUR stagger. A slanted ink plate with your class colour on its left
--      edge, a big slanted number that climbs toward danger (not a health bar), STAGGER, the knockback it means
--      ("2.1x knockback"), one word (RISING / RECOVERING / STEADY) and a 12-segment bar. The number and the bar
--      go white, then yellow, then pink together.
--   K  bottom-right: the skills, ALWAYS shown in a fight: Jump and Punch small in light violet, then Q (mobility)
--      and R (attack) in your class colour, each with its icon, key cap and name. Three states, each a different
--      shape and word: ready (bright, a READY flag with a tick), cooling (dark, a fill rising from the bottom, the
--      seconds left) and can't use (dark with stripes, a slash, a flag that says why).
--   A  top centre: one slanted strip (next round in N, get ready, 18 / 25 standing, final two, round over), the
--      count in yellow, your class colour under it.
--   F  top right: the ring-out feed, newest on top, four rows; yours marked with a yellow edge.
--   the target: a chevron and the name over your lock-on target (an open one over the nearest opponent ahead
--      when nothing is locked), with a thin bar shaded by THEIR stagger.
--
-- It only draws. Every number comes from where the game keeps it: MovementController.Hud (propel and kick
-- timing), CombatController (punch timing and results), AbilityController (kit skills), EndlagController, the
-- character's HT_Stagger, and the round's HT_RoundState folder. Rules in Core/HudLogic; colours, steps and
-- timings in Ui/HudTheme; the slanted and rough-cut shapes are tinted images from Ui/Shapes. No combat input is
-- bound here; on touch the real ContextActionService buttons stay the only buttons, with the cooldown drawn on
-- them. Per frame it only moves a cooling tile's fill and seconds; everything else changes on events.
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
local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Typography = require(ReplicatedStorage.Shared.Typography)
local Components = require(script.Parent.Parent.Ui.Components)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)
local Callouts = require(script.Parent.Parent.Ui.Callouts)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)
local Poster = require(script.Parent.Parent.Ui.Poster)
local Shapes = require(script.Parent.Parent.Ui.Shapes)

local S, T = HudTheme.Size, HudTheme.Time
local ST, TT, SS = HudTheme.Stagger, HudTheme.Tile, HudTheme.Strip
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

-- Layout. Every number here is the MOCKUP'S OWN PIXEL at 1280 x 720, read off the mockup itself with
-- design/ui/mock_capture.py (--dump with "rects"), so the HUD stands where the approved design does.
type YouSpec = {
	box: Vector2, -- the plate as it stands on screen: slanted, so wider than its contents
	lean: number, -- how far the plate's top sits right of its bottom (8 degrees)
	edge: number, -- the class-colour edge on the left
	label: Vector2, -- top-left of the STAGGER line
	figure: Vector2, -- where the number's first digit starts, and its baseline
	figureFont: number,
	figureBox: Vector2, -- the number's box: least width, height. The bump turns about its centre
	figureTop: number,
	knockGap: number, -- from the end of the number's box to the knockback column
	lines: { number }, -- tops of the multiplier line and the two word lines
	segX: number,
	segBase: number, -- the segments stand on this line
	segWidth: number,
	segPitch: number,
}

local SEG_SKEW = math.tan(math.rad(20)) -- a segment leans 20 degrees
local SEG_OFF, SEG_ON = 14, 20 -- an unlit and a lit segment's height

local L = {
	Edge = SP[5], -- 24 from the safe edges
	-- YOUR STAGGER: the mockup's plate, whole, at YScale. The owner, 2026-11-16: smaller than the mockup. At
	-- 0.66 it is 264 x 110 units (20.6 % x 15.3 % of 1280 x 720; the mockup's is 31 % x 23 %) and its small
	-- labels land exactly on the 15-unit text floor, so this is as small as it goes without breaking that.
	YScale = 0.66,
	Y = {
		box = Vector2.new(399.5, 167),
		lean = 23.5,
		edge = 10,
		label = Vector2.new(46.4, 13),
		figure = Vector2.new(40.3, 122.6),
		figureFont = 96,
		figureBox = Vector2.new(150, 86.4),
		figureTop = 36,
		knockGap = 5,
		lines = { 44, 83, 106 },
		segX = 30.9,
		segBase = 153,
		segWidth = 23.83,
		segPitch = 27.83,
	} :: YouSpec,
	-- Phones: the mockup's touch plate (narrower, a 64 px number), under the top-left buttons.
	YPhone = {
		box = Vector2.new(310.3, 159),
		lean = 22.3,
		edge = 10,
		label = Vector2.new(41.9, 9),
		figure = Vector2.new(37.8, 89.7),
		figureFont = 64,
		figureBox = Vector2.new(100, 57.6),
		figureTop = 32,
		knockGap = 3,
		lines = { 40, 79, 102 },
		segX = 26.4,
		segBase = 149,
		segWidth = 17.17,
		segPitch = 21.17,
	} :: YouSpec,
	YPhoneTop = 84,
	YMargin = 16, -- room round the plate inside its group, so its shake and the number's punch are not clipped
	LineHeight = 23, -- a 15 px label's line in the mockup
	MultiplierHeight = 39, -- the 26 px "2.1x" line
	-- THE SKILL TILES: the mockup's sizes and places (right 26, bottom 24, 14 apart).
	TileBig = 104, -- Q and R: the class skills
	TileSmall = 84, -- Jump and Punch
	TileGap = 14,
	TileRight = 26,
	TileBottom = 24,
	TilePad = 34, -- room round the row inside its group, for the shadow, the pop and the result word
	TileLine = 4, -- the ink outline
	Cap = 28,
	K = Vector2.new(34 + 84 + 14 + 84 + 14 + 104 + 14 + 104 + 34, 34 + 104 + 34),
	-- THE STRIP: 72 tall with its 5-unit class-colour line, 18 from the top, leaning 10 degrees.
	Strip = Vector2.new(460, 72),
	StripEdge = 5,
	StripLean = 12.7,
	StripTop = 18,
	StripPad = 22,
	StripGap = 12,
	StripDrop = 10, -- the words sit this far under the number's centre (they share its baseline)
	Chip = 28,
	ChipLean = 6,
	FeedWidth = 300,
	FeedRow = 28,
	FeedGap = SP[1], -- 4
	FeedRows = 4,
	ClosingFor = 2.5, -- seconds the ARENA CLOSING chip shows each time a shrink begins
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

-- One skill tile: the rough-cut shape with an ink outline and a hard shadow, holding the icon, the key cap, the
-- name, the rising cooldown fill with the seconds left, the stripes and slash for "can't use", and (Q and R) the
-- flag that names the state. A result word shows above it.
type Tile = {
	id: string,
	big: boolean,
	column: Frame,
	box: Frame,
	rest: UDim2,
	scale: UIScale,
	line: ImageLabel,
	fill: ImageLabel,
	stripes: ImageLabel,
	riseClip: Frame,
	rise: ImageLabel,
	riseFull: number,
	riseShown: number,
	icon: ImageLabel,
	iconSize: number,
	seconds: TextLabel,
	slash: Frame,
	flag: Frame?,
	flagWord: TextLabel?,
	tick: Frame?,
	cap: Frame,
	capText: TextLabel,
	capGlyph: ImageLabel,
	name: TextLabel,
	word: TextLabel,
	bright: Color3,
	state: string,
	wordUntil: number,
	secondsText: string,
}

local function makeTile(parent: Instance, id: string, x: number, big: boolean): Tile
	local size = if big then L.TileBig else L.TileSmall
	local inner = size - 2 * L.TileLine
	local iconSize = if big then 46 else 34
	local column = make("Frame", parent, {
		Name = id,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(size, L.TilePad + L.TileBig),
	})
	-- a short result word (HIT / MISS / NOW) above the tile, briefly
	local word = Poster.text(column, "label", 15, "ivory.50", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(size + 2)),
		Size = UDim2.fromOffset(size + 16, 23),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	make("UIStroke", word, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = colour("ink.950"),
		Thickness = 1.5,
		Transparency = 0.3,
	})
	-- the tile itself, scaled and turned about its own centre (used, pop) and knocked sideways when refused
	local rest = UDim2.new(0.5, 0, 1, -size / 2)
	local box = make("Frame", column, {
		Name = "Box",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = rest,
		Size = UDim2.fromOffset(size, size),
	})
	local scale = make("UIScale", box, {})
	local shadow = TT.Shadow
	Shapes.image(box, "tile", shadow.tone, {
		Name = "Shadow",
		Position = UDim2.fromOffset(shadow.x, shadow.y),
		ImageTransparency = shadow.transparency,
	})
	local line = Shapes.image(box, "tile", TT.Line, { Name = "Line", ZIndex = 1 })
	-- the face: the same shape inside the outline, with the stripes and the rising fill over it
	local face = make("Frame", box, {
		Name = "Face",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(L.TileLine, L.TileLine),
		Size = UDim2.fromOffset(inner, inner),
		ZIndex = 2,
	})
	local fill = Shapes.image(face, "tile", TT.Dark, { Name = "Fill" })
	local stripes = Shapes.image(face, "stripes", TT.Stripe, {
		Name = "Stripes",
		Visible = false,
		ZIndex = 1,
	})
	-- the cooldown: the tile's own shape in a darker class colour, shown from the bottom up by a clip whose
	-- height is the share of the cooldown already run
	local riseClip = make("Frame", face, {
		Name = "RiseClip",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 1,
	})
	local rise = Shapes.image(riseClip, "tile", TT.Dark, {
		Name = "Rise",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(inner, inner),
	})
	local icon = make("ImageLabel", box, {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromOffset(iconSize, iconSize),
		Image = HudTheme.Icons[id] or "",
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	})
	local slash = make("Frame", box, {
		Name = "Slash",
		BackgroundColor3 = colour(TT.Blocked),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.84, 0, 0, 6),
		Rotation = -38,
		Visible = false,
		ZIndex = 4,
	})
	-- the seconds left: 34 px, right 8 and bottom 26 in the mockup (a small tile takes the same, in proportion)
	local seconds = Poster.text(box, "display", if big then 34 else 27, TT.OnDark, {
		Name = "Seconds",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = if big then UDim2.new(1, -8, 1, -51.5) else UDim2.new(1, -6, 1, -41.5),
		Size = UDim2.fromOffset(70, 51),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		ZIndex = 5,
	})
	local name = Poster.text(box, "label", 15, TT.OnDark, {
		Name = "SkillName",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, 0, 0, L.LineHeight),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
	})
	-- the key cap: cream with ink lettering, top left, at least 30 wide; a gamepad's glyph takes its place
	local cap = make("Frame", box, {
		Name = "Cap",
		BackgroundColor3 = colour("ivory.50"),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(30, L.Cap),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 5,
	})
	make("UIPadding", cap, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	make("UIListLayout", cap, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local capText = Poster.text(cap, "display", 16, TT.OnBright, {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local capGlyph = make("ImageLabel", cap, {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(L.Cap, L.Cap),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	})
	-- the flag, top right (Q and R): READY with a tick, or why the skill can't be used. In the mockup it lies
	-- over the key cap and hides the key; the key must always show, so here it reaches 8 units past the tile's
	-- right edge instead.
	local flag: Frame? = nil
	local flagWord: TextLabel? = nil
	local tick: Frame? = nil
	if big then
		local made = make("Frame", box, {
			Name = "Flag",
			BackgroundColor3 = colour(TT.Ready),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 6, 0, 10),
			Size = UDim2.fromOffset(0, L.LineHeight),
			AutomaticSize = Enum.AutomaticSize.X,
			Visible = false,
			ZIndex = 6,
		})
		make("UIStroke", made, {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = colour(TT.Line),
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = 2,
		})
		make("UIPadding", made, { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) })
		make("UIListLayout", made, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		})
		-- the tick: two strokes, so it never depends on a font having the glyph
		local mark = make("Frame", made, {
			Name = "Tick",
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(12, 11),
		})
		for _, arm in { { 2.7, 7.2, 5.5, 45 }, { 7.9, 5.4, 10, -50 } } do
			make("Frame", mark, {
				BackgroundColor3 = colour(TT.OnBright),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(arm[1], arm[2]),
				Size = UDim2.fromOffset(arm[3], 2),
				Rotation = arm[4],
			})
		end
		flagWord = Poster.text(made, "label", 15, TT.OnBright, {
			LayoutOrder = 2,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
		})
		flag, tick = made, mark
	end
	return {
		id = id,
		big = big,
		column = column,
		box = box,
		rest = rest,
		scale = scale,
		line = line,
		fill = fill,
		stripes = stripes,
		riseClip = riseClip,
		rise = rise,
		riseFull = inner,
		riseShown = -1,
		icon = icon,
		iconSize = iconSize,
		seconds = seconds,
		slash = slash,
		flag = flag,
		flagWord = flagWord,
		tick = tick,
		cap = cap,
		capText = capText,
		capGlyph = capGlyph,
		name = name,
		word = word,
		bright = colour(TT.Quiet),
		state = "",
		wordUntil = 0,
		secondsText = "",
	}
end

-- A tile's look for a state, told apart by shape and word as well as colour:
--   ready: the bright tile, and on Q and R the READY flag with its tick; coming off a cooldown a class skill
--     pops once (the mockup's `spop`: 1.6 times and turned 10 degrees, settling on its spring over 0.7 s);
--   recovering: dark, the fill rising from the bottom, the icon stepped aside for the seconds left;
--   held (the attack skill while its key is down): bright with a cream outline, no flag;
--   unavailable: dark with stripes and a slash, and on Q and R a flag that says STUNNED or CAN'T USE.
local function paintTile(tile: Tile, state: string, held: boolean, stunned: boolean)
	local key = if held
		then "held"
		elseif state == "unavailable" and stunned then "stunned"
		else state
	if tile.state == key then
		return
	end
	local was = tile.state
	tile.state = key
	local bright = held or state == "ready"
	local cooling = not held and state == "recovering"
	local blocked = not held and state == "unavailable"
	tile.line.ImageColor3 = colour(if held then TT.LineHeld else TT.Line)
	tile.fill.ImageColor3 = if bright then tile.bright else colour(TT.Dark)
	tile.stripes.Visible = blocked
	tile.slash.Visible = blocked
	tile.riseClip.Visible = cooling
	tile.riseShown = -1
	tile.name.TextColor3 = colour(if bright then TT.OnBright else TT.OnDark)
	tile.seconds.Visible = cooling
	-- cooling: the icon steps up and left at 36 / 46 of its size, to leave the seconds their corner
	local iconSize = if cooling then math.floor(tile.iconSize * 36 / 46 + 0.5) else tile.iconSize
	tile.icon.Size = UDim2.fromOffset(iconSize, iconSize)
	tile.icon.Position = if cooling then UDim2.fromScale(0.34, 0.36) else UDim2.fromScale(0.5, 0.44)
	tile.icon.ImageTransparency = if blocked then 0.45 elseif cooling then 0.2 else 0
	local flag, flagWord, tick = tile.flag, tile.flagWord, tile.tick
	if flag and flagWord and tick then
		flag.Visible = state ~= "recovering" and not held
		flag.BackgroundColor3 = colour(if blocked then TT.Blocked else TT.Ready)
		tick.Visible = not blocked
		flagWord.TextColor3 = colour(if blocked then TT.OnBlocked else TT.OnBright)
		flagWord.Text = if not blocked
			then TT.WordReady
			elseif stunned then TT.WordStunned
			else TT.WordBlocked
	end
	if key == "ready" and was == "recovering" and tile.big then
		Poster.run(tile, TT.PopSeconds, function(t: number)
			local s = PosterEase.spring(t)
			tile.scale.Scale = TT.PopScale + (1 - TT.PopScale) * s
			tile.box.Rotation = TT.PopTurn * (1 - s)
		end)
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

	-- Your class colour: the stagger plate's edge, the line under the strip, and the Q and R tiles.
	local classColour = colour("coral.500")

	-- A: the status strip, top centre ------------------------------------------------------------------
	-- a slanted ink plate with the class colour showing under it (yellow for the final two and the last one);
	-- the contents are a row inside it: the number in Oswald, the words beside it on the same baseline
	local strip = group(gui, "Strip", Vector2.new(L.Strip.X, L.Strip.Y + SP[2] + L.Chip))
	strip.holder.AnchorPoint = Vector2.new(0.5, 0)
	local stripPanel = make("Frame", strip.fade, {
		Name = "Panel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, L.Strip.Y),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	local stripLast = false
	local stripPlateHeight = L.Strip.Y - L.StripEdge
	-- the plate is the top of the same slanted shape, so it starts a little right of the edge's bottom corner
	local stripSlip = L.StripLean * L.StripEdge / L.Strip.Y
	local stripEdge = Shapes.slant(stripPanel, "coral.500", L.StripLean, { Name = "Edge" })
	Shapes.slant(stripPanel, SS.Plate, L.StripLean - stripSlip, {
		Name = "Plate",
		Position = UDim2.fromOffset(stripSlip, 0),
		Size = UDim2.new(1, -stripSlip, 0, stripPlateHeight),
		ZIndex = 1,
	})
	local stripRow = make("Frame", stripPanel, {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, stripPlateHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 2,
	})
	make("UIPadding", stripRow, {
		PaddingLeft = UDim.new(0, L.StripPad + L.StripLean / 2),
		PaddingRight = UDim.new(0, L.StripPad + L.StripLean / 2),
	})
	make("UIListLayout", stripRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, L.StripGap),
	})
	-- The count holds its place in the row with a clear copy of itself; the copy that shows sits on top, so its
	-- bump (2.4 times, turned, settling on the spring) never pushes the words about.
	local stripCountSlot = Poster.text(stripRow, "display", 34, SS.Count, {
		Name = "Count",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, stripPlateHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTransparency = 1,
	})
	local stripCount = Poster.text(stripCountSlot, "display", 34, SS.Count, {
		Name = "Shown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local countScale = make("UIScale", stripCount, {})
	-- words: 15 px, a little see-through, dropped onto the number's baseline
	local function stripWord(order: number): TextLabel
		local label = Poster.text(stripRow, "label", 15, SS.Word, {
			LayoutOrder = order,
			Size = UDim2.fromOffset(0, stripPlateHeight),
			AutomaticSize = Enum.AutomaticSize.X,
			TextTransparency = 0.15,
		})
		make("UIPadding", label, { PaddingTop = UDim.new(0, 2 * L.StripDrop) })
		return label
	end
	local stripTitle = stripWord(3) -- "/ 25 STANDING", FINAL TWO, NEXT ROUND ...
	local titleScale = make("UIScale", stripTitle, {})
	local stripRound = stripWord(4) -- ROUND 4
	-- the warning chip: a slanted pink plate with dark lettering, and the "!" so it isn't colour alone
	local closing = make("Frame", strip.fade, {
		Name = "Closing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, L.Strip.Y + SP[2]),
		Size = UDim2.fromOffset(0, L.Chip),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
	})
	Shapes.slant(closing, SS.Warning, L.ChipLean, { Name = "Plate" })
	local closingScale = make("UIScale", closing, {})
	local closingText = Poster.text(closing, "label", 15, SS.OnWarning, {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "!  ARENA CLOSING",
		ZIndex = 1,
	})
	make("UIPadding", closingText, {
		PaddingLeft = UDim.new(0, SP[3] + L.ChipLean),
		PaddingRight = UDim.new(0, SP[3] + L.ChipLean),
	})

	-- Y: you --------------------------------------------------------------------------------------------
	-- The mockup's plate, built at the mockup's own pixel sizes and shrunk as one piece by L.YScale. Two slanted
	-- images make it: the class colour underneath, showing as the left edge, and the ink over it.
	local stagger = 0
	local you = group(gui, "You", L.Y.box * L.YScale)
	local plateRest = UDim2.fromOffset(L.YMargin, L.YMargin)
	local youPlate = make("Frame", you.fade, {
		Name = "Plate",
		BackgroundTransparency = 1,
		Position = plateRest,
	})
	make("UIScale", youPlate, { Scale = L.YScale })
	local youEdge = Shapes.slant(youPlate, "coral.500", L.Y.lean, { Name = "Edge" })
	local youInk = Shapes.slant(youPlate, ST.Plate, L.Y.lean, { Name = "Ink", ZIndex = 1 })
	-- STAGGER leans with the plate in the mockup (it is the one line not stood back upright), so it is set in
	-- Titillium's own slanted Bold
	local staggerLabel = Poster.text(youPlate, "label", 15, ST.Label, {
		Name = "Label",
		Text = "STAGGER",
		TextTransparency = 0.15,
		ZIndex = 2,
	})
	staggerLabel.FontFace =
		Font.new(Tokens.family.text, Enum.FontWeight.Bold, Enum.FontStyle.Italic)
	-- the number: slanted Oswald digits from the sheet, in a box that scales and turns about its centre
	local figureBox = make("Frame", youPlate, {
		Name = "Figure",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	})
	local figureScale = make("UIScale", figureBox, {})
	local figure = Poster.number(figureBox, 3, { Name = "Digits", Size = UDim2.fromScale(1, 1) })
	local knock = Poster.text(youPlate, "display", 26, ST.Text, { Name = "Multiplier", ZIndex = 2 })
	local knockWord = Poster.text(youPlate, "label", 15, ST.Text, {
		Name = "Knockback",
		Text = "knockback",
		ZIndex = 2,
	})
	local status = Poster.text(youPlate, "label", 15, ST.Text, { Name = "Word", ZIndex = 2 })
	-- the 12 segments, each its own small slanted image (one drawing lit, one unlit); lit ones are taller and take their third's colour
	local segs: { ImageLabel } = {}
	local segTone: { Color3 } = {}
	local segHeight: { number } = {}
	for index = 1, ST.Segments do
		segs[index] = Shapes.image(youPlate, "segOff", ST.SegmentOff, {
			Name = `Seg{index}`,
			AnchorPoint = Vector2.new(0, 1),
			ZIndex = 2,
		})
		segHeight[index] = SEG_OFF
		segTone[index] =
			colour(ST.Tone[HudLogic.segmentTier(index, ST.Segments, ST.YellowShare, ST.PinkShare)])
	end
	local youSpec: YouSpec = L.Y
	local shownLit = 0
	-- One segment at a height: a 20-degree lean, standing on the base line, centred on its place in the row.
	local function placeSegment(index: number, height: number)
		local spec = youSpec
		local lean = height * SEG_SKEW
		local seg = segs[index]
		segHeight[index] = height
		seg.Size = UDim2.fromOffset(spec.segWidth + lean, height)
		seg.Position =
			UDim2.fromOffset(spec.segX + (index - 1) * spec.segPitch - lean / 2, spec.segBase)
		-- the lit drawing while it is any taller than an unlit one, so its lean stays true as it grows
		seg.Image = if height > SEG_OFF + 0.01 then Shapes.ids.segOn else Shapes.ids.segOff
	end
	-- Lights the segments for the current stagger. `all` re-places every one (a new layout); otherwise only the
	-- ones that changed are touched. A changed one grows or shrinks on the mockup's `pop` curve when `animate`.
	local function paintSegments(animate: boolean, all: boolean)
		local lit = HudLogic.segmentsLit(stagger, STAGGER_MAX, ST.Segments)
		for index, seg in segs do
			local on = index <= lit
			if all or on ~= (index <= shownLit) then
				seg.ImageColor3 = if on then segTone[index] else colour(ST.SegmentOff)
				local goal = if on then SEG_ON else SEG_OFF
				local from = segHeight[index]
				if animate and from ~= goal then
					Poster.run(seg, ST.SegmentSeconds, function(t: number)
						placeSegment(index, from + (goal - from) * PosterEase.pop(t))
					end)
				else
					Poster.stop(seg)
					placeSegment(index, goal)
				end
			end
		end
		shownLit = lit
	end
	-- The number, and the knockback column that starts where the number's box ends (the box is at least
	-- `figureBox` wide, wider for a wide number, as the mockup lays it out).
	local function paintFigure()
		local spec = youSpec
		local width = Poster.setNumber(
			figure,
			tostring(math.floor(stagger + 0.5)),
			spec.figureFont,
			spec.figure.Y - spec.figureTop
		)
		local box = Vector2.new(math.max(spec.figureBox.X, width), spec.figureBox.Y)
		figureBox.Size = UDim2.fromOffset(box.X, box.Y)
		figureBox.Position = UDim2.fromOffset(spec.figure.X + box.X / 2, spec.figureTop + box.Y / 2)
		local x = spec.figure.X + box.X + spec.knockGap
		knock.Position = UDim2.fromOffset(x, spec.lines[1])
		knockWord.Position = UDim2.fromOffset(x, spec.lines[2])
		status.Position = UDim2.fromOffset(x, spec.lines[3])
		-- what this stagger does to you: the knockback the next hit will use
		knock.Text = HudLogic.multiplierText(Combat.staggerMultiplier(staggerCfg :: any, stagger))
			.. "x"
	end

	-- K: the skill tiles ----------------------------------------------------------------------------------
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
		local x = L.TilePad
		for _, id in ORDER do
			local big = BIG[id] == true
			local tile = makeTile(kit.fade, id, x, big)
			tile.name.Text = string.upper(actionById[id].name)
			tiles[id] = tile
			x += (if big then L.TileBig else L.TileSmall) + L.TileGap
		end
	end
	-- The class skills' names sit in their tiles for good; they change only with the class.
	local function refreshNames()
		tiles.propel.name.Text = string.upper(ability:GetSkill("mobility").name)
		tiles.uppercut.name.Text = string.upper(ability:GetSkill("attack").name)
	end
	-- The class colour, wherever it shows. A class with no colour of its own falls back to yellow.
	local function paintClass()
		local hex = Tokens.hex[`class.{ability:GetKitId()}`]
		classColour = if hex then Color3.fromHex(hex) else colour("coral.500")
		Shapes.paint(youEdge, classColour)
		Shapes.paint(stripEdge, if stripLast then colour(SS.Last) else classColour)
		for _, id in ORDER do
			local tile = tiles[id]
			if tile.big then
				tile.bright = classColour
			end
			-- the mockup's fill: the tile's colour mixed 45 % toward black
			tile.rise.ImageColor3 = tile.bright:Lerp(Color3.new(), TT.FillShade)
			tile.state = "" -- repainted by the loop on the next frame
		end
	end
	refreshNames()
	paintClass()
	ability.KitChanged:Connect(function()
		refreshNames()
		paintClass()
	end)

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
		-- the tile row keeps spare room round it inside its group; the tiles themselves stop at the mockup's
		-- 26 from the right and 24 from the bottom
		local tilePad = L.TilePad * scale
		kit.holder.Position = UDim2.new(1, tilePad - L.TileRight, 1, tilePad - L.TileBottom)

		-- Your stagger plate, laid out in the mockup's pixels (its own UIScale shrinks it). Phones get the
		-- mockup's touch plate, top-left under the corner buttons.
		local phone = device == "touch"
		local spec: YouSpec = if phone then L.YPhone else L.Y
		youSpec = spec
		local k = L.YScale
		local margin = L.YMargin
		you.holder.Size = UDim2.fromOffset(spec.box.X * k + 2 * margin, spec.box.Y * k + 2 * margin)
		youPlate.Size = UDim2.fromOffset(spec.box.X, spec.box.Y)
		youEdge.Size = UDim2.fromOffset(spec.edge + 2 * spec.lean, spec.box.Y)
		youInk.Position = UDim2.fromOffset(spec.edge, 0)
		youInk.Size = UDim2.fromOffset(spec.box.X - spec.edge, spec.box.Y)
		Shapes.setLean(youEdge, spec.lean)
		Shapes.setLean(youInk, spec.lean)
		staggerLabel.Position = UDim2.fromOffset(spec.label.X, spec.label.Y)
		staggerLabel.Size = UDim2.fromOffset(120, L.LineHeight)
		knock.Size = UDim2.fromOffset(120, L.MultiplierHeight)
		knockWord.Size = UDim2.fromOffset(140, L.LineHeight)
		status.Size = UDim2.fromOffset(140, L.LineHeight)
		paintSegments(false, true)
		paintFigure()

		-- the plate's bottom-left corner stands 24 from the left and the bottom, as in the mockup; a slanted
		-- plate's box starts half its lean further left
		local pad = margin * scale
		local left = edge - spec.lean * k * scale / 2
		if phone then
			you.holder.AnchorPoint = Vector2.new(0, 0)
			you.holder.Position = UDim2.new(0, left - pad, 0, L.YPhoneTop - pad)
			help.AnchorPoint = Vector2.new(1, 0)
			help.Position =
				UDim2.new(1, -edge, 0, L.StripTop + feed.holder.Size.Y.Offset * scale + SP[2])
			guide.AnchorPoint = Vector2.new(1, 0)
			guide.Position = UDim2.new(1, 0, 1, SP[2])
		else
			you.holder.AnchorPoint = Vector2.new(0, 1)
			you.holder.Position = UDim2.new(0, left - pad, 1, pad - edge)
			help.AnchorPoint = Vector2.new(1, 1)
			help.Position =
				UDim2.new(1, -L.TileRight, 1, -(L.TileBottom + (L.TileBig + 22 + SP[2]) * scale))
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
	local shownTier = ""
	local shownWord = ""
	local risingUntil: number? = nil
	local lastRise = -math.huge
	local recovering = false
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
		stripCountSlot.Visible = info.count ~= nil and (fightingNow or counting)
		stripCountSlot.Text = info.count or ""
		stripCount.Text = info.count or ""
		stripCountSlot.LayoutOrder = if counting then 2 else 1
		stripTitle.Text = if info.total then `/ {info.total} {info.title}` else info.title
		stripTitle.LayoutOrder = if counting then 1 else 3
		stripRound.Visible = roundText ~= "" and not fightingNow
		stripRound.Text = roundText
		local last = info.finalTwo or (fightingNow and (round.alive or 0) <= 1)
		stripLast = last == true
		Shapes.paint(stripEdge, if stripLast then colour(SS.Last) else classColour)
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
			and fromEvent
		then
			-- the mockup's count bump: 2.4 times and turned, settling on the spring
			local function bumpCount()
				if HudLogic.emphasize(promptActive, HudMotion.reduced()) then
					Poster.run(stripCount, SS.BumpSeconds, function(t: number)
						local spring = PosterEase.spring(t)
						countScale.Scale = SS.BumpScale + (1 - SS.BumpScale) * spring
						stripCount.Rotation = SS.BumpTurn * (1 - spring)
					end)
				end
			end
			-- Down to 5, 4, 3 or 2 standing: the last-players popup, and the count bumps as it flies into the
			-- strip. Only when the count really fell to it in this fight, never on joining one already there.
			local alive = tonumber(info.count)
			local was = tonumber(before.count)
			if
				alive
				and was
				and alive < was
				and lastPhase == "Fighting"
				and Callouts.hasLast(alive)
			then
				Callouts.last(alive, device == "touch", bumpCount)
			else
				bumpCount()
			end
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
			tile.cap.BackgroundTransparency = if tile.capGlyph.Visible then 1 else 0
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
	local function paintWord(now: number)
		local say = HudLogic.staggerWord(now, lastRise, ST.RisingFor, recovering)
		if say ~= shownWord then
			shownWord = say
			status.Text = say
		end
	end

	-- The mockup's hit: the number comes in 1.8 times its size, turned 10 degrees, and settles on the spring
	-- over 0.6 s; the plate shakes for 0.32 s (three knocks, each eased). Neither plays under Reduced Motion.
	local SHAKE_X = { { 0, -10 }, { 0.35, 8 }, { 0.7, -4 }, { 1, 0 } }
	local SHAKE_Y = { { 0, 6 }, { 0.35, -5 }, { 0.7, 2 }, { 1, 0 } }
	local function bump()
		Poster.run(figureBox, ST.BumpSeconds, function(t: number)
			local s = PosterEase.spring(t)
			figureScale.Scale = ST.BumpScale + (1 - ST.BumpScale) * s
			figureBox.Rotation = ST.BumpTurn * (1 - s)
		end)
		Poster.run(youPlate, ST.ShakeSeconds, function(t: number)
			local k = L.YScale
			youPlate.Position = plateRest
				+ UDim2.fromOffset(
					PosterEase.keyframes(SHAKE_X, t, PosterEase.ease) * k,
					PosterEase.keyframes(SHAKE_Y, t, PosterEase.ease) * k
				)
		end)
	end

	local function setStagger(value: number, animate: boolean)
		local before = stagger
		stagger = value
		local now = os.clock()
		paintFigure()
		-- white, then yellow, then pink, at the same shares of the maximum as the bar's thirds
		local tier = HudLogic.staggerTier(value, STAGGER_MAX, ST.YellowShare, ST.PinkShare)
		if tier ~= shownTier then
			shownTier = tier
			Poster.tintNumber(figure, colour(ST.Tone[tier]))
		end
		if value > before then
			lastRise = now
			risingUntil = now + ST.RisingFor
			recovering = false
			if animate and HudLogic.emphasize(promptActive, HudMotion.reduced()) then
				bump()
			end
		elseif
			value < before
			and HudLogic.recovering(value, before, now, lastRise, staggerCfg.RecoveryDelay)
		then
			-- recovering is a drop after the server's delay without a hit; hit relief is not
			recovering = true
		end
		if value <= 0 then
			recovering = false
		end
		paintWord(now)
		paintSegments(animate, false)
	end

	local function onCharacter(model: Model)
		for _, conn in charConns do
			conn:Disconnect()
		end
		table.clear(charConns)
		character = model
		-- Nothing from a previous life carries over.
		stagger = 0
		recovering, lastRise, risingUntil = false, -math.huge, nil
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
	-- used: the mockup squashes the tile to 1.25 wide by 0.6 tall and springs it back over 0.5 s. Roblox can't
	-- stretch a tile's contents unevenly, so it shrinks evenly by the same area and springs back the same way.
	local function press(tile: Tile)
		Poster.run(tile, TT.UsedSeconds, function(t: number)
			tile.scale.Scale = TT.UsedScale + (1 - TT.UsedScale) * PosterEase.spring(t)
			tile.box.Rotation = 0
		end)
	end
	-- refused: the mockup's `nope`, 6 units left then right in 0.18 s; the tile's flag already says why
	local NOPE = { { 0, 0 }, { 0.25, -TT.Nudge }, { 0.75, TT.Nudge }, { 1, 0 } }
	local function refuse(tile: Tile)
		Poster.run(tile.box, TT.NudgeSeconds, function(t: number)
			tile.box.Position = tile.rest
				+ UDim2.fromOffset(PosterEase.keyframes(NOPE, t, PosterEase.ease), 0)
		end)
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

	-- MEASURING: set the player attribute HT_HudProfile to true and this loop publishes its own cost once a
	-- second as HT_HudMs (average milliseconds per frame). Off, it costs one test a frame.
	local profiling = false
	local profileSum, profileFrames, profileSince = 0, 0, 0
	player:GetAttributeChangedSignal("HT_HudProfile"):Connect(function()
		profiling = player:GetAttribute("HT_HudProfile") == true
		profileSum, profileFrames, profileSince = 0, 0, os.clock()
	end)

	-- THE LOOP: one connection. Nothing is tweened or written here unless a state or a shown value changed.
	local lastCountdown = ""
	RunService.RenderStepped:Connect(function()
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
			-- RISING lasts a moment after a gain, then the word settles.
			if risingUntil and now >= risingUntil then
				risingUntil = nil
				paintWord(now)
			end

			-- Each action from its own real timing.
			local stunned = model:GetAttribute("HT_Stunned") ~= nil
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
				paintTile(tile, state, id == "uppercut" and holding, stunned)
				local left = HudLogic.cooldownLeft(now, timing.readyAt, timing.total)
				if tile.state == "recovering" then
					-- the fill rises a whole unit at a time, so most frames write nothing
					local shown = math.floor((1 - left) * tile.riseFull + 0.5)
					if shown ~= tile.riseShown then
						tile.riseShown = shown
						tile.riseClip.Size = UDim2.new(1, 0, 0, shown)
					end
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
				stripCountSlot.Text = info.count
				stripCount.Text = info.count
			end
		end

		if profiling then
			profileSum += os.clock() - now
			profileFrames += 1
			if now - profileSince >= 1 then
				player:SetAttribute("HT_HudMs", profileSum / profileFrames * 1000)
				profileSum, profileFrames, profileSince = 0, 0, now
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
