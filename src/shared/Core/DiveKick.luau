--!strict
-- DiveKick - how a body launched into the air steers, as plain maths with no Roblox instances.
-- (The air kick's phases, follow-up pick, timing and rebound that lived here were removed with the
-- air kick: the owner, 2026-11-25. The file keeps its name so nothing else has to move.)

local DiveKick = {}

export type Settings = {
	LaunchSteerStaggerLoss: number,
}

--- Directional air control: pushes the velocity toward where the keys point, up to `limit`. With no
--- keys it keeps what it has. It's kept apart from any launch speed, so it never cancels that.
function DiveKick.airSteer(
	vx: number,
	vz: number,
	inputX: number,
	inputZ: number,
	limit: number,
	acceleration: number,
	dt: number
): (number, number)
	if inputX == 0 and inputZ == 0 then
		return vx, vz
	end
	local had = math.sqrt(vx * vx + vz * vz)
	local nextX, nextZ = vx + inputX * acceleration * dt, vz + inputZ * acceleration * dt
	local size = math.sqrt(nextX * nextX + nextZ * nextZ)
	local cap = math.max(limit, had)
	if size > cap then
		nextX, nextZ = nextX / size * cap, nextZ / size * cap
	end
	return nextX, nextZ
end

--- How much air control someone launched has. The more staggered, the less they can do about it.
function DiveKick.launchSteerShare(cfg: Settings, stagger: number, staggerMax: number): number
	return 1 - cfg.LaunchSteerStaggerLoss * math.clamp(stagger / staggerMax, 0, 1)
end

return DiveKick
