# Haymaker Rush v3 - beat sheet (DRAFT, for the owner's OK)

Written 2026-11-17 from the camera study of 10 references (vault: `63 VFX Creation/Cutscene Camera and Impact -
Measured From 10 References.md`; sheets in `design/references/camera-study/`). It answers the owner's verdict on
v2b: "the barrage animation isnt really good, the sfx is too soft and dont really sound like heavy blows, the
target is too close, and the screen shake and camera work isnt really impactful".

## What changes, and why (the study's numbers)

| v2b now | v3 | Evidence |
|---|---|---|
| One smooth spline camera through every hit | Slow drift BETWEEN hits; on each big hit, a freeze, then a SNAP to a new angle under a 1-frame flash | No reference eases through a big hit. Orlando's "continuous" stretch snaps 20-45 deg in 1 frame on every big hit |
| Shake = a rolling sine wave fading out | Two kinds: constant small jitter through the barrage (0.15-0.3 studs, new direction every frame); one directional jolt (about 1 stud, gone in 0.1-0.25 s) AFTER each big hit's freeze | Garou vs Stinger: 0.8-1.7 % jitter, then 5-7 % jolts dying in 3 frames |
| Hit-stop 0.05-0.09 s | Big hits freeze the whole scene 0.17-0.4 s | Every big hit holds 2-5 frames at 12 fps (Jotaro 19) |
| Chase camera riding behind the runner | A FIXED camera behind the start; the attacker sprints away from it, shrinking, speed lines converging | Azure 2.17-2.92; no reference chases alongside |
| Target flush, 2 studs ahead and just above | Target held about 1 body height off (root to root ~4.5 studs) and half a body above, so silhouettes never overlap | Azure juggle 1-1.5 body heights up and to the side; Orlando 0.5-1.5 |
| Barrage: one 2-pose loop (left, right) | 4+ different punches in turn (straight up, rising hook, body jab, cross), body lean changing, plus a sharp white swoosh trail in a NEW direction every 1-2 hits | Mumen: a new smear direction every frame; Garou: a new pose every frame; Azure: an arc every 2-3 frames |
| Wind-up: a gliding two-shot | Push in to the attacker's face and eyes, then hold STILL 0.4-0.6 s, the scene darkening; a 1-frame victim insert just before contact | Acheron 1.4 s still; Serious Punch 1.2-1.7 s; Tanktop's eye push-in plus reaction insert |
| Blast: wide from the right, following | Cut to a camera in line with the throw: the target shoots straight AWAY from the lens; then an extreme wide hold of about 1 s | Garou vs Stinger 70 % to 25 % in 6 frames; Serious Punch's landscape |

The sound fix (heavier, louder barrage and hits) is a separate pass after this.

## The beats (times from the G press; the three hit times stay where the owner kept them, each freeze adds on top)

| t (s) | Beat | Camera | Bodies and effects |
|---|---|---|---|
| 0.00-0.40 | Lock-in | 2 black frames, then a low 3/4 close insert on the attacker's face and cocked fist; slow push | Glint on the fist; the rumble swells |
| 0.40-1.14 | RUSH | FIXED, low behind and above the attacker's start, aimed at the target; it does not move | Sprint, speeding up; dash trail; speed lines converge on the target |
| 1.14 | First hook | Flash 1 frame; SNAP to a low side 3/4 two-shot; freeze 0.2 s; jolt | The target pops up and back to ~1 body height |
| 1.4-3.4 | FLURRY | ONE held framing: low, waist height, side 3/4, slight dutch roll (~12 deg), both whole; only a slow drift; constant jitter | 16 punches, 4+ kinds in turn; a swoosh trail in a new direction every 1-2 hits; the target bobs half a body above, held ~1 body height off |
| 3.64 | Uppercut | Flash; SNAP to a worm's-eye front-side; freeze 0.25 s; jolt upward | Launch |
| 3.9-4.5 | Leap | Extreme wide worm's-eye, still; both small against the sky | Takeoff burst, air trail |
| 4.5-5.1 | Wind-up | Push in to the attacker's face and eyes over 0.3 s, then STILL; scene darkens | Fist glint; the haymaker held back |
| 5.10 | Silence | Same, still; 1-frame victim insert at 5.2 | Every sound cut |
| 5.25 | HAYMAKER | Freeze 0.15 s, then the 6 drawn impact frames | Our heavy hit |
| 5.6-7.0 | Result | Cut to a camera in line with the throw: the target shoots away from the lens; then an extreme wide hold ~1 s; flight | Shockwave; trail |

## Decisions (the owner, 2026-11-17, all three as recommended)

1. SNAP on the big hits: freeze, a 1-frame flash, a new angle, then a slow drift. The flurry stays one held shot.
   This reverses the earlier "no snap cuts".
2. SPACING about 1 body height (~4.5 studs root to root, the target half a body above). The fists don't touch;
   swoosh trails and hit bursts cover the gap (as in Azure).
3. SWOOSH TRAILS over the flurry: thin, sharp, white, one every 1-2 punches in a new set direction (no solid
   crescents, no black, nothing random), plus 4+ different punch poses in turn.

## Build order

1. Camera, freeze and shake: snaps under flashes, whole-scene freezes, the two kinds of shake, the fixed rush
   camera, the wind-up push-in and the result shot (the owner ranks camera first).
2. Spacing and the new flurry animation (4+ punch kinds, animations/build_strikes.luau).
3. Swoosh trails.
4. Sound pass: heavier, louder barrage and hits, measured against the references.
