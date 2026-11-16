--!nocheck
-- fx_smoke - builds every rig of the ability kits' effect modules outside Studio, so a wrong
-- property name, enum or value shows up here and not in a playtest. Run: lune run lune/fx_smoke
--
-- It loads the Fx modules with Lune's Roblox instances standing in for the engine: real Instances
-- (ParticleEmitter, Attachment, Part, Folder) checked against Roblox's own property list, and small
-- stand-ins for the services the modules touch at load. It runs each module's `preload`, which makes
-- every pooled rig. It does NOT play anything: timing, looks, sizes and the streams that run on a
-- moving body are only seen in Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local FX = "src/client/Fx/"
local MODULES =
	{ "InfernoFx", "FrostFx", "BeastFx", "DragonFx", "BruiserFx", "TricksterFx", "SkillFx" }
-- What each module's preload is given (the reach its biggest rig is built for).
local PRELOAD_ARGS = { DragonFx = 22, SkillFx = 10.5 }

local dataModel = roblox.Instance.new("DataModel")
local workspace = dataModel:GetService("Workspace")

local services = {
	CollectionService = {
		GetTagged = function()
			return {}
		end,
	},
	UserInputService = { TouchEnabled = false, KeyboardEnabled = true },
	ReplicatedStorage = dataModel:GetService("ReplicatedStorage"),
	RunService = {
		Heartbeat = {
			Connect = function()
				return { Disconnect = function() end }
			end,
		},
	},
}
local game = {
	GetService = function(_, name)
		return services[name] or error(`fx_smoke has no stand-in for {name}`)
	end,
}

local RandomStub = {
	new = function(seed)
		local state = seed or 1
		return {
			NextNumber = function(_, low, high)
				state = (state * 1103515245 + 12345) % 2147483648
				local share = state / 2147483648
				if low and high then
					return low + (high - low) * share
				end
				return share
			end,
		}
	end,
}

local loaded = {}
local load

local function environment(name)
	local env = {
		game = game,
		workspace = workspace,
		task = task,
		Random = RandomStub,
		Instance = roblox.Instance,
		script = {
			Parent = setmetatable({}, {
				__index = function(_, sibling)
					return { moduleName = sibling }
				end,
			}),
			Name = name,
		},
		require = function(reference)
			return load(reference.moduleName)
		end,
	}
	-- The Roblox data types and Enum, as the engine's globals.
	for key, value in roblox do
		if env[key] == nil then
			env[key] = value
		end
	end
	return setmetatable(env, { __index = _G })
end

function load(name)
	if loaded[name] == nil then
		local source = fs.readFile(FX .. name .. ".luau")
		local chunk = luau.load(source, { debugName = name, environment = environment(name) })
		loaded[name] = chunk()
	end
	return loaded[name]
end

-- Every effect is then called once on a stand-in body, which also builds the streams that run on a
-- moving body and runs the code that lays pieces out. The engine calls Lune doesn't have are
-- replaced: nothing is thrown, the floor is always at the origin.
local FxKit = load("FxKit")
FxKit.fire = function(rig)
	rig.used += 1
end
FxKit.floorUnder = function()
	return roblox.Vector3.new(0, 0, 0)
end
local Vector3 = roblox.Vector3
local function body(name, size)
	local part = roblox.Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = roblox.CFrame.new(0, 3, 0)
	part.Position = Vector3.new(0, 3, 0) -- Lune keeps the two apart, so both are given
	part.Parent = workspace
	return part
end
local root = body("HumanoidRootPart", Vector3.new(2, 2, 1))
local arm = body("Right Arm", Vector3.new(1, 2, 1))
local way = Vector3.new(0, 0, -1)
local at = Vector3.new(0, 4, -2)
local USES = {
	InfernoFx = function(fx)
		fx.blastoff(root, way)
		fx.meteor(at, 0.01, 0.01, 13)
		fx.hit(root, way)
		fx.punch(at, true)
		fx.landing(at)
	end,
	FrostFx = function(fx)
		fx.frostbite(root, way, 0.2)
		fx.windup(root, arm, way, 0.4)
		fx.strike(root, way)
		fx.hit(root, way)
		fx.punch(at, true)
		fx.landing(at)
	end,
	BeastFx = function(fx)
		fx.glint(at)
		fx.pounce(root, way, 0.2)
		fx.slam(at)
		fx.swipe(root, way, 1, false)
		fx.swipe(root, way, 4, true)
		fx.hit(root, way)
		fx.punch(at, way, true)
		fx.landing(at)
	end,
	DragonFx = function(fx)
		fx.ascend(root, 0.3)
		fx.windup(at)
		fx.strike(at, way, PRELOAD_ARGS.DragonFx)
		fx.hit(root, way)
	end,
	BruiserFx = function(fx)
		fx.charge(root, way, 0.3)
		fx.windup(at)
		fx.strike(root)
		fx.hit(root, way)
	end,
	TricksterFx = function(fx)
		fx.glint(at)
		fx.flip(root, 0.3)
		fx.land(at)
		fx.strike(root, way)
		fx.hit(root, way)
	end,
	SkillFx = function(fx)
		fx.uppercutHit(root)
		fx.cycloneStrike(root, PRELOAD_ARGS.SkillFx)
	end,
}

local failed = 0
for _, name in MODULES do
	local ok, problem = pcall(function()
		local module = load(name)
		module.preload(PRELOAD_ARGS[name])
		USES[name](module)
	end)
	if ok then
		print(`PASS {name}`)
	else
		failed += 1
		print(`FAIL {name}: {problem}`)
	end
end

-- Let the effects' own delayed steps run (a meteor's rock and blast), so an error in one shows.
local late = 0
local ok, problem = pcall(function()
	task.wait(0.3)
end)
if not ok then
	late += 1
	print(`FAIL delayed step: {problem}`)
end

-- How much was built, as a sanity check that preload really made the rigs.
local emitters = 0
for _, instance in workspace:GetDescendants() do
	if instance.ClassName == "ParticleEmitter" then
		emitters += 1
	end
end
print(`{#MODULES - failed} of {#MODULES} modules built, {emitters} emitters in all`)
if failed > 0 then
	process.exit(1)
end
