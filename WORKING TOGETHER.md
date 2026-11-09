# Working together on Haymaker Tussle

The code lives in this Git repo. Studio only gets a copy of it through Rojo, and Rojo copies ONE way:
files on disk -> Studio. It never copies Studio edits back to the files.

## What Rojo controls (never edit these in Studio)

| In Studio | Comes from |
|---|---|
| ReplicatedStorage.Shared | `src/shared` |
| ServerScriptService.Server | `src/server` |
| StarterPlayer.StarterPlayerScripts.Client | `src/client` |
| ReplicatedStorage.Packages | `Packages` (made by `wally install`) |

Any edit made to these in Studio is wiped the next time anyone syncs. Edit the files instead.
Everything else in the place (the map, parts in Workspace, Lighting, StarterPlayer settings) lives
only in the Team Create place and is kept when you save or publish it.

## One-time setup

1. Install Git for Windows: https://git-scm.com (defaults are fine).
2. Install Aftman (https://github.com/LPGhatguy/aftman), then accept the GitHub repo invite.
3. Get the code and the tools:
   ```
   git clone <repo url> "Haymaker Tussle"
   cd "Haymaker Tussle"
   aftman install
   wally install
   ```
   `wally install` makes the `Packages` folder. It isn't in Git, so it's needed after every fresh clone
   and whenever `wally.toml` changes.
4. Tell Git who you are (once per computer):
   ```
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```
5. In Studio, install the Rojo plugin (version 7.4.x, to match `aftman.toml`).

## Every time you work

1. **Get the latest first:** `git pull`
2. Start Rojo: `rojo serve default.project.json`, then Connect from the Rojo plugin in Studio.
3. Edit the files in `src/` with your editor. Check before you share:
   `lune run test` (tests), `selene src` (lint), `stylua src tests` (format).
4. **Share your work** when a piece works:
   ```
   git add -A
   git commit -m "what you changed"
   git push
   ```
   If `git push` refuses, run `git pull` first, then push again.
5. Tell the other person you pushed, so they `git pull` before they sync.

## The rules that stop lost work

- **Pull before you sync into Studio.** Rojo makes Studio match YOUR files. If your files are old,
  you put old code into the shared place and hide the other person's newer code.
- **Only one person runs Rojo into the Team Create place at a time.** Agree out loud who is syncing.
- **Never edit Rojo-controlled scripts in Studio** (the table above). Change the files.
- **Commit small and often**, and push when something works, not once a week.
- If `git pull` says there's a CONFLICT, you both changed the same lines. Open the file, keep the right
  version between the `<<<<<<<` and `>>>>>>>` markers, then `git add -A`, `git commit`, `git push`.
  Ask if unsure; nothing is lost while it's in Git.
- Changes to the map or other Studio-only things: save/publish the place, and tell the other person.
