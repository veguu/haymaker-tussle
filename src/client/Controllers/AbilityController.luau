--!strict
-- AbilityController - the two ability keys and the kit behind them. Q (gamepad B) is the equipped
-- kit's MOBILITY skill, R (gamepad L2) its ATTACK skill; see Config/Abilities. A press goes to that
-- skill's handler below. A skill with no handler yet (a placeholder kit) says so instead.
--
-- The server owns which kit you wear (player attributes HT_Kit, HT_OwnedKits, HT_Coins, written by
-- PlayerDataService); this only reads them, and asks to buy or equip through AbilityService.
--
-- The action names stay "HaymakerPropel" and "HaymakerUppercut": the HUD draws its cooldowns on the
-- touch buttons by those names.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityKit = require(ReplicatedStorage.Shared.Core.AbilityKit)
local Blink = require(ReplicatedStorage.Shared.Core.Blink)
local Payout = require(ReplicatedStorage.Shared.Core.Payout)
local Net = require(ReplicatedStorage.Shared.Net)

local book: any = Abilities

local SLOT_ACTIONS = {
	mobility = "HaymakerPropel",
	attack = "HaymakerUppercut",
}

-- What each reason from the server means, for the notice.
local REASONS = {
	unknown = "That kit doesn't exist.",
	owned = "You already own that kit.",
	coins = "Not enough Coins.",
	notOwned = "Buy that kit first.",
	equipped = "You're already wearing that kit.",
	inRound = "You can't change kit during a round.",
	loading = "Your data is still loading.",
	busy = "Slow down a little.",
}

local AbilityController = Knit.CreateController({
	Name = "AbilityController",
	-- (kitId) when the equipped kit changes, or first arrives.
	KitChanged = Signal.new(),
	-- () when Coins or owned kits change.
	InventoryChanged = Signal.new(),
	-- (text, good) a short message for the player: a buy went through, a placeholder skill, a refusal.
	Notice = Signal.new(),
	-- (slot) a kit skill that isn't the Base kit's went, or its press was turned down. For the HUD.
	SkillUsed = Signal.new(),
	SkillBlocked = Signal.new(),
})

local blinkCfg: any = Abilities.Blink
local lastBlink = -math.huge
local blinkRemote: RemoteEvent? = nil

-- The states nothing can be started from: stunned, caught by a kick or mid-kick, in a clash, held for
-- a round's countdown, spectating.
local function canAct(character: Model): boolean
	return character:GetAttribute("HT_Stunned") == nil
		and character:GetAttribute("HT_Air") ~= "hold"
		and character:GetAttribute("HT_Clash") == nil
		and character:GetAttribute("HT_RoundHold") == nil
		and character:GetAttribute("HT_Skill") == nil
		and character:GetAttribute("HT_Spectating") == nil
end

-- Blink: this client moves its own body (as it does for the dash), then tells the server, which shows
-- everyone else. It goes the way you're moving, through other fighters, and stops short of anything
-- solid at chest or knee height.
local function blink(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	if
		not character
		or not root
		or not root:IsA("BasePart")
		or not canAct(character)
		or not Blink.ready(blinkCfg, now, lastBlink)
	then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	local look = root.CFrame.LookVector
	local dirX, dirZ = Blink.direction(blinkCfg, velocity.X, velocity.Z, look.X, look.Z)
	if not dirX or not dirZ then
		return false
	end
	local direction = Vector3.new(dirX, 0, dirZ)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged("HT_Combatant")
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local reach = direction * (blinkCfg.Distance + blinkCfg.WallGap)
	local wall: number? = nil
	for _, drop in { 0, 1.6 } do
		local hit = workspace:Raycast(root.Position - Vector3.yAxis * drop, reach, params)
		if hit and (wall == nil or hit.Distance < wall) then
			wall = hit.Distance
		end
	end
	local travel = Blink.travel(blinkCfg, wall)
	if travel < 1 then
		return false
	end
	lastBlink = now
	local from = root.Position
	root.CFrame += direction * travel
	Knit.GetController("FxController"):Blink(character, from, root.Position)
	if blinkRemote then
		blinkRemote:FireServer()
	end
	return true
end

-- Each built skill's press. Returns whether it went (false: turned down). Add a new skill here, then
-- mark it built. A skill that isn't the Base kit's also needs a line in TIMINGS for the HUD.
local HANDLERS: { [string]: () -> boolean } = {
	Dash = function()
		return Knit.GetController("MovementController"):RequestDash()
	end,
	Uppercut = function()
		return Knit.GetController("CombatController"):ThrowUppercut()
	end,
	Blink = blink,
	Cyclone = function()
		return Knit.GetController("CombatController"):ThrowSkill("Cyclone")
	end,
}

-- Each skill's timing for the HUD: when it's ready (os.clock()), its whole cooldown, and whether the
-- body could use it right now. The Dash and the Uppercut have their own in the HUD already.
local TIMINGS: { [string]: () -> (number, number, boolean) } = {
	Blink = function()
		local character = Players.LocalPlayer.Character
		return lastBlink + blinkCfg.Cooldown,
			blinkCfg.Cooldown,
			character ~= nil and canAct(character)
	end,
	Cyclone = function()
		return Knit.GetController("CombatController"):GetSkillTiming("Cyclone")
	end,
}

--- The kit you're wearing, by id.
function AbilityController:GetKitId(): string
	local kitId = Players.LocalPlayer:GetAttribute("HT_Kit")
	return if typeof(kitId) == "string" and book.Kits[kitId] then kitId else book.DefaultKit
end

--- The skill a slot ("mobility" or "attack") gives with the kit you're wearing.
function AbilityController:GetSkill(slot: string): AbilityKit.Skill
	return AbilityKit.skill(book, self:GetKitId(), slot)
end

--- Your Coins.
function AbilityController:GetCoins(): number
	local coins = Players.LocalPlayer:GetAttribute("HT_Coins")
	return if typeof(coins) == "number" then coins else 0
end

--- The kits you own, as a set of ids.
function AbilityController:GetOwned(): { [string]: boolean }
	local owned = AbilityKit.decodeOwned(book, Players.LocalPlayer:GetAttribute("HT_OwnedKits"))
	owned[book.DefaultKit] = true
	return owned
end

--- True once the server has your profile; false while it loads.
function AbilityController:IsReady(): boolean
	return Players.LocalPlayer:GetAttribute("HT_DataReady") == true
end

--- True when your progress won't be saved this session (no DataStore access, or it failed to load).
function AbilityController:IsTemporary(): boolean
	return Players.LocalPlayer:GetAttribute("HT_DataTemp") == true
end

--- Asks the server to buy a kit. The answer comes back as a Notice.
function AbilityController:Buy(kitId: string)
	if self._buy then
		self._buy:FireServer(kitId)
	end
end

--- Asks the server to equip an owned kit. The answer comes back as a Notice.
function AbilityController:Equip(kitId: string)
	if self._equip then
		self._equip:FireServer(kitId)
	end
end

--- Presses a slot's skill, as its key does. For on-screen buttons and tests.
function AbilityController:Use(slot: string): boolean
	local skill = self:GetSkill(slot)
	local handler = if skill.built then HANDLERS[skill.id] else nil
	if not handler then
		self.Notice:Fire(`{skill.name} isn't built yet.`, false)
		return false
	end
	-- Still recovering from the last move (Core/Endlag): a mobility skill doesn't start. (Attack
	-- skills are swings, and CombatController holds those back itself.)
	local endlag = Knit.GetController("EndlagController")
	if slot == "mobility" and endlag:IsBusy() then
		self.SkillBlocked:Fire(slot)
		return false
	end
	local went = handler()
	if went and skill.id == "Blink" then
		endlag:Start("Blink")
	end
	-- The Base kit's skills tell the HUD themselves (MovementController, CombatController).
	if TIMINGS[skill.id] then
		(if went then self.SkillUsed else self.SkillBlocked):Fire(slot)
	end
	return went
end

--- A slot's timing for the HUD, for skills that aren't the Base kit's: when it's ready (os.clock()),
--- its whole cooldown, and whether it can be used right now. Nil for the Dash, the Uppercut and
--- skills that aren't built.
function AbilityController:GetTiming(slot: string): (number?, number?, boolean?)
	local timing = TIMINGS[self:GetSkill(slot).id]
	if timing then
		return timing()
	end
	return nil, nil, nil
end

function AbilityController:KnitStart()
	local player = Players.LocalPlayer
	self._buy = Net.client("AbilityBuy")
	self._equip = Net.client("AbilityEquip")
	local result = Net.client("AbilityResult")
	blinkRemote = Net.client("BlinkRequest")
	local blinkStarted = Net.client("BlinkStarted")
	if blinkStarted then
		-- Someone else's blink: only where they left from is known here; the effect finds the arrival.
		blinkStarted.OnClientEvent:Connect(function(character: any)
			if typeof(character) ~= "Instance" or not character:IsA("Model") then
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				Knit.GetController("FxController"):Blink(character, root.Position)
			end
		end)
	end
	player.CharacterAdded:Connect(function()
		lastBlink = -math.huge
	end)
	-- What the round just paid, as a notice. The Coins themselves arrive as the HT_Coins attribute.
	local earned = Net.client("CoinsEarned")
	if earned then
		earned.OnClientEvent:Connect(function(total: any, lines: any)
			if typeof(total) == "number" and typeof(lines) == "table" then
				self.Notice:Fire(Payout.describe(total, lines), true)
			end
		end)
	end

	-- Q / B: mobility. High priority and sunk, as the dash always was, so nothing under it also fires.
	ContextActionService:BindActionAtPriority(
		SLOT_ACTIONS.mobility,
		function(_name: string, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				self:Use("mobility")
			end
			return Enum.ContextActionResult.Sink
		end,
		true,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonB
	)
	-- R / L2: attack.
	ContextActionService:BindAction(
		SLOT_ACTIONS.attack,
		function(_name: string, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				self:Use("attack")
			end
			return Enum.ContextActionResult.Pass
		end,
		true,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonL2
	)

	-- Touch buttons are titled with the skill they fire.
	local function titles()
		ContextActionService:SetTitle(SLOT_ACTIONS.mobility, self:GetSkill("mobility").name)
		ContextActionService:SetTitle(SLOT_ACTIONS.attack, self:GetSkill("attack").name)
	end
	local shownKit = ""
	local function kitChanged()
		local kitId = self:GetKitId()
		if kitId ~= shownKit then
			shownKit = kitId
			titles()
			self.KitChanged:Fire(kitId)
		end
	end
	player:GetAttributeChangedSignal("HT_Kit"):Connect(kitChanged)
	for _, name in { "HT_Coins", "HT_OwnedKits", "HT_DataReady", "HT_DataTemp" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			self.InventoryChanged:Fire()
		end)
	end
	kitChanged()

	if result then
		result.OnClientEvent:Connect(function(action: any, kitId: any, reason: any)
			local kit = AbilityKit.kit(book, kitId)
			local name = if kit then kit.name else "That kit"
			if reason == "ok" then
				self.Notice:Fire(
					if action == "buy"
						then `Bought {name}. Equip it in Abilities.`
						else `{name} equipped.`,
					true
				)
			else
				self.Notice:Fire((REASONS :: any)[reason] or "That didn't work.", false)
			end
		end)
	end
end

return AbilityController
