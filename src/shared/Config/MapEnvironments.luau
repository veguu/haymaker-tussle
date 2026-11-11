--!strict
-- MapEnvironments - every arena's environment, as plain editable data. HAND-WRITTEN (not generated).
--
-- HOW IT'S USED: MapService (server) decides which map is active; EnvironmentController (client) reads the
-- active map's entry here, merges it over `Default` (Core/Environment.resolve) and applies it through
-- EnvironmentKit. The lobby shares the result, because Lighting is one per client.
--
-- ADDING A MAP: add an entry to `Maps` with its id (the same id used in GameConfig.Maps.Rotation), then
--   1. put its imported model at ServerStorage.HT_Maps.<id> (a Model, pivot = the arena's centre on the
--      surface); until then a coloured stand-in floor (`standIn`) is built instead;
--   2. optionally put cloud meshes at ReplicatedStorage.HT_MapAssets.<id>.Clouds (children named like the
--      cloud entries, e.g. "Cloud_1"); without them the clouds are built from rounded parts;
--   3. give it an `environment` holding only what differs from `Default`;
--   4. run `lune run test`: tests/Environment.spec checks every cloud's whole drift path stays clear of the
--      lobby's view of the arena, the fighting space and the sight lines to the landmarks, and that the
--      drifting leaves stay out of the fighting space.
--
-- UNITS: positions are studs RELATIVE TO THE ARENA'S CENTRE ON ITS SURFACE (Roblox axes: +Y up, the lobby
-- is on +Z). Colours are { r, g, b } 0-255. Angles in degrees. Times in seconds.
-- The sun's direction comes from `clockTime` + `latitude` (Roblox has no free azimuth): with these maps'
-- latitudes, noon puts the sun on +Z, behind the lobby; later in the day swings it toward -X.

export type Colour = { number }

local MapEnvironments = {}

-- The shared sunny sky every map starts from. Keep overall brightness and the blue sky close to this on
-- every map, so the maps read as one world.
MapEnvironments.Default = {
	sun = {
		clockTime = 15.0,
		latitude = 50,
		colour = { 255, 234, 208 }, -- Lighting.ColorShift_Top: the sunlight's warmth
		brightness = 2.2,
	},
	ambient = {
		ambient = { 88, 98, 122 }, -- shade colour: a little cool, so shadows stay colourful
		outdoor = { 114, 126, 154 }, -- held at least as bright as `ambient`, per channel
		bottom = { 18, 22, 16 }, -- Lighting.ColorShift_Bottom: a faint bounce from below
		shadowSoftness = 0.32,
		diffuse = 0.4, -- EnvironmentDiffuseScale: sky light in the shade
		specular = 0.12,
	},
	exposure = -0.15,
	grade = { brightness = 0, contrast = 0.12, saturation = 0, tint = { 255, 253, 248 } },
	bloom = { intensity = 0.35, size = 24, threshold = 1.6 }, -- threshold above 1: white surfaces don't glow
	sunRays = { intensity = 0.015, spread = 0.12 },
	atmosphere = {
		density = 0.22,
		offset = 0.2,
		colour = { 199, 222, 247 },
		decay = { 124, 164, 214 },
		glare = 0,
		haze = 0.4,
	},
	sky = { sunAngularSize = 11 }, -- the place's own Sky textures are kept
	clouds = {
		wind = { 1, 0.3 }, -- the direction clouds sway along (normalised in code)
		top = { 252, 253, 255 },
		under = { 206, 224, 246 }, -- pale blue
		-- far clouds lose contrast: the underside is blended toward the top, both toward the sky haze
		fadeStart = 350,
		fadeEnd = 1100,
		fadeMost = 0.6,
		list = {},
	},
	motes = { list = {} },
	scenery = { bob = {} },
	-- What the cloud check protects from the gameplay camera, besides the fighting space.
	landmarks = {},
	standIn = { floor = { 110, 168, 92 }, ring = { 236, 236, 228 } },
}

-- Cloud entry: x, y, z (centre), length (studs), kind "compact" | "stretched", heading (degrees, from +X
-- toward +Z), sway (studs, each way along the wind), period (seconds per sway), phase (0-1).
-- Mote spot: x, y (top of the fall), z, radius, count, kind "leaf" | "petal", colours, fall (studs).
-- Bob: match (Lua pattern on part names in the map model; outline/twin names ending _Line follow their
-- owner), rise (studs, each way), period, sway (studs along the wind).

MapEnvironments.Maps = {
	gnomon = {
		name = "Gnomon Meadow",
		model = "Gnomon",
		environment = {
			-- fresh greens, gently warm sun low over the lobby's left shoulder (azimuth -55, elevation 38) so
			-- the cliff's layers, the islets and the tufts model in light and shade; soft cool shade.
			-- Tuned 2026-11-10 from the gameplay camera and lobby spawn on the reworked island (no outlines).
			-- SOFTER pass (user, 2026-11-10: "too vibrant and bright"): less saturation and contrast, a gentler
			-- sun, lighter and softer shade, a little more haze; the sky is kept blue (desaturating further
			-- turned it grey).
			sun = { clockTime = 15.1, latitude = 50, colour = { 255, 240, 222 }, brightness = 1.9 },
			ambient = {
				ambient = { 104, 112, 132 },
				outdoor = { 132, 140, 160 },
				bottom = { 18, 24, 14 },
				shadowSoftness = 0.55,
				diffuse = 0.45,
			},
			exposure = -0.25,
			grade = {
				saturation = -0.13,
				contrast = 0.04,
				brightness = 0.01,
				tint = { 255, 252, 246 },
			},
			bloom = { intensity = 0.25 },
			atmosphere = { haze = 0.45, colour = { 200, 222, 246 } },
			clouds = {
				list = {
					{
						x = -560,
						y = 120,
						z = -230,
						length = 120,
						kind = "compact",
						heading = 10,
						sway = 30,
						period = 150,
						phase = 0.1,
					},
					{
						x = 600,
						y = 150,
						z = -420,
						length = 140,
						kind = "stretched",
						heading = -15,
						sway = 40,
						period = 180,
						phase = 0.6,
					},
					{
						x = -470,
						y = 95,
						z = 360,
						length = 100,
						kind = "compact",
						heading = 0,
						sway = 25,
						period = 140,
						phase = 0.35,
					},
					{
						x = -180,
						y = 270,
						z = -760,
						length = 150,
						kind = "stretched",
						heading = 5,
						sway = 40,
						period = 200,
						phase = 0.8,
					},
					{
						x = 700,
						y = 130,
						z = 120,
						length = 110,
						kind = "compact",
						heading = 0,
						sway = 30,
						period = 160,
						phase = 0.5,
					},
					{
						x = -760,
						y = 170,
						z = -20,
						length = 130,
						kind = "stretched",
						heading = -10,
						sway = 35,
						period = 190,
						phase = 0.2,
					},
				},
			},
			motes = {
				list = {
					-- leaves off the grove and the tall pair, petals off the hollow log's flowers and the sundial's beds
					{
						x = 232,
						y = 30,
						z = -108,
						radius = 16,
						count = 6,
						kind = "leaf",
						fall = 26,
						colours = { { 92, 160, 70 }, { 150, 190, 74 } },
					},
					{
						x = -250,
						y = 34,
						z = -46,
						radius = 14,
						count = 5,
						kind = "leaf",
						fall = 26,
						colours = { { 70, 140, 74 }, { 120, 176, 70 } },
					},
					{
						x = -300,
						y = 18,
						z = 150,
						radius = 16,
						count = 5,
						kind = "petal",
						fall = 18,
						colours = { { 240, 120, 96 }, { 250, 214, 120 } },
					},
					{
						x = 372,
						y = -6,
						z = -20,
						radius = 18,
						count = 5,
						kind = "petal",
						fall = 18,
						colours = { { 250, 232, 196 }, { 240, 120, 96 } },
					},
				},
			},
			scenery = {
				bob = {
					{ match = "^Sight_BalloonNear", rise = 2.5, period = 11, sway = 4 },
					{ match = "^Sight_BalloonFar", rise = 3, period = 14, sway = 6 },
				},
			},
			landmarks = {
				{ name = "Sundial", x = 380, y = 60, z = -30, radius = 95 },
				{ name = "Launch isle", x = 300, y = -20, z = 230, radius = 95 },
				{ name = "Near balloon", x = -250, y = 78, z = -235, radius = 22 },
			},
			standIn = { floor = { 110, 168, 92 }, ring = { 240, 236, 214 } },
		},
	},
	kitestead = {
		name = "Kitestead",
		model = "Kitestead",
		environment = {
			-- a warmer, lower afternoon sun raking across the beams and painted plank ends
			sun = { clockTime = 15.6, latitude = 52, colour = { 255, 224, 184 }, brightness = 2.15 },
			ambient = {
				ambient = { 92, 90, 104 },
				outdoor = { 122, 118, 132 },
				bottom = { 28, 20, 12 },
				shadowSoftness = 0.3,
			},
			exposure = -0.12,
			grade = { saturation = 0, contrast = 0.13, tint = { 255, 250, 242 } },
			atmosphere = { colour = { 205, 222, 242 }, decay = { 140, 166, 206 } },
			clouds = {
				wind = { -0.4, 1 },
				list = {
					{
						x = 520,
						y = 110,
						z = -300,
						length = 110,
						kind = "stretched",
						heading = 70,
						sway = 30,
						period = 170,
						phase = 0.3,
					},
					{
						x = -620,
						y = 140,
						z = -320,
						length = 130,
						kind = "compact",
						heading = 0,
						sway = 30,
						period = 150,
						phase = 0.7,
					},
					{
						x = 120,
						y = 280,
						z = -820,
						length = 140,
						kind = "stretched",
						heading = 80,
						sway = 40,
						period = 210,
						phase = 0.1,
					},
					{
						x = -520,
						y = 90,
						z = 300,
						length = 100,
						kind = "compact",
						heading = 0,
						sway = 25,
						period = 140,
						phase = 0.55,
					},
					{
						x = 420,
						y = 200,
						z = 540,
						length = 120,
						kind = "stretched",
						heading = 60,
						sway = 30,
						period = 180,
						phase = 0.9,
					},
				},
			},
			motes = { list = {} }, -- no vegetation on the raft: no leaves
			scenery = {
				bob = {
					{ match = "^Sight_KiteLoftKites", rise = 2, period = 7, sway = 3 },
					{ match = "^Kite", rise = 1.5, period = 6, sway = 2 },
				},
			},
			landmarks = {
				{ name = "Kite train", x = 760, y = 130, z = 90, radius = 120 },
				{ name = "Kite loft", x = -560, y = 60, z = -60, radius = 90 },
			},
			standIn = { floor = { 176, 128, 82 }, ring = { 236, 200, 92 } },
		},
	},
	saltcrest = {
		name = "Saltcrest",
		model = "Saltcrest",
		environment = {
			-- clear, cooler coastal light from a high sun, so the tiles' glaze and the stone stay crisp
			sun = { clockTime = 13.4, latitude = 45, colour = { 255, 246, 232 }, brightness = 2.2 },
			ambient = {
				ambient = { 88, 102, 124 },
				outdoor = { 116, 134, 160 },
				bottom = { 14, 22, 26 },
				shadowSoftness = 0.36,
			},
			exposure = -0.18,
			grade = { saturation = -0.02, contrast = 0.11, tint = { 250, 253, 255 } },
			atmosphere = {
				density = 0.2,
				haze = 0.3,
				colour = { 196, 224, 250 },
				decay = { 118, 166, 220 },
			},
			clouds = {
				wind = { 1, -0.2 },
				list = {
					{
						x = -600,
						y = 130,
						z = -360,
						length = 120,
						kind = "stretched",
						heading = -5,
						sway = 35,
						period = 170,
						phase = 0.2,
					},
					{
						x = 560,
						y = 170,
						z = -520,
						length = 130,
						kind = "compact",
						heading = 0,
						sway = 30,
						period = 160,
						phase = 0.65,
					},
					{
						x = 650,
						y = 110,
						z = 200,
						length = 100,
						kind = "compact",
						heading = 0,
						sway = 25,
						period = 150,
						phase = 0.4,
					},
					{
						x = -240,
						y = 290,
						z = -880,
						length = 150,
						kind = "stretched",
						heading = 10,
						sway = 40,
						period = 220,
						phase = 0.85,
					},
				},
			},
			motes = { list = {} }, -- the plaza's only greenery is far below the view: no leaves
			scenery = { bob = {} },
			landmarks = {
				{ name = "Net rock", x = 30, y = -100, z = -380, radius = 60 },
			},
			standIn = { floor = { 120, 186, 176 }, ring = { 242, 236, 222 } },
		},
	},
}

return MapEnvironments
