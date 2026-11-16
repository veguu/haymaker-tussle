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
}

local function one(id: number, length: number, volume: number?)
	return { { id = id, length = length, start = 0, volume = volume or 1 } }
end

-- What each role is for, in the order the picker shows them.
SoundCandidates.ORDER = {
	"ult_ready",
	"ult_blink",
	"ult_barrage",
	"ult_windup",
	"ult_impact",
	"ult_frame",
	"ult_haymaker",
	"ult_launch",
}

SoundCandidates.ABOUT = {
	ult_ready = "meter full / the G window opens",
	ult_blink = "blinking in behind them",
	ult_barrage = "the barrage's beat (7 hits, deep)",
	ult_windup = "the quiet beat, gathering power",
	ult_impact = "the haymaker landing (the boom)",
	ult_frame = "the impact frame's sting, on top",
	ult_haymaker = "the haymaker's amped-up punch",
	ult_launch = "them flying off the map",
}

-- How the picker plays each role, so it sounds the way the game plays it (UltimateFx, Ui/UltimateMeter):
-- `options` as Sfx.play takes them, `beats` (seconds) to play it as a rhythm, and `with` another role
-- layered under it the way the game does. Roles not listed play 2.5 s of the file as it is.
SoundCandidates.AUDITION = {
	ult_ready = {
		options = { cut = 1 },
		with = { role = "punch_sub", options = { volume = 1.1, pitch = 0.8, cut = 0.4 } },
	},
	ult_barrage = {
		options = { pitch = 0.9, volume = 1.8, cut = 0.3, eq = { low = 5, mid = 0, high = -4 } },
		beats = { 0.07, 0.3, 0.5, 0.67, 0.81, 0.92, 1.01 },
		with = { role = "punch_sub", options = { volume = 1.1, pitch = 1, cut = 0.28 } },
	},
	ult_haymaker = {
		options = { pitch = 0.82, volume = 2.6, cut = 0.7, eq = { low = 7, mid = 2, high = 0 } },
		with = { role = "punch_sub", options = { volume = 1.6, pitch = 0.8, cut = 0.5 } },
	},
} :: {
	[string]: {
		options: { [string]: any },
		beats: { number }?,
		with: { role: string, options: { [string]: any } }?,
	},
}

SoundCandidates.OPTIONS = {
	-- Meter full: SHORT but POWERFUL (the user, 2026-11-16: "i want it to be short but powerful kind of
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
	ult_blink = {
		{
			label = "A",
			name = "Atomic Whoosh Fluttering Pass Bys Fast 4",
			creator = "ProSoundEffects",
			takes = one(9113202345, 2.97),
		},
		{
			label = "B",
			name = "Atomic Whoosh Fluttering Pass Bys Fast 7",
			creator = "ProSoundEffects",
			takes = one(9113203658, 2.76),
		},
		{
			label = "C",
			name = "Spirit Pass Bys Fast Overlapping Whooshes 7",
			creator = "ProSoundEffects",
			takes = one(9119468107, 2.39),
		},
		{
			label = "D",
			name = "Fast Pass By Airy Whooshes Windy 10",
			creator = "ProSoundEffects",
			takes = one(9114374050, 1.62),
		},
	},
	-- The barrage's beat (UltimateFx plays it a little slower and warmer: pitch 0.9, lows up a bit, highs
	-- trimmed, so it stays a punch). The user, 2026-11-15: "more varied ... lower pitched and flat and bassy";
	-- then, of slowed body slams (ProSoundEffects "Body Impact", car-door hits at 0.78 with the highs cut):
	-- "dont sound like punches at all... sounds like a burp". So only real punch recordings here. Then
	-- (2026-11-16): "weak sounding ... like taps ... i want them to sound like actual heavy blows". A is now
	-- the heavy-bag glove hits (the same as SoundBank punch_body), each beat with a low boom under it
	-- (UltimateFx); B is both crack-and-thud sets in one bag.
	ult_barrage = {
		{
			label = "A",
			name = "Boxing Hits, Hit Punching Bag Hard (5 takes)",
			creator = "ProSoundEffects",
			takes = {
				{ id = 9113570289, length = 0.48, start = 0.02, volume = 0.75 },
				{ id = 9113565281, length = 0.67, start = 0.07, volume = 2.0 },
				{ id = 9113565276, length = 0.5, start = 0.07, volume = 1.55 },
				{ id = 9113570179, length = 0.71, start = 0, volume = 0.85 },
				{ id = 9113569029, length = 0.58, start = 0.02, volume = 1.3 },
			},
		},
		{
			label = "B",
			name = "Punch Some Crack And Thud, both sets (10 takes)",
			creator = "ProSoundEffects",
			takes = {
				{ id = 9117971499, length = 1.8, start = 0.22, volume = 1.6 },
				{ id = 9117972146, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117971636, length = 1.7, start = 0.22, volume = 1.6 },
				{ id = 9117972361, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117971770, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117972382, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117971755, length = 1.6, start = 0.21, volume = 1.6 },
				{ id = 9117972603, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117971909, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117972033, length = 1.6, start = 0.21, volume = 1.6 },
			},
		},
		{
			label = "C",
			name = "Punch Some Crack And Thud 1-7",
			creator = "ProSoundEffects",
			takes = {
				{ id = 9117971499, length = 1.8, start = 0.22, volume = 1.6 },
				{ id = 9117971636, length = 1.7, start = 0.22, volume = 1.6 },
				{ id = 9117971770, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117971755, length = 1.6, start = 0.21, volume = 1.6 },
				{ id = 9117971909, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117972033, length = 1.6, start = 0.21, volume = 1.6 },
			},
		},
		{
			label = "D",
			name = "Punch Some Crack And Thud (second set) 1-4",
			creator = "ProSoundEffects",
			takes = {
				{ id = 9117972146, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117972361, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117972382, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117972603, length = 1.6, start = 0.22, volume = 1.6 },
			},
		},
	},
	ult_windup = {
		{
			label = "A",
			name = "REVERSE NOISE HARD END 17",
			creator = "APMOfficial",
			takes = one(9043343896, 2.12, 0.8),
		},
		{
			label = "B",
			name = "REVERSE HARD STOP-Noise Build 01",
			creator = "APMOfficial",
			takes = one(1837834257, 3.4, 0.8),
		},
		{
			label = "C",
			name = "LONG RISER-Deep Machine Riser 04",
			creator = "APMOfficial",
			takes = one(1837834672, 26.87, 0.8),
		},
		{
			label = "D",
			name = "Ignited Rage Build 1",
			creator = "APMOfficial",
			takes = one(1835335007, 9.58, 0.8),
		},
	},
	ult_impact = {
		{
			label = "A",
			name = "Time Warp Big Explosion Blast Boom Tonal Tail 1",
			creator = "ProSoundEffects",
			takes = one(9126102254, 5.72),
		},
		{
			label = "B",
			name = "Time Warp Big Explosion Blast Boom Tonal Tail 6",
			creator = "ProSoundEffects",
			takes = one(9126102402, 5.72),
		},
		{
			label = "C",
			name = "Time Warp Big Explosion Blast Boom Tonal Tail 9",
			creator = "ProSoundEffects",
			takes = one(9126102564, 5.81),
		},
		{
			label = "D",
			name = "BOOM-Deep Boom 06",
			creator = "APMOfficial",
			takes = one(1837830213, 3.29),
		},
	},
	ult_frame = {
		{
			label = "A",
			name = "Orchestra Slammed",
			creator = "APMOfficial",
			takes = one(1843035156, 9.22, 0.8),
		},
		{
			label = "B",
			name = "End Hit",
			creator = "APMOfficial",
			takes = one(1836741215, 6.68, 0.8),
		},
		{
			label = "C",
			name = "Fatal Impact",
			creator = "APMOfficial",
			takes = one(1839696994, 5.18, 0.8),
		},
		{
			label = "D",
			name = "Bing Bang Boom",
			creator = "APMOfficial",
			takes = one(1843054069, 7.87, 0.8),
		},
	},
	-- The haymaker's own punch, replacing the bell (the user, 2026-11-15: "remove the bell sound its a bit too
	-- silly, just give like a louder cooler punch sound thats ... amped up"). UltimateFx plays it loud and a
	-- little deep with the lows pushed, layered over punch_hit and the ult_impact boom.
	ult_haymaker = {
		{
			label = "A",
			name = "Punch Some Crack And Thud 1-3",
			creator = "ProSoundEffects",
			takes = {
				{ id = 9117971499, length = 1.8, start = 0.22, volume = 1.6 },
				{ id = 9117971636, length = 1.7, start = 0.22, volume = 1.6 },
				{ id = 9117971770, length = 1.6, start = 0.22, volume = 1.6 },
			},
		},
		{
			label = "B",
			name = "Punch Some Crack And Thud (second set) 1-2",
			creator = "ProSoundEffects",
			takes = {
				{ id = 9117972146, length = 1.6, start = 0.22, volume = 1.6 },
				{ id = 9117972361, length = 1.6, start = 0.22, volume = 1.6 },
			},
		},
	},
	ult_launch = {
		{
			label = "A",
			name = "Cloth Whooshes Fast Whooshes Rumbling Pass Bys 9",
			creator = "ProSoundEffects",
			takes = one(9125442175, 2.42),
		},
		{
			label = "B",
			name = "Fast Pass By Airy Whooshes Windy 8",
			creator = "ProSoundEffects",
			takes = one(9114374049, 2.23),
		},
		{
			label = "C",
			name = "Spirit Pass Bys Fast Overlapping Whooshes 4",
			creator = "ProSoundEffects",
			takes = one(9119467121, 1.31),
		},
	},
} :: { [string]: { Option } }

return SoundCandidates
