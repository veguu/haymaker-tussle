--!strict
-- EndlagController - this player's recovery after every move (Core/Endlag, on GameConfig.Endlag). While
-- it's running, no new move starts: the controllers that own the keys ask IsBusy / BusyUntil first, and
-- tell it when a move of theirs starts (Start), lands (Landed) or was refused by the server (Undo).
-- The server keeps the same lock for the attacks (EndlagService); this is what makes the keys and the
-- HUD agree with it at once.
--
-- It sees one thing for itself: a dash starting (MovementController.Propelled).
-- (The dive kick's end, read from HT_Skill, went with the dive: 2026-11-25.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Endlag = require(ReplicatedStorage.Shared.Core.Endlag)

-- GameConfig's numbers, with the kits' skills' laid over them (Config/Abilities.Endlag).
local cfg: any = Endlag.with(GameConfig.Endlag :: any, Abilities.Endlag)

local EndlagController = Knit.CreateController({
	Name = "EndlagController",
})

local busyUntil = -math.huge
local before = -math.huge -- the lock as it was before the last Start, for Undo
local lastMove: string? = nil

--- When the current endlag ends (os.clock()); a time in the past when there's none.
function EndlagController:BusyUntil(): number
	return if cfg.Enabled then busyUntil else -math.huge
end

--- Is this player still recovering from a move right now?
function EndlagController:IsBusy(): boolean
	return Endlag.busy(cfg, busyUntil, os.clock())
end

--- A move of this player's started now. `lead` is how long until its strike is over (0 or nothing
--- for a dash or blink).
function EndlagController:Start(move: string, lead: number?)
	before = busyUntil
	lastMove = move
	busyUntil = Endlag.started(cfg, move, os.clock(), lead, busyUntil)
end

--- The last attack landed (the server said so): its endlag is cut to the hit's.
function EndlagController:Landed()
	if lastMove then
		busyUntil = Endlag.landed(cfg, lastMove, busyUntil, os.clock())
	end
end

--- The server refused the last move, so it never happened: the lock goes back to what it was.
function EndlagController:Undo()
	busyUntil = before
	lastMove = nil
end

function EndlagController:KnitStart()
	Knit.GetController("MovementController").Propelled:Connect(function()
		self:Start("Dash")
	end)
	-- A new body starts with nothing to recover from.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		busyUntil, before, lastMove = -math.huge, -math.huge, nil
	end)
end

return EndlagController
