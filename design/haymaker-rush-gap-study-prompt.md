# Haymaker Rush vs the references: the gap study (prompt)

Written 2026-11-17 from the owner's request: "can we study in detail about anime style vfx, camera angles, screen
effects, and especially the animations? i want you to write notes comparing what we have to our references in
extreme detail, and compare whats missing and what we are doing that we should not be." Also, on the build they
just watched: "i dont like the dash vfx for the animation, also the camera angles are still poor we need to review
what makes them good."

## 1. Goal

Find out, frame against frame, why Haymaker Rush still doesn't feel like the references. Produce:

- a written explanation of WHAT MAKES THE REFERENCES GOOD in four areas
- an exact list of where ours falls short

The four areas, in the owner's order of importance:

1. **ANIMATION** (most important): the bodies' motion.
2. **CAMERA**: placement, lens, motion, cut rhythm, composition.
3. **SCREEN EFFECTS**: whole-frame treatments.
4. **VFX**: anime-style effects on and around the bodies, including the dash.

Nothing gets built from this study until the owner has read the fix list and said which fixes to make.

## 2. Inputs

**References.** The same 10 as the first study. Contact sheets are at 12 fps, 6 x 4 frames per sheet (2 s), with
absolute times stamped:

- Azure Flames finisher (`sfZyOKF50so`): `design/references/azure-flames/sheet0..3` (8 x 3 grids; add 2N s)
- Orlando Furioso (`QlvfbPbCYCM`): `design/references/camera-study/QlvfbPbCYCM/`
- Human Battery finishers (`C2vCVdNRLms`): `design/references/camera-study/C2vCVdNRLms/`
- TSB Garou combo (`zP6MFM_SamU`): `design/references/camera-study/zP6MFM_SamU/`
- Acheron Ultimate (`3KIzXAukn5I`): `design/references/camera-study/3KIzXAukn5I/`
- Mumen Rider Combo (`3R5WsLDp2f4`): `design/references/camera-study/3R5WsLDp2f4/`
- Garou vs Stinger (`pc7b7_unix8`): `design/references/garou-stinger/`
- Garou vs Tanktop (`ZHpLPijIamA`): `design/references/camera-study/ZHpLPijIamA/`
- Serious Punch (`UwgyVQrlx_k`): `design/references/camera-study/UwgyVQrlx_k/`
- Jotaro vs DIO (`sUmnKwt9uyA`): `design/references/camera-study/sUmnKwt9uyA/`

Each study agent may make larger crops at 24 or 30 fps from the source mp4s, to read motion between the 12 fps
frames. The mp4s are in the session scratchpad `refs/`, at 720p. Animation especially needs this.

**OURS.** Haymaker Rush (build `kits-7e`), recorded from Studio in a play test at 30 fps. The attacker starts 12
studs from Practice Dummy 1. It is cut into sheets the same way and saved in `design/references/ours-kits-7e/`,
plus 30 fps sheets of the key beats.

**Our numbers.** The timeline is `src/shared/Core/Ultimates.luau`. The poses are in
`animations/build_strikes.luau`, `src/shared/Config/AnimClips*.luau` and `AnimController.luau`. The effects are in
`src/client/Fx/` (UltimateFx, DashFx, PunchHitFx, ImpactFrame, CutsceneScreen, AirFx, StepBurstFx).

**Earlier findings.**

- `63 VFX Creation/Cutscene Camera and Impact - Measured From 10 References.md` (camera, shake, freezes)
- `63 VFX Creation/Impact Frames - What They Are and How to Build Them in Roblox.md`
- The owner's VFX rules in memory (sections 7-8)

**Measured facts about ours** (2026-11-17, Studio, 34-38 fps):

- From the wind-up to the end of the flight, frames take 90-120 ms (about 10 fps).
- One 350 ms stall happened mid-flurry on a first run.
- The first hook's fist is 3 studs to the side at its freeze, and the uppercut's is 1.4 studs off.
- The haymaker lands (gap 0).
- The bodies hold still during freezes.

## 3. Method

### Beats

Compare beat by beat. The beats are:

1. lock-in
2. rush in
3. first hit
4. flurry
5. set and uppercut
6. leap and hang
7. wind-up and silence
8. haymaker and impact frames
9. result and flight

For each beat, pick the 2-3 reference moments that do the same job best. Give each one's id and time range. Then
compare them with ours at the same beat.

### Per area: what to measure

Label everything **MEASURED** (counted or measured from frames) or **READING** (interpretation). If a frame is
unclear, say so and don't guess.

**ANIMATION.** Read at 24-30 fps crops where it matters.

- **Poses.** Count the distinct poses per action. How far is each pose pushed: the line of action, the twist through
  hips and shoulders, the lean, the weight over the feet? How clear is the silhouette, and do the limbs overlap the
  body?
- **Timing and spacing.**
  - How many frames go to anticipation, the strike, the hold at contact, the follow-through and the recovery.
  - Ease in and out, or snap.
  - Which beats are HELD (identical frames) and for how long.
  - Repeated cycles against a new pose every time.
- **Arcs.** The path of fists and feet: a straight line or an arc, which way it curves, and whether the body leads
  the limb (overlap and follow-through, drag).
- **Smears, multiples and after-images.**
  - Frames where a limb is stretched, doubled or blurred.
  - How many, and the shape.
- **Exaggeration.** Squash and stretch, foreshortened fists coming at the lens, limbs drawn longer than the body
  allows.
- **The victim.**
  - How each hit reads on the body: the head snap, the fold at the waist, limbs trailing, the spin.
  - How long each reaction is, and whether it differs for each hit.
- **The rush.** How the attacker leaves (the launch pose and the first frames), how they travel (a run cycle, a
  single held pose with a streak, a teleport-smear), and how they arrive (a skid, a plant, straight into the
  strike).
- **The barrage.**
  - Fists per second.
  - The variety of punches.
  - Whether the body moves under the arms.
  - How the reference fakes "too many punches to count".
- **Ours, compared on every point.** Then list exactly which of our clips (HookRightRun, BarrageUp, Uppercut,
  HaymakerUp, Sprint, the flinches, AirTumble) fall short, and how.

**CAMERA.** Use the first study's note as a base; don't repeat it. Go further on:

- composition: where the fighters sit in the frame (thirds, centre, the edge), negative space, foreground layers
- screen direction, and whether it ever breaks on purpose
- lens: wide distortion against telephoto compression
- camera height relative to the eyes
- how each beat's first frame is composed (the "establishing read" in 1 frame)
- motivated moves: a move that follows an action, against a move for its own sake
- how the cut rhythm builds into the hit
- for ours: every shot, what it shows on screen in practice (from our recording, not from the code's intent), and
  what reads badly (blocked, flat, too far, too close, confusing, static where it should move, moving where it
  should hold)

**SCREEN EFFECTS.** Whole-frame treatments:

- flashes (colour, frames)
- inversion and polarity flips
- colour grade changes and their timing
- vignette and darkening
- speed lines drawn over the frame (radial, parallel)
- chromatic aberration and colour fringe
- cracks
- letterbox
- blur
- black frames
- the impact-frame sequences, frame by frame: which ones, how long, in what order
- for ours: the grade, the flash, the darkening, the impact frames and the dip to black, compared frame by frame

**VFX.** Anime-style effects on and around the bodies:

- **Hit sparks:** shape, colour count and value, how long they live, how they scale over time.
- **Shockwave rings, dust, debris, ground cracks.**
- **Trails.** Swing trails, smears drawn as effects, after-images.
- **Dash and rush effects** (the owner rejected ours): what each reference uses (streaks, wind lines, dust at the
  feet, after-images, a light trail, ground tear), with what timing and colours.
- **Layering:** core, glow, sparks, lines.
- **How effects are aimed.** Along the hit, radial, or set by design, never random (house rule).

Then, for ours:

- every effect we play at each beat, judged against the references and against the house rules
- which effects to REMOVE, which to REPLACE, and which are MISSING

### Per area: what to deliver

**Three lists**, each item with evidence (reference id and seconds, our seconds), a severity (HIGH, MED or LOW) and
a concrete fix in Roblox terms (numbers: frames, studs, degrees, colours, counts):

- **MISSING:** the references do it, we don't.
- **WRONG:** we do it, and the references don't or shouldn't.
- **KEEP:** we already match.

**A short "what makes the references good" summary.** The 5-8 principles that the evidence supports.

## 4. Outputs

1. Vault notes in `63 VFX Creation`:
   - one note per area: `Anime Fight Animation - ...`, `Anime Fight Camera - Composition and Rhythm`,
     `Anime Screen Effects - ...`, `Anime Fight VFX - ...`
   - one summary: `Haymaker Rush vs References - Gap Report`
   - all linked from `VFX Creation Start Here`
2. `design/haymaker-rush-v4-gaps.md`: the merged fix list, ranked (HIGH first, animation first). It groups fixes
   into build stages, each with what the owner will see change.
3. A short chat summary for the owner, and a question asking which fixes to build.

## 5. Constraints

**House rules**, from the owner's corrections:

- particles first, no 3D parts for effects unless agreed
- sharp, controlled shapes; every direction and rotation set on purpose, never random
- no solid crescents
- no circles with lines coming out ("a drawing of the sun")
- no black on swing trails
- impact frames are drawn two-tone sequences of 3-6 frames, never a flash
- full colour; black and white only in impact frames
- one complete sound per event, no gore sounds
- references are a quality bar, not a template; don't copy their characters, flames or colours

**The rig.** R6 (6 parts). Animations are baked in Luau (`animations/build_strikes.luau`); Studio's
`generate_animation` is R15-only.

**Agents.** Four study agents at most, one per area, each with all the references and our recording. Each report
is under about 2500 words. I merge them; I don't re-run them.
