--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local Clash = require("../src/shared/Core/Clash")
local GameConfig: any = require("../src/shared/Config/GameConfig")

local CFG: Clash.Settings = GameConfig.Clash

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.001
end

return {
	["two strikes inside the window are simultaneous, and outside it they aren't"] = function()
		assert(
			Clash.simultaneous(CFG, 10, 10 + CFG.Window * 0.99, 0, 0),
			"the edge of the window counts"
		)
		assert(
			not Clash.simultaneous(CFG, 10, 10 + CFG.Window + 0.01, 0, 0),
			"just past it doesn't"
		)
		assert(
			Clash.simultaneous(CFG, 10 + CFG.Window * 0.99, 10, 0, 0),
			"it doesn't matter whose comes first"
		)
	end,

	["ping widens the window a little, and never past its cap"] = function()
		assert(Clash.window(CFG, 0, 0) == CFG.Window, "no ping, no widening")
		local some = Clash.window(CFG, 0.04, 0.04)
		assert(near(some, CFG.Window + 0.02), `expected a quarter of the summed pings, got {some}`)
		assert(Clash.window(CFG, 2, 2) == CFG.Window + CFG.LatencyMax, "a huge ping hits the cap")
	end,

	["a punch only waits for a target whose press could still be on its way"] = function()
		local windup = 0.08
		assert(Clash.holdSeconds(CFG, windup, 0.05, 0.05) == 0, "equal pings never wait")
		assert(Clash.holdSeconds(CFG, windup, 0.2, 0) == 0, "a laggier attacker never waits")
		local wait = Clash.holdSeconds(CFG, windup, 0, 0.2)
		assert(
			near(wait, CFG.Window + 0.1 - windup),
			`expected the gap beyond the windup, got {wait}`
		)
		assert(Clash.holdSeconds(CFG, windup, 0, 5) == CFG.HoldMax, "the wait is capped")
	end,

	["taps are rate limited but survive a small network bunch"] = function()
		local bucket: Clash.TapBucket = { tokens = CFG.TapBurst, at = 0 }
		local counted = 0
		for _ = 1, 50 do
			if Clash.takeTap(CFG, bucket, 0) then
				counted += 1
			end
		end
		assert(counted == CFG.TapBurst, `a burst should give {CFG.TapBurst}, got {counted}`)
		-- A script firing every frame for three seconds can't beat the limit.
		counted = 0
		local now = 0
		for _ = 1, 180 do
			now += 1 / 60
			if Clash.takeTap(CFG, bucket, now) then
				counted += 1
			end
		end
		assert(counted <= CFG.MaxTapsPerSecond * 3 + 1, `{counted} taps in 3 s beats the limit`)
		assert(counted >= CFG.MaxTapsPerSecond * 3 - 1, `{counted} taps in 3 s drops honest ones`)
	end,

	["a real fast tapper never loses taps"] = function()
		local bucket: Clash.TapBucket = { tokens = CFG.TapBurst, at = 0 }
		local now = 0
		for _ = 1, 30 do
			now += 1 / 10
			assert(Clash.takeTap(CFG, bucket, now), "10 taps a second must all count")
		end
	end,

	["the contest starts even, and the bar follows who's ahead"] = function()
		assert(Clash.share(CFG, 0, 0) == 0.5, "it starts even")
		assert(Clash.share(CFG, 5, 2) > 0.5, "A ahead moves it toward A")
		assert(Clash.share(CFG, 2, 5) < 0.5, "B ahead moves it toward B")
		assert(Clash.share(CFG, CFG.WinLead, 0) == 1, "a winning lead fills it")
		assert(Clash.share(CFG, 0, CFG.WinLead * 2) == 0, "it never leaves the bar")
	end,

	["it ends early on a big lead, and otherwise at the time limit"] = function()
		assert(Clash.outcome(CFG, 3, 1, 0.5) == nil, "too early, too close")
		assert(Clash.outcome(CFG, CFG.WinLead, 0, 0.5) == "a", "a big lead wins at once")
		assert(Clash.outcome(CFG, 0, CFG.WinLead, 0.5) == "b", "for either side")
		assert(Clash.outcome(CFG, 12, 8, CFG.Seconds) == "a", "ahead at the end wins")
		assert(Clash.outcome(CFG, 8, 12, CFG.Seconds) == "b", "for either side")
	end,

	["two people mashing head-on clash sometimes, not always"] = function()
		-- Both mash at the cooldown, at every possible offset between them.
		local cooldown = GameConfig.Punch.Cooldown
		local clashes, total = 0, 0
		local offset = 0
		while offset < cooldown do
			total += 1
			-- The nearest pair of strikes in the two trains of punches.
			local gap = math.min(offset, cooldown - offset)
			if Clash.simultaneous(CFG, 0, gap, 0.08, 0.08) then
				clashes += 1
			end
			offset += 0.001
		end
		local share = clashes / total
		assert(share > 0.2, `head-on mashing should produce clashes, got {share}`)
		assert(share < 0.55, `mashing must not usually neutralise everything, got {share}`)
	end,

	["striking clearly first beats a masher, whenever they're pressing"] = function()
		-- Landing this much sooner is a clean hit, with no way for the masher to force a clash.
		local lead = CFG.Window + CFG.LatencyMax + 0.001
		for ping = 0, 0.3, 0.01 do
			assert(
				not Clash.simultaneous(CFG, 10, 10 + lead, ping, ping),
				`a {lead} s lead at {ping} ping must not clash`
			)
		end
	end,

	["baiting a whiff beats mashing: the punish lands well before they can swing again"] = function()
		local punch = GameConfig.Punch
		-- A human's slow reaction to seeing the whiff, then running 1.5 studs into reach at 30.
		local slowReaction = 0.25
		local punishStrikes = slowReaction + 1.5 / 30 + punch.Windup
		-- A whiff owes the cooldown and its recovery; the tolerance is only for network bunching.
		local nextStrike = punch.Cooldown + punch.MissRecovery + punch.Windup
		local margin = nextStrike - punishStrikes
		assert(
			margin > Clash.window(CFG, 0.1, 0.1),
			`the punish has to beat the clash window, margin {margin}`
		)
	end,

	["a clash can't last forever: level at the limit is a tie"] = function()
		assert(Clash.outcome(CFG, 10, 10, CFG.Seconds) == "tie", "level is a tie")
		assert(
			Clash.outcome(CFG, 10, 10 + CFG.TieMargin, CFG.Seconds) == "tie",
			"within the margin too"
		)
		assert(Clash.outcome(CFG, 0, 0, CFG.Seconds + 100) == "tie", "nobody tapping still ends")
	end,

	["nobody can win by tapping faster than the limit allows, however long they mash"] = function()
		-- The bucket's top rate against someone not tapping at all takes this long to win.
		local fastest = CFG.WinLead / CFG.MaxTapsPerSecond
		assert(fastest > 0.5, `a win in {fastest} s is too quick to read`)
		assert(fastest < CFG.Seconds, "a clear lead should be able to win before the limit")
	end,

	["the finishing punch is stronger than a standing one, and capped"] = function()
		assert(near(Clash.finishStrength(CFG, 55), 55 * CFG.FinishShare), "it scales up")
		assert(Clash.finishStrength(CFG, 137.5) == CFG.FinishMaxSpeed, "full stagger hits the cap")
	end,

	["they stand apart around their midpoint, facing each other"] = function()
		local ax, az, bx, bz, dirX, dirZ = Clash.stands(CFG, 0, 0, 6, 0, 0, -1)
		assert(near(dirX, 1) and near(dirZ, 0), "the line runs from A to B")
		assert(near(bx - ax, CFG.Standoff) and near(az, 0) and near(bz, 0), "the standoff apart")
		assert(near((ax + bx) / 2, 3), "around the midpoint")
	end,

	["standing exactly on top of each other still gives a sensible line"] = function()
		local ax, _, bx, _, dirX, dirZ = Clash.stands(CFG, 2, 2, 2, 2, 1, 0)
		assert(near(dirX, 1) and near(dirZ, 0), "A's facing decides the line")
		assert(near(bx - ax, CFG.Standoff), "they still end up the standoff apart")
		local _, _, _, _, x, z = Clash.stands(CFG, 2, 2, 2, 2, 0, 0)
		assert(near(x, 0) and near(z, -1), "with no facing at all there's a fixed fallback")
	end,

	["walking to the spot eases in, is capped, and stops close enough"] = function()
		assert(
			Clash.alignSpeed(CFG, CFG.AlignDeadband) == 0,
			"close enough stops, so it can't wobble"
		)
		assert(Clash.alignSpeed(CFG, 1) == CFG.AlignGain, "it slows down as it arrives")
		assert(Clash.alignSpeed(CFG, 100) == CFG.AlignSpeed, "and has a top speed")
		assert(CFG.AlignGain <= 8, "chasing the spot harder than this makes a Humanoid wobble")
	end,

	["one outside attacker can only be repelled so often"] = function()
		assert(Clash.repelReady(CFG, 10, nil), "the first is always allowed")
		assert(not Clash.repelReady(CFG, 10 + CFG.RepelCooldown / 2, 10), "too soon")
		assert(Clash.repelReady(CFG, 10 + CFG.RepelCooldown, 10), "after the cooldown")
	end,

	["a tie knocks both back with the same strength, a standing punch's, capped"] = function()
		local standing = 55
		local a = Clash.tieStrength(CFG, standing)
		local b = Clash.tieStrength(CFG, standing)
		assert(a == b, "the same for both")
		assert(near(a, math.min(standing * CFG.TieShare, CFG.FinishMaxSpeed)))
		assert(Clash.tieStrength(CFG, 1000) == CFG.FinishMaxSpeed, "capped like a finish")
	end,
}
