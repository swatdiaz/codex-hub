# Codex Revive Hub

GitHub-backed source for the Codex Revive Hub.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/swatdiaz/codex-revive-hub/main/codex_revive_hub.lua"))()
```

The loader URL stays the same when `codex_revive_hub.lua` is updated on the `main` branch.

## Files

- `codex_revive_hub.lua` — complete hub source
- `loader.lua` — stable one-line loader
- `update-github.ps1` — copies the parent source file, commits it, and pushes `main`

## Publish an update

Run this from PowerShell after changing the parent `codex_revive_hub.lua` file:

```powershell
& ".\codex-revive-hub\update-github.ps1"
```
