--!strict
-- Tutorial - the first-join tutorial's steps and wording, as plain rules with no Roblox
-- instances. Each step is one thing to do, and moves on only when that thing really
-- happened: hits and bumps count only when the server has confirmed them.

local Tutorial = {}

export type Settings = {
	HitsToLearn: number,
	FastHitSpeed: number,
	BumpPunishSeconds: number,
}

export type State = {
	step: number,
	hits: number,
	bumpAt: number?,
}

export type Event = {
	kind: "inReach" | "hit" | "bump" | "propel",
	now: number?,
	speed: number?,
}

export type Device = "mouse" | "touch" | "gamepad"
export type Advice = "click" | "closer" | "turn" | "wait"

Tutorial.STEPS = { "run", "punch", "fast", "bump", "propel" }

function Tutorial.new(): State
	return { step = 1, hits = 0 }
end

function Tutorial.isDone(state: State): boolean
	return state.step > #Tutorial.STEPS
end

function Tutorial.stepName(state: State): string
	return Tutorial.STEPS[state.step] or "done"
end

local function nextStep(state: State): State
	return { step = state.step + 1, hits = 0 }
end

--- What this event does to the tutorial. Returns a new state; never mutates.
function Tutorial.handle(state: State, cfg: Settings, event: Event): State
	local step = Tutorial.stepName(state)
	if step == "run" then
		return if event.kind == "inReach" then nextStep(state) else state
	elseif step == "punch" then
		if event.kind == "hit" then
			if state.hits + 1 >= cfg.HitsToLearn then
				return nextStep(state)
			end
			return { step = state.step, hits = state.hits + 1 }
		end
	elseif step == "fast" then
		if event.kind == "hit" and (event.speed or 0) >= cfg.FastHitSpeed then
			return nextStep(state)
		end
	elseif step == "bump" then
		if event.kind == "bump" then
			return { step = state.step, hits = 0, bumpAt = event.now }
		elseif event.kind == "hit" and state.bumpAt and event.now then
			if event.now - state.bumpAt <= cfg.BumpPunishSeconds then
				return nextStep(state)
			end
		end
	elseif step == "propel" then
		return if event.kind == "propel" then nextStep(state) else state
	end
	return state
end

--- What to tell the player about punching right now. `inside` and `why` come from the same
--- hitbox check the server uses, looked at for the moment the punch would land.
function Tutorial.advice(inside: boolean, why: string?, canPunch: boolean): Advice
	if not canPunch then
		return "wait"
	elseif inside then
		return "click"
	elseif why == "facing" then
		return "turn"
	end
	return "closer"
end

local PRESS = {
	mouse = { punch = "Click", prompt = "CLICK NOW!", propel = "Press Q to propel" },
	touch = { punch = "Tap Punch", prompt = "TAP PUNCH!", propel = "Tap Propel" },
	gamepad = { punch = "Press R2", prompt = "PRESS R2!", propel = "Press B to propel" },
}

--- The one line telling the player what to do, and the hint shown if they get stuck.
function Tutorial.text(state: State, cfg: Settings, device: Device): (string, string)
	local press = PRESS[device]
	local step = Tutorial.stepName(state)
	if step == "run" then
		if device == "mouse" then
			return "Hold W and run to the marked player",
				"You run where the camera looks. A and D steer."
		end
		return "Push the stick to the marked player", "You run where the camera looks."
	elseif step == "punch" then
		return `{press.punch} when you see {press.prompt}`,
			`They must be close and in front of you. {state.hits} of {cfg.HitsToLearn} hits.`
	elseif step == "fast" then
		return "Hit someone while running at full speed",
			"Faster running launches them further. Punch just before you touch them."
	elseif step == "bump" then
		return "Run into someone, then punch straight away",
			"The faster runner wins a bump, so they can't get away from you."
	elseif step == "propel" then
		return press.propel, "A burst of speed. Turn during it to drift."
	end
	return "You're ready! Knock rivals off the edge.", "Last one standing wins."
end

--- The big prompt in the middle of the screen. Empty means show nothing.
function Tutorial.promptText(advice: Advice, device: Device): string
	if advice == "click" then
		return PRESS[device].prompt
	elseif advice == "closer" then
		return "Get closer"
	elseif advice == "turn" then
		return "Turn to face them"
	end
	return ""
end

--- What to say after a punch thrown at the wrong moment. Empty means it was a good punch.
function Tutorial.missText(advice: Advice): string
	if advice == "closer" then
		return "Too far away!"
	elseif advice == "turn" then
		return "They weren't in front of you!"
	end
	return ""
end

return Tutorial