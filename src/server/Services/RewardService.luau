--!strict
-- RewardService - Coins from rounds. RoundService tells it what happens (a round starting, a hit
-- between two fighters still in it, a ring-out credited to someone, the round ending); this keeps
-- each fighter's tally and, when the round ends, pays every player who started it. The sums are
-- Core/Payout's on Config/Abilities.RoundPay; the Coins go into the profile PlayerDataService saves.
--
-- Nothing here comes from a client: every count is the server's own.
--
-- CoinsEarned(total, lines) goes to each paid player: the total and its parts ({ label, coins }).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityKit = require(ReplicatedStorage.Shared.Core.AbilityKit)
local Payout = require(ReplicatedStorage.Shared.Core.Payout)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local payCfg: any = Abilities.RoundPay

local RewardService = Knit.CreateService({
	Name = "RewardService",
})

-- This round's fighters and what each has done. Empty between rounds.
local tallies: { [Model]: Payout.Tally } = {}
local fighters = 0

local function trace(message: string)
	if workspace:GetAttribute("HaymakerRoundDebug") then
		print(`[Reward] {message}`)
	end
end

--- A round is starting with these fighters. Whatever was left of the last one is dropped.
function RewardService:RoundStarted(roster: { [Model]: any })
	table.clear(tallies)
	fighters = 0
	for model in roster do
		tallies[model] = Payout.newTally()
		fighters += 1
	end
end

--- A fighter in the round landed a hit on another one in it.
function RewardService:Hit(by: Model)
	local tally = tallies[by]
	if tally then
		tally.hits += 1
	end
end

--- A ring-out was credited to this fighter.
function RewardService:RingOut(by: Model)
	local tally = tallies[by]
	if tally then
		tally.ringOuts += 1
	end
end

--- The round is over (`winner` nil: nobody won). Pays every player who started it, then forgets it.
--- A player who left is skipped: their profile has already been saved and let go.
function RewardService:RoundEnded(winner: Model?)
	local data = Knit.GetService("PlayerDataService")
	for model, tally in tallies do
		tally.won = model == winner
		local player = Combatants.playerOf(model)
		if not player or player.Parent == nil then
			continue
		end
		local total, lines = Payout.forRound(payCfg, tally, fighters)
		if total <= 0 then
			continue
		end
		local paid = data:Update(player, function(profile)
			return AbilityKit.addCoins(profile, total)
		end)
		if paid then
			trace(`{player.Name} paid {total} ({tally.hits} hits, {tally.ringOuts} ring-outs)`)
			self._earned:FireClient(player, total, lines)
		end
	end
	table.clear(tallies)
	fighters = 0
end

function RewardService:KnitInit()
	self._earned = Net.server("CoinsEarned")
end

return RewardService
