--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- Coins from rounds (user, 2026-11-13): hits, ring-outs and wins pay out when the round ends.
local Abilities = require("../src/shared/Config/Abilities")
local AbilityKit = require("../src/shared/Core/AbilityKit")
local Payout = require("../src/shared/Core/Payout")

local CFG: any = Abilities.RoundPay
local BOOK: any = Abilities

return {
	["someone who never landed a hit earns nothing, even the winner"] = function()
		local total, lines = Payout.forRound(CFG, { hits = 0, ringOuts = 0, won = true }, 8)
		assert(total == 0 and #lines == 0)
	end,

	["a round too small to count pays nothing"] = function()
		local total =
			Payout.forRound(CFG, { hits = 9, ringOuts = 1, won = true }, CFG.MinFighters - 1)
		assert(total == 0)
	end,

	["taking part, hits, ring-outs and the win all add up"] = function()
		local total, lines = Payout.forRound(CFG, { hits = 4, ringOuts = 2, won = true }, 6)
		assert(total == CFG.Played + 4 * CFG.PerHit + 2 * CFG.PerRingOut + CFG.Win)
		assert(#lines == 4)
		local sum = 0
		for _, line in lines do
			sum += line.coins
		end
		assert(sum == total, "the lines are the whole total")
		assert(lines[1].label == "Played" and lines[4].label == "Win")
	end,

	["hits stop paying at the cap"] = function()
		local capped = Payout.forRound(CFG, { hits = CFG.HitCap, ringOuts = 0, won = false }, 6)
		local over = Payout.forRound(CFG, { hits = CFG.HitCap + 500, ringOuts = 0, won = false }, 6)
		assert(capped == over)
		assert(over == CFG.Played + CFG.HitCap * CFG.PerHit)
	end,

	["a loser with hits is still paid, without the win"] = function()
		local total, lines = Payout.forRound(CFG, { hits = 1, ringOuts = 0, won = false }, 2)
		assert(total == CFG.Played + CFG.PerHit)
		assert(lines[2].label == "1 hit")
	end,

	["nonsense counts are nothing, never negative Coins"] = function()
		local total = Payout.forRound(CFG, { hits = 0 / 0, ringOuts = -4, won = false } :: any, 6)
		assert(total == 0)
		total = Payout.forRound(CFG, { hits = 3, ringOuts = -4, won = false }, 6)
		assert(total == CFG.Played + 3 * CFG.PerHit)
	end,

	["the line for the player says the total and its parts"] = function()
		local total, lines = Payout.forRound(CFG, { hits = 2, ringOuts = 1, won = false }, 6)
		local text = Payout.describe(total, lines)
		assert(string.find(text, `+{total} Coins`, 1, true))
		assert(string.find(text, "2 hits", 1, true) and string.find(text, "1 ring-out", 1, true))
	end,

	["Coins are added to a new profile, whole, and never past the limit"] = function()
		local profile = AbilityKit.newProfile(BOOK)
		local richer = AbilityKit.addCoins(profile, 42)
		assert(richer and richer.coins == profile.coins + 42)
		assert(
			richer ~= profile and profile.coins == BOOK.StarterCoins,
			"the old profile is unchanged"
		)
		assert(AbilityKit.addCoins(profile, 0) == nil, "nothing to add changes nothing")
		assert(AbilityKit.addCoins(profile, -5) == nil)
		assert(AbilityKit.addCoins(profile, 0 / 0) == nil)
		local half = AbilityKit.addCoins(profile, 2.9)
		assert(half and half.coins == profile.coins + 2)
		local most = AbilityKit.addCoins(profile, AbilityKit.MAX_COINS * 2)
		assert(most and most.coins == AbilityKit.MAX_COINS)
	end,
}
