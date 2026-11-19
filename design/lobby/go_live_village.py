"""Switches the game's lobby settings from the cliffside lobby to the fighting village. ONE deliberate step.

    python design/lobby/go_live_village.py            show what would change, write nothing
    python design/lobby/go_live_village.py --apply    do it

DO NOT --apply UNTIL ServerStorage.HT_Lobby.Village is in the place (upload the GLBs, then run
out/village/studio_lobby.luau in Edit mode). Rojo serves this folder into the shared place, so the moment this
runs, the lobby's size, spawn, dummies and invisible collision change in Studio; with no Village model there,
players would stand on the new collision under the old Cliffside model.

What --apply does:
  1. design/game.json: config.Lobby becomes village_config.json (minus its _note).
  2. design/lobby/gen_layout.py: reads out/village/collision.json; its header names village.py.
  3. Runs tools/gen_config.py and design/lobby/gen_layout.py, which rewrite src/shared/Config/GameConfig.luau and
     LobbyLayout.luau.
Then run the gates (rojo build, lune run test, selene src, stylua --check, gen_config --check, gen_layout --check)
and play-test the lobby before saving the place. To go back: git checkout the four files.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
GAME = os.path.join(PROJECT, "design", "game.json")
LAYOUT = os.path.join(HERE, "gen_layout.py")
APPLY = "--apply" in sys.argv


def main():
    game = json.load(open(GAME, encoding="utf-8"))
    village = json.load(open(os.path.join(HERE, "village_config.json"), encoding="utf-8"))
    village.pop("_note", None)
    old = game["config"]["Lobby"]
    assert set(old) == set(village), f"the two Lobby blocks have different keys: {set(old) ^ set(village)}"
    for key in old:
        if old[key] != village[key]:
            print(f"Lobby.{key}: {json.dumps(old[key])[:90]} -> {json.dumps(village[key])[:90]}")
    assert os.path.exists(os.path.join(HERE, "out", "village", "collision.json")), "build the village first (village.py)"
    layout = open(LAYOUT, encoding="utf-8").read()
    swaps = (
        ('os.path.join(HERE, "out", "cliffside", "collision.json")', 'os.path.join(HERE, "out", "village", "collision.json")'),
        ("design/lobby/cliffside.py (Blender) -> design/lobby/out/cliffside/collision.json", "design/lobby/village.py (Blender) -> design/lobby/out/village/collision.json"),
    )
    for a, _ in swaps:
        assert layout.count(a) == 1, f"gen_layout.py no longer has: {a}"
    if not APPLY:
        print("nothing written. Add --apply once ServerStorage.HT_Lobby.Village is in the place.")
        return
    game["config"]["Lobby"] = village
    with open(GAME, "w", encoding="utf-8", newline="\n") as f:
        json.dump(game, f, indent=1, ensure_ascii=False)
        f.write("\n")
    for a, b in swaps:
        layout = layout.replace(a, b)
    open(LAYOUT, "w", encoding="utf-8", newline="\n").write(layout)
    subprocess.check_call([sys.executable, os.path.join(PROJECT, "tools", "gen_config.py")], cwd=PROJECT)
    subprocess.check_call([sys.executable, LAYOUT], cwd=PROJECT)
    print("applied. Run the gates, then play-test the lobby.")


main()
