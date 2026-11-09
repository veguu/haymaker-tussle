# python run_realclick.py setup [seconds] : parks the bot at home, pins you 5 studs ahead of it facing it, keeps the bot
# from punching, and counts real punch requests and taps on the server. With [seconds], a clash starts that long from now.
# python run_realclick.py read : prints the counts since setup. python run_realclick.py done : cleans up.
# Real mouse clicks come from Studio's input tool, so this is what the player's M1 really does. Studio must be in Play.
import os, subprocess, sys
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")

def luau(code, dm="Client"):
    return subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True).stdout.strip()

SERVER = r'''
local net = game:GetService("ReplicatedStorage").HaymakerTussleNet
workspace:SetAttribute("HT_TestBotQuiet", true)
workspace:SetAttribute("HaymakerCombatDebug", nil)
local player = game.Players:GetPlayers()[1]
local bot = workspace:FindFirstChild("TestBot1")
local HOME = Vector3.new(0, 103, -12)
bot.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
bot:PivotTo(CFrame.lookAt(HOME, HOME + Vector3.zAxis) * bot.HumanoidRootPart.CFrame:ToObjectSpace(bot:GetPivot()))
local start = os.clock()
local punches, taps, top = {}, 0, 0
if _G.HTCount then for _, c in _G.HTCount do c:Disconnect() end end
_G.HTCount = {
	net.PunchRequest.OnServerEvent:Connect(function() table.insert(punches, ("%.2f"):format(os.clock() - start)) end),
	net.ClashTap.OnServerEvent:Connect(function() taps += 1 end),
	game:GetService("RunService").Heartbeat:Connect(function()
		local c = player.Character
		top = math.max(top, c and c:GetAttribute("HT_ClashScore") or 0)
		workspace:SetAttribute("HT_RealOut", ("punch requests at %s; taps sent %d; top score %d; in clash %s"):format(table.concat(punches, " "), taps, top, tostring(c and c:GetAttribute("HT_Clash"))))
	end),
}
local after = __AFTER__
if after > 0 then
	task.delay(after, function()
		workspace:SetAttribute("HT_TestClash", player.Name .. "|" .. bot.Name)
		task.wait(0.1)
		workspace:SetAttribute("HT_TestClash", nil)
	end)
end
return "server counting"
'''

PIN = r'''
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local at = Vector3.new(0, 103, -7)
pcall(function() Run:UnbindFromRenderStep("HT_TestHold") end)
Run:BindToRenderStep("HT_TestHold", Enum.RenderPriority.Input.Value, function()
	local c = me.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r and not c:GetAttribute("HT_Clash") then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(at, at + Vector3.new(0, 0, -1))
	end
end)
return "pinned"
'''

what = sys.argv[1]
if what == "setup":
    print(luau(PIN))
    print(luau(SERVER.replace("__AFTER__", sys.argv[2] if len(sys.argv) > 2 else "0"), "Server"))
elif what == "read":
    print(luau('return workspace:GetAttribute("HT_RealOut")', "Server"))
else:
    print(luau('pcall(function() game:GetService("RunService"):UnbindFromRenderStep("HT_TestHold") end) return "unpinned"'))
    print(luau('if _G.HTCount then for _, c in _G.HTCount do c:Disconnect() end end workspace:SetAttribute("HT_TestBotQuiet", nil) workspace:SetAttribute("HT_RealOut", nil) return "cleaned"', "Server"))
