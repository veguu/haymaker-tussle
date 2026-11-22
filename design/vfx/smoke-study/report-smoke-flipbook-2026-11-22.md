# Report back: the smoke flipbook test piece (2026-11-21 to 2026-11-22)

For the tutorial session, under the brief's seven headings. Result in one line: four builds (toon lobes, soft poof,
a dome that dies by holes, the swirl); the swirl is in the game as build `puff-1`, approved in Studio ("Looks right").
Every number and the owner's exact words: `design/vfx/smoke-study/session-log-2026-11-21.md` (from line 78) and
`session-log-2026-11-22.md`.

## 1. The reference numbers measured, and the old vs new check numbers

**References**
- 2026-11-21, toon ring (vw2VJnY1ZZY, 13.00-13.55 s, 60 fps): 3 merged lobes 130-200 px, rim band 15-35 px, hollowing
  35 % -> 60 % -> rim only by 13.20, arch gone 13.40, small 3-4 lobe clusters 35-60 px fade by 13.55.
- 2026-11-21, explosion (oM4CaPonk0E) and cartoon poof (ucajyMCX33o): nothing -> about 60 % size on the next frame ->
  full by 3-4 frames; poof = dense white ball with 12-20 rim bumps, breaks into 6-8 soft clumps, gone in about 1.2 s.
- 2026-11-22, green-screen clip mmfhHXmdIDQ (608 x 1080, 30 fps), two different puffs in it:
  - The dome (video frames 16-35, 0.67 s): 16 unique drawings (held: 19, 24, 29, 34). Width 68 100 178 370 394 414 430
    449 469 490 500 502 506 px; height 20 75 139 246 256 268 276 286 290 302 309 310; holes as a share of the filled
    outline 0 2 5 16 23 31 40 50 57 64 72 83 89 90 %; bursts 24 % from the left; the foot lifts 3 7 11 20 26 % at the end.
  - The swirl, the one the owner wants (video frames 4-31, 0.93 s): 23 unique drawings (held: 5, 10, 15, 20, 25, 30).
    Growing: width 76 146 178 249 284 338 366 456 px, height 50 130 160 203 243 397 464 493, area 1.9k -> 110k px; one
    mass until frame 17, three at 19. Frame 20: nine beans (19.0k 11.5k 11.1k 10.8k 7.5k 7.4k 3.3k 2.6k 2.1k px), each
    then drifting 0.6-0.9 units outward (1 unit = 100 px) and shrinking to nothing by frame 30.

**Check numbers, old sheet in the game against the swirl** (`check_flipbook.py`, SMOKE_LOOK=toon, drawings 1-16)
| | Old `hit_smoke.png` | New `smoke_swirl.png` |
|---|---|---|
| coverage % | 14.3 14.9 15.5 16.1 16.7 16.9 16.8 16.5 16.0 15.6 15.3 14.4 12.4 8.9 0 0 | 0.3 1.7 3.5 6.3 8.7 16.6 21.4 23.7 16.8 13.6 7.9 5.1 2.5 1.1 0.6 0.1 |
| widest extent % | 47.7 ... 51.6 ... 42.6, 0, 0 | 12.1 23.8 29.3 38.3 44.1 54.7 61.7 67.2 72.3 75.4 74.2 75.0 74.2 73.8 73.0 73.8 |
| centre off x px | 11.9 down to 3.7 | -11.2 to -1.1, worst -13.3 (drawing 10) |
| centre off y px | 4.2 to -2.5 | 88.5 (on the ground) rising to -33.0 |
| edge width px | 46-67 | 1.2-1.9 |
| fully opaque tones | drawings 1-3 only | 1 tone, 100 % on every drawing |
| overlap with the drawing before % | 98-100 | 40 (the first step), then 61-92, 41 at the last dots |
| drawings actually drawn | 14 (15 and 16 empty) | 16 |
| result | 8 of 11 (fails extent, flat tones, clean edge) | 10 of 11 (fails "centre within 12 px sideways") |

**Swirl against its reference** (`compare_swirl.py`, white area per drawing, units^2): mine 0.16 0.77 1.62 2.92 4.02
7.69 9.88 10.98 7.77 6.28 3.63 2.34 1.14 0.53 0.26 0.03; reference 0.19 0.65 1.27 2.96 4.19 6.43 8.32 11.01 7.55 6.30
3.40 2.12 0.97 0.43 0.19 0.02. Separate shapes: both 1 x 7, then 3, then 9 (mine 8 on the first split drawing), 3 last.

**In the game:** root to floor 3.000 studs (R6); the image is 2 x Size across (5.5 studs at Size 2.75); the swirl
measured 3.1-3.6 studs tall against 4-stud poles; its foot is 37.8 % of the image below the image's middle.

## 2. Which checks or thresholds felt wrong, and why
- "Coverage about 70 %": wrong as written. A puff spanning 70 % of the cell covers about 32 % of its area. The check
  that means something is the EXTENT (62-78 %).
- "Tones: 97 % in three bins": at 256 px the anti-aliased lines between two flat tones are 5-10 % of a small shape.
  Lowered to 85 %.
- "Centre within 12 px": written for a round puff that stays put. It pushed me to SINK the puff to pass (the owner
  then said "the smoke burst shouldnt drop"). Rewritten as "never drops, may rise". It still fails honestly on the
  swirl by 1.3 px sideways, because the left bean is the biggest in the reference too. Left failing, reported.
- "Rises 50 px at most" passes on the swirl only because it counts drawings over 10 % coverage; the swirl really
  climbs 121 px from the ground. A puff that grows from the floor needs its own rule (the foot stays on one line).
- "Overlap with the drawing before, 60 %": as overlap-over-union it punished clumps for shrinking; changed to "share
  of the smaller shape inside the other". It says nothing once the puff is thin lines or dots.
- "No coverage jump over 12 points": the pop is meant to jump, so the first step is left out.
- "Biggest frame 62-78 %" is met by scattered dots as easily as by a solid puff.
- The file defaults to the SOFT look; a flat sheet must be run with `SMOKE_LOOK=toon`. Easy to forget.
- None of them sees SHAPE. Football, doughnut, pyramid, hearts, a lump with a line on it, a stray pin hole: all passed.

## 3. Every error or trap hit: message, cause, fix

**Blender toon shading (2026-11-21)**
- Stair-stepped tone edges: voxel-remeshing the lobes into one skin gives faceted normals (`shade_smooth` did not
  fix it). Fix: whole UV spheres (64 x 32), joined, polygons `use_smooth`.
- Terraced tones: the sun's cast shadows. Fix: `sun.use_shadow = False`.
- Holes opening together and centred read as a FACE, then as linked RINGS. Fix: one after another, each sliding off
  centre so an arch is left, a noise-bent edge.
- Volumetric smoke: first render 14 minutes and hit the 10-minute tool limit (it carried on in the background); the
  result was a flat white disc. Dropped. Render 4-8 frames first.

**Flat 2D shapes (2026-11-22)**
- Holes as shrunken copies of their cells = a turtle shell. Fix: inset in step with cell size, lopsided per side.
- Rounded holes at the line stage leave pointed triangles where walls go. Fix: no rounding once walls are lines.
- Removing whole walls = a few long ruled strokes; even gaps = a "cut here" dashed line. Fix: one long and one short
  gap per line, growing.
- Metaballs: beans alone never melt into one mass (bridge neighbours with extra balls); bridged all round = a
  doughnut; a filled middle = a lump with a line drawn on it; a bean missing from the middle = a square pin hole;
  a strong bend on small beans = hearts. A lone ball's surface is at 0.575 of its radius (stiffness 2, threshold 0.6).
  Metaball objects sharing a base name melt into each other: one family name per drawing.

**Alpha and colour management**
- View transform must be `Standard` (the default AgX shifts flat tones); `film_transparent = True`.
- Save the sheet with `image.alpha_mode = "STRAIGHT"` and force RGB to white (or the puff's grey) EVERYWHERE,
  including clear pixels, or filtering in the game gives a dark fringe.
- Blender's python has numpy but no PIL: PNGs are read through `ffmpeg -f rawvideo -pix_fmt rgba`.
- A dying soft ball that shrinks to a dot reads as bubbles; fading it see-through needed a per-object attribute
  into Alpha with `surface_render_method = "DITHERED"` and 64 TAA samples.
- Holdout (`ShaderNodeHoldout`) on a mesh in front works in EEVEE with a transparent film: exact, crisp negative space.

**Rendering a grid**
- Render each drawing as its own 256 px cell and assemble in numpy: pixel rows run bottom-up, so row `3 - r`.
- Thrown bits widened my framing: measure the width from the main shapes only.
- After `save_as_mainfile` the printed path turns relative (`//out\smoke_swirl.png`): harmless.
- ffmpeg `drawtext` prints "Fontconfig error: Cannot load default config file": harmless.

**Upload**
- `upload_image` with a file path: "Only http/https URLs are supported". Fix: serve the folder. Simplest that worked:
  Blender's python `-m http.server 8765 --bind 127.0.0.1` in the Bash tool's background mode, then stop it by port.
  The notice "failed with exit code 127" afterwards is only the kill.

**Studio testing**
- Two drawings showing at once, half see-through: a flipbook cross-fades by default. Fix: `FlipbookBlendFrames = false`.
- Greenish, dim white: lit by the scene. Fix: `LightInfluence = 0`, `LightEmission = 0`.
- A drawn puff sprayed like dust is wrong: it needs `Orientation = FacingCameraWorldUp`, Speed 0, no rotation, a
  constant Size, `Emit(1)`, and the emitter raised by foot share x 2 x Size.
- White puff on the lobby's limestone (246,238,224): nearly invisible. Not solved.
- The place starts rounds by itself: my test character was teleported into the arena and knocked out mid-capture.
  Fix: clone the game's emitter onto a row of attachments, emit them apart, freeze all, ONE screenshot.
- `script_grep` for "Server started - BUILD" found nothing: "-" is a pattern character. Search plain words.
- The place's GameConfig differs from disk (not ours): patched only FxKit, DashFx, Server by `multi_edit`, by hash.
- stylua failed on the longer build-stamp line: it had to be wrapped, in the place too, or the hashes differ.

**Shell and tools**
- "unexpected EOF while looking for matching `''": a heredoc holding triple-quoted Python inside a Bash call. Fix:
  write the patch file with the Write tool, then run it.
- Write refused a file a script had touched ("modified since read"): Read a few lines first.
- `cd` inside a Bash call moved the session's folder; a careless `git stash` then hit a real file (popped at once,
  nothing lost).

## 4. What took the most attempts
1. The soft poof (2026-11-21): the volume attempt, then eight owner corrections on the middle of the puff alone. It
   was never judged: the owner changed direction with new references.
2. Finding the right LOOK: four builds. Toon lobes (two previews, rejected), soft poof, the dome (built from the
   wrong effect in the right clip), the swirl.
3. The swirl's growing half: six render rounds (separate beans, doughnut, lump with a line, pin hole, hearts, then
   the open band). Its break-up half was right on the first render, because it came straight from measurements.
4. The dome: five rounds (turtle shell, pyramid, triangles, ruled strokes, dashed line).

## 5. The owner's verdicts, in their words, and whether the preview showed what Studio did
- Toon lobes, preview 1: "the smoke burst shouldnt drop".
- Toon lobes, preview 2: "ok this looks not good, i think the problem might be with the smoke itself, rather than
  changing the existing shape, it should go htrough frames like an animation. i want the puff to burst, like an actual
  puff of smoke".
- Soft poof, round by round: "too many individual bits"; "i dont like how theres nothing in the middle"; "the middle
  doesnt seem to fade/move parallel with the others"; "maybe you can have the middle enlarge, and fade out"; "ok the
  middle enlarges too big"; "should be bigger but not huge enough to overshadow the others"; "it should swell only big
  enough to where there is still a gap between it and the smoke around it"; "it should cover the gap at the start and
  reveal it slwoly as the others move away".
- 2026-11-22: "let me give you some good references for the smoke i want" (eight links), then the pick "Green-screen
  puff" and "Ground dust only" (dialog buttons).
- The dome preview: "i think i prefer this animation", with a picture of the swirl from the same clip.
- The swirl preview: "Yes, try in Studio" (button), and "One puff" for the dash dust (dialog).
- In Studio, at full speed: "Looks right" (button). No words beyond that.

**Did the preview show what Studio did?** The shapes and the timing, yes: the preview plays my 16 drawings evenly
over 0.93 s, as a OneShot flipbook does. Three things it did not show: (1) it sat on dark slate, so it hid that the
puff vanishes on the pale lobby floor; (2) it swapped drawings cleanly, while Studio cross-faded them until
`FlipbookBlendFrames` was off; (3) it was unlit white, while Studio tinted it until `LightInfluence` was 0. Size and
the foot on the floor could only be measured in Studio. I never saw the puff from a real T dash on screen (the game
camera faced away); the owner judged that.

## 6. The files made, and the new asset id
- Asset: `rbxassetid://72521547682766` = `FxKit.Tex.SwirlPuff`. The old `Tex.Smoke` (97818702295807) is unchanged.
- Game: `src/client/Fx/FxKit.luau` (the id), `src/client/Fx/DashFx.luau` (the emitter), `src/server/init.server.luau`
  (stamp `cam-1+jab-3+keys-1+kits-8t+puff-1+village-4+ui-20e`). Commits 32f76ac and 7a39130, pushed.
- Build: `design/vfx/smoke/smoke_swirl.py` (the one in the game), `smoke_puff2d.py` (the dome), `smoke_poof.py`,
  `smoke_toon.py`; `render_swirl.sh`, `render_puff2d.sh`.
- Checks and previews: `check_flipbook.py`, `compare_swirl.py`, `compare_puff2d.py`, `preview_swirl.sh`,
  `preview_puff2d.sh`, `preview.py`.
- Output kept: `design/vfx/smoke/out/smoke_swirl.png` and `smoke_swirl_on_dark.png`. Local only (ignored): the
  `.blend` files, cells, preview videos, stills, reference frames.
- Study: `design/vfx/smoke-study/01-reference-and-old.md`, `refs-2026-11-22/measure_puffA.py` and `measure_puffB.py`,
  both session logs, this report.
- Vault: `56 Field Notes/Studying VFX References` section 13; `56 Field Notes/Drawing and Uploading VFX Textures`
  (the cross-fade switch, the pale floor, the simpler server, several moments in one shot).

## 7. Tutorial notes: wrong, missing or unclear for flipbooks
Read: `Blender Mastery 0` (searched for the flipbook-related terms, not read end to end). Mastery 1 and 2 are the
animation and camera routes; there is no flipbook note yet (Mastery 0 lists it as "Next").
- **Incomplete:** the size table says a flipbook is "2x2, 4x4 or 8x8 cells". Roblox also has `FlipbookLayout = Custom`
  with `FlipbookSizeX` / `FlipbookSizeY` (the texture's size must be an exact multiple of the grid). The swirl's
  reference has 23 drawings; I used 16.
- **Unclear:** "Never run `read_factory_settings`" is right for a live session, but every headless flipbook script
  starts with `bpy.ops.wm.read_factory_settings(use_empty=True)` under `-b --factory-startup`. Say that the rule is
  for the user's open Blender, not for `-b` scripts.
- **Missing, Blender side:** holdout meshes for negative space; metaballs for shapes that melt and split (and the
  family-name rule); one object per drawing with `hide_render` keys so the .blend scrubs; render cells then assemble
  in numpy (rows bottom-up); straight alpha with RGB filled everywhere; no PIL in Blender's python.
- **Missing, Roblox side:** `FlipbookBlendFrames`; OneShot spreads the frames evenly over Lifetime, so a preview must
  be timed that way; a particle is 2 x Size across; unlit settings for flat white; `FacingCameraWorldUp` and the foot
  offset for a puff that stands on the ground; test on the palest floor.
- **Missing, method:** measure the reference's unique drawings first (the changed-share number finds held frames);
  that list is the frame list. When a clip holds several effects, show one sheet per effect and ask with pictures.
- **Missing, self-check:** no numeric check sees shape. The standard should require the sheet beside the reference
  after every render, with the differences listed before the owner sees it.
