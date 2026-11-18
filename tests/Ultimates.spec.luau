--!strict
local roblox = require("@lune/roblox")
local Ultimates = require("../src/shared/Core/Ultimates")
local Round = require("../src/shared/Core/Round")
local GameConfig = require("../src/shared/Config/GameConfig")

local Vector3 = roblox.Vector3
local CFG: any = GameConfig.Ultimate
local ARENA: any = GameConfig.Arena

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

-- A small stand-in timeline for the playback maths (the kits' ultimates are being redesigned).
local TEST: Ultimates.Timeline = {
	name = "Test",
	cinematic = 1,
	attackerFree = 1.2,
	keys = {
		{ t = 0, target = Vector3.new(0, 0, 0) },
		{ t = 0.5, attacker = Vector3.new(0, 3, 3), target = Vector3.new(0, 3, 0), ease = "out" },
		{ t = 1, attacker = Vector3.new(0, 3, 1), target = Vector3.new(0, 3, -1) },
	},
	shots = {
		{ t = 0, cam = Vector3.new(7, 2, 1), look = Vector3.new(0, 3, 1), fov = 90, cut = true },
		{
			t = 0.4,
			cam = Vector3.new(6, 2, 1),
			look = Vector3.new(0, 3, 1),
			fov = 50,
			ease = "out",
		},
		{
			t = 0.6,
			cam = Vector3.new(-5, 3, -6),
			look = Vector3.new(0, 3, 1),
			fov = 80,
			cut = true,
		},
	},
	flightFov = 90,
	cues = { { t = 0, name = "start" }, { t = 0.6, name = "hit" }, { t = 1, name = "launch" } },
	swings = {},
	blows = {},
}

return {
	["every kit plays Base's Haymaker Rush until it has its own"] = function()
		for _, kitId in
			{ "Base", "Tempest", "Inferno", "Frost", "Beast", "Dragon", "Bruiser", "Trickster" }
		do
			local line = Ultimates.timeline(kitId)
			assert(line and line.name == "Haymaker Rush", kitId)
		end
		assert(Ultimates.timeline(nil) == Ultimates.TIMELINES.Base)
	end,

	["Haymaker Rush is in order and ends in the flight"] = function()
		local line = Ultimates.TIMELINES.Base
		local function ordered(list: { any }, what: string)
			for index = 2, #list do
				assert(list[index].t >= list[index - 1].t, `{what} out of order at {index}`)
			end
			assert(list[#list].t <= line.cinematic + 1e-6, `{what} past the cinematic`)
		end
		ordered(line.keys, "keys")
		ordered(line.shots, "shots")
		ordered(line.cues, "cues")
		ordered(line.swings, "swings")
		ordered(line.blows, "blows")
		assert(line.keys[#line.keys].t == line.cinematic, "the last key is the flight's start")
		assert(line.attackerFree >= line.cinematic, "the attacker is held through the cinematic")
		-- every blow has a swing striking on it, or lands inside the barrage loop
		local barrage = line.barrage
		for _, blow in line.blows do
			local struck = barrage ~= nil and blow.t > barrage.from and blow.t < barrage.to
			for _, swing in line.swings do
				if math.abs(swing.t + swing.windup - blow.t) < 0.011 then
					struck = true
				end
			end
			assert(struck, `no swing strikes at {blow.t}`)
		end
		-- the hooks can't strike faster than their clip (0.16 s)
		-- (a held swing and its release are the exception: from the hold it strikes 0.07 s later)
		for _, swing in line.swings do
			assert(
				swing.side == "Uppercut"
					or swing.hold
					or swing.fromHold
					or swing.windup >= 0.16 - 1e-6,
				`hook at {swing.t} too fast`
			)
		end
		-- a release always follows its hold
		local held = false
		for _, swing in line.swings do
			if swing.hold then
				held = true
			elseif swing.fromHold then
				assert(held, `release at {swing.t} with nothing held`)
				held = false
			end
		end
		-- one side of the action (kits-6c, the user: "the camera angles are too random"): every camera on the
		-- attacker's right, so who is where never flips on screen
		for _, shot in line.shots do
			assert(shot.cam.X > 0, `shot at {shot.t} crosses the line`)
		end
		-- the swung blows: no two closer than a hook can strike and start to follow through (0.22 s). The flurry
		-- (kits-7d, the user: "a FAST CONSECUTIVE flurry, ~8 hits/s like Garou", one continuous flurry, which
		-- overrides kits-6d's bursts and breaths) is the barrage loop: one unbroken run at its own beat.
		local flurry = {}
		local lastSwung = -math.huge
		for _, blow in line.blows do
			if barrage and blow.t > barrage.from and blow.t < barrage.to then
				table.insert(flurry, blow.t)
			else
				assert(blow.t - lastSwung >= 0.22 - 1e-6, `blows at {blow.t} too close`)
				lastSwung = blow.t
			end
		end
		assert(#flurry >= 12, "a real flurry, not a few punches")
		for index = 2, #flurry do
			local gap = flurry[index] - flurry[index - 1]
			assert(gap >= 0.1 and gap <= 0.15, `the flurry breaks at {flurry[index]}`)
		end
		-- the pace (kits-6b, the user: "too fast"): at least 4.5 s, and no shot shorter than 0.3 s
		assert(line.cinematic >= 4.5, "long enough to read")
		local cuts = {}
		for _, shot in line.shots do
			if shot.cut then
				table.insert(cuts, shot.t)
			end
		end
		table.insert(cuts, line.cinematic)
		for index = 2, #cuts do
			assert(
				cuts[index] - cuts[index - 1] >= 0.3 - 1e-6,
				`shot at {cuts[index - 1]} too short`
			)
		end
		-- the haymaker lands in the dip's silence, after the hang
		local dip, haymaker = 0, 0
		for _, cue in line.cues do
			if cue.name == "dip" then
				dip = cue.t
			elseif cue.name == "haymaker" then
				haymaker = cue.t
			end
		end
		assert(dip > 0 and haymaker - dip >= 0.1 and haymaker - dip <= 0.3, "a 0.1-0.3 s dip")
	end,

	["shots in the attacker's frame follow the attacker"] = function()
		local line = Ultimates.TIMELINES.Base
		-- v2: the close-ups (first contact, wind-up) ride on the attacker; take the first one
		local first
		for _, shot in line.shots do
			if shot.rel == "attacker" and shot.cut then
				first = shot
				break
			end
		end
		assert(first, "a close-up rides on the attacker")
		local at, target = Vector3.new(0, 0, 12), Vector3.new(0, 0, 0)
		local cam, look = Ultimates.shot(line, first.t, at, target)
		-- the attacker faces -Z here, so their frame is the anchor's, moved to them
		assert(near(cam.X, at.X + first.cam.X, 0.001), "x")
		assert(near(cam.Z, at.Z + first.cam.Z, 0.001), "z")
		assert(near(look.Z, at.Z + first.look.Z, 0.001), "look")
		local turned = Ultimates.shot(line, first.t, Vector3.new(12, 0, 0), target)
		-- facing -X now: their right (+X local) is the anchor's -Z
		assert(near(turned.Z, -first.cam.X, 0.001), "turned with them")
		-- the two-shots ride on the pair's midpoint
		local wide
		for _, shot in line.shots do
			if shot.rel == "pair" then
				wide = shot
				break
			end
		end
		assert(wide, "a shot frames them both")
		local wideCam = Ultimates.shot(line, wide.t, at, target)
		assert(near(wideCam.Z, 6 + wide.cam.Z, 0.001), "pair midpoint")
	end,

	["big hits freeze, snap the camera and jolt; the flurry jitters (the camera study)"] = function()
		-- kits-7e (vault: 63 VFX Creation/Cutscene Camera and Impact - Measured From 10 References): every big hit
		-- holds the scene, the camera cuts to a new angle on it, and one jolt follows the freeze
		local line = Ultimates.TIMELINES.Base
		local start = Vector3.new(0, 0, 9)
		local frozen = 0
		for _, blow in line.blows do
			local freeze = blow.freeze
			if freeze then
				frozen += 1
				assert(
					freeze >= 0.15 - 1e-6 and freeze <= 0.4,
					`freeze at {blow.t} out of the measured range`
				)
				local a1, t1 = Ultimates.pose(line, blow.t + 0.01, start)
				local a2, t2 = Ultimates.pose(line, blow.t + freeze - 0.01, start)
				assert(
					(a1 - a2).Magnitude < 1e-3 and (t1 - t2).Magnitude < 1e-3,
					`bodies move in the freeze at {blow.t}`
				)
				local cut = false
				for _, shot in line.shots do
					if shot.cut and math.abs(shot.t - blow.t) < 1e-6 then
						cut = true
					end
				end
				assert(cut, `no snap on the hit at {blow.t}`)
				local jolted = false
				for _, jolt in line.jolts or {} do
					if math.abs(jolt.t - (blow.t + freeze)) < 1e-6 then
						jolted = true
					end
				end
				assert(jolted, `no jolt after the freeze at {blow.t}`)
				-- the jolt is out at once, then gone
				local x, y = Ultimates.shake(line, blow.t + freeze + 0.005)
				assert(math.sqrt(x * x + y * y) > 0.5, `the jolt at {blow.t} is too small`)
			end
		end
		assert(frozen >= 3, "the first hook, the uppercut and the haymaker freeze")
		-- the flurry's jitter: on through it, a new direction every 1/30 s, off outside
		local barrage = line.barrage :: any
		local mid = (barrage.from + barrage.to) / 2
		local x1, y1 = Ultimates.shake(line, mid)
		local x2, y2 = Ultimates.shake(line, mid + 1 / 30)
		assert(math.sqrt(x1 * x1 + y1 * y1) > 0.1, "the flurry jitters")
		assert(math.abs(x1 - x2) + math.abs(y1 - y2) > 0.1, "a new direction each frame")
		local xs, ys = Ultimates.shake(line, 0.2)
		assert(xs == 0 and ys == 0, "still before anything lands")
	end,

	["the rush in is a real run: it speeds up all the way, seen from behind"] = function()
		-- kits-7d, the user: "an animation of the rush itself, with an accompanying camera angle that shows you
		-- speeding up to them from behind you. right now it just teleports"
		local line = Ultimates.TIMELINES.Base
		local dash = line.dash
		assert(dash, "the attacker sprints while carried in")
		assert(dash.to - dash.from >= 0.6, "long enough to see (it was 0.34 s)")
		for _, start in { Vector3.new(0, 0, 6), Vector3.new(4, 0, 14), Vector3.new(-8, 0, 20) } do
			local lastSpeed = 0
			local step = 1 / 30
			local t = dash.from + step
			while t <= dash.to - step do
				local before = Ultimates.pose(line, t - step, start)
				local now = Ultimates.pose(line, t, start)
				local speed = (now - before).Magnitude / step
				assert(speed >= lastSpeed - 1e-3, `slows at {t} from {start}`)
				lastSpeed = speed
				-- the camera behind them (their own +Z) and on their right
				local attackerAt, targetAt = Ultimates.pose(line, t, start)
				local cam = Ultimates.shot(line, t, attackerAt, targetAt, start)
				if t < dash.to - 0.2 then
					local frame = Ultimates.attackerFrame(attackerAt, targetAt)
					local inFrame = frame:PointToObjectSpace(cam)
					assert(
						inFrame.Z > 3 and inFrame.X > 0,
						`camera not behind them at {t} from {start}`
					)
				end
				t += step
			end
			assert(lastSpeed > 0, "they move")
		end
	end,

	["the anchor faces outward from the arena's middle"] = function()
		local centre = Vector3.new(0, 0, 0)
		local frame = Ultimates.anchor(Vector3.new(10, 5, 0), Vector3.new(5, 5, 0), centre)
		assert(
			near(frame.LookVector.X, 1, 0.001) and near(frame.LookVector.Y, 0, 0.001),
			"outward, flat"
		)
		local off = Ultimates.anchor(Vector3.new(10, 5, 0), Vector3.new(10, 5, 4), nil)
		assert(near(off.LookVector.Z, -1, 0.001), "off the arena: away from the attacker")
	end,

	["poses start where the attacker was and end on the last key"] = function()
		local start = Vector3.new(9, 0, 9)
		local a = Ultimates.pose(TEST, 0, start)
		assert(a == start, "the attacker starts where they were")
		local a2, t2 = Ultimates.pose(TEST, TEST.cinematic + 5, start)
		local lastKey = TEST.keys[#TEST.keys]
		assert(a2 == lastKey.attacker and t2 == lastKey.target, "after the end, the last key")
		assert(
			#Ultimates.cuesBetween(TEST, -1, TEST.cinematic) == #TEST.cues,
			"every cue fires once"
		)
		assert(#Ultimates.cuesBetween(TEST, 0.5, 0.5) == 0, "an empty span fires nothing")
	end,

	["camera shots cut where marked and ease otherwise"] = function()
		for _, shot in TEST.shots do
			if shot.cut then
				local cam, look, fov = Ultimates.shot(TEST, shot.t)
				assert(cam == shot.cam and look == shot.look and fov == shot.fov, `cut at {shot.t}`)
			end
		end
		local first, second = TEST.shots[1], TEST.shots[2]
		local _, _, mid = Ultimates.shot(TEST, (first.t + second.t) / 2)
		assert(mid < first.fov and mid > second.fov, "a snap zoom in progress")
	end,

	["the flight always ends out of the round, from anywhere on the arena"] = function()
		local centre = Vector3.new(ARENA.CenterX, ARENA.CenterY, ARENA.CenterZ)
		for _, offset in
			{
				Vector3.new(0, 3, 0),
				Vector3.new(60, 3, 0),
				Vector3.new(-30, 10, 50),
				Vector3.new(0, 3, -90),
			}
		do
			local start = centre + offset
			local outward = if offset.Magnitude > 4
				then Vector3.new(offset.X, 0, offset.Z)
				else Vector3.new(1, 0, 0)
			local finish = Ultimates.flightEnd(CFG, ARENA, start, outward)
			assert(
				Round.isOut(ARENA, finish.X, finish.Y, finish.Z),
				`from {offset}: ends at {finish}`
			)
		end
		local lobby = Ultimates.flightEnd(CFG, nil, Vector3.new(0, 10, 0), Vector3.new(0, 0, -1))
		assert(
			near(lobby.Z, -CFG.LobbyFlightDistance, 0.001) and lobby.Y < 10,
			"off the arena: out and down"
		)
	end,

	["the flight arcs up then lands on its end"] = function()
		local start, finish = Vector3.new(0, 0, 0), Vector3.new(100, -50, 0)
		assert(Ultimates.flightPoint(start, finish, 0, 20) == start)
		local ending = Ultimates.flightPoint(start, finish, 1, 20)
		assert(near(ending.X, 100, 0.001) and near(ending.Y, -50, 0.001))
		assert(Ultimates.flightPoint(start, finish, 0.25, 20).Y > 0, "it rises first")
	end,
}
