--[[
    Nodes Trading Engine
    
    Handles all trading logic including:
    - Buy/sell execution
    - Price calculations
    - Slippage calculations
    - Order validation
]]

local NodeMarket = require("src.systems.node_market")
local PortfolioManager = require("src.managers.portfolio")
local Notifications = require("src.ui.notifications")
local Log = require("src.core.log")

local TradingEngine = {}

function TradingEngine.calculateSlippage(amount, node)
    if not node or not node.price then
        return 0
    end
    
    -- Simple slippage calculation based on order size
    local baseSlippage = 0.001 -- 0.1% base slippage
    local sizeMultiplier = math.min(amount / 1000, 0.01) -- Up to 1% for large orders
    return baseSlippage + sizeMultiplier
end

function TradingEngine.formatPrice(price)
    if not price then return "0" end
    if price >= 1000000 then
        return string.format("%.2fM", price / 1000000)
    elseif price >= 1000 then
        return string.format("%.2fK", price / 1000)
    else
        return string.format("%.2f", price)
    end
end

function TradingEngine.formatMarketCap(marketCap)
    if not marketCap then return "0" end
    if marketCap >= 1000000000 then
        return string.format("%.2fB", marketCap / 1000000000)
    elseif marketCap >= 1000000 then
        return string.format("%.2fM", marketCap / 1000000)
    elseif marketCap >= 1000 then
        return string.format("%.2fK", marketCap / 1000)
    else
        return string.format("%.0f", marketCap)
    end
end

function TradingEngine.validateOrder(state, orderType, amount, price)
    local errors = {}
    
    -- Validate amount
    local numAmount = tonumber(amount)
    if not numAmount or numAmount <= 0 then
        table.insert(errors, "Invalid amount")
    end
    
    -- Validate price for limit orders
    if orderType == "limit" then
        local numPrice = tonumber(price)
        if not numPrice or numPrice <= 0 then
            table.insert(errors, "Invalid limit price")
        end
    end
    
    -- Check portfolio balance for buy orders
    if state.tradingMode == "buy" then
        local portfolio = PortfolioManager.getPortfolio()
        local node = NodeMarket.getNode(state.selectedSymbol)
        if node and node.price then
            local totalCost = numAmount * node.price
            if portfolio.credits < totalCost then
                table.insert(errors, "Insufficient credits")
            end
        end
    end
    
    -- Check holdings for sell orders
    if state.tradingMode == "sell" then
        local portfolio = PortfolioManager.getPortfolio()
        local holdings = portfolio.holdings[state.selectedSymbol] or 0
        if holdings < numAmount then
            table.insert(errors, "Insufficient holdings")
        end
    end
    
    return #errors == 0, errors
end

function TradingEngine.executeBuy(state, amount, orderType, limitPrice)
    local node = NodeMarket.getNode(state.selectedSymbol)
    if not node then
        Notifications.add("Node not found", "error")
        return false
    end
    
    local numAmount = tonumber(amount)
    if not numAmount or numAmount <= 0 then
        Notifications.add("Invalid amount", "error")
        return false
    end
    
    local portfolio = PortfolioManager.getPortfolio()
    local price = node.price
    
    -- Use limit price if specified
    if orderType == "limit" and limitPrice then
        local numLimitPrice = tonumber(limitPrice)
        if numLimitPrice and numLimitPrice > 0 then
            price = numLimitPrice
        end
    end
    
    local totalCost = numAmount * price
    local slippage = TradingEngine.calculateSlippage(numAmount, node)
    local actualPrice = price * (1 + slippage)
    local actualCost = numAmount * actualPrice
    
    -- Check if we have enough credits
    if portfolio.credits < actualCost then
        Notifications.add("Insufficient credits", "error")
        return false
    end
    
    -- Execute the trade
    local success = NodeMarket.buyNode(state.selectedSymbol, numAmount, actualPrice)
    if success then
        -- Update portfolio
        PortfolioManager.addCredits(-actualCost)
        PortfolioManager.addHoldings(state.selectedSymbol, numAmount)
        
        -- Show success notification
        local priceStr = TradingEngine.formatPrice(actualPrice)
        Notifications.add(string.format("Bought %.0f %s at %s", numAmount, state.selectedSymbol, priceStr), "success")
        
        -- Clear input
        state.buyAmount = ""
        state.limitPrice = ""
        
        Log.info(string.format("Buy order executed: %.0f %s at %s (slippage: %.2f%%)", 
            numAmount, state.selectedSymbol, priceStr, slippage * 100))
        
        return true
    else
        Notifications.add("Trade failed", "error")
        return false
    end
end

function TradingEngine.executeSell(state, amount, orderType, limitPrice)
    local node = NodeMarket.getNode(state.selectedSymbol)
    if not node then
        Notifications.add("Node not found", "error")
        return false
    end
    
    local numAmount = tonumber(amount)
    if not numAmount or numAmount <= 0 then
        Notifications.add("Invalid amount", "error")
        return false
    end
    
    local portfolio = PortfolioManager.getPortfolio()
    local holdings = portfolio.holdings[state.selectedSymbol] or 0
    
    if holdings < numAmount then
        Notifications.add("Insufficient holdings", "error")
        return false
    end
    
    local price = node.price
    
    -- Use limit price if specified
    if orderType == "limit" and limitPrice then
        local numLimitPrice = tonumber(limitPrice)
        if numLimitPrice and numLimitPrice > 0 then
            price = numLimitPrice
        end
    end
    
    local slippage = TradingEngine.calculateSlippage(numAmount, node)
    local actualPrice = price * (1 - slippage) -- Slippage reduces sell price
    local actualRevenue = numAmount * actualPrice
    
    -- Execute the trade
    local success = NodeMarket.sellNode(state.selectedSymbol, numAmount, actualPrice)
    if success then
        -- Update portfolio
        PortfolioManager.addCredits(actualRevenue)
        PortfolioManager.addHoldings(state.selectedSymbol, -numAmount)
        
        -- Show success notification
        local priceStr = TradingEngine.formatPrice(actualPrice)
        Notifications.add(string.format("Sold %.0f %s at %s", numAmount, state.selectedSymbol, priceStr), "success")
        
        -- Clear input
        state.sellAmount = ""
        state.limitPrice = ""
        
        Log.info(string.format("Sell order executed: %.0f %s at %s (slippage: %.2f%%)", 
            numAmount, state.selectedSymbol, priceStr, slippage * 100))
        
        return true
    else
        Notifications.add("Trade failed", "error")
        return false
    end
end

function TradingEngine.getOrderSummary(state, amount, orderType, limitPrice)
    local node = NodeMarket.getNode(state.selectedSymbol)
    if not node then
        return nil
    end
    
    local numAmount = tonumber(amount)
    if not numAmount or numAmount <= 0 then
        return nil
    end
    
    local price = node.price
    if orderType == "limit" and limitPrice then
        local numLimitPrice = tonumber(limitPrice)
        if numLimitPrice and numLimitPrice > 0 then
            price = numLimitPrice
        end
    end
    
    local slippage = TradingEngine.calculateSlippage(numAmount, node)
    local actualPrice = price * (1 + (state.tradingMode == "buy" and slippage or -slippage))
    local totalValue = numAmount * actualPrice
    
    return {
        amount = numAmount,
        price = price,
        actualPrice = actualPrice,
        slippage = slippage,
        totalValue = totalValue,
        symbol = state.selectedSymbol
    }
end

return TradingEngine
