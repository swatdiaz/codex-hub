-- Codex Hub latest-build loader.
-- Resolves the current main commit first, then downloads the immutable file for
-- that commit so GitHub's branch cache cannot serve an older hub build.

local HttpService = game:GetService("HttpService")
local repository = "swatdiaz/codex-hub"
local commitApi = "https://api.github.com/repos/" .. repository .. "/commits/main"

local metadata = HttpService:JSONDecode(game:HttpGet(commitApi))
local commit = metadata and metadata.sha
assert(type(commit) == "string" and #commit >= 7, "Codex Hub could not resolve the latest GitHub commit")

local scriptUrl = "https://raw.githubusercontent.com/" .. repository .. "/" .. commit .. "/codex_hub.lua"
local source = game:HttpGet(scriptUrl)
local chunk, compileError = loadstring(source)
assert(chunk, "Codex Hub compile failed: " .. tostring(compileError))

return chunk()
