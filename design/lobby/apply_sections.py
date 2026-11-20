"""Copies the training sections into the lobby's settings, then regenerates GameConfig.

    python design/lobby/apply_sections.py            show what would change, write nothing
    python design/lobby/apply_sections.py --apply    do it

training_sections.json is the ONE source for the training grounds' sections (village.py builds their floors and
sign boards from it). This writes it as `Training` into village_config.json and design/game.json config.Lobby,
copies Depth, TrainingDepth and Sky (the obby's sky leg) from village_config.json, and empties the old `Dummies`
list (every dummy now belongs to a section). Only config.Lobby is touched in game.json. DO NOT put the regenerated GameConfig into the
place before the matching Village model is there (see go_live_village.py for why).
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
GAME = os.path.join(PROJECT, "design", "game.json")
VILLAGE = os.path.join(HERE, "village_config.json")


# Falling petals (LobbyService.spawnPetals): the look. WHERE they fall is out/village/petals.json, written by
# village.py: the blossom canopies. Texture is the project's soft round glow (client Fx/FxKit.Glow), no new upload.
PETALS = {"Enabled": True, "Texture": "rbxassetid://119052464621710", "RatePerStud": 0.38, "Lifetime": 9, "Size": 0.55,
          "Fall": 1.1, "Drift": 0.9, "Colour": "FFD23F", "ColourEnd": "FFF4D6"}


def dump(path, data):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
        f.write("\n")


def main():
    sections = json.load(open(os.path.join(HERE, "training_sections.json"), encoding="utf-8"))
    sections.pop("_note", None)
    village = json.load(open(VILLAGE, encoding="utf-8"))
    game = json.load(open(GAME, encoding="utf-8"))
    lobby = game["config"]["Lobby"]
    spots = json.load(open(os.path.join(HERE, "out", "village", "petals.json"), encoding="utf-8"))
    petals = dict(PETALS, Spots=[{"X": s["u"], "Back": s["d"], "Up": s["h"], "Radius": s["r"]} for s in spots])
    # the obby's sky leg (2026-11-20): its checkpoints, bell, glove and the back wall's gap live in village_config.json
    want = {"Depth": village["Depth"], "TrainingDepth": village["TrainingDepth"], "Dummies": [], "Training": sections, "Petals": petals,
            "Sky": village["Sky"]}
    for key, value in want.items():
        if lobby.get(key) != value:
            print(f"Lobby.{key}: {json.dumps(lobby.get(key))[:70]} -> {json.dumps(value)[:70]}")
    if "--apply" not in sys.argv:
        print("nothing written. Add --apply.")
        return
    for key, value in want.items():
        lobby[key] = value
        village[key] = value
    dump(GAME, game)
    dump(VILLAGE, village)
    subprocess.check_call([sys.executable, os.path.join(PROJECT, "tools", "gen_config.py")], cwd=PROJECT)
    print("applied. Run design/lobby/gen_layout.py after a village build, then the gates.")


main()
