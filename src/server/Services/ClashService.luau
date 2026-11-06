--!strict
-- ClashService - owns a clash once CombatService has found one. The two are drawn together and hold
-- there, trading a barrage of punches that's only for show, while each tap of punch scores. The server
-- counts every tap and decides the result. One finishing punch lands, once, through the normal stagger
-- and knockback rules. Clients only ever say "I tapped".
--
-- A clash is protection from outside attacks, never from the game: dying, leaving, falling out of play
-- and a round ending all still end it at once. See EndFor.
--
-- The attributes on a clashing character: HT_Clash, HT_ClashAt (where to stand), HT_ClashFace (which
-- way to look), HT_ClashScore.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Clash = require(ReplicatedStorage.Shared.Core.Clash)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg = GameConfig.Clash
local punchCfg = GameConfig.Punch
local knockCfg = GameConfig.Knockback
local staggerCfg = GameConfig.Stagger
local arena = GameConfig.Arena
local FLOOR_REACH = 4.5 -- from the root part, a little past the feet
local LEFT_POST_STUDS = 25 -- further than this from their spot, something else moved them

type Running = {
	a: Model,
	b: Model,
	scoreA: number,
	scoreB: number,
	startedAt: number,
	bucketA: Clash.TapBucket,
	bucketB: Clash.TapBucket,
	winner: Model?,
	finishAt: number?,
}

local ClashService = Knit.CreateService({
	Name = "ClashService",
})

local clashes: { Running } = {}
local byModel: { [Model]: Running } = {}
local pairTimes: { [Model]: { [Model]: number } } = setmetatable({}, { __mode = "k" }) :: any
local lastRepel: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function trace(message: string)
	if workspace:GetAttribute("HaymakerCombatDebug") then
		print(`[Combat] {message}`)
	end
end

local function floorUnder(position: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Combatants.TAG)
	return workspace:Raycast(position, Vector3.new(0, -FLOOR_REACH, 0), params) ~= nil
end

local function clearMarks(model: Model)
	model:SetAttribute("HT_Clash", nil)
	model:SetAttribute("HT_ClashAt", nil)
	model:SetAttribute("HT_ClashFace", nil)
	model:SetAttribute("HT_ClashScore", nil)
end

local function drop(clash: Running)
	local index = table.find(clashes, clash)
	if index then
		table.remove(clashes, index)
	end
	if byModel[clash.a] == clash then
		byModel[clash.a] = nil
	end
	if byModel[clash.b] == clash then
		byModel[clash.b] = nil
	end
	clearMarks(clash.a)
	clearMarks(clash.b)
	local now = os.clock()
	pairTimes[clash.a] = pairTimes[clash.a] or {}
	pairTimes[clash.a][clash.b] = now
	pairTimes[clash.b] = pairTimes[clash.b] or {}
	pairTimes[clash.b][clash.a] = now
	local combat = Knit.GetService("CombatService")
	combat:PunchLockout(clash.a)
	combat:PunchLockout(clash.b)
end

--- Is this fighter in a clash, including the moment the winner's finishing punch is on its way?
function ClashService:IsIn(model: Model): boolean
	return byModel[model] ~= nil
end

--- May these two clash at all, leaving aside whether their punches line up?
function ClashService:CanPair(a: Model, b: Model): boolean
	if not cfg.Enabled or byModel[a] or byModel[b] then
		return false
	end
	local last = pairTimes[a] and pairTimes[a][b]
	if last and os.clock() - last < cfg.PairCooldown then
		return false
	end
	local kicks = Knit.GetService("KickService")
	if kicks:IsBusy(a) or kicks:IsBusy(b) then
		return false
	end
	local rootA, rootB = Combatants.rootOf(a), Combatants.rootOf(b)
	return rootA ~= nil
		and rootB ~= nil
		and floorUnder(rootA.Position)
		and floorUnder(rootB.Position)
end

--- Starts a clash. CombatService has already decided the two punches qualify, and ended them.
function ClashService:Begin(a: Model, b: Model)
	local rootA, rootB = Combatants.rootOf(a), Combatants.rootOf(b)
	if not rootA or not rootB then
		return
	end
	local posA, posB = rootA.Position, rootB.Position
	local look = rootA.CFrame.LookVector
	local standAX, standAZ, standBX, standBZ, dirX, dirZ =
		Clash.stands(cfg, posA.X, posA.Z, posB.X, posB.Z, look.X, look.Z)
	local atA = Vector3.new(standAX, posA.Y, standAZ)
	local atB = Vector3.new(standBX, posB.Y, standBZ)
	-- Near an edge the spots might have no floor. Better to stay put than to be walked off it.
	if not floorUnder(atA) or not floorUnder(atB) then
		atA, atB = posA, posB
	end
	local face = Vector3.new(dirX, 0, dirZ)
	local now = os.clock()
	local clash: Running = {
		a = a,
		b = b,
		scoreA = 0,
		scoreB = 0,
		startedAt = now,
		bucketA = { tokens = cfg.TapBurst, at = now },
		bucketB = { tokens = cfg.TapBurst, at = now },
	}
	table.insert(clashes, clash)
	byModel[a] = clash
	byModel[b] = clash
	a:SetAttribute("HT_Clash", true)
	b:SetAttribute("HT_Clash", true)
	a:SetAttribute("HT_ClashAt", atA)
	b:SetAttribute("HT_ClashAt", atB)
	a:SetAttribute("HT_ClashFace", face)
	b:SetAttribute("HT_ClashFace", -face)
	a:SetAttribute("HT_ClashScore", 0)
	b:SetAttribute("HT_ClashScore", 0)
	self._started:FireAllClients(a, b, cfg.Seconds)
	trace(`clash begins: {a.Name} and {b.Name}`)
end

local function score(clash: Running, model: Model)
	if clash.winner then
		return
	end
	if model == clash.a then
		clash.scoreA += 1
		model:SetAttribute("HT_ClashScore", clash.scoreA)
	else
		clash.scoreB += 1
		model:SetAttribute("HT_ClashScore", clash.scoreB)
	end
end

local function endWithoutWinner(self: any, clash: Running, reason: string)
	self._ended:FireAllClients(clash.a, clash.b, nil, reason, clash.scoreA, clash.scoreB)
	drop(clash)
	trace(`clash over: {reason}, {clash.scoreA} to {clash.scoreB}`)
end

-- A tie: nobody wins, and both are pushed away from each other.
local function tie(self: any, clash: Running)
	local rootA, rootB = Combatants.rootOf(clash.a), Combatants.rootOf(clash.b)
	endWithoutWinner(self, clash, "tie")
	if rootA and rootB then
		local line =
			Vector3.new(rootB.Position.X - rootA.Position.X, 0, rootB.Position.Z - rootA.Position.Z)
		local dir = if line.Magnitude > 0.01 then line.Unit else rootA.CFrame.LookVector
		local knockback = Knit.GetService("KnockbackService")
		knockback:Launch(clash.a, -dir.X * cfg.TiePush, -dir.Z * cfg.TiePush, 0, 0, 0)
		knockback:Launch(clash.b, dir.X * cfg.TiePush, dir.Z * cfg.TiePush, 0, 0, 0)
	end
end

-- The winner's finishing punch lands. This runs once, and only ever from the tick that ends the clash.
local function landFinish(clash: Running)
	local winner = clash.winner :: Model
	local loser = if winner == clash.a then clash.b else clash.a
	drop(clash)
	local rootW, rootL = Combatants.rootOf(winner), Combatants.rootOf(loser)
	if
		not rootW
		or not rootL
		or not Combatants.isAlive(winner)
		or not Combatants.isAlive(loser)
	then
		return
	end
	local stagger = Knit.GetService("StaggerService")
	local knockback = Knit.GetService("KnockbackService")
	local combat = Knit.GetService("CombatService")
	local before = stagger:Get(loser)
	local strength =
		Clash.finishStrength(cfg, Combat.punchStrength(knockCfg, staggerCfg, 0, before))
	stagger:AddAmount(loser, cfg.FinishStagger)
	stagger:Relieve(winner)
	combat:MarkHit(loser)
	local line =
		Vector3.new(rootL.Position.X - rootW.Position.X, 0, rootL.Position.Z - rootW.Position.Z)
	local away = if line.Magnitude > 0.01 then line.Unit else rootW.CFrame.LookVector
	local up, airUp = Combat.upwardSpeeds(knockCfg, strength)
	knockback:Launch(loser, away.X * strength, away.Z * strength, up, airUp)
	local pushX, pushZ, keep = Combat.punchAftermath(punchCfg, 1, away.X, away.Z, away.X, away.Z)
	knockback:Launch(winner, pushX, pushZ, 0, 0, keep)
	combat:ConfirmHit(winner, loser, strength)
	trace(`clash finish: {winner.Name} hits {loser.Name}, strength {math.floor(strength)}`)
end

--- Ends any clash this fighter is in, with no winner and no knockback. For anything outside the fight
--- that has to take over: a round ending, a teleport, being removed.
function ClashService:EndFor(model: Model, reason: string?)
	local clash = byModel[model]
	if clash then
		endWithoutWinner(self, clash, reason or "cancelled")
	end
end

--- Ends every clash, for a round ending.
function ClashService:EndAll(reason: string?)
	for _, clash in table.clone(clashes) do
		endWithoutWinner(self, clash, reason or "cancelled")
	end
end

--- An outside attacker's validated punch reached someone in a clash. It has none of its normal effect:
--- the attacker is knocked back, once per cooldown, and nothing else changes. No stagger on anyone, no
--- stagger relief, and it never counts as a hit. Returns true if it pushed them.
function ClashService:Repel(attacker: Model, target: Model): boolean
	local now = os.clock()
	if not Clash.repelReady(cfg, now, lastRepel[attacker]) then
		return false
	end
	local rootA, rootT = Combatants.rootOf(attacker), Combatants.rootOf(target)
	if not rootA or not rootT then
		return false
	end
	lastRepel[attacker] = now
	local line =
		Vector3.new(rootA.Position.X - rootT.Position.X, 0, rootA.Position.Z - rootT.Position.Z)
	local away = if line.Magnitude > 0.01 then line.Unit else -rootA.CFrame.LookVector
	Knit.GetService("KnockbackService")
		:Launch(attacker, away.X * cfg.RepelSpeed, away.Z * cfg.RepelSpeed, 0, 0, 0)
	self._repelled:FireAllClients(attacker, target)
	trace(`{attacker.Name} repelled by the clash on {target.Name}`)
	return true
end

local function fighterGone(model: Model): string?
	local root = Combatants.rootOf(model)
	if model.Parent == nil or not root or not Combatants.isAlive(model) then
		return "gone"
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player and not model:IsDescendantOf(workspace) then
		return "gone"
	end
	if root.Position.Y < arena.CenterY - arena.EliminationDepth then
		return "fell"
	end
	local post = model:GetAttribute("HT_ClashAt") :: Vector3?
	if post and (root.Position - post).Magnitude > LEFT_POST_STUDS then
		return "moved"
	end
	return nil
end

local function tick(self: any, clash: Running, now: number)
	local why = fighterGone(clash.a) or fighterGone(clash.b)
	if why then
		endWithoutWinner(self, clash, why)
		return
	end
	if clash.finishAt then
		if now >= clash.finishAt then
			landFinish(clash)
		end
		return
	end
	local result = Clash.outcome(cfg, clash.scoreA, clash.scoreB, now - clash.startedAt)
	if result == "tie" then
		tie(self, clash)
	elseif result then
		clash.winner = if result == "a" then clash.a else clash.b
		clash.finishAt = now + punchCfg.Windup
		self._ended:FireAllClients(
			clash.a,
			clash.b,
			clash.winner,
			"win",
			clash.scoreA,
			clash.scoreB
		)
		trace(`clash won by {(clash.winner :: Model).Name}, {clash.scoreA} to {clash.scoreB}`)
	end
end

function ClashService:KnitInit()
	self._started = Net.server("ClashStarted")
	self._ended = Net.server("ClashEnded")
	self._repelled = Net.server("ClashRepelled")
	self._tap = Net.server("ClashTap")
end

function ClashService:KnitStart()
	self._tap.OnServerEvent:Connect(function(player: Player, ...)
		-- A real client sends no arguments at all.
		if select("#", ...) ~= 0 then
			return
		end
		local model = player.Character
		local clash = model and byModel[model]
		if not model or not clash or clash.winner then
			return
		end
		local bucket = if model == clash.a then clash.bucketA else clash.bucketB
		if Clash.takeTap(cfg, bucket, os.clock()) then
			score(clash, model)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if #clashes > 0 then
			local now = os.clock()
			for _, clash in table.clone(clashes) do
				tick(self, clash, now)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			self:EndFor(player.Character, "gone")
		end
	end)
end

return ClashService