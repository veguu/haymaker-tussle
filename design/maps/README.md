# Arena maps (Blender)

Three arenas from the user's concept brief (2026-11-09), built by script in Blender 5.2 so they can be
rebuilt and tweaked. All three share the same fighting surface: a flat oval **230 x 190 studs** (the
long axis along X), a **3-stud contrasting rim** flush with it, nothing standing on it, and a drop on
every side. Lighting follows reference image 4 (bright blue sky, soft white clouds, warm sun about 40
degrees up, blue-tinted soft shadows). 1 Blender unit = 1 stud; the surface top is at height 0.

| Map | Backdrop | Signature material | Review sheet |
|---|---|---|---|
| Kitestead | open sky, three tiers of cloud far below, tethered kites | timber, every plank end painted red, mustard or green, so the rim is a striped band | `out/kitestead/kitestead_sheet.png` |
| Gnomon Isle | a ring of tree-topped floating islands and a giant sundial landmark | pale stone in cream, sand and blue-grey strata with fractures, under a clover meadow | `out/gnomon/gnomon_sheet.png` |
| Saltcrest | a coastline 700 studs below: sea, hills, road, harbour village, lighthouse, boats | glazed tile in a compass rose, terracotta roof-tile eaves and brick courses | `out/saltcrest/saltcrest_sheet.png` |

Side by side: `out/arenas_compare.png`. Each map folder also has the four renders (gameplay, edge,
recovery from below the rim, overview), the `.blend`, and `glbcheck_*` renders of the exported file
re-imported on its own.

## Files

- `common.py`: the shared oval, rim, sky, sun, clouds, cameras, renders and Roblox checks.
- `kitestead.py`, `gnomon.py`, `saltcrest.py`: one map each. Rebuild (and render) with
  `blender -b --factory-startup -P kitestead.py -- <out folder>` (add `--no-render` to skip renders).
- `export_roblox.py`: bakes every mesh's colour to a PNG and writes one GLB per map plus
  `manifest.json`. `blender -b --factory-startup out/kitestead/kitestead.blend -P export_roblox.py -- out/kitestead/export kitestead`
- `check_glb.py`: re-imports a GLB into an empty scene and renders it.

## Checked

- Every mesh: under 20,000 triangles (largest 12,800), one material, one UV set
  (`manifest.json` `all_within_limits: true` for all three).
- The surface and rim are exactly flat (top at 0) and the re-imported GLB spans 230 x 190 with the rim.
- Readability: no scenery rises above the rim within 60 studs; Kitestead's kites stay at least 50 studs
  under the deck so they never cross the rim line; Gnomon's strata never reach outside the oval (no
  ledges); Saltcrest's eaves overhang below the surface.

## Putting one in Roblox (not done yet)

1. Studio: **File > Import 3D**, pick `out/<map>/export/<map>.glb`. Import as one model, keep the
   textures, upload under the **group** that owns the game (the game is group-owned).
2. Set every part `Anchored = true`. `CanCollide` per `manifest.json`: only the surface and rim collide
   (`Deck` + `Rim_PaintedEnds`, `Meadow` + `Rim_Stone`, `Plaza_Tiles` + `Rim_Terracotta`). Everything
   else is scenery: `CanCollide = false`, `CanQuery = false`, `CanTouch = false`. Saltcrest's
   `Eaves_RoofTiles` must not collide, or players could stand on them past the edge.
3. Place it so the surface top is at the arena's height (`Arena.CenterY` = 100) and its centre at
   (`Arena.CenterX`, `Arena.CenterZ`) = (0, 0). glTF is Y-up, so Blender's Y becomes Roblox's -Z; the long
   axis stays on X.
4. Code to change with it: the arena is still treated as a circle of radius 105 (`Arena.StartRadius`,
   `Core/Round.isOut`, the spawn ring, `TestFloorService` builds a round floor). With an oval map, turn
   the test floor off and make the out-of-bounds check and spawns use the 115 x 95 semi-axes. The
   current fall line (`EliminationDepth` 30 under the surface) is above Kitestead's and Gnomon's lowest
   scenery and far above Saltcrest's landscape, which is fine: it only decides when you're out.
