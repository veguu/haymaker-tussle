--!strict
-- Tuning tool, not a test. Flies the game's ordinary airborne cases on the real fall rules
-- (AirRecovery.fallVelocity, the same step the client and the dummies run) and prints apex height, time
-- up, time down, how long until the fall reaches its top speed, and the speed at landing.
--
-- Run from the project folder: lune run lune/fall_sim
-- Try other values without touching the design file: FALL_SET="FallGravityScale=1.3,MaxFallSpeed=90"
local process = require("@lune/process")

local AirRecovery = require("../src/shared/Core/AirRecovery")
local GameConfig = require("../src/shared/Config/GameConfig")

local AIR: any = table.clone(GameConfig.AirRecovery :: any)
local KICK: any = GameConfig.Kick
local KNOCK: any = GameConfig.Knockback

for pair in string.gmatch(process.env.FALL_SET or "", "[^,]+") do
	local key, value = string.match(pair, "(%w+)=(.+)")
	if key and value then
		AIR[key] = tonumber(value)
	end
end

local GRAVITY = 196.2
local DT = 1 / 240

-- One flight from launch speed `vy`, landing `drop` studs below where it started.
local function fly(risingScale: number, vy: number, drop: number)
	local y, t = 0, 0
	local apex, apexAt = 0, 0
	local capAt: number? = nil
	while (t == 0 or y > -drop) and t < 20 do
		local before = vy
		-- Physics applies full gravity, then the game adjusts it, exactly as in play.
		vy = AirRecovery.fallVelocity(AIR, GRAVITY, risingScale, vy - GRAVITY * DT, DT)
		y += (before + vy) / 2 * DT
		t += DT
		if y > apex then
			apex, apexAt = y, t
		end
		if not capAt and vy <= -AIR.MaxFallSpeed + 0.01 then
			capAt = t - apexAt
		end
	end
	return apex, apexAt, t - apexAt, capAt, -vy, t
end

local cases = {
	{ "plain jump (JumpPower 50; jumping is off in the game)", 1, 50, 0 },
	{ "walk off a 10-stud ledge", 1, 0, 10 },
	{ "walk off a 30-stud ledge", 1, 0, 30 },
	{ "uppercut, no input, lands at launch height", KICK.AirGravityScale, KNOCK.UppercutLift, 0 },
	{ "uppercut, falls 30 below the platform", KICK.AirGravityScale, KNOCK.UppercutLift, 30 },
	{ "grounded punch hop (UpwardMax)", 1, KNOCK.UpwardMax, 0 },
	{ "missed jump", KICK.MissGravityScale, KICK.MissLift, 0 },
}

print(
	string.format(
		"FallGravityScale %s  FallEaseSpeed %s  MaxFallSpeed %s",
		tostring(AIR.FallGravityScale),
		tostring(AIR.FallEaseSpeed),
		tostring(AIR.MaxFallSpeed)
	)
)
print(
	"case                                                    apex   up s  down s  cap after  land speed  total s"
)
for _, case in cases do
	local apex, up, down, cap, land, total = fly(case[2], case[3], case[4])
	print(
		string.format(
			"%-55s %6.1f %6.2f %7.2f %9s %11.0f %8.2f",
			case[1],
			apex,
			up,
			down,
			if cap then string.format("%.2f", cap) else "-",
			land,
			total
		)
	)
end
