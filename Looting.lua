-- Automate looting and keep the loot frame hidden during normal looting

local lootState = {
    sessionActive = false,
    frameHidden = true,
    slotFailed = false,
    lastSlotCount = nil,
    slotTicker = nil,
    hiddenAnchor = CreateFrame("Frame", nil, UIParent),
}

lootState.hiddenAnchor:Hide()

-- Reparent loot frame to hidden anchor to suppress it without touching its events
local function SuppressLootFrame()
    lootState.frameHidden = true
    if LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:SetParent(lootState.hiddenAnchor)
    end
end

-- Reparent loot frame back to UIParent to make it visible
local function RevealLootFrame()
    lootState.frameHidden = false
    if LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:SetParent(UIParent)
        LootFrame:SetFrameStrata("HIGH")
    end
end

-- Stop any in-progress slot ticker
local function StopSlotTicker()
    if lootState.slotTicker then
        lootState.slotTicker:Cancel()
    end
end

-- Attempt to loot a single slot, mark failure if slot is locked
local function TryLootSlot(slotIndex)
    local slotType = GetLootSlotType(slotIndex)
    if slotType == Enum.LootSlotType.None then return true end

    local _, _, _, isLocked = GetLootSlotInfo(slotIndex)
    if isLocked then
        lootState.slotFailed = true
        return false
    end

    LootSlot(slotIndex)
    return true
end

-- Step through all loot slots one per tick to avoid server race conditions
local function BeginSlotLooting(totalSlots)
    StopSlotTicker()
    local currentSlot = totalSlots

    lootState.slotTicker = C_Timer.NewTicker(0.033, function()
        if currentSlot >= 1 then
            TryLootSlot(currentSlot)
            currentSlot = currentSlot - 1
        else
            if lootState.slotFailed then
                RevealLootFrame()
            end
            StopSlotTicker()
        end
    end, totalSlots + 1)
end

-- Decide whether to auto-loot or show the frame when a corpse is opened
local function OnLootWindowReady()
    lootState.sessionActive = true

    -- Suppress immediately before Blizzard can show the frame
    SuppressLootFrame()

    local totalSlots = GetNumLootItems()
    if totalSlots == 0 or lootState.lastSlotCount == totalSlots then return end

    local autoLootActive = GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
    if autoLootActive then
        BeginSlotLooting(totalSlots)
    else
        RevealLootFrame()
    end

    lootState.lastSlotCount = totalSlots
end

-- Clean up session state and re-suppress the loot frame when looting ends
local function OnLootWindowClosed()
    lootState.sessionActive = false
    lootState.frameHidden = true
    lootState.slotFailed = false
    lootState.lastSlotCount = nil
    StopSlotTicker()
    SuppressLootFrame()
end

-- Reveal loot frame mid-session if the bag is full so nothing is missed
local function OnGameErrorMessage(_, message)
    if tContains({ ERR_INV_FULL, ERR_ITEM_MAX_COUNT }, message) then
        if lootState.sessionActive and lootState.frameHidden then
            RevealLootFrame()
        end
    end
end

-- Apply fast loot rate CVar on login
local function OnPlayerLogin()
    SetCVar("autoLootRate", 0)
    SuppressLootFrame()

    -- Block LootFrame from re-showing itself during an active auto-loot session
    hooksecurefunc(LootFrame, "UpdateShownState", function()
        if lootState.sessionActive and lootState.frameHidden then
            SuppressLootFrame()
        end
    end)
end

-- Register all required events
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
    