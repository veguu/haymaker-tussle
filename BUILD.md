# Haymaker Tussle - build checklist

One core loop. Every stage has an exit criterion that can be checked, not
eyeballed. A stage is not done because it produced files; it is done because its
criterion passed.

| # | Stage | Exit criterion | Done |
|---|---|---|---|
| 0 | preflight | every REQUIRED row green | [ ] |
| 0b | save the place | `place_state.py` says SAVED. **File > Save to File As, NEVER Ctrl+S** (that publishes) | [ ] |
| 1 | research | a findings file naming the genre, with sources that were opened | [ ] |
| 2 | design | `validate.py` passes: no TODO left, every referenced spec exists | [ ] |
| 3 | code | `roblox-code/scripts/check.py` all four gates green | [ ] |
| 4 | map | the prover returns PASS, not UNVERIFIABLE | [ ] |
| 5 | meshes | Not used: the brief asks for simple geometry and placeholder materials | n/a |
| 6 | ui | mockup PNG and .model.json emitted from the same tree | [ ] |
| 7 | animation | verification renders exist AND were looked at | [ ] |
| 8 | vfx | phase-frozen captures for every effect | [ ] |
| 9 | sfx | roles filled == roles requested, zero unfilled | [ ] |
| 10 | assembly | build stamp in Output, no duplicate modules, map + assets placed | [ ] |
| 10b | **wiring** | `verify_wired.py` green on the STATIC and the LIVE pass. Nothing generated is still a placeholder | [ ] |
| 11 | playtest | a human played it and reported back | [ ] |
| 12 | publish | place published and joinable | [ ] |

Re-save the place (File > Save to File) at every stage boundary. An unsaved
place cannot be reopened after a crash, and Studio does crash.

Stages 4 to 9 are the asset block and are mutually independent. They are the only
part of this list that may be fanned out to parallel workers (the default; see the
create-roblox-game skill). Stages 10 to 12 are single-threaded by law: one thread
touches Studio.

## Ledger

Every run is logged from the start, not reconstructed afterwards:

```
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py init --run HaymakerTussle --mode fanout
```
