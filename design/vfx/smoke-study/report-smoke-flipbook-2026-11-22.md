# Report for the tutorial session: the smoke flipbook test piece (2026-11-21 to 2026-11-22)

The brief's own "Report back" list was not on disk, so the seven parts below are my reading of it (result, pipeline,
numbers, traps, the owner's taste, self-checks, what is open). Every number and the owner's exact words are in
`design/vfx/smoke-study/session-log-2026-11-21.md` (from line 78) and `session-log-2026-11-22.md`.

## 1. Result
- Approved in Studio at full speed, 2026-11-22: "Looks right". Build `puff-1`.
- What shipped: a flat white, hard-edged, 16-drawing flipbook (`FxKit.Tex.SwirlPuff`, rbxassetid://72521547682766)
  on the dash dust only: one upright puff at the feet, 0.9 s. A wisp rises off the ground, curls into a swirl, splits
  into nine beans and shrinks to dots that drift outward. Nothing fades.
- It took four builds: toon lobes (rejected), soft poof (six correction rounds, never judged), a dome that dies by
  holes (built from the wrong effect in the right clip), then the swirl. The old shared `Tex.Smoke` is untouched.

## 2. The pipeline that worked
1. References as frames: `yt-dlp -f "bv*[height<=1080]"`, then ffmpeg sheets at 12-15 fps to find the effect, then
   EVERY frame of the chosen effect at 30 fps, numbered, plus the frames as PNGs for measuring.
2. Measure before building (numpy through Blender's python; PNGs read through ffmpeg rawvideo): per frame the white
   area, bounding box, share changed against the frame before (this finds held drawings), and the separate shapes
   with their middles and areas. Write the unique drawings down: that list IS the flipbook's frame list.
3. Build headless: `blender.exe -b --factory-startup --python script.py`. EEVEE, Standard view, film transparent,
   ortho camera, emission white, 256 px cells, 64 TAA samples, filter size 1.0. One object per drawing with
   hide_render keyed on its own frame, so the saved .blend scrubs as the animation.
4. Negative space = HOLDOUT shader on flat meshes in front of the white (holes, gaps, a ground plane that cuts the
   foot flat). Blobs that melt and pinch apart = METABALLS (one metaball family per drawing: the name before ".001").
5. Assemble the 4 x 4 sheet in numpy from the cells' alpha; RGB forced to white everywhere (no dark fringe).
6. Numbers against the reference (`compare_*.py`), the sheet checks (`check_flipbook.py`), then a side-by-side video
   at the timing the GAME will play it (16 drawings evenly over the lifetime), a slow one, and a stills sheet.
7. Owner's yes on the preview, then upload (Blender's python `-m http.server`, Studio MCP `upload_image`), patch the
   place by hash, gates, Play: freeze copies of the game's emitter at four ages in one screenshot.

## 3. Numbers worth keeping
- Reference swirl: 23 drawings in 28 video frames (0.93 s at 30 fps); grows for 16 frames, breaks up for 12. Width
  0.76 -> 4.56 units and height 0.50 -> 4.93 while growing (1 unit = 100 px); nine beans at the split, areas 2.1k to
  19.0k px, each drifting 0.6-0.9 units outward while shrinking to nothing.
- Mine against it, white area per drawing (units^2): 0.16 0.77 1.62 2.92 4.02 7.69 9.88 10.98 7.77 6.28 3.63 2.34
  1.14 0.53 0.26 0.03 against 0.19 0.65 1.27 2.96 4.19 6.43 8.32 11.01 7.55 6.30 3.40 2.12 0.97 0.43 0.19 0.02.
- A lone metaball's surface sits at 0.575 of its radius (stiffness 2, threshold 0.6). Render 30 s for 16 drawings.
- In the game: a particle is drawn 2 x Size across (cell 5.5 studs at Size 2.75; swirl 3.1-3.6 studs tall measured
  against 4-stud poles). The foot is 37.8 % of the cell below its middle: attachment y = -3 + 2 x 2.75 x 0.378.

## 4. Traps, each with what fixed it
- Volumetric smoke: a 14-minute first render and a flat white disc. Dropped. Test 4-8 frames before a full render.
- Holes that open together and centred read as a face, then as rings; holes that are shrunken copies of their cells
  read as a turtle shell. Stagger them, make them lopsided, size them with their cell.
- Beans alone never melt into one mass (bridge neighbours with extra balls); bridged all round is a doughnut; filled
  in the middle is a lump with a line drawn on it. The reference is an open band: reveal the middle last.
- Roblox cross-fades flipbook frames by default: a drawn puff shows two drawings as ghosts. `FlipbookBlendFrames =
  false`. For flat white also `LightInfluence = 0`, `LightEmission = 0`.
- A drawn puff cannot be sprayed: it must stand upright (`FacingCameraWorldUp`), not spin, not grow, not move.
- White on the lobby's pale floor nearly disappears. Not solved.
- Tooling: two heredocs with apostrophes in one Bash call fail; a file touched by a script must be Read before Write;
  `cd` in a Bash call moves the session's folder; the place's auto-starting rounds steal the test character.

## 5. The owner's taste, in their words
- "it should go through frames like an animation ... burst, like an actual puff" (against one shape that changes).
- "the smoke burst shouldnt drop". "too many individual bits". "i dont like how theres nothing in the middle".
- New references beat old picks without warning: "Soft like the reference" on the 21st, flat 2D references on the 22nd.
- "i think i prefer this animation", with a picture: they choose by looking, not by a name I give an effect.
- They correct one thing per message; a passing check has never meant they like it.

## 6. Self-checks: what they caught and what they missed
- Caught: sheet format, clear borders, grey-only, the pop, jumps between drawings, the puff sinking, edge width;
  the compare scripts caught walls too thick and a mass 20-40 % too heavy.
- Missed, every time: whether the SHAPE reads right (football, doughnut, pyramid, hearts). Only looking at the sheet
  beside the reference found those. Look after every render; list what differs before showing.
- A check written for one look fails honestly on another (the "centred within 12 px" check fails by 1.3 px on the
  swirl, whose left bean is the biggest in the reference too). Report it; do not loosen it quietly.
- The biggest miss was not a check: I asked the owner to choose a reference by a label and built the wrong effect in
  it. One sheet per effect, pictures in the question.

## 7. Open
- The other ~25 smoke effects still use the old texture; whether they get this style is not decided.
- The pale-floor problem. The growing half is less like the reference than the break-up half (an even band where the
  reference goes thick and thin). `FlipbookLayout = Custom` would allow all 23 drawings.
- Nothing from 2026-11-21 or 2026-11-22 is committed.
