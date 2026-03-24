-- State

local lastLootTime = 0
local suppressLootFrameShow = false
local LOOT_COOLDOWN = 0.2

-- Suppress LootFrame:Show() to prevent flash before our handler runs

local originalLootFrameShow = LootFrame.Show

LootFrame.Show = function(self, ...)
    if not suppressLootFrameShow then
        originalLootFrameShow(self, ...)
    end
end

-- Loot all unlocked items in reverse order to avoid index shifting

local function LootUnlockedItems()
    for slotIndex = GetNumLootItems(), 1, -1 do
        local _, _, _, _, _, isLocked = GetLootSlotInfo(slotIndex)
        if not isLocked then
            LootSlot(slotIndex)
        end
    end
end

-- Hide frame during looting, restore if locked items remain

local function SuppressAndLoot()
    suppressLootFrameShow = true
    LootFrame:Hide()

    LootUnlockedItems()

    suppressLootFrameShow = false

    if GetNumLootItems() == 0 then
        CloseLoot()
    else
        LootFrame:Show()
    end
end

-- Skip if auto-loot is inactive or cooldown has not elapsed

local function OnLootReady()
    if GetCVarBool("autoLootDefault") == IsModifiedClick("AUTOLOOTTOGGLE") then return end
    if (GetTime() - lastLootTime) < LOOT_COOLDOWN then return end

    SuppressAndLoot()

    lastLootTime = GetTime()
end

-- Register

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:SetScript("OnEvent", OnLootReady)
