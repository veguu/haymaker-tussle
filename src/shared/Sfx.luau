--!strict
-- Sfx: play a sound by ROLE, never by id.
--
-- Standing rule: cosmetics can never break gameplay. Every entry point here is
-- pcall-isolated and fails inert - a missing sound must never stop a punch from
-- landing or a body from moving.
--
-- A role's takes play round-robin, never the same one twice in a row, each from its own `start` so the
-- hit lands on the frame. Callers layer roles to build one action (a crack, a body and a boom for a
-- heavy punch): see FxController.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundBank = require(script.Parent.Config.SoundBank)

local Sfx = {}

export type Options = {
	-- Playback speed instead of the random jitter. Lower is deeper and longer.
	pitch: number?,
	-- Multiplies the take's own volume.
	volume: number?,
	-- Seconds after which it fades out (over FADE_SECONDS), for a long tail that would smear.
	cut: number?,
}

local TEMPLATES = "SfxTemplates"
local TAIL = 0.5 -- grace after the sound ends before the clone is destroyed
local FADE_SECONDS = 0.15

local lastTake: { [string]: number } = {}

local function templates(): Folder
	local folder = SoundService:FindFirstChild(TEMPLATES)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = TEMPLATES
		folder.Parent = SoundService
	end
	return folder :: Folder
end

local function template(role: string, index: number): Sound?
	local entry = SoundBank[role]
	if not entry then
		warn(`[Sfx] no such role: {role}`)
		return nil
	end
	local take = entry.takes[index]
	if not take then
		return nil
	end
	local name = `{role}_{index}`
	local folder = templates()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("Sound") then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = `rbxassetid://{take.id}`
	sound.Volume = take.volume
	sound.Looped = entry.looped
	sound.Parent = folder
	return sound
end

-- The next take to play: random, but never the one just played.
local function pickTake(role: string, count: number): number
	if count <= 1 then
		return 1
	end
	local index = math.random(1, count - 1)
	local last = lastTake[role]
	if last and index >= last then
		index += 1
	end
	lastTake[role] = index
	return index
end

--- Warm every asset. Yields, so call it from a spawned thread at startup.
function Sfx.preload()
	local list = {}
	for role, entry in SoundBank do
		for index in entry.takes do
			local t = template(role, index)
			if t then
				table.insert(list, t)
			end
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end

--- Play `role`. `parent` may be a BasePart or Attachment for 3D sound, or nil
--- for a flat 2D sound. `pitchVary` is a half-range, so 0.1 gives 0.9x - 1.1x;
--- `options.pitch` is the speed it varies around. Returns the playing Sound, or nil if anything at
--- all went wrong.
function Sfx.play(role: string, parent: Instance?, pitchVary: number?, options: Options?): Sound?
	local ok, result = pcall(function(): Sound?
		local entry = SoundBank[role]
		if not entry or #entry.takes == 0 then
			warn(`[Sfx] no such role: {role}`)
			return nil
		end
		local index = pickTake(role, #entry.takes)
		local source = template(role, index)
		if not source then
			return nil
		end
		local take = entry.takes[index]
		local clone = source:Clone()
		local pitch = if options and options.pitch then options.pitch else 1
		if pitchVary and pitchVary > 0 then
			pitch *= 1 + (math.random() * 2 - 1) * pitchVary
		end
		clone.PlaybackSpeed = pitch
		if options and options.volume then
			clone.Volume *= options.volume
		end
		clone.TimePosition = take.start
		clone.Parent = parent or SoundService
		clone:Play()
		if not entry.looped then
			-- PlaybackSpeed stretches real time, so scale the lifetime by it.
			local speed = math.max(clone.PlaybackSpeed, 0.01)
			local left = (take.length - take.start) / speed
			local cut = options and options.cut
			if cut and cut < left then
				task.delay(cut, function()
					if clone.Parent then
						TweenService:Create(clone, TweenInfo.new(FADE_SECONDS), { Volume = 0 })
							:Play()
					end
				end)
				left = cut + FADE_SECONDS
			end
			Debris:AddItem(clone, left + TAIL)
		end
		return clone
	end)
	if not ok then
		warn(`[Sfx] {role} failed inert: {result}`)
		return nil
	end
	return result
end

--- Stop a looping sound started with Sfx.play.
function Sfx.stop(sound: Sound?)
	if sound then
		pcall(function()
			sound:Stop()
			sound:Destroy()
		end)
	end
end

return Sfx
