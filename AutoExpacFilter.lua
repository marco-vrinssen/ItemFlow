-- Apply current expansion filter on auction house search bar to default results to latest content because most players only trade current expansion items

local filterFrame = CreateFrame("Frame")
local isAuctionHouseHooked = false
local isCraftingOrdersHooked = false

-- Hook auction house search bar to enable current expansion filter because the default unfiltered view shows irrelevant legacy items

local function HookAuctionHouseFilter()
    if isAuctionHouseHooked then return end
    local searchBar = AuctionHouseFrame.SearchBar

    local function applyFilter()
        searchBar.FilterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        searchBar:UpdateClearFiltersButton()
    end

    searchBar:HookScript("OnShow", function() C_Timer.After(0, applyFilter) end)
    C_Timer.After(0, applyFilter)
    isAuctionHouseHooked = true
end

-- Hook crafting orders filter dropdown to enable current expansion filter because unfiltered crafting orders include outdated recipes

local function HookCraftingOrdersFilter()
    if isCraftingOrdersHooked then return end
    local browseBar = ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar
    local filterDropdown = browseBar.FilterDropdown

    local function applyFilter()
        filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        filterDropdown:ValidateResetState()
    end

    filterDropdown:HookScript("OnShow", function() C_Timer.After(0, applyFilter) end)
    C_Timer.After(0, applyFilter)
    isCraftingOrdersHooked = true
end

-- Register events and dispatch hooks to apply filters when each frame opens because hooks must wait until frames exist

filterFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
filterFrame:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")

filterFrame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        HookAuctionHouseFilter()
    elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
        HookCraftingOrdersFilter()
    end
end)
