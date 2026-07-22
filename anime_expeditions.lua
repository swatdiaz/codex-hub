-- Codex Hub - Anime Expeditions game module
-- Loaded only for UniverseId 7613921865. The module is intentionally adaptive:
-- verified game endpoints are used directly while optional progression endpoints
-- are discovered from the live Nodes table and fail closed when unavailable.

return function(context)
    local Window = assert(context.Window, "Anime Expeditions: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Anime Expeditions: category builder is required")
    local CATEGORY_DECALS = assert(context.CategoryDecals, "Anime Expeditions: category decals are required")
    local COLORS = assert(context.Colors, "Anime Expeditions: colors are required")
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService = game:GetService("TeleportService")
    local VirtualUser = game:GetService("VirtualUser")
    local GuiService = game:GetService("GuiService")
    local LocalPlayer = Players.LocalPlayer

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local AfkPage = addHomeCategory("AFK", 1, CATEGORY_DECALS.Overnight)
    local MacroPage = addHomeCategory("Macro", 2, CATEGORY_DECALS.Combat)
    local SummonPage = addHomeCategory("Summon", 3, CATEGORY_DECALS.Weapons)
    local UnitsPage = addHomeCategory("Units", 4, CATEGORY_DECALS.Weapons)
    local ProgressPage = addHomeCategory("Progress", 5, CATEGORY_DECALS.Progress)

    local AfkSection = AfkPage:AddSection("Full AFK Controller", "Left")
    local MatchSection = AfkPage:AddSection("Match Automation", "Left")
    local StatusSection = AfkPage:AddSection("Live Status", "Right")
    local RecoverySection = AfkPage:AddSection("Recovery", "Right")
    local RecorderSection = MacroPage:AddSection("Macro Recorder", "Left")
    local PlaybackSection = MacroPage:AddSection("Macro Playback", "Right")
    local MacroInfoSection = MacroPage:AddSection("Recorded Route", "Right")
    local SummonSection = SummonPage:AddSection("Auto Summon", "Left")
    local SummonSettingsSection = SummonPage:AddSection("Summon Settings", "Right")
    local AutoSellSection = SummonPage:AddSection("Protected Auto Sell", "Right")
    local UnitOptimizerSection = UnitsPage:AddSection("Unit Optimizer", "Left")
    local UnitProgressSection = UnitsPage:AddSection("Unit Progression", "Right")
    local RewardSection = ProgressPage:AddSection("Reward Automation", "Left")
    local ProgressStatusSection = ProgressPage:AddSection("Account Snapshot", "Right")

    selectHomeCategory("AFK")

    local state = {
        Alive = true,
        FullAfk = false,
        AntiAfk = true,
        AutoStartVote = false,
        AutoSkip = false,
        AutoReplay = false,
        AutoMacro = false,
        AutoReconnect = true,
        Recording = false,
        Playing = false,
        LoopMacro = false,
        PlaybackMode = "Cost Based",
        PlaybackSpeed = 1,
        MacroName = "Main Route",
        SelectedMacro = nil,
        MacroEvents = {},
        RecordStarted = 0,
        LastRecordedAt = 0,
        LastReplay = 0,
        LastVote = {},
        AutoSummon = false,
        SummonBanner = "Standard",
        SummonAmount = 10,
        SummonInterval = 1,
        MinimumCurrencyReserve = 0,
        StopWhenBroke = true,
        StopTarget = "None",
        TotalSummons = 0,
        TotalSpent = 0,
        LastSummon = 0,
        FastSummon = false,
        SummonMax = false,
        AutoSellRarity = "Rare",
        AutoSellNormal = false,
        AutoSellShiny = false,
        AutoEquipBest = false,
        AutoUpgradeUnits = false,
        AutoEvolve = false,
        AutoAscend = false,
        AutoPotential = false,
        AutoTrait = false,
        ProgressInterval = 8,
        LastProgress = 0,
        SelectedUnitId = nil,
        AutoClaim = false,
        ClaimQuests = true,
        ClaimDaily = true,
        ClaimCalendar = true,
        ClaimBattlepass = true,
        ClaimEvent = true,
        ClaimIndex = true,
        ClaimGuild = true,
        LastClaim = 0,
        LastClaimCount = 0,
        Status = "Initializing Anime Expeditions adapter...",
        AdapterStatus = "Waiting for game modules",
        LastError = nil,
        Hooked = false,
        InternalSignal = false,
        WatchedUnits = {},
        LastGameState = "Unknown",
    }

    local statusLabel = StatusSection:AddLabel("Status: Initializing...")
    local adapterLabel = StatusSection:AddLabel("Adapter: Waiting for ReplicatedStorage")
    local matchLabel = StatusSection:AddLabel("Match: Reading GameState...")
    local macroLabel = StatusSection:AddLabel("Macro: Idle")
    local queueLabel = StatusSection:AddLabel("Queue: 0 actions")
    local summonStatusLabel = SummonSection:AddLabel("Summon: Ready")
    local balanceLabel = SummonSection:AddLabel("Balance: Reading...")
    local pityLabel = SummonSettingsSection:AddLabel("Pity: Reading selected banner...")
    local macroRouteLabel = MacroInfoSection:AddLabel("No route recorded yet.")
    local bestUnitLabel = UnitOptimizerSection:AddLabel("Best unit: Reading inventory...")
    local unitCountLabel = UnitOptimizerSection:AddLabel("Units: Reading...")
    local unitEndpointLabel = UnitProgressSection:AddLabel("Progress endpoints: Scanning...")
    local rewardEndpointLabel = RewardSection:AddLabel("Reward endpoints: Scanning...")
    local accountLabel = ProgressStatusSection:AddLabel("PlayerData: Waiting...")
    local currencyLabel = ProgressStatusSection:AddLabel("Currencies: Reading...")
    local gameInfoLabel = ProgressStatusSection:AddLabel("PlaceId " .. tostring(game.PlaceId))

    local function setStatus(message, success)
        state.Status = tostring(message)
        statusLabel.Text = "Status: " .. state.Status
        statusLabel.TextColor3 = success == false and COLORS.error or (success == true and COLORS.success or COLORS.muted)
    end

    local function setError(message)
        state.LastError = tostring(message)
        setStatus(state.LastError, false)
    end

    local function safeRequire(instance)
        if not instance then
            return nil
        end
        local ok, result = pcall(require, instance)
        if ok then
            return result
        end
        return nil
    end

    local Nodes = safeRequire(ReplicatedStorage:FindFirstChild("Nodes"))
    local Shared = ReplicatedStorage:FindFirstChild("Shared")
    local ReplicaClient = Shared and safeRequire(Shared:FindFirstChild("ReplicaClient"))
    local FusionPackage = ReplicatedStorage:FindFirstChild("FusionPackage")
    local Dependencies = FusionPackage and safeRequire(FusionPackage:FindFirstChild("Dependencies"))
    local Fusion = FusionPackage and safeRequire(FusionPackage:FindFirstChild("Fusion"))
    local peek = Fusion and Fusion.peek
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    local ReplicaSignal = remoteEvents and remoteEvents:FindFirstChild("ReplicaSignal")

    local function replicas()
        if not ReplicaClient then
            return {}
        end
        local ok, result = pcall(function()
            return ReplicaClient.Test().Replicas
        end)
        return ok and type(result) == "table" and result or {}
    end

    local function findReplica(token, predicate)
        for _, replica in pairs(replicas()) do
            if replica.Token == token and replica.Data and (not predicate or predicate(replica)) then
                return replica
            end
        end
        return nil
    end

    local function playerData()
        if Dependencies and peek then
            local ok, result = pcall(function()
                return peek(Dependencies.PlayerData)
            end)
            if ok and type(result) == "table" then
                return result
            end
        end
        local replica = findReplica("PlayerData")
        return replica and replica.Data or nil
    end

    local function gameStateReplica()
        return findReplica("GameState")
    end

    local function activeHotbar()
        return findReplica("HotbarData", function(replica)
            return replica.Data.PlacementAllowed == true
        end) or findReplica("HotbarData")
    end

    local function invokeEndpoint(endpoint, arguments)
        if not endpoint then
            return false, "endpoint unavailable"
        end
        local ok, result = pcall(function()
            if type(endpoint.FireServer) == "function" then
                return endpoint:FireServer(table.unpack(arguments, 1, arguments.n))
            end
            if type(endpoint.InvokeServer) == "function" then
                return endpoint:InvokeServer(table.unpack(arguments, 1, arguments.n))
            end
            if type(endpoint.InvokeSelf) == "function" then
                return endpoint:InvokeSelf(table.unpack(arguments, 1, arguments.n))
            end
            error("endpoint has no supported call method")
        end)
        return ok, result
    end

    -- Some executor builds temporarily lower the capability of the thread that
    -- fires a game node. Run each network call on its own disposable task so UI
    -- construction and later control updates keep normal Instance access.
    local function callEndpoint(endpoint, ...)
        local arguments = table.pack(...)
        local finished = false
        local ok, result
        task.spawn(function()
            ok, result = invokeEndpoint(endpoint, arguments)
            finished = true
        end)
        while not finished do
            task.wait()
        end
        return ok, result
    end

    local function getNode(name)
        return Nodes and Nodes[name] or nil
    end

    local function callNode(name, ...)
        local arguments = table.pack(...)
        local finished = false
        local ok, result
        task.spawn(function()
            local resolved, endpoint = pcall(getNode, name)
            if not resolved then
                ok, result = false, endpoint
            else
                ok, result = invokeEndpoint(endpoint, arguments)
            end
            finished = true
        end)
        while not finished do
            task.wait()
        end
        return ok, result
    end

    local function nodeNames(predicate)
        local names = {}
        local seen = {}
        local knownNodeNames = {
            "CLIENT_CHANGE_SETTING", "GET_SETTING_VALUE", "BANNER_SUMMON", "CHANGE_AUTOSELL_SETTING",
            "EQUIP_LOADOUT", "EQUIP_UNIT", "CHANGE_LOADOUT", "SET_LOADOUT",
            "UPGRADE_UNIT", "LEVEL_UP_UNIT", "UNIT_UPGRADE", "EVOLVE_UNIT", "UNIT_EVOLVE",
            "ASCEND_UNIT", "UNIT_ASCEND", "REROLL_POTENTIAL", "ROLL_POTENTIAL", "UNIT_POTENTIAL",
            "REROLL_TRAIT", "ROLL_TRAIT", "UNIT_TRAIT", "REPLAY", "RESTART_GAME",
            "REQUEST_REPLAY", "PLAY_AGAIN", "CLAIM_QUEST", "CLAIM_ALL_QUESTS",
            "CLAIM_DAILY", "CLAIM_LOGIN_REWARD", "CLAIM_CALENDAR_REWARD",
            "CLAIM_BATTLEPASS_REWARD", "CLAIM_ALL_BATTLEPASS_REWARDS", "CLAIM_EVENT_REWARD",
            "CLAIM_INDEX_REWARD", "CLAIM_GUILD_REWARD",
        }
        for _, name in ipairs(knownNodeNames) do
            local endpoint = getNode(name)
            if endpoint and (not predicate or predicate(string.upper(name), endpoint)) then
                seen[name] = true
                table.insert(names, name)
            end
        end
        if type(Nodes) == "table" then
            for name, endpoint in pairs(Nodes) do
                if type(name) == "string" and endpoint and not seen[name]
                    and (not predicate or predicate(string.upper(name), endpoint)) then
                    table.insert(names, name)
                end
            end
        end
        table.sort(names)
        return names
    end

    local function getSetting(name)
        local ok, value = callNode("GET_SETTING_VALUE", name)
        return ok and value == true
    end

    local function setSetting(name, value)
        local ok, result = callNode("CLIENT_CHANGE_SETTING", name, value == true)
        if not ok then
            setError("Setting " .. name .. " failed: " .. tostring(result))
        end
        return ok
    end

    local function getItemAmount(name)
        local data = playerData()
        local item = data and data.ItemData and data.ItemData[name]
        return type(item) == "table" and tonumber(item.Amount) or tonumber(item) or 0
    end

    local function getBannerInfo(banner)
        local bannerData = Dependencies and Dependencies.BannerData and peek and peek(Dependencies.BannerData) or nil
        local live = type(bannerData) == "table" and bannerData[banner] or nil
        local info = live and live.BannerInfo or nil
        return type(info) == "table" and info or {}
    end

    local function selectedBannerMeta()
        local info = getBannerInfo(state.SummonBanner)
        return {
            Cost = tonumber(info.Cost) or 50,
            Currency = tostring(info.Currency or "Gem"),
        }
    end

    local function currentPity()
        local data = playerData()
        local banner = data and data.BannerData and data.BannerData[state.SummonBanner]
        local pity = banner and banner.Pity
        if type(pity) ~= "table" then
            return "No pity data"
        end
        local entries = {}
        for rarity, value in pairs(pity) do
            table.insert(entries, tostring(rarity) .. " " .. tostring(value))
        end
        table.sort(entries)
        return #entries > 0 and table.concat(entries, " | ") or "No pity data"
    end

    local function assetFromUnitId(value)
        return value and tostring(value):match("^([^#]+)") or nil
    end

    local rarityScores = {
        Common = 1,
        Uncommon = 2,
        Rare = 3,
        Epic = 4,
        Legendary = 5,
        Mythic = 6,
        Exclusive = 7,
        Secret = 8,
    }

    local function inventoryUnits()
        local data = playerData()
        local source = data and data.UnitData
        local units = {}
        if type(source) ~= "table" then
            return units
        end
        for id, unit in pairs(source) do
            if type(unit) == "table" then
                local rarity = tostring(unit.Rarity or (unit.UnitData and unit.UnitData.Rarity) or "")
                local level = tonumber(unit.Level or unit.UnitLevel or 0) or 0
                local stars = tonumber(unit.Stars or unit.Star or 0) or 0
                local shiny = unit.Shiny == true and 1 or 0
                local trait = tostring(unit.Trait or "")
                local score = (rarityScores[rarity] or 0) * 100000 + level * 100 + stars * 500 + shiny * 25000
                table.insert(units, {
                    Id = tostring(id),
                    Asset = tostring(unit.Asset or assetFromUnitId(id) or "Unknown"),
                    Rarity = rarity ~= "" and rarity or "Unknown",
                    Level = level,
                    Trait = trait,
                    Shiny = shiny == 1,
                    Score = score,
                    Raw = unit,
                })
            end
        end
        table.sort(units, function(a, b)
            if a.Score == b.Score then
                return a.Asset < b.Asset
            end
            return a.Score > b.Score
        end)
        return units
    end

    local function bestUnit()
        local units = inventoryUnits()
        return units[1], units
    end

    local function findNumericByName(value, wanted, depth, seen)
        if type(value) ~= "table" or depth > 6 or seen[value] then
            return nil
        end
        seen[value] = true
        for key, child in pairs(value) do
            local normalized = string.lower(tostring(key))
            if type(child) == "number" and wanted[normalized] then
                return child
            end
        end
        for _, child in pairs(value) do
            local found = findNumericByName(child, wanted, depth + 1, seen)
            if found ~= nil then
                return found
            end
        end
        return nil
    end

    local function currentMatchMoney()
        local replica = gameStateReplica()
        local data = replica and replica.Data or {}
        return findNumericByName(data, {
            money = true,
            cash = true,
            yen = true,
            currency = true,
            gold = true,
        }, 0, {}) or 0
    end

    local function currentGameInfo()
        local replica = gameStateReplica()
        local data = replica and replica.Data or nil
        local parameters = data and data.Parameters or {}
        return {
            State = tostring(data and data.CurrentGameState or "Lobby"),
            SessionTime = tonumber(data and data.SessionTime) or 0,
            Map = tostring(parameters.MapName or "Lobby"),
            Difficulty = tostring(parameters.Difficulty or "Unknown"),
            Mode = tostring(parameters.Gamemode or "Unknown"),
            Act = tostring(parameters.ActName or "Unknown"),
        }
    end

    local MACRO_FOLDER = "SolixHub/AnimeExpeditions/Macros"
    local function hasFileApi()
        return type(makefolder) == "function"
            and type(isfolder) == "function"
            and type(isfile) == "function"
            and type(readfile) == "function"
            and type(writefile) == "function"
            and type(listfiles) == "function"
    end

    local function ensureFolder(path)
        if not hasFileApi() then
            return false
        end
        local current = ""
        for part in string.gmatch(path, "[^/\\]+") do
            current = current == "" and part or (current .. "/" .. part)
            if not isfolder(current) then
                pcall(makefolder, current)
            end
        end
        return isfolder(path)
    end

    local function cleanMacroName(value)
        local cleaned = tostring(value or ""):gsub("[^%w%s%-%_]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        return cleaned ~= "" and cleaned or "Main Route"
    end

    local function macroPath(name)
        return MACRO_FOLDER .. "/" .. cleanMacroName(name) .. ".json"
    end

    local function encodeValue(value, unitReferences, depth)
        depth = depth or 0
        if depth > 8 then
            return nil
        end
        local valueType = typeof(value)
        if valueType == "CFrame" then
            return {__type = "CFrame", value:GetComponents()}
        elseif valueType == "Vector3" then
            return {__type = "Vector3", value.X, value.Y, value.Z}
        elseif valueType == "Vector2" then
            return {__type = "Vector2", value.X, value.Y}
        elseif valueType == "EnumItem" then
            return {__type = "Enum", value = tostring(value)}
        elseif valueType == "Instance" then
            return {__type = "Instance", path = value:GetFullName()}
        elseif type(value) == "string" and unitReferences and unitReferences[value] then
            return {__type = "UnitRef", order = unitReferences[value]}
        elseif type(value) == "table" then
            local output = {}
            for key, child in pairs(value) do
                local encodedKey = type(key) == "number" and key or tostring(key)
                output[encodedKey] = encodeValue(child, unitReferences, depth + 1)
            end
            return output
        elseif type(value) == "number" or type(value) == "string" or type(value) == "boolean" or value == nil then
            return value
        end
        return tostring(value)
    end

    local function ownedGameUnits()
        local units = {}
        for _, replica in pairs(replicas()) do
            if (replica.Token == "GameUnit" or replica.Token == "GamePhantom") and replica.Data and replica.Data.Owner == LocalPlayer then
                table.insert(units, replica)
            end
        end
        table.sort(units, function(a, b)
            local at = tonumber(a.Data.PlacedAt) or 0
            local bt = tonumber(b.Data.PlacedAt) or 0
            if at == bt then
                return tostring(a.Data.ID) < tostring(b.Data.ID)
            end
            return at < bt
        end)
        return units
    end

    local function unitReferenceMap()
        local references = {}
        for order, replica in ipairs(ownedGameUnits()) do
            references[tostring(replica.Data.ID)] = order
        end
        return references
    end

    local function decodeValue(value, unitList, depth)
        depth = depth or 0
        if type(value) ~= "table" or depth > 8 then
            return value
        end
        if value.__type == "CFrame" then
            return CFrame.new(table.unpack(value, 1, 12))
        elseif value.__type == "Vector3" then
            return Vector3.new(value[1], value[2], value[3])
        elseif value.__type == "Vector2" then
            return Vector2.new(value[1], value[2])
        elseif value.__type == "UnitRef" then
            local replica = unitList[tonumber(value.order)]
            return replica and tostring(replica.Data.ID) or nil
        elseif value.__type == "Instance" then
            return nil
        end
        local output = {}
        for key, child in pairs(value) do
            output[key] = decodeValue(child, unitList, depth + 1)
        end
        return output
    end

    local function replicaTokenForId(id)
        for _, replica in pairs(replicas()) do
            if tostring(replica.Id) == tostring(id) then
                return replica.Token
            end
        end
        return "GameState"
    end

    local function recordSignal(arguments)
        if not state.Recording or state.Playing or state.InternalSignal then
            return
        end
        local signalName = arguments[2]
        if type(signalName) ~= "string" then
            return
        end
        local allowed = {
            PlaceGameUnit = true,
            SellGameUnit = true,
            SellAllGameUnits = true,
            Response = true,
            SelectSlot = true,
            UseAbility = true,
            ActivateAbility = true,
        }
        if not allowed[signalName] then
            return
        end
        local now = os.clock()
        local references = unitReferenceMap()
        local encodedArguments = {}
        for index = 3, arguments.n do
            encodedArguments[index - 2] = encodeValue(arguments[index], references)
        end
        table.insert(state.MacroEvents, {
            At = now - state.RecordStarted,
            Delay = state.LastRecordedAt > 0 and now - state.LastRecordedAt or 0,
            Gate = currentMatchMoney(),
            Token = replicaTokenForId(arguments[1]),
            Signal = signalName,
            Arguments = encodedArguments,
        })
        state.LastRecordedAt = now
        macroRouteLabel.Text = string.format("Route: %d actions | Last: %s", #state.MacroEvents, signalName)
    end

    local function installSignalHook()
        if state.Hooked or not ReplicaSignal then
            return ReplicaSignal ~= nil
        end
        local closure = type(newcclosure) == "function" and newcclosure or function(callback)
            return callback
        end
        if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", closure(function(self, ...)
                if self == ReplicaSignal and getnamecallmethod() == "FireServer" then
                    local arguments = table.pack(...)
                    task.defer(function()
                        pcall(recordSignal, arguments)
                    end)
                end
                return oldNamecall(self, ...)
            end))
            state.Hooked = true
            return true
        end
        if type(getrawmetatable) == "function" and type(setreadonly) == "function" and type(getnamecallmethod) == "function" then
            local ok = pcall(function()
                local metatable = getrawmetatable(game)
                local oldNamecall = metatable.__namecall
                setreadonly(metatable, false)
                metatable.__namecall = closure(function(self, ...)
                    if self == ReplicaSignal and getnamecallmethod() == "FireServer" then
                        local arguments = table.pack(...)
                        task.defer(function()
                            pcall(recordSignal, arguments)
                        end)
                    end
                    return oldNamecall(self, ...)
                end)
                setreadonly(metatable, true)
            end)
            state.Hooked = ok
            return ok
        end
        return false
    end

    local function macroNames()
        if not hasFileApi() or not ensureFolder(MACRO_FOLDER) then
            return {}
        end
        local names = {}
        local ok, files = pcall(listfiles, MACRO_FOLDER)
        if ok and type(files) == "table" then
            for _, path in ipairs(files) do
                local name = tostring(path):match("([^/\\]+)%.json$")
                if name then
                    table.insert(names, name)
                end
            end
        end
        table.sort(names)
        return names
    end

    local macroDropdown
    local afkMacroDropdown
    local function refreshMacroLists(preferred)
        local names = macroNames()
        macroDropdown:SetOptions(names, false)
        afkMacroDropdown:SetOptions(names, false)
        local target = preferred or state.SelectedMacro or names[1]
        if target then
            macroDropdown:Set(target, true)
            afkMacroDropdown:Set(target, true)
            state.SelectedMacro = target
        end
        return names
    end

    local function saveMacro()
        if not hasFileApi() or not ensureFolder(MACRO_FOLDER) then
            return false, "Executor file API is unavailable"
        end
        if #state.MacroEvents == 0 then
            return false, "Record at least one action first"
        end
        local info = currentGameInfo()
        local name = cleanMacroName(state.MacroName)
        local payload = {
            Version = 2,
            GameId = game.GameId,
            PlaceId = game.PlaceId,
            Name = name,
            CreatedAt = os.time(),
            Map = info.Map,
            Difficulty = info.Difficulty,
            Mode = info.Mode,
            Act = info.Act,
            Events = state.MacroEvents,
        }
        local ok, errorMessage = pcall(function()
            writefile(macroPath(name), HttpService:JSONEncode(payload))
        end)
        if not ok then
            return false, tostring(errorMessage)
        end
        state.SelectedMacro = name
        refreshMacroLists(name)
        return true, "Saved " .. name .. " with " .. tostring(#state.MacroEvents) .. " actions"
    end

    local function loadMacro(name)
        name = cleanMacroName(name or state.SelectedMacro)
        if not hasFileApi() or not isfile(macroPath(name)) then
            return nil, "Macro was not found: " .. name
        end
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(macroPath(name)))
        end)
        if not ok or type(decoded) ~= "table" or type(decoded.Events) ~= "table" then
            return nil, "Macro file is invalid"
        end
        return decoded
    end

    local function findCurrentReplica(token, event)
        if token == "GameState" or token == nil then
            return gameStateReplica()
        elseif token == "VotePrompt" then
            return findReplica("VotePrompt")
        elseif token == "GameUnit" or token == "GamePhantom" then
            local arguments = event.Arguments or {}
            for _, argument in pairs(arguments) do
                if type(argument) == "table" and argument.__type == "UnitRef" then
                    return ownedGameUnits()[tonumber(argument.order)]
                end
            end
            return ownedGameUnits()[1]
        end
        return findReplica(token) or gameStateReplica()
    end

    local function waitForPlaybackGate(event, previousAt)
        if state.PlaybackMode == "Cost Based" and tonumber(event.Gate) and tonumber(event.Gate) > 0 then
            local deadline = os.clock() + 180
            while state.Playing and currentMatchMoney() < tonumber(event.Gate) and os.clock() < deadline do
                task.wait(0.15)
            end
            return
        end
        local delayValue = math.max(0, (tonumber(event.At) or 0) - (tonumber(previousAt) or 0))
        delayValue = delayValue / math.max(0.25, state.PlaybackSpeed)
        local deadline = os.clock() + delayValue
        while state.Playing and os.clock() < deadline do
            task.wait(math.min(0.10, math.max(0.01, deadline - os.clock())))
        end
    end

    local function playMacroOnce()
        if state.Playing then
            return false, "A macro is already playing"
        end
        local macro, errorMessage = loadMacro(state.SelectedMacro)
        if not macro then
            return false, errorMessage
        end
        if not ReplicaSignal then
            return false, "ReplicaSignal is unavailable in this place"
        end
        state.Playing = true
        local played = 0
        local previousAt = 0
        setStatus("Playing " .. tostring(macro.Name or state.SelectedMacro), true)
        for _, event in ipairs(macro.Events) do
            if not state.Playing or not state.Alive then
                break
            end
            waitForPlaybackGate(event, previousAt)
            previousAt = tonumber(event.At) or previousAt
            if not state.Playing then
                break
            end
            local replica = findCurrentReplica(event.Token, event)
            if replica then
                local currentUnits = ownedGameUnits()
                local decoded = {}
                for index, argument in ipairs(event.Arguments or {}) do
                    decoded[index] = decodeValue(argument, currentUnits)
                end
                state.InternalSignal = true
                local ok = pcall(function()
                    ReplicaSignal:FireServer(replica.Id, event.Signal, table.unpack(decoded))
                end)
                state.InternalSignal = false
                if ok then
                    played = played + 1
                end
            end
            queueLabel.Text = string.format("Queue: %d / %d actions", played, #macro.Events)
        end
        state.Playing = false
        setStatus("Macro finished: " .. tostring(played) .. " actions", true)
        return true, "Played " .. tostring(played) .. " actions"
    end

    local function answerVote(replica, reason)
        if not ReplicaSignal or not replica then
            return false
        end
        local id = tostring(replica.Id)
        if os.clock() - (state.LastVote[id] or 0) < 1.5 then
            return false
        end
        state.LastVote[id] = os.clock()
        state.InternalSignal = true
        local ok = pcall(function()
            ReplicaSignal:FireServer(replica.Id, "Response", true)
        end)
        state.InternalSignal = false
        if ok then
            setStatus("Accepted " .. tostring(reason or "vote"), true)
        end
        return ok
    end

    local function processVotes()
        for _, replica in pairs(replicas()) do
            if replica.Token == "VotePrompt" and replica.Data then
                local title = tostring(((replica.Data.Parameters or {}).Title) or "Vote")
                local lower = string.lower(title)
                if state.AutoStartVote and lower:find("start") then
                    answerVote(replica, title)
                elseif state.AutoReplay and (lower:find("replay") or lower:find("again") or lower:find("restart")) then
                    answerVote(replica, title)
                elseif state.AutoSkip and (lower:find("skip") or lower:find("wave")) then
                    answerVote(replica, title)
                end
            end
        end
    end

    local function requestReplay()
        if os.clock() - state.LastReplay < 4 then
            return false
        end
        state.LastReplay = os.clock()
        local environment = type(getgenv) == "function" and getgenv().AE or nil
        if environment and type(environment.Restart) == "function" then
            local ok = pcall(environment.Restart)
            if ok then
                return true
            end
        end
        for _, name in ipairs({"REPLAY", "RESTART_GAME", "REQUEST_REPLAY", "PLAY_AGAIN"}) do
            if getNode(name) then
                local ok = callNode(name)
                if ok then
                    return true
                end
            end
        end
        processVotes()
        return false
    end

    local function summonOnce()
        local amount = tonumber(state.SummonAmount) or 1
        local meta = selectedBannerMeta()
        local cost = meta.Cost * amount
        local before = getItemAmount(meta.Currency)
        local reserve = math.max(0, math.floor(tonumber(state.MinimumCurrencyReserve) or 0))
        if before - cost < reserve then
            return false, string.format("Protected reserve: keep %d %s (balance %d, cost %d)", reserve, meta.Currency, before, cost)
        end
        if state.StopWhenBroke and before < cost then
            return false, string.format("Need %d %s; balance is %d", cost, meta.Currency, before)
        end
        local ok, result = callNode("BANNER_SUMMON", state.SummonBanner, amount)
        if not ok then
            return false, tostring(result)
        end
        state.TotalSummons = state.TotalSummons + amount
        task.delay(0.35, function()
            local after = getItemAmount(meta.Currency)
            state.TotalSpent = state.TotalSpent + math.max(0, before - after)
        end)
        return true, string.format("%s x%d request sent", state.SummonBanner, amount)
    end

    local autoSummonControl
    local function stopAutoSummon(message)
        state.AutoSummon = false
        if autoSummonControl then
            autoSummonControl:Set(false, true)
        end
        summonStatusLabel.Text = "Summon: " .. tostring(message)
    end

    local function rewardMatchesStopTarget(rewards)
        local target = state.StopTarget
        if target == "None" or type(rewards) ~= "table" then
            return false
        end
        for _, entry in pairs(rewards) do
            if type(entry) == "table" then
                local data = entry.Data or entry
                local rarity = tostring(data.Rarity or entry.Rarity or "")
                local shiny = data.Shiny == true or entry.Shiny == true
                if target == "Shiny" and shiny then
                    return true
                elseif rarity == target then
                    return true
                end
            end
        end
        return false
    end

    local function connectSummonResults()
        local network = ReplicatedStorage:FindFirstChild("Nodes")
        network = network and network:FindFirstChild("Network")
        network = network and network:FindFirstChild("NetworkEvents")
        local updateNode = network and network:FindFirstChild("_updateNode")
        if not updateNode or not updateNode:IsA("RemoteEvent") then
            return
        end
        track(updateNode.OnClientEvent:Connect(function(nodeName, _, rewards)
            if nodeName == "PROMPT_OBTAINED_REWARDS" or nodeName == "PROMPT_OBTAINED_REWARD_SLOTS" then
                if rewardMatchesStopTarget(rewards) then
                    stopAutoSummon("Stopped on " .. state.StopTarget)
                    Window:Notify("Anime Expeditions", "Auto Summon found " .. state.StopTarget, 4)
                end
            end
        end))
    end

    local function setAutoSell(rarity, shiny, enabled)
        if rarity == "Secret" then
            return false, "Secret units are always protected"
        end
        return callNode("CHANGE_AUTOSELL_SETTING", state.SummonBanner, rarity, shiny == true, enabled == true)
    end

    local actionPatterns = {
        Equip = {"EQUIP_LOADOUT", "EQUIP_UNIT", "CHANGE_LOADOUT", "SET_LOADOUT"},
        Upgrade = {"UPGRADE_UNIT", "LEVEL_UP_UNIT", "UNIT_UPGRADE"},
        Evolve = {"EVOLVE_UNIT", "UNIT_EVOLVE"},
        Ascend = {"ASCEND_UNIT", "UNIT_ASCEND"},
        Potential = {"REROLL_POTENTIAL", "ROLL_POTENTIAL", "UNIT_POTENTIAL"},
        Trait = {"REROLL_TRAIT", "ROLL_TRAIT", "UNIT_TRAIT"},
    }

    local function findActionNode(action)
        local candidates = actionPatterns[action] or {}
        for _, name in ipairs(candidates) do
            if getNode(name) then
                return name
            end
        end
        local actionUpper = string.upper(action)
        local discovered = nodeNames(function(name)
            return name:find(actionUpper, 1, true) ~= nil and (name:find("UNIT", 1, true) ~= nil or action == "Equip")
        end)
        return discovered[1]
    end

    local function performUnitAction(action)
        local chosen, units = bestUnit()
        if state.SelectedUnitId then
            for _, unit in ipairs(units) do
                if unit.Id == state.SelectedUnitId then
                    chosen = unit
                    break
                end
            end
        end
        if not chosen then
            return false, "No units were found in PlayerData"
        end
        local endpointName = findActionNode(action)
        if not endpointName then
            return false, action .. " endpoint is not present in this game build"
        end
        local payloads
        if action == "Equip" then
            local loadout = {}
            for index = 1, math.min(6, #units) do
                loadout[index] = units[index].Id
            end
            payloads = {loadout, {Units = loadout}, {UnitIds = loadout}}
        else
            payloads = {chosen.Id, {UnitId = chosen.Id}, {ID = chosen.Id}}
        end
        for _, payload in ipairs(payloads) do
            local ok = callNode(endpointName, payload)
            if ok then
                state.SelectedUnitId = chosen.Id
                return true, action .. " request sent for " .. chosen.Asset .. " through " .. endpointName
            end
        end
        return false, endpointName .. " rejected every supported payload shape"
    end

    local rewardCategories = {
        Quest = {"QUEST"},
        Daily = {"DAILY", "LOGIN"},
        Calendar = {"CALENDAR"},
        Battlepass = {"BATTLEPASS", "BATTLE_PASS"},
        Event = {"EVENT"},
        Index = {"INDEX", "COLLECTION"},
        Guild = {"GUILD"},
    }

    local function claimCategory(category)
        local keywords = rewardCategories[category] or {}
        local endpoints = nodeNames(function(name)
            if not (name:find("CLAIM", 1, true) or name:find("REDEEM", 1, true) or name:find("COLLECT", 1, true)) then
                return false
            end
            for _, keyword in ipairs(keywords) do
                if name:find(keyword, 1, true) then
                    return true
                end
            end
            return false
        end)
        local sent = 0
        for _, endpointName in ipairs(endpoints) do
            local ok = callNode(endpointName)
            if not ok then
                ok = callNode(endpointName, {})
            end
            if ok then
                sent = sent + 1
            end
        end
        return sent, endpoints
    end

    local function claimEnabledRewards()
        local configuration = {
            Quest = state.ClaimQuests,
            Daily = state.ClaimDaily,
            Calendar = state.ClaimCalendar,
            Battlepass = state.ClaimBattlepass,
            Event = state.ClaimEvent,
            Index = state.ClaimIndex,
            Guild = state.ClaimGuild,
        }
        local total = 0
        local available = 0
        for category, enabled in pairs(configuration) do
            if enabled then
                local sent, endpoints = claimCategory(category)
                total = total + sent
                available = available + #endpoints
                task.wait(0.10)
            end
        end
        state.LastClaimCount = total
        rewardEndpointLabel.Text = string.format("Rewards: %d requests | %d discovered endpoints", total, available)
        return total, available
    end

    local macroNameControl = RecorderSection:AddInput({
        Name = "Macro Name",
        Placeholder = "Example: Story Act 1",
        Default = state.MacroName,
        Callback = function(value)
            state.MacroName = cleanMacroName(value)
        end,
    })

    local recordingControl
    recordingControl = RecorderSection:AddToggle({
        Name = "Record Match Actions",
        Description = "Captures placement, selling, votes, slots, and abilities",
        Default = false,
        Persist = false,
        Callback = function(enabled)
            if enabled and not installSignalHook() then
                recordingControl:Set(false, true)
                setError("This executor cannot hook ReplicaSignal safely")
                return
            end
            state.Recording = enabled
            if enabled then
                state.MacroEvents = {}
                state.RecordStarted = os.clock()
                state.LastRecordedAt = 0
                macroRouteLabel.Text = "Recording a new route..."
                setStatus("Macro recording started", true)
            else
                macroRouteLabel.Text = string.format("Route: %d recorded actions", #state.MacroEvents)
                setStatus("Macro recording stopped", true)
            end
        end,
    })

    RecorderSection:AddButton({
        Name = "Save Recorded Macro",
        Description = "Stores this route only for Anime Expeditions",
        Callback = function()
            state.MacroName = cleanMacroName(macroNameControl:Get())
            local ok, message = saveMacro()
            setStatus(message, ok)
            Window:Notify("Anime Expeditions", message, 3)
        end,
    })

    RecorderSection:AddButton({
        Name = "Clear Current Recording",
        Callback = function()
            state.MacroEvents = {}
            state.RecordStarted = os.clock()
            state.LastRecordedAt = 0
            macroRouteLabel.Text = "No route recorded yet."
            setStatus("Current recording cleared", true)
        end,
    })

    macroDropdown = PlaybackSection:AddDropdown({
        Name = "Saved Macro",
        Options = {},
        Placeholder = "Select a macro...",
        Persist = false,
        Callback = function(value)
            state.SelectedMacro = value
            if afkMacroDropdown and value then
                afkMacroDropdown:Set(value, true)
            end
        end,
    })

    PlaybackSection:AddDropdown({
        Name = "Playback Mode",
        Options = {"Cost Based", "Recorded Timing"},
        Default = state.PlaybackMode,
        Callback = function(value)
            state.PlaybackMode = value or "Cost Based"
        end,
    })

    PlaybackSection:AddSlider({
        Name = "Playback Speed",
        Min = 0.25,
        Max = 3,
        Step = 0.25,
        Default = 1,
        Callback = function(value)
            state.PlaybackSpeed = value
        end,
    })

    PlaybackSection:AddToggle({
        Name = "Loop Selected Macro",
        Description = "Starts it again after the current route finishes",
        Default = false,
        Callback = function(enabled)
            state.LoopMacro = enabled
        end,
    })

    PlaybackSection:AddButton({
        Name = "Play Selected Macro",
        Callback = function()
            task.spawn(function()
                local ok, message = playMacroOnce()
                if not ok then
                    setError(message)
                end
            end)
        end,
    })

    PlaybackSection:AddButton({
        Name = "Stop Playback",
        Callback = function()
            state.Playing = false
            setStatus("Macro playback stopped", true)
        end,
    })

    PlaybackSection:AddButton({
        Name = "Refresh Macro List",
        Callback = function()
            local names = refreshMacroLists()
            setStatus("Found " .. tostring(#names) .. " macro(s)", true)
        end,
    })

    autoSummonControl = SummonSection:AddToggle({
        Name = "Auto Summon",
        Description = "Uses the selected banner and supported 1x / 10x / 50x tier",
        Default = false,
        Callback = function(enabled)
            state.AutoSummon = enabled
            summonStatusLabel.Text = enabled and "Summon: Auto loop running" or "Summon: Disabled"
        end,
    })

    SummonSection:AddDropdown({
        Name = "Banner",
        Options = {"Standard", "Mini", "NewPlayerEvent"},
        Default = state.SummonBanner,
        Callback = function(value)
            state.SummonBanner = value or "Standard"
        end,
    })

    SummonSection:AddDropdown({
        Name = "Summon Tier",
        Options = {"1", "10", "50"},
        Default = "10",
        Callback = function(value)
            state.SummonAmount = tonumber(value) or 10
        end,
    })

    SummonSection:AddSlider({
        Name = "Summon Interval",
        Min = 1,
        Max = 5,
        Step = 0.25,
        Default = 1,
        Callback = function(value)
            state.SummonInterval = value
        end,
    })

    SummonSection:AddToggle({
        Name = "Stop When Balance Is Low",
        Default = true,
        Callback = function(enabled)
            state.StopWhenBroke = enabled
        end,
    })

    SummonSection:AddDropdown({
        Name = "Stop On Result",
        Options = {"None", "Mythic", "Exclusive", "Secret", "Shiny"},
        Default = "None",
        Callback = function(value)
            state.StopTarget = value or "None"
        end,
    })

    SummonSection:AddButton({
        Name = "Summon Once",
        Callback = function()
            local ok, message = summonOnce()
            summonStatusLabel.Text = "Summon: " .. message
            if not ok then
                setError(message)
            end
        end,
    })

    SummonSettingsSection:AddToggle({
        Name = "Fast Summon",
        Description = "Changes the game's FastSummon setting only after you toggle it",
        Default = false,
        Callback = function(enabled)
            state.FastSummon = enabled
            setSetting("FastSummon", enabled)
        end,
    })

    SummonSettingsSection:AddInput({
        Name = "Minimum Currency Reserve",
        Description = "Stops before the next summon would reduce the selected banner currency below this amount",
        Placeholder = "0",
        Default = "0",
        Callback = function(value)
            state.MinimumCurrencyReserve = math.max(0, math.floor(tonumber(value) or 0))
        end,
    })

    SummonSettingsSection:AddToggle({
        Name = "Summon Max",
        Description = "Changes the game's maximum summon tier setting only after you toggle it",
        Default = false,
        Callback = function(enabled)
            state.SummonMax = enabled
            setSetting("SummonMax", enabled)
        end,
    })

    SummonSettingsSection:AddButton({
        Name = "Reset Summon Statistics",
        Callback = function()
            state.TotalSummons = 0
            state.TotalSpent = 0
            summonStatusLabel.Text = "Summon: Statistics reset"
        end,
    })

    AutoSellSection:AddLabel("Secret rarity is permanently excluded and cannot be auto-sold.")
    AutoSellSection:AddDropdown({
        Name = "Rarity To Configure",
        Options = {"Rare", "Epic", "Legendary", "Mythic", "Exclusive"},
        Default = "Rare",
        Callback = function(value)
            state.AutoSellRarity = value or "Rare"
        end,
    })

    AutoSellSection:AddToggle({
        Name = "Auto Sell Normal",
        Description = "Applies to the selected banner and rarity",
        Default = false,
        Callback = function(enabled)
            state.AutoSellNormal = enabled
            local ok, result = setAutoSell(state.AutoSellRarity, false, enabled)
            if not ok then
                setError("Auto Sell Normal failed: " .. tostring(result))
            end
        end,
    })

    AutoSellSection:AddToggle({
        Name = "Auto Sell Shiny",
        Description = "Secret and stop-target protection still take priority",
        Default = false,
        Callback = function(enabled)
            state.AutoSellShiny = enabled
            local ok, result = setAutoSell(state.AutoSellRarity, true, enabled)
            if not ok then
                setError("Auto Sell Shiny failed: " .. tostring(result))
            end
        end,
    })

    UnitOptimizerSection:AddButton({
        Name = "Scan And Select Best Unit",
        Description = "Ranks rarity, shiny status, stars, and level",
        Callback = function()
            local chosen, units = bestUnit()
            if chosen then
                state.SelectedUnitId = chosen.Id
                bestUnitLabel.Text = string.format("Best unit: %s | %s | Lv.%d", chosen.Asset, chosen.Rarity, chosen.Level)
                unitCountLabel.Text = "Units: " .. tostring(#units) .. " found | Selected " .. chosen.Id
                setStatus("Selected best unit: " .. chosen.Asset, true)
            else
                setError("No units found in PlayerData")
            end
        end,
    })

    UnitOptimizerSection:AddToggle({
        Name = "Auto Equip Best Loadout",
        Description = "Uses the strongest six units when an equip endpoint exists",
        Default = false,
        Callback = function(enabled)
            state.AutoEquipBest = enabled
        end,
    })

    UnitOptimizerSection:AddButton({
        Name = "Equip Best Now",
        Callback = function()
            local ok, message = performUnitAction("Equip")
            setStatus(message, ok)
        end,
    })

    local function addUnitProgressToggle(name, field, action, description)
        UnitProgressSection:AddToggle({
            Name = name,
            Description = description,
            Default = false,
            Callback = function(enabled)
                state[field] = enabled
                if enabled then
                    local endpoint = findActionNode(action)
                    unitEndpointLabel.Text = endpoint and (action .. ": " .. endpoint) or (action .. ": waiting for live endpoint")
                end
            end,
        })
    end

    addUnitProgressToggle("Auto Upgrade Best Unit", "AutoUpgradeUnits", "Upgrade", "Spends only when the live upgrade endpoint accepts the selected unit")
    addUnitProgressToggle("Auto Evolve Eligible Unit", "AutoEvolve", "Evolve", "Attempts evolution only for the selected strongest unit")
    addUnitProgressToggle("Auto Ascend Eligible Unit", "AutoAscend", "Ascend", "Uses the discovered ascend endpoint when available")
    addUnitProgressToggle("Auto Roll Potential", "AutoPotential", "Potential", "Targets the selected strongest unit")
    addUnitProgressToggle("Auto Roll Trait", "AutoTrait", "Trait", "Targets the selected strongest unit")

    UnitProgressSection:AddSlider({
        Name = "Progress Action Interval",
        Min = 3,
        Max = 30,
        Step = 1,
        Default = 8,
        Callback = function(value)
            state.ProgressInterval = value
        end,
    })

    UnitProgressSection:AddButton({
        Name = "Rescan Progress Endpoints",
        Callback = function()
            local found = {}
            for action in pairs(actionPatterns) do
                local endpoint = findActionNode(action)
                if endpoint then
                    table.insert(found, action .. "=" .. endpoint)
                end
            end
            table.sort(found)
            unitEndpointLabel.Text = #found > 0 and table.concat(found, " | ") or "Progress endpoints: none in this place"
        end,
    })

    RewardSection:AddToggle({
        Name = "Auto Claim Rewards",
        Description = "Rate-limited claim pass every 15 seconds",
        Default = false,
        Callback = function(enabled)
            state.AutoClaim = enabled
        end,
    })

    local function addClaimToggle(name, field)
        RewardSection:AddToggle({
            Name = name,
            Default = true,
            Callback = function(enabled)
                state[field] = enabled
            end,
        })
    end

    addClaimToggle("Claim Quests", "ClaimQuests")
    addClaimToggle("Claim Daily / Login", "ClaimDaily")
    addClaimToggle("Claim Calendar", "ClaimCalendar")
    addClaimToggle("Claim Battlepass", "ClaimBattlepass")
    addClaimToggle("Claim Events", "ClaimEvent")
    addClaimToggle("Claim Index", "ClaimIndex")
    addClaimToggle("Claim Guild", "ClaimGuild")

    RewardSection:AddButton({
        Name = "Claim Everything Available Now",
        Callback = function()
            task.spawn(function()
                local sent, available = claimEnabledRewards()
                setStatus(string.format("Reward pass sent %d of %d discovered requests", sent, available), sent > 0)
            end)
        end,
    })

    local antiAfkControl = AfkSection:AddToggle({
        Name = "Anti-AFK / Anti-Idle",
        Description = "Responds only when Roblox sends an idle signal",
        Default = true,
        Callback = function(enabled)
            state.AntiAfk = enabled
        end,
    })

    local autoStartControl = MatchSection:AddToggle({
        Name = "Auto Accept Start Vote",
        Default = false,
        Callback = function(enabled)
            state.AutoStartVote = enabled
        end,
    })

    local autoSkipControl = MatchSection:AddToggle({
        Name = "Auto Skip Waves",
        Description = "Synchronizes AutoSkipWaves only after you toggle it",
        Default = false,
        Callback = function(enabled)
            state.AutoSkip = enabled
            setSetting("AutoSkipWaves", enabled)
        end,
    })

    local autoReplayControl = MatchSection:AddToggle({
        Name = "Auto Replay",
        Description = "Accepts replay prompts after victory or defeat",
        Default = false,
        Callback = function(enabled)
            state.AutoReplay = enabled
        end,
    })

    afkMacroDropdown = MatchSection:AddDropdown({
        Name = "AFK Macro",
        Options = {},
        Placeholder = "Select a saved route...",
        Persist = false,
        Callback = function(value)
            state.SelectedMacro = value
            if macroDropdown and value then
                macroDropdown:Set(value, true)
            end
        end,
    })

    local autoMacroControl = MatchSection:AddToggle({
        Name = "Auto Run Selected Macro",
        Description = "Starts the route when a live match becomes available",
        Default = false,
        Callback = function(enabled)
            state.AutoMacro = enabled
        end,
    })

    local fullAfkControl
    fullAfkControl = AfkSection:AddToggle({
        Name = "Enable Full AFK",
        Description = "Links anti-idle, votes, wave skip, replay, and selected macro",
        Default = false,
        Callback = function(enabled)
            state.FullAfk = enabled
            antiAfkControl:Set(enabled)
            autoStartControl:Set(enabled)
            autoSkipControl:Set(enabled)
            autoReplayControl:Set(enabled)
            autoMacroControl:Set(enabled)
            setStatus(enabled and "Full AFK armed" or "Full AFK disabled", true)
        end,
    })

    RecoverySection:AddToggle({
        Name = "Auto Reconnect On Error",
        Description = "Rejoins only after Roblox reports a disconnect error",
        Default = true,
        Callback = function(enabled)
            state.AutoReconnect = enabled
        end,
    })

    RecoverySection:AddButton({
        Name = "Reconnect To Current Place",
        Callback = function()
            setStatus("Reconnecting to Anime Expeditions...", true)
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        end,
    })

    RecoverySection:AddButton({
        Name = "Stop All Anime Automation",
        Callback = function()
            state.FullAfk = false
            state.AutoSummon = false
            state.AutoClaim = false
            state.AutoEquipBest = false
            state.AutoUpgradeUnits = false
            state.AutoEvolve = false
            state.AutoAscend = false
            state.AutoPotential = false
            state.AutoTrait = false
            state.Playing = false
            fullAfkControl:Set(false)
            autoSummonControl:Set(false, true)
            setStatus("All Anime Expeditions automation stopped", true)
        end,
    })

    track(LocalPlayer.Idled:Connect(function()
        if state.AntiAfk then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(
                    Vector2.new(0, 0),
                    workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new()
                )
            end)
            setStatus("Anti-AFK pulse sent", true)
        end
    end))

    track(GuiService.ErrorMessageChanged:Connect(function(message)
        if state.AutoReconnect and state.Alive and type(message) == "string" and message ~= "" then
            setStatus("Roblox error detected; reconnecting...", false)
            task.delay(2, function()
                if state.Alive and state.AutoReconnect then
                    pcall(function()
                        TeleportService:Teleport(game.PlaceId, LocalPlayer)
                    end)
                end
            end)
        end
    end))

    local function watchGameUnit(replica)
        if state.WatchedUnits[replica] or not replica or not replica.Data then
            return
        end
        state.WatchedUnits[replica] = true
        local lastUpgrade = tonumber(replica.Data.Upgrade) or 0
        pcall(function()
            replica:OnChange(function()
                if not state.Recording or state.Playing or not replica.Data then
                    return
                end
                local currentUpgrade = tonumber(replica.Data.Upgrade) or 0
                if currentUpgrade > lastUpgrade then
                    local references = unitReferenceMap()
                    table.insert(state.MacroEvents, {
                        At = os.clock() - state.RecordStarted,
                        Delay = os.clock() - state.LastRecordedAt,
                        Gate = currentMatchMoney(),
                        Token = "GameState",
                        Signal = "UpgradeGameUnit",
                        Arguments = {
                            encodeValue(tostring(replica.Data.ID), references),
                            currentUpgrade,
                        },
                    })
                    state.LastRecordedAt = os.clock()
                    lastUpgrade = currentUpgrade
                    macroRouteLabel.Text = string.format("Route: %d actions | Last: Upgrade", #state.MacroEvents)
                end
            end)
        end)
    end

    if ReplicaClient then
        pcall(function()
            ReplicaClient.OnNew("GameUnit", watchGameUnit)
            ReplicaClient.OnNew("GamePhantom", watchGameUnit)
        end)
    end
    for _, replica in ipairs(ownedGameUnits()) do
        watchGameUnit(replica)
    end

    connectSummonResults()
    installSignalHook()
    refreshMacroLists()

    task.spawn(function()
        while state.Alive do
            local now = os.clock()
            local info = currentGameInfo()
            state.LastGameState = info.State
            processVotes()

            if state.AutoReplay and (info.State == "Victory" or info.State == "Lose" or info.State == "Defeat") then
                requestReplay()
            end

            if state.AutoMacro and not state.Playing and state.SelectedMacro and info.State == "InProgress" then
                task.spawn(function()
                    local ok, message = playMacroOnce()
                    if not ok then
                        setError(message)
                    end
                end)
            elseif state.LoopMacro and not state.Playing and state.SelectedMacro and info.State == "InProgress" then
                task.spawn(playMacroOnce)
            end

            if state.AutoSummon and now - state.LastSummon >= state.SummonInterval then
                state.LastSummon = now
                local ok, message = summonOnce()
                summonStatusLabel.Text = "Summon: " .. tostring(message)
                if not ok and state.StopWhenBroke then
                    stopAutoSummon(message)
                end
            end

            if state.AutoClaim and now - state.LastClaim >= 15 then
                state.LastClaim = now
                task.spawn(claimEnabledRewards)
            end

            if now - state.LastProgress >= state.ProgressInterval then
                state.LastProgress = now
                local actions = {
                    {state.AutoEquipBest, "Equip"},
                    {state.AutoUpgradeUnits, "Upgrade"},
                    {state.AutoEvolve, "Evolve"},
                    {state.AutoAscend, "Ascend"},
                    {state.AutoPotential, "Potential"},
                    {state.AutoTrait, "Trait"},
                }
                for _, pair in ipairs(actions) do
                    if pair[1] then
                        local ok, message = performUnitAction(pair[2])
                        unitEndpointLabel.Text = message
                        if ok then
                            break
                        end
                    end
                end
            end

            local meta = selectedBannerMeta()
            local balance = getItemAmount(meta.Currency)
            local chosen, units = bestUnit()
            local adapterReady = Nodes ~= nil and ReplicaClient ~= nil and ReplicaSignal ~= nil
            state.AdapterStatus = adapterReady and "Ready" or "Partial (lobby/match objects load on demand)"
            adapterLabel.Text = "Adapter: " .. state.AdapterStatus
            adapterLabel.TextColor3 = adapterReady and COLORS.success or COLORS.muted
            matchLabel.Text = string.format("Match: %s | %s | %s | %s", info.State, info.Map, info.Difficulty, info.Act)
            macroLabel.Text = string.format("Macro: %s | %s", state.Recording and "Recording" or (state.Playing and "Playing" or "Idle"), state.SelectedMacro or "none selected")
            queueLabel.Text = state.Playing and queueLabel.Text or ("Queue: " .. tostring(#state.MacroEvents) .. " recorded actions")
            balanceLabel.Text = string.format("Balance: %d %s | Cost: %d x%d", balance, meta.Currency, meta.Cost, state.SummonAmount)
            pityLabel.Text = "Pity: " .. currentPity()
            summonStatusLabel.Text = state.AutoSummon
                and string.format("Summon: Running | %d pulls | %d spent", state.TotalSummons, state.TotalSpent)
                or summonStatusLabel.Text
            if chosen then
                bestUnitLabel.Text = string.format("Best unit: %s | %s | Lv.%d%s", chosen.Asset, chosen.Rarity, chosen.Level, chosen.Shiny and " | Shiny" or "")
                unitCountLabel.Text = "Units: " .. tostring(#units) .. " | Selected: " .. tostring(state.SelectedUnitId or chosen.Id)
            else
                bestUnitLabel.Text = "Best unit: No PlayerData unit inventory in this place"
                unitCountLabel.Text = "Units: 0"
            end
            accountLabel.Text = string.format("PlayerData: %s | GameState: %s", playerData() and "Ready" or "Waiting", gameStateReplica() and "Ready" or "Lobby")
            currencyLabel.Text = string.format("Currencies: Gem %d | Gold %d | Yen %d", getItemAmount("Gem"), getItemAmount("Gold"), getItemAmount("Yen"))
            gameInfoLabel.Text = string.format("%s | %s | %s | PlaceId %s", info.Map, info.Mode, info.Act, tostring(game.PlaceId))
            task.wait(0.50)
        end
    end)

    if gui then
        gui:SetAttribute("AnimeExpeditionsModule", true)
        gui:SetAttribute("AnimeExpeditionsUniverseId", 7613921865)
        gui:SetAttribute("AnimeExpeditionsMacroFolder", MACRO_FOLDER)
        gui:SetAttribute("AnimeExpeditionsAfkDecal", CATEGORY_DECALS.Overnight)
        gui:SetAttribute("AnimeExpeditionsMacroDecal", CATEGORY_DECALS.Combat)
        gui:SetAttribute("AnimeExpeditionsUnitsDecal", CATEGORY_DECALS.Weapons)
        gui:SetAttribute("AnimeExpeditionsProgressDecal", CATEGORY_DECALS.Progress)
        track(gui.Destroying:Connect(function()
            state.Alive = false
            state.Playing = false
            state.Recording = false
            state.AutoSummon = false
            state.AutoClaim = false
        end))
    end

    setStatus("Anime Expeditions module ready", true)
end
