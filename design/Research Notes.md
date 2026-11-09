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
