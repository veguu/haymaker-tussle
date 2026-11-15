# Evidence: Haymaker Tussle lobby + lobby barrier (2026-11-14)

Facts only. Two items to score: (A) the lobby against rubric world.md, (B) the barrier against rubric vfx.md.

## A. Lobby ("Cliffside courtyard")
Brief: a cliffside courtyard lobby where players wait between rounds of a brawler; three terraces (balcony, court +3,
training +6 studs) stepping up away from the arena; golden-hour light; rock formations; custom low-poly Blender props
in the same art style as the game's first arena (flat-shaded, cream/sand/blue rock, coral and gold accents).

Images:
- `ingame_spawn_lobby_state.jpg`: Roblox Studio Play, the player's own camera at spawn, lobby state, golden-hour
  lighting as shipped. Orange figures are test bots. HUD is the game's.
- `ingame_barrier_left_wall.jpg`: Play, player next to the left wall (barrier visible on the right of the frame;
  the camera sits inside a planter bush).
- `cliffside_court.png`, `cliffside_over.png`, `cliffside_spawn.png`, `cliffside_training.png`, `cliffside_arena.png`:
  Blender review renders of the same model (not in-game lighting).
- `prover_plan.png`: top-down plan from the reachability prover.

Measured:
- Reachability prover (roblox-map prove.py, movement profile = the game's own numbers, worst case running jump
  16.3 studs up): P1 grounding PASS, P2 standable PASS (1612 nodes), P2b recovery PASS, P3 intent PASS (every
  terrace, ramp and low prop reachable; tall posts and tree trunk unreachable, no pockets with no way out), P5
  sightlines PASS, P10 coplanar PASS, P11 empty space PASS (17%, budget 22%), P16 enclosure PASS. P6 overlap FAIL:
  invisible collision boxes deliberately sunk into each other (never rendered).
- Hand walk in Play (keyboard): balcony -> ramp -> court -> ramp -> training and back down, both ramps both ways, no
  snag or drop; front and back walls and the stair-end planters stop the character where drawn.
- Model: 132 parts (all MeshParts), all anchored, 0 colliding (collision is separate invisible parts), 0 lights.
  33 meshes at their intended centres within 0.001 studs; walking surfaces raycast to 0.00 / 3.00 / 6.00 studs.
- Frame cost, lobby state alone, Studio on a desktop PC: 227 fps, 4.4 ms per frame, 44 draw calls, 119k triangles
  in view. Plant wind sway 0.11 ms a frame (capped 45 Hz; phones 30 Hz). Not measured on a phone.

## B. Lobby barrier (hexagon force-field on the lobby's four invisible walls)
Purpose: an ambient boundary, not an attack. Reference: `barrier_reference_frame0/80/160.png` (frames of the
user's reference GIF): near-invisible hexagon grid at rest; a patch of hexagon lines fades in around a nearby
figure, the nearest 1-2 cells go white-cyan with soft fill and bloom; the pattern drifts up-right.
Built: client-only SurfaceGuis on thin non-colliding parts: tiled hexagon line image drifting up-right, an upward
sweep band, pooled hexagon cells lit by 3D distance to each player (two tiers: 16-stud patch at 45%, full brightness
inside 6 studs), fades in/out. Off beyond a view distance.
Image: `ingame_barrier_left_wall.jpg` (right side of the frame).
Measured: script cost 0.05 ms a frame with nobody near, 0.23-0.28 ms with 72-84 cells lit, peak 0.54 ms (PC).
No ParticleEmitters, no lights. Persistent effect (not a burst); its parts and connections live for the session.
Asset ids are the project's own uploads (tile 135568689839955, cell 73567244841968, halo 118818857382687).
Not seen in motion by the reviewer (stills only).
