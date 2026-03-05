-- Define loot debounce constants to prevent duplicate loot attempts because rapid looting fires multiple events

local LOOT_DELAY   = 0.1
local lastLootTime = 0

-- Create hidden parent frame to suppress loot frame rendering because visible frame causes flicker

local hiddenFrame = CreateFrame("Frame", nil, UIParent)
hiddenFrame:SetToplevel(true)
hiddenFrame:Hide()

-- Reparent loot frame to hidden parent to keep it invisible because hidden parent suppresses rendering

local function HideLootFrame()
    if LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:SetParent(hiddenFrame)
    end
end

-- Loot all slots in reverse order to collect items quickly because manual looting is slow

local function OnLootReady()
    local isAutoLoot = GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
    if not isAutoLoot then return end
    if (GetTime() - lastLootTime) < LOOT_DELAY then return end

    for slotIndex = GetNumLootItems(), 1, -1 do
        LootSlot(slotIndex)
    end

    lastLootTime = GetTime()
end

-- Register loot lifecycle events to auto-loot and reset frame state because timing matters

hiddenFrame:RegisterEvent("LOOT_READY")
hiddenFrame:RegisterEvent("LOOT_CLOSED")

hiddenFrame:SetScript("OnEvent", function(_, event)
    if event == "LOOT_READY" then
        OnLootReady()
    elseif event == "LOOT_CLOSED" then
        HideLootFrame()
    end
end)

-- Delay initial hide to let other addons finish hooking LootFrame because early hiding breaks their hooks

C_Timer.After(6, HideLootFrame)