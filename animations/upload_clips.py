"""Uploads animations/export/*.rbxm to Roblox under the group that owns the game, and writes the ids into
src/shared/Config/AnimAssetIds.luau. Run animations/export_clips.py first.

    python animations/upload_clips.py --check          is the key there? uploads nothing
    python animations/upload_clips.py --one            uploads one clip, to prove the route works
    python animations/upload_clips.py                  uploads every clip that doesn't have an id yet
    python animations/upload_clips.py --redo Guard Land   uploads these again, as new assets

The key comes from the ROBLOX_API_KEY environment variable and is never printed. It needs Assets read and write,
and it has to be a key made under the group, since the assets have to belong to whoever owns the game.
Progress is saved after every clip, so a failure partway loses nothing: just run it again.
"""

import argparse
import json
import os
import sys
import time

import requests

GROUP_ID = "2970443"  # game.CreatorId of the place: it's group-owned
ASSETS_URL = "https://apis.roblox.com/assets/v1/assets"
OPERATION_URL = "https://apis.roblox.com/assets/v1/"
HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export")
RECORD = os.path.join(HERE, "uploaded.json")
CONFIG = os.path.join(HERE, "..", "src", "shared", "Config", "AnimAssetIds.luau")
PACE_SECONDS = 1.0  # between clips, to stay well under the rate limit


def api_key():
    key = os.environ.get("ROBLOX_API_KEY")
    if not key and sys.platform == "win32":
        # A variable set after this terminal or session opened is only in the registry.
        import winreg

        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as env:
                key = winreg.QueryValueEx(env, "ROBLOX_API_KEY")[0]
        except OSError:
            key = None
    return key


def load_record():
    if os.path.exists(RECORD):
        with open(RECORD, encoding="utf-8") as file:
            return json.load(file)
    return {}


def save(record):
    with open(RECORD, "w", encoding="utf-8") as file:
        json.dump(record, file, indent=1, sort_keys=True)
    lines = [
        "--!strict",
        "-- GENERATED FILE - DO NOT EDIT BY HAND. Source: animations/upload_clips.py",
        "-- The uploaded animation asset for each clip in AnimClips. They're owned by the group that owns the game.",
        "local AnimAssetIds: { [string]: number } = {",
    ]
    lines += [f"\t{name} = {record[name]}," for name in sorted(record)]
    lines += ["}", "", "return AnimAssetIds", ""]
    with open(CONFIG, "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines))


def upload(name, key):
    with open(os.path.join(EXPORT, name + ".rbxm"), "rb") as file:
        data = file.read()
    request = {
        "assetType": "Animation",
        "displayName": f"HT_{name}",
        "description": "Haymaker Tussle combat animation.",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    files = {
        "request": (None, json.dumps(request), "application/json"),
        "fileContent": (name + ".rbxm", data, "model/x-rbxm"),
    }
    for attempt in range(5):
        response = requests.post(ASSETS_URL, headers={"x-api-key": key}, files=files, timeout=120)
        if response.status_code != 429:
            break
        time.sleep(2 ** (attempt + 2))
    if response.status_code >= 400:
        sys.exit(f"{name}: upload refused, {response.status_code}: {response.text[:400]}")
    body = response.json()
    operation = body.get("path") or ("operations/" + body.get("operationId", ""))
    # Accepted isn't finished: the id only exists once the operation completes.
    delay = 1.5
    for _ in range(40):
        time.sleep(delay)
        delay = min(delay * 1.4, 10)
        poll = requests.get(OPERATION_URL + operation, headers={"x-api-key": key}, timeout=60)
        if poll.status_code == 429:
            continue
        if poll.status_code >= 400:
            sys.exit(f"{name}: checking the upload failed, {poll.status_code}: {poll.text[:400]}")
        state = poll.json()
        if state.get("done"):
            if "error" in state:
                sys.exit(f"{name}: Roblox rejected it: {json.dumps(state['error'])[:400]}")
            result = state.get("response", {})
            moderation = result.get("moderationResult", {}).get("moderationState", "unknown")
            return int(result["assetId"]), moderation
    sys.exit(f"{name}: still processing, operation {operation}. Run this again later.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--one", action="store_true")
    parser.add_argument("--redo", nargs="*", default=[])
    args = parser.parse_args()

    names = sorted(f[:-5] for f in os.listdir(EXPORT) if f.endswith(".rbxm"))
    record = load_record()
    key = api_key()
    if args.check:
        print(f"key: {'set' if key else 'NOT set'}; clips exported: {len(names)}; already uploaded: {len(record)}")
        return
    if not key:
        sys.exit("ROBLOX_API_KEY isn't set.")

    for name in args.redo:
        record.pop(name, None)
    to_do = [name for name in names if name not in record]
    if args.one:
        to_do = to_do[:1]
    for index, name in enumerate(to_do):
        asset, moderation = upload(name, key)
        record[name] = asset
        save(record)
        print(f"{index + 1}/{len(to_do)} {name}: {asset} ({moderation})")
        time.sleep(PACE_SECONDS)
    print(f"done: {len(record)} of {len(names)} clips have ids")


if __name__ == "__main__":
    main()
