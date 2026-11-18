# kits-8c..8d: the launch and dash retimed from measurements, and three impact-frame runs

Written 2026-11-18.

The owner on kits-8b:
- "the camera work is still pretty off, same with the animation timings"
- "the main issue is that the leap + dash have really weak impact, doesnt feel strong at all and feels like you just glide over"
- "there should be 3 impact frame moments"
- "the impact frames need to be more detailed and flashy"

The measurements are in `12a` (Azure Flames, Strongest Battlegrounds, Garou vs Stinger) and `12b` (Jotaro, Human Battery, Acheron).
Ours was measured from a Studio replay recorded at 0.2x.

## Launch and dash: ours against the references

| Beat | References (measured) | kits-8b | kits-8d |
|---|---|---|---|
| Launch | 80 % of the climb in 2 frames, parked by 0.17 s; a STILL camera (Azure 4.27; Jotaro out of frame in 8-10 frames; Human Battery flies at a locked lens) | 0.34 s; the camera whipped its aim after it | 0.17 s `kick` ease (1-(1-x)^4); a still reverse-angle camera, the target flying out over the lens |
| Launch end to take-off | 0.43-0.50 s (Azure 13 f, Strongest Battlegrounds 15 f) | 0.17 s | 0.44 s |
| Coil | 0.23 s, deepest on its last frame (Azure) | 0.17 s, the fist aimed at them (read as already thrown) | 0.30 s, deepest at the take-off, the fist cocked up by the ear |
| Dash | 0.23 s at full speed, hits on arrival (Azure, Strongest Battlegrounds); no reference slows into a stop | 0.57 s easing out, then a 0.26 s still hold | 0.23 s `launch` ease (full speed from the first fifth), contact on arrival |
| Dash camera | stays put and pans from the first coil frame with no ease-in; the attacker recedes from 36 % to 10 % of the frame's height; settles 1-2 frames before contact (Azure) | aimed AT the attacker the whole way, so they never moved on screen (the glide) | fixed behind the attacker's right, an even pan toward the target from the cut, the attacker shooting away from the lens |
| Strike | released in 1-3 frames (Mumen, Tanktop, Serious Punch) | the arm slid 0.8 studs along its aim | snaps from cocked to aimed in 0.07 s while the torso turns |
| Take-off | a ground ring, streaks and dust (Azure, Strongest Battlegrounds) | a dust ring, a gust straight up | a bigger burst, dust thrown faster, the gust along the dash, a wide streak behind the body, a camera jolt |

## Uppercut camera

- Behind the attacker's shoulder, their back hid the target in two recordings. The square contact puts the attacker a
  stud to the target's right, turned away from any camera on that side.
- Now it's the reverse angle: low, beyond the target, looking back at the attacker's front and the fist rising into the
  jackknifed body.

## Impact frames

- **Three runs, as the owner asked:**
  - contact, 0.2 s
  - the soak, 0.15 s, 0.38 s after contact
  - the release, 0.2 s, right before full speed, 0.6 s after contact
- **Each run is drawn from the bodies as they are at that moment.** The body keeps moving under and between them.
- **The slow part is 0.8 s.**
- **New card features, from the references' measured cards:**
  - lines that close in and redraw every 2 frames
  - a slash that thins
  - needles flying out on set angles
  - turning stars
  - a push-in within a card
  - the fighters as ink line art, as well as solid
  - a red-ground card
- No ring with lines, no sun shapes.

Two bugs found on the way:

1. **The silhouettes could never change colour.** Copies were matched to the live parts by position in
   `GetDescendants`. A character in play carries instances that don't clone, so nothing matched, and every card's
   figures were black whatever its ink (since kits-7f). Fixed: tag each part with its number before cloning.
2. **First-shown images drew blank.** The first run's slash and stars were missing, and its lines came in late, even
   after `PreloadAsync`. Fixed: a 1-pixel, nearly transparent copy of each card texture is kept on screen from the start
   (`HT_ImpactWarm`).

## Studio replay tool (kits-8c, Studio only)

- **Entry point:** `ReplicatedStorage.HT_UltReplay:Invoke(target, scale, hold)` plays the ultimate on this screen
  alone, on a local clock.
- **Steering:** its `Scale` attribute is the speed, and `Hold` pauses at a cutscene time.
- **Slow-motion effects:** the effects and the impact cards are slowed to the same pace.
- **Purpose:** record at 0.2-0.5x, then speed the video back up, so recordings show timing honestly at Studio's 10-30 fps.
- **Camera:** the cutscene also re-asserts its own camera every frame now, so nothing can hand it back mid-way.

## Not verified

- **Real speed in a live play:** watched only as a 0.5x replay sped up 2x (`design/references/ours-kits-8d.mp4`).
  Sound timing (the sounds aren't slowed in a replay) and a real two-player run weren't checked.
- **Stage D (grade, speed lines over the flurry) and the sound pass:** not started.
