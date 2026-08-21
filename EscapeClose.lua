local addonName = ...
local FRAME_NAME = "LafeeMusicPlayerFrame"

-- Let Escape close the standalone player window like a native Blizzard panel.
if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, FRAME_NAME)
end

-- Keep the persisted visibility state in sync when Escape hides the frame.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    C_Timer.After(0, function()
        local frame = _G[FRAME_NAME]
        if not frame then return end

        frame:HookScript("OnShow", function()
            if LafeeMusicPlayerDB then
                LafeeMusicPlayerDB.windowShown = true
            end
        end)

        frame:HookScript("OnHide", function()
            if LafeeMusicPlayerDB then
                LafeeMusicPlayerDB.windowShown = false
            end
        end)
    end)
end)
