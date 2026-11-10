--!strict
-- DashHit - what running into someone during a dash does to them, as plain maths with no Roblox
-- instances.
--
-- An ordinary collision is a bump: both take a small shove (Core/Combat.bumpOutcome). When exactly one
-- of the two is in a dash that was charged high, it's a hit instead: the one dashed into is thrown the
-- way the dasher was travelling, harder the faster the dasher was going, and far enough to end up well
-- past where the dasher's own dash carries them. The dasher carries on. A tap or a lightly charged
-- dash is still only a bump.
-- Two things have to hold. The charge the dasher asked for must be at least DashHitMinCharge, and the
-- speed the SERVER measured must be at least DashHitMinSpeed, which is set above a tap dash's top
-- speed: so claiming a charge that wasn't really held gets nothing.

local DashHit = {}

export type Settings = {
	DashHitMinCharge: number,
	DashHitMinSpeed: number,
	DashHitFullSpeed: number,
	DashHitPushShare: number,
	DashHitMaxPush: number,
	DashHitLift: number,
	DashHitStagger: number,
	DashHitReach: number,
	DashHitLeadSeconds: number,
	DashHitWidth: number,
}

export type Outcome = {
	push: number,
	lift: number,
	stagger: number,
}

--- What a dash at `speed`, charged to `power` (0 to 1), does to whoever it runs into, or nil if it's
--- only a bump: not charged enough, or not really going fast enough. The push is `DashHitPushShare` of
--- the speed, up to `DashHitMaxPush`. Speed past `DashHitFullSpeed` counts as that, so nothing measured
--- wrongly (or faked) hits harder than a full dash can.
function DashHit.outcome(cfg: Settings, speed: number, power: number): Outcome?
	if power ~= power or power < cfg.DashHitMinCharge then
		return nil
	end
	if speed ~= speed or speed < cfg.DashHitMinSpeed then
		return nil
	end
	local counted = math.min(speed, cfg.DashHitFullSpeed)
	return {
		push = math.min(counted * cfg.DashHitPushShare, cfg.DashHitMaxPush),
		lift = cfg.DashHitLift,
		stagger = math.floor(
			cfg.DashHitStagger * counted / math.max(cfg.DashHitFullSpeed, 1) * 10 + 0.5
		) / 10,
	}
end

--- Is someone in the way of this dash? `dx`, `dz` is from the dasher to them and `vx`, `vz` the dasher's
--- measured velocity. They are if they're ahead along the travel, within `DashHitReach` plus
--- `DashHitLeadSeconds` of travel, and no further than `DashHitWidth` to either side of the path.
--- The lead is there because the server sees a client's body a moment late and its push takes another
--- moment to arrive: without it, the hit lands after the dasher is already through them.
function DashHit.reaches(cfg: Settings, dx: number, dz: number, vx: number, vz: number): boolean
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed ~= speed or speed < 0.001 then
		return false
	end
	local along = (dx * vx + dz * vz) / speed
	local across = math.abs(dx * vz - dz * vx) / speed
	local reach = cfg.DashHitReach + speed * cfg.DashHitLeadSeconds
	-- A little behind still counts, for a dasher already overlapping them.
	return along >= -cfg.DashHitWidth and along <= reach and across <= cfg.DashHitWidth
end

return DashHit
