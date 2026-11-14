# Haymaker Tussle - research notes

Quick check on 2026-11-03, for problems only. The brief's design was not reopened. These come from search result summaries, not full reads.

## Findings
- **Slap Battles** is the closest Roblox game: gloves with abilities, knocking rivals off platforms. Every source found was a low-quality page, so these details are **unverified**.
- **Super Smash Bros** is the classic model for damage raising launch distance. SmashWiki describes base knockback plus a designed scaling value. A DevForum thread says the target's percent is often counted after the hit. This game deliberately uses the value from before the hit.
- **Fling risk:** players own their own characters by default, and DevForum threads describe cheaters changing their own velocity to launch people through collisions. Turning off player collisions stops it, but needs another way to do contact. This shaped the bump decision.
- **Knockback:** threads weigh a client-applied impulse (responsive, but a cheat can ignore it) against moving ownership to the server (safer, less responsive). The vault's Combat Systems Architecture note says the server decides and the owner applies.

## What changed because of this
Only one thing: players don't solid-collide, and bumps are server-decided (see `decisions.player_collisions` in `game.json`). To be judged by feel in step 3.

## Sources
- [SmashWiki: Knockback](https://www.ssbwiki.com/KB)
- [DevForum: How to calculate knockback like Super Smash Bros](https://devforum.roblox.com/t/how-to-calculate-knockback-like-super-smash-bros/1265611)
- [DevForum: Cheaters throw players off the map](https://devforum.roblox.com/t/cheaters-throw-players-off-the-map/4465570?page=2)
- [DevForum: Exploiters able to fling other players](https://devforum.roblox.com/t/exploiters-able-to-fling-other-players-on-a-game-i-help-to-develop-collisions-are-off/3305514)
- [DevForum: How do I handle knockbacks](https://devforum.roblox.com/t/how-do-i-handle-knockbacks/3480344)
- [Slap Battles summary (low-quality source)](https://docs.thebrandindustry.com/news/slap-battles-roblox-6615929)

## Lobby study (2026-11-13)

For the cliffside lobby. NOT played: none of these games could be opened from here, so this is from written guides found by web search, which describe what is in each lobby far better than how it is laid out. Treat layout details as approximate.

- **Blade Ball** (inspected: two how-to guides and a spin-wheel guide). The waiting lobby overlooks the playing arena; getting hit sends you back to it, where you watch the rest of the round and wait for the next; a timer at the top shows when. Stations sit round the lobby rather than in the middle: crates, a spin wheel you use by walking into a marked ring, an AFK zone, portals. Whether the arena is below the lobby was not stated anywhere.
- **Rivals** (inspected: beginner guides and a shooting-range guide). A hub with a big leaderboard screen, a shop, and a practice range with dummies where new players are sent first; queue pads grouped by mode in their own lanes.
- **The Strongest Battlegrounds, Untitled Boxing Game, Death Ball**: searched, nothing usable about their lobbies came back.

Lessons taken: the lobby faces the arena and the edge is the viewing spot; stations go round the outside so the middle stays open for gathering; one big readable landmark per station; practice is a separate corner new players can find; nothing needs a long walk. Nothing was copied: the layout here (three terraces stepping down to the arena) is not from any of them.

Sources: [Blade Ball how to play](https://allthings.how/roblox-blade-ball-how-to-play-full-guide/), [Blade Ball tips](https://dotesports.com/roblox/news/roblox-blade-ball-how-to-play-tips-and-tricks), [Blade Ball spin wheel](https://www.gamezebo.com/walkthroughs/blade-ball-instant-spin/), [Rivals beginner guide](https://bloxodes.com/articles/rivals-beginner-guide), [Rivals shooting range](https://pixeltwelve.com/guides/roblox-rivals-shooting-range-test-weapons)

### Three concepts (all: cliffside courtyard, above the arena, golden hour, compact)
1. **Stepped Overlook** (BUILT): three terraces stepping down toward the arena. Balcony on the edge, court behind it, training at the back under a gate. Best sightlines (each level sees over the one in front), straight short routes, and it keeps the rectangle every system already uses (spawns, walls, barrier, bots).
2. **Ring Court**: a round court about a central tree, stations round the rim, the arena seen through one opening. Strong gathering space, but most of the rim faces away from the arena.
3. **Switchback Ledges**: small ledges joined by a zig-zag cliff path, one station each. The most "cliff", but long routes, narrow paths for 25 players, and bad for spawns and bots.
