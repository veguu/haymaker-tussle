--!strict
-- CombatController - punch input and combat feedback. It only ever sends "I pressed
-- punch". The swing shows at once so input feels instant; hits are only shown once the
-- server confirms them. A swing the server refuses, or that gets beaten, stops, so it never
-- looks like a punch passing through someone. During a clash the same button taps instead.
--
-- The stagger labels are placeholders until the HUD. AnimController plays the swings.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)

local punchCfg = GameConfig.Punch
local ACTION = "HaymakerPunch"
local COMBATANT_TAG = "HT_Combatant"
local FLASH_SECONDS = 0.12

local CombatController = Knit.CreateController({
	Name = "CombatController",
})

local function flash(target: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = target
	highlight.Parent = target
	task.delay(FLASH_SECONDS, function()
		highlight:Destroy()
	end)
end

local function addStaggerLabel(model: Instance)
	if not model:IsA("Model") then
		return
	end
	if not GameConfig.Debug.MoveReadout and model:GetAttribute("HT_Dummy") ~= true then
		return
	end
	-- Your own stagger is on the readout at the top of the screen.
	if model == Players.LocalPlayer.Character then
		return
	end
	local head = model:WaitForChild("Head", 5)
	if not head or not head:IsA("BasePart") then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "HT_StaggerLabel"
	board.Size = UDim2.fromOffset(110, 26)
	board.StudsOffset = Vector3.new(0, 2.4, 0)
	board.AlwaysOnTop = true
	board.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.Parent = board
	local function refresh()
		label.Text = `Stagger {model:GetAttribute("HT_Stagger") or 0}`
	end
	model:GetAttributeChangedSignal("HT_Stagger"):Connect(refresh)
	refresh()
	board.Parent = head
end

function CombatController:KnitStart()
	local player = Players.LocalPlayer
	local request = Net.client("PunchRequest")
	local started = Net.client("PunchStarted")
	local confirmed = Net.client("HitConfirmed")
	local bumped = Net.client("BumpHappened")
	local fx = Knit.GetController("FxController")
	local anim = Knit.GetController("AnimController")
	local movement = Knit.GetController("MovementController")
	if not request or not started or not confirmed then
		warn("[Haymaker Tussle] combat remotes missing; punching is off")
		return
	end

	local clashTap = Net.client("ClashTap")
	local result = Net.client("PunchResult")

	local nextSide = "Left"
	local lastPress = -math.huge
	local recovery = 0 -- what the last swing owes on top of the cooldown, which only a whiff does
	local buffered: number? = nil
	local undoPress: number? = nil
	local undoSide = "Left"
	-- Holding the button: the next punch goes the moment the cooldown allows, exactly as a press then
	-- would. `heldBy` is the input holding it, polled so a lost release can't leave it held.
	local held = false
	local heldBy: Enum.UserInputType? = nil
	local holdBlockedUntil = 0 -- after a refusal, a hold waits a cooldown before trying again

	local function letGo()
		held = false
		heldBy = nil
	end

	local function stillHeld(): boolean
		if not held then
			return false
		end
		if heldBy == Enum.UserInputType.MouseButton1 then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		elseif heldBy and string.find(heldBy.Name, "Gamepad") then
			return UserInputService:IsGamepadButtonDown(heldBy, Enum.KeyCode.ButtonR2)
		end
		return true -- touch has no polled state; End and Cancel cover it
	end

	-- The same things the server refuses a punch for, so no swing plays that was never going to count.
	local function canPunch(character: Model?): boolean
		if character == nil then
			return false
		end
		local air = character:GetAttribute("HT_Air")
		return character:GetAttribute("HT_Skill") == nil
			and (air == nil or (air == "float" and GameConfig.AirRecovery.PunchWhileLaunched))
			and character:GetAttribute("HT_Stunned") == nil
			and character:GetAttribute("HT_Clash") == nil
	end

	local function throw(now: number, character: Model)
		undoPress, undoSide = lastPress, nextSide
		nextSide = Combat.comboSwing(punchCfg, nextSide, now, lastPress)
		lastPress = now
		recovery = 0
		buffered = nil
		anim:PlaySwing(character, nextSide)
		fx:Swing(character)
		nextSide = Combat.nextSwing(nextSide)
		movement:PunchThrown()
		request:FireServer()
	end

	-- A press is one punch, thrown at once. Pressed a moment too early, it's remembered once, and thrown
	-- as soon as it can be. It's not a queue: a second early press just replaces the first.
	-- Holding the button after that throws the next punch each time the cooldown allows, through the same
	-- gates as a press, so a hold is never faster than clicking and keeps the same combo. Letting go stops
	-- it at once. A clash still takes one tap per press: holding never mashes.
	ContextActionService:BindAction(
		ACTION,
		function(_name: string, inputState: Enum.UserInputState, inputObject: InputObject)
			if inputState == Enum.UserInputState.Begin then
				local now = os.clock()
				local character = player.Character
				if character and character:GetAttribute("HT_Clash") then
					letGo()
					if clashTap then
						clashTap:FireServer()
					end
				elseif not character or not canPunch(character) then
					buffered = nil
					held = true
					heldBy = inputObject.UserInputType
				else
					held = true
					heldBy = inputObject.UserInputType
					local readyAt = lastPress + punchCfg.Cooldown + recovery
					if now >= readyAt then
						throw(now, character)
					elseif Combat.pressBuffers(punchCfg, now, readyAt) then
						buffered = now
					end
				end
			elseif
				inputState == Enum.UserInputState.End
				or inputState == Enum.UserInputState.Cancel
			then
				letGo()
			end
			return Enum.ContextActionResult.Pass
		end,
		true,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle(ACTION, "Punch")

	-- Anything that could swallow the release lets go: the window losing focus, and a new body.
	UserInputService.WindowFocusReleased:Connect(letGo)
	player.CharacterAdded:Connect(function(character: Model)
		letGo()
		buffered = nil
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(letGo)
		end
	end)
	player.CharacterRemoving:Connect(letGo)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local character = player.Character
		if buffered then
			if not Combat.bufferLive(punchCfg, now, buffered) or not canPunch(character) then
				buffered = nil
			elseif character and now >= lastPress + punchCfg.Cooldown + recovery then
				throw(now, character)
			end
			return
		end
		if not held then
			return
		end
		if not stillHeld() or (character and character:GetAttribute("HT_Clash")) then
			letGo()
			return
		end
		if
			character
			and canPunch(character)
			and now >= holdBlockedUntil
			and now >= lastPress + punchCfg.Cooldown + recovery
		then
			throw(now, character)
		end
	end)

	if result then
		result.OnClientEvent:Connect(function(attacker: Model, kind: string)
			if attacker == player.Character then
				if kind == "miss" then
					recovery = punchCfg.MissRecovery
				elseif kind == "refused" then
					-- It never happened, so the timing and the combo go back to before it. A hold
					-- waits a cooldown before asking again, so it can't hammer the server.
					lastPress = undoPress or lastPress
					nextSide = undoSide
					holdBlockedUntil = os.clock() + punchCfg.Cooldown
					movement:PunchRefused()
				elseif kind == "clash" then
					buffered = nil
				end
			end
			if (kind == "cancelled" or kind == "refused") and attacker then
				anim:CancelSwing(attacker)
			end
		end)
	end

	local clashEnded = Net.client("ClashEnded")
	if clashEnded then
		-- Coming out of a clash starts the cooldown over, the same as the server does.
		clashEnded.OnClientEvent:Connect(function(a: Model, b: Model)
			local me = player.Character
			if me and (a == me or b == me) then
				lastPress = os.clock()
				recovery = 0
				buffered = nil
				-- The last mash may still be down: punching again takes a fresh press.
				letGo()
			end
		end)
	end

	-- Attackers are characters, not players, because the test bot punches too.
	started.OnClientEvent:Connect(function(attacker: Model, side: string)
		if attacker == player.Character then
			-- Our swing already played. Follow the server's side in case they differ.
			nextSide = Combat.nextSwing(side)
		elseif attacker and attacker.Parent then
			fx:Swing(attacker)
		end
	end)

	confirmed.OnClientEvent:Connect(function(attacker: Model, target: Model, strength: number)
		if target and target.Parent then
			-- Shown the moment this client's swing reaches its Hit event, at the fist.
			anim:AtStrike(attacker, function()
				if target.Parent then
					flash(target)
					anim:HitLanded(attacker, target, strength)
					fx:HitBurst(target, attacker, strength, anim:StrikeTip(attacker))
				end
			end)
		end
	end)

	if bumped then
		-- A shove, not a hit: the puff and a small reaction sized to it, with no burst or flash.
		bumped.OnClientEvent:Connect(function(a: Model, b: Model, knockA: number, knockB: number)
			if a and b and a.Parent and b.Parent then
				fx:BumpPuff(a, b)
				anim:HitLanded(b, a, knockA)
				anim:HitLanded(a, b, knockB)
			end
		end)
	end

	CollectionService:GetInstanceAddedSignal(COMBATANT_TAG):Connect(addStaggerLabel)
	for _, model in CollectionService:GetTagged(COMBATANT_TAG) do
		task.spawn(addStaggerLabel, model)
	end
end

return CombatController