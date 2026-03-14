-- Bind spacebar to the active sell frame post button to speed up auction posting because clicking the post button manually is slow

local quickPostFrame = CreateFrame("Frame")
local isPostEnabled = false

-- Click the visible sell frame post button to submit an auction because the auction house has multiple sell frames and only one is active

local function PostAuction()
    if not isPostEnabled then return end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return end
    local sellFrames = {
        AuctionHouseFrame.CommoditiesSellFrame,
        AuctionHouseFrame.ItemSellFrame,
        AuctionHouseFrame.SellFrame,
    }
    for _, sellFrame in ipairs(sellFrames) do
        if sellFrame and sellFrame:IsShown()
        and sellFrame.PostButton and sellFrame.PostButton:IsEnabled() then
            sellFrame.PostButton:Click()
            return
        end
    end
end

-- Enable spacebar capture when auction house opens to activate quick posting because the keybind should only work while the auction house is visible

local function OnAuctionHouseShow()
    isPostEnabled = true
    quickPostFrame:SetScript("OnKeyDown", function(_, key)
        if key == "SPACE" and isPostEnabled then
            PostAuction()
            quickPostFrame:SetPropagateKeyboardInput(false)
        else
            quickPostFrame:SetPropagateKeyboardInput(true)
        end
    end)
    quickPostFrame:SetPropagateKeyboardInput(true)
    quickPostFrame:EnableKeyboard(true)
    quickPostFrame:SetFrameStrata("HIGH")
end

-- Disable spacebar capture when auction house closes to restore normal input because the keybind should not interfere outside the auction house

local function OnAuctionHouseClosed()
    isPostEnabled = false
    quickPostFrame:SetScript("OnKeyDown", nil)
    quickPostFrame:EnableKeyboard(false)
end

-- Register auction house events to toggle quick post mode because the feature activates and deactivates with the auction house lifecycle

quickPostFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
quickPostFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")

quickPostFrame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        OnAuctionHouseShow()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        OnAuctionHouseClosed()
    end
end)
