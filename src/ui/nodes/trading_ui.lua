--[[
    Nodes Trading UI
    
    Handles rendering of trading interface including:
    - Buy/sell tabs
    - Order forms
    - Order summary
    - Input validation
]]

local Theme = require("src.core.theme")
local NodeMarket = require("src.systems.node_market")
local TradingEngine = require("src.ui.nodes.trading_engine")

local TradingUI = {}

function TradingUI.draw(self, player, node, stats, x, y, w, h)
    local tradingH = 200
    local tradingY = y + h - tradingH
    
    -- Trading background
    Theme.setColor(Theme.colors.bg1)
    love.graphics.rectangle("fill", x, tradingY, w, tradingH)
    
    -- Trading border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, tradingY, w, tradingH)
    
    -- Trading tabs
    TradingUI.drawTradingTabs(self, x, tradingY, w, 30)
    
    -- Trading content
    local contentY = tradingY + 30
    local contentH = tradingH - 30
    
    if self.state.tradingMode == "buy" then
        TradingUI.drawBuyInterface(self, player, node, stats, x, contentY, w, contentH)
    else
        TradingUI.drawSellInterface(self, player, node, stats, x, contentY, w, contentH)
    end
end

function TradingUI.drawTradingTabs(self, x, y, w, h)
    local tabW = w * 0.5
    local buyX = x
    local sellX = x + tabW
    
    -- Buy tab
    local buyActive = self.state.tradingMode == "buy"
    local buyColor = buyActive and Theme.colors.accent or Theme.colors.bg2
    Theme.setColor(buyColor)
    love.graphics.rectangle("fill", buyX, y, tabW, h)
    
    -- Buy tab border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", buyX, y, tabW, h)
    
    -- Buy tab text
    Theme.setColor(buyActive and Theme.colors.textHighlight or Theme.colors.text)
    Theme.setFont("medium")
    local buyText = "BUY"
    local buyTextW = Theme.fonts.medium:getWidth(buyText)
    local buyTextH = Theme.fonts.medium:getHeight()
    local buyTextX = buyX + (tabW - buyTextW) * 0.5
    local buyTextY = y + (h - buyTextH) * 0.5
    love.graphics.print(buyText, buyTextX, buyTextY)
    
    -- Sell tab
    local sellActive = self.state.tradingMode == "sell"
    local sellColor = sellActive and Theme.colors.accent or Theme.colors.bg2
    Theme.setColor(sellColor)
    love.graphics.rectangle("fill", sellX, y, tabW, h)
    
    -- Sell tab border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", sellX, y, tabW, h)
    
    -- Sell tab text
    Theme.setColor(sellActive and Theme.colors.textHighlight or Theme.colors.text)
    local sellText = "SELL"
    local sellTextW = Theme.fonts.medium:getWidth(sellText)
    local sellTextH = Theme.fonts.medium:getHeight()
    local sellTextX = sellX + (tabW - sellTextW) * 0.5
    local sellTextY = y + (h - sellTextH) * 0.5
    love.graphics.print(sellText, sellTextX, sellTextY)
end

function TradingUI.drawBuyInterface(self, player, node, stats, x, y, w, h)
    local pad = 12
    local inputH = 28
    local buttonH = 32
    local spacing = 8
    
    -- Amount input
    local amountY = y + pad
    TradingUI.drawInputField(self, "Amount", self.state.buyAmount, x + pad, amountY, w * 0.3, inputH, "buy")
    
    -- Order type selector
    local orderTypeX = x + pad + w * 0.35
    TradingUI.drawOrderTypeSelector(self, orderTypeX, amountY, w * 0.25, inputH)
    
    -- Limit price input (if limit order)
    local limitPriceY = amountY + inputH + spacing
    if self.state.orderType == "limit" then
        TradingUI.drawInputField(self, "Limit Price", self.state.limitPrice, x + pad, limitPriceY, w * 0.3, inputH, "limit")
    end
    
    -- Order summary
    local summaryY = limitPriceY + (self.state.orderType == "limit" and inputH + spacing or 0)
    TradingUI.drawOrderSummary(self, node, x + pad, summaryY, w - pad * 2, 60)
    
    -- Execute button
    local buttonY = summaryY + 60 + spacing
    local buttonW = 120
    local buttonX = x + w - buttonW - pad
    
    TradingUI.drawExecuteButton(self, "BUY", buttonX, buttonY, buttonW, buttonH, node)
end

function TradingUI.drawSellInterface(self, player, node, stats, x, y, w, h)
    local pad = 12
    local inputH = 28
    local buttonH = 32
    local spacing = 8
    
    -- Amount input
    local amountY = y + pad
    TradingUI.drawInputField(self, "Amount", self.state.sellAmount, x + pad, amountY, w * 0.3, inputH, "sell")
    
    -- Order type selector
    local orderTypeX = x + pad + w * 0.35
    TradingUI.drawOrderTypeSelector(self, orderTypeX, amountY, w * 0.25, inputH)
    
    -- Limit price input (if limit order)
    local limitPriceY = amountY + inputH + spacing
    if self.state.orderType == "limit" then
        TradingUI.drawInputField(self, "Limit Price", self.state.limitPrice, x + pad, limitPriceY, w * 0.3, inputH, "limit")
    end
    
    -- Order summary
    local summaryY = limitPriceY + (self.state.orderType == "limit" and inputH + spacing or 0)
    TradingUI.drawOrderSummary(self, node, x + pad, summaryY, w - pad * 2, 60)
    
    -- Execute button
    local buttonY = summaryY + 60 + spacing
    local buttonW = 120
    local buttonX = x + w - buttonW - pad
    
    TradingUI.drawExecuteButton(self, "SELL", buttonX, buttonY, buttonW, buttonH, node)
end

function TradingUI.drawInputField(self, label, value, x, y, w, h, inputType)
    -- Label
    Theme.setColor(Theme.colors.textSecondary)
    Theme.setFont("small")
    love.graphics.print(label .. ":", x, y - 16)
    
    -- Input background
    local bgColor = self.state:isInputActive() and inputType == self.state.tradingMode and Theme.colors.bg3 or Theme.colors.bg2
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Input border
    local borderColor = self.state:isInputActive() and inputType == self.state.tradingMode and Theme.colors.borderBright or Theme.colors.border
    Theme.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Input text
    Theme.setColor(Theme.colors.text)
    Theme.setFont("medium")
    local textX = x + 8
    local textY = y + (h - Theme.fonts.medium:getHeight()) * 0.5
    love.graphics.print(value or "", textX, textY)
    
    -- Cursor (if active)
    if self.state:isInputActive() and inputType == self.state.tradingMode then
        local cursorX = textX + Theme.fonts.medium:getWidth(value or "")
        local cursorY = textY
        local cursorH = Theme.fonts.medium:getHeight()
        Theme.setColor(Theme.colors.text)
        love.graphics.rectangle("fill", cursorX, cursorY, 1, cursorH)
    end
end

function TradingUI.drawOrderTypeSelector(self, x, y, w, h)
    local marketW = w * 0.5
    local limitW = w * 0.5
    
    -- Market button
    local marketActive = self.state.orderType == "market"
    local marketColor = marketActive and Theme.colors.accent or Theme.colors.bg2
    Theme.setColor(marketColor)
    love.graphics.rectangle("fill", x, y, marketW, h)
    
    -- Market border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, marketW, h)
    
    -- Market text
    Theme.setColor(marketActive and Theme.colors.textHighlight or Theme.colors.text)
    Theme.setFont("small")
    local marketText = "Market"
    local marketTextW = Theme.fonts.small:getWidth(marketText)
    local marketTextH = Theme.fonts.small:getHeight()
    local marketTextX = x + (marketW - marketTextW) * 0.5
    local marketTextY = y + (h - marketTextH) * 0.5
    love.graphics.print(marketText, marketTextX, marketTextY)
    
    -- Limit button
    local limitX = x + marketW
    local limitActive = self.state.orderType == "limit"
    local limitColor = limitActive and Theme.colors.accent or Theme.colors.bg2
    Theme.setColor(limitColor)
    love.graphics.rectangle("fill", limitX, y, limitW, h)
    
    -- Limit border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", limitX, y, limitW, h)
    
    -- Limit text
    Theme.setColor(limitActive and Theme.colors.textHighlight or Theme.colors.text)
    local limitText = "Limit"
    local limitTextW = Theme.fonts.small:getWidth(limitText)
    local limitTextH = Theme.fonts.small:getHeight()
    local limitTextX = limitX + (limitW - limitTextW) * 0.5
    local limitTextY = y + (h - limitTextH) * 0.5
    love.graphics.print(limitText, limitTextX, limitTextY)
end

function TradingUI.drawOrderSummary(self, node, x, y, w, h)
    if not node then return end
    
    -- Summary background
    Theme.setColor(Theme.colors.bg2)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Summary border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    local amount = self.state.tradingMode == "buy" and self.state.buyAmount or self.state.sellAmount
    local numAmount = tonumber(amount)
    
    if numAmount and numAmount > 0 then
        local summary = TradingEngine.getOrderSummary(self.state, amount, self.state.orderType, self.state.limitPrice)
        if summary then
            local pad = 8
            local lineHeight = 14
            local textY = y + pad
            
            Theme.setFont("small")
            
            -- Order details
            Theme.setColor(Theme.colors.textSecondary)
            love.graphics.print("Order Summary:", x + pad, textY)
            textY = textY + lineHeight
            
            Theme.setColor(Theme.colors.text)
            love.graphics.print(string.format("Amount: %.0f %s", summary.amount, summary.symbol), x + pad, textY)
            textY = textY + lineHeight
            
            love.graphics.print(string.format("Price: %s", TradingEngine.formatPrice(summary.actualPrice)), x + pad, textY)
            textY = textY + lineHeight
            
            love.graphics.print(string.format("Slippage: %.2f%%", summary.slippage * 100), x + pad, textY)
            textY = textY + lineHeight
            
            love.graphics.print(string.format("Total: %s", TradingEngine.formatPrice(summary.totalValue)), x + pad, textY)
        end
    else
        Theme.setColor(Theme.colors.textSecondary)
        Theme.setFont("small")
        love.graphics.print("Enter amount to see order summary", x + 8, y + h * 0.5 - 7)
    end
end

function TradingUI.drawExecuteButton(self, text, x, y, w, h, node)
    local isEnabled = node and node.price and node.price > 0
    local bgColor = isEnabled and Theme.colors.accent or Theme.colors.bg3
    local textColor = isEnabled and Theme.colors.textHighlight or Theme.colors.textDisabled
    
    -- Button background
    Theme.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Button border
    Theme.setColor(Theme.colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Button text
    Theme.setColor(textColor)
    Theme.setFont("medium")
    local textW = Theme.fonts.medium:getWidth(text)
    local textH = Theme.fonts.medium:getHeight()
    local textX = x + (w - textW) * 0.5
    local textY = y + (h - textH) * 0.5
    love.graphics.print(text, textX, textY)
end

function TradingUI.handleTradingTabClick(self, mx, my, x, y, w)
    local tabH = 30
    local tabW = w * 0.5
    local buyX = x
    local sellX = x + tabW
    
    if my >= y and my < y + tabH then
        if mx >= buyX and mx < buyX + tabW then
            if self.state.tradingMode ~= "buy" then
                self.state.tradingMode = "buy"
                return true
            end
        elseif mx >= sellX and mx < sellX + tabW then
            if self.state.tradingMode ~= "sell" then
                self.state.tradingMode = "sell"
                return true
            end
        end
    end
    
    return false
end

function TradingUI.handleOrderTypeClick(self, mx, my, x, y, w)
    local marketW = w * 0.5
    local limitW = w * 0.5
    local limitX = x + marketW
    
    if my >= y and my < y + 28 then
        if mx >= x and mx < x + marketW then
            if self.state.orderType ~= "market" then
                self.state.orderType = "market"
                return true
            end
        elseif mx >= limitX and mx < limitX + limitW then
            if self.state.orderType ~= "limit" then
                self.state.orderType = "limit"
                return true
            end
        end
    end
    
    return false
end

function TradingUI.handleExecuteClick(self, mx, my, x, y, w, h, node)
    if mx >= x and mx < x + w and my >= y and my < y + h then
        if node and node.price and node.price > 0 then
            local amount = self.state.tradingMode == "buy" and self.state.buyAmount or self.state.sellAmount
            if amount and tonumber(amount) and tonumber(amount) > 0 then
                if self.state.tradingMode == "buy" then
                    return TradingEngine.executeBuy(self.state, amount, self.state.orderType, self.state.limitPrice)
                else
                    return TradingEngine.executeSell(self.state, amount, self.state.orderType, self.state.limitPrice)
                end
            end
        end
    end
    return false
end

return TradingUI
