# Haymaker Tussle - settings guide
<!-- tldr:start -->
> [!tldr] TL;DR
> - Two opponents whose punches land at effectively the same moment, and would each reach the other, clash instead of one...
> - The first-join tutorial. All values are starting guesses.
> - TEMPORARY: the test floor's opponent. It only exists when one player is alone in the server.
> - The air kick. An uppercut launches someone, who can steer and propel in the air.
>
> Cost: TL;DR ~130 tok · whole note ~11.2k tok. Read more: ## Effects · ## Kick
<!-- tldr:end -->


Every adjustable value in the game. All numbers are **starting guesses to tune by playing**, not measured results.

- **Change a value:** edit `config` in `design/game.json`, then regenerate the module:
  `python ~/.claude/skills/create-roblox-game/scripts/gen_config.py --dir <project>`
- **The game reads:** `src/shared/Config/GameConfig.luau`, generated from that file. Don't edit it by hand.
- **Marked PROVISIONAL or EDITABLE:** defaults from the brief that are expected to change.

## Movement

| Setting | Start | What it does |
|---|---|---|
| `Acceleration` | 42 | Studs/s gained per second while holding a direction. Higher = quicker to top speed. |
| `MaxSpeed` | 36 | Top running speed in studs/s (default Roblox walk is 16). |
| `CoastHoldSeconds` | 0.4 | Seconds speed stays unchanged after releasing W, before it starts to fall. |
| `CoastFallSeconds` | 2 | Seconds from the end of the hold to a full stop. |
| `CoastFallCurve` | 1.5 | Shape of the fall. 1 is a steady drop; higher starts gentler and ends sharper. |
| `BrakeDeceleration` | 60 | Studs/s lost per second while holding S and moving. At 60, full speed stops in 0.6 s. |
| `PropelSpeed` | 84 | Top speed of a dash (Q), a short burst the way you are already going (from a standstill, the way the keys point). It eases up to this, holds it, then eases back down to running speed. |
| `PropelSeconds` | 0.65 | How long the whole dash lasts, its ramp and ease-out included. |
| `PropelRampSeconds` | 0.1 | Seconds of easing up to `PropelSpeed`. Lower = a harder start. It's eased, so speed never jumps from one frame to the next. |
| `PropelCooldown` | 3 | Seconds from pressing propel until it can be pressed again. |
| `PropelEaseOutSeconds` | 0.28 | Seconds at the end of the dash easing from `PropelSpeed` back to running speed. |
| `PropelTurnScale` | 0.28 | Share of the normal turn rate (`TurnRateHighSpeed` at dash speed) the keys get during a dash: 0.28 is about 150°/s, so it bends but turning is hard. Input more than a right angle off the travel is ignored, so it can never be turned round. |
| `PropelControlReturnSeconds` | 0.25 | After a dash, steering eases from `PropelTurnScale` back to normal over this long instead of all at once. |
| `PropelChargeSeconds` | 1 | Holding the dash key charges it. This is the longest hold that counts: at this many seconds it is fully charged and goes by itself. Letting go earlier dashes at whatever it has built. |
| `PropelChargedSpeed` | 140 | Top speed of a fully charged dash. A tap is `PropelSpeed`; a part charge sits in between. |
| `PropelChargedTurnScale` | 0.08 | Share of the normal turn rate the keys get during a fully charged dash. A tap is `PropelTurnScale`; the more charge, the harder it is to steer. |
| `SideStopDeceleration` | 45 | Studs/s lost per second after releasing A, D or S. Only W earns the coast. |
| `CoastMaxAngle` | 45 | When you let go of A or D, you only keep the long coast if you're heading within this many degrees of where the camera looks. Further off, you stop quickly at `SideStopDeceleration`. Letting go of W always coasts, wherever the camera turns afterward. |
| `ForwardInputThreshold` | 0.3 | How much of the input must point along the camera to count as W (or against it, as S). W+D counts as W. |
| `CoastDeceleration` | 7 | Only used when a thumbstick is eased back to a lower target speed while still pushed. |
| `ReverseDeceleration` | 50 | Studs/s lost per second while W steers hard against travel, so a reversal is a readable turn. A and D alone never lose speed this way.
| `TurnRateLowSpeed` | 720 | Degrees/s the travel direction can bend at or below TurnBlendLowSpeed. |
| `TurnRateHighSpeed` | 540 | Degrees/s the travel direction can bend at MaxSpeed. Lower = wider arcs. Full-speed turn radius is MaxSpeed / this in radians: about 3.8 studs at 540. A quarter turn takes about 0.17 s. |
| `TurnBlendLowSpeed` | 8 | Speed below which turning uses the full low-speed rate. |
| `AirControl` | 0.25 | Share of normal steering and acceleration available in the air (0 to 1). The body also has `Kick.LaunchSteerSpeed` of steering on top in the air. |
| `KnockbackResist` | 0.2 | How strongly movement input can fight existing knockback (0 = none, 1 = fully). |
| `KnockbackDecay` | 60 | Studs/s of knockback velocity lost per second while grounded. |
| `InputDeadzone` | 0.05 | Stick or key input shorter than this counts as no input. |
| `RestSnapSpeed` | 1 | At or below this speed the character faces the input at once. |
| `FacingResponsiveness` | 60 | How quickly the body rotates to match the heading. |
| `LeanResponsiveness` | 10 | How quickly the lean settles into and out of a curve. |
| `WallSpeedMargin` | 6 | Momentum can only run this far above real speed, so hitting a wall really stops you. |
| `KnockbackAirDecay` | 20 | Studs/s of knockback lost per second in the air. Low, so big hits really fly. |
| `KnockbackMaxSpeed` | 250 | Hard cap on stacked knockback. |
| `HitSpeedKeep` | 0.3 | Share of running speed kept when hit. Steering is never disabled. |
| `KnockbackGraceSeconds` | 0.2 | Time after a hit before a wall check can reduce the launch. |
| `LeanMaxDegrees` | 18 | Largest visible body lean into a curve. |
| `JumpEnabled` | false | EDITABLE DEFAULT from the brief: jumping is off in the first prototype. |

## Punch

| Setting | Start | What it does |
|---|---|---|
| `Cooldown` | 0.32 | Seconds between accepted punches. |
| `Windup` | 0.08 | Seconds from accepted punch to the server's hit check. Must match the clips' strike time. |
| `ActiveSeconds` | 0.05 | How long a swing stays live after the strike. The server checks it every frame in that time, so someone crossing fast can't slip between checks. Each target is only ever hit once per swing. |
| `MissRecovery` | 0.1 | Extra seconds before the next punch after one that hit nobody. It's what makes baiting a whiff worth it. |
| `BufferSeconds` | 0.1 | A press this close before the swing is ready is remembered and thrown when it is. Only one is held, and it's dropped if it gets older than this or you can't punch. |
| `Range` | 4.5 | Radius of a swing's reach, from the attacker's root. A target connects when its hurtbox touches it, so the most centre to centre is `Range` + `TargetRadius`, 6.5. Lowered from 5 when `TargetRadius` went back to 2, so reach stayed 6.5. |
| `HookOuterDegrees` | 55 | How far to its own side a hook reaches: left for a left hook, right for a right hook. |
| `HookInnerDegrees` | 20 | How far past straight ahead a hook carries, across the body. |
| `UppercutDegrees` | 20 | The uppercut's arc, either way. It's the narrow swing. |
| `CloseRange` | 2.2 | Radius of the close sector, for someone at your side. With `TargetRadius` it reaches 4.2 studs centre to centre, a little past two characters exactly shoulder to shoulder at 4. Lowered from 2.7 with `TargetRadius` 2, so it's unchanged. |
| `CloseDegrees` | 100 | How far round from straight ahead the close sector goes, either way. Under 180 means someone behind you has to be inside `OverlapRadius`. |
| `OverlapRadius` | 2.5 | Anyone within this many studs, centre to centre, can be hit from any direction, so running through someone still connects. |
| `ComboResetSeconds` | 2 | Seconds without punching before the next swing goes back to the left hook. |
| `HitCancelsPunch` | true | A punch still winding up is cancelled if its thrower gets hit first, so whoever lands first wins the exchange. |
| `MissSpeedKeep` | 0.7 | Share of running speed kept when a punch hits nothing, on the ground only. Lower = a harsher penalty for missing. |
| `HitRecoilSpeed` | 20 | Studs/s the puncher is pushed back when a punch lands. 20 slides about 3 studs. In the air it's scaled by `AirRecovery.HitRecoilShare`. |
| `HitSpeedKeep` | 0 | Share of running speed the puncher keeps when a punch lands, on the ground only. 0 stops them dead. |
| `TargetRadius` | 2 | The hurtbox: the radius of the upright capsule that can receive a hit, the same for everyone, whatever they're wearing. 2 covers the whole R6 body (arms reach 1.46 from the centre); it was 1.5 from air-29 until recover-1. A bumped victim slides out of this, so a bump isn't a free hit. |
| `VerticalLimit` | 4.5 | Largest height difference in studs that can still be hit. |
| `CooldownTolerance` | 0.06 | Forgives honest presses arriving bunched by a network hiccup. |
| `MaxRewindSeconds` | 0.15 | Most the server will look back for a high-ping attacker. |
| `InterpolationSeconds` | 0.05 | Added to the attacker's round-trip ping when looking back, for how far behind other players are drawn on their screen. An estimate: check it in real multiplayer. |
| `GraceSeconds` | 0.05 | **Punch forgiveness.** How far before the active frames a swing still looks for contact, so bodies that crossed just before it went live count as a hit (resolved at the normal impact time). Never reaches back before the press was accepted. 0 turns it off. The test "the grace ends where it says" shows the boundary. |
| `SweepStep` | 0.008 | Seconds between the moments a swing checks, back to the last check, using where the server saw both bodies. Catches contact that happens entirely between two server frames. Smaller is finer and costs more. |
| `PointBlankRadius` | 0.75 | Closer than this, centre to centre, a landed punch throws the target the way the attacker faces instead of along their (noisy) offset, so exact overlap gets a steady shove. |
| `RequestsPerSecondLimit` | 8 | Server rate limit on punch requests; extras are dropped. |

## Clash

Two opponents whose punches land at effectively the same moment, and would each reach the other, clash instead of one cancelling the other. Whoever taps more wins and lands one finishing punch.

| Setting | Start | What it does |
|---|---|---|
| `Enabled` | true | Off, simultaneous punches go back to whoever's lands first. |
| `Window` | 0.05 | Largest gap between two punches' strike times, in seconds, that still counts as the same moment. Wider means more clashes, and less reward for being first. |
| `LatencyMax` | 0.03 | The most the window widens for the two players' ping, because their press times are estimates. |
| `HoldMax` | 0.1 | The longest a landed punch waits for a high-ping target's simultaneous press to arrive. Usually no wait at all. |
| `Seconds` | 2.5 | A clash's longest possible length. |
| `WinLead` | 14 | A lead this large in taps wins at once. |
| `TieMargin` | 1 | At the time limit, a gap this small or smaller is a tie: no winner, both pushed apart. |
| `MaxTapsPerSecond` | 14 | The fastest tapping that counts. Extra taps are dropped. |
| `TapBurst` | 3 | How many taps can arrive bunched together by a network hiccup. |
| `Standoff` | 3.4 | Studs apart, centre to centre, the two are drawn to. |
| `AlignSpeed` | 40 | Fastest they move to get there, in studs/s. |
| `AlignGain` | 6 | How hard they close on the spot: studs/s per stud away. Much higher and a Humanoid overshoots and wobbles: 12 did, up to 2.5 studs. |
| `AlignDeadband` | 0.2 | This close to the spot counts as there. |
| `FinishShare` | 1.3 | The finishing punch's knockback as a share of a standing punch at the loser's stagger. |
| `FinishMaxSpeed` | 130 | Cap on the finishing punch's knockback, in studs/s, however staggered the loser is. |
| `FinishStagger` | 18 | Stagger the finishing punch adds. A normal hit's is `Stagger.PerHit`. |
| `TieShare` | 1 | A tie knocks both fighters back away from each other with the SAME strength: this share of a standing punch at no stagger (capped by `FinishMaxSpeed`), with the normal knockback lift. Neither one's stagger changes it, and no stagger is added. Replaces `TiePush` (a flat 28 studs/s shove). |
| `PairCooldown` | 1 | Seconds before the same two can clash again. |
| `RepelSpeed` | 35 | Studs/s an outside attacker is knocked back by punching someone in a clash. 50 measured 21 studs of slide. |
| `RepelCooldown` | 0.75 | Seconds before the same attacker can be repelled again, so overlapping attacks can't stack. |
| `ResultSeconds` | 1.2 | How long the bar shows the result before fading. |
| `PulseSeconds` | 0.14 | How often the impact effect goes off between them, for show. It matches the barrage's punches. |
| `BarScreenY` | 0.86 | Where the bar's bottom edge sits, as a share of screen height. |
| `BarWidthShare` | 0.42 | The bar's width as a share of the screen. It stays clear of the keybind panel and the touch buttons. |
| `BarHeightShare` | 0.1 | The bar's height as a share of the screen. |
| `BarEase` | 14 | How quickly the bar's fill catches up with the server's score. |

## Knockback

| Setting | Start | What it does |
|---|---|---|
| `BaseSpeed` | 23 | Launch speed in studs/s of a punch from a standing attacker on a target with no stagger: about 4.6 studs of slide (measured), so one step puts you back in reach. Was 55 (26 studs of slide) until build contact-1. |
| `SpeedBonusPerStud` | 0.38 | Extra launch speed per stud/s of the attacker's server-measured speed. Scaled down with `BaseSpeed` (was 0.9). |
| `UpwardFraction` | 0.18 | Share of launch speed added upward on a grounded target. |
| `UpwardMax` | 16 | Hard cap on upward launch speed. |
| `AirborneUpwardFraction` | 0 | Share added upward if the target is already airborne; 0 stops punches juggling anyone into the sky. |
| `UppercutLift` | 125 | Studs/s upward from an uppercut, on top of its normal punch push. With `Kick.AirGravityScale` that's about 57 studs high (measured +56 to +57), and about 1.7 s in the air with the falling rule in `AirRecovery`: 0.9 s up, 0.8 s down. |
| `BumpPropelShare` | 0.4 | A bump's shove at its hardest, as a share of `Movement.PropelSpeed`: 34 studs/s, about 10 studs of slide. Stagger doesn't add to it. A test checks that it stays under half a propel, even with the faster player's edge. |
| `BumpFullClosing` | 36 | Collision speed for a full shove. Softer collisions shove less. |
| `BumpSoftShare` | 0.4 | The softest a bump can be, as a share of the full shove. |
| `BumpSpeedKeep` | 0.6 | Share of running speed both keep through a bump. |
| `BumpStaggerShare` | 0.25 | A bump's stagger as a share of a punch's: 1.8, or 2.1 and 1.5 with the full edge below (rounded to a tenth). If a punch lands on the same impact, only the punch counts. |
| `BumpFullAdvantage` | 30 | How much faster one player must be moving, in studs/s, to get the whole edge below. Less gets part of it, and level speeds get none. |
| `BumpEdgeShare` | 0.15 | The faster player's whole edge: they shove 15% harder and add 15% more stagger, and take 15% less of both. |
| `BumpMinClosingSpeed` | 10 | Two players must close at this speed or more to bump. Softer collisions than this do nothing at all. |
| `BumpDistance` | 3.5 | Two characters this close can bump. |
| `BumpVerticalLimit` | 4 | Largest height difference that can still bump. |
| `BumpPairCooldown` | 0.5 | Seconds before the same two players can bump again. |
| `BumpReleaseMargin` | 0.5 | A bump is coming into contact, once. Contact ends only when the two are this much further apart than `BumpDistance`, so leaning on someone never bumps twice. |
| `BumpPunchGuard` | 0.25 | A punch between the same two that landed up to this long before a bump counts as the same impact, and the bump is dropped. |
| `BumpHoldSeconds` | 0.1 | A bump waits this long before it happens, so an M1 pressed just before contact can reach the server and take the impact instead. Bumps arrive this much later. 0 makes bumps instant. |
| `BumpDeferMax` | 0.35 | Longest a bump waits on a swing between the same two before it's given up. |
| `BumpMaxSweep` | 25 | A jump in the gap between two checks bigger than this, in studs, is a teleport (respawn), not a fast crossing, so it never bumps. |

## Stagger

| Setting | Start | What it does |
|---|---|---|
| `Max` | 100 | Stagger cap. Stagger is knockback vulnerability, not health. |
| `PerHit` | 7.2 | Stagger added per punch: 14 punches take a fresh fighter to full (a test checks it). Was 12 (9 punches). |
| `HitRelief` | 3.6 | Stagger the puncher loses when they land a hit, so winning exchanges is a way back from behind. Half a punch, as before (was 6). |
| `MaxKnockbackMultiplier` | 6 | Knockback multiplier at full stagger; 1 at none, linear between. Raised from 2.5 with the lower `BaseSpeed`, so a full-stagger finisher is as strong as before (about 138, a test checks it) while early hits are short shoves. |
| `UsesValueBeforeHit` | true | A punch uses the target's stagger from BEFORE that hit, then adds PerHit. Keep this one rule everywhere. |
| `RecoveryEnabled` | true | PROVISIONAL DEFAULT from the brief: stagger recovers after a period without being hit. |
| `RecoveryDelay` | 3 | Seconds without being hit before recovery starts. A new confirmed hit restarts it; misses and being chased don't. |
| `RecoveryPerSecond` | 10 | Stagger lost per second during recovery. |
| `SpeedPenaltyMax` | 0.15 | Share of running speed lost at full stagger. It can't be set past 0.2. Doesn't affect knockback, propels, jumps or air steering. |
| `SpeedPenaltyCurve` | 1.32 | Above 1 keeps the slowdown light at low stagger. At these values, half stagger is about 94% speed. |
| `SpeedShareEase` | 5 | How quickly speed follows stagger. Higher is more immediate. |

## Arena

| Setting | Start | What it does |
|---|---|---|
| `CenterX` | 0 | Arena centre X. |
| `CenterY` | 100 | Arena floor height. |
| `CenterZ` | 0 | Arena centre Z. |
| `StartRadius` | 105 | Radius at round start, grown from 75 for 30 fighters: the same room each (about 1150 square studs). About 6 seconds across at MaxSpeed. |
| `SpawnRadius` | 73 | Radius of the spawn ring. Fighters are spread evenly round it, as many points as fighters, so 30 are about 15 studs apart and 2 are on opposite sides. |
| `SpawnCount` | 30 | Most spawn points on the ring, matching `Round.MaxPlayers`. |
| `ShrinkFractionPerElimination` | 0.08 | Target radius lost per elimination, as a share of the current target. |
| `ShrinkStudsPerSecond` | 5 | How fast the real edge moves toward its target. |
| `EliminationBatchSeconds` | 0.5 | Eliminations this close together count as one batch, so the edge never jerks. |
| `InactivitySeconds` | 20 | Seconds without an elimination before gradual shrinking starts. An elimination resets it. |
| `InactivityShrinkPerSecond` | 1 | Radius lost per second during inactivity shrinking. |
| `FinalStageRadius` | 18 | Below this radius shrinking stops waiting for inactivity and never pauses. |
| `FinalStageShrinkPerSecond` | 2 | Radius lost per second in the final stage. It runs to 0: no safe minimum exists, so the round must end. |
| `EliminationDepth` | 30 | Falling this far below the floor eliminates a player. |
| `PlayAreaMargin` | 60 | Going this far past the start edge eliminates a player. |
| `SimultaneousFinalPolicy` | "NoWinner" | EDITABLE DEFAULT: if the last players go out in the same batch, announce no winner and restart cleanly. |

## Round

| Setting | Start | What it does |
|---|---|---|
| `Enabled` | true | Rounds run (RoundService). Off, the arena is a free practice floor as before. |
| `MinPlayers` | 2 | Fighters needed to count down. In Studio the test bot counts (see `StudioBotCounts`). |
| `MaxPlayers` | 30 | Round capacity (USER 2026-11-09: a full arena of 30). Anyone past it waits for the next round. |
| `IntermissionSeconds` | 15 | Lobby countdown once enough fighters are ready. Stops if they drop below `MinPlayers`. |
| `StartingSeconds` | 4 | Everyone in the round is held still on their spawn (`HT_RoundHold`): no moving, punching or boost, and nobody can be hit. |
| `RoundOverSeconds` | 6 | How long the result shows before everyone returns to the lobby. |
| `CreditSeconds` | 4 | A ring-out goes to whoever last punched, kicked, bumped or clashed the fighter within this long before they went out; otherwise they "fell". |
| `StudioBotCounts` | true | In Studio only, the 1v1 test bot (which exists when you're alone) counts as a fighter, so a round can be tested solo. Never in a live server. Bot fill for live rounds is the next round piece. |
| `AfkEnabled` | true | The AFK button (top left), a lobby setting: on, you are not put in the next rounds until you switch it off. It never moves anyone, and it is locked while you are in a round. |
| `AfkToggleSeconds` | 0.5 | Shortest time between two AFK switches, so mashing it does nothing odd. |

## Lobby

The open-air lobby beside the arena: one level rectangle with no visible walls, its long axis pointing at the arena. Going away from the arena: the viewing edge, the main lobby (where you arrive, facing the arena), then the walk-in training area with two practice dummies. Nobody on it can be hit; the dummies can only be hit by players on it. Positions are worked out in `Core/Lobby`, and its tests fail if the floor hides the arena from spawn, a dummy stands too near an edge, or the viewing edge comes inside the round's out line. The visible model is built by `design/lobby/lobby.py`; keep its numbers the same as these.

| Setting | Start | What it does |
|---|---|---|
| `Enabled` | true | The lobby exists and waiting players are sent to it. Off: they go to the training arena, if that's on. |
| `CenterX` | 0 | Centre of the viewing edge, across the arena's long axis. |
| `FloorY` | 101 | Floor height: 1 above the arena, so feet on the arena show but the lobby's own edge doesn't hide it. |
| `ViewEdgeZ` | 170 | The arena-facing edge. Past the round's out line (165), so its invisible wall never helps a fighter. |
| `Width` | 180 | Length of the viewing edge. |
| `Depth` | 240 | From the viewing edge to the back of training. |
| `TrainingDepth` | 80 | The far part that is the practice area (a third). |
| `StripWidth` / `StripSide` | 28 / 1 | The strip kept clear for gamepass displays, down the +X side (`-1` for the other). |
| `SpawnZ` / `SpawnSpread` | 312 / 12 | Where you arrive, and how far arrivals are scattered round it. |
| `WallHeight` / `WallThickness` | 240 / 6 | The invisible walls on the floor's edge. |
| `FallDepth` | 20 | This far under the floor, a dummy goes home. |
| `EyeHeight` | 4.5 | A standing player's eye above the floor, for the sightline test. |
| `ShowFloor` | true | The plain stand-in floor is visible. Turn off once the Blender model is imported: it keeps colliding. |
| `DummyResetSeconds` | 4 | A knocked dummy goes home this long after its last hit. |
| `Dummies` | 2 | Each one's name, `X` from the centre line and `FromBack` from the back edge. |
| `Spectate` | 13 / 5.5 / 16 / 9 | Fighter POV camera: `Back` and `Up` from the fighter, how far `LookAhead` it aims, and how quickly it follows (`Smooth`). |

## Training

The training arena beside the 1v1 arena: a hub, six station platforms joined to it by bridges, and passive dummies that use the real combat rules. Controls are pads on the floor that work as you walk onto them. Layout, stations and test results are in the vault note `Training Arena`. Positions are worked out in `Core/TrainingLayout`, and its tests fail if platforms overlap, a dummy stands too near an edge, or an arrival lands on a pad.

| Setting | Value | What it does |
|---|---|---|
| `Enabled` | true | Builds the training arena. False removes it, its dummies and its display. |
| `SparringEnabled` | true | PROVISIONAL DEFAULT from the brief: two players in training can hit each other. |
| `DummiesEnabled` | true | PROVISIONAL DEFAULT from the brief: the dummies exist. |
| `CenterX`, `CenterY`, `CenterZ` | 370, 100, 0 | The hub's centre. Y is the floor's top. It must stay clear of the 1v1 arena; a test checks for at least 30 studs between them. |
| `HubRadius` | 34 | Size of the hub. |
| `RingDistance` | 180 | Hub centre to each station's centre. Larger spreads stations further apart. |
| `BridgeWidth` | 14 | Width of each bridge. |
| `RimWidth` | 1.2 | Width of the yellow edge on every platform. The edge you see is the edge you can stand on. |
| `FallDepth` | 20 | Falling this far below the floor returns a player to the station they were on, with stagger reset, and sends a dummy home. |
| `ReturnInset` | 8 | How far inside a station's bridge side you arrive, and where its row of pads sits. |
| `GateInset` | 10 | How far inside the 1v1 arena's edge its TRAINING pad is. |
| `PadRadius` | 4 | Size of every pad. You walk on to use it, and it won't work again until you step off. |
| `SignDistance` | 260 | Studs at which floor text and labels stop drawing. |
| `MarkerStep` | 10 | Studs between the numbered distance rings on each station. |
| `ManualResetGrace` | 1 | After a reset pad, a dummy still waits this long after its last hit, so it isn't snatched mid-combo. |
| `ForceResetSeconds` | 20 | A dummy stuck launched, held or in the air this long is sent home anyway, so nothing stays stuck. |
| `PanelStartsOpen` | true | Whether the testing display starts open. It always starts closed on touch screens. |
| `HitboxStationKey` | D | The station that gets reach rings, stand marks and the stationary target pad. |
| `Patrol.StationKey` | E | The moving target's station. |
| `Patrol.Length` | 70 | Length of its marked line. |
| `Patrol.ResumeSeconds` | 1.5 | After a hit has faded, it waits this long before walking again. |
| `Patrol.StartIndex` | 2 | Which speed it starts at. |
| `Patrol.Speeds` | Slow 12, Medium 26, Fast 48 | Its speeds in studs/s, in the order its pad steps through them. Players run at 36. |
| `Recovery.StationKey` | F | The recovery station. |
| `Recovery.PadInset` | 7 | How far inside the edge the launch pads are. |
| `Recovery.Pads` | 5 pads | Each is `Name`, `FanDegrees` (where on the edge), `GapStuds` (how far past the edge the launch starts), `HeightStuds`, `OutwardSpeed`, `UpSpeed`, `StaggerShare` (of `Stagger.Max`) and `Launched` (true gives the uppercut's float). Their conditions are printed next to each pad. |
| `Stations` | A to F | Each is `Key`, `Title`, `Purpose`, `AngleDegrees` (around the hub, 0 is +X), `Radius`, `ResetSeconds` (how long a dummy waits after its last hit before going home) and `Dummies`. A dummy is `Name`, `Forward` (studs away from the hub from the centre), `Right`, and optionally `StartStaggerShare`, `Stationary` or `Patrols`. |

## Security

| Setting | Start | What it does |
|---|---|---|
| `SpeedSampleSeconds` | 0.05 | How often the server measures each character's real speed from its position. |
| `SpeedSampleWindow` | 4 | Samples averaged into the measured speed. |
| `HistorySeconds` | 1 | How much position history the server keeps for lag compensation. |
| `TeleportSpeed` | 300 | A jump faster than this counts as a teleport, so it isn't read as speed. |
| `SpeedTrustCap` | 40 | The speed bonus never uses more than this, whatever a client does. |

## Effects

| Setting | Start | What it does |
|---|---|---|
| `GustSeconds` | 0.6 | How long the gust behind a punch thrown in the air takes to fade out. (The dash has its own effect now: the `Dash*` settings below.) |
| `GustSideOffset` | 1.1 | How far each side of that gust starts from the character's centre. |
| `KickImpactSeconds` | 0.6 | How long the kick's blast and rings last. |
| `KickShakeSeconds` | 0.42 | How long the camera shake from a kick lasts. |
| `KickShakeStuds` | 0.8 | How far the camera shakes at its strongest. |
| `KickShakeRange` | 45 | Studs away that bystanders stop feeling a kick. |
| `KickFovPunch` | 7 | Degrees the view widens on a kick. |
| `FootDrop` | 2.6 | How far below the body centre the gust sits, at the feet. |
| `DriftPuffEvery` | 0.05 | Seconds between smoke puffs while someone is drifting. Only a propel makes this smoke, for its `PropelSeconds`. |
| `DriftPuffMinSlip` | 20 | Degrees between body and travel before smoke starts. |
| `DriftPuffMinSpeed` | 24 | Studs/s needed before a slide makes smoke. |
| `DriftPuffSeconds` | 0.7 | How long each smoke puff lasts. |
| `JumpSmokeSeconds` | 0.7 | How long the smoke around a jump takes to fade. |
| `JumpSmokePuffs` | 10 | How many puffs ring the character. |
| `JumpSmokeRadius` | 1.8 | Studs out from the feet that the puffs start. |
| `JumpSmokeSpread` | 5.5 | Studs they drift further out as they fade. |
| `JumpSmokeSize` | 5 | Studs across that each puff grows to. |
| `GroundBreakSeconds` | 2.6 | How long the broken floor lasts, from the spring until it has all gone. Must leave time for the highest chunk to land before the fade. |
| `GroundFadeSeconds` | 0.5 | The end of that time, when cracks fade and chunks shrink away. |
| `GroundBreakOwnReach` | 6 | Studs below your body that the floor has to be for your own jump to break it. |
| `GroundBreakWatchReach` | 20 | The same for someone else's jump. Longer, because their jump reaches you late and they've already risen. |
| `GroundBreakShake` | 0.25 | Size of the camera shake on your own jump, where 1 is a full kick's. 0 turns it off. |
| `GroundChunks` | 16 | Blocks thrown into the air. |
| `GroundChunkSizeMin` | 0.7 | Smallest a block's side can be, in studs. |
| `GroundChunkSizeMax` | 2.4 | Largest a block's side can be, in studs. |
| `GroundChunkOutMin` | 8 | Slowest a block flies outward, in studs/s. |
| `GroundChunkOutMax` | 26 | Fastest a block flies outward. |
| `GroundChunkUpMin` | 26 | Slowest a block is thrown upward, in studs/s. |
| `GroundChunkUpMax` | 80 | Fastest a block is thrown upward. At the gravity below, that's about 27 studs high. |
| `GroundChunkGravity` | 120 | How fast blocks fall back, in studs/s per second. Lower keeps them in the air longer. |
| `GroundChunkBounce` | 0.28 | Share of its speed a block keeps through its one bounce. |
| `GroundSlabs` | 9 | Slabs of floor that burst up around the hole. |
| `GroundSlabRing` | 3.4 | Studs from the feet to the ring of slabs. Cracks and blocks start inside it. |
| `GroundSlabLengthMin` | 3 | Shortest slab, in studs. |
| `GroundSlabLengthMax` | 5 | Longest slab. |
| `GroundSlabWidthMin` | 2.2 | Narrowest slab. |
| `GroundSlabWidthMax` | 3.8 | Widest slab. |
| `GroundSlabThickness` | 0.9 | Thickness of every slab. |
| `GroundSlabTiltMin` | 20 | Least a slab tilts, outer edge up, in degrees. |
| `GroundSlabTiltMax` | 50 | Most a slab tilts. |
| `GroundSlabRiseSeconds` | 0.07 | How fast slabs burst out of the floor. |
| `GroundSlabSinkSeconds` | 0.35 | How long they take to sink back at the end. |
| `GroundCracks` | 7 | Cracks running out from the hole. |
| `GroundCrackLengthMin` | 5 | Shortest crack, in studs. |
| `GroundCrackLengthMax` | 11 | Longest crack. |
| `GroundCrackWidth` | 0.45 | Width of a crack where it starts. It narrows toward the tip. |
| `GroundCrackBend` | 28 | Most a crack changes direction at each bend, in degrees. |
| `GroundPits` | 4 | Overlapping dark patches that make the uneven hole under the feet. |
| `GroundPitSize` | 6 | Largest size of one of those patches, in studs. |
| `HitBurstSeconds` | 0.3 | How long a punch hit's burst lasts. |
| `StrongHitSpeed` | 100 | A hit this strong gets a bigger burst, a launch sound and a puff trail. |
| `StrongHitScale` | 1.4 | How much bigger a strong hit's burst is. |
| `TrailPuffs` | 4 | Puffs left along a big launch's path. |
| `TrailPuffSeconds` | 0.07 | Time between those puffs. |
| `PoolLimit` | 80 | Most effect parts kept for reuse. |
| `DashFxRange` | 220 | Studs from the camera past which a dash shows nothing at all. |
| `DashGhostRange` | 150 | Studs from the camera past which a dash leaves no after-images (lines and streaks still show). |
| `DashGhostEvery` | 0.07 | Seconds between after-images. At dash speed (84) that is one every 6 studs. Lower = more of them, closer together. |
| `DashGhostSeconds` | 0.34 | How long each after-image takes to fade out. About `DashGhostSeconds / DashGhostEvery` show at once (5). |
| `DashGhostTransparency` | 0.6 | How see-through an after-image starts (0 solid, 1 invisible). Lower is bolder, but from behind your own after-images sit between the camera and your character, so too low hides it. It fades to 1, turning from pale blue to a deeper blue. |
| `DashGhostMaxParts` | 24 | Most body parts copied into one after-image (a body here is 6, the rest is hair and hats). Touch devices use 60% of this. |
| `DashLineCount` | 10 | Speed lines trailing off the body, spread from feet to head. Touch devices use 60%. |
| `DashLineSeconds` | 0.2 | How long a speed line lasts, so how long it is: each is 0.55 to 1.45 times this, about 9 to 24 studs at dash speed. |
| `DashLineWidth` | 0.1 | Thickness of a speed line in studs (each is 0.6 to 1.5 times this). |
| `DashStreakRate` | 45 | Wind streaks thrown off the body per second while the dash runs. |
| `DashStreakSquash` | 3 | How thin and long each streak is stretched along its flight. 0 is a round sparkle. |
| `DashDustCount` | 10 | Dust puffs kicked back from the feet when a dash starts on the ground. |
| `DashChargeRate` | 14 | Sparks per second at the feet when a dash starts charging. It rises to four times this at a full charge. The dash and its sparks are white for a tap, through yellow, to fiery orange at full. |
| `SwingSparkScale` | 0.4 | Size of the small spark where a swing cuts the air, as a share of a landed punch's spark. It sits at `Punch.Range` in front of the puncher, so it shows how far the punch reaches. |

## Debug

| Setting | Start | What it does |
|---|---|---|
| `MoveReadout` | true | TEMPORARY: small on-screen speed readout for tuning. The real HUD replaces it. |
| `ShowHitbox` | false | Off since move-4 (punches show a spark instead; the training toggle still switches it on). draws every player's punch hitbox on the floor in see-through red. Turn off before anyone else plays. |
| `TestFloor` | true | TEMPORARY: builds a plain floor and returns players who fall. The real arena replaces it. |

## Tutorial

The first-join tutorial. All values are starting guesses.

| Setting | Start | What it does |
|---|---|---|
| `Enabled` | false | TEMPORARILY OFF so the bot fights a solo player straight away while combat is tested. True brings the tutorial back. |
| `HitsToLearn` | 3 | Confirmed hits needed in the punch step. |
| `FastHitSpeed` | 25 | How fast you must be running, in studs/s, for the speed step's hit to count (top speed is 36). |
| `BumpPunishSeconds` | 1.5 | How soon after a bump your punch must land for the bump step to count. |
| `HintSeconds` | 6 | Seconds stuck on a step before its hint shows. |
| `MissSeconds` | 0.8 | How long "Too far away!" stays up after a badly timed punch. |
| `EndSeconds` | 4 | How long the closing message stays up. |

## TestBot

The 1v1 arena's opponent, which chases and punches like a player. It only exists when one player is alone in the server, and only fights players who've finished the tutorial and aren't in training. Its brain was rebuilt on 2026-11-05 from these settings after being deleted, so it may differ slightly from before.

| Setting | Value | What it does |
|---|---|---|
| `Enabled` | true | The bot exists. False removes it. |
| `Fights` | true | True: it chases and punches. False: it stands still and goes home after `ReturnSeconds`. |
| `AirSteers` | true | It steers away from you when launched, so a jump can miss it the way it can miss a person. |
| `AirSteerShare` | 0.3 | How much of a person's air control it uses when launched. |
| `StopDistance` | 4.5 | How close it runs before easing off. Must be under `Punch.Range` plus `Punch.TargetRadius`, or it can't reach. |
| `CloseInput` | 0.1 | How hard it pushes the stick when close, 0 to 1. Keeps it turning to face you. |
| `EdgeMargin` | 14 | It turns back this far from the 1v1 arena's edge, even mid-chase. |
| `ReactionSeconds` | 0.4 | How long you must be noticed before it punches. Higher is easier. |
| `PunchCooldown` | 1.1 | Seconds between its punches (players: 0.32). Lower is harder. |
| `NoticeDistance` | 14 | Studs at which it notices a target and its reaction time starts. |
| `TrackingLag` | 0.2 | Seconds behind that it sees its target, so moving makes it swing at where you were. |
| `MisjudgeStuds` | 3 | Up to this many studs it overestimates its reach, rolled each swing, so it sometimes swings early. |
| `ExtraWindup` | 0.15 | Extra seconds its punch takes to land, on top of `Punch.Windup`, so it can be dodged. |
| `WildSwingChance` | 0.35 | Share of its swings that go wide and hit nobody. |
| `ClashTapsPerSecond` | 5.5 | How fast it taps in a clash. |
| `ReturnSeconds` | 3 | When not fighting, how long after a hit before it goes back to its spot. |

## AnimationIds

| Setting | Start | What it does |
|---|---|---|
| `Idle` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `MoveStart` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `RunLow` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `RunHigh` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `LeanLeft` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `LeanRight` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `Coast` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `PunchLeft` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `PunchRight` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `HitReact` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `KnockbackFall` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |
| `Victory` | (empty) | Roblox animation id for this clip. Empty until the real clip is uploaded; no ids are invented. |

## Kick

The air kick. An uppercut launches someone, who can steer and propel in the air. Space squats, and the server picks who you follow up: anyone launched within `FollowUpOwnRange` (your own uppercut) or `FollowUpRange` (anyone else's), with nothing solid in between, by distance and by how far off where you face they are. It holds them still from that moment, and you snap straight to beside them. Once close, a ring closes; Space as it meets the key. You curl, spin forward, and whip your heel down on them. The kick always connects, and the timing sets its force. Only a grade in `FinisherGrades` (green, a perfect press) is a finisher: they're launched hard away from you and up, with a moment's loss of control. Anything else (orange or red) knocks them down: slammed to the floor, with no control until `KnockdownSeconds` after landing. You get a boost of running momentum backward and a small hop, and carry on running.

| Setting | Value | What it does |
|---|---|---|
| `Cooldown` | 15 | Seconds between jumps, hit or miss. Your first jump is ready, and it's the only limit: uppercuts don't earn jumps. |
| `AirGravityScale` | 0.7 | Share of normal gravity on someone launched by an uppercut while they rise, and on the jump after them. From the top of the arc they fall on `AirRecovery`. Lower hangs longer and feels floatier. |
| `JumpSquatSeconds` | 0.067 | Seconds down in the squat before leaving the floor. Must match `JUMP_SQUAT` in `build_clips.py`. |
| `ApproachSpeed` | 260 | Speed the snap's length is worked out from: distance / this, in seconds, kept between the two limits below. |
| `ApproachMinSeconds` | 0.08 | Shortest snap, so it's never instant. |
| `ApproachMaxSeconds` | 0.65 | Longest snap. It must cover `FollowUpOwnRange` at `ApproachMaxSpeed` (a test checks). |
| `ApproachMaxSpeed` | 280 | Fastest the snap ever moves. Keep it under `Security.TeleportSpeed` (300), or the speed audit takes it for a teleport (a test checks). |
| `LeapGuideSpeed` | 130 | The follow-up at someone you are NOT locked onto is a guided leap: an arc that is re-aimed at them the whole way. This is its speed, which sets how long it takes. Keep it under `ApproachSpeed`, or it is the snap again. |
| `LeapGuideMinSeconds` | 0.3 | Shortest guided leap, so a close one still reads as a jump. |
| `LeapGuideMaxSeconds` | 1.1 | Longest guided leap. |
| `LeapGuideMaxSpeed` | 190 | Fastest the guided leap ever moves, when the target is far or moving away. |
| `LeapGuideArc` | 120 | How much the guided leap arcs upward on its way, as a gravity. 0 is a straight line. |
| `AcceptWaitSeconds` | 0.6 | How long the squat waits for the server to accept. If it never does, nothing happens and it can be tried again. |
| `FollowUpRange` | 80 | Studs (straight line) within which someone else's launch can be followed up. |
| `FollowUpOwnRange` | 170 | The same for your own uppercut's launch. A strong uppercut throws them 150 studs within a second. |
| `FollowUpAimWeight` | 0.6 | How much where you face counts in the pick: distance times (1 + this x (1 - cos)/2), so directly behind counts 1.6 times as far. |
| `FollowUpOwnShare` | 0.8 | Your own launch counts this share as far, so it wins a close call. |
| `HoldTimeout` | 2.5 | Longest the target is ever held still, whatever goes wrong. Its own client lets go at this deadline too (`HT_HoldUntil`). |
| `JumpMissGrace` | 0.15 | Seconds past the snap's end that it counts as missed if it hasn't reached them, say because a wall was in the way. |
| `MissCarryKeep` | 18 | After a miss you go back to normal movement in the air, travelling at no more than this speed. Higher carries you further the way you were going. |
| `MissGravityScale` | 0.3 | Share of normal gravity after a miss. Lower gives more time to get back. |
| `MissLift` | 12 | Studs/s of lift the moment a jump misses, once. Raise this for more air time. |
| `MissMaxFall` | 52 | Fastest you can fall after a miss, in studs/s. Lower gives more air time. |
| `KickAimRate` | 720 | Degrees per second your keys, or your camera in shift lock, swing you around them during the timing, which aims the kick. |
| `LaunchSteerSpeed` | 26 | Fastest someone launched can steer themselves, in studs/s, on top of the launch's push. |
| `LaunchSteerAcceleration` | 90 | Studs/s per second they steer at. |
| `LaunchSteerStaggerLoss` | 0.5 | Share of that control lost at full stagger. |
| `ChaseSeconds` | 1.2 | The server stops counting a snap after this long, whatever happens. |
| `TouchFlat` | 8 | Studs along the floor between two bodies that start the kick. Nothing happens from further away. |
| `TouchTall` | 10 | Studs of height between two bodies that start the kick. |
| `AttachAbove` | 0.5 | How far above them you hang beside them. |
| `AttachSide` | 3 | How far beside them you hang, on the side you arrived from. They turn to face you. |
| `FlipAbove` | 4.5 | How far above them the spin takes you. |
| `FlipSide` | 1.5 | How far beside them you are at the end of the spin. |
| `FollowRate` | 16 | How fast aligning moves you into place. Higher snaps harder. |
| `QteEarliest` | 0.25 | Soonest the ring can meet the key, in seconds after touching. |
| `QteLatest` | 0.45 | Latest it can. Each jump picks a time between the two, so it has to be watched. |
| `GreenWindow` | 0.05 | Seconds either side of that which give a green, the strongest kick. |
| `OrangeWindow` | 0.12 | Seconds either side which give an orange. Anything else is a red, as is never pressing. |
| `RedShare` | 0.5 | Share of full force for a red: outward push, slam and stagger together. |
| `OrangeShare` | 0.85 | Share of full force for an orange. |
| `GreenShare` | 1.3 | Share of full force for a green. |
| `RedStop` | 0.05 | Seconds both are frozen when a red kick lands. |
| `OrangeStop` | 0.083 | The same for an orange. |
| `GreenStop` | 0.117 | The same for a green. |
| `FlipSeconds` | 0.28 | How long the spin takes before the heel lands. Must match the `KickSpin` clip. |
| `RecoverSeconds` | 0.45 | Seconds before you can punch again after the kick lands. |
| `ReboundRiseRed` | 14 | Studs you rise above the kick after a MISTIMED! kick. The push backward is `Movement.PropelSpeed` at every grade and holds until you land, so a higher arc carries further. From 40 studs up that's about 102 studs of travel. |
| `ReboundRiseOrange` | 30 | The same after a CLOSE! kick. About 127 studs of travel from 40 up. |
| `ReboundRiseGreen` | 46 | The same after a PERFECT! kick. Keep it under the uppercut's 57. About 147 studs of travel from 40 up, and more if that's what it takes to reach the platform. |
| `ReboundLandNear` | 15 | Studs inside the near edge that a PERFECT! rebound aims to land at least, when it needs more speed to get there. |
| `ReboundLandFar` | 55 | Studs short of the far edge that any rebound is kept to, by slowing it, so your own rebound can't throw you off the far side. |
| `ReboundSpeedMax` | 300 | Fastest a PERFECT! rebound can go to reach the platform. |
| `ReboundGravityScale` | 0.85 | Share of normal gravity during the rebound. |
| `StaggerAdded` | 18 | Stagger a kick adds at full force. A punch adds 12. Its outward push at full force is the same as a regular punch, from `Knockback.BaseSpeed` and stagger. |
| `SlamSpeed` | 110 | Studs/s a grade outside `FinisherGrades` (orange, red) drives them down at full force. |
| `BounceLift` | 75 | Studs/s a green kick bounces them up when they hit the floor, about 14 studs, only when green isn't in `FinisherGrades`. |
| `StunMaxSeconds` | 2.5 | Longest a green kick's loss of control can last, whatever else happens. |
| `StunAfterLanding` | 0.2 | Seconds of it left after landing from the bounce. |
| `KnockdownSeconds` | 0.5 | Seconds a knocked-down target (any slam but a green bounce) stays without control after landing. 0 gives control back on landing. |
| `FinisherGrades` | green | Grades that launch them away and up instead of knocking them down. Green is the perfect press; orange and red are knockdowns. |
| `FinisherPushScale` | 2 | Outward speed of a finisher, as a multiple of a punch's strength at their stagger times the grade's share. |
| `FinisherMaxSpeed` | 220 | Most outward speed a finisher gives. |
| `FinisherLift` | 45 | Studs/s a finisher sends them up. |
| `FinisherStunSeconds` | 0.45 | Seconds they can't act after a finisher, then they can punch to recover as usual. |
| `FinisherShake` | 1.3 | Camera shake for the kicker and the kicked on a finisher, as a multiple of a normal kick's. |

## AirRecovery

Getting back to the platform. Each accepted punch in the air gives a push and a tiny lift, and falling is slower for everyone. There's no limit on how many punches: it's balanced by these values and the punch cooldown. Full details and test results are in the vault note `Air Recovery`. To try values without changing this file, use `RECOVERY_SET="BoostSpeed=30" lune run lune/recovery_sim`.

| Setting | Value | What it does |
|---|---|---|
| `BoostSpeed` | 17 | Flat push one air punch gives, in studs/s. Tuned in recover-1 with `lune run lune/recovery_sim` for about 90% back when close, 50% at moderate distance, 0% very far. |
| `BoostFade` | 24 | How fast a push fades, in studs/s per second. Lower makes pushes build up more between punches. |
| `MaxSpeed` | 60 | Fastest punches can carry you. A launch can still be faster, and pushing against one still gets all of it. |
| `UpAssist` | 5 | Most lift one punch gives, in studs/s. Under 0.1 stud of height on its own. |
| `UpAssistCeiling` | 6 | A punch only tops your vertical speed up to this, so it can't add to a rise. |
| `FallGravityScale` | 1.3 | **Fall weight.** Share of normal gravity while falling, for everyone and everything (jumps, ledges, launches, kick rebounds and misses, dummies, and every prediction). Above 1 it's heavier than the rise, so launch heights don't change but the way down is quicker. An uppercut now comes down in about 0.81 s (was 1.96 s at 0.24). Lower hangs longer and makes recovery easier. |
| `FallEaseSpeed` | 12 | Falling speed over which gravity eases from a launch's own to `FallGravityScale`. Higher makes the top of the arc softer and more readable. |
| `MaxFallSpeed` | 90 | Fastest an ordinary fall gets, reached about 0.36 s into a drop. A kick's slam isn't limited by this. Keep `Animation.LandMinFallSpeed` below it. |
| `FallDrag` | 120 | How fast anything falling faster than `MaxFallSpeed` slows back to it, in studs/s per second. A slam doesn't slow. |
| `MinAirSeconds` | 0.1 | How long off the floor before a punch counts as airborne. Stops a stumble on the floor giving a push. |
| `HitRecoilShare` | 0.5 | Share of `Punch.HitRecoilSpeed` a landed punch pushes you back with in the air. |
| `PunchWhileLaunched` | true | Whether someone launched by an uppercut can punch. False removes their recovery, and any chance of dodging a jump by punching. |
| `LiftEnabled` | true | The falling lift: an UPPERCUT (the third swing of the combo) thrown while falling, with open air below, gives a small hop. False turns it off. |
| `LiftSpeed` | 42 | Vertical speed the lift sets, once, in studs/s, like a jump. It replaces `UpAssist` for that punch; the two never stack. |
| `LiftSeconds` | 0.33 | How long gravity stays lighter after a lift: about the time to the top of the hop. With the values here it rises about 7 studs, like a jump (tested 5.5 to 8). |
| `LiftGravityScale` | 0.65 | Share of gravity during those seconds. |
| `LiftForwardSpeed` | 0 | The flat push a lifting uppercut gives, in place of `BoostSpeed`. 0: the lift is straight up, like a jump, so it buys time but not distance. |
| `LiftCooldown` | 1.2 | Seconds between two lifts in one fall. |
| `LiftsPerFall` | 2 | Lifts allowed before landing. Landing resets the count. The tests fail if lifting every chance could stop a fall. |
| `LiftFallingSpeed` | 2 | How fast you must already be falling, in studs/s. Rising, or the very top of an arc, gets no lift. |
| `LiftFloorCheck` | 14 | Studs below the feet that must be clear of floor. Closer than this, the punch gets the ordinary small lift. |

## Controls

Keyboard bindings that more than one script needs to agree on. `Key` is an `Enum.KeyCode` name, `Label` what the guide shows.

| Setting | Value | What it does |
|---|---|---|
| `ShiftLock` | LeftControl, "Ctrl" | The game's own shift lock. Roblox's is off (`EnableMouseLockOption` false). |

## ShiftLock

How shift lock looks. In shift lock, the camera also aims the air kick during its timing.

| Setting | Value | What it does |
|---|---|---|
| `CameraOffsetX` | 0 | Studs the camera sits to the right of the character. Roblox's own default is 1.75. 0 is directly behind. |
| `DotSize` | 7 | Pixels across the white dot. |
| `DotAboveHead` | 0.9 | Studs above the top of the head that the dot sits. |

## LockOn

The marker and who it shows. It moves nobody and changes no hit.

| Setting | Value | What it does |
|---|---|---|
| `Range` | 70 | Studs: how close someone must be for the marker to show them. |
| `ReleaseRange` | 85 | Studs: past this, whoever is shown or selected is let go. Larger than `Range`, so it can't flicker at the limit. |
| `LookDegrees` | 12 | How close to the centre of your view someone must be to show the marker. |
| `LookReleaseDegrees` | 18 | How far off they can drift before the white marker lets go. |
| `LookStuds` | 2.5 | Up close, looking within this many studs of their middle also counts, since they fill your view. |
| `LostSightSeconds` | 0.75 | A selected opponent out of sight this long is let go. The marker goes the moment they're out of sight, and the camera holds on where they were last seen. |
| `CheckSeconds` | 0.1 | Seconds between checks of who you're looking at. A selection is checked every frame. |
| `MarkerPixels` | 128 | Marker width across the outer segments at `ReferenceHeight`. It never changes with distance. |
| `ReferenceHeight` | 1080 | Screen height at which the marker is exactly `MarkerPixels`. Other screens scale in proportion. |
| `MinMarkerPixels` | 80 | It never gets smaller than this, on a small screen. |
| `ImageOuter, ImageInner, ImageDiamond, ImageDiamondFilled, ImagePulse` | (ids) | The white shapes, made by `assets/lockon/build_lockon_art.py`. Stroke thickness lives in that script's numbers: change it, rerun it and upload again. |
| `ImageOuterOutline, ImageInnerOutline, ImageDiamondOutline, ImageDiamondFilledOutline, ImagePulseOutline` | (ids) | The dark edge behind each shape. Thickness is `OUTLINE` and `THIN_OUTLINE` in the same script: 3 and 2.5 of the concept's pixels, about 3.4 and 2.9 px on screen. |
| `MarkerColor` | FFFFFF | Colour of the marker when a target is available, as hex. |
| `LockedColor` | FFCA54 | Colour when selected, as hex. |
| `OutlineColor` | 0B1320 | Colour of the dark edge, as hex. It stays this colour in both states. |
| `OutlineOpacity` | 1 | How solid the dark edge is. |
| `OuterSpinSeconds` | 5 | Seconds per clockwise turn of the outer segments. |
| `InnerSpinSeconds` | 7 | Seconds per counterclockwise turn of the inner arcs. |
| `InnerOpacity` | 1 | How solid the inner arcs are. |
| `DiamondOpacity` | 1 | How solid the diamond is on the white marker. |
| `DiamondScale` | 0.85 | Size of the diamond on the white marker. It's full size when selected. |
| `PopSeconds` | 0.26 | How long the marker takes to pop in. |
| `PopStart` | 0.88 | Size it pops in from. |
| `PopPeak` | 1.06 | Size it overshoots to. |
| `PopPeakAt` | 0.65 | Share of the pop's time at which it peaks. |
| `SqueezeSeconds` | 0.24 | How long the tighten on selecting takes. |
| `SqueezeStart` | 1.04 | Size that tighten starts from. |
| `SqueezeLow` | 0.82 | Smallest it dips to. |
| `SqueezeLowAt` | 0.55 | Share of its time at which it dips lowest. |
| `LockedScale` | 0.88 | Size while selected. |
| `PulseSeconds` | 0.65 | How long one confirmation pulse takes. |
| `PulseRepeats` | 2 | How many pulses play on selecting. |
| `PulseStart` | 0.94 | Size a pulse starts at. |
| `PulseEnd` | 1.14 | Size a pulse ends at. |
| `PulseOpacity` | 0.9 | How solid a pulse starts. It fades to nothing. |
| `SettleSeconds` | 0.18 | How long it takes to return to full size on letting go. |
| `DiamondSeconds` | 0.15 | How long the diamond takes to change between its two sizes. |
| `FadeSeconds` | 0.15 | How long the marker takes to fade out. |
| `FadeRiseUnits` | 8 | How far it drifts up as it fades, in the concept's pixels. |

## LockCamera

The camera while locked on. It only sets the view: it never touches a velocity, a jump or a hit.

| Setting | Value | What it does |
|---|---|---|
| `FocusHeight` | 6 | Studs above your body that the camera's line passes through. Higher puts you lower on screen, clear of the opponent. |
| `BaseDistance` | 13 | Camera distance with the two of you together. |
| `DistancePerStud` | 0.12 | Extra distance per stud between you. |
| `MinDistance` | 11 | Closest automatic zoom. |
| `MaxDistance` | 24 | Furthest automatic zoom. It never goes past this. |
| `FocusRate` | 28 | How tightly the camera follows you. Higher is tighter, and about 0.04 s behind at 28. |
| `TargetRate` | 20 | How tightly it follows them, and how softly it picks them up again after losing sight. |
| `YawRate` | 13 | How promptly it turns left and right toward them. 90% of the way in about 0.18 s. |
| `PitchRate` | 13 | The same for up and down. |
| `YawMaxDegrees` | 420 | Fastest it can turn, in degrees/s. Someone crossing behind you takes about 0.45 s to swing round to, rather than snapping. |
| `PitchMaxDegrees` | 300 | Fastest it can tilt, in degrees/s, so someone passing overhead can't snap it. |
| `ZoomRate` | 3.5 | How gently it zooms in and out. |
| `EnterSeconds` | 0.25 | How long it takes to ease into lock-on. |
| `ExitSeconds` | 0.35 | How long it takes to ease back to the normal camera. |
| `PitchUpMax` | 55 | Steepest it looks up, in degrees. |
| `PitchDownMax` | 45 | Steepest it looks down, in degrees. |
| `HoldFlat` | 3 | With them closer than this on the flat, straight above or below you, the yaw holds still. |
| `FullFlat` | 10 | The yaw is fully following again by this distance. |
| `OrbitYawMax` | 30 | How far the mouse can swing the view left or right, in degrees. Under half the screen's width, so they stay on screen. |
| `OrbitPitchMax` | 18 | How far the mouse can tilt the view up or down, in degrees. |
| `MouseDegreesPerPixel` | 0.18 | Mouse speed, before the player's own sensitivity setting. |
| `OrbitReturnDelay` | 1.5 | Seconds without mouse movement before the view starts easing back to centre. |
| `OrbitReturnRate` | 1.2 | How gently it eases back. |
| `CollisionRadius` | 0.6 | Size of the camera when checking for walls and terrain. |
| `CollisionMargin` | 0.4 | Extra gap it keeps from them. |
| `PullOutRate` | 6 | How slowly it moves back out after a wall. It always comes in at once. |
| `MinPull` | 3 | Closest a wall can bring it to you. |

## KickText

The word after an air kick's timing: MISTIMED!, CLOSE! or PERFECT!

| Setting | Value | What it does |
|---|---|---|
| `ScreenX` | 0.5 | Where it sits across the screen, 0 to 1. |
| `ScreenY` | 0.85 | Where it sits down the screen, 0 to 1. Above the bottom-screen controls. |
| `WidthShare` | 0.7 | Share of the screen's width it can use. |
| `HeightShare` | 0.1 | Share of the screen's height it can use. |
| `MinTextSize` | 28 | Smallest the text gets, on small screens. |
| `MaxTextSize` | 60 | Largest the text gets, on big screens. |
| `StrokeThickness` | 3 | Dark outline, so it reads over anything. |
| `StartScale` | 0.4 | Size it starts at, as a share of full size. |
| `PeakScale` | 1.16 | Size it overshoots to. |
| `DipScale` | 0.97 | Size it dips back to before settling at full. |
| `PerfectPeakScale` | 1.34 | The overshoot for a PERFECT!. |
| `PerfectDipScale` | 0.93 | The dip for a PERFECT!. |
| `RiseSeconds` | 0.08 | How long the rise takes. |
| `DipSeconds` | 0.07 | How long the dip takes. |
| `SettleSeconds` | 0.08 | How long the settle takes. |
| `HoldSeconds` | 0.55 | Seconds from appearing until it starts to fade. |
| `PerfectHoldSeconds` | 0.65 | The same for a PERFECT!. |
| `FadeSeconds` | 0.25 | How long the fade takes. |

## Animation

| Setting | Value | What it does |
|---|---|---|
| `FadeSeconds` | 0.12 | How fast the clips blend into each other. |
| `StanceMaxSpeed` | 1.5 | Below this speed, the full boxing stance shows. |
| `SprintBlendLow` | 6 | Speed where the sprint starts to show over the stock run. |
| `SprintBlendHigh` | 22 | Speed where it has taken over fully. |
| `RunVariantSpeed` | 18 | At or above this speed, swings use their versions that keep the sprint's lean. |
| `RunRampMinShare` | 0.7 | Share of top speed that counts as running for the ramp below. |
| `RunRampSeconds` | 3 | Seconds of running to reach the fastest stride. |
| `RunRampFallRate` | 3 | How many times faster the ramp winds back down when you stop running. |
| `RunRampStart` | 1.05 | Stride speed when you first reach a run. |
| `RunRampEnd` | 1.5 | Stride speed after running for `RunRampSeconds`. |
| `RunPaceMin` | 0.45 | Slowest the stride gets from low speed. |
| `RunPaceMax` | 1.2 | Fastest the stride gets from high speed, such as a propel. |
| `BrakeDeceleration` | 52 | Studs/s lost per second that counts as braking. Set above the 45 of letting go of A or D, so only S shows it. |
| `BrakeMinSpeed` | 8 | Below this speed, no brake animation. |
| `BrakeHoldSeconds` | 0.12 | How long the slowdown must last first, so a hit or bump doesn't show it. |
| `BrakeFadeIn` | 0.04 | Seconds the skid pose takes to show. Nearly instant: it's the plant. |
| `BrakeFadeOut` | 0.07 | Seconds the skid pose takes to go. |
| `BrakeWeightMin` | 0.55 | How strongly the skid shows from the slowest brake. At top speed it shows fully. |
| `BrakeSettleMinShare` | 0.25 | A skid from below this share of top speed doesn't rock forward afterwards. |
| `SwingEndFade` | 0.09 | Seconds a swing fades out over at its end, into the run or the stance. |
| `HitStopMin` | 0.05 | Seconds a puncher's pose freezes on the weakest hit. Visual only. |
| `HitStopMax` | 0.09 | The same on the strongest hit. |
| `HitStopFullStrength` | 140 | Knockback strength that gets `HitStopMax`. |
| `UppercutHitStopExtra` | 0.03 | Extra seconds for an uppercut. |
| `HitStopCreep` | 0.06 | Speed a frozen pose still creeps at, so it never looks stuck. |
| `AttackerShakeStuds` | 0.05 | How far the puncher's body shakes in a hit stop. Visual only. |
| `VictimShakeStuds` | 0.28 | How far the one hit shakes. Visual only; hits and movement are unaffected. |
| `VictimShakeShare` | 1.7 | The one hit shakes this many times longer than the stop. |
| `FlinchFade` | 0.066 | Seconds into the pained pose, so it reads without popping. |
| `RecentHitSeconds` | 2.5 | Airborne within this long of a hit counts as being knocked, not jumping. |
| `SlammedFallSpeed` | 45 | Falling this fast after a hit shows the slammed pose. |
| `LandMinFallSpeed` | 34 | Landing this fast shows the landing. Keep it below `AirRecovery.MaxFallSpeed`, or ordinary falls never show it. |
| `LandFullStillSpeed` | 24 | Below this running speed the landing shows fully. |
| `LandWeightMin` | 0.25 | How much the landing shows at a full run. |
| `HeavyHitShare` | 0.45 | Share of `HitStopFullStrength` from which a hit gets the heavy reaction. |
| `HitTiltDegrees` | 30 | How far a hit at full strength throws the body over, away from the hit. Visual only. |
| `HitTiltStiffness` | 280 | How hard it springs back. Higher is quicker. |
| `HitTiltDamping` | 14 | How quickly the spring settles. Lower wobbles more. |
| `SkidMinSpeed` | 16 | Going backward this fast after a hit shows the skid. |
| `SkidHoldSeconds` | 1 | How long after a hit a backward slide counts as a skid. |
