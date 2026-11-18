# 12b - Launch and dash, measured frame by frame

Three references, read only inside the given windows, to retime our ultimate's launch + dash (uppercut lands 3.84,
target flies up/back 0.34 s, cut to a low camera behind the attacker, crouch 0.17 s, take-off 4.43, dash 0.57 s,
hold 0.26 s, punch). Orientation came from the window sections of `09-jotaro-vs-dio.md`, `04-human-battery.md` and
`05-acheron.md`; this file only adds numbers.

## Method

- All three files are 1280x720, 60 fps containers. Times are source seconds; "fr" = one 60 fps frame (16.7 ms).
- Sheets: frames stamped with their source time and a 10 % grid (cyan lines every 10 % of width and height), so
  positions are read as % of frame width (x, from the left) and height (y, from the top). Body "centre" = middle of
  the visible body (torso), unless a head or fist is named. Read precision about +-2-3 % for big bodies, +-3-4 % for
  small or blurred ones. "Size" = the body's visible height as % of frame height.
- Cuts and drawing changes: ffmpeg `scdet` change score per frame (score above ~5 = new drawing or cut, 0.0x = held).
- Camera motion: `vidstabdetect` (shakiness 10, accuracy 15, ASCII .trf) on a crop that holds only background, then
  the median of all local motion fields per frame. The .trf vector is the inverse of the screen motion; numbers below
  are given as the BACKGROUND's screen shift (+x = content moves right = camera pans left; +y = content moves down =
  camera tilts up). Shifts are given in % of full frame width (1280) and height (720).
- Unreliable: any frame with a full-screen flash, smear, white-out or with only speed lines as background (anime
  launch and dive shots: there is no environment, so camera motion there is judged only from subject scale/position
  and is marked "inferred").
- Anime (Jotaro) is drawn at ~20-24 drawings/s inside a 60 fps file: a drawing holds 2-3 frames (sometimes 4-5), so
  its motions are steps; per-frame speeds below are averages over each drawing's hold.

## 1. Jotaro vs DIO (anime, sUmnKwt9uyA)

Sheets: `ld-b/jd_B_pre_30.jpg` (4.10-4.65 at 30 fps), `jd_A_launch_60.jpg` (4.65-5.13, every frame),
`jd_C_launch_drawings.jpg` (each launch drawing at 640 px), `jd_D_roof_20.jpg` (6.00-7.15 at 20 fps = every drawing),
`jd_E_roof_big.jpg` (rooftop drawings at 640 px), `jd_F_dive_30.jpg` (9.40-10.03 at 30 fps). Camera on the rooftop:
vidstabdetect on the bottom 340 px (city blocks; the dust and the sign are above it).
Launch and dive shots have only animated speed lines behind the bodies: camera motion there is inferred.
Target = Jotaro (green coat, cap). Attacker = The World (purple).

### 1a. Coil, strike, launch (4.65-5.03): one mid side shot, then a cut

| Event | Source time | Frames | Seconds |
|---|---|---|---|
| Pre-hold (lull, both nearly still, drawings every ~5 fr) | 4.250-4.650 | 24 | 0.40 |
| C coil: The World twists its torso | 4.667 | 1 | 0.017 |
| S contact: fist in his stomach, white spark | 4.683-4.767 | 5 (2 drawings) | 0.083 |
| L launch: he is torn off the fist and out of frame left | 4.783-4.917 | 8 | 0.133 |
| Follow-through: The World alone, rotating ~180 deg | 4.933-5.017 | 6 | 0.10 |
| Cut to the next shot (face close-up in flight, 1.0 s) | 5.033 | - | - |

Per frame (target = his head / cap; attacker = torso centre). Values hold for the whole drawing.

| t | Drawing | Target head x,y (%) | Target dx per fr (%W) | Target size (%H) | Attacker x,y (%) | Note |
|---|---|---|---|---|---|---|
| 4.650 | lull | 36, 16 | 0 | ~90 visible (cap to frame bottom) | 72, 60 | pre-hold |
| 4.667 | coil | 36, 16 | 0 | 90 | 72, 60 (back turned) | twist, the only wind-up |
| 4.683 | contact 1 | 26, 20 | -10 (one-frame jolt) | 90 | 68, 55 | spark at his stomach (32, 48) |
| 4.700 | " | 26, 20 | 0 | | 68, 55 | |
| 4.717 | " | 26, 20 | 0 | | 68, 55 | |
| 4.733 | contact 2 | 33, 9 | +7 (folds over the fist, head forward/up) | 85 | 70, 55 | spark grows to x 15-40 |
| 4.750 | " | 33, 9 | 0 | | | |
| 4.767 | " | 33, 9 | 0 | | | |
| 4.783 | launch 1 | 13, 17 | -20 in one step (=6.7/fr over the hold) | ~60 (bent, arms up) | 60, 55 (stretched x 20-100, fist chasing at x 20) | launch frame 1 |
| 4.800 | " | 13, 17 | 0 | | | |
| 4.817 | launch 2 | 12, 18 | -1 (near hold) | ~60 | 60, 55 | |
| 4.833 | " | 12, 18 | 0 | | | |
| 4.850 | " | 12, 18 | 0 | | | |
| 4.867 | launch 3 | 4, 22 | -8 (=2.7/fr) | ~50, partly off left | 65, 55 (leg up right) | |
| 4.883 | " | 4, 22 | 0 | | | |
| 4.900 | " | 4, 22 | 0 | | | |
| 4.917 | launch 4 | 2, 40 (half off) | -2, drops +18 %H | coat only | 55, 60 (rotating) | he is out by here |
| 4.933-5.017 | follow-through | off frame left | - | coat tail x 0-35 | 55-58, 60 | The World turns ~180 deg |

Shape of the launch: a one-frame jolt at contact (-10 %W), a 3-frame fold forward over the fist (+7), then one big
step (-20 %W) and a short ease (-1, -8, -2) as he leaves the frame left and slightly down. He leaves frame
**8 frames (0.13 s) after the launch starts**; total screen travel ~36 %W (36 -> 0). The shot stays on the attacker for
6 more frames, then cuts. Nothing stops on screen: the launch ends by exiting frame.

Camera: no environment, only animated speed lines (diagonal, top-right to bottom-left, parallel to the launch).
Inferred static framing that holds on the ATTACKER: The World drifts 72 -> 55 %W (~0.5 %W/fr) with its lunge,
scale unchanged; the target is allowed to leave. Things that sell the force: the spark (5 fr), speed lines, the
attacker's 180-degree follow-through; the target is never small in this shot (it is a mid shot, both ~90 %H).

### 1b. The flight across the rooftop (6.03-7.10): wide shot, camera pans late and lets him exit

| Event | Source time | Frames | Seconds |
|---|---|---|---|
| Cut in: empty rooftop with the sign, camera nearly still | 6.033-6.183 | 10 | 0.17 |
| He enters at the top-right corner | 6.200 | - | - |
| Crosses into the sign (dust burst from 6.45) | 6.30-6.50 | 12 | 0.20 |
| Pan left + tilt down after him | 6.383-6.933 | 33 | 0.55 |
| He exits frame left, low | ~7.05-7.08 | - | - |

Target positions (body centre; drawings every 3 fr, so read at 20 fps):

| t | Target x,y (%) | dx/dy per 0.05 s (%) | Size (%H) | Note |
|---|---|---|---|---|
| 6.20 | 95, 3 (mostly off, top-right corner) | - | partial | entry |
| 6.25 | 97, 2 | - | partial | |
| 6.30 | 75, 15 | -22, +13 | 33 (diagonal, x 60-90) | fast entry |
| 6.35 | 76, 20 | +1, +5 | 33 | near hold (hits the sign) |
| 6.40 | 56, 28 | -20, +8 | 37 (vertical pose) | |
| 6.45 | 49, 32 | -7, +4 | 35 | dust burst behind him, x 55-75 |
| 6.50 | 49, 30 | 0, -2 | 37 | screen hold while the camera pans |
| 6.55 | 44, 33 | -5, +3 | 40 | |
| 6.60 | 38, 33 | -6, 0 | 40 | |
| 6.70 | 22, 32 | -8 per 0.05 | 33 | |
| 6.80 | 17, 30 | -2.5 per 0.05 | 27 | |
| 6.90 | 12, 30 | -2.5 per 0.05 | 24 | |
| 6.95 | 8, 40 | -4, +10 | 22 | dropping |
| 7.00 | 5, 45 | -3, +5 | 20 | |
| 7.05 | 4, 50 | -1, +5 | partial | exiting |

Screen speed shape: very fast entry (-22 %W in 3 fr = 7 %W/fr), a hold at the sign (6.30-6.35 and 6.45-6.50),
then 1-2 %W/fr while the camera follows, slowing to 0.5-0.8 %W/fr as the pan peaks, then drops out bottom-left.
His size stays 33-40 %H through the crossing and falls to ~20 %H as he leaves (moving away).

Camera (background shift, vidstab on the city blocks; content moves right/up = camera pans left/tilts down):

| Window | Frames | Pan (%W per fr) | Tilt (%H per fr) | Phase |
|---|---|---|---|---|
| 6.033-6.083 | 3 | 0 | 0 | still |
| 6.10-6.367 | 16 | 0.17 (10 %W/s) | 0.19 | slow drift before he arrives |
| 6.383-6.467 | 6 | 0.61 | 0.5 | ramp-up (starts as he hits the sign) |
| 6.483-6.850 | 23 | **0.73 (44 %W/s)** | **0.86 (52 %H/s)** | plateau |
| 6.866-6.933 | 5 | 0.33 | 0.37 | settle |
| 6.95-7.12 | 10 | <0.08 | +-2 jitter, net 0 | still |

The camera moves on the same 2-3 frame drawing steps (about 23-26 px per step at the plateau). Total: pan ~22 %W,
tilt ~25 %H in 0.55 s, ramp ~0.1 s, plateau ~0.37 s, stop ~0.08 s, no overshoot. It starts 0.18 s after he
appears and stops 0.12 s BEFORE he exits: the camera trails him and lets him run out of the left edge. While it
moves he sits at 15-50 %W (no leading room ahead of him: the space is behind him, filled by the dust).

### 1c. The chase dive at the lens and the strike (9.40-10.07)

| Event | Source time | Frames | Seconds |
|---|---|---|---|
| D dive close (continues from 8.65): The World head-first at the camera | 9.40-9.617 | 13 | 0.22 |
| Turns side-on and drives the arm at the lens; push along the arm | 9.633-9.800 | 11 | 0.18 |
| Smear wipe: the shoulder passes the lens as a pale blur | 9.817-9.883 | 5 | 0.083 |
| Hard cut: he lies upside down; the fist arrives blurred from the top | 9.900-9.933 | 3 | 0.05 |
| S contact: fist on his cheek | 9.950-9.967 | - | - |
| Contact hold (drawing held, speed lines move) | 10.00-10.45 | ~27 | 0.45 |

| t | Attacker (The World) | Size | Note |
|---|---|---|---|
| 9.40-9.45 | head 45, 18; body x 38-100 | head ~25 %H, body fills frame | slow roll |
| 9.467-9.533 | head 46, 22 | head ~25 %H | |
| 9.55-9.617 | head 58, 45, face to camera | head ~45 %H | jump in scale x1.8 in one drawing |
| 9.633 | side-on; arm reaching left x 0-55, y 25-75; head 82, 28 | arm ~50 %H | the reframe for the arm |
| 9.667-9.733 | arm blurred in foreground x 0-60; yellow shoulder pad 62, 75 | pad ~30 %H | |
| 9.750-9.767 | pad 45, 55 | pad ~75 %H | |
| 9.783-9.800 | pad 45, 65 | pad ~80 %H | |
| 9.817-9.883 | shoulder fills frame, pad at 85-90, 25-30 | >100 %H | smear wipe |
| 9.900 | CUT; his face upside down 40, 70 (face ~40 %H); fist blur at 45, 10 | | |
| 9.933 | fist blur 42, 28 | | +18 %H in 2 fr |
| 9.950-9.967 | fist 50, 38 on his cheek | | +10 %H, then stop = contact |
| 10.00-10.03 | fist 48, 40 held | | contact hold |

Shape: the dive does not slow down. The attacker's scale grows x3-4 in 9 frames (pad 30 -> 80 %H, 9.667-9.800)
and the shot ends by the body passing the lens (smear), then a cut to the target, where the fist covers the last
~30 %H in 3 frames and stops dead on contact. Camera: speed lines only, so "push" vs "he flies at us" can't be
separated; inferred push along the arm (the pad slides 62 -> 45 %W while growing). Gap dash end -> contact:
**smear 5 fr + cut + 3 fr = 9 frames (0.15 s)**, no hold between arrival and strike: the arrival IS the strike.

## 2. Human Battery (Roblox, C2vCVdNRLms)

Sheets: `ld-b/hb_A_dash1_60.jpg` (17.40-17.88, every frame), `hb_B_dash2_60.jpg` (17.90-18.48, every frame),
`hb_C_skyline_strip.jpg` (top 28 % of the frame, 17.50-18.08, every frame: for tracking the background),
`hb_D_launch_60.jpg` (20.00-20.38, every frame), `hb_E_launch_big.jpg` (20.08-20.27 at 640 px).
The capture repeats a frame now and then (change score ~0.1 at 17.867, 17.933, 20.15, 20.217): treat those as holds.
Camera in the dash: the runner fills half the frame and lightning covers most frames, so vidstab and a 1-D profile
tracker both gave noise (match quality poor). The pan was measured by hand from one distant landmark, a tower with
a lit brazier, tracked frame by frame in the skyline strip. Degrees assume Roblox's default 70-degree vertical FOV
(about 102 degrees horizontal at 16:9); treat them as +-25 %. Camera in the target and launch shots: vidstab on
background-only crops (left third; top strip).
Attacker = the runner (green, gauntlet). Target = the yellow dummy with red gloves.

### 2a. The dash (17.40-18.10) and the way in to the strike (18.10-18.47)

| Event | Source time | Frames | Seconds |
|---|---|---|---|
| Two-shot from behind-left (end of the charge) | 17.40-17.42 | 2 | 0.03 |
| Take-off: yellow white-out, camera now tight behind him | 17.433-17.483 | 4 | 0.067 |
| D dash: tracking shot orbiting from his back to his front | 17.50-18.10 | 36 | 0.60 |
| Star-flash cut (flare 2 fr, black frame 1 fr, flare fading over the new shot 2 fr) | 18.117-18.20 | 5 | 0.083 |
| Target turns to camera (low, close) | 18.20-18.42 | 14 | 0.23 |
| Arm enters from lower right, camera rolled 15-20 deg | 18.433-18.45 | 2 | 0.033 |
| S contact white-out | 18.467 | - | - |

Per frame, the runner (head = brown hair, size = visible height) and the background (brazier tower x):

| t | Runner head x,y (%) | Runner size (%H) | Seen from (orbit angle, 0 = his back) | Brazier tower x (%) | Note |
|---|---|---|---|---|---|
| 17.400 | body 22, 45 | 100 | behind-left two-shot | - | target far right ~77, 33, ~25 %H |
| 17.433-17.483 | (torso 45-50, 30) | - | - | - | white-out, unreliable |
| 17.500 | torso 30, 50 | >100 | 0 (back) | - | tight behind |
| 17.517 | torso 30, 50 | >100 | 0 | - | yellow speed lines |
| 17.533 | torso 45, 50 | >100 | ~20 | - | |
| 17.550 | torso 45, 55 | >100 | ~30 | - | |
| 17.567 | 60, 25 | 100 | ~45 | - | |
| 17.583 | 65, 20 | 100 | ~45 | - | |
| 17.600 | 45, 20 | 100 | ~60 | (entering right) | |
| 17.617 | 50, 22 | 95 | ~70 | ~97 | |
| 17.633 | 40, 30 | 90 | ~90 (his side) | - | gauntlet at left 15, 40 |
| 17.650 | 45, 25 | 90 | 90 | 75 | |
| 17.667 | 45, 30 | 90 | 95 | 69 | |
| 17.683 | 50, 30 | 90 | 100 | 63 | |
| 17.700 | 40, 35 | 85 | 105 | (lightning) | |
| 17.717 | 45, 35 | 85 | 110 | - | |
| 17.733 | 55, 40 | 75 | 120 | - | |
| 17.750 | 55, 40 | 75 | 125 | - | |
| 17.767 | 55, 40 | 75 | 130 | - | |
| 17.783 | 65, 40 | 70 | 135 | 39 | |
| 17.800 | 45, 45 | 65 | 140 | - | smallest he gets |
| 17.817 | 45, 45 | 65 | 145 | 34 | |
| 17.833 | 48, 45 | 65 | 145 | 32 | |
| 17.850 | 48, 45 | 65 | 150 | 28 | |
| 17.867 | 60, 45 | 65 | 150 | 25 | repeated frame |
| 17.883 | 55, 45 | 65 | 150 | 24 | |
| 17.900 | 52, 30 | 70 | 155 | 20 | |
| 17.917 | 65, 30 | 75 | 160 | 17 | |
| 17.933 | 65, 30 | 75 | 160 | 13 | repeated frame |
| 17.950 | 62, 30 | 75 | 165 | 6 | |
| 17.967 | 65, 32 | 80 | 165 | 5 | |
| 17.983 | 68, 35 | 85 | 170 | 1 | tower leaves frame |
| 18.000 | 45, 30 | 110 | ~175 (front) | - | |
| 18.017 | 45, 30 | 110 | 175 | - | |
| 18.033 | 45, 35 | 115 | 175 | - | |
| 18.050 | 55, 40 | 120 | 180 | - | |
| 18.067 | 55, 40 | 130 | 180 | - | |
| 18.083 | 60, 30 | ~150 | 180 | - | lunges at the lens |
| 18.100 | 35, 35 | >150 | 180 | - | fills the left half |
| 18.117 | - | - | - | - | star flare (cut) |

Background (camera) speed from the tower, converted to yaw with the FOV assumption:

| Window | Frames | Tower moves (%W per fr) | Camera yaw (deg per fr) |
|---|---|---|---|
| 17.50-17.60 | 6 | not measurable (VFX, body fills frame) | orbit ~45 deg done by 17.57 from his facing |
| 17.65-17.683 | 2 | -6.0 | ~7 |
| 17.683-17.783 | 6 | -4.0 | ~5.5 |
| 17.783-17.883 | 6 | -2.5 | ~2.9 |
| 17.883-17.983 | 6 | -3.8 (faster near the edge) | ~3.0 |
| 17.983-18.10 | 7 | no landmark; he faces the lens and closes in | small |

Shape: the orbit is an EASE-OUT. From his facing, ~90 deg in the first 8 frames (~11 deg/fr), then 7 -> 5.5 -> 3
deg/fr, reaching his front (~170 deg) by 17.98, i.e. ~170 deg in 0.48 s; then 7 frames where the camera stays in
front and he runs into the lens (size 110 -> >150 %H). The runner is held in the middle of the frame the whole
way (head x 40-68 %, y 20-45 %): a locked follow, no leading room; his size dips to ~65 %H mid-orbit (the camera
drops back a little while swinging round) and grows again at the end. The target is not on screen during the dash.

The target-turn shot (18.20-18.42), camera (vidstab, left third of the frame; content moving left = arc to the right):

| t | 18.217 | 18.233 | 18.250 | 18.267 | 18.283 | 18.300 | 18.317 | 18.333 | 18.350 | 18.367 | 18.383 | 18.400 | 18.417 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| %W per fr | 0.1 | 0.1 | 0.3 | 0.4 | 0.8 | 0.8 | 0.5 | 1.4 | 1.3 | 0.8 | 2.3 | 0.8 | 1.7 |

It starts almost still and speeds up into the hit (an ease-in of ~1.5-2 %W/fr by the arm's entry). The target sits
centre-right (torso 52-55, 60), size ~100 %H (glove top at y 10-20 %), turning 180 degrees in 12 frames
(back to camera at 18.217, square-on guard at 18.40). The arm then enters in 2 frames with the roll.

Gaps: take-off flash -> dash 4 fr; dash end (18.10) -> contact (18.467) = **22 frames (0.37 s)**: flash cut 5 fr,
target turn 14 fr, arm entry 2 fr. What sells speed/distance in the dash: yellow vertical speed lines (17.517),
lightning streaming back, the background whipping past at 3-6 %W/fr, and the final lunge into the lens.

### 2b. The launch on a cut (20.083-20.30)

| Event | Source time | Frames | Seconds |
|---|---|---|---|
| (end of the 98-frame hit-stop: card white-out, 20.00-20.067) | | | |
| Launch frame: radial black speed lines, diagonal yellow beam | 20.083 | 1 | 0.017 |
| L flight straight at the lens in a static low wide shot | 20.100-20.250 | 10 | 0.167 |
| Hits the lens: white flash + crescent ring | 20.267-20.300 | 3 | 0.05 |
| End card (face pressed on the cracked lens) | 20.317- | - | - |

| t | Target centre x,y (%) | Target size (%H) | Attacker x,y / size | Camera |
|---|---|---|---|---|
| 20.083 | 56, 50 (silhouette in the speed lines) | ~10 | hidden | - |
| 20.100 | 52, 54 (glowing) | 25 | 62, 57 / 20 | still |
| 20.117 | 52, 53 | 28 | 62, 57 | still |
| 20.133 | 52, 52 | 30 | 62, 57 | still |
| 20.150 | 52, 52 | 30 (repeated frame) | 62, 57 | still |
| 20.167 | 47, 50 | 35 | 63, 55 | still |
| 20.183 | 51, 52 (airborne, shadow on the floor at y 85) | 47 | 63, 58 | still |
| 20.200 | 50, 53 | 60 | 63, 55 | still |
| 20.217 | 50, 53 | 60 (repeated frame) | 63, 55 | still |
| 20.233 | 47, 60 | >80 (cut by the bottom) | 64, 60 (behind it) | still |
| 20.250 | 50, 60 (head alone ~80 %H) | ~200 | hidden | still |
| 20.267 | lens hit flash | - | - | - |

Camera: locked (vidstab on the skyline strip: <=1 px per frame). The target stays dead centre (x 47-52 %) and grows
25 -> 200 %H in 9 frames: x1.2 per frame at first, x1.3-2 per frame at the end (the hyperbola of a constant-speed
flight at the lens). The attacker stays where he punched, 20 %H, fist out. Distance is sold by the start size
(25 %H, beside the attacker), the floor tiles and the shadow separating from the body, then the lens hit.
Gap: contact 18.467 -> launch 20.083 = 97 frames of hit-stop; launch frame -> lens = 11 frames (0.18 s).

## 3. Acheron (Roblox, 3KIzXAukn5I)

Sheets: `ld-b/ach_B_pre_30.jpg` (3.47-3.93 at 30 fps), `ach_A_dash_60.jpg` (3.95-4.43, every frame),
`ach_C_dash_big.jpg` (each distinct frame at 640 px). The capture repeats a frame every ~5 frames (4.033, 4.10, 4.183,
4.233, 4.317, 4.40) and the wind-up updates only every 4 frames (3.43-3.90): numbers below are per 60 fps frame.
Camera: a 1-D column-profile tracker on the top 300 px (galaxy skybox + the white arc; match quality good except
in the smear frames) gives the PAN; vidstab on the water band (bottom 220 px) gives the ROLL as the slope of vertical
motion across the frame (the water band's own horizontal motion is polluted by the roll, so it is not used for pan).
Attacker = Acheron (white hair). Target = the green avatar under the arc.

| Event | Source time | Frames | Seconds |
|---|---|---|---|
| C load: she stands, sword trailing low behind her (held) | 3.80-4.00 | 12 | 0.20 |
| Vanish: red petal puff where she stood; she is invisible | 4.017-4.15 | 9 | 0.15 |
| Camera starts panning right and rolling | 4.05 | - | - |
| Smear: white motion-blurred body passes very close to the lens, red beams; flare on the target | 4.167-4.25 | 6 | 0.10 |
| A arrival: crisp, back to camera, past the target, sword up (held follow-through) | 4.267-4.82 | 33 | 0.55 |
| Camera settled | 4.40 | - | - |

Per frame (target = body centre; attacker = body centre; pan = skybox shift, content moving left = camera pans right):

| t | Attacker x,y / size (%) | Target x,y / size (%) | Puff x,y | Pan (%W per fr) | Roll (deg per fr) | Note |
|---|---|---|---|---|---|---|
| 3.950 | 22, 50 / 95 | 63, 55 / 25 | - | 0 | 0 | loaded pose |
| 4.000 | 22, 50 / 95 | 63, 55 | - | 0 | 0 | |
| 4.017 | gone | 63, 52 | 28, 42 (35 %H) | 0.3 | 0.1 | puff appears, 1 fr |
| 4.033 | - | 63, 52 | 28, 42 | 0 (repeat) | 0 | |
| 4.050 | - | 61, 54 | 26, 43 | 1.25 | 0.9 | camera starts, 2 fr after the puff |
| 4.067 | - | 59, 55 | 23, 45 | 3.4 | 1.5 | |
| 4.083 | - | 56, 55 | 18, 50 | **4.7** (peak) | 0.7 | |
| 4.100 | - | 56, 55 | 18, 50 | 0 (repeat) | 0 | |
| 4.117 | - | 52, 54 | 12, 60 | 4.5 | 0.9 | horizon tilted ~4 deg |
| 4.133 | - | 49, 54 | 10, 65 | 4.5 | 0.3 | |
| 4.150 | - | 45, 54 | 8, 70 | 4.2 | 0.7 | horizon ~6-7 deg |
| 4.167 | smear 50, 50 / >100 | hidden | - | (5.5, unreliable) | - | smear 1 |
| 4.183 | smear | hidden | - | 0 (repeat) | - | |
| 4.200 | smear 45, 55 / >100 | hidden | - | unreliable | - | flare on the target |
| 4.217 | smear 60, 58 | - | - | unreliable | - | |
| 4.233 | smear | - | - | 0 (repeat) | - | |
| 4.250 | 75, 60 / ~95, streaked | flare 40, 55 | 3, 80 | unreliable | - | |
| 4.267 | 79, 62 / 95, crisp | 39, 54 | lingering bottom-left | (0.6) | - | arrival |
| 4.283 | 73, 62 / 95 | 38, 52 | | 1.6 | 1.2 | |
| 4.300 | 72, 62 | 38, 52 | | 1.1 | 0.7 | |
| 4.333 | 72, 62 | 38, 52 | | 0.3 | 0 | |
| 4.367 | 72, 62 | 38, 52 | | 0.2 | 0 | |
| 4.400 | 72, 62 | 37, 52 | | 0 | 0 | camera still |
| 4.417 | 72, 62 | 37, 52 | petals fading | 0.1 | 0 | held pose to 4.82 |

Camera curve: still while she is loaded and for 2 frames after she vanishes; then a fast EASE-IN of 3 frames to a
peak of ~4.5 %W/fr (about 4.5 deg/fr = 270 deg/s with the FOV assumption), a ~5-frame plateau, the smear covers the
peak-to-decay hand-off, then a decay of ~1.6 -> 0.2 %W/fr over 6 frames, still by 4.40 (8 frames after she
reappears). Total pan ~30-35 %W (~35-40 deg). Roll: 0.7-1.5 deg/fr during the pan, horizon tilted ~7-8 deg at the
end (rising to the right: the camera banks into the turn) and KEPT tilted through the held pose.
The target (25 %H, no zoom) is dragged from 63 to 38 %W: the camera leads her direction of travel and leaves the
target left of centre so she can land in the right third (72 %W) with the target and the flare between her and the
left edge. Near objects move less than the skybox (target ~2.3-3.5 %W/fr vs sky 4.5): the camera arcs, not a pure
pan. She is never seen travelling: absence 9 fr + smear 6 fr = 15 frames (0.25 s) from vanish to arrival.
Gap: dash end (4.267) -> held pose; the hit IS the pass (flare at 4.20, before she reappears), then 33 held frames.
What sells it: the puff (1-frame appear, fades over ~25 fr, slides off bottom-left with the pan), the empty frame
with the camera already moving, the smear past the lens, and the starburst/flower flare on the small target.

## 4. Timing model (numbers to copy; fr = 1/60 s)

**Launch**

| | Jotaro (gut punch) | Human Battery (after hit-stop) |
|---|---|---|
| Wind-up before contact | 1 fr twist after a 24-fr near-still lull | (1.75 s charge, then the dash) |
| Contact on screen | 5 fr (jolt -10 %W in 1 fr, then 3-fr fold) | 1 fr contact flash, then 97 fr hit-stop |
| Launch frame | - | 1 fr radial speed lines + beam |
| Target out of the shot | **8 fr (0.13 s)**: steps -20, -1, -8, -2 %W per drawing = big kick then ease; exits frame left/down | **10 fr (0.17 s)** to the lens: centred, 25 -> 200 %H, growth speeds up at the end |
| Camera during the launch | holds on the attacker (inferred still; attacker drifts ~0.5 %W/fr) | locked still (<= 1 px/fr) |
| After | 6 fr of the attacker's follow-through, cut; 1.0 s close-up "in flight"; 3.05 s of flight shots (5.03 -> 8.08, ~183 fr) before the chase starts | 3-fr lens-hit flash, 2.2 s end card |

Neither reference moves the camera inside the launch shot itself: the target leaves a still frame. Camera following
comes in a separate wide shot (Jotaro rooftop): still 10 fr, target enters at a corner at ~7 %W/fr, camera starts
0.18 s later, ramps in 0.1 s to a plateau of **0.73 %W/fr pan + 0.86 %H/fr tilt** for 0.37 s, stops in ~0.08 s
with no overshoot, 0.12 s BEFORE the target leaves frame; total ~22 %W pan, ~25 %H tilt; the target stays 33-40 %H.

**Dash**

| | Human Battery | Acheron | Jotaro dive |
|---|---|---|---|
| Load / take-off | 4-fr white-out after the charge | 12 fr held load pose, then a 1-fr puff | (from earlier shots) |
| Dash on screen | 36 fr (0.60 s) | 15 fr (0.25 s): 9 fr absent + 6 fr smear | arm at the lens 11 fr + smear 5 fr |
| Attacker on screen | locked mid-frame (head x 40-68 %), 65-150 %H, ends lunging into the lens | not seen travelling; reappears in the right third (72-79 %W), 95 %H | scale x3-4 in 9 fr, passes the lens |
| Camera move | orbit back -> front ~170 deg, EASE-OUT: ~11 -> 7 -> 5.5 -> 3 deg/fr (tower: 6 -> 4 -> 2.5-3.8 %W/fr) | pan right, EASE-IN 3 fr to 4.5 %W/fr, ~5 fr plateau, decay 6-8 fr to still; roll 0.7-1.5 deg/fr to ~7-8 deg, kept | inferred push along the arm |
| Camera start | with the take-off flash | 2 fr after the vanish (moves into the empty frame, leading her) | - |
| Dash end -> strike | 22 fr: 5-fr flash cut, 14-fr target turn (camera easing in 0.1 -> 2 %W/fr), 2-fr arm entry | 0: the hit is the pass (flare at 4.20) | 9 fr: 5-fr smear, cut, 3-fr fist |
| Hold | after contact: 97 fr hit-stop | after the pass: 33-fr held pose, camera still, roll kept | after contact: ~27-fr contact hold |

**What this says about our stretch** (ours: launch 0.34 s with the camera whipping up after it; cut; crouch 0.17 s;
dash 0.57 s decelerating into a stop; 0.26 s still hold; punch):

1. Launch: the references get the target out of a still frame in 8-10 frames; ours takes 20 frames and moves the
   camera during it. Copy: hold the camera, let the target clear the frame (or reach the lens) in ~8-10 fr with a
   big first step (~-20 %W in the first 3 fr) and an ease after.
2. Any camera follow of a flying body: start it 0.15-0.2 s after the body is in frame, ramp 0.1 s, plateau
   ~0.7 %W/fr, stop 0.1 s before the body exits. No whip.
3. Dash camera: either a locked follow that ORBITS with an ease-out (fast first, ~11 deg/fr, settling to ~3 deg/fr)
   with the attacker kept mid-frame (HB), or a camera that starts 2 fr after take-off and accelerates over 3 fr to
   ~4.5 %W/fr ahead of the attacker, with a 7-8 deg bank kept to the end (Acheron).
4. No reference decelerates the dash into a stop and holds before the strike. The arrival is the strike (Acheron,
   Jotaro) or is covered by a 5-fr flash cut to the target reacting (HB, 14 fr). The long holds come AFTER the
   contact (27-97 fr).
5. Gaps to copy: take-off flash/puff 1-4 fr; dash 15-36 fr; dash end -> contact 0, 9 or 22 fr; load pose 12 fr.

