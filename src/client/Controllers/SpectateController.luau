--!strict
-- SpectateController - the spectate panel and its two views. The rules are in Core/Spectate; this draws them
-- and moves the camera. The panel is opened from the menu window's More page and stands at the bottom centre,
-- in the fight-poster look (2026-11-18): two rough-cut tabs, MY VIEW and FIGHTER POV (the one that is on is
-- yellow and says ON), and under them previous, who you are watching on a slanted ink plate, and next.
--
-- MY VIEW: the normal game. Your camera is on your own avatar and you walk where you like.
-- FIGHTER POV: the camera follows a fighter still in the round, and you turn and zoom it freely, as you do
-- your own (the owner, 2026-11-18; it used to sit fixed behind them). Your avatar stays where it is in the
-- lobby with its controls off, until you come back.
--
-- Who can be watched: every body tagged HT_Fighter by RoundService. If the one you're watching goes,
-- you're moved to the next and the list opens so you can choose; with nobody left, or when the round
-- ends, you're back in My View with your camera and controls. With no round on, the button says so.
--
-- While you're in a round yourself the button is locked, like AFK.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Spectate = require(ReplicatedStorage.Shared.Core.Spectate)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Drift = require(script.Parent.Parent.Ui.Drift)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)
local Poster = require(script.Parent.Parent.Ui.Poster)
local PosterKit = require(script.Parent.Parent.Ui.PosterKit)

local lobbyCfg: any = GameConfig.Lobby
local camCfg: any = lobbyCfg.Spectate
local colour = Tokens.colour
local S = HudTheme.Spectate
local DRIFT = "spectate"
local FIGHTER_TAG = "HT_Fighter"
local IN_ROUND = "HT_InRound"
local SPECTATING = "HT_Spectating"
local STEP_NAME = "HT_Spectate"
-- After the stock camera and the lock camera, so this is what's drawn.
local STEP_PRIORITY = Enum.RenderPriority.Camera.Value + 3
local STATE_FOLDER = "HT_RoundState"

local SpectateController = Knit.CreateController({
	Name = "SpectateController",
})

function SpectateController:KnitStart()
	if not GameConfig.Round.Enabled or not lobbyCfg.Enabled then
		return
	end
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_Spectate"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Size = UDim2.fromOffset(S.PanelWidth, S.Tab * 2 + S.Gap)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root

	-- The panel: the two views on one row, then who you're watching with previous and next.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundTransparency = 1
	panel.Size = UDim2.fromScale(1, 1)
	panel.Visible = false
	panel.Parent = root

	-- a rough-cut button with a word on it; it drifts like every pressable control (Ui/Drift)
	type Piece = { cut: PosterKit.Cut, label: TextLabel }
	local function piece(
		shape: string,
		x: number,
		y: number,
		width: number,
		words: string,
		onPress: () -> ()
	): Piece
		local cut = PosterKit.cut(
			panel,
			shape,
			Vector2.new(width, S.Tab),
			colour("ivory.50"),
			Vector2.new(4, 5)
		)
		PosterKit.place(cut, x, y)
		local label = Poster.text(cut.face, "label", 15, "ink.900", {
			Size = UDim2.fromScale(1, 1),
			Text = words,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		PosterKit.pressable(cut, onPress)
		Drift.add(DRIFT, cut.body, S.Tab, 3)
		return { cut = cut, label = label }
	end
	-- what the buttons do is set further down, once the views exist
	local onMine: () -> (), onPov: () -> (), onCycle: (number) -> ()
	local half = (S.PanelWidth - S.Gap) / 2
	local mineTab = piece("act", 0, 0, half, "MY VIEW", function()
		onMine()
	end)
	local povTab = piece("act", half + S.Gap, 0, half, "FIGHTER POV", function()
		onPov()
	end)
	local rowY = S.Tab + S.Gap
	local prevArrow = piece("close", 0, rowY, S.Tab, "<", function()
		onCycle(-1)
	end)
	local nextArrow = piece("close", S.PanelWidth - S.Tab, rowY, S.Tab, ">", function()
		onCycle(1)
	end)
	local whoPlate = Instance.new("Frame")
	whoPlate.Name = "Who"
	whoPlate.BackgroundTransparency = 1
	whoPlate.Position = UDim2.fromOffset(S.Tab + S.Gap, rowY)
	whoPlate.Size = UDim2.fromOffset(S.PanelWidth - (S.Tab + S.Gap) * 2, S.Tab)
	whoPlate.Parent = panel
	-- (no plate behind it since ui-19d: the owner wants no slanted ink plate anywhere; an ink outline keeps the
	-- words readable on the world)
	local who = Poster.text(whoPlate, "label", 15, "ivory.50", {
		Position = UDim2.fromOffset(S.Lean + 4, 0),
		Size = UDim2.new(1, -(S.Lean + 4) * 2, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 1,
	})
	local whoLine = Instance.new("UIStroke")
	whoLine.Color = colour("ink.900")
	whoLine.Thickness = 1.5
	whoLine.LineJoinMode = Enum.LineJoinMode.Round
	whoLine.Parent = who

	-- State.
	local view = "mine"
	local target: Model? = nil
	local targetIndex = 1
	local notice: string? = nil -- one line about what just happened, until the next change
	local open = false
	local controls: any = nil
	local camPosition: Vector3? = nil
	local free = false -- the ordinary camera is following the fighter; step() leaves it alone
	local camLook: Vector3? = nil

	local function nameOf(model: Model): string
		local owner = Players:GetPlayerFromCharacter(model)
		return if owner then owner.DisplayName else model.Name
	end

	-- Everyone who can be watched, in a steady order, never yourself.
	local function fighters(): { Model }
		local list: { Model } = {}
		for _, instance in CollectionService:GetTagged(FIGHTER_TAG) do
			if
				instance:IsA("Model")
				and instance ~= player.Character
				and instance:IsDescendantOf(workspace)
			then
				table.insert(list, instance)
			end
		end
		table.sort(list, function(a, b)
			return nameOf(a) < nameOf(b)
		end)
		return list
	end

	local function phase(): string?
		local state = ReplicatedStorage:FindFirstChild(STATE_FOLDER)
		return if state then state:GetAttribute("Phase") :: string? else nil
	end

	local function getControls(): any
		if controls == nil then
			local scripts = player:FindFirstChild("PlayerScripts")
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			if module then
				local ok, result = pcall(function()
					return (require :: any)(module):GetControls()
				end)
				controls = if ok then result else false
			else
				controls = false
			end
		end
		return controls
	end

	local function show()
		local list = fighters()
		local inRound = player:GetAttribute(IN_ROUND) == true
		local watching = if target then nameOf(target) else nil
		local shown = open and not inRound
		panel.Visible = shown
		Drift.show(DRIFT, shown)

		-- the view that is on: yellow, and it says ON (told by word as well as colour)
		local pov = view == "pov"
		mineTab.cut.fill.ImageColor3 = colour(if pov then "ivory.50" else "coral.500")
		mineTab.label.Text = if pov then "MY VIEW" else "MY VIEW  ON"
		povTab.cut.fill.ImageColor3 = colour(if pov then "coral.500" else "ivory.50")
		povTab.label.Text = if pov then "FIGHTER POV  ON" else "FIGHTER POV"
		-- the arrows: light violet when there is someone else to turn to, cream with a dim sign when not (a dark
		-- tile until 2026-11-19: the owner wants no dark plates)
		local canCycle = pov and #list > 1
		for _, arrow in { prevArrow, nextArrow } do
			if arrow.cut.button then
				arrow.cut.button.Active = canCycle
			end
			arrow.cut.fill.ImageColor3 = colour(if canCycle then "violet.400" else "ivory.50")
			arrow.label.TextColor3 = colour(if canCycle then "ink.900" else "stone.300")
			Drift.hold(arrow.cut.body, not canCycle)
		end
		if notice then
			who.Text = notice
		elseif pov and watching then
			who.Text = watching
		elseif Spectate.matchActive(phase()) and #list > 0 then
			who.Text = `{#list} fighting`
		else
			who.Text = "No active match"
		end
		-- (always cream: the dim tone read as pale purple on the world and was hard to read, seen 2026-11-19)
		who.TextColor3 = colour("ivory.50")
	end

	local function restore()
		RunService:UnbindFromRenderStep(STEP_NAME)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		if character then
			character:SetAttribute(SPECTATING, nil)
		end
		local module = getControls()
		if module then
			module:Enable()
		end
		camPosition, camLook = nil, nil
	end

	local function toMine(why: string?)
		if view == "pov" then
			restore()
		end
		view = "mine"
		target = nil
		notice = why
		show()
	end

	local function step(dt: number)
		local camera = workspace.CurrentCamera
		local body = target
		local bodyRoot = body and body:FindFirstChild("HumanoidRootPart") :: BasePart?
		if free or not camera or not bodyRoot then
			return
		end
		local at = bodyRoot.Position
		local face = bodyRoot.CFrame.LookVector
		local px, py, pz, lx, ly, lz = Spectate.camera(camCfg, at.X, at.Y, at.Z, face.X, face.Z)
		local wantPosition, wantLook = Vector3.new(px, py, pz), Vector3.new(lx, ly, lz)
		local blend = if camPosition then math.min(camCfg.Smooth * dt, 1) else 1
		local position = (camPosition or wantPosition):Lerp(wantPosition, blend)
		local look = (camLook or wantLook):Lerp(wantLook, blend)
		camPosition, camLook = position, look
		camera.CFrame = CFrame.lookAt(position, look)
		camera.Focus = CFrame.new(at)
	end

	local function watch(model: Model, why: string?)
		local list = fighters()
		target = model
		targetIndex = table.find(list, model) or 1
		notice = why
		-- The camera follows the fighter and is yours to move (the owner, 2026-11-18): it is the game's ordinary
		-- camera with the fighter as its subject, so you turn and zoom it as you do your own. A body with no
		-- Humanoid falls back to the fixed view behind it (step()).
		local camera = workspace.CurrentCamera
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		free = humanoid ~= nil
		if camera then
			if humanoid then
				camera.CameraType = Enum.CameraType.Custom
				camera.CameraSubject = humanoid
			else
				camera.CameraType = Enum.CameraType.Scriptable
			end
		end
		if view ~= "pov" then
			view = "pov"
			local character = player.Character
			if character then
				character:SetAttribute(SPECTATING, true)
			end
			local module = getControls()
			if module then
				module:Disable()
			end
			RunService:BindToRenderStep(STEP_NAME, STEP_PRIORITY, step)
		end
		camPosition, camLook = nil, nil
		show()
	end

	local function toPov()
		local list = fighters()
		if not Spectate.matchActive(phase()) or #list == 0 then
			toMine("No active match")
			return
		end
		watch(list[1], nil)
	end

	local function cycle(by: number)
		if view ~= "pov" then
			return
		end
		local list = fighters()
		local names: { string } = {}
		for index, model in list do
			names[index] = nameOf(model)
		end
		local picked = Spectate.pick(names, if target then nameOf(target) else nil, by)
		local index = if picked then table.find(names, picked) else nil
		if index then
			watch(list[index], nil)
		end
	end

	-- The watched fighter is out or gone: on to the next, with the list open to choose from, or home.
	local function lost(model: Model)
		if view ~= "pov" or target ~= model then
			show()
			return
		end
		local gone = nameOf(model)
		local list = fighters()
		local names: { string } = {}
		for index, other in list do
			names[index] = nameOf(other)
		end
		local nextName = Spectate.afterLoss(names, targetIndex)
		local index = if nextName then table.find(names, nextName) else nil
		if index and Spectate.matchActive(phase()) then
			open = true
			watch(list[index], `{gone} is out. Now {nextName}`)
		else
			toMine(`{gone} is out`)
		end
	end

	local function toggle()
		if player:GetAttribute(IN_ROUND) == true then
			return
		end
		open = not open
		notice = nil
		show()
	end
	-- The menu window's More page opens this (MenuController).
	self._toggle = toggle
	onMine = function()
		toMine(nil)
	end
	onPov = function()
		if view ~= "pov" then
			toPov()
		end
	end
	onCycle = cycle

	CollectionService:GetInstanceAddedSignal(FIGHTER_TAG):Connect(show)
	CollectionService:GetInstanceRemovedSignal(FIGHTER_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			lost(instance)
		end
	end)

	-- The round ending, or you being put in one, always gives your camera and controls back.
	local function watchState(state: Instance)
		state:GetAttributeChangedSignal("Phase"):Connect(function()
			if view == "pov" and not Spectate.matchActive(phase()) then
				toMine("Round over")
			else
				notice = nil
				show()
			end
		end)
		show()
	end
	local state = ReplicatedStorage:FindFirstChild(STATE_FOLDER)
	if state then
		watchState(state)
	else
		ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == STATE_FOLDER then
				watchState(child)
			end
		end)
	end
	player:GetAttributeChangedSignal(IN_ROUND):Connect(function()
		if player:GetAttribute(IN_ROUND) == true then
			open = false
			toMine(nil)
		else
			show()
		end
	end)
	player.CharacterAdded:Connect(function()
		if view == "pov" then
			toMine(nil)
		end
	end)

	local function layout()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else HudTheme.Scale.Reference
		local by = HudTheme.scaleFor(size)
		scale.Scale = by
		-- The panel stands at the bottom centre, just over the HUD's SPECTATING chip (which stands 24 from the
		-- bottom): nothing lies over anything (the owner, 2026-11-17).
		root.Position = UDim2.new(0.5, 0, 1, -(24 + (S.Chip.Y + 12) * by))
	end
	-- and it gives way to the open menu window
	Knit.GetController("MenuController").Changed:Connect(function(entry: string?)
		gui.Enabled = entry == nil
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	show()
	layout()
	gui.Parent = player:WaitForChild("PlayerGui")
end

--- Opens or closes the spectate panel (the More page's Spectate row). Does nothing in a round.
function SpectateController:Toggle()
	if self._toggle then
		self._toggle()
	end
end

return SpectateController
