--!strict
-- HudController - the combat HUD. During a fight: a top strip (round state and survivors), your
-- stagger along the bottom centre with speed under it, and the three combat actions (Punch, Propel,
-- Air Kick) as one compact group in the bottom-right corner, each with its icon, name, binding,
-- cooldown and ready state. A small help chip above them opens the full controls guide. The middle of
-- the screen stays clear. Around them, only when needed: an arena-closing chip under the strip, one
-- ring-out line top right, a target chip over the one opponent that matters, and a spectating chip.
--
-- It only draws. Every number comes from where the game keeps it: MovementController.Hud (real speed,
-- propel cooldown, kick timing), CombatController (punch timing and results), the character's
-- HT_Stagger, and the round's HT_RoundState folder. The rules for what to show are in Core/HudLogic;
-- sizes, colours and timings in Ui/HudTheme; the type family and text roles in Shared/Typography.
-- No combat input is bound here: the rows mirror the real controls, and on touch the real
-- ContextActionService buttons stay the only buttons, with the cooldown drawn on them.
--
-- ROUND CONTRACT, for the round service to fill (nothing in the game sets it yet; see
-- HudPreviewService for a Studio-only stand-in): a Folder ReplicatedStorage.HT_RoundState with
-- attributes Phase ("Intermission" | "Starting" | "Fighting" | "RoundOver"), Round, Alive, Total,
-- CountdownEnd (workspace:GetServerTimeNow() seconds), ShrinkActive (bool), ShrinkSeq (int, +1 each
-- time a shrink begins); a RemoteEvent in it named RingOut, fired to all with (victimName,
-- attackerName?, cause "knocked" | "fell" | "left"); and the player attribute HT_Eliminated.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local HudLogic = require(ReplicatedStorage.Shared.Core.HudLogic)
local Typography = require(ReplicatedStorage.Shared.Typography)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)

local C, S, T = HudTheme.Colour, HudTheme.Size, HudTheme.Time
local moveCfg = GameConfig.Movement
local kickCfg = GameConfig.Kick
local STAGGER_MAX = GameConfig.Stagger.Max
local HOT_SHARE = 0.7 -- stagger past this share of the max shows in the hot colour
local COMBATANT_TAG = "HT_Combatant"
local ROUND_FOLDER = "HT_RoundState"
local HELP_ACTION = "HaymakerHelp"
local GUIDE_ROWS = 6

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

-- BUILDING ------------------------------------------------------------------------------------------

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

-- A text label in a role from Typography: the role sets family, weight and size.
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

-- A thin dark edge round light text, so it reads over the sky, the floor or anything else without a panel.
local function outline(label: TextLabel | TextButton): TextLabel | TextButton
	make("UIStroke", label, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = C.Panel,
		Thickness = 1.5,
		Transparency = HudTheme.Transparency.Outline,
	})
	return label
end

-- A panel body with its bottom-right corner cut on the angle, and the yellow edge on the left. The cut
-- is a square with a hard-stepped gradient, so it costs no image.
local function body(parent: Instance, accent: boolean)
	local notch = S.Notch
	local holder = make("Frame", parent, {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	local function piece(size: UDim2, position: UDim2): Frame
		return make("Frame", holder, {
			BackgroundColor3 = C.Panel,
			BackgroundTransparency = HudTheme.Transparency.Panel,
			BorderSizePixel = 0,
			Size = size,
			Position = position,
		})
	end
	piece(UDim2.new(1, 0, 1, -notch), UDim2.new())
	piece(UDim2.new(1, -notch, 0, notch), UDim2.new(0, 0, 1, -notch))
	local corner = piece(UDim2.fromOffset(notch, notch), UDim2.new(1, -notch, 1, -notch))
	make("UIGradient", corner, {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	if accent then
		make("Frame", holder, {
			Name = "Accent",
			BackgroundColor3 = C.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, S.AccentBar, 1, -notch),
		})
	end
end

-- A group: a holder sized and placed by layout, with a CanvasGroup inside that fades and rises.
type Group = { holder: Frame, fade: CanvasGroup, scale: UIScale, wanted: boolean }

local function group(parent: Instance, name: string, width: number, height: number): Group
	local holder = make("Frame", parent, {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height),
	})
	local scale = make("UIScale", holder, {})
	local fade = make("CanvasGroup", holder, {
		Name = "Fade",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height),
		GroupTransparency = 1,
		Visible = false,
	})
	return { holder = holder, fade = fade, scale = scale, wanted = false }
end

-- The action's icon: drawn art uploaded as an image (design/ui/draw_icons.py), tinted for state, with
-- a slash for unavailable. The image keeps its own colours; ImageColor3 only greys it out.
local function icon(parent: Instance, id: string, at: UDim2): ImageLabel
	local image = make("ImageLabel", parent, {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24),
		Position = at,
		AnchorPoint = Vector2.new(0, 0.5),
		Image = HudTheme.Icons[id] or "",
		ScaleType = Enum.ScaleType.Fit,
	})
	make("Frame", image, {
		Name = "Slash",
		BackgroundColor3 = C.Muted,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 3), -- short, so most of the icon still shows
		Rotation = -45,
		Visible = false,
		ZIndex = 3,
	})
	return image
end

-- The mouse for the punch binding: the same drawn style, in the HUD's colours. 24 px so the drawn
-- mouse (about 3/4 of its image) reads at about 18 px inside the 22 px cap.
local function mouseGlyph(parent: Instance): ImageLabel
	return make("ImageLabel", parent, {
		Name = "Mouse",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Image = HudTheme.Icons.mouse,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	})
end

-- One action row: icon, name, key cap, a reserved status slot, and a thin cooldown line under it.
type Row = {
	id: string,
	frame: Frame,
	icon: ImageLabel,
	iconScale: UIScale,
	name: TextLabel,
	cap: Frame,
	capText: TextLabel,
	mouse: ImageLabel,
	capScale: UIScale,
	status: TextLabel,
	line: Frame,
	fill: Frame,
	state: string,
	statusText: string,
	wordUntil: number,
}

local function makeRow(parent: Instance, action: any, index: number): Row
	local frame = make("Frame", parent, {
		Name = action.id,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, S.ActionPad + (index - 1) * S.ActionRow),
		Size = UDim2.new(1, 0, 0, S.ActionRow),
	})
	local shape = icon(frame, action.id, UDim2.new(0, S.ActionIconX, 0.5, -1))
	local iconScale = make("UIScale", shape, {})
	local name = text(frame, "Action", {
		Position = UDim2.fromOffset(S.ActionNameX, 0),
		Size = UDim2.new(0, S.ActionNameWidth, 1, -2),
		Text = action.name,
	})
	outline(name)
	local cap = make("Frame", frame, {
		Name = "Cap",
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = HudTheme.Transparency.CapTag,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, S.ActionKeyX, 0.5, -1),
		Size = UDim2.fromOffset(S.ActionKeyWidth, 22),
	})
	make("UICorner", cap, { CornerRadius = UDim.new(0, 4) })
	local capScale = make("UIScale", cap, {})
	local capText = text(cap, "Key", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Text,
	})
	outline(capText)
	local mouse = mouseGlyph(cap)
	local status = text(frame, "Value", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, S.ActionStatusWidth, 1, -2),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Muted,
		Text = "",
	})
	outline(status)
	local line = make("Frame", frame, {
		Name = "Line",
		BackgroundColor3 = C.Track,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, S.ActionNameX, 1, -S.ActionLine),
		Size = UDim2.new(1, -(S.ActionNameX + 12), 0, S.ActionLine),
	})
	local fill = make("Frame", line, {
		BackgroundColor3 = C.Muted,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	})
	return {
		id = action.id,
		frame = frame,
		icon = shape,
		iconScale = iconScale,
		name = name,
		cap = cap,
		capText = capText,
		mouse = mouse,
		capScale = capScale,
		status = status,
		line = line,
		fill = fill,
		state = "",
		statusText = "",
		wordUntil = 0,
	}
end

-- A row's look for a state, with shape and words as well as colour:
--   ready: bright name, the icon in full colour, no line;
--   recovering: grey name, the icon greyed, a line filling toward ready, the seconds left;
--   unavailable: dim name, the icon faded with a slash through it, a dash.
-- Coming back to ready, the icon pops back to full colour once.
local function paintRow(row: Row, state: string)
	if row.state == state then
		return
	end
	local was = row.state
	row.state = state
	local ready = state == "ready"
	local dim = state == "unavailable"
	local tint = if ready then Color3.new(1, 1, 1) elseif dim then C.Dim else C.Muted
	local fade = if dim then 0.45 elseif ready then 0 else 0.2
	if ready and was == "recovering" then
		HudMotion.to(
			row.icon,
			"ready",
			{ ImageColor3 = tint, ImageTransparency = fade },
			T.ReadyFlash
		)
		HudMotion.pop(row.iconScale, 1.15, T.ReadyFlash)
	else
		HudMotion.to(row.icon, "ready", { ImageColor3 = tint, ImageTransparency = fade }, 0)
	end
	local slash = row.icon:FindFirstChild("Slash") :: Frame?
	if slash then
		slash.Visible = dim
	end
	row.name.TextColor3 = if ready then C.Text elseif dim then C.Dim else C.Muted
	row.capText.TextColor3 = if dim then C.Dim else C.Text
	row.line.BackgroundTransparency = if state == "recovering" then 0 else 1
	row.fill.Visible = state == "recovering"
end

-- THE CONTROLLER -----------------------------------------------------------------------------------

function HudController:KnitStart()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local movement = Knit.GetController("MovementController")
	local combat = Knit.GetController("CombatController")
	local lockOn = Knit.GetController("LockOnController")
	local kickPrompt = Knit.GetController("KickPromptController")
	local hud = movement.Hud

	-- Every game-owned label on screen uses the one family, including any made later.
	Typography.adopt(playerGui)

	local gui = make("ScreenGui", nil, {
		Name = "HT_Hud",
		ResetOnSpawn = false,
		DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	gui.Parent = playerGui

	-- Top strip --------------------------------------------------------------------------------------
	local strip = group(gui, "Strip", S.StripWidth, S.StripHeight + S.ShrinkHeight + 6)
	strip.holder.AnchorPoint = Vector2.new(0.5, 0)
	strip.fade.Size = UDim2.fromOffset(S.StripWidth, S.StripHeight)
	body(strip.fade, true)
	local roundLabel = text(strip.fade, "Label", {
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.fromOffset(120, 16),
		TextColor3 = C.Accent,
		Text = "",
	})
	local stripTitle = text(strip.fade, "Announce", {
		Position = UDim2.fromOffset(12, 23),
		Size = UDim2.fromOffset(160, 24),
		Text = "",
	})
	local titleScale = make("UIScale", stripTitle, {})
	local stripCount = text(strip.fade, "Stat", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.fromOffset(60, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})
	local countScale = make("UIScale", stripCount, {})
	local stripTotal = text(strip.fade, "StatSmall", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, -42, 0.5, 4),
		Size = UDim2.fromOffset(36, 22),
		TextColor3 = C.Muted,
		Text = "",
	})
	local shrinkChip = make("Frame", strip.holder, {
		Name = "Shrink",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, S.StripHeight + 4),
		Size = UDim2.fromOffset(S.ShrinkWidth, S.ShrinkHeight),
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Visible = false,
	})
	local shrinkScale = make("UIScale", shrinkChip, {})
	text(shrinkChip, "Action", {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = C.OnAccent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "ARENA CLOSING",
	})

	-- Bottom centre: stagger, then speed -------------------------------------------------------------
	local vitals = group(gui, "Vitals", S.VitalsWidth, S.VitalsHeight)
	vitals.holder.AnchorPoint = Vector2.new(0.5, 1)
	body(vitals.fade, true)
	local barLeft = 14
	text(vitals.fade, "Label", {
		Position = UDim2.fromOffset(barLeft, 6),
		Size = UDim2.fromOffset(80, 16),
		TextColor3 = C.Muted,
		Text = "STAGGER",
	})
	local staggerTrack = make("Frame", vitals.fade, {
		BackgroundColor3 = C.Track,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(barLeft, 30),
		Size = UDim2.fromOffset(S.StaggerBarWidth, S.StaggerBar),
	})
	local staggerFill = make("Frame", staggerTrack, {
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	})
	local staggerNumber = text(vitals.fade, "Stat", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 6),
		Size = UDim2.fromOffset(92, 44),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "<unbound>", -- the sentinel: setStagger writes it at once, so seeing it means a broken wire
	})
	local staggerScale = make("UIScale", staggerNumber, {})
	text(vitals.fade, "Label", {
		Position = UDim2.fromOffset(barLeft, 48),
		Size = UDim2.fromOffset(56, 16),
		TextColor3 = C.Muted,
		Text = "SPEED",
	})
	local speedDigits = text(vitals.fade, "Value", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(barLeft + 94, 48),
		Size = UDim2.fromOffset(30, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "<unbound>",
	})
	text(vitals.fade, "Label", {
		Position = UDim2.fromOffset(barLeft + 102, 48),
		Size = UDim2.fromOffset(36, 16),
		TextColor3 = C.Muted,
		Text = `/ {moveCfg.MaxSpeed}`,
	})
	local gaugeLeft = barLeft + S.StaggerBarWidth - S.GaugeOver - 8 - S.GaugeBase
	local gaugeBase = make("Frame", vitals.fade, {
		BackgroundColor3 = C.Track,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(gaugeLeft, 54),
		Size = UDim2.fromOffset(S.GaugeBase, S.GaugeHeight),
	})
	local gaugeFill = make("Frame", gaugeBase, {
		BackgroundColor3 = C.Text,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	})
	local gaugeOver = make("Frame", vitals.fade, {
		BackgroundColor3 = C.Track,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(gaugeLeft + S.GaugeBase + 8, 54),
		Size = UDim2.fromOffset(S.GaugeOver, S.GaugeHeight),
	})
	local gaugeOverFill = make("Frame", gaugeOver, {
		BackgroundColor3 = C.Over,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	})

	-- Bottom right: the three combat actions -----------------------------------------------------------
	local actionsHeight = S.ActionPad * 2 + S.ActionRow * #HudTheme.Actions
	local actions = group(gui, "Actions", S.ActionsWidth, actionsHeight)
	actions.holder.AnchorPoint = Vector2.new(1, 1)
	-- No panel: the controls are only a reminder, so they float as outlined text (user, 2026-11-09).
	local rows: { [string]: Row } = {}
	for index, action in HudTheme.Actions do
		rows[action.id] = makeRow(actions.fade, action, index)
	end

	-- The help chip, just above the actions, and the full guide it opens above itself.
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
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})
	Typography.apply(helpChip, "Key")
	outline(helpChip)
	make("UICorner", helpChip, { CornerRadius = UDim.new(0, 4) })
	local guide = make("Frame", help, {
		Name = "Guide",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -6),
		Size = UDim2.fromOffset(S.GuideWidth, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = HudTheme.Transparency.Panel,
		BorderSizePixel = 0,
		Visible = false,
	})
	make("UIPadding", guide, {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	})
	make("UIListLayout", guide, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})
	text(guide, "Button", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 24), Text = "Controls" })
	local guideRows: { { frame: Frame, key: TextLabel, info: TextLabel } } = {}
	for order = 1, GUIDE_ROWS do
		local row = make("Frame", guide, {
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, S.GuideRow),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		local key = text(row, "Key", {
			Size = UDim2.fromOffset(60, 22),
			BackgroundTransparency = 0,
			BackgroundColor3 = C.PanelRaised,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		make("UICorner", key, { CornerRadius = UDim.new(0, 4) })
		local info = text(row, "Body", {
			Position = UDim2.fromOffset(70, 0),
			Size = UDim2.new(1, -70, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		guideRows[order] = { frame = row, key = key, info = info }
	end

	-- Ring-out feed ----------------------------------------------------------------------------------
	local feed = group(gui, "Feed", S.FeedWidth, S.FeedHeight)
	feed.holder.AnchorPoint = Vector2.new(1, 0)
	body(feed.fade, true)
	local feedText = text(feed.fade, "Name", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -22, 1, -4),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- Spectating chip --------------------------------------------------------------------------------
	local spectate = group(gui, "Spectate", 180, 36)
	spectate.holder.AnchorPoint = Vector2.new(0.5, 1)
	body(spectate.fade, true)
	text(spectate.fade, "Announce", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "SPECTATING",
	})

	-- Target chip ------------------------------------------------------------------------------------
	local chip = make("BillboardGui", nil, {
		Name = "HT_TargetChip",
		Size = UDim2.fromOffset(S.ChipWidth, S.ChipHeight),
		StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0),
		AlwaysOnTop = true,
		MaxDistance = S.ChipMaxDistance,
		ResetOnSpawn = false,
		Enabled = false,
	})
	chip.Parent = playerGui
	local chipBack = make("Frame", chip, {
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = HudTheme.Transparency.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	})
	local chipName = text(chipBack, "Key", {
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.new(1, -60, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local chipNumber = text(chipBack, "StatSmall", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 1),
		Size = UDim2.fromOffset(50, 22),
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local chipTrack = make("Frame", chipBack, {
		BackgroundColor3 = C.Track,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 1, -5),
		Size = UDim2.new(1, -12, 0, 2),
	})
	local chipFill = make("Frame", chipTrack, {
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	})

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
		for _, g in { strip, feed, spectate } do
			g.scale.Scale = scale
		end
		local bottom = scale * HudTheme.Scale.Bottom
		vitals.scale.Scale = bottom
		actions.scale.Scale = bottom
		helpScale.Scale = bottom
		local edge = S.Edge
		strip.holder.Position = UDim2.new(0.5, 0, 0, S.StripTop)
		feed.holder.Position = UDim2.new(1, -edge, 0, S.StripTop)
		vitals.holder.Position = UDim2.new(0.5, 0, 1, -edge)
		spectate.holder.Position = UDim2.new(0.5, 0, 1, -edge)
		actions.holder.Position = UDim2.new(1, -edge, 1, -edge)
		if device == "touch" then
			-- Touch: the real buttons own the lower right, so the help chip sits under the feed.
			help.AnchorPoint = Vector2.new(1, 0)
			help.Position = UDim2.new(1, -edge, 0, S.StripTop + S.FeedHeight + 8)
			guide.AnchorPoint = Vector2.new(1, 0)
			guide.Position = UDim2.new(1, 0, 1, 6)
		else
			help.AnchorPoint = Vector2.new(1, 1)
			help.Position = UDim2.new(1, -edge, 1, -(edge + (actionsHeight + 6) * bottom))
			guide.AnchorPoint = Vector2.new(1, 1)
			guide.Position = UDim2.new(1, 0, 0, -6)
		end
	end

	-- STATE ------------------------------------------------------------------------------------------
	local roundFolder: Instance? = nil
	local promptActive = false
	local lastStrip: HudLogic.Strip? = nil
	local lastPhase: string? = nil
	local lastShrinkSeq = 0
	local character: Model? = nil
	local charConns: { RBXScriptConnection } = {}
	local stagger = 0
	local barFrom, barTo, barSince = 0, 0, -math.huge
	local shownDigits = 0
	local nextDigits = 0
	local gaugeShown, overShown = 0, 0
	local feedToken = 0
	local target: Model? = nil
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
		local stepped = promptActive and (g == vitals or g == actions)
		local goal = if stepped then HudTheme.Transparency.Stepped else 0
		if want and not g.wanted then
			g.wanted = true
			HudMotion.enter(g.fade, UDim2.new(), T.EnterTravel, T.Enter)
			if goal > 0 then
				HudMotion.to(g.fade, "fade", { GroupTransparency = goal }, T.Steps)
			end
		elseif not want and g.wanted then
			g.wanted = false
			HudMotion.leave(g.fade, T.Exit, function()
				return g.wanted
			end)
		elseif want then
			HudMotion.to(g.fade, "fade", { GroupTransparency = goal }, T.Steps)
		end
	end

	-- Which groups show: your stagger and actions while you're alive and fighting; nothing of yours
	-- once you're out or the round is over. Touch has its own buttons, so no action rows there.
	local function refreshGroups()
		local alive = character ~= nil and character.Parent ~= nil
		local round = readRound()
		local out = player:GetAttribute("HT_Eliminated") == true
		local over = round.phase == "RoundOver"
		local fighting = alive and not out and not over
		setGroup(vitals, fighting)
		setGroup(actions, fighting and device ~= "touch")
		setGroup(spectate, out and not over)
		help.Visible = fighting
		if not fighting then
			guide.Visible = false
		end
	end

	local function refreshStrip(fromEvent: boolean)
		local round = readRound()
		local now = workspace:GetServerTimeNow()
		local info = HudLogic.strip(round, now)
		setGroup(strip, info.visible)
		if not info.visible then
			lastStrip, lastPhase = info, round.phase
			shrinkChip.Visible = false
			return
		end
		roundLabel.Text = if round.round then `ROUND {string.format("%02d", round.round)}` else ""
		stripTitle.Text = info.title
		stripCount.Text = info.count or ""
		stripTotal.Text = if info.total then `/{info.total}` else ""
		local emphasis = fromEvent and HudLogic.emphasize(promptActive, HudMotion.reduced())
		local before = lastStrip
		-- Final two: one short emphasis when three became two in a fight, never when it started at two.
		if
			info.finalTwo
			and before
			and before.visible
			and not before.finalTwo
			and lastPhase == "Fighting"
			and round.phase == "Fighting"
		then
			stripTitle.TextColor3 = C.Accent
			if emphasis then
				HudMotion.pop(titleScale, T.EmphasisScale, T.Emphasis)
			end
			task.delay(1.5, function()
				HudMotion.to(stripTitle, "settle", { TextColor3 = C.Text }, 0.4)
			end)
		elseif not info.finalTwo then
			stripTitle.TextColor3 = C.Text
		end
		if
			before
			and before.visible
			and before.count ~= info.count
			and round.phase == "Fighting"
			and emphasis
		then
			HudMotion.pop(countScale, 1.15, 0.2)
		end
		lastStrip, lastPhase = info, round.phase
	end

	local function refreshShrink(fromEvent: boolean)
		local folder = roundFolder
		local active = folder ~= nil
			and folder:GetAttribute("ShrinkActive") == true
			and readRound().phase == "Fighting"
		local seq = if folder then (folder:GetAttribute("ShrinkSeq") or 0) :: number else 0
		shrinkChip.Visible = active
		if active and fromEvent and seq ~= lastShrinkSeq then
			if HudLogic.emphasize(promptActive, HudMotion.reduced()) then
				HudMotion.pop(shrinkScale, T.EmphasisScale + 0.1, T.Emphasis)
			end
		end
		lastShrinkSeq = seq
	end

	local function showFeed(line: string)
		feedToken += 1
		local mine = feedToken
		feedText.Text = line
		if not feed.wanted then
			setGroup(feed, true)
		end
		task.delay(T.Feed, function()
			if feedToken == mine then
				setGroup(feed, false)
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
							showFeed(HudLogic.feedLine(victim, attacker, cause or "fell"))
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

	-- Devices: bindings and the guide follow the last input used --------------------------------------
	local function refreshDevice()
		for _, action in HudTheme.Actions do
			local row = rows[action.id]
			local key = (action.keys :: any)[device] or ""
			local isMouse = key == "M1"
			row.capText.Text = if isMouse then "" else key
			row.mouse.Visible = isMouse
		end
		helpChip.Text = if device == "gamepad"
			then "?  Controls  SELECT"
			elseif device == "touch" then "?  Controls"
			else "?  Controls  H"
		local list = (HudTheme.Guide :: any)[device] or {}
		for order, row in guideRows do
			local item = list[order]
			row.frame.Visible = item ~= nil
			if item then
				row.key.Text = item.key
				row.info.Text = item.action
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
		staggerNumber.Text = `{math.floor(value + 0.5)}%`
		local hot = value >= STAGGER_MAX * HOT_SHARE
		local base = if hot then C.AccentHot else C.Text
		staggerFill.BackgroundColor3 = if hot then C.AccentHot else C.Accent
		-- The bar catches up from wherever it is now, so quick hits move toward the newest value.
		local share = value / STAGGER_MAX
		local now = os.clock()
		barFrom = HudLogic.catchUp(barFrom, barTo, now - barSince, T.StaggerCatchUp)
		barTo = share
		barSince = if animate and not HudMotion.reduced() then now else -math.huge
		if animate and HudLogic.staggerAccent(before, value, T.StaggerAccentGain) then
			staggerNumber.TextColor3 = C.Accent
			HudMotion.to(staggerNumber, "accent", { TextColor3 = base }, T.StaggerAccent)
			if not HudMotion.reduced() then
				HudMotion.pop(staggerScale, 1.08, T.StaggerAccent)
			end
		else
			HudMotion.to(staggerNumber, "accent", { TextColor3 = base }, 0)
		end
	end

	local function onCharacter(model: Model)
		for _, conn in charConns do
			conn:Disconnect()
		end
		table.clear(charConns)
		character = model
		-- Nothing from a previous life carries over.
		stagger, barFrom, barTo, barSince = 0, 0, 0, -math.huge
		shownDigits, gaugeShown, overShown = 0, 0, 0
		-- The digits are only redrawn when the speed changes, so a body that hasn't moved yet still
		-- needs its 0 written once.
		speedDigits.Text = "0"
		speedDigits.TextColor3 = C.Text
		setStagger((model:GetAttribute("HT_Stagger") or 0) :: number, false)
		table.insert(
			charConns,
			model:GetAttributeChangedSignal("HT_Stagger"):Connect(function()
				setStagger((model:GetAttribute("HT_Stagger") or 0) :: number, true)
			end)
		)
		-- The groups enter again for the new life, once.
		vitals.wanted, actions.wanted = false, false
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
	local function flashCap(row: Row)
		row.cap.BackgroundColor3 = C.Blocked
		HudMotion.to(row.cap, "blocked", { BackgroundColor3 = C.PanelRaised }, 0.18)
	end
	local function word(row: Row, say: string, colour: Color3)
		row.status.Text = say
		row.statusText = say
		row.status.TextColor3 = colour
		row.wordUntil = os.clock() + T.ResultWord
	end
	combat.PunchEvent:Connect(function(kind: string)
		local row = rows.punch
		if kind == "thrown" then
			HudMotion.press(row.capScale, T.PressScale, T.PressDown, T.PressUp)
		elseif kind == "blocked" then
			flashCap(row)
		elseif kind == "hit" then
			word(row, "HIT", C.Accent)
		elseif kind == "miss" or kind == "cancelled" then
			word(row, "MISS", C.Miss)
		end
	end)
	movement.Propelled:Connect(function()
		HudMotion.press(rows.propel.capScale, T.PressScale, T.PressDown, T.PressUp)
	end)
	movement.PropelBlocked:Connect(function()
		flashCap(rows.propel)
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
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Active = false,
				ZIndex = 5,
			})
			make("UICorner", cover, { CornerRadius = UDim.new(0.5, 0) })
			text(cover :: Frame, "Value", {
				Name = "Seconds",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -2),
				Size = UDim2.fromOffset(40, 15),
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 6,
			})
		end
		return cover, (cover :: Frame):FindFirstChild("Seconds") :: TextLabel?
	end

	-- THE LOOP: one connection, no tweens started here ---------------------------------------------
	local lastCountdown = ""
	RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		local model = character
		-- Priority: a timed kick cue or a clash steps the HUD back. Checked every frame, because the
		-- cue can start and end within one.
		local cueUp = kickPrompt:IsActive()
		local prompt = cueUp or (model ~= nil and model:GetAttribute("HT_Clash") ~= nil)
		if prompt ~= promptActive then
			promptActive = prompt
			refreshGroups()
		end

		if model then
			-- Stagger bar catch-up.
			local bar = HudLogic.catchUp(barFrom, barTo, now - barSince, T.StaggerCatchUp)
			staggerFill.Size = UDim2.fromScale(math.clamp(bar, 0, 1), 1)

			-- Momentum: the gauge follows smoothly; the digits hold steady and redraw at most DigitHz.
			local base, over = HudLogic.speedGauge(hud.speed, moveCfg.MaxSpeed, S.GaugeOverSpeed)
			local follow = math.min(T.GaugeRate * dt, 1)
			gaugeShown += (base - gaugeShown) * follow
			overShown += (over - overShown) * follow
			gaugeFill.Size = UDim2.fromScale(gaugeShown, 1)
			gaugeOverFill.Size = UDim2.fromScale(overShown, 1)
			if now >= nextDigits then
				nextDigits = now + 1 / T.DigitHz
				local digits = HudLogic.steadyDigits(shownDigits, hud.speed, T.DigitHysteresis)
				if digits ~= shownDigits then
					shownDigits = digits
					speedDigits.Text = tostring(digits)
					speedDigits.TextColor3 = if hud.speed > moveCfg.MaxSpeed + 1
						then C.Over
						else C.Text
				end
			end

			-- Each action from its own real timing.
			local blocked = model:GetAttribute("HT_Stunned") ~= nil
				or model:GetAttribute("HT_Air") == "hold"
				or model:GetAttribute("HT_Clash") ~= nil
			local punchReady, punchTotal, canPunch = combat:GetPunchTiming()
			local upperReady, upperTotal, canUpper = combat:GetUppercutTiming()
			local timings = {
				punch = { readyAt = punchReady, total = punchTotal, usable = canPunch },
				propel = {
					readyAt = now + hud.propelLeft,
					total = moveCfg.PropelCooldown,
					usable = not blocked,
				},
				-- Space: the air kick while there's someone to follow up (or one is under way), else the jump.
				kick = if hud.kickTarget or hud.kicking
					then { readyAt = hud.kickReadyAt, total = kickCfg.Cooldown, usable = true }
					else {
						readyAt = hud.jumpReadyAt,
						total = GameConfig.Jump.Cooldown,
						usable = not blocked,
					},
				uppercut = {
					readyAt = upperReady,
					total = upperTotal,
					usable = canUpper,
				},
			}
			for _, action in HudTheme.Actions do
				local id = action.id
				local timing = (timings :: any)[id]
				local state = HudLogic.actionState(now, timing.readyAt, timing.usable)
				local row = rows[id]
				paintRow(row, state)
				local left = HudLogic.cooldownLeft(now, timing.readyAt, timing.total)
				if state == "recovering" then
					row.fill.Size = UDim2.fromScale(1 - left, 1)
				end
				if now >= row.wordUntil then
					local say = ""
					local colour = C.Muted
					if id == "kick" and cueUp then
						say, colour = "NOW", C.Accent -- the kick's timing window is open
					elseif state == "recovering" and timing.total >= 1 then
						say = string.format("%.1fs", timing.readyAt - now)
					elseif state == "unavailable" then
						say = "-"
					end
					if say ~= row.statusText then
						row.statusText = say
						row.status.Text = say
						row.status.TextColor3 = colour
					end
				end
				if device == "touch" then
					local cover, seconds = touchOverlay(action.touchAction)
					if cover then
						local recovering = state == "recovering"
						cover.Size = UDim2.fromScale(1, if recovering then left else 0)
						if seconds then
							seconds.Text = if recovering and timing.total >= 1
								then string.format("%.1f", timing.readyAt - now)
								else ""
						end
					end
				end
			end

			-- One target chip: the lock-on target, or else the nearest opponent ahead.
			if now >= nextTargetPick then
				nextTargetPick = now + 0.1
				local pick: Model? = lockOn:GetTarget()
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
				if pick ~= target then
					target = pick
					local root = pick and pick:FindFirstChild("HumanoidRootPart")
					chip.Adornee = root
					chip.Enabled = root ~= nil
					chipNumber.Text = ""
					if pick then
						local owner = Players:GetPlayerFromCharacter(pick)
						chipName.Text = if owner then owner.DisplayName else pick.Name
					end
				end
			end
			if target then
				local value = (target:GetAttribute("HT_Stagger") or 0) :: number
				local label = `{math.floor(value + 0.5)}%`
				if chipNumber.Text ~= label then
					chipNumber.Text = label
					chipFill.Size = UDim2.fromScale(math.clamp(value / STAGGER_MAX, 0, 1), 1)
					local hot = value >= STAGGER_MAX * HOT_SHARE
					chipNumber.TextColor3 = if hot then C.AccentHot else C.Accent
					chipFill.BackgroundColor3 = chipNumber.TextColor3
				end
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

return HudController
