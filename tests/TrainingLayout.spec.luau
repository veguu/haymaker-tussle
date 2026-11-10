--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local Combat = require("../src/shared/Core/Combat")
local DiveKick = require("../src/shared/Core/DiveKick")
local GameConfig = require("../src/shared/Config/GameConfig")
local TrainingLayout = require("../src/shared/Core/TrainingLayout")

local CFG: any = GameConfig.Training
local ARENA: any = GameConfig.Arena
local PUNCH: any = GameConfig.Punch
local KICK: any = GameConfig.Kick
local STAGGER: any = GameConfig.Stagger

local function status(fields: { [string]: any }): any
	local base = {
		fell = false,
		busy = false,
		busyFor = 0,
		displaced = false,
		sinceHit = 100,
		requested = false,
	}
	for key, value in fields do
		base[key] = value
	end
	return base
end

return {
	["no platform touches another, so launches don't land on a neighbour's floor by default"] = function()
		local discs = TrainingLayout.discs(CFG, ARENA)
		for i = 1, #discs do
			for j = i + 1, #discs do
				local a, b = discs[i], discs[j]
				local gap = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) - a.radius - b.radius
				-- The hub meets every station by a bridge, so only station to station and arena count.
				if a.key ~= "Hub" and b.key ~= "Hub" then
					assert(gap >= 40, `{a.key} and {b.key} are only {gap} apart`)
				else
					assert(gap >= 20, `{a.key} and {b.key} are only {gap} apart`)
				end
			end
		end
	end,

	["the training arena doesn't touch the 1v1 arena"] = function()
		local furthest = CFG.RingDistance
		for _, station in CFG.Stations do
			furthest = math.max(furthest, CFG.RingDistance + station.Radius)
		end
		local between = math.abs(CFG.CenterX - ARENA.CenterX) - ARENA.StartRadius - furthest
		assert(between >= 30, `only {between} studs between them`)
	end,

	["all six stations exist"] = function()
		for _, key in { "A", "B", "C", "D", "E", "F" } do
			assert(TrainingLayout.stationByKey(CFG, key), `no station {key}`)
		end
	end,

	["every dummy stands on its own station, with its own spot and name"] = function()
		local names = {}
		for _, station in CFG.Stations do
			local cx, cz = TrainingLayout.stationCenter(CFG, station)
			local spots = {}
			for _, dummy in station.Dummies do
				assert(not names[dummy.Name], `two dummies called {dummy.Name}`)
				names[dummy.Name] = true
				local x, z = TrainingLayout.place(CFG, station, dummy.Forward, dummy.Right)
				assert(
					math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) <= station.Radius - 6,
					`{dummy.Name} is too near the edge`
				)
				assert(TrainingLayout.standingOn(CFG, x, z) == station.Key)
				for _, other in spots do
					assert(
						math.sqrt((x - other.x) ^ 2 + (z - other.z) ^ 2) >= 8,
						`{dummy.Name} is crowded`
					)
				end
				table.insert(spots, { x = x, z = z })
			end
		end
	end,

	["station A has three punching dummies"] = function()
		assert(#(TrainingLayout.stationByKey(CFG, "A") :: any).Dummies == 3)
	end,

	["stagger dummies start at low, medium and the configured maximum"] = function()
		local station: any = TrainingLayout.stationByKey(CFG, "C")
		assert(#station.Dummies == 3)
		local values = {}
		for _, dummy in station.Dummies do
			table.insert(values, TrainingLayout.startStagger(dummy, STAGGER.Max))
		end
		table.sort(values)
		assert(values[1] > 0 and values[1] < STAGGER.Max / 2, "low should be low")
		assert(values[2] > values[1] and values[2] < values[3], "medium should be between")
		assert(values[3] == STAGGER.Max, "the top one should be the real maximum")
		-- It follows the setting, not a fixed number.
		assert(TrainingLayout.startStagger({ StartStaggerShare = 1 }, 250) == 250)
	end,

	["a moving dummy's path stays on its platform"] = function()
		local station: any = TrainingLayout.stationByKey(CFG, "E")
		local dummy = station.Dummies[1]
		assert(dummy.Patrols)
		local reach = math.sqrt(dummy.Forward ^ 2 + (CFG.Patrol.Length / 2) ^ 2)
		assert(reach <= station.Radius - 4, `path reaches {reach} on a {station.Radius} platform`)
	end,

	["the path turns round at each end and only ever goes along itself"] = function()
		local toB, dirX, dirZ = TrainingLayout.patrolStep(0, 0, 0, 0, 10, 0, true, 1)
		assert(toB and dirX == 1 and dirZ == 0)
		toB, dirX = TrainingLayout.patrolStep(9.5, 0, 0, 0, 10, 0, true, 1)
		assert(not toB and dirX == -1, "turns at B")
		toB, dirX = TrainingLayout.patrolStep(0.5, 0, 0, 0, 10, 0, false, 1)
		assert(toB and dirX == 1, "turns at A")
	end,

	["speeds are slow, medium and fast, in order"] = function()
		local speeds = CFG.Patrol.Speeds
		assert(#speeds == 3)
		assert(speeds[1].Speed < speeds[2].Speed and speeds[2].Speed < speeds[3].Speed)
	end,

	["falling always goes home"] = function()
		assert(TrainingLayout.shouldReset(CFG, status({ fell = true, busy = true }), 5))
	end,

	["never goes home in the middle of a launch, a kick or a bounce"] = function()
		local during = status({ busy = true, busyFor = 3, displaced = true, requested = true })
		assert(not TrainingLayout.shouldReset(CFG, during, 5))
	end,

	["something stuck for far too long is forced home"] = function()
		local stuck = status({ busy = true, busyFor = CFG.ForceResetSeconds })
		assert(TrainingLayout.shouldReset(CFG, stuck, 5))
	end,

	["waits out a combo before going home"] = function()
		assert(not TrainingLayout.shouldReset(CFG, status({ displaced = true, sinceHit = 1 }), 5))
		assert(TrainingLayout.shouldReset(CFG, status({ displaced = true, sinceHit = 5 }), 5))
	end,

	["a reset press still waits a moment after a hit"] = function()
		assert(not TrainingLayout.shouldReset(CFG, status({ requested = true, sinceHit = 0.2 }), 5))
		assert(
			TrainingLayout.shouldReset(
				CFG,
				status({ requested = true, sinceHit = CFG.ManualResetGrace }),
				5
			)
		)
	end,

	["a dummy at home with nothing asked of it stays put"] = function()
		assert(not TrainingLayout.shouldReset(CFG, status({}), 5))
	end,

	["platformAt finds the arena, the hub and each station"] = function()
		assert(TrainingLayout.platformAt(CFG, ARENA, ARENA.CenterX, ARENA.CenterZ).key == "Arena")
		assert(TrainingLayout.platformAt(CFG, ARENA, CFG.CenterX, CFG.CenterZ).key == "Hub")
		for _, station in CFG.Stations do
			local x, z = TrainingLayout.stationCenter(CFG, station)
			assert(TrainingLayout.platformAt(CFG, ARENA, x, z).key == station.Key)
			-- Well off the edge, it's still the nearest platform, which is what a recovery is judged from.
			local _, _, outX, outZ = TrainingLayout.stationCenter(CFG, station)
			local past = station.Radius + 15
			assert(
				TrainingLayout.platformAt(CFG, ARENA, x + outX * past, z + outZ * past).key
					== station.Key
			)
		end
	end,

	["standing on: floors and bridges count, gaps don't"] = function()
		assert(TrainingLayout.standingOn(CFG, CFG.CenterX, CFG.CenterZ) == "Hub")
		local station: any = TrainingLayout.stationByKey(CFG, "A")
		local cx, cz, outX, outZ = TrainingLayout.stationCenter(CFG, station)
		assert(TrainingLayout.standingOn(CFG, cx, cz) == "A")
		local mid = CFG.RingDistance / 2
		assert(
			TrainingLayout.standingOn(CFG, CFG.CenterX + outX * mid, CFG.CenterZ + outZ * mid)
				== "Hub"
		)
		assert(TrainingLayout.standingOn(CFG, 0, 0) == nil, "the other arena isn't training")
		assert(
			TrainingLayout.standingOn(
				CFG,
				cx + outX * (station.Radius + 5),
				cz + outZ * (station.Radius + 5)
			) == nil
		)
	end,

	["each stand spot is really inside what the punch rules allow, with no special cases"] = function()
		local spots = TrainingLayout.standSpots(PUNCH)
		assert(#spots == 4)
		for _, spot in spots do
			-- You stand at the spot and face the target at the origin: forward is your distance from it.
			local size = math.sqrt(spot.forward ^ 2 + spot.right ^ 2)
			local faceX, faceZ = -spot.right / size, -spot.forward / size
			if spot.name == "BESIDE" then
				-- Beside it means it's at your shoulder, facing the way you'd be facing to walk past.
				faceX, faceZ = 0, 1
			end
			local hit = false
			for _, side in { "Left", "Right", "Uppercut" } do
				local inside =
					Combat.inHitbox(PUNCH, spot.right, 0, spot.forward, faceX, faceZ, 0, 0, 0, side)
				hit = hit or inside
			end
			assert(hit, `{spot.name} doesn't reach`)
		end
	end,

	["reach rings grow outward and come from the real settings"] = function()
		local rings = TrainingLayout.reachRings(PUNCH)
		assert(rings[1].radius < rings[2].radius and rings[2].radius < rings[3].radius)
		assert(rings[3].radius == PUNCH.Range + PUNCH.TargetRadius)
	end,

	["launch pads are marked on the platform and start past its edge, going outward"] = function()
		local station: any = TrainingLayout.stationByKey(CFG, CFG.Recovery.StationKey)
		local cx, cz = TrainingLayout.stationCenter(CFG, station)
		assert(#CFG.Recovery.Pads >= 5)
		for _, pad in CFG.Recovery.Pads do
			local spot = TrainingLayout.pad(CFG, station, pad)
			local mark = math.sqrt((spot.markX - cx) ^ 2 + (spot.markZ - cz) ^ 2)
			assert(mark < station.Radius, `{pad.Name}'s pad is off the platform`)
			local start = math.sqrt((spot.startX - cx) ^ 2 + (spot.startZ - cz) ^ 2)
			assert(start > station.Radius, `{pad.Name} starts on the platform`)
			local along = (spot.startX - cx) * spot.dirX + (spot.startZ - cz) * spot.dirZ
			assert(along > 0, `{pad.Name} doesn't go outward`)
			assert(string.find(TrainingLayout.padConditions(pad, STAGGER.Max), "stagger"))
		end
	end,

	["nobody arrives on a pad, which would send them straight back"] = function()
		local function clear(ax: number, az: number, bx: number, bz: number): boolean
			return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) > CFG.PadRadius + 2
		end
		local gateX, gateZ = TrainingLayout.arenaGate(CFG, ARENA)
		local backX, backZ = TrainingLayout.arenaArrival(CFG, ARENA)
		assert(clear(gateX, gateZ, backX, backZ), "arrives on the gate")
		local hub = TrainingLayout.hubPads(CFG)
		local hubX, hubZ = TrainingLayout.hubEntry(CFG)
		for _, pad in { hub.exit, hub.panel, hub.hitbox } do
			assert(clear(hubX, hubZ, pad.x, pad.z), "arrives on a hub pad")
		end
		for _, station in CFG.Stations do
			local x, z = TrainingLayout.entry(CFG, station)
			for _, right in { CFG.PadRadius * 3, -CFG.PadRadius * 3, -CFG.PadRadius * 6 } do
				local padX, padZ = TrainingLayout.stationPad(CFG, station, right)
				assert(clear(x, z, padX, padZ), `arrives on a pad at {station.Key}`)
				assert(
					TrainingLayout.standingOn(CFG, padX, padZ) == station.Key,
					`{station.Key}'s pad is off its floor`
				)
			end
		end
	end,

	["launch pads don't overlap each other"] = function()
		local station: any = TrainingLayout.stationByKey(CFG, CFG.Recovery.StationKey)
		local list = CFG.Recovery.Pads
		for i = 1, #list do
			for j = i + 1, #list do
				local a = TrainingLayout.pad(CFG, station, list[i])
				local b = TrainingLayout.pad(CFG, station, list[j])
				local gap = math.sqrt((a.markX - b.markX) ^ 2 + (a.markZ - b.markZ) ^ 2)
				assert(gap > CFG.PadRadius * 2, `{list[i].Name} and {list[j].Name} overlap`)
			end
		end
	end,

	["launches get stronger from pad to pad within each kind"] = function()
		local lastUp, lastOut = {}, {}
		for _, pad in CFG.Recovery.Pads do
			local kind = if pad.Launched then "up" else "drift"
			assert(
				pad.OutwardSpeed > (lastOut[kind] or 0),
				`{pad.Name} isn't further than the last`
			)
			lastOut[kind] = pad.OutwardSpeed
			lastUp[kind] = pad.UpSpeed
		end
	end,

	["a kick's rebound on a station lands on that station, not the 1v1 arena"] = function()
		local station: any = TrainingLayout.stationByKey(CFG, "B")
		local cx, cz, outX, outZ = TrainingLayout.stationCenter(CFG, station)
		local atX, atZ = cx + outX * 20, cz + outZ * 20
		local platform = TrainingLayout.platformAt(CFG, ARENA, atX, atZ)
		for _, grade: any in { "red", "orange", "green" } do
			local plan = DiveKick.planRebound(KICK, grade, {
				x = atX,
				z = atZ,
				height = 40,
				backX = -outX,
				backZ = -outZ,
				centerX = platform.x,
				centerZ = platform.z,
				radius = platform.radius,
				speed = GameConfig.Movement.PropelSpeed,
				gravity = 196.2 * KICK.ReboundGravityScale,
			})
			local landX = atX + plan.dirX * plan.speed * plan.air
			local landZ = atZ + plan.dirZ * plan.speed * plan.air
			local away = math.sqrt((landX - cx) ^ 2 + (landZ - cz) ^ 2)
			assert(away <= station.Radius, `{grade} lands {away} from the centre`)
		end
	end,
}
