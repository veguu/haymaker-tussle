--!strict
-- EndlagService - the server's word on who is still recovering from a move (Core/Endlag, on
-- GameConfig.Endlag). While a fighter is in endlag, CombatService refuses a new swing or a new hold,
-- and a dash or blink isn't shown to anyone.
--
-- The services that start moves tell it: CombatService (a punch, the launching kick, the Uppercut,
-- the Cyclone, and when one lands), PropelService (a dash), AbilityService (a blink). The end of an
-- air kick or dive kick it sees for itself, from the HT_Skill attribute KickService writes.
--
-- Every time here is the server's own clock. Nothing comes from a client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Endlag = require(ReplicatedStorage.Shared.Core.Endlag)

local cfg: any = GameConfig.Endlag
local SKILL_ATTRIBUTE = "HT_Skill"

type Lock = {
	untilAt: number,
	move: string, -- the move this lock is for, and when it started: only that move's hit can cut it
	startAt: number,
}

local EndlagService = Knit.CreateService({
	Name = "EndlagService",
})

local locks: { [Model]: Lock } = setmetatable({}, { __mode = "k" }) :: any

--- Is this fighter still recovering from a move at `now` (os.clock())? With the server's slack.
function EndlagService:IsBusy(model: Model, now: number): boolean
	local lock = locks[model]
	return lock ~= nil and Endlag.busy(cfg, lock.untilAt, now, cfg.Tolerance)
end

--- A move started at `startAt`. `lead` is how long until its strike is over (0 for a dash or blink).
function EndlagService:Start(model: Model, move: string, startAt: number, lead: number?)
	local lock = locks[model]
	local untilAt = Endlag.started(cfg, move, startAt, lead, lock and lock.untilAt)
	if not lock or untilAt > lock.untilAt then
		locks[model] = { untilAt = untilAt, move = move, startAt = startAt }
	end
end

--- The attack started at `startAt` landed at `hitAt`: its lock is cut to the move's Hit seconds. A
--- lock that has since become some other move's is left alone.
function EndlagService:Landed(model: Model, move: string, startAt: number, hitAt: number)
	local lock = locks[model]
	if lock and lock.move == move and lock.startAt == startAt then
		lock.untilAt = Endlag.landed(cfg, move, lock.untilAt, hitAt)
	end
end

function EndlagService:KnitStart()
	-- An air kick or dive kick ending (landed, missed, broken off): HT_Skill goes back to nothing.
	local function onCharacter(character: Model)
		local was = character:GetAttribute(SKILL_ATTRIBUTE)
		character:GetAttributeChangedSignal(SKILL_ATTRIBUTE):Connect(function()
			local now = character:GetAttribute(SKILL_ATTRIBUTE)
			if was ~= nil and now == nil then
				self:Start(character, "AirKick", os.clock())
			end
			was = now
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return EndlagService
