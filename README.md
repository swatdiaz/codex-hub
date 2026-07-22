# VOR Hub

GitHub-backed source for VOR Hub.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/swatdiaz/codex-hub/main/codex_hub.lua"))()
```

The loader URL stays the same when `codex_hub.lua` is updated on the `main` branch.

## Files

- `codex_hub.lua` — complete hub source
- `loader.lua` — stable one-line loader
- `update-github.ps1` — copies the parent source file, commits it, and pushes `main`

## Publish an update

Run this from PowerShell after changing the parent `codex_hub.lua` file:

```powershell
& ".\codex-hub\update-github.ps1"
```
