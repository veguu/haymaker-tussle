# Test harness (not part of the game; rojo doesn't map this folder)

Scripts written while testing the air kick. Paths inside some of them may need adjusting.

**The test bot is back (build train-4).** `TestBot1` stands on the 1v1 arena only while one player is alone in the server, and it chases, punches and taps in clashes as before. The Studio-only hooks `HT_TestPunch`, `HT_TestClash` and `HT_TestBotQuiet` are back too, so the bot scripts below should work again. Train-3 had removed the bot and these hooks. Its brain (`Core/BotBrain`) was rebuilt from the settings, so check behaviour before trusting old readings. Training dummies never attack. None of the scripts below have been re-run since train-4.

- `run_training.py <state|enter|go|click|read|press>` and `training_suite.py [station letters]`: the training arena in real play with real keys and clicks. Moves your character. Some subcommands (`enter`, `press`) still assume prompts on pillars from before the floor pads; check before use.

- `airtest.luau` + `run_airtest.py <gap ms> <none|green|orange> <none|W|S|skip|lateD>`: punches until the bot floats, sends real keys, logs phases, text and kick.
- `miss.luau`: same launch, logs a jump's arc and landing; also useful just to land an uppercut. Sends no keys itself.
- `aimtest.luau`: turns the real camera at lock-on and checks the attacker swings opposite it; logs the rebound and running after it.
- `fxtest.luau` + `run_fxtest.py`: teleports you to the bot, lands uppercuts until a jump is ready, sends Space then W and Q. Logs the ground break's pieces over time and the rebound's speed against a real propel. It leaves frozen copies of the break in ReplicatedStorage (`HT_FreezeA`, `HT_FreezeB`), client-side only; they go when Play stops. A jump with no keys can miss, so expect to run it more than once.
- `rebtest.luau` + `run_rebtest.py <red|orange|green> [edge radius] [bot stagger]`: pins the bot at the platform edge in line with your facing, then logs where a rebound started, its rise, speed and landing. Its stagger argument did not make kicks land further out.
- `run_lockon.py <setup|spin|front|unfront|lock|rest|respawn>`: drives the lock-on marker with real test keys against client-only dummies, holding the camera each frame. `coasttest.luau`, `coast2.luau`, `turntest.luau`, `trace2.luau`: movement readings.
- `run_lockcam.py <prep|size|track|cross|sight|collide|hold|shift|die|done>`, `grace.luau`: the lock-on camera and marker. `done` must run afterward, or the bot stays anchored and you stay pinned.
- `run_shiftbug.py`: camera lock frame by frame, with and without shift lock. `run_lockjump.py <grade> [key]` with `jump_sampler.luau`: a real jump while locked, logging keys and state.
- `watch.luau`: read-only list of which clips are showing for 5 s.
- `lock2.luau`: read-only camera offset and dot readout in shift lock. `final.luau`: top speed for the stagger test.
- `blender_mcp.py code <file.py>`: runs code in Blender over stdio when the session's Blender connection has dropped. `show_anims.py` plays all clips. `sheet.py`, `blender_shot.py`, `shot2.py`: pose sheet and screenshots.
- `tx_snippet.js`: in the browser pane on a YouTube video, reads caption text with timestamps.

Things learned the hard way:
- `user_keyboard_input` bypasses Windows, so a simulated Alt never shows that a real one activates Studio's menu bar. Test Alt with real keys through computer-use.
- `screen_capture` leaves out BillboardGui entirely. To see one, screenshot the real window with computer-use. Don't call `open_application` on Roblox Studio: it starts a second copy.
- The Follow camera swings back to the character's facing, and execute_luau resets a Scriptable camera. To hold a view, set the camera every frame with BindToRenderStep.
- `studio_mcp.py` reaches Studio directly: `luau --dm Client --file x.luau`, `call user_keyboard_input '{...}'`, `call start_stop_play`.
- Luau in the Client context can't press keys or call `ContextActionService`, so keys go through `user_keyboard_input`. A mouse click needs a `moveTo` first.
- A Scriptable camera switches shift lock off. Turn the real camera by setting its `CFrame`.
- Wait for Edit mode before pushing, and check the push printed PASS. A refused push means the test runs the old build.
- The push deletes then recreates code, so never push after a patch fails partway.
- Run `gen_config.py` after editing `design/game.json`. `check.py` doesn't catch a stale config.
- Each jump has a 15 s cooldown, so a test that misses has to wait that long to retry.
- The bot punches you during tests, which moves your head. Measure from the root part.
- `run_hitgrid.py [label]`: real punches at a still copy of the bot, all around you, one grid per swing with the server's reason for each miss. Takes about 4 minutes.
- `run_clash.py [section]`: the real rules through timed exchanges (1), then alignment, win, loss, tie and tap flood (2), third-party repel, removal, falling, dying, height and walls. Section 1 measures who wins by strike gap. Your character gets pinned and killed once. Needs the bot's stored heading to be sensible, so restart Play if a previous run left it facing the wrong way.
- `run_recovery.py <fly|suite|more|done>`: real air flights with real keys and clicks, held at a set distance from the edge and launched with a real knockback message. `fly <gap> <height> <outward> <up> <float 0|1> [reaction ms] [click gap ms] [clicks] [W 0|1]`; `suite` and `more` run the checks in the `Air Recovery` note. `done` must run afterward. `lune run lune/recovery_sim compare ...` flies the same launch in the simulator. The mouse tool can't click faster than about one per 0.2 s, and key and click timing lag by about 0.2 to 0.4 s, so read the real times it prints. Restart Play after `more`, because the bot's left where it was held. `run_rebtest.py` sometimes says "no kick" when a jump misses, and needs a 15 s wait between runs.
- `run_realclick.py <setup [clash delay]|read|done>`: counts real punch requests and taps while Studio's mouse tool clicks. `done` must run afterward, or you stay pinned and the bot stays quiet.
