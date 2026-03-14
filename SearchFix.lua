-- Auto trigger auction house search on paste to skip manual button clicks because pasting an item name should immediately start searching

local searchFrame = CreateFrame("Frame")
local isSearchHooked = false

-- Retry clicking the search button until enabled to handle throttling because the search button may be temporarily disabled after recent queries

local function TryClickSearch(attempts)
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return end
    local searchButton = AuctionHouseFrame.SearchBar.SearchButton
    if not searchButton then return end
    if searchButton:IsEnabled() then
        searchButton:Click()
    elseif (attempts or 0) < 10 then
        C_Timer.After(0.1, function() TryClickSearch((attempts or 0) + 1) end)
    end
end

-- Hook the search box text change to detect paste events via length jumps because pasted text causes a sudden increase in character count

local function HookSearchBox()
    if isSearchHooked then return end
    if not AuctionHouseFrame or not AuctionHouseFrame.SearchBar then return end
    local searchBox = AuctionHouseFrame.SearchBar.SearchBox
    local lastLength = 0
    searchBox:HookScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text ~= "" and math.abs(#text - lastLength) > 1 then
            TryClickSearch(0)
        end
        lastLength = #text
    end)
    isSearchHooked = true
end

-- Apply the search hook when auction house first opens to initialize paste detection because the search box must exist before it can be hooked

searchFrame:RegisterEvent("AUCTION_HOUSE_SHOW")

searchFrame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then HookSearchBox() end
end)
