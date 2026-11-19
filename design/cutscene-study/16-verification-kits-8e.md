# Haymaker Rush kits-8e: Phase 7 verification and report (2026-11-18)

This is the brief's Phase 7 for the current build, `kits-8e+lobby-4+ui-19d`. The brief's report items 1-4 (findings,
reference breakdown, gap analysis, to-do list) are in `11-synthesis-gaps-storyboard-todo.md` and are not repeated here.
This note covers items 5-7: what changed since, what was verified, and what is still open.

## How it was checked

- **A live ultimate in Play**, not the replay tool. A helper Script in ServerScriptService (it shares the game's Knit)
  filled the meter and opened the window on `Punching Dummy 1`, and the client fired `UltimateRequest`. The bots were
  frozen (`HT_BotsFrozen`).
- **A client logger** recorded, at every rendered frame:
  - the target and attacker root positions and `Anchored`;
  - the camera type and FOV;
  - each drawn-impact screen's start and end;
  - every Sound created.
- **A 20 s recording** of the viewport: `design/references/ours-kits-8e-live.mp4` (ignored). The final-punch contact
  sheet is `16-kits-8e-final-punch-sheet.png`, where sheet time + about 3.9 s = cutscene time.
- **Control check:** W was pressed after the end; the character walked 38.6 studs.
- **Interrupt test:** the ultimate was fired again and the attacker killed 5.57 s in, during the slow sink.
- **Limit:** Studio rendered about 11 fps (median frame 0.086 s, worst 0.276 s). Timing and states are measured;
  smoothness and sound are NOT judged here. The owner has to watch and listen.

## Acceptance checklist (live, kits-8e)

| Check | State | Evidence |
|---|---|---|
| Torso faces the fist at the uppercut and the final punch | Pass (measured) | Offline: 32 and 0 deg off square (tests, `lune/contact_check`). Live sheet 1.4-2.2: fist in the chest front, target folded onto it |
| The opening reads as a rush | Not judged this pass | kits-8b's arm fix was seen in the kits-8d replay video. At 11 fps the run can't be judged |
| Uppercut launches far enough | Pass (seen) | Sheet 0.4-0.6: the target small and far in the dash shot |
| Dash covers the distance, target kept in frame | Pass (seen); sliding not judgeable | Sheet 0.4-0.8 |
| No arm rotation or dead wind-up before the final punch | Pass (measured) | Arm aim constant (test); 0.07 s snap |
| Knockback starts on the hit | Pass (live) | From the contact the target moves 0.7-2.8 studs/s, never stops, then 0.9 to 13.6 after the blast |
| Target not held anchored | Pass (live) | No frame anchored, for either fighter |
| Camera keeps both readable | Pass with a note | Camera spec passes. The sink shot (sheet 1.4-2.2) is nearly still for 0.8 s, see below |
| Anticipation, contact, follow-through, recovery connected | Partly | Order and timing are right. Smoothness not judgeable at 11 fps |
| Screen effects timed, not hiding the hit | **Fail (known)** | Drawn runs on time (contact 4.94 s, plunge 6.19 s). But the uppercut and blast hits throw big white-blue rings and beams over the bodies (sheet 0.0, 2.6): stage D/E |
| Everything restored after the sequence | Pass (live) | Camera Custom, FOV 70, HUD and core UI back, no cutscene GUIs or grade left, role cleared, control back (walked 38.6 studs) |
| Interrupt-safe | Pass (live) | Attacker killed mid-sink: after the respawn, camera, HUD, core UI, grade and roles all restored, no errors or warnings, dummy released and home. Note: the cutscene plays on until the dead body is removed (3 s), so the plunge still showed |

## Live timing measured (cutscene seconds)

| Event | Planned | Live |
|---|---|---|
| Haymaker contact, sound `ult_haymaker` | 4.93 | 4.94 |
| Contact drawn run | 4.93-5.27 | 4.94-5.39 |
| Plunge drawn run | 6.12-6.55 | 6.19-6.64 |
| End (UltimateEnded) | 8.18 | 8.18 |

Both runs ran about 0.1 s long and the plunge started 0.07 s late. That is one or two of Studio's 11 fps frames: a run
starts on the first frame after its cue and ends on the first frame after its length. At 60 fps the error is 1/60 s.

## Findings that need the owner

1. **FIXED in kits-8f (see the end of this note). The slow sink reads almost still.**
   - The target moves about 0.9 studs/s for 0.85 s. On the sheet (1.4-2.2) five frames look nearly the same.
   - That's what was asked ("the part where the fist sinks in should be longer"). But a body barely moving can read
     as a pause, not a sink.
   - Options: push the fist in visibly (the attacker following the target, the fold deepening over the sink), or a
     slow push-in of the camera.
   - Needs the owner's eye at full speed.
2. **The sound doesn't follow the new timing.**
   - After the hit, the only sound is `ult_haymaker` (2.60 s long, from 4.94 to 7.54). It carries the whole sink and
     the blast.
   - Its built-in sinking boom was placed for the old 0.8 s slow part. It now lands in the middle of the sink, not on
     the blast at 6.55. Nothing marks the plunge or the blast.
   - This is the open sound pass.
3. **The rings cover the hits** at the uppercut and the blast (PunchHitFx with rings and beams). This is the open
   stage D/E effects pass (`11` to-do 14).
4. **Death mid-cutscene:** the cutscene ends only when the attacker's body is removed, so 3 s more plays on a dead
   attacker. It's harmless, but ending it on `Humanoid.Died` would be cleaner.

## What changed since `11` (report item 5)

- **kits-8b:** the rush arm, the rush and uppercut cameras, and the final zoom.
- **kits-8c/8d:** the launch and dash retimed from measurements (`13`).
- **kits-8e:** the two drawn impact runs (`Fx/DrawnImpact`, 18 uploaded frames) replace the procedural cards, and the
  slow part is 1.62 s (`Core/Ultimates.DRAWN`, `SLOW_TO`, the `plunge` cue). See HANDOFF kits-8e.

## Not accessible / not checked (report item 7)

- Real-speed smoothness and sound: Studio renders at 11 fps here, and no audio is recorded.
- Phone: framing is covered by the camera spec on three screen shapes; nothing ran on a device.
- A target that is a player, not a dummy: only a dummy was tested (the server poses dummies; a player target poses on
  their own client).

## kits-8f (same day): the sink fixed at the root

- **Cause, measured** with the new `lune/sink_check`:
  - The fist was 0.22 into the chest at the contact, then backed out: 0.74 studs clear by the plunge, 1.0 by the
    blast.
  - The attacker crept 0.2 studs/s while the target slid away at 0.93. On screen that was a gap opening slowly, which
    read as a freeze.
- **Fix (`Core/Ultimates`):**
  - The attacker is carried along the drive with the target (`CARRY_SOAK` 1, `CARRY_SLOW` 2.45, `CARRY_THROWN` 2.9).
  - The fold deepens to `SINK_FOLD` (-22 deg) by the blast.
  - The sink shot pushes in slowly: FOV 54 to 50, the camera from 6 to 5.1 studs out.
- **Measured after:**
  - The fist tip goes 0.22 → 0.43 (contact frames end) → 0.58 (plunge) → 0.65 (blast). It never backs out and never
    nears the torso's back.
  - Attacker 1.17 studs/s and target 0.93 studs/s through the sink.
- **Test:** "the fist sinks deeper through the slow part, and nothing stands still". The camera spec still passes on
  phone, desktop and tablet.
- **Seen in Studio** (replay held at 5.45 and 6.08 s): the arm is driven into the folded torso. By 6.08 s the camera
  has pushed in, the fold is deeper, and both bodies have travelled.
- **Not judged:** full speed with sound (the owner).
