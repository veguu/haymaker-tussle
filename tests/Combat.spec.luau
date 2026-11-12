--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local Combat = require("../src/shared/Core/Combat")

local PUNCH: Combat.PunchSettings = {
	Cooldown = 0.32,
	CooldownTolerance = 0.06,
	Range = 5,
	TargetRadius = 1.5,
	OverlapRadius = 2.5,
	HitCancelsPunch = true,
	ComboResetSeconds = 2,
	HookOuterDegrees = 55,
	HookInnerDegrees = 20,
	UppercutDegrees = 20,
	CloseRange = 2.7,
	CloseDegrees = 100,
	VerticalLimit = 4.5,
	BufferSeconds = 0.1,
}
local KNOCK: Combat.KnockbackSettings = {
	BaseSpeed = 55,
	SpeedBonusPerStud = 0.9,
	UpwardFraction = 0.18,
	UpwardMax = 16,
	AirborneUpwardFraction = 0,
}
local STAGGER: Combat.StaggerSettings = {
	Max = 100,
	PerHit = 12,
	MaxKnockbackMultiplier = 2.5,
	RecoveryEnabled = true,
	RecoveryDelay = 4,
	RecoveryPerSecond = 10,
}

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

-- Attacker at the origin facing -Z. Angles are from straight ahead, positive to their right, +X.
local function hit(x: number, y: number, z: number, side: string?): (boolean, string?)
	return Combat.inHitbox(PUNCH, 0, 0, 0, 0, -1, x, y, z, side)
end

local function hitAt(distance: number, degrees: number, side: string?): (boolean, string?)
	local angle = math.rad(degrees)
	return hit(math.sin(angle) * distance, 0, -math.cos(angle) * distance, side)
end

return {
	["a punch from standing still still has real strength"] = function()
		assert(Combat.punchStrength(KNOCK, STAGGER, 0, 0) == 55, "expected the base strength")
	end,

	["a punch at speed is substantially stronger"] = function()
		local still = Combat.punchStrength(KNOCK, STAGGER, 0, 0)
		local fast = Combat.punchStrength(KNOCK, STAGGER, 36, 0)
		assert(fast > still * 1.5, `expected much stronger at speed: {still} vs {fast}`)
	end,

	["speed's bonus stops at SpeedBonusMax"] = function()
		local capped = table.clone(KNOCK)
		capped.SpeedBonusMax = 40
		assert(Combat.punchStrength(capped, STAGGER, 1000, 0) == 95, "the bonus wasn't capped")
		assert(Combat.punchStrength(capped, STAGGER, 10, 0) == 64, "a small bonus was changed")
	end,

	["the real settings: running more than doubles a standing punch"] = function()
		local GameConfig = require("../src/shared/Config/GameConfig")
		local knock: any = GameConfig.Knockback
		local stagger: any = GameConfig.Stagger
		local still = Combat.punchStrength(knock, stagger, 0, 0)
		local running = Combat.punchStrength(knock, stagger, 36, 0)
		assert(running >= still * 2, `running {running} vs standing {still}`)
	end,

	["stagger raises knockback up to its cap"] = function()
		assert(Combat.staggerMultiplier(STAGGER, 0) == 1, "expected 1 at no stagger")
		assert(near(Combat.staggerMultiplier(STAGGER, 50), 1.75, 0.001), "expected a straight line")
		assert(Combat.staggerMultiplier(STAGGER, 100) == 2.5, "expected the cap at full")
		assert(
			Combat.staggerMultiplier(STAGGER, 500) == 2.5,
			"the multiplier must not pass the cap"
		)
	end,

	["stagger is capped"] = function()
		assert(Combat.addStagger(STAGGER, 95) == 100, "stagger must stop at the max")
	end,

	["a punch uses the stagger from before the hit"] = function()
		local before = 0
		local strength = Combat.punchStrength(KNOCK, STAGGER, 0, before)
		local after = Combat.addStagger(STAGGER, before)
		assert(strength == 55, "this hit's stagger must not affect this hit")
		assert(
			Combat.punchStrength(KNOCK, STAGGER, 0, after) > strength,
			"it must affect the next one"
		)
	end,

	["stagger waits, then recovers, and can't go below zero"] = function()
		assert(Combat.recoverStagger(STAGGER, 50, 3.9, 1) == 50, "no recovery before the delay")
		assert(Combat.recoverStagger(STAGGER, 50, 4, 1) == 40, "expected recovery after the delay")
		assert(Combat.recoverStagger(STAGGER, 5, 4, 1) == 0, "stagger must not go negative")
	end,

	["recovery can be turned off"] = function()
		local off = table.clone(STAGGER)
		off.RecoveryEnabled = false
		assert(Combat.recoverStagger(off, 50, 100, 1) == 50, "expected no recovery when disabled")
	end,

	["upward launch is capped and absent in the air"] = function()
		local grounded, airborne = Combat.upwardSpeeds(KNOCK, 500)
		assert(grounded == 16, `expected the cap, got {grounded}`)
		assert(airborne == 0, "a target in the air must get no extra lift")
		local small = Combat.upwardSpeeds(KNOCK, 55)
		assert(near(small, 9.9, 0.001), `expected a small hop, got {small}`)
	end,

	["every swing connects straight ahead, right out to the body's edge"] = function()
		for _, side in { "Left", "Right", "Uppercut" } do
			assert(hit(0, 0, -5, side), `{side} straight ahead should hit`)
			assert(hit(0, 0, -6.45, side), `{side} should reach the edge of the body`)
			local ok, why = hit(0, 0, -6.6, side)
			assert(not ok and why == "range", `{side} just past the body is out of range`)
		end
	end,

	["being off-centre doesn't miss"] = function()
		for _, side in { "Left", "Right", "Uppercut" } do
			for _, degrees in { -35, -15, 15, 35 } do
				assert(
					hitAt(5, degrees, side),
					`{side} at {degrees} degrees and 5 studs should hit`
				)
			end
		end
	end,

	["hooks reach out to their own side, and not as far across"] = function()
		assert(hitAt(5, -60, "Left"), "a left hook reaches well out to the left")
		assert(hitAt(5, 60, "Right"), "a right hook reaches well out to the right")
		local ok, why = hitAt(5, 60, "Left")
		assert(not ok and why == "facing", "a left hook doesn't carry that far to the right")
		ok, why = hitAt(5, -60, "Right")
		assert(not ok and why == "facing", "a right hook doesn't carry that far to the left")
	end,

	["an uppercut is the narrow swing"] = function()
		local ok, why = hitAt(5, 60, "Uppercut")
		assert(not ok and why == "facing", "well off to the side at range misses an uppercut")
		ok, why = hitAt(5, -60, "Uppercut")
		assert(not ok and why == "facing", "on either side")
	end,

	["someone at your shoulder gets hit by any swing"] = function()
		for _, side in { "Left", "Right", "Uppercut" } do
			for _, degrees in { -90, -60, 60, 90 } do
				for _, distance in { 2.6, 3, 3.5, 4, 4.15 } do
					assert(
						hitAt(distance, degrees, side),
						`{side} at {degrees} degrees and {distance} studs should hit`
					)
				end
			end
		end
	end,

	["overlapping and near-zero distance hit from any direction"] = function()
		for _, side in { "Left", "Right", "Uppercut" } do
			for _, degrees in { -180, -135, -90, 0, 90, 135 } do
				for _, distance in { 0.01, 0.5, 1.5, 2.5 } do
					assert(hitAt(distance, degrees, side), `{side} {degrees} at {distance}`)
				end
			end
			assert(hit(0, 0, 0, side), `{side} exactly on top of them should hit`)
		end
	end,

	["there's no sudden cliff as someone moves round to your side"] = function()
		-- Walking outward at any angle in front, a hit must never turn into a miss and back.
		for _, side in { "Left", "Right", "Uppercut" } do
			for degrees = -180, 175, 5 do
				local missed = false
				for distance = 0.1, 7, 0.1 do
					local inside = hitAt(distance, degrees, side)
					assert(
						not (missed and inside),
						`{side} at {degrees} degrees comes back at {distance}`
					)
					missed = not inside
				end
			end
		end
		-- And the near-side reach shrinks gradually rather than falling off an edge.
		local last = math.huge
		for degrees = 100, 170, 10 do
			local reach = 0
			for distance = 0.1, 7, 0.05 do
				if hitAt(distance, degrees, "Uppercut") then
					reach = distance
				end
			end
			assert(reach <= last + 0.01, `reach grows going round at {degrees}`)
			assert(last == math.huge or last - reach < 1, `reach falls off a cliff at {degrees}`)
			last = reach
		end
	end,

	["behind you and away is still a miss"] = function()
		for _, side in { "Left", "Right", "Uppercut" } do
			local ok, why = hit(0, 0, 3.5, side)
			assert(not ok and why == "facing", `{side} just outside the overlap, behind must miss`)
			ok, why = hitAt(5, 180, side)
			assert(not ok and why == "facing", `{side} directly behind at 5 must miss`)
			ok, why = hitAt(4.5, -135, side)
			assert(not ok and why == "facing", `{side} behind on the diagonal must miss`)
		end
	end,

	["this isn't a big bubble: most directions at range still miss"] = function()
		-- Share of a full circle at 5 studs that a swing can reach.
		for _, side in { "Left", "Right", "Uppercut" } do
			local count = 0
			for degrees = 0, 359 do
				if hitAt(5, degrees, side) then
					count += 1
				end
			end
			assert(count < 125, `{side} covers {count} degrees of the circle at 5 studs`)
			assert(count > 60, `{side} covers only {count} degrees of the circle at 5 studs`)
		end
	end,

	["height is judged the same however close they are"] = function()
		local ok, why = hit(0, 5, -3, "Left")
		assert(not ok and why == "height", "too high must miss")
		ok, why = hit(0, -5, -3, "Left")
		assert(not ok and why == "height", "too low must miss")
		ok, why = hit(0, 5, 1, "Left")
		assert(not ok and why == "height", "the overlap must not reach above")
		assert(hit(0, 4.4, -3, "Left"), "just inside the limit hits")
	end,

	["landing a hit earns back some stagger, but never below zero"] = function()
		local cfg: any = { HitRelief = 6 }
		assert(Combat.relieveStagger(cfg, 42) == 36, "should take off the relief")
		assert(Combat.relieveStagger(cfg, 4) == 0, "should stop at zero")
	end,

	["swings go right hook, left hook, and round again: no uppercut in the string"] = function()
		assert(Combat.nextSwing("Left") == "Right", "left then right")
		assert(Combat.nextSwing("Right") == "Left", "right then left")
		assert(Combat.nextSwing("Uppercut") == "Right", "anything else goes back to the right")
	end,

	["a held punch throws fast; a tap, or a hold too short, takes the full windup"] = function()
		local GameConfig = require("../src/shared/Config/GameConfig")
		local punch: any = GameConfig.Punch
		assert(Combat.releaseWindup(punch, nil, 10) == punch.Windup, "a tap")
		assert(
			Combat.releaseWindup(punch, 9.99, 10) == punch.Windup,
			"a hold shorter than the draw-back"
		)
		assert(
			Combat.releaseWindup(punch, 9, 10) == punch.ReleaseWindup,
			"held: only the release is left"
		)
		assert(
			Combat.releaseWindup(punch, 10 - punch.ReadyMaxSeconds - 1, 10) == punch.Windup,
			"a stale hold"
		)
		assert(punch.ReleaseWindup < punch.Windup, "the release is quicker than a full swing")
	end,

	["the heavy uppercut always arcs: a fixed lift, further out with speed"] = function()
		local GameConfig = require("../src/shared/Config/GameConfig")
		local upper: any = GameConfig.Uppercut
		local slowOut, slowUp = Combat.uppercutArc(upper, 0, 1)
		local fastOut, fastUp = Combat.uppercutArc(upper, 40, 1)
		assert(fastOut > slowOut, "faster throws them further")
		assert(slowUp == upper.Lift and fastUp == upper.Lift, "the lift is the same at any speed")
		assert(Combat.uppercutArc(upper, 1000, 1) == upper.ArcMax, "capped")
		assert(Combat.uppercutArc(upper, 0 / 0, 1) == upper.ArcBase, "NaN counts as standing")
		assert(Combat.uppercutArc(upper, 0, 2) == upper.ArcBase * 2, "stagger scales the push")
		assert(upper.Windup > GameConfig.Punch.Windup, "telegraphed: slower than a punch")
		local punch: any = GameConfig.Punch
		assert(punch.HoldMaxSeconds < punch.ReadyMaxSeconds, "a full hold still releases fast")
	end,

	["a heavy kick launches only from speed; slower, its arc grows with speed"] = function()
		local GameConfig = require("../src/shared/Config/GameConfig")
		local kick: any = GameConfig.HeavyKick
		assert(Combat.kickLaunches(kick, kick.LaunchSpeed), "at the line it launches")
		assert(not Combat.kickLaunches(kick, kick.LaunchSpeed - 1), "under it, no launch")
		assert(not Combat.kickLaunches(kick, 0 / 0), "NaN never launches")
		local slowOut, slowUp = Combat.heavyKickArc(kick, 0, 1)
		local fastOut, fastUp = Combat.heavyKickArc(kick, 25, 1)
		assert(fastOut > slowOut and fastUp > slowUp, "faster kicks throw further and higher")
		assert(slowUp > 0, "even standing, it lifts them")
		local maxOut = Combat.heavyKickArc(kick, 1000, 1)
		assert(maxOut == kick.ArcMax, "capped")
		assert(
			kick.Windup > GameConfig.Punch.Windup,
			"the kick is telegraphed: slower than a punch"
		)
	end,

	["a pause sends the combo back to the first swing"] = function()
		assert(
			Combat.comboSwing(PUNCH, "Uppercut", 10, 9) == "Uppercut",
			"a quick punch carries on"
		)
		assert(Combat.comboSwing(PUNCH, "Uppercut", 12, 10) == "Right", "two seconds resets it")
		assert(
			Combat.comboSwing(PUNCH, "Left", 10, nil) == "Right",
			"the first punch ever is the first swing"
		)
	end,

	["whoever lands first cancels the other's punch"] = function()
		assert(Combat.punchCancelled(PUNCH, 10, 10.05), "hit during the windup must cancel")
		assert(not Combat.punchCancelled(PUNCH, 10, 9.9), "a hit before pressing changes nothing")
		assert(not Combat.punchCancelled(PUNCH, 10, nil), "never hit changes nothing")
		local off = table.clone(PUNCH)
		off.HitCancelsPunch = false
		assert(not Combat.punchCancelled(off, 10, 10.05), "the setting turns it off")
	end,

	["the drawn outline matches what really hits, for every swing"] = function()
		for _, side in { "Left", "Right", "Uppercut" } do
			local outline = Combat.hitboxOutline(PUNCH, 64, side)
			assert(#outline == 64, "expected every point")
			assert(math.abs(outline[1].z + 6.5) < 0.01, "straight ahead should reach 6.5")
			assert(math.abs(outline[33].z - 2.5) < 0.01, "straight behind is the overlap")
			for _, point in outline do
				local length = math.sqrt(point.x * point.x + point.z * point.z)
				local outX, outZ = point.x / length, point.z / length
				assert(
					hit(point.x - outX * 0.05, 0, point.z - outZ * 0.05, side),
					"just inside must hit"
				)
				assert(
					not hit(point.x + outX * 0.05, 0, point.z + outZ * 0.05, side),
					"just outside must miss"
				)
			end
		end
	end,

	["a window of checks catches a fast crossing that one check misses"] = function()
		-- The attacker runs -Z at 36, and the target runs +Z at 36 past their shoulder: the fastest
		-- closing this game normally sees. Pressed at each starting distance, does it connect?
		local windup, window, frame = 0.08, 0.05, 1 / 60
		local function connects(gap: number, side: string, sweep: boolean): boolean
			local function at(t: number): boolean
				local attackerZ = -36 * t
				local targetZ = -gap + 36 * t
				return (hit(3, 0, targetZ - attackerZ, side))
			end
			if not sweep then
				return at(windup)
			end
			local t = windup
			while t <= windup + window + 0.0001 do
				if at(t) then
					return true
				end
				t += frame
			end
			return false
		end
		local single, swept, lost = 0, 0, 0
		for gap = 0, 20, 0.1 do
			local one = connects(gap, "Left", false)
			local many = connects(gap, "Left", true)
			single += if one then 1 else 0
			swept += if many then 1 else 0
			lost += if one and not many then 1 else 0
		end
		assert(lost == 0, "the window must only ever add to what connects")
		assert(
			swept > single,
			`expected more to connect: {single} with one check, {swept} with the window`
		)
		-- It adds what 0.05 s at 72 studs/s covers, 3.6 studs, and the slim notch that the swing's two
		-- sectors leave between them along this line. It's nothing like a bubble.
		assert(swept - single <= 50, `the window adds too much: {swept - single} tenths of a stud`)
	end,

	["each swing's strike lands within its active window, once per target"] = function()
		local reached: { [string]: boolean } = {}
		local count = 0
		-- Two targets, sampled over several frames, as the service does.
		for _ = 1, 4 do
			for _, name in { "first", "second" } do
				if not reached[name] and hit(0, 0, -4, "Left") then
					reached[name] = true
					count += 1
				end
			end
		end
		assert(count == 2, `two targets in reach must count as two hits, once each, got {count}`)
	end,

	["a short press buffer forgives early presses and nothing more"] = function()
		assert(Combat.pressBuffers(PUNCH, 10, 10.05), "just ahead of ready is remembered")
		assert(Combat.pressBuffers(PUNCH, 10, 10.1), "right at the limit")
		assert(not Combat.pressBuffers(PUNCH, 10, 10.2), "a long way ahead is dropped")
		assert(Combat.bufferLive(PUNCH, 10.05, 10), "still fresh")
		assert(not Combat.bufferLive(PUNCH, 10.2, 10), "gone stale")
		assert(not Combat.bufferLive(PUNCH, 10, nil), "nothing remembered")
	end,

	["a whiff owes recovery on top of the cooldown"] = function()
		assert(not Combat.cooldownReady(PUNCH, 10.32, 10, 0.1), "the normal cooldown isn't enough")
		assert(Combat.cooldownReady(PUNCH, 10.37, 10, 0.1), "cooldown and recovery, less tolerance")
		assert(Combat.cooldownReady(PUNCH, 10.32, 10, 0), "no recovery after a hit")
	end,

	["a bump's line follows how they were moving, not where they are"] = function()
		-- A runs +X into a still B, but has already passed it: B is now behind A.
		local x, z = Combat.bumpDirection(5, 0, 36, 0, 0, 0, 0, 0)
		assert(near(x, 1, 0.001) and near(z, 0, 0.001), `expected +X, got {x}, {z}`)
		-- Head-on, either way round, the line is the same axis.
		x, z = Combat.bumpDirection(0, 0, 36, 0, 3, 0, -36, 0)
		assert(near(x, 1, 0.001) and near(z, 0, 0.001), `expected +X head-on, got {x}, {z}`)
	end,

	["a bump's line falls back to positions, then to something safe"] = function()
		local x, z = Combat.bumpDirection(0, 0, 10, 0, 0, 3, 10, 0)
		assert(near(x, 0, 0.001) and near(z, 1, 0.001), `expected toward B, got {x}, {z}`)
		x, z = Combat.bumpDirection(1, 1, 0, 0, 1, 1, 0, 0)
		assert(x == 1 and z == 0, `expected a fixed fallback, got {x}, {z}`)
	end,

	["the cooldown allows a small tolerance and nothing more"] = function()
		assert(Combat.cooldownReady(PUNCH, 10, nil), "the first punch is always ready")
		assert(not Combat.cooldownReady(PUNCH, 10.2, 10), "too soon must be refused")
		assert(Combat.cooldownReady(PUNCH, 10.27, 10), "within the tolerance must pass")
		assert(Combat.cooldownReady(PUNCH, 10.32, 10), "the full cooldown must pass")
	end,

	["the rate limit blocks floods and refills over time"] = function()
		local bucket: Combat.Bucket = { tokens = 8, at = 0 }
		local allowed = 0
		for _ = 1, 100 do
			if Combat.takeToken(bucket, 0, 8) then
				allowed += 1
			end
		end
		assert(allowed == 8, `expected 8 allowed in a burst, got {allowed}`)
		assert(Combat.takeToken(bucket, 0.5, 8), "expected a refill after half a second")
	end,

	["closing speed is positive only when approaching"] = function()
		assert(Combat.closingSpeed(0, 0, 10, 0, 5, 0, 0, 0) == 10, "one running at a still target")
		assert(Combat.closingSpeed(0, 0, 10, 0, 5, 0, -10, 0) == 20, "both running together add up")
		assert(Combat.closingSpeed(0, 0, -10, 0, 5, 0, 0, 0) < 0, "running apart is negative")
		assert(Combat.closingSpeed(0, 0, 0, 10, 5, 0, 0, 10) == 0, "running side by side is zero")
		assert(
			Combat.closingSpeed(0, 0, 10, 0, 0, 0, 0, 0) == 0,
			"exactly overlapping has no direction"
		)
	end,
}
