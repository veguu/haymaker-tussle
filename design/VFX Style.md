# Haymaker Tussle VFX style: "Gustline"

STATUS: ON HOLD. The user tried build gust-2 on 2026-11-13 and did not like it. Their decision: drop the stylistic ideas for now (ink strokes, kit colours, the house "style") and first practise making one-to-one replicas of the reference effects, entirely out of particles, studied at 24 fps or more. Do NOT build more effects to this sheet until they say so. Details and their words: the vault handoff `_Session Handoffs/2026-11-13 - Haymaker Tussle endlag, Tempest, Coins and VFX.md`.

Earlier status: direction approved by the user 2026-11-13, then CORRECTED by them the same day: the first version was flat, solid-coloured and had too few layers. This is the corrected sheet (build gust-2). Every effect in the game is built to it, and existing ones are brought to it.

The user's correction, in their words: effects should be "glowy neon", "transparency is necessary", "each move has a LOT of different particles, more than just 5 or so", "all kinda transparent (... some are solid but this is usually just a few out of a bunch more glowing particles, kinda like a outline or highlight or some texture)", "very bright and highly animated with lots of tweens, curves, and size difference that changes with time".

The principles are in the vault: `07 Lighting VFX and Audio/VFX Reference Study - Why Good Combat VFX Reads, and Building a House Style.md` (read its section 0). This sheet is the game-specific part.

The idea in one line: **everything is wind lit up: many thin, see-through, glowing layers that never hold still, with a few ink strokes through them.**

## 1. Rendering rules (the corrected part)

1. **Glow.** Layers are additive particles (`LightEmission` 1): they add light. The white-hot middle comes from layers overlapping, not from white paint.
2. **Many layers.** A hit is about 14 layers, a ring 6, a swing 5. Under about 8 for a hit is not enough.
3. **See-through.** Every glowing layer starts partly transparent and fades out. Nothing glowing is an opaque card.
4. **A few solid pieces.** One to three layers of a move are solid and dark (Ink): speed lines along a hit, the ink-edged arc under a swing, a soft dark pool behind a burst, the floor scuff. They are the contrast the light reads against.
5. **Always moving.** Every layer changes size over its life on a curve (fast at first, settling), and most turn. The flare starts at its largest and collapses; rings race out and slow; arcs spin; the swing's layers each sweep in a little later than the one before, so it smears. No layer appears, sits and disappears.
6. **Big and brief.** The hot frame of a hit is several characters wide for about 0.1 s. What is left after is thin and lingers up to a second.

Two limits found while building it:
- **White blob.** Stacked bright white layers wash out the colour. Only one small core is white; the rest are the colour, or a paler shade of it, and big layers are dimmer than small ones.
- **Bright ground.** Glow can only brighten what's behind it, so it nearly vanishes on the pale lobby sand and against the sky. The dark underlay and the ink pieces are there for that. It is still weaker on the lobby floor than on the arena grass.

## 2. Palette roles

| Role | Colour (RGB) | Where it goes |
|---|---|---|
| **Core** | 255, 255, 255 | The small white-hot middle of a burst only |
| **Wind** | 120, 190, 255 | What plain wind glows as: a punch, a dash, anything without a kit accent |
| **Accent** | one per kit, below | Heavy moves and finishers glow in their kit's colour |
| **Body** | 176, 205, 236 and 226, 238, 252 | Smoke and puffs (the old pale wind blues) |
| **Ink** | 20, 30, 66 (deep navy, never grey or black) | The few solid pieces: speed lines, the arc's edge, the underlay, floor scuffs |

Accent per kit, so a move's colour says whose kit it is:

| Kit | Accent (RGB) |
|---|---|
| Base | 255, 196, 72 (gold) |
| Tempest | 96, 232, 196 (mint) |
| Bruiser | 255, 112, 64 (ember) |
| Trickster | 176, 120, 255 (violet) |

One hue per effect, plus white and ink. Never two accents in one effect.

## 3. The shape kit (build only from these)

1. **Flare**: a hot middle with four long thin rays and four short ones. The flash of a hit.
2. **Gust crescent**: a tapered arc, thick at the leading end, thin to nothing behind. A swing; also the thin arcs that spin off a hit and keep turning on the floor.
3. **Gust ring**: a thin bright ring, uneven and broken at one side, in a soft halo. Standing across a hit or a dash; lying on the floor.
4. **Burst ring**: a ring made of short outward strokes, like a splash seen from above. On the floor under a hit, and round a dash ring.
5. **Mote**: a small diamond (not a round sparkle). Thrown along the hit, drifting up. Diamonds are this game's spark.
6. **Soft glow**: a round soft light. Halo, pool of light on the floor, the white core, and (tinted Ink, not additive) the dark underlay.
7. **Puff / smoke**: the soft wind cloud, low round the feet.
8. **Scuff**: an ink mark on the floor that stays 1 to 2 seconds after the light.

## 4. Assembly

- **Hit** (GustBurst.hit, 14 layers): dark underlay, white core, flare, halo, spikes, two shock rings standing across the hit turning opposite ways, a ring facing the camera, spinning arcs, motes, ink speed lines; and on the floor a burst ring, a glow ring, a pool of light, smoke, and arcs that keep turning.
- **Swing** (GustBurst.swing, 5 layers, 7 for the Cyclone): an ink-edged arc under a pale hot core arc, a coloured body arc and a wide faint trail arc, each sweeping in later and growing more than the one before, plus motes thrown off the bow.
- **Ring** (GustBurst.ring, 6 layers): bright ring, coloured ring turning the other way, burst ring, soft glow, a ring facing the camera, motes thrown back.

## 5. Tiers

| Tier | Moves | Colour | Scale | Leaves a scuff | Camera |
|---|---|---|---|---|---|
| 1 Light | punch, dash, jump, bump | Wind | hit 0.72 | no | none |
| 2 Heavy | launching kick, Uppercut, Cyclone, Blink, dive kick | kit accent | hit 1.15, more of every layer | yes | small kick |
| 3 Finisher | air kick slam, ring-out, clash win | kit accent | two big floor rings | yes, with cracks | shake, zoom |

A miss shows the swing and nothing else.

## 6. Never

- Never tint, cover or outline a character (the short white hit flash is the only exception).
- Never a solid flat-coloured shape as the main body of an effect. Solid is for the few ink pieces.
- Never a layer that doesn't change size or turn.
- Never several large bright white layers on top of each other.
- Never grey or black for the dark; it's the navy ink.
- Never sparks thrown evenly all round when the hit has a direction.
- Never an effect that can collide, block a ray or affect gameplay.

## 7. Where the game is today (build gust-2, 2026-11-13)

Built to the sheet:
- Every swing's crescent; the Cyclone's goes round with the body, two arcs across from each other.
- Every hit (GustBurst.hit), plain or heavy, with a scuff after a heavy one.
- Dash ring; Blink's closing and opening rings in the kit's accent.
- Floor slams (air kick, dive kick): two gold floor rings and a scuff, on top of the old blast.

Not yet brought to the sheet:
- The floor slam's blast (ImpactFx.groundBlast) is still the old gold-and-fire explosion with grey smoke.
- Puffs, the fist trail, the dash's speed lines and after-images still use the old look.
- Bump puff, clash effects, jump push-off, ring-out: untouched.
- No gather phase (wisps drawing in before a heavy move).
- The swing's arcs are see-through plates, not additive, so they glow less than the hits do.
- Phones: fewer particles and one less swing layer, not tested on a device.
- A swing's clip and its effect are not matched frame for frame; do that with the animation pass.

## 8. Building notes

- Textures: `design/vfx/draw_gustline.ps1` draws them into `design/vfx/out/` (PowerShell and System.Drawing; this PC has no Python). The glow set is white and soft-edged, for additive particles. Upload with Studio's `upload_image` through a localhost file server. Ids, palette and accents live in `src/shared/Config/GustStyle.luau` and nowhere else.
- `src/client/Fx/GustBurst.luau`: the particle effects (hit, ring) and the swing. Pooled rigs; nothing created per effect.
- `src/client/Fx/GustFx.luau`: flat plates (the swing's arcs, the scuff). Use a plate whenever a shape has to POINT somewhere: a flat particle (`VelocityPerpendicular`) can be put in a plane, but which way it faces within that plane changes with the plane's tilt, so it suits rings (which look the same any way round) and not crescents.
- To look at an effect: emit it, wait a set time, set `TimeScale = 0` on every GustBurst emitter (build every pooled rig first, or the new ones run at full speed), then screenshot. For plates, give the swing a long `seconds`.
- Audit each effect on the arena grass AND the lobby sand.
