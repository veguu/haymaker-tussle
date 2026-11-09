# python run_rebtest.py <red|orange|green> [edge radius] [bot stagger] [key to hold during the jump] : runs rebtest.luau with the bot pinned at the edge, in line with your facing.
import json, os, subprocess, sys, threading
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
SP = os.path.dirname(os.path.abspath(__file__))
grade = sys.argv[1]
edge = sys.argv[2] if len(sys.argv) > 2 else "68"
stagger = sys.argv[3] if len(sys.argv) > 3 else "nil"
hold = sys.argv[4] if len(sys.argv) > 4 else ""
def luau(dm, *rest):
    return subprocess.run([sys.executable, M, "luau", "--dm", dm, *rest], capture_output=True, text=True).stdout
pin = """
local Run = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local player = game.Players:GetPlayers()[1]
local bot
for _, m in CS:GetTagged("HT_Combatant") do
	if m ~= player.Character then bot = m end
end
local stopAt = os.clock() + 28
local conn
conn = Run.Heartbeat:Connect(function()
	if os.clock() > stopAt then conn:Disconnect() return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and bot.Parent and bot:GetAttribute("HT_Air") == nil and bot:GetAttribute("HT_Stunned") == nil then
		local look = root.CFrame.LookVector
		local dir = Vector3.new(look.X, 0, look.Z).Unit
		local at = dir * %s + Vector3.new(0, 103, 0)
		bot.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		bot.HumanoidRootPart.CFrame = CFrame.lookAt(at, at + dir)
		local stagger = STAGGER
		if stagger then bot:SetAttribute("HT_Stagger", stagger) end
	end
end)
return "pinned"
""".replace("%s", edge).replace("STAGGER", stagger)
luau("Server", "--code", pin)
src = open(os.path.join(SP, "rebtest.luau"), encoding="utf-8").read().replace('local GRADE = "green"', 'local GRADE = "%s"' % grade)
path = os.path.join(SP, "rebtest_run.luau")
open(path, "w", encoding="utf-8").write(src)
out = {}
t = threading.Thread(target=lambda: out.update(log=luau("Client", "--file", path)))
t.start()
poll = 'for _, m in game:GetService("CollectionService"):GetTagged("HT_Combatant") do if m:GetAttribute("HT_Air") == "float" and game.Players.LocalPlayer:GetAttribute("HT_JumpReady") ~= false then return "float" end end return "no"'
for i in range(200):
    if "float" in luau("Client", "--code", poll): break
presses = [{"action": "keyPress", "key_code": "Space"}]
if hold:
    presses = [{"action": "keyDown", "key_code": hold}] + presses + [{"action": "wait", "wait_time_ms": 2500}, {"action": "keyUp", "key_code": hold}]
subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps({"actions": presses, "datamodel_type": "Client"})], capture_output=True, text=True)
t.join()
print(out.get("log", "")[:1500])
