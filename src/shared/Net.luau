--!strict
-- Net - the ONLY networking transport for gameplay and cross-client paths.
--
-- Knit's auto-generated remotes are deliberately NOT used here. When play-mode
-- introspection is unreachable, the most primitive debuggable transport wins:
-- one folder of plain RemoteEvents, created server-side, awaited client-side,
-- every name declared in this file and nowhere else.
--
-- Server: Net.server("EventName") -> RemoteEvent (creates on first use)
-- Client: Net.client("EventName") -> RemoteEvent? (nil on timeout - callers
--         must fail inert, never error)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "HaymakerTussleNet"
local CLIENT_WAIT_TIMEOUT = 10

-- Every remote in the game is declared here. A name not on this list is a bug.
export type EventName =
	"PunchRequest" -- client to server: I pressed punch. No arguments, ever.
	| "PunchStarted" -- server to all: this character started a swing: Left, Right or Uppercut
	| "HitConfirmed" -- server to all: this character's punch hit this target
	| "Knockback" -- server to the target's client: launch velocity, and lift if airborne
	| "BumpHappened" -- server to all: these two characters bumped
	| "PropelRequest" -- client to server: I propelled. No arguments, ever.
	| "PropelStarted" -- server to other clients: this player propelled
	| "KickRequest" -- client to server: I jumped at someone in the air. No arguments, ever.
	| "KickAccepted" -- server to the jumper's client: your follow-up is on, at this target
	| "KickAttach" -- client to server: I reached them. No arguments, ever.
	| "KickCommit" -- client to server: I pressed the timing key. No arguments, ever.
	| "KickImpact" -- server to all: this character's kick landed, on this target, here
	| "TutorialDone" -- client to server: I finished or skipped the tutorial. No arguments, ever.
	| "PunchResult" -- server to client(s): this character's swing was hit, miss, cancelled, refused or clash
	| "PunchDebug" -- server to all, for the hitbox display: a swing going live (and for how long) or ending, with its verdicts
	| "ClashStarted" -- server to all: these two characters are clashing, for up to this many seconds
	| "ClashTap" -- client to server: I pressed punch during a clash. No arguments, ever.
	| "ClashEnded" -- server to all: this clash is over: winner (or nil), reason, and both final scores
	| "ClashRepelled" -- server to all: this character's punch bounced off this clashing target
	| "BodyReset" -- server to a player's client: you've been moved: drop all momentum, face this way, and why
	| "AfkToggle" -- client to server: switch my AFK (sit out rounds) on or off. No arguments, ever.

local Net = {}

local function serverFolder(): Folder
	assert(RunService:IsServer(), "Net.server is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

--- Server side: get (or create) the RemoteEvent for `name`.
function Net.server(name: EventName): RemoteEvent
	local folder = serverFolder()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

--- Client side: wait for the RemoteEvent for `name`. Returns nil rather than
--- erroring, so a missing remote degrades one feature instead of the client.
function Net.client(name: EventName): RemoteEvent?
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT_TIMEOUT)
	if not folder then
		warn(`[Net] no {FOLDER_NAME} folder after {CLIENT_WAIT_TIMEOUT}s`)
		return nil
	end
	local remote = folder:WaitForChild(name, CLIENT_WAIT_TIMEOUT)
	if not remote or not remote:IsA("RemoteEvent") then
		warn(`[Net] remote {name} never arrived`)
		return nil
	end
	return remote
end

return Net
