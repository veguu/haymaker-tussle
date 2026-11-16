--!strict
-- Abilities - every ability kit in the game. A kit is two skills: a MOBILITY skill on Q (gamepad B)
-- and an ATTACK skill on R (gamepad L2). Everyone owns the Base kit; the rest are bought in the menu's
-- shop with Coins. One kit is equipped at a time. The rules are in Shared/Core/AbilityKit (tested),
-- the saving in Server/Services/PlayerDataService, the keys in Client/Controllers/AbilityController.
--
-- A skill with `built = false` is a placeholder: it can be bought and equipped, and the key just says
-- it isn't made yet. To make one real: write its client handler in AbilityController.HANDLERS (and a
-- server check if it touches anyone), then set `built = true`. Skill ids are unique across all kits.
--
-- HUD names have room for about 9 characters (HudTheme.Size.ActionNameWidth).

export type Slot = "mobility" | "attack"

export type Skill = {
	id: string,
	name: string,
	blurb: string,
	built: boolean,
}

export type Kit = {
	id: string,
	name: string,
	blurb: string,
	price: number, -- Coins; 0 for the starter kit
	mobility: Skill,
	attack: Skill,
}

local Abilities = {}

-- The kit everyone owns and starts with, and falls back to when a saved kit no longer exists.
Abilities.DefaultKit = "Base"

-- Coins a brand new player starts with. A test balance until rounds pay out (user, 2026-11-12).
Abilities.StarterCoins = 1000

-- A TEST BALANCE for the people building the game (user, 2026-11-15: "me and my friend have like 20000
-- coins"). Each time one of these accounts joins, their Coins are raised to `Amount` if they have
-- fewer (never lowered), so every kit can be bought and tried. Roblox user ids: spicycaik, and the
-- other account working in the Team Create place. Empty the list to switch it off.
Abilities.TestCoins = {
	Amount = 20000,
	UserIds = { 210649679, 190554622 },
}

-- WHAT A ROUND PAYS (Core/Payout, RewardService), when it ends, to every player who started it and
-- landed at least one hit (so standing still earns nothing):
--   Played      for taking part
--   PerHit      for each hit landed on someone still in the round (punch, kick, bump, clash), up to HitCap hits
--   PerRingOut  for each ring-out credited to you
--   Win         for being the last one standing
-- A round with fewer than MinFighters at the start pays nothing. Hits on bots count like any other.
Abilities.RoundPay = {
	Played = 5,
	PerHit = 1,
	HitCap = 25,
	PerRingOut = 10,
	Win = 30,
	MinFighters = 2,
}

-- The shop and the inventory list kits in this order.
Abilities.Order =
	{ "Base", "Tempest", "Inferno", "Frost", "Beast", "Dragon", "Bruiser", "Trickster" }

Abilities.Kits = {
	Base = {
		id = "Base",
		name = "Base",
		blurb = "The starting kit. A quick burst and a heavy launcher.",
		price = 0,
		mobility = {
			id = "Dash",
			name = "Dash",
			blurb = "A short burst the way you're going. Hard to steer.",
			built = true,
		},
		attack = {
			id = "Uppercut",
			name = "Uppercut",
			blurb = "Throws them up and away. Further the faster you ran in.",
			built = true,
		},
	},
	Tempest = {
		id = "Tempest",
		name = "Tempest",
		blurb = "Wind and speed. Get in, spin, get out.",
		price = 300,
		mobility = {
			id = "Blink",
			name = "Blink",
			blurb = "Vanish and reappear a few studs ahead.",
			built = true,
		},
		attack = {
			id = "Cyclone",
			name = "Cyclone",
			blurb = "A spinning hook that hits everyone around you.",
			built = true,
		},
	},
	Inferno = {
		id = "Inferno",
		name = "Inferno",
		blurb = "Fire. Blow yourself into the air, then drop a meteor on them.",
		price = 600,
		mobility = {
			id = "Blastoff",
			name = "Blastoff",
			blurb = "An explosion under you: it throws you up and away, and knocks back everyone close.",
			built = true,
		},
		attack = {
			id = "Meteor",
			name = "Meteor",
			blurb = "A burning rock falls on the spot ahead of you and blows everyone there away.",
			built = true,
		},
	},
	Frost = {
		id = "Frost",
		name = "Frost",
		blurb = "Ice. Freeze them where they stand, then break them out of it.",
		price = 600,
		mobility = {
			id = "Frostbite",
			name = "Frostbite",
			blurb = "A dash that freezes everyone you pass in a block of ice.",
			built = true,
		},
		attack = {
			id = "Glacier",
			name = "Glacier",
			blurb = "A stomp. Solid ice bursts from the floor ahead and throws everyone into the sky.",
			built = true,
		},
	},
	Beast = {
		id = "Beast",
		name = "Beast",
		blurb = "Claws. Leap on the nearest fighter, then tear into them.",
		price = 800,
		mobility = {
			id = "Pounce",
			name = "Pounce",
			blurb = "A leap onto the nearest fighter. Where you land, everyone close is thrown.",
			built = true,
		},
		attack = {
			id = "Frenzy",
			name = "Frenzy",
			blurb = "A rush of four claw hits that drags them along. The last one throws them.",
			built = true,
		},
	},
	Dragon = {
		id = "Dragon",
		name = "Dragon",
		blurb = "Wings and breath. Rise above the fight and blast it from range.",
		price = 1000,
		mobility = {
			id = "Ascend",
			name = "Ascend",
			blurb = "A wingbeat straight up, even in the air.",
			built = true,
		},
		attack = {
			id = "Breath",
			name = "Breath",
			blurb = "A long beam of dragon fire. Pushes back everyone in its line.",
			built = true,
		},
	},
	Bruiser = {
		id = "Bruiser",
		name = "Bruiser",
		blurb = "Heavy and hard to stop.",
		price = 500,
		mobility = {
			id = "Charge",
			name = "Charge",
			blurb = "A shoulder charge that shrugs off one punch.",
			built = true,
		},
		attack = {
			id = "Slam",
			name = "Slam",
			blurb = "Pound the ground and throw everyone close into the air.",
			built = true,
		},
	},
	Trickster = {
		id = "Trickster",
		name = "Trickster",
		blurb = "Slippery. Make them miss, then punish it.",
		price = 750,
		mobility = {
			id = "Flip",
			name = "Flip",
			blurb = "A leap away from whoever is closest.",
			built = true,
		},
		attack = {
			id = "Backfist",
			name = "Backfist",
			blurb = "A fast spinning backfist that hits all round you.",
			built = true,
		},
	},
} :: { [string]: Kit }

-- THE SKILLS' NUMBERS. The Base kit's are in GameConfig (Movement.Propel*, Uppercut); every other
-- built skill's are here, by skill id.

-- Blink (Tempest, Q): you vanish and reappear `Distance` studs along the way you're moving (the way you
-- face when you're slower than `MoveMinSpeed`), keeping your speed. It stops `WallGap` short of anything
-- solid and goes through other fighters. Rules: Core/Blink.
Abilities.Blink = {
	Distance = 20,
	Cooldown = 4,
	WallGap = 2.5,
	MoveMinSpeed = 4,
}

-- Cyclone (Tempest, R): a spinning hook through the heavy-swing machinery (CombatService, side
-- "Cyclone"). It reaches all the way round (`Degrees` 180 either side) out to `Range`, hits everyone it
-- reaches once, and throws each outward in a low arc: outward speed ArcBase + ArcPerStud per stud/s the
-- thrower was going, up to ArcMax, with `Lift` upward. It doesn't root you. `SpinSeconds` is how long
-- the body takes to turn once round (only what's shown).
Abilities.Cyclone = {
	Windup = 0.24,
	Roots = false,
	RootAfter = 0,
	Cooldown = 6,
	Range = 10.5,
	Degrees = 180,
	Lift = 45,
	ArcBase = 85,
	ArcPerStud = 1.2,
	ArcMax = 160,
	SpinSeconds = 0.42,
}

-- KIT MOVES: the mobility skills (Q) of every kit but Base and Tempest, by skill id. Each runs on the
-- player's own client, as the dash and the blink do; the server checks the kit and the cooldown before
-- showing it to everyone else (AbilityService, KitMoveRequest). Rules: Core/SkillMove.
--   Kind "burst": a run of speed along the floor or through the air. `Speed` studs a second for
--     `Seconds`; `Turn` is the share of normal steering it keeps (0: dead straight, 1: all of it).
--   Kind "leap": thrown up at `Up` studs a second and forward at `Speed`.
--   Aim "keys": the way the keys point (any way, even backward); with no key down, the way you face.
--   Aim "travel": the way you're already going; from a standstill, as "keys".
--   Aim "away": straight away from the nearest fighter within `Range` studs; with nobody in range,
--     backward (the opposite of the way you face).
--   Aim "foe": at the nearest fighter within `Range` studs, landing `Short` studs before them, never
--     faster than `MaxSpeed`; with nobody in range, as "keys". `Hang` is the leap's time in the air as
--     a multiple of its time going up.
Abilities.KitMoves = {
	-- Inferno (reworked 2026-11-15; the first version, a short burst, was "too similar to the base
	-- dash"): an explosion under you. It throws you up and the way the keys point, and at that moment
	-- the server throws everyone within `Blast.Radius` studs (and `Tall` up or down) away from you at
	-- `Push`, with `Lift` upward.
	Blastoff = {
		Kind = "leap",
		Aim = "keys",
		Up = 78,
		Speed = 54,
		Cooldown = 6,
		Blast = { Radius = 10, Tall = 7, Push = 90, Lift = 48 },
	},
	-- Frost (reworked 2026-11-15; the first version was a slide the user found too like the Dash):
	-- a fast dash any way the keys point. Every fighter the server sees within `Radius` studs of you
	-- (and `Tall` studs up or down) while it runs is frozen in a block of ice for `FreezeSeconds`:
	-- they can't move or act, and the next punch or attack skill to land on them shatters it and
	-- throws them `ShatterBonus` times as hard (CombatService, StatusService).
	Frostbite = {
		Kind = "burst",
		Aim = "keys",
		Speed = 112,
		Seconds = 0.42,
		Turn = 0.15,
		Cooldown = 6,
		Freeze = { Radius = 6.5, Tall = 6, FreezeSeconds = 1.1, ShatterBonus = 1.6 },
	},
	-- Beast (reworked 2026-11-15; the first version only moved you, and was "useless"): a leap that
	-- comes down ON the nearest fighter. The server watches for the landing, and when you come down it
	-- throws everyone within `Slam.Radius` studs away at `Push`, with `Lift` upward.
	Pounce = {
		Kind = "leap",
		Aim = "foe",
		Up = 46,
		Speed = 62,
		Range = 52,
		Short = 0,
		MaxSpeed = 125,
		Hang = 1.9,
		Cooldown = 5,
		Slam = { Radius = 8.5, Tall = 6, Push = 80, Lift = 58 },
	},
	-- Dragon: nearly straight up, from the floor or the air. The best way back to the platform.
	Ascend = { Kind = "leap", Aim = "keys", Up = 95, Speed = 26, Cooldown = 7 },
	-- Bruiser: a dash that steers a little, and takes the sting out of one punch while it runs: for
	-- `ArmorSeconds` from its start, the first punch or attack skill that lands on you throws you only
	-- `ArmorShare` as hard (AbilityService, CombatService).
	Charge = {
		Kind = "burst",
		Aim = "travel",
		Speed = 80,
		Seconds = 0.6,
		Turn = 0.35,
		Cooldown = 5,
		ArmorSeconds = 0.75,
		ArmorShare = 0.2,
	},
	-- Trickster: a leap away from the nearest fighter (Aim "away"; with nobody in `Range`, backward).
	Flip = { Kind = "leap", Aim = "away", Up = 56, Speed = 62, Range = 40, Cooldown = 4.5 },
}

-- KIT SWINGS: the attack skills (R) of those kits, by skill id. Each is a heavy swing through the same
-- machinery as the Uppercut and the Cyclone (CombatService, side = the skill id, KitSwingRequest), so
-- the numbers mean what the Cyclone's do: it reaches `Degrees` either side out to `Range` and throws
-- everyone it reaches outward at ArcBase + ArcPerStud per stud/s the thrower was going (up to ArcMax),
-- with `Lift` upward. `Lunge` is a burst forward the thrower gets as the windup starts (Core/SkillMove).
-- `Clip` and `Arm` are the swing animation it borrows and the limb its trail follows.
Abilities.KitSwings = {
	-- A swing with a `Cast` is not a swing at all once it is thrown: the press, the cooldown, the
	-- windup and the animation are the same, but what happens is the cast's (Services/SkillCastService):
	--   Kind "meteor": something falls on the spot `Distance` studs ahead of where you faced at the
	--     press. It lands `Fall` seconds after the windup and throws everyone within `Radius` (and
	--     `Tall` up or down) outward from that spot at ArcBase, with `Lift`.
	--   Kind "frenzy": `Hits` hits, `Every` seconds apart, the first as the windup ends. Each reaches
	--     `Degrees` either side out to `Range` of wherever you are and face by then. All but the last
	--     drag whoever they reach along with you (`DragPush` the way you face, with `DragLift`); the
	--     last reaches all the way round you, out to `LastReach`, and throws them outward at ArcBase
	--     with `Lift`. `Lead` is how long the whole cast takes after the windup, for the recovery that
	--     follows it. DragPush stays BELOW the lunge's speed: at 72 against a 64 lunge (measured in
	--     Play, 2026-11-15) each drag shoved the target further ahead and the throw found it 12 studs
	--     away, out of reach.
	-- Inferno: slow and rooted, and it lands well away from you. The biggest blast in the game.
	Meteor = {
		Windup = 0.45,
		Roots = true,
		RootAfter = 0.35,
		Cooldown = 8,
		Range = 29,
		Degrees = 40,
		Lift = 80,
		ArcBase = 150,
		ArcPerStud = 0,
		ArcMax = 150,
		Clip = "Uppercut",
		Arm = "Right Arm",
		Cast = { Kind = "meteor", Distance = 16, Fall = 0.35, Radius = 13, Tall = 9, Lead = 0.35 },
	},
	-- Frost: a stomp, rooted. Solid ice bursts from the floor across a wide fan ahead and throws
	-- everyone it reaches into the sky; they come down near where they stood.
	Glacier = {
		Windup = 0.42,
		Roots = true,
		RootAfter = 0.25,
		Cooldown = 7,
		Range = 15,
		Degrees = 110,
		Lift = 145,
		ArcBase = 40,
		ArcPerStud = 0.3,
		ArcMax = 70,
		Clip = "Uppercut",
		Arm = "Right Arm",
	},
	-- Beast: a rush. You run forward clawing four times; whoever you catch is dragged with you and
	-- thrown by the last hit.
	Frenzy = {
		Windup = 0.12,
		Roots = false,
		RootAfter = 0,
		Cooldown = 6,
		Range = 8.5,
		Degrees = 75,
		Lift = 44,
		ArcBase = 115,
		ArcPerStud = 0,
		ArcMax = 150,
		Lunge = { Speed = 64, Seconds = 0.58 },
		Clip = "HookLeft",
		Arm = "Left Arm",
		Cast = {
			Kind = "frenzy",
			Hits = 4,
			Every = 0.14,
			Tall = 6,
			DragPush = 56,
			DragLift = 10,
			LastReach = 12,
			Lead = 0.42,
		},
	},
	-- Dragon: rooted, slow, and it reaches further than anything else in the game, in a narrow line.
	Breath = {
		Windup = 0.45,
		Roots = true,
		RootAfter = 0.3,
		Cooldown = 8,
		Range = 22,
		Degrees = 20,
		Lift = 30,
		ArcBase = 105,
		ArcPerStud = 0.5,
		ArcMax = 150,
		Clip = "HookRight",
		Arm = "Right Arm",
	},
	-- Bruiser: rooted, all the way round, and it throws high and far. The heaviest thing in the game.
	Slam = {
		Windup = 0.38,
		Roots = true,
		RootAfter = 0.25,
		Cooldown = 7,
		Range = 12,
		Degrees = 180,
		Lift = 80,
		ArcBase = 95,
		ArcPerStud = 0.6,
		ArcMax = 150,
		Clip = "Uppercut",
		Arm = "Right Arm",
	},
	-- Trickster: all the way round too, but fast and flat, on a short cooldown. `Spin` is how long the
	-- body takes to turn once round (only what's shown).
	Backfist = {
		Windup = 0.18,
		Roots = false,
		RootAfter = 0,
		Cooldown = 4.5,
		Range = 8.5,
		Degrees = 180,
		Lift = 24,
		ArcBase = 90,
		ArcPerStud = 1.3,
		ArcMax = 170,
		Spin = 0.34,
		Clip = "HookLeft",
		Arm = "Left Arm",
	},
}

-- The recovery those skills owe (Core/Endlag), on top of GameConfig.Endlag: a swing's Hit and Miss
-- seconds, a move's one number.
Abilities.Endlag = {
	MeteorHit = 0.3,
	MeteorMiss = 0.5,
	GlacierHit = 0.35,
	GlacierMiss = 0.7,
	FrenzyHit = 0.25,
	FrenzyMiss = 0.45,
	BreathHit = 0.3,
	BreathMiss = 0.6,
	Blastoff = 0.2,
	Frostbite = 0.1,
	Pounce = 0.15,
	Ascend = 0.2,
	SlamHit = 0.35,
	SlamMiss = 0.75,
	BackfistHit = 0.25,
	BackfistMiss = 0.55,
	Charge = 0.2,
	Flip = 0.15,
}

return Abilities
