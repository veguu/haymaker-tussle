--!strict
-- RosterLogic - the rules of the fighters' row at the top of the screen (Ui/Roster, 2026-11-18): how big a tile
-- may be, where each one stands, and who wears the crown. Pure: no instances.

local RosterLogic = {}

--- The tile's side for `count` fighters in a row `room` wide: as big as fits, never over `maxTile` or under
--- `minTile` (a row that still does not fit at `minTile` simply runs wider: it is centred, so it loses its two
--- ends evenly). Returns the side and the step from one tile's centre to the next.
function RosterLogic.fit(
	count: number,
	room: number,
	maxTile: number,
	minTile: number,
	gap: number
): (number, number)
	if count <= 0 then
		return maxTile, maxTile + gap
	end
	local side = math.floor((room + gap) / count - gap)
	side = math.clamp(side, minTile, maxTile)
	return side, side + gap
end

--- Where the centre of tile `index` of `count` stands, from the row's own centre.
function RosterLogic.slot(index: number, count: number, step: number): number
	return (index - (count + 1) / 2) * step
end

--- Who wears the crown: the fighter in `order` with the most ring-outs, at least one. Two with the same number:
--- whoever got there first (`since` is when each reached the number they have; smaller is earlier).
function RosterLogic.leader(
	order: { any },
	kills: { [any]: number },
	since: { [any]: number }
): any?
	local best: any? = nil
	local bestKills, bestSince = 0, math.huge
	for _, id in order do
		local count = kills[id] or 0
		local at = since[id] or math.huge
		if count > bestKills or (count == bestKills and count > 0 and at < bestSince) then
			best, bestKills, bestSince = id, count, at
		end
	end
	return best
end

--- One frame of an eased move from `current` toward `target`: it covers the same share of what is left in the
--- same time whatever the frame rate, and lands exactly once it is within `near`.
function RosterLogic.approach(
	current: number,
	target: number,
	dt: number,
	rate: number,
	near: number
): number
	local left = target - current
	if math.abs(left) <= near then
		return target
	end
	return current + left * (1 - math.exp(-rate * math.max(dt, 0)))
end

--- One frame of a move on a critically damped spring: it sets off gently, gathers speed, slows into its place
--- and never overshoots, and a target that changes mid-move only bends it (the speed carries over). `omega` is
--- how stiff it is: it is within a hundredth of the way after about 6.6 / omega seconds. Returns the new place
--- and speed; within `near` of the target and nearly still, it is there.
function RosterLogic.spring(
	current: number,
	speed: number,
	target: number,
	dt: number,
	omega: number,
	near: number
): (number, number)
	local off = current - target
	if math.abs(off) <= near and math.abs(speed) <= near * omega then
		return target, 0
	end
	local step = math.max(dt, 0)
	local decay = math.exp(-omega * step)
	local carry = speed + omega * off
	return target + (off + carry * step) * decay, (speed - omega * carry * step) * decay
end

return RosterLogic
