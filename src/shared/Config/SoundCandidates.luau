--!strict
-- SoundCandidates - sounds to choose between, by role, until the user picks (2026-11-15). The Studio sound
-- picker (Ui/SoundPicker, P or the SOUNDS button in a Studio play test) plays each and swaps it in live;
-- SoundBank starts with option A of every role here. Once the user picks, the chosen take moves into SoundBank
-- and the role leaves this file.
--
-- ONE COMPLETE SOUND PER EVENT (kits-6c, the user: "you shouldnt combine a bunch of different sounds to mimick
-- a punch sound but instead just have an audio that matches what we actually want ... layer sounds but they
-- should all be distinct ... find the complex sound so it actually sounds like a punch and not like a musical
-- instrumental"). So no option here is built from layers: each is one already-designed file. Distinct events
-- may still overlap (the rumble under the scene, then the hit).
--
-- The punch and haymaker options are the closest the Creator Store has to the user's own references (Itadori,
-- Garou, the JJS punch ids they sent, Saitama's Serious Punch). They are COMMUNITY uploads, several of anime or
-- game audio: the user asked for sounds like those references, so they lead here (the old "licensed first"
-- rule gives way to it), but each could be taken down. Loaded in Studio 2026-11-16; `start` puts each file's
-- measured peak (PlaybackLoudness, sampled every frame) on the moment it plays; `volume` evens the peaks out.

local SoundCandidates = {}

export type Option = {
	label: string,
	name: string,
	creator: string,
	takes: { { id: number, length: number, start: number, volume: number } },
	-- how the role always plays with this pick (Sfx.Options), and other roles layered with it
	play: { [string]: any }?,
	layers: { { role: string, options: { [string]: any }?, bed: number?, delay: number? } }?,
}

-- EMPTY NOW (2026-11-16, kits-6f): the user picked ult_rush A, ult_bed B and, last, ult_haymaker B (Star Platinum
-- Punch 1), all SoundBank entries. The picker hides itself while there is nothing to choose. Add a role here
-- (ORDER, ABOUT, OPTIONS, and AUDITION if it plays as a rhythm) to offer choices again.

-- What each role is for, in the order the picker shows them.
SoundCandidates.ORDER = { "ult_barrage" } :: { string }

SoundCandidates.ABOUT = {
	ult_barrage = "Haymaker Rush's flurry: ONE rapid-punches sound over the whole 1.9 s barrage (kits-7d)",
} :: { [string]: string }

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

-- ult_barrage (kits-7d, 2026-11-17, the user: a barrage needs "one complete rapid punches sound", picked by ear):
-- community uploads that loaded in Studio on 2026-11-17, shortest first. Played from the start of the file on
-- the flurry's first punch (1.5 s); the uppercut's sound cuts off whatever is left. Volumes not yet evened out.
local function barrage(
	label: string,
	id: number,
	length: number,
	name: string,
	creator: string
): Option
	return {
		label = label,
		name = name,
		creator = `{creator} (community)`,
		takes = { { id = id, length = length, start = 0, volume = 1 } },
	}
end
SoundCandidates.OPTIONS = {
	ult_barrage = {
		barrage(
			"A",
			117958044865545,
			1.02,
			"dio punching barrage sfx 1 second",
			"Your_uncleisreal"
		),
		barrage("B", 87361464437966, 1.65, "Dragon Ball Rapid Punches SFX", "QQshka1UP"),
		barrage("C", 108575892208319, 1.70, "punch barrage sfx", "Axellatic"),
		barrage("D", 95801559782723, 1.83, "one punch man barrage hit sfx", "Axellatic"),
		barrage("E", 114289646726161, 2.12, "Rapid punches sfx", "isiahjen8"),
		barrage("F", 102850005066154, 3.51, "Multi Punch / Barrage", "Kaaizarr"),
	},
} :: { [string]: { Option } }
return SoundCandidates
