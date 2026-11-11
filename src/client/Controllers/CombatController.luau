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

local Typography = require(ReplicatedStorage.Shared.Typography)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)

local punchCfg = GameConfig.Punch
local ACTION = "HaymakerPunch"
local COMBATANT_TAG = "HT_Combatant"
local FLASH_SECONDS = 0.12

local CombatController = Knit.CreateController({
	Name = "CombatController",
	-- For the HUD: "thrown" (a swing left the hand), "blocked" (a press that couldn't punch and wasn't
	-- remembered), then the server's word on it, "hit" or "miss", or "refused".
	PunchEvent = Signal.new(),
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
	-- Only training dummies carry a permanent label. Opponents get the HUD's one target chip, and
	-- your own stagger is on your panel.
	if model:GetAttribute("HT_Dummy") ~= true or model:GetAttribute("HT_Bot") == true then
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
	Typography.apply(label, "World")
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
	-- The same things the server refuses a punch for, so no swing plays that was never going to count.
	local function canPunch(character: Model?): boolean
		if character == nil then
			return false
		end
		local air = character:GetAttribute("HT_Air")
		return character:GetAttribute("HT_Skill") == nil
			and (air == nil or (air == "float" and GameConfig.AirRecovery.PunchWhileLaunched))
			and character:GetAttribute("HT_Stunned") == nil
			and character:GetAttribute("HT_RoundHold") == nil
			and character:GetAttribute("HT_Spectating") == nil
			and character:GetAttribute("HT_Clash") == nil
	end

	local function throw(now: number, character: Model)
		undoPress, undoSide = lastPress, nextSide
		nextSide = Combat.comboSwing(punchCfg, nextSide, now, lastPress)
		lastPress = now
		recovery = 0
		buffered = nil
		local swing = nextSide
		anim:PlaySwing(character, swing)
		fx:Swing(character)
		nextSide = Combat.nextSwing(nextSide)
		movement:PunchThrown(swing)
		request:FireServer()
		self.PunchEvent:Fire("thrown")
	end

	-- The HUD's view of the punch: when it can swing again, the whole wait that started, and whether
	-- the body is in a state to swing at all.
	self._timing = function(): (number, number, boolean)
		return lastPress + punchCfg.Cooldown + recovery,
			punchCfg.Cooldown + recovery,
			canPunch(player.Character)
	end

	-- A press is one punch, thrown at once. Pressed a moment too early, it's remembered once, and thrown
	-- as soon as it can be. It's not a queue: a second early press just replaces the first. A press that
	-- can't punch tells the HUD it was blocked.
	-- Holding the button does nothing more: each punch takes its own press. A clash takes one tap per press.
	ContextActionService:BindAction(ACTION, function(_name: string, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			local now = os.clock()
			local character = player.Character
			if character and character:GetAttribute("HT_Clash") then
				if clashTap then
					clashTap:FireServer()
				end
			elseif not character or not canPunch(character) then
				buffered = nil
				self.PunchEvent:Fire("blocked")
			else
				local readyAt = lastPress + punchCfg.Cooldown + recovery
				if now >= readyAt then
					throw(now, character)
				elseif Combat.pressBuffers(punchCfg, now, readyAt) then
					buffered = now
				else
					self.PunchEvent:Fire("blocked")
				end
			end
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION, "Punch")

	player.CharacterAdded:Connect(function()
		buffered = nil
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local character = player.Character
		if buffered then
			if not Combat.bufferLive(punchCfg, now, buffered) or not canPunch(character) then
				buffered = nil
			elseif character and now >= lastPress + punchCfg.Cooldown + recovery then
				throw(now, character)
			end
		end
	end)

	if result then
		result.OnClientEvent:Connect(function(attacker: Model, kind: string)
			if attacker == player.Character then
				if kind == "hit" or kind == "miss" or kind == "refused" or kind == "cancelled" then
					self.PunchEvent:Fire(kind)
				end
				if kind == "miss" then
					recovery = punchCfg.MissRecovery
				elseif kind == "refused" then
					-- It never happened, so the timing and the combo go back to before it.
					lastPress = undoPress or lastPress
					nextSide = undoSide
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

--- When the next punch can be thrown, the whole cooldown that started (with any miss recovery), and
--- whether the body can punch at all right now. Before start, everything is ready.
function CombatController:GetPunchTiming(): (number, number, boolean)
	if self._timing then
		return self._timing()
	end
	return 0, punchCfg.Cooldown, true
end

return CombatController
