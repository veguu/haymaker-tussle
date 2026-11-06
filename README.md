# Haymaker Tussle

Rojo project for the Studio place "title" (placeId 136102156542862). How the game works is in [Haymaker Tussle - System Overview.md](Haymaker%20Tussle%20-%20System%20Overview.md).

## Toolchain (installed 2026-11-05)

Rokit 1.2.0 manages the tools pinned in `rokit.toml`: Rojo 7.7.1, Wally 0.3.2, Selene 0.32.0, StyLua 2.6.0 and luau-lsp 1.70.1. The Rojo Studio plugin is in `%LOCALAPPDATA%\Roblox\Plugins`. Git is installed too.

On a new machine: `rokit install`, then `wally install`.

## How the code got onto disk (2026-11-05)

The place was downloaded from Studio (File > Download a Copy) as `game32342.rbxl`, then pulled out with:

```
rojo syncback default.project.json --input game32342.rbxl
```

All 50 scripts in `src/` were checked against Studio and match exactly. Packages are skipped, because Wally provides them. To pull again after changes made in Studio, download a fresh copy and run the same command.

## Daily use

- `rojo serve` and connect in Studio. Edit the files here, not in Studio, or the sync overwrites your Studio edits.
- `selene src` checks for code problems. `stylua src` formats the code.
- Open this folder in VS Code. The Luau, Selene and StyLua extensions are installed, and `.vscode/settings.json` points the Luau extension at this Rojo project, so autocomplete and type errors understand the game's requires. It keeps `sourcemap.json` up to date by itself.
- Formatting on save is off, because StyLua would add a final newline to every file it touches. Format a file by hand (Shift+Alt+F) when you want to.

The project only manages `ReplicatedStorage.Shared`, `ReplicatedStorage.Packages`, `ServerScriptService.Server` and `StarterPlayer.StarterPlayerScripts.Client`. Everything else in the place (the map, sounds, settings) stays as it is in Studio.
