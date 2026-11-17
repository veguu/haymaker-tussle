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
	-- Play only the last this-many seconds of it, so a riser's hard end lands on a moment.
	last: number?,
	-- Shifts the pitch WITHOUT changing the speed (a PitchShiftSoundEffect, 0.5 to 2): with `pitch` (which
	-- changes both) it sets speed and pitch apart, e.g. faster but lower.
	octave: number?,
	-- Tone, in decibels per band (an EqualizerSoundEffect): `low` under about 400 Hz, `mid`, `high` above
	-- about 4 kHz. Bass up and highs down make a hit sound flat and heavy.
	eq: { low: number, mid: number, high: number }?,
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
function Sfx.play(
	role: string,
	parent: Instance?,
	pitchVary: number?,
	callerOptions: Options?
): Sound?
	local ok, result = pcall(function(): Sound?
		local entry = SoundBank[role]
		if not entry or #entry.takes == 0 then
			warn(`[Sfx] no such role: {role}`)
			return nil
		end
		-- The role's own way of playing (entry.play) under the caller's: the caller wins, except that pitch
		-- and volume multiply, so a louder call of a deep role stays deep.
		local options: Options? = callerOptions
		if entry.play then
			local merged: { [string]: any } = table.clone(entry.play)
			for key, value in (callerOptions or {}) :: { [string]: any } do
				if (key == "pitch" or key == "volume") and merged[key] then
					merged[key] *= value
				else
					merged[key] = value
				end
			end
			options = merged :: any
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
		if options and options.octave then
			local shift = Instance.new("PitchShiftSoundEffect")
			shift.Octave = math.clamp(options.octave, 0.5, 2)
			shift.Parent = clone
		end
		if options and options.eq then
			local tone = Instance.new("EqualizerSoundEffect")
			tone.LowGain = options.eq.low
			tone.MidGain = options.eq.mid
			tone.HighGain = options.eq.high
			tone.Parent = clone
		end
		local from = take.start
		if options and options.last then
			from = math.max(take.length - options.last * clone.PlaybackSpeed, take.start)
		end
		clone.TimePosition = from
		clone.Parent = parent or SoundService
		clone:Play()
		if not entry.looped then
			-- PlaybackSpeed stretches real time, so scale the lifetime by it.
			local speed = math.max(clone.PlaybackSpeed, 0.01)
			local left = (take.length - from) / speed
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

--- Play `role` and every layer its entry lists (SoundBank Entry.layers), as one sound. A caller's
--- `volume` scales the layers too; a layer's `delay` starts it that much later. Returns the main Sound, and
--- `into` (when given) collects every Sound it starts, the delayed ones as they start, so a caller can
--- stop the whole layered sound at once.
function Sfx.playLayered(
	role: string,
	parent: Instance?,
	pitchVary: number?,
	options: Options?,
	into: { Sound }?
): Sound?
	local main = Sfx.play(role, parent, pitchVary, options)
	if main and into then
		table.insert(into, main)
	end
	local entry = SoundBank[role]
	local scale = if options and options.volume then options.volume else 1
	for _, layer in (entry and entry.layers) or {} do
		local layerOptions: { [string]: any } = table.clone(layer.options or {})
		layerOptions.volume = (layerOptions.volume or 1) * scale
		if layer.bed then
			Sfx.bed(layer.role, parent, layer.bed, layerOptions :: any)
		else
			local function start()
				local played = Sfx.play(layer.role, parent, pitchVary, layerOptions :: any)
				if played and into then
					table.insert(into, played)
				end
			end
			if layer.delay and layer.delay > 0 then
				task.delay(layer.delay, start)
			else
				start()
			end
		end
	end
	return main
end

-- The beds playing now, by role, then by what they're on (false: flat, 2D).
local beds: { [string]: { [any]: { sound: Sound, untilAt: number, volume: number } } } = {}
local BED_FADE_IN = 0.05
local BED_FADE_OUT = 0.3

--- A BED (2026-11-16, kits-5b): one sound held under a run of plays rather than one per play. The first call
--- starts `role` (from its take's `start`, which should sit in the middle of a long file so there's no attack)
--- and fades it in over BED_FADE_IN; every later call on the same `parent` within `hold` seconds keeps it
--- going; `hold` seconds after the last call it fades out over BED_FADE_OUT. The punch references keep their
--- weight in a steady rumble like this, never in a thump on each hit. Returns the Sound.
local function bedUnsafe(role: string, parent: Instance?, hold: number, options: Options?): Sound?
	local slot = beds[role]
	if not slot then
		slot = setmetatable({}, { __mode = "k" }) :: any
		beds[role] = slot
	end
	local key: any = parent or false
	local now = os.clock()
	local playing = slot[key]
	if playing and playing.sound.Parent and playing.sound.IsPlaying then
		playing.untilAt = now + hold
		return playing.sound
	end
	local quiet: { [string]: any } = table.clone((options or {}) :: any)
	quiet.cut = nil
	local sound = Sfx.play(role, parent, nil, quiet :: any)
	if not sound then
		return nil
	end
	local full = sound.Volume
	sound.Volume = 0
	TweenService:Create(sound, TweenInfo.new(BED_FADE_IN), { Volume = full }):Play()
	local bed = { sound = sound, untilAt = now + hold, volume = full }
	slot[key] = bed
	local function check()
		if slot[key] ~= bed then
			return
		end
		local left = bed.untilAt - os.clock()
		if left > 0.01 then
			task.delay(left, check)
			return
		end
		slot[key] = nil
		if sound.Parent then
			TweenService:Create(sound, TweenInfo.new(BED_FADE_OUT), { Volume = 0 }):Play()
			Debris:AddItem(sound, BED_FADE_OUT + 0.05)
		end
	end
	task.delay(hold, check)
	return sound
end

function Sfx.bed(role: string, parent: Instance?, hold: number, options: Options?): Sound?
	local ok, result = pcall(bedUnsafe, role, parent, hold, options)
	if not ok then
		warn(`[Sfx] bed {role} failed inert: {result}`)
		return nil
	end
	return result
end

--- Swaps what `role` plays, live (the Studio sound picker). Its cached templates are dropped so the next
--- play uses the new takes.
function Sfx.setRole(role: string, entry: SoundBank.Entry)
	SoundBank[role] = entry
	lastTake[role] = nil
	local folder = templates()
	for _, item in folder:GetChildren() do
		if string.sub(item.Name, 1, #role + 1) == `{role}_` then
			item:Destroy()
		end
	end
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
