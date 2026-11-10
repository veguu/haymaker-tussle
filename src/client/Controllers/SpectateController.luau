--!strict
-- SpectateController - the Spectate button, top left under AFK, and its two views. The rules are in
-- Core/Spectate; this draws them and moves the camera.
--
-- MY VIEW: the normal game. Your camera is on your own avatar and you walk where you like.
-- FIGHTER POV: the camera sits just behind a fighter still in the round and faces the way they face
-- (another player's own camera isn't sent to you, so their facing is the truth available). Your avatar
-- stays where it is in the lobby with its controls off, until you come back.
--
-- Who can be watched: every body tagged HT_Fighter by RoundService. If the one you're watching goes,
-- you're moved to the next and the list opens so you can choose; with nobody left, or when the round
-- ends, you're back in My View with your camera and controls. With no round on, the button says so.
--
-- While you're in a round yourself the button is locked, like AFK.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Spectate = require(ReplicatedStorage.Shared.Core.Spectate)
local Typography = require(ReplicatedStorage.Shared.Typography)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)

local lobbyCfg: any = GameConfig.Lobby
local camCfg: any = lobbyCfg.Spectate
local C = HudTheme.Colour
local S = HudTheme.Spectate
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

local function label(parent: Instance, name: string, role: string, colour: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Text = "<unbound>"
	text.TextColor3 = colour
	Typography.apply(text, role)
	text.Parent = parent
	return text
end

local function button(parent: Instance, name: string, text: string): TextButton
	local made = Instance.new("TextButton")
	made.Name = name
	made.AutoButtonColor = false
	made.BorderSizePixel = 0
	made.Selectable = true
	made.BackgroundColor3 = C.PanelRaised
	made.TextColor3 = C.Text
	made.Text = text
	Typography.apply(made, "Button")
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, S.Corner)
	corner.Parent = made
	made.Parent = parent
	return made
end

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
	root.Position =
		UDim2.fromOffset(HudTheme.Size.Edge, HudTheme.Afk.Top + HudTheme.Afk.Height + S.Gap)
	root.Size = UDim2.fromOffset(S.Width + S.Gap + S.PanelWidth, S.Height + (S.Row + S.Gap) * 2)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local main = Instance.new("TextButton")
	main.Name = "SpectateButton"
	main.Size = UDim2.fromOffset(S.Width, S.Height)
	main.AutoButtonColor = false
	main.BorderSizePixel = 0
	main.Text = ""
	main.Selectable = true
	main.BackgroundColor3 = C.Panel
	main.Parent = root
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, S.Corner)
	mainCorner.Parent = main
	local press = Instance.new("UIScale")
	press.Parent = main
	local title = label(main, "Title", "Button", C.Text)
	title.Size = UDim2.new(1, 0, 0.6, 0)
	title.Position = UDim2.fromScale(0, 0.05)
	title.Text = "SPECTATE"
	local sub = label(main, "Sub", "Label", C.Muted)
	sub.Size = UDim2.new(1, -8, 0.4, 0)
	sub.Position = UDim2.new(0, 4, 0.58, 0)
	sub.TextTruncate = Enum.TextTruncate.AtEnd

	-- The panel: the two views on one row, then who you're watching with previous and next.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Position = UDim2.fromOffset(S.Width + S.Gap, 0)
	panel.Size = UDim2.fromOffset(S.PanelWidth, S.Pad * 2 + S.Row * 2 + S.Gap)
	panel.BackgroundColor3 = C.Panel
	panel.BackgroundTransparency = HudTheme.Transparency.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = root
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, S.Corner)
	panelCorner.Parent = panel

	local half = (S.PanelWidth - S.Pad * 2 - S.Gap) / 2
	local mineButton = button(panel, "MyView", "MY VIEW")
	mineButton.Position = UDim2.fromOffset(S.Pad, S.Pad)
	mineButton.Size = UDim2.fromOffset(half, S.Row)
	local povButton = button(panel, "FighterPov", "FIGHTER POV")
	povButton.Position = UDim2.fromOffset(S.Pad + half + S.Gap, S.Pad)
	povButton.Size = UDim2.fromOffset(half, S.Row)

	local rowY = S.Pad + S.Row + S.Gap
	local prevButton = button(panel, "Previous", "<")
	prevButton.Position = UDim2.fromOffset(S.Pad, rowY)
	prevButton.Size = UDim2.fromOffset(S.Arrow, S.Row)
	local nextButton = button(panel, "Next", ">")
	nextButton.Position = UDim2.fromOffset(S.PanelWidth - S.Pad - S.Arrow, rowY)
	nextButton.Size = UDim2.fromOffset(S.Arrow, S.Row)
	local who = label(panel, "Who", "Button", C.Text)
	who.Position = UDim2.fromOffset(S.Pad + S.Arrow + S.Gap, rowY)
	who.Size = UDim2.fromOffset(S.PanelWidth - (S.Pad + S.Arrow + S.Gap) * 2, S.Row)
	who.TextWrapped = true

	-- State.
	local view = "mine"
	local target: Model? = nil
	local targetIndex = 1
	local notice: string? = nil -- one line about what just happened, until the next change
	local open = false
	local controls: any = nil
	local camPosition: Vector3? = nil
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
		main.Active = not inRound
		main.BackgroundTransparency = if inRound
			then HudTheme.Transparency.Stepped
			else HudTheme.Transparency.Panel
		title.TextColor3 = if inRound then C.Dim else C.Text
		sub.TextColor3 = if inRound then C.Dim else C.Muted
		sub.Text = if inRound
			then "locked in round"
			else Spectate.status(view, phase(), watching, #list)
		panel.Visible = open and not inRound

		local pov = view == "pov"
		mineButton.BackgroundColor3 = if pov then C.PanelRaised else C.Accent
		mineButton.TextColor3 = if pov then C.Text else C.OnAccent
		mineButton.Text = if pov then "MY VIEW" else "MY VIEW  ON"
		povButton.BackgroundColor3 = if pov then C.Accent else C.PanelRaised
		povButton.TextColor3 = if pov then C.OnAccent else C.Text
		povButton.Text = if pov then "FIGHTER POV  ON" else "FIGHTER POV"
		local canCycle = pov and #list > 1
		prevButton.Active = canCycle
		nextButton.Active = canCycle
		prevButton.TextColor3 = if canCycle then C.Text else C.Dim
		nextButton.TextColor3 = if canCycle then C.Text else C.Dim
		if notice then
			who.Text = notice
		elseif pov and watching then
			who.Text = watching
		elseif Spectate.matchActive(phase()) and #list > 0 then
			who.Text = `{#list} fighting`
		else
			who.Text = "No active match"
		end
		who.TextColor3 = if pov and not notice then C.Text else C.Muted
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
		if not camera or not bodyRoot then
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
		if view ~= "pov" then
			view = "pov"
			local camera = workspace.CurrentCamera
			if camera then
				camera.CameraType = Enum.CameraType.Scriptable
			end
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

	local function tweenPress(value: number, seconds: number)
		if GuiService.ReducedMotionEnabled then
			press.Scale = 1
			return
		end
		TweenService:Create(
			press,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = value }
		):Play()
	end

	main.MouseButton1Down:Connect(function()
		tweenPress(S.PressScale, S.PressSeconds)
	end)
	main.MouseButton1Up:Connect(function()
		tweenPress(1, S.ReleaseSeconds)
	end)
	main.MouseLeave:Connect(function()
		tweenPress(1, S.ReleaseSeconds)
	end)
	main.Activated:Connect(function()
		if player:GetAttribute(IN_ROUND) == true then
			return
		end
		open = not open
		notice = nil
		show()
	end)
	mineButton.Activated:Connect(function()
		toMine(nil)
	end)
	povButton.Activated:Connect(function()
		if view ~= "pov" then
			toPov()
		end
	end)
	prevButton.Activated:Connect(function()
		cycle(-1)
	end)
	nextButton.Activated:Connect(function()
		cycle(1)
	end)

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
		local ref = HudTheme.Scale.Reference
		scale.Scale = math.clamp(
			math.min(size.X / ref.X, size.Y / ref.Y),
			HudTheme.Scale.Min,
			HudTheme.Scale.Max
		)
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	show()
	layout()
	gui.Parent = player:WaitForChild("PlayerGui")
end

return SpectateController
