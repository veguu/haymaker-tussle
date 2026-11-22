# Session log 2026-11-22: Frost ice remade in Blender (test piece 4)

Folder: `design/kits/ice-study/`. Scripts are the source of truth; `out/` holds renders, `sheets/` the reference
sheets, `studio/` the Studio captures, `ref/` the downloaded clips.

## The owner's references and picks

- Three links: Pew "Ice Moveset Showcase" (`HOeAQEvFDNA`, 1280x720 60 fps, 97 s), 豆子 "Unreal VFX | Niagara-Ice"
  (`dIWMbXMnwqc`, 30 fps, 8.4 s; a 2560x1440 copy exists), ARC "Unreal VFX Portfolio [ Ice Magic ]"
  (`hAUY_cFofLw`, 59.94 fps, 15 s; 2560x1440 copy).
- Four solid-ice effects found (sheets `pick_A` to `pick_D`): A Pew's single cone spike (0:29.5-0:31.6), B Pew's
  jagged crystal mass (1:15.4-1:33), C the Niagara flower of long blades (2.2-5.2 s), D ARC's clear rough chunks
  (8-12.5 s).
- OWNER PICKED **C and D** (question 1, with the four sheets).
- OWNER PICKED **Look 3** of three looks (question 2): the reference's flower as a new Glacier layout, pale glass
  tones. Look 1 was blades in today's layout in the game's blues; Look 2 the same in pale tones.
- OWNER: chunks (D) "**Yes, both like this**" for the freeze block and the thrown debris (question 3).
- OWNER: surface "**A: flat facets**" over a frost texture with cracks (question 4). So: vertex colours only.

## Reference C, measured (still at 3.6 s, 2560x1440; crop 1440x810 at (600, 380); root at (700, 600))

- About 15 blades from one centre: 5 broad, 6 or more needles, 3-4 short stubs in the middle.
- Leans from straight up (apparent; the camera is only about 10-12 degrees above the floor): 4, 30, 38, 44, 55, 62,
  74, 76, 79, 95 for the ten clearest. Median 58.
- Whole cluster about 2.5 times as wide as it is tall (tips 135..1310 px across, 450-467 px tall).
- Broad blades: width 16-24 % of length (645 px long x 110-130 wide; 450 x 110; 525 x 85). Needles 5-7 % (630 x 35).
  Widest about 35-45 % of the way up, narrower at the root, chisel tip over one edge; 2-3 long facets a side.
- Tones (ice pixels, percentiles 5/25/50/75/95): (125,162,198) (154,196,225) (182,224,244) (213,239,251)
  (236,251,255). Hue 193-210, saturation 0.07-0.37. No root-to-tip gradient: the tone changes facet by facet
  (shaded facet (132,183,220), lit facet (206,233,250)), plus frost mottling and white crack lines.
- Arrival (30 fps): spark lands 2.20 s, first ice 2.267, full size by 2.333 (0.07 s rise), white-out 2.333-2.433
  (white share of the frame 0.31-0.33), colours back by 2.6 (0.35 s after the start).
- Stands 2.33-4.97 s. Leaving: one white flash 5.0-5.17 s (white share 0.23-0.35) while it BREAKS into rounded
  white-hot chunks that fly up and out and fall for about 0.7 s. It does not sink. (The game's ERUPT sinks; that
  is motion code, not part of this piece. Named to the owner as a difference.)

## Reference D, measured (stills at 9.3 s and 12.5 s)

- Chunks: irregular lumps of about 8-14 flat-ish faces, crumpled surface, bright rims; 1.2-2.2 times as long as
  wide; the largest five times the smallest.
- Tones (percentiles 5/25/50/75/95): flying (112,115,133) (120,138,164) (164,161,167) (183,196,211) (229,244,255);
  on the floor (109,112,132) (116,124,142) (131,156,167) (203,202,207) (246,254,255). Saturation 0.02-0.27.

## Today's ice (kits-2), measured

- Package `rbxassetid://94341799888558` version 1 at `ReplicatedStorage.HT_KitModels.IceKit`. Mesh ids:
  Ice_SpikeTall `129137373517622`, Ice_SpikeThick `138794947248453`, Ice_Clump `123452558929132`,
  Ice_Block `72909937929383`, Ice_Shard `96667560132911`. (Keep: these are the way back.)
- Sizes (x, z, height) and triangles: SpikeTall 0.293 x 0.254 x 1, 34; SpikeThick 0.587 x 0.427, 56; Clump
  0.981 x 0.773, 118; Block 1.039 x 0.840, 96; Shard 0.360 x 0.430, 44.
- The Glacier: 19 crystals, 32.8 studs wide, 16 tall (2.05 : 1), from 1.5 studs BEHIND the thrower to 18.3 ahead
  (the move hits to 15); nearest ice to the game camera 13.2 studs; 1114 triangles.
- Studio captures: `studio/today_lobby_t005/t012/t060/t118.jpg`, `today_meadow_t005/t060.jpg`,
  `today_pieces_white.jpg` (the five pieces with a white part Color beside a white card).

## Findings (all measured this session)

1. **The kits-2 GLB holds two colour sets.** `COLOR_0` is all white, `COLOR_1` holds the painting (the vault's
   "Blender 5.2 glTF exports every colour layer" trap). Roblox showed the painted one. Blender's importer names
   them `Color` and `Color.001`.
2. **Byte vertex colours are converted to linear on export.** Painted 0.42 (root) arrived in Roblox as 0.098-0.20
   (read back with `AssetService:CreateEditableMeshAsync` + `GetFaceColors`); painted (0.92, 0.97, 1.0) as
   (0.81, 0.92, 1.0). The new kit paints a FLOAT_COLOR attribute, which the exporter writes unchanged
   (`glb_report.py`: COLOR_0 min exactly (0.64, 0.79, 0.88)).
3. **Vertex colours multiply into Neon too, and harder.** The "white-hot" flash of today's ice is navy-black at
   the roots and white only at the tips. Fitted from the captures: shown about 4.2 x stored^3.8 / ^3.2 / ^2.4 (R/G/B).
   So the new colours stay above (0.64, 0.79, 0.88): the flash is white.
4. **A MeshPart is placed by the middle of its bounding box and sized by its height.** A flower 2.1 wide for 1
   tall was 33 studs across as the Glacier's 16-stud middle piece and reached within 2.4 studs of the camera.
   The Clump therefore has a tall middle blade (width 0.73-0.79 of its height).
5. Shaded sides in Studio are blue (sky light): pixels like (1, 35, 107) on a pale-blue part. The preview's
   ambient is (0.42, 0.62, 1.0) x 0.6 with a 3.2 sun; matched pixel pairs agree within about 30/255.
6. Opaque parts (white Color, Transparency 0) showed the dark vertex colours much darker than the same mesh at
   Transparency 0.1. Not explained; not relied on (the new colours are pale).

## The new kit (numbers from `export_kit.py`, GLB `design/kits/out/export/ice_kit_v2.glb`, 126 200 bytes)

| Piece | Triangles (was) | Size x, y, height | Checks |
|---|---|---|---|
| Ice_SpikeTall | 150 (34) | 0.306 x 0.264 x 1 | closed, normals out, z min 0, 1 tall, centred |
| Ice_SpikeThick | 230 (56) | 0.755 x 0.607 x 1 | same |
| Ice_Clump | 538 (118) | 0.728 x 0.786 x 1 | same |
| Ice_Block | 64 (96) | 1.070 x 1.020 x 1 | same |
| Ice_Shard | 14 (44) | 0.580 x 0.520 x 1 | same |

GLB: one colour set (COLOR_0, (0.64, 0.79, 0.88) to (1, 1, 1)), NORMAL, POSITION, TEXCOORD_0; Y up, min y 0, max y 1.

## The new Glacier (Look 3), numbers from `check_features.py`

- 23 pieces (1 Clump, 10 SpikeTall, 12 SpikeThick), 4798 triangles (today 1114).
- 29.6 studs wide, 17.6 tall (1.68 : 1; the reference is 2.5 : 1), from 0.4 to 18.2 studs ahead (today -1.5 to
  18.3), nearest ice to the camera 14.3 (today 13.2), to the camera-to-chest line 3.09 (today 2.02).
- 49 blades of 8 studs or longer; leans 3 to 78 degrees, median 36 (reference 4 to 95, median 58).
- Each crystal's yaw is set in the table (fit_yaws.py: the yaw that shows the most ice to the game camera inside
  today's limits), instead of the game's `math.random(0, 359)`.
- What the game code must change for Look 3 (`src/client/Fx/FrostFx.luau`, after the owner's yes): the four ICE
  colours -> (125,162,198) (154,196,225) (182,224,244) (213,239,251); crystal Transparency 0.1 -> 0.25; the
  GLACIER table -> `ice_layout.FLOWER` (with a yaw column); GLACIER_CENTRE 7 -> 8.
