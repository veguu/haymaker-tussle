# python run_lockjump.py <green|red|orange> [key to hold, such as S] : holds you and the bot still and locks the camera
# on, then lets go and does a real jump with run_rebtest.py, with jump_sampler.luau watching. Not part of the game.
import json, os, subprocess, sys, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
SP = os.path.dirname(os.path.abspath(__file__))
grade = sys.argv[1]
hold = sys.argv[2] if len(sys.argv) > 2 else ""

def luau(code, dm="Client"):
    return subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True).stdout.strip()

def alt():
    subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps({"actions": [{"action": "keyPress", "key_code": "LeftAlt"}], "datamodel_type": "Client"})], capture_output=True, text=True)
    time.sleep(0.5)

GOLD = 'local g = game.Players.LocalPlayer.PlayerGui.HT_LockOnMarker; return tostring(g.Adornee ~= nil and g.Layer2.ImageColor3.B < 0.5) .. " on " .. tostring(g.Adornee and g.Adornee.Parent.Name) .. " white marker " .. tostring(g.Enabled)'
BOT_ANCHOR = '''
for _, m in game:GetService("CollectionService"):GetTagged("HT_Combatant") do
	if not game.Players:GetPlayerFromCharacter(m) then
		m.HumanoidRootPart.Anchored = ANCHORED
		POSITION
	end
end
return "bot anchored ANCHORED"
'''

print(luau(BOT_ANCHOR.replace("ANCHORED", "true").replace("POSITION", "m.HumanoidRootPart.CFrame = CFrame.lookAt(Vector3.new(0, 103, 0), Vector3.new(0, 103, 30))"), "Server"))
print(luau('''
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
pcall(function() Run:UnbindFromRenderStep("HT_TestHold") end)
pcall(function() Run:UnbindFromRenderStep("HT_TestAim") end)
Run:BindToRenderStep("HT_TestHold", Enum.RenderPriority.Input.Value, function()
	local r = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if r then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(Vector3.new(0, 103, 25), Vector3.new(0, 103, 0))
	end
end)
Run:BindToRenderStep("HT_TestAim", Enum.RenderPriority.Camera.Value + 2, function()
	workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 109, 39), Vector3.new(0, 103, 0))
end)
return "holding"
'''))
time.sleep(1.0)
state = luau(GOLD)
print("before Alt:", state)
if not state.startswith("true"):
    alt()
    state = luau(GOLD)
print("locked:", state)
luau('''
local Run = game:GetService("RunService")
Run:UnbindFromRenderStep("HT_TestAim")
Run:UnbindFromRenderStep("HT_TestHold")
return "free"
''')
print(luau(BOT_ANCHOR.replace("ANCHORED", "false").replace("POSITION", ""), "Server"))
print(subprocess.run([sys.executable, M, "luau", "--dm", "Client", "--file", os.path.join(SP, "jump_sampler.luau")], capture_output=True, text=True).stdout.strip()[-200:])
args = [sys.executable, os.path.join(SP, "run_rebtest.py"), grade, "30", "nil"] + ([hold] if hold else [])
print(subprocess.run(args, capture_output=True, text=True, cwd=SP).stdout.strip()[-700:])
print("camera:", luau('return workspace:GetAttribute("HT_JumpLog")'))
print("after:", luau(GOLD))
