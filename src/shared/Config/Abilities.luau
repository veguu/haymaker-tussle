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
Abilities.Order = { "Base", "Tempest", "Bruiser", "Trickster" }

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
	Bruiser = {
		id = "Bruiser",
		name = "Bruiser",
		blurb = "Heavy and hard to stop.",
		price = 500,
		mobility = {
			id = "Charge",
			name = "Charge",
			blurb = "A shoulder charge that shrugs off one hit.",
			built = false,
		},
		attack = {
			id = "Slam",
			name = "Slam",
			blurb = "Pound the ground and knock everyone close off their feet.",
			built = false,
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
			blurb = "A backflip away from whoever is closest.",
			built = false,
		},
		attack = {
			id = "Backfist",
			name = "Backfist",
			blurb = "A spinning backfist that hits behind you too.",
			built = false,
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
	Range = 7.5,
	Degrees = 180,
	Lift = 38,
	ArcBase = 42,
	ArcPerStud = 0.7,
	ArcMax = 85,
	SpinSeconds = 0.42,
}

return Abilities
