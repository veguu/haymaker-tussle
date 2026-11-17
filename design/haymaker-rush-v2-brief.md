# Haymaker Rush v2 - the brief

Written 2026-11-17 after studying the user's reference "New Finisher for Azure Flames Mastery" (Heroes
Battlegrounds, YouTube Short `sfZyOKF50so`, 720x1280 at 60 fps) frame by frame. Contact sheets at 12 fps, each
frame stamped with its time: `design/references/azure-flames/sheetN_from_Xs.jpg` (sheet times restart at 0, so
sheet N starts at 2N s). The user's goal: Haymaker Rush "just as good as the Azure Flames reference", with "just
the right feel and alignment", leaving nothing to interpretation.

Their complaints about the current version (kits-6f): "the camera work isnt really good as you cant see whats going
on", "the punch sfx dont match the animations". Earlier: "it all happens to fast", "the punches are too fast".

---

## 1. What Azure Flames does, measured (absolute video time)

| Time | What happens | Camera | Screen |
|---|---|---|---|
| 0.0-0.4 | Fade in (video editing: ignore) | - | - |
| 0.4-1.0 | Normal gameplay, combo lands | Gameplay camera, wide, behind and above | Normal |
| 1.0-1.45 | CHARGE: a sphere of two-colour flame (purple core, cyan licks) grows around the attacker | Same wide shot, no cut | Whole frame tints toward the purple |
| 1.5-1.95 | BURST: floor slabs erupt and fly, white wind swirl around the body | Same shot | Tint switches to blue |
| 2.0-2.1 | Flash burst, a blue streak across the screen | - | - |
| 2.17-2.92 | DASH: white wind lines rush toward the camera, a blue arc slash, a purple flame flare | Wide, behind the attacker | Colour normal |
| 3.0-3.25 | CONNECT: attacker's dark silhouette in purple/cyan flame with four-point sparkles | ONE close-up, low angle | - |
| 3.33-3.92 | Attacker drives in, wind swirl, the target takes the hit | Low, behind the attacker, pulling back wide | - |
| 4.0-4.45 | COMBO: grabs and hits, dust rolling on the floor | LOW WIDE angle, slight fisheye, both bodies whole in frame | - |
| 4.5-4.6 | The big hit: purple HALFTONE (dot-pattern) burst plus cyan streaks over the whole frame | Same shot | Halftone overlay |
| 4.67-4.75 | Purple flame explosion, the target launched up and out of frame (top right) | Same shot | - |
| 4.83-5.25 | Follow-through: cyan wind slashes, dust, attacker dashes | Same low wide shot | - |
| 5.33-5.5 | LEAP: cyan/purple vortex at the feet, purple flame pillar, attacker jumps | Low wide | - |
| 5.58-5.92 | HANG: both fighters small, high against the sky | WORM'S-EYE, very wide (fisheye), tilted, the arena roof ring framing them | - |
| 6.0 | Attacker bursts into frame from below, cyan | Close, from below | - |
| 6.08-6.33 | SLAM: a column of purple fire crashes down, white spikes and cyan arcs at its base | Wide, low | - |
| 6.42 | IMPACT FRAME 1: black, a tiny diamond at the hit point | - | Black |
| 6.5-6.58 | IMPACT FRAME 2-3: black with one white diagonal slash, then a thinner slash | - | Black + white |
| 6.67-6.75 | IMPACT FRAME 4-5: white paper, the two fighters as an INK SKETCH, radial spark | - | White + black lines |
| 6.83 | IMPACT FRAME 6: red/black, white starburst, red shards | - | Red/black |
| 6.92-7.0 | COLOUR RETURNS: a cyan flame wave sweeps across the ground | Wide | Normal |
| 7.08-7.67 | Aftermath: purple explosion cloud, sparkles, smoke; fade (editing) | Wide, still | Darkening |

From charge to impact frames: about 5.4 s. Around 8 shots in total, and all but two of them wide.

## 2. Why it works (the qualities to match, not the set pieces)

1. **You can always see both fighters.** Nearly every shot is wide or low-wide, with both bodies whole in frame.
   Only two short close-ups (0.25-0.35 s), and both come where nothing is being missed.
2. **Few cuts, long shots.** Eight shots in about 6 s, and each one holds while the action moves through it.
3. **Low camera, wide lens.** Most shots sit near the floor looking slightly up, at a wide FOV (fisheye feel), so
   the fighters look big and the arena looks huge.
4. **Two colours plus white, everywhere.** One palette for every layer: core colour, edge colour, white hot spots.
   The screen grade shifts between them by phase (purple charge, blue burst).
5. **Every phase changes something on screen.** Aura, then destruction, then speed lines, then halftone, then
   pillar, then impact frames, then wave. It never repeats the same effect twice in a row.
6. **Destruction makes the power believable.** Floor slabs fly at the burst, dust rolls on every heavy hit.
7. **The big hit is a sequence.** Hang (a pause in the sky), slam, then 6 drawn impact frames over about 0.45 s,
   then colour returns with a sweeping wave. The release is as designed as the hit.
8. **Contrast in pace.** Fast combo, then a slower hang, then the slam. The pause is what makes the slam land.
9. **Sound lands on contact.** The video is mostly music, so use it for timing only (the vault sound study). Every
   visible contact still has a sound transient on that exact frame.
10. **It ends.** The smoke settles, then control returns. No abrupt snap back to the gameplay camera.

## 3. Locked decisions (do NOT reopen; the user set these)

- Haymaker Rush is the default ultimate. Every kit falls back to it.
- The scene stays in full colour. Black and white appears ONLY in the impact frames. No title cards, no K.O. cards.
- About 6 s from the G press to the flight, with a HELD wind-up and a moment of SILENCE before the haymaker.
- The barrage comes in two bursts that speed up, with a breath between them (rhythm measured in the references),
  not one even beat.
- Every camera stays on the attacker's right (one side of the action, never crossing it). Every blow is a real swing.
- No charge-up sound.
- Sounds: ONE complete sound per event, never a punch stacked from layers at runtime. No gore, splat or squelch
  sources. Our own sounds come from royalty-free recordings (`sfx-lab/final`, built by `sfx-lab/build_round*.sh`;
  the library is `C:\Users\spicy\SFX Library\Sonniss GDC 2026`). The heavy hit is `ult_haymaker`
  (120198385193140), and M1 takes are `m1_hit`.
- VFX: particles first (meshes, camera work and screen effects only where particles can't do it). Flipbooks for
  smoke. Sharp, controlled shapes with every direction set on purpose and nothing random. No circles with lines
  coming out ("a drawing of the sun"). No solid crescents. No black on swing trails.
- Impact frames are DRAWN two-tone sequences (silhouettes, speed lines, star flares), never a flash. Vault:
  `63 VFX Creation/Impact Frames - What They Are and How to Build Them in Roblox.md`.
- References are a quality bar, not a template. Copy Azure's qualities (section 2), not its flames, its purple, or
  its exact moves.

## 4. Decide with the user BEFORE building (ask; don't assume)

1. **Palette.** Azure uses two colours plus white. Base FX are plain white/grey (FxKit rule 2), but the decision
   above is "full colour". Offer 2-3 palettes as stills of the same frame, e.g. (a) white + warm gold, (b) white +
   crimson, (c) the attacker's kit colour + white. Use one palette for every layer and the grade.
2. **Keep the approved beat times?** Recommended: yes (blow 1.14, barrage 1.76-3.06, uppercut 3.64, leap 4.2,
   wind-up 4.5, dip 5.1, haymaker 5.25, blast 5.55, flight 6.1, in `src/shared/Core/Ultimates.luau`). Redo the
   camera, VFX and sync around them.
3. **Barrage sound.** Recommended: rush blows use our `m1_hit` takes (one complete file per blow, the next blow
   cuts the last). The alternative is a dedicated shorter "rush" take set built the same way. The current
   `ult_rush` is a community upload of Itadori's punch.
4. **Flashing safety.** The impact-frame sequence swaps large areas between black and white several times in about
   0.3 s, which exceeds the common "no more than 3 flashes per second" guideline. Options: (a) keep it, but give
   the setting menu a "Reduce flashing" toggle that swaps polarity flips for a single held frame, or (b) design the
   sequence with at most 3 large luminance swaps.
5. **The two close-ups.** Recommended: the wind-up (4.5-5.1, nothing else is happening) and the very first
   contact (1.14, 0.3 s). Every other shot is wide.

## 5. The beat sheet (times from the G press)

Coordinates are in the cinematic's anchor frame as `Ultimates.luau` uses it. +X is the attacker's right, and the
attacker starts behind the target and drives toward it. READ THE HEADER COMMENT OF `HAYMAKER_RUSH` AND CONFIRM THE
AXES before trusting any number below: the numbers are starting points, and the checks in section 7 decide.

| Time (s) | Beat | Camera | Attacker | Target | VFX (palette: C1 core, C2 edge, W white) | Screen | Sound |
|---|---|---|---|---|---|---|---|
| 0.00-0.50 | LOCK-IN / CHARGE | S1: wide 3/4 from the attacker's front-right, low (about 1.5 studs above the floor), FOV 70, slow push in. Both bodies whole | Plants, aura rising | Stunned, reeling (still held from the string) | Aura: C1 flame wisps rising off the body (flipbook), C2 licks at the edges, W sparks drawn upward; a ground ring of dust | Grade eases 25 % toward C1, slight contrast push | `ult_bed` swells in (no charge sound) |
| 0.50-0.80 | BURST | S1 continues, small shake 0.15 | Burst pose | - | Floor erupts: 4-8 rock slabs thrown at set angles (solid chunks are allowed), dust flipbook ring, W shock bubble | Grade flips to C2 for 0.15 s, then eases back | one burst sound (complete, dry) on the frame the slabs leave the floor |
| 0.80-1.14 | DASH | S2: wide side profile from the right, about 16 studs out, FOV 65, tracking with the attacker | Dash (DashFx after-images) | - | W wind lines along the path, C2 trail | - | `dash` |
| 1.14-1.44 | FIRST CONTACT (close-up 1) | S3: 0.3 s close, low, from the front-right, attacker's fist and target's face both in frame | Right hook lands at 1.14 (swing starts 1.14 - 0.16) | Heavy flinch | Hit flare at the fist (PunchHitFx heavy), C1 sparks, small halftone burst | 2-frame hit-stop | `m1_finish` on the contact frame |
| 1.44-3.40 | BARRAGE (two bursts and a breath) | S4: LOW WIDE behind the attacker's right shoulder, about 9-11 studs, FOV 80 (fisheye feel); both whole; slow 15 deg orbit to the right across the barrage | Hooks on the existing PUNCHES times, each a real swing started 0.16 s before its contact | Flinch per blow, light/heavy as `rushBlows` | Per blow: a small W flare where the fist meets, C2 streak along the punch. Burst 1 last hit: halftone burst (C1 dots). Breath: dust settles. Burst 2 last hit: a bigger halftone burst plus C2 streaks across the frame (Azure 4.5) | Halftone overlay only on the two burst-ending hits | Each blow: one `m1_hit` take (or rush take, per section 4.3) on its contact frame; each cuts the last |
| 3.40-4.20 | UPPERCUT and LAUNCH | S5: low, from the front-right, FOV 75, tilting up to follow the target | Uppercut lands at 3.64 (swing starts 3.56) | Launched straight up, spinning slowly | Dust ring at the attacker's feet, W vertical streaks under the target, C1 flame flare at the fist | - | `m1_finish` on contact; `launch` whoosh |
| 4.20-4.50 | LEAP and HANG | S6: WORM'S-EYE, camera near the floor, FOV 85, both fighters small against the sky, slight tilt allowed | Leaps (pillar of C1 flame at take-off) and rises to the target | Hangs at the top (slow drift) | C1/C2 vortex at the feet on take-off, a short C1 pillar | - | One leap sound (whoosh + thump, complete) |
| 4.50-5.10 | WIND-UP (close-up 2, HELD) | S7: medium close on the attacker's face and cocked right fist from the front-right; the target soft in the background so we know where it is; slow push in, FOV 44 down to 36 | Haymaker held drawn back (HoldSwing) | Hangs | C1 gathers into the fist (particles drawn inward), W glint (two set-angle stars) | Vignette builds | `ult_bed` builds |
| 5.10-5.25 | DIP / SILENCE | S7 holds | Still | Still | Everything holds, particles slow | Darken 20 % | ALL sound fades to silence in 0.05 s |
| 5.25-5.55 | HAYMAKER + IMPACT FRAMES | Under the frames: wide side profile from the right (the silhouettes must read) | Swing releases from the hold (contact at 5.25) | Takes it | Impact-frame sequence (section 6) | Black/white ONLY here | `ult_haymaker` on 5.25 exactly (transient at sample 0; its own roar covers the blast) |
| 5.55-6.10 | BLAST and COLOUR RETURN | S8: wide from the right and a little behind the attacker, FOV 75, holding as the target is thrown | Follow-through pose | Thrown away, out of the arena | Colour returns WITH a C2 wave sweeping across the floor from the hit point; dust and debris; W shock bubble; C1 explosion cloud (flipbook) | Grade back to normal over 0.3 s | No new impact sound (the heavy hit's roar is still playing). Debris crackles are inside it |
| 6.10+ | FLIGHT and HAND-BACK | The existing chase shot follows the flight (FOV widening to `flightFov`), then the screens DIP TO BLACK and the gameplay camera comes back under the black (the user's pick, 2026-11-15; corrected in stage 1, it isn't a blend) | Control returns at `attackerFree` | Flight to `flightEnd` | Smoke settles about 0.6 s | - | (`ult_bed` was already cut at the dip) |

## 6. The impact-frame sequence at the haymaker (5.25-5.55)

Six frames, each held for a set number of 60 fps frames, with the world frozen (hit-stop) underneath. Build them on
the existing `src/client/Fx/ImpactFrame.luau` (it already has: black + slash, white, ink sketch with lines, black
split, white with black stars).
1. 5.25: black. A tiny W diamond at the hit point (2 frames).
2. 5.283: black, one long W slash through the hit point at -34 deg (the existing `slash`) (3 frames).
3. 5.333: black, thinner slash, fading (2 frames).
4. 5.367: white paper. Both fighters as an ink sketch (black outlines), radial speed lines from the hit (5 frames).
5. 5.45: C1/black: a W starburst at the hit, shards in C1 (3 frames).
6. 5.50: colour returns. The C2 wave starts at the hit point and sweeps outward (section 5, 5.55 row).
Subject to the flashing decision in section 4.4.

## 7. Checks that must pass (measure them; don't eyeball)

**Camera readability.** Write a test that runs the timeline headless (or in Studio) and samples every 1/30 s:
- In every shot except the close-ups and the impact frames, both fighters' HumanoidRootPart AND Head project
  (`WorldToViewportPoint`) inside the frame with an 8 % margin, at phone 19.5:9, desktop 16:9 and tablet 4:3.
- In wide shots the target is at least 15 % of the screen height tall, so it reads on a phone. The one exception is
  the worm's-eye hang (4.2-4.5), which is small against the sky on purpose: at least 8 % there (corrected in stage 1).
- The camera is never inside a part or a body. Raycast from the subject to the camera; it must hit nothing.
- The attacker never hides the target for more than 0.2 s at a time. Raycast from the camera to the target's head.
- Every camera stays on +X (the attacker's right). Assert it.
- No shot is shorter than 0.3 s, except the impact frames.
- Re-run the test with the cinematic started next to an arena wall and the barrier, from several anchors.
  Walls must not block the shot (pull the camera in along its ray if they do; never flip sides).

**Sound sync.** For every blow, log (a) the time the swinging hand (RightHand or LeftHand) is closest to the
target's torso and (b) the time its sound starts. They must agree within 33 ms (2 frames at 60 fps). Log both
from the same client, with Studio in front (in the background it runs at about 12 fps and cues fire late). Every
sound file's transient is at sample 0, so `start = 0`.

**Pace.** Total time from G to control back: 6.1 s plus a blend of up to 0.4 s. The two barrage bursts keep their
measured spacing (`tests/Ultimates.spec.luau` already pins the pace, the one-sided cameras and the uneven barrage;
keep those tests passing and add the camera tests).

**Look.** Make 12 fps contact sheets of our own cutscene (same method as the Azure sheets: `ffmpeg fps=12, tile`)
from a screen recording or `screen_capture` at the beat times, and put them next to the Azure sheets. Every beat in
section 5 must show what its row says.

## 8. Corners that get missed if left to interpretation

- **Animations aren't uploaded.** Play prints "not uploaded, so these won't play in a live game" for HookLeft,
  HookRight, Uppercut, ClashBarrage and others. The ultimate looks right in Studio but not live until those are
  uploaded to the group (2970443) and the ids are put in (never invent ids).
- **Clips can't be sped up** (`Config/AnimClips.luau` is generated). A hook strikes 0.16 s into its 0.63 s. An
  uppercut strikes at 0.08 s. Start each swing at contact minus strike time. Never move a contact to fit an anim.
- **Bystanders.** Other players see the bodies posed by the server and the world VFX, but not our camera. Every VFX
  layer must look right from any angle (particles do; screen overlays are only for the two fighters' clients).
- **Interruptions.** The target or the attacker leaves, dies or resets, or the round ends mid-cinematic. Every
  emitter, overlay, grade, sound and camera override must clean up within one frame, and control must return.
- **Bots and dummies** go through `UltimateService:CarriedPose`. Test on Practice Dummy 1 and on a bot.
- **Lag.** The timeline runs on the shared server clock (`startedAt`). A late client must jump into the right beat,
  not play from the start.
- **Studio in the background** runs at about 12 fps and cues fire up to 0.1 s late. Judge timing only with Studio in
  front.
- **Phones.** Particle count: no more than the existing FX budget per frame. Overlays scale to the screen. The HUD
  is hidden during the cinematic and comes back after.
- **Volume levels.** Measure the M1 takes and the heavy hit against the rest of the game sounds (PlaybackLoudness
  times Volume, Field Notes Sound Design Pitfalls section 6) so the haymaker is clearly the loudest moment of the
  game, and the barrage is not louder than normal M1s.
- **The place can be ahead of Git.** Compare the build stamp in the place with `src/server/init.server.luau`
  before Connect and before every play test (memory: haymaker-place-ahead-of-git).

## 8b. Stage 1 as built (kits-7b, 2026-11-17): what changed from the table in section 5

- **The beatdown is a JUGGLE** (the user's pick, from Garou vs Stinger 7.5-9.4 s; contact sheets in
  `design/references/garou-stinger`).
  - The first hook pops the target up.
  - The attacker stays PLANTED while each hook bounces the target up and a little back. They sink between hits,
    and the last hook of the burst sends them highest.
  - One step in during the breath. A still SET (3.18-3.40). A step in under them for the uppercut.
  - The old version slid both bodies back in a line and its fists stopped 1.4-2.2 studs short ("the punch barrage
    is a little awkward").
- **Juggle camera, three shots** (the user: "more varied, it just stays at the same far side view"):
  - static wide side profile for burst 1
  - from the breath (2.18), low behind the attacker's right shoulder, pushing in, for burst 2
  - from the last bounce (3.18), low front-right for the set and the uppercut
- **Camera KICKS on every hit** (`Timeline.kicks`, `Ultimates.kick`; the user: "screen shake"): a punch-in of
  3-10 deg plus shake of 0.16-0.8 studs, fading out. Small on the barrage, bigger on each burst's last hit, big on
  the first hook and the uppercut, biggest on the haymaker and the blast.
- **The wind-up is no longer a close-up** (the user: "bad angle / framing, too short / jarring"). The leap's
  worm's-eye shot glides without a cut into a medium two-shot from below-right, the cocked fist toward the camera
  and the target clear beyond, then pushes in through the silence. Only ONE close-up remains: the first hook.
- **The haymaker's knockback starts on contact** (the user: "the knockback from the last hit is delayed"): a 50 ms
  freeze, then they fly under the impact frames. Measured: 0.95-1.2 studs moved by 5.40 (was 0).
- Wide shots use `rel = "pair"` (offsets from the fighters' midpoint), so they track the action.
- **Measured:**
  - `tests/UltimateCamera.spec.luau` passes: both fighters inside the safe frame at phone, desktop and tablet
    shapes, from 4 attacker starts, kicks included; worst edge 0.67 of 0.84.
  - Sounds start within 2-24 ms of their cues (46 fps run).
  - Fists now land 0.3-1.3 studs from the torso on the frames caught.
  - NOT fully verified: per-hit fist-to-sound timing at full frame rate. Studio throttles to 12-15 fps whenever its
    window is covered, and most runs were throttled.
- **kits-7c, after the user tried kits-7b.** They said "the camera angles are too far behind so you cant really
  see the punches ... dont rotate too much and just keep the side view but make it closer up, not close enough
  that you cant see both bodies in their entirety and the floor beneath, and add some good screen shake".
  - The juggle and the uppercut are SIDE VIEWS from the right, about 9 studs out (was 14 static, then a
    behind-the-shoulder shot), never more than about 9 deg off the side.
  - Variety comes from height and a slow push in.
  - The camera test now also requires the floor 0.4 studs under both fighters' feet in frame for 1.44-3.18.
  - The shake is set sine waves on the shared clock with a small roll twist (no more every-frame flip), and the
    kicks are about 1.6x stronger: barrage 0.28/0.45 studs, first hook 0.55, uppercut 0.7, haymaker 1.1,
    blast 0.9.
- **Next, stage 2 effects the user asked for:** Garou's flowing water on the arms and the wind arcs on every strike,
  plus on-screen effects (speed lines, halftone bursts, impact flashes).

## 9. How to build it (stages, with the user's review after each)

1. **Blocking.** Cameras and timing only, no VFX: placeholder white flares at each contact, the sounds in. Pass the
   camera and sync checks. Show the user a play test and a contact sheet. STOP for their verdict.
2. **The big moments.** Impact frames, wind-up and hang, blast and colour-return wave. Play test, verdict.
3. **The rest of the VFX.** Charge, burst and destruction, dash, barrage flares and halftones, uppercut and leap.
   Play test, verdict.
4. **Polish.** Grade per phase, hit-stops, shake amounts, the hand-back blend, volume levels, phones, interruptions,
   bystander view. Gates (build, tests, selene, stylua), then commit only when the user asks.
