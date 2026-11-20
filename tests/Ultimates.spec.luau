--!strict
local roblox = require("@lune/roblox")
local Ultimates = require("../src/shared/Core/Ultimates")
local Round = require("../src/shared/Core/Round")
local GameConfig = require("../src/shared/Config/GameConfig")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
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
				-- a SLOWED hit (kits-7m, the haymaker: the owner asked for slow motion "so you can feel the weight")
				-- runs longer, its bodies creep on, and the camera zooms in instead of snapping (kits-8e: up to 1.8 s, the
				-- owner's "the part where the fist sinks in should be longer")
				local slowed = blow.slow ~= nil
				assert(
					freeze >= 0.15 - 1e-6 and freeze <= (if slowed then 1.8 else 0.4),
					`freeze at {blow.t} out of the measured range`
				)
				if not slowed then
					local a1, t1 = Ultimates.pose(line, blow.t + 0.01, start)
					local a2, t2 = Ultimates.pose(line, blow.t + freeze - 0.01, start)
					assert(
						(a1 - a2).Magnitude < 1e-3 and (t1 - t2).Magnitude < 1e-3,
						`bodies move in the freeze at {blow.t}`
					)
					-- (kits-8i: or under the drawn frames in the pause right before it lands)
					local cut = false
					for _, shot in line.shots do
						if shot.cut and shot.t <= blow.t + 1e-6 and shot.t >= blow.t - 0.05 then
							cut = true
						end
					end
					assert(cut, `no snap on the hit at {blow.t}`)
				end
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
		local x2, y2 = Ultimates.shake(line, mid + 0.1)
		assert(math.sqrt(x1 * x1 + y1 * y1) > 0.03, "the flurry jitters")
		assert(math.abs(x1 - x2) + math.abs(y1 - y2) > 0.03, "a new direction ten times a second")
		local xs, ys = Ultimates.shake(line, 0.2)
		assert(xs == 0 and ys == 0, "still before anything lands")
	end,

	["the target's whole body reacts: it tips back through the flurry, arches and flips (kits-7i)"] = function()
		-- the gap study: the target hung in one upright T for every hit; now the timeline turns the whole body
		local line = Ultimates.TIMELINES.Base
		local barrage = line.barrage :: any
		-- kits-7m, the owner: "the torso should be facing the players fists": pitched FORWARD over the fists below
		-- through the whole flurry (minus is forward)
		for _, at in { barrage.from + 0.2, (barrage.from + barrage.to) / 2, barrage.to - 0.2 } do
			local tilt = Ultimates.tilt(line, at)
			-- kits-8p, the owner: "rotated a bit forward so the torso is facing directly towards the punches"
			assert(tilt.X < -45 and tilt.X > -75, `facing the fists at {at} (pitch {tilt.X})`)
		end
		-- the side they rock to changes hit to hit
		local a = Ultimates.tilt(line, barrage.from + 0.3)
		local b = Ultimates.tilt(line, barrage.from + 0.3 + 0.125)
		assert(a.Z * b.Z < 0, "rocked to alternate sides")
		-- the hook snaps them over during its freeze; upright before it
		local blow = line.blows[1]
		assert(Ultimates.tilt(line, blow.t - 0.05).Magnitude < 1, "upright before the hook lands")
		assert(Ultimates.tilt(line, blow.t + 0.1).Z > 20, "rolled over by the hook")
		-- a backflip on the uppercut's rise (kits-8a: the flight then turns ON from the last pose, see "the knockback
		-- starts on the hit", so it no longer has to end on whole turns)
		local most = 0
		for _, key in line.keys do
			if key.targetTilt then
				most = math.max(most, key.targetTilt.X)
			end
		end
		assert(most >= 180, "a flip somewhere")
	end,

	["the rush in is a flash step:there, gone a moment, there by the target, zoomed in, a drawn-back pause (kits-8n)"] = function()
		-- the owner: "instead of having a running animation towards the target at the start, i think itd be better if the
		-- player just vanishes and reappears at the location" (it replaces kits-8a's run at the lens)
		local line = Ultimates.TIMELINES.Base
		local gone = line.vanish
		assert(gone, "the attacker vanishes")
		assert(line.dash == nil, "the run is retired")
		for _, clip in line.clips or {} do
			assert(clip.name ~= "RushRun", "the run's arms are retired")
		end
		-- gone for an instant (Bleach's flash step: 1-3 frames)
		local length = gone.to - gone.from
		assert(length >= 0.05 and length <= 0.15, `gone {length} s`)
		local at: { [string]: number } = {}
		for _, cue in line.cues do
			at[cue.name] = at[cue.name] or cue.t
		end
		assert(
			at.vanish and math.abs(at.vanish - gone.from) < 1e-6,
			"the vanish effect plays as they go"
		)
		assert(
			at.appear and math.abs(at.appear - gone.to) < 1e-6,
			"the arrival effect plays as they come back"
		)
		-- they reappear already winding up: the hook lands after a SHORT pause (kits-8n)
		local hook = math.huge
		for _, blow in line.blows do
			if blow.t > gone.to then
				hook = math.min(hook, blow.t)
			end
		end
		assert(hook - gone.to <= 0.45, `they wait {hook - gone.to} s before the hook lands`)
		for _, start in { Vector3.new(0, 0, 6), Vector3.new(0, 0, 14), Vector3.new(0, 0, 30) } do
			-- still where they were until they go, at the hook's spot as they come back
			local before = Ultimates.pose(line, gone.from - 0.01, start)
			assert((before - start).Magnitude < 1e-3, `they move before they vanish from {start}`)
			local after = Ultimates.pose(line, gone.to, start)
			assert(
				(after - Ultimates.FLASH_TO).Magnitude < 1e-3,
				`they reappear off the hook's spot from {start}`
			)
			-- one camera from before they go until the hook, aimed so both spots are in the frame
			for _, t in { gone.from - 0.01, gone.to + 0.01 } do
				local a, tg = Ultimates.pose(line, t, start)
				local cam, look = Ultimates.shot(line, t, a, tg, start)
				local off =
					math.deg(math.acos(math.clamp((look - cam).Unit:Dot((a - cam).Unit), -1, 1)))
				assert(off < 22, `the attacker is {off} deg off the aim at {t} from {start}`)
			end
		end
		-- kits-8n, the owner: after the tp "the same perspective before the tp", "zoomed in to match the current position":
		-- one cut, as they reappear, from the same camera place with a narrower lens
		local before, after
		for _, shot in line.shots do
			if shot.cut and shot.t <= gone.from then
				before = shot
			elseif shot.cut and shot.t > gone.from and shot.t < hook then
				assert(after == nil, "one cut after the vanish, not more")
				after = shot
			end
		end
		assert(before and after, "the shot before the step and the zoom after it")
		assert(math.abs(after.t - gone.to) < 1e-6, "the zoom comes as they reappear")
		-- kits-8p, the owner: "i want it to not change perspective, just show the back of where the player was before
		-- dasshing (turned to look at the target) and just zoom in when the player reappears"
		assert(
			before.rel == "start" and after.rel == "start",
			"the camera stays behind where they started"
		)
		assert(before.cam.Z > 2 and before.cam.X > 0, "behind the start, on the attacker's right")
		assert((after.cam - before.cam).Magnitude < 1e-3, "the same camera place after the step")
		assert(after.lookRel == "attacker", "aimed at where they are now")
		assert(after.fov < before.fov - 15, "zoomed in")
		-- kits-8o, the owner: "the player is too close to the target, they are clipping inside of them during the windup":
		-- through the wind-up the attacker stands clear (measured on the rig: from 3 studs root to root nothing overlaps)
		local releaseAt = hook
		for _, swing in line.swings do
			if math.abs(swing.t + swing.windup - hook) < 0.011 and swing.release then
				releaseAt = swing.release
			end
		end
		local t = gone.to
		while t < releaseAt do
			local a, tg = Ultimates.pose(line, t, Vector3.new(0, 0, 12))
			assert(
				(a - tg).Magnitude >= 2.75,
				`the attacker stands {(a - tg).Magnitude} from the target at {t}`
			)
			t += 0.02
		end
		-- kits-8n, the owner: "a short pause before the hit lands ... will keep going back until it brings it forward":
		-- the hook draws back from the reappear until shortly before it lands, then snaps forward
		local hookSwing
		for _, swing in line.swings do
			if math.abs(swing.t + swing.windup - hook) < 0.011 then
				hookSwing = swing
			end
		end
		assert(
			hookSwing and hookSwing.release and hookSwing.loaded,
			"the hook is drawn back, then let go"
		)
		assert(math.abs(hookSwing.t - gone.to) < 1e-6, "the wind-up starts as they reappear")
		assert(
			hookSwing.loaded >= hookSwing.release - 1e-6,
			"still drawing back through the pause, never still"
		)
		assert(hookSwing.release - gone.to >= 0.2, "a pause before it comes forward")
		assert(hook - hookSwing.release <= 0.1, "then it snaps forward")
	end,

	["the fist lands square on the chest front at the uppercut and the haymaker (kits-8a)"] = function()
		-- the owner: "the target's torso still does not face the player's fist at the moment of impact". Measured in play
		-- (design/cutscene-study/00): a flinch turned the chest ~30 deg away on the haymaker's contact frame, and the
		-- uppercut's fist met the torso 58 deg off its front. Here the bodies are posed from the baked clips at each big
		-- contact (tests/support/Rig): the fist touches the torso, in FRONT of the chest, near its middle, driving into it.
		local Rig = require("./support/Rig")
		local Clips = require("../src/shared/Config/AnimClips")
		local UltimateClips = require("../src/shared/Config/AnimClipsUltimate")
		local line = Ultimates.TIMELINES.Base
		local function clipAt(list: { any }?, t: number): (any, number)
			local current
			for _, clip in list or {} do
				if clip.t <= t then
					current = clip
				end
			end
			if current and current.name ~= "" then
				return (UltimateClips :: any)[current.name] or (Clips :: any)[current.name],
					t - current.t
			end
			return nil, 0
		end
		local checked = 0
		for _, swing in line.swings do
			if swing.side == "Uppercut" or swing.side == "HaymakerUp" then
				local hitAt = swing.t + swing.windup
				local clip = (UltimateClips :: any)[swing.side] or (Clips :: any)[swing.side]
				local attackerAt, targetAt = Ultimates.pose(line, hitAt, Vector3.new(0, 0, 12))
				local root = Ultimates.attackerFrame(attackerAt, targetAt)
				local at = (clip.strike or 0) + (swing.contact or 0)
				local tip, motion = Rig.strike(root, clip, at)
				local _, arm = Rig.fist(Rig.parts(root, Rig.sample(clip, at))["Right Arm"])
				-- an uppercut sweeps up across the arm; the haymaker drives along it
				local drive = if swing.side == "Uppercut" then motion else arm
				local targetRoot = Ultimates.targetCFrame(
					targetAt,
					targetAt + Vector3.new(0, 0, 1),
					Ultimates.tilt(line, hitAt)
				)
				local targetClip, into = clipAt(line.targetClips, hitAt)
				assert(targetClip, `nothing holds the target at {hitAt} (the flinch would turn it)`)
				local torso = Rig.parts(targetRoot, Rig.sample(targetClip, into)).Torso
				local l = torso:PointToObjectSpace(tip)
				assert(Rig.torsoGap(torso, tip) < 0.1, `the fist misses the torso at {hitAt}`)
				assert(l.Z < -0.15, `the fist is not on the chest front at {hitAt}`)
				assert(
					math.abs(l.X) < 0.7 and math.abs(l.Y) < 0.7,
					`the fist is off the chest's middle at {hitAt}`
				)
				local square = Rig.squareness(torso, drive)
				assert(
					square < (if swing.side == "Uppercut" then 40 else 15),
					`not square at {hitAt} ({square} deg)`
				)
				checked += 1
			end
		end
		assert(checked == 2, "the uppercut and the haymaker")
	end,

	["the uppercut launches them up and back, and the dash after them covers the gap (kits-8a)"] = function()
		-- the owner: "the uppercut should launch the target farther backward, so the dash section covers a noticeably
		-- longer distance" (kits-7m: 0.2 studs of travel back)
		local line = Ultimates.TIMELINES.Base
		local start = Vector3.new(0, 0, 12)
		local upper, haymaker
		for _, swing in line.swings do
			if swing.side == "Uppercut" then
				upper = swing.t + swing.windup
			elseif swing.side == "HaymakerUp" then
				haymaker = swing.t + swing.windup
			end
		end
		local attackerAtUpper, targetAtUpper = Ultimates.pose(line, upper, start)
		local attackerAtHit, targetAtHit = Ultimates.pose(line, haymaker, start)
		local back = targetAtUpper.Z - targetAtHit.Z
		assert(back >= 8, `thrown only {back} studs back`)
		local flat =
			Vector3.new(attackerAtHit.X - attackerAtUpper.X, 0, attackerAtHit.Z - attackerAtUpper.Z)
		assert(flat.Magnitude >= 7, `the dash covers only {flat.Magnitude} studs across`)
		assert((attackerAtHit - attackerAtUpper).Magnitude >= 9, "the dash is a long one")
		-- the launch is fast at first: half of it within its first sixth
		local quarter = upper + 0.25 + 0.06
		local _, early = Ultimates.pose(line, quarter, start)
		assert(targetAtUpper.Z - early.Z > back * 0.4, "the launch starts fast")
	end,

	["the haymaker is cocked through the coil and the dash, then snaps out (kits-8a, kits-8c)"] = function()
		-- the owner on kits-7m: "an awkward windup between the dash and the final punch, where the arm rotates" (a 0.86 s
		-- coil spread over the rise). kits-8c, measured: the references load VISIBLY before the travel, hold it, and
		-- release in 1-3 frames (kits-8a's load pointed the arm at the target and read as already thrown). So: the arm's
		-- aim does not move from the end of the coil through the dive, and the strike takes 0.08 s at most.
		local Rig = require("./support/Rig")
		local UltimateClips = require("../src/shared/Config/AnimClipsUltimate")
		local clip = (UltimateClips :: any).HaymakerUp
		local root = Rig.CFrame.new()
		local function aim(at: number): any
			local _, direction = Rig.fist(Rig.parts(root, Rig.sample(clip, at))["Right Arm"])
			return direction
		end
		local cocked = aim(0.18)
		for _, at in { 0.24, 0.3, 0.34, clip.hold } do
			local turned = math.deg(math.acos(math.clamp(cocked:Dot(aim(at)), -1, 1)))
			assert(turned < 10, `the cocked arm turns {turned} deg by clip {at}`)
		end
		assert(clip.strike - clip.hold <= 0.08 + 1e-6, "the strike snaps out in 0.08 s at most")
		-- the timeline plays it 1:1 from the coil to the dive, holds it, and lets it go in the last 0.08 s
		local line = Ultimates.TIMELINES.Base
		local held = false
		for _, swing in line.swings do
			if swing.side == "HaymakerUp" and swing.loaded and swing.release then
				held = math.abs((swing.loaded - swing.t) - clip.hold) < 0.02
					and swing.t + swing.windup - swing.release <= 0.08 + 1e-6
			end
		end
		assert(held, "coiled on the clip's own clock, released in the last 0.08 s")
	end,

	["the dash is short and never slows before the contact: no glide (kits-8c)"] = function()
		-- the owner on kits-8b: "the leap + dash have really weak impact ... feels like you just glide over". Measured
		-- (design/cutscene-study/12a): Azure and Strongest Battlegrounds dash in 0.23 s at full speed and hit on arrival;
		-- ours took 0.57 s easing out, then held still 0.26 s.
		local line = Ultimates.TIMELINES.Base
		local start = Vector3.new(0, 0, 12)
		local takeoff, haymaker = 0, 0
		for _, cue in line.cues do
			if cue.name == "leap" then
				takeoff = cue.t
			elseif cue.name == "haymaker" then
				haymaker = cue.t
			end
		end
		assert(haymaker - takeoff <= 0.3 + 1e-6, `the dash takes {haymaker - takeoff} s`)
		local step = 1 / 120
		local slowest = math.huge
		local t = takeoff + 0.05
		while t <= haymaker do
			local a = Ultimates.pose(line, t - step, start)
			local b = Ultimates.pose(line, t, start)
			slowest = math.min(slowest, (b - a).Magnitude / step)
			t += step
		end
		assert(slowest > 25, `the dash drops to {slowest} studs/s before the contact`)
		-- and the launch is parked before the coil ends: 0.4 s or more of hang before the take-off
		local upper = 0
		for _, cue in line.cues do
			if cue.name == "uppercut" then
				upper = cue.t
			end
		end
		local _, a = Ultimates.pose(line, upper + 0.25 + 0.17, start)
		local _, b = Ultimates.pose(line, upper + 0.25 + 0.17 + 0.05, start)
		assert((b - a).Magnitude / 0.05 < 3, "the launch is parked by 0.17 s")
		assert(takeoff - (upper + 0.25 + 0.17) >= 0.4 - 1e-6, "the coil waits 0.4 s or more")
	end,

	["the knockback starts on the hit and never stops into the flight (kits-8a)"] = function()
		-- the owner: "knockback still appears delayed". Measured on kits-7m: 0.75 s at 0.5 studs/s after the contact, then
		-- an ease-out to 4 studs/s and a jump to 56-101 as the flight took over, and a 46 deg snap in its turn.
		local line = Ultimates.TIMELINES.Base
		local start = Vector3.new(0, 0, 12)
		-- kits-8e, the owner: "the part where the fist sinks in should be longer". So the sink, from the hit to the blast,
		-- may be slow, but it never stops; after the blast it is fast at once and speeds up into the flight.
		local haymaker, blast = 0, 0
		for _, cue in line.cues do
			if cue.name == "haymaker" then
				haymaker = cue.t
			elseif cue.name == "blast" then
				blast = cue.t
			end
		end
		assert(blast - haymaker >= 1.2, `the sink lasts {blast - haymaker} s`)
		local step = 1 / 60
		local t = haymaker + step
		local fastest = 0
		while t < line.cinematic do
			local _, a = Ultimates.pose(line, t - step, start)
			local _, b = Ultimates.pose(line, t, start)
			local speed = (b - a).Magnitude / step
			if t <= blast + 1e-6 then
				assert(speed > 0.6, `the target stalls in the sink at {t} ({speed} studs/s)`)
			else
				assert(speed > 2, `the target stalls after the blast at {t} ({speed} studs/s)`)
				fastest = math.max(fastest, speed)
			end
			t += step
		end
		assert(fastest > 10, `the knockback only reaches {fastest} studs/s after the blast`)
		-- the flight leaves at the speed the knockback reached, and its turn goes on from the last pose
		local anchor = CFrame.new(0, 0, 0)
		local _, last = Ultimates.pose(line, line.cinematic, start)
		local _, before = Ultimates.pose(line, line.cinematic - step, start)
		local carried = (last - before) / step
		local flightEnd = Vector3.new(0, -60, -120)
		local first, velocity =
			Ultimates.flight(line, anchor, last, flightEnd, CFG.FlightSeconds, 18, line.cinematic)
		assert((first.Position - last).Magnitude < 1e-3, "the flight starts where the knockback is")
		assert(
			math.abs(velocity.Magnitude - carried.Magnitude) < carried.Magnitude * 0.35,
			`speed jumps from {carried.Magnitude} to {velocity.Magnitude}`
		)
		local posed = Ultimates.targetCFrame(
			last,
			last + Vector3.new(0, 0, 1),
			Ultimates.tilt(line, line.cinematic)
		)
		local _, snap = (posed.Rotation:Inverse() * first.Rotation):ToAxisAngle()
		assert(math.deg(snap) < 2, `the turn snaps {math.deg(snap)} deg`)
	end,

	["the camera sees the haymaker as the drawn plunge does, and no darkening before it (kits-8h)"] = function()
		-- the owner: "the camera zoom should match the impact frame, and also the arm posiitoning should match the impact
		-- frame too, at least before the impact frame hits"; "right before the first impact frame the screen darkens"
		local DrawnView = require("./support/DrawnView")
		local line = Ultimates.TIMELINES.Base
		local start = Vector3.new(0, 0, 12)
		local at: { [string]: number } = {}
		for _, cue in line.cues do
			assert(cue.name ~= "darken", "the darkening before the haymaker is back")
			at[cue.name] = at[cue.name] or cue.t
		end
		-- the owner: "Hide body, keep arm": every drawn-view close-up shows the attacker's striking arm alone
		local solo = line.soloArm
		assert(solo and solo.part == "Right Arm", "the drawn view shows the striking arm alone")
		for _, s in line.shots do
			if s.rel == "target" then
				assert(
					s.t >= solo.from - 1e-6 and s.t < solo.to,
					`a drawn-view shot at {s.t} shows the attacker's body`
				)
			end
		end
		-- kits-8k: at the drawing's eye as the fist lands (the plunge frames flash a moment later), and still on its line at
		-- the end of the sink (the last drawn-view shot)
		local sinkEye = 0
		for _, s in line.shots do
			if s.rel == "target" then
				sinkEye = s.t
			end
		end
		assert(sinkEye > at.haymaker + 1, "the drawn view stays through the sink")
		for _, case in { { at.haymaker, 1, "contact" }, { sinkEye, 1, "sink" } } do
			local t, scale, name = case[1], case[2], case[3]
			local cam, look, roll = DrawnView.view(line, t, scale, start)
			local shot
			for _, s in line.shots do
				if s.rel == "target" and s.t <= t + 1e-6 then
					shot = s
				end
			end
			assert(shot, `no drawn-view shot by the {name}`)
			assert(
				(shot.cam - cam).Magnitude < 0.05,
				`the {name} camera is {(shot.cam - cam).Magnitude} studs off the drawing's line`
			)
			local dir = (shot.look - shot.cam).Unit
			local want = (look - cam).Unit
			local off = math.deg(math.acos(math.clamp(dir:Dot(want), -1, 1)))
			assert(off < 1, `the {name} camera aims {off} deg off the drawing's`)
			assert(math.abs(shot.fov - DrawnView.FOV) < 0.2, `the {name} FOV is not the drawing's`)
			assert(math.abs((shot.roll or 0) - roll) < 1, `the {name} roll is not the drawing's`)
		end
	end,

	["the flurry's fists reach the juggled torso, not short of it under the head (kits-8l)"] = function()
		-- the owner: "it looks like the barrage is hitting the head instead of the torso": measured, the fists landed 1.0-2.1
		-- studs in front of the chest (lune/flurry_check prints each punch and checks the bodies don't overlap)
		local Rig = require("./support/Rig")
		local UltimateClips = require("../src/shared/Config/AnimClipsUltimate")
		local line = Ultimates.TIMELINES.Base
		local barrage = line.barrage
		assert(barrage and barrage.clip, "a barrage clip")
		local clip = UltimateClips[barrage.clip]
		local dangleFrom = 0
		for _, c in line.targetClips or {} do
			if c.name == "Dangle" and c.t < (barrage.to or 0) then
				dangleFrom = c.t
			end
		end
		local index, total, square = 0, 0, 0
		for _, cue in line.cues do
			if cue.name == "flurryHit" then
				index += 1
				local a, tg = Ultimates.pose(line, cue.t, Vector3.new(0, 0, 12))
				local root = Ultimates.attackerFrame(a, tg)
				local arm = Rig.parts(
					root,
					Rig.sample(clip, (cue.t - barrage.from) % (clip.seconds or 1))
				)[if index % 2 == 1 then "Right Arm" else "Left Arm"]
				local tRoot = Ultimates.targetCFrame(
					tg,
					tg + Vector3.new(0, 0, 1),
					Ultimates.tilt(line, cue.t)
				)
				local parts = Rig.parts(tRoot, Rig.sample(UltimateClips.Dangle, cue.t - dangleFrom))
				local torso = parts.Torso
				local tip = Rig.fist(arm)
				local gap = Rig.torsoGap(torso, tip)
				assert(gap < 1, `flurry punch {index} stops {gap} studs short of the torso`)
				-- never on the head (the clip's two high punches meet the shoulder, beside it)
				local h = parts.Head:PointToObjectSpace(tip)
				assert(
					not (math.abs(h.X) < 0.8 and math.abs(h.Y) < 0.7 and math.abs(h.Z) < 0.7),
					`flurry punch {index} lands on the head`
				)
				total += gap
				square += Rig.squareness(torso, select(2, Rig.fist(arm)))
			end
		end
		assert(index >= 12, "a real flurry")
		assert(
			total / index < 0.6,
			`the flurry's fists stop {total / index} studs short on average`
		)
	end,
	["the release bass swells through the sink and booms on the release (kits-8t)"] = function()
		-- the owner: "having the punch sound twice isnt good, instead i want something bassy"; favourite reference: Benimaru's
		-- Crimson Moon (a swell, the boom ~1.6 s in, a drone). The bass starts so its boom lands on the release.
		local SoundCandidates = require("../src/shared/Config/SoundCandidates")
		local line = Ultimates.TIMELINES.Base
		local at: { [string]: number } = {}
		for _, cue in line.cues do
			at[cue.name] = at[cue.name] or cue.t
		end
		assert(
			at.releaseRise and at.blast and at.haymaker,
			"the bass, the release and the haymaker are cued"
		)
		local rise = at.blast - at.releaseRise
		assert(
			math.abs(rise - 1.6) < 0.05,
			`the bass starts {rise} s before the release (its boom is 1.6 s in)`
		)
		assert(
			at.releaseRise >= at.haymaker,
			"it starts with the contact, not before the fist lands"
		)
		local options = SoundCandidates.OPTIONS.ult_release
		assert(options and #options > 0, "no release bass to play")
		for _, option in options do
			local take = option.takes[1]
			assert(
				take.length - (take.start or 0) >= rise + 1.5,
				`bass "{option.name}" ends before its drone`
			)
		end
	end,
	["the barrage sound lasts the whole flurry (kits-8g)"] = function()
		-- the owner: "the barrage sound doesnt play until the end of the animation" (a 1.02 s file over 1.875 s of punches)
		local SoundCandidates = require("../src/shared/Config/SoundCandidates")
		local line = Ultimates.TIMELINES.Base
		local from, last = math.huge, 0
		for _, cue in line.cues do
			if cue.name == "barrage" then
				from = math.min(from, cue.t)
			elseif cue.name == "flurryHit" then
				last = math.max(last, cue.t)
			end
		end
		local options = SoundCandidates.OPTIONS.ult_barrage
		assert(options and #options > 0, "no barrage sound to play")
		for _, option in options do
			local take = option.takes[1]
			local plays = take.length - (take.start or 0)
			assert(
				plays >= last - from - 0.05,
				`barrage "{option.name}" plays {plays} s over {last - from} s of punches`
			)
		end
	end,

	["the fist sinks deeper through the slow part, and nothing stands still (kits-8f)"] = function()
		-- kits-8e's live check: the "sink" read as a freeze. Measured, the fist backed OUT of the chest (0.74 studs clear by
		-- the plunge) while the attacker crept at 0.2 studs/s. Now, from the end of the contact frames to the blast, the
		-- fist tip works deeper past the chest's front face, never through the back, and both bodies keep moving.
		local Rig = require("./support/Rig")
		local UltimateClips = require("../src/shared/Config/AnimClipsUltimate")
		local line = Ultimates.TIMELINES.Base
		local start = Vector3.new(0, 0, 12)
		local hit, blast = 0, 0
		for _, cue in line.cues do
			if cue.name == "haymaker" then
				hit = cue.t
			elseif cue.name == "blast" then
				blast = cue.t
			end
		end
		local slow, foldFrom = 0, 0
		for _, blow in line.blows do
			if math.abs(blow.t - hit) < 0.011 then
				slow = blow.slow or 0
			end
		end
		for _, c in line.targetClips do
			if c.name == "Fold" and c.t <= hit then
				foldFrom = c.t
			end
		end
		local clip, fold = UltimateClips.HaymakerUp, UltimateClips.Fold
		-- the fist tip past the chest's front face, and its height up the torso (-1 bottom, 0 centre, +1 top)
		local function depth(t: number): (number, number)
			local a, tg = Ultimates.pose(line, t, start)
			local tip = Rig.strike(
				Ultimates.attackerFrame(a, tg),
				clip,
				(clip.strike or 0) + (t - hit) * slow
			)
			local root =
				Ultimates.targetCFrame(tg, tg + Vector3.new(0, 0, 1), Ultimates.tilt(line, t))
			local torso = Rig.parts(root, Rig.sample(fold, t - foldFrom)).Torso
			local l = torso:PointToObjectSpace(tip)
			return l.Z + 0.5, l.Y
		end
		local from = hit + 0.1 -- (kits-8i: the drawn runs are in pauses before the hits now; the sink from a frame on)
		local step = 0.05
		local last = depth(from)
		assert(last > 0.15, `the fist is out of the chest 0.1 s after the contact ({last})`)
		-- kits-8g, the owner: "the target should be getting hit in the center of the torso not the top"
		-- (kits-8h: the centre the drawn plunge hits: the chest's true centre, the owner's pick. Measured live at ~40 fps the game
		-- matches this rig; a 0.35 offset seen at ~14 fps was a measuring artefact)
		local DENT = 0
		local _, atHit = depth(hit)
		assert(math.abs(atHit - DENT) < 0.25, `the fist lands {atHit} off the chest's centre`)
		local t = from + step
		while t <= blast + 1e-6 do
			local d, height = depth(t)
			assert(d >= last - 0.01, `the fist backs out at {t} ({last} -> {d})`)
			assert(d < 0.8, `the fist goes through the back at {t} ({d})`)
			assert(
				math.abs(height - DENT) < 0.25,
				`the fist rides off the chest's centre at {t} ({height})`
			)
			local a1, t1 = Ultimates.pose(line, t - step, start)
			local a2, t2 = Ultimates.pose(line, t, start)
			assert((a2 - a1).Magnitude / step > 0.6, `the attacker stalls in the sink at {t}`)
			assert((t2 - t1).Magnitude / step > 0.6, `the target stalls in the sink at {t}`)
			last = d
			t += step
		end
		assert(last - depth(from) > 0.15, "the fist works visibly deeper over the sink")
	end,

	["two drawn impact runs, each the moment after its blow lands (kits-8k)"] = function()
		-- the owner: "there should only be 2 impact frames"; kits-8i: "both impact frames come wayy to late, like a whole
		-- second or so after the hit itself"; kits-8k: "the frames should be right after the animation lands, not right
		-- before. but not like a lot after but like immediately"
		local line = Ultimates.TIMELINES.Base
		local at: { [string]: number } = {}
		for _, cue in line.cues do
			assert(
				cue.name ~= "soak" and cue.name ~= "release",
				`the old card run "{cue.name}" is still cued`
			)
			if not at[cue.name] or cue.name ~= "flash" then
				at[cue.name] = cue.t
			end
		end
		assert(#(line.holds or {}) == 0, "the drawn runs are not paused any more")
		for _, case in { { "burst", "uppercut", "contact" }, { "plunge", "haymaker", "plunge" } } do
			local cue, blow, run = case[1], case[2], case[3]
			assert(at[cue] and at[blow], `{cue} and {blow} are both cued`)
			local after = at[cue] - at[blow]
			assert(after > 0 and after <= 0.12, `the {run} run is {after} s after the {blow} lands`)
		end
		assert(
			at.uppercut < at.haymaker and at.haymaker < at.blast,
			"uppercut, haymaker, blast in order"
		)
		-- the heavy hit's front sound on the contact
		assert(
			math.abs(at.impact - at.haymaker) < 1e-6,
			"the heavy hit's front is not on the contact"
		)
		-- the pause mechanism (kits-8i) still works for a timeline that has one
		local paused = { holds = { { t = 1, seconds = 0.1 }, { t = 2, seconds = 0.05 } } } :: any
		assert(math.abs(Ultimates.clock(paused, 0.5) - 0.5) < 1e-6, "the clock before a pause")
		assert(math.abs(Ultimates.clock(paused, 1.05) - 1) < 1e-6, "the clock runs in a pause")
		assert(math.abs(Ultimates.clock(paused, 1.6) - 1.5) < 1e-6, "the clock after a pause")
		assert(
			math.abs(Ultimates.clock(paused, 2.12) - 2) < 1e-6,
			"the clock runs in the second pause"
		)
		for _, t in { 0.5, 1.5, 3 } do
			assert(
				math.abs(Ultimates.clock(paused, Ultimates.realAt(paused, t)) - t) < 1e-6,
				"clock and realAt disagree"
			)
		end
		-- kits-8g, the owner: an impact frame is "an instant" (Azure Flames: each drawing 1-3 frames at 30 fps)
		for name, run in Ultimates.DRAWN do
			local length = Ultimates.drawnLength(name)
			assert(length <= 0.15, `the {name} run lasts {length} s: not an instant`)
			assert(#run.show >= 3, `the {name} run flashes too few drawings to read as motion`)
			for _, drawing in run.show do
				assert(
					drawing >= 1 and drawing <= run.frames,
					`{name} shows drawing {drawing} of {run.frames}`
				)
			end
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
