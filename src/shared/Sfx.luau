--!strict
-- Sfx: play a sound by ROLE, never by id.
--
-- Standing rule: cosmetics can never break gameplay. Every entry point here is
-- pcall-isolated and fails inert - a missing sound must never stop a shot from
-- firing or a sheep from moving.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local SoundBank = require(script.Parent.Config.SoundBank)

local Sfx = {}

local TEMPLATES = "SfxTemplates"
local TAIL = 0.5 -- grace after TimeLength before the clone is destroyed

local function templates(): Folder
	local folder = SoundService:FindFirstChild(TEMPLATES)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = TEMPLATES
		folder.Parent = SoundService
	end
	return folder :: Folder
end

local function template(role: string): Sound?
	local entry = SoundBank[role]
	if not entry then
		warn(`[Sfx] no such role: {role}`)
		return nil
	end
	local folder = templates()
	local existing = folder:FindFirstChild(role)
	if existing and existing:IsA("Sound") then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = role
	sound.SoundId = `rbxassetid://{entry.id}`
	sound.Volume = entry.volume
	sound.Looped = entry.looped
	sound.Parent = folder
	return sound
end

--- Warm every asset. Yields, so call it from a spawned thread at startup.
function Sfx.preload()
	local list = {}
	for role in SoundBank do
		local t = template(role)
		if t then
			table.insert(list, t)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end

--- Play `role`. `parent` may be a BasePart or Attachment for 3D sound, or nil
--- for a flat 2D sound. `pitchVary` is a half-range, so 0.1 gives 0.9x - 1.1x.
--- Returns the playing Sound, or nil if anything at all went wrong.
function Sfx.play(role: string, parent: Instance?, pitchVary: number?): Sound?
	local ok, result = pcall(function(): Sound?
		local source = template(role)
		if not source then
			return nil
		end
		local entry = SoundBank[role]
		local clone = source:Clone()
		if pitchVary and pitchVary > 0 then
			clone.PlaybackSpeed = 1 + (math.random() * 2 - 1) * pitchVary
		end
		clone.Parent = parent or SoundService
		clone:Play()
		if not entry.looped then
			-- PlaybackSpeed stretches real time, so scale the lifetime by it.
			Debris:AddItem(clone, entry.length / math.max(clone.PlaybackSpeed, 0.01) + TAIL)
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
