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

local Typography = require(ReplicatedStorage.Shared.Typography)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)

local punchCfg = GameConfig.Punch
local holdCfg = GameConfig.SkillHold
local ACTION = "HaymakerPunch"
local upperCfg = GameConfig.Uppercut
local COMBATANT_TAG = "HT_Combatant"
local FLASH_SECONDS = 0.12
-- How big a stunning punch's burst is drawn (it carries no knockback to size it by).
local STUN_HIT_SIZE = 40

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
	local endlag = Knit.GetController("EndlagController")
	if not request or not started or not confirmed then
		warn("[Haymaker Tussle] combat remotes missing; punching is off")
		return
	end

	local clashTap = Net.client("ClashTap")
	local result = Net.client("PunchResult")
	local chargeStart = Net.client("SkillChargeStart")

	local nextSide = "Right"
	local lastPress = -math.huge
	local recovery = 0 -- what the last swing owes on top of the cooldown, which only a whiff does
	local buffered: number? = nil
	local undoPress: number? = nil
	local undoSide = "Right"
	-- An attack skill being charged (R held): which, and since when on this clock.
	local charge: { side: string, at: number }? = nil

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

	-- When the next swing can start: the punch's cooldown, or the endlag of whatever move came last
	-- (Core/Endlag), whichever ends later.
	local function readyAt(): number
		return math.max(lastPress + punchCfg.Cooldown + recovery, endlag:BusyUntil())
	end

	-- The HUD's view of the punch: when it can swing again, the whole wait that started, and whether
	-- the body is in a state to swing at all.
	self._timing = function(): (number, number, boolean)
		return readyAt(), punchCfg.Cooldown + recovery, canPunch(player.Character)
	end

	-- A punch goes on the press: there is no holding one back (2026-11-15). In the air it is the air
	-- punch, which glides toward the aim (MovementController) and strikes after the longer AirWindup.
	local function throw(now: number, character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local air = humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air
		local windup = if air then punchCfg.AirWindup else punchCfg.Windup
		endlag:Start("Punch", windup + punchCfg.ActiveSeconds)
		undoPress, undoSide = lastPress, nextSide
		nextSide = Combat.comboSwing(punchCfg, nextSide, now, lastPress)
		lastPress = now
		recovery = 0
		buffered = nil
		local swing = nextSide
		anim:PlaySwing(character, swing, windup)
		fx:Swing(character)
		nextSide = Combat.nextSwing(nextSide)
		movement:PunchThrown(swing)
		request:FireServer()
		self.PunchEvent:Fire("thrown")
	end

	-- Pressing punches at once. Pressed a moment too early, the press is remembered and the punch goes the
	-- moment it can. A press that can't punch tells the HUD it was blocked. A clash takes one tap per press.
	ContextActionService:BindAction(ACTION, function(_name: string, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local now = os.clock()
		local character = player.Character
		if character and character:GetAttribute("HT_Clash") then
			if clashTap then
				clashTap:FireServer()
			end
		elseif not character or not canPunch(character) or charge then
			buffered = nil
			self.PunchEvent:Fire("blocked")
		elseif now >= readyAt() then
			throw(now, character)
		elseif Combat.pressBuffers(punchCfg, now, readyAt()) then
			buffered = now
		else
			self.PunchEvent:Fire("blocked")
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION, "Punch")

	-- THE ATTACK SKILLS (R). Each has its own cooldown and counts as a swing for the punch's.
	local heavies: { [string]: { cfg: any, remote: RemoteEvent?, last: number } } = {
		Uppercut = { cfg = upperCfg, remote = Net.client("UppercutRequest"), last = -math.huge },
		-- Tempest's attack skill: a spinning hook that reaches all the way round.
		Cyclone = {
			cfg = Abilities.Cyclone,
			remote = Net.client("CycloneRequest"),
			last = -math.huge,
		},
	}
	-- The newer kits' attack skills (Config/Abilities.KitSwings): each through one remote that names
	-- nothing (the server knows the kit).
	local kitSwingRemote = Net.client("KitSwingRequest")
	for skillId, swing in Abilities.KitSwings :: { [string]: any } do
		heavies[skillId] = { cfg = swing, remote = kitSwingRemote, last = -math.huge }
	end

	local function skillReady(move: any, now: number, character: Model?): boolean
		return character ~= nil
			and canPunch(character)
			and now >= readyAt()
			and now - move.last >= (if Players.LocalPlayer:GetAttribute("HT_TrainingFree")
					== true
				then 0
				else move.cfg.Cooldown)
			and move.remote ~= nil
	end

	local function dropCharge(character: Model?, showCancel: boolean)
		if not charge then
			return
		end
		charge = nil
		if character then
			character:SetAttribute("HT_Charging", nil)
			if showCancel then
				anim:CancelSwing(character)
			end
		end
	end

	-- Let go: the skill goes, the same however long it was held (no charge, no timing). The hold
	-- was the wind-up, so it strikes after only SkillHold.ReleaseWindup.
	local function throwHeavy(side: string): boolean
		local move = heavies[side]
		local now = os.clock()
		local character = player.Character
		if not character or not skillReady(move, now, character) then
			self.PunchEvent:Fire("blocked")
			return false
		end
		buffered = nil
		move.last = now
		undoPress, undoSide = lastPress, nextSide
		lastPress = now
		recovery = 0
		local windup = holdCfg.ReleaseWindup
		endlag:Start(
			side,
			windup + punchCfg.ActiveSeconds + (if move.cfg.Cast then move.cfg.Cast.Lead or 0 else 0)
		)
		anim:PlaySwing(character, side, windup)
		fx:Swing(character)
		if move.cfg.Roots ~= false then
			movement:HeavyKickStarted(windup + move.cfg.RootAfter)
		end
		-- A kit's attack skill: its own strike effects (FxController ignores the sides that have none),
		-- and the lunge some of them carry.
		fx:KitSwing(character, side)
		local lunge = move.cfg.Lunge
		if lunge then
			movement:SkillMove(nil, {
				Kind = "burst",
				Aim = "face",
				Speed = lunge.Speed,
				Seconds = lunge.Seconds,
				Turn = 0.2,
			})
		end
		move.remote:FireServer()
		self.PunchEvent:Fire("thrown")
		return true
	end

	-- Starts holding the attack skill `side`: the arm draws back and waits, and you move
	-- at SkillHold.MoveShare. False when it can't be used now.
	self._startCharge = function(side: string): boolean
		local move = heavies[side]
		local now = os.clock()
		local character = player.Character
		if not move or charge or not skillReady(move, now, character) then
			self.PunchEvent:Fire("blocked")
			return false
		end
		local body = character :: Model
		charge = { side = side, at = now }
		body:SetAttribute("HT_Charging", true)
		anim:HoldSwing(body, side)
		if chargeStart then
			chargeStart:FireServer()
		end
		return true
	end
	-- Lets go of the charge: the skill goes. False when there was none or it was turned down.
	self._releaseCharge = function(): boolean
		local held = charge
		if not held then
			return false
		end
		charge = nil
		local character = player.Character
		if character then
			character:SetAttribute("HT_Charging", nil)
		end
		return throwHeavy(held.side)
	end
	self._cancelCharge = function()
		dropCharge(player.Character, true)
	end
	self._charging = function(): boolean
		return charge ~= nil
	end

	-- For the HUD: when the uppercut can be thrown again, and whether the body can swing at all.
	self._uppercutTiming = function(): (number, number, boolean)
		local wait = if Players.LocalPlayer:GetAttribute("HT_TrainingFree") == true
			then 0
			else upperCfg.Cooldown
		return math.max(heavies.Uppercut.last + wait, readyAt()),
			upperCfg.Cooldown,
			canPunch(player.Character)
	end
	-- An attack skill thrown at once, with no charge (tests and on-screen buttons that only tap).
	self._throwSkill = function(side: string): boolean
		return heavies[side] ~= nil and throwHeavy(side)
	end
	self._skillTiming = function(side: string): (number, number, boolean)
		local move = heavies[side]
		if not move then
			return 0, 1, false
		end
		local wait = if Players.LocalPlayer:GetAttribute("HT_TrainingFree") == true
			then 0
			else move.cfg.Cooldown
		return math.max(move.last + wait, readyAt()), move.cfg.Cooldown, canPunch(player.Character)
	end
	self._isSkill = function(side: string): boolean
		return heavies[side] ~= nil
	end

	-- Anything that could swallow the release lets go of a charge: the window losing focus, a new body.
	UserInputService.WindowFocusReleased:Connect(function()
		dropCharge(player.Character, true)
	end)
	player.CharacterAdded:Connect(function()
		buffered = nil
		charge = nil
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local character = player.Character
		if charge then
			if not character or not canPunch(character) then
				-- Stunned, caught or in a clash while charging: the charge is gone.
				dropCharge(character, true)
			elseif now - charge.at >= holdCfg.MaxHoldSeconds then
				-- Held as long as it can be: it goes by itself.
				self._releaseCharge()
			end
			return
		end
		if buffered then
			if not Combat.bufferLive(punchCfg, now, buffered) or not canPunch(character) then
				buffered = nil
			elseif character and now >= readyAt() then
				buffered = nil
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
				elseif kind == "hit" then
					endlag:Landed()
				elseif kind == "refused" or kind == "cancelled" then
					endlag:Undo()
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
				-- A kit's attack skill that never got to strike doesn't show its strike.
				fx:KitSwingCancel(attacker)
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
			if not heavies[side] then
				nextSide = Combat.nextSwing(side)
			end
		elseif attacker and attacker.Parent then
			fx:Swing(attacker)
			fx:KitSwing(attacker, side)
		end
	end)

	confirmed.OnClientEvent:Connect(
		function(attacker: Model, target: Model, strength: number, step: number?)
			-- Hit while charging: the charge is gone (the server drops it too).
			if target == player.Character and charge then
				dropCharge(target, true)
			end
			if target and target.Parent then
				-- Shown the moment this client's swing reaches its Hit event, at the fist.
				anim:AtStrike(attacker, function()
					if target.Parent then
						-- An uppercut's arc leaves a trail behind the body it threw.
						if anim:LastSwing(attacker) == "Uppercut" then
							fx:LaunchTrail(target)
							fx:UppercutHit(target)
						end
						flash(target)
						anim:HitLanded(attacker, target, strength, step)
						-- A kit's attack skill lands with its own hit, in its kit's look.
						local swing = anim:LastSwing(attacker)
						if swing and (Abilities.KitSwings :: any)[swing] then
							fx:KitHit(target, attacker, swing, strength)
						else
							-- A stunning punch (strength 0) still lands as a hit, sized like a light one.
							fx:HitBurst(
								target,
								attacker,
								if strength > 0 then strength else STUN_HIT_SIZE,
								anim:StrikeTip(attacker)
							)
						end
					end
				end)
			end
			local _ = step
		end
	)

	if bumped then
		-- A shove, not a hit: the puff, and a small reaction on whoever was knocked, sized to it. The faster
		-- one carries on untouched, with no pose freeze.
		bumped.OnClientEvent:Connect(function(a: Model, b: Model, knockA: number, knockB: number)
			if a and b and a.Parent and b.Parent then
				-- Our own bump already showed the moment it happened, on this client.
				local me = player.Character
				if
					(a == me and movement:RecentlyBumped(b))
					or (b == me and movement:RecentlyBumped(a))
				then
					return
				end
				fx:BumpPuff(a, b, math.max(knockA, knockB))
				if knockA > 0 then
					anim:HitLanded(nil, a, knockA)
				end
				if knockB > 0 then
					anim:HitLanded(nil, b, knockB)
				end
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

--- The same for the heavy uppercut (R): when it's ready, its whole cooldown, and whether the body can swing.
function CombatController:GetUppercutTiming(): (number, number, boolean)
	if self._uppercutTiming then
		return self._uppercutTiming()
	end
	return 0, upperCfg.Cooldown, true
end

--- The Uppercut skill thrown at once, with no charge. False when it was turned down.
function CombatController:ThrowUppercut(): boolean
	return self._throwSkill ~= nil and self._throwSkill("Uppercut")
end

--- A kit's attack skill ("Uppercut", "Cyclone", a KitSwings id) thrown at once, with no charge. False
--- when it was turned down.
function CombatController:ThrowSkill(side: string): boolean
	return self._throwSkill ~= nil and self._throwSkill(side)
end

--- Is `side` an attack skill this controller throws (so R charges it)?
function CombatController:IsSkill(side: string): boolean
	return self._isSkill ~= nil and self._isSkill(side)
end

--- R pressed: starts charging the attack skill `side`. False when it can't be used now.
function CombatController:StartCharge(side: string): boolean
	return self._startCharge ~= nil and self._startCharge(side)
end

--- R let go: the charged skill goes. False when nothing was charging or it was turned down.
function CombatController:ReleaseCharge(): boolean
	return self._releaseCharge ~= nil and self._releaseCharge()
end

--- Drops a charge without throwing anything.
function CombatController:CancelCharge()
	if self._cancelCharge then
		self._cancelCharge()
	end
end

--- Is an attack skill being charged right now?
function CombatController:IsCharging(): boolean
	return self._charging ~= nil and self._charging()
end

--- That skill's timing for the HUD: when it's ready, its whole cooldown, and whether the body can swing.
function CombatController:GetSkillTiming(side: string): (number, number, boolean)
	if self._skillTiming then
		return self._skillTiming(side)
	end
	return 0, 1, true
end

return CombatController
