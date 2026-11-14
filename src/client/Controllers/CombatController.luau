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
local ACTION = "HaymakerPunch"
local kickCfg = GameConfig.HeavyKick
local upperCfg = GameConfig.Uppercut
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
	local endlag = Knit.GetController("EndlagController")
	if not request or not started or not confirmed then
		warn("[Haymaker Tussle] combat remotes missing; punching is off")
		return
	end

	local clashTap = Net.client("ClashTap")
	local result = Net.client("PunchResult")

	local nextSide = "Right"
	local lastPress = -math.huge
	local recovery = 0 -- what the last swing owes on top of the cooldown, which only a whiff does
	local buffered: number? = nil
	local undoPress: number? = nil
	local undoSide = "Right"
	local holdAt: number? = nil -- when the punch started being held back, on this clock
	local held = false
	local heldBy: Enum.UserInputType? = nil
	local readyRemote = Net.client("PunchReady")
	local kickRemote = Net.client("HeavyKickRequest")
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
		local wasHeld = holdAt ~= nil
		-- How long until it strikes: sooner for a punch held back long enough. Its endlag runs from now
		-- through the strike.
		local windup = Combat.releaseWindup(punchCfg, holdAt, now)
		endlag:Start("Punch", windup + punchCfg.ActiveSeconds)
		holdAt = nil
		-- A punch that skipped the hold (a press remembered through the cooldown) says so first, so the
		-- server never counts an old hold for it.
		if not wasHeld and readyRemote then
			readyRemote:FireServer()
		end
		undoPress, undoSide = lastPress, nextSide
		nextSide = Combat.comboSwing(punchCfg, nextSide, now, lastPress)
		lastPress = now
		recovery = 0
		buffered = nil
		local swing = nextSide
		anim:PlaySwing(character, swing)
		fx:Swing(character, swing, windup)
		nextSide = Combat.nextSwing(nextSide)
		movement:PunchThrown(swing)
		request:FireServer()
		self.PunchEvent:Fire("thrown")
	end

	-- Holding: the arm draws back and waits there, and the server is told, so a release throws fast.
	local function startHold(now: number, character: Model)
		holdAt = now
		if readyRemote then
			readyRemote:FireServer()
		end
		anim:HoldSwing(character, Combat.comboSwing(punchCfg, nextSide, now, lastPress))
	end

	-- A hold given up without a punch (stunned, caught, in a clash): the arm comes back.
	local function dropHold(character: Model?)
		if holdAt then
			holdAt = nil
			if character then
				anim:CancelSwing(character)
			end
		end
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

	-- Pressing draws the punch back; letting go throws it. A quick click is an ordinary punch. Held, the
	-- arm waits drawn back for as long as you like (it adds no power), so you can run in holding it and
	-- let go just before you reach them: the punch then lands after only Punch.ReleaseWindup. Pressed a
	-- moment too early, the press is remembered and the hold (or the tap) starts the moment it can. A
	-- press that can't punch tells the HUD it was blocked. A clash takes one tap per press.
	ContextActionService:BindAction(
		ACTION,
		function(_name: string, inputState: Enum.UserInputState, inputObject: InputObject)
			local now = os.clock()
			local character = player.Character
			if inputState == Enum.UserInputState.Begin then
				if character and character:GetAttribute("HT_Clash") then
					if clashTap then
						clashTap:FireServer()
					end
				elseif not character or not canPunch(character) then
					buffered = nil
					held, heldBy = true, inputObject.UserInputType
					self.PunchEvent:Fire("blocked")
				else
					held, heldBy = true, inputObject.UserInputType
					if holdAt then
						return Enum.ContextActionResult.Pass
					elseif now >= readyAt() then
						startHold(now, character)
					elseif Combat.pressBuffers(punchCfg, now, readyAt()) then
						buffered = now
					else
						self.PunchEvent:Fire("blocked")
					end
				end
			elseif
				inputState == Enum.UserInputState.End
				or inputState == Enum.UserInputState.Cancel
			then
				held, heldBy = false, nil
				if holdAt and character then
					if canPunch(character) then
						throw(now, character)
					else
						dropHold(character)
					end
				end
			end
			return Enum.ContextActionResult.Pass
		end,
		true,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle(ACTION, "Punch")

	-- THE HEAVY MOVES. Both are slow and telegraphed, root you through the windup, have their own cooldown
	-- and also count as a swing for the punch's.
	-- The uppercut: R (or L2). Throws them up and away in an arc, further the faster you were going.
	-- Nothing follows it.
	-- The launching kick: Space while holding punch (MovementController asks for it). Throws them straight
	-- up for an air kick.
	local heavies: { [string]: { cfg: any, remote: RemoteEvent?, last: number } } = {
		Kick = { cfg = kickCfg, remote = kickRemote, last = -math.huge },
		Uppercut = { cfg = upperCfg, remote = Net.client("UppercutRequest"), last = -math.huge },
		-- Tempest's attack skill: a spinning hook that reaches all the way round.
		Cyclone = {
			cfg = Abilities.Cyclone,
			remote = Net.client("CycloneRequest"),
			last = -math.huge,
		},
	}
	local function throwHeavy(side: string): boolean
		local move = heavies[side]
		local now = os.clock()
		local character = player.Character
		-- A punch being held back doesn't have to wait out the punch's cooldown again.
		if
			not character
			or not canPunch(character)
			or (holdAt == nil and now < readyAt())
			or now - move.last < move.cfg.Cooldown
			or not move.remote
		then
			self.PunchEvent:Fire("blocked")
			return false
		end
		-- The held punch becomes this instead, and the button has to be pressed again to hold another.
		holdAt = nil
		held, heldBy = false, nil
		buffered = nil
		move.last = now
		undoPress, undoSide = lastPress, nextSide
		lastPress = now
		recovery = 0
		endlag:Start(side, move.cfg.Windup + punchCfg.ActiveSeconds)
		anim:PlaySwing(character, side)
		fx:Swing(character, side, move.cfg.Windup)
		-- The launching kick roots you through its windup. The uppercut doesn't: you keep running.
		if move.cfg.Roots ~= false then
			movement:HeavyKickStarted(move.cfg.Windup + move.cfg.RootAfter)
		end
		move.remote:FireServer()
		self.PunchEvent:Fire("thrown")
		return true
	end
	self._throwKick = function(): boolean
		return throwHeavy("Kick")
	end
	-- For the HUD: when the uppercut can be thrown again, and whether the body can swing at all.
	self._uppercutTiming = function(): (number, number, boolean)
		return math.max(heavies.Uppercut.last + upperCfg.Cooldown, readyAt()),
			upperCfg.Cooldown,
			canPunch(player.Character)
	end
	-- The Uppercut skill (the Base kit's attack, R / L2). AbilityController owns the key.
	self._throwUppercut = function(): boolean
		return throwHeavy("Uppercut")
	end
	-- Any kit's attack skill that is a heavy swing ("Uppercut", "Cyclone"), and its timing for the HUD.
	self._throwSkill = function(side: string): boolean
		return heavies[side] ~= nil and side ~= "Kick" and throwHeavy(side)
	end
	self._skillTiming = function(side: string): (number, number, boolean)
		local move = heavies[side]
		if not move then
			return 0, 1, false
		end
		return math.max(move.last + move.cfg.Cooldown, readyAt()),
			move.cfg.Cooldown,
			canPunch(player.Character)
	end

	-- Anything that could swallow the release lets go: the window losing focus, and a new body.
	UserInputService.WindowFocusReleased:Connect(function()
		held, heldBy = false, nil
		dropHold(player.Character)
	end)
	player.CharacterAdded:Connect(function()
		buffered = nil
		holdAt = nil
		held, heldBy = false, nil
	end)

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

	-- Is the punch button down right now (drawn back, or waiting to be)? Space then kicks, not jumps.
	self._holding = function(): boolean
		return holdAt ~= nil or stillHeld()
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local character = player.Character
		if holdAt then
			if not character or not canPunch(character) then
				dropHold(character)
			elseif not stillHeld() or now - holdAt >= punchCfg.HoldMaxSeconds then
				-- Let go, or held as long as it can be (HoldMaxSeconds): it goes, and after a full hold
				-- the button has to be pressed again.
				held, heldBy = false, nil
				throw(now, character)
			end
			return
		end
		if buffered then
			if not Combat.bufferLive(punchCfg, now, buffered) or not canPunch(character) then
				buffered = nil
			elseif character and now >= readyAt() then
				buffered = nil
				if stillHeld() then
					startHold(now, character)
				else
					throw(now, character)
				end
			end
			return
		end
		-- Held from before a punch was possible (stunned, cooling down): the hold starts the moment it is.
		if held and stillHeld() and character and canPunch(character) and now >= readyAt() then
			startHold(now, character)
		elseif held and not stillHeld() then
			held, heldBy = false, nil
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
				elseif kind == "refused" then
					endlag:Undo()
					dropHold(player.Character)
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
			-- How long until theirs strikes, for its crescent: a heavy move's windup, the punch's, and
			-- the extra a bot's punch takes.
			local move = heavies[side]
			local windup = if move then move.cfg.Windup else punchCfg.Windup
			if attacker:GetAttribute("HT_Bot") or attacker:GetAttribute("HT_FillBot") then
				windup += GameConfig.TestBot.ExtraWindup
			end
			fx:Swing(attacker, side, windup)
		end
	end)

	confirmed.OnClientEvent:Connect(function(attacker: Model, target: Model, strength: number)
		if target and target.Parent then
			-- Shown the moment this client's swing reaches its Hit event, at the fist.
			anim:AtStrike(attacker, function()
				if target.Parent then
					-- An uppercut's arc leaves a trail behind the body it threw.
					if anim:LastSwing(attacker) == "Uppercut" then
						fx:LaunchTrail(target)
					end
					flash(target)
					anim:HitLanded(attacker, target, strength)
					fx:HitBurst(target, attacker, strength, anim:StrikeTip(attacker))
				end
			end)
		end
	end)

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

--- The Uppercut skill: throws the heavy uppercut if it can. False when it was turned down.
function CombatController:ThrowUppercut(): boolean
	if self._throwUppercut then
		return self._throwUppercut()
	end
	return false
end

--- A kit's attack skill that is a heavy swing, by its side ("Uppercut", "Cyclone"): throws it if it
--- can. False when it was turned down.
function CombatController:ThrowSkill(side: string): boolean
	return self._throwSkill ~= nil and self._throwSkill(side)
end

--- That skill's timing for the HUD: when it's ready, its whole cooldown, and whether the body can swing.
function CombatController:GetSkillTiming(side: string): (number, number, boolean)
	if self._skillTiming then
		return self._skillTiming(side)
	end
	return 0, 1, true
end

--- Is the punch button being held (a punch drawn back, or waiting to be)?
function CombatController:IsHolding(): boolean
	return self._holding ~= nil and self._holding()
end

--- The launching kick, for Space pressed while holding punch. False when it couldn't be thrown.
function CombatController:ThrowLaunchKick(): boolean
	return self._throwKick ~= nil and self._throwKick()
end

return CombatController
