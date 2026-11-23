# Report for the tutorial session: Frost ice remade in Blender (test piece 4, 2026-11-22)

STATUS: ice-1 DONE (sections 1 to 7). Later work, ice-2 to ice-12, is in section 8; the ice-12 break awaits the owner's verdict. Committed as `8389203`.
The numbers and the raw log are in `design/kits/ice-study/session-log-2026-11-22.md`.

## 1. The reference measurements, and the old vs new numbers

The owner sent three links and picked two of the four solid-ice effects in them, from one sheet per effect:
**C** the flower of long blades (豆子 "Unreal VFX | Niagara-Ice", YouTube `dIWMbXMnwqc`, 2.2-5.2 s) and **D** the
clear rough chunks (ARC "Unreal VFX Portfolio [ Ice Magic ]", `hAUY_cFofLw`, 8-12.5 s). Not picked: Pew's cone
spike and jagged crystal mass (`HOeAQEvFDNA`).

| Feature | Reference C | Today's ice (kits-2) | New ice |
|---|---|---|---|
| Crystals in the cluster | about 15 blades, one centre | 19 pieces over 27 x 11 studs | 23 pieces round one centre (1 Clump, 13 SpikeTall, 9 SpikeThick); 49 blades of 8 studs or more |
| Leans from straight up | 4 to 95 degrees, median 58 | 0 to 34 (the table) | 3 to 70, median 42 |
| Cluster width : height | 2.5 : 1 | 2.05 : 1 (32.8 x 16 studs) | 1.64 : 1 (29.6 x 18.1 studs) |
| Blade width / length | broad 0.16-0.24, needles 0.05-0.07 | prisms 0.25-0.59 wide for 1 tall | broad 0.15-0.30, needles 0.07-0.10 |
| Shape | flat blade, widest 35-45 % up, narrow root, chisel tip | fat 5-7 sided prism, shoulder, cone tip | flat six-sided blade, widest 42 % up, root 40 %, tip over one edge |
| Tones | (125,162,198) to (236,251,255), facet by facet | (84,156,255) to (240,251,255) x a dark root (stored 0.10-0.20) | part colours (125,162,198) to (213,239,251) x facets (0.64,0.79,0.88) to 1 |
| Arrival | 0.07 s rise, white for 0.13 s, settled at 0.35 s | KitModels: 0.08 rise, 0.06 flash, 0.07 settle | same code; the flash is now white |
| Leaving | one white flash, breaks into chunks that fly and fall | flashes and sinks | same code (sinks): NOT changed |
| Reach ahead of the thrower | - | -1.5 to 18.3 studs | 2.4 to 18.2 studs |
| Nearest ice to the game camera | - | 13.2 studs | 15.0 studs |
| Triangles (Tall / Thick / Clump / Block / Shard) | - | 34 / 56 / 118 / 96 / 44 | 150 / 230 / 538 / 64 / 14 |
| Triangles, whole Glacier | - | 1114 | 4558 |

Reference D: lumps of 8-14 flat-ish faces, 1.2-2.2 times as long as wide, nearly colourless (saturation
0.02-0.27), bright rims. New Block: one boulder of 13 hull points with three small lumps at its foot (64
triangles). New Shard: a 9-point wedge (14 triangles). Both in the same pale blue as the blades (owner: "Yes,
both like this").

Misses against the reference that were named to the owner: the flower is taller and steeper than the
reference's (1.64 : 1 against 2.5 : 1; median lean 42 against 58) because the game sizes the effect to today's
footprint and height; flat facets instead of frost and cracks (the owner chose flat); no glow, mist or sparks
(particles are not part of this piece); it sinks instead of shattering.

## 2. Which checks or thresholds felt wrong, and why

- **"Exactly 1 unit tall, root at the origin" is not what the game uses.** KitModels places a MeshPart by the
  middle of its bounding box and scales it by its height. The real rules are: bounding box centred on the origin
  in X and Y, bottom at z = 0, and a limit on width per unit of height. mesh_report has none of these; I added
  `bbox_centre_xy`, `z_min`, `height`.
- **mesh_report passes interpenetrating shells.** A clump of 13 closed blades that pass through each other is
  "manifold" by the edge count. That is fine for an effect mesh, but the report cannot tell it from one welded
  solid. It also has no check for colour sets, colour range or UVs; I added `colour_sets`, `colour_min/max`.
- **No check sees the file.** The .blend was right while the kits-2 GLB held two colour sets. `glb_report.py`
  (numpy, reads the GLB's accessors) is the check that matters before an upload.
- **"Keep the triangle counts small" has no number.** I set budgets myself (200 / 300 / 650 / 250 / 40) and the
  Glacier went from 1114 to 4798 triangles. Nothing told me whether that is acceptable for a 1.4 s effect.
- **The reference's numbers could not be pass marks.** Width : height 2.5 and median lean 58 belong to a
  free-standing showcase; the game needs the ice inside the move's reach and "REALLY big". I printed them beside
  mine and said why they differ (Mastery 2's rule for cameras applies to models too).
- **Camera clearance needed a baseline.** "The camera never ends up inside the ice" became three numbers
  (nearest vertex to the camera, to the camera-to-chest line, furthest behind the thrower), passed when no worse
  than today's (13.2, 2.02, 1.5 behind).

## 3. Every error or trap hit: message, cause, fix

| # | Symptom / message | Cause | Fix |
|---|---|---|---|
| 1 | Imported kits-2 GLB rendered pure white in Blender | The file has COLOR_0 all white and COLOR_1 painted; I read `color_attributes[0]` | Pick the set whose values vary; for new exports `export_vertex_color="NAME"`, then `glb_report.py` |
| 2 | Roots near black in Studio though painted 0.42 | BYTE_COLOR is exported as linear: 0.42 -> 0.098-0.20 (read back with EditableMesh) | Paint a FLOAT_COLOR attribute; the GLB then holds (0.64, 0.79, 0.88)-(1, 1, 1) exactly as painted |
| 3 | The game's "white-hot" flash is navy with white tips | Vertex colours multiply into Neon, about 4.2 x stored^3.8/3.2/2.4 | Keep stored colours above (0.64, 0.79, 0.88); put the tone in the part Color |
| 4 | First look render: blades across the whole screen, over the fighter | The Clump was 2.1 wide for 1 tall; the game scales by height (16 studs -> 33 wide) | A tall middle blade; width 0.73-0.79 of the height; a clearance check |
| 5 | Preview floor cyan, ice grey | World light at sky colour and full strength; gamma applied to the vertex colour | Camera rays see the sky, the scene is lit by (0.42, 0.62, 1.0) x 0.6; albedo = linear part Color x stored colour |
| 6 | New flower reached 22.9 studs ahead (the move hits to 15) | Long needles pointing ahead, and random yaw swinging side blades forward | Shorter, steeper blades ahead and behind; a yaw per row chosen by `fit_yaws.py` |
| 7 | Three renders at once: 25 s a frame instead of 2 | Three EEVEE processes sharing one GPU | One clip at a time (`render_preview_all.sh`) |
| 8 | Stopping the background script did not stop its Blender; the script then started its next clips | TaskStop ends the shell, not its children; `wait` returned when I killed the child | Stop by process, filtered on the command line (the owner's own Blender is also `blender.exe`) |
| 9 | Close-up camera sat inside the cluster / behind the thrower's head | Camera placed without looking at a test frame | Render one frame of every new camera before the batch |
| 11 | The owner pointed at a thin strip on the ground ("what is this part?") | A side blade of a leaning piece lay almost flat, most of it under the floor. Then a second one surfaced away from its root and read as a loose shard. No check saw either | Three counts added (blades flatter than 70 degrees, blades only just poking out, blades surfacing over 30 % of their length from the root), all 0; yaws refitted; the three pieces nearest the thrower made the slim piece; mid-ring leans 48-50 -> 40-42 |
| 12 | Clips rendered at 10 s a frame | The hold is 50 identical frames | Render each distinct moment once and copy (124 frames -> 35 renders, 56 s a clip) |
| 13 | The lobby-only video was 6 frames long | A render stopped mid-write left a 0-byte PNG | Delete 0-byte frames, resume |
| 14 | "Meadow" capture floated over the sea | The arena map changes each round | Raycast `HT_Map` for a flat spot each play test |
| 10 | `Start-Sleep` blocked | The harness forbids sleeping to wait | Background task and its notification |

Not hit, but checked: the glTF exporter's option names in 5.2 (`export_vertex_color`, `export_vertex_color_name`,
`export_all_vertex_colors`, `export_active_vertex_color_when_no_material`) read from
`scripts/addons_core/io_scene_gltf2/__init__.py`; `bmesh.ops.bisect_plane(dist=1e-4)` then `triangle_fill` closed
every cut blade (0 non-manifold edges on all five pieces).

## 4. What took the most attempts

1. **Making the Blender preview show what Studio shows** (five rounds): camera and layout matched on the first
   render, colour did not. It needed matched pixel pairs between a Studio capture and the render of the same
   moment, a blue ambient, the linear colour model and a fitted Neon response.
2. **The look sheets** (three rounds): too wide (trap 4), then thin and small, then thicker blades with the
   reference's facet tones and a bigger flower.
3. **The eruption renders** (three starts): parallel runs, a stopped script that kept going, then sequential.

## 5. The owner's verdicts, in their words

- Effects: picked "C: flower of long blades" and "D: clear rough chunks".
- Looks: picked "Look 3" (the flower as a new layout, pale glass).
- Chunks: "Yes, both like this".
- Surface: "A: flat facets".
- Preview: "Yes, try in Studio". Then, on a crop of the video: "also what is this part?" (the strip, trap 11). After the fix: "Yes, upload it".
- Place: "Yes, change the place".
- In Studio, at full speed: "Looks right".
- Did the preview show what Studio did: "Yes". (My own comparison: Studio's ice is lighter and more see-through than the preview; shapes, layout, timing and the white flash matched.)

## 6. The files made, the new asset ids and the old ones

- Scripts (`design/kits/ice-study/`): `ice_pieces.py` (the five pieces, every blade listed by hand),
  `ice_layout.py` (the flower table, yaws, palettes), `ice_scene.py` (game camera, floors, Roblox-like materials,
  the Glacier's layout and ERUPT), `export_kit.py`, `glb_report.py`, `check_features.py`, `fit_yaws.py`,
  `render_today.py`, `render_looks.py`, `render_chunks.py`, `render_surface.py`, `render_turntable.py`,
  `render_preview.py`, `render_preview_all.sh`, `make_preview.sh`, `make_pickers.sh`, `make_look_sheets.sh`,
  `measure_refs.py`, `px.py`, `make_frost_texture.py` (unused: the owner chose flat facets), `check_today.sh`.
- Model: `design/kits/out/export/ice_kit_v2.glb` (126 200 bytes), `design/kits/ice-study/out/ice_kit_v2.blend`.
- Sheets for the owner: `sheets/pick_A..D.png`, `out/look_sheet_1..3.png`, `out/chunk_sheet.png`,
  `out/surface_sheet.png`, `out/turntable_sheet.png`.
- Old ice (the way back): package `rbxassetid://94341799888558` version 1; mesh ids Ice_SpikeTall
  `129137373517622`, Ice_SpikeThick `138794947248453`, Ice_Clump `123452558929132`, Ice_Block `72909937929383`,
  Ice_Shard `96667560132911`.
- New ice: Model / package `rbxassetid://124516489464164` version 1 ("HT Ice Kit v2", group 2970443, Approved), at `ReplicatedStorage.HT_KitModels.IceKit`. Mesh ids: Ice_SpikeTall `139040606692395`, Ice_SpikeThick `138248884273130`, Ice_Clump `109784265225411`, Ice_Block `117185791164626`, Ice_Shard `127428084982135`.
- The old IceKit is kept at `ServerStorage.HT_KitModels_Old.IceKit_kits2`. To switch back: move it to `ReplicatedStorage.HT_KitModels` as `IceKit`, remove the new one, and restore `FrostFx.luau` from Git (`git checkout src/client/Fx/FrostFx.luau`, then the same in the place).
- Code (not committed): `src/client/Fx/FrostFx.luau` (ICE colours, `ICE_SEE` 0.25, the 23-row GLACIER table with a yaw column, centre 8, `crystal(..., yaw)`) and the stamp in `src/server/init.server.luau` (`cam-1+ice-1+jab-3+keys-1+kits-8t+puff-1+village-4+ui-20e`). Both patched into the place by find-and-replace and confirmed by hash (FrostFx 1896942439, Server 1967722221). Gates: rojo build, 608 tests, selene 0, stylua clean, fx_smoke 7 of 7.
- Studio captures: `studio/` (today's and the new ice), sheets `out/studio_check_sheet.png`, `out/studio_real_moves_sheet.png`; preview `out/ice_preview_side_by_side.mp4`, `_slow.mp4`, `ice_preview_moments.png`, `turntable_sheet.png`.
- Vault: `56 Field Notes/Vertex-Coloured Kit Meshes - Colour Sets, Linear Export, Neon and Bounding-Box
  Placement.md` (new), linked from `Field Notes Start Here.md`.

## 7. What in the tutorial notes was wrong, missing or unclear for solid models

- **Mastery 0, section 9** says "Blender (x, y, z) -> Roblox (-x, z, y)" and nothing about where a MeshPart's
  position is. Missing: the part's CFrame is the middle of the mesh's bounding box; the Blender origin is lost
  unless an imported pivot is used. For any piece a script places, say "centre the bounding box".
- **Mastery 0, mesh_report**: add `z_min`, `height`, `bbox_centre_xy`, colour sets and colour range, UV count; say
  that a mesh of several closed shells passes.
- **Nothing covers reading the exported file.** Add a GLB report step ("the file, not the .blend, is what Roblox
  gets") and the exporter's colour options by name.
- **"Trim Sheets Atlases and Vertex Colors"** says vertex colours multiply the part's Color (true) and that glTF
  "exports the active colour attribute". Missing: BYTE colours are converted to linear, FLOAT colours are not; the
  multiply applies on Neon and is much stronger there; how to read the stored colours back in Studio
  (`AssetService:CreateEditableMeshAsync`).
- **"Procedural Model Kits - Lessons", section 8** (every colour layer is exported) is right and was the cause of
  trap 1; it should name `export_vertex_color="NAME"` as the fix.
- **Mastery 3's route** assumes one reference = one effect size. For a model that the game scales and places,
  the route needs a step before the looks: read how the game sizes and places the piece (by height? by bounding
  box? random yaw?) and measure today's footprint, reach and camera clearance as the pass marks.
- **Preview conventions** (Mastery 1 section 5: each half 960 x 1080) crop a wide effect: with a vertical FOV of
  70 a 960 x 1080 half shows only 32 degrees to each side, and the Glacier spans 39. I used full 16:9 views at
  half size in a 2 x 2 grid (today | new, meadow over lobby stone) plus the new ice alone at 1920 x 1080.
- **No note says how to match a Blender preview to Studio's lighting.** What worked is in section 3, row 5, and
  in `ice_scene.py`; the measured Lighting values are Brightness 2, Ambient (70,70,85), OutdoorAmbient
  (100,100,115), ClockTime 16, sun toward (-0.860, 0.497, 0.113), Bloom 1 / 40 / 1.6, ColorCorrection contrast 0.12.
- **Unclear:** "kit effects big" against "the camera never ends up inside the ice". A number for the largest
  allowed reach toward the camera would settle it; I used today's.

## 8. After ice-1: the break, the textures and the glow (ice-2 to ice-12, added 2026-11-23)

Sources: `HANDOFF.md` entries "ice-2" and "ice-3 to ice-12". Sections 1 to 7 describe ice-1 and are left as written;
where they disagree with this section (vertex colours, "flat facets", "it sinks", package `124516489464164`), this
section is the current state. Committed and pushed as `8389203` (merged in `997283e`).

### What changed

| Step | Change | Why |
|---|---|---|
| ice-2 | Glacier and freeze crystals break into `Ice_Shard` chunks instead of sinking; the Frostbite trail still sinks | Owner: "all crystals like the glacier and frozen fighter should break, but i think the frostbite trail should melt instead." |
| ice-3 on | Vertex colours removed. Colour, roughness and metalness are baked in Blender (`bake_frost2.py` -> `design/kits/out/export/ice_kit_v4.glb`) and arrive as a SurfaceAppearance on each of the five meshes | Owner's rule: all art including textures is made in Blender; models stay default grey, colour comes from textures and VFX; a texture must wrap without stretching |
| ice-3 on | Solid, paler ice (`ICE_SEE` 0), stands 1.4 s (`GLACIER_HOLD`), one floor ring | Owner's picks from sheets |
| glow | `EmissiveMaskContent` = the roughness map, `EmissiveStrength` 4, `EmissiveTint` (200,235,255) on all five SurfaceAppearances | Owner picked "Strong" |
| ice-9 to 11 | Physics chunks for the break | Replaced at the owner's pick |
| ice-12 | Break copied from the reference: 2 to 8 small pieces a crystal burst from the cluster's middle, drag to a hang, white 0.2 s, then textured ice shrinking away (0.9-1.4 s); sparks, lingering mist, snow and a pale frost patch (2.2 s) at 93 f | Owner picked all four: more smaller pieces, burst and hang, cool quickly, sparks/mist/frost |

Current ice: package `rbxassetid://116591693926374` ("HT Ice Kit v4 gloss test") at
`ReplicatedStorage.HT_KitModels.IceKit`. Older kits in `ServerStorage.HT_KitModels_Old`: IceKit_kits2, IceKit_v2
(vertex colours, section 6's "new ice"), IceKit_v3 (textured, no gloss). Build stamp
`cam-1+ice-12+jab-3+keys-1+kits-8t+puff-1+village-4+ui-20e`. Gates: rojo build, 610 tests, selene 0, stylua clean,
fx_smoke 7 of 7.

### Errors and traps (continues section 3)

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 15 | Three frost textures thrown away | They were computed by a script, not made in Blender | Materials, bake and render in Blender for every image, textures included |
| 16 | Uploaded GLB arrived with a plain `TextureID` and no gloss | A GLB with base colour only becomes `TextureID`; base colour + metallicRoughness becomes a SurfaceAppearance | Export both maps |
| 17 | The white-hot flash did not show on textured pieces | A SurfaceAppearance hides the part's Material and Color | `textured(part, on)`: parent the SurfaceAppearance to nil for the flash, then back |
| 18 | The first cast of a session was untextured | SurfaceAppearance images load late on first use | `KitModels.preload()` with `ContentProvider:PreloadAsync` on the kit |
| 19 | fx_smoke failed after the preload | A new `GetService` needs a stand-in in `lune/fx_smoke.luau` | ContentProvider stand-in added; run fx_smoke after every Fx change |
| 20 | A glow aura per crystal read as one blob, four attempts | Soft emitters on 23 overlapping crystals always merge | Dropped ("drop the aura idea"); the glow is the SurfaceAppearance's emissive instead. `addGlow` is left in KitModels, unused |
| 21 | Generated Lua for a place patch was broken | It passed through a bash heredoc, which ate the escapes | Never paste generated Lua through a heredoc; one `execute_luau` that asserts the old hash, swaps exact strings, asserts the new hash, then writes |
| 22 | Studio screenshots in play sometimes black | They return another Roblox window ("rungstig") | Open; `screen_capture` with `camera_position` works in Edit mode, but the lobby only exists in play |
| 23 | Re-inserting the package would lose the glow | The three emissive values are set on the instance in the place, not in code or the GLB | Do not re-insert; or set them again after |

### What took the most attempts

The glow (four aura attempts before the emissive mask), and the break (shards in ice-2, physics chunks in ice-9 to
11, the reference's burst-and-hang in ice-12).

### The owner's verdicts, in their words

- ice-2 break in Studio: "Looks right". Then the rule above about breaking and melting.
- Textured ice: "looks right". Glow: "ok it looks good". Aura: "drop the aura idea".
- ice-12 break at full speed: NOT JUDGED YET (seen only by me, in slow motion on the lobby stone; captures in
  `studio/`).

### Still open

- The Frostbite trail's melt (owner picked both effects of YouTube `mOqFQpsmBeQ`; sheets `sheets/melt_pick_A.jpg`,
  `melt_pick_B.jpg`). Not started.
- The single ring's texture (`Tex.Circle`) is a double line; the break has no thin streak lines; the frost patch is
  hard to see on pale stone; the freeze block glows and may hide the fighter; `Lighting.EnvironmentSpecularScale` is
  0.1, so gloss reflections are weak.

### For the tutorial notes (continues section 7)

- Say which GLB contents become a SurfaceAppearance and which a `TextureID` (trap 16).
- Say that a SurfaceAppearance hides Material and Color, and how to flash such a part (trap 17), and to preload (18).
- `SurfaceAppearance.EmissiveMaskContent / EmissiveStrength / EmissiveTint` exist, bloom, and can be set in Edit mode.
- "Colour from textures, models grey" replaces the vertex-colour route of sections 1 to 7 for this game.

### ice-13 (2026-11-23): the owner's verdict on the ice-12 break, and the fix

- Verdict, full speed: "our shatter spreads quite wide and drops very fast", "the pieces shrink at an unnaturally fast
  pace", then "the ice pieces in the reference dont shrink, they gradually break into smaller pieces".
- Cause: the reference's break was read as a cloud, not one piece at a time. "Fewer, smaller pieces later" became
  "shrink"; the direction came from the blades (outward), not from the frames (up).
- Fix: burst mostly up, stop in 0.3 s, sag at gravity 3; pieces split into two of 0.62 x size, twice; only the last
  shrink, for 0.12 s. Trap 24 for section 3: follow single pieces through the frames and count pieces per frame.
- Not judged by the owner yet.

### ice-14 to ice-17 (2026-11-23): four more rounds on the break, then "Looks right"

| Build | Owner's words | Change |
|---|---|---|
| ice-14 | "they should slowly drop instead of going out to the side ... they just cut in half and go opposite directions sideways and the pieces look like theyre constantly rotating" | Slow fall, no sideways push at a split, turning dies away in 0.3 s |
| ice-15 | "instead of teleporting apart, the pieces should slowly drift apart" | New pieces start at the parent's exact place; a one-frame blink at each split fixed (new pieces sat at y -1000 for a frame) |
| ice-16 | "the pieces should break less ... in the reference, the pieces break very slowly and dont move too much" | Every other piece breaks, once, 0.7-1.1 s in; halves 0.7 x size, barely part |
| ice-17 | "i want it to follow physics ... in a curve since theyre effected by gravity ... the initial launch shouldnt be powerful enough for them to scatter a lot" | Launch (up 16-30, out 2-7) plus gravity 30 only; gone at the floor. Owner: "Looks right" |

- Trap 25: a leftover `debris()` call in `FrostFx.strike` threw 8 chips of the same mesh at the break (gravity 150,
  random constant spin, no floor). The owner's "drops very fast" and "constantly rotating" did not fit the code being
  tuned; it took four rounds to find because only one source was read. Fix: count every instance by name per frame and
  log the lowest and furthest; outliers are another source.
- What took the most attempts in the whole piece: this break (ice-2, ice-9 to 17).
- For the tutorial notes: before tuning debris, write down from the reference (a gridded every-frame sheet) the climb,
  the outward speed and how the fall speed grows; that gives launch speeds and a gravity directly.

## 9. The Frostbite trail's melt (melt-0 and melt-1, 2026-11-23)

Full detail: `HANDOFF.md`, entries "melt-0" (eight notes) and "melt-1". Owner's last word at full speed: "Looks right".

### What was built

One strip of flat ice tiles behind the dash, about 6 studs wide (three columns 1.5 apart, a row every 1.3 studs,
tiles over their neighbours); six uneven tile meshes and their colour and gloss textures made in Blender
(`bake_tiles.py` -> `design/kits/out/export/ice_tiles_v1.glb`, Model `75962214621516`); short crystals (0.8-1.8 studs)
on the trail's two edges; each crystal turns into a cloud of flat white triangles (Blender-rendered image
`116944529241949`) and is gone; then the tiles shrink toward their own middles in a soft white particle haze with a
few sparks. Reference for the order and timing: YouTube `mOqFQpsmBeQ` (dissolve 1.8-2.8 s, floor patch 5.5-7.4 s).

### The owner's corrections, in order

| What I showed | Owner's words | Change |
|---|---|---|
| Two colour looks, hexagon tiles | "more random instead of all being hexagons"; "dissolving spikes on the sides"; "match the glacier" | Six uneven shapes; edge crystals; the Glacier's blues and frost |
| Crystals in two rows, 3-6 studs | "placed more randomly, and shouldnt be so long"; "the crystals should dissolve before the ice melts" | Uneven placement, shorter; tiles wait for their crystals |
| Thick slabs, crystals all over | "by thicker i dont mean vertically thick"; "at the edges of the trail (but still ON the trail)" | Flat tiles; crystals on the edges only |
| A wider trail | "you didnt need to make the trail wider ... just about the apparent gaps" | Earlier width, no gaps |
| Evaporation as rising dots | "not like a rising particle but rather a glowing white aura around each melting piece" | (next rows) |
| A soft ball round each tile | "it looks like a circle around the piece instead of an aura" | |
| An outline glow with wisps | "i dont want it to be an outline, i want it to surround the pieces ... i dont want any spikes" | Real particles in Studio, three variants; owner picked C (soft + sparks) |
| The trail in play, 11 studs wide | "its enough to cover 3 ppl even though it should only be for one person" | 6 studs |
| Crystals 1.4-3.6 studs | "scaled down to match the smaller trail ... i dont want them to be tall" | 0.8-1.8; the four start crystals too |

### Errors and traps (continues section 3)

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 26 | Four aura previews rejected in a row | A particle cloud was mocked up as solid shapes in Blender stills | Preview anything that will be particles in Studio with real emitters |
| 27 | `screen_capture` with `camera_position` showed no particles | Emitters the real camera is not looking at are not simulated | Hold the real camera on them (RenderStep, Scriptable), wait, capture with no camera arguments |
| 28 | First Blender renders appeared in `C:\out` | Blender reads a bare relative output path from the drive root | `os.path.abspath` on every output path |
| 29 | Export failed: "StructRNA of type Mesh has been removed" | `ice_scene.new_scene()` resets Blender and deletes every mesh | Export before making another scene |
| 30 | Every melting tile threw "NumberSequence must end at time=1.0", 10 fps | `FxKit.curve` takes triples (time, value, envelope); I passed pairs. The error was inside KitModels' per-frame step | `keys`/`fade` for pairs; the melt callback runs in its own thread |
| 31 | The melting trail was one white band | The haze was tuned on tiles standing alone; the trail's tiles overlap, so the hazes add up | A sixth of the rate, fainter |
| 32 | The laid trail was white, not blue, in the arena | Flat tiles face the sun; the Glacier's emissive strength 4 plus bloom blows out | Strength 1 on the tile kit's instances |
| 33 | "Tall crystals" still there after shortening the trail's | A second source: four start crystals of 4-5.5 studs in `FrostFx.frostbite` | Count pieces by name and log the tallest (the same lesson as trap 25) |
| 34 | Studio could not fetch from a local server | localhost is not in the Assistant's HTTP allowlist | Patches are typed as hunks and checked by hash |

### For the tutorial notes (continues section 7)

- Blender is for models and textures. A look that will be particles is judged from real emitters in Studio.
- A flat, upward-facing emissive surface needs far less emissive strength than an upright one in the same light.
- An effect tuned on one piece must be re-tuned on the real count and overlap before it is shown.
- When the owner describes something the code being tuned cannot produce, look for a second source first.
