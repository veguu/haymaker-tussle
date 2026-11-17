--!strict
-- UltimateFx - what the ultimates look like, cue by cue (the choreography is Core/Ultimates, run by
-- UltimateController). Every client plays the cues, so everyone near sees them.
--
-- EMPTY FOR NOW (2026-11-16): the user had Base's "Final Bell" removed entirely, to be replaced by a new
-- ultimate designed from their reference cutscenes. Each kit's cues go in KITS when its ultimate is built.
-- Directions and spacing are set on purpose, never random.

local UltimateFx = {}

export type Context = {
	kit: string,
	attacker: Model,
	target: Model,
	anchor: CFrame,
	attackerFrom: Vector3, -- where the attacker was when it started (world)
	mine: boolean, -- this client is the attacker or the target
}

-- Each kit's own cues, by name.
local KITS: { [string]: { [string]: (Context) -> () } } = {}

--- Plays the cue `name` of `ctx.kit`'s ultimate.
function UltimateFx.cue(name: string, ctx: Context)
	local set = KITS[ctx.kit]
	local play = set and set[name]
	if play then
		task.spawn(play, ctx)
	end
end

return UltimateFx
