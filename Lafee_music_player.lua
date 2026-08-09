local ADDON_NAME = ...

local LMP = CreateFrame("Frame")
local DB

local DEFAULTS = {
    mode = "normal",
    enabled = true,
    volumeChannel = "Master",
    windowShown = true,
    windowPoint = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 120 },
    minimapAngle = 225,
}

local BLOODLUST_SPELLS = {
    [2825] = true,   -- Bloodlust
    [32182] = true,  -- Heroism
    [80353] = true,  -- Time Warp
    [90355] = true,  -- Ancient Hysteria
    [160452] = true, -- Netherwinds
    [178207] = true, -- Drums of Fury
    [230935] = true, -- Drums of the Mountain
    [256740] = true, -- Primal Rage
    [264667] = true, -- Primal Rage
    [309658] = true, -- Drums of Deathly Ferocity
    [321711] = true, -- Drums of the Wild
    [381301] = true, -- Feral Hide Drums
    [390386] = true, -- Fury of the Aspects
}

local currentIndex = 0
local currentPath
local currentHandle
local blHandle
local paused = false
local wasPlayingBeforeBL = false
local blAuraActive = false
local lastBLAt = 0
local mainFrame
local titleText
local statusText
local playPauseButton
local modeButton
local minimapButton

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb88cffLafee Music Player|r: " .. message)
end

local function CopyDefaults()
    LafeeMusicPlayerDB = LafeeMusicPlayerDB or {}
    for key, value in pairs(DEFAULTS) do
        if LafeeMusicPlayerDB[key] == nil then
            if type(value) == "table" then
                LafeeMusicPlayerDB[key] = {}
                for nestedKey, nestedValue in pairs(value) do
                    LafeeMusicPlayerDB[key][nestedKey] = nestedValue
                end
            else
                LafeeMusicPlayerDB[key] = value
            end
        end
    end
    DB = LafeeMusicPlayerDB
end

local function Tracks()
    return LafeeMusicPlayerTracks or {}
end

local function TrackName(path)
    return path and path:match("([^\\]+)$") or "Aucune piste"
end

local function GetMasterVolume()
    return tonumber(GetCVar("Sound_MasterVolume")) or 1
end

local function SetMasterVolume(value)
    SetCVar("Sound_MasterVolume", tostring(value))
end

local function UpdateMinimapButtonPosition()
    if not minimapButton or not DB then
        return
    end

    local angle = math.rad(DB.minimapAngle or 225)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function UpdateUI()
    if titleText then
        titleText:SetText(TrackName(currentPath))
    end

    if statusText then
        local mode = DB and DB.mode == "random" and "Aleatoire" or "Normal"
        local state = "Stop"
        if blHandle then
            state = "BL"
        elseif currentHandle then
            state = "Lecture"
        elseif paused then
            state = "Pause"
        end
        statusText:SetText(state .. " - " .. mode)
    end

    if playPauseButton then
        playPauseButton:SetText(currentHandle and "Pause" or "Play")
    end

    if modeButton then
        modeButton:SetText(DB and DB.mode == "random" and "Random" or "Normal")
    end
end

local function SaveWindowPosition()
    if not mainFrame or not DB then
        return
    end

    local point, _, relativePoint, x, y = mainFrame:GetPoint(1)
    DB.windowPoint = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 120,
    }
end

local function StopCurrent(keepPaused)
    if currentHandle then
        StopSound(currentHandle)
        currentHandle = nil
    end

    paused = keepPaused and currentPath ~= nil
    UpdateUI()
end

local function StopBL()
    if blHandle then
        StopSound(blHandle)
        blHandle = nil
    end
end

local function PickNextIndex()
    local count = #Tracks()
    if count == 0 then
        return 0
    end

    if DB.mode == "random" then
        if count == 1 then
            return 1
        end

        local nextIndex = currentIndex
        while nextIndex == currentIndex do
            nextIndex = random(1, count)
        end
        return nextIndex
    end

    return (currentIndex % count) + 1
end

local function PlayIndex(index)
    local tracks = Tracks()
    local path = tracks[index]
    if not path then
        Print("aucune musique a lire. Ajoute des fichiers dans playlist.lua.")
        return
    end

    StopCurrent(false)
    currentIndex = index
    currentPath = path
    paused = false

    local willPlay, handle = PlaySoundFile(path, DB.volumeChannel)
    if willPlay then
        currentHandle = handle
        Print("lecture: " .. TrackName(path))
    else
        currentHandle = nil
        Print("impossible de lire: " .. path)
    end

    UpdateUI()
end

local function PlayNext()
    local nextIndex = PickNextIndex()
    if nextIndex == 0 then
        Print("playlist vide. Edite playlist.lua puis recharge l'interface.")
        return
    end

    PlayIndex(nextIndex)
end

local function PlayPrevious()
    local count = #Tracks()
    if count == 0 then
        Print("playlist vide. Edite playlist.lua puis recharge l'interface.")
        return
    end

    local previousIndex = currentIndex - 1
    if previousIndex < 1 then
        previousIndex = count
    end

    PlayIndex(previousIndex)
end

local function PlayOrResume()
    if currentHandle then
        return
    end

    if paused and currentIndex > 0 then
        PlayIndex(currentIndex)
    else
        PlayNext()
    end
end

local function TogglePlayPause()
    if currentHandle then
        StopCurrent(true)
    else
        PlayOrResume()
    end
end

local function PlayBL()
    local now = GetTime()
    if blHandle or (now - lastBLAt) < 8 then
        return
    end

    local path = LafeeMusicPlayerBLTrack
    if not path or path == "" then
        Print("musique BL non configuree dans playlist.lua.")
        return
    end

    lastBLAt = now
    wasPlayingBeforeBL = currentHandle ~= nil
    StopCurrent(false)
    StopBL()

    local willPlay, handle = PlaySoundFile(path, DB.volumeChannel)
    if willPlay then
        blHandle = handle
        currentPath = path
        Print("BL detectee: lecture de " .. TrackName(path))
    else
        blHandle = nil
        Print("impossible de lire la musique BL: " .. path)
    end

    UpdateUI()
end

local function CheckPlayerBloodlust()
    if not DB or not DB.enabled then
        return
    end

    local foundBL = false

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local index = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
            if not aura then
                break
            end

            if aura.spellId and BLOODLUST_SPELLS[aura.spellId] then
                foundBL = true
                break
            end

            index = index + 1
            if index > 80 then
                break
            end
        end
    else
        for index = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", index, "HELPFUL")
            if not name then
                break
            end

            if spellId and BLOODLUST_SPELLS[spellId] then
                foundBL = true
                break
            end
        end
    end

    if foundBL and not blAuraActive then
        blAuraActive = true
        if not blHandle then
            PlayBL()
        end
    elseif not foundBL then
        blAuraActive = false
    end
end

local function StopAll()
    StopCurrent(false)
    StopBL()
    currentPath = nil
    wasPlayingBeforeBL = false
    paused = false
    Print("lecture arretee.")
    UpdateUI()
end

local function SetMode(mode)
    if mode ~= "normal" and mode ~= "random" then
        Print("mode inconnu. Utilise normal ou random.")
        return
    end

    DB.mode = mode
    Print("mode: " .. (mode == "random" and "aleatoire" or "normal"))
    UpdateUI()
end

local function ToggleMode()
    SetMode(DB.mode == "random" and "normal" or "random")
end

local function ToggleWindow()
    if not mainFrame then
        return
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
        DB.windowShown = false
    else
        mainFrame:Show()
        DB.windowShown = true
    end
end

local function CreateButton(parent, text, width, height, point, relativeTo, relativePoint, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetPoint(point, relativeTo, relativePoint, x, y)
    button:SetText(text)
    return button
end

local function CreateMainFrame()
    mainFrame = CreateFrame("Frame", "LafeeMusicPlayerFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(280, 132)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 7, right = 7, top = 7, bottom = 7 },
    })
    mainFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition()
    end)

    local point = DB.windowPoint or DEFAULTS.windowPoint
    mainFrame:SetPoint(point.point, UIParent, point.relativePoint, point.x, point.y)

    local header = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 18, -14)
    header:SetText("Lafee Music Player")

    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", ToggleWindow)

    titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleText:SetPoint("TOPLEFT", 18, -38)
    titleText:SetPoint("TOPRIGHT", -18, -38)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)

    statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("TOPLEFT", 18, -58)
    statusText:SetPoint("TOPRIGHT", -18, -58)
    statusText:SetJustifyH("LEFT")

    local previousButton = CreateButton(mainFrame, "<<", 42, 24, "BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 18, 18)
    previousButton:SetScript("OnClick", PlayPrevious)

    playPauseButton = CreateButton(mainFrame, "Play", 56, 24, "LEFT", previousButton, "RIGHT", 6, 0)
    playPauseButton:SetScript("OnClick", TogglePlayPause)

    local nextButton = CreateButton(mainFrame, ">>", 42, 24, "LEFT", playPauseButton, "RIGHT", 6, 0)
    nextButton:SetScript("OnClick", PlayNext)

    modeButton = CreateButton(mainFrame, "Normal", 66, 24, "LEFT", nextButton, "RIGHT", 6, 0)
    modeButton:SetScript("OnClick", ToggleMode)

    local volumeSlider = CreateFrame("Slider", "LafeeMusicPlayerVolumeSlider", mainFrame, "OptionsSliderTemplate")
    volumeSlider:SetPoint("BOTTOMLEFT", 18, 52)
    volumeSlider:SetSize(180, 16)
    volumeSlider:SetMinMaxValues(0, 1)
    volumeSlider:SetValueStep(0.05)
    volumeSlider:SetObeyStepOnDrag(true)
    volumeSlider:SetValue(GetMasterVolume())
    _G[volumeSlider:GetName() .. "Low"]:SetText("0")
    _G[volumeSlider:GetName() .. "High"]:SetText("100")
    _G[volumeSlider:GetName() .. "Text"]:SetText("Volume")
    volumeSlider:SetScript("OnValueChanged", function(_, value)
        SetMasterVolume(value)
    end)

    if DB.windowShown then
        mainFrame:Show()
    else
        mainFrame:Hide()
    end
end

local function CreateMinimapButton()
    minimapButton = CreateFrame("Button", "LafeeMusicPlayerMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local texture = minimapButton:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    texture:SetAllPoints()

    local fallback = minimapButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fallback:SetPoint("CENTER")
    fallback:SetText("|cffb88cffL|r")

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            TogglePlayPause()
        else
            ToggleWindow()
        end
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Lafee Music Player")
        GameTooltip:AddLine("Clic gauche: afficher/cacher", 1, 1, 1)
        GameTooltip:AddLine("Clic droit: play/pause", 1, 1, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", GameTooltip_Hide)
    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            DB.minimapAngle = math.deg(math.atan2(py - my, px - mx))
            UpdateMinimapButtonPosition()
        end)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateMinimapButtonPosition()
    end)

    UpdateMinimapButtonPosition()
end

local function ShowHelp()
    Print("/lmp play - lancer ou reprendre la playlist")
    Print("/lmp pause - pause, reprend au debut de la piste")
    Print("/lmp stop - arreter la lecture")
    Print("/lmp next - musique suivante")
    Print("/lmp prev - musique precedente")
    Print("/lmp random - mode aleatoire")
    Print("/lmp normal - mode dans l'ordre")
    Print("/lmp bl - tester la musique BL")
    Print("/lmp show - afficher/cacher l'interface")
end

local function HandleSlash(input)
    local command = (input or ""):lower():match("^%s*(%S*)")

    if command == "play" or command == "" then
        PlayOrResume()
    elseif command == "pause" then
        TogglePlayPause()
    elseif command == "stop" then
        StopAll()
    elseif command == "next" then
        PlayNext()
    elseif command == "prev" or command == "previous" then
        PlayPrevious()
    elseif command == "random" then
        SetMode("random")
    elseif command == "normal" then
        SetMode("normal")
    elseif command == "bl" then
        PlayBL()
    elseif command == "show" or command == "toggle" then
        ToggleWindow()
    else
        ShowHelp()
    end
end

local function SafeRegisterEvent(event)
    local ok = pcall(function()
        LMP:RegisterEvent(event)
    end)

    if not ok then
        Print("WoW a refuse l'event " .. event .. ". Recharge l'interface hors combat si besoin.")
    end
end

local function SafeRegisterUnitEvent(event, unit)
    local ok = pcall(function()
        LMP:RegisterUnitEvent(event, unit)
    end)

    if not ok then
        Print("WoW a refuse l'event " .. event .. ". Recharge l'interface hors combat si besoin.")
    end
end

LMP:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            CopyDefaults()
            if math.randomseed then
                math.randomseed(time())
            elseif randomseed then
                randomseed(time())
            end
            SLASH_LAFEEMUSICPLAYER1 = "/lmp"
            SLASH_LAFEEMUSICPLAYER2 = "/lafee"
            SlashCmdList.LAFEEMUSICPLAYER = HandleSlash
            CreateMainFrame()
            CreateMinimapButton()
            UpdateUI()

            C_Timer.After(0, function()
                SafeRegisterEvent("PLAYER_ENTERING_WORLD")
                SafeRegisterUnitEvent("UNIT_AURA", "player")
                SafeRegisterEvent("SOUNDKIT_FINISHED")
            end)

            Print("charge. Tape /lmp pour lancer la playlist.")
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UNIT_AURA" then
        CheckPlayerBloodlust()
    elseif event == "SOUNDKIT_FINISHED" then
        local handle = ...
        if blHandle and handle == blHandle then
            blHandle = nil
            if wasPlayingBeforeBL then
                wasPlayingBeforeBL = false
                PlayNext()
            else
                currentPath = nil
                UpdateUI()
            end
        elseif currentHandle and handle == currentHandle then
            currentHandle = nil
            PlayNext()
        end
    end
end)

SafeRegisterEvent("ADDON_LOADED")
