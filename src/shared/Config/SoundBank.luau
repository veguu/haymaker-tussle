--!strict
-- SoundBank: every sound this game uses, by role.
--
-- Every id below is a free Roblox Creator Store asset used BY ID. Nothing was uploaded, so none of
-- this touches the audio upload quota. ProSoundEffects and APMOfficial are Roblox's licensed partner
-- catalogue; the others are community uploads picked by an earlier pass of the roblox-sfx skill.
--
-- A role has one or more TAKES, played round-robin (never the same take twice in a row). Per take:
-- `length` is Sound.TimeLength as measured in Studio. `start` skips silence before the sound, so its
-- hit lands on the frame: the ProSoundEffects punches open with about 0.22 s of nothing. `volume`
-- evens the takes out: every take of a role peaks at about the same loudness.
--
-- Measured 2026-11-09 in a Studio client (PlaybackLoudness sampled every frame at Volume 0.05):
-- onset, peak and where it fades out are in the move-2 and move-3 entries of HANDOFF.md. Edited by hand;
-- design/sfx.json only lists the original search queries.

export type Take = {
	id: number,
	length: number,
	start: number,
	volume: number,
}

-- A layer played with a role by Sfx.playLayered: another role and how to play it.
export type Layer = {
	role: string,
	options: { [string]: any }?,
	-- A BED instead of a one-shot (Sfx.bed): it fades in on the first play, is held this many seconds past
	-- every later one, then fades out. One rumble under a whole combo instead of a thump per hit.
	bed: number?,
}

export type Entry = {
	takes: { Take },
	looped: boolean,
	name: string,
	creator: string,
	-- How this role always plays (Sfx.Options: pitch, eq, ...), under whatever the caller passes.
	play: { [string]: any }?,
	-- Other roles played with it by Sfx.playLayered, so one pick can be a whole layered sound.
	layers: { Layer }?,
}

-- The sub thump's takes (ProSoundEffects "Boom Impact, Deep Distant Thumping Hit"), shared by punch_thump, m1_hit and
-- m1_finish: see punch_thump below.
local THUMP_TAKES: { Take } = {
	{ id = 9125402735, length = 2.9, start = 0.01, volume = 0.9 },
	{ id = 9125401226, length = 2.9, start = 0.01, volume = 1.12 },
	{ id = 9125401225, length = 2.9, start = 0.01, volume = 1.0 },
	{ id = 9125402967, length = 2.9, start = 0.06, volume = 1.0 },
	{ id = 9125401391, length = 2.9, start = 0.01, volume = 1.08 },
	{ id = 9125401393, length = 2.9, start = 0.01, volume = 0.97 },
	{ id = 9125403415, length = 2.9, start = 0.04, volume = 1.0 },
	{ id = 9125403433, length = 3.0, start = 0.06, volume = 1.0 },
	{ id = 9125401975, length = 2.9, start = 0.01, volume = 1.04 },
	{ id = 9125402512, length = 3.0, start = 0.02, volume = 0.82 },
	{ id = 9125404320, length = 3.0, start = 0.05, volume = 1.0 },
}

local SoundBank: { [string]: Entry } = {
	-- Body bumps. Very quiet (peak 6 against a punch's 668): only a soft touch.
	["bump"] = {
		takes = { { id = 9119323910, length = 0.708, start = 0, volume = 0.4 } },
		looped = false,
		name = "Soccer Ball Kicks On Surfaces 4 (SFX)",
		creator = "ProSoundEffects",
	},
	["ground_break"] = {
		takes = { { id = 115163143171771, length = 1.122, start = 0.06, volume = 0.8 } },
		looped = false,
		name = "Ground Rocks Impact Small Slam",
		creator = "GleonoffG",
	},
	-- THE FROST KIT (2026-11-15). Ice breaking: a block of ice dropped on concrete, two takes. Used for
	-- the Glacier coming up, a freeze, and ice shattering (FxController sets the pitch for each).
	-- NOT YET MEASURED: `start` and `volume` are first guesses, not sampled like the rest of this file.
	["ice_shatter"] = {
		takes = {
			{ id = 9114855870, length = 2.1, start = 0, volume = 1.2 },
			{ id = 9114856215, length = 2.0, start = 0, volume = 1.2 },
		},
		looped = false,
		name = "Ice Block Drop To Concrete Shatter (SFX)",
		creator = "ProSoundEffects",
	},
	-- A thin, fast swish: the Frostbite's dash, over the ordinary gust.
	["ice_whoosh"] = {
		takes = {
			{ id = 9126283592, length = 0.7, start = 0, volume = 1.4 },
			{ id = 9126283272, length = 0.6, start = 0, volume = 1.4 },
		},
		looped = false,
		name = "Wood Swish Ruler Whoosh Fast Movement In Air (SFX)",
		creator = "ProSoundEffects",
	},
	-- The dash: a sharp, hissing gust of air. Each file swells from 0.1 s to its peak at about 0.45 s
	-- and is gone by 0.9 s, so it starts 0.3 s in, already more than half way up: a sharp start that
	-- peaks about 0.13 s after the press.
	["dash"] = {
		takes = {
			{ id = 9114157694, length = 2.29, start = 0.3, volume = 2.3 },
			{ id = 9114157695, length = 2.29, start = 0.3, volume = 2.3 },
			{ id = 9114157793, length = 2.25, start = 0.3, volume = 2.5 },
		},
		looped = false,
		name = "Doppler Whooshes Crackly Airy Bursts (SFX)",
		creator = "ProSoundEffects",
	},
	-- A dash being charged: the same gusts as `dash` from their quiet start, played slow (FxController
	-- sets the speed, rising with the charge), so it is a swell of air that builds for about a second.
	["dash_charge"] = {
		takes = {
			{ id = 9114157694, length = 2.29, start = 0.05, volume = 1.6 },
			{ id = 9114157695, length = 2.29, start = 0.05, volume = 1.6 },
		},
		looped = false,
		name = "Doppler Whooshes Crackly Airy Bursts (SFX)",
		creator = "ProSoundEffects",
	},
	-- The weight of a punch being thrown: a whoosh with a whipping thud in it (it was the dash in
	-- move-2). Each take starts so its peak lands about 0.08 s after the press, as the punch goes active.
	["swing_heavy"] = {
		takes = {
			{ id = 9126229267, length = 0.6, start = 0.1, volume = 0.88 },
			{ id = 9126229715, length = 0.91, start = 0.07, volume = 0.81 },
			{ id = 9126229710, length = 0.86, start = 0.12, volume = 0.87 },
		},
		looped = false,
		name = "Whoosh By Fast Airy Swooshing Whipping Thuds (SFX)",
		creator = "ProSoundEffects",
	},
	-- The old dash whoosh, now a soft air tail under `dash`.
	["propel"] = {
		takes = { { id = 120777847710409, length = 0.866, start = 0.05, volume = 0.8 } },
		looped = false,
		name = "momentum dash whoosh",
		creator = "Drexiit",
	},
	["launch"] = {
		takes = { { id = 80454497832356, length = 1.522, start = 0.05, volume = 0.6 } },
		looped = false,
		name = "Whoosh_8",
		creator = "NexusN51",
	},
	-- The crack of a punch landing: the transient, on top of `punch_hit`.
	["punch_crack"] = {
		takes = {
			{ id = 9117972033, length = 1.57, start = 0.209, volume = 2.0 },
			{ id = 9117971755, length = 1.62, start = 0.211, volume = 2.56 },
			{ id = 9117972070, length = 1.78, start = 0.212, volume = 2.68 },
			{ id = 9117971499, length = 1.77, start = 0.225, volume = 3.77 },
		},
		looped = false,
		name = "Punch Some Crack And Thud (SFX)",
		creator = "ProSoundEffects",
	},
	-- The body of a punch landing.
	["punch_hit"] = {
		takes = { { id = 82235785832022, length = 1.0, start = 0, volume = 0.7 } },
		looped = false,
		name = "Heavy_punch_impact_#3-1770242809040",
		creator = "MegaBloxxy",
	},
	-- A punch's WEIGHT (the user, 2026-11-16: "the punches are weak sounding and feel likes taps ... dont make
	-- the punches sound like high pitched smacks either, i want them to sound like actual heavy blows", with
	-- JoJo's "MUDA" rush as the reference, whose punches are nearly all under ~350 Hz). Gloves hitting a heavy
	-- bag hard: whump and thud. Onsets and peaks measured in a play test 2026-11-16; volumes even out the peaks
	-- (200, 75, 96, 177, 114). A fifth take (9113576289) was near silent and left out.
	["punch_body"] = {
		takes = {
			{ id = 9113570289, length = 0.48, start = 0.02, volume = 0.75 },
			{ id = 9113565281, length = 0.67, start = 0.07, volume = 2.0 },
			{ id = 9113565276, length = 0.5, start = 0.07, volume = 1.55 },
			{ id = 9113570179, length = 0.71, start = 0, volume = 0.85 },
			{ id = 9113569029, length = 0.58, start = 0.02, volume = 1.3 },
		},
		looped = false,
		name = "Boxing Hits, With Gloves, Hit Punching Bag Hard (SFX)",
		creator = "ProSoundEffects",
	},
	-- THE PUNCH'S LAYERS, round 3 (kits-5e, 2026-11-16). The user's references (JJS hit sounds the closest; also
	-- OPM, JoJo, Gojo): "every hit is mostly a huge, deep sub-bass thump (the loudest part), with a sharp crack on
	-- top that reaches the very highest frequencies, and a crunchy meaty layer in the middle". Measured in the
	-- JJS hits: all bands jump together on the hit, the sub becomes the loudest (~6 dB over the mids) from ~40 ms
	-- and decays by ~0.35 s, its pitch sweeping DOWN; mids and highs are gone after ~0.12 s.
	--
	-- The sub: ProSoundEffects "Boom Impact, Deep Distant Thumping Hit" (Stings), 11 takes. Measured in Studio:
	-- instant attack with its own mid transient (50 ms), the loudest low frequency falling from ~300 to ~70 Hz in
	-- 0.1-0.15 s (the reference's sub drop), and a long low tail (cut short for an M1, left for a finisher).
	-- `start` is each onset less 0.01 s; volumes even out RMS peaks (0.25-0.34).
	["punch_thump"] = {
		takes = THUMP_TAKES,
		looped = false,
		name = "Boom Impact Deep Distant Thumping Hits (SFX)",
		creator = "ProSoundEffects",
	},
	-- The meaty middle: ProSoundEffects "Punch Kit, Whappy Chin Sock, Beefy Hit" 1-8 (Fight - Hits). Most of its
	-- energy is 1.2-4.7 kHz, gone in 0.2-0.3 s (measured 2026-11-16).
	["punch_smack"] = {
		takes = {
			{ id = 9117969584, length = 0.49, start = 0.015, volume = 0.62 },
			{ id = 9117969687, length = 0.62, start = 0.01, volume = 0.63 },
			{ id = 9117969717, length = 0.9, start = 0.02, volume = 0.5 },
			{ id = 9117969878, length = 0.58, start = 0.005, volume = 0.57 },
			{ id = 9117969892, length = 0.66, start = 0.02, volume = 0.51 },
			{ id = 9117969990, length = 0.57, start = 0.005, volume = 0.46 },
			{ id = 9117970193, length = 0.92, start = 0.005, volume = 0.44 },
			{ id = 9117970227, length = 0.49, start = 0.01, volume = 0.52 },
		},
		looped = false,
		name = "Punch Kit Beefy Hit (SFX)",
		creator = "ProSoundEffects",
	},
	-- THE PICKS (the user, 2026-11-16, kits-5f, from the sound picker): m1_hit A, m1_finish A, ult_ready C.
	-- An M1 landing: the sub thump (the loudest; faded from 0.25 s, so ~0.4 s in all) with the meaty smack (its
	-- mids +6 dB) and the crack. Levels set by measuring the whole mix against a JJS hit in one AudioAnalyzer.
	["m1_hit"] = {
		takes = THUMP_TAKES,
		looped = false,
		name = "Boom Impact Deep Distant Thumping Hits (SFX) + Beefy Hit + Punch Crack",
		creator = "ProSoundEffects",
		play = { volume = 1.6, cut = 0.25 },
		layers = {
			{
				role = "punch_smack",
				options = { volume = 1.0, eq = { low = 0, mid = 6, high = 0 } },
			},
			{ role = "punch_crack", options = { volume = 1.0 } },
		},
	},
	-- The launching hit (hit 4 of a string, and kit hits that launch; FxController adds the launch whoosh): the
	-- same layers with the thump's tail left ~2 s, like the references' big finishers.
	["m1_finish"] = {
		takes = THUMP_TAKES,
		looped = false,
		name = "Boom Impact Deep Distant Thumping Hits (SFX), full tail + Beefy Hit + Punch Crack",
		creator = "ProSoundEffects",
		play = { volume = 2.0, cut = 2.0 },
		layers = {
			{
				role = "punch_smack",
				options = { volume = 1.0, eq = { low = 0, mid = 6, high = 0 } },
			},
			{ role = "punch_crack", options = { volume = 1.0 } },
		},
	},
	-- The ultimate meter filling (Ui/UltimateMeter plays it up to 2.6 s, nothing under it): a big beefy impact
	-- with a glowing tonal tail. Its hit is 0.07 s in.
	["ult_ready"] = {
		takes = { { id = 9116385056, length = 1.83, start = 0.07, volume = 1.1 } },
		looped = false,
		name = "Magic Burst 3 (SFX)",
		creator = "ProSoundEffects",
	},
	-- The light air of a swing, under `swing_heavy`.
	["punch_swing"] = {
		takes = { { id = 132239386768492, length = 0.416, start = 0.05, volume = 0.5 } },
		looped = false,
		name = "Punch Swing Special",
		creator = "FooledPulse",
	},
	-- Weight under heavy hits and the dash's push-off: short, deep, fast attack.
	["boom_low"] = {
		takes = { { id = 1837830213, length = 3.29, start = 0.01, volume = 0.67 } },
		looped = false,
		name = "BOOM-Deep Boom 06",
		creator = "APMOfficial",
	},
	-- The ground slam's weight: instant, with a long rumble.
	["boom_mid"] = {
		takes = { { id = 1837830667, length = 3.14, start = 0.045, volume = 0.8 } },
		looped = false,
		name = "BOOM-Mid Boom 07",
		creator = "APMOfficial",
	},
}

-- The roles still being chosen (Config/SoundCandidates, the ultimates' sounds): option A of each until the
-- user picks with the Studio sound picker.
local SoundCandidates = require(script.Parent.SoundCandidates)
for role, options in SoundCandidates.OPTIONS do
	if not SoundBank[role] and options[1] then
		local first = options[1]
		SoundBank[role] = {
			takes = first.takes,
			looped = false,
			name = first.name,
			creator = first.creator,
			play = first.play,
			layers = first.layers,
		}
	end
end

return SoundBank
