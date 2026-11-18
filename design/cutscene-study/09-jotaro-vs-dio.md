# 09 - Jotaro vs High DIO (The World's MUDA barrage, final blow, launch)

- Reference: "Jotaro vs High DIO Sound Effects Only#2", YouTube id `sUmnKwt9uyA`
- Length 14.5 s (870 frames), 60 fps container, 1280x720. Anime (JoJo's Bizarre Adventure: Stardust Crusaders).
- Drawing rate: ffmpeg scene-change scores show ~12 new images per 0.5 s almost everywhere, i.e. the picture is
  animated at about 24 per second; character drawings in barrage 1 change only every 5 video frames (12 per s) while
  the speed-line backgrounds change at 24 per s. "Frames" below are 60 fps video frames; "drawings" are distinct images.
- Attacker: DIO's Stand The World (blue/purple in this palette). Target: Jotaro (green coat, pink shirt in this
  palette). From 0.15 to 13.46 s the whole clip is in a shifted (non-natural) colour palette; natural night colours
  return at 13.47 s. The final blow of barrage 1 gets a third palette (black / yellow-green) for its freeze.
- Could see: every cut, shot sizes, poses in the close and mid shots, launch paths in the wide shots, the freeze card.
  Could NOT see: the exact fist-to-body contact inside the barrages (every contact drawing is covered by a white spark
  or smear), Jotaro's detailed pose in the wide shots (he is 8-35 % of frame height there), whether The World or the
  camera rotates during the dive (no environment visible, only speed lines), and any sound (pictures only).
- Studied: the 8 overview sheets (12 fps), then detail sheets at 24 fps / 60 fps of: barrage 1 (1.30-2.63), the final
  blow at every frame (2.38-2.70), one full-size pair of the impact frame and the finished X-ray card, the launch blow
  (4.16-4.65 at 24 fps, 4.65-5.07 at every frame), the rooftop flight (6.04-7.04), The World's arrival (7.96-8.62),
  the dive into contact at every frame (9.45-9.93), the contact hold (9.92-10.58), the final kick (12.42-13.42) and the
  ending fall (13.46-14.46). Freeze lengths and drawing cadence come from per-frame ffmpeg change scores.

## Summary (5 lines)

1. The barrage's last punch is set apart by changing everything at once: cadence (5-frame drawings become two 3-frame drawings), a hard cut to a closer over-the-attacker's-shoulder angle, a palette swap, a big starburst, then a 97-frame (1.62 s) true freeze with three X-ray panels fading in about every 0.45 s.
2. F1: every contact is filmed from behind or over the attacker's shoulder, so the target's chest/face front faces the fist AND the camera; before the last kick the target turns his torso into the attacker during the attacker's coil.
3. F2/F5: the launching gut punch has no hit-stop: the target moves 1-2 drawings (3-6 frames) after contact and is out of frame in about 15 frames. A 1 s close-up (blood, speed lines) and then a wide shot sell the distance: he crosses the whole frame (more than 5 body heights) and smashes a rooftop sign.
4. F3/F4: the chase is a 1.23 s head-first dive filmed from in front (he comes at the lens) inside streaming speed lines, fist already forward; the strike is the arm thrown at the lens plus a 5-frame smear wipe, then a hard cut to the contact. There is no separate arm wind-up.
5. F6/D: holds are never dead: speed lines stream, the cap chain flutters, the camera drifts. The only full freeze (the X-ray card) is paced by panel fades, and every hold sits between 2-5 frame smears.

## A. Sequence and timing

| time (s) | dur | what happens | eye drawn to |
|---|---|---|---|
| 0.00-0.13 | 0.15 s | DIO mid shot on a rooftop, yellow aura, fist cocked | DIO's raised fist |
| 0.15-1.23 | 1.08 s | The World front-on, fists hammering at the lens (target POV), radial speed lines; its head stays centred | The World's face, centre |
| 1.25-2.42 | 1.17 s | Barrage 1, side shot: Jotaro left, The World right with its back three-quarter to camera; 14 drawings, one per 5 frames, each a different multi-arm pose with a white spark at Jotaro's chest/face | contact sparks, left-centre |
| 2.43-2.52 | 0.10 s | Last punch: 2 drawings of 3 frames each; one arm fully extended into his face with a long white arc trail, fewer ghost arms | the fist at his face |
| 2.53-4.15 | 1.62 s (97 fr) | FREEZE: hard cut to a closer, lower over-shoulder impact frame in a new palette, yellow starburst at his jaw; X-ray panels fade in at 2.58, 2.98, 3.52; nothing else moves | starburst, then each new panel |
| 4.15-4.23 | 0.08 s | Back to the side shot: 1-2 more blows, circular white arc at his waist | arc |
| 4.25-4.65 | 0.40 s | Lull: near-held pose, Jotaro dazed (eyes shadowed), one arm flung up; only the speed lines, his cap chain and a slight camera drift move | his shadowed face |
| 4.65-4.68 | 1 drawing | The World twists its torso (the only wind-up) | |
| 4.68-4.77 | 0.08 s | Launch blow: fist into his stomach from low right, white spark burst | stomach |
| 4.73-5.02 | 0.30 s | He is driven out of frame left (gone by ~4.93); The World lunges after him and rotates about 180 degrees in follow-through | The World |
| 5.03-6.02 | 1.00 s | Close-up of his face in flight: head snaps (5.08-5.17), blood sprays from the mouth, diagonal speed lines | face, blood |
| 6.03-6.20 | 0.17 s | Wide empty rooftop with a big "AIR" sign | sign |
| 6.21-7.05 | 0.84 s | He flies in from the top-right corner, smashes through the sign (dust burst 6.46), sails off left and down; camera pans/tilts after him | him, dust |
| 7.05-7.62 | 0.57 s | Empty frame, dust and debris settle | dust |
| 7.63-8.07 | 0.45 s | Wide sky over the city: he tumbles, a yellow glow above right | him |
| 8.08-8.13 | ~5 fr | Cyan starburst: The World appears far above | flash |
| 8.17-8.62 | 0.45 s | Cyan spiral trail; The World dives head-first down onto him | The World closing in |
| 8.65-9.62 | 0.97 s | Dive close: The World head-first toward camera/left in teal speed lines, slow roll relative to camera | The World |
| 9.63-9.80 | 0.17 s | It drives its arm at the lens; camera pushes along the arm until shoulder and yellow pad fill the frame | the arm |
| 9.82-9.88 | 5 fr | Smear wipe: the arm passes the lens as a pale blur | (wipe) |
| 9.90-10.07 | 0.17 s | Hard cut: he lies upside down, a fist arrives blurred (9.92) and lands on his cheek (9.96) | his face |
| 10.08-10.45 | 0.37 s | Contact hold: drawing identical, speed lines stream past | his face |
| 10.47-12.42 | 1.95 s | Barrage 2 mid-air on a diagonal: The World above right punching down, he on his back below left; drawings change every 2-4 frames | sparks on his chest |
| 12.42-12.83 | 0.42 s | The World flips and tucks, knees up (the coil); he turns from back-to-camera toward it | both |
| 12.875-12.95 | 0.08 s | Leg swing, 2 smear drawings | leg |
| 12.96-13.08 | 0.12 s | Kick contact; 2 drawings push to extreme close, ending on his chest front with blood | chest |
| 13.08-13.17 | 0.10 s | Wider: kick fully extended to lower left, his legs exiting frame bottom left | his feet leaving |
| 13.17-13.46 | 0.30 s | The World holds the extended kick, only speed lines move | the pose |
| 13.47-13.56 | 0.10 s | Natural palette returns: close-up of his bloodied face | face |
| 13.58-13.71 | 0.13 s | Two very short shots of his falling body | |
| 13.75-14.50 | 0.75 s | High wide angle: he falls away into the city toward the river and a hotel roof, shrinking; camera tilts down with him | him shrinking |

Anticipation, release, settle:
- Barrage 1 builds by repetition (14 drawings at a steady 5-frame beat, 1.17 s). The release is a speed-up: the last
  punch's drawings are 3 frames each, then the cut and a 97-frame freeze. Steady beat, sudden faster beat, then a
  full stop.
- The launch blow is anticipated by a 0.40 s lull (4.25-4.65), not by a wind-up pose; the wind-up itself is one
  drawing. The release is immediate motion (no hit-stop) and the target exits within ~15 frames.
- The settle is spread over shots: a 1 s reaction close-up, then the wide flight, then 0.57 s of empty frame with
  settling dust (7.05-7.62) before the next action begins.
- The ending reverses the rhythm: a 0.4 s visible coil, 2 smear drawings, a 3-drawing contact push-in, a 0.3 s held
  follow-through, then a burst of three shots of 5-6 frames each (13.47-13.71) into a 0.75 s wide fall.

Holds and hit-stops (frames at 60 fps):
- 2.53-4.15: true freeze, 97 frames. Change scores between the panel fades are 0.1-0.2 (noise): nothing moves.
- 4.25-4.65: about 24 frames of near-hold (pose held; speed lines, chain and a slow drift move).
- 10.08-10.45: about 22 frames of contact hold (fist on face held; speed lines move).
- 13.17-13.46: about 18 frames of follow-through hold (speed lines move).
- No classic short hit-stop (a few frozen frames on contact) in any barrage: the barrages read through sparks and
  fast drawing changes instead.

Read time: each barrage contact is readable in one 5-frame drawing (barrage 1) or a 2-4 frame drawing (barrage 2)
because each drawing has one clear spark at the contact point. The final blow gets 1.6 s; the launch blow gets about
0.1 s of contact plus 0.25 s of exit.

## B. Camera work

- 0.00-0.13 DIO, mid shot, slightly low, frontal. Cut.
- 0.15-1.23 The World, medium close-up, eye level, straight front, from the target's position (target POV). Static
  framing: The World's head stays centred while fists come at the lens from both sides. Radial speed lines from the
  centre outward. No measurable camera move.
- 1.25-2.42 Barrage 1: medium two-shot, eye level, side view from just behind The World's right shoulder (The World's
  back three-quarter to camera, Jotaro three-quarter front). Attacker on the right, target on the left; the line of
  action is horizontal. Background is pure horizontal speed lines (no environment). The figures' positions jitter
  between drawings by about 5-10 % of frame width (drawn variation; the background lines run on, so this is not a
  camera shake I can separate). No push or pan.
- 2.53 CUT to the freeze frame: tighter (Jotaro's head and shoulders plus The World's back fill the frame), lower,
  over The World's right shoulder, the camera now behind the fist; same screen direction (attacker right, target
  left, punch travelling right to left). Then static for 97 frames.
- 4.15-5.02: the same mid side shot as barrage 1. 4.25-4.65: very slow drift (Jotaro's cap rises ~10 px of 270 over
  0.3 s, under 4 % of frame height). 4.68-5.02: the camera holds roughly still while both figures surge left; it keeps
  The World, not Jotaro, in frame; he exits left.
- 5.03-6.02: close-up of Jotaro's face, slightly low, three-quarter. Small head movement only; the motion is carried
  by the speed lines and blood.
- 6.03-7.62: wide, low angle across a rooftop toward the sign, city below. Static for 0.17 s, then as he passes the
  sign the camera pans left and tilts down after him (by 7.0 noticeably more street is visible at the bottom; I
  estimate the pan at about a quarter of frame width). Smooth, no overshoot visible. The camera keeps running a little
  after he has left frame (to about 7.6), then a cut.
- 7.63-8.62: wide, looking up and across the sky above the city, Jotaro centre-left, the arrival top right. Slight
  drift/pan with his fall (rooftops shift up and left between 7.96 and 8.58).
- 8.65-9.62: medium close-up travelling with The World, in front of it and slightly to the side: it dives toward
  the camera and screen left. Speed lines diagonal (top right to bottom left), parallel to its travel. Its
  orientation relative to the camera rotates by roughly 45 degrees over the shot (right side, then front, then front
  three-quarter); I cannot tell if the camera orbits or the body rolls.
- 9.63-9.88: fast push-in along the extended arm (from medium close to the shoulder filling the frame in ~10 frames),
  then the arm passes the lens as a 5-frame smear: a wipe made of the attacker's own limb.
- 9.90-10.45: close-up of Jotaro upside down (head lower left), high angle, static; the diagonal speed lines carry
  the fall.
- 10.47-12.42: medium two-shot on a strong diagonal (attacker upper right, target lower left), both falling together.
  The camera falls with them, so they stay put in frame; the speed lines carry the travel.
- 12.42-13.46: same diagonal mid shot; at contact a push-in to extreme close in 2-3 drawings (12.96-13.04), then a
  jump back out to a medium shot of the extended kick (13.08), held while the target exits bottom left.
- 13.47-13.71: three very short shots (close face, low mid shot of the falling body, dark close pass of his coat).
- 13.75-14.50: high wide angle looking down on the city, river and a hotel roof; he falls away from the camera; the
  camera tilts down after him (the hotel rises into frame from 14.0).
- Screen direction is consistent from 1.25 to 9.90: the attacker comes from the right, Jotaro travels left. The dive
  turns it into "toward the lens". Barrage 2 and the kick keep "attacker upper right, target lower left".
- Shake: I did not identify a whole-frame shake anywhere. The impact energy comes from sparks, drawn variation,
  smears, push-ins and cuts.

## C. Character animation and posing

The World (attacker):
- Barrage poses (1.25-2.42): back three-quarter to camera, shoulders square to the target, torso leaning in, 2-4 arms
  per drawing (ghost arms) at different heights, each ending in a spark on the target. The legs are not visible (mid
  shot). No wind-up between punches; each drawing is a different extension.
- Last punch of barrage 1 (2.43-2.52): one dominant arm straight out at face height with a long arc trail behind it
  showing the path; the body stays upright. The freeze frame shows it from behind: big back, the shoulder high, the arm
  disappearing forward into the starburst.
- Launch blow (4.65-5.02): in the lull its arms hang low behind it (4.25-4.29 one fist at his hip). One drawing of
  torso twist (4.65-4.67), then the fist drives into his stomach (4.68) with the whole body lunging low and
  horizontal (4.78-4.85, body stretched across the frame, ghosted). The other arm swings up and back in counter
  (4.87-4.92), and the body rotates until its front faces the camera (4.93-5.02). Big follow-through: the body keeps
  travelling and turning after contact.
- Dive (8.17-9.80): head-first, body a straight diagonal, fists forward, legs trailing; at 8.83 both arms spread,
  then the right fist forward again. The pose holds while the speed lines move; the only big change is the final
  arm drive at the lens.
- Kick (12.42-13.46): a forward flip (12.46-12.62 upside down), then a tucked coil with knees up and fists high
  (12.67-12.83, held ~3 drawings), a spinning leg sweep (2 smear drawings), contact, and a fully extended kick held
  for 0.3 s with the leg pointing exactly along the target's exit path (down left).

Jotaro (target):
- Barrage 1: upright, torso three-quarter front to camera and facing The World, head snapping in a new direction on
  each drawing (back, aside, down), arms flung out (1.75 both arms wide; 2.17 hands up). He stays at the same screen
  spot: the barrage pins him, it does not push him.
- Freeze frame: head snapped back and to the left, chin up, face distorted, eyes wide, body arched back.
- Lull: upright, slightly back-leaning, chest open, eyes hidden under the cap brim, his right arm thrown up and back.
  Dazed; this pose exposes the stomach for the launch blow.
- Launch: 4.68-4.72 still in place (spark on stomach); 4.73 already ghosted/smeared; 4.78 shifted left and up by about
  a fifth of the frame width; 4.87 mostly out top left; 4.93 only the coat tail. He goes back (left) and slightly up.
- Flight (6.21-7.05): body horizontal at entry, then upright with arms up as he hits the sign (6.33-6.38), then
  tumbling with arms and coat trailing. Too small to read facing.
- Barrage 2: on his back, chest up, head lower left; arms limp or reaching up.
- Kick: back to camera at 12.58 with his head turned toward The World; by 12.88-12.96 his head and upper body have
  turned toward it. The extreme close at 13.04 shows his chest front square to the camera with The World's limb on it.
  Then he leaves feet last down left (13.08-13.17).

Transitions: no dead time between the barrage drawings; the only dead-looking time is the deliberate lull (4.25-4.65)
and even that has secondary motion. No wasted rotation is visible: the big rotations (launch follow-through, flip into
the kick) are part of the blow. All motion reads as drawn (no physics); the barrages hold both fighters in place
against moving speed lines.

## D. Screen effects and impact treatment

- Palette shift (0.15-13.46, whole clip): everything in blue/violet/teal with a green coat and pink shirt. Decorative
  but strong: it marks the whole sequence as a special state. Natural colours return at 13.47 to end it.
- Final-blow palette (2.53-4.15, 97 frames): black/navy background with white streaks, the characters in
  yellow-green and pale highlights. This, with the cut, separates the last punch from the barrage. Essential.
- Starburst at the final blow (2.53-4.15): a big yellow-white star with long spikes at the contact (his jaw), held for
  the whole freeze. Essential: it marks the exact contact point and stays visible through the panels.
- X-ray card (2.58-4.15): three angular panels with thick red borders, monochrome pale blue-grey on white, showing
  X-ray style bones (finger bones and knuckles of fists, and a larger bony shape that may be a jaw or skull; I cannot
  read the exact anatomy). They FADE in (each starts as a see-through ghost, opaque within 4-7 frames): top right at
  2.58-2.65, bottom left at 2.98-3.10, bottom right at 3.52-3.62, with holds of 20, 25 and 32 frames between. The
  borders radiate out from the impact point, so the wedge holding his face and the starburst stays visible; the
  panels cover about 60 % of the frame, including all of The World's body. This is what the long freeze does: it turns
  the stopped frame into a reveal of internal damage, paced in three beats so the 1.6 s freeze never feels stuck.
- Contact sparks (both barrages): a white, jagged star/scratch burst at each contact, lasting one drawing (3-5
  frames), plus multiple ghost arms. Essential for reading where each punch lands.
- Arc and body smears: 2.43-2.52 long white arc trailing the last punch; 4.17-4.23 circular white arc at the waist;
  4.73-4.93 white ghosting over both bodies during the launch (partly hides the target as he leaves); 12.875-12.95 leg
  smear; 9.82-9.88 the 5-frame lens wipe (hides everything, by design, as the transition into contact).
- Speed lines: in nearly every shot. Radial (0.15-1.23), horizontal (barrage 1, launch shot), diagonal (face
  close-up, dive, contact hold, barrage 2, kick). They change at 24 per second even when the characters hold, which is
  what keeps holds alive.
- Dust burst at the sign (6.46, lingering to 7.6) and flying letter debris (6.96 the R tumbling at top): sells the
  force of the launch through the environment.
- Blood: spray from the mouth through the face close-up (5.08-6.02); drops at the kick contact (13.00-13.17); blood on
  his face in the natural-palette close-up (13.47).
- Cyan starburst (8.08-8.13, about 5 frames) and cyan spiral rings (8.17-8.62): mark the attacker's appearance and
  its path in the sky. Decorative but they make a tiny figure readable in a wide shot.
- No vignette, inversion flash, blur or distortion identified beyond the above; no whole-frame shake.

## E. What it teaches us

Strongest techniques:
1. Mark the final blow by changing several things on the same frame: cut + closer angle + palette + one huge spark +
   freeze. Each alone would be weak; together they cannot be missed.
2. Make the barrage's last punch faster than the barrage (3-frame drawings after 5-frame drawings), then stop dead.
3. Keep a long freeze alive with timed reveals (three overlays on a ~0.45 s rhythm) instead of slow motion.
4. Separate "the big hit" from "the launch": the X-ray blow pins him; the launch comes later from a lull and has NO
   hit-stop, so the knockback is instant.
5. Sell distance with the environment and the next shots, not with one long tracking shot: exit frame fast, a
   reaction close-up in flight, then a wide where he crosses the whole frame and breaks scenery.
6. Film the attacker's chase from the front (it comes at the lens) and end the travel with its own limb wiping the
   lens, then cut straight to contact.
7. Put the camera behind the attacker for every contact so the target's front faces both fist and camera.

What would not translate to R6 Roblox:
- Ghost arms, drawn smears and drawing-by-drawing pose variation: our rigs are one continuous pose per frame; we would
  need trail/afterimage parts or particles to fake them, and multi-arm drawings are not possible on an R6 rig.
- The X-ray panels as drawn art: would need ScreenGui images we author; possible but it is a 2D overlay, not 3D.
- 24-per-second stepped animation against 60 fps backgrounds: our animation is interpolated; the "steady beat then
  faster beat" can be copied with keyframe spacing and VFX timing, not with drawing holds.
- Whole-clip palette shift: possible with ColorCorrection, but it colours the whole world, not just characters.
- Faces (blood from the mouth, eyes hidden by the cap): R6 faces are decals; the head-snap reads through head and
  torso rotation only.

Concrete uses in our sequence:
- Flurry: keep the target pinned in place during the flurry; one spark per hit at the contact point; then make the
  last hit (the uppercut) faster than the flurry rhythm.
- Uppercut launch: no freeze on the launching hit; move the target on the next frame (within 3-6 frames at 60 fps),
  have the camera NOT follow (target leaves frame in ~0.25 s), then show the distance in a wider shot with scenery as
  a size reference (a sign, a railing, a roof edge) and a dust burst where he passes it.
- The leap/dash after him: film it from in front, with the attacker coming at the camera, fist already forward; end
  with the arm pushed at the lens and cut to the contact close-up.
- Haymaker impact: use our impact frames + near-still slow motion like the X-ray card, but give the hold 2-3 timed
  reveals (impact frame, panels or overlays, a palette change) and keep the impact point visible throughout.
- Before the haymaker, a short lull (0.3-0.4 s) with secondary motion can stand in for a long arm wind-up.

## F. The six questions

1. Facing at contact.
   - Barrage 1 (1.28-2.42) and its final blow (2.53): Jotaro's torso faces The World (screen right) and three-quarter
     toward the camera; the fists land on the front of his chest/sternum and on his face/jaw. The camera is behind
     The World's right shoulder, so the fist travels away from the camera into his front. Chest square to the fist:
     yes (three-quarter at most).
   - Launch blow (4.68): his chest is open (arm flung up and back in the lull), facing camera and attacker; the fist
     hits the front of his stomach from low right. Front, not side.
   - Dive contact (9.96): on his back, face up toward the fist and the camera; the fist lands on his cheek/face front.
   - Barrage 2: on his back, chest up toward the attacker above; hits land on his chest/stomach front.
   - Kick (12.96-13.04): at 12.58 his back is to the camera; during the attacker's coil (12.67-12.83) he turns his
     head and upper body toward it, and the contact close-up (13.04) shows his chest front square to the camera with
     the attacker's limb on it. He is turned into the blow before it lands.
2. Launch distance.
   - Launch blow: in its own shot he moves only about 0.2-0.4 frame widths before leaving frame left (gone in ~15
     frames, by 4.93), back and slightly up. Then a 1 s close-up in flight (speed lines, blood). In the next wide
     (6.21-7.05) he crosses the whole frame in 0.84 s, at least 5-6 of his own body heights on screen, while shrinking
     to about half size (moving away from the camera, so the real distance is larger), and smashes through a large
     rooftop sign on the way. At 7.63 he is falling in open sky above the city. Total from contact to the attacker
     catching him: 4.68 to 9.96 s, about 5.3 s of screen time, including a 1.8 s chase (8.08-9.88).
   - Kick: he leaves the medium shot in about 0.1 s (13.08-13.17), down and left; in the high wide (13.75-14.50) he
     shrinks from about half to under a tenth of frame height as he falls toward the city: a long drop, too far to
     count in body heights.
   - Set-up: the long launch gives the attacker a long, readable chase (appearance flash, spiral, 1.23 s dive).
3. Rush readability (The World's chase, 8.08-9.88, about 108 frames).
   - It starts with an appearance flash (cyan starburst, ~5 frames) far away, then a spiral trail (27 frames) as it
     dives head-first at the target, growing in frame.
   - The dive close-up is filmed from in front and slightly to the side: it travels toward the camera and screen left
     and fills more of the frame over time. Pose: head-first straight diagonal, fists forward, legs trailing, held;
     no stride. Speed: dense teal speed lines parallel to the travel, changing at 24 per second, no environment.
   - Contrast: the shot before is a calm wide (target drifting, slow dust); the dive is close, fast, and fills the
     frame.
   - Barrage 1 is opened the same way: 1.08 s of The World punching straight at the lens (0.15-1.23).
4. Dash into the final strike (9.45-9.90).
   - No wind-up after the travel and no visible arm rotation backward: the fist is already forward during the dive.
     Over the last 15 frames the body twists (9.55-9.65, about 3 drawings) and the arm is driven at the lens while the
     camera pushes along it (9.63-9.80). The arm's own smear wipes the frame for 5 frames (9.82-9.88), then a hard cut
     to the contact (fist arriving blurred at 9.92, landing at 9.96). The transition is carried by the smear wipe
     plus the cut.
   - Launch blow comparison: the "wind-up" is a 0.4 s lull plus one twist drawing; the arm never visibly loads.
   - Kick comparison: the one visible wind-up in the clip is a whole-body flip and tuck (0.4 s), not an arm rotation.
5. Knockback onset.
   - Launch blow: contact 4.68; he is smeared/moving by 4.73 (3 frames, one drawing) and clearly displaced by 4.78
     (6 frames). No hit-stop, no slow motion; the body moves at once and fast, out of frame by about 4.93 (15 frames).
   - Final blow of barrage 1: a true freeze of 97 frames (2.53-4.15) with nothing moving except the panel fades;
     after it he is NOT knocked back (the barrage resumes, the lull follows). The freeze belongs to a blow that does
     not launch.
   - Dive contact: the drawing holds about 22 frames (10.08-10.45) with the fist on his face, but the speed lines keep
     streaming, so it reads as a held pose inside continuing motion, not a freeze.
   - Kick: contact 12.96-13.04; at the next drawing (13.08, about 7 frames after first contact) he is already exiting;
     gone by 13.17.
6. Smoothness.
   - Holds always contain motion: the 0.4 s lull has speed lines, chain flutter and a slow drift; the contact hold and
     the kick hold have streaming speed lines; the 1.6 s freeze has three paced fades.
   - Holds are framed by very short smears (2-5 frames), so stillness and speed contrast instead of blending.
   - Big body rotations are follow-through, not set-up: The World rotates about 180 degrees after the launch blow and
     flips into the kick, so the body keeps flowing after contact.
   - The camera moves through the action rather than locking off between beats: drift in the lull, pan/tilt after the
     flying body, roll/orbit in the dive, push-in on the dive arm and on the kick contact, tilt down on the final fall.
   - Rhythm changes keep it from feeling mechanical: steady 5-frame barrage, faster final punch, full stop; then fast
     cuts at the end (three 5-6 frame shots) into a calm 0.75 s wide.
