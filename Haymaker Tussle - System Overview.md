---
tags: [project, haymaker-tussle, combat, architecture, type/reference]
---
# Haymaker Tussle - System Overview

Study of the Studio place "title" (placeId 136102156542862), build stamp `train-3`, read on 2026-11-05. Every game script was read. The third-party packages (Knit, Promise, Signal, Trove, Comm) and the bulk keyframe data in `AnimClips` were not read line by line.

## What the game is

A knock-them-off-the-edge brawler. Players run on momentum, punch in a left hook, right hook, uppercut combo, propel (dash/drift), and air-kick anyone an uppercut has launched. Stagger is knockback vulnerability, not health. Nothing does damage. You win by knocking people out of the arena. Rounds and the shrinking arena are configured but not built yet. A test floor and a training arena stand in for now.

## Layout

| Where | What |
|---|---|
| `ServerScriptService.Server` | Boot only: `Knit.AddServices(script.Services)`, then `Knit.Start()` |
| `ServerScriptService.Server.Combatants` | Who can be fought: anything tagged `HT_Combatant` that's alive |
| `ServerScriptService.Server.Services.*` | 11 Knit services (below) |
| `StarterPlayerScripts.Client` | Boot only: `Knit.AddControllers(script.Controllers)` |
| `Client.Controllers.*` | 13 Knit controllers (below) |
| `Client.Ui.*` | ClashBar, KickResultText, LockOnMarker, TrainingPanel, plus `playlist` (music loop) |
| `ReplicatedStorage.Shared.Core.*` | Pure maths, no instances: Combat, Momentum, Clash, DiveKick, AirRecovery, LockOn, LockCamera, TrainingLayout, Tutorial, GroundBreak, ResultPop |
| `ReplicatedStorage.Shared.Config` | `GameConfig` (every tunable), `AnimClips`, `AnimAssetIds`, `SoundBank` |
| `ReplicatedStorage.Shared.Net` | The only transport: plain RemoteEvents in `ReplicatedStorage.HaymakerTussleNet` |

About 13,500 lines of game code. Everything is `--!strict`.

**Generated files, don't hand-edit:** `AnimClips` (`build_clips.py`), `AnimAssetIds` (`upload_clips.py`), `SoundBank` (roblox-sfx skill). `GameConfig` was generated from `design/game.json`, but that contract isn't in the Rojo project, so `GameConfig.luau` is now the source and is edited directly. The code is synced from disk with **Rojo**, so edits made only in Studio get overwritten on the next sync; changes go in the files.

## Networking rules

- Every remote is declared in `Net.EventName`. A name not on the list is a bug.
- Client-to-server requests carry **no arguments, ever** (`PunchRequest`, `PropelRequest`, `KickRequest`, `KickAttach`, `KickCommit`, `ClashTap`, `TutorialDone`). Any arguments mean the request is refused.
- The server decides every hit, knockback, stagger and kick grade. Clients only say "I pressed".
- Each client owns and simulates its own body. The server measures speed itself (`SpeedAuditService`) and sends knockback to the body's owner.
- Known gaps the code admits: a cheating client could ignore knockback, or fly somewhere false during a kick chase.

## Server services

| Service | Job |
|---|---|
| **CombatService** | Punches. Rate limit (8/s token bucket), cooldown 0.32 s plus 0.1 s after a whiff, 0.1 s press buffer on the client. Hit detection is the team's `contact-2` (merged 2026-11-08): it sweeps every moment since its last look, from `Punch.GraceSeconds` before the active frames, on server-observed positions of both bodies (target rewound, capped at `MaxRewindSeconds`), throws point-blank hits along the attacker's facing, and gives a landing punch priority over a bump. Punches resolve in strike order, and simultaneous ones that reach each other become a clash. A hit cancels the target's own wind-up. |
| **ClashService** | Two simultaneous punches: both are pinned 3.4 studs apart and mash for up to 2.5 s. A 14-tap lead wins, a gap of 1 or less at the timeout is a tie. The winner's finisher goes through normal knockback, capped at 130. Outside punches bounce off ("repel"). |
| **KickService** | Air kick. An uppercut marks the target `HT_Air="float"`. Jump (Space) → the server picks the target and holds it (`"hold"`, `HT_HoldUntil`) → snap → attach → timing ring → flip → impact, graded red, orange or green. Orange and green are finishers that launch the target away and up; red slams it down. 15 s cooldown. |
| **KnockbackService** | Sends launches to the owning client (or to DummyService). Players don't collide (`HT_Characters` collision group). Bumps are decided by the server every 0.05 s from closing speed. |
| **StaggerService** | Stagger 0-100, +12 per hit, -6 for landing a hit, recovers 10/s after 3 s. Published as the `HT_Stagger` attribute. Knockback multiplier rises to 2.5× at max. |
| **SpeedAuditService** | Samples positions every 0.05 s and keeps 1 s of history. Trusted speed is capped at 40. Provides `PositionAt` for rewind and `Lead` for the attacker's lead. |
| **PropelService** | Relays "X propelled" (and whether boosted) to other clients for effects. The dash itself runs client-side. Also keeps a server copy of each player's nitro stamina and sets `HT_Nitro`, which draws the trail for everyone. |
| **DummyService** | Server-owned R6 dummies on the same Momentum rules. They never attack. They can be stationary (anchored) or patrol a line. |
| **TrainingService** | Builds the training hub and stations A-F, the floor pads, the launch pads and the `HT_InTraining` attribute. `AllowsFight` decides who can hit whom. |
| **TestFloorService** | Temporary floor at y=100 with rings and a wall, and respawns anyone who falls. |
| **TutorialService** | Records that the tutorial was done (tutorial is currently off). |

## Client controllers

| Controller | Job |
|---|---|
| **MovementController** | The big one (1,075 lines). Hijacks the stock `ControlModule.moveFunction` for input, then runs `Core/Momentum` and writes WalkSpeed/Move itself. Also handles knockback, the air-punch push, propel (Q), the air-kick chase/attach/flip (Space), clash alignment, the wall clamp, lean, and the top readout. |
| **CombatController** | Punch input (MouseButton1/R2). Plays the swing locally at once and sends `PunchRequest`. Shows a hit only when the server confirms it, timed to the animation's `Hit` marker. Taps during a clash. |
| **ShiftLockController** | The game's own shift lock. The stock one is disabled. Bound on **Left Ctrl** (`GameConfig.Controls.ShiftLock`) via ContextActionService at High priority; passed on while typing. Tells the stock camera `SetIsMouseLocked`, draws a dot over the head, and gives the mouse up to lock-on when asked. |
| **LockOnController / LockCameraController** | Marker on whoever you look at. Left Alt (released) or **E in Studio** or L1 locks the camera onto them. Display only. |
| **HitboxDebugController** | Draws each swing's real attack volume at its height, attached to the attacker for exactly the live window, plus blue hurtbox cylinders and verdict words. |
| **AnimController** | Plays every fighter's clips, plus hit stop, shake and tilt through the RootJoint C1. |
| **FxController** | Pooled wind puffs, hit bursts, the ground break on a kick jump, camera kick and sounds. |
| **KickPromptController** | The JUMP / KICK key prompt and timing ring. |
| **ClashController** | Barrage animation, pulses and the contest bar. |
| **TrainingController** | Testing panel readouts, and the client-only pads for the hitbox and panel toggles. |
| **KeybindController** | The controls list in the bottom right. Shared keys come from `GameConfig.Controls`; it also shows the reserved Shift nitro row. |
| **TutorialController** | First-join tutorial. Off (`Tutorial.Enabled = false`). |

## Controls (current)

Click/R2 punch (hold to repeat) · Q/B dash (A or D curves it) · Space/Y air kick (and the timing press) · **Left Ctrl shift lock** · Alt (E in Studio)/L1 lock on · Left Shift/L3 held for nitro. Jumping is disabled (`JumpEnabled = false`). The keys come from `GameConfig.Controls`. Details: [[Haymaker Tussle - Controls and Punch Hitbox]].

## Character attributes (the shared state)

`HT_Stagger`, `HT_Air` (`float`/`hold`), `HT_AirBy`, `HT_HoldFace`, `HT_Skill` (`chase`/`attach`/`flip`/`kick`), `HT_KickAt`, `HT_KickGrade`, `HT_Stunned`, `HT_Clash`, `HT_ClashAt`, `HT_ClashFace`, `HT_ClashScore`, `HT_Dummy`, `HT_Stationary`, `HT_Nitro`, `HT_HoldUntil`. On the player: `HT_InTraining`, `HT_ShiftLocked`, `HT_TutorialStep`. On workspace: `HaymakerCombatDebug` turns on server trace prints.

## The punch hitbox, precisely

Superseded on 2026-11-08 by `contact-2` (see the CombatService row above, `HANDOFF.md` and `design/Settings Guide.md`). The description below is the 2026-11-05 version, kept for its measurements.

`Combat.inHitbox` is a volume over three flat shapes unioned, against the target's hurtbox: an upright capsule of radius 1.5, from 3 under the root to 2.5 over it. The shapes are the swing's sector (reach 5 over the hook or uppercut arc), a close sector (3 over ±100°) and a 3-stud contact disc. Hooks span -2 to +1.5 from the root and uppercuts -1.5 to +2.5. Line of sight is checked with three rays. The swing is live from 0.08 s to 0.16 s and swept between server frames. The attacker is led forward by the server-measured physics delay, and targets are rewound by ping + 0.175 s. All the sizes, timings, the reasons and the test results are in [[Haymaker Tussle - Controls and Punch Hitbox]].

## Things worth knowing

- `AnimAssetIds` is empty, so **no custom animation plays in a live game**. Clips are registered at runtime in Studio only. They need uploading before publishing.
- `Ui.playlist` is an unguarded `while true` loop over `SoundService.Music` that prints `12` every track. It errors if `Music` is missing and spins forever if the folder is empty.
- `Debug.MoveReadout`, `Debug.TestFloor` and `Debug.ShowHitbox` are all `true`. Turn them off for release.
- `TestFloor` doubles as the switch that lets two players outside training fight (`AllowsFight` returns `Debug.TestFloor`). Turning off the test floor turns off PvP until rounds exist.
- Arena and rounds settings exist in config (15 players, a shrinking radius), but no RoundService exists yet.
