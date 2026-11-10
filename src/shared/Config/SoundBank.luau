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

export type Entry = {
	takes: { Take },
	looped: boolean,
	name: string,
	creator: string,
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

return SoundBank
