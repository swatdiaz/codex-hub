# VOR Hub

GitHub-backed source for VOR Hub.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/swatdiaz/VOR-HUB/main/VOR_HUB.lua"))()
```

The loader URL stays the same when `VOR_HUB.lua` is updated on the `main` branch.

## Files

- `VOR_HUB.lua` — complete hub source
- `loader.lua` — stable one-line loader
- `update-github.ps1` — copies the parent source file, commits it, and pushes `main`

## Publish an update

Run this from PowerShell after changing the parent `VOR_HUB.lua` file:

```powershell
& ".\VOR-HUB\update-github.ps1"
```
