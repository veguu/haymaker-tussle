--!strict
-- MapMotion - the pure rules for a map's moving scenery (Shared/MapExtras moves the parts; a map's `spinners` in
-- Config/MapEnvironments). Each mover turns its parts about a hub on an axis, and may lift them:
--   * spin (the default): turns steadily, `rpm` turns a minute (Map 1's windmill sails).
--   * swing: turns back and forth, `amp` degrees each way, one full swing every `period` seconds (Map 2's derrick
--     boom round its mast).
--   * bob: rises and falls `amp` studs, one full bob every `period` seconds, and rocks `tilt` degrees about the axis
--     a quarter-cycle behind the rise (Map 3's kite on its tether).
-- `clock` is the mover's own time in seconds: MapExtras advances it (advance) slower for Reduced Motion, so nothing
-- ever snaps.
-- Not the same as a preset's `scenery.bob` rules (EnvironmentKit: floating props rise and sway along the wind, by
-- name pattern, no turning): use a mover here when parts must turn or rock about an axis as one assembly.
-- Specs: tests/MapMotion.spec.luau.

local MapMotion = {}

export type Mover = {
	mode: string?, -- "spin" (nil), "swing" or "bob"
	parts: { string }?,
	hub: { number }?,
	axis: { number }?,
	rpm: number?, -- spin
	amp: number?, -- swing: degrees each way; bob: studs up and down
	period: number?, -- swing and bob: seconds a full cycle
	tilt: number?, -- bob: degrees of rocking about the axis
	phase: number?, -- swing and bob: where in the cycle it starts, 0 to 1
}

MapMotion.MODES = { spin = true, swing = true, bob = true }
MapMotion.REDUCED = 1 / 3 -- how fast movers run with Reduced Motion on

--- The movers' clock after a frame at time `t` (`last` = the previous frame's time, nil on the first): it runs at
--- REDUCED speed while Reduced Motion is on, and a hitch of more than a quarter second counts as a quarter second.
function MapMotion.advance(clock: number, last: number?, t: number, reduced: boolean): number
	local dt = if last then math.clamp(t - last, 0, 0.25) else 0
	return clock + dt * (if reduced then MapMotion.REDUCED else 1)
end

--- The mover's pose at `clock`: the turn about its axis in radians, and its rise in studs.
function MapMotion.pose(m: Mover, clock: number): (number, number)
	local mode = m.mode or "spin"
	if mode == "spin" then
		return clock * (m.rpm or 0) / 60 * 2 * math.pi, 0
	end
	local cycle = 2 * math.pi * (clock / math.max(m.period or 1, 0.1) + (m.phase or 0))
	if mode == "swing" then
		return math.rad(m.amp or 0) * math.sin(cycle), 0
	elseif mode == "bob" then
		return math.rad(m.tilt or 0) * math.sin(cycle - math.pi / 2), (m.amp or 0) * math.sin(cycle)
	end
	return 0, 0
end

local function vector(v: any, n: number): boolean
	if type(v) ~= "table" or #v ~= n then
		return false
	end
	for _, x in v do
		if type(x) ~= "number" or x ~= x then
			return false
		end
	end
	return true
end

--- What is wrong with a mover's config (empty when nothing). Slow, gentle motion only: scenery, not a ride.
function MapMotion.problems(m: Mover): { string }
	local out = {}
	local mode = m.mode or "spin"
	if not MapMotion.MODES[mode] then
		table.insert(out, `unknown mode {mode}`)
		return out
	end
	if type(m.parts) ~= "table" or #(m.parts :: { string }) == 0 then
		table.insert(out, "no parts")
	end
	if not vector(m.hub, 3) then
		table.insert(out, "hub is not 3 numbers")
	end
	if not vector(m.axis, 3) then
		table.insert(out, "axis is not 3 numbers")
	else
		local a = m.axis :: { number }
		if a[1] * a[1] + a[2] * a[2] + a[3] * a[3] < 1e-6 then
			table.insert(out, "axis is zero")
		end
	end
	if mode == "spin" then
		if type(m.rpm) ~= "number" or m.rpm <= 0 or m.rpm > 12 then
			table.insert(out, "spin rpm must be above 0 and at most 12")
		end
	else
		if type(m.period) ~= "number" or m.period < 4 or m.period > 300 then
			table.insert(out, `{mode} period must be 4 to 300 seconds`)
		end
		local most = if mode == "swing" then 45 else 40
		if type(m.amp) ~= "number" or m.amp <= 0 or m.amp > most then
			table.insert(out, `{mode} amp must be above 0 and at most {most}`)
		end
		if
			mode == "bob"
			and m.tilt ~= nil
			and (type(m.tilt) ~= "number" or math.abs(m.tilt) > 20)
		then
			table.insert(out, "bob tilt must be at most 20 degrees")
		end
	end
	if m.phase ~= nil and (type(m.phase) ~= "number" or m.phase < 0 or m.phase > 1) then
		table.insert(out, "phase must be 0 to 1")
	end
	return out
end

return MapMotion
