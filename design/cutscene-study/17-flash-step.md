# 17 - Flash step (kits-8m, 2026-11-19)

The owner: "instead of having a running animation towards the target at the start, i think itd be better if the
player just vanishes and reappears at the location. with some black and white flash step vfx."

## References (read as 12 fps contact sheets around each step)

| Reference | What happens |
|---|---|
| Bleach, "Sonido and Flash Step" (youtube m5Cs8tKWHW8), 2.0-3.0 s and 6.2-7.6 s | The body becomes a motion-blur smear along the move for 1-2 frames, then is simply THERE (often after a cut). Where she stood, a faint horizontal striped streak stays a few frames. The opponent's punch passes through empty space. |
| prodigy, "R6 + R15 Flashstep/Dash" (37ps6jFbFEs), 0.3-1.8 s and 5.3-6.8 s | See-through copies of the body in its skin colour, fading; white wind-streak lines along the path; smoke puffs at the start; the screen blurs and darkens round the edges during the step. |
| Ampro, "Roblox Flashstep Showcase" (lJenQzX2pF0) | The character is too small and the step too fast to see at 480p; only a tiny white spark could be made out. Not used. |

The vault's gap study (`63 VFX Creation/Anime Fight VFX - What the References Do and Where Haymaker Rush Falls Short`)
agrees: in a dash the body is smeared, not copied, and ONE band along the path stays. The old white neon after-images
were rejected ("i dont like the dash vfx").

## What we built (Fx/FlashStepFx, Core/Ultimates)

- Timing: lock-in insert 0-0.6 s (push in on the crouched attacker); cut over the target's shoulder at 0.6 with the aim
  held still; vanish 0.84; gone 0.1 s; reappear 0.94 in front of the target; the hook swings from 0.98 and lands at
  1.14 as before, so nothing later moved.
- Vanish: three black copies of the body with a white rim, stepped toward the target, gone in 0.15 s (the smear); a
  band of five thin lines along the whole path (white, black between) thinning away over 0.3 s; a black puff with a
  white core at the feet. The dash whoosh.
- Gone: the body hidden on every screen (UltimateController, `vanish`), carried to the hook's spot meanwhile.
- Appear: the body flashes white with a black rim (0.1 s); four short lines close in behind it; a small puff.
- Every offset is set in a table, nothing random.

kits-8n, the owner on kits-8m ("not bad"): after the tp the same perspective, zoomed in on where they are now, and a
short pause before the hook lands with the arm still drawing back. Now: cut 0.48, vanish 0.68, reappear 0.78 with the
same camera snapping from FOV 56 to 36 (aimed at the attacker) and pushing to 32; the hook winds back from 0.78 to its
drawn-back pose at 1.07, snaps forward and lands at 1.14. Replay (by script, 0.1x): FOV 56 until 0.78, 36 at 0.80;
HookRight time 0.006 (0.80), 0.038 (0.90), 0.071 (1.01), 0.088 (1.07), 0.178 (1.13), 0.185 contact.

kits-8o, the owner on kits-8n: "the camera is in front of the player instead of behind" and "the player is too close
to the target, they are clipping inside of them during the windup". Measured on the rig, the drawn-back hook at 1.5
studs root to root overlaps the target's body; from 3 studs nothing does. Now they reappear 3 studs out, creep to 2.8
through the pause and lunge to 1.5 on the 0.07 s snap; the camera after the reappear sits behind them over their right
shoulder (attacker space (2.2, 1.8, 5)), FOV 50 to 47, riding along. Replay (0.1x): root to root 2.97 / 2.83 / 2.80 /
2.24 / 1.50 at 0.80 / 0.95 / 1.06 / 1.10 / 1.14; the camera at (2.2, 1.8, 5.0) to (2.0, 1.6, 4.4) in the attacker's
space, aimed at the target; the usual cut at the hit.

kits-8m was checked in a Studio replay by script (screenshots came back black: Studio minimised): at 0.86 the body is hidden and
the 3 copies, 5 lines and the puff exist; at 0.95 the body is back 1.5 studs in front of the target with the flash,
the closing lines and the second puff. No errors in Output. Not yet seen on screen.
