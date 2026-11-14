--!strict
-- Payout - what a round pays in Coins, as plain maths with no Roblox instances. The numbers are
-- Config/Abilities.RoundPay; RewardService counts what happened and pays it out.

local Payout = {}

export type Settings = {
	Played: number,
	PerHit: number,
	HitCap: number,
	PerRingOut: number,
	Win: number,
	MinFighters: number,
}

-- What one fighter did in a round.
export type Tally = {
	hits: number,
	ringOuts: number,
	won: boolean,
}

export type Line = { label: string, coins: number }

local function count(n: any): number
	if typeof(n) ~= "number" or n ~= n or n < 0 then
		return 0
	end
	return math.floor(math.min(n, 1e6))
end

--- A fighter with nothing to their name yet.
function Payout.newTally(): Tally
	return { hits = 0, ringOuts = 0, won = false }
end

--- What a round pays this fighter: the total, and each part of it that isn't zero, in the order
--- Played, Hits, Ring-outs, Win. `fighters` is how many started the round. Nothing at all for a round
--- too small to count, or for someone who never landed a hit.
function Payout.forRound(cfg: Settings, tally: Tally, fighters: number): (number, { Line })
	local lines: { Line } = {}
	local hits = count(tally.hits)
	if count(fighters) < cfg.MinFighters or hits == 0 then
		return 0, lines
	end
	local total = 0
	local function add(label: string, coins: number)
		if coins > 0 then
			total += coins
			table.insert(lines, { label = label, coins = coins })
		end
	end
	add("Played", cfg.Played)
	local paidHits = math.min(hits, cfg.HitCap)
	add(if paidHits == 1 then "1 hit" else `{paidHits} hits`, paidHits * cfg.PerHit)
	local ringOuts = count(tally.ringOuts)
	add(if ringOuts == 1 then "1 ring-out" else `{ringOuts} ring-outs`, ringOuts * cfg.PerRingOut)
	if tally.won == true then
		add("Win", cfg.Win)
	end
	return total, lines
end

--- The payout as one short line for the player: "+47 Coins: Played 5, 12 hits 12, Win 30".
function Payout.describe(total: number, lines: { Line }): string
	local parts = {}
	for _, line in lines do
		table.insert(parts, `{line.label} {line.coins}`)
	end
	return `+{total} Coins: {table.concat(parts, ", ")}`
end

return Payout
