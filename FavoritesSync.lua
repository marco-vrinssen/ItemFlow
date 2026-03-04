-- Sync auction house and crafting order favorites across all characters

local ADDON_NAME = "MyTems"
local favoritesDB, characterDB
local syncing = false
local auctionHouseOpen = false

----------------------------------------------------------------
-- Item key handling
----------------------------------------------------------------

local KEY_FIELDS = {"itemID", "itemLevel", "itemSuffix", "battlePetSpeciesID", "itemContext"}

local function CopyItemKey(itemKey)
    local copy = {}
    for _, field in ipairs(KEY_FIELDS) do
        copy[field] = itemKey[field] or 0
    end
    return copy
end

local function SerializeItemKey(itemKey)
    local parts = {}
    for i, field in ipairs(KEY_FIELDS) do
        parts[i] = tostring(itemKey[field] or 0)
    end
    return table.concat(parts, ":")
end

----------------------------------------------------------------
-- Chat notifications
----------------------------------------------------------------

local function GetItemLink(itemKey)
    if itemKey.itemID and itemKey.itemID ~= 0 then
        local _, link = C_Item.GetItemInfo(itemKey.itemID)
        if link then return link end
        C_Item.RequestLoadItemDataByID(itemKey.itemID)
        return "|cff9d9d9d[Item " .. itemKey.itemID .. "]|r"
    end
    return "|cff9d9d9d[Unknown]|r"
end

local function Notify(added, displayLink)
    local prefix = added and "|cff00ff00[+]|r " or "|cffff0000[-]|r "
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. displayLink)
    end
end

----------------------------------------------------------------
-- Favorite change hook
----------------------------------------------------------------

hooksecurefunc(C_AuctionHouse, "SetFavoriteItem", function(itemKey, isFavorite)
    if syncing or not favoritesDB or not characterDB then return end
    local key = SerializeItemKey(itemKey)
    if isFavorite then
        favoritesDB.favorites[key] = CopyItemKey(itemKey)
        characterDB.synced[key] = CopyItemKey(itemKey)
    else
        favoritesDB.favorites[key] = nil
        characterDB.synced[key] = nil
    end
    Notify(isFavorite, GetItemLink(itemKey))
end)

----------------------------------------------------------------
-- Import pre-existing favorites from browse results
----------------------------------------------------------------

local function ImportFavorite(itemKey)
    if not itemKey or not favoritesDB or not characterDB then return end
    if not C_AuctionHouse.IsFavoriteItem(itemKey) then return end
    local key = SerializeItemKey(itemKey)
    if favoritesDB.favorites[key] then return end
    favoritesDB.favorites[key] = CopyItemKey(itemKey)
    characterDB.synced[key] = CopyItemKey(itemKey)
end

----------------------------------------------------------------
-- Sync favorites from account DB to character
----------------------------------------------------------------

local function SyncFavorites()
    if not favoritesDB or not characterDB then return end
    syncing = true
    local changed = false

    -- Add account favorites missing on this character

    for key, itemKey in pairs(favoritesDB.favorites) do
        if not characterDB.synced[key] then
            C_AuctionHouse.SetFavoriteItem(itemKey, true)
            characterDB.synced[key] = CopyItemKey(itemKey)
            Notify(true, GetItemLink(itemKey))
            changed = true
        end
    end

    -- Remove favorites that were deleted from account DB

    for key, itemKey in pairs(characterDB.synced) do
        if not favoritesDB.favorites[key] then
            C_AuctionHouse.SetFavoriteItem(itemKey, false)
            Notify(false, GetItemLink(itemKey))
            characterDB.synced[key] = nil
            changed = true
        end
    end

    syncing = false
    if changed and auctionHouseOpen then
        C_AuctionHouse.SearchForFavorites({})
    end
end

----------------------------------------------------------------
-- Event handling
----------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            MyTemsFavoritesDB = MyTemsFavoritesDB or {}
            favoritesDB = MyTemsFavoritesDB
            favoritesDB.favorites = favoritesDB.favorites or {}

            MyTemsFavoritesCharDB = MyTemsFavoritesCharDB or {}
            characterDB = MyTemsFavoritesCharDB
            characterDB.synced = characterDB.synced or {}
        elseif addon == "Blizzard_ProfessionsCustomerOrders" then
            -- Crafting orders share the same item key favorites as auction house
            if ProfessionsCustomerOrdersFrame then
                ProfessionsCustomerOrdersFrame:HookScript("OnShow", SyncFavorites)
            end
        end
        return
    end

    if event == "AUCTION_HOUSE_SHOW" then
        auctionHouseOpen = true
        SyncFavorites()
        frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
        frame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        frame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
        return
    end

    if event == "AUCTION_HOUSE_CLOSED" then
        auctionHouseOpen = false
        frame:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        frame:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
        frame:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        frame:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        frame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
        return
    end

    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        for _, result in ipairs(C_AuctionHouse.GetBrowseResults()) do
            ImportFavorite(result.itemKey)
        end
        return
    end

    if event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        local results = ...
        if results then
            for _, result in ipairs(results) do
                ImportFavorite(result.itemKey)
            end
        end
        return
    end

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = ...
        if itemID then
            ImportFavorite(C_AuctionHouse.MakeItemKey(itemID))
        end
        return
    end

    if event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = ...
        if itemKey then
            ImportFavorite(itemKey)
        end
        return
    end
end)
