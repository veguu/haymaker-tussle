# Haymaker Rush as built (kits-7m): map and diagnosis

Written 2026-11-18 from:
- the code
- the recording `design/references/ours-kits-7m.mp4` (16:9, 30 fps; video time = cutscene time + about 1.53 s)
- two measured play tests in Studio

The play tests ran at about 10 fps, because Studio was in the background. Frame-exact timings below come from the code;
the play tests confirm geometry and order only.

## 1. Where it runs

| Piece | Runs on | File |
|---|---|---|
| Window, request, validation, roles (`HT_Ultimate`), ring-out credit, release timers | Server | `src/server/Services/UltimateService.luau` |
| Choreography: keys, shots, cues, swings, blows, clips, jitter/jolts, flight path | Shared pure maths | `src/shared/Core/Ultimates.luau` |
| Per-frame playback: bodies, swings, clips, camera, UI hide, grade, dip | Every client, RenderStepped | `src/client/Controllers/UltimateController.luau` |
| A bot/dummy target's REAL body (what other players get replicated) | Server, Heartbeat | `src/server/Services/DummyService.luau` (`CarriedPose` branch) |
| Animation tracks (SyncSwing, SyncClip, SetBarrage, SetDash, HitLanded flinch, StretchArm) | Each client, locally | `src/client/Controllers/AnimController.luau` |
| Clips (RushIn, UpperSet, LeapUp, HaymakerUp, BarrageUp, Dangle) | Baked by Lune into `Config/AnimClipsUltimate.luau` | `animations/build_strikes.luau` |
| Cues to effects (flash, darken, impact frames, leap dust, blast) | Each client | `src/client/Fx/UltimateFx.luau`, `ImpactFrame.luau`, `CutsceneScreen.luau` |

Ownership and ordering:
- The cutscene is fully scripted on the shared server clock (`GetServerTimeNow() - startedAt`).
- Every client sets BOTH roots by CFrame every RenderStepped, from `Ultimates.pose`, plus `Ultimates.tilt` for the target.
- The server also sets a dummy target's root every Heartbeat (lookAt only, no tilt). On a fighter's screen, the
  client's RenderStepped write wins, because it is the last write before render.
- Nothing is anchored:
  - `Practice Dummy 1` measured `Anchored = false` on the server and on the client through the whole cutscene.
  - Players are never anchored by this code.
  - Bodies are CFrame-driven with velocity zeroed, so physics plays no part until the flight ends.
- The camera is Scriptable on the two fighters' screens only, set every frame from `Ultimates.shot` plus shake.
- Cleanup on end or when the attacker leaves (the connection's last block):
  - stops the barrage and the dash
  - turns `SetCutscene` off
  - stops the clips
  - removes the grade
  - restores the UI and the core UI
  - sets the camera back to Custom with the FOV before
- The server releases roles at `attackerFree` and at `cinematic + FlightSeconds`.

## 2. The timeline (cutscene seconds)

| t | Beat | Body driver | Camera |
|---|---|---|---|
| 0-0.40 | lock-in | RushIn clip 0-0.36 (fist cocked, turned away) | insert on the attacker, slow push |
| 0.40-0.48 | launch crouch | RushIn 0.40-0.48; root held | CUT: fixed camera behind the start (`rel=start`) |
| 0.48-1.14 | rush | root LINEAR from start to 1.5 studs from the target; RushIn's held stride; `SetDash` puts Sprint at weight 1 under it; HookRightRun from 0.98 | same fixed camera, the runner moving away |
| 1.14 | running hook | swing synced to contact; freeze 0.2 | flash, CUT to a low 3/4 two-shot |
| 1.70-3.58 | flurry, 16 hits | BarrageUp synced; target juggled 3.2 up, Dangle clip, pitched -30 | one held framing, slow smooth drift, jitter 0.07 |
| 3.58-3.84 | set | UpperSet clip; target dropped to 0.5 up | same drift |
| 3.84 | uppercut | Uppercut swing synced (contact -0.014); freeze 0.25; target tilt +25 then +40 (arched back) | flash, CUT to a worm's-eye front-side |
| 4.09-4.26 | target flips up | target to (0, 4.5, -2.3), tilt 170 | held |
| 4.15 | player alone | LeapUp clip from 4.18 | CUT to an insert on the attacker (`rel=attacker`, rides with them) |
| 4.26-5.05 | leap | attacker root from the ground straight UP 6.6 studs (z unchanged: 0.2 studs of travel back) | rides with the attacker, smooth |
| 4.40-5.50 | haymaker coil | HaymakerUp synced over 1.1 s: its 0-0.25 coil (arm from guard to 150 deg behind the hip, torso -70) takes 0.86 s; LeapUp is still on until 4.60 | as above |
| 5.05 | facing | target hangs 9.6 up | CUT to a low two-shot (`rel=pair`) |
| 5.26-5.50 | strike | HaymakerUp 0.25-0.32 (arm sweeps 158 deg, back to front) | push in, then ease-IN zoom to FOV 40 |
| 5.50 | contact | blow: freeze 0.75, slow 0.18; HitLanded plays HitFlinchHeavy on the target (no pose clip holds it) | held close-up; impact frames |
| 5.50-6.25 | "slow drive-through" | target moves 0.4 studs in 0.75 s (measured 0.4-0.7 studs/s) | held close-up |
| 6.25 | blast | target 1.4 studs in 0.12 s, then 2.1 in 0.23 s, eased OUT to rest at 6.60 | CUT behind and below, in line with the throw |
| 6.60-7.90 | flight | `Ultimates.flightPoint`: constant horizontal speed from frame 1 (measured 55-160 studs/s); the root rotation REPLACED by `CFrame.Angles(share*14, share*6, 0)` | chase, FOV to 95 |
| 7.95 | end | dip to black; restore | |

## 3. The six problems: root causes

### 3.1 The torso doesn't face the fist at impact

CONFIRMED, measured in play from the pose actually shown (computed on the attacker's client):

- **Haymaker.**
  - In the 0.25 s before contact, the target's chest normal was -0.31 to -0.53 in Y, pitched down toward the fist
    coming up from below. That is correct.
  - On the contact frame it jumped to (-0.50, +0.16, 0.85): yawed about 30 deg and tipped up about 9 deg.
  - The fist then meets the chest at 101-121 deg to its normal, a glancing hit along the side. A square hit would be
    near 180.
  - The recording agrees: at 7.47-7.80 s the white fist sits against the SIDE of the orange torso, with the target's
    arm sticking out past it.
- **Cause:**
  - `AnimController.HitLanded` plays a flinch clip (HitFlinchHeavy, or HitFlinchBack) on the target at the heavy blow.
  - It is held through the 0.75 s hit-stop (`stopUntil`).
  - The kits-7m rule "no flinch while a pose clip holds the body" doesn't apply here: `targetClips` ends at 3.64 s, so
    no clip holds the target at the uppercut or the haymaker.
  - The flinch turns and arches the upper body away from the blow, on the contact frame itself.
- **Uppercut.**
  - The timeline's own `targetTilt` at contact is +25 deg (head back, chest up), +40 through the freeze, so the chest
    faces up and away from a fist rising from below.
  - Measured at 3.83 s: the fist reaches the torso (gap 0.21) at 58 deg off the chest normal, under the ribs.
  - On the next frame the flinch adds a 30 deg yaw: the chest normal goes to (-0.50, 0.85, 0.18).

### 3.2 The uppercut should send them farther back, so the dash is longer

CONFIRMED from the keys:
- The uppercut lifts the target straight up: z goes from -1.84 to -2.3 at 4.26 s, then to -2.84.
- The attacker's leap starts at z = +0.36 and ends at z = +0.56.
- So the "dash" is a vertical rise of 6.6 studs with 0.2 studs of horizontal travel. Nothing in the timeline sends
  the target back, so nothing motivates a dash.

### 3.3 The opening rush reads strangely

CONFIRMED from the keys, clips and recording (video 2.0-2.67 s):

- **The body.**
  - RushIn holds one stride pose (feet fixed) while the root slides linearly over about 10 studs in 0.58 s: a
    statue skating over the ground.
  - Sprint is turned on underneath (`SetDash`), but RushIn is Action priority and keys every limb, so the legs never
    cycle.
- **The camera hides the pose.**
  - The camera is fixed straight behind the runner, so the forward lean (38-50 deg) and the stride are along the lens
    axis and foreshortened away.
  - From behind, the attacker reads as an upright figure shrinking.
  - The owner's pick C5-A (over the target's shoulder, the attacker charging AT the lens) was never built.
- **The start.**
  - The first 0.36 s is a static lock-in, turned away.
  - Then the root sits still for the 0.08 s launch crouch and moves at full speed from the next frame.
  - There is no acceleration and no deceleration into the hook: the speed is constant at about 18 studs/s, then
    stops dead at contact.

### 3.4 The arm rotates in the wind-up between the dash and the final punch

CONFIRMED from the clip keys and the swing timing:
- HaymakerUp is synced over 1.1 s (4.40 to 5.50).
- Its coil (clip 0-0.25: the right arm aimed from the guard to sweep 150 deg, fist behind the hip, torso turning to
  -70 deg) is spread over 0.86 s of the rise. The arm visibly winds back for most of the leap.
- The strike then sweeps the arm's aim from 150 deg to -8 deg in 0.24 s. That is a 158 deg rotation round the
  shoulder, because keyed arms blend their DIRECTION, so a back-to-front aim change is a swing, not a thrust.
- Overlap:
  - LeapUp (Action priority, arms up 70 deg in its extension) is still synced until 4.60.
  - HaymakerUp (Action2) starts at 4.40 from the guard. For 0.2 s the arms jump from LeapUp's raised arms to the
    guard, and then into the coil.
  - When LeapUp stops at 4.60, its fade-out adds a third blend.

### 3.5 The knockback looks delayed

CONFIRMED, measured:
- **Contact to visible motion is 0.75 s.**
  - Contact at 5.50, blast at 6.25. In between, the target moved 0.4-0.7 studs/s (0.45 studs in all).
  - The impact frames (0.29 s) are followed by 0.46 s of an almost still close-up. In the recording the knockback
    first shows at video 7.87 s, 0.84 s after contact.
- **The handoff to the flight stalls.**
  - The blast keys ease OUT to rest at 6.60 (measured 20, then 4.2 studs/s).
  - The flight starts at full speed on the next frame (measured 56, then 101 studs/s).
  - The target slows almost to a stop, then jerks away.
- **The rotation pops at the handoff.**
  - The flight replaces the tilted root (720 deg pitch about the anchor's facing) with
    `CFrame.new(at) * CFrame.Angles(...)` from 0, in world axes.
  - Measured: a 46 deg jump on the first flight frame.
- **Anchoring is NOT the cause (hypothesis rejected).**
  - The dummy measured `Anchored = false` on both server and client through the whole run.
  - The target is moved by CFrame every frame anyway, so anchoring could not delay it.
  - No velocity, constraint or humanoid state code holds it; DummyService's ultimate branch only sets CFrame.

### 3.6 Stiff camera and bodies

CONFIRMED from the code:

- **Bodies.**
  - The bodies run on straight-line key interpolation, with no carried velocity: a key with no `ease` is linear.
    Moves start and stop at full speed (the rush, the set, the facing), and a whole beat holds dead still (the hook's
    and uppercut's freezes hold both roots exactly).
  - The attacker's root is always upright and yawed only (`CFrame.lookAt` flat), so a lean exists only inside a clip.
- **Camera.**
  - Shots after a cut that aren't `ease = "smooth"` are linear or held: the rush shot crawls linearly, and the hook and
    uppercut shots hold dead still for their freeze.
  - `rel = "attacker"` and `rel = "pair"` shots are rigidly locked to the bodies, with no lag or lead. When the body
    moves linearly, the camera moves linearly with it, so the leap shot rides the attacker 1:1.
  - The haymaker zoom eases IN to the contact and stops dead (held 0.75 s).
- **Pose clips are synced by TimePosition with speed 0**, so between keys nothing overlaps or drifts beyond what the
  clip bakes.

## 4. Not a cause (checked)

- **Anchoring:** see 3.5.
- **Network replication:**
  - The fighters' screens pose both bodies locally every frame.
  - The server's tilt-less dummy pose is overwritten before render on those screens.
  - Bystanders see the server's tilt-less pose for a dummy. That is a separate, small issue: other players watching
    see no tilt.
- **Competing camera scripts:** none found. The camera is Scriptable, and only UltimateController writes it during the
  cutscene. `execute_luau` resets it when a long call ends; that only affects tests.
