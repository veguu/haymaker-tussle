# Smoke flipbook: the reference and the old sheet (2026-11-21)

Reference: Smile_Dev "VFX Pack 3" (YouTube vw2VJnY1ZZY), 1080p, 60 fps. Sheets in this folder:
`ref_A_overview.png` / `ref_A_puffs_fullres.png` (11.6-12.6 s, 15 fps), `ref_B_overview.png` /
`ref_B_lobes_fullres.png` (13.0-13.55 s, 20 fps, a 640 x 400 crop at full resolution).
Sizes are pixels in the 1080p frame, read off the full-resolution crops (by eye, about +-10 %).

## A, 11.6-12.6 s: the puffs round the charge
Small soft grey smoke behind the violet swirl, 60-120 px puffs, see-through (about a third opaque), curled edges,
NO hard steps: this moment is a soft billow, not the toon look. It drifts and thins over about 0.4 s.

## B, 13.0-13.55 s: the lobed ring (the toon look)
| t (s) | what is there | lobes | tones and edge |
|---|---|---|---|
| 13.00 | one big dome, 250 wide x 210 tall, one lobe behind it; two small lobes to the right (60-90) | 2 + 2 | one flat pale grey, about half opaque; clean edge |
| 13.05 | a cauliflower of 3 merged lobes, 330 wide; lobes 130-200 across | 3 | flat fill; the top edge a touch lighter |
| 13.10 | the same 3 lobes; a lighter RIM band about 15 px along each top edge; the middle starts to clear (about 35 % of the area) | 3 | 2 tones: light rim, grey fill; hollow starting |
| 13.15 | 2 lobes; rims 20-25 px; about 60 % hollow | 2 | rim + faint fill |
| 13.20 | one arch 300 wide: only the rim is left, a band about 35 px | 1 (outline) | 1 tone |
| 13.25 | the arch, band about 25 px, fainter | 1 | |
| 13.30 | the arch about 18 px; small cauliflower clusters upper left: 3-4 round lobes each, 35-60 across | 3-4 per cluster | flat light grey, a slightly darker base, crisp edge |
| 13.35-13.50 | the arch is gone by 13.40; the clusters KEEP their round lobes, shrink a little and fade | 3-4 | same |
| 13.55 | one faint cluster | 3 | nearly gone |

How it dies: big lobes hollow out from the middle (the fill clears, the rim stays, then the rim thins and fades);
small clusters keep their shape and lose size and opacity. Nothing frays into wisps. Whole life about 0.5 s.
Tones: at most 2 flat greys plus the lighter rim; the shadow, where there is one, sits on the underside.
Edge: clean, 1-2 px at 1080p (video compression hides anything finer).

## The old sheet (design/vfx/out/hit_smoke.png, id 97818702295807; `old_sheet_on_dark.png`)
16 frames, 4 x 4. One soft blurred white blob, no lobes, a wide feathered edge (tens of pixels), one smooth tone ramp.
From frame 9 a noise eats holes in it and it frays into wisps; the last frame is still a large ragged shape.
