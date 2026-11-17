--!strict
-- SoundCandidates - sounds to choose between, by role, until the user picks (2026-11-15). The Studio sound
-- picker (Ui/SoundPicker, P or the SOUNDS button in a Studio play test) plays each and swaps it in live;
-- SoundBank starts with option A of every role here. Once the user picks, the chosen take moves into SoundBank
-- and the role leaves this file.
--
-- Licensed catalogue first (ProSoundEffects or APMOfficial: free inside Roblox experiences, used by id, nothing
-- uploaded); an option whose creator says "(community)" is only for the user to choose, never option A.
--
-- EMPTY NOW (2026-11-16, kits-5f): the user picked m1_hit A, m1_finish A and ult_ready C, all moved into
-- SoundBank. The picker hides itself while there is nothing to choose. Add a role here (ORDER, ABOUT, OPTIONS,
-- and AUDITION if it plays as a rhythm) to offer choices again.

local SoundCandidates = {}

export type Option = {
	label: string,
	name: string,
	creator: string,
	takes: { { id: number, length: number, start: number, volume: number } },
	-- how the role always plays with this pick (Sfx.Options), and other roles layered with it
	play: { [string]: any }?,
	layers: { { role: string, options: { [string]: any }?, bed: number? } }?,
}

-- What each role is for, in the order the picker shows them.
SoundCandidates.ORDER = {} :: { string }

SoundCandidates.ABOUT = {} :: { [string]: string }

-- How the picker plays each role, so it sounds the way the game plays it: `options` as Sfx.play takes them,
-- `beats` (seconds) to play it as a rhythm, and `with` another role layered under it the way the game does.
-- Roles not listed play 2.5 s of the file as it is.
SoundCandidates.AUDITION = {} :: {
	[string]: {
		options: { [string]: any },
		beats: { number }?,
		with: { role: string, options: { [string]: any } }?,
	},
}

SoundCandidates.OPTIONS = {} :: { [string]: { Option } }

return SoundCandidates
