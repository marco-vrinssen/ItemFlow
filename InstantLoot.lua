-- Automate looting and suppress the loot frame to speed up item collection because manual looting adds unnecessary delay

local lootState = {
    isSessionActive = false,
    isFrameHidden = true,
    hasSlotFailed = false,
    lastSlotCount = nil,
    slotTicker = nil,
    hiddenAnchor = CreateFrame("Frame", nil, UIParent),
}

lootState.hiddenAnchor:Hide()

-- Reparent loot frame to hidden anchor to suppress it visually because hiding the frame directly would unregister its events

local function SuppressLootFrame()
    lootState.isFrameHidden = true
    if LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:SetParent(lootState.hiddenAnchor)
    end
end

-- Reparent loot frame back to UIParent to make it visible because locked or failed slots require manual player interaction

local function RevealLootFrame()
    lootState.isFrameHidden = false
    if LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:SetParent(UIParent)
        LootFrame:SetFrameStrata("HIGH")
    end
end

-- Cancel any running slot ticker to stop the looting sequence because the session may end before all slots are processed

local function StopSlotTicker()
    if lootState.slotTicker then
        lootState.slotTicker:Cancel()
    end
end

-- Attempt to loot a single slot to collect its contents because each slot must be looted individually through the API

local function TryLootSlot(slotIndex)
    local slotType = GetLootSlotType(slotIndex)
    if slotType == Enum.LootSlotType.None then return true end

    local _, _, _, isLocked = GetLootSlotInfo(slotIndex)
    if isLocked then
        lootState.hasSlotFailed = true
        return false
    end

    LootSlot(slotIndex)
    return true
end

-- Step through all loot slots one per tick to collect items sequentially because looting too fast causes server race conditions

local function BeginSlotLooting(totalSlots)
    StopSlotTicker()
    local currentSlot = totalSlots

    lootState.slotTicker = C_Timer.NewTicker(0.033, function()
        if currentSlot >= 1 then
            TryLootSlot(currentSlot)
            currentSlot = currentSlot - 1
        else
            if lootState.hasSlotFailed then
                RevealLootFrame()
            end
            StopSlotTicker()
        end
    end, totalSlots + 1)
end

-- Handle loot window opening to decide between auto-loot and manual display because auto-loot preference determines the looting behavior

local function OnLootWindowReady()
    lootState.isSessionActive = true

    -- Suppress loot frame immediately to prevent flicker because Blizzard shows it before auto-loot can process

    SuppressLootFrame()

    local totalSlots = GetNumLootItems()
    if totalSlots == 0 or lootState.lastSlotCount == totalSlots then return end

    local isAutoLootActive = GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
    if isAutoLootActive then
        BeginSlotLooting(totalSlots)
    else
        RevealLootFrame()
    end

    lootState.lastSlotCount = totalSlots
end

-- Clean up session state on loot window close to reset for next looting session because stale state would corrupt subsequent loot attempts

local function OnLootWindowClosed()
    lootState.isSessionActive = false
    lootState.isFrameHidden = true
    lootState.hasSlotFailed = false
    lootState.lastSlotCount = nil
    StopSlotTicker()
    SuppressLootFrame()
end

-- Reveal loot frame on inventory full error to let player manage bags because hidden items would be lost if the frame stays suppressed

local function OnGameErrorMessage(_, message)
    if tContains({ ERR_INV_FULL, ERR_ITEM_MAX_COUNT }, message) then
        if lootState.isSessionActive and lootState.isFrameHidden then
            RevealLootFrame()
        end
    end
end

-- Set fast loot rate and hook frame updates on login to initialize the module because settings and hooks must be applied once at startup

local function OnPlayerLogin()
    SetCVar("autoLootRate", 0)
    SuppressLootFrame()

    -- Block loot frame from reshowing during auto-loot to prevent flicker because UpdateShownState can override the suppression

    hooksecurefunc(LootFrame, "UpdateShownState", function()
        if lootState.isSessionActive and lootState.isFrameHidden then
            SuppressLootFrame()
        end
    end)
end

-- Register all required events to drive the loot automation lifecycle because each event triggers a distinct phase of the looting process

local lootEventFrame = CreateFrame("Frame")
lootEventFrame:RegisterEvent("PLAYER_LOGIN")
lootEventFrame:RegisterEvent("LOOT_READY")
lootEventFrame:RegisterEvent("LOOT_CLOSED")
lootEventFrame:RegisterEvent("UI_ERROR_MESSAGE")

lootEventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "LOOT_READY" then
        OnLootWindowReady()
    elseif event == "LOOT_CLOSED" then
        OnLootWindowClosed()
    elseif event == "UI_ERROR_MESSAGE" then
        OnGameErrorMessage(...)
    end
end)