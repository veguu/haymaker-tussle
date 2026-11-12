# Arena maps (Blender)

Three arenas from the user's concept brief (2026-11-09), built by script in Blender 5.2 so they can be
rebuilt and tweaked. All three share the same fighting surface: a flat oval **230 x 190 studs** (the
long axis along X), a **3-stud contrasting rim** flush with it, nothing standing on it, and a drop on
every side. Lighting follows reference image 4 (bright blue sky, soft white clouds, warm sun about 40
degrees up, blue-tinted soft shadows). 1 Blender unit = 1 stud; the surface top is at height 0.

| Map | Backdrop | Signature material | Review sheet |
|---|---|---|---|
| Kitestead | open sky, a few clouds far below, seven tethered kites | timber, every plank end painted red, mustard or green, so the rim is a striped band | `out/kitestead/kitestead_sheet.png` |
| Gnomon Isle | a ring of tree-topped floating islands and a giant sundial landmark | pale stone in cream, sand and blue-grey strata with fractures, under a clover meadow | `out/gnomon/gnomon_sheet.png` |
| Saltcrest | a coastline 700 studs below: sea, hills, road, harbour village, lighthouse, boats | glazed tile in a compass rose, terracotta roof-tile eaves and brick courses | `out/saltcrest/saltcrest_sheet.png` |

Side by side: `out/arenas_compare.png`. Each map folder also has the four renders (gameplay, edge,
recovery from below the rim, overview), the `.blend`, and `glbcheck_*` renders of the exported file
re-imported on its own.

## Visual pass 2 (2026-11-09): painted surfaces

The first export baked each fighting surface into one 1024 texture (4.5 px per stud), so grain,
tiles and leaves were mush at the fighting camera. Now the surface and rim are **painted as real
texture maps** in numpy (`paint.py`), straight from the rules of the material, and exported as they
are, so what Blender shows is what the GLB carries:

| Piece | How | Density | Maps |
|---|---|---|---|
| Fighting surface | 12 flat tiles of 64 studs (`Deck_jk`, `Meadow_jk`, `Plaza_Tiles_jk`) | 16 px/stud | colour, normal, roughness |
| Rim | a strip unwrapped round the oval, 2 pieces (`Rim_*_1`, `_2`), chamfered outer edge | 15-19 px/stud | colour, normal, roughness |
| Recovery-view scenery (beams, lashings, cliff, brick, roof tiles) | cut into 4 wedges, horizontal caps split off, smart-projected, painted from a baked position map, AO multiplied in (tinted) | about 10 px/stud | colour |

- **Kitestead**: boards 6 studs wide, each two to four beam gaps long, joints staggered and always on a
  beam of the frame; own tone and grain per board; knots that bend the grain, shallow splits at cut
  ends, darker end grain at every joint; short boards are lighter replacement planks; nail heads only
  where a board crosses a beam. Rim: 6-stud plank ends painted red, mustard, green over wood, chipped
  back to timber on the exposed corner and joints, sun-bleached on top, end grain through the paint on
  the outer face. Underside: beams with grain along their length and end-grain rings, square rope
  lashings at the outer crossings. Fewer clouds and seven kites.
- **Gnomon Isle**: meadow of overlapping clover (trefoil leaves with pale chevrons), short grass, dry
  tips and dense cool growth, patches 8-15 studs across; white clover heads and buttercups; turf thins
  to soil and pale pebbles in the last few studs. Rim: cut-stone coping blocks with joints, lichen,
  rain streaks. Cliff: thick blocky cream, rounded pitted sand, thin sharp blue-grey shelves standing
  proud, and nine big joints that run through every band and round the facets. Five hazy islands.
- **Saltcrest**: 5-stud handmade tiles, each its own hue and glaze finish, pillowed, glaze pooling at
  the edges, chipped corners showing biscuit, repaired tiles with fresher grout, a few filled cracks;
  whites held at about sRGB 214. Compass rose as crisp shapes cut through the tiles (main points 28
  studs wide at the heart, each split light/dark). Rim: matte terracotta pavers and cream mortar, a
  brick course and salt on the outer face. Eaves: two nesting courses of tapered barrel tiles with
  pale cut ends and a warm shadow under them. Brick: running bond, cream mortar, salt bloom low on
  each step. Coast hazed toward the sky.

Before/after, both from the exported GLB re-imported with the same cameras and sun:
`out/compare_kitestead.png`, `out/compare_gnomon.png`, `out/compare_saltcrest.png` (the old files and
renders are kept in `out/before/`).

## Style pass 4 (2026-11-09): painted low-poly, Gnomon Isle only

The user's brief with three references (stacked stone under a grass cap, a family of stylised trees, a
hollow log): a playful low-poly world with a bright natural base, bold accents, and silhouettes made
only by colour and light (no outlines). Done on Gnomon Isle first, to be judged in game before the
other maps and the lobby follow. The rules and builders are in `style.py`; `gnomon.py` and
`gnomon_sights.py` use them. NOT YET REVIEWED by the user.

- **Turf**: fresh leaf-green, broad warmer and cooler patches with soft but definite edges, clusters of
  two or three painted tufts (three combed strokes over a darker dab) with quiet grass between, a few
  daisies, and four small beds of coral and gold flowers at the ends of the axes (the east one under
  the sundial). The middle 30% has almost nothing on it.
- **Grass cap**: the rim (`Rim_Turf_*`, was `Rim_Stone_*`) is turf with a lighter lip, a bright line on
  the very edge, and a deep green skirt 4 studs deep hanging in a wavy line over the stone. The
  playable edge, the flat top and the collision are unchanged (230 x 190, top at 0, 14 pieces).
- **Cliff**: seven layers of chunky blocks (`style.chunk_band`): each block a flat chord set in by its
  own amount, creased part-way down, leaning its own way. Cream, blue-grey, sand, two or three painted
  tones each, no grain or pits. Never outside the oval.
- **Timber**: `Cliff_Timber`: at five places, two beam ends, a ledger and a brace set into the cliff
  under the cap. Honey on top, darker underneath, a few long strokes, pale cut ends with a darker rim.
- **Plants**: a family of four (`twin`: leaning trunk, two round crowns; `tiered`: tall tapered stack;
  `umbrella`: wide flat crown; `bush`). Crowns are smooth-shaded and painted as one volume, light top to
  deep underside. Most are green; "bloom" crowns (gold to coral) carry the accent.
- **Scenery**: four garden islets 100+ studs past the rim (grove NE, hollow log SW, tall pair W,
  pennant frame N), two far islands, the sundial with coral bands and hour marks and a gold edge, the
  balloon fair recoloured to coral, mustard and cream (teal dropped). Accents are coral and gold only.
- **Changed readability rule**: the garden islets float level with the deck or up to 11 studs above
  it, and their trees reach about 55 above the deck, so each reads as its own island; the old rule was
  20 studs within 200. Sky stays open between them.
- **Exporter fix**: single-colour props were written to PNG as linear numbers, so they came out darker
  and harsher in the GLB (all three maps, since pass 3). `export_roblox.py` now writes sRGB.
  Kitestead and Saltcrest still need a re-export to pick this up.
- **Studio check without an upload**: `studio_preview.py` packs a GLB, the 3D-model skill's
  `serve_assets.py` serves it on localhost, and `studio_preview.lua` rebuilds it in Edit mode as
  session-local MeshParts (colour only). The official Studio assistant MCP refuses localhost; the
  other Studio bridge (`executeLuau`) allows it. Four cloud meshes are wider than Roblox's 2048-stud
  mesh limit and are skipped there: they need splitting before a real import.
- Review sheet: `out/style_gnomon.png` (`py style_sheet.py gnomon`). The map before this pass is kept
  in `out/before_style/`. Fast look: `blender -b --factory-startup -P gnomon.py -- out/gnomon_fast
  --fast --cams=Gameplay,Meet` (quarter-size textures, about 2 minutes).

## Gnomon rework b (2026-11-10): doubled, no grass, shade 9, obstacles

User brief, Gnomon only. Kitestead and Saltcrest are untouched (their oval stays `common.ORIGINAL_OVAL`).

- **Size, once**: `common.OVALS["gnomon"] = (213, 176)` semi-axes, 426 x 352 studs, written as absolute
  numbers; the original 106.5 x 88 is `common.ORIGINAL_OVAL`. `gnomon.py` sets `HT_MAP=gnomon` before
  importing `common`; `rebuild.sh` exports it for the export and check steps; `check_glb.py` takes it from the
  GLB's name. The game's copy is `MapEnvironments.gnomon.arena`.
- **Island**: 1.5x as deep (`DEPTH`); block counts follow the perimeter; insets, recesses, the timber and the
  turf lip are in studs from the edge (`k()`), so the stone keeps its sizes.
- **Ground**: no 3D grass, painted blades, dabs or meadow flowers. Meadow, rim top, lip and islet caps are
  shade 9 of the user's matcha reference (sampled about sRGB 12, 25, 7; `style.PAL` leaf 16, 38, 10), solid and
  matte with broad gentle shifts and a darker footing under each obstacle. The rim keeps a lighter mossy line.
  Surface tiles are 128 studs at 4 px a stud (still 12 pieces + 2 rim).
- **Obstacles**: `obstacles.py` (plain Python) lays out 20 rocks, slabs and stumps in 15 groups and checks the
  rules (open middle, 8 studs off the spawn oval at any turn, 26 studs off the edge, 24 studs between groups,
  rocks in a group touch or leave 6+); `python obstacles.py` writes `src/shared/Config/MapObstacles.luau`. The
  meshes are `Obstacles_Stone` / `Obstacles_Wood` (never collide); MapService adds one upright Cylinder collider
  per item, frictionless.
- **Backdrop**: `push_backdrop` moves every cluster out by how far the rim moved at its bearing (nothing
  scaled). Lobby corridor (`detail.LOBBY_VIEW`) widened for the moved lobby.
- **Balloons**: `sights.balloon` has a load ring at the mouth, ropes ending on it, and the burner on a frame
  tied to the ropes; the launch field's ropes run from the tipped basket's real corners to the mouth.
- **Checks**: `check_scene.py` (run on the .blend) lists loose pieces, clashing clusters, balloons whose bob
  reaches something, and buried or floating obstacles.
- **Upload**: `export_roblox.py` also writes `out/<map>/upload/<map>_1.glb` (arena) and `_2.glb` (backdrop)
  under the 20 MB limit, and `<map>_centres.json` (each mesh's expected centre) to align the halves in Studio.

## Gnomon dressing (2026-11-11): scenery kit, grass, central pond

User brief with four references, Gnomon only.

- **Kit** (`props_kit.py` -> `out/gnomon/props/gnomon_props.blend`): 11 rocks, 4 ruins, 5 trees, 6 bushes, 6 leafy
  plants, 6 flower clusters, lily pads and a lotus, in the boulder reference's treatment (cut-plane chunks, bevelled
  edges that catch the light, a tone per facet, occlusion). Every foliage piece has a wind rig and a 4-second loop
  (`rig_all`); rocks, ruins, water and stone never move. `props_review.py` renders a sheet per family.
  `export_kit.py` writes `out/gnomon/upload/kit_*.glb` (rest pose) and `kit_manifest.json`.
- **Palette**: image 4's green, about (64, 120, 74) overall, for every foliage key; the ground is a deeper green of
  the same family (gnomon.py `build`).
- **Map dressing** (`gnomon_dress.py`, called by gnomon.py's build): the pond's basin carved into the two middle
  floor tiles on a 2-stud grid (`POND`, the same numbers as MapEnvironments.gnomon.pond and Core/Pond), its water,
  grass from the kit's six plants as low-poly scatter merged into `Grass_Scatter_*` chunks (one atlas texture;
  GrassWind sways their tips in game), and `placements.json`: shore rocks in four arcs with wide openings, lilies,
  small boulders, sparse flowers, and the islands' plants (the old procedural trees are recorded and replaced by
  kit trees, with bushes, plants and flowers round them, plus ruins and big rocks). The Blender scene shows the
  placements in collection Dressing (never exported).
- **Studio** (`studio_dress.py` -> `studio_map.luau`, `studio_dressing.luau`): joins the uploaded halves as
  HT_Maps.Gnomon and clones the kit (ServerStorage.HT_PropKit) into its HT_Dressing folder.

## Files

- `common.py`: the shared oval, sky, sun, clouds, cameras (Gameplay, Floor, Edge, Recovery, Overview),
  renders and Roblox checks.
- `paint.py`: numpy noise, hashing, colour and map writing (normal maps are OpenGL; roughness sits in
  the green channel of a glTF metallic-roughness image).
- `surfaces.py`: the tiled surface, the strip-unwrapped rim, splitting scenery into wedges and caps,
  and painting it from baked position, normal and AO.
- `kitestead.py`, `gnomon.py`, `saltcrest.py`: one map each, painters included.
- `style.py`: the pass-4 style: palette, chunky stone, timber, islets, the plant family, and the
  painters for stone, wood, grass caps and crowns.
- `studio_preview.py`, `studio_preview.lua`, `style_sheet.py`: the no-upload Studio look and the
  pass-4 review sheet.
- `rebuild.sh <map>`: the whole chain: build and paint, Floor render, export, re-import check renders.
  A map takes about 10-20 minutes (the meadow is the slowest).
- `render_views.py`: renders chosen cameras of a built `.blend`.
- `export_roblox.py`: painted meshes go out as they are (colour, normal, roughness, with tangents);
  anything still procedural is baked as before. Writes the GLB and `manifest.json`.
- `check_glb.py`: re-imports a GLB into an empty scene and renders Gameplay, Floor and Recovery.
- `compare.py`: the before/after sheets (system Python with Pillow).
- `show.py`: opens a built map in Blender's window through the gameplay camera.

## Checked

- Every mesh: under 20,000 triangles, one material, one UV set (`all_within_limits: true` for all three).
- The surface and rim tops are exactly flat at 0 (every upward face), 14 pieces per map; the
  re-imported GLB spans 230 x 190 with its top at 0.
- After re-import, 14 materials per map still carry their normal maps (12 tiles + 2 rim pieces), so
  the normal and roughness maps survive the GLB round trip.
- Readability: no scenery rises above the rim within 60 studs; kites stay at least 55 studs under the
  deck; the strata never reach outside the oval; the eaves stay below the surface.
- GLB sizes: Kitestead about 29 MB, Saltcrest about 33 MB, Gnomon about 70 MB (the meadow's colour
  maps are noisy PNGs). NOT checked: whether Roblox's importer takes a file that size, and that it
  builds a SurfaceAppearance from the normal and roughness maps (its docs say glTF PBR maps are
  imported that way). If either fails, export the colour maps as JPEG (`export_image_format`).
- Texture budget per map: 12 surface tiles x 3 maps + 2 rim x 3 at 1024, plus about 20 colour maps
  for scenery. Fine on PC; on phones, halve the surface normal and roughness maps first if memory is
  tight.

## Putting one in Roblox (not done yet)

1. Studio: **File > Import 3D**, pick `out/<map>/export/<map>.glb`. Import as one model, keep the
   textures, upload under the **group** that owns the game (the game is group-owned).
2. Set every part `Anchored = true`. `CanCollide` per `manifest.json`: only the surface tiles and rim
   pieces collide (`Deck_*` + `Rim_PaintedEnds_*`, `Meadow_*` + `Rim_Stone_*`, `Plaza_Tiles_*` +
   `Rim_Terracotta_*`). Check one imported part has a SurfaceAppearance with colour, normal and
   roughness maps. Everything
   else is scenery: `CanCollide = false`, `CanQuery = false`, `CanTouch = false`. Saltcrest's
   `Eaves_RoofTiles_*` must not collide, or players could stand on them past the edge.
3. Place it so the surface top is at the arena's height (`Arena.CenterY` = 100) and its centre at
   (`Arena.CenterX`, `Arena.CenterZ`) = (0, 0). glTF is Y-up, so Blender's Y becomes Roblox's -Z; the long
   axis stays on X.
4. Code to change with it: the arena is still treated as a circle of radius 105 (`Arena.StartRadius`,
   `Core/Round.isOut`, the spawn ring, `TestFloorService` builds a round floor). With an oval map, turn
   the test floor off and make the out-of-bounds check and spawns use the 115 x 95 semi-axes. The
   current fall line (`EliminationDepth` 30 under the surface) is above Kitestead's and Gnomon's lowest
   scenery and far above Saltcrest's landscape, which is fine: it only decides when you're out.
