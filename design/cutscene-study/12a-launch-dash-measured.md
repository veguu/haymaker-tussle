# 12a. Launch + dash, measured frame by frame (Azure Flames, TSB Garou combo, Garou vs Stinger)

Purpose: numbers for retiming our ultimate's launch and dash (uppercut 3.84, hold 0.25 s, the target flies up and back in
0.34 s, the camera whips up, then a cut to a low camera behind the attacker, 0.17 s crouch-load, take-off at 4.43,
0.57 s dash decelerating into a stop below the target, a 0.26 s hold, then the punch).
The qualitative reports are 02-azure-flames.md, 10-tsb-garou-combo.md and 01-garou-vs-stinger.md. This report only adds
measurements.

## Method

- **Frames:** I read every frame inside the windows as gridded contact sheets. Each frame has a 10% grid, edge labels
  1-9 (= 10-90%) and its source time stamped on it. The two dash stretches of Azure Flames were also read at 2x and 3x
  zoom. For the anime (60 fps upload, with each drawing held for 2-7 frames), only the frames where a new image appears
  were sheeted. `mpdecimate` found 44 new images in 11.28-13.07 s. 14 sheets were used in all.
- **Positions:** given as % of frame width (x) and height (y) from the top-left. Sizes are % of frame height. For Azure
  Flames the frame is the gameplay strip (crop 360x316 at y 160 of the portrait video), not the whole 360x640.
  - **Colour tracking:** where a subject has a unique colour, I tracked its centroid numerically. The ffmpeg rgb24 dump
    was read by a small Lune script that reports the centroid and the 5th-95th percentile extent of the matching pixels.
  - **Azure Flames:** the dummy's red "1%" damage label (it floats a fixed distance above the dummy's head), and the
    yellow hanging sign as a background marker.
  - **TSB:** the attacker's purple outfit, and the target's black clothes inside a region.
  - **Garou vs Stinger:** Garou's white hair.
  - Everything else (bodies inside smoke or blur, sizes) was read by eye from the grid, to about ±2-3%.
- **Camera:** I ran ffmpeg `vidstabdetect` (ASCII output, `fileformat=1`) and took the median of the local motion
  vectors per frame. For translation plus rotation I also ran vidstab's own global estimate
  (`vidstabtransform debug=1` → `global_motions.trf`).
  - **Sign convention used below:** "pan +x%W/f" means the background slid LEFT by x% of the frame width per frame
    (the camera turns or moves right). "tilt +y%H/f" means the background slid UP (the camera tilts down).
  - **Cross-check:** in Azure Flames the vidstab pan agrees with the yellow sign's track to within about 25%.
- **Crops for the camera:** Azure Flames used the gameplay strip only. TSB used the floor band y 350-609 px, which keeps
  the HUD bar and skill slots (y > 87%) and the combo text (from 10.07 s, top 0-30%) out of it. The anime used the full
  frame.
- **Unreliable:** frames under full-screen effects: Azure Flames 4.50-4.80 (the big burst), its cut frame 4.833, and
  5.40+; TSB 8.87-8.90 (a ghosted turn frame plus the finisher burst); the anime 11.88-12.18 (radial burst, whole frame
  blurred) and the grey or green impact frames 12.25-12.63. During the TSB lunge the floor band has few textured fields
  (12-19), so its camera numbers are noisy. I give the target's track there instead.
- **Uneven capture cadence:** both Roblox captures step unevenly. Per-frame steps alternate (for example 4.4 / 0.8 /
  4.4 %W). Read speeds as 2-frame averages.
- **Tools:** in the session scratchpad `ld-a/bin/` (`lsheet.sh`, `trfmed.awk`, `gm.sh`, `blob.luau`). Lune has to be run
  as `%USERPROFILE%\.rokit\tool-storage\lune-org\lune\0.11.1\lune.exe`; the Aftman shim refuses outside a project.
- Vault note followed: `56 Field Notes/Studying VFX References - Frame by Frame, Not From Stills.md` (read every frame
  only inside the events).

---

## 1. Azure Flames (Heroes Battlegrounds), sfZyOKF50so, 30 fps: the closest match

### L: launch. Rising strike, the dummy pops, falls, then the burst throws it up (4.20-4.80)

There are two parts.
- **The rising strike (4.20-4.37):** only pops the dummy up about 7% H and to the right on an orbiting camera.
- **The real "up and away" (4.47-4.63):** this is the burst. The dummy is lying at floor level at the right
  (4.467). It shoots up the right edge and parks in the top-right corner within 5 frames.

| t (s) | f | dummy label "1%" x,y (tracked) | dummy body x,y / size | attacker x,y / size | camera (vidstab) | notes |
|---|---|---|---|---|---|---|
| 4.200 | 0 | 47, 18 | 46, 35 / ~22% | 52, 45 / ~30% | (orbiting) | arm up under the dummy, pair overlapping at centre |
| 4.233 | 1 | 51, 15 | 50, 33 | 55, 47 | pan +1.9 | |
| 4.267 | 2 | 53, 13 | 48, 30 | 50, 52 / ~35% | pan +2.4 | dummy pops (purple-white glow) |
| 4.300 | 3 | 59, 13 | 52, 30 | 50, 53 | pan +1.9 | |
| 4.333 | 4 | 60, 11 | 55, 24 | 48, 53 | pan +3.3 | the dummy's highest point on screen |
| 4.367 | 5 | 63, 18 | 66, 25 / ~33% | 47, 55 | pan +3.6, rolling | white smear along the attacker's leg; the dummy grows (coming toward the lens) |
| 4.400 | 6 | 75, 38 | 85, 55 / ≥41% (edge) | 47, 57 | camera jump, dutch rolls out | unreliable |
| 4.433 | 7 | 74, 48 | 85, 80 (part out) | 45, 55 | unreliable | dummy falls past the right foreground |
| 4.467 | 8 | 78, 41 | 80, 72 lying / ~37% | 45, 48 | unreliable | dummy at floor level; horizon level again |
| 4.500 | 9 | 93, 14 | 90, 45 (right edge) | hidden | burst | BIG BURST (cyan flame and halftone over 70-100%) |
| 4.533 | 10 | (99, 4) | 91, 26 | - | burst | |
| 4.567 | 11 | - | 90, 20 | - | burst | |
| 4.600 | 12 | 90, 3 | 83, 17 | - | burst | |
| 4.633 | 13 | - | 82, 15 | - | burst | at the hang height |
| 4.667-4.800 | 14-18 | 80-82, 10-12 | 79-89, 12-17 (top-right, cut by the top edge) | - | burst; content slides down 0.6-2.9%H/f (camera tilting up, unreliable) | hangs |

- **The rise (body centre y, %H per frame):** 72 → 45 → 26 → 20 → 17 → 15, steps of −27, −19, −6, −3, −2. That is 80%
  of the climb in 2 frames and settled by the 5th frame (0.17 s), a hard ease-out. Afterwards the dummy sits at
  80-90% x, 12-17% y.
- **The attacker during the strike:** stays at 45-55% x, 45-57% y. The orbit is centred on him, at about 30-38% of
  frame height. The orbit pans about 2-3.5%W/f, steady (8 px of 360 per frame, which matches the report's 80 px over
  10 frames).

### H + C: hang and coil (cut at 4.833, coil 4.833-5.033)

The cut lands under the burst residue at 4.833. The new camera is low, at hip height, behind-left of the attacker and
close to him. The dummy hangs top-right and is still in the world; it only drifts with the camera.

### D + A + S: dash, contact, hit-through (5.067-5.367). Per frame

| t (s) | f | dummy label x,y (tracked) | sign left edge x / bottom y (background marker) | camera (vidstab median) | attacker on screen (eye) | notes |
|---|---|---|---|---|---|---|
| 4.833 | cut | 77, 28 | 84.4 / 24.7 | cut | dark mass 3-53% x, 28-89% y | burst residue, strong dutch |
| 4.867 | C1 | 75, 29 | 81.7 / 26.9 | pan +1.4 | centre ~28, 52; ~50% tall | coil: deep crouch, purple aura behind, arm pointing at the dummy |
| 4.900 | C2 | 72, 31 | 76.7 / 26.3 | pan +3.3 | ~27, 48 | white lightning claws in front of him |
| 4.933 | C3 | 72, 31 | 75.0 / 26.3 | pan +0.8 | ~25, 50 | |
| 4.967 | C4 | ~71, 29 | 68.6 / 25.6 | pan +4.4 | head 28, 45 | dutch easing to level |
| 5.000 | C5 | ~67, 34 | 65.6 / 25.6 | pan +2.5 | head 32, 46; body 14-53% x, 42-78% y (h ≈ 36%) | claws reach 54% x |
| 5.033 | C6 | ~67, 34 | 62.8 / 25.3 | pan +2.2 | head 32, 51 (lowest: full load) | |
| 5.067 | D1 | 63, 29 | 58.1 / 21.8 | pan +4.6, tilt +3.2 | body tips forward: 11-46% x, 48-77% y | TAKE-OFF; white streaks start |
| 5.100 | D2 | 62.5, 26.5 | 55.0 / 17.4 | pan +2.8, tilt +4.0 | torso 33, 46; body 10-46% x | streaks along the body; dust starts |
| 5.133 | D3 | 61, 23 | 51.7 / 13.0 | pan +2.5, tilt +2.9 | torso 36, 46; stretched 8-44% x | "superman" pose |
| 5.167 | D4 | 59.5, 20 | 48.6 / 8.9 | pan +2.5, tilt +3.8 | torso 30-38% x, 39-48% y | a long white streak from him toward the dummy (38→60% x) |
| 5.200 | D5 | 58.6, 17.5 | 45.8 / 5.4 | pan +2.2, tilt +2.2 | torso 30-38% x, 41-46% y; only ~10% tall now | dust covers the bottom half |
| 5.233 | D6 | 59, 19 | 43.9 / 5.7 | pan +0.6, tilt 0 | in the dust, ~26-48% x, 35-49% y | camera settled |
| 5.267 | D7 | 59, 20 | 42.5 / 6.3 | pan +0.3, tilt −0.6 | a dark smear 30-55% x, 30-60% y | the final rush |
| 5.300 | A/S | 60, 20 | 41.1 / 7.3 | pan +0.6, tilt 0 | at the dummy: 46-57% x, 21-39% y | CONTACT, white glow on the dummy |
| 5.333 | +1 | 63, 19 | 39.7 / 8.9 | pan +0.3, tilt −2.2 | the pair 55-68% x, 13-38% y | they carry on upward together |
| 5.367 | +2 | - | 37.5 / 17.7 | tilt −7.9 | the pair 47-61% x | the camera tips up after them |
| 5.400 | burst | - | - | burst | - | sphere burst covers the cut to the worm's-eye hang |

**Durations**
- Coil: 7 frames, 4.833-5.033 (0.23 s). The deepest point is the last frame before take-off. The head sinks about 5% H
  over the final 2 frames.
- Dash: 7 frames from take-off (5.067) to contact (5.300), 0.23 s.
- Dash to strike: 0 frames. The contact is the hit, and he carries on upward with the dummy for 2 frames before the
  burst cut.

**The attacker's screen motion has two parts**
- **Held (5.067-5.200, 5 frames):** the camera pans and tilts with him, so his torso stays at about 30-38% x and 41-46%
  y. He shrinks fast, from about 36% to about 10% of frame height, because he is going AWAY from the lens into depth.
- **Cross (5.233-5.300, 2-3 frames):** he covers the last screen gap to the target, about 20% W and 15% H, at roughly
  6-8%W/f, on a camera that has nearly stopped.

**The target is parked**
- The dummy label drifts 75 → 63% x during the coil, which is the camera panning toward it.
- During the dash it goes 63 → 59% x and 29 → 18% y, decelerating.
- For the last 4 frames before contact (5.200-5.300) it holds at 59-60% x, 18-20% y, the upper-right third.
- The background sign moves 2-3x faster than the dummy (parallax). So the camera translates along with the attacker
  while turning to keep the target nearly fixed. It is a follow camera aimed at the target, not a pure pan.

**The camera's speed curve**
- **No ease-in:** it is already panning at about 3%W/f in the first frame after the cut, during the coil (sign track
  3.6%W/f, vidstab 2.4%W/f on average). The camera leads the dash.
- **Through the first 5 dash frames:** a constant pan (sign 3.4, vidstab 2.9 %W/f), plus a tilt-down of 2-4.4%H/f in
  D1-D5 only. The background, the sign and the dummy all slide up together, so this is a rotation.
- **Settle:** within 1-2 frames (D5 → D6) down to 0.3-0.6%W/f (vidstab) or about 1.4%W/f (sign). This happens 2-3
  frames BEFORE contact, so the contact lands on a near-still frame.
- **After contact:** a fast tilt up after the rising pair (content down 7.9-9%H/f for 2 frames), then a burst covers
  the cut.

**What sells the distance**
- During the coil the dummy is about half the attacker's height on screen (~15-20% vs ~36%).
- The screen gap from the attacker's head to the dummy label is about 40% W and 15% H.
- White lightning claws point at the target in C2-C6.
- Streak lines run along the body in D1-D3. A long white streak connects him to the target in D4-D5.
- A dust cloud spreads from D2 and covers the bottom half by D5.
- The attacker visibly shrinks into depth.
- A dark smear marks the final rush (D7), and a white glow marks the contact.
- There is no ring at the take-off. The purple aura sits behind him during the coil.

---

## 2. TSB Garou combo, zP6MFM_SamU, 30 fps (high, steep camera; the attacker stays near 43%, 51%)

### L: finisher, hold, knockback (8.87-9.83)

| t (s) | f | target (tracked black-clothes centroid) x,y | attacker x,y (purple) | camera | notes |
|---|---|---|---|---|---|
| 8.867 | - | (ghosted) | - | rotating 2.5°/f | end of the camera turn (a double image) |
| 8.900 | S | 65.6, 52.3 | ~45, 51 | rotating 2.6°/f (burst) | FINISHER: white-cyan burst on the target |
| 8.933 | H1 | 63.6, 52.0 | ~43, 53 | pan +1.6, 1.1°/f | streak sprays out the far side (70-100% x) |
| 8.967 | H2 | 60.9, 51.4 | ~41, 56 | pan +1.8, 0.5°/f | |
| 9.000 | H3 | 60.4, 50.7 | ~44, 53 | pan +1.0 | |
| 9.033 | H4 | 58.2, 48.6 | ~44, 53 | pan +1.5 | |
| 9.067 | H5 | 57.4, 48.3 | ~44, 54 | pan +0.7 | |
| 9.100 | H6 | 57.5, 48.0 | 43, 56 | 0 | still |
| 9.133 | H7 | 57.6, 47.2 | 45, 54 | 0.2 | |
| 9.167 | H8 | 57.4, 47.0 | 44, 53 | 0.2 | the target is upright and leaning back |
| 9.200 | L1 | 61.2, 46.4 | 42.9, 51.1 | 0.7 | KNOCKBACK starts (step +3.8%W) |
| 9.233 | L2 | 63.4, 46.7 | 43.6, 51.1 | 0 | tumbling |
| 9.267 | L3 | 66.9, 43.6 | 44.9, 50.1 | 0.3 | horizontal |
| 9.300 | L4 | 73.3, 38.6 | 43.6, 50.9 | 0.3 | peak step +6.4%W, rising up-screen |
| 9.333 | L5 | 77.4, 37.9 | 44.3, 50.5 | 0.3 | |
| 9.367 | L6 | 79.1, 38.7 | 44.4, 50.4 | 0.3 | |
| 9.400 | L7 | 84.3, 38.0 | 47.0, 52.0 | 1.0 | |
| 9.433 | L8 | 84.9, 38.0 | 47.0, 52.5 | 0.3 | |
| 9.467 | L9 | 89.1, 39.1 | 46.1, 53.3 | 1.0 | |
| 9.500 | L10 | 90.8, 39.6 | 45.2, 53.6 | 0.7 | |
| 9.533-9.633 | L11-14 | 91 → 95, 39-40 | 43.6-44.4, 52-53 | 0.2-0.7 | reaching the right edge |
| 9.667-9.800 | L15-18 | 96-98 (a sliver at the edge) | 43, 51 | 0 → −0.3 | gone by 9.83 |

- **The hold before the flight:** 9 frames (8.90-9.17, 0.30 s). The target is still in the world. Its 8%W leftward
  drift on screen in H1-H5 is only the camera settling after the turn, which eases out from 1.8 to 0%W/f by 9.10.
- **The flight on screen:** from 57% to 95% x (38% W) in 14 frames (9.17-9.63), then off the right edge.
  - Shape (2-frame averages, %W/f): +3.0 (L1-L2), +5.0 (L3-L4, the peak), +2.9, +2.9, +2.9, +1.5, then +0.5 at the
    edge.
  - So: a fast start reaching its peak at frames 3-4, then an ease-out.
  - Vertically: it rises 8% H during L2-L4 (tumbling to horizontal and moving away up-screen), then stays level at
    38-40%.
  - It shrinks only about 25% over the flight (the black extent is 9.7% → 6.7% H).
- **The camera during the flight:** practically still. It follows only a little, 0.3-1.0%W/f in the same direction.
  The attacker stays at 43-47% x, 50-54% y.

### Camera re-aim and the lunge (9.80-10.57)

| t (s) | f | target x,y (eye / tracked right edge) | attacker (purple) | camera | notes |
|---|---|---|---|---|---|
| 9.800-9.933 | - | off screen | 40-41, 51 | background slides right 0.3-0.7%W/f | slow drift while he recovers and turns |
| 9.967-10.067 | - | off | 42-43, 51 | still (≤0.2) | |
| 10.100 | R1 | off | 43.6, 51.1 | floor slides DOWN 1.4%H/f | RE-AIM starts (combo text starts typing at 10.07) |
| 10.133 | R2 | (edge) | 43.7, 50.6 | down 3.0%H/f | peak |
| 10.167 | R3 | 98, 42 | 43.5, 50.7 | down 2.6%H/f | the target re-enters at the right edge, lying down |
| 10.200 | R4 | 98, 45 | 43.6, 50.7 | down 1.0%H/f | |
| 10.233 | R5 | 97, 47 | 43.7, 50.7 | down 0.9%H/f | |
| 10.267 | R6 | 95, 50 | 43.7, 50.9 | down 1.1%H/f | |
| 10.300 | D1 | 85, 52 / edge 91.0 | 43.9, 50.7 | the world starts sliding left | LUNGE starts |
| 10.333 | D2 | 78, 52 / 83.4 | ~44, 52 | | step −7.6%W (from the edge) |
| 10.367 | D3 | 73, 56 / 79.1 | ~44, 52 | | −4.3 |
| 10.400 | D4 | 70, 58 / 74.0 | ~44, 53 | | −5.1 |
| 10.433 | D5 | 60, 56 / 67.6 | ~44, 53 | | −6.4 |
| 10.467 | D6 | 57, 58 / 62.5 | ~44, 53 | | −5.1 |
| 10.500 | D7 | 55, 58 / 57.2 | ~44, 53 | | −5.3, ARRIVAL |
| 10.533 | +1 | 52, 58 / 56.4 | ~44, 53 | | −0.8: stopped dead; M1s begin (cyan glints) |
| 10.567 | +2 | 53, 60 / 57.6 | | | |

- **The re-aim:** 6 frames (10.10-10.27, 0.20 s). It starts 9 frames (0.30 s) after the target left frame.
  - Speed: 1.4 → 3.0 (peak at frame 2) → 2.6 → 1.0 → 0.9 → 1.1 %H/f. A fast start that eases out.
  - It turns just far enough to put the target at the right edge (95-98% x), then hands over to the lunge.
- **The lunge:** 7 frames (10.30 → 10.53, 0.23 s). The camera is locked to the attacker: he stays at 43-44% x, 51-53% y,
  and the world slides toward him.
  - The target closes from the edge to about 13% W from him.
  - Speed: about 5-6%W/f, nearly constant once on screen, then a dead stop in one frame (−5.3 → −0.8). There is no
  ease-in into the stop.
  - The first M1 lands 1 frame after the stop.
- **Gaps:** finisher → knockback start: 9 frames. Target off-frame (9.80) → re-aim start (10.10): 9 frames. Re-aim end →
  lunge start: 0-1 frames. Lunge stop → first hit: 1 frame.
- **What sells the distance:**
  - An afterimage chain behind the attacker (4-6 purple copies at 8.90-9.10, fading out by 9.20).
  - The white-cyan streak spraying from the target to the far side during the hold. It shows the flight direction
    before the flight starts.
  - The target leaving frame entirely. The lunge itself has no effect; the world sliding past is the only cue.

---

## 3. Garou vs Stinger (anime), pc7b7_unix8, 60 fps upload (drawings held 2-7 frames)

### D + A: arrival smear and the loaded lunge (11.28-11.88). Side-on wide, camera locked (≤0.4%W/f)

| t (s) | held for (f @60) | Garou | Glasses (target) | notes |
|---|---|---|---|---|
| 11.283 | 2 | not in frame | standing, centre 45, 50; 85% tall; head 53, 12 | |
| 11.317 | 2 | a brown streak smear at 82-100% x, 30-80% y | same | DASH (smear) |
| 11.350 | 2 | smear at 85-100% x | same | |
| 11.383 | 2 | ARRIVED, already in a deep coiled lunge: body 66-99% x, 15-90% y; hair x 77 | same | |
| 11.417-11.517 | 2-4 | hair x 77 | same | |
| 11.550-11.617 | 2 each | hair x 75-76 | same | creep 1 |
| 11.650-11.850 | 2-4 | hair x 70-72 | same | creep 2 |
| 11.883 | 2 | release: hair 59-64; white radial burst | punched at ~50, 50 | STRIKE |

- **The dash:** 2 smear images (4 frames at 60 = 0.07 s, about 2 frames at 30). He goes from off-screen right to about
  80% x and arrives already loaded. No decelerating approach is drawn; the smear replaces the travel.
- **Arrival to strike:** 0.50 s (15 frames at 30). The hold is not still: he creeps forward 6% W in two steps (77 → 75 →
  71) and leans in. The head-to-head gap shrinks from 24% W to 17% W. Then the release closes the gap in 1 image.

### L: knockback and flight (11.88-13.07): one knockback shown from 3 cameras

- **Side view, camera locked (11.883-12.10):** Glasses' centre x 50 → 47 → 42 → 33 → 30 → gone. The image timings are
  2, 5 (a held, blurred image), 2, 2 and 2 frames at 60. He exits frame left within 0.22 s of the strike, as a green
  ghost smear under white radial streaks. Garou holds his follow-through at about 60-67% x.
- **Grey impact frames 12.25-12.38** (4 images), then a green extreme close-up of his front at 12.38-12.63 (0.25 s). It
  recedes: the background appears at both sides at 12.50, with the body about 70% of the width.
- **Flight from behind, toward a tree at frame centre (12.633-13.00, 0.37 s).** The camera drifts ≤0.4%W/f in the first
  5 images and is locked after 12.83. Body height (head to feet) and position:

| t (s) | held (f @60) | height % | head x,y | note |
|---|---|---|---|---|
| 12.633 / 12.683 / 12.717 | 3, 2, 2 | 75 | 53, 29 | spread-eagle, feet at the bottom corners |
| 12.750 | 2 | 57 | 54, 33 | |
| 12.783 / 12.817 | 2, 2 | 53 | 53, 34 | |
| 12.850 / 12.883 | 2, 3 | 42 | 53, 36 | |
| 12.933 | 4 | 40 | 54, 36 | |
| 13.000 | 2 | 29-33 | 53, 35 | HITS THE TREE: legs fold, white impact lines; held afterwards |

- **Relative distance from the lens** (height⁻¹, normalised): 1.00 → 1.32 → 1.42 → 1.79 → 1.88 → about 2.4 at the
  tree.
  - The size steps shrink (−18, −4, −11, −2 %), so it eases out toward the tree.
  - The body stays dead centre (53-54% x) the whole way.
  - Black speed lines converge on the centre. The tree marks where he will stop.

---

## 4. Timing model (numbers to copy)

| beat | Azure Flames (closest) | TSB | Garou (anime) | ours now |
|---|---|---|---|---|
| hold after the launching hit | 0 f (pops at once) | 9 f / 0.30 s, target still | ~1 f, then a held blur | 0.25 s |
| launch shape | rise steps −27, −19, −6, −3, −2 %H: 80% in 2 f, settled in 5 f (0.17 s) | screen speed peaks at f3-4 (~5%W/f), then eases to ~1%W/f; off-frame after 17 f | exit in 0.22 s; the re-shown flight eases into the tree in 0.37 s | 0.34 s, up and back, flipping |
| where the target stops | top-right corner: 80-90% x, 12-17% y | out of frame | dead centre (on the tree) | - |
| camera during the flight | hidden under the burst (tilting up) | still; follows only 0.3-1%W/f | locked | whips up |
| launch end → dash start | 13 f (0.43 s), the coil being the last 7 | 15 f (0.50 s), including a 6 f re-aim | - | - |
| coil / load | 7 f (0.23 s), deepest on the last frame | none (a turn) | arrives already loaded | 0.17 s |
| dash | 7 f (0.23 s), take-off → contact | 7 f (0.23 s) | 2 smear images (~0.07 s) | 0.57 s, decelerating |
| arrival | no stop: the contact IS the hit; carries on up 2 f | dead stop in 1 f, hit 1 f later | arrives loaded, creeps 6%W over 0.5 s, then the release | stop below, still 0.26 s, then the punch |
| camera in the dash | already panning ~3%W/f in the coil; holds it (plus a 3-4%H/f tilt) through D1-D5; settles in 1-2 f, 2-3 f before contact; fast tilt up after the hit | locked to the attacker; the world slides 5-6%W/f, dead stop | locked off | low behind, panning with him |
| subjects in frame | attacker lower-left (25-38% x, 41-60% y, big then shrinking); target parked at 59-63% x, 18-30% y | attacker fixed at 43-44% x, 51% y; target enters from the right edge | target left-centre, attacker enters from the right | - |

### The rules these numbers give

1. **The dash is short; the waiting happens before it.** The Roblox references dash in 7 frames (0.23 s). The anime
   dash is a 2-image smear. Ours (0.57 s) is about 2.5x longer. The time each reference spends waiting goes into the
   coil (0.23 s), into a re-aim before the dash, or into a loaded, creeping pose. None of them waits after a soft stop.
2. **No reference decelerates into a gentle stop below the target.** Azure Flames hits straight through and carries on.
   TSB stops dead in 1 frame and hits on the next frame. If we keep our 0.26 s hold, make it a loaded pose that creeps
   (Garou: about 6% W over 0.5 s, in 2 steps). Don't make it a dead-still stop.
3. **The camera leads.** In Azure Flames it is already moving in the first coil frame, at the same speed it keeps
   through the dash (about 3%W/f). It does not ease in. It decelerates over 1-2 frames and is still 2-3 frames before
   contact.
4. **Park the target.** For the last third of the dash it is held still at 59-61% x, 18-20% y (upper-right third). The
   attacker's on-screen progress is withheld at first: he recedes into depth (36% → 10% tall) while the camera keeps
   him at 30-38% x. Then he crosses the last ~20% W in 2-3 frames onto the still target.
5. **The launch eases out hard.** Most of the rise happens in the first 2 frames. It settles by frame 5 (Azure Flames),
   or peaks at frame 3-4 and then eases (TSB). The target ends in a corner or in the upper third, small: about 15-20%
   of frame height, or half the attacker's apparent height.
6. **Time the re-aim between beats, not during them.** TSB holds the camera still through the hit and the flight. It
   re-aims for 6 frames with a fast start and an ease-out, after the target has left. The aim stops with the target
   just inside the frame edge, and the move hands straight over to the lunge.
