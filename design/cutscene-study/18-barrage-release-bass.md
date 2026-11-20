# 18 - Barrage hits, the release, the bass (study, 2026-11-19)

The owner after kits-8p: change the barrage hit VFX ("default punch doesnt really work here"), give the last punch's
release a Serious-Punch-like VFX ("a lot better and flashy"), and replace the release's second heavy-hit sound with
"something bassy". Study size agreed first: 24 fps sheets around single hits, no subagents.

## Barrage references (24 fps sheets around one hit unless said)

| Ref | What every hit is made of |
|---|---|
| b1 "Heavy Barrage" (gorF3Y_-U8Y), 4.0-5.0 s | A WHITE burst re-fired every 1-2 frames: a blown-out white core, 8-15 long thin needle streaks all shooting ONE way (along the punches, away from the puncher), 1-3 thin outline circles at the core at varied sizes and tilts, a few sharp white chips/diamonds flung out, a faint warm smoke behind the core. Never a full radial burst. |
| b2/b3 "Barrage" (5sZbb2SF-nw, wGQO0__ab7k, same creator), 4.0-5.0 s | Coloured (cyan + violet): short smeared fist streaks flying in toward the target from the puncher's side, a CLUSTER of 6-10 small thin rings at the contact (bubbles), tiny spiky splash stars, 4-point white glints popping around, grey smoke drifting. |
| b4 JoJo game clash (In46WwS3ip8) | Screen-filling yellow/violet lightning, slash smears and screen glitch. A clash, not a hit on a body; least relevant. |
| b5 "Barrage VFX" (4kHsuID9P_s), 2.0-3.0 s | MONOCHROME: long white AND black lens-shaped streaks (fist smears) shooting forward, small white and black 4-point glints, thin vertical rings at the contact, grey smoke swirling round the floor. |

Common to all: one-directional streaks along the punches (never radial), small thin rings at the contact, 4-point
glints, smoke; dense (a new hit every 1-2 frames in b1 and b5, every ~0.1 s in b3).

## The release reference: "Shockwave Punch" (MYjuLuLwGyk), 2.2-3.2 s and 11.2-12.2 s
- The body flashes solid white for 2 frames (we already do this on the flash step's reappear).
- A white blown-out CONE/flare bursts out in front of the fist (the punch's direction), 2-3 frames.
- Around it a SPIRAL: curved crescent blades swirling round the punch axis, and a thin expanding sphere/ring outline.
- Then huge translucent pale wind shapes (claw/wave curves) open out to fill the frame and fade over ~0.5 s;
  white mist and thin curly wind lines linger and rise.
The owner: this is the SHAPE wanted, made "a lot better and flashy".

## Bass references (measured with sfx-lab/tools: onsets, hitstat, subpitch)

| Ref | Moment | Numbers |
|---|---|---|
| s2 "Kakyoin's death ... all the sound effects" (H_cecUveVoQ) | 2.515 s, the big hit | sub peak -6 dB at +43 ms, held above -20 dB for 1.57 s; low -12, lmid -19, mid -19, high -20 (held only 0.55 s); loudest at +100 ms; down 20 dB at +372 ms then a long rumble; sub pitch wanders 50-100 Hz (mostly 50-75); no crackles; near mono lows. |
| s1 "Benimaru Crimson Moon" (tTUEM9KdxfQ) | 3.85-5.5 s | a slow swell: very low start (centroid 65 Hz), noisy rise with many crackles, a big boom at +1.66 s; then a steady ~50 Hz drone. |

Library candidates (Sonniss GDC 2026, measured the same way):

| Candidate | Sub | Shape | Fit |
|---|---|---|---|
| 344 Audio Bass Drop & Downer Medium 04 | -9.6 @50 ms, held 1.57 s, 50-100 Hz wander | low/lmid roar, highs held, loudest +314 ms | closest overall to s2 |
| Federico Soler Trailer Booms 011 (first boom) | -5.3 @51 ms, held 1.54 s, 50-75 Hz | darker (mid -33), wide | deep body |
| Federico Soler Trailer Booms 075 (first boom) | -3.1 @37 ms, held 1.55 s | punchy, down 20 dB by 237 ms | the hit's thump |
| 344 Bass Drop & Downer Fast 12 / Medium 15 | -14/-12, held 1.58 s | pure sub, no roar | a sub bed only |
| Colossal Impacts "Impact Cut Sweep" | -2.8 but at +631 ms | a sweep INTO the hit | wrong order |

## Built (kits-8r, kits-8s)
- Barrage hits: `src/client/Fx/BarrageHitFx.luau` (black and white, the owner's pick). Release: `src/client/Fx/ReleaseFx.luau`
  (the full shape, the owner's pick).
- Bass: three candidates from `sfx-lab/build_round8.ps1`, uploaded 2026-11-20 to group 2970443:
  A thump + roar 80095578441457, B deep body 84880153310920 (lows made mono), C sinking 97481582534056 (closest to the
  Kakyoin hit: deepest, down 20 dB by 0.3 s, then the rumble). Role `ult_release` in Config/SoundCandidates; A plays
  until the owner picks in the Studio sound picker (P).
