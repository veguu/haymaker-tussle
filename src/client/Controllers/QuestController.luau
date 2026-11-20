--!strict
-- QuestController - the client side of the daily quests (2026-11-19/20). It keeps the board QuestService sends
-- (nothing here decides anything) and shows it on the CLIPBOARD (Ui/QuestClipboard) that the notice board's prompt
-- opens (NpcController sends HT_Page "quests" here). A note that comes with the board (a quest finished, Coins
-- paid) shows in the menu's toast.
--
-- The clipboard closes on its X, on gamepad B, when the menu window opens (the two never stand together), when a
-- round takes you, and when you walk away from the board.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local QuestClipboard = require(script.Parent.Parent.Ui.QuestClipboard)

export type QuestView = QuestClipboard.QuestView

local CLOSE_ACTION = "HaymakerQuestsClose"
local WALK_AWAY = 24 -- studs from the board (level distance) at which the clipboard closes by itself
local CHECK = 0.25

local QuestController = Knit.CreateController({
	Name = "QuestController",
	-- () when the board changes
	Changed = Signal.new(),
})

local board: { QuestView }? = nil
local resetAt = 0 -- os.clock() when the board changes
local claimRemote: RemoteEvent? = nil
local clipboard: QuestClipboard.Handle? = nil

--- The board, or nil before it has come.
function QuestController:Get(): { QuestView }?
	return board
end

--- Seconds until a new board, by the server's count when the board last came.
function QuestController:SecondsLeft(): number
	return math.max(0, resetAt - os.clock())
end

--- Asks the server to claim a finished quest.
function QuestController:Claim(id: string)
	if claimRemote then
		claimRemote:FireServer(id)
	end
end

--- Asks the server for the board again.
function QuestController:Refresh()
	if claimRemote then
		claimRemote:FireServer(nil)
	end
end

local function unbind()
	ContextActionService:UnbindAction(CLOSE_ACTION)
end

--- Closes the clipboard.
function QuestController:Close()
	if clipboard and clipboard.isOpen() then
		clipboard.close()
		unbind()
	end
end

--- Opens the clipboard (the notice board's prompt). Not in a round.
function QuestController:Open()
	local player = Players.LocalPlayer
	if not clipboard or player:GetAttribute("HT_InRound") == true then
		return
	end
	if clipboard.isOpen() then
		return
	end
	Knit.GetController("MenuController"):Close()
	self:Refresh()
	clipboard.open()
	ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			self:Close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.ButtonB)
	-- it closes by itself when you walk away or a round takes you
	local lobby: any = GameConfig.Lobby
	local spot: any = QuestConfig.Board
	local boardAt = Vector2.new(lobby.CenterX + spot.X, lobby.ViewEdgeZ + spot.Back)
	task.spawn(function()
		while clipboard and clipboard.isOpen() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local far = root ~= nil
				and (Vector2.new(root.Position.X, root.Position.Z) - boardAt).Magnitude
					> WALK_AWAY
			if far or player:GetAttribute("HT_InRound") == true then
				self:Close()
				break
			end
			task.wait(CHECK)
		end
	end)
end

function QuestController:KnitStart()
	if not QuestConfig.Enabled then
		return
	end
	local player = Players.LocalPlayer
	clipboard = QuestClipboard.new(player:WaitForChild("PlayerGui"), function()
		return board
	end, function()
		return self:SecondsLeft()
	end, function(id: string)
		self:Claim(id)
	end, unbind)
	-- the menu window and the clipboard never stand together
	Knit.GetController("MenuController").Changed:Connect(function(entry: string?)
		if entry ~= nil then
			self:Close()
		end
	end)
	task.spawn(function()
		local state = Net.client("QuestState")
		claimRemote = Net.client("QuestClaim")
		if not state then
			return
		end
		state.OnClientEvent:Connect(function(view: any, note: any)
			if typeof(view) ~= "table" or typeof(view.list) ~= "table" then
				return
			end
			board = view.list
			if typeof(view.resetIn) == "number" then
				resetAt = os.clock() + view.resetIn
			end
			self.Changed:Fire()
			if clipboard and clipboard.isOpen() then
				clipboard.draw()
			end
			if typeof(note) == "string" and note ~= "" then
				Knit.GetController("MenuController"):Toast(note)
			end
		end)
		-- in case the first board was sent before this listened
		if not board then
			self:Refresh()
		end
	end)
end

return QuestController
