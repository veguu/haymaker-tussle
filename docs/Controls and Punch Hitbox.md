---
tags: [project, haymaker-tussle, combat, hitbox, controls, type/reference]
---
# Haymaker Tussle - Controls and Punch Hitbox

Changed 2026-11-05. Every number here lives in `GameConfig` (`Punch` and `Controls`), the single place to tune it. Background: [[Haymaker Tussle - System Overview]], and the general lesson in `56 Field Notes/Server Melee Checks Run on Stale Positions.md`.

## Controls

| Key | Does | Where |
|---|---|---|
| Left Ctrl | Shift lock on and off (same camera behaviour as before) | `ShiftLockController`, key from `Controls.ShiftLock` |
| Left Shift | **Nothing yet.** Reserved for nitro. Shown as "Nitro — Coming soon", dimmed | `Controls.Nitro` (`ComingSoon = true`), shown by `KeybindController` |
| Alt (E in Studio), L1 | Lock on, unchanged | `LockOnController` |

- Ctrl is bound once (`HaymakerShiftLock`, High priority). It's passed on untouched while typing in a text box, while a menu is open, and while the lock-on camera holds the mouse.
- Roblox's own shift lock stays off: `StarterPlayer.EnableMouseLockOption = false` (now also set in `default.project.json`), and the stock `MouseLockSwitchAction` is disabled every frame. No script binds Left or Right Shift.
- The controls panel now hides rows that belong to another device (the gamepad list used to leave the keyboard's last row showing) and is 300 px wide.
- There's no shift-lock wording in the tutorial (it's off) or the kick prompt, so nothing else needed changing.

To build nitro later: bind `Controls.Nitro.Key` in `MovementController` (it owns movement), set `ComingSoon = false`, and change the panel text.

## What was wrong with the hitbox

Reproduced in Studio Play, running at full speed past the stationary station D target:

1. **The real attack was judged from a stale attacker.** The server saw the runner about **0.18 s** late (measured; it's the physics buffer for a client-owned body, present even with zero network lag). At 36 studs/s that put the swing **6.8 studs behind** the runner. A punch that clearly reached the target on screen was rejected for range from 11 studs away.
2. **Targets were rewound too little.** Clients show other bodies about **0.175 s** behind the server (measured on the moving dummy). The rewind was `ping + 0.05`, capped at 0.15, so a moving target was tested several studs from where the attacker saw it.
3. **The drawing was misleading.** It was drawn once, at floor height (2.4 studs under the root), from the server's stale position, and then left in place for 0.45 s. At speed it ended up 7 to 20 studs behind the runner.
4. **The live window was a few frame checks.** It was 0.05 s, checked once per server frame, so a crossing could fall between checks.

The facing was already read fresh every frame, but it came from the same stale view as the position. Animation timing was fine: every punch clip's Hit marker is at 0.08 s, the same as `Windup`.

## The hitbox now

### Timing
| | Value |
|---|---|
| Windup (goes live) | 0.08 s after the press, on the clips' Hit marker |
| Active window | **0.08 s** (0.08 to 0.16 s), the fist sweeping from the strike to full extension, measured from the clips (was 0.05) |
| Checking | Swept between server frames in steps of at most `SweepStepStuds` 0.5, up to 12 per frame, with both bodies and the facing interpolated. Only the active window is checked. |
| Per target | Once per swing; the swing can still hit more than one target |

### Shape (horizontal, centre to centre once TargetRadius is added)
| Part | Value | Change |
|---|---|---|
| Forward reach | `Range` 5 + `TargetRadius` 1.5 = **6.5** | unchanged |
| Left hook arc | 55° out on its own side, 30° past centre | inner side was 20° |
| Right hook arc | mirror of the left | inner side was 20° |
| Uppercut arc | ±20° | unchanged |
| Close sector | `CloseRange` 3 + 1.5 = **4.5** over ±100° | was 4.2 |
| Contact | `OverlapRadius` **3** = two body radii, any direction | was 2.5 |

### Heights (from the root part)
| | Low | High |
|---|---|---|
| Hurtbox (receiving capsule, ignores accessories) | -3 (feet) | +2.5 (top of head) |
| Hook volume | -2 | +1.5 |
| Uppercut volume | -1.5 | +2.5 |

The hurtbox has to touch the volume, so hooks connect from 4.5 below to 4.5 above, exactly as before, and an uppercut from 4 below to 5.5 above, since its fist rises above the head (measured up to +4.2).

### Following the character
- The swing is judged from the attacker's **current** position and facing every frame. A player is led forward by `AttackerLeadSeconds` **0.18** along the motion the server itself measured (`SpeedAuditService:Lead`, about 0.1 s of history, speed capped by `AttackerLeadMaxSpeed` 90). Nothing comes from the client.
- There's no turn limit and no aim assist: the facing is the body's own, as `MovementController` turns it.
- Targets rewind by `ping + InterpolationSeconds` **0.175**, capped at `MaxRewindSeconds` **0.3**.
- Line of sight (three rays) still has to be clear, so nothing hits through walls.

## The display (same Hitboxes toggle as before)
- The attack volume is drawn as a prism at its real height band, from `Combat.hitboxOutline(..., bare)` and `Combat.swingBand`, the same rules the server uses.
- It's re-placed on the attacker every frame, at their position and current facing.
- It's bright white for exactly the server's live window, then a faint green (landed) or red (missed) after-image for 0.35 s that is no longer live.
- Blue hurtbox cylinders match the receiving capsule. A hit is the volume touching a cylinder.
- The pink rings around the station D target are the floor reach guide (centre to centre), separate from the volume.
- The verdict words and tested-position balls are unchanged.

## Verified in Studio (one player, dummies, 2026-11-05)
- Ctrl toggles shift lock on and off; Left and Right Shift do nothing; Ctrl is ignored while typing and during lock-on; E lock-on works and hands the mouse back.
- At a standstill: 4 and 6.37 studs ahead hit; 6.96 ahead misses (range); 4.37 to either side hits; 2.76 behind (overlapping) hits; 3.44 behind misses (facing); 4.93 at 65° and 4.58 at 109° both miss.
- At full speed (36): the server origin is within 0.1 to 0.5 studs of the runner (was 6.8 behind). Passing 2 and 4.2 studs to the side hits; pressing 17.7 studs early misses (range); pressing after passing misses (facing).
- Head-on through the moving dummy (62 studs/s closing): pressing 6 studs apart hits; pressing when already overlapping misses, because the bodies have passed by the time the swing is live.
- A wall between the two blocks the punch; without the wall, the same spot hits.
- Each hit counts once (hits = 1 throughout the overlap).
- The uppercut still launches (the dummy rose 57 studs), and the air kick runs through chase, attach, grade and impact.
- The client ran at 15 fps throughout and the server at 60. In simulation the sweep gives the same results at 20, 30, 60 and 240 Hz.

## Still needs a multiplayer playtest
- Two real players crossing: the attacker lead and target rewind against real ping. Re-measure both delays on a live server, because they adapt to the network.
- Clashes and punch cancelling between two players (the timing rules are untouched, but the volume and window changed).
- Multi-target hits (the dummies can't be packed together for a test).
- Airborne M1 recovery punches against other players.
- High-ping clients, where the rewind cap of 0.3 s starts to bind at about 125 ms of ping.
