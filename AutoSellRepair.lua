-- Auto repair gear and sell junk items at merchants to save time because manual selling and repairing is tedious

local vendorFrame = CreateFrame("Frame")
local isVendorVisited = false

local handlers = {

    -- Repair gear and sell junk on first vendor interaction to automate routine maintenance because players always want to repair and clear junk

    MERCHANT_SHOW = function()
        if isVendorVisited then return end
        isVendorVisited = true
        RunNextFrame(function()
            if CanMerchantRepair() then RepairAllItems() end
            C_MerchantFrame.SellAllJunkItems()
        end)
    end,

    -- Reset vendor visit flag on close to allow re-triggering on next visit because each merchant session should be independent

    MERCHANT_CLOSED = function()
        isVendorVisited = false
    end,

    -- Auto confirm trade timer removal popup to skip manual confirmation because the dialog interrupts vendor flow

    MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL = function()
        local popup = StaticPopup_FindVisible("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL")
        if popup and popup.button1 then popup.button1:Click() end
    end,
}

-- Dispatch events through handler table to keep logic modular because each merchant event has distinct behavior

vendorFrame:SetScript("OnEvent", function(_, event)
    if handlers[event] then handlers[event]() end
end)

-- Register all handler events to receive merchant notifications because the frame needs to listen before events fire

for event in pairs(handlers) do
    vendorFrame:RegisterEvent(event)
end
