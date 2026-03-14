-- Save and import auction house favorites across characters to sync collections because favorites are per-character by default

-- Initialize database table for a given key to ensure storage exists because saved variables may be nil on first load

local function GetDatabase(key)
    ItemFlowAccountDB = ItemFlowAccountDB or {}
    ItemFlowAccountDB[key] = ItemFlowAccountDB[key] or {}
    return ItemFlowAccountDB[key]
end

-- Create save and import button pair on a parent frame to provide user controls because favorites sync requires manual trigger

local function CreateButtonPair(parent, onSave, onImport)
    local saveButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    saveButton:SetSize(130, 22)
    saveButton:SetText("Save Favorites")
    saveButton:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -24, 4)
    saveButton:SetScript("OnClick", onSave)
    saveButton:Hide()

    local importButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    importButton:SetSize(130, 22)
    importButton:SetText("Import Favorites")
    importButton:SetPoint("RIGHT", saveButton, "LEFT", -8, 0)
    importButton:SetScript("OnClick", onImport)
    importButton:Hide()

    return saveButton, importButton
end

-- Define auction house favorites module to encapsulate all sync logic because grouping related state and functions improves maintainability

local auctionHouse = {
    isSavePending = false,
    saveButton = nil,
    importButton = nil,
    isBrowseHooked = false
}

-- Serialize item key fields to a storable table to persist favorites because raw item keys contain nil values that break serialization

function auctionHouse.SerializeItemKey(itemKey)
    return {
        itemID = itemKey.itemID,
        battlePetSpeciesID = itemKey.battlePetSpeciesID or 0,
        itemSuffix = itemKey.itemSuffix or 0,
        itemLevel = itemKey.itemLevel or 0,
    }
end

-- Deserialize stored data back to an item key to restore favorites because the game API expects nil instead of zero for unused fields

function auctionHouse.DeserializeItemKey(data)
    return {
        itemID = data.itemID,
        battlePetSpeciesID = data.battlePetSpeciesID ~= 0 and data.battlePetSpeciesID or nil,
        itemSuffix = data.itemSuffix ~= 0 and data.itemSuffix or nil,
        itemLevel = data.itemLevel ~= 0 and data.itemLevel or nil,
    }
end

-- Process browse results to capture favorites into database to complete a pending save because results arrive asynchronously after search

function auctionHouse.OnBrowseResultsUpdated()
    if not auctionHouse.isSavePending then return end

    local results = C_AuctionHouse.GetBrowseResults()
    if not results or #results == 0 then return end

    auctionHouse.isSavePending = false

    local database = GetDatabase("AuctionFavorites")
    database.favorites = {}

    for _, result in ipairs(results) do
        if result.itemKey then
            database.favorites[#database.favorites + 1] = auctionHouse.SerializeItemKey(result.itemKey)
        end
    end

    print(string.format("|cff00ff00ItemFlow:|r %d AH favorite(s) saved to account.", #database.favorites))
end

-- Trigger a favorites search to retrieve current favorites to save them because the API requires a search before results are available

function auctionHouse.Save()
    if not C_AuctionHouse.FavoritesAreAvailable() then
        print("|cffff9900ItemFlow:|r AH favorites are not available right now.")
        return
    end

    if not C_AuctionHouse.HasFavorites() then
        print("|cffff9900ItemFlow:|r You have no AH favorites to save.")
        return
    end

    auctionHouse.isSavePending = true
    C_AuctionHouse.SearchForFavorites({})
end

-- Import saved favorites from database to restore them on current character because favorites need to be set individually via API

function auctionHouse.Import()
    if not C_AuctionHouse.FavoritesAreAvailable() then
        print("|cffff9900ItemFlow:|r AH favorites are not available right now.")
        return
    end

    local database = GetDatabase("AuctionFavorites")
    if not database.favorites or #database.favorites == 0 then
        print("|cffff9900ItemFlow:|r No saved AH favorites found. Save them on another character first.")
        return
    end

    if C_AuctionHouse.HasMaxFavorites() then
        print("|cffff9900ItemFlow:|r Your AH favorites list is full. Clear some before importing.")
        return
    end

    local added, skipped = 0, 0

    for _, data in ipairs(database.favorites) do
        local itemKey = auctionHouse.DeserializeItemKey(data)
        if C_AuctionHouse.IsFavoriteItem(itemKey) then
            skipped = skipped + 1
        else
            C_AuctionHouse.SetFavoriteItem(itemKey, true)
            added = added + 1
        end
    end

    print(string.format("|cff00ff00ItemFlow:|r Imported %d AH favorite(s). %d already present, skipped.", added, skipped))
    C_AuctionHouse.SearchForFavorites({})
end

-- Toggle button visibility based on browse frame state to show controls only when relevant because buttons should not appear on other AH tabs

function auctionHouse.UpdateButtonVisibility()
    if not auctionHouse.saveButton then return end

    local isVisible = AuctionHouseFrame
        and AuctionHouseFrame:IsShown()
        and AuctionHouseFrame.BrowseResultsFrame
        and AuctionHouseFrame.BrowseResultsFrame:IsShown()

    if isVisible then
        auctionHouse.saveButton:Show()
        auctionHouse.importButton:Show()
    else
        auctionHouse.saveButton:Hide()
        auctionHouse.importButton:Hide()
    end
end

-- Create sync buttons on auction house frame to provide save and import controls because users need a way to trigger sync manually

function auctionHouse.Setup()
    if auctionHouse.saveButton then return end
    if not AuctionHouseFrame then return end

    auctionHouse.saveButton, auctionHouse.importButton = CreateButtonPair(AuctionHouseFrame, auctionHouse.Save, auctionHouse.Import)
end

-- Hook browse frame show and hide to update button visibility because the browse tab can be toggled without reopening the auction house

function auctionHouse.HookBrowseFrame()
    if auctionHouse.isBrowseHooked then return end
    if not AuctionHouseFrame or not AuctionHouseFrame.BrowseResultsFrame then return end

    AuctionHouseFrame.BrowseResultsFrame:HookScript("OnShow", auctionHouse.UpdateButtonVisibility)
    AuctionHouseFrame.BrowseResultsFrame:HookScript("OnHide", auctionHouse.UpdateButtonVisibility)
    auctionHouse.isBrowseHooked = true
end

-- Initialize auction house module when opened to set up buttons and hooks because frames must exist before they can be modified

function auctionHouse.OnShow()
    auctionHouse.Setup()
    auctionHouse.HookBrowseFrame()
    auctionHouse.UpdateButtonVisibility()
end

-- Clean up module state when auction house closes to reset pending operations because leftover state could corrupt the next session

function auctionHouse.OnClose()
    auctionHouse.isSavePending = false
    if auctionHouse.saveButton then auctionHouse.saveButton:Hide() end
    if auctionHouse.importButton then auctionHouse.importButton:Hide() end
end

-- Register and handle auction house events to drive module lifecycle because each event triggers a distinct phase of the sync workflow

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        auctionHouse.OnShow()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        auctionHouse.OnClose()
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        auctionHouse.OnBrowseResultsUpdated()
    end
end)