-- Codex Hub UI Template
-- Clean reusable interface framework only.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer

-- Change these values to customize the hub and welcome screen.
local SETTINGS = {
    GuiName = "CodexHub",
    Title = "Codex Hub",
    Discord = "Discord.gg/Codexhub",
    Creator = "Codex",
    IntroEnabled = true,
    IntroDuration = 5,
    IntroName = nil, -- nil uses the current Roblox username; example: "Quarter"
    IntroRole = nil, -- example: "Helper"
    IntroSoundEnabled = true,
    IntroSoundId = "rbxassetid://1085317309", -- Public two-second chime from the Creator Store.
    IntroSoundVolume = 0.32,
    IntroSoundPlaybackSpeed = 1,
    IntroPianoEnabled = true, -- Kept as the existing setting name so saved configs stay compatible.
    IntroPianoSoundId = "rbxassetid://9045935780", -- Ice World: public Creator Store music for the frozen intro.
    IntroPianoVolume = 0.52,
    IntroMusicDuration = 5, -- The music gets its own exact playback window.
    IntroPianoPlaybackSpeed = 1,
    InterfaceSoundsEnabled = true,
    ToggleClickSoundId = "rbxasset://sounds/volume_slider.ogg",
    ToggleClickVolume = 0.24,
    ToggleOnPlaybackSpeed = 1.18,
    ToggleOffPlaybackSpeed = 0.88,
    HubVisibilitySoundId = "rbxasset://sounds/volume_slider.ogg",
    HubVisibilitySoundVolume = 0.30,
    HubOpenPlaybackSpeed = 1.42,
    HubClosePlaybackSpeed = 0.68,
    ToggleKey = Enum.KeyCode.RightControl,
    SnowEnabled = true,
    SnowflakeCount = 52,
    AvatarPreviewEnabled = true,
    PlayerHeadshotEnabled = true,
    -- The decal is currently restricted, so use its public thumbnail until Asset Access is set to Open Use.
    ProfileLogoImageId = "rbxthumb://type=Asset&id=151878913&w=420&h=420", -- Clear to restore the Roblox avatar.
}

-- Keep the legacy storage path so existing profiles and autoload selections survive the rebrand.
-- Profiles remain separated by PlaceId so values never carry into another game.
local CONFIG_ROOT = "SolixHub/Configs/" .. tostring(game.PlaceId)
local PROFILE_FOLDER = CONFIG_ROOT .. "/Profiles"
local AUTOLOAD_FILE = CONFIG_ROOT .. "/autoload.json"

local SNOW_WHITE = Color3.fromRGB(246, 252, 255)

local COLORS = {
    shell = Color3.fromRGB(225, 239, 247),
    sidebar = Color3.fromRGB(216, 233, 242),
    surface = Color3.fromRGB(237, 246, 251),
    surface2 = Color3.fromRGB(211, 230, 240),
    row = Color3.fromRGB(154, 184, 200),
    dropdown = Color3.fromRGB(222, 237, 245),
    line = Color3.fromRGB(142, 188, 211),
    text = Color3.fromRGB(18, 42, 56),
    muted = Color3.fromRGB(52, 78, 94),
    dim = Color3.fromRGB(78, 108, 125),
    accent = Color3.fromRGB(218, 242, 252),
    accentDark = Color3.fromRGB(102, 164, 194),
    offTrack = Color3.fromRGB(132, 166, 184),
    knob = SNOW_WHITE,
    -- Deep emerald stays readable over the bright, translucent snow theme.
    success = Color3.fromRGB(24, 118, 82),
    error = Color3.fromRGB(239, 128, 137),
}

local UI_FONT = Enum.Font.GothamBold
local hubTransparencyValue = 0.46

local function create(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = property == "Font" and UI_FONT or value
    end
    object.Parent = parent
    return object
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 5),
    }, parent)
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or COLORS.line,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    }, parent)
end

local function makeLabel(parent, text, position, size, color, textSize, font)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = position,
        Size = size,
        Font = font or Enum.Font.GothamMedium,
        Text = text or "",
        TextColor3 = color or COLORS.text,
        TextSize = textSize or 14,
        TextWrapped = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local ok, message = pcall(callback, ...)
    if not ok then
        warn("[Codex Hub] Callback error: " .. tostring(message))
    end
end

-- Executor compatibility: prefer an executor-owned UI container when one is
-- available, then fall back to CoreGui and finally PlayerGui.
local function parentScreenGui(screenGui)
    local huiOk, hui = pcall(function()
        return gethui()
    end)
    if huiOk and typeof(hui) == "Instance" then
        local parented = pcall(function()
            screenGui.Parent = hui
        end)
        if parented then
            return
        end
    end
    local coreOk = pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
    if not coreOk then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function destroyOldGui()
    local containers = {}
    pcall(function()
        table.insert(containers, game:GetService("CoreGui"))
    end)
    pcall(function()
        local hui = gethui()
        if hui and not table.find(containers, hui) then
            table.insert(containers, hui)
        end
    end)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui and not table.find(containers, playerGui) then
        table.insert(containers, playerGui)
    end

    for _, guiName in ipairs({SETTINGS.GuiName, SETTINGS.GuiName .. "_Snow", SETTINGS.GuiName .. "_Notifications", SETTINGS.GuiName .. "_Status"}) do
        for _, container in ipairs(containers) do
            while true do
                local oldGui = container:FindFirstChild(guiName)
                if not oldGui then
                    break
                end
                oldGui:Destroy()
            end
        end
    end
    local oldMusic = SoundService:FindFirstChild("CodexHubMusic")
    if oldMusic then
        oldMusic:Stop()
        oldMusic:Destroy()
    end
end

destroyOldGui()

local connections = {}
local function track(connection)
    table.insert(connections, connection)
    return connection
end

local gui = create("ScreenGui", {
    Name = SETTINGS.GuiName,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 1000,
}, nil)

parentScreenGui(gui)

local toggleClickSound = create("Sound", {
    Name = "CodexToggleClick",
    SoundId = SETTINGS.ToggleClickSoundId,
    Volume = 0,
    PlaybackSpeed = SETTINGS.ToggleOnPlaybackSpeed,
    Looped = false,
    PlayOnRemove = false,
}, gui)

local function playToggleClick(enabled)
    if not SETTINGS.InterfaceSoundsEnabled or tostring(SETTINGS.ToggleClickSoundId or "") == "" then
        return
    end

    pcall(function()
        toggleClickSound:Stop()
        toggleClickSound.TimePosition = 0
        toggleClickSound.SoundId = tostring(SETTINGS.ToggleClickSoundId)
        toggleClickSound.Volume = math.clamp(tonumber(SETTINGS.ToggleClickVolume) or 0.24, 0, 1)
        toggleClickSound.PlaybackSpeed = math.clamp(
            tonumber(enabled and SETTINGS.ToggleOnPlaybackSpeed or SETTINGS.ToggleOffPlaybackSpeed) or 1,
            0.25,
            3
        )
        toggleClickSound:Play()
    end)
end

local hubVisibilitySound = create("Sound", {
    Name = "CodexHubVisibilitySound",
    SoundId = SETTINGS.HubVisibilitySoundId,
    Volume = 0,
    PlaybackSpeed = SETTINGS.HubOpenPlaybackSpeed,
    Looped = false,
    PlayOnRemove = false,
}, gui)

local function playHubVisibilitySound(opening)
    if not SETTINGS.InterfaceSoundsEnabled or tostring(SETTINGS.HubVisibilitySoundId or "") == "" then
        return
    end

    pcall(function()
        hubVisibilitySound:Stop()
        hubVisibilitySound.TimePosition = 0
        hubVisibilitySound.SoundId = tostring(SETTINGS.HubVisibilitySoundId)
        hubVisibilitySound.Volume = math.clamp(tonumber(SETTINGS.HubVisibilitySoundVolume) or 0.30, 0, 1)
        hubVisibilitySound.PlaybackSpeed = math.clamp(
            tonumber(opening and SETTINGS.HubOpenPlaybackSpeed or SETTINGS.HubClosePlaybackSpeed) or 1,
            0.25,
            3
        )
        hubVisibilitySound:Play()
    end)
end

local hubMusic = create("Sound", {
    Name = "CodexHubMusic",
    SoundId = tostring(SETTINGS.IntroPianoSoundId or ""),
    Volume = 0,
    PlaybackSpeed = math.clamp(tonumber(SETTINGS.IntroPianoPlaybackSpeed) or 1, 0.25, 3),
    Looped = true,
    PlayOnRemove = false,
}, SoundService)
local hubMusicTween = nil
local hubMusicVisibilityToken = 0

local function setHubMusicVisible(visible, restart)
    if not SETTINGS.IntroPianoEnabled or tostring(SETTINGS.IntroPianoSoundId or "") == "" or not hubMusic.Parent then
        return
    end
    hubMusicVisibilityToken += 1
    local token = hubMusicVisibilityToken
    if hubMusicTween then
        hubMusicTween:Cancel()
        hubMusicTween = nil
    end

    if visible then
        pcall(function()
            ContentProvider:PreloadAsync({hubMusic})
        end)
        if restart then
            hubMusic.TimePosition = 0
        end
        if not hubMusic.IsPlaying then
            pcall(function()
                hubMusic:Resume()
            end)
            if not hubMusic.IsPlaying then
                hubMusic:Play()
            end
        end
        hubMusicTween = TweenService:Create(hubMusic, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Volume = math.clamp(tonumber(SETTINGS.IntroPianoVolume) or 0.52, 0, 1),
        })
        hubMusicTween:Play()
        gui:SetAttribute("HubMusicVisible", true)
        gui:SetAttribute("HubMusicPlaying", hubMusic.IsPlaying)
    else
        hubMusicTween = TweenService:Create(hubMusic, TweenInfo.new(0.40, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Volume = 0,
        })
        hubMusicTween:Play()
        gui:SetAttribute("HubMusicVisible", false)
        task.delay(0.42, function()
            if token == hubMusicVisibilityToken and hubMusic.Parent then
                hubMusic:Pause()
                gui:SetAttribute("HubMusicPlaying", false)
            end
        end)
    end
end

local snowGui = create("ScreenGui", {
    Name = SETTINGS.GuiName .. "_Snow",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
    Enabled = SETTINGS.SnowEnabled,
}, gui.Parent)

local snowLayer = create("Frame", {
    Name = "SnowLayer",
    Active = false,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, snowGui)

local main = create("Frame", {
    Name = "CodexHub",
    Active = true,
    Visible = false,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(850, 560),
    BackgroundColor3 = COLORS.shell,
    BackgroundTransparency = hubTransparencyValue,
    BorderSizePixel = 0,
    ClipsDescendants = false,
}, gui)
addCorner(main, 12)
addStroke(main, COLORS.accentDark, 2, 0.05)
create("UIGradient", {
    Rotation = 28,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(250, 253, 255)),
        ColorSequenceKeypoint.new(0.48, Color3.fromRGB(229, 241, 248)),
        ColorSequenceKeypoint.new(0.72, Color3.fromRGB(211, 230, 240)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(190, 217, 231)),
    }),
}, main)

local uiScale = create("UIScale", {Scale = 1}, main)

local icicleLayer = create("Frame", {
    Name = "FrozenOuterEdge",
    Active = false,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    ZIndex = 80,
}, main)

do
    local function makeIceEdge(position, size)
        local glow = create("Frame", {
            Position = position,
            Size = size,
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.76,
            BorderSizePixel = 0,
            ZIndex = 80,
        }, icicleLayer)
        addCorner(glow, 4)

        local edge = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -2, 1, -2),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.20,
            BorderSizePixel = 0,
            ZIndex = 81,
        }, glow)
        addCorner(edge, 4)
        create("UIGradient", {
            Name = "FrozenAccentGradient",
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, COLORS.accentDark),
                ColorSequenceKeypoint.new(0.22, SNOW_WHITE),
                ColorSequenceKeypoint.new(0.52, COLORS.accent),
                ColorSequenceKeypoint.new(0.78, SNOW_WHITE),
                ColorSequenceKeypoint.new(1.00, COLORS.accentDark),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0.00, 0.18),
                NumberSequenceKeypoint.new(0.50, 0.46),
                NumberSequenceKeypoint.new(1.00, 0.18),
            }),
        }, edge)
    end

    makeIceEdge(UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 5))
    makeIceEdge(UDim2.new(0, 0, 1, -5), UDim2.new(1, 0, 0, 5))
    makeIceEdge(UDim2.fromOffset(0, 0), UDim2.new(0, 5, 1, 0))
    makeIceEdge(UDim2.new(1, -5, 0, 0), UDim2.new(0, 5, 1, 0))

    local function makeIcicle(index, xScale, yScale, width, height)
        local icicle = create("Frame", {
            Name = "Icicle" .. tostring(index),
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(xScale, 0, yScale, -1),
            Size = UDim2.fromOffset(width + 10, height + 8),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 82,
        }, icicleLayer)

        local glow = create("Frame", {
            Name = "SoftGlow",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromOffset(width + 4, math.max(7, height - 5)),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.76,
            BorderSizePixel = 0,
            ZIndex = 81,
        }, icicle)
        addCorner(glow, math.max(3, math.floor(width * 0.5)))

        local body = create("Frame", {
            Name = "CrystalBody",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromOffset(width, math.max(6, math.floor(height * 0.58))),
            BackgroundColor3 = SNOW_WHITE,
            BackgroundTransparency = 0.06,
            BorderSizePixel = 0,
            ZIndex = 82,
        }, icicle)
        addCorner(body, math.max(3, math.floor(width * 0.46)))
        create("UIGradient", {
            Name = "FrozenAccentGradient",
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, SNOW_WHITE),
                ColorSequenceKeypoint.new(0.58, COLORS.accent),
                ColorSequenceKeypoint.new(1.00, COLORS.accentDark),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0.00, 0.02),
                NumberSequenceKeypoint.new(0.72, 0.20),
                NumberSequenceKeypoint.new(1.00, 0.38),
            }),
        }, body)

        local taper = create("Frame", {
            Name = "CrystalTaper",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, math.floor(height * 0.46)),
            Size = UDim2.fromOffset(math.max(4, math.floor(width * 0.62)), math.max(7, math.floor(height * 0.43))),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.10,
            BorderSizePixel = 0,
            ZIndex = 83,
        }, icicle)
        addCorner(taper, math.max(2, math.floor(width * 0.32)))

        local tipSize = math.max(4, math.floor(width * 0.52))
        local tip = create("Frame", {
            Name = "CrystalPoint",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0, height - 2),
            Size = UDim2.fromOffset(tipSize, tipSize),
            BackgroundColor3 = COLORS.accentDark,
            BackgroundTransparency = 0.16,
            BorderSizePixel = 0,
            Rotation = 45,
            ZIndex = 84,
        }, icicle)
        addCorner(tip, math.max(1, math.floor(tipSize * 0.22)))

        local highlight = create("Frame", {
            Name = "IceHighlight",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, -math.max(1, math.floor(width * 0.18)), 0, 2),
            Size = UDim2.fromOffset(math.max(1, math.floor(width * 0.18)), math.max(4, math.floor(height * 0.30))),
            BackgroundColor3 = SNOW_WHITE,
            BackgroundTransparency = 0.22,
            BorderSizePixel = 0,
            ZIndex = 85,
        }, icicle)
        addCorner(highlight, 4)
    end

    local iceRandom = Random.new(20260721)
    for index = 1, 18 do
        local evenPosition = (index - 0.5) / 18
        local xScale = math.clamp(evenPosition + iceRandom:NextNumber(-0.018, 0.018), 0.012, 0.988)
        makeIcicle(index, xScale, 1, iceRandom:NextInteger(6, 11), iceRandom:NextInteger(15, 43))
    end

    local topPositions = {0.022, 0.050, 0.083, 0.155, 0.824, 0.874, 0.918, 0.952, 0.982}
    for index, xScale in ipairs(topPositions) do
        makeIcicle(18 + index, xScale, 0, iceRandom:NextInteger(5, 9), iceRandom:NextInteger(10, 25))
    end
end

local header = create("Frame", {
    Name = "Header",
    Active = true,
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = COLORS.sidebar,
    BackgroundTransparency = hubTransparencyValue,
    BorderSizePixel = 0,
    ZIndex = 20,
}, main)
addCorner(header, 12)
create("UIGradient", {
    Rotation = 0,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(252, 254, 255)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(229, 241, 248)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(207, 228, 239)),
    }),
}, header)

local brandLogo = create("Frame", {
    Name = "CodexLogo",
    Position = UDim2.fromOffset(13, 10),
    Size = UDim2.fromOffset(26, 26),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 21,
}, header)

-- Asset-free frozen Codex knot: six interlocking ice bars arranged as a pinwheel.
for segmentIndex = 1, 6 do
    local angle = math.rad((segmentIndex - 1) * 60)
    local segment = create("Frame", {
        Name = "KnotSegment" .. segmentIndex,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(13 + math.cos(angle) * 5.2, 13 + math.sin(angle) * 5.2),
        Size = UDim2.fromOffset(11, 4),
        BackgroundColor3 = COLORS.accent,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Rotation = math.deg(angle) + 34,
        ZIndex = 22,
    }, brandLogo)
    addCorner(segment, 2)
    create("UIGradient", {
        Name = "FrozenAccentGradient",
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, COLORS.accentDark),
            ColorSequenceKeypoint.new(0.52, COLORS.accent),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(232, 245, 251)),
        }),
    }, segment)
end

local knotCore = create("Frame", {
    Name = "KnotCore",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = Color3.fromRGB(193, 220, 233),
    BorderSizePixel = 0,
    Rotation = 45,
    ZIndex = 23,
}, brandLogo)
addCorner(knotCore, 2)
addStroke(knotCore, COLORS.accent, 1, 0.15)

local brandTitle = makeLabel(
    header,
    SETTINGS.Title,
    UDim2.fromOffset(47, 0),
    UDim2.fromOffset(105, 46),
    COLORS.text,
    15,
    Enum.Font.GothamSemibold
)
brandTitle.TextTruncate = Enum.TextTruncate.AtEnd
brandTitle.ZIndex = 21

local brandSubtitle = makeLabel(
    header,
    SETTINGS.Discord,
    UDim2.fromOffset(153, 1),
    UDim2.fromOffset(185, 44),
    COLORS.dim,
    11,
    Enum.Font.GothamMedium
)
brandSubtitle.ZIndex = 21

local minimizeButton = create("TextButton", {
    Name = "Minimize",
    AutoButtonColor = false,
    Position = UDim2.new(1, -76, 0, 7),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = COLORS.surface2,
    BackgroundTransparency = 0.38,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "-",
    TextColor3 = COLORS.muted,
    TextSize = 20,
    ZIndex = 22,
}, header)
addCorner(minimizeButton, 8)
addStroke(minimizeButton, COLORS.line, 1, 0.22)

local closeButton = create("TextButton", {
    Name = "Close",
    AutoButtonColor = false,
    Position = UDim2.new(1, -40, 0, 7),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = COLORS.surface2,
    BackgroundTransparency = 0.38,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "x",
    TextColor3 = COLORS.muted,
    TextSize = 17,
    ZIndex = 22,
}, header)
addCorner(closeButton, 8)
addStroke(closeButton, COLORS.line, 1, 0.22)

local sidebar = create("Frame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(0, 46),
    Size = UDim2.new(0, 62, 1, -46),
    BackgroundColor3 = COLORS.sidebar,
    BackgroundTransparency = 0.52,
    BorderSizePixel = 0,
}, main)
addCorner(sidebar, 12)
create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(247, 252, 255)),
        ColorSequenceKeypoint.new(0.58, Color3.fromRGB(220, 237, 245)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(198, 223, 235)),
    }),
}, sidebar)

create("Frame", {
    Position = UDim2.fromOffset(62, 46),
    Size = UDim2.new(0, 1, 1, -46),
    BackgroundColor3 = COLORS.line,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
}, main)

local contentBackdrop = create("Frame", {
    Name = "ConceptInterior",
    Position = UDim2.fromOffset(63, 46),
    Size = UDim2.new(1, -63, 1, -46),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = 0.56,
    BorderSizePixel = 0,
    ZIndex = 1,
}, main)
addCorner(contentBackdrop, 12)
create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(250, 253, 255)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(226, 240, 247)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(203, 226, 238)),
    }),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.08),
        NumberSequenceKeypoint.new(1.00, 0.30),
    }),
}, contentBackdrop)

local featuresLabel = makeLabel(sidebar, "", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), COLORS.dim, 10, Enum.Font.GothamBold)
featuresLabel.Visible = false

local navHolder = create("ScrollingFrame", {
    Name = "Navigation",
    Position = UDim2.fromOffset(7, 10),
    Size = UDim2.new(0, 48, 1, -72),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = COLORS.accentDark,
}, sidebar)
create("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, navHolder)

local avatarCard = create("Frame", {
    Name = "FloatingAvatarCard",
    Position = UDim2.fromOffset(76, 61),
    Size = UDim2.fromOffset(76, 76),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = 0.64,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    Visible = SETTINGS.AvatarPreviewEnabled,
    ZIndex = 5,
}, main)
addCorner(avatarCard, 8)
addStroke(avatarCard, COLORS.accentDark, 1, 0.48)
create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(253, 255, 255)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(224, 240, 248)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(198, 224, 237)),
    }),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.18),
        NumberSequenceKeypoint.new(1.00, 0.48),
    }),
}, avatarCard)

local avatarGlow = create("Frame", {
    Name = "AvatarGlow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(68, 68),
    BackgroundColor3 = COLORS.accent,
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    ZIndex = 6,
}, avatarCard)
addCorner(avatarGlow, 999)
create("UIGradient", {
    Name = "FrozenAccentGradient",
    Rotation = 45,
    Color = ColorSequence.new(
        SNOW_WHITE,
        Color3.fromRGB(133, 191, 217)
    ),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.28),
        NumberSequenceKeypoint.new(0.62, 0.62),
        NumberSequenceKeypoint.new(1.00, 1.00),
    }),
}, avatarGlow)

local avatarImage = create("ImageLabel", {
    Name = "AvatarPicture",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 4),
    Size = UDim2.fromOffset(68, 68),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "",
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 7,
}, avatarCard)

local avatarName = makeLabel(
    avatarCard,
    "@" .. LocalPlayer.Name,
    UDim2.new(0, 8, 1, -28),
    UDim2.new(1, -16, 0, 20),
    COLORS.text,
    11,
    Enum.Font.GothamSemibold
)
avatarName.TextXAlignment = Enum.TextXAlignment.Center
avatarName.TextTruncate = Enum.TextTruncate.AtEnd
avatarName.ZIndex = 8
avatarName.Visible = false

local currentHour = tonumber(os.date("%H")) or 12
local greetingText = currentHour < 12 and "Good morning" or (currentHour < 18 and "Good afternoon" or "Good evening")
local welcomeCard = create("Frame", {
    Name = "CodexWelcomeCard",
    Position = UDim2.fromOffset(162, 67),
    Size = UDim2.new(1, -178, 0, 64),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = 0.42,
    BorderSizePixel = 0,
    ZIndex = 5,
}, main)
addCorner(welcomeCard, 10)
addStroke(welcomeCard, COLORS.line, 1, 0.10)
create("UIGradient", {
    Rotation = 0,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(253, 255, 255)),
        ColorSequenceKeypoint.new(0.62, Color3.fromRGB(230, 242, 248)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(210, 231, 241)),
    }),
}, welcomeCard)

local headshotCard = create("Frame", {
    Name = "PlayerHeadshotCard",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -7, 0.5, 0),
    Size = UDim2.fromOffset(52, 52),
    BackgroundColor3 = COLORS.row,
    BackgroundTransparency = 0.26,
    BorderSizePixel = 0,
    Visible = SETTINGS.PlayerHeadshotEnabled,
    ZIndex = 7,
}, welcomeCard)
addCorner(headshotCard, 9)
addStroke(headshotCard, COLORS.accentDark, 1, 0.22)

local headshotImage = create("ImageLabel", {
    Name = "PlayerMugshot",
    Position = UDim2.fromOffset(3, 3),
    Size = UDim2.new(1, -6, 1, -6),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "",
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 8,
}, headshotCard)
addCorner(headshotImage, 7)

local welcomeTitle = makeLabel(
    welcomeCard,
    greetingText .. ", " .. LocalPlayer.DisplayName,
    UDim2.fromOffset(14, 8),
    UDim2.new(1, -88, 0, 27),
    COLORS.text,
    16,
    Enum.Font.GothamBold
)
welcomeTitle.ZIndex = 7
local welcomeSubtitle = makeLabel(
    welcomeCard,
    SETTINGS.Title .. " | Loading Game... | " .. SETTINGS.Discord,
    UDim2.fromOffset(14, 33),
    UDim2.new(1, -88, 0, 20),
    COLORS.muted,
    12,
    Enum.Font.GothamMedium
)
welcomeSubtitle.TextTruncate = Enum.TextTruncate.AtEnd
welcomeSubtitle.ZIndex = 7

local sidebarBrand = makeLabel(sidebar, SETTINGS.Title, UDim2.new(0, 16, 1, -54), UDim2.fromOffset(160, 20), COLORS.text, 13, Enum.Font.GothamSemibold)
local sidebarDiscord = makeLabel(sidebar, SETTINGS.Discord, UDim2.new(0, 16, 1, -34), UDim2.fromOffset(170, 18), COLORS.dim, 10, Enum.Font.GothamMedium)
sidebarBrand.Visible = false
sidebarDiscord.Visible = false

local searchFrame = create("Frame", {
    Name = "Search",
    Position = UDim2.fromOffset(350, 7),
    Size = UDim2.new(1, -465, 0, 32),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = 0.48,
    BorderSizePixel = 0,
    ZIndex = 25,
}, header)
addCorner(searchFrame, 8)
addStroke(searchFrame, COLORS.line, 1, 0.30)

local searchCircle = create("Frame", {
    Position = UDim2.fromOffset(13, 9),
    Size = UDim2.fromOffset(12, 12),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 26,
}, searchFrame)
addCorner(searchCircle, 7)
addStroke(searchCircle, COLORS.muted, 2, 0)

create("Frame", {
    Position = UDim2.fromOffset(23, 20),
    Size = UDim2.fromOffset(7, 2),
    Rotation = 45,
    BackgroundColor3 = COLORS.muted,
    BorderSizePixel = 0,
    ZIndex = 26,
}, searchFrame)

local searchBox = create("TextBox", {
    Name = "SearchBox",
    Position = UDim2.fromOffset(38, 0),
    Size = UDim2.new(1, -48, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.GothamMedium,
    PlaceholderText = "Search..",
    PlaceholderColor3 = COLORS.muted,
    Text = "",
    TextColor3 = COLORS.text,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 26,
}, searchFrame)

local pageHolder = create("Frame", {
    Name = "Pages",
    Position = UDim2.fromOffset(76, 151),
    Size = UDim2.new(1, -92, 1, -167),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, main)

local notificationGui = create("ScreenGui", {
    Name = SETTINGS.GuiName .. "_Notifications",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 1002,
}, gui.Parent)

local notificationHolder = create("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -20, 1, -20),
    Size = UDim2.fromOffset(350, 520),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 400,
}, notificationGui)
create("UIListLayout", {
    Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, notificationHolder)

local statusGui = create("ScreenGui", {
    Name = SETTINGS.GuiName .. "_Status",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 1003,
}, gui.Parent)

local statusFrame = create("Frame", {
    Name = "FloatingLiveStatus",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -24, 0, 72),
    Size = UDim2.fromOffset(360, 236),
    BackgroundColor3 = COLORS.shell,
    BackgroundTransparency = 0.13,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 500,
}, statusGui)
addCorner(statusFrame, 14)
local statusStroke = addStroke(statusFrame, COLORS.accentDark, 2, 0.08)
create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.surface),
        ColorSequenceKeypoint.new(0.55, COLORS.surface2),
        ColorSequenceKeypoint.new(1, COLORS.accentDark:Lerp(COLORS.shell, 0.55)),
    }),
    Rotation = 130,
}, statusFrame)

local statusHeader = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 502,
}, statusFrame)
local statusTitle = makeLabel(statusHeader, utf8.char(0x2744) .. "  CODEX LIVE STATUS", UDim2.fromOffset(14, 0), UDim2.new(1, -62, 1, 0), COLORS.text, 15, Enum.Font.GothamBold)
statusTitle.ZIndex = 503
local statusMinimizeButton = create("TextButton", {
    Name = "Minimize",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(34, 30),
    BackgroundColor3 = COLORS.row,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "-",
    TextColor3 = COLORS.text,
    TextSize = 20,
    ZIndex = 504,
}, statusHeader)
addCorner(statusMinimizeButton, 10)

local statusBody = create("Frame", {
    Name = "Body",
    Position = UDim2.fromOffset(10, 44),
    Size = UDim2.new(1, -20, 1, -54),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = 0.24,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 501,
}, statusFrame)
addCorner(statusBody, 10)
addStroke(statusBody, COLORS.line, 1, 0.35)

local statusWidgetLabels = {}
for index, key in ipairs({"General", "AFK", "Special", "Multi", "Farm", "Weapon"}) do
    local row = makeLabel(
        statusBody,
        key .. ": Waiting...",
        UDim2.fromOffset(12, 4 + (index - 1) * 29),
        UDim2.new(1, -24, 0, 27),
        index == 1 and COLORS.text or COLORS.muted,
        index == 1 and 13 or 12,
        index == 1 and Enum.Font.GothamBold or Enum.Font.GothamSemibold
    )
    row.TextTruncate = Enum.TextTruncate.AtEnd
    row.TextStrokeColor3 = Color3.fromRGB(238, 250, 255)
    row.TextStrokeTransparency = 0.64
    row.ZIndex = 503
    statusWidgetLabels[key] = row
end

local statusFlakes = {}
local statusRandom = Random.new()
for index = 1, 10 do
    local flake = makeLabel(statusFrame, utf8.char(index % 3 == 0 and 0x2746 or 0x2744), UDim2.fromOffset(0, 0), UDim2.fromOffset(24, 24), SNOW_WHITE, statusRandom:NextInteger(13, 22), Enum.Font.GothamBold)
    flake.Name = "StatusSnowflake" .. index
    flake.TextXAlignment = Enum.TextXAlignment.Center
    flake.TextTransparency = 0.18
    flake.TextStrokeColor3 = COLORS.accentDark
    flake.TextStrokeTransparency = 0.56
    flake.ZIndex = 502
    table.insert(statusFlakes, flake)
    task.spawn(function()
        while statusGui.Parent and flake.Parent do
            flake.Position = UDim2.fromOffset(statusRandom:NextInteger(4, 332), statusRandom:NextInteger(-35, -10))
            flake.Rotation = statusRandom:NextInteger(-35, 35)
            local tween = TweenService:Create(flake, TweenInfo.new(statusRandom:NextNumber(3.4, 6.4), Enum.EasingStyle.Linear), {
                Position = UDim2.fromOffset(statusRandom:NextInteger(4, 332), 240),
                Rotation = flake.Rotation + statusRandom:NextInteger(80, 220),
            })
            tween:Play()
            tween.Completed:Wait()
            task.wait(statusRandom:NextNumber(0.08, 0.55))
        end
    end)
end

local statusMinimized = false
local statusDragging = false
local statusDragMoved = false
local statusDragStart = nil
local statusDragPosition = nil
local function clampStatusWidget(position, size)
    local camera = workspace.CurrentCamera
    if not camera then return position end
    local viewport = camera.ViewportSize
    local width = size.X.Offset
    local height = size.Y.Offset
    local x = viewport.X * position.X.Scale + position.X.Offset
    local y = viewport.Y * position.Y.Scale + position.Y.Offset
    return UDim2.fromOffset(
        math.clamp(x, width + 8, viewport.X - 8),
        math.clamp(y, 8, math.max(8, viewport.Y - height - 8))
    )
end

local function setStatusMinimized(value)
    statusMinimized = value == true
    statusTitle.Visible = not statusMinimized
    statusBody.Visible = not statusMinimized
    for _, flake in ipairs(statusFlakes) do
        flake.Visible = not statusMinimized
    end
    if statusMinimized then
        statusFrame.Size = UDim2.fromOffset(58, 58)
        statusFrame.BackgroundTransparency = 0.05
        statusMinimizeButton.Parent = statusFrame
        statusMinimizeButton.AnchorPoint = Vector2.new(0, 0)
        statusMinimizeButton.Position = UDim2.fromOffset(0, 0)
        statusMinimizeButton.Size = UDim2.fromScale(1, 1)
        statusMinimizeButton.BackgroundTransparency = 1
        statusMinimizeButton.Text = utf8.char(0x2744)
        statusMinimizeButton.TextSize = 31
        statusStroke.Thickness = 2.5
    else
        statusFrame.Size = UDim2.fromOffset(360, 236)
        statusFrame.BackgroundTransparency = 0.13
        statusMinimizeButton.Parent = statusHeader
        statusMinimizeButton.AnchorPoint = Vector2.new(1, 0.5)
        statusMinimizeButton.Position = UDim2.new(1, -8, 0.5, 0)
        statusMinimizeButton.Size = UDim2.fromOffset(34, 30)
        statusMinimizeButton.BackgroundTransparency = 0.15
        statusMinimizeButton.Text = "-"
        statusMinimizeButton.TextSize = 20
        statusStroke.Thickness = 2
    end
    statusFrame.Position = clampStatusWidget(statusFrame.Position, statusFrame.Size)
end

local function beginStatusDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        statusDragging = true
        statusDragMoved = false
        statusDragStart = input.Position
        statusDragPosition = statusFrame.Position
    end
end
track(statusHeader.InputBegan:Connect(beginStatusDrag))
track(statusMinimizeButton.InputBegan:Connect(function(input)
    if statusMinimized then beginStatusDrag(input) end
end))
track(UserInputService.InputChanged:Connect(function(input)
    if statusDragging and statusDragStart and statusDragPosition and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - statusDragStart
        if delta.Magnitude > 5 then
            statusDragMoved = true
        end
        local proposed = UDim2.new(statusDragPosition.X.Scale, statusDragPosition.X.Offset + delta.X, statusDragPosition.Y.Scale, statusDragPosition.Y.Offset + delta.Y)
        statusFrame.Position = clampStatusWidget(proposed, statusFrame.Size)
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        statusDragging = false
        statusDragStart = nil
        statusDragPosition = nil
    end
end))
track(statusMinimizeButton.MouseButton1Click:Connect(function()
    if statusDragMoved then
        statusDragMoved = false
        return
    end
    playToggleClick(not statusMinimized)
    setStatusMinimized(not statusMinimized)
end))

local Window = {
    Gui = gui,
    SnowGui = snowGui,
    NotificationGui = notificationGui,
    StatusGui = statusGui,
    NotificationHolder = notificationHolder,
    Main = main,
    Pages = {},
    ActivePage = nil,
    Minimized = false,
    PersistentControls = {},
}

local hubVisible = true

function Window:SetVisible(visible)
    hubVisible = visible == true
    if hubVisible and self.ClampToViewport then
        self:ClampToViewport(Window.Minimized and UDim2.fromOffset(850, 46) or UDim2.fromOffset(850, 560))
    end
    gui.Enabled = hubVisible
    snowGui.Enabled = SETTINGS.SnowEnabled and hubVisible
    setHubMusicVisible(hubVisible, false)
end

function Window:ToggleVisible()
    local opening = not hubVisible
    playHubVisibilitySound(opening)
    self:SetVisible(opening)
end

local function loadProfileImage()
    if not SETTINGS.AvatarPreviewEnabled then
        return
    end

    local logoImageId = tostring(SETTINGS.ProfileLogoImageId or "")
    if logoImageId ~= "" then
        avatarImage.Image = logoImageId
        return
    end

    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.AvatarThumbnail,
                Enum.ThumbnailSize.Size420x420
            )
        end)
        if ok and avatarImage.Parent then
            avatarImage.Image = image
        end
    end)
end

loadProfileImage()
if tostring(SETTINGS.ProfileLogoImageId or "") == "" then
    track(LocalPlayer.CharacterAppearanceLoaded:Connect(loadProfileImage))
end

local function loadPlayerHeadshot()
    if not SETTINGS.PlayerHeadshotEnabled then
        return
    end

    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size420x420
            )
        end)
        if ok and headshotImage.Parent then
            headshotImage.Image = image
        end
    end)
end

loadPlayerHeadshot()
track(LocalPlayer.CharacterAppearanceLoaded:Connect(loadPlayerHeadshot))

local avatarFloatClock = 0
track(RunService.RenderStepped:Connect(function(deltaTime)
    if not SETTINGS.AvatarPreviewEnabled or not hubVisible or not main.Visible or not sidebar.Visible or not avatarCard.Visible then
        return
    end

    avatarFloatClock = avatarFloatClock + math.min(deltaTime, 0.05)
    local verticalFloat = math.sin(avatarFloatClock * 1.75) * 3
    local horizontalFloat = math.sin(avatarFloatClock * 0.82) * 2
    local sway = math.sin(avatarFloatClock * 0.95) * 1.8
    local glowPulse = (math.sin(avatarFloatClock * 1.45) + 1) * 0.5

    avatarImage.Position = UDim2.new(0.5, horizontalFloat, 0, 4 + verticalFloat)
    avatarImage.Rotation = sway
    avatarGlow.Size = UDim2.fromOffset(64 + glowPulse * 8, 64 + glowPulse * 8)
    avatarGlow.BackgroundTransparency = 0.82 - glowPulse * 0.12
end))

local function startSnowfall()
    if not SETTINGS.SnowEnabled then
        return
    end

    local random = Random.new()
    local symbols = {
        utf8.char(0x2744),
        utf8.char(0x2745),
        utf8.char(0x2746),
    }
    local count = math.clamp(math.floor(tonumber(SETTINGS.SnowflakeCount) or 52), 18, 64)

    for index = 1, count do
        local flake = create("TextLabel", {
            Name = "Snowflake" .. tostring(index),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(64, 64),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            Text = symbols[random:NextInteger(1, #symbols)],
            TextColor3 = SNOW_WHITE,
            TextStrokeColor3 = COLORS.accentDark,
            TextStrokeTransparency = 0.34,
            TextTransparency = random:NextNumber(0.01, 0.18),
            TextSize = random:NextInteger(26, 54),
            Visible = false,
            ZIndex = 2,
        }, snowLayer)
        create("ImageLabel", {
            Name = "FrozenGlow",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.45, 1.45),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Image = "rbxasset://textures/particles/sparkles_main.dds",
            ImageColor3 = COLORS.accent,
            ImageTransparency = 0.40,
            ZIndex = 1,
        }, flake)

        task.spawn(function()
            task.wait(random:NextNumber(0, 2.5))
            while snowGui.Parent do
                while snowGui.Parent and not hubVisible do
                    flake.Visible = false
                    task.wait(0.15)
                end
                if not snowGui.Parent then
                    break
                end

                local startX = random:NextNumber(0.01, 0.99)
                local endX = math.clamp(startX + random:NextNumber(-0.18, 0.18), 0.01, 0.99)
                local duration = random:NextNumber(4.8, 9.2)
                flake.Text = symbols[random:NextInteger(1, #symbols)]
                flake.TextSize = random:NextInteger(26, 54)
                flake.TextTransparency = random:NextNumber(0.01, 0.18)
                flake.Position = UDim2.new(startX, 0, 0, -68)
                flake.Rotation = random:NextInteger(-35, 35)
                flake.Visible = true

                local fall = TweenService:Create(
                    flake,
                    TweenInfo.new(duration, Enum.EasingStyle.Linear),
                    {
                        Position = UDim2.new(endX, 0, 1, 68),
                        Rotation = flake.Rotation + random:NextInteger(90, 260),
                    }
                )
                fall:Play()

                while snowGui.Parent and hubVisible and fall.PlaybackState == Enum.PlaybackState.Playing do
                    task.wait(0.10)
                end
                if not hubVisible then
                    fall:Cancel()
                end
                flake.Visible = false
                task.wait(random:NextNumber(0.05, 0.45))
            end
        end)
    end
end

startSnowfall()

local function shadeColor(color, factor)
    return Color3.new(
        math.clamp(color.R * factor, 0, 1),
        math.clamp(color.G * factor, 0, 1),
        math.clamp(color.B * factor, 0, 1)
    )
end

local function replaceThemeColor(root, oldColor, newColor)
    local properties = {
        "BackgroundColor3",
        "TextColor3",
        "TextStrokeColor3",
        "ImageColor3",
        "ScrollBarImageColor3",
        "BorderColor3",
        "Color",
    }
    local objects = {root}
    for _, descendant in ipairs(root:GetDescendants()) do
        table.insert(objects, descendant)
    end

    for _, object in ipairs(objects) do
        for _, property in ipairs(properties) do
            local ok, current = pcall(function()
                return object[property]
            end)
            if ok and current == oldColor then
                pcall(function()
                    object[property] = newColor
                end)
            end
        end
    end
end

local function applyFrozenAccent(newAccent)
    local oldAccent = COLORS.accent
    local oldAccentDark = COLORS.accentDark
    local oldLine = COLORS.line
    local newAccentDark = shadeColor(newAccent, 0.58)
    local newLine = newAccent:Lerp(newAccentDark, 0.38)

    replaceThemeColor(gui, oldAccent, newAccent)
    replaceThemeColor(gui, oldAccentDark, newAccentDark)
    replaceThemeColor(gui, oldLine, newLine)
    replaceThemeColor(snowGui, oldAccent, newAccent)
    replaceThemeColor(snowGui, oldAccentDark, newAccentDark)
    replaceThemeColor(snowGui, oldLine, newLine)

    COLORS.accent = newAccent
    COLORS.accentDark = newAccentDark
    COLORS.line = newLine

    for _, root in ipairs({gui, snowGui}) do
        for _, descendant in ipairs(root:GetDescendants()) do
            if descendant:IsA("UIGradient") and descendant.Name == "FrozenAccentGradient" then
                descendant.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, newAccent:Lerp(Color3.new(1, 1, 1), 0.68)),
                    ColorSequenceKeypoint.new(0.55, newAccent),
                    ColorSequenceKeypoint.new(1.00, newAccentDark),
                })
            end
        end
    end
end

local function applyHubTransparency(value)
    hubTransparencyValue = math.clamp(tonumber(value) or 0.46, 0.10, 0.80)
    local offsets = {
        CodexHub = 0.00,
        Header = 0.00,
        Sidebar = 0.06,
        ConceptInterior = 0.10,
        FloatingAvatarCard = 0.18,
        PlayerHeadshotCard = 0.08,
        CodexWelcomeCard = -0.04,
        Search = 0.02,
        SectionCard = -0.06,
        ControlRow = -0.16,
        DropdownRow = -0.16,
    }

    local objects = {main}
    for _, descendant in ipairs(main:GetDescendants()) do
        table.insert(objects, descendant)
    end
    for _, object in ipairs(objects) do
        local offset = offsets[object.Name]
        if offset and object:IsA("GuiObject") then
            object.BackgroundTransparency = math.clamp(hubTransparencyValue + offset, 0, 0.92)
        end
    end
end


local function makeFlag(text)
    local flag = string.lower(tostring(text or "control"))
    flag = flag:gsub("[^%w_%-]", "_"):gsub("_+", "_")
    flag = flag:gsub("^_+", ""):gsub("_+$", "")
    return flag ~= "" and flag or "control"
end

local function registerPersistentControl(section, name, options, control)
    if options.Persist == false then
        return control
    end

    local baseFlag = makeFlag(options.Flag or (section.Page.Name .. "_" .. section.Title .. "_" .. name))
    local flag = baseFlag
    local suffix = 2
    while Window.PersistentControls[flag] do
        flag = baseFlag .. "_" .. tostring(suffix)
        suffix = suffix + 1
    end

    control.Flag = flag
    Window.PersistentControls[flag] = control
    return control
end

function Window:Notify(title, message, duration)
    duration = math.max(tonumber(duration) or 3, 1)
    local notification = create("Frame", {
        Size = UDim2.fromOffset(338, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(13, 34, 48),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = 401,
    }, notificationHolder)
    addCorner(notification, 10)
    addStroke(notification, Color3.fromRGB(151, 224, 255), 1.5, 0.12)
    local frostGradient = create("UIGradient", {
        Rotation = 18,
        Offset = Vector2.new(-0.55, 0),
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(9, 29, 43)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(28, 72, 96)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(117, 191, 222)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 0.02),
            NumberSequenceKeypoint.new(0.65, 0.18),
            NumberSequenceKeypoint.new(1.00, 0.38),
        }),
    }, notification)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 11),
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),
    }, notification)
    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, notification)

    local titleLabel = makeLabel(notification, "❄  " .. tostring(title or SETTINGS.Title), nil, UDim2.new(1, 0, 0, 22), Color3.fromRGB(239, 251, 255), 15, Enum.Font.GothamBold)
    titleLabel.LayoutOrder = 1
    titleLabel.ZIndex = 402

    local messageLabel = makeLabel(notification, message or "", nil, UDim2.new(1, 0, 0, 0), Color3.fromRGB(190, 226, 242), 12, Enum.Font.GothamMedium)
    messageLabel.LayoutOrder = 2
    messageLabel.AutomaticSize = Enum.AutomaticSize.Y
    messageLabel.TextWrapped = true
    messageLabel.ZIndex = 402

    local timerTrack = create("Frame", {
        LayoutOrder = 3,
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Color3.fromRGB(54, 92, 112),
        BackgroundTransparency = 0.22,
        BorderSizePixel = 0,
        ZIndex = 402,
    }, notification)
    addCorner(timerTrack, 2)
    local timerBar = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(177, 234, 255),
        BorderSizePixel = 0,
        ZIndex = 403,
    }, timerTrack)
    addCorner(timerBar, 2)
    local notificationScale = create("UIScale", {Scale = 0.92}, notification)

    notification.BackgroundTransparency = 1
    titleLabel.TextTransparency = 1
    messageLabel.TextTransparency = 1

    TweenService:Create(notification, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.08}):Play()
    TweenService:Create(notificationScale, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    TweenService:Create(titleLabel, TweenInfo.new(0.22), {TextTransparency = 0}):Play()
    TweenService:Create(messageLabel, TweenInfo.new(0.22), {TextTransparency = 0}):Play()
    TweenService:Create(frostGradient, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Offset = Vector2.new(0.55, 0)}):Play()
    TweenService:Create(timerBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)}):Play()

    task.delay(duration, function()
        if not notification.Parent then
            return
        end

        local fade = TweenService:Create(notification, TweenInfo.new(0.20), {BackgroundTransparency = 1})
        fade:Play()
        TweenService:Create(notificationScale, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.95}):Play()
        TweenService:Create(titleLabel, TweenInfo.new(0.20), {TextTransparency = 1}):Play()
        TweenService:Create(messageLabel, TweenInfo.new(0.20), {TextTransparency = 1}):Play()
        fade.Completed:Wait()
        if notification.Parent then
            notification:Destroy()
        end
    end)
    return notification
end

local function registerSearchItem(page, object, text)
    table.insert(page.SearchItems, {
        Object = object,
        Text = string.lower(tostring(text or "")),
    })
end

local function makeControlRow(section, height)
    section.NextOrder = section.NextOrder + 1
    local row = create("Frame", {
        Name = "ControlRow",
        LayoutOrder = section.NextOrder,
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = COLORS.row,
        BackgroundTransparency = math.max(0.15, hubTransparencyValue - 0.16),
        BorderSizePixel = 0,
    }, section.Body)
    addCorner(row, 7)
    addStroke(row, COLORS.line, 1, 0.72)
    return row
end

local SectionMethods = {}

function SectionMethods:AddLabel(text)
    local row = makeControlRow(self, 36)
    local label = makeLabel(row, text, UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), COLORS.muted, 13, Enum.Font.GothamMedium)
    label.TextWrapped = true
    label.TextStrokeColor3 = Color3.fromRGB(238, 250, 255)
    label.TextStrokeTransparency = 0.72
    registerSearchItem(self.Page, row, text)
    return label
end

function SectionMethods:AddButton(options)
    options = options or {}
    local name = options.Name or "Button"
    local description = options.Description or ""
    local row = makeControlRow(self, description ~= "" and 52 or 40)

    local title = makeLabel(row, name, UDim2.fromOffset(12, description ~= "" and 5 or 0), UDim2.new(1, -50, 0, 30), COLORS.text, 13, Enum.Font.GothamSemibold)
    local descriptionLabel = nil
    if description ~= "" then
        descriptionLabel = makeLabel(row, description, UDim2.fromOffset(12, 31), UDim2.new(1, -50, 0, 18), COLORS.dim, 11, Enum.Font.GothamMedium)
        descriptionLabel.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local arrow = makeLabel(row, ">", UDim2.new(1, -36, 0, 0), UDim2.fromOffset(24, row.Size.Y.Offset), COLORS.accent, 18, Enum.Font.GothamBold)
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local button = create("TextButton", {
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, row)

    track(button.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = math.max(0, hubTransparencyValue - 0.18)}):Play()
    end))
    track(button.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = math.max(0, hubTransparencyValue - 0.10)}):Play()
    end))
    track(button.MouseButton1Click:Connect(function()
        safeCallback(options.Callback)
    end))

    registerSearchItem(self.Page, row, name .. " " .. description)

    return {
        Fire = function()
            safeCallback(options.Callback)
        end,
        SetText = function(_, newText)
            title.Text = tostring(newText)
        end,
        SetDescription = function(_, newDescription)
            if descriptionLabel then
                descriptionLabel.Text = tostring(newDescription)
            end
        end,
    }
end

function SectionMethods:AddToggle(options)
    options = options or {}
    local name = options.Name or "Toggle"
    local description = options.Description or ""
    local state = options.Default == true
    local row = makeControlRow(self, description ~= "" and 52 or 40)

    makeLabel(row, name, UDim2.fromOffset(12, description ~= "" and 5 or 0), UDim2.new(1, -80, 0, 30), COLORS.text, 13, Enum.Font.GothamSemibold)
    if description ~= "" then
        local descriptionLabel = makeLabel(row, description, UDim2.fromOffset(12, 31), UDim2.new(1, -90, 0, 18), COLORS.dim, 11, Enum.Font.GothamMedium)
        descriptionLabel.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local trackFrame = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(44, 22),
        BackgroundColor3 = COLORS.offTrack,
        BorderSizePixel = 0,
    }, row)
    addCorner(trackFrame, 11)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = COLORS.knob,
        BorderSizePixel = 0,
    }, trackFrame)
    addCorner(knob, 8)

    local button = create("TextButton", {
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, row)

    local control = {}
    function control:Set(value, silent)
        state = value == true
        local trackColor = state and COLORS.accent or COLORS.offTrack
        local knobPosition = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        TweenService:Create(trackFrame, TweenInfo.new(0.16), {BackgroundColor3 = trackColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {Position = knobPosition}):Play()
        if not silent then
            safeCallback(options.Callback, state)
        end
    end
    function control:Get()
        return state
    end

    track(button.MouseButton1Click:Connect(function()
        local nextState = not state
        playToggleClick(nextState)
        control:Set(nextState)
    end))
    control:Set(state, true)
    registerSearchItem(self.Page, row, name .. " " .. description)
    return registerPersistentControl(self, name, options, control)
end

function SectionMethods:AddDropdown(options)
    options = options or {}
    local name = options.Name or "Dropdown"
    local values = options.Options or {}
    local selected = options.Default
    local open = false

    self.NextOrder = self.NextOrder + 1
    local row = create("Frame", {
        Name = "DropdownRow",
        LayoutOrder = self.NextOrder,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = COLORS.row,
        BackgroundTransparency = math.max(0.15, hubTransparencyValue - 0.16),
        BorderSizePixel = 0,
    }, self.Body)
    addCorner(row, 7)
    addStroke(row, COLORS.line, 1, 0.72)
    create("UIListLayout", {
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)

    local top = create("Frame", {
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, row)
    makeLabel(top, name, UDim2.fromOffset(12, 3), UDim2.new(1, -40, 0, 24), COLORS.text, 12, Enum.Font.GothamSemibold)
    local valueLabel = makeLabel(top, selected and tostring(selected) or (options.Placeholder or "Select..."), UDim2.fromOffset(12, 25), UDim2.new(1, -50, 0, 24), selected and COLORS.text or COLORS.dim, 13, Enum.Font.GothamMedium)
    local arrow = makeLabel(top, "v", UDim2.new(1, -36, 0, 20), UDim2.fromOffset(24, 26), COLORS.accent, 14, Enum.Font.GothamBold)
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local topButton = create("TextButton", {
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, top)

    local optionHolder = create("Frame", {
        LayoutOrder = 2,
        Visible = false,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = COLORS.dropdown,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
    }, row)
    create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, optionHolder)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
    }, optionHolder)

    local control = {}

    local function setOpen(value)
        open = value == true
        optionHolder.Visible = open
        arrow.Text = open and "^" or "v"
    end

    local function rebuildOptions()
        for _, child in ipairs(optionHolder:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for index, value in ipairs(values) do
            local optionButton = create("TextButton", {
                LayoutOrder = index,
                AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = COLORS.row,
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                Font = Enum.Font.GothamMedium,
                Text = "  " .. tostring(value),
                TextColor3 = COLORS.muted,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, optionHolder)
            addCorner(optionButton, 4)
            track(optionButton.MouseButton1Click:Connect(function()
                control:Set(value)
                setOpen(false)
            end))
        end
    end

    function control:Set(value, silent)
        selected = value
        valueLabel.Text = value == nil and (options.Placeholder or "Select...") or tostring(value)
        valueLabel.TextColor3 = value == nil and COLORS.dim or COLORS.text
        if not silent then
            safeCallback(options.Callback, selected)
        end
    end
    function control:Get()
        return selected
    end
    function control:SetOptions(newOptions, keepSelection)
        values = newOptions or {}
        if not keepSelection then
            control:Set(nil, true)
        end
        rebuildOptions()
    end
    function control:Close()
        setOpen(false)
    end

    track(topButton.MouseButton1Click:Connect(function()
        setOpen(not open)
    end))

    rebuildOptions()
    control:Set(selected, true)
    registerSearchItem(self.Page, row, name)
    return registerPersistentControl(self, name, options, control)
end

function SectionMethods:AddSlider(options)
    options = options or {}
    local name = options.Name or "Slider"
    local minimum = tonumber(options.Min) or 0
    local maximum = tonumber(options.Max) or 100
    local step = math.max(tonumber(options.Step) or 1, 0.0001)
    local value = math.clamp(tonumber(options.Default) or minimum, minimum, maximum)
    local dragging = false

    local row = makeControlRow(self, 64)
    makeLabel(row, name, UDim2.fromOffset(12, 4), UDim2.new(1, -90, 0, 28), COLORS.text, 13, Enum.Font.GothamSemibold)
    local valueLabel = makeLabel(row, "", UDim2.new(1, -82, 0, 4), UDim2.fromOffset(70, 28), COLORS.accent, 12, Enum.Font.GothamSemibold)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local bar = create("Frame", {
        Position = UDim2.fromOffset(12, 47),
        Size = UDim2.new(1, -24, 0, 6),
        BackgroundColor3 = COLORS.offTrack,
        BorderSizePixel = 0,
    }, row)
    addCorner(bar, 3)
    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = COLORS.accent,
        BorderSizePixel = 0,
    }, bar)
    addCorner(fill, 3)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = COLORS.knob,
        BorderSizePixel = 0,
    }, bar)
    addCorner(knob, 7)

    local hitbox = create("TextButton", {
        AutoButtonColor = false,
        Position = UDim2.fromOffset(0, -10),
        Size = UDim2.new(1, 0, 1, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, bar)

    local function formatValue(number)
        if step >= 1 then
            return tostring(math.floor(number + 0.5))
        end
        local formatted = string.format("%.2f", number)
        formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
        return formatted
    end

    local control = {}
    function control:Set(newValue, silent)
        local numeric = math.clamp(tonumber(newValue) or minimum, minimum, maximum)
        numeric = minimum + math.floor(((numeric - minimum) / step) + 0.5) * step
        value = math.clamp(numeric, minimum, maximum)
        local alpha = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.fromScale(alpha, 0.5)
        valueLabel.Text = formatValue(value)
        if not silent then
            safeCallback(options.Callback, value)
        end
    end
    function control:Get()
        return value
    end

    local function updateFromInput(input)
        if bar.AbsoluteSize.X <= 0 then
            return
        end
        local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        control:Set(minimum + (maximum - minimum) * alpha)
    end

    track(hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromInput(input)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    control:Set(value, true)
    registerSearchItem(self.Page, row, name)
    return registerPersistentControl(self, name, options, control)
end

function SectionMethods:AddInput(options)
    options = options or {}
    local name = options.Name or "Input"
    local row = makeControlRow(self, 68)
    makeLabel(row, name, UDim2.fromOffset(12, 2), UDim2.new(1, -24, 0, 27), COLORS.text, 12, Enum.Font.GothamSemibold)

    local box = create("TextBox", {
        Position = UDim2.fromOffset(10, 33),
        Size = UDim2.new(1, -20, 0, 34),
        BackgroundColor3 = COLORS.dropdown,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ClearTextOnFocus = options.ClearOnFocus == true,
        Font = Enum.Font.GothamMedium,
        PlaceholderText = options.Placeholder or "Enter text...",
        PlaceholderColor3 = COLORS.dim,
        Text = tostring(options.Default or ""),
        TextColor3 = COLORS.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    addCorner(box, 4)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, box)

    track(box.FocusLost:Connect(function(enterPressed)
        safeCallback(options.Callback, box.Text, enterPressed)
    end))

    registerSearchItem(self.Page, row, name)
    local control = {
        Get = function()
            return box.Text
        end,
        Set = function(_, value)
            box.Text = tostring(value or "")
        end,
        Box = box,
    }
    return registerPersistentControl(self, name, options, control)
end

local PageMethods = {}
local NAV_ICONS = {
    Home = utf8.char(0x2302),
    Tools = utf8.char(0x2692),
    Settings = utf8.char(0x2699),
}

function PageMethods:AddSection(title, side)
    local selectedSide = side
    if selectedSide ~= "Left" and selectedSide ~= "Right" then
        selectedSide = self.NextSide
        self.NextSide = self.NextSide == "Left" and "Right" or "Left"
    end

    local parentColumn = selectedSide == "Right" and self.RightColumn or self.LeftColumn
    local card = create("Frame", {
        Name = "SectionCard",
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = COLORS.surface,
        BackgroundTransparency = math.max(0, hubTransparencyValue - 0.06),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, parentColumn)
    addCorner(card, 10)
    addStroke(card, COLORS.line, 1, 0.46)
    create("UIListLayout", {
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, card)

    local sectionHeader = create("Frame", {
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, card)
    makeLabel(sectionHeader, title or "Section", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, -2), COLORS.text, 14, Enum.Font.GothamBold)
    create("Frame", {
        Position = UDim2.new(0, 12, 1, -1),
        Size = UDim2.new(1, -24, 0, 1),
        BackgroundColor3 = COLORS.line,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
    }, sectionHeader)

    local body = create("Frame", {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, card)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    }, body)
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, body)

    local section = {
        Page = self,
        Title = title or "Section",
        Card = card,
        Body = body,
        NextOrder = 0,
    }
    return setmetatable(section, {__index = SectionMethods})
end

function Window:AddPage(name)
    assert(type(name) == "string" and name ~= "", "Page name must be a non-empty string")
    if self.Pages[name] then
        return self.Pages[name]
    end

    local navRow = create("Frame", {
        Size = UDim2.fromOffset(48, 44),
        BackgroundColor3 = COLORS.surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, navHolder)
    addCorner(navRow, 7)
    local accent = create("Frame", {
        Position = UDim2.fromOffset(0, 10),
        Size = UDim2.fromOffset(4, 24),
        BackgroundColor3 = COLORS.accentDark,
        BorderSizePixel = 0,
        Visible = false,
    }, navRow)
    addCorner(accent, 2)
    local navIconSize = name == "Home" and 30 or 20
    local navText = makeLabel(navRow, NAV_ICONS[name] or string.sub(name, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), COLORS.muted, navIconSize, Enum.Font.GothamBold)
    navText.TextXAlignment = Enum.TextXAlignment.Center
    local navButton = create("TextButton", {
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, navRow)

    local pageFrame = create("Frame", {
        Name = name .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
    }, pageHolder)

    local leftColumn = create("ScrollingFrame", {
        Name = "LeftColumn",
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accentDark,
    }, pageFrame)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, leftColumn)

    local rightColumn = create("ScrollingFrame", {
        Name = "RightColumn",
        Position = UDim2.new(0.5, 6, 0, 0),
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accentDark,
    }, pageFrame)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, rightColumn)

    local page = setmetatable({
        Name = name,
        Frame = pageFrame,
        NavRow = navRow,
        NavAccent = accent,
        NavText = navText,
        LeftColumn = leftColumn,
        RightColumn = rightColumn,
        SearchItems = {},
        NextSide = "Left",
    }, {__index = PageMethods})
    self.Pages[name] = page

    track(navButton.MouseButton1Click:Connect(function()
        self:SelectPage(name)
    end))

    if not self.ActivePage then
        self:SelectPage(name)
    end
    return page
end

function Window:SelectPage(name)
    local target = self.Pages[name]
    if not target then
        return false
    end

    for _, page in pairs(self.Pages) do
        local active = page == target
        page.Frame.Visible = active
        page.NavAccent.Visible = active
        page.NavRow.BackgroundColor3 = active and COLORS.accentDark:Lerp(SNOW_WHITE, 0.30) or COLORS.surface
        page.NavRow.BackgroundTransparency = active and 0.18 or 1
        page.NavText.TextColor3 = active and COLORS.text or COLORS.muted
        page.NavText.TextStrokeColor3 = SNOW_WHITE
        page.NavText.TextStrokeTransparency = active and 0.72 or 1
    end

    self.ActivePage = target
    searchBox.Text = ""
    return true
end

local function hasProfileFileApi()
    return type(isfolder) == "function"
        and type(makefolder) == "function"
        and type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"
end

local function ensureFolder(path)
    local current = ""
    for segment in string.gmatch(path, "[^/]+") do
        current = current == "" and segment or (current .. "/" .. segment)
        if not isfolder(current) then
            makefolder(current)
        end
    end
end

local function sanitizeProfileName(name)
    local cleaned = tostring(name or "")
    cleaned = cleaned:gsub("[^%w%s_%-]", ""):gsub("%s+", " ")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
    return string.sub(cleaned, 1, 40)
end

local function getProfilePath(name)
    return PROFILE_FOLDER .. "/" .. sanitizeProfileName(name) .. ".json"
end

function Window:ProfilesAvailable()
    return hasProfileFileApi()
end

function Window:GetProfileNames()
    if not hasProfileFileApi() or type(listfiles) ~= "function" then
        return {}
    end

    local ok, files = pcall(function()
        ensureFolder(PROFILE_FOLDER)
        return listfiles(PROFILE_FOLDER)
    end)
    if not ok or type(files) ~= "table" then
        return {}
    end

    local names = {}
    for _, path in ipairs(files) do
        local name = tostring(path):match("([^/\\]+)%.json$")
        if name and name ~= "" then
            table.insert(names, name)
        end
    end
    table.sort(names, function(left, right)
        return string.lower(left) < string.lower(right)
    end)
    return names
end

function Window:SaveProfile(name)
    if not hasProfileFileApi() then
        return false, "Executor file API is unavailable"
    end

    local profile = sanitizeProfileName(name)
    if profile == "" then
        return false, "Enter a profile name"
    end

    local values = {}
    for flag, control in pairs(self.PersistentControls) do
        local ok, value = pcall(function()
            return control:Get()
        end)
        if ok and value ~= nil then
            values[flag] = value
        end
    end

    local ok, message = pcall(function()
        ensureFolder(PROFILE_FOLDER)
        local encoded = HttpService:JSONEncode({
            version = 1,
            placeId = game.PlaceId,
            profile = profile,
            values = values,
        })
        writefile(getProfilePath(profile), encoded)
    end)
    if not ok then
        return false, "Could not save profile: " .. tostring(message)
    end
    return true, "Saved / Overwrote profile: " .. profile, profile
end

function Window:LoadProfile(name)
    if not hasProfileFileApi() then
        return false, "Executor file API is unavailable"
    end

    local profile = sanitizeProfileName(name)
    if profile == "" then
        return false, "Choose a profile to load"
    end

    local path = getProfilePath(profile)
    if not isfile(path) then
        return false, "Profile not found: " .. profile
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" or type(data.values) ~= "table" then
        return false, "Profile data is invalid"
    end
    if data.placeId ~= nil and tonumber(data.placeId) ~= game.PlaceId then
        return false, "Profile belongs to a different game"
    end

    local loaded = 0
    for flag, value in pairs(data.values) do
        local control = self.PersistentControls[flag]
        if control then
            local applied = pcall(function()
                control:Set(value)
            end)
            if applied then
                loaded = loaded + 1
            end
        end
    end
    return true, "Loaded " .. profile .. " (" .. tostring(loaded) .. " settings)", profile
end

function Window:DeleteProfile(name)
    if not hasProfileFileApi() or type(delfile) ~= "function" then
        return false, "Profile deletion is unavailable"
    end

    local profile = sanitizeProfileName(name)
    if profile == "" then
        return false, "Choose a profile to delete"
    end

    local path = getProfilePath(profile)
    if not isfile(path) then
        return false, "Profile not found: " .. profile
    end

    local ok, message = pcall(delfile, path)
    if not ok then
        return false, "Could not delete profile: " .. tostring(message)
    end
    return true, "Deleted profile: " .. profile
end

function Window:SetAutoLoad(enabled, name)
    if not hasProfileFileApi() then
        return false, "Executor file API is unavailable"
    end

    local profile = sanitizeProfileName(name)
    if enabled and (profile == "" or not isfile(getProfilePath(profile))) then
        return false, "Save or select a profile first"
    end

    local ok, message = pcall(function()
        ensureFolder(CONFIG_ROOT)
        writefile(AUTOLOAD_FILE, HttpService:JSONEncode({
            enabled = enabled == true,
            placeId = game.PlaceId,
            profile = profile,
        }))
    end)
    if not ok then
        return false, "Could not update Auto Load: " .. tostring(message)
    end

    if enabled then
        return true, "Auto Load enabled for: " .. profile
    end
    return true, "Auto Load disabled"
end

function Window:GetAutoLoad()
    if not hasProfileFileApi() or not isfile(AUTOLOAD_FILE) then
        return false, ""
    end

    local ok, metadata = pcall(function()
        return HttpService:JSONDecode(readfile(AUTOLOAD_FILE))
    end)
    if not ok or type(metadata) ~= "table" then
        return false, ""
    end
    if metadata.placeId ~= nil and tonumber(metadata.placeId) ~= game.PlaceId then
        return false, ""
    end
    return metadata.enabled == true, sanitizeProfileName(metadata.profile)
end

function Window:Destroy()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)
    if hubMusic.Parent then
        hubMusic:Stop()
        hubMusic:Destroy()
    end
    if gui.Parent then
        gui:Destroy()
    end
    if snowGui.Parent then
        snowGui:Destroy()
    end
    if notificationGui.Parent then
        notificationGui:Destroy()
    end
    if statusGui.Parent then
        statusGui:Destroy()
    end
end

function Window:PlayIntro()
    if not SETTINGS.IntroEnabled then
        main.Visible = true
        setHubMusicVisible(true, false)
        return
    end

    local duration = math.max(tonumber(SETTINGS.IntroDuration) or 5, 1.5)
    local fadeInDuration = math.min(0.35, duration * 0.15)
    -- Give the music and welcome screen room to resolve instead of cutting away abruptly.
    local fadeOutDuration = math.min(1.15, duration * 0.32)
    local blackDelay = math.min(0.65, duration * 0.25)
    local holdDuration = math.max(duration - blackDelay - fadeInDuration - fadeOutDuration, 0)

    local intro = create("Frame", {
        Name = "CodexIntro",
        Active = true,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(5, 14, 21),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 500,
    }, gui)
    create("UIGradient", {
        Rotation = 115,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(4, 12, 18)),
            ColorSequenceKeypoint.new(0.48, Color3.fromRGB(18, 39, 53)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(7, 20, 29)),
        }),
    }, intro)

    local introSound = nil
    if SETTINGS.IntroSoundEnabled and tostring(SETTINGS.IntroSoundId or "") ~= "" then
        introSound = create("Sound", {
            Name = "FrozenIntroChime",
            SoundId = tostring(SETTINGS.IntroSoundId),
            Volume = 0,
            PlaybackSpeed = math.clamp(tonumber(SETTINGS.IntroSoundPlaybackSpeed) or 1, 0.25, 3),
            Looped = false,
            PlayOnRemove = false,
        }, intro)
    end

    local introPianoSound = SETTINGS.IntroPianoEnabled and hubMusic or nil

    local introContent = create("Frame", {
        Name = "FloatingIntroContent",
        Position = UDim2.fromOffset(0, 6),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 501,
    }, intro)

    local introGlow = create("ImageLabel", {
        Name = "FrozenBloom",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -178),
        Size = UDim2.fromOffset(210, 210),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "rbxasset://textures/particles/sparkles_main.dds",
        ImageColor3 = COLORS.accent,
        ImageTransparency = 1,
        Rotation = -18,
        ZIndex = 501,
    }, intro)

    local introLogo = create("Frame", {
        Name = "FloatingCodexLogo",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -180),
        Size = UDim2.fromOffset(108, 108),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Rotation = -8,
        ZIndex = 502,
    }, intro)

    local introLogoImage = create("ImageLabel", {
        Name = "UploadedCodexLogo",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = tostring(SETTINGS.ProfileLogoImageId or ""),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 503,
    }, introLogo)

    local introFlakes = {}
    local introRandom = Random.new(2026)
    local introSymbols = {utf8.char(0x2744), utf8.char(0x2745), utf8.char(0x2746)}
    for flakeIndex = 1, 22 do
        local startX = introRandom:NextNumber(0.03, 0.97)
        local startY = introRandom:NextNumber(-0.20, 0.82)
        local flake = create("TextLabel", {
            Name = "IntroFlake" .. flakeIndex,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(startX, 0, startY, 0),
            Size = UDim2.fromOffset(52, 52),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = introSymbols[introRandom:NextInteger(1, #introSymbols)],
            TextColor3 = SNOW_WHITE,
            TextSize = introRandom:NextInteger(16, 34),
            TextStrokeColor3 = COLORS.accentDark,
            TextStrokeTransparency = 0.42,
            TextTransparency = introRandom:NextNumber(0.12, 0.48),
            Rotation = introRandom:NextInteger(-30, 30),
            ZIndex = 501,
        }, intro)
        table.insert(introFlakes, flake)
        TweenService:Create(
            flake,
            TweenInfo.new(duration + 1.2, Enum.EasingStyle.Linear),
            {
                Position = UDim2.new(math.clamp(startX + introRandom:NextNumber(-0.08, 0.08), 0.02, 0.98), 0, startY + 0.72, 0),
                Rotation = flake.Rotation + introRandom:NextInteger(80, 190),
            }
        ):Play()
    end

    local title = makeLabel(intro, "WELCOME", UDim2.new(0.5, 0, 0.5, -50), UDim2.new(1, -48, 0, 110), SNOW_WHITE, 84, Enum.Font.GothamBold)
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextTransparency = 1
    title.TextStrokeColor3 = COLORS.accentDark
    title.TextStrokeTransparency = 1
    title.ZIndex = 504
    local titleStroke = addStroke(title, COLORS.accent, 1.4, 1)

    local iceLine = create("Frame", {
        Name = "IceRevealLine",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 12),
        Size = UDim2.fromOffset(0, 2),
        BackgroundColor3 = COLORS.accent,
        BackgroundTransparency = 0.10,
        BorderSizePixel = 0,
        ZIndex = 504,
    }, intro)
    addCorner(iceLine, 1)
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, COLORS.accentDark),
            ColorSequenceKeypoint.new(0.50, SNOW_WHITE),
            ColorSequenceKeypoint.new(1.00, COLORS.accentDark),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1),
            NumberSequenceKeypoint.new(0.18, 0),
            NumberSequenceKeypoint.new(0.82, 0),
            NumberSequenceKeypoint.new(1.00, 1),
        }),
    }, iceLine)

    local identityText = SETTINGS.IntroName or LocalPlayer.Name
    local identity = makeLabel(intro, identityText, UDim2.new(0.5, 0, 0.5, 76), UDim2.new(1, -48, 0, 76), COLORS.accent, 56, Enum.Font.GothamSemibold)
    identity.AnchorPoint = Vector2.new(0.5, 0.5)
    identity.TextXAlignment = Enum.TextXAlignment.Center
    identity.TextTransparency = 1
    identity.ZIndex = 504

    local discord = makeLabel(intro, SETTINGS.Discord, UDim2.new(0.5, 0, 0.5, 148), UDim2.new(1, -48, 0, 52), Color3.fromRGB(177, 211, 228), 30, Enum.Font.GothamSemibold)
    discord.AnchorPoint = Vector2.new(0.5, 0.5)
    discord.TextXAlignment = Enum.TextXAlignment.Center
    discord.TextTransparency = 1
    discord.ZIndex = 504

    -- Float the complete center composition together while snow continues independently.
    for _, centerObject in ipairs({introGlow, introLogo, title, iceLine, identity, discord}) do
        centerObject.Parent = introContent
    end

    -- "Suit assembly" pieces: they converge while the actual hub powers on behind them.
    local assemblyPieces = {}
    local assemblyOffsets = {
        {-650, -220, -118, -66, 188, 6}, {650, -205, 124, -74, 164, -5},
        {-720, 8, -132, -8, 226, 4}, {720, 18, 138, 8, 204, -4},
        {-590, 248, -104, 74, 172, 7}, {590, 236, 112, 68, 194, -7},
    }
    for index, values in ipairs(assemblyOffsets) do
        local piece = create("Frame", {
            Name = "AssemblyShard" .. index,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, values[1], 0.5, values[2]),
            Size = UDim2.fromOffset(values[5], 3),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Rotation = values[6],
            ZIndex = 506,
        }, intro)
        addCorner(piece, 2)
        table.insert(assemblyPieces, {Object = piece, Target = UDim2.new(0.5, values[3], 0.5, values[4])})
    end

    if introPianoSound then
        pcall(function()
            setHubMusicVisible(true, true)
            gui:SetAttribute("IntroMusicStarted", true)
            gui:SetAttribute("IntroMusicAsset", tostring(SETTINGS.IntroPianoSoundId))
            gui:SetAttribute("IntroMusicLoaded", introPianoSound.IsLoaded)
            task.delay(0.20, function()
                if introPianoSound.Parent then
                    gui:SetAttribute("IntroMusicPlaying", introPianoSound.IsPlaying)
                end
            end)
        end)
    end

    task.wait(blackDelay)
    if introSound then
        pcall(function()
            introSound:Play()
            TweenService:Create(introSound, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Volume = math.clamp(tonumber(SETTINGS.IntroSoundVolume) or 0.32, 0, 1),
            }):Play()
        end)
    end
    local fadeInInfo = TweenInfo.new(fadeInDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local contentFloat = TweenService:Create(
        introContent,
        TweenInfo.new(1.20, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Position = UDim2.fromOffset(0, -10)}
    )
    contentFloat:Play()
    TweenService:Create(introGlow, TweenInfo.new(fadeInDuration * 1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        ImageTransparency = 0.58,
        Size = UDim2.fromOffset(230, 230),
        Rotation = 8,
    }):Play()
    TweenService:Create(introLogo, TweenInfo.new(fadeInDuration * 1.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Rotation = 0,
        Size = UDim2.fromOffset(130, 130),
    }):Play()
    TweenService:Create(introLogoImage, fadeInInfo, {ImageTransparency = 0}):Play()
    local logoFloat = TweenService:Create(
        introLogo,
        TweenInfo.new(0.78, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Position = UDim2.new(0.5, 0, 0.5, -170)}
    )
    logoFloat:Play()
    TweenService:Create(iceLine, TweenInfo.new(fadeInDuration * 1.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(390, 2),
    }):Play()
    TweenService:Create(titleStroke, fadeInInfo, {Transparency = 0.25}):Play()
    local titleIn = TweenService:Create(title, fadeInInfo, {TextTransparency = 0, TextStrokeTransparency = 0.68})
    titleIn:Play()
    TweenService:Create(identity, fadeInInfo, {TextTransparency = 0}):Play()
    TweenService:Create(discord, fadeInInfo, {TextTransparency = 0}):Play()
    titleIn.Completed:Wait()

    task.wait(holdDuration)
    if main.Parent then
        -- Assemble the real interface pieces, rather than simply zooming in one flat window.
        local finalHubPosition = main.Position
        main.Visible = true
        uiScale.Scale = 0.92
        main.Position = UDim2.new(finalHubPosition.X.Scale, finalHubPosition.X.Offset, finalHubPosition.Y.Scale, finalHubPosition.Y.Offset + 14)
        TweenService:Create(uiScale, TweenInfo.new(0.76, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()
        TweenService:Create(main, TweenInfo.new(0.76, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = finalHubPosition}):Play()

        local assemblyParts = {
            {Object = contentBackdrop, Start = Vector2.new(-212, 46), Delay = 0.00},
            {Object = header, Start = Vector2.new(-260, -192), Delay = 0.06},
            {Object = sidebar, Start = Vector2.new(-250, 156), Delay = 0.12},
            {Object = avatarCard, Start = Vector2.new(-188, -84), Delay = 0.18},
            {Object = welcomeCard, Start = Vector2.new(92, -104), Delay = 0.23},
            {Object = headshotCard, Start = Vector2.new(238, -82), Delay = 0.29},
            {Object = searchFrame, Start = Vector2.new(132, -170), Delay = 0.34},
            {Object = pageHolder, Start = Vector2.new(128, 110), Delay = 0.39},
        }
        for _, part in ipairs(assemblyParts) do
            local object = part.Object
            if object and object.Parent then
                local finalPosition = object.Position
                local assemblyScale = object:FindFirstChild("IntroAssemblyScale")
                if not assemblyScale then
                    assemblyScale = create("UIScale", {Name = "IntroAssemblyScale", Scale = 1}, object)
                end
                object.Position = UDim2.new(0.5, part.Start.X, 0.5, part.Start.Y)
                assemblyScale.Scale = 0.42
                task.delay(part.Delay, function()
                    if object.Parent then
                        TweenService:Create(object, TweenInfo.new(0.62, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Position = finalPosition,
                        }):Play()
                        TweenService:Create(assemblyScale, TweenInfo.new(0.62, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            Scale = 1,
                        }):Play()
                    end
                end)
            end
        end
    end

    local fadeOutInfo = TweenInfo.new(fadeOutDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
    local assemblyInfo = TweenInfo.new(math.min(0.78, fadeOutDuration * 0.74), Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    for _, assemblyPiece in ipairs(assemblyPieces) do
        assemblyPiece.Object.BackgroundTransparency = 0.18
        TweenService:Create(assemblyPiece.Object, assemblyInfo, {
            Position = assemblyPiece.Target,
            BackgroundTransparency = 1,
        }):Play()
    end
    local backgroundOut = TweenService:Create(intro, fadeOutInfo, {BackgroundTransparency = 1})
    backgroundOut:Play()
    contentFloat:Cancel()
    logoFloat:Cancel()
    TweenService:Create(introGlow, fadeOutInfo, {ImageTransparency = 1, Size = UDim2.fromOffset(300, 300)}):Play()
    TweenService:Create(introLogo, fadeOutInfo, {Rotation = 8, Size = UDim2.fromOffset(146, 146)}):Play()
    TweenService:Create(introLogoImage, fadeOutInfo, {ImageTransparency = 1}):Play()
    TweenService:Create(iceLine, fadeOutInfo, {BackgroundTransparency = 1, Size = UDim2.fromOffset(520, 1)}):Play()
    TweenService:Create(titleStroke, fadeOutInfo, {Transparency = 1}):Play()
    TweenService:Create(title, fadeOutInfo, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    TweenService:Create(identity, fadeOutInfo, {TextTransparency = 1}):Play()
    TweenService:Create(discord, fadeOutInfo, {TextTransparency = 1}):Play()
    local audioFadeOutInfo = TweenInfo.new(fadeOutDuration + 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    if introSound then
        TweenService:Create(introSound, audioFadeOutInfo, {Volume = 0}):Play()
    end
    for _, flake in ipairs(introFlakes) do
        TweenService:Create(flake, fadeOutInfo, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    end
    backgroundOut.Completed:Wait()
    task.wait(0.35) -- finish the gentle audio tail after the screen has cleared.

    if intro.Parent then
        intro:Destroy()
    end
end

track(UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == SETTINGS.ToggleKey then
        Window:ToggleVisible()
    end
end))

track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if not Window.ActivePage then
        return
    end
    local query = string.lower(searchBox.Text)
    for _, item in ipairs(Window.ActivePage.SearchItems) do
        item.Object.Visible = query == "" or string.find(item.Text, query, 1, true) ~= nil
    end
end))

function Window:ClampToViewport(targetSize, targetPosition)
    local camera = workspace.CurrentCamera
    if not camera then
        return main.Position
    end

    local viewport = camera.ViewportSize
    local size = targetSize or main.Size
    local position = targetPosition or main.Position
    local scale = math.max(0.01, uiScale.Scale)
    local visualWidth = math.max(1, (viewport.X * size.X.Scale + size.X.Offset) * scale)
    local visualHeight = math.max(1, (viewport.Y * size.Y.Scale + size.Y.Offset) * scale)
    local anchorX = viewport.X * position.X.Scale + position.X.Offset
    local anchorY = viewport.Y * position.Y.Scale + position.Y.Offset
    local margin = 8

    local minimumX = visualWidth * main.AnchorPoint.X + margin
    local maximumX = viewport.X - visualWidth * (1 - main.AnchorPoint.X) - margin
    local minimumY = visualHeight * main.AnchorPoint.Y + margin
    local maximumY = viewport.Y - visualHeight * (1 - main.AnchorPoint.Y) - margin
    if minimumX > maximumX then
        minimumX, maximumX = viewport.X * 0.5, viewport.X * 0.5
    end
    if minimumY > maximumY then
        minimumY, maximumY = viewport.Y * 0.5, viewport.Y * 0.5
    end

    main.Position = UDim2.fromOffset(
        math.clamp(anchorX, minimumX, maximumX),
        math.clamp(anchorY, minimumY, maximumY)
    )
    return main.Position
end

function Window:BeginDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local pointer = input.Position
        for _, button in ipairs({minimizeButton, closeButton}) do
            local topLeft = button.AbsolutePosition
            local bottomRight = topLeft + button.AbsoluteSize
            if pointer.X >= topLeft.X and pointer.X <= bottomRight.X and pointer.Y >= topLeft.Y and pointer.Y <= bottomRight.Y then
                return
            end
        end
        self.Dragging = true
        self.DragStart = pointer
        self.DragStartPosition = main.Position
    end
end

for _, dragSurface in ipairs({header, sidebar, contentBackdrop, welcomeCard, avatarCard}) do
    dragSurface.Active = true
    track(dragSurface.InputBegan:Connect(function(input)
        Window:BeginDrag(input)
    end))
end

track(UserInputService.InputChanged:Connect(function(input)
    if Window.Dragging and Window.DragStart and Window.DragStartPosition and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - Window.DragStart
        local proposed = UDim2.new(
            Window.DragStartPosition.X.Scale,
            Window.DragStartPosition.X.Offset + delta.X,
            Window.DragStartPosition.Y.Scale,
            Window.DragStartPosition.Y.Offset + delta.Y
        )
        Window:ClampToViewport(Window.Minimized and UDim2.fromOffset(850, 46) or UDim2.fromOffset(850, 560), proposed)
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Window.Dragging = false
        Window.DragStart = nil
        Window.DragStartPosition = nil
    end
end))

track(minimizeButton.MouseButton1Click:Connect(function()
    Window.Minimized = not Window.Minimized
    minimizeButton.Text = Window.Minimized and "+" or "-"
    sidebar.Visible = not Window.Minimized
    searchFrame.Visible = not Window.Minimized
    pageHolder.Visible = not Window.Minimized
    welcomeCard.Visible = not Window.Minimized
    avatarCard.Visible = SETTINGS.AvatarPreviewEnabled and not Window.Minimized
    contentBackdrop.Visible = not Window.Minimized
    icicleLayer.Visible = not Window.Minimized
    local targetSize = Window.Minimized and UDim2.fromOffset(850, 46) or UDim2.fromOffset(850, 560)
    Window:ClampToViewport(targetSize)
    TweenService:Create(main, TweenInfo.new(0.20, Enum.EasingStyle.Quad), {Size = targetSize}):Play()
    task.delay(0.22, function()
        if main.Parent then
            Window:ClampToViewport(targetSize)
        end
    end)
end))

track(closeButton.MouseButton1Click:Connect(function()
    Window:Destroy()
end))

track(minimizeButton.MouseEnter:Connect(function()
    minimizeButton.TextColor3 = COLORS.text
end))
track(minimizeButton.MouseLeave:Connect(function()
    minimizeButton.TextColor3 = COLORS.muted
end))
track(closeButton.MouseEnter:Connect(function()
    closeButton.TextColor3 = COLORS.error
end))
track(closeButton.MouseLeave:Connect(function()
    closeButton.TextColor3 = COLORS.muted
end))

function Window:UpdateScale()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local viewport = camera.ViewportSize
    uiScale.Scale = math.clamp(math.min((viewport.X - 30) / 850, (viewport.Y - 30) / 560), 0.55, 1)
    self:ClampToViewport(self.Minimized and UDim2.fromOffset(850, 46) or UDim2.fromOffset(850, 560))
end

Window:UpdateScale()
if workspace.CurrentCamera then
    track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        Window:UpdateScale()
    end))
end

task.spawn(function()
    local experienceName = "Unknown Game"
    local ok, information = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if ok and information and type(information.Name) == "string" and information.Name ~= "" then
        experienceName = information.Name
    end
    if brandTitle.Parent then
        brandTitle.Text = SETTINGS.Title
        brandSubtitle.Text = SETTINGS.Discord
        welcomeSubtitle.Text = SETTINGS.Title .. " | " .. experienceName .. " | " .. SETTINGS.Discord .. " | Created by " .. SETTINGS.Creator
    end
end)

-- BUILD YOUR MENU BELOW THIS LINE.
-- Game controls stay inside Home categories; Settings remains configuration-only.
local function buildReviveFeatures()
local HomePage = Window:AddPage("Home")
local ToolsPage = Window:AddPage("Tools")

-- Home uses large frozen decal cards. The images work as the category tabs while
-- the selected card reveals its controls below without changing the page layout.
HomePage.LeftColumn.Visible = false
HomePage.RightColumn.Visible = false

local categoryBar = create("Frame", {
    Name = "HomeCategoryBar",
    Size = UDim2.new(1, 0, 0, 96),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = math.max(0.18, hubTransparencyValue - 0.04),
    BorderSizePixel = 0,
    ZIndex = 20,
}, HomePage.Frame)
addCorner(categoryBar, 10)
addStroke(categoryBar, COLORS.line, 1, 0.34)
create("UIPadding", {
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
}, categoryBar)
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, categoryBar)

local homeCategories = {}
local activeHomeCategory = nil

local function selectHomeCategory(name)
    local selected = homeCategories[name]
    if not selected then
        return false
    end
    for _, category in pairs(homeCategories) do
        local active = category == selected
        category.Frame.Visible = active
        category.Button.BackgroundTransparency = active and 0.02 or 0.16
        category.Button.BackgroundColor3 = active and COLORS.accentDark:Lerp(SNOW_WHITE, 0.48) or COLORS.surface2
        category.Button.ImageTransparency = active and 0.02 or 0.14
        category.Label.TextColor3 = active and SNOW_WHITE or Color3.fromRGB(232, 246, 253)
        category.Label.TextTransparency = active and 0 or 0.08
        category.Stroke.Color = active and COLORS.accentDark or COLORS.line
        category.Stroke.Thickness = active and 2 or 1
        category.Stroke.Transparency = active and 0.02 or 0.34
        category.Accent.Visible = active
        category.SelectedGlow.Visible = active
    end
    activeHomeCategory = selected
    HomePage.SearchItems = selected.SearchItems
    searchBox.Text = ""
    HomePage.Frame:SetAttribute("ActiveCategory", name)
    return true
end

local function addHomeCategory(name, order, assetId)
    local button = create("ImageButton", {
        Name = name .. "Tab",
        LayoutOrder = order,
        Size = UDim2.fromOffset(142, 84),
        AutoButtonColor = false,
        BackgroundColor3 = COLORS.surface2,
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        Image = "rbxthumb://type=Asset&id=" .. tostring(assetId) .. "&w=420&h=420",
        ImageColor3 = Color3.fromRGB(244, 252, 255),
        ImageTransparency = 0.14,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 21,
    }, categoryBar)
    addCorner(button, 10)
    local buttonStroke = addStroke(button, COLORS.line, 1, 0.34)

    local selectedGlow = create("Frame", {
        Name = "SelectedGlow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 10, 1, 10),
        BackgroundColor3 = COLORS.accent,
        BackgroundTransparency = 0.76,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20,
    }, button)
    addCorner(selectedGlow, 13)

    local caption = create("Frame", {
        Name = "Caption",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Color3.fromRGB(10, 31, 44),
        BackgroundTransparency = 0.14,
        BorderSizePixel = 0,
        ZIndex = 23,
    }, button)
    addCorner(caption, 9)
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(38, 79, 101), Color3.fromRGB(8, 27, 39)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.36),
            NumberSequenceKeypoint.new(1, 0.02),
        }),
    }, caption)

    local label = create("TextLabel", {
        Name = "CategoryName",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = name,
        TextColor3 = Color3.fromRGB(232, 246, 253),
        TextSize = 13,
        TextStrokeColor3 = Color3.fromRGB(5, 19, 28),
        TextStrokeTransparency = 0.22,
        ZIndex = 24,
    }, caption)

    local accent = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -1),
        Size = UDim2.new(0.68, 0, 0, 4),
        BackgroundColor3 = SNOW_WHITE,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 25,
    }, button)
    addCorner(accent, 3)

    track(button.MouseEnter:Connect(function()
        if activeHomeCategory ~= homeCategories[name] then
            TweenService:Create(button, TweenInfo.new(0.14), {
                ImageTransparency = 0.04,
                BackgroundTransparency = 0.08,
            }):Play()
        end
    end))
    track(button.MouseLeave:Connect(function()
        if activeHomeCategory ~= homeCategories[name] then
            TweenService:Create(button, TweenInfo.new(0.14), {
                ImageTransparency = 0.14,
                BackgroundTransparency = 0.16,
            }):Play()
        end
    end))

    local frame = create("Frame", {
        Name = name .. "Category",
        Position = UDim2.fromOffset(0, 104),
        Size = UDim2.new(1, 0, 1, -104),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
    }, HomePage.Frame)
    local leftColumn = create("ScrollingFrame", {
        Name = "LeftColumn",
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accentDark,
    }, frame)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, leftColumn)
    local rightColumn = create("ScrollingFrame", {
        Name = "RightColumn",
        Position = UDim2.new(0.5, 6, 0, 0),
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accentDark,
    }, frame)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, rightColumn)

    local category = setmetatable({
        Name = name,
        Frame = frame,
        Button = button,
        Label = label,
        Stroke = buttonStroke,
        Accent = accent,
        SelectedGlow = selectedGlow,
        LeftColumn = leftColumn,
        RightColumn = rightColumn,
        SearchItems = {},
        NextSide = "Left",
    }, {__index = PageMethods})
    homeCategories[name] = category
    track(button.MouseButton1Click:Connect(function()
        playToggleClick(true)
        selectHomeCategory(name)
    end))
    return category
end

local OvernightPage = addHomeCategory("Overnight", 1, 13613618140)
local CombatPage = addHomeCategory("Combat", 2, 105099599251617)
local WeaponsPage = addHomeCategory("Weapons", 3, 95898332716312)
local ProgressPage = addHomeCategory("Progress", 4, 139818999438291)
local VisualsPage = addHomeCategory("Visuals", 5, 5676602141)

local OvernightSection = OvernightPage:AddSection("AFK Essentials", "Left")
local OvernightUpgradeSection = OvernightPage:AddSection("Overnight Upgrades", "Right")
local LiveSection = OvernightPage:AddSection("Live Status", "Right")
local CombatSection = CombatPage:AddSection("Combat Automation", "Left")
local CursedKingSection = CombatPage:AddSection("Special Bosses", "Left")
local SpecialPrioritySection = CombatPage:AddSection("Special Boss Priority", "Right")
local FarmSection = CombatPage:AddSection("Boss Progression Farm", "Right")
local TweenSection = CombatPage:AddSection("Enemy Tween", "Right")
local UpgradeSection = WeaponsPage:AddSection("Sword Automation", "Left")
local WeaponInfoSection = WeaponsPage:AddSection("Owned Weapons", "Right")
local ChallengeSection = ProgressPage:AddSection("Challenges", "Left")
local RebirthSection = ProgressPage:AddSection("Auto Rebirth", "Left")
local SoulRingSection = ProgressPage:AddSection("Soul Ring", "Right")
local RewardSection = ProgressPage:AddSection("Reward Automation", "Right")
local VisualSection = VisualsPage:AddSection("Character Visuals", "Left")
local VisualInfoSection = VisualsPage:AddSection("Visual Status", "Right")
local NotificationSection = VisualsPage:AddSection("Hub Notifications", "Right")
local OutfitSection = ToolsPage:AddSection("Local Outfit Preview", "Left")
local FrozenPresetSection = ToolsPage:AddSection("Frozen Codex Armor", "Right")
local ToolsInfoSection = ToolsPage:AddSection("Tools Status", "Right")

selectHomeCategory("Overnight")

local statusLabel = LiveSection:AddLabel("Status: Loading Revive remotes...")
local remoteLabel = LiveSection:AddLabel("Remotes: Loading...")
local farmStatusLabel = LiveSection:AddLabel("Farm: Waiting")
local multiHitStatusLabel = LiveSection:AddLabel("Multi Hit: Disabled")
local reaperStatusLabel = LiveSection:AddLabel("Reaper: Reading unlock state...")
local cursedKingStatusLabel = LiveSection:AddLabel("Cursed King: Reading unlock state...")
local nightmareStatusLabel = LiveSection:AddLabel("Nightmare: Reading Death Tower state...")
local deathKingStatusLabel = LiveSection:AddLabel("Death King: Reading unlock state...")
local priorityStatusLabel = LiveSection:AddLabel("Special Priority: Disabled")
local tweenStatusLabel = LiveSection:AddLabel("Tween: Enemy 1 selected")
local weaponStatusLabel = WeaponInfoSection:AddLabel("Sword: Reading inventory...")
local visualStatusLabel = VisualInfoSection:AddLabel("Visuals: Local-only and reversible")
VisualInfoSection:AddLabel("All character effects are local-only, reversible, and reapplied after respawn.")
local discordReminderStatusLabel = NotificationSection:AddLabel("Discord Reminder: Every 15 minutes")
local outfitStatusLabel = ToolsInfoSection:AddLabel("Outfit: Your Roblox avatar")
local soulRingStatusLabel = SoulRingSection:AddLabel("Soul Ring: Reading slot 1...")
local soulRingCurrencyLabel = SoulRingSection:AddLabel("Soul Stones: Reading... | Rerolls: Reading...")
ToolsInfoSection:AddLabel("Catalog previews and the frozen preset are client-only. Other players keep seeing your server avatar.")

local function setReviveStatus(message, success)
    statusLabel.Text = "Status: " .. tostring(message)
    statusLabel.TextColor3 = success == false and COLORS.error or (success == true and COLORS.success or COLORS.muted)
end

local REMOTE_NAMES = {
    "attack",
    "attackResult",
    "staticReaperReq",
    "staticReaperResp",
    "getGroupReward",
    "startTimeLimitChallengeReq",
    "timeLimitChallengeResult",
    "enterTimeLimitBossReq",
    "levelTimeLimitBossReq",
    "setAfkResumeReq",
    "enhanceWeapon",
    "equipWeapon",
    "getSignReward",
    "receiveOnlineTimeReward",
    "claimSoulSpawner",
    "claimTimeLimitBossReward",
    "claimChallengeReward",
    "rebirth",
    "SetAutoRebirth",
    "claimReaperPityReward",
    "rollSigil",
    "SetAutoSigilRarity",
    "enhanceSoulRing",
    "rerollSoulRing",
}

remoteLabel.Text = "Remotes: 0 / " .. tostring(#REMOTE_NAMES) .. " ready"

local remotes = {}
local confirmedAttackSerial = {}
local reaperLocalCooldownUntil = 0
local specialResultSerial = 0
local specialResultSuccess = false
local function getRemoContainer()
    local rbxtsInclude = ReplicatedStorage:WaitForChild("rbxts_include", 12)
    local nodeModules = rbxtsInclude and rbxtsInclude:WaitForChild("node_modules", 12)
    local rbxts = nodeModules and nodeModules:WaitForChild("@rbxts", 12)
    local remo = rbxts and rbxts:WaitForChild("remo", 12)
    local src = remo and remo:WaitForChild("src", 12)
    return src and src:WaitForChild("container", 12)
end

local function fireRemote(name, ...)
    local remote = remotes[name]
    if not remote or not remote.Parent then
        setReviveStatus(name .. " remote is not ready", false)
        return false
    end
    local arguments = table.pack(...)
    local ok, err = pcall(function()
        remote:FireServer(table.unpack(arguments, 1, arguments.n))
    end)
    if not ok then
        setReviveStatus(name .. " failed: " .. tostring(err), false)
    end
    return ok
end

task.spawn(function()
    local container = getRemoContainer()
    if not container then
        remoteLabel.Text = "Remotes: container not found"
        remoteLabel.TextColor3 = COLORS.error
        setReviveStatus("Revive remote container was not found", false)
        return
    end

    local ready = 0
    for _, name in ipairs(REMOTE_NAMES) do
        local remote = container:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            remotes[name] = remote
            ready = ready + 1
        end
    end
    if remotes.attackResult then
        track(remotes.attackResult.OnClientEvent:Connect(function(...)
            local arguments = table.pack(...)
            local confirmedLevel = tonumber(arguments[arguments.n])
            if confirmedLevel and confirmedLevel >= 1 and confirmedLevel <= 15 then
                confirmedAttackSerial[confirmedLevel] = (confirmedAttackSerial[confirmedLevel] or 0) + 1
            end
        end))
    end
    if remotes.staticReaperResp then
        track(remotes.staticReaperResp.OnClientEvent:Connect(function(maxHpRemoved)
            reaperLocalCooldownUntil = workspace:GetServerTimeNow() + 20
            reaperStatusLabel.Text = "Reaper: Confirmed -" .. tostring(maxHpRemoved) .. " Max HP | 20s cooldown"
            reaperStatusLabel.TextColor3 = COLORS.success
        end))
    end
    if remotes.timeLimitChallengeResult then
        track(remotes.timeLimitChallengeResult.OnClientEvent:Connect(function(...)
            local arguments = table.pack(...)
            local success = false
            for index = 1, arguments.n do
                if type(arguments[index]) == "boolean" then
                    success = arguments[index]
                    break
                end
            end
            specialResultSuccess = success
            specialResultSerial += 1
        end))
    end
    remoteLabel.Text = "Remotes: " .. tostring(ready) .. " / " .. tostring(#REMOTE_NAMES) .. " ready"
    remoteLabel.TextColor3 = ready == #REMOTE_NAMES and COLORS.success or COLORS.muted
    setReviveStatus("Revive-only controls are ready", true)
end)

local state = {
    antiAfk = false,
    autoAttack = false,
    multiHit = false,
    reaper = false,
    cursedKing = false,
    deathKing = false,
    nightmare = false,
    specialPriority = false,
    priorityMulti = false,
    groupReward = false,
    challengeOne = false,
    challengeFive = false,
    autoUpgrade = false,
    dailyReward = false,
    onlineReward = false,
    soulSpawner = false,
    starterRewards = false,
    bossRewards = false,
    bossFarm = false,
    autoTween = false,
    autoEquipBest = false,
    autoRebirth = false,
    autoSoulRing = false,
    demonRealm = false,
    discordReminder = true,
}

local discordReminderInterval = 15 * 60
local nextDiscordReminderAt = os.clock() + discordReminderInterval
local function showDiscordReminder()
    Window:Notify(
        "Codex Hub • Discord",
        "See you enjoying our script? Join our Discord: Discord.gg/Codexhub",
        8
    )
    nextDiscordReminderAt = os.clock() + discordReminderInterval
    discordReminderStatusLabel.Text = "Discord Reminder: Shown | Next in 15:00"
    discordReminderStatusLabel.TextColor3 = COLORS.success
end

NotificationSection:AddToggle({
    Name = "Discord Reminder",
    Description = "Shows the frozen bottom-right Discord invitation every 15 minutes",
    Default = true,
    Flag = "revive_discord_reminder",
    Callback = function(enabled)
        state.discordReminder = enabled
        nextDiscordReminderAt = os.clock() + discordReminderInterval
        discordReminderStatusLabel.Text = enabled and "Discord Reminder: Enabled | Next in 15:00" or "Discord Reminder: Disabled"
        discordReminderStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
    end,
})

NotificationSection:AddButton({
    Name = "Test Discord Reminder",
    Description = "Shows the themed bottom-right notification immediately",
    Persist = false,
    Callback = showDiscordReminder,
})

NotificationSection:AddLabel("The reminder stays visible even while the main hub is hidden with Right Ctrl.")

local antiAfkStatusLabel = OvernightSection:AddLabel("Anti-AFK: Disabled")
local antiAfkControl
antiAfkControl = OvernightSection:AddToggle({
    Name = "Anti-AFK / Anti-Idle",
    Description = "Responds when Roblox detects inactivity so overnight farming is not idle-kicked",
    Flag = "revive_anti_afk",
    Callback = function(enabled)
        state.antiAfk = enabled
        gui:SetAttribute("AntiAFKEnabled", enabled)
        antiAfkStatusLabel.Text = enabled and "Anti-AFK: Armed and waiting for an idle signal" or "Anti-AFK: Disabled"
        antiAfkStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        setReviveStatus(enabled and "Anti-AFK enabled" or "Anti-AFK disabled", enabled and true or nil)
    end,
})
gui:SetAttribute("AntiAFKEnabled", false)

task.spawn(function()
    while statusGui.Parent and gui.Parent do
        statusWidgetLabels.General.Text = statusLabel.Text
        statusWidgetLabels.General.TextColor3 = statusLabel.TextColor3
        statusWidgetLabels.AFK.Text = antiAfkStatusLabel.Text
        statusWidgetLabels.AFK.TextColor3 = antiAfkStatusLabel.TextColor3
        if state.demonRealm and state.demonRealmStatusLabel then
            statusWidgetLabels.Special.Text = state.demonRealmStatusLabel.Text
            statusWidgetLabels.Special.TextColor3 = state.demonRealmStatusLabel.TextColor3
        else
            statusWidgetLabels.Special.Text = priorityStatusLabel.Text
            statusWidgetLabels.Special.TextColor3 = priorityStatusLabel.TextColor3
        end
        statusWidgetLabels.Multi.Text = multiHitStatusLabel.Text
        statusWidgetLabels.Multi.TextColor3 = multiHitStatusLabel.TextColor3
        statusWidgetLabels.Farm.Text = farmStatusLabel.Text .. " | " .. nightmareStatusLabel.Text
        statusWidgetLabels.Farm.TextColor3 = farmStatusLabel.TextColor3
        statusWidgetLabels.Weapon.Text = weaponStatusLabel.Text
        statusWidgetLabels.Weapon.TextColor3 = weaponStatusLabel.TextColor3
        task.wait(0.20)
    end
end)

local function performAntiAfkPulse()
    local camera = workspace.CurrentCamera
    local cameraCFrame = camera and camera.CFrame or CFrame.new()
    local ok = pcall(function()
        local virtualUser = game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:Button2Down(Vector2.new(0, 0), cameraCFrame)
        task.wait(0.05)
        virtualUser:Button2Up(Vector2.new(0, 0), cameraCFrame)
    end)
    if ok then
        gui:SetAttribute("AntiAFKLastPulse", workspace:GetServerTimeNow())
        antiAfkStatusLabel.Text = "Anti-AFK: Idle pulse sent successfully"
        antiAfkStatusLabel.TextColor3 = COLORS.success
    else
        antiAfkStatusLabel.Text = "Anti-AFK: Virtual input was unavailable"
        antiAfkStatusLabel.TextColor3 = COLORS.error
    end
    return ok
end

track(LocalPlayer.Idled:Connect(function()
    if state.antiAfk and gui.Parent then
        performAntiAfkPulse()
    end
end))

OvernightSection:AddButton({
    Name = "Test Anti-AFK Pulse",
    Description = "Runs one harmless idle-protection pulse and updates the status above",
    Persist = false,
    Callback = function()
        if performAntiAfkPulse() then
            setReviveStatus("Anti-AFK test passed", true)
        else
            setReviveStatus("Anti-AFK test could not send virtual input", false)
        end
    end,
})

local overnightMultiHitControl
local overnightReaperControl
local overnightDeathKingControl
local overnightCursedKingControl
local overnightNightmareControl
local overnightSpecialPriorityControl
local overnightBossFarmControl
local overnightAutoEquipControl
local overnightAutoUpgradeControl
local overnightAutoRebirthControl
local overnightAutoSoulRingControl

local reaperBattleStore = nil
local rebirthStore = nil
local reaperUnlockLevel = 3
local reaperInterval = 20
local redDragonUnlockLevel = 5
local greenDragonUnlockLevel = 5
local nightmareUnlockLevel = 15
local rebirthTowerLevelRatio = 5
pcall(function()
    reaperBattleStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("battle"))
    rebirthStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("rebirth"))
    local globalConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbglobalconfig"))
    reaperUnlockLevel = tonumber(globalConfig.unlock_reaper_main_level_require) or reaperUnlockLevel
    reaperInterval = tonumber(globalConfig.static_reaper_interval_time) or reaperInterval
    redDragonUnlockLevel = tonumber(globalConfig.unlock_red_dragon_main_level_require) or redDragonUnlockLevel
    greenDragonUnlockLevel = tonumber(globalConfig.unlock_green_dragon_main_level_require) or greenDragonUnlockLevel
    nightmareUnlockLevel = tonumber(globalConfig.unlock_tower_main_level_require) or nightmareUnlockLevel
    rebirthTowerLevelRatio = tonumber(globalConfig.rebirth_tower_level_ratio) or rebirthTowerLevelRatio
end)

local function readAtomValue(store, name)
    local atom = store and store[name]
    if type(atom) ~= "function" then
        return nil
    end
    local ok, value = pcall(atom)
    if not ok then
        return nil
    end
    if type(value) == "function" then
        local readOk, currentValue = pcall(value)
        return readOk and currentValue or nil
    end
    return value
end

local function writeDirectAtom(store, name, value)
    local atom = store and store[name]
    if type(atom) ~= "function" then
        return false
    end
    return pcall(atom, value)
end

state.getDemonRealmState = function()
    local serverNow = workspace:GetServerTimeNow()
    local openEndTime = tonumber(readAtomValue(reaperBattleStore, "AtomTimeLimitBossOpenEndTime")) or 0
    local nextOpenTime = tonumber(readAtomValue(reaperBattleStore, "AtomTimeLimitBossNextOpenTime")) or 0
    local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
    local expEfficiency = tonumber(readAtomValue(reaperBattleStore, "AtomTimeLimitBossExpEfficiency")) or 0
    return {
        Open = openEndTime > serverNow,
        InRealm = battleState == 7,
        BattleState = battleState,
        OpenRemaining = math.max(0, math.ceil(openEndTime - serverNow)),
        NextRemaining = math.max(0, math.ceil(nextOpenTime - serverNow)),
        ExpEfficiency = expEfficiency,
    }
end

state.formatRealmCountdown = function(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainder = seconds % 60
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, remainder)
    end
    return string.format("%02d:%02d", minutes, remainder)
end

state.demonRealmStatusLabel = CursedKingSection:AddLabel("Demon Realm: Reading global event window...")
state.refreshDemonRealmStatus = function()
    local info = state.getDemonRealmState()
    if info.InRealm then
        state.demonRealmStatusLabel.Text = "Demon Realm: Inside | Auto farming | "
            .. state.formatRealmCountdown(info.OpenRemaining) .. " left"
        state.demonRealmStatusLabel.TextColor3 = COLORS.success
    elseif info.Open then
        state.demonRealmStatusLabel.Text = (state.demonRealm and "Demon Realm: Open | Joining... | " or "Demon Realm: Open now | Auto join off | ")
            .. state.formatRealmCountdown(info.OpenRemaining) .. " left"
        state.demonRealmStatusLabel.TextColor3 = state.demonRealm and COLORS.success or COLORS.muted
    elseif state.demonRealm then
        state.demonRealmStatusLabel.Text = info.NextRemaining > 0
            and ("Demon Realm: Armed | Next global event in " .. state.formatRealmCountdown(info.NextRemaining))
            or "Demon Realm: Armed | Waiting for the next global event"
        state.demonRealmStatusLabel.TextColor3 = COLORS.success
    else
        state.demonRealmStatusLabel.Text = info.NextRemaining > 0
            and ("Demon Realm: Disabled | Next event in " .. state.formatRealmCountdown(info.NextRemaining))
            or "Demon Realm: Disabled | Global event is closed"
        state.demonRealmStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

state.demonRealmControl = CursedKingSection:AddToggle({
    Name = "Auto Demon Realm",
    Description = "Joins the global Demon Realm when it opens, attacks continuously, and re-enters while it stays open",
    Flag = "revive_auto_demon_realm",
    Callback = function(enabled)
        state.demonRealm = enabled
        state.refreshDemonRealmStatus()
        setReviveStatus(
            enabled and "Demon Realm armed; waiting for the server event window" or "Auto Demon Realm disabled",
            enabled and true or nil
        )
    end,
})
CursedKingSection:AddLabel("The realm timer and stat rewards are server-controlled; Auto Demon Realm waits and rejoins every valid opening.")
task.defer(state.refreshDemonRealmStatus)

local function getReaperState()
    local mainLevel = tonumber(readAtomValue(reaperBattleStore, "AtomMainLevel")) or 0
    local maxHp = tonumber(readAtomValue(reaperBattleStore, "AtomMaxHP")) or 0
    local nextValidTime = tonumber(readAtomValue(reaperBattleStore, "AtomReaperTime")) or 0
    return {
        Unlocked = mainLevel >= reaperUnlockLevel,
        MainLevel = mainLevel,
        MaxHP = maxHp,
        NextValidTime = nextValidTime,
        Remaining = math.max(0, math.ceil(nextValidTime - workspace:GetServerTimeNow())),
    }
end

local function refreshReaperStatus(prefix)
    local info = getReaperState()
    if not info.Unlocked then
        reaperStatusLabel.Text = "Reaper: Waiting for the game's unlock state"
        reaperStatusLabel.TextColor3 = COLORS.muted
    elseif info.MaxHP <= 1 then
        reaperStatusLabel.Text = "Reaper: Unlocked | No more Max HP can be taken"
        reaperStatusLabel.TextColor3 = COLORS.muted
    elseif info.Remaining > 0 then
        reaperStatusLabel.Text = "Reaper: Unlocked | Cooldown " .. info.Remaining .. "s"
        reaperStatusLabel.TextColor3 = COLORS.muted
    else
        reaperStatusLabel.Text = "Reaper: Unlocked | Ready"
        reaperStatusLabel.TextColor3 = COLORS.success
    end
    if prefix then
        setReviveStatus(prefix, true)
    end
    return info
end

task.defer(refreshReaperStatus)

local RED_DRAGON_MODE = 1
local GREEN_DRAGON_MODE = 2
local NIGHTMARE_MODE = 3
local deathKingLevelAdd = 0
local cursedKingLevelAdd = 0
local nightmareLevelAdd = 0
local specialLastStart = {[RED_DRAGON_MODE] = 0, [GREEN_DRAGON_MODE] = 0, [NIGHTMARE_MODE] = 0}
local multiHitNeedsBootstrap = true
local nightmarePortalPrimeRunning = false
local nightmarePortalPrimedCharacter = nil
local priority = {
    target = "Nightmare",
    levelAdd = 0,
    winsPerCycle = 1,
    multiSeconds = 5,
    phase = "special",
    wins = 0,
    nextMode = NIGHTMARE_MODE,
    activeMode = nil,
    activeLevelBefore = 0,
    lastLevels = {[RED_DRAGON_MODE] = 0, [GREEN_DRAGON_MODE] = 0, [NIGHTMARE_MODE] = 0},
    seenResultSerial = 0,
    nextStartAt = 0,
    multiEndAt = 0,
    quitDeadline = 0,
}

local function levelAddText(levelAdd)
    return levelAdd == 2 and "+10" or (levelAdd == 1 and "+5" or "+1")
end

local function getSpecialBossState(mode)
    local mainLevel = tonumber(readAtomValue(reaperBattleStore, "AtomMainLevel")) or 0
    local highestRebirth = tonumber(readAtomValue(rebirthStore, "AtomHighestReachedRebirth")) or 0
    local autoMode = tonumber(readAtomValue(reaperBattleStore, "AtomAutoChallengeMode")) or 0
    local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
    local isNightmare = mode == NIGHTMARE_MODE
    local isDeathKing = mode == RED_DRAGON_MODE
    local requiredMainLevel = isNightmare and nightmareUnlockLevel
        or (isDeathKing and redDragonUnlockLevel or greenDragonUnlockLevel)
    local atomName = isNightmare and "AtomTowerLevel"
        or (isDeathKing and "AtomRedDragonLevel" or "AtomGreenDragonLevel")
    return {
        Unlocked = mainLevel >= requiredMainLevel,
        MainLevel = mainLevel,
        RequiredMainLevel = requiredMainLevel,
        HighestRebirth = highestRebirth,
        NativeAutoAvailable = highestRebirth > 0,
        Level = tonumber(readAtomValue(reaperBattleStore, atomName)) or 0,
        RequiredTowerLevel = isNightmare and (rebirthTowerLevelRatio * (highestRebirth + 1)) or nil,
        AutoMode = autoMode,
        BattleState = battleState,
        Mode = mode,
    }
end

local function getDeathKingState()
    return getSpecialBossState(RED_DRAGON_MODE)
end

local function getCursedKingState()
    return getSpecialBossState(GREEN_DRAGON_MODE)
end

local function refreshDeathKingStatus()
    local info = getDeathKingState()
    if not info.Unlocked then
        deathKingStatusLabel.Text = "Death King: Requires Main Level " .. info.RequiredMainLevel .. " | Current " .. info.MainLevel
        deathKingStatusLabel.TextColor3 = COLORS.error
    elseif state.deathKing then
        local method = info.NativeAutoAvailable and "Native Auto" or "Hub Auto"
        deathKingStatusLabel.Text = "Death King: " .. method .. " " .. levelAddText(deathKingLevelAdd) .. " | Level " .. info.Level
        deathKingStatusLabel.TextColor3 = COLORS.success
    else
        deathKingStatusLabel.Text = "Death King: Unlocked | Auto disabled | Level " .. info.Level
        deathKingStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

local function getNightmareState()
    return getSpecialBossState(NIGHTMARE_MODE)
end

local function findNightmarePortalPart()
    local bestPart = nil
    local bestScore = -math.huge
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Transparency < 1 then
            local parentName = descendant.Parent and descendant.Parent.Name or ""
            local identity = string.lower(descendant.Name .. " " .. parentName)
            local hue, saturation = Color3.toHSV(descendant.Color)
            local isPurple = hue >= 0.68 and hue <= 0.90 and saturation >= 0.22
            local score = 0
            if string.find(identity, "portal", 1, true) then score += 7 end
            if string.find(identity, "nightmare", 1, true) then score += 5 end
            if string.find(identity, "death", 1, true) then score += 3 end
            if string.find(identity, "tower", 1, true) then score += 3 end
            if isPurple then score += 4 end
            if descendant.CanTouch then score += 1 end
            if score > bestScore and score >= 8 then
                bestPart = descendant
                bestScore = score
            end
        end
    end
    return bestPart
end

local function prepareNightmareChallengeScene()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end
    local scene = workspace:FindFirstChild("TowerBattle")
    if not scene then
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        local model = assets and assets:FindFirstChild("Model")
        local sceneFolder = model and model:FindFirstChild("Scene")
        scene = sceneFolder and sceneFolder:FindFirstChild("TowerBattle")
    end
    if not scene or not scene:IsA("Model") then
        return false
    end
    local ok = pcall(function()
        if scene.Parent ~= workspace then
            scene.Parent = workspace
        end
        scene:PivotTo(CFrame.new(0, 300, 0))
        local posFolder = scene:FindFirstChild("Pos", true)
        local playerPoint = posFolder and posFolder:FindFirstChild("Player")
        if not playerPoint or not playerPoint:IsA("BasePart") then
            error("TowerBattle.Pos.Player was not found")
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = playerPoint.CFrame
    end)
    if ok then
        nightmarePortalPrimedCharacter = character
        setReviveStatus("Death Tower arena prepared automatically", true)
    end
    return ok
end

local function primeNightmarePortal()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not root then
        return false
    end
    if nightmarePortalPrimedCharacter == character then
        return true
    end
    if nightmarePortalPrimeRunning then
        return false
    end

    if prepareNightmareChallengeScene() then
        return true
    end

    local portalPart = findNightmarePortalPart()
    if not portalPart then
        setReviveStatus("Nightmare is waiting for the purple Death Tower portal", nil)
        return false
    end

    nightmarePortalPrimeRunning = true
    local originalCFrame = root.CFrame
    local ok = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = portalPart.CFrame * CFrame.new(0, 0, -2.2)
        if type(firetouchinterest) == "function" then
            firetouchinterest(root, portalPart, 0)
            firetouchinterest(root, portalPart, 1)
        end
        task.wait(0.18)
        root.CFrame = portalPart.CFrame * CFrame.new(0, 0, 2.2)
        task.wait(0.18)
        root.CFrame = originalCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    nightmarePortalPrimeRunning = false
    if ok then
        nightmarePortalPrimedCharacter = character
        setReviveStatus("Purple Death Tower portal primed automatically", true)
    end
    return ok
end

local function refreshCursedKingStatus()
    local info = getCursedKingState()
    if not info.Unlocked then
        cursedKingStatusLabel.Text = "Cursed King: Requires Main Level " .. info.RequiredMainLevel .. " | Current " .. info.MainLevel
        cursedKingStatusLabel.TextColor3 = COLORS.error
    elseif state.cursedKing then
        local method = info.NativeAutoAvailable and "Native Auto" or "Hub Auto"
        cursedKingStatusLabel.Text = "Cursed King: " .. method .. " " .. levelAddText(cursedKingLevelAdd) .. " | Level " .. info.Level
        cursedKingStatusLabel.TextColor3 = COLORS.success
    else
        cursedKingStatusLabel.Text = "Cursed King: Unlocked | Auto disabled | Level " .. info.Level
        cursedKingStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

local function refreshNightmareStatus()
    local info = getNightmareState()
    if not info.Unlocked then
        nightmareStatusLabel.Text = "Nightmare: Requires Main Level " .. info.RequiredMainLevel .. " | Current " .. info.MainLevel
        nightmareStatusLabel.TextColor3 = COLORS.error
    elseif state.nightmare then
        local method = info.NativeAutoAvailable and "Native Auto" or "Hub Auto"
        nightmareStatusLabel.Text = "Nightmare: " .. method .. " " .. levelAddText(nightmareLevelAdd)
            .. " | Tower " .. info.Level .. " / " .. info.RequiredTowerLevel .. " for next Rebirth"
        nightmareStatusLabel.TextColor3 = COLORS.success
    else
        nightmareStatusLabel.Text = "Nightmare: Unlocked | Tower " .. info.Level .. " / " .. info.RequiredTowerLevel .. " for next Rebirth"
        nightmareStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

local function startSpecialBoss(mode, levelAdd, nativeAuto)
    local info = getSpecialBossState(mode)
    if not info.Unlocked then
        if mode == NIGHTMARE_MODE then
            refreshNightmareStatus()
        elseif mode == RED_DRAGON_MODE then
            refreshDeathKingStatus()
        else
            refreshCursedKingStatus()
        end
        return false
    end
    if mode == NIGHTMARE_MODE and info.BattleState == 0 and nightmarePortalPrimedCharacter ~= LocalPlayer.Character then
        primeNightmarePortal()
        task.wait(0.12)
    end
    local autoMode = nativeAuto and mode or 0
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeMode", autoMode)
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeLevelAdd", levelAdd)
    local resumeOk = fireRemote("setAfkResumeReq", autoMode, levelAdd)
    local startOk = fireRemote("startTimeLimitChallengeReq", mode, levelAdd)
    if resumeOk and startOk then
        specialLastStart[mode] = workspace:GetServerTimeNow()
        if mode == NIGHTMARE_MODE and info.BattleState == 0 and nightmarePortalPrimedCharacter ~= LocalPlayer.Character then
            task.delay(0.9, function()
                if not gui.Parent or getNightmareState().BattleState ~= 0 then
                    return
                end
                if primeNightmarePortal() then
                    task.wait(0.15)
                    fireRemote("setAfkResumeReq", autoMode, levelAdd)
                    fireRemote("startTimeLimitChallengeReq", mode, levelAdd)
                    specialLastStart[mode] = workspace:GetServerTimeNow()
                end
            end)
        end
        return true
    end
    return false
end

local function armDeathKingAuto()
    local info = getDeathKingState()
    local ok = startSpecialBoss(RED_DRAGON_MODE, deathKingLevelAdd, info.NativeAutoAvailable and not state.specialPriority)
    if ok then
        setReviveStatus("Death King auto " .. levelAddText(deathKingLevelAdd) .. " armed", true)
    end
    refreshDeathKingStatus()
    return ok
end

local function armCursedKingAuto()
    local info = getCursedKingState()
    local ok = startSpecialBoss(GREEN_DRAGON_MODE, cursedKingLevelAdd, info.NativeAutoAvailable and not state.specialPriority)
    if ok then
        setReviveStatus("Cursed King auto " .. levelAddText(cursedKingLevelAdd) .. " armed", true)
    end
    refreshCursedKingStatus()
    return ok
end

local function armNightmareAuto()
    local info = getNightmareState()
    local ok = startSpecialBoss(NIGHTMARE_MODE, nightmareLevelAdd, info.NativeAutoAvailable and not state.specialPriority)
    if ok then
        setReviveStatus("Nightmare auto " .. levelAddText(nightmareLevelAdd) .. " armed", true)
    end
    refreshNightmareStatus()
    return ok
end

local function disarmSpecialAuto()
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeMode", 0)
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeLevelAdd", 0)
    fireRemote("setAfkResumeReq", 0, 0)
end

priority.modeName = function(mode)
    return mode == NIGHTMARE_MODE and "Nightmare"
        or (mode == RED_DRAGON_MODE and "Death King" or "Cursed King")
end

priority.reset = function()
    priority.phase = "special"
    priority.wins = 0
    priority.nextMode = priority.target == "Cursed King" and GREEN_DRAGON_MODE
        or (priority.target == "Death King" and RED_DRAGON_MODE or NIGHTMARE_MODE)
    priority.activeMode = nil
    priority.activeLevelBefore = 0
    priority.lastLevels[RED_DRAGON_MODE] = getDeathKingState().Level
    priority.lastLevels[GREEN_DRAGON_MODE] = getCursedKingState().Level
    priority.lastLevels[NIGHTMARE_MODE] = getNightmareState().Level
    priority.seenResultSerial = specialResultSerial
    priority.nextStartAt = 0
    priority.multiEndAt = 0
    priority.quitDeadline = 0
    state.priorityMulti = false
end

priority.chooseMode = function()
    local deathInfo = getDeathKingState()
    local cursedInfo = getCursedKingState()
    local nightmareInfo = getNightmareState()
    if priority.target == "Nightmare" then
        return nightmareInfo.Unlocked and NIGHTMARE_MODE or nil
    end
    if priority.target == "Cursed King" then
        return cursedInfo.Unlocked and GREEN_DRAGON_MODE or nil
    end
    if priority.target == "Death King" then
        return deathInfo.Unlocked and RED_DRAGON_MODE or nil
    end
    if priority.target == "Cycle All" then
        local order = {RED_DRAGON_MODE, GREEN_DRAGON_MODE, NIGHTMARE_MODE}
        local startIndex = table.find(order, priority.nextMode) or 1
        for offset = 0, #order - 1 do
            local candidate = order[((startIndex + offset - 1) % #order) + 1]
            if getSpecialBossState(candidate).Unlocked then
                return candidate
            end
        end
        return nil
    end
    if nightmareInfo.Unlocked then
        return NIGHTMARE_MODE
    end
    if cursedInfo.Unlocked then
        return GREEN_DRAGON_MODE
    end
    return nil
end

priority.start = function()
    local mode = priority.chooseMode()
    if not mode then
        return false
    end
    local info = getSpecialBossState(mode)
    if startSpecialBoss(mode, priority.levelAdd, false) then
        priority.activeMode = mode
        priority.activeLevelBefore = info.Level
        priority.seenResultSerial = specialResultSerial
        priority.nextStartAt = os.clock() + 2.5
        priorityStatusLabel.Text = "Special Priority: Fighting " .. priority.modeName(mode)
        priorityStatusLabel.TextColor3 = COLORS.success
        return true
    end
    priority.nextStartAt = os.clock() + 2.5
    return false
end

priority.complete = function(success)
    local completedMode = priority.activeMode
    if not completedMode then
        return
    end
    priority.activeMode = nil
    priority.activeLevelBefore = 0
    priority.nextStartAt = os.clock() + 1
    if not success then
        priorityStatusLabel.Text = "Special Priority: " .. priority.modeName(completedMode) .. " retry queued"
        priorityStatusLabel.TextColor3 = COLORS.error
        return
    end

    priority.wins += 1
    if priority.target == "Cycle All" then
        priority.nextMode = completedMode == RED_DRAGON_MODE and GREEN_DRAGON_MODE
            or (completedMode == GREEN_DRAGON_MODE and NIGHTMARE_MODE or RED_DRAGON_MODE)
    end
    if priority.wins >= priority.winsPerCycle then
        priority.phase = "quit"
        priority.wins = 0
        priority.quitDeadline = os.clock() + 3.5
        state.priorityMulti = false
        multiHitNeedsBootstrap = true
        disarmSpecialAuto()
        for attempt = 0, 2 do
            task.delay(attempt * 0.16, function()
                if gui.Parent and state.specialPriority and priority.phase == "quit" then
                    fireRemote("levelTimeLimitBossReq")
                end
            end)
        end
        priorityStatusLabel.Text = "Special Priority: " .. priority.modeName(completedMode) .. " defeated | Exiting"
        priorityStatusLabel.TextColor3 = COLORS.success
    else
        priorityStatusLabel.Text = "Special Priority: " .. priority.wins .. " / " .. priority.winsPerCycle .. " special wins"
        priorityStatusLabel.TextColor3 = COLORS.success
    end
end

priority.observeProgress = function()
    for _, mode in ipairs({RED_DRAGON_MODE, GREEN_DRAGON_MODE, NIGHTMARE_MODE}) do
        local currentLevel = getSpecialBossState(mode).Level
        local previousLevel = priority.lastLevels[mode] or currentLevel
        priority.lastLevels[mode] = currentLevel
        if currentLevel < previousLevel then
            previousLevel = currentLevel
        end
        local matchesTarget = priority.target == "Cycle All"
            or (priority.target == "Nightmare" and mode == NIGHTMARE_MODE)
            or (priority.target == "Cursed King" and mode == GREEN_DRAGON_MODE)
            or (priority.target == "Death King" and mode == RED_DRAGON_MODE)
        if priority.phase == "special" and matchesTarget and currentLevel > previousLevel then
            if not priority.activeMode then
                priority.activeMode = mode
            end
            priority.complete(true)
            return true
        end
    end
    return false
end

priority.isMultiHitActive = function()
    if state.specialPriority then
        return state.priorityMulti
    end
    return state.multiHit
end

task.defer(refreshCursedKingStatus)
task.defer(refreshDeathKingStatus)
task.defer(refreshNightmareStatus)

local attackControl
local multiHitControl
local specialPriorityControl
local bossFarmControl
local multiHitDelay = 0.06
local multiHitTargetMode = "Unlocked Bosses Only"

attackControl = CombatSection:AddToggle({
    Name = "Auto Attack Latest Boss",
    Description = "Attacks your latest unlocked boss from anywhere",
    Flag = "revive_auto_attack",
    Callback = function(enabled)
        state.autoAttack = enabled
        if enabled and multiHitControl then
            state.multiHit = false
            multiHitControl:Set(false, true)
        end
        setReviveStatus(enabled and "Auto Attack Latest Boss enabled" or "Auto Attack Latest Boss disabled", enabled and true or nil)
    end,
})

multiHitControl = CombatSection:AddToggle({
    Name = "Multi Hit All Bosses",
    Description = "Attacks every selected boss level each cycle without moving your character",
    Flag = "revive_multi_hit_all_bosses",
    Callback = function(enabled)
        state.multiHit = enabled
        if enabled then
            multiHitNeedsBootstrap = true
        end
        if overnightMultiHitControl and overnightMultiHitControl:Get() ~= enabled then
            overnightMultiHitControl:Set(enabled, true)
        end
        if enabled and attackControl then
            state.autoAttack = false
            attackControl:Set(false, true)
        end
        multiHitStatusLabel.Text = enabled and "Multi Hit: Starting confirmed round-robin..." or "Multi Hit: Disabled"
        multiHitStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        setReviveStatus(enabled and ("Multi Hit enabled: " .. multiHitTargetMode) or "Multi Hit disabled", enabled and true or nil)
    end,
})

CombatSection:AddSlider({
    Name = "Multi Hit Retry Delay",
    Min = 0.03,
    Max = 0.30,
    Default = multiHitDelay,
    Step = 0.01,
    Flag = "revive_multi_hit_delay_fast_v3",
    Callback = function(value)
        multiHitDelay = math.clamp(tonumber(value) or 0.06, 0.03, 0.30)
    end,
})

CombatSection:AddDropdown({
    Name = "Multi Hit Targets",
    Options = {"Unlocked Bosses Only", "All 15 Bosses"},
    Default = "Unlocked Bosses Only",
    Flag = "revive_multi_hit_targets_v2",
    Callback = function(value)
        multiHitTargetMode = value == "All 15 Bosses" and value or "Unlocked Bosses Only"
        if state.multiHit then
            setReviveStatus("Multi Hit targets: " .. multiHitTargetMode, true)
        end
    end,
})

CombatSection:AddLabel("Waits for the server to confirm each boss before advancing. Your character never moves.")

local autoReaperControl
autoReaperControl = CombatSection:AddToggle({
    Name = "Auto Reaper",
    Description = "Uses the companion Reaper only when unlocked and its 20-second cooldown is ready",
    Flag = "revive_auto_reaper",
    Callback = function(enabled)
        state.reaper = enabled
        if overnightReaperControl and overnightReaperControl:Get() ~= enabled then
            overnightReaperControl:Set(enabled, true)
        end
        refreshReaperStatus()
        setReviveStatus(enabled and "Auto Reaper enabled (cooldown-aware)" or "Auto Reaper disabled", enabled and true or nil)
    end,
})

CombatSection:AddToggle({
    Name = "Auto Group Reward",
    Description = "Checks the group reward every 30 seconds",
    Flag = "revive_group_reward",
    Callback = function(enabled)
        state.groupReward = enabled
        setReviveStatus(enabled and "Group Reward checks enabled" or "Group Reward checks disabled", enabled and true or nil)
    end,
})

local challengeOneControl
local challengeFiveControl
local deathKingControl
local cursedKingControl
local nightmareControl
challengeOneControl = ChallengeSection:AddToggle({
    Name = "Challenge +1 Level",
    Description = "Repeats startTimeLimitChallengeReq(1, 0)",
    Flag = "revive_challenge_one",
    Callback = function(enabled)
        state.challengeOne = enabled
        if enabled and challengeFiveControl then
            state.challengeFive = false
            challengeFiveControl:Set(false, true)
        end
        if enabled and cursedKingControl then
            cursedKingControl:Set(false)
        end
        if enabled and nightmareControl then
            nightmareControl:Set(false)
        end
        if enabled and deathKingControl then
            deathKingControl:Set(false)
        end
    end,
})

challengeFiveControl = ChallengeSection:AddToggle({
    Name = "Challenge +5 Levels",
    Description = "Repeats startTimeLimitChallengeReq(1, 1)",
    Flag = "revive_challenge_five",
    Callback = function(enabled)
        state.challengeFive = enabled
        if enabled and challengeOneControl then
            state.challengeOne = false
            challengeOneControl:Set(false, true)
        end
        if enabled and cursedKingControl then
            cursedKingControl:Set(false)
        end
        if enabled and nightmareControl then
            nightmareControl:Set(false)
        end
        if enabled and deathKingControl then
            deathKingControl:Set(false)
        end
    end,
})

CursedKingSection:AddDropdown({
    Name = "Death King Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_death_king_level_gain",
    Callback = function(value)
        deathKingLevelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.deathKing and getDeathKingState().Unlocked then
            armDeathKingAuto()
        else
            refreshDeathKingStatus()
        end
    end,
})

deathKingControl = CursedKingSection:AddToggle({
    Name = "Auto Death King",
    Description = "Farms the RedDragon special boss continuously",
    Flag = "revive_auto_death_king",
    Callback = function(enabled)
        state.deathKing = enabled
        if overnightDeathKingControl and overnightDeathKingControl:Get() ~= enabled then
            overnightDeathKingControl:Set(enabled, true)
        end
        if enabled then
            if cursedKingControl then cursedKingControl:Set(false) end
            if nightmareControl then nightmareControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            local info = refreshDeathKingStatus()
            if info.Unlocked then
                armDeathKingAuto()
            else
                setReviveStatus("Death King armed; waiting for Main Level " .. info.RequiredMainLevel, nil)
            end
        else
            if not state.cursedKing and not state.nightmare and not state.specialPriority then
                disarmSpecialAuto()
            end
            refreshDeathKingStatus()
        end
    end,
})

CursedKingSection:AddButton({
    Name = "Start Death King Once",
    Description = "Starts one Death King run with the selected level gain",
    Persist = false,
    Callback = function()
        local info = refreshDeathKingStatus()
        if info.Unlocked then
            startSpecialBoss(RED_DRAGON_MODE, deathKingLevelAdd, false)
        else
            Window:Notify("Death King", "Requires Main Level " .. info.RequiredMainLevel .. ".", 4)
        end
    end,
})

CursedKingSection:AddDropdown({
    Name = "Cursed King Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_cursed_king_level_gain",
    Callback = function(value)
        cursedKingLevelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.cursedKing and getCursedKingState().Unlocked then
            armCursedKingAuto()
        else
            refreshCursedKingStatus()
        end
    end,
})

cursedKingControl = CursedKingSection:AddToggle({
    Name = "Auto Cursed King",
    Description = "Farms GreenDragon continuously; hub-managed before Rebirth 1 and native auto afterward",
    Flag = "revive_auto_cursed_king",
    Callback = function(enabled)
        state.cursedKing = enabled
        if overnightCursedKingControl and overnightCursedKingControl:Get() ~= enabled then
            overnightCursedKingControl:Set(enabled, true)
        end
        if enabled then
            if deathKingControl then deathKingControl:Set(false) end
            if nightmareControl then nightmareControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            local info = refreshCursedKingStatus()
            if info.Unlocked then
                armCursedKingAuto()
            else
                setReviveStatus("Cursed King armed; waiting for Main Level " .. info.RequiredMainLevel, nil)
            end
        else
            if not state.deathKing and not state.nightmare and not state.specialPriority then
                disarmSpecialAuto()
            end
            refreshCursedKingStatus()
            setReviveStatus("Auto Cursed King disabled", nil)
        end
    end,
})

CursedKingSection:AddButton({
    Name = "Start Cursed King Once",
    Description = "Starts one Cursed King run with the selected level gain when ownership is unlocked",
    Persist = false,
    Callback = function()
        local info = refreshCursedKingStatus()
        if info.Unlocked then
            startSpecialBoss(GREEN_DRAGON_MODE, cursedKingLevelAdd, false)
        else
            Window:Notify("Cursed King", "Requires Main Level " .. info.RequiredMainLevel .. ".", 4)
        end
    end,
})

CursedKingSection:AddDropdown({
    Name = "Nightmare Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_nightmare_level_gain",
    Callback = function(value)
        nightmareLevelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.nightmare and getNightmareState().Unlocked then
            armNightmareAuto()
        else
            refreshNightmareStatus()
        end
    end,
})

nightmareControl = CursedKingSection:AddToggle({
    Name = "Auto Nightmare",
    Description = "Farms Death Tower continuously so its level can reach the next Rebirth requirement",
    Flag = "revive_auto_nightmare",
    Callback = function(enabled)
        state.nightmare = enabled
        if overnightNightmareControl and overnightNightmareControl:Get() ~= enabled then
            overnightNightmareControl:Set(enabled, true)
        end
        if enabled then
            if deathKingControl then deathKingControl:Set(false) end
            if cursedKingControl then cursedKingControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            local info = refreshNightmareStatus()
            if info.Unlocked then
                armNightmareAuto()
            else
                setReviveStatus("Nightmare armed; waiting for Main Level " .. info.RequiredMainLevel, nil)
            end
        else
            if not state.deathKing and not state.cursedKing and not state.specialPriority then
                disarmSpecialAuto()
            end
            refreshNightmareStatus()
            setReviveStatus("Auto Nightmare disabled", nil)
        end
    end,
})

CursedKingSection:AddButton({
    Name = "Start Nightmare Once",
    Description = "Starts one Death Tower run with the selected +1 / +5 / +10 level gain",
    Persist = false,
    Callback = function()
        local info = refreshNightmareStatus()
        if info.Unlocked then
            startSpecialBoss(NIGHTMARE_MODE, nightmareLevelAdd, false)
        else
            Window:Notify("Nightmare", "Requires Main Level " .. info.RequiredMainLevel .. ".", 4)
        end
    end,
})

CursedKingSection:AddLabel("Cursed King = GreenDragon mode 2 | Nightmare = Death Tower mode 3")

SpecialPrioritySection:AddDropdown({
    Name = "Priority Special Boss",
    Options = {"Nightmare", "Cursed King", "Death King", "Cycle All"},
    Default = "Nightmare",
    Flag = "revive_priority_special_target_v2",
    Callback = function(value)
        priority.target = (value == "Cursed King" or value == "Death King" or value == "Cycle All") and value or "Nightmare"
        if state.specialPriority then
            priority.reset()
            priorityStatusLabel.Text = "Special Priority: Target changed to " .. priority.target
            priorityStatusLabel.TextColor3 = COLORS.success
        end
    end,
})

SpecialPrioritySection:AddDropdown({
    Name = "Priority Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_priority_level_gain_v2",
    Callback = function(value)
        priority.levelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.specialPriority then
            priority.reset()
            setReviveStatus("Special priority level gain set to " .. levelAddText(priority.levelAdd), true)
        end
    end,
})

SpecialPrioritySection:AddSlider({
    Name = "Special Wins Per Cycle",
    Min = 1,
    Max = 5,
    Default = 1,
    Step = 1,
    Flag = "revive_priority_special_wins_v2",
    Callback = function(value)
        priority.winsPerCycle = math.clamp(math.floor((tonumber(value) or 1) + 0.5), 1, 5)
    end,
})

SpecialPrioritySection:AddSlider({
    Name = "Multi Hit Window",
    Min = 1,
    Max = 60,
    Default = 5,
    Step = 1,
    Suffix = "s",
    Flag = "revive_priority_multi_seconds_v2",
    Callback = function(value)
        priority.multiSeconds = math.clamp(math.floor((tonumber(value) or 5) + 0.5), 1, 60)
    end,
})

specialPriorityControl = SpecialPrioritySection:AddToggle({
    Name = "Special Boss Priority",
    Description = "Kills the selected special boss, runs timed Multi Hit, then repeats while advancing tower sections",
    Flag = "revive_special_boss_priority_v2",
    Callback = function(enabled)
        state.specialPriority = enabled
        if overnightSpecialPriorityControl and overnightSpecialPriorityControl:Get() ~= enabled then
            overnightSpecialPriorityControl:Set(enabled, true)
        end
        if enabled then
            if deathKingControl then deathKingControl:Set(false) end
            if cursedKingControl then cursedKingControl:Set(false) end
            if nightmareControl then nightmareControl:Set(false) end
            if attackControl then attackControl:Set(false) end
            if bossFarmControl then bossFarmControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            disarmSpecialAuto()
            priority.reset()
            multiHitNeedsBootstrap = true
            priorityStatusLabel.Text = "Special Priority: AFK climb armed for " .. priority.target
            priorityStatusLabel.TextColor3 = COLORS.success
            setReviveStatus("Special boss priority enabled: " .. priority.target, true)
        else
            priority.reset()
            if not state.deathKing and not state.cursedKing and not state.nightmare then
                disarmSpecialAuto()
            end
            priorityStatusLabel.Text = "Special Priority: Disabled"
            priorityStatusLabel.TextColor3 = COLORS.muted
            setReviveStatus("Special boss priority disabled", nil)
        end
    end,
})

SpecialPrioritySection:AddLabel("AFK loop: selected special wins -> timed Multi Hit -> next Death Tower / Cursed King section.")
SpecialPrioritySection:AddLabel("Nightmare progress raises Death Tower level; Rebirth 1 requires Death Tower 5.")

local dailyRewardControl
dailyRewardControl = RewardSection:AddToggle({
    Name = "Auto Daily Sign",
    Description = "Claims the daily sign reward when it becomes available",
    Flag = "revive_daily_sign",
    Callback = function(enabled)
        state.dailyReward = enabled
    end,
})

local onlineRewardControl
onlineRewardControl = RewardSection:AddToggle({
    Name = "Auto Online Rewards",
    Description = "Checks the online-time reward every five seconds",
    Flag = "revive_online_rewards",
    Callback = function(enabled)
        state.onlineReward = enabled
    end,
})

local soulSpawnerControl
soulSpawnerControl = RewardSection:AddToggle({
    Name = "Auto Soul Spawner",
    Description = "Claims accumulated Soul Spawner rewards when unlocked",
    Flag = "revive_soul_spawner",
    Callback = function(enabled)
        state.soulSpawner = enabled
    end,
})

local starterRewardControl
starterRewardControl = RewardSection:AddToggle({
    Name = "Auto Starter Rewards",
    Description = "Checks verified starter milestones 1 through 5",
    Flag = "revive_starter_rewards",
    Callback = function(enabled)
        state.starterRewards = enabled
    end,
})

local bossRewardControl
bossRewardControl = RewardSection:AddToggle({
    Name = "Auto Boss Rewards",
    Description = "Checks Time-Limit Boss reward indexes 1 through 6",
    Flag = "revive_boss_rewards",
    Callback = function(enabled)
        state.bossRewards = enabled
    end,
})

RewardSection:AddButton({
    Name = "Claim Available Rewards Now",
    Description = "Runs one safe claim pass without enabling any toggle",
    Persist = false,
    Callback = function()
        fireRemote("getSignReward")
        fireRemote("receiveOnlineTimeReward")
        fireRemote("claimSoulSpawner")
        fireRemote("getGroupReward")
        for index = 1, 5 do
            fireRemote("claimChallengeReward", index)
        end
        for index = 1, 6 do
            fireRemote("claimTimeLimitBossReward", index)
        end
        setReviveStatus("Reward claim pass sent", true)
    end,
})

local weaponStore = nil
local weaponConfig = nil
pcall(function()
    weaponStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("weapon"))
    weaponConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbweapon"))
end)

local function getOwnedWeapons()
    if not weaponStore or type(weaponStore.AtomWeapons) ~= "function" then
        return nil
    end
    local ok, owned = pcall(function()
        return weaponStore.AtomWeapons()()
    end)
    return ok and type(owned) == "table" and owned or nil
end

local function getEquippedWeaponId()
    if not weaponStore or type(weaponStore.AtomEquippedWeaponId) ~= "function" then
        return nil
    end
    local ok, equipped = pcall(function()
        return weaponStore.AtomEquippedWeaponId()()
    end)
    return ok and type(equipped) == "string" and equipped or nil
end

local function getWeaponInfo(weaponId)
    return weaponConfig and type(weaponConfig[weaponId]) == "table" and weaponConfig[weaponId] or nil
end

local function getWeaponDisplayName(weaponId)
    local info = getWeaponInfo(weaponId)
    return info and tostring(info.name or info.desc or weaponId) or tostring(weaponId or "N/A")
end

local function getLastUnlockedWeaponId()
    local owned = getOwnedWeapons()
    if not owned then
        return nil
    end
    local bestId = nil
    local bestSort = -math.huge
    for weaponId in pairs(owned) do
        local info = getWeaponInfo(weaponId)
        local order = info and tonumber(info.sort) or tonumber(tostring(weaponId):match("%d+")) or 0
        if order > bestSort then
            bestSort = order
            bestId = weaponId
        end
    end
    return bestId
end

local refreshWeaponStatus
local selectedOwnedWeaponId = nil
local ownedWeaponOptionToId = {}
local ownedWeaponDropdown = nil

local function refreshOwnedWeaponOptions()
    local owned = getOwnedWeapons() or {}
    local ordered = {}
    for weaponId, weaponState in pairs(owned) do
        local info = getWeaponInfo(weaponId)
        table.insert(ordered, {
            Id = weaponId,
            Name = getWeaponDisplayName(weaponId),
            Level = type(weaponState) == "table" and tonumber(weaponState.Level) or nil,
            Sort = info and tonumber(info.sort) or tonumber(tostring(weaponId):match("%d+")) or 0,
        })
    end
    table.sort(ordered, function(left, right)
        return left.Sort < right.Sort
    end)

    local options = {}
    ownedWeaponOptionToId = {}
    for _, entry in ipairs(ordered) do
        local label = entry.Name .. (entry.Level and (" | Lv." .. entry.Level) or "")
        table.insert(options, label)
        ownedWeaponOptionToId[label] = entry.Id
    end
    if #options == 0 then
        options = {"Inventory is still loading..."}
    end
    if ownedWeaponDropdown then
        ownedWeaponDropdown:SetOptions(options, false)
    end
    selectedOwnedWeaponId = nil
    return options
end

ownedWeaponDropdown = WeaponInfoSection:AddDropdown({
    Name = "Owned Weapon",
    Options = refreshOwnedWeaponOptions(),
    Placeholder = "Choose an owned weapon...",
    Persist = false,
    Callback = function(value)
        selectedOwnedWeaponId = ownedWeaponOptionToId[value]
    end,
})

WeaponInfoSection:AddButton({
    Name = "Equip Selected Weapon",
    Description = "Equips the owned sword selected above",
    Persist = false,
    Callback = function()
        if not selectedOwnedWeaponId then
            setReviveStatus("Choose an owned weapon first", false)
            return
        end
        if fireRemote("equipWeapon", selectedOwnedWeaponId) then
            refreshWeaponStatus("equipping " .. getWeaponDisplayName(selectedOwnedWeaponId))
            setReviveStatus("Selected sword equip request sent", true)
        end
    end,
})

WeaponInfoSection:AddButton({
    Name = "Refresh Owned Weapons",
    Description = "Refresh after a new sword unlocks while the hub is open",
    Persist = false,
    Callback = function()
        local options = refreshOwnedWeaponOptions()
        setReviveStatus("Found " .. tostring(#options) .. " owned weapon entries", true)
    end,
})

WeaponInfoSection:AddLabel("Only live inventory entries are listed, so locked swords are never auto-equipped.")

refreshWeaponStatus = function(extra)
    local equipped = getEquippedWeaponId()
    local best = getLastUnlockedWeaponId()
    local text = "Sword: " .. getWeaponDisplayName(equipped)
    if best then
        text ..= " | Last unlocked: " .. getWeaponDisplayName(best)
    end
    if extra then
        text ..= " | " .. tostring(extra)
    end
    weaponStatusLabel.Text = text
    weaponStatusLabel.TextColor3 = equipped and COLORS.success or COLORS.muted
end

local function equipLastUnlockedWeapon()
    local bestId = getLastUnlockedWeaponId()
    if not bestId then
        refreshWeaponStatus("inventory unavailable")
        return false
    end
    local equipped = getEquippedWeaponId()
    if equipped ~= bestId then
        if not fireRemote("equipWeapon", bestId) then
            return false
        end
        refreshWeaponStatus("equipping " .. getWeaponDisplayName(bestId))
    else
        refreshWeaponStatus("best equipped")
    end
    return true
end

local autoEquipBestControl
autoEquipBestControl = UpgradeSection:AddToggle({
    Name = "Auto Equip Last Unlocked",
    Description = "Equips the owned weapon with the highest order in the game's weapon data",
    Flag = "revive_auto_equip_best",
    Callback = function(enabled)
        state.autoEquipBest = enabled
        if overnightAutoEquipControl and overnightAutoEquipControl:Get() ~= enabled then
            overnightAutoEquipControl:Set(enabled, true)
        end
        if enabled then
            equipLastUnlockedWeapon()
        else
            refreshWeaponStatus()
        end
    end,
})

UpgradeSection:AddButton({
    Name = "Equip Last Unlocked Now",
    Description = "Runs one inventory check and equips your newest owned weapon",
    Persist = false,
    Callback = function()
        if equipLastUnlockedWeapon() then
            setReviveStatus("Last unlocked sword equip request sent", true)
        end
    end,
})

local autoUpgradeControl
autoUpgradeControl = UpgradeSection:AddToggle({
    Name = "Auto Upgrade Equipped Sword",
    Description = "Enhances the sword currently held; automatically follows equipment changes",
    Flag = "revive_auto_upgrade",
    Callback = function(enabled)
        state.autoUpgrade = enabled
        if overnightAutoUpgradeControl and overnightAutoUpgradeControl:Get() ~= enabled then
            overnightAutoUpgradeControl:Set(enabled, true)
        end
        refreshWeaponStatus(enabled and "auto upgrade on" or nil)
    end,
})

UpgradeSection:AddLabel("Special weapons marked non-enhanceable by the game are safely skipped.")
task.defer(refreshWeaponStatus)

local autoRebirthFloor = 1
local autoRebirthControl
local rebirthStatusLabel = RebirthSection:AddLabel("Auto Rebirth: Waiting for live Death Tower requirement")
RebirthSection:AddSlider({
    Name = "Rebirth Floor",
    Min = 1,
    Max = 100,
    Default = 1,
    Step = 1,
    Flag = "revive_rebirth_floor",
    Callback = function(value)
        autoRebirthFloor = math.floor(value)
        if state.autoRebirth then
            fireRemote("SetAutoRebirth", true, autoRebirthFloor)
        end
    end,
})

autoRebirthControl = RebirthSection:AddToggle({
    Name = "Auto Rebirth",
    Description = "Directly uses the game's rebirth request when your live Death Tower requirement is met",
    Flag = "revive_auto_rebirth",
    Callback = function(enabled)
        state.autoRebirth = enabled
        -- Also mirror the game's optional native setting when its gamepass exists,
        -- but the hub's direct requirement-aware loop does not depend on it.
        if remotes.SetAutoRebirth then
            fireRemote("SetAutoRebirth", enabled, autoRebirthFloor)
        end
        if overnightAutoRebirthControl and overnightAutoRebirthControl:Get() ~= enabled then
            overnightAutoRebirthControl:Set(enabled, true)
        end
        rebirthStatusLabel.Text = enabled and "Auto Rebirth: Armed" or "Auto Rebirth: Disabled"
        rebirthStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        setReviveStatus(enabled and "Auto Rebirth armed from live tower progress" or "Auto Rebirth disabled", enabled and true or nil)
    end,
})

RebirthSection:AddLabel("The server validates Death Tower progress. Native gamepass auto is mirrored when available.")

do
local soulRingStore = nil
local soulRingUIStore = nil
local soulRingConfig = nil
pcall(function()
    soulRingStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("soulring"))
    soulRingUIStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("ui-store")).GetUIStore()
    soulRingConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbsoulring"))
end)

local function getSoulRingResourceCount(itemId)
    local playerData = soulRingUIStore and soulRingUIStore.playerData and soulRingUIStore.playerData()
    for _, item in ipairs(playerData and playerData.Inventory or {}) do
        if tostring(item.id) == itemId then
            return tonumber(item.count) or 0
        end
    end
    return 0
end

local function getSoulRingInfo()
    local rings = {}
    pcall(function()
        local atom = soulRingStore and soulRingStore.AtomSoulRings and soulRingStore.AtomSoulRings(0)
        rings = type(atom) == "function" and atom() or {}
    end)
    local ring = rings[1]
    local configEntry = nil
    if ring and soulRingConfig then
        configEntry = soulRingConfig[ring.Id]
        if not configEntry and type(soulRingConfig.get) == "function" then
            pcall(function()
                configEntry = soulRingConfig:get(ring.Id)
            end)
        end
    end
    return {
        Available = ring ~= nil,
        Id = ring and tostring(ring.Id) or "Locked",
        Name = configEntry and tostring(configEntry.name) or (ring and tostring(ring.Id) or "Locked"),
        Description = configEntry and tostring(configEntry.desc) or "Rebirth once to unlock Soul Ring slot 1.",
        Level = ring and (tonumber(ring.Level) or 0) or 0,
        Value = ring and (tonumber(ring.Value) or 0) or 0,
        SoulStones = getSoulRingResourceCount("SkillStone"),
        Rerolls = getSoulRingResourceCount("SkillRerollStone"),
    }
end

local function refreshSoulRingStatus(prefix)
    local info = getSoulRingInfo()
    if info.Available then
        soulRingStatusLabel.Text = string.format(
            "Soul Ring: %s | Level %d | %.2f%%",
            info.Name,
            info.Level,
            info.Value * 100
        )
        soulRingStatusLabel.TextColor3 = COLORS.success
        soulRingCurrencyLabel.Text = "Soul Stones: " .. info.SoulStones .. " | Rerolls: " .. info.Rerolls
        soulRingCurrencyLabel.TextColor3 = COLORS.muted
    else
        soulRingStatusLabel.Text = "Soul Ring: Slot 1 is locked until Rebirth 1"
        soulRingStatusLabel.TextColor3 = COLORS.error
        soulRingCurrencyLabel.Text = "Soul Stones: " .. info.SoulStones .. " | Rerolls: " .. info.Rerolls
    end
    if prefix then
        setReviveStatus(prefix, true)
    end
    return info
end

local soulRingUpgradeBatch = 1
state.soulRingUpgradeBatch = soulRingUpgradeBatch
SoulRingSection:AddDropdown({
    Name = "Upgrade Levels Per Request",
    Options = {"1", "10", "50", "100"},
    Default = "1",
    Flag = "revive_soul_ring_upgrade_batch",
    Callback = function(value)
        soulRingUpgradeBatch = tonumber(value) or 1
        state.soulRingUpgradeBatch = soulRingUpgradeBatch
    end,
})

SoulRingSection:AddButton({
    Name = "Upgrade Soul Ring Now",
    Description = "Upgrades page 1, slot 1 with the selected batch size",
    Persist = false,
    Callback = function()
        local info = refreshSoulRingStatus()
        if not info.Available then
            Window:Notify("Soul Ring", "Slot 1 unlocks after your first Rebirth.", 4)
            return
        end
        if fireRemote("enhanceSoulRing", 0, 0, soulRingUpgradeBatch) then
            task.delay(0.4, refreshSoulRingStatus)
        end
    end,
})

state.autoSoulRingControl = SoulRingSection:AddToggle({
    Name = "Auto Upgrade Soul Ring",
    Description = "Continuously upgrades page 1, slot 1 using your selected batch",
    Flag = "revive_auto_soul_ring",
    Callback = function(enabled)
        state.autoSoulRing = enabled
        if overnightAutoSoulRingControl and overnightAutoSoulRingControl:Get() ~= enabled then
            overnightAutoSoulRingControl:Set(enabled, true)
        end
        setReviveStatus(enabled and "Auto Soul Ring upgrade enabled" or "Auto Soul Ring upgrade disabled", enabled and true or nil)
    end,
})

SoulRingSection:AddButton({
    Name = "Reroll Soul Ring Once",
    Description = "Spends one reroll stone on page 1, slot 1",
    Persist = false,
    Callback = function()
        local info = refreshSoulRingStatus()
        if not info.Available or info.Rerolls < 1 then
            Window:Notify("Soul Ring", "No available Soul Ring reroll.", 4)
            return
        end
        if fireRemote("rerollSoulRing", 0, 0, 1) then
            task.delay(0.5, refreshSoulRingStatus)
        end
    end,
})

SoulRingSection:AddLabel("Tracks the live Soul Ring name, level, Soul Stones, and reroll stones. Reroll stays manual.")
state.refreshSoulRingStatus = refreshSoulRingStatus
task.defer(refreshSoulRingStatus)
end

local selectedEnemy = 1
local tweenSpeed = 90
local tweenOffsetX = 0
local tweenOffsetY = 0
local tweenOffsetZ = -4.5
local activeEnemyTween = nil
local controlledHumanoid = nil
local originalAutoRotate = nil
local lockedEnemyFacing = setmetatable({}, {__mode = "k"})
bossFarmControl = nil
local manualTweenControl = nil

local battleStore = nil
local mainChallengeConfig = nil
pcall(function()
    battleStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("battle"))
    mainChallengeConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbmainchallenge"))
end)

local function getLatestUnlockedBossLevel()
    if battleStore and type(battleStore.AtomMainLevel) == "function" then
        local ok, value = pcall(function()
            return battleStore.AtomMainLevel()()
        end)
        if ok and tonumber(value) then
            -- The store reports the last completed stage; the active/latest boss is the next slot.
            return math.clamp(math.floor(tonumber(value)) + 1, 1, 15)
        end
    end
    return math.clamp(selectedEnemy, 1, 15)
end

local function getBossName(level)
    local info = mainChallengeConfig and mainChallengeConfig[level]
    return info and tostring(info.name or ("Boss " .. level)) or ("Boss " .. level)
end

local function stopEnemyTween()
    if activeEnemyTween then
        activeEnemyTween:Cancel()
        activeEnemyTween = nil
    end
    if controlledHumanoid and controlledHumanoid.Parent and originalAutoRotate ~= nil then
        controlledHumanoid.AutoRotate = originalAutoRotate
    end
    controlledHumanoid = nil
    originalAutoRotate = nil
end

local function findEnemyPart(number)
    local folder = workspace:FindFirstChild("Enemies")
    local enemy = folder and folder:FindFirstChild(tostring(number))
    if not enemy then
        return nil
    end
    if enemy:IsA("BasePart") then
        return enemy
    end
    local preferred = enemy:FindFirstChild("HumanoidRootPart", true)
        or enemy:FindFirstChild("RootPart", true)
    if preferred and preferred:IsA("BasePart") then
        return preferred
    end
    if enemy:IsA("Model") and enemy.PrimaryPart then
        return enemy.PrimaryPart
    end
    return enemy:FindFirstChildWhichIsA("BasePart", true)
end

bossFarmControl = FarmSection:AddToggle({
    Name = "Auto Farm Latest Boss",
    Description = "Targets Main Level + 1, then follows the next boss as soon as it unlocks",
    Flag = "revive_boss_progression_farm",
    Callback = function(enabled)
        state.bossFarm = enabled
        if overnightBossFarmControl and overnightBossFarmControl:Get() ~= enabled then
            overnightBossFarmControl:Set(enabled, true)
        end
        if enabled and manualTweenControl then
            state.autoTween = false
            manualTweenControl:Set(false, true)
        end
        if not enabled then
            stopEnemyTween()
            farmStatusLabel.Text = "Farm: Disabled"
            farmStatusLabel.TextColor3 = COLORS.muted
        else
            local level = getLatestUnlockedBossLevel()
            farmStatusLabel.Text = "Farm: Level " .. level .. " - " .. getBossName(level)
            farmStatusLabel.TextColor3 = COLORS.success
        end
    end,
})

FarmSection:AddLabel("Uses Main Level + 1: store 5 targets boss 6, then store 6 targets boss 7.")
FarmSection:AddLabel("Combat position uses the Enemy Tween speed and X / Y / Z sliders below.")

local enemyOptions = {}
for index = 1, 15 do
    table.insert(enemyOptions, tostring(index))
end

TweenSection:AddDropdown({
    Name = "Enemy",
    Options = enemyOptions,
    Default = "1",
    Flag = "revive_enemy",
    Callback = function(value)
        selectedEnemy = tonumber(value) or 1
        tweenStatusLabel.Text = "Tween: Enemy " .. tostring(selectedEnemy) .. " selected"
    end,
})

manualTweenControl = TweenSection:AddToggle({
    Name = "Auto Tween",
    Description = "Smoothly follows the selected enemy, stays upright, and faces its center",
    Flag = "revive_auto_tween",
    Callback = function(enabled)
        state.autoTween = enabled
        if enabled and bossFarmControl then
            state.bossFarm = false
            bossFarmControl:Set(false, true)
            farmStatusLabel.Text = "Farm: Disabled (manual tween active)"
            farmStatusLabel.TextColor3 = COLORS.muted
        end
        if not enabled then
            stopEnemyTween()
        end
    end,
})

TweenSection:AddSlider({
    Name = "Tween Speed",
    Min = 20,
    Max = 240,
    Default = tweenSpeed,
    Step = 5,
    Flag = "revive_tween_speed",
    Callback = function(value)
        tweenSpeed = value
    end,
})

TweenSection:AddSlider({
    Name = "Offset X",
    Min = -15,
    Max = 15,
    Default = tweenOffsetX,
    Step = 0.5,
    Flag = "revive_offset_x",
    Callback = function(value)
        tweenOffsetX = value
    end,
})

TweenSection:AddSlider({
    Name = "Offset Y",
    Min = -10,
    Max = 15,
    Default = tweenOffsetY,
    Step = 0.5,
    Flag = "revive_offset_y",
    Callback = function(value)
        tweenOffsetY = value
    end,
})

TweenSection:AddSlider({
    Name = "Offset Z",
    Min = -15,
    Max = 15,
    Default = tweenOffsetZ,
    Step = 0.5,
    Flag = "revive_offset_z",
    Callback = function(value)
        tweenOffsetZ = value
    end,
})

local VISUAL_COLORS = {
    ["Frozen White"] = Color3.fromRGB(225, 248, 255),
    ["Glacier Blue"] = Color3.fromRGB(92, 205, 255),
    ["Deep Ice"] = Color3.fromRGB(62, 130, 255),
    ["Arctic Cyan"] = Color3.fromRGB(96, 255, 245),
}
local visualColor = VISUAL_COLORS["Frozen White"]
local visualState = {outline = false, aura = false, trail = false, glow = false, wings = false, halo = false, nameplate = false, frozenOutfit = false}
local visualConnections = {}

local function markVisual(object)
    object:SetAttribute("CodexReviveVisual", true)
    return object
end

local function trackVisualConnection(connection)
    table.insert(visualConnections, connection)
    return connection
end

local function makeNeonPart(name, size, cframe, parent, color, transparency, shape)
    local part = markVisual(Instance.new("Part"))
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Massless = true
    part.Material = Enum.Material.Neon
    part.Color = color or visualColor
    part.Transparency = transparency or 0
    part.Shape = shape or Enum.PartType.Block
    part.Parent = parent
    return part
end

local function weldVisualPart(part, basePart)
    local weld = markVisual(Instance.new("WeldConstraint"))
    weld.Name = "CodexVisualWeld"
    weld.Part0 = basePart
    weld.Part1 = part
    weld.Parent = part
    return weld
end

local function makeWingSegment(model, core, localStart, localFinish, width, color, transparency)
    local worldStart = core.CFrame:PointToWorldSpace(localStart)
    local worldFinish = core.CFrame:PointToWorldSpace(localFinish)
    local length = (worldFinish - worldStart).Magnitude
    if length <= 0.01 then
        return nil
    end
    local segment = makeNeonPart(
        "IceFeather",
        Vector3.new(length, width, width),
        CFrame.lookAt((worldStart + worldFinish) * 0.5, worldFinish) * CFrame.Angles(0, math.rad(90), 0),
        model,
        color,
        transparency,
        Enum.PartType.Cylinder
    )
    weldVisualPart(segment, core)
    return segment
end

local function createFrozenAngelWings(character, torso)
    local wingModel = markVisual(Instance.new("Model"))
    wingModel.Name = "CodexFrozenAngelWings"
    wingModel.Parent = character

    local highlight = markVisual(Instance.new("Highlight"))
    highlight.Name = "WingIceBloom"
    highlight.Adornee = wingModel
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = visualColor
    highlight.FillTransparency = 0.72
    highlight.OutlineColor = Color3.fromRGB(246, 253, 255)
    highlight.OutlineTransparency = 0.18
    highlight.Parent = wingModel

    local wingMotors = {}
    local featherTips = {
        Vector3.new(1.15, 1.75, 0.02),
        Vector3.new(2.05, 2.05, 0.06),
        Vector3.new(2.95, 1.72, 0.10),
        Vector3.new(3.55, 1.05, 0.14),
        Vector3.new(3.62, 0.25, 0.18),
        Vector3.new(3.15, -0.55, 0.22),
        Vector3.new(2.35, -1.20, 0.26),
    }

    for _, side in ipairs({-1, 1}) do
        local core = makeNeonPart(
            side == -1 and "LeftWingCore" or "RightWingCore",
            Vector3.new(0.2, 0.2, 0.2),
            torso.CFrame * CFrame.new(0, 0.25, 0.62),
            wingModel,
            visualColor,
            1,
            Enum.PartType.Ball
        )
        local motor = markVisual(Instance.new("Motor6D"))
        motor.Name = side == -1 and "LeftWingMotor" or "RightWingMotor"
        motor.Part0 = torso
        motor.Part1 = core
        motor.C0 = CFrame.new(0, 0.25, 0.62)
        motor.Parent = torso
        wingMotors[side] = motor

        local previousTip = nil
        for index, baseTip in ipairs(featherTips) do
            local tip = Vector3.new(baseTip.X * side, baseTip.Y, baseTip.Z)
            local root = Vector3.new((0.20 + index * 0.075) * side, 0.46 - index * 0.07, 0)
            local middle = root:Lerp(tip, 0.48) + Vector3.new(0.12 * side, 0.30, -0.07)
            local width = 0.24 - index * 0.012
            local featherColor = index % 2 == 0 and visualColor:Lerp(SNOW_WHITE, 0.45) or visualColor
            makeWingSegment(wingModel, core, root, middle, width, featherColor, 0.05)
            makeWingSegment(wingModel, core, middle, tip, width * 0.72, featherColor:Lerp(SNOW_WHITE, 0.32), 0.10)

            local ribbonRoot = markVisual(Instance.new("Attachment"))
            ribbonRoot.Name = "FeatherRibbonRoot"
            ribbonRoot.Position = root
            ribbonRoot.Parent = core
            local ribbonTip = markVisual(Instance.new("Attachment"))
            ribbonTip.Name = "FeatherRibbonTip"
            ribbonTip.Position = tip
            ribbonTip.Parent = core
            local ribbon = markVisual(Instance.new("Beam"))
            ribbon.Name = "LuminousIceFeather"
            ribbon.Attachment0 = ribbonRoot
            ribbon.Attachment1 = ribbonTip
            ribbon.Color = ColorSequence.new(featherColor, Color3.fromRGB(248, 254, 255))
            ribbon.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.28),
                NumberSequenceKeypoint.new(0.72, 0.40),
                NumberSequenceKeypoint.new(1, 0.78),
            })
            ribbon.Width0 = width * 1.9
            ribbon.Width1 = width * 0.42
            ribbon.LightEmission = 1
            ribbon.LightInfluence = 0
            ribbon.Segments = 5
            ribbon.FaceCamera = true
            ribbon.Parent = core

            local crystal = makeNeonPart(
                "FeatherCrystal",
                Vector3.new(width * 1.35, width * 1.35, width * 1.35),
                core.CFrame * CFrame.new(tip),
                wingModel,
                Color3.fromRGB(244, 253, 255),
                0.12,
                Enum.PartType.Ball
            )
            weldVisualPart(crystal, core)
            if previousTip then
                makeWingSegment(wingModel, core, previousTip, tip, 0.075, visualColor:Lerp(SNOW_WHITE, 0.58), 0.22)
            end
            previousTip = tip
        end

        local rootLight = markVisual(Instance.new("PointLight"))
        rootLight.Name = "WingRootGlow"
        rootLight.Color = visualColor
        rootLight.Brightness = 1.4
        rootLight.Range = 10
        rootLight.Shadows = false
        rootLight.Parent = core

        local sparkleAttachment = markVisual(Instance.new("Attachment"))
        sparkleAttachment.Name = "WingSparkleAttachment"
        sparkleAttachment.Parent = core
        local sparkles = markVisual(Instance.new("ParticleEmitter"))
        sparkles.Name = "WingFrostSparkles"
        sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        sparkles.Color = ColorSequence.new(visualColor, SNOW_WHITE)
        sparkles.LightEmission = 1
        sparkles.Rate = 5
        sparkles.Lifetime = NumberRange.new(0.7, 1.35)
        sparkles.Speed = NumberRange.new(0.35, 1.1)
        sparkles.SpreadAngle = Vector2.new(80, 80)
        sparkles.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.20),
            NumberSequenceKeypoint.new(1, 0),
        })
        sparkles.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.10),
            NumberSequenceKeypoint.new(1, 1),
        })
        sparkles.Parent = sparkleAttachment
    end

    local animationStart = os.clock()
    trackVisualConnection(RunService.RenderStepped:Connect(function()
        if not wingModel.Parent then
            return
        end
        local phase = math.sin((os.clock() - animationStart) * 2.15)
        for side, motor in pairs(wingMotors) do
            if motor.Parent then
                motor.C0 = CFrame.new(0, 0.25, 0.62) * CFrame.Angles(
                    math.rad(phase * 1.2),
                    math.rad(side * phase * 4.2),
                    math.rad(side * phase * 2.4)
                )
            end
        end
    end))
end

local function createFrozenHalo(character, head)
    local haloModel = markVisual(Instance.new("Model"))
    haloModel.Name = "CodexFrozenHalo"
    haloModel.Parent = character

    local haloHighlight = markVisual(Instance.new("Highlight"))
    haloHighlight.Name = "HaloIceBloom"
    haloHighlight.Adornee = haloModel
    haloHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    haloHighlight.FillColor = visualColor
    haloHighlight.FillTransparency = 0.48
    haloHighlight.OutlineColor = Color3.fromRGB(246, 253, 255)
    haloHighlight.OutlineTransparency = 0.08
    haloHighlight.Parent = haloModel

    local core = makeNeonPart(
        "HaloCore",
        Vector3.new(0.16, 0.16, 0.16),
        head.CFrame * CFrame.new(0, 1.58, 0) * CFrame.Angles(math.rad(-32), 0, 0),
        haloModel,
        visualColor,
        1,
        Enum.PartType.Ball
    )
    local motor = markVisual(Instance.new("Motor6D"))
    motor.Name = "FrozenHaloMotor"
    motor.Part0 = head
    motor.Part1 = core
    motor.C0 = CFrame.new(0, 1.58, 0) * CFrame.Angles(math.rad(-32), 0, 0)
    motor.Parent = head

    local segmentCount = 18
    local radius = 1.22
    local segmentLength = (math.pi * 2 * radius / segmentCount) * 1.12
    for index = 0, segmentCount - 1 do
        local angle = (index / segmentCount) * math.pi * 2
        local localPosition = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        local segment = makeNeonPart(
            "HaloSegment",
            Vector3.new(segmentLength, 0.09, 0.14),
            core.CFrame * CFrame.new(localPosition) * CFrame.Angles(0, -angle - math.pi * 0.5, 0),
            haloModel,
            index % 2 == 0 and visualColor:Lerp(SNOW_WHITE, 0.46) or visualColor,
            0.04
        )
        weldVisualPart(segment, core)

        if index % 3 == 0 then
            local diamond = makeNeonPart(
                "HaloIceDiamond",
                Vector3.new(0.16, 0.16, 0.16),
                core.CFrame * CFrame.new(localPosition * 1.08) * CFrame.Angles(math.rad(45), math.rad(45), 0),
                haloModel,
                Color3.fromRGB(247, 254, 255),
                0.05
            )
            weldVisualPart(diamond, core)
        end
    end

    local haloLight = markVisual(Instance.new("PointLight"))
    haloLight.Name = "HaloGlow"
    haloLight.Color = visualColor
    haloLight.Brightness = 1.65
    haloLight.Range = 9
    haloLight.Shadows = false
    haloLight.Parent = core

    local attachment = markVisual(Instance.new("Attachment"))
    attachment.Name = "HaloSnowAttachment"
    attachment.Parent = core
    local snow = markVisual(Instance.new("ParticleEmitter"))
    snow.Name = "HaloSnow"
    snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    snow.Color = ColorSequence.new(visualColor, SNOW_WHITE)
    snow.LightEmission = 1
    snow.Rate = 7
    snow.Lifetime = NumberRange.new(0.8, 1.5)
    snow.Speed = NumberRange.new(0.15, 0.55)
    snow.SpreadAngle = Vector2.new(180, 180)
    snow.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.17),
        NumberSequenceKeypoint.new(1, 0),
    })
    snow.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.04),
        NumberSequenceKeypoint.new(1, 1),
    })
    snow.Parent = attachment

    local animationStart = os.clock()
    trackVisualConnection(RunService.RenderStepped:Connect(function()
        if motor.Parent and haloModel.Parent then
            local elapsed = os.clock() - animationStart
            motor.C0 = CFrame.new(0, 1.58 + math.sin(elapsed * 1.7) * 0.055, 0)
                * CFrame.Angles(math.rad(-32), 0, 0)
                * CFrame.Angles(0, elapsed * 0.48, 0)
        end
    end))
end

local function createFrozenExpeditionOutfit(character)
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local head = character:FindFirstChild("Head")
    if not torso or not head then
        return
    end

    local model = markVisual(Instance.new("Model"))
    model.Name = "CodexFrozenExpeditionOutfit"
    model.Parent = character

    local function armorPart(name, basePart, size, localCFrame, color, transparency, shape)
        if not basePart then return nil end
        local part = makeNeonPart(name, size, basePart.CFrame * localCFrame, model, color, transparency, shape)
        part.Material = Enum.Material.Ice
        weldVisualPart(part, basePart)
        return part
    end

    local deepIce = Color3.fromRGB(21, 71, 111)
    local midIce = Color3.fromRGB(49, 137, 194)
    local glacier = visualColor:Lerp(SNOW_WHITE, 0.38)
    local crystal = Color3.fromRGB(218, 248, 255)

    -- A slim undersuit keeps the avatar silhouette instead of replacing it with
    -- one oversized rectangular coat.
    armorPart(
        "ArcticUndersuit",
        torso,
        torso.Size + Vector3.new(0.12, 0.10, 0.10),
        CFrame.new(0, -0.02, 0.02),
        deepIce,
        0.48
    )
    armorPart(
        "GlacierBreastplate",
        torso,
        Vector3.new(math.max(1.12, torso.Size.X * 0.62), math.max(1.12, torso.Size.Y * 0.60), 0.16),
        CFrame.new(0, 0.08, -(torso.Size.Z * 0.5 + 0.09)),
        midIce,
        0.12
    )
    armorPart(
        "LeftChestFacet",
        torso,
        Vector3.new(math.max(0.18, torso.Size.X * 0.13), math.max(0.82, torso.Size.Y * 0.45), 0.12),
        CFrame.new(-torso.Size.X * 0.34, 0.10, -(torso.Size.Z * 0.5 + 0.08)) * CFrame.Angles(0, 0, math.rad(-16)),
        glacier,
        0.18
    )
    armorPart(
        "RightChestFacet",
        torso,
        Vector3.new(math.max(0.18, torso.Size.X * 0.13), math.max(0.82, torso.Size.Y * 0.45), 0.12),
        CFrame.new(torso.Size.X * 0.34, 0.10, -(torso.Size.Z * 0.5 + 0.08)) * CFrame.Angles(0, 0, math.rad(16)),
        glacier,
        0.18
    )
    local chestCore = armorPart(
        "CodexIceCore",
        torso,
        Vector3.new(0.34, 0.34, 0.13),
        CFrame.new(0, 0.10, -(torso.Size.Z * 0.5 + 0.20)) * CFrame.Angles(0, 0, math.rad(45)),
        crystal,
        0.02
    )
    armorPart(
        "GlacierBelt",
        torso,
        Vector3.new(torso.Size.X + 0.18, 0.22, torso.Size.Z + 0.16),
        CFrame.new(0, -(torso.Size.Y * 0.5 - 0.13), 0.02),
        deepIce,
        0.18
    )

    for _, sideInfo in ipairs({{"Left", -1}, {"Right", 1}}) do
        local side = sideInfo[1]
        local sign = sideInfo[2]
        armorPart(
            side .. "GlacierPauldron",
            torso,
            Vector3.new(0.58, 0.28, 0.72),
            CFrame.new(sign * (torso.Size.X * 0.5 + 0.22), torso.Size.Y * 0.32, -0.01)
                * CFrame.Angles(0, 0, math.rad(sign * 18)),
            glacier,
            0.13
        )
        armorPart(
            side .. "ShoulderCrystal",
            torso,
            Vector3.new(0.16, 0.54, 0.22),
            CFrame.new(sign * (torso.Size.X * 0.5 + 0.48), torso.Size.Y * 0.42, -0.05)
                * CFrame.Angles(0, 0, math.rad(sign * 32)),
            crystal,
            0.08
        )

        local lowerArm = character:FindFirstChild(side .. "LowerArm") or character:FindFirstChild(side .. " Arm")
        if lowerArm then
            armorPart(
                side .. "FrostBracer",
                lowerArm,
                lowerArm.Size + Vector3.new(0.12, -math.min(0.10, lowerArm.Size.Y * 0.08), 0.14),
                CFrame.new(0, -lowerArm.Size.Y * 0.12, -0.02),
                midIce,
                0.20
            )
        end

        local upperLeg = character:FindFirstChild(side .. "UpperLeg")
        if upperLeg then
            armorPart(
                side .. "IceCuisses",
                upperLeg,
                Vector3.new(upperLeg.Size.X + 0.10, upperLeg.Size.Y * 0.72, upperLeg.Size.Z + 0.12),
                CFrame.new(0, -upperLeg.Size.Y * 0.08, -0.03),
                deepIce,
                0.28
            )
        end

        local lowerLeg = character:FindFirstChild(side .. "LowerLeg") or character:FindFirstChild(side .. " Leg")
        if lowerLeg then
            armorPart(
                side .. "GlacierBoot",
                lowerLeg,
                lowerLeg.Size + Vector3.new(0.16, 0.08, 0.22),
                CFrame.new(0, -lowerLeg.Size.Y * 0.16, -0.05),
                deepIce,
                0.22
            )
            armorPart(
                side .. "BootCrystal",
                lowerLeg,
                Vector3.new(math.max(0.18, lowerLeg.Size.X * 0.30), math.max(0.38, lowerLeg.Size.Y * 0.32), 0.13),
                CFrame.new(0, -lowerLeg.Size.Y * 0.25, -(lowerLeg.Size.Z * 0.5 + 0.08)),
                glacier,
                0.10
            )
        end
    end

    -- The old cylinder crossed the player's eyes. This thin circlet and its
    -- crystals sit above the face and keep the avatar readable.
    armorPart(
        "FrozenCirclet",
        head,
        Vector3.new(math.max(1.35, head.Size.X * 0.82), 0.12, 0.10),
        CFrame.new(0, head.Size.Y * 0.30, -(head.Size.Z * 0.5 + 0.04)),
        midIce,
        0.10
    )
    for crownIndex = -2, 2 do
        local crownHeight = crownIndex == 0 and 0.50 or (math.abs(crownIndex) == 1 and 0.38 or 0.27)
        armorPart(
            "CrownCrystal" .. tostring(crownIndex + 3),
            head,
            Vector3.new(0.12, crownHeight, 0.12),
            CFrame.new(crownIndex * 0.25, head.Size.Y * 0.5 + crownHeight * 0.32, -0.08)
                * CFrame.Angles(0, 0, math.rad(crownIndex * -7)),
            crownIndex == 0 and crystal or glacier,
            0.08
        )
    end

    if chestCore then
        local coreLight = markVisual(Instance.new("PointLight"))
        coreLight.Name = "SuitCoreGlow"
        coreLight.Color = visualColor
        coreLight.Brightness = 1.35
        coreLight.Range = 7
        coreLight.Shadows = false
        coreLight.Parent = chestCore
        local glowStart = os.clock()
        trackVisualConnection(RunService.RenderStepped:Connect(function()
            if coreLight.Parent then
                coreLight.Brightness = 1.20 + (math.sin((os.clock() - glowStart) * 2.4) + 1) * 0.22
            end
        end))
    end

    local highlight = markVisual(Instance.new("Highlight"))
    highlight.Name = "EverestIceBloom"
    highlight.Adornee = model
    highlight.FillColor = visualColor
    highlight.FillTransparency = 0.86
    highlight.OutlineColor = SNOW_WHITE
    highlight.OutlineTransparency = 0.20
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = model

    local attachment = markVisual(Instance.new("Attachment"))
    attachment.Name = "EverestSnowAttachment"
    attachment.Position = Vector3.new(0, torso.Size.Y * 0.5, 0)
    attachment.Parent = torso
    local snow = markVisual(Instance.new("ParticleEmitter"))
    snow.Name = "EverestSnow"
    snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    snow.Color = ColorSequence.new(SNOW_WHITE, visualColor)
    snow.LightEmission = 0.75
    snow.Rate = 14
    snow.Lifetime = NumberRange.new(0.8, 1.6)
    snow.Speed = NumberRange.new(0.8, 2.2)
    snow.Acceleration = Vector3.new(-1.2, -2.4, 0)
    snow.SpreadAngle = Vector2.new(160, 160)
    snow.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.16),
        NumberSequenceKeypoint.new(1, 0),
    })
    snow.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.10),
        NumberSequenceKeypoint.new(1, 1),
    })
    snow.Parent = attachment
end

local function clearCharacterVisuals(character)
    character = character or LocalPlayer.Character
    if not character then
        return
    end
    for index = #visualConnections, 1, -1 do
        local connection = visualConnections[index]
        pcall(function()
            connection:Disconnect()
        end)
        visualConnections[index] = nil
    end
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:GetAttribute("CodexReviveVisual") == true then
            descendant:Destroy()
        end
    end
end

local function getLocalNameplateRoot()
    local worldGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    worldGui = worldGui and worldGui:FindFirstChild("World")
    return worldGui and worldGui:FindFirstChild(LocalPlayer.Name)
end

local function applyCodexNameplate()
    local nameplateRoot = getLocalNameplateRoot()
    if not nameplateRoot then
        return false
    end
    local changed = false
    for _, descendant in ipairs(nameplateRoot:GetDescendants()) do
        if descendant:IsA("TextLabel") then
            local managed = descendant:GetAttribute("CodexNameplateManaged") == true
            local isPlayerName = descendant.Text == LocalPlayer.Name or descendant.Text == LocalPlayer.DisplayName
            if managed or isPlayerName then
                if not managed then
                    descendant:SetAttribute("CodexOriginalNameplateText", descendant.Text)
                    descendant:SetAttribute("CodexNameplateManaged", true)
                end
                if descendant.Text ~= "Codex" then
                    descendant.Text = "Codex"
                end
                changed = true
            end
        end
    end
    return changed
end

local function restoreCodexNameplate()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local worldGui = playerGui and playerGui:FindFirstChild("World")
    if not worldGui then
        return
    end
    for _, descendant in ipairs(worldGui:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant:GetAttribute("CodexNameplateManaged") == true then
            descendant.Text = tostring(descendant:GetAttribute("CodexOriginalNameplateText") or LocalPlayer.DisplayName)
            descendant:SetAttribute("CodexOriginalNameplateText", nil)
            descendant:SetAttribute("CodexNameplateManaged", nil)
        end
    end
end

local function applyCharacterVisuals()
    if visualState.nameplate then
        applyCodexNameplate()
    else
        restoreCodexNameplate()
    end
    local character = LocalPlayer.Character
    if not character then
        return
    end
    clearCharacterVisuals(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    if visualState.outline then
        local highlight = markVisual(Instance.new("Highlight"))
        highlight.Name = "CodexFrozenOutline"
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = visualColor
        highlight.FillTransparency = 0.78
        highlight.OutlineColor = Color3.fromRGB(242, 253, 255)
        highlight.OutlineTransparency = 0.08
        highlight.Parent = character
    end

    if visualState.aura then
        local attachment = markVisual(Instance.new("Attachment"))
        attachment.Name = "CodexIceAuraAttachment"
        attachment.Parent = root
        local emitter = markVisual(Instance.new("ParticleEmitter"))
        emitter.Name = "CodexIceAura"
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(visualColor, Color3.fromRGB(245, 253, 255))
        emitter.LightEmission = 0.75
        emitter.Rate = 22
        emitter.Lifetime = NumberRange.new(0.7, 1.4)
        emitter.Speed = NumberRange.new(1.5, 4)
        emitter.SpreadAngle = Vector2.new(180, 180)
        emitter.Rotation = NumberRange.new(0, 360)
        emitter.RotSpeed = NumberRange.new(-80, 80)
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.28),
            NumberSequenceKeypoint.new(0.55, 0.16),
            NumberSequenceKeypoint.new(1, 0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Parent = attachment
    end

    if visualState.trail then
        local attachment0 = markVisual(Instance.new("Attachment"))
        attachment0.Name = "CodexTrailTop"
        attachment0.Position = Vector3.new(0, 1.7, 0)
        attachment0.Parent = root
        local attachment1 = markVisual(Instance.new("Attachment"))
        attachment1.Name = "CodexTrailBottom"
        attachment1.Position = Vector3.new(0, -1.7, 0)
        attachment1.Parent = root
        local trail = markVisual(Instance.new("Trail"))
        trail.Name = "CodexFrozenTrail"
        trail.Attachment0 = attachment0
        trail.Attachment1 = attachment1
        trail.Color = ColorSequence.new(visualColor, Color3.fromRGB(245, 253, 255))
        trail.LightEmission = 0.8
        trail.Lifetime = 0.32
        trail.MinLength = 0.12
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.12),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Parent = root
    end

    if visualState.glow then
        local light = markVisual(Instance.new("PointLight"))
        light.Name = "CodexFrozenGlow"
        light.Color = visualColor
        light.Brightness = 1.35
        light.Range = 12
        light.Shadows = false
        light.Parent = root
    end

    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root
    local head = character:FindFirstChild("Head")
    if visualState.wings and torso then
        createFrozenAngelWings(character, torso)
    end
    if visualState.halo and head then
        createFrozenHalo(character, head)
    end
    if visualState.frozenOutfit then
        createFrozenExpeditionOutfit(character)
    end

    local activeVisuals = {}
    for key, enabled in pairs(visualState) do
        if enabled then
            table.insert(activeVisuals, key)
        end
    end
    table.sort(activeVisuals)
    visualStatusLabel.Text = #activeVisuals > 0
        and ("Visuals: " .. table.concat(activeVisuals, ", "))
        or "Visuals: All effects disabled"
    visualStatusLabel.TextColor3 = COLORS.success
end

VisualSection:AddDropdown({
    Name = "Visual Color",
    Options = {"Frozen White", "Glacier Blue", "Deep Ice", "Arctic Cyan"},
    Default = "Frozen White",
    Flag = "revive_visual_color",
    Callback = function(value)
        visualColor = VISUAL_COLORS[value] or VISUAL_COLORS["Frozen White"]
        applyCharacterVisuals()
    end,
})

for _, option in ipairs({
    {Name = "Ice Outline", Key = "outline", Description = "Frozen character highlight"},
    {Name = "Ice Aura", Key = "aura", Description = "Glowing snow particles around your body"},
    {Name = "Frozen Trail", Key = "trail", Description = "Leaves an icy trail while moving"},
    {Name = "Body Glow", Key = "glow", Description = "Soft colored light around your character"},
    {Name = "Frozen Angel Wings", Key = "wings", Description = "Layered glowing ice-feather wings with a gentle living motion"},
    {Name = "Frozen Halo", Key = "halo", Description = "Floating rotating ice halo with snow sparkle glow"},
    {Name = "Codex Nameplate", Key = "nameplate", Description = "Locally changes your overhead in-game name to Codex; your Roblox account name is untouched"},
}) do
    VisualSection:AddToggle({
        Name = option.Name,
        Description = option.Description,
        Flag = "revive_visual_" .. option.Key,
        Callback = function(enabled)
            visualState[option.Key] = enabled
            applyCharacterVisuals()
        end,
    })
end

VisualInfoSection:AddLabel("The wings and halo are asset-free local neon geometry, so they match every frozen color preset.")
VisualInfoSection:AddLabel("Codex Nameplate is local-only and restores your real display name when disabled.")

local catalogOutfitId = ""
local originalAvatarDescription = nil
local activeCatalogDescription = nil
local frozenOutfitControl

local function getCharacterHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildWhichIsA("Humanoid") or nil
end

local function applyLocalDescription(description, statusText)
    local humanoid = getCharacterHumanoid()
    if not humanoid or not description then
        outfitStatusLabel.Text = "Outfit: Waiting for your character"
        outfitStatusLabel.TextColor3 = COLORS.error
        return false
    end
    if not originalAvatarDescription then
        local captured, currentDescription = pcall(function()
            return humanoid:GetAppliedDescription()
        end)
        if captured then
            originalAvatarDescription = currentDescription
        end
    end
    local ok = pcall(function()
        humanoid:ApplyDescription(description:Clone())
    end)
    outfitStatusLabel.Text = ok and ("Outfit: " .. statusText) or "Outfit: Preview was blocked by this game"
    outfitStatusLabel.TextColor3 = ok and COLORS.success or COLORS.error
    if ok then
        task.delay(0.55, function()
            if gui.Parent then applyCharacterVisuals() end
        end)
    end
    return ok
end

OutfitSection:AddInput({
    Name = "Marketplace Outfit ID",
    Placeholder = "Enter a public Roblox outfit ID...",
    Default = "",
    Flag = "codex_tools_marketplace_outfit_id",
    Callback = function(value)
        catalogOutfitId = tostring(value or ""):match("%d+") or ""
    end,
})

OutfitSection:AddButton({
    Name = "Preview Outfit Locally",
    Description = "Loads a public Roblox avatar outfit for your screen only; it does not grant ownership",
    Persist = false,
    Callback = function()
        local outfitId = tonumber(catalogOutfitId)
        if not outfitId or outfitId <= 0 then
            Window:Notify("Outfit Tools", "Enter a valid public outfit ID first", 4)
            return
        end
        outfitStatusLabel.Text = "Outfit: Loading marketplace outfit " .. outfitId .. "..."
        outfitStatusLabel.TextColor3 = COLORS.muted
        task.spawn(function()
            local ok, description = pcall(function()
                return Players:GetHumanoidDescriptionFromOutfitId(outfitId)
            end)
            if not ok or not description then
                outfitStatusLabel.Text = "Outfit: ID could not be loaded"
                outfitStatusLabel.TextColor3 = COLORS.error
                return
            end
            activeCatalogDescription = description:Clone()
            if applyLocalDescription(activeCatalogDescription, "Local marketplace preview " .. outfitId) then
                Window:Notify("Outfit Tools", "Local preview applied; no item was purchased", 4)
            end
        end)
    end,
})

OutfitSection:AddButton({
    Name = "Restore My Roblox Avatar",
    Description = "Removes the local marketplace preview and restores your real avatar appearance",
    Persist = false,
    Callback = function()
        task.spawn(function()
            activeCatalogDescription = nil
            local description = originalAvatarDescription
            if not description then
                local ok, fetched = pcall(function()
                    return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
                end)
                description = ok and fetched or nil
            end
            if frozenOutfitControl then frozenOutfitControl:Set(false) end
            if applyLocalDescription(description, "Your Roblox avatar restored") then
                originalAvatarDescription = nil
            end
        end)
    end,
})

frozenOutfitControl = FrozenPresetSection:AddToggle({
    Name = "Frozen Codex Armor",
    Description = "Layered ice armor, chest core, circlet crown, bracers, boots, and snowfall",
    Flag = "codex_tools_frozen_everest_outfit",
    Callback = function(enabled)
        visualState.frozenOutfit = enabled
        if enabled then
            visualColor = VISUAL_COLORS["Glacier Blue"]
        end
        applyCharacterVisuals()
        outfitStatusLabel.Text = enabled and "Outfit: Frozen Codex armor equipped" or "Outfit: Frozen preset removed"
        outfitStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
    end,
})

FrozenPresetSection:AddButton({
    Name = "Equip Full Codex Armor",
    Description = "Enables the complete layered frozen armor preset in one click",
    Persist = false,
    Callback = function()
        frozenOutfitControl:Set(true)
        Window:Notify("Frozen Preset", "Codex frozen armor equipped locally", 4)
    end,
})

FrozenPresetSection:AddLabel("Marketplace previews and the frozen preset are cosmetic only; they do not add items to your Roblox inventory.")

track(LocalPlayer.PlayerGui.DescendantAdded:Connect(function(descendant)
    if visualState.nameplate and descendant:IsA("TextLabel") then
        task.defer(applyCodexNameplate)
    end
end))

-- Linked overnight controls mirror the real categorized controls. They are not
-- saved twice; the underlying controls keep the single persistent profile flag.
overnightMultiHitControl = OvernightSection:AddToggle({
    Name = "Multi Hit All Bosses",
    Description = "Fast confirmed round-robin combat while you remain anywhere",
    Persist = false,
    Callback = function(enabled)
        if multiHitControl and multiHitControl:Get() ~= enabled then
            multiHitControl:Set(enabled)
        end
    end,
})

overnightBossFarmControl = OvernightSection:AddToggle({
    Name = "Follow Latest Boss",
    Description = "Keeps your character positioned at the newest progression boss",
    Persist = false,
    Callback = function(enabled)
        if bossFarmControl and bossFarmControl:Get() ~= enabled then
            bossFarmControl:Set(enabled)
        end
    end,
})

overnightReaperControl = OvernightSection:AddToggle({
    Name = "Auto Reaper",
    Description = "Cooldown-aware companion Reaper automation without duplicate requests",
    Persist = false,
    Callback = function(enabled)
        if autoReaperControl and autoReaperControl:Get() ~= enabled then
            autoReaperControl:Set(enabled)
        end
    end,
})

overnightDeathKingControl = OvernightSection:AddToggle({
    Name = "Auto Death King",
    Description = "Continuously advances the Death King special boss",
    Persist = false,
    Callback = function(enabled)
        if deathKingControl and deathKingControl:Get() ~= enabled then
            deathKingControl:Set(enabled)
        end
    end,
})

overnightCursedKingControl = OvernightSection:AddToggle({
    Name = "Auto Cursed King",
    Description = "Continuously advances Cursed King levels, including before native auto-resume unlocks",
    Persist = false,
    Callback = function(enabled)
        if cursedKingControl and cursedKingControl:Get() ~= enabled then
            cursedKingControl:Set(enabled)
        end
    end,
})

overnightNightmareControl = OvernightSection:AddToggle({
    Name = "Auto Nightmare / Death Tower",
    Description = "AFK climbs each Death Tower section toward the next rebirth requirement",
    Persist = false,
    Callback = function(enabled)
        if nightmareControl and nightmareControl:Get() ~= enabled then
            nightmareControl:Set(enabled)
        end
    end,
})

overnightSpecialPriorityControl = OvernightSection:AddToggle({
    Name = "Special Boss Priority Loop",
    Description = "Runs the selected special wins, timed Multi Hit, and next tower section automatically",
    Persist = false,
    Callback = function(enabled)
        if specialPriorityControl and specialPriorityControl:Get() ~= enabled then
            specialPriorityControl:Set(enabled)
        end
    end,
})

overnightAutoEquipControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Equip Last Unlocked",
    Description = "Follows the newest sword in your live owned inventory",
    Persist = false,
    Callback = function(enabled)
        if autoEquipBestControl and autoEquipBestControl:Get() ~= enabled then
            autoEquipBestControl:Set(enabled)
        end
    end,
})

overnightAutoUpgradeControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Upgrade Equipped Sword",
    Description = "Continuously upgrades the sword currently being held",
    Persist = false,
    Callback = function(enabled)
        if autoUpgradeControl and autoUpgradeControl:Get() ~= enabled then
            autoUpgradeControl:Set(enabled)
        end
    end,
})

overnightAutoRebirthControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Rebirth",
    Description = "Rebirths as soon as the live Death Tower requirement is met",
    Persist = false,
    Callback = function(enabled)
        if autoRebirthControl and autoRebirthControl:Get() ~= enabled then
            autoRebirthControl:Set(enabled)
        end
    end,
})

overnightAutoSoulRingControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Upgrade Soul Ring",
    Description = "Uses the Soul Ring batch selected in Progress",
    Persist = false,
    Callback = function(enabled)
        if state.autoSoulRingControl and state.autoSoulRingControl:Get() ~= enabled then
            state.autoSoulRingControl:Set(enabled)
        end
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Enable Tower AFK",
    Description = "Enables only Anti-AFK and Auto Nightmare; every non-tower feature stays optional",
    Persist = false,
    Callback = function()
        if specialPriorityControl:Get() then
            specialPriorityControl:Set(false)
        end
        if cursedKingControl:Get() then
            cursedKingControl:Set(false)
        end
        if deathKingControl:Get() then
            deathKingControl:Set(false)
        end
        antiAfkControl:Set(true)
        nightmareControl:Set(true)
        setReviveStatus("Tower-only AFK enabled", true)
        Window:Notify("Tower AFK", "Anti-AFK and Auto Nightmare are running; other features remain optional", 4)
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Enable Multi-Hit AFK",
    Description = "Runs Anti-AFK plus standalone Multi Hit for the ground bosses",
    Persist = false,
    Callback = function()
        specialPriorityControl:Set(false)
        deathKingControl:Set(false)
        cursedKingControl:Set(false)
        nightmareControl:Set(false)
        antiAfkControl:Set(true)
        multiHitControl:Set(true)
        setReviveStatus("Standalone Multi-Hit AFK enabled", true)
        Window:Notify("Multi-Hit AFK", "Anti-AFK and all-boss Multi Hit are running", 4)
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Enable Priority AFK",
    Description = "Runs Anti-AFK plus the selected special boss and its built-in Multi Hit phase",
    Persist = false,
    Callback = function()
        antiAfkControl:Set(true)
        specialPriorityControl:Set(true)
        setReviveStatus("Special Priority AFK enabled for " .. priority.target, true)
        Window:Notify("Priority AFK", priority.target .. " will alternate with timed Multi Hit", 4)
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Stop Overnight Automation",
    Description = "Stops the linked overnight features without changing visual settings",
    Persist = false,
    Callback = function()
        antiAfkControl:Set(false)
        specialPriorityControl:Set(false)
        multiHitControl:Set(false)
        bossFarmControl:Set(false)
        autoReaperControl:Set(false)
        deathKingControl:Set(false)
        cursedKingControl:Set(false)
        nightmareControl:Set(false)
        autoEquipBestControl:Set(false)
        autoUpgradeControl:Set(false)
        state.autoSoulRingControl:Set(false)
        dailyRewardControl:Set(false)
        onlineRewardControl:Set(false)
        soulSpawnerControl:Set(false)
        starterRewardControl:Set(false)
        bossRewardControl:Set(false)
        setReviveStatus("Overnight automation stopped", nil)
    end,
})

OvernightUpgradeSection:AddLabel("Choose Tower AFK, standalone Multi-Hit AFK, or Priority AFK. Auto Rebirth remains optional.")

track(LocalPlayer.CharacterAdded:Connect(function()
    multiHitNeedsBootstrap = true
    nightmarePortalPrimedCharacter = nil
    task.wait(0.55)
    if activeCatalogDescription then
        local humanoid = getCharacterHumanoid()
        if humanoid then
            pcall(function()
                humanoid:ApplyDescription(activeCatalogDescription:Clone())
            end)
            task.wait(0.35)
        end
    end
    applyCharacterVisuals()
end))

local lastRun = {}
local function isDue(key, interval)
    local now = os.clock()
    if now - (lastRun[key] or 0) < interval then
        return false
    end
    lastRun[key] = now
    return true
end

task.spawn(function()
    while gui.Parent do
        if not state.specialPriority
            and (state.autoAttack or state.bossFarm)
            and not priority.isMultiHitActive()
            and (tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0) ~= 7
            and isDue("attack", 0.12)
        then
            fireRemote("attack", getLatestUnlockedBossLevel())
        end
        if state.demonRealm and isDue("demonRealmPoll", 0.10) then
            state.demonRealmInfo = state.refreshDemonRealmStatus()
            if state.demonRealmInfo.InRealm then
                if isDue("demonRealmAttack", 0.08) then
                    fireRemote("attack", nil)
                end
            elseif state.demonRealmInfo.Open and isDue("demonRealmEnter", 1.25) then
                if fireRemote("enterTimeLimitBossReq") then
                    state.demonRealmStatusLabel.Text = "Demon Realm: Entry requested | Waiting for server confirmation"
                    state.demonRealmStatusLabel.TextColor3 = COLORS.success
                end
            end
        elseif isDue("demonRealmStatusRefresh", 1) then
            state.refreshDemonRealmStatus()
        end
        if state.reaper and isDue("reaperPoll", 0.25) then
            local reaperInfo = refreshReaperStatus()
            local serverNow = workspace:GetServerTimeNow()
            if reaperInfo.Unlocked
                and reaperInfo.MaxHP > 1
                and reaperInfo.Remaining <= 0
                and serverNow >= reaperLocalCooldownUntil
                and isDue("reaperSend", 1)
            then
                if fireRemote("staticReaperReq") then
                    -- The battle atom can update a moment after the response. This local
                    -- gate prevents duplicate requests and the game's false locked toast.
                    reaperLocalCooldownUntil = serverNow + reaperInterval
                    reaperStatusLabel.Text = "Reaper: Request sent | Waiting for confirmation"
                    reaperStatusLabel.TextColor3 = COLORS.muted
                end
            end
        end
        if state.specialPriority then
            -- Priority owns combat while enabled. Persisted or newly-clicked
            -- conflicting controls are silently returned to off instead of
            -- being allowed to cancel the requested priority loop.
            if state.autoAttack then state.autoAttack = false; attackControl:Set(false, true) end
            if state.deathKing then state.deathKing = false; deathKingControl:Set(false, true) end
            if state.cursedKing then state.cursedKing = false; cursedKingControl:Set(false, true) end
            if state.nightmare then state.nightmare = false; nightmareControl:Set(false, true) end
            if state.challengeOne then state.challengeOne = false; challengeOneControl:Set(false, true) end
            if state.challengeFive then state.challengeFive = false; challengeFiveControl:Set(false, true) end
            if state.bossFarm then
                state.bossFarm = false
                bossFarmControl:Set(false, true)
                if overnightBossFarmControl then overnightBossFarmControl:Set(false, true) end
                stopEnemyTween()
            end
            local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
            local progressChanged = priority.observeProgress()
            if progressChanged then
                -- Let the multi-hit worker observe the new phase before doing more special work.
            elseif priority.phase == "quit" then
                local exitTimedOut = os.clock() >= priority.quitDeadline
                if battleState == 0 or exitTimedOut then
                    priority.phase = "multi"
                    priority.multiEndAt = os.clock() + priority.multiSeconds
                    state.priorityMulti = true
                    multiHitNeedsBootstrap = true
                    priorityStatusLabel.Text = (exitTimedOut and "Special Priority: Exit timeout | " or "Special Priority: Arena exited | ")
                        .. "Multi Hit for " .. priority.multiSeconds .. "s"
                    priorityStatusLabel.TextColor3 = COLORS.success
                elseif isDue("priorityQuitRetry", 0.35) then
                    fireRemote("levelTimeLimitBossReq")
                    priorityStatusLabel.Text = "Special Priority: Quitting Tower before bridge Multi Hit"
                    priorityStatusLabel.TextColor3 = COLORS.muted
                end
            elseif priority.phase == "multi" then
                local remaining = math.max(0, priority.multiEndAt - os.clock())
                state.priorityMulti = remaining > 0
                priorityStatusLabel.Text = string.format("Special Priority: Multi Hit %.1fs remaining", remaining)
                priorityStatusLabel.TextColor3 = COLORS.success
                if remaining <= 0 then
                    state.priorityMulti = false
                    priority.phase = "special"
                    priority.nextStartAt = os.clock() + 0.5
                    priorityStatusLabel.Text = "Special Priority: Returning to " .. priority.target
                end
            elseif priority.activeMode then
                local activeInfo = getSpecialBossState(priority.activeMode)
                if activeInfo.Level > priority.activeLevelBefore then
                    -- Death Tower and Cursed King can replace a defeated boss with the
                    -- next section without ever returning AtomBattleState to zero.
                    priority.complete(true)
                elseif specialResultSerial > priority.seenResultSerial then
                    priority.seenResultSerial = specialResultSerial
                    priority.complete(specialResultSuccess)
                elseif battleState == priority.activeMode then
                    if isDue("prioritySpecialAttack", 0.10) then
                        fireRemote("attack", nil)
                    end
                elseif battleState == 0 and os.clock() >= priority.nextStartAt then
                    priority.complete(false)
                end
            elseif battleState == RED_DRAGON_MODE or battleState == GREEN_DRAGON_MODE or battleState == NIGHTMARE_MODE then
                local matchesTarget = priority.target == "Cycle All"
                    or (priority.target == "Nightmare" and battleState == NIGHTMARE_MODE)
                    or (priority.target == "Cursed King" and battleState == GREEN_DRAGON_MODE)
                    or (priority.target == "Death King" and battleState == RED_DRAGON_MODE)
                if matchesTarget then
                    local activeInfo = getSpecialBossState(battleState)
                    priority.activeMode = battleState
                    priority.activeLevelBefore = activeInfo.Level
                    priority.seenResultSerial = specialResultSerial
                    priority.nextStartAt = os.clock() + 2.5
                    priorityStatusLabel.Text = "Special Priority: Resumed " .. priority.modeName(battleState) .. " section"
                    priorityStatusLabel.TextColor3 = COLORS.success
                elseif isDue("priorityWrongSpecial", 1) then
                    priorityStatusLabel.Text = "Special Priority: Waiting for the selected special battle"
                    priorityStatusLabel.TextColor3 = COLORS.muted
                end
            elseif battleState == 0 and os.clock() >= priority.nextStartAt then
                if not priority.start() and isDue("priorityWaiting", 2) then
                    local required = priority.target == "Cursed King" and greenDragonUnlockLevel
                        or (priority.target == "Death King" and redDragonUnlockLevel or nightmareUnlockLevel)
                    priorityStatusLabel.Text = "Special Priority: Waiting for Main Level " .. required
                    priorityStatusLabel.TextColor3 = COLORS.muted
                end
            elseif isDue("priorityBattleWait", 1) then
                priorityStatusLabel.Text = "Special Priority: Waiting for current battle to finish"
                priorityStatusLabel.TextColor3 = COLORS.muted
            end
        elseif state.deathKing and isDue("deathKingPoll", 0.25) then
            local deathInfo = refreshDeathKingStatus()
            local serverNow = workspace:GetServerTimeNow()
            if deathInfo.BattleState == RED_DRAGON_MODE and isDue("deathKingAttack", 0.10) then
                fireRemote("attack", nil)
            elseif deathInfo.Unlocked
                and deathInfo.BattleState == 0
                and serverNow - specialLastStart[RED_DRAGON_MODE] >= (deathInfo.NativeAutoAvailable and 5 or 2)
            then
                armDeathKingAuto()
            end
        elseif state.cursedKing and isDue("cursedKingPoll", 0.25) then
            local cursedInfo = refreshCursedKingStatus()
            local serverNow = workspace:GetServerTimeNow()
            if cursedInfo.BattleState == GREEN_DRAGON_MODE and isDue("cursedKingAttack", 0.10) then
                fireRemote("attack", nil)
            elseif cursedInfo.Unlocked
                and cursedInfo.BattleState == 0
                and serverNow - specialLastStart[GREEN_DRAGON_MODE] >= (cursedInfo.NativeAutoAvailable and 5 or 2)
            then
                armCursedKingAuto()
            end
        elseif state.nightmare and isDue("nightmarePoll", 0.25) then
            local nightmareInfo = refreshNightmareStatus()
            local serverNow = workspace:GetServerTimeNow()
            if nightmareInfo.BattleState == NIGHTMARE_MODE and isDue("nightmareAttack", 0.10) then
                fireRemote("attack", nil)
            elseif nightmareInfo.Unlocked
                and nightmareInfo.BattleState == 0
                and serverNow - specialLastStart[NIGHTMARE_MODE] >= (nightmareInfo.NativeAutoAvailable and 5 or 2)
            then
                armNightmareAuto()
            end
        end
        if state.autoRebirth and isDue("hubAutoRebirth", 0.75) then
            local currentRebirth = tonumber(readAtomValue(rebirthStore, "AtomRebirth")) or 0
            local towerLevel = tonumber(readAtomValue(reaperBattleStore, "AtomTowerLevel")) or 0
            local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
            local requiredTower = rebirthTowerLevelRatio * (currentRebirth + 1)
            rebirthStatusLabel.Text = string.format(
                "Auto Rebirth: Rebirth %d | Tower %d / %d",
                currentRebirth,
                towerLevel,
                requiredTower
            )
            rebirthStatusLabel.TextColor3 = towerLevel >= requiredTower and COLORS.success or COLORS.muted
            if towerLevel >= requiredTower and battleState == 0 and isDue("hubAutoRebirthSend", 2) then
                if fireRemote("rebirth") then
                    rebirthStatusLabel.Text = "Auto Rebirth: Requirement met | Request sent"
                    setReviveStatus("Rebirth request sent at Death Tower " .. towerLevel, true)
                end
            end
        end
        if state.autoSoulRing and isDue("autoSoulRingUpgrade", 0.75) then
            local ringInfo = state.refreshSoulRingStatus()
            if ringInfo.Available and ringInfo.SoulStones > 0 then
                fireRemote("enhanceSoulRing", 0, 0, state.soulRingUpgradeBatch)
            end
        elseif isDue("soulRingStatusRefresh", 2) then
            state.refreshSoulRingStatus()
        end
        if visualState.nameplate and isDue("codexNameplate", 0.25) then
            applyCodexNameplate()
        end
        if state.discordReminder and isDue("discordReminder", 1) then
            local remaining = math.max(0, math.ceil(nextDiscordReminderAt - os.clock()))
            if remaining <= 0 then
                showDiscordReminder()
            else
                discordReminderStatusLabel.Text = string.format(
                    "Discord Reminder: Enabled | Next in %02d:%02d",
                    math.floor(remaining / 60),
                    remaining % 60
                )
                discordReminderStatusLabel.TextColor3 = COLORS.success
            end
        end
        if state.groupReward and isDue("group", 30) then
            fireRemote("getGroupReward")
        end
        if state.challengeOne and isDue("challenge", 0.75) then
            fireRemote("startTimeLimitChallengeReq", 1, 0)
        elseif state.challengeFive and isDue("challenge", 0.75) then
            fireRemote("startTimeLimitChallengeReq", 1, 1)
        end
        if state.autoEquipBest and isDue("equipBest", 0.80) then
            equipLastUnlockedWeapon()
        end
        if state.autoUpgrade and isDue("upgrade", 0.35) then
            local equippedId = getEquippedWeaponId()
            local info = equippedId and getWeaponInfo(equippedId) or nil
            if equippedId and (not info or info.canEnhance ~= false) then
                fireRemote("enhanceWeapon", equippedId)
            elseif equippedId and isDue("upgradeSkippedStatus", 2) then
                refreshWeaponStatus("not enhanceable")
            end
        end
        if state.dailyReward and isDue("daily", 30) then
            fireRemote("getSignReward")
        end
        if state.onlineReward and isDue("online", 5) then
            fireRemote("receiveOnlineTimeReward")
        end
        if state.soulSpawner and isDue("soul", 3) then
            fireRemote("claimSoulSpawner")
        end
        if state.starterRewards and isDue("starter", 10) then
            for index = 1, 5 do
                fireRemote("claimChallengeReward", index)
            end
        end
        if state.bossRewards and isDue("boss", 10) then
            for index = 1, 6 do
                fireRemote("claimTimeLimitBossReward", index)
            end
        end
        task.wait(0.05)
    end
end)

local function waitForBossConfirmation(level, startingSerial, duration)
    local deadline = os.clock() + duration
    repeat
        if (confirmedAttackSerial[level] or 0) > startingSerial then
            return true
        end
        task.wait(0.01)
    until not priority.isMultiHitActive() or not gui.Parent or os.clock() >= deadline
    return (confirmedAttackSerial[level] or 0) > startingSerial
end

local function bootstrapMultiHitSession()
    if not multiHitNeedsBootstrap then
        return true
    end

    local bootstrapLevel = 1
    local startingSerial = confirmedAttackSerial[bootstrapLevel] or 0
    multiHitStatusLabel.Text = "Multi Hit: Priming the bridge session automatically..."
    multiHitStatusLabel.TextColor3 = COLORS.muted

    for _ = 1, 3 do
        fireRemote("attack", bootstrapLevel)
        if waitForBossConfirmation(bootstrapLevel, startingSerial, 0.12) then
            multiHitNeedsBootstrap = false
            multiHitStatusLabel.Text = "Multi Hit: Remote session primed"
            multiHitStatusLabel.TextColor3 = COLORS.success
            return true
        end
    end

    local enemyPart = findEnemyPart(bootstrapLevel)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not enemyPart or not root then
        multiHitStatusLabel.Text = "Multi Hit: Waiting for Enemy 1 to load"
        multiHitStatusLabel.TextColor3 = COLORS.muted
        return false
    end

    local originalCFrame = root.CFrame
    local moved = pcall(function()
        local flatForward = Vector3.new(enemyPart.CFrame.LookVector.X, 0, enemyPart.CFrame.LookVector.Z)
        if flatForward.Magnitude < 0.05 then
            flatForward = Vector3.new(0, 0, -1)
        else
            flatForward = flatForward.Unit
        end
        local targetPosition = enemyPart.Position + flatForward * 5 + Vector3.new(0, 0.5, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.lookAt(targetPosition, enemyPart.Position)
    end)

    local confirmed = false
    if moved then
        task.wait(0.10)
        for _ = 1, 5 do
            fireRemote("attack", bootstrapLevel)
            if waitForBossConfirmation(bootstrapLevel, startingSerial, 0.12) then
                confirmed = true
                break
            end
        end
        pcall(function()
            root.CFrame = originalCFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    multiHitNeedsBootstrap = not confirmed
    multiHitStatusLabel.Text = confirmed
        and "Multi Hit: Bridge session primed; attacking from anywhere"
        or "Multi Hit: Bridge activation retry queued"
    multiHitStatusLabel.TextColor3 = confirmed and COLORS.success or COLORS.error
    return confirmed
end

task.spawn(function()
    local currentBoss = 1
    while gui.Parent do
        if (tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0) == 7 then
            currentBoss = 1
            multiHitStatusLabel.Text = "Multi Hit: Paused while Demon Realm is active"
            multiHitStatusLabel.TextColor3 = COLORS.muted
            task.wait(0.20)
            continue
        end
        if priority.isMultiHitActive() then
            if multiHitNeedsBootstrap and not bootstrapMultiHitSession() then
                task.wait(0.25)
                continue
            end
            local maxBoss = multiHitTargetMode == "Unlocked Bosses Only"
                and getLatestUnlockedBossLevel()
                or 15
            if currentBoss > maxBoss then
                currentBoss = 1
            end

            local startingSerial = confirmedAttackSerial[currentBoss] or 0
            local confirmationDeadline = os.clock() + 0.45
            local confirmed = false
            local multiPrefix = state.priorityMulti and "Priority Multi" or "Multi Hit"
            multiHitStatusLabel.Text = multiPrefix .. ": Boss " .. currentBoss .. " / " .. maxBoss .. " - waiting for server"
            multiHitStatusLabel.TextColor3 = COLORS.muted

            repeat
                fireRemote("attack", currentBoss)
                local retryDeadline = math.min(confirmationDeadline, os.clock() + multiHitDelay)
                repeat
                    task.wait(0.01)
                    confirmed = (confirmedAttackSerial[currentBoss] or 0) > startingSerial
                until confirmed or not priority.isMultiHitActive() or not gui.Parent or os.clock() >= retryDeadline
            until confirmed or not priority.isMultiHitActive() or not gui.Parent or os.clock() >= confirmationDeadline

            if not priority.isMultiHitActive() or not gui.Parent then
                currentBoss = 1
                multiHitStatusLabel.Text = state.specialPriority and "Multi Hit: Waiting for special-boss phase" or "Multi Hit: Disabled"
                multiHitStatusLabel.TextColor3 = COLORS.muted
                continue
            end

            if confirmed then
                multiHitStatusLabel.Text = multiPrefix .. ": Boss " .. currentBoss .. " confirmed - advancing"
                multiHitStatusLabel.TextColor3 = COLORS.success
            else
                multiHitStatusLabel.Text = multiPrefix .. ": Boss " .. currentBoss .. " did not confirm - skipped"
                multiHitStatusLabel.TextColor3 = COLORS.error
            end

            currentBoss += 1
            if currentBoss > maxBoss then
                currentBoss = 1
                if priority.isMultiHitActive() then
                    setReviveStatus("Multi Hit completed a confirmed boss round", true)
                end
            end
            task.wait(0.01)
        else
            currentBoss = 1
            if state.specialPriority then
                multiHitStatusLabel.Text = "Multi Hit: Waiting for special-boss phase"
                multiHitStatusLabel.TextColor3 = COLORS.muted
            end
            task.wait(0.05)
        end
    end
end)

task.spawn(function()
    while gui.Parent do
        if not state.autoTween and not state.bossFarm then
            task.wait(0.10)
            continue
        end

        local targetEnemy = state.bossFarm and getLatestUnlockedBossLevel() or selectedEnemy
        local enemyPart = findEnemyPart(targetEnemy)
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
        if not enemyPart or not root then
            stopEnemyTween()
            tweenStatusLabel.Text = not enemyPart and ("Tween: Waiting for Enemy " .. targetEnemy) or "Tween: Waiting for respawn"
            tweenStatusLabel.TextColor3 = COLORS.error
            if state.bossFarm then
                farmStatusLabel.Text = "Farm: Waiting for Level " .. targetEnemy .. " - " .. getBossName(targetEnemy)
                farmStatusLabel.TextColor3 = COLORS.error
            end
            task.wait(0.25)
            continue
        end

        if controlledHumanoid ~= humanoid then
            stopEnemyTween()
            controlledHumanoid = humanoid
            if humanoid then
                originalAutoRotate = humanoid.AutoRotate
                humanoid.AutoRotate = false
            end
        end

        local flatForward = lockedEnemyFacing[enemyPart]
        if not flatForward then
            flatForward = Vector3.new(enemyPart.CFrame.LookVector.X, 0, enemyPart.CFrame.LookVector.Z)
            flatForward = flatForward.Magnitude > 0.001 and flatForward.Unit or Vector3.new(0, 0, 1)
            lockedEnemyFacing[enemyPart] = flatForward
        end
        local stableEnemyCFrame = CFrame.lookAt(enemyPart.Position, enemyPart.Position + flatForward)
        local horizontalTarget = (stableEnemyCFrame * CFrame.new(tweenOffsetX, 0, tweenOffsetZ)).Position

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {character, workspace:FindFirstChild("Enemies")}
        raycastParams.IgnoreWater = true
        local ground = workspace:Raycast(horizontalTarget + Vector3.new(0, 35, 0), Vector3.new(0, -100, 0), raycastParams)
        local standingY = enemyPart.Position.Y
        if ground and humanoid then
            standingY = ground.Position.Y + humanoid.HipHeight + (root.Size.Y * 0.5)
        end
        local targetPosition = Vector3.new(horizontalTarget.X, standingY + tweenOffsetY, horizontalTarget.Z)
        local lookAt = Vector3.new(enemyPart.Position.X, targetPosition.Y, enemyPart.Position.Z)
        local goal = (lookAt - targetPosition).Magnitude > 0.05
            and CFrame.lookAt(targetPosition, lookAt, Vector3.yAxis)
            or CFrame.new(targetPosition)
        local distance = (targetPosition - root.Position).Magnitude
        local duration = math.clamp(distance / math.max(tweenSpeed, 1), 0.05, 1.25)

        if activeEnemyTween then
            activeEnemyTween:Cancel()
        end
        if distance <= 0.12 then
            root.CFrame = goal
            root.AssemblyAngularVelocity = Vector3.zero
            root.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.05)
        else
            activeEnemyTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = goal})
            activeEnemyTween:Play()
        end
        tweenStatusLabel.Text = "Tween: Enemy " .. targetEnemy .. " | Front stance | " .. math.floor(distance + 0.5) .. " studs"
        tweenStatusLabel.TextColor3 = COLORS.success
        if state.bossFarm then
            farmStatusLabel.Text = "Farm: Level " .. targetEnemy .. " - " .. getBossName(targetEnemy)
            farmStatusLabel.TextColor3 = COLORS.success
        end
        if activeEnemyTween then
            activeEnemyTween.Completed:Wait()
            if root.Parent and (state.autoTween or state.bossFarm) then
                root.CFrame = goal
                root.AssemblyAngularVelocity = Vector3.zero
            end
            activeEnemyTween = nil
        end
    end
end)

track(gui.Destroying:Connect(function()
    local hadSpecialAutomation = state.cursedKing or state.nightmare or state.specialPriority
    state.autoTween = false
    state.bossFarm = false
    state.multiHit = false
    state.priorityMulti = false
    state.cursedKing = false
    state.nightmare = false
    state.specialPriority = false
    stopEnemyTween()
    clearCharacterVisuals()
    restoreCodexNameplate()
    if state.autoRebirth and remotes.SetAutoRebirth then
        pcall(function()
            remotes.SetAutoRebirth:FireServer(false, autoRebirthFloor)
        end)
    end
    if hadSpecialAutomation and remotes.setAfkResumeReq then
        pcall(function()
            remotes.setAfkResumeReq:FireServer(0, 0)
        end)
    end
end))

end
buildReviveFeatures()

-- Generic Settings page. Keep this below your feature controls so Auto Load can restore them.
local SettingsPage = Window:AddPage("Settings")
local ProfilesSection = SettingsPage:AddSection("Saved Profiles", "Left")
local AutoLoadSection = SettingsPage:AddSection("Auto Load", "Right")
local AppearanceSection = SettingsPage:AddSection("Frozen Appearance", "Right")

local frozenPresets = {
    ["Snowstorm White"] = Color3.fromRGB(218, 242, 252),
    ["Winter Steel"] = Color3.fromRGB(177, 219, 239),
    ["Glacier Blue"] = Color3.fromRGB(105, 218, 255),
    ["Arctic Cyan"] = Color3.fromRGB(88, 255, 248),
    ["Frost White"] = Color3.fromRGB(210, 245, 255),
    ["Deep Freeze"] = Color3.fromRGB(65, 149, 255),
    ["Frozen Mint"] = Color3.fromRGB(121, 255, 218),
    ["Steel Ice"] = Color3.fromRGB(162, 201, 230),
}

local frozenAccentControl = AppearanceSection:AddDropdown({
    Name = "Ice Accent Color",
    Flag = "frozen_accent_preset",
    Options = {"Snowstorm White", "Winter Steel", "Glacier Blue", "Arctic Cyan", "Frost White", "Deep Freeze", "Frozen Mint", "Steel Ice"},
    Default = "Snowstorm White",
    Callback = function(value)
        local color = frozenPresets[value]
        if color then
            applyFrozenAccent(color)
        end
    end,
})

local transparencyControl = AppearanceSection:AddSlider({
    Name = "Hub Transparency",
    Flag = "hub_transparency",
    Min = 0.10,
    Max = 0.80,
    Default = hubTransparencyValue,
    Step = 0.05,
    Callback = function(value)
        applyHubTransparency(value)
    end,
})

AppearanceSection:AddButton({
    Name = "Reset Frozen Theme",
    Description = "Restore transparent white glass and the snowstorm accent",
    Persist = false,
    Callback = function()
        frozenAccentControl:Set("Snowstorm White")
        transparencyControl:Set(0.46)
    end,
})

local profileNameControl = ProfilesSection:AddInput({
    Name = "Profile Name",
    Placeholder = "Example: Main Setup",
    Persist = false,
})

local savedProfileControl = nil
savedProfileControl = ProfilesSection:AddDropdown({
    Name = "Saved Profiles",
    Placeholder = "Select a profile...",
    Options = {},
    Persist = false,
    Callback = function(value)
        if value then
            profileNameControl:Set(value)
        end
    end,
})

local settingsStatus = AutoLoadSection:AddLabel("Checking profile storage...")
local function setSettingsStatus(message, success)
    settingsStatus.Text = tostring(message)
    settingsStatus.TextColor3 = success == false and COLORS.error or (success == true and COLORS.success or COLORS.muted)
end

local function getChosenProfile()
    local typed = sanitizeProfileName(profileNameControl:Get())
    if typed ~= "" then
        return typed
    end
    return sanitizeProfileName(savedProfileControl:Get())
end

local function refreshProfiles(preferred)
    local profiles = Window:GetProfileNames()
    savedProfileControl:SetOptions(profiles, false)

    local target = sanitizeProfileName(preferred or getChosenProfile())
    if target ~= "" then
        for _, profile in ipairs(profiles) do
            if profile == target then
                savedProfileControl:Set(profile, true)
                profileNameControl:Set(profile)
                break
            end
        end
    end
    return profiles
end

ProfilesSection:AddButton({
    Name = "Save / Overwrite",
    Description = "Save every persistent control in this game",
    Callback = function()
        local ok, message, profile = Window:SaveProfile(getChosenProfile())
        setSettingsStatus(message, ok)
        if ok then
            profileNameControl:Set(profile)
            refreshProfiles(profile)
            Window:Notify("Settings", message, 2.5)
        end
    end,
})

ProfilesSection:AddButton({
    Name = "Load Profile",
    Description = "Apply the selected values and their callbacks",
    Callback = function()
        local ok, message, profile = Window:LoadProfile(getChosenProfile())
        setSettingsStatus(message, ok)
        if ok then
            profileNameControl:Set(profile)
            savedProfileControl:Set(profile, true)
            Window:Notify("Settings", message, 2.5)
        end
    end,
})

local pendingDeleteProfile = nil
local pendingDeleteUntil = 0
ProfilesSection:AddButton({
    Name = "Delete Profile",
    Description = "Requires a second click for confirmation",
    Callback = function()
        local profile = getChosenProfile()
        if profile == "" then
            setSettingsStatus("Choose a profile to delete", false)
            return
        end

        if pendingDeleteProfile ~= profile or os.clock() > pendingDeleteUntil then
            pendingDeleteProfile = profile
            pendingDeleteUntil = os.clock() + 4
            setSettingsStatus("Click Delete Profile again to confirm: " .. profile, false)
            return
        end

        local ok, message = Window:DeleteProfile(profile)
        pendingDeleteProfile = nil
        pendingDeleteUntil = 0
        setSettingsStatus(message, ok)
        if ok then
            profileNameControl:Set("")
            refreshProfiles()
            Window:Notify("Settings", message, 2.5)
        end
    end,
})

ProfilesSection:AddButton({
    Name = "Refresh Profile List",
    Callback = function()
        local profiles = refreshProfiles()
        setSettingsStatus("Found " .. tostring(#profiles) .. " saved profile(s)", true)
    end,
})

AutoLoadSection:AddLabel("Storage is isolated to PlaceId " .. tostring(game.PlaceId))
AutoLoadSection:AddLabel("Only toggles, dropdowns, sliders, and inputs are saved.")

local autoLoadControl = nil
autoLoadControl = AutoLoadSection:AddToggle({
    Name = "Auto Load Selected Profile",
    Description = "Loads this profile when the hub starts in this game",
    Default = false,
    Persist = false,
    Callback = function(enabled)
        local ok, message = Window:SetAutoLoad(enabled, getChosenProfile())
        if not ok then
            autoLoadControl:Set(false, true)
        end
        setSettingsStatus(message, ok)
        if ok then
            Window:Notify("Settings", message, 2.5)
        end
    end,
})

if Window:ProfilesAvailable() then
    refreshProfiles()
    local autoLoadEnabled, autoLoadProfile = Window:GetAutoLoad()
    if autoLoadEnabled and autoLoadProfile ~= "" then
        profileNameControl:Set(autoLoadProfile)
        savedProfileControl:Set(autoLoadProfile, true)
        autoLoadControl:Set(true, true)
        local ok, message = Window:LoadProfile(autoLoadProfile)
        setSettingsStatus(message, ok)
    else
        setSettingsStatus("Enter a profile name to Save / Overwrite or Load", nil)
    end
else
    setSettingsStatus("Profile saving is unavailable: executor file API not found", false)
end

Window:SelectPage("Home")
Window:PlayIntro()

-- Optional global reference for adding controls later from the same environment.
_G.CodexHubTemplate = Window
