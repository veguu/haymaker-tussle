--!strict
-- GENERATED FILE - DO NOT EDIT BY HAND.
-- Source: design/lobby/cliffside.py (Blender) -> design/lobby/out/cliffside/collision.json
-- Regenerate: python design/lobby/gen_layout.py
-- The lobby's solid pieces, which LobbyService builds invisible: u across from the centre, d back from the
-- viewing edge, h above Lobby.FloorY. box and wedge: u0..u1, d0..d1, h0..h1 (a wedge climbs from h0 at d0
-- to h1 at d1). cyl: an upright post at u, d of radius r, from h0 to h1.

local LobbyLayout = {
	colliders = {
		{ kind = "wedge", u0 = -66, u1 = 66, d0 = 21, d1 = 27, h0 = 0, h1 = 3 },
		{ kind = "box", u0 = -66, u1 = 66, d0 = 27, d1 = 150, h0 = -1, h1 = 3 },
		{ kind = "box", u0 = -66, u1 = -46, d0 = 19, d1 = 31, h0 = -1, h1 = 4.7 },
		{ kind = "box", u0 = 46, u1 = 66, d0 = 19, d1 = 31, h0 = -1, h1 = 4.7 },
		{ kind = "wedge", u0 = -66, u1 = 66, d0 = 95, d1 = 101, h0 = 3, h1 = 6 },
		{ kind = "box", u0 = -66, u1 = 66, d0 = 101, d1 = 150, h0 = 2, h1 = 6 },
		{ kind = "box", u0 = -66, u1 = -46, d0 = 93, d1 = 105, h0 = 2, h1 = 7.7 },
		{ kind = "box", u0 = 46, u1 = 66, d0 = 93, d1 = 105, h0 = 2, h1 = 7.7 },
		{ kind = "box", u0 = -66, u1 = -48, d0 = 44, d1 = 80, h0 = 2, h1 = 4.9 },
		{ kind = "cyl", u = -57.5, d = 62, r = 2.4, h0 = 3.9, h1 = 18.9 },
		{ kind = "box", u0 = -45.8, u1 = -43.8, d0 = 48.4, d1 = 55.6, h0 = 3, h1 = 4.75 },
		{ kind = "box", u0 = -45.8, u1 = -43.8, d0 = 68.4, d1 = 75.6, h0 = 3, h1 = 4.75 },
		{ kind = "box", u0 = 54.6, u1 = 58.8, d0 = 39.4, d1 = 84.6, h0 = 3, h1 = 6.3 },
		{ kind = "cyl", u = 54.8, d = 40, r = 0.6, h0 = 3, h1 = 12 },
		{ kind = "cyl", u = 54.8, d = 62, r = 0.6, h0 = 3, h1 = 12 },
		{ kind = "cyl", u = 54.8, d = 84, r = 0.6, h0 = 3, h1 = 12 },
		{ kind = "box", u0 = 50.8, u1 = 56.4, d0 = 33.8, d1 = 37.1, h0 = 3, h1 = 5.6 },
		{ kind = "box", u0 = 51.2, u1 = 56.9, d0 = 86.6, d1 = 89.8, h0 = 3, h1 = 5.4 },
		{ kind = "cyl", u = 49.4, d = 87.6, r = 1.5, h0 = 3, h1 = 6.625 },
		{ kind = "cyl", u = 49.8, d = 36.6, r = 1.32, h0 = 3, h1 = 6.19 },
		{ kind = "cyl", u = -19, d = 99, r = 1.6, h0 = 3, h1 = 20 },
		{ kind = "cyl", u = 19, d = 99, r = 1.6, h0 = 3, h1 = 20 },
		{ kind = "cyl", u = -44.8, d = 25, r = 0.6, h0 = 0, h1 = 15 },
		{ kind = "cyl", u = 44.8, d = 25, r = 0.6, h0 = 0, h1 = 15 },
		{ kind = "cyl", u = -58, d = 147.8, r = 0.6, h0 = 6, h1 = 19 },
		{ kind = "cyl", u = -30, d = 147.8, r = 0.6, h0 = 6, h1 = 19 },
		{ kind = "cyl", u = 30, d = 147.8, r = 0.6, h0 = 6, h1 = 19 },
		{ kind = "cyl", u = 58, d = 147.8, r = 0.6, h0 = 6, h1 = 19 },
		{ kind = "cyl", u = -40, d = 140.5, r = 0.95, h0 = 6, h1 = 12.2 },
		{ kind = "cyl", u = -20, d = 140.5, r = 0.95, h0 = 6, h1 = 12.2 },
		{ kind = "cyl", u = 0, d = 140.5, r = 0.95, h0 = 6, h1 = 12.2 },
		{ kind = "cyl", u = 20, d = 140.5, r = 0.95, h0 = 6, h1 = 12.2 },
		{ kind = "cyl", u = 40, d = 140.5, r = 0.95, h0 = 6, h1 = 12.2 },
		{ kind = "cyl", u = -60, d = 8, r = 1.6, h0 = 0, h1 = 4.4 },
		{ kind = "cyl", u = 61, d = 144, r = 1.6, h0 = 6, h1 = 16.5 },
		{ kind = "cyl", u = -61, d = 143, r = 1.6, h0 = 6, h1 = 10.4 },
		{ kind = "cyl", u = 60, d = 9, r = 2.6, h0 = 0, h1 = 3.6 },
		{ kind = "cyl", u = -59, d = 137, r = 2, h0 = 6, h1 = 8.4 },
	},
}

return LobbyLayout
