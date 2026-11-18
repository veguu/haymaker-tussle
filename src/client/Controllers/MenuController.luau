--!strict
-- MenuController - THE POSTER WINDOW (2026-11-16), the lobby's one window, built to the approved mockup (the
-- vault's UI Research/fight-poster-prototype.html: `.sheet`, `draw()`). It replaces the Ringside shared window
-- and its Settings panel. NavController's buttons open it on the page they name.
--
-- A WINDOW, not a screen: the arena stays visible round it and behind the menu buttons. A cream slash down its
-- left side, the page's word repeated across it and a field of dots, both drifting slowly up and to the right,
-- and the whole window takes the colour of what is open (your picked class in Classes).
--   Classes   every class as a rough-cut tile in one warm-to-cool sweep; the picked one's Q and R, and Equip.
--   Shop      the classes you don't own, for Coins. Buy asks twice (Buy, then Confirm). Passes and Cosmetics are
--             shown as PLANNED: they are not in the game, and nothing is sold for Robux.
--   Ranked    PLANNED. No ranks, seasons or rewards are invented.
--   Moves     the controls for the device in your hands.
--   More      Settings, AFK, Spectate, and the planned rest (Cosmetics, Profile, Leaderboards, Emotes, Codes).
--   Settings  the three switches the old panel had. They still change nothing, and say so.
-- In a round only More, Moves and Settings open; the match never pauses.
--
-- Everything shown comes from AbilityController (the server's attributes); this only asks it to buy or equip.
-- Its notices show as a toast in the top-left corner, window open or not. M opens and closes the window; so do the X
-- and gamepad B. Sizes are the mockup's pixels at 1280 x 720; the window scales as a whole (Ui/PosterKit).
-- The window's edge leans 0.6 degrees as in the mockup; its CONTENTS stand straight, because Roblox cannot clip
-- or scroll anything that is turned. The drifting word needs a CanvasGroup for the same reason.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local ClassPreview = require(script.Parent.Parent.Ui.ClassPreview)
local Drift = require(script.Parent.Parent.Ui.Drift)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)
local Poster = require(script.Parent.Parent.Ui.Poster)
local PosterKit = require(script.Parent.Parent.Ui.PosterKit)
local Shapes = require(script.Parent.Parent.Ui.Shapes)
local UiSound = require(script.Parent.Parent.Ui.UiSound)

local book: any = Abilities
ClassPreview.lite = Drift.lite
-- how many class tiles a page of the Classes screen holds (two rows of four)
local CLASSES_PER_PAGE = 8
-- What every skill row on the Classes page says instead of the skill's own description. "" shows the real ones.
local SKILL_DETAIL_PLACEHOLDER = "Placeholder. This move's description comes later."
-- PLACEHOLDER TILES after the real classes (the owner, 2026-11-18: "make like 2 more pages with like 8
-- placeholders for both", to see the page arrows): dark striped tiles that say SOON and answer no press. They are
-- not classes: nothing about them is in Config/Abilities, the Shop or the saved data. Set to 0 to remove them.
local PLACEHOLDER_CLASSES = 16
local colour = Tokens.colour
local make = PosterKit.make
local spring = PosterEase.spring
-- the window's way in: fast, then settling, passing its place by about a hundredth of the run
local slideIn = PosterEase.bezier(0.22, 1.06, 0.36, 1)

local TOGGLE_ACTION = "HaymakerMenu"
local CLOSE_ACTION = "HaymakerMenuClose"

-- the mockup's window: 948 x 612 with a 6-unit ink border. (The mockup stands it 306 from the left and 86 from
-- the top, its edge under the open menu strip; here it stands clear of everything, see layout().)
local SHEET = Vector2.new(948, 612)
local BORDER = 6
local ROUND_TALL = 400 -- the window's height in a round: its title and about three rows; longer pages scroll
-- the menu strips' right edge in their own units: the widest (Moves, 44 in and 250 wide) sitting out 18 as the
-- open one and grown by 4 %, then a gap
local NAV_RIGHT = 26 + 44 + 18 + 250 * 1.02 + 12
-- the blur behind the open window: its size, and how long it takes to come and go
local BLUR = { Size = 10, In = 0.25, Out = 0.18 }
local BODY = Vector2.new(836, 580) -- the contents' box, 84 right and 8 down inside the border
local TILT = -0.6

-- the mockup lays the classes out as one sweep of colour, warm to cool
local SWEEP = { "Base", "Bruiser", "Inferno", "Beast", "Trickster", "Dragon", "Frost", "Tempest" }
local TITLES = {
	shop = "Shop",
	ranked = "Ranked",
	moves = "Moves",
	more = "More",
	settings = "Settings",
}
local TONES = {
	shop = "gold.400",
	ranked = "danger.600",
	moves = "violet.400",
	more = "violet.400",
	settings = "violet.400",
}
-- what opens while a round is on
-- In a round the MENU button's window is the Settings page and nothing else (the owner, 2026-11-18: simpler);
-- the controls have their own small panel at the bottom right (NavController).
local IN_ROUND_OK = { settings = true }
-- the old window's page names, still accepted by Open()
local OLD_NAMES = { Shop = "shop", Abilities = "classes", Cosmetics = "more" }
-- `help` is what the "?" beside the name shows under the pointer
local SETTINGS = {
	-- (the one switch that DOES something so far: HudController hears it and shows the old count instead)
	{
		id = "roster",
		name = "Fighter row",
		help = "Shows everyone still standing across the top in a fight.",
	},
	{ id = "shake", name = "Camera shake", help = "Shakes your camera on big hits." },
	{ id = "flash", name = "Hit flash", help = "Flashes the fighter you hit." },
	{ id = "music", name = "Music", help = "Plays the game's music." },
}
-- the Settings page's own plain rows: one column, a flat cream card each
local SROW = {
	X = 40,
	Width = 780,
	Height = 56,
	Gap = 10,
	Switch = Vector2.new(88, 36),
	Knob = 24,
	TipHold = 3,
}
local PLANNED = { "Cosmetics", "Profile", "Leaderboards", "Emotes", "Codes" }

local MenuController = Knit.CreateController({
	Name = "MenuController",
	-- (entry: string?) when the window opens on a page, changes page or closes
	Changed = Signal.new(),
	-- (id: string, on: boolean) when a Settings switch is pressed
	SettingChanged = Signal.new(),
})

local function classColour(kitId: string): Color3
	local hex = Tokens.hex[`class.{kitId}`]
	return if hex then Color3.fromHex(hex) else colour("coral.500")
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

local function deviceOf(): string
	local kind = UserInputService:GetLastInputType()
	if kind == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(kind.Name, "Gamepad") then
		return "gamepad"
	end
	return "mouse"
end

-- "Punch: a 4-hit string. The fourth knocks them away." -> "Punch", "A 4-hit string. The fourth knocks ..."
local function splitMove(action: string): (string, string)
	local name, rest = string.match(action, "^([^:%.]+)[:%.]%s*(.*)$")
	if not name then
		return action, ""
	end
	rest = rest or ""
	if rest ~= "" then
		rest = string.upper(string.sub(rest, 1, 1)) .. string.sub(rest, 2)
	end
	return name, rest
end

function MenuController:KnitStart()
	local player = Players.LocalPlayer
	local ability = Knit.GetController("AbilityController")

	local gui = make("ScreenGui", nil, {
		Name = "HT_Menu",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 20,
	})

	-- THE WINDOW -----------------------------------------------------------------------------------------
	local holder = make("Frame", gui, {
		Name = "Sheet",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SHEET.X, SHEET.Y),
		Visible = false,
	})
	local holderScale = make("UIScale", holder, {})
	-- everything slides in from the right together
	local slide = make("Frame", holder, {
		Name = "Slide",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	})
	local slideScale = make("UIScale", slide, {})
	-- the paper: shadow, ink border and the coloured field, leaning a little
	local decor = make("Frame", slide, {
		Name = "Paper",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Rotation = TILT,
	})
	make("Frame", decor, {
		Name = "Shadow",
		BackgroundColor3 = colour("ink.900"),
		BorderSizePixel = 0, -- solid: the corner bars below lie partly over it, and a see-through one showed darker there
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.fromScale(1, 1),
	})
	-- The shadow's two open corners, closed (owner, 2026-11-18: the top-right and bottom-left corners read as a
	-- border that did not meet). One turned bar from each of the border's corners to the shadow's, so the paper
	-- reads as one solid block. Each bar lies under the border and the shadow except for that small triangle.
	do
		local reach = Vector2.new(10, 12)
		local long = reach.Magnitude
		local thick = 8
		local turn = math.deg(math.atan2(reach.Y, reach.X))
		local normal = Vector2.new(-reach.Y, reach.X) / long * (thick / 2)
		for _, corner in
			{
				{ name = "ShadowTopRight", x = 1, y = 0, side = 1 },
				{ name = "ShadowBottomLeft", x = 0, y = 1, side = -1 },
			}
		do
			local centre = reach / 2 + normal * corner.side
			make("Frame", decor, {
				Name = corner.name,
				BackgroundColor3 = colour("ink.900"),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(corner.x, centre.X, corner.y, centre.Y),
				Size = UDim2.fromOffset(long, thick),
				Rotation = turn,
				ZIndex = 0,
			})
		end
	end
	make("Frame", decor, {
		Name = "Border",
		BackgroundColor3 = colour("ink.900"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	})
	local field = make("Frame", decor, {
		Name = "Field",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(BORDER, BORDER),
		Size = UDim2.new(1, -2 * BORDER, 1, -2 * BORDER),
		ZIndex = 2,
	})
	-- the drifting dots and word, clipped to the field EXACTLY and leaning with the paper (it is the paper's
	-- child). A CanvasGroup, because the word is turned 14 degrees and a turned thing is only ever clipped by one
	-- of these. (Until 2026-11-18 it stood straight, 12 in from the edge: a plain band showed all round the
	-- pattern, widest along the top, and when the paper kicked to 4 degrees the pattern stuck out past its border.)
	local back = make("CanvasGroup", decor, {
		Name = "Back",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(BORDER, BORDER),
		Size = UDim2.new(1, -2 * BORDER, 1, -2 * BORDER),
		ZIndex = 3,
	})
	local dots = make("ImageLabel", back, {
		Name = "Dots",
		BackgroundTransparency = 1,
		Image = Shapes.ids.dots,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(-32, -32),
		Size = UDim2.new(1, 64, 1, 64),
	})
	local wordsTurn = make("Frame", back, {
		Name = "Words",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(-0.12, -0.34),
		Size = UDim2.fromScale(1.7, 2),
		Rotation = -14,
		ZIndex = 2,
	})
	local words = make("ImageLabel", wordsTurn, {
		Name = "Tile",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Tile,
		Visible = false,
	})
	local wordWidth = 300
	-- the band that sweeps across when the page changes: a shade lighter than the field, never white
	local wipeLean = (SHEET.Y * 1.2) * math.tan(math.rad(18))
	local wipe = Shapes.slant(back, "ivory.50", wipeLean, {
		Name = "Wipe",
		Position = UDim2.fromScale(-0.45, -0.1),
		Size = UDim2.new(0.34, wipeLean, 1.2, 0),
		Visible = false,
		ZIndex = 3,
	})
	-- the cream slash down the left: full height, 12 % of the width at the top and 4 % at the bottom, with a
	-- thin ink line along its edge
	local inner = SHEET - Vector2.new(2 * BORDER, 2 * BORDER)
	local slashTop, slashBottom = inner.X * 0.12, inner.X * 0.04
	-- (it lies over the dots, the word and the wipe, inside the same clipped group: the group cuts the ink
	-- line's two ends flush with the border, where a turned bar's square ends used to stop short or stick out)
	-- Things that stay upright but must keep their place on the leaning paper (the X) are told the lean too.
	local tiltFollowers: { (degrees: number) -> () } = {}
	local function setTilt(degrees: number)
		decor.Rotation = degrees
		for _, follow in tiltFollowers do
			follow(degrees)
		end
	end
	local slash = make("Frame", back, {
		Name = "Slash",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, inner.X, 1, 0),
		ZIndex = 4,
	})
	make("Frame", slash, {
		BackgroundColor3 = colour("ivory.50"),
		BorderSizePixel = 0,
		Size = UDim2.new(0, slashBottom + 0.5, 1, 0),
	})
	Shapes.image(slash, "wedgeEnd", "ivory.50", {
		Name = "Edge",
		Position = UDim2.fromOffset(slashBottom, 0),
		Size = UDim2.new(0, slashTop - slashBottom, 1, 0),
	})
	-- the thin ink line along its edge: one turned bar. (Not Shapes.slant: a slanted PLATE can't be thinner than
	-- its own lean, and asked for one it drew a wide ink band; first run, 2026-11-17.)
	local lineLean = slashTop - slashBottom
	local lineWide = inner.X * 0.009
	local slashLine = make("Frame", slash, {
		Name = "Line",
		BackgroundColor3 = colour("ink.900"),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	})
	-- The window's height. It is the mockup's 612 in the lobby and SHORT in a round, where its pages are a few
	-- rows and the room between the strip and the skill tiles is small: a shorter window can be drawn larger.
	local sheetTall = SHEET.Y
	local function setTall(tall: number)
		sheetTall = tall
		holder.Size = UDim2.fromOffset(SHEET.X, tall)
		local innerTall = tall - 2 * BORDER
		local lineTurn = math.atan(lineLean / innerTall)
		slashLine.Position =
			-- (1.5 units onto the cream: with its edge exactly on the wedge's, the wedge's soft edge showed as a
			-- pale hairline between the cream and the ink; seen enlarged, 2026-11-18)
			UDim2.fromOffset(slashBottom + lineLean / 2 + lineWide / 2 - 1.5, innerTall / 2)
		slashLine.Size = UDim2.fromOffset(
			lineWide * math.cos(lineTurn),
			innerTall / math.cos(lineTurn) + 4 * lineWide
		)
		slashLine.Rotation = math.deg(lineTurn)
	end
	setTall(SHEET.Y)

	-- the contents: straight, in the mockup's own coordinates
	local body = make("Frame", slide, {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(BORDER + 84, BORDER + 8),
		Size = UDim2.new(0, BODY.X, 1, -(SHEET.Y - BODY.Y)),
		ZIndex = 5,
	})
	-- the title: 84 px Oswald, cream with an ink outline and shadow, turned 3 degrees about its bottom-left
	local titleBox, setTitle = PosterKit.title(body, 84, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(802, 84),
		Rotation = -3,
		ZIndex = 3,
	})
	do
		-- turning about the bottom-left corner is turning about the centre and then moving the centre
		local half = Vector2.new(401, -42)
		local angle = math.rad(-3)
		local turned = Vector2.new(
			half.X * math.cos(angle) - half.Y * math.sin(angle),
			half.X * math.sin(angle) + half.Y * math.cos(angle)
		)
		titleBox.Position = UDim2.fromOffset(34 + turned.X, 84 + turned.Y)
	end
	local titleScale = make("UIScale", titleBox, {})
	local titleRest = titleBox.Rotation
	local sub = Poster.text(body, "label", 16, "ink.900", {
		Name = "Sub",
		Position = UDim2.fromOffset(40, 90),
		Size = UDim2.fromOffset(796, 24),
		ZIndex = 3,
	})
	-- THE PICKED CLASS, STANDING: your avatar in that class's pose, right of the tiles and over the Equip button
	-- (Ui/ClassPreview): an R6 body about 290 units across, standing INSIDE the window between the tiles and its
	-- right edge. It is the window's own child, not the page's, so a pose that throws an arm wide is not cut off
	-- at the page's edge: it reaches a little past the window's side, as the owner's references do.
	local preview = ClassPreview.new(slide, {
		-- (centred in the open space between the tiles and the window edge, and UNDER the page, since 2026-11-18:
		-- the owner wants it further in, with the tiles, the rows and the button drawn over it where they meet)
		-- (2026-11-18: tried CLEAR of the page arrow and the tiles, at 0.82 of this size and 93 further right,
		-- 618, 121 at 328 x 353; the owner looked and had it put back here)
		Position = UDim2.fromOffset(BORDER + 84 + 525, BORDER + 8 + 44),
		Size = UDim2.fromOffset(400, 430),
		ZIndex = 4,
	})
	local classPage = 1
	-- (a testing knob: the workspace attribute HT_ClassesPerPage makes pages smaller, to see the arrows)
	local function classesPerPage(): number
		local forced = workspace:GetAttribute("HT_ClassesPerPage")
		return if typeof(forced) == "number" and forced >= 1
			then math.floor(forced)
			else CLASSES_PER_PAGE
	end
	-- the page: straight below the title, scrolling when it has more than fits (the shop, for a new player)
	local page = make("ScrollingFrame", body, {
		Name = "Page",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.new(1, 14, 1, -118),
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = colour("ink.900"),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 2,
	})
	local PAGE_TOP = 118 -- a page's children use the mockup's body coordinates, less this

	-- THE TOAST ------------------------------------------------------------------------------------------
	-- the mockup's `.toast`: cream, an ink border, 18 px, turned 1.5 degrees, 88 from the top; it pops in
	local toastGui = make("ScreenGui", nil, {
		Name = "HT_Toast",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 22,
	})
	local toast = make("Frame", toastGui, {
		Name = "Toast",
		BackgroundColor3 = colour("ink.900"),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = 0, -- straight: small text turned even a degree is drawn soft (measured 2026-11-17)
		Visible = false,
	})
	local toastScale = make("UIScale", toast, {})
	make("UIPadding", toast, {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	})
	local toastText = Poster.text(toast, "label", 18, "ink.900", {
		BackgroundColor3 = colour("ivory.50"),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	toastText.FontFace = Font.new(Tokens.family.text, Enum.FontWeight.Bold)
	make("UIPadding", toastText, { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) })
	local TOAST = { Lower = 44, Bigger = 1.3 }
	local toastToken = 0
	local function showToast(message: string)
		toastToken += 1
		local mine = toastToken
		-- The mockup stands it at the top centre, over the window's title. Here nothing lies over anything
		-- (owner, 2026-11-17), so it stands in the top-left corner: right of the fight's MENU button, above the
		-- menu strips, left of the strip.
		local stage = PosterKit.stage()
		local scale = stage.nav
		local press = math.max(scale, PosterKit.Fit.Button)
		toastText.Text = message
		-- (lower and bigger since 2026-11-18: on the owner's PC it read small, and it stood under Roblox's own
		-- performance bar when that is switched on)
		toast.Position = UDim2.fromOffset(22 + 68 * press + 14, 18 + 34 * press + TOAST.Lower)
		toast.Visible = true
		Poster.run(toast, 0.55, function(t: number)
			local s = spring(t)
			-- A long line would reach over the open window's left edge (seen 2026-11-18, about 25 px): it is
			-- drawn just small enough to end short of it, never under 0.9 of the lobby's scale.
			local full = scale * TOAST.Bigger
			local now = toastScale.Scale
			if holder.Visible and now > 0.02 then
				local natural = toast.AbsoluteSize.X / now
				local room = holder.AbsolutePosition.X - 10 - toast.AbsolutePosition.X
				if natural > 0 and room > 0 then
					full = math.clamp(room / natural, scale * 0.9, full)
				end
			end
			toastScale.Scale = math.max(full * (0.3 + 0.7 * s), 0.01)
			toast.Rotation = -12 + 12 * s
		end)
		task.delay(2.2, function()
			if toastToken == mine then
				toast.Visible = false
			end
		end)
	end
	ability.Notice:Connect(function(message: string)
		showToast(message)
	end)

	-- STATE ----------------------------------------------------------------------------------------------
	local entry: string? = nil
	local lastEntry = "classes"
	local pick: string = ability:GetKitId()
	local confirming: string? = nil
	local settingsState: { [string]: boolean } =
		{ roster = true, shake = true, flash = true, music = true }
	MenuController._settings = settingsState
	local fieldColour = colour("coral.500")
	local driftSince = os.clock()
	local driftConn: RBXScriptConnection? = nil
	local draw: (fresh: boolean) -> ()
	local open: (to: string) -> ()
	-- when Equip and Confirm were last pressed: their sounds answer only the player's own request
	local askedEquip, askedBuy = -math.huge, -math.huge
	local ASKED_FOR = 5
	local close: () -> ()

	local function inRound(): boolean
		return player:GetAttribute("HT_InRound") == true
	end

	-- The window's colour, and with it the dots, the word and the wipe (each the field mixed toward white).
	-- `detail`, when given, colours the dots, the word and the wipe itself: a WHITE window has nothing lighter to
	-- mix toward, so its details are drawn in a pale tint instead.
	local function tint(tone: Color3, detail: Color3?)
		fieldColour = tone
		field.BackgroundColor3 = tone
		local white = Color3.new(1, 1, 1)
		dots.ImageColor3 = detail or tone:Lerp(white, 0.38)
		words.ImageColor3 = detail or tone:Lerp(white, 0.42)
		Shapes.paint(wipe, detail or tone:Lerp(white, 0.4))
	end

	-- The word repeated behind the page. A word with no tile draws none.
	local function setWord(word: string)
		local tile = Shapes.words[word]
		words.Visible = tile ~= nil
		if tile then
			wordWidth = tile.width
			words.Image = tile.id
			words.TileSize = UDim2.fromOffset(tile.width, 168)
			words.Size = UDim2.new(1, 2 * tile.width, 1, 168)
		end
	end

	-- The drift: the word moves one word-and-gap right and two rows up every 18 s, the dots one cell every 7 s,
	-- both looping without a seam. It runs only while the window is open, and not under Reduced Motion.
	local function drift()
		local t = os.clock() - driftSince
		local a = (t / 18) % 1
		words.Position = UDim2.fromOffset(-wordWidth + wordWidth * a, -168 * a)
		local b = (t / 7) % 1
		dots.Position = UDim2.fromOffset(-32 + 32 * b, -32 * b)
	end
	local function setDrift(on: boolean)
		if driftConn then
			driftConn:Disconnect()
			driftConn = nil
		end
		drift()
		if on and not HudMotion.reduced() then
			driftConn = RunService.RenderStepped:Connect(drift)
		end
	end

	-- The page change: one soft band sweeps across (0.5 s), and the paper gives a small kick (0.6 s).
	local function hit()
		if HudMotion.reduced() then
			return
		end
		wipe.Visible = true
		local width = SHEET.X * 0.34 + wipeLean
		Poster.run(wipe, 0.5, function(t: number)
			local e = PosterEase.easeOut(t)
			wipe.Position = UDim2.new(-0.45, width * 4.7 * e, -0.1, 0)
			local clear = 1 - 0.55 * (1 - e)
			for _, piece in wipe:GetChildren() do
				if piece:IsA("ImageLabel") then
					piece.ImageTransparency = clear
				elseif piece:IsA("Frame") then
					piece.BackgroundTransparency = clear
				end
			end
		end, function()
			wipe.Visible = false
		end)
		Poster.run(decor, 0.6, function(t: number)
			local s = spring(t)
			slideScale.Scale = 0.9 + 0.1 * s
			setTilt(4 + (TILT - 4) * s)
		end)
	end

	-- PAGES ----------------------------------------------------------------------------------------------
	local function clear()
		Drift.clear("page")
		for _, child in page:GetChildren() do
			Poster.stop(child)
			child:Destroy()
		end
		page.CanvasPosition = Vector2.zero
		page.CanvasSize = UDim2.new()
	end

	-- An action button (`.act`): 250 x 66, the words in 28 px Oswald. `kind` picks its colours; "off" is a
	-- button that can't be pressed, "sure" the second press of a purchase.
	local function action(
		parent: Instance,
		x: number,
		y: number,
		words_: string,
		kind: string,
		onPress: (() -> ())?,
		height: number?,
		slot: number? -- which idle-drift pace it keeps when the page is drawn again
	): (PosterKit.Cut, TextLabel)
		local fill = if kind == "go"
			then colour("go.400")
			elseif kind == "buy" then colour("gold.400")
			elseif kind == "sure" then colour("ink.900")
			elseif kind == "plain" then colour("ivory.50")
			else colour("violet.400")
		local tall = height or 66
		local cut = PosterKit.cut(parent, "act", Vector2.new(250, tall), fill)
		PosterKit.place(cut, x, y)
		local label = Poster.text(cut.face, "display", if tall < 60 then 20 else 28, "ink.900", {
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(words_),
			TextColor3 = colour(if kind == "sure" then "gold.400" else "ink.900"),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		if kind == "sure" then
			-- the mockup's dashed inner line; Roblox draws no dashes, so it is a plain one
			local ring = make("Frame", cut.face, {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(11, 11),
				Size = UDim2.new(1, -22, 1, -22),
			})
			make("UIStroke", ring, { Color = colour("gold.400"), Thickness = 3 })
		end
		if onPress and kind ~= "off" then
			PosterKit.pressable(cut, onPress)
			if not Drift.lite then
				Drift.add("page", cut.body, tall, 4, slot) -- up and down only: it carries words
			end
		end
		return cut, label
	end

	-- The class you are wearing: EQUIPPED, quiet, until the pointer comes onto it. Then it turns red, says
	-- UNEQUIP and gives a small wobble; pressing it puts the starting class back on (the owner, 2026-11-17).
	-- On a phone the first tap shows UNEQUIP for a few seconds and the second one does it.
	local WOBBLE = { { 0, 0 }, { 0.2, -4 }, { 0.5, 3 }, { 0.8, -1 }, { 1, 0 } }
	local WORN = { Arm = 0.15, TouchHold = 3, Seconds = 0.45, Pop = 1.5 }
	local function wornAction(parent: Instance, x: number, y: number)
		local armedAt: number? = nil
		local cut, label = action(parent, x, y, "Equipped", "worn", function()
			if armedAt and os.clock() - armedAt >= WORN.Arm then
				askedEquip = os.clock()
				ability:Equip(book.DefaultKit)
			end
		end, nil, 40)
		local labelScale = make("UIScale", label, {})
		local quiet, loud = colour("violet.400"), colour("stop.400")
		local function show(on: boolean)
			if (armedAt ~= nil) == on then
				return
			end
			armedAt = if on then os.clock() else nil
			label.Text = if on then "UNEQUIP" else "EQUIPPED"
			label.TextColor3 = colour(if on then "ivory.50" else "ink.900")
			local from = cut.fill.ImageColor3
			local to = if on then loud else quiet
			Poster.run(cut.fill, WORN.Seconds, function(t: number)
				cut.fill.ImageColor3 = from:Lerp(to, math.min(1, t * 3))
				labelScale.Scale = if on then WORN.Pop + (1 - WORN.Pop) * spring(t) else 1
				cut.shape.Rotation = if on
					then PosterEase.keyframes(WOBBLE, t, PosterEase.ease)
					else 0
			end)
		end
		local button = cut.button
		if button then
			button.MouseEnter:Connect(function()
				show(true)
			end)
			button.MouseLeave:Connect(function()
				if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
					task.delay(WORN.TouchHold, function()
						if cut.root.Parent then
							show(false)
						end
					end)
				else
					show(false)
				end
			end)
		end
	end

	-- A class's name on a tile or a slab: the image of it in the mockup's own font (Ui/Shapes.letters), set in
	-- the middle of a line `tall` high as the text was; real text for a class that isn't on the sheet yet.
	local function className(
		parent: Instance,
		name: string,
		css: number,
		x: number,
		y: number,
		tall: number
	)
		local key = "class:" .. string.upper(name)
		if Poster.hasWord("words", key) then
			Poster.word(parent, "words", key, css, "ink.900", {
				Position = UDim2.fromOffset(x, y + (tall - css) / 2),
				ZIndex = 2,
			})
		else
			Poster.text(parent, "display", css, "ink.900", {
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(250, tall),
				Text = string.upper(name),
				ZIndex = 2,
			})
		end
	end

	local function standing(kitId: string, wearing: string, owned: { [string]: boolean }): string
		return if kitId == wearing then "EQUIPPED" elseif owned[kitId] then "OWNED" else "NOT OWNED"
	end

	-- the classes in the mockup's order, then any the game has that the mockup didn't know
	local function classOrder(): { string }
		local order = {}
		for _, id in SWEEP do
			if book.Kits[id] then
				table.insert(order, id)
			end
		end
		for _, id in book.Order do
			if not table.find(order, id) then
				table.insert(order, id)
			end
		end
		return order
	end

	local function drawClasses(fresh: boolean)
		local wearing = ability:GetKitId()
		local owned = ability:GetOwned()
		if not book.Kits[pick] then
			pick = wearing
		end
		local kit = book.Kits[pick]
		tint(classColour(pick))
		setWord(pick)
		setTitle(kit.name)
		local order = classOrder()
		for slot = 1, PLACEHOLDER_CLASSES do
			table.insert(order, `?{slot}`)
		end
		local per = classesPerPage()
		local pages = math.max(1, math.ceil(#order / per))
		if fresh then
			-- opened afresh: on the page that holds the picked class
			classPage = math.ceil((table.find(order, pick) or 1) / per)
		end
		classPage = math.clamp(classPage, 1, pages)
		sub.Text = if pages > 1
			then `YOUR CLASSES · PICK ONE TO FIGHT WITH · PAGE {classPage} OF {pages}`
			else "YOUR CLASSES · PICK ONE TO FIGHT WITH"
		for index = 1, per do
			local id = order[(classPage - 1) * per + index]
			if not id then
				break
			end
			if string.sub(id, 1, 1) == "?" then
				-- a placeholder: where a class will stand one day
				local cut = PosterKit.cut(
					page,
					"class",
					Vector2.new(132, 112),
					colour("poster.dark"),
					Vector2.new(5, 6)
				)
				PosterKit.place(
					cut,
					44 + ((index - 1) % 4) * 144,
					128 - PAGE_TOP + math.floor((index - 1) / 4) * 124
				)
				cut.root.ZIndex = 2
				Shapes.image(cut.face, "classStripes", "ink.900", {
					Position = UDim2.fromOffset(4, 4),
					Size = UDim2.new(1, -8, 1, -8),
					ImageTransparency = 0.6,
				})
				Poster.text(cut.face, "display", 62, "ivory.50", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -10, 0, 4),
					Size = UDim2.fromOffset(70, 62),
					Text = "?",
					TextTransparency = 0.72,
					TextXAlignment = Enum.TextXAlignment.Right,
				})
				Poster.text(cut.face, "display", 22, "ivory.50", {
					Position = UDim2.fromOffset(12, 50),
					Size = UDim2.fromOffset(110, 32),
					Text = "SOON",
				})
				local soon = Poster.text(cut.face, "label", 15, "ivory.50", {
					BackgroundColor3 = colour("ink.900"),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(10, 81),
					Size = UDim2.fromOffset(0, 23),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = "PLANNED",
					ZIndex = 2,
				})
				make(
					"UIPadding",
					soon,
					{ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }
				)
				if fresh then
					PosterKit.pop(cut.root, cut.scale, 0.12 + (index - 1) * 0.04, 1, 0)
				end
				continue
			end
			local other = book.Kits[id]
			local state = standing(id, wearing, owned)
			local picked = id == pick
			local column, rowIndex = (index - 1) % 4, math.floor((index - 1) / 4)
			local cut = PosterKit.cut(
				page,
				"class",
				Vector2.new(132, 112),
				classColour(id),
				Vector2.new(5, 6)
			)
			PosterKit.place(
				cut,
				44 + column * 144,
				128 - PAGE_TOP + rowIndex * 124 - (if picked then 8 else 0)
			)
			cut.root.ZIndex = if picked then 3 else 2
			if state == "NOT OWNED" then
				Shapes.image(cut.face, "classStripes", "ink.900", {
					Position = UDim2.fromOffset(4, 4),
					Size = UDim2.new(1, -8, 1, -8),
					ImageTransparency = 0.6,
				})
			end
			Poster.text(cut.face, "display", 62, "ink.900", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 4),
				Size = UDim2.fromOffset(70, 62),
				Text = string.upper(string.sub(other.name, 1, 1)),
				TextTransparency = 0.72,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			className(cut.face, other.name, 22, 12, 50, 32)
			local badge = Poster.text(cut.face, "label", 15, "ivory.50", {
				BackgroundColor3 = colour("ink.900"),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(10, 81),
				Size = UDim2.fromOffset(0, 23),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = state,
				ZIndex = 2,
			})
			make(
				"UIPadding",
				badge,
				{ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }
			)
			if picked then
				-- the picked tile sits up, tipped, a little larger, with a cream line inside it
				local ring = make("Frame", cut.face, {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(9.5, 9.5),
					Size = UDim2.new(1, -19, 1, -19),
					ZIndex = 3,
				})
				make("UIStroke", ring, { Color = colour("ivory.50"), Thickness = 3 })
				cut.scale.Scale = 1.06
				cut.root.Rotation = 0 -- (the mockup tips it 2 degrees; turned small text is drawn soft)
			end
			PosterKit.pressable(cut, function()
				if pick ~= id then
					pick = id
					confirming = nil
					UiSound.play("ui_page")
					hit()
					draw(false)
				end
			end, picked)
			if not picked and not Drift.lite then
				-- (the picked tile answers no press, so it holds still)
				Drift.add("page", cut.body, 112, 4, index)
			end
			if fresh then
				PosterKit.pop(
					cut.root,
					cut.scale,
					0.12 + (index - 1) * 0.04,
					if picked then 1.06 else 1,
					0
				)
			end
		end
		-- More classes than one page holds: an arrow right of the tiles turns to the next page, and from the
		-- second page on one left of them turns back (the owner, 2026-11-18). With one page there are none.
		local function pageArrow(x: number, sign: string, to: number)
			local cut = PosterKit.cut(
				page,
				"close",
				Vector2.new(40, 72),
				colour("ivory.50"),
				Vector2.new(4, 5)
			)
			PosterKit.place(cut, x, 128 - PAGE_TOP + 82)
			Poster.text(cut.face, "display", 28, "ink.900", {
				Size = UDim2.fromScale(1, 1),
				Text = sign,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			PosterKit.pressable(cut, function()
				classPage = to
				UiSound.play("ui_page")
				hit()
				draw(false)
			end)
			if not Drift.lite then
				Drift.add("page", cut.body, 72, 3, 20 + to)
			end
		end
		if classPage < pages then
			pageArrow(612, ">", classPage + 1)
		end
		if classPage > 1 then
			pageArrow(0, "<", classPage - 1)
		end
		preview.show(pick, owned[pick] == true)
		-- the picked class: what it is, its two skills, and the one thing to do with it
		local blurb = Poster.text(page, "label", 18, "ink.900", {
			Position = UDim2.fromOffset(28, 374 - PAGE_TOP),
			Size = UDim2.fromOffset(540, 27),
			Text = kit.blurb,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		blurb.FontFace = Font.new(Tokens.family.text, Enum.FontWeight.SemiBold)
		local device = deviceOf()
		local y = 400 - PAGE_TOP
		for _, slot in { "mobility", "attack" } do
			local skill = kit[slot]
			local key = if device == "touch"
				then nil
				elseif device == "gamepad" then (if slot == "mobility" then "B" else "L2")
				elseif slot == "mobility" then "Q"
				else "R"
			local cooldown = cooldownOf(skill.id)
			-- BOTH skills say what they do (until 2026-11-18 only the first did, to save room: the owner's review
			-- found the two rows unlike each other). A line of the small text holds about 54 letters at this
			-- width; a longer one takes a second line. Two two-line rows end exactly at the page's foot (400 + 88 + 4 + 88),
			-- so nothing scrolls: the rows start 17 higher and stand 4 apart to make that room.
			-- (PLACEHOLDER text for now, the owner, 2026-11-18: the moves are not final, so their real
			-- descriptions, still in Config/Abilities as each skill's `blurb`, are not shown here yet)
			local detail = if SKILL_DETAIL_PLACEHOLDER ~= ""
				then SKILL_DETAIL_PLACEHOLDER
				else skill.blurb
			local height = if not detail or detail == "" then 46 elseif #detail > 57 then 88 else 68
			local row = PosterKit.row(
				page,
				546,
				height,
				key,
				skill.name,
				detail,
				if not skill.built then "PLANNED" elseif cooldown then seconds(cooldown) else nil
			)
			PosterKit.placeRow(row, 22, y)
			y += height + 4
		end
		local state = standing(pick, wearing, owned)
		local x, top = 586, 474 - PAGE_TOP
		if state == "EQUIPPED" and not inRound() and pick ~= book.DefaultKit then
			wornAction(page, x, top)
		elseif state == "EQUIPPED" then
			action(page, x, top, "Equipped", "off")
		elseif state == "NOT OWNED" then
			action(page, x, top, "See it in the Shop", "buy", function()
				open("shop")
			end, nil, 40)
		elseif inRound() then
			action(page, x, top, "Locked in a round", "off")
		else
			action(page, x, top, "Equip", "go", function()
				askedEquip = os.clock()
				ability:Equip(pick)
			end, nil, 40)
		end
	end

	-- A planned thing: a plain outlined slab that says so (the mockup's dashed one; Roblox draws no dashes).
	local function plannedSlab(
		x: number,
		y: number,
		width: number,
		name: string,
		words_: string
	): Frame
		local slab = make("Frame", page, {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(width, 181),
		})
		local ring = make("Frame", slab, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
		})
		make("UIStroke", ring, { Color = colour("ink.900"), Thickness = 4 })
		Poster.text(slab, "display", 30, "ink.900", {
			Position = UDim2.fromOffset(22, 20),
			Size = UDim2.new(1, -44, 0, 45),
			Text = string.upper(name),
		})
		local line = Poster.text(slab, "label", 16, "ink.900", {
			Position = UDim2.fromOffset(22, 69),
			Size = UDim2.new(1, -44, 0, 48),
			Text = words_,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		line.FontFace = Font.new(Tokens.family.text, Enum.FontWeight.SemiBold)
		PosterKit.tag(slab, "Planned", { Position = UDim2.new(0, 22, 1, -46) })
		return slab
	end

	local function drawShop(fresh: boolean)
		tint(colour(TONES.shop))
		setWord("Shop")
		setTitle("Shop")
		sub.Text = "CLASSES · PAY WITH COINS"
		local owned = ability:GetOwned()
		local coins = ability:GetCoins()
		local x, y, rowHeight, count = 40, 128 - PAGE_TOP, 0, 0
		local function place(width: number, height: number): (number, number)
			if x > 40 and x + width > 40 + 796 then
				x = 40
				y += rowHeight + 14
				rowHeight = 0
			end
			local atX, atY = x, y
			x += width + 14
			rowHeight = math.max(rowHeight, height)
			return atX, atY
		end
		for _, id in classOrder() do
			local kit = book.Kits[id]
			if not owned[id] then
				count += 1
				local sure = confirming == id
				local height = if sure then 181 + 56 else 181
				local atX, atY = place(286, height)
				local cut = PosterKit.cut(
					page,
					"slab",
					Vector2.new(286, height),
					classColour(id),
					Vector2.new(5, 6)
				)
				PosterKit.place(cut, atX, atY)
				className(cut.face, kit.name, 30, 18, 16, 45)
				local line = Poster.text(cut.face, "label", 16, "ink.900", {
					Position = UDim2.fromOffset(18, 65),
					Size = UDim2.fromOffset(250, 24),
					Text = `{kit.mobility.name} · {kit.attack.name}`,
				})
				line.FontFace = Font.new(Tokens.family.text, Enum.FontWeight.SemiBold)
				if inRound() then
					action(cut.face, 18, 99, "Locked in a round", "off")
				elseif coins < kit.price then
					action(cut.face, 18, 99, `Need {kit.price - coins} more`, "off")
				elseif sure then
					-- the second press spends the Coins
					action(cut.face, 18, 99, `Confirm · {kit.price}`, "sure", function()
						confirming = nil
						askedBuy = os.clock()
						ability:Buy(id)
					end, nil, count * 2)
					action(cut.face, 18, 99 + 66 + 8, "Cancel", "plain", function()
						confirming = nil
						draw(false)
					end, 48, count * 2 + 1)
				else
					action(cut.face, 18, 99, `Buy · {kit.price}`, "buy", function()
						confirming = id
						draw(false)
					end, nil, count * 2)
				end
				if fresh then
					PosterKit.pop(cut.root, cut.scale, 0.12 + (count - 1) * 0.04)
				end
			end
		end
		if count == 0 then
			local atX, atY = place(286, 120)
			local cut = PosterKit.cut(
				page,
				"slab",
				Vector2.new(286, 120),
				colour("ivory.50"),
				Vector2.new(5, 6)
			)
			PosterKit.place(cut, atX, atY)
			Poster.text(cut.face, "display", 30, "ink.900", {
				Position = UDim2.fromOffset(18, 16),
				Size = UDim2.fromOffset(250, 45),
				Text = "ALL OWNED",
			})
			local line = Poster.text(cut.face, "label", 16, "ink.900", {
				Position = UDim2.fromOffset(18, 65),
				Size = UDim2.fromOffset(250, 24),
				Text = "You own every class.",
			})
			line.FontFace = Font.new(Tokens.family.text, Enum.FontWeight.SemiBold)
		end
		for _, name in { "Passes", "Cosmetics" } do
			local atX, atY = place(294, 181)
			plannedSlab(atX, atY, 294, name, "Planned. Not in the game yet.")
		end
		page.CanvasSize = UDim2.fromOffset(0, y + rowHeight + 24)
	end

	local function drawRanked()
		tint(colour(TONES.ranked))
		setWord("Ranked")
		setTitle("Ranked")
		sub.Text = "PLANNED · NOT IN THE GAME YET"
		-- the mockup's one cream slab (420 wide inside 18 of padding), not a dashed "planned" one
		local cut = PosterKit.cut(
			page,
			"slab",
			Vector2.new(456, 166),
			colour("ivory.50"),
			Vector2.new(5, 6)
		)
		PosterKit.place(cut, 40, 128 - PAGE_TOP)
		Poster.text(cut.face, "display", 30, "ink.900", {
			Position = UDim2.fromOffset(18, 16),
			Size = UDim2.fromOffset(420, 45),
			Text = "COMING LATER",
		})
		local line = Poster.text(cut.face, "label", 16, "ink.900", {
			Position = UDim2.fromOffset(18, 65),
			Size = UDim2.fromOffset(420, 48),
			Text = "This screen is a placeholder. The game has no ranked system, so no ranks, seasons or rewards are shown.",
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		line.FontFace = Font.new(Tokens.family.text, Enum.FontWeight.SemiBold)
		PosterKit.tag(cut.face, "Planned", { Position = UDim2.fromOffset(18, 123) })
	end

	-- Rows in two columns (`.list`): each pair as tall as its taller row.
	type Item = {
		key: string?,
		name: string,
		detail: string?,
		right: string?,
		press: (() -> ())?,
	}
	local function drawList(items: { Item }, fresh: boolean)
		local y = 128 - PAGE_TOP
		for index = 1, #items, 2 do
			local height = 46
			for offset = 0, 1 do
				local item = items[index + offset]
				if item and item.detail and item.detail ~= "" then
					-- a line of the small text holds about 36 letters here; every line the detail needs gets its
					-- 26 units (with two heights only, Punch's three-line detail lost its last word; 2026-11-18)
					height = math.max(height, 46 + 26 * math.ceil(#item.detail / 36))
				end
			end
			for offset = 0, 1 do
				local item = items[index + offset]
				if item then
					local row = PosterKit.row(
						page,
						381,
						height,
						item.key,
						item.name,
						item.detail,
						item.right
					)
					PosterKit.placeRow(row, 40 + offset * 399, y)
					if item.press then
						PosterKit.pressRow(row, item.press)
						if not Drift.lite then
							Drift.add("page", row.body, height, 3, index + offset)
						end
					end
					if fresh then
						PosterKit.pop(row.root, row.scale, 0.12 + (index + offset - 1) * 0.04)
					end
				end
			end
			y += height + 8
		end
		page.CanvasSize = UDim2.fromOffset(0, y + 16)
	end

	local function drawMoves(fresh: boolean)
		tint(colour(TONES.moves))
		setWord("Moves")
		setTitle("Moves")
		local device = deviceOf()
		sub.Text = if device == "touch"
			then "CONTROLS ON TOUCH"
			elseif device == "gamepad" then "CONTROLS ON A GAMEPAD"
			else "CONTROLS ON KEYBOARD AND MOUSE"
		local items: { Item } = {}
		for _, move in (HudTheme.Guide :: any)[device] or {} do
			local name, detail = splitMove(move.action)
			table.insert(items, { key = move.key, name = name, detail = detail })
		end
		table.insert(items, 5, {
			key = if device == "gamepad" then "Up" elseif device == "touch" then "Ult" else "G",
			name = "Ultimate",
			detail = "When ULT READY shows, land a hit, then press it.",
		})
		drawList(items, fresh)
	end

	-- MORE is a lobby page: Settings, Spectate and AFK have their own buttons on the right edge (NavController),
	-- so it lists only what is planned. In a round there is no More page; MENU opens Settings.
	local function drawMore(fresh: boolean)
		tint(colour(TONES.more))
		setWord("More")
		setTitle("More")
		sub.Text = "COMING LATER"
		local items: { Item } = {}
		for _, name in PLANNED do
			table.insert(items, { name = name, right = "PLANNED" })
		end
		drawList(items, fresh)
	end

	-- SETTINGS: on purpose the PLAIN page (the owner, 2026-11-18: "similar style but looks different ... more
	-- bland, and the toggles should be more readable"). The window goes a pale grey with no repeated word behind
	-- it, and each setting is one flat cream row that reads left to right: its name, a "?" that shows what it
	-- does while the pointer is on it (a tap shows it for a few seconds), and a real switch at the right, told by
	-- its word (ON / OFF), its colour and where its knob stands. Nothing here tilts or drifts.
	local function settingRow(setting: { id: string, name: string, help: string }, y: number)
		local ink = colour("ink.900")
		local row = make("Frame", page, {
			Name = "Setting_" .. setting.id,
			BackgroundColor3 = colour("ivory.50"),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(SROW.X, y),
			Size = UDim2.fromOffset(SROW.Width, SROW.Height),
		})
		make("UICorner", row, { CornerRadius = UDim.new(0, 8) })
		make("UIStroke", row, { Color = ink, Thickness = 3 })
		local press = make("TextButton", row, {
			Name = "Press",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			AutoButtonColor = false,
			ZIndex = 1,
		})
		local left = make("Frame", row, {
			Name = "Left",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(18, 0),
			Size = UDim2.new(1, -18 - SROW.Switch.X - 28, 1, 0),
			ZIndex = 2,
		})
		make("UIListLayout", left, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		})
		Poster.text(left, "label", 20, "ink.900", {
			Name = "Name",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, SROW.Height),
			Text = setting.name,
			LayoutOrder = 1,
			ZIndex = 2,
		})
		local help = make("TextButton", left, {
			Name = "Help",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(26, 26),
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = 2,
			ZIndex = 3,
		})
		make("UICorner", help, { CornerRadius = UDim.new(0.5, 0) })
		Poster.text(help, "label", 16, "ivory.50", {
			Size = UDim2.fromScale(1, 1),
			Text = "?",
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		})
		local tip = Poster.text(left, "label", 15, "ivory.50", {
			Name = "Tip",
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = ink,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 32),
			Text = setting.help,
			Visible = false,
			LayoutOrder = 3,
			ZIndex = 3,
		})
		make("UICorner", tip, { CornerRadius = UDim.new(0, 6) })
		make("UIPadding", tip, { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })

		-- the switch: green with ON and the knob at the right, grey with OFF and the knob at the left
		local size = SROW.Switch
		local switch = make("Frame", row, {
			Name = "Switch",
			AnchorPoint = Vector2.new(1, 0.5),
			BorderSizePixel = 0,
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(size.X, size.Y),
			ZIndex = 2,
		})
		make("UICorner", switch, { CornerRadius = UDim.new(0.5, 0) })
		make("UIStroke", switch, { Color = ink, Thickness = 3 })
		local word = Poster.text(
			switch,
			"label",
			15,
			"ink.900",
			{ Size = UDim2.fromScale(1, 1), ZIndex = 2 }
		)
		make("UIPadding", word, { PaddingLeft = UDim.new(0, 13), PaddingRight = UDim.new(0, 11) })
		local knob = make("Frame", switch, {
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = colour("ivory.50"),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(SROW.Knob, SROW.Knob),
			ZIndex = 3,
		})
		make("UICorner", knob, { CornerRadius = UDim.new(0.5, 0) })
		make("UIStroke", knob, { Color = ink, Thickness = 3 })
		local knobX = size.Y / 2
		local function paint(animate: boolean)
			local on = settingsState[setting.id] == true
			switch.BackgroundColor3 = colour(if on then "go.400" else "stone.300")
			word.Text = if on then "ON" else "OFF"
			word.TextXAlignment = if on then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
			local from, to = knobX, if on then size.X - size.Y / 2 else size.Y / 2
			Poster.run(knob, if animate then 0.18 else 0, function(t: number)
				knobX = from + (to - from) * PosterEase.easeOut(t)
				knob.Position = UDim2.new(0, knobX, 0.5, 0)
			end)
		end
		paint(false)

		press.MouseEnter:Connect(function()
			UiSound.hover()
			row.BackgroundColor3 = Color3.new(1, 1, 1)
		end)
		press.MouseLeave:Connect(function()
			row.BackgroundColor3 = colour("ivory.50")
		end)
		press.MouseButton1Down:Connect(function()
			UiSound.play("ui_press")
		end)
		press.Activated:Connect(function()
			settingsState[setting.id] = not settingsState[setting.id]
			paint(true)
			MenuController.SettingChanged:Fire(setting.id, settingsState[setting.id])
		end)
		-- the "?": what the setting does, while the pointer is on it; a tap shows it for a few seconds
		local shownAt = 0
		local function showTip(on: boolean)
			tip.Visible = on
			if on then
				shownAt = os.clock()
			end
		end
		help.MouseEnter:Connect(function()
			UiSound.hover()
			showTip(true)
		end)
		help.Activated:Connect(function()
			showTip(true)
		end)
		help.MouseLeave:Connect(function()
			if UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then
				showTip(false)
				return
			end
			local mine = os.clock()
			shownAt = mine
			task.delay(SROW.TipHold, function()
				if tip.Parent and shownAt == mine then
					tip.Visible = false
				end
			end)
		end)
	end

	local function drawSettings(_fresh: boolean)
		tint(colour("ivory.50"):Lerp(colour("stone.300"), 0.45))
		setWord("") -- no repeated word behind this page
		setTitle("Settings")
		sub.Text = "FIGHTER ROW WORKS  ·  THE OTHER THREE DON'T CHANGE ANYTHING YET"
		local y = 128 - PAGE_TOP
		for _, setting in SETTINGS do
			settingRow(setting, y)
			y += SROW.Height + SROW.Gap
		end
		-- whether your progress is being saved: one quiet line, not a row
		local saving = ability:IsReady() and not ability:IsTemporary()
		Poster.text(page, "label", 15, "ink.900", {
			Name = "Saving",
			Position = UDim2.fromOffset(SROW.X + 4, y + 2),
			Size = UDim2.fromOffset(SROW.Width, 22),
			Text = if not ability:IsReady()
				then "LOADING YOUR DATA  ·  One moment."
				elseif saving then "SAVED  ·  Your Coins and classes are saved."
				else "NOT SAVING  ·  Changes are lost when you leave this session.",
			TextTransparency = 0.25,
		})
		y += 34
		page.CanvasSize = UDim2.fromOffset(0, y + 16)
	end

	draw = function(fresh: boolean)
		local now = entry
		if not now then
			return
		end
		clear()
		if now ~= "classes" then
			preview.hide()
		end
		if now == "classes" then
			drawClasses(fresh)
		elseif now == "shop" then
			drawShop(fresh)
		elseif now == "ranked" then
			drawRanked()
		elseif now == "moves" then
			drawMoves(fresh)
		elseif now == "settings" then
			drawSettings(fresh)
		else
			drawMore(fresh)
		end
		if fresh then
			-- the title slams in: twice its size and turned 16 degrees, on the spring over 0.6 s
			Poster.run(titleBox, 0.6, function(t: number)
				local s = spring(t)
				titleScale.Scale = 2.1 + (1 - 2.1) * s
				titleBox.Rotation = -16 + (titleRest + 16) * s
			end)
		end
	end

	-- OPEN AND CLOSE -------------------------------------------------------------------------------------
	-- Where the window stands and how big: in the room that is left, so it never lies over anything (owner,
	-- 2026-11-17). Above it is the HUD's strip; left of it, in the lobby, the menu strips (the open one sits out
	-- to the right); under it, in a round, the skill tiles and the ULT READY badge over them, and in the lobby
	-- the spectating chip. It is `Fit.Window` of the mockup's size where that fits, and smaller where it doesn't.
	local away = SHEET.X * 1.12 -- how far right it starts and leaves, in its own units
	local function layout()
		local stage = PosterKit.stage()
		local fit = PosterKit.Fit
		local round = inRound()
		local strip = HudTheme.Strip
		local top = stage.top + strip.Top + strip.Tall * strip.Shrink * stage.hud + 8
		local below = if round and deviceOf() ~= "touch"
			then 24 + 190 * stage.hud + 8
			else 16 + 40 * stage.hud + 16
		local left = if round then 26 * stage.scale else NAV_RIGHT * stage.nav
		local right = 26 * stage.scale
		local roomX = stage.view.X - left - right
		local roomY = stage.view.Y - top - below
		setTall(if round then ROUND_TALL else SHEET.Y)
		setTilt(decor.Rotation) -- the X keeps its corner at the new height
		local want = math.clamp(stage.scale * fit.Window, fit.WindowMin, fit.WindowMax)
		-- (the 12 is the paper's hard shadow, which is part of what must fit)
		local scale =
			math.max(math.min(want, roomX / (SHEET.X + 12), roomY / (sheetTall + 12)), 0.3)
		holderScale.Scale = scale
		-- in the MIDDLE OF THE SCREEN (owner, 2026-11-17: centred in the room beside the strips it looked off
		-- centre), moved right only as far as the menu strips make it
		local wide = SHEET.X * scale
		local x =
			math.clamp((stage.view.X - wide) / 2, left, math.max(left, stage.view.X - right - wide))
		holder.Position = UDim2.fromOffset(x, top + math.max(0, roomY - sheetTall * scale) * 0.4)
		away = math.max(SHEET.X * 1.12, (stage.view.X - x) / scale + 60)
	end

	-- THE BLUR (owner, 2026-11-17): the world behind the open window goes a little soft, fading in over a quarter
	-- second and out a little faster, so it never snaps. Not in a round: you are still fighting and have to see
	-- it. Not at the two lowest graphics levels: a whole-screen effect is the first thing a weak phone can't
	-- afford. Under Reduced Motion it is set at once.
	local blur: BlurEffect? = nil
	local blurTween: Tween? = nil
	local function lowGraphics(): boolean
		local ok, level = pcall(function()
			return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
		end)
		return ok and level >= 1 and level <= 2
	end
	local function setBlur(on: boolean)
		local want = on and not inRound() and not lowGraphics()
		if want and not blur then
			blur = make("BlurEffect", Lighting, { Name = "HT_MenuBlur", Size = 0, Enabled = false })
		end
		local effect = blur
		if not effect then
			return
		end
		if blurTween then
			blurTween:Cancel()
			blurTween = nil
		end
		local goal = if want then BLUR.Size else 0
		if want then
			effect.Enabled = true
		elseif not effect.Enabled then
			return
		end
		if HudMotion.reduced() then
			effect.Size = goal
			effect.Enabled = want
			return
		end
		local tween = TweenService:Create(
			effect,
			TweenInfo.new(
				if want then BLUR.In else BLUR.Out,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{ Size = goal }
		)
		blurTween = tween
		tween.Completed:Connect(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and not want then
				effect.Enabled = false
			end
		end)
		tween:Play()
	end

	local function onCloseKey(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			close()
		end
		return Enum.ContextActionResult.Sink -- every state, so the release never reaches the dash
	end

	open = function(to: string)
		if inRound() and to == "more" then
			to = "settings"
		end
		if inRound() and not IN_ROUND_OK[to] then
			return
		end
		local was = entry
		entry = to
		lastEntry = to
		confirming = nil
		layout()
		if not was then
			UiSound.play("ui_open")
			holder.Visible = true
			driftSince = os.clock()
			ContextActionService:BindActionAtPriority(
				CLOSE_ACTION,
				onCloseKey,
				false,
				Enum.ContextActionPriority.High.Value + 1,
				Enum.KeyCode.ButtonB
			)
			-- it comes in from the right, tipped 3 degrees, over 0.7 s. Its TURN settles on the spring; its PLACE
			-- on a curve that only just passes home. (Both were on the spring, which overshoots by a sixth: over
			-- this long a run that carried the window about 170 units too far left, across the menu strips, for
			-- a moment; caught in a capture, 2026-11-18. Callouts learned the same thing for its glide.)
			Poster.run(slide, 0.7, function(t: number)
				local s = spring(t)
				slide.Position = UDim2.new(0.5, away * (1 - slideIn(t)), 0.5, 0)
				setTilt(3 + (TILT - 3) * s)
			end)
		elseif was ~= to then
			UiSound.play("ui_page")
			hit()
		end
		draw(true)
		setDrift(true)
		Drift.show("window", true)
		Drift.show("page", true)
		setBlur(true)
		MenuController.Changed:Fire(to)
	end

	close = function()
		if not entry then
			return
		end
		entry = nil
		confirming = nil
		preview.hide()
		UiSound.play("ui_close")
		ContextActionService:UnbindAction(CLOSE_ACTION)
		setDrift(false)
		Drift.show("window", false)
		Drift.show("page", false)
		setBlur(false)
		MenuController.Changed:Fire(nil)
		local function gone()
			if not entry then
				holder.Visible = false
				clear()
			end
		end
		if HudMotion.reduced() then
			gone()
			return
		end
		-- it leaves the way it came, quickly (0.12 s)
		Poster.run(slide, 0.12, function(t: number)
			local e = PosterEase.easeIn(t)
			slide.Position = UDim2.new(0.5, away * e, 0.5, 0)
			setTilt(TILT + (3 - TILT) * e)
		end, gone)
	end

	-- the X: pink, 12 in from the top-right corner. 62 x 62 (the mockup's is 54): the window is drawn smaller
	-- than the mockup's, and this has to stay easy to hit
	local closeCut = PosterKit.cut(slide, "close", Vector2.new(62, 62), colour("danger.600"))
	PosterKit.place(closeCut, SHEET.X - BORDER - 12 - 62, BORDER + 12)
	closeCut.root.ZIndex = 7
	-- It keeps its place by the paper's top-right corner while the paper leans (it stays upright itself: small
	-- lettering is never turned). Standing still while the paper kicked to 4 degrees, its corner stuck out past
	-- the border (seen with the kick frozen, 2026-11-18).
	do
		local restAt = Vector2.new(closeCut.root.Position.X.Offset, closeCut.root.Position.Y.Offset)
		table.insert(tiltFollowers, function(degrees: number)
			local centre = Vector2.new(SHEET.X / 2, sheetTall / 2)
			local from = restAt - centre
			local angle = math.rad(degrees)
			closeCut.root.Position = UDim2.fromOffset(
				centre.X + from.X * math.cos(angle) - from.Y * math.sin(angle),
				centre.Y + from.X * math.sin(angle) + from.Y * math.cos(angle)
			)
		end)
		setTilt(TILT)
	end
	Poster.text(closeCut.face, "display", 28, "ivory.50", {
		Size = UDim2.fromScale(1, 1),
		Text = "X",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	PosterKit.pressable(closeCut, function()
		close()
	end)
	Drift.add("window", closeCut.body, 62, 5) -- up and down only: the X is a letter

	MenuController._open = open
	MenuController._close = close
	MenuController._entry = function(): string?
		return entry
	end
	MenuController._toast = showToast

	ContextActionService:BindAction(TOGGLE_ACTION, function(_: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			if entry then
				close()
			else
				open(if inRound() then "more" else lastEntry)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)

	local function redraw()
		if entry then
			if inRound() and not IN_ROUND_OK[entry] then
				close()
			else
				draw(false)
			end
		end
	end
	local function ownedCount(): number
		local count = 0
		for _ in ability:GetOwned() do
			count += 1
		end
		return count
	end
	local ownedBefore = ownedCount()
	ability.InventoryChanged:Connect(function()
		-- bought: the owned list grew after a Confirm, never on the first Buy press or as the profile loads
		local count = ownedCount()
		if count > ownedBefore and os.clock() - askedBuy < ASKED_FOR then
			askedBuy = -math.huge
			UiSound.play("ui_buy")
		end
		ownedBefore = count
		redraw()
	end)
	ability.KitChanged:Connect(function()
		if os.clock() - askedEquip < ASKED_FOR then
			askedEquip = -math.huge
			UiSound.play("ui_equip")
		end
		-- a class just equipped is the one the window shows. When that CHANGES what the Classes page shows
		-- (unequipping drops you back to the starting class), the page changes the way it does when you pick a
		-- tile: the band sweeps across and the paper kicks. It used to snap (the owner, 2026-11-18).
		local now = ability:GetKitId()
		local moved = now ~= pick
		pick = now
		if moved and entry == "classes" then
			hit()
		end
		redraw()
	end)
	player:GetAttributeChangedSignal("HT_AFK"):Connect(redraw)
	player:GetAttributeChangedSignal("HT_InRound"):Connect(function()
		-- a round starting or ending moves what the window has to stand clear of, and a fight is never blurred
		layout()
		redraw()
		setBlur(entry ~= nil)
	end)
	UserInputService.LastInputTypeChanged:Connect(layout)
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
		layout()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
	tint(fieldColour)
	local playerGui = player:WaitForChild("PlayerGui")
	gui.Parent = playerGui
	toastGui.Parent = playerGui
end

--- Opens or closes the window (on the page it last showed).
function MenuController:SetOpen(open: boolean)
	if open and self._open then
		self._open("classes")
	elseif not open and self._close then
		self._close()
	end
end

--- Opens the window on a page: "classes", "shop", "ranked", "moves", "more" or "settings". The old window's
--- names ("Shop", "Abilities", "Cosmetics") still work.
function MenuController:Open(tab: string)
	local entry = OLD_NAMES[tab] or tab
	if self._open and (entry == "classes" or TITLES[entry]) then
		self._open(entry)
	end
end

--- Closes the window.
function MenuController:Close()
	if self._close then
		self._close()
	end
end

--- Opens the Settings page.
function MenuController:OpenSettings()
	if self._open then
		self._open("settings")
	end
end

--- Whether a Settings switch is on (nil before the menu has started, or for a switch that does not exist).
--- Nothing here is saved: every switch is back on in a new session.
function MenuController:GetSetting(id: string): boolean?
	local state = self._settings
	return if state then state[id] else nil
end

--- The page that is open, or nil.
function MenuController:GetEntry(): string?
	return if self._entry then self._entry() else nil
end

--- Shows a line in the toast (top-left corner).
function MenuController:Toast(message: string)
	if self._toast then
		self._toast(message)
	end
end

return MenuController
