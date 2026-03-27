-- Save and import auction house favorites across characters because favorites are per-character by default

-- Initialize database table for a given key because saved variables may be nil on first load
local function GetDatabase(key)
    ItemFlowAccountDB = ItemFlowAccountDB or {}
    ItemFlowAccountDB[key] = ItemFlowAccountDB[key] or {}
    return ItemFlowAccountDB[key]
end

-- Create a square icon button matching the native favorites search button style
local function CreateIconButton(parent, atlas, tooltip, onClick)
    local button = CreateFrame("Button", nil, parent, "SquareIconButtonTemplate")
    button.Icon:SetAtlas(atlas)
    button.Icon:Show()

    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    return button
end

-- Print a single item line with green [+] prefix and native item link
local function PrintItemLine(itemID)
    local _, itemLink = C_Item.GetItemInfo(itemID)
    if itemLink then
        print("|cff00AA00[+]|r " .. itemLink)
    else
        print(string.format("|cff00AA00[+]|r |cffFFFF00Item %d|r", itemID))
    end
end

-- Auction house favorites sync module
local auctionHouse = {
    isSavePending = false,
    saveButton    = nil,
    importButton  = nil,
}

-- Serialize item key fields to a storable table because raw keys contain nil values that break serialization
function auctionHouse.SerializeItemKey(itemKey)
    return {
        itemID = itemKey.itemID,
        battlePetSpeciesID = itemKey.battlePetSpeciesID or 0,
        itemSuffix = itemKey.itemSuffix or 0,
        itemLevel = itemKey.itemLevel or 0,
    }
end

-- Deserialize stored data back to an item key because the API expects nil instead of zero for unused fields
function auctionHouse.DeserializeItemKey(data)
    return {
        itemID = data.itemID,
        battlePetSpeciesID = data.battlePetSpeciesID ~= 0 and data.battlePetSpeciesID or nil,
        itemSuffix = data.itemSuffix ~= 0 and data.itemSuffix or nil,
        itemLevel = data.itemLevel ~= 0 and data.itemLevel or nil,
    }
end

-- Process browse results to capture favorites into database because results arrive asynchronously after search
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

    print("|cffFFFF00Saved Favorites:|r")
    for _, data in ipairs(database.favorites) do
        PrintItemLine(data.itemID)
    end
end

-- Trigger a favorites search to save current favorites because the API requires a search before results are available
function auctionHouse.Save()
    if not C_AuctionHouse.FavoritesAreAvailable() then
        print("|cffff9900SuperAuction:|r AH favorites are not available right now.")
        return
    end

    if not C_AuctionHouse.HasFavorites() then
        print("|cffff9900SuperAuction:|r You have no AH favorites to save.")
        return
    end

    auctionHouse.isSavePending = true
    C_AuctionHouse.SearchForFavorites({})
end

-- Import saved favorites from database to restore them on current character
function auctionHouse.Import()
    if not C_AuctionHouse.FavoritesAreAvailable() then
        print("|cffff9900SuperAuction:|r AH favorites are not available right now.")
        return
    end

    local database = GetDatabase("AuctionFavorites")
    if not database.favorites or #database.favorites == 0 then
        print("|cffFFFF00Auction Favorites: No items saved.|r")
        return
    end

    if C_AuctionHouse.HasMaxFavorites() then
        print("|cffff9900SuperAuction:|r Your AH favorites list is full. Clear some before importing.")
        return
    end

    local addedItems = {}

    for _, data in ipairs(database.favorites) do
        local itemKey = auctionHouse.DeserializeItemKey(data)
        if not C_AuctionHouse.IsFavoriteItem(itemKey) then
            C_AuctionHouse.SetFavoriteItem(itemKey, true)
            addedItems[#addedItems + 1] = itemKey.itemID
        end
    end

    if #addedItems == 0 then
        print("|cffFFFF00Auction Favorites: No new items added.|r")
    else
        print("|cffFFFF00Imported Favorites:|r")
        for _, itemID in ipairs(addedItems) do
            PrintItemLine(itemID)
        end
    end

    C_AuctionHouse.SearchForFavorites({})
end

-- Create icon buttons next to the native favorites search button
function auctionHouse.Setup()
    if auctionHouse.saveButton then return end
    if not AuctionHouseFrame then return end

    local searchBar = AuctionHouseFrame.SearchBar
    if not searchBar or not searchBar.FavoritesSearchButton then return end

    local anchor = searchBar.FavoritesSearchButton
    local width, height = anchor:GetSize()

    auctionHouse.saveButton = CreateIconButton(searchBar, "poi-workorders", "Save Favorites", auctionHouse.Save)
    auctionHouse.saveButton:SetSize(width, height)
    auctionHouse.saveButton.Icon:SetSize(width * 0.6, height * 0.6)
    auctionHouse.saveButton:SetPoint("RIGHT", anchor, "LEFT", -4, 0)

    auctionHouse.importButton = CreateIconButton(searchBar, "GreenCross", "Import Favorites", auctionHouse.Import)
    auctionHouse.importButton:SetSize(width, height)
    auctionHouse.importButton.Icon:SetSize(width * 0.75, height * 0.75)
    auctionHouse.importButton:SetPoint("RIGHT", auctionHouse.saveButton, "LEFT", -4, 0)
end

-- Show buttons when auction house opens
function auctionHouse.OnShow()
    auctionHouse.Setup()
    if auctionHouse.saveButton then auctionHouse.saveButton:Show() end
    if auctionHouse.importButton then auctionHouse.importButton:Show() end
end

-- Hide buttons and reset state when auction house closes
function auctionHouse.OnClose()
    auctionHouse.isSavePending = false
    if auctionHouse.saveButton then auctionHouse.saveButton:Hide() end
    if auctionHouse.importButton then auctionHouse.importButton:Hide() end
end

-- Register events to drive module lifecycle
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
