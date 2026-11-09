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
| `PropelSpeed` | 84 | Top speed of a dash (Q). It eases up to this, holds it, then eases back down to running speed. |
| `PropelSeconds` | 0.65 | How long the whole dash lasts, its ramp and ease-out included. |
| `PropelRampSeconds` | 0.1 | Seconds of easing up to `PropelSpeed`. Lower = a harder start. It's eased, so speed never jumps from one frame to the next. |
| `PropelCooldown` | 3 | Seconds from pressing propel until it can be pressed again. |
| `PropelEaseOutSeconds` | 0.28 | Seconds at the end of the dash easing from `PropelSpeed` back to running speed, or to nitro's top speed if still boosting. |
| `PropelSteerRate` | 20 | Degrees/s the keys can bend a dash while it runs. Low on purpose: a dash is committed, so the keys can't turn it round. |
| `PropelControlReturnSeconds` | 0.25 | After a dash, normal steering fades back in over this long instead of all at once. |
| `PropelArcDegrees` | 80 | How far a curved dash turns in all. A or D held as Q is pressed curves it that way; A and D together, or neither, is straight. The turn rate is a half sine: gentle at the ends, fastest in the middle. |
| `PropelCurveInputThreshold` | 0.35 | How far the input must point to the side (0 to 1, from the camera) to curve the dash. |
| `PropelCurveBodyLead` | 24 | Degrees the body leans ahead into a curved dash, most in the middle. Past `Effects.DriftPuffMinSlip` (20) it makes drift smoke. |
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
| `ActiveSeconds` | 0.08 | How long a swing stays live after the strike: 0.08 to 0.16 s, the fist sweeping across to full extension. The server sweeps it between frames, so a fast crossing can't slip between checks. |
| `MissRecovery` | 0.1 | Extra seconds before the next punch after one that hit nobody. It's what makes baiting a whiff worth it. |
| `BufferSeconds` | 0.1 | A press this close before the swing is ready is remembered and thrown when it is. Only one is held, and it's dropped if it gets older than this or you can't punch. |
| `Range` | 5 | Radius of a swing's reach from the attacker's root. With `TargetRadius` the forward reach is 6.5 studs centre to centre. |
| `HookOuterDegrees` | 55 | How far to its own side a hook reaches: left for a left hook, right for a right hook. |
| `HookInnerDegrees` | 30 | How far past straight ahead a hook carries, across the body. |
| `UppercutDegrees` | 20 | The uppercut's arc, either way. It's the narrow swing. |
| `CloseRange` | 3 | Radius of the close sector, for someone at your side. With `TargetRadius` it reaches 4.5 studs centre to centre. |
| `CloseDegrees` | 100 | How far round from straight ahead the close sector goes, either way. Under 180 means someone behind you has to be inside `OverlapRadius`. |
| `OverlapRadius` | 3 | Anyone within this many studs, centre to centre (two `TargetRadius`), is hit from any direction, so running through someone still connects. |
| `ComboResetSeconds` | 2 | Seconds without punching before the next swing goes back to the left hook. |
| `HitCancelsPunch` | true | A punch still winding up is cancelled if its thrower gets hit first, so whoever lands first wins the exchange. |
| `MissSpeedKeep` | 0.7 | Share of running speed kept when a punch hits nothing, on the ground only. Lower = a harsher penalty for missing. |
| `HitRecoilSpeed` | 20 | Studs/s the puncher is pushed back when a punch lands. 20 slides about 3 studs. In the air it's scaled by `AirRecovery.HitRecoilShare`. |
| `HitSpeedKeep` | 0 | Share of running speed the puncher keeps when a punch lands, on the ground only. 0 stops them dead. |
| `TargetRadius` | 1.5 | The hurtbox: the radius of the upright capsule that can receive a hit, from `HurtboxBelow` under the root to `HurtboxAbove` over it, the same for everyone. |
| `HurtboxBelow` | 3 | Studs below the root that the hurtbox reaches: the feet. |
| `HurtboxAbove` | 2.5 | Studs above the root that the hurtbox reaches: the top of the head, accessories ignored. |
| `HookBandLow` | -2 | Bottom of a hook's attack volume, from the attacker's root. With the hurtbox, hooks reach 4.5 studs below and above, as the old `VerticalLimit` did. |
| `HookBandHigh` | 1.5 | Top of a hook's attack volume, from the root. |
| `UppercutBandLow` | -1.5 | Bottom of an uppercut's volume. An uppercut reaches 4 below and 5 above. |
| `UppercutBandHigh` | 2.5 | Top of an uppercut's volume: the fist rises above the head. |
| `SweepStepStuds` | 0.5 | Between two server frames the live swing is checked in steps no longer than this. |
| `SweepMaxSteps` | 12 | Most steps per frame, whatever the speed. |
| `CooldownTolerance` | 0.06 | Forgives honest presses arriving bunched by a network hiccup. |
| `MaxRewindSeconds` | 0.3 | Most the server looks back at targets for a high-ping attacker. |
| `InterpolationSeconds` | 0.175 | Added to the attacker's ping when rewinding targets: how far behind everyone else a client draws them. Measured in Studio on 2026-11-05; re-measure on a live server. |
| `AttackerLeadSeconds` | 0.18 | The server sees a player's own body about this late, so the swing is led forward along their server-measured motion by this much. Measured in Studio on 2026-11-05. |
| `AttackerLeadMaxSpeed` | 90 | Fastest motion the lead uses, so a knock or a teleport can't throw the swing far ahead. |
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
| `BaseSpeed` | 55 | Launch speed in studs/s of a punch from a standing attacker on a target with no stagger. |
| `SpeedBonusPerStud` | 0.9 | Extra launch speed per stud/s of the attacker's server-measured speed. |
| `UpwardFraction` | 0.18 | Share of launch speed added upward on a grounded target. |
| `UpwardMax` | 16 | Hard cap on upward launch speed. |
| `AirborneUpwardFraction` | 0 | Share added upward if the target is already airborne; 0 stops punches juggling anyone into the sky. |
| `UppercutLift` | 125 | Studs/s upward from an uppercut, on top of its normal punch push. With `Kick.AirGravityScale` that's about 57 studs high, and about 2.5 s in the air with the falling rule in `AirRecovery`. |
| `BumpPropelShare` | 0.4 | A bump's shove at its hardest, as a share of `Movement.PropelSpeed`: 34 studs/s, about 10 studs of slide. Stagger doesn't add to it. A test checks that it stays under half a propel, even with the faster player's edge. |
| `BumpFullClosing` | 36 | Collision speed for a full shove. Softer collisions shove less. |
| `BumpSoftShare` | 0.4 | The softest a bump can be, as a share of the full shove. |
| `BumpSpeedKeep` | 0.6 | Share of running speed both keep through a bump. |
| `BumpStaggerShare` | 0.5 | A bump's stagger as a share of a punch's: 6, or 7 and 5 with the full edge below. |
| `BumpFullAdvantage` | 30 | How much faster one player must be moving, in studs/s, to get the whole edge below. Less gets part of it, and level speeds get none. |
| `BumpEdgeShare` | 0.15 | The faster player's whole edge: they shove 15% harder and add 15% more stagger, and take 15% less of both. |
| `BumpMinClosingSpeed` | 10 | Two players must close at this speed or more to bump. Softer collisions than this do nothing at all. |
| `BumpDistance` | 3.5 | Two characters this close can bump. |
| `BumpVerticalLimit` | 4 | Largest height difference that can still bump. |
| `BumpPairCooldown` | 0.5 | Seconds before the same two players can bump again. |

## Stagger

| Setting | Start | What it does |
|---|---|---|
| `Max` | 100 | Stagger cap. Stagger is knockback vulnerability, not health. |
| `PerHit` | 12 | Stagger added per punch. |
| `HitRelief` | 6 | Stagger the puncher loses when they land a hit, so winning exchanges is a way back from behind. |
| `MaxKnockbackMultiplier` | 2.5 | Knockback multiplier at full stagger; 1 at none, linear between. |
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
| `StartRadius` | 75 | Radius at round start; about 4 seconds across at MaxSpeed. |
| `SpawnRadius` | 52 | Radius of the 15-spawn ring; about 22 studs between neighbours. |
| `SpawnCount` | 15 | Spawn points, and the round capacity they serve. |
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
| `MinPlayers` | 2 | Players needed to start. Testing default from the brief; 15 is capacity, not a minimum. |
| `MaxPlayers` | 15 | Round capacity. |
| `IntermissionSeconds` | 15 | Lobby countdown once enough players are present. |
| `StartingSeconds` | 4 | Frozen, protected countdown on the spawn points. |
| `RoundOverSeconds` | 6 | How long the result shows before returning to the lobby. |

## Lobby

| Setting | Start | What it does |
|---|---|---|
| `CenterX` | 0 | Lobby centre X. |
| `CenterY` | 100 | Lobby floor height. |
| `CenterZ` | 240 | Lobby centre Z, far enough that knockback from the arena cannot reach it. |
| `Radius` | 55 | Lobby floor radius. |

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
| `GustSeconds` | 0.6 | How long the dash gust takes to fade out. |
| `GustSideOffset` | 1.1 | How far each gust starts from the character's centre. |
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

## Debug

| Setting | Start | What it does |
|---|---|---|
| `MoveReadout` | true | TEMPORARY: small on-screen speed readout for tuning. The real HUD replaces it. |
| `ShowHitbox` | true | TEMPORARY: draws every player's punch hitbox on the floor in see-through red. Turn off before anyone else plays. |
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

The air kick. An uppercut launches someone, who can steer and propel in the air. Space squats, and the server picks who you follow up: anyone launched within `FollowUpOwnRange` (your own uppercut) or `FollowUpRange` (anyone else's), with nothing solid in between, by distance and by how far off where you face they are. It holds them still from that moment, and you snap straight to beside them. Once close, a ring closes; Space as it meets the key. You curl, spin forward, and whip your heel down on them. The kick always connects, and the timing sets its force. A grade in `FinisherGrades` (orange or green) is a finisher: they're launched hard away from you and up, with a moment's loss of control. A red still slams them down. You get a boost of running momentum backward and a small hop, and carry on running.

| Setting | Value | What it does |
|---|---|---|
| `Cooldown` | 15 | Seconds between jumps, hit or miss. Your first jump is ready, and it's the only limit: uppercuts don't earn jumps. |
| `AirGravityScale` | 0.7 | Share of normal gravity on someone launched by an uppercut while they rise, and on the jump after them. From the top of the arc they fall on `AirRecovery`. Lower hangs longer and feels floatier. |
| `JumpSquatSeconds` | 0.067 | Seconds down in the squat before leaving the floor. Must match `JUMP_SQUAT` in `build_clips.py`. |
| `ApproachSpeed` | 260 | Speed the snap's length is worked out from: distance / this, in seconds, kept between the two limits below. |
| `ApproachMinSeconds` | 0.08 | Shortest snap, so it's never instant. |
| `ApproachMaxSeconds` | 0.65 | Longest snap. It must cover `FollowUpOwnRange` at `ApproachMaxSpeed` (a test checks). |
| `ApproachMaxSpeed` | 280 | Fastest the snap ever moves. Keep it under `Security.TeleportSpeed` (300), or the speed audit takes it for a teleport (a test checks). |
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
| `SlamSpeed` | 110 | Studs/s a grade outside `FinisherGrades` (red) drives them down at full force. |
| `BounceLift` | 75 | Studs/s a green kick bounces them up when they hit the floor, about 14 studs, only when green isn't in `FinisherGrades`. |
| `StunMaxSeconds` | 2.5 | Longest a green kick's loss of control can last, whatever else happens. |
| `StunAfterLanding` | 0.2 | Seconds of it left after landing from the bounce. |
| `FinisherGrades` | green, orange | Grades that launch them away and up instead of slamming them down. Red is the failed timing. |
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
| `FallGravityScale` | 0.24 | Share of normal gravity while falling. Lower hangs longer, and makes every recovery easier. The tests fail if punching could ever hold you up. |
| `FallEaseSpeed` | 16 | Falling speed over which gravity eases from a launch's own to `FallGravityScale`. Higher makes the top of the arc softer. |
| `MaxFallSpeed` | 30 | Fastest an ordinary fall gets. A kick's slam isn't limited by this. |
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

## Nitro

Held Shift (L3 on a gamepad). Speed eases toward `SpeedMultiplier` times normal top speed on an S-curve, turning gets harder, the camera pulls in with a light shake, and a trail shows for everyone. Stamina drains while it runs, about 3 s from full, then refills after a delay. Run dry, it stays off until `ExhaustedRecharge` is back. It runs on the ground (or just off it) while moving forward or sideways, and anything that takes the body over ends it: braking, a launch, a hold, a clash, a stun, a kick. The server keeps its own copy of the stamina to decide whether everyone else sees the trail. Tested in `tests/Nitro.spec.luau`.

| Setting | Value | What it does |
|---|---|---|
| `Enabled` | true | Whether Shift does anything. |
| `SpeedMultiplier` | 2 | Top speed at full boost, as a multiple of `Movement.MaxSpeed`. |
| `RampSeconds` | 0.9 | Seconds from no boost to full boost. |
| `RampCurve` | 2 | Shape of the ramp. Above 1 is an S-curve: gentle start, strongest in the middle, settling into the top. |
| `RampAcceleration` | 150 | Extra acceleration at full boost, on top of `Movement.Acceleration`, so speed can follow the ramp. |
| `RampDownSeconds` | 0.35 | Seconds the boost level takes to fall back after it ends, for the turning and the camera. |
| `StaminaMax` | 100 | A full bar. |
| `DrainPerSecond` | 33 | Stamina spent per second of boost. 100 / 33 is about 3 s. |
| `RechargeDelay` | 0.8 | Seconds after the last spend before it starts refilling. |
| `RechargePerSecond` | 14 | Stamina back per second once refilling: about 7 s from empty. |
| `ActivateMin` | 15 | Stamina needed to start a boost. |
| `ExhaustedRecharge` | 40 | Once run dry, stamina needed before it can start again. |
| `AirGraceSeconds` | 0.2 | Seconds off the ground a boost survives, so a bump doesn't end it. |
| `TurnScale` | 0.28 | Share of the normal turn rate at full boost. Still steerable, never locked. |
| `ReleaseDeceleration` | 18 | Studs/s per second the speed over normal top speed bleeds off after a boost. |
| `DashSpeedMultiplier` | 1.35 | A dash pressed while boosting goes this many times faster. |
| `DashDurationMultiplier` | 1.3 | And lasts this many times longer. |
| `DashCooldown` | 3.5 | Its cooldown, instead of `Movement.PropelCooldown`. |
| `DashStaminaCost` | 15 | Stamina a boosted dash costs. Without that much, it's a normal dash. |
| `DashArcMultiplier` | 0.85 | A boosted curved dash turns this share of `Movement.PropelArcDegrees`. |
| `CameraZoomStuds` | 3.5 | Studs the camera pulls in at full boost. |
| `CameraMinDistance` | 6 | It never pulls in closer than this to the character. |
| `CameraEaseIn` | 4 | How fast the pull and shake come in, per second. |
| `CameraEaseOut` | 4 | How fast they go away after a boost. |
| `ShakeStuds` | 0.06 | Size of the shake at full boost. |
| `ShakeRollDegrees` | 0.35 | Roll of the shake at full boost. |
| `ShakeFrequency` | 11 | How quickly the shake moves. |
| `TrailLifetime` | 0.28 | Seconds the trail lingers behind. |
| `TrailWidth` | 1.8 | Height of the trail ribbon, in studs. |
| `TrailColor` | 8FD3FF | Trail and bar colour while boosting. |
| `TrailTransparency` | 0.3 | Transparency where the trail starts; it fades to nothing. |
| `TrailLightEmission` | 0.6 | How much the trail glows. |
| `BarBottomOffset` | 100 | Pixels from the bottom of the screen to the stamina bar, just above the stagger and speed panel. |
| `BarWidth` | 240 | Bar width in pixels. |
| `BarHeight` | 10 | Bar height in pixels. |
| `BarHideSeconds` | 1.2 | Seconds a full, unused bar stays before fading away. |
| `ServerStaminaSlack` | 10 | Extra stamina the server's copy allows, for clock differences. |
| `ServerToggleSeconds` | 0.08 | Shortest gap between two "I started" messages the server accepts. |

## Controls

Keyboard bindings that more than one script needs to agree on. `Key` is an `Enum.KeyCode` name, `Label` what the guide shows.

| Setting | Value | What it does |
|---|---|---|
| `ShiftLock` | LeftControl, "Ctrl" | The game's own shift lock. Roblox's is off (`EnableMouseLockOption` false). |
| `Nitro` | LeftShift, "Shift"; ButtonL3, "L3" | Held for the nitro boost, on keyboard and gamepad. |

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
