--!strict
-- Quests - the daily quests on the lobby's notice board (rules in Core/Quests, counted by QuestService).
--
-- Three a day, one of each tier, never two of the same kind; a new board at 00:00 UTC. Each quest's Coins are
-- fixed when it is dealt. IDS ARE PERMANENT: saved boards hold them for a day. To retire a quest, take it out of
-- the pool (a board that holds it still finishes and pays); never reuse an id for a different quest.
--
-- THE COINS (Rewards) ARE THE OWNER'S CALL. Proposed 2026-11-19: Easy 25, Medium 50, Hard 100.

local Quests = {}

-- Off: no board, no counting, no prompt. Saved boards are kept untouched.
Quests.Enabled = true

Quests.Tiers = { "Easy", "Medium", "Hard" }
Quests.Rewards = { Easy = 25, Medium = 50, Hard = 100 }

-- kind: Rounds | Hits | RingOuts | Wins | TrainSeconds (Core/Quests.KINDS)
Quests.Pool = {
	{ id = "play_3", kind = "Rounds", tier = "Easy", goal = 3 },
	{ id = "hits_30", kind = "Hits", tier = "Easy", goal = 30 },
	{ id = "train_180", kind = "TrainSeconds", tier = "Easy", goal = 180 },
	{ id = "play_8", kind = "Rounds", tier = "Medium", goal = 8 },
	{ id = "hits_100", kind = "Hits", tier = "Medium", goal = 100 },
	{ id = "ko_3", kind = "RingOuts", tier = "Medium", goal = 3 },
	{ id = "win_1", kind = "Wins", tier = "Hard", goal = 1 },
	{ id = "ko_10", kind = "RingOuts", tier = "Hard", goal = 10 },
	{ id = "hits_250", kind = "Hits", tier = "Hard", goal = 250 },
}

-- Training time is counted in steps of this many seconds (a player's board changes at most this often).
Quests.TrainStep = 10

-- THE NOTICE BOARD, where the quests are opened: at the top of the balcony's steps (design/lobby/village.py,
-- square(): posts at u -4 and 4, d 33.5; its papers face the square). Lobby-local like Lobby.Npcs: X across from
-- the lobby's middle, Back from its viewing edge. `Reach` is how near the prompt shows; `Front` how far in front
-- of the board it stands.
Quests.Board = { X = 0, Back = 33.5, Front = 1.2, Up = 3.5, Reach = 11 }

-- how many claims a player may send in a second (the claim is one press of a button)
Quests.ClaimsPerSecond = 4

return Quests
