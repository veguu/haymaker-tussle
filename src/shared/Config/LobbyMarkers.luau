--!strict
-- LobbyMarkers - the small icons floating over each keeper, board and station in the village lobby (the owner,
-- 2026-11-19: "icons on where the npcs are ... on top of the quest board ... a paper icon ... do that for
-- everything"). Drawn by the client (Controllers/LobbyMarkerController).
--
-- Places are lobby-local like GameConfig.Lobby.Npcs: X across from the lobby's middle, Back from its viewing edge,
-- Up above the ground at that spot (Core/Lobby.heightAt). Where things stand comes from design/lobby/village.py.

local LobbyMarkers = {}

LobbyMarkers.Enabled = true

-- the icon over each keeper, by the keeper's name in GameConfig.Lobby.Npcs. A keeper not listed gets none.
LobbyMarkers.Keepers = {
	["Outfitter"] = "outfit",
	["Coin Exchange"] = "coins",
	["Ranked Herald"] = "ranked",
	["Gamepass Merchant"] = "shop",
	["Moves Master"] = "moves",
	["Class Master"] = "classes",
}
-- a keeper's icon stands this far out of the shop's open front (toward the square) and this high above the
-- ground: above the awning, clear of the keeper's name tag
LobbyMarkers.KeeperOut = 5.4
LobbyMarkers.KeeperUp = 13.5

LobbyMarkers.Places = {
	-- the notice board at the top of the balcony's steps (its top bar is 8.2 up): the daily quests. Just above the
	-- board, under the bunting (at 11 the bunting hung in front of it from spawn, seen 2026-11-20)
	{ icon = "quests", X = 0, Back = 33.5, Up = 9.8 },
	-- the training grounds' main gate (its top beam is 16.2 up)
	{ icon = "training", X = 0, Back = 125.6, Up = 19.5 },
	-- the three leaderboards on training's right wall: one icon, over the middle one
	{ icon = "leaders", X = 70, Back = 171, Up = 14.5 },
	-- the obby's ramp, at its foot in the balcony's left corner
	{ icon = "obby", X = -66, Back = 9, Up = 6 },
	-- the Champion's Perch, the obby's end (its top is 29 up)
	{ icon = "perch", X = 65, Back = 10, Up = 33 },
}

-- On screen: a cream rounded tile with the icon in ink, the same size at any distance (pixels). Gone beyond
-- MaxDistance studs, and gone when you are nearer than Near (the keeper's own prompt shows there instead).
LobbyMarkers.Size = 42
LobbyMarkers.PhoneSize = 34
LobbyMarkers.MaxDistance = 120
LobbyMarkers.PhoneMaxDistance = 90
LobbyMarkers.Near = 12
-- how often the near check runs (seconds)
LobbyMarkers.Check = 0.25

return LobbyMarkers
