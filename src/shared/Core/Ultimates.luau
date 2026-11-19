--!strict
-- Ultimates - the ultimates' choreography, as plain maths shared by the server and every client
-- (2026-11-15). The user: a locked follow-up after a string's last punch (or an attack skill) knocks
-- someone away, that "pretty much guarantees hitting them off the map", super flashy, every kit its own.
--
-- ANCHOR. Everything happens in one frame, fixed when it starts: its origin is where the target was, and
-- its LookVector points OUTWARD from the arena's middle (the way they get thrown off), flat. Local -Z is
-- forward (outward), +Z behind them (where the attacker stands), +Y up.
--
-- A TIMELINE is keyframes over `Cinematic` seconds: where each fighter is (relative to the anchor; the
-- attacker's first key is "where they really were"), its camera SHOTS (cuts and moves), and named cues the effects listen
-- for. Bodies are SET to these poses every frame (by their own client, or DummyService for a bot), so
-- nothing can get in the way. At `Cinematic` the target's FLIGHT starts: a scripted path past the play
-- area's edge and below the elimination line (Round.isOut), so the ring-out is certain.
--
-- Base's "Haymaker Rush" is the default ultimate: every kit plays it until it gets its own timeline.

local Ultimates = {}

-- Roblox's own Vector3 and CFrame in the game; Lune's copies of them when the tests run outside it.
local Vector3: any = Vector3
local CFrame: any = CFrame
if Vector3 == nil then
	local outside = "@lune/roblox"
	local roblox = (require :: any)(outside)
	Vector3, CFrame = roblox.Vector3, roblox.CFrame
end

export type Key = {
	t: number,
	attacker: Vector3?, -- nil on the first key: where they really were
	target: Vector3,
	ease: string?, -- how to reach this key: "linear" (default), "out", "in"
	-- kits-7i (the gap study, B4-B6: "both roots are forced upright, so neither body can lean, roll or spin as a
	-- whole"): the TARGET's whole-body turn at this key, degrees (X pitch, plus leans the head BACK, away from the
	-- attacker; Y yaw; Z roll), applied on top of its facing; nil is upright. Interpolated like the positions, so
	-- 360 is a full backflip.
	targetTilt: Vector3?,
}

-- A camera SHOT (2026-11-15, the user: "I don't like how it just rotates around, should be more
-- thematic"): cut from the shot before (`cut`), or eased into from it. Position and look-at point are in the
-- anchor's space; `fov` in degrees, `roll` a tilt in degrees, `shake` studs of shake while it holds.
-- `rel = "attacker"` (2026-11-16, Haymaker Rush): cam and look are in the ATTACKER's own frame instead (at
-- their pose, local -Z toward the target, +X their right), for a close-up on someone whose start is
-- wherever they were standing. `rel = "pair"` (2026-11-17, v2): cam and look are offsets from the MIDPOINT of
-- the two fighters, in the anchor's axes, so a wide shot tracks the action and keeps both of them in frame
-- (design/haymaker-rush-v2-brief.md: "you can always see both fighters"). `rel = "start"` (kits-7e): in the
-- frame of where the ATTACKER STARTED, facing the target: a fixed camera they run away from (the rush).
-- `insert` (kits-7e): a close insert on one fighter (the lock-in, the wind-up), not a two-shot.
export type Shot = {
	t: number,
	cam: Vector3,
	look: Vector3,
	fov: number,
	roll: number?,
	shake: number?,
	cut: boolean?,
	-- how to reach this shot from the one before: "linear" (default), "out", "in", or "smooth" (kits-7d, the
	-- user: "no snap cuts, smooth tweens"): a spline through the run of smooth shots, so the camera never jerks
	-- at a shot; it starts from rest after a cut and settles before the next one
	ease: string?,
	rel: string?,
	insert: boolean?,
	-- kits-8a: aim at a fighter instead of a fixed point: `look` is then an offset (anchor axes) from the "attacker",
	-- the "target" or the "pair"'s midpoint, while `cam` stays where `rel` puts it. A camera that stays put and turns
	-- to follow a runner (the rush at the lens, the dash panned from where it starts).
	lookRel: string?,
}

-- The attacker's swings, by time: which swing (AnimController's sides) and how long it takes to strike.
-- `hold`: draw it back and wait there (AnimController.HoldSwing); `fromHold`: let a held swing go.
-- `contact` (kits-7f): where the fist actually meets the target, in clip seconds off the clip's strike, as measured in
-- play; the swing runs on the timeline's clock to that pose at its hit (UltimateController, AnimController.SyncSwing).
-- `loaded`, `release` and `holdShare` (kits-8a): a swing synced in three parts: its lead-in up to its hold point
-- (`holdShare` of the way to contact) by `loaded`, held there until `release`, then driven to the contact at its hit.
-- The haymaker: loaded in the crouch, held through the dash, released for the last ~0.1 s.
export type Swing = {
	t: number,
	side: string,
	windup: number,
	hold: boolean?,
	fromHold: boolean?,
	contact: number?,
	loaded: number?,
	release: number?,
	holdShare: number?,
}

-- The blows that land: `step` alternates the light and heavy flinch on the target (AnimController.HitLanded);
-- `heavy` is a launching blow.
-- `freeze` (kits-7e): a big hit holds the scene this long; its hit-stop runs as long (the keys hold the bodies).
-- `arm` (kits-7j): the striking arm, drawn long for a moment on the hit (the smear, AnimController.StretchArm).
-- `slow` (kits-7m): through the freeze the swing plays on at this share of its speed (slow motion) instead of holding.
export type Blow = {
	t: number,
	step: number,
	heavy: boolean?,
	freeze: number?,
	arm: string?,
	slow: number?,
}

export type Timeline = {
	name: string,
	cinematic: number, -- seconds before the flight
	attackerFree: number, -- seconds before the attacker gets their body back
	keys: { Key },
	shots: { Shot },
	flightFov: number, -- the chase shot's field of view at the end of the flight
	cues: { { t: number, name: string } },
	swings: { Swing },
	-- a barrage loop on the attacker between these times (AnimController.SetBarrage): `clip`, or the clash's
	barrage: { from: number, to: number, clip: string? }?,
	-- a scripted sprint on the attacker between these times (AnimController.SetDash): the rush in
	dash: { from: number, to: number }?,
	blows: { Blow },
	-- The cutscene's own colour grade on the fighters' screens while it plays (Fx/CutsceneScreen): tint RGB
	-- 0-255, then ColorCorrection saturation, contrast and brightness.
	grade: { tint: { number }, saturation: number, contrast: number, brightness: number }?,
	-- Camera KICKS on the hits (v2, the user: "there should be some screen shake ... to make it impactful"): at
	-- `t` the view narrows by `fov` degrees (a punch-in) and shakes `shake` studs more, both fading to nothing
	-- over `seconds`, on top of whatever the shot is doing.
	kicks: { { t: number, fov: number, shake: number, seconds: number } }?,
	-- the attacker's whole-body pose clips by time (kits-7j); name "" ends the last one
	clips: { { t: number, name: string } }?,
	targetClips: { { t: number, name: string } }?,
	-- kits-7e, the camera study: a constant small JITTER (studs) between these times, a new set direction every
	-- 1/30 s; and JOLTS, one directional push (screen right `x`, up `y`) that springs back within `seconds`
	jitter: { { from: number, to: number, studs: number } }?,
	jolts: { { t: number, studs: number, x: number, y: number, seconds: number } }?,
	-- kits-8h: while `from` <= t < `to`, on the fighters' screens, the attacker shows only `part` (the drawn view's
	-- close-ups, where the camera sits beside the attacker's shoulder and the drawing shows only the striking arm)
	soloArm: { from: number, to: number, part: string }?,
}

-- BASE: "Haymaker Rush" (2026-11-16). The user picked it over a black-and-white "Lights Out" (full colour,
-- every hit visible, black and white only in the impact frame), then, after trying it: "too fast", "the
-- punches are too fast compared to the animations", "the camera angles are too random". Rules kept since:
--   * ONE SIDE OF THE ACTION. Every camera stays on the attacker's right (+X): the attacker always reads on
--     screen-left, the target on screen-right, every blow and the blast travel left to right.
--   * EVERY HIT IS A REAL SWING whose fist lands on that frame, with its flinch and effect on the same frame.
--
-- v2b (kits-7d, 2026-11-17): the rush in became a real 0.74 s sprint (AnimController.SetDash); one continuous
-- flurry of rising punches (BarrageUp, a hit every 0.125 s) at a target juggled above, ended by the uppercut; the
-- haymaker (HaymakerUp) from BELOW, up and away; one rapid-punches sound over the flurry (ult_barrage).
--
-- v3, stage 1 (kits-7e, 2026-11-17): THE CAMERA, FROM A STUDY OF 10 REFERENCES (vault: 63 VFX Creation/Cutscene
-- Camera and Impact - Measured From 10 References; design/haymaker-rush-v3-beats.md). The user on v2b: "the screen
-- shake and camera work isnt really impactful". Measured in every reference, and the user's picks after it:
--   * BIG HITS FREEZE, THEN SNAP. Each big hit holds the whole scene 0.15-0.25 s (`freeze` on the blow: the bodies'
--     keys hold, the hit-stop runs that long) and the camera cuts to a new angle under a 1-frame white flash
--     (the "flash" cue), then drifts slowly. The user chose this over their earlier "no snap cuts".
--   * SHAKE IS TWO THINGS: a constant small JITTER all through the flurry (a new set direction every 1/30 s), and
--     one directional JOLT as each freeze ends, gone within ~0.2 s (Ultimates.shake). No rolling wobble, no zoom.
--   * THE RUSH from a FIXED camera behind the attacker's start (`rel = "start"`): they sprint away from the lens.
--   * Close INSERTS (`insert`) on the attacker for the lock-in and the wind-up; the wind-up pushes in and then holds
--     still before the silence (the darkening under it was removed in kits-8h).
--   * THE RESULT in line with the throw: the target shoots away from the lens.
--
--   0.00 lock-in    close insert on the attacker's face and fist, slow push                      glint
--   0.40 rush in    FIXED camera behind their start; they sprint away from it                     streaks
--   1.14 1st blow   flash, SNAP to a low 3/4 two-shot; freeze 0.2 s; jolt                         m1_finish
--   1.70 flurry     ONE held framing, low side 3/4, tilted; slow drift; jitter: 16 punches         ult_barrage
--   3.84 uppercut   flash, SNAP to a worm's-eye front-side; freeze 0.25 s; jolt up; tilt after them
--   4.65 leap       extreme wide from below, still, both against the sky
--   4.95 wind-up    close insert on the attacker's face, push in, then still
--   5.55 silence    every sound cut
--   5.70 haymaker   side profile under the drawn impact frames; freeze 0.15 s; jolt
--   6.15 blast      in line with the throw, from below behind them: the target shoots away
--
-- Space: the target starts at the origin facing +Z, the attacker comes in at +Z. y = 0 is root height.
local DASH = 0.4 -- the rush in starts
local RUSH_LAUNCH = 0.08 -- the launch crouch before the body moves (RushIn)
local BLOW = 1.14 -- the running right hook lands
local BLOW_FREEZE = 0.2
local FLURRY_FROM = 1.7 -- the first rising punch lands
local FLURRY_STEP = 0.125 -- ~8 a second (BarrageUp lands right at 0.0625, left at 0.1875 of its 0.25 s loop)
local FLURRY_HITS = 16 -- one unbroken flurry up to the uppercut's step in
local BARRAGE_STRIKE = 0.03 -- AnimClipsUltimate BarrageUp `strike` (kits-7h: chamber to contact, 0.03 s)
local UPPERCUT = 3.84
local UPPER_FREEZE = 0.25
-- THE ENDING (kits-7m, the owner: "from right after the uppercut to only show the player, showing him leap (give some
-- vfx, like a dust cloud ring and wind) and then he should be charging his punch while the leap and then bring his
-- fist forward when they are facing each other, showing both target, and then there will be a zoom in onto the fist
-- and the targets torso. the moment of the fist connecting should have a impact frame, and it should be slowed down
-- so you can feel the weight", and "the knockback from the last punch is delayed").
-- kits-8a, rebuilt from the 10-reference cutscene study (design/cutscene-study: one report per reference, 00 is our
-- diagnosis). The owner on kits-7m: the torso doesn't face the fist; the uppercut should send them FARTHER BACK so
-- the dash after them is longer; the wind-up between the dash and the punch (the arm rotating) is awkward; the
-- knockback still looks delayed; the camera and bodies are stiff. What every reference does instead:
--   * the strike is LOADED before the travel and HELD through it, released in 1-3 frames (Azure, Human Battery F3,
--     Garou vs Stinger, Mumen Rider, Tanktop, Jotaro): one clip, HaymakerUp, crouch-load, take-off, hold, drive
--   * the launch goes up AND back and the next shot shows the gap before the attacker crosses it (Azure 4.27-5.27)
--   * the target moves on the frame after contact (Azure, Garou vs Stinger, Tanktop, Jotaro); any slow part keeps it
--     MOVING (Garou vs Stinger 4.62-5.57), and drawn impact frames are not a frozen body (Azure: "resumes with the
--     target already far away")
--   * at contact the chest is square to the fist, folded onto it (every one that shows it)
-- kits-8c, MEASURED against the references (design/cutscene-study/12a, 12b; the owner on kits-8b: "the leap + dash have
-- really weak impact, doesnt feel strong at all and feels like you just glide over"). Ours was a 0.34 s launch with the
-- camera whipping after it, a 0.17 s coil, a 0.57 s dash easing out under a camera locked on the attacker, and a 0.26 s
-- still hold before the punch. The references:
--   * the launch kicks 80 % of its climb in 2 frames and is parked by 0.17 s, under a STILL camera (Azure 4.27, Jotaro)
--   * 0.43-0.5 s from the launch's end to the take-off, filled by a coil that is deepest on its last frame (Azure, TSB)
--   * the dash is 0.23 s at full speed and hits ON ARRIVAL, no slowing and no hold (Azure 5.07-5.30, TSB's lunge)
--   * its camera stays put and pans from the first coil frame, leading toward the target, while the attacker RECEDES
--     from 36 % to 10 % of the frame's height; it settles 1-2 frames before contact (Azure)
local LAUNCHED = 4.26 -- the uppercut's launch is parked at its far, high point (up AND back), 0.17 s after the freeze
local PLAYER_SHOT = 4.32 -- the cut to the dash shot
local LOAD = 4.4 -- the haymaker swing starts (HaymakerUp 0): the coil, deepest at the take-off
local TAKEOFF = 4.7 -- the body leaves the floor (HaymakerUp 0.30), 0.44 s after the launch parked
local LOADED = TAKEOFF + 0.08 -- the dive pose (HaymakerUp's hold point, 0.38), the fist still cocked
local HAYMAKER = TAKEOFF + 0.23 -- the contact, as the dash arrives
local FACE = HAYMAKER - 0.11 -- the cut to both for the last of the dash, then the zoom onto the fist and torso
local RELEASE = HAYMAKER - 0.07 -- the cocked fist snaps out (HaymakerUp 0.38-0.45)
local DIP = HAYMAKER - 0.15 -- every sound cut
-- kits-8e (2026-11-18), the owner: "there should only be 2 impact frames, the initial connection and then right before
-- the knockback", drawn by hand (design/vfx/impact: the pencil ink burst and the fist plunge, accepted "Looks good"),
-- played as pre-rendered frames by Fx/DrawnImpact. Their lengths, here so the timeline and the player agree.
-- kits-8g, the owner on kits-8f: "the impact frame is wayy too long (should be an instant, refer to the roblox
-- references)". Azure Flames (study 02, 30 fps) holds each drawing 1-3 frames and flips between them; ours held a run
-- 0.33 s and 0.43 s. Now each run flashes a few of its drawings (`show`, indices into the drawn sequence, so it still
-- reads as the burst blowing out and the fist sinking) at 60 fps, about 0.1 s each:
--   contact  6 of the 10 drawings (0.1 s), on the hit
--   plunge   5 of the 8 drawings, the last held 2 frames (0.117 s), ending as the knockback goes full speed
local DRAWN = {
	contact = { frames = 10, show = { 1, 2, 4, 6, 8, 10 }, fps = 60, hold = 0 },
	plunge = { frames = 8, show = { 1, 3, 5, 7, 8 }, fps = 60, hold = 1 / 30 },
}
local function drawnLength(name: string): number
	local run = DRAWN[name]
	return #run.show / run.fps + run.hold
end
Ultimates.DRAWN = DRAWN
Ultimates.drawnLength = drawnLength
-- kits-8h, the owner: "the impact frame comes too late, it hits midway through the gut punch ... you should see the
-- frame before you ssee the punch hit". The contact frames flash as the fist snaps out (RELEASE, 0.07 s before the
-- contact) and clear onto the fist already landed; the heavy hit's sound goes with them (the "impact" cue).
-- Then "uhh the flash still happens after the punch connects": measured in a live ultimate (with the attacker's facing
-- fixed), the fist reaches the chest front on screen about 4.965 s, 0.035 s after HAYMAKER (the swing lags the body a
-- frame). So the frames start with the snap itself and are gone just before the fist lands: the frame, then the hit.
local CONTACT_FLASH = RELEASE
local HAY_CARDS = CONTACT_FLASH - HAYMAKER + drawnLength("contact") -- the contact frames' end, after the contact
-- the owner (kits-8e): "the last punch happens too fast", "the part where the fist sinks in should be longer". The slow
-- part runs 1.62 s (it was 0.8): the same sink, stretched, about 1.4 s of it between the two drawn runs (kits-8g).
local SOAK = HAYMAKER + 0.38 -- the fist sunk in, the fold deepest (a key only now; no cards)
local SLOW_TO = HAYMAKER + 1.62 -- the slow part: the knockback in slow motion, the body MOVING away all through it
local PLUNGE = SLOW_TO - drawnLength("plunge") -- the fist plunge frames, right before they fly
-- how fast the follow-through plays meanwhile (of real speed): halved with the slow part doubled, so the fist drives
-- through the same stretch of the clip, only slower
local HAY_SLOW = 0.15
local BLAST = SLOW_TO -- full speed: the blast, and the cut to the throw line
local THROWN = BLAST + 0.3 -- the flight takes over, at the speed the knockback has reached
local HOOK_STRIKE = 0.16 -- AnimClips HookLeft/HookRight `strike`
local HAYMAKER_HOLD = 0.38 -- AnimClipsUltimate HaymakerUp `hold` (the dive pose, the fist cocked)
local HAYMAKER_STRIKE = 0.45 -- and its `strike` (the contact)
-- root to root when the running hook lands on a standing target. Measured in play (kits-7f): at 3.0 the hook's fist
-- stopped 2.3 studs short; its arc closes about 0.7 studs in front of the attacker (anime blows land at zero distance)
local REACH = 1.5
-- The juggle (kits-7k, the owner: "i dont think the positioning is right, reference the garou fight"). Garou vs
-- Stinger 7.5-9.4 s (design/references/garou-stinger/sheet1): the one in the air stays UPRIGHT, legs hanging, the
-- torso floating just above and in front of the striker's head (they overlap on screen), the striker punching up
-- from a wide low stance. So: 2.6 ahead and 3.2 up (about a body height root to root, the B7 pick), the body
-- upright with only small head-snap tilts (kits-7i's big pitch-back laid them flat over the striker's head).
local UP_REACH = 2.6
local JUGGLE_Y = 3.2
-- each punch knocks them up this much and they sink back into the next (kits-7k: Garou vs Stinger holds the one in the
-- air at ONE height for the whole 1.5 s, measured; 0.45 read as twitching)
local JUGGLE_BOB = 0.12
local JUGGLE_BACK = 0.04 -- and drives them back this far
local SWAY = 0.25 -- the attacker's root shifts this far sideways on alternate punches (B2: the body under the arms)
local LURCH = 0.3 -- and lurches in this far on every fourth
-- THE UPPERCUT (kits-8a). kits-7f measured the fist 0.8-1.3 studs off the torso at 2.2 root to root, and kits-7m's owner
-- check found the chest facing away. The cause (tests/support/Rig, lune/contact_check): the swing was held at clip
-- 0.066, while the fist is still BELOW the belly (it sweeps from y -1.1 to +2.9 between 0.066 and 0.08), and the
-- target was arched back. Now it is held at 0.075, where the fist rises through belly height, on a target still
-- falling from the juggle (caught 2.4 up) and jackknifed over the fist: measured, the fist lands mid-belly, 32 deg off
-- square to its upward drive. The attacker stands this far back and to the right of them (the sweep crosses inward).
local UPPER_CONTACT = -0.005 -- AnimClips Uppercut `strike` is 0.08
local UPPER_REACH = 1.5
local UPPER_SIDE = 1.2
local UPPER_CATCH = 2.4
-- THE LAUNCH (kits-8a, the owner: "the uppercut should launch the target farther backward, so the dash section covers
-- a noticeably longer distance"; kits-7m threw them straight up: 0.2 studs of travel back). Up AND back, about two
-- body heights back (Garou vs Stinger's Glasses: about 5 body heights a second; Jotaro: more than 5), fast at first.
local LAUNCH_BACK = 9.5
local LAUNCH_UP = 5
local HANG_DRIFT = Vector3.new(0, 0.4, -0.35) -- the hang drifts on a little (holds always move: every reference)
-- The haymaker (kits-8a): a straight drive out of the held load (HaymakerUp HAY_UP; kits-8g: about 11 deg up, it was 29,
-- the owner: "the blow should be straighter and the target shouldnt be angled too highly"). Root to root
-- at the contact, measured on the baked clips (tests/support/Rig: the fist tip in the torso's front, the drive square
-- to it): the target this far ahead and this much higher.
local HAY_GAP = 3.2 -- kits-8g: the flatter drive reaches farther (it was 2.7)
-- kits-8h: the attacker's height at the contact, so the fist lands on the chest's centre (the owner's pick "D"). Measured in a live
-- ultimate at ~40 fps the game matches the offline rig (tests/support/Rig); an earlier 0.35 "live drop" came from runs at ~14 fps
-- and was wrong. (It was 2.4, then 1.7.)
local HAY_RISE = 1.65
-- the attacker a little to the left, so the right fist meets their middle. kits-8h: -1.1 (it was -0.6), measured live: the fist
-- landed 0.2-0.3 toward the target's left of the drawing's dent
local HAY_SIDE = -1.1
-- The target's whole-body pitch at the two contacts (minus is forward, over the fist), with the Fold clip's own 28 deg
-- fold on top: the chest faces the fist's drive (tests: "the fist lands square on the chest front")
local UPPER_FOLD = -55
-- kits-8g: leaning back 18 deg, so the Fold clip's own 28 deg leaves the chest square to the ~10 deg drive (it was 360,
-- upright, for the 28 deg drive)
local HAY_FOLD = 378
-- the knockback (kits-8a): along the drive, out and up; the target's root moves this far in each part
local THROW_DIR = Vector3.new(0, 0.2, -1).Unit -- kits-8g: along the flatter drive (it was 0.5 up)
local THROW_TO_SOAK = 1.05 -- from the contact to the soak (about 2.8 studs a second, never still)
local THROW_SLOW = 1.15 -- from the soak to full speed (kits-8e: over 1.24 s now, about 0.9 studs a second: the sink)
local THROW_FAST = 4.5 -- full speed: from there into the flight without a stop (Ultimates.flight)
-- THE SINK (kits-8f). The owner asked for a longer sink, and kits-8e's live check found it read as still: measured
-- (lune/sink_check), the fist was 0.22 into the chest at the contact and then BACKED OUT, 0.74 studs clear by the
-- plunge, because the attacker crept 0.2 studs a second while the target slid away at 0.9. Now the attacker is carried
-- with the target along the drive and a little past it, so the fist works its way deeper all through the sink, and the
-- fold deepens round it. The attacker's root moves this far along the drive by each key:
-- (measured on the rig, kits-8h: the fist tip 0.21 into the chest at the contact, 0.76 at the blast, the game reading it about
-- 0.3 shallower and 0.35 lower; in the game it holds on the drawn plunge's dent, the chest's centre, all through the sink)
local CARRY_SOAK = 1.2
local CARRY_SLOW = 2.55
local CARRY_THROWN = 3.05 -- the follow-through as they are thrown off the fist
-- the fold at its deepest by the blast. kits-8h: 6 deg (it was 22), measured live at the plunge: the deepening fold turned the
-- chest 20 deg down off the level punch, so the arm came down into it from beside the lens; the drawn plunge has the chest
-- square to the fist (the owner: the arms should match the drawing before the impact frame)
local SINK_FOLD = HAY_FOLD - 6
-- kits-8g, the owner: "the target should be getting hit in the center of the torso not the top". Measured: the fist lands
-- mid-chest, then as the body folds forward over it the fist rode up to the upper chest (0.5 above the centre by the
-- blast). The attacker sinks this far below the drive by each key, so the fist stays at the centre all through the sink.
local SINK_DROP_SOAK = 0.4
local SINK_DROP_SLOW = 0.5

-- where the dash starts and the launch parks them (anchor space; the same numbers rushKeys builds), for the dash shot
local CAUGHT_Z = REACH - UP_REACH - FLURRY_HITS * JUGGLE_BACK - 0.1
local DASH_STAND = Vector3.new(UPPER_SIDE, 0, CAUGHT_Z + UPPER_REACH)
local DASH_HIGH = Vector3.new(0, UPPER_CATCH + LAUNCH_UP, CAUGHT_Z - LAUNCH_BACK)

local FLURRY: { number } = {}
for index = 1, FLURRY_HITS do
	FLURRY[index] = FLURRY_FROM + (index - 1) * FLURRY_STEP
end
local LAST_PUNCH = FLURRY[FLURRY_HITS]

-- The keys: the charge, the rush in, the pop-up, the flurry, the set, the uppercut, the leap and the haymaker.
-- Each big hit's FREEZE is a key that holds both bodies where the hit found them.
local function rushKeys(): { Key }
	local keys: { Key } = {
		{ t = 0, target = Vector3.new(0, 0, 0) },
		-- the charge: where they were (no attacker key = their own place)
		{ t = DASH, target = Vector3.new(0, 0, 0) },
		-- the launch crouch holds them in place 0.08 s (RushIn), then the rush covers the gap at FULL SPEED from the
		-- next frame (kits-7j, B8: the gap study: no reference eases into a rush; the eased-in start crept ~4 % in its
		-- first 0.15 s and read as slow)
		{ t = DASH + RUSH_LAUNCH, target = Vector3.new(0, 0, 0) },
		-- kits-8a: an explosive start (up to full speed in the first fifth), then flat out into the hook: never a
		-- slow creep and never braking before the blow
		{
			t = BLOW,
			attacker = Vector3.new(0, 0, REACH),
			target = Vector3.new(0, 0, 0),
			ease = "launch",
		},
		-- the hook's reaction (kits-7i, B5): the head snaps back and the body rolls over, held through the freeze
		{
			t = BLOW + 0.03,
			attacker = Vector3.new(0, 0, REACH),
			target = Vector3.new(0, 0, 0),
			targetTilt = Vector3.new(14, 0, 28),
			ease = "out",
		},
		{
			t = BLOW + BLOW_FREEZE,
			attacker = Vector3.new(0, 0, REACH),
			target = Vector3.new(0, 0, 0),
			targetTilt = Vector3.new(16, 0, 30),
		},
	}
	-- the hook KNOCKS them up and back to a body height off; the attacker stays planted where the hook landed
	local z = REACH - UP_REACH
	table.insert(keys, {
		t = BLOW + BLOW_FREEZE + 0.24,
		attacker = Vector3.new(0, 0, REACH),
		target = Vector3.new(0, JUGGLE_Y + 0.5, z + 0.05),
		targetTilt = Vector3.new(-24, 0, 8),
		ease = "out",
	})
	-- the flurry: each rising punch catches them as they sink and knocks them up (and a hair back, to the side the
	-- fist came from); the attacker presses after them, the body swaying under the arms and lurching in every 4th
	for index, hit in FLURRY do
		local right = index % 2 == 1 -- right lands first (BarrageUp), then left
		local sway = if right then SWAY else -SWAY
		local lurch = if index % 4 == 0 then LURCH else 0
		-- the reaction (kits-7m, the owner: "the torso should be facing the players fists"): the body pitched FORWARD
		-- over the fists below (minus is forward), limp (the Dangle pose on top), rocked toward the side each fist came
		-- from; each catch tips it a little further over, the bob lifts it back
		local lean = -30
		table.insert(keys, {
			t = hit,
			attacker = Vector3.new(sway, 0, z + UP_REACH - lurch),
			target = Vector3.new(0, JUGGLE_Y, z),
			targetTilt = Vector3.new(lean - 3, if right then -3 else 3, if right then 4 else -4),
			ease = "in", -- sinking into the catch
		})
		z -= JUGGLE_BACK
		table.insert(keys, {
			t = hit + FLURRY_STEP * 0.45,
			attacker = Vector3.new(sway * 0.6, 0, z + UP_REACH - lurch * 0.5),
			target = Vector3.new(if right then 0.15 else -0.15, JUGGLE_Y + JUGGLE_BOB, z),
			targetTilt = Vector3.new(lean + 2, if right then -5 else 5, if right then 5 else -5),
			ease = "out",
		})
	end
	-- THE SET: the flurry stops, they drop; the attacker steps in under them and to their right for the uppercut
	local caughtZ = CAUGHT_Z -- (z - 0.1: the same number, kept at the top for the dash shot)
	local standing = Vector3.new(UPPER_SIDE, 0, caughtZ + UPPER_REACH)
	table.insert(keys, {
		t = LAST_PUNCH + 0.14,
		attacker = standing,
		target = Vector3.new(0, JUGGLE_Y + JUGGLE_BOB + 0.1, caughtZ),
		targetTilt = Vector3.new(-12, 0, 0),
		ease = "out",
	})
	-- the uppercut (kits-8a): the target FOLDED DOWN over the fist rising into its belly, the chest square to it (the
	-- Fold clip on top; kits-7m's +25 arched the chest away from the fist), held through the freeze
	table.insert(keys, {
		t = UPPERCUT,
		attacker = standing,
		target = Vector3.new(0, UPPER_CATCH, caughtZ),
		targetTilt = Vector3.new(UPPER_FOLD, 0, 0),
		ease = "in",
	})
	table.insert(keys, {
		t = UPPERCUT + UPPER_FREEZE,
		attacker = standing,
		target = Vector3.new(0, UPPER_CATCH, caughtZ),
		targetTilt = Vector3.new(UPPER_FOLD, 0, 0),
	})
	-- THE ENDING (kits-8c, measured; see the constants). The uppercut KICKS them up and back (80 % of it in the first
	-- third), parked by 0.17 s, flipping over backward and hanging; the attacker coils (HaymakerUp: crouched, the fist
	-- cocked by the ear), deepest at the take-off; then the dash crosses the whole gap in 0.23 s at full speed and the
	-- fist lands ON ARRIVAL; the knockback starts on the contact (in slow motion, moving all the while) and speeds up
	-- into the flight.
	local caught = Vector3.new(0, UPPER_CATCH, caughtZ)
	local high = caught + Vector3.new(0, LAUNCH_UP, -LAUNCH_BACK)
	local function hang(t: number): Vector3
		return high + HANG_DRIFT * math.clamp((t - LAUNCHED) / (HAYMAKER - LAUNCHED), 0, 1)
	end
	local hit = hang(HAYMAKER)
	local contactSpot = hit + Vector3.new(HAY_SIDE, -HAY_RISE, HAY_GAP)
	table.insert(keys, {
		t = LAUNCHED,
		attacker = standing,
		target = high,
		targetTilt = Vector3.new(130, 0, 0),
		ease = "kick",
	})
	-- the coil: the attacker planted, the target hanging on, still turning over
	table.insert(keys, {
		t = TAKEOFF,
		attacker = standing,
		target = hang(TAKEOFF),
		targetTilt = Vector3.new(300, 0, 0),
	})
	-- the dash: full speed from the take-off and through the contact (no slowing, no hold); the target folds onto the
	-- fist (the Fold clip)
	table.insert(keys, {
		t = HAYMAKER,
		attacker = contactSpot,
		target = hit,
		targetTilt = Vector3.new(HAY_FOLD, 0, 0),
		ease = "launch",
	})
	-- THE KNOCKBACK, from the contact on: under the impact frames, then in slow motion, never still (about 3 studs a
	-- second), the attacker carried along the drive (B9); then it speeds up straight into the flight
	local thrown1 = hit + THROW_DIR * THROW_TO_SOAK
	local thrown2 = thrown1 + THROW_DIR * THROW_SLOW
	local thrown3 = thrown2 + THROW_DIR * THROW_FAST
	table.insert(keys, {
		t = SOAK,
		attacker = contactSpot + THROW_DIR * CARRY_SOAK - Vector3.new(0, SINK_DROP_SOAK, 0),
		target = thrown1,
		targetTilt = Vector3.new(HAY_FOLD - 8, 0, 0), -- folding round the fist
	})
	-- the sink (kits-8f): both carried along the drive, the fist working deeper, the fold deepening to its most
	table.insert(keys, {
		t = SLOW_TO,
		attacker = contactSpot + THROW_DIR * CARRY_SLOW - Vector3.new(0, SINK_DROP_SLOW, 0),
		target = thrown2,
		targetTilt = Vector3.new(SINK_FOLD, 0, 0),
	})
	table.insert(keys, {
		t = THROWN,
		attacker = contactSpot + THROW_DIR * CARRY_THROWN - Vector3.new(0, SINK_DROP_SLOW, 0),
		target = thrown3,
		targetTilt = Vector3.new(HAY_FOLD + 40, 0, 0),
		ease = "throw",
	})
	return keys
end

local function rushCues(): { { t: number, name: string } }
	local cues = {
		{ t = 0, name = "charge" },
		{ t = DASH, name = "dash" },
		{ t = BLOW, name = "flash" },
		{ t = BLOW, name = "blow" },
		-- the one barrage sound, from the first rising punch
		{ t = FLURRY_FROM, name = "barrage" },
	}
	for _, hit in FLURRY do
		table.insert(cues, { t = hit, name = "flurryHit" })
	end
	for _, cue in
		{
			{ t = UPPERCUT, name = "flash" },
			{ t = UPPERCUT, name = "uppercut" },
			-- the load in the crouch: the charge glows on the held fist through the whole dash (no arm turning)
			{ t = LOAD, name = "windup" },
			{ t = TAKEOFF, name = "leap" },
			{ t = DIP, name = "dip" },
			{ t = CONTACT_FLASH, name = "impact" },
			{ t = HAYMAKER, name = "haymaker" },
			{ t = PLUNGE, name = "plunge" },
			{ t = BLAST, name = "blast" },
			{ t = THROWN, name = "launch" },
		}
	do
		table.insert(cues, cue)
	end
	table.sort(cues, function(a, b)
		return a.t < b.t
	end)
	return cues
end

-- The swings: the running hook and the uppercut each start so the fist lands on its blow (the flurry is the
-- BarrageUp loop instead). The haymaker is HELD drawn back through the wind-up (AnimController.HoldSwing), then
-- let go: from the hold it strikes 0.07 s later.
local function rushSwings(): { Swing }
	return {
		-- the hook's fist is centred on the target 0.02 s after its strike (measured)
		{ t = BLOW - HOOK_STRIKE, side = "Right", windup = HOOK_STRIKE, contact = 0.025 },
		-- the uppercut meets the torso at 0.075 s of its clip, a little before its strike (0.089, measured)
		{ t = UPPERCUT - 0.1, side = "Uppercut", windup = 0.1, contact = UPPER_CONTACT },
		-- the haymaker on the shared clock (kits-8a): LOADED in the crouch (HaymakerUp 0-0.25 by LOADED, the take-off
		-- inside it), HELD through the whole dash, and DRIVEN out from RELEASE to the hit (0.25-0.32): the arm never
		-- turns on the way (kits-7m spread a 158 deg coil-and-swing over the rise)
		{
			t = LOAD,
			side = "HaymakerUp",
			windup = HAYMAKER - LOAD,
			loaded = LOADED,
			release = RELEASE,
			holdShare = HAYMAKER_HOLD / HAYMAKER_STRIKE,
		},
	}
end

-- The flinches: light and heavy in turn through the flurry; the big blows heavy, each holding its freeze.
local function rushBlows(): { Blow }
	local blows: { Blow } =
		{ { t = BLOW, step = 2, heavy = true, freeze = BLOW_FREEZE, arm = "Right Arm" } }
	for index, hit in FLURRY do
		-- BarrageUp throws right first, then left, in turn
		table.insert(blows, {
			t = hit,
			step = if index % 2 == 0 then 2 else 1,
			arm = if index % 2 == 1 then "Right Arm" else "Left Arm",
		})
	end
	table.insert(
		blows,
		{ t = UPPERCUT, step = 2, heavy = true, freeze = UPPER_FREEZE, arm = "Right Arm" }
	)
	-- the haymaker (kits-8a): its "freeze" is the impact frames and the slow motion, through which the fist drives on
	-- at HAY_SLOW of its speed while the target is already moving away (the keys), then everything goes full speed
	table.insert(blows, {
		t = HAYMAKER,
		step = 2,
		heavy = true,
		freeze = SLOW_TO - HAYMAKER,
		slow = HAY_SLOW,
		arm = "Right Arm",
	})
	return blows
end

local HAYMAKER_RUSH: Timeline = {
	name = "Haymaker Rush",
	cinematic = THROWN,
	attackerFree = THROWN + 0.05,
	grade = { tint = { 255, 255, 255 }, saturation = 0.08, contrast = 0.12, brightness = 0 },
	keys = rushKeys(),
	-- tests/UltimateCamera.spec measures every shot but the inserts and the impact frames (both fighters in frame on
	-- phone, desktop and tablet; the floor under them in the flurry). Every camera on the attacker's right.
	shots = {
		-- 0.00 the lock-in: a close insert on the attacker's face and cocked fist, from their front right; a push
		{
			t = 0,
			cam = Vector3.new(2.4, 1.5, -3.4),
			look = Vector3.new(0, 1, 0),
			fov = 50,
			rel = "attacker",
			insert = true,
			cut = true,
		},
		{
			t = DASH,
			cam = Vector3.new(2, 1.4, -2.8),
			look = Vector3.new(0, 1.1, 0),
			fov = 48,
			rel = "attacker",
			insert = true,
			ease = "smooth",
		},
		-- 0.40 the rush in (kits-8a: the owner's pick C5-A from the gap study, built at last; kits-7e's camera behind
		-- the runner foreshortened the lean and stride away, measured): over the TARGET's left shoulder, the attacker
		-- charging AT the lens, growing from about a third of the frame to filling it, the aim following them
		-- (`lookRel`) and the camera creeping in. Garou vs Stinger 0.90-2.73 (head-on), Human Battery F3 (ends lunging at
		-- the lens), Jotaro (the dive at the lens). It crops the target's shoulder on purpose (an insert).
		{
			t = DASH,
			cam = Vector3.new(3.4, 2.6, -5),
			look = Vector3.new(0, 0.6, 0),
			lookRel = "attacker",
			fov = 56,
			insert = true,
			cut = true,
		},
		{
			t = BLOW,
			cam = Vector3.new(3.1, 2.4, -4.4),
			look = Vector3.new(0, 0.9, 0),
			lookRel = "attacker",
			fov = 54,
			insert = true,
			ease = "smooth",
		},
		-- 1.14 the first hook: flash, SNAP to a low 3/4 two-shot from the attacker's side; held through the freeze with
		-- a slow creep in (kits-8a: holds always move a little, in every reference)
		{
			t = BLOW,
			cam = Vector3.new(8.6, -0.4, 3.6),
			look = Vector3.new(0, 0, 0.8),
			fov = 60,
			cut = true,
		},
		{
			t = BLOW + BLOW_FREEZE,
			cam = Vector3.new(8.35, -0.38, 3.5),
			look = Vector3.new(0, 0, 0.8),
			fov = 59.5,
			ease = "smooth",
		},
		-- 1.70-3.58 the flurry: ONE held framing, low, side 3/4, tilted; only a slow drift (the jitter is on top). kits-8g,
		-- the owner: "the camera should be more zoomed in during the barrage part, its kinda far away" (the pair filled about
		-- 40 % of the frame's height in a wide window): 14 % closer, FOV 60 and less roll, so the pair is about a fifth bigger.
		-- That is as close as it goes with both whole and the floor under them on a phone (the user's kits-7c rule; the
		-- target hangs 3.2 up, so the pair is tall), measured by tests/UltimateCamera.spec
		{
			t = FLURRY_FROM,
			cam = Vector3.new(9.12, -0.4, 1.55),
			look = Vector3.new(0, 0.7, 0.5),
			fov = 60,
			roll = 6,
			ease = "smooth",
		},
		{
			t = 2.7,
			cam = Vector3.new(8.94, -0.6, 0.86),
			look = Vector3.new(0, 0.6, 0.2),
			fov = 60,
			roll = 8,
			ease = "smooth",
		},
		{
			t = LAST_PUNCH + 0.14,
			cam = Vector3.new(8.77, -0.8, 0.26),
			look = Vector3.new(0, 0.4, -0.1),
			fov = 60,
			roll = 8,
			ease = "smooth",
		},
		-- 3.84 the uppercut: flash, SNAP to the REVERSE angle, low beyond the target on the attacker's right, looking back
		-- at the attacker's front and the fist rising into the jackknifed body (kits-8d: from behind the attacker their back
		-- hid the target in two recordings: the square contact stands them a stud to the right, turned away from any camera
		-- on that side). A slow creep in through the freeze; then STILL while the launch kicks the target up and back over
		-- the lens and out of the frame (Human Battery F3 20.10, measured: the body flies at a locked camera, 25 to 200 %
		-- of the frame in 10 frames; Jotaro: a still camera, out in 8-10 frames; kits-8b whipped the aim after them).
		{
			t = UPPERCUT,
			cam = Vector3.new(5.5, -0.8, -7.5),
			look = Vector3.new(0.6, 1.4, -1),
			fov = 58,
			cut = true,
		},
		{
			t = UPPERCUT + UPPER_FREEZE,
			cam = Vector3.new(5.38, -0.78, -7.3),
			look = Vector3.new(0.6, 1.45, -1),
			fov = 57.5,
			ease = "smooth",
		},
		-- (it crops on purpose as they fly out over the lens)
		{
			t = PLAYER_SHOT,
			cam = Vector3.new(5.36, -0.78, -7.28),
			look = Vector3.new(0.6, 1.47, -1),
			fov = 57.4,
			insert = true,
		},
		-- THE DASH (kits-8c, measured on Azure 4.83-5.30): a camera that STAYS PUT behind the attacker's right and pans
		-- toward the target at an even speed from the first frame of the coil (no ease-in), so the attacker, big in the
		-- lower left, shoots AWAY from the lens toward the target parked upper right. kits-8b aimed at the attacker the
		-- whole way, which kept them in the same spot on screen: the glide.
		{
			t = PLAYER_SHOT,
			cam = DASH_STAND + Vector3.new(6.5, 0.6, 8.5),
			look = DASH_STAND:Lerp(DASH_HIGH, 0.25) + Vector3.new(0, 0.4, 0),
			fov = 60,
			cut = true,
		},
		{
			t = FACE,
			cam = DASH_STAND + Vector3.new(6.5, 0.6, 8.5),
			look = DASH_STAND:Lerp(DASH_HIGH, 0.5) + Vector3.new(0, 0.6, 0),
			fov = 57,
		},
		-- the last of the dash: BOTH, side on from their right, the gap closing, then the zoom onto the fist and the
		-- target's torso, landing on the contact (the owner on kits-7m; the references: no hold before the hit)
		{
			t = FACE,
			cam = Vector3.new(7.2, -1.3, 0.5),
			look = Vector3.new(0, 0.3, -0.2),
			fov = 54,
			rel = "pair",
			cut = true,
		},
		-- THE DRAWN VIEW (kits-8h, the owner: "the camera zoom should match the impact frame, and also the arm
		-- posiitoning should match the impact frame too, at least before the impact frame hits"). The plunge drawing has a
		-- measurable eye: a real camera fitted to the drawing's own projection (lune/drawn_fit, tests/support/DrawnView):
		-- above the target's left front, 3 studs from the torso, FOV 30.8, rolled with the folded torso. The camera zooms onto the contact ALONG that same line of
		-- sight (1.9 times as far), so the ink burst flashes out of the fist, then pushes in along it through the whole sink
		-- and arrives at the drawing's own eye as the plunge frames flash: the live arm and torso lie where the drawn ones
		-- do. Offsets from the target's root (rel = "target"), printed by lune/plunge_view; the test "the camera sees the
		-- haymaker as the drawn plunge does" fails if the pose moves and these go stale.
		{
			t = CONTACT_FLASH,
			cam = Vector3.new(3.07, 1.4, 4.16),
			look = Vector3.new(0.96, 0.08, 1.03),
			fov = 30.8,
			roll = 6.2,
			rel = "target",
			insert = true,
			ease = "whip",
		},
		-- held under the drawn contact frames
		{
			t = HAYMAKER + HAY_CARDS,
			cam = Vector3.new(3.07, 1.4, 4.16),
			look = Vector3.new(0.96, 0.08, 1.03),
			fov = 30.8,
			roll = 6.2,
			rel = "target",
			insert = true,
		},
		-- the sink: pushing in along the drawing's line of sight to its eye as the plunge frames flash
		{
			t = PLUNGE,
			cam = Vector3.new(1.68, -0.5, 2.66),
			look = Vector3.new(-0.51, -1.21, -0.61),
			fov = 30.8,
			roll = 13.2,
			rel = "target",
			insert = true,
			ease = "smooth",
		},
		-- full speed: the result, in line with the throw, low behind them and to the right, the target shooting away
		-- and up from the lens (Garou vs Stinger 12.38-13.00, the owner's favourite)
		{
			t = BLAST,
			cam = Vector3.new(2.8, -1.6, 7.5),
			look = Vector3.new(0, 1.6, -5),
			fov = 66,
			rel = "pair",
			cut = true,
		},
		{
			t = THROWN,
			cam = Vector3.new(2.8, -1.7, 7.9),
			look = Vector3.new(0, 2.2, -7),
			fov = 70,
			rel = "pair",
			ease = "smooth",
		},
	},
	flightFov = 95,
	cues = rushCues(),
	-- no zoom punches: none of the 10 references uses one
	kicks = {},
	-- the flurry's constant small jitter (Garou vs Stinger 7.5-8.9: 0.8-1.7 % of the frame, a new direction every
	-- frame): about 0.22 studs at this distance
	jitter = { { from = FLURRY_FROM - 0.05, to = LAST_PUNCH + 0.1, studs = 0.06 } }, -- kits-8g: the camera is closer, so a little less
	-- one jolt as each freeze ends, along the hit (screen right is the way every blow travels; up for the
	-- uppercut): 5-7 % of the frame, gone within ~0.2 s. The haymaker's as its slow motion ends and the throw goes
	-- full speed.
	jolts = {
		{ t = BLOW + BLOW_FREEZE, studs = 1, x = 1, y = 0.25, seconds = 0.2 },
		{ t = UPPERCUT + UPPER_FREEZE, studs = 1.1, x = 0.2, y = 1, seconds = 0.22 },
		-- the take-off (kits-8c): the ground kicked away, a short shove down along the push
		{ t = TAKEOFF, studs = 0.55, x = -0.3, y = -1, seconds = 0.16 },
		{ t = SLOW_TO, studs = 1.3, x = 1, y = 0.45, seconds = 0.26 },
	},
	-- the drawn view's close-ups, from the contact frames to the blast: only the striking arm of the attacker, as the
	-- drawn plunge (the owner, kits-8h: "Hide body, keep arm"; the camera there sits beside the attacker's shoulder)
	soloArm = { from = CONTACT_FLASH, to = BLAST, part = "Right Arm" },
	swings = rushSwings(),
	-- the rising flurry loop, started so its first fist lands on the first punch, stopped after the last
	barrage = {
		from = FLURRY_FROM - BARRAGE_STRIKE,
		to = LAST_PUNCH + BARRAGE_STRIKE + 0.03,
		clip = "BarrageUp",
	},
	-- the sprint while the body is carried in: its legs and torso under RushRun's arms (kits-8a)
	dash = { from = DASH + RUSH_LAUNCH, to = BLOW },
	-- the attacker's whole-body pose clips (kits-7j; AnimController.SyncClip, each held on its last frame until the
	-- next): the lock-in and launch crouch, the run's arms (the Sprint legs under them), the uppercut's set crouch;
	-- from LOAD the haymaker swing has the whole body (kits-8a: nothing else plays under it, no LeapUp overlap)
	clips = {
		{ t = 0, name = "RushIn" },
		{ t = DASH + RUSH_LAUNCH, name = "RushRun" },
		{ t = BLOW, name = "" },
		{ t = LAST_PUNCH + 0.14, name = "UpperSet" },
		{ t = LOAD, name = "" },
	},
	-- the target's: limp and dangling through the juggle (kits-7m, Garou vs Stinger); FOLDED onto the fist from each
	-- big contact (kits-8a: a pose clip also keeps the flinch, which turned the chest away on the hit, off it); limp
	-- again in the hang while the attacker dashes up
	targetClips = {
		{ t = BLOW + 0.03, name = "Dangle" },
		{ t = UPPERCUT - 0.02, name = "Fold" },
		{ t = LAUNCHED, name = "Dangle" },
		{ t = HAYMAKER - 0.02, name = "Fold" },
	},
	blows = rushBlows(),
}

Ultimates.TIMELINES = {
	Base = HAYMAKER_RUSH,
} :: { [string]: Timeline }

--- The timeline for a kit: its own, or Base's "Haymaker Rush", the default ultimate, until it has one.
function Ultimates.timeline(kitId: string?): Timeline?
	return Ultimates.TIMELINES[kitId or "Base"] or Ultimates.TIMELINES.Base
end

--- The swings and blows that fall between `from` (exclusive) and `to` (inclusive).
function Ultimates.between(list: { any }, from: number, to: number): { any }
	local found = {}
	for _, item in list do
		if item.t > from and item.t <= to then
			table.insert(found, item)
		end
	end
	return found
end

--- The anchor frame: at the target, facing outward from the arena's middle (`centre`, nil off the
--- arena: the way the attacker was facing them).
function Ultimates.anchor(targetPos: Vector3, attackerPos: Vector3, centre: Vector3?): CFrame
	local outward = if centre
		then Vector3.new(targetPos.X - centre.X, 0, targetPos.Z - centre.Z)
		else Vector3.new(targetPos.X - attackerPos.X, 0, targetPos.Z - attackerPos.Z)
	if outward.Magnitude < 0.05 then
		outward = Vector3.new(0, 0, -1)
	end
	-- Built from its axes (right, up, back) rather than CFrame.lookAt, which Lune gets backwards for
	-- exactly -Z.
	local forward = outward.Unit
	local up = Vector3.new(0, 1, 0)
	return CFrame.fromMatrix(targetPos, forward:Cross(up), up, -forward)
end

-- "kick" is harder still (80 % in the first third: the uppercut's launch, measured on Azure 4.27); "launch" reaches
-- full speed in its first fifth and holds it (the rush: no creep, no braking); "whip" is a hard
-- ease-out, most of the move at once then a long settle (a launch, a camera relocating); "throw" starts at a fifth of
-- its mean speed and speeds up (the knockback leaving its slow motion at the speed it had)
local LAUNCH_SHARE = 0.2
local THROW_START = 0.2
local function eased(share: number, how: string?): number
	local x = math.clamp(share, 0, 1)
	if how == "out" then
		return 1 - (1 - x) * (1 - x)
	elseif how == "in" then
		return x * x
	elseif how == "whip" then
		return 1 - (1 - x) ^ 3
	elseif how == "kick" then
		return 1 - (1 - x) ^ 4
	elseif how == "launch" then
		local a = LAUNCH_SHARE
		return if x < a then x * x / (a * (2 - a)) else (2 * x - a) / (2 - a)
	elseif how == "throw" then
		return THROW_START * x + (1 - THROW_START) * x * x
	end
	return x
end
Ultimates.eased = eased

--- Where everything is at `t` seconds in (0 to the timeline's cinematic), in the anchor's local space:
--- the attacker (with `attackerStart`, their own place when it began, standing in for the first key),
--- and the target.
function Ultimates.pose(line: Timeline, t: number, attackerStart: Vector3): (Vector3, Vector3)
	local keys = line.keys
	local first = keys[1]
	if t <= first.t then
		return attackerStart, first.target
	end
	for index = 2, #keys do
		local key = keys[index]
		if t <= key.t then
			local before = keys[index - 1]
			local share = eased((t - before.t) / math.max(key.t - before.t, 1e-6), key.ease)
			local fromAttacker = before.attacker or attackerStart
			local toAttacker = key.attacker or fromAttacker
			return fromAttacker:Lerp(toAttacker, share), before.target:Lerp(key.target, share)
		end
	end
	local last = keys[#keys]
	return last.attacker or attackerStart, last.target
end

--- The attacker's own frame in the anchor's space: at `attackerAt`, local -Z toward `targetAt` (flat), +Y
--- up. Built from its axes, like `anchor`.
--- The target's whole-body tilt at `t` (degrees: pitch, yaw, roll), eased between keys like the positions; a key
--- without `targetTilt` is upright.
function Ultimates.tilt(line: Timeline, t: number): Vector3
	local keys = line.keys
	local zero = Vector3.new(0, 0, 0)
	if t <= keys[1].t then
		return keys[1].targetTilt or zero
	end
	for index = 2, #keys do
		local key = keys[index]
		if t <= key.t then
			local before = keys[index - 1]
			local share = eased((t - before.t) / math.max(key.t - before.t, 1e-6), key.ease)
			return (before.targetTilt or zero):Lerp(key.targetTilt or zero, share)
		end
	end
	return keys[#keys].targetTilt or zero
end

--- The target's body CFrame (world) for the cinematic: at `at`, facing `faces` flat, turned by `tilt` (degrees).
function Ultimates.targetCFrame(at: Vector3, faces: Vector3, tilt: Vector3): CFrame
	-- built from its axes like `anchor` (Lune's CFrame.lookAt is backwards for exactly +-Z, and the tests measure this)
	local toward = Vector3.new(faces.X - at.X, 0, faces.Z - at.Z)
	local forward = if toward.Magnitude > 0.001 then toward.Unit else Vector3.new(0, 0, -1)
	local up = Vector3.new(0, 1, 0)
	local base = CFrame.fromMatrix(at, forward:Cross(up), up, -forward)
	return base * CFrame.Angles(math.rad(tilt.X), math.rad(tilt.Y), math.rad(tilt.Z))
end

function Ultimates.attackerFrame(attackerAt: Vector3, targetAt: Vector3): CFrame
	local toward = Vector3.new(targetAt.X - attackerAt.X, 0, targetAt.Z - attackerAt.Z)
	if toward.Magnitude < 0.05 then
		toward = Vector3.new(0, 0, -1)
	end
	local forward = toward.Unit
	local up = Vector3.new(0, 1, 0)
	return CFrame.fromMatrix(attackerAt, forward:Cross(up), up, -forward)
end

--- The camera at `t` seconds in (0 to the timeline's cinematic): position and look-at point in the
--- anchor's space, field of view, roll and shake. A shot marked `cut` starts on its own frame; any other
--- eases in from the shot before it. `attackerAt` and `targetAt` (the poses now) place the shots marked
--- `rel = "attacker"` or `rel = "pair"`; without them those shots sit at the anchor. `attackerStart` (their place
--- when it began) places `rel = "start"` shots, facing the target's start (the origin).
function Ultimates.shot(
	line: Timeline,
	t: number,
	attackerAt: Vector3?,
	targetAt: Vector3?,
	attackerStart: Vector3?
): (Vector3, Vector3, number, number, number)
	local frame = if attackerAt and targetAt
		then Ultimates.attackerFrame(attackerAt, targetAt)
		else nil
	local startFrame = if attackerStart
		then Ultimates.attackerFrame(attackerStart, Vector3.new(0, 0, 0))
		else nil
	local function placed(shot: Shot): (Vector3, Vector3)
		if shot.rel == "attacker" and frame then
			return frame:PointToWorldSpace(shot.cam), frame:PointToWorldSpace(shot.look)
		end
		if shot.rel == "start" and startFrame then
			return startFrame:PointToWorldSpace(shot.cam), startFrame:PointToWorldSpace(shot.look)
		end
		if shot.rel == "pair" and attackerAt and targetAt then
			local middle = attackerAt:Lerp(targetAt, 0.5)
			return middle + shot.cam, middle + shot.look
		end
		-- kits-8h: offsets from the target's root (anchor axes, not turned with its pitch, so the world stays steady)
		if shot.rel == "target" and targetAt then
			return targetAt + shot.cam, targetAt + shot.look
		end
		return shot.cam, shot.look
	end
	local function place(shot: Shot): (Vector3, Vector3)
		local cam, look = placed(shot)
		if shot.lookRel and attackerAt and targetAt then
			local on = if shot.lookRel == "attacker"
				then attackerAt
				elseif shot.lookRel == "target" then targetAt
				else attackerAt:Lerp(targetAt, 0.5)
			look = on + shot.look
		end
		return cam, look
	end
	local shots = line.shots
	local current = shots[1]
	local index = 1
	for i, shot in shots do
		if shot.t <= t then
			current, index = shot, i
		end
	end
	local cam, look = place(current)
	local nextShot = shots[index + 1]
	if nextShot and not nextShot.cut and t < nextShot.t and nextShot.ease == "smooth" then
		-- A cubic Hermite spline (time-weighted Catmull-Rom tangents): the camera's velocity runs on through each
		-- shot of the run. At the run's ends (a cut, or no shot) the tangent is zero: from rest, to rest.
		local span = math.max(nextShot.t - current.t, 1e-6)
		local s = math.clamp((t - current.t) / span, 0, 1)
		local before = shots[index - 1]
		local after = shots[index + 2]
		local hasBefore = before ~= nil and not current.cut and current.t > before.t
		local hasAfter = after ~= nil and not after.cut and after.t > nextShot.t
		local nextCam, nextLook = place(nextShot)
		local beforeCam, beforeLook = if hasBefore then place(before :: Shot) else cam, look
		local afterCam, afterLook = if hasAfter then place(after :: Shot) else nextCam, nextLook
		local h00 = 2 * s ^ 3 - 3 * s ^ 2 + 1
		local h10 = s ^ 3 - 2 * s ^ 2 + s
		local h01 = -2 * s ^ 3 + 3 * s ^ 2
		local h11 = s ^ 3 - s ^ 2
		-- the tangents, scaled to this span: zero at the run's ends
		local inScale = if hasBefore then span / (nextShot.t - (before :: Shot).t) else 0
		local outScale = if hasAfter then span / ((after :: Shot).t - current.t) else 0
		local function curve(p0: any, p1: any, pBefore: any, pAfter: any): any
			return p0 * h00
				+ (p1 - pBefore) * (inScale * h10)
				+ p1 * h01
				+ (pAfter - p0) * (outScale * h11)
		end
		local function value(field: string, default: number): number
			local function of(shot: Shot?): number
				return if shot then ((shot :: any)[field] or default) else default
			end
			local v0, v1 = of(current), of(nextShot)
			local vBefore = if hasBefore then of(before) else v0
			local vAfter = if hasAfter then of(after) else v1
			return curve(v0, v1, vBefore, vAfter)
		end
		return curve(cam, nextCam, beforeCam, afterCam),
			curve(look, nextLook, beforeLook, afterLook),
			value("fov", 70),
			value("roll", 0),
			math.max(value("shake", 0), 0)
	end
	if nextShot and not nextShot.cut and t < nextShot.t then
		local share = eased((t - current.t) / math.max(nextShot.t - current.t, 1e-6), nextShot.ease)
		local nextCam, nextLook = place(nextShot)
		return cam:Lerp(nextCam, share),
			look:Lerp(nextLook, share),
			current.fov + (nextShot.fov - current.fov) * share,
			(current.roll or 0) + ((nextShot.roll or 0) - (current.roll or 0)) * share,
			(current.shake or 0) + ((nextShot.shake or 0) - (current.shake or 0)) * share
	end
	return cam, look, current.fov, current.roll or 0, current.shake or 0
end

--- The camera kicks at `t`: how many degrees narrower the view is and how many studs more it shakes, each
--- kick fading out (squared) over its own seconds.
--- The shot in force at `t` (the last one starting at or before it).
function Ultimates.currentShot(line: Timeline, t: number): Shot
	local current = line.shots[1]
	for _, shot in line.shots do
		if shot.t <= t then
			current = shot
		end
	end
	return current
end

-- The jitter's directions in turn (degrees on screen): each jumps well away from the last, set on purpose, never
-- random (house rule: every direction chosen).
local JITTER_TURNS = { 0, 135, 270, 45, 180, 315, 90, 225 }

--- The camera's SHAKE at `t` (kits-7e, from the camera study), as an offset in studs along the screen's right and
--- up: the flurry's constant jitter (a new direction every 1/30 s, full strength the whole time) plus each jolt,
--- out at once along its direction, back through zero with a small overshoot within its seconds.
function Ultimates.shake(line: Timeline, t: number): (number, number)
	local x, y = 0, 0
	for _, window in line.jitter or {} do
		if t >= window.from and t < window.to then
			-- a new direction 10 times a second (kits-7k, the owner: the camera felt choppy; every 1/30 s was a buzz)
			local turn = math.rad(JITTER_TURNS[math.floor(t * 10) % #JITTER_TURNS + 1])
			x += math.cos(turn) * window.studs
			y += math.sin(turn) * window.studs
		end
	end
	for _, jolt in line.jolts or {} do
		local into = t - jolt.t
		if into >= 0 and into < jolt.seconds then
			local s = into / jolt.seconds
			local size = (1 - s) * (1 - s) * math.cos(s * math.pi * 1.5) * jolt.studs
			local length = math.sqrt(jolt.x * jolt.x + jolt.y * jolt.y)
			if length > 0 then
				x += jolt.x / length * size
				y += jolt.y / length * size
			end
		end
	end
	return x, y
end

function Ultimates.kick(line: Timeline, t: number): (number, number)
	local fov, shake = 0, 0
	for _, kick in line.kicks or {} do
		local into = t - kick.t
		if into >= 0 and into < kick.seconds then
			local left = 1 - into / kick.seconds
			fov += kick.fov * left * left
			shake += kick.shake * left * left
		end
	end
	return fov, shake
end

--- The cues that fire between `from` (exclusive) and `to` (inclusive), in order.
function Ultimates.cuesBetween(line: Timeline, from: number, to: number): { string }
	local found = {}
	for _, cue in line.cues do
		if cue.t > from and cue.t <= to then
			table.insert(found, cue.name)
		end
	end
	return found
end

--- Where the flight ends, from `start` along the flat `outward` way: past the arena's oval grown by its
--- play-area margin and `pastEdge` more, and `below` studs under the elimination line (Round.isOut).
--- `arena` is nil off the arena (the lobby): then just `lobbyDistance` out and `below` down.
function Ultimates.flightEnd(cfg: any, arena: any?, start: Vector3, outward: Vector3): Vector3
	local dir = Vector3.new(outward.X, 0, outward.Z)
	dir = if dir.Magnitude > 0.001 then dir.Unit else Vector3.new(0, 0, -1)
	if not arena then
		return start + dir * cfg.LobbyFlightDistance - Vector3.new(0, cfg.FlightBelow, 0)
	end
	local a = (arena.SemiX or arena.StartRadius) + arena.PlayAreaMargin
	local b = (arena.SemiZ or arena.StartRadius) + arena.PlayAreaMargin
	-- How far along `dir` from `start` the grown oval's edge is: solve (px + dx s)^2/a^2 + (pz + dz s)^2/b^2 = 1.
	local px, pz = start.X - arena.CenterX, start.Z - arena.CenterZ
	local qa = (dir.X / a) ^ 2 + (dir.Z / b) ^ 2
	local qb = 2 * (px * dir.X / (a * a) + pz * dir.Z / (b * b))
	local qc = (px / a) ^ 2 + (pz / b) ^ 2 - 1
	local root = qb * qb - 4 * qa * qc
	local edge = if root >= 0 and qa > 0 then math.max((-qb + math.sqrt(root)) / (2 * qa), 0) else 0
	local floorY = math.min(start.Y, arena.CenterY) - arena.EliminationDepth - cfg.FlightBelow
	return Vector3.new(start.X, floorY, start.Z) + dir * (edge + cfg.FlightPastEdge)
end

--- Where the flying target is `share` (0 to 1) of the way through its flight from `start` to `finish`:
--- out along a rising-then-falling arc, `rise` studs up at its top.
function Ultimates.flightPoint(
	start: Vector3,
	finish: Vector3,
	share: number,
	rise: number
): Vector3
	local s = math.clamp(share, 0, 1)
	local flat = start:Lerp(finish, s)
	local lift = 4 * rise * s * (1 - s)
	return Vector3.new(flat.X, start.Y + (finish.Y - start.Y) * s * s + lift, flat.Z)
end

-- how much farther the flight turns the body over, on top of the turning it carries in (degrees, by its end)
local FLIGHT_EXTRA_TURN = 360

--- THE FLIGHT (kits-8a): the thrown target's CFrame `t` seconds into the ultimate (from the cinematic's end on), and
--- its velocity. It LEAVES AT THE SPEED THE KNOCKBACK HAD and turns on from the pose it had, at the rate it was
--- turning, so the throw never stalls or snaps. kits-7m, measured: the knockback eased out to 4 studs/s, the flight
--- jumped to 56-101 on the next frame, and the body's turn snapped 46 deg (its rotation was rebuilt from zero).
function Ultimates.flight(
	line: Timeline,
	anchor: CFrame,
	flightFrom: Vector3,
	flightEnd: Vector3,
	seconds: number,
	rise: number,
	t: number
): (CFrame, Vector3)
	local cinematic = line.cinematic
	local step = 1 / 60
	local _, endAt = Ultimates.pose(line, cinematic, Vector3.new(0, 0, 0))
	local _, before = Ultimates.pose(line, cinematic - step, Vector3.new(0, 0, 0))
	local carried = anchor:VectorToWorldSpace((endAt - before) / step)
	local flat = Vector3.new(flightEnd.X - flightFrom.X, 0, flightEnd.Z - flightFrom.Z)
	-- the share of the way covered at the carried speed from the start, then speeding up (share = a u + (1 - a) u^2)
	local flatSpeed = Vector3.new(carried.X, 0, carried.Z).Magnitude
	local a = if flat.Magnitude > 0.01
		then math.clamp(flatSpeed * seconds / flat.Magnitude, 0, 1)
		else 1
	local function at(u: number): Vector3
		local x = math.clamp(u, 0, 1)
		return Ultimates.flightPoint(flightFrom, flightEnd, a * x + (1 - a) * x * x, rise)
	end
	local u = math.clamp((t - cinematic) / seconds, 0, 1)
	local here = at(u)
	local velocity = (at(u + step / seconds) - here) / step
	-- the turn: on from the last pose, at the rate the timeline was turning it, and over a little more
	local tiltEnd = Ultimates.tilt(line, cinematic)
	local spin = (tiltEnd.X - Ultimates.tilt(line, cinematic - step).X) / step
	local faces = anchor:PointToWorldSpace(endAt + Vector3.new(0, 0, 1))
	local base = Ultimates.targetCFrame(flightFrom, faces, tiltEnd)
	local turned = spin * (t - cinematic) + FLIGHT_EXTRA_TURN * u * u
	return CFrame.new(here) * (base.Rotation * CFrame.Angles(math.rad(turned), 0, 0)), velocity
end

return Ultimates
