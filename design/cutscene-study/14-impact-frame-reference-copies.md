# 14 - Impact frames: copying the three references (practice study)

2026-11-18. The drawn impact frames (procedural flipbook lines, an ink fist, tonal bursts: `design/vfx/draw_impact_*.ps1`)
were rejected: "does not look good ... the fist should be based off of a roblox fist ... it just looks really weird".
The user asked to copy the references exactly, as practice, and study them closely first. This is that study.

- References: ref1 = the "base impact" (black/white speed burst), ref2 = the ink burst ("good for the base impact"),
  ref3 = the teal fist impact ("pretty much what i want for the fist impact"). The user also said ref3's circle "is
  supposed to represent a target being punched, a shock being absorbed".
- Tools: `design/vfx/study/ImgLab.cs` (C# compiled by PowerShell; no Python/Node here), `load.ps1`, `measure*.ps1`,
  `recreate_ref1..3.ps1`. Outputs in `design/vfx/study/out/` (every version kept; `study_sheet.png` = the finals).
- Run: `powershell -File design\vfx\study\recreate_ref3.ps1 -Refs <folder with ref1..3.png> -Tag vN [params]`.

## The big finding: none of them is drawn

All three are **a scene put through image processing**. Each one is a picture (3D shapes, debris, busy detail), a
blur that streaks it toward or away from the hit, then a tone step: a hard cut, a curve, or a colour ramp. Hand-drawn
shapes (our rejected sheets) can't produce the torn edges, needles and combed masses, because those come from
blurring real shapes and cutting the result.

## Ref 1 - base impact (1521x861, pure black and white)

Measured:
- **Tones:** 70.7% white, 18.6% black, 10.7% between (edges only); no colour.
- **Convergence:** every streak converges on (761, 594), score 0.088 (0.5 = random). The hit sits just under the middle.
- **Clear core:** 1% dark at 25 px, 7% at 80 px, so the white burst has a radius of about 10% of the height.
- **Dark share by distance:** peaks at 34-38% at 300-400 px (the smeared slabs).
- **Edges:** 2 px (a hard cut).
- **Strokes:** median 5 px wide; 83 per circle at r = 520.
- **Streak lengths:** two kinds: 5 px fragments, and 120-500 px lines.

Recipe (copy v4, `recreate_ref1.ps1`):
1. **Source:** a white scene with three kinds of content.
   - Busy fine detail (radial noise) above and below a clear band.
   - Solid black slabs and a blocky figure, with a few bright cracks.
   - Small debris.
2. **Busy detail:** outward zoom blur on the hit (amount 0.3), then a hard cut (0.44-0.56). This gives speed lines
   that taper to points toward the hit.
3. **Solid shapes:** the same blur but short (0.12), then the cut. Slabs stay solid, their near edge breaks into
   fingers, and the cracks become white slivers.
4. **Debris:** a radial trail (each speck drags a full-strength line toward the hit, lightening along it), then the
   cut. This gives the needle-thin lines that cross the clear band into the hit.
5. Darken the three layers together.

What one blur strength can't do: a single strong blur wipes out the figure, so the reference has at least two
strengths (long for the background, short for objects) plus debris needles.

## Ref 2 - ink burst (516x387, warm greys)

Measured:
- **Tones:** 71% mid-grey, 16.8% black, 12.3% light.
- **Paper colour:** (241, 231, 232); darkest (2, 1, 1).
- **Convergence:** (250, 269), score 0.125, also just under the middle.
- **Edges:** soft (2-45 px); no hard cut.
- **Black:** peaks at 49-61% in a ring 60-130 px from the hit.

Recipe (copy v7, `recreate_ref2.ps1`):
1. **Source:** a blotchy picture with three noise octaves and light to the top-right. Solid ink blobs are crowded
   into a ring round the hit and sparse outside; there are a few bare-paper patches and fine grain. The grain must go
   in before the blur so it becomes brushed striations. Laid on a padded canvas so the frame edges blur properly.
2. **Blur:** a strong outward zoom blur (amount 1.2). Each ray becomes its own grey.
3. **Contrast after the blur,** strongest in that ring (×3.2, easing to ×0.9 outside). The per-ray greys snap into
   crisp black wedges and white rays.
4. **Centre:** a hot white centre (r 100).
5. **Finish:** unsharp mask (×1.4), then the ramp black → (142, 133, 134) → paper, then grain.

The order matters. Contrast before the blur gave round soft blobs (v2); contrast after it gives wedges and rays (v3+).
Copy v7 tones: 13% black, 12% white, 75% mid (histogram distance 0.26).

## Ref 3 - fist impact (640x480, letterboxed 16:9 inside 4:3)

Measured:
- **Frame:** black bars of 60 px at the top and bottom.
- **Content tones:** 51.6% white, 19.5% black, 28.9% teal mid-tones (hue 165, saturation 0.32).
- **Exact ramp (by brightness):** black (1, 3, 2) → (100, 153, 136) at 0.5 → (159, 219, 209) at 0.75 →
  (180, 231, 227) at 0.85 → (208, 241, 240) at 0.92 → white. So the teal is only the soft edge of a black stroke: a
  gradient map, not a colour layer.
- **Streak directions:** the fist's needles all radiate from about (260, 200), just behind the fist (where the arm
  comes from), running down-right at about 20°, with coherence 0.84-0.93.

Content, as the user explained it:
- **The arm and fist:** a black mass (the arm runs from behind, the fist at its far end). Only the far edge tears
  into long, thin needles.
- **The target taking the shock:** rings around the fist, with crease lines running into it, like a dent in the body.
  Soft ink lines with teal halos; only a few big arcs show.
- **Two bold swoosh crescents:** each a pair of thick parallel strokes sweeping in from the left to the fist.
- **A second torn mass** low on the right.

Recipe (copy v10, `recreate_ref3.ps1`):
1. **Dent:** a dented surface `z = -depth·exp(-(r/width)²)`, seen at about 40°. Rings and creases are drawn as ink,
   with the projected bottom placed on the fist. Then a smear along the punch (20°, 46 px) and a soften (7).
2. **Swooshes:** tapered Bezier strokes, softened 3.
3. **Fist:** the arm mass with cracks on the far rim only, then a short averaging smear away from the arm's root and
   a hard cut. Plus needles: specks along the far rim, trailed away from the root (darker speck = longer needle).
4. Darken the three together, apply the measured teal ramp, then add the letterbox.

Known flaws in v10:
- The needles are shorter than the reference's, with dotted tips.
- The ring lines lose their black cores under the smear; v9 kept the cores, but its rings were too regular.

### Ref 3, second round: a body taking the fist (`recreate_ref3c.ps1`, copies c4 and c5)

The user: v10 "still doesnt reflect a body taking an impact from a fist", and "the target needs to go inwards".

Slicing the reference by brightness (`slice_ref3.ps1`, `out/ref3_slices.png`) showed what the circle is: **the
target's body drawn as a big ball with globe lines, seen from the side.**
- The near-straight arc at the far left is its equator.
- The tall middle arc is a latitude ring.
- The two "swooshes" are meridian pairs running across the body's near face into the fist.
- The arm is the long black band with a straight top edge running to the right edge of the frame. It drives in from
  the right, its spikes trailing behind it.

How the copy works now:
- **The body goes inwards as a fold, not a dimple.** A round dimple seen side-on is hidden by its own near rim; the
  outline only flattens (tried: `ref3c_body_c2.png`). Pushing the fist side of the ball back along the punch, most at
  the fist's height and through its whole depth, makes the outline fold in around the fist.
  The formula: `x -= depth·R·exp(-(y/(w·R))²)·(x/R)²`.
  - **The outline:** the filled body shape, drawn as a bold edge line.
  - **The lines:** the meridians dive into the fold.
  - **The shadow:** the folded front is shaded darkest at the fist, which is the reference's big dark mass.
- **The arm:** an R6 block along the punch, its fist at the bottom of the fold. It is smeared away from the fist's
  top corner, the convergence point measured earlier. Cracks only start ~300 px out, so the fist stays solid, and
  needles come only off the edges right of the fist.
- **c4** is the clearest body-caving-in reading. **c5** adds a short smear of the body's lines away from the fist,
  closer to the reference's motion but blurrier.

Not matched yet: the reference's meridians are fewer, crisper and sweep harder. Its lower-right mass is cleaner than
our needle cluster.

### Ref 3, third round: wrapping round the fist from 3/4, sinking to a vanishing point (`recreate_ref3d.ps1`, copies d8 and d11)

The user: "its supposed to wrap around the fist from a 3/4 angle, with a vanishing point that it sinks towards".
The side view (c4/c5) was the wrong camera. The scene is now a real perspective render:
- **Camera:** just behind the attacker's shoulder, looking nearly along the punch. So the punch's vanishing point
  lands right by the fist, at (464, 308) against the reference's measured (520, 280).
- **The body:** a ball **turned ~50° to the camera** (that is the 3/4). Near the punch line it is pulled ~40 units
  deep along the punch (a narrow funnel). So it wraps round the fist and its rings and paired meridians all sink
  toward the vanishing point; the rings read as the tall arcs on the left.
- **Painting order:** surface patches are painted far to near, so near patches hide far lines. Every patch redraws
  the lines on its edges, so a neighbour's fill can't notch them. Shading only starts inside the hollow and
  darkens toward the vanishing point, which merges with the fist into the reference's big dark mass.
- **The arm:** an R6 block from just in front of the camera into the funnel. Its edges converge on the same point,
  and it is smeared away from that point (spikes peel off its lower edge down-right).
- **Tried and dropped:**
  - A swirl as the surface sinks: it kinks the lines at the funnel's steep mouth (d9/d10).
  - Heavy softening: it washes the lines out (d9).
  - The camera far off the punch line: the vanishing point lands far from the fist (d1-d4).

Not matched yet: the reference's lines curve more as they sweep in, and have wider teal halos. Its lower-right mass is
missing here.

### Ref 3, fourth round: the target's lines measured, then fitted (`trace_ref3.ps1` … `fitglobe_ref3.ps1`, copy f7)

The user: "it still isnt right … heavily analyze the geometry of the reference, and analyze how the lines work. the fist
isnt the problem, but the target getting hit is". So no more guessing; the lines were measured.

1. **Tracing.**
   - An automatic tracer (thinning plus curve fits, `TraceCurves`) only found fragments. The target's lines are soft
     teal strokes that break apart at any brightness cut.
   - So the lines were traced by eye on a 40 px measuring grid (`grid_ref3.ps1`, zoomed quarters and three close-ups),
     giving 13 lines as coordinates (`ref3_lines.ps1`).
2. **Two families** (`fit_ref3.ps1`, `out/ref3_lines_map.png`):
   - **8 spokes:** the two doubled "swooshes" A and B, a top spoke, an upper-right band and two lower-left spokes. Their
     end directions meet at (601, 391), the middle of the black mass; most pass within 25-60 px of it.
   - **5 arcs.** L1 and M are huge and nearly flat on the left (L1 is r ≈ 990 centred off-frame at (1020, 617)).
     Hook, R1 and R2 on the right bend the other way.
3. **A globe fitted by direction** (`Lab.GlobeFit`).
   - **The model:** a ball with globe lines, its pole at the fist, a shallow dent there, and a perspective camera.
   - **The fit:** every spoke must follow the meridian direction and every arc the ring direction wherever it lies, and
     the fit searches the camera position, aim, roll, lens and ball size.
   - **Result:** the 10 left-side lines fit to a **mean of 9.6°** (rings 6-7°, most spokes 6-11°). The camera:
     - It is **only ~2.5 units from the impact**, front-left and a little above, looking across the body at ~70° from
       square-on.
     - It has a fairly wide lens: focal 685 px at 1280 wide, ≈ 86° horizontal, with a 5° roll.
     - The ball is huge (radius ~18 units) and the dent shallow (depth 0.9, width 0.7).
   - **Where each line lies:**
     - Meridians at azimuths 102°, 134°, 150°, 166°, 190° and 204° (about 16° apart; the swooshes are pairs ~1.5°
       apart).
     - Rings at 4.3° (M) and 6.5° (L1) from the pole: only 1.4 and 2.1 units out, but huge on screen because the
       camera passes right over them.
     - Their far sides come back on the right (R1 follows the outer ring's far side).
   - **Not explained by the globe:** Hook and R2, on the right round the arm.
4. **Why every earlier copy missed:**
   - The camera was too far away, so rings became small nested ellipses.
   - The impact sat at the ball's edge, so nothing showed to the right of the fist.
   - The closeness of the camera is what makes the near ring arcs huge and flat.
5. **The arm** has its own vanishing point, the (520, 280) the needles converge on, up-left of the fist. It drives in
   at a slant, not along the body's axis. In the copy its outline is taken from the reference, since the fist isn't
   the problem.
6. **Styling, read off the reference:**
   - The meridians are heavy black, each with a thin twin.
   - The rings are softer and greyer, the outer one faintest.
   - Everything gets a ~6 px soften, then the teal ramp.

### Ref 3, fifth round: deep, chunky, on target (copies f9-f11)

The user, on f7/f8: "its not deep enough, and the fist is too skinny and does not target the [centre]".
- **Deep:** the body now sinks along the ray to the point its lines converge on (`-SinkVPX 601 -SinkVPY 395`, depth
  4 instead of the fitted 0.9). Its lines dive straight into the fist, and the rings near it squeeze tight.
- **Dense:** f8 added the full line set the fit implies, with paired meridians every 16° all round and rings at 1.0°,
  1.6°, 2.3°, 3.2°, 4.3° and 6.5°. That gives the fan of panels at the top right and the dark mass.
- **The fist:**
  - A chunky R6 block, its face (~200 px) sitting on the centre where everything sinks.
  - Its centre line runs through that point, so it targets it.
  - f11 has the reference's arm shape: the top edge sloping down to the right, the arm widening downward toward the
    camera. f9 has the arm fanning upward.

### Ref 3, sixth round: drawn from the measured lines (`ridges_ref3.ps1`, `ref3_strokes.ps1`, `copy_ref3.ps1`, copy m4)

The user, on the fitted-globe copies: "look at the lines you drew, the copy doesnt match the lines at all". The fit
(9.6° mean direction error) was right about the structure, but no good for placing lines: a few degrees off spread
over the frame puts every line in the wrong place.

- **A ridge finder** (`Lab.RidgeBits`) finds the centre of every dark stroke by its curvature after a blur, so soft
  teal strokes are found as well as black ones. It splits them into curves and measures, every 6 px, the stroke's
  width and core darkness across it (`Stroke`).
  - Two passes: blur 3 finds 68 fine strokes; blur 9 finds 39 soft wide strokes (`out/ref3_ridges_r1/r2.png`).
- **The copy is drawn only from measurements:**
  - 21 assembled strokes (the swooshes, rings, spokes, hook, the fan over the arm) with measured paths, widths and
    darkness. The swooshes are black, 7-15 px; the rings grey (0.35-0.45), 20-36 px.
  - Every other measured centreline outside the mass, drawn at the reference's own darkness there.
  - The black mass filled from its measured outline (`Lab.DarkOutlines`, darker than 0.12).
  - Each stroke gets a lightly softened core (4 px) plus a wide halo: the same ink blurred hard (14 px) and lifted to
    light grey. Then the teal ramp.
- **The user accepted m4** ("Yes, it matches"; 2026-11-18). This is the reference 3 practice copy to build from.
- **Result:** the strokes sit on the traced lines (`out/ref3m_overlay_m4.png`). The mean tone difference against the
  reference dropped from ~0.2 for every earlier copy to 0.084.
- **Still different:**
  - The reference has soft shaded panels between some lines (the fan at the top middle, soft streaks below the mass).
  - Its lower-right mass is one streaked shape.
  - A few lines are drawn twice (assembled and found).

## Our two impact frames: first previews (2026-11-18, `design/vfx/impact/`)

User direction:
- **First impact:** "similar to" reference 2, the ink burst.
- **Second impact:** like m4, "but the impacted object will be a blocky torso and the fist will also be a block just
  like a roblox avatar. however, dont use 3D objects for this, i want the blocks to look like sketches just like all
  my references".

An earlier pass that rendered R6 fighters as 3D boxes under the burst was dropped for this.

- **Reference 2 re-copied** (`study/recreate_ref2b.ps1`, v12; tones now 15.6% black against 16.8%, mean 124 against
  131). The fixes over v7:
  - The ink blobs come from noise laid out by angle and distance (`Lab.PolarGrain`), so they are already stretched
    outward, then blurred less (0.55). This gives torn, broken masses instead of smooth rays.
  - The ink is kept close to the hot centre.
  - Broad paper rays are drawn as gentle spirals (so a slightly bending blur, `Lab.ZoomOutTwist`, keeps them) and
    broken up by noise.
  - A bigger, spiky hot centre and a lighter outer field.
- **Contact** (`build_contact.ps1`): 6 frames at 30 fps.
  - The big shapes stay put while the fine texture and ray breaks re-roll each frame (boil).
  - The ink spreads outward (reach 220 to 480 px) and the streaks lengthen (blur 0.3 to 0.65).
  - The white flash tightens (radius 230 to 130), and frames 1 and 3 flash inverted.
- **Plunge** (`build_plunge.ps1`): 12 frames at 24 fps, all 2D sketch strokes.
  - **The torso:** a box in rough 3/4 with its front, top and side faces showing. It has surface lines, dent rings,
    and creases from the fist to the box's corners (reference 3's swooshes).
  - **The cave-in:** a 2D pull toward the fist (strength 0.3 to 0.88, radius 300 to 410 px) plus a slight swirl
    (up to 0.55 rad). The torso's edges and lines bend and sink in round the fist.
  - **The fist:** an R6 arm block with a light top face, speed hatching, a black side, doubled outlines and spikes
    off its far lower edges. It drives in 90 px over the sequence.
  - **The strokes:** each one wobbles, tapers, overshoots and has a thin twin; the wobble re-rolls each frame.
  - **Finish:** reference 3's ink cores, halos, teal ramp and bars.
- **Previews:** `out/impact_preview.mp4` (real speed) and `out/impact_preview_slow.mp4` (quarter speed), plus
  `out/contact_sheet.png` and `out/plunge_sheet.png`. Nothing has been uploaded to Roblox or wired into
  `ImpactFrame.luau`.

## Second previews (2026-11-18): pencil burst, drawn fist impact

User feedback on the first previews: the first impact is "ok although id like it to be rougher and sketchier like it
was made with a pencil". The second was "pretty bad im not sure what im looking at". The user gave a new reference,
https://www.youtube.com/watch?v=HiqEBf-gn-I ("impact frame test", a FlipaClip animation, 18 s at 24 fps), and said the
torso doesn't need to cave in.

**What the video's punch impact is** (11.9-12.3 s, read at its native 24 fps): rough marker line art, redrawn every
frame, in four steps.
1. **Inverted (1 frame):** black ground with white swirl lines round the hit. The fighters are white with black lines,
   and a white four-point star sits on the contact.
2. **Black silhouettes (2 frames):** white edge lines, a black spiky star, scribble hatching all round.
3. **Heavy outlines (2 frames):** shaded sides hatched, dense scribble streaks along the punch.
4. **Smear (2 frames):** everything turns into black scribble streaks pulled along the punch, with grey scribbles over
   white.

Then the victim flies off in clean line art with a few speed dashes. The video also has a ground-crack impact
(black-ground frames with a white burst star, then cracked blocks) and a fist-close-up wind-up.

**Built:**
- **Sketch kit** (`study/Sketch.cs`, compiled with the lab):
  - variable-width marker strokes with wobble, taper and overshoot;
  - rough polygon outlines, drawn twice;
  - hatching clipped to a shape;
  - zigzag scribble streaks;
  - swirl lines;
  - four-point stars;
  - scribble smears of a shape;
  - a pencil render of a tone image: graphite strokes running out from a centre, whose density and darkness follow
    the tone, scribbled where it is near black.
- **Contact** (`build_contact.ps1`): the same v12 burst animation, but each frame is redrawn as ~9000 pencil strokes on
  warm paper with grain, under a graphite wash where the ink is darkest. The pencil boils because the strokes re-roll
  every frame. Frames 1 and 3 are inverted (dark paper, light graphite).
- **Fist impact** (`build_plunge.ps1`, replacing the caved-in torso): 7 frames at 24 fps following the video's four
  steps.
  - **The target:** a Roblox avatar drawn in 2D: torso with front, top and side faces, head, both arms and the tops of
    the legs.
  - **The attacker:** an arm block driving in from the lower left to the middle of the chest.
  - The star sits on the contact. There is no 3D and no cave-in.
- **Previews:** `out/impact_preview.mp4` and `out/impact_preview_slow.mp4`, plus `out/contact_sheet.png` and
  `out/plunge_sheet.png`.

## Third previews (2026-11-18): an exploding burst, a close-up torso and fist

User feedback:
- **Fist impact:** "the torso and the fist should be the only things visible, and the fist shouldnt be that long,
  also the entire arm sholdnt be in the shot. also the frame itself is too geometric and not sketch like", then "the
  torso should be centered, and should be more zoomed in".
- **Burst:** "the first one just flashes and doesnt look very animated".

**Changes to the burst** (`build_contact.ps1`): 10 frames at 24 fps (0.42 s), animated as an explosion.
- Frame 0 is the hit: a tight burst, inverted. After that:
  - the ink masses fly outward (`Lab.PolarGrainShift` pushes the stretched noise out in log distance, about 5.5×
    over the run);
  - the paper rays shoot from 160 px to the edges, and the streaks stretch (blur 0.12 to 0.82);
  - the clear centre opens up (inner radius 10 to 310 px), and the ink thins out at the end;
  - the burst's reach grows from 160 px, and paper fills the frame beyond it.
- Only the first frame flashes, so it no longer strobes.

**Changes to the fist impact** (`build_plunge.ps1`):
- **What's in shot:** only the torso (a block with front and side faces, two-point perspective) and the end of the
  arm block coming in from the left edge.
- **Framing:** centred and zoomed 1.2× round the torso's middle; the fist lands on the middle of the chest and sinks
  ~45 px while the torso is knocked back.
- **Line work** (`Sk.SketchEdge` / `SketchPoly`): every edge is hand-drawn, bowed, with corners overshooting or
  stopping short, up to three passes, pressure changes and breaks.
- **Fills, hatching and boil:** fills have wobbly edges (`Sk.WobblePoly`); hatching is zigzag and trimmed loosely
  (`Sk.HandHatch`); corners boil ±4 px between frames.

## Lessons for our two impact frames

1. **Make them from a scene, not from drawn shapes.** Render the moment (our R6 fighters from the cutscene camera),
   then process it with these recipes offline, into flipbook sheets. Roblox can't post-process the screen live, and
   the cutscene camera is fixed relative to the fighters, so pre-rendered frames line up.
2. **The fist is the R6 arm:** a 1×2×1 block with its square end face. It's the black mass, with the arm running back
   toward the point the needles radiate from.
3. **Contact (quick, flashy):** the ref1/ref2 recipe centred on the hit point.
   - Hard black and white (ref1) or the ink-ring version (ref2).
   - About 4-6 frames.
   - Animate by growing the blur amount and the line length frame to frame, flipping the clear core from small to
     large, and changing the noise seed each frame (the lines "boil").
4. **Fist plunge (longer, focused on the fist):** the ref3 recipe.
   - Seen from 3/4 behind the attacker's shoulder, the target's body (a gridded ball, or the R6 torso) **wraps round
     the fist and sinks toward the punch's vanishing point.** It deepens frame by frame as the fist goes in, and its
     lines are pulled into the hollow. That is the shock being absorbed, not rings spreading outward.
   - The needles lengthen as the fist sinks.
   - The swooshes sweep in over the first frames.
   - About 8-12 frames, with the teal ramp and letterbox.
5. **Process order is the look:** blur, then contrast or cut, then ramp. Contrast before the blur gives blobs.
6. **Strengths per layer:** long blur for the background detail, short for solid bodies, trails for debris. One
   global blur either wipes out the figures or under-streaks the lines.

## Next step (needs the user's go-ahead)

Build our own two sequences with these recipes from an R6 source, at the cutscene's real camera angle. The source can
be a Studio capture of the contact pose, or a small software render of R6 boxes if the Studio window can't be grabbed
(it was minimized during this study). Show them as animated previews before anything is uploaded or wired into
`ImpactFrame.luau`.
