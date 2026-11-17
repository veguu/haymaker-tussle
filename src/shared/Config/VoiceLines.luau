--!strict
-- VoiceLines - the announcer's lines, in ONE place (2026-11-16).
--
-- The owner's rule: voice lines for TWO things only, "Ultimate ready!" and the last-players calls at 5, 4, 3 and
-- 2 standing. The five recordings are the owner's own audio; the cleaned files are in the vault at
-- UI Research/voice/edited/<key>.wav.
--
-- NOT UPLOADED YET: every id below is empty, so nothing is spoken. Audio uploads are limited and public-facing,
-- so they wait for the owner's word. TO TURN A LINE ON: upload its file under the experience's owner and put
-- "rbxassetid://<number>" in its `id`. Nothing else in the code names a voice asset.
--
-- `seconds` is how long each recording lasts. The popups read it even while the ids are empty: a popup stays
-- fully on screen until its line would have finished, exactly as in the mockup.

export type Line = { id: string, seconds: number }

local VoiceLines = {}

VoiceLines.Lines = {
	["ultimate-ready"] = { id = "", seconds = 1.44 },
	["five-fighters-left"] = { id = "", seconds = 1.52 },
	["four-left"] = { id = "", seconds = 1.2 },
	["three-left"] = { id = "", seconds = 1.16 },
	["final-two"] = { id = "", seconds = 1.51 },
} :: { [string]: Line }

-- Which line each last-players count speaks.
VoiceLines.Last = {
	[5] = "five-fighters-left",
	[4] = "four-left",
	[3] = "three-left",
	[2] = "final-two",
} :: { [number]: string }

VoiceLines.Volume = 1

-- The ultimate-ready SOUND (SoundBank "ult_ready", picked in kits-5f) glows for 2.6 s. The spoken line must not
-- play over it, so once "ultimate-ready" has an id the line plays INSTEAD of that sound. Set this to false to
-- keep the sound and never speak the line.
VoiceLines.UltimateLineReplacesSound = true

--- Whether a line has been uploaded.
function VoiceLines.has(key: string): boolean
	local line = VoiceLines.Lines[key]
	return line ~= nil and line.id ~= ""
end

return VoiceLines
