--!strict
-- TrainingLayout - where everything in the training arena is, and when a dummy may go home, as plain
-- maths with no Roblox instances. All of it comes from GameConfig.Training, so moving a station means
-- changing a number. The client uses it too, for the kick's rebound and the testing display.
--
-- A hub sits in the middle with the stations in a ring around it. Each station is a circular platform
-- joined to the hub by a bridge, and "forward" on a station points away from the hub, so anything
-- punched from the bridge side flies away from every other station.

local TrainingLayout = {}

export type Disc = { key: string, x: number, y: number, z: number, radius: number }

export type ResetStatus = {
	fell: boolean, -- below the fall line
	busy: boolean, -- launched, held, stunned or in the air
	busyFor: number, -- how long it has been busy
	displaced: boolean, -- away from its home
	sinceHit: number,
	requested: boolean, -- someone pressed reset
}

export type StandSpot = { name: string, forward: number, right: number }

--- A station's centre, and the direction away from the hub.
function TrainingLayout.stationCenter(cfg: any, station: any): (number, number, number, number)
	local angle = math.rad(station.AngleDegrees)
	local outX, outZ = math.cos(angle), math.sin(angle)
	return cfg.CenterX + outX * cfg.RingDistance, cfg.CenterZ + outZ * cfg.RingDistance, outX, outZ
end

--- A point on a station, in studs away from the hub and to the right of that.
function TrainingLayout.place(
	cfg: any,
	station: any,
	forward: number,
	right: number
): (number, number)
	local x, z, outX, outZ = TrainingLayout.stationCenter(cfg, station)
	return x + outX * forward - outZ * right, z + outZ * forward + outX * right
end

--- Where someone arrives on a station, just inside its bridge side, and which way they face.
function TrainingLayout.entry(cfg: any, station: any): (number, number, number, number)
	local x, z = TrainingLayout.place(cfg, station, -(station.Radius - cfg.ReturnInset), 0)
	local _, _, outX, outZ = TrainingLayout.stationCenter(cfg, station)
	return x, z, outX, outZ
end

--- Where someone arrives on the hub from the other arena, facing into it. Clear of every pad, because
--- a pad works the moment you're on it.
function TrainingLayout.hubEntry(cfg: any): (number, number, number, number)
	return cfg.CenterX - cfg.HubRadius / 2, cfg.CenterZ, 1, 0
end

--- The pad on the other arena that leads here.
function TrainingLayout.arenaGate(cfg: any, arena: any): (number, number)
	return arena.CenterX + arena.StartRadius - cfg.GateInset, arena.CenterZ
end

--- Where someone arrives back on the other arena, clear of its pad, facing into it.
function TrainingLayout.arenaArrival(cfg: any, arena: any): (number, number, number, number)
	local x, z = TrainingLayout.arenaGate(cfg, arena)
	return x - cfg.PadRadius * 2.5, z, -1, 0
end

--- The hub's pads: the way out, on the side the other arena is on, and the display's, between the
--- bridges on the far side.
function TrainingLayout.hubPads(cfg: any): any
	local edge = cfg.HubRadius - cfg.PadRadius - cfg.RimWidth - 1
	return {
		exit = { x = cfg.CenterX - edge, z = cfg.CenterZ },
		panel = { x = cfg.CenterX + edge, z = cfg.CenterZ - cfg.PadRadius * 1.5 },
		hitbox = { x = cfg.CenterX + edge, z = cfg.CenterZ + cfg.PadRadius * 1.5 },
	}
end

--- A station's pads sit in a row across its bridge side, either side of where you arrive.
function TrainingLayout.stationPad(cfg: any, station: any, right: number): (number, number)
	return TrainingLayout.place(cfg, station, -(station.Radius - cfg.ReturnInset), right)
end

function TrainingLayout.stationByKey(cfg: any, key: string): any?
	for _, station in cfg.Stations do
		if station.Key == key then
			return station
		end
	end
	return nil
end

--- Every platform there is: the other arena, the hub and the stations.
function TrainingLayout.discs(cfg: any, arena: any): { Disc }
	local list: { Disc } = {
		{
			key = "Arena",
			x = arena.CenterX,
			y = arena.CenterY,
			z = arena.CenterZ,
			radius = arena.StartRadius,
		},
		{
			key = "Hub",
			x = cfg.CenterX,
			y = cfg.CenterY,
			z = cfg.CenterZ,
			radius = cfg.HubRadius,
		},
	}
	for _, station in cfg.Stations do
		local x, z = TrainingLayout.stationCenter(cfg, station)
		table.insert(
			list,
			{ key = station.Key, x = x, y = cfg.CenterY, z = z, radius = station.Radius }
		)
	end
	return list
end

--- The platform a body is over, or else the one whose edge is nearest. Recovery and a kick's rebound
--- are judged from this, so they work the same on every platform.
function TrainingLayout.platformAt(cfg: any, arena: any, x: number, z: number): Disc
	local best: Disc? = nil
	local bestGap = math.huge
	for _, disc in TrainingLayout.discs(cfg, arena) do
		local dx, dz = x - disc.x, z - disc.z
		local gap = math.sqrt(dx * dx + dz * dz) - disc.radius
		if gap < bestGap then
			best, bestGap = disc, gap
		end
	end
	return best :: Disc
end

--- Which part of the training arena this point is standing on: a station's key, "Hub" (a bridge counts
--- as the hub), or nil if it's off all of it.
function TrainingLayout.standingOn(cfg: any, x: number, z: number): string?
	local hubX, hubZ = x - cfg.CenterX, z - cfg.CenterZ
	if hubX * hubX + hubZ * hubZ <= cfg.HubRadius * cfg.HubRadius then
		return "Hub"
	end
	for _, station in cfg.Stations do
		local cx, cz, outX, outZ = TrainingLayout.stationCenter(cfg, station)
		local dx, dz = x - cx, z - cz
		if dx * dx + dz * dz <= station.Radius * station.Radius then
			return station.Key
		end
		local along = hubX * outX + hubZ * outZ
		local across = math.abs(-hubX * outZ + hubZ * outX)
		if along >= 0 and along <= cfg.RingDistance and across <= cfg.BridgeWidth / 2 then
			return "Hub"
		end
	end
	return nil
end

--- The stagger a dummy starts at, as a share of whatever the configured range is.
function TrainingLayout.startStagger(dummy: any, staggerMax: number): number
	return math.floor((dummy.StartStaggerShare or 0) * staggerMax + 0.5)
end

--- Should this dummy go home now? Falling always does. Otherwise it waits out a launch, a kick, a bounce
--- or a combo, and only something stuck for far too long gets forced.
function TrainingLayout.shouldReset(cfg: any, status: ResetStatus, resetSeconds: number): boolean
	if status.fell then
		return true
	end
	if status.busy then
		return status.busyFor >= cfg.ForceResetSeconds
	end
	if status.requested then
		return status.sinceHit >= cfg.ManualResetGrace
	end
	return status.displaced and status.sinceHit >= resetSeconds
end

--- One step of a marked path: heads for one end until it's there, then the other. Returns whether it's
--- heading for end B now, and the direction.
function TrainingLayout.patrolStep(
	x: number,
	z: number,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	toB: boolean,
	arrive: number
): (boolean, number, number)
	local goalX, goalZ = if toB then bx else ax, if toB then bz else az
	local dx, dz = goalX - x, goalZ - z
	local size = math.sqrt(dx * dx + dz * dz)
	if size <= arrive then
		toB = not toB
		goalX, goalZ = if toB then bx else ax, if toB then bz else az
		dx, dz = goalX - x, goalZ - z
		size = math.sqrt(dx * dx + dz * dz)
	end
	if size < 0.001 then
		return toB, 0, 0
	end
	return toB, dx / size, dz / size
end

--- The reach rings around a target, from the real punch settings, centre to centre.
function TrainingLayout.reachRings(punch: any): { { name: string, radius: number } }
	return {
		{ name = "CONTACT", radius = punch.OverlapRadius },
		{ name = "CLOSE", radius = punch.CloseRange + punch.TargetRadius },
		{ name = "REACH", radius = punch.Range + punch.TargetRadius },
	}
end

--- Where to stand around a target to test each case, all just inside what the real rules allow. Forward
--- is away from the target toward the hub side, so you're looking at it from there.
function TrainingLayout.standSpots(punch: any): { StandSpot }
	local reach = punch.Range + punch.TargetRadius - 1
	local close = punch.CloseRange + punch.TargetRadius - 0.7
	local offAngle = math.rad(punch.HookInnerDegrees)
	return {
		{ name = "FRONT", forward = reach, right = 0 },
		{
			name = "OFF-CENTRE",
			forward = reach * math.cos(offAngle),
			right = reach * math.sin(offAngle),
		},
		{ name = "BESIDE", forward = 0, right = -close },
		{ name = "OVERLAP", forward = punch.OverlapRadius - 1, right = 0 },
	}
end

--- A launch pad: where its marker is on the platform, where a launch starts from past the edge, and
--- which way it goes.
function TrainingLayout.pad(cfg: any, station: any, pad: any): any
	local cx, cz, outX, outZ = TrainingLayout.stationCenter(cfg, station)
	local angle = math.rad(pad.FanDegrees)
	local c, s = math.cos(angle), math.sin(angle)
	local dirX, dirZ = outX * c - outZ * s, outX * s + outZ * c
	local markAt = station.Radius - cfg.Recovery.PadInset
	local startAt = station.Radius + pad.GapStuds
	return {
		markX = cx + dirX * markAt,
		markZ = cz + dirZ * markAt,
		startX = cx + dirX * startAt,
		startZ = cz + dirZ * startAt,
		dirX = dirX,
		dirZ = dirZ,
	}
end

--- The line on a pad's sign, so the same launch can be repeated and written down.
function TrainingLayout.padConditions(pad: any, staggerMax: number): string
	local stagger = math.floor(pad.StaggerShare * staggerMax + 0.5)
	return `{pad.GapStuds} past edge, {pad.HeightStuds} high, {pad.OutwardSpeed} out, {pad.UpSpeed} up, stagger {stagger}`
end

return TrainingLayout