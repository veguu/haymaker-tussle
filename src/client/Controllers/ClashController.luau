--!strict
-- ClashController - what a clash looks like on this client: the barrage on both fighters, the impacts
-- between them, the winner's finishing swing, the bounce off a third party, and, for the two in it,
-- the contest bar. The server decides all of it. The tapping itself comes through CombatController,
-- because it's the same button as punching.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local ClashBar = require(script.Parent.Parent.Ui.ClashBar)

local cfg = GameConfig.Clash
local FINISH_SWING = "Right"

local ClashController = Knit.CreateController({
	Name = "ClashController",
})

type Showing = { a: Model, b: Model, nextPulse: number }

function ClashController:KnitStart()
	local started = Net.client("ClashStarted")
	local ended = Net.client("ClashEnded")
	local repelled = Net.client("ClashRepelled")
	if not started or not ended or not repelled then
		warn("[Haymaker Tussle] clash remotes missing; clashes won't show")
		return
	end
	local player = Players.LocalPlayer
	local anim = Knit.GetController("AnimController")
	local fx = Knit.GetController("FxController")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_Clash"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	local bar = ClashBar.new(gui)

	local showing: { Showing } = {}

	local function stopShowing(a: Model, b: Model)
		for index = #showing, 1, -1 do
			if showing[index].a == a and showing[index].b == b then
				table.remove(showing, index)
			end
		end
		anim:SetBarrage(a, false)
		anim:SetBarrage(b, false)
	end

	started.OnClientEvent:Connect(function(a: Model, b: Model, seconds: number)
		if not a or not b then
			return
		end
		anim:CancelSwing(a)
		anim:CancelSwing(b)
		-- Half a loop apart, so the fists alternate across the pair.
		anim:SetBarrage(a, true, 0)
		anim:SetBarrage(b, true, 0.5)
		table.insert(showing, { a = a, b = b, nextPulse = os.clock() })
		local me = player.Character
		if a == me then
			bar:Show(a, b, seconds)
		elseif b == me then
			bar:Show(b, a, seconds)
		end
	end)

	ended.OnClientEvent:Connect(
		function(a: Model, b: Model, winner: Model?, reason: string, scoreA: number, scoreB: number)
			if not a or not b then
				return
			end
			stopShowing(a, b)
			if winner and winner.Parent then
				anim:PlaySwing(winner, FINISH_SWING)
				fx:Swing(winner)
			end
			local me = player.Character
			if a == me or b == me then
				local mine = if a == me then scoreA else scoreB
				local theirs = if a == me then scoreB else scoreA
				local kind = if winner == me
					then "win"
					elseif winner then "lose"
					elseif reason == "tie" then "tie"
					else "over"
				bar:Result(kind, mine, theirs)
			end
		end
	)

	repelled.OnClientEvent:Connect(function(attacker: Model, target: Model)
		if attacker and target and attacker.Parent and target.Parent then
			fx:ClashRepel(target, attacker)
			anim:HitLanded(nil, attacker, GameConfig.Knockback.BaseSpeed / 2)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if #showing == 0 then
			return
		end
		local now = os.clock()
		for index = #showing, 1, -1 do
			local one = showing[index]
			if not one.a.Parent or not one.b.Parent then
				table.remove(showing, index)
			elseif now >= one.nextPulse then
				one.nextPulse = now + cfg.PulseSeconds
				fx:ClashPulse(one.a, one.b)
			end
		end
	end)
end

return ClashController