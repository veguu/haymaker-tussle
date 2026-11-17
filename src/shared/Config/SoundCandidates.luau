--!strict
-- SoundCandidates - sounds to choose between, by role, until the user picks (2026-11-15). The Studio sound
-- picker (Ui/SoundPicker, F7 in a Studio play test) plays each and swaps it in live; SoundBank starts
-- with option A of every role here. Once the user picks, the chosen take moves into SoundBank and the role
-- leaves this file.
--
-- Every id came back from a Creator Store search on 2026-11-15 and is Roblox's licensed catalogue
-- (ProSoundEffects or APMOfficial: free inside Roblox experiences, used by id, nothing uploaded), except
-- options whose creator says "(community)": those are only for the user to choose, never option A. Lengths
-- are Sound.TimeLength measured in Studio on 2026-11-15; `start` 0 until each pick's onset is measured.

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

-- ProSoundEffects "Punch Kit, Whappy Chin Sock, Beefy Hit" 1-8 (category Fight - Hits): designed fight
-- punches. Measured in Studio 2026-11-16 (AudioAnalyzer, quarter speed for timing): each starts 16-32 ms in,
-- peaks 27-64 ms in, is gone by 0.2-0.32 s, its lows gone within 0.1-0.2 s (no ringing boom). Most of their
-- energy is above 1.2 kHz, so alone they lean crisp: the options pair them with the heavy-bag body.
-- Volumes even out their RMS peaks (0.48 to 0.68) at about the loudness of the old crack + body + boom.
local BEEFY = {
	{ id = 9117969584, length = 0.49, start = 0.015, volume = 0.62 },
	{ id = 9117969687, length = 0.62, start = 0.01, volume = 0.63 },
	{ id = 9117969717, length = 0.9, start = 0.02, volume = 0.5 },
	{ id = 9117969878, length = 0.58, start = 0.005, volume = 0.57 },
	{ id = 9117969892, length = 0.66, start = 0.02, volume = 0.51 },
	{ id = 9117969990, length = 0.57, start = 0.005, volume = 0.46 },
	{ id = 9117970193, length = 0.92, start = 0.005, volume = 0.44 },
	{ id = 9117970227, length = 0.49, start = 0.01, volume = 0.52 },
}
-- A hit with no low end at all (EqualizerSoundEffect: everything under ~400 Hz down 40 dB): the references put
-- no thump on the hit. The weight comes from the rumble bed instead.
local NO_LOWS = { low = -40, mid = 0, high = 0 }
-- How long a rumble bed holds past each hit before it fades: about the reference's ~0.6 s, so a string pressed a
-- little slower than the cooldown (measured: ~0.45-0.55 s between hits) still keeps ONE rumble going.
local BED_HOLD = 0.6

-- What each role is for, in the order the picker shows them.
SoundCandidates.ORDER = {
	"m1_hit",
	"ult_ready",
}

SoundCandidates.ABOUT = {
	m1_hit = "an M1 landing (plays a 4-hit string)",
	ult_ready = "meter full / the G window opens",
}

-- How the picker plays each role, so it sounds the way the game plays it (UltimateFx, Ui/UltimateMeter):
-- `options` as Sfx.play takes them, `beats` (seconds) to play it as a rhythm, and `with` another role
-- layered under it the way the game does. Roles not listed play 2.5 s of the file as it is.
SoundCandidates.AUDITION = {
	-- the four punches of a string, at the speed you can press them
	m1_hit = {
		options = {},
		beats = { 0, 0.32, 0.64, 0.96 },
	},
	ult_ready = {
		options = { cut = 1 },
		with = { role = "punch_sub", options = { volume = 1.1, pitch = 0.8, cut = 0.4 } },
	},
} :: {
	[string]: {
		options: { [string]: any },
		beats: { number }?,
		with: { role: string, options: { [string]: any } }?,
	},
}

SoundCandidates.OPTIONS = {
	-- An M1 landing, the whole punch. Round 2 (kits-5b, 2026-11-16). The user, of round 1 (every option a short
	-- low thump on the hit): "still sounds nothing like the references ... still just sounds like one of those
	-- low sounding drums". Measured in the references: NO low transient on the hit; the hit is a 25 ms crack in
	-- the mids and highs only, and the weight is a steady noisy rumble under ~140 Hz held ~0.6 s (Itadori), or
	-- noise bursts spread over every band (MUDA). So here every hit has its lows CUT (no thump at all), and the
	-- weight is one RUMBLE BED (Sfx.bed) that swells in on the first hit and holds through the string.
	-- All licensed (ProSoundEffects).
	m1_hit = {
		{
			label = "A",
			name = "Beefy Hit, lows cut + deep rumble bed",
			creator = "ProSoundEffects",
			takes = BEEFY,
			play = { eq = NO_LOWS },
			layers = { { role = "punch_rumble_low", bed = BED_HOLD } },
		},
		{
			label = "B",
			name = "Beefy Hit, lows cut + rough crumbling rumble bed",
			creator = "ProSoundEffects",
			takes = BEEFY,
			play = { eq = NO_LOWS },
			layers = { { role = "punch_rumble_rough", bed = BED_HOLD } },
		},
		{
			label = "C",
			name = "Punch crack, lows cut + deep rumble bed",
			creator = "ProSoundEffects",
			takes = {
				{ id = 9117972033, length = 1.57, start = 0.209, volume = 2.0 },
				{ id = 9117971755, length = 1.62, start = 0.211, volume = 2.56 },
				{ id = 9117972070, length = 1.78, start = 0.212, volume = 2.68 },
				{ id = 9117971499, length = 1.77, start = 0.225, volume = 3.77 },
			},
			play = { eq = NO_LOWS, volume = 1.2 },
			layers = { { role = "punch_rumble_low", bed = BED_HOLD } },
		},
		{
			label = "D",
			name = "Beefy Hit, lows cut, NO bed (the smack alone, to compare)",
			creator = "ProSoundEffects",
			takes = BEEFY,
			play = { eq = NO_LOWS },
		},
	}, -- Meter full: SHORT but POWERFUL (the user, 2026-11-16: "i want it to be short but powerful kind of
	-- notificaition sound", after hype stings, charge-ups and a sword whip were all wrong). A-C are
	-- ProSoundEffects "Magic Burst" stings: one big beefy impact with a glowing tonal tail, played 1 s from the
	-- hit, with a low boom under it (Ui/UltimateMeter). D is the APM brass hype sting cut as short; E a
	-- community synth charge-up (says it is original) for the user to choose only. Measured in a play test
	-- 2026-11-16 (hits at 0.09, 0.09 and 0.28 s); volumes even out the peaks (184, 259, 282, 419, 415).
	ult_ready = {
		{
			label = "A",
			name = "Magic Burst 3, short (big beefy impact, glowing tail)",
			creator = "ProSoundEffects",
			takes = { { id = 9116385056, length = 1.83, start = 0.07, volume = 1.1 } },
		},
		{
			label = "B",
			name = "Magic Burst 5 (big beefy impact, glowing tail)",
			creator = "ProSoundEffects",
			takes = { { id = 9116385087, length = 2.27, start = 0.07, volume = 0.8 } },
		},
		{
			label = "C",
			name = "Magic Burst 4 (big beefy impact, glowing tail)",
			creator = "ProSoundEffects",
			takes = { { id = 9116384762, length = 2.69, start = 0.26, volume = 0.75 } },
		},
		{
			label = "D",
			name = "Hustler Sting 2, cut short (brass hype sting)",
			creator = "APMOfficial",
			takes = { { id = 9047100306, length = 4.36, start = 0.12, volume = 0.5 } },
		},
		{
			label = "E",
			name = "Energy Charge Up (original synth)",
			creator = "DailySoundsFX (community)",
			takes = { { id = 75223250925800, length = 1.04, start = 0, volume = 0.5 } },
		},
	},
} :: { [string]: { Option } }

return SoundCandidates
