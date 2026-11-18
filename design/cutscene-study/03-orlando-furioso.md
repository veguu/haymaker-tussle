# 03 - "New kendo Ultra Move Orlando Furioso Showcase [Type Soul]"

- **Video:** QlvfbPbCYCM, 13.65 s, 60 fps container, 1280x720. A Roblox game (Type Soul), recorded from a player's screen with the full game HUD on (hotbar, health bars, chat, name tags). It is a scripted cutscene on Roblox characters: a sword (kendo) ultimate.
- **Who is who:** the **attacker** wears a white captain's coat (haori: black patterns at the hem, a "八" mark on the back) and has black spiky hair with white horn-like shapes on the head and a black katana at the hip. In gameplay (0.6-0.9 s) the attacker is the camera's player, in white with a green glow. The **target** reads as a dark figure: black clothes and spiky dark hair.
- **What I could see:** camera placement, camera moves and their speed (I measured them with frame-to-frame motion vectors, see note), the cut list, flashes and fades (frame brightness per frame), where the fighters sit in frame, and big silhouettes.
- **What I could not see:**
  - Fine limb and torso angles. The fighters are mostly 20-40 % of frame height, the whole image is graded to high-contrast black and white, so the target is often a solid black blob.
  - Most contact frames. Every big contact sits under a white burst.
  - Who the dark caped figure is at 5.10-5.47. It wears a black cape and a white toothy mask. It is either the target or a dark form of the attacker, and I could not settle which.
- **Recording note:**
  - The capture drops frames: 3.97-4.65 is effectively 30 fps (every other frame is a duplicate), and there are scattered single duplicates elsewhere. I count durations in 60 fps slots (1 slot = 16.7 ms), and a lone duplicate is not treated as a hit-stop.
  - 0.00-0.55 s is one frozen frame. That is the recording, not the cutscene.
- **Measurement note:** camera speeds come from median motion vectors with the HUD cropped out (ffmpeg vidstabdetect). "% W/s" means how far the background slides, as a share of frame width per second. The figures are approximate, and big white bursts corrupt them; I checked every move I quote against the frames.

## Summary (5 lines)

1. The build-up is 2.8 s long and the camera never cuts in it. A fade-in on a top-down close-up of the attacker's head cranes down behind him to a low angle, then eases out to almost still. It releases at 3.97 s with a white flash and a fast orbit (~0.5 s) into a side-on two-shot.
2. After that, 9 s of combo play in **one continuous camera with no hard cut**. Every relocation is a whip of 0.1-0.25 s that eases out over 8-15 frames into a slow drift. During the drifts the background slides at 2-15 % of frame width per second, so the camera is almost never fully still.
3. The camera goes nearly still (~0-1 % W/s) for about 0.4 s right before the two biggest hits (8.67-9.05 before the giant-blade slam, 10.33-10.72 before the 10.80 slash). The hit then arrives with a white-out, a push-in and shake.
4. The fighters stay in the middle third of the frame, small and side-on, filmed from a low camera with a wide lens. Dashes are teleport slashes shown as a one-frame white streak, and the camera pans with them (even reversing direction mid-dash) instead of cutting.
5. There is no slow motion and no clear hit-stop. The slammed target is flat in a crater about 0.23 s after contact, and the white-out (8 slots) hides the contact. Nothing in the film shows a wind-up: big strikes start already mid-swing after a held camera.

---

## A. Sequence and timing

| # | Time (s) | Dur. | What happens | Eye drawn to |
|---|---|---|---|---|
| 1 | 0.00-0.55 | 0.55 | Frozen gameplay frame (recording) | - |
| 2 | 0.57-0.93 | 0.37 | Gameplay camera. The attacker (white, green glow) stands next to the target. At 0.87-0.93 a big white crescent slash sweeps over the target (activation hit, 4 bright slots) | The crescent |
| 3 | 0.95-1.15 | 0.20 | Hard cut to black (HUD still on) | - |
| 4 | 1.15-1.75 | 0.60 | Fade in (S-curve: slow start, fastest 1.35-1.50, slow end) on a **top-down extreme close-up of the attacker's head**. The grade is now black and white. White aura sparks stream to frame right; a chat bubble floats over the head | The head, the white horns |
| 5 | 1.75-2.15 | 0.40 | Near-hold on the head: slight push-in and drift, the head turns a little, aura flickers | The head |
| 6 | 2.15-3.10 | 0.95 | **Crane down and round**: the camera swings from top-down to low behind the attacker, tilting up. Shoulders, coat and legs appear, then the street, buildings and a distant dark figure. The background slides down ~22 % of frame height in 0.55 s | From the head out to the street ahead |
| 7 | 3.10-3.95 | 0.85 | Ease-out settle (5 % of frame height in 0.3 s, then 4 % in 0.55 s). The attacker's back fills the lower centre; his right hand moves at the hip | The attacker's back and head, the street beyond |
| 8 | 3.97-4.47 | 0.50 | **Release**: white flash (4 slots), then a fast orbit of ~90° around the attacker while pulling back (two pulses, the second easing out from 57 px/frame to 2). It ends in a side-on two-shot. First white slash bursts land on the target at 4.23 | The flash, then the two figures |
| 9 | 4.47-5.00 | 0.53 | The attacker stands upright at frame right, sword level at the hip. The target is low near the ground at left, 2-3 body widths away, with repeated white slash sparks on it. The camera drifts slowly the other way (10 % W/s). A black blade shape rises over the target at 4.93 | The sparks on the target |
| 10 | 5.00-5.47 | 0.47 | Camera whips right and lower (49 % W/s, then 21 % W/s). The dark caped figure travels flat and horizontal, left to right, into the white figure (5.10-5.37). 3 identical frames at 5.37-5.40 | The horizontal travel |
| 11 | 5.47-6.07 | 0.60 | One-frame white flash (5.50), then a white crescent arc on the next frame. The attacker crouches low at left, the target is at right; black shapes hang in the air. Slow drift (4 % W/s) | The bursts between them |
| 12 | 6.07-6.67 | 0.60 | **Attacker lunges right** at the target (6.13-6.33, torso pitched forward); the camera pans with him. White bursts on the target 6.43-6.60 | The lunge |
| 13 | 6.67-7.17 | 0.50 | **Circular slash flurry**: white and black crescent arcs wrap round the standing target, the attacker low at left. Camera jitters | The arcs around the target |
| 14 | 7.17-7.75 | 0.58 | **Dash-through slashes**: a horizontal white streak through the target (7.40), the attacker on its right (7.47-7.53), then back on its left (7.60). The camera pans at constant speed (~104 % W/s, 0.2 s), then reverses in a bell-shaped whip (~140 % W/s, 8 frames) | The streak, then the attacker's new position |
| 15 | 7.75-8.17 | 0.42 | Camera settles into a low tilted angle; screen sides have flipped. One-frame white flash (8.05), then a big vertical white crescent round both (8.07); a black axe-blade shape above (8.13-8.20) | The crescent |
| 16 | 8.17-8.53 | 0.37 | Clinch: the attacker crouches into the target; near-hold (5 % W/s) | The clinch |
| 17 | 8.55-8.67 | 0.12 | 2-slot white bloom, then a huge tilted black-and-white ring slash round them (8.58); 1-2 frame camera jolt | The ring |
| 18 | 8.67-9.05 | 0.38 | **Camera hold** (~1 % W/s). Black weapon shapes (axe blade above, spiked club below) hang round the target. Anticipation | The black shapes |
| 19 | 9.07-9.32 | 0.25 | **Big hit**: a giant black blade, several body-lengths long, slams down diagonally from top right through the target. White-out 9.08-9.20 (8 slots), push-in and shake, crater cracks at 9.20, a see-through dome 9.25-9.28 | The blade, then the crater |
| 20 | 9.32-10.10 | 0.78 | Aftermath: the target lies flat in the crater, the attacker crouches beside it. Slow drift (12 % W/s) | The body in the crater |
| 21 | 10.12-10.32 | 0.20 | Big diagonal slash line across the whole frame plus the **fastest whip** (13 % W and 15 % H in 0.1 s), decelerating over ~10 frames into a low tilted angle; screen sides flip | The slash line |
| 22 | 10.33-10.73 | 0.40 | **Camera hold** (~0 % W/s) on a clinch; the target is upright again (how it got up is hidden by the whip) | The clinch |
| 23 | 10.75-11.12 | 0.37 | White slash streak hits the target (10.80-10.87); the camera pans 80 % W/s with a long ease-out. The target hunches; the attacker stands upright at left | The streak, the hunched target |
| 24 | 11.13-11.30 | 0.17 | The pair 2-3 body widths apart, the target hunched | The gap |
| 25 | 11.32-11.50 | 0.18 | Huge crescent wave over the target (11.33), a second on the other side (11.40-11.47); the camera swings | The crescents |
| 26 | 11.53-11.82 | 0.30 | Pan (76 % W/s) as the two close in; the attacker's long black blade is held level | The pair |
| 27 | 11.83-12.10 | 0.27 | Big vertical white crescent with black edges arcs over both | The crescent |
| 28 | 12.10-12.42 | 0.32 | **Pull-back** to a wide shot, the fighters small at centre; slow drift | The pair, small |
| 29 | 12.43-12.55 | 0.12 | Final white burst / dome with a push-in | The burst |
| 30 | 12.55-13.02 | 0.47 | Fade to black (almost linear) while the camera eases back | - |
| 31 | 13.03-13.47 | 0.44 | Fade in to the gameplay camera, colour returns; the camera swings back to the player | - |

**Anticipation, release, settle.**

- The build-up is long (1.15-3.95 = 2.8 s) and runs on one move: fade in → slow near-hold → crane down and round → ease-out to near-still. The slowing camera at 3.4-3.95 (2-4 % W/s) is the "breath in".
- The release is a single white flash plus the fastest kind of camera move (an orbit) at 3.97.
- Inside the combo the same pattern repeats on a smaller scale: whip → drift → hold → hit. The two biggest hits (9.07 and the 10.12-10.80 pair) each follow a ~0.4 s camera hold.
- The ending settles with a pull-back to a wide shot (12.10-12.42), one last burst, and a 0.47 s fade to black.

**Continuous vs cuts vs holds vs hit-stop.**

- Hard cuts: only 0.95 (to black) and the cut under black at ~13.03 (back to gameplay). From 1.15 to 13.0 there is **no cut**. The scene-change scores during the combo never pass ~27 (a real cut here scores 50), and every high score is a whip or a flash that I checked across neighbouring frames.
- Camera holds: 8.67-9.05 and 10.33-10.72 (~0.4 s each).
- Hit-stop: none that I can separate from the recording. 5.37-5.40 has 3 identical frames (50 ms) at the moment the dark figure meets the white one; it could be a deliberate stop or a capture hitch. 10.08-10.10 is the same story. No slow motion anywhere.

**Read time per action.**

- Single slash bursts read in 2-6 slots.
- Crescent arcs stay on screen 4-10 slots (0.07-0.17 s).
- The big slam reads over ~0.25 s, plus the 0.78 s aftermath hold.
- Lunges and dashes take 0.15-0.25 s.
- Each beat is about 0.4-0.6 s. That gives a steady rhythm: roughly two hits per second, with longer holds before the big ones.

## B. Camera work

**Shot 1 - gameplay (0.57-0.93).**

- Standard over-the-shoulder third-person camera, high, behind the attacker. Both characters are small at centre.
- No cutscene camera yet.
- Hard cut to black.

**Shot 2 - build-up, one move (1.15-3.95).**

- **1.15-2.15: top-down extreme close-up.** The camera is directly above the attacker's head, which fills ~40 % of the frame height.
  - Slow drift of the ground (~21 % W/s; the background is close, so this is a small move) and a slight push-in.
  - The head turns a little.
  - Overhead, no roll.
- **2.15-3.10: crane down + tilt up.** The camera swings from overhead, round behind the attacker, down to below his shoulder height, tilting up from straight down to looking slightly up.
  - It accelerates out of the hold. The background slides fastest around 2.6-3.0 (~54 % of frame height per second).
- **3.10-3.95: ease-out.** The move decelerates to 18 % then 12 % of frame height per second and ends almost still. No overshoot is visible.
  - Low angle behind the attacker: his back is huge in the lower centre and the street recedes to a horizon at ~35-40 % of frame height. The buildings' verticals converge (wide lens, looking up).
  - The target's position is not shown clearly: a dark figure stands in the distance centre-left, and I cannot confirm it is the target.

**Shot 3 - the combo, one continuous camera (3.97-12.95).** The same rules hold all the way through.

- **Placement.**
  - The camera is **low** (around the fighters' waist or below, looking slightly up: converging building verticals, low horizon) and **wide** (strong perspective, the fighters 20-40 % of frame height, often less).
  - It sits roughly **side-on to the attacker-target line**, sometimes 3/4 behind the attacker (6.0 shows his back with the "八" mark; 7.0 shows his back-quarter).
  - Both fighters are almost always in the **middle third** of the frame, 1-3 body widths apart.
- **Relocations are whips, never cuts.** Measured profiles:
  - 3.97-4.47 orbit: two pulses. The second peaks at 57 px/frame and eases out to 2 px/frame over ~13 slots (0.22 s). The camera pulls back as it orbits, from the attacker filling the frame to a medium two-shot.
  - 4.95-5.15: whip right and down, 49 % W/s, easing to 21 % W/s by 5.4.
  - 7.38-7.58: a **constant-speed** pan (~25 px/frame every frame, ~104 % W/s) while following a dash.
  - 7.60-7.75: a **bell-shaped** whip the other way: 16 → 38 → 41 → 50 → 55 → 40 → 19 px/frame (ease in 3 frames, ease out 3 frames).
  - 7.78-8.17: decays from ~39 to 2-9 px/frame.
  - 10.12-10.32: hits peak in 2 frames (54 px/frame horizontal, with a large vertical part), then decelerates roughly exponentially over ~10 frames: 36, 31, 26, 29, 11, 11, 7, 8, 1, 6, 2.
  - 10.75-11.12: eases in over 3 frames (5 → 8 → 10), peaks at 49, then **ease-out over ~0.3 s** (15, 12, 17, 14, 25, 14, 30, 16, 14, 13, 13, 14, 9, 9, 6, 4, 0).
- **Easing pattern.** Whips start abruptly (1-3 frames to peak) and end slowly (8-18 frames): fast in, long settle. Overshoot is not visible in the frames.
- **Holds still drift.**
  - "Rest" windows drift at 4-15 % W/s: 4.50-4.95 at 10 % W/s, opposite to the preceding whip; 5.70-6.05 at 4 %; 9.35-10.07 at 12 %; 12.00-12.42 at 10 %.
  - Only the two pre-hit holds are truly still: 8.67-9.05 at ~1 % W/s and 10.33-10.72 at ~0 %.
- **Direction reversals.** At 7.38-8.17 the camera pans left, right, then left within 0.8 s, chasing the attacker as he dashes through the target and back. These reversals give the "hand-held chase" feel.
- **Height changes.**
  - The biggest is in the build-up (crane down).
  - In the combo the camera stays low throughout. 10.12-10.32 includes a large vertical component (the frame drops and rolls).
- **Push / pull.**
  - Push-in at the slam (9.12-9.17, under the white-out; the framing jumps about 1.2x larger and rotates).
  - Push-in at the final burst (12.43-12.55).
  - Pull-back at 12.00-12.13 to the wide ending shot, and again during the fade (12.6-12.95).
- **FOV.** Not measurable from the frames. It is wide throughout. The 9.10→9.12 jump looks like a zoom or push under the flash.
- **Roll / dutch.**
  - A clear dutch at 10.27-10.75: horizon tilted ~15-20°, rising to the right, with the lamp posts leaning.
  - At 7.8-10.1 the frame looks tilted the other way, but the low wide view also bends the verticals, so I can't separate roll from perspective there; any roll is at most ~10°.
  - The build-up and the 12.0-12.4 wide shot are close to level.
- **Shake.**
  - On the slam (9.07-9.32): alternating vertical jolts of ~30-38 px of the 540 px crop (about 6-7 % of frame height, 3 % of width) on consecutive frames for ~12 slots, fading by 9.35. These values are inflated by the white-out, but the jump in framing is visible.
  - Smaller 1-2 frame jolts on the ring slash (8.57-8.62) and around the flurry (6.55-7.05), where the vectors jitter ±10-20 px.
  - No shake on ordinary slash sparks.
- **Before, during or after impacts.**
  - The camera moves **after** ordinary hits: each whip starts on or just after a burst and carries the eye to the next position.
  - Before the big hits it **stops** (holds).
  - During the big hits it jolts and pushes in under the flash.
- **Keeping subjects framed while moving.** During dashes the pan speed matches the attacker (7.38-7.58 constant speed). After each whip the pair lands back in the middle third, and the drift that follows is slow enough not to push them out.
- **Screen direction and the 180° line.**
  - The attacker is on the right at 4.23-5.00, left at 5.6-7.13, right of the target after the dash-through at 7.47-7.53, left again at 7.60-7.73, right at 7.8-10.1, and left at 10.33-11.27.
  - So the line is crossed many times, but every crossing happens **during a whip or a dash-through** (the attacker physically swaps sides through the target), so it never reads as a jump.
  - Because there are no cuts, there is no eyeline matching to judge.

## C. Character animation and posing

- **Attacker poses** (as far as the size allows):
  - **Build-up, from behind (3.1-3.95):** upright, shoulders square to the camera (back to us), sword sheathed level at the waist, sticking out both sides. The right hand moves at the hip around 3.2 (hand to hilt; the exact grip is not readable). Aura haze and cloth stir constantly; the body itself barely moves.
  - **Standing iai (4.23-5.00, 10.93-11.27):** upright, a slight forward lean, facing the target 2-3 body widths away, sword arm out or level. Hits land on the target as white sparks **without a visible big swing**: the cut is "shown" by the spark at the target, not by the arm.
  - **Low crouch (5.6-6.07, 6.67-7.13, 8.17-8.47):** deep, wide stance with the torso low and turned toward the target and the coat flaring wide (that flare is the main readable secondary motion).
  - **Lunge (6.13-6.33):** torso pitched forward ~30-45°, low, travelling right ~1/4 frame width in ~0.2 s. It reads from the diagonal body line plus the pan.
  - **Dash-through (7.40):** only a one-frame horizontal white streak through the target. The next frame shows the attacker on the other side; there is no body pose in between.
  - **Slam (9.05-9.30):** the giant black blade runs from the attacker's hands to beyond the top right of frame. At 9.20-9.30 the attacker is crouched at the blade's lower end, driving it into the ground. The arms are not readable.
- **Target reactions:**
  - **4.23-5.00:** low near the ground on the left, crumpled or lying, with sparks on it. It barely moves between sparks.
  - **5.10-5.37:** the dark caped figure (probably the target, by its clothes) travels **flat and horizontal**, head first to the right, cape streaming behind, one arm and a thin black blade forward, ~1/3 frame width in ~0.25 s, ending on top of the white figure. I can't tell whether it is pulled in or lunging.
  - **5.6-7.13:** standing or hunched, facing the attacker. During the circular flurry it stays in place while the arcs wrap round it; only small recoils are visible.
  - **9.07-9.30:** driven **down**: at 9.117 its dark limbs are already displaced left and low; by 9.30 it lies flat in the crater.
  - **9.30-10.10:** lying still (front or back down is unreadable).
  - **10.33-10.73:** upright again in a clinch.
  - **10.80-11.27:** hunched and staggering after the streak.
- **Transitions between attacks:**
  - No popping is visible at this size. The biggest position changes (the dash-through, the side swaps, the target getting up after the crater) all happen under a streak, a flash or a whip. The cutscene hides discontinuities instead of animating through them.
  - Dead time: none. Even the holds have VFX forming or a clinch moving.
- **Grounded vs airborne:**
  - The fight is almost entirely grounded and low. The only clearly airborne body is the horizontal travel at 5.10-5.37.
  - The camera height does not change to follow anyone up or down.
- **Root motion vs in place vs physics:**
  - The attacker's position changes are teleport-like: there are no in-between frames at the dash-through.
  - The 5.10-5.37 travel is smooth and continuous, which looks scripted, not ragdoll.
  - The crater pose looks like a set lying pose.
  - None of this is provable from the frames.

## D. Screen effects and impact treatment

- **Grade:** the whole cutscene (1.15-13.0) is desaturated to high-contrast black and white. Whites bloom; dark clothes go solid black, so the target is a black silhouette against grey ground and white VFX. A trace of the attacker's green glow survives at 1.8-2.1. Colour returns with the fade-in at 13.07. The grade is the main readability tool: black target, white attacker, grey world.
- **Fades:**
  - Fade to black at 0.95 is a hard cut, holding ~11 slots.
  - Fade-in 1.15-1.75 (36 slots, S-curve).
  - Fade-out 12.55-13.02 (28 slots, near-linear).
  - Fade-in 13.07-13.45 back to gameplay.
- **White flashes / blooms** (whole-frame brightness jumps):
  - 0.87-0.93 (4 slots, activation crescent).
  - 3.97-4.03 (4 slots, the release).
  - **5.50 (1 slot)** and **8.05 (1 slot)**: a one-frame white bloom over the centre of the frame, followed on the very next frame by a crescent arc. The flash is the "spark" that announces the arc.
  - 8.55-8.57 (2 slots, before the ring).
  - **9.08-9.20 (8 slots): the slam white-out.** It covers most of the frame; only the black blade and black limbs show through.
  - 10.15-10.22 (5 slots, the diagonal slash).
  - 11.32-11.38 (5 slots, the crescent wave).
  - 11.83-11.92 (2 + 2 slots).
  - 12.43-12.50 (~5 slots, final burst).
  - The flashes are white, never black. None is a full-screen solid colour; the black silhouettes stay visible inside them.
- **Slash VFX:**
  - Thin white streak lines (4.5-5.1, 7.40, 10.13, 10.80, 10.93).
  - White crescent arcs with black inner edges (5.52, 6.73-7.13, 8.07, 11.33-11.47, 11.87-12.07).
  - A large tilted ring (8.58).
  - Black solid weapon shapes (axe blade, spiked club, the giant blade) at 8.13-9.30.
  - Crater cracks decal at 9.20-10.10, and a translucent dome at 9.25-9.28.
  - Crescents stay 4-10 slots and are the largest shapes on screen, sometimes covering half the frame (11.33, 11.87, 12.47).
- **Particles:** white aura sparks in the build-up; white sparks and small black shards at hits.
- **Speed lines / overlays / cards / vignette / blur / inversion / distortion:** none seen. The HUD stays on throughout (game UI, not an effect).
- **Shake:** see B; only on the slam and the ring.
- **Essential vs decorative:**
  - Essential: the white bursts at the target (they *are* the hits, since the arm swing is not shown), the one-frame flash before each crescent, the slam white-out, the crater cracks, and the grade.
  - Decorative: the floating black weapon shapes, the aura sparks, the dome.
- **Hiding the characters:** the slam white-out (9.08-9.20) hides the contact completely; the big crescents (11.33-11.47, 11.87-12.07, 12.47) cover the target for 4-10 slots. Between them the silhouettes are clear.

## E. What it teaches us

**Strongest techniques.**

1. **One camera, no cuts, for 9 s.** Relocations are whips that ease out into drifts, so the eye never resets.
2. **Stillness as anticipation.** A 0.4 s camera hold before a big hit, then a white-out + push-in + shake on contact.
3. **Hide the jumps.** Position swaps, side flips and get-ups happen under a streak, a flash or a whip.
4. **A long, slow build-up** (2.8 s, one crane move, decelerating to near-still), released by a flash and the fastest move of the clip.
5. **Readability by value:** black target, white attacker, grey world, small but always in the middle third.
6. **A one-frame white flash right before an arc** announces each big slash.

**Principles to adopt.**

- Camera moves start fast (1-3 frames) and settle slowly (8-18 frames). Between whips, keep drifting at ~5-15 % of frame width per second instead of locking.
- Reserve true stillness for the frame before the biggest hit.
- Let the camera chase dashes in the same direction at matched speed. If the attacker swaps sides, swap with a whip, not a cut.
- Keep the camera low and wide so the fight feels big even with small figures.

**What would NOT translate to an R6 blocky-fist cutscene, and why.**

- Sword-specific readability: hits shown as sparks at a distance (iai) with no arm swing. A punch needs the fist and arm to arrive, or it reads as nothing.
- Crescent arcs and the giant summoned blade belong to this kit.
- Hiding every contact under white would lose the "fist meets torso" moment the owner wants us to show.
- The black-and-white grade works here because of the white coat against the black target. Our characters would need a value contrast like that, or the grade would merge them.
- Recording artefacts (frozen opening, 30 fps segments) are not technique.

**Concrete uses in our sequence.**

- **Lock-in close-up:** start overhead or tight on the attacker and crane down and round to low behind him in one decelerating move (~1 s move + ~0.8 s settle). Release with a flash and a fast orbit to the side-on two-shot. Do not cut from the close-up to the rush.
- **Rush:** film it from the side or 3/4 front, panning at the runner's speed (like 7.38-7.58, constant pan), not from behind. Mark the start and end with a white streak or burst. Here the runner barely needs frames of running.
- **Hook → flurry → uppercut:** keep one camera. Between hits use short whips (0.1-0.25 s, ease-out) that land the pair back in the middle third, then drift slowly. For the juggle, keep the camera low and let the target rise in frame, as here, where the camera never rises to follow.
- **Uppercut → longer dash:** this reference has no long launch, so no direct model. The useful part is how a gap is crossed: a whip that leads the attacker, plus a streak.
- **Haymaker wind-up:** replace the slow arm rotation during the rise with **a held, already-loaded pose plus a ~0.4 s camera hold** while something gathers (here the black weapon shapes). The strike then starts mid-swing on the first frame it is shown (9.067).
- **Impact and knockback:** contact under a short white-out (here 8 slots), with a push-in and 0.2 s of decaying shake. The target is visibly displaced 3 slots after contact and at rest 0.23 s later; no 0.75 s near-still slow motion. If we keep a slow phase, the body should keep moving.
- **Ending:** pull back to a wide shot, one last burst, ~0.5 s fade.

## F. The six questions

1. **Facing at contact.** The target faces the attacker in every readable hit: front toward the attacker, side-on to the camera, because the camera sits side-on to the line between them (6.0, 7.0, 10.93). The hits land as white bursts on the target's middle (torso height), not on a flank, but the black silhouette hides whether the chest is square. At the slam (9.07) the blade comes down from above and behind the target relative to the camera, so contact is on the top or upper body; the white-out hides the exact frame. A fist is not shown; this is a sword kit.
2. **Launch distance.**
   - The target is **never launched far**. It stays 1-3 body widths from the attacker the whole combo.
   - The longest travel is the horizontal one at 5.10-5.37 (~1/3 frame width, about 2-3 body lengths, ~0.25 s), and it goes toward the attacker, not away.
   - The big hit sends the target **down**, not back: displaced by 9.117 (3 slots after the blade first shows at 9.067), flat in the crater by ~9.30 (0.23 s).
   - The next attack comes from the attacker staying beside the target and the camera relocating. The fight never has to be carried over distance.
3. **Rush readability.**
   - There is no long run in this reference.
   - Short rushes read through four things:
     - the lunge pose (torso pitched ~30-45° forward, 6.13-6.33, ~12 slots);
     - a one-frame horizontal white streak through the target for the dash-through (7.40), with the attacker on the other side next frame;
     - the camera panning in the direction of travel at matched speed (7.38-7.58, constant ~104 % W/s);
     - a clear before/after: the attacker's side of the target flips.
   - The opening approach (3.97-4.25) shows no run at all. A flash plus a ~0.27 s camera orbit and pull-back replaces it, and the pair is already together when the orbit ends.
4. **Dash into the final strike.**
   - Not shown as a dash. Before the giant-blade slam the attacker is already next to the target; the camera **holds** for ~0.4 s (8.67-9.05) while black weapon shapes hang in place. The blade appears **already in its downswing** at 9.067; no wind-up rotation is shown.
   - The final burst (12.43) follows a pull-back to a wide shot (12.10-12.42), where the fighters are too small to read a wind-up.
   - What carries the transition: a camera hold before, then a white flash at the strike. No cut, no slow rotation.
5. **Knockback onset.**
   - At the slam the body is visibly displaced 3 slots (~50 ms) after the blade first appears, and flat by ~14 slots (0.23 s). This sits under an 8-slot white-out with shake and push-in.
   - No hit-stop is visible beyond one recording duplicate (9.100), and **there is no slow motion anywhere** in the clip.
   - At the 10.80 streak the target hunches within 2-4 slots.
   - The only multi-frame freeze is 5.37-5.40 (3 identical frames, 50 ms, at the collision). It could be a short hit-stop or a capture hitch.
6. **Smoothness.**
   - **Camera:**
     - It is almost never locked: it drifts at 4-15 % W/s in "rest" windows, often in the opposite direction to the whip before.
     - Whips are abrupt in (1-3 frames) and long out (8-18 frames); one pan runs at constant speed while following a dash.
     - It reverses direction with the action (7.38-8.17).
     - True holds exist only twice (8.67-9.05, 10.33-10.72, ~0.4 s each), right before the big hits, and something keeps moving inside them: the clinch and the floating weapon shapes.
     - The build-up is one long eased move with no cuts.
   - **Bodies:**
     - The attacker's coat flares and the target's cape and hair stream; aura sparks never stop; every hit brings new VFX.
     - Big discontinuities (teleports, side swaps, the get-up from the crater) are covered by streaks, flashes or whips, so nothing visibly pops.
     - Limb overlap and arcs are too small to judge at this size.
