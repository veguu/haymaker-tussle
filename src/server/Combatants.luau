--!strict
-- Combatants - who can be fought right now: living player characters, plus training
-- dummies. Every server combat system asks here, so there's one answer to the question.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Combatants = {}

Combatants.TAG = "HT_Combatant"
-- A training dummy. It fights like anyone, but it must never count for rounds, scoring or rewards.
Combatants.DUMMY_ATTRIBUTE = "HT_Dummy"
-- A dummy pinned in place for inspecting reach. Punches land on it, but nothing can move it, so it can't
-- be bumped or launched, and standing inside it to test overlap doesn't throw you out.
Combatants.STATIONARY_ATTRIBUTE = "HT_Stationary"

function Combatants.rootOf(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Combatants.isAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and humanoid.Health > 0
		and Combatants.rootOf(model) ~= nil
		and model.Parent ~= nil
end

function Combatants.all(): { Model }
	local out: { Model } = {}
	for _, instance in CollectionService:GetTagged(Combatants.TAG) do
		if instance:IsA("Model") and Combatants.isAlive(instance) then
			table.insert(out, instance)
		end
	end
	return out
end

function Combatants.isDummy(model: Model): boolean
	return model:GetAttribute(Combatants.DUMMY_ATTRIBUTE) == true
end

--- Living player characters only. Anything that counts people, such as a round, uses this.
function Combatants.players(): { Model }
	local out: { Model } = {}
	for _, model in Combatants.all() do
		if not Combatants.isDummy(model) and Players:GetPlayerFromCharacter(model) then
			table.insert(out, model)
		end
	end
	return out
end

function Combatants.playerOf(model: Model): Player?
	return Players:GetPlayerFromCharacter(model)
end

return Combatants