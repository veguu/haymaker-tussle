--!strict
-- TutorialController - the first-join tutorial. One short instruction at a time, a live
-- prompt showing the moment a punch would land, and a skip button. Steps move on from what
-- really happened: hits and bumps count only once the server confirms them.
--
-- The prompt asks the same hitbox rule the server uses, for where everyone will be when the
-- punch lands, so "CLICK NOW!" means it. It's only advice: the server still decides.
--
-- Nothing is saved between sessions, so this shows on every join for now.
-- The look is a placeholder until the interface step.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Tutorial = require(ReplicatedStorage.Shared.Core.Tutorial)
local Net = require(ReplicatedStorage.Shared.Net)

local cfg = GameConfig.Tutorial
local punchCfg = GameConfig.Punch
local COMBATANT_TAG = "HT_Combatant"
local CLICK_COLOUR = Color3.fromRGB(90, 230, 110)
local ADVICE_COLOUR = Color3.fromRGB(255, 225, 120)
local MISS_COLOUR = Color3.fromRGB(255, 110, 100)

local TutorialController = Knit.CreateController({
	Name = "TutorialController",
})

local function currentDevice(): Tutorial.Device
	local kind = UserInputService:GetLastInputType()
	if kind == Enum.UserInputType.Touch then
		return "touch"
	elseif kind.Name:find("Gamepad") then
		return "gamepad"
	end
	return "mouse"
end

-- Who to practise on: the nearest other player, or the test bot when you're alone.
local function nearestTarget(me: Model?, from: Vector3): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, instance in CollectionService:GetTagged(COMBATANT_TAG) do
		if instance:IsA("Model") and instance ~= me then
			local root = instance:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local distance = (root.Position - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = instance, distance
				end
			end
		end
	end
	return best
end

local function makeLabel(parent: Instance, name: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent
	return label
end

type Screen = {
	gui: ScreenGui,
	objective: TextLabel,
	hint: TextLabel,
	progress: TextLabel,
	prompt: TextLabel,
	skip: TextButton,
}

local function makeScreen(parent: Instance): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_Tutorial"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 44)
	panel.Size = UDim2.new(0.92, 0, 0, 108)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 108)
	limit.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local progress = makeLabel(panel, "Progress")
	progress.Position = UDim2.fromOffset(14, 8)
	progress.Size = UDim2.new(1, -110, 0, 18)
	progress.TextSize = 14
	progress.TextXAlignment = Enum.TextXAlignment.Left
	progress.TextColor3 = ADVICE_COLOUR

	local objective = makeLabel(panel, "Objective")
	objective.Position = UDim2.fromOffset(14, 28)
	objective.Size = UDim2.new(1, -28, 0, 30)
	objective.TextSize = 22
	objective.TextXAlignment = Enum.TextXAlignment.Left

	local hint = makeLabel(panel, "Hint")
	hint.Position = UDim2.fromOffset(14, 60)
	hint.Size = UDim2.new(1, -28, 0, 40)
	hint.TextSize = 15
	hint.Font = Enum.Font.Gotham
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -10, 0, 6)
	skip.Size = UDim2.fromOffset(84, 24)
	skip.BackgroundColor3 = Color3.fromRGB(70, 76, 92)
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 14
	skip.Text = "Skip"
	skip.Parent = panel
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 6)
	skipCorner.Parent = skip

	-- Above the middle of the screen: clear of the character and of the phone buttons.
	local prompt = makeLabel(gui, "Prompt")
	prompt.AnchorPoint = Vector2.new(0.5, 0.5)
	prompt.Position = UDim2.fromScale(0.5, 0.36)
	prompt.Size = UDim2.new(0.8, 0, 0, 64)
	prompt.TextSize = 44
	prompt.TextStrokeTransparency = 0

	gui.Parent = parent
	return {
		gui = gui,
		objective = objective,
		hint = hint,
		progress = progress,
		prompt = prompt,
		skip = skip,
	}
end

function TutorialController:_run(player: Player)
	local trove = Trove.new()
	local doneRemote = Net.client("TutorialDone")
	local confirmed = Net.client("HitConfirmed")
	local started = Net.client("PunchStarted")
	local bumped = Net.client("BumpHappened")
	if not confirmed or not started or not bumped then
		warn("[Haymaker Tussle] combat remotes missing; no tutorial")
		if doneRemote then
			doneRemote:FireServer()
		end
		return
	end

	local screen = makeScreen(player:WaitForChild("PlayerGui"))
	trove:Add(screen.gui)

	local state = Tutorial.new()
	local stepStartedAt = os.clock()
	local lastPunchAt = -math.huge
	local missUntil = 0
	local missText = ""
	local currentAdvice: Tutorial.Advice = "closer"
	local finished = false

	local highlight = trove:Add(Instance.new("Highlight"))
	highlight.Name = "HT_TutorialTarget"
	highlight.FillTransparency = 1
	highlight.OutlineColor = CLICK_COLOUR
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	-- Lives here, not on the target, because a target can leave at any moment.
	highlight.Parent = player:WaitForChild("PlayerGui")

	local arrow = trove:Add(Instance.new("BillboardGui"))
	arrow.Name = "HT_TutorialArrow"
	arrow.Size = UDim2.fromOffset(60, 60)
	arrow.StudsOffset = Vector3.new(0, 5.5, 0)
	arrow.AlwaysOnTop = true
	arrow.Enabled = false
	local arrowLabel = makeLabel(arrow, "Arrow")
	arrowLabel.Size = UDim2.fromScale(1, 1)
	arrowLabel.Text = "V"
	arrowLabel.TextSize = 44
	arrowLabel.TextColor3 = ADVICE_COLOUR
	arrowLabel.TextStrokeTransparency = 0

	local function finish(showEnding: boolean)
		if finished then
			return
		end
		finished = true
		player:SetAttribute("HT_TutorialStep", "done")
		if doneRemote then
			doneRemote:FireServer()
		end
		highlight.Enabled = false
		arrow.Enabled = false
		screen.prompt.Text = ""
		if not showEnding then
			trove:Destroy()
			return
		end
		screen.skip.Visible = false
		screen.progress.Text = ""
		local ending, nextGoal = Tutorial.text(state, cfg, currentDevice())
		screen.objective.Text = ending
		screen.hint.Text = nextGoal
		task.delay(cfg.EndSeconds, function()
			trove:Destroy()
		end)
	end

	local function apply(event: Tutorial.Event)
		if finished then
			return
		end
		local before = state
		state = Tutorial.handle(state, cfg, event)
		if state.step ~= before.step then
			stepStartedAt = os.clock()
			player:SetAttribute("HT_TutorialStep", Tutorial.stepName(state))
			if Tutorial.isDone(state) then
				finish(true)
			end
		elseif state.hits ~= before.hits then
			stepStartedAt = os.clock()
		end
	end

	player:SetAttribute("HT_TutorialStep", Tutorial.stepName(state))
	trove:Connect(screen.skip.Activated, function()
		finish(false)
	end)
	trove:Connect(confirmed.OnClientEvent, function(attacker: Model, target: Model)
		local character = player.Character
		if attacker ~= character or not target then
			return
		end
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
		apply({
			kind = "hit",
			now = os.clock(),
			speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude,
		})
	end)
	trove:Connect(started.OnClientEvent, function(attacker: Model)
		if attacker == player.Character then
			-- Judged as it was just before this punch, so a bad one can say why.
			local text = Tutorial.missText(currentAdvice)
			if text ~= "" and state.step > 1 and not Tutorial.isDone(state) then
				missText = text
				missUntil = os.clock() + cfg.MissSeconds
			end
			lastPunchAt = os.clock()
		end
	end)
	trove:Connect(bumped.OnClientEvent, function(a: Model, b: Model)
		local character = player.Character
		if a == character or b == character then
			apply({ kind = "bump", now = os.clock() })
		end
	end)
	trove:Connect(Knit.GetController("MovementController").Propelled, function()
		apply({ kind = "propel" })
	end)

	trove:Connect(RunService.Heartbeat, function()
		if finished then
			return
		end
		local now = os.clock()
		local device = currentDevice()
		local objective, hint = Tutorial.text(state, cfg, device)
		screen.progress.Text = `Step {state.step} of {#Tutorial.STEPS}`
		screen.objective.Text = objective
		local showHint = now - stepStartedAt >= cfg.HintSeconds
		screen.hint.Text = if showHint then hint else ""

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local target = root and nearestTarget(character, root.Position)
		local targetRoot = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
		local step = Tutorial.stepName(state)
		if not root or not target or not targetRoot then
			highlight.Enabled = false
			arrow.Enabled = false
			screen.prompt.Text = ""
			return
		end

		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = if flat.Magnitude > 0.001 then flat.Unit else Vector3.new(0, 0, -1)
		local at, velocity = root.Position, root.AssemblyLinearVelocity
		local targetAt, targetVelocity = targetRoot.Position, targetRoot.AssemblyLinearVelocity
		local inside, why = Combat.inHitboxAtImpact(
			punchCfg,
			punchCfg.Windup,
			at.X,
			at.Y,
			at.Z,
			flat.X,
			flat.Z,
			velocity.X,
			velocity.Z,
			targetAt.X,
			targetAt.Y,
			targetAt.Z,
			targetVelocity.X,
			targetVelocity.Z
		)
		local ready = now - lastPunchAt >= punchCfg.Cooldown
		currentAdvice = Tutorial.advice(inside, why, ready)

		if step == "run" then
			arrow.Adornee = target:FindFirstChild("Head") :: BasePart?
			arrow.Parent = player:FindFirstChild("PlayerGui")
			arrow.Enabled = true
			if inside then
				apply({ kind = "inReach" })
			end
		else
			arrow.Enabled = false
		end

		-- The prompt belongs to the punching steps only; one thing on screen at a time.
		if step == "punch" or step == "fast" or step == "bump" then
			if now < missUntil then
				screen.prompt.Text = missText
				screen.prompt.TextColor3 = MISS_COLOUR
			else
				screen.prompt.Text = Tutorial.promptText(currentAdvice, device)
				screen.prompt.TextColor3 = if currentAdvice == "click"
					then CLICK_COLOUR
					else ADVICE_COLOUR
			end
			highlight.Adornee = target
			highlight.Enabled = currentAdvice == "click"
		else
			screen.prompt.Text = ""
			highlight.Enabled = false
		end
	end)
end

function TutorialController:KnitStart()
	if not cfg.Enabled then
		return
	end
	local player = Players.LocalPlayer
	if player then
		task.spawn(function()
			self:_run(player)
		end)
	end
end

return TutorialController