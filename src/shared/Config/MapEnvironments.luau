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
	-- THE SKY (owner 2026-11-26: "i dont like how the sky is splitn betwee two colors"): the place's photo sky had an
	-- ocean under the horizon; a plain gradient instead (design/maps/suite/sky_and_shadow_images.py: deep blue overhead,
	-- pale at the horizon, the same pale haze below it), so the horizon never splits. On every map.
	sky = {
		sunAngularSize = 11,
		textures = {
			side = "rbxassetid://97101757266736",
			up = "rbxassetid://117323388355592",
			down = "rbxassetid://130411038001935",
		},
	},
	-- THE DISTANCE BLUR (owner 2026-11-26: "some sort of blur in the distance so it makes the isaldns from far out hard
	-- to see, this should apply to everything"): sharp to `inFocusRadius` studs from the camera (the arena), softening
	-- past it (the islands). Off on phones (phone = false): a full-screen blur costs them most; the haze still softens
	-- the islands there.
	blur = { farIntensity = 0.4, focusDistance = 0, inFocusRadius = 220, phone = false },
	-- One wind per map: grass sways with it (gusts roll across the meadow along it), clouds sway along it,
	-- leaves drift with it, and Workspace.GlobalWind is set from it (particles, terrain decoration).
	wind = {
		direction = { 1, 0.3 }, -- flat x, z; normalised in code
		lean = 0.09, -- a blade tip's steady push downwind, studs per stud of blade height
		strength = 0.3, -- a gust's extra push, studs per stud of blade height
		gustLength = 40, -- studs between gust bands
		gustSeconds = 4, -- how long a gust band takes to pass a point
		flutter = 0.05, -- small fast shiver, studs per stud of height
		flutterSeconds = 1.2,
		global = 6, -- Workspace.GlobalWind speed
	},
	clouds = {
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
-- Wind: see Default.wind.
-- Bob: match (Lua pattern on part names in the map model; outline/twin names ending _Line follow their
-- owner), rise (studs, each way), period, sway (studs along the wind).

MapEnvironments.Maps = {
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
			wind = { direction = { -0.4, 1 } },
			clouds = {
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
			wind = { direction = { 1, -0.2 } },
			clouds = {
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
	-- THE LOBBY'S OWN STATE (2026-11-13): not an arena. `lobby = true` means MapService shows no geometry for
	-- it; it is what's active between rounds (GameConfig.Maps.LobbyMap), so the cliffside courtyard gets its own
	-- golden-hour light once the finished arena has gone. Never put it in Maps.Rotation.
	lobby = {
		name = "Cliffside Courtyard",
		lobby = true,
		environment = {
			-- golden hour: a low, warm sun from the lobby's left (late clock time swings it toward -X), long
			-- readable shadows, shade that leans violet so lit and shaded stone separate by hue, a warm haze
			-- toward the horizon. Exposure near neutral: the pale paving must not blow out.
			-- ui-20f, later 2026-11-19 (owner: recolour the lobby with the UI's new palette, "not girlish", "flows
			-- well"): between the first golden hour and the pastel pass. A warm, slightly high sun, slate (not
			-- lavender) shade, a warm cream haze. The pastel pass had: sun 16.0 { 255, 236, 222 } 2.2; ambient
			-- { 166, 156, 180 } / { 194, 184, 204 } / { 84, 70, 92 }; haze { 250, 232, 238 } / { 252, 214, 226 }.
			-- The first golden hour: sun 16.55 { 255, 206, 150 } 2.6; ambient { 138, 126, 142 } / { 172, 158, 166 }.
			-- RETRO COMIC (ui-22a, 2026-11-20): a crisp bright day, whiter sun, cool navy shade, clearer air, a
			-- little more colour and contrast. The ui-20f values: sun 16.2 { 255, 222, 186 } 2.4; ambient
			-- { 150, 146, 160 } / { 184, 178, 184 } / { 62, 52, 50 }; grade 0.04 / 0.1; haze { 252, 234, 214 }.
			sun = { clockTime = 15.6, latitude = 50, colour = { 255, 238, 214 }, brightness = 2.6 },
			ambient = {
				ambient = { 146, 152, 172 },
				outdoor = { 180, 186, 200 },
				bottom = { 54, 56, 66 },
				shadowSoftness = 0.3,
				diffuse = 0.5,
				specular = 0.1,
			},
			exposure = -0.05,
			grade = {
				saturation = 0.1,
				contrast = 0.12,
				brightness = 0,
				tint = { 255, 250, 242 },
			},
			bloom = { intensity = 0.35, size = 28, threshold = 1.4 },
			sunRays = { intensity = 0.03, spread = 0.16 },
			atmosphere = {
				density = 0.2,
				offset = 0.25,
				colour = { 236, 240, 250 },
				decay = { 232, 222, 210 },
				glare = 0.1,
				haze = 0.7,
			},
			wind = {
				direction = { 1, 0.3 },
				lean = 0.07,
				strength = 0.22,
				gustLength = 42,
				gustSeconds = 5,
				flutter = 0.04,
			},
			clouds = {
				top = { 255, 236, 212 },
				under = { 238, 172, 150 }, -- lit from below the horizon: peach undersides
				list = {},
				drift = {
					span = 3000,
					speed = 4.5,
					edge = 0.14,
					acrossJitter = 60,
					yJitter = 25,
					sizeJitter = 0.15,
					headingJitter = 20,
					rise = 6,
					risePeriod = 90,
					lanes = {
						{
							across = -950,
							y = 300,
							length = 160,
							speed = 0.9,
							phase = 0.75,
							stretched = 0.7,
						},
						{
							across = 650,
							y = 185,
							length = 140,
							speed = 1.0,
							phase = 0.2,
							stretched = 0.6,
						},
						{
							across = 800,
							y = 210,
							length = 150,
							speed = 0.9,
							phase = 0.65,
							stretched = 0.7,
						},
						{
							across = 1100,
							y = 270,
							length = 150,
							speed = 0.85,
							phase = 0.4,
							stretched = 0.6,
						},
						{
							across = -600,
							y = 210,
							length = 140,
							speed = 1.0,
							phase = 0.05,
							stretched = 0.6,
						},
						{
							across = -600,
							y = 240,
							length = 130,
							speed = 1.0,
							phase = 0.55,
							stretched = 0.7,
						},
						{
							across = -800,
							y = 270,
							length = 150,
							speed = 0.85,
							phase = 0.3,
							stretched = 0.6,
						},
					},
				},
			},
		},
	},
}

-- MAP 1 OF THE ARENA SUITE, "Grassy Plains" (owner brief 2026-11-20; design/maps/suite/meadow.py): Gnomon revamped.
-- A CIRCLE of radius 180 since 2026-11-22 (owner: "more circle than oval"; his size), no obstacles, and since 2026-11-26
-- the old Gnomon pond in its middle (`pond` below),
-- floating in open sky with floating islands for a background. The ONLY map in the rotation since 2026-11-26 (owner: "Only Map 1",
-- until the other maps are rebuilt); until its model is at ServerStorage.HT_Maps.Meadow a stand-in floor is built.
-- Gnomon's light, but clearer air: the fresh review (2026-11-22) found the game milky and the floor pale next to the
-- Blender look, and the haze line under the arena reading as a sea.
-- Map 1's light, sky, clouds and wind. They were the old Gnomon map's (Map 1 is Gnomon revamped) and live here since the
-- old Gnomon was deleted from the game (owner 2026-11-26: "just delte the old one from everything too"): the values are
-- Gnomon's exactly, then Map 1's own clearer air below.
local meadowEnvironment = {
	-- fresh greens, gently warm sun low over the lobby's left shoulder (azimuth -55, elevation 38) so
	-- the cliff's layers, the islets and the tufts model in light and shade; soft cool shade.
	-- Tuned 2026-11-10 from the gameplay camera and lobby spawn on the reworked island (no outlines).
	-- Sunny grass pass (2026-11-11): modest saturation lift, clear greens, and a gentle
	-- sun, lighter and softer shade, a little more haze; the sky is kept blue (desaturating further
	-- turned it grey).
	-- LIGHTING PASS 2026-11-12 (user brief, five references: bright airy daylight with warm sun, cool readable
	-- shade and gentle distance haze). The sun is higher and warmer and the shade cooler and bluer, so lit and
	-- shaded sides separate by hue as well as value; a soft shadow edge; more sky light in the shade so it stays
	-- readable; exposure near neutral (no global brightening); the atmosphere's haze is raised and its offset
	-- pushed out, so the battlefield stays clear while the distant islets soften toward the sky colour; very
	-- light bloom with a threshold above 1, so white flowers, pale rocks and clouds keep their detail.
	sun = { clockTime = 14.6, latitude = 50, colour = { 255, 234, 204 }, brightness = 2.45 },
	ambient = {
		ambient = { 98, 114, 146 },
		outdoor = { 124, 142, 178 },
		bottom = { 26, 34, 20 },
		shadowSoftness = 0.38,
		diffuse = 0.55,
		specular = 0.08,
	},
	exposure = 0,
	grade = {
		saturation = 0.02,
		contrast = 0.16,
		brightness = 0,
		tint = { 255, 252, 246 },
	},
	bloom = { intensity = 0.3, size = 28, threshold = 1.35 },
	sunRays = { intensity = 0.02, spread = 0.12 },
	atmosphere = {
		density = 0.3,
		offset = 0.3,
		colour = { 206, 228, 250 },
		decay = { 150, 186, 232 },
		glare = 0.15,
		haze = 1.3,
	},
	-- a summer breeze across the meadow from the lobby's left. Raised 2026-11-10 (user: "too subtle",
	-- wanted "a teeny bit stronger"): about half again the lean and gusts, a livelier shiver, gust
	-- bands passing a little faster so the waves read across the meadow.
	wind = {
		direction = { 1, 0.3 },
		lean = 0.09,
		strength = 0.3,
		gustLength = 42,
		gustSeconds = 4,
		flutter = 0.05,
	},
	clouds = {
		-- 2026-11-12: the fixed swaying clouds became DRIFTING lanes (Environment.driftCloud): each lane's cloud
		-- crosses 3000 studs down-wind at about 5.5 studs/s (8-11 min a crossing), fades out at the far end and
		-- comes back up-wind as a new cloud (its own size, height, offset, shape, heading). `across` is the
		-- lane's side offset from the arena (+ = the lobby's side), `y` its height, `phase` where it starts.
		list = {},
		drift = {
			span = 3000,
			speed = 5.5,
			edge = 0.14,
			acrossJitter = 60,
			yJitter = 25,
			sizeJitter = 0.15,
			headingJitter = 20,
			rise = 6,
			risePeriod = 90,
			lanes = {
				{
					across = -600,
					y = 210,
					length = 140,
					speed = 1.0,
					phase = 0.05,
					stretched = 0.4,
				},
				{
					across = -600,
					y = 240,
					length = 130,
					speed = 1.0,
					phase = 0.55,
					stretched = 0.6,
				},
				{
					across = -800,
					y = 270,
					length = 150,
					speed = 0.85,
					phase = 0.3,
					stretched = 0.5,
				},
				{
					across = -950,
					y = 300,
					length = 160,
					speed = 1.15,
					phase = 0.78,
					stretched = 0.6,
				},
				{
					across = -1100,
					y = 330,
					length = 160,
					speed = 0.8,
					phase = 0.12,
					stretched = 0.7,
				},
				{
					across = -1250,
					y = 350,
					length = 150,
					speed = 1.05,
					phase = 0.95,
					stretched = 0.5,
				},
				{
					across = 600,
					y = 160,
					length = 130,
					speed = 0.9,
					phase = 0.85,
					stretched = 0.4,
				},
				{
					across = 650,
					y = 185,
					length = 140,
					speed = 0.9,
					phase = 0.35,
					stretched = 0.5,
				},
				{
					across = 800,
					y = 210,
					length = 150,
					speed = 1.1,
					phase = 0.18,
					stretched = 0.5,
				},
				{
					across = 950,
					y = 240,
					length = 160,
					speed = 0.95,
					phase = 0.62,
					stretched = 0.6,
				},
				{
					across = 1100,
					y = 270,
					length = 150,
					speed = 1.2,
					phase = 0.42,
					stretched = 0.6,
				},
			},
		},
	},
	motes = {
		list = {
			-- leaves off the grove and the tall pair, petals off the hollow log's flowers and the sundial's beds
			{
				x = 325,
				y = 30,
				z = -151,
				radius = 16,
				count = 6,
				kind = "leaf",
				fall = 26,
				colours = { { 92, 160, 70 }, { 150, 190, 74 } },
			},
			{
				x = -354,
				y = 34,
				z = -65,
				radius = 14,
				count = 5,
				kind = "leaf",
				fall = 26,
				colours = { { 70, 140, 74 }, { 120, 176, 70 } },
			},
			{
				x = -391,
				y = 18,
				z = 196,
				radius = 16,
				count = 5,
				kind = "petal",
				fall = 18,
				colours = { { 240, 120, 96 }, { 250, 214, 120 } },
			},
			{
				x = 478,
				y = -6,
				z = -28,
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
		-- moved out with the doubled rim (2026-11-10 b): each by how far the rim moved at its bearing
		{ name = "Sundial", x = 486, y = 60, z = -38, radius = 95 },
		{ name = "Launch isle", x = 378, y = -20, z = 290, radius = 95 },
		{ name = "Near balloon", x = -320, y = 78, z = -301, radius = 22 },
	},
	standIn = { floor = { 110, 168, 92 }, ring = { 240, 236, 214 } },
}
-- SUNNY (owner 2026-11-26: "change lighting to make it more like idk, sunny or smth"): a higher, brighter, warm midday
-- sun with crisper shadows, warmer lighter shade, a little more colour; and a hazier distance with the blur (the far
-- islands "hard to see"), the haze the sky's own pale horizon colour so the horizon line disappears. Tuned live in a
-- play test from a fighter's eye (2026-11-26, life-2).
-- LESS PLASTIC (owner 2026-11-26: "it kinda has that plastic vibe ... yes i want it to be sunny but add some realism";
-- he picked B, life-4): a stronger sun against a lower, cooler shade, no specular sheen on the smooth floor, calmer
-- colour and less glow. The ground's realism itself is the painted map under the studs (HT_GroundMap, HT_GrassGrain),
-- which draws the same at the lowest quality; this light only adds to it where the quality allows.
meadowEnvironment.sun =
	{ clockTime = 13.2, latitude = 50, colour = { 255, 238, 208 }, brightness = 3.1 }
meadowEnvironment.ambient = {
	ambient = { 96, 104, 124 },
	outdoor = { 118, 128, 152 },
	bottom = { 26, 34, 20 },
	shadowSoftness = 0.12,
	diffuse = 0.9,
	specular = 0,
}
meadowEnvironment.exposure = -0.05
meadowEnvironment.grade =
	{ saturation = -0.04, contrast = 0.14, brightness = 0, tint = { 255, 248, 236 } }
meadowEnvironment.bloom = { intensity = 0.2, size = 28, threshold = 1.6 }
meadowEnvironment.sunRays = { intensity = 0.05, spread = 0.15 }
-- (offset 0.35, not more: with the pale gradient sky a high offset pulls the far islands into the sky's colour and the
-- windmill, which he wants seen turning, went ghostly; measured from a fighter's eye 2026-11-26)
-- (haze 0: at the LOWEST graphics quality the Atmosphere's haze paints a blue band under the horizon, the split he
-- disliked, MEASURED 2026-11-26 at quality 1; the gradient sky blends the horizon by itself, and density still hazes
-- the far islands at every quality)
meadowEnvironment.atmosphere = {
	density = 0.28,
	offset = 0.35,
	colour = { 196, 225, 251 },
	decay = { 150, 196, 246 },
	glare = 0,
	haze = 0,
}
MapEnvironments.Maps.meadow = {
	name = "Grassy Plains",
	model = "Meadow",
	codeObstacles = false,
	-- THE CIRCLE (owner 2026-11-22): both semi-axes are its radius, 180 studs (design/maps/suite/meadow.py RADIUS,
	-- the floor's collider in the map model). 180, not the mock's 194: the ring-out line is this plus
	-- Arena.PlayAreaMargin (60), and at 240 the whole lobby (its rock front 242 out, its edge Lobby.ViewEdgeZ 250)
	-- stays past it, so nobody knocked that way lands on the lobby still in the round (tests/ArenaShape.spec).
	arena = {
		semiX = 180,
		semiZ = 180,
		-- the spawns ALMOST AT THE EDGE (owner 2026-11-26: "make it so they're almost a thte edge of the arena"): a ring
		-- at 0.9 of the radius, 162 studs out, 18 studs (about a dash) in from the drop, every fighter facing the middle
		spawnShare = 0.9,
	},
	-- THE POND (owner 2026-11-26, his idea; the lily pond look picked from a sheet): the old Gnomon map's wading pond,
	-- the same shape, in the middle of the circle (Core/Pond: wading in it slows you by GameConfig.Pond). The numbers
	-- are design/maps/suite/meadow.py POND's in Roblox axes (z = -Blender y); the basin, the water, the lily pads and
	-- the reeds are in the map's model (Map_Meadow_Floor_Pond*, Map_Meadow_Pond_*), the bowl's collider in HT_Collision.
	pond = {
		x = 0,
		z = 0,
		semiX = 24,
		semiZ = 18,
		wobble = { { 3, 0.08, 0.6 }, { 5, 0.05, 2.1 } },
		depth = 1.6,
		inner = 0.68,
		water = 0.55,
	},
	environment = meadowEnvironment,
	-- Shared/MapExtras: the windmill's sails turn about their hub (arena-local; design/maps/out/suite/meadow_r3/
	-- landmarks.json; the axis points at the arena), at 9 turns a minute: noticeably moving from the arena (owner
	-- 2026-11-26: "it should be notiacble that its moving tho, dont make it slow"; it was 3; MapMotion allows up to 12)
	spinners = {
		{
			parts = { "Map_Meadow_WindmillSails_Timber_N", "Map_Meadow_WindmillSails_Cream_N" },
			hub = { -375.39, 292.69, -797.7 }, -- the 1.7x mill on its lifted island (meadow.py, out/suite/meadow_r3)
			axis = { 0.4258, 0, 0.9048 },
			rpm = 9,
		},
	},
	-- the phone path: far islands and small far detail come out of a phone's copy of the map, and so does the floor
	-- flowers' B layer (meadow.py floor_flowers: phones keep layer A, 40% of the flowers), and the grass grain under
	-- the studs (life-4: a second see-through layer over most of the screen, about 0.35 ms of GPU on a PC at quality
	-- 10, measured 2026-11-26; phones keep the painted ground map, which carries the look)
	phoneHide = {
		"_FarN",
		"_FarNE",
		"_FarNW",
		"_Trees_",
		"_Crops_",
		"_Hedges_",
		"_FarHouse_",
		"_FloorFlowers_B_",
		"HT_GrassGrain",
	},
	-- FULL OF LIFE (owner 2026-11-26, his picks from a list; every model and motion checked by him in the Blender
	-- preview, design/maps/suite/meadow_life.py): the pieces are in the map's model under HT_Life (Studio:
	-- design/maps/suite/studio_life.py from the game build meadow_life_game.py), moved on each client by
	-- Shared/MapLife with Core/MapLife's rules. Cosmetic only: nothing collides, is hit or is sent anywhere.
	-- PHONES: `phone` = how many are kept; the vines and roots under the rim are left out (rimOnPhones).
	life = {
		near = 260, -- studs from the camera: past this the floor's creatures and the vines freeze
		far = 1600, -- studs: past this the birds and the animals freeze
		-- "you'll NEVER be able to hit the butterfly, if u dash towards a butterfly they'll move out the way while
		-- making their wings flap faster": a fighter within `reach` coming AT one at `speed` or more (a dash, a charge),
		-- or anyone closer than `close`, makes it dart `dart` studs aside and `rise` up, wings 4 -> 12 beats a second;
		-- `lead`: a fighter coming at it is seen that much sooner (a 60-stud dash is within 8 studs for ~0.13 s).
		-- `see`: farther from the camera than this it stands still (a 1-stud butterfly, a 0.3-stud bee: too small)
		-- MORE (owner 2026-11-26, life-5: "subtle yes, but at least noticeable"), then FEWER AND FLYING (life-6: "you
		-- kinda overdid it with the butterflies, also they should smoothly move out the way. not instantly teleport. they
		-- also like fly around, not just fly in cricles in one spot"): the model's 14 plus copies made on each client up
		-- to `count` (Core.extraHomes: a companion beside each in turn); `scale` 1.4 = a 1.4-stud wingspan. Each FLIES
		-- from stop to stop up to `wander.range` studs round its home (and `lift` up), at most `speed` studs a second,
		-- lingering `linger` seconds at each; a dodge is a quicker glide (`flee`: `quick`, `speed`, for `time` s) to a
		-- point `dart` aside and `rise` up, so it starts and stops smoothly, never jumps. `flutter`: the little loop laid
		-- on the flight. `lead` 0.25: seen sooner, so the smooth swerve is ~3 studs aside by the time a dash arrives.
		butterflies = {
			calm = 4,
			fast = 12,
			reach = 8,
			close = 2.5,
			speed = 18,
			lead = 0.25,
			dart = 4.2,
			rise = 2,
			phone = 8,
			see = 80, -- (120 before life-5: past 80 studs a 1.4-stud butterfly is a 10-pixel dot)
			count = 24,
			scale = 1.4,
			flutter = 0.3,
			wander = {
				range = 28,
				lift = 2.5,
				speed = 5,
				quick = 1.2,
				linger = { 0.6, 2.5 },
				edge = 165,
			},
			flee = { quick = 7, speed = 14, time = 0.9 },
			spread = { pair = { 3, 6 }, ring = { 35, 160 }, apart = 14, lift = 1.2 },
		},
		bees = { phone = 3, see = 60 },
		-- birds (the preview's loops, arena-local): two gull flocks round the north and east islands, swallows under
		-- the rim; a lap every 20 s
		flocks = {
			{
				kind = "Gull",
				centre = { -150, 70, -420 },
				radii = { 170, 110 },
				dir = 1,
				period = 20,
				count = 6,
				spread = 14,
				flap = 3,
				amp = 0.55,
			},
			{
				kind = "Gull",
				centre = { 420, 55, -120 },
				radii = { 150, 120 },
				dir = -1,
				period = 20,
				count = 5,
				spread = 14,
				flap = 3,
				amp = 0.55,
				phone = false,
			},
			{
				kind = "Swallow",
				centre = { 0, -24, 0 },
				radii = { 198, 198 },
				dir = 1,
				period = 20,
				count = 6,
				spread = 5.6,
				flap = 5,
				amp = 0.7,
				phone = false,
			},
		},
		balloons = { loop = 120, speed = 2.5 }, -- studs across their slow loop, studs a second
		rimOnPhones = false,
		rimSee = 150, -- studs: the vines and roots sway only this near the camera (at the arena's edge, looking over)
		-- "dandelion puffs that burst when run through": within `reach` at `least` studs a second; back after `regrow` s
		dandelions = { reach = 1.2, least = 2, regrow = 25, grow = 2, seeds = 8 },
		splashes = { moving = 0.4, standing = 0.9, drops = 4, above = 4.5 }, -- seconds apart; `above`: root height wading
		petals = { every = 4, count = 28, phone = 10 }, -- a gust every 4 s (the wind's gustSeconds)
		-- NO CLOUD SHADOWS (owner 2026-11-26, after two tries: "remove the shadow shade i dont like it ... it kinda just
		-- makes like the map isn't fully rendered"): no `shadows` entry, so MapLife hides any HT_CloudShadow it finds
		-- and slides nothing. The ground's light and dark now come from the painted ground map (still, under the studs).
		-- A map that wants them back gives `shadows = { tile, speed, transparency }` (Core/MapLife.problems checks it).
		smoke = { phone = 10, phoneRate = 1.2 }, -- chimneys a phone keeps (the nearest), and their puffs a second
	},
	-- THE FLOOR (owner 2026-11-22, the stud style): one flat green with dirt patches and small stud flowers, all in
	-- the map's own meshes (Map_Meadow_Floor_*, Map_Meadow_FloorFlowers_*), the studs a Texture on the floor
	-- (HT_FloorStuds). The grass blades of the old style are gone; no `fieldGrass` entry, no per-frame cost.
}

-- PARKED, used by no map (2026-11-22): the moving grass ring round the fighter (Shared/FieldGrassField,
-- Core/FieldGrass, ReplicatedStorage.HT_FieldGrass; design/maps/suite/field_grass.py). Map 1's static grass, which
-- replaced it, was itself replaced by the stud floor on 2026-11-22, so nothing waits on this any more: it and its
-- code can be removed when the owner says. To bring it back on a map, set that map's entry
-- `fieldGrass = MapEnvironments.FieldGrassRing`.
-- Owner, 2026-11-20: "that feel of you running through a grass field, shouldn't be taller than the character, wind
-- should also blow on it": knee-to-thigh clumps in a ring round the camera.
MapEnvironments.FieldGrassRing = {
	cell = 6, -- studs between clump roots (big, full clumps: fewer parts to move; field_grass.py v2)
	-- MEASURED 2026-11-22 in Studio Play on this PC (a second field timed on its own): ring 66, these tiers: 0.48 ms
	-- a frame median, 0.58 average, 410 clumps; the phone ring 36: 0.27 ms median here, 131 clumps
	radius = 66, -- drawn this far round the camera
	radiusTouch = 36, -- phones
	fade = 24, -- the ring's last studs: clumps sink into the floor (long and soft, so no line shows)
	fadeTouch = 14,
	margin = 2.5, -- kept clear inside the edge
	variants = 4,
	scale = { 0.6, 0.9 }, -- 1 to 2.3 studs: knee to hip, so feet and landings still show (fresh review)
	-- the tips' greens: the meshes shade from 0.62 at the root to 1 at the tip, so a root sits just under the painted
	-- floor (92, 154, 76) and a tip a little lighter
	colours = { { 124, 194, 98 }, { 112, 182, 92 }, { 138, 198, 102 }, { 118, 188, 108 } },
	gustBoost = 2.2, -- tall grass waves harder than the map's wind numbers
	-- how often clumps move (MEASURED 2026-11-22 in Studio: moving a clump costs about 3 microseconds, so the
	-- frame cost is the number moved each frame): within tierNear of the camera every frame, out to tierMid every
	-- midEvery-th frame, beyond that every farEvery-th (their sway is slow; the ring's edge still sinks smoothly).
	-- Any clump being parted moves every frame. Phones (touch) use the *Touch numbers.
	tierNear = 14,
	tierMid = 30,
	midEvery = 6,
	farEvery = 16,
	tierNearTouch = 10,
	tierMidTouch = 22,
	bendRadius = 4.2, -- studs round a character that part the grass
	bendMax = 55, -- degrees at a character's feet
	sink = 0.15,
	height = 2.6, -- the tallest clump at scale 1 (field_grass.py), under a fighter's 5
}

-- MAP 2 OF THE ARENA SUITE, "The Limestone Pit" (Sunbaked Quarry; owner's pick 2026-11-21 from the design sheet
-- design/maps/out/suite/design_2-6/; design/maps/suite/quarry.py): the freshly sawn top of a sandstone block in open
-- sky, the quarry's works floating round it, the Great Derrick for its landmark. Map 1's clear air with a warmer sun.
-- NOT IN THE ROTATION until the owner approves it (game.json Maps.Rotation).
-- A DEEP copy: Quarry owns every table in it, so tuning Map 1's air (meadowEnvironment) never changes Map 2's.
local function deepCopy(t: any): any
	local out = {}
	for k, v in t do
		out[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return out
end
local quarryEnvironment = deepCopy(meadowEnvironment)
quarryEnvironment.sun =
	{ clockTime = 14.6, latitude = 50, colour = { 255, 228, 190 }, brightness = 2.5 }
quarryEnvironment.grade =
	{ saturation = 0.06, contrast = 0.18, brightness = 0, tint = { 255, 249, 240 } }
-- the clouds keep out of the view to the Great Derrick (mast at 560, -760, 416 tall; the boom and its block swing out
-- to about x 265): Gnomon's landmarks (sundial, balloons) don't exist here (fresh review 2026-11-21: a cloud crossed
-- the mast head)
quarryEnvironment.landmarks =
	{ { name = "Great Derrick", x = 430, y = 210, z = -720, radius = 230 } }
-- so the north side's drift lanes fly HIGH, over the derrick's head (Map 1's six north lanes at 210-350 studs all
-- crossed its view); the lobby side's lanes are Map 1's
do
	local lanes = {}
	for _, lane in quarryEnvironment.clouds.drift.lanes do
		if lane.across > 0 then
			table.insert(lanes, lane)
		end
	end
	for _, high in
		{
			-- high over the derrick (a scan of across x height on 2026-11-21: on this side only lanes about 700+ studs up
			-- clear its view, which the check sweeps as a box out to twice its distance)
			{ across = -650, y = 700, length = 150, speed = 1.0, phase = 0.15, stretched = 0.5 },
			{ across = -900, y = 800, length = 160, speed = 0.9, phase = 0.6, stretched = 0.6 },
			{ across = -1300, y = 950, length = 150, speed = 1.1, phase = 0.85, stretched = 0.5 },
		}
	do
		table.insert(lanes, high)
	end
	quarryEnvironment.clouds.drift.lanes = lanes
end
MapEnvironments.Maps.quarry = {
	name = "The Limestone Pit",
	model = "Quarry",
	codeObstacles = false,
	arena = {
		semiX = 213,
		semiZ = 176,
		spawnShare = 0.65,
	},
	environment = quarryEnvironment,
	-- Shared/MapExtras: the derrick's boom, its ropes and its hanging block swing slowly round the mast (5 parts).
	-- The hub is the mast's foot (quarry.py DERRICK, arena-local; the boom's own foot, landmarks.json "pivot", sits
	-- 16.9 studs off it), so the stay from the mast head stays on the mast.
	spinners = {
		{
			mode = "swing",
			parts = {
				"Map_Quarry_DerrickBoom_Crane_Derrick",
				"Map_Quarry_DerrickBoom_Honey_Derrick",
				"Map_Quarry_DerrickBoom_Lantern_Derrick",
				"Map_Quarry_DerrickBoom_Rope_Derrick",
				"Map_Quarry_DerrickBoom_Rose_Derrick",
			},
			hub = { 560, 31.4, -760 },
			axis = { 0, 1, 0 },
			amp = 12, -- degrees each way: the hanging block sweeps about 60 studs
			period = 60, -- seconds a full swing
		},
	},
	-- the phone path: the three far blocks and the far ledge come out of a phone's copy of the map
	phoneHide = { "_FarN", "_Ledge" },
}

return MapEnvironments
