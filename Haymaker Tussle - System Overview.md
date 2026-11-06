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

**Generated files, don't hand-edit:** `GameConfig` (from `design/game.json` via `gen_config.py`), `AnimClips` (`build_clips.py`), `AnimAssetIds` (`upload_clips.py`), `SoundBank` (roblox-sfx skill). The boot comments say the code is synced from disk with **Rojo**. If Rojo is in use, edits made only in Studio get overwritten on the next sync, so changes need to land in the source files on disk.

## Networking rules

- Every remote is declared in `Net.EventName`. A name not on the list is a bug.
- Client-to-server requests carry **no arguments, ever** (`PunchRequest`, `PropelRequest`, `KickRequest`, `KickAttach`, `KickCommit`, `ClashTap`, `TutorialDone`). Any arguments mean the request is refused.
- The server decides every hit, knockback, stagger and kick grade. Clients only say "I pressed".
- Each client owns and simulates its own body. The server measures speed itself (`SpeedAuditService`) and sends knockback to the body's owner.
- Known gaps the code admits: a cheating client could ignore knockback, or fly somewhere false during a kick chase.

## Server services

| Service | Job |
|---|---|
| **CombatService** | Punches. Rate limit (8/s token bucket), cooldown 0.32 s plus 0.1 s after a whiff, 0.1 s press buffer on the client. After the 0.08 s windup the swing is live for 0.05 s and is sampled every Heartbeat from the attacker's **current** root. Targets are rewound by ping + 0.05 s (capped at 0.15 s), the attacker never is. Punches resolve in strike order, and simultaneous ones that reach each other become a clash. A hit cancels the target's own wind-up. |
| **ClashService** | Two simultaneous punches: both are pinned 3.4 studs apart and mash for up to 2.5 s. A 14-tap lead wins, a gap of 1 or less at the timeout is a tie. The winner's finisher goes through normal knockback, capped at 130. Outside punches bounce off ("repel"). |
| **KickService** | Air kick. An uppercut marks the target `HT_Air="float"`. Jump (Space) → chase → attach (target held, `"hold"`) → timing ring → flip → impact, graded red, orange or green. A green stuns and bounces the target. 15 s cooldown. |
| **KnockbackService** | Sends launches to the owning client (or to DummyService). Players don't collide (`HT_Characters` collision group). Bumps are decided by the server every 0.05 s from closing speed. |
| **StaggerService** | Stagger 0-100, +12 per hit, -6 for landing a hit, recovers 10/s after 3 s. Published as the `HT_Stagger` attribute. Knockback multiplier rises to 2.5× at max. |
| **SpeedAuditService** | Samples positions every 0.05 s and keeps 1 s of history. Trusted speed is capped at 40. Provides `PositionAt` for rewind. |
| **PropelService** | Relays "X propelled" to other clients for effects. The propel itself runs client-side. |
| **DummyService** | Server-owned R6 dummies on the same Momentum rules. They never attack. They can be stationary (anchored) or patrol a line. |
| **TrainingService** | Builds the training hub and stations A-F, the floor pads, the launch pads and the `HT_InTraining` attribute. `AllowsFight` decides who can hit whom. |
| **TestFloorService** | Temporary floor at y=100 with rings and a wall, and respawns anyone who falls. |
| **TutorialService** | Records that the tutorial was done (tutorial is currently off). |

## Client controllers

| Controller | Job |
|---|---|
| **MovementController** | The big one (1,075 lines). Hijacks the stock `ControlModule.moveFunction` for input, then runs `Core/Momentum` and writes WalkSpeed/Move itself. Also handles knockback, the air-punch push, propel (Q), the air-kick chase/attach/flip (Space), clash alignment, the wall clamp, lean, and the top readout. |
| **CombatController** | Punch input (MouseButton1/R2). Plays the swing locally at once and sends `PunchRequest`. Shows a hit only when the server confirms it, timed to the animation's `Hit` marker. Taps during a clash. |
| **ShiftLockController** | The game's own shift lock. The stock one is disabled. Bound on **LeftShift/RightShift** via ContextActionService at High priority. Tells the stock camera `SetIsMouseLocked`, draws a dot over the head, and gives the mouse up to lock-on when asked. |
| **LockOnController / LockCameraController** | Marker on whoever you look at. Left Alt (released) or **E in Studio** or L1 locks the camera onto them. Display only. |
| **HitboxDebugController** | Draws the server's real attack shape from `PunchDebug`, plus blue hurtbox cylinders and verdict words. |
| **AnimController** | Plays every fighter's clips, plus hit stop, shake and tilt through the RootJoint C1. |
| **FxController** | Pooled wind puffs, hit bursts, the ground break on a kick jump, camera kick and sounds. |
| **KickPromptController** | The JUMP / KICK key prompt and timing ring. |
| **ClashController** | Barrage animation, pulses and the contest bar. |
| **TrainingController** | Testing panel readouts, and the client-only pads for the hitbox and panel toggles. |
| **KeybindController** | The controls list in the bottom right. It's static text, so it has to be updated by hand when a bind changes. |
| **TutorialController** | First-join tutorial. Off (`Tutorial.Enabled = false`). |

## Controls (current)

Click/R2 punch · Q/B propel · Space/Y air kick (and the timing press) · **Shift shift lock** · Alt (E in Studio)/L1 lock on. Jumping is disabled (`JumpEnabled = false`).

## Character attributes (the shared state)

`HT_Stagger`, `HT_Air` (`float`/`hold`), `HT_AirBy`, `HT_HoldFace`, `HT_Skill` (`chase`/`attach`/`flip`/`kick`), `HT_KickAt`, `HT_KickGrade`, `HT_Stunned`, `HT_Clash`, `HT_ClashAt`, `HT_ClashFace`, `HT_ClashScore`, `HT_Dummy`, `HT_Stationary`. On the player: `HT_InTraining`, `HT_ShiftLocked`, `HT_TutorialStep`. On workspace: `HaymakerCombatDebug` turns on server trace prints.

## The punch hitbox, precisely

`Combat.inHitbox` is three shapes unioned, with the target as an upright capsule of radius 1.5: the swing's sector (reach 5 over the hook or uppercut arc), a close sector (2.7 over ±100°), and a 2.5-stud contact disc. The vertical limit is 4.5. Line of sight is checked with three rays.

**Why it looks like you run past your own hitbox:** the server sample does follow you, but only for 0.05 s. `HitboxDebugController` positions the drawing **once**, at the moment the swing goes live (`phase == "active"`), then recolours it green or red and leaves it **parked in that spot for 0.45 s** (`LINGER_SECONDS`). At top speed (36 studs/s) you're about 16 studs past it by the time it disappears. The server also sees your body about one-way-ping late, so even the real check sits roughly a stud or two behind where your own screen shows you at speed.

Fix options, not applied yet:
1. **Visual (small):** keep each live drawing attached to its attacker's root every RenderStepped while it's showing, keeping the swing's facing.
2. **Gameplay (balance call):** lengthen `Punch.ActiveSeconds` so the real swing sweeps along with you, and/or lead the attacker's origin by trusted speed × one-way ping (capped). This changes how punches feel, and the vault's hitbox note says to use server positions with only slight slack for the attacker.

## Shift lock to Ctrl, where it lives

`ShiftLockController` → `BindActionAtPriority(..., Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)`. Swap these for `LeftControl`/`RightControl`, update the `KeybindController` row (`"Shift"` → `"Ctrl"`), and update the comments that say "Shift". Not applied yet.

## Things worth knowing

- `AnimAssetIds` is empty, so **no custom animation plays in a live game**. Clips are registered at runtime in Studio only. They need uploading before publishing.
- `Ui.playlist` is an unguarded `while true` loop over `SoundService.Music` that prints `12` every track. It errors if `Music` is missing and spins forever if the folder is empty.
- `Debug.MoveReadout`, `Debug.TestFloor` and `Debug.ShowHitbox` are all `true`. Turn them off for release.
- `TestFloor` doubles as the switch that lets two players outside training fight (`AllowsFight` returns `Debug.TestFloor`). Turning off the test floor turns off PvP until rounds exist.
- Arena and rounds settings exist in config (15 players, a shrinking radius), but no RoundService exists yet.
