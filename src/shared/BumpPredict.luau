--!strict
-- BumpPredict - which collisions a player's own client handles itself.
--
-- A bump has to land the instant two bodies meet. Decided on the server, it came a good tenth of a second
-- or more late (the server sees bodies late, then the knock travels back), and at running speed players
-- were already through each other. So during a round each player's client watches its own body and,
-- the moment it touches another fighter, knocks itself back at once. The server still sees the same
-- collision: it adds the stagger and the credit, knocks bots (it owns them), and doesn't knock a player
-- whose own client already did. Outside a round (lobby, training), where who may fight whom depends on
-- rules only the server knows, the server does it all as before.
--
-- This only ever moves the player's own body, which its client already owns, so it gives a cheat nothing
-- new: a client could always ignore a knock.

local CollectionService = game:GetService("CollectionService")

local BumpPredict = {}

BumpPredict.FIGHTER_TAG = "HT_Fighter" -- RoundService: on every body still in the round
local BLOCKING = { "HT_RoundHold", "HT_Skill", "HT_Air", "HT_Clash", "HT_Stationary" }

local function free(model: Model): boolean
	if not CollectionService:HasTag(model, BumpPredict.FIGHTER_TAG) then
		return false
	end
	for _, name in BLOCKING do
		if model:GetAttribute(name) ~= nil then
			return false
		end
	end
	return true
end

--- Is a collision between these two one that each player's own client handles? Both still in the
--- round, past the countdown, and neither mid-kick, launched, in a clash or a training target.
function BumpPredict.predicted(a: Model, b: Model): boolean
	return a ~= b and free(a) and free(b)
end

return BumpPredict
