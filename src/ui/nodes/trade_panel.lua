local Theme = require("src.core.theme")
local Viewport = require("src.core.viewport")
local Util = require("src.core.util")
local NodeMarket = require("src.systems.node_market")
local PortfolioManager = require("src.managers.portfolio")
local Notifications = require("src.ui.notifications")
local Strings = require("src.core.strings")
local Log = require("src.core.log")

local TradePanel = {}

local function formatPrice(p)
    if p >= 100 then return string.format("%.2f", p) end
    if p >= 1 then return string.format("%.3f", p) end
    return string.format("%.5f", p)
end

local function drawBuyInterface(self, player, node, stats, layout)
    love.graphics.setFont(Theme.fonts.small)
    local font = love.graphics.getFont()
    local lineHeight = font:getHeight() + 4
    local yPos = layout.y + 8

    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Amount:", layout.x, yPos)
    yPos = yPos + lineHeight

    local inputW = layout.w - 8
    local inputH = 26
    local inputX = layout.x
    local inputY = yPos

    Theme.drawGradientGlowRect(inputX, inputY, inputW, inputH, 3,
        self.buyInputActive and Theme.colors.bg0 or Theme.colors.bg1,
        Theme.colors.bg0,
        self.buyInputActive and Theme.colors.accent or Theme.colors.border,
        Theme.effects.glowWeak)

    Theme.setColor(Theme.colors.text)
    local displayText = self.buyAmount == "" and "0.0000" or self.buyAmount
    love.graphics.print(displayText, inputX + 4, inputY + 4)

    if self.buyInputActive and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local textWidth = font:getWidth(displayText)
        love.graphics.rectangle("fill", inputX + 4 + textWidth + 2, inputY + 2, 1, inputH - 4)
    end

    self._buyAmountInput = { x = inputX, y = inputY, w = inputW, h = inputH }
    yPos = yPos + inputH + 8

    local amount = tonumber(self.buyAmount) or 0
    local totalCost = amount * stats.price
    local funds = PortfolioManager.getAvailableFunds()
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Total Cost:", layout.x, yPos)
    Theme.setColor(totalCost > funds and Theme.colors.danger or Theme.colors.text)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.print(formatPrice(totalCost) .. " GC", layout.x + 110, yPos - 2)
    love.graphics.setFont(Theme.fonts.small)
    yPos = yPos + lineHeight + 4

    local buttonW = (layout.w - 20) / 4
    local buttonH = 26
    local quickAmounts = {
        { label = "10%", value = math.floor(funds * 0.10 / stats.price * 10000) / 10000 },
        { label = "25%", value = math.floor(funds * 0.25 / stats.price * 10000) / 10000 },
        { label = "50%", value = math.floor(funds * 0.50 / stats.price * 10000) / 10000 },
        { label = "MAX", value = math.floor(funds / stats.price * 10000) / 10000 }
    }

    self._quickBuyButtons = {}
    for i, qa in ipairs(quickAmounts) do
        local btnX = layout.x + 4 + (i - 1) * (buttonW + 4)
        local btnY = yPos

        Theme.drawGradientGlowRect(btnX, btnY, buttonW, buttonH, 3,
            Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak)
        Theme.setColor(Theme.colors.text)
        love.graphics.printf(qa.label, btnX, btnY + 6, buttonW, "center")

        table.insert(self._quickBuyButtons, { x = btnX, y = btnY, w = buttonW, h = buttonH, value = qa.value })
    end
    yPos = yPos + buttonH + 12

    local executeW = layout.w - 16
    local executeH = 40
    local executeX = layout.x + 8
    local executeY = yPos

    local canBuy = amount > 0 and totalCost <= funds
    local buttonColor = canBuy and Theme.colors.success or Theme.colors.bg2

    Theme.drawGradientGlowRect(executeX, executeY, executeW, executeH, 6,
        buttonColor, Theme.colors.bg1, canBuy and Theme.colors.success or Theme.colors.border, Theme.effects.glowWeak)
    Theme.setColor(canBuy and Theme.colors.textHighlight or Theme.colors.textDisabled)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.printf("BUY " .. node.symbol, executeX, executeY + 12, executeW, "center")

    self._executeBuyButton = { x = executeX, y = executeY, w = executeW, h = executeH, enabled = canBuy }
end

local function drawSellInterface(self, player, node, stats, layout)
    love.graphics.setFont(Theme.fonts.small)
    local font = love.graphics.getFont()
    local lineHeight = font:getHeight() + 4
    local yPos = layout.y + 8

    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Amount:", layout.x, yPos)
    yPos = yPos + lineHeight

    local inputW = layout.w - 8
    local inputH = 26
    local inputX = layout.x
    local inputY = yPos

    Theme.drawGradientGlowRect(inputX, inputY, inputW, inputH, 3,
        self.sellInputActive and Theme.colors.bg0 or Theme.colors.bg1,
        Theme.colors.bg0,
        self.sellInputActive and Theme.colors.accent or Theme.colors.border,
        Theme.effects.glowWeak)

    Theme.setColor(Theme.colors.text)
    local displayText = self.sellAmount == "" and "0.0000" or self.sellAmount
    love.graphics.print(displayText, inputX + 4, inputY + 4)

    if self.sellInputActive and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local textWidth = font:getWidth(displayText)
        love.graphics.rectangle("fill", inputX + 4 + textWidth + 2, inputY + 2, 1, inputH - 4)
    end

    self._sellAmountInput = { x = inputX, y = inputY, w = inputW, h = inputH }
    yPos = yPos + inputH + 8

    local amount = tonumber(self.sellAmount) or 0
    local totalRevenue = amount * stats.price
    Theme.setColor(Theme.colors.textSecondary)
    love.graphics.print("Total Revenue:", layout.x, yPos)
    Theme.setColor(Theme.colors.text)
    love.graphics.print(formatPrice(totalRevenue) .. " GC", layout.x + 85, yPos)
    yPos = yPos + lineHeight + 8

    local buttonW = (layout.w - 16) / 3
    local buttonH = 22
    local holdings = PortfolioManager.getAllHoldings()
    local holding = holdings[node.symbol] or { quantity = 0 }
    local quickAmounts = {
        { label = "25%", value = math.floor(holding.quantity * 0.25 * 10000) / 10000 },
        { label = "50%", value = math.floor(holding.quantity * 0.50 * 10000) / 10000 },
        { label = "ALL", value = holding.quantity }
    }

    self._quickSellButtons = {}
    for i, qa in ipairs(quickAmounts) do
        local btnX = layout.x + (i - 1) * (buttonW + 4)
        local btnY = yPos

        Theme.drawGradientGlowRect(btnX, btnY, buttonW, buttonH, 3,
            Theme.colors.bg3, Theme.colors.bg2, Theme.colors.border, Theme.effects.glowWeak)
        Theme.setColor(Theme.colors.text)
        love.graphics.printf(qa.label, btnX, btnY + 4, buttonW, "center")

        table.insert(self._quickSellButtons, { x = btnX, y = btnY, w = buttonW, h = buttonH, value = qa.value })
    end
    yPos = yPos + buttonH + 8

    local executeW = layout.w - 8
    local executeH = 32
    local executeX = layout.x
    local executeY = yPos

    local canSell = amount > 0 and amount <= holding.quantity
    local buttonColor = canSell and Theme.colors.danger or Theme.colors.bg2

    Theme.drawGradientGlowRect(executeX, executeY, executeW, executeH, 4,
        buttonColor, Theme.colors.bg1, canSell and Theme.colors.danger or Theme.colors.border, Theme.effects.glowWeak)
    Theme.setColor(canSell and Theme.colors.textHighlight or Theme.colors.textDisabled)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.printf("SELL " .. node.symbol, executeX, executeY + 8, executeW, "center")

    self._executeSellButton = { x = executeX, y = executeY, w = executeW, h = executeH, enabled = canSell }
end

function TradePanel.draw(self, player, node, stats, layout)
    Theme.drawGradientGlowRect(layout.x, layout.y, layout.w, layout.h, 6,
        Theme.colors.bg2, Theme.colors.bg1, Theme.colors.border, Theme.effects.glowWeak)

    local mx, my = Viewport.getMousePosition()
    local tabW = layout.w / 2
    local tabH = 28
    local buyTabX = layout.x + 4
    local sellTabX = layout.x + 4 + tabW
    local tabY = layout.y + 4

    local buySelected = self.tradingMode == "buy"
    local buyHover = mx and my and mx >= buyTabX and mx <= buyTabX + tabW - 4 and my >= tabY and my <= tabY + tabH
    Theme.drawStyledButton(buyTabX, tabY, tabW - 4, tabH, "BUY", buyHover, 1.0, buySelected and Theme.colors.success or nil, buySelected)

    local sellSelected = self.tradingMode == "sell"
    local sellHover = mx and my and mx >= sellTabX and mx <= sellTabX + tabW - 4 and my >= tabY and my <= tabY + tabH
    Theme.drawStyledButton(sellTabX, tabY, tabW - 4, tabH, "SELL", sellHover, 1.0, sellSelected and Theme.colors.danger or nil, sellSelected)

    self._buyTab = { x = buyTabX, y = tabY, w = tabW - 4, h = tabH }
    self._sellTab = { x = sellTabX, y = tabY, w = tabW - 4, h = tabH }

    local contentY = layout.y + tabH + 8
    local contentH = layout.h - tabH - 12
    local contentLayout = { x = layout.x + 4, y = contentY, w = layout.w - 8, h = contentH }

    if self.tradingMode == "buy" then
        drawBuyInterface(self, player, node, stats, contentLayout)
    else
        drawSellInterface(self, player, node, stats, contentLayout)
    end
end

function TradePanel.mousepressed(self, player, x, y, button)
    if button ~= 1 then return false end

    if self._buyTab and Util.rectContains(x, y, self._buyTab.x, self._buyTab.y, self._buyTab.w, self._buyTab.h) then
        self.tradingMode = "buy"
        self.buyInputActive = false
        self.sellInputActive = false
        return true
    end

    if self._sellTab and Util.rectContains(x, y, self._sellTab.x, self._sellTab.y, self._sellTab.w, self._sellTab.h) then
        self.tradingMode = "sell"
        self.buyInputActive = false
        self.sellInputActive = false
        return true
    end

    if self._buyAmountInput and Util.rectContains(x, y, self._buyAmountInput.x, self._buyAmountInput.y, self._buyAmountInput.w, self._buyAmountInput.h) then
        self.buyInputActive = true
        self.sellInputActive = false
        return true
    end

    if self._sellAmountInput and Util.rectContains(x, y, self._sellAmountInput.x, self._sellAmountInput.y, self._sellAmountInput.w, self._sellAmountInput.h) then
        self.sellInputActive = true
        self.buyInputActive = false
        return true
    end

    if self._quickBuyButtons then
        for _, btn in ipairs(self._quickBuyButtons) do
            if Util.rectContains(x, y, btn.x, btn.y, btn.w, btn.h) then
                self.buyAmount = tostring(btn.value)
                return true
            end
        end
    end

    if self._quickSellButtons then
        for _, btn in ipairs(self._quickSellButtons) do
            if Util.rectContains(x, y, btn.x, btn.y, btn.w, btn.h) then
                self.sellAmount = tostring(btn.value)
                return true
            end
        end
    end

    if self._executeBuyButton and self._executeBuyButton.enabled and
        Util.rectContains(x, y, self._executeBuyButton.x, self._executeBuyButton.y, self._executeBuyButton.w, self._executeBuyButton.h) then
        TradePanel.executeBuy(self, player)
        return true
    end

    if self._executeSellButton and self._executeSellButton.enabled and
        Util.rectContains(x, y, self._executeSellButton.x, self._executeSellButton.y, self._executeSellButton.w, self._executeSellButton.h) then
        TradePanel.executeSell(self, player)
        return true
    end

    self.buyInputActive = false
    self.sellInputActive = false
    return false
end

function TradePanel.textinput(self, text)
    if text:match("^[0-9%.]+$") then
        if self.buyInputActive then
            if text == "." and self.buyAmount:find("%.") then
                return true
            end
            self.buyAmount = self.buyAmount .. text
            return true
        elseif self.sellInputActive then
            if text == "." and self.sellAmount:find("%.") then
                return true
            end
            self.sellAmount = self.sellAmount .. text
            return true
        end
    end
    return false
end

function TradePanel.keypressed(self, player, key)
    if key == "backspace" then
        if self.buyInputActive then
            if #self.buyAmount > 0 then
                self.buyAmount = self.buyAmount:sub(1, -2)
            end
            return true
        elseif self.sellInputActive then
            if #self.sellAmount > 0 then
                self.sellAmount = self.sellAmount:sub(1, -2)
            end
            return true
        end
    elseif key == "return" or key == "kpenter" then
        if self.buyInputActive and self._executeBuyButton and self._executeBuyButton.enabled then
            TradePanel.executeBuy(self, player)
            return true
        elseif self.sellInputActive and self._executeSellButton and self._executeSellButton.enabled then
            TradePanel.executeSell(self, player)
            return true
        end
    elseif key == "escape" then
        self.buyInputActive = false
        self.sellInputActive = false
        return true
    end

    return false
end

function TradePanel.executeBuy(self, player)
    if not player then return end

    local amount = tonumber(self.buyAmount) or 0
    if amount <= 0 then return end

    local node = NodeMarket.getNodeBySymbol(self.selectedSymbol)
    if not node then return end

    local stats = NodeMarket.getStats(node)
    local totalCost = amount * stats.price
    local funds = PortfolioManager.getAvailableFunds()

    if totalCost > funds then
        local errorText = (Strings and Strings.getError and Strings.getError("insufficient_funds")) or "Insufficient funds"
        Notifications.add(errorText, "error")
        Log.debug("ui.nodes.trade - buy blocked: insufficient funds")
        return
    end

    local success, message = PortfolioManager.placeBuyOrder(self.selectedSymbol, amount, stats.price, false)
    if success then
        Notifications.add(string.format("Bought %.4f %s", amount, self.selectedSymbol), "success")
        self.buyAmount = ""
        self.buyInputActive = false
    else
        Notifications.add(message or "Buy order failed", "error")
    end
end

function TradePanel.executeSell(self, player)
    if not player then return end

    local amount = tonumber(self.sellAmount) or 0
    if amount <= 0 then return end

    local node = NodeMarket.getNodeBySymbol(self.selectedSymbol)
    if not node then return end

    local stats = NodeMarket.getStats(node)
    local holdings = PortfolioManager.getAllHoldings()
    local holding = holdings[self.selectedSymbol] or { quantity = 0 }

    if amount > holding.quantity then
        local errorText = (Strings and Strings.getError and Strings.getError("insufficient_holdings")) or "Insufficient holdings"
        Notifications.add(errorText, "error")
        Log.debug("ui.nodes.trade - sell blocked: insufficient holdings")
        return
    end

    local success, message = PortfolioManager.placeSellOrder(self.selectedSymbol, amount, stats.price, false)
    if success then
        Notifications.add(string.format("Sold %.4f %s", amount, self.selectedSymbol), "success")
        self.sellAmount = ""
        self.sellInputActive = false
    else
        Notifications.add(message or "Sell order failed", "error")
    end
end

return TradePanel
