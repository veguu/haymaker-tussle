--!strict
-- AnimVariants - each ability kit's own punches, made from the clips the game already has. Pure:
-- it only reads and builds clip tables (the format of Config/AnimClips), so it is tested in Lune.
--
-- WHY (the user, 2026-11-15): every kit should have "different animations ... on the basic m1
-- punches". The clips in Config/AnimClips are baked by animations/build_clips.py, which needs
-- Python and a rig solver this PC doesn't have, so a kit's punches are DERIVED from those clips with
-- three plain operations that can't produce a broken pose, because every pose they output is one the
-- solver made (or its mirror image):
--   mirrored   the same move thrown with the other side of the body.
--   reversed   the same move played backward. A rising uppercut backward is a downward chop.
--   doubled    one arm's path copied onto the other arm, mirrored and a moment later: a two-handed move.
-- Only how a punch LOOKS changes. Which swing it is, when it strikes and what it reaches are the
-- server's, and the strike still lands on the clip's Hit marker.
--
-- A pose is { rx, ry, rz, px, py, pz } per joint (degrees, studs). Mirroring left for right swaps
-- the arms and the legs and flips yaw, roll and the sideways offset (the Guard clip shows it: the
-- two arms differ in exactly those signs).

local AnimVariants = {}

export type Pose = { [string]: { number } }
export type Frame = { t: number, pose: Pose }
export type Clip = {
	loop: boolean,
	priority: string,
	seconds: number,
	strike: number?,
	hold: number?,
	frames: { Frame },
	[string]: any,
}

local OTHER_SIDE = {
	Torso = "Torso",
	Head = "Head",
	["Right Arm"] = "Left Arm",
	["Left Arm"] = "Right Arm",
	["Right Leg"] = "Left Leg",
	["Left Leg"] = "Right Leg",
}

local function round(t: number): number
	return math.floor(t * 10000 + 0.5) / 10000
end

local function mirrorValues(values: { number }): { number }
	return { values[1], -values[2], -values[3], -values[4], values[5], values[6] }
end

--- The pose with left and right swapped.
function AnimVariants.mirrorPose(pose: Pose): Pose
	local out: Pose = {}
	for joint, values in pose do
		out[OTHER_SIDE[joint] or joint] = mirrorValues(values)
	end
	return out
end

--- The clip's pose at time `t`, between its frames (held at the ends).
function AnimVariants.sample(clip: Clip, t: number): Pose
	local frames = clip.frames
	if t <= frames[1].t then
		return frames[1].pose
	end
	for index = 2, #frames do
		local after = frames[index]
		if t <= after.t then
			local before = frames[index - 1]
			local share = (t - before.t) / math.max(after.t - before.t, 1e-6)
			local out: Pose = {}
			for joint, values in before.pose do
				local target = after.pose[joint]
				if target then
					local mixed = table.create(6)
					for slot = 1, 6 do
						mixed[slot] = values[slot] + (target[slot] - values[slot]) * share
					end
					out[joint] = mixed
				else
					out[joint] = values
				end
			end
			for joint, values in after.pose do
				if out[joint] == nil then
					out[joint] = values
				end
			end
			return out
		end
	end
	return frames[#frames].pose
end

local function copyMeta(clip: Clip, frames: { Frame }): Clip
	local made = table.clone(clip) :: any
	made.frames = frames
	return made
end

--- The same clip thrown with the other side of the body.
function AnimVariants.mirrored(clip: Clip): Clip
	local frames = table.create(#clip.frames)
	for index, frame in clip.frames do
		frames[index] = { t = frame.t, pose = AnimVariants.mirrorPose(frame.pose) }
	end
	return copyMeta(clip, frames)
end

--- The same clip played backward. Its strike is still on a frame: the frame that was the strike.
--- Its hold point (where a held punch waits, drawn back) is put a little before the new strike.
function AnimVariants.reversed(clip: Clip): Clip
	local source = clip.frames
	local last = source[#source].t
	local frames = table.create(#source)
	for index = #source, 1, -1 do
		local frame = source[index]
		table.insert(frames, { t = round(last - frame.t), pose = frame.pose })
	end
	local made = copyMeta(clip, frames)
	if clip.strike then
		made.strike = round(last - clip.strike)
		made.hold = round(made.strike * 0.6)
	end
	return made
end

--- The same clip with `arm`'s path copied onto the other arm, mirrored and `lag` seconds later.
function AnimVariants.doubled(clip: Clip, arm: string, lag: number): Clip
	local other = OTHER_SIDE[arm]
	local frames = table.create(#clip.frames)
	for index, frame in clip.frames do
		local pose = table.clone(frame.pose)
		local earlier = AnimVariants.sample(clip, math.max(frame.t - lag, 0))[arm]
		if earlier then
			pose[other] = mirrorValues(earlier)
		end
		frames[index] = { t = frame.t, pose = pose }
	end
	return copyMeta(clip, frames)
end

-- WHICH CLIP EACH KIT THROWS for an ordinary punch, by the server's side ("Left", "Right"). A kit
-- that isn't here throws the boxer's hooks. The names on the right are clips in `AnimVariants.all`.
AnimVariants.Swings = {
	-- Frost: a downward chop with either hand (the uppercut, backward).
	Frost = { Left = "ChopLeft", Right = "ChopRight" },
	-- Inferno: a rising punch with either hand (the uppercut, and its mirror).
	Inferno = { Left = "RiseLeft", Right = "Uppercut" },
	-- Beast: both hands rake across, the second just behind the first.
	Beast = { Left = "RakeLeft", Right = "RakeRight" },
} :: { [string]: { [string]: string } }

--- Every clip the game plays: the baked ones in `clips` (Config/AnimClips), and the kits' own made
--- from them. A new table; `clips` is not changed.
function AnimVariants.all(clips: { [string]: Clip }): { [string]: Clip }
	local made = table.clone(clips)
	local uppercut = clips.Uppercut
	if uppercut then
		made.RiseLeft = AnimVariants.mirrored(uppercut)
		made.ChopRight = AnimVariants.reversed(uppercut)
		made.ChopLeft = AnimVariants.mirrored(made.ChopRight)
	end
	if clips.HookRight and clips.HookLeft then
		made.RakeRight = AnimVariants.doubled(clips.HookRight, "Right Arm", 0.03)
		made.RakeLeft = AnimVariants.doubled(clips.HookLeft, "Left Arm", 0.03)
	end
	return made
end

--- The clip a fighter wearing `kit` throws for the swing `side`, or nil for the boxer's own.
function AnimVariants.swing(kit: string?, side: string): string?
	local own = kit and AnimVariants.Swings[kit]
	return own and own[side]
end

return AnimVariants
