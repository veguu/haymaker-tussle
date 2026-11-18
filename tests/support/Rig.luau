--!strict
-- Rig (kits-8a): an R6 body posed by one of our baked clips, in plain maths, so the tests can measure where a fist
-- really is at a contact (design/cutscene-study/00: measured in play, the haymaker's fist met the SIDE of the torso
-- because a flinch turned it, and the uppercut's met it 58 deg off its front). The joints are Roblox's R6 Motor6Ds
-- (the same ones animations/build_strikes.luau bakes with): part = parent * C0 * Transform * C1:Inverse(), and a
-- clip's pose { rx, ry, rz, x, y, z } is Transform = CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz) in degrees.
local roblox = require("@lune/roblox")

local CFrame: any = roblox.CFrame
local Vector3: any = roblox.Vector3

local Rig = {}

local UP = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
local RIGHT = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
local LEFT = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
local function at(x: number, y: number, z: number, rotation: any): any
	return CFrame.new(x, y, z) * rotation
end
local JOINTS: { [string]: { any } } = {
	Torso = { UP, UP },
	Head = { at(0, 1, 0, UP), at(0, -0.5, 0, UP) },
	["Right Arm"] = { at(1, 0.5, 0, RIGHT), at(-0.5, 0.5, 0, RIGHT) },
	["Left Arm"] = { at(-1, 0.5, 0, LEFT), at(0.5, 0.5, 0, LEFT) },
	["Right Leg"] = { at(1, -1, 0, RIGHT), at(0.5, 1, 0, RIGHT) },
	["Left Leg"] = { at(-1, -1, 0, LEFT), at(-0.5, 1, 0, LEFT) },
}
local LIMBS = { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local function transform(values: { number }?): any
	if not values then
		return CFrame.new()
	end
	return CFrame.new(values[4], values[5], values[6])
		* CFrame.Angles(math.rad(values[1]), math.rad(values[2]), math.rad(values[3]))
end

--- A clip's pose at `t` seconds (held at its ends): each joint's Transform, blended between the two frames around it
--- the way Roblox blends keyframes (a CFrame lerp: the rotation turns the short way, not angle by angle).
function Rig.sample(clip: any, t: number): { [string]: any }
	local frames = clip.frames
	local a, b = frames[1], frames[#frames]
	local share = 0
	if t >= b.t then
		a = b
	elseif t > a.t then
		for index = 1, #frames - 1 do
			if t <= frames[index + 1].t then
				a, b = frames[index], frames[index + 1]
				break
			end
		end
		share = (t - a.t) / math.max(b.t - a.t, 1e-6)
	end
	local pose = {}
	for joint, values in a.pose do
		pose[joint] = transform(values):Lerp(transform(b.pose[joint] or values), share)
	end
	return pose
end

--- Every part's CFrame for a body whose HumanoidRootPart is at `root`, posed by `pose` (Rig.sample's; nil: the rest
--- pose).
function Rig.parts(root: any, pose: { [string]: any }?): { [string]: any }
	local function joint(name: string, parent: any): any
		local j = JOINTS[name]
		return parent * j[1] * (pose and pose[name] or CFrame.new()) * j[2]:Inverse()
	end
	local torso = joint("Torso", root)
	local parts = { Torso = torso }
	for _, name in LIMBS do
		parts[name] = joint(name, torso)
	end
	return parts
end

--- The fist: the bottom of an arm (its centre plus half its 2-stud length, down its own Y), and the way the arm
--- points (shoulder to fist).
function Rig.fist(arm: any): (any, any)
	return (arm * CFrame.new(0, -1, 0)).Position, -arm.UpVector
end

--- A swing's fist at clip time `t` on a body rooted at `root`, and the way it is MOVING there (a thrust moves along
--- the arm; an uppercut sweeps up across it, so the arm's own direction would say nothing about where it drives).
function Rig.strike(root: any, clip: any, t: number): (any, any)
	local step = 0.002
	local tip = Rig.fist(Rig.parts(root, Rig.sample(clip, t))["Right Arm"])
	local before = Rig.fist(Rig.parts(root, Rig.sample(clip, t - step))["Right Arm"])
	local after = Rig.fist(Rig.parts(root, Rig.sample(clip, t + step))["Right Arm"])
	return tip, (after - before).Unit
end

--- How far a point is outside the torso's 2 x 2 x 1 box (0 inside it).
function Rig.torsoGap(torso: any, point: any): number
	local l = torso:PointToObjectSpace(point)
	local dx = math.max(math.abs(l.X) - 1, 0)
	local dy = math.max(math.abs(l.Y) - 1, 0)
	local dz = math.max(math.abs(l.Z) - 0.5, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- Degrees between the way the fist drives and straight INTO the chest (0 = square on the front, 90 = along it).
function Rig.squareness(torso: any, armDirection: any): number
	local into = -torso.LookVector
	return math.deg(math.acos(math.clamp(into:Dot(armDirection.Unit), -1, 1)))
end

Rig.Vector3 = Vector3
Rig.CFrame = CFrame
return Rig
