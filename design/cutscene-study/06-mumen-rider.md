# 06 - "Mumen Rider Combo - Roblox VFX Showcase"

- YouTube id: 3R5WsLDp2f4. Length 8.57 s, 60 fps (511 frames), 1280x720.
- What it is: a Roblox Studio play-test recording (Studio toolbar, tabs "JBG" and "KickBarrage") of a close-range
  combo by an R6 character (black suit, white shirt, black tie, red flower on the left lapel, black hair, sunglasses)
  on a white R6 test dummy, on an empty baseplate. Not anime and not a cutscene: one fixed game camera, no cuts, no
  screen-space effects. Its value for us is the R6 punch poses, the target's hit poses and the impact timing.
- What I could see: every frame. The fighters are about 140 px tall in a 1280x630 viewport, so torsos, arm blocks,
  legs and the dummy's face direction are readable in 1:1 and 1.7x crops.
- What I could not see: the contact frames under the green bursts (each burst hides the dummy for 5 frames on the
  small hits, and for about 34 frames on the flying strike); everything inside the 1.35 s barrage vortex (5.77-7.10 s);
  the exact moment the dummy is driven to the ground; finger/fist shapes; audio. Where the camera is high, height
  and depth can't be separated (a body further back also sits higher on screen).
- Sheets studied: the 12 fps overview, then 30/60 fps 1:1 crops of every event, 1.7x zooms of the contact frames, and
  a horizon strip of all 511 frames (to measure camera motion).

## Summary (5 lines)

1. One locked high-angle wide shot for 8.57 s: no cut, no move, no shake, no FOV change, no flash (horizon strip
   identical in all 511 frames), so all of the impact comes from world-space effects and posing.
2. R6 punches are short: the arm is already raised in a guard (hand at chin height), and the hit is a 2-3 frame move
   of the arm block to horizontal at the target. The power comes from the torso turning and the body leaning in. The
   arm never swings round.
3. The dummy's chest faces the camera, turned 3/4 toward the attacker. Blows land on the belly and chest front from
   the attacker's side, and the hit pose folds the dummy forward ONTO the fist (doubled over toward the attacker).
4. Impact = a ground ring 1 frame before + a 2-frame white-green star burst + streaks pointing the way the blow goes.
   The big hit freezes both bodies for about 34 frames (0.57 s) while the spikes, streaks and rings keep animating,
   then the attacker drops and lands with a ring.
5. There is no launch, no rush and no knockback travel: the dummy stays on its spot and is finally driven down
   into the ground under the barrage. F2 and F3 are "not shown". F5: the hit pose appears within 1-2 frames, with
   no slow motion.

## A. Sequence and timing

| From-to (s) | Dur | What happens | Eye drawn to |
|---|---|---|---|
| 0.00-1.83 | 1.83 s (110 f) | Idle. Attacker stands pressed against the dummy's front-right, both still. | Nothing: two small figures centre-frame |
| 1.83->1.85 | 1 f | Pop: the attacker snaps into a new position and pose in front of the dummy. No anticipation frame. | The pop itself |
| 1.85-2.13 | 0.28 s | Lunge with the lead arm into the dummy's belly, rear arm chambered at the hip, rear leg stretched back. Held nearly still from 1.93 to 2.13 (12 f). Dummy upright, no reaction yet. | The lunge silhouette |
| 2.17-2.23 | 4 f | Attacker turns toward the camera and steps to the dummy's left side (screen right). | Turn |
| 2.23 | 1-2 f | Dummy pops into a hit pose: knees bent, arms flung out, torso folded forward toward the attacker; attacker's right fist low in its belly. | Dummy silhouette change |
| 2.30 | 1 f | White ground ring under the dummy (pre-impact pulse). | Ring |
| 2.317-2.47 | 9 f | Hit 1 burst: 2 frames of white-green star (2.317-2.333), green and black speed streaks pointing screen-left (the way the blow goes), sparks fade by 2.47. | Burst, covers the dummy 5 f |
| 2.48-2.58 | 6 f | Smoke and white crescent arcs swirl; both bodies hold their poses. | Arcs |
| 2.60-2.65 | 4 f | Wind-up for hit 2: the attacker's hand, raised near his head at 2.60, comes down-forward to chest height by 2.65. Ground ring under the dummy at 2.65. | Raised fist |
| 2.667-2.87 | 12 f | Hit 2 burst, same treatment as hit 1 (2 bright frames, streaks left, a green ring of sparks). | Burst |
| 2.90-3.07 | 10 f | Dummy straightens back to upright; attacker steps back into a stance. Arcs fade. | Recovery |
| 3.10-3.23 | 8 f | Anticipation: the attacker turns to face the camera and raises both arms to a boxer's guard (hands at chin). | Guard |
| 3.267 | 1 f | Ground ring at the attacker's feet: take-off. | Ring at the feet |
| 3.30-3.47 | 10 f | Hop and twist: knee comes up, the torso turns from facing the camera to facing the dummy (back to the camera), fist stays loaded by the shoulder. Head moves only about 25 px, under a fifth of a body height: almost in place. | Twisting body |
| 3.48-3.52 | 3 f | Strike: the arm goes to horizontal straight across the dummy's chest, the body leans almost horizontal, legs trail behind. Small white swirl at the contact point at 3.517. | Contact |
| 3.533-4.10 | ~34 f | Hit 3 burst and hold: both bodies frozen (drift under 10 px) while green spikes flicker, green and dark speed streaks stream out behind the attacker (screen right), and a green/white ring expands. | Burst |
| 4.10-4.27 | 10 f | Burst fades; the attacker drops out of the lean. | Drop |
| 4.30-4.75 | 27 f | Landing ring at the attacker's feet; crouched landing; white ground rings spread and fade. | Rings |
| 4.75-5.43 | 41 f | Quiet hold: attacker crouched beside the upright dummy. | Nothing much |
| 5.467-5.70 | 14 f | Take-off ring at the feet; the attacker rises above the dummy's head and crouches there, facing the camera, legs on the dummy's shoulders. | Rising figure |
| 5.717-7.10 | 1.38 s | Barrage: black speed lines from the upper left, then green slashes on the dummy (5.733), then a vertical white/green spinning disc around both (5.767 on). The attacker holds a crouch in its centre; the dummy sinks out of view below. | The disc |
| 7.10-7.37 | 16 f | Disc fades (black and white ring last). The attacker stands over the dummy, which lies crumpled on the ground. | Dummy on the ground |
| 7.40-7.60 | 12 f | Final stomp: big white ground shock ring and smoke at the attacker's feet. | Ring |
| 7.60-7.83 | 14 f | The dummy gets back up behind the attacker. | Dummy |
| 7.83->7.87 | 1-2 f | Reset pop to the idle positions from the start. | |
| 7.87-8.52 | 0.65 s | Idle (end of clip). | |

- **Anticipation**: short and pose-based. Before the flying strike there is an 8-frame turn into a guard (3.10-3.23),
  a 1-frame ring at the feet, then a 10-frame twist in the air. Before hit 2 there is a 4-frame hand movement. Hit 1
  has no visible build (the move starts with a pop at 1.83).
- **Release**: always in 2-3 frames (the arm block reaches the target), followed within 1-2 frames by the ring and
  burst.
- **Settle**: the effects carry the settle (smoke, arcs and rings expanding for 0.2-0.45 s); the bodies hold, then
  move to the next pose quickly.
- **Holds and hit-stop**: lunge hold 12 f (1.93-2.13); after hit 1, a body hold of about 11 f (2.40-2.58); the flying
  strike freezes both bodies for about 34 f (3.533-4.10); a crouch hold of 41 f (4.75-5.43); the barrage crouch for
  about 80 f. There is no slow motion anywhere: bodies either move at full speed or are held.
- **Read time**: each small hit reads in about 0.35 s (ring + burst + streaks); the flying strike needs about 0.25 s
  of build and holds for 0.57 s; the barrage is one 1.4 s block.

## B. Camera work

One shot, 8.57 s, no cuts.

- **Size and angle**: a wide shot. The fighters are about 22% of the viewport height, centred slightly below the
  middle; the horizon sits 28% down the viewport. High angle, looking down at roughly 20-30 degrees (estimated from
  the horizon and the foreshortened floor). From in front of and to the right of the dummy (its face points at the
  camera, turned toward the attacker), on the attacker's side. The attacker is screen-right and slightly nearer the
  camera; the dummy is screen-left and slightly further back. If this is Roblox's default 70-degree FOV, the camera
  is roughly 15-20 studs away (an estimate, not measured).
- **Movement**: none. A 3 px column of the horizon at both frame edges, taken from all 511 frames, is identical
  frame to frame: no pan, tilt, roll, push, height change or FOV change. The floor watermark and the dummy's
  screen position also never move.
- **Shake**: none at any hit, including the 34-frame flying-strike hold and the barrage.
- **Framing while moving**: the camera does not follow anyone. The attacker's hop (3.27-3.52) and rise (5.47-5.70)
  move his head only 25-55 px. This is consistent with in-place animation with no root motion (a moving root would
  normally drag Roblox's follow camera), but I can't confirm it from the video.
- **180-degree line**: kept throughout: attacker right, dummy left, blows travel screen-left, streaks point left on
  hits 1-2 and stream out to the right behind the attacker on hit 3.
- **Lesson**: this is a gameplay showcase camera, so there are no camera techniques to copy. It does prove that the
  poses and effects alone can sell the hits from a distance.

## C. Character animation and posing

The rigs are R6: each arm and leg is one straight block. The hands are the tan lower ends of the arm blocks, so
there are no elbow bends; every "bent arm" is a whole arm block rotated at the shoulder.

**Attacker poses**
- *Idle (0-1.83)*: standing upright, pressed against the dummy.
- *Lunge into the belly (1.85-2.13)*: wide stance with the rear leg stretched diagonally back; lead arm forward and
  slightly down into the dummy's belly; rear arm cocked back with the hand at the hip. The torso is turned toward
  the dummy (back three-quarters to the camera). The pose is held for 12 frames.
- *Body blow, hit 1 (2.23-2.30)*: the attacker has stepped to the dummy's left side and faces the camera and the
  dummy 3/4. His right arm angles down-forward from the shoulder (about 45 degrees below horizontal) with the hand
  in the dummy's belly at belt height. His head is low over the dummy's shoulder. A short, close blow; no
  extension beyond the target.
- *Hit 2 (2.60-2.667)*: the hand starts beside his head (arm raised forward-up) and comes down-forward to chest
  height over 3 frames. The arm sweeps about 60 degrees in a downward arc onto the folded dummy, then the burst
  covers the strike.
- *Guard (3.10-3.35)*: faces the camera; both arm blocks raised forward-up so both hands are at chin and chest
  height; knees bent, low wide stance. This is the "loaded" pose.
- *Hop and twist (3.30-3.47)*: the right knee comes up and the torso turns about 90-135 degrees in roughly 8 frames,
  from facing the camera to facing the dummy. The lead hand stays up by the shoulder and the dummy's head. Nothing
  swings back; the turn carries the arm round with the body.
- *Flying straight, hit 3 (3.48-3.52)*: the lead arm block is horizontal, straight across the dummy's chest, in line
  with the shoulder. The torso leans almost flat toward the dummy, and both legs trail up and back behind (screen
  right), with the knee still bent. The line of shoulder, arm and fist points at the target. The arm moves only
  from "raised forward-up" to "horizontal", about 30-45 degrees, in 2-3 frames.
- *Hold (3.533-4.10)*: that flying pose frozen, pressed into the dummy.
- *Drop and landing (4.10-4.43)*: the body comes down out of the lean in about 10 frames into a deep crouched
  landing.
- *Rise and barrage (5.47-7.10)*: a fast tuck jump (14 f) to a crouch above the dummy's shoulders, facing the camera.
  The barrage itself is hidden by the disc; the attacker's crouched outline stays visible and nearly still in its
  centre.
- *Over the downed dummy (7.10-7.60)*: standing upright over it; the final stomp shows as a ring at his feet.

**How the body reads the actions**: the attacker never reads as a rush; he works at arm's length the whole time.
Strikes read through (1) a clear guard or chamber pose held for a beat, (2) a body turn or lean, (3) a 2-3 frame arm
move, (4) a held contact pose. Arcs are carried by the torso; follow-through is replaced by the hold plus the
streaks. Overlap is minimal (R6), and the trailing legs on hit 3 are the main secondary motion.

**Target reactions**
- *Before hit 1 (1.85-2.20)*: upright and passive, even while the lunge arm is in its belly.
- *Hit 1 (from 2.233)*: pops in 1-2 frames into a fold: knees bent, arms flung out to the sides and up, torso
  bent forward and over toward the attacker, around the fist. Held through hit 2 until about 2.85.
- *Recovery (2.90-3.07)*: straightens to upright with its arms down in about 10 frames.
- *Hit 3 (3.48-4.27)*: stays upright on its spot while the attacker is pressed into it. Afterwards (4.17-4.43) it
  stands leaning slightly away from the attacker. It never travels.
- *Barrage (5.65-7.10)*: under the attacker; ends lying crumpled on the ground in place by 7.10 (the descent is
  hidden in the disc).
- *Get-up (7.60-7.83)*: about 14 frames.

**Transitions**: no wasted rotation in the attack poses, but two pops: the move starts with a 1-frame snap (1.83)
and ends with a 1-2 frame reset (7.85). The dummy's hit pose also pops in rather than easing in. These pops are
hidden by speed and effects in play, and would look rough in a cinematic.

**Root motion**: judged from the evidence, mostly in place. The attacker's head moves at most about 55 px across the
whole combo, the camera never follows, and the dummy never moves off its spot except downward.

## D. Screen effects and impact treatment

**There are no screen-space effects at all**: no flash, colour/grade shift, inversion, vignette, blur, impact frame
or screen shake. The edge strips over all 511 frames show no brightness change at any hit. A faint, permanent tone step
around 5.0 s doesn't line up with any hit; it is probably video compression. Every effect is world-space:

| Effect | When | Frames | Notes |
|---|---|---|---|
| White ground ring (pre-impact pulse) | 2.30, 2.65 under the dummy; 3.267, 4.30, 5.467 at the attacker's feet (take-off/landing); 7.40 big stomp ring | appears 1 f before the burst, spreads and fades over 15-25 f | Flat ring with a toothed rim plus a smoke ring. Marks every take-off, landing and hit on the ground. |
| Small white swirl at the contact point | 3.517 | 1-2 f | A tiny ring at the dummy's chest, 1 frame before the big burst. |
| Green star burst | 2.317, 2.667, 3.533 | 2 f white-hot core, then green spikes 5-8 f (34 f on hit 3) | Hits 1-2: about 30% of frame width, with streaks to about 47%. Hit 3: about 20-30%. Spikes are sharp and radial, with a white core. |
| Speed streaks (green and black) | 2.333-2.40, 2.70-2.77 pointing left; 3.55-4.13 streaming right behind the attacker; 5.717-7.0 diagonal from the upper left | 4-6 f on small hits, the whole hold on hit 3 | Show the direction of the blow (small hits) and the attacker's travel (hit 3). |
| Green ring of sparks / expanding outline | 2.77-2.87, 3.80-4.17 | 6-20 f | Grows out from the contact point. |
| White crescent "wind" arcs and smoke | after each burst, 2.48-3.10, 4.17-4.75, 7.2-7.8 | 15-35 f | Keep the frame moving while the bodies hold. |
| Barrage disc (vertical spinning green/white ring) | 5.767-7.10 | about 80 f | Faces the camera, centred on the attacker, with flickering green slashes. Ends with a 2-3 frame black-and-white ring. |

**Essential**: the pre-impact ground ring plus the 2-frame bright burst core give a crisp timing tick on every
hit, and the streaks give the direction. **Decorative**: the arcs and smoke, though they are what makes the holds
read as alive. **Hiding**: each burst covers the dummy, and on hit 3 most of the attacker too, for its whole length.
The barrage disc hides the dummy for 1.4 s, so the most important thing (the target giving way) happens off-screen.

## E. What it teaches us

**Strongest techniques**
1. *R6 punches from a loaded guard*: the hand is already at chin height before the strike, and the hit is the
   arm block rotating only 30-45 degrees to horizontal at the target in 2-3 frames. The torso turn (about 90-135
   degrees in 8 frames on hit 3) and the lean (body almost flat, legs trailing) supply the power. The arm never
   rotates through a big arc by itself.
2. *Shoulder-arm-fist in one line at contact*, pointed at the target's chest, with the body behind it.
3. *The target folds onto the fist*: the hit pose bends the dummy forward and toward the attacker, so its chest
   closes over the blow instead of turning away.
4. *Impact tick*: a ground ring 1 frame before, a white-hot core for 2 frames, then streaks in the blow's direction.
5. *Freeze with moving effects*: the 34-frame body freeze on hit 3 is held up by spikes, streaks and rings that keep
   moving, so it reads as power, not as a stall.
6. *Rings at take-off and landing* tell the viewer that the feet left or hit the ground, even with no camera move.

**Principles to adopt**: fast poses (2-3 f) between clear held poses; no slow drift into a strike; the arm is
loaded before the travel and only extends at the end; the effects keep moving through every hold.

**What would NOT translate**
- The locked wide camera: fine for gameplay, but too distant and flat for our cinematic (our owner wants motion).
- Bursts that cover the contact: our cinematic close-up needs the fist on the torso visible at the contact frame.
  Here it is always hidden.
- The pops at the start and end of the move, and the dummy's snapped hit pose: acceptable at game speed, but they
  would look broken in a slow, close cinematic.
- No launch and no travel: nothing here for our uppercut distance or the dash after the target.
- The barrage disc hides the target's descent: we want the flurry readable.

**Concrete uses in our sequence**
- *Haymaker wind-up* (the owner says the arm rotating is awkward): copy hit 3. Raise the arm into the loaded
  guard/chamber BEFORE or AT the start of the leap (one quick 3-4 frame move, like 3.10-3.23), hold it there through
  the travel, turn the torso toward the target during the travel, and only at the end move the arm block about 30-45
  degrees to horizontal in 2-3 frames. Don't rotate the arm back slowly during the rise.
- *Final punch pose*: shoulder, arm and fist in a straight line at the target's chest, torso leaning in, legs
  trailing behind (on hit 3 they trail up and back in the air).
- *Target facing* (the owner says the torso doesn't face the fist): pose the target 3/4 toward the attacker,
  and make its hit pose fold forward over the fist, chest closing onto it.
- *Impact*: add a 1-frame ground or contact ring before the impact frames, and keep streaks and sparks moving
  during our 0.75 s slow motion, the way the 34-frame hold here keeps moving.
- *Knockback delay*: the reference's hit pose appears 1-2 frames after contact, and the burst within 1-2 frames.
  Nothing waits. If our knockback must follow the slow motion, the target at least needs its hit pose (a fold
  around the fist) on the contact frame.
- *Leaps*: add rings at take-off and landing.

## F. The six questions

**1. Facing at contact.**
- Hit 1 (2.233-2.30): the dummy's chest faces the camera, turned about 3/4 toward the attacker (its face shows on
  the camera-right side of its head at 2.25). The fist comes from the attacker's side (screen right) and lands low
  on the front of its belly, at belt height, at the front-left edge. The dummy doubles forward over the fist.
- Hit 2 (2.60-2.667): the dummy is still folded toward the attacker. The downward blow lands on its bent upper
  body, at the front or top; the contact itself is hidden by the burst.
- Hit 3 (3.48-3.52): the dummy faces the camera and the attacker 3/4 (faint face toward camera-right at 3.43-3.47).
  The attacker's horizontal arm crosses the FRONT of its chest. The 3.517 swirl marks the contact at chest/stomach
  front.
- In every case: the chest is turned partly into the blow (3/4, not side-on) and the hit lands on the front of the
  torso, never the side or back. Not perfectly square to the fist: the camera side gets the rest of the turn.

**2. Launch distance.** Not shown. The dummy never launches. It stays on its spot through every hit, and the
barrage drives it straight down to the ground in place (lying by 7.10; the fall itself is hidden).

**3. Rush readability.** Not shown; there is no rush. The closest is the 0.25 s hop into hit 3 (3.27-3.52): a
1-frame take-off ring at the feet, a knee lift, a body twist and a lean with trailing legs, with almost no ground
travel (head moves under 0.2 body heights). The direction of travel is only shown afterwards, by the streaks
streaming out behind the attacker during the hold.

**4. Dash into the final strike.** Shown in miniature on hit 3. The wind-up happens BEFORE the travel: an 8-frame
turn into a two-handed guard (3.10-3.23), hands at the chin. During the 10-frame hop the fist stays loaded by the
shoulder while the TORSO turns about 90-135 degrees toward the target. The arm moves only in the last 2-3 frames
(3.48-3.52), from raised to horizontal (30-45 degrees). The arm never visibly rotates back. The transition is carried
by the held loaded pose plus the body turn, then hidden by the burst from 3.533. Hit 2 is similar: the hand,
already raised by the head, comes down-forward over 3 frames.

**5. Knockback onset.** No knockback travel is shown. The visible reaction is immediate: the dummy pops into its
folded hit pose within 1-2 frames (2.20->2.233), and on hit 3 the burst comes 1 frame after the contact swirl
(3.517->3.533). There is no slow motion; hit 3 has a hard freeze of about 34 frames (both bodies still, drift under
10 px), with only the effects moving. After it, the attacker drops within 10 frames. The dummy only leans slightly
away (4.17-4.43). Uncertain: on hit 1 the dummy's fold (2.233) comes 5 frames before the burst (2.317). Either the
burst lags the contact, or the burst marks a second blow; the frames don't settle which.

**6. Smoothness.** The camera is perfectly static, so its smoothness offers nothing to copy. The bodies avoid looking
stiff through contrast rather than easing: holds of 11-41 frames joined by very fast 2-8 frame moves, with the
effects (expanding rings, swirling white arcs, smoke, flickering spikes, streaks) always moving during every hold.
The trailing legs on hit 3 and the knee lift in the hop are the only overlap. The weak spots are the hard pops (move
start 1.83, dummy hit pose 2.233, reset 7.85), where nothing eases. Holds: 1.93-2.13 lunge, 2.40-2.58
after hit 1, 3.533-4.10 flying-strike freeze, 4.75-5.43 crouch, 5.8-7.1 barrage crouch. Each one has an effect moving
through it.
