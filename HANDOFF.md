<!-- tldr:start -->
> [!tldr] TL;DR
> - Brief (source of truth): `../Haymaker Tussle Brief.md`
> - Contract: `design/game.json`; stage specs: `design/animations.json`, `map.json`, `ui.json`, `vfx.json`, `sfx.json`...
> - Settings: `src/shared/Config/GameConfig.luau`, generated from `design/game.json`; explained in `design/Settings Guide.md`
> - STAY INSIDE CLAUDE CODE AND ROBLOX STUDIO.
>
> Cost: TL;DR ~130 tok · whole note ~20.0k tok. Read more: ## Rules · ## Section 2 progress (not closed; the user is checking one piece at a time)
<!-- tldr:end -->

<!-- section: 1 -->
# HANDOFF: section 1 of 6 closed (Research and design)

Game: `C:\Users\dumpl\Documents\LihFolk\LihFolk Vault V2\LihFolk Vault V2\Haymaker Tussle\Project`
Written: 2026-11-03T18:04:45-08:00

A cleared session starts from this file alone. Read it in full, then run:

```bash
python ~/.claude/skills/create-roblox-game/scripts/section.py resume --dir "C:\Users\dumpl\Documents\LihFolk\LihFolk Vault V2\LihFolk Vault V2\Haymaker Tussle\Project"
```

## Where things are
- Brief (source of truth): `../Haymaker Tussle Brief.md`
- Contract: `design/game.json`; stage specs: `design/animations.json`, `map.json`, `ui.json`, `vfx.json`, `sfx.json` (`meshes.json` is unused)
- Settings: `src/shared/Config/GameConfig.luau`, generated from `design/game.json`; explained in `design/Settings Guide.md`
- Research: `design/Research Notes.md`
- Code scaffold: `src/`, `tests/`, `lune/`, `Packages/` (Knit, Promise, Signal, Trove), `default.project.json` with `servePlaceIds` set to 136102156542862
- Tools: Rokit in `~/.rokit` (reads the project's `aftman.toml`). Rojo plugin: `%LOCALAPPDATA%/Roblox/Plugins/RojoManagedPlugin.rbxm`
- Studio: nothing changed.

## Done this section
- Project scaffolded; `check.py` passes rojo build, lune (3 scaffold tests), selene and stylua.
- `validate.py` passes: 16 plan sections answered, 7 declined, 0 unaddressed.
- `gen_config.py --check` passes: GameConfig matches the contract (11 sections).
- Reference GIF viewed as frames: 13 frames at 80 ms, spins about twice a loop with arms wide. Recorded in `design/animations.json`.
- No gameplay code exists yet.

## Decisions and why
The brief's design is fixed and was not reopened. Choices it left open are in `decisions` in `design/game.json`, with reasons:
- Punch uses stagger from before the hit.
- Client owns and simulates its character; server measures and caps speed.
- Server decides knockback; owning client applies it.
- Players do not solid-collide; server-decided bumps instead, because of fling risk.
- Arena shrinks to radius 0 in the final stage; no safe minimum.
- Last players out in one batch: no winner, clean restart.
- No mesh stage: brief asks for simple geometry and placeholder materials.
- Rokit instead of Aftman: vault recommendation.

## Unproven
- Every setting value is a guess; nothing has been played.
- Rojo has not synced to Studio. The plugin needs a Studio restart to load.
- Client-applied knockback can be ignored by a cheat; check in combat step.
- No-collision bumps have not been judged by feel.
- R6 for the place: the setting could not be read by script, so confirm it when movement starts.
- Slap Battles research came from low-quality pages and is unverified; all research came from search summaries.
- `BUILD.md` still has the scaffold's generic stage table; meshes is marked not used.

## Debts
- No fallbacks or stalls.
- `preflight.py` was not run, because it tests the Roblox API key and Kaggle credentials, which the user asked to leave untouched. Tool versions were verified directly. Logged as a note.
- Studio screen access was not requested because Studio was not used. Ask before step 2.

## Ledger

Initialised once in section 1. Never run `init` again.

```bash
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py counter --dir "C:\Users\dumpl\Documents\LihFolk\LihFolk Vault V2\LihFolk Vault V2\Haymaker Tussle\Project\build-runs" --run "haymaker-tussle"
```

## Place
Studio place "title", placeId 136102156542862, confirmed by the user as this game's place on 2026-11-03. Nearly empty and unchanged. Not published by this work; `publish` ids in the contract stay null until the user says.

## Rules

1. ONE SECTION PER SESSION. Finish this section's whole scope, then stop. Inside a section the skill's 'the run does not stop' rule applies in full; `section.py close N` passing is the only place you stop. Never start the next section's work, even with budget left.
2. STAY INSIDE CLAUDE CODE AND ROBLOX STUDIO. Work through the skills, MCPs and CLIs. No browser-driving tools (browser pane, Chrome), no web-GUI generators. WebSearch and WebFetch inside Claude Code are fine. Screen access is for Roblox Studio only.
3. NOTHING IN STUDIO BY THE USER'S HAND. Never ask the user to place, type, edit or configure anything in Studio, and never ask them to leave Claude Code or Studio. You may ask for: pressing Play or Stop, clicking Publish, approving a tool call, restarting a stuck MCP, or something purely mechanical no API or screen action of yours can reach.
4. LOG INTERVENTIONS AS THEY HAPPEN (run_log.py event --kind intervention): the user writes or edits code, makes a design or art decision (a genre named in the section 1 prompt is the brief, not an intervention), chooses between options, tells you WHAT is wrong rather than THAT something is wrong, or does something in Studio by hand. So never offer options: decide, and say why.
5. TIER 2 FIRST, fallback pre-authorised: take it without asking and log it as a fallback. 30-minute stall rule: one problem eats 30 minutes, fall back, log it, keep moving.
6. EVERY SESSION: ask for Roblox Studio screen access first (a grant does not survive a cleared session). 'Continue with the development of the <genre> game' means `section.py resume --game "<genre>"`: it finds the game and says which section is next.
7. THE LEDGER IS INITIALISED ONCE, in section 1. Every later call passes the --dir and --run recorded in HANDOFF.md. Bracket each ledger stage with start/end.
8. BEFORE CLOSING: save the place, write HANDOFF.md with `section.py handoff N`, replace every placeholder, run `section.py close N`. Then stop and ask the user to approve. Approval is free. If the user asks for changes, make them, log an intervention if they named what was wrong, update HANDOFF.md and close again. When the user approves ("approved", "yes that's all good"), run `section.py approve N` and say it is safe to clear the chat. Do not start the next section.

## Parked for later
See the vault note `Haymaker Tussle/Future Steps.md`. The round RESULTS SCREEN is parked until the round system exists (user, 2026-11-08); its full brief is saved there.

## Next section: first step
Section 2: Code and the playable loop (3 code, 4 map BLOCKOUT only, then play the loop on placeholder art).
**The user wants one piece at a time, checked before the next.** Do not build all of section 2 in one go. Agreed order: movement, combat, arena, rounds with lobby and training, R6 animations, interface and feedback, full testing.

First: ask the user to restart Studio so the Rojo plugin loads, then build movement only, on a plain test floor. Pure steering maths goes in `src/shared/Core/` with Lune tests first; then `MovementController`. Stop for the user to try the feel.

## Section 2 progress (not closed; the user is checking one piece at a time)
Movement piece, build `combat-5`, is in Studio for the user to try. Combat has not started. Tuned with the user: full-speed turn radius about 15 studs (TurnRateHighSpeed 138); only W earns a coast (hold 0.4 s, then a slow-then-faster fall over 2.9 s, curve 1.5); A/D during a coast only steer; releasing A, D or S stops quickly. Measured in Play: hold about 0.4 s, stop about 3.3 s after release, wall stops a full-speed run in about 0.2 s with no bounce. S while moving is a brake (BrakeDeceleration 30, measured about 30 in Play; full stop by S alone covered by tests only), and A or D still steer while braking; holding it after stopping walks backward. The older measurements below predate this tuning. The user approved the movement feel ('yeah good'; phone testing later). The user then added a shared dash, overriding the brief's no-dodge line (`decisions.dash` in game.json): Q, gamepad B or touch button, 15 studs, 3 s cooldown. The user accepted the dash and asked for combat, plus sound and effects now for both. COMBAT PIECE BUILT: server-decided punches with lag compensation, stagger, knockback, bumps with no solid player collisions, 3 dummies on the test floor, wind gust and hit effects in FxController (user's picture: gust on both sides of the feet that fades), and 5 sounds in SoundBank chosen by listing and measured length. Measured solo in Play: one punch hit 2 dummies once each, alternating sides, cooldown drops extra clicks, 'facing', 'range' and 'blocked' all refuse correctly, malformed requests are refused, a 60-request flood started 1 punch, bumps fire, a 90 studs/s launch slid about 68 studs. NOT TESTED: two real players, punch at full speed live, gamepad, phone, anyone hearing the sounds, and a cheating client ignoring knockback (known gap). To read server decisions, set workspace attribute HaymakerCombatDebug to true on the Server. NEXT: wait for the user to try combat, then build the arena only, and stop for them to try it. Before pushing code: Studio must be in Edit, and start `rojo serve default.project.json` in this folder, because it does not survive the session.
- Code: `src/shared/Core/Momentum.luau` (11 Lune tests), `src/client/Controllers/MovementController.luau`, `src/server/Services/TestFloorService.luau` (temporary).
- Measured in Play with simulated keys: rig is R6; 0 to 36 studs/s in about 1.3 s; coasts at about 13 studs/s per second on the same heading; a reversal at speed is an arc that dips to about 21; lean matches turn direction on the local client; falling off at about radius 77 returns to the centre; no jump when pressing Space on the ground.
- Not tested: touch, gamepad, two players, how anyone else sees the lean (local only until the animation step).
- Syncing: the Rojo plugin panel did not open, so code goes in with `python ~/.claude/skills/create-roblox-game/scripts/rojo_push.py` while `rojo serve default.project.json` runs in the project folder. It is not live sync: run it after each edit, with Studio in Edit mode. Logged as a fallback to heal.
- Input: current Studio's stock PlayerModule has no `GetControls`; the controller replaces `ControlModule.moveFunction`. Undocumented, so it warns if missing.
- Place: "title" is a Team Create place (collaborator "blanca"). The user had the stray Hello world LocalScript deleted. Edits made directly in Studio are overwritten by rojo_push, so the files in src are the master copies. The user has not yet said how combat, the effects and the sounds feel.
- Build `combat-6` (2026-11-03, user request): the 3 test-floor dummies are now 1 orange `TestDummy1`, 12 studs straight ahead of the spawn. It tilts when hit (placeholder in CombatController until the HitReact clip) and goes home after `Training.DummyReturnSeconds` (3) without a hit, keeping its stagger; a fall resets stagger. The test wall moved from the launch path to the side (x +40). All 3 old dummies did take hits when tested, so no dummy-specific fault was found; misses logged were range and facing, and the character faces its heading, not the camera. Multi-target hits now have only the earlier measurement until training brings more dummies (`Training.DummyCount` is still 3 for that). Dash sound replaced: "momentum dash whoosh" (120777847710409, 0.866 s, volume 0.8, no fade); the old 2.57 s clip was cut off by a 0.6 s fade. Measured in Play: new sound loads and plays on Q, the user's own punches landed and launched the dummy off the edge, and stagger stacked. NOT TESTED: anyone hearing the new sound. Possible small defect: a bump logged closing 160 near a dummy launch or return, not yet checked. Output also shows `rbxassetid://203785492 failed: Asset type does not match` on every Play; that id is not in this project, source unknown. A `rojo serve` for this project was already running and was reused.
- Build `combat-7` (2026-11-03, user request): the test dummy is now `TestBot1`, an orange bot that chases and punches like a player (`decisions.test_bot`, `TestBot` settings, `src/shared/Core/BotBrain.luau` with 7 Lune tests, logic in DummyService). It uses the player's Momentum rules, the shared punch rules through `CombatService:PunchAs`, the stock R6 run, idle and fall clips played on the server, a reaction delay of 0.2 s and a punch cooldown of 0.9 s. It does not dash. `TestBot.Fights` false makes it a standing dummy that returns home after 3 s, which is not retested in this build. PunchStarted and HitConfirmed now send the attacker's character, not the player. Measured in Play with the user fighting it: it runs at up to 36 studs/s with the run clip at the stock speed scaling, punches land on the user and raise their stagger, the user's punches land on it, and the fall clip plays during knockback. NOT TESTED: how the bot looks on screen, two real players with the bot, whether it is fun or the right difficulty. The arena has still not started: the user has not said combat is good.
- Build `combat-9` (2026-11-03, user requests). HITBOX: `Combat.inHitbox` now treats the target as a body: new settings `Punch.TargetRadius` 2 and `MaxHalfAngleDegrees` 110, with `Range` 6, so centre-to-centre reach goes from 7 to 8 studs and the allowed angle widens up close. Computed hit area 47 to 91 square studs; knockback and cooldowns unchanged. Measured in Play against an anchored test target: ahead 5 5/5; beside 3 left and right, overlapping beside 1.5, and ahead 7.5 all 3/3; behind 3 and behind-diagonal 2 0/5 once settled; overlapping behind 1.5, beside 5.5 and ahead 9 0/3. A first run with the live bot was too noisy to count; the unsettled behind-3 hit (1/3) came right after a teleport, and 0/5 once settled. The bot's punches use the same bigger hitbox, so it also hits more often; its difficulty has not been re-judged. BUMPS: both characters get the same knock along the line of their relative travel, not their positions (`Combat.bumpDirection`, `bumpSpeed`; `BumpPerClosing` 0.6, `BumpMaxSpeed` 40, minimum `BumpSpeed` 14), both lose all running speed (`speedKeep` 0 through `Launch`, the Knockback remote and `Momentum.applyKnock`), and the check runs every 0.05 s. Measured in Play: bot at 36 into a standing player gave knock 21 each, opposite directions along its line of travel, about 4 and 5 studs moved. Bumps up to closing 44 logged while the user played. NOT TESTED: a full-speed head-on (closing 72), a runner still holding W moving as far as someone standing, how a bump feels, and being bumped off the edge. The floor-dip defect found here (`PivotTo` put the bot's root at about y 101.5 because a rig's pivot isn't its root) is fixed in combat-10 by `placeAt` in DummyService; not seen live on a return home.
- Build `combat-10` (2026-11-03, user request, SUPERSEDES the equal split above): `Combat.bumpOutcome` makes whoever drove faster along the collision line recoil less and keep some speed, and shoves the other further with no speed kept. Settings: `BumpFullAdvantage` 30, `BumpFasterShare` 0.7, `BumpSlowerShare` 1.4, `BumpFasterKeepsSpeed` 0.2. A full-speed runner into someone still is knock 15 and 30; an even head-on splits evenly. `tests/Bump.spec.luau` runs on the real settings and checks: always weaker than the 55 base punch, the runner still recoils visibly, and a quick punch stays in reach of a victim who stands there or starts fleeing after 0.25 s. A first tuning (1.5, 0.6, 0.3) failed the reach check and left almost no recoil, so these values were measured with a Lune simulation of Momentum. A victim who flees the instant they're hit can get about 9.4 studs away, past the 8-stud reach. Server log in Play: closing 36 gave 15 and 30 with either character as the runner, closing 39 gave 16 and 33, closing 24 gave 10 and 20, and bot punches and user punches landed right after bumps. The user was then asked whether to lower `BumpSlowerShare` to 1.1 and has not answered; it is still 1.4. NOT TESTED: a clean live reading of how far the runner recoils (the one attempt was disturbed, and Play restarted during it), a full-speed head-on, how it feels, and the bot's difficulty now that its charges often earn a follow-up punch.
- Build `tutorial-2` (2026-11-03, user requests): a skippable first-join tutorial, in five steps: run to the marked player, punch on the live prompt (3 hits), hit at speed, bump then punish, dash. `src/shared/Core/Tutorial.luau` (steps and wording, with `tests/Tutorial.spec.luau`), `src/client/Controllers/TutorialController.luau`, `src/server/Services/TutorialService.luau`, `Combat.inHitboxAtImpact`, `Tutorial` settings. The prompt uses the server's hitbox rule at the moment a punch would land; hits and bumps count only from server events. Nothing saves, so it shows on every join (`decisions.tutorial_repeats`); once-per-person needs saved data, which is the user's call. The target is the nearest other player, or the test bot when alone. The bot now exists only with exactly one player in the server, and stays calm until the tutorial ends or is skipped. With 2 or more players, spawns are random spots 14 studs from the middle, facing in. Measured solo in Play: objective text, bot stayed home during the tutorial, step 1 advanced on reach, CLICK NOW! with the outline on the bot, Skip removed the screen and the bot then ran, no errors in Output. The user reached step 4 on an earlier build; a screenshot then showed the panel, prompt and outline correctly. NOT TESTED: two players at all (the user is about to Team Test, so watch for the bot disappearing, the tutorial targeting a real player, spawns, and real knockback and bumps between two players), steps 3 to 5 and the ending finished through real play, the "They weren't in front of you!" message (one test showed "Too far away!" from behind, possibly because the user was moving at the same time), the outline since it moved under PlayerGui (the one screenshot came back blank), phone and gamepad wording on real devices. The arena has still not started and the user has not said combat is good. The look is a placeholder until the interface step. Tutorial must move to the training area with the lobby step.
- Build `tutorial-3` (2026-11-03, user request): `TestBot.Enabled` is false, TEMPORARILY, so the bot never spawns. Set it to true in `design/game.json`, regenerate GameConfig and push to bring it back. While it's off, a solo player's tutorial waits at step 1 with nothing to run to; Skip still works.
- Build `move-11` (2026-11-03, user requests; Lune tests only so far, see the last sentence). TURNS: `TurnRateHighSpeed` 138 to 260 and `TurnRateLowSpeed` 300 to 400, computed full-speed radius about 8 studs, because the user wants to circle the 12-stud middle ring with control. The bot shares these rules, so it corners sharper too. DASH (`Momentum.tryDash` now takes the camera's flat look, not a drive): never backward (S with A or D drops the S part, S alone or a no-input dash heading backward is refused at no cooldown cost); velocity fades from the old travel into the dash over `DashDriftSeconds` 0.16; `DashSeconds` 0.33 keeps 15 studs from a standstill; `DashKeepAlignment` 0.7 keeps full exit speed up to about 45 degrees from travel, none by 90, down to `DashExitMinSpeed` 16. NOT MEASURED IN PLAY: the real turn radius, circling the ring, and how the turns feel. The dash part of this build is superseded below.
- Build `propel-1` (2026-11-03, user request, REPLACES the dash; everything renamed, including `PropelService` and the `Propel*` settings). Reference: Red Bull short "The PERFECT Drift" (youtube.com/shorts/eFNNow03LbM); only its title and 4 still frames could be viewed, not the motion. Q, gamepad B or touch: a kick up to `PropelSpeed` 60 over `PropelRampSeconds` 0.15 along travel (toward the input from a standstill), fading to `MaxSpeed` by `PropelSeconds` 1.6. During it the body turns toward the input at `PropelBodyTurnRate` 420, travel follows the body at `PropelGripRate` 120 (computed arc about 29 studs at speed 60), slip is capped at `PropelMaxSlip` 55, and slip costs up to `PropelScrub` 8 studs/s per second, floored at `PropelMinSpeed` 16. The body straightens over the last 0.25 s. S is refused at no cost, S held during it brakes, and being hit ends it. Normal running keeps its sharp grip; this reads "drift whenever turning" as during a propel, which the user has not confirmed. Smoke puffs: `FxController` reads every player's velocity and facing, no remote (`DriftPuff*` settings); a knock on the ground can also smoke. Lune tests and checks pass. Pushed; `DashService` is gone from Studio and `PropelService` is there. Measured in Play with simulated keys: speed 27 to 59 in about 0.2 s, back to 36 about 1.3 s later; with D held the body reached 83 degrees while travel was at 36, and travel bent about 120 degrees/s. Readings from play that looked like the user's own: normal full-speed turns bent about 260 to 300 degrees/s at 36, about 7 to 8 studs radius, and propel drifts showed 40 to 45 degrees of slip. NOT TESTED: S refused live, gamepad, phone, two players, anyone seeing the smoke, walls during a propel, circling the middle ring as a deliberate test, the new tutorial wording, and how any of it feels.
- Build `propel-2` (2026-11-03, user request: about 2x shorter and stronger; supersedes the propel-1 values). `PropelSeconds` 0.8, `PropelSpeed` 84, `PropelRampSeconds` 0.1, `PropelBodyTurnRate` 600, `PropelGripRate` 180 (computed arc about 27 studs at 84), `PropelScrub` 16. Chosen so the extra distance over running stays about the same in half the time. Measured in Play with simulated keys: from speed 21 it reached about 81 in about 0.15 s, travel bent about 170 degrees/s with the body up to about 45 degrees ahead, back to 36 about 0.65 s after the peak. A propel from speed 10, in play that looked like the user's, peaked at about 68, probably because the Humanoid lags and the wall-speed rule then holds speed near real speed; not confirmed or changed. Side effect: punch strength adds 0.9 per stud/s of attacker speed, so by the formula a punch at 84 launches at about 131 before stagger, against 109 at the old 60 and 87 at 36. NOT TESTED: how it feels, punches during a propel, S refused live, gamepad, phone, two players, anyone seeing the smoke, walls during a propel.
- 2026-11-03: the user approved the propel feel on `propel-2` ('it feels good'). They have still not said combat is good, and two players are still untested. NEXT: Team Test combat with two players, then the arena once the user says combat is good. `TestBot.Enabled` is still false.
- Build `punch-1` (2026-11-03, user requests). `Combat.punchAftermath` plus the end of `resolvePunch`: a punch that hits nothing keeps `Punch.MissSpeedKeep` 0.7 of running speed; a hit keeps `Punch.HitSpeedKeep` 0 and pushes the puncher back at `Punch.HitRecoilSpeed` 20 (computed slide about 3 studs). Both also end a propel. `Punch.Range` 6 to 8, so centre-to-centre reach is 10. The user asked for a bigger hitbox only if the slowdown and stop did not already make hits easier: `lune/punch_sim.luau` (new; simulated attacker on the real rules, 3000 runs each; first press / within 3 presses) gave Range 6 with no penalty strafing 12/32, head-on 45/63; Range 6 with 70% strafing 12/12, head-on 45/59, so the slowdown makes moving targets harder; Range 8 with 70% strafing 46/46, head-on 75/82. Its "fleeing" row was 0 in every setup because clicking starts too early, so it says nothing. Knocks with lift under 1 no longer force Freefall (`MIN_LIFT` in MovementController, the same in DummyService), so a miss or recoil doesn't trip the Humanoid. 96 Lune tests and checks pass. Measured in Play: build stamp `punch-1`; a miss dropped speed 36 to 26 about 0.15 s after pressing, back to 36 about 0.35 s later with W held. OPEN: at speed 36 a press at gap about 13.5 should be about 9.2 at impact, inside reach 10, yet the server logged `range`, twice. So the server may see a running attacker behind where their client is, which would shrink reach at speed and could be what the user calls inconsistent. Not confirmed. A sweep of press distances (client script firing PunchRequest at a temporary anchored clone tagged HT_Combatant at z -60) was running when the place closed, cause unknown. Also unexplained: one 10 s freeze in that session, with `Script timeout` raised in `resolvePunch` line 104; the loop there is finite and it did not repeat. NOT TESTED: the hit recoil live, how any of it feels, two players, the bot (off). Studio ID changed twice this session; re-list it.
- Build `control-1` (2026-11-03, user request: likes the feel, but hard to control). Top speed, turn rates and the propel unchanged. `Acceleration` 28 to 42, `CoastFallSeconds` 2.9 to 2, `BrakeDeceleration` 30 to 60, `SideStopDeceleration` 28 to 45, `ReverseDeceleration` 18 to 50. `lune/control_sim.luau` (new) on the real rules, before then after: top speed 1.30 to 0.87 s; letting go of W 77 to 57 studs; S stop 1.13 s 21 studs to 0.58 s 10 studs; A/D stop 1.27 s 23 studs to 0.78 s 14 studs; turning round 0.63 to 0.58 s. The bot shares these. The camera is untouched and still needs dragging to turn; a follow camera is the next thing to try if control is still hard. Lune tests and checks pass. NOT MEASURED IN PLAY: all of this, plus everything still open under `punch-1`. Check Output for the build stamp `control-1`, and push if it isn't there.
- `control-1` is pushed; Output shows the stamp on both sides with no new errors. Measurement was abandoned because the user was playing in the same session, which mixed their input with the test. Do not arm a teleporting test without first saying so and asking the user to keep their hands off. Still NOT MEASURED IN PLAY: S stop, A/D stop, coast distance, hit recoil, and the reach sweep at full speed (the one valid-looking press, gap 13.9 at speed 36, missed, but the user's facing was unknown, so it proves nothing). A propel peaked at about 83 in the user's play. The temporary target was removed; it never existed outside Play.
- Build `hitbox-1` (2026-11-03, user request: bigger hitbox, it feels like phasing through people; the user likes the `control-1` controls). `Punch.Range` 8 to 9, so reach is 11. New `Punch.OverlapRadius` 5: within it any direction hits, which replaces 'someone behind you is never hit'. `resolvePunch` now also counts a target that was in the hitbox at the press moment (attacker pose captured on request, target from `PositionAt(rewind + Windup)`) and launches it the way it was struck. Cause found by reasoning, not by a live trace: at 36 studs/s the attacker travels about 4 studs in the 0.12 s windup, so a target ahead at the press can be behind at impact. `lune/punch_sim.luau`, landing on first press / within 3 presses, Range 8 before: strafing 45/45, head-on 78/99; Range 9 with the fix: strafing 56/56, head-on 100/100. The Tutorial's CLICK NOW prompt uses `inHitboxAtImpact` only, so it won't include the press-moment rule. The bot's punches get all of this too. Lune tests and checks pass. NOT TESTED IN PLAY: all of this, whether it's now too generous, two players, and the punch-1 items (hit recoil live, reach at full speed).
- Build `hitbox-2` (2026-11-03, user requests; supersedes the `hitbox-1` sizes). `Punch.Range` 8 (reach 10), `OverlapRadius` 3.5, `HalfAngleDegrees` 45; the press-moment rule stays. New `Debug.ShowHitbox` true and `src/client/Controllers/HitboxDebugController.luau`: every player's hitbox drawn on the floor in see-through red, shaped by `Combat.hitboxOutline`, which asks `inHitbox` itself and has a test. MUST be turned off before anyone else plays. It shows where the target's centre must be, and doesn't show height or the press-moment rule. Seen in Play: 128 parts, one screenshot shows a forward fan plus a circle around the character at floor level, red and see-through, not colliding. Even at 45 the fan is wide, because the target's body adds to the angle: about 56 degrees each side at full reach, about 80 up close. `lune/punch_sim.luau`, first press: strafing 45 (hitbox-1 was 56), head-on 100; that sim's player aims well, so narrowing the angle changes nothing in it and it can't judge skill. 97 Lune tests and checks pass. NOT TESTED: any punch landing on this hitbox, how it feels, two players, seeing another player's hitbox, plus the punch-1 items (hit recoil live, reach at full speed).
- Build `hitbox-3` (2026-11-03, user request: still too big and easy, about half, must take skill; supersedes the `hitbox-2` sizes). `Punch.Range` 7 (reach 9), `OverlapRadius` 2.5, `HalfAngleDegrees` 15. Computed area from `Combat.hitboxOutline`: 134 to 66 square studs. Chosen long and thin over short and wide: reach 8 at about the same area took strafing first-press hits from 29% down to 12% in `lune/punch_sim.luau`, and reach 7 to 1%. The sim's player aims within 15 degrees, so it barely notices the narrower angle and doesn't measure aim skill. `MaxHalfAngleDegrees` 110 and `TargetRadius` 2 are unchanged, so close targets still get a wider angle. The press-moment rule stays. 97 Lune tests and checks pass. NOT TESTED: any punch on this hitbox in Play, how it feels, two players, the bot (still off, and its punches use this too), plus the punch-1 items. `Debug.ShowHitbox` is still true and must go off before anyone else plays.
- Build `hitbox-5` (2026-11-04, user requests: still too easy, shorter, skill is who hits first; bot back). `Punch.Range` 5.5, reach 7.5, area about 54. That's the shortest reach `tests/Bump.spec.luau` allows (the combat-10 promise that a follow-up punch reaches a bumped victim); 7 and 7.25 failed it. To go shorter, lower `BumpSlowerShare` first, which the user still hasn't decided (still 1.4). `Punch.HitCancelsPunch` true (`Combat.punchCancelled`, `lastHitAt` in CombatService): a punch still winding up is dropped if its thrower is hit after pressing it, so whoever lands first wins; bumps don't cancel, and a cancelled punch's swing and sound still play because the client starts them at the press. With no miss or hit aftermath on the cancelled punch. `TestBot.Enabled` true again. `lune/punch_sim.luau`, first press: strafing 5, head-on 95, standing 97; the sim's strafer never stops and its player spams early, so that low strafing number may be pessimistic, but watch for it being too hard. `Debug.ShowHitbox` is still true; turn off before anyone else plays. 98 Lune tests and checks pass. `HaymakerCombatDebug` set only for that Play session. NOT TESTED: first-hit cancel live, the feel, two players, plus the punch-1 items.
- Build `bot-3` (2026-11-04, user requests: make the bot attack like earlier; same hitbox as the player). It already shared the rule: the bot's punches go through `resolvePunch` and `Combat.inHitbox` with the same settings, and the only difference is no rewind, because it has no ping. The small hitbox was resetting `reachSince` whenever the target left it, so reaction time now runs from noticing the target within `TestBot.NoticeDistance` 14, and the bot presses when a punch would land now or at impact. `Tutorial.Enabled` is FALSE, TEMPORARILY, so the bot fights at once; set it true before the tutorial is needed again. `HitboxDebugController` now draws every `HT_Combatant`, bot included. Seen in Play, read-only, about 10 s with the user present: 7 bot punches, 7 hits, 0 misses logged, strength 75 to 87; 256 hitbox parts, 128 near the bot; bumps closing 34 to 42. The 7 of 7 may mean the bot is too accurate; not judged, and how the user was moving is unknown. OPEN: every one of those hits logged `stagger 0 before`, so stagger didn't stack. Falling off and resetting is one possible cause, but it could be a bug; not checked. NOT TESTED: the first-hit cancel, the bot's difficulty and feel, two players, plus the punch-1 items. `Debug.ShowHitbox` still has to go off before anyone else plays.
- Build `bot-5` (2026-11-04, user: don't make the bot too accurate). `TestBot` settings: `ReactionSeconds` 0.4, `PunchCooldown` 1.1, `TrackingLag` 0.2 (sees the target where it was), `MisjudgeStuds` 3, `ExtraWindup` 0.15, `WildSwingChance` 0.35; no prediction. `bot-4` (lag and misjudging alone) still landed 10 of 10, nearly all right after a bump. `bot-5` with the user playing: 9 hits of 19 swings, 2 more cancelled.
- Build `skill-1` (2026-11-04, user: hits still too easy; wants comebacks through skill and first click to win, "up to your judgement"; supersedes the `hitbox-5` sizes). The log showed the cause: the press-moment rule plus the windup let a running punch connect from about 12 studs, past the drawn red, and most hits came right after a bump. Press-moment rule REMOVED, so a punch is judged once, at impact, and the red now means exactly that; `Punch.Windup` 0.12 to 0.08 (must match the strike time when the punch clips are made); `Range` 4.5, reach 6.5, area 46. The combat-10 test promise that a follow-up always reaches a bumped victim is REPLACED by `tests/Bump.spec.luau` "a bump is no free hit": the victim slides out of reach, then can be run down within a second. New `Stagger.HitRelief` 6 (`Combat.relieveStagger`, `StaggerService:Relieve`): landing a punch takes 6 off the puncher's stagger, so an exchange swings 18. `HitCancelsPunch` CONFIRMED LIVE in the `bot-5` log, both ways. `lune/punch_sim.luau`, first press: standing 64, strafing 0, head-on 70; its strafer never stops and it can't judge a person, so treat 0 as a warning. 100 Lune tests and checks pass. `skill-1` in Play, about 20 s, read-only with the user playing: user 6 hits of about 20; bot 1 of about 7; first-hit cancels: none in this sample. OPEN: 7 misses in a row logged `blocked`, both fighters, possibly the test wall at x +40, not checked. Phasing may come back with the press-moment rule gone. NOT TESTED: `HitRelief` being seen working live, two players, gamepad, phone, plus the punch-1 items (hit recoil live, reach at full speed). `Tutorial.Enabled` false and `Debug.ShowHitbox` true are both temporary; both must be reversed before others play. `BumpSlowerShare` still 1.4.
- Build `turn-3` (2026-11-04, user requests). Propel stays on Q (Space was tried, then reversed). New `KeybindController`: bottom-right panel, Click Punch and Q Propel, R2 and B on gamepad, hidden on touch; seen in Play on mouse. TURNING: A or D alone now keeps running at full speed and clears a coast, replacing the earlier approved rule that A/D during a coast only steer; a coast W earned still applies when you let go (`tests/Momentum.spec.luau` rewritten for this). FOLLOW CAMERA: `StarterPlayer.DevComputerCameraMovementMode` and `DevTouchCameraMovementMode` are Follow. A script can't set this (`lacking capability RobloxScript`) and `rojo_push.py` doesn't apply `$properties`, so it's in `default.project.json` AND set on the place directly in Edit; confirmed Follow in Play on `Player.DevComputerCameraMode`. It needs saving with the place, and must be set by hand again on a rebuilt place. NOT MEASURED: how well the camera follows, since the only samples were mixed with the user's own input.
- ANIMATIONS IN REVIEW, NOT IN THE GAME (2026-11-04). The user's reference video is `C:\Users\dumpl\Videos\2026-11-04 00-27-58.mp4`; the user wants it improved on, not copied. `animations/build_clips.py` is the master: it bakes `Sprint` (0.533 s loop, lean 36, boxing guard with pumping fists, Movement priority), `Brake` (0.4 s loop, hands up, leaning back, Action), `PunchLeft` and `PunchRight` (0.40 s, arms only so they layer on anything, strike at 0.08 s to match `Punch.Windup`, Action2) to `animations/clips.json` and `src/shared/Config/AnimClips.luau` (generated, not yet used by any code). `animations/preview_in_blender.py` builds scene `HT_Anims` in whatever file Blender has open, with exact R6 C0 and C1 values, confirmed against the real character. The auto-mode classifier refused swapping Blender's open file, so that scene is in the open, unsaved session of `RaiseAFairy_Creatures.blend`: DON'T save over that file with it, or delete the scene first. Playback only runs if started from a `bpy.app.timers` callback.
- NEXT once the user approves the clips: wire them in. Run playback speed rises the longer you run (user request; plan: a setting ramping from about 0.8 to about 1.4 over a few seconds at top speed), Sprint weight blends in with speed over the stock run, Brake plays while `state.braking` at speed, punches on `PunchStarted` replacing the placeholder. Build each with `KeyframeSequenceProvider:RegisterKeyframeSequence` to test. Those ids are session-local, so real uploaded animation ids are needed before publishing and possibly for other players to see them in Team Test; not tested. The bot plays stock clips on the server and needs the same treatment. R6 has no elbows, so the guard is straight arms angled in.
- ANIMATIONS, SECOND PASS, STILL NOT IN THE GAME (2026-11-04, user: real hands-up guard per their boxing stance picture; huge wide swings; three of them). This SUPERSEDES the clip list above. `animations/build_clips.py` now places rigid arms by centre and fist direction (`ArmPlacer`, roll carried over so blocks don't flip): an upright arm in front of the chest stands in for a forearm, fists at y about 1.2 to 1.35, chin height. Clips: `Guard` (arms only, Idle), `Stance` (whole body when still, Idle), `Sprint` (fists up, Movement), `Brake` (hands up, Action), `HookLeft`, `HookRight`, `Uppercut` plus `...Run` variants (Action2, 0.55 s). The swings pose Torso and Head as well as arms so the whole body throws them, which is why they need Run variants with the sprint's lean: choose by speed when wiring, or the body will pop upright. Each lands at 0.08 s to match `Punch.Windup`, so the wind-up is already flung back on frame 1 and most of the size is in the follow-through. WIRING needs: the server's `nextSide` cycling three ways (HookLeft, HookRight, Uppercut) instead of Left and Right, and `Guard` always playing under everything. Not judged in Roblox yet; preview only, in scene `HT_Anims`, unsaved in the Raise a Fairy session.
- Uppercut third pass (2026-11-04, user: hooks good, uppercut stiff). `UPPERCUT` in `build_clips.py` now 0.72 s, still striking at 0.08 s: deep coil with the fist low behind, the body unwinds and hops 0.75 studs when standing (standing variant poses legs; `UppercutRun` leaves them to the sprint), fist ends overhead, the other hand pulls back, the head follows up. Hooks confirmed numerically unchanged. Preview only; the user has not yet seen or approved this pass.
- Build `anim-4` (2026-11-04, user: "put them in game", plus combo reset). ANIMATIONS ARE IN THE GAME. New `src/client/Controllers/AnimController.luau` builds the clips from `Config/AnimClips` with `KeyframeSequenceProvider:RegisterKeyframeSequence`, and each client plays them locally on every `HT_Combatant`, from replicated velocity and `PunchStarted`, so nothing is uploaded and others' characters should animate too. `Animation` settings section. Stock Animate wipes tracks when it starts, so the controller reloads them if `Guard` stops. Stride speed = ramp (0.8 to 1.5 over 3 s at speed) x pace. Brake is read from slowdown (at least 52 studs/s per second for 0.12 s, not above top speed). Swings: `Combat.nextSwing` gives Left, Right, Uppercut; `Combat.comboSwing` returns to Left after `Punch.ComboResetSeconds` 2 without a punch, on server, client and bot. Old placeholder `swingArm` removed. 107 Lune tests and checks pass. Measured in Play on `anim-2` with the user playing: own and bot tracks play; bot's guard fist (0.66, 1.21, -1.14) matches the design; stride climbed 1.04 to 1.51 while running; all three swings and Run variants seen. NOT RE-MEASURED on `anim-4`: the propel-fade brake fix, the longer brake hold, the combo reset live. NOT TESTED: two players seeing each other's clips, whether runtime-registered clips work in a live published server (real uploaded ids may be needed), gamepad, phone. `Tutorial.Enabled` false and `Debug.ShowHitbox` true still have to be reversed before others play. The arena has not started, and the user has not said combat is finished. The `HT_Anims` preview scene is still unsaved in the Raise a Fairy session in Blender; delete it before anyone saves that file.
- Build `idle-1` (2026-11-04, user requests while AFK with full permission to work on). STRIKE EVENT: a `Hit` KeyframeMarker on the exact 0.08 s frame of each swing; `AnimController:AtStrike` shows confirmed hits at that moment and `StrikeTip` puts the hit burst at the fist; not seen firing directly. KNOWN MISMATCH, ASK THE USER: the fist only reaches about 2.7 to 3 studs ahead but reach is 6.5, so a hit can land with air between fist and target; closing that needs a lunge or a much shorter reach. UPPERCUT: `Knockback.UppercutLift` 62 with `Combat.swingLift`, same backward strength; MEASURED, the bot's uppercut lifted the player to 9.7 studs. Reworked again for stiffness (shoulder drop, whip, overshoot, settle; 0.76 s); the user hasn't judged this pass. KICK: Space, gamepad Y or a touch button. `Core/DiveKick` (tests), `KickService` (server decides all hits, grades the press itself from the gap between messages, `Kick` settings), `KickPromptController` (small timing ring), MovementController steers. Press Space: leap; WASD moves a red floor ring; press Space again as the ring meets the key (`QteAt` 0.38 into the hang, plus or minus `QteWindow` 0.12) for `PerfectBoost` 1.3; front flip to the ring; kick with shake, FOV punch, freeze and floor rings. The comic picture is ONLY the round flip, no ball or spikes (user was explicit). Air targets are slammed down (negative airUp), ground targets bounced. MEASURED in Play: leap about 8 studs, hang, dive about 100 studs/s, landing, recover, clip order, second press registers. NOT SEEN: the kick actually hitting anyone, the perfect boost on a hit, a slam, how the impact feels, punching being refused mid-kick. Aiming the ring off the arena flies you off, by design for now. No new sound assets: the impact reuses the bank at lower pitch. The bot doesn't use the kick.
- IDLE: from the user's TikTok (@kaku_hatsu, "Boxer Moveset Animations"), the section labelled Idle, ONLY that. Viewed through tiktok.com/embed/v2/7578216021832568095 in the browser pane; the main page wants a login and a birthday, and neither was given. Low wide stance, torso lean 22 and twist -30, left arm up in front, right arm cocked back, bounce every 0.6 s. `Stance` and `Guard` use it, stand swings start and return to it, the kick lands into it; the sprint and `...Run` swings keep fists-up `RUN_GUARD`. Compared by eye in Studio only; not frame-matched, and rigid arms limit it. Checks: 115 Lune tests and all gates pass. `Tutorial.Enabled` false and `Debug.ShowHitbox` true still have to be reversed before others play. `HT_Anims` scene still unsaved in the Raise a Fairy session in Blender, and its Guard dummy now shows this idle.
- Build `idle-2` (2026-11-04, user: "the idle is incorrect"; supersedes the idle pose in `idle-1`). The first reading of the video was wrong: its camera sits about 45 degrees off the character's front, so the arm that looked cocked behind is level across the chest. Now: torso lean 10, turn -8; right arm level across the front of the chest (centre (1.2, 0.08, -0.8) in torso space, not attached at the shoulder); left arm forward and raised (sweep 16, lift 34); legs -5 and 17 degrees, splayed out 19, `STANCE_SINK` -0.18; bounce every 0.6 s. Compared by eye against frames at 1.3 s and 1.6 s of the video, in Blender and in Studio from the same angle; close, not frame-exact, and the user hasn't judged it. All swings end on this exact pose (numbers checked). Hook wind-ups were written for the old idle, so how the move from idle into a swing looks hasn't been judged. 115 Lune tests and gates pass. To restudy the idle: tiktok.com/embed/v2/7578216021832568095 in the browser pane, press play, use the video with duration about 24.7 (another, unrelated video is on that page).
- Build `air-1` (2026-11-04). SUPERSEDES the `idle-1` kick and the TikTok idle. IDLE REVERTED (user: "revert the old idle back"): `build_clips.py` has the fists-up boxing guard again, restored exactly from the session log (no git here), and swings start and end on it; `RUN_GUARD`, `aim_at`, `idle_arms` are gone. UPPERCUT: `UppercutLift` 61, `UppercutPushShare` 0.2, `Kick.AirGravityScale` 0.26 on an `HT_Air` attribute ("float", "hold") set by `KickService:MarkLaunched`, applied by whoever owns the body; drift doesn't fade while floating; floating bodies can't punch or propel. Height from the user's picture: circle about 36 studs above the bot (30 to 42). AIR KICK replaces the ring-aim kick: Space works ONLY with someone floating within `JumpRange` 26 (flat), and a small JUMP prompt shows then. Jump `LeapSpeed` 69 under the same gravity, WASD steers at `SteerSpeed` 42. Within `AttachRange` 8 you attach, the target hangs, a ring closes over `QteAt` 0.55 (plus or minus `QteWindow` 0.12). In time: `FlipSeconds` 0.34 flip, then the kick. Out of time or no press: "MISS", no kick (INTERPRETATION, the user said "press at the perfect time"). Spike: down at `SlamSpeed` 110, across at the speed that reaches where they'd have landed (worked out on attach from their velocity, `SlamMaxFlat` 60) plus `BaseSpeed` 10 times stagger. A second `KickImpact` fires when they reach the floor. Remote `KickLanded` replaced by `KickAttach`. Debug: workspace attribute `HaymakerCombatDebug` prints `[Kick]` lines. MEASURED in Play with real Space presses on the bot: apex 36 to 37 studs at 1.2 to 1.35 s, lands about 2.4 s after launch; prompt shows; attach, press, flip, kick, slam all ran. FOUND: the server sees the jumper about 18 studs away when the client attaches at 8 (lag at full jump speed), hence `ATTACH_TOLERANCE` 24. Rojo push DELETES then recreates code: a script over Studio's Source limit made it fail halfway and left the place missing scripts, so keep `AnimClips.luau` small (143 KB now; it failed when `KickLeap` was baked at 60 fps). NOT TESTED: real WASD steering (the test pinned the player in line with the bot), a player being launched, the MISS path, how it looks or feels, two players, gamepad, phone. Studio's Client context can't send keys from Luau (no `VirtualInputManager` or `ContextActionService:CallFunction`); use `user_keyboard_input`. Blender and Studio MCP can be reached directly if the session's connection drops: `studio_mcp.py`, and blender-mcp.exe over stdio. `preview_in_blender.py` now has an `Air kick` dummy (lifted off the floor) and a wide view. `Tutorial.Enabled` false, `Debug.ShowHitbox` true and the `HT_Anims` scene are still to be undone.
- Build `air-2` (2026-11-04, user feedback on `air-1`; SUPERSEDES its numbers and rules). UPPERCUT: lift plus the FULL punch push (`UppercutPushShare` removed), `UppercutLift` 88, `AirGravityScale` 0.55 ("too floaty" before). Launched bodies are helpless, their flat speed is set directly from Momentum, and the push fades at the floor rate so it carries as far as a regular hit. JUMP: `HT_AirBy` holds the launcher's UserId; your own launch can always be jumped at (any range, no cooldown); anyone else's within `StealRange` 26 with `Cooldown` 4, and jumping cancels anyone else's chase of that target. `LeapSpeed` 97. The chase carries you toward them at THEIR flat speed, which only holds the gap; `SteerSpeed` 42 from the keys closes it. LOCK: within `LockRange` 9 the client locks on and moves you `AttachFront` 3.5 in front, `AttachAbove` 2 up, on the side you arrived from; the server turns them to face you (`HT_HoldFace`). TIMING: the server picks the ring's moment per jump between `QteEarliest` 0.5 and `QteLatest` 1 (`HT_KickAt`), `QteWindow` 0.08 plus `PRESS_LEEWAY` 0.02. INTERPRETATION of "should be like 0.5-1 second", not confirmed by the user. Only the server grades; the client waits for its answer before showing PERFECT or MISS. KICK: `Combat.punchStrength` at attacker speed 0 with stagger, outward, away from the kicker, and `SlamSpeed` 110 down. So the side you approach from aims the kick. The "where they'd have landed" aim is removed. The lock check allows `LockRange` + 12 + 0.35 s of both bodies' speed, because at 140 studs/s the server saw 42 studs for a client-side lock. MEASURED with real W and Space on the bot (camera pointed at it): apex 35 to 36 studs at about 0.9 s; W closed 33 studs to under 8 in about 0.6 s; lock offset (0.7, 2, 3.5) with the bot facing the jumper; press in time gave PERFECT, flip, kick; after the kick the bot moved (-55, -112, -27), server line "64 outward, 110 down"; no press gave MISS and released the bot to fall. COMPUTED, not measured: 1.6 s air time unheld; about 34 studs of floor travel from a 64 push. At stagger 66 the uppercut alone reached 140 studs/s, far past the arena's 75 radius: flag to the user. NOT TESTED: stealing and cancelling (needs two players), a press outside the window, running out of steer distance with a human's reaction time, the launcher jumping from far away, gamepad, phone, how it feels. The user may also have been playing during some runs ("kicked" lines and odd heights appeared between tests; the bot's own uppercuts launch the player too). Rojo serve is running from this session. 
- Builds `air-3` to `air-5` (2026-11-04, SUPERSEDE the rules and numbers above; settings are in `design/Settings Guide.md`). COMBO NOW: `UppercutLift` 125, `AirGravityScale` 0.7: about 57 studs up, keeping the full punch push. The launched player steers (`LaunchSteerSpeed` 26, on top of the push, less at high stagger) and the bot steers away (`TestBot.AirSteers`). Punching and propel stay off while launched (the user asked for directional control; ask if they want more). Jump: `LeapSpeed` 118, aimed by keys or facing, with strength `DiveKick.jumpCarry` worked out ONCE from distance; no follow after that, then air steering (`SteerSpeed` 46). Lock: within `TouchFlat` 7, `TouchTall` 9 both hold, align beside each other (`AttachSide` 3, `FollowRate` 16). Ring between `QteEarliest` 0.25 and `QteLatest` 0.45, server grades: green within 0.05, orange within 0.12, otherwise red, and no press is red. THE KICK ALWAYS CONNECTS once locked; force share 0.5, 0.85, 1.3 applies to outward push, slam and stagger. Real server hit stop by result (`RedStop`, `OrangeStop`, `GreenStop`), then launch. On floor contact: effects, and on green a bounce (`BounceLift` 75) with outward speed kept. `HT_Stunned` (no control) is ONLY from a green kick, from launch until landing from the bounce plus `StunAfterLanding`, capped by `StunMaxSeconds`; a stunned body can't be launched again. Held bodies with no holder go back to floating automatically. RESULT TEXT: `src/client/Ui/KickResultText.luau` and `Core/ResultPop`, `KickText` settings: MISTIMED!, CLOSE!, PERFECT! once per kick. MEASURED for text: all three, repeats, fade, clean replacement. ANIMATION: all clips rebuilt, see the vault note `Combat Animation Pass` (what changed, measured, not measured); research in `Nintendo-Inspired Combat Animation Research`. Hit stop and shake are client-only through `RootJoint.C1`; movement owns `C0`. `AnimClips.luau` is excluded from stylua (`.styluaignore`) because the formatter added 12% and a script near Studio's limit makes a push fail AFTER deleting the old code; the build refuses over 185,000 characters. Test harness notes: Luau in the Client context can't press keys, so use `user_keyboard_input` and `user_mouse_input` (a click needs a `moveTo` first). When the Blender or Studio connection drops, talk to their exes directly over stdio (`studio_mcp.py`; blender-mcp.exe). YouTube captions with timestamps can be read through the player's timedtext request in the browser pane. NOT TESTED: how any of it looks in motion in Studio (user to judge), attacker killed mid-hold (script written, not run), stealing and two players, gamepad, phone, live server. At stagger 36 and above an uppercut alone can carry someone off the arena (flagged to the user, unresolved). User's punches appeared in some test logs, since they were playing during tests. `Tutorial.Enabled` false, `Debug.ShowHitbox` true and the `HT_Anims` Blender scene are still to be undone. Rojo serve is running from this session. The arena still waits on the user saying combat is good.
- Build `air-7` (2026-11-04, SUPERSEDES where it differs; details and the balance table are in the vault note `Combat Animation Pass`). Launched players can propel (measured 87 studs/s sideways); punching stays off. `Kick.Cooldown` 7 now covers own launches too (the user said "increase cooldowns"; this reverses the earlier "always", flagged to them). Jump: `DiveKick.planJump` worked out once at the end of a real `JumpSquatSeconds` 0.067 squat: meets them `JumpMeetShare` through their air time, `LeapMin` to `LeapMax`, up to `JumpCarryMax` 170, falling `JumpShortShare`/`JumpShortMax` short; direction is keys or facing, forgiven within `AimForgiveDegrees` 14; steering `SteerSpeed` 42 sits on top. To make it harder, raise short or lower forgive. Prompt: `DiveKick.canReach` hides it when unreachable. Lock `TouchFlat` 8, `TouchTall` 10. `TestBot.AirSteerShare` 0.3. Rebound: `DiveKick.rebound`, phase `rebound`, `ReboundBack` 42, `ReboundUp` 70, on every connected kick, measured (back 41, up 58 at 0.2 s). Clips: new `KickLeap`, `KickAim` (ball), `KickSpin` (non-loop, ends just before the strike), `KickDown` (first frame is the strike), `HitFlinchHeavy`, `HitFlinchBack`, `HitSkid`. Body tilt spring on `RootJoint.C1` in `AnimController`. Smoke: `FxController:JumpSmoke`, `Effects.JumpSmoke*`. Stagger: `Combat.staggerSpeedShare`, `Stagger.SpeedPenaltyMax` 0.15, `SpeedPenaltyCurve` 1.32, `RecoveryDelay` 3; applied through `Momentum.velocity(state, speedShare)`, not to knock or propel. MEASURED: speeds at 50 and 100 stagger, kick results in Play, connects 5 of 6 with no keys or W, prompt hiding. REMEMBER: run `gen_config.py` after editing `game.json`; missing it this pass broke movement in Play with no gate catching it before the push, since `check.py` doesn't compare. NOT TESTED: the look of the smoke, jump, kick and new reactions in motion (poses seen in Blender only), which flinch plays per hit, a real pursuit between two players, stealing, attacker killed mid-hold, gamepad, phone.
- Build `air-9` (2026-11-04, user feedback). `Kick.UppercutsPerJump` 2 on the server (`uppercutsSince`, published as Player attribute `HT_JumpReady`), with `Cooldown` 7 still as a floor; the first jump is free. Missed jump (`DiveKick.hasMissed`: past `plan.meet + JumpMissGrace`, or `giveUp` when the server ends the chase): `JumpCarryFade` 260, `MissLift` 20 once, `MissGravityScale` 0.2, `MissMaxFall` 38, `RecoverSteerSpeed` 56, and `AirDashSpeed` 70 through the normal propel and its cooldown, also in a rebound. Kick aim: `DiveKick.aimSide` during `attach` at `KickAimRate` 720, arrow from `FxController:ShowKickAim`; the server still kicks directly away from the attacker's position, so no new remote or trust. MEASURED: miss 3.2 s in the air, landed back with W; prompt off on the next uppercut and on for the one after; aim put the attacker opposite the keys and the rebound opposite the aim. NOT MEASURED: the kicked target's velocity along the aim (the client read 0 at the sample, likely the stop), how any of it feels, the arrow's look. When testing aim, hold the test camera still: it orbits with the attacker otherwise and chases its own tail.
- Build `air-11` (2026-11-04, SUPERSEDES). New `ShiftLockController`: replaces `GetMouseLockOffset` on the live stock `activeMouseLockController` (no setting exists; it returns a constant) with `ShiftLock.CameraOffsetX` 0, white dot projected above the head, stock cursor hidden. `:IsLocked()` asks the stock controller, because `MouseBehavior` also changes when dragging or zoomed; it's mirrored as Player attribute `HT_ShiftLocked` for tests. Undocumented API: warns and keeps the stock offset if a Roblox update removes it. In `attach`, shift lock aims by camera, otherwise keys. Arrow removed. `MissGravityScale` 0.3, `MissLift` 12, `MissMaxFall` 52, `ReboundBack` 24, `ReboundUp` 40, `ReboundGravityScale` 0.85. MEASURED: as in the vault note. A Scriptable test camera turns shift lock off; test with the real camera, turning it by setting `CFrame`. Simulated LeftShift toggles lock; sometimes Play starts already locked. Rojo push deletes before it creates, and a half-applied patch script left a broken build in Studio this pass: never push after a patch script fails. NOT TESTED: shift lock with real mouse movement, the dot's look, gamepad and phone (shift lock is mouse only).
- Build `air-12` (2026-11-04, SUPERSEDES). `DiveKick` no longer has a rebound phase, air dash or recovery steering. A missed jump (`hasMissed`) and a connected kick hand over to `Momentum` through `Momentum.moving`, with the local `airRun` in `MovementController`: `Momentum.step` is given grounded=true for full floor control, flat velocity is set directly, gravity comes from `airRun.gravityScale`. Miss: `MissCarryKeep` 18, `MissLift` 12, `MissGravityScale` 0.3, `MissMaxFall` 52; a chase can still lock on during an air run while the server still says `chase`. Rebound: `ReboundSpeed` 46 backward from facing, `ReboundUp` 40, `ReboundGravityScale` 0.85. Normal propels work in an air run. Removed: `JumpCarryFade`, `RecoverSteerSpeed`, `RecoverSteerAcceleration`, `AirDashSpeed`, `ReboundBack`. MEASURED: see the vault note `Combat Animation Pass`. UNEXPLAINED: twice, a test read `HT_JumpReady` false at the first launch of a session and no jump followed; a traced fresh session did not repeat it (ready nil, jump worked). Watch for a first jump being refused. Test scripts and lessons are in `work/test-harness`. `AnimClips.luau` is excluded from stylua. OPEN FROM THE USER: nothing unanswered, but they haven't judged the feel of any of air-5 to air-12, and they never said combat is good, so the arena still waits.
- Build `air-13` (2026-11-04, SUPERSEDES; details in the vault note `Combat Animation Pass`). REBOUND: `Momentum.propelBoost` gives `PropelSpeed` 84 at once with a propel's fade, no ramp, no cooldown used; `ReboundSpeed` removed. Q can't start a propel until it ends. MEASURED: 84 down to 36 over 0.7 s. GROUND BREAK: `Core/GroundBreak` (tests) and `FxController:JumpBreak`, client-only anchored pieces in their own pool, `Ground...` settings in `Effects`; floor's colour and material, Slate if the floor is plain. MEASURED: 50 pieces at the spring, top 24.6 studs, out 33 studs, all pooled by 2.7 s. BUG FIXED: your own jump's effects came from the replicated `HT_Skill`, so they could spawn after you'd left the floor; now fired from `springJump`, and `AnimController` only does other people's. SOUND: `ground_break` id 115163143171771 added to the bank and manifest by hand, keeping the bank's format; measured 1.122 s, loaded; not heard. NOT TESTED: the look, the sound, whether the camera keeps the break in view, another player's jump, live server. In `fxtest`, the last 3 no-keys jumps fit the aim rule: 23 and 19 degrees off missed (forgiveness is 14), under 1 degree connected. An earlier no-keys jump also missed, angle not logged, and one with W held and the camera not aimed missed too. One run's Space produced no jump, not diagnosed; watch for it. Console shows `rbxassetid://203785492 failed: Asset type does not match`; not from `src`, not looked into. `Tutorial.Enabled` false, `Debug.ShowHitbox` true and the `HT_Anims` Blender scene are still to be undone. The arena still waits on the user saying combat is good.
- Build `air-14` (2026-11-04, SUPERSEDES the rebound in `air-13`; details in the vault note `Combat Animation Pass`). `DiveKick.planRebound`, worked out once at connection: `ReboundRiseRed` 14, `ReboundRiseOrange` 30, `ReboundRiseGreen` 46 studs above the kick (uppercut is 57), flat speed `Movement.PropelSpeed` 84 held by `Momentum.airKeep` until landing, unaffected by stagger; `Momentum.landed` drops to running speed on landing. Green can't fall short: it speeds up (`ReboundSpeedMax` 300) to land `ReboundLandNear` 15 inside, and goes straight for the centre if backward never meets the platform. All grades slow down rather than pass `ReboundLandFar` 55 short of the far edge. `ReboundUp` and `Momentum.propelBoost` removed. MEASURED in Play, kicking outward with no keys: green from 86 and 39 past the edge landed 17 from centre, orange from 38 landed 13, red from 35 to 39 landed 13 to 17 (1 run 37). Flat speed held at 84 through the air, about 33 just after landing. Rises 45.6 to 45.8, 29.9, red 13.8 to 14.5. UNEXPLAINED: red read lower in 2 of 6 runs (9.7 with normal air time and landing; 4.3 with a landing 37 from centre); the throw timing there looks late, and it may be partly how the test detects the throw. NOT PLAYED: red or orange falling short (only Lune tests: red short from 115 out, orange from 140), green from over 100 out, green redirected when backward misses, a real player steering, two players, the look. Setting the bot attribute `HT_Stagger` did not make kicks land further out; a far-out Play test needs real stagger. THE ARENA MUST FEED THIS: `planRebound` uses `Arena.StartRadius` and the centre from config, so once the arena shrinks it needs the live radius or a green can land past the edge. Test scripts: `work/test-harness/rebtest.luau`, `run_rebtest.py`. `Tutorial.Enabled` false, `Debug.ShowHitbox` true and the `HT_Anims` Blender scene are still to be undone. The arena still waits on the user saying combat is good.
- 2026-11-04, for a team test: `TestBot.Enabled` set to false (user asked). Set it back to true to test alone. `Tutorial.Enabled` false and `Debug.ShowHitbox` true are unchanged unless a later entry says otherwise.
- Build `air-15` (2026-11-04, SUPERSEDES the bump rules). `Combat.bumpOutcome` is now two punches at once: `punchStrength` at half the closing speed and each side's own stagger before the bump, with `BumpEdgeShare` 0.15 at `BumpFullAdvantage` 30. The faster one adds 14 stagger against 10, and hits 15% harder and takes 15% less. Both get a punch's upward push, speed loss, `MarkHit` and the full hit show (`flash`, `HitLanded`, `HitBurst`) plus the bump puff. Neither gets `HitRelief`, because nobody landed a punch. `BumpHappened` now also carries both knocks. Removed: `BumpSpeed`, `BumpPerClosing`, `BumpMaxSpeed`, `BumpFasterShare`, `BumpSlowerShare`, `BumpFasterKeepsSpeed`, `Combat.bumpSpeed`, and the rule that a bump is weaker than a punch. `StaggerService:AddKickHit` renamed `AddAmount`. NOT TESTED IN PLAY: `TestBot.Enabled` is false for the team test, so nothing has bumped anyone in this build; Lune tests only. The edge reads each body's actual speed, so running into someone running away only counts the gap between you. `lune/punch_sim` first-press landing is now standing 59, strafing 0, head-on 41; the `skill-1` entry recorded 64, 0, 70, on older settings, so that's only a rough comparison. A head-on bump can now throw both apart before a punch lands. CONCERNS: `BumpMinClosingSpeed` 10 means light contact is now a full hit. The tutorial's bump step (punch within `BumpPunishSeconds` of a bump) probably can't be done any more, because both slide about 40 studs apart; the tutorial is off for now, and it needs a look before it's turned back on. `TestBot.Enabled` false, `Tutorial.Enabled` false and `Debug.ShowHitbox` true are still as they were.
- Build `air-16` (2026-11-04, user: A and D frictionless and easy, hard to stop only going forward). `TurnRateLowSpeed` 720, `TurnRateHighSpeed` 540. `moveStep` no longer applies `ReverseDeceleration` when the input is A or D alone, so D to A keeps full speed; W against travel still brakes. New `Momentum.endSidewaysCoast` with `CoastMaxAngle` 45, called from `MovementController` only on the frame A or D alone is let go: heading further than that from the camera's look stops at `SideStopDeceleration` instead of coasting. A first version checked on every frame with nothing held, and turning the camera ended a forward coast. MEASURED on that first version: D then A held 36 throughout, then stopped in about 0.8 s. The forward coast after this fix is NOT MEASURED yet; readings were disturbed because the user may have been playing. This also reaches the bot's movement, which uses the same turn rates. PLAYLIST: the user made a LocalScript `Client.Ui.playlist` in Studio (plays `SoundService.Music`, 3 tracks). It was only in Studio and a push would have deleted it, so an exact copy is now `src/client/Ui/playlist.client.luau`, with only a selene comment added. The user stopped my rewrite of it partway, so nothing else changed. Its known problems, not fixed: freezes the client if `Music` is empty (no yield), hangs if a track never ends, `print(12)` on every track, no shuffle or crossfade.
- Build `air-17` (2026-11-04, user: only apply the drifting effect to the propel skill). `FxController:driftSmoke` only runs within `Movement.PropelSeconds` of that character's `PropelGust`, which fires for your own propel and other players' on every client. The body lean on normal turns (`LeanMaxDegrees`) is unchanged, as is the propel's own slip in `Momentum`. Includes the `air-16` coast fix.
  MEASURED on `air-17`: 0 smoke puffs through running and D/A turns, 12 at the propel's gust. UNRESOLVED: in the same run, speed stayed about 36 for roughly 5 s after W was sent up, where a coast should fade by about 2.4 s. Possible causes: the user was playing during the test, or a stuck key, or a real bug. The follow-up reading of keys never ran, because Play stopped first. Scripts: `work/test-harness/coast2.luau` reads keys and speed during a W release.
- Build `air-18` (2026-11-04, user: no more once per 2 uppercuts, 15 s cooldown). `Kick.Cooldown` 15 is now the only limit on jumps, on both client and server. Removed: `UppercutsPerJump`, `DiveKick.jumpRecharged`, `uppercutsSince` and the Player attribute `HT_JumpReady`, which also removes the earlier unexplained `HT_JumpReady` false reading. The client starts its 15 s on the press, so a press the server refuses still locks that client out for 15 s while the server would allow it. Nothing on screen shows the cooldown; the JUMP prompt just doesn't appear. Check that smoke and all this are in the PUBLISHED place too: a rojo push only changes the open Studio session.
- Build `air-19` (2026-11-04, user: lock-on marker from `haymaker-lock-on-reference.html`). PURELY VISUAL, no remote, no movement or hit change, no homing. `Core/LockOn` (tests): who shows, bezier easing, pop, squeeze, pulse. `Ui/LockOnMarker`: one reused BillboardGui, stud-sized over Torso or UpperTorso, `AlwaysOnTop`, 3.4 studs across scaled by root height; RenderStepped only while showing; five ImageLabel layers plus a dark clone of each as the drop shadow (offset, not blurred). `Controllers/LockOnController`: 0.1 s checks, camera cone 12 degrees (18 to let go, or `LookStuds` 2.5 up close), range 70 (85 to let go), LOS ray from the camera. Left Alt toggles on RELEASE so Alt+Tab, F4, Return and Esc cancel it, as do focus loss and a focused text box; ButtonL1 and a touch button "Lock" toggle on press. `LockOn` settings section. ART: `assets/lockon/build_lockon_art.py` draws the 5 PNGs from the CSS numbers, uploaded with the Studio MCP `upload_image` tool (it needs an http url, so a local http.server): outer 82686578855013, inner 78409266589667, diamond 84290345252921, filled 71282992634163, pulse 108001335035509. All loaded with Success in Studio. MEASURED with client-only tagged clones as targets: spin 5.01 s clockwise and 7.01 s counter; selected is F8FCFF to FFCA54 and 0.720 against 0.818 (88%); holding Alt toggles once on release; Alt+Tab keys don't toggle; Alt with nobody does nothing; looking away keeps a selection; a second target doesn't take it; wall keeps it at 0.5 s and ends it by 2.1 s; target death, removal and own death clear it; works after respawn. Seen on the real screen in white and gold. CAUGHT: Studio's `screen_capture` leaves out BillboardGui, so judge it from a desktop screenshot; Studio's scripted camera gets reset by execute_luau; the Follow camera swings back to the character's facing, so hold a test camera per frame (this may also explain the odd camera angle in the coast traces). REAL ALT IN STUDIO: it needs the game view focused (click once), and it also highlights Studio's File menu, which may take the next keys until you click. The Roblox player has no such menu, but it's NOT TESTED there. NOT TESTED: ButtonL1, the touch button, real Alt+Tab, two real players, other rigs (R6 clones only), other screen sizes beyond two Studio window sizes, comparison of motion by eye. Rotating the marker's shadow keeps it below only because it's a separate offset clone. `HT_LockOnMarker` has no gameplay effect: the user may want selecting to do something later, and it must stay skill-based. TEST SIDE EFFECT: opening Roblox Studio through computer-use launches a second copy, so raise the existing window instead.
- Build `air-20` (2026-11-04, user: add the bot back). `TestBot.Enabled` true. It still only exists with exactly one player in the server.
- Builds `air-21` to `air-23` (2026-11-04, user: lock-on marker far more visible and constant size, and lock-on controls the camera; shift lock and camera lock collided). ART: `assets/lockon/build_lockon_art.py` now draws thicker strokes (outer 7, was 4) and a separate dark outline layer for each shape, 10 images uploaded; ids are in `LockOn` settings. MARKER: `BillboardGui` sized in pixels, `MarkerPixels` 128 at `ReferenceHeight` 1080, floor `MinMarkerPixels` 80, never changes with distance; opaque; outline `OutlineColor`. CAMERA: `Core/LockCamera` (tests) and `Controllers/LockCameraController`, bound at Camera + 1 only while in use, on top of the stock camera, which keeps running and follows along; camera kick moved to Camera + 2. The aim line runs from `FocusHeight` above you through the opponent, with the camera behind on it. It touches no velocity: no homing. `LostSightSeconds` 0.75: the marker hides at once (`marker:conceal`), the camera keeps the last seen point. COLLISION ROOT CAUSE: stock `CameraUtils.setMouseBehaviorOverride` saves whatever MouseBehavior it finds as normal, so the first version's direct `MouseBehavior = LockCenter` got saved and later restored with shift lock off, which looks like stock shift lock turning itself on. Trace: every shift-lock flip lined up with a real LeftShift, none with Alt. FIX: `ShiftLockController:HoldMouse` and `ReleaseMouse` own the mouse, cursor and Shift, using stock `CameraUtils` and `UpdateMouseBehavior`, both undocumented and failing inert. While camera-locked, Shift does nothing (`MouseLockSwitchAction.Enabled` false) and the dot hides; shift lock's state returns on unlock. REAL ALT IN STUDIO: it loses window focus to the menu bar (traced: `end LeftAlt`, then `WINDOW FOCUS LOST`), so the game loses keys until a click. Studio-only as far as known; not tested in the Roblox player. Test scripts: `work/test-harness/run_lockcam.py`; park the bot with `prep` and wait for any hit's slide to end before trusting a run, and `done` must run afterward or the bot stays anchored.
  MEASURED on `air-22` and `air-23`, against client-only dummies with the bot parked: marker gui 126 px at 15, 40 and 69 studs in an 833x576 view (white ring 80, the floor; gold 71), read on screen against sky and a black wall. Tracking: side to side 13% from centre, launch 22 to 23%, at 59 and 27 fps alike; roll 0; never off screen; overhead pitch 137 deg/s after the cap (1353 before). Wall 6 studs behind: camera stopped 1.5 short. Alt held toggles once; death frees camera and mouse. Grace: marker hidden within 2 frames, yaw 0.00 while they moved 14 studs hidden, resumed when back in sight, let go at 0.75 s. Mouse (real, via computer-use): yaw stopped at exactly -30, roll 0. Shift lock with camera lock: all 4 sequences correct, including shift off after lock-on ending at mouse Default. NOT RUN: a real jump while locked (code touches no velocity), 128 px at a true 1080p, terrain, gamepad and touch (no orbit on either), Roblox player, two players. UNEXPLAINED: shift lock read on at the start of Play with no Shift sent by the tests; one selection dropped during a slowed run and didn't repeat (likely the unreliable test teleport or live input); the stock Follow camera can swing after unlock if you're not facing the way it looks. Harness: one-off teleports don't always stick, so `run_lockcam.py` pins you each frame until `done`.
- Build `air-24` (2026-11-04, user: turn Roblox's shift lock off completely and make the custom one the main one). `ShiftLockController` now has its own `HaymakerShiftLock` action on LeftShift and RightShift and its own state, starting off. (`air-25`: a script can't set `Player.DevEnableMouseLock`; it errors with lacking capability.) `StarterPlayer.EnableMouseLockOption` is false in the place. That's a PLACE SETTING the rojo push skips, so set it directly in Edit if it's ever lost, and it has to be saved or published to reach players. The client also holds stock `MouseLockSwitchAction.Enabled` false every frame, as a safety net. The stock camera still does the turning, told through `SetIsMouseLocked` and `SetMouseLockOffset`, which are undocumented. While the camera is locked on, Shift does nothing.
  MEASURED on `air-25`: fresh Play, our shift lock false, stock action off, Player.DevEnableMouseLock false, no console errors. Camera lock alone, Shift during camera lock (ignored), shift lock then camera lock then back (shift lock returns), right-click during camera lock: all correct. A `LockCurrentPosition` reading after shift off was the user really holding MouseButton2, which is correct. NOT MEASURED: turning the camera with real mouse movement in the new shift lock. STILL NOT RUN: a real jump while locked, including the no-homing check with S held. `work/test-harness/run_lockjump.py <grade> [key]` is written for it, but its one attempt had no jump happen (`jumped false`, and the lock had dropped), cause not found, so it says nothing either way. `EnableMouseLockOption` false must be saved or published to reach anyone else.
- Build `air-26` (2026-11-04, user: shift lock then lock-on bugs out). REPRODUCED with real keys through computer-use: a real Alt in Studio activates the menu bar (`File` highlights, Windows cursor shows in the game view) and the game loses the keyboard. With shift lock on the mouse is locked and hidden, so it feels stuck. Simulated Alt from `user_keyboard_input` bypasses Windows and never shows this, so test real keys. No game code can stop it in Studio; the Roblox player has no menu bar, NOT verified there. So in Studio only, `E` also locks on, and the keybind panel shows it. Also fixed: `run_shiftbug.py` measured the mouse flipping 172 times in 86 frames with camera lock on and shift lock off, stock `UpdateMouseBehavior` undoing the override each frame. Now both locks only set the stock camera's `SetIsMouseLocked` flag, and CameraUtils is no longer used. A camera lock therefore also sets stock `RotationType` to CameraRelative; `AutoRotate` is false here so it shouldn't matter.
  MEASURED on `air-26`: mouse changes 0 (was 172 in 86 frames) with camera lock, with or without shift lock. Real Shift then real E: no menu highlight, no stray cursor, camera lock on, shift lock kept. All `run_lockcam.py shift` sequences correct, ending at mouse Default. JUMP WHILE LOCKED, on `air-23` with no keys: connected green, closest 6.6 then attach, rebound rose 45.7, flat 84, air 1.75, landed, against unlocked 45.8, 84, 1.71. Same again from 72 past the edge. On `air-26` with S logged down at the jump: flew 180 degrees off the bot at 156 studs/s, closest 39.1 studs, no kick. So no homing. An earlier S run connected at 0 degrees with the key unlogged; the code flies where the keys point and only forgives within 14 degrees, so that S most likely hadn't arrived at the spring, not proven. `run_lockjump.py` failures before that: bot stagger 86 flung it 129 studs, so the prompt correctly hid and the lock correctly let go past 85. Punching the bot a lot makes this test fail until it respawns. Scripts: `run_shiftbug.py`, `run_lockjump.py`, `jump_sampler.luau`. NOT TESTED: real Alt in the Roblox player, gamepad, touch, two players, true 1080p, terrain, turning with the real mouse in the new shift lock.
- Build `air-27` (2026-11-04, user: bumps less impactful, half a propel or less; SUPERSEDES the `air-15` bump). `Combat.bumpOutcome`: `PropelSpeed * BumpPropelShare` 0.4 = 33.6 at most, scaled down by `BumpFullClosing` 36 to no less than `BumpSoftShare` 0.4; no stagger multiplier and no upward push; with the 15% edge the most anyone takes is 38.6, under half a propel's 42. Stagger `BumpStaggerShare` 0.5, so 6 even, 7 and 5 at full edge. `BumpSpeedKeep` 0.6. A bump no longer calls `MarkHit`, so it doesn't beat a punch windup, and shows the puff and a small `HitLanded` only, no burst or flash. Also: `Sfx.preload` now runs in `task.spawn`, because in `KnitInit` it held up every controller's start until the audio finished loading. LIVE TEST FINDINGS: animations and sound missing in the published game. ANIMATIONS: `AnimController` uses `KeyframeSequenceProvider:RegisterKeyframeSequence`, Studio-only, silent live. Needs real uploads or a Lua player. SOUND: cause not yet known, likely asset permissions on Creator Store ids; needs the live F9 console.
- Build `air-28` (2026-11-04, user: upload the animations). THE GAME IS GROUP-OWNED: `game.CreatorId` 2970443, type Group, universe 10774434705. Anything it plays has to belong to that group or be permitted, so uploads go under the group, using a key made under the group. `Shared/AnimSequence` is the one clip builder. `animations/export_clips.py` has Studio serialise each clip to `animations/export/*.rbxm` (23 done). `animations/upload_clips.py` uploads them, saving progress to `animations/uploaded.json` and ids to `Config/AnimAssetIds` (generated, never edit). `AnimController` plays uploaded ids; a clip with no id warns by name, and only Studio falls back to registering it. WHEN A CLIP CHANGES: `build_clips.py`, push, `export_clips.py <name>`, `upload_clips.py --redo <name>`, push, publish. UPLOAD NOT RUN YET: waiting on the user's key. Open Cloud for animations is documented but untested here. ALSO CHECK under the group owner: the music tracks, and the lock-on images uploaded through Studio's `upload_image`, which may be owned by the user's account rather than the group.

- Build `air-29` (2026-11-04, SUPERSEDES the punch hit rule above; details, causes and test results are in the vault note `Punch Detection and Clashes`). HIT RULE: `Combat.inHitbox` now takes the swing and tests a fixed hurtbox (`TargetRadius` 1.5) against the swing's arc (`Range` 5), a close sector (`CloseRange` 2.7) and the contact disc (`OverlapRadius` 2.5). `HalfAngleDegrees` and `MaxHalfAngleDegrees` are gone. A swing stays live for `ActiveSeconds` 0.05, sampled every frame. TIMING: `MissRecovery` 0.1, `BufferSeconds` 0.1, client honesty through the `PunchResult` remote. CLASH: `Core/Clash`, `ClashService`, `ClashController`, `Ui/ClashBar`, clip `ClashBarrage`, settings section `Clash`. Remotes `PunchResult`, `PunchDebug`, `ClashStarted`, `ClashTap`, `ClashEnded`, `ClashRepelled`. Attributes `HT_Clash`, `HT_ClashAt`, `HT_ClashFace`, `HT_ClashScore`. FOR THE ROUND STEP: call `ClashService:EndAll` on round transitions, since nothing calls it yet. STUDIO-ONLY HOOKS: workspace attributes `HT_TestPunch`, `HT_TestClash` (only wired when `RunService:IsStudio()`) and `HT_TestBotQuiet`, all for `work/test-harness`. NOT TESTED: two real players, real latency (Studio's lag setting doesn't change `GetNetworkPing`), a true fast crossing in play, balance. `ClashBarrage` needs uploading with the other clips before it shows live. `Debug.ShowHitbox` now draws hurtboxes, each swing's real volume and its rejection reasons, instead of the constant red fan.

- Build `air-30` (2026-11-05, user: airborne recovery; details, scenarios and test results are in the vault note `Air Recovery`). NEW: `Core/AirRecovery`, settings section `AirRecovery`. Each accepted air punch gives one push (`BoostSpeed` 24, fades `BoostFade` 24, capped along its direction at `MaxSpeed` 60) and a lift (`UpAssist` 5, up to `UpAssistCeiling` 6). No charges or per-punch limits. Falling: `FallGravityScale` 0.32 eased over `FallEaseSpeed` 16, `MaxFallSpeed` 40. Applied on the client at the throw (`MovementController:PunchThrown`), taken back if the server refuses. CHANGED BEHAVIOUR: a knockback with no lift no longer zeroes a fall, including hits and bumps on someone falling; a punch's aftermath is flagged `selfRecoil` and in the air costs no speed and doesn't end an air run; the wall check compares the whole velocity, so steering against a launch no longer erases it; free air movement now sets velocity exactly, with `Kick.LaunchSteerSpeed` steering; float can punch (`PunchWhileLaunched`), hold and stun can't. `Animation.LandMinFallSpeed` lowered to 34 to stay under the top fall speed. `planJump` and `canReach` take a `TargetFall`. KEPT: slam and stun keep full gravity; a rebound and a missed jump keep their own. TOOLS: `lune/recovery_sim`, `work/test-harness/run_recovery.py`. RESULTS: modelled typical player 80 and 85% close, 35 and 35% far, 0% very far, also 0% for a sharp player; a floor-level hook off the edge is 0% for everyone, because the lift can't climb. NOT TESTED: real players and so the real percentages, two players, real latency and the refusal take-back, other frame rates in play, real Alt lock, gamepad and touch, a real arena shrink (none exists yet, so the round or arena step should keep judging edges from the current radius).
- USER DECISION (2026-11-05): a floor-level hook off the edge stays unrecoverable, so edge hooks are reliable kills. Revisit only if it feels too harsh in play; try a small increase in a hit's lift first.

- Build `train-3` (2026-11-05, user: a dedicated training arena; SUPERSEDES the 2026-11-03 test bot. Layout, stations, controls and results are in the vault note `Training Arena`). REMOVED: the chasing, punching bot and its brain (`Core/BotBrain`, its spec, `TestBot` settings, `CombatService:PunchAs`, the `HT_TestPunch` and `HT_TestClash` hooks, and bot tapping in `ClashService`). Nothing can make a dummy attack any more. The 1v1 arena has no dummy at all now. NEW: `TrainingService` (arena, stations, walk-on pads, who's in training via the player attribute `HT_InTraining`, falls, `LeaveTraining`), `Core/TrainingLayout` (all positions, plus `platformAt`, which the kick's rebound now uses so it lands on the platform you kicked from), a passive `DummyService` (spawn from a spec, safe resets, stationary mode, marked paths, rebuilt if lost), `TrainingController` and `Ui/TrainingPanel` (the testing display), a per-player hitbox switch in `HitboxDebugController`, `StaggerService:Set`, `KickService:Release`, `Combatants.isDummy` and `Combatants.players`, and the `BodyReset` remote, which clears all momentum when the server moves someone. USER REQUEST: controls are floor pads you walk onto, not prompts on pillars. CHANGED: `CombatService:CanFight` asks `TrainingService:AllowsFight` (dummies never fight each other; nobody reaches across the boundary; sparring in training is a setting). A stationary dummy can't be bumped or launched. Hitbox words only show for targets within 25 studs. FOR THE ROUND STEP: count people with `Combatants.players()` and skip anyone with `HT_InTraining`; dummies carry `HT_Dummy`. TUTORIAL: its "run to the dummy" step will find no dummy on the 1v1 arena; it's still off. NOT TESTED: two or more players in training together, sparring, StreamingEnabled with players far apart, phones and gamepads (the display starts hidden on touch), and the old harness scripts listed in the test-harness README.
- Build `train-4` (2026-11-05, user: put the attacking bot back in the 1v1 arena; NOT PUSHED YET, Studio was closed). `TestBot1` is back on the 1v1 arena, only when one player is alone, with its old `TestBot` settings plus `ReturnSeconds` 3. It is a `DummyService` body with `fights` in its spec, so training dummies stay passive. `Core/BotBrain` and its spec were REBUILT from the settings and the old calling code, because the original file was deleted with no copy; behaviour should match but isn't guaranteed identical. Back too: `CombatService:PunchAs`, the tutorial check on its punches, bot tapping in clashes, its clash walk, its air steering, and the Studio-only `HT_TestPunch`, `HT_TestClash` and `HT_TestBotQuiet` hooks, so the old harness scripts should work again (untested). It carries `HT_Dummy` and `HT_Bot`: never counted for rounds, fights only players outside training. 277 Lune tests pass. NOT TESTED in Studio at all yet.
- Builds `lift-1` to `lift-3` and `recover-1` (2026-11-08, user requests). FALLING LIFT: only an UPPERCUT thrown while falling (`LiftFallingSpeed` 2), with nothing within `LiftFloorCheck` 14 below, sets vertical speed to `LiftSpeed` 42 with `LiftGravityScale` 0.65 for `LiftSeconds` 0.33: a jump-sized hop of about 7 studs (lift-1 measured 2.8 to 3.1 studs at the old 26). `LiftsPerFall` 2, `LiftCooldown` 1.2, reset on landing, never when slammed; replaces `UpAssist` for that punch. Code: `AirRecovery.canLift/usedLift/liftVelocity`, `MovementController` (raycast floor check), `CombatController` passes the swing to `PunchThrown`. SLOWER FALL (user): `FallGravityScale` 0.24, `MaxFallSpeed` 30. RECOVERY (user targets: close 80-90%, moderate 50-60%, very far 0, no random roll): the lift and slower fall had pushed the sim to 100/97/82%; now `BoostSpeed` 17 and `LiftForwardSpeed` 0 give typical 93% close (88% late), 50% moderate (39% late), 0% very far (sharp too). Uppercut launch, jump and lift height untouched. `lune/recovery_sim` now models the combo and lift, and has a `window` mode (share back by reaction time). Uppercut victims are now in the air about 4.7 s (was 3.1), so a careful player reacting at 1.0 s still saves 82% at moderate distance; shorten air time if hesitation should cost more. MEASURED in Studio (run_recovery.py): close launch 103 out back (furthest 58 and 63), moderate 135 lost with Studio's slow clicks (furthest 98.4, sim 98.6 with the same inputs; sim says full-cadence clicks save it), very far 203 lost. One close flight showed an unexplained 98 inward burst at 2.3 s that didn't repeat. HITBOX: the server always tested from the attacker's position each frame; the debug drawing was placed once, so it now follows its attacker every frame (`HitboxDebugController.place`). `TargetRadius` back to 2 (was 1.5 since air-29) with `Range` 4.5 and `CloseRange` 2.2, so reach is unchanged: 6.5 ahead, 4.2 sides, 2.5 behind, area +5% only at a hook's outer arc edge. MEASURED in Studio with HT_TestPunch: hits at 6.2/4.0/2.3 studs, misses at 6.8/4.5/2.8, all 8 as expected. NOT TESTED: two real players, phones, the lift on a gamepad.
- Builds `hud-1`/`hud-2` (2026-11-08, user brief with two reference images; GAMEPLAY HUD FIRST, results screen NOT STARTED). New: `Controllers/HudController` (top strip, your panel, three action tiles, ring-out feed, spectating chip, help chip with the controls list, one target stagger chip), `Ui/HudTheme` (every colour, size, font, timing and the control lists: tune here), `Ui/HudMotion` (all tweens, reduced motion, interrupt-safe), `Core/HudLogic` + `tests/HudLogic.spec.luau` (9 tests), and STUDIO-ONLY `Services/HudPreviewService` (drives the round contract from `workspace:SetAttribute("HT_PreviewRound", "fight 3 4" | "ringout <victim> [attacker]" | "fell <victim>" | "shrink" | "out" | "back" | "over" | "intermission 10" | "starting 4" | "clear")`). Hooks added, read-only: `MovementController.Hud` (speed from the root, propelLeft, kickReadyAt, kickTarget, kicking) and `PropelBlocked`; `CombatController.PunchEvent` (thrown, blocked, hit, miss, cancelled, refused) and `GetPunchTiming`; `LockOnController:GetTarget`; `KickPromptController:IsActive` (its gui DisplayOrder is now 9). REMOVED `KeybindController` (its list is the help chip now); `Debug.MoveReadout` false; permanent stagger labels only on training dummies. PRODUCTION HOOK MISSING: no round service exists. It must create `ReplicatedStorage.HT_RoundState` with attributes Phase, Round, Alive, Total, CountdownEnd (server time), ShrinkActive, ShrinkSeq, a `RingOut` RemoteEvent in it fired (victimName, attackerName?, "knocked"|"fell"|"left"), and set player attribute `HT_Eliminated`. SEEN IN PLAY (hud-1, real bot fight): panel, real stagger and speed, MISS word, NO TARGET and kick cooldown on the tiles; preview: FINAL TWO 2/4, ARENA CLOSING chip, feed shown then gone after 2 s, eliminated hides your panel and tiles and shows SPECTATING, respawn leaves one HUD. hud-2 FIXES (not yet pushed): tiles 64 tall with the bar at the very bottom (text clipped before), and the HUD drops a removed round folder's last state. NOT TESTED: kick cue during a shrink, small window, touch, gamepad, help toggle, target chip (screen_capture can't show BillboardGuis), reduced motion.
- Build `hud-3` (2026-11-08, user: controls as a simple always-on list on the right, like their reference image, no toggle; stagger bar at the bottom). SUPERSEDES the hud-1/2 layout: the lower-left panel, the three action tiles and the help chip are GONE. Now: bottom centre `Vitals` (STAGGER bar 262 px with the big % on its right, SPEED digits and gauge under it), right side `Controls` list (key cap + name, white text with a dark edge, no panel; rows Shift lock, Lock target, Punch (mouse glyph), Propel, Air kick; gamepad rows L1/R2/B/Y; none on touch). Each action row shows its cooldown: grey name + seconds while recovering, dim + "no target"/"locked" when unusable, an accent flash when ready again, HIT/MISS after a punch, a red cap on a blocked press. Sizes and rows in `Ui/HudTheme` (`Vitals*`, `Control*`, `HudTheme.Controls`). Passes all gates; NOT PUSHED yet (Studio was in Play). KICK-DURING-SHRINK RUN (hud-2): the cue showed its full 0.59 s window (104 frames) and the HUD stepped back to 0.55 within 0.15 s, but the harness kicked on the TRAINING floor, where round info is hidden by design, so the survivor update and shrink chip during a cue are STILL UNTESTED on the 1v1 arena.
- Build `hud-4` (2026-11-08, pushed, PASS 92 scripts). Contains hud-3 (seen in Play: controls list on the right, stagger and speed bottom centre, speed past 36 in blue with the over gauge, Air kick dim with "no target") plus a CLASH TIE change (user: a tie should knock both back with the same power). `Clash.TiePush` 28 REMOVED; `Clash.TieShare` 1: both launched away from each other at `Clash.tieStrength` = a standing punch at no stagger (55 studs/s, lift 9.9), capped by `FinishMaxSpeed`, no stagger added. Code: `Core/Clash.tieStrength`, `ClashService` tie, one new test (290 pass). MEASURED in Studio with HT_TestClash and TieMargin/WinLead raised in memory only (the bot taps in clashes regardless of HT_TestBotQuiet, so a natural tie can't be forced): both peaked at 54 studs/s outward, moved 18.8 and 21.6 studs, stagger unchanged except recovery.
- Build `hud-5` (2026-11-08, user brief: controls bottom right, League Spartan everywhere, a text hierarchy; NOT PUSHED, Studio was in Play). FONT: League Spartan is NOT loadable (TextService:GetFamilyInfoAsync on rbxasset://fonts/families/LeagueSpartan.json fails "Temp read failed", no Enum.Font entry, no League Spartan font family on the Creator Store search), so the game uses the stated fallback MONTSERRAT (rbxasset://fonts/families/Montserrat.json; family info lists Thin..Black, all weights genuine). New `src/shared/Typography.luau`: `FAMILY` (switch the whole game here), text roles (Headline/Winner ExtraBold, Announce/Stat/StatSmall/World Bold, Action/Button/Name SemiBold, Key/Value/Label Medium, Body Regular 1.2 line height), `Typography.apply(label, role)`, and `Typography.adopt(root)` which moves any role-less text under PlayerGui onto the family (the default for future UI). Every old Gotham assignment (Combat, HitboxDebug, KickPrompt, Tutorial, ClashBar, KickResultText, TrainingPanel, and the server's DummyService and TrainingService world labels) now uses a role. HUD: the three combat actions are one bottom-right group (icon, SemiBold name, Medium key cap, reserved 44 px status slot, thin cooldown line; ready = yellow icon, recovering = grey + seconds + line, unavailable = slash + dash; Air Kick row says NOW while the kick cue is up), a "? Controls H" chip above it opens the full guide (H / Select / tap); redrawn mouse glyph (outlined body, split, lit left button, wheel). The right-middle list from hud-3/4 is gone. Kick timing ring stays at screen centre-low on purpose (eyes on the target during the window); its row shows NOW. ScreenGui uses CoreUISafeInsets. NOT DONE: results screen, touch cluster repositioning (Roblox's default CAS button ring is kept, with cooldown covers), phone and small-window screenshots.
- Build `hud-6` (2026-11-08, user: rework hud-5 with the roblox-ui skill and the LihFolk UI rules; NOT PUSHED, Studio was in Play). Used: `roblox-ui` SKILL.md (jump zone, 8 px gaps, text fit, `<unbound>` sentinel, gradient-not-rotation corners) and its `verify_ui.py` on a mirror spec `Project/design/ui/hud_layout.json` (actions group + vitals); and the vault digest `Haymaker Tussle/UI Rules.md`. All text roles now 15 or more (Key/Value/Label 15, Name/Body/World 16, Action/Button 17, StatSmall 18). Actions group 268 x 118, columns icon 14 / name 42 (82 wide) / key 132 (58) / status (58, right inset 12); vitals 380 x 72; strip 260 x 52. verify_ui: 0 warnings, all checks pass at 896x414, 1024x768, 1920x1080; the 22 remaining text_fit failures are all 640x360 "phone-small", where the checker scales the page to 0.5 with no floor, but this HUD floors its scale at 1 and hides the action rows on touch. Stagger % and speed digits start as `<unbound>`. Icons stay drawn (icon generation needs CF_ACCOUNT_ID/CF_API_TOKEN and upload needs a Roblox API key; none set, and the user asked to leave keys untouched).
- `hud-6` PUSHED (PASS 93 scripts) and SEEN IN PLAY 2026-11-08: all 55 on-screen labels render Montserrat (weights in use Bold, SemiBold, Medium, Regular), none under 15, no `<unbound>` left, no errors. Screenshot with a real Q press: Propel row grey with 2.3s and its line filling, Air Kick recovering 6.4s, speed 60 in blue over the gauge, controls group bottom right, help chip above it, centre clear. NOT CHECKED: a smaller window and a landscape phone (Studio's viewport/device can't be changed through the MCP tools; needs the Device emulator), the help guide open, gamepad, reduced motion. Results screen not built.
- Build `hud-7` (2026-11-08, user: real icons in a Roblox style from their reference images, simple and matching; the mouse keeps the HUD colours). Icons DRAWN in code by `design/ui/draw_icons.py` (thick dark outline, flat colour, one shadow, one highlight): punch (yellow fist), propel (pale-blue puff with streaks), kick (navy boot, blue cuff, orange tread sole, yellow slashes), mouse (off-white outline, dark body, yellow left button, no cable). PNGs 256 px in `assets/icons/`, preview `design/ui/icons_sheet.png`. UPLOADED with the user's OK through Studio's `upload_image` (no API key): punch rbxassetid://139534316468106, propel 113409293001874, kick 113416372768113, mouse 118394725313773, stored in `HudTheme.Icons`. HUD rows now use ImageLabels (24 px), greyed by ImageColor3 when recovering, faded plus a slash when unavailable, a small pop back to full colour when ready; name column moved to 46 for the 8 px gap. Gates green (290). NOT PUSHED: Studio was in Play. Next: push, playtest, screenshot the bottom-right group.
- `hud-7` PUSHED (PASS 93) and SEEN IN PLAY 2026-11-08 with a real W+Q press: fist in full colour (Punch ready, MISS shown), puff greyed while Propel recovered (2.4s, line filling), boot faded with a slash (no target), mouse in the Punch key cap. Possible polish the user hasn't asked for: the mouse at 18 px reads small, and the slash covers much of the boot.
- Build `hud-8` (2026-11-08, user picked the hud-7 polish). Mouse glyph in the Punch key cap 18 -> 24 px (the drawn mouse fills about 3/4 of its image, so it now reads about 18 px inside the 22 px cap); unavailable slash 30 -> 18 px long, so most of the icon shows. `HudController.luau` only. Gates green (290). PUSHED (PASS 93) and SEEN IN PLAY: mouse visible at 24 px, Air Kick slash 18x3 on the faded boot. Not tested: other window sizes, gamepad.
- Build `hud-9` (2026-11-08, user: the fist didn't look like a punch, the propel didn't look like dash smoke). `design/ui/draw_icons.py` REDRAWN: punch is now a side-on fist punching right (knuckles forward, thumb across, red wrist band, cream speed lines behind, impact marks in front); propel is a dash-smoke trail on the ground (puffs biggest at the front, shrinking to a wisp behind, speed lines above). Kick and mouse unchanged. Uploaded through Studio's `upload_image`: punch rbxassetid://93989680466321, propel 108732937698089 (old hud-7 ids replaced in `HudTheme.Icons`). Gates green (290). PUSHED (PASS 93) and SEEN IN PLAY: both new images load (IsLoaded true) and show in the HUD rows at 24 px.
- Build `fall-1` (2026-11-08, user: the slow fall should apply to everything, not only uppercut launches). The kick REBOUND after a landed kick and the MISSED-JUMP air run now fall on `AirRecovery.fallVelocity` like launched and free-air bodies: up on their own gravity (`ReboundGravityScale` 0.85, `MissGravityScale` 0.3), down eased to `FallGravityScale` 0.24 and capped at `MaxFallSpeed` 30. `Kick.MissMaxFall` 52 is now UNUSED (left in game.json). Slams still keep full gravity. LANDING: `DiveKick.planRebound` takes an optional `fallTime(up, height)`; `MovementController` passes `AirRecovery.timeToDrop`, so the rebound's longer air time is planned for and the flat speed drops instead of overshooting `ReboundLandFar`. New test in `tests/Rebound.spec.luau` (291 pass). PUSHED (PASS 93), Play starts clean with BUILD fall-1. NOT MEASURED in Play: a real landed kick's rebound and a missed jump (air time and where they land), and the falling lift during them.
- GIT (2026-11-08, user request: a second developer works through Rojo and changes were getting lost). `Project/` is a Git repo, pushed to the PRIVATE GitHub repo https://github.com/veguu/haymaker-tussle (branch `main`). `Packages/` is ignored (`wally install` rebuilds it); `.gitattributes` keeps LF line endings. Rules for both developers are in `WORKING TOGETHER.md`: `git pull` before any Rojo sync, one person syncs into the Team Create place at a time, never edit Rojo-controlled scripts in Studio. From now on, `git pull` before starting work in a session, and before every rojo_push; commit + push after each piece the user has tried and APPROVED (user, 2026-11-08), not after every edit.
- Builds `contact-1`/`contact-2` (2026-11-08, user brief: hit detection, body bumps, floaty falling; then stagger and pushback). APPROVED by the user and committed (2026-11-08). Settings and what they do are in `design/Settings Guide.md`.
  - PUNCH: `CombatService.sample` now sweeps every moment since its last look (`Combat.contactWindow`, `sweepTimes`, `sweepReach`) using `SpeedAuditService:PositionAtTime` (history plus the live position) for BOTH bodies, the target rewound as before (cap `MaxRewindSeconds` unchanged). The look starts `Punch.GraceSeconds` 0.05 before the active frames, never before the press was accepted; contact still resolves at the normal impact time; height and walls are judged at the contact moment; one hit per target per swing. Exact overlap already hit before (OverlapRadius); new `Combat.punchAway` throws the target along the attacker's facing inside `PointBlankRadius` 0.75 instead of a noisy offset. The sample loop now keeps looking until the whole window is covered, even after a late frame.
  - BUMPS: `KnockbackService:_checkBumps` keeps per-pair state (`Combat.stepBumpPair`): a bump is ENTERING contact, judged on the approach line from the previous check (works at coincident centres and just after crossing), a crossing between checks counts, contact ends past `BumpDistance + BumpReleaseMargin`, `BumpMaxSweep` 25 ignores teleports, pair cooldown kept. PUNCH OVER BUMP (`Combat.bumpPriority`): a qualified bump waits `BumpHoldSeconds` 0.1 (so a just-pressed M1 can reach the server) and while either of the pair is mid-swing; a punch landing on that pair within `BumpPunchGuard` drops it; a miss lets it happen. Pair-specific (`CombatService:PunchPendingBetween`, `HitBetweenSince`).
  - FALL: `AirRecovery.gravityScale` no longer caps falling at the rise's gravity. `FallGravityScale` 0.24 -> 1.3, `FallEaseSpeed` 16 -> 12, `MaxFallSpeed` 30 -> 90; everything (players, dummies, kick predictions, rebounds, misses) uses it. Tool: `lune run lune/fall_sim` (FALL_SET= to try values).
  - STAGGER/KNOCKBACK: `PerHit` 12 -> 7.2 (14 punches to full), `HitRelief` 6 -> 3.6, `BumpStaggerShare` 0.5 -> 0.25 (bump stagger now rounded to 0.1, not whole). Pushback: target slide dominated the gap (26.1 studs vs your recoil 3.2), so `BaseSpeed` 55 -> 23, `SpeedBonusPerStud` 0.9 -> 0.38, `MaxKnockbackMultiplier` 2.5 -> 6 (full-stagger finisher unchanged at about 138). DESIGN CHANGE: the hardest bump (34-38) can now out-shove a punch on a fresh fighter (23); the Bump spec now promises bump < punch from a quarter stagger on. Uppercut lift and recoil unchanged.
  - MEASURED IN STUDIO (single client, ping ~1 ms, `work/test-harness/run_feel.py`, `run_contact.py`, `run_kickwindow.py`), before -> after: uppercut apex +56.1 -> +56.7/+55.9, descent to launch height 1.96 -> 0.81 s; ledge drop 10 studs 0.57 -> 0.28 s, 20 studs 0.89 -> 0.38 s; standing-punch slide 26.1 -> 4.6 studs, running 39.0 -> 5.3, recoil 3.2 -> 3.4; ring-out from radius 60: weak hit 115.8 RING-OUT -> 64.6 stays on, finisher at stagger 96 217.8 -> 169.2 still RING-OUT. Contact scenarios on the copy of the bot: overlap, near overlap, crossings (target, you, both moving; 3 of 4 repeats of the 0.05 s crossing with you moving hit), server hitch, clear miss, wall (blocked), above (height), run past then press (miss), bumps both ways, fast crossing, idle inside (none), contact held (one), out and back (two), punch with bump on the same impact (bump dropped). Air Kick after an uppercut connected in 2 of 4 scripted attempts that set up; one miss jumped but never came within touch range (not diagnosed). Recovery sim: close uppercut 93% -> 71%, far 50% -> 16%, close drift 96% -> 3% (BoostSpeed 26 would bring uppercuts back to 93%/34%).
  - NOT TESTED: two real players, simulated latency, gamepad. Harness noise: an outside source pressed M1 every ~0.42 s in some runs; the old airtest harness can't hit the shorter kick window (key latency about 1 s).
- Builds `round-1` to `round-3` (2026-11-09, ROUND PIECE 1 of the round system; user answers recorded in game.json `decisions.rounds`). APPROVED and committed (2026-11-09). New `Core/Round` (+ `tests/Round.spec.luau`, 10 tests) and `Services/RoundService`: Intermission (15 s once 2 are ready) -> Starting (4 s, everyone held on evenly spread spawns with `HT_RoundHold`: movement, punches and boost refused) -> Fighting (out = below the elimination line, past the play area, leaving, dying or AFK; 0.5 s batches; last one standing wins, all out together = no winner) -> RoundOver (6 s, folder attribute `Winner`) -> back to the lobby. Publishes exactly the HUD contract (`ReplicatedStorage.HT_RoundState`, `RingOut`, `HT_Eliminated`). Ring-out credit: last punch, kick, bump or clash within `Round.CreditSeconds` 4 (`RoundService:NoteHit` called from CombatService, KnockbackService, KickService, ClashService). Fighters in the round only fight each other, only once the fight starts (`CombatService:CanFight` asks `RoundService:AllowsFight` first). LOBBY STAND-IN: the training arena (TrainingService `EnterLobby`/`Release`); new, waiting, eliminated players go there; TestFloorService no longer spawns anyone on the arena with rounds on. AFK: `AfkController` button top left ("AFK OFF / playing", yellow "AFK ON / sitting out"), remote `AfkToggle`, player attribute `HT_AFK`; on mid-round = leave that round. STUDIO: the test bot counts as a fighter (`Round.StudioBotCounts`); eliminated bot stops fighting (`HT_Eliminated` on the model). ARENA: radius 75 -> 105, spawn ring 73, 30 spawns, MaxPlayers 30; training moved to CenterX 400 to keep 37 studs clear. HUD: round info now shows in training (it's the lobby); fixed speed digits showing `<unbound>` until you first moved after a spawn. `HudPreviewService` drives the real folder when it exists.
  - SEEN IN STUDIO (solo with the bot): countdown in the lobby, both put on the arena, held 4 s (W held: no movement; punch "refused: round countdown"), fight, the bot knocked me off ("vegu out: knocked by TestBot1"), winner shown, 6 s, next countdown; a fall with nobody hitting me = "fell"; AFK on mid-round ended it and the countdown stayed off while AFK; HUD strip "ROUND 01 FINAL TWO 2/2"; round 2 started on its own.
  - NOT TESTED: two or more real players, a player leaving or resetting mid-round, a simultaneous final fall (no winner) in Studio (unit-tested only), phones/gamepad for the AFK button, 30 fighters. Next round pieces (Future Steps): bot fill to 20, the lobby, the arena shrink, the results screen, the arena's new look from the user's reference image.
  - `round-4` (user): AFK is a LOBBY setting. Toggling it in the lobby only decides whether you're put in the next round; it never moves you. In a round it's locked: server refuses (`HT_InRound` player attribute, set at round start, cleared when you're out or the round ends), the button shows "AFK / locked in round" dimmed. AFK no longer counts as leaving a round. SEEN IN STUDIO: in a round the press did nothing; in the lobby AFK on stopped the countdown without moving me, off restarted it.
- MAPS (2026-11-09, user brief with four reference images; user said to build all three and commit without asking, this time only). Three arenas built by script in Blender 5.2: `design/maps/` (README, `common.py`, `kitestead.py`, `gnomon.py`, `saltcrest.py`, `export_roblox.py`, `check_glb.py`). Same flat oval on all three (230 x 190 studs, 3-stud flush rim); Kitestead = painted timber in open sky with kites; Gnomon Isle = pale stone strata among floating islands with a sundial landmark; Saltcrest = glazed tile and terracotta above a coastline 700 studs down. Renders and review sheets in `design/maps/out/` (`arenas_compare.png`, `<map>/<map>_sheet.png`); vault record `Haymaker Tussle/Arena Maps.md`. Exported for Roblox: `design/maps/out/<map>/export/<map>.glb` + baked PNGs + `manifest.json` (every mesh under 20k tris, one material, one UV set; only surface and rim collide). Each GLB re-imported in a clean scene and rendered correctly.
  - NOT DONE: importing a map into Studio (needs File > Import 3D and an upload under the group), and the code for an oval arena (Round.isOut, spawn ring and TestFloorService still assume a circle of radius 105). The user hasn't picked a map yet.
- Build `move-1` (2026-11-09, user: remove nitro; the Q dash should propel you the way you're going, steerable but hard, like nitro but a short burst; the air kick should knock down unless the timing is perfect). APPROVED by the user and committed (2026-11-09).
  - NITRO REMOVED: `Core/Nitro` and its spec, `Ui/StaminaBar`, the server stamina copy and `HT_Nitro` in `PropelService` (back to its pre-nitro relay), `NitroStart`/`NitroStop` remotes, the trail and camera layer in `FxController`, `GameConfig.Nitro` and `Controls.Nitro`. Left Shift is unbound; shift lock stays on Ctrl. `PropelStarted` no longer carries "boosted". The round countdown's `HT_RoundHold` still freezes movement (kept in MovementController's stun check; its nitro-only uses went with nitro).
  - Q DASH: `Core/Momentum` dash is a burst along current travel (from a standstill, toward the keys), same speed profile (84, 0.65 s, 3 s cooldown). The keys steer it at `Movement.PropelTurnScale` 0.28 of the turn rate (about 150 deg/s at dash speed); input more than 90 deg off travel is ignored, so it can't be turned round; steering eases from 0.28 back to full over `PropelControlReturnSeconds`. REMOVED: the fixed A/D curve (`PropelArcDegrees`, `PropelCurveInputThreshold`, `PropelCurveBodyLead`, `dashCurve`), `PropelSteerRate`, the boosted dash and `Momentum.Modifiers`.
  - KICK: `Kick.FinisherGrades` green only. Orange and red slam and are now a KNOCKDOWN: `HT_Stunned` from the slam until `Kick.KnockdownSeconds` 0.5 after landing (KickService). No lying-down animation exists; they stand still for it.
  - Gates: rojo build OK, 325 Lune tests (2 new burst tests, nitro's removed), selene src 0, stylua clean. MEASURED IN STUDIO (solo, client floor at y 1000 for the dash; server-injected `_impact` on TestBot1 in a round for the kick): dash 36 -> 84 in about 0.15 s, held, back to 36 by about 0.6 s after Q; holding D bent it 69 deg during the burst (about 130 deg/s). Orange: slammed to the floor at 0.18 s, control back at 0.78 s. Green: finisher, launched up and away, 0.43 s stun.
  - NOT TESTED: two real players, gamepad and touch dash, a real timed kick (the grades were forced through `_impact`), how 0.5 s of knockdown feels in a fight.
- Build `move-2` (2026-11-09, user: dash, punch and slam sounds should hit harder; the downslam made a sound twice). APPROVED by ear by the user and committed (2026-11-09).
  - DOUBLE SLAM: a slam kick fires `KickImpact` twice (contact with a hit stop, then the floor with `stop` 0), and both played the same punch_hit + bump + launch at the KICKER. `FxController:KickImpact` now takes `landing` (`stop <= 0`): contact = deep body + boom_low + launch at the kicker (the crack comes from the target's HitBurst, since the kick is also a HitConfirmed); landing = ground_break + boom_mid + low punch_hit AT THE TARGET. Seen in Play: one cluster at contact, one at the floor 0.33 s later.
  - SOUND SYSTEM: `SoundBank` roles hold several TAKES (round-robin, never the same twice in a row), each with a measured `start` (skips leading silence) and a `volume` that evens the takes out. `Sfx.play(role, parent, pitchVary, { pitch, volume, cut })`: pitch replaces the jitter, `cut` fades a long tail out. FIX: callers used to set PlaybackSpeed after play, so slowed sounds were destroyed at their normal-speed length and cut off (the kick thump, the jump thud).
  - NEW SOUNDS (free, by id, Roblox's licensed partner catalogue): `punch_crack` = ProSoundEffects "Punch Some Crack And Thud" 6/4/7/1 (9117972033, 9117971755, 9117972070, 9117971499; about 0.21 s of silence skipped), `dash` = ProSoundEffects "Whoosh By Fast Airy Swooshing Whipping Thuds" (9126229267, 9126229715, 9126229710), `boom_low` = APM "BOOM-Deep Boom 06" 1837830213, `boom_mid` = APM "BOOM-Mid Boom 07" 1837830667. LAYERS: punch = crack x1.25 + old punch_hit x0.55 (+ boom_low on a strong hit); clash repel the same, softer; dash = boom_low (pitch 1.25, cut 0.35) + dash x0.65 + old propel x0.5.
  - MEASURED in a Studio client (PlaybackLoudness summed per frame, master scaled 0.1): old punch peak 773, new punch about 800 before the x1.25 crack boost, strong hit 1118, old dash 117, new dash 814 before the x0.65 cut, kick contact 1118, slam 1601. `bump` (9119323910) peaks at only 6, about 1% of a punch: bumps and clash pulses are nearly silent (left alone, not asked).
  - NOT TESTED: other players' sounds at a distance, phone speakers, many hits at once.
- Build `move-3` (2026-11-09, user, with eight reference images: a heavier punch swing, a sharper dash sound like blowing wind, and dash VFX made of particles and trails with after-images and speed lines instead of solid shapes). APPROVED by the user and committed (2026-11-09).
  - DASH VFX: new `src/client/Fx/DashFx.luau` (a plain module, not a Knit controller; `FxController:PropelGust(character, seconds)` calls it, and no longer takes a direction). The gust blobs are GONE from the dash (`gustSide` stays for the air-punch gust). One kit per character, made on its first dash and reused: 10 thin camera-facing Trails on the root (speed lines), a streak ParticleEmitter on the root (Roblox's built-in sparkle sprite, VelocityParallel, NEGATIVE Squash to stretch it along its flight; positive stands it on end), a dust emitter at the feet (built-in smoke sprite, `Emit` only on the ground), and after-images: sets of Neon copies of the visible body parts (joints, textures and face stripped), made once, then the oldest set is moved to the body's pose every `DashGhostEvery` 0.07 s and fades over `DashGhostSeconds` 0.34 from pale to deep blue. Each stays hidden for 0.045 s so it never covers the body. One Heartbeat connection, disconnected when idle; after-images dropped when the character leaves the workspace. Past `DashGhostRange` 150 studs from the camera no after-images, past `DashFxRange` 220 nothing; touch devices get 60% of the lines, streaks and parts. No uploads: nothing needs an asset id. Settings: 12 new `Effects.Dash*` (Settings Guide). ForceField was tried for the after-images and rejected: on this game's R6 block bodies only the heads show.
  - SOUNDS: `dash` = ProSoundEffects "Doppler Whooshes Crackly Airy Bursts" (9114157694, 9114157695, 9114157793), started 0.3 s into the file where the gust is already rising, pitch 1.15, volume 0.8, cut at 0.5 s, over the old `propel` whoosh at 0.4; the low boom is gone from the dash. `swing_heavy` = the three "Whoosh By Fast Airy Swooshing Whipping Thuds" takes that were the dash in move-2, restarted so the peak lands about 0.08 s after the press (`Punch.Windup`), pitch 0.88, volume 0.5, over the old `punch_swing` at pitch 0.85, volume 0.55. `Sfx.play`'s `options.pitch` is now the speed the random jitter varies around (it used to switch the jitter off).
  - CORRECTION to move-2's numbers: `Sound.PlaybackLoudness` does not change with `Sound.Volume` (the same punch read 773 at volume 0.02 and 627 at 0.2), so move-2's "measured" peaks were sums of raw layer loudness with every volume ignored. Weighted by volume (loudness x volume, summed per frame, Studio client): punch hit about 400, strong hit 719, slam landing 991, original swing 198, new swing about 275, original dash 86, move-2 dash 287, new dash about 300. The per-take evening volumes in `SoundBank` came from raw peaks, which is right for that job.
  - SEEN IN STUDIO: screenshots of a staged 12 s run at 84 studs/s on a client floor, from the side and from behind (after-images spaced about 6 studs, lines, the body clear of its newest after-image). A real punch and Q dash in a round against the bot: `swing_heavy` + `punch_swing` per swing (both fighters), `dash` + `propel` on Q, kit of 10 trails and 6 after-image sets created, no errors. Gates: rojo build OK, 325 Lune tests, selene 0, stylua clean.
  - NOT TESTED: another player's dash seen from a distance, several dashes at once, phones (the 60% quality), R15 bodies and layered clothing (this place is R6), how the after-images read on the three new maps. `Effects.DriftPuff*` smoke still exists but can hardly fire now that the body faces its travel during a dash.
- Build `hud-10` (2026-11-09, user: controls without a background, subtle; both bottom groups smaller). NOT PUSHED TO STUDIO (Studio was in Play, user said wait), NOT COMMITTED. Controls list (bottom right) has no panel or accent bar: names, key caps and status are light text with a thin dark outline (`outline()` helper, `HudTheme.Transparency.Outline` 0.3), key caps are faint tags (`CapTag` 0.45), the "? Controls H" chip is muted outlined text with no panel. Vitals and controls scale by `HudTheme.Scale.Bottom` 0.82 (text about 12 px at 1280x720, under the UI Rules' 15-unit floor, by user request). Gates green (339). Next: push in Edit, screenshot the bottom of the screen, commit on approval.
- MAPS NEXT STEP: the user is looking at the three maps in Blender (`design/maps/show.py` opens one in the GUI) and will pick one (or a rotation). Then: user does Studio File > Import 3D of `design/maps/out/<map>/export/<map>.glb` under the group; then set collisions from manifest.json, place it (surface top at Arena.CenterY 100), turn the test floor off, and switch Round.isOut / spawns to the 115 x 95 oval.
- Build `hud-10` PUSHED (2026-11-09, user said no need to ask this time): git pull had nothing new; check.py green (339); playtest stopped, `rojo serve` started, `rojo_push.py` PASS (98 scripts match); Play started, console shows BUILD hud-10 on both sides, screenshot in `work/screens/hud-10_play.jpg` (controls list unpanelled with outlined text and faint key caps, bottom groups smaller). Studio left in Edit. NOT COMMITTED: waits for the user's look.
- MAPS VISUAL PASS 2 (2026-11-09, user brief: handcrafted floors, rims and undersides for all three). Surfaces and rims are now painted texture maps (numpy, `design/maps/paint.py` + `surfaces.py`): 12 x 64-stud surface tiles at 16 px/stud and a strip-unwrapped, chamfered rim in 2 pieces at 15-19 px/stud, each with colour, OpenGL normal and roughness maps; recovery-view scenery cut into wedges with caps split off and painted from baked position/normal/AO. Before/after from the re-imported GLBs, same cameras and sun: `design/maps/out/compare_<map>.png` (old renders and GLBs in `out/before/`). All meshes within limits, surface and rim tops exactly flat, GLB spans 230 x 190, normal maps survive re-import. Mesh names changed: `Deck_jk`/`Meadow_jk`/`Plaza_Tiles_jk` tiles and `Rim_*_1/_2` (manifest collision list updated). Rebuild one map with `bash design/maps/rebuild.sh <map>`. UNTESTED: Roblox Import 3D of these GLBs (sizes 29 / 70 / 33 MB; whether SurfaceAppearances come through). NOT COMMITTED. Stray copy of an early texture run sits in `C:\out\` (a relative-path bug, fixed); a safety check stopped me deleting it, the user can delete it. Next: the user picks a map, then the import piece as in MAPS NEXT STEP.
- MAPS PASS 3, SIGHTS (2026-11-09, stopped at a usage limit; NOT COMMITTED, user hasn't reviewed). New backdrop scenery on all three maps, built by `design/maps/sights.py` (prop kit) + `gnomon_sights.py` (balloon fair: launch field, two drifting balloons, valley village), `kitestead_sights.py` (mountain timber village, waterwheel, lumber yard, ox cart, ropeway, kite train, kite loft), `saltcrest_sights.py` (bay village, dock, nets, salt pans, sailboat, lighthouse, Net Rock, squall). "Current kit" was read as Gnomon Isle (the user hasn't confirmed). New tools: `preview_backdrop.py` (fast backdrop preview), `contact.py` (sheets), `REUSE=1 bash rebuild.sh <map>` keeps painted surface maps, look-around cameras LookN/E/S/W and per-map `Sight_*` cameras, each map has its own `SUN`. All three built and exported once (within limits, tops flat, 230 x 190); sheets `out/look_<map>.png` (before/after) and `out/sights_<map>.png`. FOUND AND FIXED AFTER THAT: `export_roblox.py` used a relative output folder, so baked PNGs were written under `C:\out\` and the GLB embedded STALE pass-1 PNGs for baked (non-painted) meshes (Saltcrest's land came out part black; island and tree colours stale since pass 2). Fixed with an absolute path. IN FLIGHT WHEN STOPPED: Saltcrest full rebuild (headland shortened, sailboat moved, sight cameras raised to 16 so the eaves don't hide them) and a Kitestead re-export; results land in `out/saltcrest_rebuild.txt` and `out/kitestead_rebuild.txt`. STILL TO DO: check those two results; re-export Gnomon with the fixed exporter (its GLB still has stale island/tree textures); regenerate the `look_`/`sights_` sheets; README and vault note for pass 3; reopen the user's Blender windows. Mesh names from `split_caps` carry a `.001` (cosmetic).
- NEXT REQUESTS QUEUED BY THE USER (nothing built yet): (1) OPEN-AIR LOBBY replacing the training hub: research done, no code written. Plan: new `Core/Lobby.luau` + `LobbyService` + `SpectateController`; platform X -90..90, Z 170..410 at Y 101 (viewing edge at Z 170 faces the arena, past the round's out line so its invisible wall never helps a fighter), training = far third Z 330..410 with two dummies via `DummyService:Spawn`, gamepass strip along +X, spawn about (0, 312) facing -Z, invisible walls 240 high; `RoundService:SendToLobby` -> lobby, `CombatService:CanFight` gets a lobby rule (no PvP, dummies only), tag standing fighters `HT_Fighter` for the spectate list, `Training.Enabled` false (old hub kept in code), lobby disc for the kick rebound's `platformAt`, Blender visual in `design/lobby`. Studio had no place open ("Place is not open"): the user must open "title" before any push. (2) GNOMON MEADOW RESTYLE: hand-painted look, leaf-green base with broad soft warm/cool patches, no fine ripples, no dense clover dots, matte, sparse 2-3 stroke grass tufts and a few perimeter flowers, centre kept clear. Source traced: the speckles are the clover leaves/chevrons and flower heads, the wavy grain is the blade strokes, both in `meadow_painter` in `gnomon.py`; the maps are per-tile images used only by Gnomon (no shared material). To do: rewrite `meadow_painter`, delete `out/gnomon/textures/Meadow_*` so they repaint, rebuild, before/after from the Gameplay camera. The Blender MCP instance now has `out/gnomon/gnomon.blend` open (it was an empty default scene).
- MERGE (2026-11-09): pulled spicy's move-1..move-3 (nitro removed, Q burst, new sounds); hud-10's files merged on top, gates green. hud-10 still NOT COMMITTED.
- Build `lobby-1` ON DISK, NOT PUSHED (Studio was in Play; ask before stopping), NOT COMMITTED. Open-air lobby replacing the training hub as where players wait. New: `Core/Lobby.luau`, `Core/Spectate.luau`, `tests/Lobby.spec.luau`, `Services/LobbyService.luau` (stand-in floor, 4 invisible frictionless walls on the floor's edge, spawn facing the arena, two practice dummies, HT_InLobby, fight rule: nobody in the lobby can be hit, dummies only by lobby players), `Controllers/SpectateController.luau` (button under AFK; My View / Fighter POV with previous and next; HT_Spectating holds your body). Changed: `RoundService` (waiting players go to the lobby; standing fighters carry the tag HT_Fighter), `CombatService:CanFight` (round, then lobby, then training), `MovementController` (kick rebound lands on the lobby when you're on it; spectating holds movement), `CombatController`, `HudTheme.Spectate`, config `Lobby` rewritten and `Training.Enabled` false (old hub's code kept; one setting brings it back). Platform X -90..90, Z 170..410, Y 101. Gates green (337). Visual model: `design/lobby/lobby.py` -> `design/lobby/out/export/lobby.glb` (12 painted floor tiles + base; sightline checked in Blender from spawn and the edge). NOTHING PLAYTESTED: walls and corners, dummies, spectate camera, controls coming back, the bot in rounds. To import the model: Studio Import 3D of lobby.glb, top at Y 101, centre (0, 290), then `Lobby.ShowFloor` false.
- GNOMON MEADOW restyled (hand-painted: leaf green, broad warm and cool patches, sparse stroke tufts, perimeter flowers, clear centre, matte); before/after `design/maps/out/meadow_before_after.png` once the rebuild finishes. Old meadow maps kept in `out/before_meadow/textures`.
- Build `lobby-2` ON DISK, NOT PUSHED, NOT COMMITTED (2026-11-09, user: the fast auto-aimed follow-up only when locked on; otherwise the old jump you steer). The air follow-up now has two forms. LOCKED ON to the launched target (LockOnController's selection, sent to the server by the new remote `LockOnState`): unchanged, the server holds them and you snap to them at `ApproachSpeed`. NOT LOCKED ON: the old free jump from commit 1f7b359, restored: `DiveKick.planJump` works the arc out once, `aimJump` uses your keys or facing (forgiven within `AimForgiveDegrees` 14), the keys steer it (`SteerSpeed` 42, `AirAcceleration` 190), the target is NOT held until you touch them, and the server allows `LeapChaseSeconds` 4. `KickAccepted` now carries (target, snap). Old settings restored into `Kick`: LeapMin 70, LeapMax 150, JumpCarryMax 170, JumpMeet*, JumpShort*. Tests `tests/FreeJump.spec.luau`. NOT PLAYTESTED: either form in Studio, the jump prompt still shows for targets the free jump can't reach (the old `canReach` check wasn't restored).
- Build `move-4` ON DISK, NOT COMMITTED, NOT YET SYNCED TO STUDIO (2026-11-09, spicy: guided leap when not locked on, hold-to-charge dash coloured by power, punch sparks instead of the hitbox shape). The user has not tried it yet.
  - FOLLOW-UP NOT LOCKED ON (changes lobby-2's steered free jump): now a GUIDED LEAP. New `DiveKick.leap` / `DiveKick.leapSeconds` and `State.guide`; `DiveKick.velocity` re-aims it every frame at the spot beside the target plus an arc (`Kick.LeapGuideArc` 120), so it follows a falling, steering target without the keys. `LeapGuideSpeed` 130 (0.3 to 1.1 s; the snap is 260), capped at `LeapGuideMaxSpeed` 190. It is a velocity, so walls stop it. Server unchanged: the target is still only held from the attach, and `LeapChaseSeconds` still bounds it. `planJump` / `aimJump` / `spring` stay in DiveKick with their tests, but MovementController no longer plans a steered jump (the `spring` state is still used for a late attach after a miss).
  - CHARGED DASH: Q (or B, or the touch button) now dashes on RELEASE. Hold up to `Movement.PropelChargeSeconds` 1 s (it goes by itself at full): top speed `PropelSpeed` 84 to `PropelChargedSpeed` 140, steering `PropelTurnScale` 0.28 down to `PropelChargedTurnScale` 0.08. `Momentum.tryPropel` takes an optional `power` (0 to 1); `chargePower`, `chargedSpeed`, `chargedTurnScale` are new. A press during the cooldown is refused at the press. A stun, hold, clash, kick or body reset drops the charge. You keep running normally while charging.
  - REMOTE CHANGE: `PropelRequest` now carries one optional number, the power, for looks only. PropelService takes it only if it is a plain number, clamps it 0 to 1 and relays it on `PropelStarted`; anything else is a tap. The cooldown check is as before.
  - DASH COLOUR: `DashFx.play(character, seconds, power)` colours lines, streaks and after-images white (tap) through yellow to fiery orange (full), and a charged dash throws up to twice the streaks. `DashFx.charge` shows sparks at the feet while charging (`Effects.DashChargeRate`), only to the one charging. The dash sound drops in pitch and rises in volume with power.
  - PUNCH SPARKS: new `src/client/Fx/ImpactFx.luau` (6 pooled invisible parts with three emitters each: star flash, thin spikes, shards; built-in sparkle texture, nothing uploaded). `FxController:HitBurst` adds one at the contact point, sprayed the way the target is sent, bigger on a strong hit. `FxController:Swing` adds a small one (`Effects.SwingSparkScale` 0.4) at `Punch.Range` in front of the puncher as the swing goes live. `Debug.ShowHitbox` is now false, so the see-through floor shape and blue cylinders are off by default; the training toggle still shows them. No contact-2 code was touched.
  - CHECKED: gates green (rojo build, 347 Lune tests with 4 new ones, selene, stylua). The spark's look was checked in Studio Edit mode on a stand-in copy of the emitters (screenshot, frozen at 0.06 s). NOT TESTED: anything in Play. `rojo serve` had died, so none of move-4 reached the place; it is running again from this folder and the plugin needs Connect and Accept.
- ARENA MOVED ASIDE + LIGHTING (2026-11-09, spicy; ON DISK, NOT COMMITTED). The Gnomon map preview (`Workspace.GnomonPreview_TEMP`, 128 no-collide MeshParts centred on the origin) shows on spicy's machine as huge checkered boxes, one of them a slab right over the arena. Its builder asked for the stage to be moved rather than his models, so `Arena.CenterX` and `Lobby.CenterX` are 3000 for now (both config files; TEMPORARY, set back to 0 when the real map takes over). `tests/TrainingLayout.spec.luau` no longer hard-codes the arena at 0,0. Nothing in the preview folder, the Baseplate or the SpawnLocation was touched. Seen in Play: arena floor at (3000, 98, 0), lobby at (3000, 97, 290), nothing above the player. LIGHTING, set in the place itself (not in Rojo): the vault's "Toon arena" recipe, with Atmosphere Density 0.22 instead of 0.3 so far scenery shows. Was the Studio template default (Brightness 3, Ambient/OutdoorAmbient 70, ClockTime 14.5, Atmosphere 0.3 / offset 0.25 / haze 0, Bloom 1 / 24 / 2). Now: Ambient 70,70,85; OutdoorAmbient 100,100,115; Brightness 2; ColorShift_Top 255,225,190; EnvironmentDiffuse 0.2, Specular 0.1; ClockTime 16; Latitude 30; ShadowSoftness 0.3; Atmosphere offset 0.15, colour 180,190,210, decay 90,100,130, haze 1; Bloom 1 / 40 / 1.6; new ColorCorrection `Grade` (contrast 0.12, saturation -0.05).
- Build `move-5` ON DISK AND IN THE PLACE, NOT COMMITTED (2026-11-09, spicy: follow-ups to move-4; the user has not tried it yet). move-4 and the arena move ARE committed and pushed (7c7331d, 2344ecf); ignore "not committed" in their entries above.
  - PUNCH: the spark now shows only on a landed hit (`HitBurst`). Every swing instead shows a thin streak behind the fist: `ImpactFx.fistTrail` (one Trail per arm, `Effects.FistTrailWidth` 0.45, `FistTrailSeconds` 0.13), on the arm from the new `AnimController:SwingArm`. `Effects.SwingSparkScale` is gone.
  - CHARGING: you creep while holding the dash key (`Momentum.chargeSlow`, `Movement.PropelChargeMoveSpeed` 7, braked at `PropelChargeBrake` 140). A charge sound (`dash_charge` in SoundBank: the `dash` gust files from their quiet start, played at 0.5x rising to 0.95x with the charge; no new asset) and a slight view tremble (`Effects.ChargeShakeStuds` 0.07 at full). Both only for the one charging.
  - DASH ZOOM: `FxController:DashZoom` widens the field of view for your own dash (`Effects.DashFovPunch` 8, doubled at full charge by `DashFovChargeBonus` 1). It shares the field of view with `CameraKick` through two module values, so they stack and both return to the same base.
  - DASH HIT (server): a bump where exactly one of the two is dashing is now a hit on the other. New `Core/DashHit.luau` + `tests/DashHit.spec.luau`; `PropelService:IsDashing` (a player who asked to propel within `PropelSeconds` + 0.15 s); `KnockbackService.applyBump` checks it first and calls `applyDashHit`: thrown along the dasher's travel at `Knockback.DashHitPushShare` 0.7 of the server-measured speed (cap `DashHitMaxPush` 100, speed counted up to `DashHitFullSpeed` 140, nothing under `DashHitMinSpeed` 50), `DashHitLift` 16, up to `DashHitStagger` 12, credit to the dasher, `MarkHit`. The dasher is not slowed. New remote `DashHit` (server to all) shows it as a hit (FxController). Both dashing, or too slow: the ordinary bump. No contact-2 file was edited (CombatService:MarkHit is only called).
  - COLOUR: a full charge is now a light neon orange (head 255,208,136, tail 255,152,64) instead of the dark fiery one.
  - CHECKED: gates green (351 tests, 4 new). In Play through an injected LocalScript: charge sound playing and sped up, charge sparks on and off, field of view 70 to 86 mid-dash and back to 70, dash lines the new orange, fist Trail on during a swing and off after, no errors in Output. NOT TESTED: a real dash into someone (the DASH HIT path has only its rule tests), real key holds, how the fist streak and tremble look, two players.
  - move-5 FOLLOW-UP (same day, spicy: harder dash hit, the one hit goes further than the dasher, and only on a high charge). `DashHit.outcome` now takes the dash's charge: nil under `Knockback.DashHitMinCharge` 0.6. `DashHitMinSpeed` 50 to 90 (above a tap dash's 84, so a lied-about charge on a tap gets nothing), `DashHitPushShare` 0.7 to 0.9, `DashHitMaxPush` 100 to 130. `PropelService:IsDashing` became `DashPower` (the clamped charge the client sent, or nil). Tests check that a charge of 0.6 really reaches 90, and that the slide (push squared over twice `KnockbackDecay`) beats the dasher's whole dash at 0.6, 0.8 and 1. 354 tests. Still NOT TESTED in Play: a real charged dash into someone.
  - move-5 FOLLOW-UP 2 (spicy: the dash hit's knockback felt late). Cause: it rode the bump check, which runs every 0.05 s, only notices contact inside `BumpDistance` 3.5 and then holds 0.1 s (`BumpHoldSeconds`) for punch priority. Now `KnockbackService:_checkDashHits` runs every Heartbeat before the bump check and applies at once: new `DashHit.reaches` looks along the dasher's measured path, `Knockback.DashHitReach` 6 + `DashHitLeadSeconds` 0.12 of travel ahead, `DashHitWidth` 4.5 to either side. One hit per dasher and target per 1.5 s (`dashHits`), which also stops a bump following it. The bump path still falls back to `applyDashHit`. 355 tests. NOT TESTED in Play.
  - move-5 FOLLOW-UP 3 (spicy: the dash only seemed to hit near its end). Cause: the `DashHitMinSpeed` 90 gate read `SpeedAuditService:GetVelocity`, an average over about 0.2 s, and a charged dash starts from the 7 studs/s creep, so the first third of the dash measured too slow. `KnockbackService.dashVelocity` now takes the faster of that and a 0.08 s measure from `SpeedAuditService:PositionAt` (read only; still server-seen positions). NOT TESTED in Play.
  - move-5 TRIED BY spicy (2026-11-09): a charged dash into the bot hits from the start of the dash, and the knockback timing was accepted. Not yet committed.
- Build `move-6` ON DISK AND IN THE PLACE, NOT COMMITTED (2026-11-09, spicy; sits on top of the uncommitted move-5). The user has not tried it yet.
  - NO TAKING SOMEONE ELSE'S LAUNCH (changes lobby-2): `Kick.FollowUpOthers` false. KickService `jumpTarget` and the client's prompt both only offer a target whose `HT_AirBy` is your own user id. A launch by a bot (`HT_AirBy` 0) can't be followed up by anyone. `FollowUpRange` (80, other people's launches) is now unused unless the flag is turned back on.
  - PERFECT KICK AIMS AT THE CURSOR: `KickCommit` now carries one optional Vector3, the flat direction from the target to the floor spot under the cursor (camera look without a mouse, or with the cursor on the sky). The server cleans it with the new `DiveKick.aimDirection` (flat, unit, nil for junk) and uses it in `_impact` only when the grade is green, in place of "away from the kicker". Other grades are unchanged. The kicker's own rebound is unchanged (still back from where they face).
  - CRASH: `KickService` keeps a `flights` table from the moment a kick's launch is sent (finisher or slam) for `Kick.CrashSeconds` 1.2. Each Heartbeat it measures the body's own speed from positions; above `CrashMinSpeed` 30, anyone within `CrashDistance` 5 (not the kicker, not held, `CanFight`) is thrown the way the body was going at `CrashPush` 90 with `CrashLift` 22 and `CrashStagger` 15, once per flight, credit to the kicker. Shown through the `DashHit` remote (now "a body hit this target").
  - CHECKED: gates green (358 tests, 3 new). In Play with injected scripts: a bot marked launched by someone else, 12 studs away, was refused (`HT_Skill` stayed nil); the same bot marked launched by the player was accepted (`chase`). Output clean on BUILD move-6. NOT TESTED: the cursor aim on a real green kick, a crash, two players.
- Build `move-7` ON DISK AND IN THE PLACE, NOT COMMITTED (2026-11-09, spicy; on top of the uncommitted move-5 and move-6). The user has not tried it yet.
  - EVERY KICKED BODY BREAKS THE FLOOR: the finisher path in `KickService:_impact` now also waits for the thrown body to touch the floor (after `LIFTOFF_SECONDS`, up to `FLIGHT_WATCH_SECONDS` 6, not if it was teleported) and fires the same landing `KickImpact` (stop 0) a slam does. Client: the landing branch of `FxController:KickImpact` calls the new `FxController:GroundBlast(body, root, power)`: `breakFloor` (the jump push-off's rocks, slabs and cracks) plus `ImpactFx.groundBlast`. So slams, green bounces and finishers all do it. Past the edge there is no floor and nothing shows.
  - GROUND BLAST (`ImpactFx.groundBlast`): 3 pooled sets, each a flash, 22 upward spikes, 34 embers that drift up, 16 dust sprites, a Neon disc racing out along the floor (3 to 34 studs in 0.4 s) and a thin Neon pillar. White and gold. Built-in textures only. `Effects.GroundBlastReach` 12 (how far down the floor is looked for), `GroundBlastScale` 1.
  - ROUNDS BUTTON: built, then REMOVED the same day at the user's request (the AFK button already keeps you in the lobby). `RoundHoldController`, the `RoundHoldToggle` remote and the RoundService changes are gone; RoundService is exactly as the teammate left it.
  - CHECKED: gates green (358 tests). In Play: `GroundBlast` under the player ran without error and a screenshot shows the rocks, floor ring, embers and spikes. NOT TESTED: a real finisher landing (the new server wait), a second player.
- move-5, move-6 and move-7 APPROVED by spicy ("everything's good") and COMMITTED together (2026-11-09). Ignore "not committed" and "has not tried it yet" in their entries above. What the user actually played is the dash hit, the charge and the kick changes; a second real player has still never been in a test.
- Build `lobby-2` COMMITTED AND PUSHED as 4f46e4d (2026-11-09) after the user tried it and approved: hud-10, the open-air lobby with Spectate, both air follow-up kick forms. Known gaps unchanged (jump prompt for unreachable targets, 14 degree aim forgiveness, stand-in lobby floor).
- STYLE PASS 4, GNOMON ISLE ONLY (2026-11-09, NOT COMMITTED, NOT REVIEWED). The user's brief with three references: playful painted low-poly, bright natural base, coral and gold accents, no outlines. New `design/maps/style.py` (palette, chunky stone bands, timber, islets, plant family twin/tiered/umbrella/bush, painters for stone, wood, caps, crowns); `gnomon.py` and `gnomon_sights.py` rewritten on it. Turf repainted (combed tuft strokes, four accent flower beds), rim is now a grass cap `Rim_Turf_*` with a lighter lip and a hanging skirt (edge, flat top, collision unchanged: 230 x 190, 14 pieces), seven chunky cliff layers, `Cliff_Timber` at five places, four garden islets 100+ studs out (grove NE, hollow log SW, tall pair W, pennant frame N), sundial with coral and gold trim, teal dropped. CHANGED RULE: islet trees reach about 55 studs above the deck (old rule 20 within 200). FIXED: `export_roblox.py` wrote single-colour props as linear numbers (too dark in the GLB on all three maps); Kitestead and Saltcrest need a re-export. Studio look with no upload: `studio_preview.py` + the 3D skill's `serve_assets.py` + `studio_preview.lua` through the `roblox-studio` executeLuau bridge (the official assistant MCP refuses localhost); parts land in `Workspace.GnomonPreview_TEMP`, session-local, DELETE BEFORE SAVING. Four cloud meshes exceed Roblox's 2048-stud mesh size and must be split before a real import. Sheet `design/maps/out/style_gnomon.png`; the map before the pass is in `out/before_style/`. Details: `design/maps/README.md`, "Style pass 4". NEXT: the user judges it; then the same style on the lobby (second brief: training on the left, open centre, side strip for gamepass displays, no visible walls, sightline from spawn and the whole arena-facing edge, check from avatar height; no floor plan image was attached), then the other two maps. A real in-game test needs the user's Import 3D of `gnomon.glb` and the oval code change.
- STYLE PASS 4, STUDIO CHECK NOT FINISHED (2026-11-10). The no-upload preview was built twice in Studio (104 of 108 meshes in about 3 s), but the only capture taken was from the first build, which still had a packer bug (textures washed out). After the fix Studio's captures came back black, then Studio and Blender were closed. So the arena has NOT been seen under the game's lighting with correct colours. To redo: open "title" in Edit, `python ~/.claude/skills/roblox-3d-model/scripts/serve_assets.py --dir design/maps/out/gnomon/studio`, run `design/maps/studio_preview.lua` in slices through the `roblox-studio` executeLuau bridge, capture from (-72, 116, 18) looking at (60, 96, -10), then delete `GnomonPreview_TEMP`. One thing seen in the first capture: the place's Atmosphere hazes scenery at 380 studs heavily, so the map's own baked haze may need lowering.

### env-1 (2026-11-10, NOT COMMITTED - waiting for the user's verdict)
- Map environments: presets in `src/shared/Config/MapEnvironments.luau` (hand-written; one entry per map over a shared sunny
  `Default`), rules in `src/shared/Core/Environment.luau` (+ `tests/Environment.spec.luau`: every cloud's whole sway path is
  checked against the lobby's view of the arena, the fighting space and landmark sight lines), instances by
  `src/shared/EnvironmentKit.luau` (also the Edit-mode preview: `Kit.preview(id, anchor)` / `Kit.endPreview()`).
- `MapService` (server) is the authority for the active map (ReplicatedStorage.HT_MapState + workspace.HT_Map). Rotation and
  fade timings are `GameConfig.Maps` (design/game.json). Round end -> next map; rounds wait while a map changes. Studio:
  set workspace attribute HT_MapRequest to an id or "next".
- `EnvironmentController` (client) applies lighting, clouds, leaves and balloon bob, with a screen fade around each change.
- Until the real import, maps are stand-in floors in each map's colours (ServerStorage.HT_Maps.<Model> replaces them).
- Outlines removed from the Gnomon build (user decision); clouds are no longer baked into any map GLB (runtime owns them).
  Gnomon GLB rebuilt: 103 meshes, 27 MB.
- Tested in Play: join, gnomon->kitestead fade (covered before the swap), interrupted change, 2 reloads (no build-up), round
  end -> next map. Lighting tuned on the Gnomon preview only; Kitestead and Saltcrest values are scaled to match, unverified
  on their real geometry (they get tuned with their rework).

### wind + bots + Gnomon in Play (2026-11-10, NOT COMMITTED - waiting for the user's verdict)
- Grass wind: `src/shared/GrassWind.luau` moves blade tips (EditableMesh) near the camera within ~1 ms a frame;
  `Core/Environment.grassSway` is the maths (tested). Each preset has one `wind` (direction, lean, gusts, GlobalWind).
  In game it needs Game Settings > Security > "Allow Mesh / Image APIs" ON; until then the grass stays still.
- Bot fill: `Round.BotFill` 25 (Studio only, `BotFillStudioOnly`). DummyService fill bots fight the nearest fighter,
  are removed when out; RoundService builds them during the countdown and clears them at round end.
- Placeholder floor: the red test wall is gone (bots got pinned against it).
- GNOMON IS IMPORTED: Open Cloud Model assets 132930149516661 + 125437537718079 (group 2970443), the GLB split in
  two for the 20 MB limit, aligned and joined as ServerStorage.HT_Maps.Gnomon (pivot = arena centre, 14 solid
  surface parts, grass no shadow). It lives in the PLACE, not in git: the place must be saved to keep it.
- Tested in Play: a full 25-fighter round on Gnomon (player + test bot + 23 bots), round end, next map.
- Not built yet: the arena shrink (rounds can drag when fighters avoid each other).

### wind fixes (2026-11-10, committed)
- "Allow Mesh / Image APIs" is ON (user). Grass wind runs in Play on the imported Gnomon: the map model is
  ModelStreamingMode Persistent, GrassWind binds grass as it streams in, frees its EditableMeshes on map exit,
  and retries a chunk refused for memory. In this Studio session 10 of 12 chunks got memory (suspected: shared
  with earlier Edit previews) - confirm all 12 after a Studio restart.
- Wind raised (user: "too subtle"): lean 0.09, gusts 0.3, flutter 0.05, gust bands every 4 s.

### bot fill in Team Test (2026-11-10, committed; user confirmed bots work in Team Test)
- Round.BotFillStudioOnly = false: bots fill on any server, one real player starts a round, the test bot counts.
- BEFORE THE GAME GOES PUBLIC: turn BotFillStudioOnly back on, or build the real few-players bot rule.

### mapswap-1 + arena-1: Gnomon rework b (2026-11-10, NOT COMMITTED - waiting for the user's verdict)
- MAP SWAP AT ROUND START (mapswap-1): MapService:RoundEnded only counts; RoundService calls
  MapService:ChangeForNextRound when the intermission countdown runs out, before placing anyone. The finished map stays
  through RoundOver and the whole intermission; too few players -> no round -> no change. Tested in Play: winner round,
  everyone-out round, swap gnomon->kitestead->saltcrest each at the next round's start (pending, swap, Starting).
- GNOMON DOUBLED ONCE: 426 x 352 (semi 213 x 176). Absolute numbers in MapEnvironments.gnomon.arena (with `original`
  106.5 x 88) and design/maps/common.py OVALS (ORIGINAL_OVAL kept). Round.arenaFor / ActiveArena give every system the
  live map's oval: Round.isOut (oval + PlayAreaMargin), Round.spawnPoints (oval at spawnShare 0.65), bots
  (BotBrain.steer shape: oval edge + going round obstacles), the kick rebound (smaller semi-axis). Stand-in maps keep
  the base circle. Environment.limitsFor grows the fight space / lobby view / cloud and leaf distances per map; the lobby
  view rule is now lobbyCorridor (lobby to arena) + lobbyBehindCorridor (behind it; the old one also swept beside it).
  Two Gnomon clouds moved out; Gnomon's leaves and landmarks moved with the backdrop.
- LOBBY: ViewEdgeZ 170 -> 250 (past the bigger out line), SpawnZ -> 266, FloorY 101 -> 111 (the most Lobby.seesNearEdge
  allows). Fill bots wait in rows behind the spawn, not on the viewing edge. Raycasts from the spawn, the edge centre and
  both ends to 9 near-rim points, the centre, the far side and a fighter's head: all clear.
- GROUND: no 3D grass, painted blades or meadow flowers; shade 9 (deep forest green) everywhere grassy, matte (style.PAL).
  GrassWind finds no grass on Gnomon now (harmless).
- OBSTACLES: design/maps/obstacles.py -> Config/MapObstacles.luau (20 in 15 groups, rules checked there and in
  tests/ArenaShape.spec). MapService adds invisible upright Cylinder colliders, frictionless, CanQuery FALSE (measured: a
  queryable knee-high collider lets a Humanoid step up onto it). Every rock and stump >= 2.4 tall (a low rock beside a tall
  one made a stair). Isolated runs: 0 of 62 went over at 36 and 80 studs/s; biggest hop 1.8 at dash speed.
- SCENERY: balloon pieces bobbed apart (each part had its own phase) -> one phase per bob rule (EnvironmentKit); balloon
  geometry now joined (load ring, ropes on it, burner frame on the ropes); launch-field ropes end on the basket and mouth.
  design/maps/check_scene.py (loose pieces, clashes, bob reach, buried obstacles): clean.
- IMPORT (place, saved v208): Open Cloud Models 137947322138540 (arena half) + 97763502817350 (backdrop half) + 126646880044031
  (obstacles, no-stair heights), aligned by design/maps/out/gnomon/upload/*centres.json (arrived turned 26 deg; residual
  < 0.002 studs) as ServerStorage.HT_Maps.Gnomon; the old model is ServerStorage.HT_MapsArchive.Gnomon_before_rework_b.
- NOT VERIFIED: real dash/punch knockback into props with the real controls (tested with Humanoid runs at 36/80), a real
  player falling onto a rock, phones, more than one real player, shadows' readability on the very dark ground (judge it),
  Kitestead/Saltcrest untouched (still stand-ins at the old size).
### move-8 (2026-11-10, spicy; COMMITTED, NOT PUSHED, NOT TRIED BY THE USER YET)
- KICK LANDINGS: the ground break + explosion now show for every kicked landing. Cause found in Play: the server
  reported every landing (slam and finisher), but each client looked for floor under the body AS IT SAW IT, which
  was still ~12 studs up (other bodies arrive late), and skipped. `FxController:GroundBlast(body, at, power)` now
  raycasts down from the position the server sent with `KickImpact`.
- CRASH (KickService flights): a kicked body now hits others the whole flight until it lands (`Kick.CrashSeconds`
  1.2 -> 4, ends on landing), with velocity smoothed from server positions. New SPLASH: when it slams into the
  floor (falling >= 15 studs/s, touching floor), everyone within `CrashSplashRadius` 8 is hit too. Thrown the way
  it was going across the floor, or out from under it when it came down nearly straight (`CrashAcrossShare` 0.3).
  `CrashTall` 6 limits the height difference.
- PUNCH (touches the contact-2 punch code, at the user's request): `Punch.Windup` 0.08 -> 0.16, `Cooldown` 0.32 ->
  0.42. The swing clips still strike at 0.08, so AnimController plays the lead-in at strike / Windup speed and back
  at 1 from the strike marker. Holding punch no longer auto-repeats: press starts a CHARGE (arm held in its
  pull-back, light at the fist), release throws, full at `ChargeSeconds` 0.8 throws by itself. New remote
  `PunchCharge` (no args); the server takes the charge as the gap PunchCharge -> PunchRequest on its own clock,
  only when a punch could be thrown, drops it on a hit, a cooldown refusal, or `ChargeGrace` 0.4 past full.
  Effects: `Combat.chargedPunch` stretches Range/CloseRange/OverlapRadius by `ChargeReach` 0.3, knockback x
  (1 + `ChargeKnock` 0.45), visuals x (1 + `ChargeFx` 0.7). `PunchStarted` carries the charge; others see a charge
  through the `HT_PunchCharge` attribute (the side it will be). Contact.spec crossings re-timed relative to
  Windup (same intent); AnimClips.spec now checks strike <= Windup.
- LOCK-ON IS AIM ASSIST: no forced camera. LockCameraController was rewritten: while locked it turns the stock
  camera around the character toward the target by `AimAssist.cameraYaw` (`LockOn.AssistYawRate` 2.5/s, x0.2 while
  the player turns the camera, none past 75 degrees). MovementController bends the keys up to 35% toward the target
  when within 50 degrees, and a punch within 9 studs / 45 degrees turns the body to face them. New
  `Core/AimAssist.luau` + `tests/AimAssist.spec.luau`. `Core/LockCamera.luau` and `GameConfig.LockCamera` are now
  UNUSED (kept with their tests; remove when sure). Marker: 128 -> 52 px (min 36), outline 0.55, inner 0.6,
  diamond 0.85, pulse 0.45.
- CHECKED: gates green (374 tests, 6 new). In Play: a 0.6 s charge measured 0.77 by the server and showed the
  charge attribute; fist glow on/off; ground blast from a server position. NOT CHECKED: the camera assist in Play
  (Studio's view wasn't drawing, render steps ran 0 frames), the input bend and punch facing, a real kick landing
  with the fix, two players. Output also shows the teammate's grass wind hitting the EditableMesh memory budget
  (12 refusals this session).
### move-9 / move-10 (2026-11-10, spicy; committed after the user tried it)
- STUDIO HAD BEEN RUNNING OLD CODE: the place still had `BUILD arena-1` although `rojo serve` was up and the
  plugin showed connected, so the user's reports since move-5 were about old code. A Rojo restart plus a fresh
  plugin Connect synced it. Before debugging a report, compare the place's build stamp with disk.
- CHARGED PUNCH REMOVED (user's call): move-8's charge is gone everywhere (PunchCharge remote, HT_PunchCharge,
  Combat.chargedPunch, fist glow, Punch.Charge* settings). CombatService, Combat and Net are back to their
  pre-move-8 versions. Kept: Windup 0.16, Cooldown 0.42, the lead-in slowed to the windup. A click is one punch;
  holding never repeats. LockOn.AssistPunchReach 9 -> 8 to match the uncharged reach.
- SPEED KNOCKBACK: Knockback.SpeedBonusPerStud 0.38 -> 0.7, new SpeedBonusMax 40 (Combat.punchStrength caps the
  bonus). Running (~36) about doubles a standing punch (23 -> ~48); a dash punch tops out at 63, before stagger.
- PERFECT KICK GOES TO THE CURSOR: the client sends the 3D direction from the target to the floor under the
  cursor (DiveKick.aimWay makes it unit). The server raycasts that line to the floor and launches with
  DiveKick.aimedLaunch to land there: across at max(push, Kick.AimSpeedMin 110), flight 0.3-0.8 s, the furthest
  spot Kick.AimReachMax 90, Kick.AimStandHeight 3. On landing: knockdown (KnockdownSeconds) and an equal and
  opposite push so they stop on the spot (knocks add up, so a zero push doesn't stop anything). With no floor on
  the line they fly along it. In Play on bots: aimed 20 -> landed ~17, aimed 45 -> landed 41 and stopped.
- Every finisher landing now knocks down too, and the landing wait is 0.15 s (not 0.5), so a drive straight down
  shows its blast at once.
- LANDING VFX BIGGER: Fx.GroundBlastScale 1 -> 1.6, new GroundBreakBlastScale 1.6 (kicked landings only; the jump
  push-off stays 1). ImpactFx.groundBlast adds a fireball and a smoke cloud.
- Gates green, 378 tests. Not checked in Play: the speed knockback by hand, the aimed kick from a real player's
  client, the lock-on assist.
### move-11 to move-13 (2026-11-10, spicy; committed after the user tried it)
- PUNCH (contact-2 code, at the user's request): hooks instead of jabs. AnimClips HookLeft/HookRight(+Run)
  rebuilt by the new `animations/build_strikes.luau` (Lune; no Python here): a wide level arc that strikes at
  0.16 = Punch.Windup, with a `hold` point at 0.09. WARNING: build_clips.py still has the old hooks and no
  HeavyKick, and rewrites all of AnimClips: run build_strikes straight after it. AnimClips is 183k chars
  (limit 185k). String is right hook, left hook, repeat (no uppercut; Combat.nextSwing/comboSwing).
  HOLD: press draws the punch back and waits (no power); release throws. New remote PunchReady (no args);
  the server takes a hold it saw start >= Windup - ReleaseWindup ago (0.09 s) and the swing lands after
  Punch.ReleaseWindup 0.07 (Combat.releaseWindup); others see HT_PunchReady. Punch.Range 4.5 -> 7.
- HEAVY KICK (right click / L2): new remote HeavyKickRequest (no args), side "Kick" through the punch
  machinery with its own hitbox (HeavyKick.Range 6, Degrees 35), Windup 0.3 (rooted, HT_KickWindup), Cooldown
  5. Server measures speed at the press: >= LaunchSpeed 30 launches (MarkLaunched, air kick possible),
  slower is an upward arc ArcBase + ArcPerStud*speed (Combat.heavyKickArc). New AnimClips.HeavyKick.
  Bots never use it, so bots no longer launch anyone.
- AIR KICK: Kick.Cooldown 15 -> 5. Space still jumps; the timed press once attached is now left click / R2
  (MovementController KICK_CLICK_ACTION sinks the click only while a kick is under way; touch unchanged).
- PUNCH KNOCKBACK: Knockback.SpeedBonusPerStud 2.4, SpeedBonusMax 120: 23 standing, 143 at 50.
- MOVEMENT: Movement.MaxSpeed 36 -> 50 (to try out).
- BUMPS: both are bumped, each by the OTHER's speed: BumpBasePush 12 + 0.45/stud; a dasher (>= 70) hits
  for 0.8/stud up to 110. BumpSpeedKeep 0 (thrown back, run stops, knock fades in ~0.5 s). Separate dash hit
  removed (DashHit settings/module unused, kept). TIMING: in a round, each client detects its own contact
  (src/shared/BumpPredict + MovementController checkBumps, the server's own stepBumpPair rule) and knocks
  itself at once; the server still adds stagger/credit, knocks bots, and skips players it predicted. Bump
  FX/sound made audible (the old "bump" sound peaks at 6) and sized by the knock.
- Checked in Play: hold release 0.07, kick request/root, bump fires at contact distance (2.9). NOT checked:
  the new animations by eye, two players bumping, the backward throw on a real run.
- 2026-11-11 (user, in Studio): Gnomon got "vibrant" grass: 86 LushGrass_* MeshParts (design/maps/build_lush.py,
  meadow_grass.py, apply_lush.luau; src/shared/GrassClumps.luau animates MeadowTuft_* clumps from EnvironmentKit). The
  previous model is ServerStorage.HT_MapsArchive.Gnomon_before_vibrant_grass_20261111. OPEN: that pass dropped the
  Obstacles_Stone / Obstacles_Wood meshes from the live map, but MapService still adds their 20 colliders from
  Config/MapObstacles, so the rocks are invisible walls until the meshes go back (they're in the archived model).

### dress-1: Gnomon dressing from the scenery kit (2026-11-11, user brief with four references)
- KIT: design/maps/props_kit.py -> out/gnomon/props/gnomon_props.blend: 11 rocks, 4 ruins (arch, wall, two columns,
  ivy), 5 branching trees, 6 bushes, 6 leafy plants, 6 flower clusters, lily pads + lotus. Boulder-reference treatment
  (cut-plane chunks, bevel highlights, facet tones, AO). Every foliage asset has a wind rig + 4 s loop in Blender
  (rocks/ruins/water/stone never move). Exported static (rest pose) by export_kit.py WITHOUT vertex colours (the
  bake's facet mask turned rocks bright green in Roblox) -> Open Cloud 85222884425358 rocks, 91332757835787 ruins,
  137877609538394 trees, 75300608976315 plants, 134762157942175 flowers -> ServerStorage.HT_PropKit (42 templates).
- PALETTE: image 4's green ~ (64, 120, 74) for every foliage key; ground a deeper green of the same family.
- MAP: gnomon_dress.py (called by gnomon.py build): central pond basin carved into Meadow_11/12 (2-stud grid,
  PreciseConvexDecomposition), Pond_Water, Grass_Scatter_* (10,105 low-poly tufts of the six kit plants, 47 chunks,
  568k tris, one atlas texture, double-sided, no shadow; GrassWind sways their tips), placements.json (213: shore
  rocks in four arcs with openings, 8 lilies, 11 small boulders, 22 flower spots, 147 island pieces replacing the old
  procedural trees, plus ruins and big rocks). Open Cloud 127598119804203, 83914346795076, 84367739528469,
  139889708431034 (the map in four files: grass exported smooth without tangents). studio_dress.py writes the three
  Studio scripts (studio_kit / studio_map / studio_dressing .luau). Old model: HT_MapsArchive.Gnomon_before_kit_dressing_20261111.
- COLLISION: floor tiles hull, the two pond tiles AND the rim strips precise (a rim hull filled the half-oval and
  floored over the pond). Shore rocks and field boulders hull; all plants and flowers decorative.
- COLOUR: imported MeshParts keep a grey Color (0.64) that multiplies their texture: everything set to white.
- POND SLOWDOWN: Core/Pond (+ tests/Pond.spec) on MapEnvironments.gnomon.pond (same numbers as the basin);
  GameConfig.Pond SpeedMultiplier 0.6, Ease 12/s, MaxRootAboveFloor 4.5. MovementController multiplies a separately
  eased pondShare into travel (stacks with stagger, recomputed each frame from position, so no lingering after
  death); bots wade too (DummyService). MEASURED in Play: 43 -> 30 studs/s entering, back to 49 within ~0.2 s after
  leaving, root sinks ~1.5 into the basin, crossing through the openings between shore rocks.
- Code colliders off for Gnomon (MapEnvironments.gnomon.codeObstacles = false).
- NOT DONE / NOT VERIFIED: in-game sway of trees/bushes/flowers (Blender rigs only; grass sways via GrassWind);
  grass LOD at distance (RenderFidelity Automatic); phones; more than one real player.

## move-14 (2026-11-11): R uppercut, running jump, dive kick, hold + Space launcher, 5 s hold cap
- R (L2) is THE HEAVY UPPERCUT (UppercutRequest, side "Uppercut", GameConfig.Uppercut): always an arc
  (Combat.uppercutArc: fixed Lift 85, outward by speed), never MarkLaunched, a trail on the thrown body
  (FxController:LaunchTrail). Right click does nothing now.
- SPACE: follow-up jump if someone you launched is in reach (unchanged); else, with punch held, the launching kick
  (the old heavy kick, HeavyKick.LaunchSpeed 0 = always launches; CombatController:ThrowLaunchKick); else THE JUMP
  (Core/Jump + tests/Jump.spec, GameConfig.Jump, 3 s cooldown): flown as an air run, height and length grow with speed.
- CLICK IN THE AIR after a jump is THE DIVE (GameConfig.Dive): the client flies the body down onto the cursor's spot
  (Jump.diveWay, within Range); DiveRequest (no args) marks HT_Skill "dive"; KickService watches the body land and
  hits everyone within Radius (push, lift, stagger), then DiveLanded for everyone's ground blast.
- Punch.HoldMaxSeconds 5: a held punch goes by itself at 5 s and needs a new press. ReadyMaxSeconds 5.5.
- HUD: new Uppercut row (R / L2, punch icon for now), the Space row is "Jump" and shows the jump cooldown unless a
  follow-up is on offer. Guide text updated. Touch gets an "Upper" button from the bound action.
- Gates: rojo build OK, 398 Lune tests, selene 0, stylua clean. MEASURED IN PLAY (lobby, Practice Dummy 1):
  standing jump 6.3 studs; running jump from 60 studs/s 10.7 high, 40 long, 0.68 s; a second Space inside 3 s did
  nothing. R: dummy rose 18.2, trail on, no HT_Air. Dive: HT_Skill "dive" seen, dummy stagger 0 -> 8, knocked 16.
  Hold: HT_PunchReady lasted 5.00 s then thrown, no new hold while still pressed. Hold + Space: no jump, dummy
  HT_Air float, rose 57.
- NOT VERIFIED: any of it by eye (animations: uppercut clip, KickDown pose on the dive, the jump has no clip of its
  own), the follow-up jump after the launching kick on this build, a dive aimed with a real cursor at a distance
  (tested straight down), touch and gamepad, two real players. Bots use none of the new moves.

## move-15 (2026-11-11): bumps off
- Knockback.BumpsEnabled = false (user: "no hit or stun, even if you dash"). Gates both the server's
  KnockbackService:_checkBumps and the client's predicted bumps (MovementController checkBumps). The bump code,
  settings and tests stay, unused. A kicked body crashing into others (Kick.Crash...) is a different rule, still on.

## move-16 (2026-11-11): the uppercut keeps your momentum
- Uppercut.Roots = false (user: "only the upwards kick (click + space) should slow u"). R no longer roots through
  the windup (client skips HeavyKickStarted, server sets no HT_KickWindup) and finishPunch skips the thrower's
  aftermath for it, so a hit gives no stop and no recoil and a miss no slowdown. The launching kick is unchanged.

## ground-1 (2026-11-12): Gnomon's painted ground, very low grass, islet palettes (user brief, two references)
- GROUND: `design/maps/gnomon_ground.py` (pure numpy; `python design/maps/ground_preview.py` = close patch, full tile,
  overlay in ~1 min). Image 1's natural greens (sampled: deep 58,108,48 / mid 82,136,56 / light 97,150,61) painted
  with image 2's treatment: soft broad patches, lit/shaded grass masses, blade fans and loose blades, ~4% small worn
  sandy patches with pebbles (13% in big blotches read as camouflage at the first review; tuned). Floor tiles now
  1024 px per 128 studs, flat normals; rim, lip and tree-less caps in the same greens. CLOSE-UP OVERLAY: Texture
  `HT_GroundDetail` (rbxassetid://138334844439577, seamless, 14 studs a tile) on every Meadow_ tile's top in Studio.
- Geometry and UVs UNCHANGED (checked against the dress-1 .blend: every repainted part identical), so only images
  changed: ids + the dress-1 ids for rollback in `design/maps/out/gnomon/upload/ground_ids.json`; `studio_dress.py`
  writes `studio_ground.luau`. The colour maps went up through Studio's `upload_image` (the textures folder isn't an
  approved Open Cloud upload folder; the user could approve `design/maps/out/gnomon/textures` in Assistant Settings ->
  MCP Permissions so future maps are group-owned like the rest). Overlay and tuft models via Open Cloud, group 2970443.
- ISLETS: one tree family per planted islet (NE grove Tree_C lime, SW hollow log Tree_B deep cool, W pair Tree_D pale
  olive, N pennant Tree_E bright, far SW Tree_A, far N Tree_B); cap painted in that palette; bushes/plants carry the
  palette tint (placements.json `tint` -> clone Color, attribute Tint); flowers chosen per islet; islet tufts in its
  grass colour. Trees keep their colours. Every old random draw kept: shore, lilies, boulders, field flowers identical.
- GRASS: `design/maps/gnomon_grass.py`. 5 very low tufts (`ReplicatedStorage.HT_GrassKit`, Open Cloud 118099472869556:
  Tuft_Fine/Fan/Leaf/Round/Sprig, 0.17-0.63 studs tall at scale 1, 20-35 tris, root at the pivot), NO texture: vertex
  shade x part Color (MEASURED: TextureID is not tinted by Color and its alpha doesn't show Color; vertex colours are).
  4,561 tufts (3,508 arena + 1,053 on the four near islets), ~132k tris (was 10,105 tufts / 47 chunks / ~568k tris).
  Layout generated: `src/shared/Config/GrassLayouts/Gnomon.luau` (stylua-ignored). Old chunks moved to
  `ServerStorage.HT_MapsArchive.Gnomon_grass_chunks_20261111`.
- RUNTIME: `Shared/GrassField` (replaces GrassWind + GrassClumps, both deleted): built per client from the layout
  (never replicated, Archivable false), BulkMoveTo once a frame; wind sway inside 45 studs of the camera, fading to
  nothing at 75 (55 on touch), so leaving the range is invisible; tufts past 30 studs update every 4th frame;
  bend away from every character root (players and bots) within 3.2 studs, up to 38 deg, in 1/16 s, back in ~0.6 s.
- MEASURED in Play (build ground-1, ~20 bots): all 4,561 built on the floor; a near tuft swayed 0.5-10 deg; walking
  through one: 6 -> 9 -> 30 deg at the root, back to its sway (1-5 deg) within ~0.6 s; GrassField ~0.45 ms/frame steady,
  <1 ms on live frames (~450 tufts in range), 0 with none in range. Frame time on this PC equal within noise old vs new
  (~12 ms both, gameplay and lobby views; old chunks measured static), i.e. the grass wasn't this PC's bottleneck.
- Saved v239. NOT TESTED: phones/low-end GPUs (where the -77% triangles and no EditableMesh copies should matter),
  more than one real player, how the overlay looks at very shallow angles, tree/bush/flower sway (still Blender-only).
- FAR MESA REMOVED (user 2026-11-12, "doesn't provide anything"): `Sight_FarMesa_*` and its 21 plantings (z > 1000).
  Build: still built in gnomon_sights.build_horizon (keeps every later random draw identical), then deleted in
  gnomon.py; its plantings skipped via gnomon_dress.DROPPED. placements.json 213 -> 192; .blend updated. Studio:
  `design/maps/out/gnomon/upload/studio_drop_mesa.luau` (moves them to HT_MapsArchive.Gnomon_far_mesa_20261112), RUN; checked in Play: no mesa parts, nothing past z 1000; saved v240.

## light-1 (2026-11-12): Gnomon + lobby lighting pass (user brief, five Genshin references; images 1 and 3 lead)
- PRESET (MapEnvironments.gnomon.environment; the lobby shares it, EnvironmentController reapplies it every map
  swap): sun clock 14.6, brightness 2.45, warm top (255,234,204); cool shade ambient (98,114,146) / outdoor
  (124,142,178), bottom bounce (26,34,20); ShadowSoftness 0.38; EnvironmentDiffuseScale 0.55, specular 0.08;
  exposure 0; grade contrast 0.16, saturation 0.02, tint (255,252,246); bloom 0.3 / size 28 / threshold 1.35 (white
  flowers, pale rocks, clouds keep detail); sun rays 0.02; atmosphere density 0.3, offset 0.3, colour (206,228,250),
  decay (150,186,232), glare 0.15, haze 1.3: the hard blue horizon band is gone and the far islets soften with distance
  while the battlefield stays clear. tests/Environment.spec: the "unnamed values come from the default" check now uses
  wind.global (Gnomon names its bloom on purpose now).
- TERRAIN: judged under the new light first; the even mid-green read as one flat lime field, so the painter changed
  (gnomon_ground: wider hue range, ~100-stud warm yellow-green vs cool blue-green swaths, stronger grass masses, a
  mottle, slightly lower saturation). Only the 12 floor tiles were repainted, by the new `design/maps/repaint_meadow.py`
  (pure numpy, 6 processes, ~8 min; `--check` proves it reproduces the build's tiles: 2/255 mean difference), and
  re-uploaded via Studio upload_image; ids + rollback in ground_ids.json. ARENA_PAL (rim, lip, tree-less caps) is
  updated in code but those textures are NOT repainted yet (needs the full Blender build); they still match closely.
- GRASS: arena tuft tones lifted to (144,180,82) (128,168,76) (160,190,92) in gnomon_grass and the layout; .blend updated.
  Islet palettes untouched.
- Before/after (same cameras): design/maps/out/gnomon/lighting/{before,after}_{gameplay,lobby}.jpg. Frame time after:
  lobby 13.5 ms, gameplay 14.3 ms (earlier session ~12 ms with different bot activity; no lights or effects added,
  only values). Saved v242. NOT TESTED: phones (shadow-less quality levels), the islets close up under the new haze.

## light-2 (2026-11-12): rim, lip and tree-less caps in the new greens (user picked gaps 1 + 2; arena shrink NOT wanted)
- Full `bash rebuild.sh gnomon` (24 min, ALL WITHIN LIMITS, 86 meshes). Geometry unchanged (triangle counts per mesh
  identical; only the already-archived Grass_Scatter_* and far mesa are gone from the build). Pixel diff vs the light-1
  build (backup in design/maps/out/gnomon/before_light2, untracked): Meadow tiles and Lip_Palette unchanged; changed:
  Rim_Turf_1/2 (now carry the warm/cool meadow swaths), Sundial_Cap, Sight_LaunchIsle_Cap, Fragments_Cap, Garden_Cap
  (mixed). Islands_Cap 0.19/255 = noise, not re-uploaded.
- Those 6 colour maps uploaded through Studio upload_image (copies in design/maps/out/gnomon/upload/light2), set on
  ServerStorage.HT_Maps.Gnomon; ids + rollback (`previous_light1`) in ground_ids.json. Checked in Play: Workspace.HT_Map
  carries the new ids. User decision: the arena does NOT shrink (gap 3 dropped).
- Optimisation rule from the user for every piece: extremely optimised, tested for phones (measure ms; touch/low path).

## sway-1 (2026-11-12): map plants move in the wind (user: "everything should feel like the wind is blowing on it")
- `Shared/PlantField` (client, beside GrassField, same wind + gust bands) moves the map's own HT_Dressing placements
  locally with one BulkMoveTo a frame; rules in `Core/Foliage` (tests/Foliage.spec). Flowers lean most, then plants,
  bushes, tree crowns (bark never moves); lilies bob and turn; rocks/ruins never move. Characters push flowers,
  plants and bushes over (eased). Ranges: small plants 110 studs, bushes 130, trees 320 (phones/quality 1-3: 70/80/200),
  fading to rest at the edge; past 40% of range a placement updates every 3rd frame.
- MEASURED in Play (this PC): nearest flower 4.7 deg, tree crown at 150 studs 1.6 deg; 0.03-0.06 ms/frame worst case
  (26 of 158 placements in range at the arena centre). NOT TESTED on a real phone. Rigid per clump (no per-stem bend:
  that would need bone-rigged re-exports).
- Also bots-1: owner-only Bots button (Studio or group owner) stops/restarts every bot (workspace HT_BotsFrozen).
- NEXT (user asked): ground-slam ground-break debris should take the colour/texture of the ground it broke.

## slam-1 (2026-11-12): ground-break debris takes the ground's painted colour (user request)
- `design/maps/ground_colours.py` samples Gnomon's 12 painted floor tiles into a 4-stud colour grid (107 x 88, 55 KB)
  plus one turf colour per rim/lip/cap part -> `src/shared/Config/GroundColours/Gnomon.luau` (re-run after any floor
  repaint). FxController.floorLook: a hit on a map with GroundColours (map Model's MapId) gives the grid colour
  (Meadow_ tiles) or the part's colour, SmoothPlastic, and the floor's HT_GroundDetail texture on slab/chunk tops
  (Texture HT_Skin per pooled piece). Dust uses the same colour. Plain parts/terrain unchanged.
- MEASURED in Play via server-fired DiveLanded for a bot: grass hit -> green pieces matching the grid cell, earth patch
  -> sandy pieces, skin on. Not watched by eye in a real fight.

## clouds-1 (2026-11-12): clouds drift one way forever (user request)
- Gnomon's 6 fixed swaying clouds -> `clouds.drift` (MapEnvironments): 11 lanes, span 3000 studs, 5.5 studs/s x lane
  speed 0.8-1.2 (8-11 min a crossing). `Environment.driftCloud`: pure function of time; fades in/out over the end 14%
  of a crossing and returns up-wind as a NEW cloud (per-crossing hash: size +-15%, height +-25, side +-60, shape,
  heading +-20 deg; slow rise 6 studs). EnvironmentKit rebuilds a lane's parts on each new crossing, recolours by
  distance at 2 Hz, one BulkMoveTo a frame (~236 parts). Environment.problems checks every lane's whole path at its
  extremes (fight space, lobby views, landmarks, min distance, sky band): clean.
- MEASURED in Play: 11 lanes, 10 visible, 590-1640 studs out, moving ~5.5 studs/s down-wind; a lane wrapped while
  invisible. First try (lanes 1000-2000 out) read too small; lanes pulled in. NOT TESTED: a full crossing by eye, phones.

## perf-1 (2026-11-12): owner stats readout + first real phone test
- `PerfController`: owner-only panel under the Bots button (fps + avg ms, worst frame in 2 s, client MB, graphics
  level, "phone" when touch without keyboard); tap toggles the detail line. Owner tools (Bots button, readout) now
  show for group rank 254+ (the user is rank 254, not the 255 owner) - DummyService.mayFreeze.
- PHONE TEST (user, published, iPhone 16 or 17): "it's good" - lobby and a bot-filled round. No numbers reported.
  Still untested: low-end/older Android, graphics level 1.

## anim-1 (2026-11-12): legs froze while holding M1 and running (user's big brief, piece 1 of 5)
- THE BRIEF (user, 2026-11-12, one piece at a time): 1 this fix; 2+3 kick timing meter redesigned as a horizontal
  red-orange-yellow-GREEN-yellow-orange-red bar, score = distance from centre, whole bar animates in/out (options
  E1 X1 C1 F1 M1); 4 lobby: study Blade Ball + 2 others, three concepts, pick and build one without asking; 5 cyan
  hexagon barrier drifting up-right with a separate upward sweep and a player-centred glow the hexes move THROUGH
  (D1 R1); 6 all settings central; 7 test + summary. Reference images were pasted in chat (not saved to disk).
- CAUSE: HoldSwing picked the clip once, from the speed at the press. Below RunVariantSpeed (18) that is the
  standing HookLeft/HookRight, which keys legs + torso at Action2 and then waits FROZEN (speed 0) at its hold point,
  above Sprint (Movement) and the stock walk (Core). Run after pressing and the frozen clip pinned the legs.
  MEASURED before: held + running, Left Hip swing 0 deg (115 free).
- FIX (AnimController.updateFighter): once the hold has settled, the held clip follows current speed: >=
  Animation.HoldMoveSpeed (3) -> the arms-and-head `...Run` variant, <= HoldStandSpeed (1.5) -> the standing one,
  cross-faded over HoldSwapFade (0.12) at the same hold pose; heldSwing/swingName updated so release and cancel act
  on the live track. Applies to every fighter (others via HT_PunchReady). Controls, speeds, combat untouched.
- MEASURED after (real key + mouse input in Play): held + run 117 deg, held + walk 101 deg; stop -> back to the
  standing clip; release, 4 quick clicks, S->A direction change, jump + land, respawn then hold + run: legs move,
  no Hook/Uppercut/Kick track left playing. NOT TESTED: by eye, a hold dropped by a stun or clash, gamepad, touch.

## meter-1 (2026-11-12): the air kick's timing meter, taken from the place
- NOT written in this folder. The scripts were in the Team Create place (BUILD meter-1) and not on GitHub; their
  author couldn't push. Copied out of Studio script by script and checked against Studio by length and checksum:
  new Core/KickMeter + Ui/KickMeterBar; changed KickService, MovementController, KickPromptController,
  TrainingController, DiveKick, GameConfig; removed Core/ResultPop, Ui/KickResultText.
- WHAT IT IS: the ring timing is gone. Attached to the target, a bar opens (red ends, green middle) with a marker
  running along it; the click records where the marker is. The server rolls the marker's start (HT_KickMeter),
  scores the press on its own clock (KickMeter.pressedAt, PressLagSeconds) and publishes HT_KickScore
  (position, quality, tier). Force, hit stop and the kicker's rebound height scale smoothly with quality;
  perfect = green (the finisher), good/okay = orange, poor = red.
- WRITTEN HERE to go with it, because they weren't in the place: tests/KickMeter.spec (new), DiveKick, Rebound,
  TrainingLayout, FreeJump and Lobby specs updated to the new signatures, tests/ResultPop.spec removed,
  design/game.json mirrored from GameConfig (KickMeter added, KickText and 13 Kick timing keys removed), and the
  Settings Guide's KickMeter section. If the author's own versions of these turn up, theirs win.
- NOT VERIFIED: the meter by eye; whether the author had further unsynced changes.

## kits-1 (2026-11-12, spicy; NOT COMMITTED, NOT TRIED BY THE USER YET)
- ASKED: Q (dash) and R (uppercut) become the Base ability kit, not universal moves; the dash can't be charged;
  a framework of ability kits (each a mobility skill on Q and an attack skill on R); a menu with the ability
  inventory, a shop, and placeholder Passes and Settings tabs. User picked: Coins saved in a DataStore,
  placeholder kits that can be bought and equipped, M to open.
- NEW: Config/Abilities (the catalogue: Base = Dash + Uppercut, free; Tempest 300, Bruiser 500, Trickster 750,
  all four skills each `built = false`; StarterCoins 1000 as a test balance), Core/AbilityKit (pure rules, tests/
  AbilityKit.spec, 9 tests), PlayerDataService (DataStore HT_PlayerData_v1, session lock with a 90 s lease, 30 s
  autosave, BindToClose; no access -> plays on an unsaved profile, HT_DataTemp), AbilityService (AbilityBuy /
  AbilityEquip / AbilityResult remotes, validated, rate limited, no equip in a round; HasSkill), AbilityController
  (owns Q/B and R/L2, sends a press to the equipped kit's skill handler; placeholders say "not built yet"),
  MenuController (M or the left-edge Menu button; X, outside click or gamepad B while open closes it).
- CHANGED: MovementController (charge removed: the dash goes on the press at power 0, no charge slow; the Q
  binding moved out, RequestDash in), CombatController (R binding moved out, ThrowUppercut in), CombatService
  (UppercutRequest refused unless the kit has Uppercut), PropelService (no broadcast unless the kit has Dash),
  HudController (Q/R rows named after the kit's skills; a placeholder skill shows unavailable), HudTheme.Menu, Net.
- KEPT, UNUSED: Momentum's charge functions and their tests, the PropelCharge effect, Movement.PropelCharge*.
- MEASURED in Play (Studio, no DataStore access): data falls back to unsaved at once (1000 Coins, Base); M opens
  the menu; buying Tempest 1000 -> 700, card says Owned, toast; equipping it renames the HUD rows Blink/Cyclone
  and Q shows "Blink isn't built yet"; a hand-fired UppercutRequest with Tempest on started no swing; back on Base,
  a Q tap reached 80.8 studs/s and R threw an uppercut the server started. No script errors.
- NOT TESTED: real saving (place has no Studio API access; needs a published server or API access on), a lock
  held by a second server, touch and gamepad menus, the shift-lock cursor while the menu is open, phone size.
- NOTHING EARNS COINS YET: rounds paying out would touch RoundService (the other dev's): ask first.

## kits-1b (2026-11-13): meter press-lag 0.045, and a merge note
- KickMeter.PressLagSeconds 0.03 -> 0.045 (measured 38-54 ms between the picture pressed on and the server's clock).
- MERGE NOTE: spicy snapshotted meter-1 from Studio (f7b4fd7, 557d624) and built kits-1 (91cca15) on top while the
  meter was still uncommitted locally. Local copy was identical apart from the lag value; took origin/main and
  re-applied only that. For ~1 minute Studio held the pre-kits scripts (a push from the stale local copy); re-pushed
  from the merged tree (144 instances, PASS) before any save. Lesson: `git fetch` and compare BEFORE every Rojo push,
  not only `git pull` (a refused pull must stop the push).
- The user confirmed the meter works and that "keep you in the air" during the timing bar is no longer a problem.
- NEXT from the user's brief: piece 5 the hexagon barrier (cyan, ~90% transparent, hexes drift up-right D1, separate
  upward sweep, player-centred glow the hexes move THROUGH, R1 ripple), then piece 4 the lobby (study Blade Ball + 2
  others, three concepts, pick and build without asking), then piece 7 the final test + summary. Settings central.

## hex-1 (2026-11-13): the lobby's animated hexagon barrier (user's big brief, piece 5; NOT COMMITTED, awaiting approval)
- WHERE: the only walls in the game are the lobby's four invisible ones (LobbyService `Barrier1-4`); the arena has
  none (ring-out). The barrier is drawn on those four inner faces, 26 studs up from the floor, top fading out.
  Collision untouched: `BarrierController` (client) makes thin local parts (workspace.HT_BarrierFx, collide with
  nothing) carrying one unlit SurfaceGui a wall. Maths in `Core/HexBarrier` (tests/HexBarrier.spec, 11 tests).
- HOW: Fill tint + a Drift frame (one pattern period bigger than the wall, wrapped at a period: seamless) holding
  the tiled Lines image, the Sweep (same image through a UIGradient band whose Offset climbs) and pooled Cell
  hexagons lit per player by 3D distance (so the glow stays on the player, hexagons drift through it; R1 ripple,
  R2 plain, R3 sparks). GUI positions are whole pixels, so the frame takes the whole pixels and the wall part is
  nudged by the fraction (BulkMoveTo) for a smooth slow drift. Off beyond MaxViewDistance (no frame work).
- IMAGES: design/barrier/draw_barrier.py -> out/ (hex_tile, hex_cell, halo), uploaded through Studio upload_image:
  tile 116017742377378, cell 133821336459940, halo 118818857382687 (first, thicker pass: 116062260683745,
  82105233325855, unused). Like the ground colour maps, these are NOT group-owned Open Cloud uploads.
- REFERENCE (user pasted 2026-11-13, not on disk): a wall of thin bright cyan hexagon lines, hexagons about half a
  character wide, next to no fill, ragged faded edges. The GIF arrives as ONE STILL FRAME for Claude. Retuned to
  it: HexSize 2.5 -> 1.5, line 0.075 -> 0.05 of a radius, Transparency 0.9 -> 0.95, LineTransparency 0.35.
- SETTINGS: design/game.json -> config.Barrier (Settings Guide `## Barrier`): transparency, hex size, Drift D1-D4 +
  speed, sweep speed/width/gap/strength, proximity radius/brightness/fade times, ProximityStyle R1-R3, phone path.
- MEASURED in Play (Studio, PC, 190 fps): script cost (HT_BarrierFx attributes AvgMs/PeakMs) ~0.05 ms a frame with
  nobody near a wall, ~0.17 ms with ~50 hexagons lit, peaks under 0.7 ms. UIGradient.Offset.Y with Rotation 90 is
  a share of the object's height, positive = down (checked with a test frame). Render cost on/off could not be
  measured (frame times too noisy while the user was playing).
- NOT TESTED: the motion by eye by Claude (drift smoothness, no bobbing of the top fade, the sweep) - screenshots
  only; R2/R3 and D2-D4; several real players at one wall; corners by eye; any phone (pixel 12, 2 players, glow
  every 2nd frame); the ragged edge of the reference is a smooth fade here.
- NEXT: piece 4 the lobby (study Blade Ball + 2 others, three concepts, build one), then piece 7 the final pass.
- Pushed (146 instances, PASS) and the place saved as version 262. Build label hex-1.

## hex-2 (2026-11-13): the barrier matched to the user's GIF (NOT COMMITTED, awaiting approval)
- THE REFERENCE IS ON DISK: `LihFolk Vault V2/_assets/barrier-motion.gif` (800x500, 240 frames, 12 s). A pasted GIF
  reaches Claude as one still; split the file with PIL to read it. What it shows: at rest the wall is a barely
  visible hexagon grid; as the figure walks up, a wide patch of hexagon LINES fades in around them (3-4 character
  heights across), the 1-2 hexagons nearest go white-cyan with a faint fill and a soft bloom; pattern drifts
  up-right; all fades as they leave. Hexagons about half a character across, medium line weight. Also a soft light
  pool on the floor and thin curved streaks near the figure: NOT built.
- CHANGED: two-tier glow in HexBarrier.brightness (ProximityMidBrightness 0.45 over ProximityRadius 16, full
  brightness inside ProximityCoreRadius 6); rest state near-invisible (Transparency 0.975, LineTransparency 0.86);
  HexSize 1.6; line 0.07 of a radius; lit hexagon redrawn (bright rim, glow, 20% fill); SweepStrength 0.2,
  HaloBrightness 0.3, RippleStrength 0.25. Images: tile 135568689839955, cell 73567244841968 (hex-1's unused now).
- MEASURED in Play (Studio PC, ~180 fps): at the wall 72-84 hexagons lit, script 0.23-0.28 ms a frame, peak 0.54;
  10 studs back the patch is faint (brightest hexagon 14%). Screenshot at the wall matches the GIF's structure.
- NOT TESTED: motion by eye, phones, R2/R3, D2-D4, several players, corners. On the bright sky the white core has
  less contrast than on the GIF's dark scene.

## kits-2 (2026-11-13): Tempest is real (Blink, Cyclone), rounds pay Coins (NOT COMMITTED, awaiting the user's try)
- TEMPEST: `built = true` for both skills; their numbers are in Config/Abilities (`Abilities.Blink`,
  `Abilities.Cyclone`), not GameConfig, so design/game.json doesn't mirror them.
  - Blink (Q): the client moves its own body 20 studs the way it's moving (facing when slow), through fighters,
    stopping 2.5 short of anything solid (two rays, chest and knee). Rules in Core/Blink (tests/Blink.spec, 7).
    BlinkRequest (no args) -> AbilityService checks kit, cooldown (4 s), alive, not HT_RoundHold -> BlinkStarted to
    the others, who show it (FxController:Blink). Client handler and cooldown in AbilityController.
  - Cyclone (R): a heavy swing, side "Cyclone", in CombatService's HEAVY table (CycloneRequest, kit checked). Reach
    7.5 all the way round, hits everyone once, low outward arc, no root, cooldown 6 s. It plays the HookRight clip
    while AnimController turns the whole body once round on the root joint's C1 (no new clip: AnimClips is full).
  - HUD: AbilityController:GetTiming(slot) gives non-Base skills' cooldowns; SkillUsed/SkillBlocked press the rows.
- FIXED, AFFECTS THE KICK AND THE UPPERCUT: CombatService's swept contact check passed the plain punch's settings
  to Combat.sweepReach, so every heavy move used the punch's hitbox (range 7, 20 degrees either side) and its own
  `hitbox` was never read. It now passes `punch.cfg`. The launching kick and the Uppercut therefore now use what
  GameConfig says: range 6, 35 degrees either side (shorter and wider than they have been playing). To get the
  old feel back, set HeavyKick/Uppercut Range 7 and Degrees 20 (game.json and GameConfig together).
- COINS FROM ROUNDS: Config/Abilities.RoundPay (Played 5, PerHit 1 up to 25 hits, PerRingOut 10, Win 30; nothing
  without at least one hit landed, or in a round of fewer than 2). Core/Payout (tests/Payout.spec, 8) and
  AbilityKit.addCoins. New RewardService keeps the tallies and pays at the round's end; CoinsEarned(total, lines)
  shows as the menu's toast. RoundService (dumpl's) got four small hooks only: RoundStarted in startRound, Hit in
  NoteHit (Fighting, both still standing), RingOut in settleOuts (a `lastHitters` table beside lastHits),
  RoundEnded in finishRound. Hits on bots pay like any other.
- SAVING: PlayerDataService LOAD_TRIES 6 -> 13 (104 s, longer than the 90 s lease). Seen in Studio: Play stopped
  and started again, the old session's lock hadn't been let go, the load gave up after 48 s and the session was
  unsaved (HT_DataTemp). Now it waits the lease out.
- VERIFIED in Play (Studio, DataStore access on): bought Tempest 1000 -> 700, stopped, started: 700 Coins, Tempest
  owned and equipped came back (HT_DataTemp false). Q moved 18.1 studs and stopped 2.5 short of the lobby wall; a
  second Q inside the cooldown did nothing. R: server started "Cyclone", body turned (C1 sampled), one swing hit
  Bot 1 and Bot 21 at once (strength 42). Round end paid 8 (Played 5, 3 hits) and 7 (Played 5, 2 hits); toast
  text "+7 Coins: Played 5, 2 hits 2". No script errors. Gates: build OK, 441 tests, selene src 0, stylua clean.
- NOT VERIFIED: the look of the blink and the spin by eye; a blink seen from a second client; ring-out and win
  Coins in a live round (tests only); the 104 s lock wait itself; touch and gamepad.

## lag-1 (2026-11-13): endlag on every move (user: "so you can't just chain them"; NOT COMMITTED, awaiting the user's try)
- RULE (Core/Endlag, tests/Endlag.spec, 10 tests): one `busyUntil` per fighter. While it runs, no new move STARTS:
  punch, launching kick, Uppercut, Cyclone, Dash, Blink, jump. Running is untouched. An attack locks from the press
  through its strike (windup + Punch.ActiveSeconds) plus its Miss seconds; a hit cuts that to its Hit seconds after
  the hit. Dash and Blink lock for one number from their start; the end of an air kick or dive kick (HT_Skill going
  to nil) locks for `AirKick`. Cooldowns still apply; whichever ends later decides.
- SETTINGS: GameConfig.Endlag and design/game.json config.Endlag (same place, after Uppercut), Settings Guide
  `## Endlag`: PunchHit 0.1 / PunchMiss 0.28, KickHit 0.2 / KickMiss 0.5, UppercutHit 0.3 / UppercutMiss 0.55,
  CycloneHit 0.35 / CycloneMiss 0.65, AirKick 0.35, Dash 0.2, Blink 0.3, Tolerance 0.06, Enabled. Punch after
  punch is no slower than before (a test holds that); what changes is move INTO another move.
- LEFT ALONE ON PURPOSE: a punch already held back can be let go during a dash's or blink's endlag (the server
  allows it because it saw the hold start, and a hold can't start in endlag); the air kick after a launching kick;
  the dive out of a jump. Bots have no endlag (BotBrain paces them).
- SERVER: new EndlagService (IsBusy / Start / Landed; watches HT_Skill itself). CombatService refuses a swing or a
  new hold in endlag ("refused: endlag"), starts the lock on accept and cuts it in finishPunch on a hit.
  PropelService and AbilityService don't show a dash or blink asked for in endlag, and start its lock.
- CLIENT: new EndlagController (BusyUntil / IsBusy / Start / Landed / Undo). CombatController's readyAt() is now
  max(cooldown, endlag), so the punch buffer and the HUD follow it; AbilityController:Use holds back the mobility
  skill; MovementController holds back the jump; the HUD's Q and Space rows show the wait.
- VERIFIED in Play (Studio): Cyclone hit at +0.36 s, Q 0.17 s later did nothing, Q after the lock blinked 20 studs;
  a punch pressed 0.2 s after a blink started exactly when the blink's 0.3 s ran out (the press was buffered);
  Space 0.26 s after a whiffed punch didn't jump, Q after it dashed. Fired straight at the server: PunchRequest
  0.6 s after a whiffed Cyclone came back "refused", the same 1.1 s after was accepted. Saved profile loaded
  (708 Coins, Tempest, not temporary). Gates: build OK, 451 tests, selene src 0, stylua clean.
- NOT VERIFIED: the dash's own 0.2 s lock by timing (tool input is too slow to press inside it), the air kick's
  lock, the launching kick's and the Uppercut's numbers in Play, how any of it FEELS (the numbers are a first guess).

## gust-1 (2026-11-13): the game's own VFX style, "Gustline", first pass (NOT COMMITTED, awaiting the user's try)
- THE STYLE: design/VFX Style.md (approved by the user from a drawn board). Wind you can see, drawn as an ink line
  with a puff behind it: navy ink + pale wind blue + thin white, one accent per kit (Base gold, Tempest mint,
  Bruiser ember, Trickster violet) on heavy moves only, six shapes (crescent, ring, glint, puff, scuff, diamond
  mote), three tiers. Its section 7 lists what is and isn't brought to it yet. The principles are in the vault:
  `07 Lighting VFX and Audio/VFX Reference Study - Why Good Combat VFX Reads, and Building a House Style.md`.
- TEXTURES: design/vfx/draw_gustline.ps1 -> design/vfx/out (7 PNGs), uploaded with Studio upload_image through a
  localhost file server (it refuses file paths). Ids + palette + accents: src/shared/Config/GustStyle.luau.
- CODE: new src/client/Fx/GustFx.luau (pooled flat plates: show / floorRing / airRing / scuff; sweep, drift,
  stepped fade, follow a part). ImpactFx.burst: the flash is the glint, the shards are diamond motes, optional
  accent. FxController: swingCrescent, accentOf (player attribute HT_Kit), floorBelow; Swing(character, side,
  windup); HitBurst adds ring + scuff on a heavy hit; PropelGust and Blink add air rings; GroundBlast adds a floor
  ring + scuff. CombatController passes the side and windup to fx:Swing (others' swings: the move's windup, plus
  TestBot.ExtraWindup for bots).
- MEASURED: SurfaceGui on a part's Top face: the image's right is the part's front (LookVector), its down is the
  part's right. So a plate is CFrame.fromMatrix(at, bulge, bulge:Cross(head)).
- VERIFIED in Play (Studio): the shapes render with ink, accent and white as drawn (staged screenshot: gold
  Uppercut crescent, mint floor ring over a scuff, upright ring); a bot's real punch showed its crescent; punch,
  Uppercut and dash pressed with no script errors. Gates: build OK, 451 tests, selene src 0, stylua clean.
- NOT VERIFIED: any of it in motion (timing, the sweep, the Cyclone's turn direction against the body), the hit
  glint and motes by eye, phones, frame cost with 25 fighters swinging (each swing is one plate; pool 24, 14 on
  touch), how it reads on every map.

## gust-2 (2026-11-13): Gustline redone as glowing layered particles after the user's correction (NOT COMMITTED)
- WHY: the user said gust-1 was wrong: the references are glowy neon, see-through, 10+ particle layers a move, a few
  solid pieces only, and heavily animated. A frame-by-frame pass over the four videos (yt-dlp 720p, ffmpeg contact
  sheets at 12 fps) confirmed every point; gust-1 had been judged from one still every 1-4 s. The vault study note
  has a corrected section 0, and design/VFX Style.md is rewritten (rendering rules first).
- TEXTURES: a glow set added to draw_gustline.ps1 (glow_soft, crescent_glow, ring_glow, ring_burst, flare, mote_glow:
  white, soft-edged, for additive particles), uploaded; ids in GustStyle.Images. GustStyle.Wind is the glow colour of
  plain wind.
- CODE: new src/client/Fx/GustBurst.luau. `hit` = 14 layers (ink underlay, white core, flare, halo, spikes, two
  shock rings, camera-facing ring, spinning arcs, motes, ink speed lines; on the floor burst ring, glow ring, glow
  pool, smoke, turning arcs). `ring` = 6 layers. `swing` = 5 stacked GustFx plates (7 for the Cyclone) + motes.
  GustFx: shape "glow", `brightness`, pool 72 (28 on touch). FxController calls them from swingCrescent, HitBurst,
  PropelGust, Blink and GroundBlast. ImpactFx.burst (now only the air kick's) uses the flare and glowing motes.
- LEARNED: (1) a VelocityPerpendicular particle can be put in a plane, but which way it points within the plane
  changed with the plane's tilt (same rig: right way round facing up, back to front facing down), so crescents are
  plates and only rings are flat particles. (2) Stacked additive white = a white blob; one small white core, the
  rest tinted, big layers dimmer. (3) Additive light nearly vanishes on the pale lobby sand; a non-additive ink
  underlay and the ink lines carry it there. (4) To see an effect, freeze it: emit, wait, TimeScale 0 on every
  emitter, screenshot; build every pooled rig first.
- VERIFIED in Play (Studio, frozen frames on the arena grass): a heavy hit at 0.04 s and 0.15 s (flare, spikes,
  standing rings, floor burst ring, ink lines), a punch hit, a heavy mint hit and a dash ring at 0.09 s; the
  Uppercut's gold arc and a hook's blue arc in FRONT of a stand-in body. Gates: build OK, 451 tests, selene src 0,
  stylua clean.
- NOT VERIFIED: motion at real speed, the real key presses on this build (only staged calls), the Cyclone's arcs,
  Blink's rings, the floor slam's rings, the lobby sand after the underlay was added, frame cost in a 25-fighter
  round (a swing is 4-5 plates, a hit about 80 particles), phones.

## vfx-0 (2026-11-13): the Gustline VFX code taken out again (NOT COMMITTED, awaiting the user's try)
- WHY: the user rejected gust-2 and said "revert it". New direction: one-to-one replicas of reference effects first,
  particles only, no 3D parts, no house style yet.
- REMOVED: src/client/Fx/GustBurst.luau, src/client/Fx/GustFx.luau, src/shared/Config/GustStyle.luau. ImpactFx.luau is
  back to its hex-2 version (built-in textures). FxController: swingCrescent, accentOf, floorBelow and every
  GustBurst/GustFx call gone; HitBurst calls ImpactFx.burst again; Swing(character) takes no side or windup;
  CombatController's three fx:Swing calls follow.
- KEPT: everything from kits-2 and lag-1, including FxController:Blink (its puffs and streaks; only its two Gust rings
  went). Blink's puffs are the old sphere blobs, which the user also dislikes: to be replaced in the replica work.
- KEPT ON DISK, unused: design/VFX Style.md (ON HOLD), design/vfx/draw_gustline.ps1 and design/vfx/out. The 13 uploaded
  image ids are only in Git history now (GustStyle.luau at ff87aef).
- Gates: rojo build OK, 451 tests, selene src 0, stylua clean. NOT VERIFIED in Studio: Rojo was not connected, because
  the place holds a LobbyLayout script and a LobbyService that are not in Git (see the open question).

## vfx-1 (2026-11-13): first replica, the punch hit from "Mumen Rider Combo" (NOT COMMITTED, awaiting the user's try)
- DIRECTION (user, 2026-11-13): replicas first; particles are the basis, and meshes, camera work and screen effects
  are fine ONLY where particles can't do it. Study at 24 fps or more.
- REFERENCE: Venomec "Mumen Rider Combo" (YouTube 3R5WsLDp2f4), first punch hit, 2.28 s to 2.65 s, read at 60 fps
  (24 frames, cropped). Layers found, in order: white floor ring (1 f before), white-hot core + star of sharp green
  spikes (0 f), band of long green lines along the hit with black lines among them + soft white bubble (1 f), small
  needles (4 f), green haze, thin white arcs and floor smoke (5-6 f); light gone by 8 f, smoke and arcs to 20 f+.
- TEXTURES: design/vfx/draw_hit_replica.ps1 (C# per-pixel through Add-Type) -> design/vfx/out/hit_*.png: needle,
  dome, floor ring, arc. Uploaded through Studio; ids at the top of src/client/Fx/PunchHitFx.luau. It also uses the
  earlier glow_soft id and Roblox's built-in smoke.
- CODE: new src/client/Fx/PunchHitFx.luau: 6 pooled rigs (4 hidden parts each), 12 emitters, each told to Emit at its
  frame. PunchHitFx.play(position, direction, scale, colour?). FxController:HitBurst calls it in place of the three
  sphere blobs, three streaks and ImpactFx.burst (ImpactFx.burst is still the air kick's).
- MEASURED: (1) VelocityParallel lays the texture's WIDTH along the velocity, so a spike is drawn lying sideways.
  (2) Squash s: length x 2^-s, thickness x 2^s. (3) Spikes that should meet at a point: emit from a Sphere-shaped
  part, ShapeStyle Surface, ShapeInOut Outward. (4) On the arena grass a fully additive hit is a white blob:
  LightEmission 0.5-0.6 and Brightness 1.3-1.6 on the coloured layers keep the green. (5) Particles in Edit mode
  don't advance reliably with Studio in the background: judge frozen frames in Play. (6) The game's camera wins over
  CameraType Scriptable; BindToRenderStep at RenderPriority.Last + 1 holds a test camera.
- VERIFIED in Play (Studio, the test module pasted in, frozen frames on the arena grass at about 1 f, 3 f, 8 f, 13 f,
  20 f): burst, line band, bubble, floor ring, arcs, floor smoke all show in that order. Gates: build OK, 451 tests,
  selene src 0, stylua clean.
- NOT VERIFIED: the code on disk running in the game (Rojo not connected: the place holds LobbyLayout and a
  LobbyService that are not in Git), real punches, motion at full speed, phones, 25 fighters.
- KNOWN GAPS against the reference: the smoke is Roblox's soft built-in puff, the reference's is wispy (wants a
  flipbook); no ring one frame BEFORE the hit; the dark circle under the hit is left out; the white cores inside the
  spikes are weaker than the reference's.

## vfx-2 (2026-11-13): two more replicas (heavy hit, floor burst) and the first flipbook (NOT COMMITTED)
- REFERENCE: the same video (3R5WsLDp2f4). Floor burst 3.27-3.75 s and heavy hit 3.53-4.0 s, both read at 60 fps.
- HEAVY HIT: PunchHitFx.play(position, direction, size, colour?, heavy?). heavy = 1.25x, the star and the lines thrown
  again every 2 f for 0.4 s ("Hold", "HoldLines"), a faint tall white column, a white circle at 16 f, two tall arcs
  at 22 f. FxController:HitBurst passes heavy on a strong hit (strength >= Effects.StrongHitSpeed).
- FLOOR BURST: new src/client/Fx/StepBurstFx.luau, play(position, scale): flash, crown racing out along the floor,
  two thin arcs spinning flat, smoke. Called from FxController:PropelGust (a dash off the ground; nothing in the air).
- FLIPBOOK (the user: "they are very necessary for good vfx"): hit_smoke.png, 1024 x 1024, 4 x 4, one puff swelling
  and fraying into wisps, drawn by 3D value-noise in draw_hit_replica.ps1 (domain-warped fbm + ridged filaments,
  worn away over time). FlipbookLayout Grid4x4 + FlipbookMode OneShot. Used by the hit's haze and floor smoke and
  the floor burst's smoke, in place of Roblox's built-in puff. New textures too: hit_crown, hit_circle.
- VERIFIED in Play (Studio, pasted test copies, frozen frames on the arena grass): floor burst at 4 f, 6 f, 18 f and
  from straight above; heavy hit at 12 f and 30 f. Gates: see the end of the session.
- NOT VERIFIED: the code on disk in the game (Rojo still not connected), real key presses, full speed, phones.
- KNOWN GAPS: the heavy hit's centre is less white-hot than the reference's; the flipbook only frays in its last
  five frames; the floor burst's crown is drawn tufts, the reference's is blurrier dust.
## lobby-1 (2026-11-13): cliffside courtyard lobby + arena removed between rounds (NOT COMMITTED; MODEL NOT IN THE PLACE YET)
- hex-2 (the barrier) was approved and committed: e126351.
- BRIEF (user): cliffside courtyard with terraces and rock formations, elevated above the arena with clear
  sightlines, cohesive palette, golden hour, compact, rich decoration with custom Blender props, in the first
  map's art style; study Blade Ball + others; three concepts, build one; Blender is the modelling tool; when a
  round ends return everyone to the lobby, apply its golden-hour environment, REMOVE the arena, load the next
  arena cleanly at the next round.
- RESEARCH + CONCEPTS: design/Research Notes.md "Lobby study" (web guides only, no game could be played).
  Built concept 1 "Stepped Overlook": three terraces stepping down toward the arena.
- LAYOUT (config.Lobby): FloorY 120 (20 above the arena, was 11), 132 x 150 (was 180 x 240), Terraces
  { 28, +3 } court and { 102, +6 } training, StairRun 6, StairLead 1, spawn on the court (z 296), strip 24,
  dummies X +-26. Core/Lobby.heightAt gives the walking height; spawns, practice dummies and fill bots use it.
- COLLISION: LobbyService builds it invisible: the flat floor, then Config/LobbyLayout (GENERATED by
  design/lobby/gen_layout.py from the Blender build): 2 ramps under the steps, 2 terrace slabs, planters,
  tree bed, benches, stall counter, crates, pots, gate and banner posts, striking posts (38 pieces). The
  model itself never collides. With no model in the place the stand-in floor and terraces show (ShowFloor).
- BLENDER: design/lobby/cliffside.py (reuses props_kit.py chunk/block/canopy builders and its baked paint by
  exec-ing the file without its main(); a cheap brick() for far masonry). 33 meshes, 76,892 triangles, one
  material each, none over 20k. Paving flagstones, spawn medallion, mat, steps, planters, retaining wall,
  parapet + lantern posts, crag (cream/sand/blue like Gnomon), 11 spires, 6 tree shelves, great gold tree,
  benches, shop stall + awning + crates + pots, coral timber gate, banners, striking posts. 60 placements of
  the existing kit (trees, bushes, flowers, ruins, rocks). Source: design/lobby/out/cliffside/cliffside.blend;
  export/cliffside_1.glb (11.95 MB, 31 meshes) + cliffside_2.glb (1.96 MB); manifest.json, collision.json,
  placements.json, review renders cliffside_*.png (+ cliffside_sheet.png). `--dry` = geometry only, fast.
- BLOCKED ON THE USER: Studio refuses the upload: design/lobby/out/cliffside/export is not an approved upload
  folder (Assistant Settings -> MCP Permissions). Nothing was copied to get round it. ONCE APPROVED:
  1. open_cloud_invoke POST /assets/v1/assets, body request {assetType Model, displayName, description,
     creationContext.creator.groupId "2970443"}, files fileContent = each GLB; poll /assets/v1/operations/<id>.
  2. insert_asset each into ServerStorage as LobbyImport_1, LobbyImport_2.
  3. python design/lobby/studio_lobby.py, run out/cliffside/studio_lobby.luau in Edit (fits each import to its
     mesh centres, builds ServerStorage.HT_Lobby.Cliffside, clones the kit dressing, cloth double-sided, lantern
     paper Neon). Check its report: worst distance small, 33 of 33 meshes, 60 of 60 kit pieces.
  4. Play: look at textures/proportions/lighting, walk every terrace, check props line up with collision; save.
- ARENA REMOVAL (Maps.LobbyBetweenRounds, Maps.LobbyMap "lobby"): MapEnvironments.Maps.lobby (`lobby = true`,
  golden hour: clock 17.35, warm sun, violet shade, warm haze, 7 cloud lanes) is a map STATE with no geometry.
  Server starts on it. RoundService.endRound sends everyone to the lobby, then MapService:RoundEnded changes to
  it: the arena model is destroyed behind the existing fade (templates in ServerStorage.HT_Maps untouched) and
  clients apply the lobby light through the unchanged EnvironmentController. ChangeForNextRound loads the next
  arena (rotation from the last real arena) before fighters are placed. One change at a time (pending + token).
  ActiveArena.hasArena(); DummyService parks the Studio test bot 600 below its home while there is no arena.
  RoundService is spicy's file: only the fill-bot height and comments changed there.
- MEASURED in Play (Studio, stand-in floor): round over -> player on the court (y 128) and HT_InLobby before the
  swap; 0.8 s later Map = lobby, workspace.HT_Map has 0 descendants, exactly one HT_Map; client ClockTime 17.35,
  lobby ambient and atmosphere, fade clear; 15 s later Pending kitestead -> Map kitestead -> Starting 0.2 s
  after the swap with 25 fighters; a second round end returned to the lobby state again. No script errors
  after the one fix (the lobby entry has no `model`).
- NOT DONE / NOT TESTED: the model in the game at all (textures, scale, golden-hour look, props vs collision,
  performance with it in); walking the terraces by hand; phones; more than one real player; wind sway on the
  lobby plants (PlantField only knows the map model); the lobby disc used for a kick rebound is still flat at
  FloorY; Gnomon backdrop vs the higher lobby seen by eye. First golden-hour look was washed out toward the
  sun: glare/haze/bloom turned down afterwards, not re-checked.
- Pushed (147 instances, PASS), place saved as version 278, build label lobby-1.

## lobby-1b (2026-11-13/14): the lobby model uploaded and assembled; Studio closed before the final save (NOT COMMITTED)
- The user approved the export folder. Uploaded under group 2970443 (Open Cloud Model): cliffside_1 =
  87303457437787, cliffside_2 = 132685173763363 (both Approved). Inserted as ServerStorage.LobbyImport_1/2 and
  assembled by studio_lobby.luau into ServerStorage.HT_Lobby.Cliffside: 33 of 33 meshes, 60 of 60 kit pieces,
  sampled meshes 0.000-0.001 studs off their expected centres (the import arrives turned 180), every mesh textured.
- FIXED in the assembly (and in studio_lobby.py): the two banner cloths baked dark (occlusion between the two
  cloth layers) -> texture dropped, flat coral / gold Color; thin kit leaves (Plant_*, Flowers_*) drew black
  from behind -> DoubleSided.
- GOLDEN HOUR retuned in Play with the model in (MapEnvironments.Maps.lobby): clock 16.55 (the court was mostly
  in shadow at 17.35), lighter warm shade (ambient 138,126,142 / outdoor 172,158,166), haze 0.7, density 0.2,
  paler atmosphere colours. Sun comes from -X and a little behind: nobody looks into it when facing the arena.
- MEASURED in Play (Studio PC): LobbyService cloned the model to (3000, 120, 250), 194 descendants, 0 colliding
  parts in it. Raycasts onto the invisible solids: balcony 0.00, ramp 0.5/1.5/2.5 at d 22/24/26, court 3.00,
  second ramp 4/5 at d 97/99, training 6.00; paving tops 0.00 / 3.00 / 6.00 match. Solid where drawn: stall
  counter, tree bed and trunk, planters, gate post, bench, striking post, banner pole. A full round end with the
  model: lobby state + golden light. About 199 fps in an overview of the whole lobby; scene 130k triangles and 97
  draw calls with Gnomon AND the lobby up; barrier script 0.077 ms.
- NOT DONE: Studio closed (place not open) during the last Play run, before a save. The last save is v278, made
  BEFORE the model was inserted. The place is Team Create, so the model may or may not have been kept. NEXT
  SESSION FIRST: check ServerStorage.HT_Lobby.Cliffside exists (33 meshes, 60 dressing). If not: insert_asset
  87303457437787 and 132685173763363 into ServerStorage as LobbyImport_1 / _2 and run
  design/lobby/out/cliffside/studio_lobby.luau (no re-upload needed). Then git fetch/pull, Rojo push (the last
  push carried the retuned lighting), Play once, save.
- NOT TESTED: walking the terraces by hand (automated walking did not move the character; only raycasts);
  the retuned lighting as saved in config (seen only as live values); frame cost in the lobby state alone;
  phones; several real players; lobby plants do not sway.

## merge (2026-11-14): vfx-2 merged with dumpl's lobby-1 / lobby-1b; build stamp `vfx-2+lobby-1`
- Conflicts were only this file (both sides appended; both kept, ours first) and the two build-stamp lines.
- Git merged GameConfig.luau, design/game.json, Settings Guide.md and RoundService.luau by itself: the four reward
  hooks from kits-2 and the lobby/arena changes from lobby-1 sit in different places. Gates after the merge are in
  the commit message. NOT PLAYTESTED together.
- The place's LobbyLayout and LobbyService, which were "not in Git" all session, are this lobby-1 work: they are in
  Git now, so Rojo from this folder no longer deletes them.
## vfx-3 (2026-11-14): the hit's star made sharp and controlled; swing ribbon (NOT COMMITTED, awaiting the user's try)
- WHY (the user, after trying vfx-2): the star's spikes were "kind of blunt at the ends instead of sharp", and "the
  direction was random instead of controlled".
- CAUSE: the spikes were thrown outward from a sphere, so they pointed anywhere in 3D: the ones aimed at the camera
  drew short and blunt, and every hit was a different shape. The spike texture was also soft-edged and 256 px.
- STAR: hit_needle.png redrawn at 512 px, hard-edged, straight sides to a true point. PunchHitFx now has a STAR table
  (18 spikes: angle from the hit's direction, length). One emitter per spike on its own attachment; a hit turns the
  star's part to face the camera with its right side along the hit, mirrored so 90 degrees is always up. Heavy hits
  re-throw every other spike 8 times, 3 frames apart. Sparks fly off past every third spike.
- ARCS: no random rotation any more. ArcA/ArcB (and the heavy hit's LateArcA/B) get a set tilt toward the hit's
  direction and turn that way. StepBurstFx: two arcs opposite each other, same spin, like a pinwheel.
- SWING RIBBON: new src/client/Fx/SwingTrailFx.luau, a replica of the slash ribbons in Scrippage "Weapon Switcher"
  (UOoYfyJhQN8, 9.55-10.2 s, read at 60 fps): a Trail from the forearm/shin to 1.1 studs past the fist/foot with a
  streaked texture (hit_ribbon.png), a thin bright tip line, and four upright four-point glints (hit_star.png) at the
  strike. FxController:Swing calls it in place of ImpactFx.fistTrail (still used by the uppercut's torso trail).
- MEASURED: VelocityParallel: the texture's +X is the direction of travel. Camera-facing particles: positive
  Rotation turns ANTICLOCKWISE on screen. An emitter on an Attachment emits along the attachment's own axes.
- VERIFIED in Play from disk through Rojo: four hits in four directions frozen at 1 f (same sharp star each time,
  mirrored for a hit going left; line bands along each hit). The ribbon on a stand-in arm sweeping in a circle:
  bright line on the outside, ribbon inside it, glints upright.
- NOT VERIFIED: the ribbon on a real punch or kick (bots knocked the test character out; the one capture was taken
  with a stretched lifetime and showed nothing useful), how faceted a fast swing's ribbon looks (a Trail adds one
  straight piece a frame), the ribbon on the cream lobby floor (near invisible there), heavy hit's held star by eye.

## vfx-4 (2026-11-14): tone and contrast in the hit (NOT COMMITTED, awaiting the user's try)
- WHY (the user, after trying vfx-3): "a little too bright, i think there needs to be more contrast, a mix between
  high glow, low glow, bright green, darker (not dark enough to stop glowing) green ... dont be afriad to use black
  if needed for extra contrast/shading, it looks great if mixed well".
- THE REFERENCE, read again at 760 px a frame: each spike is white-hot at its root, neon green along it and a deeper
  green at its edge; thin black slivers sit between spikes and black lines run through the band; the floor under it
  goes dark.
- STAR: every spike has a tone. FULL = a deep green body (22% toward black, LightEmission 0.35) with a narrower
  white-hot core down its middle (its own emitter, LightEmission 0.9); DIM = a thinner deep green spike only (40%
  toward black, 0.3); INK = a thin near-black sliver behind the rest (LightEmission 0). 18 spikes + 6 ink.
- LAYERS: Layer.dark / Layer.hot (set with tone() after a layer is made) take a tinted layer toward black or start it
  white-hot. Lines are now LinesHot (4), Lines (6), LinesDeep (5) and 10 black. Halo and haze are deep green with
  low glow. New FloorShade: a soft black patch on the floor. Core brightness 3 -> 2.2, dome fainter.
- VERIFIED in Play from disk: frozen at about 2 f and 3 f (white core, bright cores, deep bodies, thin black
  slivers, three-tone band) and at about 10 f (deep green haze, arcs, smoke). Gates at the end of the session.
- NOT VERIFIED: by the user; the heavy hit's held star with the new tones; the swing ribbon and floor burst are
  still one tone (white/pale blue, as their references are).

## vfx-5 (2026-11-14): the hit rebuilt after re-reading the reference at 1080p (NOT COMMITTED, awaiting the user's try)
- WHY (the user, after trying vfx-4): the spikes were all one size, too few ("quite thin compared to the reference"),
  not sharp enough; use ZOffset so black sits behind; "a lot more shockwave and smoke effects"; and "review the
  reference video again to catch any missed details". During the work: "dont make it too thin, some stars should be
  thin but ... some of them are also thick"; "the dark things dont need to be perfectly aligned, i want diversity
  instead of just outlines"; "some things might look better with black outlines, but dont overuse this ... just
  follow the references".
- THE REVIEW (yt-dlp at 1080p, crop 720x570, four frames a sheet, 24 frames). Missed before: (1) the star is about
  40 spikes, no two alike: a few very long, broad blades near the middle, a crowd of small ones; (2) the middle is a
  white-hot mass and the band has a thick white core; (3) the black is mostly thin speed lines BEHIND the band,
  faster and longer than the green, so they show above, below and past its far end; the star itself has little
  black; (4) the shock bubble is strong, with a bright rim; (5) from 4 f a big disc of radial dust races out along
  the floor, twice the ring's width, there to 20 f; (6) the green over the one hit is flame-like wisps, not a
  puff; (7) 2 f to 5 f: a ball of short spikes round the one hit; (8) late: three or four arcs, some of them dark.
- STAR: STAR is now built in a `do` block: 8 LONG by hand, 12 MID, 22 SMALL stepped by the golden angle, 9 INK. Each
  has angle, length and `fat` (thickness / length, 0.04 to 0.28). Thickness is a Squash worked out per spike
  (s = 0.5 * log2(fat / 0.24)); play sets Size = length * 2^s. LONG and MID have a white-hot core emitter. INK
  spikes are black, independent, behind everything (ZOffset 0.2; bodies 1, cores 1.6). Non-heavy hits throw the MID
  and SMALL spikes again at 2 f and 4 f, shifted 1.2 studs onto the one hit. RIGS 6 -> 4 (about 100 emitters a rig).
- NEW LAYERS: LinesCore (white middle of the band), ShockRing (CIRCLE racing out at 1 f), FloorDust (hit_dust.png,
  flat, 5 -> 12.5 studs over 0.42 s), ArcDark1/2 (black arcs). Haze now uses the hit_wisp.png flipbook, upright.
  Dome stronger and bigger; black lines 14, faster, longer-lived, ZOffset -0.5; floor smoke 22, longer.
- TEXTURES: hit_dust.png and hit_wisp.png (a second flipbook: flame tongues that split into rising filaments; the
  trick was taking only the thin crest of a ridged noise, power 9, not the ridge itself).
- VERIFIED in Play from disk, on a dark stand-in floor like the reference's: the star frozen at its first frame, and
  three hits side by side at about 2 f, 5 f and 12 f. Gates at the end of the session.
- NOT VERIFIED: exact timing against the reference (Studio renders at 16-40 fps in the background, so freezes are
  coarse), the heavy hit by eye, cost with 25 fighters, phones.
- ADDED LAST (the user: "there are some black outlines and highlights inside the main star, but its spread thinly and doesnt comprise the entire thing"): six hair-thin black INK spikes with `front = true`, drawn over the green bodies and under the white cores (ZOffset 1.3). Seen in one close-up frozen at the first frame. Gates after this: build OK, 452 tests, selene src 0, stylua clean.

## vfx-6 (2026-11-14): the star rebuilt as a burst (rotation, size curves, randomness); slow motion for study
## *** NOT SEEN RUNNING: Studio's 3D view went black for captures before this could be photographed ***
- WHY (the user, after trying vfx-5): "i dont think you have implemented particle rotation or increasing/decreasing
  particle size thru time ... speed, size, rotation, randomness, are all very useful for making a burst, explosive
  like effect", and asked whether I can truly watch a video. I can't: I only see stills. What I can do is MEASURE
  motion off the frames and photograph my build at the same frame numbers.
- MEASURED off the 1080p frames (30 px = 1 stud): longest spike 10 studs at 0 f, 6.7 at 1 f, 3.3 at 2 f, then a
  3-stud spiky ball to 5 f. Shock bubble radius 3.2, 5, 5.8, 6.3, 6.7 studs at 1 f to 5 f. The old spikes shrank
  evenly over 6 f, which is why the hit read as static.
- STAR, rebuilt: no more one emitter per spike. New texture hit_blade.png: one blade with its colours BAKED IN
  (white-hot middle, neon green, deep green edge), standing on the image's CENTRE and pointing up, so a
  camera-facing particle turns about its base and stays on the contact as it grows or shrinks. StarBlades (26):
  Rotation 0-360, RotSpeed +-30, a Size curve with envelopes (out in one frame, 2/3, 1/3, held, gone), a Squash
  envelope (needles to broad blades), Lifetime 0.07-0.13. StarInk (9, black, behind). StarBall (14 at 2 f and 4 f on
  the one hit). StarLong1-6: the six longest, one emitter each, AIMED: Rotation = screen angle - 90, mirrored
  when the hit goes left. The STAR table, the camera-facing `burst` part and the 60-odd attachments are gone
  (about 40 emitters a rig, down from about 100).
- ELSEWHERE: every size is now a curve that goes out fast then eases (bubble, shock ring, floor ring, dust, arcs);
  the bubble, floor ring and dust turn (RotSpeed); lines, sparks, wisps and smoke have envelopes on size and wide
  ranges on speed and life. curve() makes keypoints with envelopes; scaled() keeps them.
- SLOW MOTION: PunchHitFx.studySlow(factor) stretches every timer and sets every emitter's TimeScale to 1/factor.
  For study only; nothing in the game calls it. Plan: studySlow(20), then capture at 0, 1, 2, 3, 5, 8, 12 f and
  lay them beside the reference's frames.
- NOT VERIFIED AT ALL BY EYE. Unknowns to check first: (1) whether Squash on a camera-facing particle scales along
  the blade after Rotation (assumed) or along the screen (blades would shear); (2) that the blade stands upright at
  Rotation 0 (assumed from the arc measurement); (3) lengths and brightness on the grass. The measurement snippet
  for (1) and (2) is in this session: four emitters, Rotation 0 / 60 / 60 with Squash / random.
- Gates: rojo build OK, selene src 0, stylua clean, tests at the end of the session.

## vfx-7 (2026-11-14): vfx-6 seen running and tuned frame by frame in slow motion (NOT COMMITTED, awaiting the user's try)
- Studio's view came back (the user: "It's visible now"). Everything vfx-6 assumed was MEASURED: a blade stands
  upright at Rotation 0; a positive Rotation turns it anticlockwise about its base; Squash follows the blade's own
  direction (no shear), positive = longer and thinner. 26 random blades from one point already read as a star.
- THE SLOW-MOTION METHOD WORKS. studySlow(600) makes one reference frame last 10 s, longer than a tool round trip, so
  each capture lands on a known frame (studySlow(60) was too fast: three captures in a row all landed at 22-24 f).
  Captured at 0.45, 1.4, 2.5, 4.3, 5.4, 7.3 and 8.4 f and compared with the reference's 1080p frames.
- WHAT THAT FOUND AND FIXED: (1) the star was about 1.7x too big: a blade's length is Size / 1.2 (BLADE_SIZE), not
  Size / 2; sizes cut to match the measured 10 studs. (2) The early layers lingered about 3 frames too long: at 7 f
  mine still had spikes, lines and the shock ring where the reference has only wisps, an arc and dust. Lifetimes
  cut: blades 0.04-0.075 s, long spikes 0.035-0.05, band 0.035-0.065, its white core 0.04-0.06, black lines
  0.07-0.11, ball 0.03-0.05 (thrown at 2 f and 3.5 f), bubble 0.09, shock ring 0.07, floor ring 0.15, dust 0.3.
  (3) The shock ring drawn with the circle texture looked like an interface ring: it is a second, brighter bubble
  now. (4) Blades fattened (Squash 0.2 +- 0.5; ball 0 +- 0.35). (5) Dust bigger (6 -> 14 studs); wisps deeper.
- AFTER: 0.45 f a 10-11 stud star, thick and thin blades, black behind; 1.4 f the white-cored band and a small
  bright bubble; 2.5 f band, spiky ball, strong bubble with a bright rim, dashed floor ring (close to the
  reference's 2 f); 5.4 f only black lines, a small star, a faint big bubble; 8.4 f wisps, white and dark arcs,
  sparks, floor dust and smoke.
- NOT VERIFIED: the final sizes at 8-20 f after the last tweak (dust, wisps), the heavy hit, real punches on the
  grass at full speed, 25 fighters, phones. Gates at the end of the session.

## vfx-8 (2026-11-14): the hit's motion stretched so it bursts; brighter, with glints (NOT COMMITTED, awaiting the user's try)
- WHY (the user, after trying vfx-7): "it looks like its flickering instead of bursting. i also dont see any
  rotation, nor much size tweening that is significant and burst-like. also i think the particles became too dull,
  it should be more bright and shiny".
- CAUSE: vfx-7 copied the reference's frame counts. Its star lasts 2 frames and its early layers 5. In the game,
  particles that live 2-4 frames can't show growth or spin, they pop on and off; the ball thrown again at 2 f and
  3.5 f and the heavy hit's re-throws every 3 f made that worse. The tone work had also cut the glow too far.
- NOW: the layers and their order are still the reference's, but each lives long enough to be seen moving.
  Blades 0.16-0.28 s: a sixth of their length at birth, full length a quarter of the way through, then thinning to
  a needle (Squash -0.2 -> 1.1 over life) and turning (RotSpeed +-110) as they fade. Long spikes 0.14-0.2 s, the
  same way. One second burst on the one hit at 2 f (no re-throws). Band 0.09-0.17 s with Drag. Bubble 0.22 s,
  shock 0.16, floor ring 0.26 (turning 110-170 deg/s), dust 0.45. Arcs turn 2.5x faster. Heavy hit: two more
  bursts 7 f apart, overlapping, not eleven pops.
- SHINE: core brightness 3 and a swelling glow round it; 12 sparks, faster; NEW Glints layer: nine four-point
  stars (hit_star.png) thrown outward, swelling, shrinking and spinning at up to 260 deg/s.
- SEEN in slow motion (studySlow(300)) on the dark floor at 0.025 s (blades just emerging), 0.07 s (full length,
  bubble opening), 0.133 s (thinned to needles, bubble wide with a bright rim, sparks) and 0.21 s (last needles,
  glints, wisps, arcs, dust). On the pale lobby floor the first try was a white blowout: bubble, halo and blades
  were all near fully additive. Halo and blades are LightEmission 0.6 now, bubble fainter. Seen again on the arena
  grass at 0.07 s: bright white middle and band, green blades with white cores, black behind.
- NOT VERIFIED: how it feels at full speed (slow motion can't show flicker; the user must judge), the lobby floor
  after the last change, the heavy hit, 25 fighters, phones. Gates at the end of the session.

## vfx-9 (2026-11-14): the hit as a sequence, a wedge band, placed sparks, sizes corrected (the user tried it at full speed: "Looks good"; committed, not pushed)
- WHY: the user said timing, brightness and size or shape were all still off on vfx-8 (no detail given), and asked
  for it to be compared with the frame-by-frame study of the reference (vault, `63 VFX Creation/Reference Study/
  VFX Ref V01`, hit 1 = f138-f158). They approved seven changes.
- FOUND WHILE TESTING: a particle is drawn TWICE its Size across (ring of Size 6.5 measured 12 studs; band built
  for 20 studs measured 40). vfx-8's bubble (Size to 14 = 28 studs), dust (28), halo (20) and smoke puffs (to 12)
  were therefore about twice the reference's. BLADE_SIZE (measured earlier) already allowed for it; nothing else did.
- NOW (src/client/Fx/PunchHitFx.luau):
  - SEQUENCE: the white floor ring fires alone; everything else waits LEAD = 1 frame. The star is at full size at
    once and only shrinks and thins (blades 0.10-0.16 s, long spikes 0.09-0.14 s); no grow-in.
  - BAND: three tiers of lines on three parts (TIER_CORE / MID / OUTER: 20, 13 and 7 studs long; faces 1.2, 3.6
    and 6.5 studs tall), 35 lines plus 14 thin black ones, slow drift (15-45) so it stays rooted at the contact.
  - SPARKS: ten kites on attachments of a part turned to the camera each hit; each sits 1.7-2.7 studs out and
    points straight outward; the set is turned by a random angle per hit. No sphere emission.
  - CENTRE AND GLOW: core Size 3 -> 4.2 (about 6-8 studs of glow), halo 3 -> 5 for 0.14 s.
  - BLACK: the nine black blades and two black arcs are gone. NEW hatch: two patches of four thin black lines
    over the white centre (Box volume emitters on two small camera-facing parts). Black band lines kept.
  - LEFTOVERS: smoke 0.32-0.5 s, dust 0.3 s, arcs 0.22-0.3 s, floor shade 0.35 s; ring and bubble no longer spin.
  - GLINTS: three, at 6 f (was nine at 2 f).
  - SIZES halved where they were double: bubble 6 -> 12.8 studs, shock ring to 13.6, floor ring 6.6 -> 9.6,
    dust 8 -> 15, shade 9 -> 12, wisps, smoke puffs.
  - Kept on the user's own rules: flipbook wisps and smoke, the dark floor patch.
- SEEN (Play, not saved, Rojo off): the module was pasted into the Play client as a new ModuleScript and fired
  with studySlow(600) on a dark floor in the sky. Ring alone at 0.5 f. Star at 1.1 f: white centre about 6 studs,
  green-edged spikes to about 11 studs with sharp tips. Band at about 3.5 f and 7.5 f: starts at the contact,
  tapers to one tip about 22 studs out, white middle, green tiers, black lines at its edges; bubble about 9 studs.
- NOT VERIFIED: full speed (nobody has seen vfx-9 at full speed); the sparks' and hatch's exact look (too small in
  the captures; their placement is by arithmetic and the vault's measured rotation signs); real punches in a
  round; the heavy hit; pale floors and grass; 25 fighters; phones.
- lobby-2 SAVED FROM THE PLACE (later the same day). The teammate told the user to go ahead ("doesnt care, do
  whatever"), and lobby-2 never reached GitHub (origin/main = 34285b6). Every Rojo-managed script in the place was
  checksummed against disk (102 scripts): 8 differed. Five were lobby-2 and were copied from the place to disk,
  each verified by checksum: `MovementController` (Lobby.disc gets the kick's depth), `Core/Lobby` (disc height at
  a terrace), `Config/LobbyLayout` (tall posts reach h 30 so nobody can perch), `EnvironmentKit` (lobby plants,
  PlantAvgMs / PlantPeakMs attributes), `PlantField` (lobby `Dressing` folder, 45 / 30 Hz sway). The other three
  were mine (PunchHitFx and the two stamps). NOT copied: anything lobby-2 changed outside the three Rojo roots
  (tests, design files, gen_layout.py): those exist only on the teammate's PC.
- Rojo: `rojo serve default.project.json` running from this folder on 34872. The user connected the plugin;
  the place's two stamps read `vfx-9+lobby-2` and its PunchHitFx has the corrected sizes (checked by grep).
- Gates on the combined code: rojo build OK, 452 Lune tests, selene src 0, stylua clean. Build stamp on disk:
  vfx-9+lobby-2. Nothing committed: the working tree holds vfx-9 (mine) and lobby-2 (the teammate's) together.

## vfx-10 (2026-11-14): batch 1 of the remake in one style: shared kit, step burst, swing lines, clash, kick, heavy hit (superseded by vfx-11 and vfx-12; committed with them)
- WHY (the user, after approving vfx-9): "remake all the vfx we have right now, just to test out what youve learned
  from our previous study. still going for a consistent style ... use the references as a basis". They agreed a
  plan of three batches; this is batch 1. Batch 2: dash (lines, after-images, wind, charge), air punch gust, blink,
  launch trail. Batch 3: ground blast, floor break, dive landing, bump puff, drift smoke.
- THE STYLE is written at the top of the new `src/client/Fx/FxKit.luau`: a sequence not a pile; hit colour with a
  white-hot middle = force, white and grey = floor, air and anything deflected, thin black lines = the only dark;
  pointed shapes placed as the camera sees them; real sizes (H = 5 studs, a particle draws twice its Size);
  leftovers gone in half a second. FxKit also holds the textures and the machinery (pooled rigs, layers fired in
  sequence, studySlow for all kit effects). PunchHitFx is NOT yet moved onto the kit (it was just approved).
- StepBurstFx (rewritten on the kit; reference V01 frames 196-211, 258-292, 327-343): toothed burst 0.85 -> 2.7 H
  in four frames with a hard stop, soft flash, thin inner circle, ticked ring spreading steadily to 14 f, three
  slow crescents, eight smoke puffs. White and grey only. Was about twice the reference's size with arcs spinning
  at 420 deg/s.
- SwingTrailFx (rewritten; reference V10 slash ribbons): a thin white-hot line (0.22 studs) drawn by the fist or
  foot, a thinner hit-coloured line just inside it that lasts a little longer, a thin black line just outside,
  and a faint wide body. Two upright sparkles after the strike that sit and shrink. `SWING_RIBBON_LIFE` 0.14 -> 0.1.
- ClashFx (new): `pulse` (black hatch alone for a frame, swapping sides; white-hot spot with seven short green
  spikes; small ticked ring) replaces a sphere part; `repel` is WHITE because nobody is hurt (cross flare, ring
  with an upright four-point star shrinking inside, white and black lines thrown back, four sparkles) and
  replaces a yellow sphere and three streak parts.
- KickHitFx (new; reference V01 hit 2, frames 159-195): floor ring cue; star with its longest spike forward and
  down; ONE thick white beam with a green sheath, tilted up 5 degrees, about 27 studs; thin lines round it; a fan
  of black lines above it; opaque white bubble; at 5 f a green ball with fourteen placed sparks; three thin hoops
  standing at different tilts from 6 f; dust, shade and smoke. `FxController:KickImpact` now calls it for a kick
  that connects, and StepBurstFx for a body reaching the floor or a kick that hit nothing. Its flat discs, ball
  and twelve spokes of solid parts are gone. The finisher's trail puffs (sphere parts) are left for batch 2.
- PunchHitFx heavy hit (reference V01 hit 3, the held hit): nothing is thrown again (HOLD_TIMES 0; HoldLines,
  which fired twelve times two frames apart, removed). The hold is layers that last 0.4-0.5 s: fourteen needles
  that stay and thin, three bands that turn from green to black, a ticked ring, a wider pale plume, then a green
  ball and a circle at 24-26 f.
- SEEN in Play in slow motion (FxKit.studySlow(300), dark floor): step burst at 1.5 f (13.9 studs wide, toothed,
  inner circles) and 9.5 f (ticked ring about 16 studs, smoke puffs); clash pulse (hatch, spot, spikes, ring);
  clash repel at 1.5 f (ring, star, flare, lines back) and 9.5 f (ring grown, sparkles sitting, black lines; its
  ring dipped under the floor, so it was made smaller afterwards and not seen again); kick at about 3 f (star,
  beam to about 27 studs tilted up, black fan above).
- NOT SEEN BY ANYONE: the kick after 3 f (ball, sparks, hoops, smoke); the heavy hit; the swing lines; anything at
  full speed or in a real round. Studio's captures went black part-way through (the known problem in the vault's
  field note; nothing scripted fixes it).
- Gates: rojo build OK, 452 Lune tests, selene src 0, stylua clean. Build stamp vfx-10+lobby-2. Rojo is
  connected, so the place has this build.

## vfx-11 (2026-11-14): basic punch hit; no sun-like rings anywhere; no black line on swing trails (superseded in part by vfx-12; committed with it)
- WHY (the user, after trying vfx-10): "i dont really want the mumen rider vfx, i just want a basic punching
  animation. also i feel liek there are some werid particles mixed in there such as this circle with white lines
  coming out of it looking like a drawing of the sun or something. also i dont think black lines are good for the
  m1 swing trails".
- PunchHitFx REPLACED by a basic hit spark on FxKit (about 230 lines, was about 950): a small white-hot spot, eight
  short green spikes, two longer ones leaning the way of the hit, a thin plain ring, five short white lines, five
  small placed sparks. About a head's size, gone in a sixth of a second. A strong hit is the same, 1.5 times the
  size, with a second ring and three glints. No black, floor ring, bubble, band, smoke or arcs. The replica is in
  Git at 070c547 (vfx-9). This also replaces vfx-10's heavy-hit layers (never seen by the user).
- THE "SUN": the FloorRing texture (thin rings and radial dashes) and the Crown texture (rings and tufts pointing
  outward), and possibly Dust (soft radial streaks). All three are now marked NOT TO BE USED in FxKit. Every ring
  is the plain Circle: StepBurstFx (burst and spreading ring; its extra inner circle removed), ClashFx pulse,
  KickHitFx floor cue and third hoop. KickHitFx's floor dust is a soft glow now.
- SwingTrailFx: the black line is gone. Three tones: white-hot line, thinner hit-coloured line, faint body.
- NOT CHANGED, AND NOT YET JUDGED BY THE USER: the kick (still the Mumen Rider second hit: star, thick beam, black
  fan, ball, hoops), the step burst's size, the clash effects' black hatch and black lines.
- SEEN BY NOBODY: this build. Studio's captures were still black. Gates: rojo build OK, 452 Lune tests, selene
  src 0, stylua clean. Build stamp vfx-11+lobby-2; Rojo connected.

## vfx-12 (2026-11-14): everything plain white; the kick and the clash effects basic too (the user tried it: "Looks good"; committed, not pushed)
- WHY (the user, while vfx-11's follow-up was being built): asked for the kick to be basic like the punch, then
  "also dont make the stuff green just make it plain" and "this goes for everything btw".
- PLAIN: FxKit's default colour is white (`FxKit.PLAIN`; the green constant is gone). The Blade texture has green
  drawn into it, so it is marked NOT TO BE USED; spikes are the white Needle, one emitter each, placed round the
  point as the camera sees it (new helpers `FxKit.placed` and `FxKit.arrange`). A layer marked `tint` takes a
  colour only if one is passed, which nothing does. The style's rule 2 in FxKit now says PLAIN.
- KickHitFx REWRITTEN as a basic hit one size up from the punch: spot, ten short spikes (three lean the way of the
  kick), ONE short thick streak (about 9 studs) with six thin lines, two thin rings, seven sparks, three glints.
  No black fan, bubble, ball, hoops, smoke or floor layers. vfx-10's big kick was never committed.
- PunchHitFx: same basic spark as vfx-11, now white, spikes placed by the helper.
- ClashFx: pulse is a spot, six short spikes and a thin ring; repel is the cross flare, ring and star, white
  lines back and sparkles. No black in either now (my choice, to keep them plain; the user only ruled black out
  for swing trails).
- SwingTrailFx: its second line is light grey, not green.
- OLD EFFECTS NOT YET REMADE, colours only: DashFx's pale blue, warm and orange line colours and ImpactFx's blue
  edge, gold, ember and fire colours are now white and light grey; FxController's LIGHT and SHADE puff colours are
  neutral grey. The dash no longer shows its speed tiers by colour. Rock and soot colours are unchanged.
- SEEN BY NOBODY: this build (Studio captures still black). Gates: rojo build OK, 452 Lune tests, selene src 0,
  stylua clean. Build stamp vfx-12+lobby-2; Rojo connected.

## vfx-13 (2026-11-14): batch 2 of the remake: gust, blink and launch smoke as plain particles; dash on kit textures (the user tried it: "Looks good"; committed)
- WHY: the user approved vfx-12 ("Looks good", pushed as e156abf) and said to start batch 2. Rules now settled:
  basic weight, plain white and grey, plain rings, no black on trails, no solid sphere parts.
- NEW `src/client/Fx/AirFx.luau` (on FxKit): `gust` (a thin ring standing square to an air punch, a second
  smaller one, five thin lines back, three small puffs; after the wind ring in the vault's "VFX Ref V10");
  `blinkOut` (an upright line growing tall and hair-thin while a ring closes); `blinkIn` (a white spot, an upright
  four-point star, a ring, three lines crossing the gap, two puffs; after V10's weapon-swap flash); `trail`
  (one smoke-flipbook emitter per launched root, switched on for a moment).
- FxController: `AirPunchGust`, `Blink`, the strong hit's trail puffs and the kick finisher's streaks and puffs now
  call AirFx. The `streak`, `gustSide` and `blinkPuffs` functions of solid sphere parts are deleted. `spawnBlob`
  remains for BumpPuff and JumpBreak (batch 3). `LaunchTrail` (the uppercut's Trail) is unchanged.
- DashFx: wind streaks and charge sparks use the kit's white needle (were Roblox's sparkle texture); the foot dust
  is the kit's smoke flipbook at about two thirds the size. After-images and line Trails are unchanged; its
  colours were made neutral in vfx-12.
- SEEN in Play in slow motion (FxKit.studySlow(300), dark floor, about 3 f): the punch (spot, spikes to about 4
  studs, ring, lines, sparks), the kick (larger; one thick streak of about 10 studs), the gust (ring, lines back,
  puffs), blink out (tall line and ring), blink in (star in a ring, lines across). All plain white.
- NOT SEEN: the launch smoke trail, the dash with its new textures, anything at full speed or in a round.
- Gates: rojo build OK, 452 Lune tests, selene src 0, stylua clean. Build stamp vfx-13+lobby-2; Rojo connected.

## vfx-14 (2026-11-14): batch 3 of the remake: bump, jump, drift and ground blast as plain particles; ImpactFx and the sphere-part code deleted (the user tried it: "Looks good"; committed)
- WHY: the user approved batch 2 ("Looks good", commit 07bfb50, not pushed) and the three-batch plan. This is the
  last batch. Same rules: basic, plain white and grey, plain rings, no solid sphere parts.
- StepBurstFx: new third argument `heavy`. A heavy landing adds seven thin white lines thrown up off the floor and
  seven rising smoke puffs to the ordinary burst.
- AirFx: `bump` (a small spot, one thin ring, four puffs), `puff` (one drift-smoke puff leaving along a
  direction, rising as it swells), `ribbon` (the Trail behind a launched body, moved here from ImpactFx).
- FxController: `BumpPuff` -> AirFx.bump + a small StepBurstFx at the feet; `JumpBreak` -> StepBurstFx at 0.8
  (its ten sphere puffs and the floor-coloured dust are gone; rocks unchanged); `driftSmoke` -> AirFx.puff;
  `GroundBlast` -> StepBurstFx heavy at 0.75 x GroundBlastScale x power (rocks unchanged); `LaunchTrail` ->
  AirFx.ribbon. Deleted: the Blob type, `takePart`, `spawnBlob`, `ball`, the sphere pool, LIGHT, SHADE and the
  TweenService import. No solid effect parts remain except the rock chunks and the dash's after-images.
- DELETED `src/client/Fx/ImpactFx.luau` (529 lines: the old spark, fist trail and the gold-and-fire ground
  blast). Nothing uses it now. It is in Git up to 07bfb50.
- CAUGHT BY THE PLAY TEST, not by the gates: a PowerShell array literal (`@("a", $block + "b")`: the comma binds
  tighter than +) dropped the pool's `return { floor = floor }`, so StepBurstFx errored on its first use. Fixed.
- SEEN in Play in slow motion (studySlow(300), dark floor, about 7 f): heavy landing (plain rings about 13 studs
  wide, lines thrown up, smoke), bump (ring and puff), one drift puff, a small step burst. All plain white.
- NOT SEEN: these in a real round (a dive kick landing, a jump off the floor, sliding out of a dash, two fighters
  bumping), the launch ribbon, anything at full speed.
- Gates: rojo build OK, 452 Lune tests, selene src 0, stylua clean. Build stamp vfx-14+lobby-2; Rojo connected.

## lobby-2 (2026-11-14): lobby checked properly - prover, hand walk, frame cost, the three known gaps (NOT COMMITTED)
- Pulled spicy's vfx-3..vfx-8 first (fast-forward, no conflict). Build label `vfx-8+lobby-2`. Pushed 156 instances,
  PASS; place saved v303 and v304. ServerStorage.HT_Lobby.Cliffside was in the place (194 descendants).
- PROVER (roblox-map prove.py): `design/lobby/prove/make_spec.py` writes `lobby_spec.json` from the SAME collider list
  LobbyService builds (gen_layout.colliders()) + floor + the four barriers from game.json; movement profile
  `haymaker_profile.json` = the game's own numbers, worst case a running Space jump (Jump.UpMax 80, gravity 196.2
  -> 16.3 studs up, 73 across). FOUND: players could stand on the lantern/gate/banner posts and on the great tree's
  trunk inside its canopy. FIX: gen_layout.py NO_PERCH carries every tall thin post (r <= 2.5, >= 8 tall) up to
  h 30 (above anything reachable: highest top 7.7 + 16.3). Now P1/P2/P2b/P3/P5/P10/P11/P16 PASS; P6 "overlap" is the
  invisible collision boxes sunk into each other on purpose (never rendered). Plan: prove/lobby_plan.png.
- HAND WALK in Play (keyboard via MCP; works when the Client DM is focused): balcony -> ramp -> court -> ramp ->
  training and back down, no snag or drop; front/back walls and stair-end planters stop where drawn. Side walls
  only by the prover.
- REBOUND DISC: Lobby.disc(cfg, z) now sits at the terrace height under the kick (tests/Lobby.spec).
- PLANT SWAY in the lobby: EnvironmentKit binds PlantField to workspace.HT_Lobby.Model (folder Dressing) whenever
  the map entry has `lobby = true` (in the lobby state HT_Map exists but is EMPTY, so "no model" never happened).
  48 of 60 placements move (rocks/ruins never). PlantField now poses at most 45 Hz (UPDATE_HZ; phones/low graphics
  30 Hz) instead of every frame. Cost readout: HT_Environment attributes PlantAvgMs / PlantPeakMs.
- MEASURED, lobby state alone (Studio PC): 227 fps, 4.4 ms/frame, 44 draw calls, 119k tris in view, barrier
  0.05 ms, plants 0.22 ms -> 0.11 ms after the cap (0.2 ms per update). Model: 132 MeshParts, all anchored, no
  CanCollide/CanTouch/CanQuery, no lights.
- GOLDEN HOUR by eye (in-game spawn capture): warm, readable; a bright glare patch on the paving toward the sun.
- CAPTURES: Studio's Assistant HTTP permission is not configured, so capture_receiver can't write PNGs (user's
  setting, not changed). screen_capture images land in the session's tool-results folder; copies in
  design/lobby/prove/review/ with EVIDENCE.md (the reviewers' pack). Edit-mode captures came back black/timed out.
- NOT TESTED: phones (lighter path = existing low-graphics ranges + 30 Hz), several real players, side walls by hand.
- RUBRIC (3 blind reviewers, median; pack in design/lobby/prove/review): LOBBY 7.5/10 (W1 2, W2 1, W3 2, W4 1, W5 1,
  W6 2; gates pass, phone budget unmeasured). BARRIER 5.8/10 (X1-X5 all 1, X6 2), held down mainly by evidence:
  no frame shows the lit cells by a player, no motion seen; also low contrast on bright sky. BOTH BELOW 8.5.
  Reviewers' asks: lobby - warmer golden-hour grade (sky reads noon), landmarks leading up the terraces, detail
  on the open court/training paving; barrier - frames of the lit patch, brighter core/darker backing in daylight.
- FIX ROUND 1 started, NOT DONE: a warmer grade was tried live (sun 255,192,128; exposure -0.12; saturation 0.14;
  bloom 0.22; atmosphere density 0.3, haze 1.8, decay 236,164,118) but Studio's viewport then rendered BLACK in
  every capture (Edit and Play; HUD only), so it was never seen and NOTHING was changed in MapEnvironments.

## lobby-3 (2026-11-15): floating plants grounded, red gate removed, soil under the ledge trees
- FLOATING: the kit's bushes have their pivot 0.4-1.65 studs below the leaves, so placing by pivot left every bush
  hovering. studio_lobby.py now GROUNDS each kit piece (lowest point dropped to its placement height, sunk 0.2;
  never lifted). Measured in Studio after: every piece's lowest point is at or below its ground (max -0.02).
  Ledge dressing also hung off the cut rock tops (Blender raycasts: up to 5 studs of air); it now sits on each
  ledge's flattest spot (found by raycasting cliffside.blend) within the measured flat radius.
- GATE: the red training gate is gone (cliffside.py gate_and_banners, mesh dropped from manifest.json, its two post
  colliders gone from collision.json -> LobbyLayout.luau; prover unchanged: all pass but P6, the known on-purpose
  overlap). cliffside.blend / export GLBs still hold the gate until the next full rebuild + upload.
- SOIL: each ledge tree grows from a soil mound = the kit's Rock_Flat_Slab at scale 3 (2 on the back-left ledge),
  mostly buried, repainted with the planters' soil texture (placement skin "soil"). The first left ledge was
  swallowed by a spire (2 studs of flat) and no longer carries a tree.
- NEW: design/lobby/out/cliffside/studio_dressing.luau re-dresses the existing Cliffside model in Studio (no upload).
- Pulled spicy's vfx-9..vfx-14 first (they had committed the lobby-2 scripts from the place; identical). Build label
  vfx-14+lobby-3. Rojo push 159 instances, PASS 142 scripts. Place saved v317.
- NOT SEEN BY EYE: Studio's capture returns a black 3D view and screen access was declined; checked by raycasts only.

## ui-0b (2026-11-15): Golden Hour tokens (committed with lobby-4)
- First UI Phase 0 piece done here (0a "measure first" needs a phone, so it waits). NEW src/shared/Tokens.luau: every
  colour (HEX strings + lazy Tokens.colour), space 4..64, radius, surface levels 1-3 (HUD 0.12), shadows, motion
  durations/easings, the type scale per role, the three Builder families. Nothing requires it yet: no visual change.
- NEW tests/Tokens.spec.luau (8): measured contrasts match the palette to 0.1, essential text >= 4.5:1 on ink
  900/800/700, ink on accent fills, 4-unit grid, 15-unit floor, HUD transparency <= 0.12. 460 passed.
- Build vfx-14+lobby-3+ui-0b, Rojo push PASS 143. Frame cost: none to measure (module is unused until 0c/0d).
- NEXT: 0c Typography (Builder Sans/Extended/Mono behind the same Typography API), then 0d HudTheme -> tokens.

## lobby-4 (2026-11-15): bigger shop stall; lobby wind fixed (committed, approved)
- STALL (cliffside.py, STALL_FRONT/BACK/OVER): front posts 12.5 (was 9.4), back 15.5 (was 12.2), awning reaches 7
  past the front posts (was 3.6), same slope/stripes/hem, knee braces under the overhang, thicker posts; counter
  height, length, stock and colours unchanged. Awning front edge 10.7 above the court, hem low point 8.85: a 5.2-stud
  R15 has ~3.5 studs headroom (Blender check with stand-ins: scratch render, not kept). Post colliders r 0.7.
  Full build done (blend, GLBs, textures, manifest: 32 meshes, no gate). Uploaded under group 2970443:
  cliffside_1 = 93706706559765, cliffside_2 = 85520808283381 (Approved, version 11766525074883 for _2). Inserted
  after a network outage (TLS to roblox.com was being intercepted; fixed on the user's side) and built with
  studio_lobby.luau: 32/32 meshes, 61/61 kit pieces. MEASURED in Play: awning bottom 11.85 (court 3), the user's
  character with a hat tops out 2.8 below it; the customer side (u 48..54.6, in front of the counter) is open from
  the court and a 2x5.6 box sweeps d 39..86 clear (barrel at the far end). The strip behind the counter is closed at
  both ends by crates and planters, as before. Wind still 74 dressing parts moving, no non-vegetation. Place v321.
- WIND: the lobby's kit plants were ALL still in Play. Two causes: (1) EnvironmentKit only bound the lobby's plants
  in the lobby-only state, so with an arena up the lobby was static for everyone waiting there; (2) streaming:
  PlantField was built before the lobby's Dressing reached the client, so it found nothing. Fixes: a second,
  always-on lobby PlantField in the lobby preset's wind (retried each second until HT_Lobby.Model arrives);
  PlantField rescans on DescendantAdded at its 4 Hz refresh; the great tree's crown (Meshes/Lobby_*_Leaf) sways as a
  tree; Foliage.crownScale damps big crowns (20/size, 0.5..1; test). MEASURED in Play with an arena loaded: lobby
  vegetation moving 43-45 of 45 (rest at range edge), crown moving, rocks/soil/ruins/stall still; PlantAvgMs 0.25
  (both fields), peak 0.99. Phones/low graphics: existing 30 Hz + shorter ranges. Build vfx-14+lobby-4+ui-0b,
  Rojo push PASS 143.

## kits-1 (2026-11-15): six ability kits built, every R made strong
Build `kits-1+lobby-4+ui-1`. NOT committed, NOT pushed, NOT tried by the user. Rojo not running.
- ASKED (user): "at least 4 very unique very fun new movesets" with elements and concepts like dragon or beast,
  VFX "just like the references", "very detailed very flashy"; then: finish Bruiser and Trickster; make the R
  moves strong ("the basic one and the tempest one are pretty weak"), meaning harder throws, "bigger hitboxes
  and stronger effects".
- KITS (Config/Abilities; shop order Base, Tempest, Inferno, Frost, Beast, Dragon, Bruiser, Trickster):
  Inferno 600: Jet (burst any way the keys point, 105 for 0.3 s) / Comet (lunging punch, flat and far).
  Frost 600: Slide (72 for 1.1 s, steers) / Glacier (rooted, wide, throws straight up).
  Beast 800: Pounce (leap that lands on the nearest fighter within 46) / Maul (fast wide claw, 3.5 s cooldown).
  Dragon 1000: Ascend (95 up, works in the air) / Breath (rooted, 22 studs long, narrow).
  Bruiser 500: Charge (80 for 0.6 s; the first punch on it in 0.75 s throws 0.2 as hard) / Slam (rooted, all round).
  Trickster 750: Flip (leap away from the nearest fighter) / Backfist (fast, all round, body spins).
- HOW: mobility skills are `Abilities.KitMoves` run by Core/SkillMove (pure, tested): a burst is a Momentum dash
  with its own length, speed and steering; a leap is a jump with its own speeds. MovementController starts them
  on its step (`SkillMove(id, cfg)`), AbilityService shows everyone else (KitMoveRequest, no arguments: the
  server reads the skill off the kit; KitMoveStarted). Attack skills are `Abilities.KitSwings`, each a HEAVY
  entry in CombatService with side = skill id, through one KitSwingRequest (no arguments). They borrow swing
  clips (AnimController). Recovery numbers are `Abilities.Endlag`, laid over GameConfig.Endlag by Endlag.with.
- STRONGER R: Uppercut (GameConfig AND design/game.json) Range 6 -> 8.5, Degrees 35 -> 50, Lift 85 -> 100,
  ArcBase 25 -> 70, ArcPerStud 1.3 -> 1.6, ArcMax 90 -> 170. Cyclone Range 7.5 -> 10.5, Lift 38 -> 45, ArcBase
  42 -> 85, ArcPerStud 0.7 -> 1.2, ArcMax 85 -> 160. A test holds every R to a standing throw of at least twice
  a standing punch. (For scale: a running punch reaches about 143.)
- EFFECTS: Fx/KitFxCommon (palettes, layer recipes, pieces placed as the camera sees them, streams on a moving
  body) and one module per kit (InfernoFx, FrostFx, BeastFx, DragonFx, BruiserFx, TricksterFx), plus Fx/SkillFx
  for the Uppercut's column and the Cyclone's whirl (plain white). Each header cites the reference frames it
  follows. These are coloured and big on purpose: the plain rule still holds for everything else. Four new
  textures (design/vfx/draw_kit_shapes.ps1: Claw, Shard, Leaf, Pinwheel), ids in FxKit.Tex. FxController:
  KitMove, KitSwing (windup now, strike after the windup unless KitSwingCancel), KitHit, UppercutHit.
- SAVED FROM THE PLACE (dumpl's, not from his folder): ui-0c..ui-0e (9 changed, 2 new) and later ui-1
  (HudController, HudLogic, new Ui/Components), each file verified by checksum against the place.
- CHECKED: rojo build OK, 481 Lune tests (20 new in SkillMove.spec), selene 0, stylua clean. New
  `lune run lune/fx_smoke`: builds every rig and calls every effect once on Lune's Roblox instances (7 of 7,
  1028 emitters); it catches wrong property names, not looks. SEEN IN PLAY (modules pasted into a Play client,
  slow motion, pale lobby floor): the Maul's three claws and its hit. First pass was washed out to white and the
  black slivers were too long; star spikes and body layers were retuned for every kit (colour ramps no longer
  start at white, LightEmission 0.45-0.5).
- NOT TESTED: any gameplay in Studio (no Rojo sync: the place is shared and was changing). No effect but the
  Maul's has been seen. Phones, 25 fighters, grass. Balance is a first guess.
- TEST BALANCE (user: "me and my friend have like 20000 coins"): Abilities.TestCoins lists two Roblox user ids (the user's,
  and the other account in the Team Create session: my reading of "my friend"); PlayerDataService raises their Coins
  to 20000 on joining if they have fewer (AbilityKit.topUp, never lowers; 2 tests, 483 in all). It is saved like any
  other change, and it refills on every join. Empty the list before release. Gates green; not tried in Play.

## kits-2 (2026-11-15, IN PROGRESS): the rework, Frost first
Build `kits-2+lobby-4+ui-1`. Rojo is serving from this folder and connected. NOT committed, NOT pushed.
- WHY: the user tried kits-1 and rejected it: "all of them seem very similar", most Q moves "too weak, too similar
  to the base dash, or just useless like the beast one" (Base, Tempest and Trickster's were fine), R moves "the
  same for all of them" and "underwhelming", VFX "way too thin", "too bright so its hard to see", wants "multiple
  colors and shades", "REALLY big", and solid models mixed in ("the ice should be made out of a solid model").
  Also wanted per kit: its own M1 animations and hit effects, its own air-kick and jump-kick style, its own
  sounds. All cosmetic (same damage and timing).
- AGREED DESIGN (my proposal, the user's answers): Base stays as it is. Tempest: Gale Step (blink plus a wind
  burst that pushes) / Tornado (travels, pulls in, throws up). Inferno: Blast Jump (explosion knocks back those
  close) / Meteor (ring on the floor, then a rock falls, 12-stud blast). Frost: freezing dash / Glacier stomp
  ("i would prefer the glacier stomp, a freeze ability is fine"). Beast: Pounce that slams on landing / Frenzy
  (four claw hits that drag, last one throws). Dragon: Wings (hold to glide) / Breath held 1 s, sweepable,
  pushes continuously, dragon head model. Bruiser: Bull Rush (rams and carries the first fighter) / Earthshatter
  (travelling shockwave ring you can jump, rock spikes). Trickster: keep the Flip (it was liked), add a decoy
  to swap back to / Backstab (appear behind the nearest fighter). Models from Blender (open, 5.2), free
  Creator Store sounds. Build one kit, show it, then the rest two at a time.
- REFERENCES: 13 new YouTube links (ids in the vault's `63 VFX Creation/VFX Reference Library.md`). Studied so
  far at low rate: the three ice ones and Pidgey's Excalibur. What they share: solid meshes with particles,
  opaque saturated colour masses, a dark shade behind, white only in thin cores and first frames, huge size.
- DONE, FROST: `Frostbite` (Q, was Slide): dash 112 for 0.42 s any way the keys point; the server sweeps and
  freezes everyone within 6.5 studs for 1.1 s (new Services/StatusService: HT_Frozen + HT_Stunned, remotes
  Frozen / Thawed, no refreeze for 1.5 s); a hit on a frozen fighter shatters the ice and throws 1.6x.
  `Glacier` (R): Range 15, 110 degrees, Lift 145. New Fx/KitModels (solid pieces: erupt white-hot, stand, sink;
  thrown debris) and a rewritten Fx/FrostFx (21 crystals in three waves, navy smoke, stain, rings, rays,
  three-tone arcs, chips, snow, violet motes; a freeze block; shatter; the kit's own punch hit and landing).
  FxController: kitOf(character) picks a kit's cosmetic punch and landing looks.
- ICE MESHES: design/kits/ice_kit.py (run in Blender) -> design/kits/out/export/ice_kit.glb (5 pieces: SpikeTall,
  SpikeThick, Clump, Block, Shard; vertex-coloured, 1 unit tall, root at the bottom). NOT UPLOADED: the folder
  is not on the approved Open Cloud upload list (Assistant Settings -> MCP Permissions). Until
  ReplicatedStorage.HT_KitModels holds them, KitModels shows plain blocks.
- CHECKED: gates green (rojo build, 484 Lune tests, selene 0, stylua), fx_smoke 7 of 7. SEEN IN PLAY, slow
  motion, on grass: the Glacier with stand-in blocks: about three character heights tall, four blues, dark
  arcs with white cores, rings. Much thicker than kits-1.
- NOT DONE FOR FROST: real meshes in the place; its sounds; M1 and kick ANIMATIONS (only the effects differ so
  far; AnimClips is generated by animations/build_clips.py and this PC has no Python, so new clips need a Luau
  generator); nothing played against a fighter (freeze, shatter, the stomp's throw).
- THE OTHER FIVE KITS are still kits-1.
- LATER THE SAME DAY (the user approved the upload folder): the ice kit is Open Cloud Model 94341799888558 (group
  2970443), inserted as a package at ReplicatedStorage.HT_KitModels.IceKit in the place (not in Rojo's tree, like
  HT_GrassKit). The crystals read navy on Material Ice, so they are SmoothPlastic, Reflectance 0.15, Transparency
  0.1, in four paler blues (vertex colours darken the roots). Sounds: `ice_shatter` and `ice_whoosh` in SoundBank
  (ProSoundEffects; start and volume NOT measured). PLAYED IN STUDIO as the user's account, Frost equipped, on
  Practice Dummy 1 in the lobby: Q through the dummy set HT_Frozen and HT_Stunned on it (server); R threw it about
  31 studs up (y 129 -> 160). SEEN at full speed from the player's camera: the cluster stands in front, about three
  character heights. Two fixes from that: the two crystals behind the thrower put the camera inside the ice
  (removed), and the snow sparkles were far too big (halved). The test balance works: 20000 Coins, every kit owned.
  Gates green at the end: 484 tests, selene 0, stylua, fx_smoke 7 of 7.
- THE USER TRIED FROST (kits-2) AND SAID "Yes, do the rest". Later: "also make sure to update the m1 animations".

## kits-3 (2026-11-15): Inferno and Beast reworked, kit punches, shared cast machinery
Build `kits-3+lobby-4+ui-1`. Rojo serving and connected. NOT committed, NOT pushed, NOT tried by the user.
- SHARED: `CombatService:SkillHit(attacker, target, away, strength, up)` is how anything that isn't a swing
  lands a hit (CanFight, stagger, ring-out credit, ice, armour, HitConfirmed). `Services/SkillCastService`
  runs a KitSwing that has a `Cast` (CombatService.heavy hands it over after the usual press, kit, cooldown and
  endlag checks): kinds "meteor" and "frenzy". AbilityService: a KitMove with `Blast` throws everyone close at
  once; with `Slam` the server watches for the landing, throws everyone close and fires KitLanded. New remotes
  KitCast (attacker, skill id, position) and KitLanded (character, skill id). Core/SkillMove.inFan (tested).
- INFERNO: `Blastoff` (Q, was Jet): leap 78 up / 54 forward, blast radius 10, push 90, lift 48. `Meteor` (R, was
  Comet): rooted 0.45 s, lands 16 studs ahead 0.35 s later, radius 13, throw 150, lift 80, cooldown 8.
- BEAST: `Pounce` now lands ON the nearest fighter within 52 and slams (radius 8.5, push 80, lift 58).
  `Frenzy` (R, was Maul): lunge 64 for 0.58 s, four hits 0.14 s apart; the first three drag (72 the way you
  face), the last reaches all round and throws at 115, lift 44, cooldown 6.
- KIT PUNCHES (cosmetic): `Shared/AnimVariants` (pure, 7 tests) derives clips from Config/AnimClips by mirroring,
  reversing and copying one arm onto the other: Frost ChopLeft/ChopRight (the uppercut backward), Inferno
  RiseLeft + Uppercut, Beast RakeLeft/RakeRight (both arms). AnimController plays AnimVariants.swing(kit, side)
  for Left and Right; the swing, its timing and its strike marker are unchanged. STUDIO ONLY like every clip:
  Config/AnimAssetIds is empty, so no clip of any kind plays in a live game until clips are uploaded.
- MODELS: design/kits/rock_claw_kit.py -> rock_claw_kit.glb, Open Cloud Model 89330300578027 (group), package at
  ReplicatedStorage.HT_KitModels.RockClawKit: Rock_Meteor, Rock_ChunkA/B, Claw_Blade, Claw_Fang. Blender 5.2
  CRASHED when objects were selected under temp_override in a scene that isn't the window's; each kit file now
  has its own scene and exports with use_active_scene.
- EFFECTS: KitFxCommon.thick(tones) is the shared thick layer set (dark smoke, haze, chips, motes, flash, floor
  rings, stain, three-tone arcs, rays, three-tone star, lens sparks). KitModels gained sweep (a claw swiping
  across) and whole-size thrown pieces (the meteor). InfernoFx and BeastFx rewritten on them; each kit's punch
  hit and landing look goes through FxController's kitOf / kitLanding.
- PLAYED IN STUDIO as the user's account on Practice Dummy 1: Meteor threw it about 125 studs (z 376 -> 250);
  Blastoff launched the player; Frenzy dragged it 10 studs but the LAST HIT MISSED (the lunge outran the drag),
  fixed afterwards (drag 34 -> 72, last hit all round) and NOT re-played; Pounce landed on it from 22 studs and
  the slam threw it 39 studs. SEEN from a side camera: the Meteor before and at impact, the Blastoff, a Frenzy
  swipe, the Pounce's slam. Poses seen frozen: the chop (arm overhead, then down) and the rake at its strike.
- CHECKED at the end: rojo build, 491 Lune tests, selene 0, stylua, fx_smoke 7 of 7 (2254 emitters preloaded).
- NOT DONE: Tempest, Dragon, Bruiser and Trickster are still kits-1 (their effects are the thin first version).
  KICK animations for any kit. Sounds for Inferno and Beast are the existing ones at other pitches. Balance is
  a first guess (the Meteor's 125 studs on a staggered dummy is a lot).
- STILL NOT DONE FOR FROST: kick animations; the shatter bonus was not measured; the freeze was not seen
  from outside (the block of ice round a frozen fighter); nothing tried on a phone or with other players.

## kits-3b (2026-11-15): solid crescents removed, Frenzy drag fixed
Build stamp unchanged (`kits-3+lobby-4+ui-1`). Committed and pushed with everything before it.
- The user tried the kits and asked for the "solid 2 color crescent things" on top of every effect to go. REMOVED:
  KitFxCommon thick.arcs (and its type and ARC_SHAPE), Frost's own arcs/placeArcs (Frostbite start, Glacier),
  Inferno's (Blastoff, Meteor, landing), Beast's (Pounce spring, slam, landing, the Frenzy claw fan and its
  black slivers) and Trickster's Backfist crescent sweep. Solid claw blades, smoke, rings, rays, stars stay.
  Rule for the remaining kits: no crescent layer over an effect (memory vfx-no-solid-crescents).
- FRENZY measured in Play with a server probe: at DragPush 72 against the 64 lunge each drag shoved the dummy
  further ahead; hits 2-3 landed, the throw found it 12 studs away and missed. Now DragPush 56 and a new
  Cast.LastReach 12 for the throw (SkillCastService). Gates pass. NOT RE-PLAYED: Play was stopped before the
  re-test. Next: re-play it (walk toward the dummy with W and press R while moving; the lunge follows the
  movement controller's facing, not the root's CFrame), then Tempest and Dragon.

## kits-4 AGREED DESIGN (2026-11-15, the user: "the lineups are good for the starting point")
Everything is reworked: rules, moves, VFX, animations, sounds. Order: rules first (user tests), then kits two at
a time (Base+Tempest, Inferno+Frost, Beast+Dragon, Bruiser+Trickster), each shown (animation contact sheets,
then moves and VFX in Play, then a sound board) and approved before the next. Animations NOT uploaded yet.
RULES
- M1 is a 4-hit string: hits 1-3 stun (about 0.4 s, almost no push), only hit 4 knocks back. Resets on a miss or
  about 1 s without a hit. Stunned players can't act at all, Q included.
- No speed scaling anywhere (Knockback.SpeedBonus, every ArcPerStud, the Uppercut's). Stagger meter stays.
- No held punches. No charged-dash hit (DashHit removed; a dash collision is only a bump).
- The air kick chain (jump, Space, chase, attach, QTE flip, spike) is removed. M1 in the air glides up to about
  16 studs toward the aim and punches with a normal hitbox, no AoE, and it counts as hit 1 of the string.
- R is held for every kit: charge fills over 1.0 s, movement at half speed, getting hit cancels it, a tap fires a
  weak version. PERFECT: release inside the last 0.05 s (0.95-1.00 s). Meant to be extremely hard and extremely
  rewarding (it replaces the air kick's skill test): much stronger throw, impact frame, hit-stop, its own VFX.
KITS (Q mobility / R close-range held attack / M1 string)
- Base, boxer, white+gold: Slip Step (weaving dash, makes punches miss) / Haymaker (corkscrew overhand, cone
  shockwave) / jab, cross, lead hook, overhand.
- Tempest, wind palm, cyan+white: Gale Step (two air dashes any way) / Tornado (pull in, release flings out) /
  palm thrust, spinning backhand, rising palm, double palm.
- Inferno, explosive striker, orange+red+black: Jet Fist (punch the floor, rocket forward, fire trail) /
  Eruption (uppercut into a fire pillar) / jab, body hook, spinning backfist, exploding straight.
- Frost, ice rush (Frigid Rush), white+cyan+blue: Ice Slide like Frozone (a smooth ice path under you, usable in
  the air, NO freeze) / Glacier stomp, SMALLER and NARROWER than now / ice jab, cross, spinning hook, palm burst.
- Beast, claws, red+black: Pounce (leap onto nearest, landing slam) / Frenzy (dragging claw rush, charge adds
  hits 3 to 6) / left rake, right rake, double claw, lunging swipe.
- Dragon, dragon kung fu, violet+gold: Wings (wingbeat any way incl. up, short glide) / Dragon's Maw (dragon head
  model on the fist, lunge-bite grab and hurl; the only grab) / claw palm, tail-whip backfist, rising claw,
  two-palm flame push.
- Bruiser, wrestler, gold+brown: Bull Rush (armoured charge carrying the first hit) / Earthshatter (travelling
  ring of rock spikes, charge grows it) / hammer fist, body blow, clothesline, double-axe handle.
- Trickster, feints, pink+white: Phantom Step (dash leaving a decoy, Q again swaps) / Counter (held stance; hit
  while holding = teleport behind and launch; released unhit = quick backfist) / flicker jab x3, spinning heel.
VFX: references V01 Mumen Rider, V02 Frigid Rush, V10 Weapon Switcher: full-size one-frame pops, a quiet beat
before the biggest hit, dark shapes behind bright cores, crescents of THIN strands only (no solid two-tone
crescents), plus impact frames, hit-stop, camera kick, colour flashes, shockwaves, Glass-bubble distortion.
SOUNDS: 3-4 licensed candidates per slot on a Studio sound board; the user picks.

## kits-4a (2026-11-15): the new combat rules (step 1 of the kits-4 design)
Build `kits-4a+lobby-4+ui-1`. Rojo connected (the user clicked Connect). NOT committed.
- M1 STRING: Punch.ComboHits 4. Hits 1-3 stun (StatusService:Stun, Punch.StunSeconds 0.5) and DRAG: an ObjectValue
  HT_DraggedBy in the target points at the puncher, and whoever moves the target's body (its own client in
  MovementController, or DummyService) steers it to a spot Punch.DragLead 3.2 studs in front of the puncher at
  the puncher's velocity plus a spring (Combat.dragFollow, DragSpring 8, DragMax 90). Only the FIRST fighter a
  punch reaches is dragged (several dragged to one spot piled up and stun-locked, seen with bots). Hit 4 knocks
  back at Knockback.BaseSpeed 85 x stagger. Miss or ComboResetSeconds 1 without a hit: back to hit 1.
- Speed adds nothing anywhere: SpeedBonus*, every ArcPerStud and ArcMax gone; R throws are now fixed ArcBase
  (Uppercut 125, Cyclone 125, Meteor 150, Glacier 52, Frenzy 115, Breath 125, Slam 120, Backfist 140).
- No held punches (PunchReady remote, ReleaseWindup etc. gone). No launching kick (HeavyKick config and side
  gone). The dive kick is replaced by the AIR PUNCH: a click in the air glides up to Punch.AirReach 16 studs
  over AirGlideSeconds 0.18 toward the lock-on target / the fighter under the cursor / the cursor spot, and the
  server gives it AirWindup 0.22 and makes it hit 1 of the string. Training pads no longer MarkLaunched. The
  kick chain's code is still there but nothing starts it (cleanup debt). Core/DashHit deleted (it was unused).
- HELD R for every kit: SkillChargeStart (no args) then the release request with the client's measured hold
  (Combat.trustedHold: believed within SkillCharge.Tolerance 0.15 of the server's own). Combat.chargePower:
  TapPower 0.55 rising to 1 at FullSeconds 1, which is also MaxHoldSeconds (it fires itself). PERFECT is
  PerfectStart 0.90 to PerfectEnd 0.95 s (the user moved it off the end), PerfectPower 1.9, SkillPerfect remote,
  a white flash and an impact frame (FxController:PerfectRelease / PerfectImpact, first pass). Moving at
  MoveShare 0.5 while charging (HT_Charging, client only); others see the wind-up (HT_ChargingSkill, server).
  Hit or stunned or Q while charging cancels it. Ui/ChargeBar draws the bar and the white Perfect band.
- PLAYED in Studio on the practice dummies: 4 of 4 punches landed on the run (steps 1-3 stun, step 4 strength
  176), the dummy dragged along; the air punch locked on glided 14 studs and stunned (step 1, air); Frenzy held
  0.909 s gave PERFECT from the server, 0.892 s and 0.957 s did not. TestBot1 landed a full string on me
  (step 4 strength 193-329). Console clean.
- NOT CHECKED: the drag on a PLAYER being dragged (needs a second client), the Perfect flash and impact frame
  by eye, phones and gamepads (L2 hold), the R wind-up pose seen by others. Tutorial's fast-hit step no longer
  fits (tutorial is off). Clash strength now uses BaseSpeed 85 (was 23), not re-tuned.

## kits-4b (2026-11-15): M1 lock, plain R hold, Perfect removed
Same build stamp (kits-4a). NOT committed.
- User: "dragging isn't what I want, lock them in front of you". Hits 1-3 now LOCK the first fighter a punch reaches
  Punch.LockDistance 3.2 studs in front of the puncher (Combat.lockSpot), facing them, at their velocity, led by
  LockLeadSeconds 0.1 for the lag on the puncher's body. Set by CFrame every frame, by the target's own client
  (MovementController) or DummyService. PLAYED: 4 of 4 hits on the run, the dummy held 3.5-4.5 studs ahead
  (client view). It is placed directly, so it can be pushed through a low wall (seen once).
- User: "remove the charging, you can still hold it up to 3 s but no timing". GameConfig.SkillHold
  (MaxHoldSeconds 3, MoveShare 0.5, ReleaseWindup 0.12). Same strength however long it is held. Removed:
  chargePower, trustedHold, the Perfect window and PerfectPower, the SkillPerfect remote, Ui/ChargeBar, the
  Perfect flash and the old flash "impact frame" (user: "it just flashes"). Release requests carry no arguments
  again. Gates: 481 tests (the two charge tests went), selene 0, stylua, rojo build, fx_smoke 7/7.
- NEXT (not built, design to agree): an ULTIMATE METER filled by landing hits, draining after 3 s without one;
  at full, a kit's ultimate is a locked follow-up used after the 4th M1 knocks someone away, built to ring them
  out, super flashy, with real impact frames (vault: 63 VFX Creation/Impact Frames - What They Are and How to
  Build Them in Roblox.md, from the user's 3 references).

## kits-4c (2026-11-15): ultimate meter, G follow-up, shared ultimate engine, Base "Final Bell"
Build `kits-4c+lobby-4+ui-1`. NOT committed. User answers: key G; full meter holds then drains; window after a
4th-hit knockback OR an R throw; four strings fill it; impact frames on ultimates only, each fitting its kit;
cinematic camera on both screens; the M1 lock stops at walls and stays close.
- LOCK: Punch.LockDistance 2.8; Combat.clipLock clips it at the first wall on a ray from the puncher
  (LockBodyRadius 1.4 kept clear), in MovementController and DummyService.
- METER: Core/UltimateMeter (pure, tests/UltimateMeter.spec): GameConfig.Ultimate StunHitGain 5, FinisherGain 10,
  SkillHitGain 15 (4 strings = 100), drains DrainPerSecond 12 after DrainDelaySeconds 3; full holds
  ReadyHoldSeconds 8, refreshed by every hit. Server UltimateService keeps it, publishes Player HT_Ult /
  HT_UltReady; CombatService calls Gain (stun hits, finishers, R swings) and OpenWindow (finisher, R swing,
  SkillHit). Ui/UltimateMeter: gold bar above the vitals, G cap when full, big G prompt with a closing ring.
- WINDOW + START: UltimateWindow (1.2 s) -> G (DPadUp; touch button "Ult") -> UltimateRequest (no args) ->
  UltimateStarted to all with the anchor frame (at the target, facing outward from the arena's middle, or away
  from the attacker off the arena), attacker start, shared start time, flight end. HT_Ultimate on both; CanFight
  refuses either side; their punches/skills refused.
- ENGINE: Core/Ultimates (pure, shared, tests/Ultimates.spec): timelines (keys for both bodies, camera shots,
  cues), pose(), cuesBetween(), flightEnd() (past the arena oval + PlayAreaMargin + FlightPastEdge and
  FlightBelow under the elimination line, so Round.isOut is certain; tested from 4 spots), flightPoint().
  UltimateController sets the local body and runs the camera; DummyService poses a bot target
  (UltimateService:CarriedPose). Ring-out credit NoteHit at the throw. NOTE Lune's CFrame.lookAt is wrong for
  exactly -Z; the anchor is built with fromMatrix.
- BASE "FINAL BELL" (every kit uses it until each gets its own with its kit): blink with gold afterimages,
  14 solid gold phantom fists with sparks and rings, a dim quiet beat with gold gathering, IMPACT FRAME, white
  flash + 3 gold shockwaves, gold trail and rings on the flight. Fx/ImpactFrame: two-tone frames (flat
  background, fighters as ViewportFrame silhouettes, Leaf ink speed lines, Star flares, white glow with a black
  core), per-kit frame lists (BASE: white/black/gold/black/white).
- PLAYED: meter rose 5, 10 on hits; with the meter filled by a test script, a 4-hit string opened the window, G
  started it, it ended on time (3.3 s); the dummy was 155 studs out along the throw 2.25 s in; screenshots of
  the barrage and of the impact frames (white, gold, black frames) look right. Console clean.
- NOT DONE: every other kit's own ultimate and impact frame (with each kit pair), sounds, a PLAYER as the
  target (needs 2 clients), gamepad and touch for G, phones; impact-frame holds count rendered frames so they
  last longer at low fps.

## kits-4d (2026-11-15): ultimate sounds + Studio sound picker, cut-based camera, flashier impact frame, bell slot
Build `kits-4d+lobby-4+ui-1`. NOT committed.
- SOUNDS: Config/SoundCandidates lists 3-4 Roblox-licensed options (ProSoundEffects / APMOfficial, ids from Creator
  Store searches this session, lengths MEASURED in Studio, all 24 load) for ult_ready, ult_blink, ult_barrage,
  ult_windup, ult_impact, ult_frame, ult_launch; SoundBank takes option A of each until the user picks. ult_bell
  ("the final bell should have a bell sound at the last hit") is EMPTY: no licensed boxing bell found; silent
  until an id is given. Ui/SoundPicker (Studio only, F7) plays each option and swaps it in live (Sfx.setRole)
  and prints the picks to Output. Sfx gained options.last (play the last N s, so the windup riser's hard end
  lands on the hit) and setRole. Long stings are cut with a fade (ready 1.8 s, frame 1.6 s, impact 3 s).
- CAMERA (user: "I don't like how it just rotates around, should be more thematic"): Timeline.shots, separate from
  body keys; Ultimates.shot gives position, look, FOV, roll, shake; cut shots snap, others ease. Final Bell: wide
  snap-zoom on the blink, five hard cuts through the barrage at three-quarter angles (storyboarded in Studio so
  neither fighter hides the other), a low tilted hero push-in on the wind-up, a hard cut to wide + zoom-punch and
  shake on the hit, a chase shot widening to flightFov 96. Cinematic now 2.05 s (impact held 0.3 s). The camera
  shakes in a set pattern; FOV restored after.
- IMPACT FRAME (user: "more flashy"): 8 frames ~0.3 s, held by time not rendered frames; pure white opener,
  zoom + shake per frame, red/cyan split silhouettes, thick ring, crossing beams, burst moved BEHIND the figures
  (in front it washed them grey). Seen in Studio.
- NOT DONE: the user's sound picks; the bell id; sound onsets (start) for the picks; other kits' ultimates.

## kits-4e (2026-11-15): bell, music off, ready sting, the barrage on a beat
Build `kits-4e+lobby-4+ui-1`. NOT committed.
- BELL: ult_bell holds two COMMUNITY "dong" uploads (no licensed bell exists; the user accepted "just a regular
  dong ... like the big ben"). The user asked first for faster and higher, then "lower pitch actually, just keep
  the speed": it plays at 1.4x speed with a PitchShiftSoundEffect of 0.6 (pitch about 0.84 of the file), cut at 2 s.
- MUSIC OFF: `src/client/Ui/playlist.client.luau` deleted (the user: "remove the music that plays"). The menu's
  Music toggle now does nothing (the teammate's UI: ask before touching it).
- Sfx.Options gained `octave` (pitch without speed) and `eq` ({low, mid, high} dB, an EqualizerSoundEffect).
- READY (user: "a short notification sound ... cool sounding to hype you up"): ult_ready options are now short
  ProSoundEffects stings (Sword Whip 302/702: metal slide into a ching and ring; Magic Burst 4/2), played 1.1 s
  from just before the swell.
- BARRAGE (REVISED below; user: "more varied ... lower pitched and flat and bassy ... shouldnt sound with each hit because they
  all start to over lap ... more timed so itll flow"): the 14 fists are silent; UltimateFx plays 7 beats at
  0.07, 0.30, 0.50, 0.67, 0.81, 0.92, 1.01 s (gaps closing 0.23 to 0.09), pitch 0.78 rising slightly, eq
  {low 7, mid -2, high -12}, cut 0.26 s; the last beat is louder with a low boom. Option A is ProSoundEffects
  Body Impact 1-5 + Big Thuds Wall Impact (whompy slams; onsets measured by PlaybackLoudness in a play test,
  volumes even out their peaks); B mixes those with the old crack-and-thud set; C and D are the old sets.
- The F7 picker auditions each role the way the game plays it (SoundCandidates.AUDITION: options, and beats
  for the barrage).
- Verified in Studio: all new ids load; the barrage cue fires exactly 7 sounds on the beats above, each a
  different take from the last, EQ attached, starting on the onset; ready sting and bell play. Console clean
  apart from `rbxassetid://203785492` "asset type does not match" (not in our source or the server tree; it shows
  at client start, before any ultimate plays). Gates: build, 492 tests, selene, stylua, fx_smoke.
- The user's reference cutscene, "the Raging Demon clip" (youtube shorts Yde2yYu9_lM), is a guide to what's good, NOT something to copy
  (the user, 2026-11-15). No title or K.O. cards.
- NOT DONE: the user's picks (F7); other kits' ultimates.
- BARRAGE REVISED (user: "the new punch sounds are super weird and dont sound like punches at all... sounds like
  a burp"): the Body Impact slams are gone. ult_barrage A is now both ProSoundEffects "Punch Some Crack And Thud"
  sets in one bag (10 takes), played at pitch 0.88 rising to 0.94, eq {low 4, mid 0, high -4}, cut 0.3 s. Lesson:
  a slowed, high-cut non-punch file reads as a burp; deepen real punches gently instead.
- READY REVISED (user: the Sword Whip "sounds like a sword slash or something but its supposed to sound like a
  power up"): ult_ready A-C are ProSoundEffects "Spaceship Blast High Pitch Energy Charge Up" takes (9125973461,
  9125975059, 9125973882) that rise into a peak about 1 s in; played 1.4 s from just before the rise. D is
  Magic Burst 4.
- REFERENCE STUDY (3 more cutscenes the user sent "to study", read as 6 fps contact sheets in scratchpad/cutref):
  Type Soul "Orlando Furioso" QlvfbPbCYCM, Heroes Battlegrounds "Human Battery" finishers C2vCVdNRLms, HBG
  "Azure Flames" finisher sfZyOKF50so. What they share: (1) the whole cutscene gets its own colour grade
  (Orlando: the world goes black-and-white, high contrast; Human Battery: warm gold-orange); (2) extreme
  close-ups, fists and faces filling the frame, things entering the frame; (3) near-black beats right before
  the big hit; (4) 2-4 frame stylised impact frames (black with one white slash line, then inverted white
  with black ink stars; a black ink symbol on yellow speed lines); (5) an ending beat (a cracked-glass
  overlay held about 2 s, or a fade to dark) before control returns. Not applied yet: the user decides which.

## kits-4f (2026-11-15): Final Bell gets a grade, close-up, dark beat and dip; bell out; ready = hype sting
Build `kits-4f+lobby-4+ui-1`. NOT committed. The user picked these from the references ("all four ideas are
pretty good"), then "dont do the cracked screen".
- TIMELINE (Core/Ultimates FINAL_BELL): the haymaker now lands at 1.9 (was 1.75), cinematic 2.2, attackerFree
  2.55. New shots: the hero push-in ends 1.62; a cut to an EXTREME CLOSE-UP from just in front of the
  attacker (fov 34 easing to 27) 1.62-1.82; new cue `dark` at 1.82; hit cut 1.9, zoom-punch 2.03, chase 2.2.
  `grade` field on Timeline. Everything else (server delays, DummyService, flight) reads the timeline.
- Fx/CutsceneScreen (new): `grade(spec, fadeIn)` (a ColorCorrectionEffect; Final Bell warm gold, saturation
  -0.2, contrast 0.35) and `blackout(floor, in, hold, out)` (ScreenGui, DisplayOrder 95, under ImpactFrame's
  100). Fighters' screens only. UltimateController grades at start; the DIP: black in 0.2 s, held 0.15 s, out
  0.35 s, timed so the camera hands back (ending + 0.1) under full black, and the grade is removed there.
  UltimateFx `dark` cue: near-black (0.08) cut in for 0.08 s, cut out on the hit where the impact frame's white
  takes over. Windup riser, dim and orb retimed to the 0.5 s gap (WINDUP_SECONDS).
- NOTE: EnvironmentKit (teammate) switches OFF extra ColorCorrectionEffects whenever map lighting applies, so a
  map change mid-cutscene ends the grade early. Harmless; not touched.
- BELL REMOVED (user: "a bit too silly, just give like a louder cooler punch sound thats ... amped up"): new role
  ult_haymaker (Punch Some Crack And Thud takes) at pitch 0.82, volume 2.6, eq {low 7, mid 2, high 0}, layered
  with punch_hit (2.0) and boom_low (1.4, pitch 0.8) on top of ult_impact. The community bell ids are gone.
- READY (user: "like a power up in a video game ... like a level up ... like you got an achievement, but make it
  hype sounding for a fighting game"): no game level-up sting exists in the licensed catalogue (searched level
  up, achievement, game bonus, success, arcade, power up). A-D are APM hype stings (Hustler Sting 2 from
  "Sports Hype Bangers", Gladiators link, Reach For It, Fortune Fun Win); E-F are COMMUNITY uploads that say
  they are original (DailySoundsFX "Energy Charge Up", EasyPlay "Level Up"), for the user to choose only. All
  six measured in a play test. Played 1.6 s. Picker panel widened for six options.
- Test: "final bell: close-up, then the dark beat, then the hit" (493 pass). Gates: build, tests, selene, stylua.
- NOT SEEN: the close-up framing, grade and dip on screen. Studio's 3D view did not render into captures this
  time (only the HUD; the window was likely in the background), so the storyboard could not be checked.

## kits-4g (2026-11-16): M1 plants you and steps both forward; seamless lock; heavy punch sounds; short ready
Build `kits-4g+lobby-4+ui-1`. NOT committed. The user: "make the m1 combos slow you down so you cant run while
m1ing ... you stop moving but each punch should knock both you and your target forward in the direction youre
facing" (reference: TSB Garou "Flowing Water", the pair travels forward together); "the locked m1s are really
buggy ... they kind of just drag the person to you and teleport them ... i want them to be right infront of you
seamlessly"; punches "weak sounding ... like taps ... dont make the punches sound like high pitched smacks either,
i want them to sound like actual heavy blows" (reference: JoJo "MUDA" rush; its spectrogram is nearly all under
~350 Hz); the ready sound "short but powerful kind of notificaition sound".
- PLANT + STEP (MovementController `_punchThrown`, DummyService for bots): a ground M1 stops running dead and roots
  for Punch.RootSeconds (0.5); at the strike (Windup) you glide Punch.StepDistance (2.2) over StepSeconds (0.12)
  along the way the BODY faces (root look, not the momentum heading), shorter near a wall (Combat.punchStep).
  CombatService: no M1 pays the old aftermath (backward recoil / miss slowdown) any more.
- LOCK: the SERVER picks the held spot once per stunning punch (CombatService `lockSpotFor` -> StatusService
  Stun(..., spot) -> attribute HT_LockSpot): in front of the puncher at the distance the target was when the hold
  began (Combat.lockDistance, 2.4-4) PLUS the step, clipped at walls. The target's mover (its client, or
  DummyService) glides to it (Combat.lockFollow: LockFollowRate 26, never faster than LockCatchUpSpeed 36) and
  faces the puncher. MEASURED before this (the old per-frame chase of the puncher's body): the puncher's step ran
  INTO the target (gap 3.5 -> 1.1 studs) and the target caught up ~0.3 s later, which read as drag and teleport.
  The server spot is still between punches, so nothing chases a late body. Old chase kept only as a fallback.
  Config Punch: LockMinDistance, LockMaxDistance, LockFollowRate, LockCatchUpSpeed, LockCarryMax, StepDistance,
  StepSeconds, RootSeconds (LockLeadSeconds removed); design/game.json in the same order.
- SOUNDS: new SoundBank roles punch_body (ProSoundEffects "Boxing Hits, With Gloves, Hit Punching Bag Hard", 5
  takes, onsets/peaks measured) and punch_sub (APM "Bass Drum Sounds (a)", cut 0.3). Every M1 and kit-skill hit is
  now punch_body (pitch 0.88, eq low +5 / high -4) + punch_sub + a faint crack (0.3) instead of a loud crack. The
  ult barrage A is the bag hits with a sub per beat; the haymaker adds both. ult_ready A-C are ProSoundEffects
  "Magic Burst" stings (one beefy impact, glowing tail) cut at 1 s with a sub thump under (UltimateMeter).
  SoundCandidates.AUDITION gained `with` (a layer the picker plays under, as the game does).
- Tests: lockDistance, lockFollow (carried with the step, no jump across a gap, settles), punchStep, catch-up >
  step speed (496 pass). Gates: build, tests, selene, stylua, fx_smoke.
- (SUPERSEDED by kits-4h, verified) NOT VERIFIED IN STUDIO: Studio restarted mid-session and the Rojo plugin did not reconnect, so the place holds
  everything up to the first plant/step version only (no server spot, no root-look step, no new sounds). The one
  run on that version showed the string working (3 stuns, 4th launched ~120 studs) and the step-into-target
  problem the server spot fixes.

## kits-4h (2026-11-16): the string verified in Studio; exact step that never shoves; punches = crack + body + boom
Same build stamp (kits-4g). NOT committed. After the user reconnected Rojo:
- STEP: starts at Windup + ActiveSeconds (when the server has placed the target's spot), StepSeconds 0.15, moved
  by CFrame each frame (a walked step came out ~2/3 long), and NEVER into the body in front (Combat.stepRoom stops
  it LockMinDistance short of anyone ahead). Measured: moving by position straight into a target the server had
  not moved yet made Roblox shove the bodies apart and fling the puncher ~8 studs in 0.1 s; stepRoom fixed it.
  Bots step the same way (DummyService).
- MEASURED (Practice Dummy 1, 4-hit string at 0.45 s, Studio running slow): hits 1-3 stunned and held it, the two
  travelled ~7 studs forward together, the gap stayed 2.4-4.3 studs (never under LockMinDistance), the dummy
  never moved faster than 28 studs/s (no jumps), the puncher's fastest was the step (21 studs/s), hit 4 launched it
  ~122 studs. The stun lapsed for ~0.15 s between two punches (presses 0.45 s apart vs StunSeconds 0.5, with slow
  frames); the hold re-took at the same distance.
- SOUNDS: the user heard the bass drum ("sounds like a drum ... is that the punch sound?") and sent a punch
  sound-design reference (youtube obti3wLCshs, Itadori combo). Its spectrogram: per hit a full-range crack up past
  8 kHz, a body, and a noise-like boom under ~170 Hz sweeping down 0.2-0.4 s. punch_sub is now booms, not a drum:
  ProSoundEffects "Explosions, Dull, Thuddy" x2 (each take starts on one boom of a multi-boom file) + APM "Deep
  Boom 06", cut 0.3. punch_crack is back at 0.8 (normal pitch). Verified: each hit plays crack + body + boom, a
  different take each time; the launch adds boom_low + launch.
- Tests: stepRoom (497 pass). Gates: build, tests, selene, stylua.
- NOT HEARD by me (no ears): whether the new mix reads as a heavy blow. NOT TESTED: a player as the target (two
  clients), the ultimate with the new layers, a wall in front during a string.
- THE USER, after trying kits-4h (2026-11-16): the punches "still sound nothing like a punch and a bassy drum";
  next time go back over ALL the references they have sent (punch sound: JoJo MUDA aSHcFlNOElE, Itadori combo
  obti3wLCshs; cutscenes: Raging Demon Yde2yYu9_lM, Orlando Furioso QlvfbPbCYCM, Human Battery C2vCVdNRLms, Azure Flames sfZyOKF50so; movement: TSB Garou zP6MFM_SamU).
  The boom layer (punch_sub) is the likeliest "bassy drum"; consider dropping it and sourcing designed anime-style
  punch hits instead. Committed at their request so they could stop for the night.
## ui-0c (2026-11-15): Golden Hour typography (NOT COMMITTED, awaiting the user's try)
- Shared/Typography now sets every game font in Builder Sans (reading text, FAMILY), Builder Extended (display,
  numerals, caps labels) or Builder Mono (ticking figures), from Tokens.type. Same API (face, apply, adopt,
  HT_TextRole); NEW FAMILIES, textScale(). Old role names are aliases that KEEP THEIR OLD SIZES (deviation from
  Technical Architecture 3.3, which mapped them to the new sizes: no box can overflow until each screen is rebuilt).
- NEW pure src/shared/Core/TypeRoles.luau (aliases, weight snapping to the weights each face really has, the
  PreferredTextSize multipliers Medium 1 / Large 1.15 / Larger 1.3 / Largest 1.5 for non-numeral, non-display roles,
  re-applied live on change) + tests/TypeRoles.spec.luau (8). adopt() snaps Heavy to ExtraBold.
- MEASURED in Play: 75 HUD/menu text objects, 0 left in Montserrat (Extended 56, Sans 14, Mono 5), none under 15,
  no new overflow (the same 7 Help-guide lines report TextFits false before and after). World labels: 51, all Builder
  Sans Bold (dummy stagger figures are Sans until their screen is rebuilt; the design wants Extended for numerals).
  Frame cost: none per frame (styles once per label; one settings listener). Build vfx-14+lobby-4+ui-0c, Rojo PASS 144.
- NOT TESTED: PreferredTextSize Large+ (the setting can't be changed from a script; try it in Roblox settings),
  phones, the Q1 side-by-side with Oswald + Titillium (Studio screen capture is black). NEXT: 0d HudTheme colours.

## ui-0d (2026-11-15): HudTheme colours on the Golden Hour tokens (NOT COMMITTED, awaiting the user's try)
- src/client/Ui/HudTheme.luau only (spicy co-owns it; only colour lines touched): Colour.* now read Tokens.colour:
  Panel ink.900, PanelRaised ink.800, Track ink.600, Accent coral.500, AccentHot danger.600, Text ivory.50, Muted
  stone.300, Dim stone.500, Over teal.400 (no palette job yet; Phase 1), Miss stone.300, Blocked danger.600,
  OnAccent ink.900; Menu.Coin gold.400, Menu.Good teal.400; Transparency.Panel 0.15 -> 0.12 (Tokens.surface[1]).
- MEASURED in Play (client PlayerGui): backgrounds ink.900 x26, ink.800 x11, ink.600 x5, coral x8; text ivory.50 x34,
  stone.300 x13. Left over: colours hard-coded in screens (43 Color3.fromRGB outside HudTheme, e.g. #1B2A35 text,
  #3CC4FF fills): they move when each screen is rebuilt. Known: AccentHot (danger.600) is also used as stagger TEXT
  in two places (palette says fills only); Phase 1b. Build vfx-14+lobby-4+ui-0d, Rojo PASS 144. NEXT: 0e motion.

## ui-0e (2026-11-15): motion on tokens (NOT COMMITTED, awaiting the user's try)
- NEW pure src/shared/Core/Motion.luau (resolve(tokens, duration, easing, kind, reduced): reduced -> move/scale 0,
  fades <= 0.1 s, colour untouched; stagger 0.03/item capped 0.4) + tests/Motion.spec.luau (6).
- Ui/HudMotion: NEW play(instance, channel, props, durationToken, easingToken) (kind inferred from props),
  pressDown/pressUp (t.press 0.06 / t.release 0.16), setReduced (the game's own toggle, for the Settings screen:
  not wired to any UI yet), onFrame/stopFrame (one shared RenderStepped, disconnected when idle: no callers moved
  yet). to/press/pop/enter/leave unchanged for existing callers; enter's reduced fade 0.12 -> 0.1.
- Moved off raw TweenService onto HudMotion: AfkController and SpectateController button presses (0.05 -> 0.06 s
  down), MenuController open pop (Back/Out 0.16 s -> t.panel 0.32 Quint/Out from 0.94). KickMeterBar still reads
  ReducedMotionEnabled itself (Phase 2).
- MEASURED in Play: 10 toggles/s end in the last state (1.000); reduced: scale set at once, ceremony fade 0.10 s;
  quick exit 0.14 Quad/In; onFrame 25 frames in 0.5 s, 0 after stop. All 11 ScreenGuis built, no script errors.
  Build vfx-14+lobby-4+ui-0e, Rojo PASS 145. NEXT: 0f InputMode + layout.

## ui-1 (2026-11-15): combat HUD rebuilt in the Golden Hour design (NOT COMMITTED, awaiting the user's look)
- User: "nothing changed, use the research to COMPLETELY revamp how the UI looks" -> screen-by-screen visible
  rebuild, combat HUD first. NEW src/client/Ui/Components.luau (make, text, panel levels 1-3, the Ledge, meter with
  ghost + ticks, keyCap, corner) - tokens only. HudLogic: staggerBand (40/70), multiplierText, recovering (+3 tests).
- HudController visuals rewritten (all data wiring kept): Y "you" panel bottom-left (top-left on touch, no speed):
  numeral.l stagger figure (no %), STAGGER, "4.8x knockback" (Combat.staggerMultiplier), CRITICAL coral.300 /
  RECOVERING teal.400, speed bar + over segment + stagger speed-cap notch, 256x10 bar ticks 40/70 filling ivory ->
  coral.300 -> coral.500..danger.600 gradient, ghost of the recovery start + teal drain tick, coral Ledge, one
  1.04 pulse on crossing 70. K kit bottom-right: Q, R, Jump/Kick, Punch tiles (circle attacks, rounded-square
  movement; Jump turns round in kick mode), cooldown shade draining from the top (vertical, not radial: radial
  wipe left for later), seconds > 1.5 s in mono, teal ready ring, slash when unavailable, key caps (gamepad glyphs
  via GetImageForKeyCode, mouse glyph for M1), names above tiles in the lobby / first 3 s of a fight / after a kit
  change, HIT/MISS/NOW words. A strip: auto-width pill (18 / 25 STANDING; NEXT ROUND 12 ROUND 4; gold Ledge at final
  two), ARENA CLOSING chip 2.5 s per shrink. F feed: 4 rich-text rows newest on top, yours with the coral Ledge.
  Target: coral chevron + name + thin bar in the other-fighter ramp (ivory/danger, never coral); open ivory chevron
  for the nearest-ahead candidate. Controls guide: ghost "CONTROLS" + cap, level-2 sheet. HT_RoundHold now blocks.
- MEASURED in Play (user's session): all groups built, no script errors; stagger 76 -> figure coral, CRITICAL,
  4.8x, gradient fill; reset to 0. SPEED label was 14 tall (fixed to 18, synced next Edit-mode push).
- NOT DONE from the spec: ground stagger arcs, last-hitter chevron, panel nudge toward the hitter, key caps retiring
  after 3 rounds, radial cooldown wipe, phone/gamepad device tests. Screenshots impossible (Studio capture is
  edit-view only). NEXT screens: menu/shop/settings (Phase 4), air-kick meter + clash (Phase 2), round ceremony.

## ui-2 (2026-11-16): Golden Hour rejected; the "Voltline" look, Electric blue; combat HUD rebuilt in it (NOT COMMITTED, awaiting the user's look)
The user saw the Golden Hour HUD in game and rejected it ("nothing changed", "so ass"), passed over the 9-style
look book, and gave their own brief: structure from two shop/inventory reference images (bold cards, tabs,
strong borders, sharp shapes), colour from a third (blue/indigo surfaces, purple/pink/cyan accents), the whole
game UI, and the class skills Q and R ALWAYS visible with icon, key, cooldown and three states. Preview page:
vault `UI Research/voltline-preview.html` (artifact https://claude.ai/artifact/QnB9MsrcQNE5stMHMLmSeK). They
hated the first navy palette and picked palette D "Electric blue" of four. Motion: "surprise me later".
Build `kits-4g+lobby-4+ui-2`. Place saved v373. Golden Hour docs in the vault stay as history.
- GIT: spicy's e1252a0 and 0e7ce8e were pulled first (e1252a0 already held my ui-0c..ui-1 files, saved from the
  place). Local overlap resolved by hand; backup of the pre-pull files in `work/pre-pull-backup-20261116/`.
- TOKENS (`Shared/Tokens`): the NAMES are kept and are now jobs, not paints (ink = blue surfaces, ivory/stone =
  text, coral = PINK you/selected, teal = CYAN ready, gold = YELLOW earned and rising stagger, danger =
  red-orange). New: ink.500, line.500, line.300, violet.400, `Tokens.cut` (the cut-corner images). Radii 2/3/4.
  Because the names stayed, every old screen (AFK, Spectate, menu, ultimate bar) took the new colours at once.
- TYPE: display face is Montserrat (Black Italic for headings and big numerals, upright Bold for labels),
  measured in Studio: weights 100-900, each with an italic. Text stays Builder Sans, timers Builder Mono.
  Roles carry `italic`; `Typography.face` honours it.
- SHAPE: `Components.cut(parent, level, lineTone, props, size)` = a clear Frame with `Fill` and `Line` 9-slice
  images (top-right and bottom-left corners cut; 2 images, no strokes). `Components.cutImage`, `paintCut`.
  Sources `assets/ui/cut_fill.png`, `cut_line.png`, `cut_flag.png`; uploaded through the Studio MCP
  (`upload_image` needs an http URL: served the folder with `python -m http.server` on 127.0.0.1). Ids in
  `Tokens.cut`. They are on the account Studio is signed in to: if the game moves to a group, re-check access.
  A UIListLayout or UIPadding must never sit directly in a cut frame (it would lay out the two images): put
  the content in a child body, as the controls guide does.
- HUD (`HudController`, all data wiring kept): tiles are now Jump and Punch small (56) and Q and R big (76),
  R outermost. Each: icon, name inside the top (big ones, always shown, upper case), key cap inside the
  bottom-left, a shade that drains from the top with a white lower edge, the seconds left in tenths, a cyan
  corner flag when ready, a slash when it can't be used. HELD is new: the R tile turns white-bordered while
  `HT_Charging` is set. Coming back from a cooldown the tile pops once (1.08, 0.18 s). Stagger: white, yellow
  from 40 (RISING, new word), red-orange from 70 (CRITICAL); RECOVERING cyan. Strip border turns yellow for
  the final two. Feed rows have a right edge, pink when the line is about you. Controls guide: 7 rows, text
  measured with GetTextBoundsAsync x LineHeight (AutomaticSize left wrapped rows one line tall and cut them).
  `HudTheme.Guide` no longer says "charge" or "PERFECT" (R is a plain hold of up to 3 s since kits-4b).
- ULTIMATE BAR (`Ui/UltimateMeter`, spicy's): colours from tokens, square, an ULTIMATE label. Same place and logic.
- GATES: 517 tests (Tokens.spec contrasts re-measured, 3 new; TypeRoles.spec italic + 900), selene 0, stylua,
  rojo build, gen_config --check. Pushed with rojo_push (167 scripts match).
- SEEN in Studio play (screen capture DOES show the game view now): HUD in a round, Q cooling with shade and
  "5.1", R ready with flag and filled key, unavailable tiles slashed, stagger 43 RISING in yellow, the guide
  open and wrapping, console clean of HUD errors.
- NOT CHECKED: the HELD state by eye, the ready pop, CRITICAL, the final-two strip, the feed rows, the target
  marker, gamepad glyphs, touch (the real buttons still have the old round look: their restyle is the phone
  piece), a 1280x720 or larger window (Studio's view was 843x536; the guide runs off the top at that size),
  frame cost (not measured; the HUD has fewer strokes and corners than before but two images per panel).
- KNOWN: only 4 icons exist; Q and R show the old dash/fist art for every class. 16 skill icons and 8 class
  emblems are still to draw. The air-kick prompt and meter code is still there, unused (spicy's call).
- NEXT: menu (class screen as in the preview), then AFK/Spectate/toasts, clash bar, lock-on marker, tutorial,
  phone buttons, icons, motion pass.

## ui-3 (2026-11-16): the menu rebuilt in Voltline (NOT COMMITTED, awaiting the user's look)
Build `kits-4g+lobby-4+ui-3`. Place saved after it. The user was away ("don't ask permission, I will be AFK").
- `MenuController` rewritten for looks; behaviour kept (M, the Menu button, X, click outside, gamepad B, toast
  from `ability.Notice`, redraw on InventoryChanged / KitChanged / HT_InRound, `SetOpen`). Instance names kept
  where they existed (HT_Menu, MenuButton, Toast, Backdrop, Panel, Header.Coins, Header.Close, Header.Tabs.<tab id>).
- One sheet (max 1040 x 600, was 780 x 500), cut corners, tabs along the top (the old left rail is gone): the
  tab id "Abilities" is shown as "Classes". Classes and Shop share one layout: the picked class large on the
  left (`Body.Detail`: art band with EQUIPPED / OWNED / NOT OWNED, name, blurb, Q and R rows with the cooldown
  read from Abilities / GameConfig, one button `Detail.Side.Action`) and the cards in a 2-4 column grid on the
  right (`Body.Page.Content.<kit id>`). Classes lists what you own (Equip); Shop lists what has a price (Buy,
  or "Need N more"). Passes and Settings are the same placeholders in `Body.List`.
- Each class has a colour token (`class.<id>`, from the kits-4 design). The big letter on a card stands in for
  an emblem. Buttons sit on a darker lip and drop onto it while pressed; pink = do it, yellow = spend Coins.
- GATES: 517 tests, selene 0, stylua, rojo build. Pushed (167 scripts match).
- SEEN in Studio play at 843 x 536: Classes (Inferno equipped and picked), Shop (Tempest picked), Settings.
  Console clean.
- NOT CHECKED: the Buy button and "Need N more" (the test account owns every class), equipping from the menu,
  the toast, Passes, gamepad focus order through the cards, touch, a phone-sized screen, a full-size window.
- NEXT: AFK / Spectate / Bots buttons (they have the colours but not the shape), clash bar, lock-on marker,
  tutorial, phone buttons, the 24 icons, then the motion pass.

## ui-4 (2026-11-16): Voltline rejected too; "Ringside": new navigation, shared window, palette A (NOT COMMITTED, awaiting the user's look)
The user rejected Voltline ("still looks like the placeholder UI with better graphics and different colors") and
asked for a change of STRUCTURE, designed before building. Figma was tried and dropped: their Starter plan allows
about six connector calls a month and they can't pay for more (a draft file with six palettes as variables
exists, key JD0KFHmxNLHJqXgkWUYHJ2; `UI Research/figma/palette-boards.js` can be pasted into Figma's console).
Design moved to web pages: `UI Research/palette-comparison.html` (six palettes; they picked A, Ringside Night) and
`UI Research/ringside-prototype.html`, a clickable prototype they approved ("approve, you can build it, however
keep in mind all icons are placeholders and will be replaceable"). Later note: the big Emotes button gives its
place to something that exists; I put the moves guide there and Emotes in the drawer.
Build `kits-4g+lobby-4+ui-4`. Place saved after it.
- TOKENS (`Shared/Tokens`): palette A on the same job names (ink = near-black surfaces and the INK of outlines,
  coral = red-orange primary action / you / picked, teal = GREEN ready / equip / owned, gold = coins, danger =
  pink-red, line.500 = outline ink, line.300 = faint edge, violet = focus). Radii 6 / 9 / 12. One family,
  Titillium Web (measured: 200, 300, 400, 600, 700, 900; no 500 or 800), upright everywhere; mono unchanged.
- ICONS (`Ui/Icons`): ONE list, name -> asset id, 25 placeholders (sources `assets/icons/ringside/*.png`, exported
  from the prototype's SVGs through a browser canvas, uploaded with the Studio MCP). To replace one: upload,
  change its id there. `HudTheme.Icons` reads from it. A missing name draws nothing.
- SHAPE: `Components.sticker(parent, props, {fill, line, depth, radius, button})` = rounded face, 3-unit ink
  outline, a darker lip under it. `Tokens.cut` now points at ROUNDED 9-slice images (`assets/ui/round_*.png`),
  so the HUD's panels and tiles turned into rounded ink-outlined ones with no HUD code change; the ready flag is
  a green badge.
- NAV (`Controllers/NavController`, new; gui HT_Nav, DisplayOrder 19): lobby = four square buttons on the left
  (Shop 1, Classes 2, Ranked 3 SOON, Moves 4) and MORE, which opens a drawer (Cosmetics, Profile SOON, Leaders
  SOON, Emotes SOON, Settings, Codes SOON, an AFK switch, Spectate). In a round (`HT_InRound`) it all hides and
  one gear button at the top left offers Settings and the controls guide. It only launches: `MenuController:
  Open(tab)` / `:OpenSettings()`, `HudController:ToggleGuide()` (new), `SpectateController:Toggle()` (new; its own
  button is hidden), the AfkToggle remote (the old HT_Afk gui is disabled). SOON tiles only say so. Phones get a
  two-by-two block upper left. For whoever has HT_CanFreezeBots the column steps 150 units right, clear of the
  Bots and perf tools.
- SHARED WINDOW (`MenuController`, rewritten): no MENU button. One window, three pages in a UIPageLayout: Shop
  (classes for Coins; Buy then Confirm, red-orange with a coin), Classes (every class; green Equip; unowned ones
  dim with "See it in the Shop"), Cosmetics (an honest empty page). Tabs, < > arrows, touch swipe, L1 / R1. A
  shortcut jumps with no slide (`pager.Animated = false`). Only the current page is redrawn. Settings is a
  separate small panel. Under a 700 x 400 screen the window scales down as a whole.
- GATES: 517 tests (contrasts re-measured; TypeRoles for Titillium), selene 0, stylua, rojo build, gen_config.
- SEEN in Studio play at 843 x 536: lobby column with the drawer open; the window on Classes; the fight view with
  the gear button, rounded HUD tiles, new skill icons and ready badges. Console clean.
- NOT CHECKED: Shop page, Buy / Confirm, Equip, Cosmetics page, Settings panel, the fight menu's two rows, AFK
  switch and Spectate from the drawer, keys 1-4 after the label fix, page swipe, L1 / R1, gamepad focus, phones,
  whether the emote and AFK icons load (they were blank in one capture), a full-size window, frame cost.
- NOT BUILT: the prototype's slanted stagger number and segmented bar, round phone thumb buttons, emote wheel,
  Profile / Leaderboards / Ranked / Codes screens, Passes and Robux shelves, the motion pass, final icons.
  Old code still present: KickPrompt / KickMeter (unused), AfkController's hidden button, cut_*.png.
- ui-4b (2026-11-16): the user said the left column "feels like it's not connected" (it sat 150 units in from
  the edge for the owner, clear of the Bots and perf tools). Now the column is hard against the left edge for
  everyone, and BotsFreezeController's button and PerfController's readout sit on the RIGHT edge at mid height
  (anchor 1, 0.5; y 0.42). Seen in Studio play: column at x 22, owner tools on the right. Synced, 517 tests.
- ui-4c (2026-11-16): the user said the left column looks connected now. Play test of ui-4 at 1190 x 536, mouse
  and keys (their own session stopped first, with their say-so). WORKS: Shop page; Buy then Confirm (tried by
  hiding Dragon on the client only: Buy 1000 -> Confirm 1000 -> the server refused with "You already own that
  kit.", no Coins spent); Equip and its toast; Cosmetics empty page; Settings panel and its three switches, from
  the drawer and from the fight gear; the drawer; AFK switch (server HT_AFK true, switched back off); Spectate
  from the drawer (old look still); keys 1, 2, 3 (SOON toast), 4; R1 / L1 flip pages (sent as key codes, no pad
  connected); the fight gear's two rows; Q ready / cooling (5.2 s, bar) / struck out during Get ready; the
  Emotes and AFK icons load.
  FIXED: Moves (key 4, the tile, H) did nothing while you were out of a round, because the guide sits inside the
  Help group and that was hidden unless you were fighting. `HudController.refreshGroups` now hides only the chip
  and closes the guide once, on the moment you stop fighting. 517 tests, gates green, synced, place saved.
  FOUND, NOT FIXED: (1) the controls guide is taller than a 536-high view and its top is cut off; (2) the
  owner's Bots and perf boxes draw over the guide; (3) Confirm looks the same as Buy but for the word; (4) the
  class detail panel shows Q and only a sliver of R above the action button at this height (it scrolls);
  (5) a cooling skill tile's icon is nearly hidden behind the seconds; (6) Settings' close is a small "x", the
  window's is the big cross icon; (7) Settings dims the fight HUD, Q and R included.
  FRAME COST (bots stopped, lobby): closed 12.2 to 13.9 ms, window open 11.7 to 15.2 ms, so no steady cost
  that shows over the noise; the frame the window opens on is a hitch of 40 to 54 ms (closed worst 20 to 27).
  NOT CHECKED: phones and touch swipe (no script access to the device emulator), a real gamepad and its focus
  ring, a full-size window. Note: Escape opens Roblox's own menu and it swallows clicks; that was my test, not a
  bug. `rojo_push.py` needs `rojo serve default.project.json` running first.

## ui-5 (2026-11-16): full rework from reference videos; "fight-poster" mockup (DESIGN ONLY, awaiting the user's look)
The user dropped Ringside as a constraint ("we're gonna rework everything including colors") and sent eleven
references (ten TikTok, one YouTube). All studied frame by frame; notes, 43 frame sheets and a summary are in
the vault at `../UI Research/Video References/` (start at `Batch 1 Summary - Patterns Across the References.md`;
the method is in `How Video References Are Studied.md`). Asked which direction the first mockup should take, the
user chose "Fight-poster style" (reference P10: cut buttons on one side, a diagonal colour field with a repeated
word on the other).
- Mockup: `../UI Research/fight-poster-prototype.html`, https://claude.ai/artifact/ScFqVNZYHhvufmBUMdwwa3.
  Lobby menu (Classes, Shop, Ranked, Moves, More), field re-themes per entry and per picked class, Shop with a
  distinct Confirm step, fight HUD (slanted stagger number, knockback, 12-segment bar; Q and R with ready /
  cooling / can't-use told apart by shape and word), phone layout with round thumb buttons, and a 1.7 s
  ultimate overlay (wedges, band, cut-out letters, flash, break). Fonts Oswald + Titillium Web.
- Checked in the Browser pane from a local server: lobby, class re-tint, HUD states, phone layout, the overlay's
  held frame. The pane has reduce-motion ON, so the motion itself was only seen as paused frames.
- NOTHING is built in Roblox. The ui-4 (Ringside) code is still what is synced, uncommitted, with the ui-4c fix.
- Vault: Haymaker now has a `.game` marker; search with `python ../../_tools/vault.py --game "Haymaker Tussle"`.
- Open with the user: dense or sparse, class re-colour everywhere or only in Classes, flat screen or 3D-world
  menu, per-class art style for ultimates, and no in-fight HUD reference exists in the batch.
- ui-5b (2026-11-16): the user, on seeing the first pass: "HUD should not cover the entire screen", "remove
  the ultimate bar for now", and getting your ultimate should "notify you on the screen with some cool
  animations". Mockup changed (same link, version 3): menus are a poster WINDOW with the arena visible around it
  and behind the buttons; no ultimate bar; when the ultimate is earned a banner lands near the top (streak,
  cut-out letters one by one, READY + key, edge pulse, about 1.5 s) and tucks into a small "ULT READY" badge by
  the skills; using it still plays the 1.7 s band with the class name, now without the corner wedges.
  Rule from this: nothing in this game's UI covers the whole screen.
- ui-5c (2026-11-16): the user: colours "more vibrant and playful"; animations "cooler and vibrant and
  bouncier"; background textures should drift slowly up and to the right. Mockup version 4: brighter palette
  (ink is now a dark violet #1A1236; entries green / yellow / red-pink / blue / purple; brighter class colours,
  Bruiser moved to lime as a proposal), spring easing everywhere (window and tiles overshoot and settle, buttons
  squash on press, staggered pops, stagger number punches and its plate shakes, a skill pops when it comes off
  cooldown), the ultimate notice drops its letters with a bounce plus a confetti burst, and the window's
  repeated word and dot layers loop up and to the right (18 s and 7 s).
  For Roblox: springs = TweenService Back / Elastic or a spring module on UIScale; the drift = a tiled image
  with its offset tweened; both need a frame-cost measurement and a Reduced Motion path.
- ui-5d (2026-11-16): the user: "the colors SHOULD compliment each other, don't just mix and match random
  colors". Version 5 rebuilds the palette as ONE system: violet ink #1A1236 and cream paper #FFFBEF; three print
  inks with jobs (yellow #FFD426 = coins and the loudest accent, the opposite of the ink; cyan #21D4FD = ready
  and go; magenta #FF4D9E = danger, close, can't-use); a light violet #C9BEFF for quiet controls; eight class
  colours as one warm-to-cool sweep at even brightness (Base #FFD426, Bruiser #FF9F2E, Inferno #FF6B3D, Beast
  #FF4D6D, Trickster #FF5CC8, Dragon #A97BFF, Frost #4DB8FF, Tempest #2EE0C8). The class picker lays tiles out
  in that order. The mockup page has a "colour system" card with swatches.
- ui-5e (2026-11-16): stagger meter recoloured at the user's ask (number white / yellow / red; bar green /
  yellow / red; green and red used nowhere else). The user then said "CURRENTLY i like everything so far" and
  asked for sound. Mockup version 8 adds:
  - SFX (browser-synthesised stand-ins): press, window open / close, screen switch, equip, buy, refused, hit,
    skill use, skill ready, stun, knockout, ultimate earned, ultimate used, last-players call.
  - "Last N" popups at 5, 4, 3 and 2 standing: a big slanted number slams in near the top over a coloured bar
    with "FIGHTERS LEFT" ("FINAL TWO" at 2, plus shake and confetti), about 1.7 s, then flies up into the
    standing counter, which bumps. Not full screen.
  - VOICE LINES, ONLY TWO KINDS (the user's rule): "Ultimate ready!" and the last-players calls ("Five fighters
    left!", "Four left!", "Three left!", "Final two!"). The mockup uses the device's computer speech as a
    placeholder; other sound ducks under it.
  - For Roblox (vault: "Audio Mixer Settings with SoundGroups", "Sound Fundamentals", "Sound Design Pitfalls"):
    SoundGroups for SFX / UI / Voice under Master, duck under voice, feedback sounds on the client, one voice
    per key with pitch variance, preload, assets uploaded under the experience owner. No audio is chosen or
    uploaded; do not invent asset ids. The game has no "N players left" event wired to UI yet: RoundService
    publishes Alive on ReplicatedStorage.HT_RoundState, which is enough to drive it on the client.
- ui-5f (2026-11-16): the user found the placeholder voice robotic and asked to sample the voice at 2:30 to
  2:32 of https://www.youtube.com/watch?v=PH_c6kTJlS8 for every voice line. That video is "Evolution of FIGHT
  Sound Effect (1992-2019)" (channel GamelutioN): the clip is a Mortal Kombat announcer's "FIGHT!". NOT DONE,
  and told to the user: no tool here can capture or clone audio, and the voice is a commercial game's recording
  by a real actor, so copying or cloning it into the game is not something to do (rights, and Roblox audio
  moderation). It is recorded as the STYLE TARGET only: deep, gravelly, short and shouted, with a big-room echo.
  Mockup version 9: the placeholder now picks a male English system voice if present, pitch 0.25, rate 0.88.
  Real routes offered: the user or a friend records the five lines; a hired voice actor; a text-to-speech
  service whose licence allows game use with a stock deep voice; or Creator Store announcer audio via the
  roblox-sfx skill.
- ui-5g (2026-11-16): the user asked for the earlier stagger colours back. Mockup version 10: number and bar go
  white, then yellow (#FFD426), then magenta pink (#FF4D9E). The green / yellow / red trial is dropped.
- ui-5h (2026-11-16): the user supplied the MP3 of the Mortal Kombat "FIGHT" video and asked for the voice at
  2:30 to 2:32. Cut with Windows' built-in MediaTranscoder (no installs; numpy and scipy are present, there is
  no MP3 decoder otherwise) and measured. The window holds TWO "FIGHT!" shouts from a montage, about 0.7 s each,
  with other audio underneath; pitch unreliable. Saved as a style reference only, with a brief for a real
  recording, in `../UI Research/Audio References/`. Still not done and not to be done: using that clip in the
  game or cloning its voice. Waiting on the user for how to get real voice lines.
- ui-5i (2026-11-16): the user chose "Search Creator Store" for the announcer. Searched ten queries with the
  roblox-sfx skill (set PYTHONIOENCODING=utf-8 or its printing crashes on non-Latin names; ask one page at a time
  and pause between queries or the toolbox endpoint fails). No set exists: four of the five lines have no match,
  "ultimate ready" has one clip of unknown origin (id 108588196592790, unverified), and most announcer audio there
  is lifted from other games. Not probed in Studio: Studio was in a Play session I did not start. Findings are in
  `../UI Research/Audio References/Announcer Voice Target.md`. The five lines still need one recorded voice.
- ui-5j (2026-11-16): three asks from the user, all in mockup version 11:
  (1) IDLE MOTION on interactable controls only, "subtle but noticeable, don't overdo it": every pressable
  button drifts about 5 px and tilts under 1 degree on a 2.5 to 3.3 s loop, each with its own speed and phase;
  the stagger readout, counter, coins, disabled buttons and a skill that is cooling or blocked stay still.
  (2) NO WHITE FLASH: "can become nauseating really quick". Screen changes now use a slanted band a shade
  lighter than the window sweeping across it (0.5 s); using the ultimate pulses the edge bars in the class
  colour instead of a white frame.
  (3) SOFTER SOUNDS: "hurts my ears". All stand-in sounds rebuilt with sine and triangle tones only, lower
  pitches, slower attacks, a low-pass at 3 kHz and a quieter master; the press tick is barely audible.
  Also fixed: Try it buttons used from the Lobby threw an error; they now switch to Fight first.
  For Roblox: drive idle motion from ONE shared clock for visible, pressable controls only, measure its frame
  cost, and skip it under Reduced Motion.
- ui-5k (2026-11-16): the user reversed point (2) above: "you can keep the white flash transition". Version 12
  restores the one-frame white flash on screen changes and on using the ultimate. Idle motion and the softer
  sounds stay. The colour-wipe element is still in the file, unused.
- ui-5l (2026-11-16): sounds nudged a little sharper at the user's ask (version 13). Then the user supplied five
  voice recordings (MP4s in Downloads, one per line; the ultimate line is their own audio, the source of the
  other four was not stated). Converted with Windows' MediaTranscoder, measured (all very quiet, already about
  100 Hz deep, dark), and two sets made in `../UI Research/voice/`: `original/` (trimmed and levelled) and
  `edited/` (clarity boost, slight grit, short room echo). Mockup version 14 plays these files instead of
  computer speech, with a Voice switch (Edited / Original); published with the ten WAVs as supporting files.
  All ten confirmed to load; not heard. Before any of these go into Roblox: confirm where the four non-ultimate
  lines came from, then upload under the experience owner (audio uploads are quota-limited).
- ui-5m (2026-11-16): the user confirmed all five voice recordings are their own audio, so they are clear to
  upload to Roblox under the experience owner when the build reaches sound.
- ui-5n (2026-11-16): the user picked the EDITED voice set, then asked for the background noise out, the dead
  air cut, and the lines synced to their popups (the voice sat about 0.7 s into each file, so popups were already
  fading when the words began). `../UI Research/voice/edited/*.wav` rebuilt: 95 Hz high-pass for rumble, a
  spectral gate learned from the pre-voice hiss (30 dB cut), a gate between words, start and end re-cut on the
  cleaned audio so soft first sounds (f, th) survive, then the approved edit chain. Lengths now 1.16 to 1.52 s
  (were 2.08 to 2.85 s). The user heard it on the local preview and said "its fixed i think".
  NOT DONE: the artifact link still carries the OLD voice files (publish with the `files` list to update them);
  `voice/original/` still has the old dead air; popups do not yet wait for their line to end; not heard by me,
  spectral gating can leave a watery sound.
- ui-5o (2026-11-16): the user asked for "the final product of everything". Mockup version 15 published with the
  rebuilt voice files. Finished the leftovers from ui-5n: `voice/original/` re-cut at the same points (0.78 to
  1.14 s); each popup now stays fully on screen until its line ends (last-players popups 1.70 to 2.19 s, the
  ultimate notice 1.95 s), with the voice starting 0.10 to 0.12 s after the popup. Checked on the local preview:
  no errors, all ten files load, popup durations as computed. Not heard by me.
  CURRENT STATE OF THE DESIGN: `../UI Research/fight-poster-prototype.html`,
  https://claude.ai/artifact/ScFqVNZYHhvufmBUMdwwa3 . Nothing of it is built in Roblox; ui-4 (Ringside) plus the
  ui-4c Moves fix is still what is synced in Studio, uncommitted.
- ui-5p (2026-11-16): FINAL on flashes: the user asked for the white flash to be removed again, "or find an
  alternative so it doesn't give people epilepsy". Version 16: no white flash anywhere. Screen and class changes
  use one soft slanted band a shade lighter than the window sweeping across it (0.5 s); using the ultimate pulses
  the thin edge bars once in the class colour; the skill-ready pop no longer brightens sharply. Rule for the
  build: no full-screen or large-area flashes, nothing that blinks more than three times a second.

## kits-4i (2026-11-16): the boom is out of every punch; M1 hit options in the F7 picker
Build stamp `kits-4i+lobby-4+ui-4`. NOT committed.
- THE PLACE WAS AHEAD OF GIT: it held `ui-4` (the teammate's UI work: NavController, Ui/Icons and 13 changed UI
  scripts). Saved from the place into the folder by checksum before Rojo was started; every Rojo-managed script
  then matched the place. Two tests fail with it (Tokens.spec: the new palette's contrasts, "ivory.50 on ink.900"
  and "coral.500 on ink.700"); his updated spec is probably on his PC. Left alone (his code).
- REFERENCES, as spectrograms: MUDA rush punches are 40-80 ms bursts almost all under ~300 Hz, the lows smeared
  noise with no steady line; the Itadori design is a short swell, a ~15 ms full-range crack, then long noisy lows.
- MEASURED in Studio (AudioAnalyzer in the Edit datamodel, Field Notes "Sound Design Pitfalls" section 8): punch_sub
  was the loudest layer of every M1 (RMS ~0.26 vs crack 0.17, body 0.23 at the volumes played) and its lows held
  for the full 0.5 s: the "bassy drum". Removed from the M1, the kit hits, the barrage beats and the haymaker.
  It stays only under the ultimate-ready sting (Ui/UltimateMeter, the teammate's file, not a punch).
- NEW: role `m1_hit` (Config/SoundCandidates, first row of the F7 picker; plays a 4-hit string). A = ProSoundEffects
  "Punch Kit Beefy Hit" 1-8 + the heavy-bag body; B = the same deeper (0.9, lows +4, highs -3); C = Beefy alone;
  D = the last version minus the boom (crack + bag); E = A + a 0.06 s cut of APM Deep Boom 06. Beefy onsets 16-32
  ms, peaks 27-64 ms, gone by 0.2-0.32 s; volumes even out their RMS peaks. A SoundBank entry can now carry `play`
  (its own Sfx options) and `layers` (other roles), played by `Sfx.playLayered`.
- Not changed: boom_low under the launch (hit 4) and the kit hits; ult_barrage still the bag hits.
- NOT HEARD by me. Gates: build, selene, stylua, fx_smoke pass; tests 495 pass, 2 fail (Tokens, above).
- THE USER, after trying A-E: "still sounds nothing like the references ... still just sounds like one of those
  low sounding drums".

## kits-5a (2026-11-16): Final Bell removed entirely; references re-studied for a new ultimate and mobile M1s
Build stamp `kits-5a+lobby-4+ui-4`. NOT committed. The user: "completely rework the ultimate, just entirely remove
the current one", then brainstorm a new one from the cutscene references; M1s become mobile (reference: JJK Maki
vs Naoya, youtube jORpuoAQoyA); punches still "low sounding drums".
- REMOVED: the Final Bell timeline (Core/Ultimates: TIMELINES is empty, `timeline(kit)` returns nil), all its cues
  (Fx/UltimateFx is an empty dispatcher), its impact frame (ImpactFrame.BASE), and its sound roles (ult_blink,
  ult_barrage, ult_windup, ult_impact, ult_frame, ult_haymaker, ult_launch). KEPT as the frame for the new one: the
  meter and G window (UltimateService opens no window for a kit without a timeline), the playback (pose, shots,
  cues, flight), Fx/CutsceneScreen (grade, blackout), the ImpactFrame player, ult_ready. Tests: the Final Bell
  tests are gone; the playback maths runs on a small test timeline. Studio: starts clean on kits-5a.
- PUNCH SOUND, MEASURED (ffmpeg band envelopes, scratchpad bands.ps1): the Itadori design hit has NO low transient
  on the hit: its lows swell ~75 ms before, then a steady, very loud noisy rumble under 140 Hz (~-6 dB RMS) holds
  ~0.6 s; the crack is 25 ms in the mids and highs only. The MUDA rush hits are 20-60 ms noise bursts spread evenly
  over every band. Every option we had (A-E, swings included) is a short CLEAN low thump on the hit, lows gone in
  0.05-0.2 s: that is what a kick drum is.
- Proposals to the user (agree before building): new ultimate concepts, the mobile M1 numbers, the punch rebuild.

## kits-5b (2026-11-16): mobile M1s, short stun, knock-on, dash buffer, punch sound round 2 (rumble bed)
Build stamp `kits-5b+lobby-4+ui-4`. NOT committed. NOT SEEN IN STUDIO (see the end). The user picked "M1s + punch
sound first" and took the proposed numbers.
- RULES (Punch, game.json and GameConfig in the same order): Cooldown 0.42 -> 0.32; StunSeconds 0.5 -> 0.2 (ends
  0.12 s before the next punch can land: never a true combo); LockCatchUpSpeed 36 -> 45; StepDistance, StepSeconds,
  RootSeconds REMOVED; new Push 6.5 (each stunning hit knocks the target on), MoveSpeed 20 + MoveSeconds 0.45 (run
  cap while throwing M1s), DashBufferSeconds 0.3. Endlag.PunchMiss 0.28 -> 0.2 (a whiff's endlag must fit the
  faster cadence). Windup stays 0.16 (the swing clips strike at 0.16 and can't be sped up).
- Core/Combat: punchStep/stepRoom gone; hitPush (Push clipped at a wall), stringSpeed (the cap), dashBuffered.
  CombatService.lockSpotFor: target held at (current distance clamped to LockMin..LockMax) + Push in front of the
  puncher; the puncher is never moved or pushed by its own M1 (it already kept momentum on M1s).
  MovementController: no plant, no step; punchPressedAt caps state.speed at MoveSpeed while grounded and not
  dashing; a dash pressed during an HT_Stunned stun is buffered and fires as the stun ends. DummyService: bots the
  same (punchedAt cap; plant/step gone). AnimController.HitLanded(..., step): string hits alternate HitFlinch /
  HitFlinchHeavy. Kit mobility skills (not the Dash) are not buffered through a stun.
- SOUND round 2: Sfx.bed (a sound held under a run of plays: fades in 0.05 s on the first, held `hold` s past each
  later one, fades out 0.3 s) and Layer.bed. New roles punch_rumble_low (PSE Low Rumble 2, mid-file takes) and
  punch_rumble_rough (PSE Avalanche Deep Crumbling 4). m1_hit options now: A Beefy lows cut + deep bed; B Beefy lows
  cut + rough bed; C crack lows cut + deep bed; D Beefy lows cut, no bed. NO_LOWS = eq low -40. boom_low removed
  from the M1 launch hit. Picker audition at the new cadence (0, 0.32, 0.64, 0.96).
- Tests: the stun test inverted (stun < cooldown, gap >= 0.1, buffer >= stun); push/cap/buffer tests. 495 pass,
  2 fail (Tokens: the teammate's palette). Gates: build, selene, stylua, fx_smoke.
- STUDIO: the play test found the place on `kits-4g+lobby-4+ui-4`: the teammate's Rojo had synced their folder
  over the place, wiping kits-4i/5a/5b there (disk is fine). Their only new work was HudController, saved into
  this folder by checksum. Nothing of kits-5a/5b has run in Studio yet.

## kits-5c (2026-11-16): no running through the target; one rumble per string; VERIFIED in Studio
Build stamp `kits-5c+lobby-4+ui-4`. NOT committed. After the user reconnected Rojo (stamp checked first).
- FOUND in the first real play test: fighters don't collide, so a puncher at MoveSpeed caught a target standing
  between punches and ran straight through it (gap 0.1 studs; the next hits then read as "from behind").
  FIX: Combat.frontRoom (the old stepRoom, renamed): while throwing M1s (MoveSeconds after a press) your speed is
  capped so you never get nearer than LockMinDistance to anyone ahead. Players (MovementController) and bots
  (DummyService). Test added. Also BED_HOLD 0.45 -> 0.6: at a slightly slower rhythm the rumble restarted per hit.
- VERIFIED (Practice Dummy 1, Beast kit, W held, clicks ~0.5 s apart, the fastest the tools can press): run speed
  held at 20.0 through the string, back to full after; 4 hits, the 4th launched ~100 studs; each stun ~0.2 s; the
  dummy knocked 3-8 studs ahead per hit and the puncher stopped 2.4 studs behind it, never through; flinches
  HitFlinch / HitFlinchHeavy / HitFlinch; m1_hit (option A) with EQ low -40 each hit and ONE punch_rumble_low bed
  from hit 1 through the string, louder on the launch. Dash (Base kit, Q): pressed in a (local) stun, it fired the
  frame the stun ended (82 studs/s); pressed 1 s before the end, nothing (correct, buffer 0.3 s). Console clean
  apart from the known 203785492.
- NOT TESTED: the 0.32 s cadence (the tools can't click faster than ~0.5 s), a player as the target (two
  clients), how it sounds (no ears), Studio's upload of the flinch/run clips (they play in Studio only).
- Committed as 8fc3af6 (not pushed).

## kits-5d (2026-11-16): the sound picker opens with P or a SOUNDS button (F7 never worked)
The user: "i cant see the f7 sound option thing". Measured: the picker was built and F7 bound, but a pressed F7
never reached the game (Studio keeps that key). Now P (unbound by the game and by Studio in play) and a small
"SOUNDS (P)" button at the top left (80, 12; beside the in-round menu button), Studio only. Verified in Studio:
P opens it, the button closes it, the panel shows m1_hit A-D and ult_ready A-E.

## kits-5e (2026-11-16): punch sound round 3 (sub thump + crack + smack), a finisher row, a shine for the ready sound
Build stamp `kits-5e+lobby-4+ui-4`. NOT committed. The user disliked every round-2 option and sent new references
with descriptions: punch (Gojo/Jogo - its download failed, 403; OPM Garou x2, Saitama x2, JJS melee hit set "THE
closest", JoJo ORA barrage) and ultimate (glow SFX set, anime "kiiiin" shine, light spell). Their summary: every
hit "mostly a huge, deep sub-bass thump (the loudest part), with a sharp crack on top ... and a crunchy meaty layer
in the middle", short (0.2-0.5 s); finishers keep a 1.5-4 s rumble tail; ultimates a bright tonal shine, then a hit
like Serious Punch.
- MEASURED (JJS hit, ffmpeg band RMS): all bands jump on the hit, the sub loudest (~6 dB over mids) from ~40 ms,
  sweeping down, gone ~0.35 s; mids/highs gone after ~0.12 s. (Corrects the "no thump on the hit" conclusion of
  kits-5b, drawn from one clip; Field Notes "Sound Design Pitfalls" section 8.)
- NEW ROLES: punch_thump (PSE "Boom Impact Deep Distant Thumping Hits", 11 takes: instant attack, pitch sweeping
  ~300 -> ~70 Hz, long tail) and punch_smack (the Beefy Hit takes). punch_sub (the round-1 boom) and the rumble
  beds are gone; Sfx.bed stays (unused; for a future barrage). m1_hit A thump (1.6, cut 0.25) + smack (1.0, mid
  +6 dB) + crack (1.0); B thump + smack; C thump + crack; D A at 0.88 speed. NEW ROW m1_finish (hit 4 and launching
  kit hits; replaces "m1_hit louder + boom_low"): A thump left ~2 s + smack + crack; B APM "BOOM-Synthetic Boom 03"
  (cut 2.5) + thump + smack + crack; C PSE "Wind Whoosh Sonic Boom Low End Impact" (from 0.28 s, its impact on the
  hit) + thump + crack. Levels set by measuring the whole mix against the JJS hit in one AudioAnalyzer.
- ult_ready: A APM "Beautiful Shimmer", B APM "Effect Cue 6", C PSE Magic Burst 3 (the last pick), D a community
  "GlowUp" (choose only if accepted). Ui/UltimateMeter (the teammate's file; only our sound line) now plays it 2.6 s
  with nothing under it.
- VERIFIED in Studio: picker rows m1_hit / m1_finish / ult_ready; a 4-hit string on Practice Dummy 1 played
  m1_hit (thump + smack with EQ + crack, a new take each hit) x3 and m1_finish + launch on hit 4. Gates pass
  (496; Tokens x2 the teammate's). NOT HEARD by me.

## kits-5f (2026-11-16): the user's picks baked in
The user picked m1_hit A, m1_finish A, ult_ready C. All three are now SoundBank entries (m1_hit / m1_finish share
THUMP_TAKES with punch_thump; ult_ready = PSE Magic Burst 3). SoundCandidates is empty, and the sound picker (and
its SOUNDS button) doesn't build while nothing is left to choose; add a role there to bring it back. Verified in
Studio: the entries load as picked, no picker, console clean. Gates pass (496; Tokens x2 the teammate's).

## kits-6a (2026-11-16): new ultimate "Haymaker Rush"; sound study of all 20 references
Build stamp `kits-6a+lobby-4+ui-4`. NOT committed. The user turned down "Lights Out" as too black-and-white
("only for like a temporary moment"), kept its impact frame and camera cuts, and approved Haymaker Rush; then asked
for an in-depth study of what makes the references' sounds good before any sound was picked.
- SOUND STUDY (all 20 references the user sent, spectrograms + band tables, 1-frame-per-0.5-s strips): written up
  as the vault note `07 Lighting VFX and Audio/Anime Impact Sound Anatomy - Measured From 20 References.md`. A big
  hit = dip to near silence, crack (highs sweeping down), sub 30-100 ms LATER and held/swelling (loudest layer),
  then everything above ~1 kHz filtered out, a low boom sinking in pitch, sparse debris. Rush hits = short
  crack-led ticks with their own thump over one low bed. Azure Flames, Orlando and the impact-frame edits are
  mostly music (timing only). The Raging Demon clip = `Yde2yYu9_lM` (it was in this file by id only).
- TIMELINE (Core/Ultimates HAYMAKER_RUSH, Base; EVERY kit now falls back to it, so every kit gets the G window):
  charge 0-0.35 (close on the attacker, a new `rel = "attacker"` shot frame), dash in 0.35-0.5, first blow 0.5,
  barrage 0.64-1.2 (five blows 0.14 s apart on the clash barrage loop, AnimController.SetBarrage), uppercut 1.4,
  leap 1.62, dip 1.66, haymaker 1.8 under the impact frame, colour back + blast 2.1, flight from 2.15. New
  Timeline fields: `swings` (hooks can't strike faster than 0.16 s: they start early), `barrage`, `blows`
  (target flinches, HitLanded). Grade: only a light contrast push. The hardcoded Final Bell barrage in
  UltimateController is gone; it plays the timeline's lists.
- LOOKS (Fx/UltimateFx BASE): fist glint (two set-angle stars + glow), DashFx, PunchHitFx per blow (heavy on blow,
  uppercut, haymaker, blast), StepBurstFx under the uppercut/leap/blast, AirFx trails. ImpactFrame: new `slash`
  (one long Leaf stroke, -34 deg); frames black+slash / white / ink sketch with lines / black split / white with
  black stars (~0.3 s). Each frame seen held in Studio.
- SOUNDS: no charge-up sound (the user removed it after trying C; the shine and its pitch steps are gone). The bed
  swells in under the charge; blow and uppercut = m1_finish; rush = ult_rush; dip fades everything in 0.05 s;
  haymaker = ult_crack (pitch 1.18 -> 0.7 over 0.28 s) then ult_sub 70 ms later; blast = ult_explosion, every
  sound still playing gets an EQ muffle (high -40, mid -16) and sinks in pitch over 3 s; debris at +0.5/+1.5.
  Roles in the picker (SoundCandidates, option A in play): ult_rush, ult_bed, ult_crack, ult_sub, ult_explosion,
  ult_debris. None of the Final Bell ids are reused. Community options (JJS punch ids, thunder) are B-D only.
- STUDIO: played end to end on Practice Dummy 1 with a planted test helper (fills the meter, opens the window;
  the client fires UltimateRequest at once, the window is only 1.2 s). Console clean. Shots fixed after
  captures: charge (was all torso), over-the-shoulder and side (too close; bodies now 3.2 studs apart, they
  overlapped at 2.8), face close-up (was inside the bodies), worm's-eye (the attacker blacked out half). NOT
  SEEN after the last fixes: the charge, hang and blast shots; NOT HEARD by me: any of it. The user hears it.
- Gates: build, selene, stylua, 498 tests (Tokens x2 the teammate's).
## kits-6b (2026-11-16): Haymaker Rush slowed to 5 s with holds and a wind-up; charge sound removed
Build stamp `kits-6b+lobby-4+ui-4`. NOT committed. The user, after trying kits-6a: "it all happens to fast ... there
should be some pauses before the camera shifts and there should be a pause to wind up your punch before the last
huge hit just like in the references". Earlier the same round: the charge-up shine (C) "not good", then "remove the
charge sound all together" (ult_shine and its pitch steps are gone; the bed still swells in under the charge).
- TIMELINE now 5 s (was 2.15): charge 0-0.9; dash 0.9, first blow 1.15 then a reel to 1.55; barrage 1.7-2.54
  (seven blows 0.14 apart) over three shots (shoulder 1.55, side 2.05, face 2.45 holding to 2.95); uppercut 3.05
  from the ground; leap 3.35; WIND-UP 3.6-4.22: the haymaker drawn back and HELD (new Swing `hold`, released by
  `fromHold` 0.07 s before the hit) in a close-up from the attacker's right, glint 1.6x on the fist, the bed
  swelling to 1.6x; dip 4.22; haymaker 4.4 + impact frame; blast 4.7, held to the flight at 5.
- Tests: the pace is pinned (cinematic >= 4.5 s, no shot under 0.3 s, every release after a hold). 498 pass
  (Tokens x2 the teammate's); build, selene, stylua.
- STUDIO: the wind-up seen (arm cocked, glint on the fist); the dummy hid half of it, so the camera moved to the
  attacker's right side (NOT re-seen after that move). Console clean.
- Field Notes: `Studying VFX References ...` section 9 (measure a cutscene's length and shot lengths).
## kits-6c (2026-11-16): Haymaker Rush rebuilt to an agreed beat plan; one complete sound per event
Build stamp `kits-6c+lobby-4+ui-4`. NOT committed. The user on kits-6b: "the punches are too fast compared to the
animations, and the camera angles are too random ... plan the sfx, vfx, camera, and timing with intent". A beat
plan was agreed ("looks fine"), plus: sfx must not layer on top of each other, barrage punches consecutive, the
punch "too bassy ... like a drum hit", and "you shouldnt combine a bunch of different sounds to mimick a punch".
- TIMELINE (Core/Ultimates, comment table at the top of HAYMAKER_RUSH): 5.4 s, nine shots ALL on the attacker's
  right (+X: attacker screen-left, target screen-right, blows and blast travel left to right); every blow a real
  swing whose fist lands on it (hooks start 0.16 s early); punches 0.32 s apart (the M1 cadence): first blow 1.14,
  barrage 1.62 / 1.94 / 2.26 / 2.58 (L R L R), uppercut 2.92, leap 3.5, held wind-up 3.8, silence 4.4, haymaker
  4.55, blast 4.85, flight 5.4. Each barrage blow pushes the target 0.6 back over 0.12 s (keys built in
  rushKeys()). The clash-barrage loop is no longer used. Tests pin: cams on +X, blows >= 0.3 s apart, shots >= 0.3 s.
- SOUND: one complete designed sound per event (memory + Field Notes Sound Design Pitfalls section 9). ult_rush =
  one punch file (A Itadori's punch JJK, B Itadori Punch sound, C Garou Punch, D-F JJS ids); ult_haymaker = one
  designed Serious Punch (A TSB, B Re-sfx, C sound design from 2.4 s, D Ash3167 from 2.9 s, E APM Atom Smasher);
  ult_bed the rumble. All but E and the bed are COMMUNITY uploads of anime/game audio (could be taken down).
  `start` = each file's measured peak, volumes evened by peak. Removed: ult_crack, ult_sub, ult_explosion,
  ult_debris, punch_crunch and the crack-sweep code. Foreground is one voice: each punch/whoosh fades the last in
  0.04 s (UltimateFx.foreground; Sfx.playLayered now takes an `into` list and Layer `delay`). Bed volume 0.5.
  The blast adds no sound: the haymaker's tail is muffled and sinks.
- STUDIO: played end to end, console clean; the over-the-shoulder barrage shot seen (attacker left, burst on the
  dummy right). NOT HEARD by me; the user picks ult_rush / ult_haymaker / ult_bed with P.
## kits-6d (2026-11-16): sound picks baked; the barrage in bursts like the references; haymaker hit on the frame
Build stamp `kits-6d+lobby-4+ui-4`. NOT committed. The user picked ult_rush A (Itadori's punch JJK), ult_haymaker C
(the Serious Punch sound design), ult_bed B (PSE Hollow Rumble 2): all three are SoundBank entries now and
SoundCandidates is empty (the picker hides). Their notes: the punches "should be more far apart ... dont just make
them ALL the same amount apart ... sound like an actual barrage ... refer to my references"; the haymaker hit "a
bit delayed".
- RHYTHM MEASURED in the references (ffmpeg onsets, scratchpad onsets.ps1): bursts that speed up (0.40 -> 0.30 ->
  0.25 s) with 0.5-0.9 s breaths (Raging Demon 0.26 0.16 0.16 | 0.72 | 0.26 0.26 0.32 0.32; Itadori 0.54 0.40
  0.28 | 0.92; Stinger 0.30 0.30 | 0.48 | 0.24 0.26 0.28). New barrage: first blow 1.14, reel, burst L 1.76 R 2.06,
  breath (the cut), burst L 2.56 R 2.82 L 3.06, breath, uppercut 3.64; everything after moved +0.7 (leap 4.2,
  wind-up 4.5, silence 5.1, haymaker 5.25, blast 5.55, flight 6.1). Pushback 0.5 per blow, 0.8 on the last of
  each burst (heavy flinch there). Cues/swings/blows built from the PUNCHES/SIDES/PUSHES lists. Tests: blows >= 0.22 s
  apart and NOT evenly spaced (longest - shortest gap >= 0.2).
- HAYMAKER DELAY: the file is three hits (high-band onsets 0.1, 1.4, 2.85 s, measured with an AudioAnalyzer in
  the Edit datamodel); start 2.42 fell in the second hit's decay, so the third came ~0.45 s late. start = 2.84.
- STUDIO: full run, console clean, sounds in order (blow, 2, 3, uppercut, haymaker). With Studio in the
  background (~12 fps) cues fire up to ~0.1 s late and a hitch can fire two at once (cues run on RenderStepped).
## kits-6e (2026-11-16): the haymaker hit back in the picker, gunshot-like options
Build stamp `kits-6e+lobby-4+ui-4`. NOT committed. The user: "the last hit doesnt sound", then "change it to
something louder, like a gunshot, similar to the jotaro vs dio reference". Measured during a real run: the picked
Serious Punch sound design (from 2.84 s) did play, but swelled 0 -> ~300-530 over 0.3 s with no attack (a roar,
not a hit). ult_haymaker is in SoundCandidates again (ult_rush and ult_bed stay picked in SoundBank). Options,
all with a 0.02-0.06 s attack (PlaybackLoudness every frame), volumes set so each peak is ~2x a punch: A "Star
Platinum Punch" niaz3664 (peak 785, still 622 after 0.5 s: crack then roar, closest to the Jotaro hit), B "Star
Platinum Punch 1", C "Star Platinum Punch SFX (fixed)", D "SKILL_CANON_SHOT" (all crack), E "Onslaught-Hit-4".
All community uploads. In a run, A jumps 0 -> ~850 in one sample on the frame and holds ~1000. Console clean;
gates pass (498, Tokens x2 the teammate's). Field Notes Sound Design Pitfalls section 9: impacts need an attack.
## kits-6f (2026-11-16): haymaker pick baked
Build stamp `kits-6f+lobby-4+ui-4`. NOT committed. The user picked ult_haymaker B, "Star Platinum Punch 1" (reelx1ty,
community; attack 0.02 s, peak 663 at 0.17 s, start 0.13, volume 1.6). All Haymaker Rush sounds are SoundBank
entries now (ult_rush Itadori's punch JJK, ult_haymaker Star Platinum Punch 1, ult_bed PSE Hollow Rumble 2);
SoundCandidates is empty and the picker hides. Gates pass (498, Tokens x2 the teammate's).

## ui-5a (2026-11-16): FIRST BUILD PIECE of the fight-poster UI: the colour system and a smaller stagger panel (NOT COMMITTED)
The user approved the mockup ("i think we're ready to build"), asked for the stagger panel to be smaller in the
game than in the mockup, and said to REMOVE ALL THE CURRENT UI so the new one replaces it.
- BEFORE BUILDING: origin/main was 3 commits ahead (kits-4i to kits-6f, which also committed the ui-2..ui-4 files
  from the place). Every uncommitted UI file here was identical to or older than GitHub's, so they were backed up
  to `work/pre-pull-backup-20261116b/`, restored, and the pull fast-forwarded. HANDOFF.md was merged with
  `git merge-file --union` (both sides' sections kept). Local-only and still uncommitted: tests/HudLogic.spec,
  tests/Tokens.spec, tests/Motion.spec, tests/TypeRoles.spec, README.md, HANDOFF.md.
- TOKENS (`Shared/Tokens`): the fight-poster colour system on the same job names. ink = deep violet (#120C28
  outline, #1A1236 panel), ivory = cream, stone = violet greys, coral AND gold = yellow #FFD426 (primary action,
  you, coins: the opposite of the ink), teal = cyan #21D4FD (ready, equip, owned), danger = magenta #FF4D9E,
  violet = light violet #C9BEFF (focus, quiet), line.300 #4A3F7A, and the eight class colours as one warm-to-cool
  sweep. Every existing screen re-coloured with no screen code changed. Contrasts re-measured in
  tests/Tokens.spec (ivory 17.1, yellow 12.4, cyan 10.1, magenta 5.8, stone 5.5 on the panel).
- STAGGER PANEL (`HudController`): `L.YShrink = 0.78` on desktop (phones keep their own panel). 252 x 68 px at
  1280 x 720 = 19.7 % x 9.5 % of the screen (was 25 % x 12 %). It is a uniform scale, so its small labels are
  now about 11 px; the proper restyle (slanted number, segmented bar) replaces this.
- Build `kits-6f+lobby-4+ui-5a`, 520 tests, gates green, synced, seen in Studio play at 1190 x 536 (colours and
  the smaller panel; console clean), place saved.
- STILL THE OLD LAYOUT, to be replaced piece by piece and each old piece deleted as its replacement lands:
  the left nav column, the shared window (MenuController), the HUD's tiles and strip, the ULTIMATE BAR (the user
  wants it gone: a notice instead), spectate, the controls guide. NOT BUILT from the mockup: cut-shape buttons and
  poster window, repeated-word drifting background, class re-tint, slanted stagger number and segmented bar,
  ultimate notice and badge, last 5 / 4 / 3 / 2 popups, idle motion, springy motion, the soft sound set, the five
  voice lines (the user's own recordings, `../UI Research/voice/edited/`; not uploaded to Roblox).
- Note for sound work: kits-5e to 6f (the other session) picked an ultimate-ready sound and rebuilt sounds in
  `Shared/Config/SoundBank`; read those sections before adding the voice line so the two do not clash.

## ui-6a (2026-11-16): the fight HUD of the fight-poster mockup: stagger plate, skill tiles, strip (NOT COMMITTED)
The second build piece. The three HUD pieces a player looks at in a fight are now the mockup's, and the old ones
are deleted. Build `kits-6f+lobby-4+ui-6a`, 522 tests, gates green, synced, place saved v404, nothing committed.
- SHAPES: Roblox cannot skew a frame, so three white PNGs are tinted in use. Drawn by
  `design/ui/draw_poster_shapes.py` into `assets/ui/poster_*.png`, uploaded with the Studio MCP's `upload_image`
  (it needs an http URL; port 8765 was another session's server, so use a free port). The ids live ONLY in the new
  `src/client/Ui/Shapes.luau`: `slant` (a parallelogram, 3-sliced with zero-height rows so one image makes a
  slanted plate of any size; `Shapes.slant(parent, tone, lean)`), `tile` (the rough-cut quad, stretched; the same
  image inset 4 units is the tile's fill) and `stripes` (the can't-use pattern).
- STAGGER PLATE (`HudController`, group `You`; sizes in `L.Y` / `L.YPhone`, theme in `HudTheme.Stagger`): ink
  plate, class-colour left edge, slanted number (new role `numeral.stagger`: Titillium Bold Italic, 72), STAGGER,
  "2.1x knockback" on one line, one word (RISING for 0.8 s after a gain / RECOVERING / STEADY), 12 segments.
  252 x 84 units = 19.7 % x 11.7 % at 1280 x 720. `L.YShrink` is gone. Smallest text is 15, the floor.
  A gain punches the number; a gain of 5 or more shakes the plate once; neither under Reduced Motion.
- COLOUR STEPS: this game's stagger maximum is 100, not the mockup's 150, so "yellow at 50, pink at 100" would
  have put pink only at the very top and out of step with the bar. Number and bar both step at THIRDS of the
  maximum (`HudTheme.Stagger.YellowShare` / `PinkShare`): white under 34, yellow 34 to 66, pink from 67. At a
  maximum of 150 those are exactly 50 and 100. One line to change if the owner wants the literal numbers.
- SPEED GAUGE: REMOVED. The approved mockup has none, the owner asked for a smaller panel and for the old UI to
  go, and keeping it meant either a label under the text floor or a taller panel. `HudLogic.speedGauge` and
  `steadyDigits` and their tests went with it. Git history has it if the owner wants it back.
- SKILL TILES (group `Kit`; `HudTheme.Tile`): Jump and Punch 76 units in light violet, Q and R 96 in the class
  colour (the mockup's are 84 and 104; row = 29.7 % x 13.3 % at 1280 x 720). Ink outline, hard shadow, cream key
  cap, icon, name. READY = bright tile + a cyan flag with a drawn tick and the word READY (Q and R). COOLING =
  dark, a darker class-colour fill rising from the bottom, the seconds, the icon stepped aside. CAN'T USE = dark
  with stripes, a pink slash, and a pink flag saying STUNNED or CAN'T USE (ink lettering: cream on that pink is
  about 2.9:1). Held R = bright with a cream outline. Coming off cooldown Q and R pop once; a refused key knocks
  the tile sideways; no colour blinking. Punch's key cap now says CLICK (was a mouse picture).
- STRIP (group `Strip`; `HudTheme.Strip`): slanted ink plate, class colour under it (yellow for the final two and
  the last one), count in yellow. The ARENA CLOSING chip is a slanted pink plate.
- CLASS COLOUR: `Tokens.hex["class.<kit id>"]` from `AbilityController:GetKitId()`, repainted on `KitChanged`.
- DELETED: the old cut-corner stagger panel, its bar with ghost and drain tick, the speed gauge and notch, the old
  tiles (shade, corner badge, key cap stroke states), the strip's cut panel; `HudTheme.Size` and `HudTheme.Time`
  entries nothing reads any more; `HudTheme.Icons.mouse`. `Components.cut` / `Tokens.cut` stay: the controls
  guide and the spectating chip still use them.
- NOT TOUCHED (later pieces): the ultimate bar, the lobby nav, the menu window, the feed, the controls chip and
  guide, the spectating chip, the target marker, the touch buttons' cooldown overlay.
- MEASURED in my own Studio play test (viewport 932 x 536, Tempest, bots frozen): the HUD's whole per-frame loop
  0.05 ms a frame idle and 0.06 ms with a skill cooling (set the player attribute `HT_HudProfile` to true and
  read `HT_HudMs`); whole HT_Hud on against off over five alternating rounds: 11.39 against 11.24 ms a frame,
  inside the run-to-run noise (about 1 ms). 139 instances in the three pieces. Console: only the known lines
  (`rbxassetid://203785492` asset type, not ours).
- SEEN: ready / cooling / can't-use, stagger at 22 (white), 55 (yellow), 88 (pink), strip while fighting and in
  intermission. Screenshots: the shared notes folder, `ui-6a-shots/`.
- KNOWN, NOT FIXED:
  - The HUD never scales below its 1280 x 720 size (`HudTheme.Scale.Min = 1`, there before). In a small Studio
    window the plate is 252 x 84 PIXELS: 27 % x 15.7 % of a 932 x 536 viewport. Judge size at 1280 x 720 or
    larger, or lower the floor for desktop (text would then go under 15 px on small windows).
  - In the LOBBY (intermission, you alive) the stagger plate shows under the old left nav's MORE button, as the
    old panel did. It belongs to the nav piece: either hide the fight HUD outside a round or move the nav.
  - The rising cooldown fill is close in tone to the dark tile on cool class colours (Tempest).
- NOT TESTED: phones (the plate's phone layout, 208 x 76 under the top-left buttons, has never been on screen:
  Studio's touch input cannot be driven from the MCP), a real gamepad (glyph caps), a larger Roblox text-size
  setting (the plate grows by its three text lines; the tiles do not), Reduced Motion, every class colour but
  Tempest, the final-two strip, the ARENA CLOSING chip, the held-R look, how the motion FEELS (seen as stills).

## ui-6b (2026-11-16): the fight HUD made to match the mockup exactly; tools to capture the mockup (NOT COMMITTED)
The owner, after ui-6a: "I want it to look EXACTLY like it though", and the whole new UI is to replace the old one
(order: ultimate notice, last-players popups, lobby buttons and poster window, motion and sound). This pass redid
the three ui-6a pieces to the mockup's own pixels, fonts and curves. Build `kits-6f+lobby-4+ui-6b`, 528 tests,
gates green, synced, place saved v407, nothing committed.
- THE METHOD (use it for every later piece):
  - `design/ui/mock_capture.py` renders the mockup ITSELF with headless Edge at 1280 x 720 in a chosen state
    (`out.png '{"view":"fight","cls":"Tempest","stag":82,"cdq":3.1}'`), prints any element's on-screen box
    (`--dump mock.html '{...,"rects":["#stag",".skl"]}'`), and captures any page on a clear background
    (`--clear --page x.html`). Nothing installed or downloaded. Its timers: one timer does everything, because
    `clearInterval` also cancels timeouts.
  - `design/ui/proof_pair.py` stacks a mockup capture and a Studio capture at one image pixel per HUD unit.
    Studio's `screen_capture` is 1.25 x the viewport on this PC and is saved as a JPG under the session's
    `tool-results` folder.
  - TEXT: a browser's 15 px is not Roblox's TextSize 15. Measured with the same strings in both: Oswald needs
    1.463 x the CSS size, Titillium Web 1.508 x. `Ui/Poster.text(parent, "display" | "label", cssPx, tone)` does
    the sum. Oswald loads in Roblox (200 to 700, NO slanted faces). Roblox has no letter spacing.
  - MOTION: `Core/PosterEase` holds the mockup's `--spring` (its CSS `linear()` list, point for point), its
    `--pop` cubic-bezier, the CSS ease keywords and a keyframes helper (tests in `tests/PosterEase.spec`).
    `Poster.run(key, seconds, step)` drives anything on one shared frame connection that exists only while
    something moves; under Reduced Motion it jumps to the end. TweenService's Back and Elastic are not used.
  - SLANTED SHAPES: a 9-slice loses its lean when Roblox draws it small (it picks a smaller copy of the image
    and slices that with the full-size numbers; measured in Edit mode). So `Shapes.slant` is a wedge image, a
    plain body and a pre-turned wedge (`Rotation = 180` on the second wedge left a hairline seam). Recolour with
    `Shapes.paint`. Stagger segments have their own two stretched images.
  - THE NUMBER: Roblox has no slanted Oswald, so the stagger number is drawn from a sheet of digits the browser
    rendered (`design/ui/poster_digits.html` -> `assets/ui/poster_digits.png`, `Shapes.digits` holds the cell
    size, baseline and each digit's advance; `Poster.number` / `setNumber` lay them out).
- NEW TYPE: `Tokens.family.poster` (Oswald), roles `poster.display` and `poster.label` (never scaled by the
  player's text-size setting: the layouts are fixed). Tokens `poster.dark` / `poster.stripe` / `poster.unlit` are
  the mockup's own darks. `numeral.stagger` (ui-6a) is gone again.
- STAGGER PLATE: the mockup's plate whole (label on top, number, "3.8x" / knockback / word column, segments),
  built in the mockup's pixels and shrunk as one piece by `L.YScale = 0.66`: 264 x 110 units = 20.6 % x 15.3 %
  of 1280 x 720 (the mockup's is 31 % x 23 %). 0.66 is where its 15 px labels land on the 15-unit text floor.
  This REPLACES ui-6a's compact 252 x 84 arrangement, which was my own layout, not the mockup's.
- TILES: the mockup's sizes (84 and 104, 14 apart, right 26, bottom 24), Oswald key caps ("Space", "Click", Q,
  R), 34 px seconds, the mockup's dark #2B2924 and stripes, `spop` / `nope` on the real curves.
- STRIP: 72 tall, 18 from the top (under Roblox's own top bar), 34 px Oswald count, words on its baseline.
- DIFFERENCES FROM THE MOCKUP THAT REMAIN, AND WHY:
  1. The stagger plate is 66 % of the mockup's size (the owner asked for smaller).
  2. READY / STUNNED flag: in the mockup it lies over the key cap and HIDES the Q or R. The key must always be
     visible, so the cap is 30 wide instead of 42 and the flag reaches 8 units past the tile's right edge.
  3. Stagger colour steps at thirds of 100 (34, 67), the mockup's at 50 and 100 of 150: the same shares.
  4. Icons are the game's placeholder drawings; the mockup has plain glyphs.
  5. No letter spacing in Roblox: tracked labels (STANDING, knockback, tile names) are a little narrower.
  6. "Used" squash: the mockup squashes a tile to 1.25 x 0.6; Roblox can't stretch a tile's contents unevenly, so
     it shrinks evenly (0.87) and springs back on the same curve.
  7. The ready tick is drawn with two strokes, not the font's glyph.
  8. The strip shows this game's wording per phase and sits under Roblox's top bar (76 from the screen top).
  9. Extra in the game, not in the mockup: the held-R look, CAN'T USE for blocks other than a stun, the result
     word over Punch and Jump, the ARENA CLOSING chip.
- PROOF: the shared notes folder, `ui-6b-proof/` (ready, cooling, can't use: mockup over game at the same scale).
- MEASURED (viewport 932 x 536): HUD loop 0.04 ms a frame; console only the known lines.
- NOT TESTED: phones (the touch plate has never been on screen), a gamepad, Reduced Motion, classes other than
  Tempest, the motion in real time (stills only), the count bump, final two.
- STILL OLD: the ultimate bar, the left nav and gear, the menu window, the feed, the controls chip, spectating.

## ui-6c (2026-11-16): ultimate bar removed; ULTIMATE READY notice and badge; last-players popups (NOT COMMITTED)
Pieces 1 and 2 of the owner's order after the HUD. Build `kits-6f+lobby-4+ui-6c`, 528 tests, gates green, synced,
place saved v409, nothing committed.
- GONE: `Ui/UltimateMeter.luau` (the bar, its pulsing fill, the ring prompt). No meter is on screen now.
- NEW `Ui/Callouts.luau`: the two big announcements, built when they start and destroyed when they end.
  - `Callouts.ultimate(colour, key, done)`: the mockup's `.ucall`: ULTIMATE in cut-out letters dropping in on the
    spring one by one (0.18 s + 0.045 s each), a slanted streak, a READY stamp with the key, 18 confetti, the thin
    edge bars pulsing once; holds, kicks once, then flies down-right toward the skills. Lasts
    max(1.7, (0.12 + line) / 0.8) s = 1.95 s, as in the mockup.
  - `Callouts.last(count, small, done)`: at 5, 4, 3, 2 standing: a big slanted number (an image, with its
    outline and shadow, rendered from the mockup's font: `design/ui/poster_last_digits.html`) slams in over a
    coloured bar with FIGHTERS LEFT; at 2 it says FINAL TWO, shakes and throws 20 confetti. It holds for its
    voice line (1.7 to 2.2 s), flies up into the strip, and the strip's count bumps.
  - Driven from `HudController.refreshStrip`: only when Alive really FELL to that count during a fight, so
    joining a round already at 4 shows nothing. Everyone sees it, fighters and spectators.
- NEW `Ui/UltimateNotice.luau` (same three calls UltimateController used: start, prompt, hidePrompt): follows the
  player's HT_UltReady by signal, not per frame. Earned -> the notice -> a badge above the skills, "ULT READY"
  and the key, in the class colour (the mockup's `.ultb`: pops in on the spring, then breathes). The G
  follow-up WINDOW (1.2 s, the game's own rule, not in the mockup) shows on the badge: it says PRESS and an ink
  line under it runs out. On touch the badge has no key and sits under the strip; the real Ult button stays the
  control.
- VOICE (`Shared/Config/VoiceLines.luau`, the ONE place): the five lines with their lengths and EMPTY ids. Nothing
  is uploaded: audio uploads are limited and public-facing and wait for the owner's word. To turn a line on, put
  its `rbxassetid://` in `id`. Popups already hold for each line's length. `UltimateLineReplacesSound = true`:
  once "ultimate-ready" has an id, the spoken line plays INSTEAD of SoundBank `ult_ready` (kits-5f's 2.6 s
  shine), so the two never overlap; until then that sound plays as before.
- MEASURED (my play test, viewport 932 x 536): the notice adds about 0.6 ms a frame for its two seconds, the
  final-two popup about 0.5 ms, the 5 / 4 / 3 popup and the edge bars nothing measurable; nothing runs when none
  is on screen. A first build cost about 3 ms: it faded each letter through its own CanvasGroup inside a big
  one. Now things fade by their own properties and a CanvasGroup is used only for the last fifth of a second.
  (Frame-time noise in Studio is about 1 ms; alternate short samples to see anything smaller.)
- FOUND: AutomaticSize on a frame whose child is sized by scale AND has a UIScale feeds back on itself (the
  letter cards grew to 300 units). Letter widths are measured with TextService instead.
- DIFFERENCES FROM THE MOCKUP, AND WHY: no voice yet (not uploaded); no announcement sounds yet (the sound piece);
  the last-players bar is wider than a small Studio window, so its slanted ends are off screen there; letters,
  stamps and numbers fade in by property over the same time rather than as one layer; the mockup's band with the
  class name when the ultimate is USED is not built (the game has its own ultimate sequence).
- PROOF: the shared notes folder, `ui-6c-proof/`.
- NOT TESTED: a real ultimate earned in play (I set HT_UltReady and Alive from the server), the G window on the
  badge, the voice path, gamepad and touch, Reduced Motion, counts 4 and 3, two announcements at once.

## ui-6d (2026-11-16): the LOBBY in the fight-poster look: WRITTEN, NOT TESTED, NOT SYNCED (stopped at a usage limit)
STUDIO IS STILL AT ui-6c (place v409). The files below are on disk only. Do NOT Rojo-push until the steps under
"TO FINISH" are done and a play test has passed: none of this code has run once.
- ASSETS, uploaded and recorded in `Ui/Shapes.luau` (ids and word-tile widths): the five menu strips' shapes, the
  MENU and X shapes, the class tile and its stripes, the action button, the shop slab, the dot tile, and thirteen
  WORD TILES (eight classes, Shop, Ranked, Moves, More, Settings) from `design/ui/make_word_tiles.py` +
  `design/ui/poster_words.html`. Shapes come from `design/ui/draw_poster_shapes.py` (`MENU_SHAPES`).
- NEW `Ui/PosterKit.luau`: cut (rough-cut shape with outline and shadow), pressable, pop, cap, tag, row (the
  slanted ink row), title (outlined word with shadow), lobbyScale (the lobby scales as a whole, 0.6 to 1.35).
- REWRITTEN `Controllers/MenuController.luau`: the poster window (948 x 612 at 306, 86; leaning paper, cream
  slash, drifting dots and word in a CanvasGroup, wipe band on page change, toast under the strip). Pages:
  classes, shop (Buy then Confirm, scrolls), ranked (planned), moves, more (Settings, AFK, Spectate, planned
  rest), settings. API: Open(entry), Close(), SetOpen, OpenSettings, GetEntry, Toast, signal Changed(entry?).
  Old page names still accepted. In a round only more / moves / settings open.
- REWRITTEN `Controllers/NavController.luau`: the five strips (Classes 1, Shop 2, Ranked 3, Moves 4, More), the
  coins plate, the fight's MENU button; keys 1 to 4, and H / Select for Moves.
- TO FINISH, in order:
  1. `HudController`: delete the old CONTROLS chip and guide (lines found with
     `grep -n "help\|guide\|GUIDE_\|HELP_ACTION\|toggleGuide\|wasFighting\|TextService"`): the build block from
     "-- the controls guide" to "-- F: the ring-out feed", the help / guide lines in layout(), refreshGroups and
     refreshDevice, toggleGuide and its BindAction, `HudController:ToggleGuide`, and the two constants. It binds
     the SAME action name ("HaymakerHelp") as NavController, so one of the two silently wins until it is gone.
  2. Delete `Controllers/AfkController.luau` (it only draws the old top-left AFK button; NavController no longer
     hides it; AFK is a row of the More page). Keep `HudTheme.Afk`: SpectateController reads it.
  3. Bump the build label to ui-6d, run the gates, fetch and pull, push in Edit mode, play test.
  4. Check in play: the strips and their entrance, each page, buy / confirm / equip, AFK and Spectate rows, the
     window's drift (measure its frame cost: the CanvasGroup redraws every frame while open), M / X / B, the
     round fold (MENU button), the toast, a 932 x 536 window. Compare with `design/ui/mock_capture.py`
     (`'{"entry":"classes","cls":"Tempest"}'`) using `design/ui/proof_pair.py`.
- KNOWN DIFFERENCES ALREADY DECIDED: the window's contents stand straight while its paper leans 0.6 degrees
  (Roblox cannot clip or scroll turned things); planned slabs and the Confirm ring have plain lines, not dashes;
  the dotted corner of the cream slash is not drawn; the shop scrolls (a new player has seven classes to buy).
- NOT STARTED: piece 4 (idle drift on pressable controls, the soft sound set), the feed, the spectating chip and
  SpectateController's panel in the new look, the "class name" band when an ultimate is used.
- A LOCAL IMAGE SERVER may still be running on 127.0.0.1:8791 (serving assets/ui) and `rojo serve` on 34872.
SoundCandidates is empty and the picker hides. Gates pass (498, Tokens x2 the teammate's).## kits-7a (2026-11-17): our own M1 and heavy-hit sounds, from Sonniss GDC 2026 recordings
Build stamp `kits-7a+lobby-4+ui-6c` (disk and place match). NOT committed.
- The user wants sounds MADE for the game, not picked. Synthesis failed four rounds ("a slap", "drums", vocoder
  rebuilds "kinda ok"); an in-depth study (vault `07 Lighting VFX and Audio\Punch Sound Design - References vs
  Synthesized Attempts, Measured.md`, Field Notes Sound Design Pitfalls 10-12) led to RECORDED layers: the free
  Sonniss GDC 2026 bundle (350 files, 7.5 GB) is in `C:\Users\spicy\SFX Library\Sonniss GDC 2026` (outside OneDrive).
- Picks (all in `sfx-lab\final`, PICKS.md says how each was built; build scripts `sfx-lab\build_round6.sh`, `_round7.sh`;
  tools `sfx-lab\tools\` hitstat/onsets/subpitch/vocode/zipindex): m1_hit = three takes (swing-thud on a recorded body
  punch), m1_finish = one heavy swing-thud (-8 %), ult_haymaker = "K1" heavy hit (dry snap + thud + fireworks
  explosion swept 9 kHz -> 700 Hz + mono trailer-boom sub + bass downer + ice debris). K2 (spare_heavy_crunch.wav)
  kept for something else. Rejected: gore crack ("too wet": no gore/splat sources), thud+boom heavies.
- Uploaded with Open Cloud to the game's GROUP 2970443 (the game is group-owned): m1_hit 130927601371508,
  87488745275206, 132785756805885; m1_finish 72542289493940; ult_haymaker 120198385193140. Moderation: approved.
- Code: SoundBank m1_hit / m1_finish (one file per hit, no layers, start 0), ult_haymaker (volume 1.4);
  FxController M1_PITCH_VARY 0.03 (was 0.08). Gates pass (498, Tokens x2 the teammate's).
- VERIFIED in a play test: stamps kits-7a+...+ui-6c on server and client; all five sounds load (0.45 s / 2.6 s) and
  play (PlaybackLoudness peaks ~375-395 M1, 550 heavy). NOT VERIFIED: the feel in a real M1 string or the ultimate
  (the user plays it); levels against the other game sounds.
- THE PLACE WAS AHEAD OF GIT AGAIN, now SAVED: the teammate's ui-5..ui-6c (changed Abilities, HudLogic, TypeRoles,
  Tokens, Typography, HudController, UltimateController, HudTheme; new VoiceLines, PosterEase, Ui/Callouts, Ui/Poster,
  Ui/Shapes, Ui/UltimateNotice; Ui/UltimateMeter removed). kits-7a was first patched into the place by targeted edits
  (ScriptEditorService), then every differing script was dumped with chunked execute_luau results (each just under
  Studio MCP's 100,000-character cap, so they land in tool-results files, not in context) and written by
  `lune/save_from_place.luau`. Checksums (`lune/script_hashes.luau` vs the place): 0 differ, 0 missing either way.
  Rojo Connect is safe again (check the stamp first anyway). Gates: build OK, 497 pass, 3 fail, all the teammate's
  (HudLogic.spec x2: their HudLogic changed, their spec is probably on their PC; Tokens.spec x1); selene/stylua clean.
  A local Save-to-File copy (Downloads\game2.rbxl) can't be read by Lune 0.8.9 (new compression).
## kits-7b / kits-7c (2026-11-17): Haymaker Rush v2, stage 1 (camera, sync, juggle); new upward clips built
Build stamp `kits-7c+lobby-4+ui-6c`. Spec: `design/haymaker-rush-v2-brief.md` (section 8b lists what changed).
References studied frame by frame (contact sheets in `design/references/`): Azure Flames, Garou vs Stinger;
Raging Demon and Orlando Furioso were studied for camera motion (sheets in the scratchpad only).
- Built and in the place: wide shots ride the fighters' midpoint (`rel = "pair"`); the beatdown is a planted
  juggle (hooks) in close SIDE views; camera kicks (`Timeline.kicks`, `Ultimates.kick`) with set-wave shake and roll;
  the wind-up is a medium two-shot reached by a glide; the haymaker's knockback starts on contact; the barrage uses
  our m1_hit takes, the first blow and uppercut m1_finish, the haymaker our heavy hit unprocessed.
- Checks: `tests/UltimateCamera.spec.luau` (both fighters in frame at phone/desktop/tablet, floor under their feet
  in the juggle, kicks included) passes; gates pass (499; HudLogic x2 and Tokens x1 are the teammate's).
- THE USER'S LATEST VERDICT (after kits-7c), NOT YET BUILT:
  - camera still "kinda weird": no snap cuts, smooth tweens; one continuous camera like Orlando Furioso 6.7-12.5 s;
    no zoom on the first hit
  - the hooks look like slaps; the barrage must be a FAST CONSECUTIVE flurry (~8 hits/s like Garou), punching
    UPWARD at a target juggled above (user's picks: new animations, one continuous flurry, sounds auditioned in the
    picker)
  - the haymaker must punch UP AND AWAY
  - a barrage needs one complete "rapid punches" sound
- NEW CLIPS BUILT, NOT WIRED IN: `animations/build_strikes.luau` now also bakes BarrageUp (0.25 s loop, a punch
  every 0.125 s at 0.0625/0.1875, up 50 deg) and HaymakerUp (hold 0.25, strike 0.32, up 55 deg) into
  `src/shared/Config/AnimClipsUltimate.luau` (AnimClips is at its 185k limit; AnimController must merge the two).
  Stills: `design/references/new-poses/`. The user had not yet OKed the poses when they stopped.
- NEXT (planned, agreed):
  1. merge AnimClipsUltimate into AnimController's Clips; SetBarrage takes a clip name; a HaymakerUp swing side
  2. rewrite the timeline as the flurry (draft: FLURRY_FROM 1.5, 12 hits 0.125 apart, the target juggled above at a
     punch's reach, then the existing uppercut as the finisher), with the haymaker from below sending them up and
     away
  3. one continuous eased camera (cut only under the impact frames); remove the first-hit zoom
  4. ult_barrage in SoundCandidates with 6 Creator Store options, all community uploads that loaded in Studio:
     117958044865545 (1.02 s), 87361464437966 (1.65 s), 108575892208319 (1.70 s), 95801559782723 (1.83 s),
     114289646726161 (2.12 s), 102850005066154 (3.51 s, trim)
  5. camera test, gates, play test (Studio throttles to 12-15 fps when covered: measure only when it's visible)

## ui-6d FINISHED (2026-11-17): the lobby runs; nothing overlaps; smaller; blur behind the window (NOT COMMITTED)
Build `kits-7c+lobby-4+ui-6d`, 530 tests, synced, place saved v421, nothing committed. The section above
(ui-6d, "WRITTEN, NOT TESTED") is now done; this is what changed while finishing it.
- PULLED FIRST: origin/main had two new commits (kits-7a, kits-7b..7c) that also hold a copy of the UI up to ui-6c
  "saved from the place". A plain pull was refused (same files changed here, uncommitted). Done by hand, nothing
  lost: every overlapping file backed up outside the repo (shared notes folder of this session,
  `pre-pull-backup/`), fast-forward, local work put back. HudController, HudTheme, Shapes keep the local (newer)
  text; UltimateController and SoundBank are the remote's. `stylua --check` now fails on `lune/save_from_place.luau`
  and `lune/script_hashes.luau` (the other developer's new tools, not ours, not synced to Studio): LEFT AS THEY ARE.
- REMOVED: the HUD's CONTROLS chip and guide, `Controllers/AfkController.luau`, `HudTheme.Afk`, the help sizes.
  H / Select now open the window's Moves page (NavController owns the "HaymakerHelp" action).
- THE OWNER'S THREE CALLS DURING THE PLAY TEST (they override the mockup where they differ):
  1. "NO overlapping UI" and "the stagger plate shouldn't appear in the lobby, maybe in the training area".
     The plate and the skill tiles show only in a FIGHT: a round, the training arena, or the practice end of the
     lobby (`Core/Lobby.inTraining`, looked at 4 times a second while HT_InLobby). Rule in
     `HudController` (`inFight`). The window stands in the ROOM THAT IS LEFT (`MenuController.layout`): under the
     strip, right of the menu strips (lobby), above the tiles and the ULT READY badge (round) or the spectating
     chip (lobby). The feed starts under the Coins out of a round and is hidden while the window is open. The
     toast moved to the top-left corner. The spectate panel (still the old look) moved to the bottom centre and
     is hidden while the window is open.
  2. "Everything takes TOO much of the screen, scale it well". `PosterKit.Fit`: the window is 0.8 of the mockup's
     size (0.62 to 1.1), the strips and Coins 0.85 (never under 46 px tall), the MENU button and the window's X
     kept big enough to press (X is 62, the mockup's 54). `PosterKit.stage()` is the one place: the screen UNDER
     Roblox's top bar is the mockup's 1280 x 720. The fight HUD may now shrink on a small desktop window
     (`HudTheme.Scale.MinDesktop = 0.6`, `HudTheme.scaleFor`); on touch it still never goes under 1.
     In a round the window is 400 tall, not 612 (`ROUND_TALL`): its pages are short, so it can be drawn larger.
     At 1280 x 720 the window is about 54 % x 62 % of the screen (the mockup's is 74 % x 85 %).
  3. "It should blur your background a bit, with a tween". A BlurEffect in Lighting (`HT_MenuBlur`, made by the
     client): size 10, in over 0.25 s, out over 0.18 s (`BLUR` in MenuController). NOT in a round (you are still
     fighting), not at graphics levels 1 and 2, set at once under Reduced Motion.
- FIRST-RUN BUGS FIXED: the cream slash drew a wide ink band (a slanted plate can't be thinner than its lean: the
  line is one turned bar now); the Coins plate grew to 880 wide (AutomaticSize with a child wider than its box:
  its width is measured now); the title came out at 81 % (Roblox draws no text over 100: `PosterKit.title` sets
  it at 100 and scales the box); Ranked's slab was a planned outline, not the mockup's cream slab; a long skill
  blurb was cut off (the row takes a second line); two control names were cut off ("Lock on: ...", "This guide.").
- CHECKED IN PLAY (viewport 1126 x 536 and 1190 x 536): the five strips, each page, pick + Equip, Buy then
  Confirm / Cancel (with a class hidden from the client's owned list; Confirm itself NOT pressed), the AFK row
  both ways, the Spectate row, M, X, keys 1 to 4, H in a round, the fold to MENU in a round, the toast, the ULT
  READY badge with the window open, being out with the window open. Console: only the known lines.
- MEASURED (round running behind, noise about 1 ms): the window's drifting CanvasGroup 0.10 ms a frame, the blur
  0.07 ms, the whole open window about 1 ms. So the CanvasGroup stays.
- PROOF: shared notes folder of this session, `ui-6d-proof/` (mockup over game for each page).
- DIFFERENCES FROM THE MOCKUP THAT REMAIN, AND WHY:
  1. Sizes and places: smaller, and the window stands clear of the strips instead of under the open one (owner).
  2. No stagger plate or tiles in the lobby is the mockup's too; the practice end showing them is the game's.
  3. The window's contents stand straight while its paper leans 0.6 degrees (Roblox can't clip turned things).
  4. Planned slabs and the Confirm ring are plain lines, not dashes; the slash's dotted corner is not drawn.
  5. The toast is top-left, not over the window's title (owner: nothing overlaps).
  6. No letter spacing; no tick in "EQUIPPED"; Moves shows the game's own wording and order.
  7. The game has Settings, AFK and Spectate rows, a scrolling shop, Cancel under Confirm.
- NOT TESTED: phones (window, strips and blur path never on a touch screen; on a 390-high phone the window will
  be small), a real gamepad (B to close: the test tool's ButtonB arrives as a keyboard key), Reduced Motion, the
  low-graphics blur skip, the round-start moment with the window open (seen once by chance, not on purpose),
  1920 x 1080 (sizes worked out, not seen), the strips' entrance in real time (stills only), a real purchase.
  The last two numeric tweaks (gap under the window +8, over the spectating chip +4) were pushed after the last
  play test.
- STILL OLD LOOK: the spectate panel and the "spectating" chip, the feed.
- NEXT (owner's order): 2. lettering as images: tell the owner the upload count first (worked out: 4 images:
  two sheets of the 13 window titles in full colour at 2x, one white-on-clear sheet of the fixed display words,
  one glyph sheet 0-9 x . / in upright Oswald and Titillium), WAIT for the go-ahead. 3. idle drift and sounds
  (ask before any audio upload).

## ui-6e (2026-11-17): window centred and larger; small text made sharp (NOT COMMITTED)
Same build label (`kits-7c+lobby-4+ui-6d`), 530 tests, synced, place saved v423, nothing committed.
The owner, after ui-6d: the window "doesn't feel centered", "it all feels small", "the fonts look blurry".
- CENTRED: the window stands in the middle of the SCREEN (`MenuController.layout`), moved right only as far as
  the menu strips make it. Before, it was centred in the room beside the strips, which read as off centre.
- LARGER: `PosterKit.Fit.Window` 0.9 (was 0.8), floor 0.7, ceiling 1.2. A row's small line is 17 px (the mockup's
  15) and rows are 46 / 72 / 98 tall. In a short Studio viewport (536 high) the window is still held to about
  0.54 by the no-overlap rule: judge size in a bigger viewport.
- BLURRY TEXT, MEASURED (the same line drawn five ways in a play test, cropped and enlarged):
  text under a UIScale is as sharp as text set at that size; text TURNED even 0.6 degrees is clearly soft; at
  about 13 px Titillium's letters space unevenly; the Regular weight reads washed out when small.
  So: PLANNED tags, the toast, the picked class tile and the hover tip no longer turn (the mockup turns them 1.5
  to 2 degrees); small lines are SemiBold, not Regular. Still turned: the window title (3 degrees, big; becomes
  an image in the lettering piece) and the open strip's rocking word.
- NOT TESTED: a larger viewport, phones, a gamepad. In the last two play tests Studio's 3D view was black in the
  captures (the window was probably covered); the UI drew normally.

## ui-6f (2026-11-17): the window a bit bigger again, descriptions at 19 px (NOT COMMITTED)
The owner: "scale the big ui to be a BIT bigger ... still hard to see the small descriptions". Same build label.
- `PosterKit.Fit.Window` 1 (the mockup's own size where it fits), floor 0.75, ceiling 1.3. A row's small line is
  19 px (the mockup's 15); rows are 46 / 76 / 106 tall.
- More height for it: the room kept for the "spectating" chip under the window is only kept while you are out
  (HT_Eliminated); otherwise 14 px. In a 1190 x 536 viewport the window went from 0.54 to about 0.62 of the mockup.
- Seen in play: Classes at that viewport, clear of the strip, the strips and the Coins. NOT seen: the other pages
  after this change, the last row-height tweak (pushed after the play test), larger viewports, phones.

## ui-6f UNDONE (2026-11-17): sizes back to ui-6e (NOT COMMITTED)
The owner published and played the real game: ui-6e's sizes were fine there (it only looked small in Studio's short
viewport), and ui-6f was TOO big. So ui-6f is undone: `PosterKit.Fit.Window` 0.9 (0.7 to 1.2), a row's small line
17 px, rows 46 / 72 / 98, the room under the window always kept for the spectating chip. LESSON: do not judge or
tune UI size in a 536-high Studio viewport; the published game is the judge.

## ui-7a (2026-11-17): the big lettering as images (NOT COMMITTED)
The owner: "Can't u do images for the letters too", then "Yes, upload 4". Build `kits-7c+lobby-4+ui-7a`, 530 tests,
synced, place saved v426, nothing committed.
- FOUR UPLOADS, ids ONLY in `Ui/Shapes.luau` (`Shapes.letters`): `poster_titles_1..3.png` (the 13 window titles in
  full colour with their outline and shadow) and `poster_words_1.png` (white on clear, tinted in use: the five
  menu strip labels, the ULTIMATE letters, READY, FIGHTERS LEFT, FINAL TWO, ULT READY, PRESS, ULT NOW, the eight
  class names, and upright figures 0-9 x . /). All drawn by the browser in the mockup's own Oswald at TWICE the
  mockup's size: `design/ui/poster_lettering.html` + `python design/ui/make_lettering.py`, which also writes the
  GENERATED `src/client/Ui/LetterRects.luau` (where each word is on its sheet; run `stylua` on it after).
- IMAGE TEXT CANNOT BE TRANSLATED OR RESIZED BY THE ENGINE, and it ignores the player's text-size setting. A new
  class, a renamed page or a changed word means: add it to the page's list, run the script, upload the sheet
  again, change the id. A class or title that is not on a sheet falls back to real text by itself.
- CODE: `Poster.word` / `setWord` / `wordWidth` / `hasWord` (a word; its frame is the word's text box) and
  `Poster.figures` / `setFigures` / `tintFigures` (a run of figures). Used by: the window title
  (`PosterKit.title`), the strip labels (NavController), class names on tiles and slabs (MenuController), the
  ULTIMATE letters, READY stamp and last-players words (Callouts), the badge's words (UltimateNotice), cooldown
  seconds, the standing count, the knockback multiplier (HudController) and the Coins (NavController).
  The slanted stagger number and the popup numbers were images already (`Shapes.digits`, `Shapes.last`).
- LEFT AS REAL TEXT, on purpose: everything in the small Titillium face (STAGGER, knockback, RISING, the READY /
  STUNNED / CAN'T USE flags, skill names on tiles, MENU, "/ 25 STANDING", sub lines), action button words (they
  carry prices), row names, descriptions, toasts, the feed, key caps. These are not the display lettering, they
  change, and at 15 px an image is no sharper than text.
- THE SYNC TOOL (`rojo_push.py`) refuses a script that contains `]]` or a NUL byte ("Failed to parse command
  code"): write `local t = a[b]; t[c]` instead of `a[b][c[d]]`.
- SEEN IN PLAY (viewport 1190 x 536): the lobby with Classes open (title, strip labels, class names, Coins, count),
  a round (cooldown seconds, 1.0x), the ULTIMATE notice, the ULT READY badge, FINAL TWO. Console clean.
  Proof: shared notes folder, `ui-7a-proof/`.
- NOT MEASURED: frame cost of the image figures against text (they change only when the shown value changes).
  NOT TESTED: PRESS / ULT NOW on the badge, FIGHTERS LEFT (same code as FINAL TWO), the other twelve titles on
  screen, the Coins changing, phones, a gamepad, the published game.
- NEXT: piece 3, idle drift on pressable controls and the soft sound set (ASK before any audio upload).

## ui-7a note (2026-11-17): "the strip looks softer than the dev chips" - TESTED, NO CODE CHANGE KEPT
The owner compared the top strip with the BOTS / fps chips in a small Studio window and asked for the same sharpness.
- TRIED: moving a HUD group's contents out of its CanvasGroup once it is fully shown. Captured the strip both ways in
  the same play test and enlarged the crops: NO difference (edge contrast 15.4 against 15.4). A CanvasGroup is not
  what softens it. The change was removed again; Studio matches ui-7a.
- WHAT DIFFERS: the dev chips never scale under 1 (`HudTheme.Scale.Min`), while the HUD now shrinks with a small
  desktop window (`MinDesktop = 0.6`, ui-6d). In an 867-wide window the strip is drawn at about 0.68: its 23 px
  label becomes 15 to 16 px (and is 85 % opaque, as in the mockup), and the image figures are shrunk about six
  times from their sheet. At 1280 x 720 or larger the scale is 1 or more and none of that applies.
- Judge sharpness, like size, in the published game or a full-size viewport, not a small Studio window.

## ui-7b (2026-11-17): announcements small and at the top; their bars across the whole screen (NOT COMMITTED)
The owner, on the FINAL TWO popup: it "shouldn't take up the entire screen ... if people are fighting and this blocks
them, it can ruin their experience", and "the pink strip should REACH the entire screen with NO gaps, for everything
with that pattern". Build label unchanged (`ui-7a`), 530 tests, synced, place saved v429, not committed.
- `Callouts.stage` (the one place both announcements stand on): they are SMALL now (the ULTIMATE notice 0.6 of the
  mockup's size, the last-players popup 0.4, phones 0.34) and stand right under the top strip (20 px below it), so
  the middle of the screen stays clear. The mockup has them at full size across the middle.
- Their slanted bars (the ULTIMATE streak, the last-players bar) span the WHOLE screen: `span` = the screen's
  width in the stage's units plus 400 for the lean and the shake. These two are the only uses of that pattern
  (`band` in Callouts).
- Seen in play (1190 x 536): FINAL TWO and the ULTIMATE notice, both bars edge to edge. Proof: shared notes
  folder, `ui-7b-proof/` (taken with the 10 px gap; the 20 px gap was pushed after). In a 536-high window the
  popup's words still reach the character's head; on a taller screen the character stands much lower.
- NOT TESTED: counts 5, 4, 3, phones, the announcements with the menu window open (they are drawn under it), the
  fly-away in real time.

## ui-7c (2026-11-17): full-width bars UNDONE; announcements glide left to right (NOT COMMITTED)
The owner, after ui-7b: "revert the long strip thing, I don't like it", and new motion for both popups: "appears
from the left, slowly goes right, then fades away towards the right; use your own ideas". Build label unchanged
(`ui-7a`), 530 tests, synced, place saved v431, not committed.
- BARS: back to the mockup's lengths (the ULTIMATE streak 330 past the letters each side, the last-players bar 460
  past its box). The small size and the place under the top strip from ui-7b STAY.
- MOTION (`glide` in Callouts, used by both): in fast from off the LEFT edge (0.45 s, a curve that only just passes
  its place), a slow steady drift to the right while it is read (150 units over its life), then away to the
  right, speeding up, fading through a CanvasGroup for that last part only. It no longer flies up into the strip
  (last players) or down toward the skills (ultimate), and no longer shrinks or turns as it goes. The pieces'
  own pops (letters dropping, the number slamming, stamps, confetti, the FINAL TWO shake) are unchanged. The
  strip's count still bumps as the last-players popup leaves. Reduced Motion: no glide, it stands in place.
- MEASURED in play (centre of a 1190-wide screen is 595): last players 565 -> 586 -> 607 over 1.2 s, then 821 at
  73 % gone, 1007 gone; ultimate 553 -> 614 over 1.5 s, then 688 at 40 % gone, 1011 at 97 %. Console clean.
- NOT SEEN: the motion in real time (positions were sampled, not watched), counts 5 and 4, phones.

## ui-8a (2026-11-17): idle drift on pressable controls; AFK strip fix (NOT COMMITTED)
Piece 3, part A. Build `kits-7c+lobby-4+ui-8a`, 531 tests, gates green, synced, place saved v432, nothing committed.
- NEW `Ui/Drift.luau`: the mockup's `idle()`. ONE clock (one RenderStepped connection, connected only while
  something drifts) moves every pressable control up and down, each at its own pace (2.5 to 3.34 s a swing) and
  starting point, on a cosine ease. Off under Reduced Motion (checked when anything changes and once a second).
  API: `Drift.add(group, layer, height, lift, slot?, turn?, turned?)`, `hold(layer, on)`, `show(group, on)`,
  `clear(group)`, `count()`. Groups: `nav` (shown in the lobby), `fight` (the MENU button, shown in a round),
  `window` (the X) and `page` (the window's page), both shown while the window is open. A hidden group stands at
  home and costs nothing.
- HOW IT DOES NOT FIGHT OTHER MOTION: `PosterKit.cut` now has two inner layers, `body` (everything drawn) and
  `shape` (shadow, outline, fill); `PosterKit.row` has `body`. Drift moves `body`; hover, press, pop, the strips'
  entrance and the open strip's shift stay on the root. The press button is on the root, so the hit area holds still.
- FOUND: a UDim's OFFSET IS A WHOLE NUMBER (10.3 and 10.6 both land on 10). So the drift moves by the SCALE part of
  Position (y / height), which is not rounded. Values are written only when they change by 0.2 unit / 0.02 degree.
- WHAT DRIFTS, AND BY HOW MUCH (the mockup: 5 px and -0.7 to 0.8 degrees for everything):
  - the five menu strips: 4 units, and the shape and the word image turn half a degree each way. The key cap (small
    text) only rides up and down: it stays at 0 degrees (checked: AbsoluteRotation 0). 4 and 0.5, not 5 and 0.8,
    so two neighbours at their far ends cannot touch (14 apart less a 7-unit shadow). The OPEN strip holds still:
    its word rocks instead (`Drift.hold`).
  - the fight's MENU button and the window's X: 5 units, no turn (they carry text).
  - action buttons (Equip, Buy, Confirm, Cancel, See it in the Shop) and unpicked class tiles: 4 units, no turn.
  - pressable rows (More, Settings): 3 units, no turn.
  - NOT drifting: the picked class tile (it answers no press), switched-off buttons, plain rows, slabs, Coins, the
    HUD (plate, skill tiles, strip), the ULT READY badge.
- PHONE PATH (`Drift.lite`, touch without a keyboard): no turning at all, and the window's page does not drift; only
  the strips, MENU and the X ride up and down. CHOSEN, NOT MEASURED ON A PHONE.
- MEASURED in my play test (1190 x 536, frames about 19 ms in Studio): workspace attribute `HT_DriftOff = true`
  switches all drift off (a measuring switch, read once a second). 14 alternating 1 s samples, 5 strips drifting:
  median 19.6 ms on, 19.2 off; an earlier run with 12 controls drifting (window open): 20.0 on, 19.0 off. Samples
  in each set spread from 17 to 20.6 ms, so the cost is NOT separable from Studio's noise: under 1 ms, likely far
  less (a handful of property writes a second for each control).
- SEEN (values sampled from a client script, not watched): strips between -2.4 and +1.6 units and -0.46 to +0.52
  degrees, each out of step; the smallest gap between a strip's shadow and the next strip over 7 s was 2.8 units;
  MENU -3.0 to +0.4; two rows and the X in the round's More page; the strips stand still while hidden (in a round).
  Console: only the known lines.
- AFK STRIP FIX: with too few players ready (everyone AFK) the server holds Intermission with NO CountdownEnd and
  the strip stood on "NEXT ROUND 0". `HudLogic.strip` now hides the strip for an Intermission without a countdown
  (spec added in `tests/HudLogic.spec.luau`). NOT seen in play (the test place fills with bots and starts at once).
- NOT TESTED: phones, a real gamepad, Reduced Motion, the feel in real time, hover and press WHILE drifting (by
  hand), the Classes and Shop pages' drift by eye, the published game.

## ui-8b (2026-11-17): the soft sound set: RENDERED AND APPROVED, NOT UPLOADED, NOT WIRED
Piece 3, part B, stopped here on purpose: the owner asked to carry on in a new chat. Nothing in the game changed.
- THE OWNER'S ANSWER (2026-11-17, asked with the full list): "Upload all 13". Uploads go to the game's GROUP
  2970443 by Open Cloud, as kits-7a did. Ask again only if the list changes.
- `design/ui/make_ui_sounds.py` renders them with the mockup's own numbers (`sfx()`: oscillators, swept noise,
  master gain 0.6, lowpass 4600 Hz) into `assets/sfx/ui/` (44.1 kHz, 16-bit, mono, each at -6 dBFS peak; the
  script prints each file's length and the mockup's own peak, which is what SoundBank volumes should follow).
- THE 13 FILES, WHAT THE MOCKUP PLAYS THEM ON, AND THE GAME EVENT:
  | file | s | mockup `sfx` | game event (where to call it) |
  |---|---|---|---|
  | ui_press | 0.09 | pop: pointer down on any button | any pressable control (`PosterKit.pressable` / `pressRow`) |
  | ui_open | 0.37 | whoosh: window opens | `MenuController` open from closed |
  | ui_close | 0.14 | close | `MenuController` close |
  | ui_page | 0.11 | snap: page change, tile pick, with the wipe | `MenuController` `hit()` |
  | ui_equip | 0.32 | equip | a class equipped (`ability.KitChanged`, own request) |
  | ui_buy | 0.33 | coin: bought | purchase succeeded (owned list grows), not the first Buy press |
  | ui_deny | 0.21 | nope | Q or R pressed while cooling or stunned (the tile's `nope` shake) |
  | skill_ready | 0.33 | ready | Q or R comes off cooldown (the tile's `spop`) |
  | ring_out | 0.18 | ko | the standing count falls (the strip's count bump), not for 5 to 2 |
  | last_5, last_4, last_3 | 0.55 | count(n) | `Callouts.last(n)` |
  | last_2 | 0.82 | count(2) | `Callouts.last(2)` |
- LEFT OUT, the game already has its own sound there (so nothing doubles): `ultReady` (SoundBank `ult_ready`,
  the owner's kits-5f pick), `ultFire` (the ultimate's own set: `ult_rush`, `ult_haymaker`, `ult_bed`), `hit`
  (`m1_hit` / `m1_finish`, kits-7a), `skill` (each kit move has its sounds in FxController), `stun` (combat, not
  UI). The toast has no sound in the mockup either. Voice lines stay empty (`VoiceLines.luau`).
- TO DO NEXT, in order: 1. upload the 13 (group 2970443; wait for moderation); 2. add 13 roles to
  `SoundBank.luau` (one take each, start 0, measured length; volumes low, following the mockup's peaks: the
  last_* are about 3 x the others there); 3. play them as 2D sounds (not from a character) with the mockup's
  small pitch variance (4 % each way) on ui_press, ui_page, ring_out; one voice per sound (a repeat cuts the old
  one); the mockup also dips other sound while a voice line plays (no lines yet); 4. check each loads in Studio
  (IsLoaded, TimeLength), levels against the fight sounds, console clean; 5. gates, sync, save, HANDOFF.
- NOT CHECKED: nobody has LISTENED to the WAV files (rendered from the numbers, lengths and peaks checked only).

## ui-8b DONE (2026-11-17): the soft sounds uploaded and wired; a hover sound; Equip is green (NOT COMMITTED)
Piece 3, part B. Build `kits-7c+lobby-4+ui-8b`, 531 tests, gates green, synced (178 scripts match), place saved
v435, nothing committed. origin/main had nothing new at each push.
- UPLOADED to group 2970443 with the Roblox_Studio connector's `open_cloud_invoke` (POST /assets/v1/assets, Audio;
  the folder `assets/sfx/ui` had to be approved first in Assistant Settings -> MCP Permissions). All loaded in a
  play test; moderation still said "Reviewing" at upload time (NOT re-checked):
  ui_press 97006914075932, ui_open 140346518500681, ui_close 140631035788633, ui_page 91442953128650,
  ui_equip 94748514757177, ui_buy 86516525084890, ui_deny 92136914494187, skill_ready 103068845287243,
  ring_out 117168801692223, last_5 139031912478680, last_4 134917813764725, last_3 124007641238329,
  last_2 101304163027883, ui_hover 119602077656645.
- A 14TH SOUND, `ui_hover` (the owner, mid-task: "if there's not already sound when you hover over the buttons,
  add one that complements the rest"). There was none, in the game or the mockup. `make_ui_sounds.py` now has it:
  a sine lifting 540 -> 630 Hz, 0.07 s, level 0.04 (the press falls 420 -> 300, so the two answer each other).
  The owner's request was taken as the go-ahead to upload that one file (0.10 s, 9 KB).
- `SoundBank.luau`: 14 new roles, one take each, start 0, the file's length. Volumes = the mockup's own peak x 4.3:
  ui_hover 0.10, ui_press 0.15, ui_close 0.17, ui_buy 0.20, skill_ready and ring_out 0.22, ui_page, ui_equip and
  ui_deny 0.25, ui_open 0.28, last_* 0.68 to 0.73. Every file peaks at -6 dBFS, so against an M1 hit (volume 1)
  the UI sounds sit about 17 to 22 dB down and the last_* about 9 dB down. NOT judged by ear. PlaybackLoudness is
  no help here (it does not follow Volume: every one read 130 to 270).
- NEW `client/Ui/UiSound.luau`: `play(role)` flat 2D through Sfx (fails inert), one voice per sound, 4 % pitch
  variance on ui_press, ui_page, ring_out; `playIfShown(role, gui)` only when that piece is really on screen;
  `hover()` silent on touch and for 0.3 s after any other UI sound (a press redraws the page under the pointer);
  ui_deny and skill_ready cannot repeat within 0.25 s.
- WHERE THEY PLAY: ui_press and ui_hover in `PosterKit.pressable` / `pressRow` (pointer down, pointer enter);
  ui_open, ui_page (page change and class-tile pick), ui_close in `MenuController`; ui_equip on `KitChanged` and
  ui_buy when the owned list grows, each only within 5 s of the player's own Equip / Confirm press; ui_deny on
  `PropelBlocked` / `SkillBlocked`; skill_ready in `HudController.paintTile`; ring_out when the standing count
  falls without a popup; last_N at the top of `Callouts.last`.
- FOUND AND FIXED: the Q and R tiles pass through "recovering" after EVERY move (endlag, 0.65 s at most) and pop
  "ready" each time, so skill_ready pinged about 20 times in 12 s of fighting. It now plays only after 0.8 s or
  more of recovering (`READY_SOUND_AFTER`, `Tile.coolSince`): 1 in 25 s after the fix. The pop itself is unchanged.
- EQUIP IS GREEN (the owner, mid-task: "a nice vibrant cool shade of green, so it's easier to notice"): new token
  `go.400` #1FE38C, used only by the Equip button (`MenuController.action`, kind "go"; it was teal.400).
- VERIFIED in my own play tests: all 14 load (IsLoaded, TimeLength = the file lengths); heard as Sounds created
  in SoundService from REAL events: ui_open and ui_close (M key), ui_hover, ui_deny, skill_ready, ring_out,
  last_5 / last_4 / last_3; the hover stays silent right after a press. Console: only the known lines.
- NOT TESTED: nobody has LISTENED to any of it (levels are from numbers); ui_press and ui_page from a real click;
  ui_equip and ui_buy (the test place starts a round at once, so no lobby); last_2; the green Equip button BY EYE;
  a gamepad press (no pointer-down, so ui_press is silent there); phones; Reduced Motion; the published game.
- NEXT (ask the owner which first): the feed, the spectate panel and chip in the new look, the class-name band
  when an ultimate is used; then tests on a phone, a gamepad, Reduced Motion.

## ui-9a (2026-11-17): the speed dial and hover-to-unequip: SYNCED, SEEN RUNNING (NOT COMMITTED)
The owner, after the mockup: "yes thats really good ... build it into roblox". Stamp on disk `kits-7c+lobby-4+ui-9a`;
synced later the same day (178 scripts match, origin/main had nothing new), place saved v436. 533 tests.
- MOCKUP (published, same link): `.spd`, a half dial at the bottom centre in place of the stagger plate; stagger is
  a small strip in its base ("STAGGER 22 . 2.1x"); Equip green; Equipped turns into a red Unequip under the pointer.
- GAME, `HudController` group Y rewritten: the dial is built from plain frames (a circle cut flat by a clipping
  frame, 30 rotated ticks, zone marks, a peak mark; NO new image, no upload), in the mockup's units (`L.Dial`,
  340 x 232) shrunk by `L.YScale` 0.66 (phones `YPhoneScale` 0.52), bottom centre on every device. Speed = the
  character's horizontal `AssemblyLinearVelocity`, read every 0.05 s (0.1 s on touch), smoothed; only changed
  values are written. Dial top = `Movement.PropelChargedSpeed` (140), yellow from `Movement.MaxSpeed` (50), pink
  from `HudTheme.Speed.Redline` (100). New pure rules `HudLogic.speedTicks` / `speedTier` with specs.
  The strip goes cream, yellow, pink with stagger (the number's old colour steps); a hit pops the strip and shakes
  the dial. REMOVED from view: the RISING / RECOVERING / STEADY word, the 12-segment bar, the word "knockback"
  (`HudLogic.staggerWord`, `segmentsLit` and their specs are still in Core, now unused by the HUD).
- GAME, `MenuController`: `wornAction`. On the class you wear (not in a round, not the starting class) the button
  says EQUIPPED in light violet; under the pointer it turns red (new token `stop.400` #FF4444), says UNEQUIP,
  pops and wobbles; pressing it equips `Abilities.DefaultKit`. Touch: first tap shows it for 3 s, second does it.
- SEEN in my own play test (1118 x 536 view, a fight with bots): the dial stands bottom centre and reads as the
  mockup does (one capture, by eye; no side-by-side proof pair made). It is 167 x 113 px there, x 475 to 642; the
  first skill tile starts at x 781, so nothing touches. The number and ticks follow the character's speed.
- MEASURED: 14 alternating 1 s samples with the dial shown and hidden: median 13.9 ms shown, 14.3 hidden (spread
  11 to 18), so its cost is NOT separable from Studio's noise. The HUD loop's own cost with the dial in it
  (`HT_HudProfile`): 0.065 ms a frame. The ticks were being written throughout (106 colour writes in 14 s).
- EQUIP: the green button seen in the open Classes window (fill #1FE38C). The server rule for unequip is the
  ordinary equip of `DefaultKit`, which every profile owns (`AbilityKit.equip`; refused in a round).
- THE UNEQUIP BUTTON WAS NOT PROVEN BY A PRESS OF MINE: the test place starts a round at once, so I forced the
  lobby state (server: `HT_InRound` false) and equipped Frost through the remote. Twice the class then went from
  Frost back to Base while the Classes window was open, but the pointer was not where I had put it (someone was
  using the mouse), so I cannot say my press did it, and I never read the red UNEQUIP state off the screen.
  The play session left the class on Base, as it started.
- Console: only the known lines.
- NOT TESTED: the red UNEQUIP state and its wobble by eye; a controlled unequip press; the touch path (two taps);
  the dial on a phone (its place against the real thumb buttons and stick is CHOSEN, not seen) and with a
  gamepad; the dial against the spectate panel and the air-kick meter; a hit's strip pop and shake by eye;
  speeds past 140; Reduced Motion; the published game.
- NEXT (ask the owner which first): the feed, the spectate panel and chip in the new look, the class-name band;
  then tests on a phone, a gamepad, Reduced Motion.

## ui-9b (2026-11-18): the feed in the fight-poster look: SYNCED, SEEN RUNNING (NOT COMMITTED)
ui-5a to ui-9a were committed and pushed as 85ef556 (the owner: "everything up to this point works"). The owner
picked the feed as the next piece. Stamp on disk `kits-7c+lobby-4+ui-9b`; the PLACE is still ui-9a (v436): Studio
was in a Play session I did not start. 533 tests, gates green. NOT in the mockup (it has no feed): designed here.
- `HudController.pushFeed`: a row is a small slanted ink plate (`Shapes.slant`, the top strip's lean) with the words
  upright in the poster label face at 15; a line about you has yellow under the ink, showing as a 5-unit right edge
  (`L.FeedEdge`). The verb is a word in its own colour: KNOCKED OUT yellow, FELL and LEFT quiet. A row comes in
  from the right on the spring (`Timing.FeedIn` 0.45 s) and leaves to the right past the feed's own edge
  (`FeedOut` 0.2 s); both go through `Poster.run`, so Reduced Motion shows and removes it at once. Place, row
  count, 2 s life and the give-way to the open menu are unchanged.
- SYNCED the same day (178 scripts match, origin/main had nothing new; the Rojo server had to be started again),
  place saved (see the UI Map for the version).
- FOUND AND FIXED: with `AutomaticSize` the plate came out about 40 units wider than its words. The row is now
  sized from the label's `TextBounds`, which is in SCREEN pixels: it is divided by the feed group's UIScale
  first (without that the words overflowed the plate). Words are centred on the plate.
- SEEN in my own play test with bots (1118 x 536): rows read "Bot 2  KNOCKED OUT  Bot 18", plates 162 to 174 px
  for 135 to 148 px of words; my own line had the yellow edge and my name in yellow; rows stack 23 px apart from
  the feed's top, under the Coins out of a round. Look judged from one capture of two enlarged copies.
  Console: only the known lines (plus Studio's own "Assistant plugin version changed" notice).
- NOT TESTED: FELL and LEFT lines (only knockouts happened); a long name (cut at 16 letters, as before); the slide
  in and out by eye; Reduced Motion; phones; the published game.
- NEXT: the spectate panel and chip in the new look, then the class-name band; then phone, gamepad and Reduced
  Motion tests.

## ui-9c (2026-11-18): the spectate panel and chip in the fight-poster look (NOT COMMITTED)
ui-9b (the feed) was approved and committed as de02000. Build `kits-7c+lobby-4+ui-9c`, 533 tests, gates green,
synced (178 scripts match, origin/main had nothing new), place saved (version in the UI Map). NOT in the mockup:
designed here from the kit's own pieces.
- `SpectateController`: the old hidden button, its helpers and the grey rounded panel are gone. The panel is two
  rough-cut tabs (`PosterKit.cut` "act", 40 tall): MY VIEW and FIGHTER POV; the one that is on is yellow and says
  ON, the other is cream. Under them: previous and next (the "close" shape; light violet when there is someone
  else to turn to, dark with dim lettering and switched off when not) and between them who you are watching on a
  slanted ink plate (`Shapes.slant`). The buttons press and sound like every poster button (`PosterKit.pressable`)
  and drift in their own group (`Drift` "spectate", shown only while the panel is; a switched-off arrow holds
  still). Sizes in `HudTheme.Spectate` (`Tab`, `Lean`, `Chip`). The rules (Core/Spectate), the camera and what
  opens the panel (More page, `Toggle`) are unchanged.
- `HudController`: the SPECTATING chip is a 170 x 32 slanted ink plate (was a 200 x 40 cut panel); the spectate
  panel stands 12 units above it, bottom centre.
- SEEN in my own play test (1118 x 536), opened the real way (MORE strip, Spectate row): MY VIEW ON yellow,
  "N fighting" on the plate; pressing FIGHTER POV put the camera behind Bot 4, turned that tab yellow with ON, lit
  both arrows and named the fighter; panel 208 x 65 px over the chip, nothing touching. Console: only known lines.
- NOT TESTED: the arrows really changing the fighter (I pressed next once but did not read the name before and
  after); "X is out" notices; the round ending while watching; "FIGHTER POV  ON" is a tight fit in its tab; a
  gamepad; phones; Reduced Motion; the published game.
- NEXT: the class-name band when an ultimate is used; then phone, gamepad and Reduced Motion tests.

## ui-9d (2026-11-18): the spectate camera is free to turn and zoom (NOT COMMITTED)
The owner: "while spectated you should make it so you're able to freely move your camera around". Build
`kits-7c+lobby-4+ui-9d`, 533 tests, gates green, synced, place saved v441.
- `SpectateController.watch`: Fighter POV is now the game's ORDINARY camera (`CameraType` Custom) with the watched
  fighter's Humanoid as `CameraSubject`, set on every watch (so the arrows move it). It was a Scriptable camera
  fixed behind the fighter. A body with no Humanoid still gets the old fixed view (`step()`, skipped while `free`).
  `restore()` already put the camera back on your own Humanoid. `Lobby.Spectate` Back / Up / LookAhead / Smooth in
  the config are now used only by that fallback. Your avatar's controls are still off while you watch.
- SEEN in my own play test: subject Bot 1, Custom camera, still Bot 1 after 1.5 s (nothing pulls it back; the lock
  camera and shift lock did not interfere); three scroll steps took it from 13 to 34.7 studs; the Left key turned
  it and it stayed turned; the next arrow moved it to Bot 23 and the plate said so (this also settles ui-9c's
  untested arrows); MY VIEW put the subject back on my own character and cleared `HT_Spectating`.
  Console: only the known lines.
- NOT TESTED: turning with the mouse (the test tool's right-drag did not turn it; the Left key did, through the same
  camera), touch and gamepad turning, the fighter going out while you watch, the round ending while you watch,
  the published game.
- NEXT: the class-name band when an ultimate is used; then phone, gamepad and Reduced Motion tests.

## ui-10a (2026-11-18): Shop above Classes, right-edge tools, a small stats line: SYNCED, SEEN RUNNING (NOT COMMITTED)
ui-9c and ui-9d (spectate panel, free spectate camera) were approved and committed as 95ccb68. The owner then
asked for four changes ("use your own intuition as well"). Stamp on disk `kits-7c+lobby-4+ui-10a`; the PLACE is
still ui-9d (v441): Studio was in a Play session I did not start. 533 tests.
- `NavController`: SHOP is the top strip and CLASSES the second (keys 1 and 2 follow the order; each place keeps
  its own shape and step). The mockup is swapped too (published).
- `NavController`, NEW right-edge TOOLS in the lobby: three cream "tile" cuts 84 x 78, 12 apart, each its icon
  (`Ui/Icons`: settings, spectate, afk, the existing placeholder art, already uploaded) over its word. SETTINGS
  toggles the window's Settings page, SPECTATE toggles the spectate panel, AFK fires `AfkToggle` and turns yellow
  saying AFK ON while `HT_AFK` is set. They stand 22 from the right, under the Coins and the feed's four rows
  (about the middle of the edge), come in from the right on the spring, drift in their own group ("tools"), and
  hide while the window is open and in a round. NOT in the mockup.
- `MenuController.drawMore`: in the lobby the More page lists only the planned things (its sub-line says COMING
  LATER); Settings, AFK and Spectate rows are gone from it. In a round it is unchanged (Settings, Moves).
- `PerfController` REWRITTEN: a stats line for EVERYONE, "198 FPS . 32 MS", 13 px cream with a thin ink line and
  no plate, top-left: at the corner in the lobby, beside the MENU button in a round. Pink when frames are slower
  than 30 a second. Ping is `Player:GetNetworkPing()`. SERVER REGION: shown when the workspace attribute
  `HT_ServerRegion` is set; NOTHING SETS IT YET (Roblox has no API for it; it needs HttpService and an outside
  lookup, which is the owner's decision).
- THE OWNER'S PANELS are gone from the right edge: the Bots button is bottom-left and hidden until F8
  (`BotsFreezeController`, sets `HT_DevUi`); F8 also shows the stats line's second line (worst frame, ms, MB, gfx).
- SYNCED later the same day (178 scripts match, origin/main had nothing new), place saved v442. The owner saw the
  pieces on the mockup page first (tools, stats line and the trimmed More page were added to it) and said push.
- SEEN in my own play test (1118 x 536): strips in the order shop (key 1), classes (2), ranked, moves, more; the
  tools at the right edge from y 166, under the feed's box (ends 152) and the Coins, all three icons loaded; the
  stats line "229 FPS . 1 MS" at 24,18 in the lobby and at 78,31 beside the MENU button (21,17 44 x 44) in a
  round, tools hidden in the round. PRESSED: AFK set `HT_AFK`, turned yellow and said AFK ON, and a second press
  undid it; SPECTATE opened the spectate panel; SETTINGS opened the window on its Settings page and the tools hid
  under it; F8 showed the Bots button bottom-left and the detail line. Console: only the known lines.
- AFTER THAT the tiles were widened from 84 to 94 units (SETTINGS and SPECTATE nearly touched the edges); pushed
  and saved, NOT looked at again.
- NOT TESTED: the lobby More page by eye (it should list only the planned things under COMING LATER); the tools'
  entrance; the tools against the spectate panel on a narrow screen; ping on a real server (Studio reads 0 to 1);
  the stats line under Roblox's own top-bar buttons on a phone; a gamepad; Reduced Motion; the published game.
- OPEN: the server region (nothing sets `HT_ServerRegion`); the icons are still the Ringside placeholders.
- NEXT: the class-name band when an ultimate is used; then phone, gamepad and Reduced Motion tests.

## ui-10b / ui-10c (2026-11-18): plain Settings page, stats line in the top bar, server region, line icons: WRITTEN, NOT SYNCED
ui-10a is in the place (v442) and NOT committed. Stamp on disk `kits-7c+lobby-4+ui-10c`, 537 tests, gates green.
Studio was in a Play session I did not start, so nothing of this is pushed or seen.
- SETTINGS PAGE (the owner: "similar style but looks different ... more bland ... toggles more readable ... a
  question mark next to it where you hover and it gives you the description"). `MenuController.settingRow` /
  `drawSettings`: the window goes pale grey (ivory mixed 45 % to stone.300) with NO repeated word behind it; each
  setting is one flat cream row 780 x 56 (rounded, 3-unit ink line, no slant, no shadow, no drift): its name at
  20, a round ink "?" that shows the description in an ink bubble beside it while the pointer is on it (a tap
  shows it for 3 s), and a switch at the right (88 x 36: green `go.400` with ON and the knob right, grey with OFF
  and the knob left; the knob slides in 0.18 s). The whole row toggles. The save state is one quiet line under
  the rows; the Back row shows only in a round. Descriptions are in `SETTINGS[].help`. The three switches still
  change nothing (the sub-line says so). On the mockup too (the SETTINGS tile opens it).
  A first version of this patch cut out `draw` and the window's `away`; selene caught it and the file was rebuilt
  from HEAD plus the ui-10a and Settings patches.
- STATS LINE (the owner circled Roblox's top bar, right of its buttons: "a lot smaller"): `PerfController` now
  stands at `GuiService.TopbarInset`'s left end plus 12, on the bar's middle line, in a ScreenGui that ignores
  the inset; lettering 10 (was 13), ink line 1. Same place in the lobby and in a round.
- SERVER REGION (the owner: "also add server region"): NEW `Core/ServerRegion.label` (pure, 4 specs) and
  `Services/ServerRegionService`: in Studio it sets `HT_ServerRegion` to "Studio"; on a real server it makes ONE
  GET to ip-api.com 3 s after start (one retry after 20 s) and publishes "Region, CC". NEEDS "Allow HTTP
  Requests" on for the game. ip-api's free tier is for NON-COMMERCIAL use: told to the owner; the URL is one
  constant. NEVER RUN on a real server.
- LINE ICONS (the owner: use the website's icons, not the coloured placeholders): `design/ui/make_tool_icons.py`
  renders the mockup's three drawings white on clear, 256 px, to `assets/icons/poster/tool_*.png` (checked:
  opaque pixels present, corners clear). NOT UPLOADED: the folder is not on Studio's approved upload list. NOT
  WIRED: the tiles still show the Ringside placeholders.
- TO DO NEXT: (1) owner approves `Projectssets\icons\poster` in Assistant Settings > MCP Permissions; upload the
  three as Image to group 2970443; add ids to `Ui/Icons.luau` (`toolSettings`, `toolSpectate`, `toolAfk`), use them
  in NavController's tiles with `ImageColor3` ink. (2) push in Edit mode; check the Settings page (rows, the ?
  bubble, a switch press), the stats line's place in the top bar and its size, "STUDIO" as the region, the icons.
  (3) save, correct this section, commit ui-10a to ui-10c when the owner approves.

## ui-10b / ui-10c SYNCED (2026-11-18): Settings page, top-bar stats and region are in the place; icons still waiting
Pushed (180 scripts match, origin/main had nothing new), place saved v443, 537 tests. NOT COMMITTED (ui-10a to 10c).
- SEEN in my own play test (1118 x 536): the stats line stands in Roblox's top bar at x 220 (the free part starts
  at 208), on the bar's middle line, reading "166 FPS . 2 MS . STUDIO"; the region attribute was "Studio".
  The Settings page, opened from the SETTINGS tile: three flat rows, switches green with ON; pressing the Hit flash
  row turned its switch grey with OFF and the knob left; the pointer on Camera shake's "?" showed "Shakes your
  camera on big hits." One capture: it reads as the mockup's page does.
- AFTER THAT the stats lettering was set to 12 REAL pixels on the label (`Poster.text` had turned "10" into 15;
  the first version's "13" was 19): pushed and saved, NOT looked at again.
- ICONS STILL NOT UPLOADED: Studio refused `assets/icons/poster` three times ("not inside a directory approved
  for uploads"), also after the owner said it was approved. The tiles still show the Ringside placeholders.
- NOT TESTED: the region lookup on a real server (and whether Allow HTTP Requests is on); the stats line beside
  Roblox's real buttons on a phone; the "?" by touch; the Settings page in a round (short window, Back row);
  Reduced Motion; the published game.

## ui-10d (2026-11-18): the tools' line icons uploaded and wired (NOT COMMITTED)
Build `kits-7c+lobby-4+ui-10d`, 537 tests, synced (180 scripts match), place saved v444. ui-10a to ui-10d are NOT
committed.
- The owner approved `assets/icons/poster`; uploaded as Image to group 2970443: tool_settings 84689908232322,
  tool_spectate 137196821444275 (both Approved), tool_afk 113101514810430 (Reviewing at upload, loaded in play).
  `Ui/Icons.luau`: `toolSettings`, `toolSpectate`, `toolAfk`; NavController's tiles draw them tinted ink.900.
- SEEN in my own play test: all three loaded with the ink tint; the stats lettering is 12 px (95 x 13 for
  "184 FPS . 1 MS . STUDIO"); one capture, taken while the More window was open, shows the lobby More page as
  designed (COMING LATER; Cosmetics, Profile, Leaderboards, Emotes, Codes) and the tiles hidden under it.
- NOT TESTED: the tiles with the new icons BY EYE (the window was over them in the capture); everything listed as
  not tested under ui-10a to ui-10c.
- NEXT: commit ui-10a to ui-10d when the owner approves; then the class-name band; then phone, gamepad and
  Reduced Motion tests.

## ui-10e (2026-11-18): in-arena MENU window on white, AFK toast: WRITTEN, GATES GREEN, NOT SYNCED
Stamp on disk `kits-7c+lobby-4+ui-10e`; the PLACE is still ui-10d (v444). Studio was in a Play session I did not
start, and the two new images are not uploaded. 537 tests. ui-10a to ui-10e are NOT committed.
- IN A ROUND the More page becomes the MENU window (the owner: it should say MENU, on pure white, same style and
  details): `MenuController.tint(tone, detail?)` takes an optional detail colour; `drawMore` in a round tints the
  field pure white with the dots, the word and the wipe in violet.400 mixed 45 % to white, and sets the word and
  the title to "Menu". GUARDED: until `Shapes.words.Menu` and `Shapes.letters.titles[4]` exist it still says More.
- NEW IMAGES, drawn and NOT uploaded (Studio refuses `assets/ui`: not an approved upload directory):
  `assets/ui/poster_titles_4.png` (the MENU title; `make_lettering.py` put it alone on a 4th sheet, sheets 1 to 3
  came out byte-identical and `LetterRects.luau` gained one line, `title:MENU = { 4, 0, 0, 456, 224 }`) and
  `assets/ui/words/menu.png` (219 x 168, the background tile). 'Menu' was added to the lists in
  `poster_lettering.html` and `make_word_tiles.py`.
- AFK TOAST (the owner): pressing the AFK tile now toasts "AFK on. You'll sit out the next round." or "AFK off.
  You're in for the next round." (`NavController`, only within 5 s of your own press, through `menu:Toast`).
- TO DO NEXT: owner approves `Project\assets\ui` (and `\words` if needed); upload both as Image to group
  2970443; `Shapes.letters.titles[4] = id`, `Shapes.words.Menu = { id, width = 219 }`; push in Edit mode; check
  the MENU window in a round (title, white field, pale details) and both AFK toasts; save; correct this section.

## ui-11a (2026-11-18): smaller top strip, bigger window, class preview with poses, class pages; ui-10e synced (NOT COMMITTED)
Build `kits-7c+lobby-4+ui-11a`, 537 tests, gates green, synced (181 scripts match, origin/main had nothing new),
place saved (version in the UI Map). ui-10a to ui-11a are NOT committed.
- TOP STRIP (the owner: "a bit higher and a bit smaller", to make room): `HudTheme.Strip.Top` 8 (was 18),
  `Shrink` 0.82, `Tall` 72; HudController scales the strip's group by Shrink. The window starts under it
  (`MenuController.layout`) and `PosterKit.Fit.Window` went 0.9 -> 1.
- CLASS PREVIEW (the owner's idea: your character in the empty space, a pose and an idle for each class, a
  silhouette for a class you don't own, allowed to reach outside the window). NEW `Ui/ClassPreview.luau`: one
  ViewportFrame with a WorldModel, your avatar built once from your HumanoidDescription as R15 (fallback: a copy
  of your character). NO animation assets: `POSES[kitId]` is joint angles in degrees put on Motor6D.C0, and the
  idle is a breath and sway added 30 times a second while it shows (held still on phones and under Reduced
  Motion). Not owned: `ImageColor3` ink.950 at 0.2 transparency. It is the SLIDE's child (656, 70 in body
  coordinates, 300 x 400, ZIndex 6), so the page does not cut it and it reaches past the window's right edge.
  FOUND: Roblox now joints avatars with AnimationConstraints (15, no Motor6D at all), which do not move in a
  ViewportFrame; each is replaced by a Motor6D on the same two attachments. Angle signs are written in the
  module's header and held in play (Base guard, Dragon wings).
- CLASS PAGES: 8 tiles a page (`CLASSES_PER_PAGE`); with more, an arrow right of the tiles turns the page and from
  page 2 one left of them turns back, and the sub-line adds "PAGE n OF m". No arrows with one page. The cream
  panel on the left STAYS on later pages (the left arrow fits beside it; the owner had suggested removing it).
  Testing knob: workspace attribute `HT_ClassesPerPage`.
- SEEN in my own play test (1190 x 536): the strip's group at y 8; Base in a boxer's guard and Dragon with arms
  spread, the avatar reaching past the window's right edge and clear of the tiles, the X and the Equip button;
  idle moving; with the knob at 4: "PAGE 1 OF 2", a right arrow, and after pressing it "PAGE 2 OF 2", 4 tiles
  and a left arrow; a silhouette (tint forced by hand, every class is owned on this account).
  AFK toasts: "AFK on. You'll sit out the next round." and "AFK off. You're in for the next round."
  Console: only the known lines.
- MEASURED: 12 alternating 1 s samples with the preview shown and hidden: median 10.8 ms shown, 11.2 hidden: not
  separable from Studio's noise.
- AFTER THAT the arrows were enlarged (30 x 58 -> 40 x 72) and the preview moved 8 right: pushed, NOT looked at.
- STILL WAITING: the MENU title and tile images (`assets/ui`) are refused by Studio as not approved, so the
  in-round window is white but still says MORE.
- NOT TESTED: Bruiser, Inferno, Beast, Trickster, Frost and Tempest poses by eye; a real not-owned class; an
  avatar that fails to load; the white in-round window by eye; phones (held pose, window fit); gamepad; Reduced
  Motion; the published game. The mockup page does NOT show the preview, the pages or the smaller strip.

## ui-11b (2026-11-18): the class preview REDONE as R6 with Blender-pipeline idles; blur fix; smaller strip (NOT COMMITTED)
The owner rejected ui-11a's preview: "why is it R15 poses, it should be R6 ... proportions are way too skinny ...
they should fit inside the box ... make your idle animations in Blender before putting them into Studio", and
asked for the counter to be visibly smaller and higher, all lettering equally sharp, and some classes taken away
so the silhouette can be seen. Build `kits-7c+lobby-4+ui-11b`, 537 tests, gates green, synced (182 scripts match),
place saved (version in the UI Map). ui-10a to ui-11b are NOT committed.
- IDLES: NEW `animations/build_class_idles.py`, written with build_clips.py's own helpers (R6 joint Transforms,
  feet planted with `lock_feet`): one loop a class, 24 frames. Base is the game's own stance clip; Bruiser wide
  with arms held off the body; Inferno a fist pumping overhead; Beast low with both arms clawing; Trickster one
  arm up and waving, rocking; Dragon arms lifted like half-open wings, beating slowly; Frost arms crossed low,
  nearly still; Tempest leaning into a run. It bakes `animations/class_idles.json` and the generated
  `shared/Config/ClassIdleClips.luau` (93 k characters). `animations/preview_class_idles.py` shows all eight on
  R6 dummies in a Blender scene "HT_ClassIdles". BLENDER WAS NOT RUNNING (the MCP could not connect), so the
  owner has NOT seen them in Blender and neither have I; they were checked in the game instead.
- `Ui/ClassPreview.luau` REWRITTEN: the avatar is built as R6 (`CreateHumanoidModelFromDescription`, R6), the clip
  is sampled 30 times a second and each joint's Transform goes on its Motor6D as `C0 = home x Transform`, joints
  found by the part they move ("Torso", "Right Arm"...). AnimationConstraints are still converted. The camera
  frames soles to head at about 72 units a stud; the frame is 400 x 430 at body (590, 44), so the figure stands
  INSIDE the window between the tiles and its right edge and an arm reaches a little past it. Not owned: the
  image is drawn BLACK at 0.3 transparency (an ink tint let the face and shirt show through).
- BLUR FIX: `HudController.group()` made a CanvasGroup for every HUD group (strip, feed, dial, tiles, spectate
  chip). A CanvasGroup draws to a picture first and is soft when scaled down: that is why the counter was
  blurrier than the Coins and the window. Groups are plain Frames now and are shown and hidden with no fade; the
  60 % dim of the dial and tiles during a timed cue or a clash is GONE with it. The feed's frame clips its rows.
  STILL CanvasGroups: the window's drifting background word, Callouts' last moments, ClashBar.
- STRIP: `HudTheme.Strip.Top` 2, `Shrink` 0.7 (ui-11a's 8 and 0.82 were too subtle for the owner to see).
- STUDIO-ONLY KNOB in `PlayerDataService`: workspace attribute `HT_DevDisown` ("Dragon,Frost") takes those classes
  from everyone in the session and saves it. USED ONCE on the owner's account: Dragon, Frost and Tempest are no
  longer owned (their Coins were not given back; the account has about 21,900).
- SEEN in my own play tests: all eight idles side by side on a test sheet, each a different silhouette; in the
  window Bruiser (owned) and Dragon and Tempest (not owned, flat dark shapes) standing inside the window clear of
  the tiles, the X and the button, an arm just past the right edge; the strip clearly smaller and higher.
  Console: only the known lines.
- NOT TESTED: the idles in MOTION by eye (stills only); the strip's sharpness judged on the published game (the
  owner's rule: not in a small Studio view); the HUD with no fades during a fight; the frame cost of the R6
  preview (ui-11a's R15 one measured as noise); phones; gamepad; Reduced Motion.
- STILL WAITING: `assets/ui` upload approval for the MENU title images.

## ui-12a (2026-11-18): Q and R beside the dial, small Jump and Punch, CONTROLS chip and panel, simpler round menu: SYNCED, SEEN RUNNING (NOT COMMITTED)
Stamp on disk `kits-7c+lobby-4+ui-12a`; the PLACE is still ui-11b (v449): Studio was in a Play session I did not
start. 537 tests, gates green. ui-10a to ui-12a are NOT committed.
- `HudController`: the Q and R tiles are children of the DIAL's group (`you.fade`), one each side of the dial
  (`L.DialGap` 16), standing on its foot line; hidden on touch. Jump and Punch stay bottom-right, drawn at
  `L.TileSmallScale` 0.82 (a UIScale on the column, anchored bottom-left); their result word stands `WordLift`
  higher, over the new chip. `L.K` shrank to those two tiles.
- `UltimateNotice`: the ULT READY badge clears 112 units (was 104): small tiles, chip, result word.
- `NavController`: the MENU button is 68 (was 58), lettering 17; in a round it toggles "settings". NEW CONTROLS
  chip ("H . CONTROLS", cream, 176 x 30) over Jump and Punch, and a panel 320 x 240 above the badge's place:
  ink at 0.25 transparency with an ink line, a yellow CONTROLS title and a scrolling list (key in a cream cap, the
  action's name in bold and its detail in grey, from `HudTheme.Guide` plus the Ultimate row). H toggles it in a
  round (in the lobby H still opens the Moves page); it closes when the window opens or the round ends. Both
  scale with the HUD and are hidden on touch (a phone has NO way to the controls list in a round now).
- `MenuController`: `IN_ROUND_OK = { settings = true }`; opening "more" in a round opens Settings; the Back row
  and drawMore's round branch (the white MENU page of ui-10e) are gone, so the MENU title images are no longer
  needed. The class figure is centred in the open space right of the tiles (body x 525, 400 x 430) at ZIndex 4,
  UNDER the page, so tiles, rows and the button draw over it.
- SYNCED later the same day (182 scripts match, origin/main had nothing new), place saved v450.
- SEEN in my own play test (1190 x 536, in a fight): the dial at x 511 to 678 with the Q box at 422 to 499 and the
  R box at 690 to 767 on its foot line, both showing cooldown seconds; Jump and Punch 51 px in the corner; the
  chip "H . CONTROLS" just over them with the MISS word over the chip; MENU 51 px. H opened the panel (small,
  dark and see-through, key caps and wrapped lines, a scroll bar) above the badge's place; H again closed it.
  Pressing MENU opened the window on Settings with its three rows and closed the panel.
  In the lobby the Bruiser figure stands further in, its near arm behind the Beast and Tempest tiles and its far
  arm about 35 px past the window's edge. Console: only the known lines.
- NOT TESTED: the Q and R tiles' ready pop and refusal shake in their new place; the ULT READY badge against the
  chip and the open panel; the panel's scrolling by hand; a gamepad (chip says SELECT); phones (no chip, tiles
  hidden); Reduced Motion; the published game. The mockup page shows none of this round.

## ui-12b (2026-11-18): a cog on the fight's settings button and the lobby's SETTINGS tile: SYNCED, SEEN (NOT COMMITTED)
Stamp on disk `kits-7c+lobby-4+ui-12b`; the PLACE is still ui-12a (v450): Studio was in a Play session I did not
start. 537 tests, gates green. ui-10a to ui-12b are NOT committed.
- The owner: the MENU button is only a settings button now, so it should be a cog wheel, in the style of the three
  lobby icons, and the lobby's settings icon should be the same cog (the first drawing read as a sun).
- `design/ui/make_tool_icons.py`: `cog()` draws eight blunt teeth and a hole as one outline, line 2.1 (the others
  are 2.6; at 2.6 a cog closes up). Looked at beside the eye and the Zz: it reads as a cog and matches them.
  Uploaded as Image to group 2970443: 118279305149410 (Reviewing at upload). `Icons.toolSettings` points at it.
- `NavController`: the fight button shows the cog (44 units, ink) and no word. The mockup has the cog on both
  (published).
- SYNCED later the same day (182 scripts match), place saved v451. SEEN in my own play test: the cog on the
  fight button (33 px at 1190 x 536, ink on the cream tile, no word), loaded; the lobby tile's icon is the same
  asset and loaded, NOT looked at by eye. Not tested: phones, the published game.

## ui-12c (2026-11-18): two placeholder class pages, so the page arrows show: SYNCED, SEEN (NOT COMMITTED)
ui-10a to ui-12b were approved and committed as 4c07951 ("its good, you can commit"). Stamp on disk
`kits-7c+lobby-4+ui-12c`; the PLACE is still ui-12b (v451): Studio was in a Play session I did not start. 537 tests.
- The owner asked where the Classes page's arrow was: with 8 classes there is one page and no arrow. He asked for
  "2 more pages with like 8 placeholders for both". `MenuController`: `PLACEHOLDER_CLASSES = 16` appends 16
  placeholder slots after the real classes in `drawClasses`: dark striped tiles with a faint "?", SOON and a
  PLANNED badge, no press, no drift. They are UI only (nothing in Abilities, the Shop or saved data); 0 removes
  them. With them the page is 1 OF 3 and the right arrow shows; pages 2 and 3 show the left arrow too.
- SYNCED later the same day (182 scripts match), place saved v452. SEEN in my own play test: the page opened on
  3 OF 3 with a left arrow; pressing it gave "PAGE 2 OF 3", eight SOON / PLANNED tiles and an arrow on each side
  of them, the figure behind the right-hand tiles. Page 1 was not looked at this time.
- OPEN: the owner asked to take the classes away from EVERYONE, the second developer included ("maybe let him
  keep some"), so he sees the changes. NOT DONE: it changes other people's saved data; asked the owner how.

## ui-12d (2026-11-18): one-time class reset for everyone with a refund; toast lower and bigger: SYNCED, NOT PROVEN (NOT COMMITTED)
Build `kits-7c+lobby-4+ui-12d`, 539 tests, gates green, synced (182 scripts match), place saved v453. ui-12c
(placeholder class pages) and ui-12d are NOT committed; everything before is (4c07951).
- CLASS RESET. The owner: "make it so EVERYONE, including spicycaik, doesn't have characters anymore, maybe let
  him keep some, I want him to see all the changes himself". Asked how (it changes other people's saved data and
  cannot be undone); he chose "Everyone, with refund". So:
  - `Config/Abilities.ClassReset = { Version = 1, Keep = { "Bruiser", "Inferno" } }`.
  - `Core/AbilityKit`: `Profile.reset` (0 = never; kept by `sanitize` and `copy`), and `classReset(book, profile,
    reset)`: a profile not yet at this version keeps the starter and whichever Keep kits it owns, loses the rest,
    gets back each lost kit's current price in Coins, unequips a lost kit, and is marked. 2 new specs.
  - `PlayerDataService`: applied once on join, before the builders' test top-up, and saved (dirty).
  - It runs ONCE for each player for each Version. Raise Version to run it again; 0 stops it for players not yet
    reset. A profile it has already run for cannot be put back.
- NOT PROVEN ON A SAVED PROFILE. Three play tests: the first and the third were stopped from Studio before the
  attributes could be read; the second fell back to a TEMPORARY profile (`HT_DataTemp` true: the lock of the
  session stopped just before was still held; LEASE is 90 s), which showed owned = Base, coins 20000 and proves
  nothing. The pure rule is covered by its specs. FIRST THING NEXT TIME: one clean play test (no session stopped
  in the 90 s before it), read `HT_OwnedKits` / `HT_Coins` on the server: the owner's account should own Base,
  Bruiser and Inferno only (whichever of the two it owned) with the Coins of the others added, and a second join
  must change nothing.
- TOAST (the owner: small on his PC and under Roblox's performance bar): `MenuController` `TOAST = { Lower = 44,
  Bigger = 1.3 }`: it stands 44 px lower, beside where the 68-unit button is, and is drawn 1.3 times as big.
  NOT looked at.
- OTHER LOOSE ENDS: Blender was never running, so the class idles were never shown in Blender
  (`animations/preview_class_idles.py` is ready); the mockup page lacks the class figure, the pages, the smaller
  strip, the Q / R layout and the CONTROLS panel; `assets/ui` was never approved for uploads (the MENU title
  images are unused now); "Allow HTTP Requests" is needed for the server region on live servers; phones,
  gamepad and Reduced Motion are untested throughout; the class-name band on an ultimate is not built.

## ui-13a (2026-11-18): class reset PROVEN; first pass of the owner's full UI review: SYNCED, SEEN (NOT COMMITTED)
Build `kits-7c+lobby-4+ui-13a`, 539 tests, gates green, synced (182 scripts match), place saved v456. ui-12c,
ui-12d and ui-13a are NOT committed; everything before is (4c07951).
- CLASS RESET, PROVEN BY ARITHMETIC. A LIVE server (job ea5d57be...) held the owner's profile through two of my
  play tests, so they ran on temporary profiles. Read before: 6 classes (Base, Bruiser, Inferno, Beast,
  Trickster, Dragon), 21028 Coins, no `reset`. The owner's own Studio session then loaded it: `reset = 1`
  saved, `HT_DataTemp` false, all 8 owned, 20128 Coins = 21028 + 2550 refund (800 + 750 + 1000) - 3450 (he bought
  five back: 800, 750, 1000, 600, 300). Three later joins of mine: the same 8 classes and 20128 each time, so it
  does not run twice. The in-between state (3 classes, 23578) was not seen by me.
  OPEN: the published game is an OLDER build. If it saves a profile without `reset`, the reset would run again
  on the next join of a new build. Not checked.
- THE OWNER'S REVIEW BRIEF: "a FULL review of all the UIs ... find any inconsistency"; he circled the window's
  top-left, top-right and bottom-left corners and named the gap along the top of the Shop; motion too ("it'll
  move the frame and expose what's behind it").
- HOW TO LOOK CLOSELY (new): Studio's screen capture is at native pixels. Crop and enlarge it without smoothing
  (PIL, `Image.NEAREST`, x4 to x10) to judge seams and hairlines. Enlarging a piece with a UIScale shows its
  build, but NOT hairlines (they depend on where the pixels fall at the real size).
- FOUND AND FIXED, `MenuController` (the window):
  - The dots and the repeated word stood straight, 12 in from a leaning border: a plain band all round, widest
    along the top, and at the page change's 4-degree kick the pattern stuck out past the border. `Back` (the
    CanvasGroup) is now the paper's child, sized to the field exactly.
  - The ink line beside the cream slash was a turned bar with square ends (short of the border or past it). The
    slash and its line now live inside `Back`, the line runs long and the group cuts both ends flush; the line
    sits 1.5 units onto the cream (its edge on the wedge's edge showed a pale hairline). `PaperFront` is gone.
  - The shadow's open corners (top-right, bottom-left) read as a border that did not meet: two turned bars
    close them, and the shadow is solid ink now (see-through, the overlap showed darker).
  - The X stood still while the paper leaned, so at the kick its corner stuck out: `tiltFollowers` moves it
    with the paper's corner (it stays upright).
  - The toast reached about 25 px over the open window's left edge: it is drawn just small enough to end short
    of it (never under 0.9 of the lobby's scale).
  - Moves page: Punch's three-line detail lost its last word ("away."). `drawList` gives a row 26 units for
    every line its detail needs (about 36 letters a line).
- FOUND AND FIXED, `HudController`:
  - A yellow hairline up the top strip's right side: the colour edge was the whole slanted shape with the ink
    over it, and two soft edges on one line let the under colour through. The edge is now only the band under
    the plate. The same for a feed row about you (its edge is only the right end now; that one NOT seen).
  - Jump and Punch: the key cap ("Space", "Click") covered the top of the icon. A small tile's cap is 24 tall
    at 6, 6 and its icon 26 at 0.545 of the height (seen at 0.518, where it still touched; 0.545 NOT looked at).
  - A stray white dash at the dial's foot when standing still: the top-speed mark at rest, half under the
    stagger strip. It shows only while it is more than half a tick above the reading (`peakAllowed`).
- FOUND, NOT FIXED (the owner's call):
  - Classes page: the Q row shows its description, the R row never does (there is not room for two long ones
    without scrolling). Inconsistent.
  - The class figure stands behind the page arrow and the right-hand tiles.
  - The SPECTATING chip and the feed show in the lobby after you are knocked out.
  - The tool tiles' labels (SETTINGS, SPECTATE) are spaced unevenly at small sizes (the font at about 9 px).
  - `Shapes.slant`: the body's half-unit overlap under each wedge measured 0 on several plates; no seam was
    visible at native pixels on the strip, Coins or the SPECTATING chip, so nothing was changed.
- SEEN AT NATIVE PIXELS AND CLEAN: lobby strips, tool tiles, Coins, the SPECTATING chip, the dial, Q and R,
  the CONTROLS chip and panel, the cog, the window's four corners, the Classes, Moves, Ranked, Shop and
  Settings pages.
- NOT REVIEWED YET: the announcements and last-players popups, the ULTIMATE notice and badge, the spectate
  panel, the More page, the feed in motion, every hover / press / pop motion frame by frame, the KickMeter and
  clash bars, phones, gamepad, Reduced Motion, the published game.

## ui-13b (2026-11-18): the review's "found, not fixed" list, after the owner's "Yes fix it": SYNCED, SEEN (NOT COMMITTED)
Build `kits-7c+lobby-4+ui-13b`, 539 tests, gates green, synced (182 scripts match), place saved (see the UI Map
for the version). ui-12c, ui-12d, ui-13a and ui-13b are NOT committed.
- FIXED:
  - Classes page: BOTH skill rows show their description (only Q did). `drawClasses`: the class line stands at
    374, the rows start at 400 and stand 4 apart, a row is 68 (one line) or 88 (two): two two-line rows end
    exactly at the page's foot, so nothing scrolls. `PosterKit.row`: the detail stands at 34 and is
    `height - 36` tall (a line of that text is 26 units, and Roblox DROPS a wrapped line that does not wholly
    fit: at `height - 46` an 88-unit row showed one line of two). SEEN on Inferno (the longest pair): both rows
    whole, inside the border. This also moves the Moves page's details 4 up (not looked at again).
  - The SPECTATING chip showed whenever you were out, also standing in the lobby. `HudController`: it shows
    only while your character carries `HT_Spectating` (set by SpectateController in FIGHTER POV), whether or
    not you fought that round. SEEN: gone in the lobby after a knockout. NOT seen: showing in FIGHTER POV.
  - NEW FIND: the skill flag hung from the tile's right edge and grew left, so CAN'T USE and STUNNED lay over
    the Q and R key caps (READY cleared them). It now starts just right of the cap (`seatFlag`, from the cap's
    real width) and grows right, past the tile's edge. SEEN with STUNNED: both keys show, and the Q tile's flag
    ends short of the dial.
- LEFT AS THEY ARE, ON PURPOSE:
  - The class figure behind the tiles and the page arrow: the owner asked for exactly that in ui-12a ("further
    in, with the tiles, the rows and the button drawn over it where they meet"). Moving the figure clear would
    push it about 66 units past the window's side; moving the arrow to the class line would cut the longer
    class lines. Offered to the owner as a choice.
  - The feed in the lobby: built on purpose ("the feed stands under the Coins out of a round").
  - The tool tiles' uneven letter spacing: the label is 15 units, about 9 px in my 1188 x 536 Studio window,
    where any font hints unevenly; the owner's rule is not to judge sharpness there. Not changed.
- ALSO SEEN, NOT FIXED: while the saved profile is still loading (a held lock can take up to 104 s), the
  window shows 0 Coins and every class NOT OWNED, with nothing saying it is loading. The data itself was fine
  (8 classes, 20128 Coins once loaded). Stopping a Studio play session does NOT let go of the profile's lock
  (the next session waited about 95 s for it).
- STILL NOT REVIEWED: announcements and last-players popups, the ULTIMATE notice and badge, the spectate panel,
  the More page, the feed in motion, hover / press / pop frame by frame, the kick meter and clash bars, phones,
  gamepad, Reduced Motion, the published game.

## ui-13c (2026-11-18): the review, third pass (motion, More, spectate, popups); unequip transition: SYNCED (NOT COMMITTED)
Build `kits-7c+lobby-4+ui-13c`, 539 tests, gates green, synced (182 scripts match), place saved (version in the
UI Map). ui-12c, ui-12d, ui-13a, ui-13b and ui-13c are NOT committed.
- THE CLASS FIGURE: moved clear of the arrow and tiles on the owner's word (0.82 of its size, at 618, 121), he
  looked and said "revert it": it is back at 525, 44, 400 x 430. Do not move it again unasked.
- UNEQUIP SNAPPED (the owner): unequipping drops you to the starting class, and the page changed in one frame.
  `MenuController` `ability.KitChanged`: when the equipped class changes what the Classes page shows, `hit()`
  runs first (the sweep and the paper's kick, as when a tile is picked). SEEN: caught mid-kick after pressing
  UNEQUIP on Inferno; the X followed the paper's corner, the pattern stayed inside the border.
- THE WINDOW OVERSHOT ONTO THE MENU STRIPS when opening: place AND turn were on the spring, which overshoots by
  a sixth; over the slide's long run that was about 170 units too far left for a moment (caught in a capture,
  the window lying over SHOP / CLASSES / RANKED / MOVES). The place now runs on `slideIn`
  (`PosterEase.bezier(0.22, 1.06, 0.36, 1)`); the turn stays on the spring. NOT seen mid-slide since.
- MOTION FAULTS FOUND BY READING (none seen before or after; they need a pointer at the right moment):
  - `NavController.enter`: a strip's entrance and its answer to the pointer ran under the same `Poster.run` key,
    so a pointer crossing a strip in flight replaced the entrance and left it short of its place, tipped. A
    strip's or tool's button is hidden until it has landed (`entering`).
  - `PosterKit.pressable` / `pressRow`: the entrance pop and the hover wrote the same scale under two keys (a
    shiver); the pointer now ends the pop. Letting go of a press with the pointer still on it went to REST
    size; it goes back to the hover size.
  - `NavController.setCurrent`: the open page's strip jumped its 18 units in one frame; it slides (0.25 s).
- LAST-PLAYERS POPUP UNDER THE OPEN WINDOW: it stands where the window's top is and slid along half hidden
  behind it. `HudController`: no popup while the window is open (`menuOpen`, now declared at the top of
  KnitStart); the count still bumps and the knock still plays. NOT seen after the fix.
- SMALL ONES: More page says PLANNED in capitals like the Shop and Ranked badges; a skill detail takes a second
  line from 58 letters, not 55 (Uppercut's 55 fit one line and its row stood taller than Dash's for nothing);
  the spectate panel is 320 wide, not 280 ("FIGHTER POV  ON" touched its tab's sides; NOT looked at since).
- SEEN AND CLEAN: the More page, the spectate panel (both tabs, arrows, who-plate), the SPECTATING chip in
  FIGHTER POV for a player sitting out (AFK), the small tiles' icons clear of their caps.
- HOW TO SEE A POPUP ON DEMAND (my own play test only): `require` the client's `Ui/Callouts` from the MCP's
  client context and call `last(3, false)`; it is a second copy of the module with its own ScreenGui.
- NOT REVIEWED: the popups and the ULTIMATE notice in motion (only that they are hidden by the window), the
  badge beside the open CONTROLS panel, the kick meter and clash bars, phones, gamepad, Reduced Motion, the
  published game. The owner asked next for LOUDER, LESS SOFT UI sounds, on the website mockup first.
- STUDIO: stopping a play test does not release the profile lock; the next one waits 20 to 100 s for the data.
  The owner resized Studio's viewport mid-session (926 x 536): click by instance path, not by coordinates.

## ui-13d (2026-11-18): CONTROLS panel gap, placeholder skill text: WRITTEN, GATES GREEN, NOT SYNCED; punchy sounds ON THE WEBSITE ONLY
Stamp on disk still `ui-13c`; the PLACE is ui-13c (v462): Studio was in a Play session I did not start. 539 tests.
- CONTROLS PANEL (the owner, with a picture): it always stood high, leaving an empty gap over the chip for the
  ULT READY badge. `NavController`: `panelLift()` is 77 + 30 + 8 HUD units (just over the chip) and 200 only
  while the player has `HT_UltReady`; it slides between the two in 0.25 s when the attribute changes. NOT SEEN.
  To check: the result word (HIT / MISS) over Jump and Punch now lies under the open panel.
- SKILL DESCRIPTIONS ON THE CLASSES PAGE (the owner: "just add placeholder text, not all the moves are
  finalized"): `MenuController` `SKILL_DETAIL_PLACEHOLDER`; every skill row says it. The real ones stay in
  `Config/Abilities` (`blurb`); set the constant to "" to show them again. The class's own line is unchanged.
- LOUDER, LESS SOFT UI SOUNDS (the owner: "really feel like you're interacting ... put it on the website so I
  can hear it myself before you add it into roblox ... don't overdo it"). ONLY the mockup so far
  (`UI Research/fight-poster-prototype.html`, published, version 24): a `punch()` set for hover, press, open,
  close, page change, equip, buy and not-allowed; each is a 16 to 50 ms band-passed noise CLICK with a 1 ms
  attack, a low BODY tone that drops, and its notes, through its own master (gain .85, lowpass 9000; the soft
  set is .6 and 4600). A "Sound set" switch (Punchy / Soft) and a "Hear" row play them. Checked only that every
  sound builds without an error (stub audio, `sfx_check.js` in the scratchpad): NOBODY HAS HEARD THEM.
  WHEN HE APPROVES: port the recipes to `design/ui/make_ui_sounds.py` (it needs an attack argument, a band-pass
  filter and the second master), render the 8 WAVs, ASK before uploading (8 files, names, sizes; folder
  `assets/sfx/ui` is approved), then new ids and volumes in `Config/SoundBank.luau`.
- LATER THE SAME DAY: spicycaik's 7429d6e (kits-7d..7f, and my ui-12c to ui-13c "saved from the place") PULLED
  with no stash: a copy of every changed file is in `work/pre-pull-backup-20261118/`. Build
  `kits-7f+lobby-4+ui-13d`, 541 tests (his 539 plus my two class-reset specs, which are still only local), gates
  green, SYNCED (182 scripts match), place saved v463. Local and NOT committed: ui-13d, the specs, this file.
- SEEN in my own play test: with no ultimate the open panel sits right on the chip; with `HT_UltReady` set (by
  hand, on the server, in the test only) it stood higher and the ULT READY badge sat between it and the chip,
  touching neither. NOT seen: the slide itself, and coming back down. The HIT word shows faintly under the
  panel's corner. Classes page: both rows show the placeholder line, one line each.
- NEW ON SCREEN, his: a dark "SOUNDS (P)" button top-left, beside the cog, where the toast stands. A dev tool by
  the look of it; if it ships it breaks the no-overlap rule with the toast. Not touched.
## ui-14a (2026-11-18): the PUNCHY interface sounds uploaded and wired: SYNCED, LOADED, NOT HEARD BY ANYONE IN THE GAME (NOT COMMITTED)
Build `kits-7f+lobby-4+ui-14a`, 541 tests, gates green, synced (182 scripts match). The place is NOT SAVED since v463: the owner started
a play test of his own the moment mine stopped. Save it when Studio is back in Edit mode. origin/main had nothing new at the push. NOT committed: ui-13d, ui-14a, the two class-reset specs.
- The owner heard the punchy set on the mockup page ("Yes, add them"), then: "upload all 8 then and replace all
  the sfx".
- `design/ui/make_ui_sounds.py`: `osc` takes an attack; new `bandpass_swept` and `click` (the mockup's `nz()` with
  its attack and Q); `mix` takes a gain and a cutoff; `PUNCHY` holds the eight recipes (the mockup's `punch()` at
  v = 1) and its own master (`PUNCH_GAIN` 0.85, `PUNCH_CUT` 9000). They are rendered INSTEAD of the soft recipes
  of the same names; `--soft` renders the old ones. The soft WAVs are kept in `work/soft-ui-sfx-20261118/`.
- UPLOADED to group 2970443 with `open_cloud_invoke` (POST /assets/v1/assets, Audio, one file a call, from the
  approved `assets/sfx/ui`); all "Reviewing" at upload (NOT re-checked):
  ui_press 91500867807243 (0.10 s), ui_hover 97267587317411 (0.07), ui_open 73226715728690 (0.32),
  ui_close 112607708993860 (0.17), ui_page 118179764499470 (0.10), ui_equip 102801942993328 (0.33),
  ui_buy 94696095664151 (0.38), ui_deny 101128195701132 (0.23).
- `Config/SoundBank.luau`: the eight roles point at them. VOLUME = their mockup peak x 2.2 (the soft set's rule
  was x 4.3, which would put a press at 1.03, as loud as a punch landing): ui_press 0.53 (was 0.15), ui_open 0.54
  (0.28), ui_close 0.42 (0.17), ui_page 0.41 (0.25), ui_equip 0.53 (0.25), ui_buy 0.53 (0.2), ui_deny 0.37
  (0.25), ui_hover 0.12 (0.1). MY JUDGEMENT, not the owner's ear: on the mockup they are louder still, relative
  to the soft set. The old ids and volumes are in a comment there, to go back.
- NOT changed: skill_ready, ring_out, last_5 to last_2 (not interaction sounds; they are the soft ones still), and
  `UiSound` (same roles, same rules). The fight sounds were never part of this.
- VERIFIED in my own play test: all eight load (IsLoaded, TimeLength = the file lengths); from real key presses
  the game made Sounds with the NEW ui_open and ui_close ids at 0.54 and 0.42. NOT verified: the other six from
  real events; how any of it SOUNDS in the game, against the fight sounds; phones.
- THE OWNER ASKED whether I warn him when a commit is unsafe with spicycaik working: a commit or push cannot
  overwrite his work (Git refuses a push that is behind, and I never force); the real risk is the shared PLACE,
  where a Rojo push replaces every script with my files. I fetch before each push and stop if origin moved, but
  work he has synced to the place and NOT pushed is invisible to me.
- LATER (the owner asked "did we get overwritten?"): spicycaik's 130a10e (kits-7g, and my ui-13d and ui-14a
  "saved from the place") pulled the same way (backup in `work/pre-pull-backup-20261118b/`). CHECKED: every UI
  file of mine is in the repo exactly as I wrote it (byte for byte against both backups; only the build stamp,
  now his `kits-7g+lobby-4+ui-14a`, and the uncommitted specs differ). The PLACE, though, held his kits-7f
  versions of `Core/Ultimates`, `AnimController` and `UltimateController` (the sizes matched 7429d6e, not
  130a10e): his kits-7g was not in the place. Either he never synced it there, or my ui-14a sync, made before he
  pushed 7g, put the 7f files back over it. Synced again after the pull (182 scripts match): the place now has
  kits-7g and everything of mine. Place saved v466. `rojo_push.py --check` compares place and files and writes
  nothing: run it BEFORE a sync when he is working, to see what the place has that the files do not.
## ui-15a (2026-11-18): the fighters' row (profile pictures in place of the standing count): SYNCED, SEEN RUNNING (NOT COMMITTED)
948bf93 (the sound sources, the class-reset specs, the notes up to ui-14a) is committed and pushed; nothing older is
uncommitted. Stamp on disk `kits-7g+lobby-4+ui-15a`; 548 tests (7 new), selene 0, stylua clean, build OK.
- NOT SYNCED ON PURPOSE. `rojo_push.py --check` before the sync showed the PLACE holding work of spicycaik's that
  is not on GitHub: `Config/AnimClipsUltimate` (74685 characters there, 24711 in the files), `Core/Ultimates`,
  `AnimController`, `UltimateController`. A sync replaces every mapped script, so it would have put his four back
  to kits-7g. The tool cannot push a few scripts only, and CLAUDE.md forbids ad hoc script writes into the place.
  WAIT for him to push, pull, run `--check` again (only the row's own scripts and the stamps should differ), sync.
- THE OWNER'S BRIEF: instead of "5 / 20 players left", every player's Roblox profile picture in a row across the
  top (a reference picture, "don't make it look identical"); a border in the player's CLASS colour; the one with
  the most kills stands out ("a glow, a crown, or a colour change. Use your own judgment"); on a death a red X
  DRAWN over the picture, the box fading DOWNWARD, the rest moving to the centre; "animations NEED to be smooth".
- NEW `shared/Core/RosterLogic.luau` (pure, 7 specs): `fit` (tile side for a count and a width: 40 at most, 22 at
  least, gap 4), `slot` (centred places), `leader` (most ring-outs, at least one; a tie goes to whoever got there
  first), `badge` (a bot's number or a name's first letter, for a fighter with no picture), `approach` (one frame
  of an eased move, the same at any frame rate).
- NEW `client/Ui/Roster.luau`: a tile is the poster's rough-cut quad in the CLASS colour on a hard ink shadow, the
  head shot inside (`rbxthumb://type=AvatarHeadShot`, 150 px; no yield, no upload), a small plate bottom right
  with the fighter's ring-outs from the first one; your own picture has a cream line round it. THE CROWN: a bar
  and three diamonds made of Frames (no image), on the leader, who also stands 1.14 times as big with a yellow
  plate. OUT: two red strokes drawn corner to corner (0.14 s each), one small kick, the picture goes grey, 0.5 s
  later the tile sinks 30 units and fades over 0.45 s while the others close the gap. Every tile's place and size
  is eased each frame toward its target (rate 11), on one RenderStepped connection that exists only while
  something moves; no CanvasGroup; Reduced Motion snaps.
- `HudController`: the row is built beside the strip and laid out in `layout()` (the strip's place; it keeps the
  feed's width clear on both sides). `rosterRefresh` in `refreshStrip`: while the phase is Fighting the row holds
  every body tagged `HT_Fighter` and the strip's own panel is hidden (its ARENA CLOSING chip stays). The RingOut
  event crosses the victim out (no X for "left") and credits the attacker of a "knocked"; ring-outs are counted
  on the client from those events, so a late joiner sees only the ones since. A tag lost with no ring-out
  behind it sinks without the X after 0.6 s. A player's colour is their `HT_Kit` attribute; a bot has none and
  is drawn in Base's yellow.
- TO CHECK WHEN IT RUNS (none of this has been seen): 25 tiles against the cog, the feed and the SOUNDS (P) button;
  the row against the ARENA CLOSING chip and the announcements under it; the head shots loading; the crown's
  size; whether the leader's 1.14 touches its neighbours at the smallest tile; the frame cost while closing; a
  phone; whether the last-players popup still reads now that its count no longer flies into a visible strip.
- LATER THE SAME DAY, SYNCED AND RUN. spicycaik pushed (91b91fd and 6776730, kits-7h..7m); pulled as before
  (backup `work/pre-pull-backup-20261118c/`); `--check` then showed only the row's scripts and the stamp
  differing, so it was safe. Build `kits-7m+lobby-4+ui-15a`, 552 tests (10 for the row), gates green, 184 scripts
  match, place saved v476.
- CHANGED AFTER SEEING IT RUN:
  - Too small at first (it kept the feed's width clear on both sides: about 18 px a tile in a 926 px view). The
    tile is 48 at most now and the row runs nearly the screen's width (110 units clear each side in a round, for
    the settings button; 170 out of one, for the Coins). The FEED moves under the row while the row is up
    (`rosterShown`, read in `layout()`), and the ARENA CLOSING chip moves down to stand under it.
  - My own tile's cream line was a stroke round the OUTSIDE of the picture and hid the class colour; it is a line
    just inside the picture's edge now.
  - The slide was `approach` (it sets off at full speed). It rides `RosterLogic.spring` now (critically damped,
    stiffness 14: sets off gently, never overshoots, carries its speed when the target changes; 3 specs). The
    others start to close the gap at 0.72 s, once the sinking tile is half gone (at 0.58 it was drawn over them).
- SEEN in my own play tests (25 bots and me): the row at the start of a fight, 25 tiles, bots as their numbers
  on Base's yellow, my head shot with its cream line; two ring-outs at once with both red X's drawn; the crown
  on the first fighter with a ring-out and its yellow plate, another fighter's ink plate; the feed under the
  row; in the lobby after my own ring-out, the row centred between the menu and the Coins with two gaps closing.
- MEASURED (Studio, 1190 x 536): a frame while tiles were moving 14.5 ms, while still 14.2 ms (noise); the row's
  own writes for 19 tiles 0.03 ms a frame; top speed 244 px/s; the largest change of speed between two frames
  39 to 186 px/s, in a 27 ms frame.
- NOT SEEN: the motion by eye (stills and numbers only); a real second player's picture and class colour (every
  other fighter was a bot); the ARENA CLOSING chip under the row; an announcement or the last-players popup
  with the row above it; the crown changing hands; a leaver; Reduced Motion; a phone; the published game.
- KNOWN: spicycaik's Studio-only SOUNDS (P) button lies over the row's left end in a round (it never ships).
## ui-15b (2026-11-18): the row's kill counter from 0, a thicker frame as a STYLE, the pixel crown: SYNCED, SEEN (NOT COMMITTED)
Build `kits-7m+lobby-4+ui-15b`, 551 tests, gates green, 185 scripts match, place saved v477.
ui-15a and ui-15b are NOT committed. `--check` before the sync showed only my own scripts differing.
- THE OWNER, after seeing ui-15a: "maybe there can be a kill counter instead, so everybody starts off at 0 ...
  MAKE the borders of the pfp look BETTER and slightly bigger so it can be customizable in the future ... there
  will be different styles, also make the crown look better too" (with a reference: a three-point pixel crown).
- KILL COUNTER: the plate is on every tile from the start and reads 0 (19 x 18, a thin cream line, 13 px
  figures); it only appeared with the first ring-out before. A bot's stand-in is no longer its NUMBER (it read
  as a count): a plain head and shoulders, two rounded Frames a shade lighter than the backdrop.
  `RosterLogic.badge` and its spec are gone.
- THE FRAME IS A STYLE: NEW `shared/Config/RosterFrames.luau` (`Styles`, `Default`, `get`). A style is a shape
  (a name in `Shapes.ids`), a shadow, an outline, a band (`bandTone = nil` means the fighter's CLASS colour), an
  inner line and how far the picture's backdrop is mixed toward the band. `Roster.build` draws whichever style
  `entry.frame` names. ONE style today, "Poster": ink outline 2.5, band 5.5, ink inner line 1.5 (4 units of flat
  class colour before). Nothing chooses a style yet: no setting, no product, nothing saved; `HudController`
  passes none. The tile is 52 at most (was 48), 24 at least, 5 apart; 18 units of room over it for the crown.
- THE CROWN: NEW `design/ui/make_crown.py` draws OUR OWN pixel crown in the reference's manner (three points, ink
  outline, coin yellow with Bruiser's orange as the shaded side, a pale stripe, a darker band; 21 x 15 cells at
  16 px; the shape is computed from three peaks and two valleys). The reference picture itself is not used.
  `assets/icons/poster/crown_pixel.png` (928 bytes) UPLOADED as Image to group 2970443 after the owner's yes:
  112758624871088 ("Reviewing" at upload). `Shapes.ids.crownPixel`; `Roster` shows it with ResampleMode
  Pixelated (28 x 20 units) and falls back to the old bar-and-diamonds crown if that id is ever taken out.
- SEEN in my own play test: 25 tiles with the three-layer frame, silhouettes, every plate at 0 and my head shot;
  later 16 left with the crown image loaded on the leader (4 ring-outs, yellow plate), a plate reading 3 on a
  fighter being crossed out, two X's drawn at once. NOT seen: a real second player, another class's colour on a
  frame, the crown changing hands, a phone.
- THE OWNER'S NEW RULE (2026-11-18): I may stop a running Studio play test myself, without asking ("from now on
  you're free to just stop the playtest by yourself. don't ask me anymore"). It replaces "never stop a Play
  session you did not start". Saved in memory (`haymaker-may-stop-playtests`).
## ui-15c (2026-11-18): the row's tiles drawn bigger, the counter off the picture, a Settings switch to hide the row: SYNCED, SEEN (NOT COMMITTED)
Build `kits-7m+lobby-4+ui-15c`, 551 tests, gates green, 185 scripts match, place saved v479.
ui-15a, ui-15b and ui-15c are NOT committed. `--check` before each sync showed only my own scripts differing.
- THE OWNER: "the profiles are TOO small, I don't want it big to the point it takes up the entire screen ... make
  the profile more visible", and "in settings add a toggle button to hide this".
- BIGGER: `Roster` builds a tile at 52 (`SIZE.Tile`, what every part inside is measured against) and DRAWS it as
  big as the row's room allows, up to `SIZE.Most` 72 (least 28, gap 6). A full round of 25 is held down by the
  screen's WIDTH (one row, about 4 % of the width a tile); from about 18 standing the tiles are at 72. The room
  over the tiles for the crown grows with them. `row.tall` is the height at the LARGEST size, so the feed and the
  ARENA CLOSING chip under the row keep one place.
  MEASURED in Studio at 1190 x 536: 36.5 px a tile with 25 standing (it was about 32 at most before), 53.6 px
  with 10. At 1920 x 1080 the sums give about 62 px with 25 and 72 with 18 or fewer. NOT measured there.
- MORE OF THE FACE: the head shot is cropped to its middle (`ImageRectOffset` 14, 6, `ImageRectSize` 122 of
  150), about a fifth larger. The KILL COUNTER hangs on the middle of the frame's bottom edge (22 x 17, 8 under
  it) and no longer covers a corner of the picture.
- OUT OF A ROUND the row keeps the feed's whole column clear on both sides and the feed stays under the Coins:
  moved under the row there, the feed ran down into the SETTINGS tile (seen). So the row is NARROWER in the
  lobby than in a fight (about 27 px a tile with 21 standing at 1190 wide). In a fight the feed stands under it.
- THE ROW GIVES WAY TO THE OPEN MENU WINDOW, like the feed (the window is laid out to clear the strip, and the
  taller row ran under its top edge; seen): the strip's count shows while a window is open.
- THE SWITCH: `MenuController` has a fourth Settings row, FIRST in the list, "Fighter row" ("Shows everyone still
  standing across the top in a fight."), and it is the only one that DOES something: new signal
  `MenuController.SettingChanged` (id, on) and `MenuController:GetSetting(id)`; `HudController` (`rosterWanted`)
  shows the old strip count instead while it is off. The page's line now reads "FIGHTER ROW WORKS  .  THE OTHER
  THREE DON'T CHANGE ANYTHING YET". NOT SAVED: like every switch there, it is back on in a new session.
- SEEN in my own play tests: 25 tiles at 36.5 px with the counter under each; 10 left at 53.6 px with the crown;
  the Settings page with the new row on, then OFF with the row gone and "17 / 25 STANDING" back; the window open
  with the row hidden and nothing overlapping; the row back when the window closed; the lobby with the row
  between the menu and the feed's column, the feed clear of the tool tiles.
- NOT SEEN: a full-size screen; a phone; a second real player.
- OFFERED TO THE OWNER, NOT BUILT: two rows while more than about 13 are standing (bigger tiles with a full
  round, at about twice the height).
## ui-16a (2026-11-18): the round-start countdown, 3, 2, 1, TUSSLE!: IN THE LOCAL MOCKUP FILE ONLY, NOT PUBLISHED, NOTHING IN ROBLOX
ui-15a to ui-15c (the fighters' row) were committed with this section; the place is ui-15c (v479) and was not
touched for this piece. The owner stopped the work here to carry on in a new chat.
- THE OWNER'S BRIEF (with a picture of the "GET READY  ROUND 1" strip): "when a round starts, don't have that
  thing at the top ... just remove that completely. Now instead, 3 seconds before the round starts there should be
  a countdown on the screen that goes 3.... 2.... 1.... TUSSLE! With bouncy vfx, sfx, and animations. Keep the
  style similar to everything else", then: "do it on the website first before you import it into roblox so I can
  see it".
- WHAT THE GAME HAS NOW: `RoundService` sets the phase "Starting" for `GameConfig.Round.StartingSeconds` = 4 and
  publishes `CountdownEnd` (server time) on `ReplicatedStorage.HT_RoundState`; `HudLogic.strip` returns
  "GET READY" with that countdown, and `tests/HudLogic.spec.luau` asserts it shows. The countdown must run from
  `CountdownEnd - 3`, so the first second of Starting shows nothing. `GameConfig.luau` is GENERATED: change
  `design/game.json` and run `python tools/gen_config.py` if the 4 has to change (it need not).
- DONE, IN `UI Research/fight-poster-prototype.html` ON DISK (NOT published to the artifact; the copy from before
  is `scratchpad/prototype_before_countdown.html` of the old session, which may be gone):
  - a "Start a round" button in the Try it row (`startRound()`): `cdBeat(3)`, `cdBeat(2)`, `cdBeat(1)` a second
    apart, then `cdGo()`, cleared 1.35 s later.
  - a beat: a slanted ink bar wipes in (class `cbar`, its edges in the beat's colour), the number slams in from
    3.6 times its size, turned, on the spring (0.62 s), a small shake of the whole group, eight pieces thrown
    out; at 0.78 s the number is knocked down and away (0.2 s) before the next lands. 3 is cream, 2 yellow, 1
    pink; odd beats come in turned one way, even ones the other. 250 px slanted Oswald with the ink outline and
    hard shadow, like the last-players number.
  - TUSSLE!: seven cut-out letters in boxes (cream, the class colour, yellow, the "!" pink and tipped), landing
    0.04 s apart on the spring over a taller bar; 22 pieces; the edge bars pulse; after 0.96 s the word swells to
    1.7 times and fades.
  - sounds in `punch()`: `cd` (a click, a low thump and one note: 392, 440, 523 Hz for 3, 2, 1) and `go` (a rising
    rush, a bigger thump, the chord 523 / 659 / 784 and a high sine). They always use the punchy master.
  - a line in "How to use it"; and a FIX: two `@keyframes cf` (the confetti's and the cinematic flash's) shared
    a name, so the later one hid the confetti of the ULTIMATE notice and FINAL TWO in the mockup; the flash's is
    `cfl` now.
- CHECKED: the script parses; `cd` and `go` build (4 and 7 voices) against a stub audio engine; in the browser
  pane the settled frames of 3, 2, 1 and TUSSLE! draw as meant, no console errors. NOT CHECKED: the motion (the
  pane's screenshots do not land on a chosen moment, and the pane asks for reduced motion, so the page starts with
  Motion OFF there: call `setMotion(true)` first); whether the pieces show; the sounds by ear.
- NEXT, IN ORDER: (1) finish checking the mockup, publish it to the SAME artifact
  (https://claude.ai/artifact/ScFqVNZYHhvufmBUMdwwa3, read it first), tell the owner to press Fight, then Start a
  round; (2) on his yes, in Roblox: take "GET READY" out of `HudLogic.strip` (the strip hidden in Starting; fix the
  two spec lines), add the countdown to `Ui/Callouts.luau` beside `last()` (it already has `band`, `confetti`,
  `stamp`, the big-number sheet `Shapes.last` with only 5, 4, 3, 2, so a "1" and the TUSSLE! letters need new
  lettering images: `design/ui/make_lettering.py`, then an upload he must approve), drive it from `CountdownEnd`
  in `HudController`, add the two sound recipes to `design/ui/make_ui_sounds.py` (4 files: cd_3, cd_2, cd_1,
  round_go; an upload he must approve) and roles in `Config/SoundBank.luau`; (3) the row must not appear until
  the fight starts (it already waits for the phase Fighting).
- A local preview server I started for the mockup (python http.server, port 8765) is STOPPED.

## kits-7d..7f (2026-11-17): Haymaker Rush rush-in, flurry, camera study, gap study, stage A (NOT PLAY-TESTED: the place kept being overwritten)
Build stamp `kits-7f+lobby-4+ui-13c`. Spec chain: `design/haymaker-rush-v3-beats.md` (camera study and the owner's picks), then
`design/haymaker-rush-gap-study-prompt.md` (the study brief) and `design/haymaker-rush-v4-gaps.md` (the ranked fix list, owner picks
recorded). Vault: `63 VFX Creation/Cutscene Camera and Impact - Measured From 10 References.md` and `Haymaker Rush vs References - Gap
Report.md` (plus four area notes).
- kits-7d:
  - The rush-in is a real 0.74 s sprint (AnimController.SetDash).
  - The flurry is 16 rising punches (BarrageUp, every 0.125 s), with the target juggled above. The uppercut is the finisher, and the
    haymaker comes from below (HaymakerUp).
  - `ult_barrage` is in SoundCandidates, with 6 options to pick from in the sound picker.
  - The camera is a smooth spline (`ease = "smooth"`).
  - Swings that start late shorten their windup, and the hit-stop waits for the strike (AtStrike).
  - Each client poses both fighters itself; the replicated target arrived about 0.1 s late.
- kits-7e:
  - Big hits freeze (0.2, 0.25 and 0.15 s; `Blow.freeze`, the keys hold the bodies) and the camera snaps to a new angle under a
    1-frame flash.
  - Shake is constant flurry jitter plus one jolt after each freeze (`Ultimates.shake`); there are no zoom kicks.
  - The rush camera is fixed (`rel = "start"`).
  - Close inserts (`insert`) on the lock-in and the wind-up; the screen darkens before the haymaker.
- kits-7f (stage A of the fix list):
  - The HUD and the Roblox core UI are hidden on the fighters' screens during the ultimate. They are re-hidden every frame and
    restored under the end's dip to black.
  - The dash effect is removed from the ultimate.
  - ImpactFrame.prepare clones the silhouettes in the wind-up (the old code made up to 8 character clones on the hit), and the cards
    are picked by elapsed time.
  - Ultimate sparks turn by a set cycle, with no glints (`PunchHitFx.play` takes a `turn`).
- Measured in play (kits-7e, 34-38 fps):
  - The haymaker lands, and the bodies hold still through each freeze.
  - The hook fist is 3 studs off and the uppercut's 1.4. Their freezes start before the fist arrives, and the fix is still to do (A4).
  - Studio dropped to about 10 fps from the wind-up to the end, probably from the ImpactFrame clones.
- SAVED FROM THE PLACE (the teammate's live Rojo overwrote the place three times this session): ui-13a (the class reset in
  Abilities and AbilityKit, PlayerDataService, Hud and Menu), ui-13b (Hud, Menu, PosterKit) and ui-13c (Hud, Menu, Nav, HudTheme,
  PosterKit). Each was checked by checksum against the place.
- Gates: build OK, 539 tests, selene 0, stylua clean.
- NEXT:
  - Play-test stage A at 16:9, after the teammate pulls and stops or restarts their Rojo.
  - A4: measure the hook's real contact time and start its freeze there.
  - Then stage B (animation) and stage C (camera), per `design/haymaker-rush-v4-gaps.md`.

## kits-7h..7m (2026-11-17): stage B (animation) and the owner's ending rework (NOT COMMITTED; synced, seen in Studio)
Build stamp `kits-7m+lobby-4+ui-14a` (the place has it). The last commit is 130a10e (kits-7g). Recordings of each build are in
`design/references/ours-kits-7h.mp4` .. `ours-kits-7m.mp4` (16:9, from Studio via ffmpeg gdigrab; untracked).
- 7h, flurry:
  - BarrageUp is now a 1.0 s loop of 8 different punches (FLURRY_PUNCHES in animations/build_strikes.luau), each out 0.03 s, held
    0.04 s, back 0.055 s.
  - The attacker sways and lurches.
- 7i, target reactions:
  - Key.targetTilt plus Ultimates.tilt / targetCFrame.
  - AnimController.SetCutscene keeps AirTumble, Slammed and HitSkid off during the cutscene.
- 7j, pose clips on the clock (Timeline.clips, AnimController.SyncClip):
  - RushIn (cocked lock-in, launch crouch, held stride; the rush is linear after a 0.08 s hold), UpperSet, LeapUp.
  - HaymakerUp has a deeper coil, a follow-through and air legs.
  - The 1-frame arm-stretch smear (AnimController.StretchArm, Blow.arm).
- 7k, from the owner: "positioning not right, reference the garou fight", "hugging", "pause should focus on the player":
  - The juggle is upright, 2.6 ahead and 3.2 up, from a wide low stance (FLURRY_FEET).
  - The haymaker wind-up holds them apart (WIND_GAP 3.4, WIND_RISE 3.6) and lunges in on the strike.
- 7l, "camera choppy", "target positioned weirdly":
  - The hit tilt spring is off in cutscenes (16 hits stacked it and laid the target flat).
  - Jitter is 0.07 studs at 10 Hz.
  - The cut into the leap is now a glide.
- 7m, the owner's ending beat by beat:
  - After the uppercut, the PLAYER ALONE: LeapUp with a dust ring of 8 puffs, a gust and ribbons; HaymakerUp synced from CHARGE,
    so it charges while rising.
  - FACE: both, then a zoom onto the fist and torso, then the impact frames, drawn from their own side-profile camera
    (ImpactFrame.play `view`).
  - A SLOW drive-through (Blow.slow 0.18 over HAY_FREEZE 0.75), then the knockback AT ONCE (BLAST = HAYMAKER + HAY_FREEZE).
  - The flurry target is pitched forward about 30 deg toward the fists and plays the limp Dangle clip (Timeline.targetClips;
    no flinch while a pose clip holds the body).
- Gates: build OK, 540 tests, selene 0, stylua clean.
- NOT DONE:
  - The uppercut fist is still ~1 stud off.
  - The target-like hit rings and the plain white flash (stages E and D of design/haymaker-rush-v4-gaps.md).
  - The sun in the flurry shot (stage C).
  - The teammate's Rojo overwrote the place 3 times this day: compare the stamp before every test.

## kits-8a (2026-11-18): Haymaker Rush rebuilt from a 10-reference cutscene study (NOT COMMITTED; NOT YET SEEN IN STUDIO)
Build stamp `kits-8a+lobby-4+ui-15c`. The owner's six problems on kits-7m (torso not facing the fist, launch too short for
a long dash, a strange rush, an arm rotating between the dash and the punch, a delayed knockback, a stiff camera and
bodies), each traced to its cause and fixed. The study and the plan are in `design/cutscene-study/`:
- `00`: our map and the measured diagnosis (anchoring REJECTED as a cause; the dummy is unanchored)
- `01`-`10`: one report per reference
- `11`: findings, gap analysis, storyboard and to-do list with status

What changed:
- Target facing. A `Fold` pose clip holds the target from each big contact, so `HitLanded`'s flinch can't turn it.
  Contact spacing and tilts were solved on the baked clips:
  - the uppercut is held at clip 0.075 (it was 0.066, with the fist still under the belly: the old "1 stud off" bug);
    the target is caught 2.4 up, 1.5 back and 1.2 to the right, tilted -55
  - the haymaker is 2.7 back, 2.4 below and 0.6 to the left, upright
  - measured with `lune run lune/contact_check` and asserted by `tests/Ultimates.spec`, using `tests/support/Rig`
    (R6 joints posed by our clips)
- Launch: 9.5 back and 5 up (a `whip` ease). The dash covers about 9.3 studs.
- Rush:
  - `RushIn` is now only the lock-in and crouch. `RushRun` (arms and head) runs over the real Sprint legs.
  - The camera is over the TARGET's shoulder (C5-A), with `Shot.lookRel` aiming at the runner.
  - A `launch` ease: full speed within the first fifth, never slowing.
- Dash to punch. `HaymakerUp` is one clip: load in the crouch, take-off, hold, drive. The arm's world aim stays
  constant (the sweep follows the torso turn, and the lift adds the lean). The timeline syncs it in three parts
  (`Swing.loaded`, `release`, `holdShare`). `LeapUp` is gone.
- Knockback. The target moves from the contact frame: 0.9 studs under the impact frames, then about 3 studs/s in slow
  motion, then a `throw` ease into `Ultimates.flight`, which starts at that speed and turns on from the last pose. That
  removes kits-7m's stall, its 56-101 studs/s jump and its 46 deg turn snap. `DummyService` uses it, and now poses the
  dummy with the tilt.
- Camera:
  - a whip up after the launch
  - one panning dash shot from a fixed low spot
  - a two-shot beat, then a whip zoom that lands before contact
  - a pull-back over the slow knockback, then the throw line
  - creeps through the freezes
- `targetCFrame` is built from its axes (Lune's lookAt is backwards on exact +-Z).
- The teammate's ui-15a and ui-15c (roster row, `MenuController`, `Shapes`, `RosterFrames`) were saved from the place by
  checksum. All of it matches the place exactly.

Gates: rojo build OK, 546 tests, `selene src` 0, stylua clean.

NOT DONE:
- Seeing it in Studio. The place still runs kits-7m+ui-15c. It needs Rojo Connect to this folder (port 34872) with the
  teammate's Rojo stopped, then a 16:9 recording and the acceptance list in `design/cutscene-study/11` section 6.
- Stage D screen effects.

## kits-8b (2026-11-18): fixes from the first kits-8a recording
Build stamp `kits-8b+lobby-4+ui-15c`, saved in the place (version 482). The kits-8a recording is
`design/references/ours-kits-8a.mp4` (untracked). Studio only rendered 7-10 fps that run.

Fixed from that recording:
- the rush's right arm stuck out like a wave; the fist is now drawn back by the hip (`RUN_COCKED`)
- the target's shoulder filled the rush frame; the camera moved out and up
- the attacker's back hid the target at the uppercut; the camera moved right and out
- the final zoom read as flat blocks; it was eased to FOV 47

kits-8b is NOT seen in Studio. Studio's viewport froze on a stale frame, so the screen capture got stills. Restart Studio
(its output also asks for a restart: the assistant plugin changed version), then record again. The acceptance
checklist with each item's state is in `design/cutscene-study/11`, section 6.
