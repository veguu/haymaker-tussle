# Session log 2026-11-22: flat 2D ground puff (new references)

- Soft poof (smoke_poof.py) never got a verdict: the owner sent 8 new references instead (JbZ6yIWySGE Arcane smoke
  process, mmfhHXmdIDQ green-screen 2D shapes and smoke, Z6gikDvLa44 2D fire pack, LxpPLp6h06A 2D explosion frame by
  frame, 9NgxCGkzsvg Houdini anime smoke, Y3Iy-KMwSz0 Arcane 2DFX line test, rTzu-H2-ymU How to animate smoke,
  3p2kbKpKLeI wave principle). Dense sheets: design/vfx/smoke-study/refs-2026-11-22/d_*.jpg.
- What they share: flat fills, hard edges, one lumpy silhouette, 2-3 flat tones, pops in 2-4 drawings, dies by HOLES
  opening (never an alpha fade), redrawn every drawing (about 12 a second).
- Owner picks: "Green-screen puff" (over the explosion smoke); "Ground dust only" = an exact-style copy with a flat
  bottom as a NEW texture for the dash dust first; the old Tex.Smoke stays in the other ~25 effects.
- Reference measured (measure_puffB.py, 580 x 400 cut, 30 fps, video frames 16-35): 16 unique drawings (held: 19, 24,
  29, 34). Width 68 100 178 370 394 414 430 449 469 490 500 502 506 px; height 20 75 139 246 ... 310; holes share of
  the filled outline 0 2 5 16 23 31 40 50 57 64 72 83 89 90 %; bursts from a point 24 % from the left; the foot stays
  on the ground until drawing 11, then lifts 3 7 11 20 26 % of the height.
- Build: design/vfx/smoke/smoke_puff2d.py (14 s). A dome cut into 14 cells (weighted Voronoi by half-plane clipping,
  my own layout: the reference is a paid template, not traced). White = cells with the outer edge bowed into lobes;
  holes = the cells inset, as HOLDOUT meshes in front (EEVEE, emission white, film transparent, Standard). The inset
  per drawing is SOLVED (bisection) to hit the reference hole share. Line stage: uniform thin inset, no rounding,
  then gaps (holdout strips along every wall) that grow, then whole walls go.
- Traps: (1) uniform inset = every hole a shrunken copy of its cell = turtle shell / football; fixed with inset in
  step with cell size, lopsided per side (LEAN) and a wave field. (2) Rounded holes at the line stage leave pointed
  triangles at the junctions when walls go: no rounding from drawing 11. (3) Removing whole walls only = a few long
  ruled strokes; the reference breaks every line into dashes: gaps. (4) Even gaps = a "cut here" dashed line: one
  long and one short gap per line. (5) A convex dome with one big top lobe = a pyramid: broader shoulders, smaller
  top bump. (6) The thrown bits widened the framing: left out of the width.
- Numbers (compare_puff2d.py), reference / mine: area % of peak 2 10 30 98 100 98 90 79 70 60 45 23 10 5 1 0 /
  2 9 30 97 100 97 88 78 73 64 51 22 13 4 1 0; holes % 0 2 5 16 23 31 40 50 57 64 72 83 89 90 / 0 2 5 16 23 31 41
  52 58 65 74 89 89 74. check_flipbook.py (SMOKE_LOOK=toon): 11 of 11 pass.
- Ground line: 22.5 % of the cell below its middle (an emitter must sit that share of Size above the floor; Size
  must stay constant or the foot sinks).
- Preview: preview_puff2d.sh -> out/puff2d_vs_reference.mp4 (real speed), _slow.mp4 (6 fps), _stills.png.
- Not done: owner verdict; upload; emitter; Studio test.

## Swirl puff (the owner's second pick, same day)
- OWNER on the dome-with-holes preview: posted the sheet of the OTHER puff in the same clip (d_green_puffA) with
  "i think i prefer this animation". The dome (smoke_puff2d.py) is dropped. Lesson recorded in the vault: 56 Field
  Notes, Studying VFX References, section 13 (one sheet per effect, pictures in the question).
- Reference measured (measure_puffA.py, 608 x 560 cut from 5.7 s, 30 fps, video frames 4-31 = 0.93 s): 23 drawings
  (held: 5, 10, 15, 20, 25, 30). Growing 4-19: width 76 146 178 249 284 338 366 456 px, height 50 130 160 203 243 397
  464 493, area 1.9k -> 110k px; one mass until frame 17, three at 19. Frame 20: NINE beans (areas 19.0k 11.5k 11.1k
  10.8k 7.5k 7.4k 3.3k 2.6k 2.1k), then each drifts outward 0.6-0.9 units and shrinks to a dot by frame 30. Every
  bean's path and area per drawing is in smoke_swirl.py (TRACKS, AREAS). Burst point x = 270, ground y = 540.
- Build: design/vfx/smoke/smoke_swirl.py (30 s). METABALLS (one metaball object per drawing, each its own family
  name so they never melt across drawings; a lone ball's surface is at 0.575 of its radius at stiffness 2, threshold
  0.6). Nine beans of three balls each. Growing: the beans lie on a spiral (foot, right side, top, left, middle),
  squashed by the reference's width and height per drawing, revealed along the spiral, bridged by extra balls;
  drawn gaps (the side notch, the curl, the split) are tapered Catmull-Rom bands as HOLDOUT meshes in front; a
  holdout plane cuts the foot flat at the ground. Breaking up: positions and areas straight from the measurements.
- Traps: (1) beans alone never melt into one mass: bridges between neighbours. (2) Bridged all round = a doughnut;
  filled in the middle = a lump with a line drawn on it. The reference is an open BAND (a "Z") early: reveal the
  middle beans last and leave the inside open to the notch. (3) A bean missing from the middle leaves a square pin
  hole: order of reveal. (4) Strong bend on small beans = hearts. (5) check_flipbook's "centre within 12 px
  sideways" fails by 1.3 px on drawing 9 (-13.3): the left bean is the biggest, as in the reference; not changed.
- Numbers (compare_swirl.py), reference / mine, area in units^2: 0.19 0.65 1.27 2.96 4.19 6.43 8.32 11.01 7.55 6.30
  3.40 2.12 0.97 0.43 0.19 0.02 / 0.16 0.77 1.62 2.92 4.02 7.69 9.88 10.98 7.77 6.28 3.63 2.34 1.14 0.53 0.26 0.03.
  Shapes: 1 x 7, 3, 9 x 7, 3 / 1 x 7, 3, 8, 9 x 6, 3.
- Ground line: 37.8 % of the cell below its middle. Preview: preview_swirl.sh -> out/swirl_vs_reference.mp4 (mine
  played evenly over 0.93 s, as the game plays a flipbook), _slow.mp4, _stills.png.
- Not done: owner verdict; upload; emitter; Studio test.

## Swirl puff into the game (build puff-1)
- OWNER: "Yes, try in Studio"; dialog pick "One puff" (a single swirl at the feet, about 4 studs, 0.9 s).
- Upload: out/smoke_swirl.png served by Blender's python http.server on 8765 -> rbxassetid://72521547682766
  (FxKit.Tex.SwirlPuff). The old Tex.Smoke (97818702295807) is untouched and still used by every other effect.
- DashFx dust emitter (src/client/Fx/DashFx.luau): Texture SwirlPuff, Grid4x4 OneShot, FlipbookBlendFrames false,
  Orientation FacingCameraWorldUp, Lifetime 0.9, Speed 0, Rotation 0, RotSpeed 0, Size 2.75 constant, Transparency 0,
  LightEmission 0, LightInfluence 0, Emit(1). Attachment y = -3 + 2 * 2.75 * 0.378 = -0.921 (root to floor measured
  3.000 on R6). Was: 10 puffs, Lifetime 0.35-0.6, Speed 6-14, spin 0-360, Size 0.9 -> 2.2, Transparency 0.55 -> 1.
  GameConfig.Effects.DashDustCount is now unused (left in: the place's GameConfig differs from disk, not ours to sync).
- Place: FxKit, DashFx and Server patched by multi_edit with the same strings, confirmed by hash (FxKit 4213012063,
  DashFx 2990606025, Server 1023562103). Stamp cam-1+jab-3+keys-1+kits-8t+puff-1+village-4+ui-20e seen in Output.
  GameConfig in the place (hash 3617103686) is NOT the disk's (2985240790): not touched.
- Gates: rojo build OK, 608 tests, selene 0, stylua clean, fx_smoke 7 of 7.
- Seen in Play (frozen, 4-stud poles for scale): with the default cross-fade the puff showed two drawings as ghosts;
  FlipbookBlendFrames false fixed it. Puff about 3.1-3.6 studs tall at the swirl, foot on the floor line, flat white.
  Four moments in one shot (0.14 / 0.38 / 0.55 / 0.76 s): wisp, swirl with curl, beans, dots. On grass and sand it
  reads well; on the lobby's pale limestone it nearly disappears.
- NOT seen: the puff from a real T dash on screen (the dash ran and the emitter fired, but the game camera faced
  away). Full speed is the owner's to judge.
- Docs fact for later: FlipbookLayout Custom + FlipbookSizeX/Y would allow more than 16 drawings (the reference has 23).

## Housekeeping after the owner's "Looks right" (puff-1)
- Owner picks (dialog): commit "Code and scripts"; J test key "Remove it"; roll sign "Fix and reframe".
- J key removed from AnimController on disk and in the place (hash 1954554253 both). The Studio-only merge of the
  hand clips stays.
- Roll sign: ALREADY fixed on disk by the 2026-11-21 session after it wrote its handoff note (project() turns as the
  game does; the flurry's side shot at LAST_PUNCH + 0.14 went fov 60 -> 60.4 so the floor under the attacker stays
  inside the tablet's safe frame). The place had not been given the reframe: patched now, Ultimates hash 3416957725
  on both sides. Lesson: check an "open question" in a handoff against the files before asking the owner about it.
- Commit 32f76ac on main (52 files, 1.5 MB; .blend files, renders, previews and reference frames ignored). Not pushed.
- A stray `git stash` on AnimController (my mistake) was popped at once; nothing lost.
