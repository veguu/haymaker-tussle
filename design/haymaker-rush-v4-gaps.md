# Haymaker Rush v4 - the fix list (from the gap study, for the owner's pick)

Written 2026-11-17 from four frame-by-frame studies that compared our `kits-7e` recording with the 10 references.

- Vault: `63 VFX Creation/Haymaker Rush vs References - Gap Report.md`, plus one note per area: Animation, Camera,
  Screen Effects, VFX. Every item below has its evidence and exact numbers there.
- Prompt: `design/haymaker-rush-gap-study-prompt.md`.

Ranked HIGH first, animation first, and grouped into build stages. Each stage says what you'll see change. Nothing
here is built yet.

## Stage A: the screen and the basics (small, high impact)

What you'll see: a clean cutscene with no HUD and no white blob, smoother impact frames, and fists that touch.

| # | Fix | Severity | Area |
|---|---|---|---|
| A1 | Hide every ScreenGui and the Roblox top bar on the two fighters' screens for the whole ultimate; hold the "READY", "ULTIMATE" and "FIGHTERS LEFT" banners until after it. Restore under the end's black dip. | HIGH | Screen, Camera |
| A2 | Remove the dash effect (white part copies, random streaks) from the ultimate. | HIGH | VFX |
| A3 | Impact frames: build the cards and silhouettes during the wind-up, not at the hit (they clone both characters 8 times at 5.70 s; likely the drop to about 10 fps), and pick each card by elapsed time so a slow frame can't stretch or skip one. Confirm with the MicroProfiler. | HIGH | Screen, Perf |
| A4 | Make the fists land on the hook and the uppercut (3 and 1.4 studs off today): hook contact aimed about 5 degrees across the body, reach 2.6. Add a build check that fails if a big hit's fist is over 0.5 studs from the torso. | MED | Animation |
| A5 | Remove the randomness: fixed spike rotations by hit index, aimed glints (or none). | MED | VFX |

## Stage B: the animation (the biggest change)

What you'll see: a flurry that reads as a real barrage, a target that takes every hit, and a rush that launches.

| # | Fix | Severity |
|---|---|---|
| B1 | A new flurry loop: 8 different punches over 1.0 s (straight up, rising hook, uppercut, straight, overhand, short jab, and mirrors), each with its own chamber, lean (-22 to +5), turn (±35-45) and crouch. Still one hit every 0.125 s. | HIGH |
| B2 | The body under the arms: the root shifts ±0.25 studs sideways on alternate hits and steps in 0.3 studs every 4 hits. | HIGH |
| B3 | Punch timing: out 0.03 s, hold at contact 0.04 s, back 0.055 s, with the next arm overlapping (today half of each punch is the retract). | HIGH |
| B4 | The target reacts to every flurry hit: 4 set reaction poses (hit from the right, hit from the left, arch, fold), snapped in and held 0.05 s; the body pitches back more with each hit; a bigger bob. | HIGH |
| B5 | Big-hit reactions: hook (head snap 40°, side bend 30°), uppercut (arched, a slow backflip on the rise), haymaker (a "C" fold around the fist, then the tumble). Each is held through its freeze. | HIGH |
| B6 | Free the bodies: optional pitch, roll and yaw per timeline key (today both roots are forced upright), and no AirTumble blending into the cutscene's reactions. | HIGH |
| B7 | Spacing about 1 body height in the flurry (already agreed), together with B1. | HIGH |
| B8 | The rush: a 0.08 s launch crouch, full speed from frame 2 (no slow ease-in), a held stretched stride instead of a run cycle, and the hook's cocked pose visible for its last 0.09 s. | HIGH |
| B9 | The haymaker's follow-through: arm held out, body leaning and carried 1-1.5 studs along the punch for 0.3 s. | MED |
| B10 | Leap and air poses: a launch crouch, an extension, a tuck; HaymakerUp's own air legs (knee up), instead of feet locked as if standing. | MED |
| B11 | A deep uppercut crouch in the set (0.26 s), and a deeper wind-up coil with a slight moving hold. | MED |
| B12 | Smears or fist multiples on strikes (a 1-frame arm stretch, or 2 short ghost arms). **Needs your pick.** | MED |
| B13 | A lock-in pose with the fist cocked at the shoulder. | LOW |

## Stage C: the camera

What you'll see: off-centre compositions with clear silhouettes, a wind-up that shows your face, a cut burst into
the haymaker, and a flight you can follow.

| # | Fix | Severity |
|---|---|---|
| C1 | The wind-up insert beside and a little behind your face at eye height (today the target blocks it), face on the left third, a slow push, then still. | HIGH |
| C2 | A burst of cuts into the haymaker: a 0.05 s close-up of the target's face, a 0.05-0.08 s fist coming at the lens, then the side profile and freeze. Also one victim close-up after the hook. | HIGH |
| C3 | The flurry framed off-centre (pair at x 0.3-0.6, room on the side the blows travel), FOV 52-55, a slow push in during it; a still side two-shot (about 0.25 s) before the uppercut. | HIGH |
| C4 | The flight: open close behind the target (50-60% of the height), cut away at about 25%, then a long-lens side wide against clean sky for 1 s. No widening to FOV 95. | HIGH |
| C5 | The rush shot. Option A: over the TARGET's shoulder, so you grow toward the lens from about 25% to 90% and it cuts on the fist (Garou vs Stinger). Option B: the current fixed camera behind you, closer and lower. **Needs your pick.** | HIGH |
| C6 | A clearance check so scenery never blocks a shot; keep the sun out of frame. | MED |
| C7 | Big-hit snaps open on a clean frame (at most 1 flash frame); the leap wide held 0.5-0.6 s with the pair in the top third; the lock-in reframed. | MED |
| C8 | Camera tests that cover the inserts too (no blocked faces, headroom, not centred), run at 16:9 and 19.5:9; record reviews at 16:9. | HIGH (process) |

## Stage D: screen effects

| # | Fix | Severity |
|---|---|---|
| D1 | The darkening as a colour grade (darker, more contrast), not a 55% black sheet, with one light kept bright (the fist or an eye glint). | MED |
| D2 | The flash as a 2-frame overexposure or a star flare, with no fade. | MED |
| D3 | Impact cards that animate inside their run (the slash grows then thins; the lines close in), uneven hand-set speed lines, and silhouettes big enough to read as two bodies. | MED |
| D4 | Speed lines over the frame during the flurry, aimed at the target, rotating step by step. **Needs your pick: white or black lines.** | MED |
| D5 | A visible way into the cutscene: a sharp stroke wipe, or a snap to a stronger grade. | LOW |
| D6 | Card 4 uses 4 tones (black, white, red, cyan) where the references use one accent; it came from your "more flashy" pass. **Keep or simplify?** | LOW |

## Stage E: VFX

| # | Fix | Severity |
|---|---|---|
| E1 | The "Rush Lane" in place of the dash effect, all particles and trails:<br>- a flat ring at the feet on the launch, with dust thrown back<br>- one ground trail along the whole path that stays about 0.6 s<br>- two thin edge lines<br>- a skid of dust at the arrival | HIGH |
| E2 | The flurry swooshes (already approved): thin tapered line arcs, white then grey, two per hit, directions from a set cycle, mirrored by side. | HIGH |
| E3 | A ground event on the finisher: branching cracks (no centre circle; the drawing comes to you first), debris shards and smoke that stay 0.6-1.4 s. | HIGH |
| E4 | One ring per big hit, capped in size (the blast stacks 2-3 rings up to 35 studs and reads as a target; check it against your "no sun" rule). | MED |
| E5 | Flurry sparks that don't hide the contact: no halo, a shorter life, placed just past the fist. | MED |
| E6 | A visible flight trail (the ribbon) and a ring on the launch; a lingering layer of drifting lines and smoke on big hits; grey wind on the haymaker; 2-3 spark shapes in turn. | MED / LOW |

## Then: the sound pass

Heavier, louder barrage and hits, measured against the references (your earlier note: "too soft, not heavy").

## The owner's picks (2026-11-17)

- **Order:** A, then B, then C (E and D after).
- **C5:** option A, the camera over the target's shoulder, the attacker rushing at the lens.
- **B12:** a 1-frame arm stretch (about 1.4x) on the strike frame.
- **D4:** white speed lines.
- **D6:** not answered yet.

## Picks needed from you (as asked)

1. Which stages to build, and in what order. My recommendation: A, then B, then C, then E, then D.
2. B12: smears (a stretched arm frame) or ghost fists, or neither.
3. C5: the rush camera, option A (over the target's shoulder, you rushing at the lens) or option B (behind you).
4. D4: speed lines over the flurry, white or black.
5. D6: keep the 4-tone card or simplify it to one accent.
